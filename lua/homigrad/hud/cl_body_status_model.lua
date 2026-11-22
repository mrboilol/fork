local K = include("homigrad/hud/cl_body_status_data.lua")
local DRAW = include("homigrad/hud/cl_body_status_draw.lua")
local polyCapsule = DRAW.Capsule

local IsValid = IsValid
local CurTime = CurTime
local FrameTime = FrameTime
local FrameNumber = FrameNumber
local ScrH = ScrH
local math_Clamp = math.Clamp
local math_exp = math.exp
local math_max = math.max
local math_atan2 = math.atan2

local cvar = CreateClientConVar("hg_simplesubrosa", "0", true, false, "1 - sub rosa shows a 2D figure of your real pose tinted by damage instead of circles", 0, 1)

function hg.SimpleSubRosaEnabled()
	return cvar:GetBool() and (not hg.SubRosaEnabled or hg.SubRosaEnabled())
end

local CFG = {
	DISLOCATION = 0.85,
	TISSUE_BLACK = 0.95,
	CHEST_WIDTH = 0.62,
	ABDOMEN_WIDTH = 0.5,
	PELVIS_WIDTH = 0.78,
	SHOULDER_RADIUS = 0.11,
	HIP_RADIUS = 0.14,
	HAND_LENGTH = 0.45,
	JAW_RADIUS = 0.6,
	JAW_DEPTH = 0.01,
	OUTLINE = 2,
	STALE_CAPTURE = 2,
}

local STOPS = {
	{0, 255, 255, 255},
	{0.5, 255, 214, 40},
	{1, 215, 25, 25},
}
local BLACK = {18, 18, 18}
local OUTLINE_COLOR = {10, 10, 10, 220}

