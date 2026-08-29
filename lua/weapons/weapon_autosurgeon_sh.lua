if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_tpik1_base"
SWEP.PrintName = "Portable D.I.H Unit"
SWEP.Instructions = "A portable Direct Injury Handler is a lifesaving device that you can use in any combat scenario to stabilize and treat internal injuries. It is not effective in terms of speed however, so it is still recommended to administer CPR and other lifesaving techniques in conjunction with the D.I.H. Comes with an autopulse, a organ mender, stimulators and a stitcher. This one is in a different language."
SWEP.Category = "Medicine"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Slot = 3
SWEP.SlotPos = 2

SWEP.Primary.ClipSize = 1000
SWEP.Primary.DefaultClip = 1000
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "D.I.H Battery"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/w_models/weapons/w_eq_medkit.mdl"
SWEP.WorkWithFake = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.AttachTime = 1
SWEP.AttachRange = 80
SWEP.UnitBone = "ValveBiped.Bip01_Spine2"
-- Keep the unit clear of the torso instead of burying it in the chest.
SWEP.UnitPos = Vector(2, 5, 0)
SWEP.UnitAng = Angle(0, 90, 90)
SWEP.UnitFemPos = Vector(-1.5, 0, 0.75)

SWEP.setrhik = true
SWEP.setlhik = true
SWEP.LHPos = Vector(0, -6.6, 0)
SWEP.LHAng = Angle(0, 0, 180)
SWEP.DefaultRHPosOffset = Vector(-0.5, -2, -5)
SWEP.DefaultRHAngOffset = Angle(0, 45, -55)
SWEP.DefaultLHPosOffset = Vector(0, -4, -2)
SWEP.DefaultLHAngOffset = Angle(5, 0, -35)
SWEP.AttachRHPosOffset = Vector(1, 6, -5)
SWEP.AttachRHAngOffset = Angle(0, 45, -55)
SWEP.AttachLHPosOffset = Vector(4, -4, -20)
SWEP.AttachLHAngOffset = Angle(65, 0, -35)
SWEP.SelfAttachRHPosOffset = Vector(-12, -16, -5)
SWEP.SelfAttachRHAngOffset = Angle(0, 45, -55)
SWEP.SelfAttachLHPosOffset = Vector(-6, -4, 10)
SWEP.SelfAttachLHAngOffset = Angle(5, 0, -35)
SWEP.RHPosOffset = SWEP.DefaultRHPosOffset
SWEP.RHAngOffset = SWEP.DefaultRHAngOffset
SWEP.LHPosOffset = SWEP.DefaultLHPosOffset
SWEP.LHAngOffset = SWEP.DefaultLHAngOffset
SWEP.handPos = vector_origin
SWEP.handAng = angle_zero
SWEP.UsePistolHold = false
SWEP.offsetVec = Vector(4, -0.5, -3)
SWEP.offsetAng = Angle(-30, 20, 90)
SWEP.AttachHandPos = Vector(4, -0.5, -3)
SWEP.AttachHandAng = Angle(-30, 70, 90)
SWEP.SelfAttachHandPos = Vector(4, -0.5, -3)
SWEP.SelfAttachHandAng = Angle(-30, -110, 90)
SWEP.HeadPosOffset = Vector(15, 1.7, -5)
SWEP.HeadAngOffset = Angle(-90, 0, -90)
SWEP.BaseBone = "ValveBiped.Bip01_Head1"
SWEP.HoldLH = "normal"
SWEP.HoldRH = "normal"
SWEP.HoldClampMax = 35
SWEP.HoldClampMin = 35

SWEP.Config = {
    BatteryMax = 1000,
    BatteryRecharge = {
        -- A dedicated battery restores half of the unit's capacity.  Taser
        -- cartridges remain an intentionally weaker field-expedient option.
        ["D.I.H Battery"] = 500,
        ["Taser Cartridge"] = 100
    },
    BatteryPerTick = 3,
    AutopulseBatteryPerBeat = 6,
    TickInterval = 0.25,
    AutopulseInterval = 60 / 70,
    AutopulseOxygenFloor = 28,
    AutopulseOxygenRecovery = 0.35,
    AutopulseBloodFloor = 4200,
    AutopulseBloodRestore = 180,
    AutopulseMannitolTarget = 1.25,
    AutopulseMannitolDose = 0.08,
    SoundCooldown = 0.35,
    InjuryHeal = 0.14,
    BleedHeal = 3,
    InternalBleedHeal = 1.2,
    BloodRestore = 100,
    OxygenRecovery = 0.20,
    ModeMinTicks = 3,
    ModeClearTicks = 3,
    StableTicks = 4,
    ModePreemptRatio = 1.35
}

-- SWEP is only guaranteed to exist while this file is being loaded. Deferred
-- client hooks must retain the values they need instead of looking it up later.
local ASConfig = SWEP.Config

local ASSounds = {
    battery = "autonigger/buttons.wav",
    mounted = "autonigger/autosurgeonon.wav",
    pump = "autonigger/pump.wav",
    modeComplete = "autonigger/completemode.wav",
    modeSwitch = "autonigger/switchmode.wav",
    painkillerNeeded = "autonigger/switch.wav",
    stimulator = "autonigger/stimulator.wav",
    suddenStop = "autonigger/suddenstop.wav",
    removed = "autonigger/desert.wav",
    complete = "autonigger/complete.wav"
}

local ASScanSounds = {
    "autonigger/atireputas1.wav",
    "autonigger/atireputas2.wav",
    "autonigger/atireputas3.wav"
}

-- The D.I.H. keeps reconstruction, wound closure, and volume/oxygen support as
-- distinct passes. The live planner below orders them by current danger while
-- mechanical circulation can operate concurrently during cardiac arrest.
local StitchFields = {
    "arteria", "rarmartery", "larmartery", "rlegartery", "llegartery", "aorta",
    "rvein", "lvein", "spinevein", "pulmvein", "rarmvein", "larmvein", "rlegvein", "llegvein"
}

-- Complex mode is reserved for immediately life-threatening trauma: vital
-- organs, thoracic/cranial damage, and complications from internal bleeding.
local ComplexFields = {
    "skull", "chest", "heart", "brain", "trachea", "hemothoraxTrauma", "cardiacTamponade",
    "hemothoraxL", "hemothoraxR", "brainFrontal",
    "brainParietal", "brainTemporal", "brainOccipital", "brainHemorrhage",
    "brainBleedRate"
}

