local min, max, Round, halfValue2 = math.min, math.max, math.Round, util.halfValue2
--local Organism = hg.organism
hg.organism.module.pulse = {}
local module = hg.organism.module.pulse

local BloodBPM = {
	{5000, 75},
	{4500, 95},
	{4200, 110},
	{3800, 135},
	{3400, 165},
	{3000, 205},
	{2600, 250},
	{2300, 280},
	{2000, 300},
}

-- 2000 mL is the beginning of severe shock, not an instant flatline. A
-- hemorrhaging organism can still compensate there; terminal bradycardia and
-- arrest need a further loss of preload/cardiac output.
local cardiacArrestBlood = 900
local terminalHeartRate = 300
local peaDuration = 6

local function getPalpitationThreat(org, blood, o2Value)
	local lowBlood = math.Clamp((4000 - blood) / 2000, 0, 1)
	local lowPressure = math.Clamp((65 - (org.bloodpressure or 93)) / 40, 0, 1)
	local hypoxia = math.Clamp((12 - o2Value) / 12, 0, 1)
	local shock = math.Clamp((org.shock or 0) / 60, 0, 1)
	local heartDamage = math.Clamp(org.heart or 0, 0, 1)
	local temperatureStress = math.max(
		math.Clamp((34 - (org.temperature or 36.7)) / 6, 0, 1),
		math.Clamp(((org.temperature or 36.7) - 39) / 3, 0, 1)
	)

	return math.max(lowBlood, lowPressure, hypoxia, shock, heartDamage, temperatureStress)
end

