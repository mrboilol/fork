-- JSON custom config loader and console commands (Server only)

if not SERVER then return end

ZCityWindBallistics = ZCityWindBallistics or {}

local PREFIX = "[Z-City Wind Ballistics] "

function ZCityWindBallistics.LoadCustomProfiles()
    if not file or not util then return end

    ZCityWindBallistics.customProfiles = {weapons = {}, ammo = {}}
    ZCityWindBallistics.ProfileCache = {}

    local files = file.Find("zcity_wind_ballistics/*.json", "DATA")
    if not files then return end

    for _, fileName in ipairs(files) do
        local path = "zcity_wind_ballistics/" .. fileName
        local raw = file.Read(path, "DATA")
        local decoded = raw and util.JSONToTable(raw)

        if istable(decoded) then
            if istable(decoded.weapons) then
                for key, profile in pairs(decoded.weapons) do
                    if istable(profile) then
                        ZCityWindBallistics.customProfiles.weapons[ZCityWindBallistics.NormalizeKey(key)] = profile
                    end
                end
            end

            if istable(decoded.ammo) then
                for key, profile in pairs(decoded.ammo) do
                    if istable(profile) then
                        ZCityWindBallistics.customProfiles.ammo[ZCityWindBallistics.NormalizeKey(key)] = profile
                    end
                end
            end
        else
            MsgC(Color(255, 120, 80), PREFIX .. "Failed to parse data/" .. path .. "\n")
        end
    end
end

local function PrintProfile(target, text)
    if IsValid(target) then
        target:ChatPrint(text)
    else
        print(text)
    end
end

-- Initialize directory and custom profiles loading
file.CreateDir("zcity_wind_ballistics")
ZCityWindBallistics.LoadCustomProfiles()

-- Console commands
concommand.Add("zcity_wind_ballistics_reload", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    ZCityWindBallistics.LoadCustomProfiles()
    PrintProfile(ply, PREFIX .. "custom profiles reloaded")
end)

concommand.Add("zcity_wind_ballistics_ping", function(ply)
    PrintProfile(ply, string.format("%sloaded | enabled=%s drag=%s velocity=%s wind=%s spread=%s",
        PREFIX,
        tostring(ZCityWindBallistics.Enabled),
        tostring(ZCityWindBallistics.ApplyDrag),
        tostring(ZCityWindBallistics.ApplyVelocity),
        tostring(ZCityWindBallistics.ApplyWind),
        tostring(ZCityWindBallistics.ApplySpread)
    ))
end)

concommand.Add("zcity_wind_ballistics_dump", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    if not IsValid(ply) then
        print(PREFIX .. "Run this command as a player to inspect the active weapon profile.")
        return
    end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then
        PrintProfile(ply, PREFIX .. "no active weapon")
        return
    end

    local primary = weapon.Primary or {}
    local ammoName = primary.Ammo
    local settings = ammoName and hg and hg.ammotypeshuy and hg.ammotypeshuy[ammoName] and hg.ammotypeshuy[ammoName].BulletSettings
    local profile = ZCityWindBallistics.BuildProfile({AmmoType = ammoName, Inflictor = weapon, Speed = settings and settings.Speed}, weapon, ammoName, settings)

    PrintProfile(ply, PREFIX .. "weapon=" .. weapon:GetClass() .. " ammo=" .. tostring(ammoName))
    PrintProfile(ply, string.format("barrel=%smm builtin=%s velocity=%.3f drag=%.3f wind=%.3f spread=%.3f", 
        tostring(profile.BarrelLengthMM or "?"), 
        tostring(profile.BuiltInWeaponProfile == true), 
        profile.VelocityMult or 1, 
        profile.DragMul or 1, 
        profile.WindDriftMul or 1, 
        profile.SpreadMul or 1
    ))
end)
