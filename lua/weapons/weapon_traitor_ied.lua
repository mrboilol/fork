if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_base"
SWEP.PrintName = "Improvised Explosive Device"
SWEP.Instructions = "Press E to plant immediately. Hold LMB for a silent plant, hold RMB on an object to plant inside it, or hold both for a silent inside plant. Dial the assigned number from a phone to detonate."
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

SWEP.ViewModel = ""

function SWEP:DrawWorldModel()
	if not IsValid(self:GetOwner()) then
		self:DrawWorldModel2()
	end
end

function SWEP:DrawWorldModel2()
	local desiredModel = self:GetPhoneMode()
		and "models/saraphines/insurgency explosives/ied/insurgency_ied_phone.mdl"
		or "models/props_junk/cardboard_jox004a.mdl"
	if not IsValid(self.model) or self.model:GetModel() ~= desiredModel then
		if IsValid(self.model) then self.model:Remove() end
		self.model = ClientsideModel(desiredModel)
	end
	local WorldModel = self.model
	local owner = self:GetOwner()
	WorldModel:SetNoDraw(true)
	WorldModel:SetModelScale(self:GetPhoneMode() and 1 or (self.ModelScale or 1))
	WorldModel:SetSkin(self:GetPhoneMode() and 1 or 0)
	local renderGuy = hg.GetCurrentCharacter(owner)
	if IsValid(owner) then
		local offsetVec = self:GetPhoneMode() and Vector(5, 0.5, -15) or self.offsetVec
		local offsetAng = self:GetPhoneMode() and Angle(0, 70, 180) or self.offsetAng

		local boneid = renderGuy:LookupBone("ValveBiped.Bip01_R_Hand")
		if not boneid then return end
		local matrix = renderGuy:GetBoneMatrix(boneid)
		if not matrix then return end
		local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())

		WorldModel:SetPos(newPos)
		WorldModel:SetAngles(newAng)
		WorldModel:SetupBones()
	else
		WorldModel:SetPos(self:GetPos())
		WorldModel:SetAngles(self:GetAngles())
	end

	WorldModel:DrawModel()
end

function SWEP:SetHold(value)
	self:SetWeaponHoldType(value)
	self:SetHoldType(value)
	self.holdtype = value
end

function SWEP:Think()
	self:SetHold(self.HoldType)
	if SERVER and not self:GetPlanted() then
		local owner = self:GetOwner()
		local left, right = IsValid(owner) and owner:KeyDown(IN_ATTACK), IsValid(owner) and owner:KeyDown(IN_ATTACK2)
		if not IsValid(owner) or not owner:Alive() or (not left and not right) then
			if self:GetPlanting() then self:CancelPlant() end
		else
			local mode = left and right and "combined" or right and "inside" or "silent"
			local duration = mode == "combined" and self.CombinedPlantTime or mode == "inside" and self.InsidePlantTime or self.SilentPlantTime
			if not self.PlantMode then self.PlantMode, self.PlantStartedAt = mode, CurTime() elseif mode == "combined" then self.PlantMode = mode end
			self:SetPlanting(true)
			self:SetPlantAt(self.PlantStartedAt + duration)
			self:SetHold("slam")
			if CurTime() >= self.PlantStartedAt + duration then self:FinishPlant() end
		end
	end
	if SERVER and self:GetPlanted() and HG_PHONE_SERVER and HG_PHONE.GetNumber(self) == "" then
		HG_PHONE_SERVER:RegisterPhone(self)
	end
	if SERVER and IsValid(self.HaveTheBomb) then
		self.LastBombPos = self.IEDPlacementLocalPos and self.HaveTheBomb:LocalToWorld(self.IEDPlacementLocalPos) or (self.HaveTheBomb:GetPos() + self.HaveTheBomb:OBBCenter())
		self.LastBombModel = self.HaveTheBomb:GetModel()
	end

	if SERVER and self:GetPlanted() and not self:GetDialing() and not self:GetDetonating() and not self.KABOOM and not self.PlantedOnSelf then
		if not IsValid(self.HaveTheBomb) then
			MarkIEDDestroyed(self)
		elseif not self.HaveTheBomb:IsWorld() and not (hgIsDoor and hgIsDoor(self.HaveTheBomb)) and not IsValid(self.HaveTheBomb:GetPhysicsObject()) then
			ExplodeTheItem(self, self.HaveTheBomb)
		end
	end
