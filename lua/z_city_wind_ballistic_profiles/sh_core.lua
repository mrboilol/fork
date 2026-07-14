-- Core calculation functions, bullet wrappers, and hooks (Optimized Edition)

ZCityWindBallistics = ZCityWindBallistics or {}

local PREFIX = "[Z-City Wind Ballistics] "

-- Cache for compiled weapon+ammo profiles to prevent table creation and string searches on hot paths
ZCityWindBallistics.ProfileCache = ZCityWindBallistics.ProfileCache or {}

-- Helper utilities
function ZCityWindBallistics.Clamp(value, minValue, maxValue)
    value = tonumber(value)
    if not value then return nil end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function ZCityWindBallistics.NormalizeKey(value)
    if value == nil then return nil end
    value = string.lower(tostring(value))
    value = string.gsub(value, "%s+", "")
    value = string.gsub(value, "[^%w%.%-_x]", "")
    return value
end

function ZCityWindBallistics.ContainsAny(value, hints)
    if not value then return false end
    value = string.lower(value)
    for _, hint in ipairs(hints) do
        if string.find(value, hint, 1, true) then return true end
    end
    return false
end

function ZCityWindBallistics.GetWeaponFromBullet(bullet)
    local weapon = bullet.Inflictor
    if IsValid(weapon) and weapon:IsWeapon() then return weapon end

    weapon = bullet.Weapon
    if IsValid(weapon) and weapon:IsWeapon() then return weapon end

    local owner = bullet.Shooter or bullet.Attacker or bullet.Owner
    if IsValid(owner) and owner.GetActiveWeapon then
        weapon = owner:GetActiveWeapon()
        if IsValid(weapon) and weapon:IsWeapon() then return weapon end
    end
end

function ZCityWindBallistics.GetAmmoNameFromBullet(bullet)
    if isstring(bullet.AmmoType) then return bullet.AmmoType end
    if isstring(bullet.AmmoID) then return bullet.AmmoID end

    local ammoID = bullet.AmmoID or bullet.AmmoType
    if isnumber(ammoID) and ammoID >= 0 then
        local name = game.GetAmmoName(ammoID)
        if name and name ~= "" then return name end
    end
end

function ZCityWindBallistics.GetAmmoSettings(bullet, ammoName)
    if hg and istable(hg.ammotypeshuy) and ammoName then
        local ammoData = hg.ammotypeshuy[ammoName]
        if istable(ammoData) and istable(ammoData.BulletSettings) then
            return ammoData.BulletSettings, ammoData
        end
    end

    local ammoID = bullet.AmmoID or bullet.AmmoType
    if isnumber(ammoID) and game.GetAmmoData then
        local ammoData = game.GetAmmoData(ammoID)
        if istable(ammoData) then
            return ammoData, ammoData
        end
    end
end

function ZCityWindBallistics.GetBulletSpeedMPS(bullet, settings)
    if settings and tonumber(settings.Speed) then return tonumber(settings.Speed) end
    if tonumber(bullet.Speed) then return tonumber(bullet.Speed) end
    if bullet.StartLen then return tonumber(bullet.StartLen) / 52.5 end
    if bullet.Vel then return bullet.Vel:Length() / 52.5 end
end

function ZCityWindBallistics.IsSupportedBullet(bullet, ammoName, settings)
    if not istable(bullet) then return false end
    if bullet._ZCityWindBallisticsApplied then return false end
    if bullet.DontUsePhysBullets then return false end

    local lowerAmmo = ammoName and string.lower(ammoName) or ""
    if ZCityWindBallistics.ContainsAny(lowerAmmo, ZCityWindBallistics.HEAVY_PROJECTILE_HINTS) then return false end

    local diameter = tonumber(bullet.Diameter) or (settings and tonumber(settings.Diameter))
    if diameter and diameter > 14.5 then return false end

    return bullet.Vel ~= nil or bullet.Dir ~= nil
end

function ZCityWindBallistics.MergeProfile(base, profile)
    if not istable(profile) then return base end
    for key, value in pairs(profile) do
        base[key] = value
    end
    return base
end

