--[[
	Pairing an unconscious NPC with the body lying on the ground.

	Z-City drives its whole client side simulation (bleeding, heartbeat, wounds)
	from one loop over hg.seenents, which hands every entity to the
	"Player-Ragdoll think" hook as (owner, renderedEntity) - cl_utility.lua:429.
	The owner supplies the wound list, the rendered entity supplies the bone
	positions, and the loop skips anything whose owner is currently faked into a
	ragdoll (`IsValid(ent.FakeRagdoll)`).

	Our downed NPC is neither: the entity stays in the world (hidden, frozen at
	the spot it collapsed on) and keeps its stale organism, so Z-City happily
	goes on spraying its arterial bleeding out of an invisible body standing
	where the NPC fell. Pairing the two entities the same way a player is paired
	with a fake ragdoll puts the blood back on the body.
]]

ZCNPC = ZCNPC or {}
ZCNPC.Bodies = ZCNPC.Bodies or {} -- [npc] = ragdoll it is currently lying as

--\\ Entities can arrive before the net message that talks about them
local pending = {}

local function Resolve(index)
	local ent = Entity(index)

	return IsValid(ent) and ent or nil
end

-- indices: { name = entIndex, ... }; run is called once every one of them exists
function ZCNPC.WaitEntities(indices, run)
	pending[#pending + 1] = { indices = indices, run = run, till = CurTime() + 2 }
end

local Wait = ZCNPC.WaitEntities

local resolved = {}

local function ClearResolved()
	for slot in pairs(resolved) do
		resolved[slot] = nil
	end
end

hook.Add("Think", "zcnpc_pending", function()
	if #pending == 0 then return end

	for i = #pending, 1, -1 do
		local job = pending[i]
		local ok = true

		for slot, index in pairs(job.indices) do
			local ent = Resolve(index)
			if not ent then
				ok = false

				break
			end

			resolved[slot] = ent
		end

		if ok then
			table.remove(pending, i)
			job.run(resolved)
			ClearResolved()
		elseif job.till < CurTime() then
			table.remove(pending, i)
			ClearResolved()
		else
			ClearResolved()
		end
	end
end)
--//

--\\ Going down / getting back up
function ZCNPC.AttachBody(npc, rag)
	ZCNPC.Bodies[npc] = rag

	-- makes Z-City's client think loop treat the hidden NPC as "already lying
	-- over there" and stop simulating it, exactly like a faked player
	npc.FakeRagdoll = rag

	-- Pairing the two also puts the gun in the body's hand for free, because that is
	-- how a weapon finds the hand it belongs in: SWEP:WorldModel_Transform draws on
	-- owner.FakeRagdoll when there is one (homigrad_base/sh_worldmodel.lua:566). That
	-- branch was written for players though, and asks the owner for its aim vector,
	-- which no NPC has.
	if not npc.GetAimVector then npc.GetAimVector = npc.GetForward end

	rag.zcnpc_npcbody = true
	rag.organism = rag.organism or npc.organism
	rag.new_organism = rag.new_organism or npc.new_organism
	rag.wounds = rag:GetNetVar("wounds") or rag.wounds or npc.wounds
	rag.arterialwounds = rag:GetNetVar("arterialwounds") or rag.arterialwounds or npc.arterialwounds

	-- The hidden husk is still in hg.organism_ents from when it was standing.
	-- Z-City's seen-ents scan adds every one of those on top of every ragdoll,
	-- so a downed NPC was being FOV-tested twice a frame for nothing.
	if istable(hg) and istable(hg.organism_ents) then
		hg.organism_ents[npc] = nil
	end

	hook.Run("ZCNPC_ClientDowned", npc, rag)
end

function ZCNPC.DetachBody(npc, rag)
	rag = IsValid(rag) and rag or ZCNPC.Bodies[npc]
	ZCNPC.Bodies[npc] = nil

	if not IsValid(npc) then return end

	npc.FakeRagdoll = nil
	if npc.GetAimVector == npc.GetForward then npc.GetAimVector = nil end

	if IsValid(rag) then
		-- Carry the bleeding back onto the NPC. Whatever the server already
		-- resent to this entity wins - the organism snapshot that comes with
		-- waking up arrives before this message does.
		npc.wounds = npc:GetNetVar("wounds") or rag.wounds or npc.wounds
		npc.arterialwounds = npc:GetNetVar("arterialwounds") or rag.arterialwounds or npc.arterialwounds
		npc.organism = npc.organism or rag.new_organism or rag.organism
		npc.new_organism = npc.new_organism or rag.new_organism

		-- and make sure the body cannot keep bleeding on its own while it is
		-- still around for the get up animation
		rag.organism = nil
		rag.new_organism = nil
		rag.wounds = nil
		rag.arterialwounds = nil
	end

	if istable(hg) and istable(hg.organism_ents) and npc.organism then
		hg.organism_ents[npc] = true
	end

	hook.Run("ZCNPC_ClientWokeUp", npc, rag)
end

-- How long the NPC is kept off screen while the get up animation is on its way.
-- It is the same packet, so this is a handful of frames at most; the number is
-- only there so that an animation that never starts cannot leave an NPC invisible.
local GETUP_GRACE = 0.4

net.Receive("zcnpc_body", function()
	local down = net.ReadBool()
	local npcIndex = net.ReadUInt(16)
	local ragIndex = net.ReadUInt(16)
	local getup = net.ReadBool()

	if down then
		Wait({ npc = npcIndex, rag = ragIndex }, function(ents)
			ZCNPC.AttachBody(ents.npc, ents.rag)
		end)

		return
	end

	local npc = Entity(npcIndex)
	local rag = ragIndex > 0 and Entity(ragIndex) or NULL

	if IsValid(npc) then ZCNPC.DetachBody(npc, rag) end

	if not getup then return end

	-- Both halves of the changeover, before the animation itself has arrived: the
	-- body stops being drawn and the NPC does not start until there is a pose to
	-- draw it in.
	ZCNPC.HideBody(rag, GETUP_GRACE + 1)
	ZCNPC.HoldDraw(npc, GETUP_GRACE)
end)

--\\ Bodies nobody told us about
-- The message above is said once, at the moment somebody goes down, and it is only
-- of use to a client that has both entities within a couple of seconds of hearing
-- it. Two kinds of client do not:
--
-- * one that connected afterwards. The message was sent before it was there.
-- * one on the far side of the map. A body out of PVS does not exist on the client
--   at all, so there is nothing to pair, and by the time somebody walks over to it
--   the message is long gone.
--
-- What that client sees is a body it does not know is a body: the bleeding stays
-- with the hidden NPC, and so does the gun - the world model is drawn on the hand
-- of owner.FakeRagdoll and there is nothing else for it to be drawn on
-- (homigrad_base/sh_worldmodel.lua:566), so a rifle hangs in the air over the body
-- at the height the NPC was holding it when it collapsed.
--
-- So the pairing is read off the body as well (sv_uncon.lua SyncBody), which anybody
-- can do the first time they can see the body. Noticed when the ragdoll appears
-- (OnEntityCreated, including walking into PVS) rather than by walking every
-- prop_ragdoll twice a second. A NetVar can arrive a tick late, so a body that
-- is not yet labelled is asked again for a few seconds and then left alone.
local PENDING_FOR = 3
local RETRY = 0.25

local pendingRags = {}
local retryAt = 0

local function TryPair(rag)
	if not IsValid(rag) then return true end

	local npc = rag:GetNWEntity("zcnpc_npc")
	if not (IsValid(npc) and npc:IsNPC()) then return false end

	if ZCNPC.Bodies[npc] ~= rag then
		ZCNPC.AttachBody(npc, rag)
	end

	return true
end

local function Notice(ent)
	if not (IsValid(ent) and ent:GetClass() == "prop_ragdoll") then return end
	if TryPair(ent) then return end

	pendingRags[ent] = CurTime() + PENDING_FOR
end

hook.Add("OnEntityCreated", "zcnpc_body_resync", function(ent)
	-- A brand new entity has not got its class yet, but IsRagdoll is
	-- already true for prop_ragdoll. A timer per casing is the client
	-- half of the same firefight tax.
	if not (IsValid(ent) and (ent:IsRagdoll() or ent:GetClass() == "prop_ragdoll")) then
		return
	end

	timer.Simple(0, function() Notice(ent) end)
end)

local function ScanExisting()
	for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
		Notice(rag)
	end
end

hook.Add("InitPostEntity", "zcnpc_body_resync", ScanExisting)
timer.Simple(1, ScanExisting)

hook.Add("Think", "zcnpc_body_resync", function()
	if not next(pendingRags) then return end
	if retryAt > CurTime() then return end
	retryAt = CurTime() + RETRY

	local now = CurTime()

	for rag, till in pairs(pendingRags) do
		if TryPair(rag) or till < now then
			pendingRags[rag] = nil
		end
	end
end)
--//

-- the body can also just disappear (admin cleanup, round restart)
hook.Add("EntityRemoved", "zcnpc_body", function(ent)
	pendingRags[ent] = nil

	for npc, rag in pairs(ZCNPC.Bodies) do
		if rag == ent or npc == ent then
			ZCNPC.Bodies[npc] = nil
			if IsValid(npc) and npc ~= ent then npc.FakeRagdoll = nil end
		end
	end
end)
--//
