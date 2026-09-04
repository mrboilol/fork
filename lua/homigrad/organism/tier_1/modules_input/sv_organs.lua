--local Organism = hg.organism
local function isCrush(dmgInfo)
	return not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_SLASH + DMG_BLAST)
end

local function damageOrgan(org, dmg, dmgInfo, key)
	dmg = dmg / math.max(org.organStrengthMul or 1, 1)
	local prot = math.max(0.3 - org[key],0)
	local oldval = org[key]
	org[key] = math.Round(math.min(org[key] + dmg * (isCrush(dmgInfo) and 1 or 3), 1), 3)
	
	//local damage = org[key] - oldval
	//dmgInfo:SetDamage(dmgInfo:GetDamage() + (damage * 5))

	dmgInfo:ScaleDamage(0.8)

	return 0//isCrush(dmgInfo) and 0 or prot
end

local input_list = hg.organism.input_list
local hitArtery
local function addPain(org, amount, region)
	if hg.organism.AddPain then return hg.organism.AddPain(org, amount, region) end
	org.painadd = math.min((org.painadd or 0) + amount, 150)
	return amount
end
local function addInternalBleed(org, amount, organ)
	if amount <= 0 then return end
	org.internalBleed = org.internalBleed + amount
end

local organTraumaMul = {
	heart = 1.35,
	liver = 1.15,
	lungsL = 1.1,
	lungsR = 1.1,
	trachea = 1.2,
	brain = 1.45,
	stomach = 0.85,
	intestines = 0.8,
}

local function traumaDirection(org, dmgInfo)
	local force = dmgInfo:GetDamageForce()
	if isvector(force) and force:LengthSqr() > 1 then return force:GetNormalized() end

	local owner = org.owner
	local attacker = dmgInfo:GetAttacker()
	if IsValid(owner) and IsValid(attacker) then
		local direction = owner:WorldSpaceCenter() - attacker:WorldSpaceCenter()
		if direction:LengthSqr() > 1 then return direction:GetNormalized() end
	end

	return vector_up
end

local function applyOrganTrauma(org, dmgInfo, force, delta, previousDamage, organ)
	if not org.stamina or not org.stamina[1] then return end

	local mul = organTraumaMul[organ] or 1
	local freshDamage = math.max(delta or 0, 0)
	local priorDamage = math.Clamp(previousDamage or 0, 0, 1)
	local rawForce = math.max(force or 0, 0)
	local repeatThreshold = 0.9 + priorDamage * 1.35
	local repeatHit = freshDamage <= 0.001 and rawForce >= repeatThreshold
	if freshDamage <= 0.001 and not repeatHit then return end

	local staminaMax = math.max(org.stamina.max or 180, 1)
	local staminaLoss = (freshDamage * 34 + rawForce * 4) * mul
	if repeatHit then staminaLoss = staminaLoss * 0.3 end
	org.stamina[1] = math.max(org.stamina[1] - math.min(staminaLoss, staminaMax * 0.45), 0)

	local severity = freshDamage * 1.8 + math.max(rawForce - repeatThreshold * 0.45, 0) * 0.32
	if repeatHit then severity = severity * 0.45 end
	if severity >= 0.9 and org.isPly and hg.QueuePainScream then
		hg.QueuePainScream(org.owner, math.Clamp(severity, 0.8, 1.6))
	end
	if severity <= 0.35 or org.NoKnockdown then return end

	local resistance = 1 + priorDamage * 1.6
	local chance = math.Clamp((severity - 0.35) * 0.22 / resistance, 0, freshDamage > 0.35 and 0.58 or 0.3)
	if math.Rand(0, 1) > chance then return end

	local owner = org.owner
	if not IsValid(owner) or not owner:Alive() or org.otrub or org.needotrub then return end
	if (org.traumaReactionAt or 0) > CurTime() then return end
	org.traumaReactionAt = CurTime() + 0.35

	local direction = traumaDirection(org, dmgInfo)
	owner:SetVelocity(direction * math.Clamp(75 + severity * 90, 75, 300) + vector_up * math.Clamp(20 + severity * 35, 20, 140))
	addPain(org, severity * 9, string.StartWith(organ or "", "brain") and "head" or "body")

	if repeatHit and math.Rand(0, 1) < math.Clamp((rawForce - repeatThreshold) * 0.08, 0, 0.25) then
		addInternalBleed(org, math.min(rawForce * 0.12, 0.8), organ)
	end

	if severity >= 1.7 and math.Rand(0, 1) < math.Clamp((severity - 1.5) * 0.16 / resistance, 0, 0.35) then
		org.needotrub = true
	else
		org.needfake = true
	end
