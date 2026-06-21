local boneToBodyPart = {
	["ValveBiped.Bip01_Head1"] = "head",
	["ValveBiped.Bip01_Neck1"] = "neck",
	["ValveBiped.Bip01_Spine2"] = "chest",
	["ValveBiped.Bip01_Spine1"] = "belly",
	["ValveBiped.Bip01_Spine"] = "groin",
	["ValveBiped.Bip01_L_UpperArm"] = "left arm",
	["ValveBiped.Bip01_L_Forearm"] = "left arm",
	["ValveBiped.Bip01_L_Hand"] = "left hand",
	["ValveBiped.Bip01_R_UpperArm"] = "right arm",
	["ValveBiped.Bip01_R_Forearm"] = "right arm",
	["ValveBiped.Bip01_R_Hand"] = "right hand",
	["ValveBiped.Bip01_L_Thigh"] = "left leg",
	["ValveBiped.Bip01_L_Calf"] = "left leg",
	["ValveBiped.Bip01_L_Foot"] = "left leg",
	["ValveBiped.Bip01_R_Thigh"] = "right leg",
	["ValveBiped.Bip01_R_Calf"] = "right leg",
	["ValveBiped.Bip01_R_Foot"] = "right leg",
}

local function GetWoundBodyPart(wound)
	if wound[7] then
		if wound[7] == "arteria" then return "neck" end
		if wound[7] == "rarmartery" then return "right arm" end
		if wound[7] == "larmartery" then return "left arm" end
		if wound[7] == "rlegartery" then return "right leg" end
		if wound[7] == "llegartery" then return "left leg" end
		if wound[7] == "spineartery" then return "chest" end
		return "body"
	else
		return boneToBodyPart[wound[4]] or "body"
	end
end

local function GetMostSevereWound(org)
	local maxSeverity = 0
	local target = nil
	local targetPart = nil

	-- Prioritize neck (carotid artery) wounds if any are bleeding
	for _, wound in pairs(org.arterialwounds) do
		if wound[7] == "arteria" and wound[1] > maxSeverity then
			maxSeverity = wound[1]
			target = wound[7]
			targetPart = GetWoundBodyPart(wound)
		end
	end

	if target then
		return target, targetPart, maxSeverity
	end

	for _, wound in pairs(org.arterialwounds) do
		if wound[1] > maxSeverity then
			maxSeverity = wound[1]
			target = wound[7]
			targetPart = GetWoundBodyPart(wound)
		end
	end

	for _, wound in pairs(org.wounds) do
		if wound[1] > maxSeverity then
			maxSeverity = wound[1]
			target = wound[4]
			targetPart = GetWoundBodyPart(wound)
		end
	end

	return target, targetPart, maxSeverity
end

local function IsWeaponCompatible(ply)
	return IsWeaponEntityCompatible(ply:GetActiveWeapon())
end
-- calc is short for calculator
local function CalculateEfficiency(org, target)
	local function getArmEff(armVal, amputated, dislocated, dislocation)
		if amputated then return 0.0 end
		if armVal >= 1 then return 0.3 end
		if dislocated or dislocation then return 0.6 end
		if armVal >= 0.25 then
			local severity = (armVal - 0.25) / 0.75
			return 1.0 - severity * 0.5
		end
		return 1.0
	end

	local larmEff = getArmEff(org.larm or 0, org.larmamputated, org.larmdislocated, org.larmdislocation)
	local rarmEff = getArmEff(org.rarm or 0, org.rarmamputated, org.rarmdislocated, org.rarmdislocation)

	if target == "arteria" then
		return math.Clamp((larmEff + rarmEff) / 2, 0, 1)
	end

	return math.Clamp(math.max(larmEff, rarmEff), 0, 1)
end

