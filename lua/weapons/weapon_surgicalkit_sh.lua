if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_medkit_sh"
SWEP.PrintName = "Surgical Kit"
SWEP.Instructions = "A surgical bag with a well stocked suture kit, two high tier medicines, a splint and an AED. RMB to apply on others, R to change use mode."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Color = Color(190, 215, 255)

SWEP.modes = 5
SWEP.modeNames = {
	[1] = "suture kit",
	[2] = "tranexamic acid",
	[3] = "mannitol",
	[4] = "splint",
	[5] = "aed",
}

SWEP.modeValuesdef = {
	[1] = {12, false},
	[2] = {1, false},
	[3] = {1, false},
	[4] = {1, false},
	[5] = {1, false},
}

local SUTURE_AMOUNT = 12
local MEDICINE_ORDER = {"adrenaline", "mannitol", "midazolam", "tranexamic"}
local MEDICINE_NAMES = {
	adrenaline = "adrenaline",
	mannitol = "mannitol",
	midazolam = "midazolam",
	tranexamic = "tranexamic acid",
}

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)

function SWEP:ApplyTraumaLoadout()
	local meds = self.surgicalMeds or {"tranexamic", "mannitol"}
	self.modeNames = {
		[1] = "suture kit",
		[2] = MEDICINE_NAMES[meds[1]] or meds[1],
		[3] = MEDICINE_NAMES[meds[2]] or meds[2],
		[4] = "splint",
		[5] = "aed",
	}
end

function SWEP:SyncTraumaLoadout()
	local first = self:GetNWString("hg_surgical_med1", "")
	local second = self:GetNWString("hg_surgical_med2", "")
	if first == "" or (self.surgicalMeds and self.surgicalMeds[1] == first and self.surgicalMeds[2] == second) then return end
	self.surgicalMeds = {first, second}
	self:ApplyTraumaLoadout()
end

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	if SERVER then
		local pool = table.Copy(MEDICINE_ORDER)
		local first = table.remove(pool, math.random(#pool))
		local second = table.remove(pool, math.random(#pool))
		self.surgicalMeds = {first, second}
		self:SetNWString("hg_surgical_med1", first)
		self:SetNWString("hg_surgical_med2", second)
	end
	self:ApplyTraumaLoadout()

	self.modeValues = {
		[1] = SUTURE_AMOUNT,
		[2] = 1,
		[3] = 1,
		[4] = 1,
		[5] = 1,
	}
end

function SWEP:IsSplintMode()
	return self.mode == 4
end

function SWEP:CanBandageTPIK(target)
	return self.mode == 4 and (self.modeValues[4] or 0) > 0 and hg.GetSplintTarget(target) ~= nil
end

if SERVER then
	local needleSound = "snd_jack_hmcd_needleprick.ogg"

	function SWEP:UseSurgicalMedicine(medicine, ent, org, entOwner)
		if medicine == "adrenaline" then
			return self:UseBorrowedSlot("weapon_adrenaline", ent)
		elseif medicine == "mannitol" then
			hg.organism.ApplyMannitol(org, 1)
		elseif medicine == "midazolam" then
			hg.organism.ApplyMidazolam(org)
		elseif medicine == "tranexamic" then
			hg.organism.AdministerTranexamic(org, 10)
		else
			return false
		end

		entOwner:EmitSound(needleSound, 60, math.random(95, 105))
		return true
	end

	function SWEP:Heal(ent, mode, bone)
		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()
		local slot = self.mode
		if (self.modeValues[slot] or 0) <= 0 then return end

		if slot == 1 then
			if not owner:IsPlayer() then return end
			return hg.Suture.Start(owner, self, ent, 1)
		end

		if ent == hg.GetCurrentCharacter(owner) and not hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 50, 100))
			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		local done
		if slot == 2 or slot == 3 then
			done = self:UseSurgicalMedicine(self.surgicalMeds and self.surgicalMeds[slot - 1], ent, org, entOwner)
		elseif slot == 4 then
			done = hg.ApplySplint and hg.ApplySplint(owner, ent, bone)
		elseif slot == 5 and owner:IsPlayer() then
			done = self:GiveTraumaAED(owner)
		end

		if done then
			self.modeValues[slot] = 0
			if self.poisoned2 and slot ~= 4 then
				org.poison4 = CurTime()
				self.poisoned2 = nil
			end
			if self.RefreshPerfusionTreatment then
				self:RefreshPerfusionTreatment(ent, owner.Profession == "doctor" and 0.25 or 0.18)
			end
		end

		self:RemoveIfEmpty()
		return done
	end
end
