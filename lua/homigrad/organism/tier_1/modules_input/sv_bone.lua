--local Organism = hg.organism
if SERVER then util.AddNetworkString("headtrauma_flash") end

local player_crush_amputation_threshold = 7

util.AddNetworkString("hg_play_client_sound_file")

local function isCrush(dmgInfo)
	return (not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST)) or dmgInfo:GetInflictor().RubberBullets
end

local function isMelee(dmgInfo)
	return dmgInfo:IsDamageType(DMG_SLASH + DMG_CLUB + DMG_GENERIC)
end

local halfValue2 = util.halfValue2
local function damageBone(org, bone, dmg, dmgInfo, key, boneindex, dir, hit, ricochet, nodmgchange)
	local crush = isCrush(dmgInfo)
	
	if dmgInfo:IsDamageType(DMG_SLASH) and dmg > 1.5 then
		//crush = false
	end
	
	local breakBoneMul = dmgInfo:GetInflictor().BreakBoneMul or 1
	if dmgInfo:IsDamageType(DMG_CLUB) then breakBoneMul = breakBoneMul * 0.8 end
	dmg = dmg * breakBoneMul / math.max(org.boneStrengthMul or 1, 1)
	
	if crush then
		crush = halfValue2(1 - org[key], 1, 0.5)
		dmg = dmg / math.max(6.5 * crush * (bone or 1), 1)
		if dmgInfo:GetInflictor().RubberBullets then dmg = dmg * dmgInfo:GetInflictor().Penetration end
	end

	local val = org[key]
	org[key] = math.min(org[key] + dmg, 1)
	local scale = 1 - (org[key] - val)
	
	if !nodmgchange then dmgInfo:ScaleDamage(1 - (crush and 1 * crush * math.max((1 - org[key]) ^ 0.1, 0.5) or (1 - org[key]) * (bone))) end

	return (crush and 1 * crush * math.max((1 - org[key]) ^ 0.1, 0.5) or (1 - org[key]) * (bone)), VectorRand(-0.2,0.2) / math.Clamp(dmg,0.4,0.8)
end

local bonefracture_sounds = {
	"bonefracture/rem_bonebreak1.wav",
	"bonefracture/rem_bonebreak2.wav",
	"bonefracture/rem_bonebreak3.wav",
}

local skullfracture_sounds = {
	"skullfracture/SkullFracture-1.wav",
	"skullfracture/SkullFracture-2.wav",
	"skullfracture/SkullFracture-3.wav",
	"skullfracture/SkullFracture-4.wav",
	"skullfracture/SkullFracture-5.wav",
	"skullfracture/SkullFracture-6.wav",
	"skullfracture/SkullFracture-7.wav",
}

