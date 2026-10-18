function EFFECT:Init(data)		
	local Startpos = data:GetOrigin()
			
		self.Emitter = ParticleEmitter(Startpos)
	
		for i = 1, 2 do
			local p = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), Startpos)
			
			p:SetDieTime(1)
			p:SetStartAlpha(155)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(6, 10))
			p:SetEndSize(30)
			p:SetRoll(math.random(-1, 1))
			p:SetRollDelta(math.random(-1, 1))	
			p:SetVelocity(VectorRand() * 10)
			p:SetCollide(true)
			p:SetColor(120,120,120)
		end
		
		self.Emitter:Finish()
end
		
function EFFECT:Think()
	return false
end

function EFFECT:Render()
end