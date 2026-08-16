SWEP.Base = "weapon_tpik_base"
SWEP.PrintName = "Seal"
SWEP.Author = "HacPaL_B_kOlяCkY"
SWEP.Instructions = "now with TPIK"
SWEP.Spawnable = true
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_seal.mdl"
SWEP.WorldModel = "models/sealplush/sealplush.mdl"
SWEP.WorldModelReal = "models/weapons/c_seal.mdl"
SWEP.ViewModelFOV = 54
SWEP.DrawCrosshair = false
SWEP.HoldType = "duel"
SWEP.supportTPIK = true
SWEP.setrh = true
SWEP.setlh = false
SWEP.HoldPos = Vector(0, 0, 0)
SWEP.HoldAng = Angle(0, 0, 0)
SWEP.modelscale = 0.55
SWEP.modelscale2 = 0.55

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

if SERVER then
    util.AddNetworkString("SealDeploy")
    util.AddNetworkString("SealSound")
    util.AddNetworkString("SealSkin")
end

local function SetSealSkin(wep, skin)
    wep.CurrentSkin = skin
    wep.WMSkin = skin
    wep.WMSkinV = skin
    wep:SetSkin(skin)
    if CLIENT then
        local owner = wep:GetOwner()
        if IsValid(owner) then
            local vm = owner:GetViewModel()
            if IsValid(vm) then vm:SetSkin(skin) end
        end
    end
end

function SWEP:Initialize()
    if self.BaseClass.Initialize then self.BaseClass.Initialize(self) end

    self:SetHoldType(self.HoldType)
    self.CurrentSkin       = 0
    self.Sleeping          = false
    self.WasAsleepHolster  = false
    self.LastActivity      = CurTime()
    self.NextBlink         = CurTime() + 2
    self.BlinkEnd          = 0
    self.IsBlinking        = false
    self._lastHP           = -1
end

function SWEP:Deploy()
    self:SetHold(self.HoldType)
    self.LastActivity = CurTime()
    self.NextBlink    = CurTime() + 2
    self.IsBlinking   = false
    self.DeployTime   = CurTime()

    SetSealSkin(self, 2)

    if SERVER then
        net.Start("SealDeploy")
        net.WriteBool(self.WasAsleepHolster)
        net.Send(self:GetOwner())
        
        local timerName = "SealDeploySkin_" .. self:EntIndex()
        timer.Create(timerName, 2, 1, function()
            if IsValid(self) then
                if self.WasAsleepHolster then
                    self.Sleeping = true
                    SetSealSkin(self, 1)
                    net.Start("SealSkin")
                    net.WriteInt(1, 8)
                    net.Send(self:GetOwner())
                else
                    self.Sleeping = false
                    SetSealSkin(self, 0)
                    net.Start("SealSkin")
                    net.WriteInt(0, 8)
                    net.Send(self:GetOwner())
                end
            end
        end)
    end

    return true
end

function SWEP:Holster()
    timer.Remove("SealDeploySkin_" .. self:EntIndex())
    timer.Remove("SealHurt_" .. self:EntIndex())
    self.WasAsleepHolster = self.Sleeping
    return true
end

function SWEP:PrimaryAttack()
    self:SealWake()

    if SERVER then
        net.Start("SealSound")
        net.WriteString("sealplush/sealsound1.wav")
        net.Send(self:GetOwner())
    end
end

function SWEP:SecondaryAttack()
    self:SealWake()

    if SERVER then
        net.Start("SealSound")
        net.WriteString("sealplush/soundseal1.wav")
        net.Send(self:GetOwner())
    end
end

function SWEP:Think()
    local now   = CurTime()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:SetHold(self.HoldType)

    if SERVER then
        local hp = owner:Health()
        if self._lastHP == -1 then self._lastHP = hp end

        if hp < self._lastHP and self._lastHP > 0 then
            self:SealWake()

            SetSealSkin(self, 3)
            net.Start("SealSkin")
            net.WriteInt(3, 8)
            net.Send(owner)

            timer.Create("SealHurt_" .. self:EntIndex(), 1, 1, function()
                if IsValid(self) and IsValid(owner) then
                    local s = self.Sleeping and 1 or 0
                    SetSealSkin(self, s)
                    net.Start("SealSkin")
                    net.WriteInt(s, 8)
                    net.Send(owner)
                end
            end)
        end
        self._lastHP = hp

        if not self.Sleeping and (now - self.LastActivity) >= 25 and self.CurrentSkin == 0 then
            self.Sleeping = true
            SetSealSkin(self, 1)
            net.Start("SealSkin")
            net.WriteInt(1, 8)
            net.Send(owner)
        end
    end

    if CLIENT then
        if not IsValid(owner) or owner ~= LocalPlayer() then return end

        if not self.Sleeping and self.CurrentSkin == 0 then
            if self.IsBlinking then
                if now >= self.BlinkEnd then
                    self.IsBlinking = false
                    SetSealSkin(self, 0)
                    self.NextBlink = now + math.Rand(2, 5)
                end
            else
                if now >= self.NextBlink then
                    self.IsBlinking = true
                    self.BlinkEnd   = now + 0.15
                    SetSealSkin(self, 1)
                end
            end
        end
    end
end

function SWEP:SealWake()
    timer.Remove("SealDeploySkin_" .. self:EntIndex())
    self.Sleeping         = false
    self.WasAsleepHolster = false
    self.LastActivity     = CurTime()
    self.IsBlinking       = false
    self.NextBlink        = CurTime() + 2
    
    SetSealSkin(self, 0)
    if SERVER then
        net.Start("SealSkin")
        net.WriteInt(0, 8)
        net.Send(self:GetOwner())
    end
end

if CLIENT then
    function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
        local deployTime = self.DeployTime or 0
        local delta = CurTime() - deployTime
        
        if delta < 0.5 then
            local progress = delta / 0.5
            progress = math.ease.OutQuad(progress)
            
            local offset = Lerp(progress, -15, 0)
            pos = pos + ang:Up() * offset
        end
        
        return pos, ang
    end

    net.Receive("SealDeploy", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then return end

        surface.PlaySound("sealplush/ohmygah.wav")
        wep.DeployTime = CurTime()
        SetSealSkin(wep, 2)
    end)

    net.Receive("SealSound", function()
        local snd = net.ReadString()
        surface.PlaySound(snd)
    end)

    net.Receive("SealSkin", function()
        local skin = net.ReadInt(8)
        local ply  = LocalPlayer()
        local wep  = ply:GetActiveWeapon()
        if not IsValid(wep) then return end
        SetSealSkin(wep, skin)
    end)
end
