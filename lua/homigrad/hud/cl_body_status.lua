local enabled = CreateClientConVar("hg_subrosa", "1", true, false, "sub rosa hud")

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
local math_Clamp = math.Clamp

local TAU = math.pi * 2

local PANEL_SIZE_FRACTION = 0.36
local PANEL_MARGIN_FRACTION = 0.02
local DISPLAY_SPINE = 20
local FIGURE_EXTENT = 3.8
local TARGET_HEIGHT = 0.1
local DEPTH_SCALE = 0.012
local DEPTH_SCALE_MIN = 0.75
local DEPTH_SCALE_MAX = 1.3
local CIRCLE_SEGMENTS = 24
local FILL_ALPHA = 235
local OUTLINE_ALPHA = 220
local POSE_SMOOTH_RATE = 20
local YAW_SMOOTH_RATE = 8
local SNAP_AFTER_HIDDEN = 0.5
local MIN_SPINE_LENGTH = 4
local MAX_SPINE_LENGTH = 80
local MIN_AXIS_LENGTH = 0.05
local MEDICAL_UPDATE_INTERVAL = 0.1
local SPINE_BACK_OFFSET = 0.12
local CHEST_INSET = 0.45
local PELVIS_INSET = 0.35
local SKULL_LIFT = 0.12
local JAW_DROP = 0.13
local JAW_FORWARD = 0.1

local WEIGHT = {
	DISLOCATION = 0.7,
	ARTERIAL = 0.95,
	ARTERIAL_CONTROLLED = 0.6,
	HAND_BONE_SHARE = 0.5,
}
local ARTERIAL_ACTIVE_RATE = 0.05
local BLEED_RATE_CRITICAL = 8
local WOUND_SIZE_TO_RATE = 0.24
local ARTERIAL_PULSE_DEPTH = 0.3
local DEFAULT_PULSE = 72
local SECONDS_PER_MINUTE = 60

local WOUND_CAMERA_BIAS = 2
local WOUND_MARK = {
	sizeBase = 1.5, sizePerSize = 0.15, sizeMax = 4,
	venous = {110, 0, 0},
	arterial = {255, 30, 30},
}
local REFERENCE_SCREEN_HEIGHT = 1080

local HEALTH_STOPS = {
	{0, 245, 245, 240, 180},
	{0.5, 255, 225, 40, 255},
	{1, 215, 25, 25, 255},
}
local COLOR = {
	ARMOR_GOOD = {40, 200, 70},
	ARMOR_DAMAGED = {235, 205, 50},
	ARMOR_RUINED = {215, 25, 25},
	ARMOR_FILL_ALPHA = 30,
	ARMOR_LINE_ALPHA = 220,
	RING_HEALTHY = {255, 255, 255},
	RING_BLEEDING = {215, 25, 25},
	TOURNIQUET_RING = {70, 130, 235},
	TOURNIQUET_STRAP = {35, 60, 150},
	BANDAGE_CLEAN = {225, 215, 190},
	BANDAGE_SOAKED = {150, 30, 30},
	OUTLINE = {20, 20, 22},
}
local SHAPE = {
	OUTLINE_WIDTH = 1.5,
	STRAP_THICKNESS = 0.8,
	STRAP_MAX_SEGMENT_SHARE = 0.35,
	TOURNIQUET_STRAP_T = 0.25,
}

local STRESS = {
	PULL_SPEED = 520,
	START_SPEED = 250,
	SMOOTH_RATE = 12,
	VISIBLE = 0.25,
	SHAKE_PIXELS = 3,
}

