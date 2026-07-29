hg = hg or {}

local vpang = Angle(1,-2,1)

local function IsFirearm(wep)
	if not IsValid(wep) then return false end
	if not ishgweapon(wep) then return false end
	if not wep.Primary or not wep.Primary.Ammo or wep.Primary.Ammo == "" then return false end
	return wep:Clip1() > 0
end

local function GetFearChanceBonus(ply)
	local org = IsValid(ply) and ply.organism or nil
	return math.Clamp(org and org.fear or 0, 0, 2) * 0.15
end

function hg.AccidentalFire(ply, wep, baseChance)
	if not IsValid(ply) or not IsValid(wep) then return false end
	if not IsFirearm(wep) then return false end
	if (ply.hg_accidental_fire_cd or 0) > CurTime() then return false end

	local chance = math.min(baseChance + GetFearChanceBonus(ply), 0.8)
	if math.random() >= chance then return false end

	ply.hg_accidental_fire_cd = CurTime() + 0.5

	local oldOwner = wep:GetOwner()
	if not IsValid(oldOwner) then oldOwner = nil end

	wep:SetOwner(ply)
	wep:PrimaryAttack(true)

	if oldOwner == nil then
		wep:SetOwner()
	elseif oldOwner ~= ply then
		wep:SetOwner(oldOwner)
	end

	return true
end

local function GetHeldFirearm(ply)
	local wep = IsValid(ply.ActiveWeapon) and ply.ActiveWeapon or ply:GetActiveWeapon()
	if IsFirearm(wep) then return wep end
	return nil
end

local function drop(ply, wep, newWeapon, vel)
	local wep = isentity(wep) and wep or ply:GetActiveWeapon()
	if not IsValid(wep) or wep.NoDrop then return end
	if ply:GetNWFloat("willsuicide", 0) > 0 then return end -- you cant escape.
	local eyeAngles = ply:LocalEyeAngles()
	local knockVelocity = isvector(vel) and vel or nil
	local knockSpin = knockVelocity and VectorRand() * math.Rand(350, 650) or nil

	hg.AccidentalFire(ply, wep, IsValid(ply.FakeRagdoll) and 0.55 or 0.18)

	ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_1HAND)
	ply:ViewPunch(vpang)
	timer.Simple(0,function()
		if not IsValid(ply) or not IsValid(wep) then return end
		local pos, ang
		
		if wep.WorldModel_Transform then
			pos, ang = wep:WorldModel_Transform(true)
		end
		
		if not IsValid(newWeapon) then
                        local hands = hg.GetHandsWeapon and hg.GetHandsWeapon(ply) or ply:GetWeapon("weapon_hands_sh")
                        if IsValid(hands) then
                                ply:SelectWeapon(hands:GetClass())
                                ply:SetActiveWeapon(hands)
                        end
		else
			ply:SelectWeapon(newWeapon:GetClass())
			ply:SetActiveWeapon(newWeapon)
		end

		local dropVelocity = knockVelocity and (knockVelocity + ply:GetVelocity() * 0.35) or (eyeAngles:Forward() * (isnumber(vel) and vel or 250)) + ply:GetVelocity()
		ply:DropWeapon(wep, nil, not IsValid(wep.fakeGun) and dropVelocity or nil)
		
		wep.init = true
		wep.IsSpawned = true


		timer.Simple(0,function()
			if pos and ang then
				local tr = {}
				tr.start = ply:EyePos()
				tr.endpos = pos
				tr.filter = {ply,wep}
				tr.mask = MASK_SOLID
				local tr = util.TraceLine(tr)
				if tr.Hit then pos = ply:EyePos() end
				wep:SetPos(pos)
				wep:SetAngles(ang)
			end

			if knockSpin then
				local phys = wep:GetPhysicsObject()
				if IsValid(phys) then phys:AddAngleVelocity(knockSpin) end
			end

		end)

		ply:ViewPunch(Angle(-1,5,-2))
		wep:SetOwner()
		if IsValid(wep.fakeGun) then wep:RemoveFake() end	
	end)
