-- TPIK-Compatible IK Foot System (Advanced)
-- Uses bone matrix manipulation to avoid conflicts with health indicator
-- Integrates advanced features from iker foot: stair detection, procedural stepping, anti-clip, dynamic sole
local hg = hg or {}

-- Constants
local MAX_KNEE_BEND = 68
local MIN_KNEE_BEND = -30
local MAX_FOOT_PITCH = 25
local MAX_FOOT_ROLL = 20
local REFERENCE_LEG_LENGTH = 45
local CROUCH_BLEND_TIME = 0.3
local AIR_BODY_DROP_MAX = 6
local AIR_KNEE_MIN = 8
local AIR_KNEE_MAX = 24
local AIR_FOOT_PITCH_ASCEND = -6
local AIR_FOOT_PITCH_DESCEND = 14
local AIR_SWING_SPEED = 6
local AIR_SWING_AMP = 4
local IDLE_ACQUIRE_DELAY = 0.14
local WALKABLE_Z = 0.35
local CLUSTER_TOLERANCE = 3.0

-- Sample weights for multi-point ground tracing
local SAMPLE_WEIGHTS = {
	center = 4, toe = 2, heel = 2,
	left = 2, right = 2,
	toeInner = 1, toeOuter = 1, inner = 1, outer = 1,
}

-- Configuration
hg.IKFootConfig = {
	enabled = CreateConVar("hg_ik_foot_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable IK Foot system"),
	groundDistance = CreateClientConVar("hg_ik_foot_ground_dist", "70", true, false, "Ground trace distance"),
	legLength = CreateClientConVar("hg_ik_foot_leg_length", "45", true, false, "Leg length for IK"),
	smoothing = CreateClientConVar("hg_ik_foot_smoothing", "30", true, false, "Smoothing factor (1-50)"),
	rotationSmoothing = CreateClientConVar("hg_ik_foot_rotation_smoothing", "40", true, false, "Rotation smoothing (1-60)"),
	bodyDrop = CreateClientConVar("hg_ik_foot_body_drop", "0.3", true, false, "Body drop amount (flat)"),
	bodyDropUneven = CreateClientConVar("hg_ik_foot_body_drop_uneven", "1.2", true, false, "Body drop amount (uneven)"),
	unevenDropScale = CreateClientConVar("hg_ik_foot_uneven_drop_scale", "0.15", true, false, "Height diff multiplier"),
	bendBoost = CreateClientConVar("hg_ik_foot_bend_boost", "1.20", true, false, "High foot bend boost"),
	footRotScale = CreateClientConVar("hg_ik_foot_foot_rot_scale", "0.15", true, false, "Foot rotation scale"),
	lockStrength = CreateClientConVar("hg_ik_foot_lock_strength", "0.85", true, false, "Foot lock strength"),
	releaseSpeed = CreateClientConVar("hg_ik_foot_release_speed", "65", true, false, "Foot release speed"),
	soleOffset = CreateClientConVar("hg_ik_foot_sole_offset", "0", true, false, "Sole contact offset"),
	traceStartOffset = CreateClientConVar("hg_ik_foot_trace_start_offset", "30", true, false, "Trace start height"),
	maxBodyDrop = CreateClientConVar("hg_ik_foot_max_body_drop", "42", true, false, "Maximum body drop"),
	leanEnabled = CreateClientConVar("hg_ik_foot_lean_enabled", "0", true, false, "Enable body lean"),
	stabilizeIdle = CreateClientConVar("hg_ik_foot_stabilize_idle", "1", true, false, "Stabilize idle feet"),
	idleVelocity = CreateClientConVar("hg_ik_foot_idle_velocity", "5", true, false, "Idle velocity threshold"),
	antiClip = CreateClientConVar("hg_ik_foot_anti_clip", "1", true, false, "Foot anti-clip guard"),
	dynamicSole = CreateClientConVar("hg_ik_foot_dynamic_sole", "1", true, false, "Dynamic sole correction"),
	stairStepMin = CreateClientConVar("hg_ik_foot_stair_min", "6", true, false, "Minimum stair step height"),
	stairStepMax = CreateClientConVar("hg_ik_foot_stair_max", "28", true, false, "Maximum stair step height"),
	stairWindow = CreateClientConVar("hg_ik_foot_stair_window", "0.33", true, false, "Stair sequence time window"),
	stairReleaseMul = CreateClientConVar("hg_ik_foot_stair_release_mul", "1.2", true, false, "Stair release multiplier"),
	stairAdaptive = CreateClientConVar("hg_ik_foot_stair_adaptive", "1.0", true, false, "Adaptive body drop on stairs"),
	maxKneeBend = MAX_KNEE_BEND,
	minKneeBend = MIN_KNEE_BEND,
}

-- Per-player state (advanced structure)
hg.IKFootState = hg.IKFootState or {}

-- Dynamic sole correction state
local DynSoleState = {}

local function GetDynSoleState(ply)
	local id = ply:EntIndex()
	if not DynSoleState[id] then
		DynSoleState[id] = { correction = 0 }
	end
	return DynSoleState[id]
end

local function ResetDynSole(ply)
	if not IsValid(ply) then return end
	DynSoleState[ply:EntIndex()] = nil
end

local function GetIKState(ply)
	local id = ply:EntIndex()
	if not hg.IKFootState[id] then
		hg.IKFootState[id] = {
			idle = { active = false, candidateTime = 0 },
			legs = {
				left = {
					planted = false,
					lockPos = nil,
					lastRawPos = nil,
					lastTargetPos = nil,
					footSpeed = 0,
					released = false,
					lockAge = 0,
					proc = { phase = "planted", plantPos = nil, swingStart = nil, swingTarget = nil, swingT = 0, liftH = 0, blendT = 0 },
				},
				right = {
					planted = false,
					lockPos = nil,
					lastRawPos = nil,
					lastTargetPos = nil,
					footSpeed = 0,
					released = false,
					lockAge = 0,
					proc = { phase = "planted", plantPos = nil, swingStart = nil, swingTarget = nil, swingT = 0, liftH = 0, blendT = 0 },
				},
			},
			stairs = { sequence = 0, lastStepTime = 0, confidence = 0, upHeight = 0, downHeight = 0, eventHeight = 0, mode = false, prevLeftReq = 0, prevRightReq = 0 },
			crouch = { crouching = false, transitionTime = 0, inTransition = false },
			bodyDrop = 0,
			leftKnee = 0,
			rightKnee = 0,
		}
	end
	return hg.IKFootState[id]
end

function hg.ResetIKFoot(ply)
	local id = ply:EntIndex()
	hg.IKFootState[id] = nil
	ResetDynSole(ply)
	ply.IKApplyState = nil
	ply.IKBlendState = nil
	ply.IKBones = nil
end

function hg.HardResetIKFoot()
	hg.IKFootState = {}
	DynSoleState = {}
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then
			ply.IKApplyState = nil
			ply.IKBlendState = nil
			ply.IKBones = nil
		end
	end
end

-- Multi-point ground sampling (advanced)
local function IsWalkable(normal)
	return normal and normal.z >= WALKABLE_Z
end

local function ClassifySurface(trace)
	if trace.HitWorld then return "world", true, NULL end
	local ent = trace.Entity
	if not IsValid(ent) then return "none", false, NULL end
	if ent:IsPlayer() then return "player", false, ent end
	if ent:IsRagdoll() then return "ragdoll", true, ent end
	local class = ent:GetClass()
	if string.StartWith(class, "prop_") or class == "func_physbox" then return "prop", true, ent end
	return "other", false, ent
end

