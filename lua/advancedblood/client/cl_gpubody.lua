ABL.NoJIT()
local GP = ABL.GPU
local BM = ABL.BodyMesh
local max = math.max

local BODY_RES = 256
local BODY_TEXEL_UNITS = 0.3
local TEXEL_MM2 = (BODY_TEXEL_UNITS * 25.4) ^ 2
local ML_TO_MM3 = 1000
local STAMP_INTEGRAL = 0.995
local SEEP_TEXELS = 2
local DROP_TEXELS_PER_MM = 0.5
local MIN_TEXELS = 1
local MAX_STAMPS = 256
local ANCHOR_REACH = 6

local GEO_MOVING = 0.1
local GEO_STILL = 0.6
local STILL_SPEED = 4

local K_FLOW = 20
local H_PIN = 0.04
local K_GRAV = 4
local SEAM_UNITS = 3
local EDGE_PIN = 0.35
local MAX_FLUX = 0.2
local DRY_RATE = 0.02
local EVAP = 0.004
local SOAK_CLOTH = 0.35
local ABSORB = 14
local STAIN_ABSORB = 6
local SHINE = 0.8
local DRAW_DIST = 2500
local LIGHT_REFRESH = 1
local LIGHT_FLOOR = 0.04

GP.cvBodies = CreateClientConVar("abl_gpu_bodies", "12", true, false, "GPU blood: body surfaces with simulated blood film (one per bloodied model material).", 2, 32)

local bodies = {}
GP.bodies = bodies
local slots = {}
GP.bodySlots = slots
local bodyCount = 0

local shared
local function Shared()
	if shared then return shared end
	shared = {
		inflow = GP.RT("bodyinflow", IMAGE_FORMAT_RGBA16161616F, BODY_RES),
		none = GP.Mat("bodynone", "model_vs30", "none_ps30", true, true),
	}

	return shared
end

local function NewSlot(i)
	local s = GP.Shared()
	local slot = { index = i }
	slot.rt = {
		GP.RT("body" .. i .. "a", IMAGE_FORMAT_RGBA16161616F, BODY_RES),
		GP.RT("body" .. i .. "b", IMAGE_FORMAT_RGBA16161616F, BODY_RES),
	}
	slot.geo = GP.RT("bodygeo" .. i, IMAGE_FORMAT_RGBA16161616F, BODY_RES)
	slot.unwrap = GP.Mat("bodyunwrap" .. i, "unwrap_vs30", "geo_ps30", false, true)
	slot.sim, slot.draw = {}, {}
	for k = 1, 2 do
		local sim = GP.Mat("bodysim" .. i .. "_" .. k, "clip_vs30", "simbody_ps30")
		sim:SetTexture("$basetexture", slot.rt[k])
		sim:SetTexture("$texture1", s.zero)
		sim:SetTexture("$texture2", slot.geo)
		GP.SetC(sim, 0, 1 / BODY_RES, 1 / GP.SIM_HZ, K_FLOW, H_PIN)
		GP.SetC(sim, 2, SEAM_UNITS, EDGE_PIN, MAX_FLUX, 0)
		slot.sim[k] = sim
		local draw = GP.Mat("bodyfilm" .. i .. "_" .. k, "model_vs30", "bodyfilm_ps30", true, true)
		draw:SetTexture("$basetexture", slot.rt[k])
		GP.SetC(draw, 0, 1 / BODY_RES, ABSORB, STAIN_ABSORB, SHINE)
		slot.draw[k] = draw
	end
	slots[i] = slot

	return slot
end

local function ReleaseSub(sub)
	if sub.slot then sub.slot.sub = nil sub.slot = nil end
end

local function ReleaseBody(b)
	for _, sub in pairs(b.subs) do ReleaseSub(sub) end
	if bodies[b.ent] == b then
		bodies[b.ent] = nil
		bodyCount = bodyCount - 1
	end
end

local function TakeSlot()
	local cap = GP.cvBodies:GetInt()
	for i = 1, cap do
		local slot = slots[i] or NewSlot(i)
		if not slot.sub then return slot end
	end
	local oldest
	for i = 1, cap do
		local sub = slots[i].sub
		if sub and (not oldest or sub.body.last < oldest.body.last) then oldest = sub end
	end
	if not oldest then return nil end
	local slot = oldest.slot
	oldest.body.subs[oldest.mat] = nil
	ReleaseSub(oldest)
	if next(oldest.body.subs) == nil then ReleaseBody(oldest.body) end

	return slot
