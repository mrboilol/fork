if CLIENT then return end

local min, max, Clamp = math.min, math.max, math.Clamp

hg.Mental = hg.Mental or {}

--/////////////////////////////////////////////////////////////////////////////
-- ConVars
--/////////////////////////////////////////////////////////////////////////////

local cvMentalEnabled = CreateConVar("zcity_delta_mental_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable unified mental meter (mood/despair/distress)", 0, 1)
local cvMentalEffectsEnabled = CreateConVar("zcity_delta_mental_effects_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable unified mental meter gameplay effects", 0, 1)
local cvMentalBadMood = CreateConVar("zcity_delta_mental_bad_mood_threshold", "35", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Unified mental meter bad mood threshold (0-100 distress)", 0, 100)
local cvMentalDistress = CreateConVar("zcity_delta_mental_distress_threshold", "55", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Unified mental meter distress threshold (0-100 distress)", 0, 100)
local cvMentalDesperate = CreateConVar("zcity_delta_mental_desperate_threshold", "78", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Unified mental meter desperate/despair threshold (0-100 distress)", 0, 100)
local cvTraitsEnabled = CreateConVar("zcity_delta_traits_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable trait gameplay effects; traits can still be assigned while off", 0, 1)
local cvLastStandEnabled = CreateConVar("zcity_delta_laststand_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable last stand mechanic (requires mental)", 0, 1)
local cvSchizoEnabled = CreateConVar("zcity_delta_schizophrenia_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable schizophrenia visual effects (requires traits)", 0, 1)
local cvDepressionDrainEnabled = CreateConVar("zcity_delta_depression_drain_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable depression stamina drain (requires mental)", 0, 1)
local cvDeathScreenEnabled = CreateConVar("zcity_delta_deathscreen_enable", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable death screen", 0, 1)

local function IsDespairEnabled()
    local cv = GetConVar("hg_despairsystem")
    return not cv or cv:GetInt() ~= 0
end

local function IsMentalEnabled() return cvMentalEnabled:GetBool() and IsDespairEnabled() end
local function AreMentalEffectsEnabled() return IsMentalEnabled() and cvMentalEffectsEnabled:GetBool() end
local function IsTraitsEnabled() return cvTraitsEnabled:GetBool() end
local function IsLastStandEnabled() return cvLastStandEnabled:GetBool() and IsMentalEnabled() end
local function IsSchizoEnabled() return cvSchizoEnabled:GetBool() and IsTraitsEnabled() end
local function IsDepressionDrainEnabled() return cvDepressionDrainEnabled:GetBool() and AreMentalEffectsEnabled() end

--/////////////////////////////////////////////////////////////////////////////
-- Trait Definitions
--/////////////////////////////////////////////////////////////////////////////

local traitDefs = {
    { id = "trained", side = "pos", cost = 5, name = "Trained", desc = "Calmer under pressure and more dangerous up close." },
    { id = "brawler", side = "pos", cost = 4, name = "Brawler", desc = "Violence comes naturally to you." },
    { id = "grunt", side = "pos", cost = 2, name = "Grunt", desc = "Harder to shake with grim sights around you." },
    { id = "in_shape", side = "pos", cost = 5, name = "In Shape", desc = "Better endurance and recovery." },
    { id = "lucky", side = "pos", cost = 3, name = "Lucky", desc = "Things tend to go your way when it matters." },
    { id = "medic", side = "pos", cost = 5, name = "Medic", desc = "Your treatment tends to work better than most." },
    { id = "optimist", side = "pos", cost = 3, name = "Optimist", desc = "You hold onto the bright side a little longer." },
    { id = "maniac", side = "pos", cost = 4, name = "Maniac", desc = "Disturbing scenes affect you in unusual ways." },

    { id = "ptsd", side = "neg", cost = -4, name = "PTSD", desc = "Loud violence leaves a deeper mark on you." },
    { id = "depressed", side = "neg", cost = -5, name = "Depressed", desc = "It is harder to stay motivated and steady." },
    { id = "schizophrenia", side = "neg", cost = -2, name = "Schizophrenia", desc = "Something keeps talking to you from the edge of your vision." },
    { id = "gemophobia", side = "neg", cost = -3, name = "Gemophobia", desc = "Open wounds and injury are especially unsettling to you." },
    { id = "unlucky", side = "neg", cost = -2, name = "Unlucky", desc = "Fortune rarely picks your side." },
}

local traitDefById = {}
for i = 1, #traitDefs do traitDefById[traitDefs[i].id] = traitDefs[i] end

local function NormalizeTraits(raw)
    local out = {}
    if istable(raw) then
        if #raw > 0 then
            for i = 1, #raw do
                local id = tostring(raw[i] or "")
                if id ~= "" and traitDefById[id] then out[id] = true end
            end
        else
            for id, v in pairs(raw) do
                id = tostring(id or "")
                if v and id ~= "" and traitDefById[id] then out[id] = true end
            end
        end
    end
    return out
end

local function TraitsToArray(traits)
    local out = {}
    if istable(traits) then
        for id, v in pairs(traits) do
            if v and traitDefById[id] then out[#out + 1] = id end
        end
    end
    table.sort(out)
    return out
end

local function CalcTraitPoints(traits)
    local total = 0
    if istable(traits) then
        for id, v in pairs(traits) do
            if v and traitDefById[id] then total = total + (tonumber(traitDefById[id].cost) or 0) end
        end
    end
    return total
end

local function GetPlayerTraits(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return {} end
    if not istable(ply.__zcity_delta_traits) then ply.__zcity_delta_traits = {} end
    return ply.__zcity_delta_traits
end

HasTrait = function(ply, id)
    if not IsTraitsEnabled() then return false end
    local tr = GetPlayerTraits(ply)
    return tr[tostring(id or "")] == true
end

GetTraitState = function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return nil end
    ply.__zcity_delta_trait_state = ply.__zcity_delta_trait_state or {}
    return ply.__zcity_delta_trait_state
end

--/////////////////////////////////////////////////////////////////////////////
-- Trait Multipliers (how traits scale mood/stress/despair changes)
--/////////////////////////////////////////////////////////////////////////////

local function GetTraitMultipliers(ply)
    local mul = {
        moodGain = 1, moodLoss = 1,
        stressGain = 1, stressLoss = 1,
        stressTargetMul = 1, dmgStressMul = 1,
        corpseStressMul = 1, foodMoodAdd = 0,
        despairGainMul = 1, despairDecayMul = 1,
        fearGainMul = 1, goodmoodGainMul = 1, goodmoodLossMul = 1,
    }

    if not IsTraitsEnabled() then return mul end

    if HasTrait(ply, "trained") then
        mul.stressGain = mul.stressGain * 0.90
        mul.stressLoss = mul.stressLoss * 1.12
        mul.dmgStressMul = mul.dmgStressMul * 0.85
        mul.stressTargetMul = mul.stressTargetMul * 0.95
        mul.despairGainMul = mul.despairGainMul * 0.85
        mul.fearGainMul = mul.fearGainMul * 0.88
    end

    if HasTrait(ply, "depressed") then
        mul.moodGain = mul.moodGain * 0.75
        mul.moodLoss = mul.moodLoss * 1.25
        mul.despairGainMul = mul.despairGainMul * 1.20
        mul.goodmoodGainMul = mul.goodmoodGainMul * 0.75
        mul.goodmoodLossMul = mul.goodmoodLossMul * 1.30
    end

    if HasTrait(ply, "ptsd") then
        mul.stressGain = mul.stressGain * 1.15
        mul.stressLoss = mul.stressLoss * 0.83
        mul.dmgStressMul = mul.dmgStressMul * 1.25
        mul.corpseStressMul = mul.corpseStressMul * 1.45
        mul.stressTargetMul = mul.stressTargetMul * 1.10
        mul.despairGainMul = mul.despairGainMul * 1.15
        mul.fearGainMul = mul.fearGainMul * 1.20
    end

    if HasTrait(ply, "maniac") then
        mul.corpseStressMul = 0
    end

    if HasTrait(ply, "grunt") then
        mul.corpseStressMul = mul.corpseStressMul * 0.60
        mul.fearGainMul = mul.fearGainMul * 0.85
        mul.despairGainMul = mul.despairGainMul * 0.90
    end

    if HasTrait(ply, "optimist") then
        mul.moodGain = mul.moodGain * 1.15
        mul.goodmoodGainMul = mul.goodmoodGainMul * 1.20
        mul.despairDecayMul = mul.despairDecayMul * 1.15
        mul.foodMoodAdd = mul.foodMoodAdd + 1
    end

    if HasTrait(ply, "in_shape") then
        mul.stressLoss = mul.stressLoss * 1.10
    end

    if HasTrait(ply, "gemophobia") then
        mul.stressGain = mul.stressGain * 1.10
    end

    return mul
end

--/////////////////////////////////////////////////////////////////////////////
-- Mental State (Mood / Stress NWInts)
--/////////////////////////////////////////////////////////////////////////////

local function ClampMood(v) return math.Clamp(tonumber(v) or 0, -100, 100) end
local function ClampStat(v) return math.Clamp(tonumber(v) or 0, 0, 100) end

local function GetMental(ply)
    return ClampMood(ply:GetNWInt("zcity_delta_mood", 0)), ClampStat(ply:GetNWInt("zcity_delta_stress", 10))
end

local function GetMentalMeter(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    local meter = tonumber(ply:GetNWFloat("zcity_delta_mental_meter", 0)) or 0
    if meter == 0 then meter = ClampMood(ply:GetNWInt("zcity_delta_mood", 0)) end
    return math.Clamp(meter, -100, 100)
end

local function SetMental(ply, mood, stress, silent)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsMentalEnabled() then return end

    local tm = GetTraitMultipliers(ply)
    mood = ClampMood(mood)
    stress = ClampStat(stress)

    ply:SetNWInt("zcity_delta_mood", mood)
    ply:SetNWInt("zcity_delta_stress", stress)
end

local function PushRawMental(ply, moodDelta, stressDelta)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsMentalEnabled() then return end
    local mood = tonumber(ply:GetNWInt("zcity_delta_mood", 0)) or 0
    local stress = tonumber(ply:GetNWInt("zcity_delta_stress", 0)) or 0
    ply:SetNWInt("zcity_delta_mood", ClampMood(mood + (tonumber(moodDelta) or 0)))
    ply:SetNWInt("zcity_delta_stress", ClampStat(stress + (tonumber(stressDelta) or 0)))
end

hg.Mental.GetMental = GetMental
hg.Mental.GetMentalMeter = GetMentalMeter
hg.Mental.SetMental = SetMental
hg.Mental.PushRawMental = PushRawMental
hg.Mental.IsMentalEnabled = IsMentalEnabled
hg.Mental.AreMentalEffectsEnabled = AreMentalEffectsEnabled
hg.Mental.IsTraitsEnabled = IsTraitsEnabled
hg.Mental.HasTrait = HasTrait
hg.Mental.GetTraitMultipliers = GetTraitMultipliers
hg.Mental.GetTraitState = GetTraitState

function hg.Mental.GetUnifiedState(ply, org)
    org = org or (IsValid(ply) and ply.organism)
    local mood, stress = 0, 10
    if IsValid(ply) and ply:IsPlayer() then
        mood, stress = GetMental(ply)
    end

    local despair = org and math.Clamp(tonumber(org.despair) or 0, 0, 1) or 0
    local goodmood = org and math.Clamp(tonumber(org.goodmood) or 0, 0, 1) or 0
    local fear = org and math.Clamp(tonumber(org.fear) or 0, 0, 3) or 0
    local pain = org and math.Clamp(tonumber(org.pain) or 0, 0, 150) or 0
    local shock = org and math.Clamp(tonumber(org.shock) or 0, 0, 100) or 0
    local blood = org and math.Clamp(tonumber(org.blood) or 5000, 0, 5000) or 5000
    local o2 = org and org.o2 and tonumber(org.o2[1]) or 100

    local distress = 0
    distress = distress + despair * 0.42
    distress = distress + math.Clamp(stress / 100, 0, 1) * 0.22
    distress = distress + math.Clamp(fear / 2, 0, 1) * 0.18
    distress = distress + math.Clamp(pain / 120, 0, 1) * 0.12
    distress = distress + math.Clamp(shock / 80, 0, 1) * 0.08
    distress = distress + math.Clamp((3500 - blood) / 1800, 0, 1) * 0.12
    distress = distress + math.Clamp((18 - o2) / 18, 0, 1) * 0.14
    distress = distress + math.Clamp((-mood) / 100, 0, 1) * 0.18
    distress = distress - goodmood * 0.16
    distress = math.Clamp(distress, 0, 1)

    local distressPct = distress * 100
    local meter = math.Clamp(goodmood * 100 - distressPct, -100, 100)
    local label = "stable"
    if not IsMentalEnabled() then
        distress = 0
        distressPct = 0
        meter = 0
        label = "disabled"
    elseif distressPct >= cvMentalDesperate:GetFloat() then
        label = "desperate"
    elseif distressPct >= cvMentalDistress:GetFloat() then
        label = "distress"
    elseif distressPct >= cvMentalBadMood:GetFloat() or mood < -25 then
        label = "bad_mood"
    elseif meter > 35 then
        label = "good_mood"
    end

    local state = {
        mood = mood,
        stress = stress,
        despair = despair,
        goodmood = goodmood,
        fear = fear,
        pain = pain,
        shock = shock,
        distress = distress,
        distressPct = distressPct,
        meter = meter,
        label = label,
        stability = math.Clamp(1 - distress, 0, 1),
        panicRisk = math.Clamp((distress - 0.42) / 0.58, 0, 1),
    }

    if org then
        org.mentalMood = mood
        org.mentalStress = stress
        org.mentalDistress = state.distress
        org.mentalMeter = state.meter
        org.mentalState = state.label
        org.mentalStability = state.stability
        org.mentalPanicRisk = state.panicRisk
    end

    if IsValid(ply) and ply:IsPlayer() then
        ply:SetNWFloat("zcity_delta_mental_meter", meter)
        ply:SetNWFloat("zcity_delta_mental_distress", distress)
        ply:SetNWString("zcity_delta_mental_state", label)
    end

    return state
end

--/////////////////////////////////////////////////////////////////////////////
-- Persistence
--/////////////////////////////////////////////////////////////////////////////

local function SaveMental(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local sid = ply:SteamID64()
    if not sid then return end

    local mood = ClampMood(ply:GetNWInt("zcity_delta_mood", 0))
    local stress = ClampStat(ply:GetNWInt("zcity_delta_stress", 10))

    sql.Query("CREATE TABLE IF NOT EXISTS zcity_delta_mental (sid TEXT PRIMARY KEY, mood REAL, stress REAL)")
    sql.Query(string.format("REPLACE INTO zcity_delta_mental (sid, mood, stress) VALUES ('%s', %f, %f)", sid, mood, stress))
end

local function LoadMental(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsMentalEnabled() then
        ply:SetNWInt("zcity_delta_mood", 0)
        ply:SetNWInt("zcity_delta_stress", 10)
        return
    end

    local sid = ply:SteamID64()
    if not sid then return end

    sql.Query("CREATE TABLE IF NOT EXISTS zcity_delta_mental (sid TEXT PRIMARY KEY, mood REAL, stress REAL)")
    local row = sql.QueryRow("SELECT mood, stress FROM zcity_delta_mental WHERE sid = '" .. sid .. "' LIMIT 1")
    if row then
        ply:SetNWInt("zcity_delta_mood", ClampMood(row.mood))
        ply:SetNWInt("zcity_delta_stress", ClampStat(row.stress))
    else
        ply:SetNWInt("zcity_delta_mood", 0)
        ply:SetNWInt("zcity_delta_stress", 10)
    end
end

local function SaveTraits(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local sid = ply:SteamID64()
    if not sid then return end

    local traits = GetPlayerTraits(ply)
    local arr = TraitsToArray(traits)
    local encoded = util.TableToJSON(arr)

    sql.Query("CREATE TABLE IF NOT EXISTS zcity_delta_traits (sid TEXT PRIMARY KEY, traits TEXT)")
    sql.Query(string.format("REPLACE INTO zcity_delta_traits (sid, traits) VALUES ('%s', '%s')", sid, encoded:gsub("'", "''")))
end

local function LoadTraits(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local sid = ply:SteamID64()
    if not sid then return end

    sql.Query("CREATE TABLE IF NOT EXISTS zcity_delta_traits (sid TEXT PRIMARY KEY, traits TEXT)")
    local row = sql.QueryRow("SELECT traits FROM zcity_delta_traits WHERE sid = '" .. sid .. "' LIMIT 1")
    if row and row.traits then
        local arr = util.JSONToTable(row.traits) or {}
        ply.__zcity_delta_traits = NormalizeTraits(arr)
    end
end

local function SyncTraits(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local traits = GetPlayerTraits(ply)
    local arr = TraitsToArray(traits)

    net.Start("zcity_delta_traits_sync")
    net.WriteTable(arr)
    net.Send(ply)
end

local function ApplyTraits(ply, traits)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local normalized = NormalizeTraits(traits)
    local points = CalcTraitPoints(normalized)
    if points > 0 then return false, "Trait points must be <= 0" end

    if normalized["lucky"] and normalized["unlucky"] then return false, "Lucky and Unlucky are mutually exclusive" end
    if normalized["ptsd"] and normalized["depressed"] then return false, "PTSD and Depressed are mutually exclusive" end

    ply.__zcity_delta_traits = normalized
    SaveTraits(ply)
    SyncTraits(ply)
    return true
end

hg.Mental.ApplyTraits = ApplyTraits
hg.Mental.SyncTraits = SyncTraits

net.Receive("zcity_delta_traits_set", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local traits = net.ReadTable()
    local ok, err = ApplyTraits(ply, traits)
    if not ok then
        ply:ChatPrint("[Traits] " .. tostring(err or "Invalid traits"))
    end
end)

--/////////////////////////////////////////////////////////////////////////////
-- Mental ↔ Despair Bridge
--/////////////////////////////////////////////////////////////////////////////
-- The mental system reads org.despair, org.fear, org.goodmood to derive mood/stress.
-- Traits modify the despair system via hooks.

-- Bridge: Org Think hook syncs mood/stress from organism state
hook.Add("Org Think", "zcity_delta_mental_bridge", function(owner, org, timeValue)
    if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
    if not IsMentalEnabled() then
        owner:SetNWFloat("zcity_delta_mental_meter", 0)
        owner:SetNWFloat("zcity_delta_mental_distress", 0)
        owner:SetNWString("zcity_delta_mental_state", "disabled")
        owner:SetNWInt("zcity_delta_mood", 0)
        owner:SetNWInt("zcity_delta_stress", 10)
        if org then
            org.mentalMood = 0
            org.mentalStress = 10
            org.mentalDistress = 0
            org.mentalMeter = 0
            org.mentalState = "disabled"
            org.mentalStability = 1
            org.mentalPanicRisk = 0
        end
        return
    end

    local mood = ClampMood(owner:GetNWInt("zcity_delta_mood", 0))
    local stress = ClampStat(owner:GetNWInt("zcity_delta_stress", 10))
    local tm = GetTraitMultipliers(owner)

    -- Derive mood drift from organism state
    local goodmood = org.goodmood or 0
    local despair = org.despair or 0
    local fear = org.fear or 0
    local pain = org.pain or 0

    -- Goodmood pulls mood up, despair/fear pull it down
    local moodDrift = 0
    moodDrift = moodDrift + goodmood * timeValue * 0.8 * tm.moodGain
    moodDrift = moodDrift - despair * timeValue * 1.5 * tm.moodLoss
    moodDrift = moodDrift - fear * timeValue * 0.5 * tm.moodLoss
    if pain > 40 then
        moodDrift = moodDrift - Clamp((pain - 40) / 80, 0, 1) * timeValue * 2.0 * tm.moodLoss
    end

    -- Antidepressant active: mood recovers faster
    local antidepUntil = tonumber(owner.__zcity_delta_antidep_until or 0) or 0
    local antidepStrength = math.Clamp(tonumber(owner.__zcity_delta_antidep_strength or 0) or 0, 0, 6)
    if antidepUntil > CurTime() and antidepStrength > 0 then
        moodDrift = moodDrift + antidepStrength * timeValue * 0.5
        -- Stress reduction from antidepressants
        stress = ClampStat(stress - antidepStrength * timeValue * 0.3)
    end

    mood = ClampMood(mood + moodDrift)

    -- Derive stress from organism state
    local stressTarget = 10
    stressTarget = stressTarget + fear * 40 * tm.stressGain
    stressTarget = stressTarget + Clamp(pain / 100, 0, 1) * 30 * tm.stressGain
    stressTarget = stressTarget + Clamp((org.shock or 0) / 80, 0, 1) * 25 * tm.stressGain
    stressTarget = stressTarget + Clamp((org.bleed or 0) / 2, 0, 1) * 20 * tm.stressGain
    stressTarget = stressTarget + despair * 35 * tm.stressGain

    if org.o2 and org.o2[1] then
        local o2val = org.o2[1]
        if o2val < 18 then
            stressTarget = stressTarget + Clamp((18 - o2val) / 18, 0, 1) * 30 * tm.stressGain
        end
    end

    -- Gemophobia: wound sight increases stress
    if HasTrait(owner, "gemophobia") then
        local woundSeverity = 0
        if istable(org.wounds) then
            for _, wound in pairs(org.wounds) do
                if istable(wound) then woundSeverity = woundSeverity + math.max(tonumber(wound[1]) or 0, 0) end
            end
        end
        if istable(org.arterialwounds) then
            for _, wound in pairs(org.arterialwounds) do
                if istable(wound) then woundSeverity = woundSeverity + math.max(tonumber(wound[1]) or 0, 0) * 2 end
            end
        end
        stressTarget = stressTarget + Clamp(woundSeverity / 200, 0, 1) * 25
    end

    -- Maniac: corpses give mood instead of stress
    if HasTrait(owner, "maniac") and despair > 0.3 then
        mood = ClampMood(mood + timeValue * 2.0)
    end

    -- Depressed at rock bottom: lock mood at -100
    if mood <= -100 and not (antidepUntil > CurTime() and antidepStrength > 0) then
        mood = -100
    end

    -- Lerp stress toward target
    local stressLerpRate = timeValue * 2.0 * tm.stressLoss
    stress = ClampStat(stress + (stressTarget - stress) * math.min(stressLerpRate, 1))

    -- Natural stress decay toward baseline (10)
    if stressTarget < 15 then
        stress = ClampStat(stress + (10 - stress) * timeValue * 0.1 * tm.stressLoss)
    end

    owner:SetNWInt("zcity_delta_mood", mood)
    owner:SetNWInt("zcity_delta_stress", stress)
    local unifiedState = hg.Mental.GetUnifiedState(owner, org)

    if not AreMentalEffectsEnabled() then return end

    -- Apply trait despair decay multiplier (optimist decays faster, etc.)
    -- Respect the despair system's lock so traumatic events still stick
    -- Skip in simple mode or when berserk/noradrenaline blocks despair
    if IsTraitsEnabled() and tm.despairDecayMul ~= 1 and org.despair and org.despair > 0 then
        local isLocked = CurTime() < (org._despairLockUntil or 0)
        local berserkActive = (org.berserk and org.berserk > 0) or (org.noradrenaline and org.noradrenaline > 0)
        local despairSimpleMode = ConVarExists("hg_despairsystem") and GetConVar("hg_despairsystem"):GetInt() == 0
        if not isLocked and not berserkActive and not despairSimpleMode then
            local extraDecay = (timeValue / 180) * (tm.despairDecayMul - 1)
            if extraDecay > 0 then
                org.despair = math.max(org.despair - extraDecay, 0)
            end
        end
    end

    --/////////////////////////////////////////////////////////////////////////////
    -- Bidirectional feedback: Mental ↔ Despair/Fear/Goodmood merge
    --/////////////////////////////////////////////////////////////////////////////
    -- The bridge above derives mood/stress FROM the despair system.
    -- This section feeds mood/stress BACK INTO the despair system, creating
    -- a true bidirectional merge: bad mood deepens despair, high mood helps
    -- recovery, stress makes the character more fearful and burns adrenaline.

    local despairSimpleMode = ConVarExists("hg_despairsystem") and GetConVar("hg_despairsystem"):GetInt() == 0
    local berserkActive = (org.berserk and org.berserk > 0) or (org.noradrenaline and org.noradrenaline > 0)
    local isLocked = CurTime() < (org._despairLockUntil or 0)

    if not despairSimpleMode and not berserkActive and not org.otrub then
        -- Low mood feeds despair: at -100 mood, adds ~0.015/sec
        if mood < -30 and org.despair then
            local moodFactor = Clamp((-mood - 30) / 70, 0, 1)
            local moodDespairAdd = moodFactor * timeValue * 0.015
            if isLocked then
                moodDespairAdd = moodDespairAdd * 0.3
            end
            org.despair = Clamp((org.despair or 0) + moodDespairAdd, 0, 1)
        end

        -- High mood helps despair decay: at +100 mood, extra ~0.5x decay rate
        if mood > 30 and org.despair and org.despair > 0 and not isLocked then
            local moodFactor = Clamp((mood - 30) / 70, 0, 1)
            local extraDecay = moodFactor * (timeValue / 180) * 0.5
            org.despair = math.max((org.despair or 0) - extraDecay, 0)
        end
    end

    -- Mood → goodmood: positive mood boosts recovery, negative mood drains it
    if not org.otrub then
        if mood > 20 and (org.goodmood or 0) < 1 then
            local moodFactor = Clamp((mood - 20) / 80, 0, 1)
            org.goodmood = math.Clamp((org.goodmood or 0) + moodFactor * timeValue * 0.003, 0, 1)
        elseif mood < -30 and (org.goodmood or 0) > 0 then
            local moodFactor = Clamp((-mood - 30) / 70, 0, 1)
            org.goodmood = math.Clamp((org.goodmood or 0) - moodFactor * timeValue * 0.004, 0, 1)
        end
    end

    -- High stress → fear: stressed characters are jumpier
    if not org.otrub and (stress > 60 or unifiedState.panicRisk > 0.25) and not berserkActive then
        local stressFactor = math.max(Clamp((stress - 60) / 40, 0, 1), unifiedState.panicRisk * 0.65)
        local stressFearAdd = stressFactor * timeValue * 0.15
        local hasThreat = (hg.organism and hg.organism.should_gain_fear and hg.organism.should_gain_fear(org)) or (org.fear or 0) > 0.1
        if hasThreat then
            org.fearadd = math.Clamp((org.fearadd or 0) + stressFearAdd, 0, 3)
        end
    end

    if not org.otrub and not org.givingUp and not org.panicAttack and unifiedState.panicRisk > 0.55 and not berserkActive then
        org._mentalPanicCheckTime = org._mentalPanicCheckTime or 0
        if CurTime() > org._mentalPanicCheckTime then
            org._mentalPanicCheckTime = CurTime() + 1.25
            local chance = (unifiedState.panicRisk - 0.55) / 0.45 * 0.16
            if HasTrait(owner, "ptsd") then chance = chance * 1.35 end
            if HasTrait(owner, "trained") or HasTrait(owner, "grunt") then chance = chance * 0.75 end
            if math.Rand(0, 1) < chance then
                org.panicAttack = true
                org._panicAttackEndTime = CurTime() + math.random(6, 14)
                org._panicAttackStartTime = nil
            end
        end
    end

    -- High stress → adrenaline burn: body in overdrive consumes adrenaline faster
    if not org.otrub and stress > 70 and (org.adrenaline or 0) > 0.5 then
        local stressFactor = Clamp((stress - 70) / 30, 0, 1)
        local adrenalineBurn = stressFactor * timeValue * 0.08
        org.adrenaline = math.max((org.adrenaline or 0) - adrenalineBurn, 0)
    end

    -- High stress nudges the cardiovascular target instead of adding a fresh
    -- heartbeat spike every think.
    if not org.otrub and stress > 50 then
        local stressFactor = Clamp((stress - 50) / 50, 0, 1)
        org.heartbeat = math.Approach(org.heartbeat or 70, 70 + stressFactor * 15, timeValue * 3)
    end

    -- Very low mood → disorientation (mirrors despair's disorientation at high levels)
    if mood < -70 and not org.otrub then
        org.disorientation = math.max(org.disorientation or 0, Clamp((-mood - 70) / 30, 0, 1))
    end

    -- Note: Trait fear gain and goodmood multipliers are applied via hooks
    -- (HomigradDamage for fear, and the goodmood module hooks for goodmood)
    -- to avoid compounding per-tick multiplication on cumulative organism values.

    -- Send moodles extra data to client
    if owner.__zcity_delta_moodles_next_send and CurTime() < owner.__zcity_delta_moodles_next_send then return end
    owner.__zcity_delta_moodles_next_send = CurTime() + 0.5

    net.Start("zcity_delta_moodles_extra")
    net.WriteFloat(org.satiety or 0)
    net.WriteFloat(org.internalBleed or 0)
    net.WriteFloat(org.hungry or 0)
    net.Send(owner)
end)

--/////////////////////////////////////////////////////////////////////////////
-- Trait hooks on the despair system
--/////////////////////////////////////////////////////////////////////////////

-- Modify despair gain based on traits
hook.Add("HomigradDamage", "zcity_delta_trait_damage_mental", function(ply, dmgInfo, hitgroup, ent, rawDamage)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsMentalEnabled() then return end

    local dmg = rawDamage or (dmgInfo and dmgInfo.GetDamage and dmgInfo:GetDamage()) or 0
    if dmg <= 0 then return end

    local tm = GetTraitMultipliers(ply)
    local moodDelta = -Clamp(dmg / 80, 0.5, 8) * tm.moodLoss
    local stressDelta = Clamp(dmg / 60, 0.5, 10) * tm.dmgStressMul
    PushRawMental(ply, moodDelta, stressDelta)

    if IsTraitsEnabled() and ply.organism then
        local org = ply.organism

        -- Skip despair/fear modifications when despair system is in simple mode
        -- or when berserk/noradrenaline blocks despair (matching base despair system behavior)
        local despairActive = not (org.berserk and org.berserk > 0) and not (org.noradrenaline and org.noradrenaline > 0)
        local despairSimpleMode = ConVarExists("hg_despairsystem") and GetConVar("hg_despairsystem"):GetInt() == 0

        -- Apply trait despair gain multiplier (differential only)
        if despairActive and not despairSimpleMode and tm.despairGainMul ~= 1 then
            local add = Clamp(dmg / 240, 0.01, 0.18)
            if dmgInfo and dmgInfo.IsDamageType and dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST + DMG_BURN + DMG_SLASH + DMG_CLUB) then
                add = add * 1.2
            end
            local traitAdd = add * (tm.despairGainMul - 1)
            org.despair = Clamp((org.despair or 0) + traitAdd, 0, 1)
            if traitAdd > 0 then
                org._despairLastGainedTime = CurTime()
            end
        end

        -- Apply trait fear gain multiplier: add extra fearadd scaled by trait
        -- Base game adds ~0.3 fearadd for bullet/slash/burn damage in sv_input.lua
        -- We add the differential here (only for the most consistent fearadd source)
        if tm.fearGainMul ~= 1 and not org.otrub then
            local baseFearAdd = 0
            if dmgInfo and dmgInfo.IsDamageType and dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_SLASH + DMG_BURN) then
                baseFearAdd = 0.3
            end
            -- General damage also adds fearadd proportional to damage
            baseFearAdd = baseFearAdd + Clamp(dmg / 100, 0, 0.5)
            local extraFear = baseFearAdd * (tm.fearGainMul - 1)
            if extraFear ~= 0 then
                org.fearadd = math.Clamp((org.fearadd or 0) + extraFear, 0, 3)
            end
        end

        -- Apply trait goodmood loss multiplier: extra goodmood loss on damage
        if tm.goodmoodLossMul ~= 1 and dmg > 5 then
            local baseLoss = dmg * 0.002
            local extraLoss = baseLoss * (tm.goodmoodLossMul - 1)
            org.goodmood = math.Clamp((org.goodmood or 0) - extraLoss, 0, 1)
        end
    end
end)

-- Apply trait goodmood gain multiplier: scale the overcome-fear/despair boost
-- This runs after GoodMood_OvercomeFear in Org Think, scaling the boost that was just applied
hook.Add("Org Think", "zcity_delta_trait_goodmood_gain", function(owner, org, timeValue)
    if not IsTraitsEnabled() then return end
    if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
    local tm = GetTraitMultipliers(owner)
    if tm.goodmoodGainMul == 1 then return end

    -- Track goodmood delta: if goodmood increased this tick, scale the increase
    local prev = org._zcity_delta_prev_goodmood or org.goodmood or 0
    local cur = org.goodmood or 0
    if cur > prev and tm.goodmoodGainMul ~= 1 then
        local delta = cur - prev
        local scaled = delta * tm.goodmoodGainMul
        org.goodmood = math.Clamp(prev + scaled, 0, 1)
    end
    org._zcity_delta_prev_goodmood = org.goodmood
end)

-- Trait-based damage modifiers
hook.Add("EntityTakeDamage", "zcity_delta_trait_misc_damage", function(target, dmg)
    if not IsTraitsEnabled() then return end
    if not IsValid(target) or not target:IsPlayer() or not target:Alive() then return end
    if not IsValid(dmg) then return end

    local cur = dmg:GetDamage() or 0
    if cur <= 0 then return end

    local now = CurTime()
    local state = GetTraitState(target)

    if HasTrait(target, "lucky") and state and (state.luckyGuardUntil or 0) <= now and math.Rand(0, 1) <= 0.14 then
        dmg:SetDamage(cur * 0.72)
        state.luckyGuardUntil = now + 18
        if target.organism then
            target.organism.immobilization = math.max((tonumber(target.organism.immobilization) or 0) - 2, 0)
        end
    elseif HasTrait(target, "unlucky") and state and (state.unluckyGuardUntil or 0) <= now and math.Rand(0, 1) <= 0.18 then
        dmg:SetDamage(cur * 1.16)
        state.unluckyGuardUntil = now + 14
        state.unluckyFumbleUntil = now + 12
    end

    if HasTrait(target, "grunt") and state then
        state.gruntFocusUntil = now + 8
    end

    if HasTrait(target, "schizophrenia") and state and math.Rand(0, 1) <= 0.12 then
        state.schizoEpisodeUntil = math.max(tonumber(state.schizoEpisodeUntil or 0) or 0, now + 4)
    end

    if (tonumber(target.__zcity_delta_stabilized_until or 0) or 0) > now and target.organism then
        target.organism.bleed = math.max((tonumber(target.organism.bleed) or 0) - 0.03, 0)
        target.organism.painadd = math.max((tonumber(target.organism.painadd) or 0) - 1.5, 0)
    end
end)

-- Trained: melee damage bonus
hook.Add("EntityTakeDamage", "zcity_delta_trait_trained_melee", function(target, dmg)
    if not IsTraitsEnabled() then return end
    if not IsValid(target) or not target:IsPlayer() then return end

    local att = dmg:GetAttacker()
    if not IsValid(att) or not att:IsPlayer() then return end
    if not HasTrait(att, "trained") then return end

    local state = GetTraitState(att)
    if not state then return end

    local isMelee = dmg:IsDamageType(DMG_CLUB + DMG_SLASH)
    if isMelee then
        dmg:SetDamage(dmg:GetDamage() * 1.12)
        state.trainedMeleeWindow = CurTime() + 12
    end
end)

-- Brawler: mood from dealing damage, combo system
hook.Add("EntityTakeDamage", "zcity_delta_trait_brawler_hits", function(target, dmg)
    if not IsTraitsEnabled() then return end
    if not IsValid(target) or not target:IsPlayer() then return end

    local att = dmg:GetAttacker()
    if not IsValid(att) or not att:IsPlayer() then return end
    if not HasTrait(att, "brawler") then return end

    local state = GetTraitState(att)
    if not state then return end

    state.brawlerComboCount = (state.brawlerComboCount or 0) + 1
    state.brawlerComboUntil = CurTime() + 4

    if state.brawlerComboCount >= 3 then
        state.brawlerComboCount = 0
        PushRawMental(att, 3, -3)
        if target.organism then
            target.organism.immobilization = math.max((tonumber(target.organism.immobilization) or 0) + 1.5, 0)
        end
        if att.organism and istable(att.organism.stamina) then
            local stam = att.organism.stamina
            local maxS = math.max(tonumber(stam.max) or 180, 1)
            stam[1] = math.max(tonumber(stam[1]) or 0 - maxS * 0.08, 0)
        end
    end
end)

-- Maniac: mood boost on kills
hook.Add("PlayerDeath", "zcity_delta_trait_maniac_kill", function(victim, inflictor, attacker)
    if not IsTraitsEnabled() then return end
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if not HasTrait(attacker, "maniac") then return end
    PushRawMental(attacker, 8, -5)
end)

--/////////////////////////////////////////////////////////////////////////////
-- Trait maintenance timer
--/////////////////////////////////////////////////////////////////////////////

timer.Create("zcity_delta_trait_maintenance", 1, 0, function()
    if not IsTraitsEnabled() then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end

        local state = GetTraitState(ply)
        local org = ply.organism

        if HasTrait(ply, "in_shape") and org and istable(org.stamina) then
            local stamina = org.stamina
            local maxStamina = math.max(tonumber(stamina.max) or 0, 1)
            local frac = (tonumber(stamina[1]) or 0) / maxStamina
            if frac <= 0.33 and not ply:KeyDown(IN_SPEED) then
                stamina[1] = math.min(maxStamina, (tonumber(stamina[1]) or 0) + maxStamina * 0.12)
                if state then state.secondWindUntil = CurTime() + 6 end
            end
        end

        if HasTrait(ply, "optimist") and GetMentalMeter(ply) >= 25 then
            for _, near in ipairs(player.GetAll()) do
                if near == ply then continue end
                if not IsValid(near) or not near:IsPlayer() or not near:Alive() then continue end
                if near:GetPos():DistToSqr(ply:GetPos()) > (280 * 280) then continue end
                PushRawMental(near, 1, -1)
            end
        end

        if HasTrait(ply, "schizophrenia") and state then
            if (tonumber(ply.__zcity_delta_clarity_until or 0) or 0) > CurTime() then
                state.schizoEpisodeUntil = nil
            elseif math.Rand(0, 1) <= 0.10 then
                state.schizoEpisodeUntil = CurTime() + math.Rand(3, 5)
                PushRawMental(ply, math.random(-2, 2), math.random(1, 4))
            end
        end

        if HasTrait(ply, "depressed") and (tonumber(ply.__zcity_delta_relief_until or 0) or 0) > CurTime() then
            PushRawMental(ply, 1, -2)
        end
    end
end)

--/////////////////////////////////////////////////////////////////////////////
-- Depression stamina drain
--/////////////////////////////////////////////////////////////////////////////

timer.Create("zcity_delta_depression_stamina_drain", 0.35, 0, function()
    if not IsDepressionDrainEnabled() then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
        local org = ply.organism
        if not org or not istable(org.stamina) then continue end

        local meter = GetMentalMeter(ply)
        if meter >= 0 then continue end

        if not ply:KeyDown(IN_SPEED) then continue end

        local t = (-meter) / 100
        local maxStam = math.max(tonumber(org.stamina.max) or 180, 1)
        local drainPerSec = (0.25 + 2.2 * (t ^ 1.35)) * (maxStam / 220)
        org.stamina[1] = math.max((tonumber(org.stamina[1]) or 0) - drainPerSec * 0.35, 0)
    end
end)

--/////////////////////////////////////////////////////////////////////////////
-- Gunshot/explosion stress for PTSD/Grunt
--/////////////////////////////////////////////////////////////////////////////

hook.Add("EntityFireBullets", "zcity_delta_trait_gunshot_stress", function(ent, bullet)
    if not IsTraitsEnabled() then return end
    if not IsValid(ent) or not ent:IsPlayer() then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
        if ply == ent then continue end

        local dist = ply:GetPos():DistToSqr(ent:GetPos())
        if dist > 400 * 400 then continue end

        if HasTrait(ply, "ptsd") then
            local distFalloff = 1 - Clamp(dist / (400 * 400), 0, 1)
            PushRawMental(ply, -2 * distFalloff, 5 * distFalloff)
            local state = GetTraitState(ply)
            if state then state.ptsdPanicUntil = CurTime() + 6 end
        elseif HasTrait(ply, "grunt") then
            PushRawMental(ply, 0, -1)
        end

        if HasTrait(ply, "schizophrenia") and math.Rand(0, 1) <= 0.15 then
            PushRawMental(ply, 0, math.random(1, 3))
        end
    end
end)

--/////////////////////////////////////////////////////////////////////////////
-- Antidepressants
--/////////////////////////////////////////////////////////////////////////////

function hg.Mental.ApplyAntidepressantDose(ply, target, dose)
    if not IsValid(target) or not target:IsPlayer() then return end
    if not IsMentalEnabled() then return end

    target.__zcity_delta_antidep_until = CurTime() + 240
    target.__zcity_delta_antidep_strength = math.Clamp((target.__zcity_delta_antidep_strength or 0) + (dose or 1) * 1.5, 0, 6)

    PushRawMental(target, 5, -10)
end

function hg.Mental.ApplyBetaBlockerStressReset(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsMentalEnabled() then return end

    ply:SetNWInt("zcity_delta_stress", 0)
    ply.__zcity_delta_betablock_until = CurTime() + 60
end

--/////////////////////////////////////////////////////////////////////////////
-- Medical progress modifier (used by sv_logic.lua)
--/////////////////////////////////////////////////////////////////////////////

GetMedicalProgressModifier = function(ply, target, minigameType, progressDelta)
    local mul = 1
    local state = GetTraitState(ply)
    local meter = GetMentalMeter(ply)

    if not IsTraitsEnabled() then return mul end

    if minigameType == "bandage" and HasTrait(ply, "gemophobia") then
        mul = mul * 0.84
    end

    if HasTrait(ply, "medic") then
        local sameTarget = state
            and state.lastMedicalTarget == target
            and state.lastMedicalType == minigameType
            and (state.lastMedicalAt or 0) + 8 > CurTime()
        mul = mul * (sameTarget and 1.15 or 1.06)
    end

    if HasTrait(ply, "ptsd") and state and (state.ptsdPanicUntil or 0) > CurTime() then
        mul = mul * 0.78
    end

    if HasTrait(ply, "depressed") and meter <= -35 then
        mul = mul * 0.82
    end

    if HasTrait(ply, "schizophrenia") and state and (state.schizoEpisodeUntil or 0) > CurTime() then
        mul = mul * 0.76
    end

    if HasTrait(ply, "grunt") and state and (state.gruntFocusUntil or 0) > CurTime() then
        mul = mul * 1.08
    end

    if state then
        state.lastMedicalTarget = target
        state.lastMedicalType = minigameType
        state.lastMedicalAt = CurTime()
    end

    return mul
end

GetMedicalSeverity = function(target)
    if not IsValid(target) or not target.organism then return 0, 0, 0, 0 end

    local org = target.organism
    local bleed = math.max(tonumber(org.bleed) or 0, 0)
    local woundSeverity = 0
    local arterialSeverity = 0

    if istable(org.wounds) then
        for _, wound in pairs(org.wounds) do
            if istable(wound) then woundSeverity = woundSeverity + math.max(tonumber(wound[1]) or 0, 0) end
        end
    end

    if istable(org.arterialwounds) then
        for _, wound in pairs(org.arterialwounds) do
            if istable(wound) then arterialSeverity = arterialSeverity + math.max(tonumber(wound[1]) or 0, 0) end
        end
    end

    local totalSeverity = bleed * 12 + woundSeverity * 0.06 + arterialSeverity * 0.75
    return totalSeverity, bleed, woundSeverity, arterialSeverity
end

--/////////////////////////////////////////////////////////////////////////////
-- Medical finish effects (called when a minigame completes)
--/////////////////////////////////////////////////////////////////////////////

hook.Add("hg_medical_minigame_finished", "zcity_delta_trait_medical_finish", function(ply, target, minigameType)
    if not IsTraitsEnabled() then return end
    if not IsValid(ply) or not IsValid(target) then return end

    local state = GetTraitState(ply)
    local tState = GetTraitState(target)
    local org = target.organism

    if HasTrait(ply, "trained") and state then
        state.trainedMeleeWindow = CurTime() + 12
    end

    if HasTrait(ply, "medic") and IsValid(target) then
        target.__zcity_delta_stabilized_until = CurTime() + 28
        if org then
            org.bleed = math.max((tonumber(org.bleed) or 0) - 0.5, 0)
            org.painadd = math.max((tonumber(org.painadd) or 0) - 3, 0)
        end
    end

    if HasTrait(ply, "optimist") then
        PushRawMental(ply, 2, -1)
    end

    if HasTrait(ply, "in_shape") and org and istable(org.stamina) then
        local maxS = math.max(tonumber(org.stamina.max) or 180, 1)
        org.stamina[1] = math.min(maxS, (tonumber(org.stamina[1]) or 0) + maxS * 0.15)
    end

    if HasTrait(ply, "lucky") and math.Rand(0, 1) <= 0.22 then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.modeValues then
            local idx = wep.mode or 1
            wep.modeValues[idx] = (wep.modeValues[idx] or 0) + 15
            wep:SetNetVar("modeValues", table.Copy(wep.modeValues))
        end
        PushRawMental(ply, 1, -1)
    end

    if HasTrait(ply, "maniac") and (minigameType == "amputation" or minigameType == "dislocation") then
        PushRawMental(ply, 5, -3)
    end

    -- Target gets relief from being treated
    if HasTrait(target, "depressed") then
        target.__zcity_delta_relief_until = CurTime() + 20
    end

    if HasTrait(target, "schizophrenia") and tState then
        target.__zcity_delta_clarity_until = CurTime() + 15
        tState.schizoEpisodeUntil = nil
    end

    if HasTrait(ply, "grunt") and state then
        PushRawMental(ply, 0, -2)
    end

    -- Target gets goodmood boost from being treated, scaled by trait
    if org then
        local tTm = GetTraitMultipliers(target)
        local baseBoost = 0.01
        if ply == target then baseBoost = 0.02 end
        local boost = baseBoost * tTm.goodmoodGainMul
        org.goodmood = math.Clamp((org.goodmood or 0) + boost, 0, 1)
    end
end)

--/////////////////////////////////////////////////////////////////////////////
-- Last Stand
--/////////////////////////////////////////////////////////////////////////////

local lastStandCurvePoints = {
    {happiness = -100, chance = 0.02},
    {happiness = -80, chance = 0.04},
    {happiness = -60, chance = 0.06},
    {happiness = -40, chance = 0.08},
    {happiness = -20, chance = 0.10},
    {happiness = 0, chance = 0.14},
    {happiness = 20, chance = 0.20},
    {happiness = 40, chance = 0.28},
    {happiness = 60, chance = 0.38},
    {happiness = 80, chance = 0.50},
    {happiness = 100, chance = 0.62},
}

local function EvaluateLastStandChance(happiness, ply)
    local chance = 0.14
    for i = 1, #lastStandCurvePoints do
        local pt = lastStandCurvePoints[i]
        if happiness <= pt.happiness then
            chance = pt.chance
            break
        end
        chance = pt.chance
    end

    if HasTrait(ply, "lucky") then chance = chance * 1.35 end
    if HasTrait(ply, "unlucky") then chance = chance * 0.55 end

    return Clamp(chance, 0, 0.85)
end

local function EnsureLastStandHappinessHistory(ply)
    if not istable(ply.__zcity_delta_laststand_history) then
        ply.__zcity_delta_laststand_history = {}
    end
    return ply.__zcity_delta_laststand_history
end

timer.Create("zcity_delta_laststand_happiness_updater", 9, 0, function()
    if not IsLastStandEnabled() then return end
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
        local hist = EnsureLastStandHappinessHistory(ply)
        table.insert(hist, 1, GetMentalMeter(ply))
        while #hist > 10 do table.remove(hist) end
    end
end)

local function ApplyLastStandEffects(ply, org)
    org.lastStandO2Until = CurTime() + 200
    org.lastStandAdrenalineUntil = CurTime() + 200
    org.blood = math.max(org.blood or 0, 5000)
    org.bleed = 0
    org.painadd = math.max((org.painadd or 0) - 20, 0)
    if org.o2 and org.o2.range then
        org.o2[1] = org.o2.range
        org.o2.curregen = org.o2.regen
    end
    org.pulse = math.max(org.pulse or 0, 70)
    org.heartstop = false
    org.lungsfunction = true
    org.adrenaline = math.max(org.adrenaline or 0, 4)
    org.adrenalineAdd = math.max(org.adrenalineAdd or 0, 2)

    -- Clear despair states so the despair system doesn't fight the last stand recovery
    org.givingUp = false
    org._giveUpCheckTime = 0
    org._giveUpDirectCheckTime = 0
    org._giveUpHeartStopCheck = 0
    org.panicAttack = false
    org._panicAttackEndTime = 0
    org._panicAttackStartTime = nil
    org._panicAttackCheckTime = nil
    org._panicAdrenalineGiven = false
    org.despair = math.min(org.despair or 0, 0.3)

    ply.__zcity_delta_laststand_active_until = CurTime() + 200
end

function hg.Mental.TryLastStand(ply, org)
    if not IsLastStandEnabled() then return false end
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not ply:Alive() then return false end

    org = org or ply.organism
    if not org or not org.brain then return false end

    -- Don't trigger last stand if player has given up (deliberate surrender)
    if org.givingUp then return false end

    if ply.__zcity_delta_laststand_rolled then return false end

    local hist = EnsureLastStandHappinessHistory(ply)
    local currentMood = GetMentalMeter(ply)
    local histMood = (hist and hist[10] ~= nil) and ClampMood(hist[10]) or nil
    local useHist = histMood ~= nil
    local happiness = useHist and histMood or currentMood
    local chance = EvaluateLastStandChance(happiness, ply)
    local roll = math.Rand(0, 1)

    ply.__zcity_delta_laststand_rolled = true
    ply.__zcity_delta_laststand_last = {
        happiness = happiness, currentMood = currentMood, histMood = histMood,
        useHist = useHist, chance = chance, roll = roll,
    }

    if roll >= chance then return false end

    ApplyLastStandEffects(ply, org)

    net.Start("zcity_delta_laststand")
    net.WriteBool(true)
    net.WriteFloat(tonumber(ply.__zcity_delta_laststand_active_until) or (CurTime() + 200))
    net.Send(ply)

    local tid = "zcity_delta_laststand_end_" .. ply:SteamID64()
    timer.Remove(tid)
    timer.Create(tid, 200, 1, function()
        if not IsValid(ply) then return end
        net.Start("zcity_delta_laststand")
        net.WriteBool(false)
        net.WriteFloat(0)
        net.Send(ply)
    end)

    return true
end

-- Patch organism lungs module for last stand
local function PatchOrganismForLastStand()
    if hg.__zcity_delta_laststand_patched then return end
    hg.__zcity_delta_laststand_patched = true

    if not (hg and hg.organism and hg.organism.module and hg.organism.module.lungs) then return end

    local lungsModule = hg.organism.module.lungs
    if not lungsModule[2] then return end
    if lungsModule.__zcity_delta_laststand_patched then return end
    local originalLungs = lungsModule[2]

    lungsModule[2] = function(owner, org, timeValue)
        if IsValid(owner) and owner:IsPlayer() and org and org.brain then
            if org.alive and org.brain >= 0.6 then
                hg.Mental.TryLastStand(owner, org)
            end

            if org.lastStandO2Until and CurTime() < org.lastStandO2Until and org.o2 and org.o2.range then
                org.o2[1] = org.o2.range
                org.o2.curregen = org.o2.regen
            end
        end

        originalLungs(owner, org, timeValue)

        if IsValid(owner) and owner:IsPlayer() and org and org.brain then
            if (not org.alive) and org.brain >= 0.6 then
                if hg.Mental.TryLastStand(owner, org) then
                    org.alive = true
                end
            end

            if org.lastStandO2Until and CurTime() < org.lastStandO2Until and org.o2 and org.o2.range then
                org.o2[1] = org.o2.range
                org.o2.curregen = org.o2.regen
            end
        end
    end

    lungsModule.__zcity_delta_laststand_patched = true

    -- Patch pain module for last stand adrenaline
    if hg.organism.module.pain and hg.organism.module.pain[2] then
        local painModule = hg.organism.module.pain
        if not painModule.__zcity_delta_laststand_patched and painModule[2] then
            local originalPain = painModule[2]
            painModule[2] = function(owner, org, timeValue)
                if org and org.lastStandAdrenalineUntil and CurTime() < org.lastStandAdrenalineUntil then
                    local remaining = org.lastStandAdrenalineUntil - CurTime()
                    local floor = math.max(0, remaining / 200) * 4
                    org.adrenaline = math.max(org.adrenaline or 0, floor)
                end
                originalPain(owner, org, timeValue)
            end
            painModule.__zcity_delta_laststand_patched = true
        end
    end
end

hook.Add("HomigradRun", "zcity_delta_laststand_patch", PatchOrganismForLastStand)
hook.Add("InitPostEntity", "zcity_delta_laststand_patch", PatchOrganismForLastStand)
timer.Simple(2, PatchOrganismForLastStand)
timer.Simple(5, PatchOrganismForLastStand)

--/////////////////////////////////////////////////////////////////////////////
-- Spawn / Death / Disconnect handlers
--/////////////////////////////////////////////////////////////////////////////

hook.Add("PlayerInitialSpawn", "zcity_delta_mental_load", function(ply)
    LoadMental(ply)
    LoadTraits(ply)
    timer.Simple(2, function()
        if IsValid(ply) then SyncTraits(ply) end
    end)
end)

hook.Add("PlayerSpawn", "zcity_delta_mental_spawn", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply.__zcity_delta_laststand_rolled = false
    ply.__zcity_delta_laststand_attempted = nil
    ply.__zcity_delta_laststand_active_until = nil
    if ply.organism then
        ply.organism._zcity_delta_laststand_attempted = nil
        ply.organism.lastStandO2Until = nil
        ply.organism.lastStandAdrenalineUntil = nil
    end
end)

hook.Add("PlayerDeath", "zcity_delta_mental_death", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply.__zcity_delta_laststand_rolled = false
    ply.__zcity_delta_laststand_attempted = nil
    ply.__zcity_delta_laststand_active_until = nil

    if ply.organism then
        ply.organism.lastStandAdrenalineUntil = nil
        ply.organism.lastStandO2Until = nil
    end

    if IsMentalEnabled() then
        local mood = ClampMood(ply:GetNWInt("zcity_delta_mood", 0))
        if mood < -50 then
            ply:SetNWInt("zcity_delta_mood", math.random(-30, 10))
        else
            ply:SetNWInt("zcity_delta_mood", math.random(10, 30))
        end
        ply:SetNWInt("zcity_delta_stress", 10)
        SaveMental(ply)
    end
end)

hook.Add("PlayerDisconnected", "zcity_delta_mental_save", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    SaveMental(ply)
    SaveTraits(ply)
end)

hook.Add("ShutDown", "zcity_delta_mental_save_all", function()
    for _, ply in ipairs(player.GetAll()) do
        SaveMental(ply)
        SaveTraits(ply)
    end
end)

--/////////////////////////////////////////////////////////////////////////////
-- Debug concommands
--/////////////////////////////////////////////////////////////////////////////

concommand.Add("zcity_delta_laststand_debug", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local last = ply.__zcity_delta_laststand_last
    if not last then
        ply:ChatPrint("[LastStand] No last stand attempt recorded.")
        return
    end
    ply:ChatPrint("[LastStand] happiness=" .. tostring(last.happiness) ..
        " currentMood=" .. tostring(last.currentMood) ..
        " histMood=" .. tostring(last.histMood) ..
        " useHist=" .. tostring(last.useHist) ..
        " chance=" .. tostring(last.chance) ..
        " roll=" .. tostring(last.roll) ..
        " result=" .. (last.roll < last.chance and "SUCCESS" or "FAILED"))
end)

concommand.Add("zcity_delta_traits_set", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local traits = {}
    for i = 1, #args do
        local id = tostring(args[i] or "")
        if traitDefById[id] then traits[id] = true end
    end
    local ok, err = ApplyTraits(ply, traits)
    if ok then
        ply:ChatPrint("[Traits] Applied: " .. table.concat(TraitsToArray(traits), ", "))
    else
        ply:ChatPrint("[Traits] Failed: " .. tostring(err))
    end
end)

concommand.Add("zcity_delta_traits_list", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    for _, def in ipairs(traitDefs) do
        ply:ChatPrint(string.format("[%s] %s (cost %d): %s", def.side:upper(), def.name, def.cost, def.desc))
    end
end)

concommand.Add("zcity_delta_mental_debug", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local mood, stress = GetMental(ply)
    local state = hg.Mental.GetUnifiedState(ply, ply.organism)
    ply:ChatPrint("[Mental] Meter=" .. math.Round(state.meter or 0) ..
        " Distress=" .. math.Round((state.distress or 0) * 100) ..
        " State=" .. tostring(state.label) ..
        " Mood=" .. mood ..
        " Stress=" .. stress)
    local traits = TraitsToArray(GetPlayerTraits(ply))
    ply:ChatPrint("[Traits] " .. table.concat(traits, ", ") .. " (effects " .. (IsTraitsEnabled() and "on" or "off") .. ")")
end)

print("[zcity-delta] mental system loaded (server)")