-- These are consequences recalculated by the organism from the injuries above.
-- Relieve them during surgery, but never use them by themselves to select a new
-- complex pass or the unit can repeatedly announce the same completed mode.
local ComplexReliefFields = {
    "hemothorax", "brainSwelling", "intracranialPressure", "internalBleedComplication",
    "neckBrainOxygenPenalty", "arterialO2Impairment", "throatCutPressureShock"
}

-- Generic mode reconstructs bones and non-vital abdominal organs.  Keep these
-- separate from ComplexFields so a patient is re-evaluated between the two
-- passes instead of treating every injury as critical surgery.
local SimpleFields = {
    "jaw", "pelvis", "lleg", "rleg", "larm", "rarm", "spine1", "spine2", "spine3",
    "eyeL", "eyeR", "headtrauma", "pneumothorax", "liver", "stomach", "intestines"
}

local RecoveryFields = {
    "painadd", "avgpain", "shock", "concussion", "stamina_damage", "ischemia", "seizure",
    "hypoxiaTime", "severeHypoxiaTime", "systemicIschemiaTime", "arrhythmia",
    "palpitations", "heartStrain"
}

local RecoveryReliefFields = {
    "pain", "immobilization", "disorientation", "hypoxia"
}

local DeliveryFields = {
    "bodyoxygen", "perfusion", "brainoxygen", "peripheralperfusion",
    "cerebralPerfusion", "myocardialOxygen"
}

local DeliveryColdTargets = {
    bodyoxygen = 0.82,
    perfusion = 0.70,
    brainoxygen = 0.86,
    peripheralperfusion = 0.46,
    cerebralPerfusion = 0.86,
    myocardialOxygen = 0.86
}

local ClearFlags = {
    "llegdislocation", "rlegdislocation", "larmdislocation", "rarmdislocation",
    "llegdislocated", "rlegdislocated", "larmdislocated", "rarmdislocated",
    "jawdislocation"
}

local function GetUnitTarget(ent)
    if not IsValid(ent) then return end
    if ent:IsPlayer() then
        local rag = ent.GetRagdollEntity and ent:GetRagdollEntity()
        return IsValid(rag) and rag or ent, ent
    end
    if ent:IsRagdoll() then
        local ply = hg and hg.RagdollOwner and hg.RagdollOwner(ent)
        if not IsValid(ply) then
            ply = IsValid(ent.OrgOwner) and ent.OrgOwner or ent:GetNWEntity("FakeRagdollParent")
        end
        return ent, IsValid(ply) and ply or nil
    end
end

local function GetCurrentUnitTarget(ply, fallback)
    if IsValid(fallback) and fallback:IsRagdoll() then return fallback end
    if IsValid(ply) then
        local rag = ply.GetRagdollEntity and ply:GetRagdollEntity()
        if IsValid(rag) and (not IsValid(fallback) or not ply:Alive()) then return rag end
    end
    return IsValid(fallback) and fallback or nil
end

local function GetUnitOrganism(ply, target)
    if IsValid(target) and target:IsRagdoll() and target.organism then return target.organism end
    if IsValid(ply) and ply.organism then return ply.organism end
    if IsValid(target) and target.organism then return target.organism end
end

local function PositionUnit(unit, target, bone, posOffset, angOffset, femOffset)
    if not IsValid(unit) or not IsValid(target) then return end
    local matrix = target:GetBoneMatrix(bone)
    if not matrix then return end
    local bonePos, boneAng = matrix:GetTranslation(), matrix:GetAngles()
    if femOffset and string.find(string.lower(target:GetModel() or ""), "female") then
        bonePos:Add(boneAng:Forward() * femOffset[1] + boneAng:Up() * femOffset[2] + boneAng:Right() * femOffset[3])
    end
    local pos, ang = LocalToWorld(posOffset, angOffset, bonePos, boneAng)
    unit:SetPos(pos)
    unit:SetAngles(ang)
end

local function QueueUnitSound(unit, snd, level, pitch)
    if not IsValid(unit) or not snd then return end
    unit.ASSoundQueue = unit.ASSoundQueue or {}
    table.insert(unit.ASSoundQueue, {sound = snd, level = level or 75, pitch = pitch or 100})
end

-- Keep sound routing identical to the AED: the attached model is visual-only,
-- while the patient is a reliable replicated source for nearby listeners.
local function GetUnitSoundEmitter(unit)
    if not IsValid(unit) then return end
    return IsValid(unit.ASSoundEmitter) and unit.ASSoundEmitter or unit
end

local function PlayUnitSound(unit, snd, level, pitch)
    if not IsValid(unit) or not snd then return end
    local emitter = GetUnitSoundEmitter(unit)
    if IsValid(emitter) then emitter:EmitSound(snd, level or 75, pitch or 100) end
end

local function StopUnitSound(unit, snd, emitter)
    if not IsValid(unit) or not snd then return end
    emitter = IsValid(emitter) and emitter or GetUnitSoundEmitter(unit)
    unit:StopSound(snd)
    if IsValid(emitter) and emitter != unit then emitter:StopSound(snd) end
end

local function ProcessUnitSounds(unit, config)
    if not IsValid(unit) then return true end
    local now = CurTime()
    if unit.ASPlayingSound then
        if (unit.ASSoundEndsAt or 0) > now then return true end
        StopUnitSound(unit, unit.ASPlayingSound, unit.ASPlayingEmitter)
        unit.ASPlayingSound = nil
        unit.ASPlayingEmitter = nil
        unit.ASSoundEndsAt = nil
        unit.ASCooldownUntil = now + config.SoundCooldown
    end
    if (unit.ASCooldownUntil or 0) > now then return true end

    local queue = unit.ASSoundQueue
    if not queue or #queue <= 0 then return false end

    local nextSound = table.remove(queue, 1)
    PlayUnitSound(unit, nextSound.sound, nextSound.level, nextSound.pitch)
    unit.ASPlayingSound = nextSound.sound
    unit.ASPlayingEmitter = GetUnitSoundEmitter(unit)
    unit.ASSoundEndsAt = now + math.max(SoundDuration(nextSound.sound), 0)
    return true
end

local function StopUnitSounds(unit)
    if not IsValid(unit) then return end
    for _, snd in pairs(ASSounds) do StopUnitSound(unit, snd) end
    for _, snd in ipairs(ASScanSounds) do StopUnitSound(unit, snd) end
    unit.ASPlayingSound = nil
    unit.ASPlayingEmitter = nil
    unit.ASSoundEndsAt = nil
    unit.ASCooldownUntil = nil
end

