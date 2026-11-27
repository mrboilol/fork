util.AddNetworkString("hg_simplehealth")
util.AddNetworkString("hg_simplehealth_faint")
util.AddNetworkString("hg_simplehealth_death")
util.AddNetworkString("hg_simplehealth_hardcrit")

local SimpleHealth = hg.SimpleHealth
local SoftTissue = hg.SoftTissue
local organism = hg.organism
local CONFIG = SimpleHealth.Config
local LIMB_POOLS = SoftTissue.FIELDS

local CRIT_NONE = SimpleHealth.CRIT_NONE
local CRIT_SOFT = SimpleHealth.CRIT_SOFT
local CRIT_HARD = SimpleHealth.CRIT_HARD
local MODE_SIMPLE = SimpleHealth.MODE_SIMPLE
local MODE_ORGANS = SimpleHealth.MODE_ORGANS

local NET_INTERVAL = 0.25
local NET_KEEPALIVE = 5
local BURN_TYPES = bit.bor(DMG_BURN, DMG_SLOWBURN, DMG_PLASMA, DMG_ENERGYBEAM)
local TOXIN_TYPES = bit.bor(DMG_POISON, DMG_NERVEGAS, DMG_RADIATION, DMG_ACID, DMG_PARALYZE)
local LUNG_KEYS = {"lungsL", "lungsR"}
local NORMAL_TEMPERATURE = 36.7
local DEATH_DAMAGE_CAUSES = {
	{DMG_BLAST, "blast"},
	{bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER), "shot"},
	{DMG_FALL, "fall"},
	{DMG_DROWN, "drown"},
	{DMG_SLASH, "slash"},
	{DMG_CLUB, "club"},
	{DMG_CRUSH, "crush"},
	{BURN_TYPES, "burn"},
	{TOXIN_TYPES, "toxin"},
}

organism.module.simplehealth = {}

local module = organism.module.simplehealth

SimpleHealth.ModuleOverrides = SimpleHealth.ModuleOverrides or {}
SimpleHealth.Tickers = {}
SimpleHealth.PoolTickers = {}
SimpleHealth.Sanitizers = {}

function SimpleHealth.GetState(org)
	return org and org.simpleMode and org.simple or nil
end

local function syncTissuePools(org, state)
	local weights = CONFIG.damage.limbHealth
	local limbMax = SoftTissue.Config.limbMax
	local brute, burn = 0, 0
	for _, limb in ipairs(SoftTissue.LIMBS) do
		local limbBrute = SoftTissue.Get(org, "brute", limb)
		local limbBurn = SoftTissue.Get(org, "burn", limb)
		local total = limbBrute + limbBurn
		if total > 0 then
			local scale = math.min(total, limbMax) / total * (weights[limb] or 1)
			brute = brute + limbBrute * scale
			burn = burn + limbBurn * scale
		end
	end

	state.brute = brute + (state.permBrute or 0)
	state.burn = burn
end

function SimpleHealth.AddDamage(org, pool, amount, limb)
	local state = SimpleHealth.GetState(org)
	if not state or not amount or amount <= 0 then return 0 end

	local before = state[pool] or 0
	state.lastDamage = CurTime()

	if LIMB_POOLS[pool] then
		local applied = SoftTissue.Add(org, pool, limb, amount)
		syncTissuePools(org, state)

		return applied
	end

	state[pool] = math.min(before + amount, CONFIG.poolMax)

	return state[pool] - before
end

function SimpleHealth.AddFracture(org, limb)
	local state = SimpleHealth.GetState(org)
	if not state then return end

	local fractureConfig = CONFIG.damage.fracture
	local before = SimpleHealth.GetHealth(state)
	state.permBrute = math.min((state.permBrute or 0) + fractureConfig.permanent, fractureConfig.permanentMax)
	SimpleHealth.AddDamage(org, "brute", fractureConfig.tissue, limb)

	local tick = engine.TickCount()
	if state.fractureBonusTick ~= tick then state.fractureBonus = 0 end
	state.fractureBonusTick = tick
	state.fractureBonus = state.fractureBonus + before - SimpleHealth.GetHealth(state)
end

function SimpleHealth.Heal(org, pool, amount, limb)
	local state = SimpleHealth.GetState(org)
	if not state or not amount or amount <= 0 then return 0 end

	local before = state[pool] or 0
	if LIMB_POOLS[pool] then
		SoftTissue.Heal(org, pool, limb, amount)
		syncTissuePools(org, state)

		return before - state[pool]
	end

	state[pool] = math.max(before - amount, 0)

	return before - state[pool]
end

local function newState()
	return {
		brute = 0,
		permBrute = 0,
		burn = 0,
		toxin = 0,
		oxy = 0,
		health = CONFIG.maxHealth,
		crit = CRIT_NONE,
		contamination = 0,
		heartEfficiency = 1,
		heartRate = CONFIG.heart.base,
		consciousnessCap = 1,
		lastDamage = CurTime(),
	}
end

local function rampUp(value, from, to)
	return math.Clamp((value - from) / (to - from), 0, 1)
end

local function quantizePool(value)
	return math.Clamp(math.Round(value or 0), 0, SimpleHealth.NET_POOL_MAX)
end

local function sendState(owner, org, force)
	if not IsValid(owner) or not owner:IsPlayer() then return end
	local now = CurTime()
	local mode = org.simpleMode or 0
	local state = org.simple
	local crit = state and (state.displayCrit or state.crit) or CRIT_NONE
	local countdownEnd = state and state.countdownStart and state.countdownStart + (state.countdownDuration or CONFIG.oxy.countdownTime) or 0
	local signature = mode * 4 + crit

	if state then
		for _, pool in ipairs(SimpleHealth.POOLS) do
			signature = signature * (SimpleHealth.NET_POOL_MAX + 1) + quantizePool(state[pool])
		end
	end

	local changed = org.simpleNetSignature ~= signature or org.simpleNetCountdown ~= countdownEnd
	local keepAlive = mode > 0 and (org.simpleNetKeepAlive or 0) <= now
	if not force and not keepAlive and (not changed or (org.simpleNetNext or 0) > now) then return end

	org.simpleNetSignature = signature
	org.simpleNetCountdown = countdownEnd
	org.simpleNetNext = now + NET_INTERVAL
	org.simpleNetKeepAlive = now + NET_KEEPALIVE

	net.Start("hg_simplehealth")
		net.WriteUInt(mode, SimpleHealth.NET_MODE_BITS)
		if state then
			net.WriteUInt(crit, SimpleHealth.NET_CRIT_BITS)
			for _, pool in ipairs(SimpleHealth.POOLS) do
				net.WriteUInt(quantizePool(state[pool]), SimpleHealth.NET_POOL_BITS)
			end
			net.WriteFloat(countdownEnd)
			net.WriteFloat(countdownEnd > 0 and (state.countdownDuration or CONFIG.oxy.countdownTime) or 0)
		end
	net.Send(owner)
end

local function die(org, causeKey, cause)
	organism.SetDeathCause(org, "simplehealth: " .. cause)
	org.simpleDeathCause = causeKey
	org.alive = false
end

module[1] = function(org)
	local owner = org.owner
	local isPlayer = IsValid(owner) and owner:IsPlayer()
	local mode = IsValid(owner) and SimpleHealth.ConVar:GetInt() or 0

	org.simpleMode = mode > 0 and mode or nil
	org.simple = org.simpleMode and newState() or nil
	org.simpleNetSignature = nil
	org.simpleDeathCause = nil
	org.simpleControlMul = nil

	SimpleHealth.WrapInputs()

	if isPlayer then sendState(owner, org, true) end
end

local RHYTHM_ARRHYTHMIA = {ectopy = 0.15, bigeminy = 0.3, afib = 0.5, vtach = 0.75, torsades = 0.9}
local RHYTHM_ECG = {
	ectopy = "ventricular_ectopy",
	bigeminy = "ventricular_bigeminy",
	afib = "atrial_fibrillation",
	vtach = "ventricular_tachycardia",
	torsades = "torsades_de_pointes",
}

