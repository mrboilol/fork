DMS = DMS or {}
DMS.Physics = DMS.Physics or {}

local IsValid = IsValid
local CurTime = CurTime
local math = math
local Vector = Vector
local util = util
local Lerp = Lerp

local TICK_RATE = 1 / 30
local TRACE_DISTANCE = 60
local BASE_UPRIGHT_THRESHOLD = 0.05
local BASE_STUMBLE_HEIGHT = 23.5
local SPEED_AIR_FALLING = 150
local VELOCITY_SMOOTHING = 0.2 
local TRANSITION_DELAY = 0.15
local STATE_COOLDOWN = 0.5 

local cv_FatalHeadshot = GetConVar("ar_FatalHeadshot") or CreateConVar("ar_FatalHeadshot", "1")
local cv_TumbleSpeed   = GetConVar("ar_TumbleSpeed") or CreateConVar("ar_TumbleSpeed", "300")
local cv_EnableCrawl   = GetConVar("ar_enableCrawling") or CreateConVar("ar_enableCrawling", "1")
local cv_EnableHoldEnv = GetConVar("ar_enableHoldEnv") or CreateConVar("ar_enableHoldEnv", "1")
local cv_EnableWoundGr = GetConVar("ar_EnableWoundGrab") or CreateConVar("ar_EnableWoundGrab", "1")
local cv_GrabTime      = GetConVar("ar_GrabTime") or CreateConVar("ar_GrabTime", "3")

local reusableTraceData = {
    mask = MASK_SOLID_BRUSHONLY
}
local traceVecDown = Vector(0, 0, TRACE_DISTANCE)

local function SafeGetBoneAngles(ent, boneIdx)
    if not IsValid(ent) or not boneIdx or boneIdx == -1 then return nil end
    local matrix = ent:GetBoneMatrix(boneIdx)
    if not matrix then return nil end
    return matrix:GetAngles()
end