local RADIUS = {
	SKULL = 0.2,
	NECK = 0.1,
	CHEST = 0.2,
	PELVIS = 0.17,
	SPINE = 0.045,
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
	CHEST_L = 23,
	CHEST_R = 24,
	PELVIS_L = 25,
	PELVIS_R = 26,
}
local POINT_COUNT = 26

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
		bones = {BONE.L_THIGH, BONE.L_CALF, BONE.L_FOOT},
	},
	{
		base = "rleg", upper = "rlegup", lower = "rleg",
		points = {POINT.R_HIP, POINT.R_KNEE, POINT.R_ANKLE, POINT.R_FOOT},
		radii = {RADIUS.THIGH, RADIUS.CALF, RADIUS.FOOT},
		bones = {BONE.R_THIGH, BONE.R_CALF, BONE.R_FOOT},
	},
	{
		base = "larm", upper = "larmup", lower = "larm", hand = "lhand",
		points = {POINT.L_SHOULDER, POINT.L_ELBOW, POINT.L_WRIST},
		radii = {RADIUS.UPPER_ARM, RADIUS.LOWER_ARM, RADIUS.HAND},
		bones = {BONE.L_UPPERARM, BONE.L_FOREARM, BONE.L_HAND},
	},
	{
		base = "rarm", upper = "rarmup", lower = "rarm", hand = "rhand",
		points = {POINT.R_SHOULDER, POINT.R_ELBOW, POINT.R_WRIST},
		radii = {RADIUS.UPPER_ARM, RADIUS.LOWER_ARM, RADIUS.HAND},
		bones = {BONE.R_UPPERARM, BONE.R_FOREARM, BONE.R_HAND},
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
	jaw = {POINT.SKULL, POINT.SKULL, RADIUS.SKULL},
	neck = {POINT.NECK, POINT.NECK, RADIUS.NECK},
	chest = {POINT.CHEST_L, POINT.CHEST_R, RADIUS.CHEST},
	pelvis = {POINT.PELVIS_L, POINT.PELVIS_R, RADIUS.PELVIS},
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
local hitboxCenter = {}
local boneCache
local chestBone, chestBox, pelvisBox
local skullRadius, chestRadius, pelvisRadius = RADIUS.SKULL, RADIUS.CHEST, RADIUS.PELVIS
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

local STRESS_SEGMENTS = {
	{child = BONE.L_UPPERARM, parent = BONE.SPINE4, base = "larm", regions = {"larmup"}},
	{child = BONE.L_FOREARM, parent = BONE.L_UPPERARM, base = "larm", regions = {"larm", "lhand"}},
	{child = BONE.R_UPPERARM, parent = BONE.SPINE4, base = "rarm", regions = {"rarmup"}},
	{child = BONE.R_FOREARM, parent = BONE.R_UPPERARM, base = "rarm", regions = {"rarm", "rhand"}},
	{child = BONE.L_THIGH, parent = BONE.PELVIS, base = "lleg", regions = {"llegup"}},
	{child = BONE.L_CALF, parent = BONE.L_THIGH, base = "lleg", regions = {"lleg"}},
	{child = BONE.R_THIGH, parent = BONE.PELVIS, base = "rleg", regions = {"rlegup"}},
	{child = BONE.R_CALF, parent = BONE.R_THIGH, base = "rleg", regions = {"rleg"}},
}

local severity, broken = {}, {}
local arterial, missing = {}, {}
local bleedLevel, tourniquet, bandage, stress = {}, {}, {}, {}
local regionBleed, regionArterial = {}, {}
local nextMedicalUpdate = 0
local pulseHz = DEFAULT_PULSE / SECONDS_PER_MINUTE
local currentOrg, woundSource

local emitters = {}
local emitterCount = 0
local armorBoxes, armorBoxCount = {}, 0

local circles, circleOrder = {}, {}
local circleCount = 0
local HALF_SEGMENTS = CIRCLE_SEGMENTS / 2
local capsulePoly, halfPoly = {}, {}
for i = 1, HALF_SEGMENTS + 1 do
	halfPoly[i] = {x = 0, y = 0}
end
for i = 1, (HALF_SEGMENTS + 1) * 2 do
	capsulePoly[i] = {x = 0, y = 0}
end

local function getBodyEntity(ply)
	if not IsValid(ply) then return end

	local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
	if IsValid(body) and body ~= ply then return body end
	if ply:GetNWBool("FakeGettingUp", false) and IsValid(ply.OldRagdoll) then return ply.OldRagdoll end
	if ply:Alive() then return ply end

	local deathRagdoll = ply:GetNWEntity("RagdollDeath")
	if IsValid(deathRagdoll) then return deathRagdoll end
end

local function readHitboxes(ent)
	local boxes = {}
	local set = ent:GetHitboxSet() or 0
	for index = 0, (ent:GetHitBoxCount(set) or 0) - 1 do
		local bone = ent:GetHitBoxBone(index, set)
		local mins, maxs = ent:GetHitBoxBounds(index, set)
		if bone and mins and maxs then
			local size = maxs - mins
			local extents = {math.abs(size.x), math.abs(size.y), math.abs(size.z)}
			table.sort(extents, function(a, b) return a > b end)
			local volume = extents[1] * extents[2] * extents[3]
			local existing = boxes[bone]
			if not existing or volume > existing.volume then
				boxes[bone] = {
					extents[1], extents[2], extents[3],
					volume = volume,
					center = (mins + maxs) * 0.5,
				}
			end
		end
	end

	return boxes
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
	cache.hitbox = readHitboxes(ent)
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

local function addEmitter(ent, cache, wound, region, arterialWound)
	if not region or not isvector(wound[2]) then return end

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
	emitter.region, emitter.size, emitter.arterial = region, tonumber(wound[1]) or 0, arterialWound
	emitter.valid = false
end

local function captureWounds(ent, cache)
	emitterCount = 0
	if not IsValid(woundSource) or not istable(currentOrg) then return end

	local wounds, arterialWounds = woundSource.wounds, woundSource.arterialwounds
	if istable(wounds) then
		for index, wound in ipairs(wounds) do
			if (tonumber(wound[1]) or 0) > 0 then
				addEmitter(ent, cache, wound, resolveWoundRegion(wound[4]), false)
			end
		end
	end
	if not istable(arterialWounds) then return end

	for index, wound in ipairs(arterialWounds) do
		if (tonumber(wound[1]) or 0) > 0 then
			local region = ARTERY_REGIONS[wound[7]] or resolveWoundRegion(wound[4])
			addEmitter(ent, cache, wound, region, true)
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

	for index = 1, BONE_COUNT do
		local id = cache[index]
		local box = id >= 0 and cache.hitbox[id]
		local matrix = box and ent:GetBoneMatrix(id)
		hitboxCenter[index] = matrix
			and LocalToWorld(box.center, angle_zero, matrix:GetTranslation(), matrix:GetAngles())
			or false
	end
	boneCache = cache

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

	local lThigh, rThigh = worldPos[BONE.L_THIGH], worldPos[BONE.R_THIGH]
	local lArm, rArm = worldPos[BONE.L_UPPERARM], worldPos[BONE.R_UPPERARM]
	local hipRight = lThigh and rThigh and rThigh - lThigh or lArm and rArm and rArm - lArm
	if not hipRight then return false end

	local hipUp = (worldPos[BONE.SPINE1] or neck) - pelvis
	if hipUp:Length() < MIN_AXIS_LENGTH then hipUp = Vector(up) end
	hipUp:Normalize()
	hipRight:Sub(hipUp * hipRight:Dot(hipUp))
	if hipRight:Length() < MIN_AXIS_LENGTH then return false end
	hipRight:Normalize()

	local hipForward = hipUp:Cross(hipRight)
	local headingX, headingY = hipRight.x + hipForward.y, hipRight.y - hipForward.x
	if headingX * headingX + headingY * headingY < MIN_AXIS_LENGTH * MIN_AXIS_LENGTH then return false end

	local torsoRight = lArm and rArm and rArm - lArm or Vector(hipRight)
	torsoRight:Sub(up * torsoRight:Dot(up))
	local forward = torsoRight:Length() < MIN_AXIS_LENGTH and hipForward or up:Cross(torsoRight:GetNormalized())

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

	local rx = wx - (ax + abx * t) + WOUND_CAMERA_BIAS
	local ry = wy - (ay + aby * t)
	local rz = wz - (az + abz * t)
	local radialLength = math_sqrt(rx * rx + ry * ry + rz * rz)
	if radialLength < 0.001 then rx, ry, rz, radialLength = 1, 0, 0, 1 end

	local surface = segment[3] * DISPLAY_SPINE / radialLength
	local sx, sy, sz = smoothX[a], smoothY[a], smoothZ[a]
	emitter.x = sx + (smoothX[b] - sx) * t + rx * surface
	emitter.y = sy + (smoothY[b] - sy) * t + ry * surface
	emitter.z = sz + (smoothZ[b] - sz) * t + rz * surface

	local planeLength = math_sqrt(ry * ry + rz * rz)
	if planeLength < 0.001 then
		emitter.dirX, emitter.dirZ = 0, -1
	else
		emitter.dirX, emitter.dirZ = ry / planeLength, rz / planeLength
	end
	emitter.valid = true
end

local function backOffset(pos)
	return pos and pos - frameForward * (SPINE_BACK_OFFSET * frameSpineLength)
end

local function insetPoint(index, side, center, inset)
	projectPoint(index, side and LerpVector(inset, side, center) or center)
end

local function boneBox(bone)
	local id = boneCache and boneCache[bone]

	return id and id >= 0 and boneCache.hitbox[id] or nil
end

local function limbRadius(bone, fallback, round)
	local box = boneBox(bone)
	if not box then return fallback end

	local size = round and (box[1] + box[2] + box[3]) / 6 or (box[2] + box[3]) * 0.25

	return size / frameSpineLength
end

local function projectTorsoShape(leftIndex, rightIndex, center, box, sideLeft, sideRight, inset)
	local left, right = sideLeft, sideRight
	if not box or not left or not right then
		insetPoint(leftIndex, left, center, inset)
		insetPoint(rightIndex, right, center, inset)
		return
	end

	local across = right - left
	across:Normalize()
	local halfSpan = math.max(box[1] - box[2], 0) * 0.5
	projectPoint(leftIndex, center - across * halfSpan)
	projectPoint(rightIndex, center + across * halfSpan)
end

local function findChestBox()
	for _, bone in ipairs({BONE.SPINE2, BONE.SPINE4, BONE.SPINE1}) do
		local box = boneBox(bone)
		if box then return bone, box end
	end
end

local function updateProportions()
	chestBone, chestBox = findChestBox()
	pelvisBox = boneBox(BONE.PELVIS)
	local headBox = boneBox(BONE.HEAD)
	skullRadius = headBox and (headBox[1] + headBox[2] + headBox[3]) / 6 / frameSpineLength or RADIUS.SKULL
	chestRadius = chestBox and chestBox[2] * 0.5 / frameSpineLength or RADIUS.CHEST
	pelvisRadius = pelvisBox and pelvisBox[2] * 0.5 / frameSpineLength or RADIUS.PELVIS
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
	local chestCenter = LerpVector(0.5, upperChest, midChest)
	projectPoint(POINT.PELVIS, frameRoot)
	projectPoint(POINT.CHEST, chestCenter)
	projectPoint(POINT.NECK, neck)
	projectPoint(POINT.SPINE_TOP, backOffset(midChest))
	projectPoint(POINT.SPINE_MID, backOffset(LerpVector(0.5, midChest, frameRoot)))
	projectPoint(POINT.SPINE_LOW, backOffset(frameRoot))
	updateProportions()
	local chestShapeCenter = chestBone and hitboxCenter[chestBone] or chestCenter
	local pelvisShapeCenter = hitboxCenter[BONE.PELVIS] or frameRoot
	local lArm, rArm = worldPos[BONE.L_UPPERARM], worldPos[BONE.R_UPPERARM]
	local lThigh, rThigh = worldPos[BONE.L_THIGH], worldPos[BONE.R_THIGH]
	projectTorsoShape(POINT.CHEST_L, POINT.CHEST_R, chestShapeCenter, chestBox, lArm, rArm, CHEST_INSET)
	projectTorsoShape(POINT.PELVIS_L, POINT.PELVIS_R, pelvisShapeCenter, pelvisBox, lThigh, rThigh, PELVIS_INSET)

	local skull, jaw = getHeadPoints(neck)
	projectPoint(POINT.SKULL, skull or neck + frameUp * (SKULL_LIFT * 2 * frameSpineLength))
	projectPoint(POINT.JAW, jaw)

	for point, bone in pairs(LIMB_POINT_BONES) do
		projectPoint(point, worldPos[bone])
	end

	local lFoot, rFoot = worldPos[BONE.L_FOOT], worldPos[BONE.R_FOOT]
	local lToe, rToe = worldPos[BONE.L_TOE], worldPos[BONE.R_TOE]
	projectPoint(POINT.L_FOOT, lFoot and (lToe and LerpVector(0.5, lFoot, lToe) or lFoot))
	projectPoint(POINT.R_FOOT, rFoot and (rToe and LerpVector(0.5, rFoot, rToe) or rFoot))

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
	return math_Clamp(value, 0, 1)
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
				local value = active and WEIGHT.ARTERIAL or WEIGHT.ARTERIAL_CONTROLLED
				regionArterial[region] = math.max(regionArterial[region], value)
			end
		end
	end

	for artery, region in pairs(ARTERY_REGIONS) do
		if orgNumber(org, artery) > 0 then
			regionArterial[region] = math.max(regionArterial[region], WEIGHT.ARTERIAL)
		end
	end

	for _, region in ipairs(REGIONS) do
		local venous = math_Clamp(regionBleed[region] / BLEED_RATE_CRITICAL, 0, 1)
		bleedLevel[region] = combine(venous, regionArterial[region])
		arterial[region] = regionArterial[region] > 0
	end
end

local function updateLimbState(org, limb)
	local value = orgNumber(org, limb.base)
	local boneSev = boneSeverity(value)
	local dislocation = org[limb.base .. "dislocation"] == true and WEIGHT.DISLOCATION or 0
	local isBroken = value >= 1
	local hasTourniquet = hg.HasTourniquetOnLimb and hg.HasTourniquetOnLimb(woundSource, limb.base) or false
	local upper, lower, hand = limb.upper, limb.lower, limb.hand

	severity[upper] = combine(boneSev, dislocation)
	severity[lower] = boneSev
	broken[upper], broken[lower] = isBroken, isBroken
	tourniquet[upper], tourniquet[lower] = hasTourniquet, hasTourniquet
	missing[upper] = org[upper .. "amputated"] == true
	missing[lower] = missing[upper] or org[lower .. "amputated"] == true
	if not hand then return end

	severity[hand] = boneSev * WEIGHT.HAND_BONE_SHARE
	broken[hand] = isBroken
	tourniquet[hand] = hasTourniquet
	missing[hand] = missing[lower] or org[hand .. "amputated"] == true
end

local function updateTorsoState(org)
	local headMissing = org.headamputated == true
	local jawDislocation = org.jawdislocation == true and WEIGHT.DISLOCATION or 0
	local skull, jaw = orgNumber(org, "skull"), orgNumber(org, "jaw")
	local ribs, pelvis = orgNumber(org, "chest"), orgNumber(org, "pelvis")
	local spine1, spine2, spine3 = orgNumber(org, "spine1"), orgNumber(org, "spine2"), orgNumber(org, "spine3")

	severity.skull = boneSeverity(skull)
	severity.jaw = combine(boneSeverity(jaw), jawDislocation)
	severity.neck = boneSeverity(spine3)
	severity.chest = boneSeverity(ribs)
	severity.spine2 = boneSeverity(spine2)
	severity.spine1 = boneSeverity(spine1)
	severity.pelvis = boneSeverity(pelvis)
	broken.skull, broken.jaw, broken.neck = skull >= 1, jaw >= 1, spine3 >= 1
	broken.chest, broken.pelvis = ribs >= 1, pelvis >= 1
	broken.spine2, broken.spine1 = spine2 >= 1, spine1 >= 1
	missing.skull, missing.jaw = headMissing, headMissing
end

local function readWearable(ent, field, netKey)
	if not IsValid(ent) then return end

	local state = ent[field]
	if istable(state) and next(state) then return state end
	state = ent.GetNetVar and ent:GetNetVar(netKey)
	if istable(state) and next(state) then return state end
end

local function updateBandages(ply, body)
	local owner = body
	local limbs = readWearable(body, "bandaged_limbs", "bandaged_limbs")
	if not limbs and body ~= ply then
		owner = ply
		limbs = readWearable(ply, "bandaged_limbs", "bandaged_limbs")
	end
	if not limbs then return end

	local soak = istable(owner.bandagesSoak) and owner.bandagesSoak or nil
	for bone in pairs(limbs) do
		local region = resolveWoundRegion(bone)
		if region then bandage[region] = math.max(bandage[region] or 0, soak and tonumber(soak[bone]) or 0) end
	end
end

local function clearMedicalState()
	for _, region in ipairs(REGIONS) do
		severity[region], bleedLevel[region] = 0, 0
		broken[region], arterial[region], missing[region], tourniquet[region] = false, false, false, false
		bandage[region] = nil
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
	updateBandages(ply, body)

	pulseHz = math_Clamp((tonumber(org.pulse) or DEFAULT_PULSE) / SECONDS_PER_MINUTE, 0.5, 3)
end

local function limbCanDislocate(base)
	if not currentOrg then return false end

	return currentOrg[base .. "dislocation"] ~= true and orgNumber(currentOrg, base) < 1
end

local function updateStress(ragdolled, snap)
	local dt = FrameTime()
	local blend = 1 - math_exp(-dt * STRESS.SMOOTH_RATE)
	for _, segment in ipairs(STRESS_SEGMENTS) do
		local child, parent = worldPos[segment.child], worldPos[segment.parent]
		local value = 0
		segment.speed = segment.speed or 0
		if ragdolled and not snap and child and parent and dt > 0 then
			local ox, oy, oz = child.x - parent.x, child.y - parent.y, child.z - parent.z
			if segment.valid then
				local dx, dy, dz = ox - segment.ox, oy - segment.oy, oz - segment.oz
				local speed = math_sqrt(dx * dx + dy * dy + dz * dz) / dt
				segment.speed = segment.speed + (speed - segment.speed) * blend
			end
			segment.ox, segment.oy, segment.oz, segment.valid = ox, oy, oz, true
			local pull = (segment.speed - STRESS.START_SPEED) / (STRESS.PULL_SPEED - STRESS.START_SPEED)
			value = limbCanDislocate(segment.base) and math_Clamp(pull, 0, 1) or 0
		else
			segment.valid, segment.speed = false, 0
		end
		for _, region in ipairs(segment.regions) do
			stress[region] = value
		end
	end
end

local function lerpColor(from, to, t)
	return from[1] + (to[1] - from[1]) * t, from[2] + (to[2] - from[2]) * t, from[3] + (to[3] - from[3]) * t
end

local OTRUB_CONSCIOUSNESS = 0.3
local GRAY_CONSCIOUSNESS_START = 0.85
local GRAY_SHOCK_START = 10
local GRAY_SHOCK_RANGE = 60
local GRAY_RATE = 3
local FADE_OUT_RATE = 3
local FADE_IN_RATE = 1.5
local displayGray = 0
local displayFade = 1

local function setDrawColor(red, green, blue, alpha)
	local luma = red * 0.299 + green * 0.587 + blue * 0.114
	surface.SetDrawColor(
		red + (luma - red) * displayGray,
		green + (luma - green) * displayGray,
		blue + (luma - blue) * displayGray,
		alpha * displayFade
	)
end

local function updateDisplayState(ply)
	if not ply:Alive() then
		displayGray, displayFade = 0, 1
		return
	end

	local org = ply.organism or ply.new_organism
	local replicated = ply.new_organism
	local otrub = org and org.otrub or replicated and replicated.otrub or false
	local grayTarget = 0
	if org then
		local consciousness = tonumber(org.consciousness) or 1
		local consciousnessSeverity = math_Clamp((GRAY_CONSCIOUSNESS_START - consciousness) / (GRAY_CONSCIOUSNESS_START - OTRUB_CONSCIOUSNESS), 0, 1)
		local shockSeverity = math_Clamp(((tonumber(org.shock) or 0) - GRAY_SHOCK_START) / GRAY_SHOCK_RANGE, 0, 1)
		grayTarget = math.max(consciousnessSeverity, shockSeverity)
	end
	if otrub then grayTarget = 1 end

	local dt = FrameTime()
	displayGray = displayGray + (grayTarget - displayGray) * (1 - math_exp(-dt * GRAY_RATE))
	local fadeTarget = otrub and 0 or 1
	local fadeRate = otrub and FADE_OUT_RATE or FADE_IN_RATE
	displayFade = displayFade + (fadeTarget - displayFade) * (1 - math_exp(-dt * fadeRate))
end

local function healthColor(region)
	if broken[region] then return 0, 0, 0, 255 end
	local value = math_Clamp(severity[region] or 0, 0, 1)
	for index = 2, #HEALTH_STOPS do
		local high = HEALTH_STOPS[index]
		if value <= high[1] then
			local low = HEALTH_STOPS[index - 1]
			local t = (value - low[1]) / (high[1] - low[1])

			return low[2] + (high[2] - low[2]) * t, low[3] + (high[3] - low[3]) * t,
				low[4] + (high[4] - low[4]) * t, low[5] + (high[5] - low[5]) * t
		end
	end
	local last = HEALTH_STOPS[#HEALTH_STOPS]

	return last[2], last[3], last[4], last[5]
end

local function ringColor(region)
	if tourniquet[region] then return COLOR.TOURNIQUET_RING[1], COLOR.TOURNIQUET_RING[2], COLOR.TOURNIQUET_RING[3] end

	local r, g, b = lerpColor(COLOR.RING_HEALTHY, COLOR.RING_BLEEDING, bleedLevel[region] or 0)
	if not arterial[region] then return r, g, b end

	local mul = 1 - ARTERIAL_PULSE_DEPTH * (0.5 + 0.5 * math_sin(CurTime() * pulseHz * TAU))

	return r * mul, g * mul, b * mul
end

local function queueShape(fromPoint, toPoint, region, radius, splitRegion, splitToward)
	if not smoothValid[fromPoint] or not smoothValid[toPoint] or missing[region] then return end

	circleCount = circleCount + 1
	local shape = circles[circleCount]
	if not shape then
		shape = {}
		circles[circleCount] = shape
	end
	shape.ax, shape.az = smoothY[fromPoint], smoothZ[fromPoint]
	shape.bx, shape.bz = smoothY[toPoint], smoothZ[toPoint]
	shape.depth = (smoothX[fromPoint] + smoothX[toPoint]) * 0.5
	shape.radius, shape.region = radius, region
	shape.splitRegion = splitToward and smoothValid[splitToward] and not missing[splitRegion] and splitRegion or nil
	if shape.splitRegion then shape.sx, shape.sz = smoothY[splitToward], smoothZ[splitToward] end
	circleOrder[circleCount] = circleCount
end

local function queueLimb(limb)
	local points, radii, bones = limb.points, limb.radii, limb.bones
	queueShape(points[1], points[2], limb.upper, limbRadius(bones[1], radii[1]))
	if missing[limb.upper] then return end

	queueShape(points[2], points[3], limb.lower, limbRadius(bones[2], radii[2]))
	if missing[limb.lower] then return end

	local endRadius = limbRadius(bones[3], radii[3], true)
	local foot = points[4]
	if foot then
		queueShape(foot, foot, limb.lower, endRadius)
		return
	end
	queueShape(points[3], points[3], limb.hand, endRadius)
end

local function queueBody()
	for i = 1, #circleOrder do
		circleOrder[i] = nil
	end
	circleCount = 0

	queueShape(POINT.PELVIS_L, POINT.PELVIS_R, "pelvis", pelvisRadius)
	queueShape(POINT.CHEST_L, POINT.CHEST_R, "chest", chestRadius)
	queueShape(POINT.NECK, POINT.NECK, "neck", RADIUS.NECK)
	queueShape(POINT.SPINE_TOP, POINT.SPINE_MID, "spine2", RADIUS.SPINE)
	queueShape(POINT.SPINE_MID, POINT.SPINE_LOW, "spine1", RADIUS.SPINE)
	queueShape(POINT.SKULL, POINT.SKULL, "skull", skullRadius, "jaw", POINT.NECK)
	for _, limb in ipairs(LIMBS) do
		queueLimb(limb)
	end
end

local function farthestFirst(a, b)
	return circles[a].depth < circles[b].depth
end

local function capsuleVertices(ax, ay, bx, by, r, out)
	local angle = math_atan2(by - ay, bx - ax)
	local startB = angle - math.pi * 0.5
	local startA = angle + math.pi * 0.5
	local offset = HALF_SEGMENTS + 1
	for i = 0, HALF_SEGMENTS do
		local step = i / HALF_SEGMENTS * math.pi
		local vertexB, vertexA = out[i + 1], out[offset + i + 1]
		vertexB.x, vertexB.y = bx + math_cos(startB + step) * r, by + math_sin(startB + step) * r
		vertexA.x, vertexA.y = ax + math_cos(startA + step) * r, ay + math_sin(startA + step) * r
	end
end

local function polyCapsule(ax, ay, bx, by, r)
	capsuleVertices(ax, ay, bx, by, r, capsulePoly)
	surface.DrawPoly(capsulePoly)
end

local ringInner = {}
for i = 1, (HALF_SEGMENTS + 1) * 2 do
	ringInner[i] = {x = 0, y = 0}
end
local ringQuad = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}

local function drawLine(ax, ay, bx, by, width)
	local dx, dy = bx - ax, by - ay
	local length = math_sqrt(dx * dx + dy * dy)
	if length <= 0 then return end

	local px, py = -dy / length * width * 0.5, dx / length * width * 0.5
	ringQuad[1].x, ringQuad[1].y = ax - px, ay - py
	ringQuad[2].x, ringQuad[2].y = bx - px, by - py
	ringQuad[3].x, ringQuad[3].y = bx + px, by + py
	ringQuad[4].x, ringQuad[4].y = ax + px, ay + py
	surface.DrawPoly(ringQuad)
end

local function polyCapsuleRing(ax, ay, bx, by, outer, inner)
	capsuleVertices(ax, ay, bx, by, outer, capsulePoly)
	capsuleVertices(ax, ay, bx, by, inner, ringInner)
	local count = #capsulePoly
	for i = 1, count do
		local j = i % count + 1
		local o1, o2, i1, i2 = capsulePoly[i], capsulePoly[j], ringInner[i], ringInner[j]
		ringQuad[1].x, ringQuad[1].y = o1.x, o1.y
		ringQuad[2].x, ringQuad[2].y = o2.x, o2.y
		ringQuad[3].x, ringQuad[3].y = i2.x, i2.y
		ringQuad[4].x, ringQuad[4].y = i1.x, i1.y
		surface.DrawPoly(ringQuad)
	end
end

local function polyHalfCircle(x, y, r, startAngle)
	for i = 0, HALF_SEGMENTS do
		local angle = startAngle + i / HALF_SEGMENTS * math.pi
		local vertex = halfPoly[i + 1]
		vertex.x, vertex.y = x + math_cos(angle) * r, y + math_sin(angle) * r
	end
	surface.DrawPoly(halfPoly)
end

local function polyHalfRing(x, y, outer, inner, startAngle)
	for i = 0, HALF_SEGMENTS - 1 do
		local angleA = startAngle + i / HALF_SEGMENTS * math.pi
		local angleB = startAngle + (i + 1) / HALF_SEGMENTS * math.pi
		local ax, ay = math_cos(angleA), math_sin(angleA)
		local bx, by = math_cos(angleB), math_sin(angleB)
		ringQuad[1].x, ringQuad[1].y = x + ax * outer, y + ay * outer
		ringQuad[2].x, ringQuad[2].y = x + bx * outer, y + by * outer
		ringQuad[3].x, ringQuad[3].y = x + bx * inner, y + by * inner
		ringQuad[4].x, ringQuad[4].y = x + ax * inner, y + ay * inner
		surface.DrawPoly(ringQuad)
	end
end

local strapPoly = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}
local outlineWidth = SHAPE.OUTLINE_WIDTH

