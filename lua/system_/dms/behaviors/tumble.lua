local B = {}

function B:OnStart(ar)
    local list = {  
        "ValveBiped.Bip01_Spine2",
        "ValveBiped.Bip01_R_Forearm",
        "ValveBiped.Bip01_L_Forearm",
        "ValveBiped.Bip01_R_Upperarm",
        "ValveBiped.Bip01_L_Upperarm",
        "ValveBiped.Bip01_R_Thigh",
        "ValveBiped.Bip01_Head1",
        "ValveBiped.Bip01_L_Thigh",             
    }

    ar:ApplyBoneList(list)
    ar:PlayAnimation("Cower", 1.2, "models/AREAnims/model_anim.mdl")

    local ragdoll = ar.ragdoll
    if IsValid(ragdoll) then
        local phys, physID = UniversalBone.FindBone(ragdoll, "ValveBiped.Bip01_Spine2")
        
        if IsValid(phys) then
            local forward = ragdoll:GetForward()
            local currentVel = phys:GetVelocity()
            local pushDir = (currentVel:LengthSqr() > 100) and currentVel:GetNormalized() or forward

            local force = (pushDir * 200) + Vector(0, 0, 150)
            phys:ApplyForceCenter(force * phys:GetMass())

            local rollAxis = pushDir:Cross(Vector(0, 0, 1)):GetNormalized()
            local initialTorque = rollAxis * 2500
            phys:ApplyTorqueCenter(initialTorque)
        end
    end
end

function B:OnUpdate(ar)
    local ragdoll = ar.ragdoll
    if not IsValid(ragdoll) then return end

    local phys, physID = UniversalBone.FindBone(ragdoll, "ValveBiped.Bip01_Spine2")
    if not IsValid(phys) then return end

    local vel = phys:GetVelocity()
    local speed = vel:Length()

    local minSpeed = GetConVar("ar_tumble_minspeed"):GetFloat()
    if speed <= minSpeed then return end

    local dt = FrameTime()
    local time = CurTime()

    local trace = util.TraceLine({
        start = phys:GetPos(),
        endpos = phys:GetPos() - Vector(0,0,100),
        filter = {ragdoll, ar.Entity}
    })
    
    local groundNormal = vector_up
    if trace.Hit then
        groundNormal = trace.HitNormal
    end

    local rollAxis = vel:GetNormalized():Cross(groundNormal)
    
    local gravity = physenv.GetGravity():GetNormalized()
    local downhill = (gravity - (gravity:Dot(groundNormal) * groundNormal)):GetNormalized()
    
    if downhill:LengthSqr() > 0.1 then
        rollAxis = (rollAxis + downhill:Cross(groundNormal) * 0.5):GetNormalized()
    end

    local boneID = ragdoll:TranslatePhysBoneToBone(physID)
    local matrix = ragdoll:GetBoneMatrix(boneID)
    local stuckMultiplier = 3.0
    
    if matrix then
        local myUp = matrix:GetUp()
        local alignment = math.abs(myUp:Dot(groundNormal))
        
        stuckMultiplier = 3.0 + (alignment * 3.5)
    end

    local speedFactor = math.Clamp(speed / 600, 0, 1)
    
    local angVel = phys:GetAngleVelocity()
    local angDamp = Vector(
        angVel.x * -0.05,
        angVel.y * -0.05,
        angVel.z * -0.1
    )

    local chaos = GetConVar("ar_tumble_chaos"):GetFloat()
    
    local sideAxis = rollAxis:Cross(groundNormal):GetNormalized()
    local sideWave = math.sin(time * 4)
    local sideTorque = sideAxis * sideWave * (20000 * chaos) * speedFactor

    local yawWave = math.sin(time * 1.5)
    local yawTorque = groundNormal * yawWave * (15000 * chaos) * speedFactor

    local baseTorque = GetConVar("ar_tumble_torque"):GetFloat()
    local torqueVal = (baseTorque + speedFactor * (baseTorque * 0.8)) * stuckMultiplier

    local torque =
        rollAxis * torqueVal +
        sideTorque +
        yawTorque +
        angDamp

    phys:ApplyTorqueCenter(-torque * dt)

    if stuckMultiplier > 1.5 then
        local liftPower = GetConVar("ar_tumble_lift"):GetFloat()
        
        local lift = groundNormal * (speed * liftPower)
        lift = Vector(0, 0, math.Clamp(lift.z, 0, 500))
        phys:ApplyForceCenter(lift)
    end
end

function B:OnExit(ar)
    ar:SetStrength(ActiveRagdollManager.Config.DefaultStrength)
    ar:ApplyBoneList(ActiveRagdollManager.Config.BoneList)
end

DMS:RegisterBehavior("tumble", B)