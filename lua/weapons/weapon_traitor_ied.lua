if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_tpik_base"
SWEP.PrintName = "Improvised Explosive Device"
SWEP.Instructions = "Press E to plant immediately. Hold LMB for a silent plant, hold RMB on an object to plant inside it, or hold both for a silent inside plant. With IED phones disabled, press LMB after planting to detonate."
SWEP.Category = "Weapons - Explosive"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.HoldType = "normal"
SWEP.WorldModel = "models/props_junk/cardboard_jox004a.mdl"
SWEP.WorldModelReal = "models/saraphines/insurgency explosives/ied/insurgency_ied_phone.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_ied")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_ied"
	SWEP.BounceWeaponIcon = false
end

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 4
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(3, -3, 0)
SWEP.offsetAng = Angle(0, 0, 0)
SWEP.ModelScale = 0.4

SWEP.traceLen = 5

local ExplodeTheItem
local RemoveAttachedBombVisual
local MarkIEDDestroyed

function SWEP:SetupDataTables()

	self:NetworkVar( "Bool", 0, "Planted" )
	self:NetworkVar( "Bool", 1, "Dialing" )
	self:NetworkVar( "Bool", 2, "Destroyed" )
	self:NetworkVar( "Bool", 3, "Detonating" )
	self:NetworkVar( "Bool", 4, "PhoneMode" )
	self:NetworkVar( "Bool", 5, "Planting" )
	self:NetworkVar( "Float", 0, "DetonateAt" )
	self:NetworkVar( "Float", 1, "PlantAt" )
	if SERVER then
		self:SetPlanted(false)
		self:SetDialing(false)
		self:SetDestroyed(false)
		self:SetDetonating(false)
		self:SetPhoneMode(false)
		self:SetPlanting(false)
		self:SetDetonateAt(0)
		self:SetPlantAt(0)
	end
end

SWEP.AnimList = {
	["idle"] = {"idle", 1, true},
	["plant"] = {"plant", 1.2, false, false, function(self)
		if SERVER then self:FinishIEDPlant() end
		self:PlayAnim("det_draw")
	end},
	["det_draw"] = {"det_draw", 1, false, false, function(self)
		self:PlayAnim("det_idle")
	end},
	["det_idle"] = {"det_idle", 1, true},
	["det_detonate"] = {"det_detonate", 1, false}
}

SWEP.AnimsEvents = {
	["plant"] = {
		[0.04] = function(self)
			self:EmitSound("weapons/c4/handling/c4_plant_armmovement.wav", 65)
		end,
		[0.68] = function(self)
			self:EmitSound("weapons/c4/handling/c4_plant_place.wav", 65)
		end
	},
	["det_detonate"] = {
		[0.05] = function(self)
			self:EmitSound("weapons/ied/handling/ied_trigger_ins.wav", 65)
		end
	}
}

if CLIENT then
	local hiddenBoneScale = Vector(0.0001, 0.0001, 0.0001)
	local visibleBoneScale = Vector(1, 1, 1)
	local bombBones = {
		"INSEXP",
		"INS_EXP_Wire_A_0",
		"INS_EXP_Wire_A_01",
		"INS_EXP_Wire_A_02",
		"INS_EXP_Wire_A_03",
		"INS_EXP_Wire_A_04",
		"INS_EXP_Wire_A_05",
		"INS_EXP_Wire_B_02",
		"INS_EXP_Wire_B_03",
		"INS_EXP_Wire_B_04"
	}
	local phoneAnimations = {
		det_draw = true,
		det_idle = true,
		det_detonate = true
	}

	function SWEP:GetIEDWorldModel()
		local getter = self.GetWM
		if isfunction(getter) then return getter(self) end
		return self.worldModel
	end

	function SWEP:SetHandPos()
		local ply = self:GetOwner()
		local model = self:GetIEDWorldModel()
		if not IsValid(ply) or not IsValid(model) then return end
		if not ply.shouldTransmit or ply.NotSeen then return end

		local ent = hg.GetCurrentCharacter(ply)
		if not IsValid(ent) then return end

		self.rhandik = self.setrh
		self.lhandik = self.setlh and not phoneAnimations[self.anim] and ((ply:GetTable().ChatGestureWeight or 0) < 0.1)

		local canUseRight = self.rhandik and hg.CanUseRightHand(ply)
		local canUseLeft = self.lhandik and hg.CanUseLeftHand(ply)
		local rightBones = hg.TPIKBonesRHDict
		local leftBones = hg.TPIKBonesLHDict
		local bombScale = self:GetPlanted() and hiddenBoneScale or visibleBoneScale

		for _, boneName in ipairs(bombBones) do
			local bone = model:LookupBone(boneName)
			if bone then model:ManipulateBoneScale(bone, bombScale) end
		end

		local detonatorBone = model:LookupBone("INS_DET")
		if detonatorBone then
			model:ManipulateBoneScale(detonatorBone, self.anim == "idle" and hiddenBoneScale or visibleBoneScale)
		end

		for modelBone = 0, model:GetBoneCount() - 1 do
			local modelBoneName = model:GetBoneName(modelBone)
			local playerBoneName = rightBones[modelBoneName] or leftBones[modelBoneName]
			if not playerBoneName then continue end
			if rightBones[modelBoneName] and not canUseRight then continue end
			if leftBones[modelBoneName] and not canUseLeft then continue end

			local modelMatrix = model:GetBoneMatrix(modelBone)
			local playerBone = ent:LookupBone(playerBoneName)
			if not modelMatrix or not playerBone then continue end

			ent:SetBoneMatrix(playerBone, modelMatrix)
		end
	end
end

local ExplodeTheItem
local RemoveAttachedBombVisual
local MarkIEDDestroyed

function SWEP:SetHold(value)
	self:SetWeaponHoldType(value)
	self:SetHoldType(value)
	self.holdtype = value
end

