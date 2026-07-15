--
local CurTime = CurTime
util.AddNetworkString("hgwep reload")

local function GetFearReloadFactors(ply)
	local org = IsValid(ply) and ply.organism or nil
	local fear = math.Clamp(org and org.fear or 0, 0, 2)
	local adrenaline = math.Clamp(org and org.adrenaline or 0, 0, 2)
	local jitter = math.max(0, adrenaline - 1.25)
	local stabilizer = math.min(adrenaline, 1.25) * 0.05
	local speedFactor = (1 + fear * 0.15 + jitter * 0.05) / (1 + stabilizer)
	local dropFactor = 1 + fear * 0.2 + jitter * 0.1
	local fumbleChance = math.min((fear + jitter) * 0.03, 0.25)
	return speedFactor, dropFactor, fumbleChance
end

SWEP.ArmReloadPenalty = {
    PainOnReload = 35, -- pain when reloading with broken left arm (increased from 12)
    MissingRightArmSpeedMul = 0.4, -- 60% slower when right arm is missing
    MissingRightArmPain = 55, -- pain when right arm missing + left arm broken (increased from 20)
    LeftArmBrokenReloadSlow = 1.5, -- extra multiplier when left arm is broken
    BrokenArmPickupPain = 20 -- pain when using broken arm to pick up items
}

function SWEP:CanRackWithOneHand()
    local ply = self:GetOwner()
    return self:CanRackOrReloadManualAction(ply)
end

function SWEP:HasRightArmMissing()
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply.organism then return false end
    return ply.organism.rarmamputated
end

function SWEP:GetReloadArmPenalty()
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply.organism then return 0, 1 end
    local org = ply.organism
    local pain = 0
    local speedMul = 1

    -- Check right arm health
    local rightArmHealthy = org.rarm and org.rarm < 1 and not org.rarmdislocation and not org.rarmamputated
    local leftArmBroken = ((org.larm and org.larm > 0) or org.larmdislocation) and not org.larmamputated

    -- Pain from left arm broken during reload (only if not amputated)
    if leftArmBroken and not org.larmamputated then
        pain = pain + (self.ArmReloadPenalty.PainOnReload or 35) * (org.larm or 0)
        if org.larmdislocation then
            pain = pain + 15
        end
    end

    -- Speed: only slow down if right arm is also damaged/missing
    -- If right arm is healthy, reload is fast even with left arm broken
    if leftArmBroken and not rightArmHealthy then
        speedMul = speedMul * (1 + (self.ArmReloadPenalty.LeftArmBrokenReloadSlow or 0.5))
    end

    -- Very hard to use two-handed guns when right arm is missing
    if org.rarmamputated and not org.larmamputated then
        speedMul = speedMul * (self.ArmReloadPenalty.MissingRightArmSpeedMul or 0.4)
        -- Extra pain if left arm is also damaged
        if leftArmBroken then
            pain = pain + (self.ArmReloadPenalty.MissingRightArmPain or 55)
        end
    end

    return pain, speedMul
end

