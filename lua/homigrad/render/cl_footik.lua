local IsValid, Vector, Angle, Matrix, Lerp, LerpVector, FrameTime, FrameNumber, CurTime = IsValid, Vector, Angle, Matrix, Lerp, LerpVector, FrameTime, FrameNumber, CurTime
local WorldToLocal, LocalToWorld = WorldToLocal, LocalToWorld
local math_Clamp, math_max, math_min, math_abs, math_sqrt, math_sin, math_exp, math_floor = math.Clamp, math.max, math.min, math.abs, math.sqrt, math.sin, math.exp, math.floor
local math_AngleDifference = math.AngleDifference

IKFoot = IKFoot or {}

local LEGS = {
	{
		sign = -1,
		thigh = "ValveBiped.Bip01_L_Thigh",
		calf = "ValveBiped.Bip01_L_Calf",
		foot = "ValveBiped.Bip01_L_Foot",
		toe = "ValveBiped.Bip01_L_Toe0",
		amputated = "llegamputated",
		amputatedUpper = "llegupamputated",
	},
	{
		sign = 1,
		thigh = "ValveBiped.Bip01_R_Thigh",
		calf = "ValveBiped.Bip01_R_Calf",
		foot = "ValveBiped.Bip01_R_Foot",
		toe = "ValveBiped.Bip01_R_Toe0",
		amputated = "rlegamputated",
		amputatedUpper = "rlegupamputated",
	},
}

local GROUND_TRACE_UP = 22
local GROUND_TRACE_DOWN = 32
local WALL_TRACE_HEIGHT = 10
local WALL_BACKOFF = 4
local WALKABLE_NORMAL_Z = 0.6
local RETRACE_DIST_SQR = 16
local TARGET_SMOOTH = 14
local MOVING_SPEED = 12
local REACH_FRACTION = 0.97
local OVERREACH_FRACTION = 0.9
local LANDING_SPREAD_FRACTION = 0.8
local SETTLE_SWING_TIME = 0.28
local SETTLE_COOLDOWN = 0.12
local PHASE_CORRECTION = 8
local DROP_SMOOTH = 10
local TOE_HEIGHT = 1
local MAX_TOE_DROP = 0.9
local MIN_ANKLE_HEIGHT = 1.5
local MAX_ANKLE_HEIGHT = 8
local ANKLE_LEARN_RATE = 2
local MIN_HALF_WIDTH = 2.5
local MAX_HALF_WIDTH = 9
local DROP_DEADZONE = 2
local DROP_TERRAIN_SCALE = 0.8
local CROUCH_DROP_SCALE = 0.3
local POLE_FORWARD_BIAS = 4
local MIN_LATERAL_FRACTION = 0.5
local LEDGE_SEARCH = {0.6, 0.3}
local LIMP_STRIDE_CUT = 0.35
local LIMP_DRAG = 0.6
local LIMP_DIP = 2.5
local DEBUG_BOX = Vector(1.5, 1.5, 1.5)
local DEBUG_PLANTED = Color(60, 255, 60)
local DEBUG_SWING = Color(255, 200, 60)

local groundHullMins, groundHullMaxs = Vector(-2, -2, 0), Vector(2, 2, 1)
local boneCache = {}

local function getBones(ply)
	local model = ply:GetModel()
	local cached = boneCache[model]
	if cached ~= nil then return cached end

	local bones = {pelvis = ply:LookupBone("ValveBiped.Bip01_Pelvis"), legs = {}}
	for i, leg in ipairs(LEGS) do
		local thigh, calf, foot = ply:LookupBone(leg.thigh), ply:LookupBone(leg.calf), ply:LookupBone(leg.foot)
		if not (thigh and calf and foot and bones.pelvis) then
			boneCache[model] = false

			return false
		end
		bones.legs[i] = {thigh = thigh, calf = calf, foot = foot, toe = ply:LookupBone(leg.toe)}
	end
	boneCache[model] = bones

	return bones
