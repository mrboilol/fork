local plymeta = FindMetaTable("Player")

if SERVER then
    util.AddNetworkString("send_tinnitus")
    util.AddNetworkString("send_custom_tinnitus")
    util.AddNetworkString("stop_custom_tinnitus")

    function plymeta:AddTinnitus(time, needSound, brainDamage)
        needSound = needSound or false
        brainDamage = brainDamage or false
        net.Start("send_tinnitus")
            net.WriteFloat(time)
            net.WriteBool(needSound)
            net.WriteBool(brainDamage)
        net.Send(self)
    end

    function plymeta:PlayCustomTinnitus(soundFile)
        if not IsValid(self) then return end
        net.Start("send_custom_tinnitus")
            net.WriteString(soundFile)
        net.Send(self)
    end

    function plymeta:StopCustomTinnitus()
        if not IsValid(self) then return end
        net.Start("stop_custom_tinnitus")
        net.Send(self)
    end
end

if CLIENT then
    local tinnitusExposure = 0
    local lastTinnitusThink = CurTime()

    local function AddTinnitus(time, needSound, brainDamage)
        local lply = LocalPlayer()
        if not IsValid(lply) then return end
        lply.tinnitus = math.max(lply.tinnitus or 0, CurTime() + time * 4)
        lply.tinnitusBrainDamage = brainDamage or false
        lply:SetDSP(32)
        if needSound then
            -- intentionally empty; sound is handled by callers
        end
    end

    function plymeta:AddTinnitus(time, needSound, brainDamage)
        needSound = needSound or false
        AddTinnitus(time, needSound, brainDamage)
    end

    net.Receive("send_tinnitus", function()
        local time = net.ReadFloat()
        local bool = net.ReadBool()
        local brainDamage = net.ReadBool()
        AddTinnitus(time, bool, brainDamage)
    end)

    net.Receive("send_custom_tinnitus", function()
        local soundFile = net.ReadString()
        LocalPlayer():EmitSound(soundFile, 75, 100, 1, CHAN_AUTO)
    end)

    net.Receive("stop_custom_tinnitus", function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:StopSound("tinnitus.wav")
            ply:StopSound("tinnituslong.wav")
        end
    end)

    hook.Add("Think", "HG_TinnitusAdaptiveRecovery", function()
        local now = CurTime()
        local dt = math.Clamp(now - lastTinnitusThink, 0, 0.1)
        lastTinnitusThink = now
        local lply = LocalPlayer()
        if not IsValid(lply) then return end

        if (lply.tinnitus or 0) > now then
            tinnitusExposure = tinnitusExposure + dt
            local recoveryBonus = math.Clamp((tinnitusExposure - 8) / 24, 0, 1) * 2
            lply.tinnitus = math.max((lply.tinnitus or now) - dt * recoveryBonus, now)
        else
            tinnitusExposure = math.max(tinnitusExposure - dt * 4, 0)
        end
    end)
end
