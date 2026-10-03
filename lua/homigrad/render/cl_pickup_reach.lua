local IsValid, CurTime, Vector, LerpVector, LerpAngle, math_Clamp, math_sin, math_cos = IsValid, CurTime, Vector, LerpVector, LerpAngle, math.Clamp, math.sin, math.cos
local WorldToLocal, LocalToWorld = WorldToLocal, LocalToWorld

local REACH_TIME = 0.55
local WEAK_REACH_TIME = 0.95
local GRAB_FRACTION = 0.45
local SETTLE_FRACTION = 0.12
local REACH_SPAN = 1.85
local WEAK_EXTENT = 0.65
local WEAK_SAG = 3
local WEAK_TREMOR = 0.6
local HAND_GRIP_OFFSET = 4
local GHOST_CLEANUP_GRACE = 1
local DEFAULT_FOREARM_LENGTH = 12

local HANDS = {
	left = {
		hand = "ValveBiped.Bip01_L_Hand",
		upperArm = "ValveBiped.Bip01_L_UpperArm",
		forearm = "ValveBiped.Bip01_L_Forearm",
		arm = "larm",
		gone = {"larmamputated", "lhandamputated", "larmupamputated"},
	},
	right = {
		hand = "ValveBiped.Bip01_R_Hand",
		upperArm = "ValveBiped.Bip01_R_UpperArm",
		forearm = "ValveBiped.Bip01_R_Forearm",
		arm = "rarm",
		gone = {"rarmamputated", "rhandamputated", "rarmupamputated"},
	},
}

local function armGone(org, side)
	for _, key in ipairs(HANDS[side].gone) do
		if org[key] then return true end
	end

	return false
end

local function armWeak(org, side)
	local arm = HANDS[side].arm

	return (tonumber(org[arm]) or 0) > 0 or org[arm .. "dislocation"] or org[arm .. "dislocated"] or false
end

local function chooseHand(ply)
	local org = ply.organism or {}
	if not armGone(org, "left") then return "left", armWeak(org, "left") end
	if not armGone(org, "right") then return "right", armWeak(org, "right") end
end

local function removeGhost(reach)
	if IsValid(reach.ghost) then reach.ghost:Remove() end
	reach.ghost = nil
end

local function clearReach(ply)
	local reach = ply.hgPickupReach
	if reach then removeGhost(reach) end
	ply.hgPickupReach = nil
	ply.hgPickupReachLeft = nil
end

local function reachProgress(reach)
	return (CurTime() - reach.start) / reach.duration
end

local function reachWeight(t)
	if t < GRAB_FRACTION then return math.ease.InOutSine(t / GRAB_FRACTION) end

	return math.ease.InOutSine(1 - (t - GRAB_FRACTION) / (1 - GRAB_FRACTION))
end

net.Receive("HG_PickupReach", function()
	local ply = net.ReadEntity()
	local ent = net.ReadEntity()
	local target = net.ReadVector()
	local modelPos = net.ReadVector()
	local modelAng = net.ReadAngle()
	local model = net.ReadString()
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local side, weak = chooseHand(ply)
	clearReach(ply)
	if not side then return end

	local duration = weak and WEAK_REACH_TIME or REACH_TIME
	ply.hgPickupReach = {
		side = side,
		weak = weak,
		entity = ent,
		target = target,
		modelPos = modelPos,
		modelAng = modelAng,
		model = model ~= "" and util.IsValidModel(model) and model or nil,
		start = CurTime(),
		duration = duration,
	}

	timer.Simple(duration + GHOST_CLEANUP_GRACE, function()
		if IsValid(ply) and ply.hgPickupReach and reachProgress(ply.hgPickupReach) >= 1 then clearReach(ply) end
	end)
end)

