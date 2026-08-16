local max, halfValue = math.max, util.halfValue
--local Organism = hg.organism
hg.organism.module.liver = {}
local module = hg.organism.module.liver
module[1] = function(org)
	org.liver = 0
	org.bleedingmul = 0.8
	org.coagulation_multiplier = 1.2
	org.blood_regeneration_multiplier = 1.2
end

module[2] = function(owner, org, mulTime)
	if not org.alive then return end

	-- Liver damage is stored from 0 (healthy) to 1 (destroyed). Keep the
	-- modifiers continuous so a tiny injury cannot abruptly erase the healthy
	-- liver bonus, and leave sv_blood to apply wound-specific multipliers.
	local liverDamage = math.Clamp(tonumber(org.liver) or 0, 0, 1)
	org.bleedingmul = Lerp(liverDamage, 0.8, 1.5)
	org.coagulation_multiplier = Lerp(liverDamage, 1.2, 0.5)
	org.blood_regeneration_multiplier = Lerp(liverDamage, 1.2, 0.25)
end
