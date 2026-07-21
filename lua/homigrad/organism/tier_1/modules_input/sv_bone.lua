local player_crush_amputation_threshold = 7

local function isCrush(dmgInfo)
	return (not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST)) or dmgInfo:GetInflictor().RubberBullets
end

local halfValue2 = util.halfValue2
local function damageBone(org, bone, dmg, dmgInfo, key, boneindex, dir, hit, ricochet, nodmgchange)
	local crush = isCrush(dmgInfo)

	dmg = dmg * (dmgInfo:GetInflictor().BreakBoneMul or 1)

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
		ent:EmitSound("owfuck" .. math.random(1, 9) .. ".ogg", volume or 75, 100, level or 1, CHAN_AUTO)
	else
		ent:EmitSound("newbonebreak/break" .. math.random(10) .. ".wav", volume or 75, math.random(120, 135), level or 1, CHAN_AUTO)
	end
end

local function playBoneFractureSound(ent)
	emitRandomBoneBreakSound(ent)
end

local function playRemorseismBoneBreakSound(ent, volume, level)
	if not IsValid(ent) then return end
	ent:EmitSound(bonefracture_sounds[math.random(#bonefracture_sounds)], volume or 75, math.random(135, 155), level or 1, CHAN_AUTO)
end

local function playSkullFractureSound(ent)
	if not IsValid(ent) then return end
	ent:EmitSound(skullfracture_sounds[math.random(#skullfracture_sounds)], 75, math.random(90, 110), 1, CHAN_AUTO)
end

local function addBoneInternalBleed(org, amount, cap)
	org.internalBleed = (org.internalBleed or 0) + math.Clamp(amount or 0, 0, cap or 1)
end

local function addBrokenBoneHitTrauma(org, key, dmg, soundThreshold)
	local severity = math.Clamp(dmg or 0, 0, 3)
	if severity <= 0 then return end

	org.painadd = (org.painadd or 0) + math.Clamp(severity * 7, 2, 18)
	addBoneInternalBleed(org, severity * 0.025, 0.12)

	if severity >= (soundThreshold or 0.45) then
		if (org._brokenBoneHitSound and org._brokenBoneHitSound[key] or 0) > CurTime() then return end
		org._brokenBoneHitSound = org._brokenBoneHitSound or {}
		org._brokenBoneHitSound[key] = CurTime() + 0.35
		playRemorseismBoneBreakSound(org.owner, 62, 0.55)
	end
end

local function sendSkullFractureGore(org, dmgInfo)
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
	net.WriteBool(false)
	net.Broadcast()
end

local huyasd = {
	["spine1"] = "I don't feel anything below my hips.",
	["spine2"] = "I cant't feel or move anything below my torso.",
	["spine3"] = "I can't move at all. I can barely even breathe.",
	["skull"] = "My head is aching.",
}

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
		if hg.fakeBoneFlop then hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, true) end
		if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() and hg.BreakLimb then hg.BreakLimb(org.owner, key, nil, false) end
		org.painadd = org.painadd + 55
		addBoneInternalBleed(org, 0.45, 0.8)
		org.owner:AddNaturalAdrenaline(1)
		org.immobilization = org.immobilization + dmg * 25
		org.fearadd = org.fearadd + 0.5
		timer.Simple(0, function() hg.LightStunPlayer(org.owner, 2) end)
		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.35) end
	else
		org[key .. "dislocation"] = true
		markBrokenBone(org, key == "lleg" and (segment == "up" and "ValveBiped.Bip01_L_Thigh" or "ValveBiped.Bip01_L_Calf") or (segment == "up" and "ValveBiped.Bip01_R_Thigh" or "ValveBiped.Bip01_R_Calf"))
		if hg.fakeBoneFlop then hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, true) end
		org.painadd = org.painadd + 35
		org.owner:AddNaturalAdrenaline(0.5)
		org.immobilization = org.immobilization + dmg * 10
		org.fearadd = org.fearadd + 0.5
		timer.Simple(0, function() hg.LightStunPlayer(org.owner, 2) end)
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
		return 0
	end

	local result, vecrand = damageBone(org, 0.3, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
	dmg = org[key]
	org[key] = org[key] * 0.5
	markDamagedBone(org, key == "larm" and (segment == "up" and "ValveBiped.Bip01_L_UpperArm" or "ValveBiped.Bip01_L_Forearm") or (segment == "up" and "ValveBiped.Bip01_R_UpperArm" or "ValveBiped.Bip01_R_Forearm"), dmg)

	if dmg < 0.6 then return 0 end
	if dmg < 1 and !dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL) then return 0 end

	if org.isPly and !org[key .. "amputated"] then org.just_damaged_bone = CurTime() end

	if dmg >= 1 and (!dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL) or math.random(3) != 1) then
		org[key] = 1
		markBrokenBone(org, key == "larm" and (segment == "up" and "ValveBiped.Bip01_L_UpperArm" or "ValveBiped.Bip01_L_Forearm") or (segment == "up" and "ValveBiped.Bip01_R_UpperArm" or "ValveBiped.Bip01_R_Forearm"))
		if hg.fakeBoneFlop then hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, true) end
		if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() and hg.BreakLimb then hg.BreakLimb(org.owner, key, nil, false) end
		org.painadd = org.painadd + 55
		addBoneInternalBleed(org, 0.35, 0.7)
		org.owner:AddNaturalAdrenaline(1)
		org.fearadd = org.fearadd + 0.5
		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.35) end
	else
		org[key .. "dislocation"] = true
		markBrokenBone(org, key == "larm" and (segment == "up" and "ValveBiped.Bip01_L_UpperArm" or "ValveBiped.Bip01_L_Forearm") or (segment == "up" and "ValveBiped.Bip01_R_UpperArm" or "ValveBiped.Bip01_R_Forearm"))
		if hg.fakeBoneFlop then hg.fakeBoneFlop.SetLimbSegmentState(org, key, segment, true) end
		org.painadd = org.painadd + 35
		org.owner:AddNaturalAdrenaline(0.5)
		org.fearadd = org.fearadd + 0.5
		playBoneFractureSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1) end
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
		if org.owner:IsPlayer() then org.owner:Notify(huyasd[name], true, name, 2) end
		org.painadd = org.painadd + 25
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

