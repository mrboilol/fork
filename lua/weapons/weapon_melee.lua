if SERVER then AddCSLuaFile() end
SWEP.PrintName = "Combat Knife"
SWEP.Instructions = "A military grade combat knife designed to neutralize the enemy during combat operations and special operations."
SWEP.Category = "Weapons - Melee"
SWEP.Instructions = "This is your trusty carbon-steel fixed-blade knife.\n\nLMB to attack.\nR + LMB to change attack mode.\nRMB to block."
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Slot = 1

SWEP.Weight = 0
SWEP.weight = 0.4
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.WorldModel = "models/weapons/combatknife/tactical_knife_iw7_wm.mdl"
SWEP.WorldModelReal = "models/weapons/combatknife/tactical_knife_iw7_vm.mdl"
SWEP.WorldModelExchange = false
SWEP.ViewModel = ""
SWEP.HoldType = "knife"

function SWEP:CanPrimaryAttack()
	return true
end

function SWEP:IsSprinting()
    local owner = self:GetOwner()
    if not IsValid(owner) then return false end
    if not owner.IsSprinting then return false end
    if owner:IsSprinting() and hg.GetCurrentCharacter(owner):IsPlayer() then return true end
end

function SWEP:CanSecondaryAttack()
    if self:GetClass() == "weapon_melee" then return false end
	return true
end

function SWEP:GetStaminaWeightDamageMultiplier(attacktype)
    local weight = self.weight or self.Weight or 0
    local damage = attacktype == true and self.DamageSecondary or self.DamagePrimary or 0
    return 1 + weight * 0.08 + damage * 0.008
end

SWEP.supportTPIK = true
SWEP.ismelee = true
SWEP.ismelee2 = true

SWEP.AttackTime = 0.2
SWEP.DrawAnimTime = 1.25
SWEP.EquipTime = 1
SWEP.AnimTime1 = 0.7
SWEP.WaitTime1 = 0.5
SWEP.AttackLen1 = 55

SWEP.Attack2Time = 0.1
SWEP.AnimTime2 = 0.6
SWEP.WaitTime2 = 0.4
SWEP.HitCooldownEnabled = false
SWEP.HitCooldown = 0.2
SWEP.AttackLen2 = 45

SWEP.DamageType = DMG_SLASH
SWEP.DamagePrimary = 15
SWEP.DamageSecondary = 8
SWEP.ComboEnabled = false
SWEP.ComboResetTime = 1.1
SWEP.ComboDamageMul1 = 1
SWEP.ComboDamageMul2 = 1.25
SWEP.ComboDamageMul3 = 1.65
SWEP.PlayerKnockbackMul = 2
SWEP.PlayerKnockbackUpMul = 0.45
SWEP.PlayerSecondaryKnockbackMul = 0.75
SWEP.RagdollKnockbackMul = 75
SWEP.RagdollKnockbackUpMul = 8
SWEP.RagdollSecondaryKnockbackMul = 0.65
SWEP.RagdollSwingSideMul = 1.25
SWEP.RagdollViewPunchYawMul = 0.08
SWEP.RagdollViewPunchRollMul = 0.04
SWEP.HeadTraceFallbackRadius = 10
SWEP.HeadRagdollChance = 0.55
SWEP.HeadRagdollForceMul = 1.35
SWEP.HeadRagdollUpMul = 1.2
SWEP.HeadRagdollMinDamage = 20

SWEP.PenetrationPrimary = 8
SWEP.PenetrationSecondary = 4

SWEP.MaxPenLen = 6

SWEP.NoReverse = false

SWEP.PenetrationSizePrimary = 0.75
SWEP.PenetrationSizeSecondary = 2.5

SWEP.StaminaPrimary = 10
SWEP.StaminaSecondary = 8.5

SWEP.BlockTier = 1
SWEP.MeleeMaterial = "none"
SWEP.BlockImpactSound = nil

SWEP.ViewPunch1 = Angle(2,0,0)
SWEP.ViewPunch2 = Angle(0,1,0)

SWEP.AttackSize = 5

SWEP.weaponPos = Vector(2,0.1,-0.8)
SWEP.weaponAng = Angle(180,90,90)

SWEP.AnimList = {
    ["idle"] = "vm_knifeonly_idle",
    ["deploy"] = "vm_knifeonly_raise",
    ["attack"] = "vm_knifeonly_stab",
    ["attack2"] = "vm_knifeonly_swipe",
}

SWEP.Attack_Charge_Begin = "Attack_Charge_Begin"
SWEP.Attack_Charge_Idle = "Attack_Charge_Idle"
SWEP.Attack_Charge_End = "Attack_Charge_End"

SWEP.HeavyAttackDamageMul = 2.0
SWEP.HeavyAttackWaitTime = 1.0
SWEP.HeavyAttackAnimTimeBegin = 1.0
SWEP.HeavyAttackAnimTimeIdle = 0.5
SWEP.HeavyAttackAnimTimeEnd = 0.5

SWEP.HeavyAttackStamina = 20
SWEP.HeavyAttackDelay = 0.5 -- Slower swing
SWEP.HeavyAttackTimeLength = 0.4 -- Longer hit window
SWEP.HeavyAttackViewPunch = Angle(2, 2, 0)
SWEP.HeavyAttackMaxChargeTime = 2.0 -- Time to reach max damage
SWEP.HeavyAttackAfterGetupCooldown = 2.0
SWEP.HeavyAttackGetupNWKey = "HGHeavyGetupCooldown"

SWEP.HeavyAttackSwingAng = 0
SWEP.HeavyAttackRads = 65
SWEP.HeavyAttackDamageType = nil -- Damage type for heavy attack (nil = use Primary)

SWEP.CanHeavyAttack = false
local MELEE_GLOBAL_KNOCKBACK_MUL = 0.7
local MELEE_GLOBAL_ACCURACY_MUL = 0.75
local MELEE_GLOBAL_DAMAGE_MUL = 0.6

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/hud/tfa_iw7_tactical_knife")
	SWEP.IconOverride = "vgui/hud/tfa_iw7_tactical_knife.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.AttackSwing = "weapons/slam/throw.wav" --!! заменить звуки
SWEP.SwingSound = nil
SWEP.SwingSoundPitch = nil
SWEP.AttackHit = "snd_jack_hmcd_knifehit.wav"
SWEP.Attack2Hit = "snd_jack_hmcd_knifehit.wav"
SWEP.AttackHitFlesh = "snd_jack_hmcd_knifestab.wav"
SWEP.HitFleshExtra = nil
SWEP.HitFleshExtraPitch = nil
SWEP.HitFleshPlus = nil
SWEP.Attack2HitFlesh = "snd_jack_hmcd_slash.wav"
SWEP.DeploySnd = "snd_jack_hmcd_knifedraw.wav"
SWEP.swingsoundextra = nil
SWEP.hitsoundextra = nil
SWEP.hitsoundplus = nil
SWEP.hitsoundbrutalize = nil
SWEP.BrutalizeSkullThreshold = 0.99
SWEP.BrutalizeHitVolumeMul = 0.5

SWEP.setlh = false
SWEP.setrh = true
SWEP.TwoHanded = false

SWEP.attack_ang = Angle(-55,-3,0)
SWEP.sprint_ang = Angle(30,0,0)

SWEP.HoldPos = Vector(-10,3,-2)
SWEP.HoldAng = Angle(-10,5,0)
SWEP.HeavyChargeHoldPos = Vector(0,0,0)
SWEP.HeavyChargeHoldAng = Angle(0,0,0)
SWEP.HeavyChargeStaminaDrainPerSecond = 5

SWEP.basebone = 1

SWEP.AttackPos = Vector(0,0,-10)
SWEP.AttackingPos = Vector(16,0,0)

SWEP.WorkWithFake = true

function SWEP:SetHold(value)
    self:SetWeaponHoldType(value)
    self:SetHoldType(value)
    self.holdtype = value
end

function SWEP:KeyDown(key)
	return hg.KeyDown(self:GetOwner(),key)
end

function SWEP:IsEquipLocked()
    return (self.EquipLockEnd or 0) > CurTime()
end

function SWEP:InUse()
	local ply = self:GetOwner()

    if !IsValid(ply) then return false end
    
    local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
	local org = ply.organism
    
	local power = ply:GetNWFloat("power", 1)

	if power < 0.4 and ent != ply then
		return false
	end

	return ( ((not ply.InVehicle || !ply:InVehicle()) and !hg.RagdollCombatInUse(ply)) && self:KeyDown(IN_USE)) || ((ply.InVehicle && ply:InVehicle() or hg.RagdollCombatInUse(ply) or ent == ply) && not self:KeyDown(IN_USE)) || (IsValid(ply.OldRagdoll))
end

SWEP.modelscale = 1
SWEP.modelscale2 = 1


if CLIENT then
    function PrintBones( entity )
        for i = 0, entity:GetBoneCount() - 1 do
            print( i, entity:GetBoneName( i ) )
        end
    end

    function PrintAnims( entity )
        PrintTable(entity:GetSequenceList())
    end

	function SWEP:GetWM()
        if IsValid(self.worldModel) then
            return self.worldModel
        else
            self.worldModel = ClientsideModel(self.WorldModel)
            self.worldModel:SetNoDraw(true)
            self.worldModel:SetupBones()
            self:CallOnRemove("remove_worldmodel1",function()
                if IsValid(model) then
                    model:Remove()
                    model = nil
                end
            end)
        end
		return self.worldModel
	end

	local npcang = Angle(0, 0, 180)
    function SWEP:DrawWorldModel()
		local ent = self:GetOwner()
        if not IsValid(ent) then
            self:DrawWorldModel2()
        end
        
        if ent:IsNPC() then
			local RHand = ent:LookupBone("ValveBiped.Bip01_R_Hand")
			if not RHand then return end
			local RForearm = ent:LookupBone("ValveBiped.Bip01_R_Forearm")
			local matrixR = ent:GetBoneMatrix(RHand) or (RForearm and ent:GetBoneMatrix(RForearm) or nil)
			if not matrixR then 
				//matrixR = Matrix()
				//local att = ent:GetAttachment(ent:LookupAttachment("anim_attachment_RH"))
				//matrixR:SetTranslation(att.Pos)
				//matrixR:SetAngles(att.Ang)
				return
			end

			matrixR:Rotate(npcang)

			if not IsValid(self.NPCworldModel) then
				self.NPCworldModel = ClientsideModel(self.WorldModelExchange and self.WorldModelExchange or self.WorldModel)
				self:CallOnRemove("remove_npcworldmodel1",function()
					if IsValid(self.NPCworldModel) then
						self.NPCworldModel:Remove()
						self.NPCworldModel = nil
					end
				end)
			end

			local WorldModel = self.NPCworldModel
			WorldModel:SetNoDraw(true)
			WorldModel:SetModelScale(self.modelscale2)
			WorldModel:SetRenderOrigin(matrixR:GetTranslation())
			WorldModel:SetRenderAngles(matrixR:GetAngles())
            WorldModel:SetPos(matrixR:GetTranslation())
            WorldModel:SetAngles(matrixR:GetAngles())
			WorldModel:SetupBones()
			WorldModel:DrawModel()
        end
    end

    SWEP.Current = 1

	function SWEP:DrawWorldModel2()
		local owner = self:GetOwner()
        
        if not IsValid(self.worldModel) then
            self.worldModel = self:GetWM()
        end
        
        self.worldModel:SetNoDraw(true)
        
        if IsValid(owner) and (not owner.shouldTransmit or owner.NotSeen) then return end
        if not IsValid(owner) and (not self.shouldTransmit or self.NotSeen) then return end

		local WorldModel = self.worldModel
        
        self.worldModel:SetModelScale(self.modelscale2)
        local ent = hg.GetCurrentCharacter(owner)

        local inuse = self:InUse()

        if IsValid(owner) then
            local timing = 0
            
            local animCalcTime = CurTime()
            if self.FreezeTime then
                if animCalcTime < self.FreezeTime + self.FreezeDuration then
                    animCalcTime = self.FreezeTime
                elseif self.FadeDuration and animCalcTime < self.FreezeTime + self.FreezeDuration + self.FadeDuration then
                    local fadeProgress = (animCalcTime - (self.FreezeTime + self.FreezeDuration)) / self.FadeDuration
                    local advancedTime = 0.5 * self.FadeDuration * fadeProgress * fadeProgress
                    animCalcTime = self.FreezeTime + advancedTime
                else
                     local totalLost = self.FreezeDuration + (self.FadeDuration and (0.5 * self.FadeDuration) or 0)
                     self.animtime = self.animtime + totalLost
                     self.FreezeTime = nil
                     self.FreezeDuration = nil
                     self.FadeDuration = nil
                end
            end

            if not self.cycling then
                local dtime = SysTime() - (self.lasthuyhuy or SysTime())
                self.lasthuyhuy = SysTime()
                
                if self.stopanim and self.stopanim > 0 then
                    self.animtime = self.animtime + dtime * game.GetTimeScale()
                    self.stopanim = self.stopanim - dtime * game.GetTimeScale()
                else
                    self.stopanim = nil
                end

                local timing = (1 - math.Clamp((self.animtime - animCalcTime) / self.animspeed, 0, 1))
                timing = self.reverseanim and (1 - timing) or timing
                WorldModel:SetCycle(timing)
                --PrintTable( WorldModel:GetSequenceList() )
                
                if self.callback and timing == ((not self.reverseanim) and 1 or 0) then
                    self.callback(self)
                    self.callback = nil
                end
            else
                local timing = ((animCalcTime - (self.animtime - self.animspeed))%self.animspeed) / self.animspeed
                WorldModel:SetCycle(timing)
            end


            local pos, ang = self:ModelAnim(WorldModel)

            self.ShakePos = self.ShakePos or Vector(0, 0, 0)
            self.ShakeAng = self.ShakeAng or Angle(0, 0, 0)

            local targetShakePos = Vector(0, 0, 0)
            local targetShakeAng = Angle(0, 0, 0)

            if self.FreezeTime and self.FreezeDuration and (CurTime() < self.FreezeTime + self.FreezeDuration) then
                targetShakePos = VectorRand() * 0.02
                targetShakeAng = Angle(math.Rand(-1,1), math.Rand(-1,1), math.Rand(-1,1)) * 0.5
            end

            self.ShakePos = LerpVector(FrameTime() * 15, self.ShakePos, targetShakePos)
            self.ShakeAng = LerpAngle(FrameTime() * 15, self.ShakeAng, targetShakeAng)

            pos = pos + self.ShakePos
            ang = ang + self.ShakeAng

			WorldModel:SetRenderOrigin(pos)
            WorldModel:SetRenderOrigin(pos)
			WorldModel:SetRenderAngles(ang)
            WorldModel:SetPos(pos)
            WorldModel:SetAngles(ang)
		else
            WorldModel:SetRenderOrigin(self:GetPos())
			WorldModel:SetRenderAngles(self:GetAngles())
            WorldModel:SetPos(self:GetPos())
            WorldModel:SetAngles(self:GetAngles())
		end

        WorldModel:SetupBones()
        
        if IsValid(owner) and !inuse then
            local bon = ent:LookupBone("ValveBiped.Bip01_R_Hand")
            if not bon then return end
            local mat = ent:GetBoneMatrix(bon)
            if not mat then return end

            local pos, ang = mat:GetTranslation(), mat:GetAngles()
            //local oldpos, oldang = WorldModel:GetPos(), WorldModel:GetAngles()

            //self.Current = LerpFT(0.1, self.Current,  and 1 or 0)
            
            //local pos = Lerp(self.Current, oldpos, pos)
            //local ang = Lerp(self.Current, oldang, ang)

            WorldModel:SetRenderOrigin(pos)
			WorldModel:SetRenderAngles(ang) 
            WorldModel:SetPos(pos)
            WorldModel:SetAngles(ang)

            local bon = WorldModel:LookupBone("ValveBiped.Bip01_R_Hand")
            if not bon then return end
            local matW = WorldModel:GetBoneMatrix(bon)

            if !matW then return end

            local invmat = mat * matW:GetInverse()

            for i = 0, WorldModel:GetBoneCount() - 1 do
                local mata = WorldModel:GetBoneMatrix(i)
                if !mata then continue end
                mata = invmat * mata
                WorldModel:SetBoneMatrix(i, mata)
            end
        end

        if not self.WorldModelExchange then
            WorldModel:DrawModel()
        end

        if IsValid(self.worldModel) and self.WorldModelExchange then
            if not IsValid(self.worldModel2) then
                self.worldModel2 = ClientsideModel(self.WorldModelExchange)
                self.worldModel2:SetNoDraw(true)
                self.worldModel2:SetupBones()
                local model = self.worldModel2

                self:CallOnRemove("remove_worldmodel2",function()
                    if IsValid(model) then
                        model:Remove()
                        model = nil
                    end
                end)
            end

            self.worldModel2:SetNoDraw(true)

            local pos,ang = self.worldModel:GetPos(),self.worldModel:GetAngles()
            local huy = self.worldModel:GetModel() == self.WorldModelReal
            
            if (IsValid(self:GetOwner()) or self.DontChangeDropped) then
                local mat = self.worldModel:GetBoneMatrix(self.basebone or 1)
                pos,ang = LocalToWorld(self.weaponPos,self.weaponAng,huy and mat and mat:GetTranslation() or self.worldModel:GetPos(),huy and mat and mat:GetAngles() or self.worldModel:GetAngles())
            end

            self.worldModel2:SetModelScale(self.modelscale)
            self.worldModel2:SetRenderOrigin(pos)
            self.worldModel2:SetRenderAngles(ang)
            self.worldModel2:SetPos(pos)
            self.worldModel2:SetAngles(ang)
            self.worldModel2:SetupBones()
            self.worldModel2:DrawModel()
        end
		
		if(self.DrawPostWorldModel)then
			self:DrawPostWorldModel()
		end

        if self:WaterLevel() > 0 then
            ClearDecalToEnt(IsValid(self.worldModel2) and self.worldModel2 or self.worldModel, self:EntIndex())
        end
	end
