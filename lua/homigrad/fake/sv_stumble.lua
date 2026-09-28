local hg_euphoria_getup_stumble = CreateConVar("hg_euphoria_getup_stumble", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "fake ragdoll stumbling (Artagdoll-style)", 0, 1)
local hg_euphoria_cover = CreateConVar("hg_euphoria_cover", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "fake ragdolls cover their face when hit, falling or tumbling fast (Artagdoll Cower)", 0, 1)
local hg_euphoria_death_throes = CreateConVar("hg_euphoria_death_throes", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "players writhe briefly when they die conscious (Artagdoll Dying)", 0, 1)
local hg_euphoria_tumble = CreateConVar("hg_euphoria_tumble", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "fake ragdolls tuck and roll when tumbling fast along the ground (Artagdoll Tumble)", 0, 1)
local hg_euphoria_holdenv = CreateConVar("hg_euphoria_holdenv", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "fake ragdolls reach for nearby surfaces and grab them with the fake hands (Artagdoll HoldEnv)", 0, 1)
local hg_euphoria_windmill = CreateConVar("hg_euphoria_windmill", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "fake ragdolls windmill while airborne (Artagdoll Falling)", 0, 1)
local hg_hit_knockdown_energy = CreateConVar("hg_hit_knockdown_energy", "65", FCVAR_ARCHIVE + FCVAR_NOTIFY, "hit energy (damage summed over a short window) that knocks a standing player over, 0 disables", 0, 10000)

local IKSystem = include("system_/utils/IKChain.lua")

local AR_MODEL = "models/AREAnims/model_anim.mdl"
util.PrecacheModel(AR_MODEL)
local START_DELAY = 0
local START_WINDOW = 0.75
local HIT_WINDOW = 0.5
local HIT_MIN_DMG = 8
local UPRIGHT_THRESHOLD = 0.05
local UPRIGHT_TRACE = 60
local UPRIGHT_MIN_HEIGHT = 23.5
local FOOT_HULL_MINS = Vector(-2, -2, 0)
local FOOT_HULL_MAXS = Vector(2, 2, 2)

local STUMBLE_PUSH_MUL = 3
local STUMBLE_PUSH_TIME_MUL = 1.5
local STUMBLE_STEP_TRIGGER_MUL = 0.55
local STUMBLE_STEP_INTERVAL_MUL = 0.65
local STUMBLE_LUNGE_MUL = 0.18
local STUMBLE_LUNGE_MAX = 35
local STUMBLE_FALL_GRACE = 1
local STUMBLE_INTENT_GRACE = 0.2
local STUMBLE_HIT_TIME = 1.8
local STUMBLE_DRIVEN_INSTABILITY = 0.4
local STUMBLE_STEER = 3
local STUMBLE_SWAY_RATE = 2.3
local STUMBLE_SWAY_ANGLE = 22
local DIVE_PUSH = 260
local STUMBLE_MIN_STEPS = {2, 3}
local STUMBLE_STRIDE_MUL = 1.5
local STUMBLE_STRIDE_MAX = 90
local STUMBLE_WOBBLE = 260
local STUMBLE_MIN_STEP_TIMEOUT = 2.5
local STUMBLE_CLUTCH_CHANCE = 0.55
local FALL_LOCK_TIME = 2
local FALL_FOLLOW_PUSH = 420
local FALL_BUCKLE = 260
local FOOT_ANKLE_HEIGHT = 4
local FOOT_PLANT_DIST = 8
local FOOT_STEP_ARRIVE = 0.05
local FOOT_PLANT_ARRIVE = 0.1
local FOOT_MAX_SPEED = 1500
local FOOT_PUSHOFF = 1.6
local DIVE_UP = 140
local TOPPLE_PUSH = 110
local TOPPLE_DOWN = 60
local TOPPLE_ROLL = 200

local ENERGY_WINDOW = 0.3
local ENERGY_REF = 30
local ENERGY_PUSH_MIN = 0.5
local ENERGY_PUSH_MAX = 3
local ENERGY_PLAYER_PUSH = 4
local ENERGY_PLAYER_PUSH_MAX = 450
local ENERGY_RAG_PUSH = 3.5
local ENERGY_RAG_PUSH_MAX = 420
local ENERGY_FLING = 2.5
local ENERGY_FLING_MAX = 420

local ENERGY_TYPES = {
	{DMG_BUCKSHOT, 1},
	{DMG_BULLET, 1},
	{DMG_CLUB, 1.5},
	{DMG_SLASH, 0.5},
}

local REACT_COVER_TIME = 1.5
local REACT_FAST_SPEED = 350
local REACT_FAST_COVER_TIME = 0.75
local REACT_AIR_SPEED = 150
local REACT_AIR_TRACE = 60
local REACT_IDLE_REMOVE = 2
local REACT_WRITHE_TIME = 2.5
local REACT_CRITICAL_PAIN = 80

local START_MIN_SPEED = 40
local STILL_GRACE = 0.35
local DECAY_VIGOR_FLOOR = 0.3

local VIGOR_MIN = 0.15
local BLOOD_WEAK_FRAC = 0.45
local BLOOD_FULL_FRAC = 0.85
local CONSCIOUS_WEAK = 0.3
local CONSCIOUS_FULL = 0.9
local STAMINA_FLOOR = 0.35
local STAMINA_MAX_FALLBACK = 180

local LEG_TRIP_CHANCE = {broken = 0.85, dislocated = 0.6}
local LIMB_HURT_MIN = 0.3
local LEG_HURT_TRIP_MUL = 0.5
local LIMB_HURT_WEAKEN = 0.7
local TRIP_SIDE_MUL = 1.5

local DEATH_DELAY = 0.25
local DEATH_TIME = 2.2
local DEATH_STRENGTH = 3
local DEATH_FADE_POW = 1.5

local SPINE_REACT_BONES = {
	"ValveBiped.Bip01_Spine",
	"ValveBiped.Bip01_Spine1",
	"ValveBiped.Bip01_Spine2",
	"ValveBiped.Bip01_Spine4",
	"ValveBiped.Bip01_Head1",
}

local DYING_SEQUENCES = {"Dying1", "Dying2", "Dying3", "Dying4", "Dying5", "Dying6"}

local TUMBLE_SPEED = 250

local HOLD_SEARCH_INTERVAL = 0.1
local HOLD_MIN_SPEED = 120
local HOLD_SEARCH_RADIUS = 40
local HOLD_MIN_DIST = 6
local HOLD_GRAB_CHANCE = 0.45
local HOLD_REACH_TIME = 0.6
local HOLD_GRAB_DIST = 10
local HOLD_CONFIRM_TIME = 0.3
local HOLD_TIME_MIN = 0.8
local HOLD_TIME_MAX = 2.5
local HOLD_COOLDOWN = 1.5
local HOLD_REACH_SS = 0.12
local HOLD_REACH_SPEED = 400
local HOLD_REACH_DAMP = 250
local HOLD_SURFACE_OFFSET = 2

