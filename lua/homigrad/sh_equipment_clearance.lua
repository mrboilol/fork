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

    for _, candidate in ipairs(candidates) do
        if not isfunction(candidate.GetModelBounds) then continue end
        local candidateModel = candidate.GetModel and candidate:GetModel() or nil
        if candidateModel and candidateModel ~= "" and candidateModel ~= model then continue end
        local ok, mins, maxs = pcall(candidate.GetModelBounds, candidate)
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
    local anchor = owner.GetShootPos and owner:GetShootPos() or owner:EyePos()
    local traceData = {start = anchor, endpos = target, mins = -extent, maxs = extent, filter = filter, mask = MASK_SOLID}
    local trace = util.TraceHull(traceData)
    if trace.StartSolid then
        for _, axis in ipairs({vector_up, -owner:GetAimVector(), owner:EyeAngles():Right(), -owner:EyeAngles():Right()}) do
            traceData.start = anchor + axis * math.min(extent:Length() + 2, 64)
            local path = util.TraceLine({start = anchor, endpos = traceData.start, filter = filter, mask = MASK_SOLID})
            if path.Hit then continue end
            local candidate = util.TraceHull(traceData)
            if not candidate.StartSolid then trace = candidate; break end
        end
    end
    if trace.StartSolid then
        local previous = ent.HGClearancePosition
        if previous and previous:DistToSqr(pos) < 128 * 128 then
            traceData.start = previous + target - pos
            traceData.endpos = traceData.start
            if not util.TraceHull(traceData).StartSolid then return previous end
        end
        return pos
    end
    local resolvedCenter = target
    for _ = 1, 3 do
        if not trace.Hit then break end
        resolvedCenter = trace.HitPos + trace.HitNormal * 0.5
        local remainder = target - resolvedCenter
        remainder = remainder - trace.HitNormal * math.min(remainder:Dot(trace.HitNormal), 0)
        traceData.start, traceData.endpos = resolvedCenter, resolvedCenter + remainder
        local slide = util.TraceHull(traceData)
        if slide.StartSolid then break end
        trace = slide
        if not trace.Hit then resolvedCenter = traceData.endpos end
    end
    local resolved = resolvedCenter - (target - pos)
    ent.HGClearancePosition = resolved
    return resolved
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