end

function SWEP:GetEyeTrace()
	return hg.eyeTrace(self:GetOwner())
end

SWEP.BlastDis = 35
SWEP.BlastDamage = 1000
SWEP.CallStartDelay = 1
SWEP.MaxDialTime = 10
SWEP.MaxDialDistance = 3000
SWEP.CallSound = "rem_iedcall.mp3"
SWEP.CallSoundLevel = 100
SWEP.CallSoundFallbackDuration = 2.5
SWEP.SilentPlantSound = "panoptisscon/phone_query.ogg"
SWEP.SilentPlantSoundLevel = 30
SWEP.CombinedPlantSoundLevel = 45
SWEP.NormalPlantSound = "snd_jack_hmcd_bombrig.wav"
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

SWEP.SoundFar = {"iedins/ied_detonate_dist_01.wav","ied/ied_detonate_dist_02.wav","ied/ied_detonate_dist_03.wav"}
SWEP.Sound = {"ied/ied_detonate_01.wav", "ied/ied_detonate_02.wav", "ied/ied_detonate_03.wav"}
SWEP.SoundWater = "iedins/water/ied_water_detonate_01.wav"

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
			local number = HG_PHONE.GetNumber(self)
			draw.SimpleText("Dial " .. number .. " from a phone.", "HomigradFontMedium", toScreen.x + 2 + xrand, toScreen.y + 26 + yrand, color_black, TEXT_ALIGN_CENTER)
			draw.SimpleText("Dial " .. number .. " from a phone.", "HomigradFontMedium", toScreen.x + xrand, toScreen.y + 25 + yrand, color_red, TEXT_ALIGN_CENTER)
		end
	end
end

function hg.ExplosionDisorientation(enta, tinnitus, disorientation)
	local owner = enta.organism and enta.organism.owner
	local hasHeadphones = IsValid(owner) and owner.armors and owner.armors["ears"] == "headphones1"

	-- дизориентация (мотание экрана) — полная, как было
	enta.organism.disorientation = enta.organism.disorientation + disorientation

	if hasHeadphones then
		-- активные наушники (броня headphones1): тинитуса нет вообще, мотание экрана остаётся
	else
		-- без активных наушников — полный/громкий тинитус и контузия
		if IsValid(owner) then owner:AddTinnitus(tinnitus) end
		hg.organism.module.concussion.AddConcussion(enta.organism, math.Clamp(tinnitus * 0.1, 0.1, 2.0), tinnitus)
	end

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
	local hasPhone = IsValid(owner) and owner:HasWeapon("weapon_phone")
	self:SetPhoneMode(hasPhone)
	self:SetPlanted(true)
	if HG_PHONE_SERVER then
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
			self.IEDPlanter = owner
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
	local entPos = IsValid(ent) and (self.IEDPlacementLocalPos and ent:LocalToWorld(self.IEDPlacementLocalPos) or (ent:GetPos() + ent:OBBCenter())) or vector_origin
	local ownerPos = IsValid(owner) and owner:GetPos() or entPos
	local distance = ownerPos:Distance(entPos)
	return Lerp(math.Clamp(distance / self.MaxDialDistance, 0, 1), self.CallStartDelay, self.MaxDialTime)
end

local function PlayIEDExplosionSound(self, ent)
	if IsValid(ent) and not ent:IsWorld() then
		ent:EmitSound(table.Random(self.ExplosionSounds), self.ExplosionSoundLevel, math.random(self.ExplosionSoundPitchMin, self.ExplosionSoundPitchMax), 1, CHAN_AUTO)
	else
		sound.Play(table.Random(self.ExplosionSounds), self.LastBombPos or self:GetPos(), self.ExplosionSoundLevel, math.random(self.ExplosionSoundPitchMin, self.ExplosionSoundPitchMax), 1)
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

		if self.PlantedOnSelf then
			ExplodeTheItem(self, self:GetOwner())
		else
			ExplodeTheItem(self, self.HaveTheBomb)
		end

		self.HaveTheBomb = nil
	end)
end

if SERVER then
	function SWEP:PhoneDetonate()
		if not self:GetPlanted() or self:GetDestroyed() or self.KABOOM or self:GetDialing() or self:GetDetonating() then return false end

		if self.PlantedOnSelf then
			StartIEDDetonation(self, self:GetOwner())
		else
			StartIEDDetonation(self, self.HaveTheBomb)
		end
		return true
	end
