-- Airborne droplets.
-- Droplets are integrated with semi-implicit Euler, world gravity and quadratic air drag derived
-- from each drop's terminal velocity (so small drops slow down and fall more steeply than large
-- ones), each at the rate its priority allows (up to the full simulation tick, abl_sim_hz).
-- Collision uses look-ahead traces from the last verified point (see D.Step); budgets never
-- cause tunnelling. Own-body hits are resolved against the character's hitboxes and handed back
-- to the body-surface flow. Steady outflows (arterial jets, pours) are linked into streams.
-- Low-importance / far droplets become cheap GMod particles instead.

ABL.NoJIT()
ABL.Drops = ABL.Drops or {}
local D = ABL.Drops
local C, L, BM = ABL.Config, ABL.LOD, ABL.BodyMesh
local sqrt, min, max, floor = math.sqrt, math.min, math.max, math.floor
local band = bit.band

local list = {}
D.list = list
local pool = ABL.NewPool(function() return {} end)
local nextId = 0
-- profiling accumulators (ms / calls since the last reset; read by the test harness)
D.prof = D.prof or { hb = 0, hbs = 0, tr = 0, trs = 0 }
local prof = D.prof

local traceOut = {}
local traceData = { mask = bit.bor(MASK_SOLID, CONTENTS_WATER), output = traceOut }
local vStart, vEnd = Vector(), Vector()

function D.Count() return #list end

------------------------------------------------------------------------------------------
-- GMod particle fallback (fire-and-forget)
------------------------------------------------------------------------------------------
local emitter
local partExpiry = {}
local partCount = 0
local vecTmp, gravVec = Vector(), Vector()

local function PruneParticles()
	local now = CurTime()
	local j = 0
	for i = 1, #partExpiry do
		local e = partExpiry[i]
		if e > now then j = j + 1 partExpiry[j] = e end
	end
	for i = j + 1, #partExpiry do partExpiry[i] = nil end
	partCount = j
end

local function Emitter(pos)
	if not emitter or not emitter:IsValid() then emitter = ParticleEmitter(pos, false) end
	emitter:SetPos(pos)
	return emitter
end

local function ParticleSlot(life)
	if partCount >= L.Cap(C.cl.maxParts) then return false end
	partCount = partCount + 1
	partExpiry[partCount] = CurTime() + life
	return true
end

local function ParticleLanded(part, hitPos, hitNormal)
	part:SetDieTime(0)
	if ABL.Stains and math.random() < 0.35 then ABL.Stains.Tiny(hitPos, hitNormal) end
end

function D.Particle(x, y, z, vx, vy, vz, vol)
	if not ParticleSlot(2.5) then return end
	vecTmp:SetUnpacked(x, y, z)
	local p = Emitter(vecTmp):Add(ABL.Mat.droplet, vecTmp)
	if not p then return end
	local gx, gy, gz = ABL.Gravity()
	gravVec:SetUnpacked(gx, gy, gz)
	vecTmp:SetUnpacked(vx, vy, vz)
	-- (sized by the drop's radius)
	local r = max(0.05, ABL.DropDiameterMM(vol or 0.03) / 25.4 * 0.5 * C.cl.dropScale:GetFloat())
	p:SetVelocity(vecTmp)
	p:SetGravity(gravVec)
	p:SetAirResistance(12)
	p:SetDieTime(2.5)
	p:SetStartSize(r) p:SetEndSize(r)
	p:SetStartAlpha(240) p:SetEndAlpha(240)
	-- the sprite carries the drop's colour and highlight; this only varies its tone
	local t = math.Rand(C.ToneRange[1], 1)
	-- lit like ABL's own drops (the engine's particle lighting overbrightens them to a neon red in the sun)
	local lr, lg, lb = ABL.Render.Light(x, y, z)
	p:SetColor(min(255, 255 * t * lr), min(255, 250 * lg), min(255, 250 * lb))
	p:SetRoll(math.Rand(-0.3, 0.3))
	p:SetLighting(false)
	p:SetCollide(true)
	p:SetBounce(0)
	p:SetCollideCallback(ParticleLanded)
end

-- Fine mist (atomised blood from high-energy wounds). Purely visual, never collides.
function D.Mist(pos, vel, count, size)
	if not ABL.Enabled() then return end
	local _, dist = L.PointImportance(pos.x, pos.y, pos.z)
	if dist > 1800 then return end
	local em = Emitter(pos)
	local lr, lg, lb = ABL.Render.Light(pos.x, pos.y, pos.z)
	local gx, gy, gz = ABL.Gravity()
	gravVec:SetUnpacked(gx * 0.08, gy * 0.08, gz * 0.08)
	for _ = 1, count do
		if not ParticleSlot(1.2) then return end
		-- several cloud textures of fine droplets, each puff rotated and spinning slowly as it spreads
		local p = em:Add(ABL.Mat.Mist(), pos + VectorRand() * size * 0.2)
		if p then
			p:SetVelocity(vel * math.Rand(0.4, 1) + VectorRand() * size * 3)
			p:SetGravity(gravVec)
			p:SetAirResistance(220)
			p:SetDieTime(math.Rand(0.45, 1.0))
			p:SetStartSize(size * math.Rand(0.3, 0.55))
			p:SetEndSize(size * math.Rand(1.5, 2.6))
			p:SetStartAlpha(math.random(70, 130))
			p:SetEndAlpha(0)
			local t = math.Rand(0.8, 1)
			p:SetColor(min(255, 255 * t * lr), min(255, 245 * t * lg), min(255, 245 * t * lb))
			p:SetRoll(math.Rand(0, 6.28))
			p:SetRollDelta(math.Rand(-0.6, 0.6))
			p:SetLighting(false)
		end
	end
end

