if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Tranexamic Acid"
SWEP.Instructions = "Use to reduce internal bleeding and stroke meter."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/props_health/health_vial.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_medkit")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_medkit.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -0.5, -3)
SWEP.offsetAng = Angle(-30, 20, 90)
SWEP.modes = 1
SWEP.modeNames = {
	[1] = "tranexamic acid",
}
SWEP.ofsV = Vector(-2,-10,8)
SWEP.ofsA = Angle(90,-90,90)
function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	self.modeValues = {
		[1] = 10,
	}
	self.mode = 1
end

SWEP.modeValuesdef = {
	[1] = {10,true},
}
SWEP.ShouldDeleteOnFullUse = true

if SERVER then
	function SWEP:Heal(ent, mode)
		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()

		if self.modeValues[1] == 0 then return end
		local internalBleed = org.internalBleed - org.internalBleedHeal

		if internalBleed > 0 then
			local healed = math.max(internalBleed - self.modeValues[1], 0)
			self.modeValues[1] = self.modeValues[1] - (internalBleed - healed) * (owner.Profession == "doctor" and 0.5 or 1)
			org.internalBleedHeal = org.internalBleedHeal + (internalBleed - healed)
			org.stroke_meter = math.max(org.stroke_meter - 0.25, 0)
			owner:EmitSound("snds_jack_gmod/ez_medical/" .. math.random(16, 18) .. ".wav", 60, math.random(95, 105))
		end

		if self.modeValues[1] <= 0 and self.ShouldDeleteOnFullUse then
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
		end
	end
end