function ZCityWindBallistics.BlendProfile(base, profile)
    if not istable(profile) then return base end

    for key, value in pairs(profile) do
        local numeric = tonumber(value)

        if key == "VelocityMult" or key == "MuzzleVelocityMult" then
            base.VelocityMult = (base.VelocityMult or 1) * (numeric or 1)
        elseif key == "DragMul" or key == "AirResistanceMul" then
            base.DragMul = (base.DragMul or 1) * (numeric or 1)
        elseif key == "WindDriftMul" or key == "WindMul" then
            base.WindDriftMul = (base.WindDriftMul or 1) * (numeric or 1)
        elseif key == "SpreadMul" or key == "SpreadMultiplier" then
            base.SpreadMul = (base.SpreadMul or 1) * (numeric or 1)
        elseif key == "AirResistMul" then
            base.AirResistMul = value
        else
            base[key] = value
        end
    end

    return base
end

function ZCityWindBallistics.CalculateAmmoProfile(bullet, ammoName, settings)
    local profile = {}
    local speed = ZCityWindBallistics.GetBulletSpeedMPS(bullet, settings)
    local mass = tonumber(bullet.Mass) or (settings and tonumber(settings.Mass))
    local diameter = tonumber(bullet.Diameter) or (settings and tonumber(settings.Diameter))

    if mass and diameter and mass > 0 and diameter > 0 then
        local referenceAreaMass = (5.56 * 5.56) / 4.0
        local areaMass = (diameter * diameter) / mass
        local dragMul = ZCityWindBallistics.Clamp(areaMass / referenceAreaMass, 0.45, 2.4) or 1

        profile.DragMul = dragMul
        profile.WindDriftMul = ZCityWindBallistics.Clamp(math.sqrt(dragMul), 0.65, 1.55) or 1
    else
        profile.DragMul = 1
        profile.WindDriftMul = 1
    end

    if speed and speed < 430 then
        profile.WindDriftMul = (profile.WindDriftMul or 1) * 1.12
        profile.DragMul = (profile.DragMul or 1) * 1.08
    elseif speed and speed > 830 then
        profile.WindDriftMul = (profile.WindDriftMul or 1) * 0.95
    end

    local ammoKey = ammoName and string.lower(ammoName) or ""
    for hint in pairs(ZCityWindBallistics.PISTOL_AMMO_HINTS) do
        if string.find(ammoKey, hint, 1, true) then
            profile.WindDriftMul = (profile.WindDriftMul or 1) * 1.08
            break
        end
    end

    return profile
end

function ZCityWindBallistics.ResolveBarrelLengthMM(weapon, profile)
    local millimeters = (profile and tonumber(profile.BarrelLengthMM or profile.BarrelLengthMillimeters)) or (IsValid(weapon) and tonumber(weapon.BarrelLengthMM or weapon.BarrelLengthMillimeters))
    if millimeters then return millimeters end

    local centimeters = (profile and tonumber(profile.BarrelLengthCM or profile.BarrelLengthCentimeters)) or (IsValid(weapon) and tonumber(weapon.BarrelLengthCM or weapon.BarrelLengthCentimeters))
    if centimeters then return centimeters * 10 end

    local meters = (profile and tonumber(profile.BarrelLengthM or profile.BarrelLengthMeters)) or (IsValid(weapon) and tonumber(weapon.BarrelLengthM or weapon.BarrelLengthMeters))
    if meters then return meters * 1000 end

    local inches = (profile and tonumber(profile.BarrelLengthInches or profile.BarrelLengthIn)) or (IsValid(weapon) and tonumber(weapon.BarrelLengthInches or weapon.BarrelLengthIn))
    if inches then return inches * 25.4 end

    local generic = (profile and tonumber(profile.BarrelLength)) or (IsValid(weapon) and tonumber(weapon.BarrelLength))
    if generic then
        if generic >= 100 then return generic end
        if generic >= 10 and generic <= 60 then return generic * 25.4 end
        if generic > 0 and generic < 3 then return generic * 1000 end
    end

    -- Dynamic fallback estimation based on classification
    if IsValid(weapon) then
        local classification = ZCityWindBallistics.GetWeaponClassification(weapon)
        if classification == "pistol" then
            return 115
        elseif classification == "smg" then
            return 225
        elseif classification == "bolt_action" then
            return 650
        elseif classification == "marksman" then
            return 560
        elseif classification == "rifle" then
            return 415
        end
    end
end

