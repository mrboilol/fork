local B = {}

function B:OnStart(ar)
    ar:PlayAnimation("drowning", 0.7, "models/AREAnims/model_anim.mdl")
end

function B:OnUpdate(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    local boneID = ragdoll:LookupBone("ValveBiped.Bip01_Head1")

    if boneID then
        local physBoneID = ragdoll:TranslateBoneToPhysBone(boneID)
        local phys = ragdoll:GetPhysicsObjectNum(physBoneID)

        if IsValid(phys) then
            local vel = phys:GetVelocity()
            phys:SetVelocityInstantaneous(Vector(vel.x, vel.y, -15))
        end
    end
end

DMS:RegisterBehavior("drowning", B)