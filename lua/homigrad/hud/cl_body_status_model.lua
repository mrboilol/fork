local K = include("homigrad/hud/cl_body_status_data.lua")

local IsValid = IsValid
local CurTime = CurTime
local FrameTime = FrameTime
local FrameNumber = FrameNumber
local ScrH = ScrH
local math_Clamp = math.Clamp
local math_exp = math.exp
local math_max = math.max

local cvar = CreateClientConVar("hg_simplesubrosa", "1", true, false, "1 - sub rosa shows a flat white silhouette of your real pose tinted by damage instead of circles", 0, 1)

function hg.SimpleSubRosaEnabled()
	return cvar:GetBool() and (not hg.SubRosaEnabled or hg.SubRosaEnabled())
end

local CFG = {
	WIDTH_FRACTION = 0.3,
	HEIGHT_FRACTION = 0.3,
	FIT_PAD = 0.35,
	REFERENCE_HALF = 44,
	COLLAPSED_SCALE = 0.05,
	STRETCH_FACTOR = 4,
	STRETCH_SLACK = 12,
	FIT_SMOOTH_RATE = 6,
	OUTLINE_PIXELS = 2,
	DISLOCATION = 0.85,
	TISSUE_BLACK = 0.95,
	QUANT = 20,
	OVERLAY_PULL = 6,
	JAW_PLANE_LIFT = 0.35,
	JAW_PLANE_TILT = 0.5,
	STALE_CAPTURE = 2,
	CAMERA_DISTANCE = 500,
}

local STOPS = {
	{0, 1, 1, 1},
	{0.5, 1, 0.84, 0.16},
	{1, 0.85, 0.1, 0.1},
}
local BLACK = {0.07, 0.07, 0.07}

local flatMat = CreateMaterial("hg_simplesubrosa_flat", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$model"] = 1,
	["$nocull"] = 1,
})

local NAMED_REGIONS = {
	["ValveBiped.Bip01_Head1"] = "skull",
	["ValveBiped.Bip01_Neck1"] = "neck",
	["ValveBiped.Bip01_Spine4"] = "chest",
	["ValveBiped.Bip01_Spine2"] = "chest",
	["ValveBiped.Bip01_L_Clavicle"] = "chest",
	["ValveBiped.Bip01_R_Clavicle"] = "chest",
	["ValveBiped.Bip01_Spine1"] = "abdomen",
	["ValveBiped.Bip01_Spine"] = "abdomen",
	["ValveBiped.Bip01_Pelvis"] = "pelvis",
	["ValveBiped.Bip01_L_Thigh"] = "llegup",
	["ValveBiped.Bip01_L_Calf"] = "lleg",
	["ValveBiped.Bip01_L_Foot"] = "lleg",
	["ValveBiped.Bip01_L_Toe0"] = "lleg",
	["ValveBiped.Bip01_R_Thigh"] = "rlegup",
	["ValveBiped.Bip01_R_Calf"] = "rleg",
	["ValveBiped.Bip01_R_Foot"] = "rleg",
	["ValveBiped.Bip01_R_Toe0"] = "rleg",
	["ValveBiped.Bip01_L_UpperArm"] = "larmup",
	["ValveBiped.Bip01_L_Forearm"] = "larm",
	["ValveBiped.Bip01_L_Hand"] = "lhand",
	["ValveBiped.Bip01_R_UpperArm"] = "rarmup",
	["ValveBiped.Bip01_R_Forearm"] = "rarm",
	["ValveBiped.Bip01_R_Hand"] = "rhand",
}
for _, name in ipairs(K.BONE_CANDIDATES[K.BONE.JAW]) do
	NAMED_REGIONS[name] = "jaw"
end