-- Blood entering water disperses into a slowly spreading cloud.
function D.WaterCloud(pos, vel, vol)
	local em = Emitter(pos)
	local lr, lg, lb = ABL.Render.Light(pos.x, pos.y, pos.z)
	local n = min(4, 1 + floor(vol * 20))
	for _ = 1, n do
		if not ParticleSlot(5) then return end
		local p = em:Add(ABL.Mat.Mist(), pos)
		if p then
			p:SetVelocity(vel * 0.05 + VectorRand() * 4)
			p:SetAirResistance(60)
			p:SetDieTime(math.Rand(3, 5))
			p:SetStartSize(1 + vol * 10) p:SetEndSize(8 + vol * 60)
			p:SetStartAlpha(140) p:SetEndAlpha(0)
			p:SetColor(min(255, 200 * lr), min(255, 190 * lg), min(255, 190 * lb))
			p:SetRoll(math.Rand(0, 6.28))
			p:SetRollDelta(math.Rand(-0.2, 0.2))
			p:SetLighting(false)
		end
	end
end

------------------------------------------------------------------------------------------
-- Simulated droplets
------------------------------------------------------------------------------------------
local function Release(i)
	local d = list[i]
	local src = d.src
	if src then src.dropCount = (src.dropCount or 1) - 1 end
	d.src = nil
	d.dead = true
	d.hit = nil
	ABL.SwapRemove(list, i)
	pool:Put(d)
end

local EVICT_SCAN = 48
local evictAt = 0

local function Evict(minImp)
	-- replace the least important droplet by a particle
	local worst, wi = minImp, nil
	local n = #list
	if n == 0 then return false end
	for _ = 1, min(n, EVICT_SCAN) do
		evictAt = evictAt % n + 1
		local imp = list[evictAt].imp
		if imp < worst then worst, wi = imp, evictAt end
	end
	if not wi then return false end
	local d = list[wi]
	ABL.FlowCore.Move("airborne", "lost", d.vol)
	D.Particle(d.x, d.y, d.z, d.vx, d.vy, d.vz, d.vol)
	Release(wi)
	return true
end

local MAX_SPEED = 6000   -- units/s

