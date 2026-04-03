local max, halfValue = math.max, util.halfValue
--local Organism = hg.organism
hg.organism.module.liver = {}
local module = hg.organism.module.liver
module[1] = function(org)
	org.liver = 0
end

module[2] = function(owner, org, mulTime)
	if not org.alive or org.hearstop then return end

    local liver_health = 1 - org.liver

    -- Liver is destroyed
    if liver_health <= 0.01 then
        org.bleedingmul = 1.2 -- 20% more bleeding
        org.coagulation_multiplier = 0.1 -- 90% less coagulation
        org.blood_regeneration_multiplier = 0.2 -- 80% less blood regeneration
        return
    end

    -- Liver is severely damaged
    if liver_health < 0.25 then
        org.bleedingmul = 1.0
        org.coagulation_multiplier = 1.0
        org.blood_regeneration_multiplier = 1.0
        return
    end

    -- Healthy liver benefits
    org.bleedingmul = 1.0 - (liver_health * 0.2) -- Up to 20% bleed resistance
    org.coagulation_multiplier = 1.0 + (liver_health * 0.5) -- Up to 50% better coagulation
    org.blood_regeneration_multiplier = 1.0 + (liver_health * 0.3) -- up to 30% faster blood regeneration
end