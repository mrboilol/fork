hg = hg or {}
hg.SoftTissue = hg.SoftTissue or {}

local SoftTissue = hg.SoftTissue

SoftTissue.LIMBS = {"head", "torso", "larm", "rarm", "lleg", "rleg"}
SoftTissue.KINDS = {"brute", "burn"}
SoftTissue.FIELDS = {brute = "softBrute", burn = "softBurn"}

SoftTissue.LIMB_NAMES = {
	head = "Head",
	torso = "Torso",
	larm = "Left arm",
	rarm = "Right arm",
	lleg = "Left leg",
	rleg = "Right leg",
}

SoftTissue.HITGROUP_LIMBS = {
	[HITGROUP_HEAD] = "head",
	[HITGROUP_CHEST] = "torso",
	[HITGROUP_STOMACH] = "torso",
	[HITGROUP_LEFTARM] = "larm",
	[HITGROUP_RIGHTARM] = "rarm",
	[HITGROUP_LEFTLEG] = "lleg",
	[HITGROUP_RIGHTLEG] = "rleg",
}

SoftTissue.Config = {
	limbMax = 200,
	lightWound = 15,
	passiveDelay = 60,
	passiveRegen = {brute = 0.1, burn = 0.08},
	displayMin = 1,

	severity = {
		{at = 80, key = "critical"},
		{at = 40, key = "heavy"},
		{at = 15, key = "moderate"},
		{at = 1, key = "light"},
	},
	severityRank = {light = 1, moderate = 2, heavy = 3, critical = 4},
	wording = {
		brute = {light = "bruised", moderate = "battered", heavy = "mangled", critical = "pulped"},
		burn = {light = "singed", moderate = "burned", heavy = "badly burned", critical = "charred"},
		muscle = {light = "strained muscle", moderate = "torn muscle", heavy = "ruptured muscle", critical = "ruined muscle"},
	},

	muscle = {
		limbs = {torso = true, larm = true, rarm = true, lleg = true, rleg = true},
		threshold = 20,
		ratio = 0.015,
		max = 1,
		lightBelow = 0.2,
		regenTime = 600,
		severity = {
			{at = 0.75, key = "critical"},
			{at = 0.5, key = "heavy"},
			{at = 0.2, key = "moderate"},
			{at = 0.03, key = "light"},
		},
	},

	impairment = {
		softStart = 15,
		softFull = 100,
		softLoss = 0.45,
		muscleLoss = 0.7,
		dropAt = 0.7,
		dropChance = 0.5,
		dropStrength = 0.1,
		torsoStaminaDrain = 0.2,
		headStart = 30,
		headDisorientation = 1.5,
		limbWeight = {rarm = 1.35, larm = 1, lleg = 1, rleg = 1, head = 1, torso = 1},
		legSpeedShare = 0.55,
		headKnockoutChance = 0.45,
		headKnockoutDamage = 10,
		headKnockoutMin = 2,
		headKnockoutMax = 6,
	},

	regen = {
		thiamineMul = 8,
		heavyMul = 0.5,
		bandageMaxMul = 4,
	},

	profiles = {
		{types = bit.bor(DMG_SLASH), tissue = 1.5, structure = 0.65},
		{types = bit.bor(DMG_CLUB, DMG_CRUSH, DMG_FALL, DMG_VEHICLE), tissue = 0.6, structure = 1.3},
	},

	access = {
		rib = 0.6,
		organ = 0.5,
		brokenRibOrganMul = 1.5,
		simpleTorso = 0.5,
		ribsBrokenAt = 1,
	},
	boneLimbs = {
		skull = "head", jaw = "head",
		chest = "torso", pelvis = "torso",
		heart = "torso", liver = "torso", flank = "torso", gut = "torso", lungsL = "torso", lungsR = "torso",
	},
	organInputs = {heart = true, liver = true, flank = true, gut = true, lungsL = true, lungsR = true},

	pain = {
		soft = 0.25,
		muscle = 30,
		fracture = 12,
		splintedFracture = 4,
		worstExtra = 0.5,
		max = 55,
	},
}

SoftTissue.PainSeverity = ConVarExists("pain_severity") and GetConVar("pain_severity") or CreateConVar(
	"pain_severity",
	"1",
	FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
	"Multiplies pain gained and the strength of pain effects",
	0,
	5
)

function hg.GetPainSeverity()
	return SoftTissue.PainSeverity:GetFloat()
end

