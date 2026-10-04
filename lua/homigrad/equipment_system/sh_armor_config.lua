hg = hg or {}

hg.ZCityArmorMaterials = {
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
hg.ZCityArmorClasses = {[1.5] = "I", [4] = "II", [8] = "IIIA", [12] = "III", [16] = "III+", [22] = "IV"}

local CONFIG_FIELDS = {"Protection", "BalisticMaterial", "Durability", "DurabilityMax", "DurabilityWarranty", "ProtectionDamageMul", "PenetratedDamageMul", "BluntDamageMul", "BluntWearMul", "SlashDamageMul", "SlashWearMul"}
hg.ZCityArmorConfigFields = CONFIG_FIELDS

function hg.GetZCityArmorSectionDescription(part)
	local condition = math.Clamp(part.Durability / math.max(part.DurabilityMax, 1), 0, 1)
	local ratingCondition = math.Clamp(part.Durability / math.max(part.DurabilityMax - part.DurabilityWarranty, 1), 0, 1)
	local bullet = part.Protection * ratingCondition * (part.RiotPlate and 0.12 or 1) * (part.ProtectionMode == "stab" and 0.08 or 1)
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
		config[name].RiotPlate = part.RiotPlate == true
		config[name].ProtectionMode = part.ProtectionMode or "ballistic"
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
		if part.DurabilityMax < 1 or part.Durability > part.DurabilityMax or part.DurabilityWarranty >= part.DurabilityMax then return false end
		if part.ProtectionDamageMul > 1 or part.PenetratedDamageMul > 1 or part.BluntDamageMul > 1 or part.SlashDamageMul > 1 then return false end
		if part.BluntWearMul < 0.01 or part.BluntWearMul > 5 or part.SlashWearMul < 0.01 or part.SlashWearMul > 5 then return false end
		if not isbool(part.NeedPunch) or not isbool(part.RiotPlate) then return false end
		if part.ProtectionMode ~= "ballistic" and part.ProtectionMode ~= "stab" then return false end
	end
	for name in pairs(current) do
		local part = name == "Armor" and ent or table.Copy(ent[name])
		for _, field in ipairs(CONFIG_FIELDS) do part[field] = config[name][field] end
		part.NeedPunch = config[name].NeedPunch
		part.RiotPlate = config[name].RiotPlate
		part.ProtectionMode = config[name].ProtectionMode
		if name ~= "Armor" then ent[name] = part end
	end

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
				net.WriteFloat(ent.CarryMass or 1)
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
			config[name].NeedPunch = net.ReadBool()
			config[name].RiotPlate = net.ReadBool()
			config[name].ProtectionMode = net.ReadString()
		end
		local mass = net.ReadFloat()
		if mass ~= mass or mass < 0.1 or mass > 50 then return end
		if hg.ApplyZCityArmorConfiguration(ent, config) then
			hg.SetZCityArmorMass(ent, mass)
			ent.HGArmorConfigurator = nil
		end
	end)
