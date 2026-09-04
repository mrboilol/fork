--made by lazzy https://steamcommunity.com/id/TimeToFuckinDie
SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "AKM"
SWEP.Author = "Izhevsk Machine-Building Plant"
SWEP.Instructions = "An extraordinarily potent instrument of power, this steel 7.62x39mm selective fire, gas-operated rifle with a rotating bolt, capable of firing in either semi-automatic or fully automatic mode, is the epitome of Soviet military might in the mid-20th century. With a cyclic rate of fire of around 600 rounds per minute and a 10-, 20-, or 30-round detachable box magazine, this AKM, designed by the renowned Mikhail Kalashnikov, stands as a symbol of the USSR’s technological progress. Its robust design and reliable performance in harsh conditions underline its reputation as a weapon that has left an indelible mark on global warfare"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.WeaponRecoilMul = 0.7
SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(4, 6, -6)
SWEP.holsteredAng = Angle(220, 0, 180)
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/c_ur_ak.mdl"

SWEP.ModularParts = {
	receiver = {
		model = "models/weapons/mods/ak_dc_akm_std.mdl",
		bonemerge = false,
		bone = "weapon",
		pos = Vector(0, -19, 1.5),
		ang = Angle(0, 0, 0)
	},
	magazine = {
		model = "models/weapons/mods/mag_ak_izhmash_6l10_762x39_30.mdl",
		bonemerge = false,
		bone = "mod_magazine",
		pos = Vector(0, 0, -0.15),
		ang = Angle(0, 0, 0)
	},
	handguard = {
		model = "models/weapons/mods/ak_hg_akm_std_wood.mdl",
		bonemerge = false,
		bone = "weapon",
		pos = Vector(0, -19.41, 0.5),
		ang = Angle(0, 0, 0)
	},
	pistolgrip = {
		model = "models/weapons/mods/ak_pgrip_akm_wood.mdl",
		bonemerge = false,
		bone = "weapon",
		pos = Vector(0, -12.3, -1.3),
		ang = Angle(0, 0, 0)
	},
	stock = {
		model = "models/weapons/mods/ak_stock_akm_std_wood.mdl",
		bonemerge = false,
		bone = "weapon",
		pos = Vector(0.65, -9.6, -0.8),
		ang = Angle(0, 0, 0)
	},
	stock_mount = {
		model = "models/weapons/mods/ak_stock_zenit_pt1_lock.mdl",
		bonemerge = false,
		bone = "weapon",
		pos = Vector(0.65, -9.6, -0.8),
		ang = Angle(0, 0, 0)
	},
}
SWEP.HeldMagOffsetPos = Vector(0, 0, 0)
SWEP.HeldMagOffsetAng = Angle(0, 0, 0)

SWEP.ARC9DefaultLHIKPart = "handguard"
SWEP.ARC9DefaultLHIKSourceModel = "models/weapons/mods/ak_hg_akm_std_wood.mdl"

SWEP.FakePos = Vector(-14, 2.52, 7.5)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(-1, 0, 0)
SWEP.AttachmentAng = Angle(0, 0, 0)
SWEP.FakeAttachment = "1"
SWEP.FakeBodyGroups = "01010080102"

SWEP.FakeEjectBrassATT = "2"

SWEP.FakeViewBobBone = "CAM_Homefield"

SWEP.FakeReloadSounds = {
	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.34] = "weapons/newakm/akmm_magout.wav",
	[0.38] = "weapons/newakm/akmm_magout_rattle.wav",

	[0.62] = "weapons/newakm/akmm_magin.wav",
	[0.81] = "weapons/universal/uni_crawl_l_03.wav",
	[0.99] = "weapons/universal/uni_crawl_l_04.wav",

}

SWEP.FakeEmptyReloadSounds = {

	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.34] = "weapons/newakm/akmm_magout.wav",
	[0.4] = "weapons/newakm/akmm_magout_rattle.wav",
	[0.62] = "weapons/newakm/akmm_magin.wav",

	[0.83] = "weapons/newakm/akmm_boltback.wav",
	[0.86] = "weapons/newakm/akmm_boltrelease.wav",
	[1.01] = "weapons/universal/uni_crawl_l_04.wav",
}

SWEP.MagModel = "models/btk/nam_akmmag.mdl" 

SWEP.lmagpos = Vector(0,0,1)
SWEP.lmagang = Angle(30,0,0)
SWEP.lmagpos2 = Vector(0,-2.5,1)
SWEP.lmagang2 = Angle(0,0,-90)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70
SWEP.FakeMagDropBone = 57

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}

local vector_full = Vector(1,1,1)

function SWEP:RevertMag()
	local wm = self:GetWM()

	if IsValid(wm) and wm:GetManipulateBoneScale(55):IsEqualTol(vector_origin, 0.1) then
		wm:ManipulateBoneScale(55, vector_full)
		wm:ManipulateBoneScale(56, vector_full)
		wm:ManipulateBoneScale(57, vector_origin)
		wm:ManipulateBoneScale(58, vector_origin)
	end
end

if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.15] = function( self, timeMul )
			local wm = self:GetWM()
			wm:ManipulateBoneScale(55, vector_origin)
			wm:ManipulateBoneScale(56, vector_origin)
			wm:ManipulateBoneScale(57, vector_full)
			wm:ManipulateBoneScale(58, vector_full)
		end,
		[0.16] = function( self, timeMul )
			self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.58 * timeMul)
		end,
		[0.27] = function( self, timeMul )
			local wm = self:GetWM()
			wm:ManipulateBoneScale(55, vector_full)
			wm:ManipulateBoneScale(56, vector_full)
			wm:ManipulateBoneScale(58, vector_full)
			wm:ManipulateBoneScale(57, vector_full)
		end,
		
		[0.40] = function(self,timeMul)
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(50,10,10) )
				self:GetWM():ManipulateBoneScale(57, vector_origin)
				self:GetWM():ManipulateBoneScale(58, vector_origin)
				--self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 0.5 * timeMul)
			end
		end,
		[0.85] = function(self,timeMul)
			self:GetWM():ManipulateBoneScale(57, vector_origin)
			self:GetWM():ManipulateBoneScale(58, vector_origin)
		end
	}
