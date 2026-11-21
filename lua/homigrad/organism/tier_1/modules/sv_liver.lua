local max, halfValue = math.max, util.halfValue
--local Organism = hg.organism
hg.organism.module.liver = {}

function hg.organism.DrugClearanceMul(org, liverWeight, flankWeight, cap)
	local liverDamage = math.Clamp(tonumber(org.liver) or 0, 0, 1)
	local flankDamage = math.Clamp(tonumber(org.flank) or 0, 0, 1)
	return math.min(1 + (liverDamage * liverWeight + flankDamage * flankWeight) * (cap - 1), cap)
end
local module = hg.organism.module.liver
module[1] = function(org)
	org.liver = 0
	org.flank = 0
	org.bleedingmul = 1
	org.coagulation_multiplier = 1.2
	org.blood_regeneration_multiplier = 1.2
end

module[2] = function(owner, org, mulTime)
	if not org.alive then return end

	local liverDamage = math.Clamp(tonumber(org.liver) or 0, 0, 1)
	local flankDamage = math.Clamp(tonumber(org.flank) or 0, 0, 1)
	local hepaticFailure = math.Clamp(tonumber(org.hepaticFailure) or 0, 0, 1)
	org.bleedingmul = Lerp(liverDamage, 1, 1.5) * Lerp(flankDamage, 1, 1.25) * (1 + hepaticFailure * 0.35)
	org.coagulation_multiplier = Lerp(liverDamage, 1.2, 0.5) * Lerp(flankDamage, 1, 0.7) * (1 - hepaticFailure * 0.4)
	org.blood_regeneration_multiplier = Lerp(liverDamage, 1.2, 0.25) * Lerp(flankDamage, 1, 0.3)
end