end

hg.organism.ApplyOrganTrauma = applyOrganTrauma

input_list.heart = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact)
	local oldDmg = org.heart

	local result = damageOrgan(org, dmg * 0.3, dmgInfo, "heart")
	local delta = org.heart - oldDmg

	hg.AddHarmToAttacker(dmgInfo, delta * 10, "Heart damage harm")
	
	if delta > 0 then
		org.shock = org.shock + dmg * 20
		addPain(org, dmg * 18, "body")
	end
	addInternalBleed(org, delta * 10, "heart")
	applyOrganTrauma(org, dmgInfo, dmg, delta, oldDmg, "heart")
	org.heartStrain = math.Clamp((org.heartStrain or 0) + delta * 1.4, 0, 1)
	if hg.organism.AddCardiacStress then hg.organism.AddCardiacStress(org, delta * (dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and 2.4 or 1.2)) end
	if delta > 0.08 and dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_SLASH) and math.Rand(0, 1) < math.Clamp(delta * 1.8, 0, 0.75) then
		hg.organism.StartFibrillation(org)
	end
	if delta > 0 and (org.aorta or 0) < 1 and math.Rand(0, 1) < math.Clamp(0.18 + delta * 0.7, 0.18, 0.72) then
		local arteryDir = isvector(dir) and dir:LengthSqr() > 0.001 and dir or traumaDirection(org, dmgInfo)
		hitArtery("aorta", org, math.max(dmg, 0.2), dmgInfo, boneindex or "ValveBiped.Bip01_Spine2", arteryDir, hit, impact, true)
	end

	return result
end

input_list.liver = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.liver
	local prot = math.max(0.3 - org.liver,0)
	
	hg.AddHarmToAttacker(dmgInfo, (org.liver - oldDmg) * 3, "Liver damage harm")
	
	org.liver = math.min(org.liver + dmg, 1)
	local harmed = (org.liver - oldDmg)
	if harmed > 0 then
		org.shock = org.shock + dmg * 20
		addPain(org, dmg * 35, "body")
	end
	if org.analgesia < 0.4 and harmed >= 0.2 then
		timer.Simple(0, function()
			if harmed > 0 then -- wtf? whatever
				hg.StunPlayer(org.owner,2)
			else
				hg.LightStunPlayer(org.owner,2)
			end
		end)
	end

	addInternalBleed(org, harmed * 4, "liver")
	applyOrganTrauma(org, dmgInfo, dmg, harmed, oldDmg, "liver")
	
	dmgInfo:ScaleDamage(0.8)

	return 0
end

input_list.stomach = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.stomach

	local result = damageOrgan(org, dmg, dmgInfo, "stomach")

	hg.AddHarmToAttacker(dmgInfo, (org.stomach - oldDmg) * 2, "Stomach damage harm")

	local delta = org.stomach - oldDmg
	if delta > 0 then
		addPain(org, dmg * 3, "body")
		org.shock = org.shock + dmg * 1.5
	end
	addInternalBleed(org, delta * 2, "stomach")
	applyOrganTrauma(org, dmgInfo, dmg, delta, oldDmg, "stomach")
	return result
end

