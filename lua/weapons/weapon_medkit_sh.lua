if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.BandageTPIK = false
SWEP.PrintName = "Trauma Pack"
SWEP.Instructions = "A small bag containing medical supplies. Has a bandage or bruise pack, painkillers, a tourniquet, a decompression needle and one random emergency item. A necessary thing in hiking, military conditions and just a necessary thing in everyday life. RMB to apply on others, R to change use mode."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/w_models/weapons/w_eq_medkit.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_medkit")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_medkit.vmt"
	SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -0.5, -3)
SWEP.offsetAng = Angle(-30, 20, 90)
SWEP.modes = 5
SWEP.modeNames = {
	[1] = "bandaging",
	[2] = "painkiller",
	[3] = "tranexamic acid",
	[4] = "tourniquet",
	[5] = "decompression needle",
}
SWEP.ofsV = Vector(0,0,0)
SWEP.ofsA = Angle(0,0,0)

local TRAUMA_BRUISE_CHANCE = 0.35
local BASE_MODE_NAMES = {"bandaging", "painkiller", "tranexamic acid", "tourniquet", "decompression needle"}
local BASE_MODE_DEFS = {{100, true}, {1, false}, {10, true}, {1, true}, {1, false}}
local TRAUMA_SLOTS = {
	tranexamic = {name = "tranexamic acid", amount = 10},
	mannitol = {name = "mannitol", amount = 1},
	epinephrine = {name = "epinephrine", amount = 1},
	thiamine = {name = "thiamine", amount = 1},
	betablocker = {name = "beta blockers", amount = 1},
	midazolam = {name = "midazolam", amount = 1},
	bloodpack = {name = "blood pack 750 mL o-", amount = 1},
	aed = {name = "aed", amount = 1},
}
local TRAUMA_SLOT_ORDER = {"tranexamic", "mannitol", "epinephrine", "thiamine", "betablocker", "midazolam", "bloodpack", "aed"}
local TRAUMA_BORROWED_CLASSES = {
	epinephrine = "weapon_adrenaline",
	thiamine = "weapon_thiamine",
	betablocker = "weapon_betablock",
}
local TRAUMA_BLOOD_VOLUME = 750

function SWEP:ApplyTraumaLoadout()
	local slotKey = TRAUMA_SLOTS[self.traumaSlot] and self.traumaSlot or "tranexamic"
	local slot = TRAUMA_SLOTS[slotKey]
	local names = table.Copy(BASE_MODE_NAMES)
	local defs = table.Copy(BASE_MODE_DEFS)
	if self.traumaBruise then
		names[1] = "bruise pack"
		defs[1] = {1.5, false}
	end
	names[3] = slot.name
	defs[3] = {slot.amount, slotKey == "tranexamic"}
	self.modeNames = names
	self.modeValuesdef = defs
end

function SWEP:SyncTraumaLoadout()
	local slot = self:GetNWString("hg_trauma_slot", "")
	local bruise = self:GetNWBool("hg_trauma_bruise", false)
	if slot == "" or (slot == self.traumaSlot and bruise == self.traumaBruise) then return end
	self.traumaSlot = slot
	self.traumaBruise = bruise
	self:ApplyTraumaLoadout()
end

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	if SERVER then
		self.traumaSlot = TRAUMA_SLOT_ORDER[math.random(#TRAUMA_SLOT_ORDER)]
		self.traumaBruise = math.random() < TRAUMA_BRUISE_CHANCE
		self:SetNWString("hg_trauma_slot", self.traumaSlot)
		self:SetNWBool("hg_trauma_bruise", self.traumaBruise)
	end
	self:ApplyTraumaLoadout()

	self.modeValues = {
		[1] = self.traumaBruise and 1.5 or 100,
		[2] = 1,
		[3] = TRAUMA_SLOTS[self.traumaSlot or "tranexamic"].amount,
		[4] = 1,
		[5] = 1,
	}
end

SWEP.modeValuesdef = {
	[1] = {100,true},
	[2] = {1,false},
	[3] = {10,true},
	[4] = {1,true},
	[5] = {1,false},
}
SWEP.ShouldDeleteOnFullUse = true

local math = math
local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)
function SWEP:Think()
	self:SyncTraumaLoadout()
	if not self:GetOwner():KeyDown(IN_ATTACK) and not hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 12, 0))
	end
