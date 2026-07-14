local healthModel
local blinkModel
local whiteMat = Material("models/debug/debugwhite")
local statusCircleMat = Material("sef_icons/statuseffectcircle.png", "smooth")
local bleedIconMat = Material("zcity_delta/unitmenu/status/bleeding.png", "smooth")
local statusIconCache = {}

local IND_SIZE_BASE = 180
local IND_SIZE_MAX = 240
local ICONS_SCREEN_EDGE_MARGIN = 20
local ICONS_SCREEN_MARGIN_Y = 18
local PULSE_DURATION = 8
local BLINK_SCALE = Vector(1.05, 1.05, 1.05)
local BLINK_DURATION = 5
local FRACTURE_BLINK_SPEED = 10
local SOLID_RED_DURATION = 1

local pulseStartTime = 0
local boneStates = {}
local boneCache = {}
local lastLifeState = nil
local iconsVisibility = 0
local iconsAppearTime = 0
local iconsTargetVisible = false
local cachedAfflictionIcons = {}
local lastKnownFacingAngle = 0
local fadingBones = {} -- Track bones that are fading out after being healed
local FADE_DURATION = 2 -- Seconds for damage color to fade out

local expieModels = {
    ["models/blop/expie/expie.mdl"] = true,
    ["models/assassingecko/geckoexpie/geckoexpie.mdl"] = true,
    ["models/assassingecko/geckoexpie/femgeckoexpie.mdl"] = true,
}

local function IsExpie(ent)
    if not IsValid(ent) then return false end
    return expieModels[ent:GetModel()] or ent.PlayerClassName == "expie" or ent.IsExpie or false
end

local majorBones = {
    pelvis = { organ = "stomach", bone = "ValveBiped.Bip01_Pelvis" },
    spine1 = { organ = "spine", bone = "ValveBiped.Bip01_Spine1" },
    spine2 = { organ = "spine", bone = "ValveBiped.Bip01_Spine2" },
    chest_spine = { organ = "chest", bone = "ValveBiped.Bip01_Spine2" },
    chest_ribs = { organ = "chest", bone = "ValveBiped.Bip01_Spine1", name = "Ribcage" },
    neck = { organ = "neck", bone = "ValveBiped.Bip01_Neck1" },
    l_clavicle = { organ = "larm", bone = "ValveBiped.Bip01_L_Clavicle" },
    r_clavicle = { organ = "rarm", bone = "ValveBiped.Bip01_R_Clavicle" },
    l_upperarm = { organ = "larm", bone = "ValveBiped.Bip01_L_UpperArm", canAmputate = true, ampBone = "ValveBiped.Bip01_L_Forearm" },
    r_upperarm = { organ = "rarm", bone = "ValveBiped.Bip01_R_UpperArm", canAmputate = true, ampBone = "ValveBiped.Bip01_R_Forearm" },
    l_forearm = { organ = "larm", bone = "ValveBiped.Bip01_L_Forearm" },
    r_forearm = { organ = "rarm", bone = "ValveBiped.Bip01_R_Forearm" },
    l_hand = { organ = "larm", bone = "ValveBiped.Bip01_L_Hand" },
    r_hand = { organ = "rarm", bone = "ValveBiped.Bip01_R_Hand" },
    l_thigh = { organ = "lleg", bone = "ValveBiped.Bip01_L_Thigh", canAmputate = true, ampBone = "ValveBiped.Bip01_L_Calf" },
    r_thigh = { organ = "rleg", bone = "ValveBiped.Bip01_R_Thigh", canAmputate = true, ampBone = "ValveBiped.Bip01_R_Calf" },
    l_calf = { organ = "lleg", bone = "ValveBiped.Bip01_L_Calf" },
    r_calf = { organ = "rleg", bone = "ValveBiped.Bip01_R_Calf" },
    l_foot = { organ = "lleg", bone = "ValveBiped.Bip01_L_Foot" },
    r_foot = { organ = "rleg", bone = "ValveBiped.Bip01_R_Foot" },
}

