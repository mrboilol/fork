AddCSLuaFile()
--
SWEP.CooldownHolster = 0.75
SWEP.HolsterSnd = {"homigrad/weapons/holster_rifle.ogg", 55, 100, 110}
SWEP.CooldownDeploy = 1
SWEP.DeployGripFraction = 0.3
SWEP.DeploySnd = {"homigrad/weapons/draw_rifle.mp3", 65, 100, 110}

function SWEP:GetDeployDuration()
	local roleDeployMul = hg.GetSubRolePerk and hg.GetSubRolePerk(self:GetOwner(), "DeployMul", 1) or 1
	local armEffectiveness = hg.GetArmEffectiveness and hg.GetArmEffectiveness(self:GetOwner(), "rarm") or 1
	local support = self.GetHandSupportState and self:GetHandSupportState(self:GetOwner())
	local stanceMul = support and (support.postureOneHanded and 0.75 or support.wantsTwoHands and 1.1) or 1
	return math.max(self.CooldownDeploy / self.Ergonomics * roleDeployMul * stanceMul / Lerp(armEffectiveness, 0.5, 1), 0.3)
end

function SWEP:GetHolsterDuration()
	return self:GetDeployDuration()
end

function SWEP:GetDrawFraction()
	local owner = self:GetOwner()
	if IsValid(owner) and owner.GetActiveWeapon and owner:GetActiveWeapon() ~= self then return end

	local now = CurTime()
	if self.holster then
		return math.Clamp((self.holster - now) / math.max(hg.GetHolsterTotal(self), 0.001), 0, 1)
	end
	if self.deploy then
		return math.Clamp(1 - (self.deploy - now) / self:GetDeployDuration(), 0, 1)
	end
end

local drawAnims = {"deploy", "draw"}

function SWEP:GetDrawAnim()
	local wm = self:GetWM()
	if not wm then return end
	for _, name in ipairs(drawAnims) do
		local sequence = self.AnimList[name]
		if isstring(sequence) and wm:LookupSequence(sequence) >= 0 then return name end
	end
end

function SWEP:UpdateDrawAnim()
	local owner = self:GetOwner()
	if not IsValid(owner) or owner:GetActiveWeapon() ~= self then
		self.drawAnimKey = nil
		return
	end

	if not self:GetWM() then return end

	local key = self.holster or (self.deploy and -self.deploy)
	if key == self.drawAnimKey then return end

	local previous = self.drawAnimKey
	self.drawAnimKey = key

	local anim = self:GetDrawAnim()
	if not anim then return end

	local duration = self:GetDeployDuration()
	local now = CurTime()
	if self.holster then
		local fraction = self:GetDrawFraction()
		self.SuppressAnimEvents = true
		self:PlayAnim(anim, {duration, duration * (1 - fraction)}, false, nil, true)
		self.SuppressAnimEvents = nil
	elseif self.deploy then
		self:PlayAnim(anim, {duration, math.Clamp(duration - (self.deploy - now), 0, duration)}, false)
	elseif previous then
		self:PlayAnim("idle", 1, not self.NoIdleLoop)
	end
end

function SWEP:Step_HolsterDeploy(time)
	self.deploy = self:GetDeploy() != 0 and self:GetDeploy() or nil
	self.holster = hg.GetHolsterEnd(self)

	if self.deploy and self.deploy < time then if self.Deploy_End then self:Deploy_End() end end
	if CLIENT then self:UpdateDrawAnim() end
end

function SWEP:WeaponDeployPost()
end

if SERVER then return end

function SWEP:Holster(wep)
	if hg.HolsterGate(self, wep) then return false end

	if not IsFirstTimePredicted() then return end

	if self.deploy then
		self:SetDeploy(0)
		self.deploy = nil
	end
	self.reload = nil

	if self.WorldModelFake then self:PlayAnim("idle", 1, not self.NoIdleLoop) end

	return true
end

function SWEP:Deploy()
	local time = CurTime()
	self:ResetTransientAimState()

	if self.MagIndex and IsValid(self:GetWM()) then
		self:GetWM():ManipulateBoneScale(self.MagIndex, vector_origin)
	end

	if self.WorldModelFake and not self:GetDrawAnim() then self:PlayAnim("idle", 1, not self.NoIdleLoop) end

	self.deploy = time + self:GetDeployDuration()
	self:SetDeploy(self.deploy)

	return true
end

function SWEP:Deploy_End()
	self.deploy = nil
	self:SetDeploy(0)
end