SimpleHealth.ModuleOverrides.pulse = function(owner, org, timeValue)
	if not org.alive then
		organism.BeginPostMortemDecay(org)
		org.heartstop = true

		return
	end

	org.postMortemVitals = nil
	org.postMortemStart = nil
	org.ischemia = 0

	organism.UpdateBodyTemperature(owner, org, timeValue)
	organism.UpdateFear(owner, org, timeValue)

	SimpleHealth.ClearRemovedVitals(org)

	local state = org.simple
	local heartConfig = CONFIG.heart
	local heartDamage = org.simpleMode == MODE_ORGANS and math.Clamp(tonumber(org.heart) or 0, 0, 1) or 0
	local heartEfficiency = heartDamage >= CONFIG.organs.heartMax and 0 or 1 - heartDamage
	state.heartEfficiency = heartEfficiency

	local fibrillationConfig = CONFIG.fibrillation
	local targetRate = SimpleHealth.GetTargetHeartRate(org, state)
	if state.flatline then
		state.heartRate = 0
	elseif state.fibrillating then
		state.heartRate = fibrillationConfig.rate + math.Rand(-fibrillationConfig.jitter, fibrillationConfig.jitter)
	else
		state.heartRate = math.Approach(state.heartRate, targetRate, heartConfig.approach * timeValue)
	end

	local rhythmConfig = CONFIG.rhythm
	local rhythm = not state.flatline and not state.fibrillating and state.rhythm or nil
	local rhythmOutput = 1
	local rate = state.heartRate
	if rhythm == "vtach" or rhythm == "torsades" then
		rate = (rhythm == "torsades" and rhythmConfig.torsadesHeartRate or rhythmConfig.vtachHeartRate) + math.Rand(-rhythmConfig.vtachJitter, rhythmConfig.vtachJitter)
		rhythmOutput = rhythm == "torsades" and rhythmConfig.torsadesOutput or rhythmConfig.vtachOutput
	elseif rhythm == "afib" then
		rate = math.max(rate + math.Rand(-rhythmConfig.afibRateJitter, rhythmConfig.afibRateJitter), 0)
		rhythmOutput = rhythmConfig.afibOutput
	elseif rhythm == "bigeminy" then
		rhythmOutput = rhythmConfig.bigeminyOutput
	elseif rhythm == "ectopy" then
		rhythmOutput = rhythmConfig.ectopyOutput
	end

	local fastPenalty = Lerp(rampUp(rate, heartConfig.fastStart, heartConfig.max), 1, heartConfig.fastOutputMin) * rhythmOutput
	local output = state.fibrillating and 0 or math.min(rate / heartConfig.base, 1) * fastPenalty * heartEfficiency

	local brainBefore = org.brain
	local arrest = state.flatline or state.fibrillating
	local o2 = org.o2
	if arrest and istable(o2) and isnumber(o2.range) and o2.range > 0 then
		o2[1] = math.max(o2.range * (1 - state.oxy / CONFIG.oxy.countdownStart), 0)
	end
	organism.MaintainSimplifiedCirculation(org, rate, state.fibrillating and 0 or rate * fastPenalty * heartEfficiency, heartConfig.pressure * output, arrest)
	if arrest then SimpleHealth.ClearRemovedVitals(org) end
	org.brain = brainBefore
	org.cardiacOutput = output
	org.strokeVolume = output / math.max(rate / heartConfig.base, 0.1)
	org.compensationHeartRateTarget = targetRate
	org.compensationPulseMultiplier = targetRate / heartConfig.base
	org.hypotension = 1 - math.min(output, 1)
	org.palpitations = rampUp(rate, heartConfig.fastStart, heartConfig.bloodMax)
	org.heartStrain = math.max(1 - heartEfficiency, org.palpitations, rhythm and rhythmConfig.strain[rhythm] or 0)

	if state.flatline then
		org.heartstop = true
		org.ecgState = "asystole"
	elseif state.fibrillating then
		org.heartstop = true
		org.fibrillation = true
		org.fibrillationStart = state.fibrillationStart
		org.ecgState = "ventricular_fibrillation"
		org.arrhythmia = 1
	else
		org.ecgState = SimpleHealth.GetRhythmECGState(rhythm, rate, heartDamage)
		org.arrhythmia = RHYTHM_ARRHYTHMIA[rhythm] or 0
		org.ventricularTachycardia = rhythm == "torsades" and "polymorphic" or rhythm == "vtach" and "monomorphic" or nil
		org.unstableRhythm = rhythm == "afib" and "atrial_fibrillation" or (rhythm == "ectopy" or rhythm == "bigeminy") and "ventricular_ectopy" or nil
	end
end

function SimpleHealth.GetRhythmECGState(rhythm, rate, heartDamage)
	if RHYTHM_ECG[rhythm] then return RHYTHM_ECG[rhythm] end
	if heartDamage >= CONFIG.organs.heartMax * 0.8 and rate > 25 and rate <= 70 then return "av_block_complete" end
	if rate < 60 then return "sinus_bradycardia" end
	if rate <= 100 then return "normal_sinus" end
	if rate <= 150 then return "sinus_tachycardia" end
	if rate <= 200 then return "compressed_tachycardia" end
	if rate < 260 then return "extreme_tachycardia" end

	return "terminal_tachycardia"
end

function SimpleHealth.GetTargetHeartRate(org, state)
	local heartConfig = CONFIG.heart
	local blood = tonumber(org.blood) or CONFIG.contamination.normalBlood
	local temperature = tonumber(org.temperature) or NORMAL_TEMPERATURE
	local rate = heartConfig.base

	rate = rate + math.Clamp((tonumber(org.pain) or 0) / heartConfig.painFull, 0, 1) * heartConfig.pain
	rate = rate + rampUp(heartConfig.bloodStart - blood, 0, heartConfig.bloodStart - heartConfig.bloodPeak) * heartConfig.bloodGain
	rate = rate + rampUp(state.oxy, heartConfig.oxyStart, heartConfig.oxyPeak) * heartConfig.oxyGain
	if state.crit == CRIT_SOFT then rate = rate + heartConfig.softCrit end
	rate = rate + math.Clamp(tonumber(org.adrenaline) or 0, 0, heartConfig.adrenalineCap) * heartConfig.adrenaline
	rate = rate + (state.rhythm and CONFIG.rhythm.strain[state.rhythm] or 0) * CONFIG.rhythm.strainRate

	local stamina = org.stamina
	if istable(stamina) and isnumber(stamina[1]) and isnumber(stamina.max) and stamina.max > 0 then
		rate = rate + math.Clamp(1 - stamina[1] / stamina.max, 0, 1) * heartConfig.exertion
	end

	rate = rate - math.max(tonumber(org.tranquilizer) or 0, 0) * heartConfig.sedative
	rate = rate - math.max(tonumber(org.analgesia) or 0, 0) * heartConfig.opioid
	rate = rate - math.max(heartConfig.coldStart - temperature, 0) * heartConfig.coldPerDegree
	rate = rate + math.max(temperature - heartConfig.heatStart, 0) * heartConfig.heatPerDegree

	local compensation = rampUp(heartConfig.bloodClimbStart - blood, 0, heartConfig.bloodClimbStart - heartConfig.bloodClimbEnd)
	rate = Lerp(compensation, rate, heartConfig.bloodMax)
	rate = Lerp(rampUp(state.oxy, heartConfig.oxyPeak, CONFIG.oxy.countdownStart), rate, heartConfig.oxyCrashTo)

	return math.Clamp(rate, 0, Lerp(compensation, heartConfig.max, heartConfig.bloodMax))
end

local function clearRemovedVitals(org)
	org.hypertension = 0
	org.hypertensiveEmergency = 0

	local o2 = org.o2
	if istable(o2) and isnumber(o2.range) then o2[1] = o2.range end
end

SimpleHealth.ClearRemovedVitals = clearRemovedVitals

SimpleHealth.ModuleOverrides.lungs = function(owner, org, timeValue, callback)
	for _, sanitize in ipairs(SimpleHealth.Sanitizers) do
		sanitize(owner, org, org.simple, timeValue)
	end

	clearRemovedVitals(org)

	local state = org.simple
	local o2 = org.o2
	local scale = istable(o2) and isnumber(o2.range) and o2.range > 0 and CONFIG.oxy.countdownStart / o2.range
	local before
	if state and scale then
		before = math.max(o2.range - state.oxy / scale, 0)
		o2[1] = before
	end

	callback(owner, org, timeValue)

	if before then
		state.lungOxyRate = math.max(before - o2[1], 0) * scale / math.max(timeValue, 0.001)
	end

	clearRemovedVitals(org)

	if state then state.airwayBlocked = org.breathObstructed or (org.breathFailed and not org.heartstop) or false end
end

local function isBreathing(state)
	return not state.airwayBlocked and not state.flatline and not state.fibrillating
end

function SimpleHealth.NeedleHoldsSoftCrit(org, state)
	if (tonumber(org.needle) or 0) <= 0 then return false end

	local softAt, hardAt = SimpleHealth.GetCritThresholds()

	return state.health <= softAt and state.health > hardAt and not state.flatline and not state.fibrillating
end

function SimpleHealth.IsCritImmune(org)
	if (tonumber(org.fury13) or 0) > 0 then return true end

	local owner = org.owner

	return IsValid(owner) and owner.IsBerserk and owner:IsBerserk() or false
end

local function tickOxy(owner, org, state, timeValue)
	local oxyConfig = CONFIG.oxy
	local now = CurTime()
	local crit = state.crit
	local gainMul = 1
	if (state.aedResistUntil or 0) > now then gainMul = gainMul * oxyConfig.aedGainMul end

	local needleSoft = SimpleHealth.NeedleHoldsSoftCrit(org, state)
	if (tonumber(org.needle) or 0) > 0 then gainMul = gainMul * oxyConfig.needleGainMul end

	local gain = org.heartstop and 0 or state.lungOxyRate or 0
	if SimpleHealth.BloodNoOxyConVar:GetBool() and not (state.airwayBlocked or org.holdingbreath or (tonumber(org.CO) or 0) > 1) then gain = 0 end
	if state.lethalCrit then gain = gain + oxyConfig.hardCritGain end

	local overdose, sedative = SimpleHealth.GetOverdose(org)
	gain = gain + math.min(sedative, overdose) * oxyConfig.sedativeGain + (state.oxyGainBonus or 0)

	if needleSoft then gain = 0 end

	local critOxy = math.min(state.critOxy or 0, state.oxy)
	local critGain = state.lethalFromHealth and not needleSoft and oxyConfig.hardCritGain or 0

	local bradypnea = needleSoft and 0 or tonumber(org.bradyapnea) or 0
	local bradypneaFloor = rampUp(bradypnea, oxyConfig.bradypneaStart, oxyConfig.bradypneaFull) * oxyConfig.bradypneaPool

	local oxy = state.oxy
	local softDying = crit == CRIT_SOFT and not needleSoft
	if softDying then
		oxy = oxy + oxyConfig.softCritGain * gainMul * timeValue
		critGain = critGain + oxyConfig.softCritGain
	end

	oxy = oxy + gain * gainMul * timeValue

	if gain <= 0 and not state.lethalCrit and not softDying and oxy > bradypneaFloor then
		oxy = math.max(oxy - oxyConfig.regen * timeValue, bradypneaFloor)
	elseif oxy < bradypneaFloor then
		oxy = math.min(oxy + oxyConfig.bradypneaGain * gainMul * timeValue, bradypneaFloor)
	end

	state.oxy = math.Clamp(oxy, 0, CONFIG.poolMax)
	state.critOxy = math.min(critOxy + critGain * gainMul * timeValue, state.oxy)
	state.oxyGain = gain

	if state.oxy > oxyConfig.brainDamageStart then
		local range = math.max(oxyConfig.brainDamageFull - oxyConfig.brainDamageStart, 1)
		local severity = math.Clamp((state.oxy - oxyConfig.brainDamageStart) / range, 0, 1)
		org.brain = math.min((org.brain or 0) + oxyConfig.brainDamageRate * severity * timeValue, 1)
	end
