hg.organism.module.goodmood = {}
local module = hg.organism.module.goodmood

local function GetGoodMood(org)
    org.goodmood = math.Clamp(tonumber(org.goodmood) or 1, 0, 1)
    return org.goodmood
end

local FEAR_SHIELD_COST = 0.35
local INJURY_CAP_DRAIN = 0.1
local WOUND_THOUGHT_DEPRESSION_MAX = 0.25
local WOUND_THOUGHT_MIN = 30
local WOUND_THOUGHT_MAX = 60
local WOUND_THOUGHT_ESCALATE_DELAY = 3
local WOUND_THOUGHT_DURATION = 5
local INJURY_THOUGHT_SUPPRESS = 30
local LIMBS = {"rarm", "larm", "rleg", "lleg"}
local BLEED_CONCERN_RATE = 1.5
local BLEED_CONCERN_BLOOD = 4500
local BLEED_WORSEN_DELTA = 0.75
local BLEED_DYING_BLOOD = 3200

local CHRONIC_INJURY_MIN = 0.25
local CHRONIC_RISE_TIME = 60
local CHRONIC_FALL_TIME = 90
local CHRONIC_TREATED_RISE_MUL = 0.25
local CHRONIC_HAPPINESS_PENALTY = 0.6
local CHRONIC_IRRITABLE_START = 0.3
local CHRONIC_ANGER_RATE = 0.014
local CHRONIC_ANGER_CAP = 0.2
local CHRONIC_DEPRESSION_START = 0.6
local CHRONIC_DEPRESSION_RATE = 0.006
local CHRONIC_DEPRESSION_CAP = 0.2
local PAIN_FOCUS = {
    start = 40,
    full = 90,
    angerDrain = 0.12,
    riseTime = 40,
    fallTime = 150,
    depressionStart = 0.4,
    depressionRate = 0.01,
    depressionCap = 0.25,
}

local WOUND_RANK = {hurt = 1, broken = 2, bloodloss = 3, bleeding = 3, bleedingBad = 4, dying = 5}
local WOUND_LINES = {
	hurt = {
		"Something's starting to hurt bad...",
		"This pain is starting to upset me.",
		"My fucking wounds ache...",
		"Everything hurts a little...",
		"Ugh.. It hurts bad...",
		"God, everything aches.",
	},
	broken = {
		"Something's still broken...",
		"I can still feel it grinding.",
		"It aches every time I move my broken limb.",
		"Jesus.. I can see it bend in the wrong way...",
		"I think I see the bone sticking out...",
	},
	bleeding = {
		"Oh.. im.. bleeding...",
		"God... I can feel my blood trickling down my body.",
		"Im fucking bleeding out of my wounds...",
		"I can feel blood soaking up my clothes...",
		"Shit, im bleeding...",
		"I feel blood trickling down my wounds.",
	},
	bleedingBad = {
		"Im losing an awful lot of blood...",
		"Why isnt the blood stopping...",
		"Theres a puddle of blood forming...",
		"I cant stop bleeding for some reason...",
		"My fucking body is covered in blood.",
		"Im not supposed to lose this much blood...",
		"I should really stop the bleeding somehow...",
	},
	dying = {
		"I think im dying...",
		"I cant feel my hands anymore...",
		"Everything's fading... Im not going to make it...",
		"Somebody.. please.. I dont want to die...",
		"Im so cold.. this is it, isnt it...",
		"I cant keep my eyes open...",
		"Theres too much blood.. I think this is the end...",
	},
	bloodloss = {
		"Im starting to feel dizzy...",
		"My insides feel heavier...",
		"I think I lost too much blood...",
		"Why am I so tired all of a sudden...",
		"Everything's going quiet and cold...",
	},
}

local function Clamp01(value)
    return math.Clamp(tonumber(value) or 0, 0, 1)
end

local function GetGoodMoodGainMultiplier(org)
    local depression = math.Clamp(tonumber(org.depression) or 0, 0, 1)
    local panic = math.Clamp(tonumber(org.panicattack) or 0, 0, 1)
    local mul = 1
    if depression > 0.05 then mul = math.Clamp(1 - depression * 1.6, 0.05, 0.9) end
    if panic > 0.05 then mul = mul * math.Clamp(1 - panic * 1.5, 0, 1) end

    return mul * (1 - Clamp01(org.chronicStrain) * CHRONIC_HAPPINESS_PENALTY)
end

