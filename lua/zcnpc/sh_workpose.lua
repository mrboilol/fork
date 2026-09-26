--[[
	Kneeling down over somebody.

	Everything in this addon that puts an NPC on one knee - a rebel going through a
	dead man's pockets (sv_looting.lua), a medic working on one who is still alive
	(sv_rescue.lua) - used to be a pose written onto the bones as the NPC was drawn
	(cl_loot.lua). Which is one frame of one animation, held still, on the client
	only, and that is wrong in three ways at once:

	  * Nothing moves. A man going through a corpse's pockets for two and a half
	    seconds was a statue of a man crouching.
	  * The server does not know. Hitboxes follow the server's own bones, so the
	    head of a rebel drawn kneeling was still up where it would have been if it
	    were standing - shoot where you see the head and the round goes over it.
	  * Anything the engine hangs off a bone stays behind: a stock Half-Life 2
	    rifle is parented to the hand attachment in C++, so it hung in the air at
	    chest height and had to be hidden and redrawn by hand (cl_weapon.lua).

	So the crouch is an animation layer on the NPC instead. AddLayeredSequence is
	how Half-Life 2's own NPCs flinch and reload without leaving the schedule they
	are running: the layer is blended over whatever the AI has chosen, at full
	weight, so the AI is free to go on choosing - which is the whole reason the old
	comment said an NPC "cannot be handed an animation and trusted to keep it".
	Nothing has to win an argument with MaintainActivity, because nothing is
	arguing with it.

	And a layer is real animation. The server sets its own bones up out of it, so
	the hitboxes crouch; it is networked like any other layer, so every client
	plays it with its own interpolation and the gun in the hand follows the hand.

	The pose the layer plays is not bespoke. ACT_COVER_LOW is what these models
	already duck behind cover in and what Z-City maps a crouching player onto
	(dynamic_anims_util/sh_animbase.lua:254), so every humanoid an NPC can be has
	one and it fits the skeleton it is on - a citizen, a metrocop and a soldier
	each crouch in their own proportions with nothing retargeted.

	What is left for the client is the part no stock animation has: the hands. A
	crouch idle is a man crouching, not a man rummaging through pockets or leaning
	on somebody's chest, and that is solved with the arms rather than replayed
	(cl_loot.lua).
]]

ZCNPC = ZCNPC or {}

--\\ What an NPC is busy doing, for the client to draw
-- One number rather than a flag per job, because they are the same crouch with
-- different hands in it and the client picks the hands off this.
ZCNPC.Work = {
	NONE = 0,
	LOOT = 1, -- going through a body's pockets
	CPR = 2, -- both hands on a chest, leaning
	TREAT = 3, -- a wrap, a needle, a bag of blood
}

ZCNPC.WorkVar = {
	kind = "zcnpc_workkind",
	ent = "zcnpc_workent", -- the body being worked on: where the client aims the hands
	posed = "zcnpc_workposed", -- the client owns the crouch: the layer did not take

	-- When it is due to be over, which is a clock rather than a flag on purpose: a job
	-- whose end nobody got round to announcing ends by itself rather than leaving an NPC
	-- kneeling for the rest of the round. Every errand that starts one knows how long it
	-- is going to take (sv_looting.lua, sv_rescue.lua), so there is nothing to guess.
	till = "zcnpc_worktill",
}
--//

-- The rest is the server's - the layer itself and everything that starts or stops
-- one. What the client needs of this file is the two tables above.
if CLIENT then return end

local WORK = ZCNPC.WorkVar

--\\ The crouch, once per model
-- Read out of _G by name so that an activity this branch of the engine does not
-- have is a shorter list rather than a nil handed to SelectWeightedSequence.
local ACT_NAMES = {
	"ACT_COVER_LOW",
	"ACT_CROUCHIDLE",
	"ACT_RANGE_AIM_LOW",
	"ACT_COVER_PISTOL_LOW",
	"ACT_COVER_SMG1_LOW",
	"ACT_RELOAD_LOW",
}

local ACTS = {}