local REGIONS = {"abdomen"}
for _, region in ipairs(K.REGIONS) do
	if region ~= "spine1" and region ~= "spine2" then REGIONS[#REGIONS + 1] = region end
end
local TISSUE_REGIONS = table.Copy(K.TISSUE_REGIONS)
TISSUE_REGIONS.abdomen = "torso"
local BELOW_SPINE1 = {"abdomen", "pelvis", "llegup", "lleg", "rlegup", "rleg"}
local BELOW_SPINE2 = {"chest", "abdomen", "pelvis", "llegup", "lleg", "rlegup", "rleg"}

local level, black, missing = {}, {}, {}
local baseVisible = {}
local tinted, tintedCount = {}, 0
local skullKey, jawKey = 0, 0

local proxy, boneRegion, boneCount, hasJawBone
local regionProxies = {}
local ids = {}
local worldMats, haveWorld = {}, {}
local localMats, hiddenMats = {}, {}
local writable = {}
local parentOf, refLocal = {}, {}
local eyesPos = Vector()
local haveEyes = false
local zeroScale = Vector(0, 0, 0)
local frameAng = Angle()
local captureFrame, capturePriority, captureBody = -10, 0, nil
local trackedBody

local smoothYaw = 0
local boundsMin, boundsMax = Vector(), Vector()
local fitHalf, fitY, fitZ = 0, 0, 0
local lastBody, lastDrawTime, nextMedicalUpdate = nil, 0, 0
local displayGray, displayFade = 0, 1

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

local function regionKey(region)
	if black[region] then return -1 end

	return math.floor((level[region] or 0) * CFG.QUANT + 0.5)
end

local function keyColor(key)
	if key < 0 then return BLACK[1], BLACK[2], BLACK[3] end

	local value = key / CFG.QUANT
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

local function buildGroups()
	tintedCount = 0
	skullKey, jawKey = regionKey("skull"), regionKey("jaw")

	for _, region in ipairs(REGIONS) do
		baseVisible[region] = not missing[region]
		local headSplit = not hasJawBone and (region == "skull" or region == "jaw")
		local key = regionKey(region)
		if not missing[region] and not headSplit and key ~= 0 then
			tintedCount = tintedCount + 1
			tinted[tintedCount] = region
		end
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

	buildGroups()
end

local function lookupFirst(ent, index)
	for _, name in ipairs(K.BONE_CANDIDATES[index]) do
		local found = ent:LookupBone(name)
		if found then return found end
	end
end

local function buildRefPose(model)
	refLocal = {}
	local ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
	if not IsValid(ent) then return end

	ent:SetNoDraw(true)
	ent:SetupBones()
	local ref = {}
	for i = 0, boneCount - 1 do
		ref[i] = ent:GetBoneMatrix(i)
	end
	for i = 0, boneCount - 1 do
		local parent = parentOf[i]
		if ref[i] and parent and ref[parent] then refLocal[i] = ref[parent]:GetInverseTR() * ref[i] end
	end
	ent:Remove()
end

local function mapRegions(ent)
	local direct, linked = {}, false
	hasJawBone = false
	for name, region in pairs(NAMED_REGIONS) do
		local id = ent:LookupBone(name)
		if id and id >= 0 and id < boneCount then
			direct[id] = region
			if region == "jaw" then hasJawBone = true end
		end
	end
	for i = 0, boneCount - 1 do
		local name = ent:GetBoneName(i) or ""
		if not direct[i] and name:find("Finger", 1, true) then
			direct[i] = name:find("_L_", 1, true) and "lhand" or name:find("_R_", 1, true) and "rhand" or nil
		end
		local parent = ent:GetBoneParent(i)
		parentOf[i] = parent and parent >= 0 and parent or nil
		if parentOf[i] then linked = true end
	end
	for i = 0, boneCount - 1 do
		local bone, region = i, direct[i]
		while not region and parentOf[bone] do
			bone = parentOf[bone]
			region = direct[bone]
		end
		boneRegion[i] = region or "pelvis"
	end
	if linked then buildRefPose(ent:GetModel()) end

	return linked
end

local regionMapReady = false

local function buildBoneMap(ent)
	boneCount = ent:GetBoneCount() or 0
	boneRegion = {}
	for i = 0, boneCount - 1 do
		writable[i] = ent:BoneHasFlag(i, BONE_USED_BY_VERTEX_LOD0)
		worldMats[i] = worldMats[i] or Matrix()
		localMats[i] = localMats[i] or Matrix()
		hiddenMats[i] = hiddenMats[i] or Matrix()
	end
	regionMapReady = mapRegions(ent)

	local B = K.BONE
	ids.pelvis, ids.spine1 = lookupFirst(ent, B.PELVIS), lookupFirst(ent, B.SPINE1)
	ids.neck = lookupFirst(ent, B.NECK) or lookupFirst(ent, B.SPINE4)
	ids.head = lookupFirst(ent, B.HEAD)
	ids.lThigh, ids.rThigh = lookupFirst(ent, B.L_THIGH), lookupFirst(ent, B.R_THIGH)
	ids.lArm, ids.rArm = lookupFirst(ent, B.L_UPPERARM), lookupFirst(ent, B.R_UPPERARM)
	local eyes = ent:LookupAttachment("eyes")
	ids.eyes = eyes and eyes > 0 and eyes or nil
end

local function buildProxyBones(ent, count)
	local visible = ent.hgBodyStatusVisible
	if not visible or not boneCount then return end

	for i = 0, math.min(count, boneCount) - 1 do
		if writable[i] and not pcall(ent.SetBoneMatrix, ent, i, visible[boneRegion[i]] and localMats[i] or hiddenMats[i]) then writable[i] = false end
	end
end

local function createProxy(model, visible)
	local ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
	if not IsValid(ent) then return end

	ent:SetNoDraw(true)
	ent:SetLOD(0)
	ent:SetPos(vector_origin)
	ent:SetAngles(angle_zero)
	ent:SetRenderBounds(Vector(-128, -128, -128), Vector(128, 128, 128))
	ent.hgBodyStatusVisible = visible
	ent:AddCallback("BuildBonePositions", buildProxyBones)

	return ent
end

local function removeProxies()
	if IsValid(proxy) then proxy:Remove() end
	proxy = nil
	for region, ent in pairs(regionProxies) do
		if IsValid(ent) then ent:Remove() end
		regionProxies[region] = nil
	end
end

local function getProxy(body)
	local model = body:GetModel()
	if not isstring(model) or model == "" then return end

	if not IsValid(proxy) or proxy:GetModel() ~= model then
		removeProxies()
		proxy = createProxy(model, baseVisible)
		if not proxy then return end
		buildBoneMap(proxy)
		captureBody = nil
	elseif not regionMapReady then
		regionMapReady = mapRegions(proxy)
	end

	return proxy
end

local function regionProxy(region)
	local ent = regionProxies[region]
	if not IsValid(ent) then
		ent = createProxy(proxy:GetModel(), {[region] = true})
		regionProxies[region] = ent
	end

	return ent
end

local parentRot = Matrix()
local rebuiltBone = {}

local function boneBroken(world, parentWorld, rel, modelScale)
	local scale = world:GetScale()
	if math.min(scale.x, scale.y, scale.z) < CFG.COLLAPSED_SCALE then return true end

	local pos = world:GetTranslation()
	if pos.x ~= pos.x or pos.y ~= pos.y or pos.z ~= pos.z then return true end

	local reach = rel:GetTranslation():Length() * modelScale * CFG.STRETCH_FACTOR + CFG.STRETCH_SLACK

	return pos:DistToSqr(parentWorld:GetTranslation()) > reach * reach
end

local function restoreCollapsedBones(ent)
	local modelScale = ent:GetModelScale() or 1
	for i = 0, boneCount - 1 do
		rebuiltBone[i] = false
		local parent, rel = parentOf[i], refLocal[i]
		if haveWorld[i] and parent and rel and haveWorld[parent] then
			local world = worldMats[i]
			if rebuiltBone[parent] or boneBroken(world, worldMats[parent], rel, modelScale) then
				local parentWorld = worldMats[parent]
				local parentPos = parentWorld:GetTranslation()
				parentRot:Identity()
				parentRot:SetAngles(parentWorld:GetAngles())
				parentRot:SetTranslation(parentPos)
				local rebuilt = parentRot * rel
				rebuilt:SetTranslation(parentPos + (rebuilt:GetTranslation() - parentPos) * modelScale)
				world:Set(rebuilt)
				rebuiltBone[i] = true
			end
		end
	end
end

local function captureBones(ent)
	for i = 0, boneCount - 1 do
		local matrix = ent:GetBoneMatrix(i)
		if matrix then worldMats[i]:Set(matrix) end
		haveWorld[i] = matrix ~= nil
	end
	restoreCollapsedBones(ent)

	haveEyes = false
	local attachment = ids.eyes and ent:GetAttachment(ids.eyes)
	if attachment then
		eyesPos:Set(attachment.Pos)
		haveEyes = true
	end
	captureBody = ent
end

hook.Add("PostDrawAppearance", "homigrad/body-status-model/capture-rendered-pose", function(ent)
	if ent ~= trackedBody or not IsValid(ent) or not IsValid(proxy) or proxy:GetModel() ~= ent:GetModel() then return end

	local priority = render.GetRenderTarget() == nil and 2 or 1
	local frame = FrameNumber()
	if captureFrame == frame and capturePriority > priority then return end

	captureBones(ent)
	captureFrame, capturePriority = frame, priority
end)

local function bonePos(id)
	return id and haveWorld[id] and worldMats[id]:GetTranslation() or nil
end

local function buildFrame()
	local pelvis, neck = bonePos(ids.pelvis), bonePos(ids.neck)
	if not pelvis or not neck then return false end

	local up = neck - pelvis
	local length = up:Length()
	if length < K.MIN_AXIS_LENGTH then return false end
	up:Div(length)

	local lThigh, rThigh = bonePos(ids.lThigh), bonePos(ids.rThigh)
	local lArm, rArm = bonePos(ids.lArm), bonePos(ids.rArm)
	local hipRight = lThigh and rThigh and rThigh - lThigh or lArm and rArm and rArm - lArm
	if not hipRight then return false end

	local hipUp = (bonePos(ids.spine1) or neck) - pelvis
	if hipUp:Length() < K.MIN_AXIS_LENGTH then hipUp = Vector(up) end
	hipUp:Normalize()
	hipRight:Sub(hipUp * hipRight:Dot(hipUp))
	if hipRight:Length() < K.MIN_AXIS_LENGTH then return false end
	hipRight:Normalize()

	local hipForward = hipUp:Cross(hipRight)
	local headingX, headingY = hipRight.x + hipForward.y, hipRight.y - hipForward.x
	if headingX * headingX + headingY * headingY < K.MIN_AXIS_LENGTH * K.MIN_AXIS_LENGTH then return false end

	return true, math.deg(math.atan2(headingX, -headingY)), pelvis, length
end

local function updateLocalMatrices(body, root)
	local scale = body:GetModelScale() or 1
	local scaleVec = Vector(scale, scale, scale)
	local haveBounds = false
	for i = 0, boneCount - 1 do
		local lm, hm = localMats[i], hiddenMats[i]
		lm:Identity()
		if haveWorld[i] then
			local world = worldMats[i]
			local pos, ang = WorldToLocal(world:GetTranslation(), world:GetAngles(), root, frameAng)
			lm:SetAngles(ang)
			lm:SetTranslation(pos)
			lm:Scale(scaleVec)
			if writable[i] then
				if haveBounds then
					boundsMin.x, boundsMin.y, boundsMin.z = math.min(boundsMin.x, pos.x), math.min(boundsMin.y, pos.y), math.min(boundsMin.z, pos.z)
					boundsMax.x, boundsMax.y, boundsMax.z = math_max(boundsMax.x, pos.x), math_max(boundsMax.y, pos.y), math_max(boundsMax.z, pos.z)
				else
					boundsMin:Set(pos)
					boundsMax:Set(pos)
					haveBounds = true
				end
			end
		else
			lm:Scale(zeroScale)
		end
		hm:Set(lm)
		hm:Scale(zeroScale)
	end
	if not haveBounds then
		boundsMin:Zero()
		boundsMax:Zero()
	end
end

local function headClipPlane(root)
	local head, neck = ids.head and localMats[ids.head], ids.neck and localMats[ids.neck]
	if not head or not neck then return end

	local headPos = head:GetTranslation()
	local up = headPos - neck:GetTranslation()
	if up:Length() < 0.01 then return end
	up:Normalize()

	local lift, face = 2, Vector(1, 0, 0)
	if haveEyes then
		local offset = WorldToLocal(eyesPos, angle_zero, root, frameAng) - headPos
		lift = offset:Dot(up) * CFG.JAW_PLANE_LIFT
		offset:Sub(up * offset:Dot(up))
		if offset:Length() > 0.01 then face = offset:GetNormalized() end
	end

	local normal = up - face * CFG.JAW_PLANE_TILT
	normal:Normalize()

	return normal, normal:Dot(headPos + up * lift)
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

local function drawPass(ent, r, g, b)
	if not IsValid(ent) then return end

	local luma = r * 0.299 + g * 0.587 + b * 0.114
	render.SetColorModulation(r + (luma - r) * displayGray, g + (luma - g) * displayGray, b + (luma - b) * displayGray)
	ent:SetLOD(0)
	ent:InvalidateBoneCache()
	ent:SetupBones()
	ent:DrawModel()
end

local function drawHeadOverlay(root)
	if missing.skull or skullKey == 0 and jawKey == 0 then return end

	local head = regionProxy("skull")
	local normal, distance = headClipPlane(root)
	if not normal then
		if skullKey ~= 0 then drawPass(head, keyColor(skullKey)) end
		return
	end

	local previous = render.EnableClipping(true)
	if skullKey ~= 0 then
		render.PushCustomClipPlane(normal, distance)
		drawPass(head, keyColor(skullKey))
		render.PopCustomClipPlane()
	end
	if jawKey ~= 0 then
		render.PushCustomClipPlane(-normal, -distance)
		drawPass(head, keyColor(jawKey))
		render.PopCustomClipPlane()
	end
	render.EnableClipping(previous)
end

local function drawOverlays(root)
	for index = 1, tintedCount do
		local region = tinted[index]
		drawPass(regionProxy(region), keyColor(regionKey(region)))
	end
	if not hasJawBone then drawHeadOverlay(root) end
end

local OUTLINE_DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {0.7071, 0.7071}, {-0.7071, 0.7071}, {0.7071, -0.7071}, {-0.7071, -0.7071}}

