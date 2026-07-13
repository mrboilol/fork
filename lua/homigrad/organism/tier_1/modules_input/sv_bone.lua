--local Organism = hg.organism
if SERVER then util.AddNetworkString("headtrauma_flash") end

local hg_bloodimpacts = ConVarExists("hg_bloodimpacts") and GetConVar("hg_bloodimpacts") or CreateConVar("hg_bloodimpacts", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable custom blood impact effects spray cool kill death", 0, 1)

local bonefracture_sounds = {
	"bonefracture/rem_bonebreak1.wav",
	"bonefracture/rem_bonebreak2.wav",
	"bonefracture/rem_bonebreak3.wav",
}

local function EmitRandomBoneBreakSound(entity, volume, level)
	if not IsValid(entity) then return end

	local soundType = math.random(3)
	if soundType == 1 then
		entity:EmitSound(bonefracture_sounds[math.random(#bonefracture_sounds)], volume or 75, math.random(135, 155), level or 1, CHAN_AUTO)
	elseif soundType == 2 then
		entity:EmitSound("owfuck"..math.random(1, 9)..".ogg", volume or 75, 100, level or 1, CHAN_AUTO)
	else
		entity:EmitSound("newbonebreak/break"..math.random(10)..".wav", volume or 75, math.random(120, 135), level or 1, CHAN_AUTO)
	end
end

local function PlayBoneBreakSound(entity)
    EmitRandomBoneBreakSound(entity)
end

local function PlayBrokenBoneHitSound(org, key, volume)
	if not org or not IsValid(org.owner) then return end

	org._brokenBoneHitSound = org._brokenBoneHitSound or {}
	if (org._brokenBoneHitSound[key] or 0) > CurTime() then return end
	org._brokenBoneHitSound[key] = CurTime() + 0.35

	EmitRandomBoneBreakSound(org.owner, volume or 62, 0.55)
end

local function AddBoneInternalBleed(org, amount, cap)
	if not org then return end

	org.internalBleed = (org.internalBleed or 0) + math.Clamp(amount or 0, 0, cap or 1)
end

local function AddBrokenBoneHitTrauma(org, key, dmg, soundThreshold)
	if not org then return end

	local severity = math.Clamp(dmg or 0, 0, 3)
	if severity <= 0 then return end

	org.painadd = (org.painadd or 0) + math.Clamp(severity * 7, 2, 18)
	AddBoneInternalBleed(org, severity * 0.025, 0.12)

	if severity >= (soundThreshold or 0.45) then
		PlayBrokenBoneHitSound(org, key)
	end
end

local function IsSharpHeadDamage(dmgInfo)
	return dmgInfo and dmgInfo:IsDamageType(DMG_SLASH)
end

local function GetHeadConcussionScale(dmgInfo)
	if IsSharpHeadDamage(dmgInfo) then return 0.25 end
	if dmgInfo and dmgInfo:IsDamageType(DMG_GENERIC) then return 0.55 end

	return 1
end

local function hasClimbGripActive(ply)
	if not IsValid(ply) then return false end

	local ragdoll = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply.FakeRagdollOld
	if not IsValid(ragdoll) then return false end

	return (IsValid(ragdoll.ConsLH) and ragdoll.ConsLH.ZCClimbGrip)
		or (IsValid(ragdoll.ConsRH) and ragdoll.ConsRH.ZCClimbGrip)
end

local function SendHeadTraumaFlash(org, dmg, dmgInfo, boneDelta, oldConcussion, oldBrain, oldHeadTrauma, traumaBone)
    if not org.isPly then return end
    local targetPlayer = org.owner
    if IsValid(org.owner.FakeRagdoll) then
        local ragdoll = org.owner.FakeRagdoll
        if IsValid(ragdoll.ply) then targetPlayer = ragdoll.ply end
    end
    if not IsValid(targetPlayer) or not targetPlayer:IsPlayer() then return end

    targetPlayer.HeadDisorientFlashCooldown = targetPlayer.HeadDisorientFlashCooldown or 0
    if targetPlayer.HeadDisorientFlashCooldown >= CurTime() then return end

    local newConcussion = org.concussion or 0
    local newBrain = org.brain or 0
    local newHeadTrauma = org.headtrauma or 0

    local hasBrainDamage = newBrain > 0.1 and oldBrain <= 0.1
    local hasConcussion = newConcussion >= 1.5 and newConcussion > oldConcussion
    local isSevereTrauma = oldHeadTrauma < 0.5 and newHeadTrauma >= 0.5

    local isCritical = hasBrainDamage or hasConcussion or isSevereTrauma
    boneDelta = math.max(boneDelta or 0, 0)

    local baseTime, baseSize, cooldown
    if traumaBone == "jaw" then
        if dmg < 0.35 or boneDelta <= 0.15 then return end
        baseTime = math.Clamp(0.25 + boneDelta * 0.8, 0.25, 1.0)
        baseSize = math.Clamp(1400 + boneDelta * 1400, 1200, 2800)
        cooldown = 0.8
    else
        if boneDelta <= 0.02 and dmg < 0.35 then return end
        baseTime = math.Clamp(0.3 + boneDelta * 0.9, 0.3, 1.2)
        baseSize = math.Clamp(1400 + boneDelta * 1600, 1400, 3000)
        cooldown = 0.2
    end

    local eyePos = targetPlayer:EyePos()
    local ang = targetPlayer:EyeAngles()
    local incomingPos = dmgInfo:GetDamagePosition()
    local worldPos = eyePos + ang:Forward() * 16
    if incomingPos and incomingPos ~= vector_origin then
        local incDir = (incomingPos - eyePos):GetNormalized()
        local dotRight = ang:Right():Dot(incDir)
        worldPos = eyePos + ang:Right() * (dotRight * 160) + ang:Forward() * 16
    end

    net.Start("headtrauma_flash")
    net.WriteVector(worldPos)
    net.WriteFloat(baseTime)
    net.WriteInt(baseSize, 20)
    net.WriteBool(isCritical)
    net.WriteBool(false)
    net.WriteBool(hasBrainDamage)
    net.WriteBool(hasConcussion)
    net.WriteBool(isCritical and dmg >= 0.05)
    net.Send(targetPlayer)

    if isCritical then
        local disorientationAdd = math.Clamp(dmg * (hasBrainDamage and 2.0 or 1.5), 0.1, 3.0)
        org.disorientation = math.min((org.disorientation or 0) + disorientationAdd, 10)
    end

    targetPlayer.HeadDisorientFlashCooldown = CurTime() + cooldown
end

local function isCrush(dmgInfo)
	return (not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST)) or dmgInfo:GetInflictor().RubberBullets
end

local halfValue2 = util.halfValue2
local function damageBone(org, bone, dmg, dmgInfo, key, boneindex, dir, hit, ricochet, nodmgchange)
	local crush = isCrush(dmgInfo)
	
	if dmgInfo:IsDamageType(DMG_SLASH) and dmg > 1.5 then
		//crush = false
	end
	
	dmg = dmg * (dmgInfo:GetInflictor().BreakBoneMul or 1)
	
	if crush then
		crush = halfValue2(1 - org[key], 1, 0.5)
		dmg = dmg / math.max(10 * crush * (bone or 1), 1)
		if dmgInfo:GetInflictor().RubberBullets then dmg = dmg * dmgInfo:GetInflictor().Penetration end
	end

	local val = org[key]
	org[key] = math.min(org[key] + dmg, 1)
	local scale = 1 - (org[key] - val)
	
	if !nodmgchange then dmgInfo:ScaleDamage(1 - (crush and 1 * crush * math.max((1 - org[key]) ^ 0.1, 0.5) or (1 - org[key]) * (bone))) end

	-- Track head trauma for long-term stroke risk
	if key == "skull" then
		org.headtrauma = math.min((org.headtrauma or 0) + dmg * 1.0, 2.0)
	end

	if hg.organism.AddBulletImpactBleeding then
		hg.organism.AddBulletImpactBleeding(org, dmgInfo, 1)
	end

	return (crush and 1 * crush * math.max((1 - org[key]) ^ 0.1, 0.5) or (1 - org[key]) * (bone)), VectorRand(-0.2,0.2) / math.Clamp(dmg,0.4,0.8)
end

local skullfracture_sounds = {
	"skullfracture/skullfracture-1.wav",
	"skullfracture/skullfracture-2.wav",
	"skullfracture/skullfracture-3.wav",
	"skullfracture/skullfracture-4.wav",
	"skullfracture/skullfracture-5.wav",
	"skullfracture/skullfracture-6.wav",
	"skullfracture/skullfracture-7.wav",
}

local function playSkullFractureSound(ent)
	if not IsValid(ent) then return end
	ent:EmitSound(skullfracture_sounds[math.random(#skullfracture_sounds)], 75, math.random(90, 110), 1, CHAN_AUTO)
end

local function PlayRepeatSkullFractureSound(org)
	if not org or not IsValid(org.owner) then return end
	if (org._skullFractureSound or 0) > CurTime() then return end

	org._skullFractureSound = CurTime() + 0.4
	playSkullFractureSound(org.owner)
end

local function SendSevereSkullGore(org, dmgInfo)
	local effectEnt = hg.GetCurrentCharacter(org.owner)
	if not IsValid(effectEnt) then effectEnt = org.owner end
	if not IsValid(effectEnt) then return end

	local force = dmgInfo:GetDamageForce()
	local ang = force:LengthSqr() > 0 and force:GetNormalized():Angle() or angle_zero
	net.Start("hg_brainmist")
	net.WriteEntity(effectEnt)
	net.WriteVector(dmgInfo:GetDamagePosition())
	net.WriteAngle(ang)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(true)
	net.Broadcast()
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

local function legs(org, bone, dmg, dmgInfo, key, segment, boneindex, dir, hit, ricochet)
	local oldDmg = org[key]
	local dmg = dmg * 3.25

	if dmgInfo:IsDamageType(DMG_SLASH) and dmg > 4 and !org[key.."amputated"] then
		hg.organism.AmputateLimb(org, key)

		return 0
	end

	if org[key] == 1 then
		AddBrokenBoneHitTrauma(org, key, dmg, 0.5)
		return 0
	end

	local result, vecrand = damageBone(org, 0.3, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
	
	local dmg = org[key]
	
	org[key] = org[key] * 0.5

	if dmg < 0.8 then return 0 end

	if org.isPly and !org[key.."amputated"] then org.just_damaged_bone = CurTime() end
	
	if dmg >= 1 then
		org[key] = 1

		print("[HG Bone] LEG BROKEN: key=" .. tostring(key) .. " owner=" .. tostring(org.owner))

		if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
			print("[HG Bone] Calling hg.BreakLimb for leg: key=" .. tostring(key))
			hg.BreakLimb(org.owner, key, nil, false) -- false = broken (not dislocated)
		end

		org.painadd = org.painadd + 55
		AddBoneInternalBleed(org, 0.45, 0.8)
		org.owner:AddNaturalAdrenaline(1)
		org.immobilization = org.immobilization + dmg * 25
		org.fearadd = org.fearadd + 0.5

		--if org.isPly and !org[key.."amputated"] then org.owner:Notify(broke_leg[math.random(#broke_leg)], 1, "broke"..key, 1, nil, nil) end

		timer.Simple(0, function() hg.LightStunPlayer(org.owner,2) end)
		PlayBoneBreakSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.35) end
		//broken
	else
		--//org[key] = 0.5
		org[key.."dislocation"] = true

		print("[HG Bone] LEG DISLOCATED: key=" .. tostring(key) .. " owner=" .. tostring(org.owner))

		if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
			print("[HG Bone] Calling hg.BreakLimb for dislocated leg: key=" .. tostring(key))
			hg.BreakLimb(org.owner, key, nil, true) -- true = dislocated (will apply offset)
		end

		org.painadd = org.painadd + 35
		org.owner:AddNaturalAdrenaline(0.5)
		org.immobilization = org.immobilization + dmg * 10
		org.fearadd = org.fearadd + 0.5

		--if org.isPly and !org[key.."amputated"] then org.owner:Notify(dislocated_leg[math.random(#dislocated_leg)], 1, "dislocated"..key, 1, nil, nil) end

		timer.Simple(0, function() hg.LightStunPlayer(org.owner,2) end)
		PlayBoneBreakSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1) end
		//dislocated
	end

	hg.AddHarmToAttacker(dmgInfo, (org[key] - oldDmg) * 2, "Legs bone damage harm")

	return result, vecrand
end

local function arms(org, bone, dmg, dmgInfo, key, segment, boneindex, dir, hit, ricochet)
	local oldDmg = org[key]
	local dmg = dmg * 4
	local climbGrip = hasClimbGripActive(org.owner)

	if climbGrip and (dmgInfo:IsDamageType(DMG_CRUSH) or dmgInfo:IsDamageType(DMG_FALL)) then
		dmg = dmg * 0.35
	end
	
	if dmgInfo:IsDamageType(DMG_SLASH) and dmg > 4 and !org[key.."amputated"] then
		hg.organism.AmputateLimb(org, key)

		return 0
	end

	if org[key] == 1 then
		AddBrokenBoneHitTrauma(org, key, dmg, 0.5)
		return 0
	end

	local result, vecrand = damageBone(org, 0.3, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
	
	local dmg = org[key]
	local dislocationThreshold = climbGrip and 0.82 or 0.6
	
	org[key] = org[key] * 0.5

	if dmg < dislocationThreshold then return 0 end

	if org.isPly and !org[key.."amputated"] then org.just_damaged_bone = CurTime() end
	
	if dmg >= 1 then
		org[key] = 1

		print("[HG Bone] ARM BROKEN: key=" .. tostring(key) .. " owner=" .. tostring(org.owner))

		if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
			print("[HG Bone] Calling hg.BreakLimb for arm: key=" .. tostring(key))
			hg.BreakLimb(org.owner, key, nil, false) -- false = broken (not dislocated)
		end

		org.painadd = org.painadd + 55
		AddBoneInternalBleed(org, 0.35, 0.7)
		org.owner:AddNaturalAdrenaline(1)
		org.fearadd = org.fearadd + 0.5

		--if org.isPly and !org[key.."amputated"] then org.owner:Notify(broke_arm[math.random(#broke_arm)], 1, "broke"..key, 1, nil, nil) end

		--timer.Simple(0, function() hg.LightStunPlayer(org.owner,1) end)
		PlayBoneBreakSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.35) end
		//broken
	else
		org[key.."dislocation"] = true

		print("[HG Bone] ARM DISLOCATED: key=" .. tostring(key) .. " owner=" .. tostring(org.owner))

		if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
			print("[HG Bone] Calling hg.BreakLimb for dislocated arm: key=" .. tostring(key))
			hg.BreakLimb(org.owner, key, nil, true) -- true = dislocated (will apply offset)
		end

		--//org[key] = 0.5

		org.painadd = org.painadd + (climbGrip and 20 or 35)
		org.owner:AddNaturalAdrenaline(0.5)
		org.fearadd = org.fearadd + 0.5

		--if org.isPly and !org[key.."amputated"] then org.owner:Notify(dislocated_arm[math.random(#dislocated_arm)], 1, "dislocated"..key, 1, nil, nil) end

		--timer.Simple(0, function() hg.LightStunPlayer(org.owner,1) end)
		PlayBoneBreakSound(org.owner)
		if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1) end
		//dislocated
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
	if org[name] >= hg.organism[name2] then return 0 end
	local oldDmg = org[name]

	-- Heavy collision check for neck damage transfer to skull
	if name == "spine3" and isCrush(dmgInfo) and dmg > 0.3 and math.random() < 0.4 then
		-- Transfer full damage to skull (no reduction)
		local skullDmg = dmg
		org.spine3 = oldDmg -- Reset spine3 damage
		print("[HG Bone] Heavy collision: neck damage transferred to skull (full damage), original dmg=" .. tostring(dmg) .. " skull dmg=" .. tostring(skullDmg))
		
		-- Apply damage to skull
		local skullResult, skullVec = damageBone(org, 0.25, skullDmg, dmgInfo, "skull", boneindex, dir, hit, ricochet)
		hg.AddHarmToAttacker(dmgInfo, (org.skull - (org.skull - skullResult * 0.25)) * 2, "Skull damage from neck collision transfer")
		
		return skullResult, skullVec
	end

	local result, vecrand = damageBone(org, 0.1, isCrush(dmgInfo) and dmg * 2 or dmg * 2, dmgInfo, name, boneindex, dir, hit, ricochet)
	
	if name == "spine3" and org.spine3 > 0.75 and oldDmg <= 0.75 then
		print("[HG Bone] SPINE3 threshold crossed: spine3=" .. tostring(org.spine3) .. " oldDmg=" .. tostring(oldDmg) .. " dmg=" .. tostring(dmg))
		
		-- Calculate neck break death chance based on force (damage amount)
		-- Much higher force required to kill vs paralyze
		local forceMultiplier = isCrush(dmgInfo) and 2 or 1
		local effectiveDmg = dmg * forceMultiplier
		
		-- Scale chance: 0.05 (5%) at minimum force, up to 1.0 (100%) at very high force
		-- Requires significantly more force to reach lethal levels
		local deathChance = math.Clamp(0.05 + (effectiveDmg - 0.5) * 0.8, 0.05, 1.0)
		
		print("[HG Bone] Neck break death chance: " .. tostring(deathChance * 100) .. "% (effectiveDmg=" .. tostring(effectiveDmg) .. ")")
		
		if math.random() < deathChance then
			print("[HG Bone] NECK BREAK TRIGGERED from spine damage (fatal)")
			hg.BreakNeck(org.owner, true)
			return result, vecrand
		else
			print("[HG Bone] Neck break SURVIVED - spine3=" .. tostring(org.spine3))
		end
	end

	-- Trigger spine floppy when spine1 or spine2 reach their break threshold
	-- (broken-back / broken-pelvis effect)
	if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
		if (name == "spine1" or name == "spine2") and org[name] >= hg.organism[name2] and oldDmg < hg.organism[name2] then
			print("[HG Bone] " .. string.upper(name) .. " threshold crossed: calling BreakSpine")
			if hg.BreakSpine then
				hg.BreakSpine(org.owner, name, false)
			end
		end
	end

	hg.AddHarmToAttacker(dmgInfo, (org[name] - oldDmg) * 5, "Spine bone damage harm")
	
	if (name == "spine3" || name == "spine2") then
		hg.AddHarmToAttacker(dmgInfo, (org[name] - oldDmg) * 8, "Broken spine harm")
	end

	if org[name] >= hg.organism[name2] and org.isPly then
		PlayBoneBreakSound(org.owner)
		if hg.QueuePainScream then hg.QueuePainScream(org.owner, 1.1) end
		if org.owner:IsPlayer() then
			org.owner:Notify(huyasd[name], true, name, 2)
		end
		org.painadd = org.painadd + 25
	end
	
	if dmg > 0.2 then
		--org.owner:Notify("Your spinal cord is damaged.",true,"spinalcord",4)
	end

	org.painadd = org.painadd + dmg * 2
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

local input_list = hg.organism.input_list
input_list.jaw = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.jaw
	local old_concussion = org.concussion or 0
	local old_brain = org.brain or 0
	local old_headtrauma = org.headtrauma or 0
	local sharpHead = IsSharpHeadDamage(dmgInfo)
	local concussionMul = GetHeadConcussionScale(dmgInfo)
	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "jaw", boneindex, dir, hit, ricochet)

	hg.AddHarmToAttacker(dmgInfo, (org.jaw - oldDmg) * 3, "Jaw bone damage harm")

	if org.jaw == 1 and (org.jaw - oldDmg) > 0 and org.isPly then org.owner:Notify(jaw_broken_msg[math.random(#jaw_broken_msg)], true, "jaw", 2) end

	local jawDelta = math.max((org.jaw or 0) - oldDmg, 0)
	local dislocated = jawDelta > math.Rand(0.2, 0.4) and (not sharpHead or dmg > 1.2)

	if org.jaw == 1 then
		org.shock = org.shock + dmg * 40
		org.avgpain = org.avgpain + dmg * 30

		if oldDmg != 1 then
			PlayBoneBreakSound(org.owner)
			if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 1) end
		end
	end

	org.shock = org.shock + dmg * 3

	if dislocated then
		org.shock = org.shock + dmg * (sharpHead and 8 or 20)
		org.avgpain = org.avgpain + dmg * (sharpHead and 8 or 20)
		
		if !org.jawdislocation then
			PlayBoneBreakSound(org.owner)
			if org.isPly and hg.QueuePainScream then hg.QueuePainScream(org.owner, 0.85) end
		end

		org.jawdislocation = true

		if org.isPly then org.owner:Notify(jaw_dislocated_msg[math.random(#jaw_dislocated_msg)], true, "jaw", 2) end
	end

	if dmg * concussionMul > 0.2 then
		if org.isPly then timer.Simple(0, function() hg.LightStunPlayer(org.owner,1 + dmg) end) end
	end

	-- teeth: break one tooth on any jaw damage
	if jawDelta > 0 then
		if hg.organism and hg.organism.TeethOnJawDamage then
			hg.organism.TeethOnJawDamage(org, jawDelta, dmgInfo, boneindex)
		end
	end

	if dmg > 0 and dmgInfo:IsDamageType(DMG_CLUB) and math.random(3) == 1 then
		local effectEnt = hg.GetCurrentCharacter(org.owner)
		if not IsValid(effectEnt) then effectEnt = org.owner end
		net.Start("hg_brainmist")
		net.WriteEntity(effectEnt)
		net.WriteVector(dmgInfo:GetDamagePosition())
		net.WriteAngle(dmgInfo:GetDamageForce():GetNormalized():Angle())
		net.WriteBool(false)
		net.WriteBool(true)
		net.WriteBool(false)
		net.Broadcast()
	end

	SendHeadTraumaFlash(org, dmg, dmgInfo, org.jaw - oldDmg, old_concussion, old_brain, old_headtrauma, "jaw")
	return result, vecrand
end

hook.Add("CanListenOthers", "CantHaveShitInDetroit", function(output, input, isChat, teamonly, text)
	if IsValid(output) and (output.organism.jaw == 1 or output.organism.jawdislocation) and output:Alive() and (output:IsSpeaking() or isChat) then
		-- and !isChat and output:IsSpeaking()
		output.organism.painadd = output.organism.painadd + 2 * (output:IsSpeaking() and 1 or (isChat and 5 or 0))
		output:Notify("My jaw is really hurting when I speak.", 60, "painfromjawspeak", 0, nil, Color(255, 210, 210))
	end
end)

input_list.skull = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.skull
	local old_concussion = org.concussion or 0
	local old_brain = org.brain or 0
	local old_headtrauma = org.headtrauma or 0
	local sharpHead = IsSharpHeadDamage(dmgInfo)
	local concussionMul = GetHeadConcussionScale(dmgInfo)
	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "skull", boneindex, dir, hit, ricochet)

	hg.AddHarmToAttacker(dmgInfo, (org.skull - oldDmg) * 4, "Skull bone damage harm")

	if org.skull == 1 then
		org.shock = org.shock + dmg * (sharpHead and 14 or 30)
		org.avgpain = org.avgpain + dmg * (sharpHead and 20 or 30)

		if oldDmg != 1 then
			PlayBoneBreakSound(org.owner)
			AddBoneInternalBleed(org, 0.35, 0.55)
		else
			AddBrokenBoneHitTrauma(org, "skull", dmg, 0.3)
		end
		if IsValid(org.owner) then
			org.owner:SetNWBool("SkullBrokenFully", true)
		end
	end

	org.shock = org.shock + dmg * (sharpHead and 1.2 or 3)
		org.concussion = math.min((org.concussion or 0) + dmg * 6 * concussionMul, 10)

	-- Chance to induce vomiting from head trauma
	if org.isPly and math.random() < dmg * 0.3 * concussionMul then
		org.wantToVomit = (org.wantToVomit or 0) + math.Rand(0.25, 0.6)
		org.vomitTypeHeadTrauma = math.random(8) == 1
	end

	local rnd = (not sharpHead and math.random(10) == 1) or dmgInfo:IsDamageType(DMG_CRUSH)
	org.consciousness = math.Approach(org.consciousness, 0, rnd and dmg * 2 * concussionMul or 0)

	org.brain = math.min(org.brain + (rnd and dmg * 0.05 * concussionMul or 0), 1)

	if math.random(1, 4) == 1 then
		local eye_dmg = dmg * math.Rand(0.8, 1.5)
		if math.random(1, 2) == 1 then
			if hg.organism.input_list.eyeL then hg.organism.input_list.eyeL(org, bone, eye_dmg, dmgInfo) end
		else
			if hg.organism.input_list.eyeR then hg.organism.input_list.eyeR(org, bone, eye_dmg, dmgInfo) end
		end
	end

	if (org.skull - oldDmg) > 0.6 then
		org.brain = math.min(org.brain + 0.1, 1)
	end

	if org.brain >= 0.01 and math.random(3) == 1 and (rnd or (org.skull - oldDmg) > 0.6) then
		--hg.applyFencingToPlayer(org.owner, org)
		org.shock = 70

		timer.Simple(0.1, function()
			local rag = hg.GetCurrentCharacter(org.owner)


			if rag:IsRagdoll() then
				local stype = hg.getRandomSpasm()
				hg.applySpasm(rag, stype)
				if rag.organism then rag.organism.spasm, rag.organism.spasmType = true, stype end
			end
		end)
	end

	if dmg * concussionMul > 0.4 then
		if org.isPly then
			timer.Simple(0, function()
				hg.LightStunPlayer(org.owner,1 + dmg)
			end)
		end
	end
		if dmg > 0 and dmgInfo:IsDamageType(DMG_CLUB) and math.random(3) == 1 then
		local effectEnt = hg.GetCurrentCharacter(org.owner)
		if not IsValid(effectEnt) then effectEnt = org.owner end
		net.Start("hg_brainmist")
		net.WriteEntity(effectEnt)
		net.WriteVector(dmgInfo:GetDamagePosition())
		net.WriteAngle(dmgInfo:GetDamageForce():GetNormalized():Angle())
		net.WriteBool(false)
		net.WriteBool(true)
		net.WriteBool(false)
		net.Broadcast()
	end
	
	org.shock = org.shock + (sharpHead and math.min(dmg * 8, 28) or (dmg > 1 and 45 or dmg * 9))

	if org.skull > 0.6 then
		if oldDmg <= 0.6 then
			playSkullFractureSound(org.owner)
			if org.isPly then org.owner:Notify(huyasd["skull"],true,"skull",4) end

			-- Really loud bonebreak on initial skull fracture
			if IsValid(org.owner) then
				org.owner:EmitSound("newbonebreak/break"..math.random(10)..".wav", 110, math.random(95, 115), 1, CHAN_AUTO)
			end

			-- Layer several random decals so a severe skull injury is visibly bloodier.
			if IsValid(org.owner) then
				org.owner.HG_HeadBloodDecal = true
				for i = 1, 3 do
					net.Start("hg_head_blood_decal")
					net.WriteEntity(hg.GetCurrentCharacter(org.owner))
					net.Broadcast()
				end
			end
		end
		if oldDmg > 0.6 and math.random(3) == 1 then
			PlayRepeatSkullFractureSound(org)
		end

		if oldDmg <= 0.6 or (dmg >= 0.4 and math.random(3) == 1) then
			SendSevereSkullGore(org, dmgInfo)
		end

		if dir and hg_bloodimpacts:GetBool() and (oldDmg <= 0.6 or math.random() < 0.75) then
			local dmgPos = dmgInfo:GetDamagePosition()
			local dirNorm = dir:GetNormalized()
			-- Main blood spray
			net.Start("hg_bloodimpact")
			net.WriteVector(dmgPos)
			net.WriteVector(dir / 10)
			net.WriteFloat(3)
			net.WriteInt(2, 8)
			net.Broadcast()
			-- Additional spray when skull just broke (oldDmg != 1)
			if oldDmg <= 0.6 and oldDmg ~= 1 then
				for i = 1, 3 do
					net.Start("hg_bloodimpact")
					net.WriteVector(dmgPos + VectorRand(-2, 2))
					net.WriteVector(dirNorm * 1.5 + VectorRand(-0.8, 0.8))
					net.WriteFloat(2)
					net.WriteInt(2, 8)
					net.Broadcast()
				end
			end

			-- Secondary bonebreak sound on every skull blood spray
			if IsValid(org.owner) then
				PlayBrokenBoneHitSound(org, "skull", 68)
			end
		end
	end

	org.disorientation = org.disorientation + dmg * math.max(concussionMul, 0.35)

	-- Accumulate head trauma for long-term stroke risk
	org.headtrauma = math.min((org.headtrauma or 0) + dmg * (sharpHead and 0.18 or 0.6), 2.0)

	SendHeadTraumaFlash(org, dmg, dmgInfo, org.skull - oldDmg, old_concussion, old_brain, old_headtrauma, "skull")

	return result * 0.75, vecrand
end

local ribs = {
	"I felt my torso snapping.",
	"I feel something sharp poking inside...",
	"I heard my chest break.",
	"I think one of my ribs is broken.",
}

input_list.chest = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)	
	local oldDmg = org.chest
	local oldBrokenRibs = org.brokenribs or math.Round(oldDmg * 3)

	if dmgInfo:IsDamageType(DMG_SLASH+DMG_BULLET+DMG_BUCKSHOT) and math.random(5) == 1 then return 0, vector_origin end --random chance it passed through ribs

	local result, vecrand = damageBone(org, 0.15, dmg / 4, dmgInfo, "chest", boneindex, dir, hit, ricochet, true)
	
	hg.AddHarmToAttacker(dmgInfo, (org.chest - oldDmg) * 3, "Ribs bone damage harm")

	org.painadd = org.painadd + dmg * 2
	org.shock = org.shock + dmg * 2.5
	org.o2[1] = math.max(org.o2[1] - math.min(dmg * 2.5, 6), 10)

	-- Chest hits can cause hemothorax (blood filling pleural cavity)
	if dmg >= 0.5 then
		org.hemothorax = math.min((org.hemothorax or 0) + dmg * 0.08, 1)
	end

	local currentBrokenRibs = math.Round(org.chest * 3)
	if oldBrokenRibs > 0 and currentBrokenRibs <= oldBrokenRibs and dmg >= 0.35 then
		AddBrokenBoneHitTrauma(org, "chest", dmg * 0.35, 0.5)
	end

	-- Rare chance of cardiac arrest from chest blunt trauma
	if dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH) and not dmgInfo:IsDamageType(DMG_SLASH + DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST) then
		local heartStopChance = 0
		if dmg >= 3 then
			heartStopChance = 0.025 -- 2.5% for hard blunt impacts
		else
			heartStopChance = 0.002 -- 0.2% for small hits
		end
		
		if math.random() < heartStopChance then
			org.heartstop = true
			if org.isPly then
				org.owner:Notify("o shittings", 8, "heartstop", 0)
			end
		end
	end

	if org.isPly and (not org.brokenribs or (org.brokenribs ~= math.Round(org.chest * 3))) then
		org.brokenribs = math.Round(org.chest * 3)
		
		if org.brokenribs > 0 then
			local owner = org.owner
			if IsValid(owner) and owner:IsPlayer() then
				owner:Notify(ribs[math.random(#ribs)], 5, "ribs", 4)
			end

			PlayBoneBreakSound(org.owner)
			if hg.QueuePainScream then hg.QueuePainScream(org.owner, 0.8) end

			return math.min(0, result)
		end
	end

	return result * 0.6, vecrand
end

input_list.pelvis = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.pelvis
	org.painadd = org.painadd + dmg * 1.5
	org.shock = org.shock + dmg * 1.5
	org.internalBleed = (org.internalBleed or 0) + dmg * 4.0
	org.o2[1] = math.max(org.o2[1] - dmg * 3, 0)
	local result = damageBone(org, 0.35, dmg * 0.75, dmgInfo, "pelvis", boneindex, dir, hit, ricochet)

	if oldDmg >= 1 and dmg >= 0.35 then
		AddBrokenBoneHitTrauma(org, "pelvis", dmg * 0.5, 0.45)
	end
	
	hg.AddHarmToAttacker(dmgInfo, (org.pelvis - oldDmg) / 2, "Pelvis bone damage harm")

	if org.isPly and org.pelvis == 1 then
		org.owner:Notify("FUCKING HELL- MY ASS IS BACKWARDS, LITERALLY!", true, "pelvis", 4)
	end

	-- Pelvis broken -> apply spine1 floppy (pelvis & lower spine flop loose)
	if org.pelvis >= 1 and oldDmg < 1 then
		if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
			print("[HG Bone] PELVIS BROKEN: calling BreakSpine for spine1 (pelvis floppy)")
			if hg.BreakSpine then
				hg.BreakSpine(org.owner, "spine1", false)
			end
		end
	end

	return result * 0.75
end

input_list.rarmup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone * 1.25, dmg, dmgInfo, "rarm", "up", boneindex, dir, hit, ricochet) end
input_list.rarmdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone, dmg, dmgInfo, "rarm", "down", boneindex, dir, hit, ricochet) end
input_list.larmup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone * 1.25, dmg, dmgInfo, "larm", "up", boneindex, dir, hit, ricochet) end
input_list.larmdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone, dmg, dmgInfo, "larm", "down", boneindex, dir, hit, ricochet) end
input_list.rlegup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg * 1.25, dmgInfo, "rleg", "up", boneindex, dir, hit, ricochet) end
input_list.rlegdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg, dmgInfo, "rleg", "down", boneindex, dir, hit, ricochet) end
input_list.llegup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg * 1.25, dmgInfo, "lleg", "up", boneindex, dir, hit, ricochet) end
input_list.llegdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg, dmgInfo, "lleg", "down", boneindex, dir, hit, ricochet) end
input_list.spine1 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 1, boneindex, dir, hit, ricochet) end
input_list.spine2 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 2, boneindex, dir, hit, ricochet) end
input_list.spine3 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 3, boneindex, dir, hit, ricochet) end
