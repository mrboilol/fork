AddCSLuaFile()
--
function SWEP:ResetTransientAimState()
	self.EyeSpray = Angle(0, 0, 0)
	self.EyeSprayVel = Angle(0, 0, 0)
	self.sprayAngles = Angle(0, 0, 0)
	self.SprayI = 0
	self.LastRecoilDirection = Angle(0, 0, 0)
	self.recoilWobbleAmp = 0
	self.ShotMuzzleWobble = Angle(0, 0, 0)
	self.ShotMuzzleOffset = Vector(0, 0, 0)
	self.cache_trace = nil
	self:SetLastShootTime(0)
end

function SWEP:Initialize_Spray()
	self:ResetTransientAimState()
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

SWEP.RecoilMul = 0.7
SWEP.ScreenRecoilMul = 0.6
SWEP.WeaponRecoilMul = 1.25

local cos, sin, math_max, math_min = math.cos, math.sin, math.max, math.min
function SWEP:GetPrimaryMul()
	local owner = self:GetOwner()
	local mul = ((0.5) + math_max(self.Primary.Force / 110 - 1, 0)) * (owner.Crouching and owner:Crouching() and self.CrouchMul or 1)
	self:ApplyForce(mul)
	mul = (mul or 0) * (owner.organism and owner.organism.recoilmul or 1)
	return mul
end

SWEP.sprayAngles = Angle(0,0,0)

SWEP.weaponSway = Angle(0,0,0)

