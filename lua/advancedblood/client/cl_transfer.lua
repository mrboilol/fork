-- Transfer / smear marks. A bloody body part (per-bone wetness from body-surface flow) that
-- touches a surface leaves blood behind, but only when the contact is meaningful:
--   * sliding contact (dragging, rolling) -> elongated smear along the motion, depleting the part,
--   * sustained resting contact           -> one soaked blot,
--   * a hard collision (server abl_rcol)   -> an impact print + blood shaken off the part and
--                                            squeezed out of nearby wounds.

ABL.NoJIT()
ABL.Transfer = ABL.Transfer or {}
local T = ABL.Transfer
local C, L, BM = ABL.Config, ABL.LOD, ABL.BodyMesh
local sqrt, min, max = math.sqrt, math.min, math.max

local trOut = {}
local tr = { mask = MASK_SOLID_BRUSHONLY, output = trOut }
local vA, vB = Vector(), Vector()

local function BoneBox(src, bone)
	local hbs = BM.Hitboxes(src.body)
	if not hbs then return nil end
	for i = 1, #hbs do
		if hbs[i].bone == bone then return hbs[i] end
	end
	return nil
end

local nextThink = 0
function T.Think()
	local now = CurTime()
	if now < nextThink then return end
	nextThink = now + 0.1
	local gx, gy, gz, gmag = ABL.Gravity()
	local dgx, dgy, dgz = gx / gmag, gy / gmag, gz / gmag
	for _, src in ipairs(ABL.Sources.list) do
		local body = src.body
		if IsValid(body) and body:IsRagdoll() and src.lod >= C.LOD_MEDIUM and next(src.wet) then
			src.contact = src.contact or {}
			for bone, wet in pairs(src.wet) do
				local st = src.contact[bone]
				if wet > 0.03 then
					local tb = SysTime()
					local box = BoneBox(src, bone)
					local e = box and src.pose:Bone(bone)
					ABL.Prof.Add("sub.transfer.box", SysTime() - tb)
					if e and L.TakeTrace() then
						local cx, cy, cz = (box.x0 + box.x1) * 0.5, (box.y0 + box.y1) * 0.5, (box.z0 + box.z1) * 0.5
						local wx = e[1] * cx + e[2] * cy + e[3] * cz + e[4]
						local wy = e[5] * cx + e[6] * cy + e[7] * cz + e[8]
						local wz = e[9] * cx + e[10] * cy + e[11] * cz + e[12]
						local half = min(box.y1 - box.y0, box.z1 - box.z0) * 0.5
						local reach = max(box.x1 - box.x0, box.y1 - box.y0, box.z1 - box.z0) * 0.5 + 2
						vA:SetUnpacked(wx, wy, wz)
						vB:SetUnpacked(wx + dgx * reach, wy + dgy * reach, wz + dgz * reach)
						tr.start, tr.endpos = vA, vB
						util.TraceLine(tr)
						local contact = trOut.Hit and not trOut.StartSolid and trOut.Fraction * reach <= half + 1.8
						if contact then
							local hp, hn = trOut.HitPos, trOut.HitNormal
							if not st then
								st = { x = hp.x, y = hp.y, z = hp.z, t = now, blotted = false }
								src.contact[bone] = st
							else
								local dx, dy, dz = hp.x - st.x, hp.y - st.y, hp.z - st.z
								local d = sqrt(dx * dx + dy * dy + dz * dz)
								if d >= 3.5 then
									-- sliding: smear from the last stamp to here
									local mx, my, mz = (st.x + hp.x) * 0.5, (st.y + hp.y) * 0.5, (st.z + hp.z) * 0.5
									local width = math.Clamp(half * 1.6, 1.5, 7)
									local alpha = math.Clamp(wet * 700, 60, 215)
									local ts = SysTime()
									ABL.Stains.Place("smear", ABL.Mat.Random("smear"), mx, my, mz, hn.x, hn.y, hn.z, dx / d, dy / d, dz / d, min(d * 1.3, 14), width, C.Colors.decal, alpha, nil, 40)
									ABL.Prof.Add("sub.transfer.smear", SysTime() - ts)
									src.wet[bone] = wet * 0.8
									ABL.Surface.WetAdd(mx, my, mz, wet * 0.2, 90)
									st.x, st.y, st.z, st.t = hp.x, hp.y, hp.z, now
									st.blotted = false
								elseif not st.blotted and now - st.t > 1.5 then
									-- resting contact soaks a print into the surface
									local size = math.Clamp(half * 2.2, 2, 9)
									local ts = SysTime()
									ABL.Stains.Place("soak", ABL.Mat.Random("soak"), hp.x, hp.y, hp.z, hn.x, hn.y, hn.z, nil, nil, nil, size, size, C.Colors.decal, math.Clamp(wet * 600, 60, 200), nil, 60)
									local tp = SysTime()
									ABL.FlowCore.Release("pool", wet * 0.3)
									ABL.Pools.Deposit(hp.x, hp.y, hp.z, hn, wet * 0.3, ABL.Surface.FromTrace(trOut), nil, "blot")
									ABL.Prof.Add("sub.transfer.blot", tp - ts)
									ABL.Prof.Add("sub.transfer.pool", SysTime() - tp)
									src.wet[bone] = wet * 0.85
									st.blotted = true
								end
							end
						else
							src.contact[bone] = nil
						end
					end
				elseif st then
					src.contact[bone] = nil
				end
			end
		end
	end
end

-- Server event: a bloody ragdoll hit something hard.
function T.OnCollide(ev)
	local rag = ev.rag
	if not IsValid(rag) then return end
	local owner = ABL.ZC.GetOwner(rag)
	local src = ABL.Sources.Get((IsValid(owner) and owner:Alive()) and owner or rag)
	if not src then return end
	local speed = ev.speed
	-- surface normal at the contact
	vA:SetUnpacked(ev.pos.x - ev.normal.x * 6, ev.pos.y - ev.normal.y * 6, ev.pos.z - ev.normal.z * 6)
	vB:SetUnpacked(ev.pos.x + ev.normal.x * 6, ev.pos.y + ev.normal.y * 6, ev.pos.z + ev.normal.z * 6)
	tr.start, tr.endpos = vA, vB
	util.TraceLine(tr)
	local nx, ny, nz = -ev.normal.x, -ev.normal.y, -ev.normal.z
	local hx, hy, hz = ev.pos.x, ev.pos.y, ev.pos.z
	if trOut.Hit and not trOut.StartSolid then
		nx, ny, nz = trOut.HitNormal.x, trOut.HitNormal.y, trOut.HitNormal.z
		hx, hy, hz = trOut.HitPos.x, trOut.HitPos.y, trOut.HitPos.z
	end
	ABL.Flow.Shake(src, ev.bone, speed, nx, ny, nz)
	ABL.Emission.Jolt(src, ev.bone, speed, nx, ny, nz)
	local wet = src.wet[ev.bone] or 0
	if wet > 0.02 and trOut.Hit then
		local size = math.Clamp(3 + speed / 150, 3, 10)
		ABL.Stains.Place("splat", ABL.Mat.Random("splat"), hx, hy, hz, nx, ny, nz, nil, nil, nil, size, size, C.Colors.decal, math.Clamp(wet * 800, 80, 230), nil, 50)
		src.wet[ev.bone] = wet * 0.7
	end
end
