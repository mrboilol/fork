local gravity = Vector(0, 0, -500)

function EFFECT:Init(data)
	local pos, dir = data:GetOrigin(), data:GetNormal()
	local count = math.Clamp(math.floor(data:GetMagnitude()), 1, 16)
	local spread = data:GetScale()
	local metal = bit.band(data:GetFlags(), 1) ~= 0

	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	for i = 1, count * 3 do
		local p = emitter:Add("effects/spark", pos)
		if p then
			p:SetVelocity((dir + VectorRand() * spread):GetNormalized() * math.Rand(500, 1300))
			p:SetDieTime(math.Rand(0.12, 0.35))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(0.5, 1.1))
			p:SetEndSize(0)
			p:SetStartLength(math.Rand(4, 12))
			p:SetEndLength(0)
			p:SetGravity(gravity)
			p:SetCollide(true)
			p:SetBounce(0.3)
			p:SetColor(255, metal and 225 or 200, metal and 170 or 140)
		end
	end

	if not metal then
		for i = 1, count * 2 do
			local p = emitter:Add("effects/fleck_cement" .. math.random(2), pos)
			if p then
				p:SetVelocity((dir + VectorRand() * spread):GetNormalized() * math.Rand(150, 450))
				p:SetDieTime(math.Rand(0.8, 1.6))
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(math.Rand(0.6, 1.4))
				p:SetEndSize(0.4)
				p:SetRoll(math.Rand(0, 360))
				p:SetRollDelta(math.Rand(-8, 8))
				p:SetGravity(gravity * 1.6)
				p:SetCollide(true)
				p:SetBounce(0.2)
				local shade = math.random(90, 140)
				p:SetColor(shade, shade, shade)
			end
		end
	end

	emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