-- OPTIMIZATION: Reduced from 8 to 4 offsets. Cuts extra model draws by 50% for massive lag reduction.
local outlineOffsets = {
    Vector(0, 1.5, 1.5), 
    Vector(0, -1.5, -1.5),
    Vector(0, 1.5, -1.5), 
    Vector(0, -1.5, 1.5)
}

local function ScreenScaleFixed(size)
    return size * (ScrH() / 480)
end

local function ScaleBoneAndChildren(ent, boneID, scale)
    ent:ManipulateBoneScale(boneID, scale)
    local children = ent:GetChildBones(boneID)
    for _, child in ipairs(children) do
        ScaleBoneAndChildren(ent, child, scale)
    end
end

local function ScaleBoneOnly(ent, boneID, scale)
    ent:ManipulateBoneScale(boneID, scale)
end

local function IsChestBoneName(boneName)
    return boneName == "ValveBiped.Bip01_Spine1" or boneName == "ValveBiped.Bip01_Spine2"
end

local function ScaleBone(ent, boneID, scale, boneName)
    if boneName and IsChestBoneName(boneName) then
        ScaleBoneOnly(ent, boneID, scale)
    else
        ScaleBoneAndChildren(ent, boneID, scale)
    end
end

local function InitBlinkModel(ent)
    ent:SetupBones()
    for i = 0, ent:GetBoneCount() - 1 do
        ent:ManipulateBoneScale(i, Vector(0, 0, 0))
    end
end

local function ResetModels(ply)
    if IsValid(healthModel) then
        if healthModel.accessories then
            for _, v in pairs(healthModel.accessories) do
                if IsValid(v) then v:Remove() end
            end
        end
        healthModel:Remove()
    end
    if IsValid(blinkModel) then
        blinkModel:Remove()
    end
    healthModel = nil
    blinkModel = nil
    boneStates = {}
    pulseStartTime = 0
    iconsVisibility = 0
    iconsAppearTime = 0
    iconsTargetVisible = false
    cachedAfflictionIcons = {}
end

-- Reusable matrices for optimization
local scaleZeroMat = Matrix()
scaleZeroMat:Scale(Vector(0.001, 0.001, 0.001))

local function GetIndicatorBoneSource(ply)
    local fakeRag = ply:GetNWEntity("FakeRagdoll")
    if IsValid(fakeRag) then return fakeRag, true end

    -- FakeRagdoll is the sole ragdoll trace source. Do not fall through to
    -- RagdollDeath or GetRagdollEntity: those can point at stale/different
    -- skeletons and leave old transforms on the indicator.
    return ply, false
end

local function SyncBonesCallback(ent, numbones)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local src, isRag = GetIndicatorBoneSource(ply)
    
    local srcPos = src:GetPos()
    local srcAng = src:GetAngles()

    if isRag then
        local minZ = math.huge
        for i = 0, src:GetBoneCount() - 1 do
            local mat = src:GetBoneMatrix(i)
            if mat then
                local pos = mat:GetTranslation()
                if pos.z < minZ then minZ = pos.z end
            end
        end

        local pelvis = src:LookupBone("ValveBiped.Bip01_Pelvis")
        if pelvis then
            local pMat = src:GetBoneMatrix(pelvis)
            if pMat then
                srcPos = pMat:GetTranslation()
                if minZ ~= math.huge then srcPos.z = minZ end
            end
        end

        local ragYaw = srcAng.y
        if srcAng.p == 0 and srcAng.r == 0 and (ragYaw == 0 or ragYaw == -90 or ragYaw == 90) then
            local eyeAng = ply:EyeAngles()
            srcAng = Angle(0, lastKnownFacingAngle ~= 0 and lastKnownFacingAngle or eyeAng.y, 0)
        else
            srcAng = Angle(0, ragYaw, 0)
            lastKnownFacingAngle = ragYaw
        end
    else
        local eyeAng = ply:EyeAngles()
        srcAng = Angle(0, eyeAng.y, 0)
        lastKnownFacingAngle = eyeAng.y
    end
    
    local srcWorld = Matrix()
    srcWorld:SetTranslation(srcPos)
    srcWorld:SetAngles(srcAng)
    local srcInv = srcWorld:GetInverseTR()
    
    local entTransform = Matrix()
    entTransform:SetTranslation(Vector(0, 0, 0))
    entTransform:SetAngles(Angle(0, 0, 0))
    
    for i = 0, numbones - 1 do
        local name = ent:GetBoneName(i)
        local srcBone = src:LookupBone(name)
        if srcBone then
            local mat = src:GetBoneMatrix(srcBone)
            if mat then
                local manipScale = ent:GetManipulateBoneScale(i)
                
                local localMat = srcInv * mat
                local finalMat = entTransform * localMat
                
                if manipScale == Vector(0,0,0) then
                    finalMat = finalMat * scaleZeroMat
                elseif manipScale ~= Vector(1,1,1) then
                    local scaleMat = Matrix()
                    scaleMat:Scale(manipScale)
                    finalMat = finalMat * scaleMat
                end
                
                ent:SetBoneMatrix(i, finalMat)
            end
        end
    end
