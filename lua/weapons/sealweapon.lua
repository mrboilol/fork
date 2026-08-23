SWEP.Base = "weapon_tpik_base"
SWEP.PrintName = "not a gubby"
SWEP.Author = "HacPaL_B_kOlяCkY"
SWEP.Instructions = "is that a gubby..."
SWEP.Spawnable = true
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_seal.mdl"
SWEP.WorldModel = "models/sealplush/sealplush.mdl"
SWEP.WorldModelReal = "models/weapons/c_seal.mdl"
SWEP.ViewModelFOV = 54
SWEP.DrawCrosshair = false
SWEP.HoldType = "duel"
SWEP.supportTPIK = true
SWEP.setrh = true
SWEP.setlh = false
SWEP.HoldPos = Vector(0, 0, 0)
SWEP.HoldAng = Angle(0, 0, 0)
SWEP.modelscale = 0.55
SWEP.modelscale2 = 0.55

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

if SERVER then
    util.AddNetworkString("SealDeploy")
    util.AddNetworkString("SealSound")
    util.AddNetworkString("SealSkin")
end

local function SetSealSkin(wep, skin)
    wep.CurrentSkin = skin
    wep.WMSkin = skin
    wep.WMSkinV = skin
    wep:SetSkin(skin)
    if CLIENT then
        local owner = wep:GetOwner()
        if IsValid(owner) then
            local vm = owner:GetViewModel()
            if IsValid(vm) then vm:SetSkin(skin) end
        end
    end
end

local function SpawnPhysicalSeal(self, thrown, positionOverride, angleOverride, ownerOverride)
    if CLIENT or self.SealConvertedToEntity then return end
    local cfg = HG_SEAL_CONFIG or {}
    local owner = IsValid(ownerOverride) and ownerOverride or self:GetOwner()
    local character = IsValid(owner) and hg.GetCurrentCharacter and hg.GetCurrentCharacter(owner) or owner
    if not IsValid(character) then character = owner end

    local seal = ents.Create("sealplush")
    if not IsValid(seal) then return end

    local pos = isvector(positionOverride) and positionOverride or self:GetPos()
    local ang = isangle(angleOverride) and angleOverride or self:GetAngles()
    if thrown and IsValid(owner) and owner:IsPlayer() and not positionOverride then
        ang = owner:EyeAngles()
        pos = owner:EyePos() + ang:Forward() * 18 + ang:Right() * 5 - ang:Up() * 5
    end
    seal:SetPos(pos)
    seal:SetAngles(ang)
    seal:Spawn()
    seal:SetSkin(self.CurrentSkin or 0)
    if self.SealStoredHealth then seal:SetHealth(math.max(self.SealStoredHealth, 0)) end
    if self.SealStoredBlood then seal.SealBlood = math.max(self.SealStoredBlood, 0) end
    if self.SealStoredBleedRate then seal.SealBleedRate = math.max(self.SealStoredBleedRate, 0) end
    seal:SyncPhysiology()

    if thrown and IsValid(owner) and owner:IsPlayer() then
        local speed = cfg.THROW_SPEED or 760
        local phys = seal:GetPhysicsObject()
        if IsValid(phys) then
            local inherited = IsValid(character) and character:GetVelocity() or owner:GetVelocity()
            phys:SetVelocity(owner:GetAimVector() * speed + inherited * 0.5)
            phys:AddAngleVelocity(VectorRand() * 320)
        end
        seal:ArmThrownImpact(owner, speed)
        seal:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        timer.Simple(0.15, function()
            if IsValid(seal) then seal:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE) end
        end)
    end

    self.SealConvertedToEntity = true
    return seal
end

local function FinishSealThrow(self)
    if CLIENT or not IsValid(self) then return end
    local owner = self:GetOwner()
    local seal = SpawnPhysicalSeal(self, true)
    if not IsValid(seal) then
        self.SealThrowPending = false
        return
    end

    self.SealThrowPending = false
    if IsValid(owner) and owner:IsPlayer() then
        owner:ViewPunch(Angle(2, 0, -5))
        owner:SelectWeapon("weapon_hands_sh")
    end
    self:Remove()
