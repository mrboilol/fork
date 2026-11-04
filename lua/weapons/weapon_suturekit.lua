if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.BandageTPIK = false
SWEP.PrintName = "Suture Kit"
SWEP.Instructions = "A needle, thread and hemostat for closing bleeding wounds and arteries. Closing an artery lets you take the tourniquet off that limb. LMB to suture yourself, RMB to suture someone else, R during suturing to switch wounds."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/w_models/weapons/w_eq_medkit.mdl"
SWEP.Color = Color(150, 170, 210)

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_medkit")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_medkit.vmt"
	SWEP.BounceWeaponIcon = false
end

SWEP.Slot = 3
SWEP.SlotPos = 2
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -0.5, -2)
SWEP.offsetAng = Angle(-30, 20, 90)

SWEP.mode = 1
SWEP.modes = 1
SWEP.modeNames = {
	[1] = "suture",
}

SWEP.modeValuesdef = {
	[1] = {6, false},
}

SWEP.ShouldDeleteOnFullUse = true

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)
	self.ModelScale = 0.55
end

function SWEP:Think()
	self:SetHold(self.HoldType)
end

function SWEP:CanBandageTPIK()
	return false
end

local function ResolveSutureTarget(owner)
	local ent = hg.eyeTrace(owner).Entity
	if IsValid(ent) and ent:IsRagdoll() and hg.RagdollOwner then
		ent = hg.RagdollOwner(ent) or ent
	end
	return IsValid(ent) and ent.organism and ent or nil
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.5)
	if not SERVER then return end
	local owner = self:GetOwner()
	if IsValid(owner) then hg.Suture.Start(owner, self, owner, 1) end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.5)
	if not SERVER then return end
	local owner = self:GetOwner()
	if not IsValid(owner) or IsValid(self:GetNWEntity("fakeGun")) then return end

	local target = ResolveSutureTarget(owner)
	if not target or hg.GetCurrentCharacter(target) == hg.GetCurrentCharacter(owner) then return end
	hg.Suture.Start(owner, self, target, 1)
end

function SWEP:Reload()
end

if SERVER then
	function SWEP:Heal(ent, mode)
		local owner = self:GetOwner()
		if not IsValid(owner) or not owner:IsPlayer() then return end
		return hg.Suture.Start(owner, self, ent, 1)
	end

	function SWEP:OnSutureUsed()
		if self.modeValues[1] > 0 then return end
		local owner = self:GetOwner()
		if IsValid(owner) then owner:SelectWeapon("weapon_hands_sh") end
		self:Remove()
	end
end
