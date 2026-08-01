AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "ZCLP Placeholder Entity"
ENT.Spawnable = false

if SERVER then
    function ENT:Initialize()
        self:SetNoDraw(true)
        self:DrawShadow(false)
    end
end
