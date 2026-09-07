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
    defaultHardness = 0.9,
}

impact.ProcessedDamage = setmetatable({}, {__mode = "k"})
local geometryCache = {}

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

local function ArmState(org, arm)
    local side = arm:sub(1, 1)
    local missing = org[arm .. "amputated"] or org[arm .. "upamputated"] or org[side .. "handamputated"]
    local damage = math.max(tonumber(org[arm]) or 0, tonumber(org[side .. "wrist"]) or 0)
    local dislocated = org[arm .. "dislocation"] or org[arm .. "dislocated"] or org[side .. "wristdislocation"]
    return missing, math.Clamp(math.max(damage, (dislocated or missing) and 1 or 0), 0, 1)
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
    if IsValid(model) then return model:GetModel(), model:GetPos(), model:GetAngles(), model:GetModelScale() end
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
    if math.Rand(0, 1) < math.min(chance, cfg.maxDropChance) then hg.DropWeaponFromImpact(ply, wep, direction, power) end
end

function hg.TryAbsorbEquipmentImpact(ent, dmgInfo, hitPos, direction, impactRadius)
    if impact.ProcessedDamage[dmgInfo] then return end
    if not IsValid(ent) or not isvector(hitPos) or not isvector(direction) or direction:LengthSqr() < 0.001 then return end
    if not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_CLUB + DMG_SLASH + DMG_CRUSH + DMG_FALL + DMG_VEHICLE) then return end
    local damage = dmgInfo:GetDamage()
    local ply = ent:IsPlayer() and ent or hg.RagdollOwner(ent)
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    if IsValid(wep) then
        local dir = direction:GetNormalized()
        local radius = math.max(tonumber(impactRadius) or 0, 0)
        local startPos = hitPos - dir * (48 + radius)
        local obstruction = util.TraceLine({start = hitPos, endpos = startPos, filter = {ent, ply, wep, wep.worldModel}})
        if obstruction.Hit then startPos = obstruction.HitPos end
        local model, pos, ang, scale = hg.GetHeldWeaponImpactModel(ply, wep)
        local hit = model and hg.TraceEquipmentModel(model, pos, ang, scale, startPos, hitPos + dir, impact.Config.weaponHitPadding + radius)
        if hit then
            WeaponImpact(ply, wep, hit, damage, dmgInfo:GetDamageForce():Length(), dir)
            local directness = math.Clamp(-hit.normal:Dot(dir), 0, 1)
            local absorbed = impact.Config.contactAbsorption * directness * math.Clamp(hit.thickness / 2, 0, 1)
            dmgInfo:ScaleDamage(1 - absorbed)
            dmgInfo:SetDamageForce(dmgInfo:GetDamageForce() * (1 - absorbed))
        end
    end
    if hg.Appearance and hg.Appearance.TryAbsorbAccessoryImpact then
        hg.Appearance.TryAbsorbAccessoryImpact(ent, dmgInfo, hitPos, direction, nil, impactRadius)
    end
    impact.ProcessedDamage[dmgInfo] = {}
    return dmgInfo:GetDamage() < damage
end

