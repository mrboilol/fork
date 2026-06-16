--local Organism = hg.organism

local function PlayBoneBreakSound(entity)
    if math.random() < 0.5 then
                        entity:EmitSound("owfuck"..math.random(1, 9)..".ogg", 75, 100, 1, CHAN_AUTO)
    else
        entity:EmitSound("newbonebreak/break"..math.random(10)..".wav", 75, math.random(120, 135), 1, CHAN_AUTO)
    end
end

local function CheckConcussionFlash(org, old_concussion, dmgInfo)
    if old_concussion < 1.5 and org.concussion >= 1.5 then
        net.Start("headtrauma_flash")
        net.WriteVector(dmgInfo:GetDamagePosition())
        net.WriteFloat(3.0) -- flash_intensity - more severe
        net.WriteInt(450, 20) -- flash_duration - longer
        net.WriteBool(true) -- is_critical
        net.WriteBool(false) -- play_knockout_sound
        net.Send(org.owner)
    end
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
		local oldHeadTrauma = org.headtrauma or 0
		org.headtrauma = math.min(oldHeadTrauma + dmg * 1.0, 2.0)
		-- Trigger severe headtrauma flash when headtrauma increases significantly
		if oldHeadTrauma < 0.5 and org.headtrauma >= 0.5 then
			net.Start("headtrauma_flash")
			net.WriteVector(dmgInfo:GetDamagePosition())
			net.WriteFloat(2.5)
			net.WriteInt(350, 20)
			net.WriteBool(true)
			net.WriteBool(false)
			net.Send(org.owner)
		end
	end

	return (crush and 1 * crush * math.max((1 - org[key]) ^ 0.1, 0.5) or (1 - org[key]) * (bone)), VectorRand(-0.2,0.2) / math.Clamp(dmg,0.4,0.8)
end

