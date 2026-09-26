--[[
	Finish off downed NPC bodies.

	Players stay valid enemies while FakeRagdoll'd, so hostiles keep shooting.
	Our downed NPCs used to get FL_NOTARGET the moment they hit the floor, so
	Combine / rebels forgot them instantly. While the body is still conscious
	(not otrub), the hidden half stays targetable, attackers are reminded of it,
	and their shots are steered at the ragdoll. Once it blacks out, NOTARGET
	comes back; waking on the floor or standing clears that again.
]]

local EXECUTE_RANGE_SQR = 3500 * 3500
local REMIND_INTERVAL = 0.35

-- Still worth shooting: awake enough to writhe / get back up.
--
-- Read as "is there anybody in there", and the organism is not the only place that
-- answers it. A body is finished by things that happen to the body - the head comes
-- off, the shooting goes on until there is nothing left of the chest - and the
-- organism behind it is not always told in the same tick, or at all: hg.ExplodeHead
-- reaches Gib_Input directly (sv_head.lua:407), which caps the neck and writes
-- noHead without touching brain, so a beheaded body read as somebody worth putting
-- another magazine into for as long as it stayed on the list. That is the whole of
-- "they shoot corpses": every one of these was a yes here, so hostiles were reminded
-- of it twice a second and their rounds were steered into it on purpose.
--
-- ZCNPC.IsCorpse asks the same question for Artagdoll (sv_artagdoll.lua:444) and is
-- the fuller answer, but it loads later and says no during the death collapse, which
-- is a body that is dying rather than one that is down. So the markers are read here
-- and it is asked as well when it is there.
function ZCNPC.IsDownedTargetable(rag)
	if not IsValid(rag) then return false end

	local org = rag.organism
	if not istable(org) then return false end
	if org.alive == false then return false end
	if org.otrub then return false end
	if org.heartstop then return false end
	if (org.consciousness or 1) <= 0.4 then return false end
	if (org.brain or 0) >= 1 then return false end
	if org.headamputated then return false end

	-- Dead, or dead in the next fraction of a second and only still here because the
	-- head shot delay is what makes it look like a head shot (sv_head.lua:949).
	if rag.zcnpc_corpse or rag.zcnpc_dead then return false end
	if rag.noHead or rag.headexploded then return false end
	if rag.zcnpc_headkill or (rag.zcnpc_deferredkill or 0) > CurTime() then return false end
	if (rag.zcnpc_hp or 1) <= 0 then return false end

	local npc = rag.zcnpc_npc
	if IsValid(npc) and npc.zcnpc_headkill then return false end

	if isfunction(ZCNPC.IsCorpse) and ZCNPC.IsCorpse(rag) then return false end

	return ZCNPC.Downed and ZCNPC.Downed[rag] ~= nil
end

--\\ Letting go of somebody who is no longer worth shooting
-- FL_NOTARGET stops an NPC picking a new enemy. It does nothing about one it has
-- already got: HL2 keeps the enemy and its last known position and goes on
-- putting rounds into the spot, which is what "they shoot dead bodies" looks
-- like from the floor. The husk being removed a moment later does not settle it
-- either - the memory of where it was outlives the entity, and an AI layer that
-- suppresses a position (Combat Intelligence) will keep firing at it on purpose.
--
-- So being finished with is said out loud, once, to everyone who was aiming:
-- forget the enemy, forget where it was, and let the addons that keep their own
-- memory of it hear about it too (ZCNPC_TargetLost).
local RELEASE_RANGE = 3500

