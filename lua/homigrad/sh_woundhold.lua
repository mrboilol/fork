hg.StandingWoundHold = hg.StandingWoundHold or {}
local SWH = hg.StandingWoundHold

SWH.HandsClasses = {
	weapon_hands_sh = true,
	weapon_hg_coolhands = true,
}

local boneKinds = {
	["ValveBiped.Bip01_Neck1"] = {"neck"},
	["ValveBiped.Bip01_Head1"] = {"neck"},
	["ValveBiped.Bip01_L_Hand"] = {"arm", "l", true},
	["ValveBiped.Bip01_L_Forearm"] = {"arm", "l", true},
	["ValveBiped.Bip01_L_UpperArm"] = {"arm", "l", false},
	["ValveBiped.Bip01_R_Hand"] = {"arm", "r", true},
	["ValveBiped.Bip01_R_Forearm"] = {"arm", "r", true},
	["ValveBiped.Bip01_R_UpperArm"] = {"arm", "r", false},
}

local arteryKinds = {
	arteria = {"neck"},
	larmartery = {"arm", "l", true},
	rarmartery = {"arm", "r", true},
}

function SWH.Classify(wound)
	if not wound then return end
	local kind = arteryKinds[wound[7]]
	if wound.vessel == "jugular" then kind = boneKinds["ValveBiped.Bip01_Neck1"] end
	return kind or (isstring(wound[4]) and boneKinds[wound[4]])
end

if SERVER then
	local arterialPriority = 14
	local switchMul = 1.5
	local minVenousSeverity = 10

	local function canGrip(ply, side)
		return hg.GetArmEffectiveness(ply, side .. "arm") > 0.05
	end

	local function canHold(ply, org)
		if not ply:Alive() or not org or not org.alive or org.otrub or not org.canmove then return false end
		if not ply:OnGround() or ply:InVehicle() then return false end

		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and not SWH.HandsClasses[wep:GetClass()] then return false end
		if IsValid(wep) and wep.GetFists and wep:GetFists() then return false end
		if IsValid(wep) and wep.GetIsCarrying and wep:GetIsCarrying() then return false end
		if IsValid(ply:GetNetVar("carryent")) or IsValid(ply:GetNetVar("carryent2")) then return false end
		if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) then return false end
		if hg.WallBang and hg.WallBang.Active(ply) then return false end

		local speed = ply:GetVelocity():Length2D()
		if ply:KeyDown(IN_SPEED) and speed > ply:GetWalkSpeed() * 0.5 then return false end

		return true
	end

	local function woundScore(ply, wound, arterial)
		local severity = tonumber(wound[1]) or 0
		if severity <= 0.001 or not arterial and wound.vessel ~= "jugular" and severity < minVenousSeverity then return end

		local score = severity * (arterial and arterialPriority or 1)
		if hg.GetBandageBleedMultiplier then score = score * hg.GetBandageBleedMultiplier(ply, wound[4]) end
		if hg.GetTourniquetBleedMultiplier then score = score * hg.GetTourniquetBleedMultiplier(ply, wound[4], arterial) end
		return score
	end

	local function gripHands(ply, kind)
		if kind[1] == "neck" then
			return (canGrip(ply, "l") and 1 or 0) + (canGrip(ply, "r") and 2 or 0)
		end

		local other = kind[2] == "l" and "r" or "l"
		if not canGrip(ply, other) then return 0 end
		return other == "l" and 1 or 2
	end

	local function pickWound(ply, org, current)
		local best, bestKind, bestHands, bestScore, bestArterial

		local function consider(wounds, arterial)
			for _, wound in ipairs(wounds or {}) do
				local kind = SWH.Classify(wound)
				if not kind then continue end

				local score = woundScore(ply, wound, arterial)
				if not score or score <= 0 then continue end

				local hands = gripHands(ply, kind)
				if hands == 0 then continue end

				if wound == current then score = score * switchMul end
				if not bestScore or score > bestScore then
					best, bestKind, bestHands, bestScore, bestArterial = wound, kind, hands, score, arterial
				end
			end
		end

		consider(org.wounds, false)
		consider(org.arterialwounds, true)

		return best, bestKind, bestHands, bestArterial
	end

	local function setNet(ply, hands, kind, wound)
		ply:SetNWInt("hg_standhold_hands", hands)
		if hands == 0 then return end

		ply:SetNWString("hg_standhold_kind", kind[1] == "neck" and "neck" or (kind[2] .. (kind[3] and "lower" or "upper")))
		ply:SetNWString("hg_standhold_bone", isstring(wound[4]) and wound[4] or "ValveBiped.Bip01_Neck1")
		ply:SetNWVector("hg_standhold_pos", isvector(wound[2]) and wound[2] or vector_origin)
	end

	local function release(ply, org)
		if not ply.hgStandingWoundHold then return end
		ply.hgStandingWoundHold = nil
		setNet(ply, 0)

		if org and org.manualHoldWound then
			org.manualHoldWound = false
			org.manualHoldWoundTarget = nil
			org.manualHoldWoundHands = 0
			org.manualHoldWoundStrength = 0
			org.manualHoldWoundUseRight = false
			org.manualHoldWoundArterial = false
		end
	end

	SWH.Release = release

	hook.Add("Player Think", "HG_StandingWoundHold", function(ply)
		local org = ply.organism

		if IsValid(ply.FakeRagdoll) then
			if ply.hgStandingWoundHold then
				ply.hgStandingWoundHold = nil
				setNet(ply, 0)
			end
			return
		end

		if not canHold(ply, org) then
			release(ply, org)
			return
		end

		local wound, kind, hands, arterial = pickWound(ply, org, ply.hgStandingWoundHold)
		if not wound then
			release(ply, org)
			return
		end

		local leftEff = bit.band(hands, 1) ~= 0 and hg.GetArmEffectiveness(ply, "larm") or 0
		local rightEff = bit.band(hands, 2) ~= 0 and hg.GetArmEffectiveness(ply, "rarm") or 0

		org.manualHoldWound = true
		org.manualHoldWoundTarget = wound
		org.manualHoldWoundHands = (leftEff > 0 and 1 or 0) + (rightEff > 0 and 1 or 0)
		org.manualHoldWoundUseRight = rightEff > 0
		org.manualHoldWoundArterial = arterial
		org.manualHoldWoundStrength = (leftEff + rightEff) / 2

		if ply.hgStandingWoundHold ~= wound or ply:GetNWInt("hg_standhold_hands", 0) ~= hands then
			ply.hgStandingWoundHold = wound
			setNet(ply, hands, kind, wound)
		end
	end)

	hook.Add("PlayerDeath", "HG_StandingWoundHold", function(ply)
		release(ply, ply.organism)
	end)

	hook.Add("PlayerSpawn", "HG_StandingWoundHold", function(ply)
		ply.hgStandingWoundHold = nil
		setNet(ply, 0)
	end)

	return
