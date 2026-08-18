--local Organism = hg.organism
hg.organism.module = hg.organism.module or {}
local module = hg.organism.module
hg.organism.lastindex = hg.organism.lastindex or 1000000

hg.organism.config = hg.organism.config or {
	NORMAL_BLOOD_VOLUME_ML = 5000,
	BLOOD_PRELOAD_ZERO_ML = 2000,
	BLOOD_PRELOAD_FULL_ML = 3500,
	BLOOD_PRELOAD_CURVE_POWER = 2.5,
	BLOOD_OXYGEN_TRANSPORT_ZERO_ML = 2000,
	BLOOD_OXYGEN_TRANSPORT_FULL_ML = 5000,
	-- Calibrated so the 0-30 tissue-O2 transport ceiling is ~8 at 2250 mL,
	-- while even mild hemorrhage produces a small continuous delivery penalty.
	BLOOD_OXYGEN_TRANSPORT_CURVE_POWER = 3.565,
	HEMORRHAGE_MAX_COMPENSATED_HR = 220,
	HEMORRHAGE_COMPENSATION_POWER = 1.25,
	HEMORRHAGE_VF_MIN_SECONDS = 6,
	HEMORRHAGE_BRADYCARDIC_HR = 45,
	HEMORRHAGE_BRADYCARDIA_RESERVE = 0.35,
	CRITICAL_CIRCULATION_RESERVE = 0.62,
	CRITICAL_CIRCULATION_RANGE = 0.52,
	TERMINAL_CIRCULATION_RESERVE = 0.035,
	TERMINAL_CARDIAC_OUTPUT = 0.04,
	ARTERIAL_AMPUTATION_BLEED_MULTIPLIER = 0.65,
	ARTERIAL_HEADGIB_BLEED_MULTIPLIER = 1.65,
	-- Arterial loss is modeled directly in mL/s from wound severity and current
	-- flow. This keeps it frame-rate independent and lethal over tens of seconds
	-- instead of emptying the circulation in only a few simulation ticks.
	ARTERIAL_BLEED_ML_S_PER_SEVERITY = 3.0,
	ARTERIAL_MIN_FLOW_FRACTION = 0.08,
	POSTMORTEM_DECAY_SECONDS = 5,
	CARDIAC_ARREST_MECHANICAL_DECAY_SECONDS = 5,
	BRADYCARDIA_LOW_OUTPUT_HR_BPM = 45,
	BRADYCARDIA_LOW_OUTPUT_RESERVE = 0.34,
	BRADYCARDIA_ARREST_EXPOSURE = 8,
	BRADYCARDIA_ARREST_OUTPUT = 0.22,
	BRADYCARDIA_ARREST_PERFUSION = 0.28,
	-- Palpable pulse is mechanical/peripheral, not a duplicate of ECG heart rate.
	PALPABLE_ARRHYTHMIA_PENALTY = 0.60,
	PALPABLE_PALPITATION_PENALTY = 0.50,
	PALPABLE_VASOCONSTRICTION_PENALTY = 0.35,
	HEADGIB_ARTERIAL_WOUND_SIZE = 34,
	BLOOD_REGEN_RATE_ML_S = 0.5,
	-- Hemostasis is time-dependent: a fresh wound stays open before a clot can
	-- mature. Larger wounds take longer and may enlarge slightly if uncontrolled.
	WOUND_CLOT_DELAY_MIN_S = 6,
	WOUND_CLOT_DELAY_MAX_S = 18,
	WOUND_CLOT_RAMP_S = 12,
	WOUND_CLOT_RATE_SCORE_S = 0.11,
	WOUND_UNSTABLE_START_SCORE = 12,
	WOUND_UNSTABLE_FULL_SCORE = 30,
	WOUND_UNSTABLE_MAX_GROWTH_FRACTION = 0.22,
	WOUND_UNSTABLE_GROWTH_TIME_S = 90,
	ARTERIAL_CLOT_DELAY_MULTIPLIER = 1.6,
	ARTERIAL_CLOT_RATE_MULTIPLIER = 0.32,
	CATASTROPHIC_ARTERIAL_CLOT_MULTIPLIER = 0.08,
	HEMOSTATIC_TREATMENT_CLOT_GAIN = 7,
	HEMOSTATIC_TREATMENT_DELAY_REDUCTION = 0.82,
	-- Existing skull injury increases the consequence of the next head impact.
	-- 0.6 is a meaningful fracture; 1.0 is a fully failed cranial shell.
	SKULL_VULNERABILITY_START = 0.5,
	SKULL_VULNERABILITY_FULL = 1.0,
	SKULL_BRAIN_TRAUMA_ROOT_GAIN = 1.4,
	SKULL_BRAIN_TRAUMA_QUADRATIC_GAIN = 1.2,
	SKULL_HEMORRHAGE_ROOT_GAIN = 1.8,
	SKULL_HEMORRHAGE_QUADRATIC_GAIN = 1.6
}
hg.organism.normalBloodVolume = hg.organism.config.NORMAL_BLOOD_VOLUME_ML or 5000

-- Effective preload/venous-return reserve. Mild-to-moderate hemorrhage is
-- strongly compensated, then reserve falls rapidly as circulating volume nears
-- the terminal band. This is a continuous flow curve, not a death threshold.
function hg.organism.GetBloodDeliveryFraction(blood, exponent)
	local cfg = hg.organism.config or {}
	local normalVolume = hg.organism.normalBloodVolume or 5000
	local volume = math.Clamp(tonumber(blood) or normalVolume, 0, normalVolume)
	local zeroVolume = math.Clamp(cfg.BLOOD_PRELOAD_ZERO_ML or 2000, 0, normalVolume - 1)
	local fullVolume = math.Clamp(cfg.BLOOD_PRELOAD_FULL_ML or 3500, zeroVolume + 1, normalVolume)
	local x = math.Clamp((volume - zeroVolume) / (fullVolume - zeroVolume), 0, 1)
	local shape = math.max(tonumber(cfg.BLOOD_PRELOAD_CURVE_POWER) or 2.5, 0.1)
	local reserve = 1 - (1 - x) ^ shape
	return math.Clamp(reserve, 0, 1) ^ math.max(tonumber(exponent) or 1, 0.1)
end

-- Whole-body oxygen transport reserve caused by hemorrhage. This is deliberately
-- separate from arterial oxygenation: healthy lungs can keep the remaining blood
-- saturated while insufficient circulating blood still cannot deliver enough O2.
function hg.organism.GetHemorrhageOxygenTransportFraction(blood)
	local cfg = hg.organism.config or {}
	local normalVolume = hg.organism.normalBloodVolume or 5000
	local volume = math.Clamp(tonumber(blood) or normalVolume, 0, normalVolume)
	local zeroVolume = math.Clamp(cfg.BLOOD_OXYGEN_TRANSPORT_ZERO_ML or 2000, 0, normalVolume - 1)
	local fullVolume = math.Clamp(cfg.BLOOD_OXYGEN_TRANSPORT_FULL_ML or normalVolume, zeroVolume + 1, normalVolume)
	local x = math.Clamp((volume - zeroVolume) / (fullVolume - zeroVolume), 0, 1)
	local shape = math.max(tonumber(cfg.BLOOD_OXYGEN_TRANSPORT_CURVE_POWER) or 3.565, 0.1)
	return math.Clamp(1 - (1 - x) ^ shape, 0, 1)
end

-- Sympathetic compensation is driven by fractional loss of usable circulating
-- volume, not by a list of blood checkpoints.  It begins immediately but ramps
-- nonlinearly; severe preload failure can still overpower it in sv_pulse.
function hg.organism.GetHemorrhageCompensationDrive(blood)
	local cfg = hg.organism.config or {}
	local normalVolume = hg.organism.normalBloodVolume or 5000
	local terminalVolume = math.Clamp(cfg.BLOOD_PRELOAD_ZERO_ML or 2000, 0, normalVolume - 1)
	local volume = math.Clamp(tonumber(blood) or normalVolume, 0, normalVolume)
	local loss = math.Clamp((normalVolume - volume) / math.max(normalVolume - terminalVolume, 1), 0, 1)
	local power = math.max(tonumber(cfg.HEMORRHAGE_COMPENSATION_POWER) or 1.25, 0.1)
	return loss ^ power
end

-- Cranial vulnerability is derived from the skull's existing structural damage.
-- It deliberately uses a smooth curve: an intact skull contributes no bonus, a
-- displaced fracture around 0.6 meaningfully increases cerebral injury risk, and
-- a fully failed skull makes subsequent substantial head impacts extremely dangerous.
-- Returns normalized vulnerability, brain-trauma multiplier, hemorrhage multiplier.
function hg.organism.GetCranialTraumaFactors(orgOrSkull)
	local cfg = hg.organism.config or {}
	local skull = type(orgOrSkull) == "table" and (orgOrSkull.skull or 0) or (tonumber(orgOrSkull) or 0)
	local startDamage = math.Clamp(tonumber(cfg.SKULL_VULNERABILITY_START) or 0.5, 0, 0.99)
	local fullDamage = math.Clamp(tonumber(cfg.SKULL_VULNERABILITY_FULL) or 1, startDamage + 0.01, 1)
	local x = math.Clamp((skull - startDamage) / (fullDamage - startDamage), 0, 1)
	local root = math.sqrt(x)
	local traumaMul = 1
		+ root * (tonumber(cfg.SKULL_BRAIN_TRAUMA_ROOT_GAIN) or 1.4)
		+ x * x * (tonumber(cfg.SKULL_BRAIN_TRAUMA_QUADRATIC_GAIN) or 1.2)
	local hemorrhageMul = 1
		+ root * (tonumber(cfg.SKULL_HEMORRHAGE_ROOT_GAIN) or 1.8)
		+ x * x * (tonumber(cfg.SKULL_HEMORRHAGE_QUADRATIC_GAIN) or 1.6)
	return x, traumaMul, hemorrhageMul
end

function hg.organism.ZeroVitals(org)
	if not org then return end
	org.heartstop = true
	org.heartbeat = 0
	org.pulse = 0
	org.ecgState = "asystole"
	org.bloodPressure = 0
	org.systolic = 0
	org.diastolic = 0
	org.cardiacOutput = 0
	org.strokeVolume = 0
	org.hypotension = 1
	org.hypertension = 0
	org.bloodO2Cap = 0
	org.bloodCarryO2Cap = 0
	org.bodyoxygen = 0
	org.perfusion = 0
	org.brainoxygen = 0
	org.peripheralperfusion = 0
	org.cerebralPerfusion = 0
	org.myocardialOxygen = 0
	org.oxygenIntakeAvailable = false
	org.lungsfunction = false
	if istable(org.o2) then
		org.o2[1] = 0
		org.o2.curregen = 0
	end
end

local postMortemVitalKeys = {
	heartbeat = "pulse",
	pulse = "pulse",
	bloodPressure = "pressure",
	systolic = "pressure",
	diastolic = "pressure",
	cardiacOutput = "pressure",
	strokeVolume = "pressure",
	bloodO2Cap = "oxygen",
	bloodCarryO2Cap = "oxygen",
	bodyoxygen = "oxygen",
	perfusion = "pressure",
	brainoxygen = "oxygen",
	peripheralperfusion = "pressure",
	cerebralPerfusion = "pressure",
	myocardialOxygen = "oxygen",
	consciousness = "brain"
}

function hg.organism.BeginPostMortemDecay(org, duration)
	if not org or org.postMortemDecayStart then return end

	local now = CurTime()
	duration = math.max(tonumber(duration) or hg.organism.config.POSTMORTEM_DECAY_SECONDS or 5, 0.1)
	org.postMortemDecayStart = now
	org.postMortemDecayEnd = now + duration
	org.postMortemInitialVitals = {}
	for key in pairs(postMortemVitalKeys) do
		org.postMortemInitialVitals[key] = math.max(tonumber(org[key]) or 0, 0)
	end
	if istable(org.o2) then
		org.postMortemInitialVitals.o2 = math.max(tonumber(org.o2[1]) or 0, 0)
	end

	-- Structural death is immediate; numerical circulation/gas stores decay below.
	org.heartstop = true
	org.oxygenIntakeAvailable = false
	org.lungsfunction = false
end

function hg.organism.IsPostMortemDecaying(org)
	return org and not org.alive and (tonumber(org.postMortemDecayEnd) or 0) > CurTime()
end

local arrestMechanicalKeys = {
	pulse = true,
	bloodPressure = true,
	systolic = true,
	diastolic = true,
	cardiacOutput = true,
	strokeVolume = true
}

function hg.organism.ClearCardiacArrestMechanicalDecay(org)
	if not org then return end
	org.cardiacArrestMechanicalStart = nil
	org.cardiacArrestMechanicalEnd = nil
	org.cardiacArrestMechanicalInitial = nil
end

function hg.organism.BeginCardiacArrestMechanicalDecay(org)
	if not org or not org.alive or not org.heartstop or org.cardiacArrestMechanicalStart then return end

	local now = CurTime()
	local duration = math.max(tonumber(hg.organism.config.CARDIAC_ARREST_MECHANICAL_DECAY_SECONDS) or 5, 0.1)
	org.cardiacArrestMechanicalStart = now
	org.cardiacArrestMechanicalEnd = now + duration
	org.cardiacArrestMechanicalInitial = {}
	for key in pairs(arrestMechanicalKeys) do
		org.cardiacArrestMechanicalInitial[key] = math.max(tonumber(org[key]) or 0, 0)
	end
end

function hg.organism.GetCardiacArrestMechanicalFactor(org)
	if not org or not org.alive or not org.heartstop then
		hg.organism.ClearCardiacArrestMechanicalDecay(org)
		return 1, nil
	end

	hg.organism.BeginCardiacArrestMechanicalDecay(org)
	local startTime = tonumber(org.cardiacArrestMechanicalStart) or CurTime()
	local endTime = tonumber(org.cardiacArrestMechanicalEnd) or startTime
	local duration = math.max(endTime - startTime, 0.1)
	local progress = math.Clamp((CurTime() - startTime) / duration, 0, 1)
	-- Residual mechanical circulation falls quickly enough to feel like arrest, but
	-- not so quickly that every pressure/output value teleports to zero in one tick.
	local factor = (1 - progress) ^ 1.55
	return factor, org.cardiacArrestMechanicalInitial or {}
end

function hg.organism.UpdatePostMortemVitals(org)
	if not org or org.alive then return false end
	if not org.postMortemDecayStart then hg.organism.BeginPostMortemDecay(org) end

	local startTime = tonumber(org.postMortemDecayStart) or CurTime()
	local endTime = tonumber(org.postMortemDecayEnd) or startTime
	local duration = math.max(endTime - startTime, 0.1)
	local progress = math.Clamp((CurTime() - startTime) / duration, 0, 1)
	if progress >= 1 then
		hg.organism.ZeroVitals(org)
		return false
	end

	local initial = org.postMortemInitialVitals or {}
	local factors = {
		pulse = (1 - progress) ^ 1.55,
		pressure = (1 - progress) ^ 2.15,
		oxygen = (1 - progress) ^ 0.8,
		brain = (1 - progress) ^ 1.25
	}
	for key, curve in pairs(postMortemVitalKeys) do
		local starting = tonumber(initial[key]) or math.max(tonumber(org[key]) or 0, 0)
		org[key] = math.max(starting * factors[curve], 0)
	end
	if istable(org.o2) then
		local startingO2 = tonumber(initial.o2) or math.max(tonumber(org.o2[1]) or 0, 0)
		org.o2[1] = math.max(startingO2 * factors.oxygen, 0)
		org.o2.curregen = 0
	end

	org.hypotension = math.max(tonumber(org.hypotension) or 0, progress)
	org.hypertension = math.min(tonumber(org.hypertension) or 0, 1 - progress)
	org.ecgState = progress > 0.35 and "asystole" or org.ecgState
	org.heartstop = true
	org.oxygenIntakeAvailable = false
	org.lungsfunction = false
	return true
end

-- Wounds are owned by the organism, but both kinds of player ragdoll are
-- rendered as separate entities. Keep their replicated wound lists in lockstep
-- so a hit remains visible and targetable through fake/death ragdoll changes.
function hg.organism.SyncWounds(org)
	if not org or not IsValid(org.owner) then return end

	local owner = org.owner
	local wounds = org.wounds or {}
	local arterialWounds = org.arterialwounds or {}
	local targets = {owner}
	local fakeRagdoll = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner:GetNWEntity("FakeRagdoll", NULL)
	local deathRagdoll = IsValid(owner.RagdollDeath) and owner.RagdollDeath or owner:GetNWEntity("RagdollDeath", NULL)

	if IsValid(fakeRagdoll) and fakeRagdoll != owner then
		table.insert(targets, fakeRagdoll)
	end

	if IsValid(deathRagdoll) and deathRagdoll != owner and deathRagdoll != fakeRagdoll then
		table.insert(targets, deathRagdoll)
	end

	for _, target in ipairs(targets) do
		target:SetNetVar("wounds", wounds)
		target:SetNetVar("arterialwounds", arterialWounds)
	end
end

function hg.organism.KillFatalBrainDamage(org)
	if not org or org.fatalBrainDeath then return false end

	org.fatalBrainDeath = true
	org.alive = false
	org.needotrub = false
	org.otrub = false
	org.incapacitated = false
	hg.organism.BeginPostMortemDecay(org)

	local owner = org.owner
	if IsValid(owner) and owner:IsPlayer() and owner:Alive() then
		owner:Kill()
	end

	return true
end

