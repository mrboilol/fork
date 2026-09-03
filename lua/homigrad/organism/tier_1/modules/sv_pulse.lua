local min, max, halfValue2 = math.min, math.max, util.halfValue2
local Clamp, Approach, Remap = math.Clamp, math.Approach, math.Remap
--local Organism = hg.organism
hg.organism.module.pulse = {}
local module = hg.organism.module.pulse

-- Blood-volume response is calculated rather than sampled from lookup tables.
-- Delivery approaches zero with actual circulating volume; sustained severe
-- loss also contributes a smooth collapse hazard rather than a hard cutoff.
local terminalHeartRate = 300
local peaDuration = 6
local cardiacArrestMechanicalDecayTime = 14
local hypotensionComplicationTime = 45
local arrhythmiaComplicationTime = 75

function hg.organism.BeginCardiacArrestMechanicalDecay(org)
	if not org or org.cardiacArrestMechanicalInitial then return end

	org.cardiacArrestMechanicalStart = CurTime()
	org.cardiacArrestMechanicalInitial = {
		pulse = math.max(tonumber(org.pulse) or 0, 0),
		bloodPressure = math.max(tonumber(org.bloodPressure) or 0, 0),
		cardiacOutput = math.max(tonumber(org.cardiacOutput) or 0, 0)
	}
end

function hg.organism.ClearCardiacArrestMechanicalDecay(org)
	if not org then return end
	org.cardiacArrestMechanicalStart = nil
	org.cardiacArrestMechanicalInitial = nil
end

function hg.organism.GetCardiacArrestMechanicalFactor(org)
	if not org then return 0, nil end
	if not org.cardiacArrestMechanicalInitial then
		hg.organism.BeginCardiacArrestMechanicalDecay(org)
	end

	local initial = org.cardiacArrestMechanicalInitial
	if not initial then return 0, nil end
	local elapsed = math.max(CurTime() - (org.cardiacArrestMechanicalStart or CurTime()), 0)
	return math.Clamp(1 - elapsed / cardiacArrestMechanicalDecayTime, 0, 1), initial
end

function hg.organism.GetBloodDeliveryFraction(blood, scale)
	local cfg = hg.organism.config or {}
	local normalBlood = math.max(tonumber(cfg.NORMAL_BLOOD_VOLUME_ML) or hg.organism.normalBloodVolume or 5000, 1)
	local volumeFraction = math.Clamp((tonumber(blood) or normalBlood) / normalBlood, 0, 1)
	local curve = math.max(tonumber(cfg.HEMORRHAGE_PERFUSION_EXPONENT) or 1.7, 0.05)
	return math.Clamp(volumeFraction ^ curve * (tonumber(scale) or 1), 0, 1)
end

function hg.organism.GetHemorrhageCompensationDrive(blood)
	local reserve = hg.organism.GetBloodDeliveryFraction(blood, 1)
	local cfg = hg.organism.config or {}
	local bradyReserve = math.Clamp(tonumber(cfg.HEMORRHAGE_BRADYCARDIA_RESERVE) or 0.14, 0.05, 0.9)
	return math.Clamp((1 - reserve) / math.max(1 - bradyReserve, 0.05), 0, 1)
end

local function getHemorrhageDanger(blood)
	local normalBlood = math.max(tonumber((hg.organism.config or {}).NORMAL_BLOOD_VOLUME_ML) or hg.organism.normalBloodVolume or 5000, 1)
	local volumeFraction = math.Clamp((tonumber(blood) or normalBlood) / normalBlood, 0, 1)
	return math.Clamp((0.60 - volumeFraction) / 0.20, 0, 1) ^ 1.2
end

function hg.organism.UpdateVitalHealthToll(owner, org, timeValue)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	if not hg.organism.OrganSystemsEnabled() or not hg.organism.CanTouchHealth or not hg.organism.CanTouchHealth(org) then
		org.vitalHealthStress = 0
		org.vitalHealthCeiling = nil
		org.vitalHealthDamageCarry = 0
		return
	end

	local normalBlood = math.max(tonumber((hg.organism.config or {}).NORMAL_BLOOD_VOLUME_ML) or hg.organism.normalBloodVolume or 5000, 1)
	local bloodLoss = math.Clamp(1 - (tonumber(org.blood) or normalBlood) / normalBlood, 0, 1)
	local bloodLossK = hg.organism.GetSmoothSeverity(bloodLoss, 0.12, 0.72, 1.35)
	local hypotensionK = hg.organism.GetSmoothSeverity(org.hypotension or 0, 0.18, 0.80, 1.20)
	local arrhythmiaK = math.Clamp(tonumber(org.arrhythmia) or 0, 0, 1)
	if org.unstableRhythm then arrhythmiaK = math.max(arrhythmiaK, 0.35) end
	if org.fibrillation then arrhythmiaK = 1 end
	local pulse = math.max(tonumber(org.pulse) or 0, 0)
	local bradycardiaK = hg.organism.GetSmoothSeverity(55 - pulse, 0, 45, 1.10)
	local tachycardiaK = hg.organism.GetSmoothSeverity(pulse, 130, 220, 1.20)
	local activeBleedK = hg.organism.GetSmoothSeverity(org.bleed or 0, 0.15, 4, 1.10)

	local circulationK = math.max(bloodLossK, hypotensionK, bradycardiaK, arrhythmiaK * 0.8)
	local tachycardiaStress = tachycardiaK * math.max(bloodLossK, hypotensionK, arrhythmiaK * 0.65)
	local vitalStress = math.Clamp(math.max(circulationK, tachycardiaStress) + activeBleedK * circulationK * 0.25, 0, 1)
	org.vitalHealthStress = vitalStress

	local maxHealth = math.max(owner:GetMaxHealth(), 1)
	org.vitalHealthCeiling = math.max(maxHealth * (1 - vitalStress * 0.8), maxHealth * 0.2)
	if vitalStress <= 0 then return end

	org.vitalHealthDamageCarry = (org.vitalHealthDamageCarry or 0) + (0.12 + vitalStress ^ 1.55 * 3.9) * timeValue
	local healthLoss = math.floor(org.vitalHealthDamageCarry)
	if healthLoss > 0 then
		org.vitalHealthDamageCarry = org.vitalHealthDamageCarry - healthLoss
		owner:SetHealth(math.max(owner:Health() - healthLoss, 1))
	end
end

local function canReceiveResuscitationBreathing(org)
	if not org or not org.alive or org.deathStateKilled or not org.o2 then return false end
	local owner = org.owner
	if IsValid(owner) and owner.noHead then return false end
	local leftLung = istable(org.lungsL) and (tonumber(org.lungsL[1]) or 0) or 0
	local rightLung = istable(org.lungsR) and (tonumber(org.lungsR[1]) or 0) or 0
	if leftLung >= 1 and rightLung >= 1 then return false end
	if (tonumber(org.trachea) or 0) >= 1 or (tonumber(org.hemothorax) or 0) >= 0.9 then return false end
	if (tonumber(org.brain) or 0) >= 0.85 then return false end
	if (tonumber(org.spine3) or 0) >= 1 then return false end
	if IsValid(owner) and owner:WaterLevel() >= 3
		and not (hg.organism.HasUnderwaterOxygen and hg.organism.HasUnderwaterOxygen(org)) then return false end
	return true
end

function hg.organism.RestoreSupportedOxygen(org, amount, targets)
	if not org or not org.o2 then return false end

	amount = math.Clamp(tonumber(amount) or 0, 0, 1)
	if amount <= 0 then return false end
	targets = targets or {}
	if org.oxygenIntakeAvailable == false
		and not (targets.artificialSupport == true and canReceiveResuscitationBreathing(org)) then return false end
	local bloodReserve = hg.organism.GetBloodDeliveryFraction(org.blood, 1)
	local support = amount * bloodReserve
	if support <= 0 then return false end

	local oxygenTarget = math.Clamp(tonumber(targets.oxygenTarget) or targets.oxygen or org.o2[1], 0, org.o2.range or 30)
	if targets.oxygen then
		org.o2[1] = math.min(oxygenTarget, math.max(org.o2[1] or 0, tonumber(targets.oxygen) or 0))
	end

	for _, key in ipairs({"bodyoxygen", "brainoxygen", "perfusion", "peripheralperfusion", "cerebralPerfusion", "myocardialOxygen"}) do
		local target = tonumber(targets[key .. "Target"]) or tonumber(targets[key])
		if target then
			org[key] = math.Approach(tonumber(org[key]) or 0, math.Clamp(target, 0, 1), support)
		end
	end

	for _, key in ipairs({"hypoxiaTime", "severeHypoxiaTime", "systemicIschemiaTime"}) do
		local reduction = tonumber(targets[key])
		if reduction then
			org[key] = math.max((tonumber(org[key]) or 0) - reduction * support, 0)
		end
	end

	return true
end

