local shardModel = "models/gibs/hgibs_rib.mdl"
local drawDistSqr = 1800 * 1800
local burstCooldown = 1.5

local shardLengths = {
	["ValveBiped.Bip01_Pelvis"] = 4,
	["ValveBiped.Bip01_Spine2"] = 4,
	["ValveBiped.Bip01_Neck1"] = 3,
	["ValveBiped.Bip01_L_UpperArm"] = 6,
	["ValveBiped.Bip01_R_UpperArm"] = 6,
	["ValveBiped.Bip01_L_Forearm"] = 5.5,
	["ValveBiped.Bip01_R_Forearm"] = 5.5,
	["ValveBiped.Bip01_L_Thigh"] = 9,
	["ValveBiped.Bip01_R_Thigh"] = 9,
	["ValveBiped.Bip01_L_Calf"] = 7.5,
	["ValveBiped.Bip01_R_Calf"] = 7.5,
}

local tracked = {}
local lastBurst = {}
local shard, shardAxis, shardCenter, shardLength

local function getShard()
	if IsValid(shard) then return shard end
	shard = ClientsideModel(shardModel, RENDERGROUP_OPAQUE)
	if not IsValid(shard) then return end
	shard:SetNoDraw(true)

	local mins, maxs = shard:GetModelBounds()
	local size = maxs - mins
	shardAxis = (size.x >= size.y and size.x >= size.z) and 1 or (size.y >= size.z and 2 or 3)
	shardLength = math.max(size[shardAxis], 0.1)
	shardCenter = (mins + maxs) * 0.5
	return shard
end

local shardMatrix = Matrix()
local function shardAngles(dir, ref)
	local right = dir:Cross(ref)
	if right:LengthSqr() < 0.001 then right = dir:Cross(vector_up) end
	right:Normalize()
	local up = right:Cross(dir)

	if shardAxis == 1 then
		shardMatrix:SetForward(dir)
		shardMatrix:SetRight(right)
		shardMatrix:SetUp(up)
	elseif shardAxis == 2 then
		shardMatrix:SetForward(right)
		shardMatrix:SetRight(-dir)
		shardMatrix:SetUp(up)
	else
		shardMatrix:SetForward(up)
		shardMatrix:SetRight(-right)
		shardMatrix:SetUp(dir)
	end

	return shardMatrix:GetAngles()
end

local function drawShard(mdl, surface, dir, ref, length, embed)
	local scale = length / shardLength
	local ang = shardAngles(dir, ref)
	local center = surface + dir * (length * (0.5 - embed))
	local pos = center - LocalToWorld(shardCenter * scale, angle_zero, vector_origin, ang)

	mdl:SetModelScale(scale, 0)
	mdl:SetPos(pos)
	mdl:SetAngles(ang)
	mdl:SetupBones()
	mdl:DrawModel()
end

local function getFractureBody(ent)
	if not IsValid(ent) or ent:IsDormant() then return end
	if ent:IsPlayer() then
		if not ent:Alive() or IsValid(ent:GetNWEntity("FakeRagdoll")) then return end
		if ent == LocalPlayer() and not ent:ShouldDrawLocalPlayer() then return end
	end
	return ent
end

local rendered = {}

local function getFractureTransform(ent, bone, fx, matrix)
	local boneID = ent:LookupBone(bone)
	if not boneID or ent:GetManipulateBoneScale(boneID):LengthSqr() < 0.1 then return end
	matrix = matrix or ent:GetBoneMatrix(boneID)
	if not matrix or not isvector(fx[1]) or not isangle(fx[2]) then return end

	local offset, normal = hg.organism.ClampWoundOffset(ent, boneID, fx[1], fx[2]:Forward())
	local localAng = normal and normal:Angle() or fx[2]
	if bone == "ValveBiped.Bip01_Pelvis" or bone == "ValveBiped.Bip01_Spine2"
		or bone == "ValveBiped.Bip01_Neck1" then localAng = fx[2] end
	local bonePos, boneAng = matrix:GetTranslation(), matrix:GetAngles()
	local pos, ang = LocalToWorld(offset, localAng, bonePos, boneAng)

	return pos, ang:Forward(), boneAng:Forward()
end

hook.Add("PostDrawAppearance", "hg_openfractures", function(ent)
	if not IsValid(ent) then return end
	local fractures = tracked[ent:EntIndex()]
	if not fractures then return end

	local frame = FrameNumber()
	local entry = rendered[ent]
	if not entry then
		entry = {}
		rendered[ent] = entry
	end
	entry.frame = frame
	for bone in pairs(fractures) do
		local boneID = ent:LookupBone(bone)
		entry[bone] = boneID and ent:GetBoneMatrix(boneID) or nil
	end
end)

local function fractureBurst(ent, bone, fx)
	if not hg.addBloodPart then return end
	ent:SetupBones()
	local pos, normal, along = getFractureTransform(ent, bone, fx)
	if not pos then return end

	for _ = 1, math.random(22, 34) do
		local vel = (normal * math.Rand(0.6, 1) - along * math.Rand(0, 0.4) + VectorRand() * 0.35) * math.Rand(90, 260)
		local size = math.Rand(1.2, 3)
		hg.addBloodPart(pos + normal * 0.5, vel, nil, size, size, true, nil, ent)
	end
