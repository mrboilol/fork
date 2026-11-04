if SERVER then
    util.AddNetworkString("hg_medical_minigame_start")
    util.AddNetworkString("hg_medical_minigame_progress")
    util.AddNetworkString("hg_medical_minigame_finish")
    util.AddNetworkString("hg_medical_minigame_cancel")
    util.AddNetworkString("hg_medical_minigame_bandage_state")
    util.AddNetworkString("hg_medical_minigame_bandage_target")
    util.AddNetworkString("hg_medical_minigame_bandage_cycle")
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

local STRUGGLE_ARM_MAX = 0.1

local function GetStruggleArmEffectiveness(ply, limb)
    local org = IsValid(ply) and ply.organism
    if not org then return 0 end

    local hand = limb == "larm" and "lhand" or "rhand"
    if org[limb .. "amputated"] or org[limb .. "upamputated"] or org[hand .. "amputated"] then
        return 0
    end

    local up, down = 1, 1
    if hg.GetLimbSegmentDamage then
        up, down = hg.GetLimbSegmentDamage(org, limb)
    end
    local dislocations = (org[limb .. "_up_disl"] and 1 or 0) + (org[limb .. "_down_disl"] and 1 or 0)
    if dislocations == 0 and (org[limb .. "dislocation"] or org[limb .. "dislocated"]) then dislocations = 1 end

    return math.max(STRUGGLE_ARM_MAX - (up + down) * 0.02 - dislocations * 0.025, 0.01)
end

function hg.MedicalMinigame.GetArmEffectiveness(ply, limb)
    local effectiveness = hg.GetArmEffectiveness and hg.GetArmEffectiveness(ply, limb) or GetFallbackArmEffectiveness(ply, limb)
    if effectiveness > 0 then return effectiveness end

    return GetStruggleArmEffectiveness(ply, limb)
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

    if best < 0.15 then
        speed = Lerp(best / 0.15, 0.25, speed)
    end

    return math.Clamp(speed, 0.25, 1)
end

function hg.MedicalMinigame.GetBandageEaseMultiplier(ply)
    return 1.5
end