local function TraceSample(ply, startPos, groundDist, soleOffset)
	local endPos = startPos - Vector(0, 0, groundDist)
	
	local trace = util.TraceHull({
		start = startPos,
		endpos = endPos,
		mins = Vector(-2, -2, 0),
		maxs = Vector(2, 2, 4),
		mask = MASK_PLAYERSOLID,
		filter = function(ent) return ent ~= ply and not ent:IsPlayer() end,
	})
	
	if trace.Hit and not IsWalkable(trace.HitNormal) then
		local fallback = util.TraceLine({
			start = startPos,
			endpos = endPos,
			filter = function(ent) return ent ~= ply and not ent:IsPlayer() end,
		})
		if fallback.Hit and IsWalkable(fallback.HitNormal) then
			trace = fallback
		else
			trace.Hit = false
		end
	end
	
	if trace.Hit then
		local normal = trace.HitNormal or vector_up
		local hitPos = trace.HitPos + normal * soleOffset
		local surfaceType, surfaceAllowed, surfaceEnt = ClassifySurface(trace)
		local surfaceSpeed = 0
		if IsValid(surfaceEnt) and surfaceEnt.GetVelocity then
			surfaceSpeed = surfaceEnt:GetVelocity():Length()
		end
		local surfaceStable = surfaceType == "world" or (surfaceAllowed and surfaceSpeed <= 45)
		
		if not (isvector(hitPos) and hitPos.x == hitPos.x) then
			return { hit = false, hitPos = endPos, normal = vector_up, distance = groundDist, surfaceType = "none", surfaceStable = false }
		end
		
		return {
			hit = true,
			hitPos = hitPos,
			normal = normal,
			distance = math.max(startPos.z - hitPos.z, 0),
			surfaceType = surfaceType,
			surfaceStable = surfaceStable,
			entity = surfaceEnt,
		}
	end
	
	return { hit = false, hitPos = endPos, normal = vector_up, distance = groundDist, surfaceType = "none", surfaceStable = false }
end

local function SampleFoot(ply, footPos, footAng, traceStartZ, groundDist, isLeft, soleOffset)
	local fwd = footAng:Forward()
	fwd.z = 0
	if fwd:LengthSqr() < 0.001 then fwd = Vector(1, 0, 0) else fwd:Normalize() end
	
	local right = footAng:Right()
	right.z = 0
	if right:LengthSqr() < 0.001 then right = Vector(0, 1, 0) else right:Normalize() end
	
	local sideSign = isLeft and -1 or 1
	local outer = right * (2.5 * sideSign)
	local inner = -outer
	local base = Vector(footPos.x, footPos.y, traceStartZ)
	
	local offsets = {
		center = Vector(),
		toe = fwd * 5.5,
		heel = -fwd * 3.5,
		left = -right * 2.25,
		right = right * 2.25,
		toeInner = fwd * 4 + inner * 0.75,
		toeOuter = fwd * 4 + outer * 0.75,
		outer = outer,
		inner = inner,
	}
	
	local samples = {}
	for name, offset in pairs(offsets) do
		samples[name] = TraceSample(ply, base + offset, groundDist, soleOffset)
	end
	return samples
end

local function ResolveContact(samples, fallbackPos, fallbackNormal)
	local highestHitZ = -math.huge
	for _, s in pairs(samples) do
		if s.hit and IsWalkable(s.normal) and s.hitPos.z > highestHitZ then
			highestHitZ = s.hitPos.z
		end
	end
	local clusterFloor = highestHitZ - CLUSTER_TOLERANCE
	
	local totalWeight, hitCount = 0, 0
	local posSum = Vector()
	local normalSum = Vector()
	local distSum = 0
	local surfaceWeights = {}
	local stableWeight = 0
	
	for name, s in pairs(samples) do
		if s.hit and IsWalkable(s.normal) and s.hitPos.z >= clusterFloor then
			local w = SAMPLE_WEIGHTS[name] or 1
			totalWeight = totalWeight + w
			posSum = posSum + s.hitPos * w
			normalSum = normalSum + s.normal * w
			distSum = distSum + s.distance * w
			hitCount = hitCount + 1
			local surfaceType = s.surfaceType or "none"
			surfaceWeights[surfaceType] = (surfaceWeights[surfaceType] or 0) + w
			if s.surfaceStable then
				stableWeight = stableWeight + w
			end
		end
	end
	
	local pos, normal, dist = fallbackPos, fallbackNormal or vector_up, 0
	
	if totalWeight > 0 then
		pos = posSum / totalWeight
		normal = normalSum / totalWeight
		if normal:LengthSqr() < 0.001 then normal = vector_up else normal:Normalize() end
		dist = distSum / totalWeight
		if pos.x ~= pos.x then pos = fallbackPos; hitCount = 0 end
		if normal.x ~= normal.x then normal = vector_up end
	end
	
	local dominantSurfaceType = "none"
	local dominantWeight = 0
	for surfaceType, weight in pairs(surfaceWeights) do
		if weight > dominantWeight then
			dominantWeight = weight
			dominantSurfaceType = surfaceType
		end
	end
	
	return {
		hasHit = hitCount > 0,
		hitCount = hitCount,
		position = Vector(pos),
		normal = Vector(normal),
		supportDistance = dist,
		samples = samples,
		surfaceType = dominantSurfaceType,
		surfaceStable = stableWeight >= math.max(totalWeight * 0.5, 1),
	}
end