local function AbsorbFear(org)
    local fearadd = tonumber(org.fearadd) or 0
    if fearadd <= 0 or org.goodmood <= 0 then return end

    local absorbed = math.min(fearadd, org.goodmood / FEAR_SHIELD_COST)
    org.fearadd = fearadd - absorbed
    org.goodmood = math.max(org.goodmood - absorbed * FEAR_SHIELD_COST, 0)
end

local function isLimbBroken(org)
    for _, limb in ipairs(LIMBS) do
        if org[limb .. "dislocation"] or (hg.IsLimbFractured and hg.IsLimbFractured(org, limb)) then return true end
    end

    return false
end

local function getInjury(org)
    local pain = tonumber(org.pain) or 0
    local bleed = tonumber(org.bleed) or 0
    local blood = tonumber(org.blood) or 5000
    local bleeding = bleed > 0.2
    local broken = isLimbBroken(org)

    local severity = math.max(
        math.Clamp((pain - 15) / 85, 0, 1) * 0.7,
        bleeding and math.Clamp(0.3 + bleed / 8, 0, 0.85) or 0,
        math.Clamp((4700 - blood) / 2200, 0, 1) * 0.95,
        (tonumber(org.internalBleed) or 0) > 0.5 and 0.4 or 0,
        broken and 0.3 or 0
    )

    if not bleeding then
        org.bleedTrendBase = nil
    elseif not org.bleedTrendBase or bleed < org.bleedTrendBase then
        org.bleedTrendBase = bleed
    end

    local base = org.bleedTrendBase or bleed
    local worsening = bleeding and bleed >= base * 2 and bleed - base >= BLEED_WORSEN_DELTA
    local concerning = bleeding and (bleed >= BLEED_CONCERN_RATE or (tonumber(org.arterialBleed) or 0) > 0 or blood < BLEED_CONCERN_BLOOD or worsening)

    local kind = concerning and blood < BLEED_DYING_BLOOD and "dying"
        or concerning and (bleed > 4 or blood < 3800) and "bleedingBad"
        or concerning and "bleeding"
        or blood < 4200 and "bloodloss"
        or broken and "broken"
        or pain > 25 and "hurt"
        or nil

    return severity, kind
end

