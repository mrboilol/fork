ZCBlood = ZCBlood or {}

local dropShapes = {1, 2, 3, 4, 6, 7, 8, 9, 10, 11}
local arterialShapes = {1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13}

ZCBlood.DecalMap = {}

for tier = 1, 5 do
	local normal, arterial = {}, {}
	for _, shape in ipairs(dropShapes) do normal[#normal + 1] = "zcblood/drops/drop" .. shape .. "_" .. tier end
	for _, shape in ipairs(arterialShapes) do arterial[#arterial + 1] = "zcblood/drops/adrop" .. shape .. "_" .. tier end

	game.AddDecal("ZCBlood.Normal" .. tier, normal)
	game.AddDecal("ZCBlood.Arterial" .. tier, arterial)
	ZCBlood.DecalMap["Normal.Blood2" .. tier] = "ZCBlood.Normal" .. tier
	ZCBlood.DecalMap["Arterial.Blood2" .. tier] = "ZCBlood.Arterial" .. tier
end

game.AddDecal("ZCBlood.PrintLeft", "zcblood/footprints/left")
game.AddDecal("ZCBlood.PrintRight", "zcblood/footprints/right")
