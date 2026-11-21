local Clamp, Approach, max, min, log10 = math.Clamp, math.Approach, math.max, math.min, math.log10

hg.organism.AcidBase = hg.organism.AcidBase or {}
local AcidBase = hg.organism.AcidBase

AcidBase.Config = {
	normalPh = 7.4,
	normalBicarb = 24,
	normalPaco2 = 40,
	phMin = 6.6,
	phMax = 7.9,
	bicarbMin = 4,
	bicarbMax = 45,

	bagPh = {7.3, 7.42},
	staleBagChance = 0.1,
	staleBagPh = {6.85, 7.05},

	lactateNormal = 1,
	lactateBuffer = 1.1,
	sepsisAcid = 1.5,
	septicShockAcid = 4,
	hepaticAcid = 4,
	renalStart = 0.35,
	renalRange = 0.6,
	renalAcid = 12,
	hypercapniaCompensation = 0.15,
	citratePerMl = 0.0025,
	citrateDecay = 1 / 240,
	citrateMax = 12,

	bicarbDropRate = 0.6,
	bicarbRecoverRate = 0.01,
	thiamineRecoverRate = 0.25,

	acidosisStart = 7.35,
	acidosisFull = 6.9,
	acidosisComaStart = 7.15,
	acidosisComaRange = 0.3,
	alkalosisStart = 7.45,
	alkalosisFull = 7.7,

	hepaticStart = 0.3,
	hepaticRange = 0.55,
	hepaticRise = 1 / 120,
	hepaticFall = 1 / 240,
	hepaticThiamineFall = 1 / 40,
	hepaticToxinGain = 0.006,
	hepaticToxinClear = 0.004,
	hepaticToxinThiamine = 1 / 40,
	hepaticShockStart = 0.5,

	septicShockStart = 0.9,
	septicShockRange = 0.8,
	sepsisFeverMax = 1.6,
	sepsisColdStart = 1.4,
	sepsisColdMax = -1.8,
	sepsisHeartRate = 22,
	sepsisLactate = 0.004,
	septicShockLactate = 0.025,
	septicShockNausea = 0.01,

	vasoplegiaMax = 0.7,
	simpleToxinPerAcidMl = 0.05,

	thoughtCooldown = 40,
}
local CONFIG = AcidBase.Config

local THOUGHTS = {
	{key = "sepsis", at = 0.4, value = function(org) return min(tonumber(org.hemotransfusionshock) or 0, 2) end, color = Color(220, 180, 150), lines = {
		"I'm burning up... everything aches.",
		"I feel feverish and weak...",
		"Something's festering inside me.",
	}},
	{key = "septicshock", at = 0.25, value = function(org) return org.septicShock or 0 end, color = Color(220, 150, 150), lines = {
		"I'm freezing... my heart won't slow down.",
		"I'm so cold and everything is fading...",
		"I can't stop shaking...",
	}},
	{key = "acidosis", at = 0.35, value = function(org) return org.acidosis or 0 end, color = Color(210, 170, 200), lines = {
		"I keep gulping air and it's not enough...",
		"My chest is heaving, I can't catch my breath...",
	}},
	{key = "alkalosis", at = 0.35, value = function(org) return org.alkalosis or 0 end, color = Color(170, 200, 220), lines = {
		"My fingers are tingling and cramping...",
		"My lips feel numb, my hands are twitching...",
	}},
	{key = "hepatic", at = 0.4, value = function(org) return org.hepaticToxin or 0 end, color = Color(210, 200, 120), lines = {
		"I can't think straight...",
		"My skin looks yellow...",
		"Everything feels so foggy...",
	}},
}

local function bicarbForPh(ph)
	return 0.03 * CONFIG.normalPaco2 * 10 ^ (ph - 6.1)
end
AcidBase.BicarbForPh = bicarbForPh

function AcidBase.RollBagPh()
	local range = math.random() < CONFIG.staleBagChance and CONFIG.staleBagPh or CONFIG.bagPh

	return math.Round(math.Rand(range[1], range[2]), 2)
end

function AcidBase.GetPh(org)
	return org and tonumber(org.bloodph) or CONFIG.normalPh
end

function AcidBase.Init(org)
	org.bicarb = CONFIG.normalBicarb
	org.bloodph = CONFIG.normalPh
	org.citrate = 0
	org.acidosis = 0
	org.alkalosis = 0
	org.acidosisDrive = 0
	org.alkalosisDrive = 0
	org.hepaticFailure = 0
	org.hepaticToxin = 0
	org.septicShock = 0
	org.sepsisFever = 0
	org.shockVasoplegia = 0
	org.metabolicHeartRate = 0
	org.metabolicConsciousnessCap = 1
	org.metabolicStaminaMul = 1
	org.metabolicThoughts = {}