local function TableHasBleeding(tbl)
    for _, wound in pairs(tbl or {}) do
        if wound and (tonumber(wound[1]) or 0) > 0.01 then return true end
    end
    return false
end

local function SumFields(org, fields)
    local total = 0
    for _, key in ipairs(fields) do total = total + math.max(tonumber(org[key]) or 0, 0) end
    return total
end

local function GetWoundBurden(tbl)
    local count, burden = 0, 0
    for _, wound in pairs(tbl or {}) do
        local amount = wound and math.max(tonumber(wound[1]) or 0, 0) or 0
        if amount > 0.01 then
            count = count + 1
            burden = burden + amount
        end
    end
    return count, burden
end

local function HasFieldsAbove(org, fields, threshold)
    for _, key in ipairs(fields) do
        if (tonumber(org[key]) or 0) > threshold then return true end
    end
    return false
end

local function HasStitchingWork(org)
    return HasFieldsAbove(org, StitchFields, 0.001) or TableHasBleeding(org.wounds) or TableHasBleeding(org.arterialwounds)
end

local function HasComplexWork(org)
    if HasFieldsAbove(org, ComplexFields, 0.001)
        or (tonumber(org.brainBleedRate) or 0) > 0.00001
        or (org.internalBleed or 0) > 0.01
        or org.choking or org.vomitInThroat then return true end
    return istable(org.lungsL) and ((org.lungsL[1] or 0) > 0.001 or (org.lungsL[2] or 0) > 0) or
        istable(org.lungsR) and ((org.lungsR[1] or 0) > 0.001 or (org.lungsR[2] or 0) > 0)
end

local function HasSimpleWork(org)
    if HasFieldsAbove(org, SimpleFields, 0.001) then return true end
    for _, key in ipairs(ClearFlags) do
        if org[key] then return true end
    end
    return false
end

local function HasAnatomicalSupportBlocker(org)
    local leftLung = istable(org.lungsL) and (tonumber(org.lungsL[1]) or 0) or 0
    local rightLung = istable(org.lungsR) and (tonumber(org.lungsR[1]) or 0) or 0
    return (tonumber(org.heart) or 0) >= 0.55
        or (tonumber(org.trachea) or 0) >= 0.55
        or leftLung >= 0.70 or rightLung >= 0.70
        or org.choking or org.vomitInThroat
end

local function HasDeliveryDeficit(org)
    local coldPriority = math.Clamp((35 - (tonumber(org.temperature) or 36.7)) / 5, 0, 1)
    for _, key in ipairs(DeliveryFields) do
        local target = Lerp(coldPriority, 0.92, DeliveryColdTargets[key] or 0.92)
        if (tonumber(org[key]) or 1) < target then return true end
    end
    return false
end

local function HasRecoveryWork(org)
    local oxygen = istable(org.o2) and (tonumber(org.o2[1]) or 0) or 0
    local oxygenMax = istable(org.o2) and math.max(tonumber(org.o2.range) or 30, 1) or 0
    return (tonumber(org.blood) or 5000) < 4975
        or oxygen < oxygenMax * 0.96
        or HasDeliveryDeficit(org)
        or HasFieldsAbove(org, RecoveryFields, 0.01)
        or (tonumber(org.opioidRespiratoryDepression) or 0) > 0.15
        or org.respiratoryArrest == true
end

local function HasTreatableInjury(org)
    if not org then return false end
    return HasComplexWork(org) or HasStitchingWork(org) or HasSimpleWork(org) or HasRecoveryWork(org)
end

local function ModeHasWork(org, mode)
    if mode == 1 then return HasComplexWork(org) end
    if mode == 2 then return HasStitchingWork(org) end
    if mode == 3 then return HasSimpleWork(org) end
    if mode == 4 then return HasRecoveryWork(org) end
    return false
end

-- Score actual causes and live danger rather than walking a fixed mode list.
-- The active mode gets a small hysteresis bonus, so modest stat movement does
-- not make the device oscillate between two modes every treatment tick.
local function GetTreatmentModeScore(org, mode, activeMode)
    if not ModeHasWork(org, mode) then return 0 end

    local score = 0
    if mode == 1 then
        local leftLung = istable(org.lungsL) and ((tonumber(org.lungsL[1]) or 0) + (tonumber(org.lungsL[2]) or 0)) or 0
        local rightLung = istable(org.lungsR) and ((tonumber(org.lungsR[1]) or 0) + (tonumber(org.lungsR[2]) or 0)) or 0
        score = SumFields(org, ComplexFields) * 5
            + ((tonumber(org.heart) or 0) + (tonumber(org.trachea) or 0)) * 24
            + ((tonumber(org.brain) or 0) + (tonumber(org.brainHemorrhage) or 0)) * 20
            + math.Clamp((tonumber(org.brainBleedRate) or 0) / 0.0035, 0, 1) * 18
            + (leftLung + rightLung) * 12
            + math.Clamp((tonumber(org.internalBleed) or 0) / 4, 0, 2.5) * 14
            + (tonumber(org.cardiacTamponade) or 0) * 18
        if HasAnatomicalSupportBlocker(org) then score = score + 40 end
        if org.choking or org.vomitInThroat then score = score + 24 end
    elseif mode == 2 then
        local woundCount, woundBurden = GetWoundBurden(org.wounds)
        local arteryCount, arteryBurden = GetWoundBurden(org.arterialwounds)
        score = SumFields(org, StitchFields) * 10
            + woundCount * 3 + math.Clamp(woundBurden / 8, 0, 8)
            + arteryCount * 12 + math.Clamp(arteryBurden / 4, 0, 16)
            + math.Clamp((tonumber(org.venousBleed) or 0) / 8, 0, 8)
            + math.Clamp((tonumber(org.arterialBleed) or 0) / 4, 0, 18)
    elseif mode == 3 then
        score = SumFields(org, SimpleFields) * 6
        for _, key in ipairs(ClearFlags) do
            if org[key] then score = score + 4 end
        end
    else
        local blood = tonumber(org.blood) or 5000
        local oxygen = istable(org.o2) and (tonumber(org.o2[1]) or 0) or 30
        local oxygenMax = istable(org.o2) and math.max(tonumber(org.o2.range) or 30, 1) or 30
        score = math.Clamp((5000 - blood) / 5000, 0, 1) * 20
            + math.Clamp(1 - oxygen / oxygenMax, 0, 1) * 16
            + math.Clamp((tonumber(org.pain) or 0) / 100, 0, 1) * 4
            + math.Clamp((tonumber(org.painadd) or 0) / 100, 0, 1) * 3
            + math.Clamp((tonumber(org.avgpain) or 0) / 100, 0, 1) * 3
            + math.Clamp((tonumber(org.shock) or 0) / 10, 0, 1) * 5
            + math.Clamp((tonumber(org.immobilization) or 0) / 10, 0, 1) * 2
            + math.Clamp((tonumber(org.disorientation) or 0) / 10, 0, 1) * 2
            + math.Clamp((tonumber(org.concussion) or 0) / 6, 0, 1) * 4
            + math.Clamp(tonumber(org.ischemia) or 0, 0, 1) * 10
            + math.Clamp(tonumber(org.seizure) or 0, 0, 1) * 7
            + math.Clamp(tonumber(org.hypoxia) or 0, 0, 1) * 8
            + math.Clamp((tonumber(org.hypoxiaTime) or 0) / 120, 0, 1) * 6
            + math.Clamp((tonumber(org.severeHypoxiaTime) or 0) / 120, 0, 1) * 8
            + math.Clamp((tonumber(org.systemicIschemiaTime) or 0) / 180, 0, 1) * 6
            + math.Clamp(tonumber(org.arrhythmia) or 0, 0, 1) * 6
            + math.Clamp(tonumber(org.palpitations) or 0, 0, 1) * 4
            + math.Clamp(tonumber(org.heartStrain) or 0, 0, 1) * 6
        local coldPriority = math.Clamp((35 - (tonumber(org.temperature) or 36.7)) / 5, 0, 1)
        for _, key in ipairs(DeliveryFields) do
            local target = Lerp(coldPriority, 0.92, DeliveryColdTargets[key] or 0.92)
            score = score + math.Clamp((target - (tonumber(org[key]) or 1)) / math.max(target, 0.01), 0, 1) * 4
        end
        if org.respiratoryArrest then score = score + 24 end
        score = score + math.Clamp(tonumber(org.opioidRespiratoryDepression) or 0, 0, 1) * 16
        if HasAnatomicalSupportBlocker(org) then score = score * 0.25 end
    end

    score = math.max(score, 0.1)
    if mode == activeMode then score = score * 1.15 end
    return score
