if SERVER then util.AddNetworkString("headtrauma_flash") end

local player_crush_amputation_threshold = 7

util.AddNetworkString("hg_play_client_sound_file")

local function isCrush(dmgInfo)
	return (not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST)) or dmgInfo:GetInflictor().RubberBullets
end

local function isMelee(dmgInfo)
	return dmgInfo:IsDamageType(DMG_SLASH + DMG_CLUB + DMG_GENERIC)
end

local function isBluntBrainImpact(dmgInfo)
	return dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL + DMG_VEHICLE)
end

local halfValue2 = util.halfValue2
local function damageBone(org, bone, dmg, dmgInfo, key, boneindex, dir, hit, ricochet, nodmgchange)
	local crush = isCrush(dmgInfo)
	
	if dmgInfo:IsDamageType(DMG_SLASH) and dmg > 1.5 then
		//crush = false
	end
	
	local breakBoneMul = dmgInfo:GetInflictor().BreakBoneMul or 1
	if dmgInfo:IsDamageType(DMG_CLUB) then breakBoneMul = breakBoneMul * 0.8 end
	dmg = dmg * breakBoneMul
	
	if crush then
		crush = halfValue2(1 - org[key], 1, 0.5)
		dmg = dmg / math.max(10 * crush * (bone or 1), 1)
		if dmgInfo:GetInflictor().RubberBullets then dmg = dmg * dmgInfo:GetInflictor().Penetration end
	end

	org[key] = math.min(org[key] + dmg, 1)

	if !nodmgchange then dmgInfo:ScaleDamage(1 - (crush and crush * math.max((1 - org[key]) ^ 0.1, 0.5) or (1 - org[key]) * bone)) end

	return (crush and crush * math.max((1 - org[key]) ^ 0.1, 0.5) or (1 - org[key]) * bone), VectorRand(-0.2, 0.2) / math.Clamp(dmg, 0.4, 0.8)
end

local function markDamagedBone(org, boneName, severity)
	if hg.organism.MarkDamagedBone then
		hg.organism.MarkDamagedBone(org, boneName, severity)
	end
end

local function markBrokenBone(org, boneName)
	if hg.organism.MarkBrokenBone then
		hg.organism.MarkBrokenBone(org, boneName)
	end
end

local bonefracture_sounds = {
	"bonefracture/rem_bonebreak1.wav",
	"bonefracture/rem_bonebreak2.wav",
	"bonefracture/rem_bonebreak3.wav",
}

local skullfracture_sounds = {
	"skullfracture/skullfracture-1.wav",
	"skullfracture/skullfracture-2.wav",
	"skullfracture/skullfracture-3.wav",
	"skullfracture/skullfracture-4.wav",
	"skullfracture/skullfracture-5.wav",
	"skullfracture/skullfracture-6.wav",
	"skullfracture/skullfracture-7.wav",
}

