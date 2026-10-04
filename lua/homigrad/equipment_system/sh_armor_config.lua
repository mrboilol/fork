hg = hg or {}

hg.ZCityArmorMaterials = {
	[0] = "No plate / native fabric",
	[1] = "Riot composite",
	[3] = "Ceramic",
	[1.8] = "Titanium",
	[1.4] = "Armor steel",
	[1.2] = "UHMWPE",
	[0.85] = "UHMWPE / Ceramic",
	[0.7] = "UHMWPE / Armor steel",
	[0.55] = "UHMWPE / Titanium",
	[0.9] = "Kevlar",
	[0.75] = "Kevlar / Ceramic",
	[0.6] = "Kevlar / Armor steel",
	[0.45] = "Kevlar / Titanium",
	[5] = "Fiberglass",
	[4.5] = "Polycarbonate",
}
hg.ZCityArmorClasses = {[0.5] = "Stab / slash", [1.5] = "I", [4] = "II", [8] = "IIIA", [12] = "III", [16] = "III+", [22] = "IV"}

local CONFIG_FIELDS = {"Protection", "BalisticMaterial", "Durability", "DurabilityMax", "DurabilityWarranty", "ProtectionDamageMul", "PenetratedDamageMul", "BluntDamageMul", "BluntWearMul", "SlashDamageMul", "SlashWearMul"}
hg.ZCityArmorConfigFields = CONFIG_FIELDS

local SHAPE_FIELDS = {"SizeX", "SizeY", "SizeZ", "OffsetX", "OffsetY", "OffsetZ"}
local MATERIAL_PROFILES = {
	[1] = {mass = 3.2, health = 120, stopped = 0.6, penetrated = 0.95, blunt = 0.04, slash = 0.12},
	[3] = {mass = 2.5, health = 170, stopped = 0.4, penetrated = 0.7, blunt = 0.4, slash = 0.4},
	[1.8] = {mass = 3, health = 150, stopped = 0.4, penetrated = 0.75, blunt = 0.4, slash = 0.35},
	[1.4] = {mass = 3.6, health = 150, stopped = 0.4, penetrated = 0.8, blunt = 0.4, slash = 0.3},
	[1.2] = {mass = 1.8, health = 75, stopped = 0.5, penetrated = 0.85, blunt = 0.5, slash = 0.5},
	[0.85] = {mass = 2.2, health = 95, stopped = 0.4, penetrated = 0.75, blunt = 0.4, slash = 0.4},
	[0.7] = {mass = 2.8, health = 125, stopped = 0.4, penetrated = 0.8, blunt = 0.4, slash = 0.3},
	[0.55] = {mass = 2.4, health = 100, stopped = 0.4, penetrated = 0.8, blunt = 0.4, slash = 0.35},
	[0.9] = {mass = 1.5, health = 60, stopped = 0.6, penetrated = 0.9, blunt = 0.6, slash = 0.6},
	[0.75] = {mass = 2, health = 85, stopped = 0.5, penetrated = 0.8, blunt = 0.5, slash = 0.4},
	[0.6] = {mass = 2.6, health = 115, stopped = 0.5, penetrated = 0.85, blunt = 0.5, slash = 0.3},
	[0.45] = {mass = 2.4, health = 105, stopped = 0.5, penetrated = 0.85, blunt = 0.5, slash = 0.35},
	[5] = {mass = 1.2, health = 25, stopped = 0.6, penetrated = 1, blunt = 0.06, slash = 0.65},
	[4.5] = {mass = 0.4, health = 15, stopped = 0.6, penetrated = 1, blunt = 0.65, slash = 0.7},
}

local MATERIAL_MAX_CLASS = {
	[1] = 4, [3] = 22, [1.8] = 22, [1.4] = 22, [1.2] = 12, [0.85] = 22, [0.7] = 22, [0.55] = 22,
	[0.9] = 8, [0.75] = 22, [0.6] = 22, [0.45] = 22, [5] = 1.5, [4.5] = 1.5,
}

