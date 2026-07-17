if CLIENT then return end

hg = hg or {}

local hg_sandbox_containers = CreateConVar("hg_sandbox_containers", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable random lootable prop containers in Sandbox.", 0, 1)

util.AddNetworkString("hg_sandbox_container_open")
util.AddNetworkString("hg_sandbox_container_take")

hg.SandboxContainerModels = hg.SandboxContainerModels or {
	["models/props_borealis/bluebarrel001.mdl"] = {8, "all"},
	["models/props_c17/display_cooler01a.mdl"] = {8, "food"},
	["models/props_c17/furniturecupboard001a.mdl"] = {4, "tools"},
	["models/props_c17/furnituredrawer001a.mdl"] = {5, "tools"},
	["models/props_c17/furnituredrawer002a.mdl"] = {2, "tools"},
	["models/props_c17/furnituredrawer003a.mdl"] = {3, "tools"},
	["models/props_c17/furnituredresser001a.mdl"] = {10, "weapons"},
	["models/props_c17/furniturefridge001a.mdl"] = {7, "food"},
	["models/props_c17/furniturestove001a.mdl"] = {4, "food"},
	["models/props_c17/furniturewashingmachine001a.mdl"] = {6, "all"},
	["models/props_c17/lockers001a.mdl"] = {9, "weapons"},
	["models/props_c17/oildrum001.mdl"] = {8, "all"},
	["models/props_interiors/vendingmachinesoda01a.mdl"] = {10, "food"},
	["models/props_interiors/furniture_desk01a.mdl"] = {4, "tools"},
	["models/props_junk/cardboard_box001a.mdl"] = {6, "all"},
	["models/props_junk/cardboard_box001b.mdl"] = {6, "all"},
	["models/props_junk/cardboard_box002a.mdl"] = {6, "all"},
	["models/props_junk/cardboard_box002b.mdl"] = {6, "all"},
	["models/props_junk/cardboard_box003a.mdl"] = {6, "all"},
	["models/props_junk/cardboard_box003b.mdl"] = {6, "all"},
	["models/props_junk/cardboard_box004a.mdl"] = {1, "all"},
	["models/props_junk/trashbin01a.mdl"] = {7, "trash"},
	["models/props_trainstation/trashcan_indoor001a.mdl"] = {7, "trash"},
	["models/props_junk/trashdumpster01a.mdl"] = {10, "trash"},
	["models/props_junk/wood_crate001a.mdl"] = {8, "all"},
	["models/props_junk/wood_crate001a_damaged.mdl"] = {8, "all"},
	["models/props_junk/wood_crate002a.mdl"] = {8, "all"},
	["models/props_lab/filecabinet02.mdl"] = {5, "tools"},
	["models/props_wasteland/controlroom_filecabinet001a.mdl"] = {5, "medicine"},
	["models/props_wasteland/controlroom_filecabinet002a.mdl"] = {6, "medicine"},
	["models/props_wasteland/controlroom_storagecloset001a.mdl"] = {10, "weapons"},
	["models/props_wasteland/controlroom_storagecloset001b.mdl"] = {10, "weapons"},
	["models/props_wasteland/kitchen_fridge001a.mdl"] = {10, "food"},
	["models/props_wasteland/kitchen_counter001c.mdl"] = {9, "food"},
	["models/props_c17/suitcase001a.mdl"] = {3, "all"},
	["models/props_c17/briefcase001a.mdl"] = {2, "all"},
	["models/props/cs_office/cardboard_box01.mdl"] = {4, "all"},
	["models/props/cs_office/cardboard_box02.mdl"] = {4, "all"},
	["models/props/cs_office/cardboard_box03.mdl"] = {4, "all"},
	["models/props/cs_office/file_cabinet1.mdl"] = {6, "tools"},
	["models/props/cs_office/file_cabinet1_group.mdl"] = {8, "tools"},
	["models/props/cs_office/file_cabinet2.mdl"] = {6, "tools"},
	["models/props/cs_office/file_cabinet3.mdl"] = {6, "tools"},
	["models/props/cs_office/trash_can.mdl"] = {6, "trash"},
	["models/props/cs_office/microwave.mdl"] = {4, "food"},
	["models/props/cs_militia/crate_extrasmallmill.mdl"] = {4, "tools"},
	["models/props/cs_militia/boxes_garage_lower.mdl"] = {8, "all"},
	["models/props/cs_militia/footlocker01_closed.mdl"] = {8, "weapons"},
	["models/props/cs_militia/refrigerator01.mdl"] = {8, "food"},
	["models/props/cs_militia/microwave01.mdl"] = {4, "food"},
	["models/props/cs_militia/stove01.mdl"] = {6, "food"},
	["models/props/de_nuke/crate_extrasmall.mdl"] = {4, "tools"},
	["models/props_wasteland/kitchen_stove001a.mdl"] = {7, "food"},
	["models/props_wasteland/kitchen_stove002a.mdl"] = {7, "food"},
	["models/items/item_item_crate_dynamic.mdl"] = {6, "weapons"},
	["models/items/item_item_crate.mdl"] = {1, "weapons"},
	["models/crate.mdl"] = {8, "all"},
}

local categoryWeights = {
	all = {
		{18, "medicine"},
		{14, "melee"},
		{12, "food"},
		{10, "tools"},
		{8, "ammo"},
		{6, "guns"},
		{4, "armor"},
		{4, "attachments"},
		{3, "trash"},
	},
	weapons = {
		{12, "guns"},
		{9, "melee"},
		{8, "ammo"},
		{4, "attachments"},
		{3, "armor"},
	},
	tools = {
		{11, "tools"},
		{7, "melee"},
		{5, "medicine"},
		{3, "trash"},
	},
	trash = {
		{12, "trash"},
		{5, "food"},
		{4, "tools"},
		{2, "medicine"},
	},
	food = {
		{16, "food"},
		{2, "medicine"},
		{1, "trash"},
	},
	medicine = {
		{16, "medicine"},
		{2, "food"},
		{1, "tools"},
	},
}

local lootPools = {
	medicine = {
		"weapon_bandage_sh",
		"weapon_bigbandage_sh",
		"weapon_tourniquet",
		"weapon_painkillers",
		"weapon_bloodbag",
		"weapon_bruicekit",
		"weapon_medkit_sh",
		"weapon_betablock",
		"weapon_naloxone",
		"weapon_mannitol",
		"weapon_morphine",
		"weapon_adrenaline",
	},
	melee = {
		"weapon_hammer",
		"weapon_wrench",
		"weapon_brick",
		"weapon_pocketknife",
		"weapon_bat",
		"weapon_barbedbat",
		"weapon_leadpipe",
		"weapon_hg_extinguisher",
		"weapon_hg_crowbar",
		"weapon_hatchet",
		"weapon_hg_axe",
		"weapon_hg_machete",
		"weapon_hg_sledgehammer",
		"hg_brassknuckles",
		"weapon_hg_spear",
	},
	guns = {
		"weapon_mp-80",
		"weapon_makarov",
		"weapon_ruger",
		"weapon_revolver2",
		"weapon_px4beretta",
		"weapon_m1911",
		"weapon_m9beretta",
		"weapon_fn45",
		"weapon_hk_usp",
		"weapon_glock17",
		"weapon_cz75",
		"weapon_deagle",
		"weapon_colt9mm",
		"weapon_doublebarrel_short",
		"weapon_doublebarrel",
		"weapon_remington870",
		"weapon_mini14",
		"weapon_kar98",
		"weapon_ar_pistol",
		"weapon_draco",
		"weapon_mp5",
		"weapon_m16a2",
		"weapon_mp7",
		"weapon_sks",
		"weapon_ar15",
		"weapon_ac556",
		"weapon_vpo136",
		"weapon_sr25",
	},
	food = {
		"weapon_smallconsumable",
		"weapon_bigconsumable",
	},
	tools = {
		"weapon_ducttape",
		"weapon_matches",
		"weapon_zippo_tpik",
		"hg_flashlight",
		"weapon_walkie_talkie",
		"ent_ammo_nails",
	},
	ammo = {
		"ent_ammo_9x19mmparabellum",
		"ent_ammo_9x18mm",
		"ent_ammo_.45acp",
		"ent_ammo_.357magnum",
		"ent_ammo_.22longrifle",
		"ent_ammo_12/70gauge",
		"ent_ammo_12/70slug",
		"ent_ammo_5.56x45mm",
		"ent_ammo_7.62x39mm",
		"ent_ammo_5.45x39mm",
		"ent_ammo_7.62x51mm",
	},
	armor = {
		"ent_armor_mask2",
		"ent_armor_helmet1",
		"ent_armor_helmet2",
		"ent_armor_helmet5",
		"ent_armor_vest3",
		"ent_armor_vest4",
	},
	attachments = {
		"*sight*",
		"*barrel*",
	},
	trash = {
		"weapon_brick",
		"weapon_smallconsumable",
		"weapon_matches",
	},
}

local lootAmount = {
	[1] = {0, 1},
	[2] = {0, 1},
	[3] = {1, 1},
	[4] = {1, 1},
	[5] = {1, 1},
	[6] = {1, 2},
	[7] = {1, 2},
	[8] = {2, 3},
	[9] = {2, 4},
	[10] = {2, 5},
}

local function SandboxContainersEnabled()
	return engine.ActiveGamemode() == "sandbox" and hg_sandbox_containers:GetBool()
end

local function WeightedRandomSelect(tbl)
	if hg.WeightedRandomSelect then
		local _, value = hg.WeightedRandomSelect(tbl)
		return value
	end

	local total = 0
	for _, data in ipairs(tbl) do
		total = total + (data[1] or 0)
	end

	local pick = math.Rand(0, total)
	for _, data in ipairs(tbl) do
		pick = pick - (data[1] or 0)
		if pick <= 0 then return data[2] end
	end

	return tbl[#tbl] and tbl[#tbl][2]
end

local function RandomCategory(containerCategory)
	if lootPools[containerCategory] then return containerCategory end
	return WeightedRandomSelect(categoryWeights[containerCategory] or categoryWeights.all)
end

local function RandomAttachment(kind)
	local valid = hg.validattachments and hg.validattachments[kind]
	if not valid then return nil end

	local keys = table.GetKeys(valid)
	if #keys == 0 then return nil end

	return "ent_att_" .. keys[math.random(#keys)]
end

local function RandomLootClass(containerCategory)
	for _ = 1, 8 do
		local category = RandomCategory(containerCategory)
		local pool = lootPools[category]
		local class = pool and pool[math.random(#pool)]

		if class == "*sight*" then
			class = RandomAttachment("sight")
		elseif class == "*barrel*" then
			class = RandomAttachment("barrel")
		end

		if class then return class end
	end
end

local function RandomAmmoAmount(class)
	local ammoName = string.Replace(class, "ent_ammo_", "")
	return math.random(hg.ammoents and hg.ammoents[ammoName] and hg.ammoents[ammoName].Count or 30)
end

local function SpawnLootClass(ent, class, ammoAmount, ply)
	local spawned = ents.Create(class)
	if not IsValid(spawned) then return end

	if IsValid(ply) then
		local trace = util.TraceEntityHull({
			start = ent:GetPos() + vector_up * 5,
			endpos = ply:GetPos() + vector_up * 15,
			filter = {ent, ply},
			mask = MASK_SHOT,
		}, spawned)
		spawned:SetPos(trace.HitPos)
	else
		spawned:SetPos(ent:GetPos() + VectorRand(-8, 8) + vector_up * 12)
	end
	spawned:SetAngles(Angle(0, math.random(0, 359), 0))
	spawned:Spawn()
	spawned.IsSpawned = true
	spawned.init = true

	if string.StartWith(class, "ent_ammo_") then
		spawned.AmmoCount = ammoAmount or RandomAmmoAmount(class)
	end
end

local function GenerateSandboxContainerLoot(ply, ent)
	if not SandboxContainersEnabled() then return false end
	if not IsValid(ent) or ent:IsPlayer() or ent.was_opened then return false end
	if not string.find(ent:GetClass(), "prop_") then return false end

	local model = string.lower(ent:GetModel() or "")
	local containerData = hg.SandboxContainerModels[model]
	if not containerData then return false end

	ent.sandboxLoot = {}
	ent.was_opened = true

	local amountRange = lootAmount[containerData[1]] or lootAmount[6]
	local amount = math.random(amountRange[1], amountRange[2])

	for _ = 1, amount do
		local class = RandomLootClass(containerData[2])
		if class then
			local item = {class = class}
			if string.StartWith(class, "ent_ammo_") then item.ammoAmount = RandomAmmoAmount(class) end
			ent.sandboxLoot[#ent.sandboxLoot + 1] = item
		end
	end

	return true
end

hook.Add("ZB_InventoryChecked", "SandboxContainers", function(ply, ent)
	GenerateSandboxContainerLoot(ply, ent)
end)

local function IsSandboxContainer(ent)
	if not SandboxContainersEnabled() or not IsValid(ent) or ent:GetClass() ~= "prop_physics" then return false end
	return hg.SandboxContainerModels[string.lower(ent:GetModel() or "")] ~= nil
end

local function SendSandboxContainerLoot(ply, ent)
	if not IsValid(ply) or not IsValid(ent) then return end
	net.Start("hg_sandbox_container_open")
		net.WriteEntity(ent)
		net.WriteTable(ent.sandboxLoot or {})
	net.Send(ply)
end

hook.Add("ZB_CanLootInventory", "SandboxContainerGrid", function(ply, ent)
	if not IsSandboxContainer(ent) then return end
	if not ply.keypressed then
		GenerateSandboxContainerLoot(ply, ent)
		SendSandboxContainerLoot(ply, ent)
	end
	return ply, ent, false
end)

net.Receive("hg_sandbox_container_take", function(_, ply)
	local ent = net.ReadEntity()
	local itemID = net.ReadUInt(10)
	if not IsSandboxContainer(ent) or not IsValid(ply) then return end
	if ent:GetPos():DistToSqr(ply:GetPos()) > 125 ^ 2 then return end

	local item = ent.sandboxLoot and ent.sandboxLoot[itemID]
	if not item or not item.class then return end

	ent.sandboxLoot[itemID] = nil
	SpawnLootClass(ent, item.class, item.ammoAmount, ply)
	SendSandboxContainerLoot(ply, ent)
end)

hook.Add("PropBreak", "SandboxContainers", function(ply, ent)
	if not SandboxContainersEnabled() then return end
	if not IsValid(ent) or ent:GetClass() ~= "prop_physics" then return end

	local model = string.lower(ent:GetModel() or "")
	if not hg.SandboxContainerModels[model] then return end

	if not ent.was_opened then
		GenerateSandboxContainerLoot(ply, ent)
	end

	for _, item in pairs(ent.sandboxLoot or {}) do
		SpawnLootClass(ent, item.class, item.ammoAmount)
	end

	ent.sandboxLoot = {}
end)

local function ResetSandboxContainers()
	if not SandboxContainersEnabled() then return end

	for _, ent in ipairs(ents.FindByClass("prop_*")) do
		local model = string.lower(ent:GetModel() or "")
		if hg.SandboxContainerModels[model] then
			ent.was_opened = nil
			ent.sandboxLoot = nil
			ent.inventory = nil
			ent.armors = nil
			ent:SetNetVar("Inventory", nil)
			ent:SetNetVar("Armor", nil)
		end
	end
end

hook.Add("PostCleanupMap", "SandboxContainers", function()
	timer.Simple(0, ResetSandboxContainers)
end)
