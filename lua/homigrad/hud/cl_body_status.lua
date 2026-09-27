local enabled = CreateClientConVar("hg_bodystatus_enabled", "1", true, false, "Show the live body status HUD")

local IsValid = IsValid
local CurTime = CurTime
local FrameTime = FrameTime
local ScrH = ScrH
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2
local math_abs = math.abs
local math_exp = math.exp
local math_ceil = math.ceil
local math_Clamp = math.Clamp
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawPoly = surface.DrawPoly
local surface_DrawLine = surface.DrawLine

local TAU = math.pi * 2

local PANEL_HEIGHT_FRACTION = 0.3
local PANEL_MARGIN_FRACTION = 0.025
local FIGURE_EXTENT = 3.8
local DEPTH_LIFT = 0.35
local POSE_SMOOTH_RATE = 18
local ANGLE_SMOOTH_RATE = 10
local SNAP_AFTER_HIDDEN = 0.5
local MIN_SPINE_LENGTH = 4
local MAX_SPINE_LENGTH = 80
local MIN_RIGHT_LENGTH = 1
local FLAT_TILT_THRESHOLD = 0.3
local MEDICAL_UPDATE_INTERVAL = 0.1
local DEAD_ALPHA_MUL = 0.55
local FILL_ALPHA = 215
local OUTLINE_ALPHA = 190
local OUTLINE_WIDTH = 1.5
local BEAD_SPACING = 1.3
local MAX_BEADS = 8
local SKULL_FALLBACK_OFFSET = 0.12
local JAW_FACE_BLEND = 0.6
local JAW_DROP = 0.08

local FRACTURE_SEVERITY = 0.82
local BONE_DAMAGE_WEIGHT = 0.7
local SPINE_DAMAGE_WEIGHT = 0.75
local DISLOCATION_SEVERITY = 0.68
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

local COLOR_STOPS = {
	{0, 196, 208, 200},
	{0.3, 214, 196, 118},
	{0.55, 224, 136, 62},
	{0.8, 196, 48, 40},
	{1, 96, 18, 24},
}
local OUTLINE_COLOR = {18, 18, 20}
local STUMP_COLOR = {70, 12, 16}
local CRACK_COLOR = {25, 8, 8}

local R_PELVIS = 0.2
local R_CHEST = 0.25
local R_NECK = 0.1
local R_SKULL = 0.2
local R_JAW = 0.09
local R_UPPER_ARM = 0.08
local R_LOWER_ARM = 0.07
local R_HAND = 0.075
local R_THIGH = 0.095
local R_CALF = 0.08
local R_FOOT = 0.075
local STUMP_SCALE = 0.8

local B_PELVIS, B_SPINE2, B_SPINE4, B_NECK, B_HEAD, B_JAW = 1, 2, 3, 4, 5, 6
local B_L_UPPERARM, B_L_FOREARM, B_L_HAND = 7, 8, 9
local B_R_UPPERARM, B_R_FOREARM, B_R_HAND = 10, 11, 12
local B_L_THIGH, B_L_CALF, B_L_FOOT, B_L_TOE = 13, 14, 15, 16
local B_R_THIGH, B_R_CALF, B_R_FOOT, B_R_TOE = 17, 18, 19, 20

