if SERVER then AddCSLuaFile() end

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

local MEDKIT_TYPES = {
    basic = {
        PrintName = "Basic Medkit",
        contents = {bandage = 40, tourniquet = 1},
    },
    standard = {
        PrintName = "Standard Medkit",
        contents = {bandage = 60, tourniquet = 1, painkiller = 1},
        painkillerType = "paracetamol",
    },
    emergency = {
        PrintName = "Emergency Medkit",
        contents = {bandage = 150, tourniquet = 2, painkiller = 0.4, naloxone = 1},
        painkillerType = "tramadol",
    },
    advanced = {
        PrintName = "Advanced Medkit",
        contents = {bandage = 225, tourniquet = 2, painkiller = 0.4, tranexamic = 10},
        painkillerType = "tramadol",
    },
    surgical = {
        PrintName = "Surgical Medkit",
        contents = {bandage = 375, tourniquet = 2, painkiller = 0.6, tranexamic = 10, naloxone = 1, mannitol = 1},
        painkillerType = "tapentadol",
    },
}

local modeNames = {
    bandage = "bandaging",
    painkiller = "painkiller",
    tourniquet = "tourniquet",
    naloxone = "naloxone",
    tranexamic = "tranexamic acid",
    mannitol = "mannitol",
}
local modeOrder = {"bandage", "painkiller", "tourniquet", "naloxone", "tranexamic", "mannitol"}

local function isTieredMedkit(wep)
    return IsValid(wep) and wep.HGMedkitTier ~= nil
end

local function setupMedkit(wep)
    local definition = MEDKIT_TYPES[wep.HGMedkitTier]
    if not definition then return end

    wep.modeNames = {}
    wep.modeValues = {}
    wep.modeValuesdef = {}
    wep.HGMedkitModeTypes = {}
    for _, typeName in ipairs(modeOrder) do
        local amount = definition.contents[typeName]
        if amount and amount > 0 then
            local index = #wep.modeValues + 1
            wep.modeNames[index] = modeNames[typeName]
            wep.modeValues[index] = amount
            wep.modeValuesdef[index] = {amount, typeName == "bandage" or typeName == "tourniquet" or typeName == "tranexamic"}
            wep.HGMedkitModeTypes[index] = typeName
        end
    end
    wep.modes = #wep.modeValues
    wep.mode = math.Clamp(wep.mode or 1, 1, math.max(wep.modes, 1))
end

local function applyMedkitMode(wep, ent, mode)
    local org = ent.organism
    if not org then return end
    local modeIndex = mode or wep.mode
    local typeName = wep.HGMedkitModeTypes and wep.HGMedkitModeTypes[modeIndex]
    local amount = wep.modeValues and wep.modeValues[modeIndex] or 0
    if not typeName or amount <= 0 then return end

    local owner = wep:GetOwner()
    local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
    local definition = MEDKIT_TYPES[wep.HGMedkitTier]
    if typeName == "painkiller" then
        if definition.painkillerType == "paracetamol" then
            org.painkiller = math.min((org.painkiller or 0) + amount, 5)
        else
            org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + amount, 4)
        end
        wep.modeValues[modeIndex] = 0
        entOwner:EmitSound("snd_jack_hmcd_pillsuse.wav", 60, math.random(95, 105))
        return true
    elseif typeName == "naloxone" then
        org.naloxoneadd = math.min((org.naloxoneadd or 0) + amount, 1)
    elseif typeName == "tranexamic" then
        org.internalBleedHeal = (org.internalBleedHeal or 0) + amount
        org.tranexamic_acid = math.min((org.tranexamic_acid or 0) + amount, 10)
    elseif typeName == "mannitol" then
        org.mannitol = math.Approach(org.mannitol or 0, 4, amount * 2)
        org.headtrauma = 0
    else
        return
    end

    wep.modeValues[modeIndex] = 0
    entOwner:EmitSound("snd_jack_hmcd_needleprick.wav", 60, math.random(95, 105))
    return true
end

local function registerTieredMedkits()
    local base = weapons.GetStored("weapon_medkit_sh")
    if not istable(base) then return false end

    for tier, definition in pairs(MEDKIT_TYPES) do
        local class = "weapon_medkit_" .. tier .. "_sh"
        local swep = table.Copy(base)
        swep.Base = "weapon_medkit_sh"
        swep.PrintName = definition.PrintName
        swep.HGMedkitTier = tier
        swep.Spawnable = true
        swep.__hg_tiered_medkit = true
        swep.InitializeAdd = function(self)
            self:SetHold(self.HoldType)
            setupMedkit(self)
        end
        swep.Heal = function(self, ent, mode, bone)
            local typeName = self.HGMedkitModeTypes and self.HGMedkitModeTypes[mode or self.mode]
            if typeName == "bandage" then
                return self:Bandage(ent, bone)
            elseif typeName == "tourniquet" then
                local done = self:Tourniquet(ent, bone)
                if done then self.modeValues[mode or self.mode] = 0 end
                return done
            end
            return applyMedkitMode(self, ent, mode)
        end
        weapons.Register(swep, class)
    end
    return true
end