local function drawStrap(ax, ay, bx, by, r, t, red, green, blue, horizontal)
	local dx, dy = bx - ax, by - ay
	local length = math_sqrt(dx * dx + dy * dy)
	local ux, uy = 0, 1
	if length > 0.001 and not horizontal then ux, uy = dx / length, dy / length end
	local cx, cy = ax + dx * t, ay + dy * t
	local half = math.min(r * SHAPE.STRAP_THICKNESS, math.max(length * SHAPE.STRAP_MAX_SEGMENT_SHARE, r * 0.5)) * 0.5
	local px, py = -uy * (r + outlineWidth), ux * (r + outlineWidth)
	local fx, fy = ux * half, uy * half

	strapPoly[1].x, strapPoly[1].y = cx - fx - px, cy - fy - py
	strapPoly[2].x, strapPoly[2].y = cx + fx - px, cy + fy - py
	strapPoly[3].x, strapPoly[3].y = cx + fx + px, cy + fy + py
	strapPoly[4].x, strapPoly[4].y = cx - fx + px, cy - fy + py
	setDrawColor(red, green, blue, FILL_ALPHA)
	surface.DrawPoly(strapPoly)
	setDrawColor(COLOR.OUTLINE[1], COLOR.OUTLINE[2], COLOR.OUTLINE[3], OUTLINE_ALPHA)
	drawLine(strapPoly[1].x, strapPoly[1].y, strapPoly[4].x, strapPoly[4].y, outlineWidth)
	drawLine(strapPoly[2].x, strapPoly[2].y, strapPoly[3].x, strapPoly[3].y, outlineWidth)
