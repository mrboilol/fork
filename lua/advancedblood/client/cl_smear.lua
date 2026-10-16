ABL.NoJIT()
ABL.Smear = ABL.Smear or {}
local SM = ABL.Smear
local C, L = ABL.Config, ABL.LOD
local K = C.Smear
local sqrt, min, max, Clamp = math.sqrt, math.min, math.max, math.Clamp

local walkers = setmetatable({}, { __mode = "k" })
local rags = setmetatable({}, { __mode = "k" })

local trOut = {}
local tr = { mask = MASK_SOLID, output = trOut, filter = ABL.Surface.ProbeFilter }
local vA, vB = Vector(), Vector()

local DRAG_BONES = {
	"ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Head1",
	"ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm",
	"ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_R_Foot",
}

local function Down(x, y, z, reach)
	if not L.TakeTrace() then return false end
	local gx, gy, gz, gmag = ABL.Gravity()
	gx, gy, gz = gx / gmag, gy / gmag, gz / gmag
	vA:SetUnpacked(x - gx * 4, y - gy * 4, z - gz * 4)
	vB:SetUnpacked(x + gx * reach, y + gy * reach, z + gz * reach)
	tr.start, tr.endpos = vA, vB
	util.TraceLine(tr)
	if not trOut.Hit or trOut.StartSolid then return false end
	local n = trOut.HitNormal
	if -(n.x * gx + n.y * gy + n.z * gz) < 0.64 then return false end
	return true
end

local function WetPools()
	for _, p in ipairs(ABL.Pools.list) do
		if p.wet > 0.02 and p.fade >= 1 then return true end
	end
	return false
end

local function NearPool(x, y, z, extra)
	for _, p in ipairs(ABL.Pools.list) do
		if p.wet > 0.02 and p.fade >= 1 then
			local r = (p.rad or 60) + extra
			if (p.x - x) ^ 2 + (p.y - y) ^ 2 + (p.z - z) ^ 2 < r * r then return true end
		end
	end
	return false
end

local stainTmp = {}
local function StainLoad(x, y, z, nx, ny, nz)
	local n = ABL.BloodMap.Query(x, y, z, nx, ny, nz, 2, stainTmp)
	local now, best = CurTime(), 0
	for i = 1, n do
		local r = stainTmp[i]
		best = max(best, ABL.BloodMap.Wet(r, now) * r.m)
		stainTmp[i] = nil
	end
	return best > 0.3 and K.stainPickup * best or 0
end

local function Print(x, y, z, nx, ny, nz, dx, dy, dz, len, w, load)
	local alpha = Clamp(load / K.maxLoad * 260, 40, 220)
	if ABL.Stains.Place("smear", ABL.Mat.Random("smear"), x, y, z, nx, ny, nz, dx, dy, dz, len, w, C.Colors.decal, alpha, nil, K.printWet) then
		ABL.Surface.WetAdd(x, y, z, load * 0.2, 90)
		return true
	end
	return false
end

local function Step(ply, st, side)
	local pos = ply:GetPos()
	local vel = ply:GetVelocity()
	local vx, vy = vel.x, vel.y
	local vl = sqrt(vx * vx + vy * vy)
	if vl < 1 then return end
	local dx, dy = vx / vl, vy / vl
	local fx, fy, fz = pos.x - dy * K.footSide * side, pos.y + dx * K.footSide * side, pos.z + 2
	if not Down(fx, fy, fz, 12) then return end
	local hp, hn = trOut.HitPos, trOut.HitNormal
	local p = ABL.Pools.Find(hp.x, hp.y, hp.z, hn.x, hn.y, hn.z, 0.3)
	local run = vl > 200
	if p and p.wet > 0.05 then
		local got = ABL.Pools.Disturb(p, hp.x, hp.y, hp.z, dx, dy, 0, K.pickup, K.push * (run and 2 or 1))
		st.load = min(K.maxLoad, st.load + got)
		return
	end
	st.load = min(K.maxLoad, st.load + StainLoad(hp.x, hp.y, hp.z, hn.x, hn.y, hn.z))
	if st.load < K.minLoad then
		st.load = 0
		return
	end
	local len = K.footLen * (run and 1.5 or 1)
	if Print(hp.x, hp.y, hp.z, hn.x, hn.y, hn.z, dx, dy, 0, len, K.footW, st.load) then
		st.load = st.load * (run and K.keep * 0.85 or K.keep)
	end
end

