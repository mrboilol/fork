if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Tranexamic Acid"
SWEP.Instructions = "Use to reduce internal bleeding."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/morphine_syrette/morphine.mdl"
SWEP.Model = "models/morphine_syrette/morphine.mdl"
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
SWEP.offsetVec = Vector(4, -1.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modes = 1
SWEP.modeNames = {
	[1] = "tranexamic acid",
}
SWEP.ofsV = Vector(0,8,-3)
SWEP.ofsA = Angle(-90,-90,90)
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

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

function SWEP:Think()
	if not self:GetOwner():KeyDown(IN_ATTACK) and hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 4, 0))
	end
end

function SWEP:Animation()
	local hold = self:GetHolding()
    self:BoneSet("r_upperarm", vector_origin, Angle(0, -hold + (100 * (hold / 100)), 0))
    self:BoneSet("r_forearm", vector_origin, Angle(-hold / 6, -hold * 2, -15))
end

if SERVER then
	function SWEP:Heal(ent, mode)
		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()

		if self.modeValues[1] == 0 then return end

		if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))

			if self:GetHolding() < 100 then return end
		end

		if self.poisoned2 then
			org.poison4 = CurTime()
			self.poisoned2 = nil
		end

		local internalBleed = org.internalBleed - org.internalBleedHeal

		local canHeal = false

		-- Heal internal bleeding (same as medkit tranexamic acid)
		if internalBleed > 0 then
			local healed = math.max(internalBleed - self.modeValues[1], 0)
			self.modeValues[1] = self.modeValues[1] - (internalBleed - healed) * (owner.Profession == "doctor" and 0.5 or 1)
			org.internalBleedHeal = org.internalBleedHeal + (internalBleed - healed)
			org.tranexamic_acid = math.min(org.tranexamic_acid + 5, 10)
			canHeal = true
		end

		-- Help with external bleeding
		if org.bleed > 0 then
			local bleedHeal = math.min(org.bleed, self.modeValues[1] * 0.5)
			org.bleed = org.bleed - bleedHeal
			self.modeValues[1] = self.modeValues[1] - bleedHeal * 2
			canHeal = true
		end

		-- Help with ischemia (low blood flow)
		if org.blood and org.blood < 4000 then
			local bloodAdd = math.min(self.modeValues[1] * 50, 4000 - org.blood)
			org.blood = org.blood + bloodAdd
			self.modeValues[1] = self.modeValues[1] - (bloodAdd / 50)
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
