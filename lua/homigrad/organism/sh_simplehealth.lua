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
SimpleHealth.NET_POOL_BITS = 8
SimpleHealth.NET_POOL_MAX = 255
SimpleHealth.NET_FAINT_BITS = 2

SimpleHealth.FAINT_SPEECH = 1
SimpleHealth.FAINT_FOOTSTEPS = 2
SimpleHealth.FAINT_GUNFIRE = 3

SimpleHealth.POOLS = {"brute", "burn", "toxin", "oxy"}

SimpleHealth.ConVar = ConVarExists("hg_simplehealth") and GetConVar("hg_simplehealth") or CreateConVar(
	"hg_simplehealth",
	"0",
	FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
	"0 = Homigrad organism, 1 = simple health, 2 = simple health + simplified organs (applies on next spawn)",
	0,
	2
)

SimpleHealth.Config = {
	maxHealth = 100,
	poolMax = 200,
	softCritHealth = 0,
	hardCritHealth = -100,
	deathHealth = -100,
	spike = {
		window = 2,
		minDamage = 30,
		fullDamage = 80,
		minTime = 6,
		maxTime = 20,
	},
	adrenalineCritBonus = 20,
	adrenalineFull = 4,
	deathBlood = 2500,
	brainDeath = 0.4,
	softCritControlMul = 0.55,
	recentDamageTime = 3,

	damage = {
		bruteScale = 1,
		burnScale = 1,
		toxinScale = 1,
		oxyScale = 1,
		blastBurnShare = 0.5,
		passiveDelay = 60,
		passiveBruteRegen = 0.1,
		passiveBurnRegen = 0.08,
		brokenChestAt = 1,
		brokenChestDamageMul = 0.5,
		brokenChestBleedMul = 1.75,
	},

	fracture = {
		limb = 12,
		torso = 15,
		spine = 25,
		neck = 60,
		skull = 25,
		jaw = 8,
	},

	heart = {
		base = 70,
		max = 220,
		approach = 12,
		restartRate = 55,
		adrenaline = 50,
		pain = 25,
		painFull = 100,
		bloodStart = 4500,
		bloodPeak = 3000,
		bloodGain = 65,
		bloodFloor = 2500,
		bloodCrashTo = 35,
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
		bloodStart = 3000,
		bloodChance = 0.02,
		rateLow = 35,
		rateHigh = 190,
		rateChance = 0.02,
		coldStart = 31,
		coldChance = 0.02,
		grace = 20,
		aedSuccess = 0.85,
		cprRestartChance = 0.02,
	},

	consciousness = {
		recover = 0.05,
		softCritDrain = 0.004,
		softCritDepthDrain = 0.03,
		bleedStart = 3500,
		bleedDrain = 0.05,
		oxyStart = 50,
		oxyFull = 100,
		oxyDrain = 0.06,
		flatlineDrain = 0.12,
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
		softCritCap = 20,
		softCritGain = 1,
		hardCritGain = 2,
		deliveryFull = 0.6,
		deliveryGain = 5,
		regen = 2,
		bleedStart = 3500,
		bleedGain = 0.8,
		bleedCap = 70,
		brainDamageStart = 75,
		brainDamageFull = 100,
		brainDamageRate = 0.004,
		countdownStart = 100,
		countdownTime = 30,
		countdownTrackAt = 5,
		gaspAt = 50,
		gaspHysteresis = 10,
		adrenalineGainMul = 0.5,
		adrenalineClear = 0.5,
		aedResistTime = 45,
		aedGainMul = 0.4,
		cprClear = 3,
		cprCycle = 0.5,
		cprCritHeal = 1,
		cprCritBudget = 20,
		aedShockAt = 40,
		aedShockClear = 30,
		aedHeal = 60,
		sedativeGain = 1,
		lungGain = 1.5,
	},

	toxin = {
		regen = 0.15,
		thiamineHeal = 1.5,
		thiamineContaminationClear = 0.02,
		thiamineDamageHeal = 0.5,
		thiamineOrganHeal = 0.01,
		transfusionHealPerMl = 0.03,
		bloodLossHealPerMl = 0.004,
		overdoseGain = 0.25,
		overdoseCap = 3,
		opioidSafeDose = 1.5,
		painkillerSafeDose = 2.4,
		tranquilizerSafeDose = 1,
	},

	contamination = {
		max = 2,
		toxinGain = 0.6,
		poisonDose = {poison2 = 1, poison4 = 0.8},
		poisonOnset = {poison2 = 25, poison4 = 25},
		wrongBloodPerShock = 0.5,
		wrongBloodToxinPerShock = 10,
		wrongBloodHold = 1,
		normalBlood = 5000,
		transfusionMinMl = 0.5,
	},

	medicine = {
		kitCost = 0.25,
		kitMinDamage = 1,
		kitHeal = {brute = 25, burn = 20},
		kitHealedScore = 0.25,
		bandageBurnHeal = 10,
		bandageBruteShare = 0.5,
	},

	organs = {
		heartMax = 0.99,
		liverRegenPenalty = 0.7,
		liverToxinGain = 0.06,
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
		coughBloodAt = 1,
		coughBloodInterval = 20,
		lungGainStart = 0.15,
	},

	effects = {
		lerp = 0.04,
		oxyStart = 20,
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
		damageTintMin = 25,
		damageTintFull = 100,
		damageTintStrength = 0.35,
		damageTintPulseSpeed = 1.2,
		damageTints = {
			toxin = Color(60, 170, 40),
		},
		traumaVignetteStart = 60,
		traumaVignetteFull = 100,
		traumaVignetteStrength = 0.7,
		traumaVignetteColor = Color(190, 0, 0),
		traumaVignettePulseSpeed = 1.6,
	},

	face = {
		x = 0.012,
		y = 0.62,
		size = 0.075,
		hurtBelow = 70,
		criticalBelow = 40,
		paleBloodBelow = 3500,
		shakeTime = 0.55,
		shakeHit = 0.06,
		shakeCrit = 0.04,
		materialPath = "nildoy/face_%s.png",
		statusSound = "ouchie.wav",
		statusVolume = 1,
		blipSound = "nilalert.wav",
		blipVolume = 1,
	},

	death = {
		sound = "ouchie.wav",
		delay = 0.9,
		firstPitch = 1,
		secondPitch = 1.35,
		highPitch = 2.7,
		volume = 1,
		muteInterval = 0.5,
	},

	deathCauses = {
		bleed = "You bled out.",
		flatline = "Your heart stopped.",
		suffocate = "You choked to death.",
		brain = "Your brain gave out.",
		toxin = "You were poisoned to death.",
		burn = "You burned to death.",
		brute = "You succumbed to your injuries.",
		neck = "Your neck snapped.",
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

function SimpleHealth.GetCritThresholds(adrenaline)
	local config = SimpleHealth.Config
	local bonus = math.Clamp((tonumber(adrenaline) or 0) / config.adrenalineFull, 0, 1) * config.adrenalineCritBonus

	return config.softCritHealth - bonus, config.hardCritHealth - bonus
end

function SimpleHealth.GetCritState(health, adrenaline)
	local softAt, hardAt = SimpleHealth.GetCritThresholds(adrenaline)
	if health <= hardAt then return SimpleHealth.CRIT_HARD end
	if health <= softAt then return SimpleHealth.CRIT_SOFT end

	return SimpleHealth.CRIT_NONE
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
