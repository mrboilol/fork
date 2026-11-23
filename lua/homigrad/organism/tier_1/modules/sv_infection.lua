local Clamp, Approach, max, min = math.Clamp, math.Approach, math.max, math.min

hg.organism.Infection = hg.organism.Infection or {}
local Infection = hg.organism.Infection
hg.organism.Immune = Infection

Infection.Config = {
	wbcNormal = 7.5,
	wbcMin = 0.2,
	wbcMax = 22,
	wbcLow = 4,
	wbcCritical = 1.5,
	marrowTime = 120,
	leukocytosisMax = 6,
	woundDrain = 0.004,
	woundMaxCount = 6,
	bloodLossDrain = 3,
	fightCost = 6,
	sepsisDrain = 0.012,

	growth = 0.0025,
	killRate = 0.0035,
	feverKillBonus = 0.3,
	containBase = 0.2,
	containWbc = 0.3,
	sepsisSourceMul = 1.33,
	leukopeniaBacteremia = 0.5,
	feverSepsisStart = 39.5,
	feverSepsisRate = 0.002,
	notifyAt = 0.3,

	feverMax = 3.6,
	feverPneumoniaMul = 0.8,
	feverSepsisMul = 0.5,
	feverMinStrength = 0.3,
	septicColdStart = 1.4,
	septicCold = -1.8,
	feverStart = 37.5,
	feverRange = 3,
	feverHeartRate = 9,
	feverPressor = 0.12,

	openWoundGrace = 100,
	openWoundRollEvery = 45,
	openWoundChance = 0.06,
	openWoundMaxCount = 3,
	openWoundSeed = 0.12,
	leukopeniaSeedMul = 3,

	weaponContaminationTime = 600,
	weaponChance = 0.3,
	weaponSeed = 0.15,
	weaponSepticMul = 2,
	contactTypes = DMG_SLASH + DMG_CLUB,

	antibioticDose = 180,
	antibioticMax = 420,
	antibioticInfectionClear = 1 / 45,
	antibioticSepsisClear = 1 / 40,
	antibioticSourceClear = 1 / 30,

	simpleContaminationGain = 0.01,
	simpleAntibioticClear = 0.05,
}
local CONFIG = Infection.Config

local INFECTION_THOUGHTS = {
	"This wound is throbbing and burning...",
	"The wound smells wrong...",
	"It's hot and swollen around the cut...",
}

local function infectionsEnabled()
	local cvar = GetConVar("hg_infections")

	return not cvar or cvar:GetBool()
end

function Infection.Init(org)
	org.infection = 0
	org.antibiotics = 0
	org.openWoundTime = 0
	org.openWoundRoll = 0
	org.infectionNotified = nil
	org.wbc = CONFIG.wbcNormal
	org.immuneStrength = 1
	org.leukopenia = 0
	org.fever = 0
	org.feverK = 0
	org.feverPressor = 0
	org.immuneBloodPrev = nil
end

function Infection.GetSickness(org)
	return Clamp(max(
		(org.feverK or 0) * 0.8,
		min(tonumber(org.hemotransfusionshock) or 0, 2) * 0.45,
		(org.leukopenia or 0) * 0.4,
		(tonumber(org.pneumonia) or 0) * 0.5,
		(tonumber(org.hepaticToxin) or 0) * 0.6,
		(tonumber(org.acidosis) or 0) * 0.5
	), 0, 1)
end

function Infection.GetStrength(org)
	return Clamp((tonumber(org.wbc) or CONFIG.wbcNormal) / CONFIG.wbcNormal, 0, 2)
end

function Infection.Seed(org, amount)
	amount = tonumber(amount) or 0
	if not org or amount <= 0 or not infectionsEnabled() then return end
	if (tonumber(org.antibiotics) or 0) > 0 then return end

	org.infection = min(max(tonumber(org.infection) or 0, 0) + amount, 1)
end

function Infection.Contaminate(org, amount, bacteremia)
	if not org then return end
	Infection.Seed(org, amount)
	bacteremia = tonumber(bacteremia) or 0
	if bacteremia > 0 then org.sepsisSource = min((tonumber(org.sepsisSource) or 0) + bacteremia, 1) end
end

