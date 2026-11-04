local tickRate = 0.05
local startBleed = 12
local stopBleed = 6
local kickDecayTime = 26
local legL1, legL2 = 18, 18
local legExtend, legTuck, kneeBend = 10, 100, 165
local pedalRate, bicycleRate = 2.2, 3.6
local pedalGain, pedalMax = 12, 420
local bicycleGain, bicycleMax = 18, 700
local bicycleChance = 0.33
local downChance = 0.35
local torsoMassKick = 6
local outAmpMul = 0.25
local chokeHold = 0.5
local chokeSeverity = 0.7
local chokeDecayFloor = 0.6

local function phys(rag, boneName)
	local bone = rag:LookupBone(boneName)
	if not bone then return end
	local p = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(bone))
	if IsValid(p) then return p end
end

local function pull(p, target, blend, gain, maxSpeed, base)
	local want = (target - p:GetPos()) * gain
	if want:LengthSqr() > maxSpeed * maxSpeed then want = want:GetNormalized() * maxSpeed end
	p:Wake()
	p:SetVelocity(LerpVector(blend, p:GetVelocity(), base + want))
end

local function frame(st, rag)
	local pelvisPos = st.pelvis:GetPos()
	local m = st.spineBone and rag:GetBoneMatrix(st.spineBone)
	local up, fwd
	if m then
		local a = m:GetAngles()
		up = a:Forward()
		fwd = -a:Right()
	else
		up = st.spine:GetPos() - pelvisPos
		fwd = Vector(1, 0, 0)
	end
	if up:LengthSqr() < 0.01 then up = Vector(0, 0, 1) end
	up:Normalize()
	fwd = fwd - up * fwd:Dot(up)
	if fwd:LengthSqr() < 0.01 then fwd = Vector(1, 0, 0) end
	fwd:Normalize()
	if st.flip then fwd = -fwd end
	return pelvisPos, up, fwd
end

local function legPose(hip, up, fwd, t)
	local down = -up
	local a = math.rad(Lerp(t, legExtend, legTuck))
	local g = a - math.rad(Lerp(t, 5, kneeBend))
	local knee = hip + (down * math.cos(a) + fwd * math.sin(a)) * legL1
	local foot = knee + (down * math.cos(g) + fwd * math.sin(g)) * legL2
	return knee, foot
end

local function cycle(f, phase, amp, pelvisPos, up, fwd, bicycle, floorZ, down, base)
	local hip = pelvisPos
	if f.thigh then
		local lat = f.thigh:GetPos() - pelvisPos
		lat = lat - up * lat:Dot(up) - fwd * lat:Dot(fwd)
		hip = pelvisPos + lat
	end

	local ang = phase + f.phase
	local t = math.Clamp((0.5 - 0.5 * math.cos(ang)) * amp, 0, 1)
	local knee, foot = legPose(hip, up, fwd, t)

	if bicycle then
		local size = math.Clamp(amp, 0, 1)
		local fwdMul = down and 0.7 or 1
		local downShift = down and 9 or 0
		foot = hip + up * (-8 + 8 * math.cos(ang) - downShift) * size
			+ fwd * (13 + 9 * math.sin(ang)) * fwdMul * size - up * 30 * (1 - size)
		local delta = foot - hip
		local distance = math.Clamp(delta:Length(), 0.1, legL1 + legL2 - 0.1)
		local axis = delta:GetNormalized()
		foot = hip + axis * distance
		local bend = fwd - axis * fwd:Dot(axis)
		if bend:LengthSqr() < 0.01 then bend = up - axis * up:Dot(axis) end
		bend:Normalize()
		local along = (legL1 ^ 2 - legL2 ^ 2 + distance ^ 2) / (2 * distance)
		knee = hip + axis * along + bend * math.sqrt(math.max(legL1 ^ 2 - along ^ 2, 0))
	end

	if floorZ then
		local press = math.max(0, math.sin(ang)) * math.Clamp(amp, 0, 1)
		if press > 0 and foot.z > floorZ + 2 then
			foot = Vector(foot.x, foot.y, Lerp(press * 0.8, foot.z, floorZ + 2))
		end
		if foot.z < floorZ + 3 then foot.z = floorZ + 3 end
	end

	local thigh = LerpVector(0.5, hip, knee)
	local calf = LerpVector(0.5, knee, foot)
	local gain = bicycle and bicycleGain or pedalGain
	local vmax = bicycle and bicycleMax or pedalMax
	if f.foot then pull(f.foot, foot, 0.5, gain, vmax, base) end
	if f.calf and f.calf ~= f.foot then pull(f.calf, calf, 0.35, gain, vmax, base) end
	if f.thigh then pull(f.thigh, thigh, 0.25, gain, vmax, base) end
end

local function setTorsoMass(st, mult)
	if math.abs((st.massMult or 1) - mult) < 0.05 then return end
	st.massMult = mult
	if IsValid(st.spine) then st.spine:SetMass(st.baseSpine * mult) end
	if IsValid(st.pelvis) then st.pelvis:SetMass(st.basePelvis * mult) end
end

