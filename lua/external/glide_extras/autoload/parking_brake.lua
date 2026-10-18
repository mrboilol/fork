local ACTION_PBRAKE = "parking_brake"
local SOUND_TOGGLE  = "vehicles/handbrake_parking.wav"
local SOUND_ALARM   = "vehicles/handbrake_alarm.wav"

local DOUBLE_TAP_WINDOW = 0.30
local PHYS_RELEASE_GRACE = 0.5

local VEHICLE_TYPE = Glide and Glide.VEHICLE_TYPE or nil

local ALLOWED_TYPE = {}
if VEHICLE_TYPE then
    ALLOWED_TYPE[VEHICLE_TYPE.CAR] = true
    ALLOWED_TYPE[VEHICLE_TYPE.MOTORCYCLE] = true
end

Glide.AddInputAction("general_controls", ACTION_PBRAKE, KEY_SPACE)

local CVAR_ENABLED = CreateConVar(
    "glide_extension_parking_brake",
    "1",
    FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
    "Enables parking brake extension for Glide."
)

local CVAR_ROUGH_DRIVING = CreateConVar(
    "glide_extension_parking_brake_rough_driving",
    "1",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Adds brake resistance while driving with parking brake enabled (0/1).",
    0,
    1
)

local CVAR_DRIVE_RESIST = CreateConVar(
    "glide_extension_parking_brake_drive_resist",
    "0.27",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Strength of drive resistance when rough driving is enabled (0..1).",
    0,
    1
)

local CVAR_ALARM = CreateConVar(
    "glide_extension_parking_brake_alarm",
    "1",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Plays warning alarm while driving with parking brake enabled (0/1).",
    0,
    1
)

local CVAR_GROUND_DIST = CreateConVar(
    "glide_extension_parking_brake_ground_dist",
    "20",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "How far below the chassis we consider 'grounded' for parking brake hold.",
    5,
    250
)

local CVAR_HOLD_SPEED = CreateConVar(
    "glide_extension_parking_brake_hold_speed",
    "55",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Max linear speed (units/s) under which the parking brake will stop the vehicle when unattended.",
    0,
    600
)

local CVAR_HOLD_ANGSPEED = CreateConVar(
    "glide_extension_parking_brake_hold_angspeed",
    "120",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Max angular speed under which the parking brake will stop rotation when unattended.",
    0,
    2000
)

local CVAR_IMPACT_COOLDOWN = CreateConVar(
    "glide_extension_parking_brake_impact_cooldown",
    "1.0",
    FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Seconds to wait before re-applying hold after significant movement.",
    0.0,
    5.0
)

local function inject(func_original, func)
    return function(...)
        if func_original then func_original(...) end
        func(...)
    end
end

local function IsValidGlideVehicle(ent)
    if not IsValid(ent) then return false end
    if not ent.IsGlideVehicle then return false end

    if VEHICLE_TYPE and ent.VehicleType then
        if not ALLOWED_TYPE[ent.VehicleType] then
            return false
        end
    end

    return true
end

local function GetPhys(ent)
    if not IsValid(ent) then return nil end
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return nil end
    return phys
end

local function IsGrounded(ent)
    if not IsValid(ent) then return false end

    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local z = mins.z + 4

    local pts = {
        Vector(0, 0, z),
        Vector(mins.x, mins.y, z),
        Vector(mins.x, maxs.y, z),
        Vector(maxs.x, mins.y, z),
        Vector(maxs.x, maxs.y, z),
    }

    local dist = CVAR_GROUND_DIST:GetFloat()
    local down = vector_up * -1

    for _, lp in ipairs(pts) do
        local startPos = ent:LocalToWorld(lp)
        local tr = util.TraceHull({
            start  = startPos,
            endpos = startPos + down * dist,
            mins   = Vector(-3, -3, -2),
            maxs   = Vector( 3,  3,  2),
            filter = ent,
            mask   = MASK_SOLID
        })

        if tr.Hit then
            if tr.HitNormal:Dot(vector_up) > 0.55 then
                return true
            end
        end
    end

    return false
end

