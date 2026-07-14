local ZW = ZCityWind
local config = ZW.Config
local tickInterval = engine.TickInterval()
local cos = math.cos
local sin = math.sin
local rad = math.rad
local sqrt = math.sqrt

local cachedWindVector = Vector(0, 0, 0)
local cachedWindSpeed = 0
local cachedWindYaw = 0
local cachedWindSourceX = 0
local cachedWindSourceY = 0
local cachedWindSourceZ = 0

local function UpdateCachedWindVector()
    local windSpeed = GetGlobalFloat("ZCity_Wind_Force", 0)
    local windYaw = GetGlobalFloat("ZCity_Wind_Yaw", 0)

    if windSpeed == cachedWindSpeed and windYaw == cachedWindYaw then return end

    cachedWindSpeed = windSpeed
    cachedWindYaw = windYaw

    if windSpeed > 0.01 then
        local windRad = rad(windYaw)
        local sourceSpeed = windSpeed * 52.5
        cachedWindSourceX = cos(windRad) * sourceSpeed
        cachedWindSourceY = sin(windRad) * sourceSpeed
        cachedWindSourceZ = 0
    else
        cachedWindSourceX = 0
        cachedWindSourceY = 0
        cachedWindSourceZ = 0
    end

    cachedWindVector.x = cachedWindSourceX
    cachedWindVector.y = cachedWindSourceY
    cachedWindVector.z = cachedWindSourceZ
end

timer.Create("ZCity_Wind_Cache_Vector", 0.1, 0, UpdateCachedWindVector)
UpdateCachedWindVector()

local atmosphere = ZW.Atmosphere

local function UpdateAtmosphereCache()
    local tBase = 15
    local rainAmount = 0

    if StormFox2 then
        if StormFox2.Temperature and StormFox2.Temperature.Get then
            tBase = StormFox2.Temperature.Get("celsius") or 15
        end
        if StormFox2.Weather and StormFox2.Weather.GetRainAmount then
            rainAmount = StormFox2.Weather.GetRainAmount() or 0
        end
    end

    atmosphere.TBase = tBase
    atmosphere.P0 = 101325 - 3000 * rainAmount
    atmosphere.RH = 0.4 + 0.6 * rainAmount
    atmosphere.SeaLevel = GetGlobalFloat("ZCity_Wind_SeaLevel", 0)
end

timer.Create("ZCity_Wind_Cache_Atmosphere", 0.5, 0, UpdateAtmosphereCache)
UpdateAtmosphereCache()

local function RegisterBulletHook()
    if hg and hg.PhysBullet then
        local pluginID = hg.PhysBullet.ID or "PhysBullet"
        local eventName = "HG.Plugin.List[" .. pluginID .. "].Hooks[BulletThink]"

        hook.Add(eventName, "ZCity_StormFox_Wind_Dev", function(bullet)
            local vel = bullet.Vel
            if not vel or not bullet.Pos then return end

            local velLen = vel:Length()
            if velLen <= 1 then return end

            -- 1. Apply atmospheric air resistance scaling (always active for physical bullets)
            if not bullet.OriginalAirResistMul then
                bullet.OriginalAirResistMul = bullet.AirResistMul or 0.0001
            end

            local eta = 1.0
            local h, T_local, P, p_sat, p_v, rho = 0, 15, 101325, 1705, 682, 1.225

            if config.AtmosphereEnabled then
                local baseZ = atmosphere.SeaLevel or 0
                h = (bullet.Pos.z - baseZ) * 0.01905
                h = math.Clamp(h, -3000, 44000)

                local T_base = atmosphere.TBase or 15
                local P0 = atmosphere.P0 or 101325
                local RH = atmosphere.RH or 0.4

                T_local = T_base - 0.0065 * h
                P = P0 * ((1 - 2.25577e-5 * h) ^ 5.25588)
                local T_denom = T_local + 237.3
                if T_denom == 0 then T_denom = 0.0001 end
                p_sat = 610.78 * math.exp((17.27 * T_local) / T_denom)
                p_v = RH * p_sat
                local T_kelvin = T_local + 273.15
                if T_kelvin <= 0 then T_kelvin = 0.0001 end
                rho = (P - 0.378 * p_v) / (287.058 * T_kelvin)
                eta = math.Clamp(rho / 1.225, 0.1, 2.0)
            end

            bullet.AirResistMul = bullet.OriginalAirResistMul * eta

            -- 2. Wind deflection calculation
            if cachedWindSpeed <= 0.01 then return end
            if config.WindMultiplier == 0 then return end

            if config.Debug then
                bullet._windTicks = (bullet._windTicks or 0) + 1
                if bullet._windTicks % 5 == 1 then
                    local side = SERVER and "SERVER" or "CLIENT"
                    MsgC(SERVER and ZW.Colors.Cyan or ZW.Colors.Yellow, string.format("[Z-City Wind %s] Bullet #%s Tick %d: Wind=%.1f m/s, Yaw=%.1f deg, Alt=%.1fm, Temp=%.1fC, Pres=%.0fPa, Hum=%.0f%%, Density=%.3fkg/m3, DragScale=%.3f, Vel=%s, Pos=%s\n",
                        side, tostring(bullet.Key), bullet._windTicks, cachedWindSpeed, cachedWindYaw, h, T_local, P, (p_sat > 0 and (p_v / p_sat) * 100 or 0), rho, eta, tostring(bullet.Vel), tostring(bullet.Pos)))
                end
            end

            local resistMul = bullet.AirResistMul or 0.0001
            local velX = vel.x
            local velY = vel.y
            local velZ = vel.z
            local relX = velX - cachedWindSourceX
            local relY = velY - cachedWindSourceY
            local relZ = velZ - cachedWindSourceZ
            local relVelLen = sqrt(relX * relX + relY * relY + relZ * relZ)
            local dragMul = relVelLen * resistMul
            local noWindDragMul = velLen * resistMul
            local windAccX = (-relX * dragMul) - (-velX * noWindDragMul)
            local windAccY = (-relY * dragMul) - (-velY * noWindDragMul)
            local windAccZ = (-relZ * dragMul) - (-velZ * noWindDragMul)
            local forwardX = velX / velLen
            local forwardY = velY / velLen
            local forwardZ = velZ / velLen
            local forwardDot = windAccX * forwardX + windAccY * forwardY + windAccZ * forwardZ

            windAccX = windAccX - forwardX * forwardDot
            windAccY = windAccY - forwardY * forwardDot
            windAccZ = windAccZ - forwardZ * forwardDot

            local driftMul = tonumber(bullet.ZCityWindDriftMul or bullet.WindDriftMul) or 1
            local windScale = tickInterval * config.WindMultiplier * driftMul
            vel.x = velX + windAccX * windScale
            vel.y = velY + windAccY * windScale
            vel.z = velZ + windAccZ * windScale
            bullet.Vel = vel
        end)

        MsgC(ZW.Colors.Green, "[Z-City Wind] Dynamically registered BulletThink hook on event: " .. eventName .. "\n")
        return true
    end

    return false
end

if not RegisterBulletHook() then
    timer.Create("ZCity_Wind_HookRegister", 0.5, 20, function()
        if RegisterBulletHook() then
            timer.Remove("ZCity_Wind_HookRegister")
        end
    end)
end
