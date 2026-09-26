local IKSystem = include("system_/utils/IKChain.lua")

local function IsValidNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function SanitizeVector(vec, fallback)
    if not vec or not isvector(vec) then return fallback end
    if not IsValidNumber(vec.x) or not IsValidNumber(vec.y) or not IsValidNumber(vec.z) then
        return fallback
    end
    return vec
end

local function GetBonePhys(ragdoll, boneName)
    if not IsValid(ragdoll) then return nil end
    local boneID = ragdoll:LookupBone(boneName)
    if not boneID then return nil end
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phys) and ragdoll:TranslatePhysBoneToBone(i) == boneID then
            return phys
        end
    end
    return nil
end

local DEFAULTS = {
    PushDuration = 2,
    PushPeakForce = 100,
    MaxVelocityClamp = 350,
    VelocitySmoothing = 10,
    RaycastDistance = 200,
    MaxStepUpHeight = 18,
    MaxStepDownHeight = 80,
    SearchHeightBuffer = 25,
    FootHullMins = Vector(-2, -2, 0),
    FootHullMaxs = Vector(2, 2, 2),
    MinFootSeparation = 10,
    UprightForce = 425,
    StepHeight = 20,
    HipTargetHeight = 50,
    TimeBeforeDecay = 4.0, 
    DecayDuration = 3.0,
    MaxSlopeAngle = 45,
    GroundStickDistance = 5,
    StepTriggerForward = 15,
    StepTriggerBackward = 15, 
    StepTriggerSide = 15,
    MinMovementSpeed = 15,
    StationaryThreshold = 15,
    FootLockStrength = 0.95,
    AbsoluteTraceDepth = 8192,
    PredictionTime = 0.35,
    MinStepInterval = 0.25, 
}

local CONFIG = setmetatable({}, {
    __index = function(t, key) return DEFAULTS[key] end,
    __newindex = function(t, key, value) DEFAULTS[key] = value end
})

for key, _ in pairs(DEFAULTS) do
    local cvarName = "ar_" .. key
    cvars.AddChangeCallback(cvarName, function(name, old, new)
        CONFIG[key] = tonumber(new) or DEFAULTS[key]
    end, "ConfigUpdate_" .. key)
    
    if ConVarExists(cvarName) then
        CONFIG[key] = GetConVar(cvarName):GetFloat()
    end
end

local function FindGroundPosition(pos, ragdoll, currentFootZ, pelvisZ)
    if not SanitizeVector(pos, nil) or not IsValid(ragdoll) then return nil, nil end
    
    currentFootZ = IsValidNumber(currentFootZ) and currentFootZ or pos.z
    pelvisZ = IsValidNumber(pelvisZ) and pelvisZ or currentFootZ
    
    local heightDiff = math.abs(pelvisZ - currentFootZ)
    local searchUp = math.max(CONFIG.MaxStepUpHeight, heightDiff * 0.5)
    
    local searchStart = SanitizeVector(Vector(pos.x, pos.y, pos.z + searchUp + CONFIG.SearchHeightBuffer), pos)
    local searchEnd = SanitizeVector(Vector(pos.x, pos.y, pos.z - CONFIG.AbsoluteTraceDepth), pos)
    
    local tr = util.TraceHull({
        start = searchStart,
        endpos = searchEnd,
        mins = CONFIG.FootHullMins,
        maxs = CONFIG.FootHullMaxs,
        mask = MASK_SOLID_BRUSHONLY,
        filter = ragdoll
    })
    
    if tr.Hit and SanitizeVector(tr.HitPos, nil) then
        local normal = tr.HitNormal
        local slopeAngle = math.deg(math.acos(math.Clamp(normal:Dot(Vector(0, 0, 1)), -1, 1)))

        if slopeAngle >= 90 then
            return Vector(pos.x, pos.y, currentFootZ), Vector(0, 0, 1)
        end

        if slopeAngle <= CONFIG.MaxSlopeAngle then
            local heightChange = tr.HitPos.z - currentFootZ

            if heightChange <= CONFIG.MaxStepUpHeight and heightChange >= -CONFIG.MaxStepDownHeight then
                return tr.HitPos, normal
            end
        end
    end
    
    local trLine = util.TraceLine({
        start = searchStart, endpos = searchEnd, mask = MASK_SOLID_BRUSHONLY, filter = ragdoll
    })
    
    if trLine.Hit and SanitizeVector(trLine.HitPos, nil) then
        local normal = trLine.HitNormal
        local slopeAngle = math.deg(math.acos(math.Clamp(normal:Dot(Vector(0, 0, 1)), -1, 1)))
        
        if slopeAngle >= 90 then
            return Vector(pos.x, pos.y, currentFootZ), Vector(0, 0, 1)
        end
        
        if slopeAngle <= CONFIG.MaxSlopeAngle then
            local heightChange = trLine.HitPos.z - currentFootZ
            
            if heightChange <= CONFIG.MaxStepUpHeight and heightChange >= -CONFIG.MaxStepDownHeight then
                return trLine.HitPos, normal
            end
        end
    end
    
    return Vector(pos.x, pos.y, currentFootZ), Vector(0, 0, 1)
