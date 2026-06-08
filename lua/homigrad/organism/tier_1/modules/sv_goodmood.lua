hg.organism.module.goodmood = {}
local module = hg.organism.module.goodmood

module[1] = function(org)
    org.goodmood = 1.0
end

module[2] = function(owner, org, timeValue)
    local goodmood_add = 0

    -- Natural mood decay towards 0
    org.goodmood = math.Approach(org.goodmood, 0, timeValue / 600)

    -- Increase goodmood when in good condition (pristine, no fear/despair)
    if org.despair < 0.1 and org.fear < 0.1 and org.pain < 10 then
        goodmood_add = goodmood_add + timeValue * 0.008
    end

    -- Good diet (satiety and hydration)
    if org.satiety > 80 and org.hydration > 80 then
        goodmood_add = goodmood_add + timeValue * 0.006
    end

    -- Low pain
    if org.pain < 5 then
        goodmood_add = goodmood_add + timeValue * 0.004
    end

    -- Good health (high blood, no bleeding)
    if (org.blood or 5000) > 4500 and (org.bleed or 0) < 1 then
        goodmood_add = goodmood_add + timeValue * 0.005
    end

    -- Increase goodmood when on opioids/analgesia
    if org.analgesia > 1 then
        goodmood_add = goodmood_add + timeValue * 0.007 * math.Clamp(org.analgesia, 0, 5)
    end

    if org.painkiller > 1 then
        goodmood_add = goodmood_add + timeValue * 0.005 * math.Clamp(org.painkiller, 0, 5)
    end

    -- Decrease goodmood when in fear or despair
    if org.fear > 0.2 then
        goodmood_add = goodmood_add - timeValue * 0.01 * org.fear
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

    -- Track previous fear/despair for overcoming moments
    local prevFear = org._prevFear or 0
    local prevDespair = org._prevDespair or 0
    local currentFear = org.fear or 0
    local currentDespair = org.despair or 0

    -- If fear was high (>0.8) and is now low (<0.2), give goodmood boost
    if prevFear > 0.8 and currentFear < 0.2 then
        org.goodmood = math.Clamp(org.goodmood + 0.15, 0, 1)
    end

    -- If despair was high (>0.7) and is now low (<0.2), give goodmood boost
    if prevDespair > 0.7 and currentDespair < 0.2 then
        org.goodmood = math.Clamp(org.goodmood + 0.2, 0, 1)
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
        org.goodmood = math.Clamp(org.goodmood + 0.02, 0, 1)
    elseif IsValid(owner) then
        -- Healing others gives mood boost to healer
        local healerOrg = owner.organism
        if healerOrg then
            healerOrg.goodmood = math.Clamp(healerOrg.goodmood + 0.01, 0, 1)
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
