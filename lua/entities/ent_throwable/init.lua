AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel(self.WorldModel)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetUseType(USE_TOGGLE)
	self:DrawShadow(true)
	self:SetModelScale(self.modelscale or 1)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(2)
		phys:Wake()
		phys:EnableMotion(true)
	end
	self.created = CurTime()

	timer.Simple(0, function()
		if not IsValid(self) then return end

		self:SetModelScale(self.modelscale or 1)
	end)

	timer.Simple(0.5,function()
		if not IsValid(self) then return end
		
		self:SetOwner()
	end)
end

function ENT:Think()
	if not IsValid(self:GetPhysicsObject()) then return end
	local speed = self:GetPhysicsObject():GetVelocity():LengthSqr()
	if self.constrained then return end
	if self.AeroDrag then
		AeroDrag(self, self:GetAngles():Forward(), 10)
	end
	self:SetCollisionGroup(speed < 220000 and COLLISION_GROUP_WEAPON or COLLISION_GROUP_NONE)
end

function ENT:PhysicsCollide(data, phys)
	if data.Speed < 400 then return end
	if self.removed then return end

	if self.Bounce then
		local bounce = math.min(self.Bounce, 1)
		local newVel = data.OurOldVelocity * -bounce
		phys:SetVelocity(newVel)
	end
	local pos,_ = LocalToWorld(self.localshit,angle_zero,self:GetPos(),self:GetAngles())
	local tr = {}
	tr.start = pos
	tr.endpos = pos + data.OurOldVelocity:GetNormalized() * 32
	tr.filter = self
	--if util.TraceLine(tr).Entity != data.HitEntity and not self.dont_account_for_placement then return end
	
	self.Penetration = self.penetration or 1
	local dmginfo = DamageInfo()
	dmginfo:SetAttacker(self.owner)
	dmginfo:SetInflictor(self)
	dmginfo:SetDamage((self.damage or 20) * math.Clamp((data.Speed / self.MaxSpeed), 0, 1))
	dmginfo:SetDamageForce(data.OurOldVelocity)
	dmginfo:SetDamageType(self.DamageType or DMG_SLASH)
	dmginfo:SetDamagePosition(data.HitPos)

	-- Weapons may opt into special head-impact outcomes. These fields are only
	-- exposed during TakeDamageInfo, so a later collision rolls independently.
	local forceHeadGib = self.ForceHeadGib
	local forceHeadKnockout = self.ForceHeadKnockout
	if self.HeadImpactGibChance then
		local gibImpact = math.Rand(0, 1) < self.HeadImpactGibChance
		self.ForceHeadGib = gibImpact or nil
		self.ForceHeadKnockout = not gibImpact and self.HeadImpactKnockout or nil
	end
	data.HitEntity:TakeDamageInfo(dmginfo)
	self.ForceHeadGib = forceHeadGib
	self.ForceHeadKnockout = forceHeadKnockout

	if data.HitEntity.organism then
		self:EmitSound(self.AttackHitFlesh, 65)

		if (self.DamageType or DMG_SLASH) == DMG_CLUB then
			if data.HitEntity:IsPlayer() then
				hg.ApplyBruiseTo(data.HitEntity, data.HitEntity, data.HitPos, data.HitNormal)
			elseif data.HitEntity:GetClass() == "prop_ragdoll" then
				local ragOwner = hg.RagdollOwner(data.HitEntity)
				if IsValid(ragOwner) and ragOwner:IsPlayer() then
					hg.ApplyBruiseTo(data.HitEntity, ragOwner, data.HitPos, data.HitNormal)
				end
			end
		end
	end

	if (data.HitEntity.organism) and ((self.DamageType or DMG_SLASH) == DMG_SLASH) and !self.shouldntlodge then

		local pos, ang = self:GetPos(), self:GetAngles()

		local hitent = data.HitEntity

		local tr = {}
		tr.start = pos
		tr.endpos = pos + data.OurOldVelocity
		tr.filter = self
		local tr = util.TraceLine(tr)
		local bone = tr.PhysicsBone
		local mat = hitent:GetBoneMatrix(hitent:TranslatePhysBoneToBone(bone))

		local lpos, lang = WorldToLocal(tr.HitPos, ang, mat:GetTranslation(), mat:GetAngles())

		local org = hitent.organism
		org.LodgedEntities = org.LodgedEntities or {}
		org.LodgedEntities[#org.LodgedEntities + 1] = {
			PhysBoneID = bone,
			OffsetPos = lpos,
			OffsetAng = lang,
			model = self:GetModel(),
			takeent = self.wep,
		}

		net.Start("organism_send")

		local tbl = {}
		tbl.LodgedEntities = org.LodgedEntities
		tbl.owner = org.owner
	
		net.WriteTable(tbl)
		net.WriteBool(true)
		net.WriteBool(false)
		net.WriteBool(false)
		net.WriteBool(true)
		net.Broadcast()

		self:Remove()
		self.removed = true
	end