for _, name in ipairs(ACT_NAMES) do
	local act = _G[name]

	if isnumber(act) then ACTS[#ACTS + 1] = act end
end

-- Explicit crouch idles first, for a model that ships one under a name of its own
-- and means it; then the activities, which is where the stock Half-Life 2 humans
-- answer.
local SEQ_NAMES = { "crouchidle", "crouch_idle", "Crouch_idle" }

-- [model] = sequence id, or false for a model with nothing to crouch with. The
-- false is the point: a model looked at once is not looked at again, and one with
-- no crouch anywhere in it searches the body standing up rather than costing a
-- lookup per tick forever.
local sequences = {}

local function CrouchSequence(npc)
	local model = npc:GetModel()
	local seq = sequences[model]

	if seq == nil then
		seq = false

		for _, name in ipairs(SEQ_NAMES) do
			local id = npc:LookupSequence(name)

			if isnumber(id) and id > 0 then
				seq = id

				break
			end
		end

		if seq == false then
			for _, act in ipairs(ACTS) do
				local id = npc:SelectWeightedSequence(act)

				if isnumber(id) and id > 0 then
					seq = id

					break
				end
			end
		end

		sequences[model] = seq
	end

	return seq or nil
end

ZCNPC.CrouchSequence = CrouchSequence
--//

--\\ The layer
-- Above the gestures the AI plays over the top of its own movement (flinches sit
-- at 0), so a rebel that is shot at mid-search still flinches and the flinch does
-- not take the crouch away with it.
local PRIORITY = 1

-- Long enough not to snap a skeleton into a crouch on one frame, short enough that
-- the crouch is there for nearly all of a two and a half second search. Fractions
-- of the sequence rather than seconds: that is what SetLayerBlendIn takes.
local BLEND_IN = 0.25
local BLEND_OUT = 0.2

local function Layered(npc)
	local id = npc.zcnpc_worklayer
	if not isnumber(id) then return end

	if not (isfunction(npc.IsValidLayer) and npc:IsValidLayer(id)) then
		npc.zcnpc_worklayer = nil

		return
	end

	return id
end

-- Whether the layer actually took. A branch of the engine without the overlay
-- methods, a model with no crouch in it, an NPC the call refuses - all three end
-- up here, and all three mean the client has to draw the crouch itself.
local function StartLayer(npc)
	if Layered(npc) then return true end

	if not (isfunction(npc.AddLayeredSequence) and isfunction(npc.SetLayerWeight)) then
		return false
	end

	local seq = CrouchSequence(npc)
	if not seq then return false end

	local id = npc:AddLayeredSequence(seq, PRIORITY)
	if not (isnumber(id) and id >= 0) then return false end

	npc.zcnpc_worklayer = id

	-- Full weight: the crouch is meant to replace what the AI is playing rather
	-- than average with it, and a half weight blend of standing and crouching is a
	-- man sitting on nothing.
	npc:SetLayerWeight(id, 1)

	if isfunction(npc.SetLayerLooping) then npc:SetLayerLooping(id, true) end
	if isfunction(npc.SetLayerPlaybackRate) then npc:SetLayerPlaybackRate(id, 1) end
	if isfunction(npc.SetLayerBlendIn) then npc:SetLayerBlendIn(id, BLEND_IN) end
	if isfunction(npc.SetLayerBlendOut) then npc:SetLayerBlendOut(id, BLEND_OUT) end

	return true
end

local function StopLayer(npc)
	local id = Layered(npc)
	npc.zcnpc_worklayer = nil

	if not id then return end

	if isfunction(npc.RemoveLayer) then
		npc:RemoveLayer(id, BLEND_OUT, 0)
	elseif isfunction(npc.SetLayerWeight) then
		npc:SetLayerWeight(id, 0)
	end
end
--//

--\\ What the callers use
-- kind is one of ZCNPC.Work; target is the body being worked on, which is what the
-- client aims the hands at; till is when it is expected to be over.
function ZCNPC.BeginWork(npc, kind, target, till)
	if not (IsValid(npc) and npc:IsNPC()) then return end

	-- Searching a body is standing still over it. A crouch layer moves the
	-- server's hitboxes and the client IK stretches a hand at the corpse; both
	-- of those are gone on purpose.
	if kind == ZCNPC.Work.LOOT then
		ZCNPC.EndWork(npc)

		return
	end

	local layered = StartLayer(npc)

	npc:SetNWInt(WORK.kind, kind or ZCNPC.Work.LOOT)
	npc:SetNWEntity(WORK.ent, IsValid(target) and target or NULL)
	npc:SetNWFloat(WORK.till, till or (CurTime() + 3))

	-- Said out loud rather than left for the client to work out: whether a model has
	-- a crouch in it is a question about the server's copy of that model, and a
	-- client that guessed wrong either draws two crouches on top of each other or
	-- none at all.
	npc:SetNWBool(WORK.posed, not layered)
end

-- The same crouch, a different pair of hands. A rescue moves between compressions
-- and a wrap without standing up in between (sv_rescue.lua), so this is separate
-- from beginning one.
function ZCNPC.SetWorkKind(npc, kind)
	if not IsValid(npc) then return end
	if npc:GetNWInt(WORK.kind, 0) == kind then return end

	npc:SetNWInt(WORK.kind, kind)
end

-- Ten times a second from whichever hold timer owns the NPC. The layer is not
-- something the AI takes away, but a model swap, a lua refresh or a sequence that
-- ran itself out is, and re-asking is cheaper than being wrong for the rest of a
-- search.
function ZCNPC.HoldWork(npc)
	if not IsValid(npc) then return end
	if Layered(npc) then return end
	if npc:GetNWBool(WORK.posed, false) then return end -- the client already owns it

	if not StartLayer(npc) then npc:SetNWBool(WORK.posed, true) end
end

function ZCNPC.EndWork(npc)
	if not IsValid(npc) then return end

	StopLayer(npc)

	npc:SetNWInt(WORK.kind, ZCNPC.Work.NONE)
	npc:SetNWEntity(WORK.ent, NULL)
	npc:SetNWBool(WORK.posed, false)
	npc:SetNWFloat(WORK.till, 0)
end

-- Whether the NPC is in the middle of one, for anything that has to ask rather than
-- be told.
function ZCNPC.Working(npc)
	return IsValid(npc) and npc:GetNWInt(WORK.kind, 0) ~= ZCNPC.Work.NONE
end

-- A body on the floor is not kneeling over anybody. Every errand that starts one of
-- these ends it itself, and this is the one way out none of them can see: the
-- organism moves to the body, so the NPC leaves the list they are walked from.
hook.Add("ZCNPC_Downed", "zcnpc_workpose", function(npc)
	if not ZCNPC.Working(npc) then return end

	ZCNPC.EndWork(npc)
end)
--//