local function emitRandomBoneBreakSound(ent, volume, level)
	if not IsValid(ent) then return end

	local soundType = math.random(3)
	if soundType == 1 then
		ent:EmitSound(bonefracture_sounds[math.random(#bonefracture_sounds)], volume or 75, math.random(135, 155), level or 1, CHAN_AUTO)
	elseif soundType == 2 then
		ent:EmitSound("owfuck" .. math.random(1, 10) .. ".mp3", volume or 75, 100, level or 1, CHAN_AUTO)
	else
		ent:EmitSound("newbonebreak/break" .. math.random(10) .. ".wav", volume or 75, math.random(120, 135), level or 1, CHAN_AUTO)
	end
end

local armDropChances = {
	shot = {larm = 0.005, rarm = 0.025},
	dislocation = {larm = 0.10, rarm = 0.45},
	fracture = {larm = 0.18, rarm = 0.68},
}

local function weaponUsesBothHands(wep, owner)
	if not IsValid(wep) then return false end
	if wep.TwoHanded == true then return true end
	if wep.OneHandedOnly == true or wep.TwoHanded == false then return false end

	if wep.GetHandSupportState then
		local ok, state = pcall(wep.GetHandSupportState, wep, owner)
		if ok and istable(state) then
			-- Do not require leftSupport here: the injury being processed may have
			-- just made that arm unusable. We care whether this weapon/posture was a
			-- two-hand grip, not whether the damaged hand remains usable afterward.
			return state.wantsTwoHands == true and state.postureOneHanded ~= true
		end
	end

	return false
end

local function tryDropHeldItemFromArmInjury(org, key, reason, severity, boneName, forceDrop)
	if not SERVER or not org.isPly or (key ~= "larm" and key ~= "rarm") then return end
	local owner = org.owner
	if not IsValid(owner) or not owner:Alive() then return end
	owner.hg_arm_drop_roll = owner.hg_arm_drop_roll or {}
	if not forceDrop and (owner.hg_arm_drop_roll[key] or 0) > CurTime() then return end
	owner.hg_arm_drop_roll[key] = CurTime() + 0.12

	local wep = owner:GetActiveWeapon()
	if not IsValid(wep) then owner:DropObject() return end

	-- The right hand is the primary firing/grip hand. The left hand only gets a
	-- release roll when it is genuinely supporting a two-handed weapon.
	if key == "larm" and not weaponUsesBothHands(wep, owner) then return end

	local chance = armDropChances[reason] and armDropChances[reason][key] or 0
	local severityK = math.Clamp(tonumber(severity) or 0, 0, 1.5)
	local isHand = boneName == (key == "rarm" and "ValveBiped.Bip01_R_Hand" or "ValveBiped.Bip01_L_Hand")
	local isForearm = boneName == (key == "rarm" and "ValveBiped.Bip01_R_Forearm" or "ValveBiped.Bip01_L_Forearm")

	if reason == "shot" then
		-- A direct hand hit has the strongest effect on grip. The support hand is
		-- intentionally much harder to knock free than the primary right hand.
		local handMul = key == "rarm" and 0.30 or 0.09
		local forearmMul = key == "rarm" and 0.12 or 0.035
		local otherMul = key == "rarm" and 0.06 or 0.015
		chance = chance + severityK * (isHand and handMul or (isForearm and forearmMul or otherMul))
		if isHand then chance = chance + (key == "rarm" and 0.10 or 0.03) end
		chance = chance + math.Clamp(org[key] or 0, 0, 1) * (key == "rarm" and 0.18 or 0.05)
	end
	if forceDrop then chance = 1 end
	chance = math.Clamp(chance, 0, 1)
	if chance <= 0 or math.random() >= chance then return end
	if wep:GetClass() == "weapon_hands_sh" then owner:DropObject() return end
	if wep.GetCarrying and wep.SetCarrying and IsValid(wep:GetCarrying()) then
		if key == "larm" and wep.UsingLeftHand == false then return end
		if key == "rarm" and wep.UsingRightHand == false then return end
		wep:SetCarrying()
		owner:DropObject()
		return
	end
	if wep.NoDrop and not forceDrop then return end
	if key == "larm" then
		local rightMissing = org.rarmamputated == true
		local oneHandedItem = wep.OneHandedOnly == true or wep.TwoHanded == false
		if oneHandedItem and not rightMissing then return end
	end

	hook.Run("PlayerDropWeapon", owner)
	owner:DropObject()
	-- Amputation is a hard loss of grip. If a gamemode hook did not actually
	-- release the active weapon, force the engine drop as a final fallback.
	if forceDrop and IsValid(wep) and wep:GetOwner() == owner and not wep.bigNoDrop then
		owner:DropWeapon(wep)
	end
end

hook.Add("OnAmputateLimb", "HG_AmputationDropsHeldWeapon", function(org, ent, limb)
	if limb == "rarm" then
		tryDropHeldItemFromArmInjury(org, "rarm", "fracture", 1.5, "ValveBiped.Bip01_R_Hand", true)
	end
end)

local function playBoneFractureSound(ent)
	emitRandomBoneBreakSound(ent)
end

local function playRemorseismBoneBreakSound(ent, volume, level)
	if not IsValid(ent) then return end
	ent:EmitSound(bonefracture_sounds[math.random(#bonefracture_sounds)], volume or 75, math.random(135, 155), level or 1, CHAN_AUTO)
end

local function playSkullFractureSound(ent)
	if not IsValid(ent) then return end
	-- Skull fractures need a larger audible radius than ordinary bone cracks;
	-- the samples themselves are comparatively quiet and were often masked by
	-- the simultaneous damage sounds.
	ent:EmitSound(skullfracture_sounds[math.random(#skullfracture_sounds)], 105, math.random(90, 110), 1, CHAN_AUTO)
	ent:EmitSound("gore/skullopen" .. math.random(1, 3) .. ".wav", 105, math.random(90, 110), 1, CHAN_AUTO)
end

local function addBoneInternalBleed(org, amount, cap)
	org.internalBleed = (org.internalBleed or 0) + math.Clamp(amount or 0, 0, cap or 1)
end

local function trySkullFractureHemorrhage(org, oldDamage, newDamage)
	if not hg.organism.AddBrainHemorrhage then return end

	local amountMin, amountMax, rateMin, rateMax
	if oldDamage < 1 and newDamage >= 1 then
		-- An open skull always produces a substantial traumatic cerebral bleed.
		amountMin, amountMax = 0.08, 0.16
		rateMin, rateMax = 0.0015, 0.003
	elseif oldDamage < 0.6 and newDamage >= 0.6 then
		-- At 0.6 the skull is fractured enough to transmit and trap blood
		-- inside the cranium.  Do not leave this threshold to a random roll.
		amountMin, amountMax = 0.025, 0.07
		rateMin, rateMax = 0.0004, 0.0012
	else
		return
	end

	hg.organism.AddBrainHemorrhage(org, math.Rand(amountMin, amountMax), math.Rand(rateMin, rateMax))
end

local function addBrokenBoneHitTrauma(org, key, dmg, soundThreshold)
	local severity = math.Clamp(dmg or 0, 0, 3)
	if severity <= 0 then return end

	org.painadd = (org.painadd or 0) + math.Clamp(severity * 7, 2, 18)

	if severity >= (soundThreshold or 0.45) then
		if (org._brokenBoneHitSound and org._brokenBoneHitSound[key] or 0) > CurTime() then return end
		org._brokenBoneHitSound = org._brokenBoneHitSound or {}
		org._brokenBoneHitSound[key] = CurTime() + 0.35
		playRemorseismBoneBreakSound(org.owner, 62, 0.55)
	end
end

local function sendSkullFractureGore(org, dmgInfo, openSkull)
	local ent = hg.GetCurrentCharacter(org.owner)
	if not IsValid(ent) then ent = org.owner end
	if not IsValid(ent) then return end

	local force = dmgInfo:GetDamageForce()
	local ang = force:LengthSqr() > 0 and force:GetNormalized():Angle() or angle_zero
	net.Start("hg_brainmist")
	net.WriteEntity(ent)
	net.WriteVector(dmgInfo:GetDamagePosition())
	net.WriteAngle(ang)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(openSkull == true)
	net.Broadcast()
end

local function sendHeadTraumaFlash(org, dmg, dmgInfo, boneDelta, concussionGain, brainGain, traumaBone)
	if not org.isPly or not IsValid(org.owner) or not org.owner:IsPlayer() then return end
	if org._deferHeadTraumaFlash then return end

	local target = org.owner
	local isCollision = traumaBone == "collision"
	local cooldown = (traumaBone == "jaw" or isCollision) and 0.35 or 0.2
	if (target.HeadDisorientFlashCooldown or 0) > CurTime() then return end

	boneDelta = math.max(boneDelta or 0, 0)
	concussionGain = math.max(concussionGain or 0, 0)
	brainGain = math.max(brainGain or 0, 0)
	dmg = math.max(dmg or 0, 0)
	if not isCollision and boneDelta <= 0.01 and concussionGain <= 0.05 and brainGain <= 0 and dmg < 0.2 then return end

	local hasBrainDamage = brainGain > 0
	local hasConcussion = concussionGain > 0.05
	local isCritical = hasBrainDamage or concussionGain >= 1.5
	local timeScale
	local flashSize
	if isCollision then
		timeScale = 0.6
		flashSize = 2200
	elseif traumaBone == "jaw" then
		timeScale = math.Clamp(0.25 + boneDelta * 0.8 + concussionGain * 0.08, 0.25, 1.15)
		flashSize = math.Clamp(1400 + boneDelta * 1400 + concussionGain * 120, 1400, 3000)
	else
		timeScale = math.Clamp(0.3 + boneDelta * 0.8 + brainGain * 1.5, 0.3, 1.35)
		flashSize = math.Clamp(1500 + boneDelta * 1500 + brainGain * 900, 1500, 3200)
	end

	local eyePos = target:EyePos()
	local eyeAng = target:EyeAngles()
	local worldPos = eyePos + eyeAng:Forward() * 16
	local incomingPos = dmgInfo:GetDamagePosition()
	if incomingPos ~= vector_origin then
		local incomingDir = (incomingPos - eyePos):GetNormalized()
		worldPos = eyePos + eyeAng:Right() * (eyeAng:Right():Dot(incomingDir) * 160) + eyeAng:Forward() * 16
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

	target.HeadDisorientFlashCooldown = CurTime() + cooldown
end

hg.organism.SendHeadTraumaFlash = sendHeadTraumaFlash

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

local function getThoughtPlayer(org)
	if not org or not org.isPly then return nil end

	local owner = org.owner
	if IsValid(owner) and owner:IsPlayer() then return owner end

	if IsValid(owner) and hg.RagdollOwner then
		local ply = hg.RagdollOwner(owner)
		if IsValid(ply) and ply:IsPlayer() then return ply end
	end
end

local function sendThought(org, msg, key, delay, clr)
	local ply = getThoughtPlayer(org)
	if IsValid(ply) and ply.Thought then
		ply:Thought(msg, delay or 1, key, 0, clr)
	end
end

local function hasNewThoughts(org)
	local ply = getThoughtPlayer(org)
	return IsValid(ply) and ply:GetInfoNum("hg_newthoughts", 0) > 0
end

local function sendLimbThought(org, messages, key, clr)
	local ply = getThoughtPlayer(org)
	if not IsValid(ply) or not istable(messages) or #messages == 0 then return end

	org.lastLimbThought = org.lastLimbThought or {}
	local index = math.random(#messages)
	if #messages > 1 and index == org.lastLimbThought[key] then
		index = index % #messages + 1
	end
	org.lastLimbThought[key] = index

	local msg = messages[index]
	if hasNewThoughts(org) then
		sendThought(org, msg, "thought_" .. key, 10, clr)
	elseif ply.Notify then
		ply:Notify(msg, 10, key, 0.15, nil, clr)
	end

	-- This injury was already reported immediately. Do not let the periodic
	-- status-thought path report the same break or dislocation again.
	org.just_damaged_bone = nil
end

local function legs(org, bone, dmg, dmgInfo, key, segment, boneindex, dir, hit, ricochet)
	local oldDmg = org[key]
	dmg = dmg * 4
	local amputateThreshold = org.isPly and player_crush_amputation_threshold or 4

	if dmgInfo:IsDamageType(DMG_CRUSH) and dmg > amputateThreshold and !org[key .. "amputated"] then
		hg.organism.AmputateLimb(org, key)
		return 0
	end

	if org[key] == 1 then
		addBrokenBoneHitTrauma(org, key, dmg, 0.5)
		return 0
	end

	local result, vecrand = damageBone(org, 0.3, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
	dmg = org[key]
	org[key] = org[key] * 0.5
	markDamagedBone(org, key == "lleg" and (segment == "up" and "ValveBiped.Bip01_L_Thigh" or "ValveBiped.Bip01_L_Calf") or (segment == "up" and "ValveBiped.Bip01_R_Thigh" or "ValveBiped.Bip01_R_Calf"), dmg)

	if dmg < 0.7 then return 0 end
	if dmg < 1 and !dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL) then return 0 end

	if org.isPly and !org[key .. "amputated"] then org.just_damaged_bone = CurTime() end

	if dmg >= 1 and (!dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL) or math.random(3) != 1) then
		org[key] = 1
		markBrokenBone(org, key == "lleg" and (segment == "up" and "ValveBiped.Bip01_L_Thigh" or "ValveBiped.Bip01_L_Calf") or (segment == "up" and "ValveBiped.Bip01_R_Thigh" or "ValveBiped.Bip01_R_Calf"))
		if hg.fakeBoneFlop then hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, true, {state = "broken", limb = key, segment = segment}) end
		if hg.BreakLimb then hg.BreakLimb(org.owner, key, segment, false) end
		org.painadd = org.painadd + 55
		if dmgInfo:IsDamageType(DMG_BLAST + DMG_CLUB + DMG_CRUSH + DMG_FALL + DMG_VEHICLE) then
			addBoneInternalBleed(org, 0.45, 0.8)
		end
		org.owner:AddNaturalAdrenaline(1)
		org.immobilization = org.immobilization + dmg * 25
		org.fearadd = org.fearadd + 0.5

		sendLimbThought(org, broke_leg, "broke_" .. key, Color(255, 210, 210))

		timer.Simple(0, function() hg.LightStunPlayer(org.owner,2) end)
		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.35) end
	else
		org[key .. "dislocation"] = true
		markBrokenBone(org, key == "lleg" and (segment == "up" and "ValveBiped.Bip01_L_Thigh" or "ValveBiped.Bip01_L_Calf") or (segment == "up" and "ValveBiped.Bip01_R_Thigh" or "ValveBiped.Bip01_R_Calf"))
		if hg.fakeBoneFlop then hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, true, {state = "dislocated", limb = key, segment = segment}) end
		if hg.BreakLimb then hg.BreakLimb(org.owner, key, segment, true) end
		org.painadd = org.painadd + 35
		org.owner:AddNaturalAdrenaline(0.5)
		org.immobilization = org.immobilization + dmg * 10
		org.fearadd = org.fearadd + 0.5

		sendLimbThought(org, dislocated_leg, "dislocated_" .. key, Color(255, 220, 220))

		timer.Simple(0, function() hg.LightStunPlayer(org.owner,2) end)
		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1) end
	end

	hg.AddHarmToAttacker(dmgInfo, (org[key] - oldDmg) * 2, "Legs bone damage harm")
	return result, vecrand
end

local function arms(org, bone, dmg, dmgInfo, key, segment, boneindex, dir, hit, ricochet)
	local oldDmg = org[key]
	dmg = dmg * 4
	local amputateThreshold = org.isPly and player_crush_amputation_threshold or 4

	if dmgInfo:IsDamageType(DMG_CRUSH) and dmg > amputateThreshold and !org[key .. "amputated"] then
		hg.organism.AmputateLimb(org, key)
		return 0
	end

	if org[key] == 1 then
		addBrokenBoneHitTrauma(org, key, dmg, 0.5)
		if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then tryDropHeldItemFromArmInjury(org, key, "shot", dmg, boneindex) end
		return 0
	end

	local result, vecrand = damageBone(org, 0.3, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
	dmg = org[key]
	org[key] = org[key] * 0.5
	markDamagedBone(org, key == "larm" and (segment == "up" and "ValveBiped.Bip01_L_UpperArm" or "ValveBiped.Bip01_L_Forearm") or (segment == "up" and "ValveBiped.Bip01_R_UpperArm" or "ValveBiped.Bip01_R_Forearm"), dmg)

	if dmg < 0.6 then
		if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then tryDropHeldItemFromArmInjury(org, key, "shot", dmg, boneindex) end
		return 0
	end
	if dmg < 1 and !dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL) then
		if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then tryDropHeldItemFromArmInjury(org, key, "shot", dmg, boneindex) end
		return 0
	end

	if org.isPly and !org[key .. "amputated"] then org.just_damaged_bone = CurTime() end

	if dmg >= 1 and (!dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL) or math.random(3) != 1) then
		org[key] = 1
		markBrokenBone(org, key == "larm" and (segment == "up" and "ValveBiped.Bip01_L_UpperArm" or "ValveBiped.Bip01_L_Forearm") or (segment == "up" and "ValveBiped.Bip01_R_UpperArm" or "ValveBiped.Bip01_R_Forearm"))
		if hg.fakeBoneFlop then hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, true, {state = "broken", limb = key, segment = segment}) end
		if hg.BreakLimb then hg.BreakLimb(org.owner, key, segment, false) end
		org.painadd = org.painadd + 55
		if dmgInfo:IsDamageType(DMG_BLAST + DMG_CLUB + DMG_CRUSH + DMG_FALL + DMG_VEHICLE) then
			addBoneInternalBleed(org, 0.35, 0.7)
		end
		org.owner:AddNaturalAdrenaline(1)
		org.fearadd = org.fearadd + 0.5

		sendLimbThought(org, broke_arm, "broke_" .. key, Color(255, 210, 210))

		--timer.Simple(0, function() hg.LightStunPlayer(org.owner,1) end)
		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.35) end
		tryDropHeldItemFromArmInjury(org, key, "fracture", dmg, boneindex)
	else
		org[key .. "dislocation"] = true
		markBrokenBone(org, key == "larm" and (segment == "up" and "ValveBiped.Bip01_L_UpperArm" or "ValveBiped.Bip01_L_Forearm") or (segment == "up" and "ValveBiped.Bip01_R_UpperArm" or "ValveBiped.Bip01_R_Forearm"))
		if hg.fakeBoneFlop then hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, true, {state = "dislocated", limb = key, segment = segment}) end
		if hg.BreakLimb then hg.BreakLimb(org.owner, key, segment, true) end
		org.painadd = org.painadd + 35
		org.owner:AddNaturalAdrenaline(0.5)
		org.fearadd = org.fearadd + 0.5

		sendLimbThought(org, dislocated_arm, "dislocated_" .. key, Color(255, 220, 220))

		--timer.Simple(0, function() hg.LightStunPlayer(org.owner,1) end)
		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1) end
		tryDropHeldItemFromArmInjury(org, key, "dislocation", dmg, boneindex)
	end

	hg.AddHarmToAttacker(dmgInfo, (org[key] - oldDmg) * 1.5, "Arms bone damage harm")
	return result, vecrand