end

local function GetNextTreatmentMode(org, activeMode)
    local bestMode, bestScore
    for mode = 1, 4 do
        local score = GetTreatmentModeScore(org, mode, activeMode)
        if score > 0 and (not bestScore or score > bestScore) then
            bestMode, bestScore = mode, score
        end
    end
    return bestMode, bestScore or 0
end

local function HealWoundTable(tbl, amount)
    local changed = false
    for i = #(tbl or {}), 1, -1 do
        local wound = tbl[i]
        if not wound then
            table.remove(tbl, i)
            changed = true
        else
            local old = tonumber(wound[1]) or 0
            wound[1] = math.max(old - amount, 0)
            changed = changed or wound[1] != old
            if wound[1] <= 0 then table.remove(tbl, i) end
        end
    end
    return changed
end

local function HealFields(org, fields, amount)
    for _, key in ipairs(fields) do
        if isnumber(org[key]) then org[key] = math.Approach(org[key], 0, amount) end
    end
end

local function HealStitching(org, config)
    HealFields(org, StitchFields, config.InjuryHeal)
    local woundsChanged = HealWoundTable(org.wounds, config.BleedHeal)
    local arteriesChanged = HealWoundTable(org.arterialwounds, config.BleedHeal)
    if arteriesChanged and hg and hg.organism and hg.organism.RebuildArteryWoundState then
        hg.organism.RebuildArteryWoundState(org, true)
    elseif woundsChanged and IsValid(org.owner) and hg and hg.organism and hg.organism.SyncWoundsNet then
        hg.organism.SyncWoundsNet(org)
    end
end

local function HealComplex(org, config)
    HealFields(org, ComplexFields, config.InjuryHeal)
    HealFields(org, ComplexReliefFields, config.InjuryHeal * 0.75)
    if istable(org.lungsL) then
        org.lungsL[1] = math.Approach(org.lungsL[1] or 0, 0, config.InjuryHeal)
        org.lungsL[2] = math.Approach(org.lungsL[2] or 0, 0, config.InjuryHeal)
    end
    if istable(org.lungsR) then
        org.lungsR[1] = math.Approach(org.lungsR[1] or 0, 0, config.InjuryHeal)
        org.lungsR[2] = math.Approach(org.lungsR[2] or 0, 0, config.InjuryHeal)
    end
    org.internalBleed = math.Approach(org.internalBleed or 0, 0, config.InternalBleedHeal)
    org.internalBleedHeal = math.max(org.internalBleedHeal or 0, config.InternalBleedHeal * 2)
    if org.internalBleed <= 0.01 then
        -- Clear progression memory only after the source is repaired. Keeping a
        -- high historical peak made the organism rebuild complications and send
        -- the unit straight back into complex mode after it had just completed.
        org.internalBleed = 0
        org.internalBleedDuration = 0
        org.internalBleedPeak = 0
        org.internalBleedHemothoraxRisk = false
        org.internalBleedComplication = math.Approach(org.internalBleedComplication or 0, 0, config.InjuryHeal)
    end
    org.lungsfunction = true
    org.choking = false
    org.vomitInThroat = false
    org.throatcut = false
    org.neckslit = false
    org.internalBleedLungSide = nil
    org.tracheaPath = nil
end

local function HealSimple(org, config)
    local oldSpine1 = tonumber(org.spine1) or 0
    local oldSpine2 = tonumber(org.spine2) or 0
    local oldSpine3 = tonumber(org.spine3) or 0
    local oldPelvis = tonumber(org.pelvis) or 0
    HealFields(org, SimpleFields, config.InjuryHeal)

    -- Spine damage also creates ragdoll constraints.  Healing the organism
    -- value alone leaves the patient physically broken, so release each
    -- repaired segment as soon as it crosses its movement threshold.
    if hg and hg.RemoveSpineConstraints then
        local organism = hg.organism or {}
        local spine1Threshold = organism.fake_spine1 or 1
        local spine2Threshold = organism.fake_spine2 or 1
        local spine3Threshold = organism.fake_spine3 or 1
        if (oldSpine1 >= spine1Threshold and (org.spine1 or 0) < spine1Threshold)
            or (oldPelvis >= 1 and (org.pelvis or 0) < 1) then
            hg.RemoveSpineConstraints(org.owner, "spine1")
        end
        if oldSpine2 >= spine2Threshold and (org.spine2 or 0) < spine2Threshold then
            hg.RemoveSpineConstraints(org.owner, "spine2")
        end
        if oldSpine3 >= spine3Threshold and (org.spine3 or 0) < spine3Threshold then
            hg.RemoveSpineConstraints(org.owner, "spine3")
        end
    end

    org.eyeLDestroyed = nil
    org.eyeRDestroyed = nil
    for _, key in ipairs(ClearFlags) do org[key] = false end
