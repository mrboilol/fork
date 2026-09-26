if not _G.IKSystem_Unity_FABRIK then 
    local IKSystem = {}
    local activeChains = {}

    local math_max, math_min, math_acos, math_sqrt, math_abs = math.max, math.min, math.acos, math.sqrt, math.abs
    local math_clamp = math.Clamp
    local vector, angle = Vector, Angle
    local curtime = CurTime
    local frametime = FrameTime
    local isvalid = IsValid
    local lerpvector = LerpVector
    local table_insert, table_remove = table.insert, table.remove
    local debug_line, debug_sphere = debugoverlay.Line, debugoverlay.Sphere
    
    local vec_zero = vector(0, 0, 0)
    local ang_zero = angle(0, 0, 0)
    local shared_mat = Matrix()

    local function IsVectorValid(v)
        return not (v.x ~= v.x or v.y ~= v.y or v.z ~= v.z)
    end

    local function IsNaN(x)
        return x ~= x
    end

    local DEFAULT_CONFIG = {
        maxAngularSpeed = 25600,
        angularDampening = 0.15,
        arriveTime = 0.01,
        iterations = 20,
        snapBackStrength = 0.72,
        smoothTime = 0.02,
        positionSmoothTime = 0.1,
        debug = true,
        poleStrength = 0.15,
        bendBias = 0.15,
        toleranceThreshold = 0.002,
        angleSmoothTime = 0.02
    }

    local function SmoothDamp(current, target, velocity, smoothTime, dt)
        smoothTime = math_max(0.0001, smoothTime)
        local omega = 2 / smoothTime
        local x = omega * dt
        local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
        local change = current - target
        local temp = (velocity + change * omega) * dt
        velocity = (velocity - temp * omega) * exp
        return target + (change + temp) * exp, velocity
    end

    local function SmoothDampVector(current, target, velocity, smoothTime, dt)
        if not current or not target or not velocity then 
            return current or vec_zero, velocity or vec_zero
        end
        local x, vx = SmoothDamp(current.x, target.x, velocity.x, smoothTime, dt)
        local y, vy = SmoothDamp(current.y, target.y, velocity.y, smoothTime, dt)
        local z, vz = SmoothDamp(current.z, target.z, velocity.z, smoothTime, dt)
        return vector(x, y, z), vector(vx, vy, vz)
    end

    local function SmoothDampAngle(current, target, velocity, smoothTime, dt)
        local function NormalizeAngle(a)
            a = a % 360
            if a > 180 then a = a - 360 end
            if a < -180 then a = a + 360 end
            return a
        end
        current = NormalizeAngle(current)
        target = NormalizeAngle(target)
        local diff = target - current
        if diff > 180 then diff = diff - 360 end
        if diff < -180 then diff = diff + 360 end
        local adjustedTarget = current + diff
        return SmoothDamp(current, adjustedTarget, velocity, smoothTime, dt)
    end

    local function VectorsToAngle(forward, right, up)
        if forward:LengthSqr() < 1e-6 or right:LengthSqr() < 1e-6 or up:LengthSqr() < 1e-6 then
            return ang_zero 
        end
        
        shared_mat:SetForward(forward)
        shared_mat:SetRight(right)
        shared_mat:SetUp(up)
        return shared_mat:GetAngles()
    end

    local function CalculatePoleTarget(positions, localPoleOffset, entity, midBoneIndex, pelvisIdx)
        if not isvalid(entity) then return nil end
        
        local n = #positions
        if n < 3 or not localPoleOffset then return nil end

        local midIdx = math.floor(n / 2) + 1
        local midPos = positions[midIdx]
        if not midPos then return nil end

        if pelvisIdx then
            local pelvisMatrix = entity:GetBoneMatrix(pelvisIdx)
            if pelvisMatrix then
                local pForward, pRight, pUp = pelvisMatrix:GetForward(), pelvisMatrix:GetRight(), pelvisMatrix:GetUp()
                local pelvisPos = pelvisMatrix:GetTranslation()

                local poleBase = pelvisPos
                    + pForward * localPoleOffset.x
                    + pRight * localPoleOffset.y
                    + pUp * localPoleOffset.z

                return lerpvector(0.65, midPos, poleBase)
            end
        end

        local boneMatrix = entity:GetBoneMatrix(midBoneIndex)
        if not boneMatrix then return nil end
        
        return boneMatrix:GetTranslation() + 
               boneMatrix:GetForward() * localPoleOffset.x +
               boneMatrix:GetRight() * localPoleOffset.y +
               boneMatrix:GetUp() * localPoleOffset.z
    end

    local function ApplyPoleConstraint(positions, polePos, strength)
        if not polePos or #positions < 3 then return end
        
        local n = #positions
        local root, tip = positions[1], positions[n]
        if not root or not tip then return end
        
        local toTip = tip - root
        if toTip:LengthSqr() < 1e-6 then return end
        local limbDir = toTip:GetNormalized()
        
        for i = 2, n - 1 do
            if not positions[i] then continue end
            
            local toJoint = positions[i] - root
            local projection = limbDir * toJoint:Dot(limbDir)
            local projectedPoint = root + projection
            
            local perpendicular = positions[i] - projectedPoint
            local perpDist = perpendicular:Length()
            
            if perpDist > 0.001 then
                local toPole = polePos - projectedPoint
                local desiredPerp = toPole - limbDir * toPole:Dot(limbDir)
                
                if desiredPerp:LengthSqr() > 0.001 then
                    desiredPerp:Normalize()
                    
                    local blendedPerp = lerpvector(strength, perpendicular:GetNormalized(), desiredPerp)
                    blendedPerp:Normalize()
                    
                    positions[i] = projectedPoint + blendedPerp * perpDist
                end
            end
        end
    end

    local function EnforceBend(positions, boneLengths, bendBias)
        local n = #positions
        if n < 3 then return end
        local mid = math.floor(n / 2) + 1
        if not positions[1] or not positions[n] or not positions[mid] then return end
        
        local root, tip = positions[1], positions[n]
        
        local toTip = tip - root
        if toTip:LengthSqr() < 1e-6 then return end
        local limbDir = toTip:GetNormalized()
        local dist = toTip:Length()
        
        local maxReach = 0
        for i = 1, #boneLengths do maxReach = maxReach + boneLengths[i] end
        
        if maxReach <= 0 then return end

        local extension = dist / maxReach
        if extension > 0.92 then
            local bendAmount = math_clamp((extension - 0.92) / 0.08, 0, 1) * bendBias
            local toMid = positions[mid] - root
            local projection = limbDir * toMid:Dot(limbDir)
            local perpOffset = toMid - projection
            
            if perpOffset:LengthSqr() < 1e-6 then
                perpOffset = limbDir:Cross(vector(0, 0, 1)):GetNormalized()
                if perpOffset:LengthSqr() < 1e-6 then
                    perpOffset = limbDir:Cross(vector(1, 0, 0)):GetNormalized()
                end
            else
                perpOffset:Normalize()
            end
            
            positions[mid] = positions[mid] + perpOffset * maxReach * bendAmount
        end
    end

    local function ResolveIK_Analytic3(positions, targetPos, boneLengths, polePos)
        if not positions or #positions < 3 then return positions or {} end
        local rootPos = positions[1]
        local upper, lower = boneLengths[1], boneLengths[2]
        
        if upper <= 0 or lower <= 0 then return positions end

        local toTarget = targetPos - rootPos
        local dist = toTarget:Length()
        
        if dist <= 0.0001 then return positions end

        local maxReach = upper + lower
        if dist > maxReach then
            dist = maxReach
        elseif dist > maxReach * 0.95 then
            local overlap = (dist - maxReach * 0.95) / (maxReach * 0.05)
            dist = maxReach * 0.95 + (maxReach * 0.05) * (1 - math.exp(-overlap * 2))
        end
        
        local targetDir = toTarget:GetNormalized()
        local cosUpperAngle = math_clamp((upper * upper + dist * dist - lower * lower) / (2 * upper * dist), -1, 1)
        
        if IsNaN(cosUpperAngle) then return positions end

        local upperAngle = math_acos(cosUpperAngle)
        
        local toPole = polePos and (polePos - rootPos) or vector(0, 0, 1)
        local planeNormal = targetDir:Cross(toPole)
        
        if planeNormal:LengthSqr() < 1e-6 then
            planeNormal = targetDir:Cross(vector(0, 1, 0))
            if planeNormal:LengthSqr() < 1e-6 then planeNormal = targetDir:Cross(vector(1, 0, 0)) end
        end
        
        if planeNormal:LengthSqr() < 1e-6 then
            planeNormal = vector(0, 0, 1)
        else
            planeNormal:Normalize()
        end
        
        local bendAxis = planeNormal:Cross(targetDir)
        
        if bendAxis:LengthSqr() < 1e-6 then
            bendAxis = vector(0, 1, 0)
        else
            bendAxis:Normalize()
        end
        
        local elbowDir = targetDir * math.cos(upperAngle) + bendAxis * math.sin(upperAngle)
        
        positions[2] = rootPos + elbowDir * upper
        
        local toTarget3 = targetPos - positions[2]
        if toTarget3:LengthSqr() < 1e-6 then
            positions[3] = positions[2] + elbowDir * lower
        else
            positions[3] = positions[2] + toTarget3:GetNormalized() * lower
        end
        
        return positions
    end

    local function ResolveIK_FABRIK(positions, targetPos, boneLengths, startDirections, completeLength, polePos, config)
        local numJoints = #positions
        local basePos = positions[1]
        local distToTarget = (targetPos - basePos):Length()

        for _, len in ipairs(boneLengths) do if len <= 0 then return positions end end

        if distToTarget > completeLength then
            local dir = (targetPos - basePos):GetNormalized()
            if not IsVectorValid(dir) then dir = vector(0,0,1) end

            for i = 2, numJoints do
                positions[i] = positions[i - 1] + dir * boneLengths[i - 1]
            end
            return positions
        end

        for i = 2, numJoints do
            local naturalPos = positions[i - 1] + startDirections[i - 1]
            positions[i] = lerpvector(config.snapBackStrength * 0.5, positions[i], naturalPos)
        end

        for iter = 1, config.iterations do
            positions[numJoints] = targetPos
            for i = numJoints, 2, -1 do
                local dir = (positions[i - 1] - positions[i]):GetNormalized()
                if not IsVectorValid(dir) then dir = vector(0,0,1) end

                positions[i - 1] = positions[i] + dir * boneLengths[i - 1]
            end

            positions[1] = basePos
            for i = 1, numJoints - 1 do
                local dir = (positions[i + 1] - positions[i]):GetNormalized()
                if not IsVectorValid(dir) then dir = vector(0,0,1) end
                
                if polePos and i == math.floor(numJoints / 2) then
                    local poleDir = (polePos - positions[i]):GetNormalized()
                    if IsVectorValid(poleDir) then
                        dir = (dir + poleDir * config.poleStrength):GetNormalized()
                    end
                end
                
                positions[i + 1] = positions[i] + dir * boneLengths[i]
            end

            if (positions[numJoints] - targetPos):LengthSqr() < config.toleranceThreshold^2 then break end
        end
        
        return positions
    end

    local IKChain = {}
    IKChain.__index = IKChain

    function IKChain:new(entity, boneNames, name, localPoleOffset, customConfig)
        if not isvalid(entity) then return nil end
        
        local chain = setmetatable({}, IKChain)
        chain.entity = entity
        chain.name = name or "IKChain"
        chain.localPoleOffset = localPoleOffset
        chain.active = false
        chain.destroyed = false
        chain.lastUpdateTime = curtime()
        chain.boneIndices = {}
        chain.physObjects = {} 
        
        chain.config = {}
        for k, v in pairs(DEFAULT_CONFIG) do
            chain.config[k] = v
        end
        if customConfig then
            for k, v in pairs(customConfig) do
                chain.config[k] = v
            end
        end

        for i, boneName in ipairs(boneNames) do
            local physObj = nil
            local boneIdx = nil

            if UniversalBone and UniversalBone.FindBone then
                local pObj, pID = UniversalBone.FindBone(entity, boneName)
                if isvalid(pObj) then
                    physObj = pObj
                    boneIdx = entity:TranslatePhysBoneToBone(pID)
                end
            end

            if not boneIdx or boneIdx == -1 then
                boneIdx = entity:LookupBone(boneName)
            end

            if not boneIdx then 
                print(" Warning: Could not resolve bone: ".. tostring(boneName))
                return nil 
            end
            
            chain.boneIndices[i] = boneIdx
            chain.physObjects[i] = physObj
        end

        chain.pelvisIndex = nil
        local pelvisCandidates = {"ValveBiped.Bip01_Pelvis", "Pelvis", "Hips", "Hip", "Root"}
        for _, name in ipairs(pelvisCandidates) do
            local idx = entity:LookupBone(name)
            if idx then chain.pelvisIndex = idx break end
        end

        chain.positions, chain.boneLengths, chain.startDirections = {}, {}, {}
        chain.completeLength = 0
        for i, idx in ipairs(chain.boneIndices) do
            local pos = entity:GetBonePosition(idx)
            if not pos then return nil end
            chain.positions[i] = pos
        end

        for i = 1, #chain.positions - 1 do
            local dir = chain.positions[i + 1] - chain.positions[i]
            chain.boneLengths[i] = dir:Length()
            chain.startDirections[i] = dir
            chain.completeLength = chain.completeLength + chain.boneLengths[i]
        end

        chain.smoothedPositions, chain.positionVelocities = {}, {}
        for i = 1, #chain.positions do
            chain.smoothedPositions[i] = chain.positions[i] + vec_zero
            chain.positionVelocities[i] = vec_zero
        end

        chain.smoothedAngles, chain.angleVelocities = {}, {}
        for i = 1, #chain.positions - 1 do
            local boneMatrix = entity:GetBoneMatrix(chain.boneIndices[i])
            chain.smoothedAngles[i] = boneMatrix and boneMatrix:GetAngles() or ang_zero
            chain.angleVelocities[i] = ang_zero
        end

        chain.target = (chain.positions[#chain.positions] or vec_zero) + vec_zero
        chain.prevUp = vector(0, 0, 1)
        return chain
    end

    function IKChain:SetTarget(pos)
        if self.destroyed or not pos then return end
        self.target.x, self.target.y, self.target.z = pos.x, pos.y, pos.z
        self.active = true
    end
    
    function IKChain:Update(dt)
        if self.destroyed or not self.active then return end
        local ent = self.entity
        if not isvalid(ent) then 
            self:Destroy()
            return 
        end
        
        if not self.target or not self.positions or not self.positions[1] then return end
        
        dt = dt or (curtime() - self.lastUpdateTime)
        dt = math_clamp(dt, 0, 0.1)
        self.lastUpdateTime = curtime()
        
        local rootPos = ent:GetBonePosition(self.boneIndices[1])
        if rootPos then self.positions[1] = rootPos end

        local midIdx = math.floor(#self.positions / 2) + 1
        local polePos = CalculatePoleTarget(self.positions, self.localPoleOffset, ent, self.boneIndices[midIdx], self.pelvisIndex)

        local solved
        if #self.positions == 3 then
            solved = ResolveIK_Analytic3(self.positions, self.target, self.boneLengths, polePos)
        else
            solved = ResolveIK_FABRIK(self.positions, self.target, self.boneLengths, self.startDirections, self.completeLength, polePos, self.config)
        end

        if solved then
            for i = 1, #solved do
                if solved[i] and self.smoothedPositions[i] then
                    self.smoothedPositions[i], self.positionVelocities[i] = SmoothDampVector(
                        self.smoothedPositions[i], solved[i], self.positionVelocities[i],
                        self.config.positionSmoothTime, dt
                    )
                end
            end
        end

        self:ApplyRotations(dt)
        if self.config.debug then self:DrawDebug(dt) end
    end

    function IKChain:ApplyRotations(dt)
        local ent = self.entity
        if self.destroyed or not isvalid(ent) then return end
        
        for i = 1, #self.smoothedPositions - 1 do
            local phys = self.physObjects[i]
            if not isvalid(phys) or phys:IsAsleep() then continue end
            
            local boneMatrix = ent:GetBoneMatrix(self.boneIndices[i])
            if not boneMatrix then continue end
            
            local currentPos = self.smoothedPositions[i]
            local nextPos = self.smoothedPositions[i + 1]
            
            local toNext = nextPos - currentPos
            if toNext:LengthSqr() < 1e-4 then continue end
            local targetDir = toNext:GetNormalized()

            local upVec = boneMatrix:GetUp()
            local right = targetDir:Cross(upVec)
            
            if right:LengthSqr() < 1e-6 then
                right = targetDir:Cross(vector(0, 1, 0))
                if right:LengthSqr() < 1e-6 then
                    right = vector(1, 0, 0)
                else
                    right:Normalize()
                end
            else
                right:Normalize()
            end
            
            local up = right:Cross(targetDir)
            if up:LengthSqr() < 1e-6 then
                up = vector(0, 0, 1)
            else
                up:Normalize()
            end
            
            local targetAngle = VectorsToAngle(targetDir, right, up)
            
            if self.smoothedAngles[i] and self.angleVelocities[i] then
                local p, vp = SmoothDampAngle(self.smoothedAngles[i].p, targetAngle.p, self.angleVelocities[i].p, self.config.angleSmoothTime, dt)
                local y, vy = SmoothDampAngle(self.smoothedAngles[i].y, targetAngle.y, self.angleVelocities[i].y, self.config.angleSmoothTime, dt)
                local r, vr = SmoothDampAngle(self.smoothedAngles[i].r, targetAngle.r, self.angleVelocities[i].r, self.config.angleSmoothTime, dt)
                
                if IsNaN(p) or IsNaN(y) or IsNaN(r) then continue end

                self.smoothedAngles[i] = angle(p, y, r)
                self.angleVelocities[i] = angle(vp, vy, vr)

                if IsVectorValid(self.smoothedAngles[i]:Forward()) then
                    phys:ComputeShadowControl({
                        angle = self.smoothedAngles[i],
                        secondstoarrive = self.config.arriveTime,
                        maxangular = self.config.maxAngularSpeed,
                        maxangulardamp = self.config.maxAngularSpeed * 0.5,
                        dampfactor = self.config.angularDampening,
                        teleportdistance = 0,
                        deltatime = dt
                    })
                end
            end
        end
    end

    function IKChain:DrawDebug(dt)
        if self.destroyed or not isvalid(self.entity) then return end
        local t = dt * 3
        for i = 1, #self.smoothedPositions - 1 do
            debug_line(self.smoothedPositions[i], self.smoothedPositions[i + 1], t, Color(100, 255, 150), false)
        end
        debug_sphere(self.target, 5, t, Color(255, 50, 50), false)
    end

    function IKChain:Destroy()
        self.destroyed = true
        self.active = false
        self.entity = nil
        self.positions = nil
        self.smoothedPositions = nil
        self.target = nil
        self.physObjects = nil
        self.boneIndices = nil
    end

    function IKSystem.CreateChain(ent, bones, name, localPoleOffset, customConfig)
        if not isvalid(ent) then return end
        local chain = IKChain:new(ent, bones, name, localPoleOffset, customConfig)
        if not chain then return end
        local id = ent:EntIndex()
        activeChains[id] = activeChains[id] or {}
        table_insert(activeChains[id], chain)
        return chain
    end

    function IKSystem.UpdateAll(dt)
        for id, chains in pairs(activeChains) do
            local e = Entity(id)
            if not isvalid(e) then 
                for i = #chains, 1, -1 do
                    if chains[i] then chains[i]:Destroy() end
                end
                activeChains[id] = nil
                continue 
            end

            for i = #chains, 1, -1 do
                local c = chains[i]
                if not c or c.destroyed then 
                    table_remove(chains, i)
                else
                    local ok, err = pcall(c.Update, c, dt)
                    if not ok then ErrorNoHaltWithStack(" ".. tostring(err).. "\n") end
                end
            end
        end
    end
    
    function IKSystem.RemoveEntityChains(ent)
        if not isvalid(ent) then return end
        local id = ent:EntIndex()
        if activeChains[id] then
            for _, c in ipairs(activeChains[id]) do
                if c then c:Destroy() end
            end
            activeChains[id] = nil
        end
    end

    hook.Add("Think", "IKSystem_UnityFABRIK_Update", function()
        local dt = frametime()
        IKSystem.UpdateAll(dt)
    end)

    _G.IKSystem_Unity_FABRIK = IKSystem
end

return _G.IKSystem_Unity_FABRIK