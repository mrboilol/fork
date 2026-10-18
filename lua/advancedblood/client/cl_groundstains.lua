-- Ground impact stains.
-- A droplet that lands on a floor-like world surface leaves a stain drawn by ABL itself (not an
-- engine decal), so the number of ground stains is strictly capped and the oldest are removed.
-- The stain comes from the impact:
--   * class from drop size, splash parameter K and impact angle: tiny spot, normal drop (smoother
--     to more scalloped as K rises), large impact with spines and satellites, elongated glancing
--     stain along the direction of travel, or a soaked stain on absorbent floors,
--   * size from the physical stain diameter (drop volume and spread at that impact speed),
--   * orientation: along the travel direction for glancing impacts, random otherwise.
-- Each stain lies in the surface plane at the impact point, a hair above it. Its footprint is
-- checked against the floor with short traces (no hanging over ledges, no floating over bumps);
-- if it does not fit it is shrunk. Variant, size, rotation, mirroring, opacity and tone vary per
-- stain, and variants are drawn from shuffled bags, so neighbouring stains never repeat.
-- Stains are batched into a few static meshes per area. Their colour ages from fresh and wet
-- (with a view-dependent reflection) to dried brown. Nothing here creates entities.

ABL.NoJIT()
ABL.Ground = ABL.Ground or {}
local G = ABL.Ground
local C, L, M = ABL.Config, ABL.LOD, ABL.Mat
local GC = C.Ground
local sqrt, min, max, abs, floor, cos, sin = math.sqrt, math.min, math.max, math.abs, math.floor, math.cos, math.sin

------------------------------------------------------------------------------------------
-- Atlas (tools/texgen: 8x4 cells of 256 px with a 6 px margin, 2048x1024)
------------------------------------------------------------------------------------------
local function CellUV(i)
	local cx, cy = i % 8, floor(i / 8)
	local mu, mv = 6 / 2048, 6 / 1024
	return cx / 8 + mu, cy / 4 + mv, (cx + 1) / 8 - mu, (cy + 1) / 4 - mv
end

-- frac: radius of the main stain in cell half-widths (elongated: half-width of the main ellipse);
-- reach: how far (in half-widths) its satellites / tail extend, for the footprint check
local FAM = {
	tiny   = { first = 0, n = 8, frac = 0.30, reach = 0.45 },
	drop   = { first = 8, n = 8, frac = 0.53, reach = 0.62 },
	splat  = { first = 16, n = 8, frac = 0.34, reach = 0.8 },
	elong  = { first = 24, n = 3, frac = 0.40 / 1.85, ratio = 1.85, reach = 0.8, shift = 0.28 },
	elong2 = { first = 27, n = 2, frac = 0.40 / 3.0, ratio = 3.0, reach = 0.8, shift = 0.28 },
	soak   = { first = 29, n = 3, frac = 0.52, reach = 0.6 },
}