end

hg.drop = drop

local function IsHeldGun(wep, owner)
	if not IsValid(wep) or wep:GetOwner() ~= owner or wep.NoDrop or owner:GetNWFloat("willsuicide", 0) > 0 then return false end
	if not ishgweapon(wep) then return false end
	return wep.Primary and wep.Primary.Ammo and wep.Primary.Ammo ~= ""
end

function hg.TraceHeldWeaponShot(startPos, endPos, attacker, damage, force, originalTrace)
	if not isvector(startPos) or not isvector(endPos) then return end

	local ray = endPos - startPos
	if ray:LengthSqr() <= 0 then return end

	local closestFraction = 1
	local hitPlayer, hitWeapon, hitPos, hitNormal
	local attackerPlayer = IsValid(attacker) and (attacker:IsPlayer() and attacker or (attacker.GetOwner and attacker:GetOwner())) or nil

	for _, ply in ipairs(player.GetAll()) do
		if ply == attackerPlayer or not ply:Alive() or IsValid(ply.FakeRagdoll) then continue end
		if util.DistanceToLine(startPos, endPos, ply:WorldSpaceCenter()) > 128 then continue end

		local wep = ply:GetActiveWeapon()
		if not IsHeldGun(wep, ply) or (wep.hg_knocked_from_hands or 0) > CurTime() then continue end
		if not wep.WorldModel_Transform then continue end

		local pos, ang = wep:WorldModel_Transform(true)
		if not pos or not ang then continue end

		-- worldModel is clientside. Use the SWEP's server-side model bounds at
		-- the transformed held pose so bullets can actually intersect the gun.
		local mins, maxs = wep:OBBMins(), wep:OBBMaxs()
		if not mins or not maxs or mins == maxs then continue end

		local intersectPos, intersectNormal, fraction = util.IntersectRayWithOBB(startPos, ray, pos, ang, mins, maxs)
		if intersectPos and fraction >= 0 and fraction < closestFraction then
			closestFraction = fraction
			hitPlayer = ply
			hitWeapon = wep
			hitPos = intersectPos
			hitNormal = intersectNormal
		end
	end

	if not IsValid(hitPlayer) or not IsValid(hitWeapon) then return end

	local direction = ray:GetNormalized()
	local damageAmount = math.max(tonumber(damage) or 0, 0)
	local forceAmount = math.max(tonumber(force) or 0, 0)
	local dropChance = math.Clamp(0.12 + damageAmount / 220 + forceAmount / 650, 0.12, 0.55)
	if math.random() < dropChance then
		hitWeapon.hg_knocked_from_hands = CurTime() + 0.25
		local impactSpeed = math.Clamp(250 + damageAmount * 12 + forceAmount * 4, 350, 1000)
		local knockVelocity = direction * impactSpeed + vector_up * math.Rand(80, 160) + VectorRand() * 55
		hg.drop(hitPlayer, hitWeapon, nil, knockVelocity)
	else
		hitWeapon.hg_knocked_from_hands = CurTime() + 0.05
	end

	local trace = table.Copy(originalTrace or {})
	trace.Hit = true
	trace.HitWorld = false
	trace.HitSky = false
	trace.StartSolid = false
	trace.AllSolid = false
	trace.StartPos = startPos
	trace.HitPos = hitPos
	trace.Normal = direction
	trace.HitNormal = hitNormal or -direction
	trace.Fraction = closestFraction
	trace.FractionLeftSolid = 0
	trace.Entity = hitWeapon
	trace.PhysicsBone = 0
	trace.HitGroup = 0
	trace.HitBox = 0
	trace.MatType = MAT_METAL
	trace.SurfaceProps = 0
	trace.HitTexture = "**studio**"

	return trace
