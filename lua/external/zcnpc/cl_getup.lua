--[[
	Get up animation, client half.

	Neither Z-City nor the HL2 NPC models have a get up sequence. Players leaving
	a fake ragdoll are respawned on the spot and the client crossfades every bone
	from the ragdoll pose straight into the standing pose over 0.8s
	(hg.SmoothUnfake, fake/sh_render.lua:6); on an NPC that looks like the body is
	being sucked upright, and the hand built keyframes that used to replace it here
	could never look like more than an approximation of getting up.

	So this plays real motion capture instead. sh_getup_anim.lua carries two Valve
	getup animations taken out of Left 4 Dead 2's survivor animation set - one for
	a body lying on its front, one for its back - stored as parent relative bone
	rotations. Replaying them is plain forward kinematics, and because the bone
	offsets come off whatever model is being animated, the same motion fits a
	citizen and a combine soldier with no retargeting.

	Both ends of the animation are anchored on something real. The NPC is already
	standing where the server decided it should end up, turned to the direction
	this animation finishes in, so the last frame lands on the NPC's own standing
	pose. The first frame is dragged over onto the body's actual pelvis, and that
	pull is eased out as the body rises. No floor traces are involved: the NPC's
	origin is on the ground by definition, and the animation was authored with its
	own origin on the floor.
]]

ZCNPC = ZCNPC or {}

local Pose = ZCNPC.Pose
local BONE = ZCNPC.Bone
local Anim = ZCNPC.GetUpAnim

local playing = {} -- [npc] = state

--\\ Tuning
-- Fractions of the animation spent leaving the pose the body is lying in, and
-- settling into whatever the NPC's own animation is doing by then.
local BLEND_IN = 0.18
local BLEND_OUT = 0.14

-- How far the animation may be dragged towards the body. A stand spot further
-- away than this means the body is somewhere the NPC could not get up from
-- anyway (wedged under a car, on the far side of a fence), and sliding the whole
-- animation over there looks worse than starting it where the NPC is.
local ANCHOR_REACH = 40
--//

local function Smooth(k)
	k = math.Clamp(k, 0, 1)

	return k * k * (3 - 2 * k)
end

--\\ Per model rig
-- Which bone ids the animation drives, the chain connecting them, and every
-- bone's rest offset from its parent. Bone offsets never animate in Source (the
-- root is the only bone that translates), so these can be read out of any pose
-- and are worth keeping for as long as the model is around.
local rigs = {}

