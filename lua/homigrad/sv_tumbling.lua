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
local COLLISION_TRACE_MINS = Vector(-12, -12, -20)
local COLLISION_TRACE_MAXS = Vector(12, 12, 20)
local COLLISION_FULL_SPEED_MUL = 0.98
local COLLISION_STUMBLE_SLOWDOWN = 450
local COLLISION_STUMBLE_TIME = 0.18
local COLLISION_DAMAGE_MUL = 0.08
local COLLISION_DAMAGE_TIME = 0.9
local COLLISION_SOUNDS = {
    "raminto/ram1.wav",
    "raminto/ram2.wav",
    "raminto/ram3.wav"
}

local function GetCollisionPhysBone(ply, hitPos)
    local localHit = ply:WorldToLocal(hitPos)
    local boneName = "ValveBiped.Bip01_Spine2"

    if localHit.z >= 54 then
        boneName = "ValveBiped.Bip01_Head1"
    elseif localHit.z <= 20 then
        boneName = localHit.y >= 0 and "ValveBiped.Bip01_L_Thigh" or "ValveBiped.Bip01_R_Thigh"
    elseif localHit.y >= 12 then
        boneName = "ValveBiped.Bip01_L_UpperArm"
    elseif localHit.y <= -12 then
        boneName = "ValveBiped.Bip01_R_UpperArm"
    end

    local bone = ply:LookupBone(boneName)
    local physbone = bone and ply:TranslateBoneToPhysBone(bone) or 0

    if not physbone or physbone < 0 then
        boneName = "ValveBiped.Bip01_Spine2"
        bone = ply:LookupBone(boneName)
        physbone = bone and ply:TranslateBoneToPhysBone(bone) or 0
    end

    return physbone, boneName
end

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

