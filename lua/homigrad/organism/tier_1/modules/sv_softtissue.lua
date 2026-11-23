local SoftTissue = hg.SoftTissue
local organism = hg.organism
local CONFIG = SoftTissue.Config

local LIMBS = SoftTissue.LIMBS
local FIELDS = SoftTissue.FIELDS
local HEAL_EPSILON = 0.001
local FRACTURE_LIMBS = {larm = true, rarm = true, lleg = true, rleg = true}
local MUSCLE_TYPES = bit.bor(
	DMG_CLUB, DMG_CRUSH, DMG_FALL, DMG_VEHICLE, DMG_BLAST,
	DMG_BURN, DMG_SLOWBURN, DMG_PLASMA, DMG_ENERGYBEAM
)
local REGEN = {
	restBase = 1.25,
	fedMul = 1.25,
	fedTime = 300,
}

organism.module.softtissue = {}

local module = organism.module.softtissue

local function newLimbTable()
	local values = {}
	for _, limb in ipairs(LIMBS) do
		values[limb] = 0
	end

	return values
end

module[1] = function(org)
	org.softBrute = newLimbTable()
	org.softBurn = newLimbTable()
	org.muscle = newLimbTable()
	org.deepBrute = newLimbTable()
	org.deepBurn = newLimbTable()
	org.softLastDamage = 0
	org.softPain = 0
end

function SoftTissue.Add(org, kind, limb, amount)
	local values = org and org[FIELDS[kind]]
	if not values or not amount or amount <= 0 then return 0 end

	limb = values[limb] and limb or "torso"

	local before = values[limb]
	values[limb] = math.min(before + amount, CONFIG.limbMax)
	org.softLastDamage = CurTime()

	return values[limb] - before
end

local function worstLimb(values, maxRank)
	local worst, worstValue = nil, 0
	for _, limb in ipairs(LIMBS) do
		local value = values[limb]
		if value > worstValue and (not maxRank or SoftTissue.GetSeverityRank(value) <= maxRank) then
			worst, worstValue = limb, value
		end
	end

	return worst
end

function SoftTissue.GetWorstLimb(org, kinds, maxRank)
	local worst, worstValue = nil, 0
	for _, limb in ipairs(LIMBS) do
		local value = 0
		for _, kind in ipairs(kinds) do
			local amount = kind == "muscle" and SoftTissue.GetMuscle(org, limb) * CONFIG.impairment.softFull
				or SoftTissue.Get(org, kind, limb)
			if not maxRank or kind == "muscle" or SoftTissue.GetSeverityRank(amount) <= maxRank then
				value = value + amount
			end
		end

		if value > worstValue then worst, worstValue = limb, value end
	end

	return worst
end

function SoftTissue.Heal(org, kind, limb, amount, maxRank)
	local values = org and org[FIELDS[kind]]
	if not values or not amount or amount <= 0 then return 0 end

	local healed = 0
	while amount - healed > HEAL_EPSILON do
		local target = limb or worstLimb(values, maxRank)
		local current = target and values[target] or 0
		if current <= 0 or (maxRank and SoftTissue.GetSeverityRank(current) > maxRank) then break end

		local part = math.min(current, amount - healed)
		values[target] = current - part
		healed = healed + part
		if limb then break end
	end

	return healed
end

function SoftTissue.HealMuscle(org, limb, amount)
	local muscle = org and org.muscle
	local current = muscle and muscle[limb] or 0
	if current <= 0 or not amount or amount <= 0 then return 0 end

	muscle[limb] = math.max(current - amount, 0)

	return current - muscle[limb]
end

function SoftTissue.GetRegenMul(org)
	local mul = organism.RecoveryMul(org) / REGEN.restBase
	if (tonumber(org.thiamine) or 0) > 0 then mul = mul * CONFIG.regen.thiamineMul end
	if CurTime() - (org._satietyLastClimbed or -REGEN.fedTime) < REGEN.fedTime then mul = mul * REGEN.fedMul end

	return mul
end

local BANDAGE_KEYS = {head = "skull", torso = "chest"}

