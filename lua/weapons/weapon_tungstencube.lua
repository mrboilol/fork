if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_base"
SWEP.Author = "Linnaeus"
SWEP.Purpose = "Small but mighty"
SWEP.PrintName = "Tungsten Cube"
SWEP.Category = "Weapons - Other"
SWEP.Spawnable = true
SWEP.UseHands = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/linnaeus/weaps/v_tungsten.mdl"
SWEP.WorldModel = "models/linnaeus/weaps/w_tungsten.mdl"
SWEP.HoldType = "melee"

SWEP.modelscale = 1.0
SWEP.HoldPos = Vector(-5, 2, -2)
SWEP.HoldAng = Angle(-10, 0, 0)
SWEP.basebone = 94
SWEP.weaponPos = Vector(0, 0, 0)
SWEP.weaponAng = Angle(0, -90, 0)
SWEP.AnimList = {
	["idle"] = "Idle",
	["deploy"] = "Draw",
	["attack"] = "Throw",
}

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Slot = 1
SWEP.SlotPos = 5
SWEP.DrawAmmo = false

if CLIENT then
    SWEP.IconOverride = "entities/tungstencubeicon"
    killicon.Add( "tungsten_cube", "entities/tungstencubeicon", color_white )
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1)
    self:SendWeaponAnim(ACT_VM_THROW)

    if not SERVER then return end

    local ply = self:GetOwner()

    local ent = ents.Create("ent_throwable")
    ent.WorldModel = self.WorldModel

    if hg and hg.eye and hg.GetCurrentCharacter then
        ent:SetPos(select(1, hg.eye(ply,60,hg.GetCurrentCharacter(ply))) - ply:GetAimVector() * 2)
    else
        ent:SetPos(ply:GetShootPos() + ply:EyeAngles():Forward() * 20)
    end
    ent:SetAngles(ply:EyeAngles())
    ent:SetOwner(self:GetOwner())
    ent:Spawn()

    ent.localshit = Vector(0,0,0)
    ent.wep = self:GetClass()
    ent.owner = ply
    ent.damage = 100
    ent.MaxSpeed = 1500
    ent.DamageType = DMG_CLUB
    ent.AttackHit = "phx/hmetal" .. math.random(1, 3) .. ".wav"
    ent.AttackHitFlesh = "Flesh.ImpactHard"
    ent.noStuck = true
    ent.modelscale = self.modelscale or 1.0

    local phys = ent:GetPhysicsObject()

    if IsValid(phys) then
		phys:SetMass(200)
        local throwVel = ply:GetAimVector() * ent.MaxSpeed
        local playerVel = ply:GetVelocity()
        phys:SetVelocity(throwVel + playerVel * 0.5)
        phys:AddAngleVelocity(VectorRand() * 300)
        
        -- Apply model scale if set
        if ent.modelscale and ent.modelscale ~= 1.0 then
            ent:SetModelScale(ent.modelscale, 0)
        end
    end

    ply:EmitSound("weapons/slam/throw.wav", 75, math.random(95, 105))
    ply:ViewPunch(Angle(-8, 0, -10))
    
    ply:SelectWeapon("weapon_hands_sh")
    self:Remove()
    
    return true
end

function SWEP:SecondaryAttack()
    return false
end

function SWEP:CanSecondaryAttack()
    return false
end