end

local function smoothstep(t)
	return t * t * (3 - 2 * t)
end

local function rebase(ang, fromForward, fromUp, toForward, toUp)
	local _, localAng = WorldToLocal(vector_origin, ang, vector_origin, fromForward:AngleEx(fromUp))
	local _, worldAng = LocalToWorld(vector_origin, localAng, vector_origin, toForward:AngleEx(toUp))

	return worldAng
end

local function setBone(ent, bone, pos, ang, scale)
	local mat = Matrix()
	mat:SetTranslation(pos)
	mat:SetAngles(ang)
	mat:Scale(scale)
	hg.bone_apply_matrix(ent, bone, mat)
end

local function hardBlocked(ply)
	return not ply:Alive()
		or IsValid(ply.FakeRagdoll)
		or IsValid(ply.OldRagdoll)
		or ply:GetNWBool("FakeGettingUp", false)
		or ply:InVehicle()
		or ply:GetMoveType() ~= MOVETYPE_WALK
end

local function softEligible(ply)
	if IKFoot.GetFloat("enabled") <= 0 then return false end
	if not ply:OnGround() or ply:WaterLevel() >= 2 then return false end
	local maxDist = IKFoot.GetFloat("draw_distance")

	return ply:GetPos():DistToSqr(EyePos()) <= maxDist * maxDist
end

local function legUsable(ply, legIndex)
	local org = ply.organism
	if not org then return true end
	local leg = LEGS[legIndex]

	return not (org[leg.amputated] or org[leg.amputatedUpper])
end

local function traceGround(state, x, y, originZ)
	local tr = state.groundTrace
	tr.start = Vector(x, y, originZ + GROUND_TRACE_UP)
	tr.endpos = Vector(x, y, originZ - GROUND_TRACE_DOWN)
	local result = util.TraceHull(tr)
	if result.Hit and not result.StartSolid and result.HitNormal.z >= WALKABLE_NORMAL_Z then
		return result.HitPos, result.HitNormal, not result.HitWorld and result.Entity or nil, true
	end

	return Vector(x, y, originZ), vector_up, nil, false
end

local function traceSupport(state, origin, target)
	local pos, normal, groundEnt, hit = traceGround(state, target.x, target.y, origin.z)
	if hit then return pos, normal, groundEnt end

	for _, fraction in ipairs(LEDGE_SEARCH) do
		local inward = origin + (target - origin) * fraction
		local inwardPos, inwardNormal, inwardEnt, inwardHit = traceGround(state, inward.x, inward.y, origin.z)
		if inwardHit then return inwardPos, inwardNormal, inwardEnt end
	end

	return pos, normal, groundEnt
end

local function clampToWalls(state, origin, target)
	local tr = state.wallTrace
	tr.start = origin + vector_up * WALL_TRACE_HEIGHT
	tr.endpos = Vector(target.x, target.y, tr.start.z)
	local result = util.TraceLine(tr)
	if not result.Hit or result.StartSolid then return target end
	local dir = tr.endpos - tr.start
	dir:Normalize()
	local pos = result.HitPos - dir * WALL_BACKOFF

	return Vector(pos.x, pos.y, target.z)
end

local function newState(ply)
	local filter = function(ent) return ent ~= ply and not ent:IsPlayer() end

	return {
		weight = 0,
		phase = 0,
		drop = 0,
		hop = 0,
		lastPlant = 0,
		frame = -1,
		feet = {{}, {}},
		groundTrace = {mins = groundHullMins, maxs = groundHullMaxs, mask = MASK_PLAYERSOLID, filter = filter},
		wallTrace = {mask = MASK_PLAYERSOLID, filter = filter},
	}
end

local function plantFoot(state, foot, pos, normal, groundEnt, bodyYaw)
	foot.planted = pos
	foot.normal = normal
	foot.groundEnt = groundEnt
	foot.localPos = IsValid(groundEnt) and groundEnt:WorldToLocal(pos) or nil
	foot.bodyYaw = bodyYaw
	foot.needsYaw = true
	foot.swinging = false
	state.lastPlant = CurTime()
