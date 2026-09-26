--[[
	Pat's Bear Trap bridge.

	The trap already snaps on NPCs, but only with TakeDamageInfo
	(pat_beartrap_npc_damage). Players get hg.organism.AmputateLimb + a short
	stun. Downed ZCNPC bodies are not victims at all: resolveVictim only knows
	player FakeRagdolls.

	We do not edit that addon. When it is present, TriggerVictim / Touch / Think
	are wrapped so organism NPCs (standing or lying) take the player amputation
	path, then Floor / ExtendDown for the stun.

	Stock trap fires on any NPC hull Touch with no foot-radius gate. Our first
	bridge reused the player leg check for everyone, so a standing NPC that
	clipped the trap often got slash damage and no amputation.
]]

local LEG_BONES = {
	lleg = { "ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_L_Calf" },
	rleg = { "ValveBiped.Bip01_R_Foot", "ValveBiped.Bip01_R_Calf" },
}

local function Present()
	return istable(PAT_BEARTRAP) and scripted_ents.GetStored("ent_pat_beartrap") ~= nil
end

function ZCNPC.BearTrapPresent()
	return Present()
end

local function BonePos(ent, boneName)
	if not (IsValid(ent) and boneName) then return end

	local bone = ent:LookupBone(boneName)
	if not bone then return end

	local pos = select(1, ent:GetBonePosition(bone))
	if isvector(pos) and not pos:IsZero() then return pos end

	local matrix = ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end
end

local function Character(ent)
	if istable(PAT_BEARTRAP) and isfunction(PAT_BEARTRAP.GetCharacterEntity) then
		local char = PAT_BEARTRAP.GetCharacterEntity(ent)
		if IsValid(char) then return char end
	end

	return ent
end

-- body = entity carrying the organism, standing = NPC to Floor (may equal body).
local function OrganismVictim(ent)
	if not IsValid(ent) then return end

	if ent:IsNPC() then
		if ZCNPC.IsHidden(ent) then
			local rag = ent.zcnpc_rag
			if IsValid(rag) and istable(rag.organism) and rag.organism.fakePlayer and rag.organism.alive ~= false then
				return rag, ent
			end

			return
		end

		if istable(ent.organism) and ent.organism.fakePlayer and ent.organism.alive ~= false then
			return ent, ent
		end

		return
	end

	if ent:IsRagdoll() and ent.zcnpc_npcbody then
		local org = ent.organism
		if not (istable(org) and org.fakePlayer and org.alive ~= false) then return end

		local npc = ent.zcnpc_npc
		if not IsValid(npc) then return end

		return ent, npc
	end
end

local function ClosestLegDistanceSqr(char, trapPos)
	local best = math.huge

	for _, bones in pairs(LEG_BONES) do
		for _, name in ipairs(bones) do
			local pos = BonePos(char, name)
			if isvector(pos) then
				best = math.min(best, pos:DistToSqr(trapPos))
				break
			end
		end
	end

	if best < math.huge then return best end

	local nearest = char:NearestPoint(trapPos)

	return isvector(nearest) and nearest:DistToSqr(trapPos) or math.huge
end

local function ChooseLimb(body, trapPos)
	local org = body.organism
	if not org then return end

	local char = Character(body)
	local leftPos = BonePos(char, LEG_BONES.lleg[1]) or BonePos(char, LEG_BONES.lleg[2])
	local rightPos = BonePos(char, LEG_BONES.rleg[1]) or BonePos(char, LEG_BONES.rleg[2])

	local chosen
	if isvector(leftPos) and isvector(rightPos) then
		chosen = leftPos:DistToSqr(trapPos) <= rightPos:DistToSqr(trapPos) and "lleg" or "rleg"
	else
		local localPos = char:WorldToLocal(trapPos)
		chosen = localPos.y >= 0 and "lleg" or "rleg"
	end

	local other = chosen == "lleg" and "rleg" or "lleg"
	if org[chosen .. "amputated"] and not org[other .. "amputated"] then
		chosen = other
	end

	return chosen
end

local function SnapTrap(trap)
	trap.NextTrigger = CurTime() + 0.75
	trap:CloseTrap()

	local seq = trap:LookupSequence("Snap")
	if seq and seq >= 0 then
		trap:SetSequence(seq)
		trap:SetCycle(0)
		trap:SetPlaybackRate(1)
		trap:ResetSequenceInfo()
	end

	if istable(PAT_BEARTRAP) and PAT_BEARTRAP.Sound then
		trap:EmitSound(PAT_BEARTRAP.Sound, 75, 100)
	end

	timer.Simple(0.18, function()
		if IsValid(trap) then trap:CloseTrap() end
	end)
end

local function PaintBlood(pos, source)
	for _ = 1, 5 do
		local jitter = VectorRand() * 16
		jitter.z = math.abs(jitter.z) + 4

		if util.PaintDown then
			util.PaintDown(pos + jitter, "Blood", source)
		else
			local startPos = pos + jitter
			local tr = util.TraceLine({
				start = startPos,
				endpos = startPos - Vector(0, 0, 96),
				filter = source,
			})

			if tr.Hit then
				util.Decal("Blood", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal, source)
			end
		end
	end
end

local function StunSeconds()
	local cvar = istable(PAT_BEARTRAP) and PAT_BEARTRAP.StunTime
	if cvar and cvar.GetFloat then return cvar:GetFloat() end

	return 3
end

