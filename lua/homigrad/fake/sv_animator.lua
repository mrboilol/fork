
hg.animator = hg.animator or {}

local GHOST_MODEL = "models/deathanimss/model_anim.mdl"
local ANCHOR_MODEL = "models/hunter/plates/plate.mdl"
local ANGLE_OFFSET = Angle(0, 0, 0) -- Adjusted offset, -90 -90 might be wrong for this model orientation

-- Helper to create the ghost entity hierarchy
local function CreateGhost(ragdoll)
    if IsValid(ragdoll.AnimAnchor) then ragdoll.AnimAnchor:Remove() end
    if IsValid(ragdoll.AnimGhost) then ragdoll.AnimGhost:Remove() end

    -- Create Anchor (tracks pelvis)
    local anchor = ents.Create("prop_dynamic")
    anchor:SetModel(ANCHOR_MODEL)
    anchor:SetPos(ragdoll:GetPos())
    anchor:SetAngles(ragdoll:GetAngles())
    anchor:Spawn()
    anchor:SetNoDraw(true)
    anchor:SetSolid(SOLID_NONE)
    anchor:SetMoveType(MOVETYPE_NONE)
    
    -- Create Ghost (plays animation)
    local ghost = ents.Create("prop_dynamic")
    ghost:SetModel(GHOST_MODEL)
    ghost:SetPos(anchor:GetPos())
    ghost:SetParent(anchor)
    ghost:SetLocalAngles(ANGLE_OFFSET)
    ghost:Spawn()
    ghost:SetNoDraw(true) -- Set to false to debug
    ghost:SetSolid(SOLID_NONE)
    ghost:SetMoveType(MOVETYPE_NONE)
    
    ragdoll.AnimAnchor = anchor
    ragdoll.AnimGhost = ghost
    
    return ghost
end

function hg.animator.Play(ragdoll, animName, rate, strength, loop)
    if not IsValid(ragdoll) then return end
    
    -- If already playing this animation, just update parameters
    if ragdoll.AnimCurrent and ragdoll.AnimCurrent.Name == animName and IsValid(ragdoll.AnimGhost) then
        ragdoll.AnimCurrent.Strength = strength or ragdoll.AnimCurrent.Strength
        ragdoll.AnimCurrent.Rate = rate or ragdoll.AnimCurrent.Rate
        ragdoll.AnimGhost:SetPlaybackRate(ragdoll.AnimCurrent.Rate)
        return
    end
    
    local ghost = ragdoll.AnimGhost
    if not IsValid(ghost) then
        ghost = CreateGhost(ragdoll)
    end
    
    local seq = ghost:LookupSequence(animName)
    if seq == -1 then 
        -- Fallback or error
        -- print("[HG] Animator: Sequence not found: " .. animName)
        return 
    end
    
    ghost:ResetSequence(seq)
    ghost:SetPlaybackRate(rate or 1)
    
    ragdoll.AnimCurrent = {
        Name = animName,
        Strength = strength or 1,
        Rate = rate or 1,
        Loop = loop or false,
        StartTime = CurTime()
    }
end

function hg.animator.Stop(ragdoll)
    if IsValid(ragdoll.AnimAnchor) then ragdoll.AnimAnchor:Remove() end
    -- Ghost is parented to anchor, so it gets removed too, but let's be safe
    if IsValid(ragdoll.AnimGhost) then ragdoll.AnimGhost:Remove() end
    
    ragdoll.AnimAnchor = nil
    ragdoll.AnimGhost = nil
    ragdoll.AnimCurrent = nil
end

function hg.animator.IsPlaying(ragdoll)
    return IsValid(ragdoll.AnimGhost) and ragdoll.AnimCurrent ~= nil
end

-- Update ghost position and frame
function hg.animator.Update(ragdoll)
    if not hg.animator.IsPlaying(ragdoll) then return end
    
    local anchor = ragdoll.AnimAnchor
    local ghost = ragdoll.AnimGhost
    
    -- Sync anchor to pelvis
    local pelvis = ragdoll:GetPhysicsObjectNum(0)
    if IsValid(pelvis) then
        anchor:SetPos(pelvis:GetPos())
        -- We align anchor with pelvis angles
        -- Artagdoll does: angleparent:SetAngles(physparent)
        anchor:SetAngles(pelvis:GetAngles())
    end
    
    -- Advance animation
    ghost:FrameAdvance()
    
    -- Check for animation finish if not looping
    if not ragdoll.AnimCurrent.Loop and ghost:GetCycle() >= 1 then
        hg.animator.Stop(ragdoll)
    end
    
    -- Force cycle update for looping animations to prevent stuck frames
    if ragdoll.AnimCurrent.Loop and ghost:GetCycle() >= 1 then
        ghost:SetCycle(0)
    end
end

-- Apply forces to match ghost
local shadowparams = {
    secondstoarrive = 0.05,
    maxangular = 1000,
    maxangulardamp = 100,
    maxspeed = 1000,
    maxspeeddamp = 100,
    dampfactor = 0.8,
    teleportdistance = 0
}

function hg.animator.Apply(ragdoll)
    if not hg.animator.IsPlaying(ragdoll) then return end
    
    local ghost = ragdoll.AnimGhost
    local strength = ragdoll.AnimCurrent.Strength or 1
    
    -- Iterate all physics bones
    local count = ragdoll:GetPhysicsObjectCount()
    for i = 1, count - 1 do -- Skip pelvis (0) as it is the anchor
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if not IsValid(phys) then continue end
        
        -- Find corresponding bone in ghost
        local boneID = ragdoll:TranslatePhysBoneToBone(i)
        local boneName = ragdoll:GetBoneName(boneID)
        
        if not boneName then continue end
        
        local ghostBoneID = ghost:LookupBone(boneName)
        if not ghostBoneID then continue end
        
        -- Get target pos/ang
        local targetPos, targetAng = ghost:GetBonePosition(ghostBoneID)
        
        if targetPos and targetAng then
            shadowparams.secondstoarrive = 0.05
            shadowparams.pos = targetPos
            shadowparams.angle = targetAng
            shadowparams.maxangular = 5000 * strength -- Increased force
            shadowparams.maxangulardamp = 500 * strength -- Increased damp
            shadowparams.maxspeed = 5000 * strength -- Increased force
            shadowparams.maxspeeddamp = 500 * strength -- Increased damp
            shadowparams.dampfactor = 0.8
            
            phys:Wake()
            phys:ComputeShadowControl(shadowparams)
        else
            -- print("[HG] Animator: Bone match failed for " .. tostring(boneName))
        end
    end
end
