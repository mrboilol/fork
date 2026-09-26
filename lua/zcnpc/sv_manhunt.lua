--[[
	[Z-City] Manhunt Executions.

	The execution addon builds a fresh prop_ragdoll for an NPC, plays the
	animation on that, writes wounds onto the hidden NPC's organism, then
	deletes the NPC and leaves the prop standing there with none of those
	wounds. What you see is a clean corpse after a killing that just opened
	a throat — and sometimes a second body, because the 1000-damage finish
	also knocks the NPC down our way.

	The standing NPC is laid down as one of our bodies first. The animation
	is retargeted onto that ragdoll, the generic prop is thrown away, and
	the finish is a KillDowned on the same organism that was standing there.
]]

local cfg = ZCNPC.Config

function ZCNPC.HasManhunt()
	return istable(MH) and isfunction(MH.Play)
end

function ZCNPC.ManhuntReady()
	return ZCNPC.HasManhunt() and (not cfg.manhunt or cfg.manhunt:GetBool())
end

function ZCNPC.ManhuntLethal()
	local cv = cfg.manhunt_kill
	if not cv and ConVarExists("zcnpc_manhunt_kill") then
		cv = GetConVar("zcnpc_manhunt_kill")
	end

	return not cv or cv:GetBool()
end

local function ShareBody(victim, body)
	if not (IsValid(victim) and IsValid(body)) then return end

	local org = ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(victim) or victim.organism or body.organism
	if not org then return end

	body.organism = org
	body.new_organism = victim.new_organism or org
	body.zcnpc_npcbody = true
	body.zcnpc_npc = victim
	body.zcnpc_manhunt = true
	victim.zcnpc_mh_body = body

	if ZCNPC.TransferArmor then ZCNPC.TransferArmor(victim, body) end

	body:SetNetVar("wounds", org.wounds or {})
	body:SetNetVar("arterialwounds", org.arterialwounds or {})
	body:SetNWString("PlayerName", victim:GetNWString("PlayerName"))
	body:SetNWVector("PlayerColor", victim:GetNWVector("PlayerColor"))
end

local function SyncWounds(victim, body)
	if not (IsValid(victim) and IsValid(body)) then return end

	local org = victim.organism or body.organism
	if not org then return end

	body.organism = org
	body:SetNetVar("wounds", org.wounds or {})
	body:SetNetVar("arterialwounds", org.arterialwounds or {})
end

local function PlaceBody(rag, pos, ang)
	if not IsValid(rag) then return end

	if isvector(pos) then rag:SetPos(pos) end
	if isangle(ang) then rag:SetAngles(ang) end

	rag:SetCollisionGroup(COLLISION_GROUP_WORLD)
	rag.LootingDisabled = true
end

local function RetargetAnims(from, to)
	if not (IsValid(from) and IsValid(to)) then return end

	for _, ent in ipairs(ents.FindByClass("mh_anim")) do
		if IsValid(ent) and ent.Rag == from and isfunction(ent.Drive) then
			ent:Drive(to)
		end
	end
end

local STAB_BONES = {
	"ValveBiped.Bip01_Spine2",
	"ValveBiped.Bip01_Spine1",
	"ValveBiped.Bip01_Spine",
	"ValveBiped.Bip01_Neck1",
	"ValveBiped.Bip01_Spine4",
}

local function WoundBody(ent)
	if not IsValid(ent) then return end

	if ent.organism then return ent end

	local body = ent.zcnpc_mh_body or ent.zcnpc_rag
	if IsValid(body) and body.organism then return body end

	local npc = ent.zcnpc_npc
	if IsValid(npc) then
		if npc.organism then return npc end

		body = npc.zcnpc_mh_body or npc.zcnpc_rag
		if IsValid(body) and body.organism then return body end
	end
end

-- Z-City's pulse reads org.stabwounds / slashwounds / bruises, not org.wounds.
-- AddWoundManual only fills the latter (the blood holes). Manhunt's own hits
-- call that and then TakeDamageInfo, and the damage is eaten by
-- manhunt_kills_nodamage until finish(), so HomigradDamage never increments
-- the counters. Remember the table as it was before the animation, then credit
-- whatever appeared by the time the body is left on the floor.
local BLADE_FAM = {
	Knife = true,
	Cleaver = true,
	IceAxe = true,
}

