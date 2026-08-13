local ZW = ZCityWind
local sqrt = math.sqrt

-- Keep every atmospheric consumer on the same altitude model. Source positions
-- are converted to metres and measured from the calibrated map sea level.
function ZW.GetAtmosphereAtZ(worldZ)
    local atmosphere = ZW.Atmosphere or {}
    local config = ZW.Config or {}
    local baseZ = atmosphere.SeaLevel or config.MapSeaLevelZ or 0
    local altitude = math.Clamp(((tonumber(worldZ) or baseZ) - baseZ) * 0.01905, -3000, 44000)
    local baseTemperature = atmosphere.TBase or 15
    local basePressure = math.max(atmosphere.P0 or 101325, 1)
    local humidity = atmosphere.RH or 0.4
    local temperature = baseTemperature - 0.0065 * altitude
    local pressure = basePressure * ((1 - 2.25577e-5 * altitude) ^ 5.25588)
    local temperatureDenominator = temperature + 237.3

    if temperatureDenominator == 0 then temperatureDenominator = 0.0001 end

    local saturatedPressure = 610.78 * math.exp((17.27 * temperature) / temperatureDenominator)
    local vaporPressure = humidity * saturatedPressure
    local temperatureKelvin = math.max(temperature + 273.15, 0.0001)
    local density = (pressure - 0.378 * vaporPressure) / (287.058 * temperatureKelvin)

    return altitude, temperature, pressure, saturatedPressure, vaporPressure, density, pressure / basePressure
end

function ZW.NormalizePhysBulletInput(bullet)
    if not istable(bullet) then return bullet end

    local spread = bullet.Spread
    if spread == nil then
        bullet.Spread = vector_origin
    elseif isnumber(spread) then
        bullet.Spread = Vector(spread, spread, 0)
    elseif istable(spread) and not isvector(spread) then
        bullet.Spread = Vector(tonumber(spread.x or spread[1]) or 0, tonumber(spread.y or spread[2]) or 0, tonumber(spread.z or spread[3]) or 0)
    end

    return bullet
end

function ZW.IsZCityGamemode()
    local activeGamemode = engine and engine.ActiveGamemode and engine.ActiveGamemode()
    if activeGamemode == "zcity" then return true end

    local gamemodeTable = gmod and gmod.GetGamemode and gmod.GetGamemode()
    if istable(gamemodeTable) and (gamemodeTable.FolderName == "zcity" or gamemodeTable.Name == "[L] ZCity") then return true end

    return false
end

function ZW.IsSandboxGamemode()
    local activeGamemode = engine and engine.ActiveGamemode and engine.ActiveGamemode()
    if activeGamemode == "sandbox" then return true end

    local gamemodeTable = gmod and gmod.GetGamemode and gmod.GetGamemode()
    if istable(gamemodeTable) and (gamemodeTable.FolderName == "sandbox" or gamemodeTable.Name == "Sandbox") then return true end

    return false
end

function ZW.NormalizeVector(vec)
    if not isvector(vec) then return nil end

    local lenSqr = vec:LengthSqr()
    if lenSqr <= 0 then return nil end

    return vec / sqrt(lenSqr)
end

local defaultScopeClickMil = 0.1

local function GetBulletScopeZeroingWeapon(bullet)
    local inflictor = bullet and bullet.Inflictor
    if IsValid(inflictor) and inflictor.IsWeapon and inflictor:IsWeapon() then return inflictor end

    local weapon = bullet and bullet.Weapon
    if IsValid(weapon) and weapon.IsWeapon and weapon:IsWeapon() then return weapon end

    local shooter = bullet and (bullet.Shooter or bullet.Attacker or bullet.Owner)
    if IsValid(shooter) and shooter.GetActiveWeapon then
        local activeWeapon = shooter:GetActiveWeapon()
        if IsValid(activeWeapon) and activeWeapon.IsWeapon and activeWeapon:IsWeapon() then return activeWeapon end
    end
end