-- Every bone the animation does not name, paired with the nearest bone above it
-- that the animation does drive. A citizen has 72 bones and the animation covers
-- 23 of them; the other 49 are the 30 finger bones, the 16 deformation helpers
-- that sit on the chest, back and shoulders (Pectoral, Latt, Trapezius, Bicep,
-- Shoulder, Elbow, Ulna, Wrist) and the two hand attachment points weapon world
-- models hang off.
--
-- They matter because Entity:SetBoneMatrix does not carry a bone's children with
-- it - it writes into the array of world matrices SetupBones already computed, so
-- turning Spine2 leaves whatever hangs off Spine2 exactly where it was. Left
-- alone, all 49 stay in the NPC's standing pose at the spot it is standing on
-- while the animated ones are down on the floor, and the mesh, weighted to both
-- at once, stretches between them into long dark shards - the "broken textures"
-- of a get up.
local function ExtraBones(ref, rig)
	local driven = {}

	for i = 1, rig.count do
		if rig.bones[i] then driven[rig.bones[i]] = i end
	end

	local extra = {}

	for bone = 0, ref:GetBoneCount() - 1 do
		if driven[bone] then continue end

		local anchor
		local parent = ref:GetBoneParent(bone)

		while parent and parent >= 0 and not anchor do
			anchor = driven[parent]
			parent = ref:GetBoneParent(parent)
		end

		-- nothing above it is animated: that is the model root and whatever else
		-- hangs off it beside the pelvis, so the pelvis is what it follows
		extra[#extra + 1] = { bone, anchor or 1 }
	end

	return extra
end

local function BuildRig(model)
	local ref = Pose.Reference(model)
	if not IsValid(ref) then return end

	ref:ResetSequence(0)
	ref:SetCycle(0)
	ref:SetPlaybackRate(0)
	ref:InvalidateBoneCache()
	ref:SetupBones()

	local count = #Anim.bones
	local rig = { count = count, bones = {}, parents = {}, offsets = {} }
	local world = {}

	for i = 1, count do
		local bone = ref:LookupBone(Anim.bones[i])
		local matrix = bone and ref:GetBoneMatrix(bone)

		if matrix then
			rig.bones[i] = bone
			world[i] = matrix
		end
	end

	if not rig.bones[1] then return end -- no pelvis: not a ValveBiped skeleton

	for i = 1, count do
		if not rig.bones[i] then continue end

		-- a skeleton missing a joint (custom models turn up without Spine4 or
		-- toes) hands its children to the nearest bone it does have, so the chain
		-- stays connected and only that one joint's rotation is lost
		local parent = Anim.parents[i]
		while parent > 0 and not rig.bones[parent] do parent = Anim.parents[parent] end
		rig.parents[i] = parent

		if parent > 0 then
			rig.offsets[i] = (world[parent]:GetInverseTR() * world[i]):GetTranslation()
		end
	end

	rig.extra = ExtraBones(ref, rig)

	-- the motion was captured on a 40 unit tall pelvis; a shorter model needs a
	-- proportionally shorter root path or it would push itself off the floor
	rig.scale = world[1]:GetTranslation().z / Anim.pelvisRestZ

	rigs[model] = rig

	return rig
end
--//

--\\ Sampling
-- World matrices of `variant` between frames `a` and `b`, where `root` is the
-- matrix that puts the animation's model space (origin on the floor, body facing
-- +X) into the world. Rotations are interpolated through Z-City's quaternions
-- rather than component wise, so a bone whose stored yaw wraps past 180 degrees
-- between two frames does not spin the long way round.
local function Sample(rig, variant, a, b, k, root, out)
	local rotA, rotB = variant.rot[a], variant.rot[b]
	local posA, posB = variant.root[a], variant.root[b]

	for i = 1, rig.count do
		if not rig.bones[i] then continue end

		local o = (i - 1) * 3
		local ang = Angle(rotA[o + 1], rotA[o + 2], rotA[o + 3])

		if k > 0 then
			local from, to = Matrix(), Matrix()
			from:SetAngles(ang)
			to:SetAngles(Angle(rotB[o + 1], rotB[o + 2], rotB[o + 3]))

			ang = Pose.BlendAngles(from, to, k)
		end

		local mat = Matrix()
		mat:SetAngles(ang)

		local parent = rig.parents[i]

		if parent == 0 then
			mat:SetTranslation(Vector(
				Lerp(k, posA[1], posB[1]),
				Lerp(k, posA[2], posB[2]),
				Lerp(k, posA[3], posB[3])
			) * rig.scale)

			out[i] = root * mat
		else
			mat:SetTranslation(rig.offsets[i])

			out[i] = out[parent] * mat
		end
	end

	return out
end

-- The bones nobody animates ride the nearest one that is animated, keeping the
-- pose they are holding relative to it right now. Read live off `ent` rather
-- than off the rest pose so that whatever its own animation is doing with them
-- survives - fingers wrapped around a gun stay wrapped around it, and the weapon
-- attachment point keeps the gun in the hand for the length of the get up.
--
-- Taking the transform from the nearest animated ancestor instead of walking the
-- chain down is the same delta Z-City applies in hg.bone_apply_matrix, and it
-- comes out identical: the bones in between are not animated either, so the
-- whole run of them is rigid with respect to that ancestor.
local function ToPose(rig, mats, ent, out)
	for i = 1, rig.count do
		local bone = rig.bones[i]
		if bone then out[bone] = mats[i] end
	end

	for i = 1, #rig.extra do
		local bone, index = rig.extra[i][1], rig.extra[i][2]

		local anchor = rig.bones[index]
		local moved = anchor and out[anchor]
		if not moved then continue end

		local live, liveAnchor = ent:GetBoneMatrix(bone), ent:GetBoneMatrix(anchor)
		if not (live and liveAnchor) then continue end

		local inverse = liveAnchor:GetInverse()
		if not inverse then continue end

		out[bone] = moved * (inverse * live)
	end

	return out