function SWEP:Reload(time)
	if self.reload then return end

	local ply = self:GetOwner()
	local org = ply.organism

	local manualBlock = self:GetManualActionBlockReason(ply)
	if manualBlock then
		if SERVER then ply:Notify(manualBlock .. " I cant reload this properly.", 2) end
		self:OnCantReload()
		return
	end

	if IsValid(ply.FakeRagdoll) and ply.FakeRagdoll.ConsLH then
		return
	end

	if not self:CanUse() or not self:CanReload() then self:OnCantReload() return end

	self.LastReload = CurTime()
	self:ReloadStart()
	self:ReloadStartPost()
	local org = self:GetOwner().organism

	-- Get arm-related penalties
	local armPain, armSpeedMul = self:GetReloadArmPenalty()

	self.StaminaReloadMul = (org and ((2 - (self:GetOwner().organism.stamina[1] / 180)) + ((org.pain / 40) + (org.larm / 3) + (org.rarm / 5)) - (1 - math.Clamp(org.recoilmul or 1,0.45,1.4))) or 1)
	local fearSpeedFactor = GetFearReloadFactors(self:GetOwner())
	self.StaminaReloadMul = self.StaminaReloadMul * fearSpeedFactor
	self.StaminaReloadMul = math.Clamp(self.StaminaReloadMul,0.65,1.5)

	-- Apply arm speed penalty
	self.StaminaReloadMul = self.StaminaReloadMul * armSpeedMul

	self.StaminaReloadTime = self.ReloadTime * self.StaminaReloadMul
	self.StaminaReloadTime = (self.StaminaReloadTime + (self:Clip1() > 0 and -self.StaminaReloadTime/3 or 0 ))
	self.reload = self.LastReload + self.StaminaReloadTime
	self.dwr_reverbDisable = true

	-- Add pain from arm damage
	if armPain > 0 and org then
		org.painadd = (org.painadd or 0) + armPain
	end

	net.Start("hgwep reload")
		net.WriteEntity(self)
		net.WriteFloat(self.LastReload)
		net.WriteInt(self:Clip1(),10)
		net.WriteFloat(self.StaminaReloadTime)
		net.WriteFloat(self.StaminaReloadMul)
	net.Broadcast()
end

function SWEP:OnCantReload()

end

function SWEP:ReloadStart()
	self:SetHold(self.ReloadHold or self.HoldType)
	hook.Run("HGReloading", self)
	--if self.ReloadSound then self:GetOwner():EmitSound(self.ReloadSound, 60, 100, 0.8, CHAN_AUTO) end
end

local randomgovno = {
	"Shit.. I missed...",
	"Fuck.. I dropped it...",
}

-- возможно немного насралкод но работает норм
local IsValid, hg, pairs, isnumber, timer, math, AngleRand, timer = IsValid, hg, pairs, isnumber, timer, math, AngleRand, timer

local function FailSafe(ply)
	if not IsValid(ply) then return end

	ply:SetNW2Bool("FloorReloading", false)
	if timer.Exists("FloorReload_"..ply:SteamID64()) then
		timer.Remove("FloorReload_"..ply:SteamID64())
	end
end

local function SafeCheck(ply, ent, dist)
	if not IsValid(ply) and not ply:Alive() then return false end
	if (ply:GetNetVar("carryent2") ~= ent and not IsValid(ply.FakeRagdoll)) or dist then FailSafe(ply) return false end

	local org = ply.organism
	if org.rarmamputated and org.larmamputated then FailSafe(ply) return false end
	if not ply:GetNW2Bool("FloorReloading", false) then FailSafe(ply) return false end

	return true
end

local mRandom, mRand, mClamp = math.random, math.Rand, math.Clamp

local function GetFloorReloadHandling(ply)
	local org = ply.organism or {}
	local rightUsable = not org.rarmamputated
	local leftUsable = not org.larmamputated
	local rightBroken = rightUsable and ((org.rarm or 0) >= 1 or org.rarmdislocation or org.rarmdislocated)
	local leftBroken = leftUsable and ((org.larm or 0) >= 1 or org.larmdislocation or org.larmdislocated)
	local rightHealthy = rightUsable and not rightBroken
	local leftHealthy = leftUsable and not leftBroken

	local chosenArm, isRight, isBroken
	if rightUsable and leftUsable then
		chosenArm, isRight, isBroken = "both", false, rightBroken or leftBroken
	elseif rightHealthy then
		chosenArm, isRight, isBroken = "right", true, false
	elseif leftHealthy then
		chosenArm, isRight, isBroken = "left", false, false
	elseif rightUsable then
		chosenArm, isRight, isBroken = "right", true, true
	elseif leftUsable then
		chosenArm, isRight, isBroken = "left", false, true
	else
		return nil, false, true, 1, 1, 0
	end

	local speedMult = (chosenArm == "both") and 0.38 or 0.75
	local dropChanceMult = (chosenArm == "both") and 0.25 or 0.75
	-- One-handed floor reloads are possible, but the weaker left-hand-only
	-- manipulation is much more likely to fail than the usual right hand.
	local reloadFailChance = chosenArm == "right" and 0.12 or (chosenArm == "left" and 0.42 or 0)
	local painAmount = 0
	local missingHands = (rightUsable and 0 or 1) + (leftUsable and 0 or 1)
	local damagedHands = (rightBroken and 1 or 0) + (leftBroken and 1 or 0)

	if missingHands > 0 then
		speedMult = speedMult + missingHands * 0.45
		dropChanceMult = dropChanceMult + missingHands * 0.45
	end

	if damagedHands > 0 then
		speedMult = speedMult + damagedHands * 0.28
		dropChanceMult = dropChanceMult + damagedHands * 0.35
	end

	if leftBroken then
		painAmount = painAmount + 6 + (org.larm or 0) * 4 + ((org.larmdislocation or org.larmdislocated) and 5 or 0)
	end

	if rightBroken then
		painAmount = painAmount + 8 + (org.rarm or 0) * 5 + ((org.rarmdislocation or org.rarmdislocated) and 6 or 0)
	end

	if isBroken then
		speedMult = speedMult + 0.25
		dropChanceMult = dropChanceMult + 0.25
		painAmount = painAmount + 5
	end

	return chosenArm, isRight, isBroken, math.Clamp(speedMult, 0.5, 1.9), math.Clamp(dropChanceMult, 0.4, 2.0), painAmount, reloadFailChance