end

function hg.organism.TransfuseBlood(org, ml, bagPh)
	ml = tonumber(ml) or 0
	if not org or ml <= 0 then return end
	bagPh = tonumber(bagPh) or CONFIG.normalPh

	if org.simpleMode then
		local acid = max(CONFIG.acidosisStart - bagPh, 0)
		if acid > 0 and hg.SimpleHealth and hg.SimpleHealth.AddDamage then
			hg.SimpleHealth.AddDamage(org, "toxin", ml * acid * CONFIG.simpleToxinPerAcidMl)
		end
		return
	end

	local fraction = Clamp(ml / max(tonumber(org.blood) or 5000, 1), 0, 1)
	org.bicarb = Lerp(fraction, tonumber(org.bicarb) or CONFIG.normalBicarb, bicarbForPh(bagPh))
	org.lactaid = Lerp(fraction, tonumber(org.lactaid) or CONFIG.lactateNormal, CONFIG.lactateNormal)
	org.hepaticToxin = (tonumber(org.hepaticToxin) or 0) * (1 - fraction)
	org.citrate = min((tonumber(org.citrate) or 0) + ml * CONFIG.citratePerMl, CONFIG.citrateMax)
end

local function updateSepsisOutputs(org)
	local severity = Clamp(tonumber(org.hemotransfusionshock) or 0, 0, 2)
	local shock = Clamp((severity - CONFIG.septicShockStart) / CONFIG.septicShockRange, 0, 1)
	org.septicShock = shock

	local fever = min(severity, 1) * CONFIG.sepsisFeverMax
	if severity > CONFIG.sepsisColdStart then
		fever = Lerp((severity - CONFIG.sepsisColdStart) / (2 - CONFIG.sepsisColdStart), CONFIG.sepsisFeverMax, CONFIG.sepsisColdMax)
	end
	org.sepsisFever = fever

	return severity, shock
end

local function updateHepatic(org, mulTime, thiamine, shock)
	local liver = Clamp(tonumber(org.liver) or 0, 0, 1)
	local target = max(Clamp((liver - CONFIG.hepaticStart) / CONFIG.hepaticRange, 0, 1), shock * 0.4)
	local failure = tonumber(org.hepaticFailure) or 0
	local fall = CONFIG.hepaticFall + (thiamine and CONFIG.hepaticThiamineFall or 0)
	failure = Approach(failure, target, mulTime * (target > failure and CONFIG.hepaticRise or fall))
	org.hepaticFailure = failure

	local toxin = tonumber(org.hepaticToxin) or 0
	toxin = toxin + mulTime * failure * CONFIG.hepaticToxinGain
	toxin = toxin - mulTime * ((1 - failure) * CONFIG.hepaticToxinClear + (thiamine and CONFIG.hepaticToxinThiamine or 0))
	org.hepaticToxin = Clamp(toxin, 0, 1)

	return failure, org.hepaticToxin
end

local function updateBicarb(org, mulTime, thiamine, severity, shock, hepatic)
	local renal = Clamp(((tonumber(org.flank) or 0) - CONFIG.renalStart) / CONFIG.renalRange, 0, 1)
	local lactateExcess = max((tonumber(org.lactaid) or CONFIG.lactateNormal) - CONFIG.lactateNormal, 0)
	local paco2 = Clamp(tonumber(org.paco2) or CONFIG.normalPaco2, 10, 150)

	local citrate = max((tonumber(org.citrate) or 0) - mulTime * (tonumber(org.citrate) or 0) * CONFIG.citrateDecay, 0)
	org.citrate = citrate

	local target = CONFIG.normalBicarb
		- lactateExcess * CONFIG.lactateBuffer
		- severity * CONFIG.sepsisAcid
		- shock * CONFIG.septicShockAcid
		- hepatic * CONFIG.hepaticAcid
		- renal * CONFIG.renalAcid
		+ citrate * (1 - hepatic)
		+ max(paco2 - 45, 0) * CONFIG.hypercapniaCompensation * (1 - renal)

	local bicarb = tonumber(org.bicarb) or CONFIG.normalBicarb
	local rate = target < bicarb and CONFIG.bicarbDropRate
		or CONFIG.bicarbRecoverRate * (1 - renal * 0.9) + (thiamine and CONFIG.thiamineRecoverRate or 0)
	bicarb = Clamp(Approach(bicarb, target, mulTime * rate), CONFIG.bicarbMin, CONFIG.bicarbMax)
	org.bicarb = bicarb

	local ph = Clamp(6.1 + log10(bicarb / (0.03 * paco2)), CONFIG.phMin, CONFIG.phMax)
	org.bloodph = math.Round(ph, 3)

	return ph