local huyasd = {
	["spine1"] = "My legs- i... i cant feel my legs...",
	["spine2"] = "I cant move my chest nor my legs, i think i broke something.",
	["spine3"] = "I cant move at all, much less breathe...",
	["skull"] = "My head hurts, my head hurts... why wont it stop...",
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

local function hasClimbGripActive(owner)
	if not IsValid(owner) or not owner:IsPlayer() then return false end

	local rag = owner.FakeRagdoll
	if not IsValid(rag) then return false end

	return (IsValid(rag.ConsLH) and rag.ConsLH.ZCClimbGrip) or (IsValid(rag.ConsRH) and rag.ConsRH.ZCClimbGrip)
end

local function legs(org, bone, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
	local oldDmg = org[key]
	local dmg = dmg * 3.25

	if dmgInfo:IsDamageType(DMG_SLASH) and dmg > 4 and !org[key.."amputated"] then
		hg.organism.AmputateLimb(org, key)

		return 0
	end

	if org[key] == 1 then return 0 end

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
		org.owner:AddNaturalAdrenaline(1)
		org.immobilization = org.immobilization + dmg * 25
		org.fearadd = org.fearadd + 0.5

		--if org.isPly and !org[key.."amputated"] then org.owner:Notify(broke_leg[math.random(#broke_leg)], 1, "broke"..key, 1, nil, nil) end

		timer.Simple(0, function() hg.LightStunPlayer(org.owner,2) end)
				PlayBoneBreakSound(org.owner)
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
		//dislocated
	end

	hg.AddHarmToAttacker(dmgInfo, (org[key] - oldDmg) * 2, "Legs bone damage harm")

	return result, vecrand
end

local function arms(org, bone, dmg, dmgInfo, key, boneindex, dir, hit, ricochet)
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

	if org[key] == 1 then return 0 end

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
		org.owner:AddNaturalAdrenaline(1)
		org.fearadd = org.fearadd + 0.5

		--if org.isPly and !org[key.."amputated"] then org.owner:Notify(broke_arm[math.random(#broke_arm)], 1, "broke"..key, 1, nil, nil) end

		--timer.Simple(0, function() hg.LightStunPlayer(org.owner,1) end)
				PlayBoneBreakSound(org.owner)
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
	"MY JAW, MY JAW IS BROKEN IN PIECES!",
	"MY JAW IS FUCKING FLOATING IN MY HEAD",
	"IM DISFIGURED- MY JAW IS ALL OVER THE PLACE!",
}

local jaw_dislocated_msg = {
	"JESUS CHRIST- I CAN FEEL MY JAW MUSCLES TUGGING AT MY SKULL",
	"MY JAW- I CANT MOVE MY JAW IT FUCKING HURTS",
	"MY JAW IS PAINING SO BAD, I CANT MOVE IT WITHOUT AGONIZINGLY HURTING",
	//"I CANT EVEN SPEAK, I NEED TO PUNCH IT BACK IN PLACE... BUT IT HURTS REAL BAD",
}

local input_list = hg.organism.input_list
input_list.jaw = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.jaw
	local old_concussion = org.concussion or 0

	local result, vecrand = damageBone(org, 0.25, dmg, dmgInfo, "jaw", boneindex, dir, hit, ricochet)

	hg.AddHarmToAttacker(dmgInfo, (org.jaw - oldDmg) * 3, "Jaw bone damage harm")

	if org.jaw == 1 and (org.jaw - oldDmg) > 0 and org.isPly then org.owner:Notify(jaw_broken_msg[math.random(#jaw_broken_msg)], true, "jaw", 2) end

	local dislocated = (org.jaw - oldDmg) > math.Rand(0.2, 0.4)

	if org.jaw == 1 then
		org.shock = org.shock + dmg * 40
		org.avgpain = org.avgpain + dmg * 30

if oldDmg != 1 then PlayBoneBreakSound(org.owner) end
	end

	org.shock = org.shock + dmg * 3
	    org.concussion = math.min((org.concussion or 0) + dmg * 8, 10) -- Increased from 4 to 8

	-- Chance to induce vomiting from jaw trauma
	if org.isPly and math.random() < dmg * 0.2 then
		org.wantToVomit = (org.wantToVomit or 0) + math.Rand(0.2, 0.5)
		org.vomitTypeHeadTrauma = math.random(10) == 1
	end

    -- Slight disorientation and consciousness loss
    org.disorientation = org.disorientation + dmg * 1.5 -- Increased from 0.5 to 1.5
    org.consciousness = math.max(org.consciousness - dmg * 0.15, 0) -- Increased from 0.05 to 0.15

    -- Add more concussion for significant damage
    if dmg > 0.2 then
        org.concussion = math.min((org.concussion or 0) + dmg * 4, 10) -- Increased from 2 to 4
    end

	if dislocated then
		org.shock = org.shock + dmg * 20
		org.avgpain = org.avgpain + dmg * 20
		
		if !org.jawdislocation then
PlayBoneBreakSound(org.owner)
		end

		org.jawdislocation = true

		if org.isPly then org.owner:Notify(jaw_dislocated_msg[math.random(#jaw_dislocated_msg)], true, "jaw", 2) end
	end

	if dmg > 0.2 then
		if org.isPly then timer.Simple(0, function() hg.LightStunPlayer(org.owner,1 + dmg) end) end
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

	CheckConcussionFlash(org, old_concussion, dmgInfo)
	return result, vecrand
end

hook.Add("CanListenOthers", "CantHaveShitInDetroit", function(output, input, isChat, teamonly, text)
	if IsValid(output) and output:Alive() and (output.organism.jaw == 1 or output.organism.jawdislocation) and (output:IsSpeaking() or isChat) then
        local pain_multiplier = 1
        if output.organism.jaw == 1 and output.organism.jawdislocation then
            pain_multiplier = 2.5 -- more pain
        end
        output.organism.painadd = output.organism.painadd + (2 * (output:IsSpeaking() and 1 or (isChat and 5 or 0))) * pain_multiplier
        if pain_multiplier > 1 then
            output:Notify("I CAN BARELY SPEAK WITH MY JAW LIKE THIS...", 60, "painfromjawspeak", 0, nil, Color(255, 150, 150))
        else
            output:Notify("FUUUUCK- IT HURTS REAL BAD WHEN SPEAKING", 60, "painfromjawspeak", 0, nil, Color(255, 210, 210))
        end
	end
end)

input_list.skull = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet)
	local oldDmg = org.skull
		local old_concussion = org.concussion or 0
	
	local result, vecrand = damageBone(org, 0.35, dmg, dmgInfo, "skull", boneindex, dir, hit, ricochet)

	hg.AddHarmToAttacker(dmgInfo, (org.skull - oldDmg) * 4, "Skull bone damage harm")

	if org.skull == 1 then
		org.shock = org.shock + dmg * 30
		org.avgpain = org.avgpain + dmg * 30

		if oldDmg != 1 then PlayBoneBreakSound(org.owner) end
		if IsValid(org.owner) then
			org.owner:SetNWBool("SkullBrokenFully", true)
		end
	end

	org.shock = org.shock + dmg * 3
		org.concussion = math.min((org.concussion or 0) + dmg * 6, 10)

	-- Chance to induce vomiting from head trauma
	if org.isPly and math.random() < dmg * 0.3 then
		org.wantToVomit = (org.wantToVomit or 0) + math.Rand(0.25, 0.6)
		org.vomitTypeHeadTrauma = math.random(8) == 1
	end

	local rnd = math.random(10) == 1 or dmgInfo:IsDamageType(DMG_CRUSH)
	org.consciousness = math.Approach(org.consciousness, 0, rnd and dmg * 2 or 0)

	org.brain = math.min(org.brain + (rnd and dmg * 0.05 or 0), 1)

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

	if dmg > 0.4 then
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
	
	org.shock = org.shock + (dmg > 1 and 45 or dmg * 9)

	if org.skull > 0.6 and oldDmg <= 0.6 then
		if org.isPly then
			org.owner:Notify(huyasd["skull"],true,"skull",4)
		end


		if dir and hg_bloodimpacts:GetBool() then
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
			if oldDmg ~= 1 then
				for i = 1, 3 do
					net.Start("hg_bloodimpact")
					net.WriteVector(dmgPos + VectorRand(-2, 2))
					net.WriteVector(dirNorm * 1.5 + VectorRand(-0.8, 0.8))
					net.WriteFloat(2)
					net.WriteInt(2, 8)
					net.Broadcast()
				end
			end
		end
	end

	org.disorientation = org.disorientation + (isCrush(dmgInfo) and dmg * 1 or dmg * 1)

	-- Accumulate head trauma for long-term stroke risk
	org.headtrauma = math.min((org.headtrauma or 0) + dmg * 0.6, 2.0)

	-- Trigger severe headtrauma flash on ANY brain damage from head hits
	local brainDamage = org.brain > 0
	if brainDamage and org.isPly then
		net.Start("headtrauma_flash")
		net.WriteVector(dmgInfo:GetDamagePosition())
		net.WriteFloat(3.5) -- More severe flash intensity
		net.WriteInt(500, 20) -- Longer flash duration
		net.WriteBool(true) -- is_critical
		net.WriteBool(false) -- play_knockout_sound
		net.WriteBool(true) -- hasBrainDamage - always true since we have brain damage
		net.Send(org.owner)
	end

	CheckConcussionFlash(org, old_concussion, dmgInfo)
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

	if dmgInfo:IsDamageType(DMG_SLASH+DMG_BULLET+DMG_BUCKSHOT) and math.random(5) == 1 then return 0, vector_origin end --random chance it passed through ribs

	local result, vecrand = damageBone(org, 0.15, dmg / 4, dmgInfo, "chest", boneindex, dir, hit, ricochet, true)
	
	hg.AddHarmToAttacker(dmgInfo, (org.chest - oldDmg) * 3, "Ribs bone damage harm")

	org.painadd = org.painadd + dmg * 2
	org.shock = org.shock + dmg * 2.5
	org.o2[1] = math.max(org.o2[1] - dmg * 12, 0)
	org.stamina_damage = (org.stamina_damage or 0) + dmg * 45
	org.oxygen_deprivation = (org.oxygen_deprivation or 0) + dmg * 25

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
			org.owner:Notify(ribs[math.random(#ribs)], 5, "ribs", 4)

					PlayBoneBreakSound(org.owner)
			
			-- Chance to puncture lung when ribs break
			local punctureChance = 0.25 + (org.brokenribs * 0.1) -- 25% base + 10% per broken rib
			if math.random() < punctureChance then
				local lungSide = math.random(2) == 1 and "lungsL" or "lungsR"
				local punctureSeverity = math.Rand(0.3, 0.7)
				org[lungSide][1] = math.min(org[lungSide][1] + punctureSeverity, 1)
				
				-- Chance to cause pneumothorax (collapsed lung)
				if math.random() < 0.4 then
					org[lungSide][2] = 1
					org.owner:Notify("My lung hurts a lot for some reason...", 8, "pneumothorax", 3)
				else
					org.owner:Notify("I felt it- i felt the rib poke my lung...", 6, "lungpuncture", 3)
				end
				
				-- Additional pain and shock from lung puncture
				org.painadd = org.painadd + 30
				org.shock = org.shock + 20
			end

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
	org.stamina_damage = (org.stamina_damage or 0) + dmg * 15
	org.oxygen_deprivation = (org.oxygen_deprivation or 0) + dmg * 5

	local result = damageBone(org, 0.35, dmg * 0.75, dmgInfo, "pelvis", boneindex, dir, hit, ricochet)
	
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

input_list.rarmup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone * 1.25, dmg, dmgInfo, "rarm", boneindex, dir, hit, ricochet) end
input_list.rarmdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone, dmg, dmgInfo, "rarm", boneindex, dir, hit, ricochet) end
input_list.larmup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone * 1.25, dmg, dmgInfo, "larm", boneindex, dir, hit, ricochet) end
input_list.larmdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return arms(org, bone, dmg, dmgInfo, "larm", boneindex, dir, hit, ricochet) end
input_list.rlegup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg * 1.25, dmgInfo, "rleg", boneindex, dir, hit, ricochet) end
input_list.rlegdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg, dmgInfo, "rleg", boneindex, dir, hit, ricochet) end
input_list.llegup = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg * 1.25, dmgInfo, "lleg", boneindex, dir, hit, ricochet) end
input_list.llegdown = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return legs(org, bone, dmg, dmgInfo, "lleg", boneindex, dir, hit, ricochet) end
input_list.spine1 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 1, boneindex, dir, hit, ricochet) end
input_list.spine2 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 2, boneindex, dir, hit, ricochet) end
input_list.spine3 = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, ricochet) return spine(org, bone, dmg, dmgInfo, 3, boneindex, dir, hit, ricochet) end

hook.Add("Fake", "ReapplyBrokenLimbConstraints", function(ply, ragdoll)
    if not IsValid(ply) or not ply.organism then return end
    if not (ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool()) then return end

    local org = ply.organism
    local limbs = {"larm", "rarm", "lleg", "rleg"}

    print("[HG Bone] Fake hook START: ply=" .. tostring(ply) .. " ragdoll=" .. tostring(ragdoll))
    print("[HG Bone] Org limb states: larm=" .. tostring(org["larm"]) .. " rarm=" .. tostring(org["rarm"]) .. " lleg=" .. tostring(org["lleg"]) .. " rleg=" .. tostring(org["rleg"]))
    print("[HG Bone] Org dislocation states: larm=" .. tostring(org["larmdislocation"]) .. " rarm=" .. tostring(org["rarmdislocation"]) .. " lleg=" .. tostring(org["llegdislocation"]) .. " rleg=" .. tostring(org["rlegdislocation"]))

    for _, limb in ipairs(limbs) do
        local isAmputated = org[limb .. "amputated"]
        local isBroken = org[limb] and org[limb] >= 1
        local isDislocated = org[limb .. "dislocation"]
        print("[HG Bone] Checking limb " .. limb .. ": isAmputated=" .. tostring(isAmputated) .. " isBroken=" .. tostring(isBroken) .. " isDislocated=" .. tostring(isDislocated))

        -- Skip constraints for amputated limbs
        if isAmputated then
            print("[HG Bone] Skipping " .. limb .. " - limb is amputated")
        elseif isBroken or isDislocated then
            -- OLD LUA: Use persisted segment if available (so same elbow stays broken across ragdolls)
            local segment = ply.HG_FloppyPersistSeg and ply.HG_FloppyPersistSeg[limb]
            print("[HG Bone] Reapplying floppy for " .. limb .. " with segment=" .. tostring(segment) .. " isDislocated=" .. tostring(isDislocated))
            hg.BreakLimb(ragdoll, limb, segment, isDislocated)
        elseif IsValid(ragdoll) then
            -- Constraints persist until next ragdoll - do not remove when limbs heal
            print("[HG Bone] Skipping constraint removal for healed limb " .. limb .. " - constraints persist until next ragdoll")
        end
    end

    -- Reapply neck floppy if spine3 is broken (neck broken)
    -- Use same threshold as damage code (> 0.75) for consistency
    -- Skip if head is amputated
    if org.spine3 and org.spine3 > 0.75 and IsValid(ragdoll) and not org.headamputated then
        print("[HG Bone] Fake hook: Reapplying neck floppy, spine3=" .. tostring(org.spine3))
        -- Use timer to ensure ragdoll physics are ready
        timer.Simple(0.1, function()
            if IsValid(ragdoll) and IsValid(ply) then
                print("[HG Bone] Fake hook timer: Calling BreakNeck for ragdoll")
                hg.BreakNeck(ragdoll, false) -- false = don't kill player, just reapply constraint
            end
        end)
    end

    -- Reapply spine1 / spine2 floppy if their thresholds are crossed
    -- spine1 covers the pelvis & lower spine, spine2 covers the back.
    if hg.BreakSpine and IsValid(ragdoll) then
        local fake1 = hg.organism and hg.organism.fake_spine1 or 1
        local fake2 = hg.organism and hg.organism.fake_spine2 or 1
        if (org.spine1 and org.spine1 >= fake1) or (org.pelvis and org.pelvis >= 1) then
            print("[HG Bone] Fake hook: Reapplying spine1 floppy")
            hg.BreakSpine(ragdoll, "spine1", false)
        end
        if org.spine2 and org.spine2 >= fake2 then
            print("[HG Bone] Fake hook: Reapplying spine2 floppy")
            hg.BreakSpine(ragdoll, "spine2", false)
        end
    end
end)

-- Reapply floppy/broken constraints to the corpse when the player dies
hook.Add("RagdollDeath", "ReapplyBrokenLimbConstraintsDeath", function(ply, ragdoll)
    local fakeHook = hook.GetTable()["Fake"] and hook.GetTable()["Fake"]["ReapplyBrokenLimbConstraints"]
    if fakeHook then
        fakeHook(ply, ragdoll)
    end
end)