local function updateWoundThoughts(owner, org, kind)
    local rank = kind and WOUND_RANK[kind] or 0
    local shown = org.woundThoughtRank or 0
    if rank <= shown then
        org.woundThoughtEscalate = nil
        if rank < shown then org.woundThoughtRank = rank end
    end
    if rank == 0 or org.otrub or not hg.organism.EmotionThought then return end
    local now = CurTime()
    if rank > shown and rank <= WOUND_RANK.broken and now - (org.injuryThoughtTime or -math.huge) < INJURY_THOUGHT_SUPPRESS then
        org.woundThoughtEscalate = nil
        org.woundThoughtRank = rank
        org.woundThoughtNext = now + math.Rand(WOUND_THOUGHT_MIN, WOUND_THOUGHT_MAX)
        return
    end
    if (tonumber(org.depression) or 0) >= WOUND_THOUGHT_DEPRESSION_MAX then return end
    if (tonumber(org.blood) or 5000) <= (hg.organism.BLEEDOUT_START_BLOOD or 2500) then return end

    local K = hg.PsycheCombat
    if now - (owner.hgLastEmotionTime or 0) < (K and K.thoughtGlobalCooldown or 8) then return end

    if rank > shown then
        org.woundThoughtEscalate = org.woundThoughtEscalate or now + WOUND_THOUGHT_ESCALATE_DELAY
        if now < org.woundThoughtEscalate then return end
    elseif now < (org.woundThoughtNext or 0) then
        return
    end

    org.woundThoughtEscalate = nil
    org.woundThoughtRank = rank
    org.woundThoughtNext = now + math.Rand(WOUND_THOUGHT_MIN, WOUND_THOUGHT_MAX)
    if kind == "bleeding" or kind == "bleedingBad" or kind == "dying" then org.bleedTrendBase = tonumber(org.bleed) or org.bleedTrendBase end
    local list = WOUND_LINES[kind]
    hg.organism.EmotionThought(owner, list[math.random(#list)], WOUND_THOUGHT_DURATION, "wound_" .. kind)
end

function hg.organism.ShieldEmotion(org, amount, cost)
    if not org or not isnumber(amount) or amount <= 0 then return 0 end
    local goodmood = GetGoodMood(org)
    if goodmood <= 0 then return amount end

    local absorbed = math.min(amount, goodmood / cost)
    org.goodmood = math.max(goodmood - absorbed * cost, 0)

    return amount - absorbed
end

function hg.organism.AddHappiness(org, amount)
    if not org or not isnumber(amount) or amount <= 0 then return end
    if org.buddyNear and hg.Buddy then amount = amount * hg.Buddy.Config.happinessMul end
    amount = amount * (1 - Clamp01(org.chronicStrain) * CHRONIC_HAPPINESS_PENALTY)
    amount = amount * (1 - Clamp01(org.anger) * hg.PsycheCombat.angerHappinessBlock)
    if CurTime() < (org.betaBlockerUntil or 0) then amount = amount * hg.PsycheCombat.betaBlockMul end
    if amount <= 0 then return end

    local depression = math.Clamp(tonumber(org.depression) or 0, 0, 1)
    local eased = math.min(depression, amount)
    org.depression = depression - eased
    org.depressionadd = math.max((tonumber(org.depressionadd) or 0) - amount, 0)
    amount = amount - eased

    local panic = math.max(tonumber(org.panicattackadd) or 0, 0)
    local calmed = math.min(panic, amount)
    org.panicattackadd = panic - calmed
    amount = amount - calmed

    org.goodmood = math.Clamp(GetGoodMood(org) + amount, 0, 1)
end

module[1] = function(org)
    org.goodmood = 1.0
    org._goodmoodLostTime = 0
    org._fearDuration = 0
    org.woundThoughtRank = nil
    org.woundThoughtNext = nil
    org.woundThoughtEscalate = nil
    org.bleedTrendBase = nil
    org.chronicStrain = 0
    org.painExposure = 0
end

local function updateChronicStrain(owner, org, timeValue, injury)
    local strain = Clamp01(org.chronicStrain)
    if injury >= CHRONIC_INJURY_MIN and not org.otrub then
        local treated = math.Clamp(math.max(tonumber(org.analgesia) or 0, (tonumber(org.painkiller) or 0) * 0.4), 0, 1)
        strain = strain + timeValue / CHRONIC_RISE_TIME * injury * Lerp(treated, 1, CHRONIC_TREATED_RISE_MUL)
    else
        strain = strain - timeValue / CHRONIC_FALL_TIME
    end
    org.chronicStrain = Clamp01(strain)

    local angryCvar = GetConVar("hg_angry")
    if (not angryCvar or angryCvar:GetBool()) and org.chronicStrain >= CHRONIC_IRRITABLE_START and (org.anger or 0) < CHRONIC_ANGER_CAP then
        org.anger = math.min((org.anger or 0) + timeValue * CHRONIC_ANGER_RATE * org.chronicStrain, CHRONIC_ANGER_CAP)
    end

    if org.chronicStrain >= CHRONIC_DEPRESSION_START and (tonumber(org.depression) or 0) < CHRONIC_DEPRESSION_CAP and hg.organism.AddDepression then
        local weight = (org.chronicStrain - CHRONIC_DEPRESSION_START) / (1 - CHRONIC_DEPRESSION_START)
        hg.organism.AddDepression(org, timeValue * CHRONIC_DEPRESSION_RATE * weight)
    end
end

local function updatePainFocus(org, timeValue)
    local K = PAIN_FOCUS
    local pain = tonumber(org.pain) or 0
    local exposure = Clamp01(org.painExposure)
    local severity = math.Clamp((pain - K.start) / (K.full - K.start), 0, 1)

    if severity > 0 and not org.otrub then
        exposure = exposure + timeValue / K.riseTime * severity
        local anger = tonumber(org.anger) or 0
        if anger > 0 then
            org.anger = math.max(anger - timeValue * K.angerDrain * severity, 0)
        end
    else
        exposure = exposure - timeValue / K.fallTime
    end
    org.painExposure = Clamp01(exposure)

    if org.painExposure >= K.depressionStart and (tonumber(org.depression) or 0) < K.depressionCap and hg.organism.AddDepression then
        local weight = (org.painExposure - K.depressionStart) / (1 - K.depressionStart)
        hg.organism.AddDepression(org, timeValue * K.depressionRate * weight, "pain")
    end
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

    local injury, woundKind = getInjury(org)
    updateChronicStrain(owner, org, timeValue, injury)
    updatePainFocus(org, timeValue)
    local cap = 1 - injury
    if goodmood_add > 0 then
        goodmood_add = math.min(goodmood_add, math.max(cap - org.goodmood, 0))
    end

    org.goodmood = math.Clamp(org.goodmood + goodmood_add, 0, 1)
    if org.goodmood > cap then
        org.goodmood = math.Approach(org.goodmood, cap, timeValue * INJURY_CAP_DRAIN)
    end

    if org.isPly and IsValid(owner) and owner:IsPlayer() and owner:Alive() then
        updateWoundThoughts(owner, org, woundKind)
    end
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
