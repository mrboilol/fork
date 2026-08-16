local ZW = ZCityWind
local config = ZW.Config

local debugDrawConVar = CreateClientConVar("cl_zcity_wind_debug_draw", "0", true, false, "Draw last bullet path and actual server impact point.")

local lastBulletPath = nil
local activeDebugPaths = {}
local serverHitsCache = {}
local serverHitsCacheCount = 0

local colorPath = Color(255, 255, 0, 180)
local colorClient = Color(0, 255, 0, 200)
local colorClientText = Color(0, 255, 0)
local colorServer = Color(255, 0, 0, 255)
local colorServerText = Color(255, 50, 50)
local colorDeviation = Color(0, 191, 255, 255)
local colorTextShadow = Color(0, 0, 0, 255)
local textOffset = Vector(0, 0, 15)
local SUPPRESSION_SOUND_VOLUME = 4
local SUPPRESSION_SOUND_LEVEL = 200
local SUPERSONIC_AUDIBLE_RADIUS = 1400
local SUBSONIC_AUDIBLE_RADIUS = 900
local DISTANT_CRACK_VOLUME = 3.5
local DISTANT_CRACK_SOUND_LEVEL = 190

-- The remote Z-City crack pack is mounted on the server.  Keep the modern
-- snap sounds as a fallback for installations that do not have that pack.
local function ResolveCrackSound(crack, fallback)
    if file.Exists("sound/" .. crack, "GAME") then return crack end
    return fallback
end

-- Suppression is determined on the server, while the physical-bullet client
-- hook is not guaranteed to run for every remote bullet.  Play the fly-by
-- sound from the same authoritative event that applies the suppression.
local function PlaySuppressionCrack(pos, subsonic, damage)
    local crack = subsonic and "bul_flyby/subsonic_" .. math.random(1, 27) .. ".wav"
        or damage >= 50 and "cracks/heavy/heav_crack_0" .. math.random(1, 9) .. ".ogg"
        or damage >= 30 and "cracks/medium/med_crack_0" .. math.random(1, 9) .. ".ogg"
        or "cracks/light/light_crack_0" .. math.random(1, 9) .. ".ogg"
    crack = ResolveCrackSound(crack, "bul_snap/supersonic_snap_" .. math.random(1, 18) .. ".wav")
    EmitSound(crack, pos, 0, CHAN_ITEM, SUPPRESSION_SOUND_VOLUME, SUPPRESSION_SOUND_LEVEL)
end

net.Receive("ZCity_Wind_SuppressionForce", function()
    local pos = net.ReadVector()
    local force = net.ReadFloat()
	local wasHit = net.ReadBool()
    local soundOnly = net.ReadBool()
    local subsonic = net.ReadBool()
    local damage = net.ReadFloat()
    local playSound = net.ReadBool()

    local lply = LocalPlayer()
    if not IsValid(lply) or not lply:IsPlayer() or not lply:Alive() then return end

    if not soundOnly then
        if type(Suppress) == "function" then
            Suppress(force)
        else
            SIB_suppress = SIB_suppress or {}
            SIB_suppress.Force = math.Clamp((SIB_suppress.Force or 0) + force, 0, 10)
        end
    end

    -- Hits have their own impact feedback; this event represents a clear
    -- near-miss, so it must also provide the audible crack.
    if not wasHit and playSound then
        PlaySuppressionCrack(pos, subsonic, damage)
    end

	if not soundOnly and (not hg_suppression_viewpunch or hg_suppression_viewpunch:GetBool()) then
		-- Force is calculated from the bullet's closest approach on the server.
		-- Keep grazing shots noticeable, but make a round passing right by the
		-- player's head violently kick the view.
		local proximity = math.Clamp((force - 0.8) / 13.2, 0, 1)
		local punchScale = Lerp(proximity * proximity, 1, 10)
		local hitScale = wasHit and 1.75 or 1
		local punch = Angle(math.Rand(-5.5, 3.5), math.Rand(-4.5, 4.5), math.Rand(-1.5, 1.5)) * punchScale * hitScale

		if type(QuickViewPunch) == "function" then
			QuickViewPunch(punch)
		elseif type(ViewPunch) == "function" then
			ViewPunch(punch)
		elseif lply.ViewPunch then
			lply:ViewPunch(punch)
		end
	end

    if config.Debug then
        MsgC(ZW.Colors.Gold, string.format("[Z-City Wind] Server suppression force %.2f at %s\n", force, tostring(pos)))
    end
end)