local function playBoneFractureSound(ent)
	if not IsValid(ent) then return end
	local org = ent.organism
	local soundEnt = org and IsValid(org.forcedBoneBreakSoundEnt) and org.forcedBoneBreakSoundEnt or ent
	local recipient = org and org.forcedBoneBreakRecipient
	local filter
	if IsValid(recipient) and recipient:IsPlayer() then
		filter = RecipientFilter()
		filter:AddPAS(soundEnt:GetPos())
		filter:AddPlayer(recipient)
	end
	soundEnt:EmitSound(bonefracture_sounds[math.random(#bonefracture_sounds)], 75, math.random(135, 155), 1, CHAN_AUTO, 0, 0, filter)
end

local function playSkullFractureSound(ent)
	if not IsValid(ent) then return end
	ent:EmitSound(skullfracture_sounds[math.random(#skullfracture_sounds)], 75, math.random(90, 110), 1, CHAN_AUTO)
end

local huyasd = {
	["spine1"] = "I don't feel anything below my hips.",
	["spine2"] = "I cant't feel or move anything below my torso.",
	["spine3"] = "I can't move at all. I can barely even breathe.",
	["skull"] = "My head is aching.",
}

local broke_arm = {
	"AAAAH OH GOD, IT'S BROKEN! MY ARM! IT'S BROKEN!",
	"FUCK MY FUCKING ARM IS BROKEN!",
	"NONONO MY ARM IS BENT ALL WRONG!",
	"IT'S.. MY ARM.. SNAPPED- I HEARD IT SNAP!",
	"MY ARM IS NOT SUPPOSED TO BEND IN HALF!",
}

local dislocated_arm = {
	"MY ARM- GOD, IT'S POPPED OUT OF THE SOCKET!",
	"FUCK- THE SHOULDER'S JUST- HANGING LOOSE!",
	"MY ARM..! IT'S DISLOCATED! I CAN SEE THE BULGE WHERE IT'S WRONG!",
	"THE ARM'S JUST- DEAD WEIGHT- IT'S NOT ATTACHED RIGHT!",
	"SHIT! I CAN FEEL THE BONE OUT OF PLACE!",
}

local broke_leg = {
	"MY LEG- FUCK, IT'S BROKEN- I HEARD THE SNAP!",
	"FUCK! THE SHIN'S SNAPPED CLEAN THROUGH!",
	"THE KNEE'S WRONG- THE WHOLE LEG'S TWISTED WRONG!",
	"MY LEG..! IT'S JUST- HANGING BY MUSCLE AND SKIN!",
	"THE PAIN'S SHOOTING UP TO MY HIP- FUCK, IT'S BAD!",
	"I CAN'T MOVE MY FOOT- THE ANKLE'S BROKEN TOO!",
}

local dislocated_leg = {
	"MY LEG- FUCK, IT'S DISLOCATED AT THE KNEE!",
	"I CAN SEE THE KNEECAP IN THE WRONG PLACE!",
	"AGHH- THE HIP'S POPPED OUT- IT'S STUCK OUTWARD!",
	"IT'S BENT BACKWARD- THE KNEE SHOULDN'T BEND THIS WAY!",
	"FUCK! THE HIP'S DISLOCATED!",
	"THE ANKLE'S TWISTED- BUT THE KNEE'S THE REAL PROBLEM!",
}

local limbName = {
	rleg = "right leg",
	lleg = "left leg",
	rarm = "right arm",
	larm = "left arm",
}

local function hasNewThoughts(org)
	local owner = org.owner
	return org.isPly and IsValid(owner) and owner:IsPlayer() and owner:GetInfoNum("hg_newthoughts", 0) > 0
end

local function sendThought(org, msg, key, delay, clr)
	if hasNewThoughts(org) and org.owner.Notify then
		org.owner:Notify(msg, delay or 1, key, 0, nil, clr)
	end
end

local function addPain(org, amount, region)
	if hg.organism.AddPain then return hg.organism.AddPain(org, amount, region) end
	org.painadd = math.min((org.painadd or 0) + amount, 150)
	return amount
end

local function canFeelPain(org, region)
	return not hg.organism.CanFeelPain or hg.organism.CanFeelPain(org, region)
end

local function doDislocate(org, key, dmg, segment)
	if org[key.."dislocation"] then return false end
	org[key.."dislocation"] = true
	if hg.fakeBoneFlop then
		hg.fakeBoneFlop.SetLimbSegmentDislocation(org, key, segment, not org[key.."stabilized"])
	end

	local stabilized = org[key.."stabilized"]
	if not stabilized then
		addPain(org, 35, (key == "lleg" or key == "rleg") and "lower" or "body")
		org.immobilization = org.immobilization + dmg * 10
	else
		addPain(org, 10, (key == "lleg" or key == "rleg") and "lower" or "body")
		org.immobilization = org.immobilization + dmg * 3
	end
	org.owner:AddNaturalAdrenaline(0.5)
	org.fearadd = org.fearadd + 0.5

	if hasNewThoughts(org) then
		sendThought(org, "Your " .. limbName[key] .. " is dislocated.", "thought_dislocated" .. key, 1, Color(255, 220, 220))
	else
		org.owner:Notify((key == "rarm" or key == "larm") and dislocated_arm[math.random(#dislocated_arm)] or dislocated_leg[math.random(#dislocated_leg)], true, "dislocated" .. key, 2)
	end

	timer.Simple(0, function() hg.LightStunPlayer(org.owner,2) end)
	playBoneFractureSound(org.owner)
	if org.isPly and hg.QueuePainScream and canFeelPain(org, (key == "lleg" or key == "rleg") and "lower" or "body") then hg.QueuePainScream(org.owner, 1) end
	return true
end

function hg.TryDislocateLimb(org, key, segment, severity)
	if not org or not limbName[key] or org[key .. "amputated"] or org[key .. "upamputated"] then return false end
	if org[key .. "dislocation"] or (org[key] or 0) >= 1 then return false end

	severity = math.max(tonumber(severity) or 0, 0)
	if severity < 0.18 then return false end
	local chance = math.Clamp((severity - 0.15) * 0.72, 0.08, 0.82)
	if math.Rand(0, 1) > chance then return false end

	org[key] = math.min(math.max(org[key] or 0, severity * 0.38), 0.82)
	return doDislocate(org, key, severity, segment or "up")
end

local function legs(org, bone, dmg, dmgInfo, key, segment, boneindex, dir, hit, ricochet)
	local oldDmg = org[key]
	local dmg = dmg * 2.5
	local amputateThreshold = org.isPly and player_crush_amputation_threshold or 4

	if not org.NoDismembermentPhysics and dmgInfo:IsDamageType(DMG_CRUSH) and dmg > amputateThreshold and !org[key.."amputated"] then
		hg.organism.AmputateLimb(org, key)

		return 0
	end

	if org[key] == 1 then return 0 end

	local result, vecrand = damageBone(org, 0.3, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
	
	local dmg = org[key]

	org[key] = org[key] * 0.5

	if dmg < 0.5 then return 0 end
	if dmg < 1 and !dmgInfo:IsDamageType(DMG_CLUB+DMG_CRUSH+DMG_FALL) then
		if math.Rand(0, 1) >= 0.5 then return 0 end
		doDislocate(org, key, dmg, segment)
		hg.AddHarmToAttacker(dmgInfo, (org[key] - oldDmg) * 2, "Legs bone damage harm")
		return result, vecrand
	end

	if org.isPly and !org[key.."amputated"] then org.just_damaged_bone = CurTime() end

	local stabilized = org[key.."stabilized"]
	
	if dmg >= 1 and (!dmgInfo:IsDamageType(DMG_CLUB+DMG_CRUSH+DMG_FALL) or math.random(3) != 1) then
		org[key] = 1
		if hg.fakeBoneFlop then
			hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, not stabilized)
		end

		if not stabilized then
			addPain(org, 55, "lower")
			org.immobilization = org.immobilization + dmg * 25
		else
			addPain(org, 10, "lower")
			org.immobilization = org.immobilization + dmg * 5
		end
		org.owner:AddNaturalAdrenaline(1)
		org.fearadd = org.fearadd + 0.5

		if hasNewThoughts(org) then
			sendThought(org, "Your " .. limbName[key] .. " is broken.", "thought_broke" .. key, 1, Color(255, 210, 210))
		else
			org.owner:Notify(broke_leg[math.random(#broke_leg)], true, "broke" .. key, 2)
		end

		timer.Simple(0, function() hg.LightStunPlayer(org.owner,2) end)
		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream and canFeelPain(org, "lower") then hg.QueuePainScream(org.owner, 1.35) end
	else
		doDislocate(org, key, dmg, segment)
	end

	hg.AddHarmToAttacker(dmgInfo, (org[key] - oldDmg) * 2, "Legs bone damage harm")

	return result, vecrand
end

local function arms(org, bone, dmg, dmgInfo, key, segment, boneindex, dir, hit, ricochet)
	local oldDmg = org[key]
	local dmg = dmg * 2.5
	local amputateThreshold = org.isPly and player_crush_amputation_threshold or 4
	
	if not org.NoDismembermentPhysics and dmgInfo:IsDamageType(DMG_CRUSH) and dmg > amputateThreshold and !org[key.."amputated"] then
		hg.organism.AmputateLimb(org, key)

		return 0
	end

	if org[key] == 1 then return 0 end

	local result, vecrand = damageBone(org, 0.3, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
	
	local dmg = org[key]
	
	org[key] = org[key] * 0.5

	if dmg < 0.5 then return 0 end
	if dmg < 1 and !dmgInfo:IsDamageType(DMG_CLUB+DMG_CRUSH+DMG_FALL) then
		if math.Rand(0, 1) >= 0.5 then return 0 end
		doDislocate(org, key, dmg, segment)
		hg.AddHarmToAttacker(dmgInfo, (org[key] - oldDmg) * 1.5, "Arms bone damage harm")
		return result, vecrand
	end

	if org.isPly and !org[key.."amputated"] then org.just_damaged_bone = CurTime() end

	local stabilized = org[key.."stabilized"]
	
	if dmg >= 1 and (!dmgInfo:IsDamageType(DMG_CLUB+DMG_CRUSH+DMG_FALL) or math.random(3) != 1) then
		org[key] = 1
		if hg.fakeBoneFlop then
			hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, not stabilized)
		end

		if not stabilized then
			addPain(org, 55, (limb_key == "lleg" or limb_key == "rleg") and "lower" or "body")
			org.immobilization = org.immobilization + dmg * 25
		else
			addPain(org, 10, (limb_key == "lleg" or limb_key == "rleg") and "lower" or "body")
			org.immobilization = org.immobilization + dmg * 5
		end
		org.owner:AddNaturalAdrenaline(1)
		org.fearadd = org.fearadd + 0.5

		if hasNewThoughts(org) then
			sendThought(org, "Your " .. limbName[key] .. " is broken.", "thought_broke" .. key, 1, Color(255, 210, 210))
		else
			org.owner:Notify(broke_arm[math.random(#broke_arm)], true, "broke" .. key, 2)
		end

		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream and canFeelPain(org, "body") then hg.QueuePainScream(org.owner, 1.35) end
	else
		doDislocate(org, key, dmg, segment)
	end

	hg.AddHarmToAttacker(dmgInfo, (org[key] - oldDmg) * 1.5, "Arms bone damage harm")

	if org[key] == 1 and key == "rarm" and org.isPly then
		local wep = org.owner.GetActiveWeapon and org.owner:GetActiveWeapon()
		
		/*if IsValid(wep) then
			local inv = org.owner:GetNetVar("Inventory",{})
			if not (inv["Weapons"] and inv["Weapons"]["hg_sling"] and ishgweapon(wep) and not wep:IsPistolHoldType()) then
				hg.drop(org.owner)
			else
				org.owner:SetActiveWeapon(org.owner:GetWeapon("weapon_hands_sh"))
			end
		end*/
	end

	return result, vecrand
end

local function spine(org, bone, dmg, dmgInfo, number, boneindex, dir, hit, ricochet)
	if dmgInfo:IsDamageType(DMG_BLAST) then dmg = dmg / 3 end

	local name = "spine" .. number
	local name2 = "fake_spine" .. number
	local damageLimit = name == "spine3" and 1 or hg.organism[name2]
	if org[name] >= damageLimit then return 0 end
	local oldDmg = org[name]

	local result, vecrand = damageBone(org, 0.1, dmgInfo:IsDamageType(DMG_SLASH) and dmg * 0.6 or dmg * 0.4, dmgInfo, name, boneindex, dir, hit, ricochet)
	
	hg.AddHarmToAttacker(dmgInfo, (org[name] - oldDmg) * 5, "Spine bone damage harm")
	
	if (name == "spine3" || name == "spine2") then
		hg.AddHarmToAttacker(dmgInfo, (org[name] - oldDmg) * 8, "Broken spine harm")
	end

	local breakThreshold = name == "spine3" and 1 or hg.organism[name2]
	if oldDmg < breakThreshold and org[name] >= breakThreshold and org.isPly then
		playBoneFractureSound(org.owner)
		if hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.1) end
		if org.owner:IsPlayer() and !hasNewThoughts(org) then
			org.owner:Notify(huyasd[name], true, name, 2)
		end
		sendThought(org, "Your spine is broken.", "thought_" .. name, 4, Color(255, 210, 210))
		if name == "spine3" then
			org.spine3AcutePainUntil = CurTime() + 1.5
			org.spine3AcutePain = 95
			addPain(org, 95, "spine3acute")
			if hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.6) end
		else
			if name == "spine2" then
				org.painadd = 0
				org.avgpain = 0
			end
			addPain(org, 25, "body")
		end
	end

	if name == "spine3" then
		local cervicalLimit = hg.organism.fake_spine3 or 0.75
		if oldDmg < cervicalLimit and org.spine3 >= cervicalLimit then
			org.cervicalParalysis = true
			org.paralyzed = true
			if org.isPly and IsValid(org.owner) then
				org.owner:Notify("Your neck is broken. You can't move.", 20, "cervical_paralysis", 0, nil, Color(255, 190, 190))
			end
		end
		if oldDmg < 1 and org.spine3 >= 1 then
			org.cervicalParalysis = true
			org.paralyzed = true
			if org.isPly and IsValid(org.owner) then
				org.owner:Notify("I CAN'T MOVE...", true, "cervical_respiratory_arrest", 0, nil, Color(255, 95, 95))
			end
		end
	end
	
	if dmg > 0.2 then
		--org.owner:Notify("Your spinal cord is damaged.",true,"spinalcord",4)
	end

	addPain(org, dmg * 2, "body")
	timer.Simple(0, function() hg.LightStunPlayer(org.owner) end)
	org.shock = org.shock + dmg * 5
	return result,vecrand
end

local jaw_broken_msg = {
	"I FEEL PIECES OF MY JAW... FUCK-FUCK-FUCK",
	"MY JAW IS FUCKING FLOATING IN MY HEAD",
	"MY JAW... OHH IT HURTS REALLY BAD... I FEEL PIECES OF IT MOVING",
}

local jaw_dislocated_msg = {
	"I CAN'T CLOSE MY JAW... IT FUCKING HURTS",
	"MY JAW... ITS JUST STUCK THERE-- OH ITS PAINING",
	"I CANT MOVE MY JAW AT ALL... AND ITS REALLY ACHING",
	//"I CANT EVEN SPEAK, I NEED TO PUNCH IT BACK IN PLACE... BUT IT HURTS REAL BAD",
}

local function shouldTriggerTinnitus(dmgInfo, damage, hasHelmet)
	if damage < 0.1 then return false end
	local chance = 30
	if dmgInfo:IsDamageType(DMG_CLUB) then
		chance = hasHelmet and 12 or 50
	elseif dmgInfo:IsDamageType(DMG_SLASH) then
		chance = hasHelmet and 8 or 20
	end
	return math.random(100) <= chance
end

local function applySkullTinnitus(targetPlayer, skullDamage, impactDamage)
	if not IsValid(targetPlayer) or not targetPlayer:IsPlayer() or not targetPlayer.AddTinnitus then return end
	local duration = math.Clamp(skullDamage * 9 + impactDamage * 0.45, 0.75, 5)
	targetPlayer:AddTinnitus(duration, true)
end

local function sendHeadTraumaFlash(org, dmg, dmgInfo, boneDelta, concussionGain, brainGain)
	if not org.isPly or not IsValid(org.owner) or not org.owner:IsPlayer() then return end

	local target = org.owner
	if (target.HeadDisorientFlashCooldown or 0) > CurTime() then return end

	dmg = math.max(dmg or 0, 0)
	boneDelta = math.max(boneDelta or 0, 0)
	concussionGain = math.max(concussionGain or 0, 0)
	brainGain = math.max(brainGain or 0, 0)
	if boneDelta <= 0.01 and concussionGain <= 0.05 and brainGain <= 0 and dmg < 0.05 then return end

	local hasBrainDamage = brainGain > 0
	local hasConcussion = concussionGain > 0.05
	local isCritical = hasBrainDamage or concussionGain >= 1.5
	local timeScale = math.Clamp(0.35 + boneDelta * 0.8 + concussionGain * 0.2 + brainGain, 0.35, 1.35)
	local flashSize = math.Clamp(950 + dmg * 260 + boneDelta * 1500 + concussionGain * 180 + brainGain * 900, 950, 3200)

	local eyePos = target:EyePos()
	local eyeAng = target:EyeAngles()
	local worldPos = eyePos + eyeAng:Forward() * 16
	local incomingPos = dmgInfo:GetDamagePosition()
	if incomingPos ~= vector_origin then
		local incomingDir = (incomingPos - eyePos):GetNormalized()
		worldPos = eyePos + eyeAng:Right() * (eyeAng:Right():Dot(incomingDir) * 160) + eyeAng:Up() * (eyeAng:Up():Dot(incomingDir) * 100) + eyeAng:Forward() * 16
	end

	net.Start("headtrauma_flash")
		net.WriteVector(worldPos)
		net.WriteFloat(timeScale)
		net.WriteInt(math.floor(flashSize), 20)
		net.WriteBool(isCritical)
		net.WriteBool(false)
		net.WriteBool(hasBrainDamage)
		net.WriteBool(hasConcussion)
		net.WriteBool(hasConcussion and (concussionGain >= 0.35 or hasBrainDamage))
		net.WriteBool(hasBrainDamage or concussionGain >= 1.5)
	net.Send(target)

	target.HeadDisorientFlashCooldown = CurTime() + 0.15
end

local input_list = hg.organism.input_list
local toothModel = Model("models/phobias/general/tooth/tooth.mdl")
local toothFallbackModel = Model("models/grub_nugget_small.mdl")

local function SpawnTeeth(org, count, hitPos, forceDir)
	local owner = org.owner
	if not IsValid(owner) then return end

	local character = hg.GetCurrentCharacter(owner)
	if not IsValid(character) then character = owner end

	local pos = isvector(hitPos) and hitPos or nil
	if not pos then
		local headBone = character:LookupBone("ValveBiped.Bip01_Head1")
		pos = headBone and character:GetBonePosition(headBone) or character:WorldSpaceCenter()
	end

	local direction = isvector(forceDir) and forceDir:GetNormalized() or character:GetForward()
	local baseVelocity = character:GetVelocity()
	local model = util.IsValidModel(toothModel) and toothModel or toothFallbackModel

	for _ = 1, math.min(count, 6) do
		local tooth = ents.Create("prop_physics")
		if not IsValid(tooth) then continue end

		tooth:SetModel(model)
		tooth:SetPos(pos + VectorRand(-1.5, 1.5))
		tooth:SetAngles(AngleRand())
		tooth:SetModelScale(math.Rand(0.85, 1.1), 0)
		tooth:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		tooth:Spawn()
		tooth:Activate()

		local phys = tooth:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(0.05)
			phys:SetVelocity(baseVelocity + direction * math.Rand(90, 180) + VectorRand(-55, 55) + vector_up * math.Rand(20, 70))
			phys:AddAngleVelocity(VectorRand(-500, 500))
		end

		tooth:AddCallback("PhysicsCollide", function(ent, data)
			if ent.toothLanded or data.Speed < 45 then return end
			ent.toothLanded = true
			ent:EmitSound("physics/plaster/drywall_impact_hard" .. math.random(3) .. ".wav", 45, math.random(145, 165), 0.25)
		end)

		timer.Simple(18, function()
			if IsValid(tooth) then tooth:SetModelScale(0, 2) end
		end)
		SafeRemoveEntityDelayed(tooth, 20)
	end

	local effect = EffectData()
	effect:SetOrigin(pos)
	effect:SetNormal(direction)
	util.Effect("BloodImpact", effect, true, true)
end

input_list.jaw = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.jaw
	local incomingDmg = dmg
	local rawDamageType = dmgInfo:GetDamageType()

	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "jaw", boneindex, dir, hit, ricochet)
	local jawDelta = math.max(org.jaw - oldDmg, 0)
	org.teethLost = math.Clamp(org.teethLost or 0, 0, 32)

	local jawPain = math.Clamp(incomingDmg * 10 + jawDelta * 28, 0, 38)
	addPain(org, jawPain, "head")
	if hg.organism.AddInstantPain then hg.organism.AddInstantPain(org, jawPain * 0.45, "head") else org.avgpain = math.min((org.avgpain or 0) + jawPain * 0.45, 150) end
	org.shock = math.min((org.shock or 0) + jawPain * 0.5, 95)

	if org.consciousness then
		local consciousnessDrain = math.Clamp(incomingDmg * 0.015 + jawDelta * 0.18, 0, 0.18)
		org.consciousness = math.max(org.consciousness - consciousnessDrain, 0)
	end

	if org.alive and not org.otrub and incomingDmg > 0.25 then
		local knockoutChance = math.Clamp(incomingDmg * 0.04 + jawDelta * 0.35, 0, 0.28)
		if math.Rand(0, 1) < knockoutChance then
			org.needotrub = true
			org.consciousness = math.min(org.consciousness or 1, 0.18)
		end
	end

	if jawDelta > 0 and incomingDmg >= 0.12 and org.teethLost < 32 then
		local typeMul = 0.35
		if bit.band(rawDamageType, DMG_CLUB) ~= 0 then
			typeMul = 1.35
		elseif bit.band(rawDamageType, DMG_CRUSH) ~= 0 or bit.band(rawDamageType, DMG_FALL) ~= 0 then
			typeMul = 1.15
		elseif bit.band(rawDamageType, DMG_BUCKSHOT) ~= 0 then
			typeMul = 1
		elseif bit.band(rawDamageType, DMG_BULLET) ~= 0 then
			typeMul = 0.75
		elseif bit.band(rawDamageType, DMG_BLAST) ~= 0 then
			typeMul = 0.55
		elseif bit.band(rawDamageType, DMG_SLASH) ~= 0 then
			typeMul = 0.25
		end

		local severity = math.Clamp(incomingDmg * 0.55 + jawDelta * 1.6, 0, 2)
		local chance = math.Clamp((severity - 0.12) * 0.42 * typeMul, 0, 0.85)
		if math.Rand(0, 1) < chance then
			local lost = math.random(1, math.Clamp(math.ceil(severity * 3.5 * typeMul), 1, 8))
			if (org.jaw == 1 and oldDmg < 1) or severity > 1.25 then
				lost = lost + math.random(1, 4)
			end

			lost = math.min(lost, 32 - org.teethLost)
			org.teethLost = org.teethLost + lost
			SpawnTeeth(org, lost, hit, dir)
			addPain(org, 4 + lost * 3, "head")
			org.shock = math.min((org.shock or 0) + 1 + lost * 1.5, 95)
			hg.AddHarmToAttacker(dmgInfo, lost * 0.08, "Teeth loss harm")

			if IsValid(org.owner) and hg.organism.AddWoundManual then
				hg.organism.AddWoundManual(org.owner, math.min(4 + lost * 2, 18), Vector(1, -3, 0), angle_zero, "ValveBiped.Bip01_Head1", CurTime())
				org.owner:EmitSound("physics/flesh/flesh_bloody_impact_hard1.wav", 65, math.random(105, 120), 0.7)
			end

			if org.isPly then
				local message = lost == 1 and "You lost a tooth." or ("You lost " .. lost .. " teeth.")
				if !hasNewThoughts(org) then org.owner:Notify(message, true, "teeth", 2) end
				sendThought(org, message, "thought_teeth", 3, Color(255, 210, 210))
			end
		end
	end

	hg.AddHarmToAttacker(dmgInfo, (org.jaw - oldDmg) * 3, "Jaw bone damage harm")

	if org.jaw == 1 and (org.jaw - oldDmg) > 0 and org.isPly then
		if !hasNewThoughts(org) then org.owner:Notify(jaw_broken_msg[math.random(#jaw_broken_msg)], true, "jaw", 2) end
		sendThought(org, "Your jaw is broken.", "thought_jaw", 4, Color(255, 210, 210))
	end

	local dislocated = (org.jaw - oldDmg) > math.Rand(0.1, 0.3)

	if org.jaw == 1 then
		org.shock = org.shock + dmg * 40
		if hg.organism.AddInstantPain then hg.organism.AddInstantPain(org, dmg * 30, "head") else org.avgpain = org.avgpain + dmg * 30 end

		if oldDmg != 1 then
			playBoneFractureSound(org.owner)
			if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1) end
		end
	end

	org.shock = org.shock + dmg * 3

	if dislocated then
		org.shock = org.shock + dmg * 20
		if hg.organism.AddInstantPain then hg.organism.AddInstantPain(org, dmg * 20, "head") else org.avgpain = org.avgpain + dmg * 20 end
		
		if !org.jawdislocation then
			playBoneFractureSound(org.owner)
			if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 0.85) end
		end

		org.jawdislocation = true

		if org.isPly then
			if !hasNewThoughts(org) then org.owner:Notify(jaw_dislocated_msg[math.random(#jaw_dislocated_msg)], true, "jaw", 2) end
			sendThought(org, "Your jaw is dislocated.", "thought_jawdislocated", 4, Color(255, 220, 220))
		end
	end

	if dmg > 0.2 then
		if org.isPly then timer.Simple(0, function() hg.LightStunPlayer(org.owner,1 + dmg) end) end
	end

	if (org.jaw - oldDmg) > 0.15 then
		local disorientationAdd = dmg * 0.5
		org.disorientation = math.min(org.disorientation + disorientationAdd, 1.5)

		if org.isPly and disorientationAdd > 0.1 and shouldTriggerTinnitus(dmgInfo, dmg, false) then
			local targetPlayer = org.owner
			if IsValid(org.owner.FakeRagdoll) then
				local ragdoll = org.owner.FakeRagdoll
				if IsValid(ragdoll.ply) then targetPlayer = ragdoll.ply end
			end
			if IsValid(targetPlayer) and targetPlayer:IsPlayer() then
				targetPlayer:PlayCustomTinnitus("tinnitus.wav")
			end
		end
	end

	if hg.organism.ApplyOrganTrauma then
		hg.organism.ApplyOrganTrauma(org, dmgInfo, incomingDmg, org.jaw - oldDmg, oldDmg, "brain")
	end

	return result, vecrand
end

hook.Add("CanListenOthers", "CantHaveShitInDetroit", function(output, input, isChat, teamonly, text)
	if IsValid(output) and (output.organism.jaw == 1 or output.organism.jawdislocation) and output:Alive() and (output:IsSpeaking() or isChat) then
		-- and !isChat and output:IsSpeaking()
		addPain(output.organism, 2 * (output:IsSpeaking() and 1 or (isChat and 5 or 0)), "head")
		if output:GetInfoNum("hg_newthoughts", 0) <= 0 then output:Notify("My jaw is really hurting when I speak.", 60, "painfromjawspeak", 0, nil, Color(255, 210, 210)) end
	end
end)


input_list.skull = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact)
	local oldDmg = org.skull
	local oldBrain = org.brain or 0
	local ignoreBrainDamage = hg.organism.IsBrainDamageIgnored and hg.organism.IsBrainDamageIgnored(org)
	local brainEnergy = impact and impact.source == "physics" and math.max(impact.residualEnergy or 0, 0) or dmg
	local headOutcomeHandled = impact and impact.headOutcomeHandled
	
	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "skull", boneindex, dir, hit, ricochet)
	local inflictor = dmgInfo:GetInflictor()
	local rawDamageType = impact and impact.rawDamageType or dmgInfo:GetDamageType()
	local isStab = bit.band(rawDamageType, DMG_SLASH) != 0 and not (IsValid(inflictor) and inflictor.slash)
	local helmet = org.owner.armors and org.owner.armors["head"]
	local functionalHelmet = helmet and hg.armor.head and hg.armor.head[helmet]
		and not (org.owner.armors_broken and org.owner.armors_broken[helmet])
	local helmetApplied = (org.lastHeadArmorMitigation or 1) < 1
	local helmetProtectedHit = functionalHelmet and helmetApplied

	if isStab and functionalHelmet and helmetApplied then
		org.skull = oldDmg
	end
	if isMelee(dmgInfo) and oldDmg < 1 and org.skull < 1 and dmg > 0.3 and dmg < 1.35 then result = 1 end

	hg.AddHarmToAttacker(dmgInfo, (org.skull - oldDmg) * 4, "Skull bone damage harm")

	if org.skull == 1 then
		org.shock = org.shock + dmg * 40
		if hg.organism.AddInstantPain then hg.organism.AddInstantPain(org, dmg * 30, "head") else org.avgpain = org.avgpain + dmg * 30 end

		if oldDmg != 1 then
			playSkullFractureSound(org.owner)
			sendThought(org, "Your skull is broken.", "thought_skull", 4, Color(255, 180, 180))
		end
	end

	org.shock = org.shock + dmg * 3

	local rnd = not headOutcomeHandled and (math.random(10) == 1 or dmgInfo:IsDamageType(DMG_CRUSH)) and brainEnergy > 0.05
	org.consciousness = math.Approach(org.consciousness, 0, rnd and dmg * 2 or 0)

	org.brain = math.min(org.brain + (rnd and dmg * 0.05 or 0), 1)

	if math.random(1, 4) == 1 then
		local eye_dmg = dmg * math.Rand(0.8, 1.5)
		if math.random(1, 2) == 1 then
			if hg.organism.input_list.eyeL then hg.organism.input_list.eyeL(org, bone, eye_dmg, dmgInfo) end
		else
			if hg.organism.input_list.eyeR then hg.organism.input_list.eyeR(org, bone, eye_dmg, dmgInfo) end
		end
	end

	if (org.skull - oldDmg) > 0.6 and brainEnergy > 0.05 then
		org.brain = math.min(org.brain + 0.1, 1)
	end

	if not ignoreBrainDamage and brainEnergy > 0.05 and org.brain >= 0.01 and math.random(3) == 1 and (rnd or (org.skull - oldDmg) > 0.6) then
		org.shock = 70
	end

	if dmg > 0.4 then
		if org.isPly then
			timer.Simple(0, function()
				hg.LightStunPlayer(org.owner,1 + dmg)
			end)
		end
	end
	
	org.shock = org.shock + (dmg > 1 and 50 or dmg * 10)

	if org.skull == 1 then
		if org.isPly then
			//org.owner:Notify(huyasd["skull"],true,"skull",4)
		end

		--[[if dir then
			net.Start("hg_bloodimpact")
			net.WriteVector(dmgInfo:GetDamagePosition())
			net.WriteVector(dir / 10)
			net.WriteFloat(3)
			net.WriteInt(1,8)
			net.Broadcast()
		end--]]
	end

	org.disorientation = math.min(org.disorientation + (isCrush(dmgInfo) and dmg * 1 or dmg * 1), 1.5)

	local skullDelta = math.max(org.skull - oldDmg, 0)
	local brainDelta = math.max(org.brain - oldBrain, 0)
	local hasHelmet = org.owner.armors and org.owner.armors["head"] != nil
	local concussionGain = 0
	local headTraumaSeverity = skullDelta * 2.8 + brainDelta * 5.5 + math.Clamp(brainEnergy * 0.1, 0, 1)
	if not headOutcomeHandled and org.alive and not org.otrub and headTraumaSeverity >= 0.85 then
		local knockoutChance = math.Clamp((headTraumaSeverity - 0.65) * 0.18 + brainDelta * 0.35, 0, helmetProtectedHit and 0.06 or 0.34)
		if math.Rand(0, 1) < knockoutChance then
			org.needotrub = true
			org.consciousness = math.min(org.consciousness or 1, 0.08)
			org.shock = math.min((org.shock or 0) + 12 + brainDelta * 20, 95)
			headOutcomeHandled = true
		end
	end
	if not (impact and impact.headOutcomeHandled) and hg.organism.module.concussion and hg.organism.module.concussion.AddHeadTrauma then
		concussionGain = hg.organism.module.concussion.AddHeadTrauma(org, skullDelta, brainDelta, brainEnergy * (helmetProtectedHit and 1.8 or 1), dmgInfo)
	end

	if not ignoreBrainDamage and not isStab and brainEnergy > 0.05 then
		local headDmg = math.min(dmg, brainEnergy) * (hasHelmet and 0.3 or 1)
		org.disorientation = math.min(org.disorientation + math.min(headDmg * 0.15, 1.5), 1.5)
		if hg.organism.ApplyOrganTrauma then
			hg.organism.ApplyOrganTrauma(org, dmgInfo, headDmg, org.skull - oldDmg, oldDmg, "brain")
		end
	end

	sendHeadTraumaFlash(org, dmg, dmgInfo, skullDelta, concussionGain, brainDelta)

	if (org.skull - oldDmg) > 0.02 then
		local disorientationAdd = math.min(dmg * 1.5, 2.0)
		local hasHelmet = org.owner.armors and org.owner.armors["head"] != nil
		local effectiveDisorient = hasHelmet and disorientationAdd * 0.3 or disorientationAdd
		org.disorientation = math.min(org.disorientation + effectiveDisorient, 1.5)

		if org.isPly and effectiveDisorient > 0.05 then
			local targetPlayer = org.owner
			if IsValid(org.owner.FakeRagdoll) then
				local ragdoll = org.owner.FakeRagdoll
				if IsValid(ragdoll.ply) then targetPlayer = ragdoll.ply end
			end
			if IsValid(targetPlayer) and targetPlayer:IsPlayer() then
				targetPlayer:PlayCustomTinnitus("headhit.mp3")
				if not hasHelmet or (org.skull - oldDmg) > 0.15 then
					applySkullTinnitus(targetPlayer, org.skull - oldDmg, dmg)
				end
			end
		end

		if org.isPly and effectiveDisorient > 0.05 and shouldTriggerTinnitus(dmgInfo, dmg, hasHelmet) then
			local targetPlayer = org.owner
			if IsValid(org.owner.FakeRagdoll) then
				local ragdoll = org.owner.FakeRagdoll
				if IsValid(ragdoll.ply) then targetPlayer = ragdoll.ply end
			end
			if IsValid(targetPlayer) and targetPlayer:IsPlayer() then
				targetPlayer:PlayCustomTinnitus("tinnitus.wav")
			end
		end
	end

	if not ignoreBrainDamage and org.isPly and (org.brain - 0) > 0 and dmg > 0.5 then
		local targetPlayer = org.owner
		if IsValid(org.owner.FakeRagdoll) then
			local ragdoll = org.owner.FakeRagdoll
			if IsValid(ragdoll.ply) then targetPlayer = ragdoll.ply end
		end
		if IsValid(targetPlayer) and targetPlayer:IsPlayer() then
			local idx = math.random(1, 4)
			local snd = "concussion" .. idx .. ".mp3"
			net.Start("hg_play_client_sound_file")
				net.WriteString(snd)
			net.Send(targetPlayer)
		end
	end

	return result,vecrand
end

local ribs = {
	"I think something snapped in my chest.",
	"Something feels wrong in my chest.",
	"I think there is something sharp in my chest.",
	"My chest hurts. Something may be broken.",
}

input_list.chest = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)	
	local oldDmg = org.chest

	if dmgInfo:IsDamageType(DMG_SLASH+DMG_BULLET+DMG_BUCKSHOT) and math.random(5) == 1 then return 0, vector_origin end --random chance it passed through ribs

	local result, vecrand = damageBone(org, 0.1, dmg / 4, dmgInfo, "chest", boneindex, dir, hit, ricochet, true)
	
	hg.AddHarmToAttacker(dmgInfo, (org.chest - oldDmg) * 3, "Ribs bone damage harm")

	addPain(org, dmg * 1.5, "body")
	org.shock = org.shock + dmg * 1.5

	if org.isPly and (not org.brokenribs or (org.brokenribs ~= math.Round(org.chest * 3))) then
		org.brokenribs = math.Round(org.chest * 3)
		
		if org.brokenribs > 0 then
			if hasNewThoughts(org) then
				sendThought(org, "You broke " .. org.brokenribs .. " ribs.", "thought_ribs", 3, Color(255, 210, 210))
			else
				org.owner:Notify(ribs[math.random(#ribs)], 5, "ribs", 4)
			end

			playBoneFractureSound(org.owner)
			if hg.QueuePainScream then hg.QueuePainScream(org.owner, 0.8) end

			return math.min(0, result)
		end
	end

	return result * 0.5, vecrand
end

input_list.pelvis = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.pelvis
	addPain(org, dmg * 1, "lower")
	org.shock = org.shock + dmg * 1

	local result = damageBone(org, 0.15, dmg * 0.5, dmgInfo, "pelvis", boneindex, dir, hit, ricochet)
	
	hg.AddHarmToAttacker(dmgInfo, (org.pelvis - oldDmg) / 2, "Pelvis bone damage harm")

	if org.isPly and org.pelvis == 1 then
		//org.owner:Notify("My pelvis is agonizingly hurting.", true, "pelvis", 4)
		sendThought(org, "Your pelvis is broken.", "thought_pelvis", 4, Color(255, 210, 210))
	end

	return result
end

local function upper_limb(org, bone, dmg, dmgInfo, amputate_key, limb_key, segment, boneindex, dir, hit, ricochet)
	local oldDmg = org[limb_key]
	local dmg = dmg * 2.0
	local amputateThreshold = org.isPly and player_crush_amputation_threshold or 4

	if dmgInfo:IsDamageType(DMG_CRUSH) and dmg > amputateThreshold and !org[amputate_key.."amputated"] then
		hg.organism.AmputateLimb(org, amputate_key)
		return 0
	end

	if org[limb_key] == 1 then return 0 end

	local result, vecrand = damageBone(org, 0.3, dmg, dmgInfo, limb_key, boneindex, dir, hit, ricochet)

	local d = org[limb_key]
	org[limb_key] = org[limb_key] * 0.5

	if d < 0.5 then return 0 end
	if d < 1 and !dmgInfo:IsDamageType(DMG_CLUB+DMG_CRUSH+DMG_FALL) then
		if math.Rand(0, 1) >= 0.5 then return 0 end
		doDislocate(org, limb_key, d, segment)
		return result, vecrand
	end

	if org.isPly and !org[amputate_key.."amputated"] then org.just_damaged_bone = CurTime() end

	local stabilized = org[limb_key.."stabilized"]

	if d >= 1 and (!dmgInfo:IsDamageType(DMG_CLUB+DMG_CRUSH+DMG_FALL) or math.random(3) != 1) then
		org[limb_key] = 1
		if hg.fakeBoneFlop then
			hg.fakeBoneFlop.SetLimbSegmentState(org, limb_key, segment, not stabilized)
		end

		if not stabilized then
			addPain(org, 55, "body")
			org.immobilization = org.immobilization + d * 25
		else
			addPain(org, 10, "body")
			org.immobilization = org.immobilization + d * 5
		end
		org.owner:AddNaturalAdrenaline(1)
		org.fearadd = org.fearadd + 0.5

		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream and canFeelPain(org, (limb_key == "lleg" or limb_key == "rleg") and "lower" or "body") then hg.QueuePainScream(org.owner, 1.35) end
	else
		doDislocate(org, limb_key, d, segment)
	end

	hg.AddHarmToAttacker(dmgInfo, (org[limb_key] - oldDmg) * 1.5, "Upper limb bone damage harm")

	return result, vecrand
end

input_list.rarmup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return upper_limb(org, bone * 1.25, dmg, dmgInfo, "rarmup", "rarm", "up", boneindex, dir, hit, ricochet) end
input_list.rarmdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone, dmg, dmgInfo, "rarm", "down", boneindex, dir, hit, ricochet) end
input_list.larmup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return upper_limb(org, bone * 1.25, dmg, dmgInfo, "larmup", "larm", "up", boneindex, dir, hit, ricochet) end
input_list.larmdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone, dmg, dmgInfo, "larm", "down", boneindex, dir, hit, ricochet) end
input_list.rlegup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return upper_limb(org, bone, dmg * 1.25, dmgInfo, "rlegup", "rleg", "up", boneindex, dir, hit, ricochet) end
input_list.rlegdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg, dmgInfo, "rleg", "down", boneindex, dir, hit, ricochet) end
input_list.llegup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return upper_limb(org, bone, dmg * 1.25, dmgInfo, "llegup", "lleg", "up", boneindex, dir, hit, ricochet) end
input_list.llegdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg, dmgInfo, "lleg", "down", boneindex, dir, hit, ricochet) end
input_list.spine1 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 1, boneindex, dir, hit, ricochet) end
input_list.spine2 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 2, boneindex, dir, hit, ricochet) end
input_list.spine3 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 3, boneindex, dir, hit, ricochet) end

hook.Add("Org Think", "homigrad_bone_stabilization", function(owner, org, timeValue)
	if not org.alive then return end

	org._zsh_stab_prev = org._zsh_stab_prev or {}

	for _, info in ipairs({
		{key = "larm", segs = {"up", "down"}},
		{key = "rarm", segs = {"up", "down"}},
		{key = "lleg", segs = {"up", "down"}},
		{key = "rleg", segs = {"up", "down"}},
	}) do
		local key = info.key
		local stabilized = org[key .. "stabilized"]
		local broke = (org[key] or 0) >= 0.95 or org[key .. "dislocation"]

		if not stabilized or not broke then
			org._zsh_stab_prev[key] = false
		else
			local prev = org._zsh_stab_prev[key]
			if not prev then
				if hg.fakeBoneFlop then
					for _, seg in ipairs(info.segs) do
						hg.fakeBoneFlop.SetLimbSegmentState(org, key, seg, false)
					end
				end
				org.painadd = math.max(org.painadd - 25, 0)
				org.immobilization = math.max(org.immobilization - (broke and 100 or 40), 0)
			end

			org.painadd = math.Approach(org.painadd, 0, timeValue * 5)
			org.immobilization = math.Approach(org.immobilization, 0, timeValue * 10)

			org._zsh_stab_prev[key] = true
		end
	end
end)
