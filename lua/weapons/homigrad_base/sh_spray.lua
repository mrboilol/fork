AddCSLuaFile()
--
function SWEP:Initialize_Spray()
	self.EyeSpray = Angle(0, 0, 0)
	self.SprayI = 0
	self.dmgStack = 0
	self.dmgStack2 = 0
end

SWEP.SpreadMulZoom = 1.5
SWEP.SpreadMul = 2
SWEP.CrouchMul = 0.75
SWEP.Spray = {}
for i = 1, 150 do
	SWEP.Spray[i] = Angle(-0.02 - math.cos(i) * 0.01, math.cos(i * i) * 0.01, 0)
end

SWEP.SprayRand = {Angle(0, 0, 0), Angle(0, 0, 0)}
SWEP.addSprayMul = 1

SWEP.RecoilMul = 1.0

local cos, sin, math_max, math_min = math.cos, math.sin, math.max, math.min

local function finite_number(n)
	return isnumber(n) and n == n and n > -math.huge and n < math.huge
end

local function finite_angle(ang)
	return isangle(ang) and finite_number(ang[1]) and finite_number(ang[2]) and finite_number(ang[3])
end

local function sanitize_angle(ang)
	if finite_angle(ang) then return ang end
	return Angle(0, 0, 0)
end

local hg_recoilmul = CreateConVar("hg_recoilmul", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Multiply weapon physical recoil")
local hg_spreadmul = ConVarExists("hg_spreadmul") and GetConVar("hg_spreadmul") or CreateConVar("hg_spreadmul", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Multiply weapon shot spread")
function SWEP:GetPrimaryMul()
	local owner = self:GetOwner()
	local caliberMul, weightMul = self:GetRecoilImpulseFactors()
	local supportMul = self:GetRecoilSupportMul()
	local mul = math.Clamp(caliberMul * weightMul * 0.68, 0.18, 2.7) * supportMul * (owner.Crouching and owner:Crouching() and self.CrouchMul or 1) * (self.attachments and self.attachments.barrel and self.attachments.barrel[1] ~= "empty" and 0.75 or 1)
	self:ApplyForce(mul)
	mul = ((mul or 0) * (self.Supressor and 0.75 or 1) * (owner.organism and owner.organism.recoilmul or 1)) * hg_recoilmul:GetFloat() * self:GetFearRecoilMul() * self:GetCognitiveHandlingMul()
	return mul
end

SWEP.sprayAngles = Angle(0,0,0)

SWEP.weaponSway = Angle(0,0,0)

local hg_coolcamera = ConVarExists("hg_coolcamera") and GetConVar("hg_coolcamera") or CreateConVar("hg_coolcamera", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Cool camera movement", 0, 1)

local function IsSlugcatRecoilImmune(ply, wep)
	local className = IsValid(ply) and string.lower(ply.PlayerClassName or "") or ""
	return className == "slugcat" or (IsValid(wep) and wep:GetClass() == "weapon_slugcat")
end

local function DropWrenchedWeapon(ply, wep)
	if not SERVER or not IsValid(ply) or not IsValid(wep) then return end
	ply:DropWeapon(wep)
	if ply:HasWeapon("weapon_hands_sh") then
		ply:SelectWeapon("weapon_hands_sh")
	end
end

function SWEP:PrimarySpread()
	self.Primary.Force2 = (hg.ammotypeshuy[self.Primary.Ammo] and hg.ammotypeshuy[self.Primary.Ammo].BulletSettings and hg.ammotypeshuy[self.Primary.Ammo].BulletSettings.Force) or self.Primary.Force
	self:SetLastShootTime(CurTime())
	self.lastShoot = RealTime()--SysTime()
	
	local owner = self:GetOwner()

	if not IsValid(owner) then return end

	local mul = self:GetPrimaryMul()
	self.SprayI = self.SprayI + 1
	self.dmgStack = self.dmgStack + self.Primary.Damage
	self.dmgStack2 = math.min(self.dmgStack2 + 0.2, 60)
	local sprayI = self.SprayI
	
	if SERVER then
		if owner:IsNPC() then return end
		local org = owner.organism
		if org then
			if IsSlugcatRecoilImmune(owner, self) then return end

			local _, _, recoilForce, numB = self:GetRecoilImpulseFactors()
			local force = self.Primary.Force2 or self.Primary.Force or 30
			local calForce = recoilForce
			local support = self.GetHandSupportState and self:GetHandSupportState(owner) or {}

			local rarm_broken = (org.rarm and org.rarm >= 1) and not org.rarmamputated
			local larm_broken = (org.larm and org.larm >= 1) and not org.larmamputated
			local rarm_dislocated = org.rarmdislocated or org.rarmdislocation
			local larm_dislocated = org.larmdislocated or org.larmdislocation
			local firingArm = support.firingArm or (support.onlyLeft and "larm" or "rarm")
			local firingBroken = firingArm == "larm" and larm_broken or rarm_broken
			local firingDislocated = firingArm == "larm" and larm_dislocated or rarm_dislocated
			local firingAmputated = firingArm == "larm" and org.larmamputated or org.rarmamputated
			local oneHanded = support.oneHanded or support.leftBusy or support.rightBusy

			-- Pain from shooting based on hand dominance - only if arm is actually broken
			local dominance = org.hand_dominance or "right"
			local pain_mult = 0

			if dominance == "right" then
				-- Right hand dominant: only hurt if right arm is broken (>=1) or dislocated
				if rarm_broken then
					pain_mult = org.rarm * 5 -- Increased from 2 to 5
				elseif rarm_dislocated then
					pain_mult = 5 -- Increased from 2 to 5
				end
				-- If right arm amputated, no pain (using left arm instead)
			else
				-- Left hand dominant: only hurt if left arm is broken (>=1) or dislocated
				if larm_broken then
					pain_mult = org.larm * 2
				elseif larm_dislocated then
					pain_mult = 2
				end
				-- If left arm amputated, no pain (using right arm instead)
			end

			org.painadd = org.painadd + pain_mult * force / 20 * numB
			if oneHanded then
				local oneHandPain = math.max(0, calForce - 24) * (support.onlyLeft and 0.16 or 0.1)
				if firingBroken or firingDislocated then oneHandPain = oneHandPain + calForce * 0.28 end
				org.painadd = org.painadd + oneHandPain

				if not firingAmputated and calForce >= 34 then
					local wristChance = math.Clamp((calForce - 28) / 150, 0.025, 0.42)
					if support.wantsTwoHands then wristChance = wristChance * 1.35 end
					if support.onlyLeft then wristChance = wristChance * 1.25 end
					if firingBroken or firingDislocated then wristChance = wristChance * 1.8 end
					if self:GetClass() == "weapon_ptrd" or self.Base == "weapon_ptrd" then wristChance = wristChance * 1.45 end
					wristChance = math.Clamp(wristChance, 0.015, 0.65)

					if math.random() < wristChance then
						org[firingArm] = math.max(org[firingArm] or 0, 1)
						org[firingArm .. "dislocation"] = true
						org.painadd = org.painadd + 35 + calForce * 0.45
						owner:EmitSound("newbonebreak/break"..math.random(10)..".wav", 75, math.random(105, 125), 1, CHAN_AUTO)
						if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
							hg.BreakLimb(owner, firingArm, nil, true)
						end
						DropWrenchedWeapon(owner, self)
						owner:Notify("The recoil broke your " .. (firingArm == "larm" and "left" or "right") .. " wrist.", 1, firingArm .. "_onehand_recoil", 1, nil, nil)
					end
				end
			end

			-- Right arm broken shooting checks
			if rarm_broken then
				local extra_broken_pain = calForce * 3.0 -- Increased from 1.5 to 3.0
				if larm_broken then
					extra_broken_pain = extra_broken_pain * 1.5
				end
				org.painadd = org.painadd + extra_broken_pain

				if not rarm_dislocated then
					-- small chance to dislocate
					local disl_chance = math.Clamp((calForce - 18) / 360, 0.04, 0.38)
					if larm_broken then
						disl_chance = disl_chance * 2
					end
					if self:GetClass() == "weapon_ptrd" or self.Base == "weapon_ptrd" then disl_chance = disl_chance * 1.35 end
					disl_chance = math.Clamp(disl_chance, 0.04, 0.7)
					if math.random() < disl_chance then
						org.rarmdislocation = true
						org.painadd = org.painadd + 35
						owner:EmitSound("newbonebreak/break"..math.random(10)..".wav", 75, math.random(110, 130), 1, CHAN_AUTO)
						if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
							hg.BreakLimb(owner, "rarm", nil, true)
						end
						owner:Notify("Your broken right arm dislocated from shooting!", 1, "rarm_broken_dislocate", 1, nil, nil)
					end
				else
					-- already dislocated: add a bunch of pain and a bone breaking sound
					local extra_disl_pain = 50 + calForce * 3.0 -- Increased from 35 + 1.5 to 50 + 3.0
					if larm_broken then
						extra_disl_pain = extra_disl_pain * 1.5
					end
					org.painadd = org.painadd + extra_disl_pain
					owner:EmitSound("newbonebreak/break"..math.random(10)..".wav", 75, math.random(110, 130), 1, CHAN_AUTO)

					-- High caliber weapons can break the arm again when already dislocated
					if calForce >= 50 and not org.rarmamputated then
						local break_again_chance = math.Clamp((calForce - 45) / 520, 0.03, 0.42)
						if self:GetClass() == "weapon_ptrd" or self.Base == "weapon_ptrd" then break_again_chance = break_again_chance * 1.35 end
						break_again_chance = math.Clamp(break_again_chance, 0.03, 0.55)
						if math.random() < break_again_chance then
							org.painadd = org.painadd + 80
							owner:EmitSound("newbonebreak/break"..math.random(10)..".wav", 75, math.random(110, 130), 1, CHAN_AUTO)
							-- Permanent aiming impairment
							org.permanent_aim_impairment = (org.permanent_aim_impairment or 0) + 0.15
							DropWrenchedWeapon(owner, self)
							owner:Notify("Your right arm shattered again - your aim will never be the same!", 1, "rarm_shattered", 1, nil, nil)
						end
					end
				end
			end

			-- Right arm dislocated shooting checks (not broken yet)
			if rarm_dislocated and not rarm_broken then
				-- High caliber weapons can break a dislocated arm
				if calForce >= 50 and not org.rarmamputated then
					local break_chance = math.Clamp((calForce - 45) / 360, 0.04, 0.5)
					if self:GetClass() == "weapon_ptrd" or self.Base == "weapon_ptrd" then break_chance = break_chance * 1.35 end
					break_chance = math.Clamp(break_chance, 0.04, 0.65)
					if math.random() < break_chance then
						org.rarm = 1
						org.painadd = org.painadd + 65
						owner:EmitSound("newbonebreak/break"..math.random(10)..".wav", 75, math.random(110, 130), 1, CHAN_AUTO)
						if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
							hg.BreakLimb(owner, "rarm", nil, false)
						end
						DropWrenchedWeapon(owner, self)
						owner:Notify("Your dislocated right arm snapped from the recoil!", 1, "rarm_dislocated_snap", 1, nil, nil)
					end
				end
			end
			-- Base shooting pain only applies when firing with a damaged firing arm.
			-- Right arm broken/dislocated, or (right arm missing AND left arm broken/dislocated).
			local rarm_amputated = org.rarmamputated
			local shouldShootPain = (rarm_broken or rarm_dislocated) or
				(rarm_amputated and (larm_broken or larm_dislocated))

			if shouldShootPain then
				local baseShootPain = math.max(17.5, calForce * 0.35)
				org.painadd = org.painadd + baseShootPain
			end
		end
	end

	if CLIENT and (owner == LocalPlayer() or (not LocalPlayer():Alive() and owner == LocalPlayer():GetNWEntity("spect"))) and !self.norecoil then
		local organism = owner.organism or {}
		local caliberMul, weightMul, ammoForce, numBullet = self:GetRecoilImpulseFactors()

		local support = self.GetHandSupportState and self:GetHandSupportState(owner) or {}
		local oneHandRecoilMul = 1
		if support.oneHanded then oneHandRecoilMul = oneHandRecoilMul * (support.onlyLeft and 1.85 or 1.45) end
		if support.leftBusy then oneHandRecoilMul = oneHandRecoilMul * 1.35 end
		if support.rightBusy then oneHandRecoilMul = oneHandRecoilMul * 1.55 end
		if support.wantsTwoHands and support.supportHands <= 1 then oneHandRecoilMul = oneHandRecoilMul * 1.25 end

		local recoilProgress = 0.55 + math.Clamp((sprayI - 1) / 10, 0, 1) * 0.45
		local force = math.Clamp(caliberMul * weightMul * 0.38, 0.1, 2.45) * oneHandRecoilMul * self.addSprayMul * recoilProgress

		-- Sway/debuff based on hand dominance and bone damage (using existing multiplier system)
		local dominance = organism.hand_dominance or "right"
		local arm_debuff = 0
		local amputate_debuff = 0

		if dominance == "right" then
			-- Right hand dominant: right arm damage affects more
			arm_debuff = (organism.rarm or 0) * 2 + (organism.larm or 0) * 0.5
			amputate_debuff = (organism.rarmamputated and 3 or 0) + (organism.larmamputated and 1 or 0)
			arm_debuff = arm_debuff + ((organism.rarmdislocation or organism.rarmdislocated) and 0.5 or 0) + ((organism.larmdislocation or organism.larmdislocated) and 0.2 or 0)
		else
			-- Left hand dominant: left arm damage affects more
			arm_debuff = (organism.larm or 0) * 2 + (organism.rarm or 0) * 0.5
			amputate_debuff = (organism.larmamputated and 3 or 0) + (organism.rarmamputated and 1 or 0)
			arm_debuff = arm_debuff + ((organism.larmdislocation or organism.larmdislocated) and 0.5 or 0) + ((organism.rarmdislocation or organism.rarmdislocated) and 0.2 or 0)
		end

		-- Apply aiming fatigue penalty
		arm_debuff = arm_debuff + (organism.aiming_fatigue or 0) * 0.15

		-- Apply permanent aiming impairment
		arm_debuff = arm_debuff + (organism.permanent_aim_impairment or 0) * 3

		-- Explicit broken arm recoil penalty (beyond proportional damage)
		-- Debuff variables include amputated arms for recoil penalties
		local rarm_broken_debuff = (organism.rarm and organism.rarm >= 1) or organism.rarmamputated
		local larm_broken_debuff = (organism.larm and organism.larm >= 1) or organism.larmamputated
		local broken_arm_recoil_mult = 1
		if rarm_broken_debuff then
			local multiplier = organism.rarmamputated and 2.0 or 1.5
			broken_arm_recoil_mult = broken_arm_recoil_mult * multiplier
		end
		if larm_broken_debuff then
			local multiplier = organism.larmamputated and 2.0 or 1.35
			broken_arm_recoil_mult = broken_arm_recoil_mult * multiplier
		end

		-- Mitigation calculation for overall control / handling
		local plyVel = owner:GetVelocity()
		local isStandingStill = isvector(plyVel) and plyVel:LengthSqr() < 100
		local isCrouching = owner:Crouching()
		local isRagdolled = IsValid(owner.FakeRagdoll)
		local isHoldingBreath = organism.holdingbreath

		local mitigation_mult = 1
		if isRagdolled then
			mitigation_mult = mitigation_mult * 0.85
		elseif isCrouching then
			mitigation_mult = mitigation_mult * 0.90
		elseif isStandingStill then
			mitigation_mult = mitigation_mult * 0.95
		end

		if isHoldingBreath then
			mitigation_mult = mitigation_mult - 0.05
		end

		-- Broken arms bypass this mitigation
		local bypass_mitigation = (organism.rarm and organism.rarm >= 1) or (organism.larm and organism.larm >= 1) or organism.rarmamputated or organism.larmamputated
		if bypass_mitigation then
			mitigation_mult = 1
		end

		if not bypass_mitigation then
			arm_debuff = arm_debuff * mitigation_mult
			amputate_debuff = amputate_debuff * mitigation_mult
		end

		-- Apply tourniquet handling penalty
		local tourniquet_debuff = 0
		if hg.HasTourniquetOnLimb and hg.HasTourniquetOnLimb(owner, "larm") then
			tourniquet_debuff = tourniquet_debuff + 0.3
		end
		if hg.HasTourniquetOnLimb and hg.HasTourniquetOnLimb(owner, "rarm") then
			tourniquet_debuff = tourniquet_debuff + 0.45
		end
		arm_debuff = arm_debuff + tourniquet_debuff

		local armHandlingMul = self.GetArmHealthHandlingMul and self:GetArmHealthHandlingMul() or 1
		mul = mul * math.Clamp(0.72 + arm_debuff * 0.14 + amputate_debuff * 0.16, 0.72, 1.65)
		mul = mul * math.Clamp(broken_arm_recoil_mult, 1, 1.9)
		mul = mul * oneHandRecoilMul
		mul = mul * armHandlingMul
		mul = mul * ((owner.posture == 7 or owner.posture == 8 or owner.holdingWeapon) and 2 or 1)
		mul = mul * self.RecoilMul
		mul = mul * (owner:Crouching() and 0.75 or 1)
		--mul = mul * (hg.IsOnGround(hg.GetCurrentCharacter(owner)) and 1 or 5)
		mul = mul * (self:IsResting() and 0.1 or 1)

		-- Baseline shot dispersion is pitch-dominant. Horizontal movement is still
		-- present, but cannot overpower vertical climb on light pistols.
		local angRand = Angle(-math.Rand(0.035, 0.06), math.Rand(-0.016, 0.016), 0)
		local spray

		if sprayI < 3 then
			spray = angRand
		else
			spray = self.Spray[sprayI] or Angle(0.01, 0)
		end
		
		local angranda = AngleRand(self.SprayRand[1], self.SprayRand[2])
		angranda[3] = 0
		spray = (spray + angranda * self.addSprayMul * mul * (self.randmul or 1)) * hg_spreadmul:GetFloat()

		local angrand2 = AngleRand(-force, force)
		if not self.SprayRandOnly then
			local pitchMag = math.Clamp(math.abs(angrand2[1]), force * 0.62, 10)
			local yawLimit = math.min(0.28, pitchMag * 0.26 + 0.04)
			angrand2[1] = -pitchMag
			angrand2[2] = math.Clamp(angrand2[2] * 0.45, -yawLimit, yawLimit)
			angrand2[3] = -angrand2[2] * 0.35
			local mulhuy = GetGlobalBool("FullRealismMode",false) and 10 or 1
			mul = mul * (self.attachments and self.attachments.grip and not table.IsEmpty(self.attachments.grip) and hg.attachments.grip[self.attachments.grip[1]].recoilReduction or 1)
			
			local huyang = angrand2 * mul / 2 * mulhuy
			huyang[3] = 0
			ViewPunch2(huyang * (owner.posture == 1 and not self:IsZoom() and 2 or 1) * 0.14)-- ^ ((not self.Primary.Automatic and 0.5 or 1)))
			
			local angpopa = angrand2 * mul
			angpopa[3] = 0
			ViewPunch(angpopa * (hg_coolcamera:GetBool() and 1.25 or 0.55))-- ^ ((not self.Primary.Automatic and 0.5 or 1)))
			spray = spray + angRand * 2 * (self.randmul or 1)
		end
		local angrand3 = Angle(angrand2[1], math.Clamp(angrand2[2] * 0.65, -math.abs(angrand2[1]) * 0.18 - 0.08, math.abs(angrand2[1]) * 0.18 + 0.08), 0)

		local prank3 = math.Rand(-ammoForce, ammoForce) / (ammoForce != 0 and ammoForce or 1) * 2
		local angleprikol = Angle(0,0,prank3)

		//ViewPunch2(angleprikol)

		local mul = mul * caliberMul * weightMul * 0.38 * (self:IsPistolHoldType() and 1.25 or 1) * (numBullet and math.sqrt(numBullet) or 1)
		ViewPunch2(Angle(-math.Rand(1.25,2.2), math.Rand(-0.45,0.45), 0) * mul * 0.18)
		ViewPunch(Angle(-math.Rand(1,2), math.Rand(-0.45,0.45), 0) * mul / -8)
		timer.Simple(0.01, function() if IsValid(owner) then ViewPunch2(Angle(-math.Rand(1,2), math.Rand(-0.45,0.45), 0) * mul * 0.12) end end)
		timer.Simple(0.02, function() if IsValid(owner) then ViewPunch2(Angle(1 * math.Rand(1,2.4),0,0) * mul * 0.1) end end)

		local eyeang = owner:EyeAngles()
		if not finite_angle(eyeang) then return end
		local sprayAng = (spray * (self:IsResting() and 0.1 or 1) * 6.5 + angrand3 * self.addSprayMul) * (eyeang.z == 180 and -1 or 1)
		sprayAng[2] = math.Clamp(sprayAng[2], -math.abs(sprayAng[1]) * 0.22 - 0.12, math.abs(sprayAng[1]) * 0.22 + 0.12)
		sprayAng[3] = 0

		sprayAng:RotateAroundAxis(angle_zero:Forward(), eyeang.roll)
		sprayAng.roll = 0

		local muzzleKick = sprayAng * (organism.recoilmul or 1) * armHandlingMul * oneHandRecoilMul * (owner.posture == 1 and not self:IsZoom() and 0.32 or 1) * 0.6
		muzzleKick[1] = math.Clamp(muzzleKick[1] * 1.35, -6.0, 2.4)
		local muzzleYawCap = math.min(0.65, math.abs(muzzleKick[1]) * 0.18 + 0.08)
		muzzleKick[2] = math.Clamp(muzzleKick[2] * 0.32, -muzzleYawCap, muzzleYawCap)
		muzzleKick[3] = 0
		muzzleKick = sanitize_angle(muzzleKick)
		local newEyeAng = eyeang + muzzleKick
		if finite_angle(newEyeAng) then
			owner:SetEyeAngles(newEyeAng)
		end
		
		local rnd1, rnd2 = math.Rand(1,2), math.Rand(-1,1)
		ViewPunch2(Angle(2 * rnd1, rnd2 * 1.1, 0) * mul * 0.12)
		ViewPunch(Angle(-2 * rnd1, -rnd2 * 1.1, 0) * mul * 0.22)

		local max_clip1 = self:GetMaxClip1()
		
		if(max_clip1 == 0)then
			max_clip1 = 1
		end
		
		local sprayvel = spray * mul * math.max(sprayI / max_clip1, 0.5) * self.addSprayMul * (self.cameraShakeMul or 1) * 5.6//(self.Primary.Automatic and 1 or 1)
		
		--self.weaponSway = self.weaponSway + sprayvel

		self.sprayAngles[3] = self.sprayAngles[3] + math.max(self.Primary.Damage / 100,1) * oneHandRecoilMul * self.addSprayMul * (self.cameraShakeMul or 1) * ((((self.NumBullet or 1) - 1) / 2) + 1) * (((self.podkid or 1) - 1) / 3 + 1) / 34

		self:ApplyEyeSprayVel(sprayvel * 0.9)
		--self:AnimApply_RecoilCameraZoom()
	end
end

function SWEP:ApplyForce(mul)
	//mul = mul * self.Primary.Damage / 60 * (self.NumBullet or 1)
	local ply = self:GetOwner()

	if IsValid(ply.FakeRagdoll) then
		if SERVER then
			local ent = ply.FakeRagdoll
			local phys = ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_R_Hand")))
			local tr, pos, ang = self:GetTrace(nil, nil, nil, true)
			local dir = ang:Forward()
			phys:ApplyForceCenter(-dir * self.Primary.Force * 5)
		end

		return true
	end
end

--if CLIENT then
local angZero = Angle(0, 0, 0)
function SWEP:ApplyEyeSprayVel(value)
	self.EyeSprayVel = self.EyeSprayVel + value * 0.2
	self:ApplyEyeSpray(self.EyeSprayVel)
	--self.AdditionalAng = self.AdditionalAng + Angle(-math.Rand(self.EyeSprayVel[1] * 1 ,self.EyeSprayVel[1] * 2),math.Rand(self.EyeSprayVel[2] * 2 ,self.EyeSprayVel[2] * 5),-self.EyeSprayVel[2] * 10)
	--self.AdditionalPos[1] = self.AdditionalPos[1] + self.EyeSprayVel[1] * 15
end

function SWEP:Step_SprayVel(dtime)
	self.EyeSprayVel = self.EyeSprayVel or Angle(0, 0, 0)
	self.EyeSprayVel = self.EyeSprayVel - self.EyeSprayVel * hg.lerpFrameTime2(0.95,dtime)--self.EyeSpray * 0.04
	self:ApplyEyeSpray(self.EyeSprayVel)
end

function SWEP:ApplyEyeSpray(value)
	if CLIENT and self:GetOwner() ~= LocalPlayer() then return end
	if not finite_angle(value) then return end
	self.EyeSpray = sanitize_angle(self.EyeSpray)
	local tickInterval = engine.TickInterval()
	if not finite_number(tickInterval) or tickInterval <= 0 then return end
	local nextSpray = self.EyeSpray + value * 0.2 * (FrameTime() / tickInterval)
	self.EyeSpray = sanitize_angle(nextSpray)
end

function SWEP:Step_Spray(time,dtime)
	if self.Primary.Next + 0.3 < time then self.SprayI = 0 end
	
	if SERVER then return end

	local eyeSpray = self.EyeSpray
	local owner = self:GetOwner()
	local eyeang = owner:EyeAngles()
	if not finite_angle(eyeang) then return end

	local nextEyeAng = eyeang + (sanitize_angle(eyeSpray) * (eyeang.z == 180 and -1 or 1))
	if finite_angle(nextEyeAng) then
		owner:SetEyeAngles(nextEyeAng)
	end
	local nextSpray = LerpAngle(hg.lerpFrameTime2(0.1,dtime), eyeSpray, angZero)
	eyeSpray:Set(sanitize_angle(nextSpray))
end

--[[else
	function SWEP:ApplyEyeSpray(value) end
	function SWEP:ApplyEyeSprayVel(value) end
end--]]
SWEP.ZoomFOV = 20
function SWEP:AdjustMouseSensitivity()
	--return self:IsZoom() and self:HasAttachment("sight") and (math.min(self.ZoomFOV / 10, 0.5) or 0.5) or 1
end
