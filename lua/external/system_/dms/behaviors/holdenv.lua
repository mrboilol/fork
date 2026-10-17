local IKSystem = include("system_/utils/IKChain.lua")

local B = {}

-- LOCALIZATION: Cache globals to bypass hash table lookups [cite: 47, 48]
local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local pairs = pairs
local ipairs = ipairs
local math = math

local STATIC_VALUES = {
    ropeLength = 1.6,
    ropeWidth = 0,
    addLength = 0,
    blendOutTime = 0.5,
    ignoreFloors = true,
    searchInterval = 0.1
}

local DYNAMIC_CVARS = {
    searchRadius    = "ar_holdenv_search_radius",
    minGrabDist     = "ar_holdenv_min_dist",
    maxGrabDist     = "ar_holdenv_max_dist",
    releaseVelocity = "ar_holdenv_release_vel",
    minHoldTime     = "ar_holdenv_min_hold",
    maxHoldTime     = "ar_holdenv_max_hold",
    searchCooldown  = "ar_holdenv_cooldown",
    maxGrabs        = "ar_holdenv_max_grabs"
}

local function GetCfg(key)
    local cvarName = DYNAMIC_CVARS[key]
    if cvarName then
        local cv = GetConVar(cvarName)
        if cv then return cv:GetFloat() end
    end
    return STATIC_VALUES[key]
end

local HAND_CONFIGS = {
    left = {
        bones = { "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand" },
        poleOffset = Vector(10, 15, 0),
    },
    right = {
        bones = { "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand" },
        poleOffset = Vector(10, 15, 0),
    }
}

-- OPTIMIZATION: Reduced loop overhead for bone resolution [cite: 55]
local function FindHandPhys(ragdoll, side)
    if not IsValid(ragdoll) then return nil, nil end
    local config = HAND_CONFIGS[side]
    if not config then return nil, nil end
    
    local targetBoneName = config.bones[3]
    return UniversalBone.FindBone(ragdoll, targetBoneName)
end

local function CreateGrabAnchor(grabPos)
    local anchor = ents.Create("prop_dynamic")
    if not IsValid(anchor) then return nil end
    anchor:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    anchor:SetPos(grabPos)
    anchor:Spawn()
    anchor:SetNoDraw(true)
    anchor:SetSolid(SOLID_NONE)
    return anchor
end

-- STABILITY: Safely trigger IK methods only if they exist 
local function SafeIKCall(chain, methodName, ...)
    if chain and chain[methodName] then
        return chain[methodName](chain, ...)
    end
end

function B:FindGrabPoint(handPos, ragdoll)
    local directions = {
        Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0),
        Vector(0, 0, -1), Vector(0.7, 0.7, 0), Vector(-0.7, 0.7, 0)
    }

    local bestTrace = nil
    local bestScore = -1
    local radius = GetCfg("searchRadius")

    for _, dir in ipairs(directions) do
        local trace = util.TraceLine({
            start = handPos,
            endpos = handPos + dir * radius,
            filter = ragdoll,
            mask = MASK_SOLID_BRUSHONLY
        })

        if trace.Hit and not trace.HitSky then
            if STATIC_VALUES.ignoreFloors and trace.HitNormal.z > 0.7 then continue end

            local dist = trace.Fraction * radius
            local wallFactor = 1 - math.abs(trace.HitNormal.z)
            local score = (1 - trace.Fraction) * (1 + wallFactor)

            if dist >= GetCfg("minGrabDist") and dist <= GetCfg("maxGrabDist") then
                score = score * 1.5
            end

            if score > bestScore then
                bestScore = score
                bestTrace = trace
            end
        end
    end
    return bestTrace
end

function B:ReleaseGrab(ar, side)
    local state = ar.holdEnv[side]
    if not state then return end

    if IsValid(state.rope) then state.rope:Remove() end
    if IsValid(state.anchor) then state.anchor:Remove() end
    
    state.grabbing = false
    state.grabPos = nil
    state.anchor = nil
    state.rope = nil
    state.cooldownUntil = CurTime() + GetCfg("searchCooldown")
    
    ar.holdEnv.currentlyGrabbingHand = nil
    state.blendingOut = true
    state.blendStartTime = CurTime()
end