function hg.BuildZCityArmorSection(material, class, needPunch)
	local profile = MATERIAL_PROFILES[material]
	local max = profile.health * (0.5 + 0.5 * class / 22)
	return {Protection = class, BalisticMaterial = material, Durability = max, DurabilityMax = max, DurabilityWarranty = max * 0.25,
		ProtectionDamageMul = profile.stopped, PenetratedDamageMul = profile.penetrated, BluntDamageMul = profile.blunt,
		BluntWearMul = material == 1 and 0.35 or material * 0.2, SlashDamageMul = profile.slash, SlashWearMul = 0.25, NeedPunch = needPunch == true}
end

local function getDefinition(ent)
	local stored = scripted_ents.GetStored(ent:GetClass())
	return stored and stored.t or ent
end

local function getFabric(ent, name)
	local definition = getDefinition(ent)
	local backing = definition[string.gsub(name, "Plate", "Kevlar")]
	if backing and backing.BalisticMaterial == 0.9 then
		local fabric = table.Copy(backing)
		fabric.BluntDamageMul = fabric.BluntDamageMul or fabric.ProtectionDamageMul
		fabric.BluntWearMul = fabric.BluntWearMul or 0.18
		fabric.SlashDamageMul = fabric.SlashDamageMul or fabric.ProtectionDamageMul
		fabric.SlashWearMul = fabric.SlashWearMul or 0.25
		return fabric
	end
	return {Protection = 1.5, BalisticMaterial = 0.9, Durability = 30, DurabilityMax = 30,
		DurabilityWarranty = 5, ProtectionDamageMul = 0.85, PenetratedDamageMul = 0.98,
		BluntDamageMul = 0.85, BluntWearMul = 0.18, SlashDamageMul = 0.4, SlashWearMul = 0.25, NeedPunch = false}
end

function hg.GetZCityArmorMaxClass(ent)
	local definition = getDefinition(ent)
	local max = definition.MaxPlateClass or 0
	if max == 0 then
		for _, name in pairs(definition.PlatesLinks or {}) do
			local base = definition[name]
			if base then max = math.max(max, base.ProtectionClass or base.Protection or 0) end
		end
	end
	return max
end

function hg.IsZCityArmorLoadoutAllowed(ent, class, material)
	if material == 0 then return hg.ZCityArmorClasses[class] ~= nil end
	if not hg.ZCityArmorClasses[class] or not MATERIAL_MAX_CLASS[material] then return false end
	return class <= hg.GetZCityArmorMaxClass(ent) and class <= MATERIAL_MAX_CLASS[material]
end

function hg.DeriveZCityArmorSection(ent, name, selected)
	local definition = getDefinition(ent)
	local base = name == "Armor" and definition or definition[name]
	if not base then return end
	local part = table.Copy(selected)
	if part.BalisticMaterial == 0 then
		part = getFabric(ent, name)
		part.ProtectionClass = selected.Protection
		part.Protection = math.min(selected.Protection, part.Protection)
		if selected.Protection == 0.5 then part.SlashDamageMul = 0.04 end
		part.BalisticMaterial = 0
	elseif part.Protection == base.Protection and part.BalisticMaterial == base.BalisticMaterial then
		for _, field in ipairs(CONFIG_FIELDS) do part[field] = base[field] end
		part.NeedPunch = base.NeedPunch == true
	else
		local profile = MATERIAL_PROFILES[part.BalisticMaterial]
		local classScale = 0.5 + 0.5 * part.Protection / 22
		part.DurabilityMax = profile.health * classScale
		part.DurabilityWarranty = part.DurabilityMax * 0.25
		part.ProtectionDamageMul = profile.stopped
		part.PenetratedDamageMul = profile.penetrated
		part.BluntDamageMul = profile.blunt
		part.BluntWearMul = part.BalisticMaterial == 1 and 0.35 or part.BalisticMaterial * 0.2
		part.SlashDamageMul = profile.slash
		part.SlashWearMul = 0.25
		part.NeedPunch = base.NeedPunch == true
	end
	part.BluntDamageMul = part.BluntDamageMul or part.ProtectionDamageMul
	part.BluntWearMul = part.BluntWearMul or math.max(part.BalisticMaterial, 0.9) * 0.2
	part.SlashDamageMul = part.SlashDamageMul or part.ProtectionDamageMul
	part.SlashWearMul = part.SlashWearMul or 0.25
	if selected.Protection == 0.5 and selected.BalisticMaterial ~= 0 then part.SlashDamageMul = 0.04 end
	part.Durability = math.Clamp(tonumber(selected.Durability) or part.DurabilityMax, 0, part.DurabilityMax)
	for _, field in ipairs(SHAPE_FIELDS) do part[field] = selected[field] or (string.StartWith(field, "Size") and 1 or 0) end
	part.RiotPlate = nil
	part.ProtectionMode = nil
	return part
