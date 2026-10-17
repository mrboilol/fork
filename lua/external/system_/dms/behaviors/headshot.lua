local B = {}

local REACTION_LIMP = 1
local REACTION_STIFFEN = 2
local REACTION_DROP = 3
local REACTION_DECEREBRATE = 4

function B:OnStart(ar)
    math.randomseed(os.time() + CurTime())
    
    ar.ReactionType = math.random(1, 4) 
    
    ar.HeadshotStartTime = CurTime()
    ar.DeathWaitTime = GetConVar("ar_hs_death_delay"):GetFloat()
    
    local ragdoll = ar.ragdoll

    if IsValid(ragdoll) then
        local phys = nil
        local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")

        if headBone then
            phys = ragdoll:GetPhysicsObjectNum(ragdoll:TranslateBoneToPhysBone(headBone))
        end

        if not IsValid(phys) then
            phys = ragdoll:GetPhysicsObjectNum(ragdoll:GetPhysicsObjectCount() - 1)
        end

        if IsValid(phys) then
            local ang = phys:GetAngles()
            
            local vecBack = ang:Forward() * -1
            local vecRight = ang:Right() * math.Rand(-1, 1)
            local vecUp = ang:Up() * math.Rand(-2, 2)

            local finalDir = (vecBack + vecRight + vecUp)
            finalDir:Normalize()

            local force = GetConVar("ar_headshot_force"):GetFloat()
            local torque = GetConVar("ar_headshot_torque"):GetFloat()

            phys:ApplyForceCenter(finalDir * force)
            local torqueDir = finalDir:Cross(ang:Forward()) 
            phys:AddAngleVelocity(torqueDir * torque)
        end
    end

    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            phys:SetDamping(0, 0)
        end
    end

    if ar.ReactionType == REACTION_LIMP then
        local baseTime = GetConVar("ar_hs_limp_time"):GetFloat()
        ar.HeadshotDuration = math.Rand(baseTime * 0.8, baseTime * 1.2)
        ar.StartStrength = GetConVar("ar_hs_limp_str"):GetFloat()
        ar:SetStrength(ar.StartStrength)
        ar:PlayAnimation("StuntWall", 1, "models/AREAnims/model_anim.mdl")

    elseif ar.ReactionType == REACTION_STIFFEN then
        local baseTime = GetConVar("ar_hs_stiff_time"):GetFloat()
        ar.HeadshotDuration = math.Rand(baseTime * 0.8, baseTime * 1.2)
        ar.StartStrength = GetConVar("ar_hs_stiff_str"):GetFloat()
        ar:SetStrength(ar.StartStrength)
        ar:PlayAnimation("NewHeadshot", 1, "models/AREAnims/model_anim.mdl")

        timer.Simple(0.35, function()
            if IsValid(ragdoll) then
                RagdollStiffener.Apply(ragdoll, 5)
            end
        end)

    elseif ar.ReactionType == REACTION_DROP then
        ar.HeadshotDuration = 0
        ar.StartStrength = 0
        ar:SetStrength(0)

    elseif ar.ReactionType == REACTION_DECEREBRATE then
        ar.HeadshotDuration = ar.DeathWaitTime 
        ar.StartStrength = 4
        ar:SetStrength(4)
        ar:PlayAnimation("Decerebrate", 0.5, "models/AREAnims/model_anim.mdl")
    end

        
    if RagdollFaceAnimator then RagdollFaceAnimator:DeathRelax(ragdoll) end
end

function B:OnUpdate(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    local elapsed = CurTime() - ar.HeadshotStartTime

    if elapsed <= ar.HeadshotDuration then
        local progress = elapsed / ar.HeadshotDuration
        
        if ar.ReactionType == REACTION_LIMP or ar.ReactionType == REACTION_STIFFEN then
            local currentStrength = Lerp(progress, ar.StartStrength, 0)
            ar:SetStrength(currentStrength)

        elseif ar.ReactionType == REACTION_DROP then
            ar:SetStrength(0)

        elseif ar.ReactionType == REACTION_DECEREBRATE then
            ar:SetStrength(4)
        end
        
        return
    end

    ar:SetStrength(0)

    if elapsed > (ar.HeadshotDuration + ar.DeathWaitTime) then
        if Health and not Health.dead then
            Health:Die()
            RagdollStiffener.Remove(ragdoll)
        end
    end
end

DMS:RegisterBehavior("headshot", B)