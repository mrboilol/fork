hg = hg or {}
hg.ZCityInventoryAddonEnabled = true
hg.ZCityInventoryAddonFileGuards = hg.ZCityInventoryAddonFileGuards or {}
if hg.ZCityInventoryAddonFileGuards["new_inventory_cl"] then return end
hg.ZCityInventoryAddonFileGuards["new_inventory_cl"] = true

hook.Remove("PlayerButtonDown", "NI_PlayerButtonDown")
hook.Remove("PlayerButtonUp", "NI_PlayerButtonUp")
