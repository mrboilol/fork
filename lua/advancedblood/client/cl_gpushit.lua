ABL.NoJIT()
ABL.GPU = ABL.GPU or {}
local GP = ABL.GPU
local C = ABL.Config
local min, max, sqrt, floor, abs, ceil = math.min, math.max, math.sqrt, math.floor, math.abs, math.ceil

local PREFIX = "ablgpu2_"
local SHADERS = {
	"clip_vs30", "world_vs30", "blit_ps30", "stamp_ps30", "sim_ps30", "surface_ps30",
	"unwrap_vs30", "geo_ps30", "none_ps30", "model_vs30", "simbody_ps30", "bodyfilm_ps30",
	"bed_ps30", "drain_ps30", "sinkclear_ps30",
}

local PATCH_UNITS = 96
local RES = 192
local TEXEL_UNITS = PATCH_UNITS / RES
local TEXEL_MM2 = (TEXEL_UNITS * 25.4) ^ 2
local MM_PER_UNIT = 25.4
local ML_TO_MM3 = 1000
local STAMP_INTEGRAL = 0.995
local MIN_STAMP_TEXELS = 0.75
local MAX_STRETCH = 4
local MAX_STAMPS = 384
local PLANE_DOT = 0.985
local PLANE_DIST = 1.5
local CEILING_Z = -0.4
local FLOOR_Z = 0.7
local LIFT = 0.08
local DEFAULT_TEX_UNITS = 128
local TEX_SCALE = 0.25
local POOL_REST_MM = 1.5
local POUR_SPREAD = 0.6
local DRAW_DIST = 4000
local LIGHT_REFRESH = 2
local LIGHT_FLOOR = 0.04
local NOISE_RES = 32
local NOISE_UNITS = 32
local NOISE_TILT = 0.45

local GRID = 32
local CELL_TEXELS = RES / GRID
local PROBE_UP = 4
local PROBE_DOWN = 24
local LEDGE = 3
local RING_OUT = 1.5
local PROBES_PER_FRAME = 360
local WALL_V = 1000
local VOID_V = -1000
local BORDER_V = -2000

local DRAIN_RES = 24
local DRAIN_BLOCK = RES / DRAIN_RES
local DRAIN_STEP_MM = 2
local DRAIN_INTERVAL = 0.4
local DROP_MAX_ML = 1.5
local DROP_MAX_N = 4
local DROP_JITTER = 1.5
local DROP_SPEED = 12
local SPAWN_LIFT = 0.8
local SPAWN_UP_STEP = 2
local SPAWN_UP_TRIES = 4
local HANDOFF_PUSH = DRAIN_BLOCK * TEXEL_UNITS * 0.5 + RING_OUT
local HANDOFF_RADIUS = 1.5

local SIM_HZ = 60
local MAX_STEPS = 2
local ACTIVE_HOLD = 25
local DRY_TIME = 180
local SLOW_DT = 0.25

local K_FLOW = 20
local H_PIN = 0.06
local K_GRAV = 1
local K_RELIEF = 1.2
local DRY_RATE = 0.02
local EVAP = 0.004
local MAX_FLUX = 0.12
local EDGE_PIN = 1.5
local ABSORB = 12
local STAIN_ABSORB = 8
local SHINE = 0.9

local RT_CLAMP_S, RT_CLAMP_T, RT_NOMIP, RT_NOLOD, RT_RENDERTARGET = 4, 8, 256, 512, 32768
local RT_FLAGS = bit.bor(RT_CLAMP_S, RT_CLAMP_T, RT_NOMIP, RT_NOLOD, RT_RENDERTARGET)
local RT_WRAP_FLAGS = bit.bor(RT_NOMIP, RT_NOLOD, RT_RENDERTARGET)

GP.cvPatches = CreateClientConVar("abl_gpu_patches", "24", true, false, "GPU blood: simulated surface patches (each one 96x96 units of floor or wall).", 4, 64)

GP.failed = nil
GP.verified = nil
for _, p in ipairs(GP.patches or {}) do
	if p.mesh then p.mesh:Destroy() end
end
GP.patches = {}
GP.slots = {}
GP.session = string.format("%x", floor(SysTime() * 1000) % 0xFFFFFF)

local patches, slots = GP.patches, GP.slots
local shadersOK
local readyT, ready = 0, false

local function ShadersPresent()
	if shadersOK ~= nil then return shadersOK end
	shadersOK = true
	for _, s in ipairs(SHADERS) do
		if not file.Exists("shaders/fxc/" .. PREFIX .. s .. ".vcs", "GAME") then shadersOK = false break end
	end

	return shadersOK
