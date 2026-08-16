AddCSLuaFile("shared.lua")
include("shared.lua")
ENT.IconOverride = "vgui/entities/seal.png"

local screamSounds = {
    "sealplush/krik.wav",
    "sealplush/krik2.wav",
    "sealplush/krik3.wav",
    "sealplush/krik4.wav",
}

util.AddNetworkString("SealPickedUpSound")
util.AddNetworkString("SealHeldState")
util.AddNetworkString("SealAIToggle")

function ENT:Initialize()
    self:SetModel("models/sealplush/sealplush.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetDamping(0.3, 0.6)
    end

    self.State     = "idle"
    self.Hunger    = math.random() * 20
    self.Tiredness = math.random() * 30
    self.Boredom   = math.random() * 15
    self.Social    = math.random() * 10

    self.LastDriveUpdate = CurTime()
    self.Mood            = 0
    self.LastMoodUpdate  = CurTime()
    self.RecentActions   = {}

    self.Personality = math.random() > 0.4 and "playful" or "loner"
    self.IsLazy      = math.random() > 0.55

    self.BlinkTimerID        = nil
    self.PlayTarget          = nil
    self.BuddySeal           = nil
    self.LastBigDamageTime   = 0
    self.NextPlayAllowedTime = 0
    self.NextBuddyCheck      = 0
    self.IsEating            = false
    self.IsSleeping          = false
    self.HasSleepNeed        = math.random() > 0.3
    self.NextSleepAllowed    = 0
    self.IsSwimming          = false
    self.NextSwimCheck       = 0
    self.NextBehaviorCheck   = 0
    self.CarryingProp        = false
    self.CarryWeld           = nil
    self.FlippedSince        = nil
    self.FlipAttemptTime     = nil
    self.FlippedWasBusy      = false
    self.FlipAttempts        = 0
    self.WantsSleep          = false
    self.AIDisabled          = false

    local cfg = HG_SEAL_CONFIG or {}
    self.SealAlive = true
    self.SealBlood = cfg.MAX_BLOOD_ML or 1200
    self.SealMaxBlood = self.SealBlood
    self.SealBleedRate = 0
    self.SealPhysiologyTime = CurTime()
    self:SetMaxHealth(cfg.MAX_HEALTH or 100)
    self:SetHealth(cfg.MAX_HEALTH or 100)
    self:SetNW2Bool("SealAlive", true)
    self:SetNW2Float("SealBlood", self.SealBlood)
    self:SetNW2Float("SealBleedRate", 0)

    self:SetSkin(0)
    self:EmitSound("sealplush/ohmygah.wav", 75, 100)
    self:StartBlinking()
    self:StartIdleMovement()
    self:StartRandomSounds()
end

local function RemoveSealTimers(ent)
    local idx = ent:EntIndex()
    timer.Remove("SealHop_" .. idx)
    timer.Remove("SealPlay_" .. idx)
    timer.Remove("SealBuddy_" .. idx)
    timer.Remove("SealChaseFish_" .. idx)
    timer.Remove("SealRandomSound_" .. idx)
    if ent.BlinkTimerID then timer.Remove(ent.BlinkTimerID) end
end

function ENT:SyncPhysiology()
    self:SetNW2Bool("SealAlive", self.SealAlive == true)
    self:SetNW2Float("SealBlood", math.max(self.SealBlood or 0, 0))
    self:SetNW2Float("SealBleedRate", math.max(self.SealBleedRate or 0, 0))
end

function ENT:KillSeal(reason)
    if not self.SealAlive then return end
    local cfg = HG_SEAL_CONFIG or {}
    self.SealAlive = false
    self.SealDeathReason = reason
    self.SealDeathTime = CurTime()
    self.SealBleedRate = 0
    self:SetHealth(0)
    self:SetState("dead")
    self.IsSleeping = false
    self.IsEating = false
    self.AIDisabled = true
    RemoveSealTimers(self)
    self:StopSound("sealplush/snop.wav")
    self:SyncPhysiology()

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self.SealRemoveAt = self.SealDeathTime + (cfg.CORPSE_LIFETIME or 15)
end

function ENT:UpdatePhysiology(now)
    local cfg = HG_SEAL_CONFIG or {}
    local last = self.SealPhysiologyTime or now
    local dt = math.Clamp(now - last, 0, 0.25)
    self.SealPhysiologyTime = now

    if self.SealAlive then
        local bleedRate = math.max(self.SealBleedRate or 0, 0)
        if bleedRate > 0 and dt > 0 then
            self.SealBlood = math.max((self.SealBlood or 0) - bleedRate * dt, 0)
            self.SealBleedRate = bleedRate * math.exp(-(cfg.BLEED_CLOT_RATE or 0.02) * dt)
        end

        if bleedRate >= 0.5 and now >= (self.NextSealBleedFX or 0) then
            local intensity = math.Clamp(bleedRate / 25, 0, 1)
            self.NextSealBleedFX = now + Lerp(intensity, 1.1, 0.28)
            local pos = self.SealLastWoundLocal and self:LocalToWorld(self.SealLastWoundLocal) or self:WorldSpaceCenter()
            local effect = EffectData()
            effect:SetOrigin(pos)
            effect:SetNormal(VectorRand():GetNormalized())
            effect:SetColor(BLOOD_COLOR_RED)
            effect:SetScale(Lerp(intensity, 0.35, 0.9))
            util.Effect("BloodImpact", effect, true, true)
            local tr = util.TraceLine({start = pos, endpos = pos + Vector(0, 0, -80), filter = self, mask = MASK_SOLID})
            if tr.Hit then util.Decal("Blood", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal) end
        end

        local maxBlood = self.SealMaxBlood or cfg.MAX_BLOOD_ML or 1200
        if maxBlood - (self.SealBlood or 0) >= (cfg.FATAL_BLOOD_LOSS_ML or 500) then
            self:KillSeal("bloodloss")
        elseif self:Health() <= 0 then
            self:KillSeal("damage")
        end
        self:SyncPhysiology()
        return
    end

    local removeAt = self.SealRemoveAt or (now + (cfg.CORPSE_LIFETIME or 15))
    self.SealRemoveAt = removeAt
    local fadeTime = math.max(cfg.CORPSE_FADE_TIME or 3, 0.1)
    local fadeStart = removeAt - fadeTime
    if now >= fadeStart then
        local alpha = math.Clamp((removeAt - now) / fadeTime, 0, 1) * 255
        local color = self:GetColor()
        self:SetColor(Color(color.r, color.g, color.b, alpha))
    end
    if now >= removeAt then self:Remove() end
end

function ENT:ArmThrownImpact(thrower, speed)
    local cfg = HG_SEAL_CONFIG or {}
    self.SealThrower = IsValid(thrower) and thrower or nil
    self.SealThrowMaxSpeed = math.max(speed or cfg.THROW_SPEED or 760, 1)
    self.SealThrowDamageUntil = CurTime() + (cfg.THROW_DAMAGE_WINDOW or 2)
    self.SealThrowDamageSpent = false
end

function ENT:SetState(newState)
    if self.State == newState then return end
    self.State = newState
end

function ENT:UpdateDrives()
    local now = CurTime()
    local dt  = now - self.LastDriveUpdate
    self.LastDriveUpdate = now
    local state = self.State

    self.Hunger = math.min(self.Hunger + 0.8 * dt, 100)

    if self.HasSleepNeed and not self.IsSleeping then
        local tiredRate = 0
        if state == "playing" or state == "chasing" then
            tiredRate = 2.5
        elseif state == "idle" then
            tiredRate = 0.5
        elseif state == "flipped" then
            tiredRate = 0.2
        end
        self.Tiredness = math.min(self.Tiredness + tiredRate * dt, 100)
    end

    if state == "idle" then
        self.Boredom = math.min(self.Boredom + 1.2 * dt, 100)
    else
        self.Boredom = math.max(self.Boredom - 3 * dt, 0)
    end

    if self.Personality == "playful" then
        if IsValid(self.BuddySeal) or state == "playing" then
            self.Social = math.max(self.Social - 4 * dt, 0)
        else
            self.Social = math.min(self.Social + 0.6 * dt, 100)
        end
    end
end

function ENT:UpdateMood()
    local now = CurTime()
    local dt  = now - self.LastMoodUpdate
    self.LastMoodUpdate = now

    local satisfaction = 1
        - (self.Hunger    / 100) * 0.3
        - (self.Tiredness / 100) * 0.3
        - (self.Boredom   / 100) * 0.2
        - (self.Social    / 100) * 0.2

    local targetMood = satisfaction * 2 - 1
    self.Mood = self.Mood + (targetMood - self.Mood) * 0.05 * dt * 10
    self.Mood = math.Clamp(self.Mood, -1, 1)
end

function ENT:RecordAction(action)
    table.insert(self.RecentActions, action)
    if #self.RecentActions > 3 then
        table.remove(self.RecentActions, 1)
    end
end

function ENT:WasRecentAction(action)
    for _, a in ipairs(self.RecentActions) do
        if a == action then return true end
    end
    return false
end

function ENT:ChooseBehavior()
    if self.State ~= "idle" then return end
    if self.IsSwimming then return end

    local weights = {}

    if self.HasSleepNeed and self.Tiredness >= 70 and CurTime() >= self.NextSleepAllowed then
        weights["sleep"] = self.Tiredness
        if self:WasRecentAction("sleep") then weights["sleep"] = weights["sleep"] * 0.3 end
    end

    local moodBonus = (self.Mood + 1) * 0.5
    weights["fish"] = self.Hunger * (0.7 + moodBonus * 0.3)
    if self:WasRecentAction("fish") then weights["fish"] = weights["fish"] * 0.5 end

    if CurTime() >= self.NextPlayAllowedTime then
        weights["prop"] = self.Boredom * (0.5 + moodBonus * 0.5)
        if self.Personality == "loner" then weights["prop"] = weights["prop"] * 0.6 end
        if self:WasRecentAction("prop") then weights["prop"] = weights["prop"] * 0.4 end
    end

    if self.Personality == "playful" then
        weights["buddy"] = self.Social * 1.2
        if self:WasRecentAction("buddy") then weights["buddy"] = weights["buddy"] * 0.4 end
    end

    if self.Personality == "playful" and self.Mood > 0.2 and not self:WasRecentAction("wakeBuddy") then
        weights["wakeBuddy"] = 15 * moodBonus
    end

    weights["hop"] = 10 + self.Boredom * 0.2
    if self:WasRecentAction("hop") then weights["hop"] = weights["hop"] * 0.5 end

    local best, bestW = nil, -1
    for action, w in pairs(weights) do
        if w > bestW then
            best  = action
            bestW = w
        end
    end

    if not best then return end
    self:RecordAction(best)

    if best == "sleep" then
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            local roll = self:GetAngles().roll
            phys:ApplyTorqueCenter(Vector((roll > 0 and -1 or 1) * 1500, 0, 0))
        end
    elseif best == "fish" then
        self:HandleFishDetection()
    elseif best == "prop" then
        self:StartPlayWithProp()
    elseif best == "buddy" then
        self:FindAndPlayWithBuddy()
    elseif best == "wakeBuddy" then
        self:TryWakeSleepingBuddy()
    elseif best == "hop" then
        self:PerformHop()
    end
end

function ENT:Think()
    local now = CurTime()
    self:UpdatePhysiology(now)
    if not IsValid(self) then return end

    if not self.SealAlive then
        self:NextThink(now + 0.1)
        return true
    end

    local state = self.State
    local isBeingHeld = self:IsPlayerHolding()
    if isBeingHeld and state ~= "held" then
        self:OnPickedUp()
    elseif not isBeingHeld and state == "held" then
        if not self.PickupDelay or now > self.PickupDelay then self:OnPutDown() end
    end

    local aiDisabled = GetConVar("ai_disabled")
    local globalAIDisabled = aiDisabled and aiDisabled:GetBool() or false
    if globalAIDisabled ~= self.AIDisabled then
        self.AIDisabled = globalAIDisabled
        if globalAIDisabled then self:DisableAI() else self:EnableAI() end
    end

    if self.AIDisabled then
        self:NextThink(now + 0.2)
        return true
    end

    if state ~= "held" and now > self.NextSwimCheck then
        self.NextSwimCheck = now + 0.1
        self:CheckSwimming()
    end
    if state ~= "held" then
        self:UpdateDrives()
        self:UpdateMood()
    end
    if state == "idle" and not self.IsSwimming and now > self.NextBehaviorCheck then
        self.NextBehaviorCheck = now + 3
        self:ChooseBehavior()
    end

    self:CheckFlipped()
    self:NextThink(now + 0.05)
    return true
end

function ENT:DisableAI()
    local idx = self:EntIndex()
    timer.Remove("SealHop_"       .. idx)
    timer.Remove("SealPlay_"      .. idx)
    timer.Remove("SealBuddy_"     .. idx)
    timer.Remove("SealChaseFish_" .. idx)
    self.PlayTarget = nil
    self.BuddySeal  = nil
    if self.State ~= "held" then
        self:SetState("idle")
        if not self.IsEating then self:SetSkin(0) end
    end
end

function ENT:EnableAI()
    self:StartIdleMovement(true)
    self:StartRandomSounds()
end

function ENT:ToggleAI()
    self.AIDisabled = not self.AIDisabled
    if self.AIDisabled then
        self:DisableAI()
        local idx = self:EntIndex()
        timer.Remove("SealRandomSound_" .. idx)
        if self.BlinkTimerID then timer.Remove(self.BlinkTimerID) end
        self:StartBlinking()
    else
        self:EnableAI()
    end
end

function ENT:OnPickedUp()
    self:SetState("held")
    local idx = self:EntIndex()
    timer.Remove("SealHop_"       .. idx)
    timer.Remove("SealPlay_"      .. idx)
    timer.Remove("SealBuddy_"     .. idx)
    timer.Remove("SealChaseFish_" .. idx)
    if IsValid(self.CarryWeld) then
        self.CarryWeld:Remove()
        self.CarryWeld = nil
    end
    self.CarryingProp = false
    self.PlayTarget   = nil
    self.BuddySeal    = nil
    if self.IsSwimming then
        self.IsSwimming = false
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetDamping(0.3, 0.6)
            phys:EnableGravity(true)
        end
    end
end

function ENT:OnPutDown()
    self:SetState("idle")
    self:SetSkin(0)
    if self.BlinkTimerID then timer.Remove(self.BlinkTimerID) end
    self:StartBlinking()
    self:StartIdleMovement(true)
end

function ENT:Use(activator, caller)
    if not self.SealAlive or self.SealConverting then return end
    if not IsValid(caller) or not caller:IsPlayer() or not caller:Alive() then return end
    if IsValid(caller.FakeRagdoll) then return end
    if IsValid(caller:GetWeapon("sealweapon")) then return end

    self.SealConverting = true
    local wep = ents.Create("sealweapon")
    if not IsValid(wep) then self.SealConverting = false return end
    wep:SetPos(self:GetPos())
    wep:SetAngles(self:GetAngles())
    wep:Spawn()
    wep.CurrentSkin = self:GetSkin()
    wep.WMSkin = self:GetSkin()
    wep.SealStoredHealth = self:Health()
    wep.SealStoredBlood = self.SealBlood
    wep.SealStoredBleedRate = self.SealBleedRate

    if hook.Run("PlayerCanPickupWeapon", caller, wep) == false then
        wep:Remove()
        self.SealConverting = false
        return
    end

    caller:PickupWeapon(wep)
    if wep:GetOwner() ~= caller then
        wep:Remove()
        self.SealConverting = false
        return
    end

    self:EmitSound("sealplush/squeak4.wav", 50, 100)
    self:Remove()
end

function ENT:IsUpsideDown()
    return self:GetUp().z < -0.5
end

function ENT:CheckFlipped()
    local state = self.State
    if state == "held" then return end

    if self:IsUpsideDown() then
        if state ~= "flipped" then
            self.FlippedWasBusy = (state == "playing" or state == "chasing")
            self:SetState("flipped")
            local idx = self:EntIndex()
            timer.Remove("SealHop_"       .. idx)
            timer.Remove("SealPlay_"      .. idx)
            timer.Remove("SealChaseFish_" .. idx)
            if self.BlinkTimerID then
                timer.Remove(self.BlinkTimerID)
                self.BlinkTimerID = nil
            end
            self.PlayTarget   = nil
            self.FlippedSince = CurTime()
            self.IsSleeping   = false
            self.FlipAttempts = 0

            local wantsSleep = self.HasSleepNeed
                and not self.FlippedWasBusy
                and CurTime() >= self.NextSleepAllowed
                and self.Tiredness >= 50

            if self.FlippedWasBusy then
                self.FlipAttemptTime = CurTime() + math.Rand(3, 6)
                self.WantsSleep = false
            elseif wantsSleep then
                self.FlipAttemptTime = CurTime() + math.Rand(60, 120)
                self.WantsSleep = true
            else
                self.FlipAttemptTime = CurTime() + math.Rand(5, 10)
                self.WantsSleep = false
            end
        end

        local now = CurTime()

        if self.WantsSleep and not self.IsSleeping and now - self.FlippedSince > 2 then
            self.IsSleeping = true
            self.IsEating   = false
            self:SetSkin(1)
            self:EmitSound("sealplush/snop.wav", 70, 100, 1, CHAN_STATIC)
        end

        if self.FlipAttemptTime and now > self.FlipAttemptTime then
            self.FlipAttemptTime = nil
            if self.IsSleeping then self:WakeUp() end
            self:TryFlip()
        end

    else
        if state == "flipped" then
            if self.IsSleeping then self:WakeUp() end
            self:SetState("idle")
            self.FlippedSince    = nil
            self.FlipAttemptTime = nil
            self.FlippedWasBusy  = false
            self.FlipAttempts    = 0
            self.WantsSleep      = false
            if not self.IsEating then self:SetSkin(0) end
            self:StartBlinking()
            self:StartIdleMovement(true)
        end
    end
end

function ENT:WakeUp(byBuddy)
    if not self.IsSleeping then return end
    self.IsSleeping = false
    self:StopSound("sealplush/snop.wav")
    local pitch = self.Mood > 0 and math.random(95, 110) or math.random(80, 95)
    self:EmitSound("sealplush/angry.wav", 75, pitch)
    self.Tiredness        = 0
    self.NextSleepAllowed = CurTime() + math.Rand(120, 180)
    self.Boredom = math.max(self.Boredom - 30, 0)

    if byBuddy then
        self.Mood = math.max(self.Mood - 0.5, -1)
        self:SetSkin(7)
        timer.Simple(2, function()
            if IsValid(self) and self.State ~= "scared" and self.State ~= "flipped" and not self.IsEating then
                self:SetSkin(0)
            end
        end)
    end
end

function ENT:TryFlip()
    local phys = self:GetPhysicsObject()
    if not IsValid(phys) then return end
    phys:SetVelocity(phys:GetVelocity() * 0.1)
    self.FlipAttempts = (self.FlipAttempts or 0) + 1
    local force   = math.min(2000 + self.FlipAttempts * 800, 8000)
    local roll    = self:GetAngles().roll
    local flipDir = (roll > 0) and -1 or 1
    if self.FlipAttempts % 2 == 0 then flipDir = -flipDir end
    phys:ApplyTorqueCenter(Vector(flipDir * force, 0, 0))
    phys:ApplyForceCenter(Vector(flipDir * force * 0.15, 0, 0))
    self.FlipAttemptTime = CurTime() + math.Rand(2, 3)
end

function ENT:StartBlinking()
    if self.SealAlive == false then return end
    if not IsValid(self) then return end
    if self.State == "scared" then return end
    if self.State == "flipped" and self.IsSleeping then return end

    local id = "SealBlink_" .. self:EntIndex()
    self.BlinkTimerID = id
    local interval = self.Mood > 0.3 and math.Rand(4, 8) or math.Rand(2, 5)

    timer.Create(id, interval, 1, function()
        if not IsValid(self) then return end
        if self.State == "scared" then return end
        if self.IsSleeping then return end

        local prevSkin = self:GetSkin()
        if prevSkin == 3 or prevSkin == 4 or prevSkin == 5 then
            self:StartBlinking()
            return
        end

        self:SetSkin(1)
        timer.Simple(0.1, function()
            if IsValid(self) and self.State ~= "scared" and not self.IsSleeping then
                self:SetSkin(prevSkin == 1 and 0 or prevSkin)
                self:StartBlinking()
            end
        end)
    end)
end

function ENT:StartRandomSounds()
    if self.SealAlive == false then return end
    if not IsValid(self) then return end
    local id = "SealRandomSound_" .. self:EntIndex()
    timer.Create(id, math.random(15, 30), 0, function()
        if not IsValid(self) then timer.Remove(id) return end
        if self.State ~= "scared" and not self.IsSleeping then
            local vol = self.Mood > 0 and 110 or 90
            self:EmitSound("sealplush/soundseal1.wav", vol, 100)
        end
    end)
end

function ENT:StartIdleMovement(immediate)
    if self.SealAlive == false then return end
    if not IsValid(self) then return end
    if self.State == "held" or self.State == "flipped" then return end

    local id = "SealHop_" .. self:EntIndex()
    timer.Remove(id)

    local minDelay = self.IsLazy and 10 or 5
    local maxDelay = (self.Tiredness > 60) and 25 or 15
    local delay    = math.Rand(minDelay, maxDelay)

    if immediate then self:PerformHop() end

    timer.Create(id, delay, 1, function()
        if IsValid(self) and self.State == "idle" then
            self:PerformHop()
            self:StartIdleMovement()
        end
    end)
end

function ENT:PerformHop()
    local phys = self:GetPhysicsObject()
    if not IsValid(phys) then return end

    local angVel = phys:GetAngleVelocity()
    phys:SetAngleVelocity(Vector(angVel.x * 0.15, angVel.y * 0.15, angVel.z * 0.15))

    local moodMult = 0.7 + (self.Mood + 1) * 0.3
    local angle    = math.Rand(0, 360)
    local dir      = Vector(math.cos(math.rad(angle)), math.sin(math.rad(angle)), 0)

    local hopMin = math.floor(1200 * moodMult)
    local hopMax = math.floor(1800 * moodMult)
    local upMin  = math.floor(3500 * moodMult)
    local upMax  = math.floor(4500 * moodMult)

    local hopForce = dir * math.random(hopMin, hopMax) + Vector(0, 0, math.random(upMin, upMax))
    phys:ApplyForceCenter(hopForce)

    local curYaw    = self:GetAngles().yaw
    local targetYaw = angle - 90
    local diff      = math.AngleDifference(targetYaw, curYaw)
    if math.abs(diff) > 30 then
        phys:ApplyTorqueCenter(Vector(0, 0, diff * 3))
    end
end

function ENT:Scare()
    if self.SealAlive == false then return end
    if self.State == "scared" or self.State == "held" then return end
    if self.IsSleeping then return end
    self:SetState("scared")
    if self.BlinkTimerID then timer.Remove(self.BlinkTimerID) end
    self:SetSkin(3)
    self:EmitSound("npc/roller/code2.wav", 75, 100)
    self.Social = math.min(self.Social + 15, 100)

    timer.Simple(2, function()
        if not IsValid(self) then return end
        if self.State == "scared" then
            self:SetState("idle")
            self:SetSkin(0)
            self:StartBlinking()
        end
    end)
end

function ENT:OnTakeDamage(dmg)
    self:TakePhysicsDamage(dmg)
    if not self.SealAlive then return end

    local amount = math.max(dmg:GetDamage(), 0)
    if amount <= 0 then return end
    local damagePos = dmg:GetDamagePosition()
    if isvector(damagePos) and damagePos:LengthSqr() > 0 then self.SealLastWoundLocal = self:WorldToLocal(damagePos) end
    self:SetHealth(math.max(self:Health() - amount, 0))

    local bleedAdd = 0
    if dmg:IsDamageType(DMG_BULLET) or dmg:IsDamageType(DMG_BUCKSHOT) then
        bleedAdd = amount * 0.5
    elseif dmg:IsDamageType(DMG_SLASH) then
        bleedAdd = amount * 0.4
    elseif dmg:IsDamageType(DMG_BLAST) then
        bleedAdd = amount * 0.18
    elseif (dmg:IsDamageType(DMG_CRUSH) or dmg:IsDamageType(DMG_CLUB)) and amount >= 15 then
        bleedAdd = amount * 0.08
    end
    self.SealBleedRate = math.min((self.SealBleedRate or 0) + bleedAdd, 80)

    if amount >= 20 and CurTime() - self.LastBigDamageTime > 10 then
        self.LastBigDamageTime = CurTime()
        self:SetSkin(4)
        if self.IsSleeping then self:WakeUp() end
        self.Mood = math.max(self.Mood - 0.4, -1)
        local soundToPlay = screamSounds[math.random(#screamSounds)]
        self:StopSound(soundToPlay)
        self:EmitSound(soundToPlay, 299, math.random(95, 110))
        timer.Simple(3, function()
            if IsValid(self) and self.SealAlive and self.State ~= "scared" then self:SetSkin(0) end
        end)
    elseif amount >= 5 then
        self:Scare()
    end

    if self:Health() <= 0 then self:KillSeal("damage") end
    self:SyncPhysiology()
end

function ENT:PhysicsCollide(data, physobj)
    if self.SealAlive and not self.SealThrowDamageSpent and CurTime() <= (self.SealThrowDamageUntil or 0) then
        local hit = data.HitEntity
        local ragOwner = IsValid(hit) and hit:IsRagdoll() and hg.RagdollOwner and hg.RagdollOwner(hit) or nil
        local target = IsValid(ragOwner) and ragOwner or hit
        local cfg = HG_SEAL_CONFIG or {}
        local speed = math.max(data.Speed or 0, 0)
        if IsValid(target) and target ~= self and speed >= (cfg.THROW_MIN_DAMAGE_SPEED or 300) then
            local maxSpeed = math.max(self.SealThrowMaxSpeed or cfg.THROW_SPEED or 760, 1)
            local speedFraction = math.Clamp((speed - (cfg.THROW_MIN_DAMAGE_SPEED or 300)) / math.max(maxSpeed - (cfg.THROW_MIN_DAMAGE_SPEED or 300), 1), 0, 1)
            local mass = IsValid(physobj) and math.max(physobj:GetMass(), 0.1) or (cfg.THROW_REFERENCE_MASS or 8)
            local massFactor = math.Clamp(math.sqrt(mass / math.max(cfg.THROW_REFERENCE_MASS or 8, 0.1)), 0.75, 1.35)
            local damage = (cfg.THROW_DAMAGE or 19) * speedFraction * massFactor
            if damage > 1 then
                local dmg = DamageInfo()
                dmg:SetAttacker(IsValid(self.SealThrower) and self.SealThrower or self)
                dmg:SetInflictor(self)
                dmg:SetDamage(damage)
                dmg:SetDamageType(DMG_CLUB)
                dmg:SetDamagePosition(data.HitPos)
                dmg:SetDamageForce(data.OurOldVelocity * massFactor)
                target:TakeDamageInfo(dmg)
                self.SealThrowDamageSpent = true
            end
        end
    end

    if self.SealAlive and data.DeltaTime > 0.2 and data.Speed > 150 then self:Scare() end
end

function ENT:OnRemove()
    RemoveSealTimers(self)
    if IsValid(self.CarryWeld) then self.CarryWeld:Remove() end
    self:StopSound("sealplush/snop.wav")
end

function ENT:HandleFishDetection()
    local searchRadius = 200 + self.Hunger
    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), searchRadius)) do
        if IsValid(ent) and ent:GetClass() == "fish_entity" then
            self:StartChasingFish(ent)
            return
        end
    end