function hg.TraceHeldWeaponShot(startPos, endPos, shooter, damage, force, originalTrace, shot)
    if not isvector(startPos) or not isvector(endPos) or startPos:DistToSqr(endPos) < 0.000001 then return originalTrace end
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
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and not seen[wep] then
            local model, pos, ang, modelScale = hg.GetHeldWeaponImpactModel(ply, wep)
            local hit = model and hg.TraceEquipmentModel(model, pos, ang, modelScale, startPos, endPos, cfg.weaponHitPadding + projectileRadius)
            if hit and hit.fraction <= obstructionFraction + 0.0001 then hit.weapon, hit.ply, hit.key = wep, ply, wep; hits[#hits + 1] = hit end
        end
        if hg.Appearance and hg.Appearance.TraceAccessoryShot then
            hg.Appearance.TraceAccessoryShot(body, startPos, endPos, seen, hits, projectileRadius)
        end
    end
    for index = #hits, 1, -1 do
        if hits[index].fraction > obstructionFraction + 0.0001 then table.remove(hits, index) end
    end
    table.sort(hits, function(a, b) return a.fraction < b.fraction end)
    local scale = 1
    for _, hit in ipairs(hits) do
        seen[hit.key] = true
        if shot.Contact then
            if hit.weapon then
                WeaponImpact(hit.ply, hit.weapon, hit, damage, force, direction)
            else
                local info = DamageInfo()
                info:SetDamage(damage)
                info:SetDamageType(shot.DamageType or DMG_CLUB)
                hg.Appearance.TryAbsorbAccessoryImpact(hit.body, info, hit.position, direction * (force or damage), hit)
            end
            local tr = table.Copy(originalTrace)
            tr.Hit, tr.HitWorld, tr.HitSky = true, false, false
            tr.Entity, tr.HitPos, tr.HitNormal, tr.Normal = game.GetWorld(), hit.position, hit.normal, direction
            tr.StartSolid, tr.AllSolid = false, false
            tr.MatType, tr.Fraction = hit.weapon and MAT_METAL or MAT_PLASTIC, hit.fraction
            tr.HGEquipmentContact = true
            return tr
        end
        if hit.weapon then
            WeaponImpact(hit.ply, hit.weapon, hit, damage * scale, (force or 0) * scale, direction)
            local materialName = hit.weapon.GetClashMaterial and hit.weapon:GetClashMaterial() or hit.weapon.BlockMaterial
            local material = ({wood = MAT_WOOD, plastic = MAT_PLASTIC, glass = MAT_GLASS})[materialName] or MAT_METAL
            local hardness = hg.PhysBullet and hg.PhysBullet.SurfaceHardness and hg.PhysBullet.SurfaceHardness[material] or cfg.defaultHardness
            local thickness = math.min(hit.thickness * cfg.weaponSolidFraction, cfg.weaponMaxThickness)
            local penetration = math.max(tonumber(shot.Penetration) or damage * scale / 8, 0.1)
            local maxDistance = math.min(penetration * 3 / hardness * 0.4, 100)
            local remaining = math.Clamp(1 - thickness / maxDistance, 0, 1)
            if shot.Vel and hg.PhysBullet and hg.PhysBullet.CalcVelocityLostInMaterial then
                local speed = shot.Vel:Length()
                local after = hg.PhysBullet.CalcVelocityLostInMaterial(material, thickness * thickness, speed)
                remaining = math.min(remaining, (after / math.max(speed, 1)) ^ 2)
            end
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
            if scale <= 0.001 then
                local tr = table.Copy(originalTrace)
                tr.Hit, tr.HitWorld, tr.HitSky = true, false, false
                tr.Entity, tr.HitPos, tr.HitNormal, tr.Normal = game.GetWorld(), hit.position, hit.normal, direction
                tr.StartSolid, tr.AllSolid, tr.MatType = false, false, material
                local endsAtOriginalHit = originalTrace.Hit and isvector(originalTrace.HitPos) and endPos:DistToSqr(originalTrace.HitPos) < 0.0001
                tr.Fraction = endsAtOriginalHit and originalTrace.Fraction * hit.fraction or hit.fraction
                tr.HGEquipmentBlocked, tr.HGEquipmentScale = true, 0
                return tr
            end
        else
            local info = DamageInfo()
            info:SetDamage(damage * scale)
            info:SetDamageType(DMG_BULLET)
            hg.Appearance.TryAbsorbAccessoryImpact(hit.body, info, hit.position, direction * (force or damage), hit)
            scale = scale * info:GetDamage() / math.max(damage * scale, 0.001)
        end
    end
    originalTrace.HGEquipmentScale = scale
    originalTrace.HGEquipmentPenetration = shot.EquipmentPenetration
    originalTrace.HGEquipmentProcessed = checkedBodies[originalTrace.Entity] == true
    return originalTrace
end