end

hook.Add("OnNetVarSet", "hg_openfractures", function(index, key, var)
	if key ~= "openfractures" then return end

	local old = tracked[index]
	tracked[index] = istable(var) and next(var) and var or nil
	if not tracked[index] then return end

	timer.Simple(0, function()
		local ent = getFractureBody(Entity(index))
		if not ent then return end
		local owner = ent:IsRagdoll() and hg.RagdollOwner(ent) or ent
		local ownerKey = IsValid(owner) and owner:EntIndex() or index

		for bone, fx in pairs(var) do
			if old and old[bone] then continue end
			local burstKey = ownerKey .. bone
			if (lastBurst[burstKey] or 0) > CurTime() then continue end
			lastBurst[burstKey] = CurTime() + burstCooldown
			fractureBurst(ent, bone, fx)
		end
	end)
end)

hook.Add("EntityRemoved", "hg_openfractures", function(ent, fullUpdate)
	if fullUpdate then return end
	tracked[ent:EntIndex()] = nil
	rendered[ent] = nil
end)

hook.Add("PostDrawOpaqueRenderables", "hg_openfractures", function(depth, skybox)
	if depth or skybox or not next(tracked) then return end

	local eyePos = EyePos()
	local frame = FrameNumber()
	local mdl

	for index, fractures in pairs(tracked) do
		local ent = getFractureBody(Entity(index))
		if not ent or ent:GetPos():DistToSqr(eyePos) > drawDistSqr then continue end
		local entry = rendered[ent]
		if not entry or entry.frame ~= frame then continue end

		mdl = mdl or getShard()
		if not mdl then return end

		render.SetColorModulation(1, 0.8, 0.76)
		for bone, fx in pairs(fractures) do
			local matrix = entry[bone]
			if not matrix then continue end
			local pos, normal, along = getFractureTransform(ent, bone, fx, matrix)
			if not pos then continue end

			local length = shardLengths[bone] or 6
			drawShard(mdl, pos, (normal - along * 0.55):GetNormalized(), along, length, 0.4)
			drawShard(mdl, pos + along * 1.2, (normal + along * 0.35):GetNormalized(), along, length * 0.6, 0.45)
		end
		render.SetColorModulation(1, 1, 1)
	end
end)

local chestBones = {"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Neck1", "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_R_UpperArm"}
local chestEntries = {}
local maxChestShards = 9

local function getChestOrganism(ent)
	local org = ent.organism or ent.new_organism
	if org then return org end
	local owner = ent:IsRagdoll() and hg.RagdollOwner(ent)
	return IsValid(owner) and (owner.organism or owner.new_organism) or nil
end

hook.Add("PostDrawAppearance", "hg_chestbones", function(ent)
	if not IsValid(ent) then return end
	local org = getChestOrganism(ent)
	if not org or (org.chest or 0) < 0.08 then chestEntries[ent] = nil return end

	local entry = {frame = FrameNumber()}
	for _, bone in ipairs(chestBones) do
		local boneID = ent:LookupBone(bone)
		local matrix = boneID and ent:GetBoneMatrix(boneID)
		if not matrix then chestEntries[ent] = nil return end
		entry[bone] = matrix:GetTranslation()
	end
	chestEntries[ent] = entry
end)

hook.Add("PostDrawOpaqueRenderables", "hg_chestbones", function(depth, skybox)
	if depth or skybox or not next(chestEntries) then return end

	local eyePos = EyePos()
	local frame = FrameNumber()
	local mdl

	for ent, entry in pairs(chestEntries) do
		if not IsValid(ent) then chestEntries[ent] = nil continue end
		if entry.frame ~= frame or ent:GetPos():DistToSqr(eyePos) > drawDistSqr then continue end
		local org = getChestOrganism(ent)
		if not org then continue end
		local count = math.Clamp(math.ceil((org.chest or 0) * maxChestShards), 1, maxChestShards)

		local spine = entry["ValveBiped.Bip01_Spine2"]
		local up = (entry["ValveBiped.Bip01_Neck1"] - spine):GetNormalized()
		local right = (entry["ValveBiped.Bip01_R_UpperArm"] - entry["ValveBiped.Bip01_L_UpperArm"]):GetNormalized()
		local front = up:Cross(right):GetNormalized()

		mdl = mdl or getShard()
		if not mdl then return end

		render.SetColorModulation(1, 0.8, 0.76)
		for i = 1, count do
			local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
			local surface = spine + front * 5.5 + right * ((col - 1) * 2.6 + math.sin(i * 12.9) * 0.8) + up * (row * 2.4 - 2 + math.cos(i * 7.3) * 0.6)
			local dir = (front + right * math.sin(i * 5.1) * 0.5 + up * math.cos(i * 3.7) * 0.5):GetNormalized()
			drawShard(mdl, surface, dir, right, 2.5 + (i % 3) * 0.8, 0.35)
		end
		render.SetColorModulation(1, 1, 1)
	end
end)
