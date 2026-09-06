if SERVER then AddCSLuaFile() end

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)

local MEDKIT_TYPES = {
    basic = {
        PrintName = "Basic Medkit",
        Instructions = "A compact first-aid kit with a basic bandage roll and one tourniquet. Best for stopping a small wound before it becomes serious. RMB to apply on others, R to change use mode.",
        contents = {bandage = 40, tourniquet = 1},
        bandageColor = Color(235, 235, 235),
    },
    standard = {
        PrintName = "Standard Medkit",
        Instructions = "A general-purpose first-aid kit with bandages, a tourniquet and paracetamol for everyday injuries. RMB to apply on others, R to change use mode.",
        contents = {bandage = 60, tourniquet = 1, painkiller = 1},
        bandageColor = Color(205, 205, 205),
        painkillerType = "paracetamol",
    },
    emergency = {
        PrintName = "Emergency Medkit",
        Instructions = "An emergency trauma kit with extra bandages, two tourniquets, tramadol and naloxone for severe bleeding or overdose response. RMB to apply on others, R to change use mode.",
        contents = {bandage = 120, tourniquet = 2, painkiller = 0.4, naloxone = 1},
        bandageColor = Color(165, 165, 165),
        painkillerType = "tramadol",
    },
    advanced = {
        PrintName = "Advanced Medkit",
        Instructions = "An advanced trauma kit with large dressings, two tourniquets, tramadol, tranexamic acid and a decompression needle for severe trauma. RMB to apply on others, R to change use mode.",
        contents = {bandage = 225, tourniquet = 2, painkiller = 0.4, tranexamic = 10, needle = 1},
        bandageColor = Color(125, 125, 125),
        painkillerType = "tramadol",
    },
    surgical = {
        PrintName = "Surgical Medkit",
        Instructions = "A fully stocked surgical kit with QuikClot-grade dressings, two tourniquets, tapentadol, tranexamic acid, naloxone, mannitol and a decompression needle. RMB to apply on others, R to change use mode.",
        contents = {bandage = 350, tourniquet = 2, painkiller = 0.6, tranexamic = 10, naloxone = 1, mannitol = 1, needle = 1},
        bandageColor = Color(75, 75, 75),
        painkillerType = "tapentadol",
    },
}
local NORMAL_MEDKIT = {
    PrintName = "Medkit",
    Instructions = "A standard medical bag with a quality bandage, painkiller, tranexamic acid, a tourniquet and a decompression needle. RMB to apply on others, R to change use mode.",
    contents = {bandage = 150, painkiller = 1, tourniquet = 1, tranexamic = 10, needle = 1},
    bandageColor = Color(165, 165, 165),
    bandageName = "quality bandage",
    painkillerType = "paracetamol",
}

local MEDKIT_PICKUP_CLASSES = {
    "weapon_medkit_basic_sh",
    "weapon_medkit_standard_sh",
    "weapon_medkit_emergency_sh",
    "weapon_medkit_advanced_sh",
    "weapon_medkit_surgical_sh",
}

local modeNames = {
    bandage = "bandaging",
    painkiller = "painkiller",
    tourniquet = "tourniquet",
    naloxone = "naloxone",
    tranexamic = "tranexamic acid",
    mannitol = "mannitol",
    needle = "decompression needle",
}
local modeOrder = {"bandage", "painkiller", "tourniquet", "naloxone", "tranexamic", "mannitol", "needle"}

local function setupMedkit(wep)
    local definition = MEDKIT_TYPES[wep.HGMedkitTier] or NORMAL_MEDKIT
    if not definition then return end

    wep.modeNames = {}
    wep.modeValues = {}
    wep.modeValuesdef = {}
    wep.HGMedkitModeTypes = {}
    wep.HGBandageColor = definition.bandageColor
    for _, typeName in ipairs(modeOrder) do
        local amount = definition.contents[typeName]
        if amount and amount > 0 then
            local index = #wep.modeValues + 1
            wep.modeNames[index] = typeName == "bandage" and (definition.bandageName or modeNames[typeName]) or modeNames[typeName]
            wep.modeValues[index] = amount
            wep.modeValuesdef[index] = {amount, typeName == "bandage" or typeName == "tourniquet" or typeName == "tranexamic"}
            wep.HGMedkitModeTypes[index] = typeName
        end
    end
    wep.modes = #wep.modeValues
    wep.mode = math.Clamp(wep.mode or 1, 1, math.max(wep.modes, 1))