end

local addAng = Angle()
local addPos = Vector()

local vechuy = Vector()

local addPosLerp = Vector()
local addAngLerp = Angle()

SWEP.BlockPushPos = Vector(0,0,0)
SWEP.BlockPushVel = Vector(0,0,0)
SWEP.BlockPushAng = Angle(0,0,0)
SWEP.BlockPushAngVel = Angle(0,0,0)

function SWEP:AddBlockPush(normal)
    -- normal is the direction of the attack (world space)
    -- We want to push the viewmodel in that direction relative to the player
    
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    
    local eyeAng = ply:EyeAngles()
    local localDir = WorldToLocal(ply:GetPos() + normal * 10, Angle(0,0,0), ply:GetPos(), eyeAng)
    localDir:Normalize()
    
    -- Push back (negative x/y? check coord system)
    -- Usually X is forward/back, Y is right/left, Z is up/down in Source Viewmodels? 
    -- Actually in ModelAnim addPos:
    -- addPos.x = addPos.x + eyeAng[1] * 0.05
    -- addPos.y = addPos.y - angle_difference.y * 2
    
    -- Let's apply a force.
    -- If hit from front (normal points to me), localDir.x should be negative.
    
    self.BlockPushVel = self.BlockPushVel + localDir * 40 -- Strength
    
    -- Add some random rotation
    self.BlockPushAngVel = self.BlockPushAngVel + Angle(math.Rand(-20,20), math.Rand(-10,10), math.Rand(-20,20))
end

function SWEP:UpdateBlockPush()
    local dt = FrameTime()
    
    -- Spring constants
    local stiffness = 100
    local damping = 10
    
    -- Position Spring
    local force = -self.BlockPushPos * stiffness
    self.BlockPushVel = self.BlockPushVel + force * dt
    self.BlockPushVel = self.BlockPushVel - self.BlockPushVel * damping * dt
    self.BlockPushPos = self.BlockPushPos + self.BlockPushVel * dt
    
    -- Angle Spring
    local torque = -self.BlockPushAng * stiffness
    self.BlockPushAngVel = self.BlockPushAngVel + torque * dt
    self.BlockPushAngVel = self.BlockPushAngVel - self.BlockPushAngVel * damping * dt
    self.BlockPushAng = self.BlockPushAng + self.BlockPushAngVel * dt
end

function SWEP:CustomBlockAnim(addPosLerp, addAngLerp)
    return false
end

SWEP.SuicidePos = Vector(5, -24, 5)
SWEP.SuicideAng = Angle(0, 90, 20)
SWEP.SuicideCutVec = Vector(2, -5, 6)
SWEP.SuicideCutAng = Angle(10, 0, 0)
SWEP.SuicideTime = 0.5

SWEP.CanSuicide = false -- for weapon_melee its configured in Initialize

function SWEP:ModelAnim(model, pos, ang)
    local owner = self:GetOwner()

    if !IsValid(owner) or !owner:IsPlayer() then return end

    local ent = hg.GetCurrentCharacter(owner)
    local tr = hg.eyeTrace(owner, 20, ent)
    local eyeAng = owner:EyeAngles()

    local vel = ent:GetVelocity()
    local vellen = vel:Length()

    local vellenlerp = self.velocityAdd and self.velocityAdd:Length() or vellen

    if !tr then return end

    if CLIENT then
        self.BlockPushPos = self.BlockPushPos or Vector(0,0,0)
        self.BlockPushVel = self.BlockPushVel or Vector(0,0,0)
        self.BlockPushAng = self.BlockPushAng or Angle(0,0,0)
        self.BlockPushAngVel = self.BlockPushAngVel or Angle(0,0,0)

        self:UpdateBlockPush()
        addPos:Add(self.BlockPushPos)
        addAng:Add(self.BlockPushAng)
    end

    local dtime = SysTime() - (self.timetick2 or SysTime() + 0.015)

    self.walkLerped = LerpFT(0.1, self.walkLerped or 0, (owner:InVehicle()) and 0 or vellenlerp * 200)
	self.walkTime = self.walkTime or 0
    
	local walk = math.Clamp(self.walkLerped / 200, 0, 1)
	
	self.walkTime = self.walkTime + walk * dtime * 7 * game.GetTimeScale() * (owner:OnGround() and 1 or 0)
    
    self.velocityAdd = self.velocityAdd or Vector()
    self.velocityAddVel = self.velocityAddVel or Vector()

    //vel.z = vel.z + ((owner:IsFlagSet(FL_ANIMDUCKING) and !owner:IsFlagSet(FL_DUCKING)) and (100) or (!owner:IsFlagSet(FL_ANIMDUCKING) and owner:IsFlagSet(FL_DUCKING)) and (-100) or 0)
    self.velocityAddVel = LerpFT(0.9, self.velocityAddVel * 0.99, -vel * 0.01)
    self.velocityAddVel[3] = self.velocityAddVel[3]

    self.velocityAdd = LerpFT(0.03, self.velocityAdd, self.velocityAddVel)

	local huy = self.walkTime
	
	local x, y = math.cos(huy) * math.sin(huy) * walk + math.cos(CurTime() * 5) * walk * math.sin(CurTime() * 2) * 0.5, math.sin(huy) * walk * 1 + math.sin(CurTime() * 5) * walk * math.cos(CurTime() * 4) * 0.5
    
    addPos:Zero()
    addAng:Zero()
    addPosLerp:Zero()
    addAngLerp:Zero()

    addPosLerp.z = addPosLerp.z + ((hg.KeyDown(owner, IN_DUCK)) and -2 or 0)

    local chargeState = self.CanHeavyAttack and ((self.GetChargeState and self:GetChargeState()) or self:GetDTInt(6)) or 0
    local isChargingHeavy = chargeState == 1 or chargeState == 2

    if isChargingHeavy then
        addPosLerp:Add(self.HeavyChargeHoldPos or Vector(0,0,0))
        local chargeHoldAng = self.HeavyChargeHoldAng or Angle(0,0,0)
        addAngLerp.p = addAngLerp.p + chargeHoldAng.p
        addAngLerp.y = addAngLerp.y + chargeHoldAng.y
        addAngLerp.r = addAngLerp.r + chargeHoldAng.r
    end

    if !self:CustomBlockAnim(addPosLerp, addAngLerp) then
        addPosLerp.z = addPosLerp.z + (self:GetBlocking() and -2 or 0)
        addPosLerp.x = addPosLerp.x + (self:GetBlocking() and -4 or 0)
        addPosLerp.y = addPosLerp.y + (self:GetBlocking() and 8 or 0)
        addAngLerp.r = addAngLerp.r + (self:GetBlocking() and -30 or 0)
    end

    if owner:GetNWFloat("InLegKick",0) > CurTime() + 0.1 then
       addAngLerp.p = addAngLerp.p - math.min(math.abs(math.max(eyeAng.p,0)),25)
    end

    addPosLerp.x = addPosLerp.x - 20 * math.max(0.5 - tr.Fraction,0)

    if self.CanSuicide and owner.suiciding then
        addPosLerp:Set(self.SuicidePos)
        addAngLerp:Set(self.SuicideAng)
    end

    self.lerpedAddPos = LerpFT(0.06, self.lerpedAddPos or Vector(), addPosLerp)
    self.lerpedAddAng = LerpFT(0.06, self.lerpedAddAng or Angle(), addAngLerp)

    if self:IsLocal() then
        addPos.z = x * 2 * vellenlerp * 0.3 - vellenlerp * 1
        addPos.y = y * 2 * vellenlerp * 0.3
    
        addAng.z = -x * 2// * vellenlerp * 0.3
        addAng.y = -y * 2// * vellenlerp * 0.3

        addPos.y = addPos.y - angle_difference.y * 2
        addAng.y = addAng.y + angle_difference.y * 4

        addPos.z = addPos.z + angle_difference.p * 2
        addAng.p = addAng.p + angle_difference.p * 4

        addAng.p = addAng.p + math.cos(CurTime() * 2) * 1

        //addPos.z = addPos.z + eyeAng[1] * 0.05
        addPos.x = addPos.x + eyeAng[1] * 0.05

        local veldot = self.velocityAdd:Dot(eyeAng:Right())
        
        addAng.r = addAng.r - veldot * 5 + math.cos(CurTime() * 5) * walk * 2 - angle_difference.y * 2

        //addAng.p = addAng.p + math.cos(CurTime() * 2) * 1
    end

    self.lastAddPos = addPos

    //local inattack1 = self:GetAttackType() == 1 and math.max(self:GetLastAttack() - CurTime(),0) / self.AttackTime > 0 or false
    //local inattack2 = self:GetAttackType() == 2 and math.max(self:GetLastAttack() - CurTime(),0) / self.AttackTime > 0 or false

    //self.attackanim = LerpFT(0.1, self.attackanim, (inattack1 and 0.8 or 0) - (inattack2 and 0.3 or 0))
    //self.sprintanim = LerpFT(0.05, self.sprintanim, self:IsSprinting() and 1 or 0)

    local hpos = self.HoldPos
    local hang = self.HoldAng
    
    if self.SuicideStart and self.SuicideStart + self.SuicideTime > CurTime() then
        local animpos = (1 - math.Clamp((self.SuicideStart + self.SuicideTime - CurTime()) / self.SuicideTime, 0, 1))
        animpos = math.ease.OutElastic(animpos)
        
        addPos:Add(self.SuicideCutVec * animpos)
        addAng:Add(self.SuicideCutAng * animpos)
    end

    if self.cutthroat then
        local animpos = math.Clamp((self.cutthroat - CurTime() + 1) / 1, 0, 1)
        animpos = math.ease.InOutCubic(animpos)
        addPos:Add(self.SuicideCutVec * animpos)
        addAng:Add(self.SuicideCutAng * animpos)
    end

    local pos, ang = LocalToWorld(hpos + addPos + self.lerpedAddPos, hang + addAng + self.lerpedAddAng, tr.StartPos + self.velocityAdd, eyeAng)

	self.timetick2 = SysTime()

    return pos, ang
end

SWEP.KickAng = Angle(0,0,0)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeVPShouldUseHand = false
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_Forearm"

--hook.Add("PostDrawPlayerRagdoll","ragdollhuymelee",function(ent,ply)
function hg.RenderMelees(ent, ply, wep)
    if wep.DrawWorldModel2 then
        wep:DrawWorldModel2()
    else
        wep:DrawWorldModel()
    end
end
--end)

local host_timescale = game.GetTimeScale

function SWEP:Camera(eyePos, eyeAng, view, vellen)
    //self:SetHandPos()
    self:DrawWorldModel2()

    local WorldModel = self.worldModel

    if not IsValid(WorldModel) then return end

    local camBone = (WorldModel:LookupBone(self.FakeViewBobBone) or (self.FakeVPShouldUseHand and WorldModel:LookupBone("ValveBiped.Bip01_R_Hand") or WorldModel:LookupBone("Weapon"))) or WorldModel:LookupBone("ValveBiped.Bip01_R_Hand")
    
    if camBone then
        local matrix = WorldModel:GetBoneMatrix(camBone)

        if matrix then
            local gAngles = matrix:GetAngles()
            local _,gAngles = WorldToLocal(vector_origin, gAngles, eyePos, eyeAng)
            self.OldAngPunch = self.OldAngPunch or gAngles
            local punch = ( self.OldAngPunch - gAngles ) / (self.ViewPunchDiv or 120)
            
            self.punch = punch

            //ViewPunch2( -punch )
            ViewPunch( punch )
            
            self.OldAngPunch = gAngles
        end
    end

    local owner = self:GetOwner()
    if not owner.InVehicle then return end

    view.origin = eyePos - (angle_difference_localvec * 150) - (position_difference * 0.5)
    view.angles = eyeAng
    
    local lpos = self.lastAddPos or vector_origin
    //view.angles[1] = view.angles[1] + lpos.z * 1
    //view.angles[2] = view.angles[2] + lpos.y * 1
    
    return view
end

local ang180, ang1 = Angle(0,180,0), Angle(-135,-90,0)
function SWEP:SetHandPos(noset)
	local ply = self:GetOwner()
	local owner = self:GetOwner()

    self.rhandik = false
	self.lhandik = false
    
    if not IsValid(ply) or not IsValid(self.worldModel) then return end
    if not ply.shouldTransmit or ply.NotSeen then return end

    local ent = hg.GetCurrentCharacter(ply)

	local bones = hg.TPIKBonesLH

    local ply_spine_index = ent:LookupBone("ValveBiped.Bip01_Spine4")
    if !ply_spine_index then return end
    local ply_spine_matrix = ent:GetBoneMatrix(ply_spine_index)
    if !ply_spine_matrix then return end
    local wmpos = ply_spine_matrix:GetTranslation()

	local wm = self:GetWM()
	if !IsValid(wm) then return end
	-- ent:SetupBones()

	self.rhandik = self.setrh and IsValid(owner)//self.setrh
	self.lhandik = self.setlh and IsValid(owner) and (ply:GetTable().ChatGestureWeight < 0.1) and hg.CanUseLeftHand(ply) and !(owner.suiciding and self.SuicideNoLH)

    local rhBone = ent:LookupBone("ValveBiped.Bip01_R_Hand")
    local lhBone = ent:LookupBone("ValveBiped.Bip01_L_Hand")
    local rhmat = rhBone and ent:GetBoneMatrix(rhBone) or nil
    local lhmat = lhBone and ent:GetBoneMatrix(lhBone) or nil

	ply.rhold = rhmat
	ply.lhold = lhmat

	if self.lhandik and self:InUse() then
		for _, bone in ipairs(bones) do
			local wm_boneindex = wm:LookupBone(bone)
			if !wm_boneindex then continue end
			local wm_bonematrix = wm:GetBoneMatrix(wm_boneindex)
			if !wm_bonematrix then continue end
			
			local ply_boneindex = ent:LookupBone(bone)
			if !ply_boneindex then continue end
			local ply_bonematrix = ent:GetBoneMatrix(ply_boneindex)
			if !ply_bonematrix then continue end

			local bonepos = wm_bonematrix:GetTranslation()
			local boneang = wm_bonematrix:GetAngles()

			bonepos.x = math.Clamp(bonepos.x, wmpos.x - 38, wmpos.x + 38)
			bonepos.y = math.Clamp(bonepos.y, wmpos.y - 38, wmpos.y + 38)
			bonepos.z = math.Clamp(bonepos.z, wmpos.z - 38, wmpos.z + 38)

			ply_bonematrix:SetTranslation(bonepos)
			ply_bonematrix:SetAngles(boneang)
			
            --if bone == "ValveBiped.Bip01_L_Hand" then lhmat = ply_bonematrix end
			ent:SetBoneMatrix(ply_boneindex, ply_bonematrix)
			--ent:SetBonePosition(ply_boneindex, bonepos, boneang)
		end
    else
        if ply == ent then
            local ply_spine_index = ply:LookupBone("ValveBiped.Bip01_Spine4")
            if !ply_spine_index then return end
            local ply_spine_matrix = ply:GetBoneMatrix(ply_spine_index)
            if !ply_spine_matrix then return end
            local wmpos = ply_spine_matrix:GetTranslation() - ply:EyeAngles():Right() * 5

            local tr = {}
            tr.start = wmpos
            tr.endpos = wmpos + ply:GetAimVector() * 30
            tr.filter = ply

            local trace = util.TraceLine(tr)

            if trace.Hit then
                hg.DragLeftHand(ply, self, trace.HitPos - ply:GetAimVector() * 5, ply:GetAimVector(), (trace.Entity:IsWorld() and Lerp(1, trace.HitNormal:Angle(), ply:EyeAngles() + ang180) or ply:EyeAngles() + ang180) + ang1 - ply:EyeAngles())
            end
        end
    end

	local bones = hg.TPIKBonesRH

	if self.rhandik and self:InUse() then
		for _, bone in ipairs(bones) do
			local wm_boneindex = wm:LookupBone(bone)
			if !wm_boneindex then continue end
			local wm_bonematrix = wm:GetBoneMatrix(wm_boneindex)
			if !wm_bonematrix then continue end
			
			local ply_boneindex = ent:LookupBone(bone)
			if !ply_boneindex then continue end
			local ply_bonematrix = ent:GetBoneMatrix(ply_boneindex)
			if !ply_bonematrix then continue end

			local bonepos = wm_bonematrix:GetTranslation()
			local boneang = wm_bonematrix:GetAngles()

			bonepos.x = math.Clamp(bonepos.x, wmpos.x - 38, wmpos.x + 38)
			bonepos.y = math.Clamp(bonepos.y, wmpos.y - 38, wmpos.y + 38)
			bonepos.z = math.Clamp(bonepos.z, wmpos.z - 38, wmpos.z + 38)

			ply_bonematrix:SetTranslation(bonepos)
			ply_bonematrix:SetAngles(boneang)

            --if bone == "ValveBiped.Bip01_R_Hand" then rhmat = ply_bonematrix end
            ent:SetBoneMatrix(ply_boneindex, ply_bonematrix)
			--ent:SetBonePosition(ply_boneindex, bonepos, boneang)
		end
	end

    --return rhmat,lhmat
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Blocking")
	self:NetworkVar("Float", 1, "LastBlocked")
	self:NetworkVar("Float", 2, "StartedBlocking")
    self:NetworkVar("Float", 3, "AttackWait")
    self:NetworkVar("Float", 4, "LastAttack")
    self:NetworkVar("Int", 5, "AttackType")
	self:NetworkVar("Bool", 6, "InAttack")
    self:NetworkVar("Float", 7, "AttackLength")
    self:NetworkVar("Float", 8, "AttackTime")
    
    self:NetworkVar("Int", 6, "ChargeState") -- 0: None, 1: Begin, 2: Idle, 3: Attack
    self:NetworkVar("Float", 9, "NextChargeStateTime")
    self:NetworkVar("Float", 10, "ChargeStartTime")
