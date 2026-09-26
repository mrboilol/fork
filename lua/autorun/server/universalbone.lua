UniversalBone = UniversalBone or {}

local IsValid = IsValid
local isstring = isstring
local pcall = pcall

local function GetPhysBoneData(target, physID)
    if not IsValid(target) then return nil end
    
    local phys = nil
    local boneID = nil
    local boneName = nil
    
    local physSuccess = pcall(function()
        phys = target:GetPhysicsObjectNum(physID)
    end)
    
    if not physSuccess or not IsValid(phys) then return nil end

    pcall(function()
        boneID = target:TranslatePhysBoneToBone(physID)
    end)
    
    if not boneID or boneID == -1 then return nil end
    
    pcall(function()
        boneName = target:GetBoneName(boneID)
    end)
    
    if not boneName or boneName == "__invalid" then return nil end
    
    return phys, boneName, boneID, physID
end

function UniversalBone.FindBone(target, boneInput)
    if not IsValid(target) or not isstring(boneInput) then return nil end
    if target:IsMarkedForDeletion() then return nil end

    local count = 0
    pcall(function()
        count = target:GetPhysicsObjectCount()
    end)
    
    if count == 0 then return nil, nil end

    for i = 0, count - 1 do
        local phys, name, bID, pID = GetPhysBoneData(target, i)
        if name == boneInput then
            return phys, pID
        end
    end
    
    return nil, nil
end

function UniversalBone.BuildCache(target)
    if not IsValid(target) then return {} end
    if target:IsMarkedForDeletion() then return {} end
    
    local cache = {}
    
    local count = 0
    pcall(function()
        count = target:GetPhysicsObjectCount()
    end)
    
    if count == 0 then return cache end
    
    for i = 0, count - 1 do
        local phys, name = GetPhysBoneData(target, i)
        if phys and name then
            cache[name] = phys
        end
    end
    
    return cache
end