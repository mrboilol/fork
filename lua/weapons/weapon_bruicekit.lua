if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Bruice kit"
SWEP.Instructions = "A medical kit designed to restore limb condition. RMB to use on someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_medkit")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_medkit.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.Slot = 3
SWEP.SlotPos = 1

SWEP.mode = 1
SWEP.modes = 1
SWEP.modeNames = {
	[1] = "bruise kit",
}

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)
	self.ModelScale = 1

	self.modeValues = {
		[1] = 1.0,
	}
end

SWEP.modeValuesdef = {
	[1] = {1.0, false},
}

SWEP.ShouldDeleteOnFullUse = true

if SERVER then
	local conditionPriority = {
		"spine3",
		"spine2",
		"spine1",
		"pelvis",
		"lleg",
		"rleg",
		"larm",
		"rarm",
		"chest",
		"skull",
	}

	local brokenLimbsList = { "lleg", "rleg", "larm", "rarm" }
	local complexBonesList = { "spine3", "spine2", "spine1", "pelvis", "chest", "skull" }

	local function CanHealKey(org, key)
		local v = tonumber(org[key] or 0) or 0
		if key == "larm" and org.larmamputated then return false end
		if key == "rarm" and org.rarmamputated then return false end
		if key == "lleg" and org.llegamputated then return false end
		if key == "rleg" and org.rlegamputated then return false end
		return v >= 0.05
	end

	function SWEP:GetHealData(org)
		local totalRotations = 1 -- Base 1 rotation
		local totalCost = 0
		local bonesToHeal = {}
		local availableResource = self.modeValues[1] or 0

		-- Prioritize based on conditionPriority order
		for _, key in ipairs(conditionPriority) do
			if CanHealKey(org, key) then
				local isBroken = table.HasValue(brokenLimbsList, key)
				local isComplex = table.HasValue(complexBonesList, key)
				local cost = 0.25 -- 0.25 regen per bone
				local rotations = isBroken and 2 or 1 -- 2 rotations for broken bones, 1 for others
				
				if totalCost + cost <= availableResource + 0.001 then
					totalCost = totalCost + cost
					totalRotations = totalRotations + rotations
					table.insert(bonesToHeal, {key = key, cost = cost, heal = 0.25})
				end
			end
		end

		return totalRotations, totalCost, bonesToHeal
	end

	function SWEP:CanHeal(ent)
		local org = ent and ent.organism
		if not org then return false end
		local available = self.modeValues and self.modeValues[1] or 0
		if available <= 0 then return false end

		local _, totalCost, bones = self:GetHealData(org)
		return #bones > 0
	end

	function SWEP:Heal(ent, mode, bone)
		if ent:IsNPC() then
			self:NPCHeal(ent, 0.25, "snd_jack_hmcd_bandage.wav")
		end

		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 10, 100))
			if self:GetHolding() < 100 then return end
		end

		local totalRotations, totalCost, bones = self:GetHealData(org)
		if #bones == 0 then return false end

		-- Heal the bones and spend bruise kit
		local amountHealed = 0
		for _, data in ipairs(bones) do
			local key = data.key
			local v = tonumber(org[key] or 0) or 0
			org[key] = math.max(v - data.heal, 0)
			amountHealed = amountHealed + data.heal
		end

		self.modeValues[1] = math.max((self.modeValues[1] or 0) - totalCost, 0)

		-- gain slight analgesia per total use (0.2-0.4 depending how much one healed)
		local analgesiaAdd = math.Clamp(amountHealed * 0.4, 0.2, 0.4)
		org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + analgesiaAdd, 4)

		owner:EmitSound("snd_jack_hmcd_bandage.wav", 60, math.random(95, 105))

		if (self.modeValues[1] <= 0) and self.ShouldDeleteOnFullUse then
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
		end

		return true
	end
end
