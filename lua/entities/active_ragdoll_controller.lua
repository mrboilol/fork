if SERVER then AddCSLuaFile() end

local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local Angle = Angle
local math_max = math.max
local math_asin = math.asin
local math_pi = math.pi
local math_clamp = math.Clamp
local math_abs = math.abs
local pairs = pairs
local istable = istable
local pcall = pcall
local timer = timer

local RAD2DEG = 180 / math_pi
local MAX_ANGULAR_VEL = 400 
local MAX_ANGULAR_SQR = MAX_ANGULAR_VEL * MAX_ANGULAR_VEL

local vec_buffer = Vector(0, 0, 0)

local function IsNumberValid(n)
    return n == n and n ~= math.huge and n ~= -math.huge
end

if not SafeRemoveEntity then
    function SafeRemoveEntity(ent)
        if IsValid(ent) then 
            pcall(function() ent:Remove() end)
        end
    end
end

local ENTITY = FindMetaTable("Entity")
if ENTITY and not ENTITY.DeleteOnRemove then
    function ENTITY:DeleteOnRemove(child)
        if not IsValid(self) or not IsValid(child) then return end
        
        pcall(function()
            local timerID = "DMS_Del_" .. tostring(self:EntIndex())
            self:CallOnRemove(timerID, function()
                if IsValid(child) then 
                    pcall(function() child:Remove() end)
                end
            end)
        end)
    end
end

local PHYS = FindMetaTable("PhysObj")
if PHYS and not PHYS.GetID then
    function PHYS:GetID()
        local result = -1
        pcall(function()
            local ent = self:GetEntity()
            if not IsValid(ent) then 
                result = -1
                return
            end
            
            local count = ent:GetPhysicsObjectCount()
            if not count or count <= 0 then 
                result = -1
                return
            end
            
            for i = 0, count - 1 do
                local p = ent:GetPhysicsObjectNum(i)
                if p == self then 
                    result = i
                    return
                end
            end
        end)
        return result
    end
end

local phys_settings = 
{
	["ValveBiped.Bip01_R_UpperArm"] = {mass = 3.529606, inertia = Vector(0.06, 0.28, 0.28)},
	["ValveBiped.Bip01_L_UpperArm"] = {mass = 3.466939, inertia = Vector(0.06, 0.27, 0.27)},
	["ValveBiped.Bip01_L_Forearm"] = {mass = 1.801132, inertia = Vector(0.02, 0.10, 0.10)},
	["ValveBiped.Bip01_R_Forearm"] = {mass = 1.781718, inertia = Vector(0.02, 0.10, 0.10)},
	["ValveBiped.Bip01_R_Thigh"] = {mass = 10.187500, inertia = Vector(0.35, 1.74, 1.76)},
	["ValveBiped.Bip01_R_Calf"] = {mass = 4.996145, inertia = Vector(0.10, 0.63, 0.64)},
	["ValveBiped.Bip01_Head1"] = {mass = 5.163157, inertia = Vector(0.19, 0.21, 0.27)},
}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.AutomaticFrameAdvance = true
ENT.Enabled = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Target")
    self:NetworkVar("Entity", 1, "Parent")
    self:NetworkVar("Bool", 0, "ControllerEnabled")
end

function ENT:SetReactionStrength(v)
    self.reaction_strength = math_max(v or 1, 0.1)
end

function ENT:GetReactionStrength()
    return self.reaction_strength or 1
end

function ENT:SetBoneStrength(tbl)
    self.bone_strength = istable(tbl) and tbl or nil
end

function ENT:SetResponseSpeed(v)
    self.response_speed = math_clamp(v or 1, 0.1, 1.25)
end

local function ProcessBone(self, target, physID, enable)
    if not IsValid(target) then return false end
    
    local phys = nil
    local physSuccess = pcall(function()
        phys = target:GetPhysicsObjectNum(physID)
    end)
    
    if not physSuccess or not IsValid(phys) then return false end

    pcall(function()
        if enable then
            self:AddToMotionController(phys)
            phys:Wake()
        else
            self:RemoveFromMotionController(phys)
        end
    end)

    local boneID = nil
    local boneName = nil
    
    pcall(function()
        boneID = target:TranslatePhysBoneToBone(physID)
        if boneID and boneID ~= -1 then
            boneName = target:GetBoneName(boneID)
        end
    end)

    if not boneName then return false end
    return true, phys, boneName
end

function ENT:SetBoneList(list)
    if CLIENT then return end

    local target = self:GetTarget()
    if not IsValid(target) or target:IsMarkedForDeletion() then return end

    self._physCache = {}
    self._boneNameCache = {}

    local allowed = {}
    if istable(list) then
        for _, name in pairs(list) do
            allowed[name] = true
        end
    end

    local hasAny = false
    
    local count = 0
    pcall(function()
        count = target:GetPhysicsObjectCount()
    end)
    
    if count == 0 then return end

    for i = 0, count - 1 do
        local boneID = nil
        local boneName = nil
        
        pcall(function()
            boneID = target:TranslatePhysBoneToBone(i)
            if boneID and boneID ~= -1 then
                boneName = target:GetBoneName(boneID)
            end
        end)

        local enable = boneName and allowed[boneName]
        local ok, phys = ProcessBone(self, target, i, enable)

        if ok and enable and IsValid(phys) then
            local pid = i 
            self._physCache[pid] = {
                phys = phys,
                name = boneName
            }

            local selfBone = nil
            pcall(function()
                selfBone = self:LookupBone(boneName)
            end)
            
            if selfBone then
                self._boneNameCache[boneName] = selfBone
            end

            hasAny = true
        end
    end

    self.Enabled = hasAny
    self:SetControllerEnabled(hasAny)
