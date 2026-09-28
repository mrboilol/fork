local enabled = CreateClientConVar("hg_bodystatus_enabled", "1", true, false, "Show the live body status HUD")

local IsValid = IsValid
local CurTime = CurTime
local FrameTime = FrameTime
local FrameNumber = FrameNumber
local ScrH = ScrH
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2
local math_exp = math.exp
local math_ceil = math.ceil
local math_Clamp = math.Clamp

local TAU = math.pi * 2

local SPHERE_MODEL = "models/hunter/misc/sphere025x025.mdl"
local SPHERE_MATERIAL = Material("models/debug/debugwhite")

local PANEL_SIZE_FRACTION = 0.36
local PANEL_MARGIN_FRACTION = 0.02
local DISPLAY_SPINE = 20
local CAMERA_DISTANCE = 175
local CAMERA_PITCH = 14
local CAMERA_FOV = 30
local CAMERA_TARGET_HEIGHT = 0.1
local POSE_SMOOTH_RATE = 20
local YAW_SMOOTH_RATE = 8
local SNAP_AFTER_HIDDEN = 0.5
local MIN_SPINE_LENGTH = 4
local MAX_SPINE_LENGTH = 80
local MIN_AXIS_LENGTH = 0.05
local MEDICAL_UPDATE_INTERVAL = 0.1
local BEAD_SPACING = 1.05
local MAX_BEADS = 6
local SPINE_BACK_OFFSET = 0.28
local SKULL_LIFT = 0.12
local JAW_DROP = 0.13
local JAW_FORWARD = 0.1

local FRACTURE_SEVERITY = 0.85
local BONE_DAMAGE_WEIGHT = 0.7
local SPINE_DAMAGE_WEIGHT = 0.75
local DISLOCATION_SEVERITY = 0.7
local ARTERIAL_SEVERITY = 0.95
local ARTERIAL_CONTROLLED_SEVERITY = 0.6
local ARTERIAL_ACTIVE_RATE = 0.05
local ORGAN_WEIGHT = 1.25
local BRAIN_WEIGHT = 1.6
local THORAX_WEIGHT = 0.8
local HAND_BONE_SHARE = 0.5
local BLEED_RATE_CRITICAL = 8
local BLEED_SEVERITY_MAX = 0.6
local WOUND_SIZE_TO_RATE = 0.24
local ARTERIAL_PULSE_DEPTH = 0.3
local DEFAULT_PULSE = 72
local SECONDS_PER_MINUTE = 60

local DRIP_MATERIAL = CreateMaterial("hg_bodystatus_drip", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
})
local MAX_DRIPS = 96
local MIN_DRIP_RATE = 0.01
local DRIP_CAMERA_BIAS = 2
local VENOUS_DRIP = {
	color = Color(140, 8, 8),
	spawnBase = 0.6, spawnPerRate = 0.8, spawnMax = 6,
	widthBase = 0.6, widthPerRate = 0.15, widthMax = 1.6,
	speed = 10, length = 4, life = 1.3,
}
local ARTERIAL_DRIP = {
	color = Color(255, 25, 25),
	spawnBase = 5, spawnPerRate = 0.4, spawnMax = 12,
	widthBase = 1.2, widthPerRate = 0.05, widthMax = 2.2,
	speed = 36, length = 8, life = 0.8,
}

local HEALTHY_COLOR = {0.92, 0.92, 0.92}
local CRITICAL_COLOR = {0.78, 0.08, 0.08}
local AMBIENT_LIGHT = 0.3
local LIGHTING = {
	{BOX_TOP, 1},
	{BOX_BACK, 0.75},
	{BOX_LEFT, 0.5},
	{BOX_RIGHT, 0.5},
	{BOX_FRONT, 0.35},
	{BOX_BOTTOM, 0.2},
}

local RADIUS = {
	SKULL = 0.2,
	JAW = 0.11,
	NECK = 0.1,
	CHEST = 0.3,
	PELVIS = 0.24,
	SPINE = 0.075,
	UPPER_ARM = 0.1,
	LOWER_ARM = 0.09,
	HAND = 0.085,
	THIGH = 0.13,
	CALF = 0.11,
	FOOT = 0.1,
}

local BONE = {
	PELVIS = 1,
	SPINE1 = 2,
	SPINE2 = 3,
	SPINE4 = 4,
	NECK = 5,
	HEAD = 6,
	JAW = 7,
	L_UPPERARM = 8,
	L_FOREARM = 9,
	L_HAND = 10,
	R_UPPERARM = 11,
	R_FOREARM = 12,
	R_HAND = 13,
	L_THIGH = 14,
	L_CALF = 15,
	L_FOOT = 16,
	L_TOE = 17,
	R_THIGH = 18,
	R_CALF = 19,
	R_FOOT = 20,
	R_TOE = 21,
}

