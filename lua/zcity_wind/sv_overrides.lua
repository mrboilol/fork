local ZW = ZCityWind
local config = ZW.Config
local function MarkForcedZCityPhysBullet(bullet)
    if not istable(bullet) or bullet._ZCityWindSandboxBullet then return bullet end
    if not ZW.IsZCityGamemode() then return bullet end

    local inflictor = bullet.Inflictor
    if IsValid(inflictor) and (inflictor.ZCityWindForcedPhysBullets or (ZW.IsWindForcedZCityPhysBulletWeapon and ZW.IsWindForcedZCityPhysBulletWeapon(inflictor))) then
        bullet._ZCityWindForcedPhysBullet = true
    end

    return bullet
end

local function ApplyForcedZCityPenetrationCompat(plugin)
    local bulletClass = plugin and plugin.Class_Bullet
    if not bulletClass or not bulletClass.Hit then return false end
    if bulletClass._ZCityWindForcedPenetrationCompat then return true end

    local oldHit = bulletClass.Hit
    function bulletClass:Hit(trace, len, lenBefore, ...)
        if ZW.IsZCityGamemode() or ZW.IsSandboxGamemode() or self._ZCityWindForcedPhysBullet or self._ZCityWindSandboxBullet then
            return ZW.PerformCustomBulletHit(self, plugin, trace, len, lenBefore)
        end

        return oldHit(self, trace, len, lenBefore, ...)
    end

    bulletClass._ZCityWindForcedPenetrationCompat = true
    MsgC(ZW.Colors.Magenta, "[Z-City Wind] Server forced penetration override applied successfully!\n")
    return true
end

local function ApplyServerOverride()
    local success = true
    local plugin = hg and hg.PhysBullet

    if plugin then
        if not ApplyForcedZCityPenetrationCompat(plugin) then
            success = false
        end

        if plugin.CreateBullet then
            if plugin._ZCityWindCreateBulletCompatVersion ~= 3 then
                local oldCreateBullet = plugin.CreateBullet
                function plugin.CreateBullet(bullet)
                    MarkForcedZCityPhysBullet(bullet)
                    ZW.NormalizePhysBulletInput(bullet)
                    ZW.RepairSandboxPhysBulletVelocity(bullet)
                    ZW.ApplyScopeZeroingToBullet(bullet)
                    return oldCreateBullet(bullet)
                end

                plugin._ZCityWindCreateBulletCompat = true
                plugin._ZCityWindCreateBulletCompatVersion = 3
                MsgC(ZW.Colors.Magenta, "[Z-City Wind] Physical bullet input compatibility applied successfully!\n")
            end
        else
            success = false
        end

        if not plugin._ZCityHighPrecVelOverridden then
            plugin.net_writevelocity = function(vel)
                net.WriteFloat(vel.x)
                net.WriteFloat(vel.y)
                net.WriteFloat(vel.z)
            end

            for _, tbl in pairs(plugin) do
                if type(tbl) == "table" then
                    for _, row in pairs(tbl) do
                        if type(row) == "table" and row[1] == "Vel" then
                            row[2] = plugin.net_writevelocity
                        end
                    end
                end
            end

            plugin._ZCityHighPrecVelOverridden = true
            MsgC(ZW.Colors.Magenta, "[Z-City Wind] High-precision velocity server networking override applied successfully!\n")
        end
    else
        success = false
    end

    if hg and hg.PhysBullet and hg.PhysBullet.Class_Bullet then
        if not hg.PhysBullet.Class_Bullet._ZCityServerOverridden then
            local oldRemove = hg.PhysBullet.Class_Bullet.Remove
            function hg.PhysBullet.Class_Bullet:Remove()
                if config.Debug then
                    MsgC(ZW.Colors.Magenta, "[Z-City Wind] Server bullet removed! Key=" .. tostring(self.Key) .. " Pos=" .. tostring(self.Pos) .. " CreationTime=" .. tostring(self.CreationTime) .. "\n")
                end

                ZW.SendServerSuppressionForBullet(self, self._ZCityWindServerSuppressionLastPos, self.Pos)

                if config.Debug and self.CreationTime ~= CurTime() then
                    net.Start("ZCity_WindDebug_Hit")
                        net.WriteVector(self.Pos)
                        net.WriteFloat(self.CreationTime)
                    net.Broadcast()
                end

                oldRemove(self)
            end

            hg.PhysBullet.Class_Bullet._ZCityServerOverridden = true
            MsgC(ZW.Colors.Magenta, "[Z-City Wind] Bullet class SERVER override applied successfully!\n")
        end
    else
        success = false
    end

    return success
