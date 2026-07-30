local ZW = ZCityWind
local config = ZW.Config
local distanceToLine = util.DistanceToLine
local traceLine = util.TraceLine
local maskShot = MASK_SHOT

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

function ZW.SendServerSuppressionForBullet(bullet, startPos, endPos)
    if not config.Suppression then return end
    if not bullet or not startPos or not endPos then return end

    local move = endPos - startPos
    if move:LengthSqr() <= 1 then return end

    local shooter = GetBulletShooterEntity(bullet)
    local damage = tonumber(bullet.Damage) or 10
    local sentAny = false

    for _, ply in PlayerIterator() do
        if not IsValid(ply) or not ply:Alive() then continue end
        if IsSuppressionShooter(ply, shooter) then continue end

        local eyePos = ply:EyePos()
        local dist, closestPos = distanceToLine(startPos, endPos, eyePos)
        if not dist or dist > 180 then continue end

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

        local force = math.Clamp((1 - dist / 180) * 7 + math.min(damage / 20, 3), 0.75, 10)

        net.Start("ZCity_Wind_SuppressionForce")
            net.WriteVector(closestPos)
            net.WriteFloat(force)
			net.WriteBool(false)
        net.Send(ply)

        -- Apply Z-City adrenaline and fear from nearby flying bullets
        local org = ply.organism
        if org and not org.otrub then
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

            if dist <= 120 and isLooking then
                local suppressionResponse = math.Clamp(0.25 * damage / math.max(dist / 2, 10), 0.08, 0.4)
                if ply.AddNaturalAdrenaline then
                    ply:AddNaturalAdrenaline(suppressionResponse)
                end

                local disorientation = org.disorientation or 0
                if disorientation < 2.5 then
                    org.disorientation = math.min(disorientation + math.Clamp(suppressionResponse * 0.8, 0.08, 0.35), 2.5)
                end
                org.fearadd = (org.fearadd or 0) + 0.2

                -- Near misses now feed the panic system as well as short-term
                -- fear. Throttle rapid pellets so one shotgun blast cannot fill it.
                if hg.organism and hg.organism.AddPanicAttack and CurTime() >= (org._panicSuppressionNext or 0) then
                    org._panicSuppressionNext = CurTime() + 0.2
                    hg.organism.AddPanicAttack(org, 0.055 + suppressionResponse * 0.16, true)
                end
            end
        end

        sentAny = true
    end

    if sentAny then
        bullet._ZCityWindServerSuppressionSent = true
    end
end

-- A hit is suppression too. Physical bullets may die during their impact tick,
-- so send this from damage dispatch rather than relying on a later path hook.
hook.Add("EntityTakeDamage", "ZCity_Wind_BulletHitSuppression", function(ent, dmgInfo)
	if not config.Suppression or not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then return end

	local ply = ent:IsPlayer() and ent or (hg and hg.RagdollOwner and hg.RagdollOwner(ent) or nil)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	local now = CurTime()
	if (ply._ZCityWindBulletHitSuppressionNext or 0) > now then return end
	ply._ZCityWindBulletHitSuppressionNext = now + 0.03

	local pos = dmgInfo:GetDamagePosition()
	if not pos or pos:IsZero() then pos = ply:EyePos() end
	local force = math.Clamp(6 + dmgInfo:GetDamage() / 12, 6, 10)

	net.Start("ZCity_Wind_SuppressionForce")
		net.WriteVector(pos)
		net.WriteFloat(force)
		net.WriteBool(true)
	net.Send(ply)
end)

function ZW.RegisterServerSuppressionBridge()
    local plugin = hg and hg.PhysBullet
    if not plugin then return false end
    if plugin._ZCityWindServerSuppressionBridgeRegistered then return true end

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
        if not bullet or bullet._ZCityWindServerSuppressionSent then return end

        ZW.SendServerSuppressionForBullet(bullet, bullet._ZCityWindServerSuppressionLastPos, bullet.Pos)
    end)

    plugin._ZCityWindServerSuppressionBridgeRegistered = true
    MsgC(ZW.Colors.Magenta, "[Z-City Wind] Physical bullet server suppression fallback registered successfully!\n")
    return true
end
