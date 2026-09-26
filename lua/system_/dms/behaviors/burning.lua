local B = {}

local BurntColor = Color(50, 50, 50)
local LerpSpeed = 0.5

local cv_calf_force = GetConVar("burn_calf_force")
local cv_arm_force  = GetConVar("burn_arm_force")
local cv_strength   = GetConVar("burn_strength")

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
        "ValveBiped.Bip01_R_Thigh",
        "ValveBiped.Bip01_L_Thigh"       
    }

    if ar.PlayAnimation then
        ar:PlayAnimation("idleonfire", 1, "models/Police.mdl")
    end

    ar:ApplyBoneList(list)
    
    local strength = cv_strength and cv_strength:GetFloat() or 4.5
    ar:SetStrength(strength)
    
    self.burnStartTime = CurTime()
    self.ragdoll = ragdoll
    
    if not ragdoll:IsOnFire() then
        ragdoll:Ignite(30, 0)
    end
end

function B:OnUpdate(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end
    
    local dt = FrameTime()
    local curTime = CurTime()
    local entSeed = ragdoll:EntIndex()

    local currentColor = ragdoll:GetColor()
    local newColor = Color(
        Lerp(dt * LerpSpeed, currentColor.r, BurntColor.r),
        Lerp(dt * LerpSpeed, currentColor.g, BurntColor.g),
        Lerp(dt * LerpSpeed, currentColor.b, BurntColor.b),
        255
    )
    ragdoll:SetColor(newColor)

    local calves = {"ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_L_Calf"}
    local calfForce = cv_calf_force and cv_calf_force:GetFloat() or 100

    for _, boneName in ipairs(calves) do
        local phys, physID = UniversalBone.FindBone(ragdoll, boneName)
        if IsValid(phys) then
            local speed = 8
            local movement = math.sin(curTime * speed + (physID * 0.7))
            local finalMovement = movement * calfForce

            local localRotationAxis = Vector(0, 0, finalMovement)
            local worldTorque = phys:LocalToWorldVector(localRotationAxis)

            phys:ApplyTorqueCenter(worldTorque)
            phys:AddAngleVelocity(phys:GetAngleVelocity() * -0.1)
        end
    end

    local baseArmForce = cv_arm_force and cv_arm_force:GetFloat() or 57
    local armForce = baseArmForce + (util.SharedRandom("ArmForce" .. entSeed, -10, 10))
    
    local arms = {
        "ValveBiped.Bip01_R_Upperarm", "ValveBiped.Bip01_L_Upperarm",
        "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Forearm"
    }

    for _, boneName in ipairs(arms) do
        local phys, physID = UniversalBone.FindBone(ragdoll, boneName)
        if IsValid(phys) then
            local indivSpeed = 7 + (util.SharedRandom("ArmSpeed" .. physID .. entSeed, -1.5, 1.5))
            local seed = (physID * 2) + entSeed 
            
            local upDown = math.sin(curTime * indivSpeed + seed)
            local sideSwing = math.cos(curTime * indivSpeed + seed)

            local torqueDir = Vector(0, upDown * armForce, (sideSwing - 0.5) * armForce)
            local worldTorque = phys:LocalToWorldVector(torqueDir)
            
            phys:ApplyTorqueCenter(worldTorque)
            phys:AddAngleVelocity(phys:GetAngleVelocity() * -0.15)
        end
    end
end

function B:OnExit(ar)
    ar:SetStrength(ActiveRagdollManager.Config.DefaultStrength)
    ar:ApplyBoneList(ActiveRagdollManager.Config.BoneList)
end

if DMS then DMS:RegisterBehavior("burning", B) end