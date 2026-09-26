--[[
	The two lines Z-City's pulse check leaves out.

	Z-City already tells you the heart, the warmth, the bleed and what it was
	shot with (weapon_hands_sh.lua:930). It never says whether anybody is home —
	that line is written and commented out (:1000, `org.otrub and "No reaction."`)
	— and it never counts broken bones. This is those two lines, printed from
	inside the same Think, after that reading, under the same conditions: the
	same hands, the same grip on a hand or the head, the same armour that stops
	the check on a combine soldier. Nothing else. If Z-City did not check, we
	do not either.

	Out cold is org.otrub (or consciousness already gone). org.fake and
	ZCNPC.Downed are not that — every body we put on the floor has both,
	including one that is still writhing.
]]

local cfg = ZCNPC.Config

local HANDS = {
	weapon_hands_sh = true,
	weapon_hg_coolhands = true,
}

-- The three places Z-City will let you feel for a pulse
local pulseBones = {
	["ValveBiped.Bip01_L_Hand"] = true,
	["ValveBiped.Bip01_R_Hand"] = true,
	["ValveBiped.Bip01_Head1"] = true,
}

-- Z-City's HUD fracture line is 0.999 (weapon_hands_sh.lua:620). An NPC leg
-- already fails and drops them at zcnpc_limb_threshold (~0.45), and a splint
-- is offered at 0.3 — those are bones you can feel, even if they never reached
-- a full break.
local LIMB_BREAK = 0.3

-- One press, one reading. Reload is held down as readily as it is tapped.
local RECHECK = 0.5

local function BoneName(rag, physbone)
	if not (IsValid(rag) and isnumber(physbone) and physbone >= 0) then return end

	local bone = rag:TranslatePhysBoneToBone(physbone)
	if not (bone and bone >= 0) then return end

	return rag:GetBoneName(bone)
end

-- Same lookup Z-City uses (weapon_hands_sh.lua:927): the ragdoll's owner when
-- it has one, the body itself otherwise.
local function PulseBody(rag)
	local owner = isfunction(hg.RagdollOwner) and hg.RagdollOwner(rag)

	return IsValid(owner) and owner or rag
end

local function LimbBroken(org, name)
	if org[name .. "amputated"] or org[name .. "dislocation"] then return true end

	return (org[name] or 0) > LIMB_BREAK
end

-- How many major bones are gone: arms, legs, skull, chest, three spine segments.
-- Dislocations and amputations count — they are as useless as a break for standing.
local function BrokenBones(org)
	local n = 0

	if LimbBroken(org, "lleg") then n = n + 1 end
	if LimbBroken(org, "rleg") then n = n + 1 end
	if LimbBroken(org, "larm") then n = n + 1 end
	if LimbBroken(org, "rarm") then n = n + 1 end

	if (org.skull or 0) >= 0.6 then n = n + 1 end
	if (org.chest or 0) >= 1 then n = n + 1 end

	local spine1 = istable(hg) and istable(hg.organism) and hg.organism.fake_spine1 or 1
	local spine2 = istable(hg) and istable(hg.organism) and hg.organism.fake_spine2 or 1
	local spine3 = istable(hg) and istable(hg.organism) and hg.organism.fake_spine3 or 0.5

	if (org.spine1 or 0) >= spine1 then n = n + 1 end
	if (org.spine2 or 0) >= spine2 then n = n + 1 end
	if (org.spine3 or 0) >= spine3 then n = n + 1 end

	if org.jawdislocation then n = n + 1 end

	return n
end

-- Nobody home. Not the same thing as being on the floor: org.fake is "the
-- organism wants this body lying down" (sv_organism.lua:526) and ZCNPC.Downed
-- is every ragdoll we made, knockdown included. A body thrashing on the floor
-- has both and is still awake. Same test ZCNPC.IsBodySilent uses.
local function IsOut(org)
	if org.otrub then return true end
	if (org.consciousness or 1) <= 0.4 then return true end

	return false
end

local function ExtraReport(ply, org)
	-- A corpse still has bones. Reaction is only for someone who is still a
	-- person — Z-City already said "No pulse" if they are not.
	if org.alive ~= false then
		if IsOut(org) then
			ply:ChatPrint("Knocked out.")
		else
			ply:ChatPrint("Reaction present.")
		end
	end

	local broken = BrokenBones(org)

	if broken == 0 then
		ply:ChatPrint("No broken bones.")
	elseif broken == 1 then
		ply:ChatPrint("You feel 1 broken bone.")
	else
		ply:ChatPrint("You feel " .. broken .. " broken bones.")
	end
end

-- The same gate Z-City uses, asked after its Think has already printed.
local function AfterCityPulse(wep)
	if not (ZCNPC.Enabled() and cfg.pulse_info:GetBool()) then return end

	local ply = wep:GetOwner()
	if not (IsValid(ply) and ply:IsPlayer()) then return end
	if not ply:KeyPressed(IN_RELOAD) then return end
	if (ply.zcnpc_pulse_at or 0) > CurTime() then return end

	local rag = wep.CarryEnt
	if not (IsValid(rag) and rag:GetClass() == "prop_ragdoll") then return end
	if not pulseBones[BoneName(rag, wep.CarryBone) or ""] then return end

	local body = PulseBody(rag)
	local org = IsValid(body) and body.organism
	if not istable(org) then return end
	if body.noHead or org.CantCheckPulse then return end

	ply.zcnpc_pulse_at = CurTime() + RECHECK
	ExtraReport(ply, org)
end

-- Functions are not tables in GMod Lua — marking the wrapper with a field
-- on Think itself is `attempt to index field 'Think' (a function value)`.
local wrappedThinks = setmetatable({}, { __mode = "k" })

local function WrapThink(swep)
	if not swep or not isfunction(swep.Think) then return end
	if wrappedThinks[swep.Think] then return end
	if swep._ZCNPCPulseThink then return end

	local old = swep.Think
	local wrapped = function(self)
		old(self)
		AfterCityPulse(self)
	end

	wrappedThinks[wrapped] = true
	swep.Think = wrapped
	swep._ZCNPCPulseThink = true
end

local function Install()
	for class in pairs(HANDS) do
		local stored = weapons.GetStored(class)
		if stored then WrapThink(stored) end
	end

	for _, wep in ipairs(ents.FindByClass("weapon_hands_sh")) do
		WrapThink(wep)
	end

	for _, wep in ipairs(ents.FindByClass("weapon_hg_coolhands")) do
		WrapThink(wep)
	end
end

Install()
hook.Add("HomigradRun", "zcnpc_pulse", function()
	timer.Simple(0, Install)
end)

hook.Add("OnEntityCreated", "zcnpc_pulse", function(ent)
	if not (IsValid(ent) and HANDS[ent:GetClass()]) then return end

	timer.Simple(0, function()
		if IsValid(ent) then WrapThink(ent) end
	end)
end)