local REGIONS = {"abdomen"}
for _, region in ipairs(K.REGIONS) do
	if region ~= "spine1" and region ~= "spine2" then REGIONS[#REGIONS + 1] = region end
end
local TISSUE_REGIONS = table.Copy(K.TISSUE_REGIONS)
TISSUE_REGIONS.abdomen = "torso"
local BELOW_SPINE1 = {"abdomen", "pelvis", "llegup", "lleg", "rlegup", "rleg"}
local BELOW_SPINE2 = {"chest", "abdomen", "pelvis", "llegup", "lleg", "rlegup", "rleg"}

local B = K.BONE
local BONE_TOTAL = K.BONE_COUNT
local CANDIDATES = K.BONE_CANDIDATES

local level, black, missing = {}, {}, {}
local regionR, regionG, regionB = {}, {}, {}

local worldPos, havePos = {}, {}
for i = 1, BONE_TOTAL do
	worldPos[i] = Vector()
end
local eyesForward = Vector()
local haveEyes = false
local captureFrame, capturePriority, captureBody = -10, 0, nil
local trackedBody

local smoothYaw = 0
local lastBody, lastDrawTime, nextMedicalUpdate = nil, 0, 0
local displayGray, displayFade = 0, 1

local parts, partOrder, partCount = {}, {}, 0
local frameRoot, frameForward, spineLength, yawCos, yawSin
local centerX, centerY, pixelScale, targetZ = 0, 0, 1, 0

local function orgNumber(org, key)
	local value = org[key]

	return isnumber(value) and value or 0
end

local function combine(a, b)
	return 1 - (1 - math_Clamp(a, 0, 1)) * (1 - math_Clamp(b, 0, 1))
end

local function segmentValue(org, base, segment)
	local value = org[base .. "_" .. segment]
	if isnumber(value) then return value end

	return orgNumber(org, base)
end

local function segmentDislocated(org, base, segment)
	local flagged = org[base .. "_" .. segment .. "_disl"]
	if flagged ~= nil then return flagged == true end

	return segment == "up" and org[base .. "dislocation"] == true
end

local function mark(region, value, isBlack)
	level[region] = math_max(level[region] or 0, math_Clamp(value, 0, 1))
	if isBlack then black[region] = true end
end

local function markAll(list)
	for _, region in ipairs(list) do
		black[region] = true
	end
end

local function levelColor(value)
	for index = 2, #STOPS do
		local high = STOPS[index]
		if value <= high[1] then
			local low = STOPS[index - 1]
			local t = (value - low[1]) / (high[1] - low[1])

			return low[2] + (high[2] - low[2]) * t, low[3] + (high[3] - low[3]) * t, low[4] + (high[4] - low[4]) * t
		end
	end
	local last = STOPS[#STOPS]

	return last[2], last[3], last[4]
end

local function updateLimbs(org)
	for _, limb in ipairs(K.LIMBS) do
		local up, down = segmentValue(org, limb.base, "up"), segmentValue(org, limb.base, "down")
		local upper, lower, hand = limb.upper, limb.lower, limb.hand
		missing[upper] = org[upper .. "amputated"] == true
		missing[lower] = missing[upper] or org[lower .. "amputated"] == true
		mark(upper, up, up >= 1)
		mark(lower, down, down >= 1)
		if hand then
			missing[hand] = missing[lower] or org[hand .. "amputated"] == true
			mark(hand, down * K.WEIGHT.HAND_BONE_SHARE, down >= 1)
		end

		local upDisl = not missing[upper] and segmentDislocated(org, limb.base, "up")
		local downDisl = not missing[upper] and segmentDislocated(org, limb.base, "down")
		if upDisl then mark(upper, CFG.DISLOCATION) end
		if downDisl then mark(lower, CFG.DISLOCATION) end
		if upDisl and downDisl then
			black[upper], black[lower] = true, true
			if hand then black[hand] = true end
		end
	end
end

local function updateTorso(org)
	local skull, jaw = orgNumber(org, "skull"), orgNumber(org, "jaw")
	local ribs, pelvis = orgNumber(org, "chest"), orgNumber(org, "pelvis")
	local spine1, spine2, spine3 = orgNumber(org, "spine1"), orgNumber(org, "spine2"), orgNumber(org, "spine3")

	mark("skull", skull, skull >= 1)
	mark("jaw", jaw, jaw >= 1)
	if org.jawdislocation == true then mark("jaw", CFG.DISLOCATION) end
	mark("neck", spine3, spine3 >= 1)
	mark("chest", math_max(ribs, spine2), ribs >= 1 or spine2 >= 1)
	mark("abdomen", spine1, spine1 >= 1)
	mark("pelvis", pelvis, pelvis >= 1)
	missing.skull = org.headamputated == true
	missing.jaw = missing.skull

	if spine3 >= 1 then
		markAll(REGIONS)
	elseif spine2 >= 1 then
		markAll(BELOW_SPINE2)
	elseif spine1 >= 1 then
		markAll(BELOW_SPINE1)
	end
end

local function updateMedicalState(ply, body)
	for _, region in ipairs(REGIONS) do
		level[region], black[region], missing[region] = 0, false, false
	end

	local org = ply.new_organism or ply.organism
	if not istable(org) and IsValid(body) and body ~= ply then org = body.new_organism or body.organism end
	if istable(org) then
		for region, limb in pairs(TISSUE_REGIONS) do
			local damage = combine(hg.SoftTissue.GetLimb(org, limb) / K.SHAPE.TISSUE_FULL, hg.SoftTissue.GetMuscle(org, limb))
			mark(region, damage, damage >= CFG.TISSUE_BLACK)
		end
		updateLimbs(org)
		updateTorso(org)
	end

	for _, region in ipairs(REGIONS) do
		if black[region] then
			regionR[region], regionG[region], regionB[region] = BLACK[1], BLACK[2], BLACK[3]
		else
			regionR[region], regionG[region], regionB[region] = levelColor(level[region])
		end
	end
end

local function getBoneIds(ent)
	local model = ent:GetModel()
	local cache = ent.hgSimpleSubRosaBones
	if cache and cache.model == model then return cache end

	cache = {model = model}
	for index = 1, BONE_TOTAL do
		local id = -1
		for _, name in ipairs(CANDIDATES[index]) do
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
	ent.hgSimpleSubRosaBones = cache

	return cache
end

local function captureBones(ent)
	local cache = getBoneIds(ent)
	for index = 1, BONE_TOTAL do
		local id = cache[index]
		local matrix = id >= 0 and ent:GetBoneMatrix(id)
		if matrix then
			worldPos[index]:Set(matrix:GetTranslation())
			havePos[index] = true
		else
			havePos[index] = false
		end
	end

	haveEyes = false
	if cache.eyes > 0 then
		local attachment = ent:GetAttachment(cache.eyes)
		if attachment then
			eyesForward:Set(attachment.Ang:Forward())
			haveEyes = true
		end
	end
	captureBody = ent
end

hook.Add("PostDrawAppearance", "homigrad/body-status-model/capture-rendered-pose", function(ent)
	if ent ~= trackedBody or not IsValid(ent) then return end

	local priority = render.GetRenderTarget() == nil and 2 or 1
	local frame = FrameNumber()
	if captureFrame == frame and capturePriority > priority then return end

	captureBones(ent)
	captureFrame, capturePriority = frame, priority
end)

local function pos(index)
	return havePos[index] and worldPos[index] or nil
end

local function buildFrame()
	local pelvis, neck = pos(B.PELVIS), pos(B.NECK) or pos(B.SPINE4)
	if not pelvis or not neck then return false end

	local up = neck - pelvis
	local length = up:Length()
	if length < K.CFG.MIN_SPINE_LENGTH or length > K.CFG.MAX_SPINE_LENGTH then return false end
	up:Div(length)

	local lThigh, rThigh = pos(B.L_THIGH), pos(B.R_THIGH)
	local lArm, rArm = pos(B.L_UPPERARM), pos(B.R_UPPERARM)
	local hipRight = lThigh and rThigh and rThigh - lThigh or lArm and rArm and rArm - lArm
	if not hipRight then return false end

	local hipUp = (pos(B.SPINE1) or neck) - pelvis
	if hipUp:Length() < K.MIN_AXIS_LENGTH then hipUp = Vector(up) end
	hipUp:Normalize()
	hipRight:Sub(hipUp * hipRight:Dot(hipUp))
	if hipRight:Length() < K.MIN_AXIS_LENGTH then return false end
	hipRight:Normalize()

	local hipForward = hipUp:Cross(hipRight)
	local headingX, headingY = hipRight.x + hipForward.y, hipRight.y - hipForward.x
	if headingX * headingX + headingY * headingY < K.MIN_AXIS_LENGTH * K.MIN_AXIS_LENGTH then return false end

	local torsoRight = lArm and rArm and rArm - lArm or Vector(hipRight)
	torsoRight:Sub(up * torsoRight:Dot(up))
	frameForward = torsoRight:Length() < K.MIN_AXIS_LENGTH and hipForward or up:Cross(torsoRight:GetNormalized())
	frameRoot, spineLength = pelvis, length

	return true, math.deg(math_atan2(headingX, -headingY))
end

local function project(p)
	local scale = K.DISPLAY_SPINE / spineLength
	local dx, dy = p.x - frameRoot.x, p.y - frameRoot.y
	local depth = (dx * yawCos + dy * yawSin) * scale
	local side = (dy * yawCos - dx * yawSin) * scale

	return centerX + side * pixelScale, centerY - ((p.z - frameRoot.z) * scale - targetZ) * pixelScale, depth
end

local function radiusPixels(fraction)
	return fraction * K.DISPLAY_SPINE * pixelScale
end

local function addPart(region, a, b, radius, depthBias)
	if not a or not b or missing[region] then return end

	local ax, ay, ad = project(a)
	local bx, by, bd = project(b)
	partCount = partCount + 1
	local part = parts[partCount]
	if not part then
		part = {}
		parts[partCount] = part
	end
	part.ax, part.ay, part.bx, part.by = ax, ay, bx, by
	part.r, part.region = radius, region
	part.depth = (ad + bd) * 0.5 + (depthBias or 0)
	partOrder[partCount] = partCount
end

local function handTip(hand, forearm)
	if not hand or not forearm then return hand end

	return hand + (hand - forearm) * CFG.HAND_LENGTH
end

local function queueLimbs()
	local lShoulder, rShoulder = pos(B.L_UPPERARM), pos(B.R_UPPERARM)
	local lElbow, rElbow = pos(B.L_FOREARM), pos(B.R_FOREARM)
	local lHand, rHand = pos(B.L_HAND), pos(B.R_HAND)
	addPart("larmup", lShoulder, lElbow, radiusPixels(K.RADIUS.UPPER_ARM))
	addPart("rarmup", rShoulder, rElbow, radiusPixels(K.RADIUS.UPPER_ARM))
	if not missing.larmup then addPart("larm", lElbow, lHand, radiusPixels(K.RADIUS.LOWER_ARM)) end
	if not missing.rarmup then addPart("rarm", rElbow, rHand, radiusPixels(K.RADIUS.LOWER_ARM)) end
	if not missing.larm then addPart("lhand", lHand, handTip(lHand, lElbow), radiusPixels(K.RADIUS.HAND)) end
	if not missing.rarm then addPart("rhand", rHand, handTip(rHand, rElbow), radiusPixels(K.RADIUS.HAND)) end

	local lHip, rHip = pos(B.L_THIGH), pos(B.R_THIGH)
	local lKnee, rKnee = pos(B.L_CALF), pos(B.R_CALF)
	local lAnkle, rAnkle = pos(B.L_FOOT), pos(B.R_FOOT)
	addPart("llegup", lHip, lKnee, radiusPixels(K.RADIUS.THIGH))
	addPart("rlegup", rHip, rKnee, radiusPixels(K.RADIUS.THIGH))
	if not missing.llegup then
		addPart("lleg", lKnee, lAnkle, radiusPixels(K.RADIUS.CALF))
		addPart("lleg", lAnkle, pos(B.L_TOE) or lAnkle, radiusPixels(K.RADIUS.FOOT))
	end
	if not missing.rlegup then
		addPart("rleg", rKnee, rAnkle, radiusPixels(K.RADIUS.CALF))
		addPart("rleg", rAnkle, pos(B.R_TOE) or rAnkle, radiusPixels(K.RADIUS.FOOT))
	end
end

local function queueTorso()
	local pelvis, spine1, spine2 = pos(B.PELVIS), pos(B.SPINE1), pos(B.SPINE2)
	local spine4 = pos(B.SPINE4) or spine2
	local neck, head = pos(B.NECK), pos(B.HEAD)
	local lShoulder, rShoulder = pos(B.L_UPPERARM), pos(B.R_UPPERARM)
	local lHip, rHip = pos(B.L_THIGH), pos(B.R_THIGH)

	local shoulderSpan = lShoulder and rShoulder and lShoulder:Distance(rShoulder) / spineLength or K.RADIUS.CHEST * 4
	local hipSpan = lHip and rHip and lHip:Distance(rHip) / spineLength or K.RADIUS.PELVIS * 3
	local chestR = radiusPixels(shoulderSpan * 0.5 * CFG.CHEST_WIDTH)
	local abdomenR = radiusPixels(shoulderSpan * 0.5 * CFG.ABDOMEN_WIDTH)
	local pelvisR = radiusPixels(hipSpan * 0.5 * CFG.PELVIS_WIDTH + K.RADIUS.THIGH * 0.5)

	addPart("pelvis", pelvis, spine1 or pelvis, pelvisR)
	addPart("pelvis", lHip, rHip, radiusPixels(CFG.HIP_RADIUS))
	addPart("abdomen", spine1 or pelvis, spine2, abdomenR)
	addPart("chest", spine2, spine4, chestR)
	addPart("chest", lShoulder, rShoulder, radiusPixels(CFG.SHOULDER_RADIUS))
	addPart("neck", spine4, neck or head, radiusPixels(K.RADIUS.NECK))
	if not head or missing.skull then return end

	local headUp = neck and head - neck or (head - (spine4 or head))
	if headUp:Length() > 0 then headUp:Normalize() end
	local face = haveEyes and eyesForward or frameForward
	local skull = head + headUp * (K.SKULL_LIFT * spineLength)
	local jaw = pos(B.JAW) or skull + (face * K.CFG.JAW_FORWARD - headUp * K.CFG.JAW_DROP) * spineLength
	addPart("neck", neck or spine4, head, radiusPixels(K.RADIUS.NECK))
	addPart("skull", skull, skull, radiusPixels(K.RADIUS.SKULL))
	addPart("jaw", LerpVector(0.4, skull, jaw), jaw, radiusPixels(K.RADIUS.SKULL * CFG.JAW_RADIUS), CFG.JAW_DEPTH)
end

local function farthestFirst(a, b)
	return parts[a].depth < parts[b].depth
end

local function setColor(r, g, b, a)
	local luma = r * 0.299 + g * 0.587 + b * 0.114
	surface.SetDrawColor(r + (luma - r) * displayGray, g + (luma - g) * displayGray, b + (luma - b) * displayGray, a * displayFade)
end

local function drawParts()
	for i = partCount + 1, #partOrder do
		partOrder[i] = nil
	end
	table.sort(partOrder, farthestFirst)

	local outline = math_max(CFG.OUTLINE * ScrH() / K.REFERENCE_SCREEN_HEIGHT, 1)
	draw.NoTexture()
	for i = 1, partCount do
		local part = parts[partOrder[i]]
		local region = part.region
		setColor(OUTLINE_COLOR[1], OUTLINE_COLOR[2], OUTLINE_COLOR[3], OUTLINE_COLOR[4])
		polyCapsule(part.ax, part.ay, part.bx, part.by, part.r + outline)
		setColor(regionR[region] or 255, regionG[region] or 255, regionB[region] or 255, 255)
		polyCapsule(part.ax, part.ay, part.bx, part.by, part.r)
	end
end

local function updateDisplayState(ply)
	local org = ply.organism or ply.new_organism
	local otrub = org and org.otrub or false
	local grayTarget = 0
	if org then
		local consciousness = tonumber(org.consciousness) or 1
		local consciousnessSeverity = math_Clamp((K.CFG.GRAY_CONSCIOUSNESS_START - consciousness) / (K.CFG.GRAY_CONSCIOUSNESS_START - K.CFG.OTRUB_CONSCIOUSNESS), 0, 1)
		local shockSeverity = math_Clamp(((tonumber(org.shock) or 0) - K.CFG.GRAY_SHOCK_START) / K.CFG.GRAY_SHOCK_RANGE, 0, 1)
		grayTarget = math_max(consciousnessSeverity, shockSeverity)
	end
	if otrub then grayTarget = 1 end

	local dt = FrameTime()
	displayGray = displayGray + (grayTarget - displayGray) * (1 - math_exp(-dt * K.CFG.GRAY_RATE))
	local fadeRate = otrub and K.CFG.FADE_OUT_RATE or K.CFG.FADE_IN_RATE
	displayFade = displayFade + ((otrub and 0 or 1) - displayFade) * (1 - math_exp(-dt * fadeRate))
end

local function layout()
	local size = ScrH() * K.CFG.PANEL_SIZE_FRACTION
	pixelScale = size / (K.CFG.FIGURE_EXTENT * K.DISPLAY_SPINE)
	centerX = ScrH() * K.CFG.PANEL_MARGIN_FRACTION + size * 0.5
	centerY = ScrH() * 0.5
	if hg.MoodlesEnabled and not hg.MoodlesEnabled() then
		local face = hg.SimpleHealth and hg.SimpleHealth.Config.face
		local faceSize = ScrH() * (face and face.size or 0.075)
		local margin = ScrH() * (face and face.y or 0.012)
		centerX = ScrW() * 0.5
		centerY = ScrH() - margin * 2 - faceSize - size * 0.5
	end
	targetZ = K.CFG.TARGET_HEIGHT * K.DISPLAY_SPINE

	if hg.HudEdit then
		local ox, oy = hg.HudEdit.Offset("subrosa")
		centerX, centerY = centerX + ox, centerY + oy
		hg.HudEdit.Rect("subrosa", centerX - size * 0.5, centerY - size * 0.5, size, size)
	end
end

local function getBodyEntity(ply)
	local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
	if IsValid(body) and body ~= ply then return body end
	if ply:GetNWBool("FakeGettingUp", false) and IsValid(ply.OldRagdoll) then return ply.OldRagdoll end

	return ply
end

local function drawFigure()
	local ply = LocalPlayer()
	local body = getBodyEntity(ply)
	trackedBody = body
	if not IsValid(body) or body:IsDormant() then return end

	if captureBody ~= body or FrameNumber() - captureFrame > CFG.STALE_CAPTURE then
		captureBones(body)
		captureFrame, capturePriority = FrameNumber(), 0
	end

	local ok, yaw = buildFrame()
	if not ok then return end

	local now = CurTime()
	local snap = body ~= lastBody or now - lastDrawTime > K.CFG.SNAP_AFTER_HIDDEN
	lastBody, lastDrawTime = body, now
	if snap then
		smoothYaw = yaw
	else
		local blend = 1 - math_exp(-FrameTime() * K.CFG.YAW_SMOOTH_RATE)
		smoothYaw = math.NormalizeAngle(smoothYaw + math.AngleDifference(yaw, smoothYaw) * blend)
	end
	local yawRadians = math.rad(smoothYaw)
	yawCos, yawSin = math.cos(yawRadians), math.sin(yawRadians)

	if snap or now >= nextMedicalUpdate then
		updateMedicalState(ply, body)
		nextMedicalUpdate = now + K.CFG.MEDICAL_UPDATE_INTERVAL
	end
	updateDisplayState(ply)
	if displayFade < 0.01 then return end

	layout()
	partCount = 0
	queueTorso()
	queueLimbs()
	drawParts()
end

hook.Add("HUDPaint", "homigrad/body-status-model/draw", function()
	if not hg.SimpleSubRosaEnabled() then
		trackedBody = nil
		return
	end

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		trackedBody = nil
		return
	end

	local alpha = hg.DeathHUDAlpha and hg.DeathHUDAlpha() or 1
	if alpha <= 0 then return end

	surface.SetAlphaMultiplier(alpha)
	local ok, err = pcall(drawFigure)
	surface.SetAlphaMultiplier(1)
	if not ok then ErrorNoHalt(err, "\n") end
end)
