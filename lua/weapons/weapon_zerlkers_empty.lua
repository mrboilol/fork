if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_zerlkers"
SWEP.PrintName = "empty box of tic tacs"
SWEP.Instructions = "Morty, go get their shit hurry up, I only had one of those things I threw, im holding a box of tic tacs right now."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.HoldType = "grenade"
SWEP.Primary.Wait = 0.75
SWEP.Primary.Next = 0
SWEP.ThrowDelay = 0.25
SWEP.ThrowVelocity = 1600
SWEP.ThrowDamage = 325

SWEP.WorldModel = "models/tic tacs/winter_green.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("zerlkers/keepitzen.png", "smooth")
	SWEP.IconOverride = "zerlkers/keepitzen.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.DamageType = DMG_CLUB
SWEP.DeploySnd = "Plastic_Box.ImpactSoft"
SWEP.showstats = false

function SWEP:FinishThrow()
	if CLIENT then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local thrown = ents.Create("ent_throwable")
	if not IsValid(thrown) then return end
	thrown.WorldModel = self.WorldModel
	thrown:SetPos(select(1, hg.eye(owner, 60, hg.GetCurrentCharacter(owner))) - owner:GetAimVector() * 2)
	thrown:SetAngles(owner:EyeAngles())
	thrown:SetOwner(owner)
	thrown:Spawn()
	thrown.localshit = vector_origin
	thrown.wep = self:GetClass()
	thrown.owner = owner
	thrown.damage = self.ThrowDamage
	thrown.MaxSpeed = self.ThrowVelocity
	thrown.DamageType = DMG_CLUB
	thrown.AttackHit = "Plastic_Box.ImpactHard"
	thrown.AttackHitFlesh = "Flesh.ImpactHard"
	thrown.noStuck = true

	local phys = thrown:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(owner:GetAimVector() * self.ThrowVelocity + owner:GetVelocity() * 0.5)
		phys:AddAngleVelocity(VectorRand() * 350)
	end

	owner:ViewPunch(Angle(0, 0, -6))
	owner:SelectWeapon("weapon_hands_sh")
	self:Remove()
end

function SWEP:ThrowBox()
	if CLIENT or self.Throwing then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self.Throwing = true
	owner:AnimRestartGesture(GESTURE_SLOT_GRENADE, ACT_HL2MP_GESTURE_RANGE_ATTACK_GRENADE, true)

	timer.Simple(self.ThrowDelay, function()
		if not IsValid(self) then return end
		self:FinishThrow()
	end)
end

function SWEP:PrimaryAttack()
	if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
	if self.Primary.Next > CurTime() then return end

	self.Primary.Next = CurTime() + self.Primary.Wait
	self:SetNextPrimaryFire(self.Primary.Next)
	self:ThrowBox()
end

function SWEP:SecondaryAttack()
	self:PrimaryAttack()
end
