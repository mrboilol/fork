local B = {}

local PCOLLIDE_CACHE = {}
local vec_max = Vector(2, 2, 2)
local vec_min = -vec_max

local double_grab_chance = 0.4
local hand_offset = Vector(2, 0, 0)
local force_limit = 2000 

local function IsValidNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function GetClosestPhysBone(self, pos, target_phys_bone, use_collides)
    local mdl = self:GetModel()
    if not mdl then return nil end

    local collides = PCOLLIDE_CACHE[mdl]
    if (!collides and use_collides) then
        local success, res = pcall(CreatePhysCollidesFromModel, mdl)
        if success and res then
            PCOLLIDE_CACHE[mdl] = res
            collides = PCOLLIDE_CACHE[mdl]
        else
            use_collides = false
        end
    end

    local closest_bone = nil
    local dist = math.huge

    if (use_collides and collides) then
        for phys_bone = 0, self:GetPhysicsObjectCount() - 1 do      
            local phys = self:GetPhysicsObjectNum(phys_bone)
            if IsValid(phys) then
                local collide = collides[phys_bone + 1] 
                if IsValid(collide) then            
                    local phys_pos = phys:GetPos()
                    local phys_ang = phys:GetAngles()
                    if IsValidNumber(pos.x) then
                        local hitpos, _, d = collide:TraceBox(phys_pos, phys_ang, pos, pos, vec_min, vec_max)
                        if hitpos then                                  
                            if (d < dist) then
                                dist = d
                                closest_bone = phys_bone    
                            end
                        end
                    end
                end
            end
        end
    end

    if closest_bone == nil then
        dist = math.huge
        for i = 0, self:GetPhysicsObjectCount() - 1 do
            local phys = self:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                local mins, maxs = phys:GetAABB()
                if mins and maxs then
                    local centerPos = phys:LocalToWorld((mins + maxs) / 2)
                    local d = centerPos:DistToSqr(pos)
                    if d < dist then
                        dist = d
                        closest_bone = i
                    end
                end
            end
        end
    end

    return closest_bone
end

function B:OnStart(ar)
    local ragdoll = ar.ragdoll
    local dmgpos = ar.dmgpos

    if not IsValid(ragdoll) then return end
    if not dmgpos then return end

    local woundBoneID = GetClosestPhysBone(ragdoll, dmgpos, nil, true)
    if not woundBoneID then return end

    local woundPhys = ragdoll:GetPhysicsObjectNum(woundBoneID)
    if not IsValid(woundPhys) then return end

    local visualBone = ragdoll:TranslatePhysBoneToBone(woundBoneID)
    local woundBoneName = string.lower(ragdoll:GetBoneName(visualBone) or "")

    local boneCenter = woundPhys:LocalToWorld(woundPhys:GetMassCenter())
    
    local tr = util.TraceLine({
        start = dmgpos,
        endpos = boneCenter,
        filter = {},
        mask = MASK_SHOT
    })

    local finalGrabPos = dmgpos

    if tr.Hit and tr.Entity == ragdoll then
        finalGrabPos = tr.HitPos
    else
        finalGrabPos = boneCenter
    end
    
    if not UniversalBone then return end
    
    local rPhys, rID = UniversalBone.FindBone(ragdoll, "ValveBiped.Bip01_R_Hand")
    local lPhys, lID = UniversalBone.FindBone(ragdoll, "ValveBiped.Bip01_L_Hand")

    local candidates = {}
    local isRightSideWound = string.find(woundBoneName, "_r_")
    if IsValid(rPhys) and rID and rID ~= -1 and rID ~= woundBoneID and not isRightSideWound then
        table.insert(candidates, { id = rID, phys = rPhys, name = "Right" })
    end

    local isLeftSideWound = string.find(woundBoneName, "_l_")
    if IsValid(lPhys) and lID and lID ~= -1 and lID ~= woundBoneID and not isLeftSideWound then
        table.insert(candidates, { id = lID, phys = lPhys, name = "Left" })
    end

    local handsToUse = {}

    if #candidates == 0 then
        return
    elseif #candidates == 1 then
        handsToUse = candidates
    else
        if math.random() < double_grab_chance then
            handsToUse = candidates
        else
            local c1 = candidates[1]
            local c2 = candidates[2]
            local d1 = c1.phys:GetPos():DistToSqr(finalGrabPos)
            local d2 = c2.phys:GetPos():DistToSqr(finalGrabPos)

            if d1 < d2 then
                handsToUse = {c1}
            else
                handsToUse = {c2}
            end
        end
    end

    local LocalWoundPos = woundPhys:WorldToLocal(finalGrabPos)

    self.HandData = {} 
    self.GrabStatus = { Right = false, Left = false } 

    for _, hand in ipairs(handsToUse) do
        local hID = hand.id
        local hName = hand.name
            
        if not IsValid(ragdoll:GetPhysicsObjectNum(woundBoneID)) or not IsValid(ragdoll:GetPhysicsObjectNum(hID)) then
            continue
        end

        local elastic = constraint.Elastic(
            ragdoll, 
            ragdoll, 
            woundBoneID, 
            hID, 
            LocalWoundPos, 
            hand_offset, 
            force_limit, 
            0, 
            0, 
            "cable/cable2", 
            0, 
            false
        )

        if IsValid(elastic) then
            elastic:Fire("SetSpringLength", 0, 0)
        end

        self.HandData[hName] = {
            Elastic = elastic,
            Weld = nil
        }
        self.GrabStatus[hName] = true 

        local timerName = "WoundGrab_" .. ragdoll:EntIndex() .. "_" .. hName
        self.HandData[hName].TimerName = timerName

        timer.Create(timerName, 0.4, 1, function()
            if not IsValid(ragdoll) or not self.HandData or not self.HandData[hName] then return end

            local p1 = ragdoll:GetPhysicsObjectNum(woundBoneID)
            local p2 = ragdoll:GetPhysicsObjectNum(hID)
            if IsValid(p1) then p1:Wake() end
            if IsValid(p2) then p2:Wake() end

            local weld = constraint.Weld(ragdoll, ragdoll, woundBoneID, hID, 0, false)
            
            if IsValid(weld) and self.HandData[hName] then
                self.HandData[hName].Weld = weld
                if IsValid(self.HandData[hName].Elastic) then 
                    self.HandData[hName].Elastic:Remove() 
                end
            end
        end)
    end
end

function B:OnExit(ar)
    if self.HandData then
        for name, data in pairs(self.HandData) do
            if data.TimerName and timer.Exists(data.TimerName) then timer.Remove(data.TimerName) end
            if IsValid(data.Elastic) then data.Elastic:Remove() end
            if IsValid(data.Weld) then data.Weld:Remove() end
        end
    end
    self.HandData = nil
    self.GrabStatus = nil
end

DMS:RegisterBehavior("woundgrab", B)