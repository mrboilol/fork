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
	salineBloodPerMl = 0.5,
	salineHydrationPerMl = 0.05,
	salineSatietyPerMl = 0.006,
	salineBicarbPerMl = 0.008,
	salineLactatePerMl = 0.002,
	salineMyoglobinPerMl = 0.0006,
	salineSystemicReliefPerMl = 0.0001,

	lactateNormal = 1,
	lactateBuffer = 1.1,
	sepsisAcid = 1.5,
	septicShockAcid = 4,
	hepaticAcid = 4,
	renalStart = 0.35,
	renalRange = 0.6,
	renalAcid = 12,
	uremiaRise = 1 / 180,
	uremiaFall = 1 / 400,
	uremiaNausea = 0.004,
	fluidOverloadMl = 500,
	fluidOverloadRate = 0.008,
	peritonitisVasoplegia = 0.12,
	peritonitisHeartRate = 14,
	hypercapniaCompensation = 0.15,
	hypocapniaCompensation = 0.25,
	hypocapniaCompRate = 0.02,
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
	sepsisHeartRate = 22,
	sepsisLactate = 0.004,
	septicShockLactate = 0.025,
	septicShockNausea = 0.01,
	sepsisEncephalopathyStart = 0.6,
	sepsisEncephalopathyRange = 1,
	sepsisEncephalopathy = 0.6,

	vasoplegiaMax = 0.7,

	mofRise = 60,
	mofFall = 240,
	mofStressStart = 0.4,
	mofStressRate = 0.05,
	mofHeartStart = 0.6,
	mofHeartRate = 0.01,
	mofOrganStart = 0.6,
	mofOrganRate = 0.0005,
	acidSeizureStart = 0.7,
	acidSeizureRate = 0.1,
	toxinSeizureStart = 0.6,
	toxinSeizureRate = 0.08,
	fibrillationRollInterval = 5,
	fibrillationRollChance = 0.15,

	acidosisNausea = 0.004,
	acidContractilityLoss = 0.3,
	acidCatecholamineLoss = 0.5,
	acidOxygenUnload = 0.05,
	alkaliOxygenHold = 0.1,
	alkaliCerebralConstrict = 0.25,
	hypocapniaStart = 35,
	hypocapniaRange = 15,
	hypocapniaConstrict = 0.25,
	hypercapniaStart = 45,
	hypercapniaRange = 40,
	hypercapniaDilate = 0.15,
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
	{key = "peritonitis", at = 0.3, value = function(org) return org.peritonitis or 0 end, color = Color(220, 170, 130), lines = {
		"My belly is hard as a board and it burns inside...",
		"Something's leaking in my gut... it hurts to even breathe.",
		"Every move sets my stomach on fire...",
	}},
	{key = "uremia", at = 0.4, value = function(org) return org.uremia or 0 end, color = Color(200, 190, 150), lines = {
		"I haven't pissed in ages... I feel poisoned.",
		"There's a metal taste in my mouth and I can't stop itching...",
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
	org.multiOrganFailure = 0
	org.hepaticToxin = 0
	org.septicShock = 0
	org.renalFailure = 0
	org.uremia = 0
	org.shockVasoplegia = 0
	org.metabolicHeartRate = 0
	org.metabolicConsciousnessCap = 1
	org.metabolicStaminaMul = 1
	org.acidContractility = 1
	org.catecholamineResponse = 1
	org.cerebralFlowMul = 1
	org.metabolicDrowsiness = 0
	org.metabolicThoughts = {}
end

function hg.organism.TransfuseBlood(org, ml, bagPh, bagBacteria)
	ml = tonumber(ml) or 0
	if not org or ml <= 0 then return end
	bagPh = tonumber(bagPh) or CONFIG.normalPh
	hg.organism.Infection.TransfuseBacteria(org, ml, bagBacteria)

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

function hg.organism.InfuseSaline(org, ml)
	local blood = org.blood
	local room = max(hg.organism.MAX_TRANSFUSION_BLOOD - blood, 0) / CONFIG.salineBloodPerMl
	ml = Clamp(ml, 0, room)
	if ml == 0 then return 0 end

	org.blood = blood + ml * CONFIG.salineBloodPerMl
	org.hydration = min((org.hydration or 100) + ml * CONFIG.salineHydrationPerMl, 100)
	org.thirst = max((org.thirst or 0) - ml * CONFIG.salineHydrationPerMl, 0)
	org.satiety = min((org.satiety or 100) + ml * CONFIG.salineSatietyPerMl, 100)
	org.hungry = max((org.hungry or 0) - ml * CONFIG.salineSatietyPerMl, 0)
	if org.simpleMode then return ml end

	local paco2 = Clamp(org.paco2 or CONFIG.normalPaco2, 10, 150)
	local target = Clamp(CONFIG.normalBicarb * paco2 / CONFIG.normalPaco2, CONFIG.bicarbMin, CONFIG.bicarbMax)
	org.bicarb = Approach(org.bicarb or CONFIG.normalBicarb, target, ml * CONFIG.salineBicarbPerMl)
	if (org.lactaid or 0) > CONFIG.lactateNormal then
		org.lactaid = max(org.lactaid - ml * CONFIG.salineLactatePerMl, CONFIG.lactateNormal)
	end
	org.myoglobin = max((org.myoglobin or 0) - ml * CONFIG.salineMyoglobinPerMl, 0)
	org.multiOrganFailure = max((org.multiOrganFailure or 0) - ml * CONFIG.salineSystemicReliefPerMl, 0)

	return ml
end

local DRAIN_WASHOUT = {
	bicarb = CONFIG.normalBicarb,
	lactaid = CONFIG.lactateNormal,
	citrate = 0,
	hypocapniaComp = 0,
	hepaticToxin = 0,
	myoglobin = 0,
	rhabdoAcid = 0,
	hyperkalemia = 0,
	uremia = 0,
}

function hg.organism.DrainBlood(org, ml)
	local blood = max(tonumber(org.blood) or 0, 0)
	local drained = Clamp(tonumber(ml) or 0, 0, blood)
	org.blood = blood - drained
	if org.simpleMode or drained <= 0 then return drained end

	local kept = 1 - drained / blood
	for key, normal in pairs(DRAIN_WASHOUT) do
		org[key] = normal + ((tonumber(org[key]) or normal) - normal) * kept
	end

	return drained
end

local function updateSepsisOutputs(org)
	local severity = Clamp(tonumber(org.hemotransfusionshock) or 0, 0, 2)
	local shock = Clamp((severity - CONFIG.septicShockStart) / CONFIG.septicShockRange, 0, 1)
	org.septicShock = shock

	return severity, shock
end

local function updateRenal(org, mulTime)
	local renal = Clamp(((tonumber(org.flank) or 0) - CONFIG.renalStart) / CONFIG.renalRange, 0, 1)
	org.renalFailure = renal

	local uremia = tonumber(org.uremia) or 0
	org.uremia = Clamp(Approach(uremia, renal, mulTime * (renal > uremia and CONFIG.uremiaRise or CONFIG.uremiaFall)), 0, 1)

	local overload = max((tonumber(org.blood) or 0) - (tonumber(org.maxblood) or 5000), 0) / CONFIG.fluidOverloadMl
	if renal > 0 and overload > 0 then
		org.lungWater = min((tonumber(org.lungWater) or 0) + mulTime * renal * min(overload, 2) * CONFIG.fluidOverloadRate, 1)
	end

	return renal, org.uremia
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

local function updateBicarb(org, mulTime, thiamine, severity, shock, hepatic, renal)
	local lactateExcess = max((tonumber(org.lactaid) or CONFIG.lactateNormal) - CONFIG.lactateNormal, 0)
	local paco2 = Clamp(tonumber(org.paco2) or CONFIG.normalPaco2, 10, 150)

	local citrate = max((tonumber(org.citrate) or 0) - mulTime * (tonumber(org.citrate) or 0) * CONFIG.citrateDecay, 0)
	org.citrate = citrate

	local hypocapniaComp = tonumber(org.hypocapniaComp) or 0
	hypocapniaComp = Approach(hypocapniaComp, max(CONFIG.normalPaco2 - paco2, 0) * CONFIG.hypocapniaCompensation * (1 - renal), mulTime * CONFIG.hypocapniaCompRate)
	org.hypocapniaComp = hypocapniaComp

	local target = CONFIG.normalBicarb
		- hypocapniaComp
		- lactateExcess * CONFIG.lactateBuffer
		- severity * CONFIG.sepsisAcid
		- shock * CONFIG.septicShockAcid
		- hepatic * CONFIG.hepaticAcid
		- renal * CONFIG.renalAcid
		- (tonumber(org.rhabdoAcid) or 0)
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

local function updateTerminalCascade(org, mulTime, shock, acidosis, hepatic, toxin, renal)
	local hyperK = Clamp(tonumber(org.hyperkalemia) or 0, 0, 1)
	local target = Clamp(shock * 0.3 + acidosis * 0.3 + toxin * 0.2 + renal * 0.2 + hyperK * 0.2 + hepatic * 0.1, 0, 1)
	local mof = tonumber(org.multiOrganFailure) or 0
	mof = Approach(mof, target, mulTime / (target > mof and CONFIG.mofRise or CONFIG.mofFall))
	org.multiOrganFailure = mof

	if org.heartstop then return end

	if mof > CONFIG.mofStressStart and hg.organism.AddCardiacStress then
		hg.organism.AddCardiacStress(org, mulTime * (mof - CONFIG.mofStressStart) * CONFIG.mofStressRate)
	end

	if mof > CONFIG.mofHeartStart then
		org.heart = Clamp((tonumber(org.heart) or 0) + mulTime * (mof - CONFIG.mofHeartStart) ^ 2 * CONFIG.mofHeartRate, 0, 1)
		local organ = mulTime * (mof - CONFIG.mofOrganStart) * CONFIG.mofOrganRate
		if organ > 0 then
			org.liver = min((tonumber(org.liver) or 0) + organ, 1)
			org.flank = min((tonumber(org.flank) or 0) + organ, 1)
		end
	end

	if hg.organism.AddSeizure then
		if acidosis > CONFIG.acidSeizureStart then
			hg.organism.AddSeizure(org, mulTime * (acidosis - CONFIG.acidSeizureStart) * CONFIG.acidSeizureRate)
		end
		if toxin > CONFIG.toxinSeizureStart then
			hg.organism.AddSeizure(org, mulTime * (toxin - CONFIG.toxinSeizureStart) * CONFIG.toxinSeizureRate)
		end
	end

	local rhythmRisk = max(Clamp((acidosis - 0.6) / 0.4, 0, 1), hyperK ^ 2, Clamp((mof - 0.7) / 0.3, 0, 1))
	if rhythmRisk > 0 and CurTime() >= (org.nextMetabolicFibrillationRoll or 0) then
		org.nextMetabolicFibrillationRoll = CurTime() + CONFIG.fibrillationRollInterval
		if math.Rand(0, 1) < rhythmRisk * CONFIG.fibrillationRollChance and hg.organism.StartFibrillation then
			hg.organism.StartFibrillation(org)
		end
	end
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
		org.septicShock, org.shockVasoplegia, org.renalFailure = 0, 0, 0
		org.metabolicHeartRate = tonumber(org.feverHeartRate) or 0
		org.acidosis, org.alkalosis, org.acidosisDrive, org.alkalosisDrive = 0, 0, 0, 0
		org.metabolicConsciousnessCap = 1
		org.acidContractility, org.catecholamineResponse, org.cerebralFlowMul, org.metabolicDrowsiness = 1, 1, 1, 0
		org.metabolicStaminaMul = max((1 - (tonumber(org.hemotransfusionshock) or 0)) * (1 - (org.feverK or 0) * 0.25), 0.2)
		return
	end
	if not org.alive then return end

	local thiamine = (tonumber(org.thiamine) or 0) > 0
	local severity, shock = updateSepsisOutputs(org)
	local hepatic, toxin = updateHepatic(org, mulTime, thiamine, shock)
	local renal, uremia = updateRenal(org, mulTime)
	local peritonitis = Clamp(tonumber(org.peritonitis) or 0, 0, 1)

	org.lactaid = min((tonumber(org.lactaid) or CONFIG.lactateNormal) + mulTime * (severity * CONFIG.sepsisLactate + shock * CONFIG.septicShockLactate), 20)
	if shock > 0 then
		org.wantToVomit = (org.wantToVomit or 0) + mulTime * shock * CONFIG.septicShockNausea
	end

	local ph = updateBicarb(org, mulTime, thiamine, severity, shock, hepatic, renal)
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
	if acidosis > 0 or uremia > 0 then
		org.wantToVomit = (org.wantToVomit or 0) + mulTime * (acidosis * CONFIG.acidosisNausea + uremia * CONFIG.uremiaNausea)
	end

	local paco2 = Clamp(tonumber(org.paco2) or CONFIG.normalPaco2, 10, 150)
	local hypocapnia = Clamp((CONFIG.hypocapniaStart - paco2) / CONFIG.hypocapniaRange, 0, 1)
	local hypercapnia = Clamp((paco2 - CONFIG.hypercapniaStart) / CONFIG.hypercapniaRange, 0, 1)
	org.acidContractility = 1 - acidosis * CONFIG.acidContractilityLoss
	org.catecholamineResponse = 1 - acidosis * CONFIG.acidCatecholamineLoss
	org.cerebralFlowMul = Clamp((1 - alkalosis * CONFIG.alkaliCerebralConstrict - hypocapnia * CONFIG.hypocapniaConstrict + hypercapnia * CONFIG.hypercapniaDilate)
		* (1 + acidosis * CONFIG.acidOxygenUnload - alkalosis * CONFIG.alkaliOxygenHold), 0.4, 1.2)
	org.metabolicDrowsiness = max(acidosis * 0.5, hypercapnia * 0.6, toxin * 0.5, uremia * 0.45, Clamp((severity - CONFIG.sepsisEncephalopathyStart) / CONFIG.sepsisEncephalopathyRange, 0, 1) * CONFIG.sepsisEncephalopathy)

	org.shockVasoplegia = Clamp(severity * 0.08 + shock * 0.45 + acidosis * 0.25 + max(hepatic - CONFIG.hepaticShockStart, 0) * 0.5 + peritonitis * CONFIG.peritonitisVasoplegia, 0, CONFIG.vasoplegiaMax)
	org.metabolicHeartRate = severity * CONFIG.sepsisHeartRate + acidosis * 15 + hepatic * 10 + peritonitis * CONFIG.peritonitisHeartRate + (tonumber(org.feverHeartRate) or 0)

	local acidCap = 1 - Clamp((CONFIG.acidosisComaStart - ph) / CONFIG.acidosisComaRange, 0, 1) * 0.9
	local alkaliCap = 1 - max(alkalosis - 0.5, 0) * 1.2
	local sepsisCap = 1 - shock * 0.5
	local hepaticCap = 1 - Clamp((toxin - 0.3) / 0.7, 0, 1) * 0.85
	local uremiaCap = 1 - Clamp((uremia - 0.5) / 0.5, 0, 1) * 0.6
	org.metabolicConsciousnessCap = min(acidCap, alkaliCap, sepsisCap, hepaticCap, uremiaCap)
	org.metabolicStaminaMul = max((1 - severity * 0.25) * (1 - acidosis * 0.45) * (1 - hepatic * 0.3) * (1 - renal * 0.2)
		* (1 - (org.feverK or 0) * 0.25) * (1 - (org.leukopenia or 0) * 0.2) * (1 - alkalosis * 0.3) * (1 - (tonumber(org.rhabdo) or 0) * 0.25)
		* (1 - peritonitis * 0.35) * (1 - uremia * 0.2), 0.2)

	updateTerminalCascade(org, mulTime, shock, acidosis, hepatic, toxin, max(renal, uremia))
	emitThoughts(owner, org)
end

local RAGE_CLEARS = {
	myoglobin = 2,
	rhabdo = 1,
	rhabdoAcid = 6,
	hyperkalemia = 1,
	hepaticFailure = 1,
	hepaticToxin = 1,
	multiOrganFailure = 1,
	citrate = CONFIG.citrateMax,
	hemotransfusionshock = 2,
	sepsisSource = 1,
	infection = 1,
	pneumonia = 1,
	lungWater = 1,
	clotBurden = 1,
	pulmonaryEmbolism = 1,
	aneurysm = 1,
	peritonitis = 1,
	uremia = 1,
}

function hg.organism.RageClearConditions(org, mulTime)
	local rate = mulTime / 20 * max(tonumber(org.berserk) or 0, 1)
	for key, range in pairs(RAGE_CLEARS) do
		org[key] = Approach(tonumber(org[key]) or 0, 0, rate * range)
	end
	org.rhabdoTime = 0
	org.bicarb = Approach(tonumber(org.bicarb) or CONFIG.normalBicarb, CONFIG.normalBicarb, rate * 20)
	org.lactaid = Approach(tonumber(org.lactaid) or CONFIG.lactateNormal, CONFIG.lactateNormal, rate * 20)
end

function hg.organism.UpdateSystemic(owner, org, mulTime, adrenalineStabilizer)
	hg.organism.UpdateInfection(owner, org, mulTime)
	hg.organism.UpdatePeritonitis(org, mulTime)
	hg.organism.UpdateSepsis(org, mulTime, adrenalineStabilizer)
	hg.organism.UpdateRhabdo(owner, org, mulTime)
	hg.organism.UpdateMetabolicShock(owner, org, mulTime)
end