end

function ENT:StartChasingFish(fish)
    if not IsValid(fish) then return end
    self:SetState("chasing")
    self.PlayTarget = fish
    timer.Remove("SealHop_" .. self:EntIndex())

    local pitch = math.floor(90 + (self.Hunger / 100) * 20)
    self:EmitSound("sealplush/yamapika.wav", 75, pitch)

    local id = "SealChaseFish_" .. self:EntIndex()
    timer.Create(id, 0.5, 0, function()
        if not IsValid(self) then timer.Remove(id) return end

        if self.State ~= "chasing" then
            timer.Remove(id)
            self.PlayTarget = nil
            return
        end

        if not IsValid(fish) then
            timer.Remove(id)
            self.PlayTarget = nil
            self:SetState("idle")
            self:StartIdleMovement(true)
            return
        end

        if self:GetPos():Distance(fish:GetPos()) < 50 then
            self:EmitSound("sealplush/bite.wav", 75, 100)
            fish:Remove()
            timer.Remove(id)
            self.PlayTarget = nil
            self:SetState("idle")
            self.Hunger  = 0
            self.Mood    = math.min(self.Mood + 0.3, 1)
            self.Boredom = math.max(self.Boredom - 20, 0)
            self.IsEating = true
            self:SetSkin(5)
            timer.Simple(1.5, function()
                if IsValid(self) then
                    self.IsEating = false
                    if self.State ~= "scared" and self.State ~= "flipped" then
                        self:SetSkin(0)
                    end
                end
            end)
            self:StartIdleMovement(true)
            return
        end

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            local dir = (fish:GetPos() - self:GetPos()):GetNormalized()
            self:ApplySteerTorque(dir:Angle().yaw)
            local speedBoost = 1 + (self.Hunger / 100) * 0.4
            phys:ApplyForceCenter(dir * math.floor(1000 * speedBoost) + Vector(0, 0, math.random(2500, 4000)))
        end
    end)
