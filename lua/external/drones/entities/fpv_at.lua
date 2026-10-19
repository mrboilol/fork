AddCSLuaFile()

game.AddParticles( "particles/kamik_bomb.pcf")

ENT.Base = "drone_kamikaze_entity"
ENT.PrintName = "FPV AT"
ENT.Category = "[FPV Drones]Kamikaze"
ENT.Spawnable = false

-- Правильный путь
ENT.IconOverride = "materials/vgui/entities/drone_AT_entity.png"

-- Заставляем сервер отправить иконку игрокам при подключении
if SERVER then
    resource.AddFile("materials/vgui/entities/drone_AT_entity.png")
end

ENT.armor = 75
ENT.forward = 50
ENT.up = 10
ENT.cam_up = -6.3

ENT.EngineSoundPath = "kamikaze/fpv_idlesound.ogg"
ENT.EngineSoundLevel = 95
ENT.ExplosionSound = "kamikaze/kamikbomb.wav"

ENT.FLIGHT_TIME = 150
ENT.BATTERY_VOLT_MAX = 25.2
ENT.BATTERY_VOLT_MIN = 19.8

ENT.CrashVelocityThreshold = 350 
ENT.DamageVelocityThreshold = 200

function ENT:Initialize()
    if CLIENT then return end

    self:_Initialize("models/zombie19994/fpv_at.mdl", 40)
    
    self:SetNWFloat("Kamikaze_BatteryPct", 1.0)
    self.InternalBattery = 1.0
    self.BatteryLastThink = CurTime()
    
    self:SetNWInt("Kamikaze_Interference", 0)
    self.SpawnTime = CurTime()

    self:StartFlightAnimations()

    if not self.Sound then
        self.Sound = CreateSound(self, self.EngineSoundPath)
        self.Sound:SetSoundLevel(self.EngineSoundLevel)
        self.Sound:Play()
    end
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:StartFlightAnimations()
    local seqLoop = self:LookupSequence("fpv_at_blades_rotation_loop")
    if seqLoop ~= -1 then
        self:ResetSequence(seqLoop)
        self:SetCycle(0)
        self:SetPlaybackRate(4.0)
        self:SetAutomaticFrameAdvance(true)
    end
end

function ENT:Think()
    if SERVER then
        local ct = CurTime()
        local dt = ct - (self.BatteryLastThink or ct)
        self.BatteryLastThink = ct

        if self.Enabled and not self:GetNWBool("Kamikaze_DeadBattery") then
            self.InternalBattery = math.Clamp(self.InternalBattery - dt / self.FLIGHT_TIME, 0, 1)
            self:SetNWFloat("Kamikaze_BatteryPct", self.InternalBattery)

            if self.InternalBattery <= 0 then
                self:SetNWBool("Kamikaze_DeadBattery", true)
                self.Enabled = false
                if self.Sound then self.Sound:Stop() end
            end

            if self.Sound then
                if not self.Sound:IsPlaying() then self.Sound:Play() end
                local vel = self:GetVelocity():Length()
                local pitch = math.Clamp(90 + (vel / 15), 80, 140)
                self.Sound:ChangePitch(pitch, 0.1)
            end
        end

        local user = self:GetDriver()
        if IsValid(user) then
            -- 🛠️ ФИКС: Замораживаем тело игрока
            if user:GetMoveType() ~= MOVETYPE_NONE then
                user:SetMoveType(MOVETYPE_NONE)
            end
        end

        if self.Enabled then
            local phys = self:GetPhysicsObject()
            if IsValid(phys) and phys:IsAsleep() then
                phys:Wake()
            end
        end
    end

    self:_Think()
    self:NextThink(CurTime())
    return true
end

function ENT:PhysicsSimulate(phys, delta)
    return self:_HeavyFlightSimulate(phys, delta)
end

function ENT:TriggerDroneExplosion(user)
    if not IsValid(user) and SERVER then user = self.HBOWNER end
    
    local pos = self:GetPos()
    util.ScreenShake(pos, 20, 20, 0.7, 1500)
    
    util.BlastDamage(self, IsValid(user) and user or self, pos, 300, 1200) 
    
    local effect = ents.Create("info_particle_system")
    effect:SetPos(pos)
    effect:SetKeyValue("effect_name", "kam_explo")
    effect:SetKeyValue("start_active", "1")
    effect:Spawn()
    effect:Activate()
    effect:Fire("kill", "", 5)

    self:Remove()
end

function ENT:PhysicsCollide(data, phys)
    if CLIENT or not self.Enabled then return end
    
    if data.Speed > self.CrashVelocityThreshold then
        self:TriggerDroneExplosion(self:GetDriver())
    end
end

function ENT:CalcView(ply, pos, ang, fov)
    if self:GetDriver() == ply then
        local view = {}
        view.origin = self:GetPos() + self:GetForward() * 1.9 + self:GetUp() * 6
        view.angles = self:GetAngles()
        view.fov = 100
        view.drawviewer = false
        view.drawviewmodel = false
        view.znear = 1
        return view
    end
end

function ENT:Draw()
    if self:GetDriver() == LocalPlayer() then return end
    self:DrawModel()
end

function ENT:OnRemove()
    if SERVER and IsValid(self:GetDriver()) then
        self:SetDriver(NULL)
    end

    if self.Sound then
        self.Sound:Stop()
        self.Sound = nil
    end
end