end

local function resolveMedicalTarget(ent)
    if not IsValid(ent) then return end
    if ent:IsRagdoll() and hg and hg.RagdollOwner then
        ent = hg.RagdollOwner(ent) or ent
    end
    return IsValid(ent) and ent or nil
end

local function getMedkitDefinition(wep)
    return MEDKIT_TYPES[wep.HGMedkitTier] or NORMAL_MEDKIT
end

local function medkitHasSupplies(wep)
    for _, amount in ipairs(wep.modeValues or {}) do
        if amount > 0 then return true end
    end
    return false
end

local function syncMedkit(wep)
    if (wep.net_cooldown2 or 0) < CurTime() then
        wep:SetNetVar("modeValues", wep.modeValues)
    end
end

local function finishMedkitUse(wep)
    syncMedkit(wep)
    if medkitHasSupplies(wep) then return end

    local owner = wep:GetOwner()
    if IsValid(owner) then owner:SelectWeapon("weapon_hands_sh") end
    wep:Remove()
end

local function getMedicalTargetBone(wep, ent)
    if not wep.GetBandageTargetBone then return end
    return wep:GetBandageTargetBone(ent, hg.eyeTrace(wep:GetOwner()))
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
    local definition = getMedkitDefinition(wep)
    if typeName == "painkiller" then
        if definition.painkillerType == "paracetamol" then
            org.painkiller = math.min((org.painkiller or 0) + amount, 5)
        else
            org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + amount, 4)
        end
        wep.modeValues[modeIndex] = 0
        entOwner:EmitSound("snd_jack_hmcd_pillsuse.ogg", 60, math.random(95, 105))
        return true
    elseif typeName == "naloxone" then
        org.naloxoneadd = math.min((org.naloxoneadd or 0) + amount, 1)
    elseif typeName == "tranexamic" then
        hg.organism.AdministerTranexamic(org, amount)
    elseif typeName == "mannitol" then
        org.mannitol = math.Approach(org.mannitol or 0, 4, amount * 2)
        org.headtrauma = 0
    elseif typeName == "needle" then
        org.needle = 1
        if org.trachea and org.trachea > 0 then
            org.trachea = math.max(org.trachea - 0.75, 0)
        end
    else
        return
    end

    wep.modeValues[modeIndex] = 0
    entOwner:EmitSound("snd_jack_hmcd_needleprick.ogg", 60, math.random(95, 105))
    return true
end

local function useMedkit(wep, ent, mode, bone)
    ent = resolveMedicalTarget(ent)
    if not IsValid(ent) or not ent.organism then return end

    local modeIndex = mode or wep.mode
    local typeName = wep.HGMedkitModeTypes and wep.HGMedkitModeTypes[modeIndex]
    if not typeName or not wep.modeValues or (wep.modeValues[modeIndex] or 0) <= 0 then return end

    local owner = wep:GetOwner()
    local done
    if typeName == "bandage" then
        local bandage = weapons.GetStored("weapon_bandage_sh")
        if bandage and bandage.Heal then
            done = bandage.Heal(wep, ent, modeIndex, bone or getMedicalTargetBone(wep, ent))
        end
    elseif typeName == "tourniquet" then
        local selfTreatment = hg.GetCurrentCharacter(ent) == hg.GetCurrentCharacter(owner)
        if selfTreatment and not hg_healanims:GetBool() then
            wep:SetHolding(math.min(wep:GetHolding() + 10, 100))
            if wep:GetHolding() < 100 then return end
        end

        done = wep:Tourniquet(ent, bone or getMedicalTargetBone(wep, ent))
        if done then wep.modeValues[modeIndex] = math.max(wep.modeValues[modeIndex] - 1, 0) end
    else
        done = applyMedkitMode(wep, ent, modeIndex)
    end

    if done then finishMedkitUse(wep) end
    return done
