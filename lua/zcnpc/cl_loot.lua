--[[
	The hands of somebody kneeling over a body.

	The crouch itself is not here any more. It is an animation layer the server puts
	on the NPC (sh_workpose.lua), which means it is real animation: it moves, the
	server's own hitboxes move with it, and anything the engine hangs off a bone -
	a stock Half-Life 2 rifle, parented to the hand attachment in C++ - follows the
	hand instead of staying up at the height the NPC was standing at.

	What no stock animation has is what the man is doing. ACT_COVER_LOW is a soldier
	ducking behind a wall: arms in, weapon up, perfectly still. A rebel going through
	a dead metrocop's pockets and a medic leaning on a stopped heart are the same
	crouch with completely different arms, and there is no sequence in any of these
	models for either of them.

	So the arms are solved rather than replayed. Two bone IK onto a point on the body
	being worked on (cl_pose.lua, the same solver the handcuff pose uses), which has
	the property that matters here: the target is a place in the world, so the hand
	lands on the body wherever the body actually is - the chest of a man lying on his
	back, the hip of one face down in a doorway - without anybody having authored a
	pose for each.

	Three jobs, three pairs of hands:

	  * Going through pockets. The free hand - the left one, since the right is holding
	    a rifle - down at the hip, moving the way a hand moves when it is feeling for
	    something rather than reaching for it.
	  * Chest compressions. Both hands stacked over the sternum, leaning in once
	    every half second, which is the rate the server actually compresses at
	    (sv_rescue.lua).
	  * A wrap, a needle, a bag of blood. Both hands on the chest, working slowly.
	    The item itself is a real item in the NPC's hand and draws itself there
	    (cl_medicine.lua).

	The crouch is still drawn here for a model the layer could not be started on -
	one with no crouch anywhere in it, or an engine branch without the overlay
	methods. The server says which, because whether a model has an animation in it is
	a question about the server's copy of that model and a client that guessed wrong
	would draw two crouches on top of each other.
]]

ZCNPC = ZCNPC or {}

local Pose = ZCNPC.Pose
local BONE = ZCNPC.Bone
local Work = ZCNPC.Work
local WORK = ZCNPC.WorkVar

--\\ What the server said
local function Kind(npc)
	return npc:GetNWInt(WORK.kind, Work.NONE)
end

-- The clock is read alongside the job rather than instead of it. The job is what says
-- which hands to draw and is cleared when the work ends; the clock is what expires by
-- itself, so a crouch whose end nobody got round to announcing stands back up on its own
-- rather than for the rest of the round.
local function Till(npc)
	return npc:GetNWFloat(WORK.till, 0)
end

local function Working(npc)
	local kind = Kind(npc)
	if kind == Work.NONE or kind == Work.LOOT then return false end

	return Till(npc) > CurTime()
end
--//

--\\ The crouch, for a model the layer could not be started on
local NAMES = { "crouchidle", "crouch_idle", "Crouch_idle" }

-- Read out of _G by name so that an activity this branch of the engine does not have
-- is a shorter list rather than a nil handed to SelectWeightedSequence.
local ACT_NAMES = {
	"ACT_COVER_LOW",
	"ACT_CROUCHIDLE",
	"ACT_RANGE_AIM_LOW",
	"ACT_RELOAD_LOW",
	"ACT_COVER_PISTOL_LOW",
	"ACT_COVER_SMG1_LOW",
}

local ACTS = {}