end

local function hasInternalBleed(org)
	return (tonumber(org.internalBleed) or 0) > CONFIG.internalBleed.min
end

local function tickInternalBleed(owner, org, state, timeValue)
	if not hasInternalBleed(org) then return end

	local pulseMul = math.max(tonumber(org.pulse) or 0, 0) / CONFIG.heart.base
	local drain = org.internalBleed * CONFIG.internalBleed.drainPerSeverity * pulseMul * timeValue
	org.blood = math.max((tonumber(org.blood) or CONFIG.contamination.normalBlood) - drain, 1)
end

local function tickRegen(owner, org, state, timeValue)
	local damageConfig = CONFIG.damage
	if state.flatline or state.fibrillating then return end
	if (tonumber(org.thiamine) or 0) <= 0 and CurTime() - state.lastDamage < damageConfig.passiveDelay then return end

	SoftTissue.Regen(org, timeValue, damageConfig.passiveBruteRegen, damageConfig.passiveBurnRegen)
end

local function boostedRegenMul(owner, org)
	local mul = 0
	if (tonumber(org.fury13) or 0) > 0 then mul = mul + 15 end
	if IsValid(owner) and owner:IsPlayer() then
		if owner.PlayerClassName == "furry" then mul = mul + 10 end
		if owner.IsBerserk and owner:IsBerserk() then mul = mul + 10 * math.max(tonumber(org.berserk) or 1, 1) end
	end
	local noradrenaline = tonumber(org.noradrenaline) or 0
	if noradrenaline > 0 then mul = mul + 5 * noradrenaline end

	return mul
end

local function tickFuryRegen(owner, org, state, timeValue)
	if state.flatline or state.fibrillating then return end

	local mul = boostedRegenMul(owner, org)
	if mul <= 0 then return end

	local damageConfig = CONFIG.damage
	SoftTissue.Regen(org, timeValue, damageConfig.passiveBruteRegen * mul, damageConfig.passiveBurnRegen * mul)
	state.toxin = math.max((state.toxin or 0) - damageConfig.passiveBruteRegen * mul * timeValue, 0)
end

local function tickTemperature(owner, org, state, timeValue)
	local temperatureConfig = CONFIG.temperature
	local temperature = tonumber(org.temperature) or NORMAL_TEMPERATURE
	local cold = math.max(temperatureConfig.coldStart - temperature, 0) * temperatureConfig.coldBurnPerDegree
	local heat = math.max(temperature - temperatureConfig.heatStart, 0) * temperatureConfig.heatBurnPerDegree

	SimpleHealth.AddDamage(org, "burn", (cold + heat) * timeValue)
end

local function startFlatline(owner, org, state)
	state.flatline = true
	state.heartRate = 0
	hook.Run("hg/simplehealth/flatline-changed", owner, org, true)
end

local function stopFlatline(owner, org, state)
	if not state.flatline or state.fibrillating or state.heartEfficiency <= 0 then return false end

	state.flatline = false
	state.healthFlatline = nil
	state.heartRate = CONFIG.heart.restartRate
	state.flatlineGraceUntil = CurTime() + CONFIG.flatline.grace
	hook.Run("hg/simplehealth/flatline-changed", owner, org, false)

	return true
end

local function flatlineChance(org, state)
	local flatlineConfig = CONFIG.flatline
	local softAt, hardAt = SimpleHealth.GetCritThresholds()
	local chance = 0

	if state.health <= softAt then
		chance = flatlineConfig.softCritChance + rampUp(softAt - state.health, 0, softAt - hardAt) * flatlineConfig.softCritDepthChance
	end
	if state.health <= hardAt then chance = chance + flatlineConfig.severeChance end

	local rate = state.heartRate
	if rate < flatlineConfig.rateLow then chance = chance + flatlineConfig.rateChance end
	if (tonumber(org.temperature) or NORMAL_TEMPERATURE) < flatlineConfig.coldStart then chance = chance + flatlineConfig.coldChance end

	return chance
end

local function startFibrillation(owner, org, state)
	state.fibrillating = true
	state.fibrillationStart = CurTime()
	hook.Run("hg/simplehealth/fibrillation-changed", owner, org, true)
end

local function stopFibrillation(owner, org, state)
	if not state.fibrillating or (tonumber(org.blood) or 0) <= CONFIG.deathBlood then return false end

	state.fibrillating = nil
	state.fibrillationStart = nil
	state.heartRate = CONFIG.heart.restartRate
	state.flatlineGraceUntil = CurTime() + CONFIG.flatline.grace
	hook.Run("hg/simplehealth/fibrillation-changed", owner, org, false)

	return true
end

local function tickFibrillation(owner, org, state, timeValue)
	if state.fibrillating or state.flatline then return end
	if (tonumber(org.blood) or CONFIG.contamination.normalBlood) <= CONFIG.deathBlood or state.heartRate >= CONFIG.flatline.certainRate then startFibrillation(owner, org, state) end
end

local function setRhythm(owner, org, state, rhythm)
	if state.rhythm == rhythm then return end

	state.rhythm = rhythm
	state.rhythmDegradeAt = nil
	if rhythm == "vtach" or rhythm == "torsades" then
		local rhythmConfig = CONFIG.rhythm
		state.rhythmDegradeAt = CurTime() + math.Rand(rhythmConfig.vtachDegradeMin, rhythmConfig.vtachDegradeMax)
	end
	if not rhythm then state.rhythmGraceUntil = CurTime() + CONFIG.rhythm.grace end
	hook.Run("hg/simplehealth/rhythm-changed", owner, org, rhythm)
end

local function tickRhythm(owner, org, state, timeValue)
	if state.flatline or state.fibrillating then
		state.rhythm = nil
		state.rhythmDegradeAt = nil

		return
	end

	local rhythmConfig = CONFIG.rhythm
	local now = CurTime()
	local rhythm = state.rhythm
	local rate = state.heartRate
	local heartDamage = org.simpleMode == MODE_ORGANS and math.Clamp(tonumber(org.heart) or 0, 0, 1) or 0
	local roll = math.Rand(0, 1)

	if rhythm == "vtach" or rhythm == "torsades" then
		if now >= (state.rhythmDegradeAt or now) then
			state.rhythm = nil
			state.rhythmDegradeAt = nil
			startFibrillation(owner, org, state)
		elseif rate < rhythmConfig.vtachResolveRate and roll < rhythmConfig.vtachResolveChance * timeValue then
			setRhythm(owner, org, state, nil)
		end

		return
	end

	if (state.rhythmGraceUntil or 0) > now then return end

	local hypoxia = rampUp(state.oxy, CONFIG.heart.oxyStart, CONFIG.oxy.countdownStart)
	local vtachRisk = rampUp(rate, rhythmConfig.vtachRate, CONFIG.flatline.certainRate) * (1 + hypoxia * rhythmConfig.vtachOxyMul + heartDamage * rhythmConfig.vtachHeartDamageMul)
	if vtachRisk > 0 and roll < vtachRisk * rhythmConfig.vtachChance * timeValue then
		setRhythm(owner, org, state, math.Rand(0, 1) < rhythmConfig.torsadesShare and "torsades" or "vtach")

		return
	end

	if rhythm == "afib" then
		if rate < rhythmConfig.afibRate - rhythmConfig.resolveBelow and heartDamage < rhythmConfig.afibHeartDamage and roll < rhythmConfig.resolveChance * timeValue then
			setRhythm(owner, org, state, nil)
		end

		return
	end

	local afibRisk = math.max(rampUp(rate, rhythmConfig.afibRate, rhythmConfig.vtachRate), rampUp(heartDamage, 0, rhythmConfig.afibHeartDamage))
	if afibRisk > 0 and roll < afibRisk * rhythmConfig.afibChance * timeValue then
		setRhythm(owner, org, state, "afib")
	elseif rhythm then
		if rate < rhythmConfig.ectopyRate - rhythmConfig.resolveBelow and heartDamage < rhythmConfig.bigeminyHeartDamage * 0.5 then
			if roll < rhythmConfig.resolveChance * timeValue then setRhythm(owner, org, state, nil) end
		else
			local bigeminy = heartDamage >= rhythmConfig.bigeminyHeartDamage or rate >= rhythmConfig.bigeminyRate
			setRhythm(owner, org, state, bigeminy and "bigeminy" or "ectopy")
		end
	else
		local ectopyRisk = math.max(rampUp(rate, rhythmConfig.ectopyRate, rhythmConfig.afibRate), rampUp(heartDamage, 0, rhythmConfig.bigeminyHeartDamage))
		if ectopyRisk > 0 and roll < ectopyRisk * rhythmConfig.ectopyChance * timeValue then setRhythm(owner, org, state, "ectopy") end
	end
end

local function tickFlatline(owner, org, state, timeValue)
	if state.flatline or state.fibrillating then return end
	if state.heartEfficiency <= 0 then
		startFlatline(owner, org, state)

		return
	end

	if (state.flatlineGraceUntil or 0) > CurTime() then return end
	if math.Rand(0, 1) < flatlineChance(org, state) * timeValue then
		state.healthFlatline = state.health <= SimpleHealth.GetCritThresholds() or nil
		startFlatline(owner, org, state)
	end
end

local function tickBrainPerfusion(owner, org, state, timeValue)
	local perfusionConfig = CONFIG.perfusion
	if state.flatline or state.fibrillating then
		state.brainPerfusion = 0

		return
	end

	local perfusion = math.Clamp((tonumber(org.pulse) or 0) / perfusionConfig.pulseFull, 0, 1)
	state.brainPerfusion = perfusion

	local severity = rampUp(perfusionConfig.damageBelow - perfusion, 0, perfusionConfig.damageBelow)
	if severity > 0 then org.brain = math.min((tonumber(org.brain) or 0) + perfusionConfig.brainRate * severity * timeValue, 1) end
end

