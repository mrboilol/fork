
if not SERVER then return end

-- Ensure the client net message used by head impacts is registered.
util.AddNetworkString("headtrauma_flash")

-- Configuration
local FALL_SOUND_THRESHOLD = 45
local FALL_SOUND_COOLDOWN = 3.5 
local MIN_HEIGHT_FOR_SOUND = 2 

-- ConVars for easy configuration
CreateConVar("hg_fallsounds_enabled", "1", FCVAR_REPLICATED, "Enable ragdoll fall impact sounds", 0, 1)
CreateConVar("hg_fallsounds_threshold", "50", FCVAR_REPLICATED, "Minimum speed for fall sounds (lower = more sensitive)", 25, 500)
CreateConVar("hg_fallsounds_volume", "1.0", FCVAR_REPLICATED, "Volume multiplier for fall sounds", 0.1, 2.0)

-- Sound tracking to prevent sound spam
local fallSoundTracker = {}

-- Fall sounds from mcitycustomcontent
local FALL_SOUNDS = {
    "fall/FALLS_01.wav",
    "fall/FALLS_02.wav", 
    "fall/FALLS_03.wav",
    "fall/FALLS_04.wav",
    "fall/FALLS_05.wav",
    "fall/FALLS_06.wav",
    "fall/FALLS_07.wav"
}

-- Critical hit bones that should trigger more dramatic sounds
local CRITICAL_BONES = {
    ["ValveBiped.Bip01_Head1"] = true,
    ["ValveBiped.Bip01_Spine1"] = true,
    ["ValveBiped.Bip01_Spine2"] = true,
    ["ValveBiped.Bip01_Pelvis"] = true,
    ["ValveBiped.Bip01_Spine"] = true
}

-- Get the bone name from physics bone number
local function GetBoneNameFromPhysBone(ragdoll, physBone)
    local bone = ragdoll:TranslatePhysBoneToBone(physBone)
    if bone < 0 then return nil end
    return ragdoll:GetBoneName(bone)
end

-- Check if entity is the ground/world
local function IsGroundEntity(ent)
    if not IsValid(ent) then return true end -- Hit skybox/nothing counts as ground
    if ent:IsWorld() then return true end
    
    -- Check for common ground materials
    local mat = ent:GetMaterial()
    if mat and (string.find(mat:lower(), "concrete") or 
               string.find(mat:lower(), "dirt") or 
               string.find(mat:lower(), "grass") or 
               string.find(mat:lower(), "metal") or 
               string.find(mat:lower(), "wood")) then
        return true
    end
    
    -- Check surface props from physics object if available
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        -- guard: some phys objects may lack GetMaterialIndex
        local getMat = phys.GetMaterialIndex
        if getMat then
            local ok, matIndex = pcall(getMat, phys)
            if ok and matIndex and matIndex > 0 then
                local surfaceProp = util.GetSurfacePropName(matIndex)
                if surfaceProp and (surfaceProp == "concrete" or 
                                   surfaceProp == "dirt" or 
                                   surfaceProp == "grass" or 
                                   surfaceProp == "metal" or 
                                   surfaceProp == "wood") then
                    return true
                end
            end
        end
    end
    
    -- Check if it's a common ground entity type
    local class = ent:GetClass()
    if class and (string.find(class:lower(), "prop_") or 
                 string.find(class:lower(), "func_") or 
                 class == "worldspawn") then
        return true
    end
    
    return false
end

-- Check if ragdoll is falling/impacting from a height
local function GetFallHeight(ragdoll)
    if not ragdoll.LastGroundPos then
        -- First time tracking, set initial ground position
        ragdoll.LastGroundPos = ragdoll:GetPos()
        ragdoll.LastGroundTime = CurTime()
        return 0
    end
    
    local currentPos = ragdoll:GetPos()
    local timeSinceLastGround = CurTime() - (ragdoll.LastGroundTime or 0)
    
    -- If we've been in air for more than a brief moment, calculate fall height
    if timeSinceLastGround > 0.1 then
        local heightDiff = ragdoll.LastGroundPos.z - currentPos.z
        return math.max(0, heightDiff)
    end
    
    return 0
end

-- Update ground position tracking
local function UpdateGroundPosition(ragdoll)
    local currentPos = ragdoll:GetPos()
    local groundPos = currentPos
    
    -- Trace down to find actual ground
    local trace = util.TraceLine({
        start = currentPos + Vector(0, 0, 10),
        endpos = currentPos - Vector(0, 0, 100),
        filter = ragdoll
    })
    
    if trace.Hit then
        groundPos = trace.HitPos
    end
    
    -- Update tracking if we're close to ground or moving slowly - more sensitive for simple falls
    local phys = ragdoll:GetPhysicsObject()
    if IsValid(phys) then
        local velocity = phys:GetVelocity()
        if velocity:Length() < 50 or (currentPos.z - groundPos.z) < 30 then
            ragdoll.LastGroundPos = groundPos
            ragdoll.LastGroundTime = CurTime()
        end
    end