end

local function FindGroundForBalance(pos, ragdoll)
    if not SanitizeVector(pos, nil) or not IsValid(ragdoll) then return nil end
    
    local searchStart = SanitizeVector(Vector(pos.x, pos.y, pos.z + 10), pos)
    local searchEnd = SanitizeVector(Vector(pos.x, pos.y, pos.z - 200), pos)
    
    local tr = util.TraceLine({
        start = searchStart,
        endpos = searchEnd,
        mask = MASK_SOLID_BRUSHONLY,
        filter = ragdoll
    })
    
    if tr.Hit and SanitizeVector(tr.HitPos, nil) then
        return tr.HitPos
    end
    
    return Vector(pos.x, pos.y, pos.z - 200)
end

local function InitLegs(ragdoll, data)
    if not IsValid(ragdoll) or not data then return end
    
    data.footPositions = {} 
    data.ghostPositions = {} 
    data.lockedFootPositions = {} 
    data.footPhys = {}
    data.groundNormals = { Vector(0, 0, 1), Vector(0, 0, 1) }
    data.hasGroundContact = { false, false }
    data.legState = {
        [1] = { isStepping = false, progress = 0, isLocked = false, lastStepTime = 0 },
        [2] = { isStepping = false, progress = 0, isLocked = false, lastStepTime = 0 }
    }
    
    data.lastSteppedLeg = 0

    local pelvisPhys = GetBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
    local pelvisPos = IsValid(pelvisPhys) and pelvisPhys:GetPos() or ragdoll:GetPos()
    local pelvisAng = IsValid(pelvisPhys) and pelvisPhys:GetAngles() or ragdoll:GetAngles()
    
    local startVel = Vector(0,0,0)
    if IsValid(pelvisPhys) then startVel = pelvisPhys:GetVelocity() end
    local flatStartVel = Vector(startVel.x, startVel.y, 0)
    
    pelvisAng.p = 0; pelvisAng.r = 0
    local legSeparation = 6

    for i = 1, 2 do
        local bone = (i == 1) and "ValveBiped.Bip01_L_Foot" or "ValveBiped.Bip01_R_Foot"
        local phys = GetBonePhys(ragdoll, bone)
        local sideDir = (i == 1) and 1 or -1
        local localOffset = Vector(sideDir * legSeparation, 0, 0) 
        local idealPos = LocalToWorld(localOffset, Angle(0,0,0), pelvisPos, pelvisAng)
        idealPos = SanitizeVector(idealPos, pelvisPos)
        
        if flatStartVel:Length() > 20 then
            local offset = flatStartVel * 0.4
            if offset:Length() > 45 then offset = offset:GetNormalized() * 45 end
            idealPos = idealPos + offset
        end

        local currentFootZ = (IsValid(phys) and phys:GetPos().z) or pelvisPos.z
        local searchPos = SanitizeVector(Vector(idealPos.x, idealPos.y, currentFootZ), pelvisPos)

        local ground, normal = FindGroundPosition(searchPos, ragdoll, currentFootZ, pelvisPos.z)
        local finalPos = ground or (IsValid(phys) and phys:GetPos() or searchPos)
        
        data.footPhys[i] = phys
        
        data.ghostPositions[i] = Vector(finalPos.x, finalPos.y, finalPos.z)
        data.groundNormals[i] = normal or Vector(0, 0, 1)
        data.hasGroundContact[i] = ground ~= nil
        
        if IsValid(phys) then
            data.footPositions[i] = phys:GetPos()
        else
            data.footPositions[i] = Vector(finalPos.x, finalPos.y, finalPos.z)
        end
        data.lockedFootPositions[i] = Vector(data.footPositions[i].x, data.footPositions[i].y, data.footPositions[i].z)
    end
