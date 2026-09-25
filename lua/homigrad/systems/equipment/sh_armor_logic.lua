function hg.GetArmorItemState(ent, armor, key, default)
	if not IsValid(ent) then return default end
	local states = SERVER and ent.armor_states or ent:GetNetVar("ArmorStates", ent.armor_states or {})
	local state = states and states[armor]
	if not state and ent.name == armor then state = SERVER and ent.armorState or ent:GetNetVar("ArmorItemState", {}) end
	if not state or state[key] == nil then return default end
	return state[key]
end

hg.ArmorPlateMaterials = {
	ceramic = {mass = 2.5, protection = 1},
	steel = {mass = 4, protection = 0.9},
	polyethylene = {mass = 1.8, protection = 0.8},
	uhmwpe = {mass = 1.8, protection = 0.95},
	uhmwpe_ceramic = {mass = 2.2, protection = 1.05},
	uhmwpe_arsteel = {mass = 2.8, protection = 1},
	titan = {mass = 3, protection = 1},
	arsteel = {mass = 3.6, protection = 0.95},
	kevlar = {mass = 1.5, protection = 0.7},
	kevlar_ceramic = {mass = 2, protection = 0.9},
	kevlar_arsteel = {mass = 2.6, protection = 0.85},
	kevlar_titan = {mass = 2.4, protection = 0.85},
	riot = {mass = 3.2, protection = 0.12, melee = 2.5, stab = 0.45},
}

hg.ArmorPlateLevels = {[1] = 6, [2] = 8, [3] = 10, [4] = 12, [5] = 15, [6] = 17}
hg.ArmorProtectionLevels = {stab = {ballistic = 0.12, melee = 0.8, stab = 2}}

function hg.GetArmorMaxCondition(ent, placement, armor)
	local data = hg.armor[placement] and hg.armor[placement][armor]
	local durable = placement == "head" or placement == "face"
	if data and data.durabilityArmor ~= nil then durable = data.durabilityArmor end
	local base = durable and (data and data.durability or 27) or (data and data.health or 1.5)
	return base * math.Clamp(tonumber(hg.GetArmorItemState(ent, armor, "healthMultiplier", 1)) or 1, 1, 5)
end

function hg.GetArmorMass(ent, placement, armor)
	local data = hg.armor[placement] and hg.armor[placement][armor]
	if not data then return 1 end
	local sides = hg.GetArmorItemState(ent, armor, "plateSides", "none")
	local material = hg.ArmorPlateMaterials[hg.GetArmorItemState(ent, armor, "plateMaterial", "ceramic")] or hg.ArmorPlateMaterials.ceramic
	local count = sides == "all" and 4 or sides == "both" and 2 or (sides == "front" or sides == "back") and 1 or 0
	return (data.mass or 1) + count * material.mass
end

function hg.GetArmorProtection(ent, placement, armor, hitPos)
	local data = hg.armor[placement] and hg.armor[placement][armor]
	if not data then return 0, 0, 0 end
	local quality = math.Clamp(tonumber(hg.GetArmorItemState(ent, armor, "quality", 1)) or 1, 0.8, 1.2)
	local ballistic = data.protection or 0
	local multiplier = math.Clamp(tonumber(hg.GetArmorItemState(ent, armor, "protectionMultiplier", 1)) or 1, 0.5, 2)
	local protectionLevel = hg.GetArmorItemState(ent, armor, "protectionLevel", nil)
	local levelScale = protectionLevel and hg.ArmorPlateLevels[protectionLevel]
	local levelProfile = hg.ArmorProtectionLevels[protectionLevel]
	if levelScale then multiplier = multiplier * levelScale / hg.ArmorPlateLevels[3] end
	local melee = (data.meleeProt or ballistic) * quality * multiplier * (levelProfile and levelProfile.melee or 1)
	local stab = (data.stabProt or ballistic) * quality * multiplier * (levelProfile and levelProfile.stab or 1)
	if not hg.GetArmorItemState(ent, armor, "fixedLevel", false) then ballistic = ballistic * quality end
	ballistic = ballistic * multiplier * (levelProfile and levelProfile.ballistic or 1)
	if placement ~= "torso" or not isvector(hitPos) then return ballistic, melee, stab end
	local sides = hg.GetArmorItemState(ent, armor, "plateSides", "none")
	if sides == "none" then return ballistic, melee, stab end
	local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ent) or ent
	if not IsValid(body) then return ballistic, melee, stab end
	local bone = body:LookupBone("ValveBiped.Bip01_Spine2")
	local matrix = bone and body:GetBoneMatrix(bone)
	if not matrix then return ballistic, melee, stab end
	local localPos = WorldToLocal(hitPos, angle_zero, matrix:GetTranslation(), matrix:GetAngles())
	if localPos.x < -4 or localPos.x > 10 then return ballistic, melee, stab end
	local front = localPos.y >= 2
	local side = math.abs(localPos.z) > 4.5
	if side and sides ~= "all" or not side and front and sides ~= "front" and sides ~= "both" and sides ~= "all" or not side and not front and sides ~= "back" and sides ~= "both" and sides ~= "all" then
		return ballistic, melee, stab
	end
	local level = hg.ArmorPlateLevels[hg.GetArmorItemState(ent, armor, "plateLevel", 3)] or 10
	local material = hg.ArmorPlateMaterials[hg.GetArmorItemState(ent, armor, "plateMaterial", "ceramic")] or hg.ArmorPlateMaterials.ceramic
	return ballistic + level * material.protection * 0.4, melee + level * (material.melee or 1) * 0.2, stab + level * (material.stab or 1) * 0.35