end

function ENT:ApplySteerTorque(targetYaw)
    local phys = self:GetPhysicsObject()
    if not IsValid(phys) then return end
    local angVel = phys:GetAngleVelocity()
    phys:SetAngleVelocity(Vector(angVel.x, angVel.y, angVel.z * 0.4))
    local diff = math.AngleDifference(targetYaw, self:GetAngles().yaw)
    if math.abs(diff) > 15 then
        phys:ApplyTorqueCenter(Vector(0, 0, diff * 2.5))
    end
end

function ENT:FindPlayTarget()
    if self.Personality == "loner" and math.random() > 0.4 then return nil end

    local pos = self:GetPos()
    local best, bestDist = nil, math.huge

    for _, ent in ipairs(ents.FindInSphere(pos, 350)) do
        if IsValid(ent) and ent:GetClass() == "prop_physics" then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) and phys:GetMass() <= 15 then
                local zDiff = math.abs(ent:GetPos().z - pos.z)
                if zDiff <= 40 then
                    local dist = ent:GetPos():Distance(pos)
                    if dist < bestDist then
                        bestDist = dist
                        best = ent
                    end
                end
            end
        end
    end

    return best
end

function ENT:StartPlayWithProp()
    if self.State ~= "idle" then return end
    if CurTime() < self.NextPlayAllowedTime then return end

    local target = self:FindPlayTarget()
    if not IsValid(target) then return end

    self:SetState("playing")
    self.PlayTarget = target
    timer.Remove("SealHop_" .. self:EntIndex())

    local id      = "SealPlay_" .. self:EntIndex()
    local endTime = CurTime() + math.Rand(10, 20)
    local nextActionTime = 0

    timer.Create(id, 0.2, 0, function()
        if not IsValid(self) then timer.Remove(id) return end

        if self.State ~= "playing" or not IsValid(self.PlayTarget) then
            timer.Remove(id)
            self.PlayTarget = nil
            self.NextPlayAllowedTime = CurTime() + math.Rand(20, 35)
            if self.State == "playing" then
                self:SetState("idle")
                self:StartIdleMovement(true)
            end
            return
        end

        if CurTime() > endTime then
            timer.Remove(id)
            self.PlayTarget = nil
            self.NextPlayAllowedTime = CurTime() + math.Rand(40, 60)
            self.Boredom = math.max(self.Boredom - 35, 0)
            self.Mood    = math.min(self.Mood + 0.15, 1)
            self:SetState("idle")
            self:StartIdleMovement(true)
            return
        end

        if CurTime() < nextActionTime then return end

        local phys = self:GetPhysicsObject()
        local dist = self:GetPos():Distance(self.PlayTarget:GetPos())
        if not IsValid(phys) then return end

        local dir = (self.PlayTarget:GetPos() - self:GetPos()):GetNormalized()
        self:ApplySteerTorque(dir:Angle().yaw)

        local moodMult = 0.8 + (self.Mood + 1) * 0.2

        if dist > 120 then
            phys:ApplyForceCenter(dir * math.floor(1000 * moodMult) + Vector(0, 0, math.random(2000, 3000)))
            nextActionTime = CurTime() + 0.6
        else
            local action = math.random(4)
            if action == 1 then
                local targetPhys = self.PlayTarget:GetPhysicsObject()
                if IsValid(targetPhys) then
                    targetPhys:ApplyForceCenter(dir * math.random(800, 1500) + Vector(0, 0, math.random(300, 600)))
                end
                phys:ApplyForceCenter(-dir * 200 + Vector(0, 0, 500))
                nextActionTime = CurTime() + math.Rand(1.5, 3)
            elseif action == 2 then
                local sideDir = Vector(-dir.y, dir.x, 0)
                phys:ApplyForceCenter(sideDir * math.floor(800 * moodMult) + Vector(0, 0, math.random(2500, 3500)))
                nextActionTime = CurTime() + math.Rand(1, 2)
            elseif action == 3 then
                nextActionTime = CurTime() + math.Rand(0.8, 1.5)
            else
                if not self.CarryingProp then
                    self.CarryingProp = true
                    local weld = constraint.Weld(self, self.PlayTarget, 0, 0, 0, true)
                    self.CarryWeld = weld
                    local hopDir = Vector(math.cos(math.rad(math.Rand(0,360))), math.sin(math.rad(math.Rand(0,360))), 0)
                    phys:ApplyForceCenter(hopDir * math.random(1000, 1600) + Vector(0, 0, math.random(3000, 4500)))
                    timer.Simple(math.Rand(2, 4), function()
                        if IsValid(self) then
                            self.CarryingProp = false
                            if IsValid(self.CarryWeld) then
                                self.CarryWeld:Remove()
                                self.CarryWeld = nil
                            end
                        end
                    end)
                end
                nextActionTime = CurTime() + math.Rand(3, 5)
            end
        end
    end)