local function tickConsciousness(owner, org, state, timeValue)
	local consciousnessConfig = CONFIG.consciousness
	local softAt, hardAt = SimpleHealth.GetCritThresholds()
	local blood = tonumber(org.blood) or CONFIG.contamination.normalBlood
	local drain = 0
	local held = 0

	if state.health <= softAt then
		drain = consciousnessConfig.softCritDrain + rampUp(softAt - state.health, 0, softAt - hardAt) * consciousnessConfig.softCritDepthDrain
	end
	if state.flatline or state.fibrillating then held = held + consciousnessConfig.flatlineDrain end
	local tolerance = SimpleHealth.IsCritImmune(org) and ((tonumber(org.fury13) or 0) > 0 and 0.2 or 0.35) or 1
	drain = drain + rampUp(consciousnessConfig.bleedStart - blood, 0, consciousnessConfig.bleedStart - CONFIG.deathBlood) * consciousnessConfig.bleedDrain * tolerance
	held = held + rampUp(state.oxy, consciousnessConfig.oxyStart, consciousnessConfig.oxyFull) * consciousnessConfig.oxyDrain
	if state.airwayBlocked then
		held = held + rampUp(state.oxy, consciousnessConfig.airwayStart, consciousnessConfig.airwayFull) * consciousnessConfig.airwayDrain
	end
	held = held + rampUp(consciousnessConfig.perfusionStart - (state.brainPerfusion or 1), 0, consciousnessConfig.perfusionStart) * consciousnessConfig.perfusionDrain
	drain = drain + held

	local ceiling = 1
	if state.health <= softAt and not SimpleHealth.IsCritImmune(org) then
		ceiling = Lerp(rampUp(softAt - state.health, 0, softAt - hardAt), 1, consciousnessConfig.hardCritFloor)
	end
	ceiling = math.min(ceiling, 1 - rampUp(consciousnessConfig.bloodCapStart - blood, 0, consciousnessConfig.bloodCapStart - CONFIG.deathBlood) * consciousnessConfig.bloodCapMax)

	local settled = state.leadIn and held > 0 and state.consciousnessCap <= consciousnessConfig.leadInFloor
	if settled then drain = drain - held end
	local rate = drain > 0 and -drain or settled and 0 or consciousnessConfig.recover
	local previousCap = state.consciousnessCap
	local cap = previousCap + rate * timeValue
	if cap > ceiling then cap = math.max(ceiling, math.min(cap, previousCap - consciousnessConfig.depthDrain * timeValue)) end

	state.consciousnessCap = math.Clamp(cap, 0, 1)
	org.consciousness = math.min(tonumber(org.consciousness) or 1, state.consciousnessCap)

	if org.otrub and org.consciousness < consciousnessConfig.wakeAt then org.needotrub = true end
end

table.insert(SimpleHealth.Tickers, tickInternalBleed)
table.insert(SimpleHealth.Tickers, tickOxy)
table.insert(SimpleHealth.Tickers, tickRegen)
table.insert(SimpleHealth.Tickers, tickFuryRegen)
table.insert(SimpleHealth.Tickers, tickTemperature)
table.insert(SimpleHealth.Tickers, tickFibrillation)
table.insert(SimpleHealth.Tickers, tickRhythm)
table.insert(SimpleHealth.Tickers, tickFlatline)
table.insert(SimpleHealth.Tickers, tickBrainPerfusion)
table.insert(SimpleHealth.Tickers, tickConsciousness)

for _, ticker in ipairs({tickOxy, tickRegen, tickTemperature}) do
	SimpleHealth.PoolTickers[ticker] = true
end

local function reverseHealthCrit(org, state)
	local critOxy = math.min(state.critOxy or 0, state.oxy)
	state.critOxy = critOxy

	local softAt = SimpleHealth.GetCritThresholds()
	if SimpleHealth.GetHealth(state) + critOxy <= softAt then return end

	state.oxy = state.oxy - critOxy
	state.critOxy = 0
	if state.healthFlatline then stopFlatline(org.owner, org, state) end
end

local function updateCrit(org, state)
	local previous = state.crit
	reverseHealthCrit(org, state)
	state.health = SimpleHealth.GetHealth(state)

	local critImmune = SimpleHealth.IsCritImmune(org)
	state.critImmune = critImmune
	local healthCrit = critImmune and SimpleHealth.CRIT_NONE or SimpleHealth.GetCritState(state.health)
	local severe = state.flatline or state.fibrillating or healthCrit == CRIT_HARD
	local needleSoft = healthCrit == CRIT_SOFT and SimpleHealth.NeedleHoldsSoftCrit(org, state)
	state.crit = (severe or (org.otrub and not needleSoft)) and CRIT_HARD or healthCrit
	state.displayCrit = severe and CRIT_HARD or healthCrit
	org.critical = state.displayCrit == CRIT_HARD
	state.lethalCrit = severe or (org.otrub and healthCrit == CRIT_SOFT and not needleSoft and not isBreathing(state))
	state.lethalFromHealth = state.lethalCrit and healthCrit ~= CRIT_NONE and not state.fibrillating and (not state.flatline or state.healthFlatline) or nil
	state.dying = state.crit == CRIT_HARD or (state.crit == CRIT_SOFT and not needleSoft)
	org.simpleControlMul = state.crit == CRIT_SOFT and CONFIG.softCritControlMul or nil

	local softCritFree = state.crit == CRIT_SOFT and state.health < 15
	if state.crit >= CRIT_SOFT and not softCritFree then org.needfake = true end
	local healthDrained = healthCrit == CRIT_HARD and state.consciousnessCap <= CONFIG.consciousness.hardCritFloor + 0.005
	if healthDrained then org.needotrub = true end

	if state.crit ~= previous then
		hook.Run("hg/simplehealth/crit-changed", org.owner, org, state.crit, previous)
	end
end

local function updateCountdown(owner, org, state)
	local oxyConfig = CONFIG.oxy
	local now = CurTime()
	local wasCounting = state.countdownStart ~= nil
	local bleedConfig = CONFIG.bleedCountdown
	local blood = tonumber(org.blood) or CONFIG.contamination.normalBlood

	local consciousnessConfig = CONFIG.consciousness
	local drowsy = org.otrub or state.consciousnessCap <= consciousnessConfig.leadInStart

	if not drowsy or blood >= bleedConfig.rollBelow then
		state.bleedRoll = nil
	elseif state.bleedRoll == nil then
		state.bleedRoll = math.random() < bleedConfig.rollChance
	end

	local bleedOut = drowsy and blood < bleedConfig.rollBelow and (blood < bleedConfig.start or state.bleedRoll)
	state.countdownBleed = not state.fibrillating and bleedOut or nil

	if state.fibrillating then
		state.countdownStart = state.fibrillationStart
	elseif (state.oxy > oxyConfig.countdownStart or bleedOut) and (org.otrub or state.dying or bleedOut) then
		state.countdownStart = state.countdownStart or now
	else
		state.countdownStart = nil
	end

	local counting = state.countdownStart ~= nil
	state.countdownChoked = counting and (state.countdownChoked or state.airwayBlocked) or nil

	local duration = state.fibrillating and CONFIG.fibrillation.deathTime or state.countdownChoked and oxyConfig.airwayCountdownTime or state.countdownBleed and bleedConfig.time or oxyConfig.countdownTime
	state.countdownDuration = duration

	if counting ~= wasCounting then
		hook.Run("hg/simplehealth/countdown-changed", owner, org, counting)
	end

	local convulsing = counting and (org.convulsing or org.seizureActive)
	if convulsing and not state.convulseCut and state.countdownStart + duration - now > oxyConfig.convulseRemaining then
		state.countdownStart = now + oxyConfig.convulseRemaining - duration
		if state.fibrillating then state.fibrillationStart = state.countdownStart end
	end
	state.convulseCut = convulsing or nil

	org.defibDeathGrace = nil
	org.deathStateRemaining = nil

	local elapsed = counting and now - state.countdownStart or 0
	org.incapacitated = counting and (convulsing or duration - elapsed <= oxyConfig.countdownTrackRemaining)
	org.incapReason = org.incapacitated and "oxy" or nil
	if org.incapacitated then
		org.deathStateEnd = state.countdownStart + duration
		if not org.otrub then
			org.needotrub = true
			org.consciousness = math.min(tonumber(org.consciousness) or 1, consciousnessConfig.wakeAt * 0.5)
		end
	end

	local wasLeadIn = state.leadIn
	state.leadIn = counting and not org.incapacitated or nil
	if state.leadIn then org.simpleControlMul = math.min(org.simpleControlMul or 1, consciousnessConfig.leadInControlMul) end
	if state.leadIn ~= wasLeadIn and IsValid(owner) and owner:IsPlayer() then owner.ChatWhisper = state.leadIn or state.crit == CRIT_SOFT end

	return counting and elapsed >= duration
end

local function syncOldHealth(owner, state)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end

	local fraction = math.Clamp(state.health / CONFIG.maxHealth, 0, 1)
	owner:SetHealth(math.max(math.ceil(fraction * owner:GetMaxHealth()), 1))
end

module[2] = function(owner, org, timeValue)
	local state = SimpleHealth.GetState(org)
	if not state or not org.alive then return end

	local poolsOnly = org.superfighter
	for _, tick in ipairs(SimpleHealth.Tickers) do
		if not poolsOnly or SimpleHealth.PoolTickers[tick] then tick(owner, org, state, timeValue) end
	end

	syncTissuePools(org, state)

	if poolsOnly then
		state.health = SimpleHealth.GetHealth(state)
		syncOldHealth(owner, state)
		if state.health <= 0 then die(org, "brute", "health " .. math.floor(state.health)) end
		sendState(owner, org)

		return
	end

	updateCrit(org, state)
	syncOldHealth(owner, state)

	local countdownExpired = updateCountdown(owner, org, state)
	local brainIgnored = organism.IsBrainDamageIgnored and organism.IsBrainDamageIgnored(org)

	if (state.crit == CRIT_HARD or state.critImmune) and state.health <= CONFIG.deathHealth then
		die(org, "brute", "health " .. math.floor(state.health) .. " in hardcrit")
	elseif org.otrub and (tonumber(org.blood) or CONFIG.contamination.normalBlood) < CONFIG.deathBlood then
		die(org, "bleed", "unconscious below " .. CONFIG.deathBlood .. " blood")
	elseif countdownExpired then
		local causeKey = state.fibrillating and "fibrillation" or state.flatline and "flatline" or state.countdownBleed and "bleed" or "suffocate"
		die(org, causeKey, causeKey .. " countdown expired")
	elseif not brainIgnored and (tonumber(org.brain) or 0) >= CONFIG.brainDeath then
		die(org, "brain", "brain death")
	end

	sendState(owner, org)
