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

function hg.CanPromptPickup(ply, ent)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
	if ply.organism and ply.organism.otrub then return false end
	if ply:GetNetVar("disappearance", nil) then return false end
	if not IsValid(ent) or ent:IsWorld() or ent:IsPlayer() or ent:IsRagdoll() then return false end
	local isPlayerHolding = ent.IsPlayerHolding and ent:IsPlayerHolding()
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

surface.CreateFont("HG_PickupPrompt", {
	font = "Arial",
	size = 18,
	weight = 700,
	antialias = true
})

surface.CreateFont("HG_PickupPromptSmall", {
	font = "Arial",
	size = 14,
	weight = 500,
	antialias = true
})

local nearbyPickups = {}
local nextPickupScan = 0
local selectedPickup
local lastSentPickup
local nextPickupSelectionSend = 0

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
	for _, ent in ipairs(ents.FindInSphere(ply:EyePos(), PICKUP_SCAN_RANGE)) do
		if hg.CanPromptPickup(ply, ent) and pickupVisible(ply, ent) then
			nearbyPickups[#nearbyPickups + 1] = ent
		end
	end

	table.sort(nearbyPickups, function(a, b)
		return ply:EyePos():DistToSqr(a:NearestPoint(ply:EyePos())) < ply:EyePos():DistToSqr(b:NearestPoint(ply:EyePos()))
	end)

	for index = 33, #nearbyPickups do
		nearbyPickups[index] = nil
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
	if not IsValid(ply) or not ply:Alive() or not ply:KeyDown(IN_WALK) then
		selectedPickup = nil
		sendPickupSelection(nil)
		return
	end

	selectedPickup = choosePickup(ply, scanNearbyPickups(ply))
	sendPickupSelection(selectedPickup)
end)

local keyColor = Color(190, 35, 35, 245)
local selectedColor = Color(255, 255, 255, 245)
local idleColor = Color(205, 205, 205, 205)
local backgroundColor = Color(8, 8, 8, 215)
local shadowColor = Color(0, 0, 0, 220)

local function drawPickupPrompt(ent, selected, showHint)
	if not IsValid(ent) then return end

	local screen = ent:WorldSpaceCenter():ToScreen()
	if not screen.visible then return end

	local name = "Pick up " .. pickupName(ent)
	surface.SetFont("HG_PickupPrompt")
	local nameWidth = surface.GetTextSize(name)
	local width = math.max(126, nameWidth + 58)
	local x, y = math.Round(screen.x - width * 0.5), math.Round(screen.y - 20)
	local color = selected and selectedColor or idleColor

	draw.RoundedBox(5, x + 2, y + 2, width, 40, shadowColor)
	draw.RoundedBox(5, x, y, width, 40, backgroundColor)
	draw.RoundedBox(4, x + 6, y + 7, 28, 26, selected and keyColor or Color(85, 85, 85, 225))
	draw.SimpleText("E", "HG_PickupPrompt", x + 20, y + 20, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(name, "HG_PickupPrompt", x + 42, y + 20, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if showHint then
		draw.SimpleText("Hold ALT to show nearby pickups", "HG_PickupPromptSmall", screen.x, y + 47, idleColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

hook.Add("HUDPaint", "HG_DrawPickupPrompts", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	if ply.organism and ply.organism.otrub then return end
	if ply:GetNetVar("disappearance", nil) then return end

	if ply:KeyDown(IN_WALK) then
		for _, ent in ipairs(scanNearbyPickups(ply)) do
			drawPickupPrompt(ent, ent == selectedPickup, false)
		end

		if IsValid(selectedPickup) then
			draw.SimpleText("Aim at a pickup and press E", "HG_PickupPromptSmall", ScrW() * 0.5, ScrH() * 0.5 + 34, selectedColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
		return
	end

	local traceEnt = ply:GetEyeTrace().Entity
	if hg.CanPromptPickup(ply, traceEnt) and pickupVisible(ply, traceEnt) then
		drawPickupPrompt(traceEnt, true, true)
	end
end)
