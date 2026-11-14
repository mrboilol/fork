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
	hardCritHealth = -50,
	adrenalineCritBonus = 20,
	adrenalineFull = 4,
	deathBlood = 2500,
	brainDeath = 0.4,

	damage = {
		bruteScale = 1,
		burnScale = 1,
		toxinScale = 1,
		oxyScale = 1,
		blastBurnShare = 0.5,
		bruteRegen = 0,
		burnRegen = 0,
	},

	oxy = {
		softCritCap = 20,
		softCritGain = 1,
		hardCritGain = 2,
		deliveryFull = 0.6,
		deliveryGain = 5,
		regen = 2,
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
		heartDestroyedGain = 8,
		sedativeGain = 1,
		lungGain = 1.5,
	},

	toxin = {
		regen = 0.15,
		thiamineHeal = 1.5,
		thiamineContaminationClear = 0.02,
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
		normalBlood = 5000,
		transfusionMinMl = 0.5,
	},

	medicine = {
		kitCost = 0.25,
		kitMinDamage = 1,
		kitHeal = {brute = 25, burn = 20},
		kitHealedScore = 0.25,
		bandageBurnHeal = 10,
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
		softCritStrength = 0.5,
		softCritColor = Color(150, 0, 0),
		softCritPulseSpeed = 2.2,
	},

	face = {
		x = 0.012,
		y = 0.62,
		size = 0.075,
		dominantMin = 25,
		states = {
			{key = "dead", label = "X_X", color = Color(70, 70, 70)},
			{key = "hardcrit", label = "-_-", color = Color(120, 30, 30)},
			{key = "softcrit", label = ">_<", color = Color(190, 40, 40)},
			{key = "badly_hurt", label = "T_T", color = Color(215, 110, 40)},
			{key = "hurt", label = ":/", color = Color(215, 195, 60)},
			{key = "healthy", label = ":)", color = Color(80, 190, 90)},
		},
		hurtBelow = 75,
		badlyHurtBelow = 25,
		tints = {
			brute = Color(220, 50, 50),
			burn = Color(240, 140, 40),
			toxin = Color(80, 200, 80),
			oxy = Color(70, 140, 240),
		},
		materialPath = "hg_simplehealth/face_%s.png",
	},

	chat = {
		faintHearChance = 0.5,
		faintHearRange = 300,
		faintGunfireRange = 1500,
		faintKeepMin = 0.35,
		faintKeepMax = 0.7,
		faintSoundCooldown = 6,
		thoughtCooldown = 25,
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
	local best, bestValue = nil, SimpleHealth.Config.face.dominantMin
	for _, pool in ipairs(SimpleHealth.POOLS) do
		local value = state[pool] or 0
		if value >= bestValue then
			best, bestValue = pool, value
		end
	end

	return best
end
