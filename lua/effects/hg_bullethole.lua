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

local function stamp(name, ent, pos, normal, scale)
	local mat = decalMaterial(name)
	if mat then util.DecalEx(mat, ent, pos, normal, color_white, scale, scale) end
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

	local _, size = decalMaterial(name)
	if not size then return end

	local holeScale = math.max(data:GetScale(), 0.2) * (exit and 1.35 or ricochet and 0.7 or 1) * (soft and 1.2 or 1)
	local unit = size * holeScale

	if not scrape then stamp(name, ent, pos, normal, holeScale) end

	local dot = dir:Dot(normal)
	local tangent = dir - normal * dot
	local tangentLen = tangent:Length()

	if exit then
		local side = tangentLen > 0.001 and tangent / tangentLen or normal:Angle():Right()
		local up = normal:Cross(side)
		for i = 1, 2 do
			local ang = math.Rand(0, math.pi * 2)
			stamp(name, ent, pos + (side * math.cos(ang) + up * math.sin(ang)) * unit * math.Rand(0.2, 0.35), normal, holeScale * math.Rand(0.5, 0.7))
		end
		return
	end

	if tangentLen < 0.001 then return end
	tangent:Div(tangentLen)

	local cosInc = math.Clamp(-dot, 0.05, 1)
	local elong = math.min(1 / cosInc, soft and 1.6 or 5)
	if ricochet then elong = math.max(elong, 2.5) + 1 end
	if elong < 1.25 then return end

	stamp(name, ent, pos + tangent * unit * 0.25 * math.min(elong - 1, 2), normal, holeScale * 0.8)

	local tailLen = math.min(unit * (elong - 1) * 1.1, unit * 6)
	local spacing = unit * 0.38
	local count = math.min(math.floor(tailLen / spacing), 8)

	for i = 1, count do
		local f = i / (count + 1)
		stamp(name, ent, pos - tangent * spacing * i, normal, holeScale * (0.85 - f * 0.6))
	end
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
