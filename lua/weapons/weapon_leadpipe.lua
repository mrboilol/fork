if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "Lead Pipe"
SWEP.Instructions = "Part of a lead pipe, you could beat someone up with it, good stuff for a riot.\n\nLMB to attack.\nRMB to block."
SWEP.Category = "Weapons - Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/prop/re9_requiem_pipe.mdl"
SWEP.WorldModelReal = "models/weapons/tfa_nmrih/v_me_pipe_lead.mdl"
SWEP.WorldModelExchange = "models/prop/re9_requiem_pipe.mdl"
SWEP.ViewModel = ""
SWEP.modelscale = 1.15

SWEP.bloodID = 1

SWEP.HoldType = "melee"
SWEP.weight = 3

SWEP.noreverse = true

SWEP.HoldPos = Vector(-16.4,0,0)
SWEP.HoldAng = Angle(0,0,0)

SWEP.AttackTime = 0.3
SWEP.AnimTime1 = 1.2
SWEP.WaitTime1 = 0.95
SWEP.ViewPunch1 = Angle(1,2,0)

SWEP.HitCooldownEnabled = true
SWEP.HitCooldown = 1.1
SWEP.ComboEnabled = true
SWEP.ComboResetTime = 1.6
SWEP.ComboDamageMul1 = 1
SWEP.ComboDamageMul2 = 1.25
SWEP.ComboDamageMul3 = 1.65

SWEP.Attack2Time = 0.3
SWEP.AnimTime2 = 1
SWEP.WaitTime2 = 0.8
SWEP.ViewPunch2 = Angle(0,0,-2)

SWEP.attack_ang = Angle(0,0,0)
SWEP.sprint_ang = Angle(15,0,0)

SWEP.basebone = 94
SWEP.weaponPos = Vector(0,1,-15)
SWEP.weaponAng = Angle(-90,-90,0)

SWEP.CanHeavyAttack = true -- Set to true to enable
SWEP.NeckBreakChance = 0.01
SWEP.NoReverse = true

SWEP.HeavyAttackDamageMul = 2.0 -- Max damage multiplier at full charge
SWEP.HeavyAttackWaitTime = 1.7 -- Time before you can attack again
SWEP.HeavyAttackAnimTimeBegin = 1.0 -- Duration of the wind-up/start animation
SWEP.HeavyAttackAnimTimeIdle = 1 -- Duration of the idle loop
SWEP.HeavyAttackAnimTimeEnd = 1.85 -- Duration of the attack animation
SWEP.HeavyAttackDelay = 0.5 -- Time delay before the hit actually connects (during attack anim)
SWEP.HeavyAttackTimeLength = 0.4 -- Duration of the active hit window
SWEP.HeavyAttackViewPunch = Angle(5, 0, 0) -- View punch angle on hit
SWEP.HeavyAttackMaxChargeTime = 2.0 -- Time in seconds to reach max damage/shake
SWEP.HeavyAttackSwingAng = -90 -- Custom swing angle for heavy attack
SWEP.HeavyAttackRads = 95 -- Custom radius/arc for heavy attack

SWEP.AnimList = {
    ["idle"] = "Idle",
    ["deploy"] = "Draw",
    ["attack"] = "Attack_Quick",
    ["attack2"] = "Shove",
}

SWEP.hitsoundextra = {
    {"hammer/BodyHit-1.wav", 70, {115, 125}},
    {"hammer/BodyHit-2.wav", 70, {115, 125}},
    {"hammer/BodyHit-3.wav", 70, {115, 125}},
    {"hammer/BodyHit-4.wav", 70, {115, 125}},
    {"hammer/BodyHit-5.wav", 70, {115, 125}},
    {"hammer/BodyHit-6.wav", 70, {115, 125}},
}

SWEP.hitsoundbrutalize = {
    {"hammerbrutalize/rem_hammerbrutalize1.wav", 70, {110, 115}},
    {"hammerbrutalize/rem_hammerbrutalize2.wav", 70, {110, 115}},
    {"hammerbrutalize/rem_hammerbrutalize3.wav", 70, {110, 115}},
    {"hammerbrutalize/rem_hammerbrutalize4.wav", 70, {110, 115}},
}

SWEP.swingsoundextra = {
    {"bat/baseball_swing_1st_layer_01.wav", 60, {85, 95}},
    {"bat/baseball_swing_1st_layer_02.wav", 60, {85, 95}},
    {"bat/baseball_swing_1st_layer_03.wav", 60, {85, 95}},
    {"bat/baseball_swing_1st_layer_04.wav", 60, {85, 95}},
}

SWEP.BlockTier = 2
SWEP.BlockMaterial = "metal"
SWEP.BlockSound = {"physics/metal/metal_sheet_impact_hard2.ogg", 85, {125, 145}}

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/hud/pipe.png")
	SWEP.IconOverride = "vgui/hud/pipe.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.setlh = false
SWEP.setrh = true
SWEP.TwoHanded = false

SWEP.AttackHit = "Canister.ImpactHard"
SWEP.Attack2Hit = "Canister.ImpactHard"
SWEP.AttackHitFlesh = "Flesh.ImpactHard"
SWEP.Attack2HitFlesh = "Flesh.ImpactHard"
SWEP.DeploySnd = "physics/wood/wood_plank_impact_soft2.ogg"
SWEP.HitFleshPlus = "leadpipe/hit1.mp3"
SWEP.HitFleshExtraPitch = {110, 115}
SWEP.SwingSound = "baseballbat/swing.mp3"
SWEP.SwingSoundPitch = {120, 130}
SWEP.HitFleshExtra = {
    "leadpipe/hit1.mp3",
}

SWEP.AttackPos = Vector(0,0,0)

SWEP.DamageType = DMG_CLUB
SWEP.DamagePrimary = 21
SWEP.DamageSecondary = 9

SWEP.PenetrationPrimary = 3
SWEP.PenetrationSecondary = 3

SWEP.MaxPenLen = 3

SWEP.PenetrationSizePrimary = 2
SWEP.PenetrationSizeSecondary = 2

SWEP.StaminaPrimary = 31
SWEP.StaminaSecondary = 15
SWEP.HeavyAttackStamina = 24

SWEP.AttackLen1 = 60
SWEP.AttackLen2 = 30

SWEP.NoHolster = true

function SWEP:CanSecondaryAttack()
    return true
end

SWEP.AttackTimeLength = 0.21
SWEP.Attack2TimeLength = 0.1

SWEP.AttackRads = 85
SWEP.AttackRads2 = 0

SWEP.SwingAng = 180
SWEP.SwingAng2 = 0

SWEP.MinSensivity = 0.5

SWEP.BlockTier = 3
SWEP.MeleeMaterial = "metal"
SWEP.BlockImpactSound = "physics/metal/metal_solid_impact_bullet1.ogg"

function SWEP:ThinkAdd()
	local state = self.GetChargeState and self:GetChargeState() or self:GetDTInt(6)
	if state ~= 0 then
		self.setlh = true
	else
		self.setlh = false
	end
end
