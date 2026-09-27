local hg_euphoria_getup_stumble = CreateConVar("hg_euphoria_getup_stumble", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "grounded fake ragdoll balance and stumbling (Artagdoll-style)", 0, 1)
local hg_euphoria_cover = CreateConVar("hg_euphoria_cover", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "fake ragdolls cover their face while stumbling (Artagdoll Cower)", 0, 1)

-- Port of Artagdoll's stumble behaviour (system_/dms/behaviors/stumble.lua) onto
-- player fake ragdolls. It reads the same ar_* Stumble settings, so the Artagdoll
-- spawnmenu tuning applies here too. The face cover is Artagdoll's own controller
-- entity playing its "Cower" sequence; nothing here runs through DMS.
local IKSystem = include("system_/utils/IKChain.lua")

local AR_MODEL = "models/AREAnims/model_anim.mdl"
local COVER_STRENGTH = 3
local COVER_RATE = 0.5
local START_DELAY = 0.05
local START_WINDOW = 0.5
local HIT_WINDOW = 0.5
local HIT_MIN_DMG = 8
local UPRIGHT_THRESHOLD = 0.05
local UPRIGHT_TRACE = 60
local UPRIGHT_MIN_HEIGHT = 23.5
local FOOT_HULL_MINS = Vector(-2, -2, 0)
local FOOT_HULL_MAXS = Vector(2, 2, 2)

local AR_DEFAULTS = {
	PushDuration = 2,
	PushPeakForce = 100,
	MaxVelocityClamp = 350,
	VelocitySmoothing = 10,
	MaxStepUpHeight = 18,
	MaxStepDownHeight = 80,
	SearchHeightBuffer = 25,
	StepHeight = 20,
	HipTargetHeight = 50,
	TimeBeforeDecay = 4,
	DecayDuration = 3,
	MaxSlopeAngle = 45,
	StepTriggerForward = 15,
	MinMovementSpeed = 15,
	StationaryThreshold = 15,
	AbsoluteTraceDepth = 8192,
	PredictionTime = 0.35,
	MinStepInterval = 0.25,
}

local stumbling = {}

local function readConfig()
	local cfg = {}
	for key, default in pairs(AR_DEFAULTS) do
		local cv = GetConVar("ar_" .. key)
		cfg[key] = cv and cv:GetFloat() or default
	end
	return cfg
end

