local K = include("homigrad/hud/cl_body_status_data.lua")

local IsValid = IsValid
local CurTime = CurTime
local FrameTime = FrameTime
local ScrH = ScrH
local math_Clamp = math.Clamp
local math_exp = math.exp
local math_max = math.max

local cvar = CreateClientConVar("hg_simplesubrosa", "0", true, false, "1 - sub rosa shows your player model tinted by damage instead of circles", 0, 1)

function hg.SimpleSubRosaEnabled()
	return cvar:GetBool() and (not hg.SubRosaEnabled or hg.SubRosaEnabled())
end

local CFG = {
	DISLOCATION = 0.85,
	TISSUE_BLACK = 0.95,
	QUANT = 20,
	PAD = 4,
	FRAME_SMOOTH = 6,
	YAW_SMOOTH = 5,
	LYING_FORWARD = 0.35,
	JAW_PLANE_LIFT = 0.35,
	JAW_PLANE_TILT = 0.5,
	AMBIENT = 0.45,
	KEY_LIGHT = 1,
	TOP_LIGHT = 0.75,
}

local STOPS = {
	{0, 1, 1, 1},
	{0.5, 1, 0.84, 0.16},
	{1, 0.85, 0.1, 0.1},
}
local BLACK = {0.08, 0.08, 0.08}

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
local groups, groupCount = {}, 0
local splitHead, skullKey, jawKey
local skullVisible, jawVisible = {skull = true}, {skull = true}

local proxy, boneRegion, boneCount, hasJawBone
local ids = {}
local localMats, hiddenMats = {}, {}
local passVisible
local zeroScale = Vector(0, 0, 0)
local frameAng = Angle()
local whiteMat = Material("models/debug/debugwhite")

local smoothYaw, centerY, centerZ, halfExtent = 0, 0, 0, 40
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

local function addToGroup(region, key)
	for index = 1, groupCount do
		local group = groups[index]
		if group.key == key then
			group.visible[region] = true
			return
		end
	end

	groupCount = groupCount + 1
	local group = groups[groupCount]
	if not group then
		group = {visible = {}}
		groups[groupCount] = group
	end
	group.key = key
	group.r, group.g, group.b = keyColor(key)
	for name in pairs(group.visible) do
		group.visible[name] = nil
	end
	group.visible[region] = true
end

local function buildGroups()
	groupCount = 0
	skullKey, jawKey = regionKey("skull"), regionKey("jaw")
	splitHead = ids.head ~= nil and not hasJawBone and not missing.skull and skullKey ~= jawKey

	for _, region in ipairs(REGIONS) do
		local skip = missing[region] or (region == "jaw" and not hasJawBone) or (region == "skull" and splitHead)
		if not skip then addToGroup(region, regionKey(region)) end
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

local function buildBoneMap(ent)
	boneCount = ent:GetBoneCount() or 0
	boneRegion, hasJawBone = {}, false
	local direct = {}
	for i = 0, boneCount - 1 do
		local name = ent:GetBoneName(i) or ""
		local region = NAMED_REGIONS[name]
		if not region and name:find("Finger", 1, true) then
			region = name:find("_L_", 1, true) and "lhand" or name:find("_R_", 1, true) and "rhand" or nil
		end
		direct[i] = region
		if region == "jaw" then hasJawBone = true end
	end
	for i = 0, boneCount - 1 do
		local bone, region = i, direct[i]
		while not region and bone >= 0 do
			bone = ent:GetBoneParent(bone) or -1
			region = bone >= 0 and direct[bone] or nil
		end
		boneRegion[i] = region or "pelvis"
		localMats[i] = localMats[i] or Matrix()
		hiddenMats[i] = hiddenMats[i] or Matrix()
	end

	ids.pelvis = ent:LookupBone("ValveBiped.Bip01_Pelvis")
	ids.neck = ent:LookupBone("ValveBiped.Bip01_Neck1") or ent:LookupBone("ValveBiped.Bip01_Spine4")
	ids.head = ent:LookupBone("ValveBiped.Bip01_Head1")
	ids.lThigh, ids.rThigh = ent:LookupBone("ValveBiped.Bip01_L_Thigh"), ent:LookupBone("ValveBiped.Bip01_R_Thigh")
	ids.lArm, ids.rArm = ent:LookupBone("ValveBiped.Bip01_L_UpperArm"), ent:LookupBone("ValveBiped.Bip01_R_UpperArm")
	local eyes = ent:LookupAttachment("eyes")
	ids.eyes = eyes and eyes > 0 and eyes or nil
end

local function buildProxyBones(ent, count)
	if not passVisible then return end

	for i = 0, math.min(count, boneCount) - 1 do
		ent:SetBoneMatrix(i, passVisible[boneRegion[i]] and localMats[i] or hiddenMats[i])
	end