end

local function spine(org, bone, dmg, dmgInfo, number, boneindex, dir, hit, ricochet)
	if dmgInfo:IsDamageType(DMG_BLAST) then dmg = dmg / 3 end

	local name = "spine" .. number
	local name2 = "fake_spine" .. number
	if org[name] >= hg.organism[name2] then return 0 end
	local oldDmg = org[name]
	local breakThreshold = hg.organism[name2]

	if name == "spine3" and isCrush(dmgInfo) and dmg > 0.3 and math.random() < 0.4 then
		local skullResult, skullVec = damageBone(org, 0.25, dmg, dmgInfo, "skull", boneindex, dir, hit, ricochet)
		hg.AddHarmToAttacker(dmgInfo, skullResult * 0.5, "Skull damage from neck collision transfer")
		return skullResult, skullVec
	end

	local result, vecrand = damageBone(org, 0.1, isCrush(dmgInfo) and dmg * 2 or dmg * 2, dmgInfo, name, boneindex, dir, hit, ricochet)
	markDamagedBone(org, number == 1 and "ValveBiped.Bip01_Spine1" or (number == 2 and "ValveBiped.Bip01_Spine2" or "ValveBiped.Bip01_Neck1"), org[name])
	if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() and hg.BreakSpine and (name == "spine1" or name == "spine2") and org[name] >= hg.organism[name2] and oldDmg < hg.organism[name2] then
		hg.BreakSpine(org.owner, name, false)
	end

	hg.AddHarmToAttacker(dmgInfo, (org[name] - oldDmg) * 5, "Spine bone damage harm")
	if name == "spine3" or name == "spine2" then hg.AddHarmToAttacker(dmgInfo, (org[name] - oldDmg) * 8, "Broken spine harm") end

	if org[name] >= hg.organism[name2] and org.isPly then
		markBrokenBone(org, number == 1 and "ValveBiped.Bip01_Spine1" or (number == 2 and "ValveBiped.Bip01_Spine2" or "ValveBiped.Bip01_Neck1"))
		playBoneFractureSound(org.owner)
		if hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.1) end
		if org.owner:IsPlayer() and !hasNewThoughts(org) then
			org.owner:Notify(huyasd[name], true, name, 2)
		end
		if org.owner:IsPlayer() then
			sendThought(org, "Your spine is broken.", "thought_" .. name, 4, Color(255, 210, 210))
		end
		org.painadd = org.painadd + 25
	end

	if name == "spine3" and oldDmg < breakThreshold and org[name] >= breakThreshold and hg.BreakNeck then
		local damageForce = dmgInfo:GetDamageForce()
		-- Projectile forces use a very different scale and already have their own
		-- head-gib threshold. Only physical/crush force owns this neck-tear roll.
		local force = isCrush(dmgInfo) and isvector(damageForce) and damageForce:Length() or 0
		hg.BreakNeck(org.owner, true, force)
	end

	org.painadd = org.painadd + dmg * 2
	timer.Simple(0, function() hg.LightStunPlayer(org.owner) end)
	org.shock = org.shock + dmg * 5
	return result, vecrand
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

