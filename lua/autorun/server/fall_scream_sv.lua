if SERVER then
    
    local SCREAM_VOLUME = 75
    local SCREAM_COOLDOWN = 2.0
    local MIN_SPEED = 350
    local AIR_DELAY = 0.3
    
    local MALE_SOUNDS = {}
    for i = 1, 16 do
        MALE_SOUNDS[i] = "player/male/male" .. i .. ".wav"
    end
    
    local FEMALE_SOUNDS = {}
    for i = 1, 16 do
        FEMALE_SOUNDS[i] = "player/female/female" .. i .. ".wav"
    end
    
    local COMBINE_SOUNDS = {}
    for i = 1, 16 do
        COMBINE_SOUNDS[i] = "player/combine/combine" .. i .. ".wav"
    end
    
    for _, s in ipairs(MALE_SOUNDS) do resource.AddFile("sound/" .. s) end
    for _, s in ipairs(FEMALE_SOUNDS) do resource.AddFile("sound/" .. s) end
    for _, s in ipairs(COMBINE_SOUNDS) do resource.AddFile("sound/" .. s) end
    
    local function GetScreamSound(ply)
        if not IsValid(ply) then return nil end
        
        if ply.PlayerClassName == "Combine" then
            return COMBINE_SOUNDS[math.random(1, #COMBINE_SOUNDS)]
        end
        
        local model = ply:GetModel():lower()
        if string.find(model, "female") or string.find(model, "f_") then
            return FEMALE_SOUNDS[math.random(1, #FEMALE_SOUNDS)]
        end
        
        return MALE_SOUNDS[math.random(1, #MALE_SOUNDS)]
    end
    
    local function IsPlayerConscious(ply)
        if not IsValid(ply) then return false end
        if not ply:Alive() then return false end
        
        local org = ply.organism
        if org then
            if org.alive == false then return false end
            if org.otrub == true then return false end
            if org.incapacitated == true then return false end
            if org.consciousness and org.consciousness < 0.3 then return false end
        end
        
        return true
    end
    
    local function IsInFakeMode(ply)
        if not IsValid(ply) then return false end
        if IsValid(ply.FakeRagdoll) then return true end
        if IsValid(ply:GetNWEntity("FakeRagdoll")) then return true end
        if ply:GetMoveType() == MOVETYPE_NOCLIP and not ply:InVehicle() then
            return true
        end
        return false
    end
    
    local function IsInAir(ply)
        if not IsValid(ply) then return false end
        
        if IsInFakeMode(ply) then
            local ragdoll = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply:GetNWEntity("FakeRagdoll")
            if IsValid(ragdoll) then
                local pos = ragdoll:GetPos()
                local trace = {}
                trace.start = pos
                trace.endpos = pos - Vector(0, 0, 10)
                trace.filter = {ply, ragdoll}
                trace.mask = MASK_SOLID
                local tr = util.TraceLine(trace)
                return not tr.Hit
            end
            return false
        end
        
        return not ply:OnGround() and ply:WaterLevel() == 0
    end
    
    local function GetFallSpeed(ply)
        if not IsValid(ply) then return 0 end
        
        if IsInFakeMode(ply) then
            local ragdoll = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply:GetNWEntity("FakeRagdoll")
            if IsValid(ragdoll) then
                local vel = ragdoll:GetVelocity()
                return -vel.z
            end
            return 0
        end
        
        local vel = ply:GetVelocity()
        return -vel.z
    end
    
    local function PlayScream(ply, speed)
        if not IsValid(ply) then return end
        if not IsPlayerConscious(ply) then return end
        if speed < MIN_SPEED then return end
        if ply:InVehicle() then return end
        if ply:WaterLevel() > 0 then return end
        if ply._lastScream and ply._lastScream > CurTime() then return end
        
        local sound = GetScreamSound(ply)
        if sound then
            ply:EmitSound(sound, SCREAM_VOLUME, math.random(90, 110))
            ply._lastScream = CurTime() + SCREAM_COOLDOWN
            ply._screamSound = sound
            ply._isScreaming = true
        end
    end
    
    local function StopScream(ply)
        if IsValid(ply) and ply._isScreaming then
            if ply._screamSound then ply:StopSound(ply._screamSound) end
            ply._isScreaming = false
            ply._screamSound = nil
        end
    end

    hg = hg or {}
    hg.GetFallScreamSound = GetScreamSound
    hg.StopFallScream = StopScream
    
    local playerStates = {}
    
    hook.Add("Think", "FS_AirScream", function()
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then 
                playerStates[ply] = nil
                continue 
            end
            
            if not ply:Alive() then
                playerStates[ply] = nil
                continue
            end
            
            if not IsPlayerConscious(ply) then
                playerStates[ply] = nil
                StopScream(ply)
                continue
            end
            
            local downSpeed = GetFallSpeed(ply)
            local inAir = IsInAir(ply)
            
            if not playerStates[ply] then
                playerStates[ply] = {
                    wasInAir = false,
                    fallStartTime = 0,
                    screamed = false,
                }
            end
            
            local state = playerStates[ply]
            
            if inAir and downSpeed > MIN_SPEED then
                if not state.wasInAir then
                    state.wasInAir = true
                    state.fallStartTime = CurTime()
                    state.screamed = false
                end
                
                    if state.screamed and CurTime() > (ply._lastScream or 0) then
                    state.screamed = false
                    state.fallStartTime = CurTime()
                end
                
                if not state.screamed and CurTime() - state.fallStartTime > AIR_DELAY then
                    state.screamed = true
                    PlayScream(ply, downSpeed)
                end
            else
                if state.wasInAir then
                    state.wasInAir = false
                    StopScream(ply)
                end
            end
        end
    end)
    
    hook.Add("Fake", "FS_FakeCreated", function(ply, ragdoll)
        if IsValid(ply) and IsValid(ragdoll) then
            
            if not IsPlayerConscious(ply) then return end
            
            local vel = ragdoll:GetVelocity()
            local speed = -vel.z
            if speed > MIN_SPEED then
                timer.Simple(AIR_DELAY, function()
                    if IsValid(ply) and IsValid(ragdoll) then
                        if IsPlayerConscious(ply) then
                            local newSpeed = -ragdoll:GetVelocity().z
                            if newSpeed > MIN_SPEED then
                                PlayScream(ply, newSpeed)
                            end
                        end
                    end
                end)
            end
        end
    end)
    
    hook.Add("Think", "FS_FakeFallCheck", function()
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then continue end
            
            if not IsPlayerConscious(ply) then
                playerStates["fake_" .. ply:EntIndex()] = nil
                StopScream(ply)
                continue
            end
            
            if not IsInFakeMode(ply) then 
                playerStates["fake_" .. ply:EntIndex()] = nil
                continue 
            end
            
            local ragdoll = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply:GetNWEntity("FakeRagdoll")
            if not IsValid(ragdoll) then continue end
            
            local vel = ragdoll:GetVelocity()
            local downSpeed = -vel.z
            
            local pos = ragdoll:GetPos()
            local trace = {}
            trace.start = pos
            trace.endpos = pos - Vector(0, 0, 10)
            trace.filter = {ply, ragdoll}
            trace.mask = MASK_SOLID
            local tr = util.TraceLine(trace)
            
            local inAir = not tr.Hit
            
            if not playerStates["fake_" .. ply:EntIndex()] then
                playerStates["fake_" .. ply:EntIndex()] = {
                    wasInAir = false,
                    fallStartTime = 0,
                    screamed = false,
                }
            end
            
            local state = playerStates["fake_" .. ply:EntIndex()]
            
            if inAir and downSpeed > MIN_SPEED then
                if not state.wasInAir then
                    state.wasInAir = true
                    state.fallStartTime = CurTime()
                    state.screamed = false
                end
                
                -- КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: сброс флага, если игрок уже откричал кулдаун
                -- и снова падает (например, ударился, отскочил и продолжает падать)
                if state.screamed and CurTime() > (ply._lastScream or 0) then
                    state.screamed = false
                    state.fallStartTime = CurTime()
                end
                
                if not state.screamed and CurTime() - state.fallStartTime > AIR_DELAY then
                    state.screamed = true
                    PlayScream(ply, downSpeed)
                end
            else
                if state.wasInAir then
                    state.wasInAir = false
                    StopScream(ply)
                end
            end
        end
    end)
    
    hook.Add("Fake Up", "FS_FakeUp", function(ply, ragdoll)
        if IsValid(ply) then
            playerStates[ply] = nil
            playerStates["fake_" .. ply:EntIndex()] = nil
            ply._lastScream = nil
            StopScream(ply)
        end
    end)
    
    hook.Add("PlayerDeath", "FS_Death", function(ply)
        if IsValid(ply) then
            playerStates[ply] = nil
            playerStates["fake_" .. ply:EntIndex()] = nil
            ply._lastScream = nil
            StopScream(ply)
        end
    end)
    
    hook.Add("PlayerSpawn", "FS_Spawn", function(ply)
        if IsValid(ply) then
            playerStates[ply] = nil
            playerStates["fake_" .. ply:EntIndex()] = nil
            ply._lastScream = nil
            StopScream(ply)
        end
    end)
    
    concommand.Add("test_fall_scream", function(ply)
        if IsValid(ply) then
            PlayScream(ply, 600)
        end
    end)
    
    concommand.Add("test_all_screams", function(ply)
        if not IsValid(ply) then return end
        
        local allSounds = {}
        for _, s in ipairs(MALE_SOUNDS) do table.insert(allSounds, s) end
        for _, s in ipairs(FEMALE_SOUNDS) do table.insert(allSounds, s) end
        for _, s in ipairs(COMBINE_SOUNDS) do table.insert(allSounds, s) end
        
        local idx = 1
        timer.Create("test_scream_timer", 0.3, #allSounds, function()
            if not IsValid(ply) then return end
            if idx <= #allSounds then
                ply:EmitSound(allSounds[idx], 75, 100)
                idx = idx + 1
            end
        end)
    end)
end