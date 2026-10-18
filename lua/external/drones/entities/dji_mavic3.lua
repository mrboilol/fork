AddCSLuaFile()

ENT.Base = "drone_kamikaze_entity"
ENT.PrintName = "DJI Mavic 3"
ENT.Category = "[FPV Drones]Kamikaze"
ENT.Spawnable = false
ENT.AdminSpawnable = false

-- Правильный путь (без addons/...)
ENT.IconOverride = "materials/vgui/entities/drone_mavic3_entity.png"

-- Заставляем сервер отправить иконку игрокам при подключении
if SERVER then
    resource.AddFile("materials/vgui/entities/drone_mavic3_entity.png")
end

-- Настройки камеры
ENT.forward = 50
ENT.up = 0
ENT.cam_up = -6.3

-- звук
ENT.EngineSoundPath = "kamikaze/DJI_mavic_idle.wav"
ENT.EngineSoundLevel = 90
ENT.EngineSoundLevelExternal = 75

-- флаги
ENT.EjectKeyPressed = false
ENT.IsDestroyed = false
ENT.IsCrashed = false
ENT.AnimationsStarted = false
ENT.SpawnPos = nil

-- 🔋 Заряд (16 минут)
ENT.BatteryTime = 960
ENT.BatteryLevel = 1.0
ENT.BatteryDrainRate = 1 / 960

-- 📡 Сигнал
ENT.SignalLevel = 1
ENT.SignalLost = false
ENT.SignalLostTime = 0
ENT.SignalLostDelay = 5

-- 🎥 ЗУМ КАМЕРЫ
ENT.ZoomLevel = 1
ENT.ZoomKeyPressed = false
ENT.ZoomLevels = {1, 3, 7}
ENT.ZoomIndex = 1
ENT.JustEntered = false

if CLIENT then
    ENT.SmoothPitch = 0
    ENT.SmoothFOV = 90
end

ENT.WElements = {}
ENT.VElements = {}
ENT.gun = nil

function ENT:Initialize()
    if CLIENT then return end

    self:_Initialize("models/llirikslon/mavic3.mdl", 30)

    self.SpawnPos = self:GetPos()
    
    self:SetNWFloat("Mavic_SpawnPosX", self.SpawnPos.x)
    self:SetNWFloat("Mavic_SpawnPosY", self.SpawnPos.y)
    self:SetNWFloat("Mavic_SpawnPosZ", self.SpawnPos.z)

    self.ZoomIndex = 1
    self.ZoomLevel = self.ZoomLevels[1]
    self:SetNWInt("Mavic_ZoomLevel", 1) 
    self:SetNWFloat("Mavic_CamPitch", 0) 

    self:SetAngles(self:GetAngles() + Angle(0, 180, 0))
    self.BatteryLevel = 1.0
    self.NextBatteryThink = CurTime() + 1.0
    self.NextSignalCheck = CurTime() + 0.5
    self.JustEntered = false

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
        phys:ApplyForceCenter(Vector(0, 0, 1))
    end

    self:StartNormalAnimations()

    if not self.Sound then
        local finalSound = file.Exists("sound/" .. self.EngineSoundPath, "GAME") and self.EngineSoundPath or "npc/manhack/mh_engine_loop1.wav"
        self.Sound = CreateSound(self, finalSound)
        self.Sound:Play()
    end
end

function ENT:GetSignalLevelFromDistance(dist)
    if dist <= 400 then return 1 end
    if dist <= 500 then return 2 end
    if dist <= 800 then return 3 end
    if dist <= 1000 then return 4 end
    return 0
end

function ENT:ToggleZoom()
    self.ZoomIndex = self.ZoomIndex + 1
    if self.ZoomIndex > #self.ZoomLevels then
        self.ZoomIndex = 1
    end
    
    self.ZoomLevel = self.ZoomLevels[self.ZoomIndex]
    self:SetNWInt("Mavic_ZoomLevel", self.ZoomLevel)
end