function ZCNPC.ReleaseAttackers(target, pos)
	if not IsValid(target) then return end

	pos = pos or target:WorldSpaceCenter()

	for _, att in ipairs(ents.FindInSphere(pos, RELEASE_RANGE)) do
		if not (IsValid(att) and att:IsNPC()) then continue end
		if att == target then continue end

		local aiming = att:GetEnemy() == target

		if aiming then att:SetEnemy(NULL) end

		-- Everyone who remembers it, not only whoever is aiming at it this instant.
		-- HL2 picks its next enemy out of what it remembers, so a body taken off one
		-- NPC's sights and left in the memory of the three stood behind it is a body
		-- all four look back round for.
		if isfunction(att.ClearEnemyMemory) then
			-- The one-argument form forgets this enemy; the old call took none, which
			-- threw away everything the NPC knew about everybody - so that one is
			-- kept for whoever was actually shooting at this body.
			if not pcall(att.ClearEnemyMemory, att, target) and aiming then
				att:ClearEnemyMemory()
			end
		end
	end

	hook.Run("ZCNPC_TargetLost", target, pos)
end
--//

function ZCNPC.UpdateDownedTargetable(rag, info)
	info = info or (ZCNPC.Downed and ZCNPC.Downed[rag])
	if not info then return end

	local npc = info.npc
	if not IsValid(npc) then return end

	local want = ZCNPC.Enabled() and ZCNPC.IsDownedTargetable(rag)
	local flagged = bit.band(npc:GetFlags(), FL_NOTARGET) == FL_NOTARGET

	if want and flagged then
		npc:RemoveFlags(FL_NOTARGET)
		ZCNPC.Debug("downed targetable", npc)
	elseif not want and not flagged then
		npc:AddFlags(FL_NOTARGET)
		ZCNPC.Debug("downed notarget (otrub)", npc)

		ZCNPC.ReleaseAttackers(npc, rag:WorldSpaceCenter())
	end
end

-- Steer hostile fire at the body instead of the invisible husk / empty air.
hook.Add("EntityFireBullets", "zcnpc_execute_aim", function(ent, data)
	if not ZCNPC.Enabled() then return end

	local npc = ent
	if IsValid(ent) and ent:IsWeapon() then
		npc = ent:GetOwner()
	end

	if not (IsValid(npc) and npc:IsNPC()) then return end
	if ZCNPC.IsHidden(npc) then return end

	local enemy = npc:GetEnemy()
	if not (IsValid(enemy) and enemy:IsNPC() and ZCNPC.IsHidden(enemy)) then return end

	local rag = enemy.zcnpc_rag
	if not ZCNPC.IsDownedTargetable(rag) then return end

	local aim = rag:WorldSpaceCenter()
	local src = data.Src
	if not isvector(src) then return end

	local dir = aim - src
	if dir:LengthSqr() < 1 then return end

	data.Dir = dir:GetNormalized()
	-- Prefer the body; the husk is GODMODE + redirected anyway.
	data.IgnoreEntity = enemy

	return true
end)

-- Hits that still land on the hidden husk count on the body while it is targetable.
local function RedirectToBody(ent, dmgInfo)
	local rag = ent.zcnpc_rag
	if not ZCNPC.IsDownedTargetable(rag) then return false end
	if dmgInfo:GetDamage() <= 0 then return false end

	local copy = DamageInfo()
	copy:SetDamage(dmgInfo:GetDamage())
	copy:SetDamageType(dmgInfo:GetDamageType())
	copy:SetDamageForce(dmgInfo:GetDamageForce())
	copy:SetDamagePosition(dmgInfo:GetDamagePosition())
	copy:SetAttacker(dmgInfo:GetAttacker())
	copy:SetInflictor(dmgInfo:GetInflictor())
	if dmgInfo.GetDamageCustom then
		copy:SetDamageCustom(dmgInfo:GetDamageCustom())
	end

	dmgInfo:SetDamage(0)
	dmgInfo:SetDamageForce(vector_origin)

	timer.Simple(0, function()
		if IsValid(rag) then
			rag:TakeDamageInfo(copy)
		end
	end)

	return true
end

