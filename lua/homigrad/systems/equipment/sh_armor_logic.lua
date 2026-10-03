function hg.GetArmorItemState(ent, armor, key, default)
	if not IsValid(ent) then return default end
	local states = SERVER and ent.armor_states or ent:GetNetVar("ArmorStates", ent.armor_states or {})
	local state = states and states[armor]
	if not state and ent.name == armor then state = SERVER and ent.armorState or ent:GetNetVar("ArmorItemState", {}) end
	if state and state[key] ~= nil then return state[key] end
	local natural = hg.GetArmorDefaultState and hg.GetArmorDefaultState(armor)
	if natural and natural[key] ~= nil then return natural[key] end
	return default
end

hg.ArmorPlateMaterials = {
	ceramic = {mass = 2.5, protection = 1, durability = 30, spall = 0.1},
	steel = {mass = 4, protection = 0.9, durability = 160, spall = 0.6},
	polyethylene = {mass = 1.8, protection = 0.8, durability = 65, spall = 0},
	uhmwpe = {mass = 1.8, protection = 0.95, durability = 75, spall = 0},
	uhmwpe_ceramic = {mass = 2.2, protection = 1.05, durability = 50, spall = 0.03},
	uhmwpe_arsteel = {mass = 2.8, protection = 1, durability = 120, spall = 0.15},
	titan = {mass = 3, protection = 1, durability = 130, spall = 0.3},
	arsteel = {mass = 3.6, protection = 0.95, durability = 150, spall = 0.4},
	kevlar = {mass = 1.5, protection = 0.7, durability = 45, spall = 0},
	kevlar_ceramic = {mass = 2, protection = 0.9, durability = 38, spall = 0.06},
	kevlar_arsteel = {mass = 2.6, protection = 0.85, durability = 110, spall = 0.25},
	kevlar_titan = {mass = 2.4, protection = 0.85, durability = 100, spall = 0.2},
	riot = {mass = 3.2, protection = 0.12, melee = 5, stab = 0.45, durability = 90, spall = 0},
}

hg.ArmorPlateLevels = {[1] = 6, [2] = 8, [3] = 10, [4] = 12, [5] = 15, [6] = 17}
hg.ArmorProtectionLevels = {stab = {ballistic = 0.12, melee = 0.8, stab = 2}}

local softArmorLevels = {IIA = 1, II = 2, IIIA = 3, III = 4, IV = 5}
local plateArmorLevels = {IIA = 1, II = 2, IIIA = 3, III = 3, IV = 4, V = 5, VI = 6, VII = 6}
local armorDefaultStates = {}

function hg.GetArmorDefaultState(armor)
	if not isstring(armor) then return end
	if armorDefaultStates[armor] ~= nil then return armorDefaultStates[armor] or nil end
	local data = hg.armor.torso and hg.armor.torso[armor]
	if not data then
		armorDefaultStates[armor] = false
		return
	end

	local name = (hg.armorNames or {})[armor] or armor
	local lower = string.lower(name)
	local rating
	for token in string.gmatch(name, "[IVXA]+") do
		if token:match("^[IVX]+A?$") then rating = token end
	end

	local state
	if lower:find("riot", 1, true) then
		state = {plateMaterial = "riot", plateLevel = 3, plateSides = "all", protectionLevel = "stab"}
	elseif lower:find("kevlar", 1, true) or lower:find("paca", 1, true) or lower:find("soft", 1, true) then
		state = {plateMaterial = "kevlar", plateLevel = softArmorLevels[rating] or 3, plateSides = "all"}
	else
		local material = "ceramic"
		if lower:find("plate body armor", 1, true) or lower:find("steel", 1, true) or lower:find("iron", 1, true) then
			material = "steel"
		elseif lower:find("uhmwpe", 1, true) then
			material = "uhmwpe"
		end
		state = {plateMaterial = material, plateLevel = plateArmorLevels[rating] or 3, plateSides = (data.protection or 0) > 0 and "both" or "none"}
	end

	armorDefaultStates[armor] = state
	return state