end

ExplodeTheItem = function(self,ent)
	local ent = ent
	local entValid = IsValid(ent)
	local EntPos = entValid and (ent:GetPos() + ent:OBBCenter()) or self.LastBombPos
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
	local owner = self:GetOwner()
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
			PlayIEDExplosionSound(self, ent)
			net.Start("projectileFarSound")
				net.WriteString(self.Sound[math.random(#self.Sound)])
				net.WriteString(self.SoundFar[math.random(#self.SoundFar)])
				net.WriteVector(EntPos)
				net.WriteEntity(entValid and ent or Entity(0))
				net.WriteBool(entWaterLevel > 0)
				net.WriteString(self.SoundWater)
			net.Broadcast()
			if hg and hg.PlayExtraExplosionSound then
				hg.PlayExtraExplosionSound(EntPos, entValid and ent:EntIndex() or self:EntIndex(), 1)
			else
				local soundIndex = entValid and ent:EntIndex() or self:EntIndex()
				EmitSound("explosionextra/explode_" .. math.random(1, 9) .. ".wav", EntPos, soundIndex + 800, CHAN_ITEM, 1, 145, 0, math.random(95, 105))
			end

			if entWaterLevel == 0 then
				ParticleEffect("pcf_jack_groundsplode_medium",EntPos,-vector_up:Angle())
			else
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
			util.BlastDamage(self, IsValid(self:GetOwner()) and self:GetOwner() or self, EntPos, BlastDis / 0.01905, BlastDamage * 0.1) -- эта функция полное говно кстати. бьет сковзь любые пропы...
			
			local dis = BlastDis / 0.01905
			local disorientation_dis = self.DisorientationRange / 0.01905
			for _, enta in ipairs(ents.FindInSphere(EntPos, disorientation_dis)) do
				local tracePos = enta:IsPlayer() and (enta:GetPos() + enta:OBBCenter()) or enta:GetPos()
				local tr = hg.ExplosionTrace(EntPos, tracePos, {ent})

				local phys = enta:GetPhysicsObject()
				local force = (enta:GetPos() - EntPos)
				local len = force:Length()
				force:Div(len)
				local frac = math.Clamp((disorientation_dis - len) / disorientation_dis, 0.1, 1)  
				local physics_frac = math.Clamp((dis - len) / dis, 0.5, 1)  
				local forceadd = force * physics_frac * BlastForce

			if enta.organism then
				local behindwall = tr.Entity != enta and tr.MatType != MAT_GLASS
				if IsValid(enta.organism.owner) and enta.organism.owner:IsPlayer() then
					local div = behindwall and hg.GetBlastWallAttenuation(tr) or 1
					hg.ExplosionDisorientation(enta, 5 * frac * 1.5 / div, 6 * frac * 1.5 / div)
					hg.RunZManipAnim(enta.organism.owner, "shieldexplosion")
				end
			end

				if len > dis then continue end
				if tr.Entity != enta then 					
					if IsValid(phys) then
						phys:ApplyForceCenter((forceadd/20) + vector_up * math.random(500,550))
					end

					continue
				end

				if enta:IsPlayer() then
					hg.AddForceRag(enta, 0, forceadd * 0.5, 0.5)
					hg.AddForceRag(enta, 1, forceadd * 0.5, 0.5)

					hg.LightStunPlayer(enta)
				end

				if not IsValid(phys) then continue end
				phys:ApplyForceCenter(forceadd)
			end

			-- A charge planted on a door breaches it away from the face it was placed
			-- on, instead of using the weak radial fallback for nearby doors.
			if plantedDoor and plantedNormal then
				hgBlastThatDoor(ent, -plantedNormal * self.PlantedDoorVelocity)
			else
				hgBlastDoors(entValid and ent or self, EntPos, BlastDamage / 400, BlastDis/8, false)
			end

			if planted and entValid and not plantedWorld and not plantedDoor and plantedNormal then
				local plantedPhys = ent:GetPhysicsObject()
				if IsValid(plantedPhys) then
					plantedPhys:ApplyForceOffset(-plantedNormal * self.PlantedObjectForce, EntPos)
				end
			end
			util.ScreenShake( EntPos, 45, 225, 2.5, 3000 )

			if FireEnts[entModel] then
				local Tr = util.QuickTrace(EntPos, -vector_up*500, {EntPos})
				local fire = CreateVFire(game.GetWorld(), Tr.HitPos, Tr.HitNormal, 300, IsValid(owner) and owner or self)
				if IsValid(fire) then
					fire:ChangeLife(300)
				end
			end

			if hasShrapnel and entValid then
				local shrapnelPhys = ent:GetPhysicsObject()
				local shrapnelMass = IsValid(shrapnelPhys) and shrapnelPhys:GetMass() or 20
				local shrapnelDone = false
				local co = coroutine.create(function()
					local LastShrapnel = SysTime()

					for i = 1, math.Clamp(math.Round(shrapnelMass * 300), 800, 6000) do
							LastShrapnel = SysTime()

							local dir = VectorRand(-1,1):GetNormalized()--vector_up
							dir[3] = dir[3] > 0 and math.abs(dir[3] - 0.5) or -math.abs(dir[3] + 0.5)
							dir:Normalize()

							local Tr = util.QuickTrace(EntPos, dir * 900, ent)

							if Tr.Hit and !Tr.HitSky and !Tr.HitWorld then
								local bullet = {}
								bullet.Dir = dir
								bullet.Src = EntPos
								bullet.Force = 0.01
								bullet.Damage = BlastDamage
								bullet.AmmoType = "Metal Debris"
								bullet.Attacker = IsValid(owner) and owner or game.GetWorld()
								bullet.Distance = 900
								bullet.DisableLagComp = true
								bullet.Filter = {ent}
								bullet.Penetration = 8
								--bullet.Spread = vecCone * i / self.Fragmentation
								ent:FireLuaBullets(bullet, true)
							end

							LastShrapnel = SysTime() - LastShrapnel

							if LastShrapnel > 0.001 then
								coroutine.yield()
							end
					end

					shrapnelDone = true
				end)

				coroutine.resume(co)

				local index = self:EntIndex()

				if IsValid(self) then
					self:Remove()
				end

				timer.Create("IEDCheck_" .. index, 0, 0, function()
					if not IsValid(ent) then
						timer.Remove("IEDCheck_" .. index)
						return
					end

					if coroutine.status(co) != "dead" then
						coroutine.resume(co)
					end
					if shrapnelDone then
						if not plantedWorld and not plantedDoor then
							ent:Remove()
						end
						timer.Remove("IEDCheck_" .. index)
					end
				end)
			end

			if IsValid(self) then
				self:Remove()
			end

			if not hasShrapnel and not plantedWorld and not plantedDoor and IsValid(ent) then
				ent:Remove()
			end
		end)
	end)
end

function SWEP:CanSecondaryAttack()
	return IsValid(self:GetOwner()) and not hg.GetCurrentCharacter(self:GetOwner()):IsRagdoll()
end

function SWEP:SecondaryAttack(calledFrom)
	if SERVER then
		if not calledFrom then
			if not self:CanSecondaryAttack() then
				return
			end
		end
		self:PlaceNormally()

	end
end

function SWEP:Initialize()
	self:SetHold(self.HoldType)
	self.Planted = false
	self.HaveTheBomb = false
	self.WorldModel = "models/props_junk/cardboard_jox004a.mdl"
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

	function SWEP:PlaceNormally()
		local owner = self:GetOwner()
		if not IsValid(owner) or self:GetPlanted() or self.Planted then return false end

		local tr = self:GetEyeTrace()
		if tr.HitSky then return false end

		local target = tr.Entity
		if tr.Hit and IsValid(target) and not tr.HitWorld and not target:IsPlayer() and not target:IsRagdoll() then
			RegisterIEDBomb(self, target, tr, false)
		else
			local pos = tr.Hit and (tr.HitPos + tr.HitNormal * 4) or (owner:GetShootPos() + owner:GetAimVector() * 80)
			local bomb = SpawnIEDBomb(pos)
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
		if not self:GetPlanted() or not self:GetPhoneMode() or not HG_PHONE_SERVER or not HG_PHONE_SERVER.OpenIEDPhone then return end
		self:SetNextPrimaryFire(CurTime() + 0.4)
		HG_PHONE_SERVER.OpenIEDPhone(self:GetOwner(), self)
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
		--	Owner:EmitSound("snd_jack_hmcd_bombrig.wav",50,100,1,CHAN_AUTO)
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