function DMS.Physics:HandleTransitions(ar)
    if not ar or not IsValid(ar.ragdoll) then return end
    local ragdoll = ar.ragdoll
    if ragdoll:IsMarkedForDeletion() then return end
    
    local curTime = CurTime()

    ar.nextPhysTick = ar.nextPhysTick or 0
    if curTime < ar.nextPhysTick then return end
    ar.nextPhysTick = curTime + TICK_RATE

    local phys = ragdoll:GetPhysicsObject()
    if not IsValid(phys) or phys:IsAsleep() or not phys:IsMoveable() then return end
    
    if ragdoll.DMS_IsHeadshot then
        if cv_FatalHeadshot:GetBool() then
            if ar.CurrentBehavior ~= "headshot" then
                
                if AnimatedHands then AnimatedHands:RemoveEntity(ragdoll) end

                local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
                local soundPos = ragdoll:WorldSpaceCenter() 
                if headBone then soundPos = ragdoll:GetBonePosition(headBone) end

                local randomSound = "gore/headshot/headshot" .. math.random(1, 5) .. ".wav"
                ragdoll:EmitSound(randomSound, 85, 100, 2, CHAN_AUTO)

                DMS:Switch(ar, "headshot")
                
                local layersToRemove = {"woundgrab", "holdenv", "wallstunt"}
                for i = 1, #layersToRemove do
                    local layer = layersToRemove[i]
                    if ar.ActiveLayers[layer] then DMS:RemoveLayer(ar, layer) end
                end
                
                if SoundManager then SoundManager:Play(ragdoll, "Death", false) end
                ar.DMS_HeadshotLocked = true 
                ar.lastStateSwitch = curTime
            end
            return
        else
            ragdoll.DMS_IsHeadshot = false
            ar.DMS_HeadshotLocked = false
        end
    end

    if ar.DMS_HeadshotLocked then return end

    if not ar.PersonalityInitialized then
        ar.Bravery = math.Rand(0.85, 1.25)
        ar.Balance = math.Rand(0.8, 1.2)
        ar.cachedSpineIdx = ragdoll:LookupBone("ValveBiped.Bip01_Spine2")
        ar.cachedPelvisIdx = ragdoll:LookupBone("ValveBiped.Bip01_Pelvis")
        if ar.cachedSpineIdx and ar.cachedPelvisIdx then
            ar.PersonalityInitialized = true
        else
            return 
        end
    end

    ar.lastTransitionCheck = ar.lastTransitionCheck or 0
    if curTime - ar.lastTransitionCheck < TRANSITION_DELAY then return end
    ar.lastTransitionCheck = curTime

    ar.lastStateSwitch = ar.lastStateSwitch or 0
    if curTime - ar.lastStateSwitch < STATE_COOLDOWN then return end

    local waterLevel = ragdoll:WaterLevel()
    if waterLevel >= 1 then
        if ragdoll:IsOnFire() then ragdoll:Extinguish() end
        if ar.CurrentBehavior ~= "drowning" then
            DMS:Switch(ar, "drowning")
            ar.lastStateSwitch = curTime
        end
        return
    end

    if ragdoll:IsOnFire() then
        if ar.CurrentBehavior ~= "burning" then
            DMS:Switch(ar, "burning")
            ar.lastStateSwitch = curTime
            
            if ar.ActiveLayers["woundgrab"] then DMS:RemoveLayer(ar, "woundgrab") end
            if ar.ActiveLayers["holdenv"] then DMS:RemoveLayer(ar, "holdenv") end
        end
        return
    end
    
    local velocity = phys:GetVelocity()
    local rawSpeed = velocity:Length2D()
    local verticalVel = math.abs(velocity.z)
    
    ar.avgSpeed = Lerp(VELOCITY_SMOOTHING, ar.avgSpeed or rawSpeed, rawSpeed)

    local startPos = ragdoll:WorldSpaceCenter()
    reusableTraceData.start = startPos
    reusableTraceData.endpos = startPos - traceVecDown
    reusableTraceData.filter = ragdoll
    local tr = util.TraceLine(reusableTraceData)

    local targetState = ar.CurrentBehavior
    local tumbleLimit = cv_TumbleSpeed:GetFloat() * ar.Bravery

    if not tr.Hit then
        targetState = (verticalVel > SPEED_AIR_FALLING) and "falling" or "injured"
    else
        if ar.TumbleLockTime and curTime < ar.TumbleLockTime then
            targetState = "tumble"
        else
            local isUpright = false
            local ang = SafeGetBoneAngles(ragdoll, ar.cachedSpineIdx)
            if ang then
                isUpright = ang:Forward().z > (BASE_UPRIGHT_THRESHOLD / ar.Balance) 
            end
            
            if (TRACE_DISTANCE * tr.Fraction) <= BASE_STUMBLE_HEIGHT then
                if (ar.avgSpeed > tumbleLimit) then
                    targetState = "tumble"
                    ar.TumbleLockTime = curTime + 3
                else
                    targetState = "injured"
                end
            else
                targetState = isUpright and "stumble" or "injured"
            end
        end
    end

    if targetState == "injured" then
        local pAng = SafeGetBoneAngles(ragdoll, ar.cachedPelvisIdx)
        if pAng then
            local isOnStomach = pAng:Up():Dot(Vector(0, 0, -1)) > 0.15
            if isOnStomach then
                if not ar.CrawlChanceRolled then
                    ar.WantsToCrawl = (math.random() < 0.05)
                    ar.CrawlChanceRolled = true 
                end

                if cv_EnableCrawl:GetBool() and ar.WantsToCrawl then
                    targetState = "crawling"
                end 
            else
                ar.WantsToCrawl = false
                ar.CrawlChanceRolled = false 
            end
        end
    else
        ar.CrawlChanceRolled = false
        ar.WantsToCrawl = false
    end

    if not tr.Hit then
        if not ar.ActiveLayers["holdenv"] and cv_EnableHoldEnv:GetBool() then
            DMS:AddLayer(ar, "holdenv")
        end
    else
        if ar.ActiveLayers["holdenv"] then DMS:RemoveLayer(ar, "holdenv") end
        
        if targetState == "stumble" then
            if not ar.ActiveLayers["wallstunt"] then DMS:AddLayer(ar, "wallstunt") end
        else
            if ar.ActiveLayers["wallstunt"] then DMS:RemoveLayer(ar, "wallstunt") end
        end

        if (targetState == "injured" or targetState == "stumble" or targetState == "crawling") then
            if not ar.ActiveLayers["woundgrab"] and not ar.WoundGrabPlayed then
                if cv_EnableWoundGr:GetBool() then
                    DMS:AddLayer(ar, "woundgrab")
                    ar.WoundGrabStartTime = curTime
                    ar.WoundGrabPlayed = true 
                end
            end
        end
    end

    if ar.WoundGrabStartTime and (curTime - ar.WoundGrabStartTime > cv_GrabTime:GetFloat()) then
        DMS:RemoveLayer(ar, "woundgrab")
        ar.WoundGrabStartTime = nil
    end
    
    ar.StationaryTime = ar.StationaryTime or 0

    if rawSpeed < 0.5 then
        ar.StationaryTime = ar.StationaryTime + TICK_RATE
    else
        ar.StationaryTime = 0
    end

    if targetState == "injured" and ar.StationaryTime > 1.5 then
        if ar.CurrentBehavior ~= "none" then
             if ar.BehaviorInstance and ar.BehaviorInstance.OnExit then
                 ar.BehaviorInstance:OnExit(ar)
             end
             ar.BehaviorInstance = nil
             ar.CurrentBehavior = "none"
             
             if SoundManager and SoundManager.Stop then
                 SoundManager:Stop(ragdoll, 0.5)
             end
        end
        return
    end

    if targetState and ar.CurrentBehavior ~= targetState then
        if DMS.Behaviors[targetState] then
            DMS:Switch(ar, targetState)
            ar.lastStateSwitch = curTime
        end
    end
end