local function getBandageMul(org, limb)
	if not hg.GetBandageRegenMultiplier or not IsValid(org.owner) then return 1 end

	return math.min(hg.GetBandageRegenMultiplier(org.owner, BANDAGE_KEYS[limb] or limb) or 1, CONFIG.regen.bandageMaxMul)
end

local function regenValue(value, rate, mul)
	if value <= 0 then return value end
	if value > CONFIG.lightWound then mul = mul * CONFIG.regen.heavyMul end

	return math.max(value - rate * mul, 0)
end

function SoftTissue.Regen(org, timeValue, bruteRate, burnRate)
	if not org.softBrute then return end

	local mul = SoftTissue.GetRegenMul(org) * timeValue
	for _, limb in ipairs(LIMBS) do
		local limbMul = mul * getBandageMul(org, limb)
		org.softBrute[limb] = regenValue(org.softBrute[limb], bruteRate, limbMul)
		org.softBurn[limb] = regenValue(org.softBurn[limb], burnRate, limbMul)
	end

	local muscleConfig = CONFIG.muscle
	for limb in pairs(muscleConfig.limbs) do
		local damage = org.muscle[limb]
		if damage > 0 and damage <= muscleConfig.lightBelow then
			org.muscle[limb] = math.max(damage - mul / muscleConfig.regenTime, 0)
		end
	end
end

local ARM_LIMBS = {larm = true, rarm = true}
local LEG_LIMBS = {lleg = true, rleg = true}
local EMPTY_HANDS = {weapon_hg_coolhands = true, weapon_hands = true}

local function getLimbUseTarget(owner, limb)
	if not IsValid(owner) or not owner:IsPlayer() then return 1 end

	if LEG_LIMBS[limb] then
		local org = owner.organism
		local ragdolled = IsValid(owner.FakeRagdoll) or org and org.fake
		return (not ragdolled and owner:OnGround()) and 1 or 0
	end

	local wep = owner:GetActiveWeapon()
	local armed = IsValid(wep) and not EMPTY_HANDS[wep:GetClass()]
	return (armed or owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2) or owner:KeyDown(IN_USE)) and 1 or 0
end

function SoftTissue.UpdateLimbUse(org, timeValue)
	local use = org.softUse
	if not use then use = {} org.softUse = use end

	local owner = org.owner
	for limb in pairs(FRACTURE_LIMBS) do
		local target = org.otrub and 0 or getLimbUseTarget(owner, limb)
		use[limb] = math.Approach(use[limb] or 0, target, timeValue * (target > (use[limb] or 0) and 4 or 1.5))
	end
end

function SoftTissue.GetPainLoad(org, ignoreUse)
	if not org.softBrute then return 0 end

	local painConfig = CONFIG.pain
	local owner = org.owner
	local use = org.softUse
	local total, worst = 0, 0
	for _, limb in ipairs(LIMBS) do
		local soft = SoftTissue.GetLimb(org, limb)
		local pain = soft > CONFIG.lightWound and soft * painConfig.soft or 0
		pain = pain + SoftTissue.GetMuscle(org, limb) * painConfig.muscle

		if FRACTURE_LIMBS[limb] and hg.IsLimbFractured(org, limb) then
			local splinted = hg.IsLimbSplinted and IsValid(owner) and hg.IsLimbSplinted(owner, limb)
			pain = pain + (splinted and painConfig.splintedFracture or painConfig.fracture)
		end

		if not ignoreUse and FRACTURE_LIMBS[limb] then pain = pain * (use and use[limb] or 0) end

		total = total + pain
		worst = math.max(worst, pain)
	end

	return math.min(total + worst * painConfig.worstExtra, painConfig.max)
end

local function tryArmDrop(org, limb, dmgInfo)
	local impairment = CONFIG.impairment
	local severity = math.max(SoftTissue.GetMuscle(org, limb), SoftTissue.GetSoftImpairment(org, limb))
	if severity < impairment.dropAt then return end

	local owner = org.owner
	if not IsValid(owner) or not owner:IsPlayer() or not hg.DropWeaponFromImpact then return end

	local depth = (severity - impairment.dropAt) / (1 - impairment.dropAt)
	if math.Rand(0, 1) > Lerp(depth, impairment.dropChance * 0.3, impairment.dropChance) then return end

	local force = dmgInfo:GetDamageForce()
	timer.Simple(0, function()
		if not IsValid(owner) or not owner:Alive() or owner.organism ~= org then return end

		local wep = owner:GetActiveWeapon()
		if IsValid(wep) then hg.DropWeaponFromImpact(owner, wep, force, impairment.dropStrength) end
	end)