local function patchPainkillerWeapons()
    local base = weapons.GetStored("weapon_painkillers")
    if not istable(base) then return end
    for class, config in pairs({
        weapon_tramadol = {name = "Tramadol", dose = 0.4},
        weapon_tapentadol = {name = "Tapentadol", dose = 0.8},
    }) do
        if not weapons.GetStored(class) then
            local swep = table.Copy(base)
            swep.Base = "weapon_painkillers"
            swep.PrintName = config.name
            swep.modeNames = {[1] = string.lower(config.name)}
            swep.modeValuesdef = {[1] = config.dose}
            swep.InitializeAdd = function(self)
                self:SetHold(self.HoldType)
                self.modeValues = {[1] = config.dose}
            end
            swep.Heal = function(self, ent, mode)
                local org = ent.organism
                if not org or not self.modeValues or self.modeValues[1] <= 0 then return end
                local owner = self:GetOwner()
                if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
                    self:SetHolding(math.min(self:GetHolding() + 4, 100))
                    if self:GetHolding() < 100 then return end
                end
                org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + self.modeValues[1], 4)
                self.modeValues[1] = 0
                owner:EmitSound("snd_jack_hmcd_pillsuse.wav", 60, math.random(95, 105))
                owner:SelectWeapon("weapon_hands_sh")
                self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.wav")
                self:Remove()
                return true
            end
            weapons.Register(swep, class)
        end
    end
end

if SERVER then
    hook.Add("Org Think", "zcity_delta_painkiller_stat", function(owner, org, timeValue)
        local painkiller = math.max(org.painkiller or 0, 0)
        if painkiller <= 0 then return end

        -- One paracetamol dose lasts roughly 90 seconds; naloxone clears opioid
        -- load faster just as it does analgesia.
        org.painkiller = math.Approach(painkiller, 0, timeValue / 90 * ((org.naloxone or 0) * 25 + 1))

        local overdose = painkiller >= 3
        if overdose then
            -- Painkiller use remains clear below 3.0.  From 3.0 onward the
            -- overdose is physically impairing before it becomes fatal.
            local impairment = math.Clamp(0.25 + (painkiller - 3) / 2 * 0.75, 0, 1)
            org.disorientation = math.max(org.disorientation or 0, impairment * 1.25)
            org.immobilization = math.max(org.immobilization or 0, impairment * 6)
            org.consciousness = math.Approach(org.consciousness or 1, 1 - impairment * 0.35, timeValue / 20)
            org.opioidRespiratoryDepression = math.max(org.opioidRespiratoryDepression or 0, impairment)
        end

        if painkiller >= 5 then
            -- Five points is a lethal overdose: stop breathing immediately and
            -- let the established hypoxia/arrest path finish the consequence.
            org.respiratoryArrest = true
            org.lungsfunction = false
            if org.o2 then org.o2[1] = math.max((org.o2[1] or 0) - timeValue * 12, 0) end
        elseif overdose and org.o2 then
            org.o2[1] = math.max((org.o2[1] or 0) - timeValue * (1 + impairment * 4), 0)
        end
    end)
end

local function patchMedicalMinigame()
    local patch = weapons.GetStored("weapon_medkit_basic_sh")
    if not istable(patch) then return end
    for _, tier in ipairs({"basic", "standard", "emergency", "advanced", "surgical"}) do
        local class = "weapon_medkit_" .. tier .. "_sh"
        local swep = weapons.GetStored(class)
        if istable(swep) then
            swep.GetMedicalMinigameType = function(self)
                local typeName = self.HGMedkitModeTypes and self.HGMedkitModeTypes[self.mode]
                if typeName == "bandage" then return "bandage" end
                if typeName == "tourniquet" then return "tourniquet" end
                if typeName then return "syringe" end
            end
        end
    end
end

local BANDAGE_GRADES = {
    weapon_packedbandage_sh = {name = "Packed bandage", amount = 60, color = Color(205, 205, 205)},
    weapon_combatbandage_sh = {name = "Combat bandage", amount = 225, color = Color(125, 125, 125)},
    weapon_quikclotbandage_sh = {name = "QuikClot Bandage", amount = 375, color = Color(75, 75, 75)},
}

local function registerBandageGrades()
    local normal = weapons.GetStored("weapon_bandage_sh")
    local quality = weapons.GetStored("weapon_bigbandage_sh")
    if not istable(normal) then return end

    -- The existing standard grades remain available under their requested names.
    normal.PrintName = "Bandage"
    normal.Color = Color(235, 235, 235)
    if istable(quality) then
        quality.PrintName = "Quality bandage"
        quality.Color = Color(165, 165, 165)
    end

    for class, grade in pairs(BANDAGE_GRADES) do
        if not weapons.GetStored(class) then
            local swep = table.Copy(normal)
            swep.Base = "weapon_bandage_sh"
            swep.PrintName = grade.name
            swep.Spawnable = true
            swep.AdminOnly = false
            swep.Category = "ZCity Medicine"
            swep.Color = grade.color
            swep.modeValuesdef = {[1] = {grade.amount, true}}
            swep.InitializeAdd = function(self)
                self.ModelScale = 0.9
                self.minigameCompletions = 0
                self.modeValues = {[1] = grade.amount}
            end
            weapons.Register(swep, class)
        end
    end
end
hook.Add("Initialize", "zcity_delta_medkit_tiers", function()
    patchPainkillerWeapons()
    registerBandageGrades()
    registerTieredMedkits()
    patchMedicalMinigame()
end)
hook.Add("OnReloaded", "zcity_delta_medkit_tiers_reload", function()
    patchPainkillerWeapons()
    registerBandageGrades()
    registerTieredMedkits()
    patchMedicalMinigame()
end)
timer.Simple(0, function()
    patchPainkillerWeapons()
    registerBandageGrades()
    registerTieredMedkits()
    patchMedicalMinigame()
end)