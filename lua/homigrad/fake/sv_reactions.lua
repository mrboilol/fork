
include("sv_animator.lua")

local util_TraceLine = util.TraceLine
local util_TraceHull = util.TraceHull
local Vector = Vector
local Angle = Angle
local math = math

hg.reactions = hg.reactions or {}

-- Configuration
local CONFIG = {
    RaycastDistance = 200,
    StepHeight = 20,
    StepReachMultiplier = 0.8,
    StepSpeed = 400, -- Speed of leg movement
    BalanceRadius = 15,
    ReactionDelay = 0.1
}

-- Helper: Check if player is trying to control
local function IsPlayerControlling(ply)
    if not IsValid(ply) then return false end
    return ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or 
           ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT) or 
           ply:KeyDown(IN_JUMP) or ply:KeyDown(IN_DUCK) or 
           ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) or
           ply:KeyDown(IN_USE)
end

-- Helper: Find ground position (simplified from Artagdoll)
local function FindGroundPosition(pos, ragdoll, ply)
    local filterEnts = {ragdoll}
    if IsValid(ply) then table.insert(filterEnts, ply) end
    if IsValid(ragdoll.Owner) then table.insert(filterEnts, ragdoll.Owner) end

    -- Increase trace distance slightly
    local tr = util_TraceLine({
        start = pos + Vector(0, 0, 10),
        endpos = pos + Vector(0, 0, -1000), -- Much longer trace
        filter = filterEnts,
        mask = MASK_SOLID_BRUSHONLY
    })

    if tr.Hit then
        return tr.HitPos, tr.HitNormal
    end
    return nil, nil
end

-- Helper: Predict ground position based on velocity
local function PredictGroundPosition(currentPos, velocity, ragdoll)
    local predPos = currentPos + (velocity * 0.3) -- Predict 0.3s ahead
    return FindGroundPosition(predPos, ragdoll) 
end

-- Helper: Check if ragdoll is upright
local function IsUpright(ragdoll)
    local pelvis = ragdoll:GetPhysicsObjectNum(0)
    if not IsValid(pelvis) then return false end
    local up = pelvis:GetAngles():Up()
    return up.z > 0.3 -- Allow some leaning, but not flat on ground
end

-- Neurological Posturing (Decerebrate/Decorticate)
function hg.reactions.ProcessNeurological(ragdoll, ply, org)
    if not org.brain then return false end
    
    -- Decerebrate Posturing (Extensor) - Severe damage (brain stem)
    -- Arms extended, legs extended, head arched back, rigid
    if org.brain > 0.4 then
        if IsPlayerControlling(ply) then return false end
        
        -- Use stiffness to lock body
        if not ragdoll.stiffness_neurological then
            if RagdollStiffness then
                RagdollStiffness.ActivateAllBody(ragdoll, 2) -- Keep re-applying every few seconds
            end
            ragdoll.stiffness_neurological = CurTime() + 1.5
        elseif CurTime() > ragdoll.stiffness_neurological then
             ragdoll.stiffness_neurological = nil -- Allow re-application
        end
        
        -- Force extension poses via ShadowControl if not stiff enough
        -- This is a "Tonic" phase approximation
        -- We can also use "HeadshotCurl" but that looks like flexion (Decorticate)
        -- So for Decerebrate we might want to just be very stiff and straight
        
        return true
    end
    
    -- Decorticate Posturing (Flexor) - Moderate/Severe damage (corticospinal tract)
    -- Arms flexed towards chest, legs extended
    if org.brain > 0.25 then
        if IsPlayerControlling(ply) then return false end

        -- "HeadshotCurl" looks like a flexion response, suitable for Decorticate
        if not hg.animator.IsPlaying(ragdoll) or ragdoll.AnimCurrent.Name ~= "HeadshotCurl" then
            hg.animator.Play(ragdoll, "HeadshotCurl", 0.8, 1, true)
        end
        
        -- Add some stiffness
        if not ragdoll.stiffness_neurological then
             if RagdollStiffness then
                RagdollStiffness.ActivateHeadshot(ragdoll, 2)
            end
            ragdoll.stiffness_neurological = CurTime() + 1.5
        elseif CurTime() > ragdoll.stiffness_neurological then
             ragdoll.stiffness_neurological = nil
        end
        
        return true
    end
    
    return false
