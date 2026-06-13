local healthModel
local blinkModel
local whiteMat = Material("models/debug/debugwhite")
local statusCircleMat = Material("sef_icons/statuseffectcircle.png", "smooth")
local bleedIconMat = Material("zcity_delta/unitmenu/status/bleeding.png", "smooth")
local bigBleedIconMat = Material("zcity_delta/unitmenu/status/bigbleeding.png", "smooth")
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
    skull = { organ = "skull", bone = "ValveBiped.Bip01_Head1" },
    jaw = { organ = "jaw", bone = "ValveBiped.Bip01_Head1" },
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

local function SyncBonesCallback(ent, numbones)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local src = ply
    local isRag = false
    local fakeRag = ply:GetNWEntity("FakeRagdoll")
    local deathRag = ply:GetNWEntity("RagdollDeath")
    
    if IsValid(fakeRag) then src = fakeRag; isRag = true
    elseif IsValid(deathRag) then src = deathRag; isRag = true
    elseif IsValid(ply:GetRagdollEntity()) then src = ply:GetRagdollEntity(); isRag = true end

    if not IsValid(src) then return end
    
    -- FIX: Temporarily reset bone manipulations to get original bone matrices
    -- This prevents IK foot system from interfering with bone tracing
    local savedBonePositions = {}
    local savedBoneAngles = {}
    if src == ply then
        for i = 0, src:GetBoneCount() - 1 do
            savedBonePositions[i] = src:GetManipulateBonePosition(i)
            savedBoneAngles[i] = src:GetManipulateBoneAngles(i)
            src:ManipulateBonePosition(i, Vector())
            src:ManipulateBoneAngles(i, Angle())
        end
        src:SetupBones()
    end
    
    local srcPos = src:GetPos()
    local srcAng = src:GetAngles()

    -- FIX: Ragdoll drooping and north-facing issues
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
                -- Anchor ragdolls to the pelvis x/y but lowest bone z
                srcPos = pMat:GetTranslation()
                if minZ ~= math.huge then
                    srcPos.z = minZ
                end
            end
        end
        -- Prevent snapping North: Use last known facing angle or player eye angles
        -- When ragdoll angles are zeroed/invalid, use stored angle or player eye angles
        local ragYaw = srcAng.y
        if srcAng.p == 0 and srcAng.r == 0 and (ragYaw == 0 or ragYaw == -90 or ragYaw == 90) then
            -- Ragdoll angles are likely default/invalid, use last known good angle or player eye angles
            local eyeAng = ply:EyeAngles()
            if lastKnownFacingAngle ~= 0 then
                srcAng = Angle(0, lastKnownFacingAngle, 0)
            else
                srcAng = Angle(0, eyeAng.y, 0)
            end
        else
            -- Use ragdoll's actual yaw but update our stored angle
            srcAng = Angle(0, ragYaw, 0)
            lastKnownFacingAngle = ragYaw
        end
    else
        -- FIX: Prevent the model from leaning backward/forward when you look up/down
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
                -- CRITICAL: Skip bone manipulation for the local player's actual model
                -- This prevents the health indicator's bone scaling from wrecking the bone tracing system
                if ent == ply then continue end

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
    
    -- FIX: Restore bone manipulations after reading bone matrices
    if src == ply then
        for i = 0, src:GetBoneCount() - 1 do
            if savedBonePositions[i] then
                src:ManipulateBonePosition(i, savedBonePositions[i])
            end
            if savedBoneAngles[i] then
                src:ManipulateBoneAngles(i, savedBoneAngles[i])
            end
        end
        src:SetupBones()
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
    local spine3Broken = org and GetOrgValueNumber(org.spine3 or 0) >= 1

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
            local isBroken = (organName == "skull" and GetOrgValueNumber(org[organName]) >= 0.6) or (GetOrgValueNumber(org[organName]) >= 1)
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
    viewX = ScreenScaleFixed(10) -- Left margin
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
        
        local srcEnt = ply
        local isRagdoll = false
        local fakeRag = ply:GetNWEntity("FakeRagdoll")
        local deathRag = ply:GetNWEntity("RagdollDeath")
        
        if IsValid(fakeRag) then
            srcEnt = fakeRag
            isRagdoll = true
        elseif IsValid(deathRag) then
            srcEnt = deathRag
            isRagdoll = true
        elseif IsValid(ply:GetRagdollEntity()) then
            srcEnt = ply:GetRagdollEntity()
            isRagdoll = true
        end

        local modelOffset
        if isRagdoll then
            -- With the ragdoll lowest-Z fix, we no longer need a huge offset
            modelOffset = Vector(0, 0, 10)
        else
            modelOffset = Vector(0, 0, 10)
        end

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

        -- Ensure skull (head) is always visible for the health indicator
        local skullBoneID = healthModel:LookupBone("ValveBiped.Bip01_Head1")
        if skullBoneID then
            ScaleBoneAndChildren(healthModel, skullBoneID, Vector(1, 1, 1))
        end

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

            render.SetColorModulation(r, g, b)
            for _, offset in ipairs(outlineOffsets) do
                blinkModel:SetPos(modelOffset + offset)
                blinkModel:DrawModel()
            end

            render.SetColorModulation(r, g, b)
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

                local isHeadBone = (boneName == "ValveBiped.Bip01_Head1")
                if isHeadBone then
                    local headPos = healthModel:GetBoneMatrix(bID):GetTranslation()
                    local splitZ = headPos.z - 1.0
                    local normal, distance
                    if data.key == "skull" then
                        normal = Vector(0, 0, 1)
                        distance = normal:Dot(Vector(0, 0, splitZ))
                    else -- jaw
                        normal = Vector(0, 0, -1)
                        distance = normal:Dot(Vector(0, 0, splitZ))
                    end
                    render.PushCustomClipPlane(normal, distance)
                end

                ScaleBone(blinkModel, bID, BLINK_SCALE, boneName)
                DrawDamageBlinkState(blinkModel, r * alpha, g * alpha, b * alpha)
                ScaleBone(blinkModel, bID, Vector(0,0,0), boneName)

                if isHeadBone then
                    render.PopCustomClipPlane()
                end
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
                    local isHeadBone = (boneName == "ValveBiped.Bip01_Head1")
                    if isHeadBone then
                        local headPos = healthModel:GetBoneMatrix(bID):GetTranslation()
                        local splitZ = headPos.z - 1.0
                        local normal, distance
                        if key == "skull" then
                            normal = Vector(0, 0, 1)
                            distance = normal:Dot(Vector(0, 0, splitZ))
                        else -- jaw
                            normal = Vector(0, 0, -1)
                            distance = normal:Dot(Vector(0, 0, splitZ))
                        end
                        render.PushCustomClipPlane(normal, distance)
                    end

                    ScaleBone(blinkModel, bID, BLINK_SCALE, boneName)
                    DrawDamageBlinkState(blinkModel, 1, 0, 0)
                    ScaleBone(blinkModel, bID, Vector(0,0,0), boneName)

                    if isHeadBone then
                        render.PopCustomClipPlane()
                    end
                end
            end
        end

        if #blinkingRedBones > 0 then
            local val = (math.sin(time * FRACTURE_BLINK_SPEED) + 1) / 2
            for _, key in ipairs(blinkingRedBones) do
                local boneName = majorBones[key].bone
                local bID = blinkModel:LookupBone(boneName)
                if bID then
                    local isHeadBone = (boneName == "ValveBiped.Bip01_Head1")
                    if isHeadBone then
                        local headPos = healthModel:GetBoneMatrix(bID):GetTranslation()
                        local splitZ = headPos.z - 1.0
                        local normal, distance
                        if key == "skull" then
                            normal = Vector(0, 0, 1)
                            distance = normal:Dot(Vector(0, 0, splitZ))
                        else -- jaw
                            normal = Vector(0, 0, -1)
                            distance = normal:Dot(Vector(0, 0, splitZ))
                        end
                        render.PushCustomClipPlane(normal, distance)
                    end

                    ScaleBone(blinkModel, bID, BLINK_SCALE, boneName)
                    DrawDamageBlinkState(blinkModel, val, 0, 0)
                    ScaleBone(blinkModel, bID, Vector(0,0,0), boneName)

                    if isHeadBone then
                        render.PopCustomClipPlane()
                    end
                end
            end
        end

        -- Collect bleeding icon screen positions for 2D overlay after cam.End3D
        local bleedScreen2D = {}
        if next(bleedingBones) then
            local function Project3DToIndicator2D(pos, camPos, lookAng, viewX, viewY, w, h, fov)
                local localPos = pos - camPos
                local forward = lookAng:Forward()
                local right = lookAng:Right()
                local up = lookAng:Up()
                
                local zDist = localPos:Dot(forward)
                if zDist <= 0.1 then return nil, nil end
                
                local xDist = localPos:Dot(right)
                local yDist = localPos:Dot(up)
                
                local fovRad = math.rad(fov)
                local halfW = zDist * math.tan(fovRad * 0.5)
                
                local sx = viewX + w * 0.5 - (xDist / halfW) * (w * 0.5)
                local sy = viewY + h * 0.5 - (yDist / halfW) * (h * 0.5)
                
                return sx, sy
            end

            for key, data in pairs(bleedingBones) do
                local boneName = majorBones[key].bone
                local boneID = healthModel:LookupBone(boneName)
                if boneID then
                    local mat = healthModel:GetBoneMatrix(boneID)
                    if mat then
                        local pos = mat:GetTranslation()
                        pos = pos + Vector(0, 0, 1.5)
                        local sx, sy = Project3DToIndicator2D(pos, camPos, lookAng, viewX, viewY, w, h, 50)
                        if sx and sy then
                            -- Check if this is a neck artery (arteria) wound
                            local isNeckArtery = false
                            local netArterial = ply:GetNetVar("arterialwounds", nil)
                            local arterialList = (netArterial and #netArterial > 0) and netArterial or ply.arterialwounds
                            if arterialList and data.isArterial then
                                for _, wound in ipairs(arterialList) do
                                    if type(wound) == "table" and wound[4] == boneName and wound[7] == "arteria" then
                                        isNeckArtery = true
                                        break
                                    end
                                end
                            end

                            -- Calculate bleeding rate to determine if non-arterial wounds bleed at arterial level
                            -- Arterial wounds bleed at ~wound[1] * 4.5 * pulse / 80 ml per beat
                            -- Regular wounds bleed at ~wound[1] * 7 * 2.0 * pulse / 70 ml per beat (avg rand1=7)
                            -- Neck artery (arteria) typically has wound[1] around 2.0
                            -- Regular arterial wounds typically have wound[1] around 1.0
                            local pulse = org and org.pulse or 70
                            local arterialBleedRate = 1.0 * 4.5 * pulse / 80 -- ~3.94 ml/beat at pulse 70
                            local neckArteryBleedRate = 2.0 * 4.5 * pulse / 80 -- ~7.88 ml/beat at pulse 70
                            local currentBleedRate = data.severity * 7 * 2.0 * pulse / 70 -- Approx regular wound rate

                            local bleedsAtArterialLevel = (currentBleedRate >= arterialBleedRate * 0.8) or data.isArterial
                            local bleedsAtNeckArteryLevel = (currentBleedRate >= neckArteryBleedRate * 0.8) or isNeckArtery

                            table.insert(bleedScreen2D, {sx = sx, sy = sy, severity = data.severity, isArterial = data.isArterial, isNeckArtery = isNeckArtery, bleedsAtArterialLevel = bleedsAtArterialLevel, bleedsAtNeckArteryLevel = bleedsAtNeckArteryLevel, key = key})
                        end
                    end
                end
            end
        end

        render.MaterialOverride(nil)
        render.SetColorModulation(1, 1, 1)
        render.SuppressEngineLighting(false)
    cam.End3D()

    -- Draw bleeding icons as 2D overlays so they always render on top of model bones
    if #bleedScreen2D > 0 then
        local iconSize = ScreenScaleFixed(36)
        for _, data in ipairs(bleedScreen2D) do
            local severity = data.severity
            local bleedsAtArterialLevel = data.bleedsAtArterialLevel
            local bleedsAtNeckArteryLevel = data.bleedsAtNeckArteryLevel
            local r, g, b, mat
            
            if bleedsAtNeckArteryLevel then
                -- Neck artery level: Dark Red (80, 0, 0)
                mat = bigBleedIconMat
                r, g, b = 80, 0, 0
            elseif bleedsAtArterialLevel then
                -- Arterial level: Dark Yellow (160, 140, 0)
                mat = bigBleedIconMat
                r, g, b = 160, 140, 0
            elseif severity >= 1.5 then
                -- Near arterial level: Max Red (255, 0, 0)
                mat = bigBleedIconMat
                r, g, b = 255, 0, 0
            else
                -- Normal bleeding: White to red based on severity
                -- White (255, 255, 255) for small cuts -> Red (255, 0, 0) for heavy bleeding
                mat = bleedIconMat
                local progress = math.Clamp(severity / 1.5, 0, 1)
                r = 255
                g = math.floor(255 * (1 - progress))
                b = math.floor(255 * (1 - progress))
            end

            local pulse = (math.sin(time * 5 + #data.key) + 1) / 2
            local alpha = math.floor((0.7 + pulse * 0.3) * 255)

            local sx, sy = data.sx, data.sy
            
            -- Prevent clipping outside the indicator circle boundaries
            local centerX = viewX + w * 0.5
            local centerY = viewY + h * 0.5
            local maxRadius = w * 0.45 -- Keep it slightly inside the edge
            
            local dx = sx - centerX
            local dy = sy - centerY
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist > maxRadius then
                local scale = maxRadius / dist
                sx = centerX + dx * scale
                sy = centerY + dy * scale
            end

            surface.SetDrawColor(r, g, b, alpha)
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(sx - iconSize * 0.5, sy - iconSize * 0.5, iconSize, iconSize)
        end
    end
end

hook.Add("OnRemove", "HG_CleanupHealthIndicator", function()
    if IsValid(healthModel) then healthModel:Remove() end
    if IsValid(blinkModel) then blinkModel:Remove() end
end)