local BONE_CANDIDATES = {
	[B_PELVIS] = {"ValveBiped.Bip01_Pelvis", "Bip01 Pelvis", "bip_pelvis", "mixamorig:Hips"},
	[B_SPINE2] = {"ValveBiped.Bip01_Spine2", "Bip01 Spine2", "bip_spine_2", "mixamorig:Spine1"},
	[B_SPINE4] = {"ValveBiped.Bip01_Spine4", "Bip01 Spine4", "bip_spine_3", "mixamorig:Spine2"},
	[B_NECK] = {"ValveBiped.Bip01_Neck1", "Bip01 Neck", "Bip01 Neck1", "bip_neck", "mixamorig:Neck"},
	[B_HEAD] = {"ValveBiped.Bip01_Head1", "Bip01 Head", "Bip01 Head1", "bip_head", "mixamorig:Head"},
	[B_JAW] = {"ValveBiped.Bip01_Jaw", "ValveBiped.jaw", "Bip01 Jaw", "jaw", "Jaw"},
	[B_L_UPPERARM] = {"ValveBiped.Bip01_L_UpperArm", "Bip01 L UpperArm", "bip_upperArm_L", "mixamorig:LeftArm"},
	[B_L_FOREARM] = {"ValveBiped.Bip01_L_Forearm", "Bip01 L Forearm", "bip_lowerArm_L", "mixamorig:LeftForeArm"},
	[B_L_HAND] = {"ValveBiped.Bip01_L_Hand", "Bip01 L Hand", "bip_hand_L", "mixamorig:LeftHand"},
	[B_R_UPPERARM] = {"ValveBiped.Bip01_R_UpperArm", "Bip01 R UpperArm", "bip_upperArm_R", "mixamorig:RightArm"},
	[B_R_FOREARM] = {"ValveBiped.Bip01_R_Forearm", "Bip01 R Forearm", "bip_lowerArm_R", "mixamorig:RightForeArm"},
	[B_R_HAND] = {"ValveBiped.Bip01_R_Hand", "Bip01 R Hand", "bip_hand_R", "mixamorig:RightHand"},
	[B_L_THIGH] = {"ValveBiped.Bip01_L_Thigh", "Bip01 L Thigh", "bip_hip_L", "mixamorig:LeftUpLeg"},
	[B_L_CALF] = {"ValveBiped.Bip01_L_Calf", "Bip01 L Calf", "bip_knee_L", "mixamorig:LeftLeg"},
	[B_L_FOOT] = {"ValveBiped.Bip01_L_Foot", "Bip01 L Foot", "bip_foot_L", "mixamorig:LeftFoot"},
	[B_L_TOE] = {"ValveBiped.Bip01_L_Toe0", "Bip01 L Toe0", "bip_toe_L", "mixamorig:LeftToeBase"},
	[B_R_THIGH] = {"ValveBiped.Bip01_R_Thigh", "Bip01 R Thigh", "bip_hip_R", "mixamorig:RightUpLeg"},
	[B_R_CALF] = {"ValveBiped.Bip01_R_Calf", "Bip01 R Calf", "bip_knee_R", "mixamorig:RightLeg"},
	[B_R_FOOT] = {"ValveBiped.Bip01_R_Foot", "Bip01 R Foot", "bip_foot_R", "mixamorig:RightFoot"},
	[B_R_TOE] = {"ValveBiped.Bip01_R_Toe0", "Bip01 R Toe0", "bip_toe_R", "mixamorig:RightToeBase"},
}
local BONE_COUNT = #BONE_CANDIDATES

local P_PELVIS, P_CHEST, P_NECK, P_SKULL, P_JAW = 1, 2, 3, 4, 5
local P_L_SHOULDER, P_L_ELBOW, P_L_WRIST = 6, 7, 8
local P_R_SHOULDER, P_R_ELBOW, P_R_WRIST = 9, 10, 11
local P_L_HIP, P_L_KNEE, P_L_ANKLE, P_L_FOOT = 12, 13, 14, 15
local P_R_HIP, P_R_KNEE, P_R_ANKLE, P_R_FOOT = 16, 17, 18, 19
local POINT_COUNT = 19

local LIMB_POINT_BONES = {
	[P_L_SHOULDER] = B_L_UPPERARM,
	[P_L_ELBOW] = B_L_FOREARM,
	[P_L_WRIST] = B_L_HAND,
	[P_R_SHOULDER] = B_R_UPPERARM,
	[P_R_ELBOW] = B_R_FOREARM,
	[P_R_WRIST] = B_R_HAND,
	[P_L_HIP] = B_L_THIGH,
	[P_L_KNEE] = B_L_CALF,
	[P_L_ANKLE] = B_L_FOOT,
	[P_R_HIP] = B_R_THIGH,
	[P_R_KNEE] = B_R_CALF,
	[P_R_ANKLE] = B_R_FOOT,
}

