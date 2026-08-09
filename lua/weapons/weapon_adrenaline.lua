if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Epinephrine Autoinjector"
SWEP.Instructions = "Adrenaline, also known as epinephrine, is a hormone and medication which is involved in regulating visceral functions. Use this to increase blood pressure and/or stop cardiac arrest. RMB to inject into someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/upgrades/phy_optic_eotech.mdl"
SWEP.Model = "models/weapons/w_models/w_jyringe_jroj.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_adrenaline")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_adrenaline.vmt"
	SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(5, -1.5, -2.5)
SWEP.offsetAng = Angle(90, 00, -90)
SWEP.modeNames = {
	[1] = "adrenaline"
}

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	self.modeValues = {
		[1] = 1
	}
end

SWEP.modeValuesdef = {
	[1] = 1
}

SWEP.DeploySnd = ""
SWEP.HolsterSnd = ""

SWEP.showstats = false

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

function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	if not self.healing and anim == "deploy" and self.animtime and self.animtime <= curTime then
		if SERVER then
			self:PlayAnim("idle")
		end
	end

	if self.healing and not self._animStarted then
		local buttonHeld = owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2)
		if buttonHeld and self.modeValues[1] > 0 then
			self._animStarted = true
			if SERVER then
				self:PlayAnim("use", self.UseSpeed, false, nil, false)
			end
		elseif not buttonHeld then
			self.healing = false
			self:SetHealingOther(false)
			self.setlh = true
		end
	end

	if self.healing and not owner:KeyDown(IN_ATTACK) and not owner:KeyDown(IN_ATTACK2) then
		self.healing = false
		self:SetHealingOther(false)
		self.setlh = true
		self._animStarted = false
		self.callback = nil
		hook.Remove("Think", "AnimCallback" .. self:EntIndex())
		if SERVER then
			if self.modeValues[1] > 0 then
				self:ReverseAnimToIdle("use")
			else
				self:PlayAnim("idle")
			end
		end
	end

	self:ThinkReverseAnimToIdle(curTime)
end

function SWEP:SetHandPos(noset)
	if self:GetHealingOther() then
		self.setlh = false
	else
		self.setlh = true
	end

	return self.BaseClass.SetHandPos(self, noset)
end

function SWEP:PostSetHandPos()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local ent = hg.GetCurrentCharacter(ply)
	if not IsValid(ent) then return end

	local rhBone = ent:LookupBone("ValveBiped.Bip01_R_Hand")
	if rhBone then
		local mat = ent:GetBoneMatrix(rhBone)
		if mat then
			local pos = mat:GetTranslation() + self.handPosOffset
			local ang = mat:GetAngles()
			ang.p = ang.p + self.handAngOffset.p
			ang.y = ang.y + self.handAngOffset.y
			ang.r = ang.r + self.handAngOffset.r
			mat:SetTranslation(pos)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(rhBone, mat)
		end
	end

	if not self.lhandik then return end

	local lhBone = ent:LookupBone("ValveBiped.Bip01_L_Hand")
	if lhBone then
		local mat = ent:GetBoneMatrix(lhBone)
		if mat then
			local pos = mat:GetTranslation()
			local offset = self.handPosOffset
			pos.x = pos.x - offset.x
			pos.y = pos.y - offset.y
			pos.z = pos.z + offset.z
			local ang = mat:GetAngles()
			ang.p = ang.p - self.handAngOffset.p
			ang.y = ang.y - self.handAngOffset.y
			ang.r = ang.r + self.handAngOffset.r
			mat:SetTranslation(pos)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(lhBone, mat)
		end
	end
end

if SERVER then
	function SWEP:Heal(ent, mode)
		if ent:IsNPC() then
			self:SpawnGarbage("models/bloocobalt/l4d/items/w_eq_adrenaline.mdl", nil, nil, nil, "2211")
			self:NPCHeal(ent, 0.1, "snd_jack_hmcd_needleprick.ogg")
		end

		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))

			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(org.owner.FakeRagdoll) and org.owner.FakeRagdoll or org.owner
		entOwner:EmitSound("snd_jack_hmcd_needleprick.ogg", 60, math.random(95, 105))
		org.adrenalineAdd = math.Approach(org.adrenalineAdd, 4, self.modeValues[1] * 4)
		-- The injector has to act before the normal adrenalineAdd-to-adrenaline
		-- conversion finishes, otherwise it cannot help a current cardiac arrest.
		org.adrenaline = math.max(org.adrenaline or 0, 1.5)
		org._adrenalineHoldUntil = math.max(org._adrenalineHoldUntil or 0, CurTime() + 4)
		-- Keep the dose's circulatory support separate from the adrenaline decay
		-- curve so a single injector consistently stabilizes a viable patient.
		org.epinephrineStabilizationUntil = math.max(org.epinephrineStabilizationUntil or 0, CurTime() + 12)
		-- Epinephrine alone stabilizes circulation; a recent AED application or
		-- active CPR is required before it can contribute to a restart attempt.
		org.epinephrineResuscitationUntil = math.max(org.epinephrineResuscitationUntil or 0, CurTime() + 15)
		if hg.organism and hg.organism.TryRestartHeartWithResuscitation then
			hg.organism.TryRestartHeartWithResuscitation(org)
		end
		org.palpitationTreatmentUntil = math.max(org.palpitationTreatmentUntil or 0, CurTime() + 8)
		if hg.organism and hg.organism.RestoreSupportedOxygen then
			hg.organism.RestoreSupportedOxygen(org, 0.35, {
				oxygen = 12, oxygenTarget = 22,
				bodyoxygen = 0.5, bodyoxygenTarget = 0.8,
				brainoxygen = 0.5, brainoxygenTarget = 0.8,
				perfusion = 0.45, perfusionTarget = 0.75,
				peripheralperfusion = 0.4, peripheralperfusionTarget = 0.7,
				cerebralPerfusion = 0.45, cerebralPerfusionTarget = 0.75,
				myocardialOxygen = 0.55, myocardialOxygenTarget = 0.85,
				hypoxiaTime = 3, severeHypoxiaTime = 0, systemicIschemiaTime = 4
			})
		end
		self:RefreshPerfusionTreatment(ent, 0.2)

		if self.poisoned2 then
			org.poison4 = CurTime()

			self.poisoned2 = nil
		end

		if self.modeValues[1] > 0 then
			self.modeValues[1] = 0
			owner:SelectWeapon("weapon_hands_sh")
			--!! self:SpawnGarbage() add this when port dayz models
			self:Remove()
		end
	end
end