end

-- Injured/Dying Behavior (Agonal Breathing / struggling)
function hg.reactions.ProcessInjured(ragdoll, ply, org)
    if not org.alive or org.otrub then return false end
    
    -- If in critical condition (high pain, low blood, or just dying)
    local isCritical = (org.pain > 80) or (org.blood < 2000) or (org.dying)
    
    if not isCritical then 
        if hg.animator.IsPlaying(ragdoll) and string.find(ragdoll.AnimCurrent.Name, "Dying") then
            hg.animator.Stop(ragdoll)
        end
        return false 
    end
    
    if IsPlayerControlling(ply) then return false end
    
    -- Randomly play dying animations
    if not hg.animator.IsPlaying(ragdoll) then
        if math.random() < 0.05 then -- Low chance to start
            local anims = {"Dying1", "Dying2", "Dying3", "Dying4", "Dying5"}
            local anim = anims[math.random(#anims)]
            hg.animator.Play(ragdoll, anim, math.Rand(0.8, 1.2), math.Rand(0.5, 1.0), false)
        end
    end
    
    return true -- We are handling it (or choosing to do nothing but block others)
end

-- Protective Behavior (Cowering)
function hg.reactions.ProcessCowering(ragdoll, ply, org)
    if not org.alive or org.otrub then return false end
    
    -- Trigger on sudden high pain or explosions
    -- We use org.pain for now.
    if org.pain < 50 then return false end
    
    if IsPlayerControlling(ply) then return false end
    
    -- Cower
    if not hg.animator.IsPlaying(ragdoll) or ragdoll.AnimCurrent.Name ~= "cower_idle" then
         hg.animator.Play(ragdoll, "cower_idle", 1, 1, true)
    end
    
    return true
end


-- Headshot/Brain Damage Reaction
function hg.reactions.ProcessHeadshot(ragdoll, ply, org)
    -- Lower threshold to ensure it triggers (0.2 is 20% brain damage)
    -- Also check if we are already playing it
    if org.brain < 0.2 then return false end 
    
    if IsPlayerControlling(ply) and not org.otrub then 
        if hg.animator.IsPlaying(ragdoll) and ragdoll.AnimCurrent.Name == "HeadshotCurl" then
            hg.animator.Stop(ragdoll)
        end
        return false 
    end
    
    -- Force play if not playing
    if not hg.animator.IsPlaying(ragdoll) or ragdoll.AnimCurrent.Name ~= "HeadshotCurl" then
        hg.animator.Play(ragdoll, "HeadshotCurl", 1.2, 1.5, true) -- Faster rate, higher strength for brutality
        
        -- Apply sudden impulse to head to simulate impact/spasm
        local head = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 10))
        if IsValid(head) then
            head:ApplyForceCenter(VectorRand() * 200 + Vector(0,0,100))
        end
        
        -- Add extreme stiffness
        if RagdollStiffness then
            RagdollStiffness.ActivateHeadshot(ragdoll, 3)
        end
    end
    
    return true
end

-- Burning Reaction
function hg.reactions.ProcessBurning(ragdoll, ply, org)
    if not ragdoll:IsOnFire() then 
        if hg.animator.IsPlaying(ragdoll) and ragdoll.AnimCurrent.Name == "Burning" then
             hg.animator.Stop(ragdoll)
        end
        return false 
    end
    
    if IsPlayerControlling(ply) then 
        hg.animator.Stop(ragdoll)
        return false 
    end
    
    hg.animator.Play(ragdoll, "Burning", 0.7, 1, true)
    return true
end

-- Drowning Reaction
function hg.reactions.ProcessDrowning(ragdoll, ply, org)
    if ply:WaterLevel() < 3 then 
         if hg.animator.IsPlaying(ragdoll) and ragdoll.AnimCurrent.Name == "Drowning" then
             hg.animator.Stop(ragdoll)
        end
        return false 
    end
    if not org.alive or org.otrub then return false end
    
    if IsPlayerControlling(ply) then 
        hg.animator.Stop(ragdoll)
        return false 
    end
    
    hg.animator.Play(ragdoll, "Drowning", 0.7, 1, true)
    return true