function ZCityWindBallistics.GetReferenceBarrelLength(ammoName, settings)
    if not ammoName and not settings then return 415 end -- Default reference (standard rifle)

    local name = ammoName and string.lower(ammoName) or ""

    -- 1. String signature check (highly accurate for known calibers)
    -- Pistol / SMG calibers
    if string.find(name, "9x19") or string.find(name, "9x18") or string.find(name, "45acp") or string.find(name, ".45") or string.find(name, "380") or string.find(name, "fn57") or string.find(name, "5.7x28") or string.find(name, "40s&w") or string.find(name, "10mm") then
        return 115
    end

    -- Magnum / Revolver calibers
    if string.find(name, "357") or string.find(name, "44mag") or string.find(name, ".44") or string.find(name, "7.62x25") or string.find(name, "7.63x25") then
        return 150
    end

    -- Shotgun calibers
    if string.find(name, "12/") or string.find(name, "12g") or string.find(name, "gauge") or string.find(name, "buckshot") or string.find(name, "slug") then
        return 500
    end

    -- Subsonic rifle / special
    if string.find(name, "9x39") then
        return 200
    end

    -- Heavy sniper / Anti-materiel calibers
    if string.find(name, "50bmg") or string.find(name, "12.7x") or string.find(name, "408") or string.find(name, "cheytac") or string.find(name, "338") or string.find(name, "lapua") or string.find(name, "norma") then
        return 650
    end

    -- 2. Physical signature fallback (if name is unknown/custom)
    if istable(settings) then
        local diameter = tonumber(settings.Diameter)
        local speed = tonumber(settings.Speed)
        local numBullets = tonumber(settings.NumBullet) or 1

        if diameter and speed then
            if numBullets > 1 then
                return 500 -- Shotgun / buckshot
            elseif diameter >= 11.4 and speed >= 700 then
                return 650 -- Heavy sniper (.50 BMG, 12.7mm, 14.5mm)
            elseif diameter >= 7.0 and diameter <= 9.3 and speed >= 700 then
                return 560 -- Full-power rifle / DMR (7.62x51, 7.62x54R)
            elseif diameter >= 7.0 and diameter <= 9.6 and speed < 360 then
                return 200 -- Subsonic rifle (9x39mm, .300 Blackout subsonic)
            elseif diameter >= 4.5 and diameter <= 6.8 and speed >= 700 then
                return 415 -- Intermediate rifle (5.45x39, 5.56x45, 7.62x39)
            elseif diameter >= 7.5 and diameter <= 11.5 and speed < 450 then
                return 115 -- Standard pistol (.45 ACP, 9x19, 9x18)
            end
        end
    end

    -- Default fallback for any other calibers (standard intermediate rifle length)
    return 415
end

function ZCityWindBallistics.GetWeaponClassification(weapon)
    if not IsValid(weapon) then return "rifle" end

    local class = string.lower(weapon:GetClass() or "")
    local printName = string.lower(tostring(weapon.PrintName or ""))
    local combined = class .. " " .. printName

    -- Bolt Action / Sniper
    if ZCityWindBallistics.ContainsAny(combined, ZCityWindBallistics.BOLT_ACTION_HINTS) or string.find(combined, "sniper") or string.find(combined, "awm") or string.find(combined, "awp") or string.find(combined, "t5000") or string.find(combined, "remington") then
        return "bolt_action"
    end

    -- Marksman / DMR
    if ZCityWindBallistics.ContainsAny(combined, ZCityWindBallistics.MARKSMAN_HINTS) or string.find(combined, "dmr") or string.find(combined, "vss") or string.find(combined, "svu") then
        return "marksman"
    end

    -- SMG / Pistol caliber carbine
    if string.find(combined, "smg") or string.find(combined, "mp5") or string.find(combined, "uzi") or string.find(combined, "bizon") or string.find(combined, "vityaz") or string.find(combined, "scorpion") or string.find(combined, "p90") or string.find(combined, "ump") or string.find(combined, "kriss") or string.find(combined, "vector") or string.find(combined, "rak") or string.find(combined, "sterling") or string.find(combined, "thompson") or string.find(combined, "ppsh") or string.find(combined, "mac10") or string.find(combined, "mac11") then
        return "smg"
    end

    -- Pistol
    if string.find(combined, "pistol") or string.find(combined, "glock") or string.find(combined, "beretta") or string.find(combined, "cz75") or string.find(combined, "usp") or string.find(combined, "sig") or string.find(combined, "p220") or string.find(combined, "p250") or string.find(combined, "p320") or string.find(combined, "makarov") or string.find(combined, "tokarev") or string.find(combined, "tt33") or string.find(combined, "revolver") or string.find(combined, "python") or string.find(combined, "colt") or string.find(combined, "deagle") or string.find(combined, "desert") or string.find(combined, "grach") or string.find(combined, "aps") then
        if not string.find(combined, "rifle") and not string.find(combined, "carbine") and not string.find(combined, "m4") and not string.find(combined, "m16") and not string.find(combined, "spear") then
            return "pistol"
        end
    end

    return "rifle"