end

-- Check if this ragdoll is on cooldown for fall sounds
local function IsFallSoundOnCooldown(ragdoll)
    local ragdollID = ragdoll:EntIndex()
    local lastSound = fallSoundTracker[ragdollID]
    
    if not lastSound then return false end
    
    return (CurTime() - lastSound) < FALL_SOUND_COOLDOWN
end

-- Record fall sound to prevent spam
local function RecordFallSound(ragdoll)
    local ragdollID = ragdoll:EntIndex()
    fallSoundTracker[ragdollID] = CurTime()
end

-- Clean up old entries from sound tracker (called periodically)
local function CleanupFallSoundTracker()
    local currentTime = CurTime()
    for ragdollID, lastSound in pairs(fallSoundTracker) do
        if (currentTime - lastSound) > FALL_SOUND_COOLDOWN * 3 then
            fallSoundTracker[ragdollID] = nil
        end
    end
end

-- Determine impact intensity based on speed and hit location
local function GetImpactIntensity(speed, boneName)
    if speed > 400 then
        return "heavy"
    elseif speed > 200 then
        return CRITICAL_BONES[boneName] and "heavy" or "medium"
    elseif speed > FALL_SOUND_THRESHOLD then
        return CRITICAL_BONES[boneName] and "medium" or "light"
    end
    return "light"
end

-- Play appropriate fall sound based on impact intensity
local function PlayFallSound(ragdoll, hitPos, intensity)
    local soundFile
    local volume
    local pitch
    
    -- Get volume multiplier from ConVar
    local volumeMultiplier = GetConVar("hg_fallsounds_volume"):GetFloat()
    
    if intensity == "heavy" then
        -- Heavy impacts get louder, deeper sounds
        soundFile = FALL_SOUNDS[math.random(1, 3)] -- Use first 3 for heavy
        volume = math.Rand(0.8, 1.0) * volumeMultiplier
        pitch = math.Rand(90, 100)
    elseif intensity == "medium" then
        -- Medium impacts get middle sounds
        soundFile = FALL_SOUNDS[math.random(3, 5)] -- Use middle 3 for medium
        volume = math.Rand(0.6, 0.8) * volumeMultiplier
        pitch = math.Rand(95, 105)
    else
        -- Light impacts get softer sounds
        soundFile = FALL_SOUNDS[math.random(5, 7)] -- Use last 3 for light
        volume = math.Rand(0.4, 0.6) * volumeMultiplier
        pitch = math.Rand(100, 110)
    end
    
    -- Play the sound
    sound.Play(soundFile, hitPos, 75, pitch, volume)
    
    -- Debug output for developers
    if GetConVar("developer"):GetInt() == 1 then
        local owner = hg.RagdollOwner(ragdoll)
        local ownerName = IsValid(owner) and owner:GetName() or "Unknown"
        print(string.format("[FALL SOUND] %s hit ground, intensity: %s, sound: %s", 
            ownerName, intensity, soundFile))
    end
end

-- Main collision hook for ragdoll fall sounds - using Ragdoll Collide like other systems
hook.Add("Ragdoll Collide", "RagdollFallSounds", function(ragdoll, data)
    -- Check if system is enabled
    if not GetConVar("hg_fallsounds_enabled"):GetBool() then return end
    
    -- Only process ragdolls
    if not IsValid(ragdoll) or ragdoll:GetClass() ~= "prop_ragdoll" then return end
    
    -- Check if ragdoll has an owner (player)
    local owner = hg.RagdollOwner(ragdoll)
    if not IsValid(owner) or not owner:IsPlayer() then return end

    -- Fake-control contacts are continuous physics motion, not new falls.
    -- Keep this impact system for corpses, but never loop it on a living fake.
    if owner:Alive() and owner.FakeRagdoll == ragdoll then return end

    -- Share the authoritative grounded latch with the legacy fall-sound hook.
    -- Resting physics bones keep colliding, but they are not new landings.
    if ragdoll.hg_fallSoundGrounded then return end
    
    -- Check if we're hitting the ground or a solid surface
    if not IsGroundEntity(data.HitEntity) then return end
    
    -- Get current threshold from ConVar
    local currentThreshold = GetConVar("hg_fallsounds_threshold"):GetInt()
    
    -- Get collision speed from OurOldVelocity (like kick damage system)
    local collisionSpeed = data.OurOldVelocity:Length()
    
    -- Check speed threshold
    if collisionSpeed < currentThreshold then return end
    
    -- Check cooldown to prevent spam
    if IsFallSoundOnCooldown(ragdoll) then return end
    
    -- Find which physics bone hit (data.PhysObject is already the physics object)
    local physBone = nil
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        if physObj == data.PhysObject then
            physBone = i
            break
        end
    end
    
    if not physBone then return end
    
    -- Get bone name to determine impact intensity
    local boneName = GetBoneNameFromPhysBone(ragdoll, physBone)
    if not boneName then return end
    
    -- Check fall height - much more lenient for simple falls
    local fallHeight = GetFallHeight(ragdoll)
    -- Only require height for very low speed impacts (under 100)
    if fallHeight < MIN_HEIGHT_FOR_SOUND and collisionSpeed < 100 then return end
    
    -- Determine impact intensity
    local intensity = GetImpactIntensity(collisionSpeed, boneName)
    
    -- Play the appropriate sound
    PlayFallSound(ragdoll, data.HitPos or ragdoll:GetPos(), intensity)

    -- quick flash for head-ground impacts on falls
    if boneName == "ValveBiped.Bip01_Head1" then
        local owner = hg.RagdollOwner(ragdoll)
        if IsValid(owner) and owner:IsPlayer() then
            owner.HeadDisorientFlashCooldown = owner.HeadDisorientFlashCooldown or 0
            if owner.HeadDisorientFlashCooldown < CurTime() then
                local hitpos = data.HitPos or ragdoll:GetPos()
                net.Start("headtrauma_flash")
                    net.WriteVector(hitpos)
                    net.WriteFloat(0.6)
                    net.WriteInt(2200, 20)
                    net.WriteBool(false) -- is_critical
                    net.WriteBool(false) -- play_knockout_sound
                    net.WriteBool(false) -- hasBrainDamage
                    net.WriteBool(false) -- hasConcussion
                    net.WriteBool(false) -- trigger_tinnitus
                net.Send(owner)
                owner.HeadDisorientFlashCooldown = CurTime() + 0.35
            end
        end
    end
    
    -- Record this sound to prevent rapid successive sounds
    RecordFallSound(ragdoll)
    ragdoll.hg_fallSoundGrounded = true
    
    -- Update ground position tracking after impact
    UpdateGroundPosition(ragdoll)
end)