-- Shuffled bag per family: every variant is used once before any repeats, never twice in a row.
local bags = {}
local function Variant(name, rng, lo, hi)
	local f = FAM[name]
	lo, hi = lo or 0, hi or (f.n - 1)
	local key = name .. lo .. ":" .. hi
	local bag = bags[key]
	if not bag or #bag.list == 0 then
		local list = {}
		for i = lo, hi do list[#list + 1] = i end
		for i = #list, 2, -1 do
			local j = 1 + floor(rng:Next() * i)
			list[i], list[j] = list[j], list[i]
		end
		if bag and #list > 1 and list[#list] == bag.last then list[1], list[#list] = list[#list], list[1] end
		bag = { list = list, last = bag and bag.last }
		bags[key] = bag
	end
	local v = table.remove(bag.list)
	bag.last = v
	return f.first + v
end

------------------------------------------------------------------------------------------
-- Stains, chunks, cap
------------------------------------------------------------------------------------------
local chunks = {}          -- all chunks (draw order)
local open = {}            -- spatial key -> chunk that still accepts stains
local count = 0            -- live stains
local fifo, head, tail = {}, 1, 0
local crowd = {}           -- 2.5-unit cell -> { n, last, t } (many drops on one spot)
local CHUNK_SIZE, CHUNK_MAX = 192, 96
G.stats = { placed = 0, removed = 0, shrunk = 0, merged = 0, skipped = 0 }

function G.Count() return count end

local function Chunk(x, y, z)
	local key = ABL.CellKey(x, y, z, CHUNK_SIZE)
	local c = open[key]
	if not c or #c.items >= CHUNK_MAX then
		c = { key = key, items = {}, live = 0, mesh = nil, sheen = nil, dirty = true, nextBuild = 0, nextAge = 0,
			x = x, y = y, z = z, rad = 1, nx = 0, ny = 0, nz = 1, youngest = 0 }
		open[key] = c
		chunks[#chunks + 1] = c
	end
	return c
end

local function Kill(s)
	if s.dead then return end
	s.dead = true
	count = count - 1
	local c = s.chunk
	c.live = c.live - 1
	c.dirty = true
	G.stats.removed = G.stats.removed + 1
end

function G.Near(x, y, z, nx, ny, nz, R, eat)
	local n, w, sx, sy, sz = 0, 0, 0, 0, 0
	local R2 = R * R
	for i = head, tail do
		local s = fifo[i]
		if s and not s.dead and s.nx * nx + s.ny * ny + s.nz * nz > 0.9 then
			local dx, dy, dz = s.x - x, s.y - y, s.z - z
			if abs(dx * nx + dy * ny + dz * nz) < 3 and dx * dx + dy * dy + dz * dz < R2 then
				local a = s.h * s.h
				n, w = n + 1, w + a
				sx, sy, sz = sx + s.x * a, sy + s.y * a, sz + s.z * a
				if eat and eat(s.x, s.y, s.z, a, s.h) then Kill(s) end
			end
		end
	end
	if w <= 0 then return 0, 0 end
	return n, w, sx / w, sy / w, sz / w
end

-- Over the cap: remove the oldest, preferring one that is out of view among the oldest few.
local function RemoveOldest()
	while head <= tail and (fifo[head] == nil or fifo[head].dead) do fifo[head] = nil head = head + 1 end
	local pick, seen = nil, 0
	for i = head, tail do
		local s = fifo[i]
		if s and not s.dead then
			seen = seen + 1
			pick = pick or s
			local _, vis = L.View(s.x, s.y, s.z, s.h)
			if not vis then pick = s break end
			if seen >= 10 then break end
		end
	end
	if pick then Kill(pick) end
end

local function Add(s)
	local c = Chunk(s.x, s.y, s.z)
	s.chunk = c
	c.items[#c.items + 1] = s
	c.live = c.live + 1
	c.dirty = true
	count = count + 1
	tail = tail + 1
	fifo[tail] = s
	G.stats.placed = G.stats.placed + 1
	local cap = L.Cap(C.cl.maxGround)
	while count > cap do RemoveOldest() end
end

------------------------------------------------------------------------------------------
-- Footprint check: the stain must lie on the floor it landed on
------------------------------------------------------------------------------------------
local trOut = {}
local tr = { mask = MASK_SOLID, output = trOut, filter = ABL.Surface.ProbeFilter }
local vA, vB = Vector(), Vector()

-- Probes the surface at four points around the stain. Returns ok, highest bump (units above the
-- plane) or nil when out of trace budget.
local function Fits(x, y, z, nx, ny, nz, ux, uy, uz, vx, vy, vz, r)
	local up = 0
	for k = 1, 4 do
		if not L.TakeTrace() then return nil end
		local a = (k == 1 and r) or (k == 2 and -r) or 0
		local b = (k == 3 and r) or (k == 4 and -r) or 0
		local px, py, pz = x + ux * a + vx * b, y + uy * a + vy * b, z + uz * a + vz * b
		vA:SetUnpacked(px + nx, py + ny, pz + nz)
		vB:SetUnpacked(px - nx * 1.2, py - ny * 1.2, pz - nz * 1.2)
		tr.start, tr.endpos = vA, vB
		util.TraceLine(tr)
		if not trOut.Hit or trOut.StartSolid then return false end
		local hn, hp = trOut.HitNormal, trOut.HitPos
		if hn.x * nx + hn.y * ny + hn.z * nz < 0.85 then return false end
		local dev = (hp.x - x) * nx + (hp.y - y) * ny + (hp.z - z) * nz
		if dev > 0.3 or dev < -0.3 then return false end
		if dev > up then up = dev end
	end
	return true, up
end

local function OnFloor(x, y, z, nx, ny, nz)
	if not L.TakeTrace() then return false end
	vA:SetUnpacked(x + nx, y + ny, z + nz)
	vB:SetUnpacked(x - nx * 1.2, y - ny * 1.2, z - nz * 1.2)
	tr.start, tr.endpos = vA, vB
	util.TraceLine(tr)
	if not trOut.Hit or trOut.StartSolid or not trOut.HitWorld then return false end
	local hn = trOut.HitNormal
	return hn.x * nx + hn.y * ny + hn.z * nz > 0.85
end

------------------------------------------------------------------------------------------
-- Placement
------------------------------------------------------------------------------------------
local pending = {}         -- impacts waiting for trace budget
local tokens, lastRefill = 0, 0

local function Place(q)
	local nx, ny, nz = q.nx, q.ny, q.nz
	local f = FAM[q.fam]
	local h, hu = q.h, q.hu
	local ux, uy, uz, vx, vy, vz = q.ux, q.uy, q.uz, q.vx, q.vy, q.vz
	-- centre of the quad (an elongated stain's body sits on the impact point, its tail ahead)
	local shift = (f.shift or 0) * hu
	local cx, cy, cz = q.x + ux * shift, q.y + uy * shift, q.z + uz * shift
	local up = 0
	local reach = max(h * f.frac * 1.1, hu * f.reach)
	if reach > 0.45 then
		local ok, bump = Fits(cx, cy, cz, nx, ny, nz, ux, uy, uz, vx, vy, vz, reach)
		if ok == nil then return false end
		if not ok then
			-- does not fit (a ledge, a step, a bump): a smaller stain around the impact point
			local s = 0.55
			h, hu, reach, shift = h * s, hu * s, reach * s, shift * s
			cx, cy, cz = q.x + ux * shift, q.y + uy * shift, q.z + uz * shift
			G.stats.shrunk = G.stats.shrunk + 1
			if reach > 0.45 then
				ok, bump = Fits(cx, cy, cz, nx, ny, nz, ux, uy, uz, vx, vy, vz, reach)
				if ok == nil then return false end
				if not ok then
					-- right on an edge: only a small spot around the impact point itself
					local k = 0.4 / reach
					h, hu, shift = h * k, hu * k, shift * k
					cx, cy, cz = q.x + ux * shift, q.y + uy * shift, q.z + uz * shift
					bump = 0
					G.stats.skipped = G.stats.skipped + 1
				end
			end
		end
		up = bump or 0
	end
	local u0, v0, u1, v1 = CellUV(q.cell)
	if q.flip then v0, v1 = v1, v0 end
	local off = GC.offset + up + q.jit
	local s = {
		x = cx + nx * off, y = cy + ny * off, z = cz + nz * off, nx = nx, ny = ny, nz = nz,
		ux = ux * hu, uy = uy * hu, uz = uz * hu, vx = vx * h, vy = vy * h, vz = vz * h, h = max(h, hu), h0 = h, vol = q.vol,
		u0 = u0, v0 = v0, u1 = u1, v1 = v1,
		alpha = q.alpha, tone = q.tone, tg = q.tg, born = CurTime(), dryT = q.dryT,
	}
	Add(s)
	if q.crowd then q.crowd.last = s end
	return true
end

-- Blood that lands on a spot already covered by several stains, or on one that is still wet, adds
-- to them instead of piling up more quads: the newest one there grows by the blood's volume (its
-- area with the volume it holds, to twice its first size) and is wet again.
local function Crowded(x, y, z, wet, vol)
	local k = ABL.CellKey(x, y, z, 2.5)
	local now = CurTime()
	local e = crowd[k]
	if not e or now - e.t > 30 then
		e = { n = 0, t = now }
		crowd[k] = e
	end
	e.t = now
	if (e.n >= GC.cellCap or wet) and e.last and not e.last.dead then
		local s = e.last
		local sv = s.vol or 0.01
		local g = min(sqrt((sv + vol) / sv), s.h0 * 2 / s.h, GC.maxHalf / s.h)
		s.vol = sv + vol
		if g > 1.001 then
			s.ux, s.uy, s.uz, s.vx, s.vy, s.vz = s.ux * g, s.uy * g, s.uz * g, s.vx * g, s.vy * g, s.vz * g
			s.h = s.h * g
		end
		s.born = now
		s.alpha = min(255, s.alpha * 1.04)
		s.chunk.dirty = true
		G.stats.merged = G.stats.merged + 1
		return true, e
	end
	e.n = e.n + 1
	return false, e
end

local function Queue(q)
	if not Place(q) then
		if #pending >= 48 then table.remove(pending, 1) end
		pending[#pending + 1] = q
	end
end

-- A droplet hit a floor-like world surface.
--   vol: ml, stainD: stain diameter (units) for this drop at this impact speed, sinA: impact
--   angle sine, tx..: downstream direction in the surface plane (nil for a vertical impact),
--   K: splash parameter, surf: surface category, rng: seeded RNG, wetT: seconds to dry.
function G.Impact(x, y, z, nx, ny, nz, vol, stainD, sinA, tx, ty, tz, K, surf, rng, wetT, wet)
	-- rate limit: a burst of spatter places at most `rate` stains per second
	local rt = RealTime()
	tokens = min(GC.rate * 0.5, tokens + (rt - lastRefill) * GC.rate)
	lastRefill = rt
	if tokens < 1 then return end
	tokens = tokens - 1

	local IC = C.Impact
	local fam, cell
	local R = stainD * 0.5 * rng:Range(0.9, 1.12)
	local elong = 1
	if surf.soak then
		fam = "soak"
	elseif stainD < GC.tinyD or vol < 0.004 then
		fam = "tiny"
	elseif tx and sinA < 0.82 then
		elong = math.Clamp(1 / max(sinA, 0.2), 1.2, 5)
		fam = elong > 2.4 and "elong2" or "elong"
	elseif K > IC.kCrown or vol > 0.15 then
		fam = "splat"
	else
		fam = "drop"
	end
	if fam == "drop" then
		-- a harder landing crenates the edge: pick among the rougher variants as K rises
		local t = math.Clamp((K - IC.kDeposit) / (IC.kCrown - IC.kDeposit), 0, 1)
		local lo = min(5, floor(t * 5))
		cell = Variant("drop", rng, lo, min(7, lo + 3))
	else
		cell = Variant(fam, rng)
	end

	local crowded, ce = Crowded(x, y, z, wet, vol)
	if crowded then return end

	local f = FAM[fam]
	R = max(R, fam == "tiny" and 0.06 or 0.12)
	local h = R / f.frac
	local hu = h
	if f.ratio then
		-- the texture carries the elongation; a slight stretch matches the exact angle
		hu = h * math.Clamp(elong / f.ratio, 0.87, 1.4)
	end
	if h > GC.maxHalf then hu = hu * GC.maxHalf / h h = GC.maxHalf end

	-- in-plane axes: +u along travel (or at a random angle), +v across; mirrored at random
	local ux, uy, uz
	if f.ratio then
		local a = rng:Range(-0.07, 0.07)
		local px, py, pz = ny * tz - nz * ty, nz * tx - nx * tz, nx * ty - ny * tx
		ux, uy, uz = ABL.Norm(tx * cos(a) + px * sin(a), ty * cos(a) + py * sin(a), tz * cos(a) + pz * sin(a))
	else
		local sx, sy, sz = ABL.Perp(nx, ny, nz)
		local qx, qy, qz = ny * sz - nz * sy, nz * sx - nx * sz, nx * sy - ny * sx
		local a = rng:Next() * 6.2831853
		ux, uy, uz = sx * cos(a) + qx * sin(a), sy * cos(a) + qy * sin(a), sz * cos(a) + qz * sin(a)
	end
	local vx, vy, vz = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux

	local q = {
		x = x, y = y, z = z, nx = nx, ny = ny, nz = nz, ux = ux, uy = uy, uz = uz, vx = vx, vy = vy, vz = vz,
		fam = fam, cell = cell, h = h, hu = hu, flip = rng:Next() < 0.5, vol = vol,
		-- a fresh film of whole blood is nearly opaque; the texture keeps the thin rim translucent
		alpha = 255 * (0.6 + 0.4 * (surf.alpha or 1)) * rng:Range(0.92, 1) * (fam == "tiny" and 0.94 or 1),
		-- per-stain variation of the filter: darker (venous) to brighter red, a little more or less
		-- saturated, so neighbouring stains never share one colour
		tone = rng:Range(C.ToneRange[1], 1), tg = rng:Range(0.9, 1.1), jit = rng:Next() * 0.02,
		dryT = max(8, (wetT or 60) * 2 * C.sv.drying:GetFloat()), crowd = ce,
	}
	Queue(q)
	ABL.BloodMap.Add(x, y, z, nx, ny, nz, max(R, hu * f.frac), q.alpha / 255, wetT or 60)

	if f.ratio and sinA < 0.55 and vol > 0.008 then
		local n = min(4, floor((0.55 - sinA) * 9 + rng:Next()))
		local d = (f.shift + 0.75) * hu
		local r = R * 0.38
		for _ = 1, n do
			d = d + r * rng:Range(2.2, 3.6)
			local side = rng:Range(-0.12, 0.12) * r
			local px, py, pz = x + ux * d + vx * side, y + uy * d + vy * side, z + uz * d + vz * side
			if not OnFloor(px, py, pz, nx, ny, nz) then break end
			G.Impact(px, py, pz, nx, ny, nz, vol * 0.04, r * 2, 1, nil, nil, nil, IC.kDeposit, surf, rng, wetT)
			r = r * rng:Range(0.6, 0.8)
		end
	end
end

-- Fallback particles that land on a floor leave a tiny spot (no footprint check needed).
function G.Tiny(x, y, z, nx, ny, nz, vol, rng)
	rng = rng or ABL.RNG(floor(abs(x * 7 + y * 13 + z * 3)) + 1)
	G.Impact(x, y, z, nx, ny, nz, vol or 0.003, 0.16, 1, nil, nil, nil, 30, C.Surfaces.default, rng, 20)
end

-- Deferred placements (trace budget) and crowd bookkeeping.
local nextGC = 0
function G.Think()
	local i = 1
	while i <= #pending do
		if Place(pending[i]) then table.remove(pending, i) else break end
	end
	local now = CurTime()
	if now > nextGC then
		nextGC = now + 10
		for k, e in pairs(crowd) do
			if now - e.t > 30 then crowd[k] = nil end
		end
	end
end

------------------------------------------------------------------------------------------
-- Rendering
------------------------------------------------------------------------------------------
local vec = Vector()
local function V(x, y, z, u, v, r, g, b, a)
	vec:SetUnpacked(x, y, z)
	mesh.Position(vec)
	mesh.TexCoord(0, u, v)
	mesh.Color(r, g, b, a)
	mesh.AdvanceVertex()
end

local function Quad(s, r, g, b, a)
	local x, y, z = s.x, s.y, s.z
	local ux, uy, uz, vx, vy, vz = s.ux, s.uy, s.uz, s.vx, s.vy, s.vz
	V(x - ux - vx, y - uy - vy, z - uz - vz, s.u0, s.v0, r, g, b, a)
	V(x + ux - vx, y + uy - vy, z + uz - vz, s.u1, s.v0, r, g, b, a)
	V(x + ux + vx, y + uy + vy, z + uz + vz, s.u1, s.v1, r, g, b, a)
	V(x - ux + vx, y - uy + vy, z - uz + vz, s.u0, s.v1, r, g, b, a)
end

-- fresh (wet) -> drying -> dried: filter multipliers (linear), wetness (0..1) and age fraction
local function Age(s, now)
	local k = math.Clamp((now - s.born) / s.dryT, 0, 1)
	local mr, mg, mb = ABL.Render.FilterAge(k, GC.agingK)
	return mr * s.tone, mg * (s.tg or 1), mb, math.Clamp(1 - k / 0.5, 0, 1), k
end

local function Build(c, now)
	if c.mesh then c.mesh:Destroy() c.mesh = nil end
	if c.sheen then c.sheen:Destroy() c.sheen = nil end
	c.dirty = false
	-- compact
	local items, j = c.items, 0
	for i = 1, #items do
		local s = items[i]
		if not s.dead then j = j + 1 items[j] = s end
	end
	for i = j + 1, #items do items[i] = nil end
	if j == 0 then return end
	local R = ABL.Render
	local sx, sy, sz, anx, any, anz, young, wet = 0, 0, 0, 0, 0, 0, 0, 0
	local m = Mesh()
	mesh.Begin(m, MATERIAL_QUADS, j)
	for i = 1, j do
		local s = items[i]
		-- a filter needs no lighting: the floor under it is already lit
		local mr, mg, mb, w, k = Age(s, now)
		Quad(s, R.FilterColor(mr, mg, mb, s.alpha / 255 * (1 - 0.06 * k)))
		s.wet = w
		if w > 0 then wet = wet + 1 end
		sx, sy, sz = sx + s.x, sy + s.y, sz + s.z
		anx, any, anz = anx + s.nx, any + s.ny, anz + s.nz
		if s.born > young then young = s.born end
	end
	mesh.End()
	c.mesh = m
	c.x, c.y, c.z = sx / j, sy / j, sz / j
	c.nx, c.ny, c.nz = ABL.Norm(anx, any, anz)
	local rad = 0
	for i = 1, j do
		local s = items[i]
		local d = sqrt((s.x - c.x) ^ 2 + (s.y - c.y) ^ 2 + (s.z - c.z) ^ 2) + s.h * 1.42
		if d > rad then rad = d end
	end
	c.rad = rad
	c.youngest = young
	c.wetCount = wet
	c.sheenK = -1
end

-- The wet stains again for the reflection pass. Its strength (view angle, surroundings' light)
-- is baked into the vertex colours; it is rebuilt when that strength changes noticeably.
local function BuildSheen(c, k, lr, lg, lb)
	if c.sheen then c.sheen:Destroy() c.sheen = nil end
	c.sheenK = k
	if (c.wetCount or 0) == 0 then return end
	local m = Mesh()
	mesh.Begin(m, MATERIAL_QUADS, c.wetCount)
	for _, s in ipairs(c.items) do
		if not s.dead and (s.wet or 0) > 0 then
			local w = s.wet * k * 255
			Quad(s, w * lr, w * lg, w * lb, s.alpha)
		end
	end
	mesh.End()
	c.sheen = m
end

local sheenOff = Vector()
local sheenMat = Matrix()
local sheenList = {}
-- developer: 1 no reflection pass, 2 no filter pass
local cvDebug = CreateClientConVar("abl_ground_debug", "0", false, false, "Ground stain debugging bitmask (1 no reflection, 2 no filter).")

function G.Draw()
	local now, rt = CurTime(), RealTime()
	local maxD = min(C.cl.drawDist:GetFloat(), GC.drawDist)
	local builds, set, ns = 0, false, 0
	local dbg = cvDebug:GetInt()
	local noGloss, noFilter = not GC.gloss or bit.band(dbg, 1) ~= 0, bit.band(dbg, 2) ~= 0
	for i = #chunks, 1, -1 do
		local c = chunks[i]
		if c.live <= 0 then
			if c.mesh then c.mesh:Destroy() end
			if c.sheen then c.sheen:Destroy() end
			if open[c.key] == c then open[c.key] = nil end
			table.remove(chunks, i)
		else
			-- colours keep ageing while any stain in the chunk is still drying
			if rt > c.nextAge then
				c.nextAge = rt + 2 + math.random()
				if now - c.youngest < GC.maxDry * C.sv.drying:GetFloat() then c.dirty = true end
			end
			if (c.dirty or not c.mesh) and builds < 4 and rt > c.nextBuild then
				Build(c, now)
				builds = builds + 1
				c.nextBuild = rt + 0.12
			end
			if c.mesh then
				local d2, vis = L.View(c.x, c.y, c.z, c.rad)
				if vis and d2 < (maxD + c.rad) ^ 2 then
					if not noFilter then
						ABL.Render.FilterDraw(M.groundFilter, c.mesh)
						set = true
					end
					if (c.wetCount or 0) > 0 and d2 < 1100 * 1100 and not noGloss then ns = ns + 1 sheenList[ns] = c end
				end
			end
		end
	end
	if set then ABL.Render.EndFilter() end
	-- wet reflection: Fresnel of the view angle times the brightness of the sky it mirrors (a few
	-- times the diffuse light), pattern slid with the view
	if ns > 0 then
		local sm = M.groundGloss
		sheenOff:SetUnpacked((L.eyeX + L.eyeY) / 90 % 1, (L.eyeY - L.eyeZ) / 90 % 1, 0)
		sheenMat:SetTranslation(sheenOff)
		sm:SetMatrix("$detailtexturetransform", sheenMat)
		local sheenBuilds = 0
		for i = 1, ns do
			local c = sheenList[i]
			sheenList[i] = nil
			local dx, dy, dz = c.x - L.eyeX, c.y - L.eyeY, c.z - L.eyeZ
			local d = max(sqrt(dx * dx + dy * dy + dz * dz), 1)
			local cosT = abs(dx * c.nx + dy * c.ny + dz * c.nz) / d
			-- steep views see a faint sheen, grazing views a clear mirror
			local k = min(GC.sheen * ABL.Render.Fresnel(cosT), 0.45)
			c.kNow = k
			if abs(k - (c.sheenK or -1)) > max(0.006, k * 0.2) and sheenBuilds < 3 then
				local lr, lg, lb = ABL.Render.Light(c.x + c.nx * 2, c.y + c.ny * 2, c.z + c.nz * 2)
				BuildSheen(c, k, min(lr, 1.1), min(lg, 1.1), min(lb, 1.1))
				sheenBuilds = sheenBuilds + 1
			end
			if c.sheen and c.sheenK > 0.006 then
				render.SetMaterial(sm)
				c.sheen:Draw()
			end
		end
	end
end

-- Developer (self-test): every chunk's stains, how many are wet, the sheen's strength for this
-- view and the one its mesh was built with.
function G.SheenInfo()
	local t = {}
	for i = 1, #chunks do
		local c = chunks[i]
		t[#t + 1] = string.format("%d stains, %d wet, k %.3f, built with %.3f, normal %.2f %.2f %.2f", #c.items, c.wetCount or 0, c.kNow or -1, c.sheenK or -1, c.nx, c.ny, c.nz)
	end
	return table.concat(t, " | ")
end

function G.Clear()
	for i = #chunks, 1, -1 do
		local c = chunks[i]
		if c.mesh then c.mesh:Destroy() end
		if c.sheen then c.sheen:Destroy() end
		chunks[i] = nil
	end
	for k in pairs(open) do open[k] = nil end
	for k in pairs(crowd) do crowd[k] = nil end
	for i = #pending, 1, -1 do pending[i] = nil end
	fifo, head, tail, count = {}, 1, 0, 0
end
