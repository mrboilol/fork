ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Phone"
ENT.Category = "ZCity Other"
ENT.Spawnable = true
ENT.AdminOnly = false

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "PortableModel")
end
