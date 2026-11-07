include("shared.lua")
SWEP.Category = "Weapons - Other"
SWEP.PrintName = "\"Deer Hunter\" Bow"
SWEP.Instructions = "This is a modern aluminum-fiberglass compound bow with a draw force of 290 newtons, used (with broadhead arrows) to take medium-sized north-american game.\n\nRMB to aim.\nLMB while aiming to fire.\nLMB when not aiming to stab with the loaded arrow, or bash if none is loaded."
SWEP.WorldModelReal = "models/z_city/nmrih/weapons/bow/v_bow_deerhunter.mdl"
SWEP.WorldModelExchange = false
SWEP.setlh = true
SWEP.setrh = true
SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.WepSelectIcon = Material("entities/zcity/deerhunterbow.png")
SWEP.IconOverride = "entities/zcity/deerhunterbow.png"
SWEP.BounceWeaponIcon = false

SWEP.HoldPos = Vector(0,0,0)
SWEP.HoldAng = Angle(0,0,0)

--SWEP.LerpHoldPos = Vector(0,0,0)
--SWEP.LerpHoldAng = Angle(0,0,0)

function SWEP:PostSetHandPos()
    self.LerpHoldPos = self.LerpHoldPos or Vector(0,0,0)
    self.LerpHoldAng = self.LerpHoldAng or Angle(0,0,0)

    self.HoldPos = LerpVectorFT(0.03,self.HoldPos,self.LerpHoldPos)
    self.HoldAng = LerpAngleFT(0.02,self.HoldAng,self.LerpHoldAng)


    if self.AnimArHoldtypes[self.seq] then
        self.LerpHoldPos.x = self:IsLocal() and 13 or 15.5
        self.LerpHoldPos.y = 0
        self.LerpHoldAng[3] = 2
        self.HoldType = "ar2"
    else
        self.HoldType = "slam"
        self.LerpHoldPos.x = 0
        self.LerpHoldAng[3] = 0
    end
end

SWEP.AimFOV = 55
SWEP.AimSpeed = 2.2
SWEP.AimSensitivity = 0.6

function SWEP:Camera(eyePos, eyeAng, view, vellen, ply)
    view = self.BaseClass.Camera(self, eyePos, eyeAng, view, vellen, ply)

    local owner = self:GetOwner()
    local aiming = self:IsLocal() and self.AnimArHoldtypes[self.seq] and hg.GetTPIKCharacter(owner) == owner
    self.aimFraction = math.Approach(self.aimFraction or 0, aiming and 1 or 0, FrameTime() * self.AimSpeed)
    if self.aimFraction <= 0 then return view end

    local fraction = math.ease.InOutCubic(self.aimFraction)
    local sightOrigin = IsValid(self.worldModel) and self.worldModel:GetRenderOrigin()
    if sightOrigin then
        view.origin = LerpVector(fraction, view.origin, sightOrigin)
    end

    local noZoom = GetConVar("hg_nofovzoom")
    if not (noZoom and noZoom:GetBool()) then
        view.fov = Lerp(fraction, view.fov, math.min(view.fov, self.AimFOV))
    end

    return view
end

function SWEP:AdjustMouseSensitivity()
    return Lerp(math.ease.InOutCubic(self.aimFraction or 0), 1, self.AimSensitivity)
end