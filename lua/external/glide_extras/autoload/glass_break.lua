--[[
    Custom glass material support guide:

    Example:

        if not Glide then return end

        Glide.ExtraDetailsGlass = Glide.ExtraDetailsGlass or {}
        Glide.ExtraDetailsGlass.SpecialMaterials = Glide.ExtraDetailsGlass.SpecialMaterials or {}
        Glide.ExtraDetailsGlass.IgnoreMaterials = Glide.ExtraDetailsGlass.IgnoreMaterials or {}
        Glide.ExtraDetailsGlass.OverrideBaseNames = Glide.ExtraDetailsGlass.OverrideBaseNames or {}

        --force these materials to be treated as glass.
        Glide.ExtraDetailsGlass.SpecialMaterials["models/my_pack/car/window_clean"] = true
        Glide.ExtraDetailsGlass.SpecialMaterials["models/my_pack/car/window_dirty"] = true

        --prevent these materials from being treated as glass,
        --even if their name contains "glass".
        Glide.ExtraDetailsGlass.IgnoreMaterials["models/my_pack/car/fake_glass_detail"] = true

        -- Optional. Usually not needed if the replacement VMT exists.
        Glide.ExtraDetailsGlass.OverrideBaseNames["window_clean"] = true
        Glide.ExtraDetailsGlass.OverrideBaseNames["window_dirty"] = true

    Custom cracked/broken materials go here:

        materials/vehicles/glass/cracked/window_clean.vmt
        materials/vehicles/glass/broken/window_clean.vmt

    Suffixed variants can use their own material, or fall back to the base one:

        window_dirty >> window_dirty.vmt if it exists
        window_dirty >> window.vmt if that exists
        window_dirty >> default.vmt otherwise
]]






if not Glide then return end

if SERVER then
    AddCSLuaFile()
end

game.AddParticles("particles/glide_glass_shatter.pcf")
PrecacheParticleSystem("impact_glass")

local NET_GLASS_FX = "GlideGlass_ShatterFX"

if SERVER then
    util.AddNetworkString(NET_GLASS_FX)
end

local SPECIAL_GLASS_MATS = {
    ["models/glide/exid/windows"] = true,
    ["models/glide/exid/vehiclelights_trans"] = true,
    ["models/glide/reshed/wac/c172/c172_t_spec"] = true,
    ["models/left4dead/vehicles/bus_glass"] = true,
    ["models/props_vehicles/thedivision2/vh_van01_unique01_trans"] = true,
    ["models/props_vehicles/thedivision2/vh_van01_unique03_trans"] = true,
    ["vehicle_generic_glasswindows2"] = true
}

local OVERRIDE_BASE_NAMES = {
    ["4carz1024_glass2"] = true,
    ["4carz1024_glass"] = true,
    ["pickup_trucks_glass"] = true,
    ["vehicle_glass2"] = true,
    ["bus_glass"] = true,
}

local IGNORE_GLASS_MATS = {
    ["models/left4dead/vehicles/police_cab_city_glass_opaq"] = true,
    ["models/props_vehicles/thedivision2/gn_glass_dirty01"] = true
}

Glide.ExtraDetailsGlass = Glide.ExtraDetailsGlass or {}

Glide.ExtraDetailsGlass.SpecialMaterials = Glide.ExtraDetailsGlass.SpecialMaterials or {}
Glide.ExtraDetailsGlass.IgnoreMaterials = Glide.ExtraDetailsGlass.IgnoreMaterials or {}
Glide.ExtraDetailsGlass.OverrideBaseNames = Glide.ExtraDetailsGlass.OverrideBaseNames or {}

local DEFAULT_CRACK  = "vehicles/glass/cracked/default"
local DEFAULT_BROKEN = "vehicles/glass/broken/default"

local CRACK_FOLDER  = "vehicles/glass/cracked/"
local BROKEN_FOLDER = "vehicles/glass/broken/"

local CRACK_SOUND_BASE = "vehicles/glass_crack"
local BREAK_SOUND_BASE = "vehicles/glass_break"
local CRACK_SOUND_COUNT = 5
local BREAK_SOUND_COUNT = 8

