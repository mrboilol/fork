--
local hg_hungersystem = CreateConVar("hg_hungersystem", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enables/disabled hunger system", 0, 1)
local hg_thirstsystem = CreateConVar("hg_thirstsystem", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enables/disabled thirst system", 0, 1)
local max, min, Round, Lerp, halfValue2 = math.max, math.min, math.Round, Lerp, util.halfValue2
--local Organism = hg.organism
hg.organism.module.metabolism = {}
local module = hg.organism.module.metabolism
module[1] = function(org)
	org.satiety = 100
    org.hungry = 0
    org.hungryDmgCd = 0
    org._satietyLastClimbed = 0
    org._starvingStartTime = 0
    org.hydration = 100
    org.thirst = 0
    org.thirstDmgCd = 0
end

local colorRed = Color(125,25,25)
module[2] = function(owner, org, timeValue)
    local hungerEnabled = hg_hungersystem:GetBool()

    if not hungerEnabled then
        -- Disabled hunger means the player remains completely fed.
        org.satiety = 100
        org.hungry = 0
        org._prevSatiety = 100
        org._satietyLastClimbed = CurTime()
        org._starvingStartTime = nil
    end

    -- Satiety mechanics
    local satiety = org.satiety or 0
    local timeSinceClimbed = CurTime() - (org._satietyLastClimbed or 0)
    
    -- Satiety slowly regains over time
    if hungerEnabled and satiety < 100 then
        org.satiety = min(satiety + timeValue * 0.05, 100)
    end
    
    -- Track when satiety increases (eating)
    if hungerEnabled and satiety > (org._prevSatiety or 0) then
        org._satietyLastClimbed = CurTime()
    end
    org._prevSatiety = org.satiety
    
    -- Hunger mechanics based on satiety
    local hungerRate = 0
    
    -- If satiety is high (>60) and recently climbed (<2 minutes), reduce hunger
    if not hungerEnabled then
        hungerRate = 0
    elseif satiety > 60 and timeSinceClimbed < 45 then
        hungerRate = -timeValue * 0.1
    -- If satiety is moderate (30-60), slowly reduce hunger
    elseif satiety > 30 then
        hungerRate = -timeValue * 0.05
    -- If satiety is low (0-30), start getting hungry
    elseif satiety > 0 then
        hungerRate = timeValue * 0.045
    -- If satiety is 0, get hungry at higher pace
    else
        hungerRate = timeValue * 0.075
    end
    
    org.hungry = min(max((org.hungry or 0) + hungerRate, 0), 100)
    org.hungry = Round(org.hungry or 0, 3)
    
    -- Pain and O2 loss when really hungry (>70) - only if hunger system enabled
    if hungerEnabled then
        if org.hungry > 70 then
            local painAdd = (org.hungry - 70) / 30 * timeValue * 2
            org.painadd = (org.painadd or 0) + painAdd
            
            -- Slight O2 loss
            if org.o2 and org.o2[1] then
                org.o2[1] = max(org.o2[1] - timeValue * 0.1, 0)
            end
        end
        
        -- Flatlining chance when starving (>90) for a good minute
        if org.hungry > 90 then
            if not org._starvingStartTime then
                org._starvingStartTime = CurTime()
            end
            
            local starvingDuration = CurTime() - org._starvingStartTime
            if starvingDuration > 60 then
                -- Chance increases the longer you starve
                local flatlineChance = math.min((starvingDuration - 60) / 300 * 0.02, 0.1)
                if math.random() < flatlineChance then
                    org.heartstop = true
                    org.lungsfunction = false
                end
            end
        else
            org._starvingStartTime = nil
        end
    end

    if org.hydration <= 0 and hg_thirstsystem:GetBool() then
        org.thirst = min(max(org.thirst + timeValue * 0.015, 0), 100)
        org.thirstDmgCd = org.thirstDmgCd or 0
        if org.alive and org.thirstDmgCd < CurTime() and org.thirst > 35 then
            org.painadd = org.painadd + 20 * (org.thirst / 55)
            org.thirstDmgCd = CurTime() + (math.random(30, 45) - (org.thirst / 6.5))
            -- Pain/damage cadence remains intermittent; the circulation penalty
            -- itself is updated continuously below from the current thirst state.
        end
    else
        org.thirst = min(max(org.thirst - timeValue * 2, 0), 100)
    end
    org.thirst = Round(org.thirst or 0, 3)
    org.dehydrationCirculationPenalty = (hg_thirstsystem:GetBool() and org.hydration <= 0)
        and math.Clamp((org.thirst - 60) / 40, 0, 1) or 0

	if (org.intestines > 0.5 or org.stomach > 0.5) and not org.otrub and owner:IsPlayer() and org.satiety > 1 then
		if not org.randomPainSound or org.randomPainSound < CurTime() then
			org.randomPainSound = CurTime() + math.random(20,45)
			org.painadd = org.painadd + 20
			//owner:TakeDamage(5,owner,owner)
		end
    end

    if org.satiety == 0 then return end

    if hungerEnabled then
        org.satiety = min(max(org.satiety - timeValue * 0.25, 0), 100)
    end
    -- Food supports healing/regeneration but does not instantly manufacture
    -- circulating blood. Blood-volume recovery is owned by sv_blood.
    org.regeneratehp = (!((org.regeneratehp or 0) >= 1) and min( (org.regeneratehp or 0) + timeValue * (org.satiety/100), 1)) or 0
    if hg.organism.CanTouchHealth and hg.organism.CanTouchHealth(org) then
        local healthCeiling = owner:GetMaxHealth()
        if hg.organism.OrganSystemsEnabled() then
            healthCeiling = math.min(healthCeiling, org.vitalHealthCeiling or healthCeiling)
        end
        owner:SetHealth(min(owner:Health() + org.regeneratehp, healthCeiling))
    end
end
