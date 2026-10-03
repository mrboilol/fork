-- arghahghahaha randgdol tumbel melecity so tuff
local player_GetAll = player.GetAll
local util_TraceLine = util.TraceLine
local util_TraceHull = util.TraceHull
local IsValid = IsValid
local CurTime = CurTime

local tumbleBoneBreakSounds = {
    "owfuck1.mp3",
    "owfuck2.mp3",
    "owfuck3.mp3",
    "owfuck4.mp3",
    "owfuck5.mp3",
    "owfuck6.mp3",
    "owfuck7.mp3",
    "owfuck8.mp3",
    "owfuck9.mp3",
    "owfuck10.mp3",
    "newbonebreak/break1.wav",
    "newbonebreak/break2.wav",
    "newbonebreak/break3.wav",
    "newbonebreak/break4.wav",
    "newbonebreak/break5.wav",
    "newbonebreak/break6.wav",
    "newbonebreak/break7.wav",
    "newbonebreak/break8.wav",
    "newbonebreak/break9.wav",
    "newbonebreak/break10.wav",
}

local function PlayBoneBreakSound(entity)
    entity:EmitSound(tumbleBoneBreakSounds[math.random(#tumbleBoneBreakSounds)])
end

local TUMBLE_SPEED_THRESHOLD = 250
local TUMBLE_COOLDOWN = 2
local GAP_CHECK_DIST = 30 
local WALL_CHECK_DIST = 20
local WALL_CHECK_HEIGHT = 10

local BASE_TRIP_CHANCE = 0.1
local MAX_TRIP_CHANCE = 0.8
local TRIP_BREAK_CHANCE = 0.15
local COLLISION_TRACE_MINS = Vector(-12, -12, -20)
local COLLISION_TRACE_MAXS = Vector(12, 12, 20)
local COLLISION_FULL_SPEED_MUL = 0.6
local COLLISION_STUMBLE_SLOWDOWN = 450
local COLLISION_STUMBLE_TIME = 0.18
local COLLISION_DAMAGE_MUL = 0.08
local COLLISION_DAMAGE_TIME = 0.9
local COLLISION_SOUNDS = {
    "raminto/ram1.wav",
    "raminto/ram2.wav",
    "raminto/ram3.wav"
}

local function PlayCollisionSound(ply)
    ply:EmitSound(COLLISION_SOUNDS[math.random(#COLLISION_SOUNDS)], 75, math.random(96, 104), 1)
end

local function StumbleFromCollision(ply)
    PlayCollisionSound(ply)
    ply:SetNetVar("slowDown", COLLISION_STUMBLE_SLOWDOWN)
    ply:ViewPunch(Angle(math.random(2) == 1 and -18 or 18, math.random(-2, 2), math.random(-4, 4)))

    timer.Create("hg_tumble_collision_slowdown_" .. ply:EntIndex(), COLLISION_STUMBLE_TIME, 1, function()
        if IsValid(ply) and ply:GetNetVar("slowDown", 0) <= COLLISION_STUMBLE_SLOWDOWN then
            ply:SetNetVar("slowDown", 0)
        end
    end)
end

local function GetRagdollBonePhysics(ragdoll, boneName)
    local bone = ragdoll:LookupBone(boneName)
    if not bone then return end

    local physbone = ragdoll:TranslateBoneToPhysBone(bone)
    if not physbone or physbone < 0 then return end

    local phys = ragdoll:GetPhysicsObjectNum(physbone)
    return IsValid(phys) and phys or nil
end

local function PreserveRagdollMomentum(ragdoll, velocity)
    local totalMass = 0
    local momentum = Vector(0, 0, 0)

    for physbone = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(physbone)
        if not IsValid(phys) or not phys:IsMotionEnabled() then continue end

        local mass = math.max(phys:GetMass(), 0)
        totalMass = totalMass + mass
        momentum = momentum + phys:GetVelocity() * mass
    end

    if totalMass <= 0 then return end
    local correction = velocity - momentum / totalMass

    for physbone = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(physbone)
        if not IsValid(phys) or not phys:IsMotionEnabled() then continue end
        phys:AddVelocity(correction)
        phys:Wake()
    end
end

local function ApplyTripInertia(ply, ragdoll, tripType, velocity, collisionTrace, highWallHit)
    local direction = Vector(velocity.x, velocity.y, 0)
    if direction:LengthSqr() <= 0.001 then
        direction = ply:EyeAngles():Forward()
        direction.z = 0
    end
    if direction:LengthSqr() <= 0.001 then return end
    direction:Normalize()

    local fallsBackward = tripType == "slip" or (tripType == "wall" and highWallHit)
    local fallDirection = direction * (fallsBackward and -1 or 1)
    local strength = math.Clamp(velocity:Length2D() * 0.45, 100, 190)
    local spine = GetRagdollBonePhysics(ragdoll, "ValveBiped.Bip01_Spine2")
    local pelvis = GetRagdollBonePhysics(ragdoll, "ValveBiped.Bip01_Pelvis")
    local leftCalf = GetRagdollBonePhysics(ragdoll, "ValveBiped.Bip01_L_Calf")
    local rightCalf = GetRagdollBonePhysics(ragdoll, "ValveBiped.Bip01_R_Calf")

    if IsValid(spine) then spine:AddVelocity(fallDirection * strength + Vector(0, 0, -strength * 0.45)) end
    if IsValid(pelvis) then pelvis:AddVelocity(fallDirection * strength * 0.35 + Vector(0, 0, -strength * 0.2)) end

    local legVelocity = -fallDirection * strength * 0.7 + Vector(0, 0, strength * 0.08)
    if IsValid(leftCalf) then leftCalf:AddVelocity(legVelocity) end
    if IsValid(rightCalf) then rightCalf:AddVelocity(legVelocity) end

    if collisionTrace then
        ply.hgSprintCollisionDamageMul = COLLISION_DAMAGE_MUL
        ply.hgSprintCollisionDamageUntil = CurTime() + COLLISION_DAMAGE_TIME
    end

    PreserveRagdollMomentum(ragdoll, velocity)
end

local function ScaleTripChance(ply, org, tripChance)
    local disorientation = org.disorientation or 0
    if disorientation > 0.1 then
        tripChance = tripChance + disorientation * 0.05
    end

    local stamina = org.stamina and org.stamina[1] or 100
    local maxStamina = (org.stamina and org.stamina.max) or 100
    if stamina < maxStamina then
        local staminaPenalty = (maxStamina - stamina) / maxStamina
        tripChance = tripChance + staminaPenalty * 0.2
    end

    if org.superfighter then
        tripChance = tripChance * 0.1
    end
    if org.noradrenaline and org.noradrenaline > 0 then
        tripChance = tripChance * 0.1
    end
    if org.berserk and org.berserk > 0 then
        tripChance = tripChance * 0.1
    end

    local traumaChanceMul = hg.organism.GetTraumaRagdollChanceMul and hg.organism.GetTraumaRagdollChanceMul(org) or 1
    tripChance = tripChance * traumaChanceMul
    tripChance = tripChance * (ply.GetTraitMultiplier and ply:GetTraitMultiplier("terrain_trip_chance", 1) or 1)

    return math.Clamp(tripChance, 0, MAX_TRIP_CHANCE)
end

hg.ScaleTripChance = ScaleTripChance

local function ExecuteTrip(ply, org, tripType, velocity, collisionTrace, trHighHit, breakChance)
    hg.Fake(ply, nil, nil, nil, "trip_" .. tripType)
    --mcity reference?
    if not org.superfighter then
        if math.random() < breakChance then
            PlayBoneBreakSound(ply)

            if tripType == "wall" then
                if trHighHit then
                    org.jaw = 1
                else
                    if math.random(1, 2) == 1 then
                        org.rleg = 1
                    else
                        org.lleg = 1
                    end
                end
            elseif tripType == "ragdoll" then
                if math.random(1, 2) == 1 then
                    org.rarm = 1
                else
                    org.larm = 1
                end
            else
                ply:EmitSound("physics/body/body_medium_break"..math.random(2,4)..".wav")
            end
        end
    end

    local ragdoll = ply.FakeRagdoll
    if IsValid(ragdoll) then
        if collisionTrace then
            PlayCollisionSound(ply)
        end
        ApplyTripInertia(ply, ragdoll, tripType, velocity, collisionTrace, trHighHit)

        timer.Simple(0, function()
            if IsValid(ply) then hg.StunPlayer(ply) end
        end)

        local recoveryDelay = 2
        if (org.consciousness or 1) < 0.5 then recoveryDelay = 4 end
        ply.fakecd = CurTime() + recoveryDelay
    end

    ply.nextTumbleCheck = CurTime() + TUMBLE_COOLDOWN
end

hook.Add("Think", "stanleytumbler", function()
    for _, ply in ipairs(player_GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then continue end
        
        if IsValid(ply.FakeRagdoll) then continue end
        
        if ply:GetMoveType() == MOVETYPE_NOCLIP or not ply:IsOnGround() then continue end
        
        if (ply.nextTumbleCheck or 0) > CurTime() then continue end
        ply.nextTumbleCheck = CurTime() + 0.1
        local velocity = ply:GetVelocity()
        local speed = velocity:Length2D()
        local org = ply.organism or {}
        local consciousness = org.consciousness or 1
		local disorientation = org.disorientation or 0
        local stamina = org.stamina and org.stamina[1] or 100
        local effectiveThreshold = TUMBLE_SPEED_THRESHOLD
        effectiveThreshold = effectiveThreshold * math.Clamp(consciousness, 0.5, 1.0)
        
        if stamina < 20 then
            effectiveThreshold = effectiveThreshold * 0.8
        end

        -- Disorientation lowers the speed required to tumble (max 50% reduction at 10 disorientation)
        effectiveThreshold = effectiveThreshold * math.Clamp(1 - disorientation * 0.05, 0.5, 1.0)

        if speed < effectiveThreshold then continue end

        local tripChance = BASE_TRIP_CHANCE
        local shouldTrip = false
        local tripType = "none"
        local trHighHit = false

        local forward = Vector(velocity.x, velocity.y, 0)
        if forward:LengthSqr() <= 0.001 then continue end
        forward.z = 0
        forward:Normalize()

        local pos = ply:GetPos()
        local collisionTrace

        local trWall = util_TraceHull({
            start = ply:WorldSpaceCenter(),
            endpos = ply:WorldSpaceCenter() + forward * math.Clamp(speed * engine.TickInterval() * 1.5, 18, 42),
            mins = COLLISION_TRACE_MINS,
            maxs = COLLISION_TRACE_MAXS,
            filter = {ply, ply:GetVehicle()},
            mask = MASK_PLAYERSOLID
        })

        if trWall.Hit and not trWall.HitSky and not trWall.StartSolid then
             if trWall.HitNormal.z < 0.3 then
                 local ent = trWall.Entity
                 local isEntity = IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsRagdoll())
                 local isLightProp = false

                 if IsValid(ent) and not isEntity then
                    local phys = ent:GetPhysicsObject()
                    isLightProp = IsValid(phys) and phys:GetMass() < 8
                 end

                 if not isLightProp and isEntity then
                     tripType = "ragdoll"
                     shouldTrip = true
                     tripChance = tripChance + 0.5 
                     collisionTrace = trWall
                 elseif not isLightProp then
                     local highTraceHeight = 35
                     local trHigh = util_TraceLine({
                         start = pos + Vector(0,0,highTraceHeight),
                         endpos = pos + Vector(0,0,highTraceHeight) + forward * 30,
                         filter = ply,
                         mask = MASK_PLAYERSOLID
                     })
                     trHighHit = trHigh.Hit
                     
                     local speedFactor = math.Clamp((speed - 250) / 300, 0, 1)
                     
                     local wallChance = speedFactor
                     if not trHigh.Hit then
                         wallChance = wallChance * 0.3
                     end
                     
                     if wallChance > 0 then
                         shouldTrip = true
                         tripType = "wall"
                         tripChance = tripChance + wallChance
                         collisionTrace = trWall
                     end
                 end
             end
        end

        if not shouldTrip then
            local checkPos = pos + forward * 30
            local trGround = util_TraceLine({
                start = checkPos + Vector(0,0,10),
                endpos = checkPos - Vector(0,0,GAP_CHECK_DIST),
                filter = ply,
                mask = MASK_SOLID
            })

            if not trGround.Hit then
                shouldTrip = true
                tripType = "gap"
                tripChance = tripChance + 0.4
            end
        end

        if not shouldTrip then
            ply.eyeAnglesOld = ply.eyeAnglesOld or ply:EyeAngles()
            local cosine = ply:EyeAngles():Forward():Dot(ply.eyeAnglesOld:Forward())

            if speed > 200 and cosine <= 0.99 then
                local tr = util_TraceLine({ start = pos, endpos = pos - Vector(0,0,1), filter = ply })
                local surfaceData = tr and tr.Hit and tr.SurfaceProps and util.GetSurfaceData(tr.SurfaceProps)
                if surfaceData and surfaceData.friction < 0.2 then
                    shouldTrip = true
                    tripType = "slip"
                    tripChance = tripChance + 0.7
                end
            end
            ply.eyeAnglesOld = ply:EyeAngles()
        end

        tripChance = ScaleTripChance(ply, org, tripChance)

        if shouldTrip then
            local fullSpeed = math.max(ply:GetRunSpeed(), ply.move or 0)
            if collisionTrace and speed < fullSpeed * COLLISION_FULL_SPEED_MUL then
                shouldTrip = false
            end
        end

        if shouldTrip then
            if math.random() < tripChance then
                ExecuteTrip(ply, org, tripType, velocity, collisionTrace, trHighHit, TRIP_BREAK_CHANCE)
            else
                if collisionTrace then
                    StumbleFromCollision(ply)
                else
                    ply:ViewPunch(Angle(2, 0, 0))
                end
                hg.StartStagger(ply, tripType == "slip" and -forward or forward, math.Clamp(speed / 320, 0.35, 1))
                ply.nextTumbleCheck = CurTime() + 1
            end
        end
    end
end)

local STEP_TRIP_MIN_SPEED = 110
local STEP_STEEP_MIN_SPEED = 40
local STEP_STEEP_SPEED_FLOOR = 0.5
local STEP_TRIP_FULL_SPEED = 300
local STEP_TRIP_COOLDOWN = 0.6
local STEP_HALF_WIDTH = 4.5
local STEP_TOE_HEIGHT = 3
local STEP_UP_LIMIT = 18
local STEP_LEDGE_DROP = 24
local STEP_LEVEL_TOLERANCE = 2
local STEP_UNEVEN_HEIGHT = 7
local STEP_FLIGHT_RISK = 2.5
local STEP_SPRINTER_MUL = 0.5
local STEP_BREAK_CHANCE = 0.05
local STEP_HULL_MINS = Vector(-2, -2, 0)
local STEP_HULL_MAXS = Vector(2, 2, 2)
local STEP_HAZARD_CHANCE = {
    wall = 0.4,
    gap = 0.35,
    toe = 0.2,
    steep = 0.55,
    slope = 0.14,
    uneven = 0.03,
}
local STEP_SLOPE_FLAT_Z = 0.9

local function StepHazard(ply, pos, landing)
    local footStart = Vector(pos.x, pos.y, pos.z + STEP_TOE_HEIGHT)
    local trWall = util_TraceLine({
        start = footStart + Vector(0, 0, STEP_UP_LIMIT),
        endpos = Vector(landing.x, landing.y, pos.z + STEP_TOE_HEIGHT + STEP_UP_LIMIT),
        filter = ply,
        mask = MASK_PLAYERSOLID,
    })
    if trWall.Hit and not trWall.StartSolid and trWall.HitNormal.z < 0.7 then return "wall", trWall end

    local trGround = util_TraceLine({
        start = Vector(landing.x, landing.y, pos.z + STEP_UP_LIMIT + 2),
        endpos = Vector(landing.x, landing.y, pos.z - STEP_LEDGE_DROP),
        filter = ply,
        mask = MASK_PLAYERSOLID,
    })
    if not trGround.Hit then return "gap" end
    local walkableZ = hg.WalkableNormalZ and hg.WalkableNormalZ(ply) or hg.WALKABLE_NORMAL_Z or 0.7
    if trGround.HitNormal.z < walkableZ then return "steep" end
    local heightDiff = trGround.HitPos.z - pos.z
    local slopeSeverity = math.Clamp((STEP_SLOPE_FLAT_Z - trGround.HitNormal.z) / (STEP_SLOPE_FLAT_Z - walkableZ), 0, 1)

    local trToe = util_TraceHull({
        start = footStart,
        endpos = Vector(landing.x, landing.y, footStart.z),
        mins = STEP_HULL_MINS,
        maxs = STEP_HULL_MAXS,
        filter = ply,
        mask = MASK_PLAYERSOLID,
    })
    local toeHit = trToe.Hit and not trToe.StartSolid and trToe.HitNormal.z < 0.7
    if toeHit and heightDiff <= STEP_LEVEL_TOLERANCE then return "toe", trToe end
    if slopeSeverity > 0 and math.abs(heightDiff) >= STEP_UNEVEN_HEIGHT then return "slope", nil, slopeSeverity end
    if toeHit or math.abs(heightDiff) >= STEP_UNEVEN_HEIGHT then return "uneven" end
end

function hg.FootstepTripCheck(ply, stepIndex, rate, swingFraction)
    if not ply:Alive() or IsValid(ply.FakeRagdoll) or ply:InVehicle() or ply:GetMoveType() ~= MOVETYPE_WALK then return end
    if (ply.hgNextStepTrip or 0) > CurTime() or (ply.nextTumbleCheck or 0) > CurTime() + 1 then return end

    local velocity = ply:GetVelocity()
    local speed = velocity:Length2D()
    if speed < STEP_STEEP_MIN_SPEED then return end

    local moveDir = Vector(velocity.x / speed, velocity.y / speed, 0)
    local right = Vector(moveDir.y, -moveDir.x, 0)
    local side = stepIndex == 1 and -1 or 1
    local pos = ply:GetPos()
    local reach = speed * hg.GaitSwingTime(rate, swingFraction) + hg.GaitLandingLead(speed, swingFraction)
    local landing = pos + moveDir * reach + right * (side * STEP_HALF_WIDTH)

    local hazard, hazardTrace, severity = StepHazard(ply, pos, landing)
    if not hazard then return end
    if hazard ~= "steep" and speed < STEP_TRIP_MIN_SPEED then return end

    local org = ply.organism or {}
    local speedFactor = math.Clamp((speed - STEP_TRIP_MIN_SPEED) / (STEP_TRIP_FULL_SPEED - STEP_TRIP_MIN_SPEED), 0, 1)
    if hazard == "steep" then speedFactor = math.max(speedFactor, STEP_STEEP_SPEED_FLOOR) end
    local flightFactor = 1 + hg.GaitFlightFraction(swingFraction) * STEP_FLIGHT_RISK
    local tripChance = ScaleTripChance(ply, org, STEP_HAZARD_CHANCE[hazard] * (severity or 1)) * speedFactor * flightFactor
    if ply.HasTrait and ply:HasTrait("sprinter") then
        tripChance = tripChance * STEP_SPRINTER_MUL
    end
    tripChance = math.min(tripChance, MAX_TRIP_CHANCE)
    ply.hgNextStepTrip = CurTime() + STEP_TRIP_COOLDOWN

    if math.random() < tripChance then
        timer.Simple(0, function()
            if not IsValid(ply) or not ply:Alive() or IsValid(ply.FakeRagdoll) then return end
            ExecuteTrip(ply, org, hazard, velocity, hazardTrace, false, STEP_BREAK_CHANCE)
        end)

        return
    end

    if (hazard == "slope" or hazard == "uneven") and ply.HasTrait and ply:HasTrait("vibrams") then return end

    if hazard == "wall" or hazard == "toe" then
        timer.Simple(0, function()
            if IsValid(ply) and ply:Alive() and not IsValid(ply.FakeRagdoll) then StumbleFromCollision(ply) end
        end)
    else
        ply:ViewPunch(Angle(2 + speedFactor * 3, 0, math.Rand(-2, 2)))
    end

    hg.StartStagger(ply, moveDir, 0.3 + speedFactor * 0.6)
end

local SUPPORT_CHECK_INTERVAL = 0.1
local SUPPORT_FOOT_HALF_WIDTH = 4.5
local SUPPORT_TOE = 6
local SUPPORT_HEEL = -3
local SUPPORT_PROBE_HEIGHT = 8
local SUPPORT_DROP = 20
local SUPPORT_EDGE_RADIUS = 14
local SUPPORT_LOSS_TIME = 0.3
local SUPPORT_RETRY_TIME = 0.6
local SUPPORT_TRIP_CHANCE = 0.45
local SUPPORT_TRIP_SPEED = 200
local SUPPORT_PROBE_OFFSETS = {SUPPORT_TOE, SUPPORT_HEEL}
local SUPPORT_EDGE_DIRECTIONS = {}
for i = 0, 7 do
    local yaw = math.rad(i * 45)
    SUPPORT_EDGE_DIRECTIONS[i + 1] = Vector(math.cos(yaw), math.sin(yaw), 0)
end

local function ProbeSupport(ply, x, y, z)
    local trace = util_TraceLine({
        start = Vector(x, y, z + SUPPORT_PROBE_HEIGHT),
        endpos = Vector(x, y, z - SUPPORT_DROP),
        filter = ply,
        mask = MASK_PLAYERSOLID,
    })

    return trace.Hit
end

local function FootSupported(ply, origin, right, forward, side)
    local base = origin + right * (side * SUPPORT_FOOT_HALF_WIDTH)
    for _, offset in ipairs(SUPPORT_PROBE_OFFSETS) do
        local probe = base + forward * offset
        if ProbeSupport(ply, probe.x, probe.y, origin.z) then return true end
    end

    return false
end

local function UnsupportedDirection(ply, origin, fallback)
    local direction = Vector()
    for _, dir in ipairs(SUPPORT_EDGE_DIRECTIONS) do
        if not ProbeSupport(ply, origin.x + dir.x * SUPPORT_EDGE_RADIUS, origin.y + dir.y * SUPPORT_EDGE_RADIUS, origin.z) then
            direction:Add(dir)
        end
    end
    if direction:LengthSqr() < 0.01 then return fallback end
    direction:Normalize()

    return direction
end

hook.Add("Think", "hg_foot_support_trip", function()
    local now = CurTime()
    for _, ply in ipairs(player_GetAll()) do
        if (ply.hgNextSupportCheck or 0) > now then continue end
        ply.hgNextSupportCheck = now + SUPPORT_CHECK_INTERVAL

        if not ply:Alive() or IsValid(ply.FakeRagdoll) or ply:InVehicle() or ply:GetMoveType() ~= MOVETYPE_WALK
            or not ply:IsOnGround() or ply:Crouching() or ply:WaterLevel() >= 2 or (ply.nextTumbleCheck or 0) > now then
            ply.hgUnsupportedSince = nil
            continue
        end

        local origin = ply:GetPos()
        local yaw = Angle(0, ply:EyeAngles().y, 0)
        local forward, right = yaw:Forward(), yaw:Right()
        if FootSupported(ply, origin, right, forward, -1) or FootSupported(ply, origin, right, forward, 1) then
            ply.hgUnsupportedSince = nil
            continue
        end

        ply.hgUnsupportedSince = ply.hgUnsupportedSince or now
        if now - ply.hgUnsupportedSince < SUPPORT_LOSS_TIME then continue end
        ply.hgUnsupportedSince = now + SUPPORT_RETRY_TIME - SUPPORT_LOSS_TIME

        local org = ply.organism or {}
        local dir = UnsupportedDirection(ply, origin, forward)
        if math.random() < ScaleTripChance(ply, org, SUPPORT_TRIP_CHANCE) then
            ExecuteTrip(ply, org, "gap", dir * SUPPORT_TRIP_SPEED, nil, false, STEP_BREAK_CHANCE)
        else
            ply:ViewPunch(Angle(3, 0, math.Rand(-2, 2)))
            hg.StartStagger(ply, dir, 0.7)
        end
    end
end)