function SWEP:ThinkAdd()
	if SERVER and not self:GetPlanted() then
		local owner = self:GetOwner()
		local left = IsValid(owner) and owner:KeyDown(IN_ATTACK)
		local right = IsValid(owner) and owner:KeyDown(IN_ATTACK2)
		if not IsValid(owner) or not owner:Alive() or (not left and not right) then
			if self:GetPlanting() then self:CancelPlant() end
		else
			local mode = left and right and "combined" or right and "inside" or "silent"
			local duration = mode == "combined" and self.CombinedPlantTime
				or mode == "inside" and self.InsidePlantTime
				or self.SilentPlantTime
			if not self.PlantMode then
				self.PlantMode, self.PlantStartedAt = mode, CurTime()
			elseif mode == "combined" then
				self.PlantMode = mode
			end
			self:SetPlanting(true)
			self:SetPlantAt(self.PlantStartedAt + duration)
			self:SetHold("slam")
			if CurTime() >= self.PlantStartedAt + duration then self:FinishPlant() end
		end
	end

	if SERVER and self:GetPlanted() then
		local phonesEnabled = GetConVar("hg_iedphones") and GetConVar("hg_iedphones"):GetBool() or false
		if self:GetPhoneMode() ~= phonesEnabled then
			self:SetPhoneMode(phonesEnabled)
			if HG_PHONE_SERVER then HG_PHONE_SERVER:UpdateIEDPhone(self, phonesEnabled) end
		end
	end

	if SERVER and IsValid(self.HaveTheBomb) then
		self.LastBombPos = self.HaveTheBomb:LocalToWorld(self.HaveTheBomb:OBBCenter())
		self.LastBombModel = self.HaveTheBomb:GetModel()
	end

	if SERVER and self:GetPlanted() and not self:GetDialing() and not self:GetDetonating() and not self.KABOOM and not self.PlantedOnSelf then
		if not IsValid(self.HaveTheBomb) then
			MarkIEDDestroyed(self)
		elseif not self.HaveTheBomb:IsPlayer()
			and not self.HaveTheBomb:IsNPC()
			and not self.HaveTheBomb:IsRagdoll()
			and not IsValid(self.HaveTheBomb:GetPhysicsObject())
		then
			MarkIEDDestroyed(self)
		end
	end
end

function SWEP:Think()
	self:SetHold(self.HoldType)
	self:ThinkAdd()
end

function SWEP:GetEyeTrace()
	return hg.eyeTrace(self:GetOwner())
end

SWEP.BlastDis = 12
SWEP.BlastDamage = 600
SWEP.CallStartDelay = 0.4
SWEP.MaxDialTime = 10
SWEP.MaxDialDistance = 3000
SWEP.CallSound = "rem_iedcall.mp3"
SWEP.CallSoundLevel = 100
SWEP.CallSoundFallbackDuration = 2.5
SWEP.SilentPlantSound = "panoptisscon/phone_query.mp3"
SWEP.SilentPlantSoundLevel = 30
SWEP.CombinedPlantSoundLevel = 45
SWEP.NormalPlantSound = "snd_jack_hmcd_bombrig.ogg"
SWEP.SilentPlantTime = 3.5
SWEP.InsidePlantTime = 5
SWEP.CombinedPlantTime = 7
SWEP.DisorientationRange = 15
SWEP.FireEntForceBonus = 350
SWEP.BlastForce = 600000
SWEP.PlantedBlastForceMul = 1.5
SWEP.PlantedObjectForce = 350000
SWEP.PlantedDoorVelocity = 3000
SWEP.AttachedBombModel = "models/props_junk/cardboard_jox004a.mdl"
SWEP.AttachedBombScale = 0.4
SWEP.ExplosionSounds = {
	"explosions/explode3.wav",
	"explosions/explode4.wav",
	"explosions/explode5.wav"
}
SWEP.ExplosionSoundLevel = 100
SWEP.ExplosionSoundPitchMin = 85
SWEP.ExplosionSoundPitchMax = 90
SWEP.KABOOM = false

SWEP.SoundFar = {"iedins/ied_detonate_dist_01.ogg","ied/ied_detonate_dist_02.ogg","ied/ied_detonate_dist_03.ogg"}
SWEP.Sound = {"ied/ied_detonate_01.ogg", "ied/ied_detonate_02.ogg", "ied/ied_detonate_03.ogg"}
SWEP.SoundWater = "iedins/water/ied_water_detonate_01.ogg"

local FireEnts = {
	["models/props_c17/oildrum001_explosive.mdl"] = true,
	["models/props_junk/gascan001a.mdl"] = true,
	["models/props_junk/propane_tank001a.mdl"] = true,
	["models/props_c17/canister02a.mdl"] = true,
	["models/props_c17/canister_propane01a.mdl"] = true,
	["models/props_c17/canister_propane01a.mdl"] = true,
	["models/props_junk/PropaneCanister001a.mdl"] = true
}