end

local function tryHeadKnockout(org, applied)
	local impairment = CONFIG.impairment
	local severity = SoftTissue.GetSoftImpairment(org, "head")
	if severity <= 0 then return end

	local strength = math.Clamp(applied / impairment.headKnockoutDamage, 0, 1)
	if math.Rand(0, 1) > severity * strength * impairment.headKnockoutChance then return end

	local now = CurTime()
	local until_ = now + Lerp(severity, impairment.headKnockoutMin, impairment.headKnockoutMax)
	if until_ > (org.postureOtrubUntil or 0) then org.postureOtrubUntil = until_ end
	org.needotrub = true
	org.needfake = true
	org.consciousness = math.min(tonumber(org.consciousness) or 1, 0.04)
end

function SoftTissue.OnLimbDamaged(org, limb, applied, dmgInfo)
	if not applied or applied <= 0 or not org.muscle then return end

	local muscleConfig = CONFIG.muscle
	if not org.simpleMode and muscleConfig.limbs[limb] and dmgInfo:IsDamageType(MUSCLE_TYPES) then
		local over = math.min(applied, math.max(SoftTissue.GetLimb(org, limb) - muscleConfig.threshold, 0))
		org.muscle[limb] = math.min(org.muscle[limb] + over * muscleConfig.ratio, muscleConfig.max)
	end

	if limb == "larm" or limb == "rarm" then tryArmDrop(org, limb, dmgInfo) end
	if limb == "head" then tryHeadKnockout(org, applied) end
end

local function addWithDeep(org, kind, limb, amount)
	local deep = CONFIG.deep
	local mangled = SoftTissue.Get(org, kind, limb) >= deep.at
	local applied = SoftTissue.Add(org, kind, limb, amount)

	local values = mangled and org[SoftTissue.DEEP_FIELDS[kind]]
	if values and values[limb] and amount > 0 then
		values[limb] = math.min(values[limb] + amount * deep.mul, deep.max)
	end

	return applied
end

local function clearDeep(org, amount)
	for _, field in pairs(SoftTissue.DEEP_FIELDS) do
		local values = org[field]
		if values then
			for limb, value in pairs(values) do
				if value > 0 then values[limb] = math.max(value - amount, 0) end
			end
		end
	end
end

hook.Add("HomigradDamage", "hg/softtissue/damage", function(victim, dmgInfo, hitgroup)
	local org = IsValid(victim) and victim.organism
	if not org or not org.softBrute or org.simpleMode then return end

	local damage = dmgInfo:GetDamage()
	if damage <= 0 then return end
	damage = damage * hg.SimpleHealth.FireTickScale(dmgInfo)

	local pool = hg.SimpleHealth.ClassifyDamage(dmgInfo)
	if not FIELDS[pool] then return end

	local limb = SoftTissue.HITGROUP_LIMBS[hitgroup] or "torso"
	if pool == "brute" then damage = damage * SoftTissue.GetDamageProfile(dmgInfo) end
	local applied
	if pool == "burn" and dmgInfo:IsDamageType(DMG_BLAST) then
		local burnShare = hg.SimpleHealth.Config.damage.blastBurnShare
		applied = addWithDeep(org, "brute", limb, damage * (1 - burnShare))
		applied = applied + addWithDeep(org, "burn", limb, damage * burnShare)
	else
		applied = addWithDeep(org, pool, limb, damage)
	end

	SoftTissue.OnLimbDamaged(org, limb, applied, dmgInfo)
end)