local LIMBS = {
	{
		base = "lleg", upper = "llegup", lower = "lleg",
		points = {P_L_HIP, P_L_KNEE, P_L_ANKLE, P_L_FOOT},
		radii = {R_THIGH, R_CALF, R_FOOT},
	},
	{
		base = "rleg", upper = "rlegup", lower = "rleg",
		points = {P_R_HIP, P_R_KNEE, P_R_ANKLE, P_R_FOOT},
		radii = {R_THIGH, R_CALF, R_FOOT},
	},
	{
		base = "larm", upper = "larmup", lower = "larm", hand = "lhand",
		points = {P_L_SHOULDER, P_L_ELBOW, P_L_WRIST},
		radii = {R_UPPER_ARM, R_LOWER_ARM, R_HAND},
	},
	{
		base = "rarm", upper = "rarmup", lower = "rarm", hand = "rhand",
		points = {P_R_SHOULDER, P_R_ELBOW, P_R_WRIST},
		radii = {R_UPPER_ARM, R_LOWER_ARM, R_HAND},
	},
}
local LEG_LIMBS = {LIMBS[1], LIMBS[2]}
local ARM_LIMBS = {LIMBS[3], LIMBS[4]}

local REGIONS = {
	"skull", "jaw", "neck", "chest", "pelvis",
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

local ARTERY_REGIONS = {
	arteria = "neck",
	aorta = "chest",
	larmartery = "larm",
	rarmartery = "rarm",
	llegartery = "lleg",
	rlegartery = "rleg",
}

local worldPos = {}
local figX, figY = {}, {}
local pointValid = {}
local smoothX, smoothY = {}, {}
local smoothValid = {}
local smoothAngle = 0
local lastBody
local lastDrawTime = 0

local sevA, sevB = {}, {}
local fractured, arterial, missing = {}, {}, {}
local regionBleed, regionArterial = {}, {}
local nextMedicalUpdate = 0
local pulseHz = DEFAULT_PULSE / SECONDS_PER_MINUTE

local CIRCLE_SEGMENTS = 20
local HALF_SEGMENTS = CIRCLE_SEGMENTS / 2
local circleCos, circleSin = {}, {}
local circlePoly, halfPoly = {}, {}
for i = 1, CIRCLE_SEGMENTS do
	local angle = (i - 1) / CIRCLE_SEGMENTS * TAU
	circleCos[i] = math_cos(angle)
	circleSin[i] = math_sin(angle)
	circlePoly[i] = {x = 0, y = 0}
end
for i = 1, HALF_SEGMENTS + 1 do
	halfPoly[i] = {x = 0, y = 0}
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

local function readBonePositions(ent, cache)
	for index = 1, BONE_COUNT do
		local id = cache[index]
		local matrix = id >= 0 and ent:GetBoneMatrix(id)
		worldPos[index] = matrix and matrix:GetTranslation() or false
	end
end

local frameRoot, frameRight, frameUp, frameForward, frameSpineLength

local function buildFrame()
	local pelvis, neck = worldPos[B_PELVIS], worldPos[B_NECK] or worldPos[B_SPINE4]
	if not pelvis or not neck then return false end

	local up = neck - pelvis
	local spineLength = up:Length()
	if spineLength < MIN_SPINE_LENGTH or spineLength > MAX_SPINE_LENGTH then return false end
	up:Div(spineLength)

	local right = Vector(0, 0, 0)
	local lThigh, rThigh = worldPos[B_L_THIGH], worldPos[B_R_THIGH]
	local lArm, rArm = worldPos[B_L_UPPERARM], worldPos[B_R_UPPERARM]
	if lThigh and rThigh then right:Add(rThigh - lThigh) end
	if lArm and rArm then right:Add(rArm - lArm) end
	right:Sub(up * right:Dot(up))
	local rightLength = right:Length()
	if rightLength < MIN_RIGHT_LENGTH then return false end
	right:Div(rightLength)

	frameRoot, frameRight, frameUp, frameSpineLength = pelvis, right, up, spineLength
	frameForward = up:Cross(right)

	return true
end

local function projectPoint(index, pos)
	if not pos then
		pointValid[index] = false
		return
	end

	local dx, dy, dz = pos.x - frameRoot.x, pos.y - frameRoot.y, pos.z - frameRoot.z
	local x = (dx * frameRight.x + dy * frameRight.y + dz * frameRight.z) / frameSpineLength
	local y = (dx * frameUp.x + dy * frameUp.y + dz * frameUp.z) / frameSpineLength
	local z = (dx * frameForward.x + dy * frameForward.y + dz * frameForward.z) / frameSpineLength
	figX[index] = x
	figY[index] = y + z * DEPTH_LIFT
	pointValid[index] = true
end

local function getHeadPoints(ent, cache)
	local head, neck = worldPos[B_HEAD], worldPos[B_NECK] or worldPos[B_SPINE4]
	if not head then return end

	local headUp = head - neck
	local headUpLength = headUp:Length()
	if headUpLength > 0 then headUp:Div(headUpLength) end

	local eyesPos
	if cache.eyes > 0 then
		local attachment = ent:GetAttachment(cache.eyes)
		eyesPos = attachment and attachment.Pos
	end

	local skull, jaw
	if eyesPos then
		skull = LerpVector(0.5, head, eyesPos)
		jaw = LerpVector(JAW_FACE_BLEND, head, eyesPos) - headUp * (JAW_DROP * frameSpineLength)
	else
		skull = head + headUp * (SKULL_FALLBACK_OFFSET * frameSpineLength)
		jaw = LerpVector(0.5, head, neck)
	end

	return skull, worldPos[B_JAW] or jaw
end

local function computeTiltTarget()
	local zx, zy = frameRight.z, frameUp.z
	local magnitude = math_sqrt(zx * zx + zy * zy)
	if magnitude >= FLAT_TILT_THRESHOLD then return math.deg(math_atan2(zx, zy)) end

	local sign = smoothAngle >= 0 and 1 or -1

	return sign * math.max(math_abs(smoothAngle), 90)
end

local function updatePose(ent)
	local cache = getBoneCache(ent)
	readBonePositions(ent, cache)
	if not buildFrame() then return false end

	local neck = worldPos[B_NECK] or worldPos[B_SPINE4]
	projectPoint(P_PELVIS, frameRoot)
	projectPoint(P_CHEST, worldPos[B_SPINE2] or worldPos[B_SPINE4] or LerpVector(0.5, frameRoot, neck))
	projectPoint(P_NECK, neck)

	local skull, jaw = getHeadPoints(ent, cache)
	projectPoint(P_SKULL, skull or neck + frameUp * (frameSpineLength * SKULL_FALLBACK_OFFSET * 2))
	projectPoint(P_JAW, jaw)

	for point, bone in pairs(LIMB_POINT_BONES) do
		projectPoint(point, worldPos[bone])
	end

	local lFoot, rFoot = worldPos[B_L_FOOT], worldPos[B_R_FOOT]
	projectPoint(P_L_FOOT, lFoot and (worldPos[B_L_TOE] and LerpVector(0.5, lFoot, worldPos[B_L_TOE]) or lFoot))
	projectPoint(P_R_FOOT, rFoot and (worldPos[B_R_TOE] and LerpVector(0.5, rFoot, worldPos[B_R_TOE]) or rFoot))

	return true
end

local function smoothPose(snap)
	local dt = FrameTime()
	local targetAngle = computeTiltTarget()
	if snap then
		smoothAngle = targetAngle
	else
		local angleBlend = 1 - math_exp(-dt * ANGLE_SMOOTH_RATE)
		smoothAngle = smoothAngle + math.AngleDifference(targetAngle, smoothAngle) * angleBlend
		smoothAngle = math.NormalizeAngle(smoothAngle)
	end

	local radians = math.rad(smoothAngle)
	local cosA, sinA = math_cos(radians), math_sin(radians)
	local blend = 1 - math_exp(-dt * POSE_SMOOTH_RATE)
	for index = 1, POINT_COUNT do
		if pointValid[index] then
			local x, y = figX[index], figY[index]
			local rx, ry = x * cosA - y * sinA, x * sinA + y * cosA
			if snap or not smoothValid[index] then
				smoothX[index], smoothY[index] = rx, ry
			else
				smoothX[index] = smoothX[index] + (rx - smoothX[index]) * blend
				smoothY[index] = smoothY[index] + (ry - smoothY[index]) * blend
			end
		end
		smoothValid[index] = pointValid[index]
	end
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

local function resolveWoundRegion(bone)
	if not isstring(bone) then return end

	return TORSO_BONE_REGIONS[bone] or (hg.amputeetable and hg.amputeetable[bone])
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
				local severity = active and ARTERIAL_SEVERITY or ARTERIAL_CONTROLLED_SEVERITY
				regionArterial[region] = math.max(regionArterial[region], severity)
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
	local value = orgNumber(org, limb.base)
	local boneSev = boneSeverity(value)
	local dislocation = org[limb.base .. "dislocation"] == true and DISLOCATION_SEVERITY or 0
	local isFractured = value >= 1
	local upper, lower, hand = limb.upper, limb.lower, limb.hand

	sevA[upper] = combine(combine(boneSev, dislocation), bleedSeverity(upper))
	sevA[lower] = combine(combine(boneSev, regionArterial[lower]), bleedSeverity(lower))
	fractured[upper], fractured[lower] = isFractured, isFractured
	arterial[upper], arterial[lower] = regionArterial[upper] > 0, regionArterial[lower] > 0
	missing[upper] = org[upper .. "amputated"] == true
	missing[lower] = missing[upper] or org[lower .. "amputated"] == true
	if not hand then return end

	sevA[hand] = combine(boneSev * HAND_BONE_SHARE, bleedSeverity(hand))
	fractured[hand], arterial[hand] = false, regionArterial[hand] > 0
	missing[hand] = missing[lower] or org[hand .. "amputated"] == true
end

local function updateTorsoState(org)
	local skull, jaw = orgNumber(org, "skull"), orgNumber(org, "jaw")
	local spine1, spine2, spine3 = orgNumber(org, "spine1"), orgNumber(org, "spine2"), orgNumber(org, "spine3")
	local ribs, pelvis = orgNumber(org, "chest"), orgNumber(org, "pelvis")
	local headMissing = org.headamputated == true

	sevA.skull = combine(boneSeverity(skull), bleedSeverity("skull"))
	sevB.skull = math_Clamp(orgNumber(org, "brain") * BRAIN_WEIGHT, 0, 1)
	fractured.skull, missing.skull = skull >= 1, headMissing

	sevA.jaw = combine(boneSeverity(jaw), org.jawdislocation == true and DISLOCATION_SEVERITY or 0)
	fractured.jaw, missing.jaw = jaw >= 1, headMissing

	sevA.neck = spineSeverity(spine3)
	sevB.neck = combine(combine(regionArterial.neck, organSeverity(org, "trachea")), bleedSeverity("neck"))
	fractured.neck, arterial.neck = spine3 >= 1, regionArterial.neck > 0

	local thorax = math_Clamp((orgNumber(org, "pneumothorax") + orgNumber(org, "hemothorax")) * THORAX_WEIGHT, 0, 1)
	local lungs = combine(organSeverity(org, "lungsL"), organSeverity(org, "lungsR"))
	sevA.chest = combine(spineSeverity(spine2), boneSeverity(ribs))
	local chestBleeding = combine(regionArterial.chest, bleedSeverity("chest"))
	sevB.chest = combine(combine(organSeverity(org, "heart"), lungs), combine(thorax, chestBleeding))
	fractured.chest, arterial.chest = spine2 >= 1 or ribs >= 1, regionArterial.chest > 0

	local digestive = combine(organSeverity(org, "stomach"), organSeverity(org, "intestines"))
	local abdomen = combine(organSeverity(org, "liver"), digestive)
	sevA.pelvis = combine(spineSeverity(spine1), boneSeverity(pelvis))
	sevB.pelvis = combine(abdomen, bleedSeverity("pelvis"))
	fractured.pelvis = spine1 >= 1 or pelvis >= 1
end

local function clearMedicalState()
	for _, region in ipairs(REGIONS) do
		sevA[region], sevB[region] = 0, nil
		fractured[region], arterial[region], missing[region] = false, false, false
	end
end

local function updateMedicalState(ply, body)
	clearMedicalState()

	local org = ply.new_organism or ply.organism
	if not istable(org) and IsValid(body) and body ~= ply then org = body.new_organism or body.organism end
	if not istable(org) then return end

	local source = ply:Alive() and ply or body
	local wounds = IsValid(source) and source.wounds or ply.wounds
	local arterialWounds = IsValid(source) and source.arterialwounds or ply.arterialwounds
	collectWounds(org, wounds, arterialWounds)
	updateTorsoState(org)
	for _, limb in ipairs(LIMBS) do
		updateLimbState(org, limb)
	end

	local pulse = tonumber(org.pulse) or DEFAULT_PULSE
	pulseHz = math_Clamp(pulse / SECONDS_PER_MINUTE, 0.5, 3)
end

local function severityColor(severity)
	severity = math_Clamp(severity or 0, 0, 1)
	for index = 2, #COLOR_STOPS do
		local high = COLOR_STOPS[index]
		if severity <= high[1] then
			local low = COLOR_STOPS[index - 1]
			local t = (severity - low[1]) / (high[1] - low[1])

			return low[2] + (high[2] - low[2]) * t, low[3] + (high[3] - low[3]) * t, low[4] + (high[4] - low[4]) * t
		end
	end
	local last = COLOR_STOPS[#COLOR_STOPS]

	return last[2], last[3], last[4]
end

local drawCenterX, drawCenterY, drawScale, drawAlpha = 0, 0, 1, 1

local function toScreen(index)
	return drawCenterX + smoothX[index] * drawScale, drawCenterY - smoothY[index] * drawScale
end

local function polyCircle(x, y, r)
	for i = 1, CIRCLE_SEGMENTS do
		local vertex = circlePoly[i]
		vertex.x = x + circleCos[i] * r
		vertex.y = y + circleSin[i] * r
	end
	surface_DrawPoly(circlePoly)
end

local function polyHalfCircle(x, y, r, startAngle)
	for i = 1, HALF_SEGMENTS + 1 do
		local angle = startAngle + (i - 1) / HALF_SEGMENTS * math.pi
		local vertex = halfPoly[i]
		vertex.x = x + math_cos(angle) * r
		vertex.y = y + math_sin(angle) * r
	end
	surface_DrawPoly(halfPoly)
end

local function setColor(r, g, b, alpha)
	surface_SetDrawColor(r, g, b, alpha * drawAlpha)
end

local function setRegionColor(region, severity)
	local r, g, b = severityColor(severity)
	if arterial[region] then
		local wave = 0.5 + 0.5 * math_sin(CurTime() * pulseHz * TAU)
		local mul = 1 - ARTERIAL_PULSE_DEPTH * wave
		r, g, b = r * mul, g * mul, b * mul
	end
	setColor(r, g, b, FILL_ALPHA)
end

local function drawOutlineCircle(x, y, r)
	setColor(OUTLINE_COLOR[1], OUTLINE_COLOR[2], OUTLINE_COLOR[3], OUTLINE_ALPHA)
	polyCircle(x, y, r + OUTLINE_WIDTH)
end

local function drawCrack(x, y, r)
	local offset = r * 0.7
	setColor(CRACK_COLOR[1], CRACK_COLOR[2], CRACK_COLOR[3], FILL_ALPHA)
	surface_DrawLine(x - offset, y + offset, x + offset, y - offset)
	surface_DrawLine(x - offset + 1, y + offset, x + offset + 1, y - offset)
end

local function drawStump(x, y, r)
	local stumpRadius = r * STUMP_SCALE
	drawOutlineCircle(x, y, stumpRadius)
	setColor(STUMP_COLOR[1], STUMP_COLOR[2], STUMP_COLOR[3], FILL_ALPHA)
	polyCircle(x, y, stumpRadius)
end

local function drawNode(point, region, radius)
	if not smoothValid[point] then return end

	local x, y = toScreen(point)
	local r = radius * drawScale
	if missing[region] then
		drawStump(x, y, r)
		return
	end

	drawOutlineCircle(x, y, r)
	setRegionColor(region, sevA[region])
	polyCircle(x, y, r)

	local secondary = sevB[region]
	if secondary then
		local radians = math.rad(smoothAngle)
		local upX, upY = -math_sin(radians), -math_cos(radians)
		setRegionColor(region, secondary)
		polyHalfCircle(x, y, r, math_atan2(upY, upX))
		setColor(OUTLINE_COLOR[1], OUTLINE_COLOR[2], OUTLINE_COLOR[3], OUTLINE_ALPHA)
		surface_DrawLine(x + upX * r, y + upY * r, x - upX * r, y - upY * r)
	end

	if fractured[region] then drawCrack(x, y, r) end
end

local function beadCount(length, r)
	return math_Clamp(math_ceil(length / (r * BEAD_SPACING)), 1, MAX_BEADS)
end

local function drawSegment(fromPoint, toPoint, region, radius, includeEnd)
	local x0, y0 = toScreen(fromPoint)
	local x1, y1 = toScreen(toPoint)
	local r = radius * drawScale
	local dx, dy = x1 - x0, y1 - y0
	local beads = beadCount(math_sqrt(dx * dx + dy * dy), r)
	local last = includeEnd and beads or beads - 1

	for i = 0, last do
		local t = i / beads
		drawOutlineCircle(x0 + dx * t, y0 + dy * t, r)
	end
	setRegionColor(region, sevA[region])
	for i = 0, last do
		local t = i / beads
		polyCircle(x0 + dx * t, y0 + dy * t, r)
	end

	if fractured[region] then drawCrack(x0 + dx * 0.5, y0 + dy * 0.5, r) end
end

local function limbPointsValid(limb, count)
	for i = 1, count do
		if not smoothValid[limb.points[i]] then return false end
	end

	return true
end

local function drawLimb(limb)
	local points, radii = limb.points, limb.radii
	if not limbPointsValid(limb, 3) then return end

	local stumpX, stumpY = toScreen(points[1])
	if missing[limb.upper] then
		drawStump(stumpX, stumpY, radii[1] * drawScale)
		return
	end
	drawSegment(points[1], points[2], limb.upper, radii[1], false)

	if missing[limb.lower] then
		stumpX, stumpY = toScreen(points[2])
		drawStump(stumpX, stumpY, radii[2] * drawScale)
		return
	end

	local hasFoot = points[4] and smoothValid[points[4]]
	drawSegment(points[2], points[3], limb.lower, radii[2], not limb.hand and not hasFoot)
	if hasFoot then
		drawSegment(points[3], points[4], limb.lower, radii[3], true)
		return
	end
	if limb.hand then drawNode(points[3], limb.hand, radii[3]) end
end

local function drawBody()
	draw.NoTexture()

	for _, limb in ipairs(LEG_LIMBS) do
		drawLimb(limb)
	end
	drawNode(P_PELVIS, "pelvis", R_PELVIS)
	drawNode(P_CHEST, "chest", R_CHEST)
	drawNode(P_NECK, "neck", R_NECK)
	if not missing.skull then
		drawNode(P_SKULL, "skull", R_SKULL)
		drawNode(P_JAW, "jaw", R_JAW)
	end
	for _, limb in ipairs(ARM_LIMBS) do
		drawLimb(limb)
	end
end

hook.Add("HUDPaint", "homigrad/body-status/draw", function()
	if not enabled:GetBool() then return end

	local ply = LocalPlayer()
	local body = getBodyEntity(ply)
	if not IsValid(body) or body:IsDormant() then return end

	local now = CurTime()
	local snap = body ~= lastBody or now - lastDrawTime > SNAP_AFTER_HIDDEN
	if snap then smoothValid[P_PELVIS] = false end
	if updatePose(body) then
		smoothPose(snap)
		lastBody = body
	end
	lastDrawTime = now
	if not smoothValid[P_PELVIS] then return end

	if snap or now >= nextMedicalUpdate then
		updateMedicalState(ply, body)
		nextMedicalUpdate = now + MEDICAL_UPDATE_INTERVAL
	end

	local panelSize = ScrH() * PANEL_HEIGHT_FRACTION
	drawScale = panelSize / FIGURE_EXTENT
	drawCenterX = ScrH() * PANEL_MARGIN_FRACTION + panelSize * 0.5
	drawCenterY = ScrH() * 0.5
	drawAlpha = ply:Alive() and 1 or DEAD_ALPHA_MUL

	drawBody()
end)
