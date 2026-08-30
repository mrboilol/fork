if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Tranexamic Acid"
SWEP.Instructions = "Use to reduce internal bleeding, including traumatic brain hemorrhages."
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
SWEP.offsetVec = Vector(8, -1.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modes = 1
SWEP.modeNames = {
	[1] = "tranexamic acid",
}
SWEP.ofsV = Vector(0,8,-3)
SWEP.ofsA = Angle(-90,-90,90)

function SWEP:SetupDataTables()
    self:NetworkVar("Float",0,"Holding")
    self:NetworkVar("Float",1,"RemainingAmount")
end

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	self.modeValues = {
		[1] = 10,
	}
	self.mode = 1
	self.ModelScale = 1
end

SWEP.modeValuesdef = {
	[1] = {10,true},
}
SWEP.ShouldDeleteOnFullUse = false

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)

function SWEP:Think()
	if not self:GetOwner():KeyDown(IN_ATTACK) and not hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 4, 0))
	end
	
	-- Update model scale based on remaining amount (use networked value on client)
	local remaining = SERVER and self.modeValues[1] or self:GetRemainingAmount()
	if self.modeValuesdef and self.modeValuesdef[1] and self.modeValuesdef[1][1] then
		self.ModelScale = math.Clamp(remaining / (self.modeValuesdef[1][1] * 0.8), 0.5, 1)
	else
		self.ModelScale = self.ModelScale or 1
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

		if ent == hg.GetCurrentCharacter(owner) and not hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))

			if self:GetHolding() < 100 then return end
		end

		if self.poisoned2 then
			org.poison4 = CurTime()
			self.poisoned2 = nil
		end

		local dose = self.modeValues[1]
		if dose > 0 then
			hg.organism.AdministerTranexamic(org, dose)
			self.modeValues[1] = 0
			owner:EmitSound("snds_jack_gmod/ez_medical/" .. math.random(16, 18) .. ".ogg", 60, math.random(95, 105))
		end

		-- Sync remaining amount to client
		self:SetRemainingAmount(self.modeValues[1])
		
		-- No deletion - syringe stays even when empty
		-- if self.modeValues[1] <= 0 and self.ShouldDeleteOnFullUse then
		-- 	owner:SelectWeapon("weapon_hands_sh")
		-- 	self:Remove()
		-- end
	end
end