local function manageTinnitusSound(org, targetPlayer)
	if not IsValid(targetPlayer) or not targetPlayer:IsPlayer() then return end
	local hasHelmet = org.owner.armors and org.owner.armors["head"] != nil
	if org.skull >= 0.6 then
		if not org.tinnitusLongPlaying then
			org.tinnitusLongPlaying = true
			targetPlayer:PlayCustomTinnitus("tinnituslong.wav")
			local timerName = "TinnitusCheck_" .. targetPlayer:SteamID64()
			timer.Create(timerName, 8.0, 0, function()
				if not IsValid(targetPlayer) or not targetPlayer:Alive() or org.skull < 0.6 then
					timer.Remove(timerName)
					org.tinnitusLongPlaying = false
					targetPlayer:StopCustomTinnitus()
					return
				end
				targetPlayer:PlayCustomTinnitus("tinnituslong.wav")
			end)
			local disorientTimerName = "TinnitusDisorient_" .. targetPlayer:SteamID64()
			timer.Create(disorientTimerName, 0.1, 0, function()
				if not IsValid(targetPlayer) or not targetPlayer:Alive() or org.skull < 0.6 then
					timer.Remove(disorientTimerName)
					return
				end
				local rate = hasHelmet and 0.02 or 0.06
				org.disorientation = math.min(org.disorientation + rate, 1.5)
			end)
		end
	else
		if org.tinnitusLongPlaying then
			org.tinnitusLongPlaying = false
			local timerName = "TinnitusCheck_" .. targetPlayer:SteamID64()
			timer.Remove(timerName)
			local disorientTimerName = "TinnitusDisorient_" .. targetPlayer:SteamID64()
			timer.Remove(disorientTimerName)
			targetPlayer:StopCustomTinnitus()
		end
	end
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

