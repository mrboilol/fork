if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_base"
SWEP.Author = "Linnaeus"
SWEP.Purpose = "I got bored, okay?"
SWEP.PrintName = "Tungsten Cube"
SWEP.Category = "Weapons - Other"
SWEP.Spawnable = true
SWEP.UseHands = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/linnaeus/weaps/v_tungsten.mdl"
SWEP.WorldModel = "models/linnaeus/weaps/w_tungsten.mdl"
SWEP.HoldType = "melee"

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
        ent:SetPos(select(1, hg.eye(ply, 60, hg.GetCurrentCharacter(ply))) - ply:GetAimVector() * 2)
    else
        ent:SetPos(ply:GetShootPos() + ply:EyeAngles():Forward() * 20)
    end
    
    ent:SetAngles(ply:EyeAngles())
    ent:SetOwner(ply)
    ent:Spawn()

    ent.localshit = Vector(0,0,0)
    ent.wep = self:GetClass()
    ent.owner = ply
    ent.damage = 75      -- Lowered damage to 75
    ent.MaxSpeed = 1250  -- Adjusted speed to 1250
    ent.DamageType = DMG_CLUB
    ent.AttackHit = "Concrete.ImpactHard"
    ent.AttackHitFlesh = "Flesh.ImpactHard"
    ent.noStuck = true

    local phys = ent:GetPhysicsObject()

    if IsValid(phys) then
        phys:SetMass(100) -- Making the cube incredibly heavy
        phys:SetVelocity(ply:GetAimVector() * ent.MaxSpeed)
        phys:AddAngleVelocity(VectorRand() * 300)
    end

    ply:EmitSound("weapons/slam/throw.wav", 50, math.random(95, 105))
    ply:ViewPunch(Angle(-5, 0, -8))
    
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