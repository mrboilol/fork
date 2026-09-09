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
		hg.organism.AmputateLimb(org, ({"larm", "rarm", "lleg", "rleg"})[math.random(4)])
	end
	if ply:HasTrait("john") then org.brain = math.max(org.brain or 0, 0.5) end
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

hook.Add("EntityTakeDamage", "HGTraitsKnockdown", function(target, dmgInfo)
	if not IsValid(target) or not target:IsPlayer() or not target.organism then return end
	if target:HasTrait("wimp") then target.organism.shock = math.min((target.organism.shock or 0) + dmgInfo:GetDamage() * 0.5, 95) end
	if target:HasTrait("pushover") and dmgInfo:GetDamage() > 1 and math.Rand(0, 1) < math.Clamp(dmgInfo:GetDamage() / 80, 0.04, 0.45) then target.organism.needfake = true end
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