local function ValidateContact(contact, samples, footBoneZ, soleOffset)
	local result = {
		isValid = true,
		penetrationCount = 0,
		highestValidZ = -math.huge,
		invalidReason = nil,
		normalVariance = 0,
	}
	
	if not contact.hasHit then
		result.isValid = false
		result.invalidReason = "no_hit"
		return result
	end
	
	local expectedSoleZ = footBoneZ - soleOffset
	local totalHits = 0
	local penetrating = 0
	local normals = {}
	
	for _, s in pairs(samples) do
		if not s.hit then continue end
		totalHits = totalHits + 1
		normals[#normals + 1] = s.normal
		
		local rawHitZ = s.hitPos.z - soleOffset
		if rawHitZ > footBoneZ + 0.5 then
			penetrating = penetrating + 1
		end
		
		if rawHitZ <= footBoneZ + 0.5 and s.hitPos.z > result.highestValidZ then
			result.highestValidZ = s.hitPos.z
		end
	end
	
	result.penetrationCount = penetrating
	
	if totalHits > 0 and penetrating / totalHits > 0.4 then
		result.isValid = false
		result.invalidReason = "penetrating"
	end
	
	if #normals >= 3 then
		local avgNormal = Vector()
		for _, n in ipairs(normals) do avgNormal:Add(n) end
		avgNormal:Div(#normals)
		if avgNormal:LengthSqr() > 0.001 then avgNormal:Normalize() end
		
		local variance = 0
		for _, n in ipairs(normals) do
			variance = variance + (1 - n:Dot(avgNormal))
		end
		result.normalVariance = variance / #normals
		
		if result.normalVariance > 0.35 then
			result.invalidReason = result.invalidReason or "inconsistent_normals"
		end
	end
	
	if contact.normal.z < WALKABLE_Z then
		result.isValid = false
		result.invalidReason = result.invalidReason or "steep_surface"
	end
	
	return result
end

local function PredictLanding(ply, fromPos, moveDir, lookDist, upClear, groundDist, soleOffset)
	local searchX = fromPos.x + moveDir.x * lookDist
	local searchY = fromPos.y + moveDir.y * lookDist
	local searchTop = Vector(searchX, searchY, fromPos.z + upClear)
	local searchBot = Vector(searchX, searchY, fromPos.z - groundDist)
	
	local trace = util.TraceHull({
		start = searchTop,
		endpos = searchBot,
		mins = Vector(-2, -2, 0),
		maxs = Vector(2, 2, 4),
		mask = MASK_PLAYERSOLID,
		filter = function(ent) return ent ~= ply and not ent:IsPlayer() end,
	})
	
	if trace.Hit and IsWalkable(trace.HitNormal) then
		local landPos = trace.HitPos + (trace.HitNormal or vector_up) * soleOffset
		if landPos.x == landPos.x then
			return landPos
		end
	end
	return nil
end

-- State management functions
local function UpdateCrouch(state, isCrouching)
	local crouch = state.crouch
	if crouch.crouching ~= isCrouching then
		crouch.crouching = isCrouching
		crouch.transitionTime = 0
		crouch.inTransition = true
		for _, side in ipairs({"left", "right"}) do
			local leg = state.legs[side]
			if leg then
				leg.planted = false
				leg.lockPos = nil
				leg.lastRawPos = nil
			end
		end
		state.idle.active = false
		state.idle.candidateTime = 0
	end
	if crouch.inTransition then
		crouch.transitionTime = crouch.transitionTime + FrameTime()
		if crouch.transitionTime >= CROUCH_BLEND_TIME then
			crouch.inTransition = false
		end
	end
	return crouch
end

local function UpdateIdle(state, onGround, vel2D, velZ, idleVelThresh, leftRawPos, rightRawPos)
	local idle = state.idle
	local isCandidate = onGround and vel2D <= idleVelThresh and math.abs(velZ) <= (idleVelThresh * 0.5)
	
	if isCandidate then
		idle.candidateTime = idle.candidateTime + FrameTime()
	else
		idle.candidateTime = 0
		idle.active = false
	end
	
	if isCandidate and idle.candidateTime >= IDLE_ACQUIRE_DELAY then
		idle.active = true
		idle.leftRaw = Vector(leftRawPos)
		idle.rightRaw = Vector(rightRawPos)
	end
	
	return idle, isCandidate
end

local function MeasureFootSpeed(footState, rawFootPos, dt)
	if dt <= 0 then
		footState.footSpeed = 0
	elseif footState.lastRawPos and isvector(rawFootPos) and isvector(footState.lastRawPos) then
		local speed = rawFootPos:Distance(footState.lastRawPos) / math.max(dt, 1 / 300)
		footState.footSpeed = isnumber(speed) and speed or 0
	else
		footState.footSpeed = 0
	end
	if isvector(rawFootPos) then
		footState.lastRawPos = Vector(rawFootPos)
	end
	return footState.footSpeed
end

local function UpdateFoot(footState, data)
	footState.released = false
	
	if data.contact.hasHit and not isvector(data.contact.position) then
		data.contact.hasHit = false
	end
	
	if not data.onGround then
		footState.planted = false
		footState.lockPos = nil
	end
	
	if footState.lockPos then
		local lockDist = data.rawFootPos:Distance(footState.lockPos)
		if lockDist > math.max(40, data.lockStrength * 25) then
			footState.planted = false
			footState.lockPos = nil
			footState.released = true
		end
	end
	
	local acquireDistance = math.max(4, 8 * data.lockStrength)
	local releaseDistance = math.max(acquireDistance * 1.3, 6 + data.lockStrength * 6)
	local stairReleaseMul = math.max(tonumber(data.stairReleaseMultiplier) or 1, 1)
	local releaseSpeed = math.max(data.releaseSpeed, 5)
	local stairMode = data.stairMode and (data.stairConfidence or 0) >= 0.2
	
	if stairMode then
		if data.isSupportFoot then
			releaseDistance = releaseDistance * math.max(1.05, stairReleaseMul * 0.9)
			acquireDistance = acquireDistance * math.Clamp(1 + (data.stairConfidence or 0) * 0.2, 1, 1.2)
		else
			releaseDistance = releaseDistance * 0.82
			acquireDistance = acquireDistance * 0.9
			releaseSpeed = releaseSpeed * 0.82
		end
	end
	
	local shouldAcquire = data.contact.hasHit and data.onGround and (
		data.idleActive
		or (data.footSpeed <= releaseSpeed * 0.55 and data.rawFootPos:Distance(data.contact.position) <= acquireDistance)
		or (data.isSupportFoot and data.rawFootPos:Distance(data.contact.position) <= acquireDistance * 1.2)
	)
	
	if footState.lockPos then
		footState.lockAge = (footState.lockAge or 0) + FrameTime()
		local distToLock = data.rawFootPos:Distance(footState.lockPos)
		local wantsStrideRelease = data.footSpeed > releaseSpeed and distToLock > releaseDistance * 0.5
		local stairHardLimit = stairMode and (data.isSupportFoot and releaseDistance * 0.85 or releaseDistance * 0.55) or math.huge
		
		if not data.idleActive and (wantsStrideRelease or distToLock > releaseDistance or distToLock > stairHardLimit) then
			footState.planted = false
			footState.lockPos = nil
			footState.released = true
		end
	end
	
	if not footState.lockPos and shouldAcquire then
		footState.lockPos = Vector(data.contact.position)
		footState.planted = true
		footState.lockAge = 0
	elseif footState.lockPos then
		footState.planted = true
	end
	
	if footState.lockPos and (footState.lockAge or 0) > 10 then
		footState.planted = false
		footState.lockPos = nil
		footState.released = true
		footState.lockAge = 0
	end
	
	if data.idleActive and data.contact.hasHit then
		if not footState.lockPos then
			footState.lockPos = Vector(data.contact.position)
		end
		footState.planted = true
	end
	
	local desiredPos
	if footState.lockPos then
		desiredPos = Vector(footState.lockPos)
	elseif data.contact.hasHit then
		desiredPos = Vector(data.contact.position)
	else
		desiredPos = Vector(data.rawFootPos)
	end
	
	if not isvector(desiredPos) then
		desiredPos = isvector(data.rawFootPos) and Vector(data.rawFootPos) or Vector(0, 0, 0)
	end
	
	footState.lastTargetPos = Vector(desiredPos)
	
	return {
		planted = footState.planted and footState.lockPos ~= nil,
		lockPos = footState.lockPos and Vector(footState.lockPos) or nil,
		targetPos = desiredPos,
		footSpeed = footState.footSpeed,
		released = footState.released,
	}
end

-- Stair detection and procedural stepping
local function UpdateStairSequence(state, stairData)
	local stairs = state.stairs
	local now = CurTime()
	local window = math.max(tonumber(stairData.sequenceWindow) or 0.33, 0.12)
	local stepUp = math.max(stairData.leftRise or 0, stairData.rightRise or 0)
	local stepDown = math.max(stairData.leftDrop or 0, stairData.rightDrop or 0)
	local asymmetry = math.max(stairData.heightDiff or 0, 0)
	local eventHeight = math.max(stepUp, stepDown, asymmetry * 0.75)
	
	if eventHeight > 0.2 and stairData.eligible then
		if now - (stairs.lastStepTime or 0) <= window then
			stairs.sequence = math.min((stairs.sequence or 0) + 1, 8)
		else
			stairs.sequence = 1
		end
		stairs.lastStepTime = now
	else
		stairs.sequence = math.max((stairs.sequence or 0) - FrameTime() * 4, 0)
	end
	
	local confidenceBase = stairData.edgeConfidence or 0
	local asymmetrySignal = math.Clamp(asymmetry / math.max(tonumber(stairData.stepMax) or 24, 1), 0, 1)
	local sequenceBonus = math.Clamp((stairs.sequence or 0) / 3, 0, 1)
	local confidence = math.Clamp(confidenceBase * 0.55 + asymmetrySignal * 0.5 + sequenceBonus * 0.4, 0, 1)
	if not stairData.surfaceStable then
		confidence = confidence * 0.5
	end
	
	stairs.confidence = confidence
	stairs.upHeight = stepUp
	stairs.downHeight = stepDown
	stairs.eventHeight = eventHeight
	stairs.mode = stairData.eligible and confidence >= 0.4
	
	return {
		mode = stairs.mode,
		confidence = confidence,
		sequence = stairs.sequence,
		upHeight = stepUp,
		downHeight = stepDown,
		eventHeight = eventHeight,
	}
end

local function UpdateStepperFoot(footState, otherFootState, data)
	local proc = footState.proc
	if not proc then
		footState.proc = { phase = "planted", plantPos = nil, swingStart = nil, swingTarget = nil, swingT = 0, liftH = 0, blendT = 0 }
		proc = footState.proc
	end
	
	local fadeRate = data.stairMode and 6 or -5
	proc.blendT = math.Clamp((proc.blendT or 0) + data.dt * fadeRate, 0, 1)
	
	if not proc.plantPos then
		proc.plantPos = data.currentLock and Vector(data.currentLock) or Vector(data.rawFootPos)
		proc.phase = "planted"
		proc.swingT = 0
	end
	
	if data.stairMode then
		local otherProc = otherFootState and otherFootState.proc
		local otherSwinging = otherProc and otherProc.phase == "swinging"
		
		if proc.phase == "planted" then
			local dx = data.playerPos.x - proc.plantPos.x
			local dy = data.playerPos.y - proc.plantPos.y
			local behindDist = dx * data.moveDir.x + dy * data.moveDir.y
			
			if not otherSwinging and behindDist >= data.strideLen * 0.45 and data.vel2D > 5 and data.swingTarget ~= nil then
				proc.phase = "swinging"
				proc.swingStart = Vector(proc.plantPos)
				proc.swingT = 0
				proc.liftH = data.liftHeight
				proc.swingTarget = Vector(data.swingTarget)
			end
		end
		
		if proc.phase == "swinging" then
			local swingRate = math.max(data.vel2D, 8) / math.max(data.strideLen, 10)
			proc.swingT = math.min(proc.swingT + data.dt * swingRate, 1.0)
			
			if proc.swingT >= 1.0 then
				proc.phase = "planted"
				proc.plantPos = proc.swingTarget and Vector(proc.swingTarget) or Vector(data.rawFootPos)
				proc.swingStart = nil
			end
		end
	else
		if proc.blendT <= 0 then
			proc.plantPos = nil
			proc.phase = "planted"
			proc.swingT = 0
		end
	end
	
	local procPos
	if proc.phase == "swinging" and proc.swingStart and proc.swingTarget then
		local t = proc.swingT
		local x = proc.swingStart.x + (proc.swingTarget.x - proc.swingStart.x) * t
		local y = proc.swingStart.y + (proc.swingTarget.y - proc.swingStart.y) * t
		local baseZ = proc.swingStart.z + (proc.swingTarget.z - proc.swingStart.z) * t
		procPos = Vector(x, y, baseZ + math.sin(t * math.pi) * proc.liftH)
	elseif proc.plantPos then
		procPos = Vector(proc.plantPos)
	else
		return nil
	end
	
	if not (isvector(procPos) and procPos.x == procPos.x) then return nil end
	
	if proc.blendT < 1 then
		local raw = data.rawFootPos
		return Vector(
			raw.x + (procPos.x - raw.x) * proc.blendT,
			raw.y + (procPos.y - raw.y) * proc.blendT,
			raw.z + (procPos.z - raw.z) * proc.blendT
		)
	end
	return procPos
end

local function ComputeFootRotation(samples, scale)
	if scale <= 0.01 then return Angle() end
	
	local toe, heel = samples.toe, samples.heel
	local sLeft, sRight = samples.left, samples.right
	local pitch, roll = 0, 0
	
	if toe and heel and toe.hit and heel.hit then
		local len = math.max(toe.hitPos:Distance(heel.hitPos), 0.01)
		pitch = math.Clamp(-math.deg(math.atan2(toe.hitPos.z - heel.hitPos.z, len)) * scale, -MAX_FOOT_PITCH, MAX_FOOT_PITCH)
	end
	
	if sLeft and sRight and sLeft.hit and sRight.hit then
		local len = math.max(sRight.hitPos:Distance(sLeft.hitPos), 0.01)
		roll = math.Clamp(math.deg(math.atan2(sRight.hitPos.z - sLeft.hitPos.z, len)) * scale, -MAX_FOOT_ROLL, MAX_FOOT_ROLL)
	end
	
	return Angle(0, pitch, roll)
end

local function DetermineSupportSide(leftContact, rightContact, leftState, rightState)
	if leftContact.hasHit and rightContact.hasHit then
		local zDelta = leftContact.position.z - rightContact.position.z
		if math.abs(zDelta) > 0.5 then
			return zDelta < 0 and "left" or "right"
		end
	end
	if leftState.planted and not rightState.planted then return "left" end
	if rightState.planted and not leftState.planted then return "right" end
	return leftContact.supportDistance >= rightContact.supportDistance and "left" or "right"
end

-- Calculate IK for legs (advanced)
function hg.CalculateIKFoot(ply, ent)
	if not hg.IKFootConfig.enabled:GetBool() then return nil end
	if ply:InVehicle() then return nil end
	
	-- Don't run IK if organism is in critical state to avoid animation conflicts
	if ply.organism and (ply.organism.otrub or ply.organism.brain > 0.1) then return nil end
	
	local state = GetIKState(ply)
	local dt = math.Clamp(FrameTime(), 1/300, 1/20)
	
	-- Get config values
	local groundDist = hg.IKFootConfig.groundDistance:GetFloat()
	local legLength = hg.IKFootConfig.legLength:GetFloat()
	local smoothing = math.Clamp(hg.IKFootConfig.smoothing:GetFloat(), 1, 50)
	local rotSmoothing = math.Clamp(hg.IKFootConfig.rotationSmoothing:GetFloat(), 1, 60)
	local bodyDropTarget = hg.IKFootConfig.bodyDrop:GetFloat()
	local bodyDropUneven = hg.IKFootConfig.bodyDropUneven:GetFloat()
	local unevenDropScale = hg.IKFootConfig.unevenDropScale:GetFloat()
	local bendBoost = hg.IKFootConfig.bendBoost:GetFloat()
	local footRotScale = hg.IKFootConfig.footRotScale:GetFloat()
	local lockStrength = hg.IKFootConfig.lockStrength:GetFloat()
	local releaseSpeed = hg.IKFootConfig.releaseSpeed:GetFloat()
	local soleOffset = hg.IKFootConfig.soleOffset:GetFloat()
	local traceStartOff = hg.IKFootConfig.traceStartOffset:GetFloat()
	local maxBodyDropCVar = hg.IKFootConfig.maxBodyDrop:GetFloat()
	local idleVelThresh = hg.IKFootConfig.idleVelocity:GetFloat()
	local leanEnabled = hg.IKFootConfig.leanEnabled:GetBool()
	local stabilizeIdle = hg.IKFootConfig.stabilizeIdle:GetBool()
	local antiClip = hg.IKFootConfig.antiClip:GetBool()
	local dynamicSole = hg.IKFootConfig.dynamicSole:GetBool()
	local stepMinHeight = hg.IKFootConfig.stairStepMin:GetFloat()
	local stepMaxHeight = hg.IKFootConfig.stairStepMax:GetFloat()
	local stepWindow = hg.IKFootConfig.stairWindow:GetFloat()
	local stairReleaseMul = hg.IKFootConfig.stairReleaseMul:GetFloat()
	local stairStepMul = hg.IKFootConfig.stairAdaptive:GetFloat()
	
	-- Scale params to model size
	local modelScale = math.Clamp((state.measuredLegLength or REFERENCE_LEG_LENGTH) / REFERENCE_LEG_LENGTH, 0.4, 2.5)
	groundDist = groundDist * modelScale
	legLength = legLength * modelScale
	traceStartOff = traceStartOff * modelScale
	bodyDropTarget = bodyDropTarget * modelScale
	bodyDropUneven = bodyDropUneven * modelScale
	maxBodyDropCVar = maxBodyDropCVar * modelScale
	
	local vel = ply:GetVelocity()
	local vel2D = vel:Length2D()
	local velZ = vel.z
	local onGround = ply:OnGround()
	local traceStartZ = ply:GetPos().z + traceStartOff
	
	local isCrouching = ply:Crouching()
	local crouch = UpdateCrouch(state, isCrouching)
	
	-- Get leg bones
	local lThigh = ent:LookupBone("ValveBiped.Bip01_L_Thigh")
	local lCalf = ent:LookupBone("ValveBiped.Bip01_L_Calf")
	local lFoot = ent:LookupBone("ValveBiped.Bip01_L_Foot")
	local rThigh = ent:LookupBone("ValveBiped.Bip01_R_Thigh")
	local rCalf = ent:LookupBone("ValveBiped.Bip01_R_Calf")
	local rFoot = ent:LookupBone("ValveBiped.Bip01_R_Foot")
	
	if not lFoot or not rFoot or not lCalf or not rCalf or not lThigh or not rThigh then
		return nil
	end
	
	-- Get current foot positions
	local lFootMat = ent:GetBoneMatrix(lFoot)
	local rFootMat = ent:GetBoneMatrix(rFoot)
	if not lFootMat or not rFootMat then return nil end
	
	local lFootPos = lFootMat:GetTranslation()
	local rFootPos = rFootMat:GetTranslation()
	local lFootAng = lFootMat:GetAngles()
	local rFootAng = rFootMat:GetAngles()
	
	-- Measure leg length on first valid frame
	if not state.measuredLegLength then
		local lThighMat = ent:GetBoneMatrix(lThigh)
		local rThighMat = ent:GetBoneMatrix(rThigh)
		if lThighMat and rThighMat then
			local lCalfPos = lCalf and ent:GetBoneMatrix(lCalf) and ent:GetBoneMatrix(lCalf):GetTranslation()
			local rCalfPos = rCalf and ent:GetBoneMatrix(rCalf) and ent:GetBoneMatrix(rCalf):GetTranslation()
			if lCalfPos and rCalfPos then
				local lLen = lThighMat:GetTranslation():Distance(lCalfPos) + lCalfPos:Distance(lFootPos)
				local rLen = rThighMat:GetTranslation():Distance(rCalfPos) + rCalfPos:Distance(rFootPos)
				local measured = (lLen + rLen) * 0.5
				if measured > 20 then
					state.measuredLegLength = measured
				end
			end
		end
	end
	
	-- Procedural stepper for stairs
	local prevStairMode = state.stairs and state.stairs.mode or false
	local prevStairConf = state.stairs and state.stairs.confidence or 0
	local lUsePos = lFootPos
	local rUsePos = rFootPos
	
	if onGround and not crouch.inTransition then
		local prevEventH = math.max((state.stairs and state.stairs.eventHeight or 0) * modelScale, 4)
		local strideLen = math.Clamp(prevEventH * 1.5, legLength * 0.35, legLength * 0.65)
		local liftH = math.max(prevEventH * 0.65, 4 * modelScale)
		
		local moveDir
		if vel2D >= 5 then
			moveDir = Vector(vel.x / vel2D, vel.y / vel2D, 0)
		else
			moveDir = ply:GetAngles():Forward()
			moveDir.z = 0
			moveDir:Normalize()
			if moveDir:LengthSqr() < 0.1 then moveDir = Vector(1, 0, 0) end
		end
		
		local rightDir = Vector(moveDir.y, -moveDir.x, 0)
		local halfWidth = math.max(legLength * 0.1, 3)
		local playerGroundPos = ply:GetPos()
		local upClear = prevEventH * 2 + 8
		
		local lBase = Vector(playerGroundPos.x - rightDir.x * halfWidth, playerGroundPos.y - rightDir.y * halfWidth, playerGroundPos.z)
		local rBase = Vector(playerGroundPos.x + rightDir.x * halfWidth, playerGroundPos.y + rightDir.y * halfWidth, playerGroundPos.z)
		local lTarget = PredictLanding(ply, lBase, moveDir, strideLen * 0.9, upClear, groundDist, soleOffset)
		local rTarget = PredictLanding(ply, rBase, moveDir, strideLen * 0.9, upClear, groundDist, soleOffset)
		
		local lProc = UpdateStepperFoot(state.legs.left, state.legs.right, {
			stairMode = prevStairMode and prevStairConf >= 0.4,
			stairConfidence = prevStairConf,
			playerPos = playerGroundPos,
			moveDir = moveDir,
			strideLen = strideLen,
			liftHeight = liftH,
			vel2D = vel2D,
			dt = dt,
			currentLock = state.legs.left.lockPos,
			rawFootPos = lFootPos,
			swingTarget = lTarget,
		})
		local rProc = UpdateStepperFoot(state.legs.right, state.legs.left, {
			stairMode = prevStairMode and prevStairConf >= 0.4,
			stairConfidence = prevStairConf,
			playerPos = playerGroundPos,
			moveDir = moveDir,
			strideLen = strideLen,
			liftHeight = liftH,
			vel2D = vel2D,
			dt = dt,
			currentLock = state.legs.right.lockPos,
			rawFootPos = rFootPos,
			swingTarget = rTarget,
		})
		
		if lProc then lUsePos = lProc end
		if rProc then rUsePos = rProc end
	else
		if state.legs.left.proc and (state.legs.left.proc.blendT or 0) > 0 then
			local lProc = UpdateStepperFoot(state.legs.left, state.legs.right, {
				stairMode = false, dt = dt,
				rawFootPos = lFootPos,
				currentLock = state.legs.left.lockPos,
				playerPos = ply:GetPos(),
				moveDir = Vector(1,0,0),
				strideLen = 20,
				liftHeight = 8,
				vel2D = 0,
			})
			if lProc then lUsePos = lProc end
		end
		if state.legs.right.proc and (state.legs.right.proc.blendT or 0) > 0 then
			local rProc = UpdateStepperFoot(state.legs.right, state.legs.left, {
				stairMode = false, dt = dt,
				rawFootPos = rFootPos,
				currentLock = state.legs.right.lockPos,
				playerPos = ply:GetPos(),
				moveDir = Vector(1,0,0),
				strideLen = 20,
				liftHeight = 8,
				vel2D = 0,
			})
			if rProc then rUsePos = rProc end
		end
	end
	
	-- Multi-point ground sampling
	local lSamples = SampleFoot(ply, lUsePos, lFootAng, traceStartZ, groundDist, true, soleOffset)
	local rSamples = SampleFoot(ply, rUsePos, rFootAng, traceStartZ, groundDist, false, soleOffset)
	local lContact = ResolveContact(lSamples, lUsePos, vector_up)
	local rContact = ResolveContact(rSamples, rUsePos, vector_up)
	
	-- Validate contacts
	local lValidation = ValidateContact(lContact, lSamples, lUsePos.z, soleOffset)
	local rValidation = ValidateContact(rContact, rSamples, rUsePos.z, soleOffset)
	
	local idle = UpdateIdle(state, onGround and stabilizeIdle, vel2D, velZ, idleVelThresh, lUsePos, rUsePos)
	local lSpeed = MeasureFootSpeed(state.legs.left, lUsePos, dt)
	local rSpeed = MeasureFootSpeed(state.legs.right, rUsePos, dt)
	
	if antiClip then
		if not lValidation.isValid and lValidation.invalidReason == "penetrating" then
			state.legs.left.planted = false
			state.legs.left.lockPos = nil
		end
		if not rValidation.isValid and rValidation.invalidReason == "penetrating" then
			state.legs.right.planted = false
			state.legs.right.lockPos = nil
		end
	end
	
	local support = DetermineSupportSide(lContact, rContact, state.legs.left, state.legs.right)
	local effectiveOnGround = onGround and not crouch.inTransition
	
	-- Handle procedural stepper swing phase
	local lProcSwinging = state.legs.left.proc and state.legs.left.proc.phase == "swinging"
	local rProcSwinging = state.legs.right.proc and state.legs.right.proc.phase == "swinging"
	
	local function ProcContact(c)
		return { hasHit = false, position = c.position, normal = c.normal, supportDistance = c.supportDistance, samples = c.samples, surfaceType = c.surfaceType, surfaceStable = c.surfaceStable }
	end
	
	local lContactForState = lProcSwinging and ProcContact(lContact) or lContact
	local rContactForState = rProcSwinging and ProcContact(rContact) or rContact
	
	local footData = function(contact, rawPos, speed, side)
		return {
			onGround = effectiveOnGround,
			idleActive = idle.active and not crouch.inTransition,
			isSupportFoot = support == side,
			contact = contact,
			rawFootPos = rawPos,
			footSpeed = speed,
			lockStrength = lockStrength,
			releaseSpeed = releaseSpeed,
			stairMode = state.stairs and state.stairs.mode or false,
			stairConfidence = state.stairs and state.stairs.confidence or 0,
			stairReleaseMultiplier = stairReleaseMul,
		}
	end
	
	local lResult = UpdateFoot(state.legs.left, footData(lContactForState, lUsePos, lSpeed, "left"))
	local rResult = UpdateFoot(state.legs.right, footData(rContactForState, rUsePos, rSpeed, "right"))
	
	local bodyDrop, lReqDrop, rReqDrop = 0, 0, 0
	local lKnee, rKnee = 0, 0
	local lFootRot, rFootRot = Angle(), Angle()
	local dynSoleCorr = 0
	local penetrationCorrL, penetrationCorrR = 0, 0
	
	if onGround then
		local lDist = lContact.hasHit and lContact.supportDistance or traceStartOff
		local rDist = rContact.hasHit and rContact.supportDistance or traceStartOff
		lReqDrop = math.max(lDist - traceStartOff, 0)
		rReqDrop = math.max(rDist - traceStartOff, 0)
		
		-- Anti-clip body-drop correction
		if antiClip then
			if not lValidation.isValid and lValidation.invalidReason == "penetrating" and lValidation.highestValidZ > -math.huge then
				lReqDrop = math.max(traceStartZ - lValidation.highestValidZ - traceStartOff, 0)
			end
			if not rValidation.isValid and rValidation.invalidReason == "penetrating" and rValidation.highestValidZ > -math.huge then
				rReqDrop = math.max(traceStartZ - rValidation.highestValidZ - traceStartOff, 0)
			end
		end
		
		-- Dynamic sole correction
		if dynamicSole then
			local dynState = GetDynSoleState(ply)
			local lPen = lValidation.penetrationCount
			local rPen = rValidation.penetrationCount
			local totalPen = lPen + rPen
			
			if totalPen > 2 then
				dynState.correction = dynState.correction + 0.04 * dt * 60
			elseif totalPen > 0 then
				dynState.correction = dynState.correction + 0.01 * dt * 60
			else
				dynState.correction = dynState.correction * (1 - 0.8 * dt)
			end
			dynState.correction = math.Clamp(dynState.correction, 0, 1.5)
			dynSoleCorr = dynState.correction
			
			lReqDrop = math.max(lReqDrop - dynSoleCorr, 0)
			rReqDrop = math.max(rReqDrop - dynSoleCorr, 0)
		end
		
		-- Stair detection
		local stairsState = state.stairs or {}
		local prevLReq = stairsState.prevLeftReq or lReqDrop
		local prevRReq = stairsState.prevRightReq or rReqDrop
		local leftRise = math.max(lReqDrop - prevLReq, 0)
		local rightRise = math.max(rReqDrop - prevRReq, 0)
		local leftDrop = math.max(prevLReq - lReqDrop, 0)
		local rightDrop = math.max(prevRReq - rReqDrop, 0)
		
		local maxRise = math.max(leftRise, rightRise)
		local maxDrop = math.max(leftDrop, rightDrop)
		local stairAsymmetry = math.abs(lReqDrop - rReqDrop)
		local clampedMinStep = math.max(stepMinHeight * modelScale, 2)
		local clampedMaxStep = math.max(stepMaxHeight * modelScale, clampedMinStep + 2)
		local stairRangeEvent = math.max(maxRise, maxDrop)
		local stairHeightInRange = (stairRangeEvent >= clampedMinStep and stairRangeEvent <= clampedMaxStep)
			or (stairAsymmetry >= clampedMinStep * 0.8 and stairAsymmetry <= clampedMaxStep * 1.9)
		local movementEligible = vel2D >= math.max(idleVelThresh * 0.7, 2) and math.abs(velZ) <= 140
		local stairSignalStrong = lContact.surfaceStable or rContact.surfaceStable or stairAsymmetry >= clampedMinStep
		local stairEligible = movementEligible and stairHeightInRange and lContact.surfaceStable and stairSignalStrong
		
		local stairRuntime = UpdateStairSequence(state, {
			leftRise = leftRise,
			rightRise = rightRise,
			leftDrop = leftDrop,
			rightDrop = rightDrop,
			heightDiff = stairAsymmetry,
			stepMax = clampedMaxStep,
			edgeConfidence = 0,
			surfaceStable = lContact.surfaceStable or rContact.surfaceStable,
			sequenceWindow = stepWindow,
			eligible = stairEligible,
		})
		
		state.stairs.prevLeftReq = lReqDrop
		state.stairs.prevRightReq = rReqDrop
		
		-- Calculate body drop
		local avgDrop = (lReqDrop + rReqDrop) * 0.5
		local maxDrop = math.max(lReqDrop, rReqDrop)
		local heightDiff = math.abs(lReqDrop - rReqDrop)
		
		local dropBias = math.Clamp(0.75 + (heightDiff / math.max(legLength * 0.2, 6)) * 0.25, 0.75, 1.0)
		local reqDrop = Lerp(dropBias, avgDrop, maxDrop)
		
		-- Ensure body drops enough for lower foot to reach ground
		local kneeRange = math.max(legLength * 0.50, 10)
		local maxKneeExtRad = math.rad(math.abs(MIN_KNEE_BEND))
		local maxKneeExtDist = math.sin(maxKneeExtRad) * kneeRange
		local minRequiredDrop = math.max(maxDrop - maxKneeExtDist * 0.85, 0)
		reqDrop = math.max(reqDrop, minRequiredDrop)
		
		local unevenFactor = math.Clamp(heightDiff / 10, 0, 1)
		local terrainNeed = math.Clamp(maxDrop / math.max(bodyDropTarget * 0.5, 0.3), 0, 1)
		local desiredDrop = reqDrop + Lerp(unevenFactor, bodyDropTarget, bodyDropUneven) * terrainNeed + heightDiff * unevenDropScale * 0.2
		
		if stairRuntime.mode then
			local stepBias = math.Clamp(stairRuntime.eventHeight / math.max(clampedMaxStep, 1), 0, 1)
			desiredDrop = desiredDrop + stairRuntime.eventHeight * 0.1 * stepBias
			desiredDrop = desiredDrop - stairRuntime.downHeight * 0.06
		end
		
		local dropCap = math.min(groundDist * 0.95, legLength * 0.95, maxBodyDropCVar)
		desiredDrop = math.Clamp(desiredDrop, 0, math.max(dropCap, 2))
		
		if state.bodyDrop then
			local maxStep = math.max(5 * dt * 60, 0.8)
			if stairRuntime.mode then
				local adaptiveBoost = stairRuntime.eventHeight * math.Clamp(stairStepMul, 0.25, 2)
				maxStep = maxStep + math.Clamp(adaptiveBoost * 0.3, 0, 12)
				if stairRuntime.downHeight > stairRuntime.upHeight then
					maxStep = maxStep * 0.7
				end
			end
			if crouch.inTransition then
				maxStep = maxStep * 0.25
				local transitionBlend = math.Clamp(crouch.transitionTime / CROUCH_BLEND_TIME, 0, 1)
				desiredDrop = desiredDrop * transitionBlend
			end
			desiredDrop = math.Clamp(desiredDrop, state.bodyDrop - maxStep, state.bodyDrop + maxStep)
		end
		
		state.bodyDrop = desiredDrop
		bodyDrop = desiredDrop
		
		-- Calculate knee bends
		lKnee = math.deg(math.asin(math.Clamp((bodyDrop - lReqDrop) / kneeRange, -1, 1)))
		rKnee = math.deg(math.asin(math.Clamp((bodyDrop - rReqDrop) / kneeRange, -1, 1)))
		if lKnee > 0 then lKnee = lKnee * bendBoost end
		if rKnee > 0 then rKnee = rKnee * bendBoost end
		lKnee = math.Clamp(lKnee, MIN_KNEE_BEND, MAX_KNEE_BEND)
		rKnee = math.Clamp(rKnee, MIN_KNEE_BEND, MAX_KNEE_BEND)
		
		-- Anti-clip knee correction
		if antiClip then
			local maxBendAngle = MAX_KNEE_BEND / math.max(bendBoost, 1)
			local maxBendDist = math.sin(math.rad(maxBendAngle)) * kneeRange
			
			local lExcess = bodyDrop - lReqDrop - maxBendDist
			local rExcess = bodyDrop - rReqDrop - maxBendDist
			
			if lExcess > 0.5 and lKnee >= MAX_KNEE_BEND - 1 then
				penetrationCorrL = lExcess
			end
			if rExcess > 0.5 and rKnee >= MAX_KNEE_BEND - 1 then
				penetrationCorrR = rExcess
			end
			
			local maxCorr = math.max(penetrationCorrL, penetrationCorrR)
			if maxCorr > 0.5 then
				local stairCorrBoost = state.stairs and state.stairs.mode and (1 + (state.stairs.confidence or 0) * 0.35) or 1
				bodyDrop = math.max(bodyDrop - maxCorr * 0.6 * stairCorrBoost, 0)
				state.bodyDrop = bodyDrop
				
				lKnee = math.deg(math.asin(math.Clamp((bodyDrop - lReqDrop) / kneeRange, -1, 1)))
				rKnee = math.deg(math.asin(math.Clamp((bodyDrop - rReqDrop) / kneeRange, -1, 1)))
				if lKnee > 0 then lKnee = lKnee * bendBoost end
				if rKnee > 0 then rKnee = rKnee * bendBoost end
				lKnee = math.Clamp(lKnee, MIN_KNEE_BEND, MAX_KNEE_BEND)
				rKnee = math.Clamp(rKnee, MIN_KNEE_BEND, MAX_KNEE_BEND)
			end
		end
		
		lFootRot = ComputeFootRotation(lContact.samples, footRotScale)
		rFootRot = ComputeFootRotation(rContact.samples, footRotScale)
	else
		-- Air handling
		if state.stairs then
			state.stairs.mode = false
			state.stairs.confidence = 0
		end
		local airBlend = math.Clamp(math.abs(velZ) / 260, 0, 1)
		local moveBlend = math.Clamp(vel2D / 160, 0, 1)
		local airCycle = CurTime() * (AIR_SWING_SPEED + moveBlend * 3)
		local swing = math.sin(airCycle) * AIR_SWING_AMP * moveBlend
		
		bodyDrop = math.min((state.bodyDrop or 0) * (1 - dt * 4), AIR_BODY_DROP_MAX * modelScale)
		if bodyDrop <= 0.05 then
			bodyDrop = 0
			state.bodyDrop = nil
		else
			state.bodyDrop = bodyDrop
		end
		
		local airKnee = Lerp(airBlend, AIR_KNEE_MIN, AIR_KNEE_MAX) + moveBlend * 3
		lKnee = math.Clamp(airKnee + swing, AIR_KNEE_MIN, AIR_KNEE_MAX)
		rKnee = math.Clamp(airKnee - swing, AIR_KNEE_MIN, AIR_KNEE_MAX)
		
		local footPitch = Lerp(math.Clamp((velZ + 250) / 500, 0, 1), AIR_FOOT_PITCH_DESCEND, AIR_FOOT_PITCH_ASCEND)
		lFootRot = Angle(0, footPitch + swing * 0.4, 0)
		rFootRot = Angle(0, footPitch - swing * 0.4, 0)
		
		if dynamicSole then
			local dynState = GetDynSoleState(ply)
			dynState.correction = dynState.correction * 0.95
		end
	end
	
	-- Lean calculation
	local baseAng = Angle()
	local leanAng = Angle()
	if leanEnabled then
		local bodyAng = ply:GetAngles()
		bodyAng.p = 0
		local right = bodyAng:Right()
		local lateral = vel.x * right.x + vel.y * right.y
		leanAng = Angle(0, 0, -math.Clamp(lateral / 8, -10, 10))
	end
	
	-- Smooth knee angles
	local smoothFactor = math.Clamp(smoothing / 50, 0.02, 1)
	state.leftKnee = Lerp(smoothFactor, state.leftKnee, lKnee)
	state.rightKnee = Lerp(smoothFactor, state.rightKnee, rKnee)
	
	return {
		bodyDrop = bodyDrop,
		baseAng = baseAng,
		leanAng = leanAng,
		leftThighAngle = Angle(0, -state.leftKnee, 0),
		leftCalfAngle = Angle(0, state.leftKnee, 0),
		leftFootAngle = lFootRot,
		rightThighAngle = Angle(0, -state.rightKnee, 0),
		rightCalfAngle = Angle(0, state.rightKnee, 0),
		rightFootAngle = rFootRot,
		bones = {
			lThigh = lThigh,
			lCalf = lCalf,
			lFoot = lFoot,
			rThigh = rThigh,
			rCalf = rCalf,
			rFoot = rFoot,
		}
	}
end

-- Apply IK using blended bone manipulation with spring smoothing (compatible with organism/health indicator)
function hg.ApplyIKFoot(ent, ikResult)
	if not ikResult then return end
	
	local ply = ent
	local drop = ikResult.bodyDrop or 0
	local bones = ikResult.bones
	local s = EnsureApplyState(ply)
	local dt = math.Clamp(FrameTime(), 1 / 300, 1 / 20)
	
	local smoothing = math.Clamp(hg.IKFootConfig.smoothing:GetFloat(), 1, 50)
	local rotSmoothing = math.Clamp(hg.IKFootConfig.rotationSmoothing:GetFloat(), 1, 60)
	local posST = math.max(0.02, 0.28 / math.max(smoothing, 1))
	local rotST = math.max(0.02, 0.28 / math.max(rotSmoothing, 1))
	
	local targets = {
		leftThigh = ikResult.leftThighAngle,
		leftCalf = ikResult.leftCalfAngle,
		leftFoot = ikResult.leftFootAngle,
		rightThigh = ikResult.rightThighAngle,
		rightCalf = ikResult.rightCalfAngle,
		rightFoot = ikResult.rightFootAngle,
		lean = ikResult.leanAng or Angle(),
	}
	
	-- Spring smooth all angles
	for _, name in ipairs(SPRING_FIELDS) do
		s[name], s[name .. "Vel"] = SpringAngle(s[name], s[name .. "Vel"], targets[name], rotST, dt)
	end
	
	-- Apply body drop to pelvis (bone 0)
	ApplyBlendedBonePosition(ent, 0, Vector(0, 0, -drop))
	
	-- Apply lean angle if enabled
	if ikResult.leanAng then
		ApplyBlendedBoneAngles(ent, 0, s.lean)
	end
	
	-- Apply leg angles using blended manipulation
	if bones.lThigh then
		ApplyBlendedBoneAngles(ent, bones.lThigh, s.leftThigh)
	end
	
	if bones.lCalf then
		ApplyBlendedBoneAngles(ent, bones.lCalf, s.leftCalf)
	end
	
	if bones.lFoot then
		ApplyBlendedBoneAngles(ent, bones.lFoot, s.leftFoot)
	end
	
	if bones.rThigh then
		ApplyBlendedBoneAngles(ent, bones.rThigh, s.rightThigh)
	end
	
	if bones.rCalf then
		ApplyBlendedBoneAngles(ent, bones.rCalf, s.rightCalf)
	end
	
	if bones.rFoot then
		ApplyBlendedBoneAngles(ent, bones.rFoot, s.rightFoot)
	end
end

concommand.Add("hg_ik_foot_reset", function()
	hg.HardResetIKFoot()
	chat.AddText(Color(100, 255, 100), "[HG IK Foot] ", Color(255, 255, 255), "Reset complete")
end)

-- Spring smoothing for smooth bone movement (from iker foot reference)
local function IsFiniteNumber(value)
	return isnumber(value) and value == value and value > -math.huge and value < math.huge
end

local function IsFiniteVector(vec)
	return isvector(vec)
		and IsFiniteNumber(vec.x)
		and IsFiniteNumber(vec.y)
		and IsFiniteNumber(vec.z)
end

local function SpringScalar(current, velocity, target, smoothTime, dt)
	if not (IsFiniteNumber(current) and IsFiniteNumber(velocity) and IsFiniteNumber(target)) then
		return IsFiniteNumber(target) and target or 0, 0
	end
	smoothTime = math.max(smoothTime, 0.0001)
	local omega = 2 / smoothTime
	local x = omega * dt
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
	local change = current - target
	local temp = (velocity + omega * change) * dt
	local newVelocity = (velocity - omega * temp) * exp
	local newValue = target + (change + temp) * exp
	if not IsFiniteNumber(newValue) then return IsFiniteNumber(target) and target or 0, 0 end
	if not IsFiniteNumber(newVelocity) then newVelocity = 0 end
	return newValue, newVelocity
end

local function SpringAngle(current, velocity, target, smoothTime, dt)
	local targetP = current.p + math.AngleDifference(target.p, current.p)
	local targetY = current.y + math.AngleDifference(target.y, current.y)
	local targetR = current.r + math.AngleDifference(target.r, current.r)
	local p, pv = SpringScalar(current.p, velocity.p, targetP, smoothTime, dt)
	local y, yv = SpringScalar(current.y, velocity.y, targetY, smoothTime, dt)
	local r, rv = SpringScalar(current.r, velocity.r, targetR, smoothTime, dt)
	return Angle(p, y, r), Angle(pv, yv, rv)
end

local SPRING_FIELDS = {"leftThigh", "leftCalf", "leftFoot", "rightThigh", "rightCalf", "rightFoot", "lean"}

local function EnsureApplyState(ply)
	if not ply.IKApplyState then
		local s = {
			basePos = Vector(), basePosVel = Vector(),
			baseAng = Angle(), baseAngVel = Angle(),
		}
		for _, name in ipairs(SPRING_FIELDS) do
			s[name] = Angle()
			s[name .. "Vel"] = Angle()
		end
		ply.IKApplyState = s
	end
	return ply.IKApplyState
end

-- Blend state tracking to prevent bone drift
local function GetIKBlendState(ply)
	ply.IKBlendState = ply.IKBlendState or { pos = {}, ang = {} }
	return ply.IKBlendState
end

local NEAR_EPS_VEC = 0.01
local NEAR_EPS_ANG = 0.05

local function VecNear(a, b, eps)
	eps = eps or NEAR_EPS_VEC
	return math.abs(a.x - b.x) <= eps
		and math.abs(a.y - b.y) <= eps
		and math.abs(a.z - b.z) <= eps
end

local function AngNear(a, b, eps)
	eps = eps or NEAR_EPS_ANG
	return math.abs(math.AngleDifference(a.p, b.p)) <= eps
		and math.abs(math.AngleDifference(a.y, b.y)) <= eps
		and math.abs(math.AngleDifference(a.r, b.r)) <= eps
end

local function GetCurrentBonePosition(ply, bone)
	if bone == nil then return Vector() end
	return Vector(ply:GetManipulateBonePosition(bone) or Vector())
end

local function GetCurrentBoneAngles(ply, bone)
	if bone == nil then return Angle() end
	return Angle(ply:GetManipulateBoneAngles(bone) or Angle())
end

local function SetBonePosition(ply, bone, pos)
	if bone == nil then return end
	ply:ManipulateBonePosition(bone, pos)
end

local function SetBoneAngles(ply, bone, ang)
	if bone == nil then return end
	ply:ManipulateBoneAngles(bone, ang)
end

local function ApplyBlendedBonePosition(ply, bone, offset)
	if bone == nil then return end
	local state = GetIKBlendState(ply)
	local entry = state.pos[bone]
	if not entry then
		entry = { applied = Vector(), final = nil }
		state.pos[bone] = entry
	end

	local current = GetCurrentBonePosition(ply, bone)
	local base = current
	if entry.final and VecNear(current, entry.final) then
		base = current - entry.applied
	end

	local final = base + offset
	SetBonePosition(ply, bone, final)
	entry.applied = Vector(offset)
	entry.final = Vector(final)
end

local function ApplyBlendedBoneAngles(ply, bone, offset)
	if bone == nil then return end
	local state = GetIKBlendState(ply)
	local entry = state.ang[bone]
	if not entry then
		entry = { applied = Angle(), final = nil }
		state.ang[bone] = entry
	end

	local current = GetCurrentBoneAngles(ply, bone)
	local base = current
	if entry.final and AngNear(current, entry.final) then
		base = Angle(current.p - entry.applied.p, current.y - entry.applied.y, current.r - entry.applied.r)
	end

	local final = Angle(base.p + offset.p, base.y + offset.y, base.r + offset.r)
	SetBoneAngles(ply, bone, final)
	entry.applied = Angle(offset)
	entry.final = Angle(final)
end

local function StripIKFromBones(ply, bones)
	local blendState = GetIKBlendState(ply)
	if not blendState then return end

	local posEntry = blendState.pos[0]
	if posEntry and posEntry.applied and posEntry.final then
		local current = GetCurrentBonePosition(ply, 0)
		if VecNear(current, posEntry.final, 0.1) then
			SetBonePosition(ply, 0, current - posEntry.applied)
		end
	end

	local allBones = {0, bones.lThigh, bones.rThigh, bones.lCalf, bones.rCalf, bones.lFoot, bones.rFoot}
	for _, bone in ipairs(allBones) do
		if bone then
			local angEntry = blendState.ang[bone]
			if angEntry and angEntry.applied and angEntry.final then
				local current = GetCurrentBoneAngles(ply, bone)
				if AngNear(current, angEntry.final, 0.15) then
					SetBoneAngles(ply, bone, Angle(current.p - angEntry.applied.p, current.y - angEntry.applied.y, current.r - angEntry.applied.r))
				end
			end
		end
	end
end

local function GetIKBones(ply)
	local model = ply:GetModel()
	local bones = ply.IKBones
	if bones and bones.model == model then return bones end

	if bones then ply.IKBlendState = nil end

	bones = {
		model = model,
		lFoot = ply:LookupBone("ValveBiped.Bip01_L_Foot"),
		rFoot = ply:LookupBone("ValveBiped.Bip01_R_Foot"),
		lCalf = ply:LookupBone("ValveBiped.Bip01_L_Calf"),
		rCalf = ply:LookupBone("ValveBiped.Bip01_R_Calf"),
		lThigh = ply:LookupBone("ValveBiped.Bip01_L_Thigh"),
		rThigh = ply:LookupBone("ValveBiped.Bip01_R_Thigh"),
	}

	ply.IKBones = bones
	return bones
end

local RESET_COOLDOWN = 0.5

-- Main IK hook - runs every frame for every player (compatible with organism/health indicator)
hook.Add("PostPlayerDraw", "HG_IKFoot_PostPlayerDraw", function(ply)
	if not IsValid(ply) then return end

	local alive = ply:Alive()
	if ply.IKWasAlive == false and alive then
		hg.HardResetIKFoot(ply)
		ply.IKWasAlive = alive
		return
	end
	ply.IKWasAlive = alive

	if not alive then
		hg.ResetIKFoot(ply)
		return
	end

	if not hg.IKFootConfig.enabled:GetBool() then
		hg.ResetIKFoot(ply)
		return
	end

	if ply:InVehicle() then
		hg.ResetIKFoot(ply)
		return
	end

	-- Don't run IK if organism is in critical state to avoid animation conflicts
	if ply.organism and (ply.organism.otrub or ply.organism.brain > 0.1) then
		hg.ResetIKFoot(ply)
		return
	end

	local bones = GetIKBones(ply)
	if not bones.lFoot or not bones.rFoot or not bones.lCalf or not bones.rCalf or not bones.lThigh or not bones.rThigh then
		hg.ResetIKFoot(ply)
		return
	end

	StripIKFromBones(ply, bones)
	ply:SetupBones()

	local ok, errOrResult = pcall(function()
		local ikResult = hg.CalculateIKFoot(ply, ply)
		if not ikResult then return nil end
		hg.ApplyIKFoot(ply, ikResult)
		return ikResult
	end)

	if not ok then
		ply.IKFailCount = (ply.IKFailCount or 0) + 1
		if ply.IKFailCount >= 10 and (ply.IKLastResetTime or 0) + RESET_COOLDOWN <= CurTime() then
			hg.HardResetIKFoot(ply)
			ply.IKLastResetTime = CurTime()
			ply.IKFailCount = 0
		end
		return
	end

	ply.IKFailCount = 0
end)
