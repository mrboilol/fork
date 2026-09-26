--[[
	Bone posing helpers shared by the client side features (get up animation,
	handcuff pose). Everything here works in world space on bone matrices, the
	same way Z-City poses players in hg.bone_apply_matrix / hg.SmoothUnfake.
]]

ZCNPC = ZCNPC or {}

ZCNPC.Bone = {
	pelvis = "ValveBiped.Bip01_Pelvis",
	spine = "ValveBiped.Bip01_Spine",
	spine1 = "ValveBiped.Bip01_Spine1",
	spine2 = "ValveBiped.Bip01_Spine2",
	spine4 = "ValveBiped.Bip01_Spine4",
	neck = "ValveBiped.Bip01_Neck1",
	head = "ValveBiped.Bip01_Head1",
	l_upperarm = "ValveBiped.Bip01_L_UpperArm",
	l_forearm = "ValveBiped.Bip01_L_Forearm",
	l_hand = "ValveBiped.Bip01_L_Hand",
	r_upperarm = "ValveBiped.Bip01_R_UpperArm",
	r_forearm = "ValveBiped.Bip01_R_Forearm",
	r_hand = "ValveBiped.Bip01_R_Hand",
	l_thigh = "ValveBiped.Bip01_L_Thigh",
	l_calf = "ValveBiped.Bip01_L_Calf",
	l_foot = "ValveBiped.Bip01_L_Foot",
	r_thigh = "ValveBiped.Bip01_R_Thigh",
	r_calf = "ValveBiped.Bip01_R_Calf",
	r_foot = "ValveBiped.Bip01_R_Foot",
}

local BONE = ZCNPC.Bone
local Pose = {}
ZCNPC.Pose = Pose

--\\ Basics
function Pose.Matrix(ent, name)
	local bone = ent:LookupBone(name)

	return bone and ent:GetBoneMatrix(bone)
end

-- ValveBiped limb bones run along their own +X axis towards the child bone
-- (Z-City relies on the same thing: it places amputation stumps at
-- Vector(BoneLength(bone), 0, 0) in bone space, sv_input.lua:170).
-- So aiming a bone means rotating its Forward onto `dir` - and doing that with
-- the shortest possible rotation keeps whatever twist the animation gave it.
function Pose.Aim(ang, dir)
	local forward = ang:Forward()
	local dot = math.Clamp(forward:Dot(dir), -1, 1)
	if dot > 0.99999 then return ang end

	local axis = forward:Cross(dir)
	if axis:LengthSqr() < 1e-9 then
		axis = ang:Up() -- exactly backwards: any perpendicular axis will do
	end
	axis:Normalize()

	local out = Angle(ang[1], ang[2], ang[3])
	out:RotateAroundAxis(axis, math.deg(math.acos(dot)))

	return out
end
--//

