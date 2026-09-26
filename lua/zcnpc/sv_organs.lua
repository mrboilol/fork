--[[
	Organ and artery chance, on top of Z-City's hitboxes.

	The trace either names a liver or it does not. There is no slider in that,
	which is why a blade across the belly so often reads as "the feature is
	broken": the box is small and a standing NPC is a moving target. The
	numbers here are a second roll after a torso or a neck has already been
	hit, so raising them is how a knife that was close still finds something.

	1 is the hitbox and nothing extra. Below 1 is a chance the named organ is
	ignored. Above 1 is the extra roll.
]]

local cfg = ZCNPC.Config

local ORGANS = {
	{ key = "heart", bone = "ValveBiped.Bip01_Spine2" },
	{ key = "liver", bone = "ValveBiped.Bip01_Spine1" },
	{ key = "stomach", bone = "ValveBiped.Bip01_Spine1" },
	{ key = "intestines", bone = "ValveBiped.Bip01_Spine" },
}

local ARTERIES = {
	{ name = "arteria", bone = "ValveBiped.Bip01_Neck1" },
	{ name = "rarmartery", bone = "ValveBiped.Bip01_R_UpperArm" },
	{ name = "larmartery", bone = "ValveBiped.Bip01_L_UpperArm" },
	{ name = "rlegartery", bone = "ValveBiped.Bip01_R_Thigh" },
	{ name = "llegartery", bone = "ValveBiped.Bip01_L_Thigh" },
}

local BLADE = DMG_SLASH + DMG_CLUB
local BALLISTIC = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER + DMG_SLASH

local function Ours(ent)
	if not IsValid(ent) then return false end

	return ent:IsNPC() or ent.zcnpc_npcbody == true
end

local function Chance(cvar, extra)
	local value = cvar and cvar:GetFloat() or 1
	if extra then return math.max(value - 1, 0) end

	return value
end

local function ApplyOrgan(org, key, dmg, dmgInfo)
	local list = istable(hg) and istable(hg.organism) and hg.organism.input_list
	local fn = list and list[key]
	if not isfunction(fn) then
		org[key] = math.min((org[key] or 0) + dmg * 0.15, 1)
		org.internalBleed = (org.internalBleed or 0) + dmg * 0.2

		return
	end

	fn(org, 0, dmg * 0.35, dmgInfo)
end

local function ApplyArtery(org, name, dmgInfo, bone)
	local list = istable(hg) and istable(hg.organism) and hg.organism.input_list
	local fn = list and (list[name] or list.arteria)
	if not isfunction(fn) then return end

	local pos = dmgInfo:GetDamagePosition()
	local dir = dmgInfo:GetDamageForce()
	if dir:LengthSqr() < 1 then dir = Vector(0, 0, 1) else dir = dir:GetNormalized() end

	fn(org, 0, 8, dmgInfo, nil, dir, pos)
end

hook.Add("HomigradDamage", "zcnpc_organs", function(victim, dmgInfo)
	if not ZCNPC.Enabled() then return end
	if not Ours(victim) then return end
	if not istable(dmgInfo) then return end
	if not dmgInfo:IsDamageType(BALLISTIC) then return end

	local org = victim.organism
	if not org or org.alive == false then return end
	if (victim.zcnpc_headwound or 0) > CurTime() then return end

	local dmg = dmgInfo:GetDamage()
	if dmg < 2 then return end

	local organMul = Chance(cfg.organ_chance, false)
	local arteryMul = Chance(cfg.artery_chance, false)

	-- Below 1: a named organ this hit already wrote may be ignored.
	if organMul < 1 and math.Rand(0, 1) > organMul then
		for i = 1, #ORGANS do
			local key = ORGANS[i].key
			local before = org["zcnpc_pre_" .. key]
			if before ~= nil and (org[key] or 0) > before then
				org[key] = before
			end
		end
	end

	local extraOrgan = Chance(cfg.organ_chance, true)
	local extraArtery = Chance(cfg.artery_chance, true)
	if extraOrgan <= 0 and extraArtery <= 0 then return end

	local blade = dmgInfo:IsDamageType(BLADE)
	local bonus = blade and 1.35 or 1

	if extraOrgan > 0 and math.Rand(0, 1) < extraOrgan * 0.35 * bonus then
		local pick = ORGANS[math.random(#ORGANS)]
		ApplyOrgan(org, pick.key, dmg, dmgInfo)
		ZCNPC.Debug("extra organ hit", victim, pick.key)
	end

	if extraArtery > 0 and math.Rand(0, 1) < extraArtery * 0.22 * bonus then
		local pick = ARTERIES[math.random(#ARTERIES)]
		ApplyArtery(org, pick.name, dmgInfo, pick.bone)
		ZCNPC.Debug("extra artery hit", victim, pick.name)
	end
end)
