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
		local zcityNames = {}
		local newArmor = {
			{"ent_new_armor_helmet1", "ACH Helmet IIIA", "vgui/icons/helmet"},
			{"ent_new_armor_helmet2", "Motorcycle Helmet", "vgui/icons/mothelmet"},
			{"ent_new_armor_vest1", "Plate Body Armor IV", "scrappers/armor1.png"},
			{"ent_new_armor_vest2", "Police anti-riot vest", "vgui/icons/policevest"},
			{"ent_new_armor_vest3", "Kevlar IIIA Vest", "vgui/icons/armor01"},
			{"ent_new_armor_vest4", "Kevlar-Plate III Vest", "vgui/icons/armor02"},
		}
		local replacements = {head = {helmet1 = true, helmet2 = true}, torso = {vest1 = true, vest2 = true, vest3 = true, vest4 = true}}
		for _, info in ipairs(newArmor) do
			local class = info[1]
			local stored = scripted_ents.GetStored(class)
			local data = stored and stored.t or {}
			local label = data.PrintName or info[2]
			zcity[#zcity + 1] = {spawnname = class, nicename = label, material = data.IconOverride or info[3], admin = data.AdminOnly}
			zcityNames[string.lower(label)] = true
		end
		for placement, armors in pairs(hg.zcityArmor or {}) do
			for name, data in pairs(armors) do
				if not data.inbuilt and data.Spawnable == nil and not (replacements[placement] and replacements[placement][name]) then
					local label = (hg.zcityArmorNames or {})[name] or name
					zcity[#zcity + 1] = {spawnname = "ent_armor_" .. name, nicename = label, material = (hg.zcityArmorIcons or {})[name] or "entities/ent_armor_" .. name .. ".png", admin = data.AdminOnly}
					zcityNames[string.lower(label)] = true
				end
			end
		end
		table.sort(zcity, function(a, b) return a.nicename < b.nicename end)
		addPage("working 100%", zcity)

		local judge = {}
		for placement, armors in pairs(hg.judgeArmor or {}) do
			for name, data in pairs(armors) do
				local label = (hg.judgeArmorNames or {})[name] or name
				if not data.inbuilt and data.Spawnable == nil and not ((hg.zcityArmor or {})[placement] or {})[name] and not zcityNames[string.lower(label)] then
					judge[#judge + 1] = {spawnname = "ent_armor_" .. name, nicename = label, material = (hg.judgeArmorIcons or {})[name] or "entities/ent_armor_" .. name .. ".png", admin = data.AdminOnly}
				end
			end
		end
		table.sort(judge, function(a, b) return a.nicename < b.nicename end)
		addPage("other armor", judge)
		return tabs
end, "icon16/shield.png", 30)