local HOLD_DIRS = {
	Vector(1, 0, 0),
	Vector(-1, 0, 0),
	Vector(0, 1, 0),
	Vector(0, -1, 0),
	Vector(0, 0, -1),
	Vector(0.7, 0.7, 0),
	Vector(-0.7, 0.7, 0),
	Vector(0.7, -0.7, 0),
	Vector(-0.7, -0.7, 0),
}

local HANDS = {
	l = {phys = 5, limb = "larm", cons = "ConsLH"},
	r = {phys = 7, limb = "rarm", cons = "ConsRH"},
}

local REACT_MODES = {
	stumble = {
		sequences = {"StumbleV2"},
		rate = 1.3,
		strength = 2.5,
		bones = SPINE_REACT_BONES,
		legs = false,
	},
	cover = {
		sequences = {"Cower"},
		rate = 0.5,
		strength = 3,
		bones = {"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Head1"},
		legs = false,
	},
	tumble = {
		sequences = {"Tumbling", "LEFT_Tumbling"},
		rate = 1,
		strength = 3.5,
		bones = SPINE_REACT_BONES,
		legs = true,
	},
	flail = {
		sequences = {"Falling", "Falling2"},
		rate = 1.25,
		strength = 5,
		bones = SPINE_REACT_BONES,
		legs = true,
	},
	writhe = {
		sequences = DYING_SEQUENCES,
		rate = 0.8,
		strength = 2.5,
		bones = SPINE_REACT_BONES,
		legs = true,
	},
}

local LIMB_BONES = {
	larm = {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand"},
	rarm = {"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand"},
	lleg = {"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot"},
	rleg = {"ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot"},
}

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
	Duration = 3.5,
	MinDriveSpeed = 130,
	MaxDriveSpeed = 450,
	MomentumGain = 140,
	DriveAccel = 700,
	Carry = 0.55,
	Pitch = 240,
	MaxSlopeAngle = 45,
	StepTriggerForward = 15,
	MinMovementSpeed = 15,
	StationaryThreshold = 15,
	AbsoluteTraceDepth = 8192,
	PredictionTime = 0.35,
	MinStepInterval = 0.25,
}

local stumbling = {}
local falling = {}
local reacting = {}
local dying = {}

local function readConfig()
	local cfg = {}
	for key, default in pairs(AR_DEFAULTS) do
		local cv = GetConVar("hg_stumble_" .. key)
		cfg[key] = cv and cv:GetFloat() or default
	end

	cfg.PushPeakForce = cfg.PushPeakForce * STUMBLE_PUSH_MUL
	cfg.PushDuration = cfg.PushDuration * STUMBLE_PUSH_TIME_MUL
	cfg.StepTriggerForward = cfg.StepTriggerForward * STUMBLE_STEP_TRIGGER_MUL
	cfg.MinStepInterval = cfg.MinStepInterval * STUMBLE_STEP_INTERVAL_MUL

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

local function groundTrace(ply, ragdoll, dist)
	local center = ragdoll:WorldSpaceCenter()
	return util.TraceLine({
		start = center,
		endpos = center - Vector(0, 0, dist),
		mask = MASK_SOLID_BRUSHONLY,
		filter = {ply, ragdoll},
	})
end

local function isUpright(ply, ragdoll)
	local spine = getBonePhys(ragdoll, "ValveBiped.Bip01_Spine2")
	if not IsValid(spine) then return false end
	local ang = spine:GetAngles()
	if type(ang) ~= "Angle" or ang:Forward().z <= UPRIGHT_THRESHOLD then return false end

	local tr = groundTrace(ply, ragdoll, UPRIGHT_TRACE)
	return tr.Hit and UPRIGHT_TRACE * tr.Fraction > UPRIGHT_MIN_HEIGHT
end

local function isAirborne(ply, ragdoll)
	local root = ragdoll:GetPhysicsObject()
	if not IsValid(root) or math.abs(root:GetVelocity().z) <= REACT_AIR_SPEED then return false end
	return not groundTrace(ply, ragdoll, REACT_AIR_TRACE).Hit
end

local function limbState(org, limb)
	if org[limb .. "amputated"] or org[limb .. "upamputated"] then return "gone" end
	if (org[limb] or 0) >= 1 then return "broken" end
	if org[limb .. "dislocation"] then return "dislocated" end
end

local function limbStrength(org, limb)
	if limbState(org, limb) then return 0 end
	local dmg = org[limb] or 0
	if dmg < LIMB_HURT_MIN then return 1 end

	return 1 - dmg * LIMB_HURT_WEAKEN
end

local function legTripChance(org, limb)
	local state = limbState(org, limb)
	if state then return LEG_TRIP_CHANCE[state] or 1 end
	local dmg = org[limb] or 0
	if dmg < LIMB_HURT_MIN then return 0 end

	return dmg * LEG_HURT_TRIP_MUL
end

local function vigor(org)
	local maxBlood = math.max(org.maxblood or 5000, 1)
	local bloodFrac = (org.blood or maxBlood) / maxBlood
	local bloodMul = math.Clamp((bloodFrac - BLOOD_WEAK_FRAC) / (BLOOD_FULL_FRAC - BLOOD_WEAK_FRAC), 0, 1)
	local consciousMul = math.Clamp(((org.consciousness or 1) - CONSCIOUS_WEAK) / (CONSCIOUS_FULL - CONSCIOUS_WEAK), 0, 1)
	local stamina = org.stamina
	local staminaFrac = stamina and stamina[1] and stamina[1] / (stamina.max or STAMINA_MAX_FALLBACK) or 1
	local staminaMul = math.Clamp(staminaFrac, STAMINA_FLOOR, 1)

	local ragdoll = IsValid(org.owner) and org.owner.FakeRagdoll
	local controlMul = IsValid(ragdoll) and math.Clamp(ragdoll.power or 1, 0, 1) or 1
	return bloodMul * consciousMul * staminaMul * controlMul
end

local function legsUsable(org)
	local left = limbState(org, "lleg")
	local right = limbState(org, "rleg")
	if left == "gone" or right == "gone" then return false end

	return not (left and right)
end

local function isAware(ply)
	if not ply:Alive() then return false end
	local org = ply.organism
	if not org or org.otrub or not org.canmove or org.brainfuckv2Posture then return false end

	return vigor(org) >= VIGOR_MIN
end