input_list.intestines = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.intestines

	local result = damageOrgan(org, dmg, dmgInfo, "intestines")

	hg.AddHarmToAttacker(dmgInfo, (org.intestines - oldDmg) * 2, "Intestines damage harm")

	local delta = org.intestines - oldDmg
	if delta > 0 then
		addPain(org, dmg * 2, "body")
		org.shock = org.shock + dmg
	end
	addInternalBleed(org, delta * 2, "intestines")
	applyOrganTrauma(org, dmgInfo, dmg, delta, oldDmg, "intestines")
	return result
end

local brainLobeProfiles = {
	brainFrontal = {brain = 0.8, consciousness = 1.2, disorientation = 1.5, shock = 2, pain = 7, hemorrhage = 0.6},
	brainParietal = {brain = 0.7, consciousness = 1.4, disorientation = 2.2, shock = 2.5, pain = 8, hemorrhage = 0.7},
	brainTemporal = {brain = 0.9, consciousness = 1.1, disorientation = 1.3, shock = 2.5, pain = 8, hemorrhage = 0.9},
	brainOccipital = {brain = 0.75, consciousness = 1.3, disorientation = 1.1, shock = 2, pain = 7, hemorrhage = 0.75}
}

local function getBrainLobeDamage(org)
	return math.min(org.brainFrontal or 0, 0.2) + math.min(org.brainParietal or 0, 0.2) + math.min(org.brainTemporal or 0, 0.2) + math.min(org.brainOccipital or 0, 0.2)
end

local function addBrainHemorrhage(org, amount, rate)
	org.brainHemorrhage = math.min((org.brainHemorrhage or 0) + amount, 1)
	org.brainBleedRate = math.min((org.brainBleedRate or 0) + (rate or amount * 0.0015), 0.008)
end

hg.organism.AddBrainHemorrhage = addBrainHemorrhage

local function damageBrainLobe(org, bone, dmg, dmgInfo, key)
	local profile = brainLobeProfiles[key]
	if not profile then return 0 end
	if dmgInfo:IsDamageType(DMG_BLAST) then dmg = dmg / 50 end
	if dmgInfo:IsDamageType(DMG_CLUB) then
		local intactSkull = math.Clamp(1 - (org.skull or 0) / 0.7, 0, 1)
		dmg = dmg / 3 * Lerp(intactSkull, 1, 0.75)
	end

	local oldBrainLobeDamage = getBrainLobeDamage(org)
	local oldDmg = org[key] or 0
	local result = damageOrgan(org, dmg, dmgInfo, key)
	local delta = (org[key] or 0) - oldDmg

	org.brain = math.min((org.brain or 0) + (getBrainLobeDamage(org) - oldBrainLobeDamage) * 1.5, 1)
	org.consciousness = math.Approach(org.consciousness, 0, delta * profile.consciousness)
	org.disorientation = org.disorientation + delta * profile.disorientation
	if hg.organism.module.concussion and hg.organism.module.concussion.AddHeadTrauma then
		hg.organism.module.concussion.AddHeadTrauma(org, 0, delta, dmg, dmgInfo)
	end
	if delta > 0 then
		org.shock = org.shock + dmg * profile.shock
		addPain(org, dmg * profile.pain, "head")
	end
	applyOrganTrauma(org, dmgInfo, dmg, delta, oldDmg, "brain")

	hg.AddHarmToAttacker(dmgInfo, delta * 15, key .. " damage harm")

	local penetrating = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
	local impact = dmgInfo:IsDamageType(DMG_CLUB + DMG_BLAST + DMG_CRUSH)
	local hemorrhageChance = penetrating and math.Clamp(0.3 + delta * 1.6, 0, 0.95) or impact and math.Clamp(0.04 + delta * profile.hemorrhage, 0, 0.65) or 0.02
	if delta > 0 and math.Rand(0, 1) <= hemorrhageChance then
		addBrainHemorrhage(org, delta * profile.hemorrhage, delta * (penetrating and 0.003 or 0.0012))
	end

	if key == "brainTemporal" and delta > 0.02 and math.random(2) == 1 and IsValid(org.owner) and org.owner.AddTinnitus then
		org.owner:AddTinnitus(math.Clamp(delta * 35, 1.5, 12), true)
	end

	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
		local dmgPos = dmgInfo:GetDamagePosition()
		local dirCool = dmgInfo:GetDamageForce():GetNormalized()
		local effdata = EffectData()
		effdata:SetOrigin(dmgPos)
		effdata:SetRadius(dmg / 10)
		effdata:SetMagnitude(dmg / 10)
		effdata:SetScale(1)
		util.Effect("BloodImpact", effdata)

		local ent = hg.GetCurrentCharacter(org.owner)
		if IsValid(ent) and ent.organism and not ent.organism.SpawnedBrainChunks and math.random(5) == 1 then
			SpawnMeatGore(ent, dmgPos + dirCool * 5, 3, dirCool * 1000, 0.4)
			ent.organism.SpawnedBrainChunks = true
		end
	end

	if org.brain >= 0.01 and delta > 0.01 and math.random(3) == 1 then
		org.shock = 70
	end

	return result
