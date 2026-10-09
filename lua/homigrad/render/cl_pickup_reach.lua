local IsValid, CurTime, Vector, LerpVector, LerpAngle, math_Clamp, math_sin, math_cos, math_max = IsValid, CurTime, Vector, LerpVector, LerpAngle, math.Clamp, math.sin, math.cos, math.max
local WorldToLocal, LocalToWorld = WorldToLocal, LocalToWorld

local REACH_TIME = 0.55
local WEAK_REACH_TIME = 0.95
local GRAB_FRACTION = 0.45
local GRAB_RADIUS = 3
local SETTLE_TIME = 0.06
local HANDOFF_BLEND = 0.35
local REACH_SPAN = 1.85
local WEAK_EXTENT = 0.65
local WEAK_SAG = 3
local WEAK_TREMOR = 0.6
local HAND_GRIP_OFFSET = 3.5
local CLEANUP_GRACE = 1.5
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

local function grabTime(reach)
	return reach.grabbedAt or reach.start + reach.outTime
end

local function reachIKEnd(reach)
	return grabTime(reach) + reach.backTime
end

local function ghostEnd(reach)
	if reach.select then return reach.select + reach.blend end

	return reachIKEnd(reach)
end

local function reachEnd(reach)
	return math_max(reachIKEnd(reach), ghostEnd(reach))
end

local function markGrab(reach, now, weight)
	if reach.grabbedAt then return end
	reach.grabbedAt = now
	reach.grabWeight = weight
end

local function reachWeight(reach, now)
	if not reach.grabbedAt then
		return math.ease.InOutSine(math_Clamp((now - reach.start) / reach.outTime, 0, 1))
	end

	return reach.grabWeight * math.ease.InOutSine(1 - math_Clamp((now - reach.grabbedAt) / reach.backTime, 0, 1))
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
	local reach = {
		side = side,
		weak = weak,
		entity = ent,
		skin = IsValid(ent) and ent:GetSkin() or 0,
		target = target,
		modelPos = modelPos,
		modelAng = modelAng,
		model = model ~= "" and util.IsValidModel(model) and model or nil,
		start = CurTime(),
		outTime = duration * GRAB_FRACTION,
		backTime = duration * (1 - GRAB_FRACTION),
	}
	ply.hgPickupReach = reach

	timer.Simple(duration + CLEANUP_GRACE, function()
		if IsValid(ply) and ply.hgPickupReach == reach and CurTime() >= reachEnd(reach) then clearReach(ply) end
	end)
end)