end

function SWEP:OwnerChanged()
    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self.EquipLockEnd = CurTime() + math.max(self.EquipTime or 1, 0)
        self:PlayAnim("deploy", self.DrawAnimTime or 1.25, false, nil, false, true)
        self:SetHold(self.HoldType)
        self:ResetCombo()
        timer.Simple(0,function() self.picked = true end)
    else
        self:SetInAttack(false)
        self:ResetCombo()
        timer.Simple(0,function() self.picked = nil end)
    end
end

function SWEP:OnRemove()
    if CLIENT then
        timer.Remove("hg_melee_hitstop_" .. self:EntIndex())
    end
    if IsValid(self.worldModel) then
        self.worldModel:Remove()
    end
end
SWEP.Initialzed = false
function SWEP:Deploy()
    if SERVER and self.Initialzed and not self:GetOwner().noSound then self:GetOwner():EmitSound(self.DeploySnd,65) end
    self.Initialzed = true
    self:ResetCombo()
    self:PlayAnim("deploy", 1, false, nil, false)
    self:SetHold(self.HoldType)
	
	return true
end

function SWEP:Holster(wep)
    self:SetInAttack(false)
    self:ResetCombo()
    return true
end

function SWEP:OnDrop()
    self:SetInAttack(false)
    if self.CanHeavyAttack then
        if self.SetChargeState then self:SetChargeState(0) else self:SetDTInt(6, 0) end
        self.HeavyAttackFeintBlockUntilRelease = false
        if CLIENT then
            self.ShakePos = Vector(0,0,0)
            self.ShakeAng = Angle(0,0,0)
        end
    end
end

function SWEP:IsEntSoft(ent)
	return ent:IsNPC() or ent:IsPlayer() or hg.RagdollOwner(ent) or ent:IsRagdoll()
end

function SWEP:IsHitCooldownTarget(ent)
    return IsValid(ent) and (ent:IsPlayer() or ent:IsRagdoll() or IsValid(hg.RagdollOwner(ent)))
end

function SWEP:ApplyHitCooldown()
    if not self.HitCooldownEnabled then return end
    if self.HitCooldown == nil then return end
    local owner = self:GetOwner()
    local mul = 1
    if IsValid(owner) and owner.organism then
        mul = 1 / math.Clamp((180 - owner.organism.stamina[1]) / 90, 1, 2)
    end
    self:SetAttackWait(self.HitCooldown / mul)
    self.attackwait = self.HitCooldown / mul
end

function SWEP:ThinkAdd()
end

function SWEP:Think()
    self:CustomThink()
end

if CLIENT then
    local sensitivity = 1

    function SWEP:AdjustMouseSensitivity()
        local owner = self:GetOwner()
        local ent = hg.GetCurrentCharacter(owner)

        local time = math.max(self:GetLastAttack() - CurTime(),0)

        local inattack1 = time / self.AttackTimeLength
        local inattack2 = time / self.Attack2TimeLength
        local mul = self:GetAttackType() == 1 and inattack1 or inattack2

        mul = math.max( (math.max(math.min(mul,self.MinSensivity or 0.35),0)) - (self.MinSensivity/10) ,0 )
        mul = 1-(mul)
		if self.GetBlocking and self:GetBlocking() then
			mul = math.Clamp(mul * 0.35, 0.2, 1)
		end

        sensitivity = math.min(sensitivity, mul)
        sensitivity = LerpFT(0.02, sensitivity, mul)
        
        return IsValid(ent) and ent:IsPlayer() and sensitivity
    end

end

SWEP.BrokenArmPenalty = {
    DamageMultiplier = 0.4, -- 40% damage (60% reduction)
    StaminaMultiplier = 1.5, -- 50% more stamina
    SwingSpeedMultiplier = 0.5, -- 50% slower
    BlockDurationMultiplier = 0.5, -- 50% shorter block
    PainOnBlock = 8, -- pain when blocking with damaged arms
    PainOnHit = 5 -- pain when hitting with damaged arms
}