local input_list = hg.organism.input_list
local fist_skull_damage_mul = 0.35
local jaw_concussion_per_damage = 15 -- 0.15 jaw damage = 2.25 concussion
local skull_concussion_per_damage = 11.25 -- 0.2 skull damage = 2.25 concussion
local function isFistInflictor(dmgInfo)
	local inflictor = dmgInfo and dmgInfo.GetInflictor and dmgInfo:GetInflictor() or nil
	if not IsValid(inflictor) or not inflictor:IsWeapon() then return false end

	local class = inflictor:GetClass()
	return class == "weapon_hands_sh" or class == "weapon_hg_coolhands"
end

input_list.jaw = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.jaw
	local incomingDmg = dmg
	local rawDamageType = dmgInfo:GetDamageType()

	local oldConcussion = org.concussion or 0
	local jawImpact = math.max(dmg or 0, 0)
	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "jaw", boneindex, dir, hit, ricochet)
	local jawDelta = math.max(org.jaw - oldDmg, 0)
	org.teethLost = math.Clamp(org.teethLost or 0, 0, 32)

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
			org.painadd = math.min((org.painadd or 0) + 4 + lost * 3, 150)
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
	local jawDelta = org.jaw - oldDmg
	markDamagedBone(org, "ValveBiped.Bip01_Head1", org.jaw)
	hg.AddHarmToAttacker(dmgInfo, jawDelta * 3, "Jaw bone damage harm")

	-- The jaw transfers rotational force into the brain even when the bone is
	-- already damaged. Weight it toward concussion/disorientation instead of
	-- directly injuring brain tissue like a penetrating skull hit.
	if jawDelta > 0 or jawImpact >= 0.2 then
		local impactConcussion = math.max(jawImpact - 0.15, 0) * (isCrush(dmgInfo) and 1.75 or 0.9)
		local concussionAdd = math.min(jawDelta * jaw_concussion_per_damage + impactConcussion, 5)
		local consciousnessLoss = math.min(jawDelta * 0.75 + math.max(jawImpact - 0.55, 0) * 0.35, 0.8)
		local disorientationAdd = math.min(jawDelta * 2.5 + jawImpact * 1.25, 5)

		hg.organism.module.concussion.AddImmediateConcussion(org, concussionAdd)
		org.consciousness = math.Approach(org.consciousness or 1, 0, consciousnessLoss)
		org.disorientation = math.min((org.disorientation or 0) + disorientationAdd, 10)

		-- A genuinely hard uppercut can immediately drop someone through the jaw
		-- lever without pretending the fist penetrated an intact skull.
		if isFistInflictor(dmgInfo) and jawImpact >= 0.65 and org.concussion >= 3.5 then
			org.consciousness = math.max((org.consciousness or 1) - math.min(jawImpact * 0.45, 0.5), 0)
			org.needfake = true
		end
	end

	if org.jaw == 1 and (org.jaw - oldDmg) > 0 and org.isPly then
		if !hasNewThoughts(org) then org.owner:Notify(jaw_broken_msg[math.random(#jaw_broken_msg)], true, "jaw", 2) end
		sendThought(org, "Your jaw is broken.", "thought_jaw", 4, Color(255, 210, 210))
	end

	local dislocated = (org.jaw - oldDmg) > math.Rand(0.1, 0.3)

	if org.jaw == 1 then
		markBrokenBone(org, "ValveBiped.Bip01_Head1")
		org.shock = org.shock + dmg * 40
		org.avgpain = org.avgpain + dmg * 30
		if oldDmg != 1 then
			playBoneFractureSound(org.owner)
			if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1) end
		end
	end

	org.shock = org.shock + dmg * 3
	if dislocated then
		markBrokenBone(org, "ValveBiped.Bip01_Head1")
		org.shock = org.shock + dmg * 20
		org.avgpain = org.avgpain + dmg * 20
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

	if dmg > 0.2 and org.isPly then timer.Simple(0, function() hg.LightStunPlayer(org.owner, 1 + dmg) end) end
	sendHeadTraumaFlash(org, jawImpact, dmgInfo, jawDelta, (org.concussion or 0) - oldConcussion, 0, "jaw")
	return result, vecrand
end

hook.Add("CanListenOthers", "CantHaveShitInDetroit", function(output, input, isChat, teamonly, text)
	if IsValid(output) and (output.organism.jaw == 1 or output.organism.jawdislocation) and output:Alive() and (output:IsSpeaking() or isChat) then
		output.organism.painadd = output.organism.painadd + 2 * (output:IsSpeaking() and 1 or (isChat and 5 or 0))
		if output:GetInfoNum("hg_newthoughts", 0) <= 0 then output:Notify("My jaw is really hurting when I speak.", 60, "painfromjawspeak", 0, nil, Color(255, 210, 210)) end
	end
end)

input_list.skull = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet, impact)
	org._skullImpactThisHit = true
	local oldDmg = org.skull
	local oldConcussion = org.concussion or 0
	-- Use the pre-impact skull state so this hit cannot amplify itself merely by
	-- causing the fracture. The vulnerability applies to subsequent trauma.
	local cranialVulnerability, cranialTraumaMul = 0, 1
	if hg.organism.GetCranialTraumaFactors then
		cranialVulnerability, cranialTraumaMul = hg.organism.GetCranialTraumaFactors(oldDmg)
	end
	if isFistInflictor(dmgInfo) then dmg = dmg * fist_skull_damage_mul end
	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "skull", boneindex, dir, hit, ricochet)
	local inflictor = dmgInfo:GetInflictor()
	local rawDamageType = impact and impact.rawDamageType or dmgInfo:GetDamageType()
	local isStab = bit.band(rawDamageType, DMG_SLASH) != 0 and not (IsValid(inflictor) and inflictor.slash)
	local helmet = org.owner.armors and org.owner.armors["head"]
	local functionalHelmet = helmet and hg.armor.head and hg.armor.head[helmet]
		and not (org.owner.armors_broken and org.owner.armors_broken[helmet])
	local helmetApplied = (org.lastHeadArmorMitigation or 1) < 1

	if isStab and functionalHelmet and helmetApplied then
		org.skull = oldDmg
	end
	if isMelee(dmgInfo) and oldDmg < 1 and org.skull < 1 and dmg > 0.3 and dmg < 1.35 then result = 1 end

	hg.AddHarmToAttacker(dmgInfo, (org.skull - oldDmg) * 4, "Skull bone damage harm")
	local skullDelta = org.skull - oldDmg
	trySkullFractureHemorrhage(org, oldDmg, org.skull)
	markDamagedBone(org, "ValveBiped.Bip01_Head1", org.skull)
	if oldDmg < 0.6 and org.skull >= 0.6 then
		-- A displaced fracture opens superficial vessels: emit a visible burst
		-- immediately, rather than waiting for a later bullet wound effect.
		sendSkullFractureGore(org, dmgInfo, false)
	elseif oldDmg < 1 and org.skull >= 1 then
		-- The complete break is an open cranial wound and deserves the larger,
		-- wetter effect in addition to the guaranteed cerebral hemorrhage above.
		sendSkullFractureGore(org, dmgInfo, true)
	end

	if org.skull == 1 and oldDmg < 1 then
		markBrokenBone(org, "ValveBiped.Bip01_Head1")
		org.shock = org.shock + dmg * 40

		playSkullFractureSound(org.owner)
		sendThought(org, "Your skull is broken.", "thought_skull", 4, Color(255, 180, 180))
	end

	org.shock = org.shock + dmg * 3
	local penetratingHeadHit = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
	-- Bullet brain injury is limited to traced brain hitboxes and newly exposed
	-- skull trauma. Blunt impacts become deterministic once they are severe.
	local bluntHeadImpact = isBluntBrainImpact(dmgInfo)
	local severeBluntHeadImpact = bluntHeadImpact and dmg >= 0.35
	local brainImpact = bluntHeadImpact and (severeBluntHeadImpact or math.random(10) == 1)
	org.consciousness = math.Approach(org.consciousness, 0, brainImpact and dmg * 2 or 0)
	local brainExposure = math.Clamp(((org.skull or 0) - 0.6) / 0.4, 0, 1)
	local bluntBrainDamage = 0
	-- A bullet that cracks the skull but narrowly misses a traced brain hitbox
	-- should not be consequence-free.  Transfer a small, regional amount of
	-- trauma for rifle-strength impacts.  The direct organ trace still owns the
	-- devastating/fatal cases; this specifically supplies the one-lobe injury
	-- outcome for survivable near-miss headshots.
	if penetratingHeadHit then
		local penetratingTrauma = math.max(dmg - 1, 0) * 0.08
		if penetratingTrauma > 0 then
			bluntBrainDamage = bluntBrainDamage + math.min(penetratingTrauma, 0.24)
		end
	end
	-- A hard club, bat, or punch can injure the brain without opening the skull.
	-- Scale this from impact energy so light taps remain concussion-only.
	if severeBluntHeadImpact then
		-- Once the skull is fractured, the same external impulse transfers more
		-- energy to intracranial contents. Strong hits remain energy-scaled rather
		-- than becoming a fixed "three-hit kill" counter.
		bluntBrainDamage = bluntBrainDamage + math.min(math.max(dmg - 0.35, 0) * 0.065, 0.28)
	end
	if brainExposure > 0 and brainImpact then
		bluntBrainDamage = bluntBrainDamage + dmg * 0.08 * Lerp(brainExposure, 0.35, 1)
	end
	if bluntBrainDamage > 0 and cranialVulnerability > 0 then
		bluntBrainDamage = bluntBrainDamage * cranialTraumaMul
	end

	if math.random(1, 4) == 1 then
		local eye_dmg = dmg * math.Rand(0.8, 1.5)
		if math.random(1, 2) == 1 then
			if hg.organism.input_list.eyeL then hg.organism.input_list.eyeL(org, bone, eye_dmg, dmgInfo) end
		else
			if hg.organism.input_list.eyeR then hg.organism.input_list.eyeR(org, bone, eye_dmg, dmgInfo) end
		end
	end

	local newlyExposedSkull = math.max((org.skull or 0) - math.max(oldDmg, 0.6), 0)
	if newlyExposedSkull > 0 then
		bluntBrainDamage = bluntBrainDamage + newlyExposedSkull * 0.25
	end

	local brainGain = 0
	local brainTraumaApplied = false
	if bluntBrainDamage > 0 then
		if isBluntBrainImpact(dmgInfo) and hg.organism.ApplyBluntBrainTrauma then
			-- With an intact skull, most blunt injury remains regional. As cranial
			-- structure fails, the same impact behaves increasingly like diffuse
			-- brain trauma, so repeated hard hits to a 1.0 skull become rapidly fatal.
			local regionalChance = Lerp(cranialVulnerability, 0.85, 0.15)
			brainGain = hg.organism.ApplyBluntBrainTrauma(org, bluntBrainDamage, dmgInfo, regionalChance)
			brainTraumaApplied = true
		else
			local brainBefore = org.brain or 0
			org.brain = math.min(brainBefore + bluntBrainDamage, 1)
			brainGain = math.max((org.brain or 0) - brainBefore, 0)
		end
	end

	if skullDelta > 0 or brainGain > 0 then
		-- Brain trauma adds its own concussion through ApplyBrainTraumaEffects;
		-- only the skull damage belongs in this bone-specific contribution.
		local concussionGain = math.min(skullDelta * skull_concussion_per_damage, 4.5)
		hg.organism.module.concussion.AddImmediateConcussion(org, concussionGain)
		org.consciousness = math.Approach(org.consciousness or 1, 0, skullDelta * 0.25)
		org.disorientation = (org.disorientation or 0) + skullDelta * 0.9
	end

	if brainGain > 0 and not brainTraumaApplied then
		if hg.organism.ApplyBrainTraumaEffects then
			hg.organism.ApplyBrainTraumaEffects(org, brainGain, dmgInfo)
		else
			org.consciousness = math.Approach(org.consciousness or 1, 0, brainGain * 2.5)
			org.disorientation = (org.disorientation or 0) + brainGain * 4
		end
	end

	-- Brain damage applies its stronger dizziness in the organ trauma handler;
	-- this roll represents the impact transmitted by the skull itself.
	if hg.organism.ApplyHeadTraumaDizziness then
		hg.organism.ApplyHeadTraumaDizziness(org, dmgInfo, math.max(skullDelta, dmg * 0.15), 0)
	end

	if org.brain >= 0.01 and math.random(3) == 1 and (brainImpact or skullDelta > 0.6) then
		org.shock = 70
		timer.Simple(0.1, function()
			local rag = hg.GetCurrentCharacter(org.owner)
			if IsValid(rag) and rag:IsRagdoll() then hg.applyFencingToPlayer(org.owner, org) end
		end)
	end

	if dmg > 0.4 and org.isPly then
		timer.Simple(0, function() hg.LightStunPlayer(org.owner, 1 + dmg) end)
	end

	org.shock = org.shock + (dmg > 1 and 50 or dmg * 10)
	if org.skull > 0.85 and oldDmg <= 0.85 then
		if org.isPly and IsValid(org.owner) and org.owner.Notify then org.owner:Notify(huyasd.skull, true, "skull", 4) end
	end
	org.disorientation = org.disorientation + dmg * 0.35
	sendHeadTraumaFlash(org, dmg, dmgInfo, skullDelta, (org.concussion or 0) - oldConcussion, brainGain, "skull")
	return result, vecrand
