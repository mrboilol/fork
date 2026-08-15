if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Fentanyl"
SWEP.Instructions = "Fentanyl is a highly potent synthetic piperidine opioid primarily used as an analgesic. Fentanyl dose must be strictly observed, as it can quickly lead to opiate overdose. Label says that ~20% is a maximum daily dose. RMB to inject into someone else. Press R while looking at dropped food, painkillers, or morphine to lace it with half the tube."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/morphine_syrette/morphine.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/icons/ico_fent.png")
	SWEP.IconOverride = "vgui/icons/ico_fent.png"
	SWEP.BounceWeaponIcon = false
end
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(8, -1.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modeNames = {
	[1] = "analgesic"
}

SWEP.UseSpeed = 3
SWEP.CallbackTimeAdjust = 0.5
SWEP.AnalgesiaPerDose = 6
SWEP.MaxAnalgesia = 6

SWEP.AnimList = {
	["deploy"] = { "deploy", 0.5, false },
	["use"] = { "use", 3, true },
	["idle"] = { "idle", 5, true }
}

SWEP.TimedSoundsSelf = {
	{"weapons/universal/uni_crawl_l_02.wav", 0.3},
	{"snd_jack_hmcd_needleprick.wav", 0.8},
	{"cof/weapons/syringe/syringe_insert.wav", 1.0},
}

SWEP.TimedSoundsOther = {
	{"cof/weapons/syringe/syringe_insert.wav", 0.5},
}

SWEP.modeValuesdef = {
	[1] = {1, true},
}
SWEP.ShouldDeleteOnFullUse = false

SWEP.showstats = true

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

function SWEP:Think()
	if not self:GetOwner():KeyDown(IN_ATTACK) and hg_healanims:GetBool() then
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

function SWEP:Reload()
	if not SERVER or not self:GetOwner():KeyPressed(IN_RELOAD) then return end
	if not self.modeValues or (self.modeValues[1] or 0) < 0.5 then return end

	local owner = self:GetOwner()
	local trace = owner:GetEyeTrace()
	local target = trace.Entity
	if not IsValid(target) or target:GetPos():DistToSqr(owner:GetPos()) > 14400 then return end

	local validTargets = {
		weapon_bigconsumable = true,
		weapon_smallconsumable = true,
		weapon_painkillers = true,
		weapon_morphine = true,
	}
	if not validTargets[target:GetClass()] or (target.HG_FentanylLacedAmount or 0) > 0 then return end

	self.modeValues[1] = math.max(self.modeValues[1] - 0.5, 0)
	self:SetRemainingAmount(self.modeValues[1])
	target.HG_FentanylLacedAmount = 3
	owner:EmitSound("pshiksnd", 60, math.random(95, 105))
	owner:ChatPrint("You laced the item with fentanyl.")
end
function SWEP:Animation()
	local hold = self:GetHolding()
    self:BoneSet("r_upperarm", vector_origin, Angle(0, -hold + (100 * (hold / 100)), 0))
    self:BoneSet("r_forearm", vector_origin, Angle(-hold / 6, -hold * 2, -15))
end

function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if IsValid(owner) and owner:IsNPC() then
		self:SpawnGarbage()
		self:NPCHeal(owner, 0.4, "snd_jack_hmcd_needleprick.ogg")
	end
end

	if self.healing and not owner:KeyDown(IN_ATTACK) and not owner:KeyDown(IN_ATTACK2) then
		self.healing = false
		self:SetHealingOther(false)
		self.setlh = true
		self._injectStartTime = nil
		self._slowed = false
		self._animStarted = false
		self.callback = nil
		hook.Remove("Think", "AnimCallback" .. self:EntIndex())
		if SERVER then
			if self.modeValues[1] > 0 then
				self.reverseanim = true
			else
				self:PlayAnim("idle")
			end
		end
		if CLIENT then
			if self.modeValues[1] > 0 then
				self.reverseanim = true
			end
		end
	end

	if self.healing and self._injectStartTime then
		local timeSinceStart = curTime - self._injectStartTime

		if timeSinceStart >= 1 then
			if not self._slowed then
				self._slowed = true
				if SERVER then
					self.animspeed = self.animspeed * 2
					self.animtime = curTime + (self.animtime - curTime) * 2
				end
			end

			local ent = self:GetHealingOther() and IsValid(self.healbuddy) and self.healbuddy or owner
			local org = ent.organism
			if org and self.modeValues[1] > 0 then
				local injected = math.min(FrameTime() * 1, self.modeValues[1])
				org.analgesiaAdd = math.min(org.analgesiaAdd + injected * self.AnalgesiaPerDose, self.MaxAnalgesia)
				self.modeValues[1] = math.max(self.modeValues[1] - injected, 0)
				self:SetDose(self.modeValues[1])

		owner.injectedinto = owner.injectedinto or {}
		owner.injectedinto[org.owner] = owner.injectedinto[org.owner] or 0
		owner.injectedinto[org.owner] = owner.injectedinto[org.owner] + injected

		if owner.injectedinto[org.owner] > 1 and injected > 0 then
			local dmgInfo = DamageInfo()
			dmgInfo:SetAttacker(owner)
			hook.Run("HomigradDamage", org.owner, dmgInfo, HITGROUP_RIGHTARM, hg.GetCurrentCharacter(org.owner), injected * (zb.MaximumHarm or 10))
		end

		if self.poisoned2 then
			org.poison4 = CurTime()

			self.poisoned2 = nil
		end

		-- Sync remaining amount to client
		self:SetRemainingAmount(self.modeValues[1])
		
		if self.modeValues[1] != 0 then
			entOwner:EmitSound("pshiksnd")
		else
			-- No deletion - syringe stays even when empty
			-- owner:SelectWeapon("weapon_hands_sh")
			-- self:Remove()
		end
	end
end