end

local function MatIndex(b, mat)
	local idx = b.matIndex[mat]
	if idx then return idx end
	local tail = string.match(mat, "([^/\\]+)$") or mat

	return b.matTail[tail]
end

local function BodyOf(ent)
	local b = bodies[ent]
	if b and b.model ~= ent:GetModel() then
		ReleaseBody(b)
		b = nil
	end
	if b then return b end
	b = { ent = ent, model = ent:GetModel(), subs = {}, matIndex = {}, matTail = {}, last = RealTime(), geoT = 0, lightT = 0 }
	for i, name in ipairs(ent:GetMaterials()) do
		local lower = string.lower(name)
		b.matIndex[lower] = i - 1
		b.matTail[string.match(lower, "([^/\\]+)$") or lower] = i - 1
	end
	b.matCount = #ent:GetMaterials()
	bodies[ent] = b
	bodyCount = bodyCount + 1

	return b
end

local function SubFor(ent, mat, skin)
	local b = BodyOf(ent)
	local sub = b.subs[mat]
	if sub then return sub end
	local idx = MatIndex(b, mat)
	if not idx then return nil end
	local slot = TakeSlot()
	if not slot then return nil end
	sub = { body = b, mat = mat, index = idx, slot = slot, stamps = {}, cur = 1, pending = true }
	slot.sub = sub
	for k = 1, 2 do GP.SetC(slot.sim[k], 3, DRY_RATE, EVAP, skin and 0 or SOAK_CLOTH, 0) end
	b.subs[mat] = sub
	b.geoT = 0

	return sub
end

