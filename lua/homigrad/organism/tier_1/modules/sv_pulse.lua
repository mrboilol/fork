local min, max, halfValue2 = math.min, math.max, util.halfValue2
--local Organism = hg.organism
hg.organism.module.pulse = {}
local module = hg.organism.module.pulse

-- Blood-volume response is deliberately calculated rather than sampled from
-- lookup tables. Perfusion falls continuously and reaches zero at 1750 mL.
local cardiacArrestBlood = 1750
local terminalHeartRate = 300
local peaDuration = 6

local function getBloodPerfusion(blood)
	local volume = math.Clamp(((tonumber(blood) or 5000) - cardiacArrestBlood) / (5000 - cardiacArrestBlood), 0, 1)
	-- This keeps early loss compensable while making the last quarter collapse
	-- rapidly as there is no longer enough volume to fill the pump.
	return volume ^ 0.45
end

local function getBloodCompensationRate(blood)
	blood = tonumber(blood) or 5000
	-- Every loss of blood increases the compensation rate. The curve is mild at
	-- first, then accelerates into the terminal range: 70 BPM at 5000 mL and
	-- 300 BPM at 2000 mL. Any further loss cannot produce a viable faster rate.
	local loss = math.Clamp((5000 - blood) / (5000 - 2000), 0, 1)
	return 70 + loss ^ 1.2 * (terminalHeartRate - 70)
end

-- Extreme speed and sustained lateral acceleration can briefly reduce venous
-- return.  Keep this separate from blood loss: it is a reversible pressure
-- problem, not a wound or a permanent reduction in blood volume.
local function getMotionVelocity(owner)
	if not IsValid(owner) then return vector_origin end

	local motionEnt = owner
	-- Organism owners are not always players (for example, a ragdoll during a
	-- handoff). InVehicle is a player method, so only call it when present.
	local inVehicle = isfunction(owner.InVehicle) and owner:InVehicle() or false
	if inVehicle then
		local vehicle = owner:GetVehicle()
		if IsValid(vehicle) then
			motionEnt = vehicle
			-- Glide seats are usually parented to the aircraft, while regular seats
			-- may already report the parent velocity. Walk up once so both cases use
			-- the vehicle that is actually doing the turning.
			local parent = vehicle:GetParent()
			if IsValid(parent) then motionEnt = parent end
		end
	end

	return IsValid(motionEnt) and motionEnt:GetVelocity() or vector_origin
end

local function updateHighSpeedPressureShock(owner, org, timeValue)
	if not IsValid(owner) then
		org.highSpeedPressureShock = 0
		org.lastHighSpeedVelocity = nil
		org.lastHighSpeedVelocityTime = nil
		return 0
	end

	-- Noclip movement is administrative/free-camera movement, not a physical
	-- manoeuvre. Clear the cached sample too, so leaving noclip cannot create a
	-- false acceleration spike on the first normal movement update.
	if owner:GetMoveType() == MOVETYPE_NOCLIP then
		org.highSpeedPressureShock = 0
		org.lastHighSpeedVelocity = nil
		org.lastHighSpeedVelocityTime = nil
		return 0
	end

	local now = CurTime()
	local velocity = getMotionVelocity(owner)
	local previousVelocity = org.lastHighSpeedVelocity
	local previousTime = org.lastHighSpeedVelocityTime
	org.lastHighSpeedVelocity = velocity
	org.lastHighSpeedVelocityTime = now

	if not previousVelocity or not previousTime then
		org.highSpeedPressureShock = org.highSpeedPressureShock or 0
		return org.highSpeedPressureShock
	end

	local speed = velocity:Length()
	local speedStress = math.Clamp(math.Remap(speed, 900, 1900, 0, 0.65), 0, 0.65)
	local fallStress = math.Clamp(math.Remap(-velocity.z, 850, 1750, 0, 0.75), 0, 0.75)
	local inVehicle = isfunction(owner.InVehicle) and owner:InVehicle() or false
	if velocity.z >= 0 or (not inVehicle and isfunction(owner.OnGround) and owner:OnGround()) then fallStress = 0 end

	local sampleTime = math.Clamp(now - previousTime, 0.02, 0.5)
	local acceleration = (velocity - previousVelocity) / sampleTime
	local lateralAcceleration = acceleration
	if speed > 1 then
		local direction = velocity / speed
		lateralAcceleration = acceleration - direction * acceleration:Dot(direction)
	end
	-- Aircraft retain most of their speed in a turn, so lateral acceleration is
	-- the useful signal here. Lower thresholds make abrupt high-speed turns
	-- produce a meaningful but reversible pressure drop.
	local turnStress = math.Clamp(math.Remap(speed, 500, 1150, 0, 1), 0, 1)
		* math.Clamp(math.Remap(lateralAcceleration:Length(), 250, 1100, 0, 0.95), 0, 0.95)

	local target = math.max(speedStress, fallStress, turnStress)
	local current = org.highSpeedPressureShock or 0
	-- A sharp manoeuvre takes effect quickly, but circulation recovers gradually
	-- after the aircraft levels out or the player stops falling.
	org.highSpeedPressureShock = math.Approach(current, target, target > current and timeValue * 3.5 or timeValue / 4)
	return org.highSpeedPressureShock
end

local function getPalpitationThreat(org, blood, o2Value)
	local lowBlood = math.Clamp((4500 - blood) / 2500, 0, 1)
	local lowCirculation = math.Clamp(org.hypotension or 0, 0, 1)
	local hypoxia = math.Clamp((12 - o2Value) / 12, 0, 1)
	local shock = math.Clamp((org.shock or 0) / 60, 0, 1)
	local heartDamage = math.Clamp(org.heart or 0, 0, 1)
	local temperatureStress = math.max(
		math.Clamp((34 - (org.temperature or 36.7)) / 6, 0, 1),
		math.Clamp(((org.temperature or 36.7) - 39) / 3, 0, 1)
	)

	return math.max(lowBlood, lowCirculation, hypoxia, shock, heartDamage, temperatureStress)
end

local heatDamageTargets = {"brain", "heart", "liver", "stomach", "intestines"}
local coldDamageTargets = {"heart", "liver", "stomach", "intestines"}

