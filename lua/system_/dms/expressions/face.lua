RagdollFaceAnimator = RagdollFaceAnimator or {}
RagdollFaceAnimator.TrackedRagdolls = RagdollFaceAnimator.TrackedRagdolls or {}

local math_Clamp = math.Clamp
local math_abs = math.abs
local math_sin = math.sin
local math_cos = math.cos
local Lerp = Lerp
local LerpVector = LerpVector
local IsValid = IsValid
local CurTime = CurTime
local pairs = pairs
local ipairs = ipairs

local EnableExpressions = GetConVar("ar_Expressions")

RagdollFaceAnimator.Config = {
    LogicRate = 0.1, 
    BlendSpeed = 25, 
    MaxRagdolls = 32, 
    
    EnableEyes = true, 
    EyeChangeInterval = {2, 5}, 
    EyeLookDistance = 100, 
    EyeLookHeight = {-20, 40}, 
    EyeBlendSpeed = 10, 
    
    EnableBlink = true, 
    BlinkInterval = {1.5, 7}, 
    BlinkSpeed = 18, 
    BlinkAmount = 1.0, 
}

function RagdollFaceAnimator:RegisterRagdoll(ragdoll, sourceEntity)
    if not IsValid(ragdoll) then return false end
    if EnableExpressions:GetBool() == false then return false end
    local flexCount = ragdoll:GetFlexNum()
    
    self.TrackedRagdolls[ragdoll] = {
        SourceEntity = sourceEntity,
        CurrentFlexes = {},
        TargetFlexes = {},
        FlexNameMap = {}, 
        FlexCount = flexCount, 
        LastLogicUpdate = 0,
        Active = true,
        IsRelaxing = false, 
        IsDormant = false, 
        IsPanicked = false,
        CurrentEyeTarget = Vector(0,0,0),
        TargetEyeTarget = Vector(0,0,0),
        NextEyeChange = 0,
        EyesAttachment = ragdoll:LookupAttachment("eyes"),
        NextBlink = CurTime() + 2,
        BlinkState = 0,
        BlinkProgress = 0, 
        CurrentBlinkAmount = 0, 
        BlinkFlexIDs = {}, 
        
        LipSyncTarget = 0,   
        LipSyncCurrent = 0,  
        MouthFlexIDs = {},   
        ShapeFlexIDs = {},   
    }
    
    local data = self.TrackedRagdolls[ragdoll]
    for i = 0, flexCount - 1 do
        data.CurrentFlexes[i] = 0
        data.TargetFlexes[i] = 0
        data.FlexNameMap[string.lower(ragdoll:GetFlexName(i) or "")] = i
    end
    
    self:FindBlinkFlexes(ragdoll)
    self:FindMouthFlexes(ragdoll) 
    return true
end

function RagdollFaceAnimator:GetFlexID(ragdoll, flexName)
    local data = self.TrackedRagdolls[ragdoll]
    if not data then return nil end
    if type(flexName) == "number" then return flexName end
    return data.FlexNameMap[string.lower(tostring(flexName))]
end

function RagdollFaceAnimator:SetFlex(ragdoll, flexName, value, instant)
    local data = self.TrackedRagdolls[ragdoll]
    if not data then return false end
    
    local flexID = self:GetFlexID(ragdoll, flexName)
    if not flexID then return false end

    value = math_Clamp(value, 0, 1)
    
    if instant then
        data.CurrentFlexes[flexID] = value
        ragdoll:SetFlexWeight(flexID, value)
    end
    
    data.TargetFlexes[flexID] = value
    data.IsDormant = false 
    return true
end

function RagdollFaceAnimator:SetFlexes(ragdoll, flexTable, instant)
    if not self.TrackedRagdolls[ragdoll] then return false end
    for name, value in pairs(flexTable) do
        self:SetFlex(ragdoll, name, value, instant)
    end
    return true
end

function RagdollFaceAnimator:FindBlinkFlexes(ragdoll)
    local data = self.TrackedRagdolls[ragdoll]
    local names = { "blink", "upper_close", "lower_close", "eyes_updown", "lid_close", "eyeclose", "close_lid" }
    for name, id in pairs(data.FlexNameMap) do
        for _, n in ipairs(names) do if name:find(n, 1, true) then table.insert(data.BlinkFlexIDs, id) break end end
    end
end

