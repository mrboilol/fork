if not Glide then return end

local VEHICLE_TYPE = Glide.VEHICLE_TYPE

local CVAR_ENABLED = CreateConVar(
    "glide_extension_rotorwash",
    "1",
    FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
    "Enabled."
)

local CVAR_RADIUS = CreateConVar(
    "glide_extension_rotorwash_radius",
    "400",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Radius.",
    100,
    1500
)

local CVAR_MAXMASS = CreateConVar(
    "glide_extension_rotorwash_maxmass",
    "90",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Max prop push mass.",
    1,
    2000
)

local CVAR_FORCE = CreateConVar(
    "glide_extension_rotorwash_force",
    "600",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Prop push force.",
    0,
    8000
)

local CVAR_WIND = CreateConVar(
    "glide_extension_rotorwash_wind",
    "300",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Wind strength.",
    0,
    1000
)

local CVAR_RATE = CreateConVar(
    "glide_extension_rotorwash_rate",
    "0.10",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Update interval (seconds).",
    0.02,
    1
)

local function IsGlideHeli(ent)
    if not IsValid(ent) or not ent.IsGlideVehicle then return false end

    if ent.VehicleType ~= nil and VEHICLE_TYPE ~= nil then
        if VEHICLE_TYPE.HELI ~= nil and ent.VehicleType == VEHICLE_TYPE.HELI then return true end
        if VEHICLE_TYPE.HELICOPTER ~= nil and ent.VehicleType == VEHICLE_TYPE.HELICOPTER then return true end
    end

    if ent.MainRotorOffset ~= nil or ent.MainRotorRadius ~= nil then return true end
    local cls = string.lower(ent:GetClass() or "")
    if string.find(cls, "heli", 1, true) then return true end

    return false
end

local function IsEngineOn(ent)
    if not IsValid(ent) then return false end

    if ent.IsEngineOn then
        local ok, res = pcall(ent.IsEngineOn, ent)
        if ok then return res == true end
    end

    if ent.GetEngineState then
        local ok, res = pcall(ent.GetEngineState, ent)
        if ok then return (tonumber(res) or 0) > 0 end
    end

    if ent.engineState ~= nil then
        return (tonumber(ent.engineState) or 0) > 0
    end

    return false
end

local function RotorWorldPos(ent)
    local off = ent.MainRotorOffset
    if isvector(off) then
        return ent:LocalToWorld(off)
    end
    return ent:WorldSpaceCenter()
end

if CLIENT then
    local L = Glide.GetLanguageText

    local function SetBoolCVar(cvar, value)
        RunConsoleCommand(cvar:GetName(), value and "1" or "0")
    end

    list.Set("GlideConfigExtensions", "#glide.extension.rotorwash", function(config, panel)
        config.CreateToggle(panel, L"misc.rotorwash.enabled", CVAR_ENABLED:GetBool(), function(v)
            SetBoolCVar(CVAR_ENABLED, v)
        end)

        local s_radius = config.CreateSlider(panel, L"misc.rotorwash.radius", CVAR_RADIUS:GetDefault(), CVAR_RADIUS:GetMin(), CVAR_RADIUS:GetMax(), 0, function(v)
            RunConsoleCommand(CVAR_RADIUS:GetName(), tostring(v))
        end)
        s_radius:SetValue(CVAR_RADIUS:GetInt())

        local s_force = config.CreateSlider(panel, L"misc.rotorwash.force", CVAR_FORCE:GetDefault(), CVAR_FORCE:GetMin(), CVAR_FORCE:GetMax(), 0, function(v)
            RunConsoleCommand(CVAR_FORCE:GetName(), tostring(v))
        end)
        s_force:SetValue(CVAR_FORCE:GetInt())

        local s_mass = config.CreateSlider(panel, L"misc.rotorwash.max_mass", CVAR_MAXMASS:GetDefault(), CVAR_MAXMASS:GetMin(), CVAR_MAXMASS:GetMax(), 0, function(v)
            RunConsoleCommand(CVAR_MAXMASS:GetName(), tostring(v))
        end)
        s_mass:SetValue(CVAR_MAXMASS:GetInt())

        local s_wind = config.CreateSlider(panel, L"misc.rotorwash.wind", CVAR_WIND:GetDefault(), CVAR_WIND:GetMin(), CVAR_WIND:GetMax(), 0, function(v)
            RunConsoleCommand(CVAR_WIND:GetName(), tostring(v))
        end)
        s_wind:SetValue(CVAR_WIND:GetInt())

        local label = StyledTheme.CreateFormLabel(panel, L"settings.rotorwash.client_wind")
        label:SetContentAlignment(5)
    end)

    local windEnt = nil
    local windOn = false
    local nextUpdate = 0

    local function EnsureWind()
        if IsValid(windEnt) then return end

        windEnt = ents.CreateClientside("env_wind")
        if not IsValid(windEnt) then
            windEnt = nil
            return
        end

        windEnt:SetPos(vector_origin)
        windEnt:SetAngles(Angle(0, math.random(0, 360), 0))

        windEnt:SetKeyValue("minwind", "0")
        windEnt:SetKeyValue("maxwind", "0")
        windEnt:SetKeyValue("mingust", "0")
        windEnt:SetKeyValue("maxgust", "0")
        windEnt:SetKeyValue("mingustdelay", "0.2")
        windEnt:SetKeyValue("maxgustdelay", "0.6")
        windEnt:SetKeyValue("gustduration", "0.2")
        windEnt:SetKeyValue("gustdirchange", "10")

        windEnt:Spawn()
        windEnt:Activate()
        windEnt:Fire("Enable")
    end

    local function SetWindStrength(strength)
        if not IsValid(windEnt) then return end

        local s = math.max(0, strength or 0)

        local a = windEnt:GetAngles()
        a.y = a.y + math.Rand(-12, 12)
        windEnt:SetAngles(a)

        windEnt:SetKeyValue("minwind", tostring(math.max(0, s * 0.6)))
        windEnt:SetKeyValue("maxwind", tostring(math.max(0, s)))
        windEnt:SetKeyValue("mingust", tostring(math.max(0, s * 0.2)))
        windEnt:SetKeyValue("maxgust", tostring(math.max(0, s * 0.35)))
    end

    local function DisableWind()
        if not IsValid(windEnt) then return end
        if not windOn then return end
        windOn = false
        SetWindStrength(0)
    end

    hook.Add("Think", "Glide.Extension.RotorWash.ClientWind", function()
        if not CVAR_ENABLED:GetBool() then
            DisableWind()
            return
        end

        local ply = LocalPlayer()
        if not IsValid(ply) then
            DisableWind()
            return
        end

        if not ply:InVehicle() then
            DisableWind()
            return
        end

        local gveh = ply.GlideGetVehicle and ply:GlideGetVehicle() or nil
        if not (IsValid(gveh) and IsGlideHeli(gveh)) then
            DisableWind()
            return
        end

        if not IsEngineOn(gveh) then
            DisableWind()
            return
        end

        local now = CurTime()
        if now < nextUpdate then return end
        nextUpdate = now + math.Clamp(CVAR_RATE:GetFloat(), 0.02, 1)

        EnsureWind()
        if not IsValid(windEnt) then return end

        windOn = true

        local rotorPos = RotorWorldPos(gveh)
        local height = math.abs(rotorPos.z - gveh:GetPos().z)
        local heightMul = 1
        if height > 800 then
            heightMul = math.Clamp(1 - ((height - 800) / 2200), 0.05, 1)
        end

        SetWindStrength(CVAR_WIND:GetFloat() * heightMul)
    end)

    return
