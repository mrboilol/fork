if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bigconsumable"
SWEP.PrintName = "Small consumable"
SWEP.Instructions = "A snack is always useful, regardless of the situation. Having a snack and waiting and regaining your well-being."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/jordfood/canned_burger.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_fooddrink")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_fooddrink.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -2, -1)
SWEP.offsetAng = Angle(180, 0, 0)
SWEP.showstats = false

SWEP.ofsV = Vector(-2,-10,8)
SWEP.ofsA = Angle(90,-90,90)

SWEP.FoodModelsKCNNeutralizers = {
	["models/jorddrink/7upcan01a.mdl"] = 10,
	["models/jorddrink/barqcan1a.mdl"] = 10,
	["models/jorddrink/cozcan01a.mdl"] = 10,
	["models/jorddrink/crucan01a.mdl"] = 10,
	["models/jorddrink/dewcan01a.mdl"] = 10,
	["models/jorddrink/foscan01a.mdl"] = 10,
	["models/jorddrink/heican01a.mdl"] = 10,
	["models/jorddrink/mongcan1a.mdl"] = 10,
	["models/jorddrink/pepcan01a.mdl"] = 10,
	["models/jorddrink/redcan01a.mdl"] = 10,
	["models/jorddrink/sprcan01a.mdl"] = 10,
	["models/foodnhouseholditems/juicesmall.mdl"] = 10,
}

SWEP.FoodModels = {
	"models/jorddrink/7upcan01a.mdl", 
	"models/jorddrink/barqcan1a.mdl",
	"models/jorddrink/cozcan01a.mdl",
	"models/jorddrink/crucan01a.mdl",
	"models/jorddrink/dewcan01a.mdl",
	"models/jorddrink/foscan01a.mdl",
	"models/jorddrink/heican01a.mdl",
	"models/jorddrink/mongcan1a.mdl",
	"models/jorddrink/pepcan01a.mdl",
	"models/jorddrink/redcan01a.mdl",
	"models/jorddrink/sprcan01a.mdl",
	"models/jordfood/atun.mdl",
	"models/foodnhouseholditems/chipsfritos.mdl",
	"models/foodnhouseholditems/chipslays3.mdl",
	"models/foodnhouseholditems/chipslays5.mdl",
	"models/foodnhouseholditems/juicesmall.mdl",
	"models/foodnhouseholditems/mcdburgerbox.mdl"
}

SWEP.WaterModel = {
	["models/jorddrink/7upcan01a.mdl"] = true, 
	["models/jorddrink/barqcan1a.mdl"] = true,
	["models/jorddrink/cozcan01a.mdl"] = true,
	["models/jorddrink/crucan01a.mdl"] = true,
	["models/jorddrink/dewcan01a.mdl"] = true,
	["models/jorddrink/foscan01a.mdl"] = true,
	["models/jorddrink/heican01a.mdl"] = true,
	["models/jorddrink/mongcan1a.mdl"] = true,
	["models/jorddrink/pepcan01a.mdl"] = true,
	["models/jorddrink/redcan01a.mdl"] = true,
	["models/jorddrink/sprcan01a.mdl"] = true,
	["models/foodnhouseholditems/juicesmall.mdl"] = true
}

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

local lang1, lang2 = Angle(0, -10, 0), Angle(0, 10, 0)
function SWEP:Animation()
	if (self:GetOwner().zmanipstart ~= nil and not self:GetOwner().organism.larmamputated) then return end
	local hold = self:GetHolding()
    self:BoneSet("r_upperarm", vector_origin, Angle(0, -10 -hold / 2, 10))
    self:BoneSet("r_forearm", vector_origin, Angle(-5, -hold / 2.5, -hold / 1.5))

    self:BoneSet("l_upperarm", vector_origin, lang1)
    self:BoneSet("l_forearm", vector_origin, lang2)
end

function SWEP:Think()
	self:SetHold(self.HoldType)

	local owner = self:GetOwner()
	if IsValid(owner) and not owner:KeyDown(IN_ATTACK) and hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 12, 0))
	end
end

if SERVER then
	function SWEP:Heal(ent, mode, bone)
		local org = ent.organism
		if not org then return end
		local owner = self:GetOwner()
		
			
		self.Eating = self.Eating or 0
		self.CDEating = self.CDEating or 0
		if self.CDEating > CurTime() then return end

		if self.WaterModel[self.WorldModel] then
			org.hydration = org.hydration + 30
		else
			org.satiety = org.satiety + 20
		end

		-- Stamina regeneration boost
		if org.stamina and org.stamina[1] then
			org.stamina[1] = math.min(org.stamina[1] + 15, org.stamina.max or 180)
		end
		
		-- Pain relief
		org.pain = math.max((org.pain or 0) - 5, 0)
		org.painadd = math.max((org.painadd or 0) - 3, 0)

		if org.hungry < 20 and org.thirst < 20 then
			org.satiety = org.satiety + 10
			org.hydration = org.hydration + 10
		end

		local ply = self:GetOwner()
		ply:ViewPunch(Angle(3,0,0))
		
		ent:EmitSound( self.WaterModel[self.WorldModel] and "snd_jack_hmcd_drink"..math.random(3)..".wav" or "snd_jack_hmcd_eat"..math.random(4)..".wav", 60, math.random(95, 105))
		
		self.CDEating = CurTime() + 0.5
		self.Eating = self.Eating + 1
		self:SetHolding(0)
		if self.Eating > 5 then
			self:GetOwner():SelectWeapon("weapon_hands_sh")
			self:Remove()
		end
		
		return true
	end
end