local function KillFamily(name)
	if not isstring(name) then return end

	return string.match(name, "^(%a+)")
end

local function RememberWounds(ent, name)
	if not IsValid(ent) then return end

	local fam = KillFamily(name)
	if fam then
		ent.zcnpc_mh_fam = fam
		ent.zcnpc_mh_blade = BLADE_FAM[fam] or false
	end

	if ent.zcnpc_mh_wounds0 ~= nil then return end

	local org = ent.organism or (ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(ent))
	if not org then return end

	ent.zcnpc_mh_wounds0 = #(org.wounds or {})
	ent.zcnpc_mh_stabs0 = org.stabwounds or 0
	ent.zcnpc_mh_slashes0 = org.slashwounds or 0
	ent.zcnpc_mh_bruises0 = org.bruises or 0
end

local function CopyWoundMark(from, to)
	if not (IsValid(from) and IsValid(to) and from ~= to) then return end

	to.zcnpc_mh_fam = to.zcnpc_mh_fam or from.zcnpc_mh_fam
	if to.zcnpc_mh_blade == nil then to.zcnpc_mh_blade = from.zcnpc_mh_blade end
	if to.zcnpc_mh_wounds0 == nil then to.zcnpc_mh_wounds0 = from.zcnpc_mh_wounds0 end
	if to.zcnpc_mh_stabs0 == nil then to.zcnpc_mh_stabs0 = from.zcnpc_mh_stabs0 end
	if to.zcnpc_mh_slashes0 == nil then to.zcnpc_mh_slashes0 = from.zcnpc_mh_slashes0 end
	if to.zcnpc_mh_bruises0 == nil then to.zcnpc_mh_bruises0 = from.zcnpc_mh_bruises0 end
end

