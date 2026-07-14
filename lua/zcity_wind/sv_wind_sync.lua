local ZW = ZCityWind
local config = ZW.Config

local debugForceOverride = -1
local debugYawOverride = 0
local lastPublishedSpeed
local lastPublishedYaw
local lastDynamicThink = CurTime()

local dynamicWind = {
    Enabled = false,
    BaseSpeed = 6,
    SpeedVariation = 3,
    BaseYaw = 0,
    YawVariation = 35,
    TargetInterval = 18,
    CurrentSpeed = 6,
    CurrentYaw = 0,
    TargetSpeed = 6,
    TargetYaw = 0,
    NextTargetAt = 0
}

local function NormalizeYaw(yaw)
    yaw = tonumber(yaw) or 0
    yaw = yaw % 360
    if yaw < 0 then yaw = yaw + 360 end
    return yaw
end

local function AngleDifference(a, b)
    local diff = (a - b + 180) % 360 - 180
    return diff
end

local function ApproachAngle(current, target, step)
    local diff = AngleDifference(target, current)
    if math.abs(diff) <= step then
        return NormalizeYaw(target)
    end

    return NormalizeYaw(current + (diff > 0 and step or -step))
end

local function Approach(current, target, step)
    if current < target then
        return math.min(current + step, target)
    end

    return math.max(current - step, target)
end

local function PickDynamicWindTarget()
    dynamicWind.TargetSpeed = math.max(0, dynamicWind.BaseSpeed + math.Rand(-dynamicWind.SpeedVariation, dynamicWind.SpeedVariation))
    dynamicWind.TargetYaw = NormalizeYaw(dynamicWind.BaseYaw + math.Rand(-dynamicWind.YawVariation, dynamicWind.YawVariation))
    dynamicWind.NextTargetAt = CurTime() + dynamicWind.TargetInterval
end

local function GetStormFoxWind()
    if StormFox2 and StormFox2.Wind then
        return StormFox2.Wind.GetForce() or 0, StormFox2.Wind.GetYaw() or 0
    end

    return 0, 0
end

local function PublishWind(speed, yaw)
    speed = math.max(0, tonumber(speed) or 0)
    yaw = NormalizeYaw(yaw)

    if lastPublishedSpeed == nil or math.abs(speed - lastPublishedSpeed) >= 0.05 then
        SetGlobalFloat("ZCity_Wind_Force", speed)
        lastPublishedSpeed = speed
    end

    if lastPublishedYaw == nil or math.abs(AngleDifference(yaw, lastPublishedYaw)) >= 0.1 then
        SetGlobalFloat("ZCity_Wind_Yaw", yaw)
        lastPublishedYaw = yaw
    end
end

local function GetDynamicWind()
    local now = CurTime()
    local dt = math.max(now - lastDynamicThink, 0)
    lastDynamicThink = now

    if now >= dynamicWind.NextTargetAt then
        PickDynamicWindTarget()
    end

    local speedStep = math.max(dynamicWind.SpeedVariation, 0.5) * dt / math.max(dynamicWind.TargetInterval * 0.35, 1)
    local yawStep = math.max(dynamicWind.YawVariation, 5) * dt / math.max(dynamicWind.TargetInterval * 0.35, 1)

    dynamicWind.CurrentSpeed = Approach(dynamicWind.CurrentSpeed, dynamicWind.TargetSpeed, speedStep)
    dynamicWind.CurrentYaw = ApproachAngle(dynamicWind.CurrentYaw, dynamicWind.TargetYaw, yawStep)

    return dynamicWind.CurrentSpeed, dynamicWind.CurrentYaw
end

local function SyncWindState()
    local windSpeed
    local windYaw

    if dynamicWind.Enabled then
        windSpeed, windYaw = GetDynamicWind()
    elseif debugForceOverride >= 0 then
        windSpeed = debugForceOverride
        windYaw = debugYawOverride
    else
        windSpeed, windYaw = GetStormFoxWind()
    end

    PublishWind(windSpeed, windYaw)
end

timer.Create("ZCity_Wind_Sync", 0.1, 0, SyncWindState)
SyncWindState()