end

local ribs = {
	"My rib is broken.",
	"Why does it hurt this much to breathe...",
	"Something is stabbing my lung...",
	"I felt something snap in my chest...",
}

input_list.chest = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.chest
	local oldBrokenRibs = org.brokenribs or math.Round(oldDmg * 3)
	if dmgInfo:IsDamageType(DMG_SLASH + DMG_BULLET + DMG_BUCKSHOT) and math.random(5) == 1 then return 0, vector_origin end
	local result, vecrand = damageBone(org, 0.1, dmg / 4, dmgInfo, "chest", boneindex, dir, hit, ricochet, true)
	local chestDamageDelta = math.max(org.chest - oldDmg, 0)
	markDamagedBone(org, "ValveBiped.Bip01_Spine2", org.chest)
	hg.AddHarmToAttacker(dmgInfo, (org.chest - oldDmg) * 3, "Ribs bone damage harm")
	org.painadd = org.painadd + dmg * 1.5
	org.shock = org.shock + dmg* 1.5

	-- Rib/chest trauma bruises both lungs; blast overpressure amplifies the
	-- contusion. Hemothorax itself remains limited to a devastated chest with
	-- badly damaged lungs and substantial internal bleeding.
	if chestDamageDelta > 0 and org.lungsL and org.lungsR then
		local blast = dmgInfo:IsDamageType(DMG_BLAST)
		local chestSeverity = math.Clamp((org.chest - 0.2) / 0.8, 0, 1)
		local lungContusion = chestDamageDelta * Lerp(chestSeverity, 0.3, 0.8) * (blast and 1.8 or 1)
		org.lungsL[1] = math.min((org.lungsL[1] or 0) + lungContusion, 1)
		org.lungsR[1] = math.min((org.lungsR[1] or 0) + lungContusion, 1)
		org.internalBleed = (org.internalBleed or 0) + lungContusion * (blast and 1.5 or 0.75)

		local worstLung = math.max(org.lungsL[1], org.lungsR[1])
		if org.chest >= 0.9 and worstLung >= 0.65 and org.internalBleed >= 1.5 then
			org.hemothoraxTrauma = math.min((org.hemothoraxTrauma or 0) + chestDamageDelta * (blast and 0.2 or 0.1), 1)
		end
	end
	if oldBrokenRibs > 0 and math.Round(org.chest * 3) <= oldBrokenRibs and dmg >= 0.35 then addBrokenBoneHitTrauma(org, "chest", dmg * 0.35, 0.5) end

	if org.isPly and (not org.brokenribs or org.brokenribs ~= math.Round(org.chest * 3)) then
		org.brokenribs = math.Round(org.chest * 3)
		if org.brokenribs > 0 then
			//org.owner:Notify(ribs[math.random(#ribs)], 5, "ribs", 4)
			sendThought(org, "You broke " .. org.brokenribs .. " ribs.", "thought_ribs", 3, Color(255, 210, 210))

			playBoneFractureSound(org.owner)
			if hg.QueuePainScream then hg.QueuePainScream(org.owner, 0.8) end
			return math.min(0, result)
		end
	end

	return result * 0.5, vecrand