local function TranslateServerToClient(serverPos, clientPos)
    local function align(s, c)
        local diff = s - c
        local sectors = math.floor((diff / 16384) + 0.5)
        return s - sectors * 16384
    end

    return Vector(align(serverPos.x, clientPos.x), align(serverPos.y, clientPos.y), align(serverPos.z, clientPos.z))
end

local function CacheServerHit(creationTime, pos)
    if serverHitsCache[creationTime] == nil then
        serverHitsCacheCount = serverHitsCacheCount + 1
    end

    serverHitsCache[creationTime] = pos
end

local function PopServerHit(creationTime)
    local pos = serverHitsCache[creationTime]
    if pos ~= nil then
        serverHitsCache[creationTime] = nil
        serverHitsCacheCount = math.max(serverHitsCacheCount - 1, 0)
    end

    return pos
end

net.Receive("ZCity_WindDebug_Hit", function()
    local serverPos = net.ReadVector()
    local creationTime = net.ReadFloat()

    if config.Debug then
        MsgC(ZW.Colors.Orange, "[Z-City Wind] Client received server hit: CreationTime=" .. creationTime .. " Pos=" .. tostring(serverPos) .. "\n")
    end

    if not debugDrawConVar:GetBool() then return end

    local debugPath = activeDebugPaths[creationTime]
    if debugPath then
        debugPath.serverHitPos = serverPos
    else
        CacheServerHit(creationTime, serverPos)
    end
end)

local function Draw3DText(pos, text, col)
    local ang = EyeAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos + textOffset, ang, 0.25)
        draw.SimpleTextOutlined(text, "DermaDefault", 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colorTextShadow)
    cam.End3D2D()
end

hook.Add("PostDrawTranslucentRenderables", "ZCity_WindDebug_DrawLastBullet", function(_, bSkybox)
    if bSkybox then return end
    if not debugDrawConVar:GetBool() then return end
    if not lastBulletPath then return end

    local points = lastBulletPath.points
    render.SetColorMaterial()

    if points and #points > 1 then
        for i = 1, #points - 1 do
            render.DrawBeam(points[i], points[i + 1], 2, 0, 1, colorPath)
        end
    end

    if lastBulletPath.clientHitPos then
        render.DrawWireframeSphere(lastBulletPath.clientHitPos, 6, 8, 8, colorClient, false)
        Draw3DText(lastBulletPath.clientHitPos, "Client Tracer End", colorClientText)
    end

    if lastBulletPath.serverHitPos and lastBulletPath.clientHitPos then
        local alignedServerPos = TranslateServerToClient(lastBulletPath.serverHitPos, lastBulletPath.clientHitPos)

        render.DrawWireframeSphere(alignedServerPos, 8, 10, 10, colorServer, false)
        Draw3DText(alignedServerPos, "Server Actual Hit", colorServerText)

        render.DrawBeam(lastBulletPath.clientHitPos, alignedServerPos, 1.5, 0, 1, colorDeviation)

        local distSource = lastBulletPath.clientHitPos:Distance(alignedServerPos)
        local distMeters = distSource * 0.01905
        local midPoint = (lastBulletPath.clientHitPos + alignedServerPos) * 0.5

        Draw3DText(midPoint + Vector(0, 0, -8), string.format("Deviation: %.2fm (%.1fu)", distMeters, distSource), colorDeviation)
    end
end)

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
    MsgC(ZW.Colors.Green, "[Z-City Wind] Client forced penetration override applied successfully!\n")
    return true
end

