function hg.GetLimbDebuffMultiplier(org)
	local analgesia = math.Clamp((tonumber(org.analgesia) or 0) + (tonumber(org.painkiller) or 0) * 0.3, 0, 1)
	return Lerp(analgesia, 1, 0.35)
end

function hg.GetArmEffectiveness(ply, limb)
	local org = IsValid(ply) and ply.organism
	if not org then return 1 end

	local hand = limb == "larm" and "lhand" or "rhand"
	if org[limb .. "amputated"] or org[limb .. "upamputated"] or org[hand .. "amputated"] then return 0 end

	local damage = math.Clamp(tonumber(org[limb]) or 0, 0, 1)
	local effectiveness = damage < 0.25 and 1 or Lerp((damage - 0.25) / 0.75, 0.82, 0.12)
	if org[limb .. "dislocation"] or org[limb .. "dislocated"] then
		effectiveness = math.min(effectiveness, 0.18)
	end
	effectiveness = 1 - (1 - effectiveness) * hg.GetLimbDebuffMultiplier(org)

	local tourniquetCount = hg.GetTourniquetCountOnLimb and hg.GetTourniquetCountOnLimb(ply, limb) or 0
	if tourniquetCount == 1 then
		effectiveness = effectiveness * 0.55
	elseif tourniquetCount >= 2 then
		effectiveness = effectiveness * 0.18
	end

	return math.Clamp(effectiveness, 0, 1)
end

function hg.CanUseLeftHand(ply)
	local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply

	if IsValid(ply.FakeRagdoll) and ply:GetNWBool("hg_hold_wound_manual", false) then
		if hg.DebugTPIK then hg.DebugTPIK(ply, "lh_off", "wound_manual") end
		return false
	end

	if ent.organism and (ent.organism.larmamputated or ent.organism.lhandamputated or ent.organism.larmupamputated) then
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

	if ent.organism and (ent.organism.rarmamputated or ent.organism.rhandamputated or ent.organism.rarmupamputated) then
		if hg.DebugTPIK then hg.DebugTPIK(ply, "rh_off", "amputated") end
		return false
	end

	return true
end

function hg.GetPrioritizedArm(ply)
	if not IsValid(ply) or not ply.organism then return "left", false, false end

	local org = ply.organism
	local isBroken = ((org.larm and org.larm >= 1) or org.larmdislocation) == true
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
