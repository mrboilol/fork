DMS = DMS or {}
DMS.Behaviors = DMS.Behaviors or {}

DMS.ActiveRagdolls = DMS.ActiveRagdolls or {} 
setmetatable(DMS.ActiveRagdolls, { __mode = "v" }) 

local IsValid = IsValid
local pairs   = pairs
local next    = next
local CurTime = CurTime
local FrameTime = FrameTime
local math_min = math.min
local setmetatable = setmetatable

local BehaviorSounds = {
    ["burning"]  = { reaction = "burn",   looped = true },
    ["falling"]  = { reaction = "flying", looped = true },
    ["stumble"]  = { reaction = "bullet", looped = true },
    ["injured"]  = { reaction = "bullet", looped = true },
}

local function IsBeingControlled(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayerHolding() then return true end

    if ent.GetInternalVariable then
        local driver = ent:GetInternalVariable("m_hDrivingEntity")
        if driver then return true end
    end
    
    return false
end

hook.Add("Tick", "DMS_Core_MasterLoop_Secure", function()
    if not next(DMS.ActiveRagdolls) then return end

    local dt = math_min(FrameTime(), 0.1)

    for entID, ragdoll_obj in pairs(DMS.ActiveRagdolls) do
        local rag = ragdoll_obj.ragdoll
        
        if not ragdoll_obj or not IsValid(rag) or rag:GetPhysicsObjectCount() == 0 then
            DMS.ActiveRagdolls[entID] = nil
            if ragdoll_obj and not ragdoll_obj._CleaningUp then
                DMS:Cleanup(ragdoll_obj)
            end
            continue
        end

        if IsBeingControlled(rag) then continue end

        if DMS.Physics and DMS.Physics.HandleTransitions then
            DMS.Physics:HandleTransitions(ragdoll_obj, dt)
        end

        local inst = ragdoll_obj.BehaviorInstance
        if inst and inst.OnUpdate then
            inst:OnUpdate(ragdoll_obj, dt)
        end

        local layers = ragdoll_obj.ActiveLayers
        if layers and next(layers) then
            for layerName, layerInst in pairs(layers) do
                if layerInst and layerInst.OnUpdate then
                    layerInst:OnUpdate(ragdoll_obj, dt)
                end
            end
        end
    end
end)

function DMS:RegisterBehavior(name, data)
    if not name or not data then return end
    self.Behaviors[name] = data
    print("[DMS] Registered Behavior Template: " .. name)
end

function DMS:Setup(ar)
    if not ar or not IsValid(ar.ragdoll) then return end

    ar.CurrentBehavior = "none"
    ar.BehaviorInstance = nil
    ar.ActiveLayers = ar.ActiveLayers or {}
    ar._CleaningUp = false

    local entIndex = ar.ragdoll:EntIndex()
    DMS.ActiveRagdolls[entIndex] = ar

    timer.Simple(0, function()
        if ar and IsValid(ar.ragdoll) and self.Switch then
            self:Switch(ar, "stumble")
        end
    end)
end

function DMS:Switch(ar, name)
    if not ar or not IsValid(ar.ragdoll) then return end
    if ar.CurrentBehavior == name then return end
    
    if name == "none" then
        if ar.BehaviorInstance and ar.BehaviorInstance.OnExit then
            ar.BehaviorInstance:OnExit(ar)
        end
        if SoundManager and SoundManager.Stop then
            SoundManager:Stop(ar.ragdoll, 0.25)
        end
        ar.BehaviorInstance = nil
        ar.CurrentBehavior = "none"
        return
    end
    
    if not name then return end
    local template = self.Behaviors[name]
    if not template then return end

    if ar.BehaviorInstance and ar.BehaviorInstance.OnExit then
        ar.BehaviorInstance:OnExit(ar)
    end

    if SoundManager and IsValid(ar.ragdoll) then
        local sfx = BehaviorSounds[name]
        if sfx then
            if SoundManager.Play then
                SoundManager:Play(ar.ragdoll, sfx.reaction, sfx.looped)
            end
        elseif SoundManager.Stop then
            SoundManager:Stop(ar.ragdoll, 0.25)
        end
    end

    local instance = setmetatable({}, { __index = template })
    
    ar.BehaviorInstance = instance
    ar.CurrentBehavior = name

    if instance.OnStart then
        instance:OnStart(ar)
    end
end

function DMS:AddLayer(ar, name)
    if not ar or not IsValid(ar.ragdoll) or not name then return end
    
    ar.ActiveLayers = ar.ActiveLayers or {}
    if ar.ActiveLayers[name] then return end

    local template = self.Behaviors[name]
    if not template then return end

    local instance = setmetatable({}, { __index = template })
    ar.ActiveLayers[name] = instance

    if instance.OnStart then 
        instance:OnStart(ar)
    end
end

function DMS:RemoveLayer(ar, name)
    if not ar or not ar.ActiveLayers or not name then return end
    
    local instance = ar.ActiveLayers[name]
    if not instance then return end

    if instance.OnExit then 
        instance:OnExit(ar)
    end
    
    ar.ActiveLayers[name] = nil
end

function DMS:Cleanup(ar)
    if not ar or ar._CleaningUp then return end
    ar._CleaningUp = true

    local rag = ar.ragdoll
    
    if IsValid(rag) then
        local entIndex = rag:EntIndex()
        DMS.ActiveRagdolls[entIndex] = nil
        
        if SoundManager and SoundManager.Stop then 
            SoundManager:Stop(rag, 0.3)
        end
    end

    if ar.BehaviorInstance and ar.BehaviorInstance.OnExit then
        ar.BehaviorInstance:OnExit(ar)
    end

    if ar.ActiveLayers then
        for layerName, v in pairs(ar.ActiveLayers) do
            if v and v.OnExit then v:OnExit(ar) end
        end
    end
    
    ar.ActiveLayers = nil
    ar.BehaviorInstance = nil
    ar.CurrentBehavior = "none"
    ar.ragdoll = nil
end

hook.Add("EntityRemoved", "DMS_Global_EntityCleanup", function(ent)
    local idx = ent:EntIndex()
    if idx and idx > 0 and DMS and DMS.ActiveRagdolls and DMS.ActiveRagdolls[idx] then
        DMS:Cleanup(DMS.ActiveRagdolls[idx])
    end

    if DMS_Health and DMS_Health.Active and DMS_Health.Active[ent] then
        DMS_Health.Active[ent] = nil
    end

    if SoundManager and SoundManager.ActiveSounds and SoundManager.ActiveSounds[ent] then
        if SoundManager.Stop then 
            SoundManager:Stop(ent, 0) 
        else
            SoundManager.ActiveSounds[ent] = nil 
        end
    end

    if RagdollFaceAnimator and RagdollFaceAnimator.UnregisterRagdoll then
        RagdollFaceAnimator:UnregisterRagdoll(ent)
    end

    if AnimatedHands and AnimatedHands.RemoveEntity then
        AnimatedHands:RemoveEntity(ent)
    end

    if IKSystem_Unity_FABRIK and IKSystem_Unity_FABRIK.RemoveEntityChains then
        IKSystem_Unity_FABRIK.RemoveEntityChains(ent)
    end
end)

hook.Add("PreCleanupMap", "DMS_Core_MapCleanup", function()
    for entID, ragdoll_obj in pairs(DMS.ActiveRagdolls) do
        if ragdoll_obj and not ragdoll_obj._CleaningUp then
            DMS:Cleanup(ragdoll_obj)
        end
    end
    table.Empty(DMS.ActiveRagdolls)
end)