local NW_GLASS_BROKEN = "glide_glass_broken"

local CVAR_ENABLED = CreateConVar(
    "glide_extension_glass_damage",
    "1",
    FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
    "Enables glass cracking/breaking on vehicles."
)

local CVAR_CRACK = CreateConVar(
    "glide_extension_glass_crack_damage",
    "45",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Cumulative damage required to crack glass.",
    0,
    50000
)

local CVAR_BREAK = CreateConVar(
    "glide_extension_glass_break_damage",
    "120",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Cumulative damage required to break glass.",
    0,
    50000
)

local CVAR_SOUNDLEVEL = CreateConVar(
    "glide_extension_glass_soundlevel",
    "70",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Sound level for glass crack/break.",
    50,
    140
)

local CVAR_REPAIR_SCALE = CreateConVar(
    "glide_extension_glass_repair_scale",
    "1",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "For repair tools.",
    0,
    10
)

local function IsValidGlideVehicle(ent)
    return IsValid(ent) and ent.IsGlideVehicle == true
end

local function StripVMT(path)
    if not isstring(path) then return "" end
    path = string.Trim(path)
    return (path:gsub("%.vmt$", ""))
end

local function GetBaseNameFromMat(matPath)
    matPath = StripVMT(matPath)
    if matPath == "" then return "" end
    local parts = string.Explode("/", matPath)
    return parts[#parts] or ""
end

local materialExistsCache = {}
local replacementBaseCache = {}

local function ExtraTableHas(tableName, key)
    local ext = Glide.ExtraDetailsGlass
    if not istable(ext) then return false end

    local tbl = ext[tableName]
    return istable(tbl) and tbl[key] == true
end

local function IsSpecialGlassMat(clean)
    return SPECIAL_GLASS_MATS[clean] == true or ExtraTableHas("SpecialMaterials", clean)
end

local function IsIgnoredGlassMat(clean)
    return IGNORE_GLASS_MATS[clean] == true or ExtraTableHas("IgnoreMaterials", clean)
end

local function IsOverrideBaseName(baseName)
    return OVERRIDE_BASE_NAMES[baseName] == true or ExtraTableHas("OverrideBaseNames", baseName)
end

local function StartsWith(str, prefix)
    if not isstring(str) or not isstring(prefix) then return false end
    if prefix == "" then return false end

    return string.sub(str, 1, #prefix) == prefix
end

local function MaterialExistsNoVMT(path)
    path = StripVMT(path)
    if path == "" then return false end

    local cached = materialExistsCache[path]
    if cached ~= nil then return cached end

    local exists = file.Exists("materials/" .. path .. ".vmt", "GAME")
    materialExistsCache[path] = exists

    return exists
end

local function GetReplacementFolder(state)
    return state == 1 and CRACK_FOLDER or BROKEN_FOLDER
end

local function GetDefaultReplacement(state)
    return state == 1 and DEFAULT_CRACK or DEFAULT_BROKEN
end

local function GetReplacementPath(state, baseName)
    return StripVMT(GetReplacementFolder(state) .. baseName .. ".vmt")
end

local function HasReplacementForBase(state, baseName)
    if not isstring(baseName) or baseName == "" then return nil, false end

    local path = GetReplacementPath(state, baseName)
    return path, IsOverrideBaseName(baseName) or MaterialExistsNoVMT(path)
end

local function BuildReplacementBaseCache(state)
    local cache = {}

    for baseName in pairs(OVERRIDE_BASE_NAMES) do
        cache[baseName] = true
    end

    local ext = Glide.ExtraDetailsGlass
    if istable(ext) and istable(ext.OverrideBaseNames) then
        for baseName, enabled in pairs(ext.OverrideBaseNames) do
            if enabled == true then
                cache[baseName] = true
            end
        end
    end

    local folder = GetReplacementFolder(state)
    local files = file.Find("materials/" .. folder .. "*.vmt", "GAME") or {}

    for _, fileName in ipairs(files) do
        local baseName = StripVMT(fileName)
        if baseName ~= "" then
            cache[baseName] = true
        end
    end

    replacementBaseCache[state] = cache
    return cache
end

local function GetReplacementBaseCache(state)
    return replacementBaseCache[state] or BuildReplacementBaseCache(state)
end

local function FindBestPrefixReplacementBase(state, baseName)
    if not isstring(baseName) or baseName == "" then return nil end

    local cache = GetReplacementBaseCache(state)
    local bestBase = nil

    for knownBase in pairs(cache) do
        if knownBase ~= "default" and knownBase ~= baseName and StartsWith(baseName, knownBase) then
            if bestBase == nil or #knownBase > #bestBase then
                bestBase = knownBase
            end
        end
    end

    return bestBase
end

local function PickGlassReplacement(state, baseName, rootBase)
    local fallback = GetDefaultReplacement(state)

    if not isstring(baseName) or baseName == "" then
        return fallback
    end

    local exactPath, hasExact = HasReplacementForBase(state, baseName)
    if hasExact then
        return exactPath
    end

    if isstring(rootBase) and rootBase ~= "" and rootBase ~= baseName then
        local rootPath, hasRoot = HasReplacementForBase(state, rootBase)
        if hasRoot then
            return rootPath
        end
    end

    local prefixBase = FindBestPrefixReplacementBase(state, baseName)
    if prefixBase then
        local prefixPath, hasPrefix = HasReplacementForBase(state, prefixBase)
        if hasPrefix then
            return prefixPath
        end
    end

    return fallback
end

local function IsGlassCandidate(clean)
    if clean == "" then return false, false end
    if IsIgnoredGlassMat(clean) then return false, false end

    if IsSpecialGlassMat(clean) then
        return true, true
    end

    local low = string.lower(clean)

    if string.find(low, "glass", 1, true) or string.find(low, "unique_trans", 1, true) then
        return true, false
    end

    return false, false
end

local function PickPrimaryGlassCandidate(candidates)
    for _, c in ipairs(candidates) do
        if c.special then
            return c
        end
    end

    return candidates[1]
end

local function PickRootBase(primary, candidates)
    local rootBase = primary.base

    for _, c in ipairs(candidates) do
        local base = c.base

        if base ~= "" and base ~= rootBase and StartsWith(rootBase, base) then
            if #base < #rootBase then
                rootBase = base
            end
        end
    end

    return rootBase
end

local function DetectGlassSubmaterials(ent)
    local mats = ent:GetMaterials()
    if not istable(mats) or #mats == 0 then return nil end

    local candidates = {}

    for i, m in ipairs(mats) do
        local clean = StripVMT(m)
        local isGlass, isSpecial = IsGlassCandidate(clean)

        if isGlass then
            candidates[#candidates + 1] = {
                idx = i - 1,
                orig = clean,
                base = GetBaseNameFromMat(clean),
                special = isSpecial
            }
        end
    end

    if #candidates == 0 then return nil end

    local primary = PickPrimaryGlassCandidate(candidates)
    if not primary then return nil end

    local rootBase = PickRootBase(primary, candidates)
    local selected = {}

    for _, c in ipairs(candidates) do
        if c.base == rootBase or StartsWith(c.base, rootBase) then
            selected[#selected + 1] = {
                idx = c.idx,
                orig = c.orig,
                base = c.base
            }
        end
    end

    if #selected == 0 then return nil end

    return selected, rootBase
end

local function BuildIndexedSoundPath(base, count)
    count = tonumber(count) or 0
    if count < 1 then return nil end
    local idx = math.random(1, count)
    return string.format("%s%d.wav", base, idx)
end

local function SendGlassShatterFX(ent)
    if not SERVER then return end
    if not IsValid(ent) then return end

    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local localPos = Vector(maxs.x * 0.25, 0, maxs.z * 0.45)
    local localAng = Angle(0, 0, 0)

    net.Start(NET_GLASS_FX)
        net.WriteEntity(ent)
        net.WriteVector(localPos)
        net.WriteAngle(localAng)
    net.Broadcast()
end

if CLIENT then
    net.Receive(NET_GLASS_FX, function()
        local ent = net.ReadEntity()
        local localPos = net.ReadVector()
        local localAng = net.ReadAngle()

        if not IsValid(ent) then return end

        local wpos = ent:LocalToWorld(localPos)
        local wang = ent:LocalToWorldAngles(localAng)

        ParticleEffect("impact_glass", wpos, wang, ent)
    end)

    local lastDSPWanted = nil

    local function ShouldMuffleNow(ply, veh)
        if not IsValid(ply) or not IsValid(veh) then return false end
        if not ply:InVehicle() then return false end
        if ply:GlideGetVehicle() ~= veh then return false end

        if not veh.isLocalPlayerInFirstPerson then return false end
        if veh:GetNW2Bool(NW_GLASS_BROKEN, false) then return false end

        local seatIndex = ply:GlideGetSeatIndex() or 1

        if veh.AllowFirstPersonMuffledSound then
            return veh:AllowFirstPersonMuffledSound(seatIndex) == true
        end

        return true
    end

    hook.Add("OnEntityCreated", "Glide.GlassDamage.MuffleWrap", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) or ent.IsGlideVehicle ~= true then return end
            if ent._glideGlassMuffleWrapped then return end
            ent._glideGlassMuffleWrapped = true

            local orig = ent.AllowFirstPersonMuffledSound
            if not isfunction(orig) then
                orig = function(_self, _seatIndex) return true end
            end

            ent.AllowFirstPersonMuffledSound = function(self, seatIndex)
                if self:GetNW2Bool(NW_GLASS_BROKEN, false) then
                    return false
                end
                return orig(self, seatIndex)
            end
        end)
    end)

    hook.Add("Think", "Glide.GlassDamage.MuffleThink", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        if not ply:InVehicle() then
            lastDSPWanted = nil
            return
        end

        local veh = ply:GlideGetVehicle()
        if not (IsValid(veh) and veh.IsGlideVehicle == true) then
            lastDSPWanted = nil
            return
        end

        local wantMuffle = ShouldMuffleNow(ply, veh)
        local wantDSP = wantMuffle and 30 or 1

        if lastDSPWanted ~= wantDSP then
            lastDSPWanted = wantDSP
            ply:SetDSP(wantDSP)
        end
    end)

    local L = Glide.GetLanguageText

    local function SetBoolCVar(cvar, value)
        RunConsoleCommand(cvar:GetName(), value and "1" or "0")
    end

    list.Set("GlideConfigExtensions", "#glide.extension.glass_breaking", function(config, panel)
        config.CreateToggle(panel, L"misc.glass_breaking.enabled", CVAR_ENABLED:GetBool(), function(v)
            SetBoolCVar(CVAR_ENABLED, v)
        end)

        local s_crack = config.CreateSlider(panel, L"misc.glass_breaking.crack_damage", CVAR_CRACK:GetDefault(), 0, 50000, 0, function(v)
            RunConsoleCommand(CVAR_CRACK:GetName(), tostring(v))
        end)
        s_crack:SetValue(CVAR_CRACK:GetInt())

        local s_break = config.CreateSlider(panel, L"misc.glass_breaking.break_damage", CVAR_BREAK:GetDefault(), 0, 50000, 0, function(v)
            RunConsoleCommand(CVAR_BREAK:GetName(), tostring(v))
        end)
        s_break:SetValue(CVAR_BREAK:GetInt())

        local s_lvl = config.CreateSlider(panel, L"misc.glass_breaking.sound_level", CVAR_SOUNDLEVEL:GetDefault(), 50, 140, 0, function(v)
            RunConsoleCommand(CVAR_SOUNDLEVEL:GetName(), tostring(v))
        end)
        s_lvl:SetValue(CVAR_SOUNDLEVEL:GetInt())
    end)

    return
