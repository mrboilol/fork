if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"
SWEP.BandageTPIK = false
SWEP.PrintName = "Splint"
SWEP.Instructions = "Apply to a broken arm or leg to set the fracture, or brace a cracked neck or back. A splinted bone heals faster. LMB to use on yourself, RMB to use on someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/props/splint.mdl"

hg.SPLINT_LIMB_BONES = {
	larm = "ValveBiped.Bip01_L_Forearm",
	rarm = "ValveBiped.Bip01_R_Forearm",
	lleg = "ValveBiped.Bip01_L_Calf",
	rleg = "ValveBiped.Bip01_R_Calf",
}

hg.SPLINT_LIMB_LABELS = {
	larm = "left arm",
	rarm = "right arm",
	lleg = "left leg",
	rleg = "right leg",
	spine2 = "back",
	spine3 = "neck",
}

local splintLimbOrder = {"lleg", "rleg", "larm", "rarm"}

local function GetSplintState(ent)
	if not IsValid(ent) then return {} end
	if istable(ent.splints) then return ent.splints end
	return ent.GetNetVar and ent:GetNetVar("Splints", {}) or {}
end

function hg.IsLimbSplinted(ent, limb)
	local bone = hg.SPLINT_LIMB_BONES[limb]
	if not bone then return false end
	return table.HasValue(GetSplintState(ent), bone)
end

if SERVER then
	util.AddNetworkString("splint_anim_broadcast")
end

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_medical_splint")
	SWEP.IconOverride = "vgui/wep_medical_splint.png"
	SWEP.BounceWeaponIcon = false

	local splintAnims = {}

	net.Receive("splint_anim_broadcast", function()
		local ply = net.ReadEntity()
		local dur = net.ReadFloat()
		if IsValid(ply) then
			splintAnims[ply:EntIndex()] = { start = CurTime(), dur = dur }
		end
	end)

	function hg.GetSplintAnimProgress(ply)
		local data = splintAnims[ply:EntIndex()]
		if not data then return 0 end
		local elapsed = CurTime() - data.start
		if elapsed > data.dur then
			splintAnims[ply:EntIndex()] = nil
			return 0
		end
		return math.sin((elapsed / data.dur) * math.pi)
	end

	local splintBoneModel = {
		["ValveBiped.Bip01_L_Forearm"] = "models/props/splint_use_arm.mdl",
		["ValveBiped.Bip01_R_Forearm"] = "models/props/splint_use_arm.mdl",
		["ValveBiped.Bip01_L_Calf"]    = "models/props/splint_use_leg.mdl",
		["ValveBiped.Bip01_R_Calf"]    = "models/props/splint_use_leg.mdl",
	}

	local splintBoneOffset = {
		["ValveBiped.Bip01_L_Forearm"] = { Vector(11.5, 0.5, -0.5), Angle(90,  0, -87) },
		["ValveBiped.Bip01_R_Forearm"] = { Vector(11.5, 0.5, 0.5), Angle(90,  0, -87) },
		["ValveBiped.Bip01_L_Calf"]    = { Vector(18.3, 1.69, -0.5), Angle(90, 2.6, -87) },
		["ValveBiped.Bip01_R_Calf"]    = { Vector(18, 1.6, 0.5), Angle(90, 2.6, -87) },
	}

	local splintBoneScale = {
		["ValveBiped.Bip01_L_Forearm"] = 3.5,
		["ValveBiped.Bip01_R_Forearm"] = 3.5,
		["ValveBiped.Bip01_L_Calf"]    = 3.6,
		["ValveBiped.Bip01_R_Calf"]    = 3.6,
	}

	local function RemoveSplintModels(ent)
		if not ent.splintModels then return end
		for i, mdl in pairs(ent.splintModels) do
			if IsValid(mdl) then mdl:Remove() end
			ent.splintModels[i] = nil
		end
	end

	hook.Add("OnNetVarSet", "splint_render_netvar", function(index, key, var)
		if key ~= "Splints" then return end
		local ent = Entity(index)
		if not IsValid(ent) then return end
		RemoveSplintModels(ent)
		ent.splints = var
		ent:CallOnRemove("splint_render_remove", function()
			RemoveSplintModels(ent)
		end)
	end)

	hook.Add("Player_Death", "splint_render_death_cl", function(ply)
		RemoveSplintModels(ply)
	end)

	hook.Add("Fake", "splint_render_fake_cl", function(ply, ragdoll)
		RemoveSplintModels(ply)
	end)

	function hg.RenderSplints(ent, ply)
		local splints = ply.splints
		if not splints or not next(splints) then return end

		ply.splintModels = ply.splintModels or {}

		for i, boneName in ipairs(splints) do
			local mdlPath = splintBoneModel[boneName]
			if not mdlPath then continue end

			if IsValid(ply.splintModels[i]) and ply.splintModels[i].boneName ~= boneName then
				ply.splintModels[i]:Remove()
				ply.splintModels[i] = nil
			end

			if not IsValid(ply.splintModels[i]) then
				ply.splintModels[i] = ClientsideModel(mdlPath)
				ply.splintModels[i]:SetNoDraw(true)
				ply.splintModels[i].boneName = boneName
			end

			local model = ply.splintModels[i]

			local boneIdx = ent:LookupBone(boneName)
			if not boneIdx then continue end

			local matrix = ent:GetBoneMatrix(boneIdx)
			if not matrix then continue end

			local offData = splintBoneOffset[boneName]
			local pos, ang = LocalToWorld(offData[1], offData[2], matrix:GetTranslation(), matrix:GetAngles())
			model:SetRenderOrigin(pos)
			model:SetRenderAngles(ang)
			model:SetModelScale(splintBoneScale[boneName] or 1.0)
			model:SetupBones()
			model:DrawModel()
		end
	end
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 3
SWEP.SlotPos = 2
SWEP.WorkWithFake = true

