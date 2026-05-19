AddCSLuaFile()
if SERVER then
	AddCSLuaFile("effects/eff_zcity_turret_smoke.lua")
end

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "ZCity Turret"
ENT.Category = "ZCity"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Model = "models/combine_turrets/floor_turret.mdl"

ENT.TriggerDistance = 1200
ENT.TriggerDot = 0.985
ENT.TriggerCooldown = 10.0
ENT.ActivationDelay = 1.0
ENT.StartupDelay = 8

ENT.ActivationSound = "zcity_delta/turret-activation.mp3"
ENT.ShotSound = "zcity_delta/turret-shot.mp3"

ENT.BulletDamage = 48
ENT.BulletForce = 30
ENT.BulletAmmoType = "AR2"

ENT.MuzzleForwardOffset = 10
ENT.MuzzleUpOffset = 22

ENT.DetectConeAngleDeg = 10
ENT.AimConeAngleDeg = 60

function ENT:Initialize()
	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	self.NextTriggerTime = CurTime() + (self.StartupDelay or 8)
	self.ArmedUntil = nil
	self.NextFireTime = nil
	self.PendingTarget = nil

	if SERVER then
		util.PrecacheSound(self.ActivationSound)
		util.PrecacheSound(self.ShotSound)
	end
end

function ENT:GetBaseDirection()
	local attachmentNames = {"eyes", "muzzle", "light"}
	for _, name in ipairs(attachmentNames) do
		local attachment = self:LookupAttachment(name)
		if attachment and attachment > 0 then
			local data = self:GetAttachment(attachment)
			if data and data.Ang then
				return data.Ang:Forward()
			end
		end
	end

	return self:GetForward()
end

function ENT:GetMuzzlePos()
	local attachmentNames = {"muzzle", "eyes", "light"}
	for _, name in ipairs(attachmentNames) do
		local attachment = self:LookupAttachment(name)
		if attachment and attachment > 0 then
			local data = self:GetAttachment(attachment)
			if data and data.Pos then
				return data.Pos
			end
		end
	end

	local baseDir = self:GetBaseDirection()
	local up = self:GetUp()
	return self:GetPos() + baseDir * (self.MuzzleForwardOffset or 10) + up * (self.MuzzleUpOffset or 22)
end

function ENT:Think()
	if CLIENT then return end

	local now = CurTime()
	if (self.NextTriggerTime or 0) > now then
		self:NextThink(now + 0.1)
		return true
	end

	local fireTime = self.NextFireTime
	if fireTime and fireTime <= now then
		self.NextFireTime = nil
		self:FireOnce(self.PendingTarget)
		self.PendingTarget = nil
		self.NextTriggerTime = now + (self.TriggerCooldown or 3)
		self:NextThink(now + 0.1)
		return true
	end

	if not fireTime then
		local target = self:FindTriggerEntity()
		if IsValid(target) then
			self.PendingTarget = target
			self:EmitSound(self.ActivationSound, 70, 100, 1)
			self.NextFireTime = now + (self.ActivationDelay or 1)
			self.NextTriggerTime = now + (self.ActivationDelay or 1)
		end
	end

	self:NextThink(now + 0.1)
	return true
end

function ENT:IsEntityMoving(ent)
	if not IsValid(ent) then return false end

	local vel = vector_origin
	if ent:IsPlayer() or ent:IsNPC() then
		vel = ent:GetVelocity()
	else
		local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil
		if IsValid(phys) then
			vel = phys:GetVelocity()
		else
			vel = ent.GetVelocity and ent:GetVelocity() or vector_origin
		end
	end

	return vel:LengthSqr() >= (40 * 40)
end

function ENT:GetEntityAimPos(ent)
	if not IsValid(ent) then return self:GetPos() end
	if ent.WorldSpaceCenter then return ent:WorldSpaceCenter() end
	return ent:GetPos() + ent:OBBCenter()
end