local function GetScopeZeroingClicks(wep)
    local clicksX = tonumber(wep.ReticleClicksX)
    local clicksY = tonumber(wep.ReticleClicksY)

    if clicksX == nil and wep.GetNWInt then
        clicksX = wep:GetNWInt("ZCityScopeClicksX", 0)
    end

    if clicksY == nil and wep.GetNWInt then
        clicksY = wep:GetNWInt("ZCityScopeClicksY", 0)
    end

    return math.Round(clicksX or 0), math.Round(clicksY or 0)
end

function ZW.ApplyScopeZeroingToBullet(bullet)
    if not istable(bullet) or bullet._ZCityScopeZeroingApplied then return bullet end

    local wep = GetBulletScopeZeroingWeapon(bullet)
    if not IsValid(wep) or not wep.sizeperekrestie then return bullet end

    local clicksX, clicksY = GetScopeZeroingClicks(wep)
    if clicksX == 0 and clicksY == 0 then return bullet end

    local clickMil = math.max(0, tonumber(wep.scope_click_mil) or defaultScopeClickMil)
    if clickMil <= 0 then return bullet end

    local dir = ZW.NormalizeVector(bullet.DirOriginal) or ZW.NormalizeVector(bullet.Dir) or ZW.NormalizeVector(bullet.Vel)
    if not dir then return bullet end

    local ang = dir:Angle()
    local correctedDir = dir + ang:Right() * math.tan(clicksX * clickMil / 1000) + ang:Up() * math.tan(clicksY * clickMil / 1000)
    if correctedDir:LengthSqr() <= 0 then return bullet end
    correctedDir:Normalize()

    local velLen = isvector(bullet.Vel) and bullet.Vel:Length() or nil
    if velLen and velLen > 0 then
        bullet.Vel = correctedDir * velLen
        bullet.StartLen = velLen
        bullet.Dir = nil
        bullet.DirOriginal = nil
    else
        bullet.Dir = correctedDir
        bullet.DirOriginal = nil
    end

    bullet._ZCityScopeZeroingApplied = true
    bullet._ZCityScopeZeroingClicksX = clicksX
    bullet._ZCityScopeZeroingClicksY = clicksY
    bullet._ZCityScopeZeroingClickMil = clickMil

    return bullet
end
function ZW.ResolveAmmoID(ammo)
    if isnumber(ammo) then return ammo end
    if isstring(ammo) and game.GetAmmoID then
        local ammoID = game.GetAmmoID(ammo)
        if isnumber(ammoID) and ammoID >= 0 then return ammoID end
    end
end

function ZW.GetAmmoDamageFallback(ammoID)
    ammoID = ZW.ResolveAmmoID(ammoID)
    if not ammoID then return nil end

    local playerDamage = game.GetAmmoPlayerDamage and tonumber(game.GetAmmoPlayerDamage(ammoID))
    if playerDamage and playerDamage > 0 then return playerDamage end

    local ammoData = game.GetAmmoData and game.GetAmmoData(ammoID)
    if istable(ammoData) then
        local dataDamage = tonumber(ammoData.plydmg or ammoData.PlayerDamage or ammoData.damage or ammoData.Damage)
        if dataDamage and dataDamage > 0 then return dataDamage end
    end
end

function ZW.RepairSandboxPhysBulletVelocity(bullet)
    if not istable(bullet) or not bullet._ZCityWindSandboxBullet then return bullet end

    local dir = ZW.NormalizeVector(bullet.Dir) or ZW.NormalizeVector(bullet.DirOriginal) or ZW.NormalizeVector(bullet.Vel)
    if not dir then return bullet end

    local speed = tonumber(bullet._ZCityWindSandboxSpeed or bullet.Speed) or 320
    if speed < 16 then
        speed = 320
    end

    bullet.Dir = dir
    bullet.DirOriginal = dir
    bullet.Speed = speed
    bullet.Vel = dir * (speed * 52.5)
    bullet.StartLen = bullet.Vel:Length()

    -- Z-City's spread conversion uses len = 1 whenever Dir/DirOriginal are present.
    -- Sandbox bullets already carry a real Vel, so force the core to derive direction from it.
    bullet.Dir = nil
    bullet.DirOriginal = nil

    return bullet
end