hg.RagdollReflex = {
	Vigor = vigor,
	LimbStrength = limbStrength,
	IsAware = isAware,
}

local function canStumble(ply, ragdoll)
	if not isAware(ply) or not legsUsable(ply.organism) then return false end
	if ragdoll.isSliding or ragdoll.isDropkicking or ply:InVehicle() or ragdoll.welds then return false end
	return true
end

local function limbControl(ply)
	return hg.KeyDown(ply, IN_ATTACK) or hg.KeyDown(ply, IN_ATTACK2) or hg.KeyDown(ply, IN_DUCK)
end

local function moveControl(ply)
	return hg.KeyDown(ply, IN_FORWARD) or hg.KeyDown(ply, IN_BACK)
		or hg.KeyDown(ply, IN_MOVELEFT) or hg.KeyDown(ply, IN_MOVERIGHT)
end

local function wishDir(ply)
	local ang = Angle(0, ply:EyeAngles().y, 0)
	local dir = Vector()
	if hg.KeyDown(ply, IN_FORWARD) then dir:Add(ang:Forward()) end
	if hg.KeyDown(ply, IN_BACK) then dir:Sub(ang:Forward()) end
	if hg.KeyDown(ply, IN_MOVERIGHT) then dir:Add(ang:Right()) end
	if hg.KeyDown(ply, IN_MOVELEFT) then dir:Sub(ang:Right()) end
	if dir:LengthSqr() < 0.01 then return end
	return dir:GetNormalized()
end

local function hasMomentum(ply, ragdoll)
	local hit = ply.hgStumbleHit
	if hit and CurTime() - hit.time < HIT_WINDOW then return true end
	local pelvis = getBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
	if not IsValid(pelvis) then return false end
	local vel = pelvis:GetVelocity()

	return vel.x * vel.x + vel.y * vel.y > START_MIN_SPEED * START_MIN_SPEED
end

local function triggerCover(ragdoll, duration)
	ragdoll.hgCoverUntil = math.max(ragdoll.hgCoverUntil or 0, CurTime() + duration)
end

local function makePush(st, dmgpos, fallbackDir, energy)
	local pelvisPos = st.pelvis:GetPos()

	local dir
	if dmgpos and dmgpos:DistToSqr(pelvisPos) < 200 * 200 then
		dir = pelvisPos - dmgpos
		dir.z = 0
	end
	if (not dir or dir:LengthSqr() < 1) and fallbackDir then dir = Vector(fallbackDir.x, fallbackDir.y, 0) end
	if not dir or dir:LengthSqr() < 0.01 then return end
	dir:Normalize()

	local scale = math.Clamp((energy or ENERGY_REF) / ENERGY_REF, ENERGY_PUSH_MIN, ENERGY_PUSH_MAX)
	st.push = {dir = dir, scale = scale, startTime = CurTime(), duration = st.cfg.PushDuration}
	st.pushDir = dir
end

local function initLegs(st, ragdoll)
	st.footPositions = {}
	st.ghostPositions = {}
	st.lockedFootPositions = {}
	st.groundNormals = {Vector(0, 0, 1), Vector(0, 0, 1)}
	st.hasGroundContact = {false, false}
	st.legState = {
		[1] = {isStepping = false, progress = 0, isLocked = false, lastStepTime = 0},
		[2] = {isStepping = false, progress = 0, isLocked = false, lastStepTime = 0},
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

	local prediction = horizontalVel * st.cfg.PredictionTime * STUMBLE_STRIDE_MUL
	if prediction:Length() > STUMBLE_STRIDE_MAX then prediction = prediction:GetNormalized() * STUMBLE_STRIDE_MAX end

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

local function stumbleLifetime(st)
	return st.hit and STUMBLE_HIT_TIME or math.max(st.cfg.Duration, 0.1)
end

local function updateStumble(st, ragdoll)
	local cfg = st.cfg
	local dt = FrameTime()
	local now = CurTime()
	st.vigor = st.ply.organism and vigor(st.ply.organism) or 0

	local pelvisPos = st.pelvis:GetPos()
	local rawVel = st.pelvis:GetVelocity()
	if not isValidNumber(pelvisPos.x) then return end

	if st.push then
		local elapsed = now - st.push.startTime
		if elapsed < st.push.duration then
			local force = st.push.dir * (cfg.PushPeakForce * st.push.scale * math.sin(elapsed / st.push.duration * math.pi))
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
	local flatVel = Vector(rawVel.x, rawVel.y, 0)
	local wish = not st.hit and wishDir(st.ply)
	if wish then
		wish:Rotate(Angle(0, math.sin((now - st.startTime) * STUMBLE_SWAY_RATE + st.swayPhase) * STUMBLE_SWAY_ANGLE, 0))
		st.driveDir = LerpVector(math.min(dt * STUMBLE_STEER, 1), st.driveDir or wish, wish):GetNormalized()
	elseif flatVel:LengthSqr() > START_MIN_SPEED * START_MIN_SPEED then
		st.driveDir = flatVel:GetNormalized()
	end
	local moveDir = st.driveDir or st.pushDir

	if speed < cfg.StationaryThreshold and not st.push then
		st.stillSince = st.stillSince or now
	else
		st.stillSince = nil
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
				st.steps = st.steps + 1
				st.footPositions[i] = state.targetPos
				st.lockedFootPositions[i] = state.targetPos
				if moveDir and st.hasGroundContact[i] then
					st.pelvis:AddVelocity(moveDir * math.min(speed * STUMBLE_LUNGE_MUL, STUMBLE_LUNGE_MAX) * FOOT_PUSHOFF)
					local plantSide = moveDir:Cross(state.targetPos - pelvisPos).z
					st.spine:AddAngleVelocity(moveDir * math.Clamp(plantSide, -12, 12) * 2)
				end
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
				if st.steps >= st.minSteps and math.Rand(0, 1) < st.legTrip[i] then
					st.tripLeg = i
					return
				end

				state.isStepping = true
				state.progress = 0
				state.startPos = st.footPositions[i]
				state.targetPos = findGroundPosition(cfg, st.ghostPositions[i], ragdoll, st.ghostPositions[i].z, pelvisPos.z) or st.ghostPositions[i]
			end
		end
	end

	local planted = 0
	for i = 1, 2 do
		local chain = st.ikChains[i]
		local target = sanitizeVector(st.footPositions[i], pelvisPos)
		if chain then
			chain:SetTarget(target)
			chain:Update()
		end

		local foot = st.footPhys[i]
		if chain and IsValid(foot) then
			local stepping = st.legState[i].isStepping
			local goal = target + Vector(0, 0, FOOT_ANKLE_HEIGHT)
			foot:Wake()
			foot:ComputeShadowControl({
				pos = goal,
				angle = foot:GetAngles(),
				secondstoarrive = stepping and FOOT_STEP_ARRIVE or FOOT_PLANT_ARRIVE,
				maxspeed = FOOT_MAX_SPEED,
				maxspeeddamp = FOOT_MAX_SPEED * 2,
				maxangular = 0,
				maxangulardamp = 0,
				dampfactor = 0.8,
				teleportdistance = 0,
				deltatime = dt,
			})
			if not stepping and st.hasGroundContact[i] and foot:GetPos():DistToSqr(goal) < FOOT_PLANT_DIST * FOOT_PLANT_DIST then
				planted = planted + 1
			end
		end
	end
	local instability = math.Clamp((now - st.startTime) / stumbleLifetime(st), 0, 1)
	if st.steps < st.minSteps then instability = math.min(instability, STUMBLE_DRIVEN_INSTABILITY) end
	st.spine:AddAngleVelocity(Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0) * STUMBLE_WOBBLE * (0.5 + instability) * dt)
	local grounded = planted > 0
	local support = math.min(planted, 1) + (planted > 1 and 0.25 or 0)

	local carry = math.Clamp(cfg.Carry, 0, 1) * (1 - instability * instability) * support
	if carry > 0 and grounded then
		local lift = Vector(0, 0, physenv.GetGravity():Length() * carry * dt)
		st.pelvis:AddVelocity(lift)
		st.spine:AddVelocity(lift)
	end

	if moveDir then
		st.driveSpeed = math.min(math.max(st.driveSpeed + cfg.MomentumGain * dt, flatVel:Dot(moveDir)), cfg.MaxDriveSpeed)
		local deficit = st.driveSpeed - rawVel:Dot(moveDir)
		if deficit > 0 and grounded then
			local add = moveDir * math.min(deficit, cfg.DriveAccel * dt) * math.min(support, 1)
			st.pelvis:AddVelocity(add)
			st.spine:AddVelocity(add * 1.15)
		end

		local axis = moveDir:Cross(Vector(0, 0, 1))
		st.spine:AddAngleVelocity(-axis * cfg.Pitch * (0.5 + instability) * dt)
	end