local BONE_CANDIDATES = {
	[BONE.PELVIS] = {"ValveBiped.Bip01_Pelvis", "Bip01 Pelvis", "bip_pelvis", "mixamorig:Hips"},
	[BONE.SPINE1] = {"ValveBiped.Bip01_Spine1", "Bip01 Spine1", "bip_spine_1", "mixamorig:Spine"},
	[BONE.SPINE2] = {"ValveBiped.Bip01_Spine2", "Bip01 Spine2", "bip_spine_2", "mixamorig:Spine1"},
	[BONE.SPINE4] = {"ValveBiped.Bip01_Spine4", "Bip01 Spine4", "bip_spine_3", "mixamorig:Spine2"},
	[BONE.NECK] = {"ValveBiped.Bip01_Neck1", "Bip01 Neck", "Bip01 Neck1", "bip_neck", "mixamorig:Neck"},
	[BONE.HEAD] = {"ValveBiped.Bip01_Head1", "Bip01 Head", "Bip01 Head1", "bip_head", "mixamorig:Head"},
	[BONE.JAW] = {"ValveBiped.Bip01_Jaw", "ValveBiped.jaw", "Bip01 Jaw", "jaw", "Jaw"},
	[BONE.L_UPPERARM] = {"ValveBiped.Bip01_L_UpperArm", "Bip01 L UpperArm", "bip_upperArm_L", "mixamorig:LeftArm"},
	[BONE.L_FOREARM] = {"ValveBiped.Bip01_L_Forearm", "Bip01 L Forearm", "bip_lowerArm_L", "mixamorig:LeftForeArm"},
	[BONE.L_HAND] = {"ValveBiped.Bip01_L_Hand", "Bip01 L Hand", "bip_hand_L", "mixamorig:LeftHand"},
	[BONE.R_UPPERARM] = {"ValveBiped.Bip01_R_UpperArm", "Bip01 R UpperArm", "bip_upperArm_R", "mixamorig:RightArm"},
	[BONE.R_FOREARM] = {"ValveBiped.Bip01_R_Forearm", "Bip01 R Forearm", "bip_lowerArm_R", "mixamorig:RightForeArm"},
	[BONE.R_HAND] = {"ValveBiped.Bip01_R_Hand", "Bip01 R Hand", "bip_hand_R", "mixamorig:RightHand"},
	[BONE.L_THIGH] = {"ValveBiped.Bip01_L_Thigh", "Bip01 L Thigh", "bip_hip_L", "mixamorig:LeftUpLeg"},
	[BONE.L_CALF] = {"ValveBiped.Bip01_L_Calf", "Bip01 L Calf", "bip_knee_L", "mixamorig:LeftLeg"},
	[BONE.L_FOOT] = {"ValveBiped.Bip01_L_Foot", "Bip01 L Foot", "bip_foot_L", "mixamorig:LeftFoot"},
	[BONE.L_TOE] = {"ValveBiped.Bip01_L_Toe0", "Bip01 L Toe0", "bip_toe_L", "mixamorig:LeftToeBase"},
	[BONE.R_THIGH] = {"ValveBiped.Bip01_R_Thigh", "Bip01 R Thigh", "bip_hip_R", "mixamorig:RightUpLeg"},
	[BONE.R_CALF] = {"ValveBiped.Bip01_R_Calf", "Bip01 R Calf", "bip_knee_R", "mixamorig:RightLeg"},
	[BONE.R_FOOT] = {"ValveBiped.Bip01_R_Foot", "Bip01 R Foot", "bip_foot_R", "mixamorig:RightFoot"},
	[BONE.R_TOE] = {"ValveBiped.Bip01_R_Toe0", "Bip01 R Toe0", "bip_toe_R", "mixamorig:RightToeBase"},
}
local BONE_COUNT = #BONE_CANDIDATES

local POINT = {
	PELVIS = 1,
	CHEST = 2,
	NECK = 3,
	SKULL = 4,
	JAW = 5,
	SPINE_TOP = 6,
	SPINE_MID = 7,
	SPINE_LOW = 8,
	L_SHOULDER = 9,
	L_ELBOW = 10,
	L_WRIST = 11,
	R_SHOULDER = 12,
	R_ELBOW = 13,
	R_WRIST = 14,
	L_HIP = 15,
	L_KNEE = 16,
	L_ANKLE = 17,
	L_FOOT = 18,
	R_HIP = 19,
	R_KNEE = 20,
	R_ANKLE = 21,
	R_FOOT = 22,
}
local POINT_COUNT = 22

local LIMB_POINT_BONES = {
	[POINT.L_SHOULDER] = BONE.L_UPPERARM,
	[POINT.L_ELBOW] = BONE.L_FOREARM,
	[POINT.L_WRIST] = BONE.L_HAND,
	[POINT.R_SHOULDER] = BONE.R_UPPERARM,
	[POINT.R_ELBOW] = BONE.R_FOREARM,
	[POINT.R_WRIST] = BONE.R_HAND,
	[POINT.L_HIP] = BONE.L_THIGH,
	[POINT.L_KNEE] = BONE.L_CALF,
	[POINT.L_ANKLE] = BONE.L_FOOT,
	[POINT.R_HIP] = BONE.R_THIGH,
	[POINT.R_KNEE] = BONE.R_CALF,
	[POINT.R_ANKLE] = BONE.R_FOOT,
}