end

input_list.pelvis = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.pelvis
	org.painadd = org.painadd + dmg
	org.shock = org.shock + dmg
	local result = damageBone(org, bone, dmg * 0.5, dmgInfo, "pelvis", boneindex, dir, hit, ricochet)
	local pelvisDamageDelta = math.max((org.pelvis or 0) - oldDmg, 0)
	local blast = dmgInfo:IsDamageType(DMG_BLAST)
	local severeBlunt = dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL + DMG_VEHICLE)
		and pelvisDamageDelta >= 0.2
	if blast or severeBlunt then
		addBoneInternalBleed(org, pelvisDamageDelta * (blast and 4 or 2.5), blast and 4 or 2)
	end
	markDamagedBone(org, "ValveBiped.Bip01_Pelvis", org.pelvis)
	hg.AddHarmToAttacker(dmgInfo, (org.pelvis - oldDmg) / 2, "Pelvis bone damage harm")

	if org.isPly and org.pelvis == 1 then
		//org.owner:Notify("My pelvis is agonizingly hurting.", true, "pelvis", 4)
		sendThought(org, "Your pelvis is broken.", "thought_pelvis", 4, Color(255, 210, 210))
	end

	return result
end

input_list.rarmup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone * 1.25, dmg, dmgInfo, "rarm", "up", boneindex, dir, hit, ricochet) end
input_list.rarmdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone, dmg, dmgInfo, "rarm", "down", boneindex, dir, hit, ricochet) end
input_list.larmup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone * 1.25, dmg, dmgInfo, "larm", "up", boneindex, dir, hit, ricochet) end
input_list.larmdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone, dmg, dmgInfo, "larm", "down", boneindex, dir, hit, ricochet) end
input_list.rlegup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone * 1.25, dmg, dmgInfo, "rleg", "up", boneindex, dir, hit, ricochet) end
input_list.rlegdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg, dmgInfo, "rleg", "down", boneindex, dir, hit, ricochet) end
input_list.llegup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone * 1.25, dmg, dmgInfo, "lleg", "up", boneindex, dir, hit, ricochet) end
input_list.llegdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg, dmgInfo, "lleg", "down", boneindex, dir, hit, ricochet) end
input_list.spine1 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 1, boneindex, dir, hit, ricochet) end
input_list.spine2 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 2, boneindex, dir, hit, ricochet) end
input_list.spine3 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 3, boneindex, dir, hit, ricochet) end