-- Head impact flash for non-ground crush-like collisions
hook.Add("Ragdoll Collide", "RagdollHeadFlashImpact", function(ragdoll, data)
    if not IsValid(ragdoll) or ragdoll:GetClass() ~= "prop_ragdoll" then return end
    local owner = hg.RagdollOwner(ragdoll)
    if not IsValid(owner) or not owner:IsPlayer() then return end

    -- small cooldown to prevent spam
    ragdoll.HeadFlashCooldown = ragdoll.HeadFlashCooldown or 0
    if ragdoll.HeadFlashCooldown > CurTime() then return end

    -- map phys object to phys bone
    local physBone = nil
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        if physObj == data.PhysObject then
            physBone = i
            break
        end
    end
    if not physBone then return end

    local boneName = GetBoneNameFromPhysBone(ragdoll, physBone)
    if boneName ~= "ValveBiped.Bip01_Head1" then return end

    local speed = (data.OurOldVelocity and data.OurOldVelocity:Length()) or data.Speed or 0
    local threshold = GetConVar("hg_fallsounds_threshold"):GetInt()
    if speed < math.max(threshold, 80) then return end

    local hitpos = data.HitPos or ragdoll:GetPos()
    owner.HeadDisorientFlashCooldown = owner.HeadDisorientFlashCooldown or 0
    if owner.HeadDisorientFlashCooldown < CurTime() then
        net.Start("headtrauma_flash")
            net.WriteVector(hitpos)
            net.WriteFloat(0.6)
            net.WriteInt(2200, 20)
            net.WriteBool(false) -- is_critical
            net.WriteBool(false) -- play_knockout_sound
            net.WriteBool(false) -- hasBrainDamage
            net.WriteBool(false) -- hasConcussion
            net.WriteBool(false) -- trigger_tinnitus
        net.Send(owner)
        owner.HeadDisorientFlashCooldown = CurTime() + 0.35
    end

    ragdoll.HeadFlashCooldown = CurTime() + 0.4
end)

-- Periodic cleanup of sound tracker to prevent memory leaks
timer.Create("FallSoundCleanup", 10, 0, function()
    CleanupFallSoundTracker()
end)

-- Console command to test fall sounds
concommand.Add("hg_testfallsound", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    local intensity = args[1] or "medium"
    local testSounds = {
        heavy = FALL_SOUNDS[math.random(1, 3)],
        medium = FALL_SOUNDS[math.random(3, 5)],
        light = FALL_SOUNDS[math.random(5, 7)]
    }
    
    local soundFile = testSounds[intensity] or testSounds.medium
    local volumeMultiplier = GetConVar("hg_fallsounds_volume"):GetFloat()
    local volume = (intensity == "heavy" and 0.9 or intensity == "medium" and 0.7 or 0.5) * volumeMultiplier
    
    ply:EmitSound(soundFile, 75, 100, volume)
end)

-- Console command to test if sound files work
concommand.Add("hg_testfallsound_direct", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    local soundNum = tonumber(args[1]) or math.random(1, 7)
    local soundFile = FALL_SOUNDS[soundNum]
    local volume = GetConVar("hg_fallsounds_volume"):GetFloat()
    
    if soundFile then
        ply:EmitSound(soundFile, 75, 100, volume)
    end
end)