function SoftTissue.Get(org, kind, limb)
	local values = org and org[SoftTissue.FIELDS[kind]]

	return values and values[limb] or 0
end

function SoftTissue.GetLimb(org, limb)
	return SoftTissue.Get(org, "brute", limb) + SoftTissue.Get(org, "burn", limb)
end

function SoftTissue.GetMuscle(org, limb)
	local muscle = org and org.muscle

	return muscle and muscle[limb] or 0
end

function SoftTissue.Total(org, kind)
	local values = org and org[SoftTissue.FIELDS[kind]]
	if not values then return 0 end

	local total = 0
	for _, limb in ipairs(SoftTissue.LIMBS) do
		total = total + (values[limb] or 0)
	end

	return total
end

function SoftTissue.GetSeverityKey(value, stops)
	for _, stop in ipairs(stops or SoftTissue.Config.severity) do
		if value >= stop.at then return stop.key end
	end
end

function SoftTissue.GetSeverityRank(value, stops)
	return SoftTissue.Config.severityRank[SoftTissue.GetSeverityKey(value, stops)] or 0
end

function SoftTissue.ImpairmentFor(limb, soft)
	local impairment = SoftTissue.Config.impairment
	local range = impairment.softFull - impairment.softStart

	local weight = impairment.limbWeight[limb] or 1

	return math.Clamp((soft - impairment.softStart) / range * weight, 0, 1)
end

function SoftTissue.FunctionFor(limb, soft, muscle)
	local impairment = SoftTissue.Config.impairment

	return (1 - SoftTissue.ImpairmentFor(limb, soft) * impairment.softLoss)
		* (1 - math.Clamp(muscle, 0, 1) * impairment.muscleLoss)
end

function SoftTissue.GetSoftImpairment(org, limb)
	return SoftTissue.ImpairmentFor(limb, SoftTissue.GetLimb(org, limb))
end

function SoftTissue.GetDamageProfile(dmgInfo)
	for _, profile in ipairs(SoftTissue.Config.profiles) do
		if dmgInfo:IsDamageType(profile.types) then return profile.tissue, profile.structure end
	end

	return 1, 1
end

function SoftTissue.GetLegSpeedMul(org, limb)
	local loss = 1 - SoftTissue.GetLimbFunction(org, limb)

	return 1 - loss * SoftTissue.Config.impairment.legSpeedShare
end

function SoftTissue.GetAccessMul(org, name)
	local config = SoftTissue.Config
	local limb = config.boneLimbs[name]
	if not limb or not org.softBrute then return 1 end

	local exposure = math.Clamp(SoftTissue.GetLimb(org, limb) / config.impairment.softFull, 0, 1)
	if config.organInputs[name] then
		local mul = config.access.organ
		if (tonumber(org.chest) or 0) >= config.access.ribsBrokenAt then mul = mul * config.access.brokenRibOrganMul end

		return 1 + exposure * mul
	end

	if name == "chest" or name == "pelvis" then return 1 + exposure * config.access.rib end

	return 1
end

function SoftTissue.GetLimbFunction(org, limb)
	if not org or not org.softBrute then return 1 end

	return SoftTissue.FunctionFor(limb, SoftTissue.GetLimb(org, limb), SoftTissue.GetMuscle(org, limb))
end

function SoftTissue.LimbFromBone(bone)
	if not isstring(bone) then return end
	if string.find(bone, "Head", 1, true) or string.find(bone, "Neck", 1, true) then return "head" end

	local side = string.find(bone, "_L_", 1, true) and "l" or string.find(bone, "_R_", 1, true) and "r"
	if not side then return "torso" end
	if string.find(bone, "Thigh", 1, true) or string.find(bone, "Calf", 1, true)
		or string.find(bone, "Foot", 1, true) or string.find(bone, "Toe", 1, true) then
		return side .. "leg"
	end

	return side .. "arm"
end

function SoftTissue.Describe(org, limb)
	local config = SoftTissue.Config
	local wording = config.wording
	local parts = {}

	for _, kind in ipairs(SoftTissue.KINDS) do
		local key = SoftTissue.GetSeverityKey(SoftTissue.Get(org, kind, limb))
		if key then parts[#parts + 1] = wording[kind][key] end
	end

	local muscleKey = SoftTissue.GetSeverityKey(SoftTissue.GetMuscle(org, limb), config.muscle.severity)
	if muscleKey then parts[#parts + 1] = wording.muscle[muscleKey] end
	if #parts == 0 then return end

	return table.concat(parts, ", ")
end