end

timer.Create("ZCity_WindDebug_RetryServer", 0.5, 0, function()
    if ApplyServerOverride() then
        timer.Remove("ZCity_WindDebug_RetryServer")
    end
end)

timer.Create("ZCity_Wind_ServerSuppressionBridge_RetryServer", 0.5, 0, function()
    if ZW.RegisterServerSuppressionBridge() then
        timer.Remove("ZCity_Wind_ServerSuppressionBridge_RetryServer")
    end
end)

hook.Add("InitPostEntity", "ZCity_WindDebug_OverrideServer", function()
    ApplyServerOverride()
end)

hook.Add("HomigradRun", "ZCity_WindDebug_OverrideServerHomi", function()
    ApplyServerOverride()
end)

hook.Add("InitPostEntity", "ZCity_Wind_ServerSuppressionBridge_PostEntity", function()
    ZW.RegisterServerSuppressionBridge()
end)

hook.Add("HomigradRun", "ZCity_Wind_ServerSuppressionBridge_Homi", function()
    ZW.RegisterServerSuppressionBridge()
end)

ApplyServerOverride()
ZW.RegisterServerSuppressionBridge()

-- Expose physical bullet penetration values to Homigrad's armor system (sv_equipment.lua)
local eventNameThink = "HG.Plugin.List[PhysBullet].Hooks[BulletThink]"
local eventNamePostThink = "HG.Plugin.List[PhysBullet].Hooks[BulletPostThink]"

hook.Add(eventNameThink, "ZCity_Wind_Armor_CurrentBullet", function(bullet)
    if hg and hg.PhysBullet then
        hg.PhysBullet.CurrentBullet = bullet
    end
end)

hook.Add(eventNamePostThink, "ZCity_Wind_Armor_CurrentBullet_Cleanup", function(bullet)
    if hg and hg.PhysBullet and hg.PhysBullet.CurrentBullet == bullet then
        hg.PhysBullet.CurrentBullet = nil
    end
end)

hook.Add("EntityTakeDamage", "ZCity_Wind_Armor_PhysBulletPenetration", function(target, dmgInfo)
    local bullet = hg and hg.PhysBullet and hg.PhysBullet.CurrentBullet
    if bullet and (dmgInfo:IsDamageType(DMG_BULLET) or dmgInfo:IsDamageType(DMG_BUCKSHOT)) then
        local inflictor = dmgInfo:GetInflictor()
        if IsValid(inflictor) then
            inflictor.bullet = bullet
        end
        local attacker = dmgInfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() then
            attacker.bullet = bullet
            local wep = attacker:GetActiveWeapon()
            if IsValid(wep) then
                wep.bullet = bullet
            end
        end
    end
end)

hook.Add("PostEntityTakeDamage", "ZCity_Wind_Armor_PhysBulletPenetration_Cleanup", function(target, dmgInfo)
    local inflictor = dmgInfo:GetInflictor()
    if IsValid(inflictor) then
        inflictor.bullet = nil
    end
    local attacker = dmgInfo:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() then
        attacker.bullet = nil
        local wep = attacker:GetActiveWeapon()
        if IsValid(wep) then
            wep.bullet = nil
        end
    end
end)