function Infection.Fight(org, value, mulTime, growthMul)
	value = Clamp(tonumber(value) or 0, 0, 1)
	if value <= 0 then return 0 end

	local strength = org.immuneStrength or Infection.GetStrength(org)
	local growth = mulTime * CONFIG.growth * (growthMul or 1) * (1 + value)
	local kill = min(mulTime * CONFIG.killRate * strength * (1 + (org.feverK or 0) * CONFIG.feverKillBonus), value + growth)
	org.wbc = max((tonumber(org.wbc) or CONFIG.wbcNormal) - kill * CONFIG.fightCost, CONFIG.wbcMin)

	return Clamp(value + growth - kill, 0, 1)
end

function Infection.GiveAntibiotics(org, seconds)
	if not org then return end

	org.antibiotics = min((tonumber(org.antibiotics) or 0) + (seconds or CONFIG.antibioticDose), CONFIG.antibioticMax)
end

local function countOpenWounds(org, cap)
	local count = 0
	for _, list in ipairs({org.wounds, org.arterialwounds}) do
		for _, wound in ipairs(list or {}) do
			if (wound[1] or 0) > 0 then count = count + 1 end
		end
	end

	return min(count, cap)
end

local function rollOpenWounds(org, mulTime)
	local count = countOpenWounds(org, CONFIG.openWoundMaxCount)
	if count <= 0 then
		org.openWoundTime, org.openWoundRoll = 0, 0
		return
	end

	org.openWoundTime = (org.openWoundTime or 0) + mulTime
	if org.openWoundTime < CONFIG.openWoundGrace then return end

	org.openWoundRoll = (org.openWoundRoll or 0) + mulTime
	if org.openWoundRoll < CONFIG.openWoundRollEvery then return end

	org.openWoundRoll = 0
	local weak = 1 + (org.leukopenia or 0) * CONFIG.leukopeniaSeedMul
	if math.random() < CONFIG.openWoundChance * count * weak then Infection.Seed(org, CONFIG.openWoundSeed * weak) end
end

local function updateWbc(org, mulTime, load)
	local wbc = Clamp(tonumber(org.wbc) or CONFIG.wbcNormal, CONFIG.wbcMin, CONFIG.wbcMax)

	local blood = tonumber(org.blood) or 5000
	local bloodLost = max((org.immuneBloodPrev or blood) - blood, 0)
	org.immuneBloodPrev = blood

	local marrow = (1 - Clamp(tonumber(org.hepaticFailure) or 0, 0, 1) * 0.4)
		* (1 - Clamp(tonumber(org.septicShock) or 0, 0, 1) * 0.7)
		* Clamp(tonumber(org.circulatoryO2Reserve) or 1, 0.3, 1)
	local target = CONFIG.wbcNormal + min(load, 1) * CONFIG.leukocytosisMax
	if wbc < target then
		wbc = wbc + mulTime * (target - wbc) / CONFIG.marrowTime * marrow
	else
		wbc = Approach(wbc, target, mulTime * (wbc - target) / CONFIG.marrowTime)
	end

	local wounds = countOpenWounds(org, CONFIG.woundMaxCount)
	local sepsis = min(tonumber(org.hemotransfusionshock) or 0, 2)
	wbc = wbc - mulTime * (wounds * CONFIG.woundDrain + sepsis * CONFIG.sepsisDrain)
		- bloodLost / max(tonumber(org.maxblood) or 5000, 1) * CONFIG.bloodLossDrain

	wbc = Clamp(wbc, CONFIG.wbcMin, CONFIG.wbcMax)
	org.wbc = wbc
	org.immuneStrength = Clamp(wbc / CONFIG.wbcNormal, 0, 2)
	org.leukopenia = Clamp((CONFIG.wbcLow - wbc) / (CONFIG.wbcLow - CONFIG.wbcCritical), 0, 1)

	return wounds
end