end

input_list.brainFrontal = function(org, bone, dmg, dmgInfo) return damageBrainLobe(org, bone, dmg, dmgInfo, "brainFrontal") end
input_list.brainParietal = function(org, bone, dmg, dmgInfo) return damageBrainLobe(org, bone, dmg, dmgInfo, "brainParietal") end
input_list.brainTemporal = function(org, bone, dmg, dmgInfo) return damageBrainLobe(org, bone, dmg, dmgInfo, "brainTemporal") end
input_list.brainOccipital = function(org, bone, dmg, dmgInfo) return damageBrainLobe(org, bone, dmg, dmgInfo, "brainOccipital") end
input_list.brain = input_list.brainFrontal

hook.Add("HomigradDamage", "BrainHemorrhageTrauma", function(ply, dmgInfo, hitgroup)
	local org = ply.organism
	if not org or hitgroup ~= HITGROUP_HEAD or not org.skull then return end
	if org.skull < 0.7 then return end

	local chance = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and 0.28 or dmgInfo:IsDamageType(DMG_CLUB + DMG_BLAST + DMG_CRUSH) and 0.14 or 0
	chance = chance + math.max(org.skull - 0.7, 0) * 0.5
	if math.Rand(0, 1) <= chance then
		addBrainHemorrhage(org, math.Rand(0.015, 0.05), math.Rand(0.0002, 0.001))
	end
end)

local angZero = Angle(0, 0, 0)
local vecZero = Vector(0, 0, 0)
local function getWoundBody(owner, hitEnt)
	if IsValid(hitEnt) then return hitEnt end
	if not IsValid(owner) then return end

	local rag = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll
		or owner.GetNWEntity and owner:GetNWEntity("FakeRagdoll")
	if IsValid(rag) then return rag end

	rag = IsValid(owner.RagdollDeath) and owner.RagdollDeath
		or owner.GetNWEntity and owner:GetNWEntity("RagdollDeath")
	return IsValid(rag) and rag or owner
end

local function getlocalshit(owner, hitEnt, bone, dir, hit)
	local ent = getWoundBody(owner, hitEnt)
	if not IsValid(ent) then return end

	local boneID = isnumber(bone) and bone or ent:LookupBone(bone or "")
	if not boneID or boneID < 0 then return end

	local mat = ent:GetBoneMatrix(boneID)
	if not mat then return end
	local bonePos, boneAng = mat:GetTranslation(), mat:GetAngles()
	local dmgPos = isvector(hit) and hit or bonePos
	local localPos, localAng = WorldToLocal(dmgPos, angZero, bonePos, boneAng)
	local _, dir2 = WorldToLocal(vecZero, dir:Angle(), vecZero, boneAng)
	return localPos, localAng, dir2:Forward(), ent:GetBoneName(boneID)
end

