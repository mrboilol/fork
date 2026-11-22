hg = hg or {}
hg.SimpleHealth = hg.SimpleHealth or {}

local SimpleHealth = hg.SimpleHealth

SimpleHealth.MODE_OFF = 0
SimpleHealth.MODE_SIMPLE = 1
SimpleHealth.MODE_ORGANS = 2

SimpleHealth.CRIT_NONE = 0
SimpleHealth.CRIT_SOFT = 1
SimpleHealth.CRIT_HARD = 2

SimpleHealth.NET_MODE_BITS = 2
SimpleHealth.NET_CRIT_BITS = 2
SimpleHealth.NET_POOL_BITS = 9
SimpleHealth.NET_POOL_MAX = 511
SimpleHealth.NET_FAINT_BITS = 2

SimpleHealth.FAINT_SPEECH = 1
SimpleHealth.FAINT_FOOTSTEPS = 2
SimpleHealth.FAINT_GUNFIRE = 3

SimpleHealth.POOLS = {"brute", "burn", "toxin", "oxy"}

SimpleHealth.ConVar = ConVarExists("hg_simplehealth") and GetConVar("hg_simplehealth") or CreateConVar(
	"hg_simplehealth",
	"0",
	FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
	"0 = Homigrad organism, 1 = simple health, 2 = simple health + simplified organs (changing it fully resets every living player's organism)",
	0,
	2
)

