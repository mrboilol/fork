if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_zerlkers"
SWEP.PrintName = "empty box of tic tacs"
SWEP.Instructions = "Morty, go get their shit hurry up, I only had one of those things I threw, im holding a box of tic tacs right now."
SWEP.Category = "Weapons - Melee"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.HoldType = "slam"
SWEP.Primary.Wait = 0.5
SWEP.Primary.Next = 0

SWEP.WorldModel = "models/tic tacs/winter_green.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("zerlkers/keepitzen.png", "smooth")
	SWEP.IconOverride = "zerlkers/keepitzen.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.DamageType = DMG_CLUB
SWEP.DeploySnd = "Plastic_Box.ImpactSoft"
SWEP.showstats = false

function SWEP:ThrowBox()
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
	thrown.damage = 250
	thrown.MaxSpeed = 1000
	thrown.DamageType = DMG_CLUB
	thrown.AttackHit = "Plastic_Box.ImpactHard"
	thrown.AttackHitFlesh = "Flesh.ImpactHard"
	thrown.noStuck = true

	local phys = thrown:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(owner:GetAimVector() * thrown.MaxSpeed + owner:GetVelocity() * 0.5)
		phys:AddAngleVelocity(VectorRand() * 350)
	end

	owner:ViewPunch(Angle(0, 0, -6))
	owner:SelectWeapon("weapon_hands_sh")
	self:Remove()
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