local LIMBS = {
	{
		base = "lleg", upper = "llegup", lower = "lleg",
		points = {POINT.L_HIP, POINT.L_KNEE, POINT.L_ANKLE, POINT.L_FOOT},
		radii = {RADIUS.THIGH, RADIUS.CALF, RADIUS.FOOT},
	},
	{
		base = "rleg", upper = "rlegup", lower = "rleg",
		points = {POINT.R_HIP, POINT.R_KNEE, POINT.R_ANKLE, POINT.R_FOOT},
		radii = {RADIUS.THIGH, RADIUS.CALF, RADIUS.FOOT},
	},
	{
		base = "larm", upper = "larmup", lower = "larm", hand = "lhand",
		points = {POINT.L_SHOULDER, POINT.L_ELBOW, POINT.L_WRIST},
		radii = {RADIUS.UPPER_ARM, RADIUS.LOWER_ARM, RADIUS.HAND},
	},
	{
		base = "rarm", upper = "rarmup", lower = "rarm", hand = "rhand",
		points = {POINT.R_SHOULDER, POINT.R_ELBOW, POINT.R_WRIST},
		radii = {RADIUS.UPPER_ARM, RADIUS.LOWER_ARM, RADIUS.HAND},
	},
}

local REGIONS = {
	"skull", "jaw", "neck", "chest", "spine2", "spine1", "pelvis",
	"larmup", "larm", "lhand", "rarmup", "rarm", "rhand",
	"llegup", "lleg", "rlegup", "rleg",
}

local TORSO_BONE_REGIONS = {
	["ValveBiped.Bip01_Head1"] = "skull",
	["ValveBiped.Bip01_Neck1"] = "neck",
	["ValveBiped.Bip01_Spine4"] = "chest",
	["ValveBiped.Bip01_Spine2"] = "chest",
	["ValveBiped.Bip01_L_Clavicle"] = "chest",
	["ValveBiped.Bip01_R_Clavicle"] = "chest",
	["ValveBiped.Bip01_Spine1"] = "pelvis",
	["ValveBiped.Bip01_Spine"] = "pelvis",
	["ValveBiped.Bip01_Pelvis"] = "pelvis",
	["ValveBiped.Bip01_L_Toe0"] = "lleg",
	["ValveBiped.Bip01_R_Toe0"] = "rleg",
}

local REGION_SEGMENTS = {
	skull = {POINT.SKULL, POINT.SKULL, RADIUS.SKULL},
	jaw = {POINT.JAW, POINT.JAW, RADIUS.JAW},
	neck = {POINT.NECK, POINT.NECK, RADIUS.NECK},
	chest = {POINT.CHEST, POINT.CHEST, RADIUS.CHEST},
	pelvis = {POINT.PELVIS, POINT.PELVIS, RADIUS.PELVIS},
	larmup = {POINT.L_SHOULDER, POINT.L_ELBOW, RADIUS.UPPER_ARM},
	larm = {POINT.L_ELBOW, POINT.L_WRIST, RADIUS.LOWER_ARM},
	lhand = {POINT.L_WRIST, POINT.L_WRIST, RADIUS.HAND},
	rarmup = {POINT.R_SHOULDER, POINT.R_ELBOW, RADIUS.UPPER_ARM},
	rarm = {POINT.R_ELBOW, POINT.R_WRIST, RADIUS.LOWER_ARM},
	rhand = {POINT.R_WRIST, POINT.R_WRIST, RADIUS.HAND},
	llegup = {POINT.L_HIP, POINT.L_KNEE, RADIUS.THIGH},
	lleg = {POINT.L_KNEE, POINT.L_ANKLE, RADIUS.CALF},
	rlegup = {POINT.R_HIP, POINT.R_KNEE, RADIUS.THIGH},
	rleg = {POINT.R_KNEE, POINT.R_ANKLE, RADIUS.CALF},
}

local ARTERY_REGIONS = {
	arteria = "neck",
	aorta = "chest",
	larmartery = "larm",
	rarmartery = "rarm",
	llegartery = "lleg",
	rlegartery = "rleg",
}

local worldPos = {}
local eyesPos, eyesForward
local captureFrame, captureBody = -1, nil
local trackedBody

local poseX, poseY, poseZ = {}, {}, {}
local pointValid = {}
local smoothX, smoothY, smoothZ = {}, {}, {}
local smoothValid = {}
local smoothYaw = 0
local lastBody
local lastDrawTime = 0

local severity = {}
local arterial, missing = {}, {}
local regionBleed, regionArterial = {}, {}
local nextMedicalUpdate = 0
local pulseHz = DEFAULT_PULSE / SECONDS_PER_MINUTE
local currentOrg, woundSource

local emitters = {}
local emitterCount = 0
local drips = {}
local nextDripSlot = 1
for i = 1, MAX_DRIPS do
	drips[i] = {alive = false, x = 0, y = 0, z = 0, born = 0, width = 1, style = VENOUS_DRIP}
end

local sphereEnt, sphereRadius
local sphereMatrix = Matrix()
local sphereScale = Vector(1, 1, 1)
local spherePos = Vector()

