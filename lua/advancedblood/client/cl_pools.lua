-- Pools.
-- Blood that keeps landing on a floor-like surface accumulates until it becomes a pool: one
-- continuous mass whose volume (ml) sets its area (volume / film thickness of the substrate).
-- A pool is a set of field stamps in its own surface frame (see cl_poolatlas.lua and
-- tools/texgen): a body from the family that matches how the blood arrived, plus
--   * arrival lobes where blood reaches the rim (the outline bulges toward new blood),
--   * feeders where runoff flows in, satellite droplets where drops fall in from height,
--   * necks where lobes or merged pools meet (surface tension fills the waist),
--   * clot deposits that form inside thick blood as it ages.
-- Body families: A compact fresh, B large irregular, C thin spreading (smooth floors), D elongated
-- (slopes), E heavy concentrated, F partially dried, G merged multi-source, H drip pool with
-- droplets, I runoff-fed, J old dried stain (also absorbent floors).
-- The stamps are summed and thresholded in a render-target canvas (cl_poolcanvas.lua), so every
-- change re-shapes one continuous outline: the pool spreads (each stamp's spreading field plays
-- the front advancing through its shape), bulges toward arrivals, joins neighbours through a
-- smooth neck, stops straight at walls and ledges (probed, clipped in the canvas), creeps
-- downhill and overflows ledges. It dries from the thin rim toward the thick core (fresh ->
-- ageing -> drying -> dried), darkens and flattens, and finally fades. The mesh under the canvas
-- follows the traced floor relief. Nothing is networked.

ABL.NoJIT()
ABL.Pools = ABL.Pools or {}
local P = ABL.Pools
-- (this file loaded again on its own, as a developer's save does: the pools of the load before
-- are let go first, or their meshes and canvas slots would be held by a list nothing reads)
if P.Clear then pcall(P.Clear) end
local C, L = ABL.Config, ABL.LOD
local PC = C.Pool
local PCV = ABL.PoolCanvas
local sqrt, min, max, abs, cos, sin, atan2, pi, floor, exp = math.sqrt, math.min, math.max, math.abs, math.cos, math.sin, math.atan2, math.pi, math.floor, math.exp
local Clamp = math.Clamp
local TWO_PI = pi * 2
local PS = ABL.PoolSim
local ML = C.ML_PER_CU
local SC = PC.sim

-- A pool made while this is 1 is a liquid on a lattice (cl_poolsim.lua): its blood stands in
-- cells, flows, and the outline is where it has come to. 0: the earlier pools (stamps whose size
-- follows the volume). Satellite spatter is a stamp in both.
local useSim = CreateClientConVar("abl_pool_sim", "1", true, false, "Ground pools as a liquid on a lattice (1) or as the earlier field stamps (0). Applies to pools that form from then on.", 0, 1)

local pools = {}
P.list = pools
P.stats = { created = 0, merged = 0, fed = 0, lobes = 0, sats = 0, necks = 0, paints = 0, paintMs = 0, clips = 0, simDrift = 0 }

------------------------------------------------------------------------------------------
-- Atlas cells
------------------------------------------------------------------------------------------
local cells = ABL.PoolAtlas.cells
local byKind, byFam = {}, {}
for i, c in ipairs(cells) do
	c.id = i
	byKind[c.kind] = byKind[c.kind] or {}
	table.insert(byKind[c.kind], i)
	if c.kind == "body" then
		byFam[c.fam] = byFam[c.fam] or {}
		table.insert(byFam[c.fam], i)
	end
end
P.cells, P.byFam, P.byKind = cells, byFam, byKind

-- Shuffled bags: every variant is used once before any repeats, never twice in a row.
local bags = {}
local function Pick(list, key, rng)
	local bag = bags[key]
	if not bag or #bag.list == 0 then
		local l = {}
		for i = 1, #list do l[i] = list[i] end
		for i = #l, 2, -1 do
			local j = 1 + floor(rng:Next() * i)
			l[i], l[j] = l[j], l[i]
		end
		if bag and #l > 1 and l[#l] == bag.last then l[1], l[#l] = l[#l], l[1] end
		bag = { list = l, last = bag and bag.last }
		bags[key] = bag
	end
	local v = table.remove(bag.list)
	bag.last = v
	return v
end
local function PickKind(kind, rng) return Pick(byKind[kind], kind, rng) end

-- Per family: edge-noise amplitude, opacity, reflection, spreading speed (mature), value
local FAM = {
	A = { noise = 1.0,  opacity = 1.0,  sheen = 1.0,  mature = 1.0, value = 1.0 },
	B = { noise = 1.15, opacity = 1.0,  sheen = 1.0,  mature = 1.2, value = 1.0 },
	C = { noise = 1.3,  opacity = 0.88, sheen = 1.25, mature = 0.7, value = 1.0, thin = true },
	D = { noise = 1.05, opacity = 1.0,  sheen = 1.05, mature = 1.1, value = 1.0 },
	E = { noise = 0.8,  opacity = 1.0,  sheen = 1.1,  mature = 1.4, value = 0.9 },
	F = { noise = 1.0,  opacity = 0.97, sheen = 0.8,  mature = 1.2, value = 1.0 },
	G = { noise = 1.1,  opacity = 1.0,  sheen = 1.0,  mature = 1.3, value = 0.97 },
	H = { noise = 1.0,  opacity = 1.0,  sheen = 1.0,  mature = 0.9, value = 1.0 },
	I = { noise = 1.0,  opacity = 1.0,  sheen = 1.0,  mature = 0.8, value = 1.0 },
	J = { noise = 1.6,  opacity = 0.86, sheen = 0.35, mature = 1.0, value = 1.05, soak = true },
}
local SMOOTH = { tile = true, metal = true, glass = true, plastic = true }