end
--//

--\\ Keeping the body out of sight
-- The body and the NPC are the same person and only one of them may be on screen.
-- Neither end of that changeover is a single moment, and both ends used to show
-- both of them:
--
-- * at the start, the server has to show the NPC entity before it can say what to
--   do with it, so for a frame or two there is an NPC standing next to its own
--   body. cl_body.lua hides the body the moment it hears the NPC is getting up,
--   which is the earliest anybody can know, and ZCNPC.HoldDraw keeps the NPC off
--   screen for the same handful of frames.
-- * at the end, the animation finishes on the client and the body is removed by
--   the server a tenth of a second later plus however long the packet takes. Put
--   the body back on screen at the end of the animation and that gap is the body
--   lying there again, in the pose it was in, next to somebody who has just stood
--   up out of it.
--
-- So it stays hidden, and what ends the hiding is a time limit rather than the
-- animation: the removal is the thing that is meant to end it and a time limit is
-- what covers the removal not arriving.
local hidden = function() end

local held = {} -- [ragdoll] = { restore = its own override, till = when to give up }

-- seconds nil: hidden until somebody says otherwise
function ZCNPC.HideBody(rag, seconds)
	if not IsValid(rag) then return end

	local entry = held[rag]

	if not entry then
		-- Z-City hangs its corpse gore renderer on every prop_ragdoll
		-- (fake/cl_fake.lua:447), so there is usually something here worth
		-- handing back
		entry = { restore = rag.RenderOverride }
		held[rag] = entry

		rag.RenderOverride = hidden
	end

	entry.till = seconds and (CurTime() + seconds) or nil
end

function ZCNPC.ShowBody(rag)
	local entry = held[rag]
	if not entry then return end

	held[rag] = nil

	if IsValid(rag) and rag.RenderOverride == hidden then rag.RenderOverride = entry.restore end
end

hook.Add("Think", "zcnpc_heldbodies", function()
	if not next(held) then return end

	for rag, entry in pairs(held) do
		if not IsValid(rag) then
			held[rag] = nil
		elseif entry.till and entry.till < CurTime() then
			ZCNPC.ShowBody(rag)
		end
	end
end)
--//

--\\ Playback
local function Capture(npc, rag, faceUp)
	if not (IsValid(npc) and IsValid(rag)) then return end
	if not istable(Anim) then return end

	local variant = faceUp and Anim.faceup or Anim.facedown
	if not (istable(variant) and variant.frames) then return end

	local model = npc:GetModel()
	local rig = rigs[model] or BuildRig(model)
	if not rig then return end

	rag:SetupBones()
	npc:SetupBones()

	local pelvis = Pose.Matrix(rag, BONE.pelvis)
	if not pelvis then return end

	-- The animation finishes facing `variant.endYaw` and the server turned the
	-- NPC to match (ZCNPC.PlanGetUp), so backing that rotation out of the NPC's
	-- angle is the direction the animation has to start in.
	local root = Matrix()
	root:SetAngles(Angle(0, npc:GetAngles().y - variant.endYaw, 0))
	root:SetTranslation(npc:GetPos())

	local first = Sample(rig, variant, 1, 1, 0, root, {})

	local offset = pelvis:GetTranslation() - first[1]:GetTranslation()
	if offset:LengthSqr() > ANCHOR_REACH * ANCHOR_REACH then
		offset = offset:GetNormalized() * ANCHOR_REACH
	end

	-- The model is drawn around the body while the entity itself stands somewhere
	-- else, and culling goes by the entity's bounds, not by where the bones ended
	-- up - without this the NPC blinks out of existence for most of the animation.
	local reach = offset:Length() + 48
	npc:SetRenderBounds(Vector(-reach, -reach, -reach), Vector(reach, reach, reach))

	local data = {
		rig = rig,
		variant = variant,
		rag = rag,
		yaw = root:GetAngles(),
		origin = root:GetTranslation(),
		offset = offset,
		down = Pose.Capture(rag),
		mats = {},
		pose = {},
		blend = {},
		stand = {},
	}

	-- from here on the NPC is the one being drawn in this pose
	ZCNPC.HideBody(rag)

	return data