end

function hg.IsVisorLowered(ent, armor, armorData)
	return hg.GetArmorItemState(ent, armor, "lowered", armorData.defaultLowered ~= false)
end

local voiceMufflingArmor = {
	mandible_caiman = true,
	mask2 = true,
	mask4 = true,
	visor_exfil_black = true,
	visor_fast_shield = true,
	visor_heavy_trooper = true,
	visor_kolpak = true,
	visor_lshz2dtm = true,
	visor_killa = true,
	visor_maska = true,
	visor_riot = true,
	visor_rys_t = true,
	visor_sobr1 = true,
	visor_sobr2 = true,
	visor_vulkan = true,
	visor_zsh = true,
}

function hg.IsVoiceMuffled(ent)
	if not IsValid(ent) or not ent.armors then return false end
	for placement, armor in pairs(ent.armors) do
		if not voiceMufflingArmor[armor] then continue end
		local armorData = hg.armor[placement] and hg.armor[placement][armor]
		if not armorData or not armorData.toggleableVisor or hg.IsVisorLowered(ent, armor, armorData) then return true end
	end
	return false
end
local entityMeta = FindMetaTable("Entity")
function entityMeta:SyncArmor()
	if self.armors then
		self:SetNetVar("Armor", self.armors)
		self:SetNetVar("ArmorStates", table.Copy(self.armor_states or {}))
		local rag = hg.GetCurrentCharacter(self)
		if IsValid(rag) and rag:IsRagdoll() then
			rag.armors = table.Copy(self.armors)
			rag.armors_shots = table.Copy(self.armors_shots or {})
			rag.armors_health = table.Copy(self.armors_health or {})
			rag.armors_durability = table.Copy(self.armors_durability or {})
			rag.armors_regions = table.Copy(self.armors_regions or {})
			rag.armors_broken = table.Copy(self.armors_broken or {})
			rag.armors_broken_mul = table.Copy(self.armors_broken_mul or {})
			rag.armor_states = table.Copy(self.armor_states or {})
			rag:SetNetVar("Armor", self.armors)
			rag:SetNetVar("ArmorStates", table.Copy(self.armor_states or {}))
			rag:SetNetVar("HideArmorRender", self:GetNetVar("HideArmorRender", false))
		end
	end
end

local function initArmor()
	for possibleArmor, armors in pairs(hg.armor) do
		for armorkey, armorData in pairs(armors) do
			if CLIENT then language.Add(armorkey, (hg.armorNames or {})[armorkey] or armorkey) end
			if armorData.inbuilt then continue end
			
			local armor = {}
			armor.Base = "armor_base"
			armor.PrintName = CLIENT and language.GetPhrase(armorkey) or armorkey
			armor.name = armorkey
			armor.Category = "ZCity Armor"
			armor.Spawnable = true
			if armorData.Spawnable != nil then
				armor.Spawnable = false
			end
			if armorData.AdminOnly then
				armor.AdminOnly = true
			end
			armor.Model = armorData[2]
			armor.WorldModel = armorData[2]
			armor.SubMats = armorData[4]
			armor.armor = armorData
			armor.placement = armorData[1]
			armor.IconOverride = (hg.armorIcons or {})[armorkey]
			armor.PhysModel = armorData.PhysModel or nil
			armor.PhysPos = armorData.PhysPos or nil
			armor.PhysAng = armorData.PhysAng or nil
			armor.material = armorData.material or nil
			armor.skins = armorData.skins or nil
			scripted_ents.Register(armor, "ent_armor_" .. armorkey)
		end
	end
end

function hg.GetArmorPlacement(armor)
	if istable(armor) then return end
	armor = string.Replace(armor,"ent_armor_","")
	
	local found
	for i,armplc in pairs(hg.armor) do
		for i2,armor2 in pairs(armplc) do
			if i2 == armor then found = i end
		end
	end
	return found
end

local stringToNum = {
	["torso"] = 1,
	["head"] = 2,
	["face"] = 3,
}

function hg.GetArmorPlacementNum(armor)
	return stringToNum[hg.GetArmorPlacement(armor)]
end

initArmor()
hook.Add("Initialize", "init-atts", initArmor)