end

function SimpleHealth.WouldCrit(org, damage, damageType, limb)
	local state = SimpleHealth.GetState(org)
	if not state then return false end

	if bit.band(damageType, TOXIN_TYPES) ~= 0 or bit.band(damageType, BURN_TYPES) ~= 0 or bit.band(damageType, DMG_DROWN) ~= 0 then return false end

	local damageConfig = CONFIG.damage
	local dmgInfo = DamageInfo()
	dmgInfo:SetDamageType(damageType)
	local brute = damage * SoftTissue.GetDamageProfile(dmgInfo) * damageConfig.bruteScale * (damageConfig.limbHealth[limb] or 1)

	return SimpleHealth.GetCritState(SimpleHealth.GetHealth(state) - brute) ~= CRIT_NONE
end

function SimpleHealth.Suicide(org)
	if not SimpleHealth.GetState(org) or not org.alive then return end

	die(org, "suicide", "self-inflicted blow")
end

local function resolveDeathCause(org, state)
	if org.simpleDeathCause == "suicide" then return "suicide" end
	if org.fatalBrainDeath and (tonumber(org.spine3) or 0) >= 1 then return "neck" end

	local recent = state.lastDamageTime and CurTime() - state.lastDamageTime <= CONFIG.recentDamageTime
	if recent then
		for _, entry in ipairs(DEATH_DAMAGE_CAUSES) do
			if bit.band(state.lastDamageType or 0, entry[1]) ~= 0 then return entry[2] end
		end
	end

	if org.simpleDeathCause then return org.simpleDeathCause end
	if state.fibrillating then return "fibrillation" end
	if state.flatline then return "flatline" end

	local temperatureConfig = CONFIG.temperature
	local temperature = tonumber(org.temperature) or NORMAL_TEMPERATURE
	if temperature < temperatureConfig.deathColdBelow then return "cold" end
	if temperature > temperatureConfig.deathHeatAbove then return "heat" end
	if (tonumber(org.blood) or CONFIG.contamination.normalBlood) < temperatureConfig.deathBloodBelow then return "bleed" end

	local pool = SimpleHealth.GetDominantPool(state)
	if pool == "oxy" then return "suffocate" end

	return pool or "unknown"
end

hook.Add("PlayerDeath", "hg/simplehealth/death-cause", function(ply)
	local org = IsValid(ply) and ply.organism
	local state = SimpleHealth.GetState(org)
	if not state then return end

	net.Start("hg_simplehealth_death")
		net.WriteString(resolveDeathCause(org, state))
	net.Send(ply)
end)

local function classifyDamage(dmgInfo)
	if dmgInfo:IsDamageType(DMG_DROWN) then return "oxy" end
	if dmgInfo:IsDamageType(TOXIN_TYPES) then return "toxin" end
	if dmgInfo:IsDamageType(BURN_TYPES) then return "burn" end

	return "brute"
end

local function registerSpike(org, state, applied)
	local spikeConfig = CONFIG.spike
	local now = CurTime()

	if now - (state.spikeTime or 0) > spikeConfig.window then state.spikeAmount = 0 end
	state.spikeTime = now
	state.spikeAmount = (state.spikeAmount or 0) + applied

	if state.spikeAmount < spikeConfig.minDamage then return end

	local softAt = SimpleHealth.GetCritThresholds()
	if SimpleHealth.GetHealth(state) > softAt then return end

	local severity = rampUp(state.spikeAmount, spikeConfig.minDamage, spikeConfig.fullDamage)
	local knockoutUntil = now + Lerp(severity, spikeConfig.minTime, spikeConfig.maxTime)
	if knockoutUntil > (org.postureOtrubUntil or 0) then org.postureOtrubUntil = knockoutUntil end
	org.needotrub = true
	org.needfake = true
	org.consciousness = math.min(tonumber(org.consciousness) or 1, 0.04)
end

SimpleHealth.ClassifyDamage = classifyDamage

function SimpleHealth.FireTickScale(dmgInfo)
	if dmgInfo:IsDamageType(DMG_BLAST) or not dmgInfo:IsDamageType(BURN_TYPES) then return 1 end

	return CONFIG.damage.fireTickMul
end

local function isMeleeHit(dmgInfo)
	if not dmgInfo:IsDamageType(DMG_CLUB + DMG_SLASH) or dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST) then return false end

	local inflictor = dmgInfo:GetInflictor()

	return IsValid(inflictor) and inflictor:IsWeapon()
end

hook.Add("PreHomigradDamage", "hg/simplehealth/melee-cap", function(victim, dmgInfo)
	local org = IsValid(victim) and victim.organism
	local state = SimpleHealth.GetState(org)
	if not state then return end

	state.meleeSnapshot = nil
	if not isMeleeHit(dmgInfo) then return end

	syncTissuePools(org, state)
	local tissue = {}
	for _, limb in ipairs(SoftTissue.LIMBS) do
		tissue[limb] = SoftTissue.Get(org, "brute", limb)
	end
	state.meleeSnapshot = {tick = engine.TickCount(), health = SimpleHealth.GetHealth(state), perm = state.permBrute or 0, tissue = tissue}
end)

local function capMeleeHit(org, state, damage, limb)
	local snapshot = state.meleeSnapshot
	state.meleeSnapshot = nil
	if not snapshot or snapshot.tick ~= engine.TickCount() then return end

	local damageConfig = CONFIG.damage
	local cap = damage * damageConfig.meleeHitHealth * (damageConfig.limbHealth[limb] or 1) * hg.organism.TraitMul(org, "tissue_damage", 1)
	if state.fractureBonusTick == snapshot.tick then cap = cap + (state.fractureBonus or 0) end

	local lost = snapshot.health - SimpleHealth.GetHealth(state)
	if lost <= cap then return end

	local tissueLost = lost - ((state.permBrute or 0) - snapshot.perm)
	if tissueLost <= 0 then return end

	local refund = math.min((lost - cap) / tissueLost, 1)
	for tissueLimb, before in pairs(snapshot.tissue) do
		local gained = SoftTissue.Get(org, "brute", tissueLimb) - before
		if gained > 0 then SoftTissue.Heal(org, "brute", tissueLimb, gained * refund) end
	end
	syncTissuePools(org, state)
end

hook.Add("HomigradDamage", "hg/simplehealth/damage-pools", function(victim, dmgInfo, hitgroup)
	local org = IsValid(victim) and victim.organism
	local state = SimpleHealth.GetState(org)
	if not state then return end

	local damage = dmgInfo:GetDamage()
	if damage <= 0 then return end
	local rawDamage = damage
	damage = damage * SimpleHealth.FireTickScale(dmgInfo)

	state.lastDamageType = dmgInfo:GetDamageType()
	state.lastDamageTime = CurTime()

	local damageConfig = CONFIG.damage
	local pool = classifyDamage(dmgInfo)
	local limb = SoftTissue.HITGROUP_LIMBS[hitgroup] or "torso"
	if pool == "brute" then
		damage = damage * SoftTissue.GetDamageProfile(dmgInfo)
		if limb == "torso" and org.simpleMode == MODE_SIMPLE then
			damage = damage * (1 + SoftTissue.GetSoftImpairment(org, "torso") * SoftTissue.Config.access.simpleTorso)
		end
	end
	local applied
	if pool == "burn" and dmgInfo:IsDamageType(DMG_BLAST) then
		local burnShare = damageConfig.blastBurnShare
		applied = SimpleHealth.AddDamage(org, "brute", damage * (1 - burnShare) * damageConfig.bruteScale, limb)
		applied = applied + SimpleHealth.AddDamage(org, "burn", damage * burnShare * damageConfig.burnScale, limb)
	else
		applied = SimpleHealth.AddDamage(org, pool, damage * damageConfig[pool .. "Scale"], limb)
	end

	if pool == "brute" then capMeleeHit(org, state, rawDamage, limb) end

	if LIMB_POOLS[pool] then
		SoftTissue.OnLimbDamaged(org, limb, applied, dmgInfo)
		registerSpike(org, state, applied)
	end
end)

local GATED_INPUTS = {
	heart = MODE_ORGANS,
	liver = MODE_ORGANS,
	flank = MODE_ORGANS,
	gut = MODE_ORGANS,
	lungsL = MODE_ORGANS,
	lungsR = MODE_ORGANS,
	trachea = false,
	eyeL = false,
	eyeR = false,
	chest = true,
}

SimpleHealth.OriginalInputs = SimpleHealth.OriginalInputs or {}
SimpleHealth.InputWrappers = SimpleHealth.InputWrappers or {}
SimpleHealth.InputHandlers = SimpleHealth.InputHandlers or {}

hg.InputWrapperInner = hg.InputWrapperInner or setmetatable({}, {__mode = "k"})

hg.InputWrapperChainHas = hg.InputWrapperChainHas or function(fn, target)
	while fn do
		if fn == target then return true end
		fn = hg.InputWrapperInner[fn]
	end

	return false
end

local function bleedFromOrgan(org, name, dmg, dmgInfo)
	local bleedConfig = CONFIG.organBleed
	local perHarm = bleedConfig.perHarm[name]
	if not perHarm or not isnumber(dmg) or dmg <= 0 then return end

	local blunt = not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_SLASH + DMG_BLAST)
	local harm = dmg * (bleedConfig.harmScale[name] or 1) / math.max(org.organStrengthMul or 1, 1)
	if not blunt then harm = harm * (bleedConfig.sharpMul[name] or 1) end

	local owner = org.owner
	local mul = 1
	if IsValid(owner) and owner.GetTraitMultiplier then
		harm = harm * owner:GetTraitMultiplier("organ_damage", 1)
		mul = owner:GetTraitMultiplier("internal_bleed", 1)
	end

	local current = tonumber(org.internalBleed) or 0
	org.internalBleed = math.max(current, math.min(current + math.min(harm, 1) * perHarm * mul, bleedConfig.max))