end

function ENT:FindAndPlayWithBuddy()
    if self.Personality ~= "playful" then return end
    if self.State ~= "idle" then return end

    if IsValid(self.BuddySeal) then
        local dist = self:GetPos():Distance(self.BuddySeal:GetPos())
        if dist > 500 then
            self.BuddySeal = nil
        else
            self:StartPlayWithBuddy(self.BuddySeal)
            return
        end
    end

    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 400)) do
        if IsValid(ent)
            and ent:GetClass() == self:GetClass()
            and ent ~= self
            and ent.Personality == "playful"
            and ent.State == "idle"
            and not IsValid(ent.BuddySeal) then

            self.BuddySeal = ent
            ent.BuddySeal  = self
            self:StartPlayWithBuddy(ent)
            return
        end
    end
end

function ENT:StartPlayWithBuddy(buddy)
    if not IsValid(buddy) or self.State ~= "idle" then return end

    self:SetState("playing")
    self.PlayTarget = buddy
    timer.Remove("SealHop_" .. self:EntIndex())

    local id      = "SealBuddy_" .. self:EntIndex()
    local endTime = CurTime() + math.Rand(15, 30)

    timer.Create(id, 0.5, 0, function()
        if not IsValid(self) then timer.Remove(id) return end

        if self.State ~= "playing" or not IsValid(self.PlayTarget) then
            timer.Remove(id)
            self.PlayTarget = nil
            self.BuddySeal  = nil
            if self.State == "playing" then
                self:SetState("idle")
                self:StartIdleMovement(true)
            end
            return
        end

        if CurTime() > endTime then
            timer.Remove(id)
            self.Social  = math.max(self.Social - 40, 0)
            self.Boredom = math.max(self.Boredom - 25, 0)
            self.Mood    = math.min(self.Mood + 0.2, 1)
            self.PlayTarget = nil
            self.BuddySeal  = nil
            self:SetState("idle")
            self:StartIdleMovement(true)
            return
        end

        local dist = self:GetPos():Distance(buddy:GetPos())
        if dist > 600 then
            timer.Remove(id)
            self.PlayTarget = nil
            self.BuddySeal  = nil
            self:SetState("idle")
            self:StartIdleMovement(true)
            return
        end

        local phys = self:GetPhysicsObject()
        if not IsValid(phys) then return end

        local dir = (buddy:GetPos() - self:GetPos()):GetNormalized()
        self:ApplySteerTorque(dir:Angle().yaw)

        local moodMult = 0.8 + (self.Mood + 1) * 0.2

        if dist > 80 then
            phys:ApplyForceCenter(dir * math.floor(900 * moodMult) + Vector(0, 0, math.random(2000, 3000)))
        else
            local action = math.random(3)
            if action == 1 then
                phys:ApplyForceCenter(dir * math.floor(600 * moodMult) + Vector(0, 0, math.random(2500, 4000)))
            elseif action == 2 then
                local sideDir = Vector(-dir.y, dir.x, 0)
                phys:ApplyForceCenter(sideDir * math.floor(700 * moodMult) + Vector(0, 0, math.random(2000, 3000)))
            end
        end
    end)