end

local function topple(st)
	local vel = st.pelvis:GetVelocity()
	local dir = Vector(vel.x, vel.y, 0)
	if dir:LengthSqr() < START_MIN_SPEED * START_MIN_SPEED then dir = st.pushDir or st.spine:GetAngles():Forward() end
	dir.z = 0
	if dir:LengthSqr() < 0.01 then return end
	dir = dir:GetNormalized()

	local tripFoot = st.tripLeg and st.footPositions[st.tripLeg]
	if tripFoot then
		local side = tripFoot - st.pelvis:GetPos()
		side.z = 0
		if side:LengthSqr() > 0.01 then dir = (dir + side:GetNormalized() * TRIP_SIDE_MUL * 0.25):GetNormalized() end
	end

	st.spine:AddVelocity(dir * TOPPLE_PUSH + Vector(0, 0, -TOPPLE_DOWN))
	st.pelvis:AddVelocity(dir * TOPPLE_PUSH * 0.3)

	local axis = dir:Cross(Vector(0, 0, 1))
	if axis:LengthSqr() > 0.01 then st.spine:AddAngleVelocity(-axis * TOPPLE_ROLL) end
end

local function stopStumble(ragdoll, reason)
	local st = stumbling[ragdoll]
	stumbling[ragdoll] = nil
	if not IsValid(ragdoll) then return end

	ragdoll.hgStumbleActive = nil
	if not st then return end

	if IKSystem and IKSystem.RemoveEntityChains then IKSystem.RemoveEntityChains(ragdoll) end
	if not IsValid(st.pelvis) or not IsValid(st.spine) then return end

	if reason == "dive" then
		local dir = IsValid(st.ply) and st.ply:EyeAngles():Forward() or st.driveDir or st.spine:GetAngles():Forward()
		dir = Vector(dir.x, dir.y, 0)
		if dir:LengthSqr() < 0.01 then return end
		local vel = dir:GetNormalized() * DIVE_PUSH + Vector(0, 0, DIVE_UP)
		st.pelvis:AddVelocity(vel)
		st.spine:AddVelocity(vel * 1.2)
		return
	end

	local falls = reason == "decay" or reason == "trip" or reason == "halt" or reason == "getup"
	if falls then
		topple(st)
		local vel = st.pelvis:GetVelocity()
		local dir = Vector(vel.x, vel.y, 0)
		if dir:LengthSqr() < START_MIN_SPEED * START_MIN_SPEED then dir = st.pushDir or st.driveDir or st.spine:GetAngles():Forward() end
		dir = Vector(dir.x, dir.y, 0)
		if dir:LengthSqr() > 0.01 then
			falling[ragdoll] = {ply = st.ply, pelvis = st.pelvis, spine = st.spine, dir = dir:GetNormalized(), untilT = CurTime() + FALL_LOCK_TIME}
			ragdoll.hgStumbleFalling = true
		end
	end
	if falls or reason == "fell" then triggerCover(ragdoll, REACT_COVER_TIME) end
end

local function startStumble(ply, ragdoll)
	local pelvis = getBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
	local spine = getBonePhys(ragdoll, "ValveBiped.Bip01_Spine2")
	if not IsValid(pelvis) or not IsValid(spine) then return end

	local org = ply.organism
	local st = {
		ply = ply,
		cfg = readConfig(),
		pelvis = pelvis,
		spine = spine,
		startTime = CurTime(),
		lastGroundCheckTime = 0,
		smoothedVelocity = pelvis:GetVelocity(),
		ikChains = {},
		steps = 0,
		minSteps = math.random(STUMBLE_MIN_STEPS[1], STUMBLE_MIN_STEPS[2]),
		footPhys = {getBonePhys(ragdoll, "ValveBiped.Bip01_L_Foot"), getBonePhys(ragdoll, "ValveBiped.Bip01_R_Foot")},
		vigor = vigor(org),
		legTrip = {legTripChance(org, "lleg"), legTripChance(org, "rleg")},
	}

	local hit = ply.hgStumbleHit
	if hit and CurTime() - hit.time < HIT_WINDOW then
		st.hit = true
		makePush(st, hit.pos, hit.dir, hit.energy)
		if hg.EuphoriaWoundGrab and math.random() < STUMBLE_CLUTCH_CHANCE then
			hg.EuphoriaWoundGrab(ply, ragdoll, hit.pos, hit.dir, STUMBLE_HIT_TIME + FALL_LOCK_TIME)
		end
	end
	st.swayPhase = math.Rand(0, math.pi * 2)

	local startVel = pelvis:GetVelocity()
	startVel.z = 0
	local startSpeed = startVel:Length()
	if startSpeed > START_MIN_SPEED then st.driveDir = startVel / startSpeed end
	if st.hit and st.pushDir then st.driveDir = st.pushDir end
	st.driveSpeed = math.Clamp(startSpeed, st.cfg.MinDriveSpeed, math.max(st.cfg.MaxDriveSpeed, st.cfg.MinDriveSpeed))

	initLegs(st, ragdoll)

	if IKSystem and IKSystem.CreateChain then
		if not limbState(org, "lleg") then
			st.ikChains[1] = IKSystem.CreateChain(ragdoll, LIMB_BONES.lleg, "leftLeg", Vector(0, 0, 50))
		end
		if not limbState(org, "rleg") then
			st.ikChains[2] = IKSystem.CreateChain(ragdoll, LIMB_BONES.rleg, "rightLeg", Vector(0, 0, 50))
		end
	end

	stumbling[ragdoll] = st
	ragdoll.hgStumbleActive = true
	ragdoll.hgStumblePending = nil
