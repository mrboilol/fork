-- Configuration, ConVars, and Hint Tables

ZCityWindBallistics = ZCityWindBallistics or {}

ZCityWindBallistics.enableConVar = CreateConVar("sv_zcity_wind_ballistics_enable", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Enable Z-City wind ballistic profiles.")
ZCityWindBallistics.dragConVar = CreateConVar("sv_zcity_wind_ballistics_drag", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Adjust Z-City PhysBullet air resistance from ammo ballistic data.")
ZCityWindBallistics.velocityConVar = CreateConVar("sv_zcity_wind_ballistics_velocity", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Apply conservative barrel-length velocity modifiers.")
ZCityWindBallistics.windConVar = CreateConVar("sv_zcity_wind_ballistics_wind", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Apply per-profile wind drift multipliers for the wind addon.")
ZCityWindBallistics.spreadConVar = CreateConVar("sv_zcity_wind_ballistics_spread", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Apply per-profile mechanical accuracy (spread) multipliers.")
ZCityWindBallistics.debugConVar = CreateConVar("sv_zcity_wind_ballistics_debug", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Print applied Z-City wind ballistic profile data.")

-- Cached ConVar values
ZCityWindBallistics.Enabled = ZCityWindBallistics.enableConVar:GetBool()
ZCityWindBallistics.ApplyDrag = ZCityWindBallistics.dragConVar:GetBool()
ZCityWindBallistics.ApplyVelocity = ZCityWindBallistics.velocityConVar:GetBool()
ZCityWindBallistics.ApplyWind = ZCityWindBallistics.windConVar:GetBool()
ZCityWindBallistics.ApplySpread = ZCityWindBallistics.spreadConVar:GetBool()
ZCityWindBallistics.DebugEnabled = ZCityWindBallistics.debugConVar:GetBool()

function ZCityWindBallistics.RefreshConVars()
    ZCityWindBallistics.Enabled = ZCityWindBallistics.enableConVar:GetBool()
    ZCityWindBallistics.ApplyDrag = ZCityWindBallistics.dragConVar:GetBool()
    ZCityWindBallistics.ApplyVelocity = ZCityWindBallistics.velocityConVar:GetBool()
    ZCityWindBallistics.ApplyWind = ZCityWindBallistics.windConVar:GetBool()
    ZCityWindBallistics.ApplySpread = ZCityWindBallistics.spreadConVar:GetBool()
    ZCityWindBallistics.DebugEnabled = ZCityWindBallistics.debugConVar:GetBool()
end

if cvars and cvars.RemoveChangeCallback then
    cvars.RemoveChangeCallback("sv_zcity_wind_ballistics_enable", "ZCityWindBallistics_Cache")
    cvars.RemoveChangeCallback("sv_zcity_wind_ballistics_drag", "ZCityWindBallistics_Cache")
    cvars.RemoveChangeCallback("sv_zcity_wind_ballistics_velocity", "ZCityWindBallistics_Cache")
    cvars.RemoveChangeCallback("sv_zcity_wind_ballistics_wind", "ZCityWindBallistics_Cache")
    cvars.RemoveChangeCallback("sv_zcity_wind_ballistics_spread", "ZCityWindBallistics_Cache")
    cvars.RemoveChangeCallback("sv_zcity_wind_ballistics_debug", "ZCityWindBallistics_Cache")
end

if cvars and cvars.AddChangeCallback then
    local function cacheCallback()
        timer.Simple(0, ZCityWindBallistics.RefreshConVars)
    end

    cvars.AddChangeCallback("sv_zcity_wind_ballistics_enable", cacheCallback, "ZCityWindBallistics_Cache")
    cvars.AddChangeCallback("sv_zcity_wind_ballistics_drag", cacheCallback, "ZCityWindBallistics_Cache")
    cvars.AddChangeCallback("sv_zcity_wind_ballistics_velocity", cacheCallback, "ZCityWindBallistics_Cache")
    cvars.AddChangeCallback("sv_zcity_wind_ballistics_wind", cacheCallback, "ZCityWindBallistics_Cache")
    cvars.AddChangeCallback("sv_zcity_wind_ballistics_spread", cacheCallback, "ZCityWindBallistics_Cache")
    cvars.AddChangeCallback("sv_zcity_wind_ballistics_debug", cacheCallback, "ZCityWindBallistics_Cache")
end

-- Custom JSON Profiles Storage
ZCityWindBallistics.customProfiles = {weapons = {}, ammo = {}}

-- Hint tables for fallback classification
ZCityWindBallistics.SHORT_CLASS_HINTS = {
    "ak74u", "aks74u", "aks_74u", "aks-74u", "krink", "krinkov", "compact", "short", "pdw", "draco", "micro", "mini", "sbr"
}

ZCityWindBallistics.BOLT_ACTION_HINTS = {
    "dvl", "dvl10", "cheytac", "m200", "axmc", "sako", "mosin", "kar98", "kar98k", "awm", "awp", "m98", "m98b", "t5000", "sv98", "sv-98", "r700", "remington700", "m700", "scout", "intervention", "ptrd", "musket", "winchester", "flintlock", "sniper", "dsr", "dsr1", "barrett", "m82", "m82a1", "enfield", "gauss", "item62", "ksvk", "m24", "cs5", "tkpd", "tranquilizer", "trg", "zastava", "blackarrow"
}

ZCityWindBallistics.MARKSMAN_HINTS = {
    "svd", "sr25", "m110", "rsass", "vss", "vsk94", "sks", "skstoz", "sok94", "mini14", "ac556", "g3sg1", "m14", "scar20", "marksman", "precision", "mjolnir", "gewehr", "psg", "ssr"
}

ZCityWindBallistics.HEAVY_PROJECTILE_HINTS = {
    "grenade", "rocket", "missile", "rpg", "flare", "dart", "arrow", "bolt"
}

ZCityWindBallistics.PISTOL_AMMO_HINTS = {
    ["9x18"] = true,
    ["9x19"] = true,
    [".45"] = true,
    [".380"] = true,
    [".357"] = true,
    [".44"] = true,
    ["12/70"] = true,
    ["12 gauge"] = true
}