end

local function RestoreBloodAndOxygen(org, config)
    org.blood = math.Approach(tonumber(org.blood) or 5000, 5000, config.BloodRestore)
    HealFields(org, ComplexReliefFields, config.InjuryHeal * 0.5)

    for _, key in ipairs(RecoveryFields) do
        if isnumber(org[key]) then
            org[key] = math.Approach(org[key], 0, config.InjuryHeal * 12)
        end
    end
    HealFields(org, RecoveryReliefFields, config.InjuryHeal * 12)

    -- The current organism derives respiratory arrest from opioid load. Give
    -- antidote support before attempting oxygen recovery so the support helper
    -- does not correctly reject an airway whose drive is still suppressed.
    local opioidDepression = tonumber(org.opioidRespiratoryDepression) or 0
    if opioidDepression > 0.15 or org.respiratoryArrest then
        org.naloxoneadd = math.max(tonumber(org.naloxoneadd) or 0, 0.65)
        org.naloxone = math.max(tonumber(org.naloxone) or 0, 1.5)
    end

    if hg and hg.organism and hg.organism.RestoreSupportedOxygen then
        hg.organism.RestoreSupportedOxygen(org, config.OxygenRecovery, {
            oxygen = 8,
            oxygenTarget = istable(org.o2) and (tonumber(org.o2.range) or 30) or 30,
            bodyoxygen = 0.45, bodyoxygenTarget = 0.96,
            brainoxygen = 0.45, brainoxygenTarget = 0.96,
            perfusion = 0.42, perfusionTarget = 0.94,
            peripheralperfusion = 0.38, peripheralperfusionTarget = 0.92,
            cerebralPerfusion = 0.42, cerebralPerfusionTarget = 0.95,
            myocardialOxygen = 0.45, myocardialOxygenTarget = 0.96,
            hypoxiaTime = 2, severeHypoxiaTime = 1, systemicIschemiaTime = 2
        })
    elseif istable(org.o2) then
        local oxygenMax = math.max(tonumber(org.o2.range) or 30, 1)
        org.o2[1] = math.Approach(tonumber(org.o2[1]) or 0, oxygenMax, config.OxygenRecovery * oxygenMax)
    end
end

local function ApplyAutopulse(org, config)
    local now = CurTime()
    org.dihAutopulseUntil = now + config.AutopulseInterval * 1.5
    org.dihSupportUntil = org.dihAutopulseUntil
    org.cprResuscitationUntil = math.max(tonumber(org.cprResuscitationUntil) or 0, now + 2)
    org.aedResuscitationUntil = math.max(tonumber(org.aedResuscitationUntil) or 0, now + 15)
    org.defibDeathGrace = math.max(tonumber(org.defibDeathGrace) or 0, now + 20)
    org.fibrillation = false
    if org.terminalRhythm == "ventricular_fibrillation" then org.terminalRhythm = nil end
    org.arrhythmia = math.max((tonumber(org.arrhythmia) or 0) - 0.35, 0)
    org.heartStrain = math.max((tonumber(org.heartStrain) or 0) - 0.18, 0)
    org.pulse = 70
    org.heartbeat = 70
    org.cardiacOutput = math.max(tonumber(org.cardiacOutput) or 0, 0.55)
    org.strokeVolume = math.max(tonumber(org.strokeVolume) or 0, 0.50)
    org.hypotension = math.min(tonumber(org.hypotension) or 1, 0.50)

    -- A circulation assist is only useful if it also has enough volume and
    -- oxygen to circulate.  This is deliberately limited to an emergency
    -- bridge, rather than replacing the unit's normal blood-restoration pass.
    local blood = tonumber(org.blood) or 5000
    if blood < config.AutopulseBloodFloor then
        org.blood = math.min(blood + config.AutopulseBloodRestore, config.AutopulseBloodFloor)
    end

    -- Give a small mannitol dose only when cerebral pressure is actually a
    -- concern; dosing every beat on an otherwise stable patient is needless.
    local cerebralEmergency = (tonumber(org.intracranialPressure) or 0) > 0.20
        or (tonumber(org.brainSwelling) or 0) > 0.20
        or (tonumber(org.brainHemorrhage) or 0) > 0.15
    if cerebralEmergency then
        org.mannitol = math.Approach(tonumber(org.mannitol) or 0,
            config.AutopulseMannitolTarget, config.AutopulseMannitolDose)
    end

    if hg and hg.organism and hg.organism.RestoreSupportedOxygen then
        hg.organism.RestoreSupportedOxygen(org, config.AutopulseOxygenRecovery, {
            artificialSupport = true,
            oxygen = config.AutopulseOxygenFloor,
            oxygenTarget = 30,
            bodyoxygen = 0.60, bodyoxygenTarget = 0.90,
            brainoxygen = 0.60, brainoxygenTarget = 0.88,
            perfusion = 0.55, perfusionTarget = 0.82,
            peripheralperfusion = 0.50, peripheralperfusionTarget = 0.78,
            cerebralPerfusion = 0.55, cerebralPerfusionTarget = 0.84,
            myocardialOxygen = 0.60, myocardialOxygenTarget = 0.88,
            hypoxiaTime = 0, severeHypoxiaTime = 0, systemicIschemiaTime = 0
        })
    end

    if hg and hg.organism and hg.organism.TryRestartHeartWithResuscitation then
        hg.organism.TryRestartHeartWithResuscitation(org)
    end
end

local function ClearTargetState(target, ply, unit)
    if IsValid(target) and target.AutosurgeonModelEnt == unit then
        target.AutosurgeonModelEnt = nil
        target.AutosurgeonInProgress = nil
    end
    if IsValid(ply) and ply.AutosurgeonModelEnt == unit then
        ply.AutosurgeonModelEnt = nil
        ply.AutosurgeonInProgress = nil
    end
end