end

SWEP.AnimList = {
    ["deploy"] = {"base_draw", 1, false},
    ["attack"] = {"throw", 0.45, false, false, FinishSealThrow, 0.24},
    ["idle"] = {"draw", 1, false}
}

function SWEP:Initialize()
    if self.BaseClass.Initialize then self.BaseClass.Initialize(self) end

    self:SetHoldType(self.HoldType)
    self.CurrentSkin       = 0
    self.Sleeping          = false
    self.WasAsleepHolster  = false
    self.LastActivity      = CurTime()
    self.NextBlink         = CurTime() + 2
    self.BlinkEnd          = 0
    self.IsBlinking        = false
    self._lastHP           = -1
    local cfg = HG_SEAL_CONFIG or {}
    self.SealStoredHealth = self.SealStoredHealth or cfg.MAX_HEALTH or 100
    self.SealStoredBlood = self.SealStoredBlood or cfg.MAX_BLOOD_ML or 1200
    self.SealStoredBleedRate = self.SealStoredBleedRate or 0
    self.SealPhysiologyTime = CurTime()
end

function SWEP:Deploy()
    self:SetHold(self.HoldType)
    if self.PlayAnim then self:PlayAnim("deploy") end
    self.LastActivity = CurTime()
    self.NextBlink    = CurTime() + 2
    self.IsBlinking   = false
    self.DeployTime   = CurTime()

    SetSealSkin(self, 2)

    if SERVER then
        net.Start("SealDeploy")
        net.WriteBool(self.WasAsleepHolster)
        net.Send(self:GetOwner())
        
        local timerName = "SealDeploySkin_" .. self:EntIndex()
        timer.Create(timerName, 2, 1, function()
            if IsValid(self) then
                if self.WasAsleepHolster then
                    self.Sleeping = true
                    SetSealSkin(self, 1)
                    net.Start("SealSkin")
                    net.WriteInt(1, 8)
                    net.Send(self:GetOwner())
                else
                    self.Sleeping = false
                    SetSealSkin(self, 0)
                    net.Start("SealSkin")
                    net.WriteInt(0, 8)
                    net.Send(self:GetOwner())
                end
            end
        end)
    end

    return true
end

function SWEP:Holster()
    if self.SealThrowPending then return false end
    timer.Remove("SealDeploySkin_" .. self:EntIndex())
    timer.Remove("SealHurt_" .. self:EntIndex())
    self.WasAsleepHolster = self.Sleeping
    return true
end

function SWEP:PrimaryAttack()
    if self.SealThrowPending or self.SealConvertedToEntity then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:SealWake()
    self.SealThrowPending = true
    self.Thrower = owner
    self:SetNextPrimaryFire(CurTime() + 0.6)
    if self.PlayAnim then self:PlayAnim("attack") end
end

function SWEP:SecondaryAttack()
    self:SealWake()

    if SERVER then
        net.Start("SealSound")
        net.WriteString("sealplush/soundseal1.wav")
        net.Send(self:GetOwner())
    end
end

function SWEP:ApplySealTreatment(kind, healer, strength)
    if CLIENT or self.SealConvertedToEntity then return false end

    local before = math.max(self.SealStoredBleedRate or 0, 0)
    if before <= 0.05 then return false end

    local cfg = HG_SEAL_CONFIG or {}
    strength = math.Clamp(tonumber(strength) or 1, 0.1, 1)
    local reduction, flat
    if kind == "ducttape" then
        reduction = cfg.DUCT_TAPE_BLEED_REDUCTION or 0.80
        flat = cfg.DUCT_TAPE_BLEED_FLAT or 3
    else
        reduction = cfg.BANDAGE_BLEED_REDUCTION or 0.65
        flat = cfg.BANDAGE_BLEED_FLAT or 2
    end

    local after = math.max(before * (1 - reduction * strength) - flat * strength, 0)
    if after >= before - 0.01 then return false end

    self.SealStoredBleedRate = after
    self:SetNW2Float("SealBlood", math.max(self.SealStoredBlood or 0, 0))
    self:SetNW2Float("SealBleedRate", after)
    if IsValid(healer) and healer:IsPlayer() then
        healer:ChatPrint(kind == "ducttape" and "You tape the seal's wound closed." or "You bandage the seal's wound.")
    end
    return true, before - after