end

-- Stagger Behavior
function hg.reactions.ProcessStagger(ragdoll, ply, org)
    -- Only stagger if alive and not paralyzed/unconscious
    if not org.alive or org.otrub or org.paralyzed then return false end
    
    -- Respect player control
    if IsPlayerControlling(ply) then return false end
    
    -- Must be somewhat upright to stagger
    if not IsUpright(ragdoll) then return false end

    -- If we are moving fast or took damage recently
    local velocity = ragdoll:GetVelocity()
    local speed = velocity:Length()
    
    -- Detect "off balance"
    local pelvis = ragdoll:GetPhysicsObjectNum(0) -- Pelvis
    if not IsValid(pelvis) then return false end
    
    local com = pelvis:GetPos() -- Approx CoM
    local ground, normal = FindGroundPosition(com, ragdoll, ply)
    
    if not ground then return false end -- In air (falling handled elsewhere)
    
    -- Check if CoM is outside support polygon (simplified to distance from feet center)
    -- We need to find feet positions
    local lfoot = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 13))
    local rfoot = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 14))
    
    if not IsValid(lfoot) or not IsValid(rfoot) then return false end
    
    local feetCenter = (lfoot:GetPos() + rfoot:GetPos()) / 2
    local dist = (Vector(com.x, com.y, 0) - Vector(feetCenter.x, feetCenter.y, 0)):Length()
    
    local isStaggering = false
    
    -- Logic: If speed is high or we are leaning too much, step!
    -- Or if we took damage recently (pain reaction)
    if speed > 150 or dist > CONFIG.BalanceRadius or (org.pain > 50 and math.random() < 0.1) then
        isStaggering = true
    end

    if isStaggering then
        -- Use procedural stagger for now as it needs context (which leg to step)
        -- Artagdoll uses "Stagger" animation but it's generic.
        -- Let's stick to procedural for walking/balancing unless we want to replace it.
        -- For consistency with "Add all reactions from artagdoll", we should check if Artagdoll uses animation.
        -- Artagdoll's stagger.lua uses procedural steps too? No, it uses animation in some cases but mostly procedural.
        -- Let's keep procedural for now.
        
        -- Determine which leg to step with (the one further behind usually, or random)
        local stepLeg = (math.random() > 0.5) and 13 or 14 -- 13: LFoot, 14: RFoot
        
        -- Check for broken legs (organism system)
        local isLeft = (stepLeg == 13)
        local leftBroken = (org.lleg == 1)
        local rightBroken = (org.rleg == 1)
        
        if (isLeft and leftBroken) then
            stepLeg = 14 -- Try right
        elseif (not isLeft and rightBroken) then
            stepLeg = 13 -- Try left
        end
        
        -- Double check if the chosen leg is broken
        if (stepLeg == 13 and leftBroken) or (stepLeg == 14 and rightBroken) then
            return false -- Both broken or only option broken
        end
        
        local otherLeg = (stepLeg == 13) and 14 or 13
        local calfBone = (stepLeg == 13) and 12 or 9
        local thighBone = (stepLeg == 13) and 11 or 8
        
        -- Calculate step target
        local predGround, _ = PredictGroundPosition(com, velocity, ragdoll)
        if predGround then
            local targetPos = predGround
            
            -- Apply shadow control to the stepping leg
            -- We need to lift it and move it
            local legPhys = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, stepLeg))
            local kneePhys = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, calfBone)) -- Calf
            local thighPhys = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, thighBone)) -- Thigh

            if IsValid(legPhys) then
                -- Lift
                local liftHeight = CONFIG.StepHeight
                local stepTarget = targetPos + Vector(0, 0, liftHeight)
                
                hg.ShadowControl(ragdoll, stepLeg, 0.1, nil, nil, nil, stepTarget, CONFIG.StepSpeed, 100)
                
                return true -- We handled legs
            end
        end
    end
    
    return false
