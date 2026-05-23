--[[if SERVER then return end

local function GetMedicalTarget()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local tr = hg and hg.eyeTrace and hg.eyeTrace(ply) or nil
    local ent = tr and tr.Entity or nil

    if IsValid(ent) then
        if ent:IsRagdoll() and hg and hg.RagdollOwner then
            ent = hg.RagdollOwner(ent) or ent
        end

        if IsValid(ent) and ent:IsPlayer() and ent.organism then
            return ent
        end
    end

    return ply
end

local function RequestMedicalAmputation(ent, limb)
    if not IsValid(ent) then return end
    net.Start("hg_medical_minigame_request_amputation")
        net.WriteEntity(ent)
        net.WriteString(limb)
    net.SendToServer()
end

hook.Add("radialOptions", "zcity_delta_medical_amputation", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or not ply.organism or ply.organism.otrub then return end
    if not hg or not hg.radialOptions then return end

    local target = GetMedicalTarget() or ply
    local options = {
        {
            [1] = function()
                RequestMedicalAmputation(target, "larm")
            end,
            [2] = "Amputate Left Arm"
        },
        {
            [1] = function()
                RequestMedicalAmputation(target, "rarm")
            end,
            [2] = "Amputate Right Arm"
        },
        {
            [1] = function()
                RequestMedicalAmputation(target, "lleg")
            end,
            [2] = "Amputate Left Leg"
        },
        {
            [1] = function()
                RequestMedicalAmputation(target, "rleg")
            end,
            [2] = "Amputate Right Leg"
        }
    }

    hg.radialOptions[#hg.radialOptions + 1] = {
        [1] = function()
            if hg and hg.CreateRadialMenu then
                hg.CreateRadialMenu(options)
                return -1
            end
        end,
        [2] = "Medical"
    }
end)]]
