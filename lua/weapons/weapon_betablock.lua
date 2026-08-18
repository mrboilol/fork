if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Beta-Blocker"
SWEP.Instructions = "Beta blockers can help in stressful situations, will reduce your panic and adrenaline. Very useful in combat at certain doses. RMB to inject into someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_painpills")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_painpills.vmt"
    SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(2.5, -2.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modeNames = {
    [1] = "beta-blocker"
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

SWEP.DeploySnd = "snd_jack_hmcd_pillsbounce.ogg"
SWEP.FallSnd = "snd_jack_hmcd_pillsbounce.ogg"

SWEP.showstats = false

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)

function SWEP:Think()
	self:SetBodyGroups("111")
	if not self:GetOwner():KeyDown(IN_ATTACK) and not hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 4, 0))
	end
end

local lang1, lang2 = Angle(0, -10, 0), Angle(0, 10, 0)
function SWEP:Animation()
	local owner = self:GetOwner()
	if (owner.zmanipstart ~= nil and not owner.organism.larmamputated) then return end

	local aimvec = owner:GetAimVector()
	if not aimvec then return end

	local hold = self:GetHolding()

	if owner:IsFlagSet(FL_DUCKING) or owner:GetVelocity():LengthSqr() >= 17000 then
		aimvec[3] = -2
		hold = hold / 2
	end

	local ducking = owner:IsFlagSet(FL_ANIMDUCKING)

    self:BoneSet("r_upperarm", vector_origin, Angle(30 + 10 * aimvec[3], (-50 - hold) + 10 * aimvec[3] * (ducking and -4 or -2) + hold / 2, 10 - hold / 3))
    self:BoneSet("r_forearm", vector_origin, Angle(-10, -hold, -hold))

    self:BoneSet("l_upperarm", vector_origin, lang1)
    self:BoneSet("l_forearm", vector_origin, lang2)
end

function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if IsValid(owner) and owner:IsNPC() then
		self:NPCHeal(owner, 0.1, "snd_jack_hmcd_pillsuse.ogg")
	end
end

if SERVER then
	function SWEP:Heal(ent, mode)
		if ent:IsNPC() then
			self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
			self:NPCHeal(ent, 0.1, "snd_jack_hmcd_pillsuse.ogg")
		end

        local org = ent.organism
        if not org then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and not hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))

			if self:GetHolding() < 100 then return end
		end

        local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
        entOwner:EmitSound("snd_jack_hmcd_pillsuse.ogg", 60, math.random(95, 105))

        org.adrenalineAdd = math.Approach(org.adrenalineAdd, -4, self.modeValues[1] * 2)
		org.panicattackadd = 0
		org.panicattack = 0
		org.panicattackActive = false
		org.nextPanicHeartRoll = CurTime() + 15
		org.adrenalineAdd = math.Approach(org.adrenalineAdd, -8, self.modeValues[1] * 2)
		org.adrenaline = math.Approach(org.adrenaline, 0, self.modeValues[1] * 0.5)
        
		-- Beta blockers stop the acute panic response.
        -- Beta blockers provide mild analgesic effect
        org.analgesiaAdd = (org.analgesiaAdd or 0) + 0.15

		self.modeValues[1] = 0
		owner:SelectWeapon("weapon_hands_sh")
		self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
		self:Remove()
	end
end