end

local function emitThoughts(owner, org)
	if not org.isPly or org.otrub or not IsValid(owner) or not owner.Notify then return end

	local now = CurTime()
	local state = org.metabolicThoughts or {}
	org.metabolicThoughts = state
	for _, thought in ipairs(THOUGHTS) do
		local value = thought.value(org)
		if value >= thought.at then
			if not state[thought.key] and (state.next or 0) <= now and (org.nextCriticalStatusNotify or 0) <= now then
				owner:Notify(thought.lines[math.random(#thought.lines)], 45, "metabolic_" .. thought.key, 0, nil, thought.color)
				state[thought.key] = true
				state.next = now + CONFIG.thoughtCooldown
				org.nextCriticalStatusNotify = now + 12
			end
		elseif value < thought.at * 0.5 then
			state[thought.key] = nil
		end
	end
end

function hg.organism.UpdateMetabolicShock(owner, org, mulTime)
	if org.simpleMode then
		org.septicShock, org.sepsisFever, org.shockVasoplegia, org.metabolicHeartRate = 0, 0, 0, 0
		org.acidosis, org.alkalosis, org.acidosisDrive, org.alkalosisDrive = 0, 0, 0, 0
		org.metabolicConsciousnessCap = 1
		org.metabolicStaminaMul = max(1 - (tonumber(org.hemotransfusionshock) or 0), 0.2)
		return
	end
	if not org.alive then return end

	local thiamine = (tonumber(org.thiamine) or 0) > 0
	local severity, shock = updateSepsisOutputs(org)
	local hepatic, toxin = updateHepatic(org, mulTime, thiamine, shock)

	org.lactaid = min((tonumber(org.lactaid) or CONFIG.lactateNormal) + mulTime * (severity * CONFIG.sepsisLactate + shock * CONFIG.septicShockLactate), 20)
	if shock > 0 then
		org.wantToVomit = (org.wantToVomit or 0) + mulTime * shock * CONFIG.septicShockNausea
	end

	local ph = updateBicarb(org, mulTime, thiamine, severity, shock, hepatic)
	local acidosis = Clamp((CONFIG.acidosisStart - ph) / (CONFIG.acidosisStart - CONFIG.acidosisFull), 0, 1)
	local alkalosis = Clamp((ph - CONFIG.alkalosisStart) / (CONFIG.alkalosisFull - CONFIG.alkalosisStart), 0, 1)
	org.acidosis, org.alkalosis = acidosis, alkalosis
	org.acidosisDrive, org.alkalosisDrive = acidosis, alkalosis

	if acidosis > 0.45 and hg.organism.AddCardiacStress then
		hg.organism.AddCardiacStress(org, mulTime * (acidosis - 0.45) * 0.04)
	end
	if alkalosis > 0 then
		org.disorientation = max(org.disorientation or 0, alkalosis * 1.2)
		if alkalosis > 0.3 then org.painadd = (org.painadd or 0) + mulTime * (alkalosis - 0.3) * 4 end
		if alkalosis > 0.6 and hg.organism.AddCardiacStress then
			hg.organism.AddCardiacStress(org, mulTime * (alkalosis - 0.6) * 0.03)
		end
		if alkalosis > 0.8 and hg.organism.AddSeizure then
			hg.organism.AddSeizure(org, mulTime * (alkalosis - 0.8) * 0.1)
		end
	end
	if toxin > 0 then
		org.disorientation = max(org.disorientation or 0, toxin * 1.0)
	end

	org.shockVasoplegia = Clamp(severity * 0.08 + shock * 0.45 + acidosis * 0.25 + max(hepatic - CONFIG.hepaticShockStart, 0) * 0.5, 0, CONFIG.vasoplegiaMax)
	org.metabolicHeartRate = severity * CONFIG.sepsisHeartRate + acidosis * 15 + hepatic * 10

	local acidCap = 1 - Clamp((CONFIG.acidosisComaStart - ph) / CONFIG.acidosisComaRange, 0, 1) * 0.9
	local alkaliCap = 1 - max(alkalosis - 0.5, 0) * 1.2
	local sepsisCap = 1 - shock * 0.5
	local hepaticCap = 1 - Clamp((toxin - 0.3) / 0.7, 0, 1) * 0.85
	org.metabolicConsciousnessCap = min(acidCap, alkaliCap, sepsisCap, hepaticCap)
	org.metabolicStaminaMul = max((1 - severity * 0.25) * (1 - acidosis * 0.45) * (1 - hepatic * 0.3), 0.2)

	emitThoughts(owner, org)
end
