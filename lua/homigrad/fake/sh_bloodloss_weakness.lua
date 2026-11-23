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

	hook.Add("RenderScreenspaceEffects", "HG-BloodLossWeak", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return end
		local env = weakEnvelope(ply, CurTime()) * ply:GetNWFloat("HGWeakPower", 0.5)
		if env <= 0 then return end

		colorMod["$pp_colour_brightness"] = -0.22 * env
		colorMod["$pp_colour_contrast"] = 1 - 0.25 * env
		colorMod["$pp_colour_colour"] = 1 - 0.6 * env
		DrawColorModify(colorMod)
		DrawMotionBlur(0.25, 0.6 * env, 0.01)
	end)

	return
end

local K = {
	interval = 1,
	startBlood = 4000,
	fullBlood = 2700,
	chance = 0.04,
	movingMul = 1.4,
	sprintMul = 3,
	cooldownMin = 8,
	cooldownMax = 30,
	durationBase = 2.5,
	durationSeverity = 5,
	powerBase = 0.35,
	powerSeverity = 0.55,
	fallBase = 0.12,
	fallSeverity = 0.6,
	fallSprint = 0.25,
	fallDelayMin = 0.5,
	fallDelayMax = 1.6,
	wobblePower = 0.3,
	thoughtCooldown = 20,
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
	if math.random() < fallChance then
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

timer.Create("HG_BloodLossWeak", K.interval, 0, function()
	local now = CurTime()
	for _, ply in player.Iterator() do
		local org = ply.organism
		if not org or now < (org.bloodWeakNext or 0) or ply:GetNWFloat("HGWeakEnd", 0) > now then continue end

		local sev = severity(org)
		if sev <= 0 or not canEpisode(ply, org) then continue end

		local speed = ply:GetVelocity():Length2D()
		local sprinting = ply:KeyDown(IN_SPEED) and speed > 150
		local mul = sprinting and K.sprintMul or speed > 30 and K.movingMul or 1
		if math.random() >= K.chance * sev * mul then continue end

		org.bloodWeakNext = now + Lerp(sev, K.cooldownMax, K.cooldownMin)
		startEpisode(ply, org, sev, sprinting, now)
	end
end)
