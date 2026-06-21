AddCSLuaFile()

local function SharedRand(seed, min, max)
    return util.SharedRandom(seed, min, max)
end

local function SharedAngleRand(seed, min, max)
    local a = Angle()
    a[1] = util.SharedRandom(seed .. "p", min, max)
    a[2] = util.SharedRandom(seed .. "y", min, max)
    a[3] = util.SharedRandom(seed .. "r", min, max)
    return a
end

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
function SWEP:GetPrimaryMul()
	local owner = self:GetOwner()
	local mul = ((0.5) + math_max(self.Primary.Force / 110 - 1, 0)) * (owner.Crouching and owner:Crouching() and self.CrouchMul or 1) * (self.attachments and self.attachments.barrel and self.attachments.barrel[1] ~= "empty" and 0.75 or 1)
	self:ApplyForce(mul)
	mul = (mul or 0) * (self.Supressor and 0.75 or 1) * (owner.organism and owner.organism.recoilmul or 1) * self:GetFearRecoilMul() * self:GetCognitiveHandlingMul() * self:GetWeaponWeightHandlingMul()
	return mul
end

SWEP.sprayAngles = Angle(0,0,0)

SWEP.weaponSway = Angle(0,0,0)

local hg_coolcamera = ConVarExists("hg_coolcamera") and GetConVar("hg_coolcamera") or CreateConVar("hg_coolcamera", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Cool camera movement", 0, 1)

function SWEP:ComputePrimaryRecoil(mul, recoilForce, sprayI)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	if not owner:IsPlayer() then return end

	local organism = owner.organism or {}

	local dominance = organism.hand_dominance or "right"
	local arm_debuff = 0
	local amputate_debuff = 0

	if dominance == "right" then
		arm_debuff = (organism.rarm or 0) * 2 + (organism.larm or 0) * 0.5
		amputate_debuff = (organism.rarmamputated and 3 or 0) + (organism.larmamputated and 1 or 0)
		arm_debuff = arm_debuff + ((organism.rarmdislocation or organism.rarmdislocated) and 0.5 or 0) + ((organism.larmdislocation or organism.larmdislocated) and 0.2 or 0)
	else
		arm_debuff = (organism.larm or 0) * 2 + (organism.rarm or 0) * 0.5
		amputate_debuff = (organism.larmamputated and 3 or 0) + (organism.rarmamputated and 1 or 0)
		arm_debuff = arm_debuff + ((organism.larmdislocation or organism.larmdislocated) and 0.5 or 0) + ((organism.rarmdislocation or organism.rarmdislocated) and 0.2 or 0)
	end

	arm_debuff = arm_debuff + (organism.aiming_fatigue or 0) * 0.15
	arm_debuff = arm_debuff + (organism.permanent_aim_impairment or 0) * 3

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

	local bypass_mitigation = (organism.rarm and organism.rarm >= 1) or (organism.larm and organism.larm >= 1) or organism.rarmamputated or organism.larmamputated
	if bypass_mitigation then
		mitigation_mult = 1
	end

	if not bypass_mitigation then
		arm_debuff = arm_debuff * mitigation_mult
		amputate_debuff = amputate_debuff * mitigation_mult
	end

	local tourniquet_debuff = 0
	if hg.HasTourniquetOnLimb and hg.HasTourniquetOnLimb(owner, "larm") then
		tourniquet_debuff = tourniquet_debuff + 0.3
	end
	if hg.HasTourniquetOnLimb and hg.HasTourniquetOnLimb(owner, "rarm") then
		tourniquet_debuff = tourniquet_debuff + 0.45
	end
	arm_debuff = arm_debuff + tourniquet_debuff

	mul = mul * ((2.5 + arm_debuff) / 1 + amputate_debuff)
	mul = mul * broken_arm_recoil_mult
	mul = mul * ((owner.posture == 7 or owner.posture == 8 or owner.holdingWeapon) and 2 or 1)
	mul = mul * self.RecoilMul
	mul = mul * (owner:Crouching() and 0.75 or 1)
	mul = mul * (self:IsResting() and 0.1 or 1)

	local seed = "hg_recoil_" .. self:EntIndex() .. "_" .. sprayI

	local angRand = SharedAngleRand(seed .. "_angRand", 0.03, 0.05)
	angRand[1] = -math.abs(angRand[1])
	angRand[2] = (SharedRand(seed .. "_ySign", 0, 1) >= 0.5 and 1 or -1) * angRand[2]
	angRand[3] = 0

	local spray
	if sprayI < 3 then
		spray = angRand
	else
		spray = self.Spray[sprayI] or Angle(0.01, 0)
	end

	local angranda = SharedAngleRand(seed .. "_angranda", self.SprayRand[1], self.SprayRand[2])
	angranda[3] = 0
	spray = spray + angranda * self.addSprayMul * mul * (self.randmul or 1)

	local angrand2 = SharedAngleRand(seed .. "_angrand2", -recoilForce, recoilForce)
	local angrand3 = -(-angrand2)
	angrand3[3] = 0

	local huyang, angpopa
	if not self.SprayRandOnly then
		angrand2[1] = math.Clamp(-math.abs(angrand2[1]), -10, -recoilForce/1.5)
		angrand2[2] = math.Clamp(angrand2[2], -1, 1)
		angrand2[3] = -angrand2[2] * 1
		local mulhuy = GetGlobalBool("FullRealismMode", false) and 10 or 1
		mul = mul * (self.attachments and self.attachments.grip and not table.IsEmpty(self.attachments.grip) and hg.attachments.grip[self.attachments.grip[1]].recoilReduction or 1)

		huyang = angrand2 * mul / 2 * mulhuy
		huyang[3] = 0

		angpopa = angrand2 * mul
		angpopa[3] = 0

		spray = spray + angRand * 2 * (self.randmul or 1)
	end

	local prank3 = SharedRand(seed .. "_prank3", -self.Primary.Force2, self.Primary.Force2) / (self.Primary.Force2 != 0 and self.Primary.Force2 or 1) * 2

	local viewMul = mul * self.Primary.Force2 / 100 * (self:IsPistolHoldType() and 2 or 1) * (self.NumBullet and self.NumBullet * 3 or 1)

	local eyeang = owner:EyeAngles()
	local sprayAng = (spray * (self:IsResting() and 0.1 or 1) * 8 + angrand3 * self.addSprayMul) * (eyeang.z == 180 and -1 or 1)
	sprayAng[3] = 0

	sprayAng:RotateAroundAxis(angle_zero:Forward(), eyeang.roll)
	sprayAng.roll = 0

	local eyeKick = sprayAng * 3 * (organism.recoilmul or 1) * (owner.posture == 1 and not self:IsZoom() and 0.1 or 1) * 1.0 * self:GetFearRecoilMul()
	owner:SetEyeAngles(eyeang + eyeKick)

	local rnd1 = SharedRand(seed .. "_rnd1", 1, 2)
	local rnd2 = SharedRand(seed .. "_rnd2", -1, 1)

	local max_clip1 = self:GetMaxClip1()
	if max_clip1 == 0 then max_clip1 = 1 end

	local sprayvel = spray * mul * math.max(sprayI / max_clip1, 0.5) * self.addSprayMul * (self.cameraShakeMul or 1) * 10 * 1.2

	self.sprayAngles[3] = self.sprayAngles[3] + math.max((self.Primary.Damage or 1) / 100, 1) * self.addSprayMul * (self.cameraShakeMul or 1) * ((((self.NumBullet or 1) - 1) / 2) + 1) * (((self.podkid or 1) - 1) / 3 + 1) / 40

	self:ApplyEyeSprayVel(sprayvel * 1)

	local viewPunchAngle = Angle()
	if huyang then
		viewPunchAngle:Add(huyang * (owner.posture == 1 and not self:IsZoom() and 3 or 1) * 0.25)
	end
	if angpopa then
		viewPunchAngle:Add(angpopa * (hg_coolcamera:GetBool() and 3 or 1))
	end
	viewPunchAngle:Add(Angle(-1.5 * rnd1, -1.5 * rnd2, 0) * viewMul)

	self.LastShotRecoil = viewPunchAngle * 1.5

	return huyang, angpopa, viewMul, rnd1, rnd2, seed
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

	local recoilForce = (self.Primary.Damage or 1) / 100 * self.addSprayMul * (self.NumBullet or 1) * math.min(sprayI / 30, 0.6)
	local huyang, angpopa, viewMul, rnd1, rnd2, seed = self:ComputePrimaryRecoil(mul, recoilForce, sprayI)
	
	if SERVER then
		if owner:IsNPC() then return end
		local org = owner.organism
		if org then
			local force = self.Primary.Force2 or self.Primary.Force or 30
			local numB = self.NumBullet or 1
			local calForce = force * numB

			local rarm_broken = (org.rarm and org.rarm >= 1) and not org.rarmamputated
			local larm_broken = (org.larm and org.larm >= 1) and not org.larmamputated
			local rarm_dislocated = org.rarmdislocated or org.rarmdislocation
			local larm_dislocated = org.larmdislocated or org.larmdislocation

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

			-- Right arm broken shooting checks
			if rarm_broken then
				local extra_broken_pain = calForce * 3.0 -- Increased from 1.5 to 3.0
				if larm_broken then
					extra_broken_pain = extra_broken_pain * 1.5
				end
				org.painadd = org.painadd + extra_broken_pain

				if not rarm_dislocated then
					-- small chance to dislocate
					local disl_chance = 0.05 * (calForce / 30)
					if larm_broken then
						disl_chance = disl_chance * 2
					end
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
						local break_again_chance = 0.02 * (calForce / 50)
						if math.random() < break_again_chance then
							org.painadd = org.painadd + 80
							owner:EmitSound("newbonebreak/break"..math.random(10)..".wav", 75, math.random(110, 130), 1, CHAN_AUTO)
							-- Permanent aiming impairment
							org.permanent_aim_impairment = (org.permanent_aim_impairment or 0) + 0.15
							owner:Notify("Your right arm shattered again - your aim will never be the same!", 1, "rarm_shattered", 1, nil, nil)
						end
					end
				end
			end

			-- Right arm dislocated shooting checks (not broken yet)
			if rarm_dislocated and not rarm_broken then
				-- High caliber weapons can break a dislocated arm
				if calForce >= 50 and not org.rarmamputated then
					local break_chance = 0.03 * (calForce / 50)
					if math.random() < break_chance then
						org.rarm = 1
						org.painadd = org.painadd + 65
						owner:EmitSound("newbonebreak/break"..math.random(10)..".wav", 75, math.random(110, 130), 1, CHAN_AUTO)
						if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
							hg.BreakLimb(owner, "rarm", nil, false)
						end
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
		if huyang then
			ViewPunch2(huyang * (owner.posture == 1 and not self:IsZoom() and 3 or 1) * 0.25)
		end
		if angpopa then
			ViewPunch(angpopa * (hg_coolcamera:GetBool() and 3 or 1))
		end

		ViewPunch2(Angle(-1 * rnd1, -1 * rnd2, 0) * viewMul)
		ViewPunch(Angle(-1 * rnd1, -1 * rnd2, 0) * viewMul / -2)

		timer.Simple(0.01, function()
			if not IsValid(self) then return end
			local rnd1b = SharedRand(seed .. "_t1", 1, 2)
			local rnd2b = SharedRand(seed .. "_t1y", -1, 1)
			ViewPunch2(Angle(-1 * rnd1b, 1 * rnd2b, 0) * viewMul)
		end)

		timer.Simple(0.02, function()
			if not IsValid(self) then return end
			local rnd1c = SharedRand(seed .. "_t2", 1, 2.4)
			ViewPunch2(Angle(1 * rnd1c, 0, 0) * viewMul)
		end)

		ViewPunch2(Angle(2 * rnd1, 2 * rnd2, 0) * viewMul * 0.5)
		ViewPunch(Angle(-2 * rnd1, -2 * rnd2, 0) * viewMul)
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
	self.EyeSpray = self.EyeSpray + value * 0.2 * (FrameTime() / engine.TickInterval())
end

function SWEP:Step_Spray(time,dtime)
	if self.Primary.Next + 0.3 < time then self.SprayI = 0 end

	local eyeSpray = self.EyeSpray
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	local eyeang = owner:EyeAngles()

	owner:SetEyeAngles(eyeang + (eyeSpray * (eyeang.z == 180 and -1 or 1)))
	eyeSpray:Set(LerpAngle(hg.lerpFrameTime2(0.1,dtime), eyeSpray, angZero))
end

--[[else
	function SWEP:ApplyEyeSpray(value) end
	function SWEP:ApplyEyeSprayVel(value) end
end--]]
SWEP.ZoomFOV = 20
function SWEP:AdjustMouseSensitivity()
	--return self:IsZoom() and self:HasAttachment("sight") and (math.min(self.ZoomFOV / 10, 0.5) or 0.5) or 1
end