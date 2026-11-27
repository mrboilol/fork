hg = hg or {}

local Clamp = math.Clamp

local function weakEnvelope(ply, now)
	local finish = ply:GetNWFloat("HGWeakEnd", 0)
	if finish <= now then return 0 end
	local start = ply:GetNWFloat("HGWeakStart", 0)
	local t = Clamp((now - start) / math.max(finish - start, 0.01), 0, 1)
	if t < 0.15 then return t / 0.15 end
	if t > 0.7 then return 1 - (t - 0.7) / 0.3 end
	return 1
end
hg.BloodLossWeakEnvelope = weakEnvelope

hook.Add("HG_MovementCalc_2", "HG-BloodLossWeak", function(mul, ply, cmd, mv)
	local env = weakEnvelope(ply, CurTime())
	if env <= 0 then return end

	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_SPEED)
	if mv then
		mv:RemoveKey(IN_JUMP)
		mv:RemoveKey(IN_SPEED)
	end

	mul[1] = mul[1] * (1 - 0.65 * env * ply:GetNWFloat("HGWeakPower", 0.5))
end)

if CLIENT then
	local colorMod = {
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	}

	local EDGES = {
		{mat = Material("vgui/gradient-u"), x = 0, y = 0, w = 1, h = 0.45},
		{mat = Material("vgui/gradient-d"), x = 0, y = 0.55, w = 1, h = 0.45},
		{mat = Material("vgui/gradient-l"), x = 0, y = 0, w = 0.4, h = 1},
		{mat = Material("vgui/gradient-r"), x = 0.6, y = 0, w = 0.4, h = 1},
	}
	local VIGNETTE_ALPHA = 255
	local PULSE_SPEED = 6
	local PULSE_DEPTH = 0.2
	local DIP_PITCH = 7
	local DIP_ROLL = 5

	local lastDipStart = 0

	local function localStrength()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return 0, ply end

		return weakEnvelope(ply, CurTime()) * ply:GetNWFloat("HGWeakPower", 0.5), ply
	end

	hook.Add("RenderScreenspaceEffects", "HG-BloodLossWeak", function()
		local strength, ply = localStrength()
		if strength <= 0 then return end

		local start = ply:GetNWFloat("HGWeakStart", 0)
		if start ~= lastDipStart then
			lastDipStart = start
			if ViewPunch then ViewPunch(Angle(DIP_PITCH, 0, math.Rand(-DIP_ROLL, DIP_ROLL))) end
		end

		colorMod["$pp_colour_brightness"] = -0.28 * strength
		colorMod["$pp_colour_contrast"] = 1 - 0.3 * strength
		colorMod["$pp_colour_colour"] = 1 - 0.85 * strength
		DrawColorModify(colorMod)
		DrawMotionBlur(0.18, 0.85 * strength, 0.01)
	end)

	hook.Add("HUDPaintBackground", "HG-BloodLossWeak", function()
		local strength = localStrength()
		if strength <= 0 then return end

		local pulse = 1 - PULSE_DEPTH + PULSE_DEPTH * math.sin(CurTime() * PULSE_SPEED)
		local w, h = ScrW(), ScrH()
		surface.SetDrawColor(0, 0, 0, VIGNETTE_ALPHA * math.min(strength * 1.3, 1) * pulse)

		for _, edge in ipairs(EDGES) do
			surface.SetMaterial(edge.mat)
			surface.DrawTexturedRect(w * edge.x, h * edge.y, w * edge.w, h * edge.h)
		end
	end)

	return
end

local K = {
	interval = 1,
	startBlood = 4200,
	fullBlood = 2800,
	chanceBase = 0.04,
	chanceSeverity = 0.08,
	movingMul = 1.4,
	sprintMul = 2.5,
	cooldownMin = 12,
	cooldownMax = 20,
	durationBase = 3.5,
	durationSeverity = 5,
	powerBase = 0.55,
	powerSeverity = 0.45,
	fallBase = 0.28,
	fallSeverity = 0.55,
	fallSprint = 0.25,
	fallDelayMin = 0.5,
	fallDelayMax = 1.6,
	wobblePower = 0.45,
	thoughtCooldown = 14,
	fallGapMax = 45,
	fallGapMin = 22,
	recoverGrace = 10,
}
hg.BloodLossWeakConfig = K