SimpleHealth.Config = {
	maxHealth = 100,
	poolMax = 200,
	softCritHealth = 5,
	hardCritHealth = -50,
	deathHealth = -100,
	spike = {
		window = 2,
		minDamage = 30,
		fullDamage = 80,
		minTime = 6,
		maxTime = 20,
	},
	deathBlood = 2500,
	bleedCountdown = {
		start = 2750,
		rollBelow = 3000,
		rollChance = 0.35,
		time = 30,
	},
	brainDeath = 0.4,
	softCritControlMul = 0.55,
	recentDamageTime = 3,

	damage = {
		bruteScale = 1,
		burnScale = 1,
		fireTickMul = 0.2,
		toxinScale = 1,
		oxyScale = 1,
		blastBurnShare = 0.5,
		passiveDelay = 60,
		passiveBruteRegen = 0.1,
		passiveBurnRegen = 0.08,
		brokenChestAt = 1,
		brokenChestBleedMul = 1.75,
		limbHealth = {head = 0.75, torso = 0.75, larm = 0.2, rarm = 0.2, lleg = 0.2, rleg = 0.2},
	},

	heart = {
		base = 70,
		max = 220,
		approach = 12,
		restartRate = 55,
		pain = 25,
		painFull = 100,
		bloodStart = 4500,
		bloodPeak = 3000,
		bloodGain = 65,
		bloodFloor = 2500,
		bloodClimbStart = 4750,
		bloodClimbEnd = 2750,
		bloodMax = 300,
		sedative = 18,
		opioid = 12,
		coldStart = 36.2,
		coldPerDegree = 9,
		heatStart = 37.6,
		heatPerDegree = 12,
		oxyStart = 25,
		oxyPeak = 75,
		oxyGain = 30,
		oxyCrashTo = 40,
		adrenaline = 18,
		adrenalineCap = 4,
		exertion = 50,
		softCrit = 15,
		pressure = 90,
		systolic = 120,
		diastolic = 80,
		fastStart = 140,
		fastOutputMin = 0.45,
	},

	flatline = {
		softCritChance = 0.004,
		softCritDepthChance = 0.02,
		severeChance = 0.03,
		rateLow = 35,
		rateHigh = 190,
		rateChance = 0.02,
		fastChance = 0.03,
		fastOxyMul = 3,
		certainRate = 300,
		coldStart = 31,
		coldChance = 0.02,
		grace = 20,
		aedSuccess = 0.85,
		cprRestartChance = 0.02,
	},

	fibrillation = {
		rate = 300,
		jitter = 40,
		deathTime = 20,
	},

	consciousness = {
		recover = 0.05,
		softCritDrain = 0,
		softCritDepthDrain = 0,
		bleedStart = 2750,
		bleedDrain = 0.12,
		oxyStart = 50,
		oxyFull = 100,
		oxyDrain = 0.06,
		airwayStart = 25,
		airwayFull = 75,
		airwayDrain = 0.12,
		flatlineDrain = 0.03,
		wakeAt = 0.2,
		hardCritFloor = 0.25,
		depthDrain = 0.04,
	},

	temperature = {
		coldStart = 35,
		coldBurnPerDegree = 0.08,
		heatStart = 39,
		heatBurnPerDegree = 0.12,
		deathColdBelow = 32,
		deathHeatAbove = 40.5,
		deathBloodBelow = 3000,
	},

	oxy = {
		softCritCap = 90,
		softCritGain = 2,
		hardCritGain = 2,
		regen = 2,
		brainDamageStart = 75,
		brainDamageFull = 100,
		brainDamageRate = 0.004,
		countdownStart = 100,
		countdownTime = 45,
		cprHoldAbove = 20,
		airwayCountdownTime = 12,
		countdownTrackAt = 5,
		gaspAt = 50,
		gaspHysteresis = 10,
		aedResistTime = 45,
		aedGainMul = 0.4,
		needleGainMul = 0.7,
		cprClear = 3,
		cprCycle = 0.5,
		cprCritHeal = 1,
		cprCritBudget = 20,
		aedShockAt = 40,
		aedShockClear = 30,
		aedToxinFraction = 0.1,
		aedCritToxinHeal = 8,
		aedCritTissueHeal = 12,
		cprToxinClear = 0.15,
		sedativeGain = 1,
		lungGain = 1.5,
	},

	toxin = {
		regen = 0.15,
		thiamineHeal = 1.5,
		thiamineContaminationClear = 0.1,
		thiamineDamageHeal = 0.5,
		thiamineOrganHeal = 0.01,
		transfusionHealPerMl = 0.03,
		bloodLossHealPerMl = 0.004,
		overdoseGain = 0.75,
		overdoseCap = 3,
		opioidSafeDose = 1.5,
		painkillerSafeDose = 2.4,
		tranquilizerSafeDose = 1,
	},

	contamination = {
		max = 2,
		toxinGain = 2,
		poisonDose = {poison2 = 1, poison4 = 0.8},
		poisonOnset = {poison2 = 25, poison4 = 25},
		wrongBloodPerShock = 1.2,
		wrongBloodToxinPerShock = 20,
		wrongBloodHold = 1,
		normalBlood = 5000,
		transfusionMinMl = 0.5,
	},

	medicine = {
		bandageBruteShare = 0.5,
	},

	organs = {
		heartMax = 0.99,
		liverRegenPenalty = 0.7,
		liverToxinGain = 0.12,
		flankToxinGain = 0.04,
		liverBleedMul = 0.15,
		flankBleedMul = 0.6,
		gutBleedMul = 0.3,
		flankDestroyedToxinGain = 0.05,
		flankDestroyedRegenPenalty = 0.25,
		internalBleedFloor = {liver = 0.5, flank = 0.5, gut = 1.5},
		stunMin = 0.5,
		stunMax = 4,
		stunDamageMin = 0.05,
		destroyedHitPain = 6,
		destroyedHitBleed = 0.15,
		coughNauseaAt = 0.2,
		coughBloodInterval = 20,
		lungGainStart = 0.15,
	},

	effects = {
		lerp = 0.04,
		oxyStart = 0,
		oxyStrong = 75,
		oxyStrongAmount = 0.75,
		oxyCloseAmount = 0.95,
		bloodStart = 4500,
		bloodDarken = 0.35,
		bleedDofStart = 4000,
		bleedDofIntensity = 3,
		softCritStrength = 0.8,
		softCritColor = Color(150, 0, 0),
		softCritPulseSpeed = 2.2,
		critDepthStart = 40,
		critDepthExponent = 1.4,
		critStrengthMax = 2.4,
		critDesaturate = 0.85,
		critDarken = 0.3,
		critDofIntensity = 4,
		damageTintMin = 25,
		traumaVignetteStart = 20,
		traumaVignetteFull = 120,
		traumaVignetteExponent = 1.1,
		traumaVignetteStrength = 1.3,
		traumaVignetteColor = Color(210, 0, 0),
		traumaVignettePulseSpeed = 1.6,
	},

	face = {
		x = 0.012,
		y = 0.012,
		size = 0.075,
		hurtBelow = 75,
		woundedBelow = 55,
		criticalBelow = 30,
		paleBloodBelow = 3500,
		shakeTime = 0.9,
		shakeHit = 0.045,
		deadShake = 0.06,
		deadShakeSpeed = 14,
		materialPath = "nildoy/face_%s.png",
		statusSound = "ouchie.wav",
		statusVolume = 1,
		blipSound = "nilalert.wav",
		blipVolume = 1,
	},

	death = {
		sound = "ouchie.wav",
		delay = 1.05,
		firstPitch = 1,
		secondPitch = 1.35,
		highPitch = 1.35,
		volume = 1,
		muteInterval = 0.5,
	},

	deathCauses = {
		bleed = "You bled out.",
		flatline = "Your heart stopped.",
		fibrillation = "Your heart fibrillated and gave out.",
		suffocate = "You choked to death.",
		brain = "Your brain gave out.",
		toxin = "You were poisoned to death.",
		burn = "You burned to death.",
		brute = "You succumbed to your injuries.",
		neck = "Your neck snapped.",
		suicide = "You took your own life.",
		cold = "You froze to death.",
		heat = "You died of heatstroke.",
		shot = "You were shot dead.",
		blast = "You were blown apart.",
		fall = "You fell to your death.",
		slash = "You were cut down.",
		club = "You were beaten to death.",
		crush = "You were crushed.",
		drown = "You drowned.",
		unknown = "You died.",
	},

	chat = {
		faintHearChance = 0.5,
		faintHearRange = 300,
		faintGunfireRange = 1500,
		faintKeepMin = 0.35,
		faintKeepMax = 0.7,
		faintSoundCooldown = 6,
		thoughtCooldown = 25,
		bloodThoughtLow = 3800,
		bloodThoughtCritical = 3200,
		bloodThoughtHysteresis = 150,
		healthThoughtLow = 75,
		healthThoughtHurt = 50,
		healthThoughtBad = 25,
		healthThoughtDying = 0.5,
		healthThoughtHysteresis = 5,
	},
}