end

local function Frame(npc)
	local data = playing[npc]
	if not data then return end

	local t = (CurTime() - data.start) / data.length

	if t >= 1 then
		ZCNPC.StopGetUp(npc, true)

		return
	end

	local variant = data.variant

	local root = Matrix()
	root:SetAngles(data.yaw)
	root:SetTranslation(data.origin + data.offset * (1 - Smooth(t)))

	local f = 1 + t * (variant.frames - 1)
	local a = math.floor(f)

	local mats = Sample(data.rig, variant, a, math.min(a + 1, variant.frames), f - a, root, data.mats)
	local pose = ToPose(data.rig, mats, npc, data.pose)

	if t < BLEND_IN then
		pose = Pose.Blend(pose, data.down, 1 - Smooth(t / BLEND_IN), data.blend)
	elseif t > 1 - BLEND_OUT then
		local stand = Pose.Capture(npc, data.stand)

		pose = Pose.Blend(pose, stand, Smooth((t - (1 - BLEND_OUT)) / BLEND_OUT), data.blend)
	end

	Pose.Apply(npc, pose)
end

-- finished: the animation ran its course, as opposed to being cut short. The body
-- is removed by the server a tenth of a second after the animation ends, so it
-- stays hidden either until that lands or until it is clear that it will not.
local LINGER = 2

function ZCNPC.StopGetUp(npc, finished)
	local data = playing[npc]
	if not data then return end

	playing[npc] = nil

	if IsValid(npc) then npc:SetRenderBounds(npc:OBBMins(), npc:OBBMaxs()) end

	if finished then
		ZCNPC.HideBody(data.rag, LINGER)
	else
		ZCNPC.ShowBody(data.rag)
	end
end

function ZCNPC.IsGettingUp(npc)
	return playing[npc] ~= nil
end

ZCNPC.AddPass(10, "getup", function(npc) return playing[npc] ~= nil end, Frame)
--//

--\\ Net
net.Receive("zcnpc_getup", function()
	local npcIndex = net.ReadUInt(16)
	local ragIndex = net.ReadUInt(16)
	local length = net.ReadFloat()
	local faceUp = net.ReadBool()

	if length <= 0 then return end

	ZCNPC.WaitEntities({ npc = npcIndex, rag = ragIndex }, function(ents)
		local npc = ents.npc

		ZCNPC.StopGetUp(npc)

		-- captured here rather than on the first frame we draw: the body is taken
		-- away on a timer and an NPC that stands up off screen would have nothing
		-- left to animate out of by the time it is looked at
		local data = Capture(npc, ents.rag, faceUp)
		if not data then
			-- Bone cache on the rag can miss for a frame after the body net message;
			-- try once more before giving up and popping the NPC upright.
			timer.Simple(0, function()
				if not (IsValid(npc) and IsValid(ents.rag)) then
					ZCNPC.ReleaseDraw(npc)
					return
				end

				data = Capture(npc, ents.rag, faceUp)
				if not data then
					ZCNPC.ReleaseDraw(npc)
					return
				end

				data.start, data.length = CurTime(), length
				playing[npc] = data
				ZCNPC.InstallRender(npc, true)
				ZCNPC.ReleaseDraw(npc)
			end)

			return
		end

		data.start, data.length = CurTime(), length
		playing[npc] = data

		ZCNPC.InstallRender(npc, true)
		ZCNPC.ReleaseDraw(npc) -- there is a pose to draw it in now
	end)
end)

hook.Add("EntityRemoved", "zcnpc_getup", function(ent)
	if playing[ent] then ZCNPC.StopGetUp(ent, false) end

	-- the body itself is only needed for the first frame, the animation runs on
	-- the pose copied out of it
	for _, data in pairs(playing) do
		if data.rag == ent then data.rag = nil end
	end
end)
--//
