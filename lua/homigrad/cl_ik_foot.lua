-- TPIK-Compatible IK Foot System
-- Uses bone matrix manipulation to avoid conflicts with health indicator
local hg = hg or {}

-- Configuration
hg.IKFootConfig = {
	enabled = CreateClientConVar("hg_ik_foot_enabled", "1", true, false, "Enable IK Foot system"),
	groundDistance = CreateClientConVar("hg_ik_foot_ground_dist", "70", true, false, "Ground trace distance"),
	legLength = CreateClientConVar("hg_ik_foot_leg_length", "45", true, false, "Leg length for IK"),
	smoothing = CreateClientConVar("hg_ik_foot_smoothing", "0.15", true, false, "Smoothing factor (0-1)"),
	bodyDrop = CreateClientConVar("hg_ik_foot_body_drop", "0.3", true, false, "Body drop amount"),
	maxKneeBend = 68,
	minKneeBend = -30,
}

-- Per-player state
hg.IKFootState = hg.IKFootState or {}

local function GetIKState(ply)
	local id = ply:EntIndex()
	if not hg.IKFootState[id] then
		hg.IKFootState[id] = {
			leftFoot = { planted = false, lockPos = nil, targetPos = nil },
			rightFoot = { planted = false, lockPos = nil, targetPos = nil },
			bodyDrop = 0,
			bodyDropVel = 0,
			leftKnee = 0,
			rightKnee = 0,
			leftKneeVel = 0,
			rightKneeVel = 0,
		}
	end
	return hg.IKFootState[id]
end

-- Simple ground trace
local function TraceGround(ply, pos, maxDist)
	local start = pos + Vector(0, 0, 5)
	local endPos = pos - Vector(0, 0, maxDist)
	
	local tr = util.TraceHull({
		start = start,
		endpos = endPos,
		mins = Vector(-3, -3, 0),
		maxs = Vector(3, 3, 2),
		filter = ply,
		mask = MASK_SOLID_BRUSHONLY,
	})
	
	return tr.Hit, tr.HitPos, tr.HitNormal
end

-- Update foot lock state
local function UpdateFootLock(foot, footPos, onGround, vel2D, dt)
	local lockStrength = 0.85
	local releaseSpeed = 65
	
	if not onGround then
		foot.planted = false
		foot.lockPos = nil
		return
	end
	
	-- Check if foot should lock
	if not foot.planted then
		foot.planted = true
		foot.lockPos = footPos
	elseif foot.lockPos then
		local dist = footPos:Distance(foot.lockPos)
		local speed = vel2D
		
		-- Release if moved too far
		if dist > 20 or speed > releaseSpeed then
			foot.planted = false
			foot.lockPos = nil
		end
	end
	
	return foot.lockPos or footPos
end

-- Calculate IK for legs
function hg.CalculateIKFoot(ply, ent)
	if not hg.IKFootConfig.enabled:GetBool() then return nil end
	if ply:InVehicle() then return nil end
	if not ply:OnGround() then return nil end
	
	local state = GetIKState(ply)
	local dt = math.Clamp(FrameTime(), 1/300, 1/20)
	
	local groundDist = hg.IKFootConfig.groundDistance:GetFloat()
	local legLength = hg.IKFootConfig.legLength:GetFloat()
	local smoothing = hg.IKFootConfig.smoothing:GetFloat()
	local bodyDropTarget = hg.IKFootConfig.bodyDrop:GetFloat()
	
	-- Get leg bones
	local lThigh = ent:LookupBone("ValveBiped.Bip01_L_Thigh")
	local lCalf = ent:LookupBone("ValveBiped.Bip01_L_Calf")
	local lFoot = ent:LookupBone("ValveBiped.Bip01_L_Foot")
	local rThigh = ent:LookupBone("ValveBiped.Bip01_R_Thigh")
	local rCalf = ent:LookupBone("ValveBiped.Bip01_R_Calf")
	local rFoot = ent:LookupBone("ValveBiped.Bip01_R_Foot")
	
	if not lFoot or not rFoot or not lCalf or not rCalf or not lThigh or not rThigh then
		return nil
	end
	
	-- Get current foot positions
	local lFootMat = ent:GetBoneMatrix(lFoot)
	local rFootMat = ent:GetBoneMatrix(rFoot)
	if not lFootMat or not rFootMat then return nil end
	
	local lFootPos = lFootMat:GetTranslation()
	local rFootPos = rFootMat:GetTranslation()
	
	-- Trace ground
	local lHit, lHitPos, lHitNormal = TraceGround(ply, lFootPos, groundDist)
	local rHit, rHitPos, rHitNormal = TraceGround(ply, rFootPos, groundDist)
	
	local vel = ply:GetVelocity()
	local vel2D = vel:Length2D()
	
	-- Update foot locks
	local lTarget = UpdateFootLock(state.leftFoot, lFootPos, lHit, vel2D, dt)
	local rTarget = UpdateFootLock(state.rightFoot, rFootPos, rHit, vel2D, dt)
	
	-- Calculate required body drop
	local lReqDrop = 0
	local rReqDrop = 0
	
	if lHit then
		lReqDrop = math.max(lFootPos.z - lHitPos.z, 0)
	end
	if rHit then
		rReqDrop = math.max(rFootPos.z - rHitPos.z, 0)
	end
	
	local maxDrop = math.max(lReqDrop, rReqDrop)
	local avgDrop = (lReqDrop + rReqDrop) * 0.5
	local heightDiff = math.abs(lReqDrop - rReqDrop)
	
	local dropBias = math.Clamp(0.75 + (heightDiff / 10) * 0.25, 0.75, 1.0)
	local reqDrop = Lerp(dropBias, avgDrop, maxDrop)
	reqDrop = reqDrop + bodyDropTarget
	reqDrop = math.Clamp(reqDrop, 0, legLength * 0.8)
	
	-- Smooth body drop
	state.bodyDrop, state.bodyDropVel = LerpVector(smoothing, state.bodyDrop, reqDrop), 0
	state.bodyDrop = Lerp(smoothing, state.bodyDrop, reqDrop)
	
	-- Calculate knee bends
	local kneeRange = legLength * 0.5
	local lKnee = math.deg(math.asin(math.Clamp((state.bodyDrop - lReqDrop) / kneeRange, -1, 1)))
	local rKnee = math.deg(math.asin(math.Clamp((state.bodyDrop - rReqDrop) / kneeRange, -1, 1)))
	
	-- Boost for positive bends
	if lKnee > 0 then lKnee = lKnee * 1.7 end
	if rKnee > 0 then rKnee = rKnee * 1.7 end
	
	lKnee = math.Clamp(lKnee, hg.IKFootConfig.minKneeBend, hg.IKFootConfig.maxKneeBend)
	rKnee = math.Clamp(rKnee, hg.IKFootConfig.minKneeBend, hg.IKFootConfig.maxKneeBend)
	
	-- Smooth knee angles
	state.leftKnee = Lerp(smoothing, state.leftKnee, lKnee)
	state.rightKnee = Lerp(smoothing, state.rightKnee, rKnee)
	
	return {
		bodyDrop = state.bodyDrop,
		leftThighAngle = Angle(0, -state.leftKnee, 0),
		leftCalfAngle = Angle(0, state.leftKnee, 0),
		rightThighAngle = Angle(0, -state.rightKnee, 0),
		rightCalfAngle = Angle(0, state.rightKnee, 0),
		bones = {
			lThigh = lThigh,
			lCalf = lCalf,
			lFoot = lFoot,
			rThigh = rThigh,
			rCalf = rCalf,
			rFoot = rFoot,
		}
	}
