if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Zerlkers"
SWEP.Instructions = "Keeps you awake even when you are not supposed to be, very powerful. Please do not take more than 2."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/tic tacs/winter_green.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("zerlkers/keepitzen.png", "smooth")
	SWEP.IconOverride = "zerlkers/keepitzen.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 2
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(2.5, -2.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modeNames = {[1] = "zerlkers"}
SWEP.modeValuesdef = {[1] = 1}
SWEP.DeploySnd = "snd_jack_hmcd_pillsbounce.ogg"
SWEP.FallSnd = "Metal_Barrel.ImpactHard"
SWEP.showstats = false

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Heal animation type: 0 = progressive minigames, 1 = Judge animations, 2 = progressive Judge minigames", 0, 2)

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)
	self.modeValues = {[1] = 1}
end

function SWEP:Think()
	self:SetBodyGroups("111")
	if not self:GetOwner():KeyDown(IN_ATTACK) and hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 4, 0))
	end
end

local leftArmAngle, leftForearmAngle = Angle(0, -10, 0), Angle(0, 10, 0)

function SWEP:Animation()
	local owner = self:GetOwner()
	if owner.zmanipstart ~= nil and not owner.organism.larmamputated then return end

	local aimvec = owner:GetAimVector()
	if not aimvec then return end

	local hold = self:GetHolding()
	if owner:IsFlagSet(FL_DUCKING) or owner:GetVelocity():LengthSqr() >= 17000 then
		aimvec[3] = -2
		hold = hold / 2
	end

	local ducking = owner:IsFlagSet(FL_ANIMDUCKING)
	self:BoneSet("r_upperarm", vector_origin, Angle(30 + 10 * aimvec[3], (-50 - hold) + 10 * aimvec[3] * (ducking and -4 or -2) + hold / 2, 10 - hold / 3))
	self:BoneSet("r_forearm", vector_origin, Angle(-10, -hold, -hold))
	self:BoneSet("l_upperarm", vector_origin, leftArmAngle)
	self:BoneSet("l_forearm", vector_origin, leftForearmAngle)
end

function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if IsValid(owner) and owner:IsNPC() then
		self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
		self:NPCHeal(owner, 0.2, "snd_jack_hmcd_pillsuse.ogg")
	end
end

if SERVER then
	function SWEP:SpawnEmptyBox()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local character = hg.GetCurrentCharacter(owner)
		if not IsValid(character) then character = owner end
		local bone = character:LookupBone("ValveBiped.Bip01_R_Hand")
		local matrix = bone and character:GetBoneMatrix(bone)

		local box = ents.Create("ent_throwable")
		if not IsValid(box) then return end
		box.WorldModel = self.WorldModel
		box:SetPos(matrix and matrix:GetTranslation() or character:WorldSpaceCenter())
		box:SetAngles(AngleRand(-180, 180))
		box:SetOwner(owner)
		box:Spawn()
		box.localshit = vector_origin
		box.wep = "weapon_zerlkers_empty"
		box.owner = owner
		box.damage = 18
		box.MaxSpeed = 750
		box.DamageType = DMG_CLUB
		box.AttackHit = "Metal_Barrel.ImpactHard"
		box.AttackHitFlesh = "Flesh.ImpactHard"
		box.noStuck = true

		local phys = box:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMaterial("metal_barrel")
			phys:SetVelocity(owner:GetVelocity() + owner:GetAimVector() * 170 + VectorRand(-35, 35))
			phys:AddAngleVelocity(VectorRand(-180, 180))
		end
	end

	function SWEP:Heal(ent)
		if ent:IsNPC() then
			self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
			self:NPCHeal(ent, 0.2, "snd_jack_hmcd_pillsuse.ogg")
		end

		local org = ent.organism
		if not org or not self.modeValues or (self.modeValues[1] or 0) <= 0 then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))
			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(org.owner.FakeRagdoll) and org.owner.FakeRagdoll or org.owner
		entOwner:EmitSound("snd_jack_hmcd_pillsuse.ogg", 60, math.random(95, 105))
		-- Preserve active doses so taking another pill can cross the overdose
		-- threshold. Round the remaining dose up because any still-active pill
		-- counts as a full concurrent dose for toxicity.
		org.zerlkers = math.min(math.ceil(org.zerlkers or 0) + 1, 4)
		entOwner:EmitSound("panoptisscon/Stare.mp3", 60, 100)

		self.modeValues[1] = 0
		owner:SelectWeapon("weapon_hands_sh")
		self:SpawnEmptyBox()
		self:Remove()
		return true
	end
end
