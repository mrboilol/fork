local hg_limp_style = CreateConVar("hg_limp_style", "2", {FCVAR_ARCHIVE}, "0=off, 1=zombie walk strong, 2=zombie walk mild, 3=bone only")

local limpActivities = {
	[1] = ACT_HL2MP_WALK_ZOMBIE_06,
	[2] = ACT_HL2MP_WALK_ZOMBIE_01,
}

local brokenBoneTbl = {
	["ValveBiped.Bip01_L_Thigh"] = {key = "lleg", ang = Angle(0, 14, 0)},
	["ValveBiped.Bip01_R_Thigh"] = {key = "rleg", ang = Angle(0, -14, 0)},
	["ValveBiped.Bip01_L_Calf"] = {key = "lleg", ang = Angle(0, 0, 24)},
	["ValveBiped.Bip01_R_Calf"] = {key = "rleg", ang = Angle(0, 0, -24)},
	["ValveBiped.Bip01_L_Foot"] = {key = "lleg", ang = Angle(0, 0, 26)},
	["ValveBiped.Bip01_R_Foot"] = {key = "rleg", ang = Angle(0, 0, -26)},
	["ValveBiped.Bip01_L_UpperArm"] = {key = "larm", ang = Angle(0, 0, 10)},
	["ValveBiped.Bip01_R_UpperArm"] = {key = "rarm", ang = Angle(0, 0, -10)},
	["ValveBiped.Bip01_L_Forearm"] = {key = "larm", ang = Angle(0, 0, -26)},
	["ValveBiped.Bip01_R_Forearm"] = {key = "rarm", ang = Angle(0, 0, 26)},
	["ValveBiped.Bip01_L_Hand"] = {key = "larm", ang = Angle(0, 0, -16)},
	["ValveBiped.Bip01_R_Hand"] = {key = "rarm", ang = Angle(0, 0, 16)},
}

local zeroAng = Angle(0, 0, 0)
local boneLayer = "brokenlimbs"
local spineLayer = "brokenlimbs_limp"
local limpSpineAng = Angle(0, 10, 0)
local LIMP_START_SPEED = 60
local LIMP_HOLD_TIME = 0.5
local LIMP_BLEND_SPEED = 3

local function applyBoneVisuals(ply, org)
	ply.hg_BrokenLimbBones = ply.hg_BrokenLimbBones or {}
	local applied = {}
	for boneName, data in pairs(brokenBoneTbl) do
		local key = data.key
		if hg.IsLimbFractured(org, key) and not org[key .. "amputated"] then
			local bid = ply:LookupBone(boneName)
			if bid then
				hg.bone.Set(ply, bid, vector_origin, data.ang, boneLayer)
				applied[bid] = true
				ply.hg_BrokenLimbBones[bid] = true
			end
		end
	end
	for bid in pairs(ply.hg_BrokenLimbBones) do
		if not applied[bid] then
			hg.bone.Set(ply, bid, vector_origin, zeroAng, boneLayer)
			ply.hg_BrokenLimbBones[bid] = nil
		end
	end
end

local function clearBoneVisuals(ply)
	ply.hg_LimpBlend = 0
	ply.hg_LimpUntil = nil
	if ply.hg_LimpSpine then
		hg.bone.Set(ply, ply.hg_LimpSpine, vector_origin, zeroAng, spineLayer)
		ply.hg_LimpSpine = nil
	end

	if ply.hg_BrokenLimbBones then
		for bid in pairs(ply.hg_BrokenLimbBones) do
			hg.bone.Set(ply, bid, vector_origin, zeroAng, boneLayer)
		end
		ply.hg_BrokenLimbBones = nil
	end
end

hook.Add("CalcMainActivity", "hgBrokenLimbVisuals", function(ply, vel)
	if not IsValid(ply) then return end
	if not ply:Alive() then
		clearBoneVisuals(ply)
		return
	end
	local org = ply.organism
	if not org then
		clearBoneVisuals(ply)
		return
	end

	local brokenLeg = hg.IsLimbFractured(org, "lleg") or hg.IsLimbFractured(org, "rleg") or org.llegdislocation or org.rlegdislocation
	local brokenArm = hg.IsLimbFractured(org, "larm") or hg.IsLimbFractured(org, "rarm")
	local style = hg_limp_style:GetInt()
	if style == 0 or (not brokenLeg and not brokenArm) then
		clearBoneVisuals(ply)
		return
	end

	applyBoneVisuals(ply, org)

	local now = UnPredictedCurTime()
	local canLimp = brokenLeg and not ply:Crouching() and not ply:InVehicle() and ply:IsOnGround()
	if canLimp and vel and vel:Length2D() > LIMP_START_SPEED then
		ply.hg_LimpUntil = now + LIMP_HOLD_TIME
	end
	local limping = canLimp and (ply.hg_LimpUntil or 0) > now

	local dt = math.Clamp(now - (ply.hg_LimpBlendTime or now), 0, 0.1)
	ply.hg_LimpBlendTime = now
	ply.hg_LimpBlend = math.Approach(ply.hg_LimpBlend or 0, limping and 1 or 0, dt * LIMP_BLEND_SPEED)

	if ply.hg_LimpBlend > 0 then
		local spineBid = ply.hg_LimpSpine or ply:LookupBone("ValveBiped.Bip01_Spine")
		if spineBid then
			local blend = ply.hg_LimpBlend
			hg.bone.Set(ply, spineBid, vector_origin, limpSpineAng * (blend * blend * (3 - 2 * blend)), spineLayer)
			ply.hg_LimpSpine = spineBid
		end
	elseif ply.hg_LimpSpine then
		hg.bone.Set(ply, ply.hg_LimpSpine, vector_origin, zeroAng, spineLayer)
		ply.hg_LimpSpine = nil
	end

	if limping and (style == 1 or style == 2) then
		return limpActivities[style], 0
	end
end)