local function ApplyClientOverride()
    local success = true

    local plugin = hg and hg.PhysBullet
    if plugin then
        if not ApplyForcedZCityPenetrationCompat(plugin) then
            success = false
        end
    else
        success = false
    end

    if hg and hg.PhysBullet and hg.PhysBullet.CreateBullet then
        if not hg.PhysBullet._ZCityAirResistFixed then
            local oldCreateBullet = hg.PhysBullet.CreateBullet
            function hg.PhysBullet.CreateBullet(bullet)
                ZW.NormalizePhysBulletInput(bullet)

                if bullet.AirResistMul then
                    bullet.AirResistMul = bullet.AirResistMul * 5
                end

                if bullet.Pos and IsValid(bullet.Owner) then
                    local refPos = bullet.Owner:GetShootPos()
                    bullet.Pos = TranslateServerToClient(bullet.Pos, refPos)
                end

                return oldCreateBullet(bullet)
            end

            hg.PhysBullet._ZCityAirResistFixed = true
            MsgC(ZW.Colors.Green, "[Z-City Wind] Core AirResistMul client fix and Coordinate Unwrap applied successfully!\n")
        end
    else
        success = false
    end

    if hg and hg.PhysBullet and hg.PhysBullet.Class_Bullet then
        if not hg.PhysBullet.Class_Bullet._ZCityClientOverridden then
            local oldRemove = hg.PhysBullet.Class_Bullet.Remove
            function hg.PhysBullet.Class_Bullet:Remove()
                if config.Debug then
                    MsgC(ZW.Colors.Green, "[Z-City Wind] Client bullet removed! Key=" .. tostring(self.Key) .. " Points=" .. (self.PathPoints and #self.PathPoints or 0) .. " CreationTime=" .. tostring(self.CreationTime) .. "\n")
                end

                if debugDrawConVar:GetBool() and self.PathPoints and #self.PathPoints > 0 then
                    local serverPos = PopServerHit(self.CreationTime)

                    lastBulletPath = {
                        points = table.Copy(self.PathPoints),
                        clientHitPos = self.Pos,
                        serverHitPos = serverPos,
                        time = CurTime()
                    }

                    activeDebugPaths[self.CreationTime] = lastBulletPath
                end

                -- Play distant crack if traveled far and was supersonic
                local speed = self.Vel and (self.Vel:Length() / 52.5) or 0
                local subsonic = speed < 340
                if self.DistanceTraveled and self.DistanceTraveled > 5000 and not subsonic then
                    local lply = LocalPlayer()
                    if IsValid(lply) and lply:Alive() then
                        local startPos = self.StartPos or self.Pos
                        local hitPos = self.Pos
                        local view = render.GetViewSetup(true)
                        local midPos = startPos + (hitPos - startPos) * 0.5
                        local time = view.origin:Distance(midPos) / 17836
                        local soundPos = startPos + (hitPos - startPos) * 0.35
                        timer.Simple(time, function()
							local crack = "cracks/distant/dist_crack_" .. string.format("%02d", math.random(1, 17)) .. ".ogg"
							EmitSound(ResolveCrackSound(crack, "bul_snap/supersonic_snap_" .. math.random(1, 18) .. ".wav"), soundPos, 0, CHAN_AUTO, DISTANT_CRACK_VOLUME, DISTANT_CRACK_SOUND_LEVEL)
                        end)
                    end
                end

                oldRemove(self)
            end

            hg.PhysBullet.Class_Bullet._ZCityClientOverridden = true
            MsgC(ZW.Colors.Green, "[Z-City Wind] Bullet class CLIENT override applied successfully!\n")
        end
    else
        success = false
    end

    local plugin = hg and hg.PhysBullet
    if plugin then
        if not plugin._ZCityHighPrecVelOverridden then
            plugin.net_readvelocity = function()
                return Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())
            end

            for _, tbl in pairs(plugin) do
                if type(tbl) == "table" then
                    for _, row in pairs(tbl) do
                        if type(row) == "table" and row[1] == "Vel" then
                            row[3] = plugin.net_readvelocity
                        end
                    end
                end
            end

            plugin._ZCityHighPrecVelOverridden = true
            MsgC(ZW.Colors.Green, "[Z-City Wind] High-precision velocity client networking override applied successfully!\n")
        end

        -- Add Z-City client bullet cracks and whiz sound effects for physical bullets
        if not plugin._ZCityBulletCracksRegistered then
            local pluginID = plugin.ID or "PhysBullet"
            local preEventName = "HG.Plugin.List[" .. pluginID .. "].Hooks[BulletPreThink]"
            local postEventName = "HG.Plugin.List[" .. pluginID .. "].Hooks[BulletPostThink]"

            hook.Add(preEventName, "ZCity_Wind_BulletPreThink_Client", function(bullet)
                if not bullet.StartPos then
                    bullet.StartPos = bullet.Pos and Vector(bullet.Pos)
                end
                bullet._lastPos = bullet.Pos and Vector(bullet.Pos)
            end)

            hook.Add(postEventName, "ZCity_Wind_BulletPostThink_Client", function(bullet)
                if not bullet._lastPos or not bullet.Pos then return end
				if bullet._ZCityCrackPlayed then return end
				if config.Suppression and GetGlobalBool("ZCity_Wind_ServerSuppressionAudio", false) then return end

                local lply = LocalPlayer()
                if not IsValid(lply) or not lply:Alive() then return end
                if lply.organism and lply.organism.otrub then return end

                -- If bullet shooter is local player, ignore
                if bullet.Shooter == lply or bullet.Shooter == lply:GetViewEntity() then return end

                local eyePos = lply:EyePos()
                local dist, closestPos = util.DistanceToLine(bullet._lastPos, bullet.Pos, eyePos)
                if not dist then return end

                -- Make sure closest point lies on the actual segment
                local segmentVec = bullet.Pos - bullet._lastPos
                local segmentLen = segmentVec:Length()
                if segmentLen <= 0.01 then return end

                local proj = (closestPos - bullet._lastPos):Dot(segmentVec) / (segmentLen * segmentLen)
                if proj < 0 or proj > 1 then return end

                -- Trace line check for visibility (can the player hear the bullet crack/whiz)
                local isVisible = not util.TraceLine({
                    start = closestPos,
                    endpos = eyePos,
                    filter = {lply, lply:GetViewEntity(), bullet.Shooter},
                    mask = MASK_SHOT
                }).Hit

                if not isVisible then return end

                local velocity = bullet.Vel
                local speed = velocity and (velocity:Length() / 52.5) or 343
                local subsonic = speed < 340
                local audibleRadius = subsonic and SUBSONIC_AUDIBLE_RADIUS or SUPERSONIC_AUDIBLE_RADIUS
                if dist >= audibleRadius then return end
                local playPos = velocity and closestPos - velocity:GetNormalized() * 25 or closestPos
				bullet._ZCityCrackPlayed = true

				local damage = tonumber(bullet.Damage) or 0
				local crack = subsonic and "bul_flyby/subsonic_" .. math.random(1, 27) .. ".wav"
					or damage >= 50 and "cracks/heavy/heav_crack_0" .. math.random(1, 9) .. ".ogg"
					or damage >= 30 and "cracks/medium/med_crack_0" .. math.random(1, 9) .. ".ogg"
					or "cracks/light/light_crack_0" .. math.random(1, 9) .. ".ogg"
				crack = ResolveCrackSound(crack, "bul_snap/supersonic_snap_" .. math.random(1, 18) .. ".wav")

				-- Keep the remote Z-City damage-tiered crack selection, with a
				-- louder near-miss mix so it is not buried by weapon reports.
				if HG_BulletImpactSounds and HG_BulletImpactSounds.PlayNearMiss(playPos, subsonic, SUPPRESSION_SOUND_LEVEL, SUPPRESSION_SOUND_VOLUME, crack) then return end
				EmitSound(crack, playPos, 0, CHAN_ITEM, SUPPRESSION_SOUND_VOLUME, SUPPRESSION_SOUND_LEVEL)
            end)

            plugin._ZCityBulletCracksRegistered = true
            MsgC(ZW.Colors.Green, "[Z-City Wind] Client-side physical bullet cracks and whiz sounds registered!\n")
        end
    else
        success = false
    end

    return success
end

timer.Create("ZCity_WindDebug_RetryClient", 0.5, 0, function()
    if ApplyClientOverride() then
        timer.Remove("ZCity_WindDebug_RetryClient")
    end
end)

hook.Add("InitPostEntity", "ZCity_WindDebug_OverrideClient", function()
    ApplyClientOverride()
end)

hook.Add("HomigradRun", "ZCity_WindDebug_OverrideClientHomi", function()
    ApplyClientOverride()
end)

ApplyClientOverride()

timer.Create("ZCity_WindDebug_Cleanup", 15, 0, function()
    if not lastBulletPath and serverHitsCacheCount <= 0 and next(activeDebugPaths) == nil then return end

    local now = CurTime()

    for key, path in pairs(activeDebugPaths) do
        if now - path.time > 30 then
            activeDebugPaths[key] = nil
        end
    end

    if serverHitsCacheCount > 100 then
        for key in pairs(serverHitsCache) do
            serverHitsCache[key] = nil
            serverHitsCacheCount = serverHitsCacheCount - 1

            if serverHitsCacheCount <= 50 then
                break
            end
        end
    end
end)