-- requireLegs: player-style foot radius. Standing NPC hull touches skip this
-- (stock trap does the same). Downed ragdolls keep the foot check.
local function TriggerOrganism(trap, body, standing, requireLegs)
	local org = body.organism
	if not org then return false end

	local trapPos = trap:GetPos()

	if requireLegs then
		local radius = trap.LegRadiusSqr or (22 * 22)
		if ClosestLegDistanceSqr(Character(body), trapPos) > radius then return false end
	end

	if standing == trap.LastVictim and (trap.LastVictimUntil or 0) > CurTime() then
		return false
	end

	SnapTrap(trap)
	trap.LastVictim = standing
	trap.LastVictimUntil = CurTime() + 2.5

	local limb = ChooseLimb(body, trapPos)
	local amputated = false

	if limb and org[limb .. "amputated"] ~= true and isfunction(hg.organism.AmputateLimb) then
		-- Field must exist or Z-City's AmputateLimb returns immediately.
		if org[limb .. "amputated"] == nil then
			org[limb .. "amputated"] = false
		end

		-- Our own gib gate would block a trap snap otherwise (sv_gib.lua).
		if ZCNPC.AllowNextGib then ZCNPC.AllowNextGib(org, body) end

		local ok, err = pcall(hg.organism.AmputateLimb, org, limb)
		if not ok then
			ZCNPC.Debug("bear trap AmputateLimb error:", err)
		end

		amputated = org[limb .. "amputated"] == true
	end

	if not amputated then
		local owner = trap.GetTrapOwner and trap:GetTrapOwner()
		local dmg = DamageInfo()
		dmg:SetDamage(45)
		dmg:SetDamageType(DMG_SLASH)
		dmg:SetAttacker(IsValid(owner) and owner or trap)
		dmg:SetInflictor(trap)
		body:TakeDamageInfo(dmg)
	end

	local stun = StunSeconds()
	org.lightstun = math.max(org.lightstun or 0, CurTime() + stun)

	timer.Simple(0, function()
		if not IsValid(standing) then return end

		if IsValid(standing.zcnpc_rag) then
			ZCNPC.ExtendDown(standing.zcnpc_rag, stun)
		elseif standing:IsNPC() then
			ZCNPC.Floor(standing, math.max(stun, 3))
		end
	end)

	PaintBlood(trapPos, Character(body))
	ZCNPC.Debug("bear trap shredded", standing, limb or "?", amputated and "amputated" or "slash")

	return true
end

local function PatchENT(ENT)
	if not ENT or ENT.zcnpc_beartrap_patched then return end
	ENT.zcnpc_beartrap_patched = true

	local oldTrigger = ENT.TriggerVictim
	function ENT:TriggerVictim(victimEnt)
		if not ZCNPC.Enabled() then
			return oldTrigger(self, victimEnt)
		end

		local body, standing = OrganismVictim(victimEnt)
		if body then
			-- TriggerVictim is the stock NPC path (no foot gate).
			local requireLegs = body:IsRagdoll()
			if TriggerOrganism(self, body, standing, requireLegs) then return end
		end

		return oldTrigger(self, victimEnt)
	end

	local oldTouch = ENT.Touch
	function ENT:Touch(toucher)
		if not ZCNPC.Enabled() then
			return oldTouch(self, toucher)
		end

		if IsValid(self) and self:GetArmed() and self.NextTrigger <= CurTime() then
			local body, standing = OrganismVictim(toucher)
			if body then
				if standing == self.LastVictim and (self.LastVictimUntil or 0) > CurTime() then
					return
				end

				-- Hull contact on a standing NPC is enough (stock behaviour).
				local requireLegs = body:IsRagdoll()
				if TriggerOrganism(self, body, standing, requireLegs) then return end
			end
		end

		return oldTouch(self, toucher)
	end

	local oldThink = ENT.Think
	function ENT:Think()
		if ZCNPC.Enabled() and self:GetArmed() and self.NextTrigger <= CurTime() then
			local radius = self.ScanRadius or 24

			for _, ent in ipairs(ents.FindInSphere(self:GetPos(), radius)) do
				if ent == self then continue end

				local body, standing = OrganismVictim(ent)
				if not body then continue end
				if standing == self.LastVictim and (self.LastVictimUntil or 0) > CurTime() then continue end

				-- Same gate as Touch / stock Think: feet only for downed ragdolls.
				local requireLegs = body:IsRagdoll()
				if TriggerOrganism(self, body, standing, requireLegs) then
					self:NextThink(CurTime())

					return true
				end
			end
		end

		return oldThink(self)
	end
end

function ZCNPC.InstallBearTrap()
	if not Present() then return false end

	local stored = scripted_ents.GetStored("ent_pat_beartrap")
	if stored and stored.t then PatchENT(stored.t) end

	for _, ent in ipairs(ents.FindByClass("ent_pat_beartrap")) do
		PatchENT(ent:GetTable())
	end

	if not ZCNPC.__beartrap_entity_hook then
		ZCNPC.__beartrap_entity_hook = true

		hook.Add("OnEntityCreated", "zcnpc_beartrap", function(ent)
			local class = ent:GetClass()
			if isstring(class) and class ~= "" and class ~= "ent_pat_beartrap" then return end

			timer.Simple(0, function()
				if not (IsValid(ent) and ent:GetClass() == "ent_pat_beartrap") then return end
				if not ZCNPC.Enabled() then return end

				PatchENT(ent:GetTable())
			end)
		end)
	end

	ZCNPC.Debug("Bear Trap bridge armed")

	return true
end

hook.Add("InitPostEntity", "zcnpc_beartrap_retry", function()
	if ZCNPC.InstallBearTrap then ZCNPC.InstallBearTrap() end
end)

timer.Create("zcnpc_beartrap_retry", 3, 10, function()
	if not ZCNPC.InstallBearTrap then return end
	if ZCNPC.InstallBearTrap() then
		timer.Remove("zcnpc_beartrap_retry")
	end
end)