--\\ Two bone IK (shoulder -> elbow -> hand, hip -> knee -> foot)
-- poleTarget decides which way the joint bends: the elbow/knee ends up on the
-- side of the root-to-target line that this point sits on.
-- tipAng, when given, is the orientation the hand/foot is left in.
function Pose.SolveLimb(ent, upperName, lowerName, tipName, targetPos, poleTarget, tipAng)
	local upper, lower = ent:LookupBone(upperName), ent:LookupBone(lowerName)
	local tip = ent:LookupBone(tipName)
	if not (upper and lower and tip) then return false end

	local upperMat, lowerMat, tipMat = ent:GetBoneMatrix(upper), ent:GetBoneMatrix(lower), ent:GetBoneMatrix(tip)
	if not (upperMat and lowerMat and tipMat) then return false end

	local root, joint = upperMat:GetTranslation(), lowerMat:GetTranslation()
	local len1, len2 = root:Distance(joint), joint:Distance(tipMat:GetTranslation())
	if len1 < 0.01 or len2 < 0.01 then return false end

	local toTarget = targetPos - root
	local reach = toTarget:Length()
	if reach < 0.01 then return false end

	local dir = toTarget / reach
	reach = math.Clamp(reach, math.abs(len1 - len2) + 0.01, len1 + len2 - 0.01)

	-- circle intersection: distance along dir to the joint's projection, plus its offset
	local along = (len1 * len1 - len2 * len2 + reach * reach) / (2 * reach)
	local offset = math.sqrt(math.max(len1 * len1 - along * along, 0))

	local pole = poleTarget - root
	pole = pole - dir * pole:Dot(dir)
	if pole:LengthSqr() < 1e-6 then -- pole lies on the aim line, keep the current bend
		pole = joint - root
		pole = pole - dir * pole:Dot(dir)
	end
	if pole:LengthSqr() < 1e-6 then return false end
	pole:Normalize()

	local newJoint = root + dir * along + pole * offset

	local mat = Matrix()
	mat:SetAngles(Pose.Aim(upperMat:GetAngles(), (newJoint - root):GetNormalized()))
	mat:SetTranslation(root)
	mat:SetScale(upperMat:GetScale())
	hg.bone_apply_matrix(ent, upper, mat)

	-- the forearm rode along with the upper arm, so it is already at newJoint
	local lowerMat2 = ent:GetBoneMatrix(lower)
	if not lowerMat2 then return false end

	local newTip = root + dir * reach

	local mat2 = Matrix()
	mat2:SetAngles(Pose.Aim(lowerMat2:GetAngles(), (newTip - newJoint):GetNormalized()))
	mat2:SetTranslation(newJoint)
	mat2:SetScale(lowerMat2:GetScale())
	hg.bone_apply_matrix(ent, lower, mat2)

	if tipAng then
		local tipMat2 = ent:GetBoneMatrix(tip)
		if tipMat2 then
			local mat3 = Matrix()
			mat3:SetAngles(tipAng)
			mat3:SetTranslation(tipMat2:GetTranslation())
			mat3:SetScale(tipMat2:GetScale())
			hg.bone_apply_matrix(ent, tip, mat3)
		end
	end

	return true
end
--//

--\\ Whole skeleton poses
-- A "pose" here is a plain array of world space bone matrices, indexed by bone.

function Pose.Capture(ent, out)
	out = out or {}

	for bone = 0, ent:GetBoneCount() - 1 do
		out[bone] = ent:GetBoneMatrix(bone)
	end

	return out
end

function Pose.Apply(ent, pose)
	for bone = 0, ent:GetBoneCount() - 1 do
		local mat = pose[bone]
		if mat then ent:SetBoneMatrix(bone, mat) end
	end
end

-- Rigidly moves a whole pose by a transform expressed around `pivot`.
function Pose.Transform(pose, pivot, ang, translation, out)
	out = out or {}

	local frame = Matrix()
	frame:SetAngles(ang)
	frame:SetTranslation(pivot + translation)

	local inverse = Matrix()
	inverse:SetTranslation(-pivot)

	local transform = frame * inverse

	for bone, mat in pairs(pose) do
		out[bone] = transform * mat
	end

	return out
end

local function BlendAngles(from, to, k)
	if isfunction(Quaternion) then -- Z-City ships a quaternion library (sh_quaternions.lua)
		local a, b = Quaternion(), Quaternion()
		a:SetMatrix(from)
		b:SetMatrix(to)

		return a:SLerp(b, k):Angle()
	end

	return LerpAngle(k, from:GetAngles(), to:GetAngles())
end

Pose.BlendAngles = BlendAngles

function Pose.Blend(from, to, k, out)
	out = out or {}

	for bone, a in pairs(from) do
		local b = to[bone]
		if not b then out[bone] = a continue end

		local mat = Matrix()
		mat:SetTranslation(LerpVector(k, a:GetTranslation(), b:GetTranslation()))
		mat:SetAngles(BlendAngles(a, b, k))
		mat:SetScale(b:GetScale())

		out[bone] = mat
	end

	return out
end

-- Lowest point of the bones that are expected to carry the body, used to drop a
-- constructed pose onto the floor instead of guessing height offsets.
local groundBones = {
	BONE.l_foot, BONE.r_foot,
	BONE.l_calf, BONE.r_calf,
	BONE.l_hand, BONE.r_hand,
	BONE.pelvis, BONE.spine, BONE.head,
}