end

function ZCityWindBallistics.CalculateRealisticProfile(weapon, ammoName, baseProfile, settings)
    local profile = {}
    if istable(baseProfile) then
        for k, v in pairs(baseProfile) do
            profile[k] = v
        end
    end

    local classification = ZCityWindBallistics.GetWeaponClassification(weapon)
    local L_ref = ZCityWindBallistics.GetReferenceBarrelLength(ammoName, settings)

    -- Base multipliers
    local baseVel, baseDrag, baseWind, baseSpread = 1.0, 1.0, 1.0, 1.0

    if classification == "bolt_action" then
        baseVel = 1.04
        baseDrag = 0.88
        baseWind = 0.88
        baseSpread = 0.45
    elseif classification == "marksman" then
        baseVel = 1.01
        baseDrag = 0.94
        baseWind = 0.94
        baseSpread = 0.70
    elseif classification == "smg" then
        baseVel = 0.95
        baseDrag = 1.02
        baseWind = 1.05
        baseSpread = 1.10
    elseif classification == "pistol" then
        baseVel = 0.90
        baseDrag = 1.05
        baseWind = 1.08
        baseSpread = 1.20
    end

    local L = ZCityWindBallistics.ResolveBarrelLengthMM(weapon, profile)
    if L and L_ref then
        local r = L / L_ref
        r = ZCityWindBallistics.Clamp(r, 0.2, 3.0) or 1.0

        -- Continuous power law scaling functions (replacing stepped jumps/crutches)
        local v_scale = (r < 1) and (r ^ 0.22) or (r ^ 0.12)
        local drag_scale = (1 / r) ^ 0.08
        local wind_scale = (1 / r) ^ 0.10
        local spread_scale = (1 / r) ^ 0.22

        baseVel = baseVel * v_scale
        baseDrag = baseDrag * drag_scale
        baseWind = baseWind * wind_scale
        baseSpread = baseSpread * spread_scale
    end

    -- Apply calculations only if they are not explicitly overridden
    profile.VelocityMult = profile.VelocityMult or baseVel
    profile.DragMul = profile.DragMul or baseDrag
    profile.WindDriftMul = profile.WindDriftMul or baseWind
    profile.SpreadMul = profile.SpreadMul or baseSpread

    return profile
end

function ZCityWindBallistics.CalculateWeaponProfile(weapon)
    -- Keep for backwards compatibility, fallback to realistic calculation
    return ZCityWindBallistics.CalculateRealisticProfile(weapon, nil, nil, nil)
end


-- Resolve profile with caching support
function ZCityWindBallistics.BuildProfile(bullet, weapon, ammoName, settings)
    local weaponClass = IsValid(weapon) and weapon:GetClass() or "unknown"
    local ammoKey = ammoName or "unknown"
    local cacheKey = weaponClass .. "_" .. ammoKey

    -- Try returning the cached profile (O(1) lookup, no GC allocations)
    local cached = ZCityWindBallistics.ProfileCache[cacheKey]
    if cached then return cached end

    -- Compile profile starting with basic ammo characteristics
    local profile = ZCityWindBallistics.CalculateAmmoProfile(bullet, ammoName, settings)
    local builtInProfile = ZCityWindBallistics.BUILTIN_WEAPON_PROFILES[weaponClass]

    -- Resolve realistic weapon profile parameters
    local baseProfile = {}
    if builtInProfile then
        for k, v in pairs(builtInProfile) do
            baseProfile[k] = v
        end
        profile.BuiltInWeaponProfile = true
    elseif IsValid(weapon) then
        local explicit = weapon.ZCityWindProfile or weapon.ZCityBallistics or weapon.BallisticProfile
        if istable(explicit) then
            for k, v in pairs(explicit) do
                baseProfile[k] = v
            end
        end
    end

    -- Calculate using our continuous physical formula
    local resolvedWeaponProfile = ZCityWindBallistics.CalculateRealisticProfile(weapon, ammoName, baseProfile, settings)

    -- Blend weapon profile into the base profile
    ZCityWindBallistics.BlendProfile(profile, resolvedWeaponProfile)

    -- Apply custom JSON overrides
    local normalizedAmmoKey = ZCityWindBallistics.NormalizeKey(ammoName)
    if normalizedAmmoKey then
        local ammoOverride = ZCityWindBallistics.customProfiles.ammo[normalizedAmmoKey]
        if ammoOverride then ZCityWindBallistics.MergeProfile(profile, ammoOverride) end
    end

    if IsValid(weapon) then
        local weaponOverride = ZCityWindBallistics.customProfiles.weapons[ZCityWindBallistics.NormalizeKey(weaponClass)]
        if weaponOverride then ZCityWindBallistics.MergeProfile(profile, weaponOverride) end
    end

    -- Clamp safety limits
    profile.VelocityMult = ZCityWindBallistics.Clamp(profile.VelocityMult or 1, 0.65, 1.25) or 1
    profile.DragMul = ZCityWindBallistics.Clamp(profile.DragMul or 1, 0.35, 2.8) or 1
    profile.WindDriftMul = ZCityWindBallistics.Clamp(profile.WindDriftMul or 1, 0.35, 2.25) or 1
    profile.SpreadMul = ZCityWindBallistics.Clamp(profile.SpreadMul or 1, 0.05, 5.0) or 1
    profile.BarrelLengthMM = ZCityWindBallistics.ResolveBarrelLengthMM(weapon, profile)

    -- Save to cache
    ZCityWindBallistics.ProfileCache[cacheKey] = profile

    return profile
