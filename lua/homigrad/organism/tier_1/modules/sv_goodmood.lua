hg.organism.module.goodmood = {}
local module = hg.organism.module.goodmood

module[1] = function(org)
    org.goodmood = 0
    org.lastkill = 0
end

module[2] = function(owner, org, timeValue)
    local goodmood_add = 0

    -- Increase goodmood when in good condition
    if org.despair < 0.1 and org.fear < 0.1 then
        goodmood_add = goodmood_add + timeValue * 0.015
    end

    if org.satiety > 80 and org.hydration > 80 then
        goodmood_add = goodmood_add + timeValue * 0.015
    end

    if org.pain < 10 then
        goodmood_add = goodmood_add + timeValue * 0.01
    end

    -- Increase goodmood when on opioids/analgesia
    if org.analgesia > 1 then
        goodmood_add = goodmood_add + timeValue * 0.02 * math.Clamp(org.analgesia, 0, 5)
    end

    if org.painkiller > 1 then
        goodmood_add = goodmood_add + timeValue * 0.015 * math.Clamp(org.painkiller, 0, 5)
    end

    -- Decrease goodmood when in fear or despair
    if org.fear > 0.2 then
        goodmood_add = goodmood_add - timeValue * 0.03 * org.fear
    end

    if org.despair > 0.2 then
        goodmood_add = goodmood_add - timeValue * 0.04 * org.despair
    end

    -- Decrease goodmood when recently killed someone (guilt)
    if (CurTime() - org.lastkill) < 60 then
        local guiltFactor = 1 - ((CurTime() - org.lastkill) / 60)
        goodmood_add = goodmood_add - timeValue * 0.1 * guiltFactor
    end

    org.goodmood = math.Clamp(org.goodmood + goodmood_add, 0, 1)
    org.goodmood = math.Approach(org.goodmood, 0, timeValue / 240)
end

hook.Add("PlayerDeath", "GoodMood_PlayerDeath", function(victim, inflictor, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if attacker == victim then return end

    local org = attacker.organism
    if not org then return end

    org.lastkill = CurTime()
end)

-- Decrease goodmood when taking damage
hook.Add("HomigradDamage", "GoodMood_OnDamage", function(ply, dmgInfo, hitgroup, ent)
    if not IsValid(ply) then return end
    local org = ply.organism
    if not org then return end

    local damage = dmgInfo:GetDamage()
    if damage > 5 then
        org.goodmood = math.Clamp(org.goodmood - (damage * 0.005), 0, 1)
    end
end)

-- Increase goodmood when healing (bandaging wounds)
hook.Add("PostHeal", "GoodMood_OnHeal", function(wep, target, mode)
    if not IsValid(target) then return end
    local org = target.organism
    if not org then return end

    local owner = wep:GetOwner()
    if IsValid(owner) and owner == target then
        -- Self-healing gives more mood boost
        org.goodmood = math.Clamp(org.goodmood + 0.05, 0, 1)
    elseif IsValid(owner) then
        -- Healing others gives mood boost to healer
        local healerOrg = owner.organism
        if healerOrg then
            healerOrg.goodmood = math.Clamp(healerOrg.goodmood + 0.03, 0, 1)
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
