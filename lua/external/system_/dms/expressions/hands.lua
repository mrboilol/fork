AnimatedHands = AnimatedHands or {}
AnimatedHands.Active = AnimatedHands.Active or {}
setmetatable(AnimatedHands.Active, { __mode = "k" })

local UPDATE_RATE = 0.033

local IsValid = IsValid
local CurTime = CurTime
local FrameTime = FrameTime
local math = math
local Angle = Angle
local pairs = pairs
local next = next
local hook = hook

local zeroAngle = Angle(0, 0, 0)

local EnableHandAnims = GetConVar("ar_HandsAnimation")

AnimatedHands.Poses = {
    ["Lflat"] = {
        ["ValveBiped.Bip01_L_Finger4"]  = Angle(-20, 27, 0), ["ValveBiped.Bip01_L_Finger41"] = Angle(0, 8, 0), ["ValveBiped.Bip01_L_Finger42"] = Angle(0, 29, 0),
        ["ValveBiped.Bip01_L_Finger3"]  = Angle(-8, 12.5, 0), ["ValveBiped.Bip01_L_Finger31"] = Angle(0, 39, 0), ["ValveBiped.Bip01_L_Finger32"] = Angle(0, 25, 0),
        ["ValveBiped.Bip01_L_Finger2"]  = Angle(0, 22, 0), ["ValveBiped.Bip01_L_Finger21"] = Angle(0, -22, 0), ["ValveBiped.Bip01_L_Finger22"] = Angle(0, 12, 0),
        ["ValveBiped.Bip01_L_Finger1"]  = Angle(2, 24, 0), ["ValveBiped.Bip01_L_Finger11"] = Angle(0, -16, 0), ["ValveBiped.Bip01_L_Finger12"] = Angle(0, -12, 0),
        ["ValveBiped.Bip01_L_Finger0"]  = Angle(-8, -12, 0), ["ValveBiped.Bip01_L_Finger01"] = Angle(12, 14, 0), ["ValveBiped.Bip01_L_Finger02"] = Angle(-24, -8, 0)
    },
    ["Rflat"] = {
        ["ValveBiped.Bip01_R_Finger4"]  = Angle(-20, 27, 0), ["ValveBiped.Bip01_R_Finger41"] = Angle(0, 8, 0), ["ValveBiped.Bip01_R_Finger42"] = Angle(0, 29, 0),
        ["ValveBiped.Bip01_R_Finger3"]  = Angle(-8, 12.5, 0), ["ValveBiped.Bip01_R_Finger31"] = Angle(0, 39, 0), ["ValveBiped.Bip01_R_Finger32"] = Angle(0, 25, 0),
        ["ValveBiped.Bip01_R_Finger2"]  = Angle(0, 22, 0), ["ValveBiped.Bip01_R_Finger21"] = Angle(0, -22, 0), ["ValveBiped.Bip01_R_Finger22"] = Angle(0, 12, 0),
        ["ValveBiped.Bip01_R_Finger1"]  = Angle(2, 24, 0), ["ValveBiped.Bip01_R_Finger11"] = Angle(0, -16, 0), ["ValveBiped.Bip01_R_Finger12"] = Angle(0, -12, 0),
        ["ValveBiped.Bip01_R_Finger0"]  = Angle(-8, -12, 0), ["ValveBiped.Bip01_R_Finger01"] = Angle(12, 14, 0), ["ValveBiped.Bip01_R_Finger02"] = Angle(-24, -8, 0)
    },
    ["Lrelaxed"] = {
        ["ValveBiped.Bip01_L_Finger4"]  = Angle(-6, 12, 0), ["ValveBiped.Bip01_L_Finger41"] = Angle(0, 18, 0), ["ValveBiped.Bip01_L_Finger42"] = Angle(0, 10, 0),
        ["ValveBiped.Bip01_L_Finger3"]  = Angle(-4, 10, 0), ["ValveBiped.Bip01_L_Finger31"] = Angle(0, 20, 0), ["ValveBiped.Bip01_L_Finger32"] = Angle(0, 12, 0),
        ["ValveBiped.Bip01_L_Finger2"]  = Angle(-2, 14, 0), ["ValveBiped.Bip01_L_Finger21"] = Angle(0, 22, 0), ["ValveBiped.Bip01_L_Finger22"] = Angle(0, 10, 0),
        ["ValveBiped.Bip01_L_Finger1"]  = Angle(-1, 10, 0), ["ValveBiped.Bip01_L_Finger11"] = Angle(0, 16, 0), ["ValveBiped.Bip01_L_Finger12"] = Angle(0, 12, 0),
        ["ValveBiped.Bip01_L_Finger0"]  = Angle(4, 12, 0), ["ValveBiped.Bip01_L_Finger01"] = Angle(-6, 18, 0), ["ValveBiped.Bip01_L_Finger02"] = Angle(2, 10, 0)
    },
    ["Rrelaxed"] = {
        ["ValveBiped.Bip01_R_Finger4"]  = Angle(-6, -12, 0), ["ValveBiped.Bip01_R_Finger41"] = Angle(0, -18, 0), ["ValveBiped.Bip01_R_Finger42"] = Angle(0, -10, 0),
        ["ValveBiped.Bip01_R_Finger3"]  = Angle(-4, -10, 0), ["ValveBiped.Bip01_R_Finger31"] = Angle(0, -20, 0), ["ValveBiped.Bip01_R_Finger32"] = Angle(0, -12, 0),
        ["ValveBiped.Bip01_R_Finger2"]  = Angle(-2, -14, 0), ["ValveBiped.Bip01_R_Finger21"] = Angle(0, -22, 0), ["ValveBiped.Bip01_R_Finger22"] = Angle(0, -10, 0),
        ["ValveBiped.Bip01_R_Finger1"]  = Angle(-1, -10, 0), ["ValveBiped.Bip01_R_Finger11"] = Angle(0, -16, 0), ["ValveBiped.Bip01_R_Finger12"] = Angle(0, -12, 0),
        ["ValveBiped.Bip01_R_Finger0"]  = Angle(4, -12, 0), ["ValveBiped.Bip01_R_Finger01"] = Angle(-6, -18, 0), ["ValveBiped.Bip01_R_Finger02"] = Angle(2, -10, 0)
    },
    ["Ltense"] = {
        ["ValveBiped.Bip01_L_Finger4"]  = Angle(-20, 27, 0), ["ValveBiped.Bip01_L_Finger41"] = Angle(0, 8, 0), ["ValveBiped.Bip01_L_Finger42"] = Angle(0, 29, 0),
        ["ValveBiped.Bip01_L_Finger3"]  = Angle(-8, 12.5, 0), ["ValveBiped.Bip01_L_Finger31"] = Angle(0, 39, 0), ["ValveBiped.Bip01_L_Finger32"] = Angle(0, 25, 0),
        ["ValveBiped.Bip01_L_Finger2"]  = Angle(-6, 14, 0), ["ValveBiped.Bip01_L_Finger21"] = Angle(0, -36, 0), ["ValveBiped.Bip01_L_Finger22"] = Angle(0, -50, 0),
        ["ValveBiped.Bip01_L_Finger1"]  = Angle(6, -6, 0), ["ValveBiped.Bip01_L_Finger11"] = Angle(0, 2, 0), ["ValveBiped.Bip01_L_Finger12"] = Angle(0, -50, 0),
        ["ValveBiped.Bip01_L_Finger0"]  = Angle(-24, 10, 0), ["ValveBiped.Bip01_L_Finger01"] = Angle(-10, -8, 0), ["ValveBiped.Bip01_L_Finger02"] = Angle(28, 50, 0)
    },
    ["Rtense"] = {
        ["ValveBiped.Bip01_R_Finger4"]  = Angle(-20, 27, 0), ["ValveBiped.Bip01_R_Finger41"] = Angle(0, 8, 0), ["ValveBiped.Bip01_R_Finger42"] = Angle(0, 29, 0),
        ["ValveBiped.Bip01_R_Finger3"]  = Angle(-8, 12.5, 0), ["ValveBiped.Bip01_R_Finger31"] = Angle(0, 39, 0), ["ValveBiped.Bip01_R_Finger32"] = Angle(0, 25, 0),
        ["ValveBiped.Bip01_R_Finger2"]  = Angle(-6, 14, 0), ["ValveBiped.Bip01_R_Finger21"] = Angle(0, -36, 0), ["ValveBiped.Bip01_R_Finger22"] = Angle(0, -50, 0),
        ["ValveBiped.Bip01_R_Finger1"]  = Angle(6, -6, 0), ["ValveBiped.Bip01_R_Finger11"] = Angle(0, 2, 0), ["ValveBiped.Bip01_R_Finger12"] = Angle(0, -50, 0),
        ["ValveBiped.Bip01_R_Finger0"]  = Angle(-24, 10, 0), ["ValveBiped.Bip01_R_Finger01"] = Angle(-10, -8, 0), ["ValveBiped.Bip01_R_Finger02"] = Angle(28, 50, 0)
    },
    ["Lfist"] = {
        ["ValveBiped.Bip01_L_Finger2"]  = Angle(12, -46, 0), ["ValveBiped.Bip01_L_Finger21"] = Angle(0, -18, 0), ["ValveBiped.Bip01_L_Finger22"] = Angle(0, -50, 0),
        ["ValveBiped.Bip01_L_Finger1"]  = Angle(2, -50, 0), ["ValveBiped.Bip01_L_Finger11"] = Angle(0, -32, 0), ["ValveBiped.Bip01_L_Finger12"] = Angle(0, -50, 0),
        ["ValveBiped.Bip01_L_Finger0"]  = Angle(12, 22, 0), ["ValveBiped.Bip01_L_Finger01"] = Angle(-28, 42, 0), ["ValveBiped.Bip01_L_Finger02"] = Angle(6, 26, 0)
    },
    ["Rfist"] = {
        ["ValveBiped.Bip01_R_Finger2"]  = Angle(12, -46, 0), ["ValveBiped.Bip01_R_Finger21"] = Angle(0, -18, 0), ["ValveBiped.Bip01_R_Finger22"] = Angle(0, -50, 0),
        ["ValveBiped.Bip01_R_Finger1"]  = Angle(2, -50, 0), ["ValveBiped.Bip01_R_Finger11"] = Angle(0, -32, 0), ["ValveBiped.Bip01_R_Finger12"] = Angle(0, -50, 0),
        ["ValveBiped.Bip01_R_Finger0"]  = Angle(12, 22, 0), ["ValveBiped.Bip01_R_Finger01"] = Angle(-28, 42, 0), ["ValveBiped.Bip01_R_Finger02"] = Angle(6, 26, 0)
    }
}
AnimatedHands.CurlStages = { "flat", "relaxed", "tense", "fist", "tense", "relaxed" }