function RagdollFaceAnimator:FindMouthFlexes(ragdoll)
    local data = self.TrackedRagdolls[ragdoll]
    local jawNames = { "jaw_drop", "mouth_open", "open_mouth", "lower_lip_down", "jaw_down" }
    local shapeNames = { "mouth_wide", "platysma", "lip_pucker", "mouth_pucker", "pucker", "stretch", "grimace", "clench" }
    
    for name, id in pairs(data.FlexNameMap) do
        for _, n in ipairs(jawNames) do if name:find(n, 1, true) then data.MouthFlexIDs[id] = true break end end
        for _, n in ipairs(shapeNames) do if name:find(n, 1, true) then data.ShapeFlexIDs[id] = true break end end
    end
end

function RagdollFaceAnimator:LipsSyncs(ragdoll, volume)
    local data = self.TrackedRagdolls[ragdoll]
    if not data then return end

    data.LipSyncTarget = math_Clamp(volume * volume, 0, 1)
    if volume > 0.01 then data.IsDormant = false end
end

function RagdollFaceAnimator:Think()
    local curTime = CurTime()
    local frameTime = FrameTime() 
    
    for ragdoll, data in pairs(self.TrackedRagdolls) do
        if not IsValid(ragdoll) then
            self.TrackedRagdolls[ragdoll] = nil
        else
            if curTime - data.LastLogicUpdate >= self.Config.LogicRate then
                if not data.IsRelaxing then
                    self:CheckBlinkLogic(ragdoll, data)
                    self:CheckEyeLogic(ragdoll, data)
                end
                data.LastLogicUpdate = curTime
            end

            if not data.IsRelaxing then
                local diff = data.LipSyncTarget - data.LipSyncCurrent
                local speed = (diff > 0) and 60 or 8
                if math_abs(diff) > 0.001 then
                    data.LipSyncCurrent = Lerp(frameTime * speed, data.LipSyncCurrent, data.LipSyncTarget)
                else
                    data.LipSyncCurrent = data.LipSyncTarget
                end
            end

            if not data.IsDormant or data.LipSyncTarget > 0 or data.IsPanicked or data.IsRelaxing then
                if not data.IsRelaxing then
                    self:AnimateBlink(ragdoll, data, frameTime)
                    self:AnimateEyes(ragdoll, data, frameTime)
                end

                local blinkLookup = {}
                if not data.IsRelaxing then
                    for _, id in ipairs(data.BlinkFlexIDs) do blinkLookup[id] = true end
                end

                local blend = math_Clamp(frameTime * self.Config.BlendSpeed, 0, 1)
                local moving = false
                local maxVal = 0

                for i = 0, data.FlexCount - 1 do
                    local target = data.TargetFlexes[i] or 0
                    local current = data.CurrentFlexes[i] or 0
                    local proceduralAdd = 0
                    
                    if not data.IsRelaxing and data.LipSyncCurrent > 0.01 then
                        if data.MouthFlexIDs[i] then
                            proceduralAdd = data.LipSyncCurrent
                        end
                        if data.ShapeFlexIDs[i] and data.LipSyncCurrent > 0.5 then
                            proceduralAdd = (data.LipSyncCurrent - 0.5) * 0.4
                        end
                    end
                    
                    local finalTarget = math_Clamp(target + proceduralAdd, 0, 1)
                    local diff = finalTarget - current
                    
                    if math_abs(diff) > 0.001 then
                        local new = Lerp(blend, current, finalTarget)
                        data.CurrentFlexes[i] = new
                        if new > maxVal then maxVal = new end
                        if data.IsRelaxing or not blinkLookup[i] then ragdoll:SetFlexWeight(i, new) end
                        moving = true
                    else
                        if current ~= finalTarget then
                            data.CurrentFlexes[i] = finalTarget
                            if data.IsRelaxing or not blinkLookup[i] then ragdoll:SetFlexWeight(i, finalTarget) end
                        end
                        if finalTarget > maxVal then maxVal = finalTarget end
                    end
                end
                
                if not moving and data.LipSyncTarget <= 0.01 and data.BlinkState == 0 and not data.IsPanicked then data.IsDormant = true end
                if data.IsRelaxing and maxVal < 0.01 then self.TrackedRagdolls[ragdoll] = nil end
            end
        end
    end
end

function RagdollFaceAnimator:SetPanicMode(ragdoll, enable)
    local data = self.TrackedRagdolls[ragdoll]
    if data then data.IsPanicked = enable; data.IsDormant = false end
