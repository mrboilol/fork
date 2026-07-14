local ZW = ZCityWind
local config = ZW.Config

local nativePhysBulletClasses = {
    weapon_ags_30_handheld = true
}

local function GetWeaponClassName(tbl)
    if IsValid(tbl) and tbl.GetClass then
        return tbl:GetClass()
    end

    if not istable(tbl) then return nil end
    return tbl.ClassName or tbl.Class or tbl.Folder
end

local function IsZCityWeaponTable(tbl)
    if not istable(tbl) and not IsValid(tbl) then return false end
    return tbl.ZCityWindUsePhysBullets == true or tbl.ishgwep == true or tbl.Base == "homigrad_base"
end

function ZW.IsZCityWeaponTable(tbl)
    return IsZCityWeaponTable(tbl)
end

function ZW.IsNativeZCityPhysBulletWeapon(tbl)
    if not istable(tbl) and not IsValid(tbl) then return false end
    if tbl.ZCityWindNativePhysBullets == true then return true end

    local className = GetWeaponClassName(tbl)
    return className ~= nil and nativePhysBulletClasses[className] == true
end

function ZW.IsWindForcedZCityPhysBulletWeapon(tbl)
    return IsZCityWeaponTable(tbl) and not ZW.IsNativeZCityPhysBulletWeapon(tbl)
end

local function ShouldUsePhysicalBullets(tbl)
    if not IsZCityWeaponTable(tbl) then return false end
    if tbl.DontUsePhysBullets or tbl.ZCityWindDisablePhysBullets then return false end
    return true
end

local function EnablePhysicalBulletsOnTable(tbl)
    if not ShouldUsePhysicalBullets(tbl) then return false end

    if ZW.IsWindForcedZCityPhysBulletWeapon(tbl) then
        tbl.ZCityWindForcedPhysBullets = true
    end

    if tbl.UsePhysBullets == true then return false end

    tbl.UsePhysBullets = true
    return true
end

local function EnablePhysicalBulletsForWeapon(ent)
    if not IsValid(ent) or not ent.IsWeapon or not ent:IsWeapon() then return false end
    return EnablePhysicalBulletsOnTable(ent)
end

function ZW.RefreshWeaponPhysicalBulletFlags()
    if not config.ReplaceZCityBullets then return false end
    if not ZW.IsZCityGamemode() then return false end

    local changed = 0

    if weapons and weapons.GetList then
        for _, stored in ipairs(weapons.GetList()) do
            if EnablePhysicalBulletsOnTable(stored) then
                changed = changed + 1
            end

            local className = GetWeaponClassName(stored)
            local canonical = className and weapons.GetStored and weapons.GetStored(className)
            if canonical and canonical ~= stored and EnablePhysicalBulletsOnTable(canonical) then
                changed = changed + 1
            end
        end
    end

    if ents and ents.GetAll then
        for _, ent in ipairs(ents.GetAll()) do
            if EnablePhysicalBulletsForWeapon(ent) then
                changed = changed + 1
            end
        end
    end

    if changed > 0 and config.Debug then
        MsgC(ZW.Colors.Green, "[Z-City Wind] Enabled native physical bullets for " .. changed .. " Z-City weapon entries.\n")
    end

    return changed > 0
end

hook.Add("InitPostEntity", "ZCity_Wind_EnableNativePhysBullets", function()
    ZW.RefreshWeaponPhysicalBulletFlags()
end)

hook.Add("HomigradRun", "ZCity_Wind_EnableNativePhysBullets", function()
    ZW.RefreshWeaponPhysicalBulletFlags()
end)

hook.Add("OnReloaded", "ZCity_Wind_EnableNativePhysBullets", function()
    ZW.RefreshWeaponPhysicalBulletFlags()
end)

hook.Add("OnEntityCreated", "ZCity_Wind_EnableNativePhysBullets", function(ent)
    if not config.ReplaceZCityBullets then return end
    if not ZW.IsZCityGamemode() then return end
    if not IsValid(ent) or not ent.IsWeapon or not ent:IsWeapon() then return end

    timer.Simple(0, function()
        EnablePhysicalBulletsForWeapon(ent)
    end)
end)

timer.Create("ZCity_Wind_EnableNativePhysBullets_Retry", 1, 20, function()
    ZW.RefreshWeaponPhysicalBulletFlags()
end)