net.Receive("hg_pickup_handoff", function()
	local ply = net.ReadPlayer()
	local wep = net.ReadEntity()
	local selectDelay = net.ReadFloat()
	local reach = IsValid(ply) and ply.hgPickupReach
	if not reach or reach.entity ~= wep then return end

	reach.select = CurTime() + selectDelay
	reach.blend = IsValid(wep) and wep.isTPIKBase and 0 or HANDOFF_BLEND
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
	local distance = toItem:Length()
	local maxReach = forearmLength * REACH_SPAN * (reach.weak and WEAK_EXTENT or 1)
	if distance > 0 then toItem:Mul(math_Clamp(distance - HAND_GRIP_OFFSET, 0, maxReach) / distance) end

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

	local now = CurTime()
	if now >= reachEnd(reach) then
		clearReach(ply)

		return
	end
	if now >= reachIKEnd(reach) or not IsValid(wpn) then return end

	local hand = HANDS[reach.side]
	local handBone = ent:LookupBone(hand.hand)
	local handMat = handBone and ent:GetBoneMatrix(handBone)
	if not handMat then return end

	local weight = reachWeight(reach, now)
	local goal = reachGoal(ent, ply, reach, hand, weight)
	if not goal then return end

	local hold = reach.side == "left" and ply.lhold or ply.rhold
	local base = hold and hold:GetTranslation() or handMat:GetTranslation()
	local pos = LerpVector(weight, base, goal)
	if hold then hold:SetTranslation(pos) end

	if weight >= 1 or pos:DistToSqr(goal) <= GRAB_RADIUS * GRAB_RADIUS then markGrab(reach, now, weight) end

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

local function heldTransform(ent, reach)
	local handBone = ent:LookupBone(HANDS[reach.side].hand)
	local handMat = handBone and ent:GetBoneMatrix(handBone)
	if not handMat then return end
	local handPos, handAng = handMat:GetTranslation(), handMat:GetAngles()

	if not reach.gripAng then
		local _, localAng = WorldToLocal(reach.modelPos, reach.modelAng, handPos, handAng)
		reach.gripAng = localAng
	end

	local _, heldAng = LocalToWorld(vector_origin, reach.gripAng, handPos, handAng)
	local grip = LocalToWorld(Vector(HAND_GRIP_OFFSET, 0, 0), angle_zero, handPos, handAng)
	local heldPos = LocalToWorld(-reach.ghost:OBBCenter(), angle_zero, grip, heldAng)

	return heldPos, heldAng
end

local function blendToReal(reach, pos, ang, now)
	local real = IsValid(reach.entity) and reach.entity.worldModel
	if not reach.select or now <= reach.select or reach.blend <= 0 or not IsValid(real) or real:GetModel() ~= reach.ghost:GetModel() then return pos, ang end

	local ghost = reach.ghost
	ghost:SetRenderOrigin(pos)
	ghost:SetRenderAngles(ang)
	ghost:SetupBones()
	real:SetupBones()
	local gm, rm = ghost:GetBoneMatrix(0), real:GetBoneMatrix(0)
	if not gm or not rm then return pos, ang end

	local op, oa = WorldToLocal(gm:GetTranslation(), gm:GetAngles(), pos, ang)
	local ip, ia = WorldToLocal(vector_origin, angle_zero, op, oa)
	local tpos, tang = LocalToWorld(ip, ia, rm:GetTranslation(), rm:GetAngles())
	local frac = math.ease.InOutSine(math_Clamp((now - reach.select) / reach.blend, 0, 1))
	ghost:SetModelScale(Lerp(frac, 1, real:GetModelScale()))

	return LerpVector(frac, pos, tpos), LerpAngle(frac, ang, tang)
end

local function ghostTransform(ent, reach, now)
	if now < grabTime(reach) then return reach.modelPos, reach.modelAng end
	markGrab(reach, now, 1)

	local heldPos, heldAng = heldTransform(ent, reach)
	if not heldPos then return reach.modelPos, reach.modelAng end

	local settle = math.ease.OutQuad(math_Clamp((now - reach.grabbedAt) / SETTLE_TIME, 0, 1))
	local pos, ang = LerpVector(settle, reach.modelPos, heldPos), LerpAngle(settle, reach.modelAng, heldAng)

	return blendToReal(reach, pos, ang, now)
end

function hg.PickupHandoffHides(ply, wep)
	local reach = ply.hgPickupReach

	return reach ~= nil and reach.entity == wep and ghostNeeded(reach) and CurTime() < ghostEnd(reach)
end

function hg.DrawPickupHandoff(ent, ply)
	local reach = ply.hgPickupReach
	if not reach or ent ~= ply then return end

	local now = CurTime()
	if now >= reachEnd(reach) then
		clearReach(ply)

		return
	end
	if now >= ghostEnd(reach) or not ghostNeeded(reach) then
		removeGhost(reach)

		return
	end

	if not IsValid(reach.ghost) then
		reach.ghost = ClientsideModel(reach.model, RENDERGROUP_OPAQUE)
		if not IsValid(reach.ghost) then
			reach.model = nil

			return
		end
		reach.ghost:SetNoDraw(true)
		reach.ghost:SetSkin(reach.skin)
	end

	local pos, ang = ghostTransform(ent, reach, now)
	reach.ghost:SetRenderOrigin(pos)
	reach.ghost:SetRenderAngles(ang)
	reach.ghost:SetupBones()
	reach.ghost:DrawModel()
end
