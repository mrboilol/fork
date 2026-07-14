AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    if SERVER then

        self.Garbage = true
        print(self.Type)
        self:SetModel(table.Random(ab_MedicalGarbageTypes[self.Type]))
        self:SetMoveType( MOVETYPE_NONE )
        self:SetSolid( SOLID_NONE)
        self:DrawShadow( false )
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:Wake()
            phys:SetBuoyancyRatio(0)
            phys:SetMass(1)
        end   
    end
end

function ENT:Use(activator,caller)

end 

function ENT:Think()
end

function ENT:OnRemove()
end