if SERVER then AddCSLuaFile() end

local modelBoundsCache = {}

local CLEARANCE_GROW = 700
local CLEARANCE_SHRINK = 90
local CLEARANCE_MAX = 45
local CLEARANCE_PADDING = 0.75
local CLEARANCE_PROBES = 5

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

    if util.GetModelBounds then
        local ok, mins, maxs = pcall(util.GetModelBounds, model)
        if ok and isvector(mins) and isvector(maxs) then
            modelBoundsCache[model] = {mins, maxs}
            return mins, maxs
        end
    end
    if IsValid(fallbackCandidate) then
        local ok, mins, maxs = pcall(fallbackCandidate.GetModelBounds, fallbackCandidate)
        if ok and isvector(mins) and isvector(maxs) then
            modelBoundsCache[model] = {mins, maxs}
            return mins, maxs
        end
    end
end

local function FrameKey()
    return CLIENT and FrameNumber() or engine.TickCount()
end

function hg.ResolveEquipmentClearance(ent, owner, model, pos, ang, scale)
    if not IsValid(owner) or not isstring(model) or model == "" then return pos end
    local mins, maxs = GetEquipmentModelBounds(ent, model)
    if not mins or not maxs then return pos end
    local aim = owner.GetAimVector and owner:GetAimVector() or ang:Forward()
    if not isvector(aim) or aim:LengthSqr() <= 0.000001 then aim = ang:Forward() end
    aim = aim:GetNormalized()

    local frame = FrameKey()
    if ent.HGEquipmentClearanceFrame == frame then
        return pos - aim * (ent.HGEquipmentClearance or 0)
    end
    ent.HGEquipmentClearanceFrame = frame

    scale = math.max(tonumber(scale) or 1, 0.001)
    local body = hg.GetCurrentCharacter(owner)
    local filter = {owner, ent}
    if IsValid(body) then filter[#filter + 1] = body end
    if IsValid(ent.worldModel) then filter[#filter + 1] = ent.worldModel end
    if IsValid(ent.worldModel2) then filter[#filter + 1] = ent.worldModel2 end
    local start = owner.EyePos and owner:EyePos() or pos

    local probes = {}
    for x = 0, 1 do
        for y = 0, 1 do
            for z = 0, 1 do
                local corner = Vector(x == 0 and mins.x or maxs.x, y == 0 and mins.y or maxs.y, z == 0 and mins.z or maxs.z) * scale
                local world = LocalToWorld(corner, angle_zero, pos, ang)
                probes[#probes + 1] = {pos = world, distance = (world - start):Dot(aim)}
            end
        end
    end
    table.sort(probes, function(a, b) return a.distance > b.distance end)

    local desired = 0
    for index = 1, math.min(CLEARANCE_PROBES, #probes) do
        local probe = probes[index]
        if probe.distance <= 0 then break end
        local trace = util.TraceLine({start = start, endpos = probe.pos, filter = filter, mask = MASK_PLAYERSOLID, collisiongroup = COLLISION_GROUP_PLAYER})
        if trace.Hit then
            desired = math.max(desired, (probe.pos - trace.HitPos):Dot(aim) + CLEARANCE_PADDING)
        end
    end
    desired = math.min(desired, CLEARANCE_MAX)

    local current = ent.HGEquipmentClearance or desired
    local step = (FrameTime and FrameTime() or 0.015) * (desired > current and CLEARANCE_GROW or CLEARANCE_SHRINK)
    ent.HGEquipmentClearance = current + math.Clamp(desired - current, -step, step)

    return pos - aim * ent.HGEquipmentClearance
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
