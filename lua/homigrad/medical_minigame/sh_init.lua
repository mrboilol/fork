if SERVER then
    util.AddNetworkString("hg_medical_minigame_start")
    util.AddNetworkString("hg_medical_minigame_progress")
    util.AddNetworkString("hg_medical_minigame_finish")
    util.AddNetworkString("hg_medical_minigame_cancel")
    util.AddNetworkString("hg_medical_minigame_bandage_state")
    util.AddNetworkString("hg_medical_minigame_request_amputation")
    util.AddNetworkString("hg_medical_minigame_tourniquet_pain")
    util.AddNetworkString("hg_medical_minigame_dislocation_pain")

    util.AddNetworkString("zcity_delta_moodles_extra")
    util.AddNetworkString("zcity_delta_death_report")
    util.AddNetworkString("zcity_delta_death_respawn")
end

hg.MedicalMinigame = hg.MedicalMinigame or {}
hg.MedicalMinigame.RequiredTurns = 6 -- Increased for a longer minigame

local function GetFallbackArmEffectiveness(ply, limb)
    local org = IsValid(ply) and ply.organism
    if not org then return 1 end

    local hand = limb == "larm" and "lhand" or "rhand"
    if org[limb .. "amputated"] or org[limb .. "upamputated"] or org[hand .. "amputated"] then
        return 0
    end

    local damage = math.Clamp(tonumber(org[limb]) or 0, 0, 1)
    local effectiveness = damage < 0.25 and 1 or Lerp((damage - 0.25) / 0.75, 0.82, 0.12)
    if org[limb .. "dislocation"] or org[limb .. "dislocated"] then
        effectiveness = math.min(effectiveness, 0.18)
    end

    return math.Clamp(effectiveness, 0, 1)
end

function hg.MedicalMinigame.GetArmEffectiveness(ply, limb)
    if hg.GetArmEffectiveness then
        return hg.GetArmEffectiveness(ply, limb)
    end

    return GetFallbackArmEffectiveness(ply, limb)
end


-- Medical actions are right-hand dominant, but use the stronger remaining arm.
-- A damaged second arm still matters because wrapping and stabilizing a patient
-- are two-handed tasks even when the visible item is held in only one hand.
function hg.MedicalMinigame.GetPreferredArm(ply)
    local right = hg.MedicalMinigame.GetArmEffectiveness(ply, "rarm")
    local left = hg.MedicalMinigame.GetArmEffectiveness(ply, "larm")
    if right <= 0 and left <= 0 then return nil, 0, 0 end

    if left > right then
        return "left", left, right
    end

    return "right", right, left
end

function hg.MedicalMinigame.GetArmSpeedMultiplier(ply)
    local _, best, support = hg.MedicalMinigame.GetPreferredArm(ply)
    if best <= 0 then return 0 end

    local speed = 0.5 + best * 0.35 + support * 0.15
    if support <= 0 then
        speed = speed * 0.82
    end

    return math.Clamp(speed, 0.25, 1)
end

function hg.MedicalMinigame.GetBandageEaseMultiplier(ply)
    local org = IsValid(ply) and ply.organism
    local goodmood = org and math.Clamp(tonumber(org.goodmood) or 0, 0, 1) or 0

    return 1 + goodmood * 0.35
end
