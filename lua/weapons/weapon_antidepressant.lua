if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Antidepressants"
SWEP.Author = "ZCity Delta"
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Slot = 4
SWEP.SlotPos = 3

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("weapons/weapon_bandage_sh")
    SWEP.DrawWeaponInfoBox = false
end

SWEP.deltas = 1
SWEP.modeValues = { 1 }
SWEP.mode = 1
SWEP.ShouldDeleteOnFullUse = true

function SWEP:Heal(target, mode)
    if not IsValid(target) or not target:IsPlayer() then return false end
    if not target.organism then return false end

    if hg and hg.Mental and hg.Mental.ApplyAntidepressantDose then
        hg.Mental.ApplyAntidepressantDose(self:GetOwner(), target, 1)
    end

    self.modeValues[1] = math.max((self.modeValues[1] or 0) - 1, 0)
    self:SetNetVar("modeValues", table.Copy(self.modeValues))

    local owner = self:GetOwner()
    if IsValid(owner) then
        local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
        entOwner:EmitSound("snds_jack_gmod/ez_medical/" .. math.random(16, 18) .. ".wav", 60, math.random(95, 105))
    end

    return true
end
