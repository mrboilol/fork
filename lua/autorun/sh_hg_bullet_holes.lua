AddCSLuaFile()

HG_BulletHoles = HG_BulletHoles or {}

local holes = HG_BulletHoles

holes.FLAG_RICOCHET = 1
holes.FLAG_EXIT = 2
holes.FLAG_SCRAPE = 4
holes.FLAG_ENTITY = 8
holes.IMPACT_NODECAL = 1

holes.SoftMats = {
	[MAT_DIRT] = true,
	[MAT_SAND] = true,
	[MAT_GRASS] = true,
	[MAT_SNOW] = true,
	[MAT_FOLIAGE] = true,
	[MAT_SLOSH] = true,
}

local fleshMats = {
	[MAT_FLESH] = true,
	[MAT_BLOODYFLESH] = true,
	[MAT_ALIENFLESH] = true,
	[MAT_ANTLION] = true,
}

function holes.Handles(tr)
	if not tr or not tr.Hit or tr.HitSky or tr.StartSolid or fleshMats[tr.MatType] then return false end
	if tr.HitWorld then return true end

	local ent = tr.Entity
	if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() or ent:IsRagdoll() then return false end

	local model = ent:GetModel()
	return isstring(model) and model ~= "" and string.sub(model, 1, 1) ~= "*"
end

function holes.SizeFactor(diameter, energy)
	local d = math.Clamp(tonumber(diameter) or 9, 2, 40)
	local e = tonumber(energy) or 0
	local energyMul = e > 0 and math.Clamp((e / 1500) ^ 0.12, 0.85, 1.4) or 1

	return math.Clamp((d / 9) ^ 0.9 * energyMul, 0.35, 4)
end

function holes.Emit(tr, dir, diameter, energy, flags, sizeMul)
	if not SERVER or not tr or not dir then return end

	flags = flags or 0
	if not tr.HitWorld then flags = bit.bor(flags, holes.FLAG_ENTITY) end

	local data = EffectData()
	data:SetOrigin(tr.HitPos)
	data:SetNormal(tr.HitNormal)
	data:SetStart(tr.HitPos - dir * 256)
	data:SetScale(holes.SizeFactor(diameter, energy) * (sizeMul or 1))
	data:SetFlags(flags)
	data:SetSurfaceProp(tr.SurfaceProps or 0)
	data:SetEntity(tr.Entity)
	util.Effect("hg_bullethole", data, true, true)
end