local function Weighted(rng, t)
	local sum = 0
	for _, e in ipairs(t) do sum = sum + e[2] end
	local r = rng:Next() * sum
	for _, e in ipairs(t) do
		r = r - e[2]
		if r <= 0 then return e[1] end
	end
	return t[#t][1]
end

-- The family follows how the blood arrived and what it landed on.
local function ChooseFamily(rng, kind, surf, slope, age)
	-- "fam:X" forces a family (developer gallery / test harness)
	if kind and string.sub(kind, 1, 4) == "fam:" and byFam[string.sub(kind, 5, 5)] then return string.sub(kind, 5, 5) end
	if age and age > 0 then return age > 300 and "J" or "F" end
	if surf.soak then return "J" end
	if slope > PC.slopeCreep then return "D" end
	if kind == "runoff" then return rng:Next() < 0.6 and "I" or "A" end
	if SMOOTH[surf.name] and rng:Next() < 0.55 then return "C" end
	if kind == "seep" then return Weighted(rng, { { "B", 3 }, { "E", 2 }, { "G", 2 }, { "A", 1 } }) end
	if kind == "drip" then return Weighted(rng, { { "A", 3 }, { "H", 2 }, { "E", 1 } }) end
	return Weighted(rng, { { "A", 2 }, { "B", 2 }, { "E", 1 } })
end

------------------------------------------------------------------------------------------
-- Seed accumulation (8-unit cells): pools form where several drops collect
------------------------------------------------------------------------------------------
local seeds = {}
local SEED_CELL = 8

local function SeedAdd(x, y, z, n, vol, surf, ent, kind, dx, dy, dz)
	local k = ABL.CellKey(x, y, z, SEED_CELL)
	local s = seeds[k]
	local now = CurTime()
	if not s then
		s = { vol = 0, sx = 0, sy = 0, sz = 0, w = 0, t = now, t0 = now, kinds = {} }
		seeds[k] = s
	else
		s.tp = s.t
		-- old deposits have dried in place and no longer contribute
		local decay = exp(-(now - s.t) / 45)
		ABL.FlowCore.Move("pool", "dried", s.vol * (1 - decay))
		s.vol, s.sx, s.sy, s.sz, s.w = s.vol * decay, s.sx * decay, s.sy * decay, s.sz * decay, s.w * decay
		for kk, v in pairs(s.kinds) do s.kinds[kk] = v * decay end
		s.t = now
	end
	s.vol = s.vol + vol
	s.sx, s.sy, s.sz, s.w = s.sx + x * vol, s.sy + y * vol, s.sz + z * vol, s.w + vol
	s.nx, s.ny, s.nz = n.x, n.y, n.z
	s.surf, s.ent = surf, ent
	kind = kind or "drip"
	s.kinds[kind] = (s.kinds[kind] or 0) + vol
	if dx then s.dx, s.dy, s.dz = dx, dy, dz end
	return s, k
end

local function SeedKind(s)
	local best, bv = "drip", -1
	for k, v in pairs(s.kinds) do if v > bv then best, bv = k, v end end
	return best
end

------------------------------------------------------------------------------------------
-- Frame, blobs, geometry helpers
------------------------------------------------------------------------------------------
local function Surface(p)
	local gx, gy, gz, gmag = ABL.Gravity()
	local nx, ny, nz = p.nx, p.ny, p.nz
	local gn = gx * nx + gy * ny + gz * nz
	local dx, dy, dz = gx - nx * gn, gy - ny * gn, gz - nz * gn
	local dl = sqrt(dx * dx + dy * dy + dz * dz)
	p.slope = dl / gmag
	if dl > 1e-4 then p.dx, p.dy, p.dz = dx / dl, dy / dl, dz / dl else p.dx, p.dy, p.dz = 0, 0, 0 end
	p.sx, p.sy, p.sz = ABL.Perp(nx, ny, nz)
	p.tx, p.ty, p.tz = ny * p.sz - nz * p.sy, nz * p.sx - nx * p.sz, nx * p.sy - ny * p.sx
	-- downhill in the pool frame
	p.du, p.dv = p.dx * p.sx + p.dy * p.sy + p.dz * p.sz, p.dx * p.tx + p.dy * p.ty + p.dz * p.tz
end

local function ToLocal(p, x, y, z)
	local rx, ry, rz = x - p.x, y - p.y, z - p.z
	return rx * p.sx + ry * p.sy + rz * p.sz, rx * p.tx + ry * p.ty + rz * p.tz
end

local function ToWorld(p, u, v, h)
	h = h or 0
	return p.x + p.sx * u + p.tx * v + p.nx * h, p.y + p.sy * u + p.ty * v + p.ny * h, p.z + p.sz * u + p.tz * v + p.nz * h
end

-- world direction -> angle in the pool frame
local function LocalAngle(p, dx, dy, dz)
	return atan2(dx * p.tx + dy * p.ty + dz * p.tz, dx * p.sx + dy * p.sy + dz * p.sz)
end

local VOLKIND = { body = true, lobe = true, feed = true, neck = true }

local function NewBlob(p, kind, cell, u, v, vol, rot, asp, flip)
	local c = cells[cell]
	local b = {
		kind = kind, cell = cell, u = u, v = v, au = u, av = v, vol = vol or 0, r = 0.15, rt = 0.15,
		rot = rot or 0, asp = asp or 1, flip = flip or false, w = 0.56, hs = 0.15 / c.req,
		born = CurTime(), pr = 0, pw = 0, pu = u, pv = v,
	}
	p.blobs[#p.blobs + 1] = b
	p.dirty = true
	return b
end

-- Current reach of a blob's visible outline from its centre (units): the stamp's farthest point,
-- scaled down while its front is still working through the shape (w < 1).
local function Reach(b)
	local c = cells[b.cell]
	local grow = Clamp((b.w - 0.55) / 0.45, 0, 1)
	return b.hs * c.ext * max(b.asp, 1) * (0.35 + 0.65 * grow)
end

-- Farthest visible point of the pool in local direction (du, dv) from the origin.
local function Extent(p, du, dv)
	if p.sim then return PS.Extent(p.sim, du, dv) end
	local e = 0
	for _, b in ipairs(p.blobs) do
		if VOLKIND[b.kind] then
			local x = b.u * du + b.v * dv + Reach(b)
			if x > e then e = x end
		end
	end
	return e
end

-- Is local point (u, v) inside the pool's visible footprint (within margin)?
local function Covers(p, u, v, margin)
	-- (a liquid pool is exactly where its cells are: blood counts as landing in it on a cell that
	-- holds blood or right beside one, whatever wider margin a stamp pool is asked for)
	if p.sim then return PS.Covers(p.sim, u, v, margin > 0 and min(margin, p.sim.a * 0.75) or margin) or nil end
	for _, b in ipairs(p.blobs) do
		if VOLKIND[b.kind] then
			local du, dv = u - b.u, v - b.v
			local r = Reach(b) * 0.85 + margin
			if r > 0 and du * du + dv * dv < r * r then return b end
		end
	end
	return nil
end

-- Place anchored stamps so the anchor stays where the blood arrived while the stamp grows:
-- elongated and runoff-fed bodies keep their source there (the pool extends downstream), a
-- feeder keeps its mouth just inside the pool (its channel reaches back up the rivulet).
local FEED_MOUTH = 0.62
local function Anchor(b)
	if not b.anchored then return end
	local c = cells[b.cell]
	local ca, sa = cos(b.rot), sin(b.rot)
	local sx, sy
	if b.kind == "feed" then
		sx, sy = (FEED_MOUTH - 0.3) * b.hs * b.asp, 0
	else
		sx, sy = c.sx * b.hs * b.asp, c.sy * b.hs * (b.flip and -1 or 1)
	end
	b.u = b.au - (ca * sx - sa * sy)
	b.v = b.av - (sa * sx + ca * sy)
end

------------------------------------------------------------------------------------------
-- Look: palette, noise offsets, wet state
------------------------------------------------------------------------------------------
local HWMAX = 0.44       -- wet level above the outline at which the thickest core has dried

local function Mix(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

local function MakeLook(p, fam, rng)
	local f = FAM[fam]
	p.look = {
		amp = PC.edgeNoise * f.noise * rng:Range(0.85, 1.15),
		noiseU = rng:Next() * 8, noiseV = rng:Next() * 8, noiseRot = rng:Next() * TWO_PI,
		-- a thick pool is opaque (only its rim film is translucent, see cl_poolcanvas); thin families
		-- and absorbent floors let a little of the surface through
		opacity = f.opacity >= 1 and 1 or f.opacity * (0.6 + 0.4 * (p.surf.alpha or 1)),
		-- value / hue variation between pools: no two share exactly the same colour
		tr = f.value * rng:Range(0.9, 1.07), tg = rng:Range(0.85, 1.15), tb = rng:Range(0.85, 1.15),
		sheen = f.sheen * (p.surf.absorb and (1 - p.surf.absorb) or 1),
		hw = -1, wetMode = "wet", sig = "",
	}
	p.fam = fam
end

-- Wetness state -> thresholds and palettes. Returns true when the look changed enough to repaint.
local function UpdateLook(p, now)
	local lk, pal = p.look, PC.palette
	if p.sim then
		-- a liquid pool is coloured cell by cell (cl_poolcanvas.lua); all that is said here is
		-- whether any of it still mirrors
		local g = p.sim
		local mode = g.wMax < 0.03 and "dry" or (g.wMin > 0.9 and "wet" or "mixed")
		if mode == "wet" then p.dryT = nil else p.dryT = p.dryT or now end
		lk.hw, lk.crack = 0, 0
		if mode ~= lk.wetMode then lk.wetMode = mode return true end
		return false
	end
	local wet = p.wet
	-- the thin rim dries first: while wet > 0.82 all of the pool is wet, then the wet region
	-- retreats through the field's levels toward the thickest core
	local hw = (0.82 - wet) / 0.82 * HWMAX
	if FAM[p.fam].soak then hw = hw + 0.08 end
	local mode = hw <= 0 and "wet" or (hw >= HWMAX and "dry" or "mixed")
	local wetPal = FAM[p.fam].thin and pal.thin or pal.wetFresh
	local ageK = Clamp((1 - wet) * 1.6, 0, 1)
	local wetRim, wetBody = Mix(wetPal.rim, pal.wetAged.rim, ageK), Mix(wetPal.body, pal.wetAged.body, ageK)
	-- time since the rim dried (fresh blood arriving makes the pool wet again)
	if mode == "wet" then p.dryT = nil else p.dryT = p.dryT or now end
	local oldK = p.dryT and Clamp((now - p.dryT) / 400, 0, 1) or 0
	local dryRim, dryBody = Mix(pal.dryFresh.rim, pal.dryOld.rim, oldK), Mix(pal.dryFresh.body, pal.dryOld.body, oldK)
	local dA = Clamp(hw / 0.05, 0, 1)
	lk.rimA, lk.bodyA = Mix(wetRim, dryRim, dA), Mix(wetBody, dryBody, dA)
	lk.rimB, lk.bodyB = wetRim, wetBody
	lk.hw, lk.wetMode = hw, mode
	-- a thick layer that has dried for a while cracks into small plates (craquelure)
	local f = FAM[p.fam]
	lk.crack = (mode == "dry" and not f.soak and not f.thin) and Clamp((oldK - 0.1) / 0.6, 0, 1) * 0.42 or 0
	local sig = string.format("%s%.3f%.2f%.1f%.1f%.1f", mode, max(hw, 0), dA, ageK, oldK, lk.crack)
	if sig ~= lk.sig then lk.sig = sig return true end
	return false
end

------------------------------------------------------------------------------------------
-- The liquid: the pool's lattice and the ground under it
------------------------------------------------------------------------------------------
local function SimNMax()
	local q = C.cl.quality:GetInt()
	return q >= 3 and 40 or q >= 2 and 36 or q >= 1 and 28 or 24
end

-- The pool's origin on the plane's own axes (the pinning pattern is fixed in the world).
local function SimOrigin(p)
	return p.x * p.sx + p.y * p.sy + p.z * p.sz, p.x * p.tx + p.y * p.ty + p.z * p.tz
end

-- What has crossed an edge of the lattice is handed on: blood past a ledge gathers on the edge
-- and falls as drops, blood past the line where a slope's stream begins becomes that stream
-- (cl_runoff.lua). flush: everything now, however little (the lattice is about to change).
-- Nothing falls from a cell before one trace has shown that there is no floor under it.
local Drops
local Supported
local function SimSinks(p, flush)
	local g = p.sim
	if g.outVol <= 0 and g.outLoose <= 0 and not (flush and p.runAcc > 0) then return end
	Drops = Drops or ABL.Drops
	local out, blk, bq = g.out, g.blk, g.bq
	local n, a = g.n, g.a
	local over = 0
	for c, x in pairs(out) do
		if x > 0 then
			local ml = x * ML
			local kind = blk[c]
			local u, v = (g.i0 + (c - 1) % n + 0.5) * a, (g.j0 + floor((c - 1) / n) + 0.5) * a
			over = over + 1
			if kind == PS.EXIT then
				p.runAcc = p.runAcc + ml
				p.vol = max(0, p.vol - ml)
				-- (the stream begins at the pool's edge, not half a cell past it: where, by what
				-- crossed each cell)
				p.runSU, p.runSV = (p.runSU or 0) + (u - p.du * a * 0.6) * ml, (p.runSV or 0) + (v - p.dv * a * 0.6) * ml
				p.runSW = (p.runSW or 0) + ml
				out[c] = 0
				g.outVol = g.outVol - x
			elseif g.floor[(g.i0 + (c - 1) % n) * 65536 + g.j0 + floor((c - 1) / n)] == nil then
				-- not looked under yet (one trace; a turn without traces to spare waits)
				if flush or L.TakeTrace() then PS.Looked(g, c, Supported(p, u, v), CurTime()) end
			elseif ml >= 0.06 or flush then
				local cl = p.clips[bq[c]]
				local du, dv = 0, 0
				if cl then du, dv = cl.mu, cl.mv end
				local x0, y0, z0 = ToWorld(p, u, v, 0.3)
				local wx, wy, wz = p.sx * du + p.tx * dv, p.sy * du + p.ty * dv, p.sz * du + p.tz * dv
				-- (drops of the size that falls from an edge by its own weight, side by side along
				-- the edge: one of a fifth of a millilitre is a marble)
				local nd = min(math.ceil(ml / C.Runoff.pendant), 6)
				local ex, ey, ez = p.tx * du - p.sx * dv, p.ty * du - p.sy * dv, p.tz * du - p.sz * dv
				for _ = 1, nd do
					local o, sp = math.Rand(-0.22, 0.22), math.Rand(4, 7)
					Drops.Spawn(x0 + ex * o, y0 + ey * o, z0 + ez * o, wx * sp, wy * sp, wz * sp, ml / nd, nil, 0, 0, "pool")
				end
				p.vol = max(0, p.vol - ml)
				p.outTot = p.outTot + ml
				out[c] = 0
				g.outVol = g.outVol - x
			end
		end
	end
	if g.outVol < 1e-12 then g.outVol = 0 end
	-- (what lost its cell when the lattice changed)
	if g.outLoose > 0 then
		local ml = g.outLoose * ML
		g.outLoose = 0
		p.vol = max(0, p.vol - ml)
		ABL.FlowCore.Move("pool", "lost", ml)
	end
	if p.runAcc > 0.4 or (flush and p.runAcc > 0) then
		-- One stream from a pool's tip. It begins where the blood crossed (the middle of what
		-- crossed, not whichever cell came last), and what crosses later within a unit and a
		-- half of that place goes into the same stream at its first node: blood follows where
		-- blood has run. (A new stream for every 0.4 ml, each from another cell of the tip, as it
		-- was: a fan of thin streams with kinks where they began, and a bead left lying at the
		-- pool's edge.)
		if (p.runSW or 0) > 0 then
			local cu, cv = p.runSU / p.runSW, p.runSV / p.runSW
			if not p.runU or (cu - p.runU) ^ 2 + (cv - p.runV) ^ 2 > 2.25 then p.runU, p.runV = cu, cv end
			p.runSU, p.runSV, p.runSW = 0, 0, 0
		end
		local x, y, z = ToWorld(p, p.runU or 0, p.runV or 0)
		local FWm = ABL.FlowWorld
		local joined = FWm and FWm.Join and ABL.FlowCore.cv:GetBool() and FWm.Join(x, y, z, p.nx, p.ny, p.nz, p.runAcc, 1.2)
		local hd = not joined and ABL.Runoff.Spawn(x, y, z, p.nx, p.ny, p.nz, p.runAcc, p.surf, p.ent)
		-- (a new stream leaves the pool as wide as its head: no thread between the two)
		local ch = hd and hd.chan
		if ch and ch.wmax and ch.n == 1 then
			local KF = C.Flow
			local wm = 2 * (min(max(hd.vol, 0), KF.headShow) / ML / 1.28) ^ 0.3333 * KF.headGain * KF.trackK / KF.widthGain
			wm = wm * 0.6
			if wm > ch.wmax[1] then ch.wmax[1] = wm end
			-- (and a film at its first node, out of what the head holds: the stretch between the
			-- pool and the head is there from the start)
			local f = min(hd.vol * 0.2, 0.05)
			if ch.F and ch.F[1] and f > 0 then ch.F[1], hd.vol = ch.F[1] + f, hd.vol - f end
		end
		ABL.FlowCore.Move("pool", (joined or hd) and "surface" or "lost", p.runAcc)
		p.outTot = p.outTot + p.runAcc
		p.runAcc = 0
	end
	p.overN = over
end

-- Pinning, tilt, relief, walls and edges under the lattice: again whenever one of them or the
-- lattice itself has changed.
local stainList = {}
local function StainPin(p)
	local g = p.sim
	local BK = C.BloodMap
	p.bmVer = ABL.BloodMap.ver
	local R = g.n * g.a * 0.71
	local cu, cv = (g.i0 + g.n * 0.5) * g.a, (g.j0 + g.n * 0.5) * g.a
	local cx, cy, cz = ToWorld(p, cu, cv)
	local n = ABL.BloodMap.Query(cx, cy, cz, p.nx, p.ny, p.nz, R, stainList)
	if n == 0 then return end
	local now = CurTime()
	for i = 1, n do
		local r = stainList[i]
		local u, v = ToLocal(p, r.x, r.y, r.z)
		local wet = ABL.BloodMap.Wet(r, now)
		PS.StainPin(g, u, v, r.r, r.m * (BK.pinDry + (BK.pinWet - BK.pinDry) * wet))
		stainList[i] = nil
	end
end

local function SimGround(p)
	local g = p.sim
	SimSinks(p, true)
	local sl = min(p.slope, 0.95)
	local cs = sqrt(1 - sl * sl)
	local _, _, _, gmag = ABL.Gravity()
	g.kf = C.Flow.kFlow * (gmag / C.DEFAULT_GRAVITY) * cs * (p.surf.spread or 1)
	local tn = sl / cs
	local sr = p.simRelief
	local U0, V0 = SimOrigin(p)
	PS.SetGround(g, U0, V0, tn * p.du, tn * p.dv, sr and sr.r, sr and sr.cv)
	-- on a slope a stream takes over a little way downhill of where the pool formed
	local ex
	if p.slope > PC.slopeRun and p.surf.runoff > 0.2 then
		local reach = Clamp(1.2 / p.slope, SC.exitNear, SC.exitFar)
		ex = p.simExit or { exit = true }
		ex.u, ex.v, ex.mu, ex.mv = p.du * reach, p.dv * reach, p.du, p.dv
		p.simExit = ex
	end
	if #p.clips > 0 or ex or g.clipped then
		g.clipped = true
		-- (blood shut in behind a wall on all sides has nowhere to be)
		local lost = PS.SetClips(g, p.clips, ex) * ML
		if lost > 0 then
			p.vol = max(0, p.vol - lost)
			ABL.FlowCore.Move("pool", "lost", lost)
		end
	end
	g.clipVer = p.clipVer
	StainPin(p)
end

-- Time passing over the pool's cells: what dried and what the surface took up goes into the
-- books as it happens, and the pool's wetness is the share of its blood that is still wet.
local function SimAge(p, now, dt)
	local g = p.sim
	local scale = C.sv.drying:GetFloat()
	-- (air: warmer dries and sets faster, damp dries slower; a game's scale, like the times themselves)
	local temp, humid = C.sv.envTemp:GetFloat(), C.sv.envHumid:GetFloat()
	local airDry = Clamp(1 + (temp - 20) * 0.035, 0.2, 2.5) * Clamp(1.6 - humid * 0.012, 0.4, 1.6)
	local airSet = Clamp(1 - (temp - 20) * 0.02, 0.6, 1.8)
	local dried, soaked = PS.Age(g, now, dt, SC.evap * (p.surf.dry or 1) * airDry / scale, C.Flow.clotTime * scale * airSet / g.clotRate)
	if dried > 0 then
		dried = dried * ML
		p.vol, p.driedTot = max(0, p.vol - dried), p.driedTot + dried
		ABL.FlowCore.Move("pool", "dried", dried)
	end
	if soaked > 0 then
		soaked = soaked * ML
		p.vol, p.soakTot = max(0, p.vol - soaked), p.soakTot + soaked
		ABL.FlowCore.Move("pool", "absorbed", soaked)
	end
	local wetv = g.liq + g.gel
	local all = wetv + g.dep + g.soak
	p.wet = (all > 0 and wetv * ML > 1e-4) and wetv / all or 0
end

-- Where blood has been arriving (the developer overlay's inlets; at most six are remembered).
local function Inlet(p, u, v, vol, now, kind)
	local list = p.inlets
	local e
	for q = 1, #list do
		local o = list[q]
		if (o.u - u) ^ 2 + (o.v - v) ^ 2 < 2.25 then e = o break end
	end
	if not e then
		local at = #list + 1
		if at > 6 then
			at = 1
			for q = 2, 6 do
				if list[q].last < list[at].last then at = q end
			end
		end
		e = { u = u, v = v, vol = 0, rate = 0, last = now - 1 }
		list[at] = e
	end
	local gap = max(now - e.last, 0.02)
	e.rate = e.rate + (vol / gap - e.rate) * min(1, gap / 1.5)
	e.u, e.v = e.u + (u - e.u) * 0.2, e.v + (v - e.v) * 0.2
	e.vol, e.last, e.kind = e.vol + vol, now, kind
end

-- A lattice with room for vol ml (as far as it will spread, and a margin).
local function SimInit(p, vol)
	local film = p.surf.film
	local cu = max(vol, 0) / ML
	local R = sqrt(cu / (pi * film))
	local nMax = SimNMax()
	local a = PS.A0
	while 2.6 * R + 6 * a > a * nMax and a < PS.A_MAX do a = a * 2 end
	local n = Clamp(math.ceil(2.6 * R / a) + 6, 12, nMax)
	n = n + n % 2
	local g = PS.New(a, n, -n / 2, -n / 2)
	-- the surface's profile: the layer a pool rests at (film: its wetting / contact angle), the
	-- film left behind (adhesion), how unevenly it holds the contact line (roughness), how fast
	-- blood runs on it (spread), what it takes up (absorb), how fast blood dries and sets on it
	local name = p.surf.name or "default"
	g.film, g.res, g.memK = film, film * SC.res * Clamp(p.surf.adhesion or 1, 0.5, 2), SC.memory
	g.amp = SC.rough[name] or SC.rough.default
	g.clotRate = SC.clot[name] or SC.clot.default
	g.abCap, g.abTau = SC.soak * (p.surf.absorb or 0) * film, p.surf.soak and 2.5 or 6
	g.edgeDry, g.edgeWet = film * SC.edgeDry, film * SC.edgeWet
	p.sim = g
	p.look.smooth = SMOOTH[p.surf.name] or false
	SimGround(p)
	return g, cu
end

local LOD_NAME = { [512] = "ULTRA", [256] = "HIGH", [128] = "MEDIUM" }
local function SimLOD(p)
	if p.wet <= 0 and not PS.Active(p.sim) then return "STATIC" end
	if p.vis == false or not p.slot then return "LOW" end
	return LOD_NAME[p.slot.size] or "LOW"
end

-- Developer: a log of what changes on screen, for the acceptance scenes. Collected while
-- P.trace is a table (cl_selftest.lua, "pooltrace").
function P.Trace(kind, p, a, b)
	local tr = P.trace
	if not tr or #tr > 20000 then return end
	local e = { kind = kind, f = FrameNumber(), t = CurTime(), id = p.id }
	if kind == "light" or kind == "sim" then e.ms = b end
	local g = p.sim
	if kind == "paint" then
		e.slot, e.ms = a.size, b
		if g then
			e.cells, e.dcells, e.cell, e.lattice = g.wetN, g.wetN - (p.trCells or 0), g.a, g.n
			if p.trCell and p.trCell ~= g.a then e.coarser = true end
			p.trCells, p.trCell = g.wetN, g.a
		end
		if p.trSlot and p.trSlot ~= a.size then e.newSlot = true end
		p.trSlot = a.size
		if p.trMerged then
			e.sinceMerge = e.f - p.trMerged
			p.trMerged = nil
		end
		if not p.trPainted then
			e.first = e.f - (p.trBorn or e.f)
			p.trPainted = true
		end
		e.gap = e.f - (p.trLast or e.f)
		p.trLast = e.f
	elseif kind == "merge" then
		e.small, e.smallDrawn = a.id, a.slot ~= nil and a.painted
		p.trMerged = e.f
	elseif kind == "create" then
		e.vol = p.vol
		p.trBorn = e.f
	end
	tr[#tr + 1] = e
end

function P.SimInfo(p)
	local g = p.sim
	if not g then return "" end
	local act = 0
	local now = CurTime()
	for _, e in ipairs(p.inlets) do
		if now - e.last < 2 then act = act + 1 end
	end
	return string.format(" | lattice %d x %.2f cells %d %s steps %d %.0f us | in %.1f out %.1f dried %.1f soaked %.1f | liquid %.1f set %.1f ml | inlets %d/%d over %d | %s",
		g.n, g.a, g.wetN, PS.Active(g) and string.format("moving %dx%d", g.ax1 - g.ax0 + 1, g.ay1 - g.ay0 + 1) or "at rest", g.steps, (g.cost or 0) * 1e6,
		p.inTot, p.outTot, p.driedTot, p.soakTot, g.liq * ML, g.gel * ML, act, #p.inlets, p.overN or 0, SimLOD(p))
end

------------------------------------------------------------------------------------------
-- Creation / lookup
------------------------------------------------------------------------------------------
local nextId = 1

-- tArr: when the blood arrived (a liquid pool lays it down with its next step; without it the
-- blood lies there at once).
function P.Create(x, y, z, nx, ny, nz, vol, surf, ent, age, kind, dx, dy, dz, tArr)
	-- (a pool needs a place, a surface to lie on and a volume)
	if not (ABL.InWorld(x, y, z) and nx * nx + ny * ny + nz * nz > 0.5 and vol >= 0 and vol < 1e5) then return nil end
	if not IsValid(ent) then ent = nil end
	local cap = L.Cap(C.cl.maxPools)
	if #pools >= cap then
		if not P.EvictOne() then return nil end
	end
	local now = CurTime()
	nextId = nextId + 1
	local p = {
		x = x, y = y, z = z, nx = nx, ny = ny, nz = nz,
		vol = vol, surf = surf or C.Surfaces.default, ent = ent,
		born = now - (age or 0), lastFeed = now - (age or 0), wet = 1, fade = 1, id = nextId,
		blobs = {}, clips = {}, clipVer = 0, pv = {}, pb = {}, pledge = {}, probeIdx = 1,
		spill = 0, runAcc = 0, layer = (nextId % 7) * 0.006,
		inlets = {}, inTot = vol, outTot = 0, driedTot = 0, soakTot = 0,
		dirty = true, painted = false, meshDirty = true, lightT = 0, nextAge = 0, nextMaint = now + 1,
		lastFedU = 0, lastFedV = 0, satT = 0, clotT = now + 25 + math.random() * 30,
	}
	p.rng = ABL.RNG(floor(abs(x * 31 + y * 17 + z * 7)) + 11)
	local rng = p.rng
	if IsValid(ent) then p.entPos = ent:GetPos() end
	Surface(p)
	local fam = ChooseFamily(rng, kind, p.surf, p.slope, age)
	MakeLook(p, fam, rng)
	if useSim:GetBool() then
		-- the cells of all pools of a plane lie on one grid (two pools that meet hand their blood
		-- over cell for cell): the pool's origin is moved onto it, a fifth of a unit at most
		local U0, V0 = SimOrigin(p)
		local eu, ev = floor(U0 / PS.A0 + 0.5) * PS.A0 - U0, floor(V0 / PS.A0 + 0.5) * PS.A0 - V0
		p.x, p.y, p.z = x + p.sx * eu + p.tx * ev, y + p.sy * eu + p.ty * ev, z + p.sz * eu + p.tz * ev
		p.lastFedU, p.lastFedV = -eu, -ev
		local g, cu = SimInit(p, vol)
		p.look.amp = SC.edge * rng:Range(0.9, 1.1)
		-- (how much of the floor shows through is the layer's doing, cell by cell)
		p.look.opacity = p.surf.soak and 0.92 or 1
		if age and age > 0 then
			-- a pool known from the server snapshot: already spread, and as old as it is
			U0, V0 = SimOrigin(p)
			PS.Presettle(g, cu, U0, V0, now - age)
			SimAge(p, now, age)
		elseif tArr then
			PS.Pour(g, -eu, -ev, cu, tArr)
		else
			PS.Deposit(g, -eu, -ev, cu, now)
			SimAge(p, now, 0)
		end
		pools[#pools + 1] = p
		P.stats.created = P.stats.created + 1
		UpdateLook(p, now)
		if P.trace then P.Trace("create", p) end
		return p
	end
	local cell = Pick(byFam[fam], "fam" .. fam, rng)
	-- orientation: elongated bodies point downhill, runoff-fed bodies along the flow, others random
	local rot = rng:Next() * TWO_PI
	local anchored = false
	if fam == "D" then
		rot = (p.slope > 0.01) and atan2(p.dv, p.du) or (dx and LocalAngle(p, dx, dy, dz) or rot)
		anchored = true
	elseif fam == "I" and dx then
		rot = LocalAngle(p, dx, dy, dz)
		anchored = true
	end
	local asp = fam == "D" and rng:Range(1.0, 1.25) or rng:Range(0.9, 1.14)
	local b = NewBlob(p, "body", cell, 0, 0, vol, rot, asp, rng:Next() < 0.5)
	b.anchored = anchored
	-- runoff that forms a pool of another family still arrives through a feeder
	if kind == "runoff" and dx and fam ~= "I" then
		local f = NewBlob(p, "feed", PickKind("feeder", rng), 0, 0, vol * 0.1, LocalAngle(p, dx, dy, dz), 1, rng:Next() < 0.5)
		f.anchored = true
		b.vol = vol * 0.9
	end
	if age and age > 0 then
		-- a pool known from the server snapshot: already spread, partly or fully dried
		p.wet = Clamp(1 - age / P.DryTime(p), 0, 1)
		for _, bb in ipairs(p.blobs) do bb.w = 1 end
		P.SettleRadii(p, 1)
	end
	pools[#pools + 1] = p
	P.stats.created = P.stats.created + 1
	UpdateLook(p, now)
	return p
end

function P.TargetRadius(p, vol)
	local absorb = p.surf.absorb or 0
	local cu = ((vol or p.vol) * (1 - absorb * 0.55)) / C.ML_PER_CU
	return sqrt(max(cu, 0) / (pi * p.surf.film))
end

function P.DryTime(p)
	return PC.dryBase * ((max(p.vol, 1) / 10) ^ 0.33) * C.sv.drying:GetFloat() / (p.surf.dry or 1)
end

-- Pool that contains (x,y,z) on the same surface plane (margin in units).
function P.Find(x, y, z, nx, ny, nz, margin)
	local best, bestD = nil, math.huge
	for i = 1, #pools do
		local p = pools[i]
		if p.fade >= 1 and p.nx * nx + p.ny * ny + p.nz * nz > 0.9 then
			local rx, ry, rz = x - p.x, y - p.y, z - p.z
			local h = rx * p.nx + ry * p.ny + rz * p.nz
			if abs(h) < 2 then
				local u, v = rx * p.sx + ry * p.sy + rz * p.sz, rx * p.tx + ry * p.ty + rz * p.tz
				local d2 = u * u + v * v
				if d2 < bestD and d2 < (p.rad or 1e4) ^ 2 + 100 and Covers(p, u, v, margin) then best, bestD = p, d2 end
			end
		end
	end
	return best
end

-- Radius of the pool toward a world direction (outline distance from the origin).
function P.RadiusToward(p, dx, dy, dz)
	local du, dv = dx * p.sx + dy * p.sy + dz * p.sz, dx * p.tx + dy * p.ty + dz * p.tz
	local l = sqrt(du * du + dv * dv)
	if l < 1e-6 then return 0 end
	return Extent(p, du / l, dv / l)
end

------------------------------------------------------------------------------------------
-- Feeding: new blood reshapes the pool where it arrives
------------------------------------------------------------------------------------------
local function CountKind(p, kind)
	local n = 0
	for _, b in ipairs(p.blobs) do if b.kind == kind then n = n + 1 end end
	return n
end

local function VolBlobs(p)
	local n = 0
	for _, b in ipairs(p.blobs) do if VOLKIND[b.kind] then n = n + 1 end end
	return n
end

local function Largest(p)
	local best, bv = nil, -1
	for _, b in ipairs(p.blobs) do
		if VOLKIND[b.kind] and b.vol > bv then best, bv = b, b.vol end
	end
	return best
end

-- Satellite spatter: a drop falling into the pool from height throws droplets out around it
-- (a ring for vertical impacts, a cone downstream for oblique ones).
local function AddSatellites(p, u, v, vol, K, tu, tv)
	local IC = C.Impact
	if K < IC.kDeposit * 1.3 then return end
	local now = CurTime()
	if now < p.satT then return end
	local rng = p.rng
	if rng:Next() > min(1, (K - IC.kDeposit) / IC.kCrown) * 0.6 then return end
	p.satT = now + 0.35
	if CountKind(p, "sat") >= PC.maxSats then
		-- replace the oldest spatter that the pool has already covered, otherwise keep what exists
		local oi
		for i, b in ipairs(p.blobs) do
			if b.kind == "sat" and Covers(p, b.u, b.v, -b.hs * 0.5) then oi = i break end
		end
		if not oi then return end
		table.remove(p.blobs, oi)
	end
	local cone = tu and (tu * tu + tv * tv) > 0.2
	local cell = PickKind(cone and "satcone" or "satring", rng)
	local stainD = ABL.DropDiameterMM(vol) / 25.4
	local hs = Clamp(stainD * (2.2 + K / 120), 1.2, 7) * rng:Range(0.85, 1.2)
	local rot = cone and atan2(tv, tu) or rng:Next() * TWO_PI
	local b = NewBlob(p, "sat", cell, u, v, 0, rot, rng:Range(0.9, 1.2), rng:Next() < 0.5)
	b.hs, b.w = hs, 0.7
	P.stats.sats = P.stats.sats + 1
end

-- kind: "drip" (drops falling in), "seep" (from under a body), "runoff" (a rivulet flows in,
-- dx..: its direction), "impact" (K: splash parameter of the drop), "blot" (transfer)
function P.Feed(p, vol, x, y, z, kind, dx, dy, dz, K)
	if not ABL.GoodVol(vol) then return end
	-- (blood that arrives nowhere in particular thickens the pool as a whole)
	if x and not ABL.InWorld(x, y, z) then x = nil end
	if dx and not ABL.Finite3(dx, dy, dz) then dx = nil end
	p.vol = p.vol + vol
	p.lastFeed = CurTime()
	p.wet = min(1, p.wet + vol / (p.vol * 0.25 + 0.2))
	P.stats.fed = P.stats.fed + 1
	local rng = p.rng
	if p.sim then
		-- the blood lands where it arrives and flows from there. What arrives moving (a rivulet,
		-- a drop from height) is thin for a moment and spreads the further for it
		local u, v = p.lastFedU, p.lastFedV
		local shear = 0
		if x then
			u, v = ToLocal(p, x, y, z)
			if (kind == "drip" or kind == "impact") and K then
				local tu, tv
				if dx then tu, tv = dx * p.sx + dy * p.sy + dz * p.sz, dx * p.tx + dy * p.ty + dz * p.tz end
				-- (spatter round a drop that struck the floor; one that falls into the liquid
				-- leaves no ring of dots in it)
				if not PS.Covers(p.sim, u, v, 0) then AddSatellites(p, u, v, vol, K, tu, tv) end
				shear = min(K / 8, 60)
			elseif kind == "runoff" then
				shear = 30
			end
		end
		local now = CurTime()
		-- (laid down by the liquid's steps; what finds no place is written off there: P.Think)
		PS.Pour(p.sim, u, v, vol / ML, now, shear)
		p.inTot = p.inTot + vol
		Inlet(p, u, v, vol, now, kind or "drip")
		p.lastFedU, p.lastFedV = u, v
		p.dirty = true
		return
	end
	if not x then
		local b = Largest(p)
		if b then b.vol = b.vol + vol end
		p.dirty = true
		return
	end
	local u, v = ToLocal(p, x, y, z)
	-- runoff arriving: its feeder grows (or a new one forms at the entry), the body gets the blood
	if kind == "runoff" and dx then
		local fu, fv = dx * p.sx + dy * p.sy + dz * p.sz, dx * p.tx + dy * p.ty + dz * p.tz
		local ang = atan2(fv, fu)
		local feed
		for _, b in ipairs(p.blobs) do
			if b.kind == "feed" and (b.au - u) ^ 2 + (b.av - v) ^ 2 < 4 then feed = b break end
		end
		if not feed and VolBlobs(p) < PC.maxBlobs then
			feed = NewBlob(p, "feed", PickKind("feeder", rng), u, v, 0, ang, 1, rng:Next() < 0.5)
			feed.anchored = true
			P.stats.lobes = P.stats.lobes + 1
		end
		if feed then feed.vol = feed.vol + vol * 0.12 vol = vol * 0.88 end
	end
	local b = Covers(p, u, v, 0)
	local body = b or Largest(p)
	if not body then return end
	local du, dv = u - body.u, v - body.v
	local d = sqrt(du * du + dv * dv)
	local rr = max(Reach(body), 0.3)
	if (kind == "drip" or kind == "impact") and K then
		local tu, tv
		if dx then tu, tv = dx * p.sx + dy * p.sy + dz * p.sz, dx * p.tx + dy * p.ty + dz * p.tz end
		AddSatellites(p, u, v, vol, K, tu, tv)
	end
	-- near the middle the pool just thickens and spreads evenly; toward (or beyond) the rim the
	-- arriving blood pushes a lobe out there
	if d < rr * 0.45 or kind == "seep" and d < rr * 0.7 then
		body.vol = body.vol + vol
	else
		local lobe
		for _, o in ipairs(p.blobs) do
			if o.kind == "lobe" and (o.u - u) ^ 2 + (o.v - v) ^ 2 < (Reach(o) * 0.6 + 0.4) ^ 2 then lobe = o break end
		end
		if not lobe and VolBlobs(p) < PC.maxBlobs then
			lobe = NewBlob(p, "lobe", PickKind("bulge", rng), u, v, 0, rng:Next() * TWO_PI, rng:Range(0.85, 1.2), rng:Next() < 0.5)
			P.stats.lobes = P.stats.lobes + 1
		end
		if lobe then
			local share = b and 0.55 or 0.85
			lobe.vol = lobe.vol + vol * share
			body.vol = body.vol + vol * (1 - share)
		else
			body.vol = body.vol + vol
		end
	end
	p.lastFedU, p.lastFedV = u, v
	p.dirty = true
end

-- Blood arriving on a floor-like surface (impact remains, coarse deposition, runoff reaching the
-- floor, seeping from under a body). kind / dx.. / K as for P.Feed.
function P.Deposit(x, y, z, n, vol, surf, ent, kind, dx, dy, dz, K)
	if not (vol > 0) then return end
	-- (the callers have booked the blood into the pools already: what cannot lie anywhere is written off)
	if not (vol < 1e4 and ABL.InWorld(x, y, z) and n.x * n.x + n.y * n.y + n.z * n.z > 0.5) then
		ABL.FlowCore.Move("pool", "lost", vol)
		return
	end
	if dx and not ABL.Finite3(dx, dy, dz) then dx = nil end
	if not IsValid(ent) then ent = nil end
	local p = P.Find(x, y, z, n.x, n.y, n.z, 1.2)
	if p then P.Feed(p, vol, x, y, z, kind, dx, dy, dz, K) return p end
	local s, k = SeedAdd(x, y, z, n, vol, surf, ent, kind, dx, dy, dz)
	local need = kind == "runoff" and PC.minVolumeRunoff or PC.minVolume
	if s.vol < need and s.vol >= need * (1 - C.BloodMap.seedK) then
		local cov, wet = ABL.BloodMap.Coverage(s.sx / s.w, s.sy / s.w, s.sz / s.w, n.x, n.y, n.z, 6, s.t0 - 1)
		need = need * (1 - C.BloodMap.seedK * min(1, cov * 0.5 + wet * 0.5))
	end
	if s.vol >= need then
		local cx, cy, cz = s.sx / s.w, s.sy / s.w, s.sz / s.w
		local cnt, _, gx, gy, gz = ABL.Ground.Near(cx, cy, cz, n.x, n.y, n.z, PC.attractR)
		local tr
		if cnt >= PC.attractMin then
			local dx, dy, dz = gx - cx, gy - cy, gz - cz
			local h = dx * n.x + dy * n.y + dz * n.z
			dx, dy, dz = dx - n.x * h, dy - n.y * h, dz - n.z * h
			local d = sqrt(dx * dx + dy * dy + dz * dz)
			local k = d > 0.01 and min(d * 0.8, PC.attractMax) / d or 0
			local ax, ay, az = cx + dx * k, cy + dy * k, cz + dz * k
			tr = util.TraceLine({ start = Vector(ax, ay, az) + n * 3, endpos = Vector(ax, ay, az) - n * 3, mask = MASK_SOLID, filter = ABL.Surface.ProbeFilter })
			if not (tr.Hit and tr.HitNormal:Dot(n) > 0.85) then tr = nil end
		end
		-- snap the centre onto the surface
		tr = tr or util.TraceLine({ start = Vector(cx, cy, cz) + n * 3, endpos = Vector(cx, cy, cz) - n * 3, mask = MASK_SOLID, filter = ABL.Surface.ProbeFilter })
		if tr.Hit and tr.HitNormal:Dot(n) > 0.85 then
			cx, cy, cz = tr.HitPos.x, tr.HitPos.y, tr.HitPos.z
		end
		seeds[k] = nil
		-- The drops became a pool at the moment their sum reached what a pool needs: within this
		-- arrival, taken as arriving evenly since the one before (a tenth of a second back at
		-- most). The pool is made with that sum at that moment, and what this arrival brought
		-- beyond it follows: the same pool whatever the frames are.
		local now = CurTime()
		local over, tArr = 0, nil
		if useSim:GetBool() and s.tp and vol > 0 then
			over = Clamp(s.vol - need, 0, vol)
			tArr = now - min(now - s.tp, 0.1) * (over / vol)
		end
		local np = P.Create(cx, cy, cz, n.x, n.y, n.z, s.vol - over, surf, ent, nil, SeedKind(s), s.dx, s.dy, s.dz, tArr)
		-- (no room for another pool: its blood is written off)
		if not np then
			ABL.FlowCore.Move("pool", "lost", s.vol)
		elseif over > 0 then
			P.Feed(np, over, x, y, z, kind, dx, dy, dz, K)
		end
		return np
	end
end

local function EatStains(p)
	ABL.Ground.Near(p.x, p.y, p.z, p.nx, p.ny, p.nz, p.rad + 2, function(x, y, z, a)
		local v = a * pi * PC.eatFilm * ML
		ABL.FlowCore.Move("surface", "pool", v)
		P.Feed(p, v, x, y, z, "seep")
	end)
end

function P.Disturb(p, x, y, z, dx, dy, dz, take, push)
	if not (p.fade >= 1 and p.wet > 0 and ABL.InWorld(x, y, z) and take >= 0 and take < 1e3) then return 0 end
	local u, v = ToLocal(p, x, y, z)
	local g = p.sim
	local got = 0
	if g then
		local avail = (g.liq + g.gel) * ML
		take = min(take, avail * 0.5)
		if take > 0 then got = take - PS.Take(g, u, v, take / ML) * ML end
		if push and push > 0 and dx and ABL.Finite3(dx, dy, dz) then
			local tu, tv = dx * p.sx + dy * p.sy + dz * p.sz, dx * p.tx + dy * p.ty + dz * p.tz
			local tl = sqrt(tu * tu + tv * tv)
			local amt = min(push, (avail - got) * 0.3)
			if tl > 1e-3 and amt > 0 then
				local moved = amt - PS.Take(g, u, v, amt / ML) * ML
				if moved > 0 then
					local reach = C.Smear.pushReach
					local u2, v2 = u + tu / tl * reach, v + tv / tl * reach
					if PS.Fit(g, SimNMax(), min(u, u2) - 1, min(v, v2) - 1, max(u, u2) + 1, max(v, v2) + 1) then SimGround(p) end
					local lost = PS.Deposit(g, u2, v2, moved / ML, p.lastFeed, 30) * ML
					if lost > 0 then
						p.vol = max(0, p.vol - lost)
						ABL.FlowCore.Move("pool", "lost", lost)
					end
				end
			end
		end
	else
		got = min(take, p.vol * p.wet * 0.3)
		local b = Largest(p)
		if b then b.vol = max(0, b.vol - got) end
	end
	if got > 0 then
		p.vol = max(0, p.vol - got)
		ABL.FlowCore.Move("pool", "dried", got)
	end
	p.dirty = true
	return got
end

-- Blood that is still liquid in pools, and in the drops collecting toward one (books).
function P.Volume()
	local t = 0
	for i = 1, #pools do t = t + pools[i].vol - (pools[i].bkDry or 0) + pools[i].runAcc end
	-- (drops collecting toward a pool: as booked, their drying is booked when they are next looked at)
	for _, s in pairs(seeds) do t = t + s.vol end
	return t
end

-- Drops that never became a pool dry where they lie (books; looked at every few seconds).
local nextSeedSweep = 0
local function SweepSeeds(now)
	if now < nextSeedSweep then return end
	nextSeedSweep = now + 5
	for k, s in pairs(seeds) do
		local decay = exp(-(now - s.t) / 45)
		local gone = s.vol * (1 - decay)
		s.vol, s.sx, s.sy, s.sz, s.w = s.vol * decay, s.sx * decay, s.sy * decay, s.sz * decay, s.w * decay
		for kk, v in pairs(s.kinds) do s.kinds[kk] = v * decay end
		s.t = now
		if s.vol < 0.01 then
			gone = gone + s.vol
			seeds[k] = nil
		end
		ABL.FlowCore.Move("pool", "dried", gone)
	end
end

------------------------------------------------------------------------------------------
-- Walls and ledges: probed along PC.probeDirs directions from the origin. A wall or a ledge
-- becomes a clip line in the canvas (straight edge where the blood stops); blood pushing past a
-- ledge runs over it as drops.
------------------------------------------------------------------------------------------
local probeOut = {}
local probeTrace = { mask = MASK_SOLID, output = probeOut, filter = ABL.Surface.ProbeFilter }
local vA, vB = Vector(), Vector()

local function TraceL(x0, y0, z0, x1, y1, z1)
	vA:SetUnpacked(x0, y0, z0)
	vB:SetUnpacked(x1, y1, z1)
	probeTrace.start, probeTrace.endpos = vA, vB
	util.TraceLine(probeTrace)
	return probeOut
end

function Supported(p, u, v)
	local x, y, z = ToWorld(p, u, v)
	local tr = TraceL(x + p.nx * 2, y + p.ny * 2, z + p.nz * 2, x - p.nx * 3, y - p.ny * 3, z - p.nz * 3)
	if not tr.Hit or tr.StartSolid then return false end
	local hn = tr.HitNormal
	if hn.x * p.nx + hn.y * p.ny + hn.z * p.nz < 0.85 then return false end
	local h = (tr.HitPos.x - p.x) * p.nx + (tr.HitPos.y - p.y) * p.ny + (tr.HitPos.z - p.z) * p.nz
	return abs(h) < 1.2
end

local function AddClip(p, qu, qv, mu, mv, ledge)
	for _, c in ipairs(p.clips) do
		if c.mu * mu + c.mv * mv > 0.97 and abs((qu - c.u) * c.mu + (qv - c.v) * c.mv) < 0.35 then return end
	end
	if #p.clips >= 10 then return end
	p.clips[#p.clips + 1] = { u = qu, v = qv, mu = mu, mv = mv, ledge = ledge or nil }
	p.clipVer = (p.clipVer or 0) + 1
	p.dirty = true
	P.stats.clips = P.stats.clips + 1
end

local NDIR = PC.probeDirs

-- Where the floor ends along the direction at angle ang (pool frame), looked for out to a
-- little past e: the point, or nil when the floor does not end there (or no traces are left).
local function EdgeAlong(p, ang, e)
	local eu, ev = cos(ang), sin(ang)
	local far = e * 1.6 + 1
	if not L.TakeTrace() or Supported(p, eu * far, ev * far) then return nil end
	local lo, hi = 0.2, far
	for _ = 1, 5 do
		if not L.TakeTrace() then return nil end
		local mid = (lo + hi) * 0.5
		if Supported(p, eu * mid, ev * mid) then lo = mid else hi = mid end
	end
	local d = (lo + hi) * 0.5
	return eu * d, ev * d
end

local function Probe(p, i)
	local th = (i - 1) / NDIR * TWO_PI
	local du, dv = cos(th), sin(th)
	local want = Extent(p, du, dv) * 1.12 + 0.5
	local wx, wy, wz = p.sx * du + p.tx * dv, p.sy * du + p.ty * dv, p.sz * du + p.tz * dv
	if not L.TakeTrace() then return end
	-- obstacle along the surface
	local o = 0.6
	local tr = TraceL(p.x + p.nx * o, p.y + p.ny * o, p.z + p.nz * o, p.x + p.nx * o + wx * want, p.y + p.ny * o + wy * want, p.z + p.nz * o + wz * want)
	if tr.Hit and not tr.StartSolid then
		local d = tr.Fraction * want
		local hn = tr.HitNormal
		-- in-plane direction into the wall
		local hnn = hn.x * p.nx + hn.y * p.ny + hn.z * p.nz
		local mx, my, mz = -(hn.x - p.nx * hnn), -(hn.y - p.ny * hnn), -(hn.z - p.nz * hnn)
		local mu, mv = mx * p.sx + my * p.sy + mz * p.sz, mx * p.tx + my * p.ty + mz * p.tz
		local ml = sqrt(mu * mu + mv * mv)
		if ml < 0.3 then mu, mv = du, dv else mu, mv = mu / ml, mv / ml end
		local qd = max(0.3, d - 0.12)
		AddClip(p, du * qd, dv * qd, mu, mv)
		p.pb[i] = d
		p.pledge[i] = false
		return
	end
	-- support under the far point
	if not L.TakeTrace() then return end
	if Supported(p, du * want, dv * want) then
		p.pv[i] = want
		return
	end
	-- a ledge or a hole: find the edge (4 halvings) and clip there
	local lo, hi = max(p.pv[i] or 0, 0.3), want
	for _ = 1, 4 do
		if not L.TakeTrace() then break end
		local mid = (lo + hi) * 0.5
		if Supported(p, du * mid, dv * mid) then lo = mid else hi = mid end
	end
	local e = (lo + hi) * 0.5
	-- the way the edge itself runs: where it lies a little to either side of this ray. The clip
	-- stands across the line through those two points (across the ray when they are not found)
	local mu, mv = du, dv
	local au, av = EdgeAlong(p, th - 0.35, e)
	local bu, bv = EdgeAlong(p, th + 0.35, e)
	if au and bu then
		local tu, tv = bu - au, bv - av
		local tl = sqrt(tu * tu + tv * tv)
		if tl > 0.3 then
			local cu, cv = tv / tl, -tu / tl
			if cu * du + cv * dv < 0 then cu, cv = -cu, -cv end
			-- (an edge that faces this ray; a corner seen from the side keeps the ray's own direction)
			if cu * du + cv * dv > 0.5 then mu, mv = cu, cv end
		end
	end
	AddClip(p, du * e, dv * e, mu, mv, true)
	p.pb[i] = e
	p.pledge[i] = true
end

-- Blood reaching a ledge runs over it: drops gather on the edge and fall, faster the further the
-- pool wants to spread past it.
local Drops
local function Overflow(p, dt)
	Drops = Drops or ABL.Drops
	for j = 1, NDIR do
		if p.pledge[j] then
			local th = (j - 1) / NDIR * TWO_PI
			local du, dv = cos(th), sin(th)
			local want, edge = Extent(p, du, dv), p.pb[j]
			if want > edge + 0.3 then
				local q = min(p.vol * PC.overflow * (want - edge) / max(want, 0.5), 1.5)   -- ml/s
				p.spill = p.spill + q * dt
				local dv0 = max(0.05, q * 0.12)
				if p.spill >= dv0 and p.vol > dv0 then
					p.spill = p.spill - dv0
					p.vol = p.vol - dv0
					local b = Largest(p)
					if b then b.vol = max(0, b.vol - dv0) end
					local x, y, z = ToWorld(p, du * (edge + 0.35), dv * (edge + 0.35), 0.3)
					local wx, wy, wz = p.sx * du + p.tx * dv, p.sy * du + p.ty * dv, p.sz * du + p.tz * dv
					Drops.Spawn(x, y, z, wx * 6, wy * 6, wz * 6, dv0, nil, 0, 0, "pool")
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Blob dynamics
------------------------------------------------------------------------------------------
-- Spreading: each volume-carrying stamp's area follows its volume (viscous: fast at first,
-- slower as it grows, stopped once the rim has clotted); its front works through the stamp's
-- shape (w). k = 1 settles instantly (snapshots).
function P.SettleRadii(p, k, dt)
	if p.sim then
		-- (a liquid pool spreads by its own steps; settled at once: laid out as it would lie)
		if k >= 1 then
			local g, cu = SimInit(p, p.vol)
			local U0, V0 = SimOrigin(p)
			local now = CurTime()
			PS.Presettle(g, cu, U0, V0, now)
			SimAge(p, now, 0)
			p.dirty = true
		end
		return
	end
	local film = p.surf.film
	local absorb = p.surf.absorb or 0
	local fam = FAM[p.fam]
	local spread = p.wet > 0.25
	for _, b in ipairs(p.blobs) do
		local c = cells[b.cell]
		if VOLKIND[b.kind] then
			local rt = sqrt(max(b.vol * (1 - absorb * 0.55) / C.ML_PER_CU, 0) / (pi * film))
			b.rt = rt
			if k >= 1 then
				b.r = max(b.r, rt)
			elseif spread and b.r < rt then
				b.r = b.r + (rt - b.r) * min(1, dt / (PC.spreadTau + b.r * 0.3))
			end
			if k >= 1 then b.w = 1
			elseif spread then b.w = b.w + (1 - b.w) * min(1, dt / (PC.matureTau * fam.mature)) end
			b.hs = max(b.r, 0.05) / c.req
			Anchor(b)
		elseif b.kind == "sat" then
			b.w = min(1, b.w + (dt or 1) * 3)
		end
	end
end

-- Surface tension fills the waist where two parts of a pool touch: a neck stamp grows there.
local function Necks(p)
	local blobs = p.blobs
	if CountKind(p, "neck") >= 4 or VolBlobs(p) >= PC.maxBlobs then return end
	for i = 1, #blobs do
		local a = blobs[i]
		if VOLKIND[a.kind] and a.kind ~= "neck" then
			for j = i + 1, #blobs do
				local b = blobs[j]
				if VOLKIND[b.kind] and b.kind ~= "neck" then
					local du, dv = b.u - a.u, b.v - a.v
					local d = sqrt(du * du + dv * dv)
					local ra, rb = Reach(a) * 0.8, Reach(b) * 0.8
					if d > (ra + rb) * 0.55 and d < (ra + rb) * 1.08 and d > 0.5 then
						local t = ra / (ra + rb)
						local nu, nv = a.u + du * t, a.v + dv * t
						local exists = false
						for _, o in ipairs(blobs) do
							if o.kind == "neck" and (o.u - nu) ^ 2 + (o.v - nv) ^ 2 < (min(ra, rb) * 0.5) ^ 2 then exists = true break end
						end
						if not exists then
							local take = min(a.vol, b.vol) * 0.08
							a.vol, b.vol = a.vol - take * 0.5, b.vol - take * 0.5
							local n = NewBlob(p, "neck", PickKind("bulge", p.rng), nu, nv, take, atan2(dv, du), 1.3, false)
							n.w = 0.7
							P.stats.necks = P.stats.necks + 1
							return
						end
					end
				end
			end
		end
	end
end

-- Keep the stamp count bounded: fold lobes that the pool has engulfed (or, over the limit, the
-- smallest lobe) into the part that holds them.
local function Consolidate(p)
	local blobs = p.blobs
	for i = #blobs, 1, -1 do
		local b = blobs[i]
		if b.kind == "sat" then
			-- spatter the pool has covered is gone under the blood
			if Covers(p, b.u, b.v, -b.hs * 0.9) then table.remove(blobs, i) p.dirty = true end
		elseif b.kind == "lobe" or b.kind == "neck" then
			for _, o in ipairs(blobs) do
				if o ~= b and (o.kind == "body" or o.kind == "lobe") and o.r > b.r * 1.5 then
					local d = sqrt((o.u - b.u) ^ 2 + (o.v - b.v) ^ 2)
					if d + Reach(b) < Reach(o) * 0.75 then
						o.vol = o.vol + b.vol
						table.remove(blobs, i)
						p.dirty = true
						break
					end
				end
			end
		end
	end
	while VolBlobs(p) > PC.maxBlobs do
		local si, sv = nil, math.huge
		for i, b in ipairs(blobs) do
			if (b.kind == "lobe" or b.kind == "neck") and b.vol < sv then si, sv = i, b.vol end
		end
		if not si then break end
		local b = table.remove(blobs, si)
		local best, bd = nil, math.huge
		for _, o in ipairs(blobs) do
			if VOLKIND[o.kind] then
				local d = (o.u - b.u) ^ 2 + (o.v - b.v) ^ 2
				if d < bd then best, bd = o, d end
			end
		end
		if best then best.vol = best.vol + b.vol end
		p.dirty = true
	end
end

-- Thick blood clots as it ages: darker deposits form inside the pool.
local function Clots(p, now)
	-- (a liquid pool shows set blood cell by cell, darker and duller where it has set
	-- (cl_poolcanvas.lua, Cell). Round clot marks stamped on top of that, as until phase 34, were
	-- a second picture of the same thing: dark discs in the pool, and a bulge in its outline
	-- where one lay near the edge.)
	if p.sim then return end
	if now < p.clotT or p.vol < 25 or p.wet < 0.3 or CountKind(p, "clot") >= 3 then return end
	p.clotT = now + 30 + p.rng:Next() * 40
	local body = Largest(p)
	if not body then return end
	local rng = p.rng
	local a, d = rng:Next() * TWO_PI, Reach(body) * 0.4 * sqrt(rng:Next())
	local b = NewBlob(p, "clot", PickKind("clot", rng), body.u + cos(a) * d, body.v + sin(a) * d, 0, rng:Next() * TWO_PI, 1, false)
	b.hs, b.w = Reach(body) * rng:Range(0.25, 0.45), 1
end

-- A wet pool on a slope creeps downhill: a lobe grows at the downhill rim and keeps moving down.
local function Creep(p, dt)
	if p.sim or p.slope < PC.slopeCreep or p.wet < 0.4 or p.vol < 4 then return end
	local e = Extent(p, p.du, p.dv)
	local lobe = p.creep
	if not lobe or lobe.dead then
		if VolBlobs(p) >= PC.maxBlobs then return end
		lobe = NewBlob(p, "lobe", PickKind("bulge", p.rng), p.du * e * 0.8, p.dv * e * 0.8, 0, atan2(p.dv, p.du), 1.35, false)
		p.creep = lobe
	end
	local body = Largest(p)
	if body and body ~= lobe then
		local flow = body.vol * p.slope * 0.05 * dt
		body.vol, lobe.vol = body.vol - flow, lobe.vol + flow
	end
	-- the front moves downhill until the rim clots
	local sp = p.slope * 1.2 * p.wet * dt
	lobe.u, lobe.v = lobe.u + p.du * sp, lobe.v + p.dv * sp
	p.dirty = true
end

------------------------------------------------------------------------------------------
-- Canvas: the local square the pool is painted into (with headroom so it is rarely resized)
------------------------------------------------------------------------------------------
local function UpdateCanvas(p)
	local g = p.sim
	if g then
		-- the canvas of a liquid pool is its lattice's window
		-- (coarser cells coming: what the pool shows now is kept, and turns into what they hold)
		if p.painted and p.vis and PS.FitCoarsens(g, SimNMax()) then p.morphSnaps = { PCV.Snapshot(p) } end
		if PS.Fit(g, SimNMax()) then SimGround(p) end
		local cvs = p.canvas
		if cvs and cvs.n == g.n and cvs.a == g.a and cvs.i0 == g.i0 and cvs.j0 == g.j0 then return false end
		local H = g.n * g.a * 0.5
		local cu, cv = (g.i0 + g.n * 0.5) * g.a, (g.j0 + g.n * 0.5) * g.a
		p.canvas = { cu = cu, cv = cv, H = H, G = Clamp(math.ceil(H * 2 / 9), 2, 10), n = g.n, a = g.a, i0 = g.i0, j0 = g.j0 }
		p.relief, p.reliefN = {}, 0
		p.cx, p.cy, p.cz = ToWorld(p, cu, cv)
		p.rad = H * 1.42
		p.dirty = true
		return true
	end
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, b in ipairs(p.blobs) do
		local c = cells[b.cell]
		local r = b.hs * max(b.asp, 1) * (b.kind == "sat" and 1 or min(1, c.ext + 0.12))
		x0, y0, x1, y1 = min(x0, b.u - r), min(y0, b.v - r), max(x1, b.u + r), max(y1, b.v + r)
	end
	local need = max(x1 - x0, y1 - y0) * 0.5 + 0.6
	local cu, cv = (x0 + x1) * 0.5, (y0 + y1) * 0.5
	local cvs = p.canvas
	if cvs then
		local fits = x0 >= cvs.cu - cvs.H and x1 <= cvs.cu + cvs.H and y0 >= cvs.cv - cvs.H and y1 <= cvs.cv + cvs.H
		if fits and cvs.H < need * 2.4 + 2 then return false end
	end
	local H = min(need * 1.3 + 0.5, PC.maxCanvas)
	local G = Clamp(math.ceil(H * 2 / 9), 2, 10)
	-- a new table: the slot keeps showing the previous canvas (p.pcanvas) until it is repainted
	p.canvas = { cu = cu, cv = cv, H = H, G = G }
	p.relief, p.reliefN = {}, 0
	p.cx, p.cy, p.cz = ToWorld(p, cu, cv)
	p.rad = H * 1.42
	p.dirty = true
	return true
end

-- Floor relief under the canvas grid (displacements, uneven props): a few traces per tick.
local function TraceRelief(p, budget)
	local cv = p.canvas
	local G = cv.G
	local n = (G + 1) * (G + 1)
	while p.reliefN < n and budget > 0 do
		if not L.TakeTrace() then return end
		budget = budget - 1
		local idx = p.reliefN
		local i, j = idx % (G + 1), floor(idx / (G + 1))
		local u, v = cv.cu - cv.H + 2 * cv.H * i / G, cv.cv - cv.H + 2 * cv.H * j / G
		local x, y, z = ToWorld(p, u, v)
		local tr = TraceL(x + p.nx * 3, y + p.ny * 3, z + p.nz * 3, x - p.nx * 3, y - p.ny * 3, z - p.nz * 3)
		local h = 0
		if tr.Hit and not tr.StartSolid and tr.HitNormal.x * p.nx + tr.HitNormal.y * p.ny + tr.HitNormal.z * p.nz > 0.75 then
			h = Clamp((tr.HitPos.x - p.x) * p.nx + (tr.HitPos.y - p.y) * p.ny + (tr.HitPos.z - p.z) * p.nz, -1.5, 1.5)
		end
		p.relief[idx + 1] = h
		p.reliefN = idx + 1
		if p.reliefN == n then
			p.meshDirty = true
			if p.sim then
				-- the liquid runs on the relief once all of it is known (a flat floor changes nothing)
				local any = false
				for q = 1, n do
					if abs(p.relief[q]) > 0.01 then any = true break end
				end
				if any or p.simRelief then
					p.simRelief = any and { r = p.relief, cv = cv } or nil
					SimGround(p)
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Merging: the other pool's stamps join this pool's canvas, so the fields sum into one outline
------------------------------------------------------------------------------------------
local function Destroy(p)
	if p.mesh then p.mesh:Destroy() p.mesh = nil end
	if p.slot then PCV.Free(p.slot) p.slot = nil end
	if p.nextSlot then PCV.Free(p.nextSlot) p.nextSlot = nil end
	if p.ghosts then
		for _, gh in ipairs(p.ghosts) do Destroy(gh) end
		p.ghosts = nil
	end
	if PCV.morphOwner == p then PCV.morphOwner = nil end
end

-- Do two liquid pools touch? The outermost cells of one against the cells of the other.
local function SimTouch(pa, pb)
	local hu, hv, k = PS.Hull(pb.sim)
	local ga = pa.sim
	-- (before their outlines meet: the two are one liquid first, and what joins them on screen
	-- is the blood that crosses the dry cells between them)
	local gap = max(ga.a, pb.sim.a) * 1.75
	for q = 1, k do
		local u, v = ToLocal(pa, ToWorld(pb, hu[q], hv[q]))
		if PS.Covers(ga, u, v, gap) then return true end
	end
	return false
end

-- The other pool's blood into this pool's lattice, cell by cell where it lies. From there on the
-- two are one liquid: the gap between them fills when blood reaches it, and the neck widens as
-- the layers level.
-- The rectangle of pool b's wet cells in pool a's frame.
local function SimRect(a, b)
	local gb = b.sim
	local ab = gb.a
	local u0, v0, u1, v1 = math.huge, math.huge, -math.huge, -math.huge
	for q = 0, 3 do
		local u, v = ToLocal(a, ToWorld(b, (gb.i0 + (q % 2 == 0 and gb.bx0 or gb.bx1 + 1)) * ab, (gb.j0 + (q < 2 and gb.by0 or gb.by1 + 1)) * ab))
		u0, v0, u1, v1 = min(u0, u), min(v0, v), max(u1, u), max(v1, v)
	end
	return u0, v0, u1, v1
end

local function SimMerge(a, b)
	local ga, gb = a.sim, b.sim
	if gb.bx1 < gb.bx0 then return end
	SimSinks(b, true)
	local ab = gb.a
	-- (what the two show now turns into what the one lattice holds: P.Paint, PCV.MorphBegin)
	if (a.painted and a.vis) or (b.painted and b.vis) then
		local ou, ov = ToLocal(a, ToWorld(b, 0, 0))
		local eu, ev = ToLocal(a, ToWorld(b, 1, 0))
		if abs(eu - ou - 1) + abs(ev - ov) < 1e-3 then
			local list = {}
			local sa, sb = a.painted and PCV.Snapshot(a), b.painted and PCV.Snapshot(b)
			if sa then list[#list + 1] = sa end
			if sb then
				sb.u, sb.v = sb.u + ou, sb.v + ov
				list[#list + 1] = sb
			end
			a.morphSnaps = list
		end
	end
	if PS.Fit(ga, SimNMax(), SimRect(a, b)) then SimGround(a) end
	-- A cell of the finest size lies within one cell of this lattice (the pools of a plane share
	-- one grid: P.Create), and all of it goes there; a coarser cell arrives in parts small enough
	-- to. What was shown of the cell comes along (cl_poolcanvas.lua, Cover).
	local now = CurTime()
	local dvB = PCV.Cover(gb, b, now)
	PCV.Cover(ga, a, now)
	local k = ab > PS.A0 * 1.01 and Clamp(2 * math.ceil(ab / ga.a), 2, 8) or 1
	local n = gb.n
	local h, kg, s, sb, tb, td = gb.h, gb.k, gb.s, gb.ab, gb.tb, gb.td
	local part = ab * ab / (k * k)
	local share = part / (ga.a * ga.a)
	local lost = 0
	for j = gb.by0, gb.by1 do
		for i = gb.bx0, gb.bx1 do
			local c = j * n + i + 1
			local t, rest = h[c], kg[c] + s[c] + sb[c]
			if t > 0 or rest > 0 then
				local cov = dvB[c] * share
				for sj = 1, k do
					for si = 1, k do
						local u, v = ToLocal(a, ToWorld(b, (gb.i0 + i + (si - 0.5) / k) * ab, (gb.j0 + j + (sj - 0.5) / k) * ab))
						local left, q = PS.AddAt(ga, u, v, kg[c] * part, s[c] * part, sb[c] * part, td[c], t * part, tb[c])
						lost = lost + left
						if q and cov > 0 then PCV.CoverAdd(ga, q, cov) end
					end
				end
			end
		end
	end
	if lost > 0 then
		b.vol = max(0, b.vol - lost * ML)
		ABL.FlowCore.Move("pool", "lost", lost * ML)
	end
	for _, it in ipairs(gb.pour) do
		it.u, it.v = ToLocal(a, ToWorld(b, it.u, it.v))
		ga.pour[#ga.pour + 1] = it
		ga.pourVol = ga.pourVol + it.vol * (1 - it.done)
	end
	gb.pour, gb.pourVol = {}, 0
	if ga.pourVol > 0 then PS.WakeAll(ga) end
	a.inTot, a.outTot, a.driedTot, a.soakTot = a.inTot + b.inTot, a.outTot + b.outTot, a.driedTot + b.driedTot, a.soakTot + b.soakTot
	for _, e in ipairs(b.inlets) do
		if #a.inlets < 6 then
			e.u, e.v = ToLocal(a, ToWorld(b, e.u, e.v))
			a.inlets[#a.inlets + 1] = e
		end
	end
	SimAge(a, CurTime(), 0)
end

local function Merge(a, b)
	if P.trace then P.Trace("merge", a, b) end
	for _, o in ipairs(b.blobs) do
		local x, y, z = ToWorld(b, o.u, o.v)
		local ax, ay, az = ToWorld(b, o.au, o.av)
		o.u, o.v = ToLocal(a, x, y, z)
		o.au, o.av = ToLocal(a, ax, ay, az)
		local dx, dy, dz = b.sx * cos(o.rot) + b.tx * sin(o.rot), b.sy * cos(o.rot) + b.ty * sin(o.rot), b.sz * cos(o.rot) + b.tz * sin(o.rot)
		o.rot = LocalAngle(a, dx, dy, dz)
		a.blobs[#a.blobs + 1] = o
	end
	for _, c in ipairs(b.clips) do
		local x, y, z = ToWorld(b, c.u, c.v)
		local qu, qv = ToLocal(a, x, y, z)
		local mx, my, mz = b.sx * c.mu + b.tx * c.mv, b.sy * c.mu + b.ty * c.mv, b.sz * c.mu + b.tz * c.mv
		AddClip(a, qu, qv, mx * a.sx + my * a.sy + mz * a.sz, mx * a.tx + my * a.ty + mz * a.tz, c.ledge)
	end
	if a.sim and b.sim then SimMerge(a, b) end
	a.vol = a.vol + b.vol
	a.bkDry = (a.bkDry or 0) + (b.bkDry or 0)
	a.runAcc = a.runAcc + b.runAcc
	a.wet = max(a.wet, b.wet)
	a.lastFeed = max(a.lastFeed, b.lastFeed)
	a.born = min(a.born, b.born)
	for i = 1, NDIR do a.pv[i] = nil end
	a.dirty = true
	P.stats.merged = P.stats.merged + 1
	Consolidate(a)
	-- (the canvas for the lattice as it now is, and no waiting for the repaint)
	if a.sim then
		local keep = a.morphSnaps
		UpdateCanvas(a)
		a.morphSnaps = keep or a.morphSnaps
		a.nextPaint = 0
	end
end

-- Two pools can only come to touch when at least one of them is still growing or moving: a pool
-- being fed (or fed in the last seconds, still spreading) or creeping down a slope. Only those are
-- tested, against every other pool; stamp positions are worked out once per check.
local mergeStamp = 0
local function MergePrep(p)
	if p.mgStamp == mergeStamp then return end
	p.mgStamp = mergeStamp
	local blobs = p.blobs
	for k = 1, #blobs do
		local b = blobs[k]
		if VOLKIND[b.kind] then
			b.mx, b.my, b.mz = ToWorld(p, b.u, b.v)
			b.mr = Reach(b)
		else
			b.mr = false
		end
	end
end

local function MergeCheck(now)
	mergeStamp = mergeStamp + 1
	local n = #pools
	local creep = PC.slopeCreep
	local anyActive = false
	for i = 1, n do
		local p = pools[i]
		local act = p.canvas ~= nil and p.wet > 0 and (now - p.lastFeed < 6 or (p.slope > creep and p.wet > 0.3))
		-- (a liquid pool: while it still moves, and looked at three times a second)
		if p.sim then
			act = p.canvas ~= nil and p.wet > 0 and (now - p.lastFeed < 6 or PS.Active(p.sim)) and now >= (p.mgT or 0)
			if act then p.mgT = now + 0.3 end
		end
		p.mgActive = act
		if act then anyActive = true end
	end
	if not anyActive then return end
	local mf = PC.mergeFactor
	for ia = 1, n do
		local pa = pools[ia]
		if pa.mgActive then
			for ib = 1, n do
				local pb = pools[ib]
				-- (each pair once: two active pools are tested from the first of them)
				if ib ~= ia and pb.canvas and (ib > ia or not pb.mgActive) and (pa.sim == nil) == (pb.sim == nil)
					and pa.ent == pb.ent and pa.nx * pb.nx + pa.ny * pb.ny + pa.nz * pb.nz > 0.95 then
					local dx, dy, dz = pb.cx - pa.cx, pb.cy - pa.cy, pb.cz - pa.cz
					local reach = pa.rad + pb.rad
					if dx * dx + dy * dy + dz * dz < reach * reach and abs(dx * pa.nx + dy * pa.ny + dz * pa.nz) < 2 then
						-- closest pair of stamps: merge when their outlines come within the merge gap
						MergePrep(pa)
						MergePrep(pb)
						local touch = pa.sim ~= nil and (SimTouch(pa, pb) or SimTouch(pb, pa))
						local ba, bb = pa.blobs, pb.blobs
						for i = 1, (pa.sim and 0 or #ba) do
							local A = ba[i]
							local ra = A.mr
							if ra then
								local xa, ya, za = A.mx, A.my, A.mz
								for j = 1, #bb do
									local Bq = bb[j]
									local rb = Bq.mr
									if rb then
										local ex, ey, ez = xa - Bq.mx, ya - Bq.my, za - Bq.mz
										local lim = (ra + rb) * mf
										if ex * ex + ey * ey + ez * ez < lim * lim then touch = true break end
									end
								end
								if touch then break end
							end
						end
						if touch then
							-- the bigger pool absorbs the smaller one (two liquid pools only while one
							-- lattice can hold both)
							local big, small, si = pa, pb, ib
							if pb.vol + (pb.driedTot or 0) > pa.vol + (pa.driedTot or 0) then big, small, si = pb, pa, ia end
							if not big.sim or PS.CanFit(big.sim, SimNMax(), SimRect(big, small)) then
								Merge(big, small)
								if big.sim and small.mesh and small.slot and small.painted then
									-- (the smaller pool's picture stays until the bigger one has been painted
									-- with its blood: P.Paint)
									local gl = big.ghosts or {}
									big.ghosts, big.ghostT = gl, RealTime() + 0.5
									gl[#gl + 1] = small
									if small.ghosts then
										for _, gh in ipairs(small.ghosts) do gl[#gl + 1] = gh end
										small.ghosts = nil
									end
								else
									Destroy(small)
								end
								ABL.SwapRemove(pools, si)
								return
							end
						end
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Eviction / baking
------------------------------------------------------------------------------------------
function P.EvictOne()
	-- least important: dried, far, old
	local worst, wi = math.huge, nil
	for i = 1, #pools do
		local p = pools[i]
		local imp = L.PointImportance(p.cx or p.x, p.cy or p.y, p.cz or p.z)
		local score = imp * (0.3 + p.wet) * (1 + p.vol / 50)
		if score < worst then worst, wi = score, i end
	end
	if not wi then return false end
	P.Bake(pools[wi])
	-- (what was still wet in it is dried blood from here on: books)
	ABL.FlowCore.Move("pool", "dried", pools[wi].vol - (pools[wi].bkDry or 0) + pools[wi].runAcc)
	Destroy(pools[wi])
	ABL.SwapRemove(pools, wi)
	return true
end

-- Replace a pool by an engine decal (made from the pool bodies, see texgen) so it survives
-- without per-frame cost when the pool cap forces it out.
function P.Bake(p)
	if p.baked then return end
	local rad = 0
	for _, b in ipairs(p.blobs) do if VOLKIND[b.kind] then rad = max(rad, sqrt(b.u * b.u + b.v * b.v) + Reach(b)) end end
	if p.sim then
		for q = 0, 7 do rad = max(rad, PS.Extent(p.sim, cos(q * pi / 4), sin(q * pi / 4))) end
	end
	if rad < 1 then return end
	p.baked = true
	local col = C.Colors.decal
	local w = rad * 2 / 0.8
	ABL.Stains.Place("pool", ABL.Mat.Random("pool", p.rng), p.x, p.y, p.z, p.nx, p.ny, p.nz, nil, nil, nil, w, w, col, 225 * p.fade, IsValid(p.ent) and p.ent or nil, 0, p.rng)
end

------------------------------------------------------------------------------------------
-- Update. A pool that is being fed thinks about 10 times a second, a wet one left alone 3 times
-- (it only creeps and dries), a dry one once a second (only ageing is left), a fading one 5 times.
-- Pools take turns over the frames instead of all thinking in the same one, and each steps by the
-- time since its own last turn.
------------------------------------------------------------------------------------------
local MAX_THINKS = 10      -- pools per frame at most (the rest wait a frame)
-- (the ageing of the pool that is being stepped: PS.Advance calls this after a step that ends
-- on a half second)
local agePool
local function AgeTick(t)
	local p = agePool
	local g = p.sim
	local slot = floor(t * 2 + 1e-6)
	if slot ~= g.ageSlot then
		SimAge(p, t, min((slot - (g.ageSlot or slot - 1)) * 0.5, 1.5))
		g.ageSlot = slot
	end
end
local NEAR = 300           -- units: a pool in view within this is "near the viewer"
local nextMerge = 0
function P.Think()
	local now = CurTime()
	local life, fadeT = PC.life, PC.fade
	local done = 0
	local tSettle, tProbe, tMaint, tLook, tRelief = 0, 0, 0, 0, 0
	-- what the liquid's steps may take this frame
	local simT, simBudget = 0, SC.budget * 0.001 * max(L.scale, 0.35)
	-- (two rounds: the pools in view near the viewer first, so that what the others cost comes
	-- out of what those have left over)
	for round = 1, 2 do
	local i = #pools
	while i > 0 do
		local p = pools[i]
		local due = p.thinkT or 0
		local near = p.hero == true
		-- (a pool that was just fed does not wait out a slow turn)
		if near == (round == 1) and (now >= due or (now - p.lastFeed < 0.2 and due - now > 0.15)) and done < MAX_THINKS then
			done = done + 1
			local wetNow = p.wet > 0
			local dt = min(now - (p.thinkL or (now - 0.1)), wetNow and 0.6 or 1.5)
			local tA = SysTime()
			p.thinkL = now
			local remove = false
			-- pools on moving props are dropped (their stains remain as decals)
			if p.ent ~= nil and p.entPos then
				if not IsValid(p.ent) or p.ent:GetPos():DistToSqr(p.entPos) > 1 then remove = true end
			end
			if not remove and wetNow then
				local g = p.sim
				if g then
					if g.clipVer ~= p.clipVer then SimGround(p) end
					-- time: soaking in, setting, drying, twice a second: while the liquid moves, after
					-- the step that ends on a half second of the game's time (AgeTick: the same place
					-- among the steps whatever the frames are); at rest, at the turn after it
					if not g.ageSlot then g.ageSlot = floor(now * 2) end
					if not g.tS then
						local slot = floor(now * 2)
						if slot ~= g.ageSlot then
							SimAge(p, now, min((slot - g.ageSlot) * 0.5, 1.5))
							g.ageSlot = slot
						end
					end
					-- the liquid's own steps (fewer at once for a pool nobody sees)
					if simT < simBudget then
						local s0 = SysTime()
						agePool = p
						local steps = PS.Advance(g, dt, p.vis == false and 2 or 4, now, AgeTick)
						s0 = SysTime() - s0
						if P.trace then P.Trace("sim", p, nil, s0 * 1000) end
						if g.pourLost > 0 then
							-- (blood that arrived where walls and edges leave it no place)
							local lost = g.pourLost * ML
							g.pourLost = 0
							p.vol = max(0, p.vol - lost)
							ABL.FlowCore.Move("pool", "lost", lost)
						end
						simT = simT + s0
						if steps > 0 then g.cost = (g.cost or s0 / steps) * 0.9 + s0 / steps * 0.1 end
					end
					SimSinks(p, false)
					if g.moved > g.film * 0.02 then
						g.moved = 0
						p.dirty = true
					end
				else
					local dryT = P.DryTime(p)
					local sinceFeed = now - p.lastFeed
					p.wet = max(0, p.wet - dt / dryT * (sinceFeed > 2 and 1 or 0.2))
					P.SettleRadii(p, 0, dt)
				end
				if not g and p.wet > 0.35 then Overflow(p, dt) end
				Creep(p, dt)
				-- slope: feed runoff from the downhill rim
				if not g and p.slope > PC.slopeRun and p.wet > 0.4 and p.vol > 3 and p.surf.runoff > 0.2 then
					local flow = p.vol * p.slope * 0.12 * dt * p.surf.runoff
					p.runAcc = p.runAcc + flow
					p.vol = p.vol - flow
					local b = Largest(p)
					if b then b.vol = max(0, b.vol - flow) end
					if p.runAcc > 0.4 then
						local r = Extent(p, p.du, p.dv)
						local x, y, z = ToWorld(p, p.du * r, p.dv * r)
						ABL.FlowCore.Move("pool", ABL.Runoff.Spawn(x, y, z, p.nx, p.ny, p.nz, p.runAcc, p.surf, p.ent) and "surface" or "lost", p.runAcc)
						p.runAcc = 0
					end
				end
				tSettle = tSettle + (SysTime() - tA)
				tA = SysTime()
				-- probe walls / ledges where the outline has grown past the verified distance (2 per turn)
				local probes = 0
				for _ = 1, NDIR do
					local j = p.probeIdx
					p.probeIdx = j % NDIR + 1
					if not p.pb[j] then
						local th = (j - 1) / NDIR * TWO_PI
						local want = Extent(p, cos(th), sin(th))
						if want > (p.pv[j] or 0) + 0.25 then
							Probe(p, j)
							probes = probes + 1
							if probes >= 2 then break end
						end
					end
				end
				tProbe = tProbe + (SysTime() - tA)
			end
			local fading = false
			if not remove then
				tA = SysTime()
				if now > p.nextMaint then
					p.nextMaint = now + 1 + p.rng:Next() * 0.5
					Consolidate(p)
					if p.wet > 0.3 then Necks(p) end
					Clots(p, now)
					if p.wet > 0.2 and p.rad then EatStains(p) end
					if p.sim and p.wet > 0 and p.bmVer ~= ABL.BloodMap.ver then StainPin(p) end
					-- (the lattice holds what the pool's volume says: rounding is taken out here)
					if p.sim then
						local v = PS.Volume(p.sim) * ML
						if v > 1e-9 then
							local k = p.vol / v
							if abs(k - 1) > P.stats.simDrift then P.stats.simDrift = abs(k - 1) end
							if abs(k - 1) > 1e-12 then PS.Scale(p.sim, k) end
						end
					end
				end
				tMaint = tMaint + (SysTime() - tA)
				tA = SysTime()
				-- anything that moved enough to show needs a repaint
				local blobs = p.blobs
				for k = 1, #blobs do
					local b = blobs[k]
					if abs(b.hs - b.pr) > max(0.02, b.hs * 0.015) or abs(b.w - b.pw) > 0.02 or abs(b.u - b.pu) + abs(b.v - b.pv) > 0.04 then
						p.dirty = true
						break
					end
				end
				if UpdateLook(p, now) then p.dirty = true end
				UpdateCanvas(p)
				tLook = tLook + (SysTime() - tA)
				tA = SysTime()
				if p.canvas and p.reliefN < (p.canvas.G + 1) ^ 2 then TraceRelief(p, 6) end
				tRelief = tRelief + (SysTime() - tA)
				-- ageing & cleanup
				local age = now - p.lastFeed
				if p.wet <= 0 and age > life then
					fading = true
					p.fade = max(0, p.fade - dt / fadeT)
					p.meshDirty = true
					if p.fade <= 0 then remove = true end
				end
			end
			-- books: the share of the pool that has dried (a liquid pool's are written as its cells dry)
			if not p.sim then
				local dry = p.vol * (1 - p.wet)
				if dry ~= (p.bkDry or 0) then
					ABL.FlowCore.Move("pool", "dried", dry - (p.bkDry or 0))
					p.bkDry = dry
				end
			end
			if remove then
				ABL.FlowCore.Move("pool", "dried", p.vol - (p.bkDry or 0) + p.runAcc)
				Destroy(p)
				ABL.SwapRemove(pools, i)
			else
				local every = (p.wet > 0 and ((now - p.lastFeed < 4 or (p.sim and PS.Active(p.sim))) and 0.1 or 0.33)) or (fading and 0.2) or 1
				if every == 0.1 and p.sim and near then
					-- (a liquid pool near the viewer: one step of the liquid a turn, at an even pace)
					p.thinkT = now + PS.STEP * 0.98
				else
					p.thinkT = now + every * (0.85 + 0.3 * math.random())
				end
			end
		end
		i = i - 1
	end
	end
	local Prof = ABL.Prof
	if done > 0 then
		Prof.Add("sub.pools.spread", tSettle) Prof.Add("sub.pools.probes", tProbe) Prof.Add("sub.pools.upkeep", tMaint)
		Prof.Add("sub.pools.look", tLook) Prof.Add("sub.pools.relief", tRelief)
		Prof.Count("pool turns", done)
	end
	SweepSeeds(now)
	if now >= nextMerge then
		nextMerge = now + 0.1
		local tM = SysTime()
		MergeCheck(now)
		Prof.Add("sub.pools.merge", SysTime() - tM)
	end
end

------------------------------------------------------------------------------------------
-- Repainting (called before the frame renders): the most visible, most out-of-date pools first,
-- within a per-frame budget. Slot size follows the pool's size on screen.
------------------------------------------------------------------------------------------
local function WantSize(p, d)
	-- slot texels per world unit ~ 0.8 x screen pixels per unit (75 deg fov, 1080p)
	local px = 0.8 * 2 * p.canvas.H * (ScrH() * 1.15) / max(d, 1)
	if px > 300 then return 512 elseif px > 150 then return 256 end
	return 128
end

local function MarkPainted(p)
	for _, b in ipairs(p.blobs) do b.pr, b.pw, b.pu, b.pv = b.hs, b.w, b.u, b.v end
end

local cand = {}
function P.Paint()
	if #pools == 0 then return end
	if not PCV.ready then PCV.Start() end
	local rt = RealTime()
	local n = 0
	local view = PCV.view:GetInt()
	-- the two liquid pools in view nearest the viewer (within NEAR): they are stepped every step
	-- and painted every frame while their outline moves; all others keep the slower pace
	local h1, h2, hd1, hd2 = nil, nil, NEAR, NEAR
	for _, p in ipairs(pools) do
		if p.sim and p.canvas and p.vis and (p.dist or NEAR) < hd2 and p.wet > 0 then
			if p.dist < hd1 then h2, hd2, h1, hd1 = h1, hd1, p, p.dist else h2, hd2 = p, p.dist end
		end
	end
	for _, p in ipairs(pools) do
		if p.canvas and (#p.blobs > 0 or p.sim) then
			local d2, vis = L.View(p.cx, p.cy, p.cz, p.rad)
			local d = sqrt(d2)
			p.dist, p.vis = d, vis
			p.hero = p == h1 or p == h2
			local want = WantSize(p, d)
			local cur = p.slot and p.slot.size or 0
			-- grow the slot when needed; shrink only when far too big for a while
			if want > cur or not p.slot then p.want = want
			elseif want < cur and not vis then p.want = (p.shrinkT and rt > p.shrinkT) and want or cur p.shrinkT = p.shrinkT or rt + 8
			else p.want, p.shrinkT = cur, nil end
			local near = vis and d < NEAR
			local hero = p.hero
			-- (the layer's slope is lit as seen from where the viewer stands: a wet pool near the
			-- viewer is painted again when the viewer has walked a good way round it)
			if p.sim and near and p.wet > 0 then
				local eu, ev = ToLocal(p, L.eyeX, L.eyeY, L.eyeZ)
				eu, ev = p.canvas.cu - eu, p.canvas.cv - ev
				local el = sqrt(eu * eu + ev * ev)
				if el > 0.5 then
					eu, ev = eu / el, ev / el
					-- (five degrees: the far side's line turns with the viewer in steps too small to see)
					if not p.vdu or eu * p.vdu + ev * p.vdv < 0.996 then
						p.vdu, p.vdv = eu, ev
						p.dirty = true
					end
				end
			end
			-- What is shown of a liquid pool near the viewer is still catching up with the liquid:
			-- between the paints that follow the liquid, every frame gets a light paint (the
			-- outline and the colours; the mirror's mask keeps for those few frames).
			local full = p.dirty or (p.easing and not hero) or p.want ~= cur or not p.painted or rt > p.nextAge or (p.sim and p.viewN ~= view)
			if full and p.painted and rt < (p.nextPaint or 0) then full = false end
			p.lightNext = not full and p.easing == true and p.sim ~= nil and hero and p.painted and p.want == cur and p.pcanvas == p.canvas and rt >= (p.nextLight or 0)
			local stale = full or p.lightNext
			-- (a pool that was taken in is kept on screen for the next paint only)
			if p.ghosts and rt > p.ghostT then
				for _, gh in ipairs(p.ghosts) do Destroy(gh) end
				p.ghosts = nil
			end
			if stale and (vis or d < 1500) then
				-- priority: visible, near, changed long ago
				local pr = (vis and 4 or 1) / (1 + d / 400) * (1 + min(rt - (p.staleT or rt), 2))
				if not p.painted then pr = pr * 3 end
				-- (the pools near the viewer before all others)
				if vis and d < NEAR then pr = pr * 4 end
				p.staleT = p.staleT or rt
				n = n + 1
				cand[n] = p
				p.prio = pr
			end
		end
	end
	for i = n + 1, #cand do cand[i] = nil end
	if n == 0 then return end
	table.sort(cand, function(a, b) return a.prio > b.prio end)
	local q = C.cl.quality:GetInt()
	local budgetN = (q >= 3 and 3 or q >= 1 and 2 or 1)
	local budgetMs = 1.4 * max(L.scale, 0.35)
	local t0 = SysTime()
	for i = 1, n do
		local p = cand[i]
		if i > budgetN or (SysTime() - t0) * 1000 > budgetMs then break end
		local slot = p.slot
		if not slot or p.want ~= slot.size then
			slot = PCV.Alloc(p.want) or (p.want > 128 and PCV.Alloc(p.want / 2)) or (p.want > 256 and PCV.Alloc(128))
		end
		if slot then
			if p.morphSnaps then
				local snaps = p.morphSnaps
				p.morphSnaps = nil
				-- (what the pools it took in showed is among the old patches now)
				if p.sim and PCV.MorphBegin(p, snaps) and p.ghosts then
					for _, gh in ipairs(p.ghosts) do Destroy(gh) end
					p.ghosts = nil
				end
			end
			local ok, ms = PCV.Paint(p, slot)
			if ok then
				if slot ~= p.slot then
					if p.slot then PCV.Free(p.slot) end
					p.slot = slot
					p.meshDirty = true
				end
				if p.pcanvas ~= p.canvas then
					p.pcanvas = p.canvas
					p.meshDirty = true
				end
				local ts = game.GetTimeScale()
				-- (at most 90 light paints a second of the game's time)
				p.nextLight = rt + 0.011 / ts
				if p.lightNext then
					-- (when what is shown has caught up, one more full paint: the mirror's mask)
					if not p.easing then p.dirty = true end
					P.stats.paints = P.stats.paints + 1
					if P.trace then P.Trace("light", p, slot, ms) end
				else
					-- (a liquid pool in view: as often as what its paint costs allows; never less
					-- often than before. Per second of the game's time: a slowed game is not painted
					-- more often for it)
					local iv = p.vis and 0.08 or 0.3
					if p.sim and p.vis then
						iv = 0.14 + p.sim.wetN / 4000
						if p.hero then iv = min(max(ms * 0.001 / SC.paintDuty, 0.022), iv) end
					end
					p.nextPaint = rt + (iv + min(p.dist or 0, 2000) / 4000) / ts
					if p.ghosts then
						for _, gh in ipairs(p.ghosts) do Destroy(gh) end
						p.ghosts = nil
					end
					p.painted = true
					p.viewN = view
					p.dirty = false
					p.staleT = nil
					MarkPainted(p)
					-- colours keep ageing while the pool dries; a slow refresh also restores slots lost
					-- to a device reset
					p.nextAge = rt + ((p.look.wetMode ~= "dry" and p.wet > 0) and 1.5 or 12) + math.random()
					P.stats.paints = P.stats.paints + 1
					P.stats.paintMs = P.stats.paintMs * 0.9 + ms * 0.1
					if P.trace then P.Trace("paint", p, slot, ms) end
				end
			elseif slot ~= p.slot then
				PCV.Free(slot)
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Rendering: one static grid mesh per pool (on the traced floor relief), drawn with the pool
-- material, then the wet layer of drying pools, then the view-dependent wet reflection.
------------------------------------------------------------------------------------------
local vec = Vector()
local gx, gy, gz, gU, gV, gR, gG, gB = {}, {}, {}, {}, {}, {}, {}, {}

local function BuildMesh(p)
	if p.mesh then p.mesh:Destroy() p.mesh = nil end
	local cv, slot, lk = p.pcanvas, p.slot, p.look
	local G = cv.G
	local page = PCV.page
	local k = slot.size / (2 * cv.H)
	local R = ABL.Render
	local tint = p.surf.tint
	local a = 255 * lk.opacity * p.fade
	-- the surface normal: the environment reflection mirrors about it
	local nrm = Vector(p.nx, p.ny, p.nz)
	local n1 = G + 1
	local relief = (cv == p.canvas) and p.relief or nil
	for j = 0, G do
		for i = 0, G do
			local idx = j * n1 + i + 1
			local u, v = cv.cu - cv.H + 2 * cv.H * i / G, cv.cv - cv.H + 2 * cv.H * j / G
			local off = PC.offset + p.layer + (relief and relief[idx] or 0)
			local x, y, z = ToWorld(p, u, v, off)
			gx[idx], gy[idx], gz[idx] = x, y, z
			gU[idx] = (slot.x + (u - cv.cu + cv.H) * k) / page
			gV[idx] = (slot.y + (v - cv.cv + cv.H) * k) / page
			local lr, lg, lb = R.Light(x + p.nx * 2, y + p.ny * 2, z + p.nz * 2)
			gR[idx] = min(255, 255 * lr * lk.tr * tint[1])
			gG[idx] = min(255, 255 * lg * lk.tr * lk.tg * tint[2])
			gB[idx] = min(255, 255 * lb * lk.tr * lk.tb * tint[3])
		end
	end
	local m = Mesh()
	mesh.Begin(m, MATERIAL_QUADS, G * G)
	for j = 0, G - 1 do
		for i = 0, G - 1 do
			for c = 1, 4 do
				local ii, jj = i + ((c == 2 or c == 3) and 1 or 0), j + ((c >= 3) and 1 or 0)
				local idx = jj * n1 + ii + 1
				vec:SetUnpacked(gx[idx], gy[idx], gz[idx])
				mesh.Position(vec)
				mesh.TexCoord(0, gU[idx], gV[idx])
				mesh.Normal(nrm)
				mesh.Color(gR[idx], gG[idx], gB[idx], a)
				mesh.AdvanceVertex()
			end
		end
	end
	mesh.End()
	p.mesh = m
	p.meshDirty = false
end

local sheenList, sheenK, sheenE, sheenF = {}, {}, {}, {}
local sheenCol, filterCol = Vector(), Vector()

-- The mirror's pass over the pool's grid. Every vertex has the reflectance of the view's angle
-- at that place (Fresnel, n ~ 1.35; no more than mirrorMax): the far side of a pool is seen at a
-- lower angle than the near side and mirrors more of what is behind it, which is how a level
-- liquid looks from close by. (One reflectance for the whole pool, taken at its middle, made it
-- an evenly tinted sheet.) k: the pool's own share (its look, its wetness, its fade).
-- Built every frame, for the pools that are large in view only (P.Draw): a hundred of them
-- cost 2 ms a frame that way, and a pool that is small in view has one angle anyway.
local mvx, mvy, mvz, mva = {}, {}, {}, {}
local mirrorNrm = Vector()
local function MirrorMesh(p, k)
	local cv, slot = p.pcanvas, p.slot
	local G = cv.G
	local n1 = G + 1
	local page = PCV.page
	local relief = (cv == p.canvas) and p.relief or nil
	local ex, ey, ez = L.eyeX, L.eyeY, L.eyeZ
	local nx, ny, nz = p.nx, p.ny, p.nz
	local cap = PC.mirrorMax
	for j = 0, G do
		for i = 0, G do
			local idx = j * n1 + i + 1
			local x, y, z = ToWorld(p, cv.cu - cv.H + 2 * cv.H * i / G, cv.cv - cv.H + 2 * cv.H * j / G, PC.offset + p.layer + (relief and relief[idx] or 0))
			mvx[idx], mvy[idx], mvz[idx] = x, y, z
			local dx, dy, dz = x - ex, y - ey, z - ez
			local d = sqrt(dx * dx + dy * dy + dz * dz)
			local q = d > 1e-3 and 1 - abs(dx * nx + dy * ny + dz * nz) / d or 0
			local F = 0.022 + 0.978 * q * q * q * q * q
			if F > cap then F = cap end
			F = F * k
			mva[idx] = F >= 1 and 255 or F * 255
		end
	end
	mirrorNrm:SetUnpacked(nx, ny, nz)
	mesh.Begin(MATERIAL_QUADS, G * G)
	for j = 0, G - 1 do
		for i = 0, G - 1 do
			for c = 1, 4 do
				local ii, jj = i + ((c == 2 or c == 3) and 1 or 0), j + ((c >= 3) and 1 or 0)
				local idx = jj * n1 + ii + 1
				vec:SetUnpacked(mvx[idx], mvy[idx], mvz[idx])
				mesh.Position(vec)
				mesh.TexCoord(0, (slot.x + slot.size * ii / G) / page, (slot.y + slot.size * jj / G) / page)
				mesh.Normal(mirrorNrm)
				mesh.Color(255, 255, 255, mva[idx])
				mesh.AdvanceVertex()
			end
		end
	end
	mesh.End()
end

-- Sun glint: where the eye sees the sun mirrored in the (flat) pool, a highlight masked by the wet
-- part of the pool (page B), stretched toward the viewer the flatter the view (the surface is not a
-- perfect mirror). The highlight texture is placed on the pool mesh through the detail transform.
local glintMat, glintCol = Matrix(), Vector()
local trSun, trSunQ = {}, { mask = MASK_OPAQUE }
local vSa, vSb = Vector(), Vector()
local function Glint(p, sx, sy, sz, vis)
	local nx, ny, nz = p.nx, p.ny, p.nz
	local sn = sx * nx + sy * ny + sz * nz
	if sn <= 0.05 then return end
	-- the eye ray that reflects into the sun
	local dx, dy, dz = sx - 2 * sn * nx, sy - 2 * sn * ny, sz - 2 * sn * nz
	local dn = -sn
	local ex, ey, ez = L.eyeX, L.eyeY, L.eyeZ
	local t = ((p.x - ex) * nx + (p.y - ey) * ny + (p.z - ez) * nz) / dn
	if t <= 1 then return end
	local gx, gy, gz = ex + dx * t, ey + dy * t, ez + dz * t
	local u, v = ToLocal(p, gx, gy, gz)
	local cv, slot = p.pcanvas, p.slot
	if abs(u - cv.cu) > cv.H * 0.95 or abs(v - cv.cv) > cv.H * 0.95 then return end
	-- is that spot in the sun? (a trace toward the sun, refreshed now and then)
	local rt = RealTime()
	if rt > (p.sunT or 0) and L.TakeTrace() then
		p.sunT = rt + 0.7 + math.random() * 0.3
		vSa:SetUnpacked(gx + nx, gy + ny, gz + nz)
		vSb:SetUnpacked(gx + sx * 8000, gy + sy * 8000, gz + sz * 8000)
		trSunQ.start, trSunQ.endpos, trSunQ.output = vSa, vSb, trSun
		util.TraceLine(trSunQ)
		p.sunLit = (not trSun.Hit) or trSun.HitSky
	end
	if not p.sunLit then return end
	local cosT = sn
	local S = t * 0.04
	local stretch = Clamp(1 / max(cosT, 0.22), 1, 4)
	-- toward the viewer in the pool plane
	local th = atan2(-(dx * p.tx + dy * p.ty + dz * p.tz), -(dx * p.sx + dy * p.sy + dz * p.sz))
	local page = PCV.page
	local k = slot.size / (2 * cv.H)
	local gpu, gpv = (slot.x + (u - cv.cu + cv.H) * k) / page, (slot.y + (v - cv.cv + cv.H) * k) / page
	local w = page / k
	local ca, sa = cos(th), sin(th)
	local a11, a12 = w * ca / (S * stretch), w * sa / (S * stretch)
	local a21, a22 = -w * sa / S, w * ca / S
	glintMat:Identity()
	glintMat:SetField(1, 1, a11) glintMat:SetField(1, 2, a12)
	glintMat:SetField(2, 1, a21) glintMat:SetField(2, 2, a22)
	glintMat:SetField(1, 4, 0.5 - (a11 * gpu + a12 * gpv))
	glintMat:SetField(2, 4, 0.5 - (a21 * gpu + a22 * gpv))
	-- (its core is white whatever the angle: the sun is that bright. Its halo is not: three times
	-- full white, doubled again by the texture, made a pool in the sun's mirror direction one flat
	-- white shape.)
	local kk = min(PC.glint * vis * (0.8 + 1.5 * ABL.Render.Fresnel(cosT)) * p.fade * (p.sim and 1 or min(1, (p.wet - 0.2) / 0.5)), 0.75)
	if kk <= 0.02 then return end
	local gm = PCV.matGlint
	glintCol:SetUnpacked(kk, kk * 0.97, kk * 0.9)
	gm:SetVector("$color", glintCol)
	gm:SetMatrix("$detailtexturetransform", glintMat)
	render.SetMaterial(gm)
	p.mesh:Draw()
end

function P.Draw()
	if not PCV.ready then return end
	local rt = RealTime()
	local maxD2 = min(C.cl.drawDist:GetFloat(), 3000) ^ 2
	local builds, ns = 0, 0
	local texPx = ScrH() * 1.15
	local dbg = PCV.debug:GetInt()
	local noReflect, softOnly, noFilter = bit.band(dbg, 1) ~= 0, bit.band(dbg, 4) ~= 0, bit.band(dbg, 2) ~= 0
	local filterFade = -1
	-- (developer: the engine's exposure scale as this pass sees it)
	local ts = render.GetToneMappingScaleLinear()
	P.tone = ts and ts.x or 1
	for i = 1, #pools do
		local p = pools[i]
		-- (pools it has taken in and not yet been painted with)
		if p.ghosts then
			render.SetMaterial(PCV.matPool)
			for _, gh in ipairs(p.ghosts) do
				if gh.mesh then gh.mesh:Draw() end
			end
		end
		if p.slot and p.painted and p.pcanvas then
			local d2, vis = L.View(p.cx, p.cy, p.cz, p.rad)
			if vis and d2 < maxD2 then
				-- lighting is baked into the vertex colours: rebuild when it changes noticeably
				if rt > p.lightT then
					p.lightT = rt + 2 + math.random()
					local lr, lg, lb = ABL.Render.Light(p.cx + p.nx * 2, p.cy + p.ny * 2, p.cz + p.nz * 2)
					if abs(lr - (p.lr or -1)) + abs(lg - (p.lg or -1)) + abs(lb - (p.lb or -1)) > 0.06 then
						p.lr, p.lg, p.lb = lr, lg, lb
						p.meshDirty = true
					end
				end
				if (not p.mesh or p.meshDirty) and builds < 4 then
					BuildMesh(p)
					builds = builds + 1
				end
				if p.mesh then
					local d = sqrt(d2)
					local lk = p.look
					-- slot texels per screen pixel: minified slots use the softer outline
					local minif = (p.slot.size / (2 * p.pcanvas.H)) / (texPx / max(d, 1))
					-- what the layer lets through, then its own colour (cl_poolcanvas.lua, PCV.Init).
					-- floor x (colour x fade + 1 - cover x fade): a pool that fades out lets more and more
					-- through, and where the layer covers nothing the floor is what it was
					if not noFilter and p.fade > 0.02 then
						local mf, fa = PCV.matFilter, p.fade
						if fa ~= filterFade then
							filterFade = fa
							filterCol:SetUnpacked(fa, fa, fa)
							mf:SetVector("$color", filterCol)
							mf:SetFloat("$alpha", fa)
						end
						render.SetMaterial(mf)
						render.OverrideBlend(true, BLEND_DST_COLOR, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)
						render.OverrideDepthEnable(true, false)
						p.mesh:Draw()
						render.OverrideDepthEnable(false)
						render.OverrideBlend(false)
					end
					if minif > 1.7 or d > 900 or softOnly then
						render.SetMaterial(PCV.matPoolSoft)
					else
						render.SetMaterial(PCV.matPool)
					end
					p.mesh:Draw()
					-- wet reflection: Fresnel (Schlick, n ~ 1.35) of the view angle, fading as the pool clots
					if not noReflect and lk.wetMode ~= "dry" and (p.sim or p.wet > 0.2) and d < 1400 then
						local dx, dy, dz = p.cx - L.eyeX, p.cy - L.eyeY, p.cz - L.eyeZ
						local cosT = abs(dx * p.nx + dy * p.ny + dz * p.nz) / max(d, 1)
						local F = 0.022 + 0.978 * (1 - cosT) ^ 5
						-- (how wet: a stamp pool's one number, a liquid pool's mask cell by cell)
						local wk = p.sim and 1 or min(1, (p.wet - 0.2) / 0.5)
						local k = PC.sheen * lk.sheen * (0.05 + 1.2 * F) * wk * p.fade
						if k > 0.01 then
							ns = ns + 1
							sheenList[ns], sheenK[ns] = p, min(k, 0.75)
							-- the pool's share of the mirror; how much of the mirrored cubemap (it carries
							-- the scene's brightness itself) each place shows is Fresnel's reflectance at
							-- that place and no more, and no more than mirrorMax: what the map gives a
							-- pool to mirror is a blurred average of its surroundings, and a fifth of
							-- that over the blood is a grey wash with no picture in it, not a reflection
							sheenE[ns] = lk.sheen * wk * p.fade
							-- (the whole pool's reflectance, for one that is small in view; and whether it is)
							sheenF[ns] = (p.rad or 1) > d * 0.1 and -1 or min(F, PC.mirrorMax)
						end
					end
				end
			end
		end
	end
	-- reflections: the wet part mirrors the surroundings, which slide across it as the viewer moves
	if ns > 0 then
		local useEnv = PCV.useEnv:GetBool()
		local sm = PCV.matSheen
		for i = 1, ns do
			local p, k = sheenList[i], sheenK[i]
			-- the nearest of the map's baked cubemaps (none: the generic sheen pattern)
			if useEnv and p.envPath == nil then
				p.envPath = ABL.Render.Cubemap(p.cx, p.cy, p.cz + 8) or false
			end
			if useEnv and p.envPath then
				-- the surroundings mirrored about the surface, weighted by Fresnel and wetness
				-- (what is mirrored takes the place of that much of the blood's own colour: the
				-- material's alpha is the reflectance, its colour the surroundings)
				local em = PCV.EnvMat(p.envPath)
				local e = PC.envStrength
				sheenCol:SetUnpacked(e, e, e)
				em:SetVector("$envmaptint", sheenCol)
				local whole = sheenF[i]
				em:SetFloat("$alpha", whole < 0 and 1 or min(whole * sheenE[i], 1))
				render.SetMaterial(em)
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)
				if whole < 0 then MirrorMesh(p, sheenE[i]) else p.mesh:Draw() end
				render.OverrideBlend(false)
			else
				sheenCol:SetUnpacked(k, k, k)
				sm:SetVector("$color", sheenCol)
				local su = ((L.eyeX * p.sx + L.eyeY * p.sy + L.eyeZ * p.sz) / PC.sheenWorld) % 1
				local sv = ((L.eyeX * p.tx + L.eyeY * p.ty + L.eyeZ * p.tz) / PC.sheenWorld) % 1
				sm:SetMatrix("$detailtexturetransform", PCV.TileTransform(p, PC.sheenWorld, 0, su, sv))
				render.SetMaterial(sm)
				p.mesh:Draw()
			end
		end
		-- the sun mirrored in the wet surface
		if PC.glint > 0 then
			local sx, sy, sz, vis = ABL.Render.Sun()
			if sx then
				for i = 1, ns do Glint(sheenList[i], sx, sy, sz, vis) end
			end
		end
		for i = 1, ns do sheenList[i] = nil end
	end
end

function P.Clear()
	for i = #pools, 1, -1 do Destroy(pools[i]) pools[i] = nil end
	for k in pairs(seeds) do seeds[k] = nil end
	PCV.Clear()
end

function P.Count() return #pools end

-- Developer: the pool as it is with the share `wet` of its blood still wet (thin places dry
-- first), `since` seconds after the dry places went dry.
function P.DevDry(p, wet, since)
	p.lastFeed = CurTime() - 100
	if p.sim then
		local now = CurTime()
		local dried = PS.DryTo(p.sim, wet, now, since) * ML
		if dried > 0 then
			p.vol, p.driedTot = max(0, p.vol - dried), p.driedTot + dried
			ABL.FlowCore.Move("pool", "dried", dried)
		end
		SimAge(p, now, 0)
		UpdateLook(p, now)
		p.dirty = true
		return
	end
	p.wet = wet
	if since then p.dryT = CurTime() - since end
end

-- Totals for the debug HUD / harness.
function P.Totals()
	local blobs, sats, slots = 0, 0, 0
	for _, p in ipairs(pools) do
		for _, b in ipairs(p.blobs) do
			if b.kind == "sat" then sats = sats + 1 else blobs = blobs + 1 end
		end
		if p.slot then slots = slots + 1 end
	end
	return blobs, sats, slots
end

-- Debug overlay: stamp outlines (reach circles), clip lines, canvas square.
function P.DebugDraw(Text3D)
	local col = { body = Color(255, 60, 60), lobe = Color(255, 160, 40), feed = Color(80, 200, 255), neck = Color(200, 80, 255), sat = Color(255, 255, 255), clot = Color(90, 90, 90) }
	local cClip, cCanvas = Color(0, 255, 0), Color(60, 60, 255)
	local cWin, cIn, cOff, cOut = Color(255, 220, 0), Color(0, 255, 255), Color(90, 120, 120), Color(255, 0, 255)
	for _, p in ipairs(pools) do
		local function W(u, v) return Vector(ToWorld(p, u, v, 0.4)) end
		for _, b in ipairs(p.blobs) do
			local r = b.kind == "sat" and b.hs or Reach(b)
			local last
			for s = 0, 16 do
				local a = s / 16 * TWO_PI
				local q = W(b.u + cos(a) * r, b.v + sin(a) * r)
				if last then render.DrawLine(last, q, col[b.kind] or color_white, false) end
				last = q
			end
		end
		for _, c in ipairs(p.clips) do
			local tu, tv = -c.mv, c.mu
			render.DrawLine(W(c.u - tu * 4, c.v - tv * 4), W(c.u + tu * 4, c.v + tv * 4), cClip, false)
			render.DrawLine(W(c.u, c.v), W(c.u + c.mu * 1.5, c.v + c.mv * 1.5), cClip, false)
		end
		if p.canvas then
			local cv = p.canvas
			local a, b, c, d = W(cv.cu - cv.H, cv.cv - cv.H), W(cv.cu + cv.H, cv.cv - cv.H), W(cv.cu + cv.H, cv.cv + cv.H), W(cv.cu - cv.H, cv.cv + cv.H)
			render.DrawLine(a, b, cCanvas, false) render.DrawLine(b, c, cCanvas, false)
			render.DrawLine(c, d, cCanvas, false) render.DrawLine(d, a, cCanvas, false)
		end
		Text3D(Vector(ToWorld(p, 0, 0, 2)), string.format("pool %d %s %.1f ml wet %.2f %s blobs %d slot %s", p.id, p.fam, p.vol, p.wet, p.look.wetMode, #p.blobs, p.slot and p.slot.size or "-"), col.body)
		local g = p.sim
		if g then
			-- the liquid: the window that is still moving, where blood arrives, where it leaves
			local now = CurTime()
			if PS.Active(g) then
				local a = g.a
				local u0, v0, u1, v1 = (g.i0 + g.ax0) * a, (g.j0 + g.ay0) * a, (g.i0 + g.ax1 + 1) * a, (g.j0 + g.ay1 + 1) * a
				render.DrawLine(W(u0, v0), W(u1, v0), cWin, false) render.DrawLine(W(u1, v0), W(u1, v1), cWin, false)
				render.DrawLine(W(u1, v1), W(u0, v1), cWin, false) render.DrawLine(W(u0, v1), W(u0, v0), cWin, false)
			end
			for _, e in ipairs(p.inlets) do
				local on = now - e.last < 2
				render.DrawLine(W(e.u, e.v), Vector(ToWorld(p, e.u, e.v, on and 3 or 1.2)), on and cIn or cOff, false)
			end
			for c, x in pairs(g.out) do
				local u, v = (g.i0 + (c - 1) % g.n + 0.5) * g.a, (g.j0 + floor((c - 1) / g.n) + 0.5) * g.a
				render.DrawLine(W(u, v), Vector(ToWorld(p, u, v, -1.5)), x > 0 and cIn or cOut, false)
			end
			-- where it is flowing: down the free surface, a longer line the faster
			local n, a = g.n, g.a
			local h, zf, sh = g.h, g.zf, g.sh
			local skip = (g.bx1 - g.bx0 > 24) and 2 or 1
			for j = max(g.by0, 1), min(g.by1, n - 2), skip do
				for i = max(g.bx0, 1), min(g.bx1, n - 2), skip do
					local c = j * n + i + 1
					local hh = h[c]
					if hh > 0 and sh[c] > 0.5 then
						local z0 = zf[c] + hh
						local gu = (h[c + 1] > 0 and zf[c + 1] + h[c + 1] or z0) - (h[c - 1] > 0 and zf[c - 1] + h[c - 1] or z0)
						local gv = (h[c + n] > 0 and zf[c + n] + h[c + n] or z0) - (h[c - n] > 0 and zf[c - n] + h[c - n] or z0)
						local gl = sqrt(gu * gu + gv * gv)
						if gl > 1e-7 then
							local len = (min(sh[c] * hh / 3, 1.5) * 0.6 + 0.1) / gl
							local u, v = (g.i0 + i + 0.5) * a, (g.j0 + j + 0.5) * a
							render.DrawLine(W(u, v), W(u - gu * len, v - gv * len), cOut, false)
						end
					end
				end
			end
			local st = PS.Stats(g, now)
			local scale = C.sv.drying:GetFloat()
			local all = g.liq + g.gel + g.dep + g.soak
			Text3D(Vector(ToWorld(p, 0, 0, 3.2)), string.format("in %.1f out %.1f ml | layer %.3f / %.3f (film %.3f) | speed %.2f / %.2f u/s | age %.0f s clot %.2f dry %.2f | %s",
				p.inTot, p.outTot, st.hMean, st.hMax, g.film, st.uMean, st.uMax, st.age, all > 0 and g.gel / all or 0, all > 0 and (g.dep + g.soak) / all or 0, p.surf.name or "?"), cIn)
			Text3D(Vector(ToWorld(p, 0, 0, 4.4)), "liquid" .. P.SimInfo(p) .. string.format(" | clotting time %.0f s", C.Flow.clotTime * scale), cWin)
		end
	end
end