if CLIENT then
    local L = Glide.GetLanguageText

    local function SetBoolCVar(cvar, value)
        RunConsoleCommand(cvar:GetName(), value and "1" or "0")
    end

    list.Set("GlideConfigExtensions", "#glide.extension.parking_brake", function(config, panel)
        config.CreateToggle(panel, L"misc.parking_brake.enabled", CVAR_ENABLED:GetBool(), function(v)
            SetBoolCVar(CVAR_ENABLED, v)
        end)

        config.CreateToggle(panel, L"misc.parking_brake.alarm", CVAR_ALARM:GetBool(), function(v)
            SetBoolCVar(CVAR_ALARM, v)
        end)

        config.CreateToggle(panel, L"misc.parking_brake.rough_driving", CVAR_ROUGH_DRIVING:GetBool(), function(v)
            SetBoolCVar(CVAR_ROUGH_DRIVING, v)
        end)

        local slider_resist = config.CreateSlider(panel, L"misc.parking_brake.resist_strength", CVAR_DRIVE_RESIST:GetDefault(), 0, 1, 2, function(v)
            RunConsoleCommand(CVAR_DRIVE_RESIST:GetName(), tostring(v))
        end)
        slider_resist:SetValue(CVAR_DRIVE_RESIST:GetFloat())

        local label = StyledTheme.CreateFormLabel(panel, L"settings.parking_brake.resistance_help")
        label:SetContentAlignment(5)

        local slider_ground = config.CreateSlider(panel, L"misc.parking_brake.ground_dist", CVAR_GROUND_DIST:GetDefault(), CVAR_GROUND_DIST:GetMin(), CVAR_GROUND_DIST:GetMax(), 0, function(v)
            RunConsoleCommand(CVAR_GROUND_DIST:GetName(), tostring(v))
        end)
        slider_ground:SetValue(CVAR_GROUND_DIST:GetFloat())

        local label = StyledTheme.CreateFormLabel(panel, L"settings.parking_brake.ground_dist_warning")
        label:SetContentAlignment(5)
    end)

    return
end

