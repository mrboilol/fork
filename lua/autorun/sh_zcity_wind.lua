ZCityWind = ZCityWind or {}
ZCityWind.Version = "2026-06-04.5"

local function IncludeShared(path)
    if SERVER then
        AddCSLuaFile(path)
    end

    return include(path)
end

local function IncludeClient(path)
    if SERVER then
        AddCSLuaFile(path)
        return
    end

    return include(path)
end

local function IncludeServer(path)
    if SERVER then
        return include(path)
    end
end

IncludeShared("zcity_wind/sh_config.lua")
IncludeShared("zcity_wind/sh_util.lua")
IncludeShared("zcity_wind/sh_weapon_flags.lua")
IncludeShared("zcity_wind/sh_sandbox_bridge.lua")
IncludeServer("zcity_wind/sv_network.lua")
IncludeServer("zcity_wind/sv_wind_sync.lua")
IncludeShared("zcity_wind/sh_wind_sim.lua")
IncludeClient("zcity_wind/cl_debug.lua")
IncludeClient("zcity_wind/cl_menu.lua")
IncludeServer("zcity_wind/sv_suppression.lua")
IncludeServer("zcity_wind/sv_overrides.lua")

MsgC(Color(0, 255, 0), "[Z-City Wind] sh_zcity_wind.lua loaded fully!\n")