end

	-- Bone to organ damage mapping (shared with projectile_nonexplosive_base)
	local boneToOrgans = {
		["ValveBiped.Bip01_Head1"] = {{"brain", 0.15, 0.4}},
		["ValveBiped.Bip01_Neck1"] = {{"arteria", 0.3, 0.6}},
		["ValveBiped.Bip01_Spine4"] = {{"heart", 0.25, 0.5}, {"liver", 0.15, 0.3}},
		["ValveBiped.Bip01_Spine3"] = {{"liver", 0.2, 0.4}, {"stomach", 0.15, 0.3}},
		["ValveBiped.Bip01_Spine2"] = {{"intestines", 0.2, 0.4}},
		["ValveBiped.Bip01_Spine1"] = {{"intestines", 0.15, 0.3}},
		["ValveBiped.Bip01_L_Clavicle"] = {{"lungsL", 0.2, 0.4}},
		["ValveBiped.Bip01_R_Clavicle"] = {{"lungsR", 0.2, 0.4}},
		["ValveBiped.Bip01_L_UpperArm"] = {{"larmartery", 0.25, 0.5}},
		["ValveBiped.Bip01_R_UpperArm"] = {{"rarmartery", 0.25, 0.5}},
		["ValveBiped.Bip01_L_Forearm"] = {{"larmartery", 0.2, 0.4}},
		["ValveBiped.Bip01_R_Forearm"] = {{"rarmartery", 0.2, 0.4}},
		["ValveBiped.Bip01_L_Thigh"] = {{"llegartery", 0.25, 0.5}},
		["ValveBiped.Bip01_R_Thigh"] = {{"rlegartery", 0.25, 0.5}},
		["ValveBiped.Bip01_L_Calf"] = {{"llegartery", 0.2, 0.4}},
		["ValveBiped.Bip01_R_Calf"] = {{"rlegartery", 0.2, 0.4}},
	}

function ENT:Use(ply)
	if self.created + 0.5 > CurTime() then return end
	if self.removed then return end
	if self.wep then
		local wep = ents.Create(self.wep)
		wep:Spawn()
		wep:SetPos(self:GetPos())
		wep:SetAngles(self:GetAngles())
		wep.poisoned2 = self.poisoned2
		self:Remove()

		if constraint.FindConstraint( self, "Weld" ) then
			local tbl = constraint.FindConstraint( self, "Weld" )
			if tbl.Ent2:IsPlayer() or tbl.Ent2:IsRagdoll() then
				local dmginfo = DamageInfo()
				dmginfo:SetAttacker(self.owner)
				dmginfo:SetInflictor(self)
				dmginfo:SetDamage(self.returndamage or 10)
				dmginfo:SetDamagePosition(self:GetPos())
				dmginfo:SetDamageType(DMG_SLASH)
				self.PainMultiplier = 0.5
				tbl.Ent2:TakeDamageInfo(dmginfo)
				hg.organism.AddWoundManual(tbl.Ent2,self.returnblood or 10,vector_origin,angle_zero,tbl["Bone2"] or 0,CurTime())

				-- Check for organ damage based on bone location
				local org = tbl.Ent2.organism
				if org and boneToOrgans[tbl["Bone2"]] then
					for _, organData in ipairs(boneToOrgans[tbl["Bone2"]]) do
						local organName, minChance, maxChance = organData[1], organData[2], organData[3]
						local damageChance = math.Rand(minChance, maxChance)
						
						if math.random() < damageChance then
							if organName == "brain" then
								org.brain = math.min(org.brain + math.Rand(0.05, 0.15), 1)
							elseif organName == "heart" then
								org.heart = math.min(org.heart + math.Rand(0.1, 0.3), 1)
							elseif organName == "liver" then
								org.liver = math.min(org.liver + math.Rand(0.1, 0.25), 1)
							elseif organName == "lungsL" then
								org.lungsL[1] = math.min(org.lungsL[1] + math.Rand(0.1, 0.25), 1)
								if math.random() < 0.3 then
									org.lungsL[2] = math.min(org.lungsL[2] + math.Rand(0.1, 0.2), 1)
								end
							elseif organName == "lungsR" then
								org.lungsR[1] = math.min(org.lungsR[1] + math.Rand(0.1, 0.25), 1)
								if math.random() < 0.3 then
									org.lungsR[2] = math.min(org.lungsR[2] + math.Rand(0.1, 0.2), 1)
								end
							elseif organName == "stomach" then
								org.stomach = math.min(org.stomach + math.Rand(0.1, 0.2), 1)
							elseif organName == "intestines" then
								org.intestines = math.min(org.intestines + math.Rand(0.1, 0.2), 1)
							elseif organName == "arteria" then
								org.arteria = 1
							elseif organName == "larmartery" then
								org.larmartery = 1
							elseif organName == "rarmartery" then
								org.rarmartery = 1
							elseif organName == "llegartery" then
								org.llegartery = 1
							elseif organName == "rlegartery" then
								org.rlegartery = 1
							end
							
							-- Add additional bleeding from organ damage
							org.internalBleed = org.internalBleed + math.Rand(0.1, 0.3)
						end
					end
				end
			end
		end

		if not hook.Run("PlayerCanPickupWeapon",ply,wep) then wep.IsSpawned = true wep.init = true return end

		ply:PickupWeapon(wep)
	end
end