function hg.organism.TryRestoreBreathingWithResuscitation(org, strength)
	if not canReceiveResuscitationBreathing(org) or org.heartstop or org.respiratoryArrest then return false end
	strength = math.Clamp(tonumber(strength) or 0.5, 0.1, 1)
	org.lungsfunction = true
	org.oxygenIntakeAvailable = true
	org.bradyapnea = math.Approach(tonumber(org.bradyapnea) or 0, 0, 0.35 * strength)
	org.respiratoryRate = math.max(tonumber(org.respiratoryRate) or 0, math.Round(8 + 6 * strength))
	if hg.organism.OxygenateBlood then
		org.o2.curregen = math.max(tonumber(org.o2.curregen) or 0, hg.organism.OxygenateBlood(org))
	end
	local oxygenFloor = math.min(tonumber(org.o2.range) or 30, 4 + 6 * strength)
	org.o2[1] = math.max(tonumber(org.o2[1]) or 0, oxygenFloor)
	return true
end

local function getBloodPerfusion(blood)
	-- Preserve enough central circulation at moderate loss while allowing an
	-- almost empty circulation to become correspondingly ineffective.
	return hg.organism.GetBloodDeliveryFraction(blood, 1)
end

local function getBloodCompensationRate(blood)
	local cfg = hg.organism.config or {}
	local reserve = getBloodPerfusion(blood)
	local response = hg.organism.GetHemorrhageCompensationDrive and hg.organism.GetHemorrhageCompensationDrive(blood)
		or math.Clamp(1 - reserve, 0, 1)
	local maxRate = cfg.HEMORRHAGE_MAX_COMPENSATED_HR or 300
	-- Hemorrhage drives the electrical rate toward terminal tachycardia. The
	-- weak palpable pulse and falling pressure are downstream consequences of
	-- poor filling; they must not turn the blood-loss rhythm into an early
	-- bradycardic death path.
	return math.Clamp(70 + (maxRate - 70) * math.Clamp(response / 0.9, 0, 1), 0, maxRate)
end

local function getRateOutput(heartbeat)
	local rate = math.Clamp(tonumber(heartbeat) or 0, 0, terminalHeartRate)
	-- Cardiac output is fundamentally rate x stroke volume. Bradycardia can gain
	-- some stroke volume from extra filling time, but that compensation is capped;
	-- a 20-30 BPM escape rhythm cannot provide normal minute output merely because
	-- circulating volume is still adequate.
	local normalizedRate = rate / 70
	local slowRateDepth = math.Clamp((70 - rate) / 55, 0, 1)
	local fillingCompensation = Lerp(slowRateDepth, 1, 1.25)
	local fastFillingLoss = 1 - math.Clamp((rate - 150) / 150, 0, 0.72)
	return math.Clamp(normalizedRate * fillingCompensation * fastFillingLoss, 0, 1.35)
end

local function getPalpablePulseTarget(org, heartbeat, circulation, hemorrhageCompensation, effectivePalpitations)
	local cfg = hg.organism.config or {}
	local rate = math.Clamp(tonumber(heartbeat) or 0, 0, terminalHeartRate)
	if rate <= 0 or circulation <= 0 then return 0, 0 end

	-- Cardiac output above already contains blood volume, preload, temperature,
	-- contractility and the fast-rate filling penalty. Derive how much blood each
	-- electrical beat is effectively ejecting instead of multiplying those causes
	-- into the pulse a second time.
	local rateFactor = math.max(rate / 70, 0.1)
	local effectiveStrokeVolume = math.Clamp(circulation / rateFactor, 0, 1)

	-- Arrhythmias/palpitations produce a pulse deficit: some electrical complexes
	-- do not create enough mechanical ejection to be palpable. This is specifically
	-- a beat-capture term, separate from their smaller central-output penalty.
	local arrhythmia = math.Clamp(tonumber(org.arrhythmia) or 0, 0, 1)
	local rhythmCapture = math.Clamp(1
		- arrhythmia * (tonumber(cfg.PALPABLE_ARRHYTHMIA_PENALTY) or 0.60)
		- math.Clamp(effectivePalpitations or 0, 0, 1) * (tonumber(cfg.PALPABLE_PALPITATION_PENALTY) or 0.50), 0.08, 1)
	if org.fibrillation then rhythmCapture = rhythmCapture * 0.08 end
	if rate <= 55 and arrhythmia < 0.15 and (effectivePalpitations or 0) < 0.15 and circulation >= 0.45 then
		return rate, 1
	end

	-- Sympathetic compensation centralizes blood through vasoconstriction. It may
	-- maintain central MAP while making a radial/peripheral pulse much weaker.
	local peripheralVasoconstriction = math.Clamp(1
		- math.Clamp(hemorrhageCompensation or 0, 0, 1) * (tonumber(cfg.PALPABLE_VASOCONSTRICTION_PENALTY) or 0.35), 0.5, 1)
	local peripheralFlow = math.Clamp(circulation / 0.9, 0, 1) ^ 0.35

	local capture = math.Clamp(effectiveStrokeVolume * rhythmCapture * peripheralVasoconstriction * peripheralFlow, 0, 1)
	return rate * capture, capture
end

function hg.organism.UpdatePerfusion(owner, org, timeValue)
	if not org or not org.o2 then return end

	local o2Range = math.max(tonumber(org.o2.range) or 30, 1)
	local oxygenReserve = Clamp((tonumber(org.o2[1]) or 0) / o2Range, 0, 1)
	local circulation = Clamp(tonumber(org.cardiacOutput) or 0, 0, 1)
	local pulseReserve = Clamp((tonumber(org.pulse) or 0) / 70, 0, 1)
	-- A slow or weak palpable pulse means tissue is not receiving enough
	-- effective beats, even when stored oxygen and nominal cardiac output have
	-- not caught up yet. Blood volume reaches O2 through this circulation path.
	local effectiveCirculation = math.min(circulation, pulseReserve)
	local pressureReserve = Clamp((tonumber(org.bloodPressure) or 0) / 65, 0, 1)
	local cerebralPerfusion = math.min(effectiveCirculation * 1.15, pressureReserve)
	local neckPenalty = Clamp(tonumber(org.neckBrainOxygenPenalty) or 0, 0, 0.8)
	local brainTarget = math.max(math.min(oxygenReserve, cerebralPerfusion) - neckPenalty, 0)
	local bodyTarget = math.min(oxygenReserve, effectiveCirculation)

	org.perfusion = Approach(tonumber(org.perfusion) or 1, effectiveCirculation, timeValue * 0.9)
	org.cerebralPerfusion = Approach(tonumber(org.cerebralPerfusion) or 1, cerebralPerfusion, timeValue * 1.15)
	org.peripheralperfusion = Approach(tonumber(org.peripheralperfusion) or 1, effectiveCirculation, timeValue * 0.8)
	org.bodyoxygen = Approach(tonumber(org.bodyoxygen) or 1, bodyTarget, timeValue * (bodyTarget < (org.bodyoxygen or 1) and 1.0 or 0.35))
	org.brainoxygenTarget = brainTarget
	org.brainoxygen = Approach(tonumber(org.brainoxygen) or 1, brainTarget, timeValue * (brainTarget < (org.brainoxygen or 1) and 1.35 or 0.25))

	local severeHypoxia = Clamp((0.28 - org.brainoxygen) / 0.28, 0, 1)
	org.hypoxiaTime = severeHypoxia > 0 and (org.hypoxiaTime or 0) + timeValue or math.max((org.hypoxiaTime or 0) - timeValue * 2, 0)
	org.severeHypoxiaTime = org.brainoxygen < 0.16 and (org.severeHypoxiaTime or 0) + timeValue or math.max((org.severeHypoxiaTime or 0) - timeValue, 0)
	if org.brainoxygen < 0.28 then
		org.consciousness = math.min(org.consciousness or 1, 0.15 + org.brainoxygen / 0.28 * 0.55)
	end
	if org.brainoxygen < 0.16 then org.needotrub = true end
	if org.brainoxygen < 0.08 then
		org.brain = math.min((org.brain or 0) + timeValue * (0.08 - org.brainoxygen) * 0.12, 1)
	end
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
	-- Hemorrhage-related rhythm danger follows the same preload reserve as cardiac
	-- output. It stays near zero through compensated loss, then rises through the
	-- 3000-2000 mL danger band instead of switching on around normal volume.
	local lowBlood = getHemorrhageDanger(blood)
	local lowCirculation = math.Clamp(((org.hypotension or 0) - 0.5) / 0.5, 0, 1)
	local hypoxia = math.Clamp((12 - o2Value) / 12, 0, 1)
	local shock = math.Clamp(((org.shock or 0) - 20) / 40, 0, 1)
	local heartDamage = math.Clamp(org.heart or 0, 0, 1)
	local temperatureStress = math.max(
		math.Clamp((34 - (org.temperature or 36.7)) / 6, 0, 1),
		math.Clamp(((org.temperature or 36.7) - 39) / 3, 0, 1)
	)

	return math.max(lowBlood, lowCirculation, hypoxia, shock, heartDamage, temperatureStress)
end

local heatDamageTargets = {"brain", "heart", "liver", "stomach", "intestines"}
local coldDamageTargets = {"heart", "liver", "stomach", "intestines"}
local tachycardiaThoughts = {
	"Your heart rate is dangerously elevated.",
	"Tachycardia is straining your circulation.",
	"Your pulse is racing.",
	"Severe palpitations are affecting your circulation.",
	"Your heart is beating too fast."
}
local cardiacArrestThoughts = {
	"MY CHEST- IT HURTS...",
	"I'M FADING- EVERYTHING IS GOING DARK",
	"I'M DYING... I CAN'T FEEL MY PULSE",
	"gg boi im cooked"
}

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

