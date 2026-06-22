if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_base"
SWEP.PrintName = "Tetrodotoxin syringe"
SWEP.Instructions = "Tetrodotoxin is a strong poison that was found by a japanese scientist in 1906. Death occurs from paralysis of the respiratory muscles. Can only be injected in the spinal nerves."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/upgrades/phy_optic_eotech.mdl"
SWEP.Model = "models/weapons/w_models/w_jyringe_proj.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_poisonneedle")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_poisonneedle"
	SWEP.BounceWeaponIcon = false
end

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 3
SWEP.SlotPos = 4
SWEP.WorkWithFake = false
SWEP.offsetVec = Vector(5, -1.5, -0.6)
SWEP.offsetAng = Angle(0, 0, 0)
SWEP.ModelScale = 0.5

if SERVER then
    function SWEP:OnRemove() end
end

function SWEP:DrawWorldModel()
	hg.swep.DrawBoneAttachedModel(self, {modelKey = self.Model})
end

function SWEP:SetHold(value)
	hg.swep.SetHold(self, value)
end

function SWEP:Think()
	self:SetHold(self.HoldType)
end

SWEP.traceLen = 5

function SWEP:GetEyeTrace()
	return hg.swep.GetEyeTrace(self)
end

local caninjectbone = {
    ["ValveBiped.Bip01_Spine"] = true,
    ["ValveBiped.Bip01_Spine1"] = true,
    ["ValveBiped.Bip01_Spine2"] = true,
	["ValveBiped.Bip01_Neck1"] = true,
}

function SWEP:CanInject(ent,bone) 

    local matrix = ent:GetBoneMatrix(ent:TranslatePhysBoneToBone(bone))
    local pos = matrix:GetTranslation()
    local ang = matrix:GetAngles()

    local TrueVec = ( self:GetOwner():GetPos() - ent:GetPos() ):GetNormalized()
	local LookVec = ent:GetAngles():Forward() * 1
	local DotProduct = LookVec:DotProduct( TrueVec )
	local ApproachAngle=( -math.deg( math.asin(DotProduct) )+90 )

    return ApproachAngle>=120
end

if CLIENT then
	local colred = Color(190,40,40)
	function SWEP:DrawHUD()
		if GetViewEntity() ~= LocalPlayer() then return end
		if LocalPlayer():InVehicle() then return end
        local tr = self:GetEyeTrace()
        local toScreen = tr.HitPos:ToScreen()

		local ply = tr.Entity
		if IsValid(ply) and (ply:IsPlayer() or ply:IsRagdoll()) and caninjectbone[ply:GetBoneName(ply:TranslatePhysBoneToBone(tr.PhysicsBone))] and self:CanInject(ply,tr.PhysicsBone) then
			draw.SimpleText( "Inject", "HomigradFont", toScreen.x + 3, toScreen.y + 27, color_black, TEXT_ALIGN_CENTER )
			draw.SimpleText( "Inject", "HomigradFont", toScreen.x, toScreen.y + 25, colred, TEXT_ALIGN_CENTER )
            surface.SetDrawColor(195,0,0,155)
            surface.DrawRect(toScreen.x-2.5, toScreen.y-2.5, 5, 5)
        else
            surface.SetDrawColor(255,255,255,155)
            surface.DrawRect(toScreen.x-2.5, toScreen.y-2.5, 5, 5)
        end
	end
end

function SWEP:DoPoison(ply)
    local org = ply.organism
    local Owner = self:GetOwner()

	org.poison1 = CurTime()

    Owner:EmitSound("snd_jack_hmcd_needleprick.wav",30)

    self:Remove()
	Owner:SelectWeapon("weapon_hands_sh")
end

if SERVER then
	hg.poison.Register({
		key = "poison1",
		notifyDelay = 20,
		notifyMsg = "I can't... properly breathe...",
		notifyTag = "poison1",
		killDelay = 30,
		hookSuffix = "poison1",
	})
end

function SWEP:SecondaryAttack()
end

function SWEP:Initialize()
	self:SetHold(self.HoldType)
end

function SWEP:PrimaryAttack()
	if SERVER then
        local tr = self:GetEyeTrace()
		local ply = tr.Entity
        if IsValid(ply) and (ply:IsPlayer() or ply:IsRagdoll()) and caninjectbone[ply:GetBoneName(ply:TranslatePhysBoneToBone(tr.PhysicsBone))] and self:CanInject(ply,tr.PhysicsBone) then
			self:DoPoison(ply)
        end
	end
end

function SWEP:Reload()
end