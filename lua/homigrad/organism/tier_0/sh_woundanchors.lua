hg.organism = hg.organism or {}

local function ProjectWoundToBounds(offset, mins, maxs, direction)
    local point = Vector(math.Clamp(offset.x, mins.x, maxs.x), math.Clamp(offset.y, mins.y, maxs.y), math.Clamp(offset.z, mins.z, maxs.z))
    local delta = offset - point
    local normal

    if delta:LengthSqr() > 0.001 then
        local ax, ay, az = math.abs(delta.x), math.abs(delta.y), math.abs(delta.z)
        if ax >= ay and ax >= az then
            normal = Vector(delta.x >= 0 and 1 or -1, 0, 0)
        elseif ay >= az then
            normal = Vector(0, delta.y >= 0 and 1 or -1, 0)
        else
            normal = Vector(0, 0, delta.z >= 0 and 1 or -1)
        end
        return point, normal
    end

    if isvector(direction) and direction:LengthSqr() > 0.001 then
        local bestDistance = math.huge
        local function test(component, origin, low, high, positiveNormal, negativeNormal)
            if math.abs(component) <= 0.001 then return end
            local distance = ((component > 0 and high or low) - origin) / component
            if distance < 0 or distance >= bestDistance then return end
            bestDistance = distance
            normal = component > 0 and positiveNormal or negativeNormal
        end
        test(direction.x, offset.x, mins.x, maxs.x, Vector(1, 0, 0), Vector(-1, 0, 0))
        test(direction.y, offset.y, mins.y, maxs.y, Vector(0, 1, 0), Vector(0, -1, 0))
        test(direction.z, offset.z, mins.z, maxs.z, Vector(0, 0, 1), Vector(0, 0, -1))
        if bestDistance < math.huge then return offset + direction * bestDistance, normal end
    end

    local faces = {
        {offset.x - mins.x, Vector(-1, 0, 0), 1, mins.x},
        {maxs.x - offset.x, Vector(1, 0, 0), 1, maxs.x},
        {offset.y - mins.y, Vector(0, -1, 0), 2, mins.y},
        {maxs.y - offset.y, Vector(0, 1, 0), 2, maxs.y},
        {offset.z - mins.z, Vector(0, 0, -1), 3, mins.z},
        {maxs.z - offset.z, Vector(0, 0, 1), 3, maxs.z},
    }
    table.sort(faces, function(a, b) return a[1] < b[1] end)
    if faces[1][3] == 1 then
        point.x = faces[1][4]
    elseif faces[1][3] == 2 then
        point.y = faces[1][4]
    else
        point.z = faces[1][4]
    end
    return point, faces[1][2]
end

function hg.organism.ClampWoundOffset(ent, bone, offset, direction)
    local nearest, nearestNormal, distance
    local hitboxSet = isfunction(ent.GetHitboxSet) and ent:GetHitboxSet() or 0
    for index = 0, (ent:GetHitBoxCount(hitboxSet) or 0) - 1 do
        if ent:GetHitBoxBone(index, hitboxSet) ~= bone then continue end
        local mins, maxs = ent:GetHitBoxBounds(index, hitboxSet)
        if not mins or not maxs then continue end
        local point, normal = ProjectWoundToBounds(offset, mins, maxs, direction)
        local bounded = Vector(math.Clamp(offset.x, mins.x, maxs.x), math.Clamp(offset.y, mins.y, maxs.y), math.Clamp(offset.z, mins.z, maxs.z))
        local dist = bounded:DistToSqr(offset)
        if not distance or dist < distance then nearest, nearestNormal, distance = point, normal, dist end
    end
    return nearest or offset, nearestNormal, distance
end

function hg.organism.GetWoundAnchor(ent, pos, ang, fallbackBone)
    if not IsValid(ent) or not isvector(pos) then return end
    if isfunction(ent.SetupBones) then ent:SetupBones() end
    local bestBone, bestPos, bestNormal, bestAng, bestDistance
    local hitboxSet = isfunction(ent.GetHitboxSet) and ent:GetHitboxSet() or 0
    for index = 0, (ent:GetHitBoxCount(hitboxSet) or 0) - 1 do
        local bone = ent:GetHitBoxBone(index, hitboxSet)
        local matrix = bone and bone >= 0 and ent:GetBoneMatrix(bone)
        if not matrix or ent:GetManipulateBoneScale(bone):LengthSqr() < 0.1 then continue end
        local offset, rotation = WorldToLocal(pos, ang, matrix:GetTranslation(), matrix:GetAngles())
        local clamped, normal, distance = hg.organism.ClampWoundOffset(ent, bone, offset, rotation:Forward())
        if not bestDistance or distance < bestDistance or (distance == bestDistance and bone == fallbackBone) then
            bestBone, bestPos, bestNormal, bestAng, bestDistance = bone, clamped, normal or rotation:Forward(), rotation, distance
        end
    end
    if bestBone then return bestPos, isfunction(bestNormal.Angle) and bestNormal:Angle() or bestAng, ent:GetBoneName(bestBone) end
    local matrix = fallbackBone and fallbackBone >= 0 and ent:GetBoneMatrix(fallbackBone)
    if not matrix then return end
    local offset, rotation = WorldToLocal(pos, ang, matrix:GetTranslation(), matrix:GetAngles())
    local clamped, normal = hg.organism.ClampWoundOffset(ent, fallbackBone, offset, rotation:Forward())
    return clamped, normal and isfunction(normal.Angle) and normal:Angle() or rotation, ent:GetBoneName(fallbackBone)
end

function hg.organism.GetWoundTransform(ent, wound)
    if not IsValid(ent) or not isvector(wound[2]) or not isangle(wound[3]) then return end
    if isfunction(ent.SetupBones) then ent:SetupBones() end
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
    local offset, normal = hg.organism.ClampWoundOffset(ent, bone, wound[2], wound[3]:Forward())
    local localAng = normal and isfunction(normal.Angle) and normal:Angle() or wound[3]
    return LocalToWorld(offset, localAng, matrix:GetTranslation(), matrix:GetAngles())
end