local function Walkers()
	local maxD2 = K.dist * K.dist
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() and ply:IsOnGround() and ply:GetMoveType() == MOVETYPE_WALK and not ply:GetNoDraw() then
			local pos = ply:GetPos()
			local st = walkers[ply]
			if not st then
				st = { load = 0, acc = 0, side = 1, x = pos.x, y = pos.y }
				walkers[ply] = st
			end
			local mx, my = pos.x - st.x, pos.y - st.y
			local d = sqrt(mx * mx + my * my)
			st.x, st.y = pos.x, pos.y
			if d > 64 then
				st.acc = 0
			elseif (st.load > 0 or NearPool(pos.x, pos.y, pos.z, 24)) and (pos.x - L.eyeX) ^ 2 + (pos.y - L.eyeY) ^ 2 + (pos.z - L.eyeZ) ^ 2 < maxD2 then
				st.acc = st.acc + d
				local stride = K.stride * (ply:Crouching() and 0.6 or 1)
				if st.acc >= stride then
					st.acc = st.acc % stride
					st.side = -st.side
					Step(ply, st, st.side)
				end
			else
				st.acc = 0
			end
		end
	end
end

local function DragBone(rs, bone, x, y, z)
	local b = rs.b[bone]
	if not Down(x, y, z, K.contactH) then
		if b then b.c = false end
		return
	end
	local hp, hn = trOut.HitPos, trOut.HitNormal
	if not b then
		b = { x = hp.x, y = hp.y, z = hp.z, load = 0, c = true }
		rs.b[bone] = b
		return
	end
	local dx, dy, dz = hp.x - b.x, hp.y - b.y, hp.z - b.z
	local d = sqrt(dx * dx + dy * dy + dz * dz)
	if not b.c then
		b.x, b.y, b.z, b.c = hp.x, hp.y, hp.z, true
		return
	end
	if d < K.dragStep then return end
	dx, dy, dz = dx / d, dy / d, dz / d
	local p = ABL.Pools.Find(hp.x, hp.y, hp.z, hn.x, hn.y, hn.z, 0.3)
	if p and p.wet > 0.05 then
		b.load = min(K.maxLoad, b.load + ABL.Pools.Disturb(p, b.x, b.y, b.z, dx, dy, dz, K.dragPickup, K.dragPush))
	else
		b.load = min(K.maxLoad, b.load + StainLoad(hp.x, hp.y, hp.z, hn.x, hn.y, hn.z))
		if b.load >= K.minLoad then
			if Print((b.x + hp.x) * 0.5, (b.y + hp.y) * 0.5, (b.z + hp.z) * 0.5, hn.x, hn.y, hn.z, dx, dy, dz, min(d * 1.3, 14), K.dragW, b.load) then
				b.load = b.load * K.dragKeep
			end
		else
			b.load = 0
		end
	end
	b.x, b.y, b.z = hp.x, hp.y, hp.z
end

local function Ragdolls()
	local maxD2 = K.dist * K.dist
	for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
		if IsValid(rag) and not rag:IsDormant() then
			local pos = rag:GetPos()
			local rs = rags[rag]
			local active = rs and rs.loaded
			if (pos.x - L.eyeX) ^ 2 + (pos.y - L.eyeY) ^ 2 + (pos.z - L.eyeZ) ^ 2 < maxD2 and (active or NearPool(pos.x, pos.y, pos.z, 48)) then
				if not rs then
					rs = { b = {}, ids = {} }
					for i, name in ipairs(DRAG_BONES) do rs.ids[i] = rag:LookupBone(name) or -1 end
					rags[rag] = rs
				end
				local loaded = false
				for i = 1, #DRAG_BONES do
					local id = rs.ids[i]
					if id >= 0 then
						local bp = rag:GetBonePosition(id)
						if bp then DragBone(rs, id, bp.x, bp.y, bp.z) end
						local b = rs.b[id]
						if b and b.load > 0 then loaded = true end
					end
				end
				rs.loaded = loaded
			end
		end
	end
end

local nextWalk, nextRag = 0, 0
function SM.Think()
	local now = CurTime()
	if now >= nextWalk then
		nextWalk = now + K.tick
		local any = WetPools()
		if any or next(walkers) then Walkers() end
		if now >= nextRag then
			nextRag = now + K.ragTick
			if any or next(rags) then Ragdolls() end
		end
	end
end

function SM.Clear()
	for k in pairs(walkers) do walkers[k] = nil end
	for k in pairs(rags) do rags[k] = nil end
end
