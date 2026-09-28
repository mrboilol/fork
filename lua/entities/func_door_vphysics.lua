AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     = ""
ENT.PrintName    = ""
ENT.Author       = "Meetric"
ENT.Purpose      = ""
ENT.Instructions = ""

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "ClientRotation")
end

function ENT:Initialize()
	self:SetMoveType(MOVETYPE_PUSH)
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInitShadow(false, false)
	self:AddFlags(FL_UNBLOCKABLE_BY_PLAYER)
	self:SetMaterial("models/props_combine/stasisfield_beam")
	self:SetCustomCollisionCheck(true)
	self:EnableCustomCollisions(true)
	self:SetNoDraw(true)

	-- collide only with players
	hook.Add("ShouldCollide", "func_door_vphysics_TFCOLLISION_GROUP_RESPAWNROOMS", function(e0, e1)
		if e0:GetClass() == "func_door_vphysics" and !e1:IsPlayer() then return false end
		if e1:GetClass() == "func_door_vphysics" and !e0:IsPlayer() then return false end
	end)

	duplicator.Disallow("func_door_vphysics")	-- doesnt seem to do anything outside of this function
end

-- no interaction with traces, only player collision
function ENT:TestCollision(_, _, _, _, mask)
	return bit.band(mask, CONTENTS_PLAYERCLIP) != 0 and bit.band(mask, CONTENTS_DEBRIS) == 0
end

if SERVER then
	-- InfMap support
	if InfMap then
		hook.Add("PropUpdateChunk", "func_door_vphysics", function(ent, new_chunk)
			if !ent.DOOR_TOUCHING then return end

			for e, time in pairs(ent.DOOR_TOUCHING) do
				if !e:IsValid() or CurTime() > time then
					ent.DOOR_TOUCHING[e] = nil
					continue
				end

				e:SetGroundEntity(ent)
				if e.CHUNK_OFFSET == new_chunk then
					continue
				end

				e.CONSTRAINED_MAIN = false
				e:InfMap_SetPos(e:InfMap_GetPos() + InfMap.unlocalize_vector(Vector(), e.CHUNK_OFFSET - new_chunk))
				InfMap.prop_update_chunk(e, new_chunk)
			end
		end)

		function ENT:Touch(ent)
			if !ent:IsPlayer() then return end
			
			self.DOOR_TOUCHING = self.DOOR_TOUCHING or {}
			self.DOOR_TOUCHING[ent] = CurTime() + FrameTime() * 2
		end
	end

	local function angle_difference(a, b)
		return Angle(
			math.AngleDifference(a[1], b[1]), 
			math.AngleDifference(a[2], b[2]), 
			math.AngleDifference(a[3], b[3])
		)
	end

	function ENT:Think()
		-- reset collision group if EnableCollisions is used (cmenu)
		if self.DOOR_PARENT:GetCollisionGroup() == COLLISION_GROUP_NONE then
			self.DOOR_PARENT:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		end

		-- stop if collision group is modified by player
		local not_solid = self.DOOR_PARENT:GetCollisionGroup() != COLLISION_GROUP_PASSABLE_DOOR
		self:SetNotSolid(not_solid)

		if not_solid then 
			self:SetPos(self.DOOR_PARENT:GetPos())
			self:SetAngles(self.DOOR_PARENT:GetAngles())
		else
			local delta_ang = angle_difference(self.DOOR_PARENT:GetAngles(), self:GetAngles()) / FrameTime() / 2	-- divide by 2 to smooth angular momentum
			local delta_pos = (self.DOOR_PARENT:GetPos() - self:GetPos()) / FrameTime()
			--local delta_pos =  (Vector(500 * math.sin(CurTime() * 10), 0, 0) - self:GetPos())

			self:SetSaveValue("m_flMoveDoneTime", math.huge)	-- force CBaseDoor object to simulate physics
			self:SetLocalAngularVelocity(delta_ang)
			self:SetLocalVelocity(delta_pos)
			self:SetAbsVelocity(delta_pos)	-- fixes if goes too fast
		end

		self:NextThink(CurTime())
		return true
	end

	function ENT:OnDuplicated()
		self:Remove()
	end
end

if CLIENT then
	-- undo yaw rotation caused internally from MOVETYPE_PUSH
	function ENT:PhysicsUpdate()
		local lp = LocalPlayer()
		if self:GetClientRotation() then return end
		
		if !IsValid(lp) or lp:GetGroundEntity() != self then
			self.DOOR_PREVANG = nil
			return
		end

		if self.DOOR_PREVANG then
			local delta_y = Angle(0, math.AngleDifference(self.DOOR_PREVANG.y, self:GetAngles().y), 0)
			lp:SetEyeAngles(lp:EyeAngles() + delta_y)
		end
		self.DOOR_PREVANG = self:GetAngles()
	end
end