local function stabilizeECGState(org, candidate, heartbeat)
	local current = org.ecgState
	if not current then
		org._ecgStateSince = CurTime()
		return candidate
	end
	if current == candidate then
		org._ecgStateSince = org._ecgStateSince or CurTime()
		return candidate
	end

	local immediate = candidate == "asystole" or candidate == "pea"
		or candidate == "ventricular_fibrillation"
	if immediate then
		org._ecgStateSince = CurTime()
		return candidate
	end

	if current == "normal_sinus" and candidate == "sinus_tachycardia" and heartbeat < 104 then return current end
	if current == "sinus_tachycardia" and candidate == "normal_sinus" and heartbeat > 96 then return current end
	if current == "normal_sinus" and candidate == "sinus_bradycardia" and heartbeat > 56 then return current end
	if current == "sinus_bradycardia" and candidate == "normal_sinus" and heartbeat < 64 then return current end
	-- Rate bands must never lag behind a clearly different live heartbeat. Keep
	-- hysteresis for borderline noise, but do not show a normal/100 BPM trace
	-- while the actual heart is already running at 180 BPM.
	local currentRateMismatch = (current == "normal_sinus" and heartbeat > 104)
		or (current == "sinus_tachycardia" and (heartbeat > 154 or heartbeat < 96))
		or (current == "compressed_tachycardia" and heartbeat < 145)
		or (current == "extreme_tachycardia" and heartbeat < 215)
		or (current == "terminal_tachycardia" and heartbeat < 245)
	if currentRateMismatch then
		org._ecgStateSince = CurTime()
		return candidate
	end

	local since = org._ecgStateSince or CurTime()
	if CurTime() - since < 1.25 then return current end
	org._ecgStateSince = CurTime()
	return candidate
end

function hg.organism.GetECGState(heartbeat, heartstop, org)
	heartbeat = math.Clamp(tonumber(heartbeat) or 0, 0, terminalHeartRate)
	org = org or {}
	if heartstop then return heartbeat < 1 and "asystole" or "pea" end
	if heartbeat < 1 then return "asystole" end
	if hg.organism.OrganSystemsEnabled and not hg.organism.OrganSystemsEnabled() then
		if heartbeat <= 100 then return "normal_sinus" end
		if heartbeat <= 150 then return "sinus_tachycardia" end
		if heartbeat <= 200 then return "compressed_tachycardia" end
		if heartbeat < 280 then return "extreme_tachycardia" end
		return "terminal_tachycardia"
	end

	local o2 = org.o2 and org.o2[1] or 30
	local hypoxia = math.Clamp((12 - o2) / 12, 0, 1)
	local cerebral = math.Clamp(math.max((org.brain or 0) * 0.8, org.brainHemorrhage or 0), 0, 1)
	local cardiac = math.Clamp(org.heart or 0, 0, 1)
	local cold = math.Clamp((34 - (org.temperature or 36.7)) / 7, 0, 1)
	local hemorrhageReserve = getBloodPerfusion(org.blood or 5000)
	local hemorrhagicDecompensation = math.Clamp((0.25 - hemorrhageReserve) / 0.25, 0, 1)
	local suppression = math.max(cerebral * 0.9, hypoxia, cardiac * 0.9, cold, hemorrhagicDecompensation)
	local output = math.Clamp(tonumber(org.cardiacOutput) or 1, 0, 1.5)
	local perfusion = math.Clamp(tonumber(org.perfusion) or output, 0, 1)
	local pulse = math.max(tonumber(org.pulse) or 0, 0)
	local arrhythmia = math.Clamp(tonumber(org.arrhythmia) or 0, 0, 1)
	local ischemia = math.max(math.Clamp(1 - (org.myocardialOxygen or 1), 0, 1), math.Clamp(org.ischemia or 0, 0, 1))
	-- Conduction failure is derived from myocardial injury, ischemia and electrical instability.
	local conductionFailure = math.Clamp(cardiac * 0.48 + ischemia * 0.42 + arrhythmia * 0.28, 0, 1)
	local candidate

	if org.terminalRhythm == "terminal_tachycardia" and heartbeat >= 220 then
		candidate = "terminal_tachycardia"
	elseif org.fibrillation or org.terminalRhythm == "ventricular_fibrillation" then
		candidate = "ventricular_fibrillation"
	elseif arrhythmia >= 0.72 and heartbeat >= 140 and (ischemia >= 0.35 or (org.heartStrain or 0) >= 0.3 or heartbeat >= 200) then
		candidate = "terminal_tachycardia"
	elseif pulse <= 5 and output <= 0.08 and perfusion <= 0.08 then
		candidate = "pea"
	elseif conductionFailure >= 0.82 and heartbeat > 25 and heartbeat <= 70 then
		candidate = "av_block_complete"
	elseif conductionFailure >= 0.58 and heartbeat > 35 and heartbeat <= 100 then
		candidate = "av_block_partial"
	elseif org.unstableRhythm == "atrial_fibrillation" then
		candidate = "atrial_fibrillation"
	elseif org.unstableRhythm == "ventricular_ectopy" then
		candidate = "ventricular_ectopy"
	elseif arrhythmia >= 0.45 and heartbeat > 50 and heartbeat <= 220 and output > 0.12 and perfusion > 0.12 then
		candidate = "atrial_fibrillation"
	elseif arrhythmia >= 0.1 and heartbeat > 35 and heartbeat <= 220 and output > 0.12 and perfusion > 0.12 then
		candidate = "ventricular_ectopy"
	elseif cold >= 0.18 and heartbeat > 40 and cold >= math.max(cerebral * 0.9, hypoxia, cardiac * 0.9) then
		candidate = "hypothermia_bradycardia"
	elseif heartbeat <= 40 and (hypoxia >= 0.65 or cardiac >= 0.65 or cold >= 0.75 or hemorrhagicDecompensation >= 0.75) then
		candidate = "ventricular_escape"
	elseif heartbeat <= 60 and suppression >= 0.52 then
		candidate = "junctional_escape"
	elseif heartbeat < 50 and suppression >= 0.32 then
		candidate = "sinus_pause"
	elseif cerebral >= 0.28 and heartbeat < 60 then
		-- Neurologic injury may alter autonomic rate but is not its own ECG rhythm.
		candidate = "sinus_bradycardia"
	elseif cerebral >= 0.45 and arrhythmia >= 0.28 then
		candidate = "ventricular_ectopy"
	elseif heartbeat < 60 then
		candidate = "sinus_bradycardia"
	elseif heartbeat <= 100 then
		candidate = "normal_sinus"
	elseif heartbeat <= 150 then
		candidate = "sinus_tachycardia"
	elseif heartbeat <= 220 and arrhythmia >= 0.35 and output > 0.12 and perfusion > 0.12 then
		candidate = "compressed_tachycardia"
	elseif heartbeat < 250 and arrhythmia < 0.35 then
		candidate = "sinus_tachycardia"
	elseif heartbeat < 280 then
		candidate = "extreme_tachycardia"
	else
		candidate = "terminal_tachycardia"
	end

	return stabilizeECGState(org, candidate, heartbeat)
end



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
	if hg.organism.OrganSystemsEnabled and not hg.organism.OrganSystemsEnabled() then return false end
	-- Do not restart the VF clock every Think while the same fibrillation episode
	-- is already active; progression to arrest depends on elapsed VF duration.
	if org.fibrillation then return true end
	org.fibrillation = true
	-- Fibrillation replaces an organized palpitation rhythm; keeping both
	-- active makes circulation, ECG, and status displays disagree.
	org.palpitations = 0
	org.palpitationTreatmentUntil = 0
	org.arrhythmia = math.max(org.arrhythmia or 0, 0.8)
	org.fibrillationStart = CurTime()
end

local function maintainSimplifiedCirculation(org)
	-- hg_huyorgans 0 keeps one intentionally small cardiovascular model. Organ
	-- hits may still bleed and hurt, but the protected heart continues pumping.
	org.heartstop = false
	if hg.organism.ClearCardiacArrestMechanicalDecay then hg.organism.ClearCardiacArrestMechanicalDecay(org) end
	org.heartbeat = 70
	org.pulse = 70
	org.ecgState = "normal_sinus"
	org.bloodPressure = 90
	org.systolic = 120
	org.diastolic = 80
	org.cardiacOutput = 1
	org.strokeVolume = 1
	org.compensationPulseMultiplier = 1
	org.compensationHeartRateTarget = 70
	org.mechanicalPulseCapture = 1
	org.pulseDeficit = 0
	org.cardiacArrestStart = nil
	org.cardiacArrestO2Start = nil
	org.terminalRhythm = nil
	org.unstableRhythm = nil
	org.fibrillation = false
	org.fibrillationStart = 0
	org.arrhythmia = 0
	org.arrhythmiaComplication = 0
	org.palpitations = 0
	org.myocardialOxygen = 1
	org.heartStrain = 0
	org.hypotension = 0
	org.hypotensionExposure = 0
	org.prolongedHypotension = false
	org.hypertension = 0
	org.hemorrhagicCollapseExposure = 0
	org.criticalHemorrhageTime = 0
	hg.organism.UpdatePerfusion(org.owner, org, org.timeValue or 0)
