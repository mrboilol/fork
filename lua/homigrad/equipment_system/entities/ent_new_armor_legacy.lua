if not load_from_armor_file then return end
if not hg.armor or not hg.BuildZCityArmorSection then return end

local CLASSES = {0.5, 1.5, 4, 8, 12, 16, 22}
local SOFT = 0.9

local function nearestClass(protection)
	local best = CLASSES[1]
	for _, class in ipairs(CLASSES) do
		if math.abs(class - protection) < math.abs(best - protection) then best = class end
	end
	return best
end

local function plateMaterial(class)
	if class <= 1.5 then return 4.5 end
	if class <= 8 then return 1.2 end
	if class <= 12 then return 1.4 end
	return 3
end

local function renderData(data, female)
	local pos = data[3]
	local ang = data[4]
	local scale = data.scale or 1
	if female then
		local fp = data.femPos or vector_origin
		pos = pos + Vector(fp[1], -fp[3], fp[2])
		ang = data.femAng or ang
		scale = data.femscale or scale
	end
	return {
		Model = data.model or data[2],
		ModelSubMaterials = {},
		HideSubMaterails = {},
		Skin = 0,
		Bodygroups = "0000000000000",
		BoneMerge = not data.nobonemerge,
		ParentBone = data.bone,
		OffsetPos = pos,
		OffsetAng = ang,
		ModelSize = scale,
	}
end

local function register(key, data, templateName, class, plateMat)
	local stored = scripted_ents.GetStored(templateName)
	if not stored then return end
	local ENT = table.Copy(stored.t)
	ENT.PrintName = (hg.armorNames or {})[key] or key
	ENT.Spawnable = true
	ENT.AdminOnly = data.Spawnable ~= nil or data.AdminOnly or nil
	ENT.CarryMass = data.mass or ENT.CarryMass
	ENT.Model = data[2]
	ENT.ModelMaterial = ""
	ENT.IconOverride = (hg.armorIcons or {})[key]
	ENT.MaxPlateClass = class
	ENT.Male = renderData(data, false)
	ENT.FeMale = renderData(data, true)
	local built = {}
	for _, name in pairs(ENT.PlatesLinks) do
		if not built[name] then
			built[name] = true
			local punch = ENT[name] and ENT[name].NeedPunch
			if string.find(name, "Plate", 1, true) then
				ENT[name] = hg.BuildZCityArmorSection(plateMat, class, punch)
			else
				ENT[name] = hg.BuildZCityArmorSection(SOFT, math.min(class, 8), punch)
			end
		end
	end
	scripted_ents.Register(ENT, "ent_new_armor_legacy_" .. key)
end

for key, data in pairs(hg.armor.torso or {}) do
	local class = nearestClass(data.protection or 0)
	if class >= 12 then
		register(key, data, "ent_new_armor_vest4", class, plateMaterial(class))
	else
		register(key, data, "ent_new_armor_vest3", class, SOFT)
	end
end

for key, data in pairs(hg.armor.head or {}) do
	local class = nearestClass(data.protection or 0)
	if class < 1.5 then class = 1.5 end
	register(key, data, "ent_new_armor_helmet1", class, plateMaterial(class))
end