end

local function startStep(state, index, duration, allowOverlap)
	local foot, other = state.feet[index], state.feet[3 - index]
	if foot.swinging or not foot.planted then return end
	if other.swinging and not allowOverlap then
		foot.pending = duration

		return
	end

	foot.pending = nil
	foot.swinging = true
	foot.t = 0
	foot.duration = duration
	foot.start = Vector(foot.planted)
	foot.startNormal = foot.normal
	foot.startYaw = foot.toeYaw
	foot.target = nil
end

local function plantedWorldPos(foot)
	if not foot.localPos then return foot.planted end
	if not IsValid(foot.groundEnt) then return nil end
	foot.planted = foot.groundEnt:LocalToWorld(foot.localPos)

	return foot.planted
end

local function landingTarget(ply, state, ctx, foot, index)
	local sign = LEGS[index].sign
	local rest = ctx.origin + ctx.right * (sign * ctx.halfWidth)
	if ctx.speed <= MOVING_SPEED then return rest end

	local remaining = (1 - foot.t) * foot.duration
	local bodyAtLanding = ctx.origin + ctx.vel * remaining
	local lead = hg.GaitLandingLead(ctx.speed, ctx.swingFraction) * IKFoot.GetFloat("stride_scale") * (1 - ctx.limp[index] * LIMP_STRIDE_CUT)
	local offset = ctx.right * (sign * ctx.halfWidth) + ctx.moveDir * lead
	local maxSpread = ctx.legLength * LANDING_SPREAD_FRACTION
	if offset:Length() > maxSpread then
		offset:Normalize()
		offset:Mul(maxSpread)
	end

	local lateral = offset:Dot(ctx.right)
	local minLateral = ctx.halfWidth * MIN_LATERAL_FRACTION
	if sign * lateral < minLateral then
		offset:Add(ctx.right * (sign * minLateral - lateral))
	end

	return bodyAtLanding + offset
end

local function updateSwing(ply, state, ctx, index, dt)
	local foot = state.feet[index]
	foot.t = math_min(foot.t + dt / foot.duration, 1)

	local desired = clampToWalls(state, ctx.origin, landingTarget(ply, state, ctx, foot, index))
	if not foot.target or foot.tracedAt:DistToSqr(desired) > RETRACE_DIST_SQR then
		local pos, normal, groundEnt = traceSupport(state, ctx.origin, desired)
		foot.tracedAt = desired
		foot.target = foot.target and LerpVector(math_min(dt * TARGET_SMOOTH, 1), foot.target, pos) or pos
		foot.targetNormal = normal
		foot.targetEnt = groundEnt
	end

	if foot.t >= 1 then
		plantFoot(state, foot, foot.target, foot.targetNormal, foot.targetEnt, ctx.bodyYaw)
		foot.ground = foot.planted
		foot.groundNormal = foot.normal

		return
	end

	local t = foot.t
	local s = smoothstep(t)
	local start, target = foot.start, foot.target
	local rise = target.z - start.z
	local zProgress = rise > 1 and smoothstep(math_min(t * 1.6, 1)) or s
	local clearance = (IKFoot.GetFloat("step_height") * (0.6 + 0.4 * ctx.speedFraction) + math_abs(rise) * 0.3) * (1 - ctx.limp[index] * LIMP_DRAG)
	local pos = LerpVector(s, start, target)
	pos.z = Lerp(zProgress, start.z, target.z) + math_sin(math.pi * t) * clearance
	foot.ground = pos
	foot.groundNormal = LerpVector(s, foot.startNormal or vector_up, foot.targetNormal)
end

