local ZW = ZCityWind
local config = ZW.Config
local distanceToLine = util.DistanceToLine
local traceLine = util.TraceLine
local maskShot = MASK_SHOT
local SUPPRESSION_RADIUS = 180
local SUPERSONIC_AUDIBLE_RADIUS = 1400
local SUBSONIC_AUDIBLE_RADIUS = 900

local function PlayerIterator()
    if player.Iterator then
        return player.Iterator()
    end

    return ipairs(player.GetAll())
end

local function GetBulletShooterEntity(bullet)
    local shooter = bullet and (bullet.Shooter or bullet.Attacker)
    return IsValid(shooter) and shooter or Entity(0)
end

local function IsSuppressionShooter(ply, shooter)
    if not IsValid(ply) or not IsValid(shooter) then return false end
    if ply == shooter then return true end

    local owner = shooter.GetOwner and shooter:GetOwner() or nil
    if IsValid(owner) and ply == owner then return true end

    return false
end

local GRAZE_MIN_DIST = 14
local GRAZE_MAX_DIST = 36
local GRAZE_FORCE = 14

local function SendSuppressionFlinch(ply, eyePos, closestPos, hard)
    local now = CurTime()
    if not hard and ((ply._ZCityWindFlinchNext or 0) > now or IsValid(ply.FakeRagdoll)) then return end
    ply._ZCityWindFlinchNext = now + 0.6

    local onRight = ply:EyeAngles():Right():Dot(closestPos - eyePos) > 0
    local sequence = ply:LookupSequence(onRight and "flinch_shoulder_r" or "flinch_shoulder_l")
    local activity = sequence and sequence >= 0 and ply:GetSequenceActivity(sequence) or -1
    if activity < 0 then activity = onRight and ACT_FLINCH_RIGHTARM or ACT_FLINCH_LEFTARM end

    net.Start("DoPlayerFlinch")
        net.WriteInt(activity, 32)
        net.WriteEntity(ply)
    net.Broadcast()
end

local function GrazeProbePoints(ply)
    local body = hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply)
    if IsValid(body) and body ~= ply then return {body:WorldSpaceCenter()} end

    local pos = ply:GetPos()
    return {pos + Vector(0, 0, 12), pos + Vector(0, 0, 36), ply:EyePos()}
end

function ZW.ApplyBulletShock(ply, damage, fromPos)
    local org = ply.organism
    if not org or org.otrub then return end

    SendSuppressionFlinch(ply, ply:EyePos(), fromPos, true)

    local strength = math.Clamp((tonumber(damage) or 10) / 30, 0.5, 1.5)
    if ply.AddNaturalAdrenaline then ply:AddNaturalAdrenaline(0.08 * strength) end
    org.fearadd = (org.fearadd or 0) + 0.3 * strength
    if hg.organism and hg.organism.AddPanicAttack then
        hg.organism.AddPanicAttack(org, 0.12 * strength, true, true, true, true)
    end
end

function ZW.GrazePlayer(ply, closestPos, damage)
    if (ply._ZCityWindGrazeNext or 0) > CurTime() then return end
    ply._ZCityWindGrazeNext = CurTime() + 0.4

    local org = ply.organism
    if not org or org.otrub then return end

    ZW.ApplyBulletShock(ply, damage, closestPos)

    net.Start("ZCity_Wind_SuppressionForce")
        net.WriteVector(closestPos)
        net.WriteFloat(GRAZE_FORCE)
        net.WriteBool(false)
        net.WriteBool(false)
        net.WriteBool(false)
        net.WriteFloat(tonumber(damage) or 10)
        net.WriteBool(false)
    net.Send(ply)
end