local function updateFever(org)
	local strength = Clamp(org.immuneStrength or 1, CONFIG.feverMinStrength, 1)
	local sepsis = Clamp(tonumber(org.hemotransfusionshock) or 0, 0, 2)
	local load = (tonumber(org.infection) or 0) + (tonumber(org.pneumonia) or 0) * CONFIG.feverPneumoniaMul + min(sepsis, 1) * CONFIG.feverSepsisMul
	local fever = min(load, 1) * CONFIG.feverMax * strength
	if sepsis > CONFIG.septicColdStart then
		fever = Lerp((sepsis - CONFIG.septicColdStart) / (2 - CONFIG.septicColdStart), fever, CONFIG.septicCold)
	end
	org.fever = fever

	local temperature = tonumber(org.temperature) or 36.7
	local feverK = Clamp((temperature - CONFIG.feverStart) / CONFIG.feverRange, 0, 1)
	org.feverK = feverK
	org.feverPressor = feverK * CONFIG.feverPressor * (1 - Clamp(tonumber(org.shockVasoplegia) or 0, 0, 1))
	org.feverHeartRate = max(temperature - 37.2, 0) * CONFIG.feverHeartRate

	return temperature
end

local function clearWithAntibiotics(org, mulTime)
	org.infection = Approach(tonumber(org.infection) or 0, 0, mulTime * CONFIG.antibioticInfectionClear)
	org.medical_infection = Approach(tonumber(org.medical_infection) or 0, 0, mulTime / 30)
	org.sepsisSource = Approach(tonumber(org.sepsisSource) or 0, 0, mulTime * CONFIG.antibioticSourceClear)

	if org.simpleMode then
		local state = hg.SimpleHealth and hg.SimpleHealth.GetState and hg.SimpleHealth.GetState(org)
		if state and state.contamination then
			state.contamination = max(state.contamination - mulTime * CONFIG.simpleAntibioticClear, 0)
		end
		return
	end

	org.hemotransfusionshock = max((tonumber(org.hemotransfusionshock) or 0) - mulTime * CONFIG.antibioticSepsisClear, 0)
end

local function feedSepsis(org, load, wounds, temperature, mulTime)
	local contain = CONFIG.containBase + CONFIG.containWbc * min(org.immuneStrength or 1, 1)
	local spill = max(load - contain, 0) * CONFIG.sepsisSourceMul
	local leukopenia = org.leukopenia or 0
	if leukopenia > 0 then
		spill = max(spill, leukopenia * CONFIG.leukopeniaBacteremia * ((wounds > 0 or load > 0.05) and 1 or 0.3))
	end
	local feverSeed = load > 0.1 and max(temperature - CONFIG.feverSepsisStart, 0) * CONFIG.feverSepsisRate or 0
	if spill <= 0 and feverSeed <= 0 then return end

	if org.simpleMode then
		if hg.SimpleHealth and hg.SimpleHealth.AddContamination then
			hg.SimpleHealth.AddContamination(org, mulTime * (spill * CONFIG.simpleContaminationGain + feverSeed))
		end
		return
	end

	org.sepsisSource = min(max(tonumber(org.sepsisSource) or 0, spill) + mulTime * feverSeed, 1)
end