if CLIENT then
	local colWhite = Color(255, 255, 255, 255)
	local colblue = Color(40,40,160)
	local colred = Color(160,40,40)
	local lerpthing = 0
	function SWEP:DrawHUD()
		if GetViewEntity() ~= LocalPlayer() then return end
		if LocalPlayer():InVehicle() then return end
		local tr = self:GetEyeTrace()

		if not tr then return end
		local toScreen = tr.HitPos:ToScreen()
		local Size = math.max(math.min(1 - (tr and tr.Fraction or 0), 1), 0.1)
		local x, y = tr.HitPos:ToScreen().x, tr.HitPos:ToScreen().y
	
		lerpthing = Lerp(0.1, lerpthing, tr.Hit and 1 or 0)
		colWhite.a = 255 * Size * lerpthing
		surface.SetDrawColor(colWhite)
		surface.DrawRect(x - 25 * lerpthing * 0.1, y - 2.5, 50 * lerpthing * 0.1, 5)
		surface.DrawRect(x - 2.5, y - 25 * lerpthing * 0.1, 5, 50 * lerpthing * 0.1)

		if self:GetDestroyed() then
			local xrand,yrand = math.random(-1,1),math.random(-1,1)
			draw.SimpleText( "IED destroyed", "HomigradFontMedium", toScreen.x + 2 + xrand, toScreen.y + 26 + yrand, color_black, TEXT_ALIGN_CENTER )
			draw.SimpleText( "IED destroyed", "HomigradFontMedium", toScreen.x + xrand, toScreen.y + 25 + yrand, color_red, TEXT_ALIGN_CENTER )
		elseif self:GetDetonating() then
			local xrand,yrand = math.random(-1,1),math.random(-1,1)
			draw.SimpleText( "Detonating..", "HomigradFontMedium", toScreen.x + 2 + xrand, toScreen.y + 26 + yrand, color_black, TEXT_ALIGN_CENTER )
			draw.SimpleText( "Detonating..", "HomigradFontMedium", toScreen.x + xrand, toScreen.y + 25 + yrand, color_red, TEXT_ALIGN_CENTER )
		elseif self:GetDialing() then
			local xrand,yrand = math.random(-1,1),math.random(-1,1)
			local timeText = "Time: " .. math.Round(math.max(self:GetDetonateAt() - CurTime(), 0), 1) .. "s"
			draw.SimpleText( "Dialing...", "HomigradFontMedium", toScreen.x + 2 + xrand, toScreen.y + 26 + yrand, color_black, TEXT_ALIGN_CENTER )
			draw.SimpleText( "Dialing...", "HomigradFontMedium", toScreen.x + xrand, toScreen.y + 25 + yrand, color_red, TEXT_ALIGN_CENTER )
			draw.SimpleText( timeText, "HomigradFont", toScreen.x + 2 + xrand, toScreen.y + 56 + yrand, color_black, TEXT_ALIGN_CENTER )
			draw.SimpleText( timeText, "HomigradFont", toScreen.x + xrand, toScreen.y + 55 + yrand, color_white, TEXT_ALIGN_CENTER )
		elseif tr.Hit and not tr.HitSky and IsValid(tr.Entity) and not tr.Entity:IsPlayer() and not tr.Entity:IsRagdoll() and not self:GetPlanted() then
			if not tr.HitWorld then
				local min, max = tr.Entity:GetModelBounds()
				local minmaxs = (max - min)
				local size = minmaxs[1] + minmaxs[2] + minmaxs[3]
				if size <= 15 then return end
			end

			if tr.MatType == MAT_METAL then
				draw.SimpleText( "It will explode with shrapnel.", "HomigradFont", toScreen.x+3, toScreen.y + 25 + 32, color_black, TEXT_ALIGN_CENTER )
				draw.SimpleText( "It will explode with shrapnel.", "HomigradFont", toScreen.x, toScreen.y + 25 + 30, colblue, TEXT_ALIGN_CENTER )
			end

			if FireEnts[tr.Entity:GetModel()] then
				draw.SimpleText( "It will explode creating a fire.", "HomigradFont", toScreen.x+3, toScreen.y + 25 + 62, color_black, TEXT_ALIGN_CENTER )
				draw.SimpleText( "It will explode creating a fire.", "HomigradFont", toScreen.x, toScreen.y + 25 + 60, colred, TEXT_ALIGN_CENTER )
			end
			draw.SimpleText( "Plant onto Object.", "HomigradFont", toScreen.x + 3, toScreen.y + 27, color_black, TEXT_ALIGN_CENTER )
			draw.SimpleText( "Plant onto Object.", "HomigradFont", toScreen.x, toScreen.y + 25, color_white, TEXT_ALIGN_CENTER )
		elseif self:GetPlanting() then
			draw.SimpleText("Planting IED: " .. math.Round(math.max(self:GetPlantAt() - CurTime(), 0), 1) .. "s", "HomigradFontMedium", toScreen.x, toScreen.y + 25, color_white, TEXT_ALIGN_CENTER)
		elseif self:GetPlanted() then
			local xrand,yrand = math.random(-1,1),math.random(-1,1)
			local instruction = self:GetPhoneMode() and "Dial " .. HG_PHONE.GetNumber(self) .. " from a phone." or "LMB to detonate."
			draw.SimpleText(instruction, "HomigradFontMedium", toScreen.x + 2 + xrand, toScreen.y + 26 + yrand, color_black, TEXT_ALIGN_CENTER)
			draw.SimpleText(instruction, "HomigradFontMedium", toScreen.x + xrand, toScreen.y + 25 + yrand, color_red, TEXT_ALIGN_CENTER)
		end
	end
end

function hg.ExplosionDisorientation(enta, tinnitus, disorientation)
	enta.organism.owner:AddTinnitus(tinnitus)
	enta.organism.disorientation = enta.organism.disorientation + (disorientation)

	net.Start("organism_send") // отправляем только дизориентацию (чтобы не нагружать нет), и сразу
	local tbl = {}
	tbl.disorientation = enta.organism.disorientation
	tbl.shock = enta.organism.shock
	tbl.owner = enta.organism.owner
	net.WriteTable(tbl)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.WriteBool(true) // вот эта шняга отвечает за то чтобы оно просто мерджнуло и всё
	net.Send(enta.organism.owner)
end

function SWEP:CreateFake() end

MarkIEDDestroyed = function(self)
	if not IsValid(self) then return end
	if SERVER and HG_PHONE_SERVER and HG_PHONE.GetNumber(self) ~= "" then HG_PHONE_SERVER:UnregisterPhone(self) end

	self:SetDialing(false)
	if self.CallLoopTimer then timer.Remove(self.CallLoopTimer) self.CallLoopTimer = nil end
	self:SetPlanting(false)
	self:SetPlantAt(0)
	self:SetDetonateAt(0)
	self:SetDestroyed(true)
	self:SetDetonating(false)
	self:SetPlanted(false)
	self.Planted = false
	self.PlantedOnSelf = false
	self.HaveTheBomb = nil
	self.IEDPlacementLocalPos = nil
	self.IEDPlacementLocalNormal = nil
	self.IEDHasShrapnel = nil
	RemoveAttachedBombVisual(self)
end

RemoveAttachedBombVisual = function(self)
	if IsValid(self.AttachedBombConstraint) then
		self.AttachedBombConstraint:Remove()
	end

	if IsValid(self.AttachedBombVisual) then
		self.AttachedBombVisual:Remove()
	end

	self.AttachedBombConstraint = nil
	self.AttachedBombVisual = nil
end