local function updatePhase(ply, state, ctx, dt)
	local rate
	if ply == LocalPlayer() and ply.hg_GaitPhase then
		rate = (ply.hg_GaitRate or 0) * hg.GaitLimpRateMul(ply, state.phase)
		state.phase = (state.phase + rate * dt) % 2
		local diff = (ply.hg_GaitPhase - state.phase + 1) % 2 - 1
		state.phase = (state.phase + diff * math_min(dt * PHASE_CORRECTION, 1)) % 2
	else
		rate = hg.GaitStepRate(ctx.speed, ctx.speed > MOVING_SPEED) * hg.GaitLimpRateMul(ply, state.phase)
		state.phase = (state.phase + rate * dt) % 2
	end
	state.rate = rate

	if rate <= 0 then
		state.stepIndex = nil

		return
	end

	local stepIndex = math_floor(state.phase) % 2 + 1
	if stepIndex == state.stepIndex then return end
	state.stepIndex = stepIndex
	startStep(state, stepIndex, hg.GaitSwingTime(rate, ctx.swingFraction), ctx.swingFraction > 1)
end

local function settleIdleFeet(state, ctx)
	if ctx.speed > MOVING_SPEED or CurTime() - state.lastPlant < SETTLE_COOLDOWN then return end
	local settleDist = IKFoot.GetFloat("settle_distance")
	local settleAngle = IKFoot.GetFloat("settle_angle")
	local worstIndex, worstError = nil, 1

	for index = 1, 2 do
		local foot = state.feet[index]
		if foot.swinging or not foot.planted then return end
		local rest = ctx.origin + ctx.right * (LEGS[index].sign * ctx.halfWidth)
		local distError = (foot.planted - rest):Length2D() / settleDist
		local yawError = math_abs(math_AngleDifference(ctx.bodyYaw, foot.bodyYaw or ctx.bodyYaw)) / settleAngle
		local err = math_max(distError, yawError)
		if err > worstError then
			worstIndex, worstError = index, err
		end
	end

	if worstIndex then startStep(state, worstIndex, SETTLE_SWING_TIME, false) end
end

local function releaseFeet(state, ctx)
	for index = 1, 2 do
		local foot = state.feet[index]
		foot.planted, foot.swinging, foot.pending = nil, false, nil
		foot.ground = ctx.anim[index].ankle - vector_up * state.ankleHeight
		foot.groundNormal = vector_up
	end
end

local function updateFeet(ply, state, ctx, dt)
	updatePhase(ply, state, ctx, dt)
	if not ctx.onGround then
		releaseFeet(state, ctx)

		return
	end

	for index = 1, 2 do
		local foot = state.feet[index]
		if not foot.planted then
			local anim = ctx.anim[index]
			plantFoot(state, foot, traceSupport(state, ctx.origin, anim.ankle))
			foot.bodyYaw = ctx.bodyYaw
		end

		if foot.pending and not state.feet[3 - index].swinging then
			startStep(state, index, foot.pending, false)
		end

		if not foot.swinging then
			local planted = plantedWorldPos(foot)
			local hipGround = ctx.origin + ctx.right * (LEGS[index].sign * ctx.halfWidth)
			local overreach = not planted or (planted - hipGround):Length2D() > ctx.legLength * OVERREACH_FRACTION
			if overreach then
				startStep(state, index, SETTLE_SWING_TIME, false)
			end
			foot.ground = foot.planted
			foot.groundNormal = foot.normal
		end
	end

	settleIdleFeet(state, ctx)

	for index = 1, 2 do
		if state.feet[index].swinging then updateSwing(ply, state, ctx, index, dt) end
	end
end

local function updateDrop(state, ctx, dt)
	local targetDrop = 0
	for index = 1, 2 do
		local foot = state.feet[index]
		local supporting = not foot.swinging or foot.t > 0.5
		if ctx.anim[index].usable and supporting and foot.ground then
			targetDrop = math_max(targetDrop, ctx.origin.z - foot.ground.z - DROP_DEADZONE)
		end
	end

	local maxDrop = IKFoot.GetFloat("max_body_drop") * (ctx.crouching and CROUCH_DROP_SCALE or 1)
	targetDrop = math_Clamp(targetDrop * DROP_TERRAIN_SCALE, 0, maxDrop)
	state.drop = state.drop + (targetDrop - state.drop) * (1 - math_exp(-dt * DROP_SMOOTH))
