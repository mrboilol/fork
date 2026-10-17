-- Wound marks on the body: the visible openings of a wound record (cl_wounds.lua).
--
-- Geometry. A projectile hit is placed on the character's own render mesh: the entry is the
-- outermost surface the bullet line meets, the exit the surface that same line leaves through (so
-- entry and exit belong to one track), and a flesh-only path that stays just under the skin is a
-- graze: one elongated mark along the path instead of two holes. A retained projectile has no exit.
-- The angle of impact, the length of the track and whether the surface is bare skin or cloth are
-- written back into the record.
--
-- Drawing. A mark is a patch of the mesh's own triangles around the wound, so it is part of the
-- surface: it follows every animation and ragdoll pose and cannot float or slide. The patch is a
-- static mesh in the space of the bone it sits on (re-baked when skin that bends between bones has
-- moved under it), drawn once per layer. Layers are textures from tools/texgen, each placed by its
-- own texture transform (size, stretch along the bullet's path, rotation, offset), so no two wounds
-- are the same picture:
--   on skin   bruise, soot, powder stippling (by range), abrasion collar (pushed towards the side the
--             bullet came from), the defect itself, wet blood, clot / crust;
--   on cloth  the hole in the fabric with its dark wipe ring, soot / stippling, torn threads at an
--             exit, and the blood soaking into the cloth around the hole as it comes.
-- What a layer shows changes continuously with the record's state: the bruise comes up, wet blood
-- loses its gloss, darkens and sets into a crust, edge first.
--
-- Bleeding: Z-City's wounds linked to the record bleed from exactly these openings (cl_emission).

ABL.NoJIT()
ABL.WoundFX = ABL.WoundFX or {}
local W = ABL.WoundFX
local C, BM, L, WD = ABL.Config, ABL.BodyMesh, ABL.LOD, ABL.Wound
local WC, WR = C.WoundFX, C.Wound
local sqrt, min, max, abs, cos, sin, exp = math.sqrt, math.min, math.max, math.abs, math.cos, math.sin, math.exp
local Clamp = math.Clamp

local PASS_FILTER, PASS_COLOUR, PASS_GLOSS = 1, 2, 3

------------------------------------------------------------------------------------------
-- Layer materials (one per texture and pass, shared by all marks: placed per draw)
------------------------------------------------------------------------------------------
local mats = {}
local function LayerMat(tex, pass)
	local key = tex .. ":" .. pass
	local mt = mats[key]
	if mt then return mt end
	local kv = { ["$basetexture"] = "advancedblood/" .. tex, ["$vertexcolor"] = 1, ["$vertexalpha"] = 1, ["$nocull"] = 1 }
	if pass == PASS_GLOSS then kv["$additive"] = 1 else kv["$translucent"] = 1 end
	mt = CreateMaterial("abl_wl_" .. string.gsub(tex, "[^%w]", "_") .. "_" .. pass, "UnlitGeneric", kv)
	mats[key] = mt
	return mt
end

-- What a layer is (how its opacity, colour and size follow the wound's state).
--   FIXED   what the shot left for good: soot, stippling, abrasion, the defect itself
--   BRUISE  comes up over the first minute
--   BLOOD   the wet film around the wound: there within a second, darkens, gives way to the crust
--   CRUST   what the film sets into
--   GLOSS   reflection of the wet parts
--   SOAK    blood in the cloth around a hole: grows with what has come out of the wound
--   SOAKB   that blood's own colour over it (a soak-only mark: see PlaceSoak)
local K_FIXED, K_BRUISE, K_BLOOD, K_GLOSS, K_CRUST, K_SOAK, K_SOAKB = 1, 2, 3, 4, 5, 6, 7

-- variants per texture family (tools/texgen)
local NV = { bruise = 3, soot = 2, stipple = 3, collar = 3, wipe = 2, defect = 4, stellate = 2, tear = 4, blood = 4, crust = 3, furrow = 2, imprint = 2, clothhole = 3, clothtear = 3, soak = 2 }

local function Layer(layers, tex, pass, kind, half, st, rot, ox, oy, alpha, detail)
	local l = { mat = LayerMat("wounds/" .. tex, pass), pass = pass, kind = kind, half = half, half0 = half, st = st or 1, rot = rot or 0, ox = ox or 0, oy = oy or 0, a = alpha or 1, detail = detail or false }
	layers[#layers + 1] = l
	return l
end

local function Pick(rng, family)
	return family .. (1 + math.floor(rng:Next() * NV[family]) % NV[family])
end

-- The layers of a mark, back to front, from its record. Returns the list and the half-size of
-- the patch that holds them all.
--   mk.skin    bare skin or cloth
--   mk.down    rotation that turns a layer's "down" towards where gravity pulled along the skin
--              when the wound was made (the film that welled out ran that way)
local function BuildLayers(mk, r, rng)
	local layers = {}
	local kind, skin = mk.kind, mk.skin
	local down = mk.down or 0
	local absorb = mk.absorb or 1
	-- an oblique path draws everything out along it
	local obl = Clamp(1 / (r.cosI or 1), 1, 2.4) ^ 0.7

	if kind == "soak" then
		-- No opening is drawn (a cut, a tear, a wound made by something other than a bullet): only
		-- the cloth round it taking blood up. As a filter it darkens the cloth; blood is not a dye,
		-- so its own colour lies over that (on dark or coloured cloth the patch is red-brown, not black).
		local sk = Pick(rng, "soak")
		local half, rot = mk.len or 1.6, rng:Range(-3, 3)
		Layer(layers, sk, PASS_FILTER, K_SOAK, half, 1, rot, 0, 0, absorb)
		Layer(layers, sk, PASS_COLOUR, K_SOAKB, half, 1, rot, 0, 0, 0.42 * absorb)
	elseif kind == "graze" then
		-- A furrow along the skin: as long as the path, a few projectile widths across
		local hy = Clamp(r.caliber * 2.6, 0.55, 1.3)
		local st = Clamp(((mk.len or 3) * 0.5 / 0.82) / hy, 1, 4.5)
		local rot = rng:Range(-0.05, 0.05)
		if skin then
			Layer(layers, Pick(rng, "bruise"), PASS_COLOUR, K_BRUISE, hy * 1.5, st, rng:Range(-3, 3), 0, 0, 0.5, true)
			Layer(layers, Pick(rng, "blood"), PASS_COLOUR, K_BLOOD, hy * rng:Range(0.9, 1.3), 1, down, rng:Range(-0.3, 0.3) * hy * st, 0, 0.85)
			Layer(layers, Pick(rng, "crust"), PASS_COLOUR, K_CRUST, hy * 0.8, st * 0.8, rot, 0, 0, 0.9, true)
			local f = Pick(rng, "furrow")
			Layer(layers, f, PASS_COLOUR, K_FIXED, hy, st, rot)
			Layer(layers, f .. "_g", PASS_GLOSS, K_GLOSS, hy, st, rot)
		else
			-- cloth torn open along the path, the furrow showing through it
			Layer(layers, Pick(rng, "soak"), PASS_FILTER, K_SOAK, hy * 1.7, st * 0.8, rng:Range(-3, 3), 0, 0, absorb)
			local f = Pick(rng, "furrow")
			-- (in the shade of the torn cloth, and soaked dark like it)
			Layer(layers, f, PASS_COLOUR, K_FIXED, hy * 0.85, st, rot, 0, 0, 0.95).tint = 0.5
		end

	elseif kind == "exit" then
		-- Torn open from inside: no abrasion, no soot, whatever the range
		local ro = r.exitOpening
		local big = ro > r.caliber * 0.85
		if skin then
			local tear = (r.boneHit and big) and (rng:Next() < 0.6 and "tear3" or "tear2") or (not big and (rng:Next() < 0.5 and "tear4" or "tear1")) or Pick(rng, "tear")
			local half = Clamp(ro / 0.36, 0.7, 3.2)
			local rot = rng:Range(-3.14, 3.14)
			Layer(layers, Pick(rng, "bruise"), PASS_COLOUR, K_BRUISE, Clamp(half * 2.2, 1.8, 4), 1, rng:Range(-3, 3), 0, 0, 0.75, true)
			local b = Pick(rng, "blood")
			local hb = half * rng:Range(1.3, 1.9)
			Layer(layers, b, PASS_COLOUR, K_BLOOD, hb, 1, down)
			Layer(layers, Pick(rng, "crust"), PASS_COLOUR, K_CRUST, hb * 0.8, 1, down, 0, 0, 0.95, true)
			Layer(layers, tear, PASS_COLOUR, K_FIXED, half, 1, rot)
			Layer(layers, b .. "_g", PASS_GLOSS, K_GLOSS, hb, 1, down, 0, 0, 0.7)
			Layer(layers, tear .. "_g", PASS_GLOSS, K_GLOSS, half, 1, rot)
		else
			local half = Clamp(ro / 0.3, 0.8, 3.2)
			local rot = rng:Range(-3.14, 3.14)
			Layer(layers, Pick(rng, "soak"), PASS_FILTER, K_SOAK, Clamp(half * 1.9, 1.6, 4.2), 1, rng:Range(-3, 3), 0, 0, absorb)
			local t = Pick(rng, "clothtear")
			Layer(layers, t, PASS_COLOUR, K_FIXED, half, 1, rot)
			Layer(layers, t .. "_g", PASS_GLOSS, K_GLOSS, half, 1, rot, 0, 0, 0.6)
		end

	else
		-- Entry. Around the defect lies what the shot left on the first surface it met, by range:
		-- soot (contact, near), powder stippling (near, medium), the muzzle's imprint (contact)
		local rd = r.opening
		local reach = r.reachK or 1
		local contact = r.range == WD.RANGE_CONTACT
		if r.soot > 0 then
			-- (pressed on: little escapes, a narrow dense ring. A hand away: wide and thin)
			local half = contact and Clamp(rd * 4.5 * reach, 0.9, 1.6) or Clamp(rd * 11 * reach, 2, 3.6)
			Layer(layers, Pick(rng, "soot"), PASS_COLOUR, K_FIXED, half, obl, rng:Range(-3, 3), half * 0.3 * (obl - 1), 0, (contact and 0.95 or 0.6) * r.soot)
		end
		if r.stipple > 0 then
			local half = Clamp(rd * (r.range == WD.RANGE_MEDIUM and 17 or 12) * reach, 2.4, 4.6)
			Layer(layers, Pick(rng, "stipple"), PASS_COLOUR, K_FIXED, half, obl, rng:Range(-3, 3), half * 0.25 * (obl - 1), 0, r.stipple * (skin and 1 or 0.4), true)
		end
		if skin then
			Layer(layers, Pick(rng, "bruise"), PASS_COLOUR, K_BRUISE, Clamp(rd * (6 + 9 * r.cavity), 1.5, 3.6), obl, rng:Range(-3, 3), 0, 0, 0.45 + 0.4 * r.cavity, true)
			if contact and r.imprint > 0.45 then
				Layer(layers, Pick(rng, "imprint"), PASS_COLOUR, K_FIXED, Clamp(rd * 3.6, 0.8, 1.3), 1, rng:Range(-3, 3), 0, 0, 0.85 * r.imprint, true)
			end
			-- abrasion collar: wider on the side the bullet came from
			local cr = rd * (1.35 + 0.5 * r.collar)
			Layer(layers, Pick(rng, "collar"), PASS_COLOUR, K_FIXED, cr / 0.72, obl ^ 1.25, rng:Range(-3, 3), -rd * 0.9 * (obl - 1), 0, 0.9)
			if r.wipe > 0 then
				Layer(layers, Pick(rng, "wipe"), PASS_COLOUR, K_FIXED, rd * 1.25 / 0.74, obl, 0, 0, 0, 0.55 * r.wipe, true)
			end
			local b = Pick(rng, "blood")
			local hb = Clamp(rd * rng:Range(3.6, 5.2), 0.8, 1.7)
			Layer(layers, b, PASS_COLOUR, K_BLOOD, hb, 1, down)
			Layer(layers, Pick(rng, "crust"), PASS_COLOUR, K_CRUST, hb * 0.8, 1, down, 0, 0, 0.95, true)
			local hole, half
			if r.stellate > 0 then
				-- a contact wound over bone, burst open by the gas
				hole, half = Pick(rng, "stellate"), rd * (3 + 2.2 * r.stellate)
			else
				hole, half = Pick(rng, "defect"), rd / 0.5
			end
			local rot = rng:Range(-0.15, 0.15) + (r.stellate > 0 and rng:Range(-3, 3) or 0)
			local st = r.stellate > 0 and 1 or obl
			Layer(layers, hole, PASS_COLOUR, K_FIXED, half, st, rot)
			Layer(layers, b .. "_g", PASS_GLOSS, K_GLOSS, hb, 1, down, 0, 0, 0.7)
			Layer(layers, hole .. "_g", PASS_GLOSS, K_GLOSS, half, st, rot)
		else
			-- through cloth: the hole in the weave (its dark rim is the bullet wipe), blood coming
			-- up into the cloth around it
			Layer(layers, Pick(rng, "soak"), PASS_FILTER, K_SOAK, Clamp(rd * 7, 1.3, 2.4), 1, rng:Range(-3, 3), 0, 0, absorb)
			local h = Pick(rng, "clothhole")
			local half = rd / 0.29
			Layer(layers, h, PASS_COLOUR, K_FIXED, half, obl, rng:Range(-3, 3))
			Layer(layers, h .. "_g", PASS_GLOSS, K_GLOSS, half, obl, 0, 0, 0, 0.5)
		end
	end

	local S = 0
	for i = 1, #layers do
		local l = layers[i]
		if kind ~= "soak" and (l.kind == K_BLOOD or l.kind == K_CRUST or l.kind == K_SOAK) then
			l.gmax = max(1, min(WC.spreadMax, WC.spreadHalf / l.half))
		end
		local ext = l.half * (l.gmax or 1) * max(l.st, 1) + max(abs(l.ox), abs(l.oy))
		if ext > S then S = ext end
	end
	return layers, S
end

------------------------------------------------------------------------------------------
-- Creation
------------------------------------------------------------------------------------------
-- Tangent frame of the mark in bind space: normal n, +x (t) along `dir` projected onto the skin.
local function Frame(m, tri, bdx, bdy, bdz)
	local nx, ny, nz = BM.BindNormal(m, tri)
	local tx, ty, tz = 0, 0, 0
	if bdx then
		local dn = bdx * nx + bdy * ny + bdz * nz
		tx, ty, tz = bdx - nx * dn, bdy - ny * dn, bdz - nz * dn
	end
	local tl = sqrt(tx * tx + ty * ty + tz * tz)
	if tl < 0.15 then
		tx, ty, tz = ABL.Perp(nx, ny, nz)
	else
		tx, ty, tz = tx / tl, ty / tl, tz / tl
	end
	local bx, by, bz = ny * tz - nz * ty, nz * tx - nx * tz, nx * ty - ny * tx
	return nx, ny, nz, tx, ty, tz, bx, by, bz
end

local function AddMark(src, r, kind, tri, u, v, dx, dy, dz, rng, len)
	local m, pose = src.mesh, src.pose
	local bdx, bdy, bdz = BM.WorldDirToBind(pose, m.tb[tri], dx, dy, dz)
	local nx, ny, nz, tx, ty, tz, bx, by, bz = Frame(m, tri, bdx, bdy, bdz)
	local bone = m.tb[tri]
	local mk = {
		kind = kind, rec = r, m = m, tri = tri, u = u, v = v,
		anchor = { tri, u, v, m },
		nx = nx, ny = ny, nz = nz, tx = tx, ty = ty, tz = tz, bx = bx, by = by, bz = bz,
		born = CurTime(), tone = rng:Range(C.ToneRange[1], 1),
		bone = bone, len = len,
		absorb = (m.tabs and m.tabs[tri]) or 1,
	}
	-- bare skin or cloth: by the material where the model names its skin (a cap on a head is not
	-- skin), else by the body part
	if (m.nskin or 0) > 0 then
		mk.skin = m.tskin[tri] == true
	else
		mk.skin = ABL.Flow.SkinBone(src, bone) or false
	end
	-- which way is down along the skin, as the body stands now: the blood that wells out of the
	-- wound in the first moments runs that way (a layer's own "down" is its +v)
	local gx, gy, gz = ABL.Gravity()
	local ggx, ggy, ggz = BM.WorldDirToBind(pose, bone, gx, gy, gz)
	local gt, gb = 0, 0
	if ggx then gt, gb = ggx * tx + ggy * ty + ggz * tz, ggx * bx + ggy * by + ggz * bz end
	mk.down = (gt * gt + gb * gb > 0.04) and math.atan2(gt, gb) or rng:Range(-3.14, 3.14)
	mk.layers, mk.S = BuildLayers(mk, r, rng)
	mk.hitPos = Vector(pose:Point(tri, u, v))
	src.marks = src.marks or {}
	local marks = src.marks
	-- a new wound right on top of an older one replaces it
	local px, py, pz = BM.BindPoint(m, tri, u, v)
	for i = #marks, 1, -1 do
		local o = marks[i]
		if o.m == m and o.kind == kind then
			local ox2, oy2, oz2 = BM.BindPoint(m, o.tri, o.u, o.v)
			if (ox2 - px) ^ 2 + (oy2 - py) ^ 2 + (oz2 - pz) ^ 2 < 0.3 * 0.3 then o.gone = true W.FreeMark(o) table.remove(marks, i) end
		end
	end
	if #marks >= WC.maxPerSource then marks[1].gone = true W.FreeMark(marks[1]) table.remove(marks, 1) end
	marks[#marks + 1] = mk
	return mk
end

-- Place the wound of record r on the body mesh: bullet line through world point (x,y,z) near
-- `bone`, direction (dx,dy,dz). Fills in the record's surface geometry. Returns the entry (or
-- graze) mark and the exit mark; either may be nil.
function W.PlaceWound(src, r, bone, x, y, z, dx, dy, dz, rng)
	local m, pose = src.mesh, src.pose
	if not m then return nil end
	-- entry: the outermost surface the line meets (a wound belongs on the jacket, not the shirt)
	local tri, u, v = BM.AnchorOuter(pose, bone, x, y, z, -dx, -dy, -dz, 6)
	if not tri then tri, u, v = BM.Anchor(pose, bone, x, y, z, 6) end
	if not tri then return nil end
	local ex, ey, ez, nx, ny, nz = pose:Point(tri, u, v)
	local cosI = max(-(dx * nx + dy * ny + dz * nz), 0.12)
	r.cosI = cosI
	-- exit: the surface the same line leaves through, seen from beyond the far side. A retained
	-- projectile has none
	local xtri, xu, xv
	if r.pen ~= WD.PEN_RETAINED then
		xtri, xu, xv = BM.AnchorOuter(pose, bone, ex, ey, ez, dx, dy, dz, WC.exitReach)
		if xtri == tri then xtri = nil end
	end
	local len
	if xtri then
		local qx, qy, qz = pose:Point(xtri, xu, xv)
		len = sqrt((qx - ex) ^ 2 + (qy - ey) ^ 2 + (qz - ez) ^ 2)
		r.trackLen = len
		-- a graze: flesh only, and the path never gets deep under the skin
		if r.pen == WD.PEN_SOFT and len < 12 and 0.5 * len * cosI < WR.grazeDepth and cosI < WR.grazeCos then
			r.graze = true
			local mt, mu, mv = BM.Anchor(pose, bone, (ex + qx) * 0.5, (ey + qy) * 0.5, (ez + qz) * 0.5, 5)
			if not mt then mt, mu, mv = tri, u, v end
			return AddMark(src, r, "graze", mt, mu, mv, dx, dy, dz, rng, len), nil
		end
	end
	local mk = AddMark(src, r, "entry", tri, u, v, dx, dy, dz, rng)
	local mx = xtri and AddMark(src, r, "exit", xtri, xu, xv, dx, dy, dz, rng) or nil
	return mk, mx
end

-- The cloth round a wound that has no mark of its own soaking up blood (cl_flowcore.lua FC.Feed).
-- rec: the wound's stand-in for a record; rec.soak (0..1) says how full the cloth is, rec.fedT
-- when blood last came. half: half-size of the patch when it is full (units).
function W.PlaceSoak(src, wd, rec, half)
	local m = src.mesh
	if not m or not wd.tri or wd.tri > m.nt or not (half > 0 and half < 100) then return nil end
	local gx, gy, gz, gmag = ABL.Gravity()
	local mk = AddMark(src, rec, "soak", wd.tri, wd.u, wd.v, gx / gmag, gy / gmag, gz / gmag,
		ABL.RNG(ABL.Hash(tostring(wd.id)) + 977), Clamp(half * 1.25, 0.9, 2.8))
	return mk
end

-- A projectile hit (E.OnHit). entry: world position, ev.dir: bullet direction.
function W.OnHit(src, body, ev, r, entry, exitPos, rng)
	if not IsValid(body) or not r.bullet or r.pen == WD.PEN_ARMOR then return nil end
	-- (the mesh is still being built, or the source has not taken up this body yet: a fake ragdoll
	-- that appeared in the tick of the hit)
	if not src.mesh or src.body ~= body then
		W.Pending(src, body, ev.bone, ev.lpos, ev.dir, r)
		return nil
	end
	local dir = ev.dir
	-- (its own generator, the same one a mark placed later gets: the event's generator then runs
	-- the same sequence on every client, whether its surface model was ready or not)
	return W.PlaceWound(src, r, ev.bone, entry.x, entry.y, entry.z, dir.x, dir.y, dir.z, ABL.RNG(r.id * 7919 + 31))
end

-- Marks placed after the hit was processed (the body mesh was still being built): hand them to
-- the record and to the wounds already bleeding through it.
local function Attach(r, mk, mx)
	r.entryMark, r.exitMark = mk, mx
	for _, wd in ipairs(r.wds) do
		local use = (wd.role == "exit") and (mx or mk) or mk
		if use then
			wd.mark = use
			wd.tri, wd.anchorTried = nil, false
		end
	end
	local sl = r.src and r.src.pendingHits
	if sl then
		for _, h in ipairs(sl) do
			if h.rec == r then h.mark = (h.role == "exit") and (mx or mk) or mk end
		end
	end
end

-- The body mesh is still being built: remember the hit in bone space (position and bullet
-- direction: the body may fall and turn before the mark can be placed) and place it once ready.
function W.Pending(src, body, bone, lpos, dir, r)
	local M = body:GetBoneMatrix(bone)
	if not M then return end
	local ldir = WorldToLocal(dir, angle_zero, vector_origin, M:GetAngles())
	src.pendingMarks = src.pendingMarks or {}
	local p = src.pendingMarks
	if #p >= 8 then table.remove(p, 1) end
	p[#p + 1] = { bone = bone, lpos = Vector(lpos), ldir = ldir, rec = r, t = CurTime() }
end

-- The body's surface model is another one (cl_sources.lua): the marks on the old one go, and each
-- wound is marked again on the new one from its record, which knows where the projectile struck
-- and which way it went in the space of the bone it struck (W.Think places it once the new surface
-- model is there). A bone of that name the new model must have; else the wound has no mark there.
-- Soaked patches come back by themselves as their wounds bleed on (cl_flowcore.lua FC.Feed).
function W.Remesh(src)
	local marks = src.marks
	if marks then
		local body = src.body
		local now = CurTime()
		local seen = {}
		for i = 1, #marks do
			local mk = marks[i]
			mk.gone = true
			W.FreeMark(mk)
			local r = mk.rec
			if r and not r.soakOnly and not r.gone and not seen[r] then
				seen[r] = true
				r.entryMark, r.exitMark = nil, nil
				local bone = IsValid(body) and r.boneName and body:LookupBone(r.boneName) or nil
				if bone and r.lentry and r.ldir then
					src.pendingMarks = src.pendingMarks or {}
					local p = src.pendingMarks
					if #p < WC.maxPerSource then p[#p + 1] = { bone = bone, lpos = Vector(r.lentry), ldir = r.ldir, rec = r, t = now } end
				end
			end
		end
		src.marks = nil
	end
	for _, wd in pairs(src.wounds) do
		if wd.mark and wd.mark.gone then wd.mark = nil end
		if wd.soakMark and wd.soakMark.gone then wd.soakMark = nil end
	end
	for _, h in ipairs(src.pendingHits or {}) do
		if h.mark and h.mark.gone then h.mark = nil end
	end
end

function W.Think(src)
	local p = src.pendingMarks
	if not p or #p == 0 or not src.mesh or not IsValid(src.body) then return end
	local now = CurTime()
	for i = #p, 1, -1 do
		local q = p[i]
		if now - q.t > 20 or q.rec.gone then
			table.remove(p, i)
		else
			local b = src.pose:Bone(q.bone)
			if b then
				local lx, ly, lz = q.lpos.x, q.lpos.y, q.lpos.z
				local x = b[1] * lx + b[2] * ly + b[3] * lz + b[4]
				local y = b[5] * lx + b[6] * ly + b[7] * lz + b[8]
				local z = b[9] * lx + b[10] * ly + b[11] * lz + b[12]
				local l = q.ldir
				local dx, dy, dz = ABL.Norm(b[1] * l.x + b[2] * l.y + b[3] * l.z, b[5] * l.x + b[6] * l.y + b[7] * l.z, b[9] * l.x + b[10] * l.y + b[11] * l.z)
				local r = q.rec
				-- (no direction: the bone has been scaled away, a destroyed head carries no mark)
				if dx ~= 0 or dy ~= 0 or dz ~= 0 then
					local mk, mx = W.PlaceWound(src, r, q.bone, x, y, z, dx, dy, dz, ABL.RNG(r.id * 7919 + 31))
					Attach(r, mk, mx)
				end
				table.remove(p, i)
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Patch: the mesh triangles around the mark, with texture coordinates (bind space, built once).
-- The patch's own coordinates span the square of half-size mk.S around the wound along its
-- tangent (u) and bitangent (v); layers are placed inside it by their texture transforms.
------------------------------------------------------------------------------------------
-- Does triangle (u, v in half-units: the patch is the square -1..1) overlap that square?
local function TriHitsSquare(u1, v1, u2, v2, u3, v3)
	if min(u1, u2, u3) > 1 or max(u1, u2, u3) < -1 or min(v1, v2, v3) > 1 or max(v1, v2, v3) < -1 then return false end
	-- separating axes: the triangle's edge normals
	for e = 1, 3 do
		local ax, ay, bx, by
		if e == 1 then ax, ay, bx, by = u1, v1, u2, v2 elseif e == 2 then ax, ay, bx, by = u2, v2, u3, v3 else ax, ay, bx, by = u3, v3, u1, v1 end
		local nx, ny = by - ay, ax - bx
		local p1, p2, p3 = u1 * nx + v1 * ny, u2 * nx + v2 * ny, u3 * nx + v3 * ny
		local r = abs(nx) + abs(ny)
		if min(p1, p2, p3) > r or max(p1, p2, p3) < -r then return false end
	end
	return true
end

local function BuildPatch(mk, m)
	local cx, cy, cz = BM.BindPoint(m, mk.tri, mk.u, mk.v)
	local S = mk.S
	local nx, ny, nz, tx, ty, tz, bx, by, bz = mk.nx, mk.ny, mk.nz, mk.tx, mk.ty, mk.tz, mk.bx, mk.by, mk.bz
	local su = 1 / S
	local ids, us, vs, as = {}, {}, {}, {}
	local vnx, vny, vnz = m.nx, m.ny, m.nz
	local vx, vy, vz, t1, t2, t3 = m.vx, m.vy, m.vz, m.t1, m.t2, m.t3
	local n = 0
	local lu, lv = {}, {}
	-- Every triangle that reaches into the square belongs to the patch, however large it is (coarse
	-- meshes have triangles bigger than a wound): the layers are transparent towards their borders
	-- and clamped beyond them, so the patch's own outline never shows.
	for _, t in ipairs(BM.TrisNear(m, cx, cy, cz, S * 1.5 + 6)) do
		-- only surface facing the same way (not the far side of the neck, not inside the mouth), and
		-- close to the wound's surface (not a collar standing off the neck); the surface may curve
		-- away from the wound's plane with distance
		local fx, fy, fz = BM.BindNormal(m, t)
		if t == mk.tri or fx * nx + fy * ny + fz * nz > 0.15 then
			local ok = true
			for k = 1, 3 do
				local id = (k == 1 and t1[t]) or (k == 2 and t2[t]) or t3[t]
				local dx, dy, dz = vx[id] - cx, vy[id] - cy, vz[id] - cz
				local h = dx * nx + dy * ny + dz * nz
				local pu, pv = dx * tx + dy * ty + dz * tz, dx * bx + dy * by + dz * bz
				local lat = sqrt(pu * pu + pv * pv)
				lu[k], lv[k] = pu * su, pv * su
				if t ~= mk.tri and (h > S * 0.37 + lat * 0.15 or h < -(S * 0.52 + lat * 0.8)) then ok = false break end
			end
			if ok and TriHitsSquare(lu[1], lv[1], lu[2], lv[2], lu[3], lv[3]) then
				for k = 1, 3 do
					n = n + 1
					ids[n] = (k == 1 and t1[t]) or (k == 2 and t2[t]) or t3[t]
					us[n] = 0.5 + 0.5 * lu[k]
					vs[n] = 0.5 + 0.5 * lv[k]
					-- Layers are laid on flat (projected along the wound's normal): where the surface turns
					-- away from it they would smear over the turned-away triangles, so they fade out there
					local id = ids[n]
					as[n] = Clamp(((vnx[id] * nx + vny[id] * ny + vnz[id] * nz) - 0.2) / 0.45, 0, 1)
				end
			end
		end
	end
	mk.patch = { n = n, ids = ids, u = us, v = vs, a = as }
	-- does the patch follow one bone rigidly? (corners out in the transparent border may bend with
	-- another bone: nothing of the wound is drawn there)
	local rigid = m.inv[mk.bone] ~= nil
	local b1, w1 = m.b1, m.w1
	local inner = 0.36 * max(1, 2.4 / S)
	for c = 1, n do
		local id = ids[c]
		if (b1[id] ~= mk.bone or w1[id] < 0.97) and abs(us[c] - 0.5) < inner and abs(vs[c] - 0.5) < inner then rigid = false break end
	end
	mk.rigid = rigid
end

------------------------------------------------------------------------------------------
-- The patch as a static mesh in the space of the mark's bone
------------------------------------------------------------------------------------------
local vec = Vector()
local function V(x, y, z, u, v, a)
	vec:SetUnpacked(x, y, z)
	mesh.Position(vec)
	mesh.TexCoord(0, u, v)
	-- (opacity through colour and alpha both: right for the blended and for the multiplied layers)
	local c = 255 * a ^ (1 / 2.2)
	mesh.Color(c, c, c, 255 * a)
	mesh.AdvanceVertex()
end

local function FreeMark(mk)
	if mk.mesh then mk.mesh:Destroy() mk.mesh = nil end
end
W.FreeMark = FreeMark

local OFFSET = 0.06
-- Rigid skin: from the bind pose, once. Bending skin: from the current pose, and again whenever
-- the skin has moved under it (W.Draw checks a few of its corners).
local function Bake(mk, m, pose)
	FreeMark(mk)
	local P = mk.patch
	local ids, us, vs, as = P.ids, P.u, P.v, P.a
	local ms
	if mk.rigid then
		local inv = m.inv[mk.bone]
		local ox, oy, oz = mk.nx * OFFSET, mk.ny * OFFSET, mk.nz * OFFSET
		local vx, vy, vz = m.vx, m.vy, m.vz
		ms = Mesh()
		mesh.Begin(ms, MATERIAL_TRIANGLES, P.n / 3)
		for c = 1, P.n do
			local id = ids[c]
			local x, y, z = vx[id] + ox, vy[id] + oy, vz[id] + oz
			V(inv[1] * x + inv[2] * y + inv[3] * z + inv[4], inv[5] * x + inv[6] * y + inv[7] * z + inv[8], inv[9] * x + inv[10] * y + inv[11] * z + inv[12], us[c], vs[c], as[c])
		end
		mesh.End()
	else
		local inv = pose:BoneInv(mk.bone)
		if not inv then return false end
		local _, _, _, anx, any, anz = pose:SkinPoint(mk.anchor)
		local ox, oy, oz = anx * OFFSET, any * OFFSET, anz * OFFSET
		ms = Mesh()
		mesh.Begin(ms, MATERIAL_TRIANGLES, P.n / 3)
		for c = 1, P.n do
			local x, y, z = pose:Vertex(ids[c])
			x, y, z = x + ox, y + oy, z + oz
			V(inv[1] * x + inv[2] * y + inv[3] * z + inv[4], inv[5] * x + inv[6] * y + inv[7] * z + inv[8], inv[9] * x + inv[10] * y + inv[11] * z + inv[12], us[c], vs[c], as[c])
		end
		mesh.End()
		-- three corners to watch
		local s = mk.sample
		if not s then s = {} mk.sample = s end
		for k = 1, 3 do
			local c = (k == 1 and 1) or (k == 2 and max(1, math.floor(P.n / 2))) or P.n
			local x, y, z = pose:Vertex(ids[c])
			local o = (k - 1) * 4
			s[o + 1] = ids[c]
			s[o + 2] = inv[1] * x + inv[2] * y + inv[3] * z + inv[4]
			s[o + 3] = inv[5] * x + inv[6] * y + inv[7] * z + inv[8]
			s[o + 4] = inv[9] * x + inv[10] * y + inv[11] * z + inv[12]
		end
	end
	mk.mesh = ms
	mk.bakeT = RealTime()
	return true
end

-- Has bending skin moved under the baked patch (more than half a millimetre or so)?
local function Drifted(mk, pose)
	local inv = pose:BoneInv(mk.bone)
	local s = mk.sample
	if not inv or not s then return false end
	for o = 0, 8, 4 do
		local x, y, z = pose:Vertex(s[o + 1])
		local lx = inv[1] * x + inv[2] * y + inv[3] * z + inv[4]
		local ly = inv[5] * x + inv[6] * y + inv[7] * z + inv[8]
		local lz = inv[9] * x + inv[10] * y + inv[11] * z + inv[12]
		if abs(lx - s[o + 2]) + abs(ly - s[o + 3]) + abs(lz - s[o + 4]) > 0.05 then return true end
	end
	return false
end

------------------------------------------------------------------------------------------
-- Drawing (from ABL.Flow.DrawSource, before the body blood so it runs over the wound)
------------------------------------------------------------------------------------------
local colVec = Vector()
local boneMat = Matrix()
local texMat = Matrix()
local GAMMA = 1 / 2.2

-- Place a layer inside the patch: texture transform for half-size h, stretch st along the tangent,
-- rotation rot, offset (ox, oy) in units.
local function PlaceLayer(mat, S, l)
	local c, s = cos(l.rot), sin(l.rot)
	local su, sv = S / (l.half * l.st), S / l.half
	local oxp, oyp = l.ox / (2 * l.half * l.st), l.oy / (2 * l.half)
	texMat:SetField(1, 1, c * su)
	texMat:SetField(1, 2, -s * sv)
	texMat:SetField(1, 4, 0.5 - 0.5 * c * su + 0.5 * s * sv - c * oxp + s * oyp)
	texMat:SetField(2, 1, s * su)
	texMat:SetField(2, 2, c * sv)
	texMat:SetField(2, 4, 0.5 - 0.5 * s * su - 0.5 * c * sv - s * oxp - c * oyp)
	mat:SetMatrix("$basetexturetransform", texMat)
end

local patchFrame = -1
function W.Draw(src, pose, off)
	local marks = src.marks
	local frame = FrameNumber()
	local m = src.mesh
	if not marks or #marks == 0 or not m then return end
	local body = src.body
	local R = ABL.Render
	local now, rt = CurTime(), RealTime()
	local ex, ey, ez = L.eyeX, L.eyeY, L.eyeZ
	local drawn = 0
	R.EndFilter()
	for i = 1, #marks do
		local mk = marks[i]
		if mk.m == m then
			-- a limb that is not drawn (a destroyed head) takes its wounds with it
			if now > (mk.hidT or 0) then
				mk.hidT = now + 0.5
				mk.hidden = ABL.ZC.BoneHidden(body, mk.bone) or (body.headexploded and ABL.ZC.BoneLimb(body:GetBoneName(mk.bone) or "") == "head")
			end
			if not mk.hidden then
				-- (one new patch per frame: several wounds made at once appear over as many frames
				-- instead of costing one long frame)
				if not mk.patch and patchFrame ~= frame then
					patchFrame = frame
					BuildPatch(mk, m)
				end
				local P = mk.patch
				if P and P.n >= 3 then
					local ax, ay, az, anx, any, anz = pose:SkinPoint(mk.anchor)
					local vx, vy, vz = ex - ax, ey - ay, ez - az
					local d = sqrt(vx * vx + vy * vy + vz * vz)
					-- (a mark facing away from the camera is behind its own body part)
					if d < WC.drawDist and vx * anx + vy * any + vz * anz > -0.3 * d then
						if not mk.mesh or (not mk.rigid and rt - mk.bakeT > 0.07 and Drifted(mk, pose)) then
							if Bake(mk, m, pose) then ABL.Prof.Count("mark bakes", 1) end
						end
						local ms = mk.mesh
						local ok = ms ~= nil
						if ok then
							if body.CopyBoneMatrix then
								body:CopyBoneMatrix(mk.bone, boneMat)
							else
								local bm = body:GetBoneMatrix(mk.bone)
								if bm then boneMat = bm else ok = false end
							end
						end
						if ok then
							local r = mk.rec
							local lr, lg, lb = R.Light(ax + anx * 2, ay + any * 2, az + anz * 2)
							-- (a soak-only mark dries once no blood has come for a while)
							if r.soakOnly then r.dry = Clamp((now - (r.fedT or now) - 30) / 120, 0, 1) end
							local wet, clot, dry, bruise = r.wet, r.clot, r.dry, r.bruise
							-- blood around the wound darkens as it sets and dries
							local dk = 1 - 0.22 * clot - 0.28 * dry
							local cosT = (vx * anx + vy * any + vz * anz) / max(d, 1)
							-- (the reflection of a small wet patch: never a white sticker)
							local gk = (wet ^ 1.5) * (1 - 0.8 * clot) * min(WC.gloss, 0.05 + 0.6 * C.Ground.sheen * R.Fresnel(cosT))
							-- the film is there within a second, and gives way to the crust as it dries
							local film = Clamp((now - mk.born) / 0.8, 0, 1) * (1 - 0.75 * dry)
							local crust = Clamp((clot - 0.25) / 0.6, 0, 1)
							-- blood in the cloth: grows with what has come out of the wound
							local soak = r.soakOnly and r.soak or Clamp(0.3 + r.released / 14, 0, 1)
							local spread = Clamp(sqrt(max(r.released or 0, 0) / WC.spreadMl), 0, 1)
							local detailOK = d < WC.detailDist
							local layers, S = mk.layers, mk.S
							cam.PushModelMatrix(boneMat)
							for k = 1, #layers do
								local l = layers[k]
								local kind = l.kind
								local a = l.a
								if l.gmax then
									l.half = l.half0 * (WC.spreadMin + (l.gmax - WC.spreadMin) * spread)
								end
								if l.detail and not detailOK then
									a = 0
								elseif kind == K_BRUISE then
									a = a * bruise
								elseif kind == K_BLOOD then
									a = a * film
								elseif kind == K_GLOSS then
									a = (d < 600) and a * gk or 0
								elseif kind == K_CRUST then
									a = a * crust
								elseif kind == K_SOAK or kind == K_SOAKB then
									if r.soakOnly then
										-- (from nothing: it starts as a spot at the opening)
										a = a * min(1, soak * 5)
										l.half = l.half0 * (0.22 + 0.78 * sqrt(soak))
									else
										a = a * (0.45 + 0.55 * soak)
									end
								end
								if a > 0.02 then
									local mat = l.mat
									PlaceLayer(mat, S, l)
									if l.pass == PASS_FILTER then
										-- multiplied over the lit surface: opacity through colour and alpha.
										-- Dried blood in cloth is browner and a little lighter than wet
										local f = min(a, 1)
										colVec:SetUnpacked(min(1, f * (1 + 0.5 * dry)) ^ GAMMA, min(1, f * (1 + 0.9 * dry)) ^ GAMMA, min(1, f * (1 + 0.5 * dry)) ^ GAMMA)
										mat:SetVector("$color", colVec)
										mat:SetFloat("$alpha", f)
										render.SetMaterial(mat)
										R.BeginFilter()
										ms:Draw()
										R.EndFilter()
									elseif l.pass == PASS_GLOSS then
										colVec:SetUnpacked(a * lr, a * lg, a * lb)
										mat:SetVector("$color", colVec)
										render.SetMaterial(mat)
										ms:Draw()
									elseif kind == K_SOAKB then
										-- (what blood in cloth scatters back: a dark red, browner as it dries)
										local t = 1 - 0.3 * dry
										colVec:SetUnpacked(min(1, lr * 0.5 * t), min(1, lg * (0.07 + 0.05 * dry) * t), min(1, lb * 0.08 * t))
										mat:SetVector("$color", colVec)
										mat:SetFloat("$alpha", min(a, 1))
										render.SetMaterial(mat)
										ms:Draw()
									else
										local t = ((kind == K_BLOOD or kind == K_CRUST) and dk or 1) * (l.tint or 1)
										colVec:SetUnpacked(min(1.3, lr * (kind == K_BLOOD and mk.tone or 1) * t), min(1.3, lg * t), min(1.3, lb * t))
										mat:SetVector("$color", colVec)
										mat:SetFloat("$alpha", min(a, 1))
										render.SetMaterial(mat)
										ms:Draw()
									end
									drawn = drawn + 1
								end
							end
							cam.PopModelMatrix()
						end
					end
				end
			end
		end
	end
	if drawn > 0 then ABL.Prof.Count("mark layers", drawn) end
end

function W.Clear(src)
	for _, mk in ipairs(src.marks or {}) do
		mk.gone = true
		FreeMark(mk)
	end
	src.marks = nil
	src.pendingMarks = nil
end
