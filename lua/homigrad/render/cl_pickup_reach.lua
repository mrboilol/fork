local IsValid, CurTime, Vector, LerpVector, LerpAngle, math_Clamp, math_sin, math_cos, math_max = IsValid, CurTime, Vector, LerpVector, LerpAngle, math.Clamp, math.sin, math.cos, math.max
local WorldToLocal, LocalToWorld = WorldToLocal, LocalToWorld

local REACH_TIME = 0.55
local WEAK_REACH_TIME = 0.95
local GRAB_FRACTION = 0.5
local HOVER_FRACTION = 0.5
local HANDOFF_BLEND = 0.35
local REACH_SPAN = 1.95
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

local function resolveItemVisual(ent, model, pos, ang)
	if not IsValid(ent) then return model, pos, ang end

	local fake = ent.WorldModelFake
	if isstring(fake) and util.IsValidModel(fake) then
		if ent.FakePos and ent.FakeAng then pos, ang = LocalToWorld(ent.FakePos, ent.FakeAng, pos, ang) end

		return fake, pos, ang, ent.FakeScale
	end

	local exchange = ent.WorldModelExchange
	if isstring(exchange) and util.IsValidModel(exchange) then return exchange, pos, ang, ent.modelscale end

	return model, pos, ang
end

net.Receive("HG_PickupReach", function()
	local ply = net.ReadEntity()
	local ent = net.ReadEntity()
	local target = net.ReadVector()
	local modelPos = net.ReadVector()
	local modelAng = net.ReadAngle()
	local model = net.ReadString()
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local scale
	model, modelPos, modelAng, scale = resolveItemVisual(ent, model, modelPos, modelAng)

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
		scale = scale or 1,
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

local function dressGhost(reach)
	local ghost, item = reach.ghost, reach.entity
	ghost:SetSkin(reach.skin)
	ghost:SetModelScale(reach.scale, 0)
	if not IsValid(item) then return end

	for i = 0, 6 do
		ghost:SetBodygroup(i, item:GetBodygroup(i))
	end

	if item.WorldModelFake ~= ghost:GetModel() then return end
	if item.FakeBodyGroups then ghost:SetBodyGroups(item.FakeBodyGroups) end

	local idle = item.AnimList and item.AnimList.idle or "idle"
	local sequence = isstring(idle) and ghost:LookupSequence(idle) or idle
	if isnumber(sequence) and sequence >= 0 then ghost:SetSequence(sequence) end
end

local function ensureGhost(reach)
	if IsValid(reach.ghost) then return reach.ghost end
	if not reach.model then return end

	local ghost = ClientsideModel(reach.model, RENDERGROUP_OPAQUE)
	if not IsValid(ghost) then
		reach.model = nil

		return
	end

	ghost:SetNoDraw(true)
	reach.ghost = ghost
	dressGhost(reach)

	return ghost
end

local function aimAngle(ang, dir)
	local fwd = ang:Forward()
	dir = dir:GetNormalized()
	local axis = fwd:Cross(dir)
	local sine = axis:Length()
	local out = Angle(ang.p, ang.y, ang.r)
	if sine < 0.0001 then return out end

	out:RotateAroundAxis(axis / sine, math.deg(math.atan2(sine, fwd:Dot(dir))))

	return out
end

local function fakeGrip(reach, item)
	if not IsValid(item) or not reach.model or reach.model ~= item.WorldModelFake then return end

	local ghost = ensureGhost(reach)
	local bone = ghost and ghost:LookupBone(HANDS[reach.side].hand)
	if not bone then return end

	ghost:SetRenderOrigin(vector_origin)
	ghost:SetRenderAngles(angle_zero)
	ghost:InvalidateBoneCache()
	ghost:SetupBones()
	local mat = ghost:GetBoneMatrix(bone)
	if mat then return mat:GetTranslation(), mat:GetAngles() end
end

local function swepGrip(reach, item)
	if not IsValid(item) or not item.WorldPos or not item.LHPos then return end

	local frame = Vector(0, 0, -1)
	local handPos, handAng
	if reach.side == "left" then
		local lhang = Angle(0, 0, 0)
		lhang:RotateAroundAxis(lhang:Forward(), -90)
		handPos, handAng = LocalToWorld(item.LHPos, item.LHAng or angle_zero, frame, lhang)
		handPos, handAng = LocalToWorld(item.LHPosOffset or vector_origin, item.LHAngOffset or angle_zero, handPos, handAng)
	else
		handPos, handAng = LocalToWorld(item.RHPosOffset or vector_origin, item.RHAngOffset or angle_zero, frame, angle_zero)
	end

	local modelPos, modelAng = LocalToWorld(item.WorldPos, (item.WorldAng or angle_zero) + (item.WorldAng2 or angle_zero), vector_origin, angle_zero)
	modelAng:RotateAroundAxis(modelAng:Forward(), 180)
	if reach.model and reach.model == item.WorldModelFake and item.FakePos and item.FakeAng then
		modelPos, modelAng = LocalToWorld(item.FakePos, item.FakeAng, modelPos, modelAng)
	end

	return WorldToLocal(handPos, handAng, modelPos, modelAng)
end

local function fallbackGrip(reach, ent)
	local hand = HANDS[reach.side]
	local handBone = ent:LookupBone(hand.hand)
	local handMat = handBone and ent:GetBoneMatrix(handBone)
	if not handMat then return end

	local shoulderBone = ent:LookupBone(hand.upperArm)
	local shoulderMat = shoulderBone and ent:GetBoneMatrix(shoulderBone)
	local origin = shoulderMat and shoulderMat:GetTranslation() or handMat:GetTranslation()
	local aim = aimAngle(handMat:GetAngles(), reach.target - origin)

	return WorldToLocal(reach.target - aim:Forward() * HAND_GRIP_OFFSET, aim, reach.modelPos, reach.modelAng)
end

local function ensureGrip(reach, ent)
	if reach.handInModelPos then return true end

	local item = reach.entity
	local pos, ang = fakeGrip(reach, item)
	if not pos then pos, ang = swepGrip(reach, item) end
	if not pos then pos, ang = fallbackGrip(reach, ent) end
	if not pos then return false end

	reach.handInModelPos, reach.handInModelAng = pos, ang
	reach.modelInHandPos, reach.modelInHandAng = WorldToLocal(vector_origin, angle_zero, pos, ang)

	return true
end

local function reachGoal(ent, ply, reach, hand, weight)
	local shoulderBone = ent:LookupBone(hand.upperArm)
	local shoulderMat = shoulderBone and ent:GetBoneMatrix(shoulderBone)
	if not shoulderMat then return end

	local forearm = ent:LookupBone(hand.forearm)
	local forearmLength = forearm and ply:BoneLength(forearm) or 0
	if forearmLength <= 0 then forearmLength = DEFAULT_FOREARM_LENGTH end

	local goal, goalAng = LocalToWorld(reach.handInModelPos, reach.handInModelAng, reach.modelPos, reach.modelAng)
	local shoulder = shoulderMat:GetTranslation()
	local toGoal = goal - shoulder
	local distance = toGoal:Length()
	local maxReach = forearmLength * REACH_SPAN * (reach.weak and WEAK_EXTENT or 1)
	if distance > maxReach then goal = shoulder + toGoal * (maxReach / distance) end

	if reach.weak then
		local now = CurTime()
		local tremor = Vector(math_sin(now * 23), math_cos(now * 19), math_sin(now * 29)) * WEAK_TREMOR
		goal = goal + (tremor - vector_up * WEAK_SAG) * weight
	end

	return goal, goalAng
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
	if not handMat or not ensureGrip(reach, ent) then return end

	local weight = reachWeight(reach, now)
	local goal, goalAng = reachGoal(ent, ply, reach, hand, weight)
	if not goal then return end

	local hold = reach.side == "left" and ply.lhold or ply.rhold
	local base = hold and hold:GetTranslation() or handMat:GetTranslation()
	local baseAng = hold and hold:GetAngles() or handMat:GetAngles()
	local pos, ang = LerpVector(weight, base, goal), LerpAngle(weight, baseAng, goalAng)
	if hold then
		hold:SetTranslation(pos)
		hold:SetAngles(ang)
	end

	if weight >= 1 then markGrab(reach, now, weight) end

	if reach.side == "left" then
		ply.hgPickupReachLeft = true
		hg.DragLeftHand_Ex(ent, wpn, pos, ang)

		return
	end

	handMat:SetTranslation(pos)
	handMat:SetAngles(ang)
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
	if not handMat or not ensureGrip(reach, ent) then return end

	return LocalToWorld(reach.modelInHandPos, reach.modelInHandAng, handMat:GetTranslation(), handMat:GetAngles())
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
	ghost:SetModelScale(Lerp(frac, reach.scale, real:GetModelScale()))

	return LerpVector(frac, pos, tpos), LerpAngle(frac, ang, tang)
end

local function ghostTransform(ent, reach, now)
	local heldPos, heldAng = heldTransform(ent, reach)
	if not heldPos then return reach.modelPos, reach.modelAng end

	local grab = grabTime(reach)
	if now < grab then
		local hoverStart = reach.start + reach.outTime * (1 - HOVER_FRACTION)
		local hover = math.ease.InOutSine(math_Clamp((now - hoverStart) / math_max(grab - hoverStart, 0.001), 0, 1))

		return LerpVector(hover, reach.modelPos, heldPos), LerpAngle(hover, reach.modelAng, heldAng)
	end
	markGrab(reach, now, 1)

	return blendToReal(reach, heldPos, heldAng, now)
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

	if not ensureGhost(reach) then return end

	local pos, ang = ghostTransform(ent, reach, now)
	reach.ghost:SetRenderOrigin(pos)
	reach.ghost:SetRenderAngles(ang)
	reach.ghost:SetupBones()
	reach.ghost:DrawModel()
end
