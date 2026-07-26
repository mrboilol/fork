SWEP.Base = "weapon_base"
SWEP.PrintName = "Mobile Phone"
SWEP.Instructions = "LMB or Reload opens the phone. Call any registered map or player phone, text during calls, or use live voice chat."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.ViewModel = ""
SWEP.WorldModel = "models/saraphines/insurgency explosives/ied/insurgency_ied_phone.mdl"
SWEP.HoldType = "slam"
SWEP.Weight = 1
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 5
SWEP.SlotPos = 6
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(5, 0.5, -15)
SWEP.offsetAng = Angle(0, 70, 180)
SWEP.ModelScale = 1

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_phone")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_phone"
	SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	if SERVER then
		timer.Simple(0, function()
			if IsValid(self) and HG_PHONE_SERVER then HG_PHONE_SERVER:RegisterPhone(self) end
		end)
	end
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
	if SERVER and HG_PHONE_SERVER then HG_PHONE_SERVER:RegisterPhone(self) end
	return true
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.4)
	if SERVER and HG_PHONE_SERVER then HG_PHONE_SERVER:OpenPhone(self:GetOwner(), self) end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.4)
end

function SWEP:Reload()
	if (self.NextPhoneOpen or 0) > CurTime() then return end
	self.NextPhoneOpen = CurTime() + 0.4
	if SERVER and HG_PHONE_SERVER then HG_PHONE_SERVER:OpenPhone(self:GetOwner(), self) end
end

function SWEP:GetInfo()
	return {
		phoneNumber = HG_PHONE.GetNumber(self),
		displayName = HG_PHONE.GetDisplayName(self),
		ringtone = HG_PHONE.GetRingtone(self)
	}
end

function SWEP:SetInfo(info)
	if not SERVER or not istable(info) then return end
	timer.Simple(0, function()
		if IsValid(self) and HG_PHONE_SERVER then
			HG_PHONE_SERVER:SetIdentity(self, info.phoneNumber, info.displayName, info.ringtone)
		end
	end)
end

function SWEP:OnRemove()
	if CLIENT and IsValid(self.PhoneWorldModel) then self.PhoneWorldModel:Remove() end
	if SERVER and HG_PHONE_SERVER and HG_PHONE.GetNumber(self) ~= "" then HG_PHONE_SERVER:UnregisterPhone(self) end
end

if CLIENT then
	function SWEP:DrawWorldModel()
		self:DrawWorldModel2()
	end

	function SWEP:DrawWorldModel2()
		self.PhoneWorldModel = IsValid(self.PhoneWorldModel) and self.PhoneWorldModel or ClientsideModel(self.WorldModel)
		local model = self.PhoneWorldModel
		if not IsValid(model) then return end
		model:SetNoDraw(true)
		model:SetModelScale(self.ModelScale, 0)
		model:SetSkin(1)

		local owner = self:GetOwner()
		local character = IsValid(owner) and hg.GetCurrentCharacter(owner) or nil
		if IsValid(character) then
			local bone = character:LookupBone("ValveBiped.Bip01_R_Hand")
			local matrix = bone and character:GetBoneMatrix(bone)
			if not matrix then return end
			local pos, ang = LocalToWorld(self.offsetVec, self.offsetAng, matrix:GetTranslation(), matrix:GetAngles())
			model:SetPos(pos)
			model:SetAngles(ang)
		else
			model:SetPos(self:GetPos())
			model:SetAngles(self:GetAngles())
		end
		model:DrawModel()
	end
end