end

-- Flailing Behavior (High Fall)
function hg.reactions.ProcessFlailing(ragdoll, ply, org)
    if not org.alive or org.otrub then return false end
    
    -- Removed player control check - involuntary panic reflex
    
    local pelvis = ragdoll:GetPhysicsObjectNum(0)
    local velocity = IsValid(pelvis) and pelvis:GetVelocity() or ragdoll:GetVelocity()
    local verticalSpeed = velocity.z
    
    -- Falling fast (lowered threshold further to ensure it triggers)
    if verticalSpeed < -200 then
        local pos = IsValid(pelvis) and pelvis:GetPos() or ragdoll:GetPos()
        local ground, _ = FindGroundPosition(pos, ragdoll, ply)
        local dist = ground and (pos.z - ground.z) or 1000
        
        -- High up -> Flail
        if dist > 200 then
             -- Use Animation "Falling"
             -- Force play it if not already playing
             if not hg.animator.IsPlaying(ragdoll) or ragdoll.AnimCurrent.Name ~= "Falling" then
                 hg.animator.Play(ragdoll, "Falling", 1.2, 1, true)
             end
             return true
        end
    end
    
    if hg.animator.IsPlaying(ragdoll) and ragdoll.AnimCurrent.Name == "Falling" then
         hg.animator.Stop(ragdoll)
    end
    
    return false
end

-- Tripping/Stumbling (Hit obstacle)
function hg.reactions.ProcessTripping(ragdoll, ply, org)
    if not org.alive or org.otrub or org.paralyzed then return false end
    
    -- If user is controlling, maybe they MEANT to jump?
    if ply:KeyDown(IN_JUMP) then return false end
    
    local velocity = ragdoll:GetVelocity()
    local speed = velocity:Length()
    
    if speed < 100 then return false end -- Lowered threshold (walk speed)
    
    local lfoot = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 13))
    local rfoot = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 14))
    
    if not IsValid(lfoot) or not IsValid(rfoot) then return false end
    
    -- Raycast forward from feet to detect low obstacles
    local forward = velocity:GetNormalized()
    local traceStart = (lfoot:GetPos() + rfoot:GetPos()) / 2 + Vector(0, 0, 5)
    local traceEnd = traceStart + forward * 30
    
    local tr = util_TraceLine({
        start = traceStart,
        endpos = traceEnd,
        filter = {ragdoll, ply},
        mask = MASK_SOLID
    })
    
    if tr.Hit then
        -- TRIP!
        -- 1. Push pelvis forward (momentum carries body)
        -- 2. Pull legs back/up (caught on obstacle)
        -- 3. Arms forward (handled by Protective/Stagger potentially, or we force it here)
        
        local pelvis = ragdoll:GetPhysicsObjectNum(0)
        if IsValid(pelvis) then
            pelvis:ApplyForceCenter(forward * 500 + Vector(0, 0, -200)) -- Dip forward
        end
        
        -- Lift legs back
        hg.ShadowControl(ragdoll, 13, 0.1, nil, nil, nil, lfoot:GetPos() - forward * 20 + Vector(0, 0, 10), 1000, 100)
        hg.ShadowControl(ragdoll, 14, 0.1, nil, nil, nil, rfoot:GetPos() - forward * 20 + Vector(0, 0, 10), 1000, 100)
        
        -- Arms forward immediately to catch fall
        local lhand = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 5))
        local rhand = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 7))
        
        if IsValid(lhand) and org.larm ~= 1 then
            hg.ShadowControl(ragdoll, 5, 0.05, nil, nil, nil, ragdoll:GetPos() + forward * 50 + Vector(0, 0, 20), 1000, 100)
        end
        
        if IsValid(rhand) and org.rarm ~= 1 then
            hg.ShadowControl(ragdoll, 7, 0.05, nil, nil, nil, ragdoll:GetPos() + forward * 50 + Vector(0, 0, 20), 1000, 100)
        end
        
        return true -- Handled everything (arms and legs)
    end
    
    return false
end