end

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
	if placement ~= "torso" or not hg.IsArmorPlateHit(ent, armor, hitPos) then return ballistic, melee, stab end
	local level = hg.ArmorPlateLevels[hg.GetArmorItemState(ent, armor, "plateLevel", 3)] or 10
	local material = hg.GetArmorPlateMaterial(ent, armor)
	local condition = hg.GetArmorPlateCondition(ent, armor)
	return ballistic + level * material.protection * 0.4 * condition, melee + level * (material.melee or 1) * 0.2 * condition, stab + level * (material.stab or 1) * 0.35 * condition
end

function hg.GetArmorPlateMaterial(ent, armor)
	return hg.ArmorPlateMaterials[hg.GetArmorItemState(ent, armor, "plateMaterial", "ceramic")] or hg.ArmorPlateMaterials.ceramic
end

function hg.GetArmorPlateMaxHealth(ent, armor)
	local level = hg.ArmorPlateLevels[hg.GetArmorItemState(ent, armor, "plateLevel", 3)] or 10
	return (hg.GetArmorPlateMaterial(ent, armor).durability or 60) * level / hg.ArmorPlateLevels[3]
end

function hg.GetArmorPlateCondition(ent, armor)
	local maximum = hg.GetArmorPlateMaxHealth(ent, armor)
	local health = tonumber(hg.GetArmorItemState(ent, armor, "plateHealth", maximum)) or maximum
	return math.Clamp(health / maximum, 0, 1)
end

function hg.IsArmorPlateHit(ent, armor, hitPos)
	if not isvector(hitPos) then return false end
	local sides = hg.GetArmorItemState(ent, armor, "plateSides", "none")
	if sides == "none" then return false end
	local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ent) or ent
	if not IsValid(body) then return false end
	local bone = body:LookupBone("ValveBiped.Bip01_Spine2")
	local matrix = bone and body:GetBoneMatrix(bone)
	if not matrix then return false end
	local localPos = WorldToLocal(hitPos, angle_zero, matrix:GetTranslation(), matrix:GetAngles())
	if localPos.x < -4 or localPos.x > 10 then return false end
	if math.abs(localPos.z) > 4.5 then return sides == "all" end
	if localPos.y >= 2 then return sides == "front" or sides == "both" or sides == "all" end
	return sides == "back" or sides == "both" or sides == "all"
end

function hg.BulletPiercesSoftArmor(dmgInfo, bullet)
	local ammoID = dmgInfo and dmgInfo:GetAmmoType()
	local ammoName = ammoID and ammoID >= 0 and game.GetAmmoName(ammoID) or bullet and bullet.AmmoType
	local ammo = ammoName and hg.ammotypeshuy and hg.ammotypeshuy[ammoName]
	return ammo and ammo.BulletSettings and ammo.BulletSettings.PierceSoftArmor or false
end

function hg.IsArmorPlateStopping(ent, placement, armor, hitPos)
	return placement == "torso" and hg.IsArmorPlateHit(ent, armor, hitPos) and hg.GetArmorPlateCondition(ent, armor) > 0
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
		local rag = IsValid(self.zcnpc_rag) and self.zcnpc_rag or hg.GetCurrentCharacter(self)
		if IsValid(rag) and rag:IsRagdoll() then
			rag.armors = table.Copy(self.armors)
			rag.armors_shots = table.Copy(self.armors_shots or {})
			rag.armors_health = table.Copy(self.armors_health or {})
			rag.armors_durability = table.Copy(self.armors_durability or {})
			rag.armors_regions = table.Copy(self.armors_regions or {})
			rag.armors_broken = table.Copy(self.armors_broken or {})
			rag.armors_broken_mul = table.Copy(self.armors_broken_mul or {})
			rag.armors_wear_stage = table.Copy(self.armors_wear_stage or {})
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