end

function hg.GetZCityArmorMass(ent, config)
	local definition = getDefinition(ent)
	local totalWeight, weight = 0, {}
	for name in pairs(config) do
		local base = name == "Armor" and definition or definition[name]
		local profile = MATERIAL_PROFILES[base.BalisticMaterial]
		weight[name] = (profile and profile.mass or 1) * base.DurabilityMax
		totalWeight = totalWeight + weight[name]
	end
	local carrier = definition.SlotOccupation and definition.SlotOccupation[ZC_ARMOR_SLOT_TORSO] and 0.6 or 0.2
	local original = definition.CarryMass or 1
	local mass = carrier
	local sections = {}
	for name, part in pairs(config) do
		local base = name == "Armor" and definition or definition[name]
		local sectionMass = 0
		if part.BalisticMaterial == 0 and base.BalisticMaterial == 0.9 then
			sectionMass = (original - carrier) * weight[name] / totalWeight
		elseif part.BalisticMaterial ~= 0 then
			sectionMass = (original - carrier) * weight[name] / totalWeight
				* MATERIAL_PROFILES[part.BalisticMaterial].mass / MATERIAL_PROFILES[base.BalisticMaterial].mass
				* (0.5 + 0.5 * part.Protection / 22) / (0.5 + 0.5 * base.Protection / 22)
				* (part.SizeX or 1) * (part.SizeY or 1) * (part.SizeZ or 1)
		end
		sections[name] = sectionMass
		mass = mass + sectionMass
	end
	return mass, sections
end

function hg.GetOldArmorInSlots(ply, slots)
	local worn = SERVER and ply.armors or ply:GetNetVar("Armor", {})
	if not worn then return end
	if slots[ZC_ARMOR_SLOT_HEAD] and worn.head then return "head" end
	if slots[ZC_ARMOR_SLOT_TORSO] and worn.torso then return "torso" end
end

function hg.GetNewArmorOnPlacement(ply, placement)
	local slot = placement == "head" and ZC_ARMOR_SLOT_HEAD or placement == "torso" and ZC_ARMOR_SLOT_TORSO
	if not slot then return end
	for _, index in ipairs(ply:GetNetVar("zc_equipment", {})) do
		local equipment = Entity(index)
		if IsValid(equipment) and equipment.SlotOccupation and equipment.SlotOccupation[slot] and equipment.GetEquiped and equipment:GetEquiped() then return equipment end
	end
end

function hg.SyncZCityArmorCondition(ent)
	if not SERVER or not IsValid(ent) then return end
	local condition, changed = {}, false
	local old = ent:GetNetVar("ZCityArmorCondition", {})
	for _, name in pairs(ent.PlatesLinks or {}) do
		local part = ent[name]
		if part and part.DurabilityMax and not condition[name] then
			condition[name] = math.Round(math.Clamp(part.Durability / math.max(part.DurabilityMax, 1), 0, 1), 2)
			if part.Fabric then condition[name .. "Fabric"] = math.Round(math.Clamp(part.Fabric.Durability / math.max(part.Fabric.DurabilityMax, 1), 0, 1), 2) end
		end
	end
	for name, value in pairs(condition) do if old[name] ~= value then changed = true end end
	if changed then ent:SetNetVar("ZCityArmorCondition", condition) end
