AddCSLuaFile()
--
SWEP.CooldownHolster = 0.75
SWEP.HolsterSnd = {"homigrad/weapons/holster_rifle.ogg", 55, 100, 110}
SWEP.CooldownDeploy = 1
SWEP.DeployGripFraction = 0.3
SWEP.DeploySnd = {"homigrad/weapons/draw_rifle.mp3", 65, 100, 110}

SWEP.NoAnimDeployTime = 0.15

local sequenceProbe
local sequenceDurations = {}

local function nativeSequenceDuration(model, sequence)
	if not model or model == "" then return end

	local key = model .. "|" .. sequence
	local cached = sequenceDurations[key]
	if cached ~= nil then return cached or nil end

	if not IsValid(sequenceProbe) then
		if SERVER then
			sequenceProbe = ents.Create("base_anim")
			if not IsValid(sequenceProbe) then return end
			sequenceProbe:SetModel(model)
			sequenceProbe:Spawn()
			sequenceProbe:SetNoDraw(true)
			sequenceProbe:SetSolid(SOLID_NONE)
			sequenceProbe:SetMoveType(MOVETYPE_NONE)
		else
			sequenceProbe = ClientsideModel(model)
			if not IsValid(sequenceProbe) then return end
			sequenceProbe:SetNoDraw(true)
		end
	end

	sequenceProbe:SetModel(model)
	local index = sequenceProbe:LookupSequence(sequence)
	local duration = index >= 0 and sequenceProbe:SequenceDuration(index) or 0
	sequenceDurations[key] = duration > 0 and duration or false
	return duration > 0 and duration or nil
end

hg.NativeSequenceDuration = nativeSequenceDuration

function SWEP:GetNativeDrawDuration()
	local list = self.AnimList
	if not list then return end

	local model = self.WorldModelFake or self.WorldModel
	for _, name in ipairs({"deploy", "draw"}) do
		local sequence = list[name]
		if isstring(sequence) then
			local duration = nativeSequenceDuration(model, sequence)
			if duration then return duration end
		end
	end
end

function SWEP:GetDeployDuration()
	local native = self:GetNativeDrawDuration()
	if not native then return self.NoAnimDeployTime end

	local roleDeployMul = hg.GetSubRolePerk and hg.GetSubRolePerk(self:GetOwner(), "DeployMul", 1) or 1
	local armEffectiveness = hg.GetArmEffectiveness and hg.GetArmEffectiveness(self:GetOwner(), "rarm") or 1
	return math.max(native * roleDeployMul / Lerp(armEffectiveness, 0.5, 1), 0.1)
end

function SWEP:HasDrawAnim()
	return self:GetNativeDrawDuration() ~= nil
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