-- Protective Behavior (Arms out when falling)
function hg.reactions.ProcessProtective(ragdoll, ply, org)
    if not org.alive or org.otrub then return false end
    
    if IsPlayerControlling(ply) then return false end
    
    local velocity = ragdoll:GetVelocity()
    local verticalSpeed = velocity.z
    
    -- Check if falling
    if verticalSpeed < -300 then
        -- Check ground distance
        local ground, _ = FindGroundPosition(ragdoll:GetPos(), ragdoll, ply)
        local dist = ground and (ragdoll:GetPos().z - ground.z) or 1000
        
        if dist < 300 and dist > 50 then
            -- Put arms out!
            local handled = false
            
            local lhand = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 5))
            local rhand = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 7))
            
            local head = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 10))
            local forward = head and head:GetAngles():Forward() or ragdoll:GetAngles():Forward()
            
            -- Check organism state (broken arms)
            local leftBroken = (org.larm == 1)
            local rightBroken = (org.rarm == 1)
            
            if IsValid(lhand) and not leftBroken then
                local targetL = ragdoll:GetPos() + forward * 30 + Vector(0, 10, 0)
                hg.ShadowControl(ragdoll, 5, 0.05, nil, nil, nil, targetL, 600, 50)
                handled = true
            end
            
            if IsValid(rhand) and not rightBroken then
                local targetR = ragdoll:GetPos() + forward * 30 + Vector(0, -10, 0)
                hg.ShadowControl(ragdoll, 7, 0.05, nil, nil, nil, targetR, 600, 50)
                handled = true
            end
            
            return handled -- Handled arms
        end
    end
    
    return false
end

-- Main entry point
function hg.ProcessReactions(ragdoll, ply, org)
    if not IsValid(ragdoll) or not IsValid(ply) or not org then return end
    
    -- Check if animation is playing
    if hg.animator.IsPlaying(ragdoll) then
        hg.animator.Update(ragdoll)
        hg.animator.Apply(ragdoll)
        
        -- If playing a blocking animation, return all true to suppress default controls
        -- We check if we should stop it in the specific reaction functions below
    end
    
    -- Neurological Posturing (Severe brain damage - decerebrate/decorticate)
    local isNeurological = hg.reactions.ProcessNeurological(ragdoll, ply, org)
    if isNeurological then
        return {arms = true, legs = true}
    end
    
    -- Headshot / Brain Damage (High priority, involuntary)
    local isHeadshot = hg.reactions.ProcessHeadshot(ragdoll, ply, org)
    if isHeadshot then
        return {arms = true, legs = true}
    end
    
    -- Burning (High priority)
    local isBurning = hg.reactions.ProcessBurning(ragdoll, ply, org)
    if isBurning then
        return {arms = true, legs = true}
    end
    
    -- Drowning (High priority)
    local isDrowning = hg.reactions.ProcessDrowning(ragdoll, ply, org)
    if isDrowning then
        return {arms = true, legs = true}
    end

    -- Check for tripping (Highest priority - immediate physical interaction)
    local isTripping = hg.reactions.ProcessTripping(ragdoll, ply, org)
    if isTripping then
        return {arms = true, legs = true}
    end
    
    -- Check for flailing (High fall)
    local isFlailing = hg.reactions.ProcessFlailing(ragdoll, ply, org)
    if isFlailing then
        return {arms = true, legs = false} 
    end
    
    -- Check for injured (High pain / dying)
    local isInjured = hg.reactions.ProcessInjured(ragdoll, ply, org)
    if isInjured then
        return {arms = true, legs = true}
    end
    
    -- Check for cowering (Moderate pain / fear)
    local isCowering = hg.reactions.ProcessCowering(ragdoll, ply, org)
    if isCowering then
        return {arms = true, legs = true}
    end
    
    -- Check for protective (Falling close to ground)
    local handledArms = hg.reactions.ProcessProtective(ragdoll, ply, org)
    
    -- Check for stagger (Balance)
    local handledLegs = hg.reactions.ProcessStagger(ragdoll, ply, org)
    
    return {arms = handledArms, legs = handledLegs}
end
