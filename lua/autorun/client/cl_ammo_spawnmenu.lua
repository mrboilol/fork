local function getCarriedAmmoNames()
	local names = {}
	local ply = LocalPlayer()
	if not IsValid(ply) then return names end

	local function addAmmo(name)
		if isstring(name) and name ~= "" and string.lower(name) ~= "none" then names[name] = true end
	end

	for _, wep in ipairs(ply:GetWeapons()) do
		if not IsValid(wep) or wep:GetOwner() ~= ply then continue end
		local primaryAmmo = wep.Primary and wep.Primary.Ammo
		addAmmo(primaryAmmo)
		addAmmo(wep.Secondary and wep.Secondary.Ammo)
		local variants = wep.AmmoTypes or wep.AmmoTypes2 and wep.AmmoTypes2[primaryAmmo]
		for _, variant in pairs(variants or {}) do addAmmo(variant[1]) end
	end

	return names
end

spawnmenu.AddCreationTab("Ammo", function()
	local scroll = vgui.Create("DScrollPanel")
	local entries = {}
	for key, data in pairs(hg.ammotypes or {}) do
		if data.noentity then continue end
		local class = "ent_ammo_" .. key
		local stored = scripted_ents.GetStored(class)
		if not stored or not stored.t.Spawnable then continue end
		entries[#entries + 1] = {
			ammoName = data.name,
			spawnname = class,
			nicename = data.name,
			material = hg.GetAmmoIconPath(key),
			admin = stored.t.AdminOnly
		}
	end
	table.sort(entries, function(a, b) return a.nicename < b.nicename end)

	local function addHeading(text)
		local label = vgui.Create("DLabel", scroll)
		label:SetText(text)
		label:SetFont("DermaLarge")
		label:SizeToContents()
		label:Dock(TOP)
		label:DockMargin(8, 8, 8, 8)
		return label
	end

	local function addLayout()
		local layout = vgui.Create("DIconLayout", scroll)
		layout:Dock(TOP)
		layout:SetStretchHeight(true)
		layout:SetSpaceX(4)
		layout:SetSpaceY(4)
		layout:DockMargin(8, 0, 8, 8)
		return layout
	end

	local function addIcon(layout, entry)
		local icon = spawnmenu.CreateContentIcon("entity", layout, entry)
		if IsValid(icon) then layout:Add(icon) end
	end

	addHeading("stuff you can use")
	local compatibleLayout = addLayout()
	local emptyLabel = vgui.Create("DLabel", scroll)
	emptyLabel:SetText("you have nothing kid")
	emptyLabel:SizeToContents()
	emptyLabel:Dock(TOP)
	emptyLabel:DockMargin(8, 0, 8, 8)
	addHeading("All ammo")
	local allLayout = addLayout()
	for _, entry in ipairs(entries) do addIcon(allLayout, entry) end

	local lastSignature
	local nextRefresh = 0
	local function refreshCarriedAmmo()
		local names = getCarriedAmmoNames()
		local compatible = {}
		local signature = {}
		for _, entry in ipairs(entries) do
			if not names[entry.ammoName] then continue end
			compatible[#compatible + 1] = entry
			signature[#signature + 1] = entry.spawnname
		end
		signature = table.concat(signature, "|")
		if signature == lastSignature then return end
		lastSignature = signature
		compatibleLayout:Clear()
		for _, entry in ipairs(compatible) do addIcon(compatibleLayout, entry) end
		emptyLabel:SetVisible(#compatible == 0)
		scroll:InvalidateLayout(true)
	end

	function scroll:Think()
		if not self:IsVisible() or CurTime() < nextRefresh then return end
		nextRefresh = CurTime() + 0.25
		refreshCarriedAmmo()
	end

	refreshCarriedAmmo()
	return scroll
end, "icon16/package.png", 31)