function SimpleHealth.GetHealth(state)
	local config = SimpleHealth.Config

	return config.maxHealth - (state.brute or 0) - (state.burn or 0) - (state.toxin or 0) - (state.oxy or 0)
end

function SimpleHealth.GetCritThresholds()
	local config = SimpleHealth.Config

	return config.softCritHealth, config.hardCritHealth
end

function SimpleHealth.GetCritState(health)
	local softAt, hardAt = SimpleHealth.GetCritThresholds()
	if health <= hardAt then return SimpleHealth.CRIT_HARD end
	if health <= softAt then return SimpleHealth.CRIT_SOFT end

	return SimpleHealth.CRIT_NONE
end

function SimpleHealth.GetCritDepth(state)
	local startAt = SimpleHealth.Config.effects.critDepthStart
	local _, hardAt = SimpleHealth.GetCritThresholds()

	return math.Clamp((startAt - SimpleHealth.GetHealth(state)) / (startAt - hardAt), 0, 1)
end

function SimpleHealth.GetDominantPool(state)
	local best, bestValue = nil, SimpleHealth.Config.effects.damageTintMin
	for _, pool in ipairs(SimpleHealth.POOLS) do
		local value = state[pool] or 0
		if value >= bestValue then
			best, bestValue = pool, value
		end
	end

	return best
end