local function getBodyEntity(ply)
	if not IsValid(ply) then return end

	local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
	if IsValid(body) and body ~= ply then return body end
	if ply:GetNWBool("FakeGettingUp", false) and IsValid(ply.OldRagdoll) then return ply.OldRagdoll end
	if ply:Alive() then return ply end

	local deathRagdoll = ply:GetNWEntity("RagdollDeath")
	if IsValid(deathRagdoll) then return deathRagdoll end
end

local function getBoneCache(ent)
	local model = ent:GetModel()
	local cache = ent.hgBodyStatusBones
	if cache and cache.model == model then return cache end

	cache = {model = model}
	for index = 1, BONE_COUNT do
		local id = -1
		for _, name in ipairs(BONE_CANDIDATES[index]) do
			local found = ent:LookupBone(name)
			if found then
				id = found
				break
			end
		end
		cache[index] = id
	end
	local eyes = ent:LookupAttachment("eyes")
	cache.eyes = eyes and eyes > 0 and eyes or -1
	ent.hgBodyStatusBones = cache

	return cache
end

local function resolveWoundRegion(bone)
	if not isstring(bone) then return end

	return TORSO_BONE_REGIONS[bone] or (hg.amputeetable and hg.amputeetable[bone])
end

local function lookupNamedBone(ent, cache, bone)
	if isnumber(bone) then return bone end
	if not isstring(bone) then return end

	cache.named = cache.named or {}
	local id = cache.named[bone]
	if id == nil then
		id = ent:LookupBone(bone) or false
		cache.named[bone] = id
	end

	return id or nil
end

local function addEmitter(ent, cache, wound, region, rate, arterialWound)
	if not region or not isvector(wound[2]) or rate <= MIN_DRIP_RATE then return end

	local id = lookupNamedBone(ent, cache, wound[4])
	local matrix = id and ent:GetBoneMatrix(id)
	if not matrix then return end

	emitterCount = emitterCount + 1
	local emitter = emitters[emitterCount]
	if not emitter then
		emitter = {}
		emitters[emitterCount] = emitter
	end
	emitter.world = LocalToWorld(wound[2], angle_zero, matrix:GetTranslation(), matrix:GetAngles())
	emitter.region, emitter.rate, emitter.arterial = region, rate, arterialWound
	emitter.valid = false
end

local function woundRate(rates, index, wound, sizeToRate)
	local rate = istable(rates) and tonumber(rates[index]) or tonumber(wound.visualBleedRate)

	return rate or (tonumber(wound[1]) or 0) * sizeToRate
end

local function captureWounds(ent, cache)
	emitterCount = 0
	if not IsValid(woundSource) or not istable(currentOrg) then return end

	local wounds, arterialWounds = woundSource.wounds, woundSource.arterialwounds
	if istable(wounds) then
		for index, wound in ipairs(wounds) do
			if (tonumber(wound[1]) or 0) > 0 then
				local rate = woundRate(currentOrg.woundBleedRates, index, wound, WOUND_SIZE_TO_RATE)
				addEmitter(ent, cache, wound, resolveWoundRegion(wound[4]), rate, false)
			end
		end
	end
	if not istable(arterialWounds) then return end

	for index, wound in ipairs(arterialWounds) do
		if (tonumber(wound[1]) or 0) > 0 then
			local rate = woundRate(currentOrg.arterialWoundBleedRates, index, wound, 1)
			local region = ARTERY_REGIONS[wound[7]] or resolveWoundRegion(wound[4])
			addEmitter(ent, cache, wound, region, rate, true)
		end
	end
end

local function captureBones(ent)
	local cache = getBoneCache(ent)
	for index = 1, BONE_COUNT do
		local id = cache[index]
		local matrix = id >= 0 and ent:GetBoneMatrix(id)
		worldPos[index] = matrix and matrix:GetTranslation() or false
	end

	eyesPos, eyesForward = nil, nil
	if cache.eyes > 0 then
		local attachment = ent:GetAttachment(cache.eyes)
		if attachment then eyesPos, eyesForward = attachment.Pos, attachment.Ang:Forward() end
	end

	captureWounds(ent, cache)
	captureFrame, captureBody = FrameNumber(), ent
end

hook.Add("PostDrawAppearance", "homigrad/body-status/capture-rendered-pose", function(ent)
	if ent ~= trackedBody or not IsValid(ent) then return end

	captureBones(ent)
end)

local frameRoot, frameUp, frameForward, frameSpineLength, yawCos, yawSin

local function buildFrame()
	local pelvis, neck = worldPos[BONE.PELVIS], worldPos[BONE.NECK] or worldPos[BONE.SPINE4]
	if not pelvis or not neck then return false end

	local up = neck - pelvis
	local spineLength = up:Length()
	if spineLength < MIN_SPINE_LENGTH or spineLength > MAX_SPINE_LENGTH then return false end
	up:Div(spineLength)

	local right = Vector(0, 0, 0)
	local lThigh, rThigh = worldPos[BONE.L_THIGH], worldPos[BONE.R_THIGH]
	local lArm, rArm = worldPos[BONE.L_UPPERARM], worldPos[BONE.R_UPPERARM]
	if lThigh and rThigh then right:Add(rThigh - lThigh) end
	if lArm and rArm then right:Add(rArm - lArm) end
	right:Sub(up * right:Dot(up))
	if right:Length() < MIN_AXIS_LENGTH then return false end
	right:Normalize()

	local forward = up:Cross(right)
	local headingX, headingY = right.x + forward.y, right.y - forward.x
	if headingX * headingX + headingY * headingY < MIN_AXIS_LENGTH * MIN_AXIS_LENGTH then return false end

	frameRoot, frameUp, frameForward, frameSpineLength = pelvis, up, forward, spineLength

	return true, math.deg(math_atan2(headingX, -headingY))
