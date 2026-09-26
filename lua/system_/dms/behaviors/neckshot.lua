-- scrapped

local B = {}

local function GetBonePhys(ragdoll, boneName)
    local boneID = ragdoll:LookupBone(boneName)
    if not boneID then return nil end
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phys) and ragdoll:TranslatePhysBoneToBone(i) == boneID then
            return phys
        end
    end
    return nil
end

function B:OnStart(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end
    
    local list = {  
        "ValveBiped.Bip01_Spine2",
        "ValveBiped.Bip01_R_Forearm",
        "ValveBiped.Bip01_L_Forearm",
        "ValveBiped.Bip01_R_Upperarm",
        "ValveBiped.Bip01_L_Upperarm",
        "ValveBiped.Bip01_Head1",
        "ValveBiped.Bip01_R_Hand",
        "ValveBiped.Bip01_L_Hand",  
        "ValveBiped.Bip01_R_Calf",
        "ValveBiped.Bip01_L_Calf",         
    }

    ar:ApplyBoneList(list)
    ar:PlayAnimation("drowning", 0.5, "models/AREAnims/model_anim.mdl")
    
    ar:SetStrength(5)
    ar.neckStrength = 5

    self.spinePhys = GetBonePhys(ragdoll, "ValveBiped.Bip01_Spine2")

    print("neckshot activated")
end

function B:OnUpdate(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    if ar.neckStrength and ar.neckStrength > 0 then
        ar.neckStrength = ar.neckStrength - (FrameTime() * 0.5)
        
        if ar.neckStrength < 0 then ar.neckStrength = 0 end
        ar:SetStrength(ar.neckStrength)
    end
end

function B:OnExit(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    ar:SetStrength(ActiveRagdollManager.Config.DefaultStrength)
    ar:ApplyBoneList(ActiveRagdollManager.Config.BoneList)
    self.spinePhys = nil
    ar.neckStrength = nil

    print("neckshot stop")
end

if DMS then DMS:RegisterBehavior("neckshot", B) end