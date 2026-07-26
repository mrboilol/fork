if CLIENT then return end

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

local MEDICAL_WEAPON_CLASSES = {
    "weapon_bandage_sh",
    "weapon_bigbandage_sh",
    "weapon_packedbandage_sh",
    "weapon_combatbandage_sh",
    "weapon_quikclotbandage_sh",
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
    "weapon_adrenaline",
    "weapon_thiamine",
    "weapon_mannitol",
    "weapon_naloxone",
    "weapon_tranexamic_acid",
    "weapon_betablock",
    "weapon_autoresuscitator",
    "weapon_horse_tranq",
    "weapon_fury13",
    "weapon_fury16"
}

local function StopHealAnimation(owner)
    if not IsValid(owner) then return end

    local wep = owner.HGMedicalMinigameWeapon
    owner.HGMedicalMinigameWeapon = nil

    if not IsValid(wep) then return end
    wep.HGMedicalMinigameActive = nil

    if wep.SetHolding then
        wep:SetHolding(0)
    end
end

local function StartHealAnimation(owner, wep)
    if not IsValid(owner) or not IsValid(wep) then return end

    if owner.HGMedicalMinigameWeapon ~= wep then
        StopHealAnimation(owner)
    end

    owner.HGMedicalMinigameWeapon = wep
    wep.HGMedicalMinigameActive = true

    if wep.SetHolding then
        wep:SetHolding(hg_healanims:GetBool() and 100 or 0)
    end
end

local function GetMinigameType(wep)
    if not IsValid(wep) then return nil end

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

    if class == "weapon_bandage_sh" or class == "weapon_bigbandage_sh" or class == "weapon_packedbandage_sh" or class == "weapon_combatbandage_sh" or class == "weapon_quikclotbandage_sh" or class == "weapon_bruicekit" then
        return "bandage"
    end

    if class == "weapon_tourniquet" then
        return "tourniquet"
    end

    if class == "weapon_morphine" or class == "weapon_fentanyl" or class == "weapon_needle" or class == "weapon_adrenaline" or class == "weapon_mannitol" or class == "weapon_naloxone" or class == "weapon_tranexamic_acid" or class == "weapon_horse_tranq" or class == "weapon_fury13" or class == "weapon_fury16" then
        return "syringe"
    end

    if class == "weapon_painkillers" or class == "weapon_tramadol" or class == "weapon_tapentadol" or class == "weapon_thiamine" or class == "weapon_betablock" then
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

local function StartMinigame(wep, owner, minigameType, target)
    if not IsValid(wep) or not IsValid(owner) then return false end
    if not minigameType then return false end

    local modeValueIndex = GetModeValueIndex(wep, minigameType)
    local startValue = wep.modeValues and wep.modeValues[modeValueIndex] or nil

    wep.healbuddy = target or owner
    wep.HGMedicalMinigameStartValue = startValue

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

local function PatchWeapon(class)
    local stored = weapons.GetStored(class)
    if not istable(stored) then return false end
    if stored.__hg_med_minigame_patched then return true end

    stored.__hg_med_minigame_patched = true
    stored.__hg_med_minigame_primary = stored.PrimaryAttack
    stored.__hg_med_minigame_secondary = stored.SecondaryAttack

    function stored:PrimaryAttack()
        local owner = self:GetOwner()
        local minigameType = GetMinigameType(self)
        if IsValid(owner) and minigameType then
            StartMinigame(self, owner, minigameType, owner)
            self:SetNextPrimaryFire(CurTime() + (minigameType == "bandage" and 0.25 or 1))
            return
        end

        if self.__hg_med_minigame_primary then
            return self:__hg_med_minigame_primary()
        end
    end

    function stored:SecondaryAttack()
        local owner = self:GetOwner()
        local minigameType = GetMinigameType(self)
        if IsValid(owner) and minigameType then
            local target = ResolveSecondaryTarget(owner)
            if IsValid(target) then
                StartMinigame(self, owner, minigameType, target)
                self:SetNextSecondaryFire(CurTime() + (minigameType == "bandage" and 0.25 or 1))
                return
            end
        end

        if self.__hg_med_minigame_secondary then
            return self:__hg_med_minigame_secondary()
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
        if IsValid(wep) and wep.HGMedicalMinigameActive and owner:GetActiveWeapon() == wep then
            if wep.SetHolding then
                wep:SetHolding(hg_healanims:GetBool() and 100 or 0)
            end
        elseif wep ~= nil then
            StopHealAnimation(owner)
        end

        local active = owner:GetActiveWeapon()
        if IsValid(active) and active:GetClass() == "weapon_defibrilator_homigrad" and active.SetHolding then
            local inUse = owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2)
            active:SetHolding(hg_healanims:GetBool() and inUse and 100 or 0)
        end
    end
end)

hook.Add("hg_medical_minigame_ended", "zcity_delta_medical_healanim_end", function(owner)
    StopHealAnimation(owner)
end)

hook.Add("PlayerDeath", "zcity_delta_medical_healanim_death", function(owner)
    StopHealAnimation(owner)
end)

timer.Simple(0, SchedulePatchRetries)
