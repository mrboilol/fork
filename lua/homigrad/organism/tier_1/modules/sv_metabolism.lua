local hg_hungersystem = CreateConVar("hg_hungersystem", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enables/disabled hunger system", 0, 1)
local hg_thirstsystem = CreateConVar("hg_thirstsystem", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enables/disabled thirst system", 0, 1)
local max, min, Round, Lerp, Clamp = math.max, math.min, math.Round, Lerp, math.Clamp
hg.organism.module.metabolism = {}
local module = hg.organism.module.metabolism

local FUEL_FULL_SATIETY = 30
local BASE_BURN = 0.25
local HEAT_BURN = 0.1
local DEMAND_BURN = 0.12
local THIAMINE_BURN_MUL = 2
local THIAMINE_REGEN_MUL = 2
local THIAMINE_STARVE_FADE = 1 / 60
local HYDRATION_BASE_DRAIN = 0.06
local HYDRATION_HEAT_DRAIN = 0.03
local HYDRATION_FEVER_DRAIN = 0.04
local THIRST_START = 35
local THIRST_RISE = 0.35
local THIRST_FALL = 2
local THIRST_PAIN_AT = 60

function hg.organism.TraitMul(org, key, default)
	local owner = org and org.owner
	if IsValid(owner) and owner.GetTraitMultiplier then return owner:GetTraitMultiplier(key, default or 1) end

	return default or 1
end
local TraitMul = hg.organism.TraitMul

module[1] = function(org)
	org.satiety = 100
	org.hungry = 0
	org.hungryDmgCd = 0
	org._satietyLastClimbed = 0
	org._starvingStartTime = 0
	org.hydration = 100
	org.thirst = 0
	org.thirstDmgCd = 0
	org.metabolicFuel = 1
	org.metabolicBurn = 0
end

local colorRed = Color(125,25,25)

local hungryThoughts = {
	"Mgh, I'm hungry...",
	"Some food would be great...",
	"I should eat something.",
}
local veryHungryThoughts = {
	"My stomach... Ugh...",
	"If I don't eat, I'll feel even worse...",
	"Stomach... Damn it... I feel sick.",
}
local thirstyThoughts = {
	"I'm thirsty...",
	"Some water would be great...",
	"I should drink something.",
}
local veryThirstyThoughts = {
	"My throat is so dry...",
	"If I don't drink, I'll feel even worse...",
	"Water... Damn it... I feel sick.",
}

module[2] = function(owner, org, timeValue)
	local hungerEnabled = hg_hungersystem:GetBool()
	local thirstEnabled = hg_thirstsystem:GetBool()
	local thiamine = (tonumber(org.thiamine) or 0) > 0

	if not hungerEnabled then
		org.satiety = 100
		org.hungry = 0
		org._prevSatiety = 100
		org._satietyLastClimbed = CurTime()
		org._starvingStartTime = nil
	end

	local satiety = org.satiety or 0
	local timeSinceClimbed = CurTime() - (org._satietyLastClimbed or 0)

	if hungerEnabled and satiety < 100 then
		org.satiety = min(satiety + timeValue * 0.05, 100)
	end

	if hungerEnabled and satiety > (org._prevSatiety or 0) then
		org._satietyLastClimbed = CurTime()
	end
	org._prevSatiety = org.satiety

	local hungerRate = 0

	if not hungerEnabled then
		hungerRate = 0
	elseif satiety > 60 and timeSinceClimbed < 45 then
		hungerRate = -timeValue * 0.1
	elseif satiety > 30 then
		hungerRate = -timeValue * 0.05
	elseif satiety > 0 then
		hungerRate = timeValue * 0.045
	else
		hungerRate = timeValue * 0.075
	end

	org.hungry = min(max((org.hungry or 0) + hungerRate, 0), 100)
	org.hungry = Round(org.hungry or 0, 3)

	local fuel = 1
	if hungerEnabled then
		fuel = Clamp((org.satiety or 0) / (FUEL_FULL_SATIETY * TraitMul(org, "fuel_need", 1)), 0, 1)
		if thiamine and fuel < 1 then fuel = math.sqrt(fuel) end
	end
	if not org.simpleMode then fuel = fuel * (1 - Clamp(tonumber(org.hepaticFailure) or 0, 0, 1) * 0.4) end
	org.metabolicFuel = fuel

	if hungerEnabled and org.isPly and owner:IsPlayer() and not org.otrub then
		if org.hungry > 70 then
			owner:Notify(veryHungryThoughts[math.random(#veryHungryThoughts)], 60, "hungry_severe", 0, nil, colorRed)
		elseif org.hungry > 40 then
			owner:Notify(hungryThoughts[math.random(#hungryThoughts)], 60, "hungry", 0)
		end
	end

	if hungerEnabled then
		if org.hungry > 70 then
			local painAdd = (org.hungry - 70) / 30 * timeValue * 2
			org.painadd = (org.painadd or 0) + painAdd

			if org.o2 and org.o2[1] then
				org.o2[1] = max(org.o2[1] - timeValue * 0.1, 0)
			end
		end

		if org.hungry > 90 then
			if not org._starvingStartTime then
				org._starvingStartTime = CurTime()
			end

			local starvingDuration = CurTime() - org._starvingStartTime
			if starvingDuration > 60 then
				local flatlineChance = math.min((starvingDuration - 60) / 300 * 0.02, 0.1)
				if math.random() < flatlineChance then
					org.heartstop = true
					org.lungsfunction = false
				end
			end
		else
			org._starvingStartTime = nil
		end

		if thiamine and fuel <= 0 then
			org.thiamine = math.Approach(org.thiamine, 0, timeValue * THIAMINE_STARVE_FADE)
		end
	end

	local heat = max(tonumber(org.heatProduction) or 0, 0)
	local demand = max((tonumber(org.metabolicDemand) or 1) - 1, 0)

	if thirstEnabled then
		local sweat = HYDRATION_BASE_DRAIN + heat * HYDRATION_HEAT_DRAIN + max(tonumber(org.fever) or 0, 0) * HYDRATION_FEVER_DRAIN
		org.hydration = Clamp((org.hydration or 100) - timeValue * sweat * TraitMul(org, "thirst_drain", 1), 0, 100)

		local target = Clamp((THIRST_START - org.hydration) / THIRST_START, 0, 1) * 100
		local rate = target > org.thirst and THIRST_RISE or THIRST_FALL
		org.thirst = math.Approach(org.thirst, target, timeValue * rate)

		org.thirstDmgCd = org.thirstDmgCd or 0
		if org.alive and org.thirstDmgCd < CurTime() and org.thirst > THIRST_PAIN_AT then
			org.painadd = (org.painadd or 0) + 20 * (org.thirst / 55)
			org.thirstDmgCd = CurTime() + (math.random(30, 45) - (org.thirst / 6.5))
		end

		if org.isPly and owner:IsPlayer() and not org.otrub then
			if org.thirst > 60 then
				owner:Notify(veryThirstyThoughts[math.random(#veryThirstyThoughts)], 60, "thirsty_severe", 0, nil, colorRed)
			elseif org.thirst > 30 then
				owner:Notify(thirstyThoughts[math.random(#thirstyThoughts)], 60, "thirsty", 0)
			end
		end
	else
		org.hydration = 100
		org.thirst = 0
	end
	org.thirst = Round(org.thirst or 0, 3)
	org.dehydrationCirculationPenalty = thirstEnabled and Clamp((org.thirst - 60) / 40, 0, 1) or 0

	if org.gut > 0.5 and not org.otrub and (org.cotard or 0) <= 0 and owner:IsPlayer() and org.satiety > 1 then
		if not org.randomPainSound or org.randomPainSound < CurTime() then
			org.randomPainSound = CurTime() + math.random(20,45)
			local gutSeverity = Clamp((org.gut - 0.5) / 0.5, 0, 1)
			hg.organism.AddPain(org, 6 + gutSeverity * 14)
		end
	end

	if org.satiety == 0 then
		org.metabolicBurn = 0
		return
	end

	if hungerEnabled then
		local burn = (BASE_BURN + heat * HEAT_BURN + demand * DEMAND_BURN) * TraitMul(org, "hunger_drain", 1)
		if thiamine then burn = burn * THIAMINE_BURN_MUL end
		org.metabolicBurn = burn
		org.satiety = min(max(org.satiety - timeValue * burn, 0), 100)
	end

	org.regeneratehp = (!((org.regeneratehp or 0) >= 1) and min( (org.regeneratehp or 0) + timeValue * (org.satiety/100) * (thiamine and THIAMINE_REGEN_MUL or 1), 1)) or 0
	if hg.organism.CanTouchHealth and hg.organism.CanTouchHealth(org) then
		local healthCeiling = owner:GetMaxHealth()
		if hg.organism.OrganSystemsEnabled() then
			healthCeiling = math.min(healthCeiling, org.vitalHealthCeiling or healthCeiling)
		end
		owner:SetHealth(min(owner:Health() + org.regeneratehp, healthCeiling))
	end
end
