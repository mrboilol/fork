local Clamp, Approach, max, min = math.Clamp, math.Approach, math.max, math.min

hg.organism.Pneumonia = hg.organism.Pneumonia or {}
local Pneumonia = hg.organism.Pneumonia

Pneumonia.Config = {
	aspirateTime = 35,
	aspirateOtrubMul = 1.6,
	drainAwake = 1 / 240,
	drainOtrub = 1 / 700,
	lungFailAt = 0.9,

	seedFromWater = 0.08,
	seedRate = 1 / 300,
	growthMul = 0.9,
	waterGrowthMul = 1.5,
	antibioticClear = 1 / 90,

	lungDamageStart = 0.4,
	lungDamageTime = 900,
	lungDamageCap = 0.7,

	coughEvery = {12, 28},
}
local CONFIG = Pneumonia.Config

local WATER_THOUGHTS = {
	"I swallowed so much water... my chest is heavy.",
	"Every breath gurgles.",
}
local PNEUMONIA_THOUGHTS = {
	"My chest burns when I breathe... I'm burning up.",
	"I can't stop coughing. Something's wrong with my lungs.",
}

local function infectionsEnabled()
	local cvar = GetConVar("hg_infections")
	return not cvar or cvar:GetBool()
end

local function notify(owner, org, list, id)
	if not org.isPly or org.otrub or not IsValid(owner) or not owner.Notify then return end
	owner:Notify(list[math.random(#list)], 45, id, 0, nil, Color(170, 200, 210))
end

function hg.organism.ResetPneumonia(org)
	org.lungWater = 0
	org.pneumonia = 0
	org.nextPneumoniaCough = nil
	org.lungWaterNotified = nil
	org.pneumoniaNotified = nil
end

function hg.organism.GetLungWater(org)
	return Clamp(tonumber(org.lungWater) or 0, 0, 1)
end

function hg.organism.GetPneumonia(org)
	return Clamp(tonumber(org.pneumonia) or 0, 0, 1)
end

local function updateAspiration(org, timeValue, submerged)
	local water = hg.organism.GetLungWater(org)
	if submerged and not org.holdingbreath then
		local mul = org.otrub and CONFIG.aspirateOtrubMul or 1
		water = min(water + timeValue / CONFIG.aspirateTime * mul, 1)
	elseif water > 0 and not submerged then
		water = max(water - timeValue * (org.otrub and CONFIG.drainOtrub or CONFIG.drainAwake), 0)
	end
	org.lungWater = water
	return water
end

local function updateInfection(org, timeValue, water)
	local pneumonia = hg.organism.GetPneumonia(org)

	if (tonumber(org.antibiotics) or 0) > 0 then
		pneumonia = max(pneumonia - timeValue * CONFIG.antibioticClear, 0)
	else
		if water > CONFIG.seedFromWater and infectionsEnabled() then
			pneumonia = pneumonia + timeValue * water * CONFIG.seedRate
		end
		pneumonia = hg.organism.Infection.Fight(org, pneumonia, timeValue, CONFIG.growthMul + water * CONFIG.waterGrowthMul)
	end

	pneumonia = Clamp(pneumonia, 0, 1)
	org.pneumonia = pneumonia
	return pneumonia
end

local function applyPneumoniaEffects(org, timeValue, pneumonia)
	local damageK = pneumonia - CONFIG.lungDamageStart
	if damageK > 0 then
		local add = timeValue * damageK / CONFIG.lungDamageTime
		for _, lung in ipairs({org.lungsL, org.lungsR}) do
			if lung[1] < CONFIG.lungDamageCap then
				lung[1] = min(lung[1] + add, CONFIG.lungDamageCap)
			end
		end
	end
end

local function cough(owner, org, water, pneumonia)
	local severity = max(water, pneumonia)
	if severity < 0.1 or org.otrub or not IsValid(owner) then
		org.nextPneumoniaCough = nil
		return
	end

	local now = CurTime()
	if not org.nextPneumoniaCough then
		org.nextPneumoniaCough = now + math.Rand(3, 8)
		return
	end
	if org.nextPneumoniaCough > now then return end

	org.nextPneumoniaCough = now + math.Rand(CONFIG.coughEvery[1], CONFIG.coughEvery[2]) * (1.3 - severity * 0.6)
	if owner:WaterLevel() >= 3 then return end

	owner:EmitSound("homigrad/player/male/male_cough" .. math.random(5) .. ".ogg", 55 + math.Round(severity * 15))
	org.o2[1] = max(org.o2[1] - severity * 2, 0)
	if water > 0 then
		org.lungWater = max(water - 0.03, 0)
	end
end

local function updateThoughts(owner, org, water, pneumonia)
	if water < 0.1 then
		org.lungWaterNotified = nil
	elseif water >= 0.2 and not org.lungWaterNotified then
		org.lungWaterNotified = true
		notify(owner, org, WATER_THOUGHTS, "lung_water")
	end

	if pneumonia < 0.15 then
		org.pneumoniaNotified = nil
	elseif pneumonia >= 0.3 and not org.pneumoniaNotified then
		org.pneumoniaNotified = true
		notify(owner, org, PNEUMONIA_THOUGHTS, "pneumonia")
	end
end

function hg.organism.UpdatePneumonia(owner, org, timeValue, submerged)
	if org.simpleMode or not org.alive then return end

	local water = updateAspiration(org, timeValue, submerged)
	local pneumonia = updateInfection(org, timeValue, water)
	applyPneumoniaEffects(org, timeValue, pneumonia)
	cough(owner, org, org.lungWater, pneumonia)
	updateThoughts(owner, org, org.lungWater, pneumonia)
end
