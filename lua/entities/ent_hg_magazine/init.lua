AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/kali/weapons/black_ops/magazines/30rd galil magazine.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:DrawShadow(true)
	self:SetUseType(USE_TOGGLE)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	
	-- Store ammo data
	self.ammoCount = self.ammoCount or 0
	self.ammoType = self.ammoType or ""
	self.weaponClass = self.weaponClass or ""
	
	-- Set bodygroup based on ammo count (empty vs partial)
	if self.ammoCount > 0 then
		self:SetBodygroup(1, 0)
	else
		self:SetBodygroup(1, 1)
	end
	
	timer.Simple(0.1, function()
		if not IsValid(self) then return end
		self:SetCollisionGroup(COLLISION_GROUP_NONE)
	end)
	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:SetMass(5)
		phys:Wake()
	end
end

function ENT:PhysicsCollide(data, physobj)
	if data.DeltaTime > .2 and data.Speed > 120 then
		sound.Play("physics/metal/weapon_impact_hard" .. math.random(3) .. ".ogg", self:LocalToWorld(self:OBBCenter()), 85)
	end
end

function ENT:Use(ply)
	if self:IsPlayerHolding() then return end
	
	-- Give ammo back to player
	if self.ammoCount > 0 and self.ammoType ~= "" then
		local currentAmmo = ply:GetAmmoCount(self.ammoType)
		ply:SetAmmo(currentAmmo + self.ammoCount, self.ammoType)
		
		-- Notify player
		if SERVER then
			ply:Notify("Picked up magazine with " .. self.ammoCount .. " rounds", 3)
		end
	else
		if SERVER then
			ply:Notify("Picked up empty magazine", 3)
		end
	end
	
	self:Remove()
end

function ENT:OnTakeDamage(dmginfo)
	self:TakePhysicsDamage(dmginfo)
end

function ENT:SetMagazineData(ammoCount, ammoType, weaponClass)
	self.ammoCount = ammoCount or 0
	self.ammoType = ammoType or ""
	self.weaponClass = weaponClass or ""
	
	if self.ammoCount > 0 then
		self:SetBodygroup(1, 0)
	else
		self:SetBodygroup(1, 1)
	end
end
