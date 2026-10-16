-- Batched rendering. Every visual that is not an engine decal or a GMod particle goes through
-- these per-material quad batches (one mesh.Begin per material per frame) instead of thousands
-- of individual draw calls. Lighting for unlit materials is sampled on the CPU and cached.

ABL.NoJIT()
ABL.Render = ABL.Render or {}
local R = ABL.Render
local sqrt, floor, min, max = math.sqrt, math.floor, math.min, math.max

local batches = {}    -- IMaterial -> batch
local order = {}      -- materials in first-use order
local tmpVec = Vector()
local MAX_QUADS = 4000

local function GetBatch(mat)
	local b = batches[mat]
	if not b then
		b = { n = 0, d = {} } -- d: 9 numbers per vertex (x,y,z,u,v,r,g,b,a)
		batches[mat] = b
		order[#order + 1] = mat
	end
	return b
end

-- Queue a quad: corners in order (1)-(2)-(3)-(4), uv rect u0,v0 - u1,v1.
function R.Quad(mat, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, r, g, b, a, u0, v0, u1, v1)
	local bt = GetBatch(mat)
	if bt.n >= MAX_QUADS then return end
	u0, v0, u1, v1 = u0 or 0, v0 or 0, u1 or 1, v1 or 1
	local d, o = bt.d, bt.n * 36
	d[o + 1], d[o + 2], d[o + 3], d[o + 4], d[o + 5], d[o + 6], d[o + 7], d[o + 8], d[o + 9] = x1, y1, z1, u0, v0, r, g, b, a
	d[o + 10], d[o + 11], d[o + 12], d[o + 13], d[o + 14], d[o + 15], d[o + 16], d[o + 17], d[o + 18] = x2, y2, z2, u1, v0, r, g, b, a
	d[o + 19], d[o + 20], d[o + 21], d[o + 22], d[o + 23], d[o + 24], d[o + 25], d[o + 26], d[o + 27] = x3, y3, z3, u1, v1, r, g, b, a
	d[o + 28], d[o + 29], d[o + 30], d[o + 31], d[o + 32], d[o + 33], d[o + 34], d[o + 35], d[o + 36] = x4, y4, z4, u0, v1, r, g, b, a
	bt.n = bt.n + 1
end

-- Quad with individual per-corner alpha and v coordinates (used by strips).
function R.StripQuad(mat, ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz, r, g, b, a1, a2, v1, v2)
	local bt = GetBatch(mat)
	if bt.n >= MAX_QUADS then return end
	local d, o = bt.d, bt.n * 36
	d[o + 1], d[o + 2], d[o + 3], d[o + 4], d[o + 5], d[o + 6], d[o + 7], d[o + 8], d[o + 9] = ax, ay, az, 0, v1, r, g, b, a1
	d[o + 10], d[o + 11], d[o + 12], d[o + 13], d[o + 14], d[o + 15], d[o + 16], d[o + 17], d[o + 18] = bx, by, bz, 1, v1, r, g, b, a1
	d[o + 19], d[o + 20], d[o + 21], d[o + 22], d[o + 23], d[o + 24], d[o + 25], d[o + 26], d[o + 27] = cx, cy, cz, 1, v2, r, g, b, a2
	d[o + 28], d[o + 29], d[o + 30], d[o + 31], d[o + 32], d[o + 33], d[o + 34], d[o + 35], d[o + 36] = dx, dy, dz, 0, v2, r, g, b, a2
	bt.n = bt.n + 1
end

-- Planar quad centred at (x,y,z) spanned by half-axes S=(sx,sy,sz) and T=(tx,ty,tz).
function R.PlaneQuad(mat, x, y, z, sx, sy, sz, tx, ty, tz, r, g, b, a)
	R.Quad(mat,
		x - sx - tx, y - sy - ty, z - sz - tz,
		x + sx - tx, y + sy - ty, z + sz - tz,
		x + sx + tx, y + sy + ty, z + sz + tz,
		x - sx + tx, y - sy + ty, z - sz + tz,
		r, g, b, a)
end

-- Camera-facing sprite stretched along direction (ax,ay,az) (unit) by `len`, width `w`.
local camX, camY, camZ = 0, 0, 0
local upX, upY, upZ = 0, 0, 1
function R.SetCamera(pos, ang)
	camX, camY, camZ = pos.x, pos.y, pos.z
	local up = ang:Up()
	upX, upY, upZ = up.x, up.y, up.z
end

function R.Streak(mat, x, y, z, ax, ay, az, len, w, r, g, b, a)
	-- to camera
	local tx, ty, tz = camX - x, camY - y, camZ - z
	-- if no meaningful direction use camera up
	if len <= w then ax, ay, az = upX, upY, upZ len = w end
	-- right = axis x toCam
	local rx, ry, rz = ay * tz - az * ty, az * tx - ax * tz, ax * ty - ay * tx
	local rl = sqrt(rx * rx + ry * ry + rz * rz)
	if rl < 1e-6 then rx, ry, rz = 1, 0, 0 rl = 1 end
	local hw = w * 0.5 / rl
	rx, ry, rz = rx * hw, ry * hw, rz * hw
	local hl = len * 0.5
	local fx, fy, fz = ax * hl, ay * hl, az * hl
	R.Quad(mat,
		x - fx - rx, y - fy - ry, z - fz - rz,
		x - fx + rx, y - fy + ry, z - fz + rz,
		x + fx + rx, y + fy + ry, z + fz + rz,
		x + fx - rx, y + fy - ry, z + fz - rz,
		r, g, b, a)
end

function R.Flush()
	local drawn = 0
	for i = 1, #order do
		local mat = order[i]
		local bt = batches[mat]
		local n = bt.n
		if n > 0 then
			local d = bt.d
			render.SetMaterial(mat)
			mesh.Begin(MATERIAL_QUADS, n)
			for q = 0, n * 4 - 1 do
				local o = q * 9
				tmpVec:SetUnpacked(d[o + 1], d[o + 2], d[o + 3])
				mesh.Position(tmpVec)
				mesh.TexCoord(0, d[o + 4], d[o + 5])
				mesh.Color(d[o + 6], d[o + 7], d[o + 8], d[o + 9])
				mesh.AdvanceVertex()
			end
			mesh.End()
			drawn = drawn + n
			bt.n = 0
		end
	end
	return drawn
end

function R.Discard()
	for i = 1, #order do batches[order[i]].n = 0 end
end

------------------------------------------------------------------------------------------
-- Filter pass: blood as an absorbing film over what is already drawn. The filter textures hold
-- coverage x transmission (premultiplied); with dst * (src + 1 - srcAlpha) the surface under the
-- blood is multiplied by lerp(1, T, coverage), so it shows through thin blood with its own lighting,
-- shadows and detail. Destination alpha is left alone (the engine keeps depth there).
------------------------------------------------------------------------------------------
function R.BeginFilter()
	render.OverrideBlend(true, BLEND_DST_COLOR, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)
end
function R.EndFilter()
	render.OverrideBlend(false)
end
-- Draw a static mesh as a filter. Material and blend state are set for every draw: building a
-- static mesh in between (meshes are rebuilt inside the draw loops) does not keep them.
function R.FilterDraw(mat, m)
	render.SetMaterial(mat)
	render.OverrideBlend(true, BLEND_DST_COLOR, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)
	m:Draw()
end

-- Vertex colour for a filter texture: linear multipliers m (ageing, tone) and opacity f, premultiplied
-- and gamma encoded (vertex colours are read as sRGB, the multiply happens in linear light).
local GAMMA = 1 / 2.2
function R.FilterColor(mr, mg, mb, f)
	if f <= 0 then return 0, 0, 0, 0 end
	return 255 * min(mr * f, 1) ^ GAMMA, 255 * min(mg * f, 1) ^ GAMMA, 255 * min(mb * f, 1) ^ GAMMA, 255 * min(f, 1)
end

-- Ageing multipliers of the filter textures: fresh -> aging at kAging, -> dried at 1 (C.Filter).
function R.FilterAge(k, kAging)
	local F = ABL.Config.Filter
	local a, b, t
	kAging = kAging or 0.45
	if k < kAging then a, b, t = F.fresh, F.aging, k / kAging else a, b, t = F.aging, F.dried, min((k - kAging) / (1 - kAging), 1) end
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- Reflection strength of a wet surface seen at cosT (Schlick, n ~ 1.35 for blood plasma).
function R.Fresnel(cosT)
	local k = 1 - (cosT < 0 and -cosT or cosT)
	return 0.022 + 0.978 * k * k * k * k * k
end

-- Cubemaps baked into the map (materials/maps/<map>/c<x>_<y>_<z>.vtf, packed in the BSP): the one
-- nearest to a wet surface gives it a real reflection of its surroundings. nil on maps without
-- built cubemaps.
local cubemaps
local cubeFrom, cubeTo, cubeOut = Vector(), Vector(), {}
local cubeTrace = { mask = MASK_SOLID_BRUSHONLY, output = cubeOut }
function R.Cubemap(x, y, z)
	if cubemaps == nil then
		cubemaps = false
		local map = game.GetMap()
		local list = {}
		for _, f in ipairs(file.Find("materials/maps/" .. map .. "/c*.vtf", "GAME") or {}) do
			local cx, cy, cz = string.match(f, "^c(%-?%d+)_(%-?%d+)_(%-?%d+)%.vtf$")
			if cx then list[#list + 1] = { tonumber(cx), tonumber(cy), tonumber(cz), "maps/" .. map .. "/" .. string.sub(f, 1, -5) } end
		end
		if #list > 0 then cubemaps = list end
	end
	if not cubemaps then return nil end
	-- The nearest cubemap the point can see: the plain nearest one may sit behind a wall (a pool
	-- outside a building would mirror the dark room inside). The few nearest are tried in order.
	for i = 1, #cubemaps do
		local c = cubemaps[i]
		c[5] = (c[1] - x) ^ 2 + (c[2] - y) ^ 2 + (c[3] - z) ^ 2
	end
	local nearest
	cubeFrom:SetUnpacked(x, y, z)
	cubeTrace.start = cubeFrom
	for _ = 1, min(4, #cubemaps) do
		local best, bd = nil, math.huge
		for i = 1, #cubemaps do
			local c = cubemaps[i]
			if c[5] < bd then bd, best = c[5], c end
		end
		if not best then break end
		best[5] = math.huge
		nearest = nearest or best
		cubeTo:SetUnpacked(best[1], best[2], best[3])
		cubeTrace.endpos = cubeTo
		util.TraceLine(cubeTrace)
		if cubeOut.Fraction > 0.97 then return best[4] end
	end
	return nearest and nearest[4]
end

-- Sun direction (toward the sun) and visibility, nil indoors / on maps without a sun.
local sunT, sunX, sunY, sunZ, sunVis = 0, 0, 0, 1, 0
function R.Sun()
	local now = RealTime()
	if now > sunT then
		sunT = now + 1
		local info = util.GetSunInfo and util.GetSunInfo()
		if info and info.direction then
			sunX, sunY, sunZ = info.direction.x, info.direction.y, info.direction.z
			sunVis = 1 - (info.obstruction or 0)
		else
			sunVis = 0
		end
	end
	if sunVis <= 0 then return nil end
	return sunX, sunY, sunZ, sunVis
end

------------------------------------------------------------------------------------------
-- Lighting cache: approximates what a lightmapped surface would receive at a point so unlit
-- overlays/pools match the engine decals underneath. Values are display-space multipliers.
------------------------------------------------------------------------------------------
local lightCache = {}
local lightCount = 0
local LIGHT_CELL = 24
local lightVec = Vector()

function R.Light(x, y, z)
	local k = ABL.CellKey(x, y, z, LIGHT_CELL)
	local e = lightCache[k]
	local now = RealTime()
	if e and e[4] > now then return e[1], e[2], e[3] end
	lightVec:SetUnpacked(x, y, z)
	local c = render.GetLightColor(lightVec)
	-- linear -> display space (gamma ~2.2), keep a small floor so blood never turns fully black
	local r = min(max(c.x, 0.0006) ^ 0.4545, 1.25)
	local g = min(max(c.y, 0.0006) ^ 0.4545, 1.25)
	local b = min(max(c.z, 0.0006) ^ 0.4545, 1.25)
	if not e then
		e = {}
		lightCache[k] = e
		lightCount = lightCount + 1
		if lightCount > 3000 then
			for kk in pairs(lightCache) do lightCache[kk] = nil end
			lightCount = 0
			lightCache[k] = e
		end
	end
	e[1], e[2], e[3], e[4] = r, g, b, now + 1.5 + math.random() * 0.5
	return r, g, b
end

function R.ClearLight()
	for k in pairs(lightCache) do lightCache[k] = nil end
	lightCount = 0
end