end

local holdEase = 0.35
local neckOut = 1.5
local neckSpread = 1.6
local wristFwd = 14
local wristUp = 7
local wristSide = 2
local gripBack = 3.5
local gripDown = 0.8
local gripSide = 1.5

local angLH = Angle(-135, -90, 180)
local angRH = Angle(-135, 90, 0)

local fingers = {
	{"Finger0", 0.5, true}, {"Finger01", 0.6, true}, {"Finger02", 0.5, true},
	{"Finger1", 1.0}, {"Finger11", 1.1}, {"Finger12", 0.55},
	{"Finger2", 1.0}, {"Finger21", 1.1}, {"Finger22", 0.55},
	{"Finger3", 0.95}, {"Finger31", 1.05}, {"Finger32", 0.55},
	{"Finger4", 0.9}, {"Finger41", 1.0}, {"Finger42", 0.5},
}
local fingerCurl = Angle(0, -72, 0)
local thumbGrip = Angle(-38, 35, 0)
local thumbFist = {l = Angle(0, 0, -80), r = Angle(0, 0, 80)}
local sideBones = {l = "ValveBiped.Bip01_L_", r = "ValveBiped.Bip01_R_"}

local function blendHand(ply, side, pos, ang, w)
	local id = ply:LookupBone(sideBones[side] .. "Hand")
	local mat = id and ply:GetBoneMatrix(id)
	if not mat then return end
	mat:SetTranslation(LerpVector(w, mat:GetTranslation(), pos))
	mat:SetAngles(LerpAngle(w, mat:GetAngles(), ang))
	hg.bone_apply_matrix(ply, id, mat)
end

local function woundWorldPos(ply, bone, lpos)
	local id = ply:LookupBone(bone)
	local mat = id and ply:GetBoneMatrix(id)
	if not mat then return end
	return LocalToWorld(lpos, angle_zero, mat:GetTranslation(), mat:GetAngles())
end

local function snapshot(ply)
	return {
		hands = ply:GetNWInt("hg_standhold_hands", 0),
		kind = ply:GetNWString("hg_standhold_kind", ""),
		bone = ply:GetNWString("hg_standhold_bone", ""),
		pos = ply:GetNWVector("hg_standhold_pos", vector_origin),
	}
