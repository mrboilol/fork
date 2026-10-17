if not SERVER then return end

-- networking
util.AddNetworkString("xdefc_zcity_hurtexpression")
util.AddNetworkString("xdefc_zcity_reloadexpression")
util.AddNetworkString("xdefc_zcity_attack")

hook.Add("Think", "xdefc_zcity_bg_update", function()
    for _, ply in ipairs(player.GetAll()) do
        if not ply:GetNWBool("XDEFC_Enabled") then continue end

        local currentGroups = ""

        for _, v in ipairs(ply:GetBodyGroups()) do
            if v.submodels and #v.submodels > 0 then
                currentGroups = currentGroups .. v.id .. "-" .. ply:GetBodygroup(v.id) .. ","
            end
        end

        if ply:GetNWString("XDEFC_Groups") ~= currentGroups then
            ply:SetNWString("XDEFC_Groups", currentGroups)
        end
    end
end)

-- hurt
hook.Add("HomigradDamage", "xdefc_zcity_hurt", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply:GetNWBool("XDEFC_Enabled") then return end

    net.Start("xdefc_zcity_hurtexpression")
        net.WriteEntity(ply)
    net.Broadcast()
end)

-- reload
hook.Add("HGReloading", "xdefc_zcity_reload_expression", function(wep)
    if not IsValid(wep) then return end

    local ply = wep:GetOwner()

    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply:GetNWBool("XDEFC_Enabled") then return end

    local reloadTime = wep.StaminaReloadTime or wep.ReloadTime or 2

    net.Start("xdefc_zcity_reloadexpression")
        net.WriteEntity(ply)
        net.WriteFloat(reloadTime)
    net.Broadcast()
end)

-- attack
local nextAttack = {}

local function HasBaseRecursive(classname, targetbase)
    local stored = weapons.GetStored(classname)

    if not stored then return false end

    local checked = {}

    while stored and stored.Base and not checked[stored.Base] do
        if stored.Base == targetbase then
            return true
        end

        checked[stored.Base] = true
        stored = weapons.GetStored(stored.Base)
    end

    return false
end

hook.Add("Think", "xdefc_zcity_attack_sv", function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:IsPlayer() then continue end
        if not ply:GetNWBool("XDEFC_Enabled") then continue end

        -- player must actually be holding attack
        if not ply:KeyDown(IN_ATTACK) then continue end

        local wep = ply:GetActiveWeapon()

        if not IsValid(wep) then continue end

        local class = wep:GetClass()

        local isHomigrad =
            HasBaseRecursive(class, "homigrad_base")

        local isMelee =
            HasBaseRecursive(class, "weapon_melee")

        -- fallback for some weapons
        local isCustom =
            wep.AttackTime ~= nil

        if not isHomigrad and not isMelee and not isCustom then
            continue
        end

        -- cooldown
        nextAttack[ply] = nextAttack[ply] or 0

        if CurTime() < nextAttack[ply] then
            continue
        end

        nextAttack[ply] = CurTime() + 0.15

        net.Start("xdefc_zcity_attack")
            net.WriteEntity(ply)
        net.Broadcast()
    end
end)

-- wounded
local WOUNDED_THINK_INTERVAL = 0.1
local woundedNextThink = 0

hook.Add("Think", "xdefc_zcity_wounded_sv", function()
    if CurTime() < woundedNextThink then return end
    woundedNextThink = CurTime() + WOUNDED_THINK_INTERVAL

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:IsPlayer() then continue end
        if not ply:GetNWBool("XDEFC_Enabled") then continue end
        if not ply:Alive() then continue end

        local org = ply.organism
        if not istable(org) then continue end

        local wounded =
            (org.blood or math.huge) < 3500 or
            (org.brain or 0) >= 0.25 or
            (org.pain or 0) >= 50

        if wounded then
            if xdefc and xdefc.main and xdefc.main.eventTrigger then
                xdefc.main.eventTrigger(ply, "Wounded", 1, 0.3)
            end
        end
    end
end)
