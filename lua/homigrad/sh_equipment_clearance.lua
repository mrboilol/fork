if SERVER then AddCSLuaFile() end

local modelBoundsCache = {}

local function GetEquipmentModelBounds(ent, model)
    local cached = modelBoundsCache[model]
    if cached then return cached[1], cached[2] end

    local candidates = {}
    if IsValid(ent) then
        if IsValid(ent.worldModel) then candidates[#candidates + 1] = ent.worldModel end
        if IsValid(ent.worldModel2) then candidates[#candidates + 1] = ent.worldModel2 end
        candidates[#candidates + 1] = ent
    end

    local fallbackCandidate
    for _, candidate in ipairs(candidates) do
        if not isfunction(candidate.GetModelBounds) then continue end
        local candidateModel = candidate.GetModel and candidate:GetModel() or nil
        if candidateModel and candidateModel ~= "" and candidateModel ~= model then
            fallbackCandidate = fallbackCandidate or candidate
        else
            local ok, mins, maxs = pcall(candidate.GetModelBounds, candidate)
            if ok and isvector(mins) and isvector(maxs) then
                modelBoundsCache[model] = {mins, maxs}
                return mins, maxs
            end
        end
    end

    if IsValid(fallbackCandidate) then
        local ok, mins, maxs = pcall(fallbackCandidate.GetModelBounds, fallbackCandidate)
        if ok and isvector(mins) and isvector(maxs) then
            modelBoundsCache[model] = {mins, maxs}
            return mins, maxs
        end
    end

    if util.GetModelBounds then
        local ok, mins, maxs = pcall(util.GetModelBounds, model)
        if ok and isvector(mins) and isvector(maxs) then
            modelBoundsCache[model] = {mins, maxs}
            return mins, maxs
        end
    end
end

function hg.ResolveEquipmentClearance(ent, owner, model, pos, ang, scale)
    if not IsValid(owner) or not isstring(model) or model == "" then return pos end
    local mins, maxs = GetEquipmentModelBounds(ent, model)
    if not mins or not maxs then return pos end
    scale = math.max(tonumber(scale) or 1, 0.001)
    local center = (mins + maxs) * (scale * 0.5)
    local half = (maxs - mins) * (scale * 0.5)
    local forward, right, up = ang:Forward(), ang:Right(), ang:Up()
    local extent = Vector(
        math.abs(forward.x) * half.x + math.abs(right.x) * half.y + math.abs(up.x) * half.z,
        math.abs(forward.y) * half.x + math.abs(right.y) * half.y + math.abs(up.y) * half.z,
        math.abs(forward.z) * half.x + math.abs(right.z) * half.y + math.abs(up.z) * half.z
    ) + Vector(0.5, 0.5, 0.5)
    local body = hg.GetCurrentCharacter(owner)
    local filter = {owner, ent}
    if IsValid(body) then filter[#filter + 1] = body end
    if IsValid(ent.worldModel) then filter[#filter + 1] = ent.worldModel end
    if IsValid(ent.worldModel2) then filter[#filter + 1] = ent.worldModel2 end
    local target = LocalToWorld(center, angle_zero, pos, ang)
    local aim = owner.GetAimVector and owner:GetAimVector() or ang:Forward()
    if not isvector(aim) or aim:LengthSqr() <= 0.000001 then aim = ang:Forward() end
    aim = aim:GetNormalized()
    local backward = -aim
    local traceData = {start = target, endpos = target, mins = -extent, maxs = extent, filter = filter, mask = MASK_SOLID}
    local function Blocked(distance)
        traceData.start = target + backward * distance
        traceData.endpos = traceData.start
        local trace = util.TraceHull(traceData)
        return trace.StartSolid or trace.AllSolid
    end
    if not Blocked(0) then return pos end
    local clear = math.Clamp(extent:Length() + 8, 16, 64)
    if Blocked(clear) then return pos + backward * clear end
    local blocked = 0
    for _ = 1, 5 do
        local distance = (blocked + clear) * 0.5
        if Blocked(distance) then
            blocked = distance
        else
            clear = distance
        end
    end
    return pos + backward * (clear + 0.5)
end

function hg.ResolveAnimatedEquipmentClearance(ent, owner, pose, model, pos, ang, scale, bone, offsetPos, offsetAng)
    if not hg.ResolveEquipmentClearance then return pos end
    local modelPos, modelAng = pos, ang
    if IsValid(pose) and bone then
        pose:SetPos(pos)
        pose:SetAngles(ang)
        if pose.InvalidateBoneCache then pose:InvalidateBoneCache() end
        if pose.SetupBones then pose:SetupBones() end
        local matrix = pose:GetBoneMatrix(bone)
        modelPos, modelAng = LocalToWorld(offsetPos or vector_origin, offsetAng or angle_zero, matrix and matrix:GetTranslation() or pos, matrix and matrix:GetAngles() or ang)
    end
    local resolved = hg.ResolveEquipmentClearance(ent, owner, model, modelPos, modelAng, scale)
    return pos + resolved - modelPos
end

function hg.EquipmentImpactPose(wep, pos, ang)
    local remaining = math.Clamp(wep:GetNWFloat("HGEquipmentRecovery", 0) - CurTime(), 0, 0.8)
    if remaining <= 0 then return pos, ang end
    local impulse = wep:GetNWVector("HGEquipmentImpulse", vector_origin)
    local kick = math.sin(remaining * 24) * remaining
    return pos + impulse * remaining * 3, ang + Angle(-kick * 7, kick * 5, kick * 9)
end

hook.Add("StartCommand", "HGEquipmentRecovery", function(ply, cmd)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetNWFloat("HGEquipmentRecovery", 0) <= CurTime() then return end
    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
    cmd:RemoveKey(IN_RELOAD)
end)
