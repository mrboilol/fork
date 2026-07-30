if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_melee"
SWEP.PrintName = "empty box of tic tacs"
SWEP.Instructions = "Morty, go get their shit hurry up, I only had one of those things I threw, im holding a box of tic tacs right now."
SWEP.Category = "Weapons - Melee"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.HoldType = "melee"

SWEP.WorldModel = "models/tic tacs/winter_green.mdl"
SWEP.WorldModelReal = "models/weapons/combatknife/tactical_knife_iw7_vm.mdl"
SWEP.WorldModelExchange = SWEP.WorldModel
SWEP.DontChangeDropped = true

SWEP.weaponPos = Vector(1, -1, -2)
SWEP.weaponAng = Angle(0, 90, 90)
SWEP.HoldPos = Vector(-7, 1, -3)

if CLIENT then
	SWEP.WepSelectIcon = Material("zerlkers/keepitzen.png", "smooth")
	SWEP.IconOverride = "zerlkers/keepitzen.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.DamageType = DMG_CLUB
SWEP.DamagePrimary = 3
SWEP.DamageSecondary = 2
SWEP.PenetrationPrimary = 0.2
SWEP.PenetrationSecondary = 0.1
SWEP.PenetrationSizePrimary = 0.5
SWEP.PenetrationSizeSecondary = 0.5
SWEP.MaxPenLen = 1
SWEP.StaminaPrimary = 4
SWEP.StaminaSecondary = 3
SWEP.AttackLen1 = 28
SWEP.AttackLen2 = 24
SWEP.AttackHit = "Plastic_Box.ImpactHard"
SWEP.Attack2Hit = "Plastic_Box.ImpactHard"
SWEP.AttackHitFlesh = "Flesh.ImpactHard"
SWEP.Attack2HitFlesh = "Flesh.ImpactHard"
SWEP.DeploySnd = "Plastic_Box.ImpactSoft"

function SWEP:CustomAttack2()
	if CLIENT then return true end

	local owner = self:GetOwner()
	if not IsValid(owner) then return true end

	local thrown = ents.Create("ent_throwable")
	if not IsValid(thrown) then return true end
	thrown.WorldModel = self.WorldModelExchange
	thrown:SetPos(select(1, hg.eye(owner, 60, hg.GetCurrentCharacter(owner))) - owner:GetAimVector() * 2)
	thrown:SetAngles(owner:EyeAngles())
	thrown:SetOwner(owner)
	thrown:Spawn()
	thrown.localshit = vector_origin
	thrown.wep = self:GetClass()
	thrown.owner = owner
	thrown.damage = 18
	thrown.MaxSpeed = 750
	thrown.DamageType = DMG_CLUB
	thrown.AttackHit = "Plastic_Box.ImpactHard"
	thrown.AttackHitFlesh = "Flesh.ImpactHard"
	thrown.noStuck = true

	local phys = thrown:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(owner:GetAimVector() * thrown.MaxSpeed + owner:GetVelocity() * 0.5)
		phys:AddAngleVelocity(VectorRand() * 400)
	end

	owner:ViewPunch(Angle(0, 0, -6))
	owner:SelectWeapon("weapon_hands_sh")
	self:Remove()
	return true
end

SWEP.AttackTimeLength = 0.15
SWEP.Attack2TimeLength = 0.01
SWEP.AttackRads = 25
SWEP.AttackRads2 = 0
SWEP.SwingAng = -75
SWEP.SwingAng2 = 0
