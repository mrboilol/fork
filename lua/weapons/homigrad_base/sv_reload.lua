--
local CurTime = CurTime
util.AddNetworkString("hgwep reload")

SWEP.ArmReloadPenalty = {
    PainOnReload = 35, -- pain when reloading with broken left arm (increased from 12)
    MissingRightArmSpeedMul = 0.4, -- 60% slower when right arm is missing
    MissingRightArmPain = 55, -- pain when right arm missing + left arm broken (increased from 20)
    LeftArmBrokenReloadSlow = 1.5, -- extra multiplier when left arm is broken
    BrokenArmPickupPain = 20 -- pain when using broken arm to pick up items
}

function SWEP:CanRackWithOneHand()
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply.organism then return true end
    local org = ply.organism

    -- Can't rack one-handed if left arm is missing
    if org.larmamputated then return false end

    return true
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

	-- Check if left arm is broken (but not amputated) - allow reload but add pain
	local ply = self:GetOwner()
	local org = ply.organism
	local leftArmBroken = org and ((org.larm and org.larm >= 1) or org.larmdislocation) and not org.larmamputated

	-- Bypass ConsLH check if left arm is broken (but not amputated), add pain instead
	if IsValid(ply.FakeRagdoll) and ply.FakeRagdoll.ConsLH then
		if leftArmBroken then
			-- Add pain for using broken left arm to reload
			local painAmount = (org.larm or 0) * 15 + (org.larmdislocation and 10 or 0)
			org.painadd = (org.painadd or 0) + painAmount
		else
			return
		end
	end

	if not self:CanUse() or not self:CanReload() then self:OnCantReload() return end

	-- Check for left arm missing - can't rack one-handed bolt actions
	if ply.organism and ply.organism.larmamputated then
		-- If weapon needs racking (drawBullet == false), force floor reload
		if self.drawBullet == false then
			if SERVER then
				ply:Notify("I can't cycle it with one hand.", 1)
			end
			self:OnCantReload()
			return
		end
	end

	self.LastReload = CurTime()
	self:ReloadStart()
	self:ReloadStartPost()
	local org = self:GetOwner().organism

	-- Get arm-related penalties
	local armPain, armSpeedMul = self:GetReloadArmPenalty()

	self.StaminaReloadMul = (org and ((2 - (self:GetOwner().organism.stamina[1] / 180)) + ((org.pain / 40) + (org.larm / 3) + (org.rarm / 5)) - (1 - math.Clamp(org.recoilmul or 1,0.45,1.4))) or 1)
    if org and org.fear and org.fear > 0 then
        self.StaminaReloadMul = self.StaminaReloadMul * (1 + org.fear * 0.05) -- 5% longer reload per fear point
    end
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

concommand.Add("hg_reloadfloorweapon", function(ply, cmd, args)
	if not IsValid(ply) and not ply:Alive() then return end
	local org = ply.organism
	if org.rarmamputated and org.larmamputated then return end

	local ent = (IsValid(hg.eyeTrace(ply).Entity) and hg.eyeTrace(ply).Entity) or (IsValid(ply:GetNetVar("carryent")) and ply:GetNetVar("carryent"))
	if not IsValid(ent) or not ishgweapon(ent) or ent:GetPos():DistToSqr(ply:GetPos()) > 6000 then return end

	local isshotgun = (ent.Base == "weapon_m4super" or ent:GetClass() == "weapon_m4super")
	local limbs = org.rarmamputated or org.larmamputated
	local clip, maxclip, ammocount = ent:Clip1(), ent:GetMaxClip1(), ply:GetAmmoCount(ent.Primary.Ammo)

	-- Calculate prioritized arm and penalties for floor reload
	local chosenArm, isRight, isBroken = hg.GetPrioritizedArm(ply)

	-- Add pain when using broken arm during floor reload (overall hurt more!)
	if isBroken then
		local armVal = isRight and (org.rarm or 0) or (org.larm or 0)
		local disloc = isRight and org.rarmdislocation or org.larmdislocation
		local painAmount = 25 * armVal + (disloc and 15 or 0)

		-- Using right arm makes things better overall (reduce pain from a broken arm)
		if isRight then
			painAmount = painAmount * 0.7
		end
		org.painadd = (org.painadd or 0) + painAmount
	end

	-- Speed multiplier: faster when chosen arm is healthy.
	-- If using right arm, things are even better overall!
	local speedMult = 1.0
	if not isBroken then
		speedMult = isRight and 0.5 or 0.8 -- Right arm healthy is super fast (0.5), Left arm healthy is fast (0.8)
	else
		speedMult = isRight and 1.1 or 1.6 -- Right arm broken is slightly slower (1.1), Left arm broken is much slower (1.6)
	end

	-- Drop chance: lower when chosen arm is healthy.
	-- If using right arm, things are even better overall!
	local dropChanceMult = 1.0
	if not isBroken then
		dropChanceMult = isRight and 0.4 or 0.7 -- Right arm healthy has 60% less drop chance, Left arm healthy has 30% less
	else
		dropChanceMult = isRight and 1.0 or 1.5 -- Right arm broken is normal drop chance, Left arm broken is 1.5x drop chance
	end

	if clip >= maxclip then return end

	if limbs and clip < maxclip or (ammocount > 0 or (isshotgun and clip > 0 and not ent.drawBullet)) then
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
					timer.Simple(i * mRand(3.2, 3.6) * ((isshotgun and ammocount <= 0 and not ent.drawBullet) and 0.5 or 1) * speedMult, function()
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

		timer.Create("FloorReload_"..ply:SteamID64(), (ent.ReloadTime + mRand(0.8, 1.8) * ((isshotgun and ammocount <= 0 and not ent.drawBullet) and 0.5 or 1) * speedMult) or 5, 1, function()
			if not SafeCheck(ply, ent, dist) then FailSafe(ply) return end

			ply:EmitSound("physics/body/body_medium_impact_soft"..mRandom(7)..".wav", 55)
			ply:ViewPunch(AngleRand(-2, 2))
			ply:PickupWeapon(ent)
			ply:SetActiveWeapon(ent)
			ent:ReloadEnd()

			FailSafe(ply)
		end)
	end
end)

hook.Add("PlayerDeath", "fixgovno", function(ply)
	FailSafe(ply)
end)