local input_list = hg.organism.input_list
local function isFistInflictor(dmgInfo)
	local inflictor = dmgInfo and dmgInfo.GetInflictor and dmgInfo:GetInflictor() or nil
	if not IsValid(inflictor) or not inflictor:IsWeapon() then return false end

	local class = inflictor:GetClass()
	return class == "weapon_hands_sh" or class == "weapon_hg_coolhands"
end

input_list.jaw = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.jaw
	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "jaw", boneindex, dir, hit, ricochet)
	local jawDelta = org.jaw - oldDmg
	markDamagedBone(org, "ValveBiped.Bip01_Head1", org.jaw)
	hg.AddHarmToAttacker(dmgInfo, jawDelta * 3, "Jaw bone damage harm")

	if jawDelta > 0 then
		org.concussion = math.min((org.concussion or 0) + math.min(jawDelta * 3, 2.25), 10)

		-- Normal jabs still build concussion through jaw damage. A high-damage fist
		-- strike (such as an uppercut) adds enough rotational trauma to knock out a
		-- target without bypassing an intact skull to damage the brain directly.
		if isFistInflictor(dmgInfo) then
			local fistImpact = math.Clamp(((dmgInfo:GetDamage() or 0) - 11) / 4, 0, 1)
			if fistImpact > 0 then
				org.concussion = math.min(org.concussion + 1 + fistImpact * 2, 10)
				org.consciousness = math.max((org.consciousness or 1) - fistImpact * 0.4, 0)
				if fistImpact >= 0.75 and org.concussion >= 3 then org.needfake = true end
			end
		end
	end

	if org.jaw == 1 and (org.jaw - oldDmg) > 0 and org.isPly then org.owner:Notify(jaw_broken_msg[math.random(#jaw_broken_msg)], true, "jaw", 2) end
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
		if org.isPly then org.owner:Notify(jaw_dislocated_msg[math.random(#jaw_dislocated_msg)], true, "jaw", 2) end
	end

	if dmg > 0.2 and org.isPly then timer.Simple(0, function() hg.LightStunPlayer(org.owner, 1 + dmg) end) end
	return result, vecrand
end

hook.Add("CanListenOthers", "CantHaveShitInDetroit", function(output, input, isChat, teamonly, text)
	if IsValid(output) and (output.organism.jaw == 1 or output.organism.jawdislocation) and output:Alive() and (output:IsSpeaking() or isChat) then
		output.organism.painadd = output.organism.painadd + 2 * (output:IsSpeaking() and 1 or (isChat and 5 or 0))
		output:Notify("My jaw is really hurting when I speak.", 60, "painfromjawspeak", 0, nil, Color(255, 210, 210))
	end
end)

input_list.skull = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.skull
	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "skull", boneindex, dir, hit, ricochet)
	hg.AddHarmToAttacker(dmgInfo, (org.skull - oldDmg) * 4, "Skull bone damage harm")
	local skullDelta = org.skull - oldDmg
	markDamagedBone(org, "ValveBiped.Bip01_Head1", org.skull)
	local brainBefore = org.brain or 0

	if org.skull == 1 then
		markBrokenBone(org, "ValveBiped.Bip01_Head1")
		org.shock = org.shock + dmg * 40
		org.avgpain = org.avgpain + dmg * 30
		if oldDmg != 1 then
			playSkullFractureSound(org.owner)
			playBoneFractureSound(org.owner)
			sendSkullFractureGore(org, dmgInfo)
			addBoneInternalBleed(org, 0.35, 0.55)
			if IsValid(org.owner) then org.owner:SetNWBool("SkullBrokenFully", true) end
		else
			addBrokenBoneHitTrauma(org, "skull", dmg, 0.3)
		end
	end

	org.shock = org.shock + dmg * 3
	local rnd = math.random(10) == 1 or dmgInfo:IsDamageType(DMG_CRUSH)
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

	if skullDelta > 0.6 then
		org.brain = math.min(org.brain + 0.1, 1)
	end

	local brainGain = math.max(org.brain - brainBefore, 0)
	if skullDelta > 0 or brainGain > 0 then
		local concussionGain = math.min(skullDelta * 3 + brainGain * 5, 3)
		org.concussion = math.min((org.concussion or 0) + concussionGain, 10)
	end

	if org.brain >= 0.01 and math.random(3) == 1 and (rnd or skullDelta > 0.6) then
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
	org.disorientation = org.disorientation + dmg
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
	markDamagedBone(org, "ValveBiped.Bip01_Spine2", org.chest)
	hg.AddHarmToAttacker(dmgInfo, (org.chest - oldDmg) * 3, "Ribs bone damage harm")
	org.painadd = org.painadd + dmg
	org.shock = org.shock + dmg
	if dmg >= 0.5 then org.hemothorax = math.min((org.hemothorax or 0) + dmg * 0.08, 1) end
	if oldBrokenRibs > 0 and math.Round(org.chest * 3) <= oldBrokenRibs and dmg >= 0.35 then addBrokenBoneHitTrauma(org, "chest", dmg * 0.35, 0.5) end

	if org.isPly and (not org.brokenribs or org.brokenribs ~= math.Round(org.chest * 3)) then
		org.brokenribs = math.Round(org.chest * 3)
		if org.brokenribs > 0 then
			markBrokenBone(org, "ValveBiped.Bip01_Spine2")
			if IsValid(org.owner) and org.owner:IsPlayer() then org.owner:Notify(ribs[math.random(#ribs)], 5, "ribs", 4) end
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
	addBoneInternalBleed(org, dmg * 4, 4)
	local result = damageBone(org, bone, dmg * 0.5, dmgInfo, "pelvis", boneindex, dir, hit, ricochet)
	markDamagedBone(org, "ValveBiped.Bip01_Pelvis", org.pelvis)
	hg.AddHarmToAttacker(dmgInfo, (org.pelvis - oldDmg) / 2, "Pelvis bone damage harm")
	if oldDmg >= 1 and dmg >= 0.35 then addBrokenBoneHitTrauma(org, "pelvis", dmg * 0.5, 0.45) end
	if org.pelvis >= 1 and oldDmg < 1 and ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() and hg.BreakSpine then hg.BreakSpine(org.owner, "spine1", false) end
	if org.pelvis >= 1 then markBrokenBone(org, "ValveBiped.Bip01_Pelvis") end
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
