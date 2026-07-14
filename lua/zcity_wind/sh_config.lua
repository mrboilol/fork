local ZW = ZCityWind or {}
ZCityWind = ZW

local flags = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)

ZW.CVars = ZW.CVars or {}
ZW.Config = ZW.Config or {}
ZW.Atmosphere = ZW.Atmosphere or {
    TBase = 15,
    P0 = 101325,
    RH = 0.4
}
ZW.Colors = ZW.Colors or {
    Green = Color(0, 255, 0),
    Cyan = Color(0, 255, 255),
    Yellow = Color(255, 255, 0),
    Orange = Color(255, 128, 0),
    Magenta = Color(255, 0, 255),
    Gold = Color(255, 220, 80)
}

local cvarsTable = ZW.CVars
local config = ZW.Config

cvarsTable.WindMultiplier = CreateConVar("sv_zcity_wind_multiplier", "1.0", flags, "Wind deflection multiplier for bullets.")
cvarsTable.Debug = CreateConVar("sv_zcity_wind_debug", "0", flags, "Toggle console debug prints for bullet wind simulation.")
cvarsTable.ReplaceZCityBullets = CreateConVar("sv_zcity_wind_replace_zcity_bullets", "1", flags, "Enable physical bullets for Z-City/Homigrad weapons through the weapon base, without replacing EntityFireBullets globally.")
cvarsTable.ReplaceSandboxBullets = CreateConVar("sv_zcity_wind_replace_sandbox_bullets", "1", flags, "Replace Sandbox default FireBullets with physical bullets so wind can affect them.")
cvarsTable.Suppression = CreateConVar("sv_zcity_wind_suppression", "1", flags, "Enable lightweight near-miss suppression effects for physical bullets.")
cvarsTable.MapSeaLevelZ = CreateConVar("sv_zcity_wind_sea_level", "0", bit.bor(FCVAR_REPLICATED), "The absolute world Z coordinate of the map's sea level (baseline ground level).")
cvarsTable.AtmosphereEnabled = CreateConVar("sv_zcity_wind_atmosphere", "1", flags, "Toggle realistic atmospheric parameters (altitude, temperature, pressure, humidity) influencing bullet drag.")

local function CacheFloat(key, convar, fallback)
    config[key] = convar:GetFloat()

    if cvars and cvars.AddChangeCallback then
        cvars.AddChangeCallback(convar:GetName(), function(_, _, newValue)
            config[key] = tonumber(newValue) or fallback
        end, "ZCityWind_Cache_" .. key)
    end
end

local function CacheBool(key, convar)
    config[key] = convar:GetBool()

    if cvars and cvars.AddChangeCallback then
        cvars.AddChangeCallback(convar:GetName(), function(_, _, newValue)
            config[key] = tobool(newValue)
        end, "ZCityWind_Cache_" .. key)
    end
end

CacheFloat("WindMultiplier", cvarsTable.WindMultiplier, 1)
CacheBool("Debug", cvarsTable.Debug)
CacheBool("ReplaceZCityBullets", cvarsTable.ReplaceZCityBullets)
CacheBool("ReplaceSandboxBullets", cvarsTable.ReplaceSandboxBullets)
CacheBool("Suppression", cvarsTable.Suppression)
CacheFloat("MapSeaLevelZ", cvarsTable.MapSeaLevelZ, 0)
CacheBool("AtmosphereEnabled", cvarsTable.AtmosphereEnabled)

function ZW.IsDebugEnabled()
    return config.Debug == true
end
