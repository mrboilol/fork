hg.organism.module.goodmood = {}
local module = hg.organism.module.goodmood

module[1] = function(org)
    org.goodmood = 1.0
    org._goodmoodLostTime = 0
    org._fearDuration = 0
end

module[2] = function(owner, org, timeValue)
    local goodmood_add = 0

    -- Natural mood decay towards 0
    org.goodmood = math.Approach(org.goodmood, 0, timeValue / 600)

    -- Track fear duration for cumulative penalty
    local fear = org.fear or 0
    if fear > 0.1 then
        org._fearDuration = (org._fearDuration or 0) + timeValue
    else
        org._fearDuration = math.max((org._fearDuration or 0) - timeValue * 0.5, 0)
    end

    -- Track when goodmood is lost (drops below 0.3)
    if (org.goodmood or 0) < 0.3 and (org._prevGoodMood or 1) >= 0.3 then
        org._goodmoodLostTime = CurTime()
    end
    org._prevGoodMood = org.goodmood

    -- Check if in penalty window (30 seconds after losing goodmood)
    local timeSinceLoss = CurTime() - (org._goodmoodLostTime or 0)
    local inPenaltyWindow = timeSinceLoss < 30

    -- Increase goodmood when in good condition (pristine, no fear/despair)
    -- Reduced by 75% during penalty window
    if org.despair < 0.1 and org.fear < 0.1 and org.pain < 10 then
        local multiplier = inPenaltyWindow and 0.25 or 1
        goodmood_add = goodmood_add + timeValue * 0.008 * multiplier
    end

    -- Good diet (satiety and hydration)
    -- Reduced by 75% during penalty window
    if org.satiety > 80 and org.hydration > 80 then
        local multiplier = inPenaltyWindow and 0.25 or 1
        goodmood_add = goodmood_add + timeValue * 0.006 * multiplier
    end

    -- Low pain
    -- Reduced by 75% during penalty window
    if org.pain < 5 then
        local multiplier = inPenaltyWindow and 0.25 or 1
        goodmood_add = goodmood_add + timeValue * 0.004 * multiplier
    end

    -- Good health (high blood, no bleeding)
    -- Reduced by 75% during penalty window
    if (org.blood or 5000) > 4500 and (org.bleed or 0) < 1 then
        local multiplier = inPenaltyWindow and 0.25 or 1
        goodmood_add = goodmood_add + timeValue * 0.005 * multiplier
    end

    -- Increase goodmood when on opioids/analgesia
    -- Reduced by 75% during penalty window
    if org.analgesia > 1 then
        local multiplier = inPenaltyWindow and 0.25 or 1
        goodmood_add = goodmood_add + timeValue * 0.007 * math.Clamp(org.analgesia, 0, 5) * multiplier
    end

    if org.painkiller > 1 then
        local multiplier = inPenaltyWindow and 0.25 or 1
        goodmood_add = goodmood_add + timeValue * 0.005 * math.Clamp(org.painkiller, 0, 5) * multiplier
    end

    -- Decrease goodmood when in fear or despair
    -- Fear penalty scales with both current fear level and accumulated fear duration
    if org.fear > 0.2 then
        local fearDurationMultiplier = 1 + math.min((org._fearDuration or 0) / 60, 2) -- Up to 3x multiplier after 60 seconds of fear
        goodmood_add = goodmood_add - timeValue * 0.02 * org.fear * fearDurationMultiplier
    end

    if org.despair > 0.2 then
        goodmood_add = goodmood_add - timeValue * 0.015 * org.despair
    end

    org.goodmood = math.Clamp(org.goodmood + goodmood_add, 0, 1)
end

-- Decrease goodmood when taking damage
hook.Add("HomigradDamage", "GoodMood_OnDamage", function(ply, dmgInfo, hitgroup, ent)
    if not IsValid(ply) then return end
    local org = ply.organism
    if not org then return end

    local damage = dmgInfo:GetDamage()
    if damage > 5 then
        org.goodmood = math.Clamp(org.goodmood - (damage * 0.002), 0, 1)
    end
end)

