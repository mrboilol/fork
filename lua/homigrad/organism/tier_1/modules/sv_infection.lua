hg.organism.module.infection = {}
local module = hg.organism.module.infection

module[1] = function(org)
    org.infection = 0
    org.infection_organs_affected = {} -- Track which organs are affected by sepsis
end

module[2] = function(owner, org, mulTime)
    if org.infection > 0 then
        -- Faster infection progression, especially once established
        if org.infection > 0.2 then -- Lowered threshold for progression
            local progression_rate = mulTime / 75 -- Faster growth (100 -> 75)
            -- Accelerated progression above 0.5
            if org.infection > 0.5 then
                progression_rate = progression_rate * (1 + (org.infection - 0.5) * 2)
            end
            org.infection = math.min(org.infection + progression_rate, 1.0) -- Cap at 1.0 for severe sepsis
        else
            org.infection = org.infection - (mulTime / 400) -- Slower natural decay
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

        -- Fever - raises body temperature
        local base_temp = 37.0 + (org.infection - 0.5) * 3
        local temp_spike = math.sin(CurTime() * 0.1) * (org.infection - 0.5) * 0.5 -- Temperature fluctuation
        org.temperature = math.max(org.temperature or 36.7, base_temp + temp_spike)

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

        -- High fever complications (additional temp rise from sepsis)
        org.temperature = math.min(org.temperature + (org.infection - 0.75) * 0.5, 40.5) -- Dangerous hyperthermia
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
