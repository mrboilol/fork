if SERVER then return end

if _G.__zcity_delta_unitmenu_command_loaded then return end
_G.__zcity_delta_unitmenu_command_loaded = true

local function EnsureUnitMenuLoaded()
    if isfunction(_G.ZCityDeltaToggleUnitMenu) then return true end
    if not file.Exists("zcity_delta/unitmenu_cl.lua", "LUA") then return false end

    local ok, err = pcall(include, "zcity_delta/unitmenu_cl.lua")
    if not ok then
        ErrorNoHalt("[zcity-delta-addon] unitmenu include failed: zcity_delta/unitmenu_cl.lua\n" .. tostring(err) .. "\n")
        return false
    end

    return isfunction(_G.ZCityDeltaToggleUnitMenu)
end

concommand.Add("hg_unitmenu", function()
    if EnsureUnitMenuLoaded() then
        _G.ZCityDeltaToggleUnitMenu()
    end
end)