for _, name in ipairs(ACT_NAMES) do
	local act = _G[name]

	if isnumber(act) then ACTS[#ACTS + 1] = act end
end

-- Enough to read as motion out of a two second idle without paying for a frame
-- nobody can see the difference of.
local SAMPLES = 10

-- Long enough not to snap a skeleton into a crouch on one frame, short enough that
-- the crouch is there for nearly all of a search. Standing back up has no matching
-- ease on purpose: the server ends a search early when something walks round the
-- corner, and getting up off a body in a hurry is what that should look like.
local BLEND_IN = 0.3

-- [model] = sampled animation, or false for a model with no crouch anywhere in it.
local anims = {}

local function CrouchAnim(model)
	local anim = anims[model]

	if anim == nil then
		anim = Pose.SampleSequence(model, NAMES, ACTS, SAMPLES) or false
		anims[model] = anim
	end

	return anim or nil
end

-- Where in the loop it is, as a pair of sampled frames and how far between them.
local function Advance(anim)
	local f = ((CurTime() / anim.duration) % 1) * anim.count
	local a = math.floor(f)

	return anim.frames[a + 1], anim.frames[(a + 1) % anim.count + 1], f - a
end

local function DrawCrouch(npc)
	local anim = CrouchAnim(npc:GetModel())
	if not anim then return end

	local from, to, k = Advance(anim)
	if not (from and to) then return end

	-- Two tables, kept on the NPC and never pointed at each other. On the NPC because
	-- Pose.Apply reads up to the bone count of whatever it is drawing, so two models
	-- with different skeletons sharing one scratch pose leaves the smaller wearing
	-- what the larger left behind. Separate because Pose.Blend and Pose.Transform
	-- both write into the table they are handed, and a table that is both an input and
	-- the output is a pose blending with itself.
	npc.zcnpc_lootframe = Pose.Blend(from, to, k, npc.zcnpc_lootframe)

	-- The sample is model space - origin at the feet, facing +X - so where the NPC is
	-- standing and which way it is turned is the whole transform.
	local ang = Angle(0, npc:GetAngles().y, 0)

	npc.zcnpc_lootworld = Pose.Transform(npc.zcnpc_lootframe, vector_origin, ang, npc:GetPos(), npc.zcnpc_lootworld)

	local out = npc.zcnpc_lootworld

	-- Timed from the first frame this draws rather than from when the server says the
	-- work began, because those are not the same moment. A render override is only
	-- installed on an NPC that has something to draw, by a scan every fifth of a
	-- second (cl_render.lua), so an NPC with nothing else drawn on it starts being
	-- drawn up to that late - and a blend read off the server's clock would be two
	-- thirds of the way into the crouch on the first frame anybody sees, which is the
	-- snap the blend is here to avoid.
	--
	-- Keyed on the work's own end time: a new one for every job, so the previous
	-- crouch's clock is never mistaken for this one's.
	local till = Till(npc)

	if npc.zcnpc_lootsearch ~= till then
		npc.zcnpc_lootsearch = till
		npc.zcnpc_lootstart = CurTime()
	end

	local blend = math.min((CurTime() - npc.zcnpc_lootstart) / BLEND_IN, 1)

	if blend < 1 then
		-- Out of the animation the AI is playing and into the crouch. Captured rather
		-- than remembered, because what it eases out of is whatever the NPC was doing
		-- when it got there - walking, turning, standing. cl_render.lua calls SetupBones
		-- before the passes run, so this is the animation underneath rather than what
		-- the last frame of this pass wrote.
		npc.zcnpc_lootlive = Pose.Capture(npc, npc.zcnpc_lootlive)
		npc.zcnpc_lootblend = Pose.Blend(npc.zcnpc_lootlive, out, blend, npc.zcnpc_lootblend)

		out = npc.zcnpc_lootblend
	end

	Pose.Apply(npc, out)
end
--//

--\\ Where on the body the hands go
-- Pockets are at the hip and a heart is behind the sternum, and both of them are a
-- bone rather than a height above the floor: a body lying on its side has its chest
-- a foot off the ground and its hip somewhere else entirely, and an offset from the
-- ragdoll's origin would put a medic's hands in the air next to it.
local CHEST_BONE = "ValveBiped.Bip01_Spine2"
local HIP_BONE = "ValveBiped.Bip01_Pelvis"

-- Bone ids per body, kept on the body. Two name lookups a frame per NPC kneeling over
-- one is not much on its own, and it is also two answers that cannot change: a bone id
-- is a property of the model. `false` for a skeleton that has not got one.
local function BoneId(ent, name)
	local cache = ent.zcnpc_workbones

	if not cache then
		cache = {}
		ent.zcnpc_workbones = cache
	end

	local bone = cache[name]

	if bone == nil then
		bone = ent:LookupBone(name) or false
		cache[name] = bone
	end

	return bone or nil
end

local function BonePos(ent, name)
	local bone = BoneId(ent, name)
	if not bone then return end

	local mat = ent:GetBoneMatrix(bone)
	if not mat then return end

	return mat:GetTranslation()
end

local function WorkPoint(target, kind)
	-- The bones as they are this frame. A ragdoll draws itself from its own entry in
	-- the render list, in either order with the NPC kneeling over it, so its bones
	-- are as likely to be last frame's as this frame's.
	target:SetupBones()

	local name = kind == Work.LOOT and HIP_BONE or CHEST_BONE
	local pos = BonePos(target, name) or BonePos(target, CHEST_BONE)

	return pos or target:WorldSpaceCenter()
end
--//

--\\ What the hands are doing there
-- All three are a small movement around a fixed point, and all three are read off
-- CurTime rather than off how far through the job it is: what they are is somebody
-- working, and somebody working looks the same in the first second as in the last.
local RUMMAGE_RATE = 3.1
local RUMMAGE_REACH = 4

-- One compression every half second, which is the rate the server actually
-- compresses at - Compress is called from the half second pass (sv_rescue.lua), so
-- the hands go down as the ribs do rather than at a rate somebody picked to look
-- right.
local CPR_PERIOD = 0.5
local CPR_DEPTH = 7

local TREAT_RATE = 1.4
local TREAT_REACH = 2

-- Which way is "into the body" for a hand that is pressing on it. The NPC is turned
-- to face what it is kneeling over (sv_looting.lua, sv_rescue.lua), so its own
-- forward is across the body and down is down.
local function Offset(npc, kind)
	local t = CurTime()

	if kind == Work.CPR then
		-- Nothing but down, and all the way back up between: a compression is a lean,
		-- and the recoil is half of what makes it read as one.
		local push = 0.5 - 0.5 * math.cos(t * (math.pi * 2 / CPR_PERIOD))

		return -vector_up * (push * CPR_DEPTH)
	end

	local right = npc:GetRight()
	local forward = npc:GetForward()

	if kind == Work.LOOT then
		return right * (math.sin(t * RUMMAGE_RATE) * RUMMAGE_REACH)
			+ forward * (math.sin(t * RUMMAGE_RATE * 0.7) * RUMMAGE_REACH * 0.75)
			- vector_up * (math.abs(math.sin(t * RUMMAGE_RATE * 1.3)) * RUMMAGE_REACH * 0.5)
	end

	return right * (math.sin(t * TREAT_RATE) * TREAT_REACH)
		+ forward * (math.cos(t * TREAT_RATE * 0.8) * TREAT_REACH)
end

-- Which way the elbow bends. Out to the side of the shoulder and a little below it,
-- the same shape the handcuff pose uses (cl_render.lua) and for the same reason:
-- without a pole target the solver is free to put the elbow anywhere on a circle,
-- including through the ribs.
local ELBOW_OUT = 22
local ELBOW_DOWN = 10

-- How far apart the two hands sit when both are on the chest. Stacked rather than
-- side by side would be the textbook, and is not worth the wrists it would cost:
-- these are two independent two bone solves and crossing them over each other is
-- how an arm ends up inside the other one.
local HANDS_APART = 3.5

local function Reach(npc, prefix, target, side)
	local shoulder = Pose.Matrix(npc, BONE[prefix .. "upperarm"])
	if not shoulder then return end

	local root = shoulder:GetTranslation()
	local pole = root + npc:GetRight() * (ELBOW_OUT * side) - vector_up * ELBOW_DOWN

	Pose.SolveLimb(npc, BONE[prefix .. "upperarm"], BONE[prefix .. "forearm"], BONE[prefix .. "hand"], target, pole)
end

local function DrawHands(npc, kind)
	local target = npc:GetNWEntity(WORK.ent)
	if not IsValid(target) then return false end

	local point = WorkPoint(target, kind) + Offset(npc, kind)

	-- The free hand for pockets, and the free hand is the left one: the right is holding
	-- the rifle, which a man going through a dead metrocop's coat does not put down. It
	-- also keeps the gun out of it - the weapon rides the hand it is attached to
	-- (cl_weapon.lua), so searching with the right hand is searching with a rifle.
	-- Loot no longer reaches: a hand stretched at the body pulled the skeleton
	-- out of the hitboxes and left the searcher in a T-pose afterwards.
	if kind == Work.LOOT then return false end

	local across = npc:GetRight() * HANDS_APART

	Reach(npc, "r_", point + across, 1)
	Reach(npc, "l_", point - across, -1)

	return true
end
--//

--\\ The pass
-- Order 15: after the get up (10), which owns the bones outright for as long as it
-- runs and cannot be happening at the same time as this, and before the gore (20)
-- and the cuffs (30), both of which are meant to land on top of whatever pose the
-- body is standing in rather than under it.
ZCNPC.AddPass(15, "loot", Working, function(npc)
	local kind = Kind(npc)

	-- The crouch, only when the server could not put a layer on this model. When it
	-- could, what is underneath the hands is the layer playing on the NPC's own
	-- animation, which is where it belongs.
	if npc:GetNWBool(WORK.posed, false) then DrawCrouch(npc) end

	if not DrawHands(npc, kind) then return end

	-- Said out loud, because the gun in its hand is drawn from its own entry in the
	-- render list and has no other way of knowing the hand moved (cl_render.lua,
	-- cl_weapon.lua, cl_medicine.lua). The whole skeleton rather than the arms: the
	-- solver carries every bone under a shoulder with it, fingers and the weapon
	-- attachment point included, and there are never more than a handful of NPCs
	-- kneeling over anybody at once.
	npc.zcnpc_lootposed = Pose.Capture(npc, npc.zcnpc_lootposed)

	ZCNPC.MarkPosed(npc, npc.zcnpc_lootposed)
end)
--//
