AddCSLuaFile()

ENT.Base          = "base_nextbot"
ENT.Type          = "nextbot"
ENT.PrintName     = "Kies"
ENT.Category      = "Nextbot"
ENT.Spawnable     = false
ENT.PhysgunDisabled = true
ENT.RenderGroup   = RENDERGROUP_TRANSLUCENT
ENT.slash            = true
ENT.TissueOnlyDamage = true
ENT.NoDismemberment  = true

local HITBOX_MODEL = "models/humans/group01/male_07.mdl"

local SPRITE_H = 80
local SPRITE_W = SPRITE_H * (451 / 1026)

if SERVER then

	local cv_health  = GetConVar("kies_health")
	local cv_speed   = GetConVar("kies_speed")
	local cv_damage  = GetConVar("kies_damage")
	local cv_range   = GetConVar("kies_attack_range")
	local cv_delay   = GetConVar("kies_attack_delay")
	local cv_acquire = GetConVar("kies_acquire_distance")

	resource.AddFile("materials/kies/kies.vmt")
	resource.AddFile("materials/kies/kies.vtf")
	resource.AddFile("materials/kies/killicon.vmt")

	for _, f in ipairs(file.Find("sound/kies/*", "GAME")) do
		local ext = string.lower(string.GetExtensionFromFilename(f) or "")
		if ext == "mp3" or ext == "wav" or ext == "ogg" then
			resource.AddFile("sound/kies/" .. f)
		end
	end

	local ai_ignoreplayers = GetConVar("ai_ignoreplayers")
	local ai_disabled      = GetConVar("ai_disabled")

	local function AIOff()
		return ai_disabled ~= nil and ai_disabled:GetBool()
	end

	local function IsValidTarget(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return false end
		if not ply:Alive() then return false end
		if ply:GetObserverMode() ~= OBS_MODE_NONE then return false end
		if ply:IsFlagSet(FL_NOTARGET) then return false end
		if ai_ignoreplayers and ai_ignoreplayers:GetBool() then return false end
		return true
	end

	local SLASH_ZONES = {
		{artery = "arteria", bone = "ValveBiped.Bip01_Neck1", hitgroup = HITGROUP_HEAD},
		{artery = "larmartery", limb = "larm", bone = "ValveBiped.Bip01_L_Forearm", hitgroup = HITGROUP_LEFTARM},
		{artery = "rarmartery", limb = "rarm", bone = "ValveBiped.Bip01_R_Forearm", hitgroup = HITGROUP_RIGHTARM},
		{artery = "llegartery", limb = "lleg", bone = "ValveBiped.Bip01_L_Thigh", hitgroup = HITGROUP_LEFTLEG},
		{artery = "rlegartery", limb = "rleg", bone = "ValveBiped.Bip01_R_Thigh", hitgroup = HITGROUP_RIGHTLEG},
	}
	local SLASH_START_OFFSET = 4
	local ARTERY_CUT_CHANCE = 0.35
	local ARTERY_CUT_FORCE = 2
	local ARTERY_MIN_ARMOR_PASS = 0.5

	local AURA_RADIUS = 600
	local AURA_INTERVAL = 1
	local AURA_PANIC = 0.12
	local AURA_DEPRESSION = 0.035
	local AURA_ANGER = 0.08

	local HIT_COOLDOWN = 1.8

	local LIMB_RIP_DAMAGE = 45
	local LIMB_RIP_CHANCE = 0.35

	local CRY_RADIUS = 2500
	local CRY_COOLDOWN_MIN = 18
	local CRY_COOLDOWN_MAX = 35
	local CRY_DEPRESSION_MIN = 0.08
	local CRY_DEPRESSION_MAX = 0.25
	local CRY_SHAKEN_CONDITION = 0.2
	local CRY_DESPAIR_CALM = 0.15
	local CRY_DESPAIR_MIN = 0.3
	local CRY_DESPAIR_MAX = 0.65
	local CRY_BLOOD_FINE = 4500
	local CRY_BLOOD_BAD = 2500
	local CRY_PAIN_BAD = 80
	local CRY_LOSING_BAD = 25

	util.AddNetworkString("kies/war-cry")

	local function PickSlashZone(org)
		local intact = {}
		for _, zone in ipairs(SLASH_ZONES) do
			local usable
			if zone.limb then
				usable = org and not org[zone.limb .. "amputated"]
			else
				usable = org and (org[zone.artery] or 0) < 1
			end

			if usable then intact[#intact + 1] = zone end
		end

		local pool = #intact > 0 and intact or SLASH_ZONES
		return pool[math.random(#pool)]
	end

	local function BuildSlashTrace(body, zone, from)
		local bone = body:LookupBone(zone.bone)
		local matrix = bone and body:GetBoneMatrix(bone)
		if not matrix then return end

		local bonePos = matrix:GetTranslation()
		local normal = (bonePos - from):GetNormalized()

		return {
			Entity = body,
			Hit = true,
			HitPos = bonePos - normal * SLASH_START_OFFSET,
			Normal = normal,
			HitNormal = -normal,
			HitBoxBone = bone,
			PhysicsBone = body:TranslateBoneToPhysBone(bone),
			HitGroup = zone.hitgroup,
		}
	end

	local function TryRipLimb(org, limb, damage)
		if org.superfighter or org[limb .. "amputated"] then return end

		org.kiesSlashDamage = org.kiesSlashDamage or {}
		local total = (org.kiesSlashDamage[limb] or 0) + damage
		org.kiesSlashDamage[limb] = total

		if total < LIMB_RIP_DAMAGE or math.Rand(0, 1) > LIMB_RIP_CHANCE * total / LIMB_RIP_DAMAGE then return end

		org.kiesSlashDamage[limb] = nil
		timer.Simple(0, function()
			if IsValid(org.owner) then hg.organism.AmputateLimb(org, limb) end
		end)
	end

	hook.Add("Org Clear", "kies/slash/reset-damage", function(org)
		org.kiesSlashDamage = nil
	end)

	hook.Add("HomigradDamage", "kies/slash/cut-artery", function(victim, dmgInfo, hitgroup, ent)
		local kies = dmgInfo:GetInflictor()
		if not IsValid(kies) or kies:GetClass() ~= "npc_kies" then return end

		local zone = kies.SlashZone
		local contact = kies.MeleeDamageContact
		local org = victim.organism
		if not zone or not contact or not org then return end

		local armorPass = org.lastArmorMitigation
		if zone.hitgroup == HITGROUP_HEAD then armorPass = org.lastHeadArmorMitigation end
		armorPass = armorPass or 1
		if armorPass < ARTERY_MIN_ARMOR_PASS then return end

		if zone.limb then TryRipLimb(org, zone.limb, cv_damage:GetFloat() * armorPass) end
		if (org[zone.artery] or 0) >= 1 or math.Rand(0, 1) > ARTERY_CUT_CHANCE then return end

		hg.organism.input_list[zone.artery](org, 0, ARTERY_CUT_FORCE, dmgInfo, zone.bone,
			contact.normal, contact.hitPos, nil, {entity = ent})
	end)

	local function HoldsLoadedGun(ply)
		local wep = ply:GetActiveWeapon()
		return IsValid(wep) and wep:GetPrimaryAmmoType() >= 0 and wep:Clip1() > 0
	end

	local function IsNearKies(ply, allKies)
		local body = hg.GetCurrentCharacter(ply)
		local pos = IsValid(body) and body:WorldSpaceCenter() or ply:WorldSpaceCenter()

		for _, kies in ipairs(allKies) do
			if pos:DistToSqr(kies:WorldSpaceCenter()) <= AURA_RADIUS * AURA_RADIUS then return true end
		end

		return false
	end

	local function ApplyAura(ply, org)
		if HoldsLoadedGun(ply) then
			hg.organism.RileAnger(org, AURA_ANGER)
			return
		end

		hg.organism.AddPanicAttack(org, AURA_PANIC, false, false, true)
		hg.organism.AddDepression(org, AURA_DEPRESSION, "fight")
	end

	local function CryCondition(org)
		local dying = hg.organism.GetDyingLevel and hg.organism.GetDyingLevel(org) or 0
		local bleeding = (CRY_BLOOD_FINE - (org.blood or CRY_BLOOD_FINE)) / (CRY_BLOOD_FINE - CRY_BLOOD_BAD)
		local pain = (org.pain or 0) / CRY_PAIN_BAD
		local losing = (org.hgLosing or 0) / CRY_LOSING_BAD

		return math.Clamp(math.max(dying, bleeding, pain, losing, org.depression or 0), 0, 1)
	end

	local function HearWarCry(ply, org)
		local condition = CryCondition(org)
		local despair = CRY_DESPAIR_CALM
		if condition >= CRY_SHAKEN_CONDITION then
			despair = Lerp(condition, CRY_DESPAIR_MIN, CRY_DESPAIR_MAX)
		end

		hg.organism.AddDepression(org, Lerp(condition, CRY_DEPRESSION_MIN, CRY_DEPRESSION_MAX), "fight")
		if hg.organism.ShockDespair then hg.organism.ShockDespair(ply, despair) end
	end

	function ENT:TryWarCry()
		if CurTime() < (self.NextWarCry or 0) then return end
		self.NextWarCry = CurTime() + math.Rand(CRY_COOLDOWN_MIN, CRY_COOLDOWN_MAX)

		local origin = self:GetPos() + Vector(0, 0, SPRITE_H * 0.75)

		net.Start("kies/war-cry")
		net.WriteVector(origin)
		net.Broadcast()

		for _, ply in player.Iterator() do
			local org = ply.organism
			if not org or org.otrub or not ply:Alive() or ply:GetObserverMode() ~= OBS_MODE_NONE then continue end
			if HoldsLoadedGun(ply) then continue end

			local body = hg.GetCurrentCharacter(ply)
			local pos = IsValid(body) and body:WorldSpaceCenter() or ply:WorldSpaceCenter()
			if pos:DistToSqr(origin) <= CRY_RADIUS * CRY_RADIUS then HearWarCry(ply, org) end
		end
	end

	timer.Create("kies/aura/apply", AURA_INTERVAL, 0, function()
		local allKies = ents.FindByClass("npc_kies")
		if #allKies == 0 then return end

		for _, ply in player.Iterator() do
			local org = ply.organism
			if not org or org.otrub or not ply:Alive() or ply:GetObserverMode() ~= OBS_MODE_NONE then continue end
			if IsNearKies(ply, allKies) then ApplyAura(ply, org) end
		end
	end)

	function ENT:Initialize()
		self:SetModel(HITBOX_MODEL)
		self:SetCollisionBounds(Vector(-14, -14, 0), Vector(14, 14, SPRITE_H))
		self:DrawShadow(false)
		self:SetBloodColor(DONT_BLEED)

		local hp = cv_health:GetInt()
		self.KiesMaxHealth = hp
		if isfunction(self.SetMaxHealth) then
			self:SetMaxHealth(hp)
		end
		self:SetHealth(hp)

		self.loco:SetDesiredSpeed(cv_speed:GetFloat())
		self.loco:SetAcceleration(400)
		self.loco:SetDeceleration(400)
		self.loco:SetJumpHeight(64)
		self.loco:SetDeathDropHeight(300)

		self.NextAttack = 0
	end

	function ENT:ApplyNewMaxHealth(hp)
		local frac = math.Clamp(self:Health() / math.max(self:GetKiesMaxHealth(), 1), 0, 1)
		self.KiesMaxHealth = hp
		if isfunction(self.SetMaxHealth) then self:SetMaxHealth(hp) end
		self:SetHealth(math.max(1, math.ceil(hp * frac)))
	end

	function ENT:GetKiesMaxHealth()
		return self.KiesMaxHealth or 150
	end

	function ENT:OnInjured(dmginfo)
		local ed = EffectData()
		ed:SetOrigin(dmginfo:GetDamagePosition() ~= vector_origin and dmginfo:GetDamagePosition() or (self:GetPos() + Vector(0, 0, 40)))
		ed:SetMagnitude(1)
		ed:SetScale(1)
		ed:SetRadius(2)
		util.Effect("MetalSpark", ed)
		self:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", 70, math.random(95, 115))
	end

	function ENT:OnKilled(dmginfo)
		if self.KiesDead then return end
		self.KiesDead = true

		hook.Run("OnNPCKilled", self, dmginfo:GetAttacker(), dmginfo:GetInflictor())

		local ed = EffectData()
		ed:SetOrigin(self:GetPos() + Vector(0, 0, 40))
		ed:SetMagnitude(4)
		ed:SetScale(2)
		ed:SetRadius(4)
		util.Effect("ManhackSparks", ed)
		self:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 80, 110)

		self:Remove()
	end

	function ENT:FindTarget()
		local myPos = self:GetPos()
		local maxDist = cv_acquire:GetFloat()
		local best, bestDist = nil, maxDist * maxDist

		for _, ply in ipairs(player.GetAll()) do
			if IsValidTarget(ply) then
				local d = myPos:DistToSqr(ply:GetPos())
				if d < bestDist then
					best, bestDist = ply, d
				end
			end
		end

		return best
	end

	function ENT:TryAttack(target)
		if AIOff() then return end
		if CurTime() < self.NextAttack then return end

		local from = self:GetPos() + Vector(0, 0, SPRITE_H * 0.5)
		local character = hg.GetCurrentCharacter(target)
		local to = (IsValid(character) and character or target):WorldSpaceCenter()
		local range = cv_range:GetFloat()
		if from:DistToSqr(to) > range * range then return end

		self.NextAttack = CurTime() + math.max(cv_delay:GetFloat(), HIT_COOLDOWN)

		local dir = (to - from):GetNormalized()
		local body = IsValid(character) and character or target

		local zone = PickSlashZone(target.organism)
		local trace = BuildSlashTrace(body, zone, from)

		local dmg = DamageInfo()
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamage(cv_damage:GetFloat())
		dmg:SetDamageType(DMG_SLASH)
		dmg:SetDamagePosition(trace and trace.HitPos or body:WorldSpaceCenter())
		dmg:SetDamageForce(dir * 5000)

		if trace then
			hg.SetMeleeDamageContact(self, body, trace)
			self.SlashZone = zone
		end

		body:TakeDamageInfo(dmg)
		hg.ClearMeleeDamageContact(self)
		self.SlashZone = nil

		target:SetVelocity(dir * 250 + Vector(0, 0, 120))
		target:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 75, 100)
	end

	function ENT:HandleStuck()
		self.loco:ClearStuck()
		if self.loco:IsOnGround() then
			self.loco:Jump()
		end
	end

	function ENT:OnStuck()
		if AIOff() then return end
		self:HandleStuck()
	end

	function ENT:FreezeInPlace()
		local v = self.loco:GetVelocity()
		self.loco:SetVelocity(Vector(0, 0, v.z))
	end

	local function HasNavmesh()
		return navmesh.GetNavAreaCount() > 0
	end

	function ENT:ChaseTarget(target)
		local path = Path("Follow")
		path:SetMinLookAheadDistance(250)
		path:SetGoalTolerance(20)

		local nextRepath = 0
		local nextRetarget = CurTime() + 1

		while IsValidTarget(target) do
			if AIOff() then return end

			local now = CurTime()
			local tpos = target:GetPos()

			self.loco:SetDesiredSpeed(cv_speed:GetFloat())

			if HasNavmesh() then
				if now >= nextRepath then
					nextRepath = now + 0.25
					path:Compute(self, tpos)
				end
			end

			if HasNavmesh() and path:IsValid() then
				path:Update(self)
			else
				self.loco:FaceTowards(tpos)
				self.loco:Approach(tpos, 1)
			end

			self:TryWarCry()
			self:TryAttack(target)

			if self.loco:IsStuck() then
				self:HandleStuck()
			end

			if now >= nextRetarget then
				nextRetarget = now + 1
				local best = self:FindTarget()
				if not IsValid(best) then return end
				target = best
			end

			coroutine.yield()
		end
	end

	function ENT:Wander()
		if AIOff() then return end

		if not HasNavmesh() then
			coroutine.wait(1)
			return
		end

		local areas = navmesh.Find(self:GetPos(), 1500, 100, 100)
		if #areas == 0 then
			coroutine.wait(1)
			return
		end

		local goal = areas[math.random(#areas)]:GetRandomPoint()

		local path = Path("Follow")
		path:SetMinLookAheadDistance(200)
		path:SetGoalTolerance(30)
		path:Compute(self, goal)

		if not path:IsValid() then
			coroutine.wait(0.5)
			return
		end

		local giveUp = CurTime() + 8
		local nextScan = CurTime() + 0.5

		self.loco:SetDesiredSpeed(cv_speed:GetFloat())

		while path:IsValid() and CurTime() < giveUp do
			if AIOff() then return end

			path:Update(self)

			if self.loco:IsStuck() then
				self:HandleStuck()
				return
			end

			if CurTime() >= nextScan then
				nextScan = CurTime() + 0.5
				if IsValid(self:FindTarget()) then return end
			end

			coroutine.yield()
		end
	end

	function ENT:RunBehaviour()
		while true do
			if AIOff() then
				self:FreezeInPlace()
				coroutine.wait(0.1)
				continue
			end

			local target = self:FindTarget()

			if IsValid(target) then
				self:ChaseTarget(target)
			else
				self:Wander()
			end

			coroutine.yield()
		end
	end

else

	local MAT_KIES = Material("kies/kies")

	language.Add("npc_kies", "Kies")
	killicon.Add("npc_kies", "kies/killicon", color_white)

	function ENT:Initialize()
		self:SetRenderBounds(
			Vector(-SPRITE_H / 2, -SPRITE_H / 2, 0),
			Vector(SPRITE_H / 2, SPRITE_H / 2, SPRITE_H),
			Vector(5, 5, 5)
		)
	end

	function ENT:Draw() end

	function ENT:DrawTranslucent()
		local pos = self:GetPos() + Vector(0, 0, SPRITE_H / 2)

		local normal = EyePos() - pos
		normal.z = 0
		if normal:LengthSqr() < 0.01 then return end
		normal:Normalize()

		local lc = render.GetLightColor(pos)
		local b = math.Clamp(math.max(lc.x, lc.y, lc.z) * 1.4 + 0.35, 0.5, 1)
		local col = Color(255 * b, 255 * b, 255 * b, 255)

		render.SetMaterial(MAT_KIES)
		render.DrawQuadEasy(pos, normal, SPRITE_W, SPRITE_H, col, 180)
	end

	local cv_volume = CreateClientConVar("kies_volume", "1", true, false,
		"Kies audio volume (0-1).")

	local CRY_SOUND_LEVEL = 110

	local function FindSoundFile()
		for _, f in ipairs(file.Find("sound/kies/*", "GAME")) do
			local ext = string.lower(string.GetExtensionFromFilename(f) or "")
			if ext == "mp3" or ext == "wav" or ext == "ogg" then
				return "kies/" .. f
			end
		end
	end

	local crySound = FindSoundFile()

	net.Receive("kies/war-cry", function()
		local origin = net.ReadVector()
		if not crySound then return end

		sound.Play(crySound, origin, CRY_SOUND_LEVEL, 100, math.Clamp(cv_volume:GetFloat(), 0, 1))
	end)

end

list.Set("NPC", "npc_kies", {
	Name = "Kies",
	Class = "npc_kies",
	Category = "Nextbot",
	AdminOnly = false
})