end

local function canUseMedkitMode(wep, ent)
    ent = resolveMedicalTarget(ent)
    if not IsValid(ent) or not ent.organism then return false end

    local modeIndex = wep.mode or 1
    local typeName = wep.HGMedkitModeTypes and wep.HGMedkitModeTypes[modeIndex]
    if not typeName or not wep.modeValues or (wep.modeValues[modeIndex] or 0) <= 0 then return false end

    if typeName == "bandage" then
        local org = ent.organism
        return #org.wounds > 0 or (hg.organism.GetBandageDislocation and hg.organism.GetBandageDislocation(org)) or (org.lleg or 0) >= 0.05 or (org.rleg or 0) >= 0.05 or (org.skull or 0) >= 0.05 or (org.chest or 0) >= 0.05 or (org.rarm or 0) >= 0.05 or (org.larm or 0) >= 0.05
    end

    return true
end

local function applyMedkitControls(swep)
    swep.ShouldDeleteOnFullUse = false
    swep.CanHeal = function(self, ent)
        return canUseMedkitMode(self, ent)
    end
    swep.Heal = function(self, ent, mode, bone)
        return useMedkit(self, ent, mode, bone)
    end
    swep.PrimaryAttack = function(self)
        if not SERVER then return end
        local owner = self:GetOwner()
        if not IsValid(owner) or not owner:Alive() then return end
        self:SetNextPrimaryFire(CurTime() + 0.15)
        self:Heal(owner, self.mode)
    end
    swep.SecondaryAttack = function(self)
        if not SERVER or IsValid(self:GetNWEntity("fakeGun")) then return end
        local owner = self:GetOwner()
        if not IsValid(owner) or not owner:Alive() then return end

        local target = resolveMedicalTarget(hg.eyeTrace(owner).Entity)
        if not IsValid(target) or hg.GetCurrentCharacter(target) == hg.GetCurrentCharacter(owner) then return end
        self:SetNextSecondaryFire(CurTime() + 0.15)
        self:Heal(target, self.mode, getMedicalTargetBone(self, target))
    end
    swep.Reload = function(self)
        if not SERVER or not self:GetOwner():KeyPressed(IN_RELOAD) or self.modes <= 1 then return end
        self.mode = self.mode % self.modes + 1
        net.Start("select_mode")
        net.WriteEntity(self)
        net.WriteInt(self.mode, 4)
        net.Broadcast()
    end
end

local function registerTieredMedkits()
    local base = weapons.GetStored("weapon_medkit_sh")
    if not istable(base) then return false end

    for tier, definition in pairs(MEDKIT_TYPES) do
        local class = "weapon_medkit_" .. tier .. "_sh"
        local swep = table.Copy(base)
        swep.Base = "weapon_medkit_sh"
        swep.PrintName = definition.PrintName
        swep.Instructions = definition.Instructions
        swep.HGMedkitTier = tier
        swep.PickupFunc = false -- do not inherit weapon_medkit_sh's generic reroll callback
        swep.Spawnable = true
        swep.__hg_tiered_medkit = true
        swep.InitializeAdd = function(self)
            self:SetHold(self.HoldType)
            setupMedkit(self)
        end
        applyMedkitControls(swep)
        weapons.Register(swep, class)
    end
    return true
end

