if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "'Uber' Norepinephrine"
SWEP.Instructions = "An experimental combat stimulant refined from early Fury-13 samples with uncertain origin, nicknamed as 'Fury-16'.\n\nInstead of modifying your body, it forces it to burn through every resource for a massive speed boost. Functions by flooding the system with synthetic noradrenaline, inducing extreme vasoconstriction and cardiac output."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_adrenaline.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("entities/zcity/fury16.png")
	SWEP.IconOverride = "entities/zcity/fury16.png"
	SWEP.BounceWeaponIcon = false
end
SWEP.AdminOnly = true
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(3, -2.5, -1)
SWEP.offsetAng = Angle(-30, 20, -90)
SWEP.ModelScale = 0.75
SWEP.Color = Color(0, 90, 255)
SWEP.modeNames = {
	[1] = "fury-13"
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

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Heal animation type: 0 = progressive minigames, 1 = Judge animations, 2 = progressive Judge minigames", 0, 2)

function SWEP:Think()
	self:SetBodyGroups("11")
	if not self:GetOwner():KeyDown(IN_ATTACK) and hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 4, 0))
	end
end

function SWEP:Animation()
	local hold = self:GetHolding()
    self:BoneSet("r_upperarm", vector_origin, Angle(0, -hold + (100 * (hold / 100)), 0))
    self:BoneSet("r_forearm", vector_origin, Angle(-hold / 6, -hold * 2, -15))
end

function SWEP:NPCHeal(npc, mul, snd)
	if not npc then npc = self:GetOwner() end

	if npc:IsNPC() then
		self:SetHold("melee")
		if not mul then mul = 0.3 end
		npc:SetHealth(math.Clamp(npc:Health() + (npc:GetMaxHealth() * 1 * mul), 0, npc:GetMaxHealth() * math.Clamp(2 * mul, 2, 100)))
		npc:EmitSound(snd or "snd_jack_hmcd_needleprick.ogg", 80, math.random(95, 105))
		npc:SetPlaybackRate(6)
		npc:SetKeyValue("m_flPlaybackSpeed", 6)

		if SERVER then
			self:Remove()
		end
	end
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
			self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
			self:NPCHeal(ent, 20, "snd_jack_hmcd_needleprick.ogg")
		end

		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))

			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		entOwner:EmitSound("snd_jack_hmcd_needleprick.ogg", 80, math.random(115, 120))

		if org.berserk >= 0.4 then
			hg.ExplodeHead(ent)
		end

		org.noradrenaline = org.noradrenaline + 1.25

		self.modeValues[1] = 0

		if self.poisoned2 then
			org.poison4 = CurTime()

			self.poisoned2 = nil
		end

		if self.modeValues[1] == 0 then
			owner:SelectWeapon("weapon_hands_sh")
			self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
			self:Remove()
		end
	end
end