end

local function projectRaw(pos)
	local scale = DISPLAY_SPINE / frameSpineLength
	local dx, dy = pos.x - frameRoot.x, pos.y - frameRoot.y

	return (dx * yawCos + dy * yawSin) * scale, (dy * yawCos - dx * yawSin) * scale, (pos.z - frameRoot.z) * scale
end

local function projectPoint(index, pos)
	if not pos then
		pointValid[index] = false
		return
	end

	poseX[index], poseY[index], poseZ[index] = projectRaw(pos)
	pointValid[index] = true
end

local function placeEmitter(emitter)
	local segment = REGION_SEGMENTS[emitter.region]
	if not segment or missing[emitter.region] then return end

	local a, b = segment[1], segment[2]
	if not smoothValid[a] or not smoothValid[b] or not pointValid[a] or not pointValid[b] then return end

	local wx, wy, wz = projectRaw(emitter.world)
	local ax, ay, az = poseX[a], poseY[a], poseZ[a]
	local abx, aby, abz = poseX[b] - ax, poseY[b] - ay, poseZ[b] - az
	local lengthSqr = abx * abx + aby * aby + abz * abz
	local along = (wx - ax) * abx + (wy - ay) * aby + (wz - az) * abz
	local t = lengthSqr > 0.001 and math_Clamp(along / lengthSqr, 0, 1) or 0

	local rx = wx - (ax + abx * t) - DRIP_CAMERA_BIAS
	local ry = wy - (ay + aby * t)
	local rz = wz - (az + abz * t)
	local radialLength = math_sqrt(rx * rx + ry * ry + rz * rz)
	if radialLength < 0.001 then rx, ry, rz, radialLength = -1, 0, 0, 1 end

	local surface = segment[3] * DISPLAY_SPINE / radialLength
	local sx, sy, sz = smoothX[a], smoothY[a], smoothZ[a]
	emitter.x = sx + (smoothX[b] - sx) * t + rx * surface
	emitter.y = sy + (smoothY[b] - sy) * t + ry * surface
	emitter.z = sz + (smoothZ[b] - sz) * t + rz * surface
	emitter.valid = true
end

local function backOffset(pos)
	return pos and pos - frameForward * (SPINE_BACK_OFFSET * frameSpineLength)
end

local function getHeadPoints(neck)
	local head = worldPos[BONE.HEAD]
	if not head then return end

	local headUp = head - neck
	if headUp:Length() > 0 then headUp:Normalize() end
	local face = eyesForward or frameForward
	local skull = head + headUp * (SKULL_LIFT * frameSpineLength)
	local jaw = worldPos[BONE.JAW] or skull + (face * JAW_FORWARD - headUp * JAW_DROP) * frameSpineLength

	return skull, jaw
end

local function updatePose(snap)
	local ok, targetYaw = buildFrame()
	if not ok then return false end

	if snap then
		smoothYaw = targetYaw
	else
		local blend = 1 - math_exp(-FrameTime() * YAW_SMOOTH_RATE)
		smoothYaw = math.NormalizeAngle(smoothYaw + math.AngleDifference(targetYaw, smoothYaw) * blend)
	end
	local yawRadians = math.rad(smoothYaw)
	yawCos, yawSin = math_cos(yawRadians), math_sin(yawRadians)

	local neck = worldPos[BONE.NECK] or worldPos[BONE.SPINE4]
	local upperChest = worldPos[BONE.SPINE4] or neck
	local midChest = worldPos[BONE.SPINE2] or LerpVector(0.5, frameRoot, neck)
	projectPoint(POINT.PELVIS, frameRoot)
	projectPoint(POINT.CHEST, LerpVector(0.5, upperChest, midChest))
	projectPoint(POINT.NECK, neck)
	projectPoint(POINT.SPINE_TOP, backOffset(neck))
	projectPoint(POINT.SPINE_MID, backOffset(midChest))
	projectPoint(POINT.SPINE_LOW, backOffset(frameRoot))

	local skull, jaw = getHeadPoints(neck)
	projectPoint(POINT.SKULL, skull or neck + frameUp * (SKULL_LIFT * 2 * frameSpineLength))
	projectPoint(POINT.JAW, jaw)

	for point, bone in pairs(LIMB_POINT_BONES) do
		projectPoint(point, worldPos[bone])
	end

	local lFoot, rFoot = worldPos[BONE.L_FOOT], worldPos[BONE.R_FOOT]
	projectPoint(POINT.L_FOOT, lFoot and (worldPos[BONE.L_TOE] and LerpVector(0.5, lFoot, worldPos[BONE.L_TOE]) or lFoot))
	projectPoint(POINT.R_FOOT, rFoot and (worldPos[BONE.R_TOE] and LerpVector(0.5, rFoot, worldPos[BONE.R_TOE]) or rFoot))

	local blend = 1 - math_exp(-FrameTime() * POSE_SMOOTH_RATE)
	for index = 1, POINT_COUNT do
		if pointValid[index] then
			if snap or not smoothValid[index] then
				smoothX[index], smoothY[index], smoothZ[index] = poseX[index], poseY[index], poseZ[index]
			else
				smoothX[index] = smoothX[index] + (poseX[index] - smoothX[index]) * blend
				smoothY[index] = smoothY[index] + (poseY[index] - smoothY[index]) * blend
				smoothZ[index] = smoothZ[index] + (poseZ[index] - smoothZ[index]) * blend
			end
		end
		smoothValid[index] = pointValid[index]
	end

	for i = 1, emitterCount do
		placeEmitter(emitters[i])
	end

	return true
