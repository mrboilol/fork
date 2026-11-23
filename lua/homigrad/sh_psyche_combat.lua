hg = hg or {}

hg.PsycheCombat = {
	trainedLineThreshold = 0.6,

	trainedPanicGainMul = 0.6,
	trainedDepressionMul = 0.5,
	noDepressionSurge = 1.5,
	noDepressionSurgeCap = 1.2,
	noDepressionHappinessCost = 2,
	noDepressionTraumaGain = 2,
	noDepressionTraumaMul = 0.6,
	noDepressionTraumaDecay = 150,
	trainedAngerMul = 1.6,
	panicBraceStart = 0.15,
	panicBraceFull = 0.6,
	panicTripAdd = 0.08,
	panicTripMul = 1.5,
	sorrowPanicNumb = 0.6,
	sorrowAdrenalineNumb = 0.65,
	outnumberedPanicWeight = 1,
	surpriseHitMul = 1.5,
	surpriseDot = -0.2,
	trainedDecayBonus = 0.6,
	coverDecayMul = 1.5,
	coverCheckInterval = 1,
	coverMemory = 20,
	calmDecayMul = 1.4,
	calmAfter = 6,
	meleeRadius = 110,
	meleeDot = 0.75,
	meleePanic = 0.07,
	meleeCooldown = 1.2,
	o2PanicStart = 18,
	o2PanicFull = 6,
	o2PanicRate = 0.12,
	chokingPanic = 0.5,
	shotAtWindow = 3,
	shotAtCount = 5,

	crashMinPeak = 1.5,
	crashEnd = 0.4,
	crashScalePeak = 3.5,
	crashMinStrength = 0.3,
	crashDuration = 25,
	crashMaskAdrenaline = 1.5,
	crashInstability = 0.25,
	crashTempo = 0.85,
	crashPower = 0.92,
	crashExertion = 1.2,
	crashAim = 1.1,
	adrenalineMoveBonus = 0.05,

	focusPanicLow = 0.1,
	focusPanicPeak = 0.3,
	focusPanicHigh = 0.55,
	focusAim = 0.85,
	focusTempo = 1.06,
	focusSteady = 0.8,

	tremorAdrenaline = 1.2,
	tremorCrash = 0.8,
	tremorO2 = 1.2,
	tremorBlood = 1.2,
	tremorStamina = 0.5,
	tremorCap = 2.2,
	tremorFreq = 12,
	tremorForce = 120,
	o2TremorStart = 22,
	o2TremorFull = 8,
	bloodTremorStart = 4200,
	bloodTremorFull = 2800,
	trainedShakeMul = 0.65,

	breathRate = 0.22,
	breathPanicRate = 1.6,
	breathForce = 14,
	breathPanicAmp = 2,
	breathHoldMul = 0.15,
	breathBraceMul = 0.6,
	breathYaw = 0.35,

	flinchPanic = 1.2,
	flinchMaxMul = 2.4,
	trainedFlinchMul = 0.7,

	snatchStart = 0.7,
	snatchMaxDeg = 1.1,
	trainedSnatchMul = 0.5,

	bystanderDeathRadius = 450,
	bystanderDeathSorrow = 0.2,
	corpseSorrow = 0.15,
	firstKillSorrow = 0.15,
	firstKillTrainingMax = 0.5,
	isolationRadius = 1500,
	isolationCheck = 2,
	isolationTime = 15,
	isolationRate = 0.002,
	isolationBlood = 4300,
	isolationPain = 60,

	angerShieldStart = 0.15,
	angerShieldFull = 0.75,
	angerPanicShield = 0.75,
	angerPanicDrainStart = 0.35,
	angerPanicDrain = 0.06,
	angerFightAt = 0.3,
	angerTunnelStart = 0.2,
	angerTunnelFull = 0.8,
	angerThoughtAt = 0.5,
	angerPower = 0.3,
	angerResilience = 0.85,
	moodPeakMemory = 45,
	depressionMemoryTime = 90,
	leanBase = 0.1,
	leanMood = 0.8,
	leanDepression = 1.4,
	leanMin = 0.05,
	leanMax = 0.95,
	fightDepressionMul = 0.3,
	angerOpponentDecayMul = 0,
	angerHappinessBlock = 0.85,
	angerDepressionAfter = 25,
	angerDepressionRate = 0.01,
	angerDownRelief = 0.3,
	angerDownHappiness = 0.12,
	angerFakeAfter = 6,
	angerFakeFadeMul = 6,
	angerDownFadeMul = 12,
	angerDownDepression = 0.6,
	betaBlockMul = 0.2,
	disengageAfter = 6,
	angerDisengageDecay = 0.05,
	angerFleeDistance = 600,
	angerFleeDepression = 0.25,
	angerFleePanic = 0.8,
	fleeReliefDuration = 8,
	adrenalineIdleAfter = 15,
	adrenalineIdleRamp = 20,
	adrenalineIdleMul = 4,
	adrenalineSustainCap = 10,
	successCooldown = 0.4,
	hitRelief = 0.012,
	blockRelief = 0.02,
	parryRelief = 0.05,
	winRelief = 0.01,
	killRelief = 0.25,

	panicThoughtAt = 0.5,
	adrenalineThoughtAt = 2,
	thoughtGlobalCooldown = 8,
	thoughtRepeatWindow = 60,
	thoughtDuration = 4,
	thoughtCooldowns = {
		panic = 25,
		adrenaline = 30,
		crash = 40,
		shotAt = 20,
		witness = 20,
		corpse = 45,
		firstKill = 0,
		isolation = 90,
		anger = 30,
	},
	thoughtPriority = {
		firstKill = true,
		witness = true,
		isolation = true,
	},
}

function hg.GetPsycheTraining(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not hg.GetCombatTraining then return 0 end

	return math.Clamp(tonumber(hg.GetCombatTraining(ply)) or 0, 0, 1)
end

function hg.IsPsycheApathetic(ply)
	return IsValid(ply) and ply.HasTrait and ply:HasTrait("apathetic") or false
end

function hg.GetPanicLevel(org)
	local K = hg.PsycheCombat
	local panic = math.Clamp(tonumber(org and org.panicattack) or 0, 0, 1)

	return math.Clamp((panic - K.panicBraceStart) / (K.panicBraceFull - K.panicBraceStart), 0, 1)
end

function hg.GetAngerShield(org)
	local K = hg.PsycheCombat
	local anger = math.Clamp(tonumber(org and (org.anger or org.psycheAnger)) or 0, 0, 1)

	return math.Clamp((anger - K.angerShieldStart) / (K.angerShieldFull - K.angerShieldStart), 0, 1)
end

function hg.GetPsycheFlinchMul(ply)
	local org = IsValid(ply) and ply.organism
	if not org then return 1 end

	local K = hg.PsycheCombat
	local panic = math.Clamp(tonumber(org.panicattack) or 0, 0, 1)

	return math.min((1 + panic * K.flinchPanic) * Lerp(hg.GetPsycheTraining(ply), 1, K.trainedFlinchMul), K.flinchMaxMul)
end
