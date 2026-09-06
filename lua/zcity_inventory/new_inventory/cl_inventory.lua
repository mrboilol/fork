hg = hg or {}
hg.ZCityInventoryAddonEnabled = true
hg.ZCityInventoryAddonFileGuards = hg.ZCityInventoryAddonFileGuards or {}
if hg.ZCityInventoryAddonFileGuards["new_inventory_cl"] then return end
hg.ZCityInventoryAddonFileGuards["new_inventory_cl"] = true

local clrInv = Color(20, 0, 0, 200)
local clrInvSelected = Color(90, 0, 0, 200)

hook.Add("PlayerButtonDown", "NI_PlayerButtonDown", function(ply, key)
	if ply ~= LocalPlayer() or key ~= KEY_1 or not GetGlobalBool("RadialInventory", false) then return end
	if not ply:Alive() or not ply.organism or ply.organism.otrub or not hg.CreateRadialMenu then return end

	local options = {}
	for _, wep in ipairs(ply:GetWeapons()) do
		local icon = type(wep.WepSelectIcon) == "IMaterial" and wep.WepSelectIcon or (type(wep.WepSelectIcon2) == "IMaterial" and wep.WepSelectIcon2)
		options[#options + 1] = {
			function()
				if not IsValid(wep) or wep == ply:GetActiveWeapon() then return end

				input.SelectWeapon(wep)
				net.Start("NI_SelectWeapon")
				net.WriteEntity(wep)
				net.SendToServer()
				surface.PlaySound("arc9_eft_shared/weapon_generic_spin" .. math.random(10) .. ".ogg")
			end,
			wep:GetPrintName(), nil, nil, icon, clrInv, clrInvSelected
		}
	end

	if #options > 0 then hg.CreateRadialMenu(options, false) end
end)

hook.Add("PlayerButtonUp", "NI_PlayerButtonUp", function(ply, key)
	if ply == LocalPlayer() and key == KEY_1 and GetGlobalBool("RadialInventory", false) and hg.PressRadialMenu then
		hg.PressRadialMenu(1)
	end
end)
