if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Tranexamic Acid"
SWEP.Instructions = "Use to reduce internal bleeding and stroke meter."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_models/w_jyringe_jroj.mdl"
SWEP.Model = "models/weapons/w_models/w_jyringe_jroj.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/icons/ico_manitol.png")
	SWEP.IconOverride = "vgui/icons/ico_manitol.png"
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
		local stroke_meter = org.stroke_meter or 0
		local infection = org.infection or 0
		
		local canHeal = false

		-- Heal internal bleeding
		if internalBleed > 0 then
			local healed = math.max(internalBleed - self.modeValues[1], 0)
			self.modeValues[1] = self.modeValues[1] - (internalBleed - healed) * (owner.Profession == "doctor" and 0.5 or 1)
			org.internalBleedHeal = org.internalBleedHeal + (internalBleed - healed)
			org.tranexamic_acid = math.min(org.tranexamic_acid + 5, 10)
			canHeal = true
		end

		-- Heal stroke - tranexamic acid is a good remedy
		if stroke_meter > 0 and self.modeValues[1] > 0 then
			local efficacy = stroke_meter > 0.85 and 0.6 or 0.8 -- Good efficacy, even on severe strokes
			local healed = math.max(stroke_meter - self.modeValues[1] * efficacy, 0)
			local amountUsed = (stroke_meter - healed) * 1.5
			self.modeValues[1] = math.max(self.modeValues[1] - amountUsed * (owner.Profession == "doctor" and 0.5 or 1), 0)
			org.stroke_meter = healed
			-- Clear TIA warning if stroke meter drops enough
			if org.stroke_meter < 0.6 then
				org.tia_warning = false
			end
			canHeal = true
		end

		-- Heal infection - tranexamic acid helps fight infection
		if infection > 0 and self.modeValues[1] > 0 then
			local reduction = infection >= 0.75 and 0.3 or (infection >= 0.5 and 0.5 or 0.7) -- Good reduction
			local healed = math.max(infection - reduction, 0)
			local amountUsed = 2
			self.modeValues[1] = math.max(self.modeValues[1] - amountUsed * (owner.Profession == "doctor" and 0.5 or 1), 0)
			org.infection = healed
			canHeal = true
		end

		if canHeal then
			owner:EmitSound("snds_jack_gmod/ez_medical/" .. math.random(16, 18) .. ".wav", 60, math.random(95, 105))
		end

		if self.modeValues[1] <= 0 and self.ShouldDeleteOnFullUse then
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
		end
	end
end