-- kind: 0 drip/normal, 1 jet stream segment, 2 fine spray, 3 impact secondary
-- from: where its blood was before (books, cl_flowcore.lua): nil new blood out of a wound,
-- "surface" / "pool" off a surface or out of a pool, "air" part of a drop that was already flying.
function D.Spawn(x, y, z, vx, vy, vz, vol, src, gen, kind, from)
	if not (vol > 0) or not ABL.Enabled() then return end
	local FC = ABL.FlowCore
	-- A drop that would be nowhere, or of no size: none is made. Blood that was already somewhere
	-- (on a surface, in a pool, in another drop) is written off there.
	if not (vol < 1e4 and ABL.InWorld(x, y, z) and ABL.Finite3(vx, vy, vz)) then
		if from then FC.Move(from == "air" and "airborne" or from, "lost", vol) end
		return
	end
	-- (nothing leaves a body faster than this: a drop thrown harder is one bad number, not a fast drop)
	local sp2 = vx * vx + vy * vy + vz * vz
	if sp2 > MAX_SPEED * MAX_SPEED then
		local k = MAX_SPEED / sqrt(sp2)
		vx, vy, vz = vx * k, vy * k, vz * k
	end
	if src and (gen or 0) <= 1 then ABL.Wounds.Ledger(src, "airborne", vol) end
	if from == nil then FC.Release("airborne", vol) elseif from ~= "air" then FC.Move(from, "airborne", vol) end
	local Sim = ABL.Sim
	local imp, lod, hz
	if src then
		lod = src.lod or C.LOD_MEDIUM
		imp = src.importance or 0.5
		local tier = C.LODTiers[lod]
		if not tier or tier.particlesOnly then
			if tier then D.Particle(x, y, z, vx, vy, vz, vol) end
			FC.Move("airborne", "lost", vol)
			return
		end
		hz = tier.hz
		if (src.dropCount or 0) >= tier.drops * L.QualityScale() then
			D.Particle(x, y, z, vx, vy, vz, vol)
			FC.Move("airborne", "lost", vol)
			return
		end
	else
		local pi, dist = L.PointImportance(x, y, z)
		if dist > C.cl.drawDist:GetFloat() then FC.Move("airborne", "lost", vol) return end
		imp = pi
		hz = Sim.HzAt(dist)
		if dist > 2600 then
			D.Particle(x, y, z, vx, vy, vz, vol)
			FC.Move("airborne", "lost", vol)
			return
		end
	end
	-- fine droplets matter less (small, short-lived stains): they are the first to become particles
	imp = imp * (0.35 + 0.65 * min(1, sqrt(vol / 0.02)))
	-- under load (the governor shrank LOD distances) fewer droplets are simulated at once
	if #list >= L.Cap(C.cl.maxDrops) * (0.4 + 0.6 * L.scale) then
		if not Evict(imp) then
			D.Particle(x, y, z, vx, vy, vz, vol)
			FC.Move("airborne", "lost", vol)
			return
		end
	end

	local d = pool:Get()
	nextId = nextId + 1
	d.id = nextId
	d.dead = false
	d.x, d.y, d.z = x, y, z
	d.px, d.py, d.pz = x, y, z
	d.cx, d.cy, d.cz = x, y, z
	d.vx, d.vy, d.vz = vx, vy, vz
	d.vol = vol
	local vt = ABL.TerminalVelocity(vol)
	local _, _, _, gmag = ABL.Gravity()
	d.k = gmag / (vt * vt) * (kind == 1 and 0.35 or 1)
	-- (its true radius: 0.09 units for 0.05 ml; what is too small to see is kept a pixel wide where
	-- it is drawn, not made bigger here)
	d.r = math.Clamp(ABL.DropDiameterMM(vol) / 25.4 * 0.5 * C.cl.dropScale:GetFloat(), 0.02, 0.9)
	d.src = src
	d.gen = gen or 0
	d.kind = kind or 0
	d.born = CurTime()
	d.ignoreBody = CurTime() + 0.09
	d.imp = imp
	-- update rate and simulation clock (first step comes with the next tick)
	d.hz = hz or 60
	d.acc = 0
	d.lt, d.sd = Sim.t, 1 / min(d.hz, Sim.rate)
	d.nextTrace = 0
	d.nextHb = 0
	d.la = 1 / C.DROP_TRACE_HZ
	d.hbx, d.hby, d.hbz = x, y, z
	d.hit = nil
	-- stream links (D.Link)
	d.prev, d.prevId, d.stream, d.link0 = nil, nil, nil, nil
	d.sw, d.tb, d.loose = nil, nil, nil
	-- look: tone (venous darker, arterial brighter) and a slight flattening / stretching of the drop
	d.tone = math.Rand(C.ToneRange[1], C.ToneRange[2])
	d.shape = math.Rand(0.86, 1.12)
	d.lightT = 0
	d.lr, d.lg, d.lb = 1, 1, 1
	list[#list + 1] = d
	if src then src.dropCount = (src.dropCount or 0) + 1 end
	return d
end

-- Streams: consecutive drops of one steady outflow (an arterial jet, a pour from a large wound, a
-- stream running off the body) are linked, and drawn as one continuous liquid ribbon through them.
-- holder: the emitter's state table; key: which outflow of that emitter.
function D.Link(d, holder, key)
	if not d then return end
	local now = CurTime()
	local lk = holder.streams
	if not lk then lk = {} holder.streams = lk end
	local e = lk[key]
	if not e then e = {} lk[key] = e end
	local last = e.d
	if last and not last.dead and last.id == e.id and now - e.t < 0.15 then
		d.prev, d.prevId = last, last.id
		-- how far apart the two were when linked: the stream thins as they move apart (DrawChain)
		local dx, dy, dz = last.x - d.x, last.y - d.y, last.z - d.z
		d.link0 = max(sqrt(dx * dx + dy * dy + dz * dz), 0.75)
	end
	-- The thread this drop is a piece of: as wide as its blood makes it over the length it was
	-- let out along (a jet of 2 ml/s at 120 units a second is under a millimetre across, not a
	-- rope), and a thread for as long as one of that width takes to break into drops.
	local sw = sqrt(4 * d.vol / C.ML_PER_CU / (3.14159 * (d.link0 or 1.5)))
	local SB = C.StreamBreak
	d.sw = sw
	d.tb = math.Clamp(SB.k * (sw * 25.4) ^ 1.5, SB.min, SB.max) * (0.8 + 0.4 * math.random())
	d.stream = true
	e.d, e.id, e.t = d, d.id, now
end

function D.ForgetSource(src)
	for i = 1, #list do
		if list[i].src == src then list[i].src = nil end
	end
end

------------------------------------------------------------------------------------------
-- Step
-- Each droplet integrates at its own rate (ABL.Sim: every tick when near and important, less
-- often with a longer step further away). Collision uses look-ahead traces at most
-- C.DROP_TRACE_HZ times per second: the trace runs from the last verified point to where the drop
-- will be by the next trace; a surface found ahead is remembered and the impact happens when the
-- drop actually reaches it. When the per-frame trace budget is exhausted the drop keeps flying and
-- the next trace covers the whole unchecked stretch, so budgets never cause tunnelling.
------------------------------------------------------------------------------------------
local Flow, Impacts

local tAddAt, tDecal, nAddAt, nDecal = 0, 0, 0, 0
local function HitCharacter(d, i, ent, bone, hx, hy, hz, nx, ny, nz)
	local src = d.src
	if src and src.body == ent then
		local t0 = SysTime()
		local took = bone and Flow.AddAt(src, bone, hx, hy, hz, d.vol, d.vx, d.vy, d.vz)
		tAddAt, nAddAt = tAddAt + SysTime() - t0, nAddAt + 1
		if took then
			Release(i)
			return
		end
	end
	-- someone else (or no surface model yet): a small studio decal on that body
	local t1 = SysTime()
	ABL.FlowCore.Land(d.vol, 0.5)
	ABL.Stains.OnCharacter(ent, hx, hy, hz, nx, ny, nz, d.vol)
	tDecal, nDecal = tDecal + SysTime() - t1, nDecal + 1
	if src then ABL.Wounds.Ledger(src, "character", d.vol) end
	Release(i)
end

-- The drop reached surface `tr` (a live trace result or a remembered hit).
local function Collide(d, i, tr)
	local hp = tr.HitPos
	if band(tr.Contents or 0, CONTENTS_WATER) ~= 0 then
		D.WaterCloud(hp, Vector(d.vx, d.vy, d.vz), d.vol)
		ABL.FlowCore.Move("airborne", "lost", d.vol)
		Release(i)
		return
	end
	if tr.HitSky then
		ABL.FlowCore.Move("airborne", "lost", d.vol)
		Release(i)
		return
	end
	local ent = tr.Entity
	if IsValid(ent) and (ent:IsPlayer() or ent:IsRagdoll() or ent:IsNPC()) then
		local bone
		if ent:IsRagdoll() then
			bone = ent:TranslatePhysBoneToBone(tr.PhysicsBone or 0)
		else
			bone = tr.HitBoxBone
		end
		local hn = tr.HitNormal
		HitCharacter(d, i, ent, bone, hp.x, hp.y, hp.z, hn.x, hn.y, hn.z)
		return
	end
	Impacts.Handle(d, tr)
	Release(i)
end

-- Remember a surface found ahead (the shared trace output is overwritten by the next trace).
local HIT_FIELDS = { "Contents", "HitSky", "Entity", "PhysicsBone", "HitBoxBone", "HitGroup", "SurfaceProps", "MatType", "HitTexture", "HitWorld", "Fraction" }
local function Remember(d, tr, sx, sy, sz, ex, ey, ez, expire)
	local h = d.hitRec
	if not h then h = { HitPos = Vector(), HitNormal = Vector() } d.hitRec = h end
	for k = 1, #HIT_FIELDS do local f = HIT_FIELDS[k] h[f] = tr[f] end
	h.Hit = true
	h.HitPos:Set(tr.HitPos)
	h.HitNormal:Set(tr.HitNormal)
	h.sx, h.sy, h.sz, h.ex, h.ey, h.ez = sx, sy, sz, ex, ey, ez
	h.expire = expire
	d.hit = h
end

-- Fraction of the way along segment s -> e at which point p lies (projection).
local function Along(px, py, pz, sx, sy, sz, ex, ey, ez)
	local qx, qy, qz = ex - sx, ey - sy, ez - sz
	local qq = qx * qx + qy * qy + qz * qz
	if qq < 1e-8 then return 1 end
	return ((px - sx) * qx + (py - sy) * qy + (pz - sz) * qz) / qq
end

function D.Step(h)
	Flow = Flow or ABL.Flow
	Impacts = Impacts or ABL.Impacts
	local Sim = ABL.Sim
	local rate, simT = Sim.rate, Sim.t
	local traceDt = 1 / C.DROP_TRACE_HZ
	local lookMax = C.DROP_LOOK_MAX
	local hbDt = 1 / C.DROP_BODY_HZ
	local gx, gy, gz = ABL.Gravity()
	local now = CurTime()
	local tTrace, tHit, tImp, tLand = 0, 0, 0, 0
	local heapOn, Heap = ABL.Prof.heapOn, ABL.Prof.Heap
	local i = #list
	while i > 0 do
		local d = list[i]
		local acc = d.acc + h
		local period = d.hz < rate and 1 / d.hz or 1 / rate
		if acc + 1e-6 < period then
			d.acc = acc
		else
			d.acc = 0
			local dt = acc
			d.px, d.py, d.pz = d.x, d.y, d.z
			d.lt, d.sd = simT, dt
			local vx, vy, vz = d.vx, d.vy, d.vz
			local sp = sqrt(vx * vx + vy * vy + vz * vz)
			local k = d.k * sp
			-- semi-implicit Euler with implicit drag term (unconditionally stable)
			local inv = 1 / (1 + k * dt)
			vx = (vx + gx * dt) * inv
			vy = (vy + gy * dt) * inv
			vz = (vz + gz * dt) * inv
			d.vx, d.vy, d.vz = vx, vy, vz
			local x, y, z = d.x + vx * dt, d.y + vy * dt, d.z + vz * dt
			d.x, d.y, d.z = x, y, z

			local removed = false
			-- own body (hitboxes) once the drop has left the wound; only drops inside the body's
			-- bounds (plus one step of travel) are tested against the individual hitboxes
			-- (a ragdoll's own physics objects stop the droplet trace below, so only upright
			-- characters, whose hull is not their shape, need the hitbox test)
			-- (tested at the collision cadence, over the whole stretch since the last test)
			local src = d.src
			if src and now > d.ignoreBody and simT >= d.nextHb and src.mesh and IsValid(src.body) and not src.isRagdoll then
				d.nextHb = simT + (period > hbDt and period or hbDt) * 0.98
				local tier = C.LODTiers[src.lod]
				local mn, mx = src.bbMin, src.bbMax
				if tier and tier.bodyflow and mn then
					local hx0, hy0, hz0 = d.hbx or d.px, d.hby or d.py, d.hbz or d.pz
					local pad = 2 + sqrt((x - hx0) ^ 2 + (y - hy0) ^ 2 + (z - hz0) ^ 2)
					if x > mn.x - pad and x < mx.x + pad and y > mn.y - pad and y < mx.y + pad and z > mn.z - pad and z < mx.z + pad then
						if heapOn then Heap("drops.move") end
						local t0 = SysTime()
						local bone, _, hx, hy, hz = BM.SegmentHitboxes(src.pose, src.body, hx0, hy0, hz0, x, y, z)
						local th = SysTime() - t0
						if heapOn then Heap("drops.ownbody") end
						tHit = tHit + th
						prof.hb, prof.hbs = prof.hb + th * 1000, prof.hbs + 1
						if bone then
							local tl = SysTime()
							local inx, iny, inz = ABL.Norm(-vx, -vy, -vz)
							HitCharacter(d, i, src.body, bone, hx, hy, hz, inx, iny, inz)
							removed = true
							tLand = tLand + SysTime() - tl
							if heapOn then Heap("drops.land") end
						end
					end
				end
				d.hbx, d.hby, d.hbz = x, y, z
			end

			-- a surface found ahead earlier: impact once the drop gets there
			local hit = not removed and d.hit
			if hit then
				if Along(x, y, z, hit.sx, hit.sy, hit.sz, hit.ex, hit.ey, hit.ez) >= hit.Fraction then
					if heapOn then Heap("drops.move") end
					local ti = SysTime()
					Collide(d, i, hit)
					tImp = tImp + (SysTime() - ti)
					if heapOn then Heap("drops.impact") end
					removed = true
				elseif simT > hit.expire then
					-- it curved away (drag, or the surface moved): look again
					d.hit = nil
					d.nextTrace = 0
				end
			end

			if not removed and not d.hit and simT >= d.nextTrace and L.TakeTrace() then
				-- Look ahead along the chord to where the drop will be `reach` seconds from now. A
				-- clear look lengthens the next one (up to C.DROP_LOOK_MAX): a drop in free flight
				-- needs a handful of traces, one about to land is followed closely.
				local la = d.la
				if la < period then la = period end
				local reach = la * 1.25
				local hl = 0.5 * reach * reach
				local ex, ey, ez = x + vx * reach + gx * hl, y + vy * reach + gy * hl, z + vz * reach + gz * hl
				vStart:SetUnpacked(d.cx, d.cy, d.cz)
				vEnd:SetUnpacked(ex, ey, ez)
				traceData.start = vStart
				traceData.endpos = vEnd
				if src then
					traceData.filter = (now < d.ignoreBody + 0.06) and src.filterAll or src.filterOwner
				else
					traceData.filter = nil
				end
				if heapOn then Heap("drops.move") end
				local t0 = SysTime()
				util.TraceLine(traceData)
				local tt = SysTime() - t0
				if heapOn then Heap("drops.trace") end
				tTrace = tTrace + tt
				prof.tr, prof.trs = prof.tr + tt * 1000, prof.trs + 1
				d.nextTrace = simT + la * 0.98
				local tr = traceOut
				if tr.Hit then
					local p0 = Along(x, y, z, d.cx, d.cy, d.cz, ex, ey, ez)
					if tr.AllSolid then
						-- emitted inside solid/water (e.g. a body lying in water)
						vEnd:SetUnpacked(x, y, z)
						if band(util.PointContents(vEnd), CONTENTS_WATER) ~= 0 then D.WaterCloud(vEnd, Vector(vx, vy, vz), d.vol) end
						ABL.FlowCore.Move("airborne", "lost", d.vol)
						Release(i) removed = true
					elseif p0 >= tr.Fraction then
						-- already there
						local ti = SysTime()
						Collide(d, i, tr)
						tImp = tImp + (SysTime() - ti)
						if heapOn then Heap("drops.impact") end
						removed = true
					else
						-- remembered until the drop gets there; if it is late (drag), look again
						local eta = (tr.Fraction - p0) / max(1 - p0, 1e-3) * reach
						Remember(d, tr, d.cx, d.cy, d.cz, ex, ey, ez, simT + eta * 1.5 + period * 2)
						d.la = traceDt
					end
				else
					d.cx, d.cy, d.cz = x, y, z
					d.la = min(la * 1.6, lookMax)
				end
			end

			if not removed and (now - d.born > 7 or z < -32000) then
				ABL.FlowCore.Move("airborne", "lost", d.vol)
				Release(i)
			end
		end
		i = i - 1
		if i > #list then i = #list end
	end
	local Prof = ABL.Prof
	Prof.Add("sub.drops.trace", tTrace) Prof.Add("sub.drops.ownbody", tHit) Prof.Add("sub.drops.impact", tImp)
	Prof.Add("sub.drops.land", tLand)
	Prof.Add("sub.drops.onbody", tAddAt) Prof.Add("sub.drops.bodydecal", tDecal)
	Prof.Count("drops onto a stream", nAddAt) Prof.Count("drops as a body decal", nDecal)
	tAddAt, tDecal, nAddAt, nDecal = 0, 0, 0, 0
end

------------------------------------------------------------------------------------------
-- Rendering.
-- Near the camera a drop is a small shaded 3D body: an ellipsoid a little longer along its motion
-- (and a little flattened or stretched per drop, as falling drops oscillate), shaded per vertex like
-- a liquid: a deep crimson body lit from above, the sky mirrored along its upper rim and the ground
-- along its lower rim (Fresnel), a faint red glow where light leaves it on the far side, and a sharp
-- highlight of the sun / sky as an additive glint at the true reflection point. Farther drops are lit
-- sprites of the same drop (texture), smeared into a streak when they move fast. Linked stream drops
-- (arterial jets, pours) are drawn as one continuous liquid ribbon through them (DrawStream).
------------------------------------------------------------------------------------------
local NEAR3D, MAX3D, SEG = 170, 32, 8
local PX3D = 2.5          -- a drop is modelled in 3D when its radius covers at least this many pixels
local RSTR = SEG + 1
local ringC, ringS = {}, {}
for i = 0, SEG do ringC[i] = math.cos(i / SEG * 6.2831853) ringS[i] = math.sin(i / SEG * 6.2831853) end
-- profile along the axis (front -> tail): { position (radii), ring radius }
-- (a sphere: a drop in the air is round. The pointed tail it had before led the way: the axis is
-- the direction of motion.)
local PROF = { { -1, 0 }, { -0.74, 0.673 }, { -0.26, 0.966 }, { 0.26, 0.966 }, { 0.74, 0.673 }, { 1, 0 } }
local NPROF = #PROF
-- the drops to draw in 3D this frame, 13 numbers each, and the vertices of the one being drawn
-- (reused: nothing is allocated per drop or per frame)
local N3, near3dN = {}, 0
local VX, VY, VZ, VR, VG, VB = {}, {}, {}, {}, {}, {}
local vtx = Vector()

local function DV(x, y, z, r, g, b)
	vtx:SetUnpacked(x, y, z)
	mesh.Position(vtx)
	mesh.Color(r, g, b, 252)
	mesh.AdvanceVertex()
end

-- Liquid shading of one vertex (normal n, position p). ux..: up (against gravity); sx..: key light
-- direction (sun, or the sky straight above); lr..: light at the drop (display space).
local function ShadeDrop(nx, ny, nz, px, py, pz, ex, ey, ez, ux, uy, uz, sx, sy, sz, cr, cg, cb, lr, lg, lb)
	local wx, wy, wz = ex - px, ey - py, ez - pz
	local wl = sqrt(wx * wx + wy * wy + wz * wz)
	if wl < 1e-4 then wl = 1e-4 end
	wx, wy, wz = wx / wl, wy / wl, wz / wl
	local ndv = nx * wx + ny * wy + nz * wz
	if ndv < 0 then ndv = 0 end
	local up = nx * ux + ny * uy + nz * uz
	local key = nx * sx + ny * sy + nz * sz
	-- body: diffuse from the sky and the key light, darker underneath
	local k = 0.45 + 0.35 * (up > 0 and up or 0) + 0.45 * (key > 0 and key or 0)
	-- light passing through the drop leaves it on the side away from the key light
	local glow = (key < 0 and -key or 0) * (1 - ndv) * 0.9
	-- mirror: sky above the horizon, ground below
	local rup = 2 * ndv * up - (wx * ux + wy * uy + wz * uz)
	-- (kept low: a drop is a few millimetres of dark liquid, and a bright mirror on it reads grey)
	local env = rup > 0 and 0.3 + 0.5 * min(rup * 1.6, 1) or 0.1
	local q = 1 - ndv
	local f = 0.022 + 0.978 * q * q * q * q * q
	local s = f * env * 255
	local r = (cr * k + cr * glow * 1.4) * (1 - f) + s
	local g = (cg * k + cg * glow * 0.6) * (1 - f) + s * 0.97
	local b = (cb * k + cb * glow * 0.6) * (1 - f) + s * 0.95
	return min(255, r * lr), min(255, g * lg), min(255, b * lb)
end

local glints, glintN = {}, 0

-- All 3D drops go into one triangle strip: each drop is its profile's bands one after another (a
-- closed band ends where the next begins; the tips are rings of radius 0), joined to the next drop
-- by two repeated vertices. 92 vertices per drop.
local function Draw3D(ex, ey, ez, gx, gy, gz)
	local n = near3dN
	if n == 0 then return end
	near3dN = 0
	local ux, uy, uz = -gx, -gy, -gz
	local sx, sy, sz, sunVis = ABL.Render.Sun()
	if not sx then sx, sy, sz = ABL.Norm(ux + 0.25, uy + 0.15, uz) sunVis = 0.4 end
	render.SetColorMaterial()
	mesh.Begin(MATERIAL_TRIANGLE_STRIP, n * ((NPROF - 1) * RSTR * 2 + 2) - 4)
	local col = C.Colors.wet
	glintN = 0
	for k = 0, n - 1 do
		local o = k * 13
		local x, y, z, rad, ax, ay, az, el = N3[o + 1], N3[o + 2], N3[o + 3], N3[o + 4], N3[o + 5], N3[o + 6], N3[o + 7], N3[o + 8]
		local lr, lg, lb, tone, shape = N3[o + 9], N3[o + 10], N3[o + 11], N3[o + 12], N3[o + 13]
		local cr, cg, cb = col[1] * tone, col[2], col[3]
		local px, py, pz = ABL.Perp(ax, ay, az)
		local qx, qy, qz = ay * pz - az * py, az * px - ax * pz, ax * py - ay * px
		local sq = 1 / sqrt(shape)
		for j = 1, NPROF do
			local pj = PROF[j]
			local t, rr = pj[1] * rad * el * shape, pj[2] * rad * sq
			local cx, cy, cz = x + ax * t, y + ay * t, z + az * t
			local base = (j - 1) * RSTR
			if rr > 0 then
				-- normal of the profile surface (radial + axial tilt from the profile's slope)
				local pr, tn = pj[2], pj[1]
				local nl = 1 / sqrt(pr * pr + tn * tn)
				pr, tn = pr * nl, tn * nl
				for i = 0, SEG - 1 do
					local c, s = ringC[i], ringS[i]
					local ox, oy, oz = px * c + qx * s, py * c + qy * s, pz * c + qz * s
					local vx, vy, vz = cx + ox * rr, cy + oy * rr, cz + oz * rr
					local id = base + i
					VX[id], VY[id], VZ[id] = vx, vy, vz
					VR[id], VG[id], VB[id] = ShadeDrop(ox * pr + ax * tn, oy * pr + ay * tn, oz * pr + az * tn,
						vx, vy, vz, ex, ey, ez, ux, uy, uz, sx, sy, sz, cr, cg, cb, lr, lg, lb)
				end
			else
				local sg = pj[1] < 0 and -1 or 1
				local r, g, b = ShadeDrop(ax * sg, ay * sg, az * sg, cx, cy, cz, ex, ey, ez, ux, uy, uz, sx, sy, sz, cr, cg, cb, lr, lg, lb)
				for i = 0, SEG - 1 do
					local id = base + i
					VX[id], VY[id], VZ[id], VR[id], VG[id], VB[id] = cx, cy, cz, r, g, b
				end
			end
			local a, b = base, base + SEG
			VX[b], VY[b], VZ[b], VR[b], VG[b], VB[b] = VX[a], VY[a], VZ[a], VR[a], VG[a], VB[a]
		end
		-- (the faces toward the viewer are the ones the engine keeps: clockwise as seen from outside)
		if k > 0 then DV(VX[0], VY[0], VZ[0], VR[0], VG[0], VB[0]) end
		for j = 1, NPROF - 1 do
			local b1, b2 = (j - 1) * RSTR, j * RSTR
			for i = 0, SEG do
				local p, q = b2 + i, b1 + i
				DV(VX[q], VY[q], VZ[q], VR[q], VG[q], VB[q])
				DV(VX[p], VY[p], VZ[p], VR[p], VG[p], VB[p])
			end
		end
		if k < n - 1 then
			local id = (NPROF - 1) * RSTR + SEG
			DV(VX[id], VY[id], VZ[id], VR[id], VG[id], VB[id])
		end
		-- the key light's reflection: on a sphere it sits where the normal is the half vector
		local wx, wy, wz = ABL.Norm(ex - x, ey - y, ez - z)
		local hx, hy, hz = ABL.Norm(wx + sx, wy + sy, wz + sz)
		glintN = glintN + 1
		local gI = glints[glintN] or {}
		glints[glintN] = gI
		gI[1], gI[2], gI[3] = x + hx * rad * 0.9 + wx * rad * 0.2, y + hy * rad * 0.9 + wy * rad * 0.2, z + hz * rad * 0.9 + wz * rad * 0.2
		gI[4], gI[5] = rad * 0.55, 150 + 105 * sunVis
		gI[6], gI[7], gI[8] = lr, lg, lb
	end
	mesh.End()
	-- glints: queued into the additive sprite batch (flushed after this)
	local R = ABL.Render
	for i = 1, glintN do
		local gI = glints[i]
		local a = gI[5]
		R.Streak(ABL.Mat.glint, gI[1], gI[2], gI[3], 0, 0, 0, 0, gI[4], min(255, a * gI[6]), min(255, a * gI[7]), min(255, a * gI[8]), 255)
	end
end

-- Streams: each chain of linked drops (newest, at the wound, first) becomes one ribbon facing the
-- camera through the drops' interpolated positions, a liquid cylinder texture tiled along it.
-- The ribbon follows a smooth curve through the drops (an extra point between each pair). Where
-- the drops have moved apart the stream thins (the same volume over more length), and it breaks
-- where it was stretched too far (between the pulses of an arterial jet), where a link is missing
-- (a drop hit something) or a gap is too long; what lies behind a break is its own stream.
-- It ends for good where the thread has been in the air longer than a thread of its width holds
-- together (D.Link): from there on its pieces are drops, drawn as drops.
local chainPts = {}
local rawX, rawY, rawZ, rawW, rawT, rawS = {}, {}, {}, {}, {}, {}
local STREAM_BREAK = 4
local function ChainPoint(k, x, y, z, w, tone)
	local p = chainPts[k]
	if not p then p = {} chainPts[k] = p end
	p[1], p[2], p[3], p[4], p[5] = x, y, z, w, tone
end
local function DrawChain(head, lr, lg, lb, ct)
	if head.loose then return nil end
	local R = ABL.Render
	local n = 0
	local d = head
	local nextHead = nil
	while d do
		n = n + 1
		rawX[n], rawY[n], rawZ[n] = d.rx, d.ry, d.rz
		-- the thread's own width; it necks over the second half of the time it holds together
		local w = d.sw or d.r
		local ta = (ct - d.born) / (d.tb or 0.1)
		if ta > 0.5 then w = w * (1.5 - ta) end
		rawW[n] = max(w, d.minW)
		rawT[n] = d.tone
		rawS[n] = 1
		local pv = d.prev
		if pv and (pv.dead or pv.id ~= d.prevId or not pv.rx or pv.loose) then pv = nil end
		if pv then
			local dx, dy, dz = pv.rx - d.rx, pv.ry - d.ry, pv.rz - d.rz
			local len2 = dx * dx + dy * dy + dz * dz
			local st = sqrt(len2) / (d.link0 or 3)
			if len2 > 24 * 24 or st > STREAM_BREAK then
				nextHead = pv
				pv = nil
			else
				rawS[n] = st
			end
		end
		d.drawn = true
		d = pv
		if n >= 96 then nextHead = d break end
	end
	if n < 2 then
		head.drawn = false
		return nextHead
	end
	-- points: the drops, and between each pair a point on the curve through them (Catmull-Rom)
	local np = 0
	for k = 1, n do
		-- width: thinner where the links at this drop are stretched, thicker where they bunch up
		local s1 = k > 1 and rawS[k - 1] or rawS[k]
		local s2 = k < n and rawS[k] or s1
		local wf = 1 / sqrt(max((s1 + s2) * 0.5, 0.55))
		np = np + 1
		ChainPoint(np, rawX[k], rawY[k], rawZ[k], rawW[k] * wf, rawT[k])
		if k < n then
			local a, b = k > 1 and k - 1 or k, k + 2 <= n and k + 2 or k + 1
			local j = k + 1
			local wm = 1 / sqrt(max(rawS[k], 0.55))
			np = np + 1
			ChainPoint(np,
				(-rawX[a] + 9 * rawX[k] + 9 * rawX[j] - rawX[b]) * 0.0625,
				(-rawY[a] + 9 * rawY[k] + 9 * rawY[j] - rawY[b]) * 0.0625,
				(-rawZ[a] + 9 * rawZ[k] + 9 * rawZ[j] - rawZ[b]) * 0.0625,
				(rawW[k] + rawW[j]) * 0.5 * wm, (rawT[k] + rawT[j]) * 0.5)
		end
	end
	n = np
	local ex, ey, ez = L.eyeX, L.eyeY, L.eyeZ
	-- per point: left / right edge (shared by the segments on both sides: no cracks at joints)
	local vacc = 0
	for k = 1, n do
		local p = chainPts[k]
		local a, b = chainPts[k > 1 and k - 1 or k], chainPts[k < n and k + 1 or k]
		local tx, ty, tz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local vx, vy, vz = ex - p[1], ey - p[2], ez - p[3]
		local rx, ry, rz = ty * vz - tz * vy, tz * vx - tx * vz, tx * vy - ty * vx
		local rl = sqrt(rx * rx + ry * ry + rz * rz)
		if rl < 1e-6 then rx, ry, rz, rl = 1, 0, 0, 1 end
		-- the ends of the stream taper (the pulse front, and where it breaks up)
		local w = p[4] * 0.5 * ((k == 1 or k == n) and 0.45 or (k == 2 or k == n - 1) and 0.8 or 1)
		rx, ry, rz = rx / rl * w, ry / rl * w, rz / rl * w
		p[6], p[7], p[8] = p[1] - rx, p[2] - ry, p[3] - rz
		p[9], p[10], p[11] = p[1] + rx, p[2] + ry, p[3] + rz
		if k > 1 then
			local q = chainPts[k - 1]
			vacc = vacc + sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2) / max(p[4] * 4, 0.5)
		end
		p[12] = vacc
	end
	local mat = ABL.Mat.streamTile
	for k = 1, n - 1 do
		local p, q = chainPts[k], chainPts[k + 1]
		local t = (p[5] + q[5]) * 0.5
		R.Quad(mat, p[6], p[7], p[8], p[9], p[10], p[11], q[9], q[10], q[11], q[6], q[7], q[8],
			min(255, 255 * lr * t), min(255, 255 * lg), min(255, 255 * lb), 245, 0, p[12], 1, q[12])
	end
	return nextHead
