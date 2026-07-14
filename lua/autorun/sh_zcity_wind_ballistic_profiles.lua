-- Z-City Wind Ballistic Profiles
-- Companion addon for Z-City Realistic Bullet Wind Drift.

if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("z_city_wind_ballistic_profiles/sh_config.lua")
    AddCSLuaFile("z_city_wind_ballistic_profiles/sh_builtin_profiles.lua")
    AddCSLuaFile("z_city_wind_ballistic_profiles/sh_core.lua")
end

local PREFIX = "[Z-City Wind Ballistics] "
local VERSION = "2026-06-15.02"
_G.ZCityWindBallisticsProfilesLoaded = VERSION

if CLIENT then
    MsgC(Color(120, 220, 255), PREFIX .. "client loaded; profiles are applied on the server.\n")
    return
end

-- Server-only load sequence
include("z_city_wind_ballistic_profiles/sh_config.lua")
include("z_city_wind_ballistic_profiles/sh_builtin_profiles.lua")
include("z_city_wind_ballistic_profiles/sh_core.lua")
include("z_city_wind_ballistic_profiles/sv_custom_profiles.lua")

MsgC(Color(120, 220, 255), PREFIX .. "loaded v" .. VERSION .. "\n")