ZW.LegacySurfaceHardness = {
    [MAT_METAL] = 1,
    [MAT_COMPUTER] = 0.9,
    [MAT_VENT] = 0.9,
    [MAT_GRATE] = 0.9,
    [MAT_FLESH] = 0.5,
    [MAT_ALIENFLESH] = 0.3,
    [MAT_SAND] = 0.1,
    [MAT_DIRT] = 0.9,
    [74] = 0.1,
    [85] = 0.2,
    [MAT_WOOD] = 0.5,
    [MAT_FOLIAGE] = 0.5,
    [MAT_CONCRETE] = 0.9,
    [MAT_TILE] = 0.8,
    [MAT_SLOSH] = 0.05,
    [MAT_PLASTIC] = 0.3,
    [MAT_GLASS] = 0.6
}

ZW.LegacyMaterialDamage = {
    [MAT_METAL] = 0.3,
    [MAT_DIRT] = 0.3,
    [MAT_CONCRETE] = 0.25,
    [MAT_GRATE] = 0.99,
    [MAT_VENT] = 0.45,
    [MAT_TILE] = 0.3,
    [MAT_COMPUTER] = 0.45,
    [MAT_WOOD] = 0.6,
    [MAT_GLASS] = 0.99
}

local function GetLegacyPenetrationDirection(bullet, trace)
    return ZW.NormalizeVector(trace and trace.Normal) or ZW.NormalizeVector(bullet and bullet.Vel) or ZW.NormalizeVector(bullet and bullet.Dir)
end

function ZW.AddToTraceFilter(bullet, ent)
    if not istable(bullet) or not IsValid(ent) then return end

    local filter = bullet.TraceFilter
    if filter == nil then
        bullet.TraceFilter = ent
    elseif istable(filter) then
        local found = false
        for i = 1, #filter do
            if filter[i] == ent then
                found = true
                break
            end
        end
        if not found then
            table.insert(filter, ent)
        end
    elseif isfunction(filter) then
        local oldFilter = filter
        bullet.TraceFilter = function(e, ...)
            if e == ent then return false end
            return oldFilter(e, ...)
        end
    else
        if filter ~= ent then
            bullet.TraceFilter = { filter, ent }
        end
    end
end