local function ApplyCollisionTripForces(ply, tr, velocity, impactSpeed)
    local hitEnt = tr.Entity
    local impactDir = IsValid(hitEnt) and hitEnt:IsPlayer() and ply:WorldSpaceCenter() - hitEnt:WorldSpaceCenter() or -tr.HitNormal

    if impactDir:LengthSqr() <= 0.001 then
        impactDir = velocity:GetNormalized()
    end

    impactDir.z = math.max(impactDir.z, 0.18)
    impactDir:Normalize()

    local hitPhysbone, hitBoneName = GetCollisionPhysBone(ply, tr.HitPos)
    local torsoBone = ply:LookupBone("ValveBiped.Bip01_Spine2")
    torsoBone = torsoBone and ply:TranslateBoneToPhysBone(torsoBone) or 0

    local clampedImpact = math.Clamp(impactSpeed, 0, 260)
    local hitMass = (hg.IdealMassPlayer and hg.IdealMassPlayer[hitBoneName]) or 4
    local torsoMass = (hg.IdealMassPlayer and hg.IdealMassPlayer["ValveBiped.Bip01_Spine2"]) or 4
    local contactForce = impactDir * clampedImpact * hitMass * 0.55
    local torsoForce = impactDir * clampedImpact * torsoMass * 0.4 + Vector(0, 0, clampedImpact * torsoMass * 0.2)

    ply.hgSprintCollisionDamageMul = COLLISION_DAMAGE_MUL
    ply.hgSprintCollisionDamageUntil = CurTime() + COLLISION_DAMAGE_TIME
    hg.AddForceRag(ply, hitPhysbone, contactForce, 0.25)
    hg.AddForceRag(ply, torsoBone, torsoForce, 0.25)
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
        local fear = org.fear or 0
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
        local collisionImpactSpeed

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
                     collisionImpactSpeed = IsValid(ent) and ent:IsPlayer() and (velocity - ent:GetVelocity()):Length() or speed
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
                         collisionImpactSpeed = math.abs(velocity:Dot(-trWall.HitNormal))
                         collisionImpactSpeed = collisionImpactSpeed > 0 and collisionImpactSpeed or speed
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

        if fear > 0.1 then
            tripChance = tripChance + fear * 0.25
        end
        if disorientation > 0.1 then
            tripChance = tripChance + disorientation * 0.05
        end

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

        tripChance = math.Clamp(tripChance, 0, MAX_TRIP_CHANCE)

        if shouldTrip then
            local fullSpeed = math.max(ply:GetRunSpeed(), ply.move or 0)
            if collisionTrace and speed < fullSpeed * COLLISION_FULL_SPEED_MUL then
                shouldTrip = false
            end
        end

        if shouldTrip then
            if math.random() < tripChance then
                hg.Fake(ply)
                --mcity reference?
                if not org.superfighter then
                    local breakChance = 0.15
					if math.random() < breakChance then
                        -- Limb break
                                                PlayBoneBreakSound(ply)

                        if tripType == "wall" then
                            if trHighHit then
                                org.jaw = 1 -- Break jaw
                            else
                                if math.random(1, 2) == 1 then
                                    org.rleg = 1 -- Break right leg
                                else
                                    org.lleg = 1 -- Break left leg
                                end
                            end
                        elseif tripType == "ragdoll" then
                            if math.random(1, 2) == 1 then
                                org.rarm = 1 -- Break right arm
                            else
                                org.larm = 1 -- Break left arm
                            end
                        else
                            ply:EmitSound("physics/body/body_medium_break"..math.random(2,4)..".wav")
                        end
					end
                end
                
                local ragdoll = ply.FakeRagdoll
                if IsValid(ragdoll) then
                    local b1 = ply:TranslateBoneToPhysBone(ply:LookupBone("ValveBiped.Bip01_L_Calf"))
                    local phys1 = (hg.IdealMassPlayer and hg.IdealMassPlayer["ValveBiped.Bip01_L_Calf"]) or 7
                    local b2 = ply:TranslateBoneToPhysBone(ply:LookupBone("ValveBiped.Bip01_R_Calf"))
                    local phys2 = (hg.IdealMassPlayer and hg.IdealMassPlayer["ValveBiped.Bip01_R_Calf"]) or 7
                    local torso = ply:TranslateBoneToPhysBone(ply:LookupBone("ValveBiped.Bip01_Spine2"))
                    local phystorso = (hg.IdealMassPlayer and hg.IdealMassPlayer["ValveBiped.Bip01_Spine2"]) or 20

                    local force = velocity:GetNormalized() * 150

                    if collisionTrace then
                        PlayCollisionSound(ply)
                        ApplyCollisionTripForces(ply, collisionTrace, velocity, collisionImpactSpeed)
                    elseif tripType == "slip" then
                        hg.AddForceRag(ply, torso, -force * 5 * phystorso, 0.5)
                        hg.AddForceRag(ply, b1, (force * 5 - Vector(0,0,2)) * phys1, 0.5)
                        hg.AddForceRag(ply, b2, (force * 5 - Vector(0,0,2)) * phys2, 0.5)
                    else
                        local torsoForce = -force * 5 * phystorso
                        local legForce = (force * 5 - Vector(0,0,2)) * phys1

                        if tripType == "wall" then
                            torsoForce = torsoForce * 1.2
                            legForce = legForce * 0.8 
                        elseif tripType == "gap" then
                            legForce = legForce * 1.5
                        elseif tripType == "ragdoll" then
                            torsoForce = torsoForce * 0.5
                        end

                        hg.AddForceRag(ply, torso, torsoForce, 0.5)
                        hg.AddForceRag(ply, b1, legForce, 0.5)
                        hg.AddForceRag(ply, b2, legForce, 0.5)
                    end

                    timer.Simple(0, function()
                        if IsValid(ply) then hg.StunPlayer(ply) end
                    end)

                    local recoveryDelay = 2
                    if consciousness < 0.5 then recoveryDelay = 4 end
                    ply.fakecd = CurTime() + recoveryDelay
                end
                
                ply.nextTumbleCheck = CurTime() + TUMBLE_COOLDOWN
            else
                if collisionTrace then
                    StumbleFromCollision(ply)
                else
                    ply:ViewPunch(Angle(2, 0, 0))
                end
                ply.nextTumbleCheck = CurTime() + 1 
            end
        end
    end
end)
