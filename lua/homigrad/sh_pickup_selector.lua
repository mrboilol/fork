local PICKUP_RANGE = 100
local PICKUP_SCAN_RANGE = PICKUP_RANGE + 24

hg.PickupBlockedWeapons = hg.PickupBlockedWeapons or {
	["weapon_357"] = true,
	["weapon_pistol"] = true,
	["weapon_crossbow"] = true,
	["weapon_crowbar"] = true,
	["weapon_frag"] = true,
	["weapon_ar2"] = true,
	["weapon_rpg"] = true,
	["weapon_slam"] = true,
	["weapon_shotgun"] = true,
	["weapon_smg1"] = true,
	["weapon_stunstick"] = true
}

local physicsPickupClasses = {
	["prop_physics"] = true,
	["prop_physics_multiplayer"] = true,
	["func_physbox"] = true
}

local function isBound(ent)
	local ductCount = hgCheckDuctTapeObjects and hgCheckDuctTapeObjects(ent) or 0
	local nailCount = hgCheckBindObjects and hgCheckBindObjects(ent) or 0
	return ductCount > 0 or nailCount > 0
end

local function isHeldByPlayer(ent)
	local checkHolding = ent.IsPlayerHolding
	return isfunction(checkHolding) and checkHolding(ent) or false
end

function hg.CanPromptPickup(ply, ent)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
	if ply.organism and ply.organism.otrub then return false end
	if ply:GetNetVar("disappearance", nil) then return false end
	if not IsValid(ent) or ent:IsWorld() or ent:IsPlayer() or ent:IsRagdoll() then return false end
	local isPlayerHolding = isHeldByPlayer(ent)
	if ent:GetNoDraw() or IsValid(ent:GetParent()) or isPlayerHolding then return false end
	if ply:EyePos():DistToSqr(ent:NearestPoint(ply:EyePos())) > PICKUP_RANGE * PICKUP_RANGE then return false end

	if ent:IsWeapon() then
		return not IsValid(ent:GetOwner()) and not hg.PickupBlockedWeapons[ent:GetClass()] and not isBound(ent)
	end

	if ent.IsZPickup then return not isBound(ent) end
	if not physicsPickupClasses[ent:GetClass()] or isBound(ent) then return false end

	local phys = ent:GetPhysicsObject()
	return IsValid(phys) and phys.GetMass and phys:GetMass() <= 14
end

local function hasPickupLineOfSight(ply, ent)
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ent:WorldSpaceCenter(),
		filter = ply,
		mask = MASK_SOLID
	})

	return not tr.Hit or tr.Entity == ent
end

if SERVER then
	util.AddNetworkString("HG_PickupSelection")

	net.Receive("HG_PickupSelection", function(_, ply)
		local ent = net.ReadEntity()
		ply.hgPickupSelection = IsValid(ent) and ent or nil
		ply.hgPickupSelectionExpires = CurTime() + 0.4
	end)

	function hg.GetPickupUseEntity(ply)
		if not ply:KeyDown(IN_WALK) or not ply:KeyDown(IN_USE) then return end
		if (ply.hgPickupSelectionExpires or 0) < CurTime() then return end

		local ent = ply.hgPickupSelection
		if not hg.CanPromptPickup(ply, ent) or not hasPickupLineOfSight(ply, ent) then return end

		return ent
	end

	return
end

local nearbyPickups = {}
local nearbyInteractables = {}
local nextPickupScan = 0
local selectedPickup
local lastSentPickup
local nextPickupSelectionSend = 0
local altGlowAlpha = 0

function hg.CanPromptSearch(ply, ent)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
	if ply.organism and ply.organism.otrub then return false end
	if ply:GetNetVar("disappearance", nil) then return false end
	if not IsValid(ent) or ent:IsWorld() or ent:IsPlayer() or ent:IsRagdoll() then return false end
	if ent:GetNoDraw() or IsValid(ent:GetParent()) then return false end
	if ply:EyePos():DistToSqr(ent:NearestPoint(ply:EyePos())) > PICKUP_RANGE * PICKUP_RANGE then return false end

	return ent.IsSearchableContainer == true or ent:GetNWBool("hgSearchableContainer", false)
end

local function pickupName(ent)
	local name

	if ent:IsWeapon() and ent.GetPrintName then
		name = ent:GetPrintName()
	end

	name = name or ent.PrintName
	if not name or name == "" then
		local phrase = language.GetPhrase(ent:GetClass())
		if phrase ~= ent:GetClass() then name = phrase end
	end

	if not name or name == "" then
		name = string.StripExtension(string.GetFileFromFilename(ent:GetModel() or ""))
	end

	if not name or name == "" then name = ent:GetClass() end
	return string.Replace(name, "_", " ")
end

local function pickupVisible(ply, ent)
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ent:WorldSpaceCenter(),
		filter = ply,
		mask = MASK_SOLID
	})

	return not tr.Hit or tr.Entity == ent
end