function ZW.PerformCustomBulletHit(bullet, plugin, trace, len, len_before)
    if bullet.DieOnHit then
        bullet:Die()
        return
    end

    -- Prevent getting stuck in collision overlap (e.g. ragdoll bones)
    if trace and IsValid(trace.Entity) and bullet._lastHitEntity == trace.Entity and bullet._lastExitPos then
        local dist = trace.HitPos:Distance(bullet._lastExitPos)
        if dist < 4.0 then
            local dir = ZW.NormalizeVector(bullet.Vel) or trace.Normal
            return dir, len, len_before
        end
    end

    -- 1. Check for starting/all solid to prevent getting stuck
    if trace and (trace.StartSolid or trace.AllSolid) then
        if bullet.OnStopped then
            bullet:OnStopped(trace.HitPos, "solid", trace)
        end
        bullet:Die()
        return
    end

    -- 2. Calculate if it ricochets or penetrates
    local newVelNormal, lenLeft, ricochet, angDiff, stopped = plugin.CalcHit(trace, len, len_before, bullet.TraceMask, bullet.Penetration, bullet.SizeMins, bullet.SizeMaxs)

    if stopped then
        ricochet = false -- Stopped-ricochet fix
        if bullet.OnStopped then
            bullet:OnStopped(trace.HitPos, "hit", trace)
        end
        bullet:Die()
        return
    end

    if ricochet then
        -- Handle ricochet velocity reduction
        local lenSubtractFrac = (90 - angDiff) / 90
        local resistMul = plugin.CalcMaterialResist(trace.MatType)
        len_before = len_before - math.min(resistMul * bullet.AirResistMul * 140 * lenSubtractFrac * len_before * len_before, len_before)
        local newLen = math.min(lenLeft, len_before)

        -- Reduce bullet damage on ricochet by 15% (Z-City style)
        bullet.Damage = (bullet.Damage or 0) * 0.85

        if SERVER and (not HG_BulletImpactSounds or not HG_BulletImpactSounds.PlayRicochet(trace.HitPos)) then
            local rnd = math.random(12)
            if rnd == 8 then rnd = 9 end
            sound.Play("arc9_eft_shared/ricochet/ricochet" .. rnd .. ".wav", trace.HitPos, 75, math.random(90, 110))
        end

        if bullet.PostRicochet then
            bullet:PostRicochet(newVelNormal, newLen, ricochet, angDiff, len_before, trace)
        end

        return newVelNormal, newLen, len_before
    else
        -- 3. Penetration (non-ricochet)
        if trace.HitSky then
            bullet:Die()
            return
        end

        local dir = GetLegacyPenetrationDirection(bullet, trace)
        local penetration = tonumber(bullet.Penetration) or 10
        local hardness = ZW.LegacySurfaceHardness[trace.MatType] or 0.5
        
        -- Z-City style virtual penetration power (multiplied by 3)
        local virtualPen = penetration * 3
        local maxDistance = math.Clamp(virtualPen / hardness * 0.4, 1, 128)

        local exitTrace = nil
        local searchDistance = 1
        local step = 2

        -- Robust backward trace-loop to find the exit of the wall
        while searchDistance < maxDistance do
            local testPos = trace.HitPos + dir * searchDistance
            local tr = util.TraceLine({
                start = testPos,
                endpos = trace.HitPos,
                mask = bullet.TraceMask or MASK_SHOT,
                filter = bullet.TraceFilter
            })

            if not tr.StartSolid then
                exitTrace = tr
                break
            end

            searchDistance = searchDistance + step
        end

        if exitTrace then
            local thickness = exitTrace.HitPos:Distance(trace.HitPos)
            local distSqr = thickness * thickness
            local newLenBefore = plugin.CalcVelocityLostInMaterial(trace.MatType, distSqr, len_before)

            if newLenBefore > 1000 then -- bullet still has enough speed/energy to continue
                bullet.Pos = exitTrace.HitPos + dir * 2.0 -- Offset slightly past exit to avoid double-hitting
                len_before = newLenBefore
                local newLen = math.max(lenLeft - thickness, 0)

                if IsValid(trace.Entity) and not trace.Entity:IsWorld() then
                    ZW.AddToTraceFilter(bullet, trace.Entity)
                    bullet._lastHitEntity = trace.Entity
                    bullet._lastExitPos = bullet.Pos
                end

                -- Update remaining bullet penetration for armor/future penetrations
                bullet.Penetration = math.max(penetration * (1 - thickness / maxDistance), 0)

                -- Reduce bullet damage by the material's damage modifier (Z-City style)
                local isGrate = trace.MatType == MAT_GRATE or (trace.HitPos and bit.band(util.PointContents(trace.HitPos), CONTENTS_GRATE) ~= 0)
                local dmgModifier = isGrate and 0.99 or ZW.LegacyMaterialDamage[trace.MatType] or 0.5
                bullet.Damage = (bullet.Damage or 0) * dmgModifier

                if SERVER then
                    local effectdata = EffectData()
                    effectdata:SetOrigin(exitTrace.HitPos)
                    effectdata:SetEntity(exitTrace.Entity)
                    effectdata:SetStart(exitTrace.StartPos)
                    effectdata:SetSurfaceProp(exitTrace.SurfaceProps)
                    effectdata:SetDamageType(DMG_BULLET)
                    effectdata:SetHitBox(exitTrace.HitBox)

                    local replacedSound = HG_BulletImpactSounds and HG_BulletImpactSounds.PlayMaterialImpact(exitTrace)
                    if replacedSound then
                        HG_BulletImpactSounds.MakeEffectSilent(effectdata)
                        util.Effect("Impact_GMOD", effectdata, true, true)
                    else
                        util.Effect("Impact", effectdata, true, true)
                    end
                end

                if bullet.PostPenetration then
                    bullet:PostPenetration(newVelNormal, newLen, ricochet, angDiff, len_before, trace)
                end

                return newVelNormal, newLen, len_before
            end
        end

        -- Stopped inside wall
        if bullet.OnStopped then
            bullet:OnStopped(trace.HitPos, "penetration", trace)
        end
        bullet:Die()
    end
end
