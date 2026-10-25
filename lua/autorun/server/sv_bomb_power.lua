hg = hg or {}

local SHRAPNEL_PER_TICK = 40
local SHRAPNEL_RANGE = 56756
local SHRAPNEL_AMMO = "Metal Debris"
local FIRE_PROP_MASS = 100
local FIRE_FORCE_PER_DISTANCE = 0.01524
local NORMAL_FORCE_PER_DISTANCE = 0.1524

function hg.BombShrapnel(pos, attacker, count, damage)
	local carrier = ents.Create("prop_dynamic")
	if not IsValid(carrier) then return end

	carrier:SetModel("models/props_junk/PopCan01a.mdl")
	carrier:SetPos(pos)
	carrier:Spawn()
	carrier:SetNoDraw(true)
	carrier:SetNotSolid(true)

	local ammo = hg.ammotypeshuy and hg.ammotypeshuy[SHRAPNEL_AMMO]
	local settings = ammo and ammo.BulletSettings or {}
	local filter = {carrier}
	local bullet = {
		Speed = settings.Speed,
		Distance = SHRAPNEL_RANGE,
		MaxPenLen = 100,
		Diameter = settings.Diameter or 1,
		Src = pos,
		Force = 20,
		Damage = damage,
		AmmoType = SHRAPNEL_AMMO,
		Attacker = IsValid(attacker) and attacker or game.GetWorld(),
		Inflictor = carrier,
		DisableLagComp = true,
		Filter = filter,
		Callback = hg.bulletHit
	}

	local fired = 0
	local name = "hg_bomb_shrapnel_" .. carrier:EntIndex()

	timer.Create(name, 0, 0, function()
		if not IsValid(carrier) then
			timer.Remove(name)
			return
		end

		for i = 1, SHRAPNEL_PER_TICK do
			if fired >= count then
				timer.Remove(name)
				SafeRemoveEntity(carrier)
				return
			end
			fired = fired + 1

			local dir = VectorRand()
			dir.z = dir.z * 0.7
			dir:Normalize()

			local tr = util.TraceLine({start = pos, endpos = pos + dir * 100, filter = filter, mask = MASK_SHOT})
			if tr.HitWorld then continue end

			bullet.Dir = dir
			bullet.penetrated = 0
			bullet.Penetration = settings.Penetration or 10
			carrier:FireLuaBullets(bullet, true)
		end
	end)
end

function hg.BombExplode(ent, attacker, level)
	if not IsValid(ent) or ent.HasExploded then return end

	local cfg = hg.BombPower[math.Clamp(level or hg.BombPowerDefault, 1, #hg.BombPower)]
	local pos = ent:WorldSpaceCenter()

	ent.owner = IsValid(attacker) and attacker or ent
	ent:SetNoDraw(true)
	ent:SetNotSolid(true)

	if cfg.fire > 0 then
		hg.PropExplosion(ent, "Fire", cfg.distance * FIRE_FORCE_PER_DISTANCE, FIRE_PROP_MASS, {
			DamageMul = 10,
			MaxDistance = cfg.distance,
			MaxDamage = cfg.damage,
			FireBoost = cfg.fire,
			ShrapnelMul = 0
		})
	else
		hg.PropExplosion(ent, "Normal", cfg.distance * NORMAL_FORCE_PER_DISTANCE, 0, {DamageMul = 10})
	end

	if cfg.shrapnel > 0 then
		hg.BombShrapnel(pos, attacker, cfg.shrapnel, cfg.shrapnelDamage)
	end
end