local function patchNormalMedkit()
    local normal = weapons.GetStored("weapon_medkit_sh")
    if not istable(normal) then return end

    normal.PrintName = NORMAL_MEDKIT.PrintName
    normal.Instructions = NORMAL_MEDKIT.Instructions
    normal.HGOriginalInitializeAdd = normal.HGOriginalInitializeAdd or normal.InitializeAdd
    normal.InitializeAdd = function(self)
        if normal.HGOriginalInitializeAdd then normal.HGOriginalInitializeAdd(self) end
        setupMedkit(self)
    end
    applyMedkitControls(normal)

    -- Ground pickups remain the generic medkit entity until a player takes
    -- them. Resolve the result here so map loot, crates and dropped generic
    -- medkits all use the same server-authoritative random selection.
    normal.PickupFunc = function(self, ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if ply.hgGivingTieredMedkit then return true end -- Give() already owns this nested pickup

        local availableClasses = {}
        for _, class in ipairs(MEDKIT_PICKUP_CLASSES) do
            if not ply:HasWeapon(class) and weapons.GetStored(class) then
                availableClasses[#availableClasses + 1] = class
            end
        end
        if #availableClasses == 0 then return end

        ply.hgGivingTieredMedkit = true
        local replacement = ply:Give(availableClasses[math.random(#availableClasses)])
        ply.hgGivingTieredMedkit = nil
        if not IsValid(replacement) then return end

        self:Remove()
        return true
    end
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
                if ent == hg.GetCurrentCharacter(owner) and not hg_healanims:GetBool() then
                    self:SetHolding(math.min(self:GetHolding() + 4, 100))
                    if self:GetHolding() < 100 then return end
                end
                org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + self.modeValues[1], 4)
                self.modeValues[1] = 0
                owner:EmitSound("snd_jack_hmcd_pillsuse.ogg", 60, math.random(95, 105))
                owner:SelectWeapon("weapon_hands_sh")
                self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
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
    weapon_packedbandage_sh = {name = "Packed bandage", amount = 60, color = Color(205, 205, 205), instructions = "A sealed field dressing with more clean gauze than a loose bandage. RMB to use on someone else."},
    weapon_combatbandage_sh = {name = "Combat bandage", amount = 120, color = Color(125, 125, 125), instructions = "A large military dressing for controlling serious bleeding in the field. RMB to use on someone else."},
    weapon_quikclotbandage_sh = {name = "QuikClot Bandage", amount = 180, color = Color(75, 75, 75), instructions = "A hemostatic QuikClot dressing for heavy bleeding when ordinary gauze is not enough. RMB to use on someone else."},
}

local LARGE_BANDAGE_GRADES = {
    weapon_bigpackedbandage_sh = {name = "Packed Bandage +", amount = 150, color = Color(205, 205, 205), instructions = "An oversized sealed field dressing with enough sterile gauze for several serious wounds. RMB to use on someone else."},
    weapon_bigcombatbandage_sh = {name = "Combat Bandage +", amount = 225, color = Color(125, 125, 125), instructions = "An oversized military trauma dressing for controlling multiple serious wounds in the field. RMB to use on someone else."},
    weapon_bigquikclotbandage_sh = {name = "QuikClot Bandage +", amount = 350, color = Color(75, 75, 75), instructions = "An oversized hemostatic QuikClot dressing for catastrophic bleeding and extended field care. RMB to use on someone else."},
}

local BANDAGE_PICKUP_CLASSES = {
    "weapon_bandage_sh",
    "weapon_bigbandage_sh",
    "weapon_packedbandage_sh",
    "weapon_combatbandage_sh",
    "weapon_quikclotbandage_sh",
    "weapon_bigpackedbandage_sh",
    "weapon_bigcombatbandage_sh",
    "weapon_bigquikclotbandage_sh",
}

local BANDAGE_PICKUP_CLASS_SET = {}
for _, class in ipairs(BANDAGE_PICKUP_CLASSES) do
    BANDAGE_PICKUP_CLASS_SET[class] = true
end

local BANDAGE_PICKUP_WEIGHTS = {
    {class = "weapon_bandage_sh", weight = 52},
    {class = "weapon_bigbandage_sh", weight = 18},
    {class = "weapon_packedbandage_sh", weight = 12},
    {class = "weapon_combatbandage_sh", weight = 8},
    {class = "weapon_quikclotbandage_sh", weight = 5},
    {class = "weapon_bigpackedbandage_sh", weight = 3},
    {class = "weapon_bigcombatbandage_sh", weight = 1.5},
    {class = "weapon_bigquikclotbandage_sh", weight = 0.5},
}

local function pickBandageClass(ply)
    local totalWeight = 0
    for _, entry in ipairs(BANDAGE_PICKUP_WEIGHTS) do
        if not ply:HasWeapon(entry.class) and weapons.GetStored(entry.class) then
            totalWeight = totalWeight + entry.weight
        end
    end
    if totalWeight <= 0 then return end

    local roll = math.Rand(0, totalWeight)
    for _, entry in ipairs(BANDAGE_PICKUP_WEIGHTS) do
        if not ply:HasWeapon(entry.class) and weapons.GetStored(entry.class) then
            roll = roll - entry.weight
            if roll <= 0 then return entry.class end
        end
    end
end

local function patchBandagePickupRandomizer()
    local normal = weapons.GetStored("weapon_bandage_sh")
    if not istable(normal) then return end

    normal.PickupFunc = function(self, ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if not BANDAGE_PICKUP_CLASS_SET[self:GetClass()] then return end

        if ply.hgGivingTieredBandage then return true end -- Give() already owns this nested pickup
        local class = pickBandageClass(ply)
        if not class then return end

        ply.hgGivingTieredBandage = true
        local replacement = ply:Give(class)
        ply.hgGivingTieredBandage = nil
        if not IsValid(replacement) then return end

        self:Remove()
        return true
    end
end
local function registerBandageGrades()
    local normal = weapons.GetStored("weapon_bandage_sh")
    local quality = weapons.GetStored("weapon_bigbandage_sh")
    if not istable(normal) then return end

    -- The existing standard grades remain available under their requested names.
    normal.PrintName = "Bandage"
    normal.Instructions = "A loose roll of gauze for light bleeding. It may not be sterile, but it is better than leaving a wound open. RMB to use on someone else."
    normal.Color = Color(235, 235, 235)
    normal.modeValuesdef = {[1] = {40, true}}
    if istable(quality) then
        quality.PrintName = "Quality bandage"
        quality.Instructions = "A larger sterile dressing with quality gauze for wounds that need more than a basic bandage. RMB to use on someone else."
        quality.Color = Color(165, 165, 165)
    end

    for class, grade in pairs(BANDAGE_GRADES) do
        if not weapons.GetStored(class) then
            local swep = table.Copy(normal)
            swep.Base = "weapon_bandage_sh"
            swep.PrintName = grade.name
            swep.Instructions = grade.instructions
            swep.PickupFunc = false -- do not inherit weapon_bandage_sh's generic reroll callback
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

        local registered = weapons.GetStored(class)
        if istable(registered) then
            registered.PrintName = grade.name
            registered.Instructions = grade.instructions
            registered.Color = grade.color
            registered.PickupFunc = false -- do not inherit weapon_bandage_sh's generic reroll callback
        end
    end

    if not istable(quality) then return end
    for class, grade in pairs(LARGE_BANDAGE_GRADES) do
        if not weapons.GetStored(class) then
            local swep = table.Copy(quality)
            swep.Base = "weapon_bigbandage_sh"
            swep.PrintName = grade.name
            swep.Instructions = grade.instructions
            swep.PickupFunc = false
            swep.Spawnable = true
            swep.AdminOnly = false
            swep.Category = "ZCity Medicine"
            swep.Color = grade.color
            swep.BandageAmount = grade.amount
            swep.modeValuesdef = {[1] = {grade.amount, true}}
            weapons.Register(swep, class)
        end

        local registered = weapons.GetStored(class)
        if istable(registered) then
            registered.PrintName = grade.name
            registered.Instructions = grade.instructions
            registered.Color = grade.color
            registered.BandageAmount = grade.amount
            registered.modeValuesdef = {[1] = {grade.amount, true}}
            registered.PickupFunc = false
        end
    end
end
hook.Add("Initialize", "zcity_delta_medkit_tiers", function()
    patchPainkillerWeapons()
    registerBandageGrades()
    patchBandagePickupRandomizer()
    patchNormalMedkit()
    registerTieredMedkits()
    patchMedicalMinigame()
end)
hook.Add("OnReloaded", "zcity_delta_medkit_tiers_reload", function()
    patchPainkillerWeapons()
    registerBandageGrades()
    patchBandagePickupRandomizer()
    patchNormalMedkit()
    registerTieredMedkits()
    patchMedicalMinigame()
end)
timer.Simple(0, function()
    patchPainkillerWeapons()
    registerBandageGrades()
    patchBandagePickupRandomizer()
    patchNormalMedkit()
    registerTieredMedkits()
    patchMedicalMinigame()
end)
