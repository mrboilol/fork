if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "horse tranq"
SWEP.Instructions = "The label reads etorphine or whatever that means, its a very watered down version of horse tranq intended for use in, well, horses however a small dose can very much kill humans. Label says a quarter of the vial is enough to sedate horses."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/morphine_syrette/morphine.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/icons/ico_tranq.png")
	SWEP.IconOverride = "vgui/icons/ico_tranq.png"
	SWEP.BounceWeaponIcon = false
end
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -1.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modeNames = {
	[1] = "tranq"
}

SWEP.DeploySnd = ""
SWEP.HolsterSnd = ""

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	self.modeValues = {
		[1] = 1,
	}
end

SWEP.ofsV = Vector(0,8,-3)
SWEP.ofsA = Angle(-90,-90,90)
SWEP.modeValuesdef = {
	[1] = {1, true},
}

SWEP.showstats = true

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
	if IsValid(owner) and owner:IsNPC() then
		self:SpawnGarbage()
		self:NPCHeal(owner, 0.4, "snd_jack_hmcd_needleprick.wav")
	end
end

if SERVER then
	function SWEP:Heal(ent, mode)
		if ent:IsNPC() then
			self:SpawnGarbage()
			self:NPCHeal(ent, 0.4, "snd_jack_hmcd_needleprick.wav")
		end

		local org = ent.organism
		if not org then return end

		if self.modeValues[1] <= 0 then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
			self:SetHolding(math.Clamp(self:GetHolding() + 100, 0, 50))

			--if self:GetHolding() < 100 then return end
		end
		
		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner

		local injected = math.min(FrameTime() * 1, self.modeValues[1])
		
		-- 5% (0.05) of dose gives 1.0 analgesia. 1 / 0.05 = 20
		org.analgesia = math.min(org.analgesia + injected * 20, 20) 

		-- 10% (0.1) of dose gives 0.5 tranquilizer. 0.5 / 0.1 = 5
		org.tranquilizer = math.min(org.tranquilizer + injected * 12.5, 12.5)

		self.modeValues[1] = math.max(self.modeValues[1] - injected, 0)

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

		if self.modeValues[1] != 0 then
			entOwner:EmitSound("pshiksnd")
		else
			--//owner:SelectWeapon("weapon_hands_sh")
			--//self:Remove()
		end
	end
end