function AnimatedHands:AddEntity(ent)
    if not IsValid(ent) then return end
    if self.Active[ent] then return end 
    if EnableHandAnims:GetBool() == false then return end

    local flatL = self.Poses["Lflat"] or {}
    local flatR = self.Poses["Rflat"] or {}
    local relaxedL = self.Poses["Lrelaxed"] or {}
    local relaxedR = self.Poses["Rrelaxed"] or {}

    self.Active[ent] = {
        Stage = 1,
        Progress = 0,
        Speed = 0.65,
        NoiseFreq = math.Rand(1.7, 2),
        NoiseAmp = 2.3,
        WaitTime = math.Rand(0.2, 0.25),
        L_old = flatL,
        R_old = flatR,
        L_new = relaxedL,
        R_new = relaxedR,
        BoneCache = {},
        LastUpdate = CurTime()
    }
end

function AnimatedHands:RemoveEntity(ent)
    if IsValid(ent) and self.Active[ent] then
        local data = self.Active[ent]
        for boneName, boneID in pairs(data.BoneCache) do
            if boneID and boneID >= 0 then
                ent:ManipulateBoneAngles(boneID, zeroAngle)
            end
        end
    end
    self.Active[ent] = nil
end

hook.Add("Think", "AnimatedHands_CurlSystem", function()
    if not next(AnimatedHands.Active) then return end

    local dt = FrameTime()
    local ct = CurTime()
    
    if dt <= 0 or dt > 0.5 then return end

    local toProcess = {}
    for ent, data in pairs(AnimatedHands.Active) do
        toProcess[ent] = data
    end

    for ent, data in pairs(toProcess) do

        if not IsValid(ent) then 
            AnimatedHands:RemoveEntity(ent)
            continue 
        end

        if ct - data.LastUpdate < UPDATE_RATE then continue end
        
        local delta = ct - data.LastUpdate
        data.LastUpdate = ct

        data.Progress = data.Progress + delta * data.Speed

        if data.Progress >= (1 + data.WaitTime) then
            data.Stage = (data.Stage % #AnimatedHands.CurlStages) + 1
            local stag = AnimatedHands.CurlStages[data.Stage]

            data.L_old = data.L_new
            data.R_old = data.R_new
            
            data.L_new = AnimatedHands.Poses["L" .. stag] or {}
            data.R_new = AnimatedHands.Poses["R" .. stag] or {}

            data.Progress = 0
            data.WaitTime = math.Rand(0.2, 0.4)
        end

        local t = math.Clamp(data.Progress, 0, 1)
        t = t * t * (3 - 2 * t)

        local amp = data.NoiseAmp
        local freq = data.NoiseFreq
        local cache = data.BoneCache

        local hands = { 
            {data.L_old, data.L_new, 1}, 
            {data.R_old, data.R_new, -1} 
        }

        for i = 1, 2 do
            local set = hands[i]
            local old_pose = set[1]
            local new_pose = set[2]
            local sideMod = set[3]

            if new_pose then
                for boneName, targetAng in pairs(new_pose) do
                    if not targetAng then continue end
                    
                    local id = cache[boneName]
                    if id == nil then 
                        local boneID = ent:LookupBone(boneName)
                        if boneID then id = boneID else id = -1 end
                        cache[boneName] = id
                    end
                    
                    if id == -1 then continue end

                    local startAng = old_pose and old_pose[boneName] or zeroAngle

                    local p = startAng.p + (targetAng.p - startAng.p) * t
                    local y = startAng.y + (targetAng.y - startAng.y) * t
                    local r = startAng.r + (targetAng.r - startAng.r) * t
                    
                    local noise = math.sin(ct * freq + (id * 0.3)) * amp
                    p = p + noise
                    y = y + (noise * 0.5 * sideMod)
                    
                    ent:ManipulateBoneAngles(id, Angle(p, y, r))
                end
            end
        end
    end
end)

local nextCleanup = 0
hook.Add("Think", "AnimatedHands_SafetyCleanup", function()
    local ct = CurTime()
    if ct < nextCleanup then return end
    nextCleanup = ct + 5
    
    if not next(AnimatedHands.Active) then return end
    
    for ent, _ in pairs(AnimatedHands.Active) do
        if not IsValid(ent) then AnimatedHands:RemoveEntity(ent) end
    end
end)