module[2] = function(owner, org, timeValue)
	if not org.alive or not org.softBrute then return end

	if not org.simpleMode and CurTime() - org.softLastDamage >= CONFIG.passiveDelay then
		SoftTissue.Regen(org, timeValue, CONFIG.passiveRegen.brute, CONFIG.passiveRegen.burn)
	end

	if (tonumber(org.thiamine) or 0) > 0 then clearDeep(org, CONFIG.deep.thiamineClear * timeValue) end

	SoftTissue.UpdateLimbUse(org, timeValue)
	org.softPain = SoftTissue.GetPainLoad(org)

	local impairment = CONFIG.impairment
	local torsoMuscle = org.muscle.torso
	if torsoMuscle > 0 and org.stamina then
		org.stamina.subadd = (org.stamina.subadd or 0) + torsoMuscle * impairment.torsoStaminaDrain
	end

	local head = SoftTissue.GetLimb(org, "head")
	if head > impairment.headStart then
		local severity = math.Clamp((head - impairment.headStart) / (impairment.softFull - impairment.headStart), 0, 1)
		org.disorientation = math.max(org.disorientation or 0, severity * impairment.headDisorientation)
	end
end

local STRUCTURE_INPUTS = {
	"skull", "jaw", "chest", "pelvis",
	"larmup", "larmdown", "rarmup", "rarmdown",
	"llegup", "llegdown", "rlegup", "rlegdown",
	"heart", "liver", "flank", "gut", "lungsL", "lungsR",
}

local BONE_FIELDS = {
	skull = "skull", jaw = "jaw", chest = "chest", pelvis = "pelvis",
	larmup = "larm_up", larmdown = "larm_down", rarmup = "rarm_up", rarmdown = "rarm_down",
	llegup = "lleg_up", llegdown = "lleg_down", rlegup = "rleg_up", rlegdown = "rleg_down",
}

local function applyBoneTrauma(org, name, before)
	local after = tonumber(org[BONE_FIELDS[name]])
	if not before or not after then return end

	local trauma = CONFIG.boneTrauma
	local delta = after - before
	if delta < trauma.minDelta then return end

	local limb = CONFIG.boneLimbs[name] or string.sub(name, 1, 4)
	local amount = delta * trauma.perDamage
	local fractured = before < 1 and after >= 1
	if fractured then amount = amount + trauma.fracture end

	SoftTissue.Add(org, "brute", limb, amount)

	local muscleConfig = CONFIG.muscle
	if fractured and muscleConfig.limbs[limb] then
		org.muscle[limb] = math.min(org.muscle[limb] + trauma.muscleOnFracture, muscleConfig.max)
	end
end

SoftTissue.InputWrappers = SoftTissue.InputWrappers or {}

hg.InputWrapperInner = hg.InputWrapperInner or setmetatable({}, {__mode = "k"})

hg.InputWrapperChainHas = hg.InputWrapperChainHas or function(fn, target)
	while fn do
		if fn == target then return true end
		fn = hg.InputWrapperInner[fn]
	end

	return false
end

local function wrapInput(inputList, name)
	local original = inputList[name]
	if not isfunction(original) or hg.InputWrapperChainHas(original, SoftTissue.InputWrappers[name]) then return end

	local isOrgan = CONFIG.organInputs[name]
	local boneField = BONE_FIELDS[name]
	local function wrapper(org, bone, dmg, dmgInfo, ...)
		if not org.softBrute or not isnumber(dmg) or not dmgInfo or not dmgInfo.IsDamageType then
			return original(org, bone, dmg, dmgInfo, ...)
		end

		if not isOrgan then
			local _, structure = SoftTissue.GetDamageProfile(dmgInfo)
			dmg = dmg * structure
		end

		dmg = dmg * SoftTissue.GetAccessMul(org, name)

		if not boneField or org.simpleMode then return original(org, bone, dmg, dmgInfo, ...) end

		local before = tonumber(org[boneField])
		local results = {original(org, bone, dmg, dmgInfo, ...)}
		applyBoneTrauma(org, name, before)

		return unpack(results, 1, table.maxn(results))
	end

	SoftTissue.InputWrappers[name] = wrapper
	hg.InputWrapperInner[wrapper] = original
	inputList[name] = wrapper
end

function SoftTissue.WrapInputs()
	local inputList = organism.input_list
	if not inputList then return end

	for _, name in ipairs(STRUCTURE_INPUTS) do
		wrapInput(inputList, name)
	end
end

SoftTissue.WrapInputs()
hook.Add("InitPostEntity", "hg/softtissue/wrap-inputs", function()
	timer.Simple(0, SoftTissue.WrapInputs)
end)