function B:OnStart(ar)
    local ragdoll = ar.ragdoll
    
    ar.holdEnv = {
        left = { cooldownUntil = 0 },
        right = { cooldownUntil = 0 },
        lastSearchTime = 0,
        currentlyGrabbingHand = nil,
        grabCount = 0,
        ikChains = {}
    }
    
    for side, config in pairs(HAND_CONFIGS) do
        local chain = IKSystem.CreateChain(
            ragdoll, config.bones, "HoldEnv_" .. side, config.poleOffset, 
            {
                iterations = 15, snapBackStrength = 0.3, smoothTime = 0.02,
                positionSmoothTime = 0.08, poleStrength = 0.4
            }
        )
        if chain then
            ar.holdEnv.ikChains[side] = chain
            -- CRASH FIX: Using Reset or similar safe check instead of Stop
            SafeIKCall(chain, "Reset") 
        end
    end
end

function B:OnUpdate(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) or not ar.holdEnv then return end
    
    local curTime = CurTime()

    for side, _ in pairs(HAND_CONFIGS) do
        local state = ar.holdEnv[side]
        local chain = ar.holdEnv.ikChains[side]
        local handPhys, handPhysID = FindHandPhys(ragdoll, side)
        if not IsValid(handPhys) or not chain then continue end
        
        local handPos = handPhys:GetPos()

        if state.blendingOut then
            if curTime > (state.blendStartTime + STATIC_VALUES.blendOutTime) then
                state.blendingOut = false
                -- CRASH FIX: Verified call
                SafeIKCall(chain, "Reset")
            else
                SafeIKCall(chain, "SetTarget", handPos)
            end
            continue
        end

        if not state.grabbing and 
           ar.holdEnv.currentlyGrabbingHand == nil and
           ar.holdEnv.grabCount < GetCfg("maxGrabs") and
           curTime >= state.cooldownUntil and
           curTime - ar.holdEnv.lastSearchTime > STATIC_VALUES.searchInterval then
            
            ar.holdEnv.lastSearchTime = curTime
            
            if handPhys:GetVelocity():Length() > 50 then
                local trace = self:FindGrabPoint(handPos, ragdoll)
                if trace and trace.Hit then
                    local grabPos = trace.HitPos + trace.HitNormal * 2
                    state.anchor = CreateGrabAnchor(grabPos)
                    
                    if IsValid(state.anchor) then
                        state.rope = constraint.Rope(
                            state.anchor, ragdoll, 0, handPhysID,
                            Vector(0, 0, 0), Vector(0, 0, 0),
                            STATIC_VALUES.ropeLength, STATIC_VALUES.addLength,
                            0, STATIC_VALUES.ropeWidth, "cable/rope", false
                        )
                        
                        if IsValid(state.rope) then
                            state.grabbing = true
                            state.grabPos = grabPos
                            state.grabTime = curTime
                            ar.holdEnv.currentlyGrabbingHand = side
                            ar.holdEnv.grabCount = ar.holdEnv.grabCount + 1
                            
                            SafeIKCall(chain, "SetTarget", grabPos)
                            chain.active = true
                        else
                            state.anchor:Remove()
                        end
                    end
                end
            end
        end

        if state.grabbing then
            local shouldRelease = false
            local holdDuration = curTime - state.grabTime
            
            if not IsValid(state.anchor) then shouldRelease = true end
            if holdDuration >= GetCfg("maxHoldTime") then shouldRelease = true end
            if handPhys:GetVelocity():Length() > GetCfg("releaseVelocity") then shouldRelease = true end
            if handPos:Distance(state.grabPos) > GetCfg("maxGrabDist") * 2 then shouldRelease = true end
            
            if shouldRelease and holdDuration > GetCfg("minHoldTime") then
                self:ReleaseGrab(ar, side)
            else
                SafeIKCall(chain, "SetTarget", state.grabPos)
            end
        end
    end
end

function B:OnExit(ar)
    if not ar.holdEnv then return end
    
    for side, _ in pairs(HAND_CONFIGS) do
        self:ReleaseGrab(ar, side)
        local chain = ar.holdEnv.ikChains[side]
        SafeIKCall(chain, "Destroy")
    end
    
    ar.holdEnv = nil
end

DMS:RegisterBehavior("holdenv", B)