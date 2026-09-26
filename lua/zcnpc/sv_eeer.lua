--[[
	EEER (ragdoll pain expressions).

	A body this addon lays down is spawned with ents.Create("prop_ragdoll").
	It is not an engine death ragdoll and it is not the NPC any more, so
	EEER's "NPC-only ragdolls" filter never sees a source and skips the face.
	The flags it already reads are written here, and a downed body is pointed
	at the NPC it came from.

	The face is the half we want. The other half is physics EEER starts the
	moment it sees an NPC ragdoll: death-stiff captures the standing pose
	0.12s later and holds it (the slow-mo headshot crumple), death-motion
	walks the legs and lifts the pelvis, and the twitch motor ticks every
	0.04s forever. Those come off here. The expression stays.
]]

local cfg = ZCNPC.Config

function ZCNPC.HasEeer()
	return istable(RPE_HEADSHOT) or istable(RPE_NET_MESSAGES) or ConVarExists("sv_rpe_enable")
end

function ZCNPC.EeerReady()
	return ZCNPC.HasEeer() and (not cfg.eeer or cfg.eeer:GetBool())
end

local function Headkill(ent)
	if not IsValid(ent) then return false end

	return ent.zcnpc_headkill == true
		or (IsValid(ent.zcnpc_rag) and ent.zcnpc_rag.zcnpc_headkill == true)
end

local function Mark(rag, npc)
	if not IsValid(rag) then return end

	rag.RPE_SourceWasNPC = true
	rag.sourceWasNPC = true
	rag.RPE_FromNPC = true
	rag.RPE_npc_source = npc
	rag.RPE_SourceEnt = npc

	if IsValid(npc) then
		-- PendingHeadshot is what starts EEER's death-stiff / death-motion on
		-- this rag. Copied onto a body that is still standing, that is the
		-- slow-mo fall. Face flags below are enough for the expression.
		if not Headkill(npc) and not Headkill(rag) then
			rag.RPE_PendingHeadshot = npc.RPE_PendingHeadshot or rag.RPE_PendingHeadshot
		end

		rag.RPE_LastHitGroup = npc.RPE_LastHitGroup
		rag.RPE_LastHitGroupAt = npc.RPE_LastHitGroupAt
	end
end

-- Block death-stiff (standing pose hold) and death-motion (gait + lift).
-- EEER queues the stiff 0.12s after it sees the rag, so this is repeated
-- for a couple of ticks after we first say it.
local function LetFallOnce(rag)
	if not IsValid(rag) then return end

	rag.RPE_DeathStiffStarted = true
	rag.RPE_DeathStiffQueued = nil
	rag.RPE_DeathMotionConsidered = true
	rag.RPE_DeathMotionPending = nil
	rag.RPE_PendingHeadshot = nil

	if istable(RPE_DEATH_MOTION) and isfunction(RPE_DEATH_MOTION.cancel) then
		RPE_DEATH_MOTION.cancel(rag, "zcnpc_fall")
	end

	if IsValid(rag.RPE_DeathStiffController) then
		rag.RPE_DeathStiffController:Remove()
		rag.RPE_DeathStiffController = nil
	end

	if IsValid(rag.RPE_DeathMotionController) then
		rag.RPE_DeathMotionController:Remove()
		rag.RPE_DeathMotionController = nil
	end
end

function ZCNPC.EeerLetFall(rag)
	if not IsValid(rag) then return end

	LetFallOnce(rag)

	local id = "zcnpc_eeer_fall_" .. rag:EntIndex()
	timer.Create(id, 0.05, 5, function()
		if IsValid(rag) then LetFallOnce(rag) end
	end)
end

local function ClearBrainfuck(rag)
	if not IsValid(rag) then return end

	rag.spasm, rag.spasmEnd, rag.spasmStart = nil, nil, nil
	rag.spasmDur, rag.spasmForce, rag.spasmType, rag.rigorActive = nil, nil, nil, nil

	local org = rag.organism
	if org then
		org.spasm, org.spasmType = nil, nil
	end
end

-- Dead: the 0.04s organic-wave / random-twitch motor stops. The face is
-- already written and stays. Z-City's own brainfuck spasm is cleared too.
function ZCNPC.EeerStopMotion(rag)
	if not IsValid(rag) then return end

	LetFallOnce(rag)
	ClearBrainfuck(rag)

	if isfunction(RPE_DisableRagdollAllEffectsByTotalDamage) then
		RPE_DisableRagdollAllEffectsByTotalDamage(rag)
	else
		rag.RPE_TotalDamageDisabled = true
		rag.RPE_TotalDamageDisabledAt = CurTime()
	end
end

hook.Add("ZCNPC_Downed", "zcnpc_eeer", function(npc, rag)
	if not ZCNPC.EeerReady() then return end

	Mark(rag, npc)

	if Headkill(npc) or Headkill(rag) then
		ZCNPC.EeerLetFall(rag)
	end
end)

hook.Add("ZCNPC_Died", "zcnpc_eeer_stop", function(rag)
	ZCNPC.EeerStopMotion(rag)
	timer.Simple(0.2, function()
		if IsValid(rag) then ZCNPC.EeerStopMotion(rag) end
	end)
end)

hook.Add("RagdollDeath", "zcnpc_eeer", function(ent, rag)
	if not ZCNPC.EeerReady() then return end
	if not (IsValid(ent) and ent:IsNPC() and IsValid(rag)) then return end

	Mark(rag, ent)
	-- This hook is a finished corpse (sv_core TransferOrganismToCorpse).
	ZCNPC.EeerStopMotion(rag)
end)

-- Damage on the hidden NPC has to reach the body EEER is actually looking at,
-- or a living expression never starts on a knockdown.
hook.Add("PostEntityTakeDamage", "zcnpc_eeer", function(ent, dmgInfo)
	if not ZCNPC.EeerReady() then return end
	if not (IsValid(ent) and ent:IsNPC() and IsValid(ent.zcnpc_rag)) then return end

	local rag = ent.zcnpc_rag
	Mark(rag, ent)

	-- A lethal head shot is still standing for a tick. build_pending_info is
	-- what queues death-stiff on that pose.
	if Headkill(ent) or Headkill(rag) then
		ZCNPC.EeerLetFall(rag)

		return
	end

	if istable(RPE_HEADSHOT) and isfunction(RPE_HEADSHOT.build_pending_info) then
		if (ent.zcnpc_headwound or 0) > CurTime() then
			RPE_HEADSHOT.build_pending_info(rag, dmgInfo, CurTime(), false)
		end
	end
end)