local function DropUnit(unit, target, ply, battery, snd)
    if not IsValid(unit) or unit.ASDropped then return end
    unit.ASDropped = true
    StopUnitSounds(unit)
    local pos, ang = unit:GetPos(), unit:GetAngles()
    ClearTargetState(target, ply, unit)

    local pickup = ents.Create("prop_physics")
    if IsValid(pickup) then
        pickup:SetModel("models/w_models/weapons/w_eq_medkit.mdl")
        pickup:SetPos(pos + Vector(0, 0, 4))
        pickup:SetAngles(ang)
        pickup:SetUseType(SIMPLE_USE)
        pickup:Spawn()
        pickup:Activate()
        pickup:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        pickup.IsDroppedAutosurgeon = true
        pickup.AutosurgeonBattery = math.max(math.floor(battery or 0), 0)
        pickup:EmitSound(ASSounds.removed, 75, 100)
        if snd then pickup:EmitSound(snd, 75, 100) end
    elseif snd then
        sound.Play(ASSounds.removed, pos, 75, 100)
        sound.Play(snd, pos, 75, 100)
    else
        sound.Play(ASSounds.removed, pos, 75, 100)
    end
    unit:Remove()
end

local function TraceUnitTarget(owner, range)
    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * range,
        filter = owner,
        mask = MASK_SHOT_HULL
    })
    return GetUnitTarget(tr.Entity)
end

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "AttachStart")
    self:NetworkVar("Float", 1, "AttachFinish")
    self:NetworkVar("Bool", 0, "AttachSelf")
end

function SWEP:CanOperate(owner)
    if not IsValid(owner) or not owner.organism or not hg or not hg.organism then return true end
    local fake2 = hg.organism.fake_spine2 or 1
    local fake3 = hg.organism.fake_spine3 or 1
    if owner.organism.spine2 >= fake2 or owner.organism.spine3 >= fake3 then
        if SERVER then owner:Notify("You can't do that with a broken spine!", 1, "spine_fail", 3) end
        return false
    end
    return true
end

function SWEP:BeginPlacement(target, ply, attack, selfUse)
    local owner = self:GetOwner()
    if not IsValid(owner) or not self:CanOperate(owner) or self.Applying then return end
    if self:Clip1() <= 0 then
        owner:EmitSound(ASSounds.battery)
        owner:PrintMessage(HUD_PRINTCENTER, "Autosurgeon needs a battery")
        return
    end
    if not IsValid(target) or not IsValid(ply) or not ply.organism then return end
    if IsValid(target.AutosurgeonModelEnt) or target.AutosurgeonInProgress or IsValid(ply.AutosurgeonModelEnt) or ply.AutosurgeonInProgress then return end
    self.Applying = {
        target = target,
        ply = ply,
        start = CurTime(),
        finish = CurTime() + self.AttachTime,
        attack = attack,
        selfUse = selfUse
    }
    self:SetAttachStart(self.Applying.start)
    self:SetAttachFinish(self.Applying.finish)
    self:SetAttachSelf(selfUse or false)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.05)
    if CLIENT then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local target, ply = TraceUnitTarget(owner, self.AttachRange)
    if not IsValid(target) or not IsValid(ply) or ply == owner then return end
    self:BeginPlacement(target, ply, IN_ATTACK, false)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.05)
    if CLIENT then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local target = GetCurrentUnitTarget(owner, owner)
    self:BeginPlacement(target, owner, IN_ATTACK2, true)
end

function SWEP:CancelPlacement()
    self.Applying = nil
    self:SetAttachStart(0)
    self:SetAttachFinish(0)
    self:SetAttachSelf(false)
end

