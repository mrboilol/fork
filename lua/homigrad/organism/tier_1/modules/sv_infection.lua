hg.organism.module.infection = {}
local module = hg.organism.module.infection

module[1] = function(org)
    org.infection = 0
end

module[2] = function(owner, org, mulTime)
    if org.infection > 0 then
        if org.infection > 0.25 then
            org.infection = org.infection + (mulTime / 150)
        else
            org.infection = org.infection - (mulTime / 200)
        end
    end

    org.infection = math.max(org.infection, 0)

    if org.infection >= 0.75 then
        org.immobilization = math.min(org.immobilization + (org.infection - 0.75) * 0.1, 10)
        org.disorientation = math.min(org.disorientation + (org.infection - 0.75) * 0.05, 2)
        org.consciousness = org.consciousness - (org.infection - 0.75) * 0.01
    end

    if org.infection >= 1.0 then
        org.ischemia = org.ischemia + (org.infection - 1.0) * 0.02
    end
end
