function hg.GetLimbSegmentDamage(org, limb)
	if not org then return 0, 0 end
	local up, down = tonumber(org[limb .. "_up"]), tonumber(org[limb .. "_down"])
	if up == nil and down == nil then
		local aggregate = math.Clamp(tonumber(org[limb]) or 0, 0, 1)
		if aggregate > 0.75 then up = aggregate else down = aggregate / 0.75 end
	end
	return math.Clamp(up or 0, 0, 1), math.Clamp(down or 0, 0, 1)
end

function hg.IsLimbFractured(org, limb)
	local up, down = hg.GetLimbSegmentDamage(org, limb)
	return math.max(up, down) >= 1
end

function hg.IsLimbIncapacitated(org, limb)
	if not org then return false end
	local up, down = hg.GetLimbSegmentDamage(org, limb)
	local upBroken = up >= 0.95
	local downBroken = down >= 0.95
	local dislocated = org[limb .. "_up_disl"] or org[limb .. "_down_disl"] or org[limb .. "dislocation"] or org[limb .. "dislocated"]
	return upBroken and downBroken or dislocated and (upBroken or downBroken) or false
end

function hg.GetLimbDebuffMultiplier(org)
	local analgesia = math.Clamp((tonumber(org.analgesia) or 0) + (tonumber(org.painkiller) or 0) * 0.3, 0, 1)
	return Lerp(analgesia, 1, 0.35)
end

function hg.GetLimbEffectiveness(org, limb, segment)
	if not org then return 1 end
	if hg.IsLimbIncapacitated(org, limb) then return 0 end
	local leg = limb == "lleg" or limb == "rleg"
	local extremity = limb == "lleg" and "lfoot" or limb == "rleg" and "rfoot" or limb == "larm" and "lhand" or "rhand"
	if org[limb .. "upamputated"] or (segment ~= "up" and (org[limb .. "amputated"] or org[extremity .. "amputated"])) then return 0 end

	local up, down = hg.GetLimbSegmentDamage(org, limb)
	local upDislocated = org[limb .. "_up_disl"]
	local downDislocated = org[limb .. "_down_disl"]
	if (org[limb .. "dislocation"] or org[limb .. "dislocated"]) and not upDislocated and not downDislocated then upDislocated = true end

	local debuff = leg and 1 or hg.GetLimbDebuffMultiplier(org)
	local function strength(damage, dislocated)
		local mechanical = 1 - (leg and 0.9 or 0.88) * damage ^ 1.3
		local power = math.min(1 - (1 - mechanical) * debuff, 1 - damage ^ 4 * 0.75)
		return dislocated and math.min(power, leg and 0.15 or 0.18) or power
	end
	up, down = strength(up, upDislocated), strength(down, downDislocated)
	if segment == "up" then return up * (0.85 + down * 0.15) end
	if segment == "down" then return down * up ^ 0.5 end
	return up ^ (leg and 0.9 or 0.75) * down ^ (leg and 0.75 or 0.9)
end

function hg.GetArmEffectiveness(ply, limb, segment)
	local org = IsValid(ply) and ply.organism
	if not org then return 1 end

	local hand = limb == "larm" and "lhand" or "rhand"
	if org[limb .. "amputated"] or org[limb .. "upamputated"] or org[hand .. "amputated"] then return 0 end

	local effectiveness = hg.GetLimbEffectiveness(org, limb, segment)

	local tourniquetCount = hg.GetTourniquetCountOnLimb and hg.GetTourniquetCountOnLimb(ply, limb) or 0
	if tourniquetCount == 1 then
		effectiveness = effectiveness * 0.55
	elseif tourniquetCount >= 2 then
		effectiveness = effectiveness * 0.18
	end

	return math.Clamp(effectiveness, 0, 1)
end

function hg.GetThrowArmMultiplier(ply)
	return 0.35 + 0.65 * hg.GetArmEffectiveness(ply, "rarm")
end

