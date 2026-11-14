hg = hg or {}
hg.WeaponSelector = hg.WeaponSelector or {}
local WS = hg.WeaponSelector

local proceduralConVar = CreateClientConVar("hg_procedural_icons", "1", true, false, "Render weapon selector icons from the weapon model", 0, 1)

local fallbackModels = {}
local heldFrames = {}
local skipClasses = {
    weapon_hands_sh = true,
    weapon_hands = true,
    weapon_hg_coolhands = true,
}

local function LocalDir(ent, dir)
    local ang = ent:GetAngles()
    return Vector(dir:Dot(ang:Forward()), -dir:Dot(ang:Right()), dir:Dot(ang:Up()))
end

local function WorldDir(ent, dir)
    local ang = ent:GetAngles()
    return ang:Forward() * dir.x - ang:Right() * dir.y + ang:Up() * dir.z
end

local function SnapAxis(dir)
    local ax, ay, az = math.abs(dir.x), math.abs(dir.y), math.abs(dir.z)
    if ax >= ay and ax >= az then return Vector(dir.x >= 0 and 1 or -1, 0, 0), 1 end
    if ay >= az then return Vector(0, dir.y >= 0 and 1 or -1, 0), 2 end
    return Vector(0, 0, dir.z >= 0 and 1 or -1), 3
end

local function BoundsFrame(ent)
    local mins, maxs = ent:GetModelBounds()
    if not mins then return end
    local size = maxs - mins
    local order = {{1, size.x}, {2, size.y}, {3, size.z}}
    table.sort(order, function(a, b) return a[2] > b[2] end)
    local axes = {Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1)}
    return axes[order[1][1]], axes[order[2][1]]
end

local function GetFallbackModel(path)
    local ent = fallbackModels[path]
    if IsValid(ent) then return ent end
    if not isstring(path) or path == "" or not util.IsValidModel(path) then return end
    ent = ClientsideModel(path, RENDERGROUP_OPAQUE)
    if not IsValid(ent) then return end
    ent:SetNoDraw(true)
    ent:SetPos(vector_origin)
    ent:SetAngles(angle_zero)
    ent:SetupBones()
    fallbackModels[path] = ent
    return ent
end