end

local function gaitBob(state, ctx)
	if not ctx.onGround or (state.rate or 0) <= 0 then return 0 end
	local stepProgress = state.phase % 1
	local stanceIndex = 3 - (math_floor(state.phase) % 2 + 1)
	local dip = ctx.limp[stanceIndex] * LIMP_DIP * math_sin(math.pi * stepProgress)
	local flight = hg.GaitFlightFraction(ctx.swingFraction)
	if stepProgress >= flight then return -dip end

	return math_sin(math.pi * stepProgress / flight) * IKFoot.GetFloat("flight_hop") * ctx.speedFraction - dip
end

local function readAnim(ent, ply, bones)
	local anim = {}
	for index, ids in ipairs(bones.legs) do
		local hipMat, kneeMat, ankleMat = ent:GetBoneMatrix(ids.thigh), ent:GetBoneMatrix(ids.calf), ent:GetBoneMatrix(ids.foot)
		if not (hipMat and kneeMat and ankleMat) then return nil end
		local hip, knee, ankle = hipMat:GetTranslation(), kneeMat:GetTranslation(), ankleMat:GetTranslation()
		anim[index] = {
			hip = hip,
			ankle = ankle,
			length = hip:Distance(knee) + knee:Distance(ankle),
			usable = legUsable(ply, index),
		}
	end

	return anim
end

local function buildContext(ply, state, anim, dt)
	local origin = ply:GetPos()
	local vel = ply:GetVelocity()
	vel.z = 0
	local speed = vel:Length()
	local speedFraction = math_Clamp(speed / math_max(ply:GetRunSpeed(), 1), 0, 1)
	local bodyYaw = ply:GetRenderAngles().y
	local bodyAng = Angle(0, bodyYaw, 0)
	local hipSpan = (anim[1].hip - anim[2].hip):Length2D() * 0.5 * IKFoot.GetFloat("stance_width")
	local measuredAnkle = math_Clamp(math_min(anim[1].ankle.z, anim[2].ankle.z) - origin.z, MIN_ANKLE_HEIGHT, MAX_ANKLE_HEIGHT)

	if not state.ankleHeight then
		state.ankleHeight = measuredAnkle
	elseif speed < MOVING_SPEED and not ply:Crouching() then
		state.ankleHeight = state.ankleHeight + (measuredAnkle - state.ankleHeight) * math_min(dt * ANKLE_LEARN_RATE, 1)
	end

	return {
		origin = origin,
		vel = vel,
		speed = speed,
		moveDir = speed > 0 and vel / speed or bodyAng:Forward(),
		speedFraction = speedFraction,
		bodyYaw = bodyYaw,
		forward = bodyAng:Forward(),
		right = bodyAng:Right(),
		halfWidth = math_Clamp(hipSpan, MIN_HALF_WIDTH, MAX_HALF_WIDTH),
		legLength = math_max(anim[1].length, anim[2].length),
		onGround = ply:OnGround(),
		crouching = ply:Crouching(),
		limp = {hg.GaitLegLimp(ply.organism, "lleg"), hg.GaitLegLimp(ply.organism, "rleg")},
		swingFraction = hg.GaitSwingFraction(speed),
		anim = anim,
	}
end