end

if SERVER then
    local function EnsureGlassMeta(ent)
        if ent._glideGlass ~= nil then return end

        local mats, rootBase = DetectGlassSubmaterials(ent)
        if not mats then
            ent._glideGlass = false
            ent:SetNW2Bool(NW_GLASS_BROKEN, false)
            return
        end

        ent._glideGlass = {
            mats = mats,
            rootBase = rootBase,
            dmg = 0,
            state = 0
        }

        ent:SetNW2Bool(NW_GLASS_BROKEN, false)
    end

    local function GetGlassSoundPatch(ent, path, level)
        if not IsValid(ent) or not isstring(path) or path == "" then return nil end
        ent._glideGlassSoundPatches = ent._glideGlassSoundPatches or {}

        local p = ent._glideGlassSoundPatches[path]
        if p == nil then
            p = CreateSound(ent, path)
            ent._glideGlassSoundPatches[path] = p
        end

        if p and p.SetSoundLevel then
            p:SetSoundLevel(level)
        end

        return p
    end

    local function PlayGlassSound(ent, path)
        if not IsValid(ent) then return end
        if not isstring(path) or path == "" then return end

        local lvl = CVAR_SOUNDLEVEL:GetInt()
        local p = GetGlassSoundPatch(ent, path, lvl)
        if not p then return end
        p:Play()
    end

    local function ApplyGlassState(ent, newState)
        EnsureGlassMeta(ent)
        if ent._glideGlass == false then return end

        local g = ent._glideGlass
        if not g then return end
        if g.state == newState then return end

        g.state = newState
        ent:SetNW2Bool(NW_GLASS_BROKEN, newState == 2)

        if newState == 0 then
            for _, mat in ipairs(g.mats) do
                ent:SetSubMaterial(mat.idx, mat.orig)
            end

            return
        end

        for _, mat in ipairs(g.mats) do
            local rep = PickGlassReplacement(newState, mat.base, g.rootBase)
            ent:SetSubMaterial(mat.idx, rep)
        end

        if newState == 1 then
            local snd = BuildIndexedSoundPath(CRACK_SOUND_BASE, CRACK_SOUND_COUNT)
            if snd then PlayGlassSound(ent, snd) end
        elseif newState == 2 then
            local snd = BuildIndexedSoundPath(BREAK_SOUND_BASE, BREAK_SOUND_COUNT)
            if snd then PlayGlassSound(ent, snd) end
            SendGlassShatterFX(ent)
        end
    end

    local function RecomputeStateFromDamage(ent)
        EnsureGlassMeta(ent)
        if ent._glideGlass == false then return end

        local g = ent._glideGlass
        if not g then return end

        local crack = CVAR_CRACK:GetFloat()
        local brk = CVAR_BREAK:GetFloat()
        local dmg = tonumber(g.dmg) or 0

        if brk > 0 and dmg >= brk then
            ApplyGlassState(ent, 2)
            return
        end

        if crack > 0 and dmg >= crack then
            ApplyGlassState(ent, 1)
            return
        end

        ApplyGlassState(ent, 0)
    end

    local function ForceBreakGlass(ent)
        if not CVAR_ENABLED:GetBool() then return false end

        EnsureGlassMeta(ent)
        if ent._glideGlass == false then return false end

        local g = ent._glideGlass
        if not g then return false end

        g.dmg = math.max(g.dmg or 0, CVAR_CRACK:GetFloat(), CVAR_BREAK:GetFloat())
        ApplyGlassState(ent, 2)

        return true
    end

    local function OnDamage(ent, dmg)
        EnsureGlassMeta(ent)
        if ent._glideGlass == false then return end

        local g = ent._glideGlass
        if not g then return end

        g.dmg = (g.dmg or 0) + dmg
        RecomputeStateFromDamage(ent)
    end

    hook.Add("EntityTakeDamage", "Glide.GlassDamage", function(ent, dmginfo)
        if not CVAR_ENABLED:GetBool() then return end
        if not IsValidGlideVehicle(ent) then return end

        local dmg = dmginfo:GetDamage() or 0
        if dmg <= 0 then return end

        OnDamage(ent, dmg)
    end)

    do
        local wrapped = false

        local function WrapPartialRepair()
            if wrapped then return end
            if not Glide or not isfunction(Glide.PartialRepair) then return end
            wrapped = true

            local original = Glide.PartialRepair

            Glide.PartialRepair = function(ent, ...)
                local beforeChassis, beforeEngine
                if IsValid(ent) and ent.IsGlideVehicle == true then
                    beforeChassis = ent.GetChassisHealth and ent:GetChassisHealth() or nil
                    beforeEngine = ent.GetEngineHealth and ent:GetEngineHealth() or nil
                end

                local wasHealthIncreased, hasFinished = original(ent, ...)

                if not CVAR_ENABLED:GetBool() then
                    return wasHealthIncreased, hasFinished
                end

                if not (IsValid(ent) and ent.IsGlideVehicle == true) then
                    return wasHealthIncreased, hasFinished
                end

                EnsureGlassMeta(ent)
                if ent._glideGlass == false then
                    return wasHealthIncreased, hasFinished
                end

                local g = ent._glideGlass
                if not g then
                    return wasHealthIncreased, hasFinished
                end

                if not wasHealthIncreased then
                    return wasHealthIncreased, hasFinished
                end

                local afterChassis = ent.GetChassisHealth and ent:GetChassisHealth() or beforeChassis
                local afterEngine = ent.GetEngineHealth and ent:GetEngineHealth() or beforeEngine

                local chassisDelta = 0
                if isnumber(beforeChassis) and isnumber(afterChassis) then
                    chassisDelta = math.max(afterChassis - beforeChassis, 0)
                end

                local engineDelta = 0
                if isnumber(beforeEngine) and isnumber(afterEngine) then
                    engineDelta = math.max(afterEngine - beforeEngine, 0)
                end

                local maxCh = ent.MaxChassisHealth or 1000
                local repairPoints = chassisDelta + (engineDelta * maxCh)

                local scale = math.max(CVAR_REPAIR_SCALE:GetFloat(), 0)
                repairPoints = repairPoints * scale

                if repairPoints > 0 then
                    g.dmg = math.max((g.dmg or 0) - repairPoints, 0)
                    RecomputeStateFromDamage(ent)
                end

                return wasHealthIncreased, hasFinished
            end
        end

        WrapPartialRepair()
        hook.Add("InitPostEntity", "Glide.GlassDamage.WrapPartialRepair", function()
            WrapPartialRepair()
        end)
    end

    hook.Add("EntityRemoved", "Glide.GlassDamage.Cleanup", function(ent)
        if ent._glideGlassSoundPatches then
            for _, p in pairs(ent._glideGlassSoundPatches) do
                if p and p.Stop then p:Stop() end
            end
            ent._glideGlassSoundPatches = nil
        end

        if ent._glideGlass and ent._glideGlass ~= false then
            ent._glideGlass = nil
        end
    end)

    local function WrapSeatbeltCompat(ent)
        if not IsValidGlideVehicle(ent) then return end
        if ent._glideGlassSeatbeltCompatWrapped then return end

        local original = ent.CanFallOnCollision
        if not isfunction(original) then return end

        ent._glideGlassSeatbeltCompatWrapped = true

        ent.CanFallOnCollision = function(self, seatIndex, ...)
            local result = original(self, seatIndex, ...)

            -- Seatbelt addon creates `self.seatbelts`.
            -- If CanFallOnCollision allows the player to fall/eject, break the glass.
            if result ~= false and istable(self.seatbelts) then
                ForceBreakGlass(self)
            end

            return result
        end
    end

    local function TryWrapSeatbeltCompat(ent)
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            WrapSeatbeltCompat(ent)
        end)
    end

    hook.Add("OnEntityCreated", "Glide.GlassDamage.SeatbeltCompat", TryWrapSeatbeltCompat)

    timer.Simple(0, function()
        for _, ent in ipairs(ents.GetAll()) do
            WrapSeatbeltCompat(ent)
        end
    end)
end