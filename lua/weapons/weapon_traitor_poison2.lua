if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_base"
SWEP.PrintName = "VX vial"
SWEP.Instructions = "VX is an extremely toxic synthetic chemical compound in the organophosphorus class, specifically, a thiophosphonate. In the class of nerve agents, it was developed for military use in chemical warfare after translation of earlier discoveries of organophosphate toxicity in pesticide research."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/props_junk/PopCan01a.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_poisonliquid")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_poisonliquid"
	SWEP.BounceWeaponIcon = false
end

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 3
SWEP.SlotPos = 4
SWEP.WorkWithFake = false
SWEP.offsetVec = Vector(5, -1.5, -0.6)
SWEP.offsetAng = Angle(0, 0, -10)
SWEP.ModelScale = 0.3

if SERVER then
    function SWEP:OnRemove() end
end

function SWEP:DrawWorldModel()
	hg.swep.DrawBoneAttachedModel(self, {material = "models/mat_jack_hmcd_armor"})
end

function SWEP:SetHold(value)
	hg.swep.SetHold(self, value)
end

function SWEP:Think()
	self:SetHold(self.HoldType)
end

SWEP.traceLen = 5

function SWEP:GetEyeTrace()
	return hg.swep.GetEyeTrace(self)
end

if CLIENT then
	function SWEP:DrawHUD()
		hg.swep.DrawSimpleCrosshair(self)
	end
end

function SWEP:DoPoison(ent)
    local owner = self:GetOwner()

    owner:EmitSound("snd_jack_hmcd_needleprick.wav",30)

	ent.poisoned = true

    self:Remove()
	owner:SelectWeapon("weapon_hands_sh")
end

if SERVER then
	hook.Add("PlayerUse","otravleno_dibil!!!",function(ply,ent)
		if IsValid(ent) and ent.poisoned then
			if IsValid(ply) and ply.organism then
				ply.organism.poison2 = CurTime()
				ent.poisoned = nil
			end
		end
	end)

	hg.poison.Register({
		key = "poison2",
		notifyDelay = 15,
		notifyMsg = "Something stops me from breathing normally.",
		notifyTag = "poison2",
		killDelay = 30,
		hookSuffix = "poison2",
	})
end

function SWEP:SecondaryAttack()
end

function SWEP:Initialize()
	self:SetHold(self.HoldType)
	self:SetModelScale(self.ModelScale)
	self:Activate()
	if IsValid(self:GetPhysicsObject()) then
		self:GetPhysicsObject():SetMass(5)
	end
end

function SWEP:PrimaryAttack()
	if SERVER then
        local tr = self:GetEyeTrace()

        if IsValid(tr.Entity) and IsValid(tr.Entity:GetPhysicsObject()) and not tr.Entity:IsPlayer() then
            self:DoPoison(tr.Entity)
        end
	end
end

function SWEP:Reload()
end