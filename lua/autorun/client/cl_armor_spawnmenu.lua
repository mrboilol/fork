spawnmenu.AddCreationTab("Armor", function()
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
		for _, class in ipairs({"ent_new_armor_helmet1", "ent_new_armor_vest1", "ent_new_armor_vest2"}) do
			local stored = scripted_ents.GetStored(class)
			local data = stored and stored.t
			if data and data.Spawnable then
				zcity[#zcity + 1] = {spawnname = class, nicename = data.PrintName or class, material = data.IconOverride or "entities/" .. class .. ".png", admin = data.AdminOnly}
			end
		end
		addPage("Z-City", zcity)

		local judge = {}
		for _, armors in pairs(hg.armor or {}) do
			for name, data in pairs(armors) do
				if not data.inbuilt and data.Spawnable == nil then
					judge[#judge + 1] = {spawnname = "ent_armor_" .. name, nicename = (hg.armorNames or {})[name] or name, material = (hg.armorIcons or {})[name] or "entities/ent_armor_" .. name .. ".png", admin = data.AdminOnly}
				end
			end
		end
		table.sort(judge, function(a, b) return a.nicename < b.nicename end)
		addPage("Judge", judge)
		return tabs
end, "icon16/shield.png", 30)