function Pose.Ground(ent, pose, groundZ)
	local lowest

	for _, name in ipairs(groundBones) do
		local bone = ent:LookupBone(name)
		local mat = bone and pose[bone]
		if not mat then continue end

		local z = mat:GetTranslation().z
		if not lowest or z < lowest then lowest = z end
	end

	if not lowest then return pose end

	local shift = groundZ - lowest
	if math.abs(shift) < 0.05 then return pose end

	local up = Vector(0, 0, shift)
	for bone, mat in pairs(pose) do
		local moved = Matrix()
		moved:SetAngles(mat:GetAngles())
		moved:SetTranslation(mat:GetTranslation() + up)
		moved:SetScale(mat:GetScale())

		pose[bone] = moved
	end

	return pose
end
--//

--\\ Reference model: a hidden copy of the NPC's model used to read poses out of
-- sequences the NPC itself is not playing right now (the same trick ZManip uses
-- to source custom animations, cl_zmanip.lua:138).
local reference

local function Reference(model)
	if not IsValid(reference) then
		reference = ClientsideModel(model, RENDERGROUP_OPAQUE)
		if not IsValid(reference) then return end

		reference:SetNoDraw(true)
	elseif reference:GetModel() ~= model then
		reference:SetModel(model)
	end

	reference:SetPos(vector_origin)
	reference:SetAngles(angle_zero)

	return reference
end

-- Sitting at the origin facing +X, so everything read off it is in model space.
-- Handed out for the get up rig, which needs a model's rest proportions rather
-- than a pose.
Pose.Reference = Reference

-- Names first, because a model that ships an animation under an explicit name means
-- it; then the activities, which is where the stock Half-Life 2 humans answer.
local function FindSequence(ent, names, acts)
	for _, name in ipairs(names or {}) do
		local id = ent:LookupSequence(name)
		if id and id > 0 then return id end
	end

	for _, act in ipairs(acts or {}) do
		local id = ent:SelectWeightedSequence(act)
		if id and id > 0 then return id end
	end
end

-- Model space (origin at the entity's feet, facing +X) pose of a sequence.
-- `names` are tried in order, then `acts`; nil when the model has neither.
function Pose.FromSequence(model, names, acts, cycle)
	local ent = Reference(model)
	if not ent then return end

	local seq = FindSequence(ent, names, acts)
	if not seq then return end

	ent:ResetSequence(seq)
	ent:SetCycle(cycle or 0)
	ent:SetPlaybackRate(0)
	ent:InvalidateBoneCache()
	ent:SetupBones()

	return Pose.Capture(ent), seq
end

-- The same thing `count` times, spread evenly over the sequence, plus how many
-- seconds it takes to get through them. Which is what makes a held frame into an
-- animation: read once per model and interpolated between at draw time, so a
-- crouch that breathes costs one blend a frame rather than driving a hidden copy
-- of the model through ResetSequence and SetupBones on every one of them.
--
-- Deliberately not the whole animation. A sampled frame is a keyframe whatever the
-- source was, and a dozen of them across a two second idle is finer than anybody
-- authored it at - what is lost is the exact easing between two of Valve's own
-- keys, and what is gained is being able to afford to play it at all.
function Pose.SampleSequence(model, names, acts, count)
	local ent = Reference(model)
	if not ent then return end

	local seq = FindSequence(ent, names, acts)
	if not seq then return end

	count = math.max(count or 8, 2)

	ent:ResetSequence(seq)
	ent:SetPlaybackRate(0)

	local frames = {}

	for i = 1, count do
		-- One short of the end on the last frame: a looping idle's last frame is its
		-- first one, and two identical keys in a row is a hitch in the loop.
		ent:SetCycle((i - 1) / count)
		ent:InvalidateBoneCache()
		ent:SetupBones()

		frames[i] = Pose.Capture(ent)
	end

	local duration = ent:SequenceDuration(seq)
	if not (isnumber(duration) and duration > 0.05) then duration = 1 end

	return { frames = frames, count = count, duration = duration }
end
--//