end

function SimpleHealth.RibTissueDamage(org, ribs)
	if org.simpleMode ~= MODE_SIMPLE then return false end

	SimpleHealth.AddDamage(org, "brute", ribs * CONFIG.damage.ribBrute, "torso")

	return true
end

local function wrapInput(inputList, name, allowedMode)
	local original = inputList[name]
	if not isfunction(original) or hg.InputWrapperChainHas(original, SimpleHealth.InputWrappers[name]) then return end

	SimpleHealth.OriginalInputs[name] = original

	local function wrapper(org, ...)
		local mode = org.simpleMode
		if not mode then return original(org, ...) end
		if allowedMode ~= true and mode ~= allowedMode then
			local _, dmg, dmgInfo = ...
			bleedFromOrgan(org, name, dmg, dmgInfo)

			return 0
		end

		local handler = SimpleHealth.InputHandlers[name]
		if handler then return handler(original, org, ...) end

		return original(org, ...)
	end

	SimpleHealth.InputWrappers[name] = wrapper
	hg.InputWrapperInner[wrapper] = original
	inputList[name] = wrapper
end

function SimpleHealth.WrapInputs()
	local inputList = organism.input_list
	if not inputList then return end

	for name, allowedMode in pairs(GATED_INPUTS) do
		wrapInput(inputList, name, allowedMode)
	end
end

SimpleHealth.WrapInputs()
hook.Add("InitPostEntity", "hg/simplehealth/wrap-inputs", SimpleHealth.WrapInputs)

local function sanitizeOrgans(owner, org)
	org.trachea = 0
	org.eyeL = 0
	org.eyeR = 0

	if org.simpleMode == MODE_ORGANS then
		org.heart = math.min(tonumber(org.heart) or 0, CONFIG.organs.heartMax)

		return
	end

	org.heart = 0
	org.liver = 0
	org.flank = 0
	org.gut = 0
	org.pneumothorax = 0
	org.hemothorax = 0
	org.hemothoraxL = 0
	org.hemothoraxR = 0
	org.hemothoraxTrauma = 0
	if hg.organism.ResetPneumonia then hg.organism.ResetPneumonia(org) end
	org.cardiacTamponade = 0

	for _, key in ipairs(LUNG_KEYS) do
		local lung = org[key]
		if istable(lung) then
			lung[1] = 0
			lung[2] = 0
		end
	end
end

table.insert(SimpleHealth.Sanitizers, sanitizeOrgans)

function SimpleHealth.AddContamination(org, amount)
	local state = SimpleHealth.GetState(org)
	if not state or not amount or amount <= 0 then return end

	state.contamination = math.min(state.contamination + amount, CONFIG.contamination.max)
end

local function syncSepsis(org, state)
	local sepsis = state.contamination
	org.hemotransfusionshock = sepsis
	state.sepsisShown = sepsis
end

local function convertPoisons(owner, org, state)
	if not state then return end

	local contaminationConfig = CONFIG.contamination
	local now = CurTime()

	for key, onset in pairs(contaminationConfig.poisonOnset) do
		local started = org[key]
		if isnumber(started) and started + onset <= now then
			SimpleHealth.AddContamination(org, contaminationConfig.poisonDose[key])
			org[key] = nil
			org[key .. "notificate"] = nil
			hook.Run("hg/simplehealth/poisoned", owner, org, key)
		end
	end

	local shock = (tonumber(org.hemotransfusionshock) or 0) - (state.sepsisShown or 0)
	if shock > 0.0001 then
		SimpleHealth.AddDamage(org, "toxin", shock * contaminationConfig.wrongBloodToxinPerShock)
		SimpleHealth.AddContamination(org, shock * contaminationConfig.wrongBloodPerShock)
		state.wrongBloodUntil = now + contaminationConfig.wrongBloodHold
	end

	org.sepsisSource = 0
	syncSepsis(org, state)
end

table.insert(SimpleHealth.Sanitizers, convertPoisons)

local function tickBloodExchange(org, state, timeValue)
	local toxinConfig = CONFIG.toxin
	local contaminationConfig = CONFIG.contamination
	local blood = math.max(tonumber(org.blood) or contaminationConfig.normalBlood, 0)
	local lastBlood = state.lastBlood or blood
	state.lastBlood = blood

	local delta = blood - lastBlood
	if delta < 0 and lastBlood > 0 then
		state.contamination = state.contamination * math.Clamp(blood / lastBlood, 0, 1)
		SimpleHealth.Heal(org, "toxin", -delta * toxinConfig.bloodLossHealPerMl)

		return
	end

	local transfused = delta - (tonumber(org.bloodRegenRate) or 0) * timeValue
	if transfused <= contaminationConfig.transfusionMinMl then return end
	if (state.wrongBloodUntil or 0) > CurTime() then return end

	state.contamination = state.contamination * lastBlood / math.max(lastBlood + transfused, 1)
	SimpleHealth.Heal(org, "toxin", transfused * toxinConfig.transfusionHealPerMl)
end

function SimpleHealth.GetOverdose(org)
	local toxinConfig = CONFIG.toxin
	local opioid = math.max((tonumber(org.analgesia) or 0) - toxinConfig.opioidSafeDose, 0)
	local painkiller = math.max((tonumber(org.painkiller) or 0) - toxinConfig.painkillerSafeDose, 0)
	local sedative = math.max((tonumber(org.tranquilizer) or 0) - toxinConfig.tranquilizerSafeDose, 0)

	return math.min(opioid + painkiller + sedative, toxinConfig.overdoseCap), sedative
end

local function tickToxin(owner, org, state, timeValue)
	local toxinConfig = CONFIG.toxin

	tickBloodExchange(org, state, timeValue)

	if state.contamination > 0 then
		SimpleHealth.AddDamage(org, "toxin", state.contamination * CONFIG.contamination.toxinGain * timeValue)
	end

	local infection = rampUp(tonumber(org.infection) or 0, toxinConfig.infectionStart, 1)
	if infection > 0 then
		SimpleHealth.AddDamage(org, "toxin", infection * toxinConfig.infectionGain * timeValue)
	end

	local overdose = SimpleHealth.GetOverdose(org)
	if overdose > 0 then
		SimpleHealth.AddDamage(org, "toxin", overdose * toxinConfig.overdoseGain * timeValue)
	end

	state.thiamineActive = (tonumber(org.thiamine) or 0) > 0
	if state.thiamineActive then
		SimpleHealth.Heal(org, "toxin", toxinConfig.thiamineHeal * timeValue)
		SimpleHealth.Heal(org, "brute", toxinConfig.thiamineDamageHeal * timeValue)
		SimpleHealth.Heal(org, "burn", toxinConfig.thiamineDamageHeal * timeValue)
		state.contamination = math.max(state.contamination - toxinConfig.thiamineContaminationClear * timeValue, 0)
	end

	SimpleHealth.Heal(org, "toxin", toxinConfig.regen * (state.toxinRegenMul or 1) * timeValue)

	syncSepsis(org, state)
end

local function healWorstPools(org, state, amount)
	local healed = 0

	while amount - healed > 0.001 do
		local worst, value
		for _, pool in ipairs(SimpleHealth.POOLS) do
			if (state[pool] or 0) > (value or 0) then worst, value = pool, state[pool] end
		end
		if not worst then break end

		healed = healed + SimpleHealth.Heal(org, worst, amount - healed)
	end

	return healed
end

local function tickResuscitation(owner, org, state, timeValue)
	local oxyConfig = CONFIG.oxy
	local now = CurTime()

	if state.crit == CRIT_NONE then state.cprCritHealed = nil end

	if (org.cprSupportUntil or 0) > now and (state.nextCprClear or 0) <= now then
		state.nextCprClear = now + oxyConfig.cprCycle
		SimpleHealth.Heal(org, "oxy", oxyConfig.cprClear)
		SimpleHealth.Heal(org, "toxin", oxyConfig.cprToxinClear)

		local _, hardAt = SimpleHealth.GetCritThresholds()
		local healed = state.cprCritHealed or 0
		if state.health <= hardAt and healed < oxyConfig.cprCritBudget then
			state.cprCritHealed = healed + healWorstPools(org, state, math.min(oxyConfig.cprCritHeal, oxyConfig.cprCritBudget - healed))
		end

		if state.flatline and math.Rand(0, 1) < CONFIG.flatline.cprRestartChance then stopFlatline(owner, org, state) end
	end

	if (org.cprSupportUntil or 0) > now and state.countdownStart and not state.fibrillating then
		local remaining = state.countdownStart + (state.countdownDuration or oxyConfig.countdownTime) - now
		if remaining > oxyConfig.cprHoldAbove then state.countdownStart = state.countdownStart + timeValue end
	end
end

function SimpleHealth.ShouldAEDShock(org)
	local state = SimpleHealth.GetState(org)

	return state ~= nil and (state.flatline or state.fibrillating or state.rhythm == "vtach" or state.rhythm == "torsades" or state.oxy >= CONFIG.oxy.aedShockAt)
end

