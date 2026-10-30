AddCSLuaFile()

local hg_crosshair = ConVarExists("hg_crosshair") and GetConVar("hg_crosshair") or CreateConVar("hg_crosshair", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Crosshair: 0 disabled, 1 enabled, 2 enabled with opponent status", 0, 2)

if SERVER then
	util.AddNetworkString("hg_crosshair_status")

	local organNames = {
		heart = "organ",
		liver = "organ",
		kidneys = "organ",
		stomach = "organ",
		intestines = "organ",
		brain = "organ",
		spine1 = "organ",
		spine2 = "organ",
		spine3 = "organ",
		trachea = "organ",
		aorta = "organ",
		lungsL = "organ",
		lungsR = "organ",
		eyeL = "organ",
		eyeR = "organ",
		lleg = "bone",
		rleg = "bone",
		larm = "bone",
		rarm = "bone",
		chest = "bone",
		pelvis = "bone",
		skull = "bone",
		jaw = "bone",
	}

	local function organValue(org, key)
		local value = org[key]
		if istable(value) then value = value[1] end
		return tonumber(value) or 0
	end

	hook.Add("PreHomigradDamage", "hg_crosshair_status", function(victim)
		if hg_crosshair:GetInt() ~= 2 or not IsValid(victim) then return end
		local org = victim.organism
		if not istable(org) then return end

		local snap = {}
		for key in pairs(organNames) do
			snap[key] = organValue(org, key)
		end
		victim.hgXhairOrganSnap = snap
	end)

	hook.Add("HomigradDamage", "hg_crosshair_status", function(victim, dmgInfo)
		if hg_crosshair:GetInt() ~= 2 or not IsValid(victim) then return end
		local snap = victim.hgXhairOrganSnap
		victim.hgXhairOrganSnap = nil

		local attacker = dmgInfo:GetAttacker()
		if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
		local org = victim.organism
		if not istable(org) then return end

		if attacker.hgXhairTarget ~= victim then attacker.hgXhairHits = {} end
		attacker.hgXhairHits = attacker.hgXhairHits or {}
		attacker.hgXhairTarget = victim
		attacker.hgXhairUntil = CurTime() + 6

		if snap then
			for key, kind in pairs(organNames) do
				local before, after = snap[key] or 0, organValue(org, key)
				if kind == "bone" then
					if before < 1 and after >= 1 then attacker.hgXhairHits["broke bone"] = CurTime() + 3 end
				elseif after > before + 0.01 then
					attacker.hgXhairHits[after >= 1 and "destroyed organ" or "damaged organ"] = CurTime() + 3
				end
			end
		end
	end)

	local function buildStatus(ply)
		local target = ply.hgXhairTarget
		if not IsValid(target) or (ply.hgXhairUntil or 0) < CurTime() then return end
		local org = target.organism
		if not istable(org) then return end

		if org.alive == false or (target:IsPlayer() and not target:Alive()) then return {"dead"} end

		local lines = {}
		local hitNames = {}
		for name, untilTime in pairs(ply.hgXhairHits or {}) do
			if untilTime > CurTime() then hitNames[#hitNames + 1] = name end
		end
		if table.HasValue(hitNames, "destroyed organ") then table.RemoveByValue(hitNames, "damaged organ") end
		table.sort(hitNames)
		for _, name in ipairs(hitNames) do
			lines[#lines + 1] = name
		end

		local pain = tonumber(org.pain) or 0
		local blood = tonumber(org.blood) or 5000
		local bleed = tonumber(org.bleed) or 0

		if org.otrub then lines[#lines + 1] = "unconscious" end
		if org.heartstop then lines[#lines + 1] = "heart stopped" end
		if bleed > 1 then
			lines[#lines + 1] = "bleeding heavily"
		elseif hg.IsActivelyBleeding and hg.IsActivelyBleeding(org) then
			lines[#lines + 1] = "bleeding"
		end
		if blood < 2500 then
			lines[#lines + 1] = "very pale"
		elseif blood < 3500 then
			lines[#lines + 1] = "pale"
		end
		if pain > 70 then
			lines[#lines + 1] = "in agony"
		elseif pain > 30 then
			lines[#lines + 1] = "in pain"
		end
		if not org.otrub then
			if (tonumber(org.disorientation) or 0) > 1 then lines[#lines + 1] = "dizzy" end
			if (tonumber(org.consciousness) or 1) < 0.6 then lines[#lines + 1] = "drowsy" end
		end
		if (tonumber(org.shock) or 0) > 40 then lines[#lines + 1] = "in shock" end

		while #lines > 5 do table.remove(lines) end
		return lines
	end

	timer.Create("hg_crosshair_status", 0.25, 0, function()
		local enabled = hg_crosshair:GetInt() == 2
		for _, ply in player.Iterator() do
			local lines = enabled and buildStatus(ply) or nil
			if not lines then ply.hgXhairTarget = nil end
			local key = lines and table.concat(lines, "|") or ""
			if key == (ply.hgXhairLastKey or "") then continue end
			ply.hgXhairLastKey = key

			net.Start("hg_crosshair_status")
			net.WriteUInt(lines and #lines or 0, 4)
			for _, line in ipairs(lines or {}) do
				net.WriteString(line)
			end
			net.Send(ply)
		end
	end)

	return
end

surface.CreateFont("HGCrosshairStatus", {
	font = "Roboto",
	size = 15,
	weight = 500,
	antialias = true,
})

local statusLines = {}
local statusAlpha = 0

net.Receive("hg_crosshair_status", function()
	local lines = {}
	for i = 1, net.ReadUInt(4) do
		lines[i] = net.ReadString()
	end
	if #lines > 0 then statusLines = lines end
	statusLines.empty = #lines == 0
end)

local state = {
	alpha = 0,
	x = ScrW() * 0.5,
	y = ScrH() * 0.5,
	radius = 40,
	color = Color(255, 255, 255),
	kind = nil,
	points = {},
}

local white = Color(255, 255, 255)
local red = Color(255, 40, 40)

local function smooth(speed)
	return 1 - math.exp(-speed * FrameTime())
end

local swayWindow = 0.35

local function gunConeAngle(wep, owner, tr)
	local cone = 0
	local ammo = wep.GetBulletSettings and wep:GetBulletSettings() or {}
	if (ammo.NumBullet or 1) > 1 and wep.GetPelletSpread then
		local spread = wep:GetPelletSpread(owner, ammo)
		cone = isvector(spread) and math.max(spread.x, spread.y) or tonumber(spread) or 0
	end

	local trait = owner.GetTraitMultiplier and owner:GetTraitMultiplier("gun_accuracy", 1) or 1
	if trait > 1 then cone = cone + 0.018 * (trait - 1) end

	local now = RealTime()
	local samples = wep.hgXhairSway or {}
	wep.hgXhairSway = samples
	samples[#samples + 1] = {now, tr.Normal - owner:GetAimVector()}
	while samples[1] and samples[1][1] < now - swayWindow do table.remove(samples, 1) end

	local mean = Vector()
	for _, s in ipairs(samples) do mean:Add(s[2]) end
	mean:Div(#samples)

	local sway = 0
	for _, s in ipairs(samples) do
		sway = math.max(sway, (s[2] - mean):Length())
	end

	return cone + sway
end

local function meleeArcPoint(wep, eyetr, attacktype, t, reach)
	local normal = eyetr.Normal:Angle()
	normal:RotateAroundAxis(normal:Forward(), wep:GetAttackConfigValue(wep.SwingAng, wep.SwingAng2, wep.ChargeSwingAng, attacktype) or -90)
	normal:RotateAroundAxis(normal:Up(), (0.5 - t) * (wep:GetAttackConfigValue(wep.AttackRads, wep.AttackRads2, wep.ChargeAttackRads, attacktype) or 65))
	return eyetr.StartPos + normal:Forward() * reach
end

local function updateGun(wep, owner)
	if wep:IsZoom() or (wep.IsSprinting and wep:IsSprinting()) then return false end

	local tr = wep:GetTrace(true)
	if not tr or not tr.HitPos then return false end
	local scr = tr.HitPos:ToScreen()
	if not scr.visible then return false end

	local angle = gunConeAngle(wep, owner, tr)
	local dist = tr.StartPos:Distance(tr.HitPos)
	local edge = (tr.HitPos + tr.Normal:Angle():Right() * dist * math.tan(math.min(angle, 1.2))):ToScreen()
	local target = math.Clamp(math.Distance(scr.x, scr.y, edge.x, edge.y), 3, 250)

	if state.kind ~= "gun" then
		state.kind = "gun"
		state.x, state.y = scr.x, scr.y
		state.radius = target
	end

	local s = smooth(18)
	state.x = Lerp(s, state.x, scr.x)
	state.y = Lerp(s, state.y, scr.y)
	state.radius = Lerp(smooth(target > state.radius and 10 or 3), state.radius, target)
	state.color = white
	return true
end

local function updateMelee(wep, owner)
	if wep.IsSprinting and wep:IsSprinting() then return false end

	local charging = wep.Charging or (wep:GetInAttack() and wep:GetAttackType() == 3)
	local attacktype = charging and 3 or (wep:GetInAttack() and wep:GetAttackType()) or (wep:GetNetVar("mode") == true and 2) or 1
	local ent = hg.GetCurrentCharacter(owner)
	if not IsValid(ent) then return false end

	local eyetr, reach = wep:GetMeleeSweepData(owner, ent, attacktype, 0.5)
	if not eyetr then return false end
	if reach < 16 then reach = (wep.AttackLen1 or 55) * 0.7 end

	local points = {}
	local filter = {owner, ent, wep, owner.OldRagdoll}
	local markPos, onTarget
	for i = 0, 8 do
		local worldPos = meleeArcPoint(wep, eyetr, attacktype, i / 8, reach)
		local scr = worldPos:ToScreen()
		if not scr.visible then return false end
		points[#points + 1] = scr

		if not onTarget then
			local tr = util.TraceLine({start = eyetr.StartPos, endpos = worldPos, filter = filter})
			local hitEnt = tr.Entity
			if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC() or hitEnt:IsRagdoll()) then
				markPos, onTarget = tr.HitPos, true
			end
		end
	end
	markPos = markPos or meleeArcPoint(wep, eyetr, attacktype, 0.5, reach)
	local markScr = markPos:ToScreen()

	local s = smooth(18)
	if state.markX and state.kind == "melee" then
		state.markX = Lerp(s, state.markX, markScr.x)
		state.markY = Lerp(s, state.markY, markScr.y)
	else
		state.markX, state.markY = markScr.x, markScr.y
	end
	state.markAlpha = Lerp(smooth(10), state.markAlpha or 0, onTarget and 1 or 0.45)
	state.stab = wep.IsStabAttack and wep:IsStabAttack(attacktype) or false
	if state.kind ~= "melee" or #state.points ~= #points then
		state.kind = "melee"
		state.points = points
	else
		for i, p in ipairs(points) do
			local old = state.points[i]
			old.x = Lerp(s, old.x, p.x)
			old.y = Lerp(s, old.y, p.y)
		end
	end

	local top = math.huge
	local sumX = 0
	for _, p in ipairs(state.points) do
		top = math.min(top, p.y)
		sumX = sumX + p.x
	end
	state.x = sumX / #state.points
	state.y = top
	state.radius = 0

	local frac = charging and wep:GetChargeFraction() or 0
	state.color = Color(Lerp(frac, white.r, red.r), Lerp(frac, white.g, red.g), Lerp(frac, white.b, red.b))
	return true
end

local meleeThrowSpeed = {
	weapon_brick = 700,
	weapon_hg_bottle = 1300,
	weapon_hg_mug = 1100,
	weapon_hg_glassshard = 1200,
	weapon_hg_glassshard_taped = 1200,
	weapon_tpik_microphone = 700,
	weapon_wrench = 700,
}

local function getThrowSpeed(wep, owner)
	local class = wep:GetClass()
	if wep.GetMeleeSweepData then
		if not wep.CustomAttack2 or not wep:GetBlocking() then return end
		return meleeThrowSpeed[class] or 1500, false
	end

	if wep.ThrowVelocity then
		local low = owner:KeyDown(IN_ATTACK2) and not owner:KeyDown(IN_ATTACK)
		return low and (wep.LowThrowVelocity or wep.ThrowVelocity) or wep.ThrowVelocity, false
	end

	if not wep.ENT or not wep.Throw then return end
	local arm = hg.GetThrowArmMultiplier and hg.GetThrowArmMultiplier(owner) or 1
	if weapons.IsBasedOn(class, "weapon_hg_legacy_grenade") or class == "weapon_hg_legacy_grenade" then
		return 800 * arm, true
	end

	local low = wep.IsLowThrow or (owner:KeyDown(IN_ATTACK2) and not owner:KeyDown(IN_ATTACK))
	return (low and (wep.ThrowLowMul or 600) or (wep.ThrowHighMul or 1200)) / 1.5 * arm, true
end

local function updateThrow(wep, owner, speed, addVelocity)
	local ent = hg.GetCurrentCharacter(owner)
	if not IsValid(ent) then return false end

	local pos = owner:EyePos()
	local vel = owner:GetAimVector() * speed + (addVelocity and ent:GetVelocity() or vector_origin)
	local gravity = physenv.GetGravity()
	local filter = {owner, ent, wep, owner.OldRagdoll}
	local points = {}
	local landing

	for _ = 1, 60 do
		local nextVel = vel + gravity * 0.05
		local nextPos = pos + (vel + nextVel) * 0.025
		local tr = util.TraceLine({start = pos, endpos = nextPos, filter = filter, mask = MASK_SHOT})
		points[#points + 1] = pos:ToScreen()
		if tr.Hit then
			landing = tr.HitPos
			break
		end
		pos, vel = nextPos, nextVel
	end

	landing = landing or pos
	local scr = landing:ToScreen()
	points[#points + 1] = scr

	state.kind = "throw"
	state.points = points
	state.x = scr.x
	state.y = scr.y
	state.radius = 5
	state.color = white
	return true
end

local function drawCircle(x, y, radius, segments)
	local step = math.pi * 2 / segments
	local lastX, lastY = x + radius, y
	for i = 1, segments do
		local a = i * step
		local nx, ny = x + math.cos(a) * radius, y + math.sin(a) * radius
		surface.DrawLine(lastX, lastY, nx, ny)
		lastX, lastY = nx, ny
	end
end

hook.Add("HUDPaint", "hg_crosshair", function()
	local mode = hg_crosshair:GetInt()
	if mode == 0 then return end

	local owner = LocalPlayer()
	local wep = IsValid(owner) and owner:Alive() and owner:GetActiveWeapon()
	local visible = false

	local throwSpeed, throwAddVel
	if IsValid(wep) then throwSpeed, throwAddVel = getThrowSpeed(wep, owner) end

	if throwSpeed then
		visible = updateThrow(wep, owner, throwSpeed, throwAddVel)
	elseif IsValid(wep) then
		if wep.GetMeleeSweepData then
			visible = updateMelee(wep, owner)
		elseif wep.ishgwep and wep.GetTrace and not wep.ismelee then
			visible = updateGun(wep, owner)
		end
	end

	state.alpha = Lerp(smooth(visible and 8 or 10), state.alpha, visible and 1 or 0)
	if state.alpha < 0.01 then
		state.kind = nil
		statusAlpha = 0
		return
	end

	local col = state.color
	surface.SetDrawColor(col.r, col.g, col.b, 200 * state.alpha)

	if state.kind == "throw" then
		for i = 2, #state.points, 2 do
			local a, b = state.points[i - 1], state.points[i]
			if a.visible and b.visible then surface.DrawLine(a.x, a.y, b.x, b.y) end
		end
		drawCircle(state.x, state.y, state.radius, 16)
	elseif state.kind == "gun" then
		drawCircle(state.x, state.y, state.radius, math.Clamp(math.floor(state.radius * 0.8), 24, 64))
	elseif state.kind == "melee" then
		local first, last = state.points[1], state.points[#state.points]
		if state.stab and math.Distance(first.x, first.y, last.x, last.y) < 12 then
			surface.DrawLine(state.markX - 6, state.markY, state.markX + 6, state.markY)
			surface.DrawLine(state.markX, state.markY - 6, state.markX, state.markY + 6)
		else
			for i = 2, #state.points do
				local a, b = state.points[i - 1], state.points[i]
				surface.DrawLine(a.x, a.y, b.x, b.y)
			end
		end
		surface.SetDrawColor(col.r, col.g, col.b, 255 * state.alpha * (state.markAlpha or 0))
		surface.DrawRect(state.markX - 1, state.markY - 1, 3, 3)
	end

	if mode ~= 2 then return end

	statusAlpha = Lerp(smooth(6), statusAlpha, statusLines.empty == false and 1 or 0)
	if statusAlpha < 0.01 or #statusLines == 0 then return end

	local alpha = 220 * statusAlpha * state.alpha
	local y = state.y - state.radius - 10
	surface.SetFont("HGCrosshairStatus")
	for i = #statusLines, 1, -1 do
		local _, h = surface.GetTextSize(statusLines[i])
		y = y - h
		draw.SimpleText(statusLines[i], "HGCrosshairStatus", state.x + 1, y + 1, Color(0, 0, 0, alpha * 0.8), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(statusLines[i], "HGCrosshairStatus", state.x, y, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end)
