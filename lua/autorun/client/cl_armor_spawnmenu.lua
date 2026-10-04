local function hideDuplicateArmorCategory()
	local entities = list.GetForEdit("SpawnableEntities")
	for class, data in pairs(entities) do
		if data.Category == "ZCity Armor" or data.Category == "ZCity Ammo" or data.Category == "ZCity TestArmor" then entities[class] = nil end
	end
end

hook.Add("Initialize", "hg/armor/spawnmenu-category", function()
	timer.Simple(0, hideDuplicateArmorCategory)
end)
hook.Add("HomigradRun", "hg/armor/spawnmenu-category", hideDuplicateArmorCategory)
hook.Add("OnReloaded", "hg/armor/spawnmenu-category", hideDuplicateArmorCategory)
hideDuplicateArmorCategory()

spawnmenu.AddCreationTab("armor", function()
		local tabs = vgui.Create("DPropertySheet")

		local function addPage(label, entries)
			local scroll = vgui.Create("DScrollPanel", tabs)
			local layout = vgui.Create("DIconLayout", scroll)
			layout:Dock(FILL)
			layout:SetStretchHeight(true)
			layout:SetSpaceX(4)
			layout:SetSpaceY(4)
			for _, entry in ipairs(entries) do
				local icon = spawnmenu.CreateContentIcon("entity", layout, entry)
				if IsValid(icon) then layout:Add(icon) end
			end
			tabs:AddSheet(label, scroll)
		end

		local zcity = {}
		local legacy = {}
		local newArmor = {
			{"ent_new_armor_helmet1", "ACH Helmet IIIA", "vgui/icons/helmet"},
			{"ent_new_armor_helmet2", "Motorcycle Helmet", "vgui/icons/mothelmet"},
			{"ent_new_armor_vest1", "Plate Body Armor IV", "scrappers/armor1.png"},
			{"ent_new_armor_vest2", "Police anti-riot vest", "vgui/icons/policevest"},
			{"ent_new_armor_vest3", "Kevlar IIIA Vest", "vgui/icons/armor01"},
			{"ent_new_armor_vest4", "Kevlar-Plate III Vest", "vgui/icons/armor02"},
		}
		for _, info in ipairs(newArmor) do
			local class = info[1]
			local stored = scripted_ents.GetStored(class)
			local data = stored and stored.t
			if not data or not data.Spawnable then continue end
			local label = data.PrintName or info[2]
			local target = data.PlatesLinks and next(data.PlatesLinks) and zcity or legacy
			target[#target + 1] = {spawnname = class, nicename = label, material = data.IconOverride or info[3], admin = data.AdminOnly}
		end
		for _, armors in pairs(hg.armor or hg.zcityArmor or {}) do
			for name, data in pairs(armors) do
				if not data.inbuilt and data.Spawnable == nil then
					local label = (hg.armorNames or hg.zcityArmorNames or {})[name] or name
					legacy[#legacy + 1] = {spawnname = "ent_armor_" .. name, nicename = label, material = (hg.armorIcons or hg.zcityArmorIcons or {})[name] or "entities/ent_armor_" .. name .. ".png", admin = data.AdminOnly}
				end
			end
		end
		table.sort(zcity, function(a, b) return a.nicename < b.nicename end)
		addPage("working 100%", zcity)

		table.sort(legacy, function(a, b) return a.nicename < b.nicename end)
		addPage("other armor", legacy)
		return tabs
end, "icon16/shield.png", 30)