end

local function restoreHeartAfterResuscitation(org, now, resusBloodK)
	org.heartstop = false
	if hg.organism.ClearCardiacArrestMechanicalDecay then hg.organism.ClearCardiacArrestMechanicalDecay(org) end
	org.fibrillation = false
	org.terminalRhythm = nil
	org.unstableRhythm = nil
	org.arrhythmia = math.max((org.arrhythmia or 0) - 0.45, 0)
	org.heart = math.max((org.heart or 0) - 0.08, 0)
	org.heartStrain = math.max((org.heartStrain or 0) - 0.2, 0)
	org.ischemia = math.max((org.ischemia or 0) - 0.15, 0)
	org.heartbeat = Clamp(org.heartbeat or 70, 55, 100)
	org.pulse = max(org.pulse or 0, 35 * resusBloodK)
	org.bloodPressure = max(org.bloodPressure or 0, 40 * resusBloodK)
	org.cardiacOutput = max(org.cardiacOutput or 0, 0.4 * resusBloodK)
	local rateFactor = math.max((org.heartbeat or 0) / 70, 0.1)
	org.strokeVolume = Clamp((org.cardiacOutput or 0) / rateFactor, 0, 1.5)
	org.myocardialOxygen = max(org.myocardialOxygen or 0, 0.5 * resusBloodK)
	org.hypotension = math.min(org.hypotension or 1, 1 - 0.45 * resusBloodK)
	org.cardiacRestartUntil = now + 6
	if hg.organism.TryRestoreBreathingWithResuscitation then
		hg.organism.TryRestoreBreathingWithResuscitation(org, 1)
	end
	if hg.organism.RestoreSupportedOxygen then
		hg.organism.RestoreSupportedOxygen(org, 0.2, {
			artificialSupport = true,
			oxygen = 10, oxygenTarget = 18, bodyoxygen = 0.45, bodyoxygenTarget = 0.7,
			brainoxygen = 0.4, brainoxygenTarget = 0.65, perfusion = 0.4,
			perfusionTarget = 0.65, myocardialOxygen = 0.5, myocardialOxygenTarget = 0.75,
			hypoxiaTime = 5, severeHypoxiaTime = 1, systemicIschemiaTime = 6
		})
	end

	return true
end

function hg.organism.ApplyAEDResuscitation(org)
	if not org or not org.alive or org.deathStateKilled then return false end
	if (org.brain or 0) >= 0.85 or (org.heart or 0) >= 1 then return false end

	local resusBloodK = getBloodPerfusion(org.blood or 5000)
	if resusBloodK <= 0.03 then return false end
	return restoreHeartAfterResuscitation(org, CurTime(), resusBloodK)
end

function hg.organism.TryRestartHeartWithResuscitation(org, cprDuration)
	if not org or not org.alive or not org.heartstop or org.deathStateKilled then return false end
	if (org.brain or 0) >= 0.85 or (org.heart or 0) >= 1 then return false end

	local now = CurTime()
	local hasAED = (org.aedResuscitationUntil or 0) > now
	local hasEpinephrine = (org.epinephrineResuscitationUntil or 0) > now
	local hasCPR = (org.cprResuscitationUntil or 0) > now
	local sustainedCPR = hasCPR and (tonumber(cprDuration) or 0) >= 8
	if not ((hasAED and (hasEpinephrine or hasCPR)) or (hasEpinephrine and hasCPR) or sustainedCPR) then return false end

	if (org.resuscitationAttemptUntil or 0) > now then return false end
	org.resuscitationAttemptUntil = now + 6

	local chance = hasAED and hasCPR and hasEpinephrine and 100
		or hasAED and hasCPR and 96
		or hasAED and hasEpinephrine and 92
		or hasCPR and hasEpinephrine and 84
		or 48
	chance = chance * Clamp(1 - (org.heart or 0) * 0.2, 0.72, 1)
	if org.o2 and (org.o2[1] or 0) < 3 then chance = chance * 0.9 end
	local resusBloodK = getBloodPerfusion(org.blood or 5000)
	if resusBloodK <= 0.03 then return false end
	chance = chance * (0.6 + resusBloodK * 0.4)
	if math.random(100) > chance then return false end

	return restoreHeartAfterResuscitation(org, now, resusBloodK)
end

