if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Bruice kit"
SWEP.Color = Color(0, 255, 150)
SWEP.Instructions = "A medical kit designed to restore limb condition. RMB to use on someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_medkit")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_medkit.vmt"
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
		"jaw",
	}

	local brokenLimbsList = { "lleg", "rleg", "larm", "rarm", "chest" }
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

		-- Bones stay ahead of dislocations, but any quarter-charge left after those
		-- higher-priority treatments can reset one joint in the same use.
		if availableResource - totalCost >= 0.25 - 0.001 then
			local dislocations = {
				{key = "llegdislocation", limb = "lleg"},
				{key = "rlegdislocation", limb = "rleg"},
				{key = "larmdislocation", limb = "larm"},
				{key = "rarmdislocation", limb = "rarm"},
				{key = "jawdislocation", limb = "jaw"},
			}

			for _, dislocation in ipairs(dislocations) do
				if org[dislocation.key] then
					totalCost = 0.25
					totalRotations = totalRotations + 2
					table.insert(bonesToHeal, {
						key = dislocation.key,
						limb = dislocation.limb,
						dislocation = true,
						cost = 0.25,
						heal = 0.25,
					})
					break
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
			self:NPCHeal(ent, 0.25, "snd_jack_hmcd_bandage.ogg")
		end

		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and not hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 10, 100))
			if self:GetHolding() < 100 then return end
		end

		local totalRotations, totalCost, bones = self:GetHealData(org)
		if #bones == 0 then return false end

		-- Heal the bones and spend bruise kit
		local amountHealed = 0
		for _, data in ipairs(bones) do
			local key = data.key
			if data.dislocation then
				if hg.organism.CompleteDislocationFix then
					hg.organism.CompleteDislocationFix(org, data.limb, owner)
				else
					org[key] = false
				end
				amountHealed = amountHealed + data.heal
				continue
			end

			local v = tonumber(org[key] or 0) or 0
			local newVal = math.max(v - data.heal, 0)

			if key == "skull" and v >= 0.6 then
				newVal = 0.55
			end

			org[key] = newVal
			amountHealed = amountHealed + (v - newVal)
		end

		self.modeValues[1] = math.max((self.modeValues[1] or 0) - totalCost, 0)

		-- Add a green bandage on the healed joint/chest so the treatment is visible
		if amountHealed > 0 then
			local bruisemap = {
				larm = "ValveBiped.Bip01_L_Forearm",
				rarm = "ValveBiped.Bip01_R_Forearm",
				lleg = "ValveBiped.Bip01_L_Calf",
				rleg = "ValveBiped.Bip01_R_Calf",
				chest = "ValveBiped.Bip01_Spine2",
				pelvis = "ValveBiped.Bip01_Pelvis",
				spine1 = "ValveBiped.Bip01_Spine1",
				spine2 = "ValveBiped.Bip01_Spine2",
				spine3 = "ValveBiped.Bip01_Spine2",
				skull = "ValveBiped.Bip01_Head1",
				jaw = "ValveBiped.Bip01_Head1",
			}
			local spearmint = Color(0, 255, 150)

			ent.bandaged_limbs = ent.bandaged_limbs or {}
			for _, data in ipairs(bones) do
				local boneName = bruisemap[data.limb or data.key]
				if boneName and not ent.bandaged_limbs[boneName] then
					ent.bandaged_limbs[boneName] = { pos = vector_origin, ang = angle_zero, color = spearmint }
				end
			end

			ent:SetNetVar("bandaged_limbs", ent.bandaged_limbs)
			if IsValid(ent.FakeRagdoll) then
				ent.FakeRagdoll:SetNetVar("bandaged_limbs", ent.bandaged_limbs)
			end
			if ent:IsRagdoll() and hg.RagdollOwner(ent) and hg.RagdollOwner(ent):Alive() then
				hg.RagdollOwner(ent):SetNetVar("bandaged_limbs", ent.bandaged_limbs)
			end
		end

		-- gain slight analgesia per total use (0.2-0.4 depending how much one healed)
		local analgesiaAdd = math.Clamp(amountHealed * 0.4, 0.2, 0.4)
		org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + analgesiaAdd, 4)

		owner:EmitSound("snd_jack_hmcd_bandage.ogg", 60, math.random(95, 105))

		if (self.modeValues[1] <= 0) and self.ShouldDeleteOnFullUse then
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
		end

		return true
	end
end