function SimpleHealth.OnAEDShock(org)
	local state = SimpleHealth.GetState(org)
	if not state then return end

	local oxyConfig = CONFIG.oxy
	for _, pool in ipairs(SimpleHealth.POOLS) do
		SimpleHealth.Heal(org, pool, state[pool] or 0)
	end

	state.countdownStart = nil
	state.countdownChoked = nil
	state.leadIn = nil
	state.bleedRoll = nil
	org.incapacitated = false
	org.incapReason = nil
	org.deathStateEnd = nil
	state.aedResistUntil = CurTime() + oxyConfig.aedResistTime
	state.cprCritHealed = nil

	if state.flatline then
		local flatlineConfig = CONFIG.flatline
		local cpr = (org.cprSupportUntil or 0) + flatlineConfig.aedCprWindow > CurTime()
		if math.Rand(0, 1) < (cpr and flatlineConfig.aedCprRestartChance or flatlineConfig.aedRestartChance) then
			stopFlatline(org.owner, org, state)
		end
	end
	stopFibrillation(org.owner, org, state)
	setRhythm(org.owner, org, state, nil)
	org.heartstop = state.flatline or state.fibrillating or false
	if not org.heartstop then org.fibrillation = false end
	state.heartRate = math.max(state.heartRate, CONFIG.heart.base)
	state.consciousnessCap = 1
	state.health = SimpleHealth.GetHealth(state)
end

function SimpleHealth.OnHeartRestarted(org)
	local state = SimpleHealth.GetState(org)
	if not state then return end

	if state.flatline then stopFlatline(org.owner, org, state) end
	stopFibrillation(org.owner, org, state)
end

function SimpleHealth.TagWoundBrute(org, wound, dmgInfo, share)
	local state = SimpleHealth.GetState(org)
	if not state or not wound or classifyDamage(dmgInfo) ~= "brute" then return end

	local damageConfig = CONFIG.damage
	local brute = dmgInfo:GetDamage() * damageConfig.bruteScale
	if dmgInfo:IsDamageType(DMG_BLAST) then brute = brute * (1 - damageConfig.blastBurnShare) end

	wound.simpleBrute = (wound.simpleBrute or 0) + brute * share
end

function SimpleHealth.OnWoundHealed(org, wound, fraction)
	local brute = wound and wound.simpleBrute
	if not brute or brute <= 0 or fraction <= 0 then return end

	local part = brute * math.min(fraction, 1)
	wound.simpleBrute = brute - part
	SimpleHealth.Heal(org, "brute", part * CONFIG.medicine.bandageBruteShare, SoftTissue.LimbFromBone(wound[4]))
end

table.insert(SimpleHealth.Tickers, tickToxin)
SimpleHealth.PoolTickers[tickToxin] = true
table.insert(SimpleHealth.Tickers, tickResuscitation)

function SimpleHealth.OnBandageApplied(org, bone)
	hg.Medicine.Use("weapon_bandage_sh", org, bone)
end

local DEFAULT_COAGULATION = 1.2
local DEFAULT_BLOOD_REGENERATION = 1.2
local DESTROYED = 1

local function organDamage(org, key)
	return math.Clamp(tonumber(org[key]) or 0, 0, 1)
end