end

local lang1, lang2 = Angle(0, -10, 0), Angle(0, 10, 0)
function SWEP:Animation()
	local owner = self:GetOwner()
	if (owner.zmanipstart ~= nil and not ( owner.organism and owner.organism.larmamputated )) then return end

	if not owner.GetAimVector then return end
	local aimvec = owner:GetAimVector()
	if not aimvec then return end

	local hold = self:GetHolding()
	local ducking = owner:IsFlagSet(FL_ANIMDUCKING)

    self:BoneSet("r_upperarm", vector_origin, Angle(30 - hold / 5, -30 + hold / 2 + 20 * aimvec[3] * (ducking and -3 or -1), 5 - hold / 4))
    self:BoneSet("r_forearm", vector_origin, Angle(hold / 25, -hold / 2.5, 35 -hold / 1.4))

    self:BoneSet("l_upperarm", vector_origin, lang1)
    self:BoneSet("l_forearm", vector_origin, lang2)
end

function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if IsValid(owner) and owner:IsNPC() then
		self:SpawnGarbage()
		self:NPCHeal(owner, 0.6, "snd_jack_hmcd_bandage.ogg")
	end
end

function SWEP:CanBandageTPIK(target)
	if self.traumaBruise and self.mode == 1 then
		local bruise = weapons.GetStored("weapon_bruicekit")
		return bruise ~= nil and bruise.CanHeal ~= nil and bruise.CanHeal(self, target) or false
	end

	return weapons.GetStored("weapon_bandage_sh").CanBandageTPIK(self, target)
end