end

function SWEP:ModelCreated(model)
	model:ManipulateBoneScale(57, vector_origin)
	model:ManipulateBoneScale(58, vector_origin)
	model:SetBodyGroups(self.FakeBodyGroups)
end

SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false

SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "7.62x39 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 42
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 50
SWEP.ShockMultiplier = 2

SWEP.Primary.Sound = {"weapons/newakm/akmm_tp.wav", 85, 90, 100}
SWEP.Primary.SoundFP = {"weapons/newakm/akmm_fp.wav", 85, 90, 100}

SWEP.SupressedSound = {"weapons/newakm/akmm_suppressed_tp.wav", 65, 90, 100}
SWEP.SupressedSoundFP = {"weapons/newakm/akmm_suppressed_fp.wav", 65, 90, 100}

SWEP.Primary.SoundEmpty = {"weapons/newakm/akmm_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}

SWEP.DistSound = "weapons/newakm/akmm_dist.wav"



SWEP.WepSelectIcon2 = Material("pwb/sprites/akm.vmt")
SWEP.IconOverride = "entities/arc9_eft_akm.png"
SWEP.ScrappersSlot = "Primary"
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor1", Vector(0,0,0), {}},
		[2] = {"supressor6", Vector(0,0,0), {}},
		["mount"] = Vector(-2,0.2,0),
		["mountAngle"] = Angle(0,0,0)
	},
	sight = {
		["mountType"] = {"picatinny", "dovetail"},
		["mount"] = {["dovetail"] = Vector(-25, 2.2, -0.45),["picatinny"] = Vector(-24.5, 2.65, -0.22)},
	},
	mount = {
		["picatinny"] = {
			"mount3",
			Vector(-22.5, 0, -1.26),
			{},
			["mountType"] = "picatinny",
		},
		["dovetail"] = {
			"empty",
			Vector(0, 0, 0),
			{},
			["mountType"] = "dovetail",
		},
	},
	stock = {
		[1] = {"stock_akm_std", Vector(0, 0, 0), {}},
		["mountType"] = "ak_stock",
		["mountBone"] = "weapon",
		["mount"] = Vector(0.65, -9.6, -0.8),
	},
}

SWEP.RHandPos = Vector(0, -1, 0)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.Penetration = 19
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.02 - math.cos(i) * 0.03, math.cos(i * i) * 0.02, 0) * 2
end

SWEP.Ergonomics = 0.8
SWEP.HaveModel = "models/pwb/weapons/w_akm.mdl"
--SWEP.ShellEject = "EjectBrass_338Mag"
SWEP.CustomShell = "762x39"

SWEP.Penetration = 15
SWEP.WorldPos = Vector(4, -1, -1.5)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
--https://youtu.be/I7TUHPn_W8c?list=RDEMAfyWQ8p5xUzfAWa3B6zoJg
SWEP.attPos = Vector(0.2, -2.6, 27)
SWEP.attAng = Angle(-0, 0.3, 0)
SWEP.lengthSub = 20
SWEP.handsAng = Angle(3, -1, 0)
SWEP.AimHands = Vector(-4, 0.5, -4)

SWEP.RHPos = Vector(3, -7, 3.5)
SWEP.RHAng = Angle(0, -8, 90)
SWEP.LHPos = Vector(11, 1.6, -3)
SWEP.LHAng = Angle(-110, -180, 5)

SWEP.weight = 4

--local to head
SWEP.RHPos = Vector(3,-6.5,3.5)
SWEP.RHAng = Angle(0,-8,90)
--local to rh
SWEP.LHPos = Vector(15,1.5,-3.5)
SWEP.LHAng = Angle(-110,-180,0)

SWEP.ShootAnimMul = 7

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = Lerp(FrameTime()*15,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = 0*self.shooanim
		vec[2] = 1*self.shooanim
		vec[3] = 0*self.shooanim
		wep:ManipulateBonePosition(8,vec,false)
	end
end
local lfang4 = Angle(0,70,0)
local lfang3 = Angle(0,-25,0)
local lfang2 = Angle(0,46,0)
local lfang1 = Angle(0,-30,0)
local lfang0 = Angle(0,-7,0)
local vec_zero = Vector(0,0,0)
local l_finger02 = Angle(-10,0,0)
function SWEP:AnimHoldPost()

SWEP.FireAnimTime = 0.15
SWEP.FireAnimCandidates = {"fire", "fire1"}

function SWEP:PrimaryShootPost()
	if not CLIENT then return end
	if self.reload then return end
	if not self:ShouldUseFakeModel() then return end

	local worldModel = self:GetWM()
	if not IsValid(worldModel) then return end

	local selectedSequence
	for _, sequenceName in ipairs(self.FireAnimCandidates) do
		local sequenceID = worldModel:LookupSequence(sequenceName)
		if sequenceID ~= nil and sequenceID >= 0 then
			selectedSequence = sequenceName
			break
		end
	end

	if not selectedSequence then return end

	self.AnimList.fire = selectedSequence
	self:PlayAnim("fire", self.FireAnimTime, false, function()
		if not IsValid(self) then return end
		self:PlayAnim("idle", 1, not self.NoIdleLoop)
	end)
end