end

local function DrawHealthAccessories(healthModel, ply, baseCol)
    local accessories = ply:GetNetVar("Accessories")
    if not accessories then 
        if healthModel.accessories then
            for k, v in pairs(healthModel.accessories) do
                if IsValid(v) then v:Remove() end
            end
            healthModel.accessories = nil
        end
        return 
    end
    
    healthModel.accessories = healthModel.accessories or {}
    local accList = istable(accessories) and accessories or {accessories}
    local currentAccs = {}
    
    for _, accName in pairs(accList) do
        currentAccs[accName] = true
        local accessData = hg.Accessories[accName]
        if not accessData then continue end
        if accessData.norender then continue end
        
        local model = healthModel.accessories[accName]
        local isFemale = false
        if hg.Appearance.FuckYouModels and hg.Appearance.FuckYouModels[2][healthModel:GetModel()] then
            isFemale = true
        end
        
        if not IsValid(model) then
            local modelPath = isFemale and accessData.femmodel or accessData.model
            if not modelPath then continue end
            
            model = ClientsideModel(modelPath, RENDERGROUP_OTHER)
            model:SetNoDraw(true)
            model:SetModelScale(accessData[isFemale and "fempos" or "malepos"][3])
            
            local skin = accessData.skin
            if isfunction(skin) then skin = skin(healthModel) end
            model:SetSkin(skin or 0)
            
            model:SetBodyGroups(accessData.bodygroups or "")
            
            if accessData.bonemerge then
                model:AddEffects(EF_BONEMERGE)
            end
            
            if accessData.SubMat then
                model:SetSubMaterial(0, accessData.SubMat)
            end
            
            healthModel.accessories[accName] = model
        end
        
        local boneName = accessData.bone
        local bone = healthModel:LookupBone(boneName)
        
        if bone then
            local matrix = healthModel:GetBoneMatrix(bone)
            if matrix then
                local bonePos, boneAng = matrix:GetTranslation(), matrix:GetAngles()
                local posData = accessData[isFemale and "fempos" or "malepos"]
                local localPos, localAng = posData[1], posData[2]
                
                local pos, ang = LocalToWorld(localPos, localAng, bonePos, boneAng)
                
                model:SetRenderOrigin(pos)
                model:SetRenderAngles(ang)
                
                if model:GetParent() ~= healthModel then
                    model:SetParent(healthModel, bone)
                end

                render.SetColorModulation(1, 1, 1)
                for _, offset in ipairs(outlineOffsets) do
                    model:SetRenderOrigin(pos + offset)
                    model:DrawModel()
                end

                render.SetColorModulation(0.5, 0.5, 0.5)
                model:SetRenderOrigin(pos)
                model:DrawModel()
            end
        end
    end
    
    for name, model in pairs(healthModel.accessories) do
        if not currentAccs[name] then
            if IsValid(model) then model:Remove() end
            healthModel.accessories[name] = nil
        end
    end
end

local function GetOrgValueNumber(value)
    if type(value) == "number" then return value end
    if type(value) == "table" then
        if type(value[1]) == "number" then return value[1] end
        if type(value.cur) == "number" then return value.cur end
        if type(value.value) == "number" then return value.value end
    end
    return 0
end