local function scanNearbyPickups(ply)
	if nextPickupScan > CurTime() then return nearbyPickups end
	nextPickupScan = CurTime() + 0.08

	nearbyPickups = {}
	nearbyInteractables = {}
	for _, ent in ipairs(ents.FindInSphere(ply:EyePos(), PICKUP_SCAN_RANGE)) do
		if hg.CanPromptPickup(ply, ent) and pickupVisible(ply, ent) then
			nearbyPickups[#nearbyPickups + 1] = ent
		end
		if hg.CanPromptSearch(ply, ent) and pickupVisible(ply, ent) then
			nearbyInteractables[#nearbyInteractables + 1] = ent
		end
	end

	table.sort(nearbyPickups, function(a, b)
		return ply:EyePos():DistToSqr(a:NearestPoint(ply:EyePos())) < ply:EyePos():DistToSqr(b:NearestPoint(ply:EyePos()))
	end)

	for index = 33, #nearbyPickups do
		nearbyPickups[index] = nil
	end

	for _, ent in ipairs(nearbyPickups) do
		nearbyInteractables[#nearbyInteractables + 1] = ent
	end

	table.sort(nearbyInteractables, function(a, b)
		return ply:EyePos():DistToSqr(a:NearestPoint(ply:EyePos())) < ply:EyePos():DistToSqr(b:NearestPoint(ply:EyePos()))
	end)

	for index = 33, #nearbyInteractables do
		nearbyInteractables[index] = nil
	end

	return nearbyPickups
end

local function choosePickup(ply, pickups)
	local traceEnt = ply:GetEyeTrace().Entity
	if hg.CanPromptPickup(ply, traceEnt) and pickupVisible(ply, traceEnt) then return traceEnt end

	local centerX, centerY = ScrW() * 0.5, ScrH() * 0.5
	local maxScreenDistance = math.min(ScrW(), ScrH()) * 0.2
	local bestDistance = maxScreenDistance * maxScreenDistance
	local best

	for _, ent in ipairs(pickups) do
		if not IsValid(ent) then continue end

		local screen = ent:WorldSpaceCenter():ToScreen()
		if not screen.visible then continue end

		local distance = (screen.x - centerX) ^ 2 + (screen.y - centerY) ^ 2
		if distance < bestDistance then
			bestDistance = distance
			best = ent
		end
	end

	return best
end

local function sendPickupSelection(ent)
	if ent == lastSentPickup and (not IsValid(ent) or nextPickupSelectionSend > CurTime()) then return end
	lastSentPickup = ent
	nextPickupSelectionSend = CurTime() + 0.2

	net.Start("HG_PickupSelection")
		net.WriteEntity(IsValid(ent) and ent or NULL)
	net.SendToServer()
end

hook.Add("Think", "HG_UpdatePickupSelection", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		selectedPickup = nil
		sendPickupSelection(nil)
		return
	end

	selectedPickup = choosePickup(ply, scanNearbyPickups(ply))
	sendPickupSelection(ply:KeyDown(IN_WALK) and selectedPickup or nil)
	altGlowAlpha = math.Approach(altGlowAlpha, ply:KeyDown(IN_WALK) and 1 or 0, FrameTime() * 4)
end)

hook.Add("PreDrawHalos", "HG_HighlightPickupCandidates", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or altGlowAlpha <= 0 then return end

	scanNearbyPickups(ply)
	local eyePos = ply:EyePos()
	for _, ent in ipairs(nearbyInteractables) do
		local distance = eyePos:Distance(ent:NearestPoint(eyePos))
		local proximity = math.Clamp(1 - distance / PICKUP_RANGE, 0, 1)
		local intensity = 0.3 + proximity * 0.7

		halo.Add({ent}, Color(255 * intensity, 210 * intensity, 80 * intensity, math.Round(255 * altGlowAlpha)), 2, 2, 1, true, false)
	end
end)

function hg.EnsurePickupHudHint(ent)
	if not IsValid(ent) or ent.HudHintMarkup then return end

	local use = string.upper(input.LookupBinding("+use") or "E")
	local action = hg.CanPromptSearch(LocalPlayer(), ent) and "search" or "pickup"
	ent.HudHintMarkup = markup.Parse(
		"<font=ZCity_Tiny>" .. pickupName(ent) .. "</font>\n" ..
		"<font=ZCity_SuperTiny><colour=125,125,125>" .. use .. " to " .. action .. "</colour></font>",
		450
	)
	ent.hgGeneratedPickupHudHint = ent.HudHintMarkup
end

local noPickupPrompts = {}

function hg.GetPickupPromptEntities(ply, traceEnt)
	if not IsValid(ply) or not ply:Alive() then return noPickupPrompts end

	if ply:KeyDown(IN_WALK) then
		scanNearbyPickups(ply)
		for _, ent in ipairs(nearbyInteractables) do
			hg.EnsurePickupHudHint(ent)
		end
		return nearbyInteractables, selectedPickup
	end

	if IsValid(selectedPickup) and hg.CanPromptPickup(ply, selectedPickup) and pickupVisible(ply, selectedPickup) then
		hg.EnsurePickupHudHint(selectedPickup)
		return {selectedPickup}, selectedPickup
	end

	return noPickupPrompts
end
