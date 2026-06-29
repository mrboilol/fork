if CLIENT then return end

local cvDeathScreen = CreateConVar("zcity_delta_deathscreen_enable", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable death screen", 0, 1)

util.AddNetworkString("zcity_delta_death_respawn")
util.AddNetworkString("zcity_delta_death_report")

local lifeStats = {}
local respawnRequested = {}
local respawnRequestCooldown = {}

local function RespawnTimerName(ply)
    local id = IsValid(ply) and ply.SteamID64 and ply:SteamID64() or nil
    if not id or id == "" or id == "0" then
        id = IsValid(ply) and ply:EntIndex() or tostring(ply)
    end
    return "zcity_delta_death_respawn_" .. id
end

local function ClearRespawnRequest(ply)
    respawnRequested[ply] = nil
    respawnRequestCooldown[ply] = nil
    if IsValid(ply) then
        timer.Remove(RespawnTimerName(ply))
    end
end

local function TryRespawnPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return true end
    if ply:Alive() then
        ClearRespawnRequest(ply)
        return true
    end
    if not cvDeathScreen:GetBool() then
        ClearRespawnRequest(ply)
        return true
    end

    ply.NextSpawnTime = CurTime()
    ply:Spawn()

    if ply:Alive() then
        ClearRespawnRequest(ply)
        return true
    end

    return false
end

local function ResetLifeStats(ply)
    lifeStats[ply] = {
        spawnTime = CurTime(),
        kills = 0,
        damageDealt = 0,
        damageTaken = 0,
        objectsUsed = 0,
        distance = 0,
        lastPos = ply:GetPos(),
        lastAttacker = "Unknown cause",
        wounds = {},
    }
end

hook.Add("PlayerSpawn", "zcity_delta_death_respawn_init", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ClearRespawnRequest(ply)
    timer.Simple(0.5, function()
        if IsValid(ply) then ResetLifeStats(ply) end
    end)
end)

hook.Add("PlayerDisconnected", "zcity_delta_death_respawn_cleanup", function(ply)
    lifeStats[ply] = nil
    ClearRespawnRequest(ply)
end)

hook.Add("HomigradDamage", "zcity_delta_death_respawn_track", function(ply, dmgInfo, hitgroup, ent, rawDamage)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local stats = lifeStats[ply]
    if not stats then return end

    local dmg = rawDamage or (dmgInfo and dmgInfo.GetDamage and dmgInfo:GetDamage()) or 0
    if dmg > 0 then
        stats.damageTaken = stats.damageTaken + dmg
    end

    local att = dmgInfo and dmgInfo.GetAttacker and dmgInfo:GetAttacker()
    if IsValid(att) then
        if att:IsPlayer() then
            stats.lastAttacker = att:Nick()
        else
            stats.lastAttacker = att:GetClass() or "Unknown"
        end
    end
end)

hook.Add("PlayerDeath", "zcity_delta_death_respawn_report", function(ply, inflictor, attacker)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not cvDeathScreen:GetBool() then return end

    local stats = lifeStats[ply] or {}
    local lifeSeconds = stats.spawnTime and (CurTime() - stats.spawnTime) or 0

    local report = {
        name = ply:Nick() or "UNKNOWN",
        lifeSeconds = lifeSeconds,
        kills = stats.kills or 0,
        damageDealt = stats.damageDealt or 0,
        damageTaken = stats.damageTaken or 0,
        usedObjects = stats.objectsUsed or 0,
        distance = math.floor(stats.distance or 0),
        lastAttacker = stats.lastAttacker or "Unknown cause",
        appearance = nil,
        wounds = {},
    }

    -- Capture appearance
    report.appearance = {
        model = ply:GetModel(),
        skin = ply:GetSkin(),
        bodygroups = {},
        color = { r = 255, g = 255, b = 255, a = 255 },
        playerColor = { x = 1, y = 1, z = 1 },
        modelScale = 1,
    }

    if ply.GetBodygroups then
        for _, bg in pairs(ply:GetBodygroups()) do
            if bg and bg.id then
                report.appearance.bodygroups[bg.id] = ply:GetBodygroup(bg.id) or 0
            end
        end
    end

    local col = ply:GetPlayerColor()
    if col then
        report.appearance.playerColor = { x = col.x or 1, y = col.y or 1, z = col.z or 1 }
    end

    -- Capture wounds
    local org = ply.organism
    if org then
        if istable(org.wounds) then
            for _, wound in pairs(org.wounds) do
                if istable(wound) then
                    table.insert(report.wounds, {
                        bone = wound[2] or wound.bone or "",
                        dmg = wound[1] or wound.dmg or 0,
                        localPos = wound.localPos or nil,
                        localAng = wound.localAng or nil,
                    })
                end
            end
        end
        if istable(org.arterialwounds) then
            for _, wound in pairs(org.arterialwounds) do
                if istable(wound) then
                    table.insert(report.wounds, {
                        bone = wound[6] or wound.bone or "",
                        dmg = (wound[1] or 0) * 2,
                        localPos = wound.localPos or nil,
                        localAng = wound.localAng or nil,
                    })
                end
            end
        end
    end

    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        net.Start("zcity_delta_death_report")
        net.WriteTable(report)
        net.Send(ply)
    end)
end)

-- Track kills
hook.Add("PlayerDeath", "zcity_delta_death_respawn_kills", function(victim, inflictor, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    local stats = lifeStats[attacker]
    if stats then stats.kills = (stats.kills or 0) + 1 end
end)

-- Track distance
hook.Add("Move", "zcity_delta_death_respawn_distance", function(ply, mv)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    local stats = lifeStats[ply]
    if not stats then return end
    local pos = ply:GetPos()
    if stats.lastPos then
        stats.distance = (stats.distance or 0) + pos:Distance(stats.lastPos) / 52.49
    end
    stats.lastPos = pos
end)

-- Override PlayerDeathThink to block default respawn when death screen is enabled
hook.Add("Think", "zcity_delta_death_respawn_block", function()
    if not cvDeathScreen:GetBool() then return end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and not ply:Alive() and not respawnRequested[ply] then
            ply.NextSpawnTime = math.huge
        end
    end
end)

-- Handle respawn request from client
net.Receive("zcity_delta_death_respawn", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not cvDeathScreen:GetBool() then return end
    if ply:Alive() then return end

    local now = CurTime()
    if (respawnRequestCooldown[ply] or 0) > now then return end
    respawnRequestCooldown[ply] = now + 0.75

    respawnRequested[ply] = true
    ply.NextSpawnTime = CurTime()

    if TryRespawnPlayer(ply) then return end

    timer.Create(RespawnTimerName(ply), 0.1, 10, function()
        if TryRespawnPlayer(ply) then return end
    end)
end)

-- Concommands for toggling
concommand.Add("zcity_delta_deathscreen_toggle", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local enabled = not cvDeathScreen:GetBool()
    RunConsoleCommand("zcity_delta_deathscreen_enable", enabled and "1" or "0")
    ply:ChatPrint("Death screen " .. (enabled and "enabled" or "disabled"))
end)

concommand.Add("zcity_delta_deathscreen_on", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    RunConsoleCommand("zcity_delta_deathscreen_enable", "1")
    ply:ChatPrint("Death screen enabled")
end)

concommand.Add("zcity_delta_deathscreen_off", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    RunConsoleCommand("zcity_delta_deathscreen_enable", "0")
    ply:ChatPrint("Death screen disabled")
end)

print("[zcity-delta] death screen loaded (server)")