local function GetStatusIcon(iconName)
    local cached = statusIconCache[iconName]
    if cached ~= nil then
        return cached or nil
    end

    local mat = Material("sef_icons/" .. iconName .. ".png", "smooth")
    if mat:IsError() then
        statusIconCache[iconName] = false
        return nil
    end

    statusIconCache[iconName] = mat
    return mat
end

function HUD_DrawDynamicIndicator()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local alive = ply:Alive()
    if lastLifeState ~= alive then
        ResetModels(ply)
        lastLifeState = alive
    end
    
    if not alive then return end
    if gui.IsGameUIVisible() then return end
    
    if not IsValid(healthModel) then
        healthModel = ClientsideModel(ply:GetModel(), RENDERGROUP_OTHER)
        healthModel:SetNoDraw(true)
        healthModel:SetIK(false)
        healthModel:AddCallback("BuildBonePositions", SyncBonesCallback)
    end
    
    if not IsValid(blinkModel) then
        blinkModel = ClientsideModel(ply:GetModel(), RENDERGROUP_OTHER)
        blinkModel:SetNoDraw(true)
        blinkModel:SetIK(false)
        InitBlinkModel(blinkModel)
        blinkModel:AddCallback("BuildBonePositions", SyncBonesCallback)
    end

    if healthModel:GetModel() ~= ply:GetModel() or (ply.PlayerClassName ~= healthModel.lastPlayerClassName) then
        healthModel:SetModel(ply:GetModel())
        blinkModel:SetModel(ply:GetModel())
        InitBlinkModel(blinkModel)
        boneStates = {}
        fadingBones = {}
        healthModel.lastPlayerClassName = ply.PlayerClassName
        
        if healthModel.accessories then
            for _, v in pairs(healthModel.accessories) do
                if IsValid(v) then v:Remove() end
            end
            healthModel.accessories = nil
        end
    end

    local consciousness = 1
    local org = ply.organism
    
    if org and org.consciousness then 
        consciousness = org.consciousness 
    end
    
    local time = CurTime()
    local damagedBones = {}
    
    -- Check spine damage levels for cascading limb damage
    local spine1Broken = org and GetOrgValueNumber(org.spine1 or 0) >= 1
    local spine2Broken = org and GetOrgValueNumber(org.spine2 or 0) >= 1
    local spine3Broken = org and GetOrgValueNumber(org.spine3 or 0) >= 0.8

    if org then
        for key, data in pairs(majorBones) do
            local organName = data.organ
            -- Initialize bone state even if organ data doesn't exist yet
            if not boneStates[key] then
                boneStates[key] = {
                    amputated = false,
                    blinking = false,
                    blinkEnd = 0,
                    fractured = false,
                    fractureTime = 0
                }
            end

            if not org[organName] then continue end

            local boneName = data.bone
            local isAmputated = data.canAmputate and org[organName .. "amputated"]
            local isBroken = GetOrgValueNumber(org[organName]) >= 1
            local isDislocated = org[organName .. "dislocation"]

            -- SPINE DAMAGE CASCADING: Apply spine damage to limbs
            -- spine1 broken = both legs black
            -- spine2 broken = chest, legs, arms black
            -- spine3 broken = everything black
            if spine3Broken then
                -- Everything is broken
                isBroken = true
            elseif spine2Broken then
                -- Chest, legs, and arms are broken
                if organName == "chest" or organName == "lleg" or organName == "rleg" or
                   organName == "larm" or organName == "rarm" or organName == "stomach" or
                   organName == "pelvis" then
                    isBroken = true
                end
            elseif spine1Broken then
                -- Both legs are broken
                if organName == "lleg" or organName == "rleg" then
                    isBroken = true
                end
            end

            local state = boneStates[key]
            local ampBoneName = data.ampBone or boneName

            if state.amputated and not isAmputated then
                state.amputated = false
                state.blinking = false
                local boneID = healthModel:LookupBone(ampBoneName)
                if boneID then ScaleBone(healthModel, boneID, Vector(1, 1, 1), ampBoneName) end
                local blinkBoneID = blinkModel:LookupBone(ampBoneName)
                if blinkBoneID then ScaleBone(blinkModel, blinkBoneID, Vector(0, 0, 0), ampBoneName) end
            end

            if state.fractured and not (isBroken or isDislocated) then
                state.fractured = false
                if not state.amputated then
                    local blinkBoneID = blinkModel:LookupBone(boneName)
                    if blinkBoneID then ScaleBone(blinkModel, blinkBoneID, Vector(0, 0, 0), boneName) end
                    
                    local boneID = healthModel:LookupBone(boneName)
                    if boneID then ScaleBone(healthModel, boneID, Vector(1, 1, 1), boneName) end
                end
            end

            local damageValue = GetOrgValueNumber(org[organName])
            
            -- Handle fading out when bone is fully healed
            local prevFade = fadingBones[key]
            if damageValue and damageValue > 0 then
                -- Bone is damaged, remove from fading if it was there
                if prevFade then
                    fadingBones[key] = nil
                end
            elseif prevFade then
                -- Bone was fading, check if fade is complete
                if time > prevFade.endTime then
                    fadingBones[key] = nil
                end
            end

            if isAmputated then
                if state.fractured then
                     state.fractured = false
                     local blinkBoneID = blinkModel:LookupBone(boneName)
                     if blinkBoneID then ScaleBone(blinkModel, blinkBoneID, Vector(0, 0, 0), boneName) end
                     
                     local boneID = healthModel:LookupBone(boneName)
                     if boneID then ScaleBone(healthModel, boneID, Vector(1, 1, 1), boneName) end
                end

                if not state.amputated then
                    state.amputated = true
                    state.blinking = true
                    state.blinkEnd = time + BLINK_DURATION
                    pulseStartTime = time
                    
                    local boneID = healthModel:LookupBone(ampBoneName)
                    if boneID then ScaleBone(healthModel, boneID, Vector(0, 0, 0), ampBoneName) end
                    
                    local blinkBoneID = blinkModel:LookupBone(ampBoneName)
                    if blinkBoneID then ScaleBone(blinkModel, blinkBoneID, BLINK_SCALE, ampBoneName) end
                end
                
                if state.blinking and time > state.blinkEnd then
                    state.blinking = false
                    local blinkBoneID = blinkModel:LookupBone(ampBoneName)
                    if blinkBoneID then ScaleBone(blinkModel, blinkBoneID, Vector(0, 0, 0), ampBoneName) end
                end
                
            elseif (isBroken or isDislocated) then
                if not state.fractured then
                    state.fractured = true
                    state.fractureTime = time
                    pulseStartTime = time
                    local blinkBoneID = blinkModel:LookupBone(boneName)
                    if blinkBoneID then ScaleBone(blinkModel, blinkBoneID, BLINK_SCALE, boneName) end
                    
                    local boneID = healthModel:LookupBone(boneName)
                    if boneID then ScaleBone(healthModel, boneID, Vector(0, 0, 0), boneName) end
                end
            end

            if damageValue and damageValue > 0 and damageValue < 1 and not state.fractured and not state.amputated then
                table.insert(damagedBones, {key = key, damage = damageValue, fading = false})
            elseif damageValue and damageValue == 0 and not state.fractured and not state.amputated then
                -- Bone was damaged but is now healed - start fade out if not already fading
                local prevDamage = prevFade and prevFade.lastDamage or 0
                if prevDamage > 0 and not fadingBones[key] then
                    fadingBones[key] = {
                        key = key,
                        lastDamage = prevDamage,
                        startTime = time,
                        endTime = time + FADE_DURATION
                    }
                end
                -- Add to damagedBones for rendering during fade
                if fadingBones[key] then
                    table.insert(damagedBones, {key = key, damage = fadingBones[key].lastDamage, fading = true})
                end
            end
            
            -- Store current damage for next frame comparison
            if fadingBones[key] then
                fadingBones[key].lastDamage = damageValue
            end
        end
    end
    
    local size = IND_SIZE_BASE
    local w, h = ScreenScaleFixed(size), ScreenScaleFixed(size)
    
    local viewX, viewY
    
    -- Position at bottom left of screen
    viewX = ScreenScaleFixed(30) -- Left margin
    viewY = ScrH() - h - ScreenScaleFixed(50) -- Position at bottom with margin
    
    -- Store indicator position and size for moodle adjustment
    HUD.dynamicIndicator = {
        x = viewX,
        y = viewY,
        w = w,
        h = h,
        active = true
    }
    
    local camPos = Vector(95, 0, 65) 
    local lookAng = Angle(11, 180, 0)

    cam.Start3D(camPos, lookAng, 50, viewX, viewY, w, h)
        render.SuppressEngineLighting(true)
        render.MaterialOverride(whiteMat)
        
        local col = math.Clamp(consciousness, 0, 1)
        
        local srcEnt = GetIndicatorBoneSource(ply)
        local modelOffset = Vector(0, 0, 10)

        local drawAng = Angle(0, 0, 0)

        -- Always update sequence and cycle for proper animation sync
        healthModel:SetSequence(srcEnt:GetSequence())
        healthModel:SetCycle(srcEnt:GetCycle())
        blinkModel:SetSequence(srcEnt:GetSequence())
        blinkModel:SetCycle(srcEnt:GetCycle())

        healthModel:SetPos(modelOffset)
        healthModel:SetAngles(drawAng)
        blinkModel:SetAngles(drawAng)

        for i = 0, ply:GetNumBodyGroups() - 1 do
            healthModel:SetBodygroup(i, ply:GetBodygroup(i))
        end
        healthModel:SetSkin(ply:GetSkin())

        healthModel:SetupBones()

        local base_col = math.max(0.2, consciousness)

        render.SetColorModulation(base_col, base_col, base_col)
        for _, offset in ipairs(outlineOffsets) do
            healthModel:SetPos(modelOffset + offset)
            healthModel:DrawModel()
        end

        render.SetColorModulation(base_col, base_col, base_col)
        healthModel:SetPos(modelOffset)
        healthModel:DrawModel()
        
        DrawHealthAccessories(healthModel, ply, base_col)

        local function DrawDamageBlinkState(blinkModel, r, g, b)
            blinkModel:SetupBones()

            local dimR, dimG, dimB = r * base_col, g * base_col, b * base_col
            render.SetColorModulation(dimR, dimG, dimB)
            for _, offset in ipairs(outlineOffsets) do
                blinkModel:SetPos(modelOffset + offset)
                blinkModel:DrawModel()
            end

            render.SetColorModulation(dimR, dimG, dimB)
            blinkModel:SetPos(modelOffset)
            blinkModel:DrawModel()
        end

        -- DAMAGE COLORS LOGIC (Verified Working: 0.0=White -> 0.5=Yellow -> 0.75=Orange -> 1.0=Red)
        for _, data in ipairs(damagedBones) do
            local boneName = majorBones[data.key].bone
            local bID = blinkModel:LookupBone(boneName)
            if bID then
                local r, g, b, alpha
                local damage = data.damage
                if damage <= 0.5 then
                    local prog = damage / 0.5
                    r, g, b = 1, 1, 1 - prog
                elseif damage <= 0.75 then
                    local prog = (damage - 0.5) / 0.25
                    r, g, b = 1, 1 - 0.5 * prog, 0
                elseif damage <= 0.99 then
                    local prog = (damage - 0.75) / 0.24
                    r, g, b = 1, 0.5 - 0.5 * prog, 0
                else
                    r, g, b = 1, 0, 0
                end

                -- Apply fade alpha if bone is fading out after being healed
                alpha = 1
                if data.fading and fadingBones[data.key] then
                    local fadeProgress = 1 - math.Clamp((time - fadingBones[data.key].startTime) / FADE_DURATION, 0, 1)
                    alpha = fadeProgress
                end

                ScaleBone(blinkModel, bID, BLINK_SCALE, boneName)
                DrawDamageBlinkState(blinkModel, r * alpha, g * alpha, b * alpha)
                ScaleBone(blinkModel, bID, Vector(0,0,0), boneName)
            end
        end

        local hasAmputationBlink = false
        local hasFractureBlink = false
        local solidRedBones = {}
        local blinkingRedBones = {}
        local bleedingBones = {} -- key -> {severity = num, isArterial = bool}

        for key, state in pairs(boneStates) do
            if state.blinking then hasAmputationBlink = true end
            if state.fractured then
                hasFractureBlink = true
                if (time - state.fractureTime) < SOLID_RED_DURATION then
                    table.insert(solidRedBones, key)
                else
                    table.insert(blinkingRedBones, key)
                end
            end
        end

        if IsValid(ply) then
            local function CheckWoundList(list, isArterial)
                if not list then return end
                for i = 1, #list do
                    local wound = list[i]
                    if type(wound) == "table" and (wound[1] or 0) > 0.001 then
                        local boneName = wound[4]
                        if type(boneName) == "string" then
                            -- Check against major bones
                            for key, data in pairs(majorBones) do
                                if data.bone == boneName then
                                    if not bleedingBones[key] then
                                        bleedingBones[key] = {severity = 0, isArterial = false}
                                    end
                                    bleedingBones[key].severity = bleedingBones[key].severity + (wound[1] or 0)
                                    if isArterial then
                                        bleedingBones[key].isArterial = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            local netWounds = ply:GetNetVar("wounds", nil)
            local netArterial = ply:GetNetVar("arterialwounds", nil)
            CheckWoundList((netWounds and #netWounds > 0) and netWounds or ply.wounds, false)
            CheckWoundList((netArterial and #netArterial > 0) and netArterial or ply.arterialwounds, true)
        end

        if hasAmputationBlink then
            local val = (math.sin(time * 10) + 1) / 2
            DrawDamageBlinkState(blinkModel, 1, 1 - val, 1 - val)
        end

        if #solidRedBones > 0 then
            for _, key in ipairs(solidRedBones) do
                local boneName = majorBones[key].bone
                local bID = blinkModel:LookupBone(boneName)
                if bID then
                    ScaleBone(blinkModel, bID, BLINK_SCALE, boneName)
                    DrawDamageBlinkState(blinkModel, 1, 0, 0)
                    ScaleBone(blinkModel, bID, Vector(0,0,0), boneName)
                end
            end
        end

        if #blinkingRedBones > 0 then
            local val = (math.sin(time * FRACTURE_BLINK_SPEED) + 1) / 2
            for _, key in ipairs(blinkingRedBones) do
                local boneName = majorBones[key].bone
                local bID = blinkModel:LookupBone(boneName)
                if bID then
                    ScaleBone(blinkModel, bID, BLINK_SCALE, boneName)
                    DrawDamageBlinkState(blinkModel, val, 0, 0)
                    ScaleBone(blinkModel, bID, Vector(0,0,0), boneName)
                end
            end
        end

        -- Draw bleeding icons as 3D billboards that stick to the model bones
        if next(bleedingBones) then
            render.MaterialOverride(nil)
            render.SetColorModulation(1, 1, 1)
            render.SuppressEngineLighting(true)

            for key, data in pairs(bleedingBones) do
                local boneName = majorBones[key].bone
                local boneID = healthModel:LookupBone(boneName)
                if boneID then
                    local mat = healthModel:GetBoneMatrix(boneID)
                    if mat then
                        local pos = mat:GetTranslation()
                        -- Offset toward camera to prevent clipping through model
                        local toCam = (camPos - pos):GetNormalized()
                        pos = pos + toCam * 3.0 + Vector(0, 0, 1.5)

                        local pulse = (math.sin(time * 5 + #key) + 1) / 2
                        local alpha = 0.7 + pulse * 0.3

                        render.SetMaterial(bleedIconMat)
                        render.DrawSprite(pos, 6, 6, Color(255, 255, 255, alpha * 255))
                    end
                end
            end

            render.SuppressEngineLighting(false)
        end

        render.MaterialOverride(nil)
        render.SetColorModulation(1, 1, 1)
        render.SuppressEngineLighting(false)
    cam.End3D()

end

hook.Add("OnRemove", "HG_CleanupHealthIndicator", function()
    if IsValid(healthModel) then healthModel:Remove() end
    if IsValid(blinkModel) then blinkModel:Remove() end
end)
