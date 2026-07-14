local ZW = ZCityWind
local config = ZW.Config

local function ShouldReplaceSandboxBullet(bullet)
    if not config.ReplaceSandboxBullets then return false end
    if not ZW.IsSandboxGamemode() then return false end
    if ZW.IsZCityGamemode() then return false end
    if GetGlobalBool("PhysBullets_ReplaceDefault", false) then return false end
    if not istable(bullet) or bullet.DontUsePhysBullets or bullet.ZCityWindDisablePhysBullets then return false end
    if not bullet.Src or not bullet.Dir then return false end

    local plugin = hg and hg.PhysBullet
    if not plugin or not plugin.CreateBullet then return false end

    return true
end

local function GetBulletAttacker(ent, bullet)
    local attacker = bullet.Attacker
    if IsValid(attacker) then return attacker end

    if IsValid(ent) and ent.IsWeapon and ent:IsWeapon() then
        local owner = ent:GetOwner()
        if IsValid(owner) then return owner end
    end

    return ent
end

local function PrepareSandboxPhysBullet(ent, bullet)
    local physBullet = table.Copy(bullet)
    local attacker = GetBulletAttacker(ent, physBullet)
    local incomingVel = isvector(physBullet.Vel) and physBullet.Vel or nil
    local incomingVelLen = incomingVel and incomingVel:Length() or 0
    local dir = ZW.NormalizeVector(physBullet.Dir) or ZW.NormalizeVector(incomingVel)

    physBullet.Attacker = attacker
    physBullet.Shooter = IsValid(physBullet.Shooter) and physBullet.Shooter or attacker
    physBullet.Owner = IsValid(physBullet.Owner) and physBullet.Owner or attacker
    physBullet.Inflictor = IsValid(physBullet.Inflictor) and physBullet.Inflictor or (IsValid(ent) and ent or attacker)
    physBullet.Dir = dir or physBullet.Dir
    physBullet.DirOriginal = ZW.NormalizeVector(physBullet.DirOriginal) or physBullet.Dir
    physBullet.Num = 1
    physBullet.AmmoID = ZW.ResolveAmmoID(physBullet.AmmoID or physBullet.AmmoType) or physBullet.AmmoID

    local damage = tonumber(physBullet.Damage)
    if not damage or damage <= 0 then
        local fallbackDamage = ZW.GetAmmoDamageFallback(physBullet.AmmoID or physBullet.AmmoType)
        if fallbackDamage then
            physBullet.Damage = fallbackDamage
        end
    end

    if incomingVelLen > 128 and not physBullet.Speed then
        physBullet.Speed = incomingVelLen / 52.5
    end

    local speed = tonumber(physBullet.Speed) or 0
    if speed < 16 then
        physBullet.Speed = 320
    end

    local finalSpeed = tonumber(physBullet.Speed) or 320
    physBullet._ZCityWindSandboxBullet = true
    physBullet._ZCityWindSandboxSpeed = finalSpeed

    local penetration = tonumber(physBullet.Penetration)
    if not penetration then
        local weapon = IsValid(ent) and ent.IsWeapon and ent:IsWeapon() and ent or (IsValid(attacker) and attacker.GetActiveWeapon and attacker:GetActiveWeapon())
        if IsValid(weapon) then
            penetration = tonumber(weapon.Penetration) or (weapon.Primary and tonumber(weapon.Primary.Penetration))
        end
    end
    physBullet.Penetration = penetration or 10

    physBullet.penetrated = physBullet.penetrated or 0
    physBullet.MaxPenLen = physBullet.MaxPenLen or 100
    physBullet.Diameter = physBullet.Diameter or 1

    if physBullet.DieOnHit == nil then
        physBullet.DieOnHit = false
    end

    if physBullet.Dir then
        physBullet.Vel = physBullet.Dir * (finalSpeed * 52.5)
        physBullet.StartLen = physBullet.Vel:Length()
    else
        physBullet.Vel = nil
        physBullet.StartLen = nil
    end

    if not IsValid(physBullet.IgnoreEntity) then
        physBullet.IgnoreEntity = IsValid(attacker) and attacker or ent
    end

    if not physBullet.TraceFilter and not physBullet.Filter then
        local filter = {}
        if IsValid(physBullet.IgnoreEntity) then filter[#filter + 1] = physBullet.IgnoreEntity end
        if IsValid(ent) and ent ~= physBullet.IgnoreEntity then filter[#filter + 1] = ent end

        if #filter == 1 then
            physBullet.TraceFilter = filter[1]
        elseif #filter > 1 then
            physBullet.TraceFilter = filter
        end
    else
        physBullet.TraceFilter = physBullet.TraceFilter or physBullet.Filter
    end

    return ZW.NormalizePhysBulletInput(physBullet)
end

hook.Add("EntityFireBullets", "ZCity_Wind_SandboxPhysBulletReplace", function(ent, bullet)
    if not ShouldReplaceSandboxBullet(bullet) then return end

    if SERVER then
        local count = math.Clamp(math.floor(tonumber(bullet.Num) or 1), 1, 64)
        for _ = 1, count do
            local physBullet = PrepareSandboxPhysBullet(ent, bullet)

            if config.Debug then
                local velLen = isvector(physBullet.Vel) and math.Round(physBullet.Vel:Length(), 2) or "nil"
                MsgC(ZW.Colors.Green, "[Z-City Wind] Sandbox phys bullet input: Dir=" .. tostring(physBullet.Dir) .. " Speed=" .. tostring(physBullet.Speed) .. " Damage=" .. tostring(physBullet.Damage) .. " Vel=" .. tostring(physBullet.Vel) .. " VelLen=" .. tostring(velLen) .. " AmmoType=" .. tostring(physBullet.AmmoType) .. "\n")
            end

            hg.PhysBullet.CreateBullet(physBullet)
        end

        if config.Debug then
            MsgC(ZW.Colors.Green, "[Z-City Wind] Replaced Sandbox FireBullets with " .. count .. " physical bullet(s).\n")
        end
    end

    return false
end)