local function alignFoot(foot, carriedAng, toeDir, weight, ankleHeight, toeLength)
	local normal = foot.groundNormal or vector_up
	local currentYaw = toeDir:Angle().y
	if foot.needsYaw then
		foot.toeYaw = currentYaw
		foot.needsYaw = nil
	end

	local yaw = foot.toeYaw or currentYaw
	if foot.swinging then
		local startYaw = foot.startYaw or currentYaw
		yaw = startYaw + math_AngleDifference(currentYaw, startYaw) * smoothstep(foot.t)
		weight = weight * (1 - math_sin(math.pi * foot.t))
	end
	if weight <= 0 then return carriedAng end

	local flat = Angle(0, yaw, 0):Forward()
	flat = flat - normal * flat:Dot(normal)
	flat:Normalize()
	local drop = math_Clamp((ankleHeight - TOE_HEIGHT) / math_max(toeLength, 1), 0, MAX_TOE_DROP)
	local desired = flat * math_sqrt(1 - drop * drop) - normal * drop
	desired = LerpVector(weight, toeDir, desired)
	desired:Normalize()

	return rebase(carriedAng, toeDir, normal, desired, normal)
end

local function solveLeg(ent, ids, foot, ankleTarget, weight, ctx, state, alignWeight)
	local hipMat, kneeMat, ankleMat = ent:GetBoneMatrix(ids.thigh), ent:GetBoneMatrix(ids.calf), ent:GetBoneMatrix(ids.foot)
	if not (hipMat and kneeMat and ankleMat) then return end

	local hip, knee0, ankle0 = hipMat:GetTranslation(), kneeMat:GetTranslation(), ankleMat:GetTranslation()
	local upperLength, lowerLength = hip:Distance(knee0), knee0:Distance(ankle0)
	if upperLength < 1 or lowerLength < 1 then return end

	local target = LerpVector(weight, ankle0, ankleTarget)
	local toTarget = target - hip
	local dist = toTarget:Length()
	if dist < 0.01 then return end
	local dir = toTarget / dist
	dist = math_Clamp(dist, math_abs(upperLength - lowerLength) + 0.5, (upperLength + lowerLength) * REACH_FRACTION)
	local ankle = hip + dir * dist

	local animAxis = (ankle0 - hip):GetNormalized()
	local bend0 = knee0 - hip
	local pole0 = bend0 - animAxis * bend0:Dot(animAxis) + ctx.forward * POLE_FORWARD_BIAS
	pole0 = pole0 - animAxis * pole0:Dot(animAxis)
	if pole0:LengthSqr() < 0.0001 then pole0 = ctx.right:Cross(animAxis) end
	pole0:Normalize()
	local pole = pole0 - dir * pole0:Dot(dir)
	if pole:LengthSqr() < 0.0001 then pole = ctx.forward - dir * ctx.forward:Dot(dir) end
	pole:Normalize()

	local along = (upperLength * upperLength - lowerLength * lowerLength + dist * dist) / (2 * dist)
	local knee = hip + dir * along + pole * math_sqrt(math_max(upperLength * upperLength - along * along, 0))
	local plane0, plane1 = animAxis:Cross(pole0), dir:Cross(pole)

	local footAng0 = ankleMat:GetAngles()
	local thighAng = rebase(hipMat:GetAngles(), bend0, plane0, knee - hip, plane1)
	local calfAng = rebase(kneeMat:GetAngles(), ankle0 - knee0, plane0, ankle - knee, plane1)
	local footAng = rebase(footAng0, ankle0 - knee0, plane0, ankle - knee, plane1)

	local toeMat = ids.toe and ent:GetBoneMatrix(ids.toe)
	if toeMat and alignWeight > 0 then
		local toeLocal = WorldToLocal(toeMat:GetTranslation(), angle_zero, ankle0, footAng0)
		local toeDir = LocalToWorld(toeLocal, angle_zero, ankle, footAng) - ankle
		local toeLength = toeDir:Length()
		if toeLength > 0.5 then
			toeDir:Div(toeLength)
			footAng = alignFoot(foot, footAng, toeDir, alignWeight * weight, state.ankleHeight, toeLength)
		end
	end

	setBone(ent, ids.thigh, hip, thighAng, hipMat:GetScale())
	setBone(ent, ids.calf, knee, calfAng, kneeMat:GetScale())
	setBone(ent, ids.foot, ankle, footAng, ankleMat:GetScale())

	return knee