end

local function getProxy(body)
	local model = body:GetModel()
	if not isstring(model) or model == "" then return end

	if not IsValid(proxy) or proxy:GetModel() ~= model then
		if IsValid(proxy) then proxy:Remove() end
		proxy = ClientsideModel(model, RENDERGROUP_OPAQUE)
		if not IsValid(proxy) then return end
		proxy:SetNoDraw(true)
		proxy:SetPos(vector_origin)
		proxy:SetAngles(angle_zero)
		proxy:SetRenderBounds(Vector(-128, -128, -128), Vector(128, 128, 128))
		proxy:AddCallback("BuildBonePositions", buildProxyBones)
		buildBoneMap(proxy)
	end

	return proxy
end

local function bonePos(body, id)
	local matrix = id and body:GetBoneMatrix(id)

	return matrix and matrix:GetTranslation()
end

local function targetYaw(body)
	local pelvis, neck = bonePos(body, ids.pelvis), bonePos(body, ids.neck)
	if not pelvis or not neck then return body:GetAngles().y end

	local up = neck - pelvis
	up:Normalize()
	local lSide, rSide = bonePos(body, ids.lArm) or bonePos(body, ids.lThigh), bonePos(body, ids.rArm) or bonePos(body, ids.rThigh)
	if not lSide or not rSide then return body:GetAngles().y end

	local right = rSide - lSide
	right:Sub(up * right:Dot(up))
	right:Normalize()
	local forward = up:Cross(right)
	local fx, fy = forward.x, forward.y
	if fx * fx + fy * fy < CFG.LYING_FORWARD * CFG.LYING_FORWARD then
		fx, fy = -up.y, up.x
		local current = math.rad(smoothYaw)
		if fx * math.cos(current) + fy * math.sin(current) < 0 then fx, fy = -fx, -fy end
	end

	return math.deg(math.atan2(fy, fx))
end

local function updateLocalMatrices(body, root)
	local scale = body:GetModelScale() or 1
	local scaleVec = Vector(scale, scale, scale)
	local minY, maxY, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for i = 0, boneCount - 1 do
		local world = body:GetBoneMatrix(i)
		local lm, hm = localMats[i], hiddenMats[i]
		if world then
			local pos, ang = WorldToLocal(world:GetTranslation(), world:GetAngles(), root, frameAng)
			lm:Identity()
			lm:SetAngles(ang)
			lm:SetTranslation(pos)
			lm:Scale(scaleVec)
			if pos.y < minY then minY = pos.y end
			if pos.y > maxY then maxY = pos.y end
			if pos.z < minZ then minZ = pos.z end
			if pos.z > maxZ then maxZ = pos.z end
		else
			lm:Identity()
			lm:Scale(zeroScale)
		end
		hm:Set(lm)
		hm:Scale(zeroScale)
	end
	if minY > maxY then return end

	return (minY + maxY) * 0.5, (minZ + maxZ) * 0.5, math_max(maxY - minY, maxZ - minZ) * 0.5 + CFG.PAD
end

local function headClipPlane(body, root)
	local head, neck = localMats[ids.head], ids.neck and localMats[ids.neck]
	if not head or not neck then return end

	local headPos, neckPos = head:GetTranslation(), neck:GetTranslation()
	local up = headPos - neckPos
	if up:Length() < 0.01 then return end
	up:Normalize()

	local lift, face = 2, Vector(1, 0, 0)
	local attachment = ids.eyes and body:GetAttachment(ids.eyes)
	if attachment then
		local eyes = WorldToLocal(attachment.Pos, angle_zero, root, frameAng)
		local offset = eyes - headPos
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

local function setColor(r, g, b)
	local luma = r * 0.299 + g * 0.587 + b * 0.114
	render.SetColorModulation(r + (luma - r) * displayGray, g + (luma - g) * displayGray, b + (luma - b) * displayGray)
end

local function drawPass(visible, r, g, b)
	passVisible = visible
	setColor(r, g, b)
	proxy:InvalidateBoneCache()
	proxy:DrawModel()
end

local function drawHeadSplit(normal, distance)
	local previous = render.EnableClipping(true)
	render.PushCustomClipPlane(normal, distance)
	local r, g, b = keyColor(skullKey)
	drawPass(skullVisible, r, g, b)
	render.PopCustomClipPlane()

	render.PushCustomClipPlane(-normal, -distance)
	r, g, b = keyColor(jawKey)
	drawPass(jawVisible, r, g, b)
	render.PopCustomClipPlane()
	render.EnableClipping(previous)
end