local function applyTemperatureTrauma(org)
	local temperature = org.temperature or 36.7
	local heatStress = math.Clamp(math.Remap(temperature, 40, 42, 0, 1), 0, 1)
	local coldStress = math.Clamp(math.Remap(temperature, 31, 27, 0, 1), 0, 1)

	if heatStress <= 0 and coldStress <= 0 then
		org.nextTemperatureTrauma = nil
		return
	end

	if (org.nextTemperatureTrauma or 0) > CurTime() then return end
	org.nextTemperatureTrauma = CurTime() + 2

	local stress = heatStress > 0 and heatStress or coldStress
	local targets = heatStress > 0 and heatDamageTargets or coldDamageTargets
	local chance = heatStress > 0 and Lerp(heatStress, 0.08, 0.6) or Lerp(coldStress, 0.04, 0.3)
	if math.Rand(0, 1) > chance then return end

	-- Hyperthermia can injure the brain or a major organ. Hypothermic tissue
	-- damage is deliberately much smaller; its main acute danger remains the
	-- severe bradycardia/arrest progression below.
	local damage = heatStress > 0 and math.Rand(0.0015, 0.004) * stress or math.Rand(0.0004, 0.0012) * stress
	local key = targets[math.random(#targets)]
	org[key] = math.min((org[key] or 0) + damage, 1)
end

local function notifyTemperatureStress(owner, org)
	if not org.isPly or org.otrub or not IsValid(owner) or not owner:Alive() then return end

	local temperature = org.temperature or 36.7
	if temperature < 33 then
		owner:Notify("I'm very cold...", 30, "temperature_very_cold", 0, nil, Color(150, 210, 255))
	elseif temperature < 35 then
		owner:Notify("I'm getting cold...", 30, "temperature_cold", 0, nil, Color(150, 210, 255))
	elseif temperature >= 40 then
		owner:Notify("I'm very hot...", 30, "temperature_very_hot", 0, nil, Color(255, 145, 110))
	elseif temperature >= 38.5 then
		owner:Notify("I'm getting hot...", 30, "temperature_hot", 0, nil, Color(255, 145, 110))
	end
end

function hg.organism.GetECGState(heartbeat, heartstop, org)
	heartbeat = math.Clamp(tonumber(heartbeat) or 0, 0, terminalHeartRate)
	if heartstop then return heartbeat < 1 and "asystole" or "pea" end
	if heartbeat < 1 then return "asystole" end
	if hg.organism.OrganSystemsEnabled and not hg.organism.OrganSystemsEnabled() then
		if heartbeat <= 100 then return "normal_sinus" end
		if heartbeat <= 150 then return "sinus_tachycardia" end
		if heartbeat <= 200 then return "compressed_tachycardia" end
		if heartbeat < 280 then return "extreme_tachycardia" end
		return "terminal_tachycardia"
	end

	org = org or {}
	local o2 = org.o2 and org.o2[1] or 30
	local hypoxia = math.Clamp((12 - o2) / 12, 0, 1)
	local cerebral = math.Clamp(math.max((org.brain or 0) * 0.8, org.brainHemorrhage or 0), 0, 1)
	local cardiac = math.Clamp(org.heart or 0, 0, 1)
	-- Mild cold (34-35 C) does not override a needed hemorrhage response.
	-- Conduction suppression begins in moderate hypothermia and grows toward
	-- severe hypothermia.
	local cold = math.Clamp((34 - (org.temperature or 36.7)) / 7, 0, 1)
	local hemorrhagicDecompensation = math.Clamp((2000 - (org.blood or 5000)) / (2000 - cardiacArrestBlood), 0, 1)
	local suppression = math.max(cerebral * 0.9, hypoxia, cardiac * 0.9, cold, hemorrhagicDecompensation)

	-- Complete/partial AV block is a direct conduction-system injury pattern,
	-- while severe systemic failure falls back to an escape rhythm.
	if cardiac >= 0.72 and heartbeat > 40 then return "av_block_complete" end
	if cardiac >= 0.4 and heartbeat > 45 then return "av_block_partial" end
	if org.fibrillation or org.terminalRhythm == "ventricular_fibrillation" then return "ventricular_fibrillation" end
	if org.unstableRhythm == "atrial_fibrillation" then return "atrial_fibrillation" end
	if org.unstableRhythm == "ventricular_ectopy" then return "ventricular_ectopy" end
	-- Moderate cold should retain its conduction/J-wave morphology while the
	-- rhythm is still sinus-driven; a slower escape rhythm takes precedence.
	if cold >= 0.18 and heartbeat > 40 and cold >= math.max(cerebral * 0.9, hypoxia, cardiac * 0.9) then return "hypothermia_bradycardia" end
	if heartbeat <= 40 and (hypoxia >= 0.65 or cardiac >= 0.65 or cold >= 0.75 or hemorrhagicDecompensation >= 0.75) then return "ventricular_escape" end
	if heartbeat <= 60 and suppression >= 0.52 then return "junctional_escape" end
	if heartbeat < 50 and suppression >= 0.32 then return "sinus_pause" end
	if cerebral >= 0.28 then return heartbeat < 60 and "cerebral_bradycardia" or "cerebral_irregular" end
	if heartbeat < 60 then return "sinus_bradycardia" end
	if heartbeat <= 100 then return "normal_sinus" end
	if heartbeat <= 150 then return "sinus_tachycardia" end
	if heartbeat <= 200 then return "compressed_tachycardia" end
	if heartbeat < 280 then return "extreme_tachycardia" end
	return "terminal_tachycardia"
end



local Clamp, Approach, Remap = math.Clamp, math.Approach, math.Remap
local CurTime = CurTime
local function getBloodVolume(org)
	return getBloodPerfusion(org.blood)
end

local function getHeartEfficiency(org)
	local heart = Clamp(1 - org.heart, 0, 1)
	local ischemia = Clamp(1 - (org.myocardialOxygen or 1), 0, 1)
	local strain = Clamp(org.heartStrain or 0, 0, 1)
	return Clamp(heart - ischemia * 0.35 - strain * 0.25, 0, 1)
end

local function addArrhythmia(org, amount)
	org.arrhythmia = Clamp((org.arrhythmia or 0) + amount, 0, 1)
	org.nextArrhythmiaRoll = math.min(org.nextArrhythmiaRoll or CurTime(), CurTime() + 4)
end

function hg.organism.AddCardiacStress(org, amount)
	if not org or not isnumber(amount) or amount <= 0 then return 0 end
	addArrhythmia(org, amount)
	org.heartStrain = Clamp((org.heartStrain or 0) + amount * 0.45, 0, 1)
	return org.arrhythmia
end

function hg.organism.StartFibrillation(org)
	if not org or org.heartstop then return end
	org.fibrillation = true
	-- Fibrillation replaces an organized palpitation rhythm; keeping both
	-- active makes circulation, ECG, and status displays disagree.
	org.palpitations = 0
	org.palpitationTreatmentUntil = 0
	org.arrhythmia = math.max(org.arrhythmia or 0, 0.8)
	org.fibrillationStart = CurTime()
end

module[1] = function(org)
	org.heart = 0
	org.heartstop = false
	org.pulse = 70 -- that's the blood pressure
	org.heartbeat = 75
	org.ecgState = "normal_sinus"
	org.cardiacOutput = 1
	org.strokeVolume = 1
	org.compensationPulseMultiplier = 1
	org.compensationHeartRateTarget = 75
	org.palpitations = 0
	org.palpitationTreatmentUntil = 0
	org.cardiacArrestStart = nil
	org.cardiacArrestO2Start = nil
	org.heartbeat = 70
	org.cardiacOutput = 1
	org.arrhythmia = 0
	org.fibrillation = false
	org.fibrillationStart = 0
	org.myocardialOxygen = 1
	org.heartStrain = 0
	org.hypertension = 0
	org.hypotension = 0
	org.highSpeedPressureShock = 0
	org.lastHighSpeedVelocity = nil
	org.lastHighSpeedVelocityTime = nil
	org.nextArrhythmiaRoll = 0
	org.lastCardiacPain = 0

	org.tempchanging = 0
	org.heatbuff = 30 -- seconds of heat supply
	org.needed_temp = 36.7
	org.lowBloodTemperatureTarget = 36.7
end

function hg.organism.should_gain_fear(org)
	local hasRealInjury = (org.blood and org.blood < 4000) or (org.bleed and org.bleed > 1) or (org.pain and org.pain > 30 and (org.blood and org.blood < 4500 or org.bleed and org.bleed > 0))
	if not hasRealInjury then return false end
	return true
end

module[2] = function(owner, org, timeValue)
	local organSystemsEnabled = hg.organism.OrganSystemsEnabled and hg.organism.OrganSystemsEnabled() or true
	notifyTemperatureStress(owner, org)

	if not organSystemsEnabled then
		org.heartstop = false
		org.terminalRhythm = nil
		org.unstableRhythm = nil
	end

	local o2Value = org.o2 and org.o2[1] or 30
	if not org.heartstop and not org.fibrillation and (org.arrhythmia or 0) < 0.25 and (org.myocardialOxygen or 1) > 0.55 then
		org.heartStrain = Approach(org.heartStrain or 0, 0, timeValue / 45)
	end

	local heart = getHeartEfficiency(org)
	local brain = math.Clamp(1 - org.brain * 1.5,0,1)
	local o2 = org.o2
	local o2 = halfValue2(o2[1], o2.range, o2.k)

	if org.isPly and not org.otrub and (heart == 0) then org.owner:Notify("My torso hurts a lot...",true,"heart",6) end
	if org.isPly and not org.otrub and org.heartstop then org.owner:Notify("",true,"heartstop",6) end

	local stamina = org.stamina
	
	if not org.alive then
		if hg.organism and hg.organism.ZeroVitals then
			hg.organism.ZeroVitals(org)
		else
			org.heartstop = true
			org.heartbeat = 0
			org.pulse = 0
			org.hypotension = 1
			org.hypertension = 0
		end
		return
	end

	if organSystemsEnabled then applyTemperatureTrauma(org) end

	local pulse = org.heartstop and 0 or 70-- + 120 * ((stamina.max or 180) - stamina[1]) / (stamina.max or 180) * (org.lungsfunction and 1 or 0)
	--pulse = pulse + math.min(org.adrenaline, 2) * 40 + (!org.otrub and math.max(org.fear * 50, 0) or 0)
	pulse = org.alive and pulse or 0
	pulse = math.Clamp(pulse, 0, 200)
	
	org.pulse = math.Approach(org.pulse, pulse, pulse > org.pulse and timeValue * 2 or timeValue * 2)
	
	local bloodNow = org.blood or 5000
	local hemorrhageCompensation = math.Clamp(org.hemorrhageCompensation or 0, 0, 1)
	local hypovolemicShock = math.Clamp(org.hypovolemicShock or 0, 0, 1)
	local palpitations = math.Clamp(org.palpitations or 0, 0, 1)
	local palpitationThreat = getPalpitationThreat(org, bloodNow, o2Value)
	local effectivePalpitations = palpitations * Lerp(palpitationThreat, 0.2, 1)
	local compensationPulseMultiplier = math.Clamp(1 - hemorrhageCompensation * 0.35 - hypovolemicShock * 0.1 - effectivePalpitations * 0.3, 0.35, 1)
	org.compensationPulseMultiplier = compensationPulseMultiplier
	local bloodPerfusionK = getBloodPerfusion(bloodNow)
	local k = heart * o2 * math.Clamp(bloodPerfusionK, 0, 1) * brain * (org.heartstop and 0 or 1)
	pulse = pulse * k
	pulse = pulse * compensationPulseMultiplier
	pulse = pulse * (math.Clamp(math.Remap(org.temperature, 28, 36.7, 0.5, 1), 0.5, 1))

	local bloodCrash = org.blood ~= nil and org.blood < 1500
	-- Loss of circulation is progressive while the organism is still alive. This
	-- leaves a short treatment window instead of turning a heart stop into an
	-- immediate zero-pulse state on the next organism tick.
	local dropRate = (heart == 0 or org.heartstop or bloodCrash) and timeValue * 6 or timeValue * 5
	org.pulse = math.Approach(org.pulse, pulse, dropRate)
	local bloodVolume = getBloodVolume(org)
	-- Stored O2 may outlast respiration briefly, but it cannot continue to
	-- sustain the myocardium once the lungs have stopped delivering oxygen.
	local oxygenation = Clamp(o2 * (org.oxygenIntakeAvailable == false and 0 or 1), 0, 1)
	local highSpeedPressureShock = updateHighSpeedPressureShock(owner, org, timeValue)
	local vascularTone = Clamp(1 + min(org.adrenaline, 3) * 0.12 + max(org.fear, 0) * 0.08 + Clamp(org.shock, 0, 45) / 360, 0.65, 1.55)
	local accelerationPressureMul = 1 - highSpeedPressureShock * 0.8
	local circulationBase = bloodVolume * heart * vascularTone * accelerationPressureMul * Clamp(Remap(org.temperature, 28, 36.7, 0.55, 1), 0.45, 1.1)
	local rhythmMul = org.fibrillation and 0.18 or Clamp(1 - (org.arrhythmia or 0) * 0.22, 0.5, 1)
	local dihSupport = (org.dihSupportUntil or 0) > CurTime()
	local defibGrace = (org.defibDeathGrace or 0) > CurTime() or (org.defibSupportUntil or 0) > CurTime()
	local cprSupport = (org.cprSupportUntil or 0) > CurTime()
	local cprSupportPulse = math.Clamp(tonumber(org.cprSupportPulse) or 40, 0, 70)
	local arrestCirculation = dihSupport and (70 / 92) or (defibGrace and 0.49 or (cprSupport and cprSupportPulse / 92 or 0))
	local circulation = org.alive and (org.heartstop and arrestCirculation or circulationBase * rhythmMul) or 0
	org.pulse = Approach(org.pulse, circulation * 92, heart == 0 and timeValue * 10 or timeValue * 5)
	org.cardiacOutput = org.heartstop and (dihSupport and 1 or (defibGrace and 0.35 or (cprSupport and cprSupportPulse / 110 or 0))) or Clamp(circulation * (92 / 90) * heart * rhythmMul, 0, 1.5)
	if not org.heartstop and not org.fibrillation and (org.arrhythmia or 0) < 0.25 and (org.myocardialOxygen or 1) > 0.65 and circulation > 0.6 then
		org.cardiacOutput = Approach(org.cardiacOutput, Clamp(getBloodVolume(org) * heart, 0, 1), timeValue / 20)
	end
	local myocardialTarget = Clamp(oxygenation * bloodVolume * Clamp(circulation * (92 / 70), 0, 1.2), 0, 1)
	if org.heartstop and defibGrace then myocardialTarget = math.max(myocardialTarget, 0.25) end
	org.myocardialOxygen = Approach(org.myocardialOxygen or 1, myocardialTarget, timeValue / 8)
	local hypotensionTarget = Clamp(Remap(circulation, 0.98, 0.22, 0, 1), 0, 1)
	local hypotensionRate = highSpeedPressureShock > 0.25 and timeValue / 2.5 or timeValue / 8
	org.hypotension = Approach(org.hypotension or 0, hypotensionTarget, hypotensionRate)
	org.hypertension = Approach(org.hypertension or 0, Clamp(Remap(circulation, 1.25, 1.68, 0, 1), 0, 1), timeValue / 20)

	-- Epinephrine supports a functioning respiratory/circulatory system; it
	-- must not manufacture cardiac or oxygen recovery after breathing has failed.
	local epinephrineStabilizing = (org.epinephrineStabilizationUntil or 0) > CurTime()
		and org.oxygenIntakeAvailable == true and not org.heartstop
	if epinephrineStabilizing then
		org.cardiacOutput = math.max(org.cardiacOutput or 0, 0.55)
		org.strokeVolume = math.max(org.strokeVolume or 0, 0.55)
		org.myocardialOxygen = math.max(org.myocardialOxygen or 0, 0.7)
		org.hypotension = math.min(org.hypotension or 1, 0.45)
		org.heartStrain = Approach(org.heartStrain or 0, 0, timeValue / 8)
		org.arrhythmia = Approach(org.arrhythmia or 0, 0, timeValue / 6)
	end

	org.fearadd = math.Clamp(org.fearadd, 0, 3)

	-- Keep the existing pressure compensation, with a continuous blood-volume
	-- calculation owning the baseline heart-rate response to hemorrhage.
	local perfusionPulse = org.pulse or 70
	local compensationRate = perfusionPulse < 70 and 70 + (70 - perfusionPulse) * 4 or perfusionPulse
	compensationRate = math.Clamp(compensationRate, 45, 300)
	local bloodCompensationRate = getBloodCompensationRate(bloodNow)
	org.compensationHeartRateTarget = bloodCompensationRate
	if bloodNow < 4500 then
		compensationRate = math.min(compensationRate, bloodCompensationRate)
	end

	local heartbeat = math.max(compensationRate, bloodCompensationRate)

	local staminaMax = math.max(org.stamina.max or 180, 1)
	local stamina = math.Clamp(org.stamina[1] or staminaMax, 0, staminaMax)
	-- Exertion only elevates the heart rate once 50 stamina has actually been lost.
	local exertionK = org.analgesia < 1 and math.Clamp((staminaMax - 50 - stamina) / math.max(staminaMax - 50, 1), 0, 1) or 0
	local exertionHeartBoost = exertionK * 32
	local runnin_or_exhausted = org.analgesia < 1 and (org.stamina.sub > 0 or org.stamina[1] < (org.stamina.max * 0.66))
	org.heartbeat = math.Approach(org.heartbeat, math.max(heartbeat - 10, runnin_or_exhausted and ((1 - math.min(1, org.stamina[1] / (org.stamina.max * 1))) * 110 + 90) or 60), !runnin_or_exhausted and timeValue * 2 or timeValue * 15)
	
	heartbeat = heartbeat + (owner.suiciding and 50 or 0)
	heartbeat = heartbeat + math.Clamp((org.shock or 0) - 20, 0, 40)
	heartbeat = heartbeat + math.Clamp(org.pain, 40, 80) - 40
	heartbeat = heartbeat + exertionHeartBoost
	local adrenalineHeartBoost = 9 * math.min(math.max((org.adrenaline or 0) - 1.5, 0), 3)
	heartbeat = heartbeat + adrenalineHeartBoost
	heartbeat = heartbeat - 40 * math.min(org.analgesia / 2.5, 1)
	heartbeat = heartbeat + 100 * math.Clamp(math.Remap(org.temperature, 40, 42, 0, 1), 0, 1)
	heartbeat = heartbeat - 160 * (1 - math.Clamp(math.Remap(org.temperature, 28, 36.7, 0, 1), 0, 1))
	if org.panicattackActive then heartbeat = heartbeat + 20 end -- adrenaline handles most of the boost

	-- Neurologic injury, oxygen starvation, myocardial damage, and cold each
	-- suppress the sinus node differently. This creates bradycardia first, then
	-- pause/junctional and ventricular escape ranges instead of one universal
	-- flatline path.
	local brainHemorrhage = math.Clamp(org.brainHemorrhage or 0, 0, 1)
	local cerebralSuppression = math.Clamp(math.max((org.brain or 0) * 0.8, brainHemorrhage) * 0.9, 0, 1)
	local hypoxiaSuppression = math.Clamp((12 - o2Value) / 12, 0, 1)
	local cardiacSuppression = math.Clamp(org.heart or 0, 0, 1)
	-- Compensation remains effective through mild cold. Below 34 C the sinus
	-- node and conduction system progressively lose responsiveness. At terminal
	-- blood volume, preload failure can also remove the prior tachycardia.
	local coldSuppression = math.Clamp((34 - (org.temperature or 36.7)) / 7, 0, 1)
	local hemorrhagicDecompensation = math.Clamp((2000 - bloodNow) / (2000 - cardiacArrestBlood), 0, 1)
	local zerlkersSuppression = math.Clamp(org.zerlkersOverdose or 0, 0, 1)
	-- Low blood volume produces tachycardia up to the terminal threshold; it
	-- must not be treated as a bradycardia source before the pump actually fails.
	local bradycardiaSeverity = math.max(cerebralSuppression, hypoxiaSuppression, cardiacSuppression * 0.9, coldSuppression, zerlkersSuppression)
	org.bradycardiaSeverity = bradycardiaSeverity
	org.hemorrhagicDecompensation = hemorrhagicDecompensation

	local bradyTarget
	if bradycardiaSeverity >= 0.16 then
		if bradycardiaSeverity >= 0.78 then
			bradyTarget = 28 -- ventricular escape: 20-40 BPM
		elseif bradycardiaSeverity >= 0.52 then
			bradyTarget = Lerp(math.Remap(bradycardiaSeverity, 0.52, 0.78, 0, 1), 45, 30)
		elseif bradycardiaSeverity >= 0.32 then
			bradyTarget = Lerp(math.Remap(bradycardiaSeverity, 0.32, 0.52, 0, 1), 58, 45)
		else
			bradyTarget = Lerp(math.Remap(bradycardiaSeverity, 0.16, 0.32, 0, 1), 66, 58)
		end
		heartbeat = math.min(heartbeat, bradyTarget)
	end

	-- Viability limits the maximum rate the body can sustain, but compensation
	-- should still exist. Do not multiply BPM down into impossible states like
	-- 45 pulse / 15 heartbeat unless the heart has actually stopped.
	local survivalK = math.Clamp(k, 0, 1)
	local maxCompensatedRate = math.Clamp(150 + survivalK * 110 + hemorrhageCompensation * 60 - hypovolemicShock * 12, 110, terminalHeartRate)
	maxCompensatedRate = math.max(maxCompensatedRate, bloodCompensationRate)
	if heart < 0.35 or brain < 0.35 then
		maxCompensatedRate = math.min(maxCompensatedRate, 85)
	end
	if org.heartstop then
		maxCompensatedRate = 0
	else
		local minPumpRate = perfusionPulse < 60 and 60 + (60 - perfusionPulse) * 0.4 or 45
		if bradyTarget then minPumpRate = math.min(minPumpRate, bradyTarget) end
		heartbeat = math.max(heartbeat, minPumpRate)
	end

	-- Hard physiological ceiling. Sustained rates above ~250 BPM are ventricular
	-- tachycardia/fibrillation; above ~300 the heart cannot fill and arrests.
	heartbeat = math.Clamp(heartbeat, 0, maxCompensatedRate)

	-- The cardiovascular response accelerates with blood loss. The old fixed
	-- 2.4 BPM/s rise lagged so far behind active bleeding that the target curve
	-- was never reached before pressure collapse.
	local compensationResponse = math.Clamp((5000 - bloodNow) / (5000 - cardiacArrestBlood), 0, 1)
	local riseRate = Lerp(compensationResponse, 5, 35)
	org.heartbeat = math.Approach(org.heartbeat, heartbeat, heartbeat > org.heartbeat and timeValue * riseRate or timeValue * 4.5)
	org.heartbeat = math.Clamp(org.heartbeat, 0, terminalHeartRate)

	-- Palpitations represent accumulated myocardial strain, rather than a
	-- momentary high BPM. Even moderate tachycardia eventually matters, while
	-- extreme rates build the condition rapidly; it then clears only gradually
	-- once the rhythm settles.
	local tachycardiaK = math.Clamp((org.heartbeat - 120) / 120, 0, 1)
	local correctingPalpitations = (org.palpitationTreatmentUntil or 0) > CurTime()
	if org.fibrillation then
		org.palpitations = 0
	elseif correctingPalpitations then
		org.palpitations = math.max(palpitations - timeValue / 4, 0)
	elseif tachycardiaK > 0 and not org.heartstop then
		org.palpitations = math.Clamp(palpitations + timeValue * (0.002 + tachycardiaK * 0.021), 0, 1)
	else
		org.palpitations = math.max(palpitations - timeValue / 90, 0)
	end
	palpitations = org.palpitations
	palpitationThreat = getPalpitationThreat(org, bloodNow, o2Value)
	effectivePalpitations = palpitations * Lerp(palpitationThreat, 0.2, 1)

	-- Blood loss drives the rhythm continuously toward 300 BPM at 2000 mL; at
	-- 1750 mL perfusion is zero and circulation cannot be sustained.
	local restartCirculationActive = (org.cardiacRestartUntil or 0) > CurTime()
	if not org.heartstop and bloodNow <= cardiacArrestBlood then
		org.heartstop = true
	end

	-- Severe cold and terminal preload failure destabilize the myocardium before
	-- arrest. Keep transient AF/ectopy visible, but let VF be a no-output
	-- electrical arrest rather than pretending it is a fast effective pulse.
	local severeCold = organSystemsEnabled and coldSuppression >= 0.62
	local terminalHemorrhage = bloodNow <= 2500
	if not (severeCold or terminalHemorrhage) then
		org.unstableRhythm = nil
		org.terminalRhythm = nil
	elseif not org.heartstop and (org.nextColdRhythmRoll or 0) <= CurTime() then
		org.nextColdRhythmRoll = CurTime() + 3
		-- Begin terminal electrical instability as soon as blood reaches 2500;
		-- it escalates sharply to certain arrest at 1750. This is separate from
		-- the ordinary arrhythmia system so a healthy heart can still briefly be
		-- rescued in the upper part of this range.
		local hemorrhageInstability = math.Clamp(math.Remap(bloodNow, 2500, cardiacArrestBlood, 0.3, 1), 0, 1)
		local instability = math.max(coldSuppression, hemorrhagicDecompensation, hemorrhageInstability)
		local roll = math.Rand(0, 1)
		if roll < 0.04 + instability * 0.36 then
			org.terminalRhythm = "ventricular_fibrillation"
			org.heartstop = true
		elseif roll < 0.20 + instability * 0.38 then
			org.unstableRhythm = "atrial_fibrillation"
		elseif roll < 0.48 + instability * 0.38 then
			org.unstableRhythm = "ventricular_ectopy"
		else
			org.unstableRhythm = nil
		end
	end

	-- Track sustained ventricular tachycardia for the probabilistic arrest
	-- check below. Low pressure/perfusion remains the deterministic flatline.
	if org.heartbeat > 250 and k < 0.65 then
		org._tachycardiaSince = org._tachycardiaSince or CurTime()
	else
		org._tachycardiaSince = nil
	end

	-- Probabilistic heartstop based on heart rate (kept as a softer fallback for
	-- the 200-300 range where rhythms become dangerous but not yet lethal).
	if organSystemsEnabled and not org.heartstop and (not org._heart_rate_check_time or CurTime() > org._heart_rate_check_time) then
		org._heart_rate_check_time = CurTime() + 1 -- check every second

		local hb = org.heartbeat
		local chance = 0
		local sustainedTachy = org._tachycardiaSince and org._tachycardiaSince + 3 < CurTime()
		local highTachyK = math.Clamp((hb - 130) / 120, 0, 1)
		if effectivePalpitations > 0.05 and highTachyK > 0 then
			-- A strained heart is especially likely to fail when it is still
			-- forced to race. Palpitations alone are mild; blood loss, shock,
			-- hypoxia, heart damage, or temperature stress restore their danger.
			chance = highTachyK * effectivePalpitations * 0.032
		end
		if bloodNow >= 4500 and sustainedTachy and hb >= 250 and k < 0.8 then
			chance = 0.06
		elseif bloodNow >= 4500 and sustainedTachy and hb >= 230 and k < 0.55 then
			chance = 0.025
		end

		if org.panicattackActive then chance = chance * 0.5 end
		if chance > 0 and math.random() < chance then
			org.heartstop = true
		end
	end

	if not org.heartstop then
		-- A compensating heartbeat can only modestly support perfusion. It must
		-- not make a weak pulse look normal simply because the heart is racing.
		local heartbeatNow = org.heartbeat or 70
		local pumpRateK = math.Clamp(heartbeatNow / 70, 0.25, 2.4)
		local fillingK = (1 - math.Clamp((heartbeatNow - 185) / 85, 0, 0.55)) * (1 - effectivePalpitations * 0.2)
		local maxPumpSupport = 1.1 - math.Clamp((heartbeatNow - 100) / 200, 0, 0.35)
		local pumpSupport = math.Clamp(pumpRateK * fillingK, 0.25, maxPumpSupport)
		local supportedPulse = math.Clamp(pulse * pumpSupport, 0, 200)
		if supportedPulse > org.pulse then
			org.pulse = math.Approach(org.pulse, supportedPulse, timeValue * 8)
		end
	end
	
	heartbeat = heartbeat + (org.hypotension or 0) * 55
	heartbeat = heartbeat - (org.myocardialOxygen and (1 - org.myocardialOxygen) or 0) * 35
	if (org.arrhythmia or 0) > 0.05 and not org.fibrillation then heartbeat = heartbeat + math.Rand(-70, 90) * org.arrhythmia end
	if org.fibrillation then heartbeat = math.Rand(180, 360) end

	org.heartbeat = math.Approach(org.heartbeat, heartbeat, heartbeat > org.heartbeat and timeValue * 5 or timeValue * 3)
	
	local ischemia = Clamp(1 - (org.myocardialOxygen or 1), 0, 1)
	local stress = Clamp((org.heart or 0) * 0.9 + ischemia * 0.8 + (org.hypertension or 0) * 0.35 + (org.hypotension or 0) * 0.3 + Clamp(org.shock, 0, 80) / 180 + max(org.pain - 60, 0) / 220 + max(org.heartbeat - 165, 0) / 190, 0, 2)
	org.arrhythmia = Approach(org.arrhythmia or 0, Clamp(stress * 0.42, 0, 1), stress > (org.arrhythmia or 0) and timeValue / 25 or timeValue / 90)
	if org.isPly and not org.otrub then
		if org.fibrillation or org.unstableRhythm or org.arrhythmia > 0.35 then
			owner:Notify("My heart rhythm feels irregular...", 45, "arrhythmia", 0, nil, Color(255, 170, 170))
		end
		if org.heartbeat >= 150 and not org.heartstop then
			owner:Notify("My heart is racing...", 45, "tachycardia", 0, nil, Color(255, 170, 170))
		elseif org.heartbeat > 0 and org.heartbeat <= 45 and not org.heartstop then
			owner:Notify("My heartbeat is becoming dangerously slow...", 45, "bradycardia", 0, nil, Color(150, 210, 255))
		end
	end
	if stress > 0.65 and CurTime() >= (org.nextArrhythmiaRoll or 0) then
		org.nextArrhythmiaRoll = CurTime() + Clamp(Remap(stress, 0.65, 1.6, 14, 3), 3, 14)
		if math.Rand(0, 1) < Clamp((stress - 0.65) * 0.12, 0.01, 0.18) then hg.organism.StartFibrillation(org) end
	end

	if org.heartbeat >= terminalHeartRate then
		hg.organism.StartFibrillation(org)
	end

	if org.fibrillation then
		org.consciousness = math.min(org.consciousness, 1 - Clamp(org.hypotension or 0, 0, 1))
		org.o2[1] = max(org.o2[1] - timeValue * 1.8, 0)
		if (org.fibrillationStart or CurTime()) + 24 < CurTime() or (org.cardiacOutput or 0) < 0.08 then org.heartstop = true end
	end
	if org.hypertension > 0.35 then org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * org.hypertension / 360, 0, 1) end
	if ischemia > 0.35 then org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * ischemia / 260, 0, 1) end
	if ischemia > 0.45 and org.isPly and not org.otrub and (org.lastCardiacPain or 0) < CurTime() then
		org.lastCardiacPain = CurTime() + math.Rand(14, 24)
		org.painadd = org.painadd + math.Rand(4, 9) * ischemia
		org.shock = math.max(org.shock, 10 + ischemia * 22)
	end
	if org.hypotension > 0.2 then org.consciousness = math.min(org.consciousness, 1 - Clamp(org.hypotension, 0, 1)) end

    if org.hypotension > 0.55 then
        -- Adrenaline, tranexamic acid and thiamine prevent low-circulation organ damage.
        local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
        local hasAntiIschemia = totalAdrenaline > 0.5 or (org.tranexamic_acid or 0) > 0 or (org.thiamine or 0) > 0
        if not hasAntiIschemia then
            local ischemiaK = math.Clamp((org.hypotension - 0.55) / 0.45, 0, 1)
            local damage = timeValue * ischemiaK * 0.005
            org.brain = math.min(org.brain + damage * 0.2, 1)
            org.heart = math.min(org.heart + damage, 1)
            org.liver = math.min(org.liver + damage * 0.5, 1)
            org.stomach = math.min(org.stomach + damage * 0.3, 1)
            org.intestines = math.min(org.intestines + damage * 0.3, 1)
        end
    end

	local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
	local adrenalineStabilizer = totalAdrenaline > 0.8
	
	-- Tranexamic acid and thiamine accelerate ischemia regression
	local hasAntiIschemia = (org.tranexamic_acid or 0) > 0 or (org.thiamine or 0) > 0

	if org.ischemia > 0 then
		if org.ischemia > 1 and not adrenalineStabilizer and not hasAntiIschemia then
			local ischemiaK = math.Clamp((org.ischemia - 1) / 5, 0, 1)
			local damage = timeValue * ischemiaK * 0.007
			org.brain = math.min(org.brain + damage * 0.2, 1)
			org.heart = math.min(org.heart + damage, 1)
			org.liver = math.min(org.liver + damage * 0.5, 1)
			org.stomach = math.min(org.stomach + damage * 0.3, 1)
			org.intestines = math.min(org.intestines + damage * 0.3, 1)
		end

		-- Epinephrine/adrenaline above 0.5 accelerates ischemia regression
		-- Tranexamic acid and thiamine also accelerate ischemia regression
		local decayRate = (adrenalineStabilizer or hasAntiIschemia) and timeValue / 4 or timeValue / 10
		org.ischemia = math.max(org.ischemia - decayRate, 0)
	end

	if org.hypotension > 0.2 then
		local disorientK = math.Clamp((org.hypotension - 0.2) / 0.5, 0, 1)
		org.disorientation = math.max(org.disorientation, 0.5 + disorientK * 1.0)
	end

	if org.hypotension > 0.14 then
		local staminaK = math.Clamp((org.hypotension - 0.14) / 0.41, 0, 1)
		local staminaLoss = staminaK * staminaK * (org.stamina.max * 2 / 3) / 60
		org.stamina[1] = math.max(org.stamina[1] - timeValue * staminaLoss, 0)
	end

	if org.hypotension > 0.64 then
		local shockK = math.Clamp((org.hypotension - 0.64) / 0.36, 0, 1)
		org.shock = math.Approach(org.shock, 20 + shockK * 45, timeValue * (0.5 + shockK * 1.5))
	end

	if org.hypotension > 0.5 then
		local lowK = math.Clamp((org.hypotension - 0.35) / 0.5, 0, 1)
		org.consciousness = math.Approach(org.consciousness, 0.75, timeValue * (0.08 + lowK * 0.11))
		if org.isPly and not org.otrub then
			org.owner:Notify("My limbs feel weak... My circulation is failing.", true, "low_perfusion", 0, nil, Color(200, 170, 170))
		end
	end

	-- Low pulse affects consciousness (below 40 BPM)
	if org.pulse < 40 then
		local pulseK = math.Clamp((40 - org.pulse) / 40, 0, 1)
		org.consciousness = math.max(org.consciousness - timeValue * pulseK * 0.15, 0)
	end

	if org.hypertension > 0 then
		local highK = math.Clamp(org.hypertension * 1.27, 0, 1)
		local adrenalineMitigation = math.Clamp(org.adrenaline / 3, 0, 1) * 0.25
		local effectiveHighK = highK * (1 - adrenalineMitigation)
		org.disorientation = math.max(org.disorientation, 0.25 + effectiveHighK * 1.5)
		org.shock = math.Approach(org.shock, math.max(org.shock, 10 + effectiveHighK * 20), timeValue * (0.4 + effectiveHighK * 1.4))
	end

	org.fear = math.Approach(org.fear, (org.otrub and 0 or (org.fearadd > 0 and 1 or -1)), org.otrub and timeValue * 0.5 or (org.fearadd > 0 and (org.fear < 0 and timeValue * 5 * org.fearadd or timeValue / 5 * org.fearadd) or (org.fear <= 0 and timeValue / 240 or timeValue / 50)))
	-- less time to start fearing, more time to become calm again
	-- if no fear, in 3 minutes become slightly talkative, so would say random phrases to calm themselves in a current situation
	local gainfear = hg.organism.should_gain_fear(org)
	org.fearadd = math.Approach(org.fearadd, 0, gainfear and timeValue or timeValue / 4.9) -- 15 seconds to stop fearing something and start to calm down
	local fearGainRate = gainfear and timeValue / 5 or 0
	org.fearadd = math.Approach(org.fearadd, 1, fearGainRate)
	
	-- Medication fills adrenalineAdd first; include that active dose so an
	-- epinephrine injection can affect an arrest before its normal decay tick.
	local adren = math.max(org.adrenaline or 0, org.adrenalineAdd or 0)

	local bloodCurveOwnsArrest = bloodNow <= 2500 and (org.heart or 0) < 0.8 and org.brain < 0.85
	if organSystemsEnabled then
		local failedCirculation = (org.pulse < 10 or org.hypotension > 0.92) and not bloodCurveOwnsArrest and not restartCirculationActive
		if failedCirculation or org.brain >= 0.85 or (org.heart >= 0.8 and org.blood < 1500) then org.heartstop = true end
		if org.temperature < 28 or org.temperature > 42 then org.heartstop = true end
	end
	-- A successful AED/epinephrine restart deliberately has a short window to
	-- rebuild circulation.  Do not immediately overwrite it here just because
	-- the previous arrest left the pulse at zero or caused temporary hypoxia.
	if (org.pulse < 10 or org.brain >= 0.6) and not restartCirculationActive then org.heartstop = true end
	if org.temperature < 28 or org.temperature > 42 then org.heartstop = true end
	if org.heartstop then
		org.heartbeat = 0
		org.fibrillation = false
		org.arrhythmia = 0
	end

	if org.temperature < 34 or org.temperature > 38 or org.blood < 4000 or org.pain > 20 then
		org.fear = math.max(org.fear, 0)
	end

	-- temperature
	local needed_temp = math.min(math.max(37 * (org.pulse / 45), 35), org.lowBloodTemperatureTarget or 36.7)
	local changeRate = timeValue / 60
	changeRate = changeRate * (org.temperature < needed_temp and math.Clamp(org.heatbuff / 60, 1, 2) or 1)
	if math.abs(org.tempchanging) < changeRate then
		org.temperature = math.Approach(org.temperature, needed_temp, changeRate)
	else
		org.needed_temp = needed_temp
	end
	
	if not org.heartstop then
		org.last_heartbeat = CurTime()
	end

	-- Epinephrine can sometimes restore a reversible arrest, but each injector
	-- dose receives exactly one attempt. Natural/combat adrenaline must not make
	-- the patient reroll a restart every pulse tick.
	if org.heartstop and org.epinephrineRestartPending then
		org.epinephrineRestartPending = nil
		local canRestartHeart = org.alive and (org.blood or 5000) >= 800 and (not organSystemsEnabled or ((org.heart or 0) < 1 and (org.brain or 0) < 0.85 and (org.temperature or 36.7) >= 28 and (org.temperature or 36.7) <= 42))
		local dose = math.Clamp(org.epinephrineRestartDose or adren or 0, 0, 4)
		org.epinephrineRestartDose = nil
		local chance = math.Clamp(35 + dose * 18, 0, 80)
		chance = chance * math.Clamp(1 - (org.heart or 0) * 0.65, 0.2, 1)
		if (org.o2 and (org.o2[1] or 0) < 5) or (org.hypotension or 0) > 0.98 then
			chance = chance * 0.6
		end
		local rand = math.random(100)

		if canRestartHeart and chance > rand then
			org.heartstop = false
			org.terminalRhythm = nil
			org.unstableRhythm = nil
			org.cardiacArrestStart = nil
			org.cardiacArrestO2Start = nil
			org._zeroO2Time = 0
			org.heartbeat = math.Clamp(org.heartbeat > 0 and org.heartbeat or 90, 80, 140)
			org.pulse = math.max(org.pulse or 0, 35)
			org.hypotension = math.min(org.hypotension or 1, 0.5)
			org.cardiacRestartUntil = CurTime() + 2
			if org.o2 then
				local o2Restore = math.Clamp(adren * 2.5, 8, 12)
				org.o2[1] = math.max(org.o2[1], o2Restore)
			end
		end
	end

	-- Electrical activity, a palpable pulse, and cardiac output are separate.
	-- PEA therefore keeps a weak ECG trace briefly while pressure and pulse are 0.
	if org.heartstop then
		if not org.cardiacArrestStart then
			org.cardiacArrestStart = CurTime()
			org.cardiacArrestO2Start = math.Clamp(org.o2 and org.o2[1] or 0, 0, 6)
		end

		local arrestElapsed = math.max(CurTime() - org.cardiacArrestStart, 0)
		if org.terminalRhythm == "ventricular_fibrillation" and arrestElapsed < peaDuration then
			org.heartbeat = 260
			org.ecgState = "ventricular_fibrillation"
		elseif arrestElapsed < peaDuration then
			local peaTarget = Lerp(math.Clamp(arrestElapsed / peaDuration, 0, 1), 60, 20)
			org.heartbeat = math.Approach(org.heartbeat or terminalHeartRate, peaTarget, timeValue * 120)
			org.ecgState = "pea"
		else
			org.heartbeat = math.Approach(org.heartbeat or 0, 0, timeValue * 40)
			org.ecgState = org.heartbeat < 1 and "asystole" or "pea"
		end
		if arrestElapsed >= peaDuration then
			org.terminalRhythm = nil
		end

		if dihSupport then
			org.pulse = 70
			org.heartbeat = 70
			org.strokeVolume = 1
			org.cardiacOutput = 1
			org.hypotension = 0
			org.hypertension = 0
		else
			org.pulse = cprSupport and math.max(tonumber(org.cprSupportPulse) or 20, 12) or 0
			org.strokeVolume = cprSupport and 0.2 or 0
		end
	else
		org.cardiacArrestStart = nil
		org.cardiacArrestO2Start = nil
		org.ecgState = hg.organism.GetECGState(org.heartbeat or 0, false, org)
	end

	if org.heartstop then
		org.heartstoptime = org.heartstoptime or CurTime()
		if org.isPly then
	        org.owner:Notify("I'm feeling dizzy...", true, "heartstop", 10)
		end
	else
		if org.isPly then
			org.owner:ResetNotification("heartstop")
		end
		org.heartstoptime = nil
	end

	if org.alive and org.heartstoptime and org.heartstoptime + 30 < CurTime() and (org.lastsoundtime or 0) < CurTime() and org.otrub then
		org.owner:EmitSound("breathing/agonalbreathing_"..math.random(13)..".wav", 60)
		--org.owner:EmitSound("breathing/agonalbreathing_"..math.random(13)..".wav", 50)
		
		org.lastsoundtime = CurTime() + math.random(25,35)
	end

end

--if org.heartstop then org.needotrub = true end --не совсем...
util.AddNetworkString("pulse")
function hg.organism.Pulse(owner, org, timeValue)
	local stamina = org.stamina
	if org.o2[1] > 1 and org.alive and org.heart < 1 and org.brain < 0.6 then
		--org.brain = max(org.brain - timeValue / 30, 0) --regen
	end--brain damage is usually permanent

	if owner:IsPlayer() and owner:Alive() then
		net.Start("pulse")
		net.Send(owner)
	end
end