local function startCam(x, y, w, h, half, dy, dz, pull)
	local halfW = half * w / h
	local camX = math_max(CFG.CAMERA_DISTANCE, boundsMax.x + half)
	cam.Start({
		type = "3D",
		x = x, y = y, w = w, h = h,
		origin = Vector(camX - (pull or 0), fitY + dy, fitZ + dz),
		angles = Angle(0, 180, 0),
		ortho = {left = -halfW, right = halfW, top = -half, bottom = half},
		znear = 1, zfar = camX - boundsMin.x + half,
	})
end

local function drawOutline(x, y, w, h, half)
	local step = 2 * half / h * math_max(1, CFG.OUTLINE_PIXELS * ScrH() / 1080)
	for _, dir in ipairs(OUTLINE_DIRS) do
		startCam(x, y, w, h, half, dir[1] * step, dir[2] * step)
		if dir == OUTLINE_DIRS[1] then render.ClearDepth() end
		local ok, err = pcall(drawPass, proxy, 0, 0, 0)
		cam.End()
		if not ok then return false, err end
	end

	return true
end

local function panelRect()
	local w, h = ScrH() * CFG.WIDTH_FRACTION, ScrH() * CFG.HEIGHT_FRACTION
	local x = ScrH() * K.CFG.PANEL_MARGIN_FRACTION + w * 0.5
	local y = ScrH() * 0.5
	if hg.MoodlesEnabled and not hg.MoodlesEnabled() then
		local face = hg.SimpleHealth and hg.SimpleHealth.Config.face
		local faceSize = ScrH() * (face and face.size or 0.075)
		local margin = ScrH() * (face and face.y or 0.012)
		x = ScrW() * 0.5
		y = ScrH() - margin * 2 - faceSize - h * 0.5
	end
	if hg.HudEdit then
		local ox, oy = hg.HudEdit.Offset("subrosa")
		x, y = x + ox, y + oy
		hg.HudEdit.Rect("subrosa", x - w * 0.5, y - h * 0.5, w, h)
	end

	return math.floor(x - w * 0.5), math.floor(y - h * 0.5), math.floor(w), math.floor(h)