function ENT:StartNormalAnimations()
    if self.IsDestroyed or self.IsCrashed then return end
    self.AnimationsStarted = true
    self:SetAutomaticFrameAdvance(true)

    local seqBegin = self:LookupSequence("mavic3_blades_rotation_begin")
    local seqLoop = self:LookupSequence("mavic3_blades_rotation_loop")

    if seqBegin ~= -1 then
        self:ResetSequence("mavic3_blades_rotation_begin")
        self:SetCycle(0)
        self:SetPlaybackRate(1.0)

        timer.Simple(1.0, function()
            if IsValid(self) and not self.IsDestroyed and not self.IsCrashed then
                self:StartLoopAnimation()
            end
        end)
    elseif seqLoop ~= -1 then
        self:StartLoopAnimation()
    end
end

function ENT:StartLoopAnimation()
    if self.IsDestroyed or self.IsCrashed then return end
    local seqLoop = self:LookupSequence("mavic3_blades_rotation_loop")
    if seqLoop ~= -1 then
        self:ResetSequence("mavic3_blades_rotation_loop")
        self:SetCycle(0)
        self:SetPlaybackRate(5.0)
        self:SetAutomaticFrameAdvance(true)
    end
end

function ENT:StartCrashedAnimation(reason)
    if self.IsDestroyed then return end

    self.IsCrashed = true
    self.Enabled = false

    local seqDestroy = self:LookupSequence("mavic3_blades_rotation_angle_90")
    if seqDestroy ~= -1 then
        self:ResetSequence("mavic3_blades_rotation_angle_90")
        self:SetCycle(0)
        self:SetPlaybackRate(1.0)
        self:SetAutomaticFrameAdvance(false)
    else
        self:ResetSequence("idle")
    end

    if self.Sound then
        self.Sound:Stop()
    end

    if self:GetDriver():IsValid() then
        self:EjectDriver() -- 🛠️ ФИКС: Безопасно выбрасываем пилота при краше
    end
end

function ENT:Think()
    if SERVER then
        local ct = CurTime()
        if self.IsDestroyed or self.IsCrashed then 
            self:NextThink(ct)
            return true 
        end

        if self.Sound and self.Sound:IsPlaying() and not self.IsDestroyed and not self.IsCrashed then
            local vel = self:GetVelocity():Length()
            local pitch = math.Clamp(80 + vel * 0.1, 70, 120)
            self.Sound:ChangePitch(pitch, 0.1)
        end

        local driver = self:GetDriver()

        -- 🛠️ ФИКС: Замораживаем игрока, чтобы он не падал под карту
        if IsValid(driver) and driver:IsPlayer() then
            if driver:GetMoveType() ~= MOVETYPE_NONE then
                driver:SetMoveType(MOVETYPE_NONE)
            end
        end

        if IsValid(driver) and self.Enabled then
            if ct > self.NextBatteryThink then
                self.NextBatteryThink = ct + 1.0
                self.BatteryLevel = math.Clamp(self.BatteryLevel - self.BatteryDrainRate, 0, 1)
                self:SetNWFloat("Mavic_BatteryLevel", self.BatteryLevel)
                if self.BatteryLevel <= 0 then 
                    self:StartCrashedAnimation("battery dead")
                    self:NextThink(ct)
                    return true
                end
            end
        end

        if IsValid(driver) and self.Enabled and self.SpawnPos then
            if ct > self.NextSignalCheck then
                self.NextSignalCheck = ct + 0.5
                local dist = self:GetPos():Distance(self.SpawnPos) / 39.37
                local newLevel = self:GetSignalLevelFromDistance(dist)

                if newLevel > 0 then
                    self.SignalLevel = newLevel
                    self:SetNWInt("Mavic_SignalLevel", self.SignalLevel)

                    if self.SignalLost then
                        self.SignalLost = false
                        self.SignalLostTime = 0
                    end
                else
                    if not self.SignalLost then
                        self.SignalLost = true
                        self.SignalLostTime = ct
                        self:SetNWInt("Mavic_SignalLevel", 4)
                    else
                        local lostFor = ct - self.SignalLostTime
                        if lostFor >= self.SignalLostDelay then
                            self:StartCrashedAnimation("signal lost")
                            self:NextThink(ct)
                            return true
                        end
                    end
                end
            end
        end

        if IsValid(driver) and driver:IsPlayer() then
            if self.JustEntered and ct > self.EnterTime + 0.5 then
                self.JustEntered = false
            end
            
            if not self.JustEntered and not self.EnterTime then
                self.JustEntered = true
                self.EnterTime = ct
            end

            if driver:KeyDown(IN_USE) then
                if not self.ZoomKeyPressed and not self.JustEntered then
                    self.ZoomKeyPressed = true
                    self:ToggleZoom()
                end
            else
                self.ZoomKeyPressed = false
            end

            if driver:KeyDown(IN_RELOAD) then
                if not self.EjectKeyPressed then
                    self.EjectKeyPressed = true
                    self:EjectDriver()
                end
            else
                self.EjectKeyPressed = false
            end
        else
            self.JustEntered = false
            self.EnterTime = nil
        end

        if self.Enabled then
            local phys = self:GetPhysicsObject()
            if phys:IsValid() and phys:IsAsleep() then
                phys:Wake()
                phys:ApplyForceCenter(Vector(0, 0, 10))
            end
        end
    end
    self:NextThink(CurTime())
    return true