local function isValidNumber(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function sanitizeVector(vec, fallback)
	if not vec or not isvector(vec) then return fallback end
	if not isValidNumber(vec.x) or not isValidNumber(vec.y) or not isValidNumber(vec.z) then return fallback end
	return vec
end

local function getBonePhys(ragdoll, boneName)
	local boneID = ragdoll:LookupBone(boneName)
	if not boneID then return nil end
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		if IsValid(phys) and ragdoll:TranslatePhysBoneToBone(i) == boneID then
			return phys
		end
	end
end

local function groundFromTrace(cfg, tr, pos, currentFootZ)
	if not tr.Hit or not sanitizeVector(tr.HitPos, nil) then return end

	local normal = tr.HitNormal
	local slopeAngle = math.deg(math.acos(math.Clamp(normal.z, -1, 1)))
	if slopeAngle >= 90 then return Vector(pos.x, pos.y, currentFootZ), Vector(0, 0, 1) end
	if slopeAngle > cfg.MaxSlopeAngle then return end

	local heightChange = tr.HitPos.z - currentFootZ
	if heightChange <= cfg.MaxStepUpHeight and heightChange >= -cfg.MaxStepDownHeight then
		return tr.HitPos, normal
	end
end

local function findGroundPosition(cfg, pos, ragdoll, currentFootZ, pelvisZ)
	if not sanitizeVector(pos, nil) then return nil, nil end

	currentFootZ = isValidNumber(currentFootZ) and currentFootZ or pos.z
	pelvisZ = isValidNumber(pelvisZ) and pelvisZ or currentFootZ

	local searchUp = math.max(cfg.MaxStepUpHeight, math.abs(pelvisZ - currentFootZ) * 0.5)
	local searchStart = Vector(pos.x, pos.y, pos.z + searchUp + cfg.SearchHeightBuffer)
	local searchEnd = Vector(pos.x, pos.y, pos.z - cfg.AbsoluteTraceDepth)

	local ground, normal = groundFromTrace(cfg, util.TraceHull({
		start = searchStart,
		endpos = searchEnd,
		mins = FOOT_HULL_MINS,
		maxs = FOOT_HULL_MAXS,
		mask = MASK_SOLID_BRUSHONLY,
		filter = ragdoll,
	}), pos, currentFootZ)
	if ground then return ground, normal end

	ground, normal = groundFromTrace(cfg, util.TraceLine({
		start = searchStart,
		endpos = searchEnd,
		mask = MASK_SOLID_BRUSHONLY,
		filter = ragdoll,
	}), pos, currentFootZ)
	if ground then return ground, normal end

	return Vector(pos.x, pos.y, currentFootZ), Vector(0, 0, 1)
end

local function findGroundForBalance(pos, ragdoll)
	local tr = util.TraceLine({
		start = Vector(pos.x, pos.y, pos.z + 10),
		endpos = Vector(pos.x, pos.y, pos.z - 200),
		mask = MASK_SOLID_BRUSHONLY,
		filter = ragdoll,
	})
	if tr.Hit and sanitizeVector(tr.HitPos, nil) then return tr.HitPos end
	return Vector(pos.x, pos.y, pos.z - 200)
end

-- Artagdoll's stumble / injured split (dms_physics.lua HandleTransitions)
local function isUpright(ply, ragdoll)
	local spine = getBonePhys(ragdoll, "ValveBiped.Bip01_Spine2")
	if not IsValid(spine) then return false end
	local ang = spine:GetAngles()
	if type(ang) ~= "Angle" or ang:Forward().z <= UPRIGHT_THRESHOLD then return false end

	local center = ragdoll:WorldSpaceCenter()
	local tr = util.TraceLine({
		start = center,
		endpos = center - Vector(0, 0, UPRIGHT_TRACE),
		mask = MASK_SOLID_BRUSHONLY,
		filter = {ply, ragdoll},
	})
	return tr.Hit and UPRIGHT_TRACE * tr.Fraction > UPRIGHT_MIN_HEIGHT
end

local function legsUsable(org)
	return not (org.llegamputated or org.llegupamputated or org.rlegamputated or org.rlegupamputated or org.lleg == 1 or org.rleg == 1)
end

local function canStumble(ply, ragdoll)
	if not ply:Alive() then return false end
	local org = ply.organism
	if not org or org.otrub or not org.canmove or not legsUsable(org) then return false end
	if ragdoll.isSliding or ragdoll.isDropkicking then return false end
	return true
end

local function makePush(st, dmgpos, fallbackDir)
	if not IsValid(st.pelvis) then return end
	local pelvisPos = st.pelvis:GetPos()

	local dir
	if dmgpos and dmgpos:DistToSqr(pelvisPos) < 200 * 200 then
		dir = pelvisPos - dmgpos
		dir.z = 0
	end
	if (not dir or dir:LengthSqr() < 1) and fallbackDir then dir = Vector(fallbackDir.x, fallbackDir.y, 0) end
	if not dir or dir:LengthSqr() < 0.01 then return end
	dir:Normalize()

	st.push = { dir = dir, startTime = CurTime(), duration = st.cfg.PushDuration }
end

local function initLegs(st, ragdoll)
	st.footPositions = {}
	st.ghostPositions = {}
	st.lockedFootPositions = {}
	st.groundNormals = { Vector(0, 0, 1), Vector(0, 0, 1) }
	st.hasGroundContact = { false, false }
	st.legState = {
		[1] = { isStepping = false, progress = 0, isLocked = false, lastStepTime = 0 },
		[2] = { isStepping = false, progress = 0, isLocked = false, lastStepTime = 0 },
	}

	local pelvisPos = st.pelvis:GetPos()
	local pelvisAng = st.pelvis:GetAngles()
	pelvisAng.p = 0
	pelvisAng.r = 0

	local startVel = st.pelvis:GetVelocity()
	local flatStartVel = Vector(startVel.x, startVel.y, 0)

	for i = 1, 2 do
		local phys = getBonePhys(ragdoll, i == 1 and "ValveBiped.Bip01_L_Foot" or "ValveBiped.Bip01_R_Foot")
		local idealPos = sanitizeVector(LocalToWorld(Vector((i == 1 and 1 or -1) * 6, 0, 0), angle_zero, pelvisPos, pelvisAng), pelvisPos)

		if flatStartVel:Length() > 20 then
			local offset = flatStartVel * 0.4
			if offset:Length() > 45 then offset = offset:GetNormalized() * 45 end
			idealPos = idealPos + offset
		end

		local currentFootZ = IsValid(phys) and phys:GetPos().z or pelvisPos.z
		local ground, normal = findGroundPosition(st.cfg, Vector(idealPos.x, idealPos.y, currentFootZ), ragdoll, currentFootZ, pelvisPos.z)
		local finalPos = ground or (IsValid(phys) and phys:GetPos() or idealPos)

		st.ghostPositions[i] = Vector(finalPos.x, finalPos.y, finalPos.z)
		st.groundNormals[i] = normal or Vector(0, 0, 1)
		st.hasGroundContact[i] = ground ~= nil
		st.footPositions[i] = IsValid(phys) and phys:GetPos() or Vector(finalPos.x, finalPos.y, finalPos.z)
		st.lockedFootPositions[i] = Vector(st.footPositions[i].x, st.footPositions[i].y, st.footPositions[i].z)
	end
end

local function updateGhostPositions(st, ragdoll, isMoving, horizontalVel)
	local pelvisPos = st.pelvis:GetPos()
	local pelvisAng = st.pelvis:GetAngles()
	pelvisAng.p = 0
	pelvisAng.r = 0

	local prediction = horizontalVel * st.cfg.PredictionTime
	if prediction:Length() > 60 then prediction = prediction:GetNormalized() * 60 end

	for i = 1, 2 do
		if not isMoving and st.legState[i].isLocked then continue end

		local basePos = sanitizeVector(LocalToWorld(Vector((i == 1 and 1 or -1) * 7, 0, 0), angle_zero, pelvisPos, pelvisAng), pelvisPos)
		local idealPos = basePos + prediction
		local currentZ = st.ghostPositions[i] and st.ghostPositions[i].z or pelvisPos.z

		local ground, normal = findGroundPosition(st.cfg, Vector(idealPos.x, idealPos.y, currentZ), ragdoll, currentZ, pelvisPos.z)
		st.hasGroundContact[i] = ground ~= nil

		if ground then
			st.ghostPositions[i] = LerpVector(FrameTime() * (isMoving and 20 or 5), st.ghostPositions[i], ground)
			st.groundNormals[i] = normal or Vector(0, 0, 1)
		else
			st.ghostPositions[i] = st.ghostPositions[i] or Vector(idealPos.x, idealPos.y, pelvisPos.z - st.cfg.HipTargetHeight)
			st.groundNormals[i] = Vector(0, 0, 1)
		end
	end
end

local function updateStumble(st, ragdoll)
	local cfg = st.cfg
	local dt = FrameTime()
	local now = CurTime()

	local pelvisPos = st.pelvis:GetPos()
	local rawVel = st.pelvis:GetVelocity()
	if not isValidNumber(pelvisPos.x) then return end

	if st.push then
		local elapsed = now - st.push.startTime
		if elapsed < st.push.duration then
			local force = st.push.dir * (cfg.PushPeakForce * math.sin(elapsed / st.push.duration * math.pi))
			if sanitizeVector(force, nil) then
				st.pelvis:ApplyForceCenter(force)
				st.spine:ApplyForceCenter(force * 0.5)
			end
		else
			st.push = nil
		end
	end

	st.smoothedVelocity = LerpVector(dt * cfg.VelocitySmoothing, st.smoothedVelocity, Vector(rawVel.x, rawVel.y, 0))
	local safeVel = Vector(st.smoothedVelocity.x, st.smoothedVelocity.y, 0)
	local speed = safeVel:Length()
	if speed > cfg.MaxVelocityClamp then
		safeVel = safeVel:GetNormalized() * cfg.MaxVelocityClamp
		speed = cfg.MaxVelocityClamp
	end

	if now - st.lastGroundCheckTime > 0.05 then
		updateGhostPositions(st, ragdoll, speed > cfg.MinMovementSpeed, safeVel)
		st.lastGroundCheckTime = now
	end

	local stepSpeed = math.Clamp(3 + speed / 40, 3, 10)

	for i = 1, 2 do
		local state = st.legState[i]
		if state.isStepping then
			state.progress = state.progress + dt * stepSpeed
			if state.progress >= 1 then
				state.isStepping = false
				state.lastStepTime = now
				st.footPositions[i] = state.targetPos
				st.lockedFootPositions[i] = state.targetPos
			else
				local t = state.progress
				local nextPos = LerpVector(t, state.startPos, state.targetPos)
				nextPos.z = nextPos.z + math.sin(t * math.pi) * cfg.StepHeight
				st.footPositions[i] = nextPos
			end
		elseif speed < cfg.StationaryThreshold then
			if state.isLocked then
				st.footPositions[i] = LerpVector(0.3, st.footPositions[i], st.lockedFootPositions[i])
			else
				state.isLocked = true
				st.lockedFootPositions[i] = st.footPositions[i]
			end
		else
			state.isLocked = false

			local trigger = cfg.StepTriggerForward
			if st.footPositions[i]:DistToSqr(st.ghostPositions[i]) > trigger * trigger
				and not st.legState[i == 1 and 2 or 1].isStepping
				and now - state.lastStepTime > cfg.MinStepInterval then
				state.isStepping = true
				state.progress = 0
				state.startPos = st.footPositions[i]
				state.targetPos = findGroundPosition(cfg, st.ghostPositions[i], ragdoll, st.ghostPositions[i].z, pelvisPos.z) or st.ghostPositions[i]
			end
		end
	end

	for i = 1, 2 do
		local chain = st.ikChains[i]
		if chain then
			chain:SetTarget(sanitizeVector(st.footPositions[i], pelvisPos))
			chain:Update()
		end
	end

	local decayMult = math.Clamp(1 - (now - st.startTime - cfg.TimeBeforeDecay) / cfg.DecayDuration, 0, 1)
	local groundedLegs = (st.hasGroundContact[1] and 1 or 0) + (st.hasGroundContact[2] and 1 or 0)
	if groundedLegs == 0 then return end

	local feetMid = (st.footPositions[1] + st.footPositions[2]) / 2

	local groundBelowFeet = findGroundForBalance(feetMid, ragdoll)
	local diffZ = groundBelowFeet.z + cfg.HipTargetHeight - pelvisPos.z
	local damperForce = diffZ < 10 and rawVel.z * -12 or 0
	local totalZForce = (diffZ * 35 + damperForce) * decayMult
	if isValidNumber(totalZForce) then
		st.spine:ApplyForceCenter(Vector(0, 0, math.max(totalZForce, 0)))
	end

	-- no lateral correction while the push is live, or it rubber-bands the shove away
	local lateralOffset = pelvisPos - feetMid
	lateralOffset.z = 0
	if not st.push and lateralOffset:Length() > 2 then
		local correction = lateralOffset * -8 * decayMult
		if sanitizeVector(correction, nil) then st.pelvis:ApplyForceCenter(correction) end
	end
end

local function coverBones(org)
	local bones = { "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Head1" }
	if not (org.larmamputated or org.larmupamputated) then
		table.Add(bones, { "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand" })
	end
	if not (org.rarmamputated or org.rarmupamputated) then
		table.Add(bones, { "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand" })
	end
	return bones
end

local function stopCover(st)
	local cover = st.cover
	if not cover then return end
	st.cover = nil
	if IsValid(cover.ent) then cover.ent:Remove() end
end

local function startCover(st, ragdoll, org)
	if not hg_euphoria_cover:GetBool() then return end

	-- the controller's Initialize rewrites limb masses for Artagdoll NPC bodies; keep ours
	local saved = {}
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		if IsValid(phys) then saved[phys] = { phys:GetMass(), phys:GetInertia() } end
	end

	local ctrl = ents.Create("active_ragdoll_controller")
	if not IsValid(ctrl) then return end
	ctrl:SetModel(AR_MODEL)
	ctrl:SetTarget(ragdoll)
	ctrl:SetPos(ragdoll:GetPos())
	ctrl:SetAngles(angle_zero)
	ctrl:Spawn()
	ctrl:Activate()

	for phys, data in pairs(saved) do
		if IsValid(phys) then
			phys:SetMass(data[1])
			phys:SetInertia(data[2])
		end
	end

	local seq = ctrl:LookupSequence("Cower")
	if not seq or seq == -1 then
		ctrl:Remove()
		return
	end

	ctrl:SetBoneList(coverBones(org))
	ctrl:SetReactionStrength(COVER_STRENGTH)
	ctrl:ResetSequence(seq)
	ctrl:SetPlaybackRate(COVER_RATE)
	ctrl:SetCycle(0)

	st.cover = { ent = ctrl, pelvisBone = ctrl:LookupBone("ValveBiped.Bip01_Pelvis"), held = false }
end

-- Artagdoll's controller aims bones at the Cower pose in its own world space, so
-- keep the animation's pelvis lined up with the fake ragdoll's pelvis.
local function updateCover(st, ragdoll)
	local cover = st.cover
	local ctrl = cover.ent
	if not IsValid(ctrl) then
		st.cover = nil
		return
	end

	local held = (ragdoll.HGFallCoverActive or ragdoll.hgWoundGrab) and true or false
	if held ~= cover.held then
		cover.held = held
		ctrl:SetControllerEnabled(not held)
	end

	if not cover.pelvisBone then return end

	if not cover.localInv then
		local boneM = ctrl:GetBoneMatrix(cover.pelvisBone)
		if not boneM then return end
		cover.localInv = (ctrl:GetWorldTransformMatrix():GetInverseTR() * boneM):GetInverseTR()
	end

	local pelvisM = Matrix()
	pelvisM:SetAngles(st.pelvis:GetAngles())
	ctrl:SetPos(st.pelvis:GetPos())
	ctrl:SetAngles((pelvisM * cover.localInv):GetAngles())
end

local function stopStumble(ragdoll)
	local st = stumbling[ragdoll]
	stumbling[ragdoll] = nil
	if not IsValid(ragdoll) then return end

	ragdoll.hgStumbleActive = nil
	if st then
		stopCover(st)
		if IKSystem and IKSystem.RemoveEntityChains then IKSystem.RemoveEntityChains(ragdoll) end
	end
end

local function startStumble(ply, ragdoll)
	local pelvis = getBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
	local spine = getBonePhys(ragdoll, "ValveBiped.Bip01_Spine2")
	if not IsValid(pelvis) or not IsValid(spine) then return end

	local st = {
		ply = ply,
		cfg = readConfig(),
		pelvis = pelvis,
		spine = spine,
		startTime = CurTime(),
		lastGroundCheckTime = 0,
		smoothedVelocity = Vector(0, 0, 0),
		ikChains = {},
	}

	local hit = ply.hgStumbleHit
	if hit and CurTime() - hit.time < HIT_WINDOW then
		makePush(st, hit.pos, hit.dir)
	end

	initLegs(st, ragdoll)

	if IKSystem and IKSystem.CreateChain then
		st.ikChains[1] = IKSystem.CreateChain(ragdoll, { "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot" }, "leftLeg", Vector(0, 0, 50))
		st.ikChains[2] = IKSystem.CreateChain(ragdoll, { "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot" }, "rightLeg", Vector(0, 0, 50))
	end

	startCover(st, ragdoll, ply.organism)

	stumbling[ragdoll] = st
	ragdoll.hgStumbleActive = true
	ragdoll.hgStumblePending = nil
end

local function queueStumble(ragdoll)
	local now = CurTime()
	ragdoll.hgStumblePending = { from = now + START_DELAY, untilT = now + START_DELAY + START_WINDOW }
end

hook.Add("Fake", "HG_EuphoriaStumble", function(ply, ragdoll)
	if not hg_euphoria_getup_stumble:GetBool() or not IsValid(ragdoll) then return end
	queueStumble(ragdoll)
end)

hook.Add("Fake Up", "HG_EuphoriaStumble", function(ply, ragdoll)
	if IsValid(ragdoll) then stopStumble(ragdoll) end
end)

hook.Add("EntityTakeDamage", "HG_EuphoriaStumbleHit", function(ent, dmgInfo)
	if not IsValid(ent) then return end

	local ply
	if ent:IsPlayer() then
		ply = ent
	elseif ent:IsRagdoll() then
		ply = hg.RagdollOwner(ent)
	end
	if not IsValid(ply) or not ply:Alive() then return end

	if bit.band(dmgInfo:GetDamageType(), DMG_FALL + DMG_CRUSH + DMG_BURN + DMG_POISON + DMG_DROWN) ~= 0 then return end

	local dir = dmgInfo:GetDamageForce()
	if dir:LengthSqr() <= 1 then
		local attacker = dmgInfo:GetAttacker()
		dir = IsValid(attacker) and ply:GetPos() - attacker:GetPos() or nil
	end

	ply.hgStumbleHit = { pos = dmgInfo:GetDamagePosition(), dir = dir, time = CurTime() }

	local ragdoll = ply.FakeRagdoll
	if not IsValid(ragdoll) or dmgInfo:GetDamage() < HIT_MIN_DMG then return end
	if not hg_euphoria_getup_stumble:GetBool() then return end

	local st = stumbling[ragdoll]
	if st then
		makePush(st, ply.hgStumbleHit.pos, dir)
	else
		queueStumble(ragdoll)
	end
end)

hook.Add("Think", "HG_EuphoriaStumble", function()
	local enabled = hg_euphoria_getup_stumble:GetBool()

	for ragdoll, st in pairs(stumbling) do
		local ply = st.ply
		if not enabled or not IsValid(ragdoll) or not IsValid(ply) or ply.FakeRagdoll ~= ragdoll
			or not IsValid(st.pelvis) or not IsValid(st.spine)
			or not canStumble(ply, ragdoll)
			or hg.KeyDown(ply, IN_DUCK)
			or CurTime() - st.startTime >= st.cfg.TimeBeforeDecay + st.cfg.DecayDuration
			or not isUpright(ply, ragdoll) then
			stopStumble(ragdoll)
			continue
		end

		if st.cover and (hg.KeyDown(ply, IN_ATTACK) or hg.KeyDown(ply, IN_ATTACK2) or not hg_euphoria_cover:GetBool()) then
			stopCover(st)
		end
		if st.cover then updateCover(st, ragdoll) end

		updateStumble(st, ragdoll)
	end

	if not enabled then return end

	local now = CurTime()
	for i, ply in player.Iterator() do
		local ragdoll = ply.FakeRagdoll
		if not IsValid(ragdoll) or stumbling[ragdoll] then continue end

		local pending = ragdoll.hgStumblePending
		if not pending or now < pending.from then continue end
		if now > pending.untilT then
			ragdoll.hgStumblePending = nil
			continue
		end

		if canStumble(ply, ragdoll) and not hg.KeyDown(ply, IN_DUCK) and isUpright(ply, ragdoll) then
			startStumble(ply, ragdoll)
		end
	end
end)