local function lungSeverity(org)
	local damage = 0
	for _, key in ipairs(LUNG_KEYS) do
		local lung = org[key]
		damage = damage + (istable(lung) and math.Clamp(tonumber(lung[1]) or 0, 0, 1) or 0)
	end

	return math.max(damage / #LUNG_KEYS, math.Clamp(tonumber(org.pneumothorax) or 0, 0, 1))
end

SimpleHealth.ModuleOverrides.liver = function(owner, org)
	if not org.alive then return end

	local bleedMul = 1
	if org.simpleMode == MODE_ORGANS then
		local organConfig = CONFIG.organs
		bleedMul = (1 + organDamage(org, "liver") * organConfig.liverBleedMul)
			* (1 + organDamage(org, "flank") * organConfig.flankBleedMul)
			* (1 + organDamage(org, "gut") * organConfig.gutBleedMul)
	end

	org.bleedingmul = bleedMul
	org.coagulation_multiplier = DEFAULT_COAGULATION
	org.blood_regeneration_multiplier = hasInternalBleed(org) and CONFIG.internalBleed.regenMul or DEFAULT_BLOOD_REGENERATION
end

local REPAIRED_ORGANS = {"heart", "liver", "flank", "gut", "pneumothorax"}

local DESTROYED_MEND_TIME = 120

local function repairOrgans(org, amount, timeValue)
	org.thiamineMend = org.thiamineMend or {}
	for _, key in ipairs(REPAIRED_ORGANS) do
		local damage = organDamage(org, key)
		if damage >= DESTROYED then
			local mend = (org.thiamineMend[key] or 0) + timeValue
			if mend >= DESTROYED_MEND_TIME then
				org.thiamineMend[key] = nil
				org[key] = DESTROYED - 0.001
			else
				org.thiamineMend[key] = mend
			end
		else
			org[key] = math.max(damage - amount, 0)
		end
	end

	for _, key in ipairs(LUNG_KEYS) do
		local lung = org[key]
		if istable(lung) then lung[1] = math.max((tonumber(lung[1]) or 0) - amount, 0) end
	end
end

local function tickOrgans(owner, org, state, timeValue)
	if org.simpleMode ~= MODE_ORGANS then
		state.toxinRegenMul = 1
		state.oxyGainBonus = 0

		return
	end

	local organConfig = CONFIG.organs
	if state.thiamineActive then repairOrgans(org, CONFIG.toxin.thiamineOrganHeal * timeValue, timeValue) end

	local liver = organDamage(org, "liver")
	local flank = organDamage(org, "flank")
	local gut = organDamage(org, "gut")
	local flankDestroyed = flank >= DESTROYED

	local flankRegenMul = flankDestroyed and 1 - organConfig.flankDestroyedRegenPenalty or 1
	state.toxinRegenMul = math.max((1 - liver * organConfig.liverRegenPenalty) * flankRegenMul, 0)

	if not state.thiamineActive then
		local organToxin = liver * organConfig.liverToxinGain + flank * organConfig.flankToxinGain
		if flankDestroyed then organToxin = organToxin + organConfig.flankDestroyedToxinGain end
		SimpleHealth.AddDamage(org, "toxin", organToxin * timeValue)
	end

	local lungStart = organConfig.lungGainStart
	local lungLoad = math.max(lungSeverity(org) - lungStart, 0) / (1 - lungStart)
	state.oxyGainBonus = lungLoad * CONFIG.oxy.lungGain

	local treated = (tonumber(org.tranexamic_acid) or 0) > 0 or (tonumber(org.internalBleedHeal) or 0) > 0
	if treated then return end

	local floors = organConfig.internalBleedFloor
	local bleedFloor = liver * floors.liver + flank * floors.flank + gut * floors.gut
	if bleedFloor > (tonumber(org.internalBleed) or 0) then org.internalBleed = bleedFloor end
end

table.insert(SimpleHealth.Tickers, tickOrgans)

local function abdominalHit(key)
	return function(original, org, bone, dmg, dmgInfo, ...)
		local organConfig = CONFIG.organs
		local before = organDamage(org, key)
		local result = original(org, bone, dmg, dmgInfo, ...)

		if before >= DESTROYED then
			organism.AddPain(org, organConfig.destroyedHitPain, "body")
			org.internalBleed = (tonumber(org.internalBleed) or 0) + organConfig.destroyedHitBleed

			return result
		end

		local harmed = organDamage(org, key) - before
		local owner = org.owner
		if harmed < organConfig.stunDamageMin or not IsValid(owner) or not owner:IsPlayer() then return result end

		local duration = Lerp(harmed, organConfig.stunMin, organConfig.stunMax)
		timer.Simple(0, function()
			if not IsValid(owner) or not owner:Alive() or owner.organism ~= org then return end

			local remaining = (tonumber(org.stun) or 0) - CurTime()
			hg.StunPlayer(owner, math.max(duration, remaining))
		end)

		return result
	end
end

SimpleHealth.InputHandlers.chest = function(original, org, bone, dmg, dmgInfo, ...)
	local damageConfig = CONFIG.damage
	local broken = org.simpleMode == MODE_SIMPLE and (tonumber(org.chest) or 0) >= damageConfig.brokenChestAt
	local result, vec = original(org, bone, dmg, dmgInfo, ...)
	local tick = engine.TickCount()
	if not broken or org.simpleBrokenChestTick == tick then return result, vec end

	org.simpleBrokenChestTick = tick

	return result, vec
end

hook.Add("PreHomigradDamageBulletBleedAdd", "hg/simplehealth/broken-chest", function(victim, org, dmgInfo, hitgroup, harm, hitBoxs, inputHole, info)
	local tick = engine.TickCount()
	if not org or org.simpleBrokenChestTick ~= tick or org.simpleBrokenChestBledTick == tick then return end

	org.simpleBrokenChestBledTick = tick
	info.bleed = (tonumber(info.bleed) or 0) * CONFIG.damage.brokenChestBleedMul
end)

SimpleHealth.InputHandlers.liver = abdominalHit("liver")
SimpleHealth.InputHandlers.flank = abdominalHit("flank")
SimpleHealth.InputHandlers.gut = abdominalHit("gut")

local THOUGHT_COLOR = Color(255, 150, 150)
local FAINT_SOUND_KEYS = {
	[SimpleHealth.FAINT_FOOTSTEPS] = "footsteps",
	[SimpleHealth.FAINT_GUNFIRE] = "gunfire",
}

SimpleHealth.FaintListeners = SimpleHealth.FaintListeners or {}

local faintListeners = SimpleHealth.FaintListeners

function SimpleHealth.GetCrit(ply)
	local state = IsValid(ply) and SimpleHealth.GetState(ply.organism)

	return state and state.crit or CRIT_NONE
end

function SimpleHealth.IsWhisperForced(ply)
	local state = IsValid(ply) and SimpleHealth.GetState(ply.organism)

	return state and (state.crit == CRIT_SOFT or state.leadIn) or false
end

local function stateThought(owner, key, text)
	if not IsValid(owner) or not owner:IsPlayer() or not owner.Thought then return end

	owner:Thought(text, CONFIG.chat.thoughtCooldown, "simplehealth_" .. key, 1, THOUGHT_COLOR)
end

hook.Add("hg/simplehealth/crit-changed", "hg/simplehealth/chat", function(owner, org, crit, previous)
	if not IsValid(owner) or not owner:IsPlayer() then return end

	if crit == CRIT_SOFT or previous == CRIT_SOFT then owner.ChatWhisper = crit == CRIT_SOFT end

	if crit == CRIT_SOFT and previous == CRIT_NONE then
		hg.ChatLog.Emit("softcrit", owner)
		stateThought(owner, "softcrit", "I can't get up...")
	elseif crit == CRIT_HARD then
		stateThought(owner, "hardcrit", "Everything is going dark")
		net.Start("hg_simplehealth_hardcrit")
		net.Send(owner)
	end
end)

hook.Add("hg/simplehealth/countdown-changed", "hg/simplehealth/chat", function(owner, org, counting)
	if counting and IsValid(owner) then hg.ChatLog.Emit("stopbreathing", owner) end
end)

hook.Add("hg/simplehealth/flatline-changed", "hg/simplehealth/chat", function(owner, org, flatline)
	if flatline and not org.otrub then stateThought(owner, "flatline", "My chest... my heart stopped...") end
end)

hook.Add("hg/simplehealth/rhythm-changed", "hg/simplehealth/chat", function(owner, org, rhythm)
	if org.otrub then return end
	if rhythm == "vtach" or rhythm == "torsades" then
		stateThought(owner, "vtach", "My heart is hammering way too fast... something is wrong.")
	elseif rhythm == "afib" then
		stateThought(owner, "afib", "My heartbeat feels all over the place.")
	end
end)

hook.Add("hg/simplehealth/fibrillation-changed", "hg/simplehealth/chat", function(owner, org, fibrillating)
	if fibrillating and not org.otrub then stateThought(owner, "fibrillation", "My chest is quivering... I can't feel a heartbeat.") end
end)

hook.Add("hg/simplehealth/poisoned", "hg/simplehealth/chat", function(owner)
	stateThought(owner, "poisoned", "Something is wrong with me... I feel sick.")
end)

local BLOOD_THOUGHTS = {
	{legacy = "I'm losing a lot of blood..", new = "Your skin is becoming pale."},
	{legacy = "I'm about to pass out from blood..", new = "Your skin is deathly pale and cold. You are about to pass out."},
}

local function tickBloodThoughts(owner, org, state)
	local chatConfig = CONFIG.chat
	local blood = tonumber(org.blood) or CONFIG.contamination.normalBlood
	local current = state.bloodThoughtLevel or 0
	local exit = chatConfig.bloodThoughtHysteresis
	local level = 0

	if blood <= chatConfig.bloodThoughtCritical + (current >= 2 and exit or 0) then
		level = 2
	elseif blood <= chatConfig.bloodThoughtLow + (current >= 1 and exit or 0) then
		level = 1
	end

	state.bloodThoughtLevel = level
	if level <= current or org.otrub then return end

	local lines = BLOOD_THOUGHTS[level]
	if not owner.Thought then return end
	local useNew = owner:GetInfoNum("hg_newthoughts", 0) > 0

	owner:Thought(useNew and lines.new or lines.legacy, chatConfig.thoughtCooldown, "hgstatus_simpleblood" .. level, 1, THOUGHT_COLOR)
end

local HEALTH_THOUGHTS = {
	{
		legacy = {"I don't feel right...", "Something is off. I feel weaker than I should.", "I'm hurt, and it's starting to show..."},
		new = {"You feel weaker than you should.", "Your body feels heavy and wrong.", "You are starting to feel unsteady."},
	},
	{
		legacy = {"I'm hurt pretty badly...", "This is bad. I'm hurt worse than I thought."},
		new = {"You are badly hurt.", "You are hurt worse than you thought."},
	},
	{
		legacy = {"I'm in really bad shape...", "My body is giving out..."},
		new = {"Your body is failing. You need medical attention.", "Your strength is draining away."},
	},
	{
		legacy = {"I'm very close to death...", "I can feel myself slipping..."},
		new = {"You are very close to death.", "You can feel yourself slipping away."},
	},
	{
		legacy = {"I'm dying... I need help now...", "I'm not going to make it without help..."},
		new = {"You are dying. Without help, you will not survive.", "You are fading fast. You need help now."},
	},
}

local function healthThoughtLevel(org, state, current)
	local chatConfig = CONFIG.chat
	local softAt, hardAt = SimpleHealth.GetCritThresholds()
	local health = state.health
	local thresholds = {
		chatConfig.healthThoughtLow,
		chatConfig.healthThoughtHurt,
		chatConfig.healthThoughtBad,
		softAt,
		softAt - (softAt - hardAt) * chatConfig.healthThoughtDying,
	}

	for level = #thresholds, 1, -1 do
		local exit = current >= level and chatConfig.healthThoughtHysteresis or 0
		if health <= thresholds[level] + exit then return level end
	end

	return 0
end

local function tickHealthThoughts(owner, org, state)
	local current = state.healthThoughtLevel or 0
	local level = healthThoughtLevel(org, state, current)
	state.healthThoughtLevel = level
	if level <= current or org.otrub or not owner.Thought or not owner.GetInfoNum then return end

	local lines = HEALTH_THOUGHTS[level]
	local useNew = owner:GetInfoNum("hg_newthoughts", 0) > 0
	local pool = useNew and lines.new or lines.legacy

	owner:Thought(pool[math.random(#pool)], CONFIG.chat.thoughtCooldown, "hgstatus_simplehealth" .. level, 1, THOUGHT_COLOR)
end

local function tickSymptoms(owner, org, state)
	local oxyConfig = CONFIG.oxy
	local organConfig = CONFIG.organs
	local now = CurTime()

	tickBloodThoughts(owner, org, state)
	tickHealthThoughts(owner, org, state)

	if state.oxy >= oxyConfig.gaspAt and not state.gasping then
		state.gasping = true
		hg.ChatLog.Emit("airgasp", owner)
		if not org.otrub then stateThought(owner, "gasp", "I can't breathe...") end
	elseif state.oxy < oxyConfig.gaspAt - oxyConfig.gaspHysteresis then
		state.gasping = false
	end

	local nausea = tonumber(org.wantToVomit) or 0
	local nauseaRising = nausea >= organConfig.coughNauseaAt and nausea > (state.nauseaPrev or 0)
	state.nauseaPrev = nausea
	if nauseaRising and not org.otrub and (state.nextCoughBlood or 0) <= now then
		state.nextCoughBlood = now + organConfig.coughBloodInterval
		organism.CoughBlood(org)
		hg.ChatLog.Emit("coughblood", owner)
	end

	faintListeners[owner] = org.otrub and true or nil
end

table.insert(SimpleHealth.Tickers, tickSymptoms)

local function sendFaint(listener, kind, text)
	net.Start("hg_simplehealth_faint")
		net.WriteUInt(kind, SimpleHealth.NET_FAINT_BITS)
		if kind == SimpleHealth.FAINT_SPEECH then net.WriteString(text) end
	net.Send(listener)
end

local function isFaintListener(listener)
	local org = IsValid(listener) and listener:Alive() and listener.organism

	return org and org.otrub and SimpleHealth.GetState(org) ~= nil
end

local function forEachFaintListener(source, pos, range, callback)
	local rangeSqr = range * range

	for listener in pairs(faintListeners) do
		if not isFaintListener(listener) then
			faintListeners[listener] = nil
		elseif listener ~= source and hg.GetCurrentCharacter(listener):GetPos():DistToSqr(pos) <= rangeSqr then
			callback(listener)
		end
	end
end

local function sendFaintSound(listener, kind)
	local key = FAINT_SOUND_KEYS[kind]
	local now = CurTime()
	listener.hgSimpleFaintNext = listener.hgSimpleFaintNext or {}
	if (listener.hgSimpleFaintNext[key] or 0) > now then return end

	listener.hgSimpleFaintNext[key] = now + CONFIG.chat.faintSoundCooldown
	sendFaint(listener, kind)
end

local function partialSpeech(text)
	local chatConfig = CONFIG.chat
	text = utf8.force(text)

	local length = utf8.len(text)
	if not length or length <= 0 then return end

	local keep = math.max(math.floor(length * math.Rand(chatConfig.faintKeepMin, chatConfig.faintKeepMax)), 1)
	local first = math.random(1, length - keep + 1)

	return "..." .. utf8.sub(text, first, first + keep - 1) .. "..."
end

hook.Add("HG_PlayerSay", "hg/simplehealth/faint-speech", function(speaker, textTable)
	if next(faintListeners) == nil then return end
	if not IsValid(speaker) or not speaker:Alive() or (speaker.organism and speaker.organism.otrub) then return end

	local text = textTable[1]
	if not isstring(text) or text == "" then return end

	local chatConfig = CONFIG.chat
	forEachFaintListener(speaker, speaker:GetPos(), chatConfig.faintHearRange, function(listener)
		if math.Rand(0, 1) > chatConfig.faintHearChance then return end

		local partial = partialSpeech(text)
		if partial then sendFaint(listener, SimpleHealth.FAINT_SPEECH, partial) end
	end)
end)

hook.Add("PlayerFootstep", "hg/simplehealth/faint-footsteps", function(ply, pos)
	if next(faintListeners) == nil then return end

	forEachFaintListener(ply, pos, CONFIG.chat.faintHearRange, function(listener)
		sendFaintSound(listener, SimpleHealth.FAINT_FOOTSTEPS)
	end)
end)

hook.Add("EntityFireBullets", "hg/simplehealth/faint-gunfire", function(shooter)
	if next(faintListeners) == nil or not IsValid(shooter) then return end

	forEachFaintListener(shooter, shooter:GetPos(), CONFIG.chat.faintGunfireRange, function(listener)
		sendFaintSound(listener, SimpleHealth.FAINT_GUNFIRE)
	end)
end)

local function resetOrganismsForMode()
	table.Empty(faintListeners)

	for _, ply in ipairs(player.GetAll()) do
		local org = ply.organism
		if org and ply:Alive() then hg.organism.Clear(org) end
	end
end

cvars.RemoveChangeCallback("hg_simplehealth", "hg/simplehealth/mode-reset")
cvars.AddChangeCallback("hg_simplehealth", function()
	timer.Create("hg/simplehealth/mode-reset", 0, 1, resetOrganismsForMode)
end, "hg/simplehealth/mode-reset")
