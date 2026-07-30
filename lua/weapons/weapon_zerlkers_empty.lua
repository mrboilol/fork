if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_hg_grenade_tpik"
SWEP.PrintName = "empty box of tic tacs"
SWEP.Instructions = [[LMB - high throw
RMB - low throw]]
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.HoldType = "camera"
SWEP.ViewModel = ""
SWEP.WorkWithFake = true

SWEP.Primary.Wait = 2
SWEP.Primary.Next = 0
SWEP.ThrowVelocity = 800
SWEP.LowThrowVelocity = 400
SWEP.ThrowDamage = 325

SWEP.WorldModel = "models/tic tacs/winter_green.mdl"
SWEP.WorldModelReal = "models/weapons/zcity/c_molotov.mdl"
SWEP.WorldModelExchange = "models/tic tacs/winter_green.mdl"
SWEP.basebone = 57
SWEP.weaponPos = Vector(0.4, -0.2, -1.5)
SWEP.weaponAng = Angle(0, 140, 0)
SWEP.modelscale = 1

SWEP.HideMeshBones = {
	"Weapon",
	"Liq_base",
	"Fire_Rag",
	"Spoon",
	"Liq_top",
	"Bone01",
	"Bone02",
	"Bone03",
	"Bone04",
	"Bone05",
	"Rag_God"
}
SWEP.HideMeshOnlyScale = {Weapon = true}

SWEP.NoSpoon = true
SWEP.NoTrap = true
SWEP.spoon = false
SWEP.throwsound = "weapons/m67/m67_throw_01.wav"
SWEP.DeploySnd = "Plastic_Box.ImpactSoft"
SWEP.showstats = false

if CLIENT then
	SWEP.WepSelectIcon = Material("zerlkers/keepitzen.png", "smooth")
	SWEP.IconOverride = "zerlkers/keepitzen.png"
	SWEP.BounceWeaponIcon = false
end

local function finishThrow(self, velocity, positionOffset, angleOffset)
	if CLIENT then return end

	self:Throw(velocity, CurTime(), nil, positionOffset, angleOffset)
	self.InThrowing = false
	self.ReadyToThrow = false
	self.IsLowThrow = false
	self.SpoonTime = false
	self.Spoon = true

	timer.Simple(0.6, function()
		if not IsValid(self) then return end

		local owner = self:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then
			owner:SelectWeapon("weapon_hands_sh")
		end
		self:Remove()
	end)
end

SWEP.AnimList = {
	["deploy"] = {"base_draw", 1, false},
	["attack"] = {"throw", 0.8, false, false, function(self)
		finishThrow(self, self.ThrowVelocity, Vector(2, 4, 0), Angle(-40, 0, 0))
	end, 0.65},
	["attack2"] = {"lowthrow", 0.8, false, false, function(self)
		finishThrow(self, self.LowThrowVelocity, Vector(0, 4, -6), Angle(40, 0, 0))
	end, 0.6},
	["pullbackhigh"] = {"pullback_high", 1.5, false, false, function(self)
		self.ReadyToThrow = true
	end, 0.8},
	["pullbacklow"] = {"pullback_low", 1.5, false, false, function(self)
		self.IsLowThrow = true
		self.ReadyToThrow = true
	end, 0.8},
	["revers_pullbackhigh"] = {"pullback_high", 1.5, false, true},
	["revers_pullbacklow"] = {"pullback_low", 1.5, false, true},
	["idle"] = {"draw", 1, false}
}

function SWEP:Throw(velocity, _, nosound, throwPosAdjust, throwAngAdjust)
	if CLIENT then return end

	local owner = self.Thrower or self:GetOwner()
	if not IsValid(owner) then return end

	local character = hg.GetCurrentCharacter(owner)
	if not IsValid(character) then character = owner end

	throwPosAdjust = throwPosAdjust or vector_origin
	throwAngAdjust = throwAngAdjust or angle_zero

	local _, _, headMatrix = self:GetEyeTrace()
	local eyePos = headMatrix and headMatrix:GetTranslation() or owner:EyePos()
	local eyeAng = owner:EyeAngles()
	local spawnPos = eyePos
		+ eyeAng:Forward() * throwPosAdjust[1]
		+ eyeAng:Right() * (throwPosAdjust[2] + 2)
		+ eyeAng:Up() * throwPosAdjust[3]

	local thrown = ents.Create("ent_throwable")
	if not IsValid(thrown) then return end

	thrown.WorldModel = self.WorldModel
	thrown:SetPos(spawnPos)
	thrown:SetOwner(character)
	thrown:Spawn()
	thrown:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	local throwAng = owner:EyeAngles()
	throwAng:RotateAroundAxis(throwAng:Forward(), throwAngAdjust[1])
	throwAng:RotateAroundAxis(throwAng:Right(), throwAngAdjust[2])
	throwAng:RotateAroundAxis(throwAng:Up(), throwAngAdjust[3])
	thrown:SetAngles(throwAng)

	thrown.localshit = vector_origin
	thrown.wep = self:GetClass()
	thrown.owner = owner
	thrown.damage = self.ThrowDamage
	thrown.MaxSpeed = velocity > 0 and velocity or self.ThrowVelocity
	thrown.DamageType = DMG_GENERIC
	thrown.PainMultiplier = 0
	thrown.ShockMultiplier = 0
	thrown.BleedMultiplier = 0
	thrown.ImmobilizationMul = 0
	thrown.HurtMultiplier = 0
	thrown.AttackHit = "Metal_Barrel.ImpactHard"
	thrown.AttackHitFlesh = "Flesh.ImpactHard"
	thrown.noStuck = true

	local phys = thrown:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMaterial("metal_barrel")
		phys:SetVelocity(owner:GetAimVector() * velocity + character:GetVelocity())
		phys:AddAngleVelocity(VectorRand() * 350)
	end

	if not nosound then
		character:EmitSound(self.throwsound, 75, math.random(95, 105))
	end
	owner:ViewPunch(Angle(3, 0, 0))
	owner:AnimRestartGesture(GESTURE_SLOT_GRENADE, ACT_HL2MP_GESTURE_RANGE_ATTACK_GRENADE, true)

	timer.Simple(0.15, function()
		if IsValid(thrown) then
			thrown:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
		end
	end)

	if owner:IsOnGround() then
		owner:SetVelocity(owner:GetVelocity() * -0.5)
	end

	self.Thrower = nil
end

function SWEP:ThinkAdd()
	if CLIENT or not self.ReadyToThrow or self.InThrowing then return end

	local released = self.IsLowThrow and not self:KeyDown(IN_ATTACK2)
		or not self.IsLowThrow and not self:KeyDown(IN_ATTACK)
	if not released or (self.wait or 0) > CurTime() then return end

	self.wait = CurTime() + 1
	self:PlayAnim(self.IsLowThrow and "attack2" or "attack")
	self.InThrowing = true
	self:SetShowGrenade(false)
end