local function setup(ply, rag)
	local rc, lc = phys(rag, "ValveBiped.Bip01_R_Calf"), phys(rag, "ValveBiped.Bip01_L_Calf")
	local st = {
		rag = rag,
		start = CurTime(),
		spine = phys(rag, "ValveBiped.Bip01_Spine2"),
		pelvis = phys(rag, "ValveBiped.Bip01_Pelvis"),
		spineBone = rag:LookupBone("ValveBiped.Bip01_Spine2"),
		feet = {
			{thigh = phys(rag, "ValveBiped.Bip01_R_Thigh"), calf = rc, foot = phys(rag, "ValveBiped.Bip01_R_Foot") or rc, phase = 0},
			{thigh = phys(rag, "ValveBiped.Bip01_L_Thigh"), calf = lc, foot = phys(rag, "ValveBiped.Bip01_L_Foot") or lc, phase = math.pi},
		},
		bicycle = math.random() < bicycleChance,
		phase = 0,
	}
	if not (st.spine and st.pelvis) then return end

	st.down = st.bicycle and math.random() < downChance
	st.baseSpine = st.spine:GetMass()
	st.basePelvis = st.pelvis:GetMass()

	st.flip = false
	local _, up, fwd = frame(st, rag)
	local face = Angle(0, ply:GetAngles().y, 0):Forward()
	local flat = Vector(fwd.x, fwd.y, 0)
	if up.z > 0.6 and flat:LengthSqr() > 0.15 then
		st.flip = flat:GetNormalized():Dot(face) < 0
	end

	return st
end

local function clear(ply)
	local st = ply.hgArteryKick
	if not st then return end
	ply.hgArteryKick = nil
	if IsValid(st.rag) then
		st.rag.hgArteryKick = nil
		setTorsoMass(st, 1)
	end
end

local function busy(ply, rag)
	return rag.hgGetUp or rag.hgCurl or rag.hgStumbleActive or rag.isSliding or rag.isDropkicking
		or hg.KeyDown(ply, IN_FORWARD) or hg.KeyDown(ply, IN_BACK)
		or hg.KeyDown(ply, IN_MOVELEFT) or hg.KeyDown(ply, IN_MOVERIGHT)
end

local function awakeChoking(ply, org)
	if org.choking then ply.hgChokeSeen = CurTime() end
	if org.otrub then return false end
	return org.vomitInThroat or ply._fiberwire_old_o2regen ~= nil or CurTime() - (ply.hgChokeSeen or 0) < chokeHold
end

local function tick(ply)
	local rag = ply.FakeRagdoll
	local org = ply.organism
	local st = ply.hgArteryKick
	if not IsValid(rag) or not ply:Alive() or not org or not org.alive then
		clear(ply)
		return
	end

	local bleed = tonumber(org.arterialBleed) or 0
	local choking = awakeChoking(ply, org)
	if not choking and bleed < (st and stopBleed or startBleed) then
		clear(ply)
		return
	end

	if st and st.rag ~= rag then
		clear(ply)
		st = nil
	end
	if not st then
		st = setup(ply, rag)
		if not st then return end
		ply.hgArteryKick = st
		rag.hgArteryKick = true
	end

	if busy(ply, rag) then
		setTorsoMass(st, 1)
		return
	end

	local now = CurTime()
	local severity = math.Clamp(bleed / 40, choking and chokeSeverity or 0.3, 1)
	local life = math.Clamp(((tonumber(org.blood) or 5000) - 1500) / 2500, 0, 1)
	local decay = math.Clamp(1 - (now - st.start) / kickDecayTime, 0.16, 1)
	if st.bicycle then decay = math.max(decay, 0.45) end
	if choking then decay = math.max(decay, chokeDecayFloor) end

	if not st.nextRand or now >= st.nextRand then
		st.nextRand = now + math.Rand(0.8, 2.0)
		st.rateMul = math.Rand(0.72, 1.32)
		st.ampMul = math.Rand(0.82, 1.22)
		for _, f in ipairs(st.feet) do f.phase = math.Rand(0, math.pi * 2) end
	end

	local amp = (st.bicycle and (0.9 + 0.3 * severity) or (0.4 + 0.6 * severity)) * life * decay * st.ampMul
	if org.otrub then amp = amp * outAmpMul end
	amp = math.Clamp(amp, 0, 1.3)
	if amp < 0.05 then
		setTorsoMass(st, 1)
		return
	end

	setTorsoMass(st, Lerp(math.Clamp(amp * 1.5, 0, 1), 1, torsoMassKick))

	local rate = (st.bicycle and bicycleRate or pedalRate * (0.5 + 0.5 * severity)) * st.rateMul * (0.35 + 0.65 * decay)
	if org.otrub then rate = rate * 0.6 end
	st.phase = st.phase + math.min(tickRate * rate * math.pi * 2, math.pi * 0.5)

	local pelvisPos, up, fwd = frame(st, rag)
	local base = st.pelvis:GetVelocity()

	if st.bicycle and not org.otrub and now >= (st.nextJolt or 0) then
		st.nextJolt = now + math.Rand(0.12, 0.3)
		local k = 25 + 30 * severity
		st.spine:AddVelocity(VectorRand() * k)
		st.pelvis:AddVelocity(VectorRand() * k * 0.6)
	end

	local tr = util.TraceLine({
		start = pelvisPos,
		endpos = pelvisPos - Vector(0, 0, 90),
		filter = {rag, ply},
	})
	local floorZ = tr.Hit and tr.HitPos.z or nil

	for _, f in ipairs(st.feet) do
		cycle(f, st.phase, amp, pelvisPos, up, fwd, st.bicycle, floorZ, st.down, base)
	end
end

timer.Create("HG_ArteryKick", tickRate, 0, function()
	for _, ply in player.Iterator() do
		if ply.hgArteryKick or IsValid(ply.FakeRagdoll) then tick(ply) end
	end
end)

hook.Add("PlayerDeath", "HG_ArteryKick", clear)
hook.Add("PlayerSpawn", "HG_ArteryKick", clear)
hook.Add("PlayerDisconnected", "HG_ArteryKick", clear)