end

function ENT:TryWakeSleepingBuddy()
    if self.Personality ~= "playful" then return end
    if self.State ~= "idle" then return end
    if math.random() > 0.10 then return end

    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 350)) do
        if IsValid(ent)
            and ent:GetClass() == self:GetClass()
            and ent ~= self
            and ent.IsSleeping
            and ent.State == "flipped" then

            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                local dir = (ent:GetPos() - self:GetPos()):GetNormalized()
                dir.z = 0
                phys:ApplyForceCenter(dir * math.random(1500, 2500) + Vector(0, 0, math.random(2000, 3500)))
                self:EmitSound("sealplush/squeak4.wav", 60, math.random(95, 115))
            end

            timer.Simple(0.8, function()
                if IsValid(ent) and ent.IsSleeping then
                    ent:WakeUp(true)
                    local victimPhys = ent:GetPhysicsObject()
                    if IsValid(victimPhys) then
                        local knockDir = (ent:GetPos() - self:GetPos()):GetNormalized()
                        knockDir.z = 0.5
                        victimPhys:ApplyForceCenter(knockDir:GetNormalized() * math.random(3000, 5000))
                    end
                    ent:EmitSound("sealplush/krik.wav", 75, math.random(90, 110))
                    timer.Simple(0.1, function()
                        if IsValid(ent) then ent:Scare() end
                    end)
                end
            end)

            return
        end
    end
