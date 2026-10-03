local sendDelay = 0.05
local nextSend = 0

function hg.SendTPIKPose(ply, ent, wpn)
    if ply ~= LocalPlayer() or CurTime() < nextSend then return end
    if not IsValid(ent) or not IsValid(wpn) then return end
    local class = wpn:GetClass()
    if class == "weapon_hands_sh" or class == "weapon_hg_coolhands" then return end
    local pos, ang = wpn.visualDesiredPos, wpn.visualDesiredAng
    if not isvector(pos) or not isangle(ang) then return end
    local rightBone, leftBone = ent:LookupBone("ValveBiped.Bip01_R_Hand"), ent:LookupBone("ValveBiped.Bip01_L_Hand")
    local rightMatrix = rightBone and ent:GetBoneMatrix(rightBone)
    local leftMatrix = leftBone and ent:GetBoneMatrix(leftBone)
    if not rightMatrix or not leftMatrix then return end
    nextSend = CurTime() + sendDelay
    net.Start("hg_tpik_pose", true)
    net.WriteEntity(wpn)
    net.WriteVector(pos)
    net.WriteAngle(ang)
    net.WriteVector(rightMatrix:GetTranslation())
    net.WriteVector(leftMatrix:GetTranslation())
    net.SendToServer()
end