local panicattack_threshold = 0.3
local panicattack_add_decay_time = 80
local panicattack_rise_time = 4
local panicattack_decay_time = 140
local panicattack_gain_mul = 0.7
local panicattack_threshold = 0.45
local panicattack_add_decay_time = 90
local panicattack_rise_time = 2.5
local panicattack_decay_time = 200
local panicattack_gain_chance = 1
local panicattack_gain_mul = 1
local panicattack_disorientation = 0.45
local panicattack_adrenaline_add_target = 4
local panicattack_adrenaline_add_rise_time = 14
local panicattack_heart_roll_delay = 15
local panicattack_heart_roll_chance = 1
local panicattack_damage_scale = 0.022
local panicattack_witness_radius = 850
local panicattack_death_radius = 900
local panicattack_corpse_radius = 400
local panicattack_corpse_total = 0.3
local panicattack_corpse_tick = 0.03
local panicattack_fire_radius = 450
local panicattack_fire_check_delay = 1
local hg_panic = ConVarExists("hg_panic") and GetConVar("hg_panic") or CreateConVar("hg_panic", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enable panic attack logic", 0, 1)
local hg_painsound = ConVarExists("hg_painsound") and GetConVar("hg_painsound") or CreateConVar("hg_painsound", "6", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Pain audio: 0 = pain beat + reality, 1 = pain beat, 2 = agony, 3 = altpain, 4 = reality, 5 = sillypain, 6 = REM pain stack", 0, 6)
local hg_dyingsound = ConVarExists("hg_dyingsound") and GetConVar("hg_dyingsound") or CreateConVar("hg_dyingsound", "2", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Dying audio: 0 = conscious beat + ending, 1 = conscious beat, 2 = dying, 3 = alto2, 4 = ending, 5 = sillydying, 6 = fuck, 7 = sonimcooked, 8 = REM dying 1 + 2, 9 = REM dying 2 + quiet itssofuckingover background, 10 = itshopeless", 0, 10)
local hg_otrubsound = ConVarExists("hg_otrubsound") and GetConVar("hg_otrubsound") or CreateConVar("hg_otrubsound", "4", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Unconscious (otrub) audio: 0 = unconscious beat, 1 = altotrub, 2 = sleepy, 3 = itssoover, 4 = nga im cooked, 5 = REM dying, 6 = fuck, 7 = itshopeless", 0, 7)
local gunfight_adrenaline_delay = 1.5
local gunfight_adrenaline_cap = 1.5
local debug_destroy_eyes = CreateConVar("hg_debug_destroy_eyes", "0", FCVAR_CHEAT, "Force eye destruction for visual debugging: 0 = off, 1 = left, 2 = right, 3 = both", 0, 3)
local seizure_min_duration = 10
local seizure_max_duration = 30
local seizure_end_shock = 35
local seizure_min_brain_damage_per_second = 0.0025
local seizure_max_brain_damage_per_second = 0.005
local seizure_shock_per_second = 1.5
local seizure_pose_force = 850
local seizure_pose_damp = 42
local seizure_leg_buckle = 46
local seizure_shake_freq = 5.8
local seizure_shake_amp = 1.35
local seizure_brain_trauma_gain_mul = 2
local seizure_brain_heal_gain_mul = 1.1
local seizure_temperature_gain_mul = 0.0065
local seizure_temperature_cold_gain_mul = 0.005
local seizure_temperature_low_start = 35
local seizure_temperature_high_start = 39
local seizure_brain_sustained_gain_min = 0.004
local seizure_brain_sustained_gain_max = 0.075
local seizure_brain_roll_delay = 8
local seizure_brain_roll_min_chance = 5
local seizure_brain_roll_max_chance = 55
local seizure_no_cause_decay_time = 90
local seizure_mannitol_gain_reduction = 0.5
local seizure_mannitol_recovery_bonus = 1
hook.Add("Org Clear", "Main", function(org)
	org.alive = true
	org.otrub = false
	org.postMortemDecayStart = nil
	org.postMortemDecayEnd = nil
	org.postMortemInitialVitals = nil
	org.entindex = IsValid(org.owner) and org.owner:EntIndex() or hg.organism.lastindex + 1
	module.pulse[1](org)
	module.blood[1](org)
	module.pain[1](org)
	module.stamina[1](org)
	module.lungs[1](org)
	module.liver[1](org)
	module.metabolism[1](org)
	module.concussion[1](org)
	module.random_events[1](org)
	module.goodmood[1](org)
	if module.teeth and module.teeth[1] then module.teeth[1](org) end
	if module.medical_system and module.medical_system[1] then module.medical_system[1](org) end
	if module.trauma_combo and module.trauma_combo[1] then module.trauma_combo[1](org) end
	org.brain = 0
	org.brainFrontal = 0
	org.brainParietal = 0
	org.brainTemporal = 0
	org.brainOccipital = 0
	org.brainHemorrhage = 0
	org.brainBleedRate = 0
	-- Perfusion is kept separate from the existing mmHg blood-pressure value:
	-- pressure is the pump's output, while perfusion describes how much of that
	-- output reaches the body and brain.
	org.brainSwelling = 0
	org.intracranialPressure = 0
	org.cerebralPerfusion = 1
	org.bodyoxygen = 1
	org.perfusion = 1
	org.brainoxygen = 1
	org.peripheralperfusion = 1
	org.perfusionMoveMul = 1
	org.perfusionGripMul = 1
	org.hypoxia = 0
	org.hypoxiaTime = 0
	org.severeHypoxiaTime = 0
	org.systemicIschemiaTime = 0
	org.neckBrainOxygenPenalty = 0
	org.eyeL = 0
	org.eyeR = 0
	org.eyeLDestroyed = nil
	org.eyeRDestroyed = nil
	org.consciousness = 1
	org.disorientation = 0
	org.jaw = 0
	org.teethLost = 0
	org.spine1 = 0
	org.spine2 = 0
	org.spine3 = 0
	org.chest = 0
	org.pelvis = 0
	org.skull = 0
	org.eyeL = 0
	org.eyeR = 0
	org.stomach = 0
	org.intestines = 0
	org.headtrauma = 0

	org.tranexamic_acid = 0

	org.thiamine = 0
	org.thiamine_timer = 0
	org.thiamine_healed = false

	org.lleg = 0
	org.rleg = 0
	org.larm = 0
	org.rarm = 0
	org.llegdislocation = false
	org.rlegdislocation = false
	org.rarmdislocation = false
	org.larmdislocation = false
	org.jawdislocation = false

	org.llegamputated = false
	org.rlegamputated = false
	org.rarmamputated = false
	org.larmamputated = false
	org.headamputated = false

	org.furryinfected = false

	org.health = 100
	org.canmove = true
	org.recoilmul = hg.GetSubRolePerk and hg.GetSubRolePerk(owner, "RecoilMul", 1) or 1
	org.legstrength = 1
	org.armstrength = 1
	org.meleespeed = 1
	org.breathing = 1
	-- Keep the initialized recoil multiplier within the safe range.
	org.recoilmul = math.Clamp(tonumber(org.recoilmul) or 1, 0.65, 1.5)
	org.temperature = 36.7
	org.superfighter = false
	org.CantCheckPulse = nil
	org.HEV = nil
	org.bleedingmul = 1
	org.neckslitSoundName = nil
	org.neckslitSoundEnt = nil

	--\\ info for rp addition
	org.last_heartbeat = CurTime()
	org.bulletwounds = 0
	org.stabwounds = 0
	org.slashwounds = 0
	org.bruises = 0
	org.burns = 0
	org.explosionwounds = 0

	org.fear = 0
	org.fearadd = 0
	--//

	org.assimilated = 0
	org.berserk = 0
	org.noradrenaline = 0
	org.zerlkers = 0
	org.zerlkersOverdose = 0
	org.panicattackadd = 0
	org.panicattack = 0
	org.panicattackActive = false
	org.nextPanicHeartRoll = 0
	org.seizure = 0
	org.seizureActive = false
	org.seizureStart = 0
	org.seizureEnd = 0
	org.nextSeizureSpasm = 0
	org.nextSeizureRoll = 0
	org.seizureSuppressedUntil = 0
	org.lastSeizureBrain = 0
	org.lastSeizureLobeDamage = 0
	org.lastSeizureTemperature = org.temperature
	org.deathStateEnd = nil
	org.deathStateKilled = nil
	org.lastWoundsSig = nil
	org.lastArterialWoundsSig = nil
	org.fatalBrainDeath = nil
	org.headGibArterialWoundAdded = nil

	org.noradrenalineEndTime = nil
	org.blindness = nil

	-- Hand dominance for limb impairment calculations
	org.hand_dominance = "right"

	-- Permanent aiming impairment from repeated arm trauma
	org.permanent_aim_impairment = 0

	if IsValid(org.owner) then
		if org.owner:IsPlayer() and org.owner:Alive() then
			org.owner:SetHealth(100)
			org.owner:SetNetVar("wounds",{})
			org.owner:SetNetVar("arterialwounds",{})
		end

		org.owner:SetNetVar("zableval_masku", false)
	end

	org.allowholster = false
	
	org.just_damaged_bone = nil
	org.damagedBoneName = nil
	org.damagedBoneSeverity = nil
	org.damagedBoneTime = nil
	org.brokenBoneName = nil
	org.LodgedEntities = nil
	
	
	org.dmgstack = {}
end)

hook.Add("Should Fake Up", "organism", function(ply)
	local org = ply.organism
	local resilience = hg.organism.GetResilience and hg.organism.GetResilience(org) or 0
	if org.seizureActive or org.otrub or org.fake or org.nearpainlimit or org.shock > 40 * (1 + resilience * 0.5) or org.spine1 >= hg.organism.fake_spine1 or org.spine2 >= hg.organism.fake_spine2 or org.spine3 >= hg.organism.fake_spine3 or (org.lleg == 1 and org.rleg == 1) and org.berserk <= 0.3 or org.consciousness <= 0.4 * (1 - resilience * 0.3) then
		return false
	end
end)

util.AddNetworkString("organism_send")
util.AddNetworkString("organism_sendply")
local CurTime = CurTime
local nullTbl = {}
local function wounds_signature(wounds)
	if not wounds or #wounds == 0 then return "0" end

	local sig = tostring(#wounds)
	for i = 1, #wounds do
		local wound = wounds[i]
		if wound then
			sig = sig .. ":" .. tostring(wound[4]) .. ":" .. tostring(math.Round((wound[1] or 0) * 100)) .. ":" .. tostring(wound[7])
		end
	end

	return sig
end
local hg_developer = ConVarExists("hg_developer") and GetConVar("hg_developer") or CreateConVar("hg_developer",0,FCVAR_SERVER_CAN_EXECUTE,"Toggle developer mode (enables damage traces)",0,1)
local hg_incapacitation = ConVarExists("hg_incapacitation") and GetConVar("hg_incapacitation") or CreateConVar("hg_incapacitation", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enable Remorseism incapacitation", 0, 1)
local hg_huyorgans = ConVarExists("hg_huyorgans") and GetConVar("hg_huyorgans") or CreateConVar("hg_huyorgans", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Organ complexity: 0=simple heart/lungs with bones and head trauma, 1=full organ failure", 0, 1)
local incapacitation_death_delay = 25

function hg.organism.IncapacitationEnabled()
	return hg_incapacitation:GetBool()
end

function hg.organism.OrganSystemsEnabled()
	return hg_huyorgans:GetBool()
end

local function approachVital(current, target, timeValue, fallRate, recoveryRate)
	local value = tonumber(current)
	if value == nil or value != value then value = target end
	local rate = target > value and (recoveryRate or fallRate) or fallRate
	return math.Approach(value, target, math.max(timeValue or 0, 0) * rate)
end

-- Normalized delivery values are organism reserves, not smoothed readouts.
-- They continuously recover toward the healthy 1.0 baseline, while the
-- current physiological target can force them downward much more quickly.
local function updateNormalizedVital(current, target, timeValue, recoveryRate, forcedLossRate)
	local value = tonumber(current)
	if value == nil or value != value then value = 1 end

	local dt = math.max(timeValue or 0, 0)
	local forcedTarget = math.Clamp(tonumber(target) or 1, 0, 1)
	value = math.Clamp(value, 0, 1)
	local responseRate = forcedTarget < value and forcedLossRate or recoveryRate
	local response = 1 - math.exp(-dt * math.max(responseRate or 0, 0))
	value = value + (forcedTarget - value) * response

	return math.Clamp(value, 0, 1)
end

-- Vottur's perfusion model derives delivery from normalized circulation state.
function hg.organism.UpdateIntracranialPressure(org, pressure, timeValue)
	if not org then return 1 end

	local dt = timeValue or engine.TickInterval()
	local hemorrhage = math.Clamp(org.brainHemorrhage or 0, 0, 1)
	local bleedStress = math.Clamp((org.brainBleedRate or 0) / 0.0035, 0, 1)
	local brainTrauma = math.Clamp(org.brain or 0, 0, 1)
	local skullTrauma = math.Clamp(org.skull or 0, 0, 1)
	local zerlkers = hg.organism.GetZerlkersResistance and hg.organism.GetZerlkersResistance(org) or 0
	local mannitolRelief = math.Clamp((org.mannitol or 0) / 2, 0, 1)
	local hypoxicEdema = math.Clamp(((org.hypoxiaTime or 0) - 25) / 50, 0, 1) * 0.16
	-- A fracture becomes clinically significant at 0.6 and an open skull at 1.0.
	-- This keeps traumatic skull damage from being a purely cosmetic precursor to
	-- brain injury: it raises pressure even before the hemorrhage has expanded.
	local fracturedSkull = math.Clamp((skullTrauma - 0.6) / 0.4, 0, 1)
	-- A live dose slows the secondary swelling response, buying treatment time.
	-- The injury and hemorrhage still remain and can become terminal untreated.
	local traumaResponse = 1 - zerlkers * 0.55
	local swellingTarget = math.Clamp((hemorrhage * 0.62 + bleedStress * 0.18 + brainTrauma * 0.24 + skullTrauma * 0.06 + fracturedSkull * 0.12 + hypoxicEdema) * traumaResponse - mannitolRelief * 0.22, 0, 1)

	org.brainSwelling = approachVital(org.brainSwelling, swellingTarget, dt, swellingTarget > (org.brainSwelling or 0) and 0.026 or (0.006 + mannitolRelief * 0.02))
	local icpTarget = math.Clamp((org.brainSwelling or 0) * 0.78 + hemorrhage * 0.24 + bleedStress * 0.12 - mannitolRelief * 0.08, 0, 1)
	org.intracranialPressure = approachVital(org.intracranialPressure, icpTarget, dt, icpTarget > (org.intracranialPressure or 0) and 0.10 or (0.03 + mannitolRelief * 0.05))

	local pressurePenalty = math.Clamp(math.Remap(org.intracranialPressure, 0.15, 0.85, 0, 0.9), 0, 0.9)
	local cerebralTarget = math.Clamp((pressure or 0) - pressurePenalty, 0, 1)
	org.cerebralPerfusion = updateNormalizedVital(org.cerebralPerfusion, cerebralTarget, dt, 0.32, 0.22)
	return org.cerebralPerfusion
end

-- Zerlkers and adrenaline keep an injured character functional for longer.
-- This is resistance, not replacement blood or oxygen: pressure and cerebral
-- oxygen still win, while weakness and loss of awareness arrive later.
function hg.organism.GetResilience(org)
	if not org then return 0 end

	local zerlkers = math.Clamp(org.zerlkers or 0, 0, 1)
	local adrenaline = math.Clamp((org.adrenaline or 0) / 1.5, 0, 1)
	return math.max(zerlkers, adrenaline)
end

-- Zerlkers has a stronger effect than ordinary adrenaline, but only while a
-- single dose is active. Keeping it separate prevents other stimulants from
-- inheriting its emergency circulation and trauma benefits.
function hg.organism.GetZerlkersResistance(org)
	if not org or (org.zerlkersOverdose or 0) > 0 then return 0 end
	return math.Clamp(org.zerlkers or 0, 0, 1)
end

-- Short-lived combat chemistry helps a conscious character stay on their feet
-- through blunt impacts, without preventing damage or medical incapacitation.
function hg.organism.GetTraumaRagdollResistance(org)
	if not org then return 0 end

	-- A live Zerlkers dose should make an otherwise mobile character very hard
	-- to knock down. It cannot override broken spines/legs or terminal vitals,
	-- which are checked separately before a fake state is cancelled.
	local zerlkers = math.Clamp(org.zerlkers or 0, 0, 1) * 0.75
	local adrenaline = math.Clamp((org.adrenaline or 0) / 1.5, 0, 1) * 0.20
	local anger = math.Clamp(org.anger or 0, 0, 1) * 0.15
	return math.Clamp(zerlkers + adrenaline + anger, 0, 0.85)
end

function hg.organism.GetTraumaRagdollChanceMul(org)
	return 1 - hg.organism.GetTraumaRagdollResistance(org)
end

function hg.organism.GetResilientBlood(org)
	local resilience = hg.organism.GetResilience(org)
	local zerlkers = hg.organism.GetZerlkersResistance(org)
	-- This only extends the compensated low-volume band; it never adds real blood.
	return math.min((org and org.blood or 5000) + resilience * 600 + zerlkers * 500, 5000)
end

-- Keep the terminal gasp tied to the actual death event so every fatal route
-- (damage, organ failure, or an explicit Kill call) gets the same cue once.
hook.Add("PlayerDeath", "hg_organism_death_gasp", function(ply)
	if IsValid(ply) then
		ply:EmitSound("deathgasp.mp3", 75, 100)
	end
end)

-- Mechanical support can keep an otherwise treatable patient in the livable
-- band, but it cannot move oxygen through a destroyed pump, airway, lungs, or
-- an almost empty circulatory system.  Keeping this rule here makes CPR, AEDs
-- and the autosurgeon agree about when oxygen recovery is possible.
function hg.organism.RestoreSupportedOxygen(org, recovery, floors)

	if not org or not istable(org.o2) then return false end

	local leftLung = istable(org.lungsL) and (tonumber(org.lungsL[1]) or 0) or 0
	local rightLung = istable(org.lungsR) and (tonumber(org.lungsR[1]) or 0) or 0
	local criticalFailure = (tonumber(org.heart) or 0) >= 0.55
		or (tonumber(org.trachea) or 0) >= 0.55
		or leftLung >= 0.70 or rightLung >= 0.70
		-- Cardiac arrest itself marks lungsfunction false in sv_lungs; CPR and
		-- automated compressions must still work when the airway and lungs are intact.
		or (org.lungsfunction == false and not org.heartstop)
		-- Do not let medicine recover delivery from a stale O2 reservoir after
		-- the lungs have reported zero active intake.
		or (org.oxygenIntakeAvailable == false and not org.heartstop)
		or org.respiratoryArrest
	if criticalFailure then return false end

	local supportBlood = math.max(tonumber(org.blood) or 5000, 0)
	local normalBlood = math.max(hg.organism.normalBloodVolume or 5000, 1)
	local flowSupport = hg.organism.GetBloodDeliveryFraction(supportBlood, 1)
	local carryingCapacity = math.Clamp(supportBlood / normalBlood, 0, 1)
	local bloodSupportK = math.min(flowSupport, carryingCapacity)
	if bloodSupportK <= 0 then return false end

	recovery = math.max(tonumber(recovery) or 0, 0) * bloodSupportK
	floors = floors or {}
	local oxygenMax = math.max(tonumber(org.o2.range) or 30, 1)
	local supportCeiling = bloodSupportK
	local supportedOxygenMax = oxygenMax * supportCeiling
	local oxygenFloor = math.Clamp(tonumber(floors.oxygen) or 0, 0, supportedOxygenMax)
	local oxygenTarget = math.Clamp(tonumber(floors.oxygenTarget) or oxygenFloor, oxygenFloor, supportedOxygenMax)
	org.o2[1] = math.max(math.Approach(tonumber(org.o2[1]) or 0, oxygenTarget, recovery * oxygenMax), oxygenFloor)

	local vitalFloors = {
		bodyoxygen = tonumber(floors.bodyoxygen) or 0,
		brainoxygen = tonumber(floors.brainoxygen) or 0,
		perfusion = tonumber(floors.perfusion) or 0,
		peripheralperfusion = tonumber(floors.peripheralperfusion) or 0,
		cerebralPerfusion = tonumber(floors.cerebralPerfusion) or 0,
		myocardialOxygen = tonumber(floors.myocardialOxygen) or 0
	}
	for key, floor in pairs(vitalFloors) do
		floor = math.Clamp(floor, 0, supportCeiling)
		local target = math.Clamp(tonumber(floors[key .. "Target"]) or floor, floor, supportCeiling)
		org[key] = math.max(math.Approach(tonumber(org[key]) or 0, target, recovery), floor)
	end

	org.hypoxia = math.Approach(tonumber(org.hypoxia) or 0, 0, recovery)
	org.hypoxiaTime = math.min(math.Approach(tonumber(org.hypoxiaTime) or 0, 0, recovery * 18), tonumber(floors.hypoxiaTime) or math.huge)
	org.severeHypoxiaTime = math.min(math.Approach(tonumber(org.severeHypoxiaTime) or 0, 0, recovery * 14), tonumber(floors.severeHypoxiaTime) or math.huge)
	org.systemicIschemiaTime = math.min(math.Approach(tonumber(org.systemicIschemiaTime) or 0, 0, recovery * 14), tonumber(floors.systemicIschemiaTime) or math.huge)
	return true
end

-- A normal Zerlkers dose is a last-resort stimulant, not a substitute for a
-- functioning brain, circulation, or oxygen supply. Keep this check in one
-- place so ordinary pain/shock collapse can be suppressed without allowing a
-- terminal condition to be silently cleared later in the tick.
function hg.organism.ZerlkersCanPreventOtrub(org)

	if not org or (org.zerlkers or 0) <= 0 or (org.zerlkersOverdose or 0) > 0 then return false end

	-- Zerlkers is meant to carry a patient through severe trauma. Reserve its
	-- failure for conditions that are genuinely close to fatal, rather than the
	-- moderate vital penalties that normally start an otrub.
	local terminalBrainDamage = (org.brain or 0) >= 0.38 or (org.brainHemorrhage or 0) >= 0.12
	local terminalBrainOxygen = (org.brainoxygen or 1) <= 0.12
	local terminalFailure = org.heartstop or org.respiratoryArrest or org.choking or org.neckslit

	return not (terminalBrainDamage or terminalBrainOxygen or terminalFailure)
end

-- Zerlkers can also stop the non-terminal ragdoll/fake state caused by pain,
-- shock, or moderate circulation/oxygen loss. Structural injuries and truly
-- terminal physiology still take precedence.
function hg.organism.ZerlkersCanPreventFake(org)
	if not hg.organism.ZerlkersCanPreventOtrub(org) then return false end

	local oxygen = org.o2 and org.o2[1] or math.huge
	local mechanicalIncapacity = (org.spine2 or 0) >= hg.organism.fake_spine2
		or (org.spine3 or 0) >= hg.organism.fake_spine3
		or ((org.lleg or 0) >= 1 and (org.rleg or 0) >= 1)
		or org.seizureActive == true
	local severePhysiology = oxygen < 5
		or (org.brain or 0) >= 0.35 or org.choking or org.neckslit

	return not (mechanicalIncapacity or severePhysiology)
end

function hg.organism.UpdatePerfusion(owner, org, timeValue)
	if not org then return end

	local dt = timeValue or engine.TickInterval()
	local resilience = hg.organism.GetResilience(org)
	local zerlkers = hg.organism.GetZerlkersResistance(org)
	-- Resilience can soften shock effects, but it cannot create circulating volume.
	local blood = math.max(org.blood or 0, 0)

	-- Continuous blood-volume delivery stays near compensated values through
	-- mild loss, then collapses nonlinearly as preload becomes critically small.
	-- This is a flow curve, not a hidden death event.
	local bloodFraction = hg.organism.GetBloodDeliveryFraction(blood, 1)
	-- Compensation is strongest in the middle of the curve and vanishes at both
	-- zero and normal volume, so stimulants cannot manufacture circulation.
	local lowBloodReserve = bloodFraction * (1 - bloodFraction) * zerlkers * 0.35
	bloodFraction = math.min(bloodFraction + lowBloodReserve, 1)
	local oxygen = org.o2 and math.Clamp((org.o2[1] or 0) / math.max(org.o2.range or 30, 1), 0, 1) or 1
	-- Losing fresh intake does not instantly remove oxygen already carried in
	-- blood and tissue. Cap residual delivery at the current body-O2 level so it
	-- can preserve and then drain the reserve, but can never regenerate a patient
	-- merely because the stored O2 value is still high.
	local oxygenIntakeAvailable = org.oxygenIntakeAvailable ~= false
	local residualOxygenDelivery = math.min(oxygen, math.Clamp(org.bodyoxygen or oxygen, 0, 1))
	local oxygenDelivery = oxygenIntakeAvailable and oxygen or residualOxygenDelivery
	local hypercapnia = math.Clamp(math.Remap(org.CO or 0, 5, 30, 0, 1), 0, 1)
	local brainTrauma = math.Clamp(org.brain or 0, 0, 1)
	local shockPenalty = math.Clamp((org.shock or 0) / 100, 0, 0.35) * (1 - resilience * 0.3 - zerlkers * 0.45)
	local arterialImpairment = math.Clamp(org.arterialO2Impairment or 0, 0, 1)
	local pump = math.Clamp(1 - (org.hypotension or 0) + (org.hypertension or 0) * 0.2, 0, 1.2)
	local output = math.Clamp(org.cardiacOutput or ((org.pulse or 0) / 70), 0, 1.2)
	-- Hypothermia progressively lowers metabolic demand and constricts peripheral
	-- vessels. Model that as a redistribution rather than free oxygen: the effect
	-- is bounded by the oxygen, blood and central circulation that still exist.
	-- It begins with mild hypothermia and is fully active near 30 C; the rhythm
	-- instability and arrest rules in sv_pulse still make deeper cold dangerous.
	local bodyTemperature = org.temperature or 36.7
	local hypothermicPriority = bodyTemperature < 35 and math.Clamp(math.Remap(bodyTemperature, 35, 30, 0, 1), 0, 1) or 0
	local centralOxygenSupply = math.min(oxygenDelivery, bloodFraction)
	org.hypothermicSurvivalPriority = hypothermicPriority

	-- Tissue O2 already has a separate carrying-capacity limit in sv_lungs.
	-- Keep oxygen availability and circulating-volume support as hard limits
	-- rather than multiplying several hemorrhage penalties together.
	local bodyOxygenTarget = math.Clamp(centralOxygenSupply * Lerp(hypercapnia, 1, 0.35), 0, 1)
	local coldBodyOxygenLossRate = 2.5 * Lerp(hypothermicPriority, 1, 0.72)
	org.bodyoxygen = updateNormalizedVital(org.bodyoxygen, bodyOxygenTarget, dt, 0.55, coldBodyOxygenLossRate)
	-- Arterial loss already lowers blood volume and the circulation target in
	-- sv_pulse. Applying its live bleed rate again here made any open artery an
	-- independent disorientation/otrub source instead of a blood-loss emergency.
	-- Blood volume already owns the baseline circulation in sv_pulse. That
	-- circulation then produces both cardiacOutput and hypotension, so multiplying
	-- pump, bloodFraction and output here applied the same blood loss three times.
	-- Moderate hemorrhage remains compensated; the shared preload curve only
	-- becomes steep as volume approaches the severe/terminal range.
	--
	-- The weakest part of the circulation should cap delivery instead: low volume,
	-- pump pressure, or cardiac output can each be decisive without compounding the
	-- same deficit. This keeps moderate blood loss weak but viable while very low
	-- volume progressively removes pressure and oxygen delivery.
	local circulationLimit = math.min(pump, bloodFraction, math.max(output, 0.15))
	-- Shock already lowers consciousness in sv_pain and weakens the limbs below.
	-- Subtracting it from central flow as well made hemorrhagic shock reduce O2
	-- twice and moved the blackout point back above 2500 mL.
	-- Active venous/arterial/internal bleeding already changes circulating volume,
	-- and thoracic complications already feed their own lung/tamponade models.
	-- Systemic perfusion therefore follows the circulation limit once, rather than
	-- subtracting the same hemorrhage again from the downstream result.
	local pressureDelivery = math.Clamp(circulationLimit, 0, 1)
	local centralFlowSupply = math.min(pressureDelivery, bloodFraction)
	-- Perfusion is blood flow. Oxygen content affects the tissue supplied by that
	-- flow, but must not feed back into the flow value that sv_lungs uses as its
	-- O2 cap; that loop was the remaining sudden O2 crash at moderate blood loss.
	-- Reduced whole-body flow is the price of preserving the core. Peripheral
	-- flow falls much further, so cold patients lose movement and grip before the
	-- protected brain and myocardium lose their remaining oxygen reserve.
	local perfusionTarget = centralFlowSupply * Lerp(hypothermicPriority, 1, 0.84)
	local peripheralTarget = math.min(centralFlowSupply, math.Clamp(pressureDelivery - shockPenalty * 0.35, 0, 1))
	peripheralTarget = peripheralTarget * Lerp(hypothermicPriority, 1, 0.48)

	org.perfusion = updateNormalizedVital(org.perfusion, perfusionTarget, dt, 0.30, 0.16)
	-- Vasoconstriction can preserve a modest central pressure advantage, but it
	-- cannot bypass absent circulation or manufacture volume.
	local centralPressureSupport = hypothermicPriority * centralFlowSupply * 0.18
	local cerebralPerfusion = hg.organism.UpdateIntracranialPressure(org, math.Clamp(pump + centralPressureSupport, 0, 1.2), dt)
	-- In the cold, systemic oxygen is preferentially routed toward the brain.
	-- This lets cerebral oxygen exceed the whole-body delivery stat without ever
	-- exceeding actual oxygen-carrying capacity.
	local brainOxygenSupply = Lerp(hypothermicPriority, math.min(org.bodyoxygen, centralOxygenSupply), centralOxygenSupply)
	local cerebralOxygenDelivery = math.min(cerebralPerfusion, brainOxygenSupply)
	-- A carotid wound has one distinct local effect in addition to systemic blood
	-- loss: reduced cerebral inflow. Keep that effect here instead of also
	-- deleting arterial O2 or systemic pressure elsewhere.
	local brainTarget = math.Clamp(cerebralOxygenDelivery * Lerp(arterialImpairment, 1, 0.45) * Lerp(brainTrauma, 1, 0.35) * Lerp(hypercapnia, 1, 0.5), 0, 1)
	local coldBrainOxygenLossRate = 2.6 * Lerp(hypothermicPriority, 1, 0.58)
	org.brainoxygen = updateNormalizedVital(org.brainoxygen, brainTarget, dt, 0.28, coldBrainOxygenLossRate * 0.085)
	org.peripheralperfusion = updateNormalizedVital(org.peripheralperfusion, peripheralTarget, dt, 0.34, 0.20)

	-- Lower cardiac metabolic demand preserves myocardial oxygen from the same
	-- finite central supply. Recovery remains deliberately slow and impossible
	-- without breathing, circulating blood and central flow.
	if hypothermicPriority > 0 and centralFlowSupply > 0 then
		local demandAdjustedCentralFlow = math.Clamp(centralFlowSupply / Lerp(hypothermicPriority, 1, 0.8), 0, 1)
		local myocardialColdTarget = math.min(centralOxygenSupply, demandAdjustedCentralFlow)
		if myocardialColdTarget > (org.myocardialOxygen or 0) then
			org.myocardialOxygen = math.Approach(org.myocardialOxygen or 0, myocardialColdTarget, dt * 0.12 * hypothermicPriority)
		end
	end

	-- A recent epinephrine dose strongly stabilizes oxygen delivery, but only
	-- while the lungs are providing oxygen and the patient has enough blood to
	-- carry it. This prevents stat spikes from treating zero regeneration as a
	-- recoverable state.
	local epinephrineStabilizing = (org.epinephrineStabilizationUntil or 0) > CurTime()
		and oxygenIntakeAvailable and not org.heartstop
	if epinephrineStabilizing then
		local epiFlowSupport = hg.organism.GetBloodDeliveryFraction(blood, 1)
		local epiCarryingCapacity = math.Clamp(blood / math.max(hg.organism.normalBloodVolume or 5000, 1), 0, 1)
		local epiBloodSupport = math.min(epiFlowSupport, epiCarryingCapacity)
		local epiFloor = 0.55 * epiBloodSupport
		org.bodyoxygen = math.max(org.bodyoxygen or 0, epiFloor)
		org.brainoxygen = math.max(org.brainoxygen or 0, epiFloor)
		org.perfusion = math.max(org.perfusion or 0, 0.50 * epiBloodSupport)
		org.peripheralperfusion = math.max(org.peripheralperfusion or 0, 0.45 * epiBloodSupport)
		org.cerebralPerfusion = math.max(org.cerebralPerfusion or 0, 0.50 * epiBloodSupport)
	end

	local rawMoveMul = math.Clamp(math.Remap(org.peripheralperfusion, 0.22, 0.75, 0.25, 1), 0.25, 1) * Lerp(hypothermicPriority, 1, 0.72)
	local rawGripMul = math.Clamp(math.Remap(org.peripheralperfusion, 0.18, 0.7, 0.35, 1), 0.35, 1) * Lerp(hypothermicPriority, 1, 0.65)
	org.perfusionMoveMul = math.min(rawMoveMul + resilience * 0.2, 1)
	org.perfusionGripMul = math.min(rawGripMul + resilience * 0.15, 1)

	-- Cold tissue tolerates a lower systemic flow because its metabolic demand is
	-- lower. Use demand-adjusted perfusion for ischemia/death timing while keeping
	-- the raw perfusion stat low so the physical penalty remains visible.
	local demandAdjustedPerfusion = math.Clamp(org.perfusion / Lerp(hypothermicPriority, 1, 0.84), 0, 1)
	local thresholdMul = (1 - resilience * 0.25 - zerlkers * 0.25) * Lerp(hypothermicPriority, 1, 0.82)
	local badHypoxia = org.brainoxygen < 0.45 * thresholdMul or org.cerebralPerfusion < 0.4 * thresholdMul or demandAdjustedPerfusion < 0.35 * thresholdMul
	local severeHypoxia = org.brainoxygen < 0.22 * thresholdMul or org.cerebralPerfusion < 0.18 * thresholdMul or demandAdjustedPerfusion < 0.16 * thresholdMul
	org.hypoxia = math.Clamp(1 - math.min(org.bodyoxygen, org.brainoxygen, org.cerebralPerfusion, demandAdjustedPerfusion), 0, 1)
	org.hypoxiaTime = badHypoxia and math.min((org.hypoxiaTime or 0) + dt * (severeHypoxia and 2.25 or 1), 120) or math.Approach(org.hypoxiaTime or 0, 0, dt * 2.5)
	org.severeHypoxiaTime = severeHypoxia and math.min((org.severeHypoxiaTime or 0) + dt, 120) or math.Approach(org.severeHypoxiaTime or 0, 0, dt * 2)

	-- Sustained failure of oxygen delivery eventually becomes systemic ischemia.
	-- Keep it tied to an actual catastrophic cause: severe blood loss, hypoxemia,
	-- or hemotransfusion shock. A transient low-perfusion value on its own must
	-- not quietly start systemic organ damage.
	local demandAdjustedPeripheral = math.Clamp(org.peripheralperfusion / Lerp(hypothermicPriority, 1, 0.48), 0, 1)
	local systemicDelivery = math.min(org.bodyoxygen, demandAdjustedPerfusion, demandAdjustedPeripheral)
	local systemicSeverity = math.Clamp((0.55 - systemicDelivery) / 0.45, 0, 1)
	-- internalBleed is an injury-severity score, not lost circulating volume.
	-- Let it become dangerous through its real bleed rate/complications and the
	-- resulting blood loss instead of treating the score itself as ischemia.
	local severeBloodLoss = bloodFraction < 0.72
	local o2Value = istable(org.o2) and (org.o2[1] or 30) or (tonumber(org.o2) or 30)
	local o2Range = istable(org.o2) and math.max(org.o2.range or 30, 1) or 30
	-- Exertion debt deliberately lowers the displayed tissue-O2 reserve while a
	-- player is exhausted. Add that temporary demand back for the pathological
	-- hypoxemia gate so ordinary fatigue cannot start systemic organ damage.
	local nonExertionO2 = math.min(o2Value + math.max(org.exertionO2Debt or 0, 0), o2Range)
	local hypoxemia = nonExertionO2 / o2Range < 14 / 30
	local ischemiaCauseActive = severeBloodLoss or hypoxemia or (org.hemotransfusionshock or 0) > 0
	if systemicSeverity > 0 and ischemiaCauseActive then
		local exposureRate = 0.35 + systemicSeverity * 0.65
		org.systemicIschemiaTime = math.min((org.systemicIschemiaTime or 0) + dt * exposureRate, 180)
	else
		org.systemicIschemiaTime = math.Approach(org.systemicIschemiaTime or 0, 0, dt * 2)
	end

	local systemicDelay = 20 * (1 + resilience * 0.6 + zerlkers * 1.2)
	if ischemiaCauseActive and (org.systemicIschemiaTime or 0) > systemicDelay then
		local durationRamp = math.Clamp(((org.systemicIschemiaTime or 0) - systemicDelay) / 30, 0, 1)
		local ischemiaRate = systemicSeverity * Lerp(durationRamp, 0.12, 0.3)
		org.ischemia = math.min((org.ischemia or 0) + dt * ischemiaRate, 6)
	end

	if owner and owner.IsBerserk and owner:IsBerserk() then return end
	local delayMul = 1 + resilience * 0.6 + zerlkers * 1.2
	local brainOxygen = math.Clamp(org.brainoxygen or 1, 0, 1)
	local cerebralHypoxia = math.Clamp((0.58 * thresholdMul - brainOxygen) / math.max(0.58 * thresholdMul, 0.01), 0, 1)
	if cerebralHypoxia > 0 and ((org.hypoxiaTime or 0) > 5 * delayMul or (org.severeHypoxiaTime or 0) > 2 * delayMul) then
		-- Cerebral oxygen, rather than the whole-body tissue reserve, owns LOC.
		-- The exponent gives mild hypoxia a soft cognitive effect and lets severe
		-- cerebral hypoxia pull consciousness toward zero continuously.
		local brainConsciousness = math.Clamp(1 - cerebralHypoxia ^ 1.35, 0, 1)
		org.consciousness = math.min(org.consciousness or 1, brainConsciousness)
	end
	if org.perfusion < 0.4 * thresholdMul and ((org.hypoxiaTime or 0) > 10 * delayMul or (org.severeHypoxiaTime or 0) > 4 * delayMul) then
		org.disorientation = math.max(org.disorientation or 0, math.Remap(org.perfusion, 0.4, 0, 1.5, 6))
	end
	if org.peripheralperfusion < 0.32 * thresholdMul then
		org.immobilization = math.max(org.immobilization or 0, math.Remap(org.peripheralperfusion, 0.32, 0, 1.5, 7))
	end
	if (org.perfusion < 0.32 * thresholdMul or brainOxygen < 0.35 * thresholdMul) and ((org.hypoxiaTime or 0) > 12 * delayMul or (org.severeHypoxiaTime or 0) > 5 * delayMul) then org.needfake = true end
	if brainOxygen < 0.20 * thresholdMul and ((org.hypoxiaTime or 0) > 20 * delayMul or (org.severeHypoxiaTime or 0) > 8 * delayMul) then org.needotrub = true end

	-- Anoxic injury is likewise cerebral. Tissue O2 can disable the body, but it
	-- cannot damage the brain while measured brain oxygen remains adequate.
	local anoxicBrainSeverity = math.Clamp((0.30 * thresholdMul - brainOxygen) / math.max(0.30 * thresholdMul, 0.01), 0, 1)
	if anoxicBrainSeverity > 0 and (org.severeHypoxiaTime or 0) > 3 * delayMul then
		org.brain = math.min((org.brain or 0) + dt * anoxicBrainSeverity ^ 2 * 0.025, 1)
	end
	local drugNeurotoxicity = math.Clamp(((org.drugRespiratoryDepression or 0) - 0.35) / 0.65, 0, 1)
	if drugNeurotoxicity > 0 then
		org.brain = math.min((org.brain or 0) + dt * drugNeurotoxicity ^ 2 * 0.0015, 1)
	end
end

local advancedBrainAfflictions = {
	"brainFrontal", "brainParietal", "brainTemporal", "brainOccipital",
	"brainHemorrhage", "brainSwelling", "intracranialPressure"
}

local advancedDeliveryVitals = {
	"bodyoxygen", "perfusion", "brainoxygen", "peripheralperfusion",
	"cerebralPerfusion", "perfusionMoveMul", "perfusionGripMul"
}

-- Keep supernatural/automated healing paths in step with the newer brain and
-- oxygen-delivery model. damageRecovery uses the same normalized scale as
-- organ damage; deliveryRecovery controls recovery of the O2/perfusion reserves.
function hg.organism.RegenerateAdvancedAfflictions(org, damageRecovery, deliveryRecovery)
	if not org then return end

	local damage = math.max(tonumber(damageRecovery) or 0, 0)
	local delivery = math.max(tonumber(deliveryRecovery) or damage, 0)

	for _, key in ipairs(advancedBrainAfflictions) do
		org[key] = math.Approach(tonumber(org[key]) or 0, 0, damage)
	end

	-- Bleed rate is a much smaller value than normalized injury severity. Scaling
	-- its recovery prevents even slow regeneration from erasing a fresh bleed in
	-- one tick while still allowing the source to close completely.
	org.brainBleedRate = math.Approach(tonumber(org.brainBleedRate) or 0, 0, damage * 0.01)
	org.internalBleedComplication = math.Approach(tonumber(org.internalBleedComplication) or 0, 0, damage)
	org.neckBrainOxygenPenalty = math.Approach(tonumber(org.neckBrainOxygenPenalty) or 0, 0, damage)
	org.arterialO2Impairment = math.Approach(tonumber(org.arterialO2Impairment) or 0, 0, damage)
	org.throatCutPressureShock = math.Approach(tonumber(org.throatCutPressureShock) or 0, 0, damage)

	for _, key in ipairs(advancedDeliveryVitals) do
		org[key] = math.Approach(tonumber(org[key]) or 1, 1, delivery)
	end

	if istable(org.o2) then
		local oxygenMax = tonumber(org.o2.range) or 30
		org.o2[1] = math.Approach(tonumber(org.o2[1]) or 0, oxygenMax, delivery * oxygenMax)
	end

	org.hypoxia = math.Approach(tonumber(org.hypoxia) or 0, 0, delivery)
	org.hypoxiaTime = math.Approach(tonumber(org.hypoxiaTime) or 0, 0, delivery * 150)
	org.severeHypoxiaTime = math.Approach(tonumber(org.severeHypoxiaTime) or 0, 0, delivery * 150)
	org.systemicIschemiaTime = math.Approach(tonumber(org.systemicIschemiaTime) or 0, 0, delivery * 150)
end

-- Statistics is intentionally an allow-list: it exposes every physiological field
-- shown by cl_statistics without networking the organism's internal functions/caches.
local statisticSyncKeys = {
	"temperature", "tempchanging", "heatbuff", "blindness", "fear", "goodmood", "assimilated", "berserk", "noradrenaline", "fearadd",
	"blood", "bleed", "venousBleed", "arterialBleed", "internalBleedRate", "bloodtype", "hemotransfusionshock", "internalBleed", "internalBleedHeal",
	"arteria", "rarmartery", "larmartery", "rlegartery", "llegartery", "spineartery",
	"llegdislocation", "rlegdislocation", "larmdislocation", "rarmdislocation", "jawdislocation",
	"llegamputated", "rlegamputated", "larmamputated", "rarmamputated",
	"likely_phrase", "alive", "otrub", "incapacitated", "critical", "pain", "painadd", "avgpain", "immobilization",
	"painkiller", "analgesia", "naloxone", "shock", "hurt", "tranquilizer", "wantToVomit", "satiety",
	"adrenaline", "adrenalineStorage", "adrenalineAdd", "anger", "panicattackadd", "panicattack", "stamina",
	"brain", "brainFrontal", "brainParietal", "brainTemporal", "brainOccipital", "brainHemorrhage", "brainBleedRate", "brainSwelling",
	"seizure", "seizureActive", "concussion", "consciousness", "skull", "disorientation", "jaw", "spine1", "spine2", "spine3", "chest", "pelvis",
	"heart", "heartstop", "fibrillation", "arrhythmia", "bloodPressure", "systolic", "diastolic", "myocardialOxygen", "heartStrain",
	"hypertension", "hypotension", "ecgState", "pulse", "heartbeat", "cardiacOutput", "strokeVolume", "hemorrhageCompensation",
	"compensationPulseMultiplier", "compensationHeartRateTarget", "mechanicalPulseCapture", "pulseDeficit", "palpitations", "hypovolemia", "hypovolemicShock",
	"stomach", "liver", "intestines", "thiamine", "vomitInThroat",
	"lungsL", "lungsR", "eyeL", "eyeR", "trachea", "pneumothorax", "hemothorax", "cardiacTamponade", "needle",
	"o2", "bloodO2Cap", "bloodCarryO2Cap", "CO", "lungsfunction", "COregen", "LodgedEntities", "holdingbreath",
	"bodyoxygen", "perfusion", "peripheralperfusion", "cerebralPerfusion", "brainoxygen", "hypoxia", "hypoxiaTime",
	"severeHypoxiaTime", "ischemia", "intracranialPressure", "lleg", "rleg", "larm", "rarm", "superfighter"
}

local function CopyStatisticFields(sendtable, org)
	for _, key in ipairs(statisticSyncKeys) do
		local value = org[key]
		if value ~= nil then sendtable[key] = value end
	end
	-- health belongs to the player entity rather than the organism table.
	if IsValid(org.owner) and org.owner.Health then sendtable.health = org.owner:Health() end
	-- silent berserk is deliberately hidden from clients.
	if org.silentBerserk then sendtable.berserk = 0 end
end

local function send_organism(org, ply)
	if not IsValid(org.owner) then return end
	local sendtable = {}

	sendtable.alive = org.alive
	sendtable.otrub = org.otrub
	sendtable.postMortemDecayStart = org.postMortemDecayStart
	sendtable.postMortemDecayEnd = org.postMortemDecayEnd
	sendtable.owner = org.owner
	sendtable.stamina = org.stamina
	sendtable.immobilization = org.immobilization
	sendtable.adrenaline = org.adrenaline
	sendtable.adrenalineAdd = org.adrenalineAdd
	sendtable.zerlkers = org.zerlkers
	sendtable.zerlkersOverdose = org.zerlkersOverdose
	sendtable.anger = org.anger
	sendtable.analgesia = org.analgesia
	sendtable.lleg = org.lleg
	sendtable.rleg = org.rleg
	sendtable.rarm = org.rarm
	sendtable.larm = org.larm
	sendtable.pelvis = org.pelvis
	sendtable.skull = org.skull
	sendtable.chest = org.chest
	sendtable.internalBleed = org.internalBleed
	sendtable.internalBleedHeal = org.internalBleedHeal
	sendtable.hemothorax = org.hemothorax
	sendtable.cardiacTamponade = org.cardiacTamponade
	sendtable.disorientation = org.disorientation
	sendtable.brain = org.brain
	sendtable.brainFrontal = org.brainFrontal
	sendtable.brainParietal = org.brainParietal
	sendtable.brainTemporal = org.brainTemporal
	sendtable.brainOccipital = org.brainOccipital
	sendtable.brainHemorrhage = org.brainHemorrhage
	sendtable.brainBleedRate = org.brainBleedRate
	sendtable.o2 = org.o2
	sendtable.losing_oxy = org.losing_oxy
	sendtable.CO = org.CO
	sendtable.blood = org.blood
	sendtable.bloodtype = org.bloodtype
	sendtable.bleed = org.bleed
	sendtable.hurt = org.hurt
	sendtable.pain = org.pain
	sendtable.shock = org.shock
	sendtable.pulse = org.pulse
	sendtable.heartbeat = org.heartbeat
	sendtable.bloodPressure = org.bloodPressure
	sendtable.systolic = org.systolic
	sendtable.diastolic = org.diastolic
	sendtable.cardiacOutput = org.cardiacOutput
	sendtable.strokeVolume = org.strokeVolume
	sendtable.arrhythmia = org.arrhythmia
	sendtable.palpitations = org.palpitations
	sendtable.fibrillation = org.fibrillation
	sendtable.myocardialOxygen = org.myocardialOxygen
	sendtable.heartStrain = org.heartStrain
	sendtable.hypertension = org.hypertension
	sendtable.hypotension = org.hypotension
	sendtable.heartstop = org.heartstop
	sendtable.ecgState = org.ecgState
	sendtable.hemorrhageCompensation = org.hemorrhageCompensation
	sendtable.compensationPulseMultiplier = org.compensationPulseMultiplier
	sendtable.compensationHeartRateTarget = org.compensationHeartRateTarget
	sendtable.mechanicalPulseCapture = org.mechanicalPulseCapture
	sendtable.pulseDeficit = org.pulseDeficit
	sendtable.hypovolemia = org.hypovolemia
	sendtable.hypovolemicShock = org.hypovolemicShock
	sendtable.bloodO2Cap = org.bloodO2Cap
	sendtable.bloodCarryO2Cap = org.bloodCarryO2Cap
	sendtable.arterialBleed = org.arterialBleed
	sendtable.venousBleed = org.venousBleed
	sendtable.woundBleedRates = org.woundBleedRates
	sendtable.arterialWoundBleedRates = org.arterialWoundBleedRates
	sendtable.internalBleedRate = org.internalBleedRate
	sendtable.bodyoxygen = org.bodyoxygen
	sendtable.perfusion = org.perfusion
	sendtable.brainoxygen = org.brainoxygen
	sendtable.peripheralperfusion = org.peripheralperfusion
	sendtable.cerebralPerfusion = org.cerebralPerfusion
	sendtable.brainSwelling = org.brainSwelling
	sendtable.intracranialPressure = org.intracranialPressure
	sendtable.hypoxia = org.hypoxia
	sendtable.hypoxiaTime = org.hypoxiaTime
	sendtable.severeHypoxiaTime = org.severeHypoxiaTime
	sendtable.ischemia = org.ischemia
	sendtable.throatcut = org.throatcut
	sendtable.throatCutUntil = org.throatCutUntil
	sendtable.throatCutSeverity = org.throatCutSeverity
	sendtable.timeValue = org.timeValue
	sendtable.holdingbreath = org.holdingbreath
	sendtable.arteria = org.arteria
	sendtable.recoilmul = org.recoilmul
	sendtable.meleespeed = org.meleespeed
	sendtable.legstrength = org.legstrength
	sendtable.armstrength = org.armstrength
	sendtable.breathing = org.breathing
	sendtable.temperature = org.temperature
	sendtable.canmove = org.canmove
	sendtable.fear = org.fear
	sendtable.goodmood = org.goodmood
	sendtable.llegdislocation = org.llegdislocation
	sendtable.rlegdislocation = org.rlegdislocation
	sendtable.rarmdislocation = org.rarmdislocation
	sendtable.larmdislocation = org.larmdislocation
	sendtable.jawdislocation = org.jawdislocation
	sendtable.jaw = org.jaw
	sendtable.teethLost = org.teethLost
	sendtable.llegamputated = org.llegamputated
	sendtable.rlegamputated = org.rlegamputated
	sendtable.rarmamputated = org.rarmamputated
	sendtable.larmamputated = org.larmamputated
	sendtable.headamputated = org.headamputated
	sendtable.lungsfunction = org.lungsfunction
	sendtable.eyeL = org.eyeL
	sendtable.eyeR = org.eyeR
	sendtable.consciousness = org.consciousness
	sendtable.concussion = org.concussion
	sendtable.assimilated = org.assimilated
	sendtable.berserk = org.silentBerserk and 0 or org.berserk
	sendtable.noradrenaline = org.noradrenaline
	sendtable.panicattackadd = org.panicattackadd
	sendtable.panicattack = org.panicattack
	sendtable.seizure = org.seizure
	sendtable.seizureActive = org.seizureActive
	sendtable.seizureStart = org.seizureStart
	sendtable.seizureEnd = org.seizureEnd
	sendtable.damagedBoneName = org.damagedBoneName
	sendtable.damagedBoneSeverity = org.damagedBoneSeverity
	sendtable.damagedBoneTime = org.damagedBoneTime
	sendtable.brokenBoneName = org.brokenBoneName
	sendtable.LodgedEntities = org.LodgedEntities
	sendtable.CantCheckPulse = org.CantCheckPulse
	sendtable.blindness = org.blindness

	sendtable.critical = org.critical
	sendtable.incapacitated = org.incapacitated
	sendtable.deathStateEnd = org.deathStateEnd or 0
	sendtable.berserkActive2 = org.silentBerserk and false or org.berserkActive2
	sendtable.noradrenalineActive = org.noradrenalineActive
	sendtable.aiming_fatigue = org.aiming_fatigue
	sendtable.hand_dominance = org.hand_dominance
	sendtable.permanent_aim_impairment = org.permanent_aim_impairment
	sendtable.panicattackActive = org.panicattackActive

	sendtable.superfighter = org.superfighter
	CopyStatisticFields(sendtable, org)

	net.Start("organism_send")
	net.WriteTable(sendtable)
	net.WriteBool(org.owner.fullsend)
	net.WriteBool(false)
	net.WriteBool(true)
	net.WriteBool(false)
	if IsValid(ply) and ply:IsPlayer() then
		net.Send(ply)
	else
		net.Broadcast()
	end
	if org.owner == ply or not IsValid(ply) or not ply:IsPlayer() then
		org.owner.fullsend = nil
	end
end

local function send_bareinfo(org)
	if not IsValid(org.owner) then return end

	local skullDamage = org.skull or 0
	org.owner:SetNWBool("SkullBrokenPartial", skullDamage >= 0.6 and skullDamage < 1)
	org.owner:SetNWBool("SkullOpen", skullDamage >= 1)
	org.owner:SetNWBool("SkullBrokenFully", skullDamage >= 1)

	local sendtable = {}

	sendtable.alive = org.alive
	sendtable.otrub = org.otrub
	sendtable.postMortemDecayStart = org.postMortemDecayStart
	sendtable.postMortemDecayEnd = org.postMortemDecayEnd
	sendtable.owner = org.owner
	sendtable.bloodtype = org.bloodtype
	sendtable.pulse = org.pulse
	sendtable.blood = org.blood
	sendtable.bleed = org.bleed
	sendtable.hurt = org.hurt
	sendtable.pain = org.pain
	sendtable.shock = org.shock
	sendtable.brain = org.brain
	sendtable.consciousness = org.consciousness
	sendtable.disorientation = org.disorientation
	sendtable.adrenaline = org.adrenaline
	sendtable.adrenalineAdd = org.adrenalineAdd
	sendtable.fear = org.fear
	sendtable.fearadd = org.fearadd
	sendtable.stamina = org.stamina
	sendtable.immobilization = org.immobilization
	sendtable.critical = org.critical
	sendtable.incapacitated = org.incapacitated
	sendtable.deathStateEnd = org.deathStateEnd or 0
	sendtable.holdingbreath = org.holdingbreath
	sendtable.zerlkers = org.zerlkers
	sendtable.zerlkersOverdose = org.zerlkersOverdose
	sendtable.heartbeat = org.heartbeat
	sendtable.bloodPressure = org.bloodPressure
	sendtable.systolic = org.systolic
	sendtable.diastolic = org.diastolic
	sendtable.cardiacOutput = org.cardiacOutput
	sendtable.strokeVolume = org.strokeVolume
	sendtable.arrhythmia = org.arrhythmia
	sendtable.palpitations = org.palpitations
	sendtable.fibrillation = org.fibrillation
	sendtable.myocardialOxygen = org.myocardialOxygen
	sendtable.heartStrain = org.heartStrain
	sendtable.hypertension = org.hypertension
	sendtable.hypotension = org.hypotension
	sendtable.heartstop = org.heartstop
	sendtable.ecgState = org.ecgState
	sendtable.hemorrhageCompensation = org.hemorrhageCompensation
	sendtable.compensationPulseMultiplier = org.compensationPulseMultiplier
	sendtable.compensationHeartRateTarget = org.compensationHeartRateTarget
	sendtable.mechanicalPulseCapture = org.mechanicalPulseCapture
	sendtable.pulseDeficit = org.pulseDeficit
	sendtable.hypovolemia = org.hypovolemia
	sendtable.hypovolemicShock = org.hypovolemicShock
	sendtable.bloodO2Cap = org.bloodO2Cap
	sendtable.bloodCarryO2Cap = org.bloodCarryO2Cap
	sendtable.arterialBleed = org.arterialBleed
	sendtable.venousBleed = org.venousBleed
	sendtable.woundBleedRates = org.woundBleedRates
	sendtable.arterialWoundBleedRates = org.arterialWoundBleedRates
	sendtable.internalBleedRate = org.internalBleedRate
	sendtable.hemothorax = org.hemothorax
	sendtable.cardiacTamponade = org.cardiacTamponade
	sendtable.bodyoxygen = org.bodyoxygen
	sendtable.perfusion = org.perfusion
	sendtable.brainoxygen = org.brainoxygen
	sendtable.peripheralperfusion = org.peripheralperfusion
	sendtable.cerebralPerfusion = org.cerebralPerfusion
	sendtable.brainSwelling = org.brainSwelling
	sendtable.intracranialPressure = org.intracranialPressure
	sendtable.hypoxia = org.hypoxia
	sendtable.hypoxiaTime = org.hypoxiaTime
	sendtable.severeHypoxiaTime = org.severeHypoxiaTime
	sendtable.ischemia = org.ischemia
	sendtable.throatcut = org.throatcut
	sendtable.throatCutUntil = org.throatCutUntil
	sendtable.throatCutSeverity = org.throatCutSeverity
	sendtable.temperature = org.temperature
	sendtable.analgesia = org.analgesia
	sendtable.o2 = org.o2
	sendtable.losing_oxy = org.losing_oxy
	sendtable.timeValue = org.timeValue
	sendtable.superfighter = org.superfighter
	sendtable.lungsfunction = org.lungsfunction
	sendtable.eyeL = org.eyeL
	sendtable.eyeR = org.eyeR
	sendtable.lleg = org.lleg
	sendtable.rleg = org.rleg
	sendtable.rarm = org.rarm
	sendtable.larm = org.larm
	sendtable.llegdislocation = org.llegdislocation
	sendtable.rlegdislocation = org.rlegdislocation
	sendtable.rarmdislocation = org.rarmdislocation
	sendtable.larmdislocation = org.larmdislocation
	sendtable.jawdislocation = org.jawdislocation
	sendtable.jaw = org.jaw
	sendtable.teethLost = org.teethLost
	sendtable.llegamputated = org.llegamputated
	sendtable.rlegamputated = org.rlegamputated
	sendtable.rarmamputated = org.rarmamputated
	sendtable.larmamputated = org.larmamputated
	sendtable.headamputated = org.headamputated
	sendtable.LodgedEntities = org.LodgedEntities
	sendtable.berserkActive2 = org.silentBerserk and false or org.berserkActive2
	sendtable.CantCheckPulse = org.CantCheckPulse
	sendtable.noradrenalineActive = org.noradrenalineActive
	sendtable.panicattackadd = org.panicattackadd
	sendtable.panicattack = org.panicattack
	sendtable.seizure = org.seizure
	sendtable.seizureActive = org.seizureActive
	sendtable.seizureStart = org.seizureStart
	sendtable.seizureEnd = org.seizureEnd
	sendtable.damagedBoneName = org.damagedBoneName
	sendtable.damagedBoneSeverity = org.damagedBoneSeverity
	sendtable.damagedBoneTime = org.damagedBoneTime
	sendtable.brokenBoneName = org.brokenBoneName
	sendtable.brainFrontal = org.brainFrontal
	sendtable.brainParietal = org.brainParietal
	sendtable.brainTemporal = org.brainTemporal
	sendtable.brainOccipital = org.brainOccipital
	sendtable.brainHemorrhage = org.brainHemorrhage
	sendtable.brainBleedRate = org.brainBleedRate
	CopyStatisticFields(sendtable, org)

	local rf = RecipientFilter()
	--rf:AddAllPlayers()
	rf:AddPVS(org.owner:GetPos())
	if org.owner:IsPlayer() then rf:RemovePlayer(org.owner) end

	net.Start("organism_send")
	net.WriteTable(sendtable)
	net.WriteBool(org.owner.fullsend)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.Send(rf)
end

hg.send_organism = send_organism
hg.send_bareinfo = send_bareinfo

local META = FindMetaTable("Player")
function META:IsBerserk()
	if !IsValid(self) then return false end
	if self:IsPlayer() and not self:Alive() then return false end

	local org = self.organism
	return org.berserkActive2 or false
end

function META:IsStimulated()
	if !IsValid(self) then return false end
	if self:IsPlayer() and not self:Alive() then return false end

	local org = self.organism
	return org.noradrenalineActive or false
end

local META2 = FindMetaTable("Entity")
function META2:IsBerserk()
	return false
end

function META2:IsStimulated()
	return false
end

function hg.organism.AddPanicAttack(org, amount, silent, chanceMultiplier)
	if not org then return 0 end
	if not hg_panic:GetBool() then
		org.panicattackadd = 0
		org.panicattack = 0
		org.panicattackActive = false
		return 0
	end
	if not isnumber(amount) or amount <= 0 then return org.panicattackadd or 0 end
	if (org.berserk or 0) > 0 then return org.panicattackadd or 0 end
	local adrenalineRisk = math.Clamp(((org.adrenaline or 0) + (org.adrenalineAdd or 0) - 1.5) / 3, 0, 0.65)
	local analgesiaRisk = math.Clamp(((org.analgesia or 0) + (org.analgesiaAdd or 0) - 0.2) / 2.8, 0, 1) * 0.2
	local vulnerability = 1 + adrenalineRisk + analgesiaRisk
	local eventScale = math.max(tonumber(chanceMultiplier) or 1, 0)

	-- Every witnessed-death or corpse-exposure event advances the live panic meter.
	org.panicattackadd = math.Clamp((org.panicattackadd or 0) + amount * panicattack_gain_mul * eventScale * math.min(vulnerability, 1.75), 0, 1)

	if silent and IsValid(org.owner) and org.owner:IsPlayer() and (org.owner.lastKillTime or 0) > CurTime() - 4 then
		return org.panicattackadd or 0
	end
	if IsValid(org.owner) and org.owner:IsPlayer() then
		org.owner:PrintMessage(HUD_PRINTCONSOLE, "[PANIC:ADD] +" .. amount)
	end
	if math.random(panicattack_gain_chance) != 1 then return org.panicattackadd or 0 end
	org.panicattackadd = math.Clamp((org.panicattackadd or 0) + amount * panicattack_gain_mul, 0, 1)
	return org.panicattackadd
end

local function getMannitolSeizureStrength(org)
	return math.Clamp((org.mannitol or 0) / 4, 0, 1)
end

function hg.organism.AddSeizure(org, amount)
	if not org then return 0 end
	if (org.seizureSuppressedUntil or 0) > CurTime() then
		org.seizure = 0
		return 0
	end
	if not isnumber(amount) or amount <= 0 then return org.seizure or 0 end

	local mannitolStrength = getMannitolSeizureStrength(org)
	local gainMultiplier = 1 - mannitolStrength * seizure_mannitol_gain_reduction
	org.seizure = math.Clamp((org.seizure or 0) + amount * gainMultiplier, 0, 1)

	return org.seizure
end

function hg.organism.MarkDamagedBone(org, boneName, severity)
	if not org or not isstring(boneName) then return end

	org.damagedBoneName = boneName
	org.damagedBoneSeverity = math.Clamp(severity or 0.5, 0, 1)
	org.damagedBoneTime = CurTime()
	if IsValid(org.owner) then org.owner.fullsend = true end
end

function hg.organism.MarkBrokenBone(org, boneName)
	if not org or not isstring(boneName) then return end

	org.brokenBoneName = boneName
	if IsValid(org.owner) then org.owner.fullsend = true end
end

local function reduceSeizure(org, amount)
	if not org or not isnumber(amount) or amount <= 0 then return org and org.seizure or 0 end

	-- Mannitol clears seizure risk faster, but does not cut short an active seizure.
	if not org.seizureActive then
		amount = amount * (1 + getMannitolSeizureStrength(org) * seizure_mannitol_recovery_bonus)
	end
	org.seizure = math.max((org.seizure or 0) - amount, 0)

	return org.seizure
end

local function getSeizureLobeDamage(org)
	return math.Clamp((org.brainFrontal or 0) + (org.brainParietal or 0) + (org.brainTemporal or 0) + (org.brainOccipital or 0), 0, 1)
end

local function apply_seizure_pose(rag, org, time)
	if hg.applySeizurePostureToRagdoll then hg.applySeizurePostureToRagdoll(rag, org, 1) end
end

local function stop_seizure(owner, org)
	local wasActive = org.seizureActive
	org.seizure = 0
	org.seizureActive = false
	org.seizureStart = 0
	org.seizureEnd = 0
	org.nextSeizureSpasm = 0

	if wasActive and IsValid(owner) and owner:IsPlayer() and owner:Alive() then
		owner.fullsend = true
		send_organism(org, owner)
	end
end

function hg.organism.SuppressSeizure(org, duration)
	if not org then return 0 end

	local time = CurTime()
	org.seizureSuppressedUntil = math.max(org.seizureSuppressedUntil or 0, time + math.max(tonumber(duration) or 0, 0))
	stop_seizure(org.owner, org)

	return org.seizureSuppressedUntil
end

local function start_seizure(owner, org)
	if org.seizureActive or not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end

	local time = CurTime()
	local severity = math.Clamp(math.max(org.brain or 0, getSeizureLobeDamage(org)), 0, 1)
	org.seizure = 1
	org.seizureActive = true
	org.seizureStart = time
	-- Minor damage produces a short seizure; severe brain trauma can sustain one
	-- for up to half a minute, but every episode ends on its own.
	org.seizureEnd = time + seizure_min_duration + (seizure_max_duration - seizure_min_duration) * severity
	org.nextSeizureSpasm = time
	org.lastSeizureInjuryTime = time
	owner.fullsend = true
	send_organism(org, owner)
end

local function is_panic_corpse(ent)
	if not IsValid(ent) then return false end
	if ent:IsPlayer() then
		return not ent:Alive() and not IsValid(ent:GetNWEntity("RagdollDeath", NULL))
	end
	if ent:IsNPC() then return ent:Health() <= 0 end
	if not ent:IsRagdoll() then return false end
	local owner = hg.RagdollOwner and hg.RagdollOwner(ent)
	return not IsValid(owner) or not owner:IsPlayer() or not owner:Alive()
end

local function get_corpse_killer(ent)
	if not IsValid(ent) then return nil end
	if IsValid(ent._panicDeathAttacker) then return ent._panicDeathAttacker end
	local owner = hg.RagdollOwner and hg.RagdollOwner(ent)
	return IsValid(owner) and owner._panicDeathAttacker or nil
end

local function can_see_panic_corpse(owner, corpse)
	local corpsePos = corpse:WorldSpaceCenter()
	local character = hg.GetCurrentCharacter(owner) or owner
	local tr = util.TraceLine({
		start = owner:EyePos(),
		endpos = corpsePos,
		filter = {owner, character, corpse},
		mask = MASK_SHOT
	})
	return not tr.Hit
end

hook.Add("Org Think", "PanicAttackCorpseExposure", function(owner, org)
	if not hg_panic:GetBool() then return end
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	if not org or org.otrub then return end
	if (org._panicNextCorpseCheck or 0) > CurTime() then return end
	org._panicNextCorpseCheck = CurTime() + 1

	org._panicCorpseExposure = org._panicCorpseExposure or {}

	for _, corpse in ipairs(ents.FindInSphere(owner:GetPos(), panicattack_corpse_radius)) do
		local corpseKiller = get_corpse_killer(corpse)
		if corpse ~= owner and is_panic_corpse(corpse) and corpseKiller ~= owner and can_see_panic_corpse(owner, corpse) then
			local exposure = org._panicCorpseExposure[corpse] or 0
			if exposure < panicattack_corpse_total then
				-- A body has a finite impact. Once this specific corpse has registered,
				-- looking at it again cannot keep feeding panic or its adrenaline response.
				local before = org.panicattackadd or 0
				hg.organism.AddPanicAttack(org, math.min(panicattack_corpse_tick, panicattack_corpse_total - exposure), true)
				local gained = math.max((org.panicattackadd or 0) - before, 0)
				org._panicCorpseExposure[corpse] = math.min(exposure + gained, panicattack_corpse_total)
			end
		end
	end
end)

hook.Add("EntityFireBullets", "GunfightNaturalAdrenaline", function(shooter)
	if not IsValid(shooter) or not shooter:IsPlayer() or not shooter:Alive() then return end
	local org = shooter.organism
	if not org or org.otrub then return end
	if (org._gunfightAdrenalineNext or 0) > CurTime() then return end

	-- Sustained gunfire creates a small combat response even before a shot lands;
	-- actual hits add the stronger attacker/victim response in sv_input.
	org._gunfightAdrenalineNext = CurTime() + gunfight_adrenaline_delay
	local adrenalineAmount = (org.adrenaline or 0) < gunfight_adrenaline_cap and 0.3 or 0
	if hg.organism.RileAnger then
		hg.organism.RileAnger(org, 0.05, adrenalineAmount)
	elseif adrenalineAmount > 0 then
		shooter:AddNaturalAdrenaline(0.3)
	end
end)

hook.Add("Org Think", "PanicAttackNearbyFire", function(owner, org)
	if not hg_panic:GetBool() then return end
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	if not org or org.otrub then return end
	if (org._panicNextFireCheck or 0) > CurTime() then return end
	org._panicNextFireCheck = CurTime() + panicattack_fire_check_delay

	local closest
	for _, ent in ipairs(ents.FindInSphere(owner:GetPos(), panicattack_fire_radius)) do
		if not IsValid(ent) or ent == owner then continue end
		if ent:GetClass() ~= "env_fire" and ent:GetClass() ~= "vfire" and not ent:IsOnFire() then continue end

		local dist = owner:GetPos():Distance(ent:GetPos())
		if not closest or dist < closest then closest = dist end
	end

	if closest then
		-- Fire is a sustained threat: this tiny per-second gain only overtakes
		-- normal panic decay when the player stays close to it for a while.
		local falloff = math.Clamp(1 - closest / panicattack_fire_radius, 0, 1)
		hg.organism.AddPanicAttack(org, 0.02 + falloff * 0.04, true)
	end
end)

hook.Add("EntityTakeDamage", "PanicAttackCombatTrauma", function(target, dmgInfo)
	if not hg_panic:GetBool() then return end
	if not IsValid(target) or not target:IsPlayer() or not target:Alive() then return end

	local org = target.organism
	if not org or org.otrub or (org.berserk or 0) > 0 then return end

	local damage = math.max(dmgInfo:GetDamage(), 0)
	if damage <= 0 then return end

	-- Direct trauma is the most reliable panic trigger. Gunshots and hostile
	-- attacks build it quickly, while blasts and fire add their own shock.
	local amount = math.Clamp(damage / 110, 0.015, 0.22)
	if dmgInfo:IsDamageType(DMG_BULLET) or dmgInfo:IsDamageType(DMG_BUCKSHOT) then
		amount = amount * 1.25
	end
	if dmgInfo:IsExplosionDamage() then
		amount = amount + 0.24
	end
	if dmgInfo:IsDamageType(DMG_BURN) or dmgInfo:IsDamageType(DMG_SLOWBURN) then
		amount = amount + 0.09
	end

	local attacker = dmgInfo:GetAttacker()
	if IsValid(attacker) and attacker ~= target and (attacker:IsPlayer() or attacker:IsNPC() or attacker:IsNextBot()) then
		amount = amount + 0.04
	end
	if damage >= 35 then amount = amount + 0.12 end

	hg.organism.AddPanicAttack(org, math.min(amount, 0.55), true)
end)

local function resolve_panic_attacker(victim, attacker)
	if IsValid(attacker) then
		if attacker:IsPlayer() then
			return attacker
		end

		local owner = attacker.GetOwner and attacker:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then
			return owner
		end
	end

	if IsValid(victim) and victim.GetPhysicsAttacker then
		local physicsAttacker = victim:GetPhysicsAttacker()
		if IsValid(physicsAttacker) and physicsAttacker:IsPlayer() then
			return physicsAttacker
		end
	end
end

local function panic_witness_event(victim, attacker, amount, radius, chanceMultiplier)
	if not hg_panic:GetBool() then return end
	if not IsValid(victim) then return end
	if not isnumber(amount) or amount <= 0 then return end

	local victimEnt = hg.GetCurrentCharacter(victim) or victim
	local victimPos = victimEnt.WorldSpaceCenter and victimEnt:WorldSpaceCenter() or victimEnt:GetPos()

	for _, watcher in ipairs(ents.FindInSphere(victimPos, radius)) do
		if not watcher:IsPlayer() or watcher == victim then continue end
		if not watcher:Alive() or not watcher.organism or watcher.organism.otrub then continue end
		if IsValid(attacker) and watcher == attacker then continue end

		if IsValid(victim.killedBy) and watcher == victim.killedBy then continue end
		local watcherEnt = hg.GetCurrentCharacter(watcher) or watcher
		local tr = util.TraceLine({
			start = watcher:EyePos(),
			endpos = victimPos,
			filter = {watcher, watcherEnt, victim, victimEnt, attacker},
			mask = MASK_SHOT
		})

		if tr.Hit then continue end

		hg.organism.AddPanicAttack(watcher.organism, amount, true, chanceMultiplier)
		watcher:PrintMessage(HUD_PRINTCONSOLE, "[PANIC:WITNESS] +" .. amount .. " attacker=" .. (IsValid(attacker) and attacker:Nick() or "NIL") .. " victim=" .. (IsValid(victim) and victim:Nick() or "NIL") .. " killedBy=" .. (IsValid(victim.killedBy) and victim.killedBy:Nick() or "NIL"))
		hg.organism.AddPanicAttack(watcher.organism, amount, true)
	end
end

hook.Add("EntityTakeDamage", "PanicTrackLastAttacker", function(target, dmgInfo)
	local owner = target:IsPlayer() and target or (IsValid(target.ply) and target.ply) or nil
	if not IsValid(owner) or not owner:IsPlayer() then return end
	local att = resolve_panic_attacker(owner, dmgInfo:GetAttacker())
	if IsValid(att) then
		owner.lastPanicAttacker = att
		owner.lastPanicAttackTime = CurTime()
	end
end)
local numerical = {
	"One.",
	"Two.",
	"Three.",
	"Four.",
	"Five.",
	"Six.",
	"Seven.",
	"Eight.",
	"Nine.",
	"Ten.",
	"Eleven.",
	"Twelve.",
	"Thirteen.",
	"Fourteen.",
	"Fifteen.",
	"Sixteen.",
	"Seventeen.",
	"Eighteen.",
	"Nineteen.",
	"Twenty."
}

hook.Add("HomigradDamage", "Berserk", function(ply, dmgInfo, hitgroup, ent)
	local attacker, victim = dmgInfo:GetAttacker(), ply
	if !attacker or !IsValid(attacker) or (IsValid(attacker) and !attacker:IsPlayer()) then
		attacker = ply:GetPhysicsAttacker()
	end

	if not IsValid(attacker) or not attacker:IsPlayer() then return end
	if not IsValid(victim) or not victim:IsPlayer() then return end
	if attacker == victim then return end
	if !attacker:IsBerserk() then return end

	timer.Simple(0, function()
		if IsValid(attacker) and IsValid(victim) and not victim:Alive() then
			attacker.BerserkKills = (attacker.BerserkKills or 0) + 1
			attacker:NotifyBerserk(numerical[attacker.BerserkKills] or (attacker.BerserkKills .. "."))

			attacker.organism.berserk = attacker.organism.berserk + 0.5
		end
	end)
end)

-- One-handed behavior: wrist damage from heavy calibers and reduced control
hook.Add("EntityFireBullets", "OneHandedBehavior", function(ent, bulletData)
	if not IsValid(ent) or not ent:IsPlayer() then return end
	local org = ent.organism
	if not org or org.otrub then return end
	if string.lower(ent.PlayerClassName or "") == "slugcat" then return end

	-- Get weapon info
	local wep = ent:GetActiveWeapon()
	if not IsValid(wep) then return end
	if wep:GetClass() == "weapon_slugcat" then return end

	-- Determine if caliber is heavy based on ammo type
	local ammoType = wep:GetPrimaryAmmoType()
	local ammoData = hg.ammotypes[game.GetAmmoName(ammoType)]
	local isHeavyCaliber = false
	local caliberWeight = 0

	if ammoData and ammoData.BulletSettings then
		local bullet = ammoData.BulletSettings
		-- Heavy caliber criteria: high force, mass, or diameter
		local force = bullet.Force or 0
		local mass = bullet.Mass or 0
		local diameter = bullet.Diameter or 0

		-- Calculate caliber weight score
		caliberWeight = (force / 180) + (mass / 18) + (diameter / 14)
		if wep:GetClass() == "weapon_ptrd" or wep.Base == "weapon_ptrd" then
			caliberWeight = caliberWeight * 1.35
		end
		isHeavyCaliber = caliberWeight > 0.8
	end

	-- Check if left arm is damaged or amputated (one-handed condition)
	local leftArmDamaged = (org.larm and org.larm >= 1) or org.larmamputated or (org.larmdislocation or org.larmdislocated)
	local isPostureOneHanded = IsValid(wep) and wep.TwoHanded == false
	if not leftArmDamaged and not isPostureOneHanded then return end

	-- Posture-only one-handing (healthy left arm, weapon set TwoHanded = false): only penalize for heavy calibers
	if not leftArmDamaged and isPostureOneHanded then
		if not isHeavyCaliber then return end
		if not org.rarmamputated then
			local wristDamage = caliberWeight * 0.10
			org.rarm = math.min((org.rarm or 0) + wristDamage, 1)
		end
		org.painadd = (org.painadd or 0) + caliberWeight * 7
		return
	end

	-- Apply wrist damage for heavy calibers when one-handed
	if isHeavyCaliber then
		local wristDamage = caliberWeight * 0.15
		-- Damage the right arm (the only usable arm)
		if not org.rarmamputated then
			org.rarm = math.min((org.rarm or 0) + wristDamage, 1)
		end
		-- Add pain
		org.painadd = (org.painadd or 0) + wristDamage * 10
	end

	-- Chance to drop weapon based on caliber weight and arm damage
	if not org.rarmamputated then
		local armDamage = org.rarm or 0
		local dropChance = caliberWeight * 0.1 + armDamage * 0.15
		if math.random() < dropChance then
			ent:DropWeapon(wep)
			if ent:HasWeapon("weapon_hands_sh") then ent:SelectWeapon("weapon_hands_sh") end
		end
	end

	-- Apply reduced control for one-handed usage
	-- Increase recoil multiplier based on caliber weight and one-handed status.
	-- Keep it bounded so repeated shots do not permanently multiply recoil.
	local oneHandedPenalty = math.Clamp(1 + caliberWeight * 0.35, 1, 2.35)
	org.recoilmul = math.max(org.recoilmul or 1, oneHandedPenalty)

	-- Reduce arm strength for one-handed usage
	local armStrengthPenalty = math.Clamp(1 - caliberWeight * 0.12, 0.35, 1)
	org.armstrength = math.min(org.armstrength or 1, armStrengthPenalty)

	-- Apply worse control for one-handed postures (if weapon is two-handed but being used one-handed)
	local isTwoHandedWeapon = wep.TwoHanded ~= false
	if isTwoHandedWeapon then
		-- Additional penalty for using two-handed weapons one-handed
		org.recoilmul = math.max(org.recoilmul, 1.35)
		org.armstrength = math.min(org.armstrength, 0.7)
	end
end)


hook.Add("HomigradDamage", "PanicAttackDamage", function(ply, dmgInfo)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	if not ply.organism then return end
	local amount = math.Clamp(dmgInfo:GetDamage() * panicattack_damage_scale + (dmgInfo:IsDamageType(DMG_BLAST) and 0.08 or 0), 0.03, 0.55)
	local attacker = resolve_panic_attacker(ply, dmgInfo:GetAttacker())
	if not IsValid(attacker) and IsValid(ply.lastPanicAttacker) and (ply.lastPanicAttackTime or 0) > CurTime() - 30 then
		attacker = ply.lastPanicAttacker
	end
	ply:PrintMessage(HUD_PRINTCONSOLE, "[PANIC:DAMAGE] +" .. amount .. " attacker=" .. (IsValid(attacker) and attacker:Nick() or "NIL"))
	hg.organism.AddPanicAttack(ply.organism, amount)
	if dmgInfo:GetDamage() <= 0 and not dmgInfo:IsDamageType(DMG_BLAST) then return end
	panic_witness_event(ply, attacker, math.Clamp(amount * 0.75, 0.04, 0.2), panicattack_witness_radius)
end)
local function stopNeckSlitSound(owner, org)
	if not org or not org.neckslitSoundName then return end
	if IsValid(org.neckslitSoundEnt) then org.neckslitSoundEnt:StopSound(org.neckslitSoundName) end
	if IsValid(owner) then owner:StopSound(org.neckslitSoundName) end
	org.neckslitSoundName = nil
	org.neckslitSoundEnt = nil
end

hook.Add("PlayerDeath", "HG_StopNeckSlitSound", function(ply)
	stopNeckSlitSound(ply, ply.organism)
end)

hook.Add("Org Think", "Main", function(owner, org, timeValue)
	if not IsValid(owner) then
		hg.organism.list[owner] = nil
		return
	end

	local isPly = owner:IsPlayer()
	local alive = owner:Alive()
	if isPly and not alive then return end
	local curTime = CurTime()

	org.isPly = isPly

	if isPly or org.fakePlayer then
		if not org.fakePlayer then
			org.alive = alive
		end
	else
		org.alive = false
	end

	org.needotrub = false
	org.needfake = false
	if isPly then
		org.ownerFake = org.FakeRagdoll and true
	else
		org.ownerFake = false
	end

	org.timeValue = timeValue
	org.incapacitated = false
	org.critical = false

	-- Two concurrent Zerlkers doses poison the nervous system. The overdose load
	-- lingers after the concentration starts falling so the second dose has a
	-- real physiological consequence instead of disappearing after one tick.
	local zerlkers = math.max(org.zerlkers or 0, 0)
	if zerlkers >= 2 then
		org.zerlkersOverdose = math.max(org.zerlkersOverdose or 0, math.Clamp(zerlkers - 1, 1, 3))
	end

	local zerlkersOverdose = math.Clamp(org.zerlkersOverdose or 0, 0, 1)
	if zerlkersOverdose > 0 then
		org.disorientation = math.max(org.disorientation or 0, 2.5 + zerlkersOverdose * 3.5)
		org.immobilization = math.max(org.immobilization or 0, zerlkersOverdose * 5)
		org.brain = math.min((org.brain or 0) + timeValue * (0.004 + zerlkersOverdose * 0.008), 1)
	end
	org.zerlkersOverdose = math.Approach(org.zerlkersOverdose or 0, 0, timeValue / 45)

	-- Aiming fatigue tracking (affects recoil multipliers)
	if isPly then
		local wep = owner:GetActiveWeapon()
		local isAiming = IsValid(wep) and wep.IsZoom and wep:IsZoom()

		if isAiming then
			if not org.aiming_start_time then
				org.aiming_start_time = CurTime()
			end
			local duration = CurTime() - org.aiming_start_time
			if duration >= 0.5 then
				-- Define debuff variables (include amputated arms)
				local rarm_broken_debuff = (org.rarm and org.rarm >= 1) or org.rarmamputated
				local larm_broken_debuff = (org.larm and org.larm >= 1) or org.larmamputated
				-- Define pain variables (exclude amputated arms)
				local rarm_broken_pain = (org.rarm and org.rarm >= 1) and not org.rarmamputated
				local larm_broken_pain = (org.larm and org.larm >= 1) and not org.larmamputated
				local rarm_dislocated = org.rarmdislocated or org.rarmdislocation
				local larm_dislocated = org.larmdislocated or org.larmdislocation

				-- Check for left hand mitigation: working left hand + damaged right hand
				-- Mitigation applies unless one-handing or left arm is damaged
				local leftHandHealthy = not org.larmamputated and not (org.larm and org.larm >= 1) and not (org.larmdislocation or org.larmdislocated)
				local rightHandDamaged = (org.rarm and org.rarm >= 1) or (org.rarmdislocation or org.rarmdislocated) or org.rarmamputated
				local isOneHanding = IsValid(wep) and wep.TwoHanded == false
				
				local debuffMitigation = 1
				if leftHandHealthy and rightHandDamaged and not isOneHanding then
					debuffMitigation = 0.6 -- Slightly mitigate debuffs (40% reduction)
				end

				-- Fatigue kicks in faster the longer you hold the aim.
				local duration_ramp = 1 + math.Clamp(duration - 0.5, 0, 12) * 0.18

				-- Stance affects fatigue: high ready (3) / low ready (4) are steadier
				-- (slower fatigue); any other stance fatigues slightly faster.
				local posture = owner.posture or 0
				local posture_fatigue_mult = (posture == 3 or posture == 4) and 0.7 or 1.25

				local fatigue_rate = timeValue * 0.7 * duration_ramp * posture_fatigue_mult

				org.aiming_fatigue = math.min((org.aiming_fatigue or 0) + fatigue_rate, 10)

				-- Increase aiming fatigue accumulation for broken/amputated arms
				if rarm_broken_debuff or larm_broken_debuff then
					local fatigue_multiplier = 1.5 * debuffMitigation
					if org.rarmamputated or org.larmamputated then
						fatigue_multiplier = 2.0 * debuffMitigation -- More severe for amputated arms
					end
					org.aiming_fatigue = math.min((org.aiming_fatigue or 0) + fatigue_rate * fatigue_multiplier, 10)
				end

				local pain_threshold = 4.0
				if rarm_broken_pain then
					pain_threshold = 1.5
				elseif rarm_dislocated then
					pain_threshold = 2.5
				end

				if duration > pain_threshold then
					local pain_rate = timeValue * 1.5
					if rarm_broken_pain then
						pain_rate = pain_rate * 3.0 * debuffMitigation
					elseif rarm_dislocated then
						pain_rate = pain_rate * 1.8 * debuffMitigation
					end

					org.painadd = org.painadd + pain_rate
				end
			end
		else
			org.aiming_start_time = nil
			org.aiming_fatigue = math.max((org.aiming_fatigue or 0) - timeValue * 0.3, 0)
		end
	end

	if isPly then
		module.stamina[2](owner, org, timeValue)
	end

	local debugEyes = debug_destroy_eyes:GetInt()
	if debugEyes ~= (org.debugEyesMode or 0) then
		if debugEyes == 1 or debugEyes == 3 then
			org.eyeL = 1
		end
		if debugEyes == 2 or debugEyes == 3 then
			org.eyeR = 1
		end
		org.debugEyesMode = debugEyes
	end

	-- Latch a destroyed eye until its damage is fully healed. Passive recovery
	-- dipping from 1 to 0.99 must not make the blind side vanish immediately.
	if (org.eyeL or 0) >= 1 then org.eyeLDestroyed = true end
	if (org.eyeR or 0) >= 1 then org.eyeRDestroyed = true end
	if (org.eyeL or 0) <= 0 then org.eyeLDestroyed = nil end
	if (org.eyeR or 0) <= 0 then org.eyeRDestroyed = nil end

	local leftEyeBlind = org.eyeLDestroyed == true
	local rightEyeBlind = org.eyeRDestroyed == true
	if not leftEyeBlind and not rightEyeBlind then
		org.blindness = nil
	elseif leftEyeBlind and not rightEyeBlind then
		org.blindness = 2
	elseif rightEyeBlind and not leftEyeBlind then
		org.blindness = 1
	else
		org.blindness = 0
	end

	if module.liver and module.liver[2] then module.liver[2](owner, org, timeValue) end

	--module.blood[3](owner,org,timeValue)--arteria
	module.blood[2](owner, org, timeValue)
	local neckslit = false
	if org.arterialwounds then
		for i, wound in pairs(org.arterialwounds) do
			if wound[7] == "arteria" and wound[1] > 0 then
				neckslit = true
				break
			end
		end
	end
	org.neckslit = neckslit

	if org.neckslit and not org.otrub then
		org.needfake = true
		if not org.neckslitDeadline then
			org.neckslitDeadline = CurTime() + 15
			org.neckslitWarned = nil
		elseif org.neckslitWarned ~= true and org.neckslitDeadline - CurTime() <= 4 then
			org.neckslitWarned = true
			if isPly and owner:Alive() then
				owner:Notify("I'm fading... someone save me!", true, "neckslit_save", 0)
			end
		end
	elseif org.neckslitDeadline then
		org.neckslitDeadline = nil
		org.neckslitWarned = nil
	end

	if isPly and (org.lleg == 1 or org.rleg == 1) and not org.NoKnockdown then
		if (org.legBreakFallNext or 0) < CurTime() then
			org.legBreakFallNext = CurTime() + 0.5
			local spd = owner:GetVelocity():Length()
			if not IsValid(owner.FakeRagdoll) and spd > 200 and math.random(100) < math.Clamp((spd - 200) / 4, 2, 30) then
				org.needfake = true
			end
		end
	end

	module.pain[2](owner, org, timeValue)
	if isPly then
		module.pain[2](owner, org, timeValue)
		module.metabolism[2](owner, org, timeValue)
		module.concussion[2](owner, org, timeValue)
		module.random_events[2](owner, org, timeValue)
		module.goodmood[2](owner, org, timeValue)
		if module.teeth and module.teeth[2] then module.teeth[2](owner, org, timeValue) end
		if module.medical_system and module.medical_system[2] then module.medical_system[2](owner, org, timeValue) end
	end



	module.pulse[2](owner, org, timeValue)
	-- Lungs/tissue delivery must see this tick's blood volume and cardiac output.
	if isPly or org.fakePlayer then
		module.lungs[2](owner, org, timeValue)
	end
	-- Derive systemic/brain delivery only after blood, pump output and tissue O2
	-- have all been updated for the same tick.
	hg.organism.UpdatePerfusion(owner, org, timeValue)
	if not org.alive then hg.organism.UpdatePostMortemVitals(org) end
	if module.trauma_combo and module.trauma_combo[2] then module.trauma_combo[2](owner, org, timeValue) end

	if org.owner.PlayerClassName == "furry" then
		org.assimilated = 0
	end

	if org.owner.PlayerClassName != "furry" and org.furryinfected then
		org.assimilated = math.Approach(org.assimilated, 1, timeValue / 30 * org.pulse / 70)

		if org.assimilated == 1 then
			hg.Furrify(org.owner)

			org.furryinfected = false
		end
	else
		if (org.lightstun - curTime) <= 0 then
			org.assimilated = math.Approach(org.assimilated, 0, (timeValue / 60 * org.pulse / 70) * 6)
		end
	end

	if org.assimilated == 1 then
		org.assimilated = 0
		org.owner:SetPlayerClass("furry")
	end

	org.berserk = math.Approach(org.berserk, 0, timeValue / 60)
	org.noradrenaline = math.Approach(org.noradrenaline, 0, timeValue / 45)
	org.zerlkers = math.Approach(org.zerlkers or 0, 0, timeValue / 120)
	local oldPanicAttack = org.panicattack or 0
	if not hg_panic:GetBool() then
		org.panicattackadd = 0
		org.panicattack = 0
		org.panicattackActive = false
	elseif org.berserk > 0 then
		-- Berserk suppresses both new panic triggers and any attack already in progress.
		org.panicattackadd = 0
		org.panicattack = 0
	else
		org.panicattackadd = math.Approach(org.panicattackadd or 0, 0, timeValue / panicattack_add_decay_time)
		org.panicattack = math.Approach(oldPanicAttack, org.panicattackadd or 0, timeValue / ((org.panicattackadd or 0) > oldPanicAttack and panicattack_rise_time or panicattack_decay_time))
	end
	local oldSeizureBrain = org.lastSeizureBrain or (org.brain or 0)
	local lobeDamage = getSeizureLobeDamage(org)
	local oldSeizureLobeDamage = org.lastSeizureLobeDamage or lobeDamage
	local oldSeizureTemperature = org.lastSeizureTemperature or (org.temperature or 36.7)
	org.tranexamic_acid = math.Approach(org.tranexamic_acid, 0, timeValue / 120) -- Tranexamic acid decays over 2 minutes

	if org.berserk > 0 and !org.berserkActive then
		org.berserkActive = true

		owner.lastBerserkLaughSoundCD = curTime + 5

		timer.Simple(3.95, function()
			org.berserkActive2 = true
		end)
	elseif org.berserk <= 0 then
		org.berserkActive = false
		org.berserkActive2 = false
		owner.BerserkKills = nil
	end

	if org.noradrenaline > 0 then
		org.noradrenalineActive = true
		org.noradrenalineEndTime = nil
	elseif org.noradrenaline <= 0 then
		if org.noradrenalineActive then
			org.noradrenalineEndTime = CurTime()
		end
		org.noradrenalineActive = false
	end

	local organSystemsEnabled = hg_huyorgans:GetBool()

	if oldPanicAttack < panicattack_threshold and org.panicattack >= panicattack_threshold and isPly and owner:Alive() then
		owner:Notify("I can't calm down.", 2, "panicattack_start", 2, nil, Color(255, 140, 140))
	end

	if org.panicattack >= panicattack_threshold then
		org.panicattackActive = true
		org.disorientation = math.max(org.disorientation, 0.6 + panicattack_disorientation * org.panicattack)
		org.adrenalineAdd = math.Approach(org.adrenalineAdd or 0, math.Remap(org.panicattack, panicattack_threshold, 1, panicattack_adrenaline_add_target * 0.5, panicattack_adrenaline_add_target), timeValue / panicattack_adrenaline_add_rise_time)

		if organSystemsEnabled and isPly and curTime >= (org.nextPanicHeartRoll or 0) then
			org.nextPanicHeartRoll = curTime + panicattack_heart_roll_delay
			if math.random(100) <= panicattack_heart_roll_chance then
				org.heartstop = true
				owner:Notify("My heart just stopped.", 2, "panicattack_heartstop", 2, nil, Color(255, 120, 120))
			end
		end
	else
		org.panicattackActive = false
		org.nextPanicHeartRoll = curTime + panicattack_heart_roll_delay
	end
	local temperature = org.temperature or 36.7
	local brainDelta = (org.brain or 0) - oldSeizureBrain
	local lobeDelta = lobeDamage - oldSeizureLobeDamage
	if brainDelta > 0 then
		hg.organism.AddSeizure(org, math.Clamp(brainDelta * seizure_brain_trauma_gain_mul, 0, 1))
	elseif brainDelta < 0 and oldSeizureBrain > 0 then
		reduceSeizure(org, math.Clamp(-brainDelta * seizure_brain_heal_gain_mul, 0, 1))
	end
	if lobeDelta > 0 then
		hg.organism.AddSeizure(org, math.Clamp(lobeDelta * seizure_brain_trauma_gain_mul, 0, 1))
	end

	-- Temperature-driven seizures belong to the full physiology mode. Direct
	-- brain and skull trauma remains consequential in both modes.
	if organSystemsEnabled then
		local previousTemperature = oldSeizureTemperature
		local heatStress = math.max(temperature - seizure_temperature_high_start, previousTemperature - seizure_temperature_high_start, 0)
		local coldStress = math.max(seizure_temperature_low_start - temperature, seizure_temperature_low_start - previousTemperature, 0)
		if heatStress > 0 then
			hg.organism.AddSeizure(org, timeValue * heatStress * seizure_temperature_gain_mul)
		elseif coldStress > 0 then
			hg.organism.AddSeizure(org, timeValue * coldStress * seizure_temperature_cold_gain_mul)
		end

	end

	local seizureBrainDamage = math.Clamp(math.max(org.brain or 0, lobeDamage), 0, 1)
	if seizureBrainDamage >= 0.01 then
		-- Brain injury remains epileptogenic after the initial impact.  Even a
		-- slight injury slowly fills the seizure meter; severe trauma ramps it
		-- rapidly, so it cannot remain a harmless static value between hits.
		local sustainedGain = math.Remap(seizureBrainDamage, 0.01, 1,
			seizure_brain_sustained_gain_min, seizure_brain_sustained_gain_max)
		hg.organism.AddSeizure(org, timeValue * sustainedGain)

		org.nextSeizureRoll = org.nextSeizureRoll or (curTime + seizure_brain_roll_delay)
		if curTime >= org.nextSeizureRoll then
			org.nextSeizureRoll = curTime + seizure_brain_roll_delay
			local rollChance = math.Remap(seizureBrainDamage, 0.01, 1, seizure_brain_roll_min_chance, seizure_brain_roll_max_chance)
			if math.random(100) <= rollChance then
				-- Brain damage can cause an abrupt seizure instead of only slowly
				-- filling the warning meter over several successful rolls.
				hg.organism.AddSeizure(org, 1)
			end
		end
	else
		org.nextSeizureRoll = curTime + seizure_brain_roll_delay
	end

	org.lastSeizureBrain = org.brain or 0
	org.lastSeizureLobeDamage = lobeDamage
	org.lastSeizureTemperature = temperature

	if org.seizure >= 1 and !org.seizureActive and isPly and owner:Alive() then
		start_seizure(owner, org)
	elseif org.seizureActive and org.seizure <= 0 then
		stop_seizure(owner, org)
	end

	if org.seizureActive then
		local time = CurTime()
		local seizureEnd = org.seizureEnd or time

		org.needfake = true
		owner.fakecd = math.max(owner.fakecd or 0, seizureEnd)

		if time >= seizureEnd then
			org.shock = math.max(org.shock or 0, seizure_end_shock)
			org.consciousness = 0
			org.needotrub = true
			stop_seizure(owner, org)
		else
			local lastInjuryTime = org.lastSeizureInjuryTime or time
			local injuryDelta = math.Clamp(time - lastInjuryTime, 0, 0.25)
			org.lastSeizureInjuryTime = time

			-- Seizures progressively injure the brain. Mild episodes add only a little,
			-- while longer severe-trauma seizures can become fatal if left untreated.
			local seizureSeverity = math.Clamp(math.max(org.brain or 0, getSeizureLobeDamage(org)), 0, 1)
			local brainDamageRate = seizure_min_brain_damage_per_second + (seizure_max_brain_damage_per_second - seizure_min_brain_damage_per_second) * seizureSeverity
			org.brain = math.min((org.brain or 0) + injuryDelta * brainDamageRate, 1)
			org.shock = math.min((org.shock or 0) + injuryDelta * seizure_shock_per_second, 85)

			local rag = owner.FakeRagdoll
			if IsValid(rag) then
				apply_seizure_pose(rag, org, time)
			end
		end
	end

	if (org.llegamputated or org.rlegamputated) and org.berserk <= 0.3 then
		org.needfake = true
	end

	if org.rarmamputated and org.larmamputated and owner:IsPlayer() then
		local hands = owner:GetWeapon("weapon_hands_sh")
		if owner:GetActiveWeapon() != hands then
			owner:SetActiveWeapon(hands)
		end
	end

	if isPly then
		owner.aimed_at = owner.aimed_at or 0
		local aimed_at_target = owner.aimed_at_target

		if (org._nextAimedAtCheck or 0) <= CurTime() then
			org._nextAimedAtCheck = CurTime() + 0.15
			local aimed = false
			local aimedPos = nil
			local aimedDist = nil
			local ownerPos = owner:EyePos()
			local aimThreshold = -0.9
			local maxDistance = 800

			for _, ent in ipairs(player.GetAll()) do
				if ent == owner then continue end
				if not ent:Alive() then continue end

				local wep = ent:GetActiveWeapon()
				if not ishgweapon(wep) then continue end

				local entPos = ent:EyePos()
				local dist = ownerPos:Distance(entPos)
				if dist > maxDistance then continue end

				local toTarget = (ownerPos - entPos):GetNormalized()
				local aimDot = ent:GetAimVector():Dot(toTarget)

				if aimDot < aimThreshold then
					aimed = true
					aimedPos = entPos
					aimedDist = dist
					break
				end
			end

			if aimed and aimedPos then
				local canSee = util.TraceLine({
					start = ownerPos,
					endpos = aimedPos,
					filter = owner,
					mask = MASK_VISIBLE
				}).Fraction > 0.5

				if canSee or aimedDist < 200 then
					owner.aimed_at_target = true
				else
					owner.aimed_at_target = false
				end
			else
				owner.aimed_at_target = false
			end
		end

		if owner.aimed_at_target then
			owner.aimed_at = math.Approach(owner.aimed_at, 1, timeValue / 3)
			org.fearadd = org.fearadd + timeValue * 1.5
		else
			owner.aimed_at = math.Approach(owner.aimed_at, 0, timeValue / 5)
		end
	end

	if org.otrub then
		org.uncon_timer = org.uncon_timer or 0
		org.uncon_timer = org.uncon_timer + timeValue
	else
		org.uncon_timer = 0
	end
	local just_went_uncon = not org.otrub and org.needotrub and not org.NoKnockdown
	local just_woke_up = not org.needotrub and org.otrub

	-- Zerlkers should keep a patient conscious through pain, shock, and other
	-- non-terminal collapse triggers. Terminal brain injury, cerebral hypoxia,
	-- airway failure, and overdose remain able to set needotrub.
	if org.needotrub and hg.organism.ZerlkersCanPreventOtrub(org) then
		org.needotrub = false
		org.consciousness = math.max(org.consciousness or 0, 0.38)
	end

	local just_went_uncon = not org.otrub and org.needotrub
	

	local just_woke_up = not org.needotrub and org.otrub and (org.uncon_timer or 0) > 6
	if isPly and just_went_uncon then hook.Run("HG_OnOtrub", owner); hook.Run("PlayerDropWeapon", owner) end
	if isPly and just_woke_up then hook.Run("HG_OnWakeOtrub", owner) end
	if org.NoKnockdown then
		org.canmove = true
		org.canmovehead = true
	else
		org.canmove = (org.spine2 < hg.organism.fake_spine2 and org.spine3 < hg.organism.fake_spine3) and not org.otrub
		org.canmovehead = (org.spine3 < hg.organism.fake_spine3) and not org.otrub
		if not (org.canmove and org.canmovehead and (org.stun - CurTime()) < 0) then org.needfake = true end
		if org.neckslit and not org.otrub then org.needfake = true end
	end

	org.canmove = (org.spine2 < hg.organism.fake_spine2 and org.spine3 < hg.organism.fake_spine3) and not org.otrub
	org.canmovehead = (org.spine3 < hg.organism.fake_spine3) and not org.otrub
	
	if not (org.canmove and org.canmovehead and (org.stun - curTime) < 0) then org.needfake = true end

	local just_went_uncon = not org.otrub and org.needotrub

	if org.brain < 0.4 then
		local naturalHeal = org.thiamine > 0 and timeValue / 480 or timeValue / 1800
		-- full heal in ~30 minutes (really fast tho) -- Ну не идет столько раунд даже в каких-нибудь скраперсах ну какой даун это придумал
		-- 8 minutes with thiamine -- ДАЖЕ СТОЛЬКО НЕ ВСЕГДА ДЛИТСЯ

		org.thiamine = math.Approach(org.thiamine, 0, timeValue / 240)
		-- you'd need to give 1 thiamine each 4 minutes

		if org.liver < 1 then org.liver = math.Approach(org.liver, 0, naturalHeal) end
		if org.heart < 1 then org.heart = math.Approach(org.heart, 0, naturalHeal) end
		org.heartStrain = math.Approach(org.heartStrain or 0, 0, naturalHeal * 0.5)
		org.arrhythmia = math.Approach(org.arrhythmia or 0, 0, naturalHeal)
		if org.stomach < 1 then org.stomach = math.Approach(org.stomach, 0, naturalHeal) end
		if org.intestines < 1 then org.intestines = math.Approach(org.intestines, 0, naturalHeal) end
		if org.lungsR[1] < 1 then org.lungsR[1] = math.Approach(org.lungsR[1], 0, naturalHeal) end
		if org.lungsL[1] < 1 then org.lungsL[1] = math.Approach(org.lungsL[1], 0, naturalHeal) end
		if (org.eyeL or 0) < 1 then org.eyeL = math.Approach(org.eyeL or 0, 0, naturalHeal) end
		if (org.eyeR or 0) < 1 then org.eyeR = math.Approach(org.eyeR or 0, 0, naturalHeal) end
	end

	-- Thiamine healing logic
	org.thiamine = math.Approach(org.thiamine, 0, timeValue / 240)

	if org.thiamine > 0 then
		if not org.thiamine_healed then
			org.thiamine_timer = org.thiamine_timer + timeValue
			local heal_delay = (org.satiety or 0) > 50 and 20 or 60

			if org.thiamine_timer > heal_delay then
				org.thiamine_healed = true
			end
		end
	else
		org.thiamine_timer = 0
		org.thiamine_healed = false
	end

	if org.thiamine_healed then
		local thiamineHealRate = timeValue / 480
		-- Heal all organs
		local organs_to_heal = {
			"liver", "heart", "stomach", "intestines", "brain", "jaw",
			"spine1", "spine2", "spine3", "chest", "pelvis", "skull", "trachea",
			"lleg", "rleg", "larm", "rarm"
		}

		local oldSpine1 = org.spine1 or 0
		local oldSpine2 = org.spine2 or 0
		local oldPelvis = org.pelvis or 0

		for _, organ in ipairs(organs_to_heal) do
			if org[organ] and org[organ] > 0 then
				org[organ] = math.Approach(org[organ], 0, thiamineHealRate)
			end
		end

		-- Remove spine floppy constraints when spine heals below break threshold
		if hg.RemoveSpineConstraints then
			local fake1 = hg.organism and hg.organism.fake_spine1 or 1
			local fake2 = hg.organism and hg.organism.fake_spine2 or 1
			if (oldSpine1 >= fake1 and org.spine1 < fake1) or (oldPelvis >= 1 and org.pelvis < 1) then
				hg.RemoveSpineConstraints(org.owner, "spine1")
			end
			if oldSpine2 >= fake2 and org.spine2 < fake2 then
				hg.RemoveSpineConstraints(org.owner, "spine2")
			end
		end

		if org.lungsR and org.lungsR[1] > 0 then org.lungsR[1] = math.Approach(org.lungsR[1], 0, thiamineHealRate) end
		if org.lungsL and org.lungsL[1] > 0 then org.lungsL[1] = math.Approach(org.lungsL[1], 0, thiamineHealRate) end
		if org.lungsR and org.lungsR[2] > 0 then org.lungsR[2] = math.Approach(org.lungsR[2], 0, thiamineHealRate) end
		if org.lungsL and org.lungsL[2] > 0 then org.lungsL[2] = math.Approach(org.lungsL[2], 0, thiamineHealRate) end
		hg.organism.RegenerateAdvancedAfflictions(org, thiamineHealRate, thiamineHealRate)
	end

	if org.otrub and isPly and org.owner:Alive() then
		//org.owner:ScreenFade(SCREENFADE.PURGE, color_black, 0.5, 0)
		//org.owner:ConCommand("soundfade 100 99999")
	end

	if not org.otrub and isPly and org.owner:Alive() then
		--org.owner:ConCommand("soundfade 0 1")
	end

	-- Incapacitation is the terminal form of unconsciousness. Keep ordinary
	-- OTRUB resuscitatable, but give a continuously incapacitated player one
	-- fixed rescue window before death.
	if isPly and owner:Alive() and org.otrub and org.incapacitated then
		if not org.deathStateEnd then
			org.deathStateEnd = curTime + incapacitation_death_delay
			owner.fullsend = true
		end

		if curTime >= org.deathStateEnd and not org.deathStateKilled then
			org.deathStateKilled = true
			if org.analgesia > 1.5 or org.painkiller > 2.4 then
				hg.achievements.AddPlayerAchievement(owner, "drugs", 1)
			end
			owner:Kill()
			return
		end
	else
		org.deathStateEnd = nil
		org.deathStateKilled = nil
	end

	if isPly and org.neckslit and org.neckslitDeadline and CurTime() >= org.neckslitDeadline and owner:Alive() and not org.deathStateKilled then
		org.deathStateKilled = true
		owner:Kill()
		return
	end

	if isPly and org.brain and org.brain >= 1 and owner:Alive() and not org.deathStateKilled then
		org.deathStateKilled = true
		if org.analgesia > 1.5 or org.painkiller > 2.4 then
			hg.achievements.AddPlayerAchievement(owner, "drugs", 1)
		end
		owner:Kill()
		return
	end

	if just_went_uncon then
		org.owner.fullsend = true
	end

	if org.brain > 0.05 then
		if math.random(600) < org.brain * 20 then
			org.needfake = true
		end
	end
	-- Resolve Zerlkers resistance before publishing org.fake. Previously the
	-- transient damage/stun needfake flag was copied to org.fake first, so other
	-- hooks could observe a knockdown for a tick even though Zerlkers cleared the
	-- source flag immediately afterward.
	if org.needfake and hg.organism.ZerlkersCanPreventFake(org) then
		org.needfake = false
		org.consciousness = math.max(org.consciousness or 0, 0.55)
	end
	if org.NoKnockdown then
		org.otrub = false
		org.needotrub = false
		org.fake = false
		org.needfake = false
	else
		org.otrub = org.needotrub
		org.fake = org.needfake
	end

	if org.neckslitSoundName and (org.otrub or org.needotrub) then
		if IsValid(org.neckslitSoundEnt) then
			org.neckslitSoundEnt:StopSound(org.neckslitSoundName)
		end
		if IsValid(owner) then
			owner:StopSound(org.neckslitSoundName)
		end
		org.neckslitSoundName = nil
		org.neckslitSoundEnt = nil
	end

	    org.was_otrub = org.otrub

	org.otrub = org.needotrub
	org.fake = org.needfake
		if org.needfake and owner:IsNPC() then
		local dmgInfo = DamageInfo()
		dmgInfo:SetDamage(10000)
		dmgInfo:SetAttacker(owner)
		owner:TakeDamageInfo(dmgInfo)
	end

	org.health = owner:Health()
	local rag = owner:IsPlayer() and owner.FakeRagdoll or owner
	if IsValid(rag) and rag:IsRagdoll() and (not owner.lastFake or owner.lastFake == 0) then
		local wantedCollisionGroup = (rag:GetVelocity():LengthSqr() > (200 * 200)) and COLLISION_GROUP_NONE or COLLISION_GROUP_WEAPON
		if rag:GetCollisionGroup() ~= wantedCollisionGroup then
			hg.ApplySetCollisionGroupNow(rag, wantedCollisionGroup)
		end
	end
	if isPly then
		if org.otrub or org.fake then hg.Fake(owner,nil,true) end
		if not org.alive and owner:Alive() then
			if org.analgesia > 1.5 or org.painkiller > 2.4 then
				hg.achievements.AddPlayerAchievement(owner, "drugs", 1)
			end
			owner:Kill()
		end
	end

	-- A terminal condition often makes the player unconscious before the next
	-- normal thought tick.  Keep status thoughts running while they are still
	-- alive so the dying phrase pool can actually be seen.
	if isPly and org.alive and owner:Alive() then
		local mul = hg.likely_to_phrase(owner)

		if not org.likely_phrase then org.likely_phrase = 0 end

				org.likely_phrase = math.max(org.likely_phrase + math.Rand(0, mul) / 25, 0)
		//print(org.likely_phrase)
		if org.likely_phrase >= 1 and (org.next_status_phrase or 0) <= curTime and !hg.GetCurrentCharacter(owner):IsOnFire() then
			local str = hg.get_status_message(owner)
			//print(str)
			if str and str != "" then
				org.likely_phrase = 0
				org.next_status_phrase = curTime + math.Rand(7, 11)
				-- (msg, delay, msgKey, showTime, func, clr)
				owner:Notify(str, 7, "phrase", 0.15, nil, hg.get_notify_color(owner))
			else
				-- Keep most of the accumulated urgency when a transient state has no
				-- phrase, rather than making the player wait through another full roll.
				org.likely_phrase = 0.8
			end
		end
	end

	if !org.alive then org.otrub = true end

	if !org.alive then
		org.lungsfunction = false
		org.heartstop = true
	end

	time = curTime

	if IsValid(owner) then
		org.sendPlyTime = org.sendPlyTime or curTime
		if (org.sendPlyTime > time) and !just_went_uncon then return end
		org.sendPlyTime = curTime + 1 + (not isPly and 2 or 0)
		send_bareinfo(org)

		local woundsSig = wounds_signature(org.wounds)
		if org.lastWoundsSig != woundsSig or org.owner.fullsend then
			org.lastWoundsSig = woundsSig
			org.owner:SetNetVar("wounds", org.wounds)
		end

		local arterialWoundsSig = wounds_signature(org.arterialwounds)
		if org.lastArterialWoundsSig != arterialWoundsSig or org.owner.fullsend then
			org.lastArterialWoundsSig = arterialWoundsSig
			org.owner:SetNetVar("arterialwounds", org.arterialwounds)
		end
		hg.organism.SyncWounds(org)

		if isPly and alive then
			send_organism(org, owner)
		end
	end
end)

hook.Add("Org Think", "regenerationberserk", function(owner, org, timeValue)
	if not owner:IsPlayer() or not owner:Alive() then return end
	if zb and zb.modes and zb.modes.juggernaut and zb.modes.juggernaut:IsJuggernaut(owner) then return end
	if !owner:IsBerserk() then return end
	//if org.heartstop then return end

	org.blood = math.Approach(org.blood, hg.organism.normalBloodVolume or 5000, timeValue * 60)

	for i, wound in pairs(org.wounds) do
		wound[1] = math.max(wound[1] - timeValue * 10,0)
	end

	for i, wound in pairs(org.arterialwounds) do
		wound[1] = math.max(wound[1] - timeValue * 10,0)
	end

	org.internalBleed = math.max(org.internalBleed - timeValue * 10, 0)

	local regen = timeValue / 120 * org.berserk

	local oldLleg, oldRleg, oldRarm, oldLarm = org.lleg, org.rleg, org.rarm, org.larm
	org.lleg = math.max(org.lleg - regen, 0)
	org.rleg = math.max(org.rleg - regen, 0)
	org.rarm = math.max(org.rarm - regen, 0)
	org.larm = math.max(org.larm - regen, 0)
	-- Constraints are only applied on death/heal/neck break events and persist until next ragdoll
	-- Do not remove constraints when limbs heal
	org.chest = math.max(org.chest - regen, 0)
	local oldPelvis = org.pelvis
	org.pelvis = math.max(org.pelvis - regen, 0)
	local oldSpine1 = org.spine1
	local oldSpine2 = org.spine2
	local oldSpine3 = org.spine3
	org.spine1 = math.max(org.spine1 - regen, 0)
	org.spine2 = math.max(org.spine2 - regen, 0)
	org.spine3 = math.max(org.spine3 - regen, 0)
	-- Constraints are only applied on death/heal/neck break events and persist until next ragdoll
	-- Do not remove spine/neck constraints when they heal
	org.skull = math.max(org.skull - regen, 0)

	org.liver = math.max(org.liver - regen, 0)
	org.intestines = math.max(org.intestines - regen, 0)
	org.heart = math.max(org.heart - regen, 0)
	org.stomach = math.max(org.stomach - regen, 0)
	org.lungsR[1] = math.max(org.lungsR[1] - regen, 0)
	org.lungsL[1] = math.max(org.lungsL[1] - regen, 0)
	org.lungsR[2] = math.max((org.lungsR[2] or 0) - regen, 0)
	org.lungsL[2] = math.max((org.lungsL[2] or 0) - regen, 0)
	org.eyeL = math.max((org.eyeL or 0) - regen, 0)
	org.eyeR = math.max((org.eyeR or 0) - regen, 0)
	local oldBrain = org.brain or 0
	org.brain = math.max(oldBrain - regen, 0)
	reduceSeizure(org, math.Clamp((oldBrain - org.brain) * seizure_brain_heal_gain_mul, 0, 1))
	org.lastSeizureBrain = org.brain
	hg.organism.RegenerateAdvancedAfflictions(org, regen, regen)

	org.hungry = 0

	org.pain = math.Approach(org.pain, 0, timeValue * 10)
	org.painadd = math.Approach(org.painadd, 0, timeValue * 10)
	org.avgpain = math.Approach(org.avgpain, 0, timeValue * 10)
	org.shock = math.Approach(org.shock, 0, timeValue * 10)
	org.immobilization = math.Approach(org.immobilization, 0, timeValue * 10)
	org.disorientation = math.Approach(org.disorientation, 0, timeValue * 10)

	org.lungsfunction = true
	org.heartstop = false
	org.fibrillation = false
	org.arrhythmia = 0
	org.heartStrain = math.max((org.heartStrain or 0) - regen, 0)

	owner:SetRunSpeed(math.min(500, 400 + (25 * org.berserk)))
end)

hook.Add("Org Think", "regenerationnoradrenaline", function(owner, org, timeValue)
	if not owner:IsPlayer() or not owner:Alive() then return end
	if org.noradrenaline <= 0 then return end
	
	local regen = timeValue / 60 * org.noradrenaline

	org.lungsR[1] = math.max(org.lungsR[1] - regen, 0)
	org.lungsL[1] = math.max(org.lungsL[1] - regen, 0)
	org.lungsR[2] = math.max((org.lungsR[2] or 0) - regen, 0)
	org.lungsL[2] = math.max((org.lungsL[2] or 0) - regen, 0)
	org.eyeL = math.max((org.eyeL or 0) - regen, 0)
	org.eyeR = math.max((org.eyeR or 0) - regen, 0)

	org.hungry = 0

	org.pain = math.Approach(org.pain, 0, regen * 10)
	org.painadd = math.Approach(org.painadd, 0, regen * 10)
	org.avgpain = math.Approach(org.avgpain, 0, regen * 10)
	org.shock = math.Approach(org.shock, 0, regen * 10)
	org.immobilization = math.Approach(org.immobilization, 0, regen * 10)
	org.disorientation = math.Approach(org.disorientation, 0, regen * 10)
	org.adrenaline = math.Approach(org.adrenaline, 4, regen * 10)
	org.analgesia = math.Approach(org.analgesia, 1, regen * 10)

	if org.noradrenaline > 2 then
		local oldBrain = org.brain or 0
		org.brain = math.Approach(oldBrain, 0.3, timeValue / 60)
		reduceSeizure(org, math.Clamp((oldBrain - org.brain) * seizure_brain_heal_gain_mul, 0, 1))
		org.lastSeizureBrain = org.brain
		hg.organism.RegenerateAdvancedAfflictions(org, regen, regen)
	else
		hg.organism.RegenerateAdvancedAfflictions(org, 0, regen)
	end

	org.pulse = math.Approach(org.pulse, 70, regen * 10)
	org.heartbeat = math.Approach(org.heartbeat, 220, regen * 10)
	org.hypotension = math.Approach(org.hypotension or 0, 0, regen / 8)
	org.hypertension = math.Approach(org.hypertension or 0, 0, regen / 20)

	org.lungsfunction = true
	org.heartstop = false
	org.fibrillation = false
end)

concommand.Add("hg_organism_setvalue", function(ply, cmd, args)
	if not ply:IsAdmin() then return end

	if not args[3] then
		if isbool(ply.organism[args[1]]) then
			ply.organism[args[1]] = tonumber(args[2]) != 0
		else
			ply.organism[args[1]] = tonumber(args[2])
		end
	end

	if args[3] then
		for i,pl in pairs(player.GetListByName(args[3])) do
			if isbool(pl.organism[args[1]]) then
				pl.organism[args[1]] = tonumber(args[2]) != 0
			else
				pl.organism[args[1]] = tonumber(args[2])
			end
		end
	end
end)

concommand.Add("hg_organism_setvalue2", function(ply, cmd, args)
	if not ply:IsAdmin() then return end

	ply.organism[args[1]][tonumber(args[2])] = tonumber(args[3])
end)

concommand.Add("hg_organism_clear", function(ply, cmd, args)
	if not ply:IsAdmin() then return end

	if not args[1] then
		hg.organism.Clear(ply.organism)
	end

	if args[1] then
		for i,pl in pairs(player.GetListByName(args[1])) do
			hg.organism.Clear(pl.organism)
		end
	end
end)

hook.Add("SetupMove", "hg-speed", function(ply, mv) end) --mv:SetMaxClientSpeed(100) --mv:SetMaxSpeed(100)

hook.Add("StartCommand","hg_lol",function(ply,cmd)
	if not ply:Alive() or not ply.organism then return end
	if ply.organism.seizureActive then
		cmd:ClearMovement()
		if not IsValid(ply.FakeRagdoll) then cmd:ClearButtons() end
	elseif ply.organism.otrub then
		cmd:ClearMovement()
	end
end)

hook.Add("PlayerDeath","next-respawn-full",function(ply)
	ply.fullsend = true
end)

hook.Add("PlayerDeath", "PanicAttackWitnessDeath", function(victim, inflictor, attacker)
	local realAttacker = resolve_panic_attacker(victim, attacker)
	victim._panicDeathAttacker = realAttacker
	panic_witness_event(victim, realAttacker, 0.22, panicattack_death_radius, 2)
	if not IsValid(realAttacker) and IsValid(victim.lastPanicAttacker) and (victim.lastPanicAttackTime or 0) > CurTime() - 30 then
		realAttacker = victim.lastPanicAttacker
	end
	victim.killedBy = realAttacker
	if IsValid(realAttacker) then
		realAttacker.lastKillTime = CurTime()
	end
end)

hook.Add("OnNPCKilled", "PanicAttackWitnessNPCDeath", function(victim, attacker, inflictor)
	local realAttacker = resolve_panic_attacker(victim, attacker)
	victim._panicDeathAttacker = realAttacker
	panic_witness_event(victim, realAttacker, 0.16, panicattack_death_radius, 2)
	if not IsValid(realAttacker) and IsValid(victim.lastPanicAttacker) and (victim.lastPanicAttackTime or 0) > CurTime() - 30 then
		realAttacker = victim.lastPanicAttacker
	end
	if IsValid(realAttacker) then
		realAttacker.lastKillTime = CurTime()
	end
end)

hook.Add("RagdollDeath", "PanicAttackRememberCorpseKiller", function(victim, ragdoll)
	if IsValid(victim) and IsValid(ragdoll) then
		ragdoll._panicDeathAttacker = victim._panicDeathAttacker
	end
end)

hook.Add("HG_OnWakeOtrub", "afterOtrub", function( owner )
	owner.organism.after_otrub = true
	local str = hg.get_status_message(owner)
	owner.organism.after_otrub = nil
	//print(str)
	-- (msg, delay, msgKey, showTime, func, clr, traumatic)
	timer.Simple(0.1,function()
		if not IsValid(owner) then return end
		owner:Notify(str, 1, "wake", 1, nil, hg.get_notify_color(owner))
	end)

	owner.organism.fearadd = owner.organism.fearadd + 5

	owner:SendLua("system.FlashWindow()")
end)

hook.Add("HG_OnOtrub", "fearful", function( plya )// ЧЕ
	local ent = hg.GetCurrentCharacter(plya)
	for i,ply in ipairs(ents.FindInSphere(ent:GetPos(),256)) do
		if not ply:IsPlayer() or not ply.organism or plya == ply then continue end

		local tr = {}
		tr.start = ply:GetPos()
		tr.endpos = ent:GetPos()
		tr.filter = {ply,ent}
		if not util.TraceLine(tr).Hit then
			ply.organism.adrenalineAdd = ply.organism.adrenalineAdd + 0.3
			ply.organism.fearadd = ply.organism.fearadd + 0.3
		end
	end
end)

local unlucky_dislocations = {
	"Why can't I fix this goddamn dislocation...",
	"Please... why is it so hard.",
	"Just go back in place already...",
	"This is irritating",
	"I should try again",
}

local finally_fixed = {
	"Finally.",
	"That was harder than I thought",
	"One dislocation away.",
}

local function fixlimb(org, key, fixer)
	if math.random(100) > (97 + (fixer != org.owner and (fixer.organism and fixer.organism.pain or 0) or 0) - (org.analgesia * 50 + org.painkiller * 15) - (fixer != org.owner and 30 or 0) - (fixer.tries or 0) * 10 - (fixer.Profession == "doctor" and 100 or 0) - (org.owner == fixer and (IsValid(org.owner.FakeRagdoll) or (org.owner.Crouching and org.owner:Crouching())) and 10 or 0)) then
		org[key.."dislocation"] = false
		if hg.fakeBoneFlop and hg.fakeBoneFlop.ClearStoredLimb(org, key) then
			hg.fakeBoneFlop.ScheduleRebuild(org.owner)
		end
		org.painadd = org.painadd + 5 * math.random(1, 3)
		org.fearadd = org.fearadd + 0.1

		org.owner:EmitSound("physics/flesh/flesh_impact_hard6.wav", 65)

		if fixer == org.owner and (fixer.tries or 0) > 3 and math.random(3) == 1 then
			fixer:Notify(finally_fixed[math.random(#finally_fixed)], 1, "dislocations_unlucky", 1, nil, Color(255, 255, 255, 255))
		end

		fixer.tries = 0
	else
		fixer.tries = (fixer.tries or 0) + 1
		org.painadd = org.painadd + 15 * math.random(1, 3)

		org.fearadd = org.fearadd + 0.3

		org.owner:EmitSound("physics/body/body_medium_impact_soft"..math.random(7)..".wav", 65)
		
		if fixer.Profession != "doctor" and math.random(5) == 1 then
			local dmgInfo = DamageInfo()
			dmgInfo:SetDamage(50)
			dmgInfo:SetDamageType(DMG_CLUB)
			local func = hg.organism.input_list[key.."down"]
			if func then func(org.owner.organism, 1, 6, dmgInfo, 0, vector_up) end
		end

		if fixer == org.owner and fixer.tries > 3 and math.random(3) == 1 then
			fixer:Notify(unlucky_dislocations[math.random(#unlucky_dislocations)], 1, "dislocations_unlucky", 1, nil, Color(255, 255, 255, 255))
		end
	end
end

concommand.Add("hg_fixdislocation", function(ply, cmd, args)
	local fixer = ply

	if args and args[2] and math.Round(tonumber(args[2])) == 1 then
		ply = hg.eyeTrace(fixer).Entity
	end

	if !IsValid(ply) or !ply.organism then return end

	ply = ply.organism.owner

	local org = ply.organism
	if !fixer:Alive() or !org or fixer.organism.otrub then return end
	if (fixer.tried_fixing_limb or 0) > CurTime() then return end
	if !fixer.organism.canmove or !fixer.organism.canmovehead or fixer.organism.pain > 60 then return end
	fixer.tried_fixing_limb = CurTime() + fixer.organism.pain / 30

	if math.Round(tonumber(args[1])) == 1 then
		if org.llegdislocation then
			fixlimb(org, "lleg", fixer)
		elseif org.rlegdislocation then
			fixlimb(org, "rleg", fixer)
		end
	elseif math.Round(tonumber(args[1])) == 2 then
		if org.larmdislocation then
			fixlimb(org, "larm", fixer)
		elseif org.rarmdislocation then
			fixlimb(org, "rarm", fixer)
		end
	elseif math.Round(tonumber(args[1])) == 3 then
		if org.jawdislocation then
			fixlimb(org, "jaw", fixer)
		end
	end
end)

hook.Add("OnEntityWaterLevelChanged", "ClearBlood", function(ent, old, new)
	if new >= 2 then
		if ent:IsOnFire() then ent:Extinguish() end
		ent:RemoveAllDecals()
	end
end)
