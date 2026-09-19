hg.organism = hg.organism or {}

function hg.organism.ClampWoundOffset(ent, bone, offset, direction)
    local nearest, distance
    local hitboxSet = isfunction(ent.GetHitboxSet) and ent:GetHitboxSet() or 0
    for index = 0, (ent:GetHitBoxCount(hitboxSet) or 0) - 1 do
        if ent:GetHitBoxBone(index, hitboxSet) ~= bone then continue end
        local mins, maxs = ent:GetHitBoxBounds(index, hitboxSet)
        if not mins or not maxs then continue end
        local point = Vector(math.Clamp(offset.x, mins.x, maxs.x), math.Clamp(offset.y, mins.y, maxs.y), math.Clamp(offset.z, mins.z, maxs.z))
        local dist = point:DistToSqr(offset)
        if dist == 0 and isvector(direction) and direction:LengthSqr() > 0.001 then
            local tx = direction.x > 0.001 and (maxs.x - offset.x) / direction.x or direction.x < -0.001 and (mins.x - offset.x) / direction.x
            local ty = direction.y > 0.001 and (maxs.y - offset.y) / direction.y or direction.y < -0.001 and (mins.y - offset.y) / direction.y
            local tz = direction.z > 0.001 and (maxs.z - offset.z) / direction.z or direction.z < -0.001 and (mins.z - offset.z) / direction.z
            local surfaceDistance = math.min(tx or math.huge, ty or math.huge, tz or math.huge)
            if surfaceDistance < math.huge then point = offset + direction * surfaceDistance end
        end
        if not distance or dist < distance then nearest, distance = point, dist end
    end
    return nearest or offset
end

function hg.organism.GetWoundAnchor(ent, pos, ang, fallbackBone)
    if not IsValid(ent) or not isvector(pos) then return end
    if isfunction(ent.SetupBones) then ent:SetupBones() end
    local bestBone, bestPos, bestAng, bestDistance
    for index = 0, (ent:GetHitBoxCount(0) or 0) - 1 do
        local bone = ent:GetHitBoxBone(index, 0)
        local matrix = bone and bone >= 0 and ent:GetBoneMatrix(bone)
        if not matrix or ent:GetManipulateBoneScale(bone):LengthSqr() < 0.1 then continue end
        local offset, rotation = WorldToLocal(pos, ang, matrix:GetTranslation(), matrix:GetAngles())
        local clamped = hg.organism.ClampWoundOffset(ent, bone, offset)
        local distance = clamped:DistToSqr(offset)
        if not bestDistance or distance < bestDistance or (distance == bestDistance and bone == fallbackBone) then
            bestBone, bestPos, bestAng, bestDistance = bone, clamped, rotation, distance
        end
    end
    if bestBone then return hg.organism.ClampWoundOffset(ent, bestBone, bestPos, bestAng:Forward()), bestAng, ent:GetBoneName(bestBone) end
    local matrix = fallbackBone and fallbackBone >= 0 and ent:GetBoneMatrix(fallbackBone)
    if not matrix then return end
    local offset, rotation = WorldToLocal(pos, ang, matrix:GetTranslation(), matrix:GetAngles())
    return hg.organism.ClampWoundOffset(ent, fallbackBone, offset, rotation:Forward()), rotation, ent:GetBoneName(fallbackBone)
end

function hg.organism.GetWoundTransform(ent, wound)
    if not IsValid(ent) or not isvector(wound[2]) or not isangle(wound[3]) then return end
    local bone = isnumber(wound[4]) and wound[4] or ent:LookupBone(wound[4] or "")
    if not bone or bone < 0 or bone >= ent:GetBoneCount() then return end
    if ent:GetManipulateBoneScale(bone):LengthSqr() < 0.1 then return end
    local matrix = ent:GetBoneMatrix(bone)
    if not matrix then return end
    if ent:IsRagdoll() then
        local physBone = ent:TranslateBoneToPhysBone(bone)
        if physBone and physBone >= 0 and ent:TranslatePhysBoneToBone(physBone) == bone then
            local phys = ent:GetPhysicsObjectNum(physBone)
            if IsValid(phys) and matrix:GetTranslation():DistToSqr(phys:GetPos()) > 24 * 24 then return end
        end
    end
    local offset = hg.organism.ClampWoundOffset(ent, bone, wound[2], wound[3]:Forward())
    return LocalToWorld(offset, wound[3], matrix:GetTranslation(), matrix:GetAngles())
end