end

local function Check()
	if GP.failed or not C.cl.gpu:GetBool() then return false end
	if render.GetDXLevel() < 90 then return false end

	return ShadersPresent()
end

local function Capable()
	local now = RealTime()
	if now < readyT then return ready end
	readyT = now + 1
	ready = Check()

	return ready
end

function GP.Ready()
	return GP.verified == true and Capable()
end

local function RT(name, fmt, size, flags)
	return GetRenderTargetEx("ablgpu_" .. name, size, size, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE, flags or RT_FLAGS, 0, fmt)
end

local MODEL_FLAGS = { ["$model"] = 1, ["$softwareskin"] = 1, ["$vertexnormal"] = 1 }

local function Mat(tag, vs, ps, depth, model)
	local kv = {
		["$vertexshader"] = PREFIX .. vs,
		["$pixshader"] = PREFIX .. ps,
		["$basetexture"] = "vgui/white",
		["$texture1"] = "vgui/white",
		["$texture2"] = "vgui/white",
		["$texture3"] = "vgui/white",
		["$linearread_basetexture"] = 1,
		["$linearread_texture1"] = 1,
		["$linearread_texture2"] = 1,
		["$linearread_texture3"] = 1,
		["$linearwrite"] = 1,
		["$copyalpha"] = 1,
		["$cull"] = 0,
		["$depthtest"] = depth and 1 or 0,
		["$vertextransform"] = (depth or model) and 1 or 0,
		["$tcsize0"] = 4,
		["$tcsize1"] = 4,
		["$c0_x"] = 0,
	}
	if model then
		for k, v in pairs(MODEL_FLAGS) do kv[k] = v end
	end

	return CreateMaterial("ablgpu_" .. GP.session .. "_" .. tag, "screenspace_general", kv)
end

local CNAMES = {}
for i = 0, 3 do CNAMES[i] = { "$c" .. i .. "_x", "$c" .. i .. "_y", "$c" .. i .. "_z", "$c" .. i .. "_w" } end

local function SetC(mat, i, x, y, z, w)
	local n = CNAMES[i]
	mat:SetFloat(n[1], x)
	mat:SetFloat(n[2], y)
	mat:SetFloat(n[3], z)
	mat:SetFloat(n[4], w)
end

local shared
local function Shared()
	if shared then return shared end
	local s = {}
	s.inflow = RT("inflow", IMAGE_FORMAT_RGBA16161616F, RES)
	s.zero = RT("zero", IMAGE_FORMAT_RGBA8888, 4)
	s.noise = RT("relief", IMAGE_FORMAT_RGBA8888, NOISE_RES, RT_WRAP_FLAGS)
	s.drainRT = RT("drain", IMAGE_FORMAT_RGBA8888, DRAIN_RES)
	s.blit = Mat("blit", "clip_vs30", "blit_ps30")
	s.stamp = Mat("stamp", "clip_vs30", "stamp_ps30")
	s.bed = Mat("bed", "clip_vs30", "bed_ps30")
	shared = s

	return s
end

local function DrawNoise()
	for y = 0, NOISE_RES - 1 do
		for x = 0, NOISE_RES - 1 do
			local nx, ny = math.Rand(-NOISE_TILT, NOISE_TILT), math.Rand(-NOISE_TILT, NOISE_TILT)
			local nz = sqrt(max(1 - nx * nx - ny * ny, 0))
			surface.SetDrawColor((nx * 0.5 + 0.5) * 255, (ny * 0.5 + 0.5) * 255, (nz * 0.5 + 0.5) * 255, 255)
			surface.DrawRect(x, y, 1, 1)
		end
	end
end

local function Prepare()
	local s = Shared()
	if s.prepared then return end
	s.prepared = true
	render.PushRenderTarget(s.zero) render.Clear(0, 0, 0, 0) render.PopRenderTarget()
	render.PushRenderTarget(s.noise)
	cam.Start2D()
	DrawNoise()
	cam.End2D()
	render.PopRenderTarget()
end

