local B = {}

local CrawlSpeed = 32

function B:OnStart(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    ar:SetStrength(4.25)
    ar:PlayAnimation("Crawling", 1, "models/AREAnims/model_anim.mdl")
    
    if UniversalBone and UniversalBone.FindBone then
        local phys, physID = UniversalBone.FindBone(ragdoll, "ValveBiped.Bip01_Spine2")
        ar.spinePhys = phys
    end

    ar.headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")

    ar.OriginalDamping = {}

    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            local linear, angular = phys:GetDamping()
            ar.OriginalDamping[i] = {lin = linear, ang = angular}

            phys:SetMaterial("flesh") 
            phys:SetDamping(0.1, 0.1) 
            phys:Wake()
        end
    end
end

function B:OnUpdate(ar)
    local ragdoll = ar.ragdoll
    local phys = ar.spinePhys
    if not IsValid(ragdoll) or not IsValid(phys) then return end

    local headForward = Vector(1, 0, 0)
    if ar.headBone then
        local headMatrix = ragdoll:GetBoneMatrix(ar.headBone)
        if headMatrix then 
            headForward = headMatrix:GetAngles():Forward() 
        end
    end

    local crawlDir = Vector(headForward.x, headForward.y, 0)
    crawlDir:Normalize()

    local currentVel = phys:GetVelocity()
    local targetVel = crawlDir * CrawlSpeed
    
    phys:SetVelocity(Vector(targetVel.x, targetVel.y, currentVel.z))
end

function B:OnExit(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    ar:SetStrength(ActiveRagdollManager.Config.DefaultStrength)
    ar:ApplyBoneList(ActiveRagdollManager.Config.BoneList)
    
    if ar.OriginalDamping then
        for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
            local phys = ragdoll:GetPhysicsObjectNum(i)
            local original = ar.OriginalDamping[i]
            
            if IsValid(phys) and original then
                phys:SetDamping(original.lin, original.ang)
            end
        end
    end

    ar.spinePhys = nil
    ar.headBone = nil
    ar.OriginalDamping = nil
end

DMS:RegisterBehavior("crawling", B)