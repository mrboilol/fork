if CLIENT then return end

local VEHICLE_TYPES = {
    [0] = "undefined",
    [1] = "car",
    [2] = "bike",
    [3] = "heli",
    [4] = "plane",
    [5] = "tank",
    [6] = "boat"
}

local cv_sounds       = CreateConVar("glide_water_sounds", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED})
local cv_particles    = CreateConVar("glide_water_particles", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED})
local cv_debug_notify = CreateConVar("glide_water_debug_notify", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED})
local cv_debug_logs   = CreateConVar("glide_water_debug_logs", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED})

local typeConVars = {}
for id, suffix in pairs(VEHICLE_TYPES) do
    typeConVars[id] = {
        enable = CreateConVar("glide_water_enable_" .. suffix, (id == 6) and "0" or "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}),
        fill   = CreateConVar("glide_water_fill_" .. suffix, (id == 5 and "0.1" or id == 6 and "0.01" or id == 2 and "0.1" or "0.04"), {FCVAR_ARCHIVE, FCVAR_REPLICATED}),
        drain  = CreateConVar("glide_water_drain_" .. suffix, "0.04", {FCVAR_ARCHIVE, FCVAR_REPLICATED}),
        delay  = CreateConVar("glide_water_delay_" .. suffix, (id == 5 and "0" or id == 6 and "10.0" or id == 2 and "0" or "4.0"), {FCVAR_ARCHIVE, FCVAR_REPLICATED}),
        offset = CreateConVar("glide_water_offset_" .. suffix, (id == 5 and "-15" or id == 6 and "10" or "0"), {FCVAR_ARCHIVE, FCVAR_REPLICATED}),
        damp   = CreateConVar("glide_water_damp_" .. suffix, (id == 5 and "25" or id == 2 and "12" or "16"), {FCVAR_ARCHIVE, FCVAR_REPLICATED}),
        bias   = CreateConVar("glide_water_bias_" .. suffix, (id == 1 and "0.6" or id == 3 and "0.7" or "0.2"), {FCVAR_ARCHIVE, FCVAR_REPLICATED}),
        air    = CreateConVar("glide_water_air_" .. suffix, (id == 1 and "0.6" or id == 3 and "0.5" or "0.3"), {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    }
end

local PHYSICS_CONFIG = {
    floatStiffness   = 18,     
    maxSpinSpeed     = 45,     
    lateralDamping   = 5.0,    
    angularDamping   = 6.0,    
    waterFriction    = 4.5,    
    sinkSound        = "glidewater/sink_loop.wav",   
    drainSound       = "glidewater/drain_loop.wav", 
    sinkVolume       = 1.0,    
    drainVolume      = 1.0,    
}

local vehicleState = {}

cvars.AddChangeCallback("glide_water_debug_notify", function(name, oldVal, newVal)
    if cv_debug_notify:GetBool() then
        PrintMessage(HUD_PRINTTALK, "[Glide Water Settings] Admin alerts activated.")
    end
end, "GlideWaterPhysics_NotifyMain")

hook.Add("Think", "GlideWaterPhysics_ThinkLoop", function()
    local dt = FrameTime()
    if dt <= 0 then return end 

    local serverGravity = math.abs(physenv.GetGravity().z)
    if serverGravity == 0 then serverGravity = 600 end

    local cfg_use_sounds    = cv_sounds:GetBool()
    local cfg_use_particles = cv_particles:GetBool()
    local cfg_log_status    = cv_debug_logs:GetBool()

    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        if not ent.IsGlideVehicle then continue end

        local vType = ent.VehicleType or 0
        local cvarsBlock = typeConVars[vType]
        if not cvarsBlock then continue end

        if not cvarsBlock.enable:GetBool() then 
            local id = ent:EntIndex()
            if vehicleState[id] then
                if vehicleState[id].sinkSoundObj then vehicleState[id].sinkSoundObj:Stop() end
                if vehicleState[id].drainSoundObj then vehicleState[id].drainSoundObj:Stop() end
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:EnableGravity(true)
                    phys:SetDamping(0, 0)
                end
                vehicleState[id] = nil
            end
            continue 
        end

        local phys = ent:GetPhysicsObject()
        if not IsValid(phys) then continue end

        local id       = ent:EntIndex()
        local inWater  = ent:WaterLevel() > 0
        local state    = vehicleState[id]

        if inWater and not state then
            vehicleState[id] = {
                waterFill       = 0,
                timeInWater     = 0,
                outOfWaterTime  = 0,
                printTimer      = 0,
                sinkSoundObj    = CreateSound(ent, PHYSICS_CONFIG.sinkSound),
                drainSoundObj   = CreateSound(ent, PHYSICS_CONFIG.drainSound),
                sinkPlaying     = false,
                drainPlaying    = false,
                sinkLoopTime    = 0,
                drainLoopTime   = 0
            }
            state = vehicleState[id]
            if cfg_log_status then
                print("[WATER] " .. ent:GetClass() .. " entered water")
            end
        end

        if not state then continue end

        local mass      = phys:GetMass()
        local vel       = phys:GetVelocity()
        local angVel    = phys:GetAngleVelocity()
        local hasDriver = IsValid(ent:GetDriver())

        local cfg_fill_rate    = cvarsBlock.fill:GetFloat()
        local cfg_drain_rate   = cvarsBlock.drain:GetFloat()
        local cfg_sink_delay   = cvarsBlock.delay:GetFloat()
        local cfg_float_offset = cvarsBlock.offset:GetFloat()
        local cfg_damp_scale   = cvarsBlock.damp:GetFloat()
        local cfg_sink_bias    = cvarsBlock.bias:GetFloat()
        local cfg_air_pocket   = cvarsBlock.air:GetFloat()

        local prevFill = state.waterFill
        if inWater then
            state.outOfWaterTime = 0 
            state.timeInWater = state.timeInWater + dt
            if state.timeInWater > cfg_sink_delay then
                state.waterFill = math.Clamp(state.waterFill + cfg_fill_rate * dt, 0, 1)
            end
        else
            state.outOfWaterTime = state.outOfWaterTime + dt
            if state.outOfWaterTime > 1.5 then
                state.timeInWater = 0
                state.waterFill = math.Clamp(state.waterFill - cfg_drain_rate * dt, 0, 1)
            end
        end

        if not inWater and prevFill > 0 and state.waterFill <= 0 then
            if state.sinkSoundObj then state.sinkSoundObj:Stop() end
            if state.drainSoundObj then state.drainSoundObj:Stop() end
            vehicleState[id] = nil
            phys:EnableGravity(true)
            phys:SetDamping(0, 0)
            continue
        end

        local fill = state.waterFill
        local audioInWater = inWater or (state.outOfWaterTime < 0.5)
        local shouldPlaySink = cfg_use_sounds and audioInWater and state.timeInWater > cfg_sink_delay and fill < 1
        local shouldPlayDrain = cfg_use_sounds and not audioInWater and fill > 0

        if shouldPlaySink then
            if not state.sinkPlaying and state.sinkSoundObj then
                state.sinkSoundObj:PlayEx(PHYSICS_CONFIG.sinkVolume, 100)
                state.sinkPlaying = true
                state.sinkLoopTime = CurTime() + 9.8 
            elseif state.sinkPlaying and CurTime() >= state.sinkLoopTime then
                state.sinkSoundObj:Stop()
                state.sinkSoundObj:PlayEx(PHYSICS_CONFIG.sinkVolume, 100)
                state.sinkLoopTime = CurTime() + 9.8
            end
        else
            if state.sinkPlaying and state.sinkSoundObj then
                state.sinkSoundObj:Stop()
                state.sinkPlaying = false
            end
        end

        if shouldPlayDrain then
            if not state.drainPlaying and state.drainSoundObj then
                state.drainSoundObj:PlayEx(PHYSICS_CONFIG.drainVolume, 100)
                state.drainPlaying = true
                state.drainLoopTime = CurTime() + 9.8
            elseif state.drainPlaying and CurTime() >= state.drainLoopTime then
                state.drainSoundObj:Stop()
                state.drainSoundObj:PlayEx(PHYSICS_CONFIG.drainVolume, 100)
                state.drainLoopTime = CurTime() + 9.8
            end
        else
            if state.drainPlaying and state.drainSoundObj then
                state.drainSoundObj:Stop()
                state.drainPlaying = false
            end
        end

        if cfg_log_status then
            state.printTimer = state.printTimer + dt
            if state.printTimer >= 0.5 then
                state.printTimer = 0
                print(string.format("[WATER] %s fill: %.1f%%", ent:GetClass(), fill * 100))
            end
        end

        phys:EnableGravity(true)

        local currentSpin = angVel:Length()
        if currentSpin > PHYSICS_CONFIG.maxSpinSpeed then
            phys:SetAngleVelocity(angVel * (PHYSICS_CONFIG.maxSpinSpeed / currentSpin))
        end

        if inWater then
            if fill > 0.15 then
                if isfunction(ent.SetEngineActive) then ent:SetEngineActive(false) end
                if isfunction(ent.StopEngine) then ent:StopEngine() end
                if ent.SetEngineIgnited then ent:SetEngineIgnited(false) end
            end

            local entryEase = math.Clamp(state.timeInWater / 2.0, 0, 1)

            local targetLinearDamp = PHYSICS_CONFIG.lateralDamping
            local targetAngularDamp = PHYSICS_CONFIG.angularDamping
            if hasDriver then
                targetLinearDamp = targetLinearDamp + 5.0   
                targetAngularDamp = targetAngularDamp + 10.0
            end
            phys:SetDamping(targetLinearDamp * entryEase, targetAngularDamp * entryEase)

            local mins, maxs = ent:GetCollisionBounds()
            local fullHeight = maxs.z - mins.z
            local waterZ = ent:GetPos().z + (fullHeight * 0.5)

            local tr = util.TraceLine({
                start  = ent:GetPos() + Vector(0, 0, 500),
                endpos = ent:GetPos() + Vector(0, 0, -500),
                mask   = MASK_WATER,
            })
            if tr.Hit then waterZ = tr.HitPos.z end

            local zOffset = mins.z + (fullHeight * 0.2)
            local localPoints = {
                { pos = Vector(mins.x * 0.85, mins.y * 0.85, zOffset), isFront = false }, 
                { pos = Vector(maxs.x * 0.85, mins.y * 0.85, zOffset), isFront = true  }, 
                { pos = Vector(mins.x * 0.85, maxs.y * 0.85, zOffset), isFront = false }, 
                { pos = Vector(maxs.x * 0.85, maxs.y * 0.85, zOffset), isFront = true  }  
            }

            local pointMass = mass / 4

            for _, ptData in ipairs(localPoints) do
                local wPt = ent:LocalToWorld(ptData.pos)
                local depth = (waterZ + cfg_float_offset) - wPt.z

                local pointFill = fill
                if ptData.isFront then
                    pointFill = math.Clamp(fill * (1 + cfg_sink_bias * 1.5), 0, 1)
                else
                    if cfg_air_pocket > 0 then
                        if fill < cfg_air_pocket then
                            pointFill = 0 
                        else
                            pointFill = math.Clamp((fill - cfg_air_pocket) / (1 - cfg_air_pocket + 0.001), 0, 1)
                        end
                    else
                        pointFill = math.Clamp(fill * (1 - cfg_sink_bias), 0, 1)
                    end
                end

                local driverWeightMultiplier = hasDriver and 4.5 or 1.5
                local pointSinkingWeight = pointFill * pointMass * serverGravity * driverWeightMultiplier
                phys:ApplyForceOffset(Vector(0, 0, -pointSinkingWeight * dt), wPt)

                if depth > 0 then
                    local pointBuoyancyFactor = math.max(0, 1 - pointFill)
                    local pointSubmerged = math.Clamp(depth / fullHeight, 0, 1)
                    local pointUpwardForce = pointSubmerged * PHYSICS_CONFIG.floatStiffness * pointMass * pointBuoyancyFactor * (serverGravity * 0.1)

                    local pointVel = phys:GetVelocityAtPoint(wPt)
                    local dampCoefficient = hasDriver and (cfg_damp_scale * 1.5) or cfg_damp_scale
                    local pointVerticalDamp = -pointVel.z * pointMass * dampCoefficient * entryEase

                    phys:ApplyForceOffset(Vector(0, 0, (pointUpwardForce + pointVerticalDamp) * dt), wPt)
                end
            end

            if cfg_use_particles and math.random() > 0.4 then
                local wMins, wMaxs = ent:WorldSpaceAABB()

                if inWater and fill > 0 and fill < 1 and state.timeInWater > cfg_sink_delay then
                    local bubbleHeight = math.max(0, waterZ - wMins.z)
                    if bubbleHeight > 5 then
                        local spawnMins = Vector(wMins.x, wMins.y, wMins.z)
                        local spawnMaxs = Vector(wMaxs.x, wMaxs.y, wMins.z + 8)
                        effects.Bubbles(spawnMins, spawnMaxs, math.random(2, 4), bubbleHeight, 15)
                    end
                end
            end

            local dragMult = hasDriver and 1.5 or PHYSICS_CONFIG.waterFriction
            local horizontalDragForce = Vector(-vel.x, -vel.y, 0) * mass * dragMult * entryEase
            phys:ApplyForceCenter(Vector(horizontalDragForce.x, horizontalDragForce.y, 0) * dt)
        else
            if cfg_use_particles and state.waterFill > 0 and math.random() > 0.4 then
                local wMins, wMaxs = ent:WorldSpaceAABB()
                local randomX = math.Rand(wMins.x, wMaxs.x)
                local randomY = math.Rand(wMins.y, wMaxs.y)
                local drainPos = Vector(randomX, randomY, wMins.z + 2)

                local ed = EffectData()
                ed:SetOrigin(drainPos)
                ed:SetScale(0.4) 
                util.Effect("GlassImpact", ed)
            end

            phys:SetDamping(0, 0)
        end
    end
end)

hook.Add("EntityRemoved", "GlideWaterPhysics_Cleanup", function(ent)
    local id = ent:EntIndex()
    if vehicleState[id] then
        if vehicleState[id].sinkSoundObj then vehicleState[id].sinkSoundObj:Stop() end
        if vehicleState[id].drainSoundObj then vehicleState[id].drainSoundObj:Stop() end
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then 
            phys:EnableGravity(true) 
            phys:SetDamping(0, 0)
        end
        vehicleState[id] = nil
    end
end)