end

local centerX, centerY, pixelScale, targetZ = 0, 0, 1, 0

local function drawSplit(shape, x, y, outer, inner)
	local towardX = centerX + shape.sx * pixelScale - x
	local towardY = centerY - (shape.sz - targetZ) * pixelScale - y
	local angle = math_atan2(towardY, towardX)
	if (severity[shape.region] or 0) > 0 then
		local red, green, blue, alpha = healthColor(shape.region)
		setDrawColor(red, green, blue, alpha)
		polyHalfCircle(x, y, inner, angle + math.pi * 0.5)
	end
	if (severity[shape.splitRegion] or 0) > 0 then
		local red, green, blue, alpha = healthColor(shape.splitRegion)
		setDrawColor(red, green, blue, alpha)
		polyHalfCircle(x, y, inner, angle - math.pi * 0.5)
	end

	local red, green, blue = ringColor(shape.region)
	setDrawColor(red, green, blue, OUTLINE_ALPHA)
	polyCapsuleRing(x, y, x, y, outer, inner)
	red, green, blue = ringColor(shape.splitRegion)
	setDrawColor(red, green, blue, OUTLINE_ALPHA)
	polyHalfRing(x, y, outer, inner, angle - math.pi * 0.5)
	local lineX, lineY = math_cos(angle + math.pi * 0.5) * inner, math_sin(angle + math.pi * 0.5) * inner
	drawLine(x - lineX, y - lineY, x + lineX, y + lineY, outlineWidth)