local function panelRect()
	local size = ScrH() * K.CFG.PANEL_SIZE_FRACTION
	local x = ScrH() * K.CFG.PANEL_MARGIN_FRACTION + size * 0.5
	local y = ScrH() * 0.5
	if hg.MoodlesEnabled and not hg.MoodlesEnabled() then
		local face = hg.SimpleHealth and hg.SimpleHealth.Config.face
		local faceSize = ScrH() * (face and face.size or 0.075)
		local margin = ScrH() * (face and face.y or 0.012)
		x = ScrW() * 0.5
		y = ScrH() - margin * 2 - faceSize - size * 0.5
	end
	if hg.HudEdit then
		local ox, oy = hg.HudEdit.Offset("subrosa")
		x, y = x + ox, y + oy
		hg.HudEdit.Rect("subrosa", x - size * 0.5, y - size * 0.5, size, size)
	end

	return math.floor(x - size * 0.5), math.floor(y - size * 0.5), math.floor(size)
end

local function getBodyEntity(ply)
	local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
	if IsValid(body) and body ~= ply then return body end
	if ply:GetNWBool("FakeGettingUp", false) and IsValid(ply.OldRagdoll) then return ply.OldRagdoll end

	return ply
end

local function drawModelStatus(alpha)
	local ply = LocalPlayer()
	local body = getBodyEntity(ply)
	if not IsValid(body) or body:IsDormant() or not getProxy(body) then return end

	local root = bonePos(body, ids.pelvis) or body:GetPos()
	local now = CurTime()
	local snap = body ~= lastBody or now - lastDrawTime > K.CFG.SNAP_AFTER_HIDDEN
	lastBody, lastDrawTime = body, now

	local yaw = targetYaw(body)
	local dt = FrameTime()
	if snap then
		smoothYaw = yaw
	else
		smoothYaw = math.NormalizeAngle(smoothYaw + math.AngleDifference(yaw, smoothYaw) * (1 - math_exp(-dt * CFG.YAW_SMOOTH)))
	end
	frameAng.y = smoothYaw

	local cy, cz, half = updateLocalMatrices(body, root)
	if not cy then return end
	if snap then
		centerY, centerZ, halfExtent = cy, cz, half
	else
		local blend = 1 - math_exp(-dt * CFG.FRAME_SMOOTH)
		centerY = centerY + (cy - centerY) * blend
		centerZ = centerZ + (cz - centerZ) * blend
		halfExtent = halfExtent + (half - halfExtent) * blend
	end

	if snap or now >= nextMedicalUpdate then
		updateMedicalState(ply, body)
		nextMedicalUpdate = now + K.CFG.MEDICAL_UPDATE_INTERVAL
	end
	updateDisplayState(ply)
	if displayFade < 0.01 then return end

	local x, y, size = panelRect()
	cam.Start({
		type = "3D",
		x = x, y = y, w = size, h = size,
		origin = Vector(500, centerY, centerZ),
		angles = Angle(0, 180, 0),
		ortho = {left = -halfExtent, right = halfExtent, top = -halfExtent, bottom = halfExtent},
		znear = 1, zfar = 1000,
	})
	render.ClearDepth()
	render.SuppressEngineLighting(true)
	render.ResetModelLighting(CFG.AMBIENT, CFG.AMBIENT, CFG.AMBIENT)
	render.SetModelLighting(BOX_FRONT, CFG.KEY_LIGHT, CFG.KEY_LIGHT, CFG.KEY_LIGHT)
	render.SetModelLighting(BOX_TOP, CFG.TOP_LIGHT, CFG.TOP_LIGHT, CFG.TOP_LIGHT)
	render.MaterialOverride(whiteMat)
	render.SetBlend(alpha * displayFade)

	local ok, err = pcall(function()
		for index = 1, groupCount do
			local group = groups[index]
			drawPass(group.visible, group.r, group.g, group.b)
		end
		if splitHead and ids.head then
			local normal, distance = headClipPlane(body, root)
			if normal then drawHeadSplit(normal, distance) else drawPass(skullVisible, keyColor(skullKey)) end
		end
	end)

	passVisible = nil
	render.SetBlend(1)
	render.MaterialOverride()
	render.SetColorModulation(1, 1, 1)
	render.SuppressEngineLighting(false)
	cam.End()
	if not ok then ErrorNoHalt(err, "\n") end
end

hook.Add("HUDPaint", "homigrad/body-status-model/draw", function()
	if not hg.SimpleSubRosaEnabled() then return end

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	local alpha = hg.DeathHUDAlpha and hg.DeathHUDAlpha() or 1
	if alpha <= 0 then return end

	local ok, err = pcall(drawModelStatus, alpha)
	if not ok then ErrorNoHalt(err, "\n") end
end)
