hg.EquipmentImpact = hg.EquipmentImpact or {}
local impact = hg.EquipmentImpact

impact.Config = {
    traumaMinDamage = 5,
    traumaFullDamage = 65,
    rightChance = 0.012,
    leftChance = 0.004,
    traumaSeverityChance = 0.06,
    traumaInjuryChance = 0.38,
    leftInjuryMultiplier = 0.65,
    soleArmSignificantDamage = 18,
    soleArmChance = 0.92,
    weaponBaseChance = 0.005,
    weaponPowerChance = 0.36,
    weaponInjuryChance = 0.55,
    weaponSoleInjuryChance = 0.45,
    weaponSoleSignificantPower = 0.3,
    weaponSoleSevereInjury = 0.5,
    braceInjuryMultiplier = 0.3,
    damagePowerWeight = 0.8,
    forcePowerWeight = 0.2,
    grazingPower = 0.15,
    impactDamage = 80,
    impactForce = 120,
    maxDropChance = 0.98,
    dropCooldown = 0.35,
    maxImpulseSpeed = 320,
    inheritedSpeed = 160,
    weaponHitPadding = 0.65,
    weaponSolidFraction = 0.25,
    weaponMaxThickness = 8,
    contactAbsorption = 0.55,
    blockAbsorption = 0.82,
    parryFallBreakSpeed = 950,
    defaultHardness = 0.9,
    heldDurabilityMultiplier = 1.75,
}

impact.ProcessedDamage = setmetatable({}, {__mode = "k"})
local geometryCache = {}
local materialProfiles = {
    metal = {mat = MAT_METAL, hardness = 0.9, ballisticResistance = 9, contactAbsorption = 0.5, blockAbsorption = 0.82, durability = 150, bulletWear = 0.42, meleeWear = 0.22},
    wood = {mat = MAT_WOOD, hardness = 0.5, ballisticResistance = 1.25, contactAbsorption = 0.12, blockAbsorption = 0.48, durability = 65, bulletWear = 0.7, meleeWear = 0.5},
    plastic = {mat = MAT_PLASTIC, hardness = 0.35, ballisticResistance = 0.7, contactAbsorption = 0.08, blockAbsorption = 0.35, durability = 45, bulletWear = 0.85, meleeWear = 0.65},
    glass = {mat = MAT_GLASS, hardness = 0.2, ballisticResistance = 0.25, contactAbsorption = 0.03, blockAbsorption = 0.18, durability = 18, bulletWear = 1.4, meleeWear = 1.3},
    ceramic = {mat = MAT_CONCRETE, hardness = 0.75, ballisticResistance = 4.5, contactAbsorption = 0.28, blockAbsorption = 0.55, durability = 42, bulletWear = 1.05, meleeWear = 0.8},
    fabric = {mat = MAT_FLESH, hardness = 0.15, ballisticResistance = 0.12, contactAbsorption = 0.02, blockAbsorption = 0.12, durability = 28, bulletWear = 0.95, meleeWear = 0.75},
}

local function NormalizeMaterialName(name)
    name = string.lower(tostring(name or ""))
    if string.find(name, "metal", 1, true) or string.find(name, "iron", 1, true) or string.find(name, "steel", 1, true) then return "metal" end
    if string.find(name, "wood", 1, true) or string.find(name, "chair", 1, true) or string.find(name, "furniture", 1, true) then return "wood" end
    if string.find(name, "glass", 1, true) then return "glass" end
    if string.find(name, "concrete", 1, true) or string.find(name, "stone", 1, true) or string.find(name, "brick", 1, true) or string.find(name, "ceramic", 1, true) or string.find(name, "mug", 1, true) then return "ceramic" end
    if string.find(name, "cloth", 1, true) or string.find(name, "fabric", 1, true) or string.find(name, "leather", 1, true) then return "fabric" end
    if string.find(name, "plastic", 1, true) or string.find(name, "rubber", 1, true) then return "plastic" end
end

function hg.GetEquipmentMaterialProfile(ent, materialName)
    local normalized = NormalizeMaterialName(materialName)
    if not normalized and IsValid(ent) then
        normalized = NormalizeMaterialName(ent.EquipmentMaterial or ent.BlockMaterial)
        if not normalized and isfunction(ent.GetClashMaterial) then normalized = NormalizeMaterialName(ent:GetClashMaterial()) end
        if not normalized then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) and isfunction(phys.GetMaterial) then normalized = NormalizeMaterialName(phys:GetMaterial()) end
        end
        if not normalized then normalized = NormalizeMaterialName(ent:GetMaterial()) or NormalizeMaterialName((ent:GetModel() or "") .. " " .. tostring(ent.PrintName or "")) end
        if not normalized and ent:IsWeapon() then normalized = "metal" end
    end
    normalized = normalized or "plastic"
    return materialProfiles[normalized], normalized
end

function hg.GetEquipmentCondition(ent, held)
    if not IsValid(ent) then return 0, 1 end
    local profile = hg.GetEquipmentMaterialProfile(ent)
    local maxDurability = math.max(tonumber(ent.EquipmentDurability) or profile.durability, 1)
    if held then maxDurability = maxDurability * impact.Config.heldDurabilityMultiplier end
    local durability = ent.HGEquipmentDurability
    if durability == nil then durability = maxDurability end
    return math.Clamp(durability / maxDurability, 0, 1), maxDurability
end

function hg.DamageEquipmentCondition(ent, damage, damageType, held)
    if not IsValid(ent) or not isnumber(damage) or damage <= 0 then return false end
    local profile = hg.GetEquipmentMaterialProfile(ent)
    local condition, maxDurability = hg.GetEquipmentCondition(ent, held)
    local isBullet = bit.band(damageType or 0, DMG_BULLET + DMG_BUCKSHOT) ~= 0
    local wear = damage * (isBullet and profile.bulletWear or profile.meleeWear)
    local durability = ent.HGEquipmentDurability
    if durability == nil then durability = maxDurability * condition end
    durability = math.max(durability - wear, 0)
    ent.HGEquipmentDurability = durability
    ent:SetNWFloat("HGEquipmentCondition", math.Clamp(durability / maxDurability, 0, 1))
    if durability > 0 then return false end
    local newlyBroken = not ent:GetNWBool("HGEquipmentBroken", false)
    ent:SetNWBool("HGEquipmentBroken", true)
    return newlyBroken