SWEP.offsetVec = Vector(3.5, -2, -1)
SWEP.offsetAng = Angle(0, 90, 155)

SWEP.DeploySnd = "physics/body/body_medium_impact_soft5.wav"
SWEP.FallSnd = "physics/body/body_medium_impact_soft5.wav"
SWEP.HolsterSnd = ""

SWEP.ShouldDeleteOnFullUse = true
SWEP.showstats = true

SWEP.modeNames = {
	[1] = "splint"
}

SWEP.modeValuesdef = {
	[1] = {1, true},
}

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)
	self.modeValues = {
		[1] = 1
	}
end

local lang1, lang2 = Angle(0, -10, 0), Angle(0, 10, 0)

function SWEP:Animation()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	if (owner.zmanipstart ~= nil and not owner.organism.larmamputated) then return end

	local aimvec = owner:GetAimVector()
	if not aimvec then return end

	local hold = self:GetHolding()
	local wave = CLIENT and hg.GetSplintAnimProgress and hg.GetSplintAnimProgress(owner) or 0

	self:BoneSet("r_upperarm", vector_origin, Angle(30 + 10 * aimvec[3] + wave * 35, (-50 - hold) + 10 * aimvec[3] * -2 + hold / 2 - wave * 30, 10 - hold / 3))
	self:BoneSet("r_forearm", vector_origin, Angle(-10 + wave * 60, -hold - wave * 20, -hold))
	self:BoneSet("l_upperarm", vector_origin, Angle(lang1.p + wave * 30, lang1.y - wave * 20, lang1.r))
	self:BoneSet("l_forearm", vector_origin, Angle(lang2.p + wave * 20, lang2.y, lang2.r))
end

function SWEP:Think()
	self:SetHold(self.HoldType)
end

function SWEP:IsSplintMode()
	return true
end

function SWEP:CanBandageTPIK(target)
	return (self.modeValues and self.modeValues[1] or 0) > 0 and IsValid(target) and hg.GetSplintTarget(target) ~= nil
end

local function GetSplintHolder(ent)
	local org = ent.organism
	return org and IsValid(org.owner) and org.owner or ent
end

local function SyncSplints(holder)
	holder.splints = holder.splints or {}
	holder:SetNetVar("Splints", holder.splints)
	if IsValid(holder.FakeRagdoll) then
		holder.FakeRagdoll.splints = table.Copy(holder.splints)
		holder.FakeRagdoll:SetNetVar("Splints", holder.FakeRagdoll.splints)
	end
end

local function LimbFromBone(bone)
	if not isstring(bone) then return end
	local side = string.find(bone, "_L_", 1, true) and "l" or string.find(bone, "_R_", 1, true) and "r"
	if not side then return end
	if string.find(bone, "Thigh", 1, true) or string.find(bone, "Calf", 1, true) or string.find(bone, "Foot", 1, true) then
		return side .. "leg"
	end
	if string.find(bone, "Arm", 1, true) or string.find(bone, "Hand", 1, true) then
		return side .. "arm"
	end
end

local function NeedsSplint(holder, org, limb)
	return not org[limb .. "amputated"] and hg.IsLimbFractured(org, limb) and not hg.IsLimbSplinted(holder, limb)
end

local function SpineFromBone(bone)
	if not isstring(bone) then return end
	if string.find(bone, "Neck", 1, true) or string.find(bone, "Head", 1, true) then return "spine3" end
	if string.find(bone, "Spine", 1, true) then return "spine2" end
end

local function NeedsSpineSplint(org, key)
	return hg.IsSpinePartiallyBroken and hg.IsSpinePartiallyBroken(org, key) and not org[key .. "splinted"]
end