concommand.Add("zcity_wind_test", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("[Ballistics + Wind] You must be an Admin to use this command!")
        return
    end

    local arg1 = args[1]
    local arg2 = args[2]
    local printMsg = IsValid(ply) and function(msg) ply:ChatPrint(msg) end or print

    if not arg1 then
        local sfForce, sfYaw = GetStormFoxWind()
        local activeForce = GetGlobalFloat("ZCity_Wind_Force", 0)
        local activeYaw = GetGlobalFloat("ZCity_Wind_Yaw", 0)

        printMsg("")
        printMsg("=== Z-City Bullet Wind Deflection Debug ===")
        printMsg("StormFox 2 Wind (Server): " .. string.format("%.2f m/s, %.1f deg", sfForce, sfYaw))
        if debugForceOverride >= 0 then
            printMsg("Debug Wind Override: ACTIVE (" .. string.format("%.2f m/s, %.1f deg", debugForceOverride, debugYawOverride) .. ")")
        elseif dynamicWind.Enabled then
            printMsg("Dynamic Wind Override: ACTIVE (" .. string.format("avg %.2f +/- %.2f m/s, yaw %.1f +/- %.1f deg, %.1fs targets", dynamicWind.BaseSpeed, dynamicWind.SpeedVariation, dynamicWind.BaseYaw, dynamicWind.YawVariation, dynamicWind.TargetInterval) .. ")")
        else
            printMsg("Debug Wind Override: INACTIVE (using StormFox 2 if available)")
        end
        local atmos = ZW.Atmosphere or {}
        printMsg("Active networked wind: " .. string.format("%.2f m/s, %.1f deg", activeForce, activeYaw))
        printMsg("Atmosphere Physics Simulation: " .. (config.AtmosphereEnabled and "ENABLED" or "DISABLED"))
        printMsg("Atmosphere Base Temp: " .. string.format("%.1f °C", atmos.TBase or 15))
        printMsg("Atmosphere Base Pres: " .. string.format("%.0f Pa", atmos.P0 or 101325))
        printMsg("Atmosphere Humidity: " .. string.format("%.1f%%", (atmos.RH or 0.4) * 100))
        printMsg("Map Sea Level Z Coordinate: " .. tostring(config.MapSeaLevelZ or 0) .. " (" .. math.Round((config.MapSeaLevelZ or 0) * 0.01905, 1) .. "m)")
        printMsg("Wind deflection multiplier: " .. tostring(config.WindMultiplier))
        printMsg("Native Z-City physical bullets: " .. tostring(config.ReplaceZCityBullets))
        printMsg("Sandbox physical bullet replacement: " .. tostring(config.ReplaceSandboxBullets))
        printMsg("Suppression effects: " .. tostring(config.Suppression))
        printMsg("")
        printMsg("Commands:")
        printMsg("  zcity_wind_test <force_m_s> <yaw_deg> - Set custom wind deflection")
        printMsg("  zcity_wind_test reset                 - Disable custom wind deflection")
        printMsg("  zcity_wind_dynamic <avg_m_s> <var_m_s> <yaw_deg> <yaw_var_deg> [target_sec]")
        printMsg("  zcity_wind_dynamic reset              - Disable dynamic wind")
        printMsg("  sv_zcity_wind_multiplier <val>        - Set wind deflection multiplier")
        printMsg("  sv_zcity_wind_replace_zcity_bullets <0/1> - Toggle native Z-City physical bullets")
        printMsg("  sv_zcity_wind_replace_sandbox_bullets <0/1> - Toggle Sandbox physical bullet replacement")
        printMsg("  sv_zcity_wind_suppression <0/1>       - Toggle near-miss suppression effects")
        printMsg("  sv_zcity_wind_atmosphere <0/1>        - Toggle realistic atmosphere physics scaling")
        printMsg("  sv_zcity_wind_sea_level <Z>           - Manually set absolute world sea level Z coordinate")
        printMsg("  zcity_wind_set_sealevel               - Calibrate sea level automatically at player's feet")
        printMsg("==========================================")
        return
    end

    if arg1 == "reset" or arg1 == "off" then
        debugForceOverride = -1
        dynamicWind.Enabled = false
        PublishWind(0, 0)
        printMsg("[Ballistics + Wind] Wind overrides cleared. Using StormFox 2 wind if available.")
        return
    end

    local force = tonumber(arg1)
    local yaw = tonumber(arg2 or "0")

    if not force then
        printMsg("[Ballistics + Wind] Invalid wind speed! Usage: zcity_wind_test <force> <yaw>")
        return
    end

    dynamicWind.Enabled = false
    debugForceOverride = force
    debugYawOverride = NormalizeYaw(yaw)
    PublishWind(force, yaw)

    printMsg("[Ballistics + Wind] Wind override set to: " .. string.format("%.2f m/s, %.1f deg", force, yaw))
end)