end

local function drawShapeExtras(shape, ax, ay, bx, by, r)
	local region = shape.region
	local soak = bandage[region]
	if soak then
		local red, green, blue = lerpColor(COLOR.BANDAGE_CLEAN, COLOR.BANDAGE_SOAKED, math_Clamp(soak, 0, 1))
		drawStrap(ax, ay, bx, by, r, 0.5, red, green, blue)
	end

	local limbTop = region == "larmup" or region == "rarmup" or region == "llegup" or region == "rlegup"
	if limbTop and tourniquet[region] then
		local color = COLOR.TOURNIQUET_STRAP
		drawStrap(ax, ay, bx, by, r, SHAPE.TOURNIQUET_STRAP_T, color[1], color[2], color[3])
	end
end

local function drawShape(shape)
	local ax = centerX + shape.ax * pixelScale
	local ay = centerY - (shape.az - targetZ) * pixelScale
	local bx = centerX + shape.bx * pixelScale
	local by = centerY - (shape.bz - targetZ) * pixelScale
	local depthScale = math_Clamp(1 + shape.depth * DEPTH_SCALE, DEPTH_SCALE_MIN, DEPTH_SCALE_MAX)
	local r = shape.radius * DISPLAY_SPINE * pixelScale * depthScale
	local shake = stress[shape.region] or 0
	if shake > STRESS.VISIBLE then
		local amount = shake * shake * STRESS.SHAKE_PIXELS
		local jx, jy = math.Rand(-amount, amount), math.Rand(-amount, amount)
		ax, ay, bx, by = ax + jx, ay + jy, bx + jx, by + jy
	end

	local inner = math.max(r - outlineWidth, 1)
	if shape.splitRegion then
		drawSplit(shape, ax, ay, r, inner)
	else
		if (severity[shape.region] or 0) > 0 then
			local red, green, blue, alpha = healthColor(shape.region)
			setDrawColor(red, green, blue, alpha)
			polyCapsule(ax, ay, bx, by, inner)
		end
		local red, green, blue = ringColor(shape.region)
		setDrawColor(red, green, blue, OUTLINE_ALPHA)
		polyCapsuleRing(ax, ay, bx, by, r, inner)
	end

	drawShapeExtras(shape, ax, ay, bx, by, r)
