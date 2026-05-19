EFFECT.Mat = Material("particle/particle_smokegrenade")

function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local normal = data:GetNormal()
	local scale = math.Clamp(data:GetScale(), 0.25, 6)

	if normal == vector_origin then
		normal = Vector(0, 0, 1)
	end

	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	local up = normal
	local right = up:Cross(Vector(0, 0, 1))
	if right:LengthSqr() < 0.001 then
		right = up:Cross(Vector(0, 1, 0))
	end
	right:Normalize()
	local forward = right:Cross(up)
	forward:Normalize()

	local puffCount = math.floor(32 * scale)
	for i = 1, puffCount do
		local spawnPos = pos + VectorRand() * (12 * scale)
		spawnPos = spawnPos + up * math.Rand(0, 2) * scale

		local particle = emitter:Add("particle/particle_smokegrenade", spawnPos)
		if not particle then continue end

		local vel = VectorRand() * (85 * scale)
		vel = vel + up * math.Rand(6, 18) * scale

		particle:SetVelocity(vel)
		particle:SetDieTime(math.Rand(1.6, 2.8))
		particle:SetStartAlpha(255)
		particle:SetEndAlpha(0)
		particle:SetStartSize(math.Rand(12, 18) * scale)
		particle:SetEndSize(math.Rand(85, 140) * scale)
		particle:SetRoll(math.Rand(-180, 180))
		particle:SetRollDelta(math.Rand(-1.0, 1.0))
		particle:SetColor(125, 105, 75)
		particle:SetAirResistance(120)
		particle:SetGravity(-up * (260 + 40 * scale))
		particle:SetLighting(false)
		particle:SetCollide(false)
	end

	local ringCount = math.floor(18 * scale)
	for i = 1, ringCount do
		local ang = math.Rand(0, math.pi * 2)
		local r = math.Rand(6, 18) * scale
		local radial = forward * math.cos(ang) + right * math.sin(ang)
		local spawnPos = pos + radial * r + up * math.Rand(0, 1.5) * scale

		local particle = emitter:Add("particle/particle_smokegrenade", spawnPos)
		if not particle then continue end

		local vel = radial * math.Rand(110, 180) * scale + VectorRand() * (30 * scale)
		vel = vel + up * math.Rand(4, 10) * scale

		particle:SetVelocity(vel)
		particle:SetDieTime(math.Rand(1.2, 2.0))
		particle:SetStartAlpha(240)
		particle:SetEndAlpha(0)
		particle:SetStartSize(math.Rand(10, 16) * scale)
		particle:SetEndSize(math.Rand(70, 115) * scale)
		particle:SetRoll(math.Rand(-180, 180))
		particle:SetRollDelta(math.Rand(-0.8, 0.8))
		particle:SetColor(135, 115, 85)
		particle:SetAirResistance(95)
		particle:SetGravity(-up * (240 + 30 * scale))
		particle:SetLighting(false)
		particle:SetCollide(false)
	end

	emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