function hg.GetSplintTarget(ent, bone)
	local org = ent.organism
	if not org then return end
	local holder = GetSplintHolder(ent)

	local aimed = LimbFromBone(bone)
	if aimed and NeedsSplint(holder, org, aimed) then return aimed end

	local aimedSpine = SpineFromBone(bone)
	if aimedSpine and NeedsSpineSplint(org, aimedSpine) then return aimedSpine end
	for _, key in ipairs({"spine3", "spine2"}) do
		if NeedsSpineSplint(org, key) then return key end
	end

	local best, bestDamage
	for _, limb in ipairs(splintLimbOrder) do
		if NeedsSplint(holder, org, limb) then
			local damage = tonumber(org[limb]) or 0
			if not best or damage > bestDamage then best, bestDamage = limb, damage end
		end
	end
	return best
end

if SERVER then
	function hg.ApplySplint(user, ent, bone)
		local org = ent.organism
		if not org then return false end

		local limb = hg.GetSplintTarget(ent, bone)
		if not limb then
			if IsValid(user) and user:IsPlayer() then
				user:Notify("No unsplinted fractures to treat.", true, "splint_nofrac", 0)
			end
			return false
		end

		local holder = GetSplintHolder(ent)
		if hg.SPLINT_LIMB_BONES[limb] then
			hg.organism.ApplyBandageBoneTreatment(org, limb, 0.25)
			holder.splints = holder.splints or {}
			table.insert(holder.splints, hg.SPLINT_LIMB_BONES[limb])
			SyncSplints(holder)
		else
			hg.organism.StabilizeSpine(org, limb, 0.35, true)
		end
		org.avgpain = math.max((org.avgpain or 0) - 5, 0)
		org.pain = math.max((org.pain or 0) - 5, 0)

		local label = hg.SPLINT_LIMB_LABELS[limb]
		if IsValid(holder) and holder:IsPlayer() then
			if holder == user then
				holder:Notify("You splint your " .. label .. ".", true, "splint_apply", 0)
			else
				holder:Notify("Someone splints your " .. label .. ".", true, "splint_apply", 0)
			end
		end
		if IsValid(user) and user:IsPlayer() and user ~= holder then
			user:Notify("You splint their " .. label .. ".", true, "splint_apply_other", 0)
		end

		if IsValid(user) then
			local soundEnt = IsValid(user.FakeRagdoll) and user.FakeRagdoll or user
			soundEnt:EmitSound("splint/item_splint_01.wav", 65, math.random(90, 110))

			if user:IsPlayer() then
				local animTime = SoundDuration("splint/item_splint_01.wav")
				if not animTime or animTime <= 0 then animTime = 3 end
				net.Start("splint_anim_broadcast")
					net.WriteEntity(user)
					net.WriteFloat(math.min(animTime, 3))
				net.Broadcast()
			end
		end

		return true
	end

	function SWEP:Heal(ent, mode, bone)
		if ent:IsNPC() then return end
		if not ent.organism then return end
		if (self.modeValues[1] or 0) <= 0 then return end

		local owner = self:GetOwner()
		if not hg.ApplySplint(owner, ent, bone) then return end

		self.modeValues[1] = self.modeValues[1] - 1
		self:SetNetVar("modeValues", self.modeValues)

		if self.modeValues[1] <= 0 and self.ShouldDeleteOnFullUse then
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
		end

		return true
	end

	hook.Add("Org Think", "splint_remove_on_heal", function(owner, org)
		if not IsValid(owner) or not istable(owner.splints) or not next(owner.splints) then return end

		local changed
		for i = #owner.splints, 1, -1 do
			for limb, limbBone in pairs(hg.SPLINT_LIMB_BONES) do
				if owner.splints[i] == limbBone and ((tonumber(org[limb]) or 0) < 0.05 or org[limb .. "amputated"]) then
					table.remove(owner.splints, i)
					changed = true
					break
				end
			end
		end
		if changed then SyncSplints(owner) end
	end)

	hook.Add("Player Spawn", "splint_render_clear_spawn", function(ply)
		if OverrideSpawn then return end
		ply.splints = {}
		ply:SetNetVar("Splints", {})
	end)

	hook.Add("Org Clear", "splint_clear_on_reset", function(org)
		local ent = org and org.owner
		if not IsValid(ent) or not istable(ent.splints) or not next(ent.splints) then return end
		ent.splints = {}
		SyncSplints(ent)
	end)

	hook.Add("Player_Death", "splint_render_death", function(ply)
		if IsValid(ply.FakeRagdoll) then
			ply.FakeRagdoll.splints = table.Copy(ply.splints or {})
			ply.FakeRagdoll:SetNetVar("Splints", ply.FakeRagdoll.splints)
		end
		ply.splints = {}
		ply:SetNetVar("Splints", {})
	end)

	hook.Add("Fake", "splint_render_fake_sv", function(ply, ragdoll)
		if not IsValid(ragdoll) then return end
		ragdoll.splints = table.Copy(ply.splints or {})
		ply:SetNetVar("Splints", ply.splints or {})
		ragdoll:SetNetVar("Splints", ragdoll.splints)
	end)
end