function hg.CanUseLeftHand(ply)
	local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply

	if IsValid(ply.FakeRagdoll) and ply:GetNWBool("hg_hold_wound_manual", false)
		and (ply:GetNWBool("hg_hold_wound_twohand", false) or not ply:GetNWBool("hg_hold_wound_right", false)) then
		if hg.DebugTPIK then hg.DebugTPIK(ply, "lh_off", "wound_manual") end
		return false
	end

	if ent.organism and (ent.organism.larmamputated or ent.organism.lhandamputated or ent.organism.larmupamputated or hg.IsLimbIncapacitated(ent.organism, "larm")) then
		if hg.DebugTPIK then hg.DebugTPIK(ply, "lh_off", "amputated") end
		return false
	end

	local wep = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon()
	local Car = (ply.GetSimfphys and IsValid(ply:GetSimfphys()) and ply:GetSimfphys()) or (ply.GlideGetVehicle and IsValid(ply:GlideGetVehicle()) and ply:GlideGetVehicle()) or ply:GetVehicle()

	if (IsValid(Car) and hg.GetCarSteering(Car)) then
		holdingwheel = hg.GetCarSteering(Car) > 0
	end

	local chatgesture = (ply:GetTable().ChatGestureWeight or 0) > 0.1
	local tauntleft = ply:GetNWBool("TauntLeftHand", false) and ply:GetNWFloat("StartTaunt", 0) + 0.1 < CurTime()
	local flashlight = IsValid(ply.flashlight)
	local nothandcuffed = !ply:GetNetVar("handcuffed")
	local notreload = wep and not wep.reload
	local fingerpose = ent != ply and math.abs(ent:GetManipulateBoneAngles(ent:LookupBone("ValveBiped.Bip01_L_Finger11"))[2]) > 5 and !ply:InVehicle()
	local vehiclenowep = (ply:InVehicle() and (wep and not IsValid(wep)) and not wep.reload) and hg.isdriveablevehicle(ply:GetVehicle())

	if not ply.zmanipstart and hg.DebugTPIK then
		local reasons = {}
		if (chatgesture or tauntleft or flashlight) and nothandcuffed and notreload then
			if chatgesture then reasons[#reasons + 1] = "chat" end
			if tauntleft then reasons[#reasons + 1] = "taunt" end
			if flashlight then reasons[#reasons + 1] = "flashlight" end
		end
		if fingerpose then reasons[#reasons + 1] = "fingerpose" end
		if vehiclenowep then reasons[#reasons + 1] = "vehicle" end
		if #reasons > 0 then
			hg.DebugTPIK(ply, "lh_off", table.concat(reasons, ", "))
		end
	end

	return (not (((chatgesture or tauntleft or flashlight) and nothandcuffed and notreload) or (fingerpose) or (vehiclenowep))) or ply.zmanipstart
end

function hg.CanUseRightHand(ply)
	local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply

	if IsValid(ply.FakeRagdoll) and ply:GetNWBool("hg_hold_wound_right", false) then
		if hg.DebugTPIK then hg.DebugTPIK(ply, "rh_off", "wound_right") end
		return false
	end

	if ent.organism and (ent.organism.rarmamputated or ent.organism.rhandamputated or ent.organism.rarmupamputated or hg.IsLimbIncapacitated(ent.organism, "rarm")) then
		if hg.DebugTPIK then hg.DebugTPIK(ply, "rh_off", "amputated") end
		return false
	end

	return true
end

function hg.GetPrioritizedArm(ply)
	if not IsValid(ply) or not ply.organism then return "left", false, false end

	local org = ply.organism
	local isBroken = ((org.larm and hg.IsLimbFractured(org, "larm")) or org.larmdislocation) == true
	return "left", false, isBroken
end

function hg.earanim(ply)
	local plyTable = ply:GetTable()

	plyTable.ChatGestureWeight = plyTable.ChatGestureWeight || 0

	if (ply:IsPlayingTaunt()) then return end

	local wep = ply:GetActiveWeapon()

	if (ply:IsTyping()) or (ply:GetNetVar("flashlight", false) and (!wep.IsPistolHoldType or wep:IsPistolHoldType() or ply.PlayerClassName == "Gordon")) then
		plyTable.ChatGestureWeight = math.Approach(plyTable.ChatGestureWeight, 1, FrameTime() * 3.0)
	else
		plyTable.ChatGestureWeight = math.Approach(plyTable.ChatGestureWeight, 0, FrameTime() * 3.0)
	end

	if (plyTable.ChatGestureWeight > 0) then
		ply:AnimRestartGesture(GESTURE_SLOT_VCD, ACT_GMOD_IN_CHAT, true)
		ply:AnimSetGestureWeight(GESTURE_SLOT_VCD, plyTable.ChatGestureWeight)
	end
end