end

function SWEP:UpdateSealPhysiology(now)
    if CLIENT or self.SealConvertedToEntity then return end
    local cfg = HG_SEAL_CONFIG or {}
    local last = self.SealPhysiologyTime or now
    local dt = math.Clamp(now - last, 0, 0.25)
    self.SealPhysiologyTime = now
    local bleedRate = math.max(self.SealStoredBleedRate or 0, 0)
    if bleedRate > 0 and dt > 0 then
        self.SealStoredBlood = math.max((self.SealStoredBlood or cfg.MAX_BLOOD_ML or 1200) - bleedRate * dt, 0)
        self.SealStoredBleedRate = bleedRate * math.exp(-(cfg.BLEED_CLOT_RATE or 0.02) * dt)
    end

    local owner = self:GetOwner()
    if bleedRate >= (cfg.HELD_BLEED_FX_MIN_RATE or 0.5) and IsValid(owner) and owner:IsPlayer() and now >= (self.NextHeldSealBleedFX or 0) then
        local intensity = math.Clamp(bleedRate / 25, 0, 1)
        self.NextHeldSealBleedFX = now + Lerp(intensity, 1.05, 0.3)
        local hand = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        local pos = owner:WorldSpaceCenter()
        if hand then
            local handPos = owner:GetBonePosition(hand)
            if isvector(handPos) then pos = handPos end
        end
        local velocity = owner:GetVelocity() * 0.12 + VectorRand() * Lerp(intensity, 6, 20) + Vector(0, 0, -14)
        if HG_EmitSealBlood then HG_EmitSealBlood(owner, pos, velocity, intensity) end
    end

    self:SetNW2Float("SealBlood", math.max(self.SealStoredBlood or 0, 0))
    self:SetNW2Float("SealBleedRate", math.max(self.SealStoredBleedRate or 0, 0))

    local maxBlood = cfg.MAX_BLOOD_ML or 1200
    if (self.SealStoredHealth or cfg.MAX_HEALTH or 100) <= 0 or maxBlood - (self.SealStoredBlood or maxBlood) >= (cfg.FATAL_BLOOD_LOSS_ML or 500) then
        local seal = SpawnPhysicalSeal(self, false)
        if IsValid(seal) then
            seal:KillSeal((self.SealStoredHealth or 0) <= 0 and "damage" or "bloodloss")
            local owner = self:GetOwner()
            if IsValid(owner) and owner:IsPlayer() then owner:SelectWeapon("weapon_hands_sh") end
            self:Remove()
        end
    end
end