end

function ENT:Initialize()
    if CLIENT then return end

    self._physCache = {}
    self._boneNameCache = {}

    local target = self:GetTarget()
    if not IsValid(target) then
        timer.Simple(0, function() 
            if IsValid(self) then 
                pcall(function() self:Remove() end)
            end 
        end)
        return
    end

    pcall(function()
        self:StartMotionController()
    end)
    
    pcall(function()
        target:DeleteOnRemove(self)
    end)

    		for bone_name, info in pairs(phys_settings) do
		 	local bone = target:LookupBone(bone_name)
		 	if bone then
		 		local phys_bone = target:TranslateBoneToPhysBone(bone)
		 		local phys = target:GetPhysicsObjectNum(phys_bone)
		 		if IsValid(phys) then
			 		phys:SetInertia(info.inertia)
			 		phys:SetMass(info.mass)
			 	end
			end
		end

end

function ENT:Think()
    if SERVER then
        local target = self:GetTarget()
        local parent = self:GetParent()

        if IsValid(target) and not target:IsMarkedForDeletion() and IsValid(parent) then
            pcall(function()
                local bone = target:TranslatePhysBoneToBone(0)
                if bone and bone ~= -1 then
                    local pos, ang = target:GetBonePosition(bone)
                    if ang then 
                        parent:SetAngles(ang) 
                    end
                end
            end)
        end
    end

    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
    if CLIENT then return end

    if self._physCache then
        for _, data in pairs(self._physCache) do
            if IsValid(data.phys) then
                pcall(function()
                    self:RemoveFromMotionController(data.phys)
                end)
            end
        end
    end

    self._physCache = nil
    self._boneNameCache = nil
end

function ENT:UpdateTransmitState()
    return TRANSMIT_NEVER
end

function ENT:VectorsFromAngles(physAng, animAng)
    local success = pcall(function()
        local phyF = physAng:Forward()
        local phyR = physAng:Right()
        local animR = animAng:Right()
        local animU = animAng:Up()

        local yVal = math_clamp(phyF:Dot(animR), -0.998, 0.998)
        local pVal = math_clamp(phyF:Dot(animU), -0.998, 0.998)
        local rVal = math_clamp(phyR:Dot(animU), -0.998, 0.998)

        vec_buffer.x = math_asin(rVal) * RAD2DEG
        vec_buffer.y = math_asin(pVal) * RAD2DEG
        vec_buffer.z = math_asin(yVal) * RAD2DEG
    end)
    
    if not success then
        vec_buffer.x = 0
        vec_buffer.y = 0
        vec_buffer.z = 0
    end
    
    return vec_buffer
end

function ENT:PhysicsSimulate(phys, dt)
    if CLIENT or not self.Enabled or not self:GetControllerEnabled() then return SIM_NOTHING end

    if not IsValid(phys) then return SIM_NOTHING end
    if not IsValid(self) or self:IsMarkedForDeletion() then return SIM_NOTHING end
    
    local isMoveable = false
    pcall(function()
        isMoveable = phys:IsMoveable()
    end)
    if not isMoveable then return SIM_NOTHING end

    local target = self:GetTarget()
    if not IsValid(target) or target:IsMarkedForDeletion() then return SIM_NOTHING end

    if not self._physCache then return SIM_NOTHING end

    local pid = -1
    pcall(function()
        pid = phys:GetID()
    end)
    
    if pid == -1 then return SIM_NOTHING end
    
    local data = self._physCache[pid]
    if not data or not IsValid(data.phys) then
        pcall(function()
            self:RemoveFromMotionController(phys)
        end)
        return SIM_NOTHING
    end

    local boneID = self._boneNameCache[data.name]
    if not boneID then return SIM_NOTHING end
    
    local animAng = nil
    pcall(function()
        local _, ang = self:GetBonePosition(boneID)
        animAng = ang
    end)
    
    if not animAng then return SIM_NOTHING end

    local physAng = nil
    pcall(function()
        physAng = phys:GetAngles()
    end)
    
    if not physAng then return SIM_NOTHING end

    local angVel = self:VectorsFromAngles(physAng, animAng)

    if not IsNumberValid(angVel.x) or not IsNumberValid(angVel.y) or not IsNumberValid(angVel.z) then
        return SIM_NOTHING
    end

    local response = self.response_speed or 1
    local boneMul = self.bone_strength and self.bone_strength[data.name] or 1
    local strength = (self.reaction_strength or 1) * response * boneMul
    angVel:Mul(strength)
    
    local currentVel = Vector(0, 0, 0)
    pcall(function()
        currentVel = phys:GetAngleVelocity()
    end)
    
    currentVel:Mul(0.15)
    angVel:Sub(currentVel)

    local magSqr = angVel:LengthSqr()
    if magSqr > MAX_ANGULAR_SQR then
        angVel:Normalize()
        angVel:Mul(MAX_ANGULAR_VEL)
    end

    local dt_mult = math_clamp(dt * 66, 0.01, 2.0) 
    angVel:Mul(dt_mult)

    if IsNumberValid(angVel.x) and IsNumberValid(angVel.y) and IsNumberValid(angVel.z) then
        pcall(function()
            phys:AddAngleVelocity(angVel)
        end)
    end
    
    return SIM_NOTHING
end