end

local function orgNumber(org, key)
	local value = org[key]

	return isnumber(value) and value or 0
end

local function combine(a, b)
	return 1 - (1 - math_Clamp(a, 0, 1)) * (1 - math_Clamp(b, 0, 1))
end

local function boneSeverity(value)
	if value >= 1 then return FRACTURE_SEVERITY end

	return value * BONE_DAMAGE_WEIGHT
end

local function spineSeverity(value)
	if value >= 1 then return 1 end

	return value * SPINE_DAMAGE_WEIGHT
end

local function organSeverity(org, key)
	return math_Clamp(orgNumber(org, key) * ORGAN_WEIGHT, 0, 1)
end

local function bleedSeverity(region)
	return math_Clamp(regionBleed[region] / BLEED_RATE_CRITICAL, 0, BLEED_SEVERITY_MAX)
end

local function collectWounds(org, wounds, arterialWounds)
	for _, region in ipairs(REGIONS) do
		regionBleed[region] = 0
		regionArterial[region] = 0
	end

	if istable(wounds) then
		local rates = org.woundBleedRates
		for index, wound in ipairs(wounds) do
			local region = resolveWoundRegion(wound[4])
			local size = tonumber(wound[1]) or 0
			if region and size > 0 then
				local rate = istable(rates) and tonumber(rates[index])
					or tonumber(wound.visualBleedRate)
					or size * WOUND_SIZE_TO_RATE
				regionBleed[region] = regionBleed[region] + math.max(rate, 0)
			end
		end
	end

	if istable(arterialWounds) then
		local rates = org.arterialWoundBleedRates
		for index, wound in ipairs(arterialWounds) do
			local region = ARTERY_REGIONS[wound[7]] or resolveWoundRegion(wound[4])
			if region and (tonumber(wound[1]) or 0) > 0 then
				local rate = istable(rates) and tonumber(rates[index])
				local active = not rate or rate > ARTERIAL_ACTIVE_RATE
				local value = active and ARTERIAL_SEVERITY or ARTERIAL_CONTROLLED_SEVERITY
				regionArterial[region] = math.max(regionArterial[region], value)
			end
		end
	end

	for artery, region in pairs(ARTERY_REGIONS) do
		if orgNumber(org, artery) > 0 then
			regionArterial[region] = math.max(regionArterial[region], ARTERIAL_SEVERITY)
		end
	end
end

local function updateLimbState(org, limb)
	local boneSev = boneSeverity(orgNumber(org, limb.base))
	local dislocation = org[limb.base .. "dislocation"] == true and DISLOCATION_SEVERITY or 0
	local upper, lower, hand = limb.upper, limb.lower, limb.hand

	severity[upper] = combine(combine(boneSev, dislocation), bleedSeverity(upper))
	severity[lower] = combine(combine(boneSev, regionArterial[lower]), bleedSeverity(lower))
	arterial[upper], arterial[lower] = regionArterial[upper] > 0, regionArterial[lower] > 0
	missing[upper] = org[upper .. "amputated"] == true
	missing[lower] = missing[upper] or org[lower .. "amputated"] == true
	if not hand then return end

	severity[hand] = combine(boneSev * HAND_BONE_SHARE, bleedSeverity(hand))
	arterial[hand] = regionArterial[hand] > 0
	missing[hand] = missing[lower] or org[hand .. "amputated"] == true
end

