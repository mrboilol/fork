AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
	local model = self.PhoneModelOverride or HG_PHONE.DEFAULT_DESK_MODEL
	if not util.IsValidModel(model) then model = HG_PHONE.MODEL_HANDHELD end
	self:SetModel(model)
	self:SetPortableModel(string.lower(model) == string.lower(HG_PHONE.MODEL_HANDHELD))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:SetMass(math.Clamp(phys:GetMass(), 1, 12))
	else
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_BBOX)
	end

	timer.Simple(0, function()
		if IsValid(self) and HG_PHONE_SERVER then HG_PHONE_SERVER:RegisterPhone(self) end
	end)
end

function ENT:Use(activator)
	if not IsValid(activator) or not activator:IsPlayer() or not HG_PHONE_SERVER then return end
	HG_PHONE_SERVER:OpenPhone(activator, self)
end

function ENT:OnRemove()
	if HG_PHONE_SERVER and HG_PHONE.GetNumber(self) ~= "" then HG_PHONE_SERVER:UnregisterPhone(self) end
end