end

function hg.GetHeldEquipmentEntities(ply)
    local held, seen = {}, {}
    local function Add(ent)
        if not IsValid(ent) or ent:IsWorld() or ent:IsPlayer() or ent:IsRagdoll() or seen[ent] then return end
        seen[ent] = true
        held[#held + 1] = ent
    end
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    if IsValid(wep) and isfunction(wep.GetCarrying) then Add(wep:GetCarrying()) end
    if IsValid(ply) and isfunction(ply.GetNetVar) then
        Add(ply:GetNetVar("carryent"))
        Add(ply:GetNetVar("carryent2"))
    end
    if IsValid(ply) and isfunction(ply.GetEntityInUse) then
        local ent = ply:GetEntityInUse()
        if IsValid(ent) and ent:IsPlayerHolding() then Add(ent) end
    end
    return held
end

local function DropHeldEquipment(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and isfunction(wep.GetCarrying) and isfunction(wep.SetCarrying) and wep:GetCarrying() == ent then wep:SetCarrying() end
    if ply:GetNetVar("carryent2") == ent and hg.SetCarryEnt2 then hg.SetCarryEnt2(ply) end
    if ent:IsPlayerHolding() and isfunction(ply.DropObject) then ply:DropObject(ent) end
end

local function SetupEntityBones(entity)
    if IsValid(entity) and isfunction(entity.SetupBones) then
        entity:SetupBones()
    end
end

local function GetGeometry(model)
    if geometryCache[model] ~= nil then return geometryCache[model] or nil end
    local probe = ents.Create("base_anim")
    if not IsValid(probe) then return end
    probe:SetModel(model)
    local mins, maxs = probe:GetModelBounds()
    local geometry = {mins = mins, maxs = maxs, convexes = {}, boxes = {}}
    probe:PhysicsInit(SOLID_VPHYSICS)
    local phys = probe:GetPhysicsObject()
    local meshes = IsValid(phys) and phys:GetMeshConvexes() or {}
    for _, mesh in ipairs(meshes or {}) do
        local center = Vector()
        for _, vertex in ipairs(mesh) do center = center + vertex.pos end
        center = center / math.max(#mesh, 1)
        local planes = {}
        for i = 1, #mesh - 2, 3 do
            local a, b, c = mesh[i].pos, mesh[i + 1].pos, mesh[i + 2].pos
            local normal = (b - a):Cross(c - a)
            if normal:LengthSqr() <= 0.000001 then continue end
            normal:Normalize()
            if normal:Dot(center - a) > 0 then normal = -normal end
            planes[#planes + 1] = {normal = normal, distance = normal:Dot(a)}
        end
        if #planes > 0 then geometry.convexes[#geometry.convexes + 1] = planes end
    end
    if #geometry.convexes == 0 and isfunction(probe.SetupBones) and isfunction(probe.GetHitBoxCount) and isfunction(probe.GetHitBoxBone) and isfunction(probe.GetHitBoxBounds) and isfunction(probe.GetBoneMatrix) then
        probe:SetupBones()
        for i = 0, (probe:GetHitBoxCount(0) or 0) - 1 do
            local bone = probe:GetHitBoxBone(i, 0)
            local matrix = bone and probe:GetBoneMatrix(bone)
            local boxMin, boxMax = probe:GetHitBoxBounds(i, 0)
            if matrix and boxMin and boxMax then
                geometry.boxes[#geometry.boxes + 1] = {pos = matrix:GetTranslation(), ang = matrix:GetAngles(), mins = boxMin, maxs = boxMax}
            end
        end
    end
    probe:Remove()
    geometryCache[model] = geometry
    return geometry
end

local function ClipConvex(startPos, ray, planes)
    local entry, leave, normal = 0, math.huge, -ray:GetNormalized()
    for _, plane in ipairs(planes) do
        local distance = plane.distance - plane.normal:Dot(startPos)
        local slope = plane.normal:Dot(ray)
        if math.abs(slope) < 0.000001 then
            if distance < 0 then return end
        elseif slope < 0 then
            local fraction = distance / slope
            if fraction > entry then entry, normal = fraction, plane.normal end
        else
            leave = math.min(leave, distance / slope)
        end
        if entry > leave then return end
    end
    if leave <= 0 or entry > 1 then return end
    return entry, leave, normal
end

function hg.TraceEquipmentModel(model, pos, ang, scale, startPos, endPos, padding)
    if not isstring(model) or model == "" then return end
    local geometry = GetGeometry(model)
    if not geometry or not geometry.mins or not geometry.maxs then return end
    scale = math.max(tonumber(scale) or 1, 0.001)
    local startLocal = WorldToLocal(startPos, angle_zero, pos, ang) / scale
    local endLocal = WorldToLocal(endPos, angle_zero, pos, ang) / scale
    local ray = endLocal - startLocal
    padding = math.max(tonumber(padding) or 0, 0) / scale
    if ray:LengthSqr() < 0.000001 then return end
    local paddingVector = Vector(padding, padding, padding)
    if not util.IntersectRayWithOBB(startLocal, ray, vector_origin, angle_zero, geometry.mins - paddingVector, geometry.maxs + paddingVector) then return end
    local best, exit, normal
    for _, planes in ipairs(geometry.convexes) do
        local expandedPlanes = planes
        if padding > 0 then
            expandedPlanes = {}
            for _, plane in ipairs(planes) do
                expandedPlanes[#expandedPlanes + 1] = {normal = plane.normal, distance = plane.distance + padding}
            end
        end
        local entry, leave, hitNormal = ClipConvex(startLocal, ray, expandedPlanes)
        if entry and (not best or entry < best) then best, exit, normal = entry, leave, hitNormal end
    end
    if #geometry.convexes == 0 then
        local boxes = #geometry.boxes > 0 and geometry.boxes or {{pos = vector_origin, ang = angle_zero, mins = geometry.mins, maxs = geometry.maxs}}
        for _, box in ipairs(boxes) do
            local hit, hitNormal, entry = util.IntersectRayWithOBB(startLocal, ray, box.pos, box.ang, box.mins - paddingVector, box.maxs + paddingVector)
            if hit and (not best or entry < best) then
                local beyond = hit + ray:GetNormalized() * ((box.maxs - box.mins):Length() + 1)
                local back = util.IntersectRayWithOBB(beyond, hit - beyond, box.pos, box.ang, box.mins - paddingVector, box.maxs + paddingVector)
                best, exit, normal = entry, entry + (back and back:Distance(hit) or 0.1) / ray:Length(), hitNormal
            end
        end
    end
    if not best then return end
    local worldNormal = LocalToWorld(normal, angle_zero, vector_origin, ang)
    return {
        fraction = best,
        position = startPos + (endPos - startPos) * best,
        normal = worldNormal,
        thickness = math.max((exit - best) * ray:Length() * scale, 0.05),
    }
end

local armorHelmetPlacements = {
    head = true,
    visor = true,
    helmet_jaw = true,
    helmet_ears = true,
}

local function GetArmorWearer(ent)
    if not IsValid(ent) then return end
    if ent:IsPlayer() or ent:IsNPC() then return ent end
    local owner = hg.RagdollOwner and hg.RagdollOwner(ent)
    return IsValid(owner) and owner or ent
end

local function GetArmorPieceTransform(body, wearer, armorData, piece, placement, primary)
    local female = ThatPlyIsFemale(body)
    local bone = body:LookupBone(piece.bone or armorData.bone or "")
    local matrix = bone and body:GetBoneMatrix(bone)
    if not matrix then return end

    local bonePos = Vector(matrix:GetTranslation())
    local boneAng = matrix:GetAngles()
    local femaleOffset = piece.femPos or vector_origin
    if female then
        bonePos:Add(boneAng:Forward() * femaleOffset[1] + boneAng:Up() * femaleOffset[2] + boneAng:Right() * femaleOffset[3])
    end

    local localPos = primary and armorData[3] or piece.pos or vector_origin
    local localAng = female and piece.femAng or (primary and armorData[4] or piece.ang) or angle_zero
    local pos, ang = LocalToWorld(localPos or vector_origin, localAng, bonePos, boneAng)
    if armorHelmetPlacements[placement] and IsValid(wearer) and wearer.PlayerClassName == "swat" then
        pos:Add(Vector(0, 0, 1))
    end

    local wearerScale = placement == "torso" and IsValid(wearer) and wearer.PlayerClassName == "swat" and 1.08 or 1
    local scale = ((female and piece.femscale) or piece.scale or 1) * wearerScale
    return pos, ang, scale
end

local function ArmorManualBoxIntersects(body, armor, placement, startPos, endPos, padding)
    if not hg.organism or not hg.organism.GetHitBoxOrgans or not hg.organism.ShootMatrix then return false end
    local organs = hg.organism.GetHitBoxOrgans(body:GetModel(), body)
    if not organs then return false end
    local boxes = hg.organism.ShootMatrix(body, organs)
    if not boxes then return false end

    local ray = endPos - startPos
    local expand = Vector(padding or 0, padding or 0, padding or 0)
    for _, box in ipairs(boxes) do
        local organ = box[6] and organs[box[6]] and organs[box[6]][box[7]]
        if not organ or (organ[1] ~= armor and organ[7] ~= placement) then continue end
        if util.IntersectRayWithOBB(startPos, ray, box[1], box[2], box[3] - expand, box[4] + expand) then return true end
    end
    return false
end

function hg.TraceArmorShot(body, startPos, endPos, seen, hits, padding)
    if not IsValid(body) or not istable(hg.armor) then return end
    local wearer = GetArmorWearer(body)
    local armors = istable(body.armors) and body.armors or IsValid(wearer) and wearer.armors
    if not istable(armors) then return end

    seen = seen or {}
    hits = hits or {}
    padding = math.max(tonumber(padding) or 0, 0)
    for placement, armor in pairs(armors) do
        local armorData = hg.armor[placement] and hg.armor[placement][armor]
        local key = "armor:" .. tostring(body:EntIndex()) .. ":" .. tostring(armor)
        if not armorData or seen[key] then continue end

        local best
        local model = IsValid(wearer) and wearer:GetNWString("ArmorModel" .. armor, "") or ""
        if model == "" then model = armorData.model or armorData[2] end
        if isstring(model) and model ~= "" then
            local pos, ang, scale = GetArmorPieceTransform(body, wearer, armorData, armorData, placement, true)
            best = pos and hg.TraceEquipmentModel(model, pos, ang, scale, startPos, endPos, padding) or nil
        end

        local extraModels = armorData.extraModels or (armorData.extraModel and {armorData.extraModel})
        for _, piece in ipairs(extraModels or {}) do
            if not isstring(piece.model) or piece.model == "" then continue end
            local pos, ang, scale = GetArmorPieceTransform(body, wearer, armorData, piece, placement, false)
            local hit = pos and hg.TraceEquipmentModel(piece.model, pos, ang, scale, startPos, endPos, padding) or nil
            if hit and (not best or hit.fraction < best.fraction) then best = hit end
        end

        if not best or ArmorManualBoxIntersects(body, armor, placement, startPos, endPos, padding) then continue end
        best.armor, best.placement, best.data = armor, placement, armorData
        best.body, best.wearer, best.key = body, wearer, key
        hits[#hits + 1] = best
    end
    return hits
end

local function ArmState(org, arm)
    local side = arm:sub(1, 1)
    local missing = org[arm .. "amputated"] or org[arm .. "upamputated"] or org[side .. "handamputated"]
    local damage = math.max(tonumber(org[arm]) or 0, tonumber(org[side .. "wrist"]) or 0)
    local dislocated = org[arm .. "dislocation"] or org[arm .. "dislocated"] or org[side .. "wristdislocation"]
    return missing, math.Clamp(math.max(damage, (dislocated or missing) and 1 or 0), 0, 1)
end

function hg.GetFallBraceState(ply, body)
    if not IsValid(ply) then return end
    if IsValid(body) and body.HGFallCoverActive then
        local coverWep = ply.GetActiveWeapon and ply:GetActiveWeapon()
        return true, IsValid(coverWep) and coverWep.GetBlocking and coverWep:GetBlocking() or false
    end

    local wep = ply.GetActiveWeapon and ply:GetActiveWeapon()
    local blocking = IsValid(wep) and wep.GetBlocking and wep:GetBlocking() or false
    local handsOut = ply.KeyDown and ply:KeyDown(IN_USE)
    if not handsOut and ply.KeyDown and ply:KeyDown(IN_ATTACK2) then
        handsOut = not IsValid(wep) or wep:GetClass() == "weapon_hands_sh" or wep.ismelee2 == true
    end

    return blocking or handsOut, blocking
end

function hg.ApplyFallBraceDamage(ply, body, dmgInfo, damage)
    if not IsValid(ply) or not isnumber(damage) or damage <= 0 then return 0 end
    local target = IsValid(body) and body or ply
    local org = target.organism or ply.organism
    local input = hg.organism and hg.organism.input_list
    if not org or not input then return 0 end

    local arms = {}
    if not org.rarmamputated and not org.rarmupamputated then arms[#arms + 1] = "rarmup" end
    if not org.larmamputated and not org.larmupamputated then arms[#arms + 1] = "larmup" end
    if #arms == 0 then return 0 end

    local perArm = damage / #arms
    for _, arm in ipairs(arms) do
        if input[arm] then input[arm](org, 0, perArm, dmgInfo) end
    end

    return damage
end

function hg.GetWeaponImpactGrip(ply, wep)
    local org = ply.organism or {}
    local rightMissing, rightInjury = ArmState(org, "rarm")
    local leftMissing, leftInjury = ArmState(org, "larm")
    local support = wep.GetHandSupportState and wep:GetHandSupportState(ply)
    local twoHands = wep.TwoHanded == true or (wep.TwoHanded == nil and wep.OneHandedOnly ~= true and wep.IsPistolHoldType and not wep:IsPistolHoldType()) or false
    local rightBusy = support and support.rightBusy
    local leftBusy = support and support.leftBusy
    local onlyLeft = not leftMissing and not leftBusy and (rightMissing or rightInjury >= 1 or rightBusy)
    local firingArm = onlyLeft and "larm" or "rarm"
    local brace = twoHands and not onlyLeft and not leftMissing and not leftBusy and not (support and support.postureOneHanded)
    return {
        firingArm = firingArm,
        injury = onlyLeft and leftInjury or rightInjury,
        braceInjury = brace and leftInjury or 0,
        sole = onlyLeft or not brace or leftInjury >= 1,
        leftRelevant = onlyLeft or brace,
        rightRelevant = not onlyLeft,
        noHands = (rightMissing or rightBusy) and (leftMissing or leftBusy),
    }
end

function hg.GetHeldWeaponImpactModel(ply, wep)
    if not IsValid(wep) then return end
    if wep.WorldModel_Transform then wep:WorldModel_Transform() end
    local model = wep.worldModel
    if IsValid(model) then
        local modelName = model:GetModel()
        local modelScale = model:GetModelScale()
        if isstring(wep.WorldModelExchange) and wep.WorldModelExchange ~= "" then
            modelName = wep.WorldModelExchange
            modelScale = wep.modelscale or modelScale
        end
        return modelName, model:GetPos(), model:GetAngles(), modelScale
    end
    if wep.NoDrop then return end
    local body = hg.GetCurrentCharacter(ply)
    if not IsValid(body) then return end
    SetupEntityBones(body)
    local grip = hg.GetWeaponImpactGrip(ply, wep)
    local bone = body:LookupBone(grip.firingArm == "larm" and "ValveBiped.Bip01_L_Hand" or "ValveBiped.Bip01_R_Hand")
    local matrix = bone and body:GetBoneMatrix(bone)
    if not matrix then return end
    local pos, ang = LocalToWorld(wep.weaponPos or wep.WorldPos or vector_origin, wep.weaponAng or wep.WorldAng or angle_zero, matrix:GetTranslation(), matrix:GetAngles())
    return wep.WorldModelExchange or wep.WorldModel or wep:GetModel(), pos, ang, (wep.WorldModelExchange and wep.modelscale or wep.modelscale2) or wep:GetModelScale()
end

function hg.DropWeaponFromImpact(ply, wep, direction, strength)
    if not IsValid(ply) or not ply:Alive() or not IsValid(wep) or wep.NoDrop or wep:GetOwner() ~= ply then return false end
    local cfg = impact.Config
    if (ply.hgNextImpactDrop or 0) > CurTime() then return false end
    local _, pos, ang = hg.GetHeldWeaponImpactModel(ply, wep)
    pos, ang = pos or wep:GetPos(), ang or wep:GetAngles()
    local body = hg.GetCurrentCharacter(ply)
    wep.HGImpactDropNotificationPending = true
    hook.Run("PlayerDropWeapon", ply, wep)
    if IsValid(wep) then wep.HGImpactDropNotificationPending = nil end
    if not IsValid(wep) or IsValid(wep:GetOwner()) then return false end
    ply.hgNextImpactDrop = CurTime() + cfg.dropCooldown
    wep:SetPos(pos)
    wep:SetAngles(ang)
    local phys = wep:GetPhysicsObject()
    if IsValid(phys) then
        local inherited = IsValid(body) and body:GetVelocity() or ply:GetVelocity()
        inherited = inherited:GetNormalized() * math.min(inherited:Length(), cfg.inheritedSpeed)
        local dir = isvector(direction) and direction:GetNormalized() or vector_origin
        local speed = math.Clamp(strength or 0, 0, 1) * cfg.maxImpulseSpeed
        phys:Wake()
        phys:SetVelocity(inherited + dir * speed)
    end
    if hg.NotifyPickupHistoryDrop then
        local name = wep.GetPrintName and wep:GetPrintName() or wep.PrintName or wep:GetClass()
        hg.NotifyPickupHistoryDrop(ply, name)
    end
    return true
end

function hg.TryArmTraumaDrop(ent, dmgInfo, hitgroup, body, rawDamage)
    if hitgroup ~= HITGROUP_RIGHTARM and hitgroup ~= HITGROUP_LEFTARM then return end
    local ply = IsValid(ent) and ent:IsPlayer() and ent or hg.RagdollOwner(IsValid(body) and body or ent)
    if not IsValid(ply) or not ply:Alive() then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep.NoDrop then return end
    local cfg = impact.Config
    local damage = rawDamage or dmgInfo:GetDamage()
    if damage < cfg.traumaMinDamage or not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_CLUB + DMG_SLASH + DMG_CRUSH + DMG_FALL + DMG_BLAST + DMG_VEHICLE) then return end
    local grip = hg.GetWeaponImpactGrip(ply, wep)
    local right = hitgroup == HITGROUP_RIGHTARM
    if not right and not grip.leftRelevant then return end
    local _, injury = ArmState(ply.organism or {}, right and "rarm" or "larm")
    local severity = math.Clamp(damage / cfg.traumaFullDamage, 0, 1)
    local chance = (right and cfg.rightChance or cfg.leftChance) + severity ^ 2 * cfg.traumaSeverityChance
    chance = chance + injury * cfg.traumaInjuryChance * math.Clamp(damage / cfg.soleArmSignificantDamage, 0, 1) * (right and 1 or cfg.leftInjuryMultiplier)
    if grip.firingArm == "larm" and not right and damage >= cfg.soleArmSignificantDamage then chance = math.max(chance, cfg.soleArmChance) end
    if grip.noHands then chance = cfg.maxDropChance end
    if math.Rand(0, 1) < math.min(chance, cfg.maxDropChance) then hg.DropWeaponFromImpact(ply, wep, dmgInfo:GetDamageForce(), severity * 0.35) end
end

local function WeaponImpact(ply, wep, hit, damage, force, direction)
    local cfg = impact.Config
    local grip = hg.GetWeaponImpactGrip(ply, wep)
    local directness = math.Clamp(-hit.normal:Dot(direction), 0, 1)
    local power = math.Clamp(damage / cfg.impactDamage * cfg.damagePowerWeight + math.max(force or 0, 0) / cfg.impactForce * cfg.forcePowerWeight, 0, 1)
    power = power * (cfg.grazingPower + directness * (1 - cfg.grazingPower))
    local chance = cfg.weaponBaseChance + power ^ 2 * cfg.weaponPowerChance
    chance = chance + power * (grip.injury + grip.braceInjury * cfg.braceInjuryMultiplier) * cfg.weaponInjuryChance
    if grip.sole then chance = chance + power * grip.injury * cfg.weaponSoleInjuryChance end
    if grip.sole and grip.injury >= cfg.weaponSoleSevereInjury and power >= cfg.weaponSoleSignificantPower then chance = math.max(chance, cfg.soleArmChance) end
    if grip.noHands then chance = cfg.maxDropChance end

    if isfunction(wep.OnHeldWeaponImpact) then
        wep:OnHeldWeaponImpact(hit, damage, force, direction, hit.shot)
    end

    local damageType = hit.damageType or (hit.shot and hit.shot.DamageType) or DMG_CLUB
    local broken = hg.DamageEquipmentCondition(wep, damage, damageType, true)
    if broken then
        hg.DropWeaponFromImpact(ply, wep, direction, 1)
        return
    end

    if math.Rand(0, 1) < math.min(chance, cfg.maxDropChance) then hg.DropWeaponFromImpact(ply, wep, direction, power) end
end

local function GetWeaponImpactAbsorption(wep, hit, direction, dmgInfo)
    local directness = math.Clamp(-hit.normal:Dot(direction), 0, 1)
    local profile = hg.GetEquipmentMaterialProfile(wep)
    local contactAbsorption = tonumber(wep.EquipmentContactAbsorption) or profile.contactAbsorption or impact.Config.contactAbsorption
    local absorbed = contactAbsorption * directness * math.Clamp(hit.thickness / 2, 0, 1)
    local blocking = wep.GetBlocking and wep:GetBlocking() or false
    local parry = false
    if blocking and wep.GetStartedBlocking and wep.GetBlockParryWindow then
        parry = CurTime() - wep:GetStartedBlocking() <= wep:GetBlockParryWindow()
    end
    local highFall = dmgInfo and dmgInfo:IsDamageType(DMG_FALL) and dmgInfo:GetDamageForce():Length() >= impact.Config.parryFallBreakSpeed
    if blocking then absorbed = math.max(absorbed, tonumber(wep.EquipmentBlockAbsorption) or profile.blockAbsorption or impact.Config.blockAbsorption) end
    if parry and not highFall then return 1, true end
    return math.Clamp(absorbed, 0, 1), false
end

local function GetHeldEntityImpactAbsorption(ent, hit, direction)
    local profile = hg.GetEquipmentMaterialProfile(ent)
    local directness = math.Clamp(-hit.normal:Dot(direction), 0, 1)
    local thickness = math.Clamp(hit.thickness / 3, 0.15, 1)
    return math.Clamp((tonumber(ent.EquipmentContactAbsorption) or profile.contactAbsorption) * directness * thickness, 0, 0.9)
end

local function GetEquipmentBallisticRemaining(ent, hit, shot, damage, scale, absorbed)
    local profile = hg.GetEquipmentMaterialProfile(ent)
    local condition = hg.GetEquipmentCondition(ent, true)
    if ent:GetNWBool("HGEquipmentBroken", false) then condition = math.min(condition, 0.15) end
    local penetration = math.max(tonumber(shot.Penetration) or damage * scale / 8, 0.1)
    local resistance = (tonumber(ent.EquipmentBallisticResistance) or profile.ballisticResistance) * Lerp(condition, 0.2, 1)
    local solidFraction = tonumber(ent.EquipmentSolidFraction) or impact.Config.weaponSolidFraction
    local maxThickness = tonumber(ent.EquipmentMaxThickness) or impact.Config.weaponMaxThickness
    local thickness = math.min(hit.thickness * solidFraction, maxThickness)
    local geometricDistance = math.min(penetration * 3 / math.max(profile.hardness, 0.05) * 0.4, 100)
    local remaining = math.Clamp(1 - thickness / math.max(geometricDistance, 0.01), 0, 1)
    remaining = math.min(remaining, math.Clamp((penetration - resistance) / penetration, 0, 1))
    if shot.Vel and hg.PhysBullet and hg.PhysBullet.CalcVelocityLostInMaterial then
        local speed = shot.Vel:Length()
        local after = hg.PhysBullet.CalcVelocityLostInMaterial(profile.mat, thickness * thickness, speed)
        remaining = math.min(remaining, (after / math.max(speed, 1)) ^ 2)
    end
    remaining = remaining * (1 - absorbed)
    if remaining < 0.02 then remaining = 0 end
    return remaining, penetration, profile
end

local function TraceReachesEquipmentWearer(trace, hit)
    if not trace or not IsValid(trace.Entity) or not hit or not IsValid(hit.body) then return false end
    if trace.Entity == hit.body or trace.Entity == hit.wearer then return true end
    local owner = hg.RagdollOwner and hg.RagdollOwner(trace.Entity)
    return IsValid(owner) and owner == hit.wearer
end

function hg.TryAbsorbEquipmentImpact(ent, dmgInfo, hitPos, direction, impactRadius)
    if impact.ProcessedDamage[dmgInfo] then return end
    if not IsValid(ent) or not isvector(hitPos) or not isvector(direction) or direction:LengthSqr() < 0.001 then return end
    if not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_CLUB + DMG_SLASH + DMG_CRUSH + DMG_FALL + DMG_VEHICLE) then return end
    local damage = dmgInfo:GetDamage()
    local ply = ent:IsPlayer() and ent or hg.RagdollOwner(ent)
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    local parried = false
    local armorHit, armorResult
    if IsValid(ply) then
        local dir = direction:GetNormalized()
        local radius = math.max(tonumber(impactRadius) or 0, 0)
        local startPos = hitPos - dir * (48 + radius)
        local traceFilter = {ent, ply}
        if IsValid(wep) then
            traceFilter[#traceFilter + 1] = wep
            if IsValid(wep.worldModel) then traceFilter[#traceFilter + 1] = wep.worldModel end
        end
        local obstruction = util.TraceLine({start = hitPos, endpos = startPos, filter = traceFilter})
        if obstruction.Hit then startPos = obstruction.HitPos end
        local equipmentHits = {}
        if IsValid(wep) then
            local model, pos, ang, scale = hg.GetHeldWeaponImpactModel(ply, wep)
            local weaponHit = model and hg.TraceEquipmentModel(model, pos, ang, scale, startPos, hitPos + dir, impact.Config.weaponHitPadding + radius)
            if weaponHit then weaponHit.weapon, weaponHit.ply = wep, ply; equipmentHits[#equipmentHits + 1] = weaponHit end
        end
        for _, heldEnt in ipairs(hg.GetHeldEquipmentEntities(ply)) do
            local model = heldEnt:GetModel()
            local heldHit = model and hg.TraceEquipmentModel(model, heldEnt:GetPos(), heldEnt:GetAngles(), heldEnt:GetModelScale(), startPos, hitPos + dir, radius)
            if heldHit then heldHit.heldEntity, heldHit.ply = heldEnt, ply; equipmentHits[#equipmentHits + 1] = heldHit end
        end
        if hg.TraceArmorShot then
            SetupEntityBones(ent)
            hg.TraceArmorShot(ent, startPos, hitPos + dir, {}, equipmentHits, radius)
        end
        table.sort(equipmentHits, function(a, b) return a.fraction < b.fraction end)
        local hit = equipmentHits[1]
        if hit then
            hit.damageType = dmgInfo:GetDamageType()
            local absorbed
            if hit.armor then
                local inflictor = dmgInfo:GetInflictor()
                local bullet = IsValid(inflictor) and inflictor.bullet or nil
                local armorShot = {
                    DamageType = dmgInfo:GetDamageType(),
                    Diameter = bullet and bullet.Diameter,
                    Penetration = bullet and bullet.Penetration or damage / 2,
                    bullet = bullet,
                }
                armorResult = hg.ProcessArmorModelHit and hg.ProcessArmorModelHit(hit, damage, dmgInfo:GetDamageForce(), dir, armorShot)
                armorHit = hit
                absorbed = 1 - math.Clamp(armorResult and armorResult.scale or 1, 0, 1)
            elseif hit.weapon then
                if hit.weapon.HGEquipmentContactTick ~= engine.TickCount() then
                    WeaponImpact(ply, hit.weapon, hit, damage, dmgInfo:GetDamageForce():Length(), dir)
                end
                hit.weapon.HGEquipmentContactTick = nil
                local weaponParry
                absorbed, weaponParry = GetWeaponImpactAbsorption(hit.weapon, hit, dir, dmgInfo)
                if weaponParry then
                    parried = true
                    if hit.weapon.PlayBlockImpactEffect then
                        hit.weapon:PlayBlockImpactEffect({HitPos = hit.position, HitNormal = hit.normal}, hit.weapon, "parry")
                    end
                end
            else
                absorbed = GetHeldEntityImpactAbsorption(hit.heldEntity, hit, dir)
                local broken = hg.DamageEquipmentCondition(hit.heldEntity, damage, dmgInfo:GetDamageType(), true)
                if broken then DropHeldEquipment(ply, hit.heldEntity) end
            end
            dmgInfo:ScaleDamage(1 - absorbed)
            dmgInfo:SetDamageForce(dmgInfo:GetDamageForce() * (1 - absorbed))
        end
    end
    if hg.Appearance and hg.Appearance.TryAbsorbAccessoryImpact then
        hg.Appearance.TryAbsorbAccessoryImpact(ent, dmgInfo, hitPos, direction, nil, impactRadius)
    end
    local state = parried and {parried = true} or {}
    if armorHit then
        state.armorHits = {[armorHit.key] = true}
        state.penetration = armorResult and armorResult.penetration
    end
    impact.ProcessedDamage[dmgInfo] = state
    return dmgInfo:GetDamage() < damage
end

function hg.TraceHeldWeaponShot(startPos, endPos, shooter, damage, force, originalTrace, shot)
    if not isvector(startPos) or not isvector(endPos) or startPos:DistToSqr(endPos) < 0.000001 then return originalTrace end
    originalTrace = originalTrace or {}
    shot = shot or {}
    shot.EquipmentHits = shot.EquipmentHits or {}
    local seen, hits, checkedBodies = shot.EquipmentHits, {}, {}
    local segment = endPos - startPos
    local segmentLength = segment:Length()
    local direction = segment / segmentLength
    local obstructionFraction = 1
    if originalTrace and originalTrace.Hit and isvector(originalTrace.HitPos) then
        obstructionFraction = math.Clamp(startPos:Distance(originalTrace.HitPos) / segmentLength, 0, 1)
    end
    local cfg = impact.Config
    local projectileRadius = math.max(tonumber(shot.EquipmentRadius) or 0, 0)
    for _, ply in ipairs(player.GetAll()) do
        if ply == shooter or not ply:Alive() then continue end
        local body = hg.GetCurrentCharacter(ply)
        if not IsValid(body) then continue end
        SetupEntityBones(body)
        checkedBodies[body] = true
        checkedBodies[ply] = true
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and not seen[wep] then
            local model, pos, ang, modelScale = hg.GetHeldWeaponImpactModel(ply, wep)
            local hit = model and hg.TraceEquipmentModel(model, pos, ang, modelScale, startPos, endPos, cfg.weaponHitPadding + projectileRadius)
            if hit and hit.fraction <= obstructionFraction + 0.0001 then hit.weapon, hit.ply, hit.key = wep, ply, wep; hit.shot = shot; hits[#hits + 1] = hit end
        end
        for _, heldEnt in ipairs(hg.GetHeldEquipmentEntities(ply)) do
            if seen[heldEnt] then continue end
            local model = heldEnt:GetModel()
            local hit = model and hg.TraceEquipmentModel(model, heldEnt:GetPos(), heldEnt:GetAngles(), heldEnt:GetModelScale(), startPos, endPos, projectileRadius)
            if hit and hit.fraction <= obstructionFraction + 0.0001 then
                hit.heldEntity, hit.ply, hit.key, hit.shot = heldEnt, ply, heldEnt, shot
                hits[#hits + 1] = hit
            end
        end
        if hg.Appearance and hg.Appearance.TraceAccessoryShot then
            hg.Appearance.TraceAccessoryShot(body, startPos, endPos, seen, hits, projectileRadius)
        end
        if hg.TraceArmorShot then
            hg.TraceArmorShot(body, startPos, endPos, seen, hits, projectileRadius)
        end
    end
    for index = #hits, 1, -1 do
        if hits[index].fraction > obstructionFraction + 0.0001 then table.remove(hits, index) end
    end
    table.sort(hits, function(a, b) return a.fraction < b.fraction end)
    local scale = 1
    shot.ArmorModelHits = shot.ArmorModelHits or {}
    for _, hit in ipairs(hits) do
        seen[hit.key] = true
        if shot.Contact then
            local contactScale = 1
            local armorResult
            if hit.armor then
                armorResult = hg.ProcessArmorModelHit and hg.ProcessArmorModelHit(hit, damage, force, direction, shot)
                contactScale = armorResult and armorResult.scale or 1
                shot.ArmorModelHits[hit.key] = true
            elseif hit.weapon then
                WeaponImpact(hit.ply, hit.weapon, hit, damage, force, direction)
                hit.weapon.HGEquipmentContactTick = engine.TickCount()
            elseif hit.heldEntity then
                local broken = hg.DamageEquipmentCondition(hit.heldEntity, damage, shot.DamageType or DMG_CLUB, true)
                if broken then DropHeldEquipment(hit.ply, hit.heldEntity) end
                hit.heldEntity.HGHeldEquipmentResistanceUntil = CurTime() + 0.1
            else
                local info = DamageInfo()
                info:SetDamage(damage)
                info:SetDamageType(shot.DamageType or DMG_CLUB)
                hg.Appearance.TryAbsorbAccessoryImpact(hit.body, info, hit.position, direction * (force or damage), hit)
                contactScale = info:GetDamage() / math.max(damage, 0.001)
            end

            if (hit.armor or not hit.weapon and not hit.heldEntity) and TraceReachesEquipmentWearer(originalTrace, hit) and not (armorResult and armorResult.stopped) then
                local tr = table.Copy(originalTrace or {})
                tr.HGEquipmentScale = contactScale
                tr.HGEquipmentProcessed = true
                tr.HGArmorModelHits = shot.ArmorModelHits
                tr.HGArmorModelContact = true
                return tr
            end
            local tr = table.Copy(originalTrace or {})
            tr.Hit, tr.HitWorld, tr.HitSky = true, false, false
            tr.Entity = hit.weapon and hit.ply or hit.heldEntity or game.GetWorld()
            tr.HitPos, tr.HitNormal, tr.Normal = hit.position, hit.normal, direction
            tr.StartSolid, tr.AllSolid = false, false
            local equipment = hit.weapon or hit.heldEntity
            local profile = equipment and hg.GetEquipmentMaterialProfile(equipment)
            tr.MatType, tr.Fraction = hit.armor and MAT_METAL or profile and profile.mat or MAT_PLASTIC, hit.fraction
            tr.HGEquipmentContact = true
            tr.HGEquipmentScale = contactScale
            tr.HGEquipmentProcessed = true
            tr.HGArmorModelHits = shot.ArmorModelHits
            if hit.weapon then
                local grip = hg.GetWeaponImpactGrip(hit.ply, hit.weapon)
                local directness = math.Clamp(-hit.normal:Dot(direction), 0, 1)
                local absorbed = impact.Config.contactAbsorption * directness * math.Clamp(hit.thickness / 2, 0, 1)
                tr.HGEquipmentScale = 1 - absorbed
                tr.HGEquipmentWeapon = hit.weapon
                tr.HGEquipmentIntercept = true
                tr.HitGroup = grip and grip.firingArm == "larm" and HITGROUP_LEFTARM or HITGROUP_RIGHTARM
            elseif hit.heldEntity then
                tr.HGEquipmentHeldEntity = hit.heldEntity
                tr.HGEquipmentIntercept = true
            end
            return tr
        end
        if hit.armor then
            local result = hg.ProcessArmorModelHit and hg.ProcessArmorModelHit(hit, damage * scale, (force or 0) * scale, direction, shot)
            shot.ArmorModelHits[hit.key] = true
            if result then
                scale = scale * math.Clamp(result.scale or 1, 0, 1)
                if result.penetration ~= nil then
                    shot.Penetration = result.penetration
                    shot.EquipmentPenetration = result.penetration
                end
                if result.stopped or scale <= 0.001 then
                    local tr = table.Copy(originalTrace or {})
                    tr.Hit, tr.HitWorld, tr.HitSky = true, false, false
                    tr.Entity, tr.HitPos, tr.HitNormal, tr.Normal = game.GetWorld(), hit.position, hit.normal, direction
                    tr.StartSolid, tr.AllSolid, tr.MatType = false, false, result.material or MAT_METAL
                    tr.Fraction = hit.fraction
                    tr.HGEquipmentBlocked, tr.HGEquipmentScale = true, 0
                    tr.HGEquipmentProcessed, tr.HGEquipmentIntercept = true, true
                    tr.HGArmorModelHits = shot.ArmorModelHits
                    tr.HGArmorModelContact = true
                    return tr
                end
            end
        elseif hit.weapon or hit.heldEntity then
            local equipment = hit.weapon or hit.heldEntity
            local absorbed, parry
            if hit.weapon then
                absorbed, parry = GetWeaponImpactAbsorption(hit.weapon, hit, direction)
                WeaponImpact(hit.ply, hit.weapon, hit, damage * scale, (force or 0) * scale, direction)
            else
                absorbed = GetHeldEntityImpactAbsorption(hit.heldEntity, hit, direction)
                local broken = hg.DamageEquipmentCondition(hit.heldEntity, damage * scale, shot.DamageType or DMG_BULLET, true)
                if broken then DropHeldEquipment(hit.ply, hit.heldEntity) end
                hit.heldEntity.HGHeldEquipmentResistanceUntil = CurTime() + 0.1
            end
            local remaining, penetration, profile = GetEquipmentBallisticRemaining(equipment, hit, shot, damage, scale, absorbed)
            local material = profile.mat
            shot.Penetration = penetration * remaining
            shot.EquipmentPenetration = shot.Penetration
            scale = scale * remaining
            local effect = EffectData()
            effect:SetOrigin(hit.position)
            effect:SetNormal(hit.normal)
            effect:SetMagnitude(1)
            effect:SetScale(1)
            if material == MAT_METAL then util.Effect("Sparks", effect, true, true) end
            if HG_BulletImpactSounds then HG_BulletImpactSounds.PlayMaterialImpact({HitPos = hit.position, MatType = material}) end
            if hit.weapon and hit.weapon:GetClass() == "weapon_pan" and remaining <= 0.001 then
                hook.Run("HGEquipmentBulletBlocked", hit.ply, "pan", hit.weapon, hit.position)
            end
            if parry then
                local tr = table.Copy(originalTrace or {})
                tr.Hit, tr.HitWorld, tr.HitSky = true, false, false
                tr.Entity, tr.HitPos, tr.HitNormal, tr.Normal = game.GetWorld(), hit.position, hit.normal, direction
                tr.StartSolid, tr.AllSolid, tr.MatType = false, false, material
                tr.Fraction = hit.fraction
                tr.HGEquipmentBlocked, tr.HGEquipmentScale = true, 0
                tr.HGEquipmentProcessed, tr.HGEquipmentIntercept = true, true
                tr.HGEquipmentWeapon = hit.weapon
                if hit.weapon.PlayBlockImpactEffect then
                    hit.weapon:PlayBlockImpactEffect({HitPos = hit.position, HitNormal = hit.normal}, hit.weapon, "parry")
                end
                return tr
            end
            if scale <= 0.001 then
                local tr = table.Copy(originalTrace or {})
                tr.Hit, tr.HitWorld, tr.HitSky = true, false, false
                tr.Entity, tr.HitPos, tr.HitNormal, tr.Normal = game.GetWorld(), hit.position, hit.normal, direction
                tr.StartSolid, tr.AllSolid, tr.MatType = false, false, material
                local endsAtOriginalHit = originalTrace and originalTrace.Hit and isvector(originalTrace.HitPos) and endPos:DistToSqr(originalTrace.HitPos) < 0.0001
                tr.Fraction = endsAtOriginalHit and originalTrace.Fraction * hit.fraction or hit.fraction
                tr.HGEquipmentBlocked, tr.HGEquipmentScale = true, 0
                tr.HGEquipmentProcessed, tr.HGEquipmentIntercept = true, true
                tr.HGEquipmentWeapon = hit.weapon
                tr.HGEquipmentHeldEntity = hit.heldEntity
                return tr
            end
        else
            local info = DamageInfo()
            info:SetDamage(damage * scale)
            info:SetDamageType(shot.DamageType or DMG_BULLET)
            hg.Appearance.TryAbsorbAccessoryImpact(hit.body, info, hit.position, direction * (force or damage), hit)
            scale = scale * info:GetDamage() / math.max(damage * scale, 0.001)
        end
    end
    originalTrace.HGEquipmentScale = scale
    originalTrace.HGEquipmentPenetration = shot.EquipmentPenetration
    originalTrace.HGEquipmentProcessed = checkedBodies[originalTrace.Entity] == true
    originalTrace.HGArmorModelHits = shot.ArmorModelHits
    return originalTrace
end

hook.Add("EntityTakeDamage", "HG_HeldEquipmentResistance", function(ent, dmgInfo)
    if not IsValid(ent) or (ent.HGHeldEquipmentResistanceUntil or 0) < CurTime() then return end
    dmgInfo:ScaleDamage(1 / impact.Config.heldDurabilityMultiplier)
end)