local THOUGHTS = {
	{"I feel light-headed...", "My legs feel weak...", "Everything's going grey..."},
	{"I can't... stand up straight...", "My vision's going dark...", "I'm so cold and weak..."},
}

local function severity(org)
	local blood = org.blood or 5000
	return Clamp((K.startBlood - blood) / (K.startBlood - K.fullBlood), 0, 1)
end

local function canEpisode(ply, org)
	if not ply:Alive() or not org.alive or org.otrub or org.godmode then return false end
	if IsValid(ply.FakeRagdoll) or ply:InVehicle() or ply:GetMoveType() ~= MOVETYPE_WALK or not ply:OnGround() then return false end
	return true
end

local function startEpisode(ply, org, sev, sprinting, now)
	local power = K.powerBase + K.powerSeverity * sev
	ply:SetNWFloat("HGWeakStart", now)
	ply:SetNWFloat("HGWeakEnd", now + K.durationBase + K.durationSeverity * sev)
	ply:SetNWFloat("HGWeakPower", power)

	local brace = hg.organism.AdrenalineBrace and hg.organism.AdrenalineBrace(org) or 0
	local fallChance = (K.fallBase + K.fallSeverity * sev + (sprinting and K.fallSprint or 0)) * (1 - brace)
	if now >= (org.bloodWeakNextFall or 0) and math.random() < fallChance then
		org.bloodWeakNextFall = now + Lerp(sev, K.fallGapMax, K.fallGapMin)
		local delay = Lerp(math.random(), K.fallDelayMin, K.fallDelayMax)
		if not (hg.StartStagger and hg.StartStagger(ply, nil, power, delay)) then
			timer.Simple(delay, function()
				if IsValid(ply) and ply:Alive() and not IsValid(ply.FakeRagdoll) then hg.Fake(ply) end
			end)
		end
	elseif hg.StartStagger then
		hg.StartStagger(ply, nil, K.wobblePower * power)
	end

	if now >= (org.bloodWeakNextThought or 0) and hg.organism.EmotionThought then
		org.bloodWeakNextThought = now + K.thoughtCooldown
		local pool = THOUGHTS[sev > 0.55 and 2 or 1]
		hg.organism.EmotionThought(ply, pool[math.random(#pool)], 4, "bloodloss_weak")
	end
end

hook.Add("PlayerDeath", "HG-BloodLossWeak", function(ply)
	ply:SetNWFloat("HGWeakEnd", 0)
end)

hook.Add("Org Clear", "HG-BloodLossWeak", function(org)
	org.bloodWeakNext = nil
	org.bloodWeakNextFall = nil
	org.bloodWeakNextThought = nil
end)

timer.Create("HG_BloodLossWeak", K.interval, 0, function()
	local now = CurTime()
	for _, ply in player.Iterator() do
		local org = ply.organism
		if not org then continue end

		if IsValid(ply.FakeRagdoll) then
			org.bloodWeakNext = math.max(org.bloodWeakNext or 0, now + K.recoverGrace)
			continue
		end

		if now < (org.bloodWeakNext or 0) or ply:GetNWFloat("HGWeakEnd", 0) > now then continue end

		local sev = severity(org)
		if sev <= 0 or not canEpisode(ply, org) then continue end

		local speed = ply:GetVelocity():Length2D()
		local sprinting = ply:KeyDown(IN_SPEED) and speed > 150
		local mul = sprinting and K.sprintMul or speed > 30 and K.movingMul or 1
		if math.random() >= (K.chanceBase + K.chanceSeverity * sev) * mul then continue end

		org.bloodWeakNext = now + Lerp(sev, K.cooldownMax, K.cooldownMin)
		startEpisode(ply, org, sev, sprinting, now)
	end
end)
