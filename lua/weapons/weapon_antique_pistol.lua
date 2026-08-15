SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Antique Bolt Pistol"
SWEP.Author = "Juarez Sim"
SWEP.Instructions = "Single-shot .357 Magnum pistol. Reload cycles the bolt."
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 1
SWEP.SlotPos = 11

SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/antique_pistol.mdl"
SWEP.WorldModelFake = "models/weapons/antique_pistol.mdl"
SWEP.WorldModelReal = "models/weapons/antique_pistol.mdl"
SWEP.UseCustomWorldModel = true
SWEP.FakeScale = 1
SWEP.FakePos = Vector(-7.5, 1.2, 4.2)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.WorldPos = Vector(8, -1, -2.5)
SWEP.WorldAng = Angle(0, 180, 0)

SWEP.holsteredBone = "ValveBiped.Bip01_Pelvis"
SWEP.holsteredPos = Vector(2, 4, -2)
SWEP.holsteredAng = Angle(-10, 0, 180)
SWEP.shouldntDrawHolstered = false

SWEP.LocalMuzzlePos = Vector(20.315, 0, 1.772)
SWEP.LocalMuzzleAng = Angle(0, 0, 0)
SWEP.WeaponEyeAngles = Angle(0, 0, 0)
SWEP.BarrelLength = 21
SWEP.lengthSub = 8

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ".357 Magnum"
SWEP.Primary.Damage = 45
SWEP.Primary.Force = 30
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Wait = 0.35
SWEP.Primary.Sound = {"homigrad/weapons/pistols/deagle-1.wav", 75, 90, 100}

SWEP.CustomShell = "10mm"
SWEP.ShellEject = "EjectBrass_357"
SWEP.FakeEjectBrassATT = "ejectbrass"
SWEP.ManualCycle = true
SWEP.OpenBolt = false
SWEP.NumBullet = 1
SWEP.Penetration = 8
SWEP.weight = 1.4
SWEP.weaponInvCategory = 2
SWEP.ScrappersSlot = "Secondary"

SWEP.ReloadTime = 0.9
SWEP.HoldType = "revolver"
SWEP.AimHold = "revolver"
SWEP.ZoomPos = Vector(-6.5, -0.1, 4.3)
SWEP.RHandPos = Vector(0, 0, 0)
SWEP.LHandPos = false
SWEP.Ergonomics = 0.88
SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.ogg", 55, 100, 110}
SWEP.availableAttachments = {}

SWEP.AnimList = {
    idle = "idle",
    deploy = "deploy",
    reload = "cycle",
    reload_empty = "cycle",
    cycle = "cycle",
    bolt_open = "bolt_open",
    bolt_close = "bolt_close",
    trigger_pull = "trigger_pull",
}

SWEP.AnimsEvents = {
    cycle = {
        -- PlayAnim uses normalized event fractions: 0.47 * 0.90 = 0.423 s.
        [0.47] = function(self)
            self:RejectShell(self.ShellEject)
        end,
    },
}

function SWEP:Reload()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if (self.AntiqueCycleEnd or 0) > CurTime() then return end
    if self:Clip1() >= self.Primary.ClipSize and self.drawBullet ~= false then return end

    self.AntiqueCycleEnd = CurTime() + self.ReloadTime
    self:SetNetVar("shootgunReload", self.AntiqueCycleEnd)
    self:PlayAnim("cycle", self.ReloadTime, false, function(weapon)
        if not IsValid(weapon) then return end

        local weaponOwner = weapon:GetOwner()
        if IsValid(weaponOwner) and weapon:Clip1() < weapon.Primary.ClipSize then
            local ammoType = weapon.Primary.Ammo
            if weaponOwner:GetAmmoCount(ammoType) > 0 then
                weaponOwner:RemoveAmmo(1, ammoType)
                weapon:SetClip1(1)
            end
        end

        weapon.drawBullet = weapon:Clip1() > 0
        weapon:SetNetVar("shootgunReload", 0)
        weapon:PlayAnim("idle", 1, true, nil, false, true)
    end, false, true)
end

function SWEP:PostFireBullet()
    self:PlayAnim("trigger_pull", 0.2, false, function(weapon)
        if IsValid(weapon) then
            weapon:PlayAnim("idle", 1, true, nil, false, true)
        end
    end, false, true)
end