local function interpolateCurve(curve, value)
	value = tonumber(value) or curve[1][1]
	if value >= curve[1][1] then return curve[1][2] end

	for i = 1, #curve - 1 do
		local high = curve[i]
		local low = curve[i + 1]
		if value <= high[1] and value >= low[1] then
			local fraction = math.Clamp((high[1] - value) / (high[1] - low[1]), 0, 1)
			return Lerp(fraction, high[2], low[2])
		end
	end

	return curve[#curve][2]
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
	local hemorrhagicDecompensation = math.Clamp((1500 - (org.blood or 5000)) / 600, 0, 1)
	local suppression = math.max(cerebral * 0.9, hypoxia, cardiac * 0.9, cold, hemorrhagicDecompensation)

	-- Complete/partial AV block is a direct conduction-system injury pattern,
	-- while severe systemic failure falls back to an escape rhythm.
	if cardiac >= 0.72 and heartbeat > 40 then return "av_block_complete" end
	if cardiac >= 0.4 and heartbeat > 45 then return "av_block_partial" end
	if org.terminalRhythm == "ventricular_fibrillation" then return "ventricular_fibrillation" end
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
		org.bloodpressure = 93
	org.systolic = 120
	org.diastolic = 80

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
	if not organSystemsEnabled then
		org.heartstop = false
		org.terminalRhythm = nil
		org.unstableRhythm = nil
	end

	local heart = organSystemsEnabled and 1 - org.heart or 1
	-- Brain damage weakens the heart's neurological drive.
	local brain = organSystemsEnabled and math.Clamp(1 - org.brain * 1.5, 0, 1) or 1
	local o2Value = org.o2 and org.o2[1] or 30
	local o2 = organSystemsEnabled and halfValue2(o2Value, org.o2.range, org.o2.k) or 1

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
			org.bloodpressure = 0
			org.systolic = 0
			org.diastolic = 0
		end
		return
	end

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
	-- Blood volume begins weakening effective perfusion at 3500 mL. Keeping
	-- full perfusion above that point prevents compensation from starting early.
	local bloodPerfusionK = bloodNow >= 3500 and 1 or math.Remap(math.Clamp(bloodNow, 1000, 3500), 1000, 3500, 0, 1)
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

	org.fearadd = math.Clamp(org.fearadd, 0, 3)

	-- Keep the existing pressure compensation, but let the configured blood
	-- curve own the baseline heart-rate response to hemorrhage.
	local perfusionPulse = org.pulse or 70
	local compensationRate = perfusionPulse < 70 and 70 + (70 - perfusionPulse) * 4 or perfusionPulse
	compensationRate = math.Clamp(compensationRate, 45, 300)
	local bloodCompensationRate = interpolateCurve(BloodBPM, math.Clamp(bloodNow, 0, 5000))
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
	local hemorrhagicDecompensation = math.Clamp((1500 - bloodNow) / 600, 0, 1)
	local bradycardiaSeverity = math.max(cerebralSuppression, hypoxiaSuppression, cardiacSuppression * 0.9, coldSuppression, hemorrhagicDecompensation)
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
	if correctingPalpitations then
		org.palpitations = math.max(palpitations - timeValue / 4, 0)
	elseif tachycardiaK > 0 and not org.heartstop then
		org.palpitations = math.Clamp(palpitations + timeValue * (0.002 + tachycardiaK * 0.021), 0, 1)
	else
		org.palpitations = math.max(palpitations - timeValue / 90, 0)
	end
	palpitations = org.palpitations
	palpitationThreat = getPalpitationThreat(org, bloodNow, o2Value)
	effectivePalpitations = palpitations * Lerp(palpitationThreat, 0.2, 1)

	-- At terminal blood volume, bradycardia/poor filling finally progress to
	-- deterministic arrest. The 2000 mL band remains severe compensated shock.
	local restartCirculationActive = (org.cardiacRestartUntil or 0) > CurTime()
	if not org.heartstop and not restartCirculationActive and bloodNow <= cardiacArrestBlood and (org.heartbeat <= 40 or bradycardiaSeverity >= 0.7) then
		org.heartstop = true
	end

	-- Severe cold and terminal preload failure destabilize the myocardium before
	-- arrest. Keep transient AF/ectopy visible, but let VF be a no-output
	-- electrical arrest rather than pretending it is a fast effective pulse.
	local severeCold = organSystemsEnabled and coldSuppression >= 0.62
	local terminalHemorrhage = hemorrhagicDecompensation >= 0.7
	if not (severeCold or terminalHemorrhage) then
		org.unstableRhythm = nil
		org.terminalRhythm = nil
	elseif not org.heartstop and (org.nextColdRhythmRoll or 0) <= CurTime() then
		org.nextColdRhythmRoll = CurTime() + 3
		local instability = math.max(coldSuppression, hemorrhagicDecompensation)
		local roll = math.Rand(0, 1)
		if roll < 0.025 + instability * 0.055 then
			org.terminalRhythm = "ventricular_fibrillation"
			org.heartstop = true
		elseif roll < 0.2 + instability * 0.18 then
			org.unstableRhythm = "atrial_fibrillation"
		elseif roll < 0.45 + instability * 0.2 then
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
	
	local blood = math.Clamp(org.blood or 5000, 0, 5000)
	local bloodK = math.Clamp((blood - 2000) / 2000, 0, 1)
	local o2K = math.Clamp(o2, 0, 1)
	local heartK = math.Clamp(1 - org.heart, 0, 1)
	local brainK = math.Clamp(1 - org.brain * 1.25, 0, 1)
	local hypothermiaK = math.Clamp(math.Remap(org.temperature, 28, 36.7, 0.45, 1), 0.45, 1)
	local adrenalineHyperMul = math.Clamp(org.adrenaline, 0, 5) * 0.025
	local hypertensionMul = 1 + adrenalineHyperMul + math.Clamp(org.pain, 0, 120) / 120 * 0.06 + math.Clamp(org.shock, 0, 80) / 80 * 0.08
	hypertensionMul = hypertensionMul * (1 - math.Clamp(org.analgesia / 4, 0, 1) * 0.08)
	hypertensionMul = math.Clamp(hypertensionMul, 0.72, 1.45)

	local compensation = 1 + hemorrhageCompensation * 0.45 * (1 - effectivePalpitations * 0.75)
	compensation = compensation * (1 - hypovolemicShock * 0.2)
	compensation = math.Clamp(compensation, 0.45, 1.4)

	local pumpRateK = math.Clamp((org.heartbeat or 70) / 70, 0.25, 2.4)
	local fillingK = (1 - math.Clamp(((org.heartbeat or 70) - 185) / 85, 0, 0.55)) * (1 - effectivePalpitations * 0.2)
	local pulse_factor = (org.pulse / 70) * math.Clamp(pumpRateK * fillingK, 0.45, 1.12)
	local volumeMapK = blood >= 3500 and 1 or math.Remap(math.Clamp(blood, 1000, 3500), 1000, 3500, 0.12, 1)
	local map = 93 * pulse_factor * hypertensionMul * compensation * volumeMapK
	map = org.alive and map or 0

	if org.heartstop then
		map = 0
	end

	-- High velocity reduces blood pressure (falling or rapid acceleration only)
	-- Skip for ragdolled players: ragdoll physics jitter causes false velocity spikes
	local velocityPenalty = 0
	local isRagdolled = owner:IsPlayer() and (IsValid(owner.FakeRagdoll) or IsValid(owner:GetNWEntity("FakeRagdoll", NULL)) or org.needfake or org.otrub)
	if not isRagdolled then
		local velocity = owner:GetVelocity()
		local speed = velocity:Length()
		local fallSpeed = math.max(0, -velocity.z)

		-- Falling causes G-force blood pressure loss
		if fallSpeed > 100 then
			velocityPenalty = math.Clamp((fallSpeed - 100) / 400, 0, 0.9)
		end

		-- Rapid deceleration (e.g., vehicle crashes, slamming into walls) causes G-force loss
		local prevSpeed = org._pulsePrevSpeed or speed
		local decel = math.max(0, prevSpeed - speed) / math.max(timeValue, 0.001)
		if decel > 800 and velocity.z <= 0 then
			velocityPenalty = math.min(velocityPenalty + math.Clamp((decel - 800) / 800, 0, 0.2), 0.95)
		end
		org._pulsePrevSpeed = speed
	else
		org._pulsePrevSpeed = nil
	end

	if velocityPenalty > 0 then
		map = map * (1 - velocityPenalty)
	end

	-- Keep the existing mmHg model, but make its pressure target respond to
	-- Vottur's separate loss channels instead of waiting only for blood volume
	-- to fall. Arterial loss causes the sharpest immediate pressure collapse.
	local arterialLoss = math.max(org.arterialBleed or 0, 0)
	local venousLoss = math.max(org.venousBleed or 0, 0)
	local internalLoss = math.max(org.internalBleedRate or 0, 0)
	local bleedPressureLoss = math.Clamp(arterialLoss / 18, 0, 0.50)
		+ math.Clamp(venousLoss / 65, 0, 0.18)
		+ math.Clamp(internalLoss / 45, 0, 0.22)
	local throatPressureLoss = math.Clamp(org.throatCutPressureShock or 0, 0, 1) * 0.22
	map = map * math.Clamp(1 - bleedPressureLoss - throatPressureLoss, 0.08, 1)

	map = math.Clamp(map, 0, 190)
	local bpTarget = map
	local bpCurrent = org.bloodpressure or 93
	local bpRate = (bpTarget > bpCurrent) and 14 or 10
	if velocityPenalty > 0 then
		bpRate = bpRate * (1 + velocityPenalty * 4)
	end
	org.bloodpressure = math.Approach(bpCurrent, bpTarget, timeValue * bpRate)

	local pulsePressure = 40 * heartK * math.max(bloodK, 0.3)
	pulsePressure = pulsePressure * (1 + math.Clamp((org.heartbeat - 70) / 180, -0.2, 0.6))
	pulsePressure = math.Clamp(pulsePressure, 8, 95)

	local targetDiastolic = math.Clamp(org.bloodpressure - pulsePressure * 0.5, 0, 180)
	local targetSystolic = math.Clamp(targetDiastolic + pulsePressure, 0, 260)

	org.diastolic = math.Approach(org.diastolic or 80, targetDiastolic, timeValue * 16)
	org.systolic = math.Approach(org.systolic or 120, targetSystolic, timeValue * 16)

    if org.bloodpressure < 50 then
        -- Adrenaline, tranexamic acid and thiamine prevent organ damage from low blood pressure
        local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
        local hasAntiIschemia = totalAdrenaline > 0.5 or (org.tranexamic_acid or 0) > 0 or (org.thiamine or 0) > 0
        if not hasAntiIschemia then
            local ischemiaK = math.Clamp((50 - org.bloodpressure) / 30, 0, 1)
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

	-- Disorientation: 0.5 at BP 75, 1.5 at BP 40
	if org.bloodpressure < 75 then
		local disorientK = math.Clamp((75 - org.bloodpressure) / 35, 0, 1)
		org.disorientation = math.max(org.disorientation, 0.5 + disorientK * 1.0)
	end

	-- Stamina loss: starts at BP 80, small/slow, builds to 2/3 at BP 50
	if org.bloodpressure < 80 then
		local staminaK = math.Clamp((80 - org.bloodpressure) / 30, 0, 1)
		local staminaLoss = staminaK * staminaK * (org.stamina.max * 2 / 3) / 60 -- scales quadratically, reaches 2/3 over ~60 seconds at BP 50
		org.stamina[1] = math.max(org.stamina[1] - timeValue * staminaLoss, 0)
	end

	-- Shock: only starts at BP 45, slower buildup
	if org.bloodpressure < 45 then
		local shockK = math.Clamp((45 - org.bloodpressure) / 30, 0, 1)
		org.shock = math.Approach(org.shock, 20 + shockK * 45, timeValue * (0.5 + shockK * 1.5))
	end

	if org.bloodpressure < 55 then
		local lowK = math.Clamp((65 - org.bloodpressure) / 35, 0, 1)
		org.consciousness = math.Approach(org.consciousness, 0.75, timeValue * (0.08 + lowK * 0.11))
	end

	-- Low pulse affects consciousness (below 40 BPM)
	if org.pulse < 40 then
		local pulseK = math.Clamp((40 - org.pulse) / 40, 0, 1)
		org.consciousness = math.max(org.consciousness - timeValue * pulseK * 0.15, 0)
	end

	if org.bloodpressure > 115 then
		local highK = math.Clamp((org.bloodpressure - 115) / 55, 0, 1)
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
	
	local adrenK = max(1 + org.adrenaline, 1)
	-- Medication fills adrenalineAdd first; include that active dose so an
	-- epinephrine injection can affect an arrest before its normal decay tick.
	local adren = math.max(org.adrenaline or 0, org.adrenalineAdd or 0)

	local bloodCurveOwnsArrest = bloodNow <= 2300 and (org.heart or 0) < 0.8 and org.brain < 0.85
	if organSystemsEnabled then
		local failedCirculation = (org.pulse < 10 or org.bloodpressure < 25) and not bloodCurveOwnsArrest and not restartCirculationActive
		if failedCirculation or org.brain >= 0.85 or (org.heart >= 0.8 and org.blood < 1500) then org.heartstop = true end
		if org.temperature < 28 or org.temperature > 42 then org.heartstop = true end
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

	if org.heartstop and adren > 0 and (org.adrenaline_try or 0) < CurTime() then
		local canRestartHeart = org.alive and (org.blood or 5000) >= 800 and (not organSystemsEnabled or ((org.heart or 0) < 1 and (org.brain or 0) < 0.85 and (org.temperature or 36.7) >= 28 and (org.temperature or 36.7) <= 42))
		-- Scale chance with adrenaline level: significantly improved effectiveness
		-- Low dose (1): ~70% chance, Medium dose (2): ~90% chance, High dose (4+): near-certain
		local chance = math.Clamp(adren * 60 + adren * adren * 12, 0, 99)
		chance = chance * math.Clamp(1 - (org.heart or 0) * 0.65, 0.2, 1)
		if (org.o2 and (org.o2[1] or 0) < 5) or (org.bloodpressure or 0) < 15 then
			chance = chance * 0.6
		end
		local rand = math.random(100)

		-- High adrenaline retries faster (0.02s at adren>=3, 0.04s otherwise)
		org.adrenaline_try = CurTime() + (adren >= 3 and 0.02 or 0.04)

		if canRestartHeart and chance > rand then
			org.heartstop = false
			org.terminalRhythm = nil
			org.unstableRhythm = nil
			org.cardiacArrestStart = nil
			org.cardiacArrestO2Start = nil
			org._zeroO2Time = 0
			org.heartbeat = math.Clamp(org.heartbeat > 0 and org.heartbeat or 90, 80, 140)
			org.pulse = math.max(org.pulse or 0, 35)
			org.bloodpressure = math.max(org.bloodpressure or 0, 55)
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

		org.pulse = 0
		org.strokeVolume = 0
		org.cardiacOutput = 0
		org.bloodpressure = 0
		org.systolic = 0
		org.diastolic = 0
	else
		org.cardiacArrestStart = nil
		org.cardiacArrestO2Start = nil
		-- CO = HR x SV. Blood volume, cardiac damage, cold contractility, and
		-- insufficient diastolic filling each reduce stroke volume; a high rate
		-- alone cannot make a thready hypovolemic pulse look effective.
		local rateK = math.Clamp((org.heartbeat or 0) / 75, 0, 2.5)
		local fillingK = (1 - math.Clamp(((org.heartbeat or 75) - 180) / 120, 0, 0.7)) * (1 - effectivePalpitations * 0.25)
		local strokeVolume = volumeMapK * (organSystemsEnabled and (1 - math.Clamp(org.heart or 0, 0, 1)) * hypothermiaK or 1) * fillingK
		org.strokeVolume = math.Clamp(strokeVolume, 0, 1.2)
		org.cardiacOutput = math.Clamp(rateK * org.strokeVolume, 0, 1.5)
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

	local circulatoryRisk = (org.bloodpressure or 93) < 55 or (org.pulse or 70) < 35 or (org.blood or 5000) < 2200 or (org.o2 and (org.o2[1] or 30) < 8)

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
