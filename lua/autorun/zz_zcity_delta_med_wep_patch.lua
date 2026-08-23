if CLIENT then return end

-- Public semantics: 0 uses the original models with progressive minigames;
-- 1 uses Judge-style animation-only medical items where those variants exist.
local hg_healanims = GetConVar("hg_healanims") or CreateConVar("hg_healanims", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)
local HEAL_ANIMATION_RETURN_TIME = 0.35

local MEDICAL_WEAPON_CLASSES = {
    "weapon_bandage_sh",
    "weapon_bigbandage_sh",
    "weapon_packedbandage_sh",
    "weapon_combatbandage_sh",
    "weapon_quikclotbandage_sh",
    "weapon_bigpackedbandage_sh",
    "weapon_bigcombatbandage_sh",
    "weapon_bigquikclotbandage_sh",
    "weapon_bruicekit",
    "weapon_tourniquet",
    "weapon_morphine",
    "weapon_fentanyl",
    "weapon_medkit_sh",
    "weapon_medkit_basic_sh",
    "weapon_medkit_standard_sh",
    "weapon_medkit_emergency_sh",
    "weapon_medkit_advanced_sh",
    "weapon_medkit_surgical_sh",
    "weapon_needle",
    "weapon_painkillers",
    "weapon_tramadol",
    "weapon_tapentadol",
    "weapon_zerlkers",
    "weapon_adrenaline",
    "weapon_thiamine",
    "weapon_mannitol",
    "weapon_naloxone",
    "weapon_tranexamic_acid",
    "weapon_betablock",
    "weapon_autoresuscitator",
    "weapon_horse_tranq",
    "weapon_midazolam",
    "weapon_fury13",
    "weapon_fury16"
}

local function GetMedicalAnimationType()
    return 1 - math.Clamp(hg_healanims:GetInt(), 0, 1)
end

local function SetHealAnimationTarget(wep, target)
    if not IsValid(wep) or not wep.SetHolding then return end

    wep.HGMedicalMinigameAnimationTarget = math.Clamp(target or 0, 0, 100)
end

local function UpdateHealAnimation(wep, immediate)
    if not IsValid(wep) or not wep.SetHolding then return true end

    local target = wep.HGMedicalMinigameAnimationTarget or 0
    local holding = target
    if not immediate and wep.HGMedicalMinigameAnimationReturnStarted then
        local fraction = math.Clamp((CurTime() - wep.HGMedicalMinigameAnimationReturnStarted) / HEAL_ANIMATION_RETURN_TIME, 0, 1)
        holding = Lerp(fraction, wep.HGMedicalMinigameAnimationReturnHolding or 0, 0)
    end
    wep:SetHolding(holding)

    return holding <= 0 and target <= 0
end

local function StopHealAnimation(owner)
    if not IsValid(owner) then return end

    local wep = owner.HGMedicalMinigameWeapon
    owner.HGMedicalMinigameWeapon = nil

    local medical = hg and hg.MedicalMinigame
    if medical and medical.BandageSessions then
        medical.BandageSessions[owner] = nil
    end
    if medical and medical.TourniquetSessions then
        medical.TourniquetSessions[owner] = nil
    end

    if not IsValid(wep) then return end
    wep.HGMedicalMinigameActive = nil
    wep.HGMedicalMinigameProgress = nil
    wep.HGMedicalMinigameAnimationReturnHolding = wep:GetHolding() or 0
    wep.HGMedicalMinigameAnimationReturnStarted = CurTime()
    SetHealAnimationTarget(wep, 0)
    owner.HGMedicalMinigameReturningWeapon = wep
end

local function StartHealAnimation(owner, wep)
    if not IsValid(owner) or not IsValid(wep) then return end

    if owner.HGMedicalMinigameWeapon ~= wep then
        StopHealAnimation(owner)
    end

    owner.HGMedicalMinigameWeapon = wep
    wep.HGMedicalMinigameActive = true
    wep.HGMedicalMinigameProgress = 0
    wep.HGMedicalMinigameAnimationReturnHolding = nil
    wep.HGMedicalMinigameAnimationReturnStarted = nil
    owner.HGMedicalMinigameReturningWeapon = nil
    SetHealAnimationTarget(wep, 0)
end