end

function ENT:IsInWater()
    return self:WaterLevel() >= 1
end

function ENT:CheckSwimming()
    local inWater = self:IsInWater()

    if inWater and not self.IsSwimming then
        self.IsSwimming   = true
        self.SwimPhase    = "surface"
        self.SwimDir      = Vector(1, 0, 0)
        self.SwimSpeed    = 0
        self.SwimTargetSpeed = 0
        self.SwimPhaseEnd = 0
        self.SwimTurnEnd  = 0
        self.SwimDiveZ    = nil
        self.SwimCruiseZ  = nil
        self.SwimRollPhase = 0

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableGravity(false)
            phys:SetDamping(4, 8)
            phys:SetVelocity(phys:GetVelocity() * 0.2)
            phys:SetAngleVelocity(Vector(0, 0, 0))
        end

        local idx = self:EntIndex()
        timer.Remove("SealHop_"       .. idx)
        timer.Remove("SealPlay_"      .. idx)
        timer.Remove("SealChaseFish_" .. idx)
        self.PlayTarget = nil

        self.Boredom = math.max(self.Boredom - 15, 0)
        self.Mood    = math.min(self.Mood + 0.1, 1)

    elseif not inWater and self.IsSwimming then
        self.IsSwimming      = false
        self.SwimPhase       = nil
        self.SwimDir         = nil
        self.SwimSpeed       = nil
        self.SwimRollPhase   = nil

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableGravity(true)
            phys:SetDamping(0.3, 0.6)
            local vel = phys:GetVelocity()
            phys:SetVelocity(Vector(vel.x * 0.3, vel.y * 0.3, math.max(vel.z * 0.2, 0)))
            phys:SetAngleVelocity(Vector(0, 0, 0))
        end

        if self.State == "idle" then
            self:StartIdleMovement(true)
        end
    end

    if self.IsSwimming then self:WaterTick() end