end

function RagdollFaceAnimator:UnregisterRagdoll(ragdoll) self.TrackedRagdolls[ragdoll] = nil end

function RagdollFaceAnimator:DeathRelax(ragdoll)
    local data = self.TrackedRagdolls[ragdoll]
    if not data then return false end
    data.IsRelaxing = true; data.IsPanicked = false; data.LipSyncTarget = 0; data.LipSyncCurrent = 0
    for i = 0, data.FlexCount - 1 do data.TargetFlexes[i] = 0 end
    data.IsDormant = false
    return true
end

function RagdollFaceAnimator:CheckBlinkLogic(ragdoll, data)
    if not self.Config.EnableBlink or #data.BlinkFlexIDs == 0 then return end
    if data.BlinkState == 0 and CurTime() >= data.NextBlink then
        if data.IsPanicked and math.Rand(0, 1) > 0.5 then data.NextBlink = CurTime() + 1 return end
        data.BlinkState = 1; data.BlinkProgress = 0; data.IsDormant = false 
    end
end

function RagdollFaceAnimator:CheckEyeLogic(ragdoll, data)
    if not self.Config.EnableEyes then return end
    if CurTime() >= data.NextEyeChange then
        local cfg = self.Config
        if data.EyesAttachment and data.EyesAttachment > 0 then
            local attachment = ragdoll:GetAttachment(data.EyesAttachment)
            if attachment then
                local fwd, rgt, up = attachment.Ang:Forward(), attachment.Ang:Right(), attachment.Ang:Up()
                local worldTarget = attachment.Pos + (fwd * cfg.EyeLookDistance) + (rgt * math.Rand(-40, 40)) + (up * math.Rand(cfg.EyeLookHeight[1], cfg.EyeLookHeight[2]))
                data.TargetEyeTarget = WorldToLocal(worldTarget, Angle(0,0,0), attachment.Pos, attachment.Ang)
            end
        end
        data.NextEyeChange = CurTime() + (data.IsPanicked and math.Rand(0.1, 0.4) or math.Rand(cfg.EyeChangeInterval[1], cfg.EyeChangeInterval[2]))
        data.IsDormant = false
    end
end

function RagdollFaceAnimator:AnimateBlink(ragdoll, data, deltaTime)
    if data.BlinkState == 0 then return end
    local progressDelta = deltaTime * self.Config.BlinkSpeed
    if data.BlinkState == 1 then
        data.BlinkProgress = math_Clamp(data.BlinkProgress + progressDelta, 0, 1)
        data.CurrentBlinkAmount = Lerp(data.BlinkProgress, 0, self.Config.BlinkAmount)
        if data.BlinkProgress >= 1 then data.BlinkState = 2; data.BlinkProgress = 0 end
    elseif data.BlinkState == 2 then
        data.BlinkProgress = math_Clamp(data.BlinkProgress + progressDelta, 0, 1)
        data.CurrentBlinkAmount = Lerp(data.BlinkProgress, self.Config.BlinkAmount, 0)
        if data.BlinkProgress >= 1 then
            data.BlinkState = 0; data.CurrentBlinkAmount = 0
            data.NextBlink = CurTime() + math.Rand(self.Config.BlinkInterval[1], self.Config.BlinkInterval[2])
        end
    end
    for _, id in ipairs(data.BlinkFlexIDs) do ragdoll:SetFlexWeight(id, data.CurrentBlinkAmount) end
end

function RagdollFaceAnimator:AnimateEyes(ragdoll, data, deltaTime)
    local distSq = data.CurrentEyeTarget:DistToSqr(data.TargetEyeTarget)
    if distSq > 0.01 or data.IsPanicked then
        data.CurrentEyeTarget = LerpVector(math_Clamp(deltaTime * self.Config.EyeBlendSpeed, 0, 1), data.CurrentEyeTarget, data.TargetEyeTarget)
        local finalPos = data.CurrentEyeTarget
        if data.IsPanicked then
            local t = CurTime() * 50
            finalPos = finalPos + Vector(math_sin(t) * 0.8, math_cos(t * 1.2) * 0.8, 0)
        end
        ragdoll:SetEyeTarget(finalPos)
    end
end

hook.Add("Think", "RagdollFaceAnimator_Think", function() RagdollFaceAnimator:Think() end)