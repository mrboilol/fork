hg.organism.module.goodmood = {}
local module = hg.organism.module.goodmood

local function GetGoodMood(org)
    org.goodmood = math.Clamp(tonumber(org.goodmood) or 1, 0, 1)
    return org.goodmood
end

local FEAR_SHIELD_COST = 0.35

local function GetGoodMoodGainMultiplier(org)
    local depression = math.Clamp(tonumber(org.depression) or 0, 0, 1)
    local panic = math.Clamp(tonumber(org.panicattack) or 0, 0, 1)
    local mul = 1
    if depression > 0.05 then mul = math.Clamp(1 - depression * 1.6, 0.05, 0.9) end
    if panic > 0.05 then mul = mul * math.Clamp(1 - panic * 1.5, 0, 1) end

    return mul
end

local function AbsorbFear(org)
    local fearadd = tonumber(org.fearadd) or 0
    if fearadd <= 0 or org.goodmood <= 0 then return end

    local absorbed = math.min(fearadd, org.goodmood / FEAR_SHIELD_COST)
    org.fearadd = fearadd - absorbed
    org.goodmood = math.max(org.goodmood - absorbed * FEAR_SHIELD_COST, 0)
end

module[1] = function(org)
    org.goodmood = 1.0
    org._goodmoodLostTime = 0
    org._fearDuration = 0
end

module[2] = function(owner, org, timeValue)
    local goodmood_add = 0
    GetGoodMood(org)
    AbsorbFear(org)

    -- Natural mood decay towards 0
    org.goodmood = math.Approach(org.goodmood, 0, timeValue / 420)

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

    -- Increase goodmood when in good condition.
    -- Reduced by 75% during penalty window
    if org.fear < 0.1 and org.pain < 10 then
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

    goodmood_add = goodmood_add * GetGoodMoodGainMultiplier(org)

    local depression = math.Clamp(tonumber(org.depression) or 0, 0, 1)
    if depression > 0.05 then
        goodmood_add = goodmood_add - timeValue * (0.015 + depression * 0.11)
    end

    local panic = math.Clamp(tonumber(org.panicattack) or 0, 0, 1)
    if panic > 0.05 then
        goodmood_add = goodmood_add - timeValue * (0.04 + panic * 0.16)
    end

    -- Decrease goodmood when in fear.
    -- Fear penalty scales with both current fear level and accumulated fear duration
    if org.fear > 0.2 then
        local fearDurationMultiplier = 1 + math.min((org._fearDuration or 0) / 60, 2) -- Up to 3x multiplier after 60 seconds of fear
        goodmood_add = goodmood_add - timeValue * 0.04 * org.fear * fearDurationMultiplier
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
        org.goodmood = math.Clamp(GetGoodMood(org) - (damage * 0.003), 0, 1)
    end
end)

-- Increase goodmood when overcoming fear.
hook.Add("Org Think", "GoodMood_OvercomeFear", function(owner, org, timeValue)
    if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
    GetGoodMood(org)

    -- Check if in penalty window (30 seconds after losing goodmood)
    local timeSinceLoss = CurTime() - (org._goodmoodLostTime or 0)
    local inPenaltyWindow = timeSinceLoss < 30

    -- Track previous fear for overcoming moments.
    local prevFear = org._prevFear or 0
    local currentFear = org.fear or 0

    -- If fear was high (>0.8) and is now low (<0.2), give goodmood boost
    -- Reduced by 75% during penalty window
    if prevFear > 0.8 and currentFear < 0.2 then
        local boost = inPenaltyWindow and 0.0375 or 0.15
        org.goodmood = math.Clamp(org.goodmood + boost * GetGoodMoodGainMultiplier(org), 0, 1)
    end

    org._prevFear = currentFear
end)

-- Increase goodmood when healing (bandaging wounds)
hook.Add("PostHeal", "GoodMood_OnHeal", function(wep, target, mode)
    if not IsValid(target) then return end
    local org = target.organism
    if not org then return end
    GetGoodMood(org)

    local owner = wep:GetOwner()
    if IsValid(owner) and owner == target then
        -- Self-healing gives more mood boost
        -- Reduced by 75% during penalty window
        local timeSinceLoss = CurTime() - (org._goodmoodLostTime or 0)
        local inPenaltyWindow = timeSinceLoss < 30
        local boost = inPenaltyWindow and 0.005 or 0.02
        org.goodmood = math.Clamp(org.goodmood + boost * GetGoodMoodGainMultiplier(org), 0, 1)
    elseif IsValid(owner) then
        -- Healing others gives mood boost to healer
        local healerOrg = owner.organism
        if healerOrg then
            GetGoodMood(healerOrg)
            local timeSinceLoss = CurTime() - (healerOrg._goodmoodLostTime or 0)
            local inPenaltyWindow = timeSinceLoss < 30
            local boost = inPenaltyWindow and 0.0025 or 0.01
            healerOrg.goodmood = math.Clamp(healerOrg.goodmood + boost * GetGoodMoodGainMultiplier(healerOrg), 0, 1)
        end
    end
end)
