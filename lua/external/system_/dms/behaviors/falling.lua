local IKSystem = include("system_/utils/IKChain.lua")

local B = {}

local DEBUG_GIZMOS = false

local BRACE_CONFIG = {
    LookAheadTime = 0.65, 
    BraceSpeed = 0.08,
    MinVelocity = 50,
}

local IK_SETTINGS = {
    arriveTime = 0.01,
    positionSmoothTime = 0.1,
    maxAngularSpeed = 55000, 
    debug = false 
} 

local IsValid = IsValid
local Vector = Vector
local FrameTime = FrameTime
local debugoverlay = debugoverlay

local FallAnims = {"Falling", "Falling2"}

local function GetRandomFallAnim()
    return FallAnims[math.random(#FallAnims)]
end

function B:OnStart(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    ar.CurrentAnim = GetRandomFallAnim()


    ar:PlayAnimation(ar.CurrentAnim, 1.25, "models/AREAnims/model_anim.mdl")
    ar:SetStrength(5)

    self.LeftChain = IKSystem.CreateChain(ragdoll, {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand"}, "LeftBrace", Vector(0, 0, -50), IK_SETTINGS)
    self.RightChain = IKSystem.CreateChain(ragdoll, {"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand"}, "RightBrace", Vector(0, 0, -50), IK_SETTINGS)

    self.IsBracing = false
end

function B:OnUpdate(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    local phys = ragdoll:GetPhysicsObject()
    if not IsValid(phys) then return end

    local velocity = phys:GetVelocity()
    local speed = velocity:Length()

    if speed <= BRACE_CONFIG.MinVelocity then 
        self:ResetBracing()
        return 
    end

    local predictedOffset = velocity * BRACE_CONFIG.LookAheadTime
    local spineBone = ar.cachedSpineIdx or ragdoll:LookupBone("ValveBiped.Bip01_Spine2") or 0
    local startPos = ragdoll:GetBonePosition(spineBone)
    local endPos = startPos + predictedOffset

    local tr = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = ragdoll,
        mask = MASK_SOLID
    })

    if tr.Hit then
        self.IsBracing = true

        local hitPos = tr.HitPos
        local hitNormal = tr.HitNormal
        local braceDir = velocity:GetNormalized()
        
        local rightOffset = braceDir:Cross(Vector(0,0,1)):GetNormalized() * 12
        local wallOffset = hitNormal * 5 

        local leftTarget = hitPos - rightOffset + wallOffset
        local rightTarget = hitPos + rightOffset + wallOffset

        local spinePhysId = ragdoll:TranslateBoneToPhysBone(spineBone)
        local spinePhys = ragdoll:GetPhysicsObjectNum(spinePhysId)

        if IsValid(spinePhys) then
            local lookDir = (hitPos - spinePhys:GetPos()):GetNormalized()
            local targetAng = lookDir:Angle()

            local params = {
                secondstoarrive = 0.2,
                pos = spinePhys:GetPos(),
                angle = targetAng,
                maxangular = IK_SETTINGS.maxAngularSpeed,
                maxangulardamp = 10000,
                dampfactor = 0.8,
                teleportdistance = 0,
                deltatime = FrameTime()
            }
            spinePhys:ComputeShadowControl(params)
        end

        if self.LeftChain and self.LeftChain.SetTarget then self.LeftChain:SetTarget(leftTarget) end
        if self.RightChain and self.RightChain.SetTarget then self.RightChain:SetTarget(rightTarget) end

        if DEBUG_GIZMOS then
            debugoverlay.Line(startPos, hitPos, 0.1, Color(255, 0, 0), true)
            debugoverlay.Cross(hitPos, 5, 0.1, Color(255, 255, 0), true)
        end
    else
        self:ResetBracing()
        
        if DEBUG_GIZMOS then
            debugoverlay.Line(startPos, endPos, 0.1, Color(0, 255, 0, 50), true)
        end
    end
end

function B:ResetBracing()
    self.IsBracing = false
    if self.LeftChain and self.LeftChain.Reset then self.LeftChain:Reset() end
    if self.RightChain and self.RightChain.Reset then self.RightChain:Reset() end
end

function B:OnExit(ar)
    ar:SetStrength(2.5)

    if self.LeftChain and self.LeftChain.Destroy then self.LeftChain:Destroy() end
    if self.RightChain and self.RightChain.Destroy then self.RightChain:Destroy() end
    
    self.LeftChain = nil
    self.RightChain = nil
end

DMS:RegisterBehavior("falling", B)