end

local function getBodyEntity(ply)
	local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
	if IsValid(body) and body ~= ply then return body end
	if ply:GetNWBool("FakeGettingUp", false) and IsValid(ply.OldRagdoll) then return ply.OldRagdoll end

	return ply
end

local function drawFigure(alpha)
	local ply = LocalPlayer()
	local body = getBodyEntity(ply)
	trackedBody = body
	if not IsValid(body) or body:IsDormant() or not getProxy(body) then return end

	if captureBody ~= body or FrameNumber() - captureFrame > CFG.STALE_CAPTURE then
		captureBones(body)
		captureFrame, capturePriority = FrameNumber(), 0
	end

	local ok, yaw, root, spineLength = buildFrame()
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
	frameAng.y = smoothYaw
	root = Vector(root)
	updateLocalMatrices(body, root)

	if snap or now >= nextMedicalUpdate then
		updateMedicalState(ply, body)
		nextMedicalUpdate = now + K.CFG.MEDICAL_UPDATE_INTERVAL
	end
	updateDisplayState(ply)
	if displayFade < 0.01 then return end

	local x, y, w, h = panelRect()
	local pad = spineLength * CFG.FIT_PAD
	local half = math_max((boundsMax.z - boundsMin.z) * 0.5 + pad, ((boundsMax.y - boundsMin.y) * 0.5 + pad) * h / w, CFG.REFERENCE_HALF)
	local centerY, centerZ = (boundsMin.y + boundsMax.y) * 0.5, (boundsMin.z + boundsMax.z) * 0.5
	if snap or fitHalf <= 0 then
		fitHalf, fitY, fitZ = half, centerY, centerZ
	else
		local blend = 1 - math_exp(-FrameTime() * CFG.FIT_SMOOTH_RATE)
		fitHalf = fitHalf + (half - fitHalf) * blend
		fitY = fitY + (centerY - fitY) * blend
		fitZ = fitZ + (centerZ - fitZ) * blend
	end
	half = fitHalf
	render.SuppressEngineLighting(true)
	render.MaterialOverride(flatMat)
	render.SetBlend(alpha * displayFade)

	local drawn, err = drawOutline(x, y, w, h, half)
	startCam(x, y, w, h, half, 0, 0)
	render.ClearDepth()
	if drawn then drawn, err = pcall(drawPass, proxy, 1, 1, 1) end
	cam.End()
	startCam(x, y, w, h, half, 0, 0, CFG.OVERLAY_PULL * (body:GetModelScale() or 1))
	if drawn then drawn, err = pcall(drawOverlays, root) end

	render.SetBlend(1)
	render.MaterialOverride()
	render.SetColorModulation(1, 1, 1)
	render.SuppressEngineLighting(false)
	cam.End()
	if not drawn then ErrorNoHalt(err, "\n") end
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

	local ok, err = pcall(drawFigure, alpha)
	if not ok then ErrorNoHalt(err, "\n") end