end

local function applyPose(ent, ply, state, bones, ctx)
	local weight = state.weight
	local pelvisOffset = (state.hop - state.drop) * weight
	local pelvisMat = ent:GetBoneMatrix(bones.pelvis)
	if pelvisMat and math_abs(pelvisOffset) > 0.01 then
		local current = pelvisMat:GetTranslation()
		local alreadyOffset = state.pelvisFrame == FrameNumber() and current:DistToSqr(state.pelvisSet) < 0.0001
		if not alreadyOffset then
			local moved = Matrix(pelvisMat)
			moved:SetTranslation(current + vector_up * pelvisOffset)
			hg.bone_apply_matrix(ent, bones.pelvis, moved)
			state.pelvisSet = moved:GetTranslation()
			state.pelvisFrame = FrameNumber()
		end
	end

	local alignWeight = IKFoot.GetFloat("align_feet") > 0 and 1 or 0
	state.appliedKnee = nil
	for index, ids in ipairs(bones.legs) do
		local foot = state.feet[index]
		if ctx.anim[index].usable and foot.ground then
			local normal = foot.groundNormal or vector_up
			local ankleTarget = foot.ground + normal * state.ankleHeight
			local knee = solveLeg(ent, ids, foot, ankleTarget, weight, ctx, state, alignWeight)
			state.appliedKnee = state.appliedKnee or knee and {bone = ids.calf, pos = knee}
		end
	end
end

local function alreadyApplied(ent, state)
	local applied = state.appliedKnee
	if not applied then return false end
	local mat = ent:GetBoneMatrix(applied.bone)

	return mat ~= nil and mat:GetTranslation():DistToSqr(applied.pos) < 0.0001
end

local function drawDebug(state)
	for index = 1, 2 do
		local foot = state.feet[index]
		if foot.planted then
			render.DrawWireframeBox(foot.planted, angle_zero, -DEBUG_BOX, DEBUG_BOX, DEBUG_PLANTED, true)
		end
		if foot.swinging and foot.target then
			render.DrawWireframeBox(foot.target, angle_zero, -DEBUG_BOX, DEBUG_BOX, DEBUG_SWING, true)
		end
	end
end

function hg.FootIK(ent, ply)
	if not ply:IsPlayer() or not IKFoot.GetFloat then return end
	if ent ~= ply or hardBlocked(ply) then
		ply.hg_FootIK = nil

		return
	end

	local eligible = softEligible(ply)
	local state = ply.hg_FootIK
	if not state and not eligible then return end
	local bones = getBones(ply)
	if not bones then return end

	state = state or newState(ply)
	ply.hg_FootIK = state

	if state.frame == FrameNumber() then
		if not state.ctx or alreadyApplied(ent, state) then return end
		applyPose(ent, ply, state, bones, state.ctx)

		return
	end
	state.frame = FrameNumber()

	local dt = math_min(FrameTime(), 0.1)
	local blendSpeed = IKFoot.GetFloat("blend_speed")
	state.weight = math_Clamp(state.weight + (eligible and dt * blendSpeed or -dt * blendSpeed * 2), 0, 1)
	if state.weight <= 0 and not eligible then
		ply.hg_FootIK = nil

		return
	end

	local anim = readAnim(ent, ply, bones)
	if not anim then return end
	local ctx = buildContext(ply, state, anim, dt)
	state.ctx = ctx

	updateFeet(ply, state, ctx, dt)
	updateDrop(state, ctx, dt)
	state.hop = gaitBob(state, ctx)
	applyPose(ent, ply, state, bones, ctx)

	if IKFoot.GetFloat("debug") > 0 then drawDebug(state) end
end

function IKFoot.HardReset(ply)
	if IsValid(ply) then ply.hg_FootIK = nil end
end
