local ENTITY = FindMetaTable("Entity")

hg.EngineTranslateBoneToPhysBone = hg.EngineTranslateBoneToPhysBone or ENTITY.TranslateBoneToPhysBone
local engineTranslate = hg.EngineTranslateBoneToPhysBone

hg.physBoneMapCache = hg.physBoneMapCache or {}
local mapCache = hg.physBoneMapCache

local function getMap(ent, count)
	local key = tostring(ent:GetModel()) .. "|" .. count
	local map = mapCache[key]
	if map then return map end

	map = {}
	for i = 0, count - 1 do
		local bone = ent:TranslatePhysBoneToBone(i)
		if isnumber(bone) and bone >= 0 then map[bone] = i end
	end
	mapCache[key] = map
	return map
end

function ENTITY:TranslateBoneToPhysBone(bone)
	local count = isnumber(bone) and bone >= 0 and self:GetPhysicsObjectCount() or 0
	if count <= 1 then return engineTranslate(self, bone) end

	local map = getMap(self, count)
	local current, guard = bone, 0
	while isnumber(current) and current >= 0 and guard < 256 do
		local phys = map[current]
		if phys then return phys end
		current = self:GetBoneParent(current)
		guard = guard + 1
	end

	return engineTranslate(self, bone)
end