local function NewSlot(i)
	local s = Shared()
	local slot = { index = i }
	slot.rt = { RT("state" .. i .. "a", IMAGE_FORMAT_RGBA16161616F, RES), RT("state" .. i .. "b", IMAGE_FORMAT_RGBA16161616F, RES) }
	slot.sim, slot.draw, slot.drain, slot.clear = {}, {}, {}, {}
	for k = 1, 2 do
		local sim = Mat("sim" .. i .. "_" .. k, "clip_vs30", "sim_ps30")
		sim:SetTexture("$basetexture", slot.rt[k])
		sim:SetTexture("$texture1", s.zero)
		SetC(sim, 0, 1 / RES, 1 / SIM_HZ, K_FLOW, H_PIN)
		SetC(sim, 3, DRY_RATE, EVAP, MAX_FLUX, EDGE_PIN)
		slot.sim[k] = sim
		local draw = Mat("draw" .. i .. "_" .. k, "world_vs30", "surface_ps30", true)
		draw:SetTexture("$basetexture", slot.rt[k])
		SetC(draw, 0, 1 / RES, ABSORB, STAIN_ABSORB, SHINE)
		slot.draw[k] = draw
		local drain = Mat("drain" .. i .. "_" .. k, "clip_vs30", "drain_ps30")
		drain:SetTexture("$basetexture", slot.rt[k])
		SetC(drain, 0, 1 / (DRAIN_STEP_MM * 255), 0, 0, 0)
		slot.drain[k] = drain
		local clear = Mat("clear" .. i .. "_" .. k, "clip_vs30", "sinkclear_ps30")
		clear:SetTexture("$basetexture", slot.rt[k])
		clear:SetTexture("$texture1", s.drainRT)
		slot.clear[k] = clear
	end
	slots[i] = slot

	return slot
end

local corners = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }
local vtmp = Vector()

local function NDC(px, py, res)
	vtmp:SetUnpacked((px / res) * 2 - 1 - 1 / res, 1 - (py / res) * 2 + 1 / res, 0)
	return vtmp
end

local function RectQuads(list, res, payload)
	res = res or RES
	local n = #list
	if n == 0 then return end
	cam.Start2D()
	mesh.Begin(MATERIAL_QUADS, n)
	for i = 1, n do
		local q = list[i]
		for ci = 1, 4 do
			local c = corners[ci]
			local px = c[1] == 0 and q[1] or q[3]
			local py = c[2] == 0 and q[2] or q[4]
			mesh.Position(NDC(px, py, res))
			mesh.TexCoord(0, px / res, py / res)
			mesh.TexCoord(1, payload or 0, 0)
			mesh.AdvanceVertex()
		end
	end
	mesh.End()
	cam.End2D()
end

local FULL = { { 0, 0, RES, RES } }

local function FullQuad(res)
	if res and res ~= RES then
		RectQuads({ { 0, 0, res, res } }, res)
		return
	end
	RectQuads(FULL)
end

local LOCAL_CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }

local function StampQuads(list, res)
	res = res or RES
	local n = #list
	cam.Start2D()
	mesh.Begin(MATERIAL_QUADS, n)
	for i = 1, n do
		local st = list[i]
		local cx, cy, a, b, du, dv = st[1], st[2], st[3], st[4], st[5], st[6]
		for ci = 1, 4 do
			local lc = LOCAL_CORNERS[ci]
			local ox = lc[1] * a * du - lc[2] * b * dv
			local oy = lc[1] * a * dv + lc[2] * b * du
			mesh.Position(NDC(cx + ox, cy + oy, res))
			mesh.TexCoord(0, lc[1], lc[2])
			mesh.TexCoord(1, st[7], 0)
			mesh.AdvanceVertex()
		end
	end
	mesh.End()
	cam.End2D()
end

local AXES = {
	z = { Vector(1, 0, 0), Vector(0, -1, 0) },
	x = { Vector(0, 1, 0), Vector(0, 0, -1) },
	y = { Vector(1, 0, 0), Vector(0, 0, -1) },
}

local function Basis(n)
	local ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
	local key = (az >= ax and az >= ay) and "z" or (ax >= ay and "x" or "y")
	local tu, tv = AXES[key][1], AXES[key][2]
	local u = tu - n * tu:Dot(n)
	u:Normalize()
	local v = tv - n * tv:Dot(n) - u * tv:Dot(u)
	v:Normalize()

	return u, v, tu, tv
end

local function TexUnits(texName)
	local m = texName and Material(texName)
	if not m or m:IsError() then return DEFAULT_TEX_UNITS, DEFAULT_TEX_UNITS, nil end
	local base = m:GetTexture("$basetexture")
	local w, h = DEFAULT_TEX_UNITS, DEFAULT_TEX_UNITS
	if base and not base:IsError() then w, h = base:Width() * TEX_SCALE, base:Height() * TEX_SCALE end
	local bump
	if m:GetInt("$ssbump") ~= 1 then
		local bt = m:GetTexture("$bumpmap")
		if bt and not bt:IsError() then bump = bt end
	end

	return max(w, 1), max(h, 1), bump
end