local function CreateAttachedBombVisual(self, ent, tr)
	if not IsValid(ent) or not tr then return end

	RemoveAttachedBombVisual(self)

	local visual = ents.Create("prop_physics")
	if not IsValid(visual) then return end

	local ang = tr.HitNormal:Angle()
	ang:RotateAroundAxis(ang:Right(), 90)
	ang:RotateAroundAxis(ang:Up(), 90)

	visual:SetModel(self.AttachedBombModel)
	visual:SetModelScale(self.AttachedBombScale, 0)
	visual:SetPos(tr.HitPos + tr.HitNormal * 4)
	visual:SetAngles(ang)
	visual:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	visual:Spawn()
	visual:Activate()

	local targetPhys = ent:GetPhysicsObject()
	local visualPhys = visual:GetPhysicsObject()
	if IsValid(targetPhys) and IsValid(visualPhys) then
		-- Remorseism's placed explosives are real entities welded to the exact
		-- traced physics bone, so they remain fixed to moving/rotating surfaces.
		visualPhys:SetMass(20)
		self.AttachedBombConstraint = constraint.Weld(visual, ent, 0, tr.PhysicsBone or 0, 9999, true, true)
	else
		-- Brush doors do not expose a weldable physics object. Parenting keeps
		-- the same surface-local placement without making them auto-detonate.
		visual:SetMoveType(MOVETYPE_NONE)
		visual:SetSolid(SOLID_NONE)
		if not ent:IsWorld() then
			visual:SetParent(ent)
			visual:SetLocalPos(ent:WorldToLocal(tr.HitPos + tr.HitNormal * 4))
			visual:SetLocalAngles(ent:WorldToLocalAngles(ang))
		end
	end

	if not ent:IsWorld() then
		ent:DeleteOnRemove(visual)
	end
	self:DeleteOnRemove(visual)
	self.AttachedBombVisual = visual
end

local function RegisterIEDBomb(self, ent, tr, insideObject)
	if not IsValid(ent) then return end

	self.HaveTheBomb = ent
	self:SetDestroyed(false)
	self:SetDetonating(false)
	local owner = self:GetOwner()
	local phonesEnabled = GetConVar("hg_iedphones") and GetConVar("hg_iedphones"):GetBool() or false
	local hasPhone = phonesEnabled and IsValid(owner) and owner:HasWeapon("weapon_phone")
	self:SetPhoneMode(phonesEnabled)
	self:SetPlanted(true)
	self.IEDPlanter = owner
	if phonesEnabled and HG_PHONE_SERVER then
		-- Set privacy before registration; this number must never enter Contacts.
		self:SetNW2Bool("HGPhonePublic", false)
		self:SetNW2Bool("HGPhonePublicInitialized", true)
		HG_PHONE_SERVER:RegisterPhone(self)
		local number = HG_PHONE.GetNumber(self)
		if IsValid(owner) then
			if owner.Notify then
				owner:Notify("IED planted. Dial " .. number .. " to detonate.", 0)
			else
				owner:ChatPrint("IED planted. Dial " .. number .. " to detonate.")
			end
			if not hasPhone then
				local phone = owner:Give("weapon_phone")
				if IsValid(phone) then owner:SelectWeapon("weapon_phone") end
			end
			owner:DropWeapon(self)
			self:SetNoDraw(true)
			self:SetSolid(SOLID_NONE)
			self:SetMoveType(MOVETYPE_NONE)
		end
	end
	if not ent:IsWorld() then
		ent.bombowner = self
		ent.IEDOwner = self
		ent.IEDBlastBonus = self.FireEntForceBonus
		ent:CallOnRemove("ied_destroy_" .. self:EntIndex(), function(removedEnt)
			if IsValid(self) and not self.KABOOM then
				if IsValid(removedEnt) then
					ExplodeTheItem(self, removedEnt)
				else
					MarkIEDDestroyed(self)
				end
			end
		end)
	end

	if tr then
		-- Store the attachment in the target's local space so the charge stays on
		-- moving doors and props, and its blast always pushes through that face.
		local offset = insideObject and -4 or 4
		self.IEDPlacementLocalPos = ent:WorldToLocal(tr.HitPos + tr.HitNormal * offset)
		self.IEDPlacementLocalNormal = ent:WorldToLocalAngles(tr.HitNormal:Angle()):Forward()
		self.IEDHasShrapnel = tr.MatType == MAT_METAL or (hgIsDoor and hgIsDoor(ent))
		if not insideObject then CreateAttachedBombVisual(self, ent, tr) end
	end
end

function SWEP:RegisterExternalIEDBomb(ent)
	if not SERVER or not IsValid(ent) or self:GetPlanted() or self.KABOOM then return false end

	RegisterIEDBomb(self, ent)
	self.PlantedOnSelf = true
	self.LastBombPos = ent:LocalToWorld(ent:OBBCenter())
	self.LastBombModel = ent:GetModel()
	return self:GetPlanted()
end

local function SpawnIEDBomb(pos)
	local bomb = ents.Create("prop_physics")
	if not IsValid(bomb) then return end

	bomb:SetModel("models/props_junk/cardboard_jox004a.mdl")
	bomb:SetPos(pos)
	bomb:SetModelScale(0.4)
	bomb:Spawn()
	bomb:Activate()

	local phys = bomb:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(20) end

	return bomb
end

local function GetIEDDialDelay(self, ent)
	local owner = IsValid(self.IEDPlanter) and self.IEDPlanter or self:GetOwner()
	local entPos = IsValid(ent) and ent:LocalToWorld(ent:OBBCenter()) or vector_origin
	local ownerPos = IsValid(owner) and owner:GetPos() or entPos
	local distance = ownerPos:Distance(entPos)
	return Lerp(math.Clamp(distance / self.MaxDialDistance, 0, 1), self.CallStartDelay, self.MaxDialTime)
end

