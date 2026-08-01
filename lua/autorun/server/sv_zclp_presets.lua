util.AddNetworkString("zclp_create_preset")
util.AddNetworkString("zclp_update_preset")
util.AddNetworkString("zclp_load_preset")
util.AddNetworkString("zclp_notify")
util.AddNetworkString("zclp_give_preset")
util.AddNetworkString("zclp_save_snapshot")
util.AddNetworkString("zclp_respawned")

local PROTECTED_WEAPONS = {
    ["weapon_hands_sh"] = true
}

local function notify(ply, phraseKey, ...)
    if not IsValid(ply) then return end
    local args = {...}
    net.Start("zclp_notify")
    net.WriteString(phraseKey or "request_failed")
    net.WriteUInt(#args, 4)
    for _, arg in ipairs(args) do
        net.WriteString(tostring(arg))
    end
    net.Send(ply)
end

local function cleanPresetName(name)
    name = tostring(name or "")
    name = string.Trim(name)
    name = string.sub(name, 1, ZCLP.MaxNameLength)
    return name
end

local function isValidPresetName(name)
    if not isstring(name) then return false end
    if name == "" then return false end
    if #name > ZCLP.MaxNameLength then return false end
    return true
end

local function sanitizeWeaponInfo(value, depth)
    depth = depth or 0
    if depth > 8 then return nil end

    local t = type(value)
    if t == "number" or t == "string" or t == "boolean" then
        return value
    end

    if t == "table" then
        local out = {}
        for k, v in pairs(value) do
            local keyType = type(k)
            if keyType ~= "number" and keyType ~= "string" then continue end
            local safeVal = sanitizeWeaponInfo(v, depth + 1)
            if safeVal ~= nil then
                out[k] = safeVal
            end
        end
        return out
    end

    return nil
end

local function collectWeapons(ply)
    local out = {}
    for _, wep in ipairs(ply:GetWeapons()) do
        if not IsValid(wep) then continue end
        local class = wep:GetClass()
        if PROTECTED_WEAPONS[class] then continue end

        local info
        if wep.GetInfo then
            info = sanitizeWeaponInfo(wep:GetInfo())
        end

        local weaponData = {
            class = class,
            clip1 = wep:Clip1(),
            clip2 = wep:Clip2()
        }

        if istable(info) then
            weaponData.info = info
        end

        out[#out + 1] = {
            class = weaponData.class,
            clip1 = weaponData.clip1,
            clip2 = weaponData.clip2,
            info = weaponData.info
        }
    end
    return out
end

local function collectClothes(ply)
    local classes = {}
    local worn = ply:GetNetVar("zc_clothes", {})
    if not istable(worn) then
        return classes
    end

    for _, entIndex in ipairs(worn) do
        local cloth = Entity(entIndex)
        if not IsValid(cloth) then continue end
        local class = cloth:GetClass()
        if not isstring(class) or class == "" then continue end
        classes[#classes + 1] = class
    end

    return classes
end

local function collectSnapshot(ply)
    local activeWep = ""
    if IsValid(ply:GetActiveWeapon()) then
        activeWep = ply:GetActiveWeapon():GetClass()
    end

    local inv = ply:GetNetVar("Inventory", {})
    local ammoPreset = {}
    local attachmentsPreset = {}

    if istable(inv.Ammo) then
        for ammoId, count in pairs(inv.Ammo) do
            if isnumber(ammoId) and isnumber(count) and count > 0 then
                ammoPreset[ammoId] = math.floor(count)
            end
        end
    end

    if istable(inv.Attachments) then
        for k, v in pairs(inv.Attachments) do
            local safeVal = sanitizeWeaponInfo(v)
            if safeVal ~= nil then
                attachmentsPreset[k] = safeVal
            end
        end
    end

    return {
        meta = {
            zcityVersion = hg and hg.Version or "unknown",
            savedAt = os.time()
        },
        weapons = collectWeapons(ply),
        activeWeapon = activeWep,
        armor = table.Copy(ply:GetNetVar("Armor", {})),
        clothes = collectClothes(ply),
        ammo = ammoPreset,
        inventoryAttachments = attachmentsPreset
    }
end

local function removeCurrentClothes(ply)
    local worn = ply:GetNetVar("zc_clothes", {})
    if not istable(worn) then return end

    for _, entIndex in ipairs(worn) do
        local cloth = Entity(entIndex)
        if not IsValid(cloth) then continue end
        if cloth.Unwear then
            cloth:Unwear(ply)
        end
        SafeRemoveEntity(cloth)
    end
    ply:SetNetVar("zc_clothes", {})
end

local function removeArmor(ply)
    ply.armors = {}
    if ply.SyncArmor then
        ply:SyncArmor()
    else
        ply:SetNetVar("Armor", {})
    end
end

local function clearPlayerLoadout(ply)
    -- Remove weapons (except protected)
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) then
            local class = wep:GetClass()
            if not PROTECTED_WEAPONS[class] then
                ply:StripWeapon(class)
            end
        end
    end

    -- Remove armor
    removeArmor(ply)

    -- Remove clothes
    removeCurrentClothes(ply)

    -- Remove ammo
    ply:StripAmmo()

    -- Reset inventory netvar if it exists
    local inv = ply:GetNetVar("Inventory", {})
    if istable(inv) then
        inv.Ammo = {}
        inv.Attachments = {}
        ply:SetNetVar("Inventory", inv)
    end
end

local function applyArmorPreset(ply, armorPreset)
    if not istable(armorPreset) then return end

    for _, armor in pairs(armorPreset) do
        if isstring(armor) then
            hg.AddArmor(ply, armor)
        end
    end
end

local function applyWeaponsPreset(ply, preset)
    for _, data in ipairs(preset or {}) do
        if istable(data) and isstring(data.class) then
            local class = data.class
            if not ply:HasWeapon(class) then
                ply:Give(class)
            end
            
            local wep = ply:GetWeapon(class)
            if IsValid(wep) then
                if istable(data.info) and wep.SetInfo then
                    wep:SetInfo(data.info)
                end

                if isnumber(data.clip1) and data.clip1 >= 0 then
                    wep:SetClip1(data.clip1)
                end

                if isnumber(data.clip2) and data.clip2 >= 0 then
                    wep:SetClip2(data.clip2)
                end
            end
        end
    end
end

local function applyClothesPreset(ply, clothesPreset)
    removeCurrentClothes(ply)
    if not istable(clothesPreset) then return end

    for _, class in ipairs(clothesPreset) do
        if not isstring(class) then continue end
        local ent = ents.Create(class)
        if not IsValid(ent) then continue end
        ent:SetPos(ply:GetPos())
        ent:Spawn()
        if ent.Wear then
            ent:Wear(ply)
        end
    end
end

local function applyAmmoPreset(ply, ammoPreset)
    if not istable(ammoPreset) then return end

    for ammoId, _ in pairs(ply:GetAmmo()) do
        local ammoName = game.GetAmmoName(ammoId)
        if ammoName then
            ply:SetAmmo(0, ammoName)
        end
    end

    for ammoId, count in pairs(ammoPreset) do
        if not isnumber(ammoId) or not isnumber(count) then continue end
        local ammoName = game.GetAmmoName(ammoId)
        if not ammoName then continue end
        ply:GiveAmmo(math.max(0, math.floor(count)), ammoName, true)
    end
end

local function applyInventoryAttachmentsPreset(ply, attachmentsPreset)
    if not istable(attachmentsPreset) then return end

    ply.inventory = ply.inventory or {}
    ply.inventory.Weapons = ply.inventory.Weapons or {}
    ply.inventory.Ammo = ply.inventory.Ammo or {}
    ply.inventory.Armor = ply.inventory.Armor or {}
    ply.inventory.Attachments = {}

    for k, v in pairs(attachmentsPreset) do
        local safeVal = sanitizeWeaponInfo(v)
        if safeVal ~= nil then
            ply.inventory.Attachments[k] = safeVal
        end
    end

    ply.inventory.Ammo = ply:GetAmmo()
    ply:SetNetVar("Inventory", ply.inventory)
end

local function applyPreset(ply, preset)
    if not istable(preset) then return end
    
    clearPlayerLoadout(ply)
    
    applyWeaponsPreset(ply, preset.weapons)
    applyArmorPreset(ply, preset.armor)
    applyClothesPreset(ply, preset.clothes)
    applyAmmoPreset(ply, preset.ammo)
    applyInventoryAttachmentsPreset(ply, preset.inventoryAttachments)

    if isstring(preset.activeWeapon) and preset.activeWeapon ~= "" and ply:HasWeapon(preset.activeWeapon) then
        ply:SelectWeapon(preset.activeWeapon)
    end
end

net.Receive("zclp_create_preset", function(_, ply)
    if not IsValid(ply) then return end
    if not ZCLP.IsCompatible() then
        notify(ply, "incompat")
        return
    end

    local name = cleanPresetName(net.ReadString())
    if not isValidPresetName(name) then
        notify(ply, "invalid_name")
        return
    end

    local snapshot = collectSnapshot(ply)
    net.Start("zclp_save_snapshot")
    net.WriteString(name)
    net.WriteTable(snapshot)
    net.WriteBool(false)
    net.Send(ply)
end)

net.Receive("zclp_update_preset", function(_, ply)
    if not IsValid(ply) then return end
    if not ZCLP.IsCompatible() then
        notify(ply, "incompat")
        return
    end

    local name = cleanPresetName(net.ReadString())
    if not isValidPresetName(name) then
        notify(ply, "invalid_name")
        return
    end

    local snapshot = collectSnapshot(ply)
    net.Start("zclp_save_snapshot")
    net.WriteString(name)
    net.WriteTable(snapshot)
    net.WriteBool(true)
    net.Send(ply)
end)

net.Receive("zclp_load_preset", function(_, ply)
    if not IsValid(ply) then return end
    if not ZCLP.IsCompatible() then
        notify(ply, "incompat")
        return
    end

    local name = net.ReadString()
    local preset = net.ReadTable()

    if not istable(preset) or table.Count(preset) == 0 then
        notify(ply, "not_found")
        return
    end

    applyPreset(ply, preset)
    notify(ply, "loaded")
end)

net.Receive("zclp_give_preset", function(_, ply)
    if not IsValid(ply) then return end
    if not ZCLP.IsCompatible() then
        notify(ply, "incompat")
        return
    end

    local name = net.ReadString()
    local preset = net.ReadTable()
    local target = net.ReadEntity()

    if not IsValid(target) or not target:IsPlayer() then
        notify(ply, "request_failed")
        return
    end

    if not istable(preset) or table.Count(preset) == 0 then
        notify(ply, "not_found")
        return
    end

    applyPreset(target, preset)

    -- Notify sender
    notify(ply, "given", target:Nick())

    -- Notify receiver
    notify(target, "received", ply:Nick())
end)

hook.Add("PlayerDeath", "ZCLP_TrackDeath", function(ply)
    ply.ZCLP_IsDead = true
end)

hook.Add("PlayerSpawn", "ZCLP_AutoSpawn", function(ply)
    if not ZCLP.IsCompatible() then return end
    
    -- Check if it's a real respawn after death
    if not ply.ZCLP_IsDead then return end
    ply.ZCLP_IsDead = false

    timer.Simple(0.2, function()
        if not IsValid(ply) or not ply:Alive() then return end
        
        -- Double check if we are in a vehicle or fake
        if ply:InVehicle() then return end
        if ply.IsFake and ply:IsFake() then return end

        net.Start("zclp_respawned")
        net.Send(ply)
    end)
end)
