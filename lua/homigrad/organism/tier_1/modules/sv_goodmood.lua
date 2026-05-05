hg.organism.module.goodmood = {}
local module = hg.organism.module.goodmood

module[1] = function(org)
    org.goodmood = 0
    org.lastkill = 0
end

module[2] = function(owner, org, timeValue)
    local goodmood_add = 0

    if org.despair < 0.1 and org.fear < 0.1 then
        goodmood_add = goodmood_add + timeValue * 0.01
    end

    if org.satiety > 80 and org.hydration > 80 then
        goodmood_add = goodmood_add + timeValue * 0.01
    end

    if (CurTime() - org.lastkill) < 30 then
        goodmood_add = goodmood_add + timeValue * 0.05
    end

    if org.pain < 10 then
        goodmood_add = goodmood_add + timeValue * 0.01
    end

    org.goodmood = math.Clamp(org.goodmood + goodmood_add, 0, 1)
    org.goodmood = math.Approach(org.goodmood, 0, timeValue / 180)
end

hook.Add("PlayerDeath", "GoodMood_PlayerDeath", function(victim, inflictor, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if attacker == victim then return end

    local org = attacker.organism
    if not org then return end

    org.lastkill = CurTime()
end)