local function GetMinigameType(wep)
    if not IsValid(wep) then return nil end
    if wep.HGMedicalMinigameType then return wep.HGMedicalMinigameType end

    -- Use homigrad's function if available to avoid duplication
    if hg and hg.MedicalMinigame and hg.MedicalMinigame.GetMedicalMinigameType then
        return hg.MedicalMinigame.GetMedicalMinigameType(wep)
    end

    -- Fallback logic (matches homigrad's implementation)
    local class = wep:GetClass()

    local medkitModeType = wep.HGMedkitTier and wep.HGMedkitModeTypes and wep.HGMedkitModeTypes[wep.mode]
    if medkitModeType == "bandage" then return "bandage" end
    if medkitModeType == "tourniquet" then return "tourniquet" end
    if medkitModeType then return "syringe" end

    if class == "weapon_bandage_sh" or class == "weapon_bigbandage_sh" or class == "weapon_packedbandage_sh" or class == "weapon_combatbandage_sh" or class == "weapon_quikclotbandage_sh" or class == "weapon_bigpackedbandage_sh" or class == "weapon_bigcombatbandage_sh" or class == "weapon_bigquikclotbandage_sh" or class == "weapon_bruicekit" then
        return "bandage"
    end

    if class == "weapon_tourniquet" then
        return "tourniquet"
    end

    if class == "weapon_morphine" or class == "weapon_fentanyl" or class == "weapon_needle" or class == "weapon_adrenaline" or class == "weapon_mannitol" or class == "weapon_naloxone" or class == "weapon_tranexamic_acid" or class == "weapon_horse_tranq" or class == "weapon_fury13" or class == "weapon_fury16" then
        return "syringe"
    end

    if class == "weapon_painkillers" or class == "weapon_tramadol" or class == "weapon_tapentadol" or class == "weapon_zerlkers" or class == "weapon_thiamine" or class == "weapon_betablock" then
        return "syringe"
    end

    if class == "weapon_autoresuscitator" then
        return "syringe"
    end

    if class == "weapon_medkit_sh" then
        if wep.mode == 1 then return "bandage" end
        if wep.mode == 2 or wep.mode == 3 or wep.mode == 5 then return "syringe" end
        if wep.mode == 4 then return "tourniquet" end
    end

    return nil
end

local function GetModeValueIndex(wep, minigameType)
    if not IsValid(wep) then return 1 end
    if wep:GetClass() ~= "weapon_medkit_sh" and not wep.HGMedkitTier then return 1 end

    if minigameType == "syringe" then return wep.mode or 3 end
    if minigameType == "tourniquet" then return wep.HGMedkitTier and (wep.mode or 1) or 4 end
    return 1
end

local function GetSyringeAnimationProgress(wep, progress)
    if not IsValid(wep) then return 0 end

    -- Fentanyl is potent enough that a fifth of a dose represents a full
    -- injection motion.  Larger doses keep that pose instead of forcing the
    -- player through multiple full syringe motions.
    if wep:GetClass() == "weapon_fentanyl" then
        return math.Clamp(progress / 0.2, 0, 1)
    end

    return math.Clamp(progress, 0, 1)
end

local function ResolveSecondaryTarget(owner)
    if not IsValid(owner) then return nil end
    local tr = (hg and hg.eyeTrace and hg.eyeTrace(owner, 100)) or owner:GetEyeTrace()
    local ent = tr and tr.Entity or nil
    if not IsValid(ent) then return nil end

    if ent:IsRagdoll() and hg and hg.RagdollOwner then
        ent = hg.RagdollOwner(ent) or ent
    end

    if not IsValid(ent) or not ent:IsPlayer() or not ent:Alive() or not ent.organism then return nil end
    if ent ~= owner then
        local entChar = (hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(ent)) or ent
        if not IsValid(entChar) then entChar = ent end
        if owner:GetPos():DistToSqr(entChar:GetPos()) > 10000 then return nil end
    end
    return ent
end

local function CanUseMedicalArms(owner)
    if not IsValid(owner) then return false end
    if not hg or not hg.MedicalMinigame or not hg.MedicalMinigame.GetArmSpeedMultiplier then return true end
    if hg.MedicalMinigame.GetArmSpeedMultiplier(owner) > 0 then return true end

    if (owner.HGMedicalNoArmsNotice or 0) <= CurTime() then
        owner.HGMedicalNoArmsNotice = CurTime() + 1
        owner:ChatPrint("You need at least one usable arm to perform treatment.")
    end
    return false
end

local function StartMinigame(wep, owner, minigameType, target)
    if not IsValid(wep) or not IsValid(owner) then return false end
    if not minigameType then return false end
    if not CanUseMedicalArms(owner) then return false end

    local modeValueIndex = GetModeValueIndex(wep, minigameType)
    local startValue = wep.modeValues and wep.modeValues[modeValueIndex] or nil

    wep.healbuddy = target or owner
    wep.HGMedicalMinigameStartValue = startValue
    wep.HGMedicalMinigameRequiredProgress = 1

    local started = false
    if minigameType == "bandage" and hg and hg.MedicalMinigame and hg.MedicalMinigame.StartBandageMinigame then
        started = hg.MedicalMinigame.StartBandageMinigame(owner, wep.healbuddy) == true
    elseif minigameType == "tourniquet" and hg and hg.MedicalMinigame and hg.MedicalMinigame.StartTourniquetMinigame then
        started = hg.MedicalMinigame.StartTourniquetMinigame(owner, wep.healbuddy) == true
    else
        net.Start("hg_medical_minigame_start")
            net.WriteString(minigameType)
            net.WriteEntity(wep.healbuddy)
        net.Send(owner)
        started = true
    end

    if started then
        StartHealAnimation(owner, wep)
    end

    return started
end

local JUDGE_REPLACEMENTS = {
    weapon_painkillers = "weapon_painkillers_tpik",
    weapon_thiamine = "weapon_thiamine_tpik",
    weapon_betablock = "weapon_betablock_tpik"
}
local ORIGINAL_REPLACEMENTS = {}
for original, judge in pairs(JUDGE_REPLACEMENTS) do ORIGINAL_REPLACEMENTS[judge] = original end

local function DesiredMedicalClass(class)
    if hg_healanims:GetBool() then return JUDGE_REPLACEMENTS[class] end
    return ORIGINAL_REPLACEMENTS[class]
end

local function ReplaceMedicalWeapon(ent)
    if not IsValid(ent) or not ent:IsWeapon() then return end
    local targetClass = DesiredMedicalClass(ent:GetClass())
    if not targetClass or not weapons.GetStored(targetClass) then return end

    local owner = ent:GetOwner()
    local modeValues = istable(ent.modeValues) and table.Copy(ent.modeValues) or nil
    local wasActive = IsValid(owner) and owner:IsPlayer() and owner:GetActiveWeapon() == ent
    if IsValid(owner) and owner:IsPlayer() then
        local replacement = owner:GetWeapon(targetClass)
        if not IsValid(replacement) then replacement = owner:Give(targetClass) end
        if IsValid(replacement) then
            if modeValues then replacement.modeValues = modeValues end
            if wasActive then owner:SelectWeapon(targetClass) end
            ent:Remove()
        end
        return
    end

    local replacement = ents.Create(targetClass)
    if not IsValid(replacement) then return end
    replacement:SetPos(ent:GetPos())
    replacement:SetAngles(ent:GetAngles())
    replacement:Spawn()
    replacement:Activate()
    if modeValues then replacement.modeValues = modeValues end
    local phys = ent:GetPhysicsObject()
    local newPhys = replacement:GetPhysicsObject()
    if IsValid(phys) and IsValid(newPhys) then
        newPhys:SetVelocity(phys:GetVelocity())
        newPhys:AddAngleVelocity(phys:GetAngleVelocity())
    end
    ent:Remove()
end

local function ConvertExistingMedicalWeapons()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:IsWeapon() then ReplaceMedicalWeapon(ent) end
    end
end

hook.Add("OnEntityCreated", "zcity_delta_healanims_replace_items", function(ent)
    timer.Simple(0, function() if IsValid(ent) then ReplaceMedicalWeapon(ent) end end)
end)

cvars.AddChangeCallback("hg_healanims", function()
    timer.Simple(0, ConvertExistingMedicalWeapons)
end, "zcity_delta_healanims_replace_existing")

local function PatchWeapon(class)
    local stored = weapons.GetStored(class)
    if not istable(stored) then return false end
    if stored.__hg_med_minigame_patched then return true end

    stored.__hg_med_minigame_patched = true
    local originalPrimary = stored.PrimaryAttack
    local originalSecondary = stored.SecondaryAttack
    local originalThink = stored.Think

    function stored:Think()
        local result
        if originalThink then
            result = originalThink(self)
        end

        -- The original weapon Think methods lower Holding whenever the mouse
        -- is released.  A minigame captures the mouse, so restore its pose
        -- after that Think call instead of letting the normal medicine logic
        -- erase the replicated animation each frame.
        local owner = self:GetOwner()
        if IsValid(owner) and owner.HGMedicalMinigameWeapon == self and self.HGMedicalMinigameActive and self.SetHolding then
            self:SetHolding(self.HGMedicalMinigameAnimationTarget or 0)
        end

        return result
    end

    function stored:PrimaryAttack()
        local owner = self:GetOwner()
        local minigameType = GetMinigameType(self)
        if IsValid(owner) and minigameType and not CanUseMedicalArms(owner) then
            self:SetNextPrimaryFire(CurTime() + 0.5)
            return
        end
        if IsValid(owner) and minigameType and GetMedicalAnimationType() == 1 then
            if StartMinigame(self, owner, minigameType, owner) then
                self:SetNextPrimaryFire(CurTime() + (minigameType == "bandage" and 0.25 or 1))
                return
            end
        end

        if originalPrimary then
            return originalPrimary(self)
        end
    end

    function stored:SecondaryAttack()
        local owner = self:GetOwner()
        local minigameType = GetMinigameType(self)
        if IsValid(owner) and minigameType and not CanUseMedicalArms(owner) then
            self:SetNextSecondaryFire(CurTime() + 0.5)
            return
        end
        if IsValid(owner) and minigameType and GetMedicalAnimationType() == 1 then
            local target = ResolveSecondaryTarget(owner)
            if IsValid(target) then
                if StartMinigame(self, owner, minigameType, target) then
                    self:SetNextSecondaryFire(CurTime() + (minigameType == "bandage" and 0.25 or 1))
                    return
                end
            end
        end

        if originalSecondary then
            return originalSecondary(self)
        end
    end

    return true
end

local function ApplyPatches()
    for _, class in ipairs(MEDICAL_WEAPON_CLASSES) do
        PatchWeapon(class)
    end
end

local function SchedulePatchRetries()
    timer.Simple(0, ApplyPatches)
    timer.Simple(1, ApplyPatches)
    timer.Simple(5, ApplyPatches)
end

hook.Add("Initialize", "zcity_delta_patch_med_weps", SchedulePatchRetries)
hook.Add("InitPostEntity", "zcity_delta_patch_med_weps_post", SchedulePatchRetries)
hook.Add("OnReloaded", "zcity_delta_patch_med_weps_reload", SchedulePatchRetries)

hook.Add("Think", "zcity_delta_medical_healanim_progress", function()
    for _, owner in player.Iterator() do
        local wep = owner.HGMedicalMinigameWeapon
        if GetMedicalAnimationType() ~= 1 and wep ~= nil then
            StopHealAnimation(owner)
            wep = nil
        end
        if IsValid(wep) and wep.HGMedicalMinigameActive and owner:GetActiveWeapon() == wep then
            local minigameType = GetMinigameType(wep)
            local animtype = GetMedicalAnimationType()
            if minigameType == "bandage" or minigameType == "tourniquet" then
                SetHealAnimationTarget(wep, animtype == 1 and (wep.HGMedicalMinigameProgress or 0) * 100 or 0)
            elseif minigameType == "syringe" then
                local progress = GetSyringeAnimationProgress(wep, wep.HGMedicalMinigameProgress or 0)
                SetHealAnimationTarget(wep, animtype == 1 and progress * 100 or 0)
            end

            -- Weapon Think functions normally lower Holding whenever attack
            -- is released.  Set the current minigame pose directly so they
            -- cannot pull a bandage pose down or lag behind syringe progress.
            UpdateHealAnimation(wep, true)
        elseif wep ~= nil then
            StopHealAnimation(owner)
        end

        local returning = owner.HGMedicalMinigameReturningWeapon
        if IsValid(returning) and UpdateHealAnimation(returning) then
            owner.HGMedicalMinigameReturningWeapon = nil
        elseif returning ~= nil and not IsValid(returning) then
            owner.HGMedicalMinigameReturningWeapon = nil
        end

        local active = owner:GetActiveWeapon()
        if IsValid(active) and active:GetClass() == "weapon_defibrilator_homigrad" and active.SetHolding then
            local inUse = owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2)
            active:SetHolding((not hg_healanims:GetBool()) and inUse and 100 or 0)
        end
    end
end)

-- The minigame owns its networking.  Its progress hook gives the animation
-- the same accumulated completion value used by the actual treatment.
hook.Add("hg_medical_minigame_progress", "zcity_delta_medical_healanim_syringe_progress", function(owner, wep, minigameType, progressDelta)
    if not IsValid(owner) or not IsValid(wep) then return end
    if owner.HGMedicalMinigameWeapon ~= wep then return end

    local delta = math.max(progressDelta or 0, 0)
    if minigameType == "bandage" then
        local required = math.max(wep.HGMedicalMinigameRequiredProgress or 1, 1)
        delta = delta / required
    end
    wep.HGMedicalMinigameProgress = math.Clamp((wep.HGMedicalMinigameProgress or 0) + delta, 0, 1)
end)

hook.Add("hg_medical_minigame_ended", "zcity_delta_medical_healanim_end", function(owner)
    StopHealAnimation(owner)
end)

hook.Add("PlayerDeath", "zcity_delta_medical_healanim_death", function(owner)
    StopHealAnimation(owner)
end)

timer.Simple(0, SchedulePatchRetries)