local function emitArterialImpact(owner, wound)
	if not IsValid(owner) or not wound then return end
	local body = getWoundBody(owner)
	if not IsValid(body) then return end
	local bone = body:LookupBone(wound[4] or "")
	local matrix = bone and bone >= 0 and body:GetBoneMatrix(bone)
	local pos, normal = body:WorldSpaceCenter(), vector_up
	if matrix then
		pos = LocalToWorld(wound[2] or vector_origin, wound[3] or angle_zero, matrix:GetTranslation(), matrix:GetAngles())
		normal = matrix:GetAngles():Forward()
	end

	local effect = EffectData()
	effect:SetOrigin(pos)
	effect:SetNormal(normal)
	effect:SetMagnitude(2)
	effect:SetScale(1.2)
	effect:SetRadius(3)
	util.Effect("BloodImpact", effect, true, true)
end

local arterySize = {
	["arteria"] = 14,
	["rarmartery"] = 6,
	["larmartery"] = 6,
	["rlegartery"] = 9,
	["llegartery"] = 9,
	["aorta"] = 18,
}

local arteryMessages ={
	"I can feel blood rushing from my neck...",
	"My neck.. it's... pumping out blood.",
	"I'm bleeding out of my neck!"
}

local slashToArtery = {
	["rarmup"] = "rarmartery",
	["rarmdown"] = "rarmartery",
	["larmup"] = "larmartery",
	["larmdown"] = "larmartery",
	["rlegup"] = "rlegartery",
	["rlegdown"] = "rlegartery",
	["llegup"] = "llegartery",
	["llegdown"] = "llegartery",
}

local function getArteryChanceMul(dmgInfo)
	local inflictor = dmgInfo:GetInflictor()
	return IsValid(inflictor) and inflictor.ArteryChance or 1
end

local function getStaminaMul(dmgInfo)
	local att = dmgInfo:GetAttacker()
	if IsValid(att) and att.organism and att.organism.stamina then
		local stamina = att.organism.stamina
		return math.max(stamina[1] / stamina.max, 0.1)
	end
	return 1
end