end

-- Apply IK using bone matrix manipulation (TPIK-compatible)
function hg.ApplyIKFoot(ent, ikResult)
	if not ikResult then return end
	
	local drop = ikResult.bodyDrop or 0
	
	-- Apply body drop to pelvis (bone 0)
	local pelvisMat = ent:GetBoneMatrix(0)
	if pelvisMat then
		local newPos = pelvisMat:GetTranslation() + Vector(0, 0, -drop)
		pelvisMat:SetTranslation(newPos)
		ent:SetBoneMatrix(0, pelvisMat)
	end
	
	-- Apply leg angles using bone matrix
	local bones = ikResult.bones
	
	if bones.lThigh then
		local mat = ent:GetBoneMatrix(bones.lThigh)
		if mat then
			local ang = mat:GetAngles()
			ang:RotateAroundAxis(ang:Right(), ikResult.leftThighAngle.p)
			ang:RotateAroundAxis(ang:Up(), ikResult.leftThighAngle.y)
			ang:RotateAroundAxis(ang:Forward(), ikResult.leftThighAngle.r)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(bones.lThigh, mat)
		end
	end
	
	if bones.lCalf then
		local mat = ent:GetBoneMatrix(bones.lCalf)
		if mat then
			local ang = mat:GetAngles()
			ang:RotateAroundAxis(ang:Right(), ikResult.leftCalfAngle.p)
			ang:RotateAroundAxis(ang:Up(), ikResult.leftCalfAngle.y)
			ang:RotateAroundAxis(ang:Forward(), ikResult.leftCalfAngle.r)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(bones.lCalf, mat)
		end
	end
	
	if bones.rThigh then
		local mat = ent:GetBoneMatrix(bones.rThigh)
		if mat then
			local ang = mat:GetAngles()
			ang:RotateAroundAxis(ang:Right(), ikResult.rightThighAngle.p)
			ang:RotateAroundAxis(ang:Up(), ikResult.rightThighAngle.y)
			ang:RotateAroundAxis(ang:Forward(), ikResult.rightThighAngle.r)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(bones.rThigh, mat)
		end
	end
	
	if bones.rCalf then
		local mat = ent:GetBoneMatrix(bones.rCalf)
		if mat then
			local ang = mat:GetAngles()
			ang:RotateAroundAxis(ang:Right(), ikResult.rightCalfAngle.p)
			ang:RotateAroundAxis(ang:Up(), ikResult.rightCalfAngle.y)
			ang:RotateAroundAxis(ang:Forward(), ikResult.rightCalfAngle.r)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(bones.rCalf, mat)
		end
	end
end

-- Reset IK state for a player
function hg.ResetIKFoot(ply)
	local id = ply:EntIndex()
	hg.IKFootState[id] = nil
end

-- Hard reset all IK
function hg.HardResetIKFoot()
	hg.IKFootState = {}
end

concommand.Add("hg_ik_foot_reset", function()
	hg.HardResetIKFoot()
	chat.AddText(Color(100, 255, 100), "[HG IK Foot] ", Color(255, 255, 255), "Reset complete")
end)