end

local function drawCircles()
	table.sort(circleOrder, farthestFirst)
	for i = 1, circleCount do
		drawShape(circles[circleOrder[i]])
	end
end

local function drawWounds()
	local sizeScale = ScrH() / REFERENCE_SCREEN_HEIGHT
	for i = 1, emitterCount do
		local emitter = emitters[i]
		if emitter.valid then
			local color = emitter.arterial and WOUND_MARK.arterial or WOUND_MARK.venous
			local radius = math.min(WOUND_MARK.sizeBase + emitter.size * WOUND_MARK.sizePerSize, WOUND_MARK.sizeMax) * sizeScale
			local x = centerX + emitter.y * pixelScale
			local y = centerY - (emitter.z - targetZ) * pixelScale
			setDrawColor(COLOR.OUTLINE[1], COLOR.OUTLINE[2], COLOR.OUTLINE[3], OUTLINE_ALPHA)
			polyCapsule(x, y, x, y, radius + outlineWidth)
			setDrawColor(color[1], color[2], color[3], 255)
			polyCapsule(x, y, x, y, radius)
		end
	end
end

local function armorWear(ply, body, slot)
	local armors = body:GetNetVar("Armor") or ply:GetNetVar("Armor")
	local armor = istable(armors) and (isstring(slot) and armors[slot] or nil)
	if not isstring(armor) then return 0 end

	local wear = body ~= ply and body:GetNWFloat("ArmorWear" .. armor, -1) or -1
	if wear < 0 then wear = ply:GetNWFloat("ArmorWear" .. armor, 0) end

	return math_Clamp(wear, 0, 1)
