hg.organism.module.infection = {}
local module = hg.organism.module.infection

local hg_infections = ConVarExists("hg_infections") and GetConVar("hg_infections") or CreateConVar("hg_infections",1,FCVAR_ARCHIVE + FCVAR_NOTIFY,"Enable infections system",0,1)

module[1] = function(org)
    org.infection = 0
    org.infection_organs_affected = {} -- Track which organs are affected by sepsis
end

module[2] = function(owner, org, mulTime)
    if not hg_infections:GetBool() then return end
    if org.infection > 0 then
        -- Faster infection progression, especially once established
        if org.infection > 0.25 then
            local progression_rate = mulTime / 600
            if org.infection > 0.5 then
                progression_rate = progression_rate * (1 + (org.infection - 0.5) * 0.5)
            end
            org.infection = math.min(org.infection + progression_rate, 1.5)
        else
            org.infection = org.infection - (mulTime / 200) -- Natural decay
        end
    end

    org.infection = math.max(org.infection, 0)

    -- Mild infection effects (0.3+)
    if org.infection >= 0.3 then
        org.immobilization = math.min(org.immobilization + (org.infection - 0.3) * 0.08, 12)
        org.disorientation = math.min(org.disorientation + (org.infection - 0.3) * 0.05, 3)
        org.stamina[1] = math.max(org.stamina[1] - (org.infection - 0.3) * 0.1, 0) -- Fatigue
    end

    -- Moderate infection - fever and delirium (0.5+)
    if org.infection >= 0.5 then
        org.consciousness = math.max(org.consciousness - (org.infection - 0.5) * 0.02, 0.3)
        org.painadd = math.min(org.painadd + (org.infection - 0.5) * 0.15, 75)

        -- Fever - raises body temperature toward a target based on infection severity
        local fever_intensity = (org.infection - 0.5) * 1.5
        if org.infection >= 0.75 then
            fever_intensity = fever_intensity + (org.infection - 0.75) * 1.0
        end
        local base_temp = 37.0 + fever_intensity
        local temp_spike = math.sin(CurTime() * 0.05) * (org.infection - 0.5) * 0.3 -- Temperature fluctuation
        org.temperature = math.max(org.temperature or 36.7, math.min(base_temp + temp_spike, 40.5))

        -- Delirium/confusion with fever
        if org.consciousness < 0.6 or (org.temperature and org.temperature > 38.5) then
            org.disorientation = math.min(org.disorientation + 1, 4)
        end
    end

    -- Severe infection - septic effects (0.75+)
    if org.infection >= 0.75 then
        org.ischemia = org.ischemia + (org.infection - 0.75) * 0.02

        -- Septic shock - more dangerous than regular shock
        local sepsis_shock_rate = (org.infection - 0.75) * 0.06
        org.shock = math.min(org.shock + sepsis_shock_rate, 100)

        -- Organ damage from sepsis
        local organs = {"heart", "lungs", "liver", "kidneys", "brain"}
        for _, organ in ipairs(organs) do
            if org[organ] and math.random() < (org.infection - 0.75) * 0.1 then
                org[organ] = math.min(org[organ] + 0.003 * mulTime, 1)
                if not org.infection_organs_affected[organ] then
                    org.infection_organs_affected[organ] = true
                    owner:Notify("I feel a burning pain in my " .. organ .. "...", 2, "infection", 3)
                end
            end
        end

        -- High fever complications handled in moderate infection block above
    end

    -- Critical sepsis (1.0+)
    if org.infection >= 1.0 then
        -- Multi-organ failure risk
        org.coagulation_multiplier = math.max((org.coagulation_multiplier or 1) - 0.01, 0.3) -- DIC - Disseminated Intravascular Coagulation

        -- Profound septic shock
        org.shock = math.min(org.shock + (org.infection - 1.0) * 0.1, 120)

        -- Severe organ damage
        for _, organ in ipairs({"heart", "brain"}) do
            if org[organ] then
                org[organ] = math.min(org[organ] + (org.infection - 1.0) * 0.005 * mulTime, 1)
            end
        end

        -- Risk of heart failure at max infection
        if org.infection >= 1.0 and math.random() < 0.025 then
            org.heartstop = true
            owner:Notify("My heart... it can't keep up...", 1, "infection", 5)
        end
    end
end