if SERVER then
	function SWEP:GetHealData(org, bone)
		return weapons.GetStored("weapon_bruicekit").GetHealData(self, org, bone)
	end

	function SWEP:UseBruisePack(ent, bone)
		local bruise = weapons.GetStored("weapon_bruicekit")
		if not bruise or not bruise.Heal then return end

		local deleteOnFullUse = self.ShouldDeleteOnFullUse
		self.ShouldDeleteOnFullUse = false
		local done = bruise.Heal(self, ent, self.mode, bone)
		self.ShouldDeleteOnFullUse = deleteOnFullUse
		return done
	end

	function SWEP:UseBorrowedSlot(class, ent)
		local stored = weapons.GetStored(class)
		if not stored or not stored.Heal then return false end

		local owner = self:GetOwner()
		local medkit = self
		local proxy = setmetatable({
			modeValues = {1},
			poisoned2 = self.poisoned2,
			GetOwner = function() return owner end,
			GetHolding = function() return 100 end,
			SetHolding = function() end,
			Remove = function() end,
			SpawnGarbage = function() end,
			NPCHeal = function() end,
			RefreshPerfusionTreatment = function(_, target, amount) return medkit:RefreshPerfusionTreatment(target, amount) end,
		}, {__index = stored})

		stored.Heal(proxy, ent, 1)
		self.poisoned2 = proxy.poisoned2
		if IsValid(owner) then owner:SelectWeapon(self:GetClass()) end
		return proxy.modeValues[1] <= 0
	end

	function SWEP:GiveTraumaAED(owner)
		local class = "weapon_defibrillator"
		if not weapons.GetStored(class) then return false end

		if not owner:HasWeapon(class) then
			local given = owner:Give(class)
			if IsValid(given) then
				owner:SelectWeapon(class)
				return true
			end
		end

		local item = ents.Create(class)
		if not IsValid(item) then return false end
		item:SetPos(owner:EyePos() + owner:GetAimVector() * 40)
		item:Spawn()
		item.IsSpawned = true
		return true
	end

	function SWEP:UseTraumaSlot(ent, org, owner, entOwner)
		if (self.modeValues[3] or 0) <= 0 then return end

		local slot = self.traumaSlot
		local done
		if slot == "mannitol" then
			hg.organism.ApplyMannitol(org, 1)
			entOwner:EmitSound("snd_jack_hmcd_needleprick.ogg", 60, math.random(95, 105))
			done = true
		elseif slot == "midazolam" then
			hg.organism.ApplyMidazolam(org)
			entOwner:EmitSound("snd_jack_hmcd_needleprick.ogg", 60, math.random(95, 105))
			done = true
		elseif slot == "bloodpack" then
			org.blood = math.min((org.blood or 0) + TRAUMA_BLOOD_VOLUME, hg.organism.MAX_TRANSFUSION_BLOOD or 6500)
			self:RefreshPerfusionTreatment(ent, 0.3)
			entOwner:EmitSound("zcity/healing/bloodbag_spear_0.ogg", 60, math.random(95, 105))
			done = true
		elseif slot == "aed" then
			done = self:GiveTraumaAED(owner)
		elseif TRAUMA_BORROWED_CLASSES[slot] then
			done = self:UseBorrowedSlot(TRAUMA_BORROWED_CLASSES[slot], ent)
		end

		if done then
			if self.poisoned2 then
				org.poison4 = CurTime()
				self.poisoned2 = nil
			end
			self.modeValues[3] = 0
		end
	end

	function SWEP:Heal(ent, mode, bone)
		if ent:IsNPC() then
			self:SpawnGarbage()
			self:NPCHeal(ent, 0.6, "snd_jack_hmcd_bandage.ogg")
		end

		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and not hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 50, 100))
			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		if self.mode == 2 then
			if self.modeValues[2] == 0 then return end
			org.analgesiaAdd = math.min(org.analgesiaAdd + self.modeValues[2] * 0.3, 4)
			self.modeValues[2] = 0
			entOwner:EmitSound("snds_jack_gmod/ez_medical/15.ogg", 60, math.random(95, 105))
		elseif self.mode == 3 and (self.traumaSlot or "tranexamic") ~= "tranexamic" then
			self:UseTraumaSlot(ent, org, owner, entOwner)
		elseif self.mode == 3 then
			if self.modeValues[3] == 0 then return end
			local internalBleed = org.internalBleed - org.internalBleedHeal

			if self.poisoned2 then
				org.poison4 = CurTime()
				self.poisoned2 = nil
			end

			if internalBleed > 0 then
				local healed = math.max(internalBleed - self.modeValues[3], 0)
				self.modeValues[3] = self.modeValues[3] - (internalBleed - healed) * (owner.Profession == "doctor" and 0.5 or 1)
				org.internalBleedHeal = org.internalBleedHeal + (internalBleed - healed)
				entOwner:EmitSound("snds_jack_gmod/ez_medical/" .. math.random(16, 18) .. ".ogg", 60, math.random(95, 105))
			end
		elseif self.mode == 1 then
			if self.traumaBruise then
				self:UseBruisePack(ent, bone)
			else
				self:Bandage(ent, bone)
			end
		elseif self.mode == 4 then
			if self:Tourniquet(ent, bone) then self.modeValues[4] = 0 end
		elseif self.mode == 5 then
			if self.modeValues[5] == 0 then return end
			if self.poisoned2 then
				org.poison4 = CurTime()
				self.poisoned2 = nil
			end

			org.needle = 1
			if org.trachea and org.trachea > 0 then
				org.trachea = math.max(org.trachea - 0.75, 0)
			end

			self.modeValues[5] = 0
			entOwner:EmitSound("snd_jack_hmcd_needleprick.ogg", 60, math.random(95, 105))
		end

		if self.RefreshPerfusionTreatment then
			self:RefreshPerfusionTreatment(ent, owner.Profession == "doctor" and 0.25 or 0.18)
		end

		if self.modeValues[1] <= 0 and self.modeValues[2] <= 0 and self.modeValues[3] <= 0 and self.modeValues[4] <= 0 and self.modeValues[5] <= 0 and self.ShouldDeleteOnFullUse then
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
		end
	end
end