end

local function collectArmorBoxes(ply, body)
	armorBoxCount = 0
	if not IsValid(body) or not hg.organism.GetHitBoxOrgans or not hg.organism.ShootMatrix then return end

	local organs = hg.organism.GetHitBoxOrgans(body:GetModel(), body)
	local boxes = hg.organism.ShootMatrix(body, organs)
	if not boxes then return end

	for _, box in ipairs(boxes) do
		local organ = box[6] and organs[box[6]] and organs[box[6]][box[7]]
		if organ and organ[7] then
			armorBoxCount = armorBoxCount + 1
			local entry = armorBoxes[armorBoxCount]
			if not entry then
				entry = {}
				armorBoxes[armorBoxCount] = entry
			end
			entry.bone, entry.pos, entry.ang, entry.size = box[6], organ[3], organ[4], organ[5]
			entry.wear = armorWear(ply, body, organ[7])
		end
	end
end

local function armorColor(wear)
	if wear <= 0.5 then return lerpColor(COLOR.ARMOR_GOOD, COLOR.ARMOR_DAMAGED, wear * 2) end

	return lerpColor(COLOR.ARMOR_DAMAGED, COLOR.ARMOR_RUINED, (wear - 0.5) * 2)
end

local ARMOR_SIGNS = {
	{-1, -1, -1}, {1, -1, -1}, {1, 1, -1}, {-1, 1, -1},
	{-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1},
}
local armorPoints, armorHull = {}, {}
for i = 1, #ARMOR_SIGNS do
	armorPoints[i] = {x = 0, y = 0}
