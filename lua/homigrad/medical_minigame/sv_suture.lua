hg.Suture = hg.Suture or {}
hg.Suture.Sessions = hg.Suture.Sessions or {}

util.AddNetworkString("hg_suture_start")
util.AddNetworkString("hg_suture_target")
util.AddNetworkString("hg_suture_cycle")
util.AddNetworkString("hg_suture_event")
util.AddNetworkString("hg_suture_finish")
util.AddNetworkString("hg_suture_cancel")

local EVENT_PUNCTURE = 1
local EVENT_SLIP = 2

local function ResolveTarget(ent)
	if not IsValid(ent) then return end
	if ent:IsRagdoll() and hg.RagdollOwner then
		ent = hg.RagdollOwner(ent) or ent
	end
	return IsValid(ent) and ent.organism and ent or nil
end

local function CanReach(ply, target)
	if not IsValid(ply) or not ply:Alive() or not IsValid(target) or not target.organism then return false end
	if ply.organism and ply.organism.otrub then return false end
	if target == ply then return true end
	local character = hg.GetCurrentCharacter(target)
	if not IsValid(character) then character = target end
	return ply:GetPos():DistToSqr(character:GetPos()) <= 10000
end

function hg.Suture.GetOptions(target)
	local org = IsValid(target) and target.organism
	local options = {}
	if not org then return options end

	for _, wound in ipairs(org.arterialwounds or {}) do
		if (wound[1] or 0) > 0 then
			options[#options + 1] = {
				kind = "artery", wound = wound, bone = wound[4], value = wound[1], cost = wound[7] == "arteria" and 3 or 2,
				label = "Artery - " .. (wound[7] == "arteria" and "neck" or hg.GetBoneLabel(wound[4])),
			}
		end
	end

	for _, wound in ipairs(org.wounds or {}) do
		if (wound[1] or 0) > 0 then
			options[#options + 1] = {
				kind = "wound", wound = wound, bone = wound[4], value = wound[1], cost = 1,
				label = "Wound - " .. hg.GetBoneLabel(wound[4]),
			}
		end
	end

	table.sort(options, function(a, b)
		if a.kind ~= b.kind then return a.kind == "artery" end
		return a.value > b.value
	end)

	return options
end

local function ResolveChoice(session)
	local options = hg.Suture.GetOptions(session.target)
	if #options == 0 then return nil, options, 0 end
	for index, option in ipairs(options) do
		if option.wound == session.wound then return option, options, index end
	end
	session.wound = options[1].wound
	return options[1], options, 1
end

local function GetStitchCount(option)
	if option.kind == "artery" then return option.cost == 3 and 8 or 7 end
	return math.Clamp(3 + math.floor(option.value / 15), 3, 6)
end

local function WriteChoice(option, index, count)
	net.WriteString(option.label)
	net.WriteUInt(math.min(index, 63), 6)
	net.WriteUInt(math.min(count, 63), 6)
	net.WriteUInt(GetStitchCount(option), 4)
end

local function GetSupply(session)
	local wep = session.weapon
	return IsValid(wep) and wep.modeValues and wep.modeValues[session.mode] or 0
end

local function EndSession(ply, finished)
	if not hg.Suture.Sessions[ply] then return end
	hg.Suture.Sessions[ply] = nil
	hook.Run("hg_medical_minigame_ended", ply, "suture", finished)
end

function hg.Suture.HasOptions(target)
	target = ResolveTarget(target)
	return target ~= nil and #hg.Suture.GetOptions(target) > 0
end

