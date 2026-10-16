-- Stains. Every stain is an engine decal (correct lightmapping, clipped to the surface so it can
-- never float or poke through geometry, zero per-frame cost) plus, while fresh, a "wet" overlay
-- quad drawn on top with the same shape. The overlay is fresh wet blood (its colour and translucent
-- thin rim from the atlas, a Fresnel reflection of the surroundings on top) and dries from the
-- rim inward (shrinks + fades), revealing the darker decal: fresh -> ageing -> dried.
-- Directional stains (elongated, smears, satellites) are rotated with $basetexturetransform
-- variants matched to the engine's decal basis so they point along the impact direction.

ABL.NoJIT()
ABL.Stains = ABL.Stains or {}
local S = ABL.Stains
local C, M, L = ABL.Config, ABL.Mat, ABL.LOD
local sqrt, abs, atan2, floor, min, max, cos, sin = math.sqrt, math.abs, math.atan2, math.floor, math.min, math.max, math.cos, math.sin

-- wet overlays live in chunks of static meshes (one atlas material, rebuilt only when changed)
local chunks = {}
S.chunks = chunks
local ovCount = 0
local CHUNK = 48

-- verified by the in-game test (decal texture space rotation sign)
S.ROT_SIGN = 1

------------------------------------------------------------------------------------------
-- Engine decal basis (replicates the engine's texture-space basis for decals without an
-- explicit s-axis): floors/ceilings use world X for S; walls use world down for T.
------------------------------------------------------------------------------------------
function S.Basis(nx, ny, nz)
	local sx, sy, sz, tx, ty, tz
	if abs(nz) > 0.70710678 then
		sx, sy, sz = 1, 0, 0
		tx, ty, tz = sy * nz - sz * ny, sz * nx - sx * nz, sx * ny - sy * nx
		sx, sy, sz = ny * tz - nz * ty, nz * tx - nx * tz, nx * ty - ny * tx
	else
		tx, ty, tz = 0, 0, -1
		sx, sy, sz = ny * tz - nz * ty, nz * tx - nx * tz, nx * ty - ny * tx
		tx, ty, tz = sy * nz - sz * ny, sz * nx - sx * nz, sx * ny - sy * nx
	end
	local sl = sqrt(sx * sx + sy * sy + sz * sz)
	local tl = sqrt(tx * tx + ty * ty + tz * tz)
	if sl < 1e-6 then sl = 1 end
	if tl < 1e-6 then tl = 1 end
	return sx / sl, sy / sl, sz / sl, tx / tl, ty / tl, tz / tl
end

------------------------------------------------------------------------------------------
-- Rate limiting
------------------------------------------------------------------------------------------
local tokens, lastRefill = 0, 0
-- small stains may only use the bucket while it is comfortably full, so large splashes, pools
-- and runoff streaks still get placed during heavy bleeding
local function TakeDecal(size)
	local now = RealTime()
	local rate = C.cl.decalRate:GetFloat()
	tokens = min(rate * 0.5, tokens + (now - lastRefill) * rate)
	lastRefill = now
	local need = (size and size < 1.5) and 6 or 1
	if tokens < need then return false end
	tokens = tokens - 1
	return true
end
S.stats = { decals = 0, rejected = 0 }

local vecPos, vecNorm = Vector(), Vector()
local colTmp = Color(255, 255, 255, 255)
local world

-- Place a stain.
--   fam/idx : texture family / variant (see cl_materials)
--   x,y,z   : point on the surface;  nx,ny,nz: outward surface normal
--   dx,dy,dz: in-plane unit direction the stain points to (nil = random orientation)
--   w, h    : world size of the texture: w along the direction, h across it ("streak" textures
--             run along v, so for them h is the length)
--   col     : {r,g,b} decal colour, alpha 0..255
--   wetT    : seconds the wet overlay lasts (nil/0 = no overlay)
-- Engine decals are scaled along the surface's own fixed decal basis while the stain is rotated
-- inside the texture, so only square decals keep their shape at any angle: a long directional
-- stain is laid down as a row of overlapping squares along its direction.
-- Engine decals (timed for the profiler: placing one is the costliest single call a stain makes).
local function Decal(mat, ent, pos, normal, col, w, h)
	local t0 = SysTime()
	util.DecalEx(mat, ent, pos, normal, col, w, h)
	ABL.Prof.Add("sub.decals", SysTime() - t0)
end

