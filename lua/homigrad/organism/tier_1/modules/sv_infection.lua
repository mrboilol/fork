local Approach, max, min = math.Approach, math.max, math.min

hg.organism.Infection = hg.organism.Infection or {}
local Infection = hg.organism.Infection

Infection.Config = {
	growth = 0.0025,
	selfClear = 1 / 600,
	selfClearBelow = 0.15,
	sepsisStart = 0.25,
	sepsisSourceMul = 1.33,
	notifyAt = 0.3,

	openWoundGrace = 100,
	openWoundRollEvery = 45,
	openWoundChance = 0.06,
	openWoundMaxCount = 3,
	openWoundSeed = 0.12,

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
end

function Infection.Seed(org, amount)
	amount = tonumber(amount) or 0
	if not org or amount <= 0 or not infectionsEnabled() then return end
	if (tonumber(org.antibiotics) or 0) > 0 then return end

	org.infection = min(max(tonumber(org.infection) or 0, 0) + amount, 1)
end

function Infection.GiveAntibiotics(org, seconds)
	if not org then return end

	org.antibiotics = min((tonumber(org.antibiotics) or 0) + (seconds or CONFIG.antibioticDose), CONFIG.antibioticMax)
end

local function countOpenWounds(org)
	local count = 0
	for _, list in ipairs({org.wounds, org.arterialwounds}) do
		for _, wound in ipairs(list or {}) do
			if (wound[1] or 0) > 0 then count = count + 1 end
		end
	end

	return min(count, CONFIG.openWoundMaxCount)
end

local function rollOpenWounds(org, mulTime)
	local count = countOpenWounds(org)
	if count <= 0 then
		org.openWoundTime, org.openWoundRoll = 0, 0
		return
	end

	org.openWoundTime = (org.openWoundTime or 0) + mulTime
	if org.openWoundTime < CONFIG.openWoundGrace then return end

	org.openWoundRoll = (org.openWoundRoll or 0) + mulTime
	if org.openWoundRoll < CONFIG.openWoundRollEvery then return end

	org.openWoundRoll = 0
	if math.random() < CONFIG.openWoundChance * count then Infection.Seed(org, CONFIG.openWoundSeed) end
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

local function feedSepsis(org, infection, mulTime)
	local excess = infection - CONFIG.sepsisStart
	if excess <= 0 then return end

	if org.simpleMode then
		if hg.SimpleHealth and hg.SimpleHealth.AddContamination then
			hg.SimpleHealth.AddContamination(org, mulTime * excess * CONFIG.simpleContaminationGain)
		end
		return
	end

	org.sepsisSource = max(tonumber(org.sepsisSource) or 0, min(excess * CONFIG.sepsisSourceMul, 1))
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

	local antibiotics = tonumber(org.antibiotics) or 0
	if antibiotics > 0 then
		org.antibiotics = max(antibiotics - mulTime, 0)
		clearWithAntibiotics(org, mulTime)
		return
	end

	if infectionsEnabled() then rollOpenWounds(org, mulTime) end

	local infection = tonumber(org.infection) or 0
	if infection <= 0 then return end

	if infection < CONFIG.selfClearBelow then
		infection = max(infection - mulTime * CONFIG.selfClear, 0)
	else
		infection = min(infection + mulTime * CONFIG.growth * (1 + infection), 1)
	end
	org.infection = infection

	feedSepsis(org, infection, mulTime)
	notifyInfection(owner, org, infection)
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
