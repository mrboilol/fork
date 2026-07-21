hg = hg or {}
hg.ZCityInventoryAddonEnabled = true
hg.ZCityInventoryAddonFileGuards = hg.ZCityInventoryAddonFileGuards or {}
if hg.ZCityInventoryAddonFileGuards["new_inventory_cl"] then return end
hg.ZCityInventoryAddonFileGuards["new_inventory_cl"] = true

local clr_inv, clr_inv_selected = Color(8, 8, 8, 225), Color(215, 215, 215, 105)
local type = type

local function GetInventorySystem()
	local convar = GetConVar("hg_invsystem")
	if convar then
		return math.Clamp(convar:GetInt(), 0, 2)
	end

	return math.Clamp(GetGlobalInt("InventorySystem", 0), 0, 2)
end

local function GetItemDescription(wep)
	if not IsValid(wep) then return "" end

	local description = wep.Description
	if not isstring(description) or string.Trim(description) == "" then
		description = wep.Instructions
	end
	if not isstring(description) or string.Trim(description) == "" then
		description = wep.Purpose
	end
	if not isstring(description) then return "" end

	description = language.GetPhrase(description)
	return string.Trim(description)
end

local function GetItemName(wep)
	local class = wep:GetClass()
	local phrase = language.GetPhrase(class)
	return phrase ~= class and phrase or wep:GetPrintName()
end

local function SelectWeapon(wep)
    net.Start("NI_SelectWeapon")
    net.WriteEntity(wep)
    net.SendToServer()
end

local function BeginRadialWeaponSelect(ply, wep)
    SelectWeapon(wep)
    if wep ~= ply:GetActiveWeapon() then
        surface.PlaySound("arc9_eft_shared/weapon_generic_spin" .. math.random(10) .. ".ogg")
    end
end

hook.Add("PlayerButtonDown", "NI_PlayerButtonDown", function(ply, key)
	if GetInventorySystem() == 2 and key == KEY_1 and ply.organism and not ply.organism.otrub then
		local tbl1 = {}
		local weps = ply:GetWeapons()
		for i = 1, #weps do
			local wep = weps[i]

			local icon = type(wep.WepSelectIcon2) == "IMaterial" and wep.WepSelectIcon2 or (type(wep.WepSelectIcon) == "IMaterial" and wep.WepSelectIcon)
			tbl1[#tbl1 + 1] = {
				function()
					BeginRadialWeaponSelect(ply, wep)
				end, GetItemName(wep), nil, nil, icon, clr_inv, clr_inv_selected, GetItemDescription(wep)
			}
		end
		hg.CreateRadialMenu(tbl1, false)
	end
end)

hook.Add("PlayerButtonUp", "NI_PlayerButtonUp", function(ply, key)
	if GetInventorySystem() == 2 and key == KEY_1 then
		hg.PressRadialMenu(1)
	end
end)