local function updateTorsoState(org)
	local headMissing = org.headamputated == true
	local thorax = math_Clamp((orgNumber(org, "pneumothorax") + orgNumber(org, "hemothorax")) * THORAX_WEIGHT, 0, 1)
	local lungs = combine(organSeverity(org, "lungsL"), organSeverity(org, "lungsR"))
	local chestOrgans = combine(combine(organSeverity(org, "heart"), lungs), thorax)
	local chestBleeding = combine(regionArterial.chest, bleedSeverity("chest"))
	local digestive = combine(organSeverity(org, "stomach"), organSeverity(org, "intestines"))
	local abdomen = combine(organSeverity(org, "liver"), digestive)
	local brain = math_Clamp(orgNumber(org, "brain") * BRAIN_WEIGHT, 0, 1)
	local carotid = combine(regionArterial.neck, organSeverity(org, "trachea"))

	severity.skull = combine(combine(boneSeverity(orgNumber(org, "skull")), brain), bleedSeverity("skull"))
	local jawDislocation = org.jawdislocation == true and DISLOCATION_SEVERITY or 0
	severity.jaw = combine(boneSeverity(orgNumber(org, "jaw")), jawDislocation)
	severity.neck = combine(combine(spineSeverity(orgNumber(org, "spine3")), carotid), bleedSeverity("neck"))
	severity.chest = combine(combine(boneSeverity(orgNumber(org, "chest")), chestOrgans), chestBleeding)
	severity.spine2 = spineSeverity(orgNumber(org, "spine2"))
	severity.spine1 = spineSeverity(orgNumber(org, "spine1"))
	severity.pelvis = combine(combine(boneSeverity(orgNumber(org, "pelvis")), abdomen), bleedSeverity("pelvis"))
	arterial.neck, arterial.chest = regionArterial.neck > 0, regionArterial.chest > 0
	missing.skull, missing.jaw = headMissing, headMissing
end

local function clearMedicalState()
	for _, region in ipairs(REGIONS) do
		severity[region] = 0
		arterial[region], missing[region] = false, false
	end
end

local function updateMedicalState(ply, body)
	clearMedicalState()

	local org = ply.new_organism or ply.organism
	if not istable(org) and IsValid(body) and body ~= ply then org = body.new_organism or body.organism end
	currentOrg = istable(org) and org or nil
	if not currentOrg then return end

	local source = ply:Alive() and ply or body
	collectWounds(org, source.wounds, source.arterialwounds)
	updateTorsoState(org)
	for _, limb in ipairs(LIMBS) do
		updateLimbState(org, limb)
	end

	pulseHz = math_Clamp((tonumber(org.pulse) or DEFAULT_PULSE) / SECONDS_PER_MINUTE, 0.5, 3)
end

local function getSphereEntity()
	if IsValid(sphereEnt) then return sphereEnt end

	sphereEnt = ClientsideModel(SPHERE_MODEL, RENDERGROUP_OTHER)
	if not IsValid(sphereEnt) then return end

	sphereEnt:SetNoDraw(true)
	sphereRadius = math.max((sphereEnt:OBBMaxs().x - sphereEnt:OBBMins().x) * 0.5, 1)

	return sphereEnt
end

local function setRegionColor(region)
	local t = math_Clamp(severity[region] or 0, 0, 1)
	local r = HEALTHY_COLOR[1] + (CRITICAL_COLOR[1] - HEALTHY_COLOR[1]) * t
	local g = HEALTHY_COLOR[2] + (CRITICAL_COLOR[2] - HEALTHY_COLOR[2]) * t
	local b = HEALTHY_COLOR[3] + (CRITICAL_COLOR[3] - HEALTHY_COLOR[3]) * t
	if arterial[region] then
		local mul = 1 - ARTERIAL_PULSE_DEPTH * (0.5 + 0.5 * math_sin(CurTime() * pulseHz * TAU))
		r, g, b = r * mul, g * mul, b * mul
	end
	render.SetColorModulation(r, g, b)
end

local function drawSphere(x, y, z, radius)
	local scale = radius * DISPLAY_SPINE / sphereRadius
	sphereScale.x, sphereScale.y, sphereScale.z = scale, scale, scale
	sphereMatrix:SetScale(sphereScale)
	sphereEnt:EnableMatrix("RenderMultiply", sphereMatrix)
	spherePos.x, spherePos.y, spherePos.z = x, y, z
	sphereEnt:SetPos(spherePos)
	sphereEnt:SetupBones()
	sphereEnt:DrawModel()
end

local function drawNode(point, region, radius)
	if not smoothValid[point] or missing[region] then return end

	setRegionColor(region)
	drawSphere(smoothX[point], smoothY[point], smoothZ[point], radius)
end

local function drawSegment(fromPoint, toPoint, region, radius, includeEnd)
	if not smoothValid[fromPoint] or not smoothValid[toPoint] or missing[region] then return end

	local x0, y0, z0 = smoothX[fromPoint], smoothY[fromPoint], smoothZ[fromPoint]
	local dx, dy, dz = smoothX[toPoint] - x0, smoothY[toPoint] - y0, smoothZ[toPoint] - z0
	local length = math_sqrt(dx * dx + dy * dy + dz * dz)
	local beads = math_Clamp(math_ceil(length / (radius * DISPLAY_SPINE * BEAD_SPACING)), 1, MAX_BEADS)
	local last = includeEnd and beads or beads - 1

	setRegionColor(region)
	for i = 0, last do
		local t = i / beads
		drawSphere(x0 + dx * t, y0 + dy * t, z0 + dz * t, radius)
	end
end