function ENT:FindTriggerEntity()
	local origin = self:GetMuzzlePos()
	local baseDir = self:GetBaseDirection()
	local maxDist = self.TriggerDistance or 400
	local maxDistSqr = maxDist * maxDist
	local minDot = self.TriggerDot or 0.75
	if self.DetectConeAngleDeg ~= nil then
		local ang = math.Clamp(tonumber(self.DetectConeAngleDeg) or 0, 0, 179)
		minDot = math.cos(math.rad(ang))
	end

	local bestEnt
	local bestDot = minDot
	local bestDistSqr = maxDistSqr

	for _, ent in ipairs(ents.FindInSphere(origin, maxDist)) do
		if not IsValid(ent) then continue end
		if ent == self then continue end
		if ent:IsWorld() then continue end
		if ent:GetSolid() == SOLID_NONE then continue end
		if ent:IsPlayer() and not ent:Alive() then continue end

		if not self:IsEntityMoving(ent) then continue end

		local targetPos = self:GetEntityAimPos(ent)
		local toTarget = targetPos - origin
		local distSqr = toTarget:LengthSqr()
		if distSqr > maxDistSqr then continue end

		local dir = toTarget:GetNormalized()
		local dot = baseDir:Dot(dir)
		if dot < minDot then continue end

		local tr = util.TraceLine({
			start = origin,
			endpos = targetPos,
			mask = MASK_SHOT,
			filter = {self}
		})

		if tr.Hit and tr.Entity ~= ent then continue end

		if dot > bestDot or (dot == bestDot and distSqr < bestDistSqr) then
			bestEnt = ent
			bestDot = dot
			bestDistSqr = distSqr
		end
	end

	return bestEnt
end

function ENT:FireOnce(target)
	if CLIENT then return end

	self:EmitSound(self.ShotSound, 85, 100, 1)

	local baseDir = self:GetBaseDirection()
	local src = self:GetMuzzlePos()

	local aimDir = baseDir
	if IsValid(target) then
		if target:IsPlayer() and not target:Alive() then
			target = nil
		end
	end

	if IsValid(target) then
		local desiredDir = (self:GetEntityAimPos(target) - src):GetNormalized()
		local baseAng = baseDir:Angle()
		local desiredAng = desiredDir:Angle()
		local delta = desiredAng - baseAng
		delta.p = math.NormalizeAngle(delta.p)
		delta.y = math.NormalizeAngle(delta.y)

		local maxAng = self.AimConeAngleDeg or 35
		delta.p = math.Clamp(delta.p, -maxAng, maxAng)
		delta.y = math.Clamp(delta.y, -maxAng, maxAng)
		delta.r = 0

		aimDir = (baseAng + delta):Forward()
	end

	local dust = EffectData()
	local downStart = self:GetPos() + self:GetUp() * 8
	local tr = util.TraceLine({
		start = downStart,
		endpos = downStart - self:GetUp() * 200,
		mask = MASK_SOLID,
		filter = {self}
	})

	local dustPos = tr.HitPos
	local dustNormal = tr.HitNormal
	if not tr.Hit then
		dustPos = self:GetPos()
		dustNormal = Vector(0, 0, 1)
	end

	dustPos = dustPos + dustNormal * 2
	dust:SetOrigin(dustPos)
	dust:SetStart(dustPos)
	dust:SetNormal(dustNormal)
	dust:SetScale(4)
	util.Effect("eff_zcity_turret_smoke", dust, true, true)

	local bullet = {}
	bullet.Num = 1
	bullet.Src = src
	bullet.Dir = aimDir
	bullet.Spread = vector_origin
	bullet.Tracer = 1
	bullet.TracerName = "Tracer"
	bullet.Force = self.BulletForce or 14
	bullet.Damage = self.BulletDamage or 38
	bullet.AmmoType = self.BulletAmmoType or "AR2"
	bullet.Attacker = self
	bullet.IgnoreEntity = self

	self:FireBullets(bullet)
end