local function Stamp(sub, tu, tv, texels, volML)
	local list = sub.stamps
	local r = max(texels, MIN_TEXELS)
	local peak = volML * ML_TO_MM3 / (STAMP_INTEGRAL * r * r * TEXEL_MM2)
	if #list >= MAX_STAMPS then
		list[#list][7] = list[#list][7] + peak
	else
		list[#list + 1] = { (tu % 1) * BODY_RES, (tv % 1) * BODY_RES, r, r, 1, 0, peak }
	end
	sub.body.last = RealTime()
end

local function Feed(src, tri, u, v, texels, vol)
	if not GP.Ready() or not (vol > 0) then return false end
	local body, m = src.body, src.mesh
	if not (IsValid(body) and m and m.ready and tri and tri <= m.nt) then return false end
	local tu, tv, mat = BM.TexPoint(m, tri, u, v)
	if not tu then return false end
	local sub = SubFor(body, mat, m.tskin[tri])
	if not sub then return false end
	Stamp(sub, tu, tv, texels, vol)

	return true
end

function GP.BodyFeed(src, wd, vol)
	return Feed(src, wd.tri, wd.u, wd.v, SEEP_TEXELS, vol)
end

function GP.BodyAdd(src, bone, x, y, z, vol)
	if not GP.Ready() or not src.mesh or not src.pose then return false end
	local tri, u, v = BM.Anchor(src.pose, bone, x, y, z, ANCHOR_REACH)
	if not tri then return false end
	local texels = ABL.DropDiameterMM(vol) * DROP_TEXELS_PER_MM

	return Feed(src, tri, u, v, texels, vol)
end

local function Unwrap(b)
	local none = Shared().none
	local ent = b.ent
	local c = ent:WorldSpaceCenter()
	b.center = c
	for _, sub in pairs(b.subs) do
		local slot = sub.slot
		GP.SetC(slot.unwrap, 0, c.x, c.y, c.z, 0)
		render.PushRenderTarget(slot.geo)
		render.Clear(0, 0, 0, 0)
		for i = 0, b.matCount - 1 do
			render.MaterialOverrideByIndex(i, i == sub.index and slot.unwrap or none)
		end
		ent:DrawModel()
		render.MaterialOverrideByIndex()
		render.PopRenderTarget()
	end
end

local function StepSub(sub, steps, dt, g)
	local s, shared2 = GP.Shared(), Shared()
	local slot = sub.slot
	if sub.pending then
		for k = 1, 2 do
			render.PushRenderTarget(slot.rt[k])
			render.Clear(0, 0, 0, 0)
			render.PopRenderTarget()
		end
		sub.pending = nil
	end
	local hasInflow = #sub.stamps > 0
	if hasInflow then
		render.PushRenderTarget(shared2.inflow)
		render.Clear(0, 0, 0, 0)
		render.SetMaterial(s.stamp)
		GP.Additive(true)
		GP.StampQuads(sub.stamps, BODY_RES)
		GP.Additive(false)
		render.PopRenderTarget()
		sub.stamps = {}
	end
	for i = 1, steps do
		local from = sub.cur
		local sim = slot.sim[from]
		sim:SetTexture("$texture1", (i == 1 and hasInflow) and shared2.inflow or s.zero)
		sim:SetFloat("$c0_y", dt)
		GP.SetC(sim, 1, g.x, g.y, g.z, K_GRAV)
		render.PushRenderTarget(slot.rt[3 - from])
		render.SetMaterial(sim)
		GP.FullQuad(BODY_RES)
		render.PopRenderTarget()
		sub.cur = 3 - from
	end
end

local function StepBody(b, now, steps, g)
	local idle = now - b.last
	local hasStamps = false
	for _, sub in pairs(b.subs) do
		if #sub.stamps > 0 or sub.pending then hasStamps = true break end
	end
	local n, dt
	if hasStamps or idle < GP.ACTIVE_HOLD then
		n, dt = steps, 1 / GP.SIM_HZ
	elseif idle < GP.DRY_TIME and now >= (b.slowT or 0) then
		b.slowT = now + GP.SLOW_DT
		n, dt = 1, GP.SLOW_DT
	else
		return
	end
	if n <= 0 then return end
	if now >= b.geoT then
		local still = b.ent:GetVelocity():LengthSqr() < STILL_SPEED * STILL_SPEED
		b.geoT = now + (still and GEO_STILL or GEO_MOVING)
		Unwrap(b)
	end
	for _, sub in pairs(b.subs) do StepSub(sub, n, dt, g) end
end

function GP.BodySim(now, steps)
	if bodyCount == 0 then return end
	local gx, gy, gz = ABL.Gravity()
	local g = Vector(gx, gy, gz)
	g:Normalize()
	local dead = {}
	for ent, b in pairs(bodies) do
		if not IsValid(ent) then dead[#dead + 1] = b end
	end
	for _, b in ipairs(dead) do ReleaseBody(b) end
	if bodyCount == 0 then return end
	cam.Start3D(EyePos(), EyeAngles())
	for ent, b in pairs(bodies) do
		if not ent:IsDormant() then StepBody(b, now, steps, g) end
	end
	cam.End3D()
end

local function Visible(ent, eye)
	if ent:IsDormant() or ent:GetNoDraw() then return false end
	if ent == LocalPlayer() and not ent:ShouldDrawLocalPlayer() then return false end

	return ent:WorldSpaceCenter():DistToSqr(eye) < DRAW_DIST * DRAW_DIST
end

function GP.BodyDraw()
	if bodyCount == 0 then return end
	local none = Shared().none
	local eye = EyePos()
	local now = RealTime()
	for ent, b in pairs(bodies) do
		if IsValid(ent) and Visible(ent, eye) then
			if now >= b.lightT then
				b.lightT = now + LIGHT_REFRESH
				local l = render.GetLightColor(ent:WorldSpaceCenter())
				b.light = Vector(max(l.x, LIGHT_FLOOR), max(l.y, LIGHT_FLOOR), max(l.z, LIGHT_FLOOR))
			end
			for i = 0, b.matCount - 1 do render.MaterialOverrideByIndex(i, none) end
			for _, sub in pairs(b.subs) do
				if not sub.pending then
					local mat = sub.slot.draw[sub.cur]
					GP.SetC(mat, 1, b.light.x, b.light.y, b.light.z, 0)
					GP.SetC(mat, 2, eye.x, eye.y, eye.z, 0)
					GP.SetC(mat, 3, 1, 0, 0, 0)
					render.MaterialOverrideByIndex(sub.index, mat)
				end
			end
			ent:DrawModel()
			render.MaterialOverrideByIndex()
		end
	end
end

function GP.BodyCount()
	return bodyCount
end

function GP.BodyClear()
	local list = {}
	for _, b in pairs(bodies) do list[#list + 1] = b end
	for _, b in ipairs(list) do ReleaseBody(b) end
end
