ActiveRagdollManager = ActiveRagdollManager or {}

local IsValid = IsValid
local timer_Simple = timer.Simple

ActiveRagdollManager.Config = {
    DefaultStrength = 2.5,
    DefaultModel = "models/Humans/Group02/male_06.mdl",
    DefaultAnim = "run_all",

    BoneList = {
        "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Spine1",
        "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Head1",
        "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot",
        "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot",
        "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
        "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand",
    }
}

local flexTable = {
    ["inner_raiser"] = 1.0,
    ["au1"] = 1.0,
    ["right_inner_raiser"] = 1.0,
    ["left_inner_raiser"] = 1.0,
    ["right_mouth_drop"] = 0.65,
    ["left_mouth_drop"] = 0.65,
    ["au15"] = 0.65,
    ["chin_raiser"] = 0.23,
    ["au17"] = 0.23,
    ["smile"] = 0.0,
    ["right_outer_raiser"] = 0.0,
    ["left_outer_raiser"] = 0.0,
    ["wrinkler"] = 0.0,
}

function ActiveRagdollManager.InitEntity(ent, dmgpos)
    if not IsValid(ent) or ent:IsMarkedForDeletion() then return end
    if ent:GetClass() ~= "prop_ragdoll" then return end
    
    if ActiveRagdoll and ActiveRagdoll.Get and ActiveRagdoll.Get(ent) then return end

    timer_Simple(0.05, function()
        if not IsValid(ent) or ent:IsMarkedForDeletion() then return end
        if ActiveRagdoll and ActiveRagdoll.Get and ActiveRagdoll.Get(ent) then return end

        local ar = ActiveRagdoll.new(ent, nil, dmgpos)
        if not ar then return end

        ar:SetStrength(ActiveRagdollManager.Config.DefaultStrength)
        ar:ApplyBoneList(ActiveRagdollManager.Config.BoneList)

        if DMS and DMS.Setup then DMS:Setup(ar) end
        
        if RagdollFaceAnimator then
            RagdollFaceAnimator:RegisterRagdoll(ent)
            RagdollFaceAnimator:SetFlexes(ent, flexTable)
        end

        if AnimatedHands and AnimatedHands.AddEntity then
            AnimatedHands:AddEntity(ent)
        end
    end)
end

function ActiveRagdollManager.Run(ent, dmgpos)
    ActiveRagdollManager.InitEntity(ent, dmgpos)
end