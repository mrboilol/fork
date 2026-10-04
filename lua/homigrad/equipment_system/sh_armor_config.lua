hg = hg or {}

hg.ZCityArmorMaterials = {
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
hg.ZCityArmorClasses = {[1.5] = "I", [4] = "II", [8] = "IIIA", [12] = "III", [16] = "III+", [22] = "IV"}

local CONFIG_FIELDS = {"Protection", "BalisticMaterial", "DurabilityMax", "DurabilityWarranty", "ProtectionDamageMul", "PenetratedDamageMul"}

function hg.GetZCityArmorConfiguration(ent)
	if not IsValid(ent) or not string.StartWith(ent:GetClass(), "ent_new_armor_") then return end
	local parts = {}
	for _, name in pairs(ent.PlatesLinks or {}) do parts[name] = ent[name] end
	if next(parts) == nil then parts.Armor = ent end
	local config = {}
	for name, part in pairs(parts) do
		config[name] = {}
		for _, field in ipairs(CONFIG_FIELDS) do config[name][field] = part[field] end
	end

	return config
end

function hg.ApplyZCityArmorConfiguration(ent, config)
	local current = hg.GetZCityArmorConfiguration(ent)
	if not current or not istable(config) or table.Count(config) ~= table.Count(current) then return false end
	for name in pairs(current) do
		local part = config[name]
		if not istable(part) then return false end
		for _, field in ipairs(CONFIG_FIELDS) do
			local value = part[field]
			if not isnumber(value) or value ~= value or value < 0 or value > 500 then return false end
		end
		part.BalisticMaterial = math.Round(part.BalisticMaterial, 2)
		if not hg.ZCityArmorClasses[part.Protection] or not hg.ZCityArmorMaterials[part.BalisticMaterial] then return false end
		if part.DurabilityMax < 1 or part.DurabilityWarranty >= part.DurabilityMax then return false end
		if part.ProtectionDamageMul > 1 or part.PenetratedDamageMul > 1 then return false end
	end
	for name in pairs(current) do
		local part = name == "Armor" and ent or table.Copy(ent[name])
		for _, field in ipairs(CONFIG_FIELDS) do part[field] = config[name][field] end
		part.Durability = part.DurabilityMax
		if name ~= "Armor" then ent[name] = part end
	end

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
			for _, field in ipairs(CONFIG_FIELDS) do config[name][field] = net.ReadFloat() end
		end
		if hg.ApplyZCityArmorConfiguration(ent, config) then ent.HGArmorConfigurator = nil end
	end)
else
	net.Receive("hg_configure_zcity_armor", function()
		local ent = net.ReadEntity()
		local config = net.ReadTable()
		if not IsValid(ent) or not istable(config) then return end
		local frame = vgui.Create("DFrame")
		frame:SetSize(360, 410)
		frame:Center()
		frame:SetTitle("Configure " .. ent.PrintName)
		frame:MakePopup()
		local apply = vgui.Create("DButton", frame)
		apply:Dock(BOTTOM)
		apply:SetTall(32)
		apply:SetText("Apply armor configuration")
		local tabs = vgui.Create("DPropertySheet", frame)
		tabs:Dock(FILL)
		local names = table.GetKeys(config)
		table.sort(names)
		for _, name in ipairs(names) do
			local part = config[name]
			local panel = vgui.Create("DPanel", tabs)
			panel:DockPadding(8, 8, 8, 8)
			local function choice(label, field, options, tooltip)
				local row = vgui.Create("DComboBox", panel)
				row:Dock(TOP)
				row:DockMargin(0, 0, 0, 8)
				row:SetTooltip(tooltip)
				for value, title in SortedPairs(options) do row:AddChoice(label .. ": " .. title, value, value == part[field]) end
				row.OnSelect = function(_, _, _, value) part[field] = value end
			end
			local function slider(label, field, minimum, maximum, decimals, tooltip)
				local row = vgui.Create("DNumSlider", panel)
				row:Dock(TOP)
				row:SetTall(40)
				row:SetText(label)
				row:SetMin(minimum)
				row:SetMax(maximum)
				row:SetDecimals(decimals)
				row:SetValue(part[field])
				row:SetTooltip(tooltip)
				row.OnValueChanged = function(_, value) part[field] = value end
			end
			choice("Protection class", "Protection", hg.ZCityArmorClasses, "ZCity ballistic resistance for this section.")
			choice("Material", "BalisticMaterial", hg.ZCityArmorMaterials, "ZCity material determines how quickly this section degrades.")
			slider("Durability", "DurabilityMax", 1, 500, 0, "Maximum durability of this section.")
			slider("Warranty", "DurabilityWarranty", 0, 499, 0, "Durability reserved before protection starts decreasing. Must be below durability.")
			slider("Stopped damage", "ProtectionDamageMul", 0, 1, 2, "Fraction of damage transmitted when this section stops a hit.")
			slider("Penetrated damage", "PenetratedDamageMul", 0, 1, 2, "Fraction of damage transmitted when a hit penetrates this section.")
			tabs:AddSheet(string.gsub(name, "(%l)(%u)", "%1 %2"), panel)
		end
		apply.DoClick = function()
			if not IsValid(ent) then frame:Close() return end
			for _, part in pairs(config) do
				if part.DurabilityWarranty >= part.DurabilityMax then
					apply:SetText("Warranty must be below durability")
					return
				end
			end
			net.Start("hg_configure_zcity_armor")
				net.WriteEntity(ent)
				net.WriteUInt(#names, 4)
				for _, name in ipairs(names) do
					net.WriteString(name)
					for _, field in ipairs(CONFIG_FIELDS) do net.WriteFloat(config[name][field]) end
				end
			net.SendToServer()
			frame:Close()
		end
	end)
end