end

function hg.WoundHoldTPIK(ent, ply, wpn)
	if ent ~= ply or not IsValid(wpn) then return end

	ply.hgStandHoldTPIKAt = CurTime()
	local holding = ply:GetNWInt("hg_standhold_hands", 0) ~= 0 and not IsValid(ply:GetNWEntity("FakeRagdoll"))
	if holding then ply.hgStandHoldLast = snapshot(ply) end

	ply.hgStandHoldEase = math.Approach(ply.hgStandHoldEase or 0, holding and 1 or 0, FrameTime() / holdEase)
	local w = math.ease.InOutSine(ply.hgStandHoldEase)
	local hold = ply.hgStandHoldLast
	if w <= 0 or not hold then
		ply.hgStandHoldLast = nil
		return
	end

	local yaw = Angle(0, ply:EyeAngles().y, 0)
	local fwd, right = yaw:Forward(), yaw:Right()
	local roles = {}

	if hold.kind == "neck" then
		local pos = woundWorldPos(ply, hold.bone, hold.pos)
		if not pos then return end
		pos = pos + fwd * neckOut

		local inAng = (-fwd):Angle()
		local _, lang = LocalToWorld(vector_origin, angLH, vector_origin, inAng)
		local _, rang = LocalToWorld(vector_origin, angRH, vector_origin, inAng)
		local both = hold.hands == 3

		if bit.band(hold.hands, 1) ~= 0 then
			blendHand(ply, "l", both and pos - right * neckSpread or pos, lang, w)
			wpn.lhandik = true
			roles.l = "grip"
		end
		if bit.band(hold.hands, 2) ~= 0 then
			blendHand(ply, "r", both and pos + right * neckSpread + vector_up * 1.2 or pos, rang, w)
			wpn.rhandik = true
			roles.r = "grip"
		end
	else
		local cut = string.sub(hold.kind, 1, 1)
		local grip = cut == "l" and "r" or "l"
		local sign = cut == "r" and 1 or -1
		local gripDir = right * sign

		if string.sub(hold.kind, 2) == "lower" then
			local head = ply:LookupBone("ValveBiped.Bip01_Head1")
			local headPos = head and ply:GetBonePosition(head)
			local origin = ply:GetPos()
			local baseZ = isvector(headPos) and headPos.z - 16 or origin.z + (ply:Crouching() and 36 or 48)
			if ply:Crouching() then baseZ = math.max(baseZ, origin.z + 32) end

			local wrist = Vector(origin.x, origin.y, baseZ) + fwd * wristFwd + vector_up * wristUp + right * (sign * wristSide)
			if isvector(headPos) then wrist.z = math.min(wrist.z, headPos.z - 4) end

			local gripPos = wrist - fwd * gripBack - vector_up * gripDown - right * (sign * gripSide)

			blendHand(ply, cut, wrist, (fwd - right * sign * 0.3):GetNormalized():AngleEx(vector_up), w)
			blendHand(ply, grip, gripPos, gripDir:AngleEx(vector_up), w)
			roles[cut] = "fist"
		else
			local pos = woundWorldPos(ply, hold.bone, hold.pos)
			if not pos then return end
			blendHand(ply, grip, pos, gripDir:AngleEx(vector_up), w)
		end

		roles[grip] = "grip"
		wpn.lhandik = true
		wpn.rhandik = true
	end

	ply.hgStandHoldRoles = roles
end

hook.Add("Bones", "HG_StandingWoundHoldFingers", function(ply, dtime)
	if (ply.hgStandHoldTPIKAt or 0) < CurTime() - 0.25 then ply.hgStandHoldEase = 0 end
	local w = math.ease.InOutSine(ply.hgStandHoldEase or 0)
	local roles = w > 0 and ply.hgStandHoldRoles or nil
	if not roles and not ply.hgStandHoldFingers then return end
	ply.hgStandHoldFingers = roles ~= nil

	for side, prefix in pairs(sideBones) do
		local role = roles and roles[side]
		for _, f in ipairs(fingers) do
			local ang = angle_zero
			if role == "grip" then
				ang = f[3] and thumbGrip * 0.62 or fingerCurl * (0.9 * f[2])
			elseif role == "fist" then
				ang = f[3] and thumbFist[side] * f[2] or fingerCurl * f[2]
			end
			hg.bone.Set(ply, prefix .. f[1], vector_origin, ang * w, "woundhold")
		end
	end
end)