local function notifyInfection(owner, org, infection)
	if infection < CONFIG.notifyAt * 0.5 then
		org.infectionNotified = nil
		return
	end
	if org.infectionNotified or infection < CONFIG.notifyAt then return end
	if not org.isPly or org.otrub or not IsValid(owner) or not owner.Notify then return end

	owner:Notify(INFECTION_THOUGHTS[math.random(#INFECTION_THOUGHTS)], 45, "infection", 0, nil, Color(200, 190, 140))
	org.infectionNotified = true
end

function hg.organism.UpdateInfection(owner, org, mulTime)
	if not org.alive then return end

	local load = (tonumber(org.infection) or 0) + (tonumber(org.pneumonia) or 0)
	local wounds = updateWbc(org, mulTime, load)
	local temperature = updateFever(org)

	local antibiotics = tonumber(org.antibiotics) or 0
	if antibiotics > 0 then
		org.antibiotics = max(antibiotics - mulTime, 0)
		clearWithAntibiotics(org, mulTime)
		return
	end

	if infectionsEnabled() then rollOpenWounds(org, mulTime) end

	local infection = tonumber(org.infection) or 0
	if infection > 0 then
		infection = Infection.Fight(org, infection, mulTime)
		org.infection = infection
		notifyInfection(owner, org, infection)
	end

	feedSepsis(org, infection + (tonumber(org.pneumonia) or 0), wounds, temperature, mulTime)
end

function hg.organism.UpdateSepsis(org, mulTime, adrenalineStabilizer)
	if org.simpleMode then return end

	local bloodLost = max((org.sepsisBloodPrev or org.blood) - org.blood, 0)
	org.sepsisBloodPrev = org.blood

	local thiamine = (org.thiamine or 0) > 0
	local txa = (org.tranexamic_acid or 0) > 0

	local organLoad = (org.liver or 0) + (org.flank or 0)
	local organHealed = max((org.sepsisOrganPrev or organLoad) - organLoad, 0)
	local source = org.sepsisSource or 0
	if source > 0 then
		source = max(source - organHealed * 1.5 - mulTime * (1 / 600 + (thiamine and 1 / 20 or 0)), 0)
		org.sepsisSource = source
		local cap = source * 1.5
		if org.hemotransfusionshock < cap then
			org.hemotransfusionshock = min(org.hemotransfusionshock + mulTime * source * 0.015, cap)
		end
	end

	local sepsis = org.hemotransfusionshock
	if sepsis <= 0 then
		org.sepsisOrganPrev = organLoad
		return
	end
	local severity = min(sepsis, 2)
	local shock = Clamp((severity - 0.9) / 0.8, 0, 1)
	local organDamage = mulTime * max(severity - 0.5, 0) * (thiamine and 0.5 or 1) * (txa and 0.5 or 1)

	org.internalBleed = org.internalBleed + mulTime * severity * 0.3 * (txa and 0.5 or 1)
	org.liver = min(org.liver + organDamage * 0.012, 1)
	org.flank = min((org.flank or 0) + organDamage * 0.012, 1)
	org.heart = min(org.heart + organDamage * 0.006, 1)
	if not adrenalineStabilizer and not thiamine and not txa then
		org.ischemia = org.ischemia + mulTime * severity * 0.3
	end

	if shock > 0 and not thiamine then
		sepsis = min(sepsis + mulTime * shock * 0.006, 2)
	end

	local immune = Clamp(org.immuneStrength or 1, 0.25, 1.25)
	local clearance = mulTime * ((source > 0 and 0 or 1 / 150) * (1 - shock * 0.85) * immune + (thiamine and 1 / 30 or 0) + (txa and 1 / 30 or 0)) + bloodLost / 600
	org.hemotransfusionshock = max(sepsis - clearance, 0)
	org.sepsisOrganPrev = (org.liver or 0) + (org.flank or 0)
end

local function getContactWeapon(dmgInfo)
	local inflictor = dmgInfo:GetInflictor()
	if IsValid(inflictor) and inflictor:IsWeapon() then return inflictor end

	local attacker = dmgInfo:GetAttacker()
	if IsValid(attacker) and (attacker:IsPlayer() or attacker:IsNPC()) then
		local active = attacker:GetActiveWeapon()
		if IsValid(active) then return active end
	end
end

hook.Add("HomigradDamage", "hg/infection/contaminated-weapon", function(victim, dmgInfo)
	if not infectionsEnabled() or not dmgInfo:IsDamageType(CONFIG.contactTypes) then return end

	local org = IsValid(victim) and victim.organism
	if not org or not org.alive then return end

	local wep = getContactWeapon(dmgInfo)
	if not IsValid(wep) then return end

	local now = CurTime()
	local load = wep.hgContaminationLoad or 1
	if (wep.hgContaminatedUntil or 0) > now and wep.hgContaminationSource ~= org and math.random() < CONFIG.weaponChance * load then
		Infection.Seed(org, CONFIG.weaponSeed * load)
	end

	if dmgInfo:IsDamageType(DMG_SLASH) or (tonumber(org.bleed) or 0) > 0 then
		local septic = max(tonumber(org.infection) or 0, min(tonumber(org.hemotransfusionshock) or 0, 2) * 0.5)
		wep.hgContaminatedUntil = now + CONFIG.weaponContaminationTime
		wep.hgContaminationSource = org
		wep.hgContaminationLoad = 1 + min(septic, 1) * (CONFIG.weaponSepticMul - 1)
	end
end)
