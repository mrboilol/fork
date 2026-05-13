hg.organism.module.infection = {}
local module = hg.organism.module.infection

module[1] = function(org)
    org.infection = 0
end

module[2] = function(owner, org, mulTime)
    if org.infection > 0 then
        if org.infection > 0.25 then
            org.infection = math.min(org.infection + (mulTime / 150), 1.0) -- Cap at 1.0
        else
            org.infection = org.infection - (mulTime / 200)
        end
    end

    org.infection = math.max(org.infection, 0)

    if org.infection >= 0.5 then
        org.immobilization = math.min(org.immobilization + (org.infection - 0.5) * 0.05, 10)
        org.disorientation = math.min(org.disorientation + (org.infection - 0.5) * 0.03, 2)
    end

    if org.infection >= 0.75 then
        org.consciousness = math.max(org.consciousness - (org.infection - 0.75) * 0.01, 0)
        org.painadd = math.min(org.painadd + (org.infection - 0.75) * 0.1, 50)
    end

    if org.infection >= 1.0 then
        org.ischemia = org.ischemia + (org.infection - 1.0) * 0.02
        -- Sepsis effects when infection is severe
        org.shock = math.min(org.shock + (org.infection - 1.0) * 0.05, 80)
        org.fever = math.max(org.fever or 36.7, 36.7 + (org.infection - 1.0) * 2)
    end
end