function SWEP:AttachUnit(owner, target, ply)
    if not IsValid(owner) or not IsValid(target) or not IsValid(ply) or not ply.organism then return end
    if IsValid(target.AutosurgeonModelEnt) or target.AutosurgeonInProgress then return end
    local bone = target:LookupBone(self.UnitBone)
    if not bone or not target:GetBoneMatrix(bone) then return end

    local battery = self:Clip1()
    if battery <= 0 then return end
    local config = self.Config
    local unitBone = self.UnitBone
    local unitPos = self.UnitPos
    local unitAng = self.UnitAng
    local unitFemPos = self.UnitFemPos
    local weaponClass = self:GetClass()
    local unit = ents.Create("prop_dynamic")
    if not IsValid(unit) then return end
    unit:SetModel(self.WorldModel)
    unit:SetSolid(SOLID_NONE)
    unit:Spawn()
    unit:SetMoveType(MOVETYPE_NONE)
    unit.ASSoundEmitter = target
    unit:SetNWInt("AutosurgeonBattery", battery)
    owner:SetNWEntity("AutosurgeonModelEnt", unit)
    PositionUnit(unit, target, bone, unitPos, unitAng, unitFemPos)

    target.AutosurgeonModelEnt = unit
    target.AutosurgeonInProgress = true
    ply.AutosurgeonModelEnt = unit
    ply.AutosurgeonInProgress = true
    -- The scan is an explicit first phase. Its WAV duration is tracked by the
    -- sound processor, which also enforces SoundCooldown after it finishes;
    -- treatment cannot begin until both have elapsed.
    local scanSound = ASScanSounds[math.random(#ASScanSounds)]
    unit.ASSoundEmitter = target
    PlayUnitSound(unit, ASSounds.mounted)
    PlayUnitSound(unit, scanSound)
    unit.ASPlayingSound = scanSound
    unit.ASPlayingEmitter = GetUnitSoundEmitter(unit)
    unit.ASSoundEndsAt = CurTime() + math.max(SoundDuration(scanSound), 0)
    owner:ViewPunch(Angle(5, 0, 0))

    local timerName = "AutosurgeonFollow" .. unit:EntIndex()
    local activeTarget = target
    local scanning = true
    local nextTreatment = CurTime()
    local nextAutopulse = CurTime()
    local treatmentMode
    local modeTicks = 0
    local modeClearTicks = 0
    local stableTicks = 0
    local completedModeAnnouncements = {}
    local lastAnnouncedMode
    local painkillerTarget
    local painkillerAnnounced = false
    local movingSince

    unit:CallOnRemove("AutosurgeonCleanup", function()
        timer.Remove(timerName)
        StopUnitSounds(unit)
        ClearTargetState(activeTarget, ply, unit)
        if IsValid(owner) and owner:GetNWEntity("AutosurgeonModelEnt") == unit then
            owner:SetNWEntity("AutosurgeonModelEnt", NULL)
        end
        unit.ASSoundEmitter = nil
    end)

    timer.Create(timerName, 0, 0, function()
        if not IsValid(unit) then timer.Remove(timerName) return end
        local currentTarget = GetCurrentUnitTarget(ply, activeTarget)
        if not IsValid(currentTarget) or not IsValid(ply) then
            DropUnit(unit, activeTarget, ply, battery)
            return
        end

        if currentTarget != activeTarget then
            ClearTargetState(activeTarget, ply, unit)
            activeTarget = currentTarget
            activeTarget.AutosurgeonModelEnt = unit
            activeTarget.AutosurgeonInProgress = true
            ply.AutosurgeonModelEnt = unit
            ply.AutosurgeonInProgress = true
        end
        unit.ASSoundEmitter = activeTarget
        local currentBone = activeTarget:LookupBone(unitBone)
        if currentBone then PositionUnit(unit, activeTarget, currentBone, unitPos, unitAng, unitFemPos) end

        if unit.ASPendingDrop then
            DropUnit(unit, activeTarget, ply, battery)
            return
        end

        if activeTarget:GetVelocity():LengthSqr() > 160 * 160 then
            movingSince = movingSince or CurTime()
            if movingSince + 1.25 < CurTime() then
                DropUnit(unit, activeTarget, ply, battery)
                return
            end
        else
            movingSince = nil
        end

        local org = GetUnitOrganism(ply, activeTarget)
        if not org or not org.alive then
            DropUnit(unit, activeTarget, ply, battery)
            return
        end

        -- Mechanical support runs alongside surgery. An arrested patient should
        -- not spend several seconds without circulation while the unit closes a
        -- wound or repairs the organ that caused the arrest.
        local needsAutopulse = org.heartstop or org.fibrillation
            or org.terminalRhythm == "ventricular_fibrillation"
            or ((tonumber(org.pulse) or 0) <= 0 and (tonumber(org.cardiacOutput) or 0) <= 0.08)
        if needsAutopulse and CurTime() >= nextAutopulse then
            if battery < config.AutopulseBatteryPerBeat then
                -- Battery depletion is terminal for an attached unit: stop
                -- treatment and eject it immediately instead of waiting for
                -- the sound queue or another timer tick.
                DropUnit(unit, activeTarget, ply, battery, ASSounds.suddenStop)
                return
            end
            battery = battery - config.AutopulseBatteryPerBeat
            unit:SetNWInt("AutosurgeonBattery", battery)
            ApplyAutopulse(org, config)
            -- Do not queue this behind scan/mode announcements: one pump.ogg
            -- is emitted for every completed mechanical pulse.
            PlayUnitSound(unit, ASSounds.pump, 65, 100)
            nextAutopulse = CurTime() + config.AutopulseInterval
        end

        local soundBusy = ProcessUnitSounds(unit, config)
        if scanning and soundBusy then return end

        -- Start treatment in the same tick the scan ends.  When the scan did
        -- not find a treatment mode, the normal completion path below removes
        -- the unit instead of leaving it idle on the patient.
        if scanning then
            scanning = false
            nextTreatment = CurTime()
        end
        if CurTime() < nextTreatment then return end
        nextTreatment = CurTime() + config.TickInterval

        -- Require several clear observations before completing a mode. Derived
        -- organism values update on a different timer and can briefly lag one
        -- tick behind their repaired source. Do this before considering another
        -- mode so an apparently finished pass cannot be abandoned and rebound.
        if treatmentMode and not ModeHasWork(org, treatmentMode) then
            modeClearTicks = modeClearTicks + 1
            if modeClearTicks >= config.ModeClearTicks then
                if not completedModeAnnouncements[treatmentMode] then
                    QueueUnitSound(unit, ASSounds.modeComplete)
                    completedModeAnnouncements[treatmentMode] = true
                end
                treatmentMode = nil
                modeTicks = 0
                modeClearTicks = 0
            end
            return
        end
        modeClearTicks = 0

        local recommendedMode, recommendedScore = GetNextTreatmentMode(org, treatmentMode)
        if not treatmentMode then
            treatmentMode = recommendedMode
            if treatmentMode then
                modeTicks = 0
                modeClearTicks = 0
                stableTicks = 0
                if lastAnnouncedMode and lastAnnouncedMode != treatmentMode then
                    QueueUnitSound(unit, ASSounds.modeSwitch)
                end
                lastAnnouncedMode = treatmentMode
            end
        elseif recommendedMode and recommendedMode != treatmentMode and modeTicks >= config.ModeMinTicks then
            local activeScore = GetTreatmentModeScore(org, treatmentMode, treatmentMode)
            if activeScore <= 0 or recommendedScore >= activeScore * config.ModePreemptRatio then
                treatmentMode = recommendedMode
                modeTicks = 0
                modeClearTicks = 0
                stableTicks = 0
                if lastAnnouncedMode != treatmentMode then QueueUnitSound(unit, ASSounds.modeSwitch) end
                lastAnnouncedMode = treatmentMode
            end
        end

        if not treatmentMode then
            local unsafePainkiller = org.respiratoryArrest
                or (tonumber(org.opioidRespiratoryDepression) or 0) > 0.15
                or (tonumber(org.analgesia) or 0) > 1.2
                or (tonumber(org.painkiller) or 0) > 1.5
            if unsafePainkiller then
                painkillerTarget = nil
                painkillerAnnounced = false
            end
            if painkillerTarget then
                org.painkiller = math.min((tonumber(org.painkiller) or 0) + 0.25, painkillerTarget, 1)
                if org.painkiller >= painkillerTarget then
                    QueueUnitSound(unit, ASSounds.stimulator)
                    painkillerTarget = nil
                    painkillerAnnounced = false
                end
                return
            end

            if needsAutopulse or HasTreatableInjury(org) then
                stableTicks = 0
                return
            end
            if soundBusy then
                stableTicks = 0
                return
            end
            stableTicks = stableTicks + 1
            if stableTicks < config.StableTicks then return end
            DropUnit(unit, activeTarget, ply, battery, ASSounds.complete)
            return
        end
        if battery < config.BatteryPerTick then
            DropUnit(unit, activeTarget, ply, battery, ASSounds.suddenStop)
            return
        end

        battery = battery - config.BatteryPerTick
        unit:SetNWInt("AutosurgeonBattery", battery)
        modeTicks = modeTicks + 1

        local pain = tonumber(org.pain) or 0
        local canGivePainkiller = not org.respiratoryArrest
            and (tonumber(org.opioidRespiratoryDepression) or 0) <= 0.15
            and (tonumber(org.analgesia) or 0) <= 1.2
            and (tonumber(org.painkiller) or 0) < 1
        if pain > 50 and canGivePainkiller then
            local safeDose = math.min(1, math.max(0.25, (pain - 50) / 100))
            painkillerTarget = math.max(painkillerTarget or 0, safeDose)
            if not painkillerAnnounced then
                QueueUnitSound(unit, ASSounds.painkillerNeeded)
                painkillerAnnounced = true
            end
        end
        if treatmentMode == 1 then
            HealComplex(org, config)
        elseif treatmentMode == 2 then
            HealStitching(org, config)
        elseif treatmentMode == 3 then
            HealSimple(org, config)
        else
            RestoreBloodAndOxygen(org, config)
        end
    end)

    owner:StripWeapon(weaponClass)
end

function SWEP:Think()
    if CLIENT then
        local attachTime = self.AttachTime or 1
        local startTime, finishTime = self:GetAttachStart(), self:GetAttachFinish()
        local targetProgress = startTime > 0 and finishTime > CurTime() and math.Clamp((CurTime() - startTime) / attachTime, 0, 1) or 0
        self.AttachProgress = math.Approach(self.AttachProgress or 0, targetProgress, FrameTime() / attachTime)
        local selfUse = self:GetAttachSelf()
        local progress = self.AttachProgress
        self.RHPosOffset = LerpVector(progress, self.DefaultRHPosOffset, selfUse and self.SelfAttachRHPosOffset or self.AttachRHPosOffset)
        self.RHAngOffset = LerpAngle(progress, self.DefaultRHAngOffset, selfUse and self.SelfAttachRHAngOffset or self.AttachRHAngOffset)
        self.LHPosOffset = LerpVector(progress, self.DefaultLHPosOffset, selfUse and self.SelfAttachLHPosOffset or self.AttachLHPosOffset)
        self.LHAngOffset = LerpAngle(progress, self.DefaultLHAngOffset, selfUse and self.SelfAttachLHAngOffset or self.AttachLHAngOffset)
        self.offsetVec = LerpVector(progress, Vector(4, -0.5, -3), selfUse and self.SelfAttachHandPos or self.AttachHandPos)
        self.offsetAng = LerpAngle(progress, Angle(-30, 20, 90), selfUse and self.SelfAttachHandAng or self.AttachHandAng)
        return
    end

    local apply = self.Applying
    if not apply then return end
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:KeyDown(apply.attack) then self:CancelPlacement() return end
    if apply.finish > CurTime() then return end
    local target, ply
    if apply.selfUse then
        target, ply = GetCurrentUnitTarget(owner, owner), owner
    else
        target, ply = TraceUnitTarget(owner, self.AttachRange)
    end
    if target != apply.target or ply != apply.ply then self:CancelPlacement() return end
    self:CancelPlacement()
    self:AttachUnit(owner, target, ply)
end

if SERVER then
    util.AddNetworkString("AS_Recharge")

    hook.Add("PlayerUse", "AutosurgeonPickupUse", function(ply, ent)
        if not IsValid(ent) or not ent.IsDroppedAutosurgeon then return end
        local wep = ply:Give("weapon_autosurgeon_sh")
        if IsValid(wep) then wep:SetClip1(ent.AutosurgeonBattery or 0) end
        ent:Remove()
        return false
    end)

    net.Receive("AS_Recharge", function(_, ply)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() != "weapon_autosurgeon_sh" or not wep:CanOperate(ply) then return end
        local hasBattery = ply:GetAmmoCount("D.I.H Battery") > 0
        local hasTaser = ply:GetAmmoCount("Taser Cartridge") > 0
        if not hasBattery and not hasTaser then return end
        local current = wep:Clip1()
        if current >= wep.Config.BatteryMax then return end
        local source = hasBattery and "D.I.H Battery" or "Taser Cartridge"
        ply:RemoveAmmo(1, source)
        wep:SetClip1(math.min(current + wep.Config.BatteryRecharge[source], wep.Config.BatteryMax))
        wep:EmitSound(hasBattery and "panoptisscon/phone_simcard_insert.mp3" or "snd_jack_hmcd_ammobox.ogg")
    end)
end

if CLIENT then
    SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_medkit")
    SWEP.IconOverride = "vgui/wep_jack_hmcd_medkit.vmt"
    SWEP.BounceWeaponIcon = false

    function SWEP:DrawHUD()
        if GetViewEntity() != LocalPlayer() or LocalPlayer():InVehicle() then return end
        local maxBattery = ASConfig.BatteryMax
        local unit = LocalPlayer():GetNWEntity("AutosurgeonModelEnt")
        local battery = IsValid(unit) and unit:GetNWInt("AutosurgeonBattery", 0) or self:Clip1()
        local ratio = math.Clamp(battery / maxBattery, 0, 1)
        local width, height = 240, 16
        local barX, barY = (ScrW() - width) / 2, ScrH() - 58
        draw.RoundedBox(4, barX, barY, width, height, Color(0, 0, 0, 185))
        draw.RoundedBox(3, barX + 2, barY + 2, (width - 4) * ratio, height - 4, Color(80 + (1 - ratio) * 175, 200 * ratio, 70, 235))
        draw.SimpleText("D.I.H BATTERY  " .. math.Round(ratio * 100) .. "%", "HomigradFont", ScrW() / 2, barY - 3, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        local x, y = ScrW() / 2, ScrH() / 2 + 65
        local selfText = "Hold RMB to place autosurgeon on yourself"
        draw.SimpleText(selfText, "HomigradFont", x + 3, y + 26, color_black, TEXT_ALIGN_CENTER)
        draw.SimpleText(selfText, "HomigradFont", x, y + 24, color_white, TEXT_ALIGN_CENTER)
        local target, ply = TraceUnitTarget(LocalPlayer(), self.AttachRange)
        if not IsValid(target) or not IsValid(ply) or ply == LocalPlayer() then return end
        draw.SimpleText("Hold LMB to place autosurgeon", "HomigradFont", x + 3, y + 2, color_black, TEXT_ALIGN_CENTER)
        draw.SimpleText("Hold LMB to place autosurgeon", "HomigradFont", x, y, color_white, TEXT_ALIGN_CENTER)
    end

    local altWasDown = false
    hook.Add("Think", "AutosurgeonAltRadial", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() != "weapon_autosurgeon_sh" then altWasDown = false return end
        local altDown = input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
        if altDown and not altWasDown and (ply:GetAmmoCount("D.I.H Battery") > 0 or ply:GetAmmoCount("Taser Cartridge") > 0) then
            hg.CreateRadialMenu({
                {
                    function() net.Start("AS_Recharge") net.SendToServer() end,
                    "Recharge D.I.H"
                }
            })
        end
        altWasDown = altDown
    end)
end
