hg = hg or {}
hg.ZCityInventoryAddonEnabled = true
hg.ZCityInventoryAddonFileGuards = hg.ZCityInventoryAddonFileGuards or {}
if hg.ZCityInventoryAddonFileGuards["new_inventory_cl"] then return end
hg.ZCityInventoryAddonFileGuards["new_inventory_cl"] = true

local clr_inv, clr_inv_selected = Color(8, 8, 8, 225), Color(215, 215, 215, 105)
local type = type

local function GetInventorySystem()
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

local radialBackpackDraw

local function SelectWeapon(wep)
    net.Start("NI_SelectWeapon")
    net.WriteEntity(wep)
    net.SendToServer()
end

local function CancelRadialBackpackDraw(finished)
    if not radialBackpackDraw then return end

    local selector = hg.WeaponSelector
    if selector and selector.CancelBackpackDraw then
        selector.CancelBackpackDraw(finished)
    end

    radialBackpackDraw = nil
end

local function BeginRadialWeaponSelect(ply, wep)
    CancelRadialBackpackDraw(false)

    local selector = hg.WeaponSelector
    local mustDrawFromBackpack = wep ~= ply:GetActiveWeapon()
        and selector and selector.ShouldDelayBackpackDraw and selector.ShouldDelayBackpackDraw(ply, wep)

    if not mustDrawFromBackpack then
        SelectWeapon(wep)
        if wep ~= ply:GetActiveWeapon() then
            surface.PlaySound("arc9_eft_shared/weapon_generic_spin" .. math.random(10) .. ".ogg")
        end
        return
    end

    local duration = selector.GetBackpackDrawDuration(ply, wep)
    radialBackpackDraw = {
        weapon = wep,
        finish = CurTime() + duration
    }
    selector.StartBackpackDraw(ply, wep, duration)
    selector.PlayBackpackReachPreview(wep, duration)
end

hook.Add("StartCommand", "NI_RadialBackpackDraw", function(ply, cmd)
    local pending = radialBackpackDraw
    if not pending then return end

    if GetInventorySystem() ~= 2 or not IsValid(ply) or not ply:Alive() or not IsValid(pending.weapon) then
        CancelRadialBackpackDraw(false)
        return
    end

    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
    if CurTime() < pending.finish then return end

    local wep = pending.weapon
    CancelRadialBackpackDraw(true)
    SelectWeapon(wep)
    surface.PlaySound("arc9_eft_shared/weapon_generic_spin" .. math.random(10) .. ".ogg")
end)

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