local function CreditManhuntWounds(ent)
	if not IsValid(ent) then return end

	local body = ent:IsRagdoll() and ent or (ent.zcnpc_mh_body or ent.zcnpc_rag)
	if not IsValid(body) then body = ent end
	if body.zcnpc_mh_credited then return end

	local org = body.organism or ent.organism
		or (ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(body))
	if not org then return end

	local baseline = body.zcnpc_mh_wounds0
	if baseline == nil and ent ~= body then baseline = ent.zcnpc_mh_wounds0 end
	if baseline == nil then
		body.zcnpc_mh_credited = true

		return
	end

	local added = math.max(0, #(org.wounds or {}) - baseline)
	if added <= 0 then
		body.zcnpc_mh_credited = true

		return
	end

	local fam = body.zcnpc_mh_fam or ent.zcnpc_mh_fam
	local blade = body.zcnpc_mh_blade
	if blade == nil then blade = ent.zcnpc_mh_blade end
	if blade == nil then blade = BLADE_FAM[fam] == true end

	if blade then
		if fam == "Cleaver" then
			local start = body.zcnpc_mh_slashes0 or ent.zcnpc_mh_slashes0 or 0
			org.slashwounds = math.max(org.slashwounds or 0, start + added)
		else
			local start = body.zcnpc_mh_stabs0 or ent.zcnpc_mh_stabs0 or 0
			org.stabwounds = math.max(org.stabwounds or 0, start + added)
		end
	else
		local start = body.zcnpc_mh_bruises0 or ent.zcnpc_mh_bruises0 or 0
		org.bruises = math.max(org.bruises or 0, start + added)
	end

	body.zcnpc_mh_credited = true
	if ent ~= body then ent.zcnpc_mh_credited = true end
end

local function StabWounds(ent, count)
	ent = WoundBody(ent)
	if not IsValid(ent) then return end

	local org = ent.organism or (ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(ent))
	if not org then return end

	org.wounds = org.wounds or {}
	ent.organism = org

	count = math.Clamp(count or math.random(1, 5), 1, 5)
	org.stabwounds = (org.stabwounds or 0) + count

	local bones = {}
	for i = 1, #STAB_BONES do
		if ent:LookupBone(STAB_BONES[i]) then
			bones[#bones + 1] = STAB_BONES[i]
		end
	end
	if #bones == 0 then bones[1] = STAB_BONES[1] end

	if isfunction(hg.organism.AddWoundManual) then
		for _ = 1, count do
			hg.organism.AddWoundManual(ent, math.random(25, 55), VectorRand(-2, 2), AngleRand(),
				bones[math.random(#bones)], CurTime())
		end
	else
		for _ = 1, count do
			org.wounds[#org.wounds + 1] = {
				math.random(12, 28),
				VectorRand(-2, 2),
				AngleRand(),
				bones[math.random(#bones)],
				CurTime(),
			}
		end
	end

	org.bleed = (org.bleed or 0) + math.Rand(3, 7)
	org.internalBleed = (org.internalBleed or 0) + math.Rand(1, 4)
end

local function MarkWoundOnly(ent, on)
	if not IsValid(ent) then return end

	ent.zcnpc_mh_woundonly = on or nil
	if ent:IsNPC() then
		ent.zcnpc_mh_holdremove = on or nil
	end

	local body = ent.zcnpc_mh_body or ent.zcnpc_rag
	if IsValid(body) then
		body.zcnpc_mh_woundonly = on or nil
	end

	local npc = ent.zcnpc_npc
	if IsValid(npc) and npc ~= ent then
		npc.zcnpc_mh_woundonly = on or nil
		npc.zcnpc_mh_holdremove = on or nil
	end
end

-- The execution addon's finish() calls victim:Remove() on the hidden NPC. A
-- field overwrite on that one entity does not catch :Remove() - that goes
-- through the Entity metatable. The downed monitor then sees a vanished NPC
-- and buries the body as a corpse, which is why the toggle did nothing.
local WoundOnlyFinish

local function InstallRemoveHold()
	local meta = FindMetaTable("Entity")
	if not meta or meta._ZCNPCMHRemove then return end
	if not isfunction(meta.Remove) then return end

	local old = meta.Remove

	meta.Remove = function(self)
		if self.zcnpc_mh_holdremove then
			WoundOnlyFinish(self)

			return
		end

		return old(self)
	end

	meta._ZCNPCMHRemove = true
end

WoundOnlyFinish = function(ent)
	if not ent then return end

	local victim, body
	if IsValid(ent) then
		victim = ent:IsNPC() and ent or ent.zcnpc_npc
		body = ent.zcnpc_mh_body or ent.zcnpc_rag
		if not IsValid(body) and ent:IsRagdoll() then body = ent end
	else
		victim = ent.zcnpc_npc
		body = ent.zcnpc_mh_body or ent.zcnpc_rag
	end

	if not IsValid(victim) then victim = nil end
	if not IsValid(body) then
		body = victim and (victim.zcnpc_mh_body or victim.zcnpc_rag)
		if not IsValid(body) then body = nil end
	end

	if (victim and victim.zcnpc_mh_wounded) or (body and body.zcnpc_mh_wounded) then
		return
	end

	local org = (body and body.organism)
		or (victim and victim.organism)
		or (ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(body or victim))

	-- Clamp the kill flags before the monitor is allowed to see this body as
	-- finished. Clearing the latch first is what let a brain=1 from the
	-- animation bury them on the same tick.
	if org then
		if (org.brain or 0) >= 1 then org.brain = 0.45 end
		if (org.skull or 0) >= 1 then org.skull = 0.4 end
		org.headamputated = nil
		org.alive = true
		org.otrub = true
		org.needotrub = true
	end

	if victim then
		victim.zcnpc_mh_wounded = true
		victim.zcnpc_mh_holdremove = nil
	end

	if body then body.zcnpc_mh_wounded = true end

	MarkWoundOnly(victim or body, false)

	-- Credit the animation first: StabWounds adds its own stab counter, and
	-- those holes must not also be counted as whatever family the swings were.
	pcall(CreditManhuntWounds, body or victim)
	pcall(StabWounds, body or victim, math.random(1, 5))

	if body then
		body.LootingDisabled = nil
		body:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		if ZCNPC.ExtendDown then ZCNPC.ExtendDown(body, 8) end
		if victim then SyncWounds(victim, body) end
		body:SetNetVar("wounds", (org and org.wounds) or {})
		body:SetNetVar("arterialwounds", (org and org.arterialwounds) or {})
		-- Execution is over and they are out. Injured-writhe on a "Knocked out"
		-- body is the active ragdoll still driving them.
		if ZCNPC.UpdateActive then ZCNPC.UpdateActive(body) end
		if ZCNPC.SweepDupes then
			ZCNPC.SweepDupes(body)
			timer.Simple(0, function()
				if IsValid(body) then ZCNPC.SweepDupes(body) end
			end)
			timer.Simple(0.08, function()
				if IsValid(body) then ZCNPC.SweepDupes(body) end
			end)
		end
	end

	ZCNPC.Debug("manhunt wound-only finish", victim, body)
end

ZCNPC.ManhuntWoundFinish = WoundOnlyFinish

local function InstallExplodeHold()
	if not (istable(hg) and isfunction(hg.ExplodeHead)) then return end
	if hg._ZCNPCExplodeHead then return end

	local old = hg.ExplodeHead

	hg.ExplodeHead = function(ent, ...)
		if IsValid(ent) and (ent.zcnpc_mh_woundonly or ent.zcnpc_mh_holdremove
			or (IsValid(ent.zcnpc_npc) and (ent.zcnpc_npc.zcnpc_mh_woundonly
				or ent.zcnpc_npc.zcnpc_mh_holdremove))) then
			return
		end

		return old(ent, ...)
	end

	hg._ZCNPCExplodeHead = true
end

-- The body on the ground is the corpse. Do not build a second organism onto a
-- generic prop — that is how a manhunt kill left two people on the floor.
local function KeepCorpse(victim, body)
	if not IsValid(body) then return end
	if body.zcnpc_mh_kept then return end

	if (IsValid(victim) and (victim.zcnpc_mh_woundonly or victim.zcnpc_mh_holdremove
			or victim.zcnpc_mh_wounded))
		or body.zcnpc_mh_woundonly or body.zcnpc_mh_wounded
		or not ZCNPC.ManhuntLethal() then
		WoundOnlyFinish(IsValid(victim) and victim or body)

		return
	end

	body.zcnpc_mh_kept = true
	body.zcnpc_keepbody = true
	body.LootingDisabled = nil
	body:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	pcall(CreditManhuntWounds, IsValid(victim) and victim or body)

	local info = ZCNPC.Downed and ZCNPC.Downed[body]
	if info and ZCNPC.KillDowned then
		ZCNPC.KillDowned(body, info)
		if ZCNPC.SweepDupes then ZCNPC.SweepDupes(body) end

		return
	end

	if IsValid(victim) and victim.organism and ZCNPC.TransferOrganismToCorpse then
		ZCNPC.TransferOrganismToCorpse(victim, body)
	elseif istable(body.organism) then
		body.organism.alive = false
		body.organism.owner = body
		body:SetNetVar("wounds", body.organism.wounds or {})
		body:SetNetVar("arterialwounds", body.organism.arterialwounds or {})
	end

	body.zcnpc_corpse = true
end

local function LayDown(victim)
	if not (IsValid(victim) and victim:IsNPC()) then return end
	if IsValid(victim.zcnpc_rag) then return victim.zcnpc_rag end
	if not isfunction(ZCNPC.MakeUnconscious) then return end

	local ok, made = pcall(ZCNPC.MakeUnconscious, victim, nil, nil)
	if ok and IsValid(made) then return made end
end

local function FindGeneric(victim, ours, caught)
	if IsValid(victim.zcnpc_mh_body) and victim.zcnpc_mh_body ~= ours then
		return victim.zcnpc_mh_body
	end

	for i = 1, #caught do
		local ent = caught[i]
		if IsValid(ent) and ent:GetModel() == victim:GetModel() and ent ~= ours and ent ~= victim.zcnpc_rag then
			return ent
		end
	end

	for _, ent in ipairs(ents.FindInSphere(victim:GetPos(), 96)) do
		if IsValid(ent) and ent:GetClass() == "prop_ragdoll"
			and ent:GetModel() == victim:GetModel()
			and ent ~= ours and ent ~= victim.zcnpc_rag
			and not ent.zcnpc_npcbody then
			return ent
		end
	end
end

local function Install()
	if not ZCNPC.HasManhunt() then return false end

	InstallRemoveHold()
	InstallExplodeHold()

	if MH._ZCNPCPlay then return true end

	local old = MH.Play

	MH.Play = function(killer, victim, name)
		local ours
		local woundOnly = ZCNPC.ManhuntReady() and not ZCNPC.ManhuntLethal()
			and IsValid(victim) and not victim:IsPlayer()

		if ZCNPC.ManhuntReady() and IsValid(victim) and not victim:IsPlayer() then
			ours = LayDown(victim)

			if IsValid(ours) then
				ours.zcnpc_manhunt = true
				ours.zcnpc_npcbody = true
				ours.zcnpc_keepbody = true
				victim.zcnpc_mh_body = ours

				local org = ours.organism
				if org then
					org.otrub = true
					org.needotrub = true
				end

				if ZCNPC.ExtendDown then ZCNPC.ExtendDown(ours, 30) end
			end

			if woundOnly then
				MarkWoundOnly(victim, true)
			end

			-- MakeUnconscious moves the organism onto the ragdoll. Manhunt's
			-- own hits write victim.organism, so point that field at the same
			-- table or the cuts never land.
			if IsValid(ours) and ours.organism then
				victim.organism = ours.organism
			end

			RememberWounds(ours, name)
			RememberWounds(victim, name)
			CopyWoundMark(ours, victim)
			CopyWoundMark(victim, ours)
		end

		local caught = {}
		local catch = "zcnpc_mh_catch_" .. (IsValid(victim) and victim:EntIndex() or 0)

		hook.Add("OnEntityCreated", catch, function(ent)
			if IsValid(ent) and ent:GetClass() == "prop_ragdoll" then
				caught[#caught + 1] = ent
			end
		end)

		local ok, err = old(killer, victim, name)
		hook.Remove("OnEntityCreated", catch)

		if not ok then return ok, err end
		if not ZCNPC.ManhuntReady() then return ok, err end
		if not (IsValid(victim) and not victim:IsPlayer()) then return ok, err end

		local generic = FindGeneric(victim, ours, caught)

		if IsValid(ours) and IsValid(generic) and generic ~= ours then
			PlaceBody(ours, generic:GetPos(), generic:GetAngles())
			RetargetAnims(generic, ours)

			local kbody = IsValid(killer) and killer.FakeRagdoll
			if IsValid(kbody) then constraint.NoCollide(kbody, ours, 0, 0) end

			generic:Remove()
			if ZCNPC.SweepDupes then
				ZCNPC.SweepDupes(ours)
				timer.Simple(0, function()
					if IsValid(ours) then ZCNPC.SweepDupes(ours) end
				end)
			end
		elseif IsValid(generic) and not IsValid(ours) then
			ours = generic
			ShareBody(victim, ours)
		elseif IsValid(ours) then
			ShareBody(victim, ours)
		end

		if not IsValid(ours) then return ok, err end

		victim.zcnpc_mh_body = ours
		ShareBody(victim, ours)
		-- Victim was marked before MH.Play started the hits. Copy that baseline
		-- onto the body first or RememberWounds would snapshot a table that
		-- already has the first cut in it.
		CopyWoundMark(victim, ours)
		RememberWounds(ours, name)
		RememberWounds(victim, name)
		CopyWoundMark(ours, victim)

		if woundOnly then
			MarkWoundOnly(victim, true)
			if ours.organism then victim.organism = ours.organism end
		end

		local tag = "zcnpc_mh_" .. victim:EntIndex()
		timer.Create(tag, 0.15, 40, function()
			if not (IsValid(victim) and IsValid(ours)) then
				timer.Remove(tag)

				return
			end

			SyncWounds(victim, ours)
		end)

		if woundOnly then
			local kill = MH.Kills and MH.Kills[name]
			local wait = (kill and kill.len or 6) + 0.3
			local woundTag = "zcnpc_mh_wound_" .. victim:EntIndex()

			timer.Create(woundTag, wait, 1, function()
				if (IsValid(victim) and victim.zcnpc_mh_wounded)
					or (IsValid(ours) and ours.zcnpc_mh_wounded) then
					return
				end

				WoundOnlyFinish(IsValid(victim) and victim or ours)
			end)
		end

		victim:CallOnRemove("zcnpc_manhunt", function(ent)
			timer.Remove(tag)
			if ent.zcnpc_mh_woundonly or ent.zcnpc_mh_holdremove or ent.zcnpc_mh_wounded then
				local body = ent.zcnpc_mh_body
				if IsValid(body) and not body.zcnpc_mh_wounded then
					WoundOnlyFinish(body)
				end

				return
			end

			timer.Remove("zcnpc_mh_wound_" .. ent:EntIndex())
			if IsValid(ent.zcnpc_mh_body) then KeepCorpse(ent, ent.zcnpc_mh_body) end
		end)

		ZCNPC.Debug("manhunt body shared", victim, ours)

		return ok, err
	end

	MH._ZCNPCPlay = true
	ZCNPC.Debug("Manhunt Executions bridge installed")

	return true
end

-- Skull / brain events during the animation would kill the organism before
-- finish() even runs. Hold them down for the length of the execution.
hook.Add("Org Think", "zcnpc_manhunt_wound", function(owner, org)
	if not (istable(org) and IsValid(owner)) then return end
	if not (owner.zcnpc_mh_woundonly or owner.zcnpc_mh_holdremove
		or (IsValid(owner.zcnpc_npc) and (owner.zcnpc_npc.zcnpc_mh_woundonly
			or owner.zcnpc_npc.zcnpc_mh_holdremove))) then
		return
	end

	if (org.brain or 0) >= 0.7 then org.brain = 0.45 end
	if (org.skull or 0) >= 1 then org.skull = 0.4 end
	org.headamputated = nil
	org.alive = true
	org.otrub = true
end)

hook.Add("EntityTakeDamage", "zcnpc_manhunt_corpse", function(ent, dmgInfo)
	if not ZCNPC.ManhuntReady() then return end
	if not (IsValid(ent) and ent:IsNPC() and IsValid(ent.zcnpc_mh_body)) then return end
	if not (dmgInfo and isfunction(dmgInfo.GetDamage)) or dmgInfo:GetDamage() < 400 then return end

	if ent.zcnpc_mh_woundonly or ent.zcnpc_mh_holdremove or not ZCNPC.ManhuntLethal() then
		return true
	end

	KeepCorpse(ent, ent.zcnpc_mh_body)

	return true
end)

hook.Add("EntityRemoved", "zcnpc_manhunt_wound", function(ent)
	if not ent then return end
	if not (ent.zcnpc_mh_holdremove or ent.zcnpc_mh_woundonly) then return end

	local body = ent.zcnpc_mh_body or ent.zcnpc_rag
	if IsValid(body) and not body.zcnpc_mh_wounded then
		WoundOnlyFinish(body)
	end
end)

hook.Add("CreateEntityRagdoll", "zcnpc_manhunt_noragdoll", function(ent, rag)
	if not (IsValid(ent) and IsValid(rag)) then return end
	if ZCNPC.DropEngineRagdoll and ZCNPC.DropEngineRagdoll(ent, rag) then return end
	if not IsValid(ent.zcnpc_mh_body) then return end
	if rag == ent.zcnpc_mh_body then return end

	rag.zcnpc_drop = true
	timer.Simple(0, function()
		if IsValid(rag) and rag ~= ent.zcnpc_mh_body then rag:Remove() end
	end)
end)

Install()
hook.Add("HomigradRun", "zcnpc_manhunt", function()
	timer.Simple(0, Install)
end)
timer.Create("zcnpc_manhunt_retry", 2, 0, function()
	if Install() then timer.Remove("zcnpc_manhunt_retry") end
end)