end

local B = {}

function B:OnStart(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    ar:ApplyBoneList({  
        "ValveBiped.Bip01_Spine2",
        "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Thigh", 
        "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_Head1", "ValveBiped.Bip01_L_Thigh", 
        "ValveBiped.Bip01_L_Calf"
    })
    ar:SetStrength(3)
    ar:PlayAnimation("Cower", 0.5, "models/AREAnims/model_anim.mdl")

    self.ikChains = {}
    if IKSystem and IKSystem.CreateChain then
        self.ikChains[1] = IKSystem.CreateChain(ragdoll, { "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot" }, "leftLeg", Vector(0,0,50))
        self.ikChains[2] = IKSystem.CreateChain(ragdoll, { "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot" }, "rightLeg", Vector(0,0,50))
    end

    self.pelvisPhys = GetBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
    self.spinePhys = GetBonePhys(ragdoll, "ValveBiped.Bip01_Spine2")
    
    self.startTime = CurTime()
    self.lastGroundCheckTime = 0
    self.smoothedVelocity = Vector(0,0,0)

    self.pushData = nil
    if ar.dmgpos and isvector(ar.dmgpos) and IsValid(self.pelvisPhys) then
        local pelvisPos = self.pelvisPhys:GetPos()
        local pushDir = pelvisPos - ar.dmgpos
        pushDir.z = 0; pushDir:Normalize()
        self.pushData = { dir = pushDir, startTime = CurTime(), duration = CONFIG.PushDuration }
    end

    InitLegs(ragdoll, self)
end

function B:UpdateGhostPositions(ragdoll, isMoving, horizontalVel)
    if not IsValid(self.pelvisPhys) then return end
    local pelvisPos = self.pelvisPhys:GetPos()
    local pelvisAng = self.pelvisPhys:GetAngles()
    pelvisAng.p = 0; pelvisAng.r = 0
    
    local legSeparation = 7
    local prediction = horizontalVel * CONFIG.PredictionTime 
    
    if prediction:Length() > 60 then
        prediction = prediction:GetNormalized() * 60
    end

    for i = 1, 2 do
        if not isMoving and self.legState[i].isLocked then continue end
        local sideDir = (i == 1) and 1 or -1
        local basePos = LocalToWorld(Vector(sideDir * legSeparation, 0, 0), Angle(0,0,0), pelvisPos, pelvisAng)
        basePos = SanitizeVector(basePos, pelvisPos)
        
        local idealPos = basePos + prediction
        
        local currentZ = (self.ghostPositions[i] and self.ghostPositions[i].z) or pelvisPos.z
        local searchPos = SanitizeVector(Vector(idealPos.x, idealPos.y, currentZ), pelvisPos)
        
        local ground, normal = FindGroundPosition(searchPos, ragdoll, currentZ, pelvisPos.z)
        
        self.hasGroundContact[i] = (ground ~= nil)

        if ground then
            local blendSpeed = isMoving and 20 or 5
            self.ghostPositions[i] = LerpVector(FrameTime() * blendSpeed, self.ghostPositions[i], ground)
            self.groundNormals[i] = normal or Vector(0, 0, 1)
        else
            if not self.ghostPositions[i] then
                self.ghostPositions[i] = Vector(idealPos.x, idealPos.y, pelvisPos.z - CONFIG.HipTargetHeight)
            else
                self.ghostPositions[i] = Vector(
                    self.ghostPositions[i].x, 
                    self.ghostPositions[i].y, 
                    self.ghostPositions[i].z
                )
            end
            self.groundNormals[i] = Vector(0, 0, 1)
        end
    end
end

function B:OnUpdate(ar)
    if not ar or not IsValid(ar.ragdoll) then return end
    local dt = FrameTime()
    local ragdoll = ar.ragdoll
    local currentTime = CurTime()
    
    local pelvisPos, rawVel, pelvisAng = Vector(0,0,0), Vector(0,0,0), Angle(0,0,0)
    if IsValid(self.pelvisPhys) then
        pelvisPos = self.pelvisPhys:GetPos(); rawVel = self.pelvisPhys:GetVelocity(); pelvisAng = self.pelvisPhys:GetAngles()
        pelvisAng.p = 0; pelvisAng.r = 0
    end
    if not IsValidNumber(pelvisPos.x) then return end

    if self.pushData then
        local elapsed = currentTime - self.pushData.startTime
        if elapsed < self.pushData.duration then
            local t = elapsed / self.pushData.duration
            local wave = math.sin(t * math.pi) 
            local currentForce = self.pushData.dir * (CONFIG.PushPeakForce * wave)
            if SanitizeVector(currentForce, nil) then
                self.pelvisPhys:ApplyForceCenter(currentForce)
                if IsValid(self.spinePhys) then self.spinePhys:ApplyForceCenter(currentForce * 0.5) end
            end
        else self.pushData = nil end
    end

    local flatRawVel = Vector(rawVel.x, rawVel.y, 0)
    self.smoothedVelocity = LerpVector(dt * CONFIG.VelocitySmoothing, self.smoothedVelocity, flatRawVel)
    local safeVel = Vector(self.smoothedVelocity.x, self.smoothedVelocity.y, 0)
    local speed = safeVel:Length()
    if speed > CONFIG.MaxVelocityClamp then safeVel:Normalize(); safeVel = safeVel * CONFIG.MaxVelocityClamp; speed = CONFIG.MaxVelocityClamp end

    if currentTime - self.lastGroundCheckTime > 0.05 then
        self:UpdateGhostPositions(ragdoll, speed > CONFIG.MinMovementSpeed, safeVel)
        self.lastGroundCheckTime = currentTime
    end
    
    local dynamicSpeed = math.Clamp(3.0 + (speed / 40), 3.0, 10.0)

    for i = 1, 2 do
        local state = self.legState[i]
        if state.isStepping then
            state.progress = state.progress + (dt * dynamicSpeed)
            if state.progress >= 1.0 then
                state.isStepping = false; state.lastStepTime = currentTime
                self.footPositions[i] = state.targetPos
                self.lockedFootPositions[i] = state.targetPos
            else
                local t = state.progress
                local nextPos = LerpVector(t, state.startPos, state.targetPos)
                nextPos.z = nextPos.z + (math.sin(t * math.pi) * CONFIG.StepHeight)
                self.footPositions[i] = nextPos
            end
        else
            if speed < CONFIG.StationaryThreshold then
                if state.isLocked then self.footPositions[i] = LerpVector(0.3, self.footPositions[i], self.lockedFootPositions[i])
                else state.isLocked = true; self.lockedFootPositions[i] = self.footPositions[i] end
            else
                state.isLocked = false
                
                -- [FIX] SIMPLIFIED DISTANCE TRIGGER
                -- Instead of relying on WorldToLocal rotation math (which breaks when hips spin),
                -- we just check the raw distance squared. 
                -- Since trigger values are 15/15/15, this circle check is mathematically perfect for 360-degree pushes.
                local distSqr = self.footPositions[i]:DistToSqr(self.ghostPositions[i])
                local triggerDist = CONFIG.StepTriggerForward -- 15
                
                if distSqr > (triggerDist * triggerDist) and not self.legState[i==1 and 2 or 1].isStepping and (currentTime - state.lastStepTime) > CONFIG.MinStepInterval then
                    state.isStepping = true; state.progress = 0; state.startPos = self.footPositions[i]

                    local targetVec = self.ghostPositions[i]
                    
                    local grounded, _ = FindGroundPosition(targetVec, ragdoll, self.ghostPositions[i].z, pelvisPos.z)
                    state.targetPos = grounded or targetVec
                end
            end
        end
    end

    for i = 1, 2 do
        if self.ikChains[i] then
            local safeTarget = SanitizeVector(self.footPositions[i], pelvisPos)
            if self.ikChains[i].SetTarget then self.ikChains[i]:SetTarget(safeTarget) end
            if self.ikChains[i].Update then self.ikChains[i]:Update() end
            if self.ikChains[i].Solve then self.ikChains[i]:Solve() end
        end
    end

    if IsValid(self.pelvisPhys) and IsValid(self.spinePhys) then
        local timeAlive = currentTime - self.startTime
        local decayMult = math.Clamp(1.0 - ((timeAlive - CONFIG.TimeBeforeDecay) / CONFIG.DecayDuration), 0.0, 1.0)
        
        local groundedLegs = (self.hasGroundContact[1] and 1 or 0) + (self.hasGroundContact[2] and 1 or 0)
        
        if groundedLegs > 0 then
            local balanceCheckPos = (self.footPositions[1] + self.footPositions[2]) / 2
            local groundBelowFeet = FindGroundForBalance(balanceCheckPos, ragdoll)
            
            if groundBelowFeet then
                local targetPelvisZ = groundBelowFeet.z + CONFIG.HipTargetHeight
                local diffZ = targetPelvisZ - pelvisPos.z
                
                local springForce = diffZ * 35
                
                local damperForce = 0
                if diffZ < 10 then 
                    damperForce = rawVel.z * -12 
                end
                
                local totalZForce = (springForce + damperForce) * decayMult
                
                if IsValidNumber(totalZForce) then
                    self.spinePhys:ApplyForceCenter(Vector(0, 0, math.max(totalZForce, 0)))
                end
            end
        end
        
        if groundedLegs > 0 then
            local lateralOffset = pelvisPos - ((self.footPositions[1] + self.footPositions[2]) / 2)
            lateralOffset.z = 0 
            if lateralOffset:Length() > 2 then
                -- [FIX] DISABLE STABILITY FORCE DURING PUSH
                -- This prevents the "rubber band" effect where the ragdoll stops itself from flying
                if not self.pushData then 
                    local correctionForce = lateralOffset * -8 * decayMult
                    if SanitizeVector(correctionForce, nil) then self.pelvisPhys:ApplyForceCenter(correctionForce) end
                end
            end
        end
    end
    
    for i = 1, 2 do
        if self.ghostPositions and self.ghostPositions[i] then
            debugoverlay.Box(self.ghostPositions[i], Vector(-2,-2,-2), Vector(2,2,2), 0.05, Color(0, 255, 0, 200))
            if self.footPositions[i] then
                debugoverlay.Line(self.footPositions[i], self.ghostPositions[i], 0.05, Color(255, 255, 0), true)
            end
        end
    end
end

function B:OnExit(ar)
    if self.ikChains then
        for _, chain in pairs(self.ikChains) do if chain and chain.Stop then chain:Stop() end end
        if IKSystem and IKSystem.RemoveEntityChains then IKSystem.RemoveEntityChains(ar.ragdoll) end
    end

        ar:ApplyBoneList({
        "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Spine1",
        "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Head1",
        "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot",
        "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot",
        "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
        "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand",
    })
end

DMS:RegisterBehavior("stumble", B)