end

local function cross2(o, a, b)
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
end

local function buildHull()
	table.sort(armorPoints, function(a, b)
		if a.x ~= b.x then return a.x < b.x end
		return a.y < b.y
	end)

	local n = 0
	for i = 1, #armorPoints do
		while n >= 2 and cross2(armorHull[n - 1], armorHull[n], armorPoints[i]) <= 0 do
			n = n - 1
		end
		n = n + 1
		armorHull[n] = armorPoints[i]
	end
	local lower = n + 1
	for i = #armorPoints - 1, 1, -1 do
		while n >= lower and cross2(armorHull[n - 1], armorHull[n], armorPoints[i]) <= 0 do
			n = n - 1
		end
		n = n + 1
		armorHull[n] = armorPoints[i]
	end

	return n - 1
end

local function drawArmor()
	local body = captureBody
	if armorBoxCount == 0 or not IsValid(body) or not boneCache then return end

	for index = 1, armorBoxCount do
		local box = armorBoxes[index]
		local id = lookupNamedBone(body, boneCache, box.bone)
		local matrix = id and body:GetBoneMatrix(id)
		if matrix then
			local pos, ang = LocalToWorld(box.pos, box.ang, matrix:GetTranslation(), matrix:GetAngles())
			local size = box.size
			for corner = 1, #ARMOR_SIGNS do
				local sign = ARMOR_SIGNS[corner]
				local world = LocalToWorld(Vector(size.x * sign[1], size.y * sign[2], size.z * sign[3]), angle_zero, pos, ang)
				local _, py, pz = projectRaw(world)
				local point = armorPoints[corner]
				point.x, point.y = centerX + py * pixelScale, centerY - (pz - targetZ) * pixelScale
			end

			local count = buildHull()
			if count >= 3 then
				local red, green, blue = armorColor(box.wear or 0)
				setDrawColor(red, green, blue, COLOR.ARMOR_FILL_ALPHA)
				local poly = {}
				for i = count, 1, -1 do
					poly[#poly + 1] = {x = armorHull[i].x, y = armorHull[i].y}
				end
				surface.DrawPoly(poly)
				setDrawColor(red, green, blue, COLOR.ARMOR_LINE_ALPHA)
				for i = 1, count do
					local a, b = armorHull[i], armorHull[i % count + 1]
					drawLine(a.x, a.y, b.x, b.y, outlineWidth)
				end
			end
		end
	end
end

local function renderFigure()
	local size = ScrH() * PANEL_SIZE_FRACTION
	pixelScale = size / (FIGURE_EXTENT * DISPLAY_SPINE)
	outlineWidth = math.max(SHAPE.OUTLINE_WIDTH * ScrH() / REFERENCE_SCREEN_HEIGHT, 1)
	centerX = ScrH() * PANEL_MARGIN_FRACTION + size * 0.5
	centerY = ScrH() * 0.5
	targetZ = TARGET_HEIGHT * DISPLAY_SPINE

	draw.NoTexture()
	queueBody()
	drawCircles()
	drawArmor()
	drawWounds()
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
		collectArmorBoxes(ply, body)
		nextMedicalUpdate = now + MEDICAL_UPDATE_INTERVAL
	end
	updateStress(body ~= ply and body:IsRagdoll(), snap)

	updateDisplayState(ply)
	if displayFade < 0.01 then return end

	renderFigure()
end)