local probeTrace = { mask = MASK_SOLID_BRUSHONLY }
local probeOut = {}
probeTrace.output = probeOut
local pA, pB = Vector(), Vector()

local function PlanePoint(p, su, sv)
	return p.origin + p.u * su + p.v * sv
end

local function Probe(p, w)
	pA:Set(w) pA:Add(p.n * PROBE_UP)
	pB:Set(w) pB:Sub(p.n * PROBE_DOWN)
	probeTrace.start, probeTrace.endpos = pA, pB
	util.TraceLine(probeTrace)
	local tr = probeOut
	if tr.StartSolid then return p.floor and WALL_V or VOID_V end
	if not tr.Hit or tr.HitSky then return VOID_V end
	local depth = tr.Fraction * (PROBE_UP + PROBE_DOWN) - PROBE_UP
	if depth > LEDGE then return VOID_V end
	if depth < -LEDGE then return WALL_V end

	return -depth
end

local RING_SIDES = {
	{ 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 },
}

local function RingPoint(p, side, i)
	local d = RING_SIDES[side]
	local t = (i + 0.5) / GRID * PATCH_UNITS
	if d[1] == 0 then
		local sv = d[2] < 0 and -RING_OUT or PATCH_UNITS + RING_OUT

		return PlanePoint(p, t, sv)
	end
	local su = d[1] < 0 and -RING_OUT or PATCH_UNITS + RING_OUT

	return PlanePoint(p, su, t)
end

local GRID_POINTS = (GRID + 1) * (GRID + 1)
local RING_POINTS = 4 * GRID

local function ProbeStep(p, budget)
	local i = p.probeI
	local total = GRID_POINTS + RING_POINTS
	while i < total and budget > 0 do
		if i < GRID_POINTS then
			local gx, gy = i % (GRID + 1), floor(i / (GRID + 1))
			p.bed[i] = Probe(p, PlanePoint(p, gx / GRID * PATCH_UNITS, gy / GRID * PATCH_UNITS))
		else
			local r = i - GRID_POINTS
			p.ring[r] = Probe(p, RingPoint(p, floor(r / GRID) + 1, r % GRID))
		end
		i = i + 1
		budget = budget - 1
	end
	p.probeI = i

	return budget, i >= total
end

local function BedAt(p, gx, gy)
	return p.bed[gy * (GRID + 1) + gx]
end

local function Sentinel(v)
	return v >= WALL_V or v <= VOID_V
end

local function Upload(p, v)
	if Sentinel(v) then return v end

	return v * MM_PER_UNIT * p.kBed
end

local function GridQuads(p)
	cam.Start2D()
	mesh.Begin(MATERIAL_QUADS, GRID * GRID)
	for gy = 0, GRID - 1 do
		for gx = 0, GRID - 1 do
			for ci = 1, 4 do
				local c = corners[ci]
				local cx, cy = gx + c[1], gy + c[2]
				local px, py = cx * CELL_TEXELS, cy * CELL_TEXELS
				mesh.Position(NDC(px, py, RES))
				mesh.TexCoord(0, px / RES, py / RES)
				mesh.TexCoord(1, Upload(p, BedAt(p, cx, cy)), 0)
				mesh.AdvanceVertex()
			end
		end
	end
	mesh.End()
	cam.End2D()
end

local function RingRect(side, i)
	local d = RING_SIDES[side]
	local a, b = i * CELL_TEXELS, (i + 1) * CELL_TEXELS
	if d[1] == 0 then
		local y = d[2] < 0 and 0 or RES - 1

		return { a, y, b, y + 1 }
	end
	local x = d[1] < 0 and 0 or RES - 1

	return { x, a, x + 1, b }
end