end

local function DrawStream(head, lr, lg, lb, ct)
	local d = head
	local guard = 0
	while d and guard < 24 do
		guard = guard + 1
		d = DrawChain(d, lr, lg, lb, ct)
	end
end

function D.Draw()
	local R = ABL.Render
	local M = ABL.Mat
	local Sim = ABL.Sim
	local now = RealTime()
	local ct = CurTime()
	local drawDist2 = C.cl.drawDist:GetFloat() ^ 2
	local ex, ey, ez = L.eyeX, L.eyeY, L.eyeZ
	local near2 = NEAR3D * NEAR3D
	near3dN = 0
	-- a drop gets its 3D body where that can be seen (its radius at least PX3D pixels): a smaller one
	-- is the lit sprite of the same drop. Under load the governor lowers how many are modelled.
	local k3d = (L.pxK or 960) / PX3D
	local max3d = max(6, floor(MAX3D * L.scale))
	-- positions between the last two simulated states (each drop has its own step rate)
	local streams = false
	for i = 1, #list do
		local d = list[i]
		local a = Sim.Alpha(d.lt, d.sd)
		d.rx = d.px + (d.x - d.px) * a
		d.ry = d.py + (d.y - d.py) * a
		d.rz = d.pz + (d.z - d.pz) * a
		d.drawn = false
		-- distant drops are kept at least ~1 pixel wide
		local dx, dy, dz = d.rx - ex, d.ry - ey, d.rz - ez
		d.minW = sqrt(dx * dx + dy * dy + dz * dz) * 0.0016
		if d.stream then
			streams = true
			d.newer = false
			-- (a thread of blood holds together only so long: DrawChain)
			if not d.loose and ct - d.born > (d.tb or 0.1) then d.loose = true end
		end
	end
	-- streams: mark every drop that a newer one links to; the newest of each chain is its head
	if streams then
		for i = 1, #list do
			local d = list[i]
			local pv = d.prev
			if pv and not pv.dead and pv.id == d.prevId then pv.newer = true end
		end
	end
	for i = 1, #list do
		local d = list[i]
		local x, y, z = d.rx, d.ry, d.rz
		local dx, dy, dz = x - ex, y - ey, z - ez
		local dist2 = dx * dx + dy * dy + dz * dz
		if dist2 < drawDist2 then
			if now > d.lightT then
				d.lightT = now + 0.25
				d.lr, d.lg, d.lb = R.Light(x, y, z)
			end
			if d.stream and not d.newer and d.prev then DrawStream(d, d.lr, d.lg, d.lb, ct) end
		end
	end
	for i = 1, #list do
		local d = list[i]
		if not d.drawn then
			local x, y, z = d.rx, d.ry, d.rz
			local dx, dy, dz = x - ex, y - ey, z - ez
			local dist2 = dx * dx + dy * dy + dz * dz
			if dist2 < drawDist2 then
				local vx, vy, vz = d.vx, d.vy, d.vz
				local sp = sqrt(vx * vx + vy * vy + vz * vz)
				local w = d.r * 2
				-- distant drops are kept at least ~1 pixel wide
				if w < d.minW then w = d.minW end
				local ax, ay, az = 0, 0, 1
				if sp > 1e-3 then ax, ay, az = vx / sp, vy / sp, vz / sp end
				local tone = d.tone or 1
				local lim = d.r * k3d
				-- (a piece of a stream that broke away is a drop like any other, a little longer: the
				-- ligament it came from)
				local jet = d.kind == 1
				if dist2 < near2 and dist2 < lim * lim and near3dN < max3d then
					-- a real little drop: an ellipsoid, a bit longer along its motion when fast
					local o = near3dN * 13
					near3dN = near3dN + 1
					N3[o + 1], N3[o + 2], N3[o + 3], N3[o + 4], N3[o + 5], N3[o + 6], N3[o + 7] = x, y, z, d.r, ax, ay, az
					N3[o + 8], N3[o + 9], N3[o + 10], N3[o + 11], N3[o + 12], N3[o + 13] = (jet and 1.35 or 1) + min(sp / 500, 0.6), d.lr, d.lg, d.lb, tone, d.shape or 1
				else
					-- the sprites carry the drop's colour and highlight; vertex colour = light x tone
					local r, g, b = min(255, 255 * d.lr * tone), min(255, 255 * d.lg), min(255, 255 * d.lb)
					local blur = min(sp / 120, 2.4) + (jet and w * 0.6 or 0)
					if blur > w * 0.6 then
						R.Streak(M.dropStreak, x, y, z, ax, ay, az, w + blur, w, r, g, b, 240)
					else
						R.Streak(M.droplet, x, y, z, ax, ay, az, w + blur, w, r, g, b, 245)
					end
				end
			end
		end
	end
	local gx, gy, gz, gmag = ABL.Gravity()
	Draw3D(ex, ey, ez, gx / gmag, gy / gmag, gz / gmag)
end

function D.Clear()
	for i = #list, 1, -1 do Release(i) end
	for i = 1, #partExpiry do partExpiry[i] = nil end
	partCount = 0
end

function D.ParticleCount() return partCount end
D.PruneParticles = PruneParticles
