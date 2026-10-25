SWEP.Base = "weapon_revolver2"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "S&W Model 500"
SWEP.Author = "Smith & Wesson"
SWEP.Instructions = "Five-shot double-action revolver chambered in .500 S&W Magnum"
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"
SWEP.WorldModelFake = "models/weapons/c_ins2_revolver_sw500.mdl"

SWEP.DrumSize = 5
SWEP.MagIndex = false

SWEP.FakeScale = 1.25
SWEP.FakePos = Vector(-20.43, 2.94, 8.44)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.FakeAttachment = "muzzle"
SWEP.AttachmentPos = Vector(0, 0, 0)
SWEP.AttachmentAng = Angle(0, 0, 0)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_Forearm"
SWEP.FakeVPShouldUseHand = false
SWEP.ViewPunchDiv = 1

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload_speed",
	["reload_empty"] = "base_reload_speed",
	["inspect"] = "check1",
}

SWEP.FakeReloadSounds = {
	[0.26] = "weapons/tfa_ins2/swmodel10/revolver_open_chamber.wav",
	[0.45] = "weapons/tfa_ins2/thanez_cobra/revolver_dump_rounds_01.wav",
	[0.79] = "weapons/tfa_ins2/thanez_cobra/revolver_speed_loader_insert_01.wav",
	[0.99] = "weapons/tfa_ins2/thanez_cobra/revolver_close_chamber.ogg"
}

SWEP.FakeEmptyReloadSounds = SWEP.FakeReloadSounds

SWEP.ReloadSoundes = {
	"none",
	"none",
	"weapons/tfa_ins2/swmodel10/revolver_open_chamber.wav",
	"none",
	"none",
	"weapons/tfa_ins2/thanez_cobra/revolver_dump_rounds_01.wav",
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/thanez_cobra/revolver_speed_loader_insert_01.wav",
	"none",
	"weapons/tfa_ins2/thanez_cobra/revolver_close_chamber.ogg",
	"none",
	"none",
	"none",
	"none"
}

SWEP.WepSelectIcon2 = Material("entities/weapon_sw500.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/weapon_sw500.png"

SWEP.weight = 2.2
SWEP.punchmul = 9
SWEP.punchspeed = 0.8
SWEP.podkid = 3
SWEP.RecoilActionMul = 1.6
SWEP.ShockMultiplier = 4

SWEP.LocalMuzzlePos = Vector(8.94, 0.33, 7.1)
SWEP.LocalMuzzleAng = Angle(0, 0, 0)
SWEP.WeaponEyeAngles = Angle(0, 0, 0)

SWEP.weaponInvCategory = 2
SWEP.ScrappersSlot = "Secondary"
SWEP.ShellEject = false
SWEP.CustomShell = "50ae"
SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ".500 Bushwhacker Raptor"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 190
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 45
SWEP.Primary.Sound = {"weapons/darsu_eft/deagle/deagle_outdoor_close.wav", 85, 60, 70}
SWEP.Primary.Wait = 0.35
SWEP.ReloadTime = 4

SWEP.HoldType = "revolver"
SWEP.AimHold = "revolver"
SWEP.ZoomPos = Vector(25, 0.45, 8.32)
SWEP.RHandPos = Vector(-13.5, 0, 3)
SWEP.LHandPos = false
SWEP.SprayRand = {Angle(-0.15, -0.25, 0), Angle(-0.3, 0.25, 0)}
SWEP.AnimShootMul = 4
SWEP.AnimShootHandMul = 2
SWEP.ShootAnimMul = 3
SWEP.Ergonomics = 0.75
SWEP.Penetration = 14

SWEP.WorldPos = Vector(11, -0.8, 2.6)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(0, -2, -0.5)
SWEP.attAng = Angle(0, 0, 0)
SWEP.lengthSub = 25
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, 1, -7)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true

SWEP.availableAttachments = {}

SWEP.RHPos = Vector(12, -4.5, 3)
SWEP.RHAng = Angle(0, -5, 90)
SWEP.LHPos = Vector(-1.2, -1.4, -2.8)
SWEP.LHAng = Angle(5, 9, -100)

function SWEP:OnCantReload()
	if self.Inspecting and self.Inspecting > CurTime() then return end
	self.Inspecting = CurTime() + 4.4
	self:PlayAnim("inspect", 4.4, false, function(self)
		self:PlayAnim("idle", 1)
	end, false, true)
end

if CLIENT then
	local vector_full = Vector(1, 1, 1)
	local loaderBones = {"sw500-loader", "sw500-loaded1", "sw500-loaded2", "sw500-loaded3", "sw500-loaded4"}

	local function setLoaderScale(self, wm, scale)
		if not IsValid(wm) then return end
		for _, name in ipairs(loaderBones) do
			local bone = wm:LookupBone(name)
			if bone then wm:ManipulateBoneScale(bone, scale) end
		end
		self.loaderShown = scale == vector_full
	end

	SWEP.FakeReloadEvents = {
		[0.3] = false,
		[0.5] = false,
		[0.9] = false,
		[0.61] = function(self)
			local wm = self:GetWM()
			if not IsValid(wm) then return end
			local bone = wm:LookupBone("sw500-drum")
			local pos, ang = wm:GetBonePosition(bone or 0)
			local drum = self:GetDrum()
			for i = 1, #drum do
				if self.CustomShell and drum[i] == -1 then
					self:MakeShell(self.CustomShell, pos, ang, Vector(0, 0, 0))
				end
			end
		end,
		[0.65] = function(self)
			setLoaderScale(self, self:GetWM(), vector_full)
		end,
		[1.1] = function(self)
			setLoaderScale(self, self:GetWM(), vector_origin)
		end
	}

	function SWEP:ModelCreated(model)
		model:SetRenderBounds(Vector(-80, -80, -80), Vector(80, 80, 80))
		setLoaderScale(self, model, vector_origin)
	end

	function SWEP:DrawPost()
		local wm = self:GetWM()
		if not IsValid(wm) then return end
		if self.loaderShown and not self.reload then setLoaderScale(self, wm, vector_origin) end
		local target = self:GetNWInt("drumroll", 0)
		local current = self.DrumAng or 0
		if current ~= current or math.abs(current - target) > 1000 then current = target end
		self.DrumAng = LerpFT(0.05, current, target)
		local bone = wm:LookupBone("sw500-drum")
		if bone then
			wm:ManipulateBoneAngles(bone, Angle((360 / self.DrumSize) * (self.reload and 0 or self.DrumAng), 0, 0))
		end
	end
end