local function RingQuads(p)
	local lists = { [BORDER_V] = {}, [VOID_V] = {}, [WALL_V] = {} }
	for r = 0, RING_POINTS - 1 do
		local v = p.ring[r]
		local kind = v >= WALL_V and WALL_V or (v <= VOID_V and VOID_V or BORDER_V)
		local l = lists[kind]
		l[#l + 1] = RingRect(floor(r / GRID) + 1, r % GRID)
	end
	for value, list in pairs(lists) do RectQuads(list, RES, value) end
end

local function InitState(p)
	local s = Shared()
	for k = 1, 2 do
		render.PushRenderTarget(p.slot.rt[k])
		render.Clear(0, 0, 0, 0)
		render.SetMaterial(s.bed)
		GridQuads(p)
		RingQuads(p)
		render.PopRenderTarget()
	end
	p.pending = nil
end

local function MeshVertex(p, gx, gy)
	local v = BedAt(p, gx, gy)
	local h = Sentinel(v) and 0 or v

	return {
		pos = PlanePoint(p, gx / GRID * PATCH_UNITS, gy / GRID * PATCH_UNITS) + p.n * (h + LIFT),
		normal = p.n, u = gx / GRID, v = gy / GRID,
	}
end

local function BuildMesh(p)
	local verts = {}
	for gy = 0, GRID - 1 do
		for gx = 0, GRID - 1 do
			local a, b = MeshVertex(p, gx, gy), MeshVertex(p, gx + 1, gy)
			local c, d = MeshVertex(p, gx + 1, gy + 1), MeshVertex(p, gx, gy + 1)
			verts[#verts + 1] = a verts[#verts + 1] = b verts[#verts + 1] = c
			verts[#verts + 1] = a verts[#verts + 1] = c verts[#verts + 1] = d
		end
	end
	local m = Mesh()
	m:BuildFromTriangles(verts)
	p.mesh = m
end

local function Release(p)
	if p.mesh then p.mesh:Destroy() p.mesh = nil end
	if p.slot then p.slot.patch = nil end
	for i = #patches, 1, -1 do
		if patches[i] == p then table.remove(patches, i) break end
	end
end

local function TakeSlot()
	local cap = GP.cvPatches:GetInt()
	for i = 1, cap do
		local slot = slots[i] or NewSlot(i)
		if not slot.patch then return slot end
	end
	local oldest
	for _, p in ipairs(patches) do
		if p.slot.index <= cap and (not oldest or p.last < oldest.last) then oldest = p end
	end
	if not oldest then return nil end
	local slot = oldest.slot
	Release(oldest)

	return slot
end

local function Gravity(p)
	local gx, gy, gz = ABL.Gravity()
	local g = Vector(gx, gy, gz)
	g:Normalize()
	p.g = g
	p.gu, p.gv = g:Dot(p.u), g:Dot(p.v)
	p.kBed = max(-g:Dot(p.n), 0)
end

local function SetupMaterials(p, bump, texW, texH)
	if not bump then texW, texH = NOISE_UNITS, NOISE_UNITS end
	local u0, v0 = p.origin:Dot(p.tu) / texW, p.origin:Dot(p.tv) / texH
	local su, sv = PATCH_UNITS * p.u:Dot(p.tu) / texW, PATCH_UNITS * p.v:Dot(p.tv) / texH
	for k = 1, 2 do
		local sim = p.slot.sim[k]
		sim:SetTexture("$texture2", bump or Shared().noise)
		SetC(sim, 1, p.gu, p.gv, K_GRAV, K_RELIEF)
		SetC(sim, 2, u0, v0, su, sv)
	end
end

local function NewPatch(pos, n, texName)
	local slot = TakeSlot()
	if not slot then return nil end
	local u, v, tu, tv = Basis(n)
	local s0 = floor(pos:Dot(u) / PATCH_UNITS) * PATCH_UNITS
	local t0 = floor(pos:Dot(v) / PATCH_UNITS) * PATCH_UNITS
	local dist = n:Dot(pos)
	local p = {
		slot = slot, n = Vector(n), u = u, v = v, tu = tu, tv = tv, dist = dist, texName = texName,
		floor = n.z >= FLOOR_Z, stamps = {}, last = RealTime(), lightT = 0, light = Vector(1, 1, 1),
		cur = 1, pending = true, probeI = 0, bed = {}, ring = {},
	}
	p.origin = u * s0 + v * t0 + p.n * dist
	p.center = PlanePoint(p, PATCH_UNITS * 0.5, PATCH_UNITS * 0.5)
	slot.patch = p
	Gravity(p)
	local texW, texH, bump = TexUnits(texName)
	SetupMaterials(p, bump, texW, texH)
	patches[#patches + 1] = p

	return p
end

local function UV(p, pos)
	local d = pos - p.origin

	return d:Dot(p.u) / PATCH_UNITS, d:Dot(p.v) / PATCH_UNITS
end

local function Find(pos, n)
	for _, p in ipairs(patches) do
		if p.n:Dot(n) > PLANE_DOT and abs(p.n:Dot(pos) - p.dist) < PLANE_DIST then
			local u, v = UV(p, pos)
			if u >= 0 and u < 1 and v >= 0 and v < 1 then return p, u, v end
		end
	end
end

local function Usable(tr)
	if not tr.Hit or tr.HitSky or tr.HitNoDraw then return false end
	if not tr.HitWorld and not (IsValid(tr.Entity) and tr.Entity:IsWorld()) then return false end

	return tr.HitNormal.z >= CEILING_Z
end

local function Stamp(p, u, v, radiusU, volMM3, du, dv, stretch)
	local list = p.stamps
	local rT = max(radiusU / TEXEL_UNITS, MIN_STAMP_TEXELS)
	local a, b = rT * stretch, rT
	local peak = volMM3 / (STAMP_INTEGRAL * a * b * TEXEL_MM2)
	if #list >= MAX_STAMPS then
		local last = list[#list]
		last[7] = last[7] + peak * (a * b) / (last[3] * last[4])
	else
		list[#list + 1] = { u * RES, v * RES, a, b, du, dv, peak }
	end
	p.last = RealTime()
end

local function Patch(pos, n, texName)
	local p, u, v = Find(pos, n)
	if p then return p, u, v end
	p = NewPatch(pos, n, texName)
	if not p then return nil end
	u, v = UV(p, pos)

	return p, u, v
end

function GP.Land(d, tr, vol, radius, vx, vy, vz)
	if not GP.Ready() or not (vol > 0) or not Usable(tr) then return false end
	local n = tr.HitNormal
	local p, u, v = Patch(tr.HitPos, n, tr.HitTexture)
	if not p then return false end
	local vel = Vector(vx, vy, vz)
	local sp = vel:Length()
	local tan = vel - n * vel:Dot(n)
	local vt = tan:Length()
	local du, dv, stretch = 1, 0, 1
	if vt > 1e-3 and sp > 1e-3 then
		du, dv = tan:Dot(p.u) / vt, tan:Dot(p.v) / vt
		local sinA = max(-vel:Dot(n), 0) / sp
		stretch = math.Clamp(1 / max(sinA, 0.25), 1, MAX_STRETCH)
	end
	Stamp(p, u, v, radius, vol * ML_TO_MM3, du, dv, stretch)

	return true
end

local pourTrace = { mask = MASK_SOLID_BRUSHONLY }
local qA, qB = Vector(), Vector()

function GP.Pour(x, y, z, n, vol, dx, dy, dz)
	if not GP.Ready() or not (vol > 0) or n.z < CEILING_Z then return false end
	local pos = Vector(x, y, z)
	local p, u, v = Find(pos, n)
	if not p then
		qA:SetUnpacked(x + n.x * 2, y + n.y * 2, z + n.z * 2)
		qB:SetUnpacked(x - n.x * 4, y - n.y * 4, z - n.z * 4)
		pourTrace.start, pourTrace.endpos = qA, qB
		local tr = util.TraceLine(pourTrace)
		if not Usable(tr) then return false end
		p, u, v = Patch(tr.HitPos, tr.HitNormal, tr.HitTexture)
		if not p then return false end
	end
	local mm3 = vol * ML_TO_MM3
	local radius = sqrt(mm3 / (math.pi * POOL_REST_MM)) / 25.4 * POUR_SPREAD
	local du, dv = 1, 0
	if dx then
		local dir = Vector(dx, dy, dz)
		local l = sqrt(dir:Dot(p.u) ^ 2 + dir:Dot(p.v) ^ 2)
		if l > 1e-3 then du, dv = dir:Dot(p.u) / l, dir:Dot(p.v) / l end
	end
	Stamp(p, u, v, radius, mm3, du, dv, 1)

	return true
end

local function Additive(on)
	if on then
		render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)
	else
		render.OverrideBlend(false)
	end
end

local function StepPatch(p, steps, dt)
	local s = Shared()
	local hasInflow = #p.stamps > 0
	if hasInflow then
		render.PushRenderTarget(s.inflow)
		render.Clear(0, 0, 0, 0)
		render.SetMaterial(s.stamp)
		Additive(true)
		StampQuads(p.stamps)
		Additive(false)
		render.PopRenderTarget()
		p.stamps = {}
	end
	for i = 1, steps do
		local from = p.cur
		local to = 3 - from
		local sim = p.slot.sim[from]
		sim:SetTexture("$texture1", (i == 1 and hasInflow) and s.inflow or s.zero)
		sim:SetFloat("$c0_y", dt)
		render.PushRenderTarget(p.slot.rt[to])
		render.SetMaterial(sim)
		FullQuad()
		render.PopRenderTarget()
		p.cur = to
	end
end

local function DrainVolume(k)
	return k * DRAIN_STEP_MM * TEXEL_MM2 / ML_TO_MM3
end

local function BlockCenter(p, bx, by)
	local half = DRAIN_BLOCK * 0.5

	return PlanePoint(p, (bx * DRAIN_BLOCK + half) * TEXEL_UNITS, (by * DRAIN_BLOCK + half) * TEXEL_UNITS)
end

local function FreeSpot(pos)
	for _ = 1, SPAWN_UP_TRIES do
		if bit.band(util.PointContents(pos), CONTENTS_SOLID) == 0 then return pos end
		pos.z = pos.z + SPAWN_UP_STEP
	end

	return pos
end

local function SpawnFall(p, bx, by, vol)
	local pos = FreeSpot(BlockCenter(p, bx, by) + p.n * SPAWN_LIFT)
	local tan = p.u * p.gu + p.v * p.gv
	local n = min(DROP_MAX_N, ceil(vol / DROP_MAX_ML))
	local each = vol / n
	for _ = 1, n do
		local x = pos.x + math.Rand(-DROP_JITTER, DROP_JITTER)
		local y = pos.y + math.Rand(-DROP_JITTER, DROP_JITTER)
		local vx = tan.x * DROP_SPEED + p.g.x * DROP_SPEED * 0.5
		local vy = tan.y * DROP_SPEED + p.g.y * DROP_SPEED * 0.5
		local vz = tan.z * DROP_SPEED + p.g.z * DROP_SPEED * 0.5
		ABL.Drops.Spawn(x, y, pos.z, vx, vy, vz, each, nil, 0, 0, "dried")
	end
end

local function Handoff(p, bx, by, vol)
	local ox = bx == 0 and -1 or (bx == DRAIN_RES - 1 and 1 or 0)
	local oy = by == 0 and -1 or (by == DRAIN_RES - 1 and 1 or 0)
	if ox == 0 and oy == 0 then SpawnFall(p, bx, by, vol) return end
	local l = sqrt(ox * ox + oy * oy)
	local du, dv = ox / l, oy / l
	local target = BlockCenter(p, bx, by) + (p.u * du + p.v * dv) * HANDOFF_PUSH
	local np, nu, nv = Patch(target, p.n, p.texName)
	if not np or np == p then SpawnFall(p, bx, by, vol) return end
	Stamp(np, nu, nv, HANDOFF_RADIUS, vol * ML_TO_MM3, du, dv, 1)
end

local function Drain(p)
	local s = Shared()
	render.PushRenderTarget(s.drainRT)
	render.Clear(0, 0, 0, 255)
	render.SetMaterial(p.slot.drain[p.cur])
	FullQuad(DRAIN_RES)
	render.CapturePixels()
	local found
	for by = 0, DRAIN_RES - 1 do
		for bx = 0, DRAIN_RES - 1 do
			local r, g = render.ReadPixel(bx, by)
			if r > 0 or g > 0 then
				found = found or {}
				found[#found + 1] = { bx, by, r, g }
			end
		end
	end
	render.PopRenderTarget()
	if not found then return end
	local to = 3 - p.cur
	render.PushRenderTarget(p.slot.rt[to])
	render.SetMaterial(p.slot.clear[p.cur])
	FullQuad()
	render.PopRenderTarget()
	p.cur = to
	for _, f in ipairs(found) do
		if f[3] > 0 then SpawnFall(p, f[1], f[2], DrainVolume(f[3])) end
		if f[4] > 0 then Handoff(p, f[1], f[2], DrainVolume(f[4])) end
	end
end

local drainIdx = 0

local function DrainOne(now)
	local n = #patches
	for _ = 1, n do
		drainIdx = drainIdx % n + 1
		local p = patches[drainIdx]
		if not p.pending and now >= (p.drainT or 0) and now - p.last < DRY_TIME then
			p.drainT = now + DRAIN_INTERVAL
			Drain(p)
			return
		end
	end
end

local simAcc = 0
local SELFTEST_RES = 16
local SELFTEST_MIN = 200

local function SelfTest()
	local rt = RT("selftest", IMAGE_FORMAT_RGBA8888, SELFTEST_RES)
	render.PushRenderTarget(rt)
	render.Clear(0, 0, 0, 255)
	render.SetMaterial(Shared().blit)
	RectQuads({ { 0, 0, SELFTEST_RES, SELFTEST_RES } }, SELFTEST_RES, 1)
	render.CapturePixels()
	local r = render.ReadPixel(SELFTEST_RES / 2, SELFTEST_RES / 2)
	render.PopRenderTarget()

	return r and r >= SELFTEST_MIN
end

local function SimFrame()
	local now = RealTime()
	simAcc = min(simAcc + FrameTime(), MAX_STEPS / SIM_HZ)
	local steps = floor(simAcc * SIM_HZ)
	simAcc = simAcc - steps / SIM_HZ
	Prepare()
	if GP.BodySim then GP.BodySim(now, steps) end
	local budget = PROBES_PER_FRAME
	for _, p in ipairs(patches) do
		if p.pending then
			if budget > 0 then
				local done
				budget, done = ProbeStep(p, budget)
				if done then
					BuildMesh(p)
					InitState(p)
				end
			end
		else
			local idle = now - p.last
			if #p.stamps > 0 or idle < ACTIVE_HOLD then
				if steps > 0 then StepPatch(p, steps, 1 / SIM_HZ) end
			elseif idle < DRY_TIME and now >= (p.slowT or 0) then
				p.slowT = now + SLOW_DT
				StepPatch(p, 1, SLOW_DT)
			end
		end
	end
	DrainOne(now)
end

GP.RT, GP.Mat, GP.SetC, GP.Shared, GP.Prepare = RT, Mat, SetC, Shared, Prepare
GP.FullQuad, GP.StampQuads, GP.Additive = FullQuad, StampQuads, Additive
GP.SIM_HZ, GP.ACTIVE_HOLD, GP.DRY_TIME, GP.SLOW_DT = SIM_HZ, ACTIVE_HOLD, DRY_TIME, SLOW_DT

local function Fail(err)
	GP.failed = true
	ready = false
	ErrorNoHalt("[ABL] GPU blood disabled, CPU simulation takes over: " .. tostring(err) .. "\n")
end

GP.Fail = Fail

local function Busy()
	return #patches > 0 or (GP.BodyCount and GP.BodyCount() > 0)
end

local function Verify()
	if not Capable() then return end
	local rt = render.GetRenderTarget()
	local ok, passed = pcall(SelfTest)
	if render.GetRenderTarget() ~= rt then render.PopRenderTarget() end
	GP.verified = ok and passed == true
	if not GP.verified then Fail(ok and "custom shaders did not run (self-test read back nothing)" or passed) end
end

hook.Add("PostRender", "ABL_GPUSim", function()
	if GP.verified == nil then
		Verify()
		return
	end
	if not Busy() or not GP.Ready() then return end
	local rt = render.GetRenderTarget()
	local ok, err = pcall(SimFrame)
	if ok then return end
	for _ = 1, 8 do
		if render.GetRenderTarget() == rt then break end
		render.PopRenderTarget()
	end
	render.OverrideBlend(false)
	render.MaterialOverrideByIndex()
	Fail(err)
end)

local function DrawPatches()
	local eye = EyePos()
	local now = RealTime()
	for _, p in ipairs(patches) do
		local toEye = eye - p.center
		if not p.pending and toEye:Dot(p.n) > 0 and toEye:LengthSqr() < DRAW_DIST * DRAW_DIST then
			if now >= p.lightT then
				p.lightT = now + LIGHT_REFRESH
				local l = render.GetLightColor(p.center + p.n * 4)
				p.light = Vector(max(l.x, LIGHT_FLOOR), max(l.y, LIGHT_FLOOR), max(l.z, LIGHT_FLOOR))
			end
			local mat = p.slot.draw[p.cur]
			SetC(mat, 1, p.light.x, p.light.y, p.light.z, 0)
			SetC(mat, 2, eye.x, eye.y, eye.z, 0)
			SetC(mat, 3, p.n.x, p.n.y, p.n.z, 1)
			render.SetMaterial(mat)
			p.mesh:Draw()
		end
	end
end

hook.Add("PostDrawOpaqueRenderables", "ABL_GPUDraw", function(depth, sky, sky3d)
	if depth or sky or sky3d or not Busy() or not GP.Ready() then return end
	render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)
	render.OverrideDepthEnable(true, false)
	local ok, err = pcall(DrawPatches)
	if ok and GP.BodyDraw then ok, err = pcall(GP.BodyDraw) end
	render.OverrideDepthEnable(false)
	render.OverrideBlend(false)
	if not ok then
		render.MaterialOverrideByIndex()
		Fail(err)
	end
end)

function GP.Clear()
	for i = #patches, 1, -1 do Release(patches[i]) end
	if GP.BodyClear then GP.BodyClear() end
end

function GP.Count()
	return #patches
end

concommand.Add("abl_gpu_status", function()
	print(string.format("[ABL] GPU blood: enabled=%s capable=%s verified=%s failed=%s patches=%d bodies=%d",
		tostring(C.cl.gpu:GetBool()), tostring(Capable()), tostring(GP.verified), tostring(GP.failed == true),
		#patches, GP.BodyCount and GP.BodyCount() or 0))
end)