function SWEP:Think()
    local now   = CurTime()
    if SERVER then self:UpdateSealPhysiology(now) end
    if not IsValid(self) then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    self.SealLastOwner = owner

    self:SetHold(self.HoldType)

    if SERVER then
        local hp = owner:Health()
        if self._lastHP == -1 then self._lastHP = hp end

        if hp < self._lastHP and self._lastHP > 0 then
            self:SealWake()

            SetSealSkin(self, 3)
            net.Start("SealSkin")
            net.WriteInt(3, 8)
            net.Send(owner)

            timer.Create("SealHurt_" .. self:EntIndex(), 1, 1, function()
                if IsValid(self) and IsValid(owner) then
                    local s = self.Sleeping and 1 or 0
                    SetSealSkin(self, s)
                    net.Start("SealSkin")
                    net.WriteInt(s, 8)
                    net.Send(owner)
                end
            end)
        end
        self._lastHP = hp

        if not self.Sleeping and (now - self.LastActivity) >= 25 and self.CurrentSkin == 0 then
            self.Sleeping = true
            SetSealSkin(self, 1)
            net.Start("SealSkin")
            net.WriteInt(1, 8)
            net.Send(owner)
        end
    end

    if CLIENT then
        if not IsValid(owner) or owner ~= LocalPlayer() then return end

        if not self.Sleeping and self.CurrentSkin == 0 then
            if self.IsBlinking then
                if now >= self.BlinkEnd then
                    self.IsBlinking = false
                    SetSealSkin(self, 0)
                    self.NextBlink = now + math.Rand(2, 5)
                end
            else
                if now >= self.NextBlink then
                    self.IsBlinking = true
                    self.BlinkEnd   = now + 0.15
                    SetSealSkin(self, 1)
                end
            end
        end
    end
end

function SWEP:SealWake()
    timer.Remove("SealDeploySkin_" .. self:EntIndex())
    self.Sleeping         = false
    self.WasAsleepHolster = false
    self.LastActivity     = CurTime()
    self.IsBlinking       = false
    self.NextBlink        = CurTime() + 2
    
    SetSealSkin(self, 0)
    if SERVER then
        net.Start("SealSkin")
        net.WriteInt(0, 8)
        net.Send(self:GetOwner())
    end
end

function SWEP:OnDrop()
    if CLIENT or self.SealConvertedToEntity or self.SealDropPending then return end
    self.SealDropPending = true

    local owner = IsValid(self.SealLastOwner) and self.SealLastOwner or nil
    local pos = self:GetPos()
    local ang = self:GetAngles()
    if IsValid(owner) then
        local rag = owner:GetNWEntity("RagdollDeath")
        if not IsValid(rag) then rag = owner.FakeRagdoll end
        if IsValid(rag) then
            pos = rag:WorldSpaceCenter() + Vector(0, 0, 6)
            ang = rag:GetAngles()
        else
            pos = owner:EyePos()
            ang = owner:EyeAngles()
        end
    end

    timer.Simple(0, function()
        if not IsValid(self) or self.SealConvertedToEntity then return end
        -- If another system re-owned the SWEP during the deferred Homicide drop
        -- cleanup, abort conversion rather than duplicating/removing it in-hand.
        if IsValid(self:GetOwner()) then
            self.SealDropPending = false
            return
        end
        local seal = SpawnPhysicalSeal(self, false, pos, ang, owner)
        if IsValid(seal) then self:Remove() else self.SealDropPending = false end
    end)
end

function SWEP:OnRemove()
    timer.Remove("SealDeploySkin_" .. self:EntIndex())
    timer.Remove("SealHurt_" .. self:EntIndex())
    hook.Remove("Think", "AnimCallback" .. self:EntIndex())
    if self.BaseClass.OnRemove then self.BaseClass.OnRemove(self) end
end

if CLIENT then
    function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
        local deployTime = self.DeployTime or 0
        local delta = CurTime() - deployTime
        
        if delta < 0.5 then
            local progress = delta / 0.5
            progress = math.ease.OutQuad(progress)
            
            local offset = Lerp(progress, -15, 0)
            pos = pos + ang:Up() * offset
        end
        
        return pos, ang
    end

    net.Receive("SealDeploy", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then return end

        surface.PlaySound("sealplush/ohmygah.wav")
        wep.DeployTime = CurTime()
        SetSealSkin(wep, 2)
    end)

    net.Receive("SealSound", function()
        local snd = net.ReadString()
        surface.PlaySound(snd)
    end)

    net.Receive("SealSkin", function()
        local skin = net.ReadInt(8)
        local ply  = LocalPlayer()
        local wep  = ply:GetActiveWeapon()
        if not IsValid(wep) then return end
        SetSealSkin(wep, skin)
    end)
end
