if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_tpik1_base"
SWEP.PrintName = "Portable D.I.H Unit"
SWEP.Instructions = "Hold LMB to place on a patient. Hold RMB to place on yourself."
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
        ["D.I.H Battery"] = 250,
        ["Taser Cartridge"] = 100
    },
    BatteryPerTick = 8,
    AutopulseBatteryPerBeat = 14,
    TickInterval = 0.5,
    AutopulseInterval = 60 / 70,
    SoundCooldown = 0.35,
    InjuryHeal = 0.06,
    BleedHeal = 1.5,
    InternalBleedHeal = 0.5,
    BloodRestore = 16
}

-- SWEP is only guaranteed to exist while this file is being loaded. Deferred
-- client hooks must retain the values they need instead of looking it up later.
local ASConfig = SWEP.Config

local ASSounds = {
    battery = "autonigger/buttons.ogg",
    mounted = "autonigger/autosurgeonon.ogg",
    pump = "autonigger/pump.ogg",
    modeComplete = "autonigger/completemode.ogg",
    modeSwitch = "autonigger/switchmode.ogg",
    painkillerNeeded = "autonigger/switch.ogg",
    stimulator = "autonigger/stimulator.ogg",
    removed = "autonigger/desert.ogg",
    complete = "autonigger/complete.ogg"
}

local ASScanSounds = {
    "autonigger/atireputas1.ogg",
    "autonigger/atireputas2.ogg",
    "autonigger/atireputas3.ogg"
}

-- The D.I.H. intentionally works in three passes. The order matters: closing
-- open vessels first prevents the later reconstruction passes from fighting an
-- active bleed.
local StitchFields = {
    "arteria", "rarmartery", "larmartery", "rlegartery", "llegartery", "spineartery",
    "rvein", "lvein", "spinevein", "pulmvein", "rarmvein", "larmvein", "rlegvein", "llegvein"
}

local ComplexFields = {
    "skull", "chest", "heart", "brain", "trachea", "hemothorax", "hemothoraxTrauma",
    "hemothoraxL", "hemothoraxR", "internalBleedComplication", "brainFrontal",
    "brainParietal", "brainTemporal", "brainOccipital", "brainHemorrhage", "brainSwelling",
    "intracranialPressure", "brainBleedRate", "neckBrainOxygenPenalty", "arterialO2Impairment",
    "throatCutPressureShock"
}

local SimpleFields = {
    "jaw", "pelvis", "lleg", "rleg", "larm", "rarm", "spine1", "spine2", "spine3",
    "eyeL", "eyeR", "headtrauma", "pneumothorax", "liver", "stomach", "intestines"
}

local RecoveryFields = {
    "pain", "painadd", "avgpain", "shock", "immobilization", "disorientation",
    "concussion", "stamina_damage", "ischemia"
}