hitArtery = function(artery, org, dmg, dmgInfo, boneindex, dir, hit, impact, forceRupture)
	if not forceRupture and (isCrush(dmgInfo) or dmgInfo:IsDamageType(DMG_BLAST)) then
		local ruptureChance = math.Clamp((dmg - 0.35) * 0.45, 0, 0.75)
		if ruptureChance <= 0 or math.Rand(0, 1) > ruptureChance then return 1 end
	end
	local arteryResistance = math.max(org.arteryResistanceMul or 1, 1)
	if arteryResistance > 1 and math.Rand(0, 1) > 1 / arteryResistance then return 1 end
	dmg = dmg / arteryResistance
	if dmgInfo:IsDamageType(DMG_SLASH) and dmg < 2 then
		local staminaMul = getStaminaMul(dmgInfo)
		local arteryChanceMul = getArteryChanceMul(dmgInfo)
		local arteryChance = arteryChanceMul >= 2 and 1 or math.Clamp(0.45 * arteryChanceMul * staminaMul, 0, 1)

		if math.Rand(0, 1) > arteryChance then
			-- Didn't fully cut through, maybe just a scratch
			local scratchChance = 0.2 + 0.3 * staminaMul
			if math.Rand(0, 1) < scratchChance then
				addPain(org, dmg * 0.3, artery == "arteria" and "head" or (artery == "llegartery" or artery == "rlegartery") and "lower" or "body")
				if artery == "arteria" and org.isPly and IsValid(org.owner) then
					org.owner:Notify("My neck got scratched!", true, "arteria", 0)
				end
			end
			return
		end
	end
	addPain(org, dmg + 45, artery == "arteria" and "head" or (artery == "llegartery" or artery == "rlegartery") and "lower" or "body")
	org.shock = math.min(org.shock + 15, 95)
	org.fearadd = math.min(org.fearadd + 1.5, 3)
	hg.organism.AddPanicAttack(org, math.max(0.9 - (org.panicattackadd or 0), 0), false, false, true)
	local arteryDamage = tonumber(org[artery]) or 0
	if arteryDamage >= 1 then return 0 end
	if org[string.Replace(artery, "artery", "").."amputated"] then return end

	if artery == "aorta" then
		hg.AddHarmToAttacker(dmgInfo, 18, "Aorta punctured harm")
	elseif artery ~= "arteria" then
		hg.AddHarmToAttacker(dmgInfo, 4, "Random artery punctured harm")//((1 - org[artery]) - math.max((1 - org[artery]) - dmg,0)) / 4
	else
		if org.isPly and not org.otrub then
			org.owner:Notify(table.Random(arteryMessages), true, "arteria", 0)
		end
		
		hg.AddHarmToAttacker(dmgInfo, 15, "Carotid artery punctured harm")
		org.neckslit = true
		org.needfake = true
	end

	org[artery] = math.min(arteryDamage + 1, 1)

	local owner = org.owner

	if artery == "arteria" and IsValid(owner) then
		local ent = hg.GetCurrentCharacter(owner)
		if IsValid(ent) and not org.otrub and not org.needotrub and (owner:IsPlayer() and owner:Alive() or not owner:IsPlayer()) then
			ent:EmitSound("neckslit.ogg", 70, 100, 1, CHAN_AUTO)
		end

		local snd = (ThatPlyIsFemale and ThatPlyIsFemale(owner)) and "femaleneck.mp3" or "maleneck.mp3"
		timer.Simple(0, function()
			if IsValid(owner) then
				if owner:IsPlayer() and owner:Alive() then
					hg.Fake(owner, nil, true, true)
				end
				local rag = hg.GetCurrentCharacter(owner)
				if IsValid(rag) and not org.otrub and not org.needotrub and (owner:IsPlayer() and owner:Alive() or not owner:IsPlayer()) then
					rag:EmitSound(snd, 70, 100, 1, CHAN_VOICE)
					org.neckslitSoundName = snd
					org.neckslitSoundEnt = rag
				end
			end
		end)
	end

	local hitEnt = impact and impact.entity
	local localPos, localAng, dir2, woundBone = getlocalshit(owner, hitEnt, boneindex, dir, hit)
	if not localPos then
		localPos, localAng, dir2 = vecZero, angZero, Vector(-1, 0, 0)
	end
	local wound = {arterySize[artery], localPos, localAng, woundBone or boneindex, CurTime(), dir2 * 100, artery}
	wound.visualBleedRate = math.max((arterySize[artery] or 6) * 4.5, 1)
	table.insert(org.arterialwounds, wound)
	hg.organism.MarkArterialWoundsNetDirty(org)
	emitArterialImpact(owner, wound)
	--if IsValid(owner:GetNWEntity("RagdollDeath")) then owner:GetNWEntity("RagdollDeath"):SetNetVar("wounds",org.arterialwounds) end
	return 0
end

hook.Add("PreTraceOrganBulletDamage", "hg_melee_artery_chance", function(org, bone, dmg, dmgInfo, box, dir, hit, ricochet, organ, hookInfo, impact)
	if not dmgInfo:IsDamageType(DMG_SLASH) then return end

	local artery = organ and slashToArtery[organ[1]]
	if not artery then return end
	if getArteryChanceMul(dmgInfo) <= 1 then return end

	local arteryChance = math.Clamp(getArteryChanceMul(dmgInfo) - 1, 0, 1)
	if math.Rand(0, 1) > arteryChance then return end

	hitArtery(artery, org, dmg, dmgInfo, box[6], dir, hit, impact)
end)

input_list.arteria = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact)
	return hitArtery("arteria", org, dmg, dmgInfo, "ValveBiped.Bip01_Neck1", dir, hit, impact)
end