end

function ENT:OnTakeDamage(dmg)
    if CLIENT then return end
    self.BaseClass.OnTakeDamage(self, dmg)
    if self.armor <= 0 and not self.IsDestroyed and not self.IsCrashed then
        self:StartCrashedAnimation("damage")
    end
end

function ENT:EjectDriver()
    if SERVER and IsValid(self:GetDriver()) then
        self:SetDriver(NULL)
    end
end

function ENT:CalcView(ply, pos, ang, fov)
    if self:GetDriver() == ply then
        local view = {}
        
        local targetZoom = self:GetNWInt("Mavic_ZoomLevel", 1)
        local targetFOV = 90 / (targetZoom > 0 and targetZoom or 1)
        self.SmoothFOV = Lerp(FrameTime() * 5, self.SmoothFOV or 90, targetFOV)

        local targetPitch = self:GetNWFloat("Mavic_CamPitch", 0)
        self.SmoothPitch = Lerp(FrameTime() * 8, self.SmoothPitch or 0, targetPitch)

        view.origin = self:GetPos() + self:GetForward() * 3 + self:GetUp() * 3
        
        local finalAng = self:GetAngles()
        finalAng:RotateAroundAxis(finalAng:Right(), self.SmoothPitch) 
        
        view.angles = finalAng
        view.fov = self.SmoothFOV
        view.drawviewer = false
        view.drawviewmodel = false
        view.znear = 1
        return view
    end
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:TriggerDroneExplosion()
    return
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

if SERVER then
    util.AddNetworkString("Mavic_SetCameraPitch")
    
    net.Receive("Mavic_SetCameraPitch", function(len, ply)
        local drone = net.ReadEntity()
        local pitch = net.ReadFloat()
        
        if IsValid(drone) and drone:GetDriver() == ply then
            drone:SetNWFloat("Mavic_CamPitch", pitch)
        end
    end)
end

if CLIENT then
    hook.Add("Think", "Mavic_CameraControl", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local drone = ply:GetNWEntity("kamikaze_")
        if not IsValid(drone) or drone:GetClass() ~= "dji_mavic3" or drone:GetDriver() ~= ply then return end
        
        local ct = CurTime()
        if not drone.NextPitchThink then 
            drone.NextPitchThink = ct 
        end
        
        if ct > drone.NextPitchThink then
            drone.NextPitchThink = ct + 0.05 
            
            local speed = 1.0 
            local currentPitch = drone:GetNWFloat("Mavic_CamPitch", 0)
            local changed = false
            
            if input.IsKeyDown(KEY_G) then 
                currentPitch = math.Clamp(currentPitch - speed, -90, 35) 
                changed = true 
            end
            
            if input.IsKeyDown(KEY_T) then 
                currentPitch = math.Clamp(currentPitch + speed, -90, 35) 
                changed = true 
            end
            
            if changed then
                net.Start("Mavic_SetCameraPitch")
                net.WriteEntity(drone)
                net.WriteFloat(currentPitch)
                net.SendToServer()
            end
        end
    end)
end