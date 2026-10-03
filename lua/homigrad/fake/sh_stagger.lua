hg = hg or {}

local ATTACK_FRAC = 0.18
local INPUT_SLOWDOWN = 0.4

function hg.StaggerEnvelope(now, start, finish)
	if finish <= start then return 0 end
	local t = math.Clamp((now - start) / (finish - start), 0, 1)
	if t < ATTACK_FRAC then return t / ATTACK_FRAC end
	local k = (t - ATTACK_FRAC) / (1 - ATTACK_FRAC)
	return 1 - k * k * (3 - 2 * k)
end

hook.Add("HG_MovementCalc_2", "HG-Stagger", function(mul, ply, cmd, mv)
	local finish = ply:GetNWFloat("HGStaggerEnd", 0)
	local now = CurTime()
	if finish <= now then return end

	local env = hg.StaggerEnvelope(now, ply:GetNWFloat("HGStaggerStart", 0), finish)
	cmd:RemoveKey(IN_JUMP)
	if mv then mv:RemoveKey(IN_JUMP) end

	mul[1] = mul[1] * (1 - INPUT_SLOWDOWN * env * ply:GetNWFloat("HGStaggerPower", 0.5))
end)

if CLIENT then return end

local hg_stagger = CreateConVar("hg_stagger", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "standing players stagger procedurally (IK pose + slowdown) when hit lightly, almost tripping or fighting their own momentum", 0, 1)

local ESCALATE_POWER = 1.35
local REFRESH_GAP = 0.15
local DURATION_BASE = 0.45
local DURATION_PER_POWER = 0.75
local INERTIA_INTERVAL = 0.05
local INERTIA_MIN_SPEED = 170
local INERTIA_FULL_SPEED = 300
local INERTIA_LOSS_FRAC = 0.35
local INERTIA_OPPOSE_DOT = -0.25
local INERTIA_BASE_CHANCE = 0.45
local INERTIA_COOLDOWN = 1.5

local function flatDirection(dir, ply)
	local flat = Vector(dir and dir.x or 0, dir and dir.y or 0, 0)
	if flat:LengthSqr() < 0.01 then
		flat = ply:EyeAngles():Forward()
		flat.z = 0
	end
	flat:Normalize()
	return flat
end

function hg.StartStagger(ply, dir, power)
	if not hg_stagger:GetBool() or not IsValid(ply) or not ply:Alive() then return false end
	if IsValid(ply.FakeRagdoll) or ply:InVehicle() or ply:GetMoveType() ~= MOVETYPE_WALK or not ply:OnGround() then return false end

	local now = CurTime()
	local finish = ply:GetNWFloat("HGStaggerEnd", 0)
	power = math.Clamp(power or 0.5, 0.1, 1)

	if finish > now then
		if now - ply:GetNWFloat("HGStaggerStart", 0) < REFRESH_GAP then return false end

		local start = ply:GetNWFloat("HGStaggerStart", 0)
		local remaining = ply:GetNWFloat("HGStaggerPower", 0) * hg.StaggerEnvelope(now, start, finish)
		if remaining + power >= ESCALATE_POWER then
			ply:SetNWFloat("HGStaggerEnd", 0)
			timer.Simple(0, function()
				if IsValid(ply) and ply:Alive() and not IsValid(ply.FakeRagdoll) then hg.Fake(ply, nil, nil, nil, "stagger") end
			end)
			return true
		end

		power = math.min(remaining + power, 1)
	end

	dir = flatDirection(dir, ply)
	ply:SetNWVector("HGStaggerDir", dir)
	ply:SetNWFloat("HGStaggerPower", power)
	ply:SetNWFloat("HGStaggerStart", now)
	ply:SetNWFloat("HGStaggerEnd", now + DURATION_BASE + DURATION_PER_POWER * power)
	ply:SetNWBool("HGStaggerLeft", math.random(2) == 1)

	return true
end

hook.Add("PlayerDeath", "HG-Stagger", function(ply)
	ply:SetNWFloat("HGStaggerEnd", 0)
end)

hook.Add("Think", "HG-StaggerInertia", function()
	local now = CurTime()

	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() or IsValid(ply.FakeRagdoll) or ply:GetMoveType() ~= MOVETYPE_WALK or not ply:OnGround() then
			ply.hgInertiaVel = nil
			continue
		end
		if (ply.hgInertiaNext or 0) > now then continue end
		ply.hgInertiaNext = now + INERTIA_INTERVAL

		local vel = ply:GetVelocity()
		vel.z = 0
		local prev = ply.hgInertiaVel
		ply.hgInertiaVel = vel
		if not prev or (ply.hgInertiaCooldown or 0) > now then continue end

		local prevSpeed = prev:Length()
		if prevSpeed < INERTIA_MIN_SPEED then continue end

		local prevDir = prev / prevSpeed
		if prevSpeed - vel:Dot(prevDir) < prevSpeed * INERTIA_LOSS_FRAC then continue end

		local yaw = Angle(0, ply:EyeAngles().y, 0)
		local wish = yaw:Forward() * ((ply:KeyDown(IN_FORWARD) and 1 or 0) - (ply:KeyDown(IN_BACK) and 1 or 0))
			+ yaw:Right() * ((ply:KeyDown(IN_MOVERIGHT) and 1 or 0) - (ply:KeyDown(IN_MOVELEFT) and 1 or 0))
		if wish:LengthSqr() < 0.01 then continue end
		wish:Normalize()
		if wish:Dot(prevDir) > INERTIA_OPPOSE_DOT then continue end

		ply.hgInertiaCooldown = now + INERTIA_COOLDOWN

		local speedFactor = math.Clamp((prevSpeed - INERTIA_MIN_SPEED) / (INERTIA_FULL_SPEED - INERTIA_MIN_SPEED), 0, 1)
		local chance = hg.ScaleTripChance and hg.ScaleTripChance(ply, ply.organism or {}, INERTIA_BASE_CHANCE * (0.4 + 0.6 * speedFactor)) or INERTIA_BASE_CHANCE
		if math.random() < chance then
			hg.StartStagger(ply, prevDir, 0.35 + speedFactor * 0.5)
		end
	end
end)
