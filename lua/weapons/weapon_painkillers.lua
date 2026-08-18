if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Painkillers"
SWEP.Instructions = "Can be used to relieve pain (thanks Mr. Obvious). RMB to use on someone else."
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
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(2.5, -2.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modeNames = {
	[1] = "painkiller"
}
local painkillerTypes = {
	paracetamol = {
		name = "Paracetamol", dose = 1,
		description = "Paracetamol is a OTC medication that tends to alleviate acute and chronic pain. It is classified as a NSAID and is generally safe to take in moderate amounts.",
		appearance = "This one is a white, thick pill that leaves dust around.",
	},
	tramadol = {
		name = "Tramadol", dose = 0.4,
		description = "Tramadol is a prescription only medication that is prescribed when non-opioid options seem inadequate. It is a moderate schedule IV opioid that might cause respiratory depression on excess use.",
		appearance = "This one has a off-white color to it, and is a small pill.",
	},
	tapentadol = {
		name = "Tapentadol", dose = 0.8,
		description = "Tapentadol is a prescription only medication that is used for severe acute pain, this is used for certain nerve pain or when a opioid-level medication is required/prescribed. It is a strong schedule II opioid that might cause a risk in overdosing or respiratory depression. Do not take more than one.",
		appearance = "This one has a off white color to it, and is a small pill. It also feels very brittle.",
	},
}
local painkillerTypeOrder = {"paracetamol", "tramadol", "tapentadol"}

function SWEP:RandomizePainkillerType()
	if not SERVER then return end

	local medicineID = painkillerTypeOrder[math.random(#painkillerTypeOrder)]
	local medicine = painkillerTypes[medicineID]
	self:SetNWString("hg_painkiller_type", medicineID)
	self:SetNWString("hg_painkiller_label", medicine.name)
	self:SetNWString("hg_painkiller_detail", medicine.description .. "\n" .. medicine.appearance)
end


function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)
	self.modeValues = {[1] = 1}
	if not SERVER then return end

	self:RandomizePainkillerType()
end
SWEP.modeValuesdef = {
	[1] = 1,
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

	if CLIENT then
		local label = self:GetNWString("hg_painkiller_label", "Painkillers")
		local detail = self:GetNWString("hg_painkiller_detail", "")
		local displayKey = label .. "\n" .. detail
		if self.hg_painkiller_display_key ~= displayKey then
			self.hg_painkiller_display_key = displayKey
			self.PrintName = label
			self.HudHintMarkup = markup.Parse("<font=ZCity_Tiny>" .. label .. "</font>\n<font=ZCity_SuperTiny><colour=125,125,125>" .. detail .. "</colour></font>\n" .. self.HowToUseInstructions, 450)
		end
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
		self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
		self:NPCHeal(owner, 0.2, "snd_jack_hmcd_pillsuse.ogg")
	end
end

if SERVER then
	function SWEP:Heal(ent, mode)
		if ent:IsNPC() then
			self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
			self:NPCHeal(ent, 0.2, "snd_jack_hmcd_pillsuse.ogg")
		end

		local org = ent.organism
		if not org then return end
		if !org.analgesiaAdd or !self.modeValues or !self.modeValues[1] then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and not hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))

			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		entOwner:EmitSound("snd_jack_hmcd_pillsuse.ogg", 60, math.random(95, 105))

		local lacedAmount = self.HG_FentanylLacedAmount or 0
		if lacedAmount > 0 then
			org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + lacedAmount, 25)
			self.HG_FentanylLacedAmount = nil
		end
		local medicineID = self:GetNWString("hg_painkiller_type", "paracetamol")
		local medicine = painkillerTypes[medicineID] or painkillerTypes.paracetamol
		if medicineID == "paracetamol" then
			org.painkiller = math.min((org.painkiller or 0) + medicine.dose, 5)
		else
			org.analgesiaAdd = math.min(org.analgesiaAdd + medicine.dose, 4)
		end

		if self.modeValues[1] > 0 then
			self.modeValues[1] = 0
			owner:SelectWeapon("weapon_hands_sh")
			self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
			self:Remove()
		end
		
		return true
	end
end