end

concommand.Add("hg_reloadfloorweapon", function(ply, cmd, args)
	if not IsValid(ply) and not ply:Alive() then return end
	local org = ply.organism
	if ply:GetNWBool("hg_hold_wound_manual", false) or org.rarmamputated and org.larmamputated then return end

	local ent = (IsValid(hg.eyeTrace(ply).Entity) and hg.eyeTrace(ply).Entity) or (IsValid(ply:GetNetVar("carryent")) and ply:GetNetVar("carryent"))
	if not IsValid(ent) or not ishgweapon(ent) or ent:GetPos():DistToSqr(ply:GetPos()) > 6000 then return end

	local isshotgun = (ent.Base == "weapon_m4super" or ent:GetClass() == "weapon_m4super")
	local limbs = ply:GetNWBool("hg_hold_wound_manual", false) or org.rarmamputated or org.larmamputated
	local clip, maxclip, ammocount = ent:Clip1(), ent:GetMaxClip1(), ply:GetAmmoCount(ent.Primary.Ammo)
	local needsCycle = ent.IsManuallyCycledWeapon and ent:IsManuallyCycledWeapon() and ent.drawBullet == false

	-- Calculate prioritized arm and penalties for floor reload
	local chosenArm, isRight, isBroken, speedMult, dropChanceMult, painAmount, reloadFailChance = GetFloorReloadHandling(ply)
	if not chosenArm then return end

	-- Add pain when using broken arm during floor reload (overall hurt more!)
	if painAmount > 0 then
		org.painadd = (org.painadd or 0) + painAmount
	end

	-- Fear and adrenaline make floor reloads clumsier
	local fearSpeedFactor, fearDropFactor, fumbleChance = GetFearReloadFactors(ply)
	speedMult = speedMult * fearSpeedFactor
	dropChanceMult = dropChanceMult * fearDropFactor

	if clip >= maxclip and not needsCycle and not (isshotgun and not ent.drawBullet) then return end
	local reloadFailed = reloadFailChance > 0 and mRand(0, 1) < reloadFailChance

	if limbs and clip < maxclip or (ammocount > 0 or needsCycle or (isshotgun and clip > 0 and not ent.drawBullet)) then
		if isshotgun and ent.drawBullet and ammocount <= 0 then return end

		local dist = ent:GetPos():DistToSqr(ply:GetPos()) > 6000
		local phys = ent:GetPhysicsObject()

		hg.SetCarryEnt2(ply, ent, 0, phys:GetMass(), vector_origin, ply:GetAimVector() * 10 + ply:GetUp() * -25 + ply:GetShootPos(), ply:EyeAngles())
		ply:EmitSound("physics/body/body_medium_impact_soft"..mRandom(7)..".wav", 55)
		ply:ViewPunch(AngleRand(-2, 2))
		ply:SetNW2Bool("FloorReloading", true) -- отсюда начинается фейлсейф..

		if ent.FakeReloadSounds ~= nil then
			for i, snd in pairs(ent.FakeReloadSounds) do
				if not SafeCheck(ply, ent, dist) then FailSafe(ply) return end

				if isnumber(i) then
					local fumbleDelay = 0
					if math.random() < fumbleChance then
						fumbleDelay = mRand(0.15, 0.45)
						ply:ViewPunch(AngleRand(-1, 1))
					end
					timer.Simple(i * mRand(3.2, 3.6) * ((isshotgun and ammocount <= 0 and not ent.drawBullet) and 0.5 or 1) * speedMult + fumbleDelay, function()
						if not SafeCheck(ply, ent, dist) then FailSafe(ply) return end

						-- Adjusted drop chance based on right arm health
						local dropCheck = mRandom(10 * org.consciousness / dropChanceMult)
						local dropThreshold = (5 * org.consciousness)
						if dropCheck == dropThreshold then
							if IsValid(ply:GetNetVar("carryent2")) then
								local ent2 = ply:GetNetVar("carryent2")
								ply:SetNetVar("carryent2",NULL)
								ply:SetNetVar("carrybone2",nil)
								ply:SetNetVar("carrymass2",0)
								ply:SetNetVar("carrypos2",nil)
								heldents[ent2:EntIndex()] = nil
							end

							ent:EmitSound("physics/metal/weapon_impact_hard"..mRandom(3)..".wav", 65)
							ply:Notify(randomgovno[mRandom(#randomgovno)], 10)
							ply:EmitSound("physics/body/body_medium_impact_soft"..mRandom(7)..".wav", 55)
							ply:ViewPunch(AngleRand(-3, 3))
							FailSafe(ply)

							return
						end

						ent:EmitSound(snd)
						local mul = mClamp(i * 2, 0.2, 1.1)
						ply:ViewPunch(AngleRand(-3 * mul, 3 * mul))
					end)
				end
			end
		end

		local mainFumbleDelay = 0
		if math.random() < fumbleChance then
			mainFumbleDelay = mRand(0.2, 0.6)
			ply:ViewPunch(AngleRand(-1.5, 1.5))
		end
		timer.Create("FloorReload_"..ply:SteamID64(), (ent.ReloadTime + mRand(0.8, 1.8) * ((isshotgun and ammocount <= 0 and not ent.drawBullet) and 0.5 or 1) * speedMult + mainFumbleDelay) or 5, 1, function()
			if not SafeCheck(ply, ent, dist) then FailSafe(ply) return end

			ply:EmitSound("physics/body/body_medium_impact_soft"..mRandom(7)..".wav", 55)
			ply:ViewPunch(AngleRand(-2, 2))
			ply:PickupWeapon(ent)
			ply:SetActiveWeapon(ent)
			if reloadFailed then
				ent:EmitSound("physics/metal/weapon_impact_hard"..mRandom(3)..".wav", 60)
				ply:Notify("You fumble the reload.", 4)
				FailSafe(ply)
				return
			end
			if needsCycle and clip >= maxclip and ammocount > 0 then
				ent.AnimStart_Draw = CurTime()
				if ent.Draw then ent:Draw(true) end
				if ent.Primary then
					ent.Primary.Next = CurTime() + (ent.AnimDraw or 0) + (ent.Primary.Wait or 0)
				end
				net.Start("hgwep draw")
				net.WriteEntity(ent)
				net.WriteBool(ent.drawBullet)
				net.WriteFloat(CurTime())
				net.Broadcast()
				if ent.PlaySnd then
					ent:PlaySnd(ent.CockSound or "weapons/shotgun/shotgun_cock.wav", true, CHAN_AUTO)
				else
					ent:EmitSound(ent.CockSound or "weapons/shotgun/shotgun_cock.wav")
				end
			else
				ent:ReloadEnd()
			end

			FailSafe(ply)
		end)
	end
end)

hook.Add("PlayerDeath", "fixgovno", function(ply)
	FailSafe(ply)
end)