local function DisableWoundPressure(ply, org)
	if not org.pressingWound then return end
	org.pressingWound = false
	org.pressingWoundTarget = nil
	org.pressingWoundPart = nil
	org.pressingWoundEfficiency = 0
	org.pressingWoundRecalc = nil
	if org.pressingWoundOldPosture ~= nil then
		ply.posture = org.pressingWoundOldPosture
		org.pressingWoundOldPosture = nil
	end
end

local function IsWeaponEntityCompatible(wep)
	if not IsValid(wep) then return true end
	local class = wep:GetClass()
	if class == "weapon_hands_sh" then return true end

	if wep.IsPistolHoldType and wep:IsPistolHoldType() then return true end
	if wep.HoldType == "revolver" or wep.HoldType == "pistol" then return true end
	if wep.LHandPos == false then return true end

	if wep.TwoHanded == false then return true end
	if wep.TwoHanded == true then return false end

	local twohands = wep.TwoHands or (wep.HoldType and (wep.HoldType == "ar2" or wep.HoldType == "shotgun" or wep.HoldType == "smg" or wep.HoldType == "crossbow" or wep.HoldType == "rpg"))
	if twohands then return false end

	return true
end

hook.Add("PlayerSwitchWeapon", "HG_WoundPressureWeaponSwitch", function(ply, oldWep, newWep)
	if not ply.organism then return end
	if not ply.organism.pressingWound then return end
	if not IsWeaponEntityCompatible(newWep) then
		DisableWoundPressure(ply, ply.organism)
	end
end)

hook.Add("StartCommand", "HG_WoundPressure", function(ply, cmd)
	if not ply.organism then return end
	if not ply:Alive() then
		DisableWoundPressure(ply, ply.organism)
		return
	end

	local org = ply.organism

	if org.otrub or IsValid(ply.FakeRagdoll) then
		DisableWoundPressure(ply, org)
		return
	end

	if org.pressingWound then
		local hasBleeding = (#org.wounds > 0) or (#org.arterialwounds > 0)
		if not hasBleeding then
			DisableWoundPressure(ply, org)
			return
		end

		if not IsWeaponCompatible(ply) then
			DisableWoundPressure(ply, org)
			return
		end

		if (org.pressingWoundRecalc or 0) < CurTime() then
			org.pressingWoundRecalc = CurTime() + 0.5
			local newTarget, newPart, newSeverity = GetMostSevereWound(org)
			if newTarget and newSeverity > 0 then
				org.pressingWoundTarget = newTarget
				org.pressingWoundPart = newPart
				org.pressingWoundEfficiency = CalculateEfficiency(org, newTarget)
			else
				DisableWoundPressure(ply, org)
				return
			end
		end
	end

	if (org.pressingWoundNextToggle or 0) > CurTime() then return end

	if not (cmd:KeyDown(IN_WALK) and cmd:KeyDown(IN_USE)) then
		org._woundPressureKeyHeld = false
		return
	end

	if org._woundPressureKeyHeld then return end
	org._woundPressureKeyHeld = true
	org.pressingWoundNextToggle = CurTime() + 0.5

	if org.pressingWound then
		DisableWoundPressure(ply, org)
		return
	end

	local hasLeftArm = not org.larmamputated
	local hasRightArm = not org.rarmamputated

	if not hasLeftArm and not hasRightArm then
		return
	end

	local target, targetPart, severity = GetMostSevereWound(org)
	if not target or severity <= 0 then
		return
	end

	if not IsWeaponCompatible(ply) then
		return
	end

	if (hasLeftArm and not hasRightArm) or (hasRightArm and not hasLeftArm) then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() ~= "weapon_hands_sh" then
			return
		end
	end

	local efficiency = CalculateEfficiency(org, target)
	if efficiency <= 0 then
		return
	end

	org.pressingWound = true
	org.pressingWoundTarget = target
	org.pressingWoundPart = targetPart
	org.pressingWoundEfficiency = efficiency

	-- Make the weapon one-handed while pressing the wound
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) then
		org.pressingWoundOldPosture = ply.posture
		ply.posture = 8
	end
end)