function S.Place(fam, idx, x, y, z, nx, ny, nz, dx, dy, dz, w, h, col, alpha, ent, wetT, rng)
	-- (a stain needs a place, a surface and a size)
	if not (ABL.InWorld(x, y, z) and nx * nx + ny * ny + nz * nz > 0.5 and w > 0 and w < 1e3 and h > 0 and h < 1e3) then return false end
	if dx and not ABL.Finite3(dx, dy, dz) then dx = nil end
	local stainScale = C.cl.stainScale:GetFloat()
	w, h = w * stainScale, h * stainScale
	if S.CellFull(x, y, z) then S.stats.rejected = S.stats.rejected + 1 return false end
	if not TakeDecal(w) then S.stats.rejected = S.stats.rejected + 1 return false end

	local sx, sy, sz, tx, ty, tz = S.Basis(nx, ny, nz)
	local step = 0
	local ang = 0
	if dx then
		local du = dx * sx + dy * sy + dz * sz
		local dv = dx * tx + dy * ty + dz * tz
		ang = atan2(dv, du)
	elseif rng then
		ang = rng:Next() * 6.2831853
	else
		ang = math.random() * 6.2831853
	end
	if fam == "streak" then ang = ang - 1.5707963 end -- streak textures run along +v
	local steps = M.ROT_STEPS
	step = floor(ang / 6.2831853 * steps + 0.5) % steps
	local tm = SysTime()
	local mat = M.Decal(fam, idx, (step * S.ROT_SIGN) % steps)
	ABL.Prof.Add("sub.decalmat", SysTime() - tm)
	if not mat then return false end

	world = world or game.GetWorld()
	local target = IsValid(ent) and ent or world
	vecNorm:SetUnpacked(nx, ny, nz)
	colTmp.r, colTmp.g, colTmp.b, colTmp.a = min(255, col[1]), min(255, col[2]), min(255, col[3]), min(255, alpha)
	if dx and fam ~= "streak" and w > h * 1.15 then
		local n = min(4, math.ceil(w / h - 0.15))
		local span = w - h
		for i = 1, n do
			local t = (n == 1) and 0 or ((i - 1) / (n - 1) - 0.5) * span
			vecPos:SetUnpacked(x + nx + dx * t, y + ny + dy * t, z + nz + dz * t)
			Decal(mat, target, vecPos, vecNorm, colTmp, h, h)
		end
		S.stats.decals = S.stats.decals + n
	else
		local aspect = (fam == "streak") and 2 or 1
		vecPos:SetUnpacked(x + nx, y + ny, z + nz)
		Decal(mat, target, vecPos, vecNorm, colTmp, w, h / aspect)
		S.stats.decals = S.stats.decals + 1
	end
	ABL.Surface.CountDecal(x, y, z)
	ABL.BloodMap.Add(x, y, z, nx, ny, nz, max(w, h) * 0.5, alpha / 255, wetT)

	if wetT and wetT > 0 then
		local qa = step * 6.2831853 / steps
		local ca, sa = cos(qa), sin(qa)
		-- in-plane axes of the texture after rotation
		local ux, uy, uz = sx * ca + tx * sa, sy * ca + ty * sa, sz * ca + tz * sa
		local vx, vy, vz = -sx * sa + tx * ca, -sy * sa + ty * ca, -sz * sa + tz * ca
		S.AddOverlay(fam, idx, x, y, z, nx, ny, nz, ux, uy, uz, vx, vy, vz, w * 0.5, h * 0.5, wetT, alpha)
	end
	return true
end

function S.CellFull(x, y, z)
	return ABL.Surface.CellDecals(x, y, z) >= C.Stain.cellCap
end

