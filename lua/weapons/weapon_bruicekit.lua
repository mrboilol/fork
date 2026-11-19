if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Bruice kit"
SWEP.Color = Color(60, 200, 60)
SWEP.BandageTPIKColor = SWEP.Color
SWEP.Instructions = "A roll of green trauma bandages for bruises, burns and damaged muscle. Sets broken bones (not spines) so they can heal. Does not stop bleeding. RMB to use on someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_bandage")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_bandage.png"
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
		[1] = 1.5,
	}
end

SWEP.modeValuesdef = {
	[1] = {1.5, false},
}

SWEP.ShouldDeleteOnFullUse = true

if SERVER then
	local BONE_COST = 0.1
	local BONE_DEBUFF = 0.3
	local GREEN = Color(60, 200, 60)
	local BONE_ORDER = {"skull", "chest", "pelvis", "jaw", "lleg", "rleg", "larm", "rarm"}
	local BONE_THRESHOLDS = {skull = 0.6, chest = 1, pelvis = 1, jaw = 1}
	local LIMB_BONE_KEYS = {head = {"skull", "jaw"}, torso = {"chest", "pelvis"}}
	local WRAP_BONES = {
		head = "ValveBiped.Bip01_Head1",
		torso = "ValveBiped.Bip01_Spine2",
		larm = "ValveBiped.Bip01_L_Forearm",
		rarm = "ValveBiped.Bip01_R_Forearm",
		lleg = "ValveBiped.Bip01_L_Calf",
		rleg = "ValveBiped.Bip01_R_Calf",
		skull = "ValveBiped.Bip01_Head1",
		jaw = "ValveBiped.Bip01_Head1",
		chest = "ValveBiped.Bip01_Spine2",
		pelvis = "ValveBiped.Bip01_Pelvis",
	}

	local function needsSetting(org, key)
		if BONE_THRESHOLDS[key] then return (tonumber(org[key]) or 0) >= BONE_THRESHOLDS[key] end

		return hg.IsLimbFractured(org, key)
	end

	local function pickBone(org, bone)
		local aimed = hg.SoftTissue.LimbFromBone(bone)
		local candidates = aimed and (LIMB_BONE_KEYS[aimed] or {aimed}) or {}
		if isstring(bone) and string.find(bone, "Pelvis", 1, true) then candidates = {"pelvis", "chest"} end

		for _, key in ipairs(candidates) do
			if needsSetting(org, key) then return key end
		end
		for _, key in ipairs(BONE_ORDER) do
			if needsSetting(org, key) then return key end
		end
	end

	local function tissueRelief(org, steps)
		local SoftTissue = hg.SoftTissue
		local limb = steps[1] and steps[1].target
		if not limb then return 0 end

		local soft, muscle = SoftTissue.GetLimb(org, limb), SoftTissue.GetMuscle(org, limb)
		for _, step in ipairs(steps) do
			if step.kind == "muscle" then
				muscle = math.max(muscle - step.heal, 0)
			else
				soft = soft - math.min(step.heal, SoftTissue.Get(org, step.kind, limb))
			end
		end

		return SoftTissue.FunctionFor(limb, math.max(soft, 0), muscle) - SoftTissue.GetLimbFunction(org, limb)
	end

	local function softCritLimb(org)
		local SimpleHealth = hg.SimpleHealth
		local state = SimpleHealth.GetState(org)
		if not state or SimpleHealth.GetHealth(state) > (SimpleHealth.GetCritThresholds()) then return end

		local amounts = hg.Medicine.Items.weapon_bruicekit.amount
		local weights = SimpleHealth.Config.damage.limbHealth
		local best, bestGain = nil, 0
		for _, limb in ipairs(hg.SoftTissue.LIMBS) do
			local gain = (math.min(hg.SoftTissue.Get(org, "brute", limb), amounts.brute)
				+ math.min(hg.SoftTissue.Get(org, "burn", limb), amounts.burn)) * (weights[limb] or 1)
			if gain > bestGain then best, bestGain = limb, gain end
		end

		return best
	end

	function SWEP:GetHealData(org, bone)
		local totalRotations = 1
		local totalCost = 0
		local bonesToHeal = {}
		local availableResource = self.modeValues[1] or 0

		local dislocation = not hg.SimpleHealth.GetState(org) and hg.organism.GetBandageDislocation(org, bone)
		if dislocation and availableResource >= 0.25 then
			totalCost = totalCost + 0.25
			totalRotations = totalRotations + 2
			table.insert(bonesToHeal, {
				key = dislocation .. "dislocation",
				limb = dislocation,
				dislocation = true,
				cost = 0.25,
				heal = 0.25,
			})
		end

		local available = availableResource - totalCost
		local critLimb = softCritLimb(org)
		local steps, stepCost = hg.Medicine.Plan("weapon_bruicekit", org, critLimb and WRAP_BONES[critLimb] or bone, available)

		local boneKey = not critLimb and available >= BONE_COST - 0.001 and pickBone(org, bone)
		if boneKey and (#steps == 0 or tissueRelief(org, steps) <= BONE_DEBUFF) then
			steps, stepCost = {{key = boneKey, limb = boneKey, setBone = true, cost = BONE_COST, heal = 0}}, BONE_COST
		end

		for _, step in ipairs(steps) do
			totalRotations = totalRotations + 1
			bonesToHeal[#bonesToHeal + 1] = step
		end

		return totalRotations, totalCost + stepCost, bonesToHeal
	end

	local function wrapGreen(ent, boneName, applied)
		if not boneName or not hg.AddBandageLayer(ent, boneName, applied) then return end

		local state = ent.bandaged_limbs[boneName]
		if istable(state) then
			state.color = GREEN
		else
			ent.bandaged_limbs[boneName] = {pos = vector_origin, ang = angle_zero, color = GREEN, layers = tonumber(state) or 1}
		end
	end

	function SWEP:CanHeal(ent)
		local org = ent and ent.organism
		if not org then return false end
		local available = self.modeValues and self.modeValues[1] or 0
		if available <= 0 then return false end

		local _, totalCost, bones = self:GetHealData(org)
		return #bones > 0
	end

	function SWEP:CanBandageTPIK(target)
		return self:CanHeal(target)
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

		local totalRotations, totalCost, bones = self:GetHealData(org, bone)
		if #bones == 0 then return false end

		local amountHealed = 0
		local wrapped = {}
		local applied = {}
		for _, data in ipairs(bones) do
			if data.medicine then
				if hg.Medicine.ApplyStep(org, data) > 0 then
					amountHealed = amountHealed + data.cost
					wrapped[#wrapped + 1] = WRAP_BONES[data.target]
				end
				continue
			end

			if data.setBone then
				if hg.organism.ApplyBandageBoneTreatment(org, data.key, nil, true) > 0 then
					amountHealed = amountHealed + data.cost
					wrapped[#wrapped + 1] = WRAP_BONES[data.key]
				end
				continue
			end

			hg.organism.CompleteDislocationFix(org, data.limb, owner)
			amountHealed = amountHealed + data.heal
		end

		self.modeValues[1] = math.max((self.modeValues[1] or 0) - totalCost, 0)

		if amountHealed > 0 then org.painHabit = 1 end

		if #wrapped > 0 then
			ent.bandaged_limbs = ent.bandaged_limbs or {}
			for _, boneName in ipairs(wrapped) do
				wrapGreen(ent, boneName, applied)
			end

			ent:SetNetVar("bandaged_limbs", ent.bandaged_limbs)
			if IsValid(ent.FakeRagdoll) then
				ent.FakeRagdoll:SetNetVar("bandaged_limbs", ent.bandaged_limbs)
			end
			if ent:IsRagdoll() and hg.RagdollOwner(ent) and hg.RagdollOwner(ent):Alive() then
				hg.RagdollOwner(ent):SetNetVar("bandaged_limbs", ent.bandaged_limbs)
			end
		end

		if not hg.SimpleHealth.GetState(org) then
			local analgesiaAdd = math.Clamp(amountHealed * 0.65, 0.35, 0.8)
			org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + analgesiaAdd, 4)
		end

		owner:EmitSound("snd_jack_hmcd_bandage.ogg", 60, math.random(95, 105))

		if (self.modeValues[1] <= 0) and self.ShouldDeleteOnFullUse then
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
		end

		return true
	end
end
