util.AddNetworkString("hg_tpik_pose")

local maxAge = 0.4
local maxOffset = 48
local maxReachSqr = 120 * 120

net.Receive("hg_tpik_pose", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local wep = net.ReadEntity()
    local pos, ang = net.ReadVector(), net.ReadAngle()
    local rightPos, leftPos = net.ReadVector(), net.ReadVector()
    if not IsValid(wep) or wep ~= ply:GetActiveWeapon() or not wep.WorldModel_Transform then return end
    local body = hg.GetCurrentCharacter(ply)
    if not IsValid(body) then return end
    local center = body:WorldSpaceCenter()
    if pos:DistToSqr(center) > maxReachSqr or rightPos:DistToSqr(center) > maxReachSqr or leftPos:DistToSqr(center) > maxReachSqr then return end
    local serverPos, serverAng = wep:WorldModel_Transform(true)
    if not isvector(serverPos) or not isangle(serverAng) then return end
    local offsetPos, offsetAng = WorldToLocal(pos, ang, serverPos, serverAng)
    if offsetPos:Length() > maxOffset then
        wep.HGReportedPose = nil
        return
    end
    wep.HGReportedPose = {
        pos = offsetPos,
        ang = offsetAng,
        right = (WorldToLocal(rightPos, angle_zero, pos, ang)),
        left = (WorldToLocal(leftPos, angle_zero, pos, ang)),
        time = CurTime(),
    }
end)

function hg.ApplyReportedWeaponPose(wep, serverPos, serverAng)
    local reported = IsValid(wep) and wep.HGReportedPose
    if not reported or CurTime() - reported.time > maxAge then return end
    return LocalToWorld(reported.pos, reported.ang, serverPos, serverAng)
end

function hg.GetReportedHandPoints(wep)
    local reported = IsValid(wep) and wep.HGReportedPose
    if not reported or CurTime() - reported.time > maxAge or not wep.WorldModel_Transform then return end
    local serverPos, serverAng = wep:WorldModel_Transform(true)
    if not isvector(serverPos) or not isangle(serverAng) then return end
    local pos, ang = LocalToWorld(reported.pos, reported.ang, serverPos, serverAng)
    local rightPos = LocalToWorld(reported.right, angle_zero, pos, ang)
    local leftPos = LocalToWorld(reported.left, angle_zero, pos, ang)
    return rightPos, leftPos
end