local function reachGoal(ent, ply, reach, hand, weight)
	local shoulderBone = ent:LookupBone(hand.upperArm)
	local shoulderMat = shoulderBone and ent:GetBoneMatrix(shoulderBone)
	if not shoulderMat then return end

	local forearm = ent:LookupBone(hand.forearm)
	local forearmLength = forearm and ply:BoneLength(forearm) or 0
	if forearmLength <= 0 then forearmLength = DEFAULT_FOREARM_LENGTH end

	local shoulder = shoulderMat:GetTranslation()
	local toItem = reach.target - shoulder
	local maxReach = forearmLength * REACH_SPAN * (reach.weak and WEAK_EXTENT or 1)
	if toItem:LengthSqr() > maxReach * maxReach then
		toItem:Normalize()
		toItem:Mul(maxReach)
	end

	local goal = shoulder + toItem
	if reach.weak then
		local now = CurTime()
		local tremor = Vector(math_sin(now * 23), math_cos(now * 19), math_sin(now * 29)) * WEAK_TREMOR
		goal = goal + (tremor - vector_up * WEAK_SAG) * weight
	end

	return goal
end

function hg.PickupReachTPIK(ent, ply, wpn)
	ply.hgPickupReachLeft = nil
	local reach = ply.hgPickupReach
	if not reach then return end
	if ent ~= ply or IsValid(ply.FakeRagdoll) or not ply:Alive() then
		clearReach(ply)

		return
	end

	local t = reachProgress(reach)
	if t >= 1 then
		clearReach(ply)

		return
	end
	if not IsValid(wpn) then return end

	local hand = HANDS[reach.side]
	local handBone = ent:LookupBone(hand.hand)
	local handMat = handBone and ent:GetBoneMatrix(handBone)
	if not handMat then return end

	local weight = reachWeight(t)
	local goal = reachGoal(ent, ply, reach, hand, weight)
	if not goal then return end

	local hold = reach.side == "left" and ply.lhold or ply.rhold
	local base = hold and hold:GetTranslation() or handMat:GetTranslation()
	local pos = LerpVector(weight, base, goal)
	if hold then hold:SetTranslation(pos) end

	if reach.side == "left" then
		ply.hgPickupReachLeft = true
		hg.DragLeftHand_Ex(ent, wpn, pos, handMat:GetAngles())

		return
	end

	handMat:SetTranslation(pos)
	hg.bone_apply_matrix(ent, handBone, handMat)
	wpn.rhandik = true
end

local function ghostNeeded(reach)
	local item = reach.entity

	return reach.model and (not IsValid(item) or IsValid(item:GetOwner()) or item:GetNoDraw())
end

local function ghostTransform(ent, reach, t)
	if t < GRAB_FRACTION then return reach.modelPos, reach.modelAng end

	local handBone = ent:LookupBone(HANDS[reach.side].hand)
	local handMat = handBone and ent:GetBoneMatrix(handBone)
	if not handMat then return reach.modelPos, reach.modelAng end
	local handPos, handAng = handMat:GetTranslation(), handMat:GetAngles()

	if not reach.gripAng then
		local _, localAng = WorldToLocal(reach.modelPos, reach.modelAng, handPos, handAng)
		reach.gripAng = localAng
	end

	local heldPos, heldAng = LocalToWorld(Vector(HAND_GRIP_OFFSET, 0, 0), reach.gripAng, handPos, handAng)
	local settle = math_Clamp((t - GRAB_FRACTION) / SETTLE_FRACTION, 0, 1)

	return LerpVector(settle, reach.modelPos, heldPos), LerpAngle(settle, reach.modelAng, heldAng)
end

function hg.PickupHandoffHides(ply, wep)
	local reach = ply.hgPickupReach

	return reach ~= nil and reach.entity == wep and ghostNeeded(reach) and reachProgress(reach) < 1
end

function hg.DrawPickupHandoff(ent, ply)
	local reach = ply.hgPickupReach
	if not reach or ent ~= ply or not ghostNeeded(reach) then return end

	local t = reachProgress(reach)
	if t >= 1 then return end

	if not IsValid(reach.ghost) then
		reach.ghost = ClientsideModel(reach.model, RENDERGROUP_OPAQUE)
		if not IsValid(reach.ghost) then
			reach.model = nil

			return
		end
		reach.ghost:SetNoDraw(true)
	end

	local pos, ang = ghostTransform(ent, reach, t)
	reach.ghost:SetPos(pos)
	reach.ghost:SetAngles(ang)
	reach.ghost:SetupBones()
	reach.ghost:DrawModel()
end
