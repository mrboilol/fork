local healthModel
local blinkModel
local whiteMat = Material("models/debug/debugwhite")
local statusCircleMat = Material("sef_icons/statuseffectcircle.png", "smooth")
local statusIconCache = {}

local IND_SIZE_BASE = 180
local IND_SIZE_MAX = 240
local ICONS_SCREEN_EDGE_MARGIN = 20
local ICONS_SCREEN_MARGIN_Y = 18
local BLINK_SCALE = Vector(1.05, 1.05, 1.05)
local BLINK_DURATION = 5

local boneStates = {}
local boneCache = {}
local lastLifeState = nil
local iconsVisibility = 0
local iconsAppearTime = 0
local iconsTargetVisible = false
local cachedAfflictionIcons = {}
local lastKnownFacingAngle = 0

local majorBones = {
    pelvis = { organ = "pelvis", bone = "ValveBiped.Bip01_Pelvis" },
    spine1 = { organ = "spine1", bone = "ValveBiped.Bip01_Spine1" },
    spine2 = { organ = "spine2", bone = "ValveBiped.Bip01_Spine2" },
    chest_spine = { organ = "chest", bone = "ValveBiped.Bip01_Spine2" },
    chest_ribs = { organ = "chest", bone = "ValveBiped.Bip01_Spine1", name = "Ribcage" },
    neck = { organ = "spine3", bone = "ValveBiped.Bip01_Neck1" },
    skull = { organ = "skull", bone = "ValveBiped.Bip01_Head1" },
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

local function GetBoneMarkerDimensions(ent, boneID)
    local mat = ent:GetBoneMatrix(boneID)
    if not mat then return end

    local startPos = mat:GetTranslation()
    local endPos
    local longestDistance = 0

    for _, childID in ipairs(ent:GetChildBones(boneID) or {}) do
        local childMat = ent:GetBoneMatrix(childID)
        if childMat then
            local childPos = childMat:GetTranslation()
            local distance = startPos:Distance(childPos)
            if distance > longestDistance then
                longestDistance = distance
                endPos = childPos
            end
        end
    end

    local length = math.Clamp(longestDistance > 0 and longestDistance or 9, 7, 26)
    local width = math.Clamp(length * 0.32, 3.5, 8)
    local pos = endPos and (startPos + endPos) * 0.5 or startPos

    return pos, width, length
end

local function DrawBoneMarker(ent, boneName, color, cameraPos)
    local boneID = ent:LookupBone(boneName)
    if not boneID then return end

    local pos, width, length = GetBoneMarkerDimensions(ent, boneID)
    if not pos then return end

    -- Pull the marker slightly toward the indicator camera so the smooth,
    -- capsule-like circle remains readable over the traced skeleton.
    pos = pos + (cameraPos - pos):GetNormalized() * 1.5
    render.SetMaterial(statusCircleMat)
    render.DrawSprite(pos, width * 2.1, length * 1.15, color)
end

local function GetDamageColor(severity)
    local damage = math.Clamp(severity or 0, 0, 1)

    -- Healthy is white; sustained damage moves through yellow into red.
    -- Broken or dislocated bones are handled separately as blinking red.
    if damage <= 0.5 then
        local progress = damage * 2
        return 1, 1, 1 - progress
    end

    local progress = (damage - 0.5) * 2
    return 1, 1 - progress, 0
end

local function GetOrgValueNumber(value)
    if isnumber(value) then return value end
    if istable(value) then
        if isnumber(value[1]) then return value[1] end
        if isnumber(value.cur) then return value.cur end
        if isnumber(value.value) then return value.value end
    end

    return 0
end

local function IsSubrosaEnabled()
    local convar = GetConVar("hg_subrosa")
    return convar and convar:GetBool()
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

    if org then
        for key, data in pairs(majorBones) do
            local organName = data.organ
            -- Initialize bone state even if organ data doesn't exist yet
            if not boneStates[key] then
                boneStates[key] = {
                    amputated = false,
                    blinking = false,
                    blinkEnd = 0
                }
            end

            if not org[organName] then continue end

            local boneName = data.bone
            local isAmputated = data.canAmputate and org[organName .. "amputated"]
            local severity = math.Clamp(GetOrgValueNumber(org[organName]), 0, 1)
            local isBroken = severity >= 1 or org[organName .. "dislocation"]

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

            if isAmputated then
                if not state.amputated then
                    state.amputated = true
                    state.blinking = true
                    state.blinkEnd = time + BLINK_DURATION
                    
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
            elseif severity > 0 or isBroken then
                damagedBones[key] = {
                    bone = boneName,
                    severity = severity,
                    broken = isBroken
                }
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

        if IsSubrosaEnabled() then
            -- Bone-only mode: every marker is sized from the copied bone and
            -- its child, so the pose is traced without drawing the character.
            cam.IgnoreZ(true)
            for key, data in pairs(majorBones) do
                local r, g, b, alpha = base_col, base_col, base_col, 185
                local damage = damagedBones[key]
                if damage and damage.broken then
                    local blink = 0.45 + (math.sin(time * 10) + 1) * 0.275
                    r, g, b, alpha = 1, 0, 0, 255 * blink
                elseif damage then
                    r, g, b = GetDamageColor(damage.severity)
                    alpha = 235
                end
                DrawBoneMarker(healthModel, data.bone, Color(r * 255, g * 255, b * 255, alpha), camPos)
            end
            cam.IgnoreZ(false)
        else
            render.SetColorModulation(base_col, base_col, base_col)
            for _, offset in ipairs(outlineOffsets) do
                healthModel:SetPos(modelOffset + offset)
                healthModel:DrawModel()
            end

            render.SetColorModulation(base_col, base_col, base_col)
            healthModel:SetPos(modelOffset)
            healthModel:DrawModel()
            DrawHealthAccessories(healthModel, ply, base_col)
        end

        local hasAmputationBlink = false

        for key, state in pairs(boneStates) do
            if state.blinking then hasAmputationBlink = true end
        end

        if hasAmputationBlink and not IsSubrosaEnabled() then
            local val = (math.sin(time * 10) + 1) / 2
            DrawDamageBlinkState(blinkModel, 1, 1 - val, 1 - val)
        end

        if not IsSubrosaEnabled() then
            for _, damage in pairs(damagedBones) do
                local boneID = blinkModel:LookupBone(damage.bone)
                if boneID then
                    local r, g, b
                    if damage.broken then
                        r = 0.35 + (math.sin(time * 10) + 1) * 0.325
                        g, b = 0, 0
                    else
                        r, g, b = GetDamageColor(damage.severity)
                    end

                    ScaleBone(blinkModel, boneID, BLINK_SCALE, damage.bone)
                    DrawDamageBlinkState(blinkModel, r, g, b)
                    ScaleBone(blinkModel, boneID, Vector(0, 0, 0), damage.bone)
                end
            end
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