end

function hg.GetZCityArmorContactSection(ent, name, fabricOnly)
	local part = name and ent[name] or ent
	if not part then return end
	if fabricOnly or part.BalisticMaterial == 0 then
		local backing = name and ent[string.gsub(name, "Plate", "Kevlar")]
		if backing and backing ~= part then return backing end
		part.Fabric = part.Fabric or getFabric(ent, name or "Armor")
		return part.Fabric
	end
	return part
end

function hg.GetZCityArmorHitBoxes(wearer, organ)
	if not hg.organism.armor_hitbox_sets or not hg.organism.armor_hitbox_sets[organ[1]] then return end
	if not wearer.GetEquipmentByHitBoxSet then return end
	local armor = wearer:GetEquipmentByHitBoxSet(organ[1])
	if not IsValid(armor) then return end
	local name = armor.PlatesLinks and armor.PlatesLinks[organ[9]]
	local shape = armor:GetNetVar("ZCityArmorShape", {})
	local part = name and shape[name]
	if not part then return end
	local adjusted = table.Copy(organ)
	if part.BalisticMaterial == 0 then
		adjusted[10] = true
		return {adjusted}
	end
	local changed = false
	for _, field in ipairs(SHAPE_FIELDS) do
		if part[field] ~= (string.StartWith(field, "Size") and 1 or 0) then changed = true end
	end
	if not changed then return end
	adjusted[3] = organ[3] + Vector(part.OffsetX, part.OffsetY, part.OffsetZ)
	adjusted[5] = Vector(organ[5].x * part.SizeX, organ[5].y * part.SizeY, organ[5].z * part.SizeZ)
	local boxes = {adjusted}
	local backing = armor[string.gsub(name, "Plate", "Kevlar")]
	local insert = string.find(name, "Plate", 1, true)
		or (string.find(name, "Kevlar", 1, true) and part.BalisticMaterial ~= 0.9)
	if insert and (not backing or backing == armor[name]) then
		local fabric = table.Copy(organ)
		fabric[10] = true
		boxes[#boxes + 1] = fabric
	end
	return boxes
end

function hg.GetZCityArmorSectionDescription(part)
	local condition = math.Clamp(part.Durability / math.max(part.DurabilityMax, 1), 0, 1)
	local ratingCondition = math.Clamp(part.Durability / math.max(part.DurabilityMax - part.DurabilityWarranty, 1), 0, 1)
	local bullet = part.Protection * ratingCondition * (part.BalisticMaterial == 1 and 0.12 or 1)
	local blunt = 1 - (1 - part.BluntDamageMul) * math.sqrt(condition)
	local slash = 1 - (1 - part.SlashDamageMul) * math.sqrt(condition)
	local stopped = math.min(part.ProtectionDamageMul * (2 - ratingCondition), 1)
	local penetrated = math.min(part.PenetratedDamageMul * (2 - ratingCondition), 1)
	return string.format("Health %.1f / %.1f. Full ballistic rating down to %.1f health.\nBullet resistance: %.2f penetration units.\nBase stopped / penetrated damage: %.1f%% / %.1f%%. Condition-adjusted: %.1f%% / %.1f%% before energy/penetration scaling.\nCurrent blunt / slash damage transmitted: %.1f%% / %.1f%%.\nRemaining blunt / slash absorption capacity: %.1f / %.1f damage.\nBullet wear: %.2f x (penetration + 25%% of impact damage).",
		part.Durability, part.DurabilityMax, part.DurabilityMax - part.DurabilityWarranty, bullet,
		part.ProtectionDamageMul * 100, part.PenetratedDamageMul * 100, stopped * 100, penetrated * 100, blunt * 100, slash * 100,
		part.Durability / math.max(part.BluntWearMul, 0.01), part.Durability / math.max(part.SlashWearMul, 0.01), part.BalisticMaterial)
end

function hg.GetZCityArmorConfiguration(ent)
	if not IsValid(ent) or not string.StartWith(ent:GetClass(), "ent_new_armor_") then return end
	local parts = {}
	for _, name in pairs(ent.PlatesLinks or {}) do parts[name] = ent[name] end
	if next(parts) == nil then parts.Armor = ent end
	local config = {}
	for name, part in pairs(parts) do
		config[name] = {}
		for _, field in ipairs(CONFIG_FIELDS) do config[name][field] = part[field] end
		config[name].BluntDamageMul = part.BluntDamageMul or part.ProtectionDamageMul
		config[name].BluntWearMul = part.BluntWearMul or part.BalisticMaterial * 0.2
		config[name].SlashDamageMul = part.SlashDamageMul or part.ProtectionDamageMul
		config[name].SlashWearMul = part.SlashWearMul or 0.25
		config[name].NeedPunch = part.NeedPunch == true
		config[name].Protection = part.ProtectionClass or part.Protection
		for _, field in ipairs(SHAPE_FIELDS) do
			config[name][field] = part[field] or (string.StartWith(field, "Size") and 1 or 0)
		end
		if part.BalisticMaterial == 0 and part.Fabric then config[name].Durability = part.Fabric.Durability end
		if part.Fabric then config[name].FabricDurability = part.Fabric.Durability end
	end

	return config
end

function hg.ApplyZCityArmorConfiguration(ent, config)
	local current = hg.GetZCityArmorConfiguration(ent)
	if not current or not istable(config) or table.Count(config) ~= table.Count(current) then return false end
	local derived = {}
	for name in pairs(current) do
		local part = istable(config[name]) and table.Copy(config[name])
		if not istable(part) then return false end
		if part.ProtectionMode == "stab" then part.Protection = 0.5 end
		if part.RiotPlate then part.BalisticMaterial = 1 end
		if not isnumber(part.BalisticMaterial) then return false end
		part.BalisticMaterial = math.Round(part.BalisticMaterial, 2)
		if not hg.ZCityArmorClasses[part.Protection] or not hg.ZCityArmorMaterials[part.BalisticMaterial] then return false end
		if not hg.IsZCityArmorLoadoutAllowed(ent, part.Protection, part.BalisticMaterial) then
			local base = name == "Armor" and getDefinition(ent) or getDefinition(ent)[name]
			if not base or part.Protection ~= (base.ProtectionClass or base.Protection) or part.BalisticMaterial ~= base.BalisticMaterial then return false end
		end
		if not isnumber(part.Durability) or part.Durability ~= part.Durability or part.Durability < 0 or part.Durability > 500 then return false end
		if part.FabricDurability ~= nil and (not isnumber(part.FabricDurability) or part.FabricDurability ~= part.FabricDurability
			or part.FabricDurability < 0 or part.FabricDurability > 500) then return false end
		for _, field in ipairs(SHAPE_FIELDS) do
			local size = string.StartWith(field, "Size")
			local value = part[field] or (size and 1 or 0)
			if value ~= (size and 1 or 0) then return false end
			part[field] = value
		end
		derived[name] = hg.DeriveZCityArmorSection(ent, name, part)
	end
	local mass = hg.GetZCityArmorMass(ent, derived)
	if mass ~= mass or mass < 0.1 or mass > 50 then return false end
	if mass < 0.5 * (getDefinition(ent).CarryMass or 1) * 0.25 then return false end
	for name in pairs(current) do
		local part = name == "Armor" and ent or table.Copy(ent[name])
		for _, field in ipairs(CONFIG_FIELDS) do part[field] = derived[name][field] end
		for _, field in ipairs(SHAPE_FIELDS) do part[field] = derived[name][field] end
		part.NeedPunch = derived[name].NeedPunch
		part.ProtectionClass = derived[name].ProtectionClass
		part.RiotPlate = nil
		part.ProtectionMode = nil
		if part.BalisticMaterial == 0 then
			part.Fabric = getFabric(ent, name)
			part.Fabric.Durability = part.Durability
		elseif derived[name].FabricDurability ~= nil then
			part.Fabric = getFabric(ent, name)
			part.Fabric.Durability = math.min(derived[name].FabricDurability, part.Fabric.DurabilityMax)
		end
		if name ~= "Armor" then ent[name] = part end
	end
	ent:SetNetVar("ZCityArmorShape", derived)
	hg.SetZCityArmorMass(ent, mass)
	return true
end

function hg.SetZCityArmorMass(ent, mass)
	if not IsValid(ent) or not isnumber(mass) or mass ~= mass or mass < 0.1 or mass > 50 then return false end
	ent.CarryMass = mass
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(mass) end
	ent:SetNetVar("ZCityArmorMass", mass)
	return true
end

if SERVER then
	util.AddNetworkString("hg_configure_zcity_armor")
	local function configureSpawnedArmor(ply, ent)
		if not IsValid(ply) or not ply:IsPlayer() or not hg.GetZCityArmorConfiguration(ent) then return end
		if ent.HGArmorConfigurator or ent:GetEquiped() then return end
		ent.HGArmorConfigurator = ply
		ent.HGArmorConfigureUntil = CurTime() + 120
		timer.Simple(0.1, function()
			if not IsValid(ent) or not IsValid(ply) or ent:GetEquiped() then return end
			net.Start("hg_configure_zcity_armor")
				net.WriteEntity(ent)
				net.WriteTable(hg.GetZCityArmorConfiguration(ent))
			net.Send(ply)
		end)
	end
	hook.Add("PlayerSpawnedSENT", "hg/armor/configure-zcity", configureSpawnedArmor)
	hook.Add("OnEntityCreated", "hg/armor/configure-created-zcity", function(ent)
		if not string.StartWith(ent:GetClass(), "ent_new_armor_") then return end
		timer.Simple(0.1, function()
			if IsValid(ent) then configureSpawnedArmor(ent:GetCreator(), ent) end
		end)
	end)
	net.Receive("hg_configure_zcity_armor", function(_, ply)
		local ent = net.ReadEntity()
		if not IsValid(ent) or ent.HGArmorConfigurator ~= ply or CurTime() > (ent.HGArmorConfigureUntil or 0) then return end
		if ent:GetEquiped() or IsValid(ent.WearOwner) or ply:GetPos():DistToSqr(ent:GetPos()) > 512 * 512 then return end
		local count = net.ReadUInt(4)
		if count == 0 or count > 8 then return end
		local config = {}
		for _ = 1, count do
			local name = net.ReadString()
			if config[name] then return end
			config[name] = {}
			config[name].Protection = net.ReadFloat()
			config[name].BalisticMaterial = net.ReadFloat()
			config[name].Durability = 500
		end
		if hg.ApplyZCityArmorConfiguration(ent, config) then
			ent.HGArmorConfigurator = nil
		end
	end)
else
	local MATERIAL_INFO = {
		[0] = "Nothing inserted. Only the fabric of the garment protects this spot, using the LEVEL you picked (fabric is weak, usually Level I). Stab fabric is very good against cuts and stabs. Lightest option.",
		[1] = "Soft riot plastic. Excellent against clubs and fists, good against knives and cuts, weak against bullets.",
		[3] = "Hard ceramic. Stops bullets very well and is light for its strength, but cracks and wears out fast when hit.",
		[1.8] = "Titanium. Strong and fairly light, wears more slowly than steel.",
		[1.4] = "Armor steel. Very tough and cheap, but the heaviest plate.",
		[1.2] = "UHMWPE (a tough plastic fibre). Very light, good for mid-level protection.",
		[0.85] = "Plastic fibre with a ceramic layer. Light and strong.",
		[0.7] = "Plastic fibre with a steel layer. Strong but heavier.",
		[0.55] = "Plastic fibre with a titanium layer. Strong and balanced.",
		[0.9] = "Kevlar fabric. Light and flexible, stops pistol bullets but not rifle bullets.",
		[0.75] = "Kevlar with a ceramic layer. Light and strong.",
		[0.6] = "Kevlar with a steel layer. Strong but heavier.",
		[0.45] = "Kevlar with a titanium layer. Strong and balanced.",
		[5] = "Fiberglass. Very light, only stops weak hits.",
		[4.5] = "Polycarbonate (clear hard plastic). Extremely light, only stops weak hits.",
	}
	local CLASS_INFO = {
		[0.5] = "Stops knife stabs and slashes only. Does not stop bullets.",
		[1.5] = "Stops weak pistol rounds.",
		[4] = "Stops most pistol rounds.",
		[8] = "Stops strong pistol rounds and submachine guns.",
		[12] = "Stops most rifle rounds.",
		[16] = "Stops strong rifle rounds.",
		[22] = "Stops armor-piercing rifle rounds. Heaviest.",
	}
	local function prettyName(name)
		local label = string.gsub(name, "(%l)(%u)", "%1 %2")
		label = string.gsub(label, "Kevlar", "soft panel")
		return (string.gsub(label, "^%l", string.upper))
	end
	local function materialTooltip(material, class)
		local text = MATERIAL_INFO[material]
		if material ~= 0 then
			local stats = hg.BuildZCityArmorSection(material, class)
			text = text .. string.format("\nHealth: %.0f   Weight factor: %.1f\nWhen it stops a bullet, %.0f%% of the damage still reaches you.\nIf a bullet breaks through, %.0f%% of the damage reaches you.\nBlunt damage that gets through: %.0f%%.\nCut damage that gets through: %.0f%%.",
				stats.DurabilityMax, MATERIAL_PROFILES[material].mass, stats.ProtectionDamageMul * 100, stats.PenetratedDamageMul * 100, stats.BluntDamageMul * 100, stats.SlashDamageMul * 100)
		end
		return text
	end
	net.Receive("hg_configure_zcity_armor", function()
		local ent = net.ReadEntity()
		local config = net.ReadTable()
		if not IsValid(ent) or not istable(config) then return end
		local frame = vgui.Create("DFrame")
		frame:SetSize(520, math.min(ScrH() - 80, 780))
		frame:Center()
		frame:SetTitle("Build your armor: " .. ent.PrintName)
		frame:MakePopup()
		local apply = vgui.Create("DButton", frame)
		apply:Dock(BOTTOM)
		apply:SetTall(34)
		apply:SetText("Done - use this armor")
		local weight = vgui.Create("DLabel", frame)
		weight:Dock(TOP)
		weight:SetTall(36)
		weight:SetWrap(true)
		weight:SetTooltip("Heavier plates and higher levels make the armor weigh more. Taking a plate out makes it lighter.")
		local help = vgui.Create("DLabel", frame)
		help:Dock(TOP)
		help:SetTall(70)
		help:SetWrap(true)
		help:SetText("How this works: each tab is one spot on the armor (front, back, sides...). For each spot, first pick a LEVEL (how strong), then pick a PLATE type (what it is made of). Hover over anything to read what it does. This armor can only hold plates up to the level it was made for.")
		local function updateWeight()
			weight:SetText(string.format("Total armor weight: %.2f kg. Higher levels and heavier plates make it heavier.", hg.GetZCityArmorMass(ent, config)))
		end
		updateWeight()
		local tabs = vgui.Create("DPropertySheet", frame)
		tabs:Dock(FILL)
		local names = table.GetKeys(config)
		table.sort(names)
		for _, name in ipairs(names) do
			local part = config[name]
			local original = table.Copy(part)
			local maxClass = math.max(hg.GetZCityArmorMaxClass(ent), original.Protection)
			local panel = vgui.Create("DScrollPanel", tabs)
			local classLabel = vgui.Create("DLabel", panel)
			local classBox = vgui.Create("DPanel", panel)
			local materialLabel = vgui.Create("DLabel", panel)
			local materialBox = vgui.Create("DPanel", panel)
			local summary = vgui.Create("DLabel", panel)
			local classButtons, materialButtons = {}, {}
			local function updateDescription()
				local preview = hg.DeriveZCityArmorSection(ent, name, part)
				local backingName = string.gsub(name, "Plate", "Kevlar")
				if part.BalisticMaterial == 0 and backingName ~= name and config[backingName] then
					preview = hg.DeriveZCityArmorSection(ent, backingName, config[backingName])
				elseif part.BalisticMaterial == 0 then
					preview.BalisticMaterial = 0.9
				end
				local _, sectionMass = hg.GetZCityArmorMass(ent, config)
				local description = string.format("Weight of this spot: %.2f kg\n", sectionMass[name]) .. hg.GetZCityArmorSectionDescription(preview)
				if part.BalisticMaterial == 0 then
					description = "No plate here: only the soft fabric protects this spot.\n" .. description
				end
				summary:SetText(description)
				updateWeight()
			end
			local function markSelected(buttons, selected)
				for value, button in pairs(buttons) do button:SetEnabled(value ~= selected) end
			end
			local function buildMaterials()
				for _, button in pairs(materialButtons) do button:Remove() end
				materialButtons = {}
				local first
				local selectedAllowed = false
				for value, title in SortedPairs(hg.ZCityArmorMaterials) do
					local keep = value == original.BalisticMaterial and part.Protection == original.Protection
					if hg.IsZCityArmorLoadoutAllowed(ent, part.Protection, value) or keep then
						first = first or value
						selectedAllowed = selectedAllowed or value == part.BalisticMaterial
						local button = vgui.Create("DButton", materialBox)
						button:SetText(value == 0 and "No plate" or title)
						button:SetTall(26)
						button:Dock(TOP)
						button:SetTooltip(materialTooltip(value, part.Protection))
						button.DoClick = function()
							part.BalisticMaterial = value
							part.Durability = 500
							markSelected(materialButtons, value)
							updateDescription()
						end
						materialButtons[value] = button
					end
				end
				if not selectedAllowed and first then part.BalisticMaterial = first end
				materialBox:SetTall(26 * table.Count(materialButtons))
				markSelected(materialButtons, part.BalisticMaterial)
			end
			classLabel:Dock(TOP)
			classLabel:SetText("Step 1 - Pick a LEVEL (how strong this spot is). If you pick No plate in step 2, this is the strength of the fabric instead. Hover a button to see what it stops.")
			classLabel:SetWrap(true)
			classLabel:SetAutoStretchVertical(true)
			classLabel:DockMargin(8, 8, 8, 4)
			classBox:Dock(TOP)
			classBox.Paint = nil
			for value, title in SortedPairs(hg.ZCityArmorClasses) do
				if value <= maxClass then
					local button = vgui.Create("DButton", classBox)
					button:SetText("Level " .. title)
					button:SetTall(26)
					button:Dock(TOP)
					button:SetTooltip(CLASS_INFO[value])
					button.DoClick = function()
						part.Protection = value
						part.Durability = 500
						markSelected(classButtons, value)
						buildMaterials()
						updateDescription()
					end
					classButtons[value] = button
				end
			end
			classBox:SetTall(26 * table.Count(classButtons))
			markSelected(classButtons, part.Protection)
			materialLabel:Dock(TOP)
			materialLabel:SetText("Step 2 - Pick a PLATE type (what it is made of). Only plates that fit your level are shown. Hover to see its stats.")
			materialLabel:SetWrap(true)
			materialLabel:SetAutoStretchVertical(true)
			materialLabel:DockMargin(8, 8, 8, 4)
			materialBox:Dock(TOP)
			materialBox.Paint = nil
			summary:Dock(TOP)
			summary:SetWrap(true)
			summary:SetAutoStretchVertical(true)
			summary:DockMargin(8, 8, 8, 8)
			buildMaterials()
			updateDescription()
			tabs:AddSheet(prettyName(name), panel)
		end
		apply.DoClick = function()
			if not IsValid(ent) then frame:Close() return end
			net.Start("hg_configure_zcity_armor")
				net.WriteEntity(ent)
				net.WriteUInt(#names, 4)
				for _, name in ipairs(names) do
					net.WriteString(name)
					net.WriteFloat(config[name].Protection)
					net.WriteFloat(config[name].BalisticMaterial)
				end
			net.SendToServer()
			frame:Close()
		end
	end)
end
