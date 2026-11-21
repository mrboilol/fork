if SERVER then AddCSLuaFile() end
ENT.Type = "anim"
ENT.Author = "Sadsalat"
ENT.Category = "ZCity Other"
ENT.PrintName = "Projectile NoneExplosive Base"
ENT.Spawnable = false
ENT.AdminOnly = true

ENT.Model = ""
ENT.HitSound = "weapons/crossbow/hit1.wav"
ENT.FleshHit = "weapons/crossbow/bolt_skewer1.wav"

ENT.Damage = 200
ENT.Force = 0.2

-- pluv

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:SetMass(1)
			phys:Wake()
		end
	end

	ENT.Hit = false

	function ENT:GetEmbedAngle(normal)
		return normal:Angle()
	end

	local function lodgeAnchorBone(ent, hitPos, physBone, hitBox, ang)
		local trusted
		if ent:GetPhysicsObjectCount() > 1 then
			trusted = ent:TranslatePhysBoneToBone(physBone or 0)
		elseif isnumber(hitBox) and (ent:IsPlayer() or ent:IsNPC()) then
			trusted = ent:GetHitBoxBone(hitBox, ent:GetHitboxSet() or 0)
		end

		local boneName = hg.organism and hg.organism.GetWoundAnchor and select(3, hg.organism.GetWoundAnchor(ent, hitPos, ang, trusted))
		local bone = boneName and ent:LookupBone(boneName) or trusted
		if not bone or bone < 0 then return ent:TranslatePhysBoneToBone(physBone or 0), physBone end

		local anchorPhysBone = ent:TranslateBoneToPhysBone(bone)
		if anchorPhysBone and anchorPhysBone >= 0 then
			return ent:TranslatePhysBoneToBone(anchorPhysBone), anchorPhysBone
		end
		return bone, physBone
	end

	function ENT:Hit(ent, hit_pos, phys_bone_id, normal, hitbox)
		local ply = hg.RagdollOwner(ent) or ent
		local rag = IsValid(ply) and (IsValid(ply:GetNWEntity("RagdollDeath", ply.FakeRagdoll)) and ply:GetNWEntity("RagdollDeath", ply.FakeRagdoll)) or ent:IsRagdoll() and ent or IsValid(ent.FakeRagdoll) and ent.FakeRagdoll
		local org = rag and rag.organism or ent.organism
		rag = rag or ent

		if !org then
			self:SetPos(hit_pos)
			self:SetAngles(self:GetEmbedAngle(normal))
			constraint.Weld(self, rag, 0, rag:IsPlayer() and 0 or phys_bone_id, 0, true, false)
		end

		local bone = ent:TranslatePhysBoneToBone(phys_bone_id)
		if org then
			bone, phys_bone_id = lodgeAnchorBone(ent, hit_pos, phys_bone_id, hitbox, normal:Angle())
		end
		local mat = bone and bone >= 0 and ent:GetBoneMatrix(bone)
		local offset_pos = Vector()
		local offset_ang = Angle()

		if(mat)then
			offset_pos, offset_ang = WorldToLocal(hit_pos, self:GetEmbedAngle(normal), mat:GetTranslation(), mat:GetAngles())
		end

		local phys = ent:GetPhysicsObjectNum(phys_bone_id or 0)
		if IsValid(phys) then
			phys:ApplyForceOffset(normal * self.Damage * 200, hit_pos)
		end

		self.HitEntity = ent
		self.phys_bone_id = phys_bone_id
		self.Hit = true

		if org then
			org.LodgedEntities = org.LodgedEntities or {}
			org.LodgedEntities[#org.LodgedEntities + 1] = {
				PhysBoneID = self.phys_bone_id,
				BoneName = bone and ent:GetBoneName(bone) or nil,
				OffsetPos = offset_pos,
				OffsetAng = offset_ang,
				CrossbowBolt = self:GetClass() == "crossbow_projectile",
				model = self:GetModel()
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
		end

		if org then
			SafeRemoveEntity(self)
		end
	end

	function ENT:PhysicsCollide(data, physobj)
		if data.DeltaTime > .2 and data.Speed > 200 and !self.Hit then
            local dir = data.HitPos - (data.HitPos + self:GetAngles():Forward() * -5)
            --print(dir:GetNormalized())
            local hitNormal = data.HitNormal
            local ApproachAngle = math.deg(math.asin(hitNormal:DotProduct(dir:GetNormalized())))
	        local MaxRicAngle = 10
            --print(ApproachAngle)

            --if ApproachAngle < MaxRicAngle * 1 then 
            --        --[[local effectpoint = self:GetPos()
            --        timer.Simple(.1,function()
            --            local effectdata = EffectData()
            --            effectdata:SetOrigin( effectpoint )
            --            effectdata:SetScale(1)
            --            effectdata:SetMagnitude(2)
            --            effectdata:SetRadius(0.1)
            --            util.Effect( "Sparks", effectdata )
            --        end)
            --        local NewVec = dir:Angle()
            --        NewVec:RotateAroundAxis(hitNormal, 180)
            --        NewVec = NewVec:Forward()
            --        self:SetVelocity(self:GetAngles():Forward() * -1000)]]--
--
            --    return 
            --end

            timer.Simple(.1,function()
                local effectdata = EffectData()
                effectdata:SetOrigin( data.HitPos )
                effectdata:SetScale(0.1)
                effectdata:SetMagnitude(2)
                effectdata:SetRadius(0.1)
                util.Effect( "Sparks", effectdata )
            end)
			local physBoneID = 0
			if IsValid(data.HitEntity) and IsValid(data.HitObject) then
				for index = 0, data.HitEntity:GetPhysicsObjectCount() - 1 do
					if data.HitEntity:GetPhysicsObjectNum(index) == data.HitObject then
						physBoneID = index
						break
					end
				end
			end
			self:Hit(data.HitEntity, data.HitPos, physBoneID, data.OurOldVelocity:GetNormalized())
            self:DamagePly(data.HitEntity, data.HitObject:GetMaterial(), data.HitPos) 
            return 
		end
	end

	function AeroDrag(ent, forward, mult, spdReq)
		if(constraint.HasConstraints(ent))then
			return
		end
		
		if ent:IsPlayerHolding() then return end
		local Phys = ent:GetPhysicsObject()
		if not IsValid(Phys) then return end
		local Vel = Phys:GetVelocity()
		local Spd = Vel:Length()
	
		if not spdReq then
			spdReq = 300
		end
	
		if Spd < spdReq then return end
		mult = mult or 1
		local Pos, Mass = Phys:LocalToWorld(Phys:GetMassCenter()), Phys:GetMass()
		Phys:ApplyForceOffset(Vel * Mass / 6 * mult, Pos + forward)
		Phys:ApplyForceOffset(-Vel * Mass / 6 * mult, Pos - forward)
		Phys:AddAngleVelocity(-Phys:GetAngleVelocity() * Mass / 1000)
	end

    local vecSmoke = Vector(255,255,255)
    function ENT:Think()
		AeroDrag(self, self:GetAngles():Forward(), .6)
        self:NextThink(CurTime() + 0.1)
    end

	function ENT:Use(ply)
	end

	function ENT:OnTakeDamage(dmginfo)
	end
    local fleshmats = {
        ["flesh"] = true,
        ["player"] = true
    }
	function ENT:DamagePly(ent,mat,hitpos)
		if self.Exploded then return end
		self.Exploded = true
		local SelfPos, Owner = self:LocalToWorld(self:OBBCenter()), self
        local DmgInfo = DamageInfo()
        DmgInfo:SetDamage(self.Damage)
        DmgInfo:SetDamageForce(self:GetAngles():Forward() * self.Force)
        DmgInfo:SetDamagePosition(hitpos)
        DmgInfo:SetDamageType(DMG_BULLET)
        DmgInfo:SetInflictor(self)
        DmgInfo:SetAttacker(self)
        ent:TakeDamageInfo(DmgInfo)
        --print(mat)
        self:EmitSound( fleshmats[mat] and self.FleshHit or self.HitSound)
        util.Decal( fleshmats[mat] and "Impact.Flesh" or "Impact.Concrete", SelfPos + self:GetAngles():Forward() * -5, SelfPos + self:GetAngles():Forward() * 500, self )
        self:Remove()
	end

	function hg.TakeArrow(ent, ply)
		return hg.TakeLodged(ent, ply)
	end

	concommand.Add("hg_takearrow", function(ply, cmd, args)
		if ply.organism and ply.organism.LodgedEntities and ply.organism.canmove then
			hg.TakeLodged(ply, ply)
		end
	end)

	hook.Add("Player Think", "takeArrowFunc", function(ply, ent)
		if ply.organism and ply.organism.canmove and ply:KeyPressed(IN_USE) then
			local tr = hg.eyeTrace(ply)

			local ent = tr.Entity

			if not IsValid(ent) then return end

			if not ent.organism then
				local owner = ent:GetNWEntity("ply")
				if IsValid(owner) and owner.organism then
					ent = owner
				else
					return
				end
			end

			hg.TakeLodged(ent, ply)
		end
	end)
	end

	if CLIENT then
	hg.lodgedmodels = hg.lodgedmodels or {}

	local lodgedFitCache = {}
	local lodgedAxes = {Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1)}

	local function lodgedModelFit(model)
		local key = model:GetModel()
		local fit = lodgedFitCache[key]
		if fit then return fit end

		local mins, maxs = model:GetModelBounds()
		local size = maxs - mins
		local order = {1, 2, 3}
		table.sort(order, function(a, b) return size[a] > size[b] end)
		local long, wide = order[1], order[2]
		local longSign = math.abs(maxs[long]) >= math.abs(mins[long]) and 1 or -1
		local wideSign = math.abs(maxs[wide]) >= math.abs(mins[wide]) and 1 or -1

		local tip = (mins + maxs) * 0.5
		tip[long] = longSign > 0 and maxs[long] or mins[long]

		local basis = (lodgedAxes[long] * longSign):AngleEx(lodgedAxes[wide] * wideSign)
		local _, inverse = WorldToLocal(vector_origin, angle_zero, vector_origin, basis)
		fit = {inverse = inverse, tip = tip}
		lodgedFitCache[key] = fit
		return fit
	end

	function hg.ProjectilesDraw(ent, ply)
		if !IsValid(arrowasdasd) then
			arrowasdasd = ClientsideModel("models/z_city/nmrih/items/arrow/ammo_arrow_single.mdl")
			arrowasdasd:SetNoDraw(true)
		end

		if ent.organism and ent.organism.LodgedEntities then
			for i, settings in ipairs(ent.organism.LodgedEntities) do				
				local arrow = hg.lodgedmodels[settings.model] or arrowasdasd
				
				if settings.model then
					if !IsValid(hg.lodgedmodels[settings.model]) then
						local model = ClientsideModel(settings.model)
						model:SetNoDraw(true)
						
						hg.lodgedmodels[settings.model] = model
					end
					
					arrow = hg.lodgedmodels[settings.model]
				end

				local bone = settings.BoneName and ent:LookupBone(settings.BoneName)
				if not bone or bone < 0 then bone = ent:TranslatePhysBoneToBone(tonumber(settings.PhysBoneID) or 0) end
				local mat = bone and bone >= 0 and ent:GetBoneMatrix(bone)
				if not mat then continue end
				local pos, ang = LocalToWorld(settings.OffsetPos, settings.OffsetAng, mat:GetTranslation(), mat:GetAngles())
				local scale = tonumber(settings.modelscale) or 1
				if arrow.hgLodgedScale ~= scale then
					arrow:SetModelScale(scale, 0)
					arrow.hgLodgedScale = scale
				end

				if settings.FitModel then
					local fit = lodgedModelFit(arrow)
					local _, modelAng = LocalToWorld(vector_origin, fit.inverse, vector_origin, ang)
					local tipOffset = LocalToWorld(fit.tip * scale, angle_zero, vector_origin, modelAng)
					local depth = tonumber(settings.LodgeDepth) or 3
					pos = pos + ang:Forward() * depth + ang:Up() * depth * 0.5 - tipOffset
					ang = modelAng
				end
	
				arrow:SetPos(pos)
				arrow:SetAngles(ang)

				arrow:SetupBones()
				arrow:DrawModel()
			end

		end
	end

	function ENT:Draw()
		self:DrawModel()
		
		if(self.PostDraw)then
			self:PostDraw()
		end
	end
end
