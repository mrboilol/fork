local function GiveRandomSupplies(ply, org)
	if org.HGPreparedGiven then return end
	org.HGPreparedGiven = true
	local supplies = {
		"weapon_bandage_sh", "weapon_bigbandage_sh", "weapon_medkit_sh", "weapon_bloodbag",
		"weapon_hammer", "weapon_hatchet", "weapon_hg_crowbar", "weapon_combatknife", "weapon_hg_bottle"
	}
	for _ = 1, 3 do
		ply:Give(table.remove(supplies, math.random(#supplies)))
	end
end

local function ApplySpawnTraits(ply)
	if not IsValid(ply) or not ply:Alive() or not ply.organism then return end
	local org = ply.organism
	if ply:HasTrait("paraplegic") then org.spine1 = math.max(org.spine1 or 0, hg.organism.fake_spine1 or 1) end
	if ply:HasTrait("blind") then
		org.eyeL = 1
		org.eyeR = 1
	end
	if ply:HasTrait("naturally_hypertensive") then
		org.hypertension = math.max(org.hypertension or 0, 0.7)
		if not org.HGHypertensionDefib then
			org.HGHypertensionDefib = true
			ply:Give("weapon_defibrillator")
		end
	end
	if ply:HasTrait("frail") and not org.HGFrailSupplies then
		org.HGFrailSupplies = true
		ply:Give("weapon_medkit_sh")
	end
	if ply:HasTrait("hemolytic_anemia") and not org.HGHemolyticBloodBag then
		org.HGHemolyticBloodBag = true
		ply:Give("weapon_bloodbag")
	end
	if ply:HasTrait("prepared") then GiveRandomSupplies(ply, org) end
	if ply:HasTrait("amputee") and not org.HGAmputeeApplied then
		org.HGAmputeeApplied = true
		local limbs = hg.Traits.GetSpawnAmputationLimbPool(ply)
		hg.organism.SetMissingLimb(org, limbs[math.random(#limbs)])
	end
	if ply:HasTrait("john") then org.brain = math.max(org.brain or 0, 0.05) end
end

hook.Add("PlayerSpawn", "HGTraitsSpawnEffects", function(ply)
	ply.HGTraitsSpawnPending = true
	timer.Simple(0.5, function()
		ApplySpawnTraits(ply)
		if IsValid(ply) then ply.HGTraitsSpawnPending = nil end
	end)
end)

hook.Add("HGTraitsChanged", "HGTraitsApplySpawnSelection", function(ply)
	if ply.HGTraitsSpawnPending then ApplySpawnTraits(ply) end
end)

hook.Add("Org Think", "HGTraitsPhysiology", function(owner, org, timeValue)
	if not IsValid(owner) or not owner:IsPlayer() then return end
	if owner:HasTrait("hemolytic_anemia") or owner:HasTrait("john") then org.blood = math.max((org.blood or 0) - timeValue * 0.35, 0) end
	if owner:HasTrait("naturally_hypertensive") then org.hypertension = math.max(org.hypertension or 0, 0.7) end
	org.conditionResistanceMul = owner:HasTrait("biologically_efficient") and 0.7 or 1
	if owner:HasTrait("biologically_efficient") then
		if (org.heartstop or org.fibrillation or (org.arrhythmia or 0) > 0.65) and math.Rand(0, 1) < timeValue * 0.012 then
			org.heartstop = false
			org.fibrillation = false
			org.arrhythmia = math.max((org.arrhythmia or 0) - 0.45, 0)
			org.heartStrain = math.max((org.heartStrain or 0) - 0.2, 0)
		end
	end
end)

local function TryClumsyWeaponDrop(ply, chance)
	if (ply.HGClumsyWeaponDropNext or 0) > CurTime() or math.Rand(0, 1) > chance then return false end
	local weapon = ply:GetActiveWeapon()
	if not IsValid(weapon) or weapon.NoDrop then return false end

	ply.HGClumsyWeaponDropNext = CurTime() + 1.25
	timer.Simple(0, function()
		if IsValid(ply) and ply:GetActiveWeapon() == weapon then hook.Run("PlayerDropWeapon", ply, weapon) end
	end)
	return true
end

hook.Add("EntityTakeDamage", "HGTraitsKnockdown", function(target, dmgInfo)
	if not IsValid(target) or not target:IsPlayer() or not target.organism then return end
	if target:HasTrait("wimp") then target.organism.shock = math.min((target.organism.shock or 0) + dmgInfo:GetDamage() * 0.5, 95) end
	if target:HasTrait("pushover") and dmgInfo:GetDamage() > 1 and math.Rand(0, 1) < math.Clamp(dmgInfo:GetDamage() / 80, 0.04, 0.45) then target.organism.needfake = true end
	if target:HasTrait("clumsy") and dmgInfo:GetDamage() > 4 and dmgInfo:IsDamageType(DMG_CRUSH + DMG_FALL) and math.Rand(0, 1) < math.Clamp(dmgInfo:GetDamage() / 55, 0.16, 0.6) then target.organism.needfake = true end

	local attacker = dmgInfo:GetAttacker()
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker == target or not attacker:HasTrait("clumsy") then return end
	if dmgInfo:GetDamage() <= 0 or not dmgInfo:IsDamageType(DMG_CLUB + DMG_SLASH) then return end
	local weapon = attacker:GetActiveWeapon()
	if IsValid(weapon) and (weapon.ismelee2 or ishgweapon(weapon)) then TryClumsyWeaponDrop(attacker, 0.32) end
end)

hook.Add("EntityFireBullets", "HGTraitsClumsyGunfire", function(ent, bullet)
	local ply = IsValid(ent) and (ent:IsPlayer() and ent or ent.GetOwner and ent:GetOwner())
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not ply:HasTrait("clumsy") then return end
	if (ply.HGClumsyGunfireNext or 0) > CurTime() or math.Rand(0, 1) > 0.28 then return end

	ply.HGClumsyGunfireNext = CurTime() + 0.55
	if isvector(bullet.Dir) then bullet.Dir = (bullet.Dir + VectorRand() * math.Rand(0.04, 0.12)):GetNormalized() end

	TryClumsyWeaponDrop(ply, 0.35)
end)

hook.Add("PlayerSay", "HGTraitsJohn", function(speaker, text)
	if string.lower(string.Trim(text or "")) != "john koller tames" then
		if speaker:HasTrait("john") then return text .. " :3" end
		return
	end
	for _, ply in player.Iterator() do
		if ply:Alive() and ply:HasTrait("john") and ply:GetPos():DistToSqr(speaker:GetPos()) <= 600 * 600 then
			local dmg = DamageInfo()
			dmg:SetDamage(10000)
			dmg:SetDamageType(DMG_BLAST)
			dmg:SetAttacker(speaker)
			dmg:SetInflictor(speaker)
			ply:TakeDamageInfo(dmg)
		end
	end
end)