function ZW.CheckBulletGraze(bullet, startPos, endPos)
    if not bullet or not startPos or not endPos then return end
    if (endPos - startPos):LengthSqr() <= 1 then return end

    local shooter = GetBulletShooterEntity(bullet)
    local grazed = bullet._ZCityWindGrazed
    if not grazed then
        grazed = {}
        bullet._ZCityWindGrazed = grazed
    end

    local now = CurTime()
    for _, ply in PlayerIterator() do
        if not IsValid(ply) or not ply:Alive() or grazed[ply] then continue end
        if IsSuppressionShooter(ply, shooter) or (ply._ZCityWindGrazeHitUntil or 0) > now then continue end

        local nearest, nearestPos = math.huge
        for _, point in ipairs(GrazeProbePoints(ply)) do
            local dist, closest = distanceToLine(startPos, endPos, point)
            if dist and dist < nearest then nearest, nearestPos = dist, closest end
        end

        if nearest < GRAZE_MIN_DIST or nearest > GRAZE_MAX_DIST then continue end

        local filter = {ply, hg.GetCurrentCharacter(ply)}
        if IsValid(shooter) then filter[#filter + 1] = shooter end
        local blocked = traceLine({
            start = nearestPos,
            endpos = ply:WorldSpaceCenter(),
            filter = filter,
            mask = maskShot
        }).Hit
        if blocked then continue end

        grazed[ply] = true
        ZW.GrazePlayer(ply, nearestPos, bullet.Damage)
    end
end

function ZW.SendServerSuppressionForBullet(bullet, startPos, endPos)
    if not config.Suppression then return end
    ZW.CheckBulletGraze(bullet, startPos, endPos)
    if not bullet or not startPos or not endPos then return end

    local move = endPos - startPos
    if move:LengthSqr() <= 1 then return end

    local shooter = GetBulletShooterEntity(bullet)
    local damage = tonumber(bullet.Damage) or 10
    local speed = isvector(bullet.Vel) and bullet.Vel:Length() / 52.5 or tonumber(bullet.Speed) or 343
    local subsonic = speed < 340
    local audibleRadius = subsonic and SUBSONIC_AUDIBLE_RADIUS or SUPERSONIC_AUDIBLE_RADIUS
    local sentPlayers = bullet._ZCityWindSuppressionPlayers
    if not sentPlayers then
        sentPlayers = {}
        bullet._ZCityWindSuppressionPlayers = sentPlayers
    end
    for _, ply in PlayerIterator() do
        if not IsValid(ply) or not ply:Alive() then continue end
        if IsSuppressionShooter(ply, shooter) then continue end

        local playerState = sentPlayers[ply]
        if playerState and playerState.suppression then continue end

        local eyePos = ply:EyePos()
        local dist, closestPos = distanceToLine(startPos, endPos, eyePos)
        if not dist or dist > audibleRadius then continue end

        local filter = {ply}
        if IsValid(shooter) then filter[#filter + 1] = shooter end

        local owner = IsValid(shooter) and shooter.GetOwner and shooter:GetOwner() or nil
        if IsValid(owner) then filter[#filter + 1] = owner end

        if hg and hg.GetCurrentCharacter then
            local character = hg.GetCurrentCharacter(ply)
            if IsValid(character) then filter[#filter + 1] = character end
        end

        local blocked = traceLine({
            start = closestPos,
            endpos = eyePos,
            filter = filter,
            mask = maskShot
        }).Hit

        if blocked then continue end

        -- Cracks carry much farther than the tight radius that causes camera
        -- kick and panic. Keep those two ranges independent so an audible
        -- round at distance does not behave like it shaved the player's head.
        local soundOnly = dist > SUPPRESSION_RADIUS

        -- A bullet can first become audible at long range and then enter the tight
        -- suppression radius a moment later. Keep one distant crack and one close
        -- fly-by event per listener instead of letting the distant event suppress
        -- the much more important near-head crack/whizz.
        local playSound
        if soundOnly then
            playSound = not (playerState and playerState.audioDistant)
        else
            playSound = not (playerState and playerState.audioNear)
        end
        if soundOnly and not playSound then continue end

        local proximity = math.Clamp(1 - dist / SUPPRESSION_RADIUS, 0, 1)
        local force = soundOnly and 0 or math.Clamp(0.8 + proximity * proximity * 11 + math.min(damage / 25, 2.5), 0.8, 14)

        net.Start("ZCity_Wind_SuppressionForce")
            net.WriteVector(closestPos)
            net.WriteFloat(force)
            net.WriteBool(false)
            net.WriteBool(soundOnly)
            net.WriteBool(subsonic)
            net.WriteFloat(damage)
            net.WriteBool(playSound)
        net.Send(ply)
        playerState = playerState or {}
        if soundOnly then
            playerState.audioDistant = true
        else
            playerState.audioNear = true
            playerState.suppression = true
        end
        sentPlayers[ply] = playerState

        -- Apply Z-City adrenaline and fear from nearby flying bullets
        local org = ply.organism
        if org and not org.otrub then
            if not soundOnly then SendSuppressionFlinch(ply, eyePos, closestPos) end

            local shooterdist = (IsValid(owner) and owner or shooter):GetPos():Distance(eyePos)
            local isLooking = true
            if shooterdist < 200 then
                local shootEnt = IsValid(owner) and owner or shooter
                if IsValid(shootEnt) and shootEnt.IsPlayer and shootEnt:IsPlayer() then
                    local diff = eyePos - shootEnt:GetShootPos()
                    local diffLen = diff:Length()
                    if diffLen > 0 then
                        isLooking = shootEnt:GetAimVector():Dot(diff) / diffLen >= 0.8
                    end
                end
            end

            if dist <= 180 and isLooking then
                local suppressionResponse = math.Clamp(0.25 * damage / math.max(dist / 2, 10), 0.08, 0.4)
                if ply.AddNaturalAdrenaline then
                    ply:AddNaturalAdrenaline(suppressionResponse)
                end

                org.fearadd = (org.fearadd or 0) + 0.2

                if hg.organism and hg.organism.AddPanicAttack and CurTime() >= (org._panicSuppressionNext or 0) then
                    org._panicSuppressionNext = CurTime() + 0.15
                    hg.organism.AddPanicAttack(org, 0.1 + suppressionResponse * 0.35, true, true, true, true)
                    if hg.organism.PsycheNearMiss then hg.organism.PsycheNearMiss(ply, org) end
                end
            end
        end
    end
end

-- Native FireBullets weapons do not enter the physical-bullet Think hooks.
-- Feed their actual shot segment through the same closest-pass calculation so
-- suppression audio is not exclusive to the custom projectile implementation.
hook.Add("PostEntityFireBullets", "ZCity_Wind_HitscanNearMissAudio", function(shooter, data)
    if not config.Suppression or not istable(data) then return end
    if not isvector(data.Src) or not isvector(data.Dir) then return end

    local direction = Vector(data.Dir)
    if direction:LengthSqr() <= 0 then return end
    direction:Normalize()

    local distance = math.Clamp(tonumber(data.Distance) or 8192, 128, 32768)
    local synthetic = {
        Shooter = shooter,
        Attacker = IsValid(data.Attacker) and data.Attacker or shooter,
        Damage = tonumber(data.Damage) or 10,
        Speed = tonumber(data.Speed) or 343
    }

    local endPos = data.Src + direction * distance
    local trace = data.Trace
    if istable(trace) and isvector(trace.HitPos) and not trace.HitSky then endPos = trace.HitPos end

    ZW.SendServerSuppressionForBullet(synthetic, data.Src, endPos)
end)

-- A hit is suppression too. Physical bullets may die during their impact tick,
-- so send this from damage dispatch rather than relying on a later path hook.
hook.Add("EntityTakeDamage", "ZCity_Wind_BulletHitSuppression", function(ent, dmgInfo)
	if not config.Suppression or not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then return end

	local ply = ent:IsPlayer() and ent or (hg and hg.RagdollOwner and hg.RagdollOwner(ent) or nil)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	local now = CurTime()
	if (ply._ZCityWindBulletHitSuppressionNext or 0) > now then return end
	ply._ZCityWindBulletHitSuppressionNext = now + 0.03
	ply._ZCityWindGrazeHitUntil = now + 0.25

	local pos = dmgInfo:GetDamagePosition()
	if not pos or pos:IsZero() then pos = ply:EyePos() end
	ZW.ApplyBulletShock(ply, dmgInfo:GetDamage(), pos)
	local force = math.Clamp(6 + dmgInfo:GetDamage() / 12, 6, 10)

	net.Start("ZCity_Wind_SuppressionForce")
		net.WriteVector(pos)
		net.WriteFloat(force)
		net.WriteBool(true)
		net.WriteBool(false)
		net.WriteBool(false)
		net.WriteFloat(dmgInfo:GetDamage())
		net.WriteBool(false)
	net.Send(ply)
end)

local function ThreatVictim(ent)
    if not IsValid(ent) then return end
    if ent:IsPlayer() then return ent end
    local owner = hg and hg.RagdollOwner and hg.RagdollOwner(ent)
    return IsValid(owner) and owner:IsPlayer() and owner or nil
end

hook.Add("EntityTakeDamage", "ZCity_Wind_ThreatHitMark", function(ent, dmgInfo)
    local ply = ThreatVictim(ent)
    if not ply then return end
    ply._ZCityWindThreatHitAt = CurTime()
end)

function ZW.ApplyNearMissThreat(ply, pos, force, panic, since)
    if not config.Suppression or not IsValid(ply) or not ply:Alive() then return end
    local org = ply.organism
    if not org or org.otrub then return end

    local K = hg and hg.PsycheCombat
    if not K then return end
    if since and (ply._ZCityWindThreatHitAt or 0) >= since - K.threatHitWindow then return end

    SendSuppressionFlinch(ply, ply:EyePos(), pos)

    net.Start("ZCity_Wind_SuppressionForce")
        net.WriteVector(pos)
        net.WriteFloat(force)
        net.WriteBool(false)
        net.WriteBool(false)
        net.WriteBool(false)
        net.WriteFloat(0)
        net.WriteBool(false)
    net.Send(ply)

    if ply.AddNaturalAdrenaline then ply:AddNaturalAdrenaline(math.Clamp(force / 60, 0.05, 0.2)) end
    org.fearadd = (org.fearadd or 0) + 0.2
    if hg.organism and hg.organism.AddPanicAttack then
        hg.organism.AddPanicAttack(org, panic, true, true, true, true)
    end
end

local function QueueNearMissThreat(ply, pos, force, panic, delay)
    local queuedAt = CurTime()
    timer.Simple(delay, function()
        ZW.ApplyNearMissThreat(ply, pos, force, panic, queuedAt + delay)
    end)
end

function ZW.MeleeSwingThreat(attacker, wep)
    local K = hg and hg.PsycheCombat
    if not K or not config.Suppression or not IsValid(attacker) or not IsValid(wep) then return end
    local reach = (wep.MeleeRange or (wep.GetAttackLength and wep:GetAttackLength()) or wep.ReachDistance or 60) + K.meleeThreatPad
    local origin = attacker:EyePos()
    local aim = attacker:GetAimVector()
    local now = CurTime()

    for _, ply in PlayerIterator() do
        if ply == attacker or not ply:Alive() or (ply._ZCityWindMeleeThreatNext or 0) > now then continue end
        local eye = ply:EyePos()
        local diff = eye - origin
        local dist = diff:Length()
        if dist > reach or dist < 1 or aim:Dot(diff / dist) < K.meleeThreatDot then continue end

        ply._ZCityWindMeleeThreatNext = now + K.meleeCooldown
        local proximity = 1 - dist / reach
        QueueNearMissThreat(ply, origin + aim * dist, 2 + proximity * K.meleeThreatForce, K.meleePanic, K.meleeThreatDelay)
    end
end

local function IsThrownBy(ent, ply)
    if ent:GetOwner() == ply or ent.owner == ply or ent.Owner == ply then return true end
    return ent.GetPhysicsAttacker and ent:GetPhysicsAttacker(3) == ply
end

local function ScanFlyingThreats(ply, K, now)
    local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply)
    local center = ply:WorldSpaceCenter()
    local seen = ply._ZCityWindThrowSeen or {}
    ply._ZCityWindThrowSeen = seen

    for _, ent in ipairs(ents.FindInSphere(center, K.throwThreatScan)) do
        if ent == ply or ent == body or ent:IsPlayer() or ent:IsWorld() or IsValid(ent:GetParent()) then continue end
        if (seen[ent] or 0) > now or ent:IsVehicle() or ent:IsPlayerHolding() then continue end

        local phys = ent:GetPhysicsObject()
        if not IsValid(phys) or not phys:IsMotionEnabled() then continue end
        local vel = phys:GetVelocity()
        local speedSqr = vel:LengthSqr()
        if speedSqr < K.throwThreatSpeed * K.throwThreatSpeed then continue end
        if ThreatVictim(ent) == ply or IsThrownBy(ent, ply) then continue end

        local entPos = ent:WorldSpaceCenter()
        local t = math.Clamp((center - entPos):Dot(vel) / speedSqr, 0, K.throwThreatLead)
        if t <= 0 then continue end
        local closest = entPos + vel * t
        local dist = closest:Distance(center)
        local radius = K.throwThreatRadius + ent:BoundingRadius() * 0.5
        if dist > radius then continue end

        seen[ent] = now + 1.5
        local proximity = 1 - dist / radius
        local heavy = math.Clamp(phys:GetMass() / 30, 0.5, 2)
        QueueNearMissThreat(ply, closest, 2 + proximity * K.throwThreatForce * heavy, K.throwThreatPanic * heavy, t + 0.1)
    end

    for ent, untilTime in pairs(seen) do
        if untilTime <= now or not IsValid(ent) then seen[ent] = nil end
    end
end

timer.Create("ZCity_Wind_FlyingThreats", 0.1, 0, function()
    if not config.Suppression or not hg or not hg.PsycheCombat then return end
    local K = hg.PsycheCombat
    local now = CurTime()
    for _, ply in PlayerIterator() do
        if IsValid(ply) and ply:Alive() and ply.organism and not ply.organism.otrub then
            ScanFlyingThreats(ply, K, now)
        end
    end
end)

function ZW.RegisterServerSuppressionBridge()
    local plugin = hg and hg.PhysBullet
    if not plugin then return false end
    if plugin._ZCityWindServerSuppressionBridgeRegistered then
        SetGlobalBool("ZCity_Wind_ServerSuppressionAudio", true)
        return true
    end

    local pluginID = plugin.ID or "PhysBullet"
    local preEventName = "HG.Plugin.List[" .. pluginID .. "].Hooks[BulletPreThink]"
    local postEventName = "HG.Plugin.List[" .. pluginID .. "].Hooks[BulletPostThink]"

    hook.Add(preEventName, "ZCity_Wind_ServerSuppressionBridge_Pre", function(bullet)
        if not config.Suppression then return end
        if not bullet or not bullet.Pos then return end
        bullet._ZCityWindServerSuppressionLastPos = Vector(bullet.Pos)
    end)

    hook.Add(postEventName, "ZCity_Wind_ServerSuppressionBridge_Post", function(bullet)
        if not config.Suppression then return end
        if not bullet then return end

        ZW.SendServerSuppressionForBullet(bullet, bullet._ZCityWindServerSuppressionLastPos, bullet.Pos)
    end)

    plugin._ZCityWindServerSuppressionBridgeRegistered = true
    SetGlobalBool("ZCity_Wind_ServerSuppressionAudio", true)
    MsgC(ZW.Colors.Magenta, "[Z-City Wind] Physical bullet server suppression fallback registered successfully!\n")
    return true
end