end)

concommand.Add("hg_simplesubrosa_debug", function()
	local parts = {}
	for index = 1, tintedCount do
		local region = tinted[index]
		parts[#parts + 1] = region .. "=" .. regionKey(region)
	end
	print("[subrosa] proxy", IsValid(proxy), "bones", boneCount, "tinted", tintedCount, table.concat(parts, " "))
	local ply = LocalPlayer()
	local org = ply.new_organism or ply.organism
	if istable(org) then print("[subrosa] org rarm", org.rarm, org.rarm_up, org.rarm_down, "larm", org.larm, org.larm_up, org.larm_down) else print("[subrosa] no org") end
	local unwritable = {}
	for i = 0, (boneCount or 0) - 1 do
		if not writable[i] and IsValid(proxy) and proxy:BoneHasFlag(i, BONE_USED_BY_VERTEX_LOD0) then unwritable[#unwritable + 1] = proxy:GetBoneName(i) end
	end
	print("[subrosa] latched unwritable", table.concat(unwritable, ", "))
	for index = 1, tintedCount do
		local region = tinted[index]
		local ent = regionProxies[region]
		if IsValid(ent) then
			ent:InvalidateBoneCache()
			ent:SetupBones()
			local shown, hidden = 0, 0
			for i = 0, boneCount - 1 do
				local m = ent:GetBoneMatrix(i)
				local name = ent:GetBoneName(i) or ""
				if boneRegion[i] == region or NAMED_REGIONS[name] == region then
					print("[subrosa] bone", i, name, "map", boneRegion[i], "lod0", ent:BoneHasFlag(i, BONE_USED_BY_VERTEX_LOD0), "world", haveWorld[i], "mat", m and tostring(m:GetTranslation()) or "nil", m and tostring(m:GetScale()) or "", "local", tostring(localMats[i]:GetTranslation()))
				end
				if m and boneRegion[i] == region then
					shown = shown + 1
					if shown <= 2 then print("[subrosa]", region, ent:GetBoneName(i), m:GetTranslation(), localMats[i]:GetTranslation(), m:GetScale()) end
				elseif m and m:GetScale():Length() < 0.01 then
					hidden = hidden + 1
				end
			end
			print("[subrosa]", region, "visible bones", shown, "collapsed others", hidden)
		else
			print("[subrosa]", region, "proxy invalid")
		end
	end
end)