-- Increase goodmood when overcoming fear/despair
hook.Add("Org Think", "GoodMood_OvercomeFear", function(owner, org, timeValue)
    if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end

    -- Check if in penalty window (30 seconds after losing goodmood)
    local timeSinceLoss = CurTime() - (org._goodmoodLostTime or 0)
    local inPenaltyWindow = timeSinceLoss < 30

    -- Track previous fear/despair for overcoming moments
    local prevFear = org._prevFear or 0
    local prevDespair = org._prevDespair or 0
    local currentFear = org.fear or 0
    local currentDespair = org.despair or 0

    -- If fear was high (>0.8) and is now low (<0.2), give goodmood boost
    -- Reduced by 75% during penalty window
    if prevFear > 0.8 and currentFear < 0.2 then
        local boost = inPenaltyWindow and 0.0375 or 0.15
        org.goodmood = math.Clamp(org.goodmood + boost, 0, 1)
    end

    -- If despair was high (>0.7) and is now low (<0.2), give goodmood boost
    -- Reduced by 75% during penalty window
    if prevDespair > 0.7 and currentDespair < 0.2 then
        local boost = inPenaltyWindow and 0.05 or 0.2
        org.goodmood = math.Clamp(org.goodmood + boost, 0, 1)
    end

    org._prevFear = currentFear
    org._prevDespair = currentDespair
end)

-- Increase goodmood when healing (bandaging wounds)
hook.Add("PostHeal", "GoodMood_OnHeal", function(wep, target, mode)
    if not IsValid(target) then return end
    local org = target.organism
    if not org then return end

    local owner = wep:GetOwner()
    if IsValid(owner) and owner == target then
        -- Self-healing gives more mood boost
        -- Reduced by 75% during penalty window
        local timeSinceLoss = CurTime() - (org._goodmoodLostTime or 0)
        local inPenaltyWindow = timeSinceLoss < 30
        local boost = inPenaltyWindow and 0.005 or 0.02
        org.goodmood = math.Clamp(org.goodmood + boost, 0, 1)
    elseif IsValid(owner) then
        -- Healing others gives mood boost to healer
        local healerOrg = owner.organism
        if healerOrg then
            local timeSinceLoss = CurTime() - (healerOrg._goodmoodLostTime or 0)
            local inPenaltyWindow = timeSinceLoss < 30
            local boost = inPenaltyWindow and 0.0025 or 0.01
            healerOrg.goodmood = math.Clamp(healerOrg.goodmood + boost, 0, 1)
        end
    end

    -- Apply constraints based on current damage state when healing
    -- Constraints are applied on heal events and persist until next ragdoll
    if not (ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool()) then return end

    local ragdoll = target.FakeRagdoll
    if not IsValid(ragdoll) then return end

    local limbs = {"larm", "rarm", "lleg", "rleg"}
    for _, limb in ipairs(limbs) do
        local isAmputated = org[limb .. "amputated"]
        local isBroken = org[limb] and org[limb] >= 1
        local isDislocated = org[limb .. "dislocation"]

        if not isAmputated and (isBroken or isDislocated) then
            local segment = target.HG_FloppyPersistSeg and target.HG_FloppyPersistSeg[limb]
            hg.BreakLimb(ragdoll, limb, segment, isDislocated)
        end
    end

    -- Apply neck constraint if spine3 is broken
    if org.spine3 and org.spine3 > 0.75 and not org.headamputated then
        timer.Simple(0.1, function()
            if IsValid(ragdoll) and IsValid(target) then
                hg.BreakNeck(ragdoll, false)
            end
        end)
    end

    -- Apply spine constraints if thresholds are crossed
    if hg.BreakSpine then
        local fake1 = hg.organism and hg.organism.fake_spine1 or 1
        local fake2 = hg.organism and hg.organism.fake_spine2 or 1
        if (org.spine1 and org.spine1 >= fake1) or (org.pelvis and org.pelvis >= 1) then
            hg.BreakSpine(ragdoll, "spine1", false)
        end
        if org.spine2 and org.spine2 >= fake2 then
            hg.BreakSpine(ragdoll, "spine2", false)
        end
    end
end)

-- Good mood provides resilience (damage reduction)
hook.Add("ScalePlayerDamage", "GoodMood_Resilience", function(ply, hitgroup, dmgInfo)
    if not IsValid(ply) then return end
    local org = ply.organism
    if not org then return end

    local goodmood = math.Clamp(org.goodmood or 0, 0, 1)
    if goodmood > 0.3 then
        local resilience = (goodmood - 0.3) * 0.15 -- Up to 10.5% damage reduction at max goodmood
        dmgInfo:ScaleDamage(1 - resilience)
    end
end)