function SWEP:HasBrokenArm(owner)
    if not IsValid(owner) or not owner.organism then return false end
    local org = owner.organism
    
    -- For one-handed weapons, only check right arm (left arm doesn't affect one-handed grip)
    if not self.TwoHanded then
        return (org.rarm and org.rarm >= 1) or org.rarmdislocation
    end
    
    -- For two-handed weapons, check both arms
    return (org.larm and org.larm >= 1) or (org.rarm and org.rarm >= 1) or org.larmdislocation or org.rarmdislocation
end

function SWEP:GetArmDamagePercent(owner)
    if not IsValid(owner) or not owner.organism then return 0 end
    local org = owner.organism
    local damage = 0
    
    if not self.TwoHanded then
        -- For one-handed: only check right arm (left arm doesn't affect one-handed grip)
        local rarmDamage = (org.rarm or 0)
        local rarmDisloc = org.rarmdislocation and 0.5 or 0
        damage = rarmDamage + rarmDisloc
    else
        -- For two-handed: average both arms
        local larmDamage = (org.larm or 0) + (org.larmdislocation and 0.5 or 0)
        local rarmDamage = (org.rarm or 0) + (org.rarmdislocation and 0.5 or 0)
        damage = (larmDamage + rarmDamage) / 2
    end
    
    return math.min(damage, 1)
end

function SWEP:MultiplyDMG(owner, ent, vellen, mul)
    if owner.organism and owner.organism.stamina and owner.organism.stamina[1] then
        mul = mul * 1 / math.Clamp((180 - owner.organism.stamina[1]) / 90,1,1.3)
    end
    mul = mul * math.Clamp(vellen / 250, 0.9, 1.25)
    mul = mul * (ent ~= owner and 0.75 or 1)
    mul = mul * MELEE_GLOBAL_DAMAGE_MUL
    mul = mul * (owner.MeleeDamageMul or 1)

    if owner.organism.superfighter then
        mul = mul * 5
    end

    if owner:IsBerserk() then
        mul = mul * (1 + owner.organism.berserk)
    end

    if self:GetAttackType() == 3 then
        local startTime = self.GetChargeStartTime and self:GetChargeStartTime() or self:GetDTFloat(10)
        local chargeTime = startTime > 0 and (CurTime() - startTime) or 0
        local chargeProgress = math.Clamp(chargeTime / self.HeavyAttackMaxChargeTime, 0, 1)
        
        -- Start at 1.0 (normal damage), ramp up to HeavyAttackDamageMul (2.0)
        local bonus = (self.HeavyAttackDamageMul - 1.0) * chargeProgress
        mul = mul * (1.0 + bonus)
    end

    if self:GetInAttack() and self.MouseSwayAccumulator then
        local swayBonus = math.Clamp(self.MouseSwayAccumulator / 180, 0, 0.5)
        mul = mul * (1.0 + swayBonus)
    end

    if self:HasBrokenArm(owner) then
        local multiplier = self.BrokenArmPenalty.DamageMultiplier
        local org = owner.organism
        local armDamage = self:GetArmDamagePercent(owner)
        -- Scale damage penalty based on arm damage (up to -60% at full damage)
        local damagePenalty = 1 - (armDamage * 0.6)
        mul = mul * math.max(multiplier, damagePenalty)
    end

    return mul
end

function SWEP:ResetCombo()
    self.ComboCount = 0
    self.ComboExpire = 0
    self.ComboAppliedThisAttack = nil
end

function SWEP:GetComboDamageMul()
    if (self.ComboExpire or 0) < CurTime() then
        self.ComboCount = 0
    end

    local step = math.Clamp((self.ComboCount or 0) + 1, 1, 3)

    if step == 2 then
        return self.ComboDamageMul2 or 1, step
    elseif step == 3 then
        return self.ComboDamageMul3 or 1, step
    end

    return self.ComboDamageMul1 or 1, step
end

function SWEP:ApplyComboDamage(dmg)
    if not self.ComboEnabled then
        return dmg
    end

    if self.ComboAppliedThisAttack then
        return dmg
    end

    local mul, step = self:GetComboDamageMul()
    self.ComboCount = step >= 3 and 0 or step
    self.ComboExpire = step >= 3 and 0 or (CurTime() + (self.ComboResetTime or 1.1))
    self.ComboAppliedThisAttack = true

    return dmg * mul
end

function SWEP:GetConfiguredHitSoundPitch(pitch)
    if istable(pitch) then
        local pitchMin = pitch.min or pitch[1] or 100
        local pitchMax = pitch.max or pitch[2] or pitchMin
        return math.random(pitchMin, pitchMax)
    end

    return pitch or 100
end

function SWEP:EmitConfiguredHitSound(owner, data, volumeMul)
    if not IsValid(owner) then return end

    if isstring(data) then
        owner:EmitSound(data, 50 * (volumeMul or 1), 100)
        return
    end

    if not istable(data) then return end

    local snd = data.sound or data.path or data[1]
    if not isstring(snd) then return end

    local volume = (data.volume or data.vol or data[2] or 50) * (volumeMul or 1)
    local pitch = self:GetConfiguredHitSoundPitch(data.pitch or data[3])

    owner:EmitSound(snd, volume, pitch)
end

function SWEP:EmitConfiguredHitSoundLayer(owner, layer, volumeMul)
    if isstring(layer) then
        self:EmitConfiguredHitSound(owner, layer, volumeMul)
        return
    end

    if not istable(layer) then return end

    local snd = layer.sound or layer.path or layer[1]
    if isstring(snd) and (layer.sound or layer.path or not istable(layer[1])) then
        self:EmitConfiguredHitSound(owner, layer, volumeMul)
        return
    end

    for _, data in ipairs(layer) do
        self:EmitConfiguredHitSoundLayer(owner, data, volumeMul)
    end
end

function SWEP:GetRandomConfiguredHitSound(layer)
    if isstring(layer) then return layer end
    if not istable(layer) then return nil end

    local snd = layer.sound or layer.path or layer[1]
    if isstring(snd) and (layer.sound or layer.path or not istable(layer[1])) then
        return layer
    end

    local count = #layer
    if count <= 0 then return nil end

    return self:GetRandomConfiguredHitSound(layer[math.random(count)])
end

function SWEP:PlayExtraHitSounds(owner, volumeMul)
    self:EmitConfiguredHitSoundLayer(owner, self.hitsoundextra, volumeMul)
    self:EmitConfiguredHitSoundLayer(owner, self.hitsoundplus, volumeMul)
end

function SWEP:PlaySwingSound(owner)
    if self.swingsoundextra ~= nil then
        self:EmitConfiguredHitSoundLayer(owner, self.swingsoundextra)
        return
    end

    owner:EmitSound(self.AttackSwing or "weapons/slam/throw.wav", 50, math.random(95,105))
end

function SWEP:PrecacheConfiguredHitSoundLayer(layer)
    if isstring(layer) then
        util.PrecacheSound(layer)
        return
    end

    if not istable(layer) then return end

    local snd = layer.sound or layer.path or layer[1]
    if isstring(snd) and (layer.sound or layer.path or not istable(layer[1])) then
        util.PrecacheSound(snd)
        return
    end

    for _, data in ipairs(layer) do
        self:PrecacheConfiguredHitSoundLayer(data)
    end
end

function SWEP:GetHitVictim(ent)
    return hg.RagdollOwner(ent) or ent
end

function SWEP:IsHeadHit(ent, trace)
    local victim = self:GetHitVictim(ent)
    return self:IsHeadTrace(trace and trace.Entity, trace) or self:IsHeadTrace(victim, trace)
end

function SWEP:IsHeadTrace(ent, trace)
    if not trace then return false end
    if trace.HitGroup == HITGROUP_HEAD then return true end
    if not IsValid(ent) then return false end

    local headBone = ent.LookupBone and ent:LookupBone("ValveBiped.Bip01_Head1")
    if not headBone then return false end

    if trace.PhysicsBone ~= nil and ent.TranslateBoneToPhysBone and ent.TranslatePhysBoneToBone then
        local headPhys = ent:TranslateBoneToPhysBone(headBone)
        if headPhys ~= nil and headPhys >= 0 and trace.PhysicsBone == headPhys then
            return true
        end

        local bone = ent:TranslatePhysBoneToBone(trace.PhysicsBone)
        if bone and bone >= 0 and ent:GetBoneName(bone) == "ValveBiped.Bip01_Head1" then
            return true
        end
    end

    if trace.HitBoxBone ~= nil and ent.GetBoneName and ent:GetBoneName(trace.HitBoxBone) == "ValveBiped.Bip01_Head1" then
        return true
    end

    if trace.HitPos then
        local headMatrix = ent.GetBoneMatrix and ent:GetBoneMatrix(headBone)
        local headPos = headMatrix and headMatrix:GetTranslation() or ent.GetBonePosition and select(1, ent:GetBonePosition(headBone))
        if headPos and headPos ~= vector_origin then
            local radius = self.HeadTraceFallbackRadius or 10
            if headPos:DistToSqr(trace.HitPos) <= (radius * radius) then
                return true
            end
        end
    end

    return false
end

function SWEP:ShouldHeadRagdoll(ent, trace)
    local victim = self:GetHitVictim(ent)
    local damageThreshold = self.HeadRagdollMinDamage or 20
    local weaponDamage = math.max(self.DamagePrimary or 0, self.DamageSecondary or 0)
    if not IsValid(victim) or not victim:IsPlayer() then return false end
    if not victim:Alive() or IsValid(victim.FakeRagdoll) then return false end
    if weaponDamage <= damageThreshold then return false end
    if not self:IsHeadHit(ent, trace) then return false end
    return math.Rand(0, 1) <= (self.HeadRagdollChance or 0.85)
end

function SWEP:ShouldPlayBrutalizeHitSound(victim, trace)
    if not istable(self.hitsoundbrutalize) then return false end
    if not self:GetRandomConfiguredHitSound(self.hitsoundbrutalize) then return false end
    if not IsValid(victim) or not victim.organism then return false end
    if (victim.organism.skull or 0) < (self.BrutalizeSkullThreshold or 0.99) then return false end
    return self:IsHeadHit(victim, trace)
end

function SWEP:PlaySoftHitSounds(owner, ent, trace, attacktype)
    if not IsValid(owner) then return end
    if not IsValid(ent) then return end

    local victim = self:GetHitVictim(ent)
    local brutalize = self:ShouldPlayBrutalizeHitSound(victim, trace)
    local volumeMul = brutalize and (self.BrutalizeHitVolumeMul or 0.5) or 1

    owner:EmitSound(attacktype and self.Attack2HitFlesh or self.AttackHitFlesh, 50 * volumeMul)

    if not attacktype then
        self:PlayExtraHitSounds(owner, volumeMul)
    end

    if brutalize then
        self:EmitConfiguredHitSound(owner, self:GetRandomConfiguredHitSound(self.hitsoundbrutalize))
    end
end

function SWEP:Attack(owner, ent, vellen, attacktype, inattackLength)
    //if SERVER then owner:SetNetVar("slowDown", owner:GetNetVar("slowDown", 0) + (attacktype and self.DamageSecondary or self.DamagePrimary)) end
    
    if not self.FirstAttackTick then 
        if CLIENT then
            if owner == lply and self.viewpunch then
                ViewPunch(self.ViewPunch1)
                self.viewpunch = nil
            end
        else
            self.Penetration = (attacktype == 3 and self.PenetrationPrimary * 1.5) or (attacktype and self.PenetrationSecondary or self.PenetrationPrimary)
            self.PenetrationSize = (attacktype == 3 and self.PenetrationSizePrimary * 1.5) or (attacktype and self.PenetrationSizeSecondary or self.PenetrationSizePrimary)
            
            self:PlaySwingSound(owner)
            
            if owner.organism then
                owner.organism.stamina.subadd = owner.organism.stamina.subadd + (attacktype and self.StaminaSecondary or self.StaminaPrimary) * 0.5 * math.Clamp(vellen / 200, 1, 1.25)
            end

            if !attacktype then
                if self.CustomAttack and self:CustomAttack() then
                    self:SetInAttack(false)

                    return
                end
            else
                if self.CustomAttack2 and self:CustomAttack2() then
                    self:SetInAttack(false)

                    return
                end
            end
        end
    end
    
    self.HitEnts = self.HitEnts or {owner, ent}
    
    local vellen = math.min(owner:GetVelocity():Length() * 0.05, 40)
    local eyetr = hg.eyeTrace(owner, (self:GetAttackLength() + vellen), ent, owner:GetAimVector())
    //debugoverlay.Line(eyetr.StartPos, eyetr.StartPos + eyetr.Normal * (self:GetAttackLength() + vellen), 3, color_white)
    //local ent = ents.Create("prop_physics")
    //ent:SetModel("models/props_interiors/pot01a.mdl")
    //ent:SetPos(eyetr.HitPos)
    //ent:Spawn()
    //ent:SetMoveType(MOVETYPE_NONE)
    //ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    if self:IsEntSoft(eyetr.Entity) then return eyetr end
    
    local trace

    local amt = 6

    for i = 0, amt do
        local normal = eyetr.Normal:Angle()

        local ang = (attacktype == 3 and self.HeavyAttackSwingAng) or (attacktype and self.SwingAng2 or self.SwingAng) or -90
        local rads = ((attacktype == 3 and self.HeavyAttackRads) or (attacktype and self.AttackRads2 or self.AttackRads) or 65) * MELEE_GLOBAL_ACCURACY_MUL

        normal:RotateAroundAxis(normal:Forward(), ang)
        normal:RotateAroundAxis(normal:Up(), ((0.5 - inattackLength) * rads))
        normal:RotateAroundAxis(normal:Up(), (i - amt * 0.5) * MELEE_GLOBAL_ACCURACY_MUL)
        
        --debugoverlay.Line(eyetr.StartPos, eyetr.StartPos + normal:Forward() * (self:GetAttackLength() + vellen), 3, color_white)

        local tr = {}

        tr.start = eyetr.StartPos
        tr.endpos = eyetr.StartPos + normal:Forward() * (self:GetAttackLength() + vellen)
        tr.filter = self.MultiDmg1 and {owner, ent} or self.HitEnts

        local size = 0.15

        tr.mins = -Vector(size, size, size)
        tr.maxs = Vector(size, size, size)

        trace = util.TraceLine(tr)

        //if SERVER then
        //    local vec = trace.Normal * math.min(self.DamagePrimary * 0.5, 20)
        //    vec[3] = 0
    //
        //    owner:SetVelocity(vec)
        //end

        if self:IsEntSoft(trace.Entity) then break end
    end
    
    return trace
end

local bluntDecals, bluntDecalsRand = {}, 1 
for i = 1, 4 do 
	 local mat = "decals/zcity/blunt_impact" .. i 
	 table.insert(bluntDecals, mat) 
	 game.AddDecal("Impact.BluntAdd" .. i, mat) 

	 list.Add("PaintMaterials", "Impact.BluntAdd" .. i) 
	 bluntDecalsRand = i 
end 

function SWEP:PlayEffects(trace, attacktype)
    local owner = self:GetOwner()
    
    if self:IsEntSoft(trace.Entity) then
        if self.DamageType == DMG_SLASH then
            util.Decal( "Blood", trace.HitPos + trace.HitNormal * 15, trace.HitPos - trace.HitNormal * 15, owner )
            util.Decal( "Blood", trace.HitPos + trace.HitNormal * 2, owner:GetPos(), trace.Entity )
        end
    elseif not self.AttackHitPlayed then
        self.AttackHitPlayed = true

        owner:EmitSound("hitregister.ogg", 75, 115)
        owner:EmitSound(self.AttackHit,75)
        owner:EmitSound(self.AttackHit, 75)

		if self.weight >= 1.5 and self.DamageType ~= DMG_SLASH and trace.MatType ~= MAT_GLASS and not attacktype then
			util.Decal("Impact.BluntAdd" .. math.random(bluntDecalsRand), trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal, owner)
			owner:ScreenShake(trace.HitPos, self.HitScreenShakeAmp or 22, self.HitScreenShakeFreq or 6, self.HitScreenShakeDur or 0.28, self.HitScreenShakeRadius or 110, false)
		end
    end
end

function SWEP:BreakGlass(ent)
	if not IsValid(ent) then return end
    if string.find(ent:GetClass(),"break") and ent:GetBrushSurfaces()[1] and string.find(ent:GetBrushSurfaces()[1]:GetMaterial():GetName(),"glass") then
        //ent:EmitSound("physics/glass/glass_sheet_impact_hard"..math.random(3)..".wav")
        
        if math.random(1, 4) == 4 and ent:Health() < 250 then
            //ent:Fire("Break")
        end
        
        return true
    else
        return false
    end
end

function SWEP:BehindAttack(ent)
    local owner = self:GetOwner()

    return self:IsEntSoft(ent) and ent:IsPlayer() and IsValid(owner) and (owner:GetAimVector():Dot(ent:GetAimVector()) > math.cos(math.rad(45)))
end

function SWEP:PunchPlayer(ent, attacktype, trnormal, dmg)
    if ent:IsPlayer() or ent:IsRagdoll() then 
        local ply = hg.RagdollOwner(ent) or ent

        if ply:IsPlayer() then
            local normal = Angle(0,0,0)
            
            local ang = (attacktype == 3 and self.HeavyAttackSwingAng) or (attacktype and self.SwingAng2 or self.SwingAng) or -90
            local rads = ((attacktype == 3 and self.HeavyAttackRads) or (attacktype and self.AttackRads2 or self.AttackRads) or 65) * MELEE_GLOBAL_ACCURACY_MUL

            normal:RotateAroundAxis(normal:Forward(),-ang)
            normal:RotateAroundAxis(normal:Up(),-rads)

            local dot = ply:GetAimVector():Dot(trnormal)
            
            local angrand = AngleRand(-5, 5)

            ply:ViewPunch((normal * -dot) * dmg * (self.HitPunchMul or 0.75) / (self.HitPunchDiv or 40))
			if ply:OnGround() or ply.organism.superfighter then
                local owner = self:GetOwner()
                local pushDir = IsValid(owner) and (ply:GetPos() - owner:GetPos()) or trnormal
                pushDir.z = 0
                if pushDir:LengthSqr() <= 0.001 then
                    pushDir = Vector(trnormal.x, trnormal.y, 0)
                end
                if pushDir:LengthSqr() > 0.001 then
                    pushDir:Normalize()
                end
                local forceMul = attacktype and (self.PlayerSecondaryKnockbackMul or 0.75) or 1
                local force = pushDir * math.min(dmg * (self.PlayerKnockbackMul or 3.25) * forceMul, 140)
                force.z = math.min(dmg * (self.PlayerKnockbackUpMul or 0.45) * forceMul, 22)
                ply:SetVelocity(force)
			end
        end
    end
end

function SWEP:GetRagdollHitForce(ent, traceNormal, dmg, attacktype)
    local owner = self:GetOwner()
    local pushDir = IsValid(owner) and IsValid(ent) and (ent:GetPos() - owner:GetPos()) or traceNormal
    if IsValid(owner) then
        local eyeAng = owner:EyeAngles()
        local viewPunch = attacktype and (self.ViewPunch2 or angle_zero) or (self.ViewPunch1 or angle_zero)
        local swingAng = attacktype and (self.SwingAng2 or 0) or (self.SwingAng or -90)
        local sideBias = math.sin(math.rad(swingAng)) * (self.RagdollSwingSideMul or 0.85)
        sideBias = sideBias - viewPunch.y * (self.RagdollViewPunchYawMul or 0.08)
        sideBias = sideBias - viewPunch.r * (self.RagdollViewPunchRollMul or 0.04)
        pushDir = pushDir + eyeAng:Right() * sideBias
    end
    pushDir.z = 0
    if pushDir:LengthSqr() <= 0.001 then
        pushDir = Vector(traceNormal.x, traceNormal.y, 0)
    end
    if pushDir:LengthSqr() > 0.001 then
        pushDir:Normalize()
    end
    local forceMul = attacktype and (self.RagdollSecondaryKnockbackMul or 0.75) or 1
    local force = pushDir * math.min(dmg * (self.RagdollKnockbackMul or 75) * forceMul, 1800)
    force.z = math.min(dmg * (self.RagdollKnockbackUpMul or 8) * forceMul, 240)
    return force
end

SWEP.MinSensivity = 0.35

function SWEP:AlreadyHit(ent, trace, dmg)
    local ply = hg.RagdollOwner(ent)

    if IsValid(ply) and self.HitEnts[#self.HitEnts] == ply then
        return true
    else
        return false
    end
end

function SWEP:BlockingLogic(ent, mul, attacktype, trace)
    local ent = hg.RagdollOwner(ent) or ent
	local owner = self:GetOwner()

	if ent:IsPlayer() and ((istable(self.HitEnts) and !table.HasValue(self.HitEnts, ent)) or owner:IsNPC()) then
        local wep = ent:GetActiveWeapon()

        local pos, aimvec = hg.eye(ent)
        local pos2, aimvec2 = hg.eye(owner)

		if owner:IsNPC() then
			pos, aimvec, aimvec2 = owner:EyePos(), owner:GetAimVector(), owner:GetAimVector()
		end

        if not aimvec or not aimvec2 then return 1 end

        local dist, posHit, distLine = util.DistanceToLine(pos + aimvec * 100, pos, trace.HitPos)

        //print(dist, distLine)

        local dmg = wep.DamagePrimary
        local selfdmg = self.DamagePrimary * 0.2

        if wep.GetBlocking and wep:GetBlocking() and wep.SetStartedBlocking and dist < 10 then
            local defenderBlockTier = wep.BlockTier or 1
            local attackerBlockTier = self.BlockTier or 1

            if defenderBlockTier >= attackerBlockTier then
                if attacktype == 3 then
                    local defenderStamina = ent.organism and ent.organism.stamina and ent.organism.stamina[1] or 0
                    local heavyBreakChance = math.Clamp(attackerBlockTier * 0.12, 0, 0.35)
                    if defenderStamina < 65 and math.random() <= heavyBreakChance then
                        ent:EmitSound("blockbreak.ogg", 65, 112)
                        if SERVER then
                            hg.drop(ent)
                            
                            net.Start("MeleeBlockEffect")
                            net.WriteVector(trace.HitPos)
                            net.WriteString((wep.MeleeMaterial or "none") .. "_broken")
                            net.Broadcast()
                        end
                        return 1
                    end
                end

                if wep.BlockImpactSound then
                    ent:EmitSound(wep.BlockImpactSound, 60)
                end

                if SERVER then
                    net.Start("MeleeBlockEffect")
                    net.WriteVector(trace.HitPos)
                    net.WriteString(wep.MeleeMaterial or "none")
                    net.Broadcast()
                    
                    net.Start("MeleeBlockPush")
                    net.WriteVector(trace.Normal)
                    net.Send(ent)
                end

                if wep.SetLastBlocked then
                    -- wep:SetLastBlocked(CurTime()) -- Removing this to ensure block doesn't stop
                end

                local perfectblock_window = 0.5
                if IsValid(wep) and wep.HasBrokenArm and wep:HasBrokenArm(ent) then
                    perfectblock_window = perfectblock_window * ((wep.BrokenArmPenalty and wep.BrokenArmPenalty.BlockDurationMultiplier) or 1)
                end
                local perfectblock = CurTime() - wep:GetStartedBlocking() < perfectblock_window
                
                local heavyBlockedNoBreak = attacktype == 3
                local staminaLossMul = heavyBlockedNoBreak and 1.75 or 1
                local blockerViewPunchMul = heavyBlockedNoBreak and 1.8 or 1

                if perfectblock then
                    ent:EmitSound("parry.ogg", 75)
                else
                    if ent.organism then
                        ent.organism.stamina.subadd = ent.organism.stamina.subadd + 15 * staminaLossMul
                    end
                end

                -- Add pain when blocking with damaged arms
                if IsValid(wep) and wep.HasBrokenArm and wep:HasBrokenArm(ent) and ent.organism then
                    local painAmount = (wep.BrokenArmPenalty and wep.BrokenArmPenalty.PainOnBlock) or 8
                    local armDamage = wep.GetArmDamagePercent and wep:GetArmDamagePercent(ent) or 0
                    ent.organism.painadd = (ent.organism.painadd or 0) + (painAmount * (0.5 + armDamage * 0.5))
                end

                ent.organism.stamina.subadd = ent.organism.stamina.subadd + mul * math.Clamp(selfdmg / dmg, 0.1, 1) * selfdmg * (perfectblock and 0 or 1) * staminaLossMul

                if not owner:IsNPC() then
                    self:PunchPlayer(owner, attacktype, -owner:GetAimVector(), selfdmg / 2)
                end
                self:PunchPlayer(ent, attacktype, owner:GetAimVector(), (selfdmg / 2) * blockerViewPunchMul)
                
                if perfectblock then
                    -- ent:EmitSound("tasty/empty.wav")
                end
                
                -- if wep.SetLastBlocked then
                --    wep:SetLastBlocked(CurTime())
                -- end

                return 0
            end
        end
    end

    return 1
end

local matBlood = Material("zbattle/blood")
SWEP.blockSound = nil
SWEP.ShouldAttackOnce = true

function SWEP:IsClient()
	return CLIENT and self:GetOwner() == LocalPlayer()
end

function SWEP:AddDecal()
    net.Start("bloody_decal_1")
    net.WriteEntity(self)
    net.SendPVS(self:GetPos())
end

local hg_nomeleestop

if CLIENT then
    hg_nomeleestop = ConVarExists("hg_nomeleestop") and GetConVar("hg_nomeleestop") or CreateConVar("hg_nomeleestop", 0, FCVAR_ARCHIVE, "Toggle melee stop-on-hit animation feature", 0, 1)
end

local function GetMeleeAnimTiming(self)
    local animspeed = math.max(self.animspeed or 0, 0.001)
    local timing = 1 - math.Clamp((self.animtime - CurTime()) / animspeed, 0, 1)
    return self.reverseanim and (1 - timing) or timing
end

local function SetMeleeAnimTiming(self, timing, speedMul)
    local animspeed = math.max((self.animspeed or 0) * speedMul, 0.001)
    local internalTiming = self.reverseanim and (1 - timing) or timing
    self.animspeed = animspeed
    self.animtime = CurTime() - internalTiming * animspeed + animspeed
end

local function QueueMeleeHitStop(self, speedMul, pause, resumeMul, reverse, stopanim)
    if not CLIENT then return end

    self.hitstopToken = (self.hitstopToken or 0) + 1

    local token = self.hitstopToken
    local timerId = "hg_melee_hitstop_" .. self:EntIndex()
    local timing = GetMeleeAnimTiming(self)

    timer.Remove(timerId)

    self.reverseanim = reverse and true or false
    SetMeleeAnimTiming(self, timing, speedMul)
    self.stopanim = stopanim

    timer.Create(timerId, pause, 1, function()
        if not IsValid(self) then return end
        if self.hitstopToken ~= token then return end

        local currentTiming = GetMeleeAnimTiming(self)
        SetMeleeAnimTiming(self, currentTiming, resumeMul)
    end)
end

function SWEP:CustomThink()
    local owner = self:GetOwner()
    local actwep = owner.GetActiveWeapon and owner:GetActiveWeapon()

    if CLIENT and (not self.ShakePos or not self.ShakeAng) then
        self.ShakePos = Vector(0,0,0)
        self.ShakeAng = Angle(0,0,0)
    end

	if SERVER and not owner:IsNPC() and owner.organism and (not owner.organism.canmove or ((owner.organism.stun - CurTime()) > 0) or (owner.organism.larm == 1 and owner.organism.rarm == 1)) and IsValid(actwep) and self == actwep then
		self:RemoveFake()
		
		hg.drop(owner)

		return
	end

    if self.CanSuicide and hg.KeyDown(owner, IN_ATTACK) and owner.suiciding and !self.SuicideStart then
        self.SuicideStart = CurTime()

        if SERVER then
            if self.SuicideFunc then
                self:SuicideFunc()
            else
                local dmgInfo = DamageInfo()
                dmgInfo:SetDamageType(DMG_SLASH)

                local org = owner.organism
                local ent = hg.GetCurrentCharacter(owner)
                
                local neckBone = ent:LookupBone("ValveBiped.Bip01_Neck1")
                if not neckBone then return end
                local neckMat = ent:GetBoneMatrix(neckBone)
                if not neckMat then return end
                local ang = neckMat:GetAngles()
                local _, ang = LocalToWorld(vector_origin, Angle(0, -60, 0), vector_origin, ang)
                
                hg.organism.input_list["arteria"](org, 0, 5, dmgInfo, nil, -ang:Forward())
                
                for i = 1, 5 do
                    hg.organism.AddWoundManual(owner, 50, VectorRand(-2, 2), ang, "ValveBiped.Bip01_Neck1", CurTime() + math.Rand(0, 2))
                end

                owner:AddNaturalAdrenaline(math.max(2 - org.adrenaline, 0))
                org.fear = math.max(org.fear, 1)

                --timer.Simple(0, function()
                --    hg.organism.Vomit(owner, "player/flesh/flesh_bullet_impact_03.wav")
                --end)
                hook.Run("HomigradDamage", owner, dmgInfo, HITGROUP_HEAD, hg.GetCurrentCharacter(org.owner), 15)
                owner:EmitSound(self.SuicideSound or self.Attack2HitFlesh, 50)
                
                --timer.Simple(0.05, function()
                --    owner:ViewPunch(self.SuicidePunchAng or Angle(5, 10, 0))
                --end)
            end
        end
    end

    if self.SuicideStart and self.SuicideStart + self.SuicideTime < CurTime() then
        owner.suiciding = false
        self.cutthroat = CurTime()
        self.SuicideStart = nil
    end

    self:SetHold(owner.suiciding and self.SuicideHoldType or self.HoldType)

    if SERVER and owner.organism and owner.organism.rarmamputated and not owner.organism.larmamputated then
        self:RemoveFake()

		hg.drop(owner)

        return
    end

    -- Allow holding two-handed weapons with both arms broken (but not amputated)
    -- Only prevent if one arm is amputated
    if owner.organism and owner.organism.larmamputated and self.TwoHanded then return end

    self:ThinkAdd()

    local owner = self:GetOwner()

    if self.CanHeavyAttack then
        local state = self.GetChargeState and self:GetChargeState() or self:GetDTInt(6)
        local nextState = self.GetNextChargeStateTime and self:GetNextChargeStateTime() or self:GetDTFloat(9)
        if CLIENT then
            nextState = math.max(nextState or 0, self.HeavyChargeNextStateLocal or 0)
        end
        local curTime = CurTime()
        local attackDown = hg.KeyDown(owner, IN_ATTACK)
        local useDown = hg.KeyDown(owner, IN_USE)
        local feintPressed = owner.KeyPressed and owner:KeyPressed(IN_ATTACK2)
        local heavyGetupCooldownDuration = self.HeavyAttackAfterGetupCooldown or 2
        local heavyGetupCooldownEnd = owner:GetNWFloat(self.HeavyAttackGetupNWKey or "HGHeavyGetupCooldown", 0)
        heavyGetupCooldownEnd = math.max(heavyGetupCooldownEnd, (owner.LastFakeUp or 0) + heavyGetupCooldownDuration)
        local heavyGetupBlocked = curTime < heavyGetupCooldownEnd
        local function cancelHeavyChargeWithFeintAnim(cancelTime)
            cancelTime = math.Clamp(cancelTime or self.HeavyAttackAnimTimeBegin, 0.05, self.HeavyAttackAnimTimeBegin)
            local feintLockTime = math.max(cancelTime, 0.5)
            self:PlayAnim(self.Attack_Charge_Begin, cancelTime, false, nil, true, true)
            if self.SetChargeState then self:SetChargeState(0) else self:SetDTInt(6, 0) end
            if self.SetNextChargeStateTime then self:SetNextChargeStateTime(0) else self:SetDTFloat(9, 0) end
            self.HeavyChargeNextStateLocal = 0
            self.HeavyChargeStartLocal = 0
            self.HeavyAttackStaminaDeducted = false
            self.HeavyChargeStaminaDrainAcc = 0
            self.HeavyChargeStaminaDrainTick = curTime
            self.HeavyChargeBeginAnimEnd = 0
            self.HeavyAttackFeintLockEndTime = curTime + feintLockTime
            self.HeavyAttackFeintBlockUntilRelease = true
            self:SetInAttack(false)
            self:SetLastAttack(curTime)
            self:SetAttackWait(feintLockTime)
            self.lastattack = curTime
            self.attackwait = feintLockTime
            if CLIENT then
                self.ShakePos = Vector(0,0,0)
                self.ShakeAng = Angle(0,0,0)
            end
        end

        if self.HeavyAttackFeintBlockUntilRelease and not attackDown then
            self.HeavyAttackFeintBlockUntilRelease = false
        end

        local inFakeState = IsValid(owner) and (owner.fake or (owner.organism and owner.organism.fake) or IsValid(owner.FakeRagdoll))
        if not IsValid(owner) or not owner:Alive() or owner.fake or (owner.organism and (owner.organism.fake or owner.organism.otrub)) or IsValid(owner.FakeRagdoll) then
            if state ~= 0 then
                if (state == 1 or state == 2) and IsValid(owner) then
                    local cancelTime = self.HeavyAttackAnimTimeBegin
                    if state == 1 then
                        local startTime = self.GetChargeStartTime and self:GetChargeStartTime() or self:GetDTFloat(10)
                        cancelTime = math.Clamp(curTime - startTime, 0.05, self.HeavyAttackAnimTimeBegin)
                    elseif state == 2 then
                        cancelTime = self.HeavyAttackAnimTimeBegin
                    end
                    cancelHeavyChargeWithFeintAnim(cancelTime)
                    state = 0
                else
                    if self.SetChargeState then self:SetChargeState(0) else self:SetDTInt(6, 0) end
                    self.HeavyAttackStaminaDeducted = false
                    self.HeavyAttackFeintBlockUntilRelease = false
                    self.HeavyChargeNextStateLocal = 0
                    self.HeavyChargeStartLocal = 0
                    self.HeavyChargeStaminaDrainAcc = 0
                    self.HeavyChargeStaminaDrainTick = curTime
                    self.HeavyChargeBeginAnimEnd = 0
                    if CLIENT then
                        self.ShakePos = Vector(0,0,0)
                        self.ShakeAng = Angle(0,0,0)
                    end
                    if IsValid(owner) then
                        owner:StopSound("pwb2/weapons/mac11/draw.wav")
                    end
                    if not inFakeState then
                        self:PlayAnim("idle", 1, false, nil, false)
                    end
                end
            elseif CLIENT then
                self.HeavyChargeNextStateLocal = 0
                self.HeavyChargeStartLocal = 0
                if not inFakeState then
                    self:PlayAnim("idle", 1, false, nil, false, true)
                end
            end
        elseif (state == 1 or state == 2) and useDown and attackDown and feintPressed and not self:GetInAttack() then
            local cancelTime = self.HeavyAttackAnimTimeBegin
            if state == 1 then
                local startTime = self.GetChargeStartTime and self:GetChargeStartTime() or self:GetDTFloat(10)
                cancelTime = math.Clamp(curTime - startTime, 0.05, self.HeavyAttackAnimTimeBegin)
            end
            cancelHeavyChargeWithFeintAnim(cancelTime)
            state = 0
        elseif state == 0 then
            self.HeavyChargeStaminaDrainAcc = 0
            self.HeavyChargeStaminaDrainTick = curTime
            if useDown and attackDown and not heavyGetupBlocked and not self.HeavyAttackFeintBlockUntilRelease and not self:GetInAttack() and (self:GetLastAttack() + self:GetAttackWait() < curTime) and not self:GetBlocking() and not self:IsEquipLocked() then
                if owner.organism and owner.organism.stamina and owner.organism.stamina[1] and owner.organism.stamina[1] < 80 then return end
                if self.SetChargeState then self:SetChargeState(1) else self:SetDTInt(6, 1) end
                self.HeavyAttackStaminaDeducted = false
                if self.SetNextChargeStateTime then self:SetNextChargeStateTime(curTime + self.HeavyAttackAnimTimeBegin) else self:SetDTFloat(9, curTime + self.HeavyAttackAnimTimeBegin) end
                if self.SetChargeStartTime then self:SetChargeStartTime(curTime) else self:SetDTFloat(10, curTime) end
                self.HeavyChargeNextStateLocal = curTime + self.HeavyAttackAnimTimeBegin
                self.HeavyChargeStartLocal = curTime
                self:PlayAnim(self.Attack_Charge_Begin, self.HeavyAttackAnimTimeBegin, false, nil, false, true)
                self.HeavyChargeBeginAnimEnd = curTime + self.HeavyAttackAnimTimeBegin
                
                -- Play cloth sound on begin
                owner:EmitSound("pwb2/weapons/mac11/draw.wav", 55, 100)
            end
        elseif state == 1 then
             local startTime = self.GetChargeStartTime and self:GetChargeStartTime() or self:GetDTFloat(10)
             if CLIENT then
                startTime = math.max(startTime or 0, self.HeavyChargeStartLocal or 0)
             end
             local chargeProgress = math.min((curTime - startTime) / self.HeavyAttackMaxChargeTime, 1.0)
             local beginEndTime = startTime + self.HeavyAttackAnimTimeBegin
             
             if CLIENT then
                local shake = chargeProgress * 0.01 -- Reduced from 0.05
                self.ShakePos = self.ShakePos + VectorRand() * shake
                self.ShakeAng = self.ShakeAng + AngleRand() * (shake * 0.5)
             end

            if curTime >= beginEndTime then
                if not hg.KeyDown(owner, IN_ATTACK) then
                     -- Released during charge? Go straight to attack
                    if self.SetChargeState then self:SetChargeState(3) else self:SetDTInt(6, 3) end
                    self.HeavyChargeNextStateLocal = 0
                    
                    self.HitEnts = nil
                    self.FirstAttackTick = false
                    self.AttackHitPlayed = false
                    
                local mul = 1
                if owner.organism and owner.organism.stamina and owner.organism.stamina[1] then
                    mul = 1 / math.Clamp((180 - owner.organism.stamina[1]) / 90, 1, 2)
                end

                self:PlayAnim(self.Attack_Charge_End, self.HeavyAttackAnimTimeEnd / mul, false, nil, false, true)

                if SERVER and owner.organism and owner.organism.stamina and not self.HeavyAttackStaminaDeducted then
                    owner.organism.stamina.subadd = owner.organism.stamina.subadd + (self.HeavyAttackStamina or 20) * self:GetStaminaWeightDamageMultiplier(3)
                    self.HeavyAttackStaminaDeducted = true
                end
                
                self:SetAttackType(3)
                self:SetLastAttack(curTime + self.HeavyAttackDelay / mul)
                self:SetAttackTime(curTime + self.HeavyAttackTimeLength / mul)
                self:SetAttackLength(self.AttackLen1)
                self:SetAttackWait(self.HeavyAttackWaitTime / mul)
                self:SetInAttack(true)
                
                -- Reset shake immediately on attack release to prevent animation lag/jitter
                if CLIENT then
                    self.ShakePos = Vector(0,0,0)
                    self.ShakeAng = Angle(0,0,0)
                end
                    
                    if CLIENT and not self:IsLocal() and owner.AnimRestartGesture then
                         owner:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_SLAM, true)
                    end
                    
                    self.viewpunch = true
                else
                    if self.SetChargeState then self:SetChargeState(2) else self:SetDTInt(6, 2) end
                    if self.SetNextChargeStateTime then self:SetNextChargeStateTime(curTime + self.HeavyAttackAnimTimeIdle) else self:SetDTFloat(9, curTime + self.HeavyAttackAnimTimeIdle) end
                    self.HeavyChargeNextStateLocal = curTime + self.HeavyAttackAnimTimeIdle
                    self.HeavyChargeBeginAnimEnd = 0
                    self:PlayAnim(self.Attack_Charge_Idle, self.HeavyAttackAnimTimeIdle, true, nil, false, true)
                end
            end
        elseif state == 2 then
             local startTime = self.GetChargeStartTime and self:GetChargeStartTime() or self:GetDTFloat(10)
             if CLIENT then
                startTime = math.max(startTime or 0, self.HeavyChargeStartLocal or 0)
             end
             local chargeProgress = math.min((curTime - startTime) / self.HeavyAttackMaxChargeTime, 1.0)

             if CLIENT then
                local shake = chargeProgress * 0.02 -- Reduced from 0.1
                self.ShakePos = self.ShakePos + VectorRand() * shake
                self.ShakeAng = self.ShakeAng + AngleRand() * (shake * 0.5)
             end

            if not hg.KeyDown(owner, IN_ATTACK) then
                -- Trigger Attack
                if self.SetChargeState then self:SetChargeState(3) else self:SetDTInt(6, 3) end
                self.HeavyChargeNextStateLocal = 0
                
                local mul = 1
                if owner.organism and owner.organism.stamina and owner.organism.stamina[1] then
                    mul = 1 / math.Clamp((180 - owner.organism.stamina[1]) / 90, 1, 2)
                end
                
                self.HitEnts = nil
                self.FirstAttackTick = false
                self.AttackHitPlayed = false
                
                self:PlayAnim(self.Attack_Charge_End, self.HeavyAttackAnimTimeEnd / mul, false, nil, false, true)

                if SERVER and owner.organism and owner.organism.stamina and not self.HeavyAttackStaminaDeducted then
                    owner.organism.stamina.subadd = owner.organism.stamina.subadd + (self.HeavyAttackStamina or 20) * self:GetStaminaWeightDamageMultiplier(3)
                    self.HeavyAttackStaminaDeducted = true
                end
                
                self:SetAttackType(3)
                self:SetLastAttack(curTime + self.HeavyAttackDelay / mul)
                self:SetAttackTime(curTime + self.HeavyAttackTimeLength / mul)
                self:SetAttackLength(self.AttackLen1) -- Use Primary length or custom?
                self:SetAttackWait(self.HeavyAttackWaitTime / mul)
                self:SetInAttack(true)
                self.HitWorld = false
                
                -- Reset shake immediately on attack release
                if CLIENT then
                    self.ShakePos = Vector(0,0,0)
                    self.ShakeAng = Angle(0,0,0)
                end
                
                if CLIENT and not self:IsLocal() and owner.AnimRestartGesture then
                     owner:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_SLAM, true)
                end
                
                self.viewpunch = true
            elseif curTime >= nextState then
                 -- Loop idle
                 if self.SetNextChargeStateTime then self:SetNextChargeStateTime(curTime + self.HeavyAttackAnimTimeIdle) else self:SetDTFloat(9, curTime + self.HeavyAttackAnimTimeIdle) end
                 self.HeavyChargeNextStateLocal = curTime + self.HeavyAttackAnimTimeIdle
                 self:PlayAnim(self.Attack_Charge_Idle, self.HeavyAttackAnimTimeIdle, true, nil, false, true)
            end
        elseif state == 3 then
             -- Attack logic is handled by GetInAttack() block
             self.HeavyChargeNextStateLocal = 0
             self.HeavyChargeStaminaDrainAcc = 0
             self.HeavyChargeStaminaDrainTick = curTime
             self.HeavyChargeBeginAnimEnd = 0
             if not self:GetInAttack() then
                 if self.SetChargeState then self:SetChargeState(0) else self:SetDTInt(6, 0) end
             end
        end

        if SERVER then
            if state ~= 0 and state ~= 3 and hg.KeyDown(owner, IN_ATTACK) then
                self.HeavyChargeStaminaDrainTick = self.HeavyChargeStaminaDrainTick or curTime
                self.HeavyChargeStaminaDrainAcc = (self.HeavyChargeStaminaDrainAcc or 0) + math.max(curTime - self.HeavyChargeStaminaDrainTick, 0)
                self.HeavyChargeStaminaDrainTick = curTime

                if owner.organism and owner.organism.stamina then
                    while self.HeavyChargeStaminaDrainAcc >= 1 do
                        owner.organism.stamina.subadd = owner.organism.stamina.subadd + (self.HeavyChargeStaminaDrainPerSecond or 5) * self:GetStaminaWeightDamageMultiplier(3)
                        self.HeavyChargeStaminaDrainAcc = self.HeavyChargeStaminaDrainAcc - 1
                    end
                else
                    self.HeavyChargeStaminaDrainAcc = 0
                end
            else
                self.HeavyChargeStaminaDrainAcc = 0
                self.HeavyChargeStaminaDrainTick = curTime
            end
        end
    end
    
    if CLIENT and owner ~= lply then return end

    //if SERVER then
        local oldblocking = self:GetBlocking()
        local now = CurTime()
        local feintLockActive = (self.HeavyAttackFeintLockEndTime or 0) > now
                local blockDuration = 1
        if self:HasBrokenArm(owner) then
            blockDuration = blockDuration * self.BrokenArmPenalty.BlockDurationMultiplier
        end
        local blocking = not feintLockActive and ((now - self:GetStartedBlocking()) > blockDuration or oldblocking) and owner.organism and owner.organism.stamina and owner.organism.stamina[1] and owner.organism.stamina[1] > 90 and !self:GetInAttack() and (self:GetAttackTime() - now - 0) < 0 and self:CanBlock() and hg.KeyDown(owner, IN_ATTACK2)
        --if self:CutDuct() then return end
        self:SetBlocking(blocking)
        
        if self:GetBlocking() and !oldblocking then
            self:SetStartedBlocking(CurTime())
        end
    //end

	if self:GetBlocking() then
		if not self.blockSound then
			sound.Play("pwb2/weapons/matebahomeprotection/mateba_cloth.wav", self:GetPos(), 65)
			self.blockSound = true
		end
	else
		if self.blockSound then
			sound.Play("pwb2/weapons/mac11/draw.wav", self:GetPos(), 55)
		end
		self.blockSound = nil
	end

    if self:GetInAttack() then
        local currentEyeAngles = owner:EyeAngles()
        if self.LastEyeAngles then
            local diff = currentEyeAngles - self.LastEyeAngles
            diff:Normalize()
            local sway = math.abs(diff.y) + math.abs(diff.p)
            self.MouseSwayAccumulator = (self.MouseSwayAccumulator or 0) + sway
        end
        self.LastEyeAngles = currentEyeAngles

        local blockMul = 1
        local inattack1 = math.max(self:GetLastAttack() - CurTime(), 0) / self.AttackTime
        local inattack2 = math.max(self:GetLastAttack() - CurTime(), 0) / self.Attack2Time

        local inattackL1 = math.max(self:GetAttackTime() - CurTime(), 0) / self.AttackTimeLength
        local inattackL2 = math.max(self:GetAttackTime() - CurTime(), 0) / self.Attack2TimeLength

        local inattack3 = math.max(self:GetLastAttack() - CurTime(), 0) / self.HeavyAttackDelay
        local inattackL3 = math.max(self:GetAttackTime() - CurTime(), 0) / self.HeavyAttackTimeLength
        
        local ent = hg.GetCurrentCharacter(owner)
        local vellen = ent:GetVelocity():Length()

        local mul = self:MultiplyDMG(owner, ent, vellen, 1)
        
        if self:GetAttackType() == 1 and inattack1 == 0 then
            owner:LagCompensation(true)
            
            local trace = self:Attack(owner, ent, vellen, false, inattackL1)

            owner:LagCompensation(false)

            if SERVER and (owner:OnGround() or owner.organism.superfighter) then -- ранбуст для супербойцов
                local vec = owner:GetAimVector() * math.min(self.DamagePrimary * 0.5, 20)
                vec[3] = 0

                owner:SetVelocity(vec)
            end

            if !trace then return end

            local ent = trace.Entity

            local shouldhit = (IsValid(ent) or ent:IsWorld())
            local soft = self:IsEntSoft(ent)

            local dmg = math.random(self.DamagePrimary - 3, self.DamagePrimary + 3)
            blockMul = 1

            if !shouldhit then
                goto meleeskip1
            end

            if SERVER and soft and self.HitEnts[#self.HitEnts] ~= ent then
                self:AddDecal()
            end

            if self:IsHitCooldownTarget(ent) then
                self:ApplyHitCooldown()
            end

			if CLIENT and IsFirstTimePredicted() and self.weight > 0.4 and (!self.stopanim or (!soft and !self.HitWorld)) and !hg_nomeleestop:GetBool() then
				if !soft or self.AnimAlwaysBack or self.HitWorld then   
                    QueueMeleeHitStop(self, self.HitStopWorldSpeedMul or 2.35, self.HitStopWorldPause or 0.12, self.HitStopWorldResumeMul or 0.6, true, self.HitStopWorldStop or 0.12)
                    util.ScreenShake(self:GetPos(), 35, 1, 1, 100)
					self.reverseanim = true
                    self.HitWorld = true
				else
                    QueueMeleeHitStop(self, self.HitStopSoftSpeedMul or 1.9, self.HitStopSoftPause or 0.05, self.HitStopSoftResumeMul or 0.72, false, self.HitStopSoftStop or 0.1)
                    util.ScreenShake(self:GetPos(), 35, 1, 1, 100)
				end
			end

            if CLIENT then goto meleeskip1 end

            ent:PrecacheGibs()

            mul = mul * (self:BehindAttack(ent) and 2 or 1)
            blockMul = self:BlockingLogic(ent, mul, false, trace)
            mul = mul * blockMul

            if blockMul == 0 and self.DamageType == DMG_SLASH then
                self:SetInAttack(false)
                self.HitEnts = nil
                self.FirstAttackTick = false
                self.AttackHitPlayed = false
                return
            end

            dmg = dmg * mul
            dmg = self:ApplyComboDamage(dmg)

            if self:AlreadyHit(ent, trace) then
                goto meleeskip1
            end
            
            if self.HitEnts[#self.HitEnts] ~= ent then
                self:PlayEffects(trace, false)
            end
            
            if self.MultiDmg1 or (self.HitEnts[#self.HitEnts] ~= ent) then

                if self.MultiDmg1 or not self:IsEntSoft(ent) then
                    dmg = dmg / (self.AttackRads * self.AttackTimeLength)
                else
                    dmg = dmg / 1.5
                end
                                
                local dmginfo = DamageInfo()

                dmginfo:SetAttacker(owner)
                dmginfo:SetInflictor(self)
                dmginfo:SetDamage(dmg)
                dmginfo:SetDamageForce(trace.Normal * dmg * MELEE_GLOBAL_KNOCKBACK_MUL)
                
                local dmgType = self.DamageType
                if self:GetAttackType() == 3 and self.HeavyAttackDamageType then
                    dmgType = self.HeavyAttackDamageType
                end
                
                dmginfo:SetDamageType(ent:GetClass() == "func_breakable_surf" and DMG_SLASH or dmgType)
                dmginfo:SetDamagePosition(trace.HitPos)
                
                hg.AddForceRag(ent, trace.PhysicsBone or 0, trace.Normal * math.min(dmg, 25) * 400 * MELEE_GLOBAL_KNOCKBACK_MUL, 0.5)

                self:PunchPlayer(ent, false, trace.Normal, dmg)

                local phys = ent:GetPhysicsObjectNum(trace.PhysicsBone or 0)

                if IsValid(phys) then
                    local forceMultiplier = math.min(dmg, 25) * 400 * MELEE_GLOBAL_KNOCKBACK_MUL
                    phys:ApplyForceCenter(trace.Normal * forceMultiplier * 0.8)
                    phys:ApplyForceOffset(trace.Normal * forceMultiplier * 0.2, trace.HitPos)
                end

                self.slash = self.MultiDmg1
                ent:TakeDamageInfo(dmginfo)

                if SERVER and self.NeckBreakChance and (self.DamagePrimary or 0) >= (self.DamageSecondary or 0) and blockMul >= 1 then
                    local isHead = trace.HitGroup == HITGROUP_HEAD
                    if not isHead and ent:IsRagdoll() then
                        local physBone = trace.PhysicsBone
                        if physBone then
                            local bone = ent:TranslatePhysBoneToBone(physBone)
                            if bone then
                                local name = ent:GetBoneName(bone)
                                if name and string.find(string.lower(name), "head") then
                                    isHead = true
                                end
                            end
                        end
                    end

                    if (ent:IsPlayer() or ent:IsRagdoll()) and isHead then
                         if math.random() <= self.NeckBreakChance then
                              hg.BreakNeck(ent)
                         end
                    end
                end

                self.attackedOnce = true
                self.slash = nil
                self:PlaySoftHitSounds(owner, ent, trace, false)
                
                local headHit = self:IsHeadHit(ent, trace)
                local hitForce = self:GetRagdollHitForce(ent, trace.Normal, dmg, false)
                if headHit then
                    hitForce.x = hitForce.x * (self.HeadRagdollForceMul or 1.35)
                    hitForce.y = hitForce.y * (self.HeadRagdollForceMul or 1.35)
                    hitForce.z = hitForce.z * (self.HeadRagdollUpMul or 1.2)
                end
                hg.AddForceRag(ent, trace.PhysicsBone or 0, hitForce, 0.5)

                self:PunchPlayer(ent, false, trace.Normal, dmg)

                local phys = ent:GetPhysicsObjectNum(trace.PhysicsBone or 0)

                if IsValid(phys) then
                    phys:ApplyForceOffset(hitForce, trace.HitPos)
                end

                if self:ShouldHeadRagdoll(ent, trace) then
                    timer.Simple(0, function()
                        local victim = self:GetHitVictim(ent)
                        if IsValid(victim) and victim:IsPlayer() and victim:Alive() and not IsValid(victim.FakeRagdoll) then
                            hg.Fake(victim)
                        end
                    end)
                end

                self:PrimaryAttackAdd(ent, trace)
            end

            ::meleeskip1::
            
            if not ent:IsWorld() and self:IsEntSoft(ent) then
                self.HitEnts[#self.HitEnts + 1] = ent
            end

            self.FirstAttackTick = true

            if inattackL1 == 0 then
                self:SetInAttack(false)
                self.HitEnts = nil
                self.FirstAttackTick = false
                self.AttackHitPlayed = false
                self.ComboAppliedThisAttack = nil
            end
        elseif self:GetAttackType() == 2 and inattack2 == 0 then
            owner:LagCompensation(true)
            
            local trace = self:Attack(owner, ent, vellen, true, inattackL2)

            owner:LagCompensation(false)

            if !trace then return end

            local ent = trace.Entity

            local shouldhit = (IsValid(ent) or ent:IsWorld())

            local dmg = math.random(self.DamageSecondary - 3, self.DamageSecondary + 3)
            blockMul = 1

            if !shouldhit then
                goto meleeskip2
            end

            if SERVER and self:IsEntSoft(ent) and self.DamageType == DMG_SLASH and self.HitEnts[#self.HitEnts] ~= ent then
                self:AddDecal()
            end

            if self:IsHitCooldownTarget(ent) then
                self:ApplyHitCooldown()
            end

            if CLIENT then goto meleeskip2 end

            ent:PrecacheGibs()

            if SERVER then -- ранбуст для супербойцов and (ent:OnGround() or ent.organism and ent.organism.superfighter)
                local vec = trace.Normal * math.min(self.DamageSecondary  * 0.5, 20) * MELEE_GLOBAL_KNOCKBACK_MUL
                vec[3] = 0
                
                ent:SetVelocity(vec)
            end

            mul = mul * (self:BehindAttack(ent) and 2 or 1)
            blockMul = self:BlockingLogic(ent, mul, true, trace)
            mul = mul * blockMul

            if blockMul == 0 and self.DamageType == DMG_SLASH then
                self:SetInAttack(false)
                self.HitEnts = nil
                self.FirstAttackTick = false
                self.AttackHitPlayed = false
                return
            end

            dmg = dmg * mul
            dmg = self:ApplyComboDamage(dmg)

            if self:AlreadyHit(ent, trace) then
                goto meleeskip2
            end

            if self.HitEnts[#self.HitEnts] ~= ent then
                self:PlayEffects(trace, true)
            end

            if self.MultiDmg2 or (self.HitEnts[#self.HitEnts] ~= ent) then
                //if self:BreakGlass(ent) then
                    //goto meleeskip2
                //end

                if self.MultiDmg2 or not self:IsEntSoft(ent) then
                    dmg = dmg / math.max(1,self.AttackRads2 * self.Attack2TimeLength)
                end

                local dmginfo = DamageInfo()

                dmginfo:SetAttacker(owner)
                dmginfo:SetInflictor(self)
                dmginfo:SetDamage(dmg)
                dmginfo:SetDamageForce(trace.Normal * dmg * MELEE_GLOBAL_KNOCKBACK_MUL)
                dmginfo:SetDamageType(ent:GetClass() == "func_breakable_surf" and DMG_SLASH or self.DamageType)
                dmginfo:SetDamagePosition(trace.HitPos)

                local phys = ent:GetPhysicsObjectNum(trace.PhysicsBone or 0)

                hg.AddForceRag(ent, trace.PhysicsBone or 0, trace.Normal * math.min(dmg, 25) * 400 * MELEE_GLOBAL_KNOCKBACK_MUL, 0.5)

                self:PunchPlayer(ent, true, trace.Normal, dmg)

                if IsValid(phys) then
                    local forceMultiplier = math.min(dmg, 25) * 400 * MELEE_GLOBAL_KNOCKBACK_MUL
                    phys:ApplyForceCenter(trace.Normal * forceMultiplier * 0.8)
                    phys:ApplyForceOffset(trace.Normal * forceMultiplier * 0.2, trace.HitPos)
                end

                self.slash = self.MultiDmg2
                --print(dmg)
                ent:TakeDamageInfo(dmginfo)

                if SERVER and self.NeckBreakChance and (self.DamageSecondary or 0) > (self.DamagePrimary or 0) and blockMul >= 1 then
                    local isHead = trace.HitGroup == HITGROUP_HEAD
                    if not isHead and ent:IsRagdoll() then
                        local physBone = trace.PhysicsBone
                        if physBone then
                            local bone = ent:TranslatePhysBoneToBone(physBone)
                            if bone then
                                local name = ent:GetBoneName(bone)
                                if name and string.find(string.lower(name), "head") then
                                    isHead = true
                                end
                            end
                        end
                    end

                    if (ent:IsPlayer() or ent:IsRagdoll()) and isHead then
                         if math.random() <= self.NeckBreakChance then
                              hg.BreakNeck(ent)
                         end
                    end
                end

                self.attackedOnce = true
                self.slash = nil
                self:PlaySoftHitSounds(owner, ent, trace, true)

                local headHit = self:IsHeadHit(ent, trace)
                local phys = ent:GetPhysicsObjectNum(trace.PhysicsBone or 0)
                local hitForce = self:GetRagdollHitForce(ent, trace.Normal, dmg, true)
                if headHit then
                    hitForce.x = hitForce.x * (self.HeadRagdollForceMul or 1.35)
                    hitForce.y = hitForce.y * (self.HeadRagdollForceMul or 1.35)
                    hitForce.z = hitForce.z * (self.HeadRagdollUpMul or 1.2)
                end

                hg.AddForceRag(ent, trace.PhysicsBone or 0, hitForce, 0.5)

                self:PunchPlayer(ent, true, trace.Normal, dmg)

                if IsValid(phys) then
                    phys:ApplyForceOffset(hitForce, trace.HitPos)
                end

                if self:ShouldHeadRagdoll(ent, trace) then
                    timer.Simple(0, function()
                        local victim = self:GetHitVictim(ent)
                        if IsValid(victim) and victim:IsPlayer() and victim:Alive() and not IsValid(victim.FakeRagdoll) then
                            hg.Fake(victim)
                        end
                    end)
                end

                self:SecondaryAttackAdd(ent, trace)
            end

            ::meleeskip2::

            if not ent:IsWorld() and self:IsEntSoft(ent) then
                self.HitEnts[#self.HitEnts + 1] = ent
            end

            self.FirstAttackTick = true

            if inattackL2 == 0 then
                self:SetInAttack(false)
                self.HitEnts = nil
                self.FirstAttackTick = false
                self.AttackHitPlayed = false
                self.ComboAppliedThisAttack = nil
            end
        end
    else
        self.attackedOnce = nil
        self.ComboAppliedThisAttack = nil
    end

end

function SWEP:PrimaryAttackAdd(ent)
end

function SWEP:SecondaryAttackAdd(ent)
end

SWEP.AttackTimeLength = 0.15
SWEP.Attack2TimeLength = 0.1
SWEP.HitStopWorldSpeedMul = 2.35
SWEP.HitStopWorldResumeMul = 0.6
SWEP.HitStopWorldPause = 0.12
SWEP.HitStopWorldStop = 0.12
SWEP.HitStopSoftSpeedMul = 1.9
SWEP.HitStopSoftResumeMul = 0.72
SWEP.HitStopSoftPause = 0.05
SWEP.HitStopSoftStop = 0.1
SWEP.HitPunchMul = 0.75
SWEP.HitPunchDiv = 40
SWEP.HitScreenShakeAmp = 22
SWEP.HitScreenShakeFreq = 6
SWEP.HitScreenShakeDur = 0.28
SWEP.HitScreenShakeRadius = 110

SWEP.AttackRads = 45
SWEP.AttackRads2 = 65

SWEP.SwingAng = -90
SWEP.SwingAng2 = 0

function SWEP:PrimaryAttack()
    if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
    local ply = self:GetOwner()
    if self:IsEquipLocked() then return end

    if self.cutthroat and self.cutthroat + 1 > CurTime() then return end
    if self.CanSuicide and ply.suiciding then return end

    if self.CanHeavyAttack and (hg.KeyDown(ply, IN_USE) or self:GetChargeState() > 0) and not (ply.fake or (ply.organism and (ply.organism.fake or ply.organism.otrub)) or IsValid(ply.FakeRagdoll)) then return end

    -- Allow attacking with both arms broken (but not amputated)
    if ply.organism and ply.organism.larmamputated and self.TwoHanded then return end
    if ply.organism and ply.organism.rarmamputated and ply.organism.larmamputated and self.TwoHanded then return end
    if !hg.KeyDown(self:GetOwner(), IN_ATTACK2) and not self:CanPrimaryAttack() then return end
    
    if self:GetLastBlocked() + 1 > CurTime() then
        //return
    end

    if self:GetBlocking() then
        self:SecondaryAttack(true)

        return
    end
    
    local ply = self:GetOwner()
    local ent = hg.GetCurrentCharacter(ply)

    if !self:InUse() then return end
        if (self:GetLastAttack() + self:GetAttackWait()) > CurTime() then return end
    if self.lastattack and (self.lastattack + self.attackwait) > CurTime() then return end
    
    local mul = 1
    if ply.organism and ply.organism.stamina and ply.organism.stamina[1] then
        mul = 1 / math.Clamp((180 - ply.organism.stamina[1]) / 90, 1, 2)
    end

    if self:HasBrokenArm(ply) then
        local multiplier = self.BrokenArmPenalty.SwingSpeedMultiplier
        local org = ply.organism
        local checkLeft = self.TwoHanded and (org.larm and org.larm >= 1 and org.larmdislocation)
        local checkRight = (org.rarm and org.rarm >= 1 and org.rarmdislocation)
        if org and (checkLeft or checkRight) then
            multiplier = multiplier * 0.5 -- More severe (even slower)
        end
        mul = mul * multiplier
    end

    
    self.HitEnts = nil
    self.FirstAttackTick = false
    self.AttackHitPlayed = false
    self.HitWorld = false
    self.ComboAppliedThisAttack = nil
    self:PlayAnim("attack", self.AnimTime1 / mul,false,nil,false,false)
    self:SetAttackType(1)
    self:SetLastAttack(CurTime() + self.AttackTime / mul)
    self:SetAttackTime(self:GetLastAttack() + (self.AttackTimeLength / mul))
    self:SetAttackLength(self.AttackLen1)
    self:SetAttackWait(self.WaitTime1 / mul)
    self:SetInAttack(true)
    self.lastattack = CurTime() + self.Attack2Time / mul
    self.attackwait = self.WaitTime2 / mul

    if CLIENT and not self:IsLocal() and ply.AnimRestartGesture then
        self:GetOwner():AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_SLAM, true)
    end

    self.viewpunch = true
end

function SWEP:CutDuct()
    if self.DamageType ~= DMG_SLASH or CLIENT then return end
    
    local ent = hg.eyeTrace(self:GetOwner()).Entity
    
    if IsValid(ent) then
        if hgIsDoor(ent) and ent.LockedDoor then
            ent.LockedDoor = ent.LockedDoor - FrameTime() * 10
            
            if (ent.SoundTime or 0) < CurTime() then
                ent.SoundTime = CurTime() + 5

                self:GetOwner():EmitSound("tapetear.mp3",65)
                self:PlayAnim("duct_cut",5)
            end

            if ent.LockedDoor <= 0 then
                if !ent.LockedDoorNail and !ent.LockedDoorMap then ent:Fire("unlock", "", 0) end
                ent.LockedDoor = nil
            end
            
            return true
        end

        if ent.DuctTape and next(ent.DuctTape) then
            if (ent.SoundTime or 0) < CurTime() then
                ent.SoundTime = CurTime() + 5

                self:GetOwner():EmitSound("tapetear.mp3",65)
                self:PlayAnim("duct_cut",5)
            end
            
            local key = next(ent.DuctTape)
            local duct = ent.DuctTape[key]
            
            duct[2] = duct[2] - FrameTime()
            
            if duct[2] <= 0 then
                if IsValid(duct[1]) then
                    duct[1]:Remove()
                    duct[1] = nil
                end
                
                ent.DuctTape[key] = nil
            end

            return true
        end
    end
end

function SWEP:CanBlock()
    if (self.HeavyAttackFeintLockEndTime or 0) > CurTime() then return false end
    if self.CanHeavyAttack and self.GetChargeState and self:GetChargeState() > 0 then return false end
    return true
end

function SWEP:SecondaryAttack(override)
    local ply = self:GetOwner()
    if self:IsEquipLocked() then return end
    -- Allow attacking with both arms broken (but not both amputated)
    if ply.organism and ply.organism.larmamputated and self.TwoHanded then return end
    if ply.organism and ply.organism.rarmamputated and ply.organism.larmamputated and self.TwoHanded then return end

    if self.CanHeavyAttack and (hg.KeyDown(ply, IN_USE) or self:GetChargeState() > 0) then return end

    if self:CutDuct() then
        return
    end

    if self:CanBlock() and not override then
        return 
    end

    if self:GetLastBlocked() + 1 > CurTime() then
        return
    end

    if not self:CanSecondaryAttack() then
        
        return
    end

    if not game.SinglePlayer() and not IsFirstTimePredicted() then return end

    local ent = hg.GetCurrentCharacter(ply)

    if !self:InUse() then return end
    if (hg.KeyDown(ply, IN_USE) and not IsValid(ply.FakeRagdoll)) then return end
        if (self:GetLastAttack() + self:GetAttackWait()) > CurTime() then return end
    if self.lastattack and (self.lastattack + self.attackwait) > CurTime() then return end

    local mul = 1
    if ply.organism and ply.organism.stamina and ply.organism.stamina[1] then
        mul = 1 / math.Clamp((180 - ply.organism.stamina[1]) / 90, 1, 2)
    end

    if self:HasBrokenArm(ply) then
        local multiplier = self.BrokenArmPenalty.SwingSpeedMultiplier
        local org = ply.organism
        local checkLeft = self.TwoHanded and (org.larm and org.larm >= 1 and org.larmdislocation)
        local checkRight = (org.rarm and org.rarm >= 1 and org.rarmdislocation)
        if org and (checkLeft or checkRight) then
            multiplier = multiplier * 0.5 -- More severe (even slower)
        end
        mul = mul * multiplier
    end

    self.HitEnts = nil
    self.FirstAttackTick = false
    self.AttackHitPlayed = false
    self.HitWorld = false
    self.ComboAppliedThisAttack = nil
    self:PlayAnim("attack2",self.AnimTime2 / mul,false,nil,false,false)
    self:SetAttackType(2)
    self:SetLastAttack(CurTime() + self.Attack2Time / mul)
    self:SetAttackTime(self:GetLastAttack() + (self.Attack2TimeLength / mul))
    self:SetAttackLength(self.AttackLen2)
    self:SetAttackWait(self.WaitTime2 / mul)
    self:SetInAttack(true)
    self.lastattack = CurTime() + self.Attack2Time / mul
    self.attackwait = self.WaitTime2 / mul
    
    if CLIENT and not self:IsLocal() and ply.AnimRestartGesture then
        ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_SLAM, true)
    end

    self.viewpunch = true
end

function SWEP:InitAdd()
end

if CLIENT then
	SWEP.HowToUseInstructions = "<font=ZCity_Tiny>"..string.upper( (input.LookupBinding("+use") or "BIND YOUR +USE KEY PLEASE. WRITE \"bind e +use\" IN CONSOLE FOR THE LOVE OF GOD") ).." to pickup</font>"
end

local util = util
function SWEP:Initialize()
    self:ResetCombo()
    self.attackanim = 0
    self.sprintanim = 0
    self.animtime = 0
    self.animspeed = 1
    self.reverseanim = false
    self:PlayAnim("idle",10,true)

	if CLIENT then
		self.ShakePos = Vector(0,0,0)
		self.ShakeAng = Angle(0,0,0)
		self.HudHintMarkup = markup.Parse("<font=ZCity_Tiny>".. self.PrintName .."</font>\n<font=ZCity_SuperTiny><colour=125,125,125>".. self.HowToUseInstructions .."</colour></font>",450)
	end

    if self:GetClass() == "weapon_melee" then
        self.ImmobilizationMul = 2
        self.StaminaMul = 0.5
        self.BreakBoneMul = 0.5
        self.ShockMultiplier = 0.5
        self.PainMultiplier = 2

        self.CanSuicide = true

        function self:Reload()
            if SERVER then
                if self:GetOwner():KeyPressed(IN_ATTACK) then
                    self:SetNetVar("mode", not self:GetNetVar("mode"))
                    self:GetOwner():ChatPrint("Changed mode to "..(self:GetNetVar("mode") and "slash." or "stab."))
                    --self.Swing = self:GetNetVar("mode")
                    --self.UpSwing = not self:GetNetVar("mode")
                end
            end
        end

        function self:CustomBlockAnim(addPosLerp, addAngLerp)
            addPosLerp.z = addPosLerp.z + (self:GetBlocking() and 5 or 0)
            addPosLerp.x = addPosLerp.x + (self:GetBlocking() and 2 or 0)
            addPosLerp.y = addPosLerp.y + (self:GetBlocking() and -18 or 0)
            addAngLerp.r = addAngLerp.r + (self:GetBlocking() and 20 or 0)
            addAngLerp.y = addAngLerp.y + (self:GetBlocking() and 60 or 0)
            
            return true
        end

        function self:CanPrimaryAttack()
            if hg.KeyDown(self:GetOwner(), IN_RELOAD) then return end
            if not self:GetNetVar("mode") then
                return true
            else
                self.allowsec = true
                self:SecondaryAttack(true)
                self.allowsec = nil
                return false
            end
        end
        
        function self:CanSecondaryAttack()
            return self.allowsec and true or false
        end
    end

    self:SetAttackLength(60)
    self:SetAttackWait(0)
    if self.modelscale then
        self:SetModelScale(self.modelscale)
        self:Activate()
    end
    self:SetHold(self.HoldType)
    
    if self.SwingSound then util.PrecacheSound(self.SwingSound) end
    util.PrecacheSound(self.AttackSwing)
    util.PrecacheSound(self.AttackHit)
    util.PrecacheSound(self.Attack2Hit)
    util.PrecacheSound(self.AttackHitFlesh)
    if self.HitFleshExtra then
        for _, sound in ipairs(self.HitFleshExtra) do
            util.PrecacheSound(sound)
        end
    end
    if self.HitFleshPlus then
        util.PrecacheSound(self.HitFleshPlus)
    end
    util.PrecacheSound(self.Attack2HitFlesh)
    util.PrecacheSound(self.DeploySnd)
    self:PrecacheConfiguredHitSoundLayer(self.swingsoundextra)
    self:PrecacheConfiguredHitSoundLayer(self.hitsoundextra)
    self:PrecacheConfiguredHitSoundLayer(self.hitsoundplus)
    self:PrecacheConfiguredHitSoundLayer(self.hitsoundbrutalize)

    self:InitAdd()
end

function SWEP:IsLocal()
	if SERVER then return end
	return not ((self:GetOwner() ~= lply) or (lply ~= GetViewEntity()))
end

SWEP.tries = 10

if SERVER then
    util.AddNetworkString("melee_attack")
    util.AddNetworkString("MeleeBlockEffect")
    util.AddNetworkString("MeleeBlockPush")
elseif CLIENT then
    net.Receive("MeleeBlockPush", function()
        local normal = net.ReadVector()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        
        if IsValid(wep) and wep.AddBlockPush then
            wep:AddBlockPush(normal)
        end
    end)

    net.Receive("MeleeBlockEffect", function()
        local pos = net.ReadVector()
        local mat = net.ReadString()
        
        local isBroken = string.sub(mat, -7) == "_broken"
        if isBroken then
            mat = string.sub(mat, 1, -8)
        end
        
        local emitter = ParticleEmitter(pos)
        
        if mat == "wood" then
            if isBroken then
                     for i=1, 30 do
                        local part = emitter:Add("effects/fleck_wood" .. math.random(1,2), pos)
                        if part then
                            part:SetVelocity(VectorRand() * 250 + Vector(0,0,120))
                            part:SetDieTime(3.5)
                            part:SetStartAlpha(255)
                            part:SetEndAlpha(0)
                            part:SetStartSize(2)
                            part:SetEndSize(0)
                            part:SetRoll(math.Rand(0, 360))
                            part:SetGravity(Vector(0,0,-350))
                            part:SetCollide(true)
                            part:SetBounce(0.4)
                        end
                    end
                 for i=1, 5 do
                     local part = emitter:Add("particle/smokesprites_000" .. math.random(1,9), pos)
                     if part then
                         part:SetVelocity(VectorRand() * 28)
                         part:SetDieTime(3)
                         part:SetStartAlpha(110)
                         part:SetEndAlpha(0)
                         part:SetStartSize(10)
                         part:SetEndSize(20)
                         part:SetRoll(math.Rand(0, 360))
                         part:SetColor(100, 90, 70)
                     end
                 end
            else
                for i=1, 5 do
                    local part = emitter:Add("effects/fleck_wood" .. math.random(1,2), pos)
                    if part then
                        part:SetVelocity(VectorRand() * 50 + Vector(0,0,50))
                        part:SetDieTime(3)
                        part:SetStartAlpha(255)
                        part:SetEndAlpha(0)
                        part:SetStartSize(1.5)
                        part:SetEndSize(0)
                        part:SetRoll(math.Rand(0, 360))
                        part:SetGravity(Vector(0,0,-200))
                        part:SetCollide(true)
                    end
                end
                 local part = emitter:Add("particle/smokesprites_000" .. math.random(1,9), pos)
                 if part then
                     part:SetVelocity(VectorRand() * 10)
                     part:SetDieTime(1)
                     part:SetStartAlpha(50)
                     part:SetEndAlpha(0)
                     part:SetStartSize(5)
                     part:SetEndSize(10)
                     part:SetRoll(math.Rand(0, 360))
                 end
            end
             
        elseif mat == "metal" then
            if isBroken then
                for i=1, 35 do
                    local part = emitter:Add("effects/spark", pos)
                    if part then
                        part:SetVelocity(VectorRand() * 260)
                        part:SetDieTime(1.2)
                        part:SetStartAlpha(255)
                        part:SetEndAlpha(0)
                        part:SetStartSize(1.8)
                        part:SetEndSize(0)
                        part:SetRoll(math.Rand(0, 360))
                        part:SetGravity(Vector(0,0,-350))
                        part:SetCollide(true)
                        part:SetBounce(0.45)
                    end
                end
                 local part = emitter:Add("effects/yellowflare", pos)
                 if part then
                     part:SetVelocity(Vector(0,0,0))
                     part:SetDieTime(0.16)
                     part:SetStartAlpha(255)
                     part:SetEndAlpha(0)
                     part:SetStartSize(45)
                     part:SetEndSize(0)
                 end
                 
                 for i=1, 3 do
                     local part = emitter:Add("particle/smokesprites_000" .. math.random(1,9), pos)
                     if part then
                         part:SetVelocity(VectorRand() * 24)
                         part:SetDieTime(1.7)
                         part:SetStartAlpha(120)
                         part:SetEndAlpha(0)
                         part:SetStartSize(10)
                         part:SetEndSize(22)
                         part:SetRoll(math.Rand(0, 360))
                         part:SetColor(100,100,100)
                     end
                 end
            else
                for i=1, 10 do
                    local part = emitter:Add("effects/spark", pos)
                    if part then
                        part:SetVelocity(VectorRand() * 100)
                        part:SetDieTime(0.5)
                        part:SetStartAlpha(255)
                        part:SetEndAlpha(0)
                        part:SetStartSize(2)
                        part:SetEndSize(0)
                        part:SetRoll(math.Rand(0, 360))
                        part:SetGravity(Vector(0,0,-200))
                        part:SetCollide(true)
                        part:SetBounce(0.5)
                    end
                end
                 local part = emitter:Add("effects/yellowflare", pos)
                 if part then
                     part:SetVelocity(Vector(0,0,0))
                     part:SetDieTime(0.1)
                     part:SetStartAlpha(255)
                     part:SetEndAlpha(0)
                     part:SetStartSize(20)
                     part:SetEndSize(0)
                 end
            end
        end
        
        emitter:Finish()
    end)
    net.Receive("melee_attack",function()
        local tbl = net.ReadTable()
        local ent = net.ReadEntity()
        local sendtoclient = net.ReadBool()

        if ent.IsLocal and (not ent:IsLocal() or sendtoclient) then
            if IsValid(ent) and ent.PlayAnim then
                ent:PlayAnim(tbl.anim,tbl.time,tbl.cycling,tbl.callback,tbl.reverse)

                if (tbl.anim == "attack" or tbl.anim == "attack2") and ent:GetOwner().AnimRestartGesture and IsValid(ent:GetOwner()) and not ent:GetOwner():IsWorld() then
                    ent:GetOwner():AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_SLAM, true)
                end
            end
        end
    end)
end

function SWEP:PlayAnim(anim, time, cycling, callback, reverse, sendtoclient)
    if SERVER then
        sendtoclient = sendtoclient or false
        net.Start("melee_attack")
            local netTbl = {
                anim = anim,
                time = time,
                cycling = cycling,
                callback = callback,
                reverse = reverse
            }
            net.WriteTable(netTbl) 
            net.WriteEntity(self)
            net.WriteBool(sendtoclient)
        net.SendPVS(self:GetPos())
    return end
    if not IsValid(self:GetWM()) or not IsValid(self:GetOwner()) or self:GetOwner():GetActiveWeapon() ~= self then
		self.tries = self.tries - 1
		if self.tries > 0 then
			timer.Simple(0.01,function()
                if not IsValid(self) then return end
				self:PlayAnim(anim,time,cycling,callback,reverse)
			end)
		end
		return
	end

    local mdl = self:GetWM()
    self.tries = 10
    local mdl = self:GetWM()
    self.tries = 10
    if self:GetWM():GetModel() ~= self.WorldModelReal then self:GetWM():SetModel(self.WorldModelReal) end
    
    if CLIENT then
        self.hitstopToken = (self.hitstopToken or 0) + 1
        timer.Remove("hg_melee_hitstop_" .. self:EntIndex())
        self.stopanim = nil
    end
    
    self:GetWM():SetSequence(self.AnimList[anim] or anim)
    self.animtime = CurTime() + time
    self.animspeed = time
    self.cycling = cycling
    self.reverseanim = reverse
    if callback then
        self.callback = callback
    end
end

function SWEP:SetFakeGun(ent)
	self:SetNWEntity("fakeGun", ent)
	self.fakeGun = ent
end

function SWEP:RemoveFake()
	if not IsValid(self.fakeGun) then return end
	self.fakeGun:Remove()
	self:SetFakeGun()
end

local function GetPhysBoneNum(ent,string)
	if not IsValid(ent) then return 7 end
	return ent:TranslateBoneToPhysBone(ent:LookupBone(string))
end

function SWEP:CreateFake(ragdoll)
	if IsValid(self:GetNWEntity("fakeGun")) then return end
	if not IsValid(ragdoll) then return end
	local ent = ents.Create("prop_physics")
    ent.notprop = true
	local physbonerh = GetPhysBoneNum(ragdoll,"ValveBiped.Bip01_R_Hand")
	local rh = ragdoll:GetPhysicsObjectNum(physbonerh)

	ent:SetPos(rh:GetPos())
	ent:SetModel(self.WorldModel)
	ent:Spawn()
	ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	ent:SetMoveType(MOVETYPE_NONE)
	ent:GetPhysicsObject():SetMass(0)
    ent:SetNoDraw(true)
    ent.dontPickup = true
	ent.fakeOwner = self
	ragdoll:DeleteOnRemove(ent)
	ragdoll.fakeGun = ent
	if IsValid(ragdoll.ConsRH) then ragdoll.ConsRH:Remove() end
	self:SetFakeGun(ent)
	ent:CallOnRemove("homigrad-swep", self.RemoveFake, self)

	ent:SetNoDraw(true)
end

function SWEP:NPCThink()
    local npc = self:GetOwner()
    self:SetWeaponHoldType("melee")
    
    if npc:GetClass() == "npc_metropolice" then
        self:SetWeaponHoldType("smg")
    end
    
    --npc:Fire( "GagEnable" )
    
    if npc:GetClass() == "npc_citizen" then
        --npc:Fire( "DisableWeaponPickup" )
    end
    
    local enemy = npc:GetEnemy()
    if not enemy then return end

    local dist = enemy:GetPos():Distance(npc:GetPos())

    if enemy and dist > 85 then
        --npc:SetSchedule(SCHED_CHASE_ENEMY)
    end

    if dist < 85 and (self.LastNPCAttack or 0) < CurTime() then
		local timerId = (self:EntIndex() .. "_NPCAttack")
		if timer.Exists(timerId) then return end

        local dmg = math.random(self.DamagePrimary - 3, self.DamagePrimary + 3)
        
        local tr = {}
        tr.start = npc:EyePos()
        tr.endpos = enemy.EyePos and enemy:EyePos() or enemy:GetPos()
        tr.filter = npc

        local trace = util.TraceLine(tr)
		--  trace.Entity == ((enemy:IsPlayer() and IsValid(enemy.FakeRagdoll) and (enemy.organism and not enemy.organism.otrib)) and enemy.FakeRagdoll or enemy)
        local trEnt = IsValid(trace.Entity) and trace.Entity
		if IsValid(trEnt) then
			self.LastNPCAttack = CurTime() + (self.AnimTime1 or 1)
			self:PlaySwingSound(npc)

            npc:SetSchedule(SCHED_MELEE_ATTACK1)
			timer.Create(timerId, (self.AttackTime + 0.1) or 0.4, 1, function()
				if IsValid(self) and IsValid(npc) and npc:Alive() and IsValid(trEnt) then
					local mul = 1
					mul = mul * (self:BehindAttack(trEnt) and 2 or 1)
					mul = mul * self:BlockingLogic(trEnt, mul, false, trace)
					trEnt:PrecacheGibs()

					dmg = dmg * mul
					local dmginfo = DamageInfo()
					dmginfo:SetAttacker(npc)
					dmginfo:SetInflictor(self)
					dmginfo:SetDamage(dmg)
					dmginfo:SetDamageForce(trace.Normal * dmg * MELEE_GLOBAL_KNOCKBACK_MUL)
					dmginfo:SetDamageType(self.DamageType)
					dmginfo:SetDamagePosition(trace.HitPos)
					trEnt:TakeDamageInfo(dmginfo)
                    self:PlaySoftHitSounds(npc, trEnt, trace, false)

					if trEnt:IsPlayer() then
						local headHit = self:IsHeadHit(trEnt, trace)
						local hitForce = self:GetRagdollHitForce(trEnt, trace.Normal, dmg, false)
						if headHit then
							hitForce.x = hitForce.x * (self.HeadRagdollForceMul or 1.35)
							hitForce.y = hitForce.y * (self.HeadRagdollForceMul or 1.35)
							hitForce.z = hitForce.z * (self.HeadRagdollUpMul or 1.2)
						end
						hg.AddForceRag(trEnt, trace.PhysicsBone or 0, hitForce, 0.5)

						self:PunchPlayer(trEnt, false, trace.Normal, dmg)
		
						local phys = trEnt:GetPhysicsObjectNum(trace.PhysicsBone or 0)
		
						if IsValid(phys) then
							phys:ApplyForceOffset(hitForce, trace.HitPos)
						end

						if self:ShouldHeadRagdoll(trEnt, trace) then
							timer.Simple(0, function()
								local victim = self:GetHitVictim(trEnt)
								if IsValid(victim) and victim:IsPlayer() and victim:Alive() and not IsValid(victim.FakeRagdoll) then
									hg.Fake(victim)
								end
							end)
						end
					end
				end
				if timer.Exists(timerId) then timer.Remove(timerId) end
			end)
        end
    end
end

function SWEP:GetNPCRestTimes()
	return self.AnimTime1, self.AnimTime1
end

function SWEP:GetCapabilities()
    if (self.NPCThinktime or 0) < CurTime() then self.NPCThinktime = CurTime() + 0.01 self:NPCThink() end
    return bit.bor( CAP_WEAPON_MELEE_ATTACK1, CAP_MOVE_GROUND )
end

function SWEP:SetupWeaponHoldTypeForAI( t )
	self.ActivityTranslateAI = {}
	if ( t == "melee" ) then
		self.ActivityTranslateAI [ ACT_IDLE ] 						= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_ANGRY ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_RELAXED ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_STIMULATED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AGITATED ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_RELAXED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_STIMULATED ] 		= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_AGITATED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_RANGE_ATTACK1 ] 				= ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_RANGE_ATTACK1_LOW ]          = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_MELEE_ATTACK1 ]              = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_MELEE_ATTACK2 ]              = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_SPECIAL_ATTACK1 ] 			= ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		
		self.ActivityTranslateAI [ ACT_RANGE_AIM_LOW ]              = ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_COVER_LOW ] 					= ACT_HL2MP_IDLE_KNIFE
		
		self.ActivityTranslateAI [ ACT_WALK ] 						= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM ]				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_RELAXED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_STIMULATED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_AGITATED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_RELAXED ] 				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_STIMULATED ] 			= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_AGITATED ] 				= ACT_HL2MP_WALK_KNIFE
		
		self.ActivityTranslateAI[ ACT_RUN_RELAXED ]			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_STIMULATED ]		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_AGITATED ]		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_CROUCH ] 				= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_CROUCH_AIM ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN ] 						= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_RELAXED ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_STIMULATED ] 		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_AGITATED ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM ] 					= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_MP_RUN ] 					= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_SMALL_FLINCH ] 				= ACT_RANGE_ATTACK_PISTOL
		self.ActivityTranslateAI [ ACT_BIG_FLINCH ] 				= ACT_RANGE_ATTACK_PISTOL
		
		return
	end
	
	if ( t == "smg" ) then
	
		self.ActivityTranslateAI [ ACT_IDLE ] 						= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_ANGRY ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_RELAXED ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_STIMULATED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AGITATED ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_RELAXED ]			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_STIMULATED ]		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_AGITATED ]		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_CROUCH ] 				= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_CROUCH_AIM ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN ] 						= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_RELAXED ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_STIMULATED ] 		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_AGITATED ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM ] 					= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_MP_RUN ] 					= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_WALK ] 						= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM ]				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_RELAXED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_STIMULATED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_AGITATED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_RELAXED ] 				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_STIMULATED ] 			= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_AGITATED ] 				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_MELEE_ATTACK1 ] 				= ACT_MELEE_ATTACK_SWING
		self.ActivityTranslateAI [ ACT_RANGE_ATTACK1 ] 				= ACT_MELEE_ATTACK_SWING
		self.ActivityTranslateAI [ ACT_SPECIAL_ATTACK1 ] 			= ACT_RANGE_ATTACK_THROW
		self.ActivityTranslateAI [ ACT_SMALL_FLINCH ] 				= ACT_RANGE_ATTACK_PISTOL
		self.ActivityTranslateAI [ ACT_BIG_FLINCH ] 				= ACT_RANGE_ATTACK_PISTOL
		
		return
	end
	
	if ( t == "shotgun" ) then
		
		self.ActivityTranslateAI [ ACT_IDLE ] 						= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_ANGRY ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_RELAXED ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_STIMULATED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AGITATED ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_RELAXED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_STIMULATED ] 		= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_AGITATED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_RANGE_ATTACK1 ] 				= ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_RANGE_ATTACK1_LOW ]          = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_MELEE_ATTACK1 ]              = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_MELEE_ATTACK2 ]              = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_SPECIAL_ATTACK1 ] 			= ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		
		self.ActivityTranslateAI [ ACT_RANGE_AIM_LOW ]              = ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_COVER_LOW ] 					= ACT_HL2MP_IDLE_KNIFE
		
		self.ActivityTranslateAI [ ACT_WALK ] 						= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM ]				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_RELAXED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_STIMULATED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_AGITATED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_RELAXED ] 				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_STIMULATED ] 			= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_AGITATED ] 				= ACT_HL2MP_WALK_KNIFE
		
		self.ActivityTranslateAI[ ACT_RUN_RELAXED ]			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_STIMULATED ]		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_AGITATED ]		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_CROUCH ] 				= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_CROUCH_AIM ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN ] 						= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_RELAXED ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_STIMULATED ] 		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_AGITATED ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM ] 					= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_MP_RUN ] 					= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_SMALL_FLINCH ] 				= ACT_RANGE_ATTACK_PISTOL
		self.ActivityTranslateAI [ ACT_BIG_FLINCH ] 				= ACT_RANGE_ATTACK_PISTOL
		
		return
	end
	
	if ( t == "pistol") then 
		self.ActivityTranslateAI [ ACT_IDLE ] 						= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_ANGRY ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_RELAXED ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_STIMULATED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AGITATED ] 				= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_RELAXED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_STIMULATED ] 		= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_IDLE_AIM_AGITATED ] 			= ACT_HL2MP_IDLE_KNIFE
		self.ActivityTranslateAI [ ACT_RANGE_ATTACK1 ] 				= ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_RANGE_ATTACK1_LOW ]          = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_MELEE_ATTACK1 ]              = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_MELEE_ATTACK2 ]              = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		self.ActivityTranslateAI [ ACT_SPECIAL_ATTACK1 ] 			= ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE
		
		self.ActivityTranslateAI [ ACT_RANGE_AIM_LOW ]              = ACT_IDLE_SHOTGUN
		self.ActivityTranslateAI [ ACT_COVER_LOW ] 					= ACT_IDLE_SHOTGUN
		
		self.ActivityTranslateAI [ ACT_WALK ] 						= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM ]				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_RELAXED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_STIMULATED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI[ ACT_WALK_AIM_AGITATED ]		= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_RELAXED ] 				= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_STIMULATED ] 			= ACT_HL2MP_WALK_KNIFE
		self.ActivityTranslateAI [ ACT_WALK_AGITATED ] 				= ACT_HL2MP_WALK_KNIFE
		
		self.ActivityTranslateAI[ ACT_RUN_RELAXED ]			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_STIMULATED ]		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI[ ACT_RUN_AGITATED ]		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_CROUCH ] 				= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_CROUCH_AIM ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN ] 						= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_RELAXED ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_STIMULATED ] 		= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM_AGITATED ] 			= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_RUN_AIM ] 					= ACT_HL2MP_RUN_KNIFE
		self.ActivityTranslateAI [ ACT_MP_RUN ] 					= ACT_HL2MP_RUN_KNIFE
		
		return
	end
