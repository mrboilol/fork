local decalNames = {
	[MAT_CONCRETE] = "Impact.Concrete",
	[MAT_TILE] = "Impact.Concrete",
	[MAT_PLASTIC] = "Impact.Concrete",
	[MAT_METAL] = "Impact.Metal",
	[MAT_VENT] = "Impact.Metal",
	[MAT_GRATE] = "Impact.Metal",
	[MAT_COMPUTER] = "Impact.Computer",
	[MAT_WOOD] = "Impact.Wood",
	[MAT_FOLIAGE] = "Impact.Wood",
	[MAT_GLASS] = "Impact.Glass",
	[MAT_DIRT] = "Impact.Sand",
	[MAT_SAND] = "Impact.Sand",
	[MAT_GRASS] = "Impact.Sand",
	[MAT_SNOW] = "Impact.Sand",
}

local matCache = {}

local function decalMaterial(name)
	local path = util.DecalMaterial(name)
	if not path or path == "" then path = util.DecalMaterial("Impact.Concrete") end
	if not path or path == "" then return end

	local entry = matCache[path]
	if not entry then
		local mat = Material(path)
		if mat:IsError() then
			entry = false
		else
			local size = (mat:Width() or 0) * (mat:GetFloat("$decalscale") or 1)
			entry = {mat, size > 0 and size or 6}
		end
		matCache[path] = entry
	end

	if not entry then return end
	return entry[1], entry[2]
end

local SIN_45 = math.sqrt(0.5)
local axisX, axisDown = Vector(1, 0, 0), Vector(0, 0, -1)

local function decalBasis(normal)
	if math.abs(normal.z) > SIN_45 then
		local t = axisX:Cross(normal)
		local s = normal:Cross(t)
		s:Normalize()
		t:Normalize()
		return s, t
	end

	local s = normal:Cross(axisDown)
	local t = s:Cross(normal)
	s:Normalize()
	t:Normalize()
	return s, t
end

function EFFECT:Init(data)
	local holes = HG_BulletHoles
	if not holes then return end

	local flags = data:GetFlags()
	local ent = data:GetEntity()
	if bit.band(flags, holes.FLAG_ENTITY) ~= 0 then
		if not IsValid(ent) then return end
	else
		ent = game.GetWorld()
	end

	local pos, normal = data:GetOrigin(), data:GetNormal()
	local dir = pos - data:GetStart()
	if dir:LengthSqr() < 0.0001 then dir = -normal else dir:Normalize() end

	local surf = util.GetSurfaceData(data:GetSurfaceProp())
	local matType = surf and surf.material or MAT_CONCRETE
	local name = decalNames[matType] or "Impact.Concrete"
	local soft = holes.SoftMats[matType]

	local ricochet = bit.band(flags, holes.FLAG_RICOCHET) ~= 0
	local exit = bit.band(flags, holes.FLAG_EXIT) ~= 0
	local scrape = bit.band(flags, holes.FLAG_SCRAPE) ~= 0

	local mat, size = decalMaterial(name)
	if not mat then return end

	local holeScale = math.max(data:GetScale(), 0.2) * (exit and 1.6 or ricochet and 0.8 or 1) * (soft and 1.2 or 1)

	local dot = dir:Dot(normal)
	local tangent = dir - normal * dot
	local tangentLen = tangent:Length()

	local elong = 1
	if not exit and tangentLen > 0.001 then
		tangent:Div(tangentLen)
		elong = math.min(1 / math.Clamp(-dot, 0.05, 1), soft and 1.6 or 4)
		if ricochet or scrape then elong = math.max(elong, 2.5) + 1 end
	end

	local w, h = holeScale, holeScale
	if elong > 1.05 then
		local s, t = decalBasis(normal)
		local ts, tt = tangent:Dot(s), tangent:Dot(t)
		w = holeScale * (1 + (elong - 1) * ts * ts)
		h = holeScale * (1 + (elong - 1) * tt * tt)
		pos = pos - tangent * size * holeScale * (elong - 1) * 0.3
	end

	util.DecalEx(mat, ent, pos, normal, color_white, w, h)
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