local ClearFlags = {
    "llegdislocation", "rlegdislocation", "larmdislocation", "rarmdislocation",
    "llegdislocated", "rlegdislocated", "larmdislocated", "rarmdislocated",
    "jawdislocation", "throatcut", "neckslit"
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

local function ProcessUnitSounds(unit, config)
    if not IsValid(unit) then return true end
    if (unit.ASBusyUntil or 0) > CurTime() then return true end
    local queue = unit.ASSoundQueue
    if not queue or #queue <= 0 then return false end

    local nextSound = table.remove(queue, 1)
    local emitter = IsValid(unit.ASSoundEmitter) and unit.ASSoundEmitter or unit
    emitter:EmitSound(nextSound.sound, nextSound.level, nextSound.pitch)
    unit.ASBusyUntil = CurTime() + math.max(SoundDuration(nextSound.sound), 0) + config.SoundCooldown
    return true
end

local function StopUnitSounds(unit)
    if not IsValid(unit) then return end
    local emitter = IsValid(unit.ASSoundEmitter) and unit.ASSoundEmitter or unit
    for _, snd in pairs(ASSounds) do
        unit:StopSound(snd)
        if IsValid(emitter) and emitter != unit then emitter:StopSound(snd) end
    end
    for _, snd in ipairs(ASScanSounds) do
        unit:StopSound(snd)
        if IsValid(emitter) and emitter != unit then emitter:StopSound(snd) end
    end
end

local function TableHasBleeding(tbl)
    for _, wound in pairs(tbl or {}) do
        if wound and (tonumber(wound[1]) or 0) > 0 then return true end
    end
    return false
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
    if HasFieldsAbove(org, ComplexFields, 0.001) or (org.internalBleed or 0) > 0.01 then return true end
    return istable(org.lungsL) and ((org.lungsL[1] or 0) > 0.001 or (org.lungsL[2] or 0) > 0) or
        istable(org.lungsR) and ((org.lungsR[1] or 0) > 0.001 or (org.lungsR[2] or 0) > 0)
end

local function HasSimpleWork(org)
    if HasFieldsAbove(org, SimpleFields, 0.001) or HasFieldsAbove(org, RecoveryFields, 0.01) or (org.blood or 5000) < 4999 then return true end
    for _, key in ipairs(ClearFlags) do
        if org[key] then return true end
    end
    return false
end

local function HasTreatableInjury(org)
    if not org then return false end
    for _, key in ipairs(StitchFields) do
        if (tonumber(org[key]) or 0) > 0.001 then return true end
    end
    for _, key in ipairs(ComplexFields) do
        if (tonumber(org[key]) or 0) > 0.001 then return true end
    end
    for _, key in ipairs(SimpleFields) do
        if (tonumber(org[key]) or 0) > 0.001 then return true end
    end
    for _, key in ipairs(RecoveryFields) do
        if (tonumber(org[key]) or 0) > 0.01 then return true end
    end
    if istable(org.lungsL) and ((org.lungsL[1] or 0) > 0.001 or (org.lungsL[2] or 0) > 0) then return true end
    if istable(org.lungsR) and ((org.lungsR[1] or 0) > 0.001 or (org.lungsR[2] or 0) > 0) then return true end
    if (org.internalBleed or 0) > 0.01 or (org.blood or 5000) < 4999 then return true end
    if TableHasBleeding(org.wounds) or TableHasBleeding(org.arterialwounds) then return true end
    for _, key in ipairs(ClearFlags) do
        if org[key] then return true end
    end
    return false
end

-- Keep a treatment mode active until its entire category is complete.  Cycling
-- through the modes every tick made the unit abandon a repair halfway through
-- whenever another category also needed attention.
local function GetNextTreatmentMode(org)
    if HasStitchingWork(org) then return 1 end
    if HasComplexWork(org) then return 2 end
    if HasSimpleWork(org) then return 3 end
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
    elseif woundsChanged and IsValid(org.owner) and hg and hg.organism and hg.organism.SyncWounds then
        hg.organism.SyncWounds(org)
    end
end

local function HealComplex(org, config)
    HealFields(org, ComplexFields, config.InjuryHeal)
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
    org.lungsfunction = true
    org.internalBleedLungSide = nil
    org.tracheaPath = nil
end

local function HealSimple(org, config)
    HealFields(org, SimpleFields, config.InjuryHeal)
    local heal = config.InjuryHeal
    for _, key in ipairs(RecoveryFields) do
        if isnumber(org[key]) then org[key] = math.Approach(org[key], 0, heal * 12) end
    end
    org.blood = math.Approach(org.blood or 5000, 5000, config.BloodRestore)
    org.eyeLDestroyed = nil
    org.eyeRDestroyed = nil
    for _, key in ipairs(ClearFlags) do org[key] = false end
end

local function ApplyAutopulse(org, config)
    org.dihAutopulseUntil = CurTime() + config.AutopulseInterval * 1.5
    org.dihSupportUntil = org.dihAutopulseUntil
    org.deathStateEnd = math.max(org.deathStateEnd or 0, CurTime() + 2)
    org.pulse = 70
    org.heartbeat = 70
    org.cardiacOutput = 1
    org.strokeVolume = 1
    org.hypotension = 0
    org.hypertension = 0
    org.perfusion = 1
    org.peripheralperfusion = 1
    org.cerebralPerfusion = 1
    org.myocardialOxygen = 1
    if istable(org.o2) then
        org.o2[1] = math.Approach(org.o2[1] or 0, org.o2.range or 30, 1.5)
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
    QueueUnitSound(unit, ASSounds.mounted)
    owner:ViewPunch(Angle(5, 0, 0))

    local timerName = "AutosurgeonFollow" .. unit:EntIndex()
    local activeTarget = target
    local nextTreatment = CurTime() + 1
    local nextAutopulse = CurTime()
    local treatmentMode
    local modeSwitchPending = false
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

    QueueUnitSound(unit, ASScanSounds[math.random(#ASScanSounds)])
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

        if ProcessUnitSounds(unit, config) then return end
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
        if not org or not org.alive or org.deathStateKilled then
            DropUnit(unit, activeTarget, ply, battery)
            return
        end
        if CurTime() < nextTreatment then return end
        nextTreatment = CurTime() + config.TickInterval
        local needsAutopulse = org.heartstop or (tonumber(org.pulse) or 0) <= 0
        if not treatmentMode then treatmentMode = GetNextTreatmentMode(org) end

        -- Finish stitching, complex repair, and generic repair before using
        -- support functions such as stimulants or autopulse.
        if not treatmentMode then
            if modeSwitchPending and (needsAutopulse or painkillerTarget) then
                QueueUnitSound(unit, ASSounds.modeSwitch)
                modeSwitchPending = false
            end
            if needsAutopulse and CurTime() >= nextAutopulse then
                if battery < config.AutopulseBatteryPerBeat then
                    QueueUnitSound(unit, ASSounds.battery)
                    unit.ASPendingDrop = true
                    return
                end
                battery = battery - config.AutopulseBatteryPerBeat
                unit:SetNWInt("AutosurgeonBattery", battery)
                ApplyAutopulse(org, config)
                QueueUnitSound(unit, ASSounds.pump, 65, 100)
                nextAutopulse = CurTime() + config.AutopulseInterval
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

            if needsAutopulse then return end
            QueueUnitSound(unit, ASSounds.complete)
            unit.ASPendingDrop = true
            return
        end
        if battery < config.BatteryPerTick then
            QueueUnitSound(unit, ASSounds.battery)
            unit.ASPendingDrop = true
            return
        end

        battery = battery - config.BatteryPerTick
        unit:SetNWInt("AutosurgeonBattery", battery)
        QueueUnitSound(unit, ASSounds.pump, 65, 100)
        if modeSwitchPending then
            QueueUnitSound(unit, ASSounds.modeSwitch)
            modeSwitchPending = false
        end

        local pain = tonumber(org.pain) or 0
        if pain > 50 and (tonumber(org.painkiller) or 0) < 1 then
            local safeDose = math.min(1, math.max(0.25, (pain - 50) / 100))
            painkillerTarget = math.max(painkillerTarget or 0, safeDose)
            if not painkillerAnnounced then
                QueueUnitSound(unit, ASSounds.painkillerNeeded)
                painkillerAnnounced = true
            end
        end
        if treatmentMode == 1 then
            HealStitching(org, config)
        elseif treatmentMode == 2 then
            HealComplex(org, config)
        else
            HealSimple(org, config)
        end

        local modeStillNeeded = treatmentMode == 1 and HasStitchingWork(org) or
            treatmentMode == 2 and HasComplexWork(org) or
            treatmentMode == 3 and HasSimpleWork(org)
        if not modeStillNeeded then
            QueueUnitSound(unit, ASSounds.modeComplete)
            treatmentMode = nil
            modeSwitchPending = true
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
        wep:EmitSound(hasBattery and "panoptisscon/phone_simcard_insert.ogg" or "snd_jack_hmcd_ammobox.wav")
    end)
end

if CLIENT then
    SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_medkit")
    SWEP.IconOverride = "vgui/wep_jack_hmcd_medkit.png"
    SWEP.BounceWeaponIcon = false

    function SWEP:DrawHUD()
        if GetViewEntity() != LocalPlayer() or LocalPlayer():InVehicle() then return end
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

    hook.Add("HUDPaint", "AutosurgeonBatteryHUD", function()
        local weapon = LocalPlayer():GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() != "weapon_autosurgeon_sh" then return end
        local unit = LocalPlayer():GetNWEntity("AutosurgeonModelEnt")
        if not IsValid(unit) then return end

        local battery = math.max(unit:GetNWInt("AutosurgeonBattery", 0), 0)
        local maxBattery = ASConfig.BatteryMax
        draw.SimpleText("D.I.H BATTERY: " .. battery .. " / " .. maxBattery, "HomigradFont", ScrW() / 2, ScrH() - 100, color_white, TEXT_ALIGN_CENTER)
    end)
end