end
concommand.Add("drop", drop)
concommand.Add("dropweapon", drop)
concommand.Add("-drop", drop)
concommand.Add("-dropweapon", drop)
local whitelist = {
	["*drop"] = true,
	["/drop"] = true,
	["!drop"] = true
}

hook.Add("HG_PlayerSay", "homigrad-drop-weapons", function(ply, txtTbl, text)
	if whitelist[text] then
		drop(ply)
		txtTbl[1] = ""
	end
end)

local function IsFullAuto(wep)
	if not IsValid(wep) then return false end
	local base = weapons.Get(wep:GetClass())
	return base and base.Primary and base.Primary.Automatic
end

local function StartAutoTriggerHold(ply, wep, duration)
	if not IsValid(ply) or not IsValid(wep) then return end
	local endTime = CurTime() + duration
	local timerName = "hg_auto_trigger_" .. ply:EntIndex()
	timer.Create(timerName, 0.05, 0, function()
		if not IsValid(ply) or not IsValid(wep) or CurTime() > endTime then
			timer.Remove(timerName)
			return
		end
		if not IsFirearm(wep) then timer.Remove(timerName) return end
		wep:SetOwner(ply)
		wep:PrimaryAttack(true)
	end)
end

hook.Add("Fake", "hg-accidental-fire-fake", function(ply, ragdoll)
	if not IsValid(ply) then return end
	local wep = GetHeldFirearm(ply)
	if not wep then return end
	hg.AccidentalFire(ply, wep, 0.05)
end)

hook.Add("DoPlayerDeath", "hg-accidental-fire-track", function(ply)
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	ply.hg_deathWep = IsFirearm(wep) and wep or nil
end)

hook.Add("PlayerDropWeapon", "hg-accidental-fire-track-drop", function(ply, wep)
	if not IsValid(ply) or not IsValid(wep) then return end
	ply.hg_lastDroppedWep = wep
	ply.hg_lastDroppedWepTime = CurTime()

	timer.Simple(0.1, function()
		if not IsValid(wep) then return end
		local phys = wep:GetPhysicsObject()
		if not IsValid(phys) then return end
		local speed = phys:GetVelocity():Length()
		if speed < 50 then return end
		local impactChance = math.Clamp(speed / 800, 0, 1) * 0.55
		wep.hg_floor_discharge_chance = impactChance
		wep.hg_floor_discharge_owner = ply
		wep.hg_floor_discharge_expires = CurTime() + 3

		wep.PhysicsCollide = function(self, data, physobj)
			if not self.hg_floor_discharge_chance then return end
			if CurTime() > (self.hg_floor_discharge_expires or 0) then
				self.hg_floor_discharge_chance = nil
				return
			end
			if data.Speed < 100 then return end
			local chance = self.hg_floor_discharge_chance * math.Clamp(data.Speed / 400, 0.2, 1)
			local owner = self.hg_floor_discharge_owner
			self.hg_floor_discharge_chance = nil
			if IsValid(owner) and math.random() < chance then
				hg.AccidentalFire(owner, self, 1)
			end
		end
	end)
end)

hook.Add("RagdollDeath", "hg-accidental-fire-death", function(ply, ragdoll)
	if not IsValid(ply) then return end
	local wep = ply.hg_deathWep
	ply.hg_deathWep = nil
	if not IsValid(wep) and (CurTime() - (ply.hg_lastDroppedWepTime or 0)) < 1 then
		wep = ply.hg_lastDroppedWep
		ply.hg_lastDroppedWep = nil
	end
	if not IsValid(wep) then return end
	hg.AccidentalFire(ply, wep, 0.55)

	if IsFullAuto(wep) and math.random() < 0.45 then
		local holdDuration = math.Remap(math.random(), 0, 1, 0.3, 4.0)
		StartAutoTriggerHold(ply, wep, holdDuration)
	end
end)