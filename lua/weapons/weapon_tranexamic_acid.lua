if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bigconsumable"
SWEP.PrintName = "Tranexamic Acid"
SWEP.Instructions = "Use to reduce internal bleeding and stroke meter."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/props_health/health_vial.mdl"
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

SWEP.FoodModels = {
	"models/props_health/health_vial.mdl"
}

SWEP.WaterModel = {
	["models/props_health/health_vial.mdl"] = true
}

if SERVER then
	function SWEP:Heal(ent, mode, bone)
		local org = ent.organism
		if not org then return end
		self.Eating = self.Eating or 0
		self.CDEating = self.CDEating or 0
		if self.CDEating > CurTime() then return end

		org.stroke_meter = math.max(org.stroke_meter - 25, 0)
        org.internalBleed = math.max(org.internalBleed - 1, 0)

		local ply = self:GetOwner()
		ply:ViewPunch(Angle(3,0,0))
		
		ent:EmitSound( "snd_jack_hmcd_drink"..math.random(3)..".wav", 60, math.random(95, 105))
		
		self.CDEating = CurTime() + 0.5
		self.Eating = self.Eating + 1
		if self.Eating > 5 then
			self:GetOwner():SelectWeapon("weapon_hands_sh")
			self:Remove()
		end
		
		return true
	end
end