end

function SWEP:CanBePickedUpByNPCs()
	return true
end

--[[function SWEP:CustomAttack2() -- prikol
    local ent = ents.Create("ent_throwable")
    ent.WorldModel = self.WorldModelExchange or self.WorldModel

    local ply = self:GetOwner()

    ent:SetPos(select(1, hg.eye(ply,60,hg.GetCurrentCharacter(ply))) - ply:GetAimVector() * 2)
    ent:SetAngles(ply:EyeAngles())
    ent:SetOwner(self:GetOwner())
    ent:Spawn()

    ent.localshit = Vector(0,0,0)
    ent.wep = self:GetClass()
    ent.owner = ply
    ent.damage = self.DamagePrimary * 0.7
    ent.MaxSpeed = 1300
    ent.DamageType = self.DamageType
    ent.AttackHit = "Concrete.ImpactHard"
    ent.AttackHitFlesh = "Flesh.ImpactHard"
    ent.noStuck = true

    local phys = ent:GetPhysicsObject()

    if IsValid(phys) then
        local throwVel = ply:GetAimVector() * ent.MaxSpeed
        local playerVel = ply:GetVelocity()
        phys:SetVelocity(throwVel + playerVel * 0.5)
        phys:AddAngleVelocity(VectorRand() * 500)
    end

    //ply:EmitSound("weapons/slam/throw.wav",50,math.random(95,105))
    ply:ViewPunch(self.ViewPunch1 * 0.6)
    ply:SelectWeapon("weapon_hands_sh")

    self:Remove()

    return true
end]]