module[1] = function(org)
	org.heart = 0
	org.heartstop = false
	org.pulse = 70
	org.heartbeat = 70
	org.bloodPressure = 90
	org.systolic = 120
	org.diastolic = 80
	org.cardiacOutput = 1
	org.strokeVolume = 1
	org.ecgState = "normal_sinus"
	org.compensationPulseMultiplier = 1
	org.compensationHeartRateTarget = 75
	org.mechanicalPulseCapture = 1
	org.pulseDeficit = 0
	org.palpitations = 0
	org.palpitationTreatmentUntil = 0
	org.lastHeartbeatForPalpitations = 70
	org.lastPulseForPalpitations = 70
	org.internalBleedRhythmRisk = 0
	org.traumaRhythmRisk = 0
	org.cardiacArrestStart = nil
	org.cardiacArrestO2Start = nil
	org.arrhythmia = 0
	org.arrhythmiaComplication = 0
	org.fibrillation = false
	org.fibrillationStart = 0
	org.myocardialOxygen = 1
	org.perfusion = 1
	org.peripheralperfusion = 1
	org.cerebralPerfusion = 1
	org.bodyoxygen = 1
	org.brainoxygen = 1
	org.brainoxygenTarget = 1
	org.hypoxiaTime = 0
	org.severeHypoxiaTime = 0
	org.heartStrain = 0
	org.hypertension = 0
	org.hypotension = 0
	org.hypotensionExposure = 0
	org.prolongedHypotension = false
	org.highSpeedPressureShock = 0
	org.lastHighSpeedVelocity = nil
	org.lastHighSpeedVelocityTime = nil
	org.nextArrhythmiaRoll = 0
	org.lastCardiacPain = 0
	org.hemorrhagicCollapseExposure = 0
	org.criticalHemorrhageTime = 0
	org.vitalHealthStress = 0
	org.vitalHealthCeiling = nil
	org.vitalHealthDamageCarry = 0

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
	org.ischemia = tonumber(org.ischemia) or 0
	local organSystemsEnabled = hg.organism.OrganSystemsEnabled and hg.organism.OrganSystemsEnabled() or true

	local o2Value = org.o2 and org.o2[1] or 30
	local previousHeartbeat = tonumber(org.lastHeartbeatForPalpitations) or tonumber(org.heartbeat) or 70
	local previousPulse = tonumber(org.lastPulseForPalpitations) or tonumber(org.pulse) or 70
	if not org.heartstop and not org.fibrillation and (org.arrhythmia or 0) < 0.25 and (org.myocardialOxygen or 1) > 0.55 then
		org.heartStrain = Approach(org.heartStrain or 0, 0, timeValue / 45)
	end

	local heart = getHeartEfficiency(org)
	local brain = math.Clamp(1 - org.brain * 1.5,0,1)
	local o2 = org.o2
	local o2 = halfValue2(o2[1], o2.range, o2.k)

	if org.isPly and not org.otrub and (heart == 0) then org.owner:Notify("My torso hurts a lot...",true,"heart",6) end

	local stamina = org.stamina
	
	if not org.alive then
		if hg.organism and hg.organism.BeginPostMortemDecay then
			hg.organism.BeginPostMortemDecay(org)
		end
		org.heartstop = true
		return
	end

	if not organSystemsEnabled then
		maintainSimplifiedCirculation(org)
		return
	end

	if organSystemsEnabled then applyTemperatureTrauma(org) end
	if not org.heartstop and org.cardiacArrestMechanicalInitial then
		hg.organism.ClearCardiacArrestMechanicalDecay(org)
	end

	local arrestMechanicalFactor, arrestMechanicalInitial = 1, nil
	if hg.organism and hg.organism.GetCardiacArrestMechanicalFactor then
		arrestMechanicalFactor, arrestMechanicalInitial = hg.organism.GetCardiacArrestMechanicalFactor(org)
	end

	local pulse = org.heartstop
		and math.max((arrestMechanicalInitial and arrestMechanicalInitial.pulse or 0) * arrestMechanicalFactor, 0)
		or 70-- + 120 * ((stamina.max or 180) - stamina[1]) / (stamina.max or 180) * (org.lungsfunction and 1 or 0)
	--pulse = pulse + math.min(org.adrenaline, 2) * 40 + (!org.otrub and math.max(org.fear * 50, 0) or 0)
	pulse = org.alive and pulse or 0
	pulse = math.Clamp(pulse, 0, 200)
	
	org.pulse = math.Approach(org.pulse, pulse, pulse > org.pulse and timeValue * 2 or timeValue * 2)
	
	local bloodNow = org.blood or 5000
	local preloadReserve = getBloodPerfusion(bloodNow)
	-- Blood loss alone should not destabilize the rhythm while the patient is
	-- still in the compensated range. Complications can still lower circulation
	-- and enter the electrical-risk path independently.
	local hemorrhageDanger = getHemorrhageDanger(bloodNow)
	local hemorrhageRhythmStress = hemorrhageDanger
	org.hemorrhageRhythmStress = hemorrhageRhythmStress
	local hemorrhageCompensation = math.Clamp(org.hemorrhageCompensation or 0, 0, 1)
	local hypovolemicShock = math.Clamp(org.hypovolemicShock or 0, 0, 1)
	local palpitations = math.Clamp(org.palpitations or 0, 0, 1)
	local palpitationThreat = getPalpitationThreat(org, bloodNow, o2Value)
	local effectivePalpitations = palpitations * Lerp(palpitationThreat, 0.2, 1)
	-- Compensation raises vascular tone below; it should not simultaneously
	-- suppress the pump. Only true decompensation and rhythm instability reduce it.
	local compensationPulseMultiplier = math.Clamp(1 - hypovolemicShock * 0.18 - effectivePalpitations * 0.3, 0.35, 1)
	org.compensationPulseMultiplier = compensationPulseMultiplier
	local bloodPerfusionK = preloadReserve
	local k = heart * o2 * math.Clamp(bloodPerfusionK, 0, 1) * brain
	if not org.heartstop then
		pulse = pulse * k
		pulse = pulse * compensationPulseMultiplier
		pulse = pulse * (math.Clamp(math.Remap(org.temperature, 28, 36.7, 0.5, 1), 0.5, 1))
	end

	-- Loss of circulation is progressive while the organism is still alive. This
	-- leaves a short treatment window instead of turning a heart stop into an
	-- immediate zero-pulse state on the next organism tick.
	local dropRate = (heart == 0 or org.heartstop) and timeValue * 6 or timeValue * 5
	org.pulse = math.Approach(org.pulse, pulse, dropRate)
	local bloodVolume = getBloodVolume(org)
	-- Stored O2 may outlast respiration briefly, but it cannot continue to
	-- sustain the myocardium once the lungs have stopped delivering oxygen.
	local oxygenation = Clamp(o2 * (org.oxygenIntakeAvailable == false and 0 or 1), 0, 1)
	local highSpeedPressureShock = updateHighSpeedPressureShock(owner, org, timeValue)
	local vascularTone = Clamp(1 + hemorrhageCompensation * 0.24 + min(org.adrenaline, 3) * 0.12 + max(org.fear, 0) * 0.08 + Clamp(org.shock, 0, 45) / 360, 0.65, 1.55)
	local accelerationPressureMul = 1 - highSpeedPressureShock * 0.8
	local dehydrationPressureMul = 1 - math.Clamp(org.dehydrationCirculationPenalty or 0, 0, 1) * 0.22
	-- Pericardial blood restricts filling before it directly damages the heart.
	-- Its effect compounds with blood loss, causing obstructive shock and low
	-- cardiac output without treating tamponade as an immediate flatline.
	local tamponade = Clamp(org.cardiacTamponade or 0, 0, 1)
	local tamponadePreload = Clamp(1 - tamponade * 0.82, 0.18, 1)
	local internalBleedComplication = Clamp(org.internalBleedComplication or 0, 0, 1)
	local internalBleedPressureMul = Clamp(1 - internalBleedComplication * 0.35, 0.65, 1)
	local arrhythmia = Clamp(tonumber(org.arrhythmia) or 0, 0, 1)
	local rhythmInstability = arrhythmia
	if org.unstableRhythm then rhythmInstability = math.max(rhythmInstability, 0.35) end
	if org.fibrillation then rhythmInstability = 1 end
	local rateOutput = getRateOutput(org.heartstop and 0 or (org.heartbeat or 70))
	local circulationBase = bloodVolume * heart * compensationPulseMultiplier * rateOutput * vascularTone * accelerationPressureMul * dehydrationPressureMul * tamponadePreload * internalBleedPressureMul * Clamp(Remap(org.temperature, 28, 36.7, 0.55, 1), 0.45, 1.1)
	local rhythmMul = org.fibrillation and 0.18 or Clamp(1 - rhythmInstability * 0.42, 0.32, 1)
	local dihSupport = (org.dihSupportUntil or 0) > CurTime()
	local defibGrace = (org.defibDeathGrace or 0) > CurTime() or (org.defibSupportUntil or 0) > CurTime()
	local cprSupport = (org.cprSupportUntil or 0) > CurTime()
	local cprSupportPulse = math.Clamp(tonumber(org.cprSupportPulse) or 40, 0, 70)
	local arrestCirculation = (dihSupport and (70 / 92) or (defibGrace and 0.49 or (cprSupport and cprSupportPulse / 92 or 0))) * bloodVolume
	local residualCirculation = 0
	if org.heartstop and arrestMechanicalInitial then
		local initialPulseFlow = (arrestMechanicalInitial.pulse or 0) / 92
		local initialPressureFlow = (arrestMechanicalInitial.bloodPressure or 0) / 92
		local initialOutput = arrestMechanicalInitial.cardiacOutput or 0
		residualCirculation = Clamp(max(initialPulseFlow, initialPressureFlow, initialOutput) * arrestMechanicalFactor, 0, 1.5)
	end
	local circulation = org.alive and (org.heartstop and max(arrestCirculation, residualCirculation) or circulationBase * rhythmMul) or 0
	local palpablePulseTarget, mechanicalPulseCapture
	if org.heartstop then
		-- During arrest, residual/support circulation owns the fading mechanical pulse.
		palpablePulseTarget = circulation * 92
		mechanicalPulseCapture = (org.heartbeat or 0) > 0 and math.Clamp(palpablePulseTarget / math.max(org.heartbeat, 1), 0, 1) or 0
	else
		palpablePulseTarget, mechanicalPulseCapture = getPalpablePulseTarget(
			org, org.heartbeat or 0, circulation, hemorrhageCompensation, effectivePalpitations
		)
	end
	org.mechanicalPulseCapture = mechanicalPulseCapture
	org.pulseDeficit = math.max((org.heartbeat or 0) - palpablePulseTarget, 0)
	org.pulse = Approach(org.pulse, palpablePulseTarget, heart == 0 and timeValue * 10 or timeValue * 8)
	-- Keep a real mean arterial pressure alongside the legacy palpable-pulse
	-- value. Judge's pressure readout is useful to medicine/UI code, while the
	-- current circulation model remains the single owner of the actual target.
	local mechanicalPulseReserve = Clamp(palpablePulseTarget / 70, 0, 1)
	local pressureCirculation = circulation * (0.35 + mechanicalPulseReserve * 0.65) * Clamp(1 - rhythmInstability * 0.24, 0.70, 1)
	local pulsePressureSupport = Clamp((palpablePulseTarget - 10) / 50, 0, 1)
	local pressureTarget = Clamp(pressureCirculation * 92 * Lerp(pulsePressureSupport, 0.3, 1), 0, 180)
	local pressureNow = tonumber(org.bloodPressure) or pressureTarget
	local pressureFallRate = org.heartstop and not (dihSupport or defibGrace or cprSupport) and 22 or 12
	org.bloodPressure = Approach(pressureNow, pressureTarget, timeValue * (pressureTarget > pressureNow and 12 or pressureFallRate))
	local pressurePulseReserve = Clamp(org.bloodPressure / 90, 0, 1)
	local sympatheticSupport = Clamp(math.max((org.adrenaline or 0) - 1.5, 0) / 1.5 + (org.hypertension or 0) * 0.6, 0, 1)
	local pressurePulseCap = math.min(70 * pressurePulseReserve + 130 * sympatheticSupport, org.heartbeat or 0)
	if not org.heartstop then
		palpablePulseTarget = math.min(palpablePulseTarget, pressurePulseCap)
		org.pulse = Approach(org.pulse, palpablePulseTarget, timeValue * 8)
		org.pulseDeficit = math.max((org.heartbeat or 0) - palpablePulseTarget, 0)
	end
	-- Treat bloodPressure as mean arterial pressure and derive a pulse pressure
	-- which collapses with circulation. At healthy values this settles near 120/80.
	local pulsePressure = Clamp(40 * Clamp(org.bloodPressure / 92, 0, 1.5) + ((org.heartbeat or 70) - 70) * 0.1, 0, 80)
	org.systolic = math.Round(Clamp(org.bloodPressure + pulsePressure * 2 / 3, 0, 240))
	org.diastolic = math.Round(Clamp(org.bloodPressure - pulsePressure / 3, 0, 160))
	local supportCardiacOutput = (dihSupport and 1 or (defibGrace and 0.35 or (cprSupport and cprSupportPulse / 110 or 0))) * bloodVolume
	if org.heartstop then
		local residualCardiacOutput = (arrestMechanicalInitial and arrestMechanicalInitial.cardiacOutput or 0) * arrestMechanicalFactor
		org.cardiacOutput = Clamp(max(supportCardiacOutput, residualCardiacOutput), 0, 1.5)
	else
		org.cardiacOutput = Clamp(circulation, 0, 1.5)
	end
	-- Oxygenation, preload reserve, and circulation are linked but should not be
	-- multiplied repeatedly. The weakest link caps myocardial delivery once.
	-- The weakest link should cap delivery once without compounding blood loss.
	local circulationDelivery = Clamp(circulation * (92 / 70), 0, 1.2)
	local myocardialTarget = hg.organism.GetLimitingReserve(oxygenation, circulationDelivery)
	if org.heartstop and defibGrace then myocardialTarget = math.max(myocardialTarget, 0.25) end
	org.myocardialOxygen = Approach(org.myocardialOxygen or 1, myocardialTarget, timeValue / 8)
	local pressureHypotensionTarget = Clamp(Remap(pressureCirculation, 0.98, 0.22, 0, 1), 0, 1)
	local rhythmHypotensionTarget = rhythmInstability * (org.fibrillation and 0.85 or 0.48)
	local hypotensionTarget = math.max(pressureHypotensionTarget, rhythmHypotensionTarget)
	local hypotensionRate = highSpeedPressureShock > 0.25 and timeValue / 2.5 or timeValue / 8
	org.hypotension = Approach(org.hypotension or 0, hypotensionTarget, hypotensionRate)
	local arrhythmiaComplicationTarget = math.Clamp(rhythmInstability * (0.45 + (1 - pressureCirculation) * 0.55), 0, 1)
	local arrhythmiaComplication = Approach(
		org.arrhythmiaComplication or 0,
		arrhythmiaComplicationTarget,
		arrhythmiaComplicationTarget > (org.arrhythmiaComplication or 0) and timeValue / arrhythmiaComplicationTime or timeValue / 120
	)
	org.arrhythmiaComplication = arrhythmiaComplication
	if org.hypotension > 0.92 and not org.heartstop then
		org.hypotensionExposure = math.min((org.hypotensionExposure or 0) + timeValue, 120)
	else
		org.hypotensionExposure = math.Approach(org.hypotensionExposure or 0, 0, timeValue * 1.5)
	end
	org.prolongedHypotension = (org.hypotensionExposure or 0) >= hypotensionComplicationTime
	org.hypertension = Approach(org.hypertension or 0, Clamp(Remap(circulation, 1.25, 1.68, 0, 1), 0, 1), timeValue / 20)
	hg.organism.UpdatePerfusion(owner, org, timeValue)
	-- Normalized stroke volume separates a fast electrical rate from how much
	-- blood each effective beat is actually moving.
	local rateFactor = math.max((org.heartbeat or 0) / 70, 0.1)
	org.strokeVolume = Clamp((org.cardiacOutput or 0) / rateFactor, 0, 1.5)

	-- Epinephrine supports a functioning respiratory/circulatory system; it
	-- must not manufacture cardiac or oxygen recovery after breathing has failed.
	local epinephrineStabilizing = (org.epinephrineStabilizationUntil or 0) > CurTime()
		and org.oxygenIntakeAvailable == true and not org.heartstop
	if epinephrineStabilizing then
		local epiVolumeSupport = math.Clamp(bloodVolume, 0, 1)
		org.cardiacOutput = math.max(org.cardiacOutput or 0, 0.55 * epiVolumeSupport)
		org.strokeVolume = math.max(org.strokeVolume or 0, 0.55 * epiVolumeSupport)
		org.myocardialOxygen = math.max(org.myocardialOxygen or 0, 0.7 * epiVolumeSupport)
		org.hypotension = math.min(org.hypotension or 1, 1 - 0.55 * epiVolumeSupport)
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
	-- As preload fails, the volume-response curve progressively owns the rate
	-- target. At normal volume it does not suppress unrelated tachycardia.
	local lowVolumeInfluence = 1 - preloadReserve
	if bloodCompensationRate < compensationRate then
		compensationRate = Lerp(lowVolumeInfluence, compensationRate, bloodCompensationRate)
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
	-- node and conduction system progressively lose responsiveness. Extremely low
	-- preload can also remove the prior tachycardia without directly stopping it.
	local coldSuppression = math.Clamp((34 - (org.temperature or 36.7)) / 7, 0, 1)
	local hemorrhagicDecompensation = math.Clamp((0.25 - preloadReserve) / 0.25, 0, 1)
	local zerlkersSuppression = math.Clamp(org.zerlkersOverdose or 0, 0, 1)
	local drugBradycardia = math.Clamp(((org.drugRespiratoryDepression or 0) - 0.12) / 0.88, 0, 1)
	local cervicalSuppression = org.cervicalParalysis and 0.58 or 0
	-- Low blood volume produces tachycardia until preload becomes extremely poor;
	-- it is not a bradycardia source before that point.
	local bradycardiaSeverity = math.max(cerebralSuppression, hypoxiaSuppression, cardiacSuppression * 0.9, coldSuppression, zerlkersSuppression, drugBradycardia * 0.9, cervicalSuppression)
	org.bradycardiaSeverity = bradycardiaSeverity
	org.drugBradycardia = drugBradycardia
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
	local preloadRateCeiling = bloodCompensationRate + 35
	if preloadRateCeiling < maxCompensatedRate then
		maxCompensatedRate = Lerp(lowVolumeInfluence, maxCompensatedRate, preloadRateCeiling)
	end
	if heart < 0.35 or brain < 0.35 then
		maxCompensatedRate = math.min(maxCompensatedRate, 85)
	end
	if org.heartstop then
		maxCompensatedRate = 0
	else
		local minPumpRate = perfusionPulse < 60 and 60 + (60 - perfusionPulse) * 0.4 or 45
		if bradyTarget and bloodCompensationRate < terminalHeartRate - 20 then minPumpRate = math.min(minPumpRate, bradyTarget) end
		heartbeat = math.max(heartbeat, minPumpRate)
	end

	-- Hard physiological ceiling. Sustained rates above ~250 BPM are ventricular
	-- tachycardia/fibrillation; above ~300 the heart cannot fill and arrests.
	heartbeat = math.Clamp(heartbeat, 0, maxCompensatedRate)

	-- The cardiovascular response accelerates with blood loss. The old fixed
	-- 2.4 BPM/s rise lagged so far behind active bleeding that the target curve
	-- was never reached before pressure collapse.
	local normalBloodVolume = (hg.organism.config and hg.organism.config.NORMAL_BLOOD_VOLUME_ML) or 5000
	local compensationResponse = 1 - math.Clamp(bloodNow / normalBloodVolume, 0, 1)
	local riseRate = Lerp(compensationResponse, 5, 35)
	org.heartbeat = math.Approach(org.heartbeat, heartbeat, heartbeat > org.heartbeat and timeValue * riseRate or timeValue * 4.5)
	org.heartbeat = math.Clamp(org.heartbeat, 0, terminalHeartRate)

	-- Palpitations represent accumulated myocardial strain, rather than a
	-- momentary high BPM. Even moderate tachycardia eventually matters, while
	-- extreme rates build the condition rapidly; it then clears only gradually
	-- once the rhythm settles.
	local tachycardiaK = math.Clamp((org.heartbeat - 120) / 120, 0, 1)
	local palpitationGain = (tachycardiaK > 0 and 0.002 or 0) + tachycardiaK * 0.021 + hemorrhageRhythmStress * 0.006
	local correctingPalpitations = (org.palpitationTreatmentUntil or 0) > CurTime()
	local heartbeatSettling = (org.heartbeat or 0) <= previousHeartbeat + 0.5
	local pulseSettling = (org.pulse or 0) <= previousPulse + 0.5
	local rhythmSettling = heartbeatSettling and pulseSettling
	if org.fibrillation then
		org.palpitations = 0
	elseif correctingPalpitations then
		org.palpitations = math.max(palpitations - timeValue / 4, 0)
	elseif rhythmSettling then
		local slowing = math.Clamp((previousHeartbeat - (org.heartbeat or 0) + previousPulse - (org.pulse or 0)) / 80, 0, 1)
		org.palpitations = math.max(palpitations - timeValue * (0.0075 + slowing * 0.025), 0)
	elseif palpitationGain > 0 and not org.heartstop then
		org.palpitations = math.Clamp(palpitations + timeValue * palpitationGain, 0, 1)
	else
		org.palpitations = math.max(palpitations - timeValue / 90, 0)
	end
	palpitations = org.palpitations
	palpitationThreat = getPalpitationThreat(org, bloodNow, o2Value)
	effectivePalpitations = palpitations * Lerp(palpitationThreat, 0.2, 1)
	-- Severe hemorrhage decompensates from the circulation it produces. The
	-- weaker of preload reserve and actual pump output owns the collapse curve,
	-- so volume is not counted again after cardiac output has already fallen.
	local cfg = hg.organism.config or {}
	local circulatoryReserve = math.Clamp(circulation, 0, 1)
	local hemorrhageO2Transport = circulatoryReserve
	local electricalFlowFailure = math.Clamp((0.62 - circulatoryReserve) / 0.62, 0, 1)
	local electricalO2Failure = math.Clamp((0.58 - hemorrhageO2Transport) / 0.58, 0, 1)
	local myocardialFailure = math.Clamp((0.45 - (org.myocardialOxygen or 1)) / 0.45, 0, 1)
	local bloodOnlyElectricalFailure = math.max(electricalO2Failure, myocardialFailure) * hemorrhageDanger
	local hemorrhageElectricalInstability = math.max(electricalFlowFailure, bloodOnlyElectricalFailure)
	org.hemorrhageElectricalInstability = hemorrhageElectricalInstability
	local criticalReserve = cfg.CRITICAL_CIRCULATION_RESERVE or 0.31
	local criticalRange = math.max(cfg.CRITICAL_CIRCULATION_RANGE or 0.10, 0.01)
	local criticalHemorrhageDepth = math.Clamp((criticalReserve - circulatoryReserve) / criticalRange, 0, 1)
	local terminalReserve = math.Clamp(cfg.TERMINAL_CIRCULATION_RESERVE or 0.035, 0, 0.25)
	local terminalOutput = math.Clamp(cfg.TERMINAL_CARDIAC_OUTPUT or 0.04, 0, 0.25)
	local terminalCirculatoryFailure = circulatoryReserve <= terminalReserve
		and math.Clamp(circulation, 0, 1) <= terminalOutput
		and not (dihSupport or defibGrace or cprSupport)
	org.terminalCirculatoryFailure = terminalCirculatoryFailure
	org.hemorrhagicCollapseExposure = math.Approach(
		org.hemorrhagicCollapseExposure or 0,
		criticalHemorrhageDepth,
		timeValue / (criticalHemorrhageDepth > (org.hemorrhagicCollapseExposure or 0) and 8 or 12)
	)

	-- Sustained critical circulation accumulates a decompensation dose. Near the
	-- edge there is a treatment window; progressively worse flow accelerates it.
	if criticalHemorrhageDepth > 0 then
		if not org.heartstop then
			local exposureRate = 0.35 + criticalHemorrhageDepth ^ 2 * 1.65
			org.criticalHemorrhageTime = math.min((org.criticalHemorrhageTime or 0) + timeValue * exposureRate, 30)
		end
	else
		-- Only recovery/transfusion out of the critical volume band clears the dose.
		org.criticalHemorrhageTime = math.Approach(org.criticalHemorrhageTime or 0, 0, timeValue * 1.5)
	end

	-- Blood loss raises the compensation target continuously, but volume does not
	-- flip the heart into an arrest state at an arbitrary threshold.
	local restartCirculationActive = (org.cardiacRestartUntil or 0) > CurTime()

	-- Mild hypothermia produces a slow but organized sinus rhythm. Below 32 C,
	-- conduction becomes electrically unstable; atrial fibrillation and ectopy
	-- can appear before deep hypothermia makes ventricular fibrillation likely.
	-- Keep VF as a no-output electrical arrest rather than a fast effective pulse.
	local hypothermicArrhythmia = organSystemsEnabled and (org.temperature or 36.7) <= 32
	local hypothermiaInstability = math.Clamp((32 - (org.temperature or 36.7)) / 4, 0, 1)
	if not hypothermicArrhythmia then
		org.unstableRhythm = nil
		if org.terminalRhythm ~= "terminal_tachycardia" then org.terminalRhythm = nil end
	elseif not org.heartstop and (org.nextColdRhythmRoll or 0) <= CurTime() then
		local roll = math.Rand(0, 1)
		-- Isolated hypothermia deteriorates less abruptly than hemorrhagic
		-- collapse. Let mild/severe cold show ectopy or AF first; VF becomes a
		-- real but still uncommon event below 30 C.
		org.nextColdRhythmRoll = CurTime() + 6
		local deepCold = math.Clamp((30 - (org.temperature or 36.7)) / 2, 0, 1)
		if roll < deepCold * 0.08 then
			-- Deep cold may destabilize into VF, but temperature itself does not
			-- directly flip the heartstop flag. VF and/or the resulting failure of
			-- cardiac output are what progress the organism into arrest.
			hg.organism.StartFibrillation(org)
			org.terminalRhythm = "ventricular_fibrillation"
		elseif roll < 0.03 + hypothermiaInstability * 0.16 then
			org.unstableRhythm = "atrial_fibrillation"
		elseif roll < 0.15 + hypothermiaInstability * 0.24 then
			org.unstableRhythm = "ventricular_ectopy"
		else
			org.unstableRhythm = nil
		end
	end

	-- Track sustained ventricular tachycardia for the probabilistic arrest check below.
	if org.heartbeat > 250 and k < 0.65 then
		org._tachycardiaSince = org._tachycardiaSince or CurTime()
	else
		org._tachycardiaSince = nil
	end

	-- Probabilistic heartstop comes from an unstable rhythm or sustained
	-- tachycardia. Hemorrhage reaches this path through the heartbeat it drives.
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
	if bradyTarget and not org.fibrillation then heartbeat = math.min(heartbeat, bradyTarget) end

	org.heartbeat = math.Approach(org.heartbeat, heartbeat, heartbeat > org.heartbeat and timeValue * 5 or timeValue * 3)
	
	local ischemia = Clamp(1 - (org.myocardialOxygen or 1), 0, 1)
	local internalBleedPeak = math.max(tonumber(org.internalBleedPeak) or 0, tonumber(org.internalBleed) or 0, 0)
	local internalBleedRhythmRisk = Clamp(internalBleedComplication * math.Clamp(internalBleedPeak / 6, 0, 1), 0, 1)
	local chestRhythmRisk = Clamp(((org.chest or 0) - 0.45) / 0.55, 0, 1)
	local cardiacTraumaRhythmRisk = math.max(Clamp(((org.heart or 0) - 0.3) / 0.7, 0, 1), chestRhythmRisk * 0.65)
	local traumaRhythmRisk = math.max(internalBleedRhythmRisk * (0.45 + cardiacTraumaRhythmRisk * 0.55), cardiacTraumaRhythmRisk * 0.6)
	org.internalBleedRhythmRisk = internalBleedRhythmRisk
	org.traumaRhythmRisk = traumaRhythmRisk
	local stress = Clamp((org.heart or 0) * 0.9 + ischemia * 0.8 + (org.hypertension or 0) * 0.35 + (org.hypotension or 0) * 0.3 + hemorrhageRhythmStress * 0.35 + hemorrhageElectricalInstability * 0.95 + hypothermiaInstability * 0.35 + traumaRhythmRisk * 0.8 + Clamp(org.shock, 0, 80) / 180 + max(org.pain - 60, 0) / 220 + max(org.heartbeat - 165, 0) / 190, 0, 2.5)
	local arrhythmiaTarget = Clamp(math.max(stress * 0.42, hemorrhageElectricalInstability * 0.88, traumaRhythmRisk * 0.72) * math.Clamp(org.conditionResistanceMul or 1, 0.05, 1), 0, 1)
	org.arrhythmia = Approach(org.arrhythmia or 0, arrhythmiaTarget, arrhythmiaTarget > (org.arrhythmia or 0) and timeValue / Lerp(hemorrhageElectricalInstability, 25, 6) or timeValue / 90)
	if org.isPly and not org.otrub and not org.heartstop then
		if org.fibrillation or org.unstableRhythm or org.arrhythmia > 0.35 then
			owner:Notify("My heart feels like its beating weird...", 45, "arrhythmia", 0, nil, Color(255, 170, 170))
		elseif org.heartbeat >= 150 then
			owner:Notify("My heart is beating faster than normal.", 45, "tachycardia", 0, nil, Color(255, 170, 170))
		elseif org.heartbeat > 0 and org.heartbeat <= 45 then
			owner:Notify("My heart feels too slow...", 45, "bradycardia", 0, nil, Color(150, 210, 255))
		end
	end
	if stress > 0.55 and CurTime() >= (org.nextArrhythmiaRoll or 0) then
		local rollInterval = Clamp(Remap(stress + hemorrhageElectricalInstability, 0.55, 2.3, 10, 1.25), 1.25, 10)
		org.nextArrhythmiaRoll = CurTime() + rollInterval
		local vfChance = Clamp((stress - 0.55) * 0.15 + hemorrhageElectricalInstability ^ 2 * 0.42 + traumaRhythmRisk ^ 2 * 0.16, 0.01, 0.65)
		if math.Rand(0, 1) < vfChance then
			hg.organism.StartFibrillation(org)
			if hemorrhageElectricalInstability > 0.72 then org.terminalRhythm = "ventricular_fibrillation" end
		end
	end

	if org.heartbeat >= terminalHeartRate then
		org.terminalRhythm = "terminal_tachycardia"
		hg.organism.StartFibrillation(org)
	end
	org.lastHeartbeatForPalpitations = org.heartbeat or 0
	org.lastPulseForPalpitations = org.pulse or 0

	if org.fibrillation then
		org.o2[1] = max(org.o2[1] - timeValue * 1.8, 0)
		local vfElapsed = CurTime() - (org.fibrillationStart or CurTime())
		local minVF = math.max(tonumber(cfg.HEMORRHAGE_VF_MIN_SECONDS) or 6, 1)
		local noUsefulOutput = (org.cardiacOutput or 0) < 0.08
		if vfElapsed >= 24 or (noUsefulOutput and vfElapsed >= minVF) then
			org.heartstop = true
			org.terminalRhythm = "ventricular_fibrillation"
		end
	end
	if rhythmInstability > 0 then
		local complicationBurden = math.max(rhythmInstability * 0.7, arrhythmiaComplication)
		org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * complicationBurden / 160, 0, 1)
		org.ischemia = math.min((org.ischemia or 0) + timeValue * complicationBurden * 0.05, 6)
	end
	if org.hypertension > 0.35 then org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * org.hypertension / 360, 0, 1) end
	if ischemia > 0.35 then org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * ischemia / 260, 0, 1) end
	if ischemia > 0.45 and org.isPly and not org.otrub and (org.lastCardiacPain or 0) < CurTime() then
		org.lastCardiacPain = CurTime() + math.Rand(14, 24)
		org.painadd = org.painadd + math.Rand(4, 9) * ischemia
		org.shock = math.max(org.shock, 10 + ischemia * 22)
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
		decayRate = decayRate * (1 - math.Clamp(arrhythmiaComplication * 0.9, 0, 0.9))
		org.ischemia = math.max(org.ischemia - decayRate, 0)
	end

	if org.hypotension > 0.55 then
		local disorientK = math.Clamp((org.hypotension - 0.55) / 0.35, 0, 1)
		org.disorientation = math.max(org.disorientation, 0.25 + disorientK * 1.25)
	end

	if org.hypotension > 0.64 then
		local shockK = math.Clamp((org.hypotension - 0.64) / 0.36, 0, 1)
		org.shock = math.Approach(org.shock, math.max(org.shock, shockK * 20), timeValue * (0.5 + shockK * 1.5))
	end

	-- Poor perfusion weakens a player, but low tissue oxygen must be the first
	-- system to push them into the serious collapse state.
	if org.hypotension > 0.5 and o2Value <= 15 then
		local lowK = math.Clamp((org.hypotension - 0.35) / 0.5, 0, 1)
		org.consciousness = math.Approach(org.consciousness, 0.75, timeValue * (0.08 + lowK * 0.11))
		if org.isPly and not org.otrub then
			org.owner:Notify("My limbs feel weak...", true, "low_perfusion", 0, nil, Color(200, 170, 170))
		end
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

	-- Bradycardia is dangerous because too few effective beats reduce minute
	-- cardiac output, not because cold owns a separate lethal temperature check.
	-- This can therefore kill a severely hypothermic patient who still has 3 L+
	-- of blood, while a well-perfused slow rhythm remains survivable.
	local bradyLowRate = math.max(tonumber(cfg.BRADYCARDIA_LOW_OUTPUT_HR_BPM) or 45, 1)
	local bradyLowReserve = math.Clamp(tonumber(cfg.BRADYCARDIA_LOW_OUTPUT_RESERVE) or 0.34, 0.05, 0.8)
	local bradyRateDepth = math.Clamp((bradyLowRate - (org.heartbeat or 0)) / math.max(bradyLowRate - 15, 1), 0, 1)
	local bradyOutputDepth = math.Clamp((bradyLowReserve - (org.cardiacOutput or 0)) / bradyLowReserve, 0, 1)
	local bradyPerfusionDepth = math.Clamp((bradyLowReserve - (org.perfusion or 0)) / bradyLowReserve, 0, 1)
	local bradyLowOutputSeverity = math.min(bradyRateDepth, math.max(bradyOutputDepth, bradyPerfusionDepth))
	org.bradycardicLowOutputSeverity = bradyLowOutputSeverity
	if not org.heartstop and bradyLowOutputSeverity > 0 then
		local gain = timeValue * (0.35 + bradyLowOutputSeverity ^ 2 * 1.65)
		org.bradycardicLowOutputTime = math.min((org.bradycardicLowOutputTime or 0) + gain, 20)
	else
		org.bradycardicLowOutputTime = math.Approach(org.bradycardicLowOutputTime or 0, 0, timeValue * 1.5)
	end

	-- Terminal hemorrhage is allowed to reach the tachycardia threshold below;
	-- low output alone is not an immediate VF/flatline trigger.
	if organSystemsEnabled then
		local hemorrhageDrivenLowOutput = criticalHemorrhageDepth > 0 or bloodNow <= 2500
		local failedCirculation = org.pulse < 10 and not hemorrhageDrivenLowOutput and not restartCirculationActive
		local failedHypotension = org.prolongedHypotension and not restartCirculationActive
		local failedBradyOutput = (org.bradycardicLowOutputTime or 0) >= (tonumber(cfg.BRADYCARDIA_ARREST_EXPOSURE) or 8)
			and (org.cardiacOutput or 0) < (tonumber(cfg.BRADYCARDIA_ARREST_OUTPUT) or 0.22)
			and (org.perfusion or 0) < (tonumber(cfg.BRADYCARDIA_ARREST_PERFUSION) or 0.28)
			and not restartCirculationActive
		if failedCirculation or failedHypotension or failedBradyOutput or org.brain >= 0.85 or org.heart >= 0.9 then org.heartstop = true end
		if org.temperature > 42 then org.heartstop = true end
	end
	-- A successful AED/epinephrine restart deliberately has a short window to
	-- rebuild circulation.  Do not immediately overwrite it here just because
	-- the previous arrest left the pulse at zero or caused temporary hypoxia.
	local hemorrhageDrivenLowOutput = criticalHemorrhageDepth > 0 or bloodNow <= 2500
	if ((org.pulse < 10 and not hemorrhageDrivenLowOutput) or (org.brain >= 0.6 and not (hg.organism.IsBrainDamageIgnored and hg.organism.IsBrainDamageIgnored(org)))) and not restartCirculationActive then org.heartstop = true end
	if org.temperature > 42 then org.heartstop = true end
	if org.heartstop and not org.fibrillation and org.terminalRhythm ~= "ventricular_fibrillation" and org.terminalRhythm ~= "asystole"
		and (org.heartbeat or 0) >= 140 and (org.arrhythmia or 0) >= 0.72
		and (ischemia >= 0.35 or (org.heartStrain or 0) >= 0.3 or (org.heartbeat or 0) >= 200) then
		org.terminalRhythm = "terminal_tachycardia"
	end
	if org.heartstop then
		-- Rhythm failure is discrete, but the electrical/mechanical numbers decay.
		-- Do not force heartbeat, pulse and pressure to zero on the arrest tick.
		if org.terminalRhythm ~= "ventricular_fibrillation" then org.fibrillation = false end
		org.arrhythmia = math.Approach(org.arrhythmia or 0, 0, timeValue * 0.35)
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

	-- Electrical activity, a palpable pulse, and cardiac output are separate.
	-- PEA therefore keeps a weak ECG trace briefly while pressure and pulse are 0.
	if org.heartstop then
		if not org.cardiacArrestStart then
			org.cardiacArrestStart = CurTime()
			org.cardiacArrestO2Start = math.Clamp(org.o2 and org.o2[1] or 0, 0, org.o2 and org.o2.range or 30)
		end

		local arrestElapsed = math.max(CurTime() - org.cardiacArrestStart, 0)
		if org.terminalRhythm == "ventricular_fibrillation" and arrestElapsed < peaDuration then
			org.heartbeat = 260
			org.ecgState = "ventricular_fibrillation"
		elseif org.terminalRhythm == "terminal_tachycardia" and arrestElapsed < peaDuration then
			org.heartbeat = 180
			org.ecgState = "terminal_tachycardia"
		elseif arrestElapsed < peaDuration then
			local peaTarget = Lerp(math.Clamp(arrestElapsed / peaDuration, 0, 1), 60, 20)
			org.heartbeat = math.Approach(org.heartbeat or terminalHeartRate, peaTarget, timeValue * 120)
			org.ecgState = "pea"
		else
			org.heartbeat = math.Approach(org.heartbeat or 0, 0, timeValue * 18)
			org.ecgState = org.heartbeat < 1 and "asystole" or "pea"
		end
		if arrestElapsed >= peaDuration then
			org.terminalRhythm = nil
		end

		-- Mechanical/electrical support is already represented by arrestCirculation
		-- above and is bounded by circulating volume. Do not overwrite pulse,
		-- stroke volume or cardiac output with normal fixed values here.
	else
		org.cardiacArrestStart = nil
		org.cardiacArrestO2Start = nil
		org.ecgState = hg.organism.GetECGState(org.heartbeat or 0, false, org)
	end

	if org.heartstop then
		org.heartstoptime = org.heartstoptime or CurTime()
		if org.isPly then
	        org.owner:Notify(cardiacArrestThoughts[math.random(#cardiacArrestThoughts)], true, "heartstop", 10)
		end
	else
		if org.isPly then
			org.owner:ResetNotification("heartstop")
		end
		org.heartstoptime = nil
	end

	-- A living, unconscious organism with no effective oxygenation or circulation
	-- makes frequent agonal attempts at breathing. Do not wait for the old 30s
	-- arrest delay: the first gasp is immediate and later ones stay irregular.
	local noOxygen = org.o2 and (org.o2[1] or 0) <= 0.25
	if org.alive and org.otrub and (org.heartstop or noOxygen) and (org.lastsoundtime or 0) < CurTime() then
		org.owner:EmitSound("breathing/agonalbreathing_" .. math.random(13) .. ".ogg", 60)
		org.lastsoundtime = CurTime() + math.Rand(4, 7)
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