local hg_coolcamera = ConVarExists("hg_coolcamera") and GetConVar("hg_coolcamera") or CreateConVar("hg_coolcamera", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Cool camera movement", 0, 1)

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
			local support = self.GetHandSupportState and self:GetHandSupportState(owner) or {}
			local firingArm = support.firingArm or "rarm"
			local effectiveness = hg.GetArmEffectiveness and hg.GetArmEffectiveness(owner, firingArm) or 1
			local recoilForce = self.Primary.Force
			if self.GetRecoilImpulseFactors then
				local _, _, resolvedForce = self:GetRecoilImpulseFactors()
				recoilForce = resolvedForce
			end
			local injuryPain = math.max(0, 1 - effectiveness) * math.Clamp((recoilForce or self.Primary.Force or 30) / 15, 0.5, 6)
			if support.oneHanded then injuryPain = injuryPain + math.max((recoilForce or 0) - 25, 0) * 0.035 end
			org.painadd = (org.painadd or 0) + injuryPain
		end
	end

	if CLIENT and (owner == LocalPlayer() or (not LocalPlayer():Alive() and owner == LocalPlayer():GetNWEntity("spect"))) and !self.norecoil then
		local organism = owner.organism or {}
		local caliberMul, weightMul = 1, 1
		if self.GetRecoilImpulseFactors then
			caliberMul, weightMul = self:GetRecoilImpulseFactors()
		end
		local supportMul = self.GetRecoilSupportMul and self:GetRecoilSupportMul() or 1
		local handlingMul = self.GetArmHealthHandlingMul and self:GetArmHealthHandlingMul() or 1
		local stanceMul = self.GetPostureStabilityMul and self:GetPostureStabilityMul(self:IsZoom()) or 1
		local cantedHold = owner.posture == 7 or owner.posture == 9
		local force = math.Clamp(caliberMul * weightMul * supportMul * handlingMul * stanceMul * (0.65 + math.min(sprayI / 12, 0.6)), 0.15, 4)
		mul = mul * supportMul * handlingMul
		mul = mul * self.RecoilMul
		local screenRecoilMul = self.ScreenRecoilMul or 1
		mul = mul * (owner:Crouching() and 0.75 or 1)
		--mul = mul * (hg.IsOnGround(hg.GetCurrentCharacter(owner)) and 1 or 5)
		mul = mul * (self:IsResting() and 0.1 or 1)

		local firstShotMul = sprayI == 1 and 0.45 or sprayI == 2 and 0.7 or 1
		local angRand = AngleRand(0.03, 0.05) * firstShotMul
		angRand[1] = -math.abs(angRand[1])
		angRand[2] = (math.random(2) == 1 and 1 or -1) * angRand[2]
		angRand[3] = 0
		local spray

		if sprayI < 3 then
			spray = angRand
		else
			spray = self.Spray[sprayI] or Angle(0.01, 0)
		end
		
		local angranda = AngleRand(self.SprayRand[1], self.SprayRand[2])
		angranda[3] = 0
		spray = spray + angranda * self.addSprayMul * mul * (self.randmul or 1)

		local angrand2
		if cantedHold then
			-- Clockwise-canted Gangsta/Somalian holds rotate muzzle rise into leftward travel.
			angrand2 = Angle(math.Rand(-force * 0.18, force * 0.08), -math.Rand(force * 0.72, force * 1.15), -math.Rand(force * 0.12, force * 0.35))
		else
			angrand2 = Angle(-math.Rand(force * 0.65, force), math.Rand(-force * 0.22, force * 0.22), math.Rand(-force * 0.08, force * 0.08))
		end
		self.LastRecoilDirection = Angle(angrand2[1] / math.max(force, 0.001), angrand2[2] / math.max(force, 0.001), angrand2[3] / math.max(force, 0.001))
		
		local angrand3 = -(-angrand2)
		angrand3[3] = 0
		if not self.SprayRandOnly then
			if not cantedHold then
				angrand2[1] = math.Clamp(-math.abs(angrand2[1]), -10, -force / 1.5)
				angrand2[2] = math.Clamp(angrand2[2], -1, 1)
				angrand2[3] = -angrand2[2]
			end
			local mulhuy = GetGlobalBool("FullRealismMode",false) and 10 or 1
			mul = mul * self:GetAttachmentRecoilMul()
			
			local huyang = angrand2 * mul / 2 * mulhuy
			huyang[3] = 0
			ViewPunch2(huyang * (owner.posture == 1 and not self:IsZoom() and 3 or 1) * 0.12 * screenRecoilMul)
			
			local angpopa = angrand2 * mul
			angpopa[3] = 0
			ViewPunch(angpopa * (hg_coolcamera:GetBool() and 1.2 or 0.45) * screenRecoilMul)
			spray = spray + angRand * 2 * (self.randmul or 1)
		end

		-- The old recoil system kicked the muzzle itself, not only the camera.
		-- Keep this render-side so authoritative shot spread remains predictable;
		-- sh_worldmodel applies the offset and eases it back after every shot.
		-- Recoil owns the dominant rise while addSprayMul widens only side travel.
		local muzzleKickMul = math.Clamp(force * (self.WeaponRecoilMul or 1), 0.1, 5)
		local muzzleSideMul = math.Clamp(self.addSprayMul or 1, 0.08, 2.5)
		self.ShotMuzzleWobble = (self.ShotMuzzleWobble or Angle(0, 0, 0)) + Angle(
			(cantedHold and math.Rand(-0.12, 0.08) or -math.Rand(0.42, 0.82)) * muzzleKickMul,
			(cantedHold and -math.Rand(0.65, 1.05) or math.Rand(-0.22, 0.22)) * muzzleKickMul * muzzleSideMul,
			(cantedHold and -math.Rand(0.18, 0.38) or math.Rand(-0.14, 0.14)) * muzzleKickMul * muzzleSideMul
		)
		self.ShotMuzzleOffset = (self.ShotMuzzleOffset or Vector(0, 0, 0)) + Vector(
			-math.Rand(0.18, 0.42) * muzzleKickMul,
			(cantedHold and -math.Rand(0.28, 0.55) or math.Rand(-0.13, 0.13)) * muzzleKickMul * muzzleSideMul,
			(cantedHold and math.Rand(-0.08, 0.12) or math.Rand(0.2, 0.48)) * muzzleKickMul
		)

		local prank3 = math.Rand(-self.Primary.Force2,self.Primary.Force2) / (self.Primary.Force2 != 0 and self.Primary.Force2 or 1) * 2
		local angleprikol = Angle(0,0,prank3)

		//ViewPunch2(angleprikol)

		local cameraKick = math.Clamp(force * self.Primary.Force2 / 100, 0.05, 1.2) * screenRecoilMul
		ViewPunch2(angrand2 * cameraKick * 0.2)
		ViewPunch(angrand2 * cameraKick * 0.08)

		local eyeang = owner:EyeAngles()
		local sprayAng = (spray * (self:IsResting() and 0.1 or 1) * 8 + angrand3 * self.addSprayMul) * (eyeang.z == 180 and -1 or 1)
		sprayAng[3] = 0

		sprayAng:RotateAroundAxis(angle_zero:Forward(), eyeang.roll)
		sprayAng.roll = 0

		owner:SetEyeAngles(eyeang + sprayAng * (organism.recoilmul or 1) * (owner.posture == 1 and not self:IsZoom() and 0.1 or 1) * 0.12 * screenRecoilMul)
		
		local max_clip1 = self:GetMaxClip1()
		
		if(max_clip1 == 0)then
			max_clip1 = 1
		end
		
		local sprayvel = spray * mul * math.max(sprayI / max_clip1, 0.5) * self.addSprayMul * (self.cameraShakeMul or 1) * 10 * 1.2//(self.Primary.Automatic and 1 or 1)
		
		--self.weaponSway = self.weaponSway + sprayvel

		self.sprayAngles[3] = self.sprayAngles[3] + math.max(self.Primary.Damage / 100,1) * self.addSprayMul * (self.cameraShakeMul or 1) * ((((self.NumBullet or 1) - 1) / 2) + 1) * (((self.podkid or 1) - 1) / 3 + 1) / 40

		self:ApplyEyeSprayVel(sprayvel * 1)
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
	self.EyeSpray = self.EyeSpray + value * 0.2 * (FrameTime() / engine.TickInterval())
end

function SWEP:Step_Spray(time,dtime)
	if self.Primary.Next + 0.22 < time then self.SprayI = 0 end
	
	if SERVER then return end

	local eyeSpray = self.EyeSpray
	local owner = self:GetOwner()
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