end

local function queueStumble(ragdoll)
	local now = CurTime()
	ragdoll.hgStumblePending = {from = now + START_DELAY, untilT = now + START_DELAY + START_WINDOW}
end

local function isFloppy(ragdoll, org, bone)
	local ragFloppy = ragdoll.hg_floppy_bones
	local orgFloppy = org.fake_floppy_bones

	return ragFloppy and ragFloppy[bone] or orgFloppy and orgFloppy[bone] or false
end

local LIMB_HAND = {larm = "l", rarm = "r"}

local function handBusy(ragdoll, limb)
	local side = LIMB_HAND[limb]
	if not side then return false end
	if IsValid(ragdoll[HANDS[side].cons]) then return true end
	if ragdoll.hgWoundGrips and ragdoll.hgWoundGrips[side] then return true end
	local wound = ragdoll.hgWoundGrab
	if wound and wound.hand == ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, HANDS[side].phys)) then return true end
	local reach = ragdoll.hgEnvReach

	return reach and reach[side] and true or false
end

local function reactBones(mode, org, ragdoll)
	local bones = {}
	local strength = {}
	for _, bone in ipairs(mode.bones) do
		if not isFloppy(ragdoll, org, bone) then bones[#bones + 1] = bone end
	end

	for limb, limbBones in pairs(LIMB_BONES) do
		local isLeg = limb == "lleg" or limb == "rleg"
		if isLeg and not mode.legs then continue end
		local mul = limbStrength(org, limb)
		if mul <= 0 or handBusy(ragdoll, limb) then continue end

		for _, bone in ipairs(limbBones) do
			if isFloppy(ragdoll, org, bone) then continue end
			bones[#bones + 1] = bone
			strength[bone] = mul
		end
	end

	return bones, strength
end

local function limbKey(org, ragdoll)
	local floppy = ragdoll.hg_floppy_bones and table.Count(ragdoll.hg_floppy_bones) or 0

	return table.concat({
		limbStrength(org, "larm"),
		limbStrength(org, "rarm"),
		limbStrength(org, "lleg"),
		limbStrength(org, "rleg"),
		floppy,
		handBusy(ragdoll, "larm") and 1 or 0,
		handBusy(ragdoll, "rarm") and 1 or 0,
	}, "/")
end

local function spawnController(ragdoll)
	local saved = {}
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		if IsValid(phys) then saved[phys] = {phys:GetMass(), phys:GetInertia()} end
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

	return ctrl
end

local function removeReaction(ragdoll)
	local rs = reacting[ragdoll]
	reacting[ragdoll] = nil
	if rs and IsValid(rs.ent) then rs.ent:Remove() end
end

local function setReactMode(rs, modeName, org)
	if rs.mode == modeName then return end

	if not modeName then
		rs.mode = nil
		rs.idleSince = CurTime()
		rs.ent:SetControllerEnabled(false)
		return
	end

	local mode = REACT_MODES[modeName]
	local seq = rs.ent:LookupSequence(mode.sequences[math.random(#mode.sequences)])
	if not seq or seq == -1 then return end

	local bones, strength = reactBones(mode, org, rs.ragdoll)
	rs.ent:SetBoneList(bones)
	rs.ent:SetBoneStrength(strength)
	rs.ent:SetReactionStrength(mode.strength * vigor(org))
	rs.limbKey = limbKey(org, rs.ragdoll)
	rs.ent:ResetSequence(seq)
	rs.ent:SetPlaybackRate(mode.rate)
	rs.ent:SetCycle(0)

	rs.mode = modeName
	rs.localInv = nil
	rs.held = false
	rs.alignAfter = CurTime()
end

local function alignController(rs, pelvis)
	local ctrl = rs.ent
	if not rs.pelvisBone then return end

	if not rs.localInv then
		if CurTime() <= rs.alignAfter then return end
		local boneM = ctrl:GetBoneMatrix(rs.pelvisBone)
		if not boneM then return end
		rs.localInv = (ctrl:GetWorldTransformMatrix():GetInverseTR() * boneM):GetInverseTR()
	end

	local pelvisM = Matrix()
	pelvisM:SetAngles(pelvis:GetAngles())
	ctrl:SetPos(pelvis:GetPos())
	ctrl:SetAngles((pelvisM * rs.localInv):GetAngles())
end

local function wantedReaction(ply, ragdoll)
	if not isAware(ply) then return end
	if hg_euphoria_windmill:GetBool() and isAirborne(ply, ragdoll) then return "flail" end
	if stumbling[ragdoll] then return "stumble" end

	if limbControl(ply) then
		ragdoll.hgCoverUntil = nil
		return
	end

	local root = ragdoll:GetPhysicsObject()
	if hg_euphoria_tumble:GetBool() and IsValid(root) and not stumbling[ragdoll] and not moveControl(ply) then
		local vel = root:GetVelocity()
		local grounded = groundTrace(ply, ragdoll, REACT_AIR_TRACE).Hit
		if grounded and vel.x * vel.x + vel.y * vel.y > TUMBLE_SPEED * TUMBLE_SPEED then return "tumble" end
	end

	if not hg_euphoria_cover:GetBool() then return end

	if IsValid(root) and root:GetVelocity():LengthSqr() > REACT_FAST_SPEED * REACT_FAST_SPEED then
		triggerCover(ragdoll, REACT_FAST_COVER_TIME)
	end

	if (ragdoll.hgCoverUntil or 0) > CurTime() then return "cover" end
	if moveControl(ply) or stumbling[ragdoll] then return end

	local org = ply.organism
	local critical = org.critical or (org.pain or 0) > REACT_CRITICAL_PAIN
	if not critical and (ragdoll.hgWritheUntil or 0) <= CurTime() then return end
	if not isUpright(ply, ragdoll) then return "writhe" end
end

local function updateReaction(ply, ragdoll)
	local modeName = wantedReaction(ply, ragdoll)
	local rs = reacting[ragdoll]

	if not rs then
		if not modeName then return end
		local pelvis = getBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
		local ctrl = IsValid(pelvis) and spawnController(ragdoll)
		if not ctrl then return end
		rs = {
			ply = ply,
			ragdoll = ragdoll,
			ent = ctrl,
			pelvis = pelvis,
			pelvisBone = ctrl:LookupBone("ValveBiped.Bip01_Pelvis"),
			idleSince = CurTime(),
		}
		reacting[ragdoll] = rs
	end

	if not IsValid(rs.ent) or not IsValid(rs.pelvis) then
		removeReaction(ragdoll)
		return
	end

	local org = ply.organism
	if rs.mode and rs.limbKey ~= limbKey(org, ragdoll) then rs.mode = "stale" end
	setReactMode(rs, modeName, org)

	if not rs.mode then
		if CurTime() - rs.idleSince > REACT_IDLE_REMOVE then removeReaction(ragdoll) end
		return
	end

	local mode = REACT_MODES[rs.mode]
	if not mode then return end
	local strength = mode.strength * vigor(org)
	if rs.mode == "stumble" then
		local st = stumbling[ragdoll]
		strength = strength * (1 - 0.8 * math.Clamp((CurTime() - st.startTime) / stumbleLifetime(st), 0, 1))
	end
	rs.ent:SetReactionStrength(strength)

	local held = (ragdoll.HGFallCoverActive or ragdoll.hgCurl) and true or false
	if held ~= rs.held then
		rs.held = held
		rs.ent:SetControllerEnabled(not held)
	end

	alignController(rs, rs.pelvis)
end

hook.Add("Fake", "HG_EuphoriaStumble", function(ply, ragdoll)
	if not IsValid(ragdoll) then return end

	local hit = ply.hgStumbleHit
	if hit and CurTime() - hit.time < HIT_WINDOW and math.max(hit.dmg or 0, hit.energy or 0) >= HIT_MIN_DMG then
		triggerCover(ragdoll, REACT_COVER_TIME)
		ragdoll.hgWritheUntil = CurTime() + REACT_COVER_TIME + REACT_WRITHE_TIME
	end

	if hg_euphoria_getup_stumble:GetBool() then queueStumble(ragdoll) end
end)

hook.Add("Fake Up", "HG_EuphoriaStumble", function(ply, ragdoll)
	if not IsValid(ragdoll) then return end
	falling[ragdoll] = nil
	ragdoll.hgStumbleFalling = nil
	stopStumble(ragdoll)
	removeReaction(ragdoll)
	ragdoll.hgReflexGrab = nil
	ragdoll.hgEnvReach = nil
end)

local function hitEnergy(dmgInfo)
	for _, entry in ipairs(ENERGY_TYPES) do
		if dmgInfo:IsDamageType(entry[1]) then return dmgInfo:GetDamage() * entry[2] end
	end
	return 0
end

local function addHitEnergy(ply, energy, flatDir)
	local now = CurTime()
	local acc = ply.hgHitEnergy
	if not acc then
		acc = {energy = 0, pushed = 0, dir = Vector(0, 0, 0), time = now}
		ply.hgHitEnergy = acc
	end

	local keep = math.Clamp(1 - (now - acc.time) / ENERGY_WINDOW, 0, 1)
	acc.energy = acc.energy * keep + energy
	acc.pushed = acc.pushed * keep
	acc.dir:Mul(keep)
	if flatDir then acc.dir:Add(flatDir * energy) end
	acc.time = now

	return acc
end

local function takePush(acc, amount, cap)
	amount = math.min(amount, math.max(cap - acc.pushed, 0))
	acc.pushed = acc.pushed + amount
	return amount
end

local function knockDown(ply)
	local acc = ply.hgHitEnergy
	if acc.knockdown then return end
	acc.knockdown = true

	timer.Simple(0, function()
		if not IsValid(ply) then return end
		acc.knockdown = nil
		if not ply:Alive() or IsValid(ply.FakeRagdoll) then return end

		hg.Fake(ply)
		local ragdoll = ply.FakeRagdoll
		if not IsValid(ragdoll) or acc.dir:LengthSqr() < 0.01 then return end

		local fling = math.min(acc.energy * ENERGY_FLING, ENERGY_FLING_MAX)
		local vel = Vector(acc.dir.x, acc.dir.y, 0):GetNormalized() * fling
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local phys = ragdoll:GetPhysicsObjectNum(i)
			if IsValid(phys) then phys:AddVelocity(vel) end
		end
	end)
end

hook.Add("EntityTakeDamage", "HG_EuphoriaStumbleHit", function(ent, dmgInfo)
	if not IsValid(ent) then return end

	local ply
	if ent:IsPlayer() then
		if IsValid(ent.FakeRagdoll) then return end
		ply = ent
	elseif ent:IsRagdoll() then
		ply = hg.RagdollOwner(ent)
		if IsValid(ply) and ply.FakeRagdoll ~= ent then return end
	end
	if not IsValid(ply) or not ply:Alive() then return end

	if bit.band(dmgInfo:GetDamageType(), DMG_FALL + DMG_CRUSH + DMG_BURN + DMG_POISON + DMG_DROWN) ~= 0 then return end

	local dir = dmgInfo:GetDamageForce()
	if dir:LengthSqr() <= 1 then
		local attacker = dmgInfo:GetAttacker()
		dir = IsValid(attacker) and ply:GetPos() - attacker:GetPos() or nil
	end

	local flatDir = dir and Vector(dir.x, dir.y, 0)
	if flatDir and flatDir:LengthSqr() > 0.01 then flatDir:Normalize() else flatDir = nil end

	local energy = hitEnergy(dmgInfo)
	local acc = addHitEnergy(ply, energy, flatDir)
	local dmg = dmgInfo:GetDamage()
	ply.hgStumbleHit = {pos = dmgInfo:GetDamagePosition(), dir = dir, dmg = dmg, energy = acc.energy, time = CurTime()}

	local ragdoll = ply.FakeRagdoll
	if not IsValid(ragdoll) then
		if energy <= 0 or not flatDir or acc.knockdown then return end

		local knockdown = hg_hit_knockdown_energy:GetFloat()
		if knockdown > 0 and acc.energy >= knockdown then
			knockDown(ply)
			return
		end

		local push = takePush(acc, energy * ENERGY_PLAYER_PUSH, ENERGY_PLAYER_PUSH_MAX)
		if push > 0 then ply:SetVelocity(flatDir * push) end
		return
	end

	if energy > 0 and flatDir then
		local push = takePush(acc, energy * ENERGY_RAG_PUSH, ENERGY_RAG_PUSH_MAX)
		if push > 0 then
			local pelvis = getBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
			local spine = getBonePhys(ragdoll, "ValveBiped.Bip01_Spine2")
			if IsValid(pelvis) then pelvis:AddVelocity(flatDir * push) end
			if IsValid(spine) then spine:AddVelocity(flatDir * push * 0.5) end
		end
	end

	if math.max(dmg, acc.energy) < HIT_MIN_DMG then return end

	triggerCover(ragdoll, REACT_COVER_TIME)
	ragdoll.hgWritheUntil = CurTime() + REACT_COVER_TIME + REACT_WRITHE_TIME

	if not hg_euphoria_getup_stumble:GetBool() then return end

	local st = stumbling[ragdoll]
	if st then
		makePush(st, ply.hgStumbleHit.pos, dir, acc.energy)
	else
		queueStumble(ragdoll)
	end
end)

local function armControl(ply)
	return limbControl(ply) or moveControl(ply)
		or hg.KeyDown(ply, IN_SPEED) or hg.KeyDown(ply, IN_WALK) or hg.KeyDown(ply, IN_USE)
end

local function handPhys(ragdoll, hand)
	return ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, hand.phys))
end

local function handFree(ply, ragdoll, org, side, hand)
	if limbStrength(org, hand.limb) <= 0 or IsValid(ragdoll[hand.cons]) then return false end
	local phys = handPhys(ragdoll, hand)
	if not IsValid(phys) then return false end
	local wound, wall = ragdoll.hgWoundGrab, ragdoll.hgWallGrab
	if wound and wound.hand == phys or wall and wall.hand == phys then return false end
	if side ~= "r" then return true end
	local wep = ply:GetActiveWeapon()

	return not (IsValid(wep) and (ishgweapon(wep) or wep.ismelee2))
end

local function findHoldPoint(ply, ragdoll, handPos)
	local best, bestScore
	for _, dir in ipairs(HOLD_DIRS) do
		local tr = util.TraceLine({
			start = handPos,
			endpos = handPos + dir * HOLD_SEARCH_RADIUS,
			filter = {ply, ragdoll},
			mask = MASK_SOLID,
		})
		if not tr.Hit or tr.HitSky then continue end
		if tr.Fraction * HOLD_SEARCH_RADIUS < HOLD_MIN_DIST then continue end
		local ent = tr.Entity
		if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsRagdoll()) then continue end

		local score = 1 - tr.Fraction
		if not bestScore or score > bestScore then best, bestScore = tr, score end
	end

	return best
end

local function clearReach(ragdoll, side)
	ragdoll.hgEnvReach[side] = nil
	ragdoll.hgEnvCooldown = ragdoll.hgEnvCooldown or {}
	ragdoll.hgEnvCooldown[side] = CurTime() + HOLD_COOLDOWN
end

local function releaseHoldEnv(ragdoll)
	ragdoll.hgReflexGrab = nil
	ragdoll.hgEnvReach = nil
end

local function updateHeldHand(ragdoll, reach, side, hand, now)
	local reflex = ragdoll.hgReflexGrab
	local holding = (reflex[side] or 0) > now
	local welded = IsValid(ragdoll[hand.cons])
	if holding and (welded or now - reach.grabAt < HOLD_CONFIRM_TIME) then return end

	reflex[side] = nil
	clearReach(ragdoll, side)
end

local function updateReachingHand(ragdoll, org, reach, side, hand, now)
	local phys = handPhys(ragdoll, hand)
	local armMul = limbStrength(org, hand.limb)
	if now > reach.untilT or not IsValid(phys) or armMul <= 0 then
		clearReach(ragdoll, side)
		return
	end

	local vig = vigor(org)
	if phys:GetPos():DistToSqr(reach.pos) < HOLD_GRAB_DIST * HOLD_GRAB_DIST then
		reach.grabAt = now
		ragdoll.hgReflexGrab[side] = now + math.Rand(HOLD_TIME_MIN, HOLD_TIME_MAX) * math.max(vig, DECAY_VIGOR_FLOOR)
		return
	end

	local mul = armMul * vig
	hg.ShadowControl(ragdoll, hand.phys, HOLD_REACH_SS, nil, nil, nil, reach.pos, HOLD_REACH_SPEED * mul, HOLD_REACH_DAMP * mul)
end

local function updateIdleHand(ply, ragdoll, org, side, hand, now)
	local cooldown = ragdoll.hgEnvCooldown
	if cooldown and (cooldown[side] or 0) > now then return end
	if not handFree(ply, ragdoll, org, side, hand) then return end

	local tr = findHoldPoint(ply, ragdoll, handPhys(ragdoll, hand):GetPos())
	if not tr then return end

	ragdoll.hgEnvReach[side] = {pos = tr.HitPos + tr.HitNormal * HOLD_SURFACE_OFFSET, untilT = now + HOLD_REACH_TIME}
end

local function updateHoldEnv(ply, ragdoll)
	if not hg_euphoria_holdenv:GetBool() or not isAware(ply) or armControl(ply) or ragdoll.HGFallCoverActive or stumbling[ragdoll] then
		releaseHoldEnv(ragdoll)
		return
	end

	local now = CurTime()
	local org = ply.organism
	ragdoll.hgEnvReach = ragdoll.hgEnvReach or {}
	ragdoll.hgReflexGrab = ragdoll.hgReflexGrab or {}

	local root = ragdoll:GetPhysicsObject()
	local moving = IsValid(root) and root:GetVelocity():LengthSqr() > HOLD_MIN_SPEED * HOLD_MIN_SPEED
	if not moving then
		ragdoll.hgEnvKlepto = nil
	elseif ragdoll.hgEnvKlepto == nil then
		ragdoll.hgEnvKlepto = math.random() < HOLD_GRAB_CHANCE
	end
	local search = moving and ragdoll.hgEnvKlepto and (ragdoll.hgEnvNextSearch or 0) <= now
	if search then ragdoll.hgEnvNextSearch = now + HOLD_SEARCH_INTERVAL end

	for side, hand in pairs(HANDS) do
		local reach = ragdoll.hgEnvReach[side]
		if reach and reach.grabAt then
			updateHeldHand(ragdoll, reach, side, hand, now)
		elseif reach then
			updateReachingHand(ragdoll, org, reach, side, hand, now)
		elseif search then
			updateIdleHand(ply, ragdoll, org, side, hand, now)
		end
	end
end

local function stumbleEndReason(ply, ragdoll, st)
	if not hg_euphoria_getup_stumble:GetBool() then return "off" end
	if not IsValid(ragdoll) or not IsValid(ply) or ply.FakeRagdoll ~= ragdoll then return "gone" end
	if not IsValid(st.pelvis) or not IsValid(st.spine) or not canStumble(ply, ragdoll) then return "gone" end
	if st.tripLeg then return "trip" end

	local now = CurTime()
	local elapsed = now - st.startTime
	if elapsed > STUMBLE_INTENT_GRACE then
		if hg.KeyDown(ply, IN_JUMP) and not hg.KeyDown(ply, IN_USE) then return "dive" end
		if not st.hit and not moveControl(ply) then return "halt" end
	end
	if st.stillSince and now - st.stillSince > STILL_GRACE then return "decay" end

	st.vigor = vigor(ply.organism)
	if st.steps < st.minSteps and elapsed < STUMBLE_MIN_STEP_TIMEOUT then return end
	if elapsed >= stumbleLifetime(st) then return "decay" end
	if now - st.startTime >= STUMBLE_FALL_GRACE and not isUpright(ply, ragdoll) then return "fell" end
end

hook.Add("Should Fake Up", "HG_EuphoriaStumble", function(ply)
	local ragdoll = ply.FakeRagdoll
	if not IsValid(ragdoll) then return end
	if falling[ragdoll] then return false end
	if not stumbling[ragdoll] then return end
	stopStumble(ragdoll, "getup")
	return false
end)

local function stopFalling(ragdoll)
	falling[ragdoll] = nil
	if IsValid(ragdoll) then ragdoll.hgStumbleFalling = nil end
end

local function updateFalling(ragdoll, fs)
	local ply = fs.ply
	if not IsValid(ragdoll) or not IsValid(ply) or ply.FakeRagdoll ~= ragdoll or not IsValid(fs.pelvis) or not IsValid(fs.spine) then
		stopFalling(ragdoll)
		return
	end
	if CurTime() > fs.untilT or not isUpright(ply, ragdoll) then
		stopFalling(ragdoll)
		return
	end

	local dt = FrameTime()
	fs.spine:AddVelocity(fs.dir * FALL_FOLLOW_PUSH * dt)
	fs.pelvis:AddVelocity(Vector(0, 0, -FALL_BUCKLE * dt))
end

local function removeDying(ragdoll)
	local ds = dying[ragdoll]
	dying[ragdoll] = nil
	if ds and IsValid(ds.ent) then ds.ent:Remove() end
end

local function canDieReacting(org)
	if not org or org.otrub or org.brainfuckv2Posture or org.headamputated then return false end
	if (org.spine3 or 0) >= 1 then return false end

	return vigor(org) >= VIGOR_MIN
end

local function startDeathThroes(ragdoll, org)
	removeReaction(ragdoll)
	removeDying(ragdoll)

	local pelvis = getBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
	local ctrl = IsValid(pelvis) and spawnController(ragdoll)
	if not ctrl then return end

	local mode = REACT_MODES.writhe
	local seq = ctrl:LookupSequence(mode.sequences[math.random(#mode.sequences)])
	if not seq or seq == -1 then
		ctrl:Remove()
		return
	end

	local bones, strength = reactBones(mode, org, ragdoll)
	ctrl:SetBoneList(bones)
	ctrl:SetBoneStrength(strength)
	ctrl:SetReactionStrength(DEATH_STRENGTH * vigor(org))
	ctrl:ResetSequence(seq)
	ctrl:SetPlaybackRate(mode.rate)
	ctrl:SetCycle(0)

	local now = CurTime()
	dying[ragdoll] = {
		ent = ctrl,
		pelvis = pelvis,
		pelvisBone = ctrl:LookupBone("ValveBiped.Bip01_Pelvis"),
		alignAfter = now,
		startTime = now,
		strength = DEATH_STRENGTH * vigor(org),
	}
end

local function updateDying(ragdoll, ds)
	if not IsValid(ragdoll) or not IsValid(ds.ent) or not IsValid(ds.pelvis) then
		removeDying(ragdoll)
		return
	end

	local frac = (CurTime() - ds.startTime) / DEATH_TIME
	if frac >= 1 then
		removeDying(ragdoll)
		return
	end

	ds.ent:SetReactionStrength(ds.strength * (1 - frac) ^ DEATH_FADE_POW)
	alignController(ds, ds.pelvis)
end

hook.Add("RagdollDeath", "HG_EuphoriaDeathThroes", function(ply, ragdoll)
	if not IsValid(ply) or not ply:IsPlayer() or not IsValid(ragdoll) then return end
	if not hg_euphoria_death_throes:GetBool() or not canDieReacting(ply.organism) then return end

	local org = ply.organism
	timer.Simple(DEATH_DELAY, function()
		if not IsValid(ragdoll) then return end
		local deadOrg = ragdoll.organism or org
		if not canDieReacting(deadOrg) then return end

		startDeathThroes(ragdoll, deadOrg)
	end)
end)

hook.Add("Think", "HG_EuphoriaStumble", function()
	for ragdoll, st in pairs(stumbling) do
		local reason = stumbleEndReason(st.ply, ragdoll, st)
		if reason then
			stopStumble(ragdoll, reason)
			continue
		end

		updateStumble(st, ragdoll)
	end

	for ragdoll, fs in pairs(falling) do
		updateFalling(ragdoll, fs)
	end

	for ragdoll, rs in pairs(reacting) do
		if not IsValid(ragdoll) or not IsValid(rs.ply) or rs.ply.FakeRagdoll ~= ragdoll then
			removeReaction(ragdoll)
		end
	end

	for ragdoll, ds in pairs(dying) do
		updateDying(ragdoll, ds)
	end

	local now = CurTime()
	local stumbleEnabled = hg_euphoria_getup_stumble:GetBool()
	for _, ply in player.Iterator() do
		local ragdoll = ply.FakeRagdoll
		if not IsValid(ragdoll) then continue end

		updateReaction(ply, ragdoll)
		updateHoldEnv(ply, ragdoll)

		local pending = ragdoll.hgStumblePending
		if not stumbleEnabled or stumbling[ragdoll] or not pending or now < pending.from then continue end
		if now > pending.untilT then
			ragdoll.hgStumblePending = nil
			continue
		end

		local ground = groundTrace(ply, ragdoll, UPRIGHT_TRACE)
		if canStumble(ply, ragdoll) and not hg.KeyDown(ply, IN_DUCK) and hasMomentum(ply, ragdoll)
			and ground.Hit and UPRIGHT_TRACE * ground.Fraction > UPRIGHT_MIN_HEIGHT then
			startStumble(ply, ragdoll)
		end
	end
end)