input_list.rarmartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact) return hitArtery("rarmartery", org, dmg, dmgInfo, boneindex, dir, hit, impact) end
input_list.larmartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact) return hitArtery("larmartery", org, dmg, dmgInfo, boneindex, dir, hit, impact) end
input_list.rlegartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact) return hitArtery("rlegartery", org, dmg, dmgInfo, boneindex, dir, hit, impact) end
input_list.llegartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact) return hitArtery("llegartery", org, dmg, dmgInfo, boneindex, dir, hit, impact) end
input_list.aorta = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact) return hitArtery("aorta", org, dmg, dmgInfo, boneindex, dir, hit, impact) end
input_list.eyeL = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.eyeL or 0
	dmg = dmg * 0.75
	org.eyeL = math.min((org.eyeL or 0) + dmg, 1)

	hg.AddHarmToAttacker(dmgInfo, dmg * 5, "Left eye damage harm")
	addPain(org, dmg * 20, "head")
	org.shock = org.shock + dmg * 10

	dmgInfo:ScaleDamage(0.8)
	return 0
end

input_list.eyeR = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.eyeR or 0
	dmg = dmg * 0.75
	org.eyeR = math.min((org.eyeR or 0) + dmg, 1)

	hg.AddHarmToAttacker(dmgInfo, dmg * 5, "Right eye damage harm")
	addPain(org, dmg * 20, "head")
	org.shock = org.shock + dmg * 10

	dmgInfo:ScaleDamage(0.8)
	return 0
end

input_list.lungsL = function(org, bone, dmg, dmgInfo)
	local prot = math.max(0.3 - org.lungsL[1],0)
	local oldval = org.lungsL[1]

	hg.AddHarmToAttacker(dmgInfo, (dmg * 0.25), "Lung left damage harm")

	org.lungsL[1] = math.min(org.lungsL[1] + dmg / 4 / math.max(org.organStrengthMul or 1, 1), 1)
	if (dmgInfo:IsDamageType(DMG_BULLET+DMG_SLASH+DMG_BUCKSHOT)) or (math.random(3) == 1) then org.lungsL[2] = math.min(org.lungsL[2] + dmg / math.max(org.organStrengthMul or 1, 1), 1) end

	addInternalBleed(org, (org.lungsL[1] - oldval) * 2, "lungsL")
	applyOrganTrauma(org, dmgInfo, dmg, org.lungsL[1] - oldval, oldval, "lungsL")
	
	dmgInfo:ScaleDamage(0.8)

	return 0//isCrush(dmgInfo) and 1 or prot
end

input_list.lungsR = function(org, bone, dmg, dmgInfo)
	local oldval = org.lungsR[1]

	hg.AddHarmToAttacker(dmgInfo, (dmg * 0.25), "Lung right damage harm")

	org.lungsR[1] = math.min(org.lungsR[1] + dmg / 4 / math.max(org.organStrengthMul or 1, 1), 1)
	if (dmgInfo:IsDamageType(DMG_BULLET+DMG_SLASH+DMG_BUCKSHOT)) or (math.random(3) == 1) then org.lungsR[2] = math.min(org.lungsR[2] + dmg / math.max(org.organStrengthMul or 1, 1), 1) end

	addInternalBleed(org, (org.lungsR[1] - oldval) * 2, "lungsR")
	applyOrganTrauma(org, dmgInfo, dmg, org.lungsR[1] - oldval, oldval, "lungsR")

	dmgInfo:ScaleDamage(0.8)

	return 0//isCrush(dmgInfo) and 1 or prot
end

input_list.trachea = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.trachea

	if dmgInfo:IsDamageType(DMG_BLAST) then dmg = dmg / 5 end

	local result = damageOrgan(org, dmg * 2, dmgInfo, "trachea")

	hg.AddHarmToAttacker(dmgInfo, (org.trachea - oldDmg) * 8, "Trachea damage harm")
	applyOrganTrauma(org, dmgInfo, dmg, org.trachea - oldDmg, oldDmg, "trachea")

	//org.internalBleed = org.internalBleed + dmg * 2

	return result
end