local function CollectEntities(wep)
    local wm = wep.GetWM and wep:GetWM() or nil
    if IsValid(wm) then
        local ents = {wm}
        if istable(wep.modelAtt) then
            local origin = wm:GetPos()
            for _, att in pairs(wep.modelAtt) do
                if IsValid(att) and att ~= wm and att:GetPos():DistToSqr(origin) < 10000 then
                    ents[#ents + 1] = att
                    if IsValid(att.model) and att.model:GetPos():DistToSqr(origin) < 10000 then ents[#ents + 1] = att.model end
                end
            end
        end
        return wm, ents, true
    end

    local path = wep.WorldModel
    if not isstring(path) or path == "" then path = wep:GetModel() end
    local ent = GetFallbackModel(path)
    if not ent then return end
    return ent, {ent}, false
end

local function GetFrame(wep, base, live)
    local key = base:GetModel()
    if live then
        local owner = wep:GetOwner()
        if IsValid(owner) and owner:IsPlayer() and owner:GetActiveWeapon() == wep then
            local barrel, barrelAxis = SnapAxis(LocalDir(base, owner:EyeAngles():Forward()))
            local up, upAxis = SnapAxis(LocalDir(base, Vector(0, 0, 1)))
            if barrelAxis ~= upAxis then heldFrames[key] = {barrel, up} end
        end
    end

    local frame = heldFrames[key]
    if frame then return frame[1], frame[2] end
    return BoundsFrame(base)
end

local corner = Vector()
local function ExpandExtents(ent, center, right, up, ext)
    local mins, maxs = ent:GetRenderBounds()
    if not mins then return end
    for i = 0, 7 do
        corner.x = bit.band(i, 1) == 0 and mins.x or maxs.x
        corner.y = bit.band(i, 2) == 0 and mins.y or maxs.y
        corner.z = bit.band(i, 4) == 0 and mins.z or maxs.z
        local offset = ent:LocalToWorld(corner) - center
        local r, u = offset:Dot(right), offset:Dot(up)
        if r < ext[1] then ext[1] = r end
        if r > ext[2] then ext[2] = r end
        if u < ext[3] then ext[3] = u end
        if u > ext[4] then ext[4] = u end
    end
end

local ignoredBoneWords = {"bip01", "arm", "hand", "finger", "camera", "cam_", "_cam", "clavicle", "forearm", "wrist", "ulna", "bicep", "elbow", "shoulder", "tag_view"}

local function IsGunBone(name)
    name = string.lower(name)
    for _, word in ipairs(ignoredBoneWords) do
        if string.find(name, word, 1, true) then return false end
    end
    return true
end

local function ExpandPoint(pos, center, right, up, ext)
    local offset = pos - center
    local r, u = offset:Dot(right), offset:Dot(up)
    if r < ext[1] then ext[1] = r end
    if r > ext[2] then ext[2] = r end
    if u < ext[3] then ext[3] = u end
    if u > ext[4] then ext[4] = u end
end

local function ExpandBones(ent, center, right, up, ext)
    local count = ent:GetBoneCount() or 0
    if count < 2 then return false end
    local used = 0
    local origin = ent:GetPos()
    for bone = 0, count - 1 do
        local name = ent:GetBoneName(bone)
        if not name or name == "__INVALIDBONE__" or not IsGunBone(name) then continue end
        local scale = ent:GetManipulateBoneScale(bone)
        if scale and scale:LengthSqr() < 0.01 then continue end
        local matrix = ent:GetBoneMatrix(bone)
        if not matrix then continue end
        local pos = matrix:GetTranslation()
        if pos:DistToSqr(origin) > 6400 then continue end
        ExpandPoint(pos, center, right, up, ext)
        used = used + 1
    end
    return used >= 3
end

function WS.CanDrawProceduralIcon(wep)
    if not proceduralConVar:GetBool() or not IsValid(wep) or skipClasses[wep:GetClass()] then return false end
    return true
end

function WS.DrawProceduralIcon(wep, x, y, wide, tall, alpha, tint, padding)
    if not WS.CanDrawProceduralIcon(wep) or wide < 4 or tall < 4 then return false end
    local base, ents, live = CollectEntities(wep)
    if not IsValid(base) then return false end

    local barrelLocal, upLocal = GetFrame(wep, base, live)
    if not barrelLocal then return false end
    local right = WorldDir(base, barrelLocal)
    local up = WorldDir(base, upLocal)
    local forward = up:Cross(right)
    local center = base:GetPos()

    local ext = {math.huge, -math.huge, math.huge, -math.huge}
    local boneFit = live and ExpandBones(base, center, right, up, ext)
    if boneFit then
        local padR, padU = (ext[2] - ext[1]) * 0.06 + 1, (ext[4] - ext[3]) * 0.2 + 1.5
        ext[1], ext[2], ext[3], ext[4] = ext[1] - padR, ext[2] + padR, ext[3] - padU, ext[4] + padU
    end
    for index, ent in ipairs(ents) do
        if index > 1 or not boneFit then ExpandExtents(ent, center, right, up, ext) end
    end
    if ext[1] >= ext[2] or ext[3] >= ext[4] then return false end

    local midR, midU = (ext[1] + ext[2]) * 0.5, (ext[3] + ext[4]) * 0.5
    local halfR, halfU = (ext[2] - ext[1]) * 0.5, (ext[4] - ext[3]) * 0.5
    local scale = math.max(halfR / (wide * 0.5), halfU / (tall * 0.5)) * (padding or 1.08)
    local hw, hh = wide * 0.5 * scale, tall * 0.5 * scale
    local focus = center + right * midR + up * midU

    cam.Start({
        type = "3D",
        x = x, y = y, w = wide, h = tall,
        origin = focus - forward * 400,
        angles = forward:AngleEx(up),
        znear = 1, zfar = 1200,
        ortho = {left = -hw, right = hw, top = -hh, bottom = hh},
    })
        render.ClearDepth(false)
        render.SuppressEngineLighting(true)
        render.SetLightingOrigin(focus)
        render.ResetModelLighting(0.35, 0.35, 0.37)
        render.SetModelLighting(BOX_FRONT, 0.85, 0.85, 0.88)
        render.SetModelLighting(BOX_TOP, 1, 1, 1)
        render.SetModelLighting(BOX_BACK, 0.55, 0.55, 0.6)
        local col = tint or color_white
        render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
        render.SetBlend((alpha or 255) / 255)
        for _, ent in ipairs(ents) do ent:DrawModel() end
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
        render.SuppressEngineLighting(false)
    cam.End3D()
    return true
end