end

function ENT:WaterTick()
    local phys = self:GetPhysicsObject()
    if not IsValid(phys) then return end

    local now  = CurTime()
    local epos = self:GetPos()

    local tr = util.TraceLine({
        start  = epos,
        endpos = epos + Vector(0, 0, 500),
        mask   = MASK_WATER,
    })
    local surfZ = tr.Hit and tr.HitPos.z or (epos.z + 50)
    local depth = surfZ - epos.z
    local phase = self.SwimPhase or "surface"
    if not self.SwimDir or now > (self.SwimTurnEnd or 0) then
        local ang        = math.Rand(0, 360)
        local newDir     = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
        self.SwimDir     = newDir
        self.SwimTurnEnd = now + math.Rand(4, 10)
        local targetYaw = math.deg(math.atan2(newDir.y, newDir.x))
        local diff      = math.AngleDifference(targetYaw, self:GetAngles().yaw)
        phys:ApplyTorqueCenter(Vector(0, 0, diff * 15))
    end
    self.SwimSpeed = self.SwimSpeed or 0
    local baseSpeed = self.IsLazy and 55 or 80
    if phase == "surface" then
        self.SwimTargetSpeed = baseSpeed * 0.7
        if now > (self.SwimPhaseEnd or 0) then
            if math.random() < 0.4 then
                self.SwimPhase    = "diving"
                self.SwimPhaseEnd = now + math.Rand(4, 8)
                self.SwimDiveZ    = epos.z - math.Rand(80, 200)
                self.SwimTargetSpeed = baseSpeed * 1.3
            else
                self.SwimPhaseEnd = now + math.Rand(3, 6)
            end
        end
        local targetZ = surfZ - 20
        local zErr    = targetZ - epos.z
        local zVel    = phys:GetVelocity().z
        local zForce  = math.Clamp(zErr * 8 - zVel * 2, -60, 60)
        self.SwimSpeed = self.SwimSpeed + (self.SwimTargetSpeed - self.SwimSpeed) * 0.08
        local vel = phys:GetVelocity()
        phys:SetVelocity(Vector(
            self.SwimDir.x * self.SwimSpeed,
            self.SwimDir.y * self.SwimSpeed,
            vel.z * 0.6 + zForce * 0.08
        ))
        self.SwimRollPhase = (self.SwimRollPhase or 0) + 0.06
        local rollAmt = math.sin(self.SwimRollPhase) * 8
        local curAng  = self:GetAngles()
        self:SetAngles(Angle(curAng.pitch * 0.9, curAng.yaw, rollAmt))
        phys:SetAngleVelocity(Vector(0, 0, 0))

    elseif phase == "diving" then
        local targetZ = self.SwimDiveZ or (epos.z - 100)
        local zErr    = targetZ - epos.z

        if math.abs(zErr) < 25 or now > (self.SwimPhaseEnd or 0) then
            self.SwimPhase    = "cruising"
            self.SwimPhaseEnd = now + math.Rand(4, 10)
            self.SwimCruiseZ  = epos.z
        else
            self.SwimTargetSpeed = baseSpeed * 1.2
            self.SwimSpeed = self.SwimSpeed + (self.SwimTargetSpeed - self.SwimSpeed) * 0.1

            local diveRatio = math.Clamp(zErr / 100, -1, 1)
            local pitchTarget = diveRatio * -35
            local curAng = self:GetAngles()
            local newPitch = curAng.pitch + (pitchTarget - curAng.pitch) * 0.12
            local hSpeed = self.SwimSpeed * math.cos(math.rad(newPitch))
            local vSpeed = self.SwimSpeed * math.sin(math.rad(-newPitch))

            phys:SetVelocity(Vector(
                self.SwimDir.x * hSpeed,
                self.SwimDir.y * hSpeed,
                -vSpeed
            ))
            self.SwimRollPhase = (self.SwimRollPhase or 0) + 0.07
            local rollAmt = math.sin(self.SwimRollPhase) * 10
            self:SetAngles(Angle(newPitch, curAng.yaw, rollAmt))
            phys:SetAngleVelocity(Vector(0, 0, 0))
        end
    elseif phase == "cruising" then
        local targetZ = self.SwimCruiseZ or epos.z
        local zErr    = targetZ - epos.z
        local zVel    = phys:GetVelocity().z
        local zForce  = math.Clamp(zErr * 6 - zVel * 1.5, -40, 40)

        if now > (self.SwimPhaseEnd or 0) then
            self.SwimPhase    = "ascending"
            self.SwimPhaseEnd = now + math.Rand(3, 5)
        end

        self.SwimTargetSpeed = baseSpeed * 1.0
        self.SwimSpeed = self.SwimSpeed + (self.SwimTargetSpeed - self.SwimSpeed) * 0.07

        phys:SetVelocity(Vector(
            self.SwimDir.x * self.SwimSpeed,
            self.SwimDir.y * self.SwimSpeed,
            phys:GetVelocity().z * 0.6 + zForce * 0.06
        ))
        self.SwimRollPhase = (self.SwimRollPhase or 0) + 0.06
        local rollAmt = math.sin(self.SwimRollPhase) * 9
        local curAng  = self:GetAngles()
        self:SetAngles(Angle(curAng.pitch * 0.88, curAng.yaw, rollAmt))
        phys:SetAngleVelocity(Vector(0, 0, 0))

    elseif phase == "ascending" then
        local targetZ = surfZ - 20
        local zErr    = targetZ - epos.z
        if epos.z >= surfZ - 30 or now > (self.SwimPhaseEnd or 0) then
            self.SwimPhase    = "surface"
            self.SwimPhaseEnd = now + math.Rand(3, 7)
        else
            self.SwimTargetSpeed = baseSpeed * 1.1
            self.SwimSpeed = self.SwimSpeed + (self.SwimTargetSpeed - self.SwimSpeed) * 0.1

            local ascentRatio = math.Clamp(zErr / 80, -1, 1)
            local pitchTarget = ascentRatio * -20
            local curAng = self:GetAngles()
            local newPitch = curAng.pitch + (pitchTarget - curAng.pitch) * 0.1

            local hSpeed = self.SwimSpeed * math.cos(math.rad(newPitch))
            local vSpeed = self.SwimSpeed * math.abs(math.sin(math.rad(newPitch)))

            phys:SetVelocity(Vector(
                self.SwimDir.x * hSpeed,
                self.SwimDir.y * hSpeed,
                vSpeed
            ))

            self.SwimRollPhase = (self.SwimRollPhase or 0) + 0.07
            local rollAmt = math.sin(self.SwimRollPhase) * 8
            self:SetAngles(Angle(newPitch, curAng.yaw, rollAmt))
            phys:SetAngleVelocity(Vector(0, 0, 0))
        end
    end
    if self.SwimDir then
        local targetYaw = math.deg(math.atan2(self.SwimDir.y, self.SwimDir.x))
        local curYaw    = self:GetAngles().yaw
        local diff      = math.AngleDifference(targetYaw, curYaw)
        if math.abs(diff) > 8 then
            local av = phys:GetAngleVelocity()
            phys:SetAngleVelocity(Vector(av.x, av.y, av.z * 0.2))
            phys:ApplyTorqueCenter(Vector(0, 0, diff * 3))
        end
    end
end