end

if SERVER then
    local trackedHelis = {}
    local nextThinkByEnt = {}

    local function TrackHeli(ent)
        if not IsGlideHeli(ent) then return end
        trackedHelis[ent] = true
    end

    local function ForgetHeli(ent)
        trackedHelis[ent] = nil
        nextThinkByEnt[ent] = nil
    end

    local function RefreshHeliList()
        table.Empty(trackedHelis)
        table.Empty(nextThinkByEnt)

        for _, ent in ipairs(ents.GetAll()) do
            TrackHeli(ent)
        end
    end

    local function PushProps(ent, origin, radius, maxMass, baseForce)
        local nearby = ents.FindInSphere(origin, radius)
        if not istable(nearby) then return end

        for _, e in ipairs(nearby) do
            if not IsValid(e) then continue end
            if e == ent then continue end

            if e:IsPlayer() or e:IsNPC() or e:IsVehicle() then continue end
            if e.GetClass and e:GetClass() == "worldspawn" then continue end

            local phys = e:GetPhysicsObject()
            if not IsValid(phys) then continue end
            if not phys:IsMoveable() then continue end

            local mass = phys:GetMass()
            if mass <= 0 or mass > maxMass then continue end

            local ep = e:WorldSpaceCenter()
            local d = ep:Distance(origin)
            if d <= 1 or d > radius then continue end

            local frac = 1 - (d / radius)
            if frac <= 0 then continue end

            local dir = ep - origin
            dir.z = 0

            local len = dir:Length()
            if len <= 0.001 then continue end

            dir:Mul(1 / len)

            local push = (dir * (baseForce * frac)) + Vector(0, 0, -baseForce * 0.05 * frac)

            local massScale = math.Clamp(1 - (mass / maxMass), 0.05, 1)
            push:Mul(massScale)

            phys:ApplyForceCenter(push)
            phys:AddAngleVelocity(VectorRand() * (15 * frac * massScale))
        end
    end

    hook.Add("OnEntityCreated", "Glide.Extension.RotorWash.TrackHelis", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            TrackHeli(ent)
        end)
    end)

    hook.Add("InitPostEntity", "Glide.Extension.RotorWash.RefreshHelis", function()
        timer.Simple(0, RefreshHeliList)
    end)

    timer.Simple(0, RefreshHeliList)

    hook.Add("Think", "Glide.Extension.RotorWash.ServerPush", function()
        if not CVAR_ENABLED:GetBool() then return end

        local now = CurTime()
        local radius = CVAR_RADIUS:GetFloat()
        local maxMass = CVAR_MAXMASS:GetFloat()
        local baseForce = CVAR_FORCE:GetFloat()
        local rate = math.Clamp(CVAR_RATE:GetFloat(), 0.02, 1)

        for ent in pairs(trackedHelis) do
            if not IsGlideHeli(ent) then
                ForgetHeli(ent)
                continue
            end

            local nextT = nextThinkByEnt[ent] or 0
            if now < nextT then continue end

            nextThinkByEnt[ent] = now + rate

            if not IsEngineOn(ent) then
                continue
            end

            local rotorPos = RotorWorldPos(ent)

            local height = math.abs(rotorPos.z - ent:GetPos().z)
            local heightMul = 1

            if height > 800 then
                heightMul = math.Clamp(1 - ((height - 800) / 2200), 0.05, 1)
            end

            PushProps(ent, rotorPos, radius, maxMass, baseForce * heightMul)
        end
    end)

    hook.Add("EntityRemoved", "Glide.Extension.RotorWash.Cleanup", function(ent)
        ForgetHeli(ent)
    end)
end