local function PlayIEDExplosionSound(ent, fallbackPos, sounds, soundLevel, pitchMin, pitchMax)
	if not istable(sounds) or #sounds == 0 then return end

	local soundName = sounds[math.random(#sounds)]
	if IsValid(ent) and not ent:IsWorld() then
		ent:EmitSound(soundName, soundLevel, math.random(pitchMin, pitchMax), 1, CHAN_AUTO)
	else
		sound.Play(soundName, fallbackPos, soundLevel, math.random(pitchMin, pitchMax), 1)
	end
end

local function StartIEDDetonation(self, ent)
	if self:GetDialing() then return end

	local delay = GetIEDDialDelay(self, ent)

	self:SetDialing(true)
	self:SetDestroyed(false)
	self:SetDetonating(false)
	self:SetDetonateAt(CurTime() + delay)
	self:EmitSound("buttonpress.ogg", 55)

	-- Start immediately. At close range the detonation delay equals CallStartDelay,
	-- so delaying this sound could otherwise skip the first call entirely.
	if IsValid(self) and IsValid(ent) and self:GetDialing() then
		local timerName = "IEDCallLoop_" .. self:EntIndex()
		self.CallLoopTimer = timerName
		local pos = self.IEDPlacementLocalPos and ent:LocalToWorld(self.IEDPlacementLocalPos) or ent:GetPos()
		sound.Play(self.CallSound, pos, self.CallSoundLevel, 100, 1)
		local duration = SoundDuration(self.CallSound)
		timer.Create(timerName, duration > 0 and duration or self.CallSoundFallbackDuration, 0, function()
			if not IsValid(self) or not IsValid(ent) or not self:GetDialing() then return timer.Remove(timerName) end
			local pos = self.IEDPlacementLocalPos and ent:LocalToWorld(self.IEDPlacementLocalPos) or ent:GetPos()
			sound.Play(self.CallSound, pos, self.CallSoundLevel, 100, 1)
		end)
		timer.Start(timerName)
	end

	timer.Simple(delay, function()
		if not IsValid(self) then return end

		self:SetDialing(false)
		if self.CallLoopTimer then timer.Remove(self.CallLoopTimer) self.CallLoopTimer = nil end
		self:SetDetonateAt(0)
		self:SetDetonating(true)

		if self.KABOOM then return end

		ExplodeTheItem(self, self.HaveTheBomb)

		self.HaveTheBomb = nil
	end)
end

if SERVER then
	function SWEP:PhoneDetonate()
		if not self:GetPlanted() or self:GetDestroyed() or self.KABOOM or self:GetDialing() or self:GetDetonating() then return false end

		StartIEDDetonation(self, self.HaveTheBomb)
		return true
	end
end

ExplodeTheItem = function(self,ent)
	local ent = ent
	local entValid = IsValid(ent)
	local EntPos = entValid and ent:LocalToWorld(ent:OBBCenter()) or self.LastBombPos
	if not EntPos then self:Remove() return end

	local entModel = entValid and ent:GetModel() or self.LastBombModel
	local entWaterLevel = entValid and ent:WaterLevel() or 0
	local entAngles = entValid and ent:GetAngles() or angle_zero
	local mat = entValid and ent:GetMaterialType() or nil
	local planted = entValid and self.IEDPlacementLocalPos ~= nil
	local plantedWorld = planted and ent:IsWorld()
	local plantedDoor = planted and hgIsDoor and hgIsDoor(ent)
	local hasShrapnel = mat == MAT_METAL or (planted and self.IEDHasShrapnel)
	local plantedNormal

	if planted then
		EntPos = ent:LocalToWorld(self.IEDPlacementLocalPos)
		plantedNormal = ent:LocalToWorldAngles(self.IEDPlacementLocalNormal:Angle()):Forward()
		self.IEDPlacementLocalPos = nil
		self.IEDPlacementLocalNormal = nil
		self.IEDHasShrapnel = nil
	end

	self.KABOOM = true
	self:SetDialing(false)
	self:SetDetonateAt(0)
	self:SetDestroyed(false)
	self:SetDetonating(true)
	RemoveAttachedBombVisual(self)
	if entValid and not ent:IsWorld() then
		ent:StopSound(self.CallSound)
		if ent.bombowner == self then ent.bombowner = nil end
		if ent.IEDOwner == self then ent.IEDOwner = nil end
		ent.IEDBlastBonus = nil
	end
	local BlastDamage = self.BlastDamage
	local BlastDis = self.BlastDis
	local DisorientationRange = self.DisorientationRange or SWEP.DisorientationRange
	local ExplosionSounds = istable(self.ExplosionSounds) and self.ExplosionSounds or SWEP.ExplosionSounds
	local ExplosionSoundLevel = self.ExplosionSoundLevel or SWEP.ExplosionSoundLevel
	local ExplosionSoundPitchMin = self.ExplosionSoundPitchMin or SWEP.ExplosionSoundPitchMin
	local ExplosionSoundPitchMax = self.ExplosionSoundPitchMax or SWEP.ExplosionSoundPitchMax
	local Sound = istable(self.Sound) and self.Sound or SWEP.Sound
	local SoundFar = istable(self.SoundFar) and self.SoundFar or SWEP.SoundFar
	local SoundWater = self.SoundWater or SWEP.SoundWater
	local owner = IsValid(self.IEDPlanter) and self.IEDPlanter or self:GetOwner()
	local attacker = IsValid(owner) and owner or self
	local BlastForce = self.BlastForce * (planted and self.PlantedBlastForceMul or 1)

	if entValid and hg and hg.GasTank and hg.GasTank.ActiveTanks and hg.GasTank.ActiveTanks[ent:EntIndex()] and hg.GasTankDetonate then
		hg.GasTankDetonate(ent)
		self.HaveTheBomb = nil
		if IsValid(self) then
			self:Remove()
		end
		return
	end

	local fireData = entModel and hg and hg.expItems and hg.expItems[entModel]
	if entValid and fireData and hg and hg.PropExplosion then
		local phys = ent:GetPhysicsObject()
		local mass = IsValid(phys) and phys:GetMass() or 10
		-- Fuel containers inherit the charge's full power. Use a copy because the
		-- explosive definition table is shared by every map entity.
		local iedFireData = table.Copy(fireData)
		iedFireData.RangeMul = (iedFireData.RangeMul or 1) * 1.75
		iedFireData.DamageMul = (iedFireData.DamageMul or 1) * 1.75
		iedFireData.KnockbackMul = (iedFireData.KnockbackMul or 1) * 1.8
		iedFireData.FireBoost = 2.5
		iedFireData.ShrapnelCountMul = 3
		ent.IEDBlastBonus = nil
		ent.IEDOwner = nil
		hg.PropExplosion(ent, iedFireData.ExpType, ((ent.Volume or iedFireData.Force) * 2) + self.FireEntForceBonus, mass, iedFireData)
		self.HaveTheBomb = nil
		if IsValid(self) then
			self:Remove()
		end
		return
	end

	timer.Simple(0.4,function()
		timer.Simple(0.1,function()
			PlayIEDExplosionSound(ent, EntPos, ExplosionSounds, ExplosionSoundLevel, ExplosionSoundPitchMin, ExplosionSoundPitchMax)
			net.Start("projectileFarSound")
				net.WriteString(Sound[math.random(#Sound)])
				net.WriteString(SoundFar[math.random(#SoundFar)])
				net.WriteVector(EntPos)
				net.WriteEntity(entValid and ent or Entity(0))
				net.WriteBool(entWaterLevel > 0)
				net.WriteString(SoundWater)
			hg.SendNetToPlayersWithin(EntPos, 25000)

			if entWaterLevel > 0 then
				local effectdata = EffectData()
				effectdata:SetOrigin(EntPos)
				effectdata:SetScale(3)
				effectdata:SetNormal(-entAngles:Forward())
				util.Effect("eff_jack_genericboom", effectdata)
			end
			hg.ExplosionEffect(EntPos, BlastDis / 0.2, 80)

			if hasShrapnel then
				local Poof=EffectData()
				Poof:SetOrigin(EntPos)
				Poof:SetScale(1)
				util.Effect("eff_jack_hmcd_shrapnel",Poof,true,true)
			end
		end)

		timer.Simple(0.2,function()
			local inflictor = IsValid(ent) and ent or self
			if hg and hg.BlastDamageWithShockwave then
				hg.BlastDamageWithShockwave(inflictor, attacker, EntPos, BlastDis / 0.01905, BlastDamage * 0.3, {
					Force = 50000,
					ExplosionType = "IED",
					Filter = IsValid(ent) and {ent} or {}
				})
			else
				util.BlastDamage(inflictor, attacker, EntPos, BlastDis / 0.01905, BlastDamage * 0.3)
			end
			
			local dis = BlastDis / 0.01905
			local disorientation_dis = DisorientationRange / 0.01905
			for _, enta in ipairs(ents.FindInSphere(EntPos, disorientation_dis)) do
				local tracePos = enta:IsPlayer() and (enta:GetPos() + enta:OBBCenter()) or enta:GetPos()
				local tr = hg.ExplosionTrace(EntPos, tracePos, {ent})

				local len = enta:GetPos():Distance(EntPos)
				local frac = math.Clamp((disorientation_dis - len) / disorientation_dis, 0.1, 1)  

				if enta.organism then
					local behindwall = tr.Entity != enta and tr.MatType != MAT_GLASS
					if IsValid(enta.organism.owner) and enta.organism.owner:IsPlayer() and not behindwall then
						hg.ExplosionDisorientation(enta, 5 * frac * 1.5, 6 * frac * 1.5)
						hg.RunZManipAnim(enta.organism.owner, "shieldexplosion")
					end
				end

			end

			--hgWreckBuildings(ent, EntPos, BlastDamage / 400, BlastDis/8, false)
			hgBlastDoors(IsValid(ent) and ent or attacker, EntPos, BlastDamage / 400, BlastDis/8, false)
			util.ScreenShake( EntPos, 50, 300, 3.5, 4000 )

			if FireEnts[entModel] then
				local Tr = util.QuickTrace(EntPos, -vector_up*500, {EntPos})
				local fire = CreateVFire(game.GetWorld(), Tr.HitPos, Tr.HitNormal, 300, IsValid(owner) and owner or self)
				if IsValid(fire) then
					fire:ChangeLife(300)
				end
			end

			local shrapnelActive = false

			if IsValid(ent) and IsValid(ent:GetPhysicsObject()) then
				shrapnelActive = true
				local fragmentCount = math.Clamp(1200 + math.Round(ent:GetPhysicsObject():GetMass() * 20), 1200, 3000)
				if ent.iedFreePlant then
					fragmentCount = math.max(math.Round(fragmentCount * 0.75), 900)
				end
				local co = coroutine.create(function()
					local LastShrapnel = SysTime()

					for i = 1, fragmentCount do
							if not IsValid(ent) then return end
							LastShrapnel = SysTime()

							local dir = VectorRand(-1,1):GetNormalized()--vector_up
							dir[3] = dir[3] > 0 and math.abs(dir[3] - 0.5) or -math.abs(dir[3] + 0.5)
							dir:Normalize()

							local Tr = util.QuickTrace(EntPos, dir * 400, ent)

							if Tr.Hit and !Tr.HitSky and (!Tr.HitWorld or Tr.Fraction >= 0.2) then
								if not IsValid(ent) then return end
								local bullet = {}
								bullet.Dir = dir
								bullet.Src = EntPos
								bullet.Force = 0.01
								bullet.Damage = BlastDamage
								bullet.AmmoType = "Metal Debris"
								bullet.Attacker = attacker
								bullet.Distance = 400
								bullet.DisableLagComp = true
								bullet.Filter = {ent}
								bullet.Penetration = 6
								--bullet.Spread = vecCone * i / self.Fragmentation
								ent:FireLuaBullets(bullet, true)
							end

							LastShrapnel = SysTime() - LastShrapnel

							if LastShrapnel > 0.001 then
								coroutine.yield()
							end
					end

				ent.ShrapnelDone = true
			end)

			ent.ShrapnelDone = false
			local ok = coroutine.resume(co)
				if not ok then
					ent.ShrapnelDone = true
				end

				local index = self:EntIndex()

				if IsValid(self) then
					self:Remove()
				end

				timer.Create("IEDCheck_" .. index, 0, 0, function()
					if not IsValid(ent) then
						timer.Remove("IEDCheck_" .. index)
						return
					end

					if coroutine.status(co) ~= "dead" then
						local ok = coroutine.resume(co)
						if not ok then
							timer.Remove("IEDCheck_" .. index)
							return
						end
					end

					if ent.ShrapnelDone then
						ent:Remove()
						timer.Remove("IEDCheck_" .. index)
					end
				end)
			end

			if IsValid(self) then
				self:Remove()
			end

			if not shrapnelActive and IsValid(ent) then
				ent:Remove()
			end
		end)
	end)
end

function SWEP:CanSecondaryAttack()
	local owner = self:GetOwner()
	local character = IsValid(owner) and hg.GetCurrentCharacter(owner)
	return not self.IEDPlantPending and IsValid(character) and not character:IsRagdoll()
end

function SWEP:BeginIEDPlant(mode, tr)
	if self.IEDPlantPending or self:GetPlanted() or not tr then return end

	self.IEDPlantPending = true
	self.IEDPlantMode = mode
	self.IEDPlantEntity = tr.Entity
	self.IEDPlantPos = tr.HitPos
	self.IEDPlantNormal = tr.HitNormal
	if mode == "embedded" and IsValid(tr.Entity) then
		self.IEDPlantLocalPos = tr.Entity:WorldToLocal(tr.HitPos)
		self.IEDPlantLocalAng = tr.Entity:WorldToLocalAngles(tr.HitNormal:Angle())
	end
	self:PlayAnim("plant")
end

function SWEP:FinishIEDPlant()
	if not self.IEDPlantPending or self:GetPlanted() then return end

	local owner = self:GetOwner()
	local mode = self.IEDPlantMode
	local bomb
	if not IsValid(owner) then
		self.IEDPlantPending = false
		self.IEDPlantMode = nil
		self.IEDPlantEntity = nil
		self.IEDPlantLocalPos = nil
		self.IEDPlantLocalAng = nil
		return
	end

	if mode == "embedded" then
		bomb = self.IEDPlantEntity
		local isCharacter = IsValid(bomb) and (bomb:IsPlayer() or bomb:IsNPC() or bomb:IsRagdoll())
		if not IsValid(bomb) or not isCharacter and not IsValid(bomb:GetPhysicsObject()) then
			self.IEDPlantPending = false
			self:PlayAnim("idle")
			return
		end

		if self.IEDPlantLocalPos and self.IEDPlantLocalAng then
			self.IEDPlantPos = bomb:LocalToWorld(self.IEDPlantLocalPos)
			self.IEDPlantNormal = bomb:LocalToWorldAngles(self.IEDPlantLocalAng):Forward()
		end
	else
		bomb = ents.Create("prop_physics")
		if not IsValid(bomb) then
			self.IEDPlantPending = false
			self:PlayAnim("idle")
			return
		end

		bomb:SetModel("models/saraphines/insurgency explosives/ied/insurgency_ied.mdl")
		bomb:SetModelScale(0.8)
		local bombAng = self.IEDPlantNormal:Angle()
		bombAng:RotateAroundAxis(bombAng:Right(), 90)
		bombAng:RotateAroundAxis(bombAng:Up(), 90)
		bomb:SetPos(self.IEDPlantPos + self.IEDPlantNormal * 2)
		bomb:SetAngles(bombAng)
		bomb:Spawn()
		bomb:Activate()
		bomb.iedFreePlant = true

		local mins, maxs = bomb:OBBMins(), bomb:OBBMaxs()
		local placement = util.TraceHull({
			start = self.IEDPlantPos + self.IEDPlantNormal * 8,
			endpos = self.IEDPlantPos - self.IEDPlantNormal * 4,
			mins = mins,
			maxs = maxs,
			filter = {owner, bomb},
			mask = MASK_SOLID
		})
		if placement.Hit then
			bomb:SetPos(placement.HitPos + placement.HitNormal * 0.5)
		end

		local phys = bomb:GetPhysicsObject()
		if not IsValid(phys) then
			bomb:Remove()
			self.IEDPlantPending = false
			self.IEDPlantMode = nil
			self.IEDPlantEntity = nil
			self:PlayAnim("idle")
			return
		end

		phys:SetMass(20)
		phys:SetBuoyancyRatio(0.05)
		phys:EnableMotion(true)
		phys:Wake()
	end

	self.Planted = true
	RegisterIEDBomb(self, bomb, mode == "embedded" and {
		HitPos = self.IEDPlantPos,
		HitNormal = self.IEDPlantNormal
	} or nil)
	owner:EmitSound("snd_jack_hmcd_bombrig.wav", mode == "embedded" and 50 or 60, 100, 1, CHAN_AUTO)
	self:SetNextPrimaryFire(CurTime() + 2)
	self.nextattackhuy = CurTime() + 2
	self:SetPlanted(true)
	self.IEDPlantPending = false
	self.IEDPlantMode = nil
	self.IEDPlantEntity = nil
	self.IEDPlantLocalPos = nil
	self.IEDPlantLocalAng = nil
end

function SWEP:SecondaryAttack(calledFrom)
	if SERVER then
		if not calledFrom then
			if not self:CanSecondaryAttack() then
				return
			end
		end
		if not self.Planted then
			local owner = self:GetOwner()
			local character = IsValid(owner) and hg.GetCurrentCharacter(owner)
			local filter = {owner, character}
			local aimPos = owner:EyePos() + owner:GetAimVector() * 85

			local tr = util.TraceLine({
				start = owner:EyePos(),
				endpos = aimPos,
				filter = filter,
				mask = MASK_SOLID
			})

			local plantTrace
			if tr.Hit then
				plantTrace = {
					Entity = tr.Entity,
					HitPos = tr.HitPos,
					HitNormal = tr.HitNormal
				}
			else
				local down = util.TraceLine({
					start = aimPos,
					endpos = aimPos - Vector(0, 0, 1000),
					filter = filter,
					mask = MASK_SOLID
				})
				if down.Hit then
					plantTrace = {
						Entity = down.Entity,
						HitPos = down.HitPos,
						HitNormal = down.HitNormal
					}
				end
			end

			if plantTrace then
				self:BeginIEDPlant("free", plantTrace)
			end
		end
	end
end

function SWEP:Initialize()
	self:SetHold(self.HoldType)
	self.Planted = false
	self.HaveTheBomb = false
end

if SERVER then
	function SWEP:OnRemove()
		if HG_PHONE_SERVER and HG_PHONE.GetNumber(self) ~= "" then HG_PHONE_SERVER:UnregisterPhone(self) end
		RemoveAttachedBombVisual(self)
		if self.CallLoopTimer then timer.Remove(self.CallLoopTimer) end
	end
end

if CLIENT then
	function SWEP:PrimaryAttack()
	end
end

if SERVER then
	SWEP.nextattackhuy = 0
	SWEP.PlantedOnSelf = false

	function SWEP:CancelPlant()
		self.PlantMode = nil
		self.PlantStartedAt = nil
		self:SetPlanting(false)
		self:SetPlantAt(0)
		self:SetHold("normal")
	end
	function SWEP:AttackHuy()
		if self.IEDPlantPending then return end
		if not (self.Planted or self.HaveTheBomb or self.PlantedOnSelf) then
			local Owner = self:GetOwner()
			local Tr = self:GetEyeTrace()
			local character = IsValid(Owner) and hg.GetCurrentCharacter(Owner)
			local target = Tr and Tr.Entity
			local targetPhys = IsValid(target) and target:GetPhysicsObject()
			local canEmbed = IsValid(target) and (
				target:IsPlayer()
				or target:IsNPC()
				or target:IsRagdoll()
				or IsValid(targetPhys) and targetPhys:GetMass() < 500
			)

			if canEmbed then
				if not target:IsPlayer() and not target:IsNPC() and not target:IsRagdoll() then
					local min, max = target:GetModelBounds()
					local minmaxs = max - min
					local size = minmaxs[1] + minmaxs[2] + minmaxs[3]
					if size <= 15 then return end
				end

				self:BeginIEDPlant("embedded", Tr)
				return
			elseif IsValid(character) and character:IsRagdoll() then
				self:SecondaryAttack(true)
				return
			end
		end

		return self:PlaceNormally()
	end

	-- E is an immediate plant.  This used to call a deleted method, leaving the
	-- weapon in hand and throwing an error every time the advertised control was
	-- used.  Keep it independent from the timed planting animation.
	function SWEP:PlaceNormally()
		local owner = self:GetOwner()
		if not IsValid(owner) or self:GetPlanted() or self.Planted or self.IEDPlantPending then return false end

		local tr = self:GetEyeTrace()
		if not tr or tr.HitSky then return false end

		local bomb
		if tr.Hit and IsValid(tr.Entity) and not tr.HitWorld
			and not tr.Entity:IsPlayer() and not tr.Entity:IsNPC() and not tr.Entity:IsRagdoll()
		then
			RegisterIEDBomb(self, tr.Entity, tr, false)
		else
			local pos = tr.Hit and (tr.HitPos + tr.HitNormal * 4) or (owner:GetShootPos() + owner:GetAimVector() * 80)
			bomb = SpawnIEDBomb(pos)
			if not IsValid(bomb) then return false end
			RegisterIEDBomb(self, bomb)
		end

		self.Planted = true
		self:SetPlanted(true)
		owner:EmitSound(self.NormalPlantSound, 60, 100, 1, CHAN_AUTO)
		self.nextattackhuy = CurTime() + 2
		return true
	end

	function SWEP:FinishPlant()
		local owner, tr, mode = self:GetOwner(), self:GetEyeTrace(), self.PlantMode
		if not IsValid(owner) or not tr.Hit or tr.HitSky then return self:CancelPlant() end
		local inside = mode == "inside" or mode == "combined"
		if inside then
			local phys = IsValid(tr.Entity) and tr.Entity:GetPhysicsObject()
			local door = IsValid(tr.Entity) and hgIsDoor and hgIsDoor(tr.Entity)
			if not IsValid(tr.Entity) or tr.HitWorld or not (door or (IsValid(phys) and phys:GetMass() < 500)) then return self:CancelPlant() end
			RegisterIEDBomb(self, tr.Entity, tr, true)
		else
			local target = tr.Entity
			if IsValid(target) and not tr.HitWorld and not target:IsPlayer() and not target:IsRagdoll() then
				RegisterIEDBomb(self, target, tr, false)
			else
				local bomb = SpawnIEDBomb(tr.HitPos + tr.HitNormal * 4)
				if not IsValid(bomb) then return self:CancelPlant() end
				RegisterIEDBomb(self, bomb)
			end
		end
		self:CancelPlant()
		self.Planted = true
		self:SetPlanted(true)
		local sound, level = self.SilentPlantSound, self.SilentPlantSoundLevel
		if mode == "inside" then sound, level = self.NormalPlantSound, 60 end
		if mode == "combined" then level = self.CombinedPlantSoundLevel end
		owner:EmitSound(sound, level, 100, 1, CHAN_AUTO)
	end

	hook.Add("KeyPress", "hg_ied_immediate_plant", function(ply, key)
		if key ~= IN_USE then return end

		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_traitor_ied" then
			wep:PlaceNormally()
		end
	end)

	function SWEP:PrimaryAttack()
		if not self:GetPlanted() then return end

		if self:GetPhoneMode() then
			if not HG_PHONE_SERVER or not HG_PHONE_SERVER.OpenIEDPhone then return end
			self:SetNextPrimaryFire(CurTime() + 0.4)
			HG_PHONE_SERVER.OpenIEDPhone(self:GetOwner(), self)
			return
		end

		if (self.nextattackhuy or 0) > CurTime() then return end
		if self:PhoneDetonate() then
			self.nextattackhuy = CurTime() + 1
			self:SetNextPrimaryFire(CurTime() + 1)
		end
	end
	function SWEP:SecondaryAttack() end


	function SWEP:Reload()
		if (self.NextPhoneOpen or 0) > CurTime() then return end
		self.NextPhoneOpen = CurTime() + 0.5
		if not self:GetPlanted() then
			self.IEDPublicOnPlant = not self.IEDPublicOnPlant
			self:GetOwner():ChatPrint("IED number will be " .. (self.IEDPublicOnPlant and "public." or "private."))
			return
		end

		if self:GetPhoneMode() and HG_PHONE_SERVER and HG_PHONE_SERVER.OpenIEDPhone then
			HG_PHONE_SERVER.OpenIEDPhone(self:GetOwner(), self)
		end

		-- Historical self-plant behavior remains intentionally disabled.
		--if not self.Planted and not self.PlantedOnSelf then
		--	local Owner = self:GetOwner()
--
		--	self.PlantedOnSelf = true
--
--
		--	self.WorldModel = "models/saraphines/insurgency explosives/ied/insurgency_ied_phone.mdl"
--
		--	net.Start("ied_have_the_bomb")
		--	net.WriteEntity(self)
		--	net.Broadcast()
--
		--	Owner:EmitSound("snd_jack_hmcd_bombrig.ogg",50,100,1,CHAN_AUTO)
--
		--	self.Planted = true
--
--
		--	timer.Simple(5, function()
		--		if IsValid(self) and IsValid(Owner) and self.PlantedOnSelf then
		--			ExplodeTheItem(self, Owner)
		--		end
		--	end)
--
		--	self:SetNextPrimaryFire(CurTime() + 2)
		--end
	end
end
