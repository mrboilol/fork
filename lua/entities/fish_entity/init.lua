AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/fish/fish.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysWake()

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

function ENT:Use(activator, caller)
    if activator:IsPlayer() then
        activator:PickupObject(self)
    end
end