end

function ZCityWindBallistics.ApplyVelocityProfile(bullet, profile)
    if not ZCityWindBallistics.ApplyVelocity then return end

    local mult = profile.VelocityMult or 1
    if math.abs(mult - 1) < 0.001 then return end
    if not bullet.Vel then return end

    bullet.Vel = bullet.Vel * mult
    if bullet.StartLen then bullet.StartLen = bullet.StartLen * mult end
    bullet._ZCityWindBallisticsVelocityMult = mult
end

function ZCityWindBallistics.ApplyDragProfile(bullet, profile)
    if not ZCityWindBallistics.ApplyDrag then return end

    local current = tonumber(bullet.AirResistMul) or 0.00002
    if current <= 0 then current = 0.00002 end
    local explicit = tonumber(profile.AirResistMul)

    if explicit and explicit > 0 then
        bullet.AirResistMul = ZCityWindBallistics.Clamp(explicit, 0.000004, 0.00012) or current
    else
        bullet.AirResistMul = ZCityWindBallistics.Clamp(current * (profile.DragMul or 1), 0.000004, 0.00012) or current
    end

    bullet._ZCityWindBallisticsDragMul = bullet.AirResistMul / current
end

function ZCityWindBallistics.ApplyWindProfile(bullet, profile)
    if not ZCityWindBallistics.ApplyWind then return end

    local current = tonumber(bullet.ZCityWindDriftMul or bullet.WindDriftMul) or 1
    bullet.ZCityWindDriftMul = ZCityWindBallistics.Clamp(current * (profile.WindDriftMul or 1), 0.25, 3) or current
end

function ZCityWindBallistics.IsSupportedBulletForSpread(bullet, ammoName, settings)
    if not istable(bullet) then return false end
    if bullet._ZCityWindBallisticsApplied then return false end
    if bullet.DontUsePhysBullets then return false end

    local lowerAmmo = ammoName and string.lower(ammoName) or ""
    if ZCityWindBallistics.ContainsAny(lowerAmmo, ZCityWindBallistics.HEAVY_PROJECTILE_HINTS) then return false end

    local diameter = tonumber(bullet.Diameter) or (settings and tonumber(settings.Diameter))
    if diameter and diameter > 14.5 then return false end

    return true
end

