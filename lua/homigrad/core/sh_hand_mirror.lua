local HAND_GRIP_INSET = 1
local HAND_POS_LIMIT = 38

local flipZ = Matrix({
	{1, 0, 0, 0},
	{0, 1, 0, 0},
	{0, 0, -1, 0},
	{0, 0, 0, 1},
})

function hg.GetMirrorMatrix(origin, normal)
	local offset = normal * (2 * origin:Dot(normal))

	return Matrix({
		{1 - 2 * normal.x * normal.x, -2 * normal.x * normal.y, -2 * normal.x * normal.z, offset.x},
		{-2 * normal.y * normal.x, 1 - 2 * normal.y * normal.y, -2 * normal.y * normal.z, offset.y},
		{-2 * normal.z * normal.x, -2 * normal.z * normal.y, 1 - 2 * normal.z * normal.z, offset.z},
		{0, 0, 0, 1},
	})
end

function hg.IsMirroredMatrix(matrix)
	local a, b, c = matrix:GetField(1, 1), matrix:GetField(1, 2), matrix:GetField(1, 3)
	local d, e, f = matrix:GetField(2, 1), matrix:GetField(2, 2), matrix:GetField(2, 3)
	local g, h, i = matrix:GetField(3, 1), matrix:GetField(3, 2), matrix:GetField(3, 3)

	return a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g) < 0
end

local function unmirroredAngles(matrix)
	return matrix:GetForward():AngleEx(-matrix:GetUp())
end

function hg.GetOffHandMatrix(matrix, normal)
	local origin = matrix:GetTranslation() - normal * HAND_GRIP_INSET
	local mirrored = hg.GetMirrorMatrix(origin, normal) * matrix
	local result = Matrix()
	result:SetTranslation(mirrored:GetTranslation())
	result:SetAngles(unmirroredAngles(mirrored))

	return result
end

function hg.PoseOffHand(source, ent, mirror, center, weight)
	for sourceBone = 0, source:GetBoneCount() - 1 do
		local rightBone = hg.TPIKBonesRHDict[source:GetBoneName(sourceBone)]
		if not rightBone then continue end

		local sourceMatrix = source:GetBoneMatrix(sourceBone)
		local leftBone = string.gsub(rightBone, "_R_", "_L_")
		local bone = ent:LookupBone(leftBone)
		local matrix = bone and ent:GetBoneMatrix(bone)
		if not sourceMatrix or not matrix then continue end
		if not hg.IsMirroredMatrix(sourceMatrix) then
			if not mirror then continue end
			sourceMatrix = mirror * sourceMatrix
		end

		local pos, ang = sourceMatrix:GetTranslation(), unmirroredAngles(sourceMatrix)
		pos.x = math.Clamp(pos.x, center.x - HAND_POS_LIMIT, center.x + HAND_POS_LIMIT)
		pos.y = math.Clamp(pos.y, center.y - HAND_POS_LIMIT, center.y + HAND_POS_LIMIT)
		pos.z = math.Clamp(pos.z, center.z - HAND_POS_LIMIT, center.z + HAND_POS_LIMIT)
		if weight and weight < 1 then
			pos = LerpVector(weight, matrix:GetTranslation(), pos)
			ang = LerpAngle(weight, matrix:GetAngles(), ang)
		end

		matrix:SetTranslation(pos)
		matrix:SetAngles(ang)
		ent:SetBoneMatrix(bone, matrix)
	end
end

if SERVER then return end

function hg.TransformModelBones(model, transform)
	for bone = 0, model:GetBoneCount() - 1 do
		local matrix = model:GetBoneMatrix(bone)
		if matrix then model:SetBoneMatrix(bone, transform * matrix) end
	end
end

function hg.GetOffHandAttachTransform(handMatrix, sourceMatrix)
	return handMatrix * flipZ * sourceMatrix:GetInverse()
end

function hg.SetupMirroredModel(model, baseMatrix, localPos, localAng)
	local offset = Matrix()
	offset:SetTranslation(localPos)
	offset:SetAngles(localAng)

	local root = baseMatrix * offset * flipZ
	local pos, ang = root:GetTranslation(), root:GetAngles()
	model:SetRenderOrigin(pos)
	model:SetRenderAngles(ang)
	model:SetPos(pos)
	model:SetAngles(ang)
	model:InvalidateBoneCache()
	model:SetupBones()

	local frame = Matrix()
	frame:SetTranslation(pos)
	frame:SetAngles(ang)
	hg.TransformModelBones(model, frame * flipZ * frame:GetInverse())
end

function hg.DrawMirroredModel(model)
	render.CullMode(MATERIAL_CULLMODE_CW)
	model:DrawModel()
	render.CullMode(MATERIAL_CULLMODE_CCW)
end