-- Replaces the hard zero in sv_uncon for the targetable window.
hook.Add("EntityTakeDamage", "zcnpc_execute_redirect", function(ent, dmgInfo)
	if not (ZCNPC.Enabled() and ZCNPC.IsHidden(ent)) then return end

	if RedirectToBody(ent, dmgInfo) then
		return true
	end
end)

-- Keep nearby hostiles locked on a conscious body (HL2 forgets FL_NOTARGET flips).
--
-- Everybody who might be shooting at a body, gathered once for the whole pass. This
-- used to be a 3500 unit FindInSphere per body, which is the wrong shape of question
-- twice over: the sphere answers with every entity inside ninety metres - the props,
-- the debris, the gibs, the dropped magazines, on some maps most of what is in the
-- level - and it was asked again for each body on the floor, so the cost of a
-- firefight went up with the square of how badly it had gone.
--
-- The list that is actually wanted is the NPCs, of which there are tens. They
-- are already on ZCNPC.NPCs (sv_core.lua); walking that and measuring distances
-- by hand is a few dozen cheap tests instead of a walk of every entity on the
-- map, and it asks the two questions that do not depend on which body it is -
-- is it hidden, is it alive - once per NPC rather than once per NPC per body.
--
-- Held between passes so a running fight is one table rather than one every third of
-- a second.
local hostiles = {}
local hostilePos = {}

local function CollectHostiles()
	local n = 0
	local npcs = ZCNPC.NPCs

	if npcs then
		for ent in pairs(npcs) do
			if IsValid(ent) and not ZCNPC.IsHidden(ent) and ent:Health() > 0 then
				n = n + 1
				hostiles[n] = ent
				hostilePos[n] = ent:GetPos()
			end
		end
	end

	-- The tail of a longer pass must not be walked again as though it were live.
	for i = n + 1, #hostiles do
		hostiles[i] = nil
		hostilePos[i] = nil
	end

	return n
end

timer.Create("zcnpc_execute_remind", REMIND_INTERVAL, 0, function()
	if not ZCNPC.Enabled() then return end

	local downed = ZCNPC.Downed
	if not downed or not next(downed) then return end

	-- The NPCs are only worth gathering if something down there is worth shooting at,
	-- and that is decided per body. Gathered lazily, on the first body that says yes.
	local count

	for rag, info in pairs(downed) do
		if not IsValid(rag) then continue end

		ZCNPC.UpdateDownedTargetable(rag, info)

		if not ZCNPC.IsDownedTargetable(rag) then continue end

		local victim = info.npc
		if not IsValid(victim) then continue end

		count = count or CollectHostiles()
		if count == 0 then return end

		local pos = rag:WorldSpaceCenter()

		for i = 1, count do
			local att = hostiles[i]
			if att == victim then continue end
			if not IsValid(att) then continue end

			-- Distance first: it is the test that rules out almost everybody and the
			-- only one here that is arithmetic rather than a call into the engine.
			if hostilePos[i]:DistToSqr(pos) > EXECUTE_RANGE_SQR then continue end
			if att:Disposition(victim) ~= D_HT then continue end

			local enemy = att:GetEnemy()
			if IsValid(enemy) and enemy ~= victim and not (enemy:IsNPC() and ZCNPC.IsHidden(enemy)) then
				continue
			end

			att:SetEnemy(victim)
			att:UpdateEnemyMemory(victim, pos)

			local state = att:GetNPCState()
			if state == NPC_STATE_IDLE or state == NPC_STATE_ALERT or state == NPC_STATE_NONE then
				att:SetNPCState(NPC_STATE_COMBAT)
			end
		end
	end
end)

hook.Add("ZCNPC_Downed", "zcnpc_execute", function(npc, rag)
	if not ZCNPC.Enabled() then return end

	ZCNPC.UpdateDownedTargetable(rag, ZCNPC.Downed[rag])
end)

hook.Add("ZCNPC_WokeUp", "zcnpc_execute", function(npc)
	if not IsValid(npc) then return end

	npc:RemoveFlags(FL_NOTARGET)
end)