------------------------------------------------------------------------------------------
-- Wet overlays
------------------------------------------------------------------------------------------
local function NewChunk()
	local c = { items = {}, mesh = nil, dirty = true, nextBuild = 0, nextAge = 0, x = 0, y = 0, z = 0, rad = 0 }
	chunks[#chunks + 1] = c
	return c
end

local function DropOldest()
	local c = chunks[1]
	if not c then return end
	table.remove(c.items, 1)
	ovCount = ovCount - 1
	c.dirty = true
end

function S.AddOverlay(fam, idx, x, y, z, nx, ny, nz, ux, uy, uz, vx, vy, vz, hw, hh, life, alpha)
	if ovCount >= L.Cap(C.cl.maxOverlays) then DropOldest() end
	local c = chunks[#chunks]
	if not c or #c.items >= CHUNK then c = NewChunk() end
	local off = C.Stain.offset + (#c.items % 5) * 0.004 -- tiny layering offset avoids z-fighting between overlays
	c.items[#c.items + 1] = {
		x = x + nx * off, y = y + ny * off, z = z + nz * off, nx = nx, ny = ny, nz = nz,
		ux = ux, uy = uy, uz = uz, vx = vx, vy = vy, vz = vz, hw = hw, hh = hh,
		born = CurTime(), life = life * C.sv.drying:GetFloat(), alpha = alpha,
		cell = M.AtlasCell(fam, idx), tone = math.Rand(C.ToneRange[1], C.ToneRange[2]),
	}
	ovCount = ovCount + 1
	c.dirty = true
end

local vec = Vector()
local function Vert(x, y, z, u, v, r, g, b, a)
	vec:SetUnpacked(x, y, z)
	mesh.Position(vec)
	mesh.TexCoord(0, u, v)
	mesh.Color(r, g, b, a)
	mesh.AdvanceVertex()
end

-- Two static meshes per chunk: the wet overlays (their colour from the atlas, lit on the CPU) and
-- their reflection (gloss atlas, additive; the view-dependent Fresnel strength is applied per draw
-- through $color, the mesh holds wetness and light).
local function Build(c, now)
	if c.mesh then c.mesh:Destroy() c.mesh = nil end
	if c.gloss then c.gloss:Destroy() c.gloss = nil end
	local items = c.items
	local n = #items
	c.dirty = false
	if n == 0 then return end
	local R = ABL.Render
	local quads = {}
	local sx, sy, sz, nx, ny, nz = 0, 0, 0, 0, 0, 0
	for i = 1, n do
		local o = items[i]
		sx, sy, sz = sx + o.x, sy + o.y, sz + o.z
		nx, ny, nz = nx + (o.nx or 0), ny + (o.ny or 0), nz + (o.nz or 1)
		local k = math.Clamp((now - o.born) / o.life, 0, 1)
		-- dries from the rim inward: shrink a little, fade out; the reflection goes first
		local sc = 1 - 0.28 * k
		local a = o.alpha * (1 - k) ^ 1.4
		local wet = (1 - k) ^ 2
		local lr, lg, lb = R.Light(o.x, o.y, o.z)
		local t = o.tone or 1
		local hw, hh = o.hw * sc, o.hh * sc
		local ax, ay, az = o.ux * hw, o.uy * hw, o.uz * hw
		local bx, by, bz = o.vx * hh, o.vy * hh, o.vz * hh
		quads[i] = { o.x - ax - bx, o.y - ay - by, o.z - az - bz, o.x + ax - bx, o.y + ay - by, o.z + az - bz,
			o.x + ax + bx, o.y + ay + by, o.z + az + bz, o.x - ax + bx, o.y - ay + by, o.z - az + bz,
			min(255, 255 * lr * t), min(255, 255 * lg), min(255, 255 * lb), a,
			min(255, 255 * wet * lr), min(255, 255 * wet * lg), min(255, 255 * wet * lb), o.cell }
	end
	for pass = 1, 2 do
		local m = Mesh()
		mesh.Begin(m, MATERIAL_QUADS, n)
		for i = 1, n do
			local q = quads[i]
			local cell = q[20]
			local u0, v0, u1, v1 = cell[1], cell[2], cell[3], cell[4]
			local r, g, b = q[13], q[14], q[15]
			if pass == 2 then r, g, b = q[17], q[18], q[19] end
			Vert(q[1], q[2], q[3], u0, v0, r, g, b, q[16])
			Vert(q[4], q[5], q[6], u1, v0, r, g, b, q[16])
			Vert(q[7], q[8], q[9], u1, v1, r, g, b, q[16])
			Vert(q[10], q[11], q[12], u0, v1, r, g, b, q[16])
		end
		mesh.End()
		if pass == 1 then c.mesh = m else c.gloss = m end
	end
	c.x, c.y, c.z = sx / n, sy / n, sz / n
	c.nx, c.ny, c.nz = ABL.Norm(nx, ny, nz)
	local rad = 0
	for i = 1, n do
		local o = items[i]
		local d = math.sqrt((o.x - c.x) ^ 2 + (o.y - c.y) ^ 2 + (o.z - c.z) ^ 2) + math.max(o.hw, o.hh)
		if d > rad then rad = d end
	end
	c.rad = rad
end

local glossList, glossCol, glossOff, glossMat = {}, Vector(), Vector(), Matrix()

function S.Draw()
	local now = CurTime()
	local rt = RealTime()
	local maxD = math.min(C.cl.drawDist:GetFloat(), 2500)
	local builds = 0
	local set = false
	local ng = 0
	for i = #chunks, 1, -1 do
		local c = chunks[i]
		-- ageing step: drop dried overlays, refresh fading colours about once per second
		if rt > c.nextAge then
			c.nextAge = rt + 1 + math.random() * 0.2
			local items = c.items
			for j = #items, 1, -1 do
				if now - items[j].born >= items[j].life then
					table.remove(items, j)
					ovCount = ovCount - 1
				end
			end
			c.dirty = true
		end
		if #c.items == 0 then
			if c.mesh then c.mesh:Destroy() end
			if c.gloss then c.gloss:Destroy() end
			table.remove(chunks, i)
		else
			if (c.dirty or not c.mesh) and rt > c.nextBuild and builds < 4 then
				Build(c, now)
				builds = builds + 1
				c.nextBuild = rt + 0.1
			end
			if c.mesh then
				local d2, vis = L.View(c.x, c.y, c.z, c.rad)
				if vis and d2 < (maxD + c.rad) ^ 2 then
					if not set then render.SetMaterial(M.atlas) set = true end
					c.mesh:Draw()
					if c.gloss and d2 < 1200 * 1200 then ng = ng + 1 glossList[ng] = c end
				end
			end
		end
	end
	-- wet reflection: Fresnel of the view angle on the chunk's (mean) surface, pattern slid with the view
	if ng > 0 then
		local gm = M.atlasGloss
		glossOff:SetUnpacked((L.eyeX - L.eyeY) / 70 % 1, (L.eyeZ + L.eyeX) / 70 % 1, 0)
		glossMat:SetTranslation(glossOff)
		gm:SetMatrix("$detailtexturetransform", glossMat)
		render.SetMaterial(gm)
		for i = 1, ng do
			local c = glossList[i]
			glossList[i] = nil
			local dx, dy, dz = c.x - L.eyeX, c.y - L.eyeY, c.z - L.eyeZ
			local d = max(sqrt(dx * dx + dy * dy + dz * dz), 1)
			local k = min(C.Ground.sheen * ABL.Render.Fresnel((dx * c.nx + dy * c.ny + dz * c.nz) / d), 0.7)
			if k > 0.01 then
				glossCol:SetUnpacked(k, k, k)
				gm:SetVector("$color", glossCol)
				c.gloss:Draw()
			end
		end
	end
end

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
-- Convenience placements
------------------------------------------------------------------------------------------
-- Tiny stain (particles landing): a ground spot on floors, a small decal elsewhere
function S.Tiny(pos, normal)
	local n = normal
	local gx, gy, gz, gmag = ABL.Gravity()
	if -(n.x * gx + n.y * gy + n.z * gz) / gmag > 0.64 then
		ABL.Ground.Tiny(pos.x, pos.y, pos.z, n.x, n.y, n.z)
		return
	end
	S.Place("drop", math.random(1, 4), pos.x, pos.y, pos.z, n.x, n.y, n.z, nil, nil, nil, 0.9, 0.9, C.Colors.decal, 220, nil, 0)
end

------------------------------------------------------------------------------------------
-- Studio decals on bodies.
-- The engine stamps its own red splat ("Impact.Flesh") on a body wherever a bullet strikes it. ABL
-- draws the wound there itself, and a decal on a model cannot be taken off singly: so, with the
-- takeover on, ABL clears the body's decals a moment after each hit it has a wound for and puts its
-- own back. It keeps the last few it placed on each body, in the space of the nearest bone.
------------------------------------------------------------------------------------------
local bodyLog = setmetatable({}, { __mode = "k" })
local BODY_LOG = 12

local function NearestBone(ent, pos)
	local best, bd
	for b = 0, (ent:GetBoneCount() or 0) - 1 do
		local m = ent:GetBoneMatrix(b)
		if m then
			local d = m:GetTranslation():DistToSqr(pos)
			if not bd or d < bd then best, bd = b, d end
		end
	end
	return best
end

local function BodyDecal(mat, ent, pos, normal, w, h)
	Decal(mat, ent, pos, normal, colTmp, w, h)
	local bone = NearestBone(ent, pos)
	local m = bone and ent:GetBoneMatrix(bone)
	if not m then return end
	local ang = m:GetAngles()
	local log = bodyLog[ent]
	if not log then log = {} bodyLog[ent] = log end
	if #log >= BODY_LOG then table.remove(log, 1) end
	log[#log + 1] = {
		mat = mat, bone = bone, w = w, h = h,
		lpos = WorldToLocal(pos, angle_zero, m:GetTranslation(), ang),
		lnorm = WorldToLocal(normal, angle_zero, vector_origin, ang),
	}
end

-- A bullet struck this body and ABL has a wound for it: the engine's own decal goes. The effect
-- that places it reaches the client with the hit, but the client plays effects late by its
-- interpolation delay; so the body is cleared just after that, and once more a little later.
local clearAt = setmetatable({}, { __mode = "k" })
local cvInterp, cvRatio, cvRate

local function ClearBody(ent)
	if not IsValid(ent) then return end
	ent:RemoveAllDecals()
	local log = bodyLog[ent]
	if not log then return end
	colTmp.r, colTmp.g, colTmp.b, colTmp.a = 255, 255, 255, 255
	for i = 1, #log do
		local d = log[i]
		local m = ent:GetBoneMatrix(d.bone)
		if m then
			local ang = m:GetAngles()
			local pos = LocalToWorld(d.lpos, angle_zero, m:GetTranslation(), ang)
			local nrm = LocalToWorld(d.lnorm, angle_zero, vector_origin, ang)
			Decal(d.mat, ent, pos, nrm, colTmp, d.w, d.h)
		end
	end
end

function S.ClearEngineHitDecal(ent)
	if not IsValid(ent) or clearAt[ent] then return end
	clearAt[ent] = true
	cvInterp = cvInterp or GetConVar("cl_interp")
	cvRatio = cvRatio or GetConVar("cl_interp_ratio")
	cvRate = cvRate or GetConVar("cl_updaterate")
	local lerp = 0.1
	if cvInterp and cvRatio and cvRate then
		lerp = math.Clamp(max(cvInterp:GetFloat(), cvRatio:GetFloat() / max(cvRate:GetFloat(), 1)), 0, 0.5)
	end
	timer.Simple(lerp + 0.03, function() ClearBody(ent) end)
	timer.Simple(lerp + 0.22, function()
		clearAt[ent] = nil
		ClearBody(ent)
	end)
end

-- Studio decal on a character that was hit by a droplet
local charTokens = setmetatable({}, { __mode = "k" })
function S.OnCharacter(ent, x, y, z, nx, ny, nz, vol)
	if not IsValid(ent) or not (ABL.InWorld(x, y, z) and ABL.Finite3(nx, ny, nz) and vol > 0) then return end
	local now = RealTime()
	if (charTokens[ent] or 0) > now then return end
	charTokens[ent] = now + 0.12
	if not TakeDecal() then return end
	local size = math.Clamp(ABL.DropDiameterMM(vol) / 25.4 * 3, 0.6, 3.5)
	world = world or game.GetWorld()
	-- normal points from the surface toward where the drop came from
	vecPos:SetUnpacked(x + nx * 2, y + ny * 2, z + nz * 2)
	vecNorm:SetUnpacked(nx, ny, nz)
	colTmp.r, colTmp.g, colTmp.b, colTmp.a = 255, 255, 255, 255
	local fam = vol > 0.05 and "splat" or "drop"
	BodyDecal(M.decal[fam][math.random(1, M.families[fam])], ent, vecPos, vecNorm, size, size)
	S.stats.decals = S.stats.decals + 1
end

-- Blood soaking into clothes / skin around a wound: a studio decal projected onto the model,
-- so it follows animation and ragdoll poses exactly (engine skinned decal).
function S.BodySoak(ent, x, y, z, nx, ny, nz, size)
	if not IsValid(ent) or not (ABL.InWorld(x, y, z) and ABL.Finite3(nx, ny, nz) and size > 0) or not TakeDecal(size) then return end
	vecPos:SetUnpacked(x + nx * 1.5, y + ny * 1.5, z + nz * 1.5)
	vecNorm:SetUnpacked(nx, ny, nz)
	colTmp.r, colTmp.g, colTmp.b, colTmp.a = 255, 255, 255, 255
	BodyDecal(M.decal.soak[math.random(1, M.families.soak)], ent, vecPos, vecNorm, size, size)
	S.stats.decals = S.stats.decals + 1
end

-- Wound mark on a body (studio decal at the wound)
function S.WoundMark(ent, x, y, z, nx, ny, nz, size)
	if not IsValid(ent) or not (ABL.InWorld(x, y, z) and ABL.Finite3(nx, ny, nz) and size > 0) or not TakeDecal() then return end
	vecPos:SetUnpacked(x + nx * 2, y + ny * 2, z + nz * 2)
	vecNorm:SetUnpacked(nx, ny, nz)
	colTmp.r, colTmp.g, colTmp.b, colTmp.a = 255, 255, 255, 255
	Decal(M.decal.wound[1], ent, vecPos, vecNorm, colTmp, size, size)
end

function S.Clear()
	for i = #chunks, 1, -1 do
		if chunks[i].mesh then chunks[i].mesh:Destroy() end
		if chunks[i].gloss then chunks[i].gloss:Destroy() end
		chunks[i] = nil
	end
	ovCount = 0
end

function S.Count() return ovCount end
