AddCSLuaFile()

if SERVER and util.NetworkStringToID("zcity_delta_sonar_hit") == 0 then
	util.AddNetworkString("zcity_delta_sonar_hit")
end

if SERVER and util.NetworkStringToID("send_tinnitus") == 0 then
	util.AddNetworkString("send_tinnitus")
end

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "ZCity Sonar Turret"
ENT.Category = "ZCity"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Model = "models/props_combine/combine_light001a.mdl"
ENT.TriggerDistance = 800
ENT.TriggerCooldown = 120
ENT.StartupDelay = 10
ENT.ActivationDelay = 3
ENT.ActivationSound = "zcity_delta/turret-activation.mp3"
ENT.BrainDamage = 0.15
ENT.SkullDamage = 0.15
ENT.Disorientation = 24
ENT.Shock = 20
ENT.TinnitusSeconds = 180
ENT.HeadWoundDamage = 28

function ENT:Initialize()
	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	self.NextTriggerTime = CurTime() + (self.StartupDelay or 10)
	self.NextFireTime = nil
	self.PendingVictims = nil

	if SERVER then
		util.PrecacheSound(self.ActivationSound)
	end
end

function ENT:GetTargetCharacter(ply)
	if not IsValid(ply) then return nil end
	if hg and hg.GetCurrentCharacter then
		return hg.GetCurrentCharacter(ply) or ply
	end
	return ply
end

function ENT:GetPlayersInRange()
	local victims = {}
	local radiusSqr = (self.TriggerDistance or 800) * (self.TriggerDistance or 800)
	local origin = self:GetPos()

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		local ent = self:GetTargetCharacter(ply)
		if not IsValid(ent) then continue end
		if origin:DistToSqr(ent:GetPos()) > radiusSqr then continue end
		table.insert(victims, ply)
	end

	return victims
end

function ENT:ApplyEffectsToPlayer(ply)
	if not IsValid(ply) or not ply:Alive() then return end

	local target = self:GetTargetCharacter(ply)
	if not IsValid(target) or not target.organism then return end
	local org = target.organism

	org.disorientation = math.max(org.disorientation or 0, self.Disorientation or 24)
	org.shock = math.max(org.shock or 0, self.Shock or 20)
	org.brain = math.max(org.brain or 0, self.BrainDamage or 0.15)
	org.skull = math.max(org.skull or 0, self.SkullDamage or 0.15)

	if hg and hg.organism and hg.organism.AddWoundManual then
		local headBone = "ValveBiped.Bip01_Head1"
		for _ = 1, 3 do
			hg.organism.AddWoundManual(target, self.HeadWoundDamage or 28, vector_origin, angle_zero, headBone, CurTime())
		end
	end

	ply:SetNetVar("wounds", org.wounds or {})
	ply:SetNetVar("arterialwounds", org.arterialwounds or {})

	net.Start("send_tinnitus")
		net.WriteFloat(self.TinnitusSeconds or 180)
		net.WriteBool(true)
	net.Send(ply)

	net.Start("zcity_delta_sonar_hit")
	net.Send(ply)

	if hg and hg.LightStunPlayer then
		hg.LightStunPlayer(ply, 2)
	end
end

function ENT:Think()
	if CLIENT then return end

	local now = CurTime()
	if (self.NextTriggerTime or 0) > now then
		self:NextThink(now + 0.25)
		return true
	end

	local fireTime = self.NextFireTime
	if fireTime and fireTime <= now then
		local victims = self.PendingVictims or {}
		self.NextFireTime = nil
		self.PendingVictims = nil

		for _, ply in ipairs(victims) do
			self:ApplyEffectsToPlayer(ply)
		end

		self.NextTriggerTime = now + (self.TriggerCooldown or 120)
		self:NextThink(now + 0.25)
		return true
	end

	local victims = self:GetPlayersInRange()
	if #victims > 0 and not fireTime then
		self.PendingVictims = victims
		self.NextFireTime = now + (self.ActivationDelay or 3)
		self.NextTriggerTime = self.NextFireTime
		self:EmitSound(self.ActivationSound, 70, 100, 1)
	end

	self:NextThink(now + 0.25)
	return true
end