function hg.Suture.Start(ply, wep, ent, mode)
	if not IsValid(ply) or not ply:IsPlayer() or not IsValid(wep) then return false end
	local target = ResolveTarget(ent) or ply
	if not CanReach(ply, target) then return false end

	mode = mode or 1
	local session = {weapon = wep, target = target, mode = mode}
	if GetSupply(session) <= 0 then return false end

	local previous = hg.Suture.Sessions[ply]
	if previous and previous.target == target then session.wound = previous.wound end

	local option, options, index = ResolveChoice(session)
	if not option then
		ply:Notify("There is nothing to suture.", true, "suture_nothing", 0)
		return false
	end

	hg.Suture.Sessions[ply] = session

	net.Start("hg_suture_start")
		net.WriteEntity(target)
		WriteChoice(option, index, #options)
	net.Send(ply)

	return true
end

function hg.Suture.Apply(ply, session, option)
	local target = session.target
	local org = target.organism
	local wep = session.weapon
	local wound = option.wound

	if option.kind == "artery" then
		table.RemoveByValue(org.arterialwounds, wound)
		if wound[7] == "arteria" then
			org.neckslit = false
			org.neckslitDeadline = nil
			org.neckslitWarned = nil
			org.throatCutPressureShock = 0
			org.neckBrainOxygenPenalty = 0
		end
		if hg.organism.RebuildArteryWoundState then
			hg.organism.RebuildArteryWoundState(org, true)
		else
			hg.organism.MarkArterialWoundsNetDirty(org)
		end

		local woundBone = wound[7] == "arteria" and "arteria" or wound[4]
		local limb = hg.GetTourniquetLimb and hg.GetTourniquetLimb(woundBone)
		if limb then
			local limbStillBleeding = false
			for _, other in ipairs(org.arterialwounds or {}) do
				if (other[1] or 0) > 0 and hg.GetTourniquetLimb(other[7] == "arteria" and "arteria" or other[4]) == limb then
					limbStillBleeding = true
					break
				end
			end

			local holder = IsValid(org.owner) and org.owner or target
			if not limbStillBleeding and hg.RemoveTourniquetsOnLimb(holder, woundBone) > 0 then
				ply:Notify("The artery is closed. You take the tourniquet off.", true, "suture_tourniquet", 0)
			end
		end
	else
		org.bleed = math.max((org.bleed or 0) - (wound[1] or 0), 0)
		wound[1] = 0
		table.RemoveByValue(org.wounds, wound)
		hg.organism.MarkWoundsNetDirty(org, true)
	end

	org.painadd = (org.painadd or 0) + (option.kind == "artery" and 6 or 3)

	wep.modeValues[session.mode] = math.max(wep.modeValues[session.mode] - math.min(option.cost, GetSupply(session)), 0)
	wep:SetNetVar("modeValues", wep.modeValues)

	local soundEnt = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
	soundEnt:EmitSound("snd_jack_hmcd_bandage.wav", 55, math.random(110, 125))

	if wep.OnSutureUsed then wep:OnSutureUsed(target) end
end

local function GetValidSession(ply)
	local session = hg.Suture.Sessions[ply]
	if not session then return end
	if not IsValid(session.weapon) or session.weapon:GetOwner() ~= ply or ply:GetActiveWeapon() ~= session.weapon or not CanReach(ply, session.target) then
		EndSession(ply, false)
		return
	end
	return session
end

net.Receive("hg_suture_cycle", function(len, ply)
	local session = GetValidSession(ply)
	if not session or (session.nextCycle or 0) > CurTime() then return end
	session.nextCycle = CurTime() + 0.15

	local _, options, index = ResolveChoice(session)
	if #options == 0 then return end

	local nextIndex = index % #options + 1
	session.wound = options[nextIndex].wound

	net.Start("hg_suture_target")
		WriteChoice(options[nextIndex], nextIndex, #options)
	net.Send(ply)
end)

net.Receive("hg_suture_event", function(len, ply)
	local session = GetValidSession(ply)
	if not session or (session.nextEvent or 0) > CurTime() then return end
	session.nextEvent = CurTime() + 0.08

	local event = net.ReadUInt(2)
	local org = session.target.organism
	if event == EVENT_PUNCTURE then
		org.painadd = (org.painadd or 0) + 1.5
	elseif event == EVENT_SLIP then
		org.painadd = (org.painadd or 0) + 7
		org.fearadd = (org.fearadd or 0) + 0.05
		local target = hg.GetCurrentCharacter(session.target)
		if IsValid(target) then
			target:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 55, math.random(110, 130))
		end
	end
end)

net.Receive("hg_suture_finish", function(len, ply)
	local session = GetValidSession(ply)
	if not session then return end

	local option = ResolveChoice(session)
	if option and GetSupply(session) > 0 then
		hg.Suture.Apply(ply, session, option)
	end

	EndSession(ply, option ~= nil)
end)

net.Receive("hg_suture_cancel", function(len, ply)
	EndSession(ply, false)
end)

hook.Add("PlayerDeath", "hg_suture_clear", function(ply)
	EndSession(ply, false)
	for healer, session in pairs(hg.Suture.Sessions) do
		if session.target == ply then EndSession(healer, false) end
	end
end)
