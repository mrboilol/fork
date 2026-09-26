ActiveRagdoll = ActiveRagdoll or {}
ActiveRagdoll.__index = ActiveRagdoll

ActiveRagdoll._Instances = ActiveRagdoll._Instances or {}
setmetatable(ActiveRagdoll._Instances, { __mode = "k" })

local IsValid = IsValid
local ents_Create = ents.Create
local timer = timer

function ActiveRagdoll.new(ragdoll, animModel, dmgpos)
    if not IsValid(ragdoll) or ragdoll:IsMarkedForDeletion() then return nil end

    local existing = ActiveRagdoll.Get(ragdoll)
    if existing and existing.Destroy then
        existing:Destroy()
    end

    local self = setmetatable({}, ActiveRagdoll)
    
    self.ragdoll = ragdoll
    self.dmgpos = dmgpos
    self.animModel = animModel or "models/AREAnims/model_anim.mdl"
    self.currentBoneList = nil
    self.IsDestroying = false

    local parent = ents_Create("prop_dynamic")
    if IsValid(parent) then
        parent:SetModel("models/hunter/plates/plate.mdl")
        parent:SetPos(ragdoll:GetPos())
        parent:SetNoDraw(true)
        parent:SetNotSolid(true)
        parent:SetMoveType(MOVETYPE_NONE)
        parent:Spawn()
        self.parent = parent
    else
        ErrorNoHalt("[ActiveRagdoll] Failed to create parent entity\n")
        return nil
    end

    local controller = ents_Create("active_ragdoll_controller")
    if IsValid(controller) then
        controller:SetModel(self.animModel)
        controller:SetTarget(ragdoll)
        controller:SetParent(self.parent)
        controller:Spawn()
        controller:Activate()
        controller:SetAngles(Angle(-90, -90, 0))
        self.controller = controller
    else
        ErrorNoHalt("[ActiveRagdoll] Failed to create controller entity\n")
        if IsValid(self.parent) then self.parent:Remove() end
        return nil
    end

    local id = ragdoll:EntIndex()
    if id > 0 then
        ragdoll:CallOnRemove("AR_Cleanup_" .. id, function()
            timer.Simple(0, function()
                local inst = ActiveRagdoll.Get(ragdoll)
                if inst and not inst.IsDestroying then 
                    inst:Destroy()
                end
            end)
        end)
    end

    if DMS_Health and DMS_Health.new then
        self.health = DMS_Health.new(ragdoll, 200)
    end

    ActiveRagdoll._Instances[ragdoll] = self
    return self
end

function ActiveRagdoll:SetModel(modelPath)
    if not IsValid(self.controller) or not modelPath or self.animModel == modelPath then return end 

    self.animModel = modelPath
    self.controller:SetModel(modelPath)

    if self.currentBoneList then
        self.controller:SetBoneList(self.currentBoneList)
    elseif self.controller.Initialize then
        self.controller:Initialize() 
    end
end

function ActiveRagdoll:PlayAnimation(name, rate, model)
    if not IsValid(self.controller) then return end
    
    if model and model ~= self.animModel then
        self:SetModel(model)
    end

    local seq = self.controller:LookupSequence(name)
    if seq and seq ~= -1 then
        self.controller:ResetSequence(seq)
        self.controller:SetPlaybackRate(rate or 1)
        self.controller:SetCycle(0)
    end
end

function ActiveRagdoll:ApplyBoneList(list)
    if not IsValid(self.controller) or not list then return end
    self.currentBoneList = list 
    self.controller:SetBoneList(list)
end

function ActiveRagdoll:SetStrength(val)
    if not IsValid(self.controller) then return end
    self.controller:SetReactionStrength(val)
end

function ActiveRagdoll.Get(ragdoll)
    if not IsValid(ragdoll) then return nil end
    return ActiveRagdoll._Instances[ragdoll]
end

function ActiveRagdoll:Destroy()
    if self.IsDestroying then return end
    self.IsDestroying = true

    if DMS and DMS.Cleanup then DMS:Cleanup(self) end

    if _G.IKSystem_Unity_FABRIK and IsValid(self.ragdoll) then
        _G.IKSystem_Unity_FABRIK.RemoveEntityChains(self.ragdoll)
    end

    if IsValid(self.controller) then self.controller:Remove() end
    if IsValid(self.parent) then self.parent:Remove() end

    if IsValid(self.ragdoll) then
        ActiveRagdoll._Instances[self.ragdoll] = nil
    end
    
    self.controller = nil
    self.parent = nil
    self.ragdoll = nil
end