else
	net.Receive("hg_configure_zcity_armor", function()
		local ent = net.ReadEntity()
		local config = net.ReadTable()
		local mass = net.ReadFloat()
		if not IsValid(ent) or not istable(config) then return end
		local frame = vgui.Create("DFrame")
		frame:SetSize(480, math.min(ScrH() - 80, 760))
		frame:Center()
		frame:SetTitle("Configure " .. ent.PrintName)
		frame:MakePopup()
		local apply = vgui.Create("DButton", frame)
		apply:Dock(BOTTOM)
		apply:SetTall(32)
		apply:SetText("Apply armor configuration")
		local weight = vgui.Create("DNumSlider", frame)
		weight:Dock(TOP)
		weight:SetText("Total armor mass (kg)")
		weight:SetMin(0.1)
		weight:SetMax(50)
		weight:SetDecimals(1)
		weight:SetValue(mass)
		weight:SetTooltip("Total equipment weight used by movement, stamina, the HUD, and dropped armor physics.")
		weight.OnValueChanged = function(_, value) mass = value end
		local tabs = vgui.Create("DPropertySheet", frame)
		tabs:Dock(FILL)
		local names = table.GetKeys(config)
		table.sort(names)
		for _, name in ipairs(names) do
			local part = config[name]
			local panel = vgui.Create("DScrollPanel", tabs)
			local summary = vgui.Create("DLabel", panel)
			summary:Dock(TOP)
			summary:SetTall(175)
			summary:SetWrap(true)
			summary:SetAutoStretchVertical(true)
			summary:DockMargin(8, 8, 8, 8)
			local function updateDescription()
				summary:SetText(hg.GetZCityArmorSectionDescription(part))
			end
			local sliders = {}
			local function choice(label, field, options, tooltip)
				local row = vgui.Create("DComboBox", panel)
				row:Dock(TOP)
				row:DockMargin(0, 0, 0, 8)
				row:SetTooltip(tooltip)
				for value, title in SortedPairs(options) do row:AddChoice(label .. ": " .. title, value, value == part[field]) end
				row.OnSelect = function(_, _, _, value)
					part[field] = value
					if field == "BalisticMaterial" then
						part.RiotPlate = value == 1
						if part.RiotPlate then part.BluntDamageMul = 0.08 part.BluntWearMul = 0.35 end
					elseif field == "ProtectionMode" and value == "stab" then
						part.SlashDamageMul = 0.04
						part.SlashWearMul = 0.25
					end
					for key, control in pairs(sliders) do control:SetValue(part[key]) end
					updateDescription()
				end
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
				sliders[field] = row
				row:SetTooltip(tooltip)
				row.OnValueChanged = function(_, value) part[field] = value updateDescription() end
			end
			choice("Protection class", "Protection", hg.ZCityArmorClasses, "ZCity ballistic resistance for this section.")
			choice("Material", "BalisticMaterial", hg.ZCityArmorMaterials, "ZCity material determines how quickly this section degrades.")
			choice("Protection mode", "ProtectionMode", {ballistic = "Ballistic", stab = "Stab / slash"}, "Stab mode transmits 4% of a fresh covered slash, but retains only 8% of the ballistic class. Riot material retains 12% of the ballistic class and transmits 8% of fresh blunt damage. Wear increases transfer; remaining health caps absorption.")
			slider("Current health", "Durability", 0, 500, 1, "Actual remaining section health. Cannot exceed maximum health; saved in loadout presets.")
			slider("Maximum health", "DurabilityMax", 1, 500, 0, "Maximum durability of this section, in health points.")
			slider("Full-rating reserve", "DurabilityWarranty", 0, 499, 0, "Health that may be lost before ballistic protection starts decreasing. Full rating lasts down to maximum health minus this reserve.")
			slider("Stopped damage", "ProtectionDamageMul", 0, 1, 2, "Fraction of damage transmitted when this section stops a hit.")
			slider("Penetrated damage", "PenetratedDamageMul", 0, 1, 2, "Fraction of damage transmitted when a hit penetrates this section.")
			slider("Blunt transmitted", "BluntDamageMul", 0, 1, 2, "Fresh blunt damage fraction. 0.08 passes 8% and absorbs 92%; worn sections pass more.")
			slider("Blunt health cost", "BluntWearMul", 0.01, 5, 2, "Section health consumed per absorbed blunt damage. Remaining absorption capacity is health divided by this value.")
			slider("Slash transmitted", "SlashDamageMul", 0, 1, 2, "Fresh slash/stab damage fraction. 0.04 passes 4% and absorbs 96%; worn sections pass more.")
			slider("Slash health cost", "SlashWearMul", 0.01, 5, 2, "Section health consumed per absorbed slash damage. Remaining absorption capacity is health divided by this value.")
			local punch = vgui.Create("DCheckBoxLabel", panel)
			punch:Dock(TOP)
			punch:SetText("Bullet view punch / tinnitus / flash")
			punch:SetTooltip("Enables the existing view punch, tinnitus, flash and disorientation response to bullet/buckshot impacts.")
			punch:SetValue(part.NeedPunch and 1 or 0)
			punch.OnChange = function(_, value) part.NeedPunch = value end
			updateDescription()
			tabs:AddSheet(string.gsub(name, "(%l)(%u)", "%1 %2"), panel)
		end
		apply.DoClick = function()
			if not IsValid(ent) then frame:Close() return end
			for _, part in pairs(config) do
				if part.DurabilityWarranty >= part.DurabilityMax or part.Durability > part.DurabilityMax then
					apply:SetText("Check current health, maximum and warranty")
					return
				end
			end
			net.Start("hg_configure_zcity_armor")
				net.WriteEntity(ent)
				net.WriteUInt(#names, 4)
				for _, name in ipairs(names) do
					net.WriteString(name)
					for _, field in ipairs(CONFIG_FIELDS) do net.WriteFloat(config[name][field]) end
					net.WriteBool(config[name].NeedPunch)
					net.WriteBool(config[name].RiotPlate)
					net.WriteString(config[name].ProtectionMode)
				end
				net.WriteFloat(mass)
			net.SendToServer()
			frame:Close()
		end
	end)
end