concommand.Add("zcity_wind_dynamic", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("[Ballistics + Wind] You must be an Admin to use this command!")
        return
    end

    local printMsg = IsValid(ply) and function(msg) ply:ChatPrint(msg) end or print
    local arg1 = args[1]

    if not arg1 then
        printMsg("Usage: zcity_wind_dynamic <avg_m_s> <variation_m_s> <yaw_deg> <yaw_variation_deg> [target_seconds]")
        printMsg("Example: zcity_wind_dynamic 6 3 90 25 18")
        printMsg("Current dynamic wind: " .. (dynamicWind.Enabled and "ACTIVE" or "INACTIVE"))
        return
    end

    if arg1 == "reset" or arg1 == "off" then
        dynamicWind.Enabled = false
        debugForceOverride = -1
        PublishWind(0, 0)
        printMsg("[Ballistics + Wind] Dynamic wind disabled. Using StormFox 2 wind if available.")
        return
    end

    local baseSpeed = tonumber(args[1])
    local speedVariation = tonumber(args[2])
    local baseYaw = tonumber(args[3])
    local yawVariation = tonumber(args[4])
    local targetInterval = tonumber(args[5] or "18")

    if not baseSpeed or not speedVariation or not baseYaw or not yawVariation then
        printMsg("[Ballistics + Wind] Invalid args. Usage: zcity_wind_dynamic <avg_m_s> <variation_m_s> <yaw_deg> <yaw_variation_deg> [target_seconds]")
        return
    end

    dynamicWind.BaseSpeed = math.Clamp(baseSpeed, 0, 80)
    dynamicWind.SpeedVariation = math.Clamp(math.abs(speedVariation), 0, 40)
    dynamicWind.BaseYaw = NormalizeYaw(baseYaw)
    dynamicWind.YawVariation = math.Clamp(math.abs(yawVariation), 0, 180)
    dynamicWind.TargetInterval = math.Clamp(targetInterval, 5, 120)
    dynamicWind.CurrentSpeed = math.max(0, dynamicWind.BaseSpeed + math.Rand(-dynamicWind.SpeedVariation, dynamicWind.SpeedVariation))
    dynamicWind.CurrentYaw = NormalizeYaw(dynamicWind.BaseYaw + math.Rand(-dynamicWind.YawVariation, dynamicWind.YawVariation))
    dynamicWind.Enabled = true
    debugForceOverride = -1
    lastDynamicThink = CurTime()

    PickDynamicWindTarget()
    PublishWind(dynamicWind.CurrentSpeed, dynamicWind.CurrentYaw)

    printMsg("[Ballistics + Wind] Dynamic wind enabled: " .. string.format("avg %.2f +/- %.2f m/s, yaw %.1f +/- %.1f deg, target every %.1fs", dynamicWind.BaseSpeed, dynamicWind.SpeedVariation, dynamicWind.BaseYaw, dynamicWind.YawVariation, dynamicWind.TargetInterval))
end)

cvars.AddChangeCallback("sv_zcity_wind_sea_level", function(_, _, newValue)
    local zVal = tonumber(newValue) or 0
    SetGlobalFloat("ZCity_Wind_SeaLevel", zVal)
    config.MapSeaLevelZ = zVal
end, "ZCityWind_SeaLevel_Sync")

local function LoadMapSeaLevel()
    local mapName = game.GetMap():lower()
    local zVal = 0

    if file.Exists("zcity_wind_sealevels.json", "DATA") then
        local data = util.JSONToTable(file.Read("zcity_wind_sealevels.json", "DATA") or "")
        if istable(data) and data[mapName] then
            zVal = tonumber(data[mapName]) or 0
        end
    end

    local convar = GetConVar("sv_zcity_wind_sea_level")
    if convar then
        convar:SetFloat(zVal)
        config.MapSeaLevelZ = zVal
    end
    SetGlobalFloat("ZCity_Wind_SeaLevel", zVal)

    if zVal ~= 0 then
        MsgC(Color(0, 255, 128), "[Z-City Wind] Loaded saved sea level for map " .. mapName .. ": " .. zVal .. " units (" .. math.Round(zVal * 0.01905, 1) .. "m)\n")
    end
end

hook.Add("Initialize", "ZCity_Wind_LoadSeaLevel", LoadMapSeaLevel)
LoadMapSeaLevel()

concommand.Add("zcity_wind_set_sealevel", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("[Ballistics + Wind] You must be an Admin to use this command!")
        return
    end

    local printMsg = IsValid(ply) and function(msg) ply:ChatPrint(msg) end or print
    local zVal = 0

    if IsValid(ply) then
        local plyPos = ply:GetPos()
        local tr = util.TraceLine({
            start = plyPos + Vector(0, 0, 10),
            endpos = plyPos - Vector(0, 0, 200),
            filter = ply
        })
        zVal = tr.Hit and tr.HitPos.z or plyPos.z
    else
        printMsg("[Ballistics + Wind] This command must be run by a player to detect position, or use: sv_zcity_wind_sea_level <value>")
        return
    end

    zVal = math.Round(zVal)

    local convar = GetConVar("sv_zcity_wind_sea_level")
    if convar then
        convar:SetFloat(zVal)
        config.MapSeaLevelZ = zVal
    end

    local mapName = game.GetMap():lower()
    local data = {}
    if file.Exists("zcity_wind_sealevels.json", "DATA") then
        data = util.JSONToTable(file.Read("zcity_wind_sealevels.json", "DATA") or "") or {}
    end
    data[mapName] = zVal

    file.Write("zcity_wind_sealevels.json", util.TableToJSON(data, true))

    printMsg("[Ballistics + Wind] Map sea level successfully calibrated and saved to Z = " .. zVal .. " (" .. math.Round(zVal * 0.01905, 1) .. "m).")
end)