if SERVER then
    local function EnsureAlarmSound(self)
        if self._glidePB_AlarmSound ~= nil then return end
        self._glidePB_AlarmSound = CreateSound(self, SOUND_ALARM)
        if self._glidePB_AlarmSound then
            self._glidePB_AlarmSound:SetSoundLevel(60)
        end
    end

    local function AlarmOn(self)
        if not CVAR_ALARM:GetBool() then return end
        EnsureAlarmSound(self)
        if not self._glidePB_AlarmSound then return end
        if self._glidePB_AlarmPlaying then return end
        self._glidePB_AlarmSound:Play()
        self._glidePB_AlarmPlaying = true
    end

    local function AlarmOff(self)
        if self._glidePB_AlarmSound == nil then
            self._glidePB_AlarmPlaying = false
            return
        end
        if not self._glidePB_AlarmPlaying then return end
        self._glidePB_AlarmSound:FadeOut(0.2)
        self._glidePB_AlarmPlaying = false
    end

    local function OnPostInitialize(self)
        self._glidePB_LastTap = {}
        self.GlideParkingBrake = false

        self._glidePB_AlarmSound = nil
        self._glidePB_AlarmPlaying = false

        self._glidePB_NoHoldUntil = 0
        self._glidePB_LastHeld = 0

        self:SetNWBool("glide_parking_brake", false)
    end

    local function SetBrakeState(self, state)
        self.GlideParkingBrake = state and true or false
        self:SetNWBool("glide_parking_brake", self.GlideParkingBrake)
        self:EmitSound(SOUND_TOGGLE, 70, 100, 1, CHAN_AUTO)

        if not self.GlideParkingBrake then
            AlarmOff(self)
        end
    end

    local function ToggleBrake(self)
        SetBrakeState(self, not self.GlideParkingBrake)
    end

    local function MarkImpactCooldown(self)
        self._glidePB_NoHoldUntil = CurTime() + CVAR_IMPACT_COOLDOWN:GetFloat()
    end

    local function ApplyParkHold(self)
        if not self.GlideParkingBrake then return end
        if IsValid(self:GetDriver()) then return end

        if self:IsPlayerHolding() then
            self._glidePB_LastHeld = CurTime()
            return
        end

        if (CurTime() - (self._glidePB_LastHeld or 0)) < PHYS_RELEASE_GRACE then
            return
        end

        if CurTime() < (self._glidePB_NoHoldUntil or 0) then return end
        if not IsGrounded(self) then return end

        local phys = GetPhys(self)
        if not phys then return end

        local holdSpeed = CVAR_HOLD_SPEED:GetFloat()
        local holdAng   = CVAR_HOLD_ANGSPEED:GetFloat()

        local v  = phys:GetVelocity()
        local av = phys:GetAngleVelocity()

        if v:Length() > holdSpeed or av:Length() > holdAng then
            MarkImpactCooldown(self)
            return
        end

        phys:SetVelocityInstantaneous(vector_origin)
        phys:SetAngleVelocityInstantaneous(vector_origin)
        phys:Sleep()
    end

    local function ApplyDriveResistance(self, dt)
        if not CVAR_ROUGH_DRIVING:GetBool() then return end
        if not self.GlideParkingBrake then return end
        if self:IsPlayerHolding() then return end

        local driver = self:GetDriver()
        if not IsValid(driver) then return end

        local phys = GetPhys(self)
        if not phys then return end

        local strength = math.Clamp(CVAR_DRIVE_RESIST:GetFloat(), 0, 1)
        if strength <= 0 then return end

        local groundedMul = IsGrounded(self) and 1 or 0.20

        local v  = phys:GetVelocity()
        local av = phys:GetAngleVelocity()

        local factor = math.Clamp(1 - (strength * 6.5 * groundedMul) * dt, 0, 1)
        phys:SetVelocityInstantaneous(v * factor)

        local afactor = math.Clamp(1 - (strength * 4.0 * groundedMul) * dt, 0, 1)
        phys:SetAngleVelocityInstantaneous(av * afactor)
    end

    local function UpdateAlarm(self)
        if not CVAR_ALARM:GetBool() then
            AlarmOff(self)
            return
        end

        if not self.GlideParkingBrake then
            AlarmOff(self)
            return
        end

        local driver = self:GetDriver()
        if not IsValid(driver) then
            AlarmOff(self)
            return
        end

        local phys = GetPhys(self)
        local speed = phys and phys:GetVelocity():Length() or 0

        if speed > 35 then
            AlarmOn(self)
        else
            AlarmOff(self)
        end
    end

    local function OnSeatInput(self, seatIndex, action, pressed)
        if not CVAR_ENABLED:GetBool() then return end
        if action ~= ACTION_PBRAKE then return end
        if not pressed then return end

        self._glidePB_LastTap = self._glidePB_LastTap or {}

        local now = CurTime()
        local last = self._glidePB_LastTap[seatIndex] or 0
        self._glidePB_LastTap[seatIndex] = now

        if (now - last) <= DOUBLE_TAP_WINDOW then
            self._glidePB_LastTap[seatIndex] = 0
            ToggleBrake(self)
        end
    end

    local function OnDriverExit(self)
        if not CVAR_ENABLED:GetBool() then return end
        if not self.GlideParkingBrake then return end
        ApplyParkHold(self)
        AlarmOff(self)
    end

    local function OnDriverEnter(self)
        EnsureAlarmSound(self)
    end

    local function OnPostThink(self, dt, selfTbl)
        if not CVAR_ENABLED:GetBool() then return end

        if not self.GlideParkingBrake then
            AlarmOff(self)
            return
        end

        UpdateAlarm(self)

        if IsValid(self:GetDriver()) then
            ApplyDriveResistance(self, dt)
            return
        end

        ApplyParkHold(self)
    end

    local function OnRemove(self)
        if self._glidePB_AlarmSound ~= nil then
            self._glidePB_AlarmSound:Stop()
            self._glidePB_AlarmSound = nil
        end
        self._glidePB_AlarmPlaying = false
    end

    local function OnEntityCreated(ent)
        timer.Simple(0, function()
            if not IsValidGlideVehicle(ent) then return end

            ent.OnPostInitialize = inject(ent.OnPostInitialize, OnPostInitialize)
            ent.OnSeatInput      = inject(ent.OnSeatInput, OnSeatInput)
            ent.OnDriverExit     = inject(ent.OnDriverExit, OnDriverExit)
            ent.OnDriverEnter    = inject(ent.OnDriverEnter, OnDriverEnter)
            ent.OnPostThink      = inject(ent.OnPostThink, OnPostThink)
            ent.OnRemove         = inject(ent.OnRemove, OnRemove)

            if ent._glidePB_LastTap == nil then
                OnPostInitialize(ent)
            end
        end)
    end

    local function Enable()
        hook.Add("OnEntityCreated", "Glide.Extension.ParkingBrake", OnEntityCreated)
    end

    local function Disable()
        hook.Remove("OnEntityCreated", "Glide.Extension.ParkingBrake")
    end

    if CVAR_ENABLED:GetBool() then
        Enable()
    end

    cvars.AddChangeCallback(CVAR_ENABLED:GetName(), function(_, _, value)
        if tobool(value) then
            Enable()
        else
            Disable()
        end
    end)
end