local function drawLimb(limb)
	local points, radii = limb.points, limb.radii
	drawSegment(points[1], points[2], limb.upper, radii[1], false)
	if missing[limb.upper] then return end

	local foot = points[4]
	if foot then
		drawSegment(points[2], points[3], limb.lower, radii[2], false)
		drawSegment(points[3], foot, limb.lower, radii[3], true)
		return
	end
	drawSegment(points[2], points[3], limb.lower, radii[2], false)
	if not missing[limb.lower] then drawNode(points[3], limb.hand, radii[3]) end
end

local function drawBody()
	drawNode(POINT.PELVIS, "pelvis", RADIUS.PELVIS)
	drawNode(POINT.CHEST, "chest", RADIUS.CHEST)
	drawNode(POINT.NECK, "neck", RADIUS.NECK)
	drawSegment(POINT.SPINE_TOP, POINT.SPINE_MID, "spine2", RADIUS.SPINE, false)
	drawSegment(POINT.SPINE_MID, POINT.SPINE_LOW, "spine1", RADIUS.SPINE, true)
	drawNode(POINT.SKULL, "skull", RADIUS.SKULL)
	drawNode(POINT.JAW, "jaw", RADIUS.JAW)
	for _, limb in ipairs(LIMBS) do
		drawLimb(limb)
	end
end

local function spawnDrip(emitter, style)
	local drip = drips[nextDripSlot]
	nextDripSlot = nextDripSlot % MAX_DRIPS + 1
	drip.alive, drip.style, drip.born = true, style, CurTime()
	drip.x, drip.y, drip.z = emitter.x, emitter.y, emitter.z
	drip.width = math.min(style.widthBase + emitter.rate * style.widthPerRate, style.widthMax)
end

local function spawnDrips()
	local dt = FrameTime()
	for i = 1, emitterCount do
		local emitter = emitters[i]
		if emitter.valid then
			local style = emitter.arterial and ARTERIAL_DRIP or VENOUS_DRIP
			local perSecond = math.min(style.spawnBase + emitter.rate * style.spawnPerRate, style.spawnMax)
			local expected = perSecond * dt
			local count = math.floor(expected) + (math.random() < expected % 1 and 1 or 0)
			for _ = 1, count do
				spawnDrip(emitter, style)
			end
		end
	end
end

local dripStart, dripEnd = Vector(), Vector()

local function drawDrips()
	local now = CurTime()
	render.SetMaterial(DRIP_MATERIAL)
	for i = 1, MAX_DRIPS do
		local drip = drips[i]
		if drip.alive then
			local style = drip.style
			local age = now - drip.born
			if age >= style.life then
				drip.alive = false
			else
				local fall = age * style.speed
				dripStart:SetUnpacked(drip.x, drip.y, drip.z - math.max(fall - style.length, 0))
				dripEnd:SetUnpacked(drip.x, drip.y, drip.z - fall)
				local color = style.color
				color.a = 255 * (1 - age / style.life)
				render.DrawBeam(dripStart, dripEnd, drip.width, 0, 1, color)
			end
		end
	end
end

local function renderFigure()
	if not getSphereEntity() then return end

	local size = ScrH() * PANEL_SIZE_FRACTION
	local x = ScrH() * PANEL_MARGIN_FRACTION
	local y = (ScrH() - size) * 0.5
	local pitch = math.rad(CAMERA_PITCH)
	local targetZ = CAMERA_TARGET_HEIGHT * DISPLAY_SPINE
	local camPos = Vector(-CAMERA_DISTANCE * math_cos(pitch), 0, targetZ + CAMERA_DISTANCE * math_sin(pitch))
	local camAng = Angle(CAMERA_PITCH, 0, 0)

	cam.Start3D(camPos, camAng, CAMERA_FOV, x, y, size, size)
		render.ClearDepth()
		render.SuppressEngineLighting(true)
		render.ResetModelLighting(AMBIENT_LIGHT, AMBIENT_LIGHT, AMBIENT_LIGHT)
		for _, light in ipairs(LIGHTING) do
			render.SetModelLighting(light[1], light[2], light[2], light[2])
		end
		render.MaterialOverride(SPHERE_MATERIAL)

		drawBody()

		render.MaterialOverride(nil)
		render.SetColorModulation(1, 1, 1)
		render.SuppressEngineLighting(false)
		spawnDrips()
		drawDrips()
	cam.End3D()
end

hook.Add("HUDPaint", "homigrad/body-status/draw", function()
	if not enabled:GetBool() then
		trackedBody = nil
		return
	end

	local ply = LocalPlayer()
	local body = getBodyEntity(ply)
	trackedBody = body
	if not IsValid(body) or body:IsDormant() then return end
	woundSource = ply:Alive() and ply or body

	local now = CurTime()
	local snap = body ~= lastBody or now - lastDrawTime > SNAP_AFTER_HIDDEN
	if snap then smoothValid[POINT.PELVIS] = false end
	if captureBody ~= body or captureFrame ~= FrameNumber() then captureBones(body) end
	if updatePose(snap) then lastBody = body end
	lastDrawTime = now
	if not smoothValid[POINT.PELVIS] then return end

	if snap or now >= nextMedicalUpdate then
		updateMedicalState(ply, body)
		nextMedicalUpdate = now + MEDICAL_UPDATE_INTERVAL
	end

	renderFigure()
end)