function ZCityWindBallistics.OverrideCreateBullet()
    local plugin = hg and hg.PhysBullet
    if not plugin or not plugin.CreateBullet then return false end
    if plugin._ZCityWindProfilesCreateBulletOverridden then return true end

    local oldCreateBullet = plugin.CreateBullet
    function plugin.CreateBullet(bullet)
        if ZCityWindBallistics.Enabled and ZCityWindBallistics.ApplySpread and istable(bullet) then
            local ammoName = ZCityWindBallistics.GetAmmoNameFromBullet(bullet)
            local settings = ZCityWindBallistics.GetAmmoSettings(bullet, ammoName)
            if ZCityWindBallistics.IsSupportedBulletForSpread(bullet, ammoName, settings) then
                local weapon = ZCityWindBallistics.GetWeaponFromBullet(bullet)
                local profile = ZCityWindBallistics.BuildProfile(bullet, weapon, ammoName, settings)
                
                -- Cache profile on the bullet table itself to avoid ANY lookups during BulletPostSetup hook
                bullet._ZCityResolvedProfile = profile

                if profile.SpreadMul and profile.SpreadMul ~= 1 then
                    local spread = bullet.Spread
                    if spread == nil then
                        bullet.Spread = vector_origin
                    elseif isnumber(spread) then
                        bullet.Spread = Vector(spread, spread, 0)
                    elseif istable(spread) and not isvector(spread) then
                        bullet.Spread = Vector(tonumber(spread.x or spread[1]) or 0, tonumber(spread.y or spread[2]) or 0, tonumber(spread.z or spread[3]) or 0)
                    end
                    
                    bullet.Spread = bullet.Spread * profile.SpreadMul
                    bullet._ZCityWindBallisticsSpreadMul = profile.SpreadMul
                end
            end
        end

        return oldCreateBullet(bullet)
    end

    plugin._ZCityWindProfilesCreateBulletOverridden = true
    MsgC(Color(120, 220, 255), PREFIX .. "wrapped plugin.CreateBullet to apply spread profiles\n")
    return true
end

function ZCityWindBallistics.ApplyBulletProfile(bullet)
    if not ZCityWindBallistics.Enabled then return end

    local ammoName = ZCityWindBallistics.GetAmmoNameFromBullet(bullet)
    local settings = ZCityWindBallistics.GetAmmoSettings(bullet, ammoName)
    if not ZCityWindBallistics.IsSupportedBullet(bullet, ammoName, settings) then return end

    -- Retrieve pre-resolved profile from CreateBullet to avoid O(1) cache lookup
    local profile = bullet._ZCityResolvedProfile
    if not profile then
        local weapon = ZCityWindBallistics.GetWeaponFromBullet(bullet)
        profile = ZCityWindBallistics.BuildProfile(bullet, weapon, ammoName, settings)
    end

    bullet._ZCityWindBallisticsApplied = true

    ZCityWindBallistics.ApplyVelocityProfile(bullet, profile)
    ZCityWindBallistics.ApplyDragProfile(bullet, profile)
    ZCityWindBallistics.ApplyWindProfile(bullet, profile)

    if ZCityWindBallistics.DebugEnabled then
        local weapon = ZCityWindBallistics.GetWeaponFromBullet(bullet)
        local weaponClass = IsValid(weapon) and weapon:GetClass() or "unknown"
        MsgC(Color(120, 220, 255), string.format("%s%s | ammo=%s barrel=%s builtin=%s vel=%.3f drag=%.3f wind=%.3f spread=%.3f air=%.8f\n",
            PREFIX,
            weaponClass,
            tostring(ammoName or "unknown"),
            tostring(profile.BarrelLengthMM or "?"),
            tostring(profile.BuiltInWeaponProfile == true),
            profile.VelocityMult or 1,
            profile.DragMul or 1,
            profile.WindDriftMul or 1,
            profile.SpreadMul or 1,
            bullet.AirResistMul or 0
        ))
    end
end

function ZCityWindBallistics.RegisterBulletPostSetupHook()
    local plugin = hg and hg.PhysBullet
    if not plugin then return false end

    local pluginID = plugin.ID or "PhysBullet"
    local eventName = "HG.Plugin.List[" .. pluginID .. "].Hooks[BulletPostSetup]"

    hook.Add(eventName, "ZCity_Wind_BallisticProfiles", ZCityWindBallistics.ApplyBulletProfile)
    MsgC(Color(120, 220, 255), PREFIX .. "registered BulletPostSetup hook on " .. eventName .. "\n")

    ZCityWindBallistics.OverrideCreateBullet()

    return true
end

-- Hook retries and entry points
if not ZCityWindBallistics.RegisterBulletPostSetupHook() then
    timer.Create("ZCityWindBallistics_HookRetry", 0.5, 40, function()
        if ZCityWindBallistics.RegisterBulletPostSetupHook() then
            timer.Remove("ZCityWindBallistics_HookRetry")
        end
    end)
end

hook.Add("InitPostEntity", "ZCityWindBallistics_InitPostEntity", function()
    timer.Simple(0, ZCityWindBallistics.RegisterBulletPostSetupHook)
end)

hook.Add("HomigradRun", "ZCityWindBallistics_HomigradRun", ZCityWindBallistics.RegisterBulletPostSetupHook)
