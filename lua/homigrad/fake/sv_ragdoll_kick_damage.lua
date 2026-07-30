-- Ragdoll High-Speed Impact Damage System
-- Handles damage when ragdoll striking bones hit players/ragdolls at high speeds

if not SERVER then return end

-- Configuration
local LEG_SHOVE_SPEED_THRESHOLD = 100
local DROP_KICK_SPEED_THRESHOLD = 360
local TACKLE_SPEED_THRESHOLD = 160
local KICK_DAMAGE_COOLDOWN = 0.5 -- Cooldown between kick damage hits (seconds)
local DROP_KICK_STAMINA_COST = 30

-- Hit tracking to prevent damage multiplication
local kickHitTracker = {}

-- Bones that can deal collision damage during kicks, tackles, and flailing hits.
local KICK_BONES = {
    ["ValveBiped.Bip01_L_UpperArm"] = true,
    ["ValveBiped.Bip01_R_UpperArm"] = true,
    ["ValveBiped.Bip01_L_Forearm"] = true,
    ["ValveBiped.Bip01_R_Forearm"] = true,
    ["ValveBiped.Bip01_L_Hand"] = true,
    ["ValveBiped.Bip01_R_Hand"] = true,
    ["ValveBiped.Bip01_L_Calf"] = true,
    ["ValveBiped.Bip01_R_Calf"] = true,
    ["ValveBiped.Bip01_L_Foot"] = true,
    ["ValveBiped.Bip01_R_Foot"] = true,
    ["ValveBiped.Bip01_L_Thigh"] = true, -- Added missing thigh bones
    ["ValveBiped.Bip01_R_Thigh"] = true, -- Added missing thigh bones
    ["ValveBiped.Bip01_Head1"] = true,
    ["ValveBiped.Bip01_Pelvis"] = true,
    ["ValveBiped.Bip01_Spine"] = true,
    ["ValveBiped.Bip01_Spine1"] = true,
    ["ValveBiped.Bip01_Spine2"] = true,
}

local LEG_BONES = {
    ["ValveBiped.Bip01_L_Thigh"] = true,
    ["ValveBiped.Bip01_L_Calf"] = true,
    ["ValveBiped.Bip01_L_Foot"] = true,
    ["ValveBiped.Bip01_R_Thigh"] = true,
    ["ValveBiped.Bip01_R_Calf"] = true,
    ["ValveBiped.Bip01_R_Foot"] = true,
}

local BONE_HITGROUPS = {
    ["ValveBiped.Bip01_L_UpperArm"] = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_L_Forearm"] = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_L_Hand"] = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_R_UpperArm"] = HITGROUP_RIGHTARM,
    ["ValveBiped.Bip01_R_Forearm"] = HITGROUP_RIGHTARM,
    ["ValveBiped.Bip01_R_Hand"] = HITGROUP_RIGHTARM,
    ["ValveBiped.Bip01_L_Thigh"] = HITGROUP_LEFTLEG,
    ["ValveBiped.Bip01_L_Calf"] = HITGROUP_LEFTLEG,
    ["ValveBiped.Bip01_L_Foot"] = HITGROUP_LEFTLEG,
    ["ValveBiped.Bip01_R_Thigh"] = HITGROUP_RIGHTLEG,
    ["ValveBiped.Bip01_R_Calf"] = HITGROUP_RIGHTLEG,
    ["ValveBiped.Bip01_R_Foot"] = HITGROUP_RIGHTLEG,
    ["ValveBiped.Bip01_Head1"] = HITGROUP_HEAD,
    ["ValveBiped.Bip01_Pelvis"] = HITGROUP_STOMACH,
    ["ValveBiped.Bip01_Spine"] = HITGROUP_CHEST,
    ["ValveBiped.Bip01_Spine1"] = HITGROUP_CHEST,
    ["ValveBiped.Bip01_Spine2"] = HITGROUP_CHEST,
}

-- Sound effects for different impact types
local KICK_SOUNDS = {
    flesh = "physics/flesh/flesh_impact_hard1.wav",
    body = "physics/body/body_medium_impact_hard1.wav",
    generic = "physics/concrete/concrete_impact_hard3.wav",
}

-- Get the bone name from physics bone number
local function GetBoneNameFromPhysBone(ragdoll, physBone)
    local bone = ragdoll:TranslatePhysBoneToBone(physBone)
    if bone < 0 then return nil end
    return ragdoll:GetBoneName(bone)
end

-- Door collisions happen before the ordinary damage path, so identify a real
-- leg-first airborne hit here instead of treating every ragdoll impact alike.
local function IsRagdollDropkick(ragdoll, data)
    if data.OurOldVelocity:Length() < DROP_KICK_SPEED_THRESHOLD then return false end

    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        if ragdoll:GetPhysicsObjectNum(i) == data.PhysObject then
            return LEG_BONES[GetBoneNameFromPhysBone(ragdoll, i)] == true
        end
    end

    return false
end

-- Generate unique key for attacker-target pair
local function GetHitKey(attacker, target)
    local attackerID = IsValid(attacker) and attacker:SteamID() or "unknown"
    local targetID = ""
    
    if target:IsPlayer() then
        targetID = target:SteamID()
    elseif target:IsRagdoll() then
        local owner = hg.RagdollOwner(target)
        targetID = IsValid(owner) and owner:SteamID() or tostring(target:EntIndex())
    else
        targetID = tostring(target:EntIndex())
    end
    
    return attackerID .. "_" .. targetID
end

-- Check if kick damage is on cooldown
local function IsKickOnCooldown(attacker, target)
    local key = GetHitKey(attacker, target)
    local lastHit = kickHitTracker[key]
    
    if not lastHit then return false end
    
    return (CurTime() - lastHit) < KICK_DAMAGE_COOLDOWN
end

-- Record kick damage hit
local function RecordKickHit(attacker, target)
    local key = GetHitKey(attacker, target)
    kickHitTracker[key] = CurTime()
end

-- Clean up old entries from hit tracker (called periodically)
local function CleanupHitTracker()
    local currentTime = CurTime()
    for key, lastHit in pairs(kickHitTracker) do
        if (currentTime - lastHit) > KICK_DAMAGE_COOLDOWN * 2 then
            kickHitTracker[key] = nil
        end
    end
end

-- Check if entity can take kick damage
local function CanTakeKickDamage(ent)
    if not IsValid(ent) then return false end
    
    -- Players and NPCs can take damage
    if ent:IsPlayer() then return true end
    if ent:IsNPC() then return true end
    
    -- Ragdolls can take damage if they have a valid owner
    if ent:IsRagdoll() then
        local owner = hg.RagdollOwner(ent)
        return IsValid(owner) and owner:IsPlayer()
    end
    
    return false
end

-- Leg extensions are primarily shoves, while a fast airborne leg impact becomes a dropkick.
-- Body, arm, and head contacts are tackles: reliable knockback with deliberately low damage.
local function CalculateImpact(boneName, speed)
    if LEG_BONES[boneName] then
        if speed >= DROP_KICK_SPEED_THRESHOLD then
            -- A committed ragdoll dropkick should hit harder than the animated hg_kick dropkick.
            return math.min(34 + (speed - DROP_KICK_SPEED_THRESHOLD) * 0.14, 65),
                math.max(2200, speed * 8),
                math.Clamp(350 + (speed - DROP_KICK_SPEED_THRESHOLD) * 1.5, 400, 900),
                "dropkick"
        end

        if speed >= LEG_SHOVE_SPEED_THRESHOLD then
            return math.min(1 + (speed - LEG_SHOVE_SPEED_THRESHOLD) * 0.035, 9),
                math.max(1400, speed * 8),
                math.Clamp(250 + speed * 1.4, 350, 650),
                "leg shove"
        end
    elseif speed >= TACKLE_SPEED_THRESHOLD then
        return math.min(2 + (speed - TACKLE_SPEED_THRESHOLD) * 0.04, 13),
            math.max(1000, speed * 5),
            math.Clamp(200 + speed, 300, 600),
            "tackle"
    end

    return 0, 0, 0, nil
end

-- Get appropriate sound for the target
local function GetKickSound(target)
    if target:IsPlayer() then
        return KICK_SOUNDS.flesh
    elseif target:IsRagdoll() then
        return KICK_SOUNDS.body
    else
        return KICK_SOUNDS.generic
    end
end

-- Apply kick damage to target
local function ApplyKickDamage(attacker, target, damage, hitPos, force, boneName, knockback)
    if damage <= 0 then return end
    
    -- Create damage info similar to weapon_melee
    local dmginfo = DamageInfo()
    dmginfo:SetAttacker(attacker)
    dmginfo:SetInflictor(attacker.FakeRagdoll or attacker) -- Use ragdoll as inflictor if available
    dmginfo:SetDamage(damage)
    dmginfo:SetDamageForce(force)
    dmginfo:SetDamageType(DMG_CLUB) -- Blunt damage like melee weapons
    dmginfo:SetDamagePosition(hitPos)
    
    -- Apply damage
    target:TakeDamageInfo(dmginfo)

    local harm = dmginfo:GetDamage() / 100
    local hitgroup = HITGROUP_GENERIC
    hitgroup = BONE_HITGROUPS[boneName] or HITGROUP_GENERIC
    hook.Run("HomigradDamage", target, dmginfo, hitgroup, target, harm)
    
    -- Add knockback effect similar to weapon_melee
    if target:IsPlayer() or target:IsRagdoll() then
        local targetPlayer = hg.RagdollOwner(target) or target
        if IsValid(targetPlayer) and targetPlayer:IsPlayer() then
            -- Apply view punch and velocity like melee weapons
            local forceDir = force:GetNormalized()
            targetPlayer:ViewPunch(Angle(damage * 0.3, 0, 0))
            targetPlayer:SetVelocity(forceDir * knockback)
        end
    end
    
    -- Apply physics force to ragdolls
    if target:IsRagdoll() then
        local phys = target:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceOffset(force, hitPos)
        end
    end
    
    -- Play impact sound
    local sound = GetKickSound(target)
    target:EmitSound(sound, 75, math.random(95, 105))
    
	-- A committed ragdoll kick shares the same short attack-adrenaline window and cap.
	if IsValid(attacker) and attacker.organism then
		local attackerOrg = attacker.organism
		local now = CurTime()

		if now >= (attackerOrg._attackAdrenalineCooldownUntil or 0) then
			attackerOrg._attackAdrenalineGainUntil = now + 2
			attackerOrg._attackAdrenalineCooldownUntil = attackerOrg._attackAdrenalineGainUntil + 5
		end

		if now <= (attackerOrg._attackAdrenalineGainUntil or 0) then
			local adrenalineGain = math.Clamp(damage * 0.01, 0.1, 0.15)
			attackerOrg.adrenalineAdd = math.min((attackerOrg.adrenalineAdd or 0) + adrenalineGain, 1.5)
		end
	end
end

-- Function to open door faster and restore original speed
local function OpenDoorFaster(door)
    if not IsValid(door) then return end
    
    -- Play door breaking sounds for normal kicks
    sound.Play("Wood_Crate.Break", door:GetPos(), 60, 100)
    sound.Play("Wood_Furniture.Break", door:GetPos(), 60, 100)
    
    -- Set faster speed temporarily
    door:SetKeyValue("speed", "400")
    door:Fire("toggle", "", 0)
    
    -- Restore original speed after 2 seconds
    timer.Simple(2, function()
        if IsValid(door) then
            door:SetKeyValue("speed", "100") -- Default door speed
        end
    end)
end

-- Function to apply bleeding and random dislocation to ragdoll
local function ApplyInjuriesToRagdoll(ragdoll)
    local owner = hg.RagdollOwner(ragdoll)
    if not IsValid(owner) or not owner.organism then return end
    
    -- Add bleeding (15-25 points)
    owner.organism.bleed = (owner.organism.bleed or 0) + math.random(15, 25)
    
    -- Apply random dislocation (leg, arm, or jaw) only if none already present
    local dislocations = {
        "llegdislocation",
        "rlegdislocation",
        "larmdislocation",
        "rarmdislocation",
        "jawdislocation"
    }
    
    local hasDislocation = false
    for _, key in ipairs(dislocations) do
        if owner.organism[key] then
            hasDislocation = true
            break
        end
    end
    
    if not hasDislocation then
        local randomDislocation = dislocations[math.random(1, #dislocations)]
        owner.organism[randomDislocation] = true
    end
    
    -- Debug output
    if GetConVar("developer"):GetInt() == 1 then
        print(string.format("[DOOR BREAK] %s suffered %d bleeding from door impact", 
            owner:GetName(), 
            owner.organism.bleed or 0))
    end
end

-- Main kick damage handler
hook.Add("Ragdoll Collide", "RagdollKickDamage", function(ragdoll, data)
    if ragdoll == data.HitEntity then return end
    if data.DeltaTime < 0.25 then return end
    if not ragdoll:IsRagdoll() then return end
    if not IsValid(data.HitEntity) then return end
    if data.HitEntity:IsPlayerHolding() then return end

    local attacker = hg.RagdollOwner(ragdoll)

    -- Door handling with two different behaviors
    if hgIsDoor(data.HitEntity) then
        local impactDamage = math.max((data.Speed - 180) / 12, 6)
        if hgDamageDoor(data.HitEntity, impactDamage, data.HitNormal, attacker) then
            ApplyInjuriesToRagdoll(ragdoll)
            return
        end

        if data.Speed > 560 then
            -- High-speed impact: Break door + bleeding + dislocation
            -- Play fire axe door breaking sounds
            sound.Play("Wood_Crate.Break", data.HitEntity:GetPos(), 60, 100)
            sound.Play("Wood_Furniture.Break", data.HitEntity:GetPos(), 60, 100)
            hgBlastThatDoor(data.HitEntity, data.HitNormal * 200)
            ApplyInjuriesToRagdoll(ragdoll)
        elseif data.Speed > 320 then
            -- A weaker locked-door impact can still breach, with the chance rising toward the full-force threshold.
            local locked = data.HitEntity:GetInternalVariable("m_bLocked")
            local breachChance

            if IsRagdollDropkick(ragdoll, data) then
                -- A committed ragdoll dropkick is more likely to force a locked door than a regular kick.
                breachChance = math.Clamp(0.45 + (data.Speed - DROP_KICK_SPEED_THRESHOLD) / 1000, 0.45, 0.6)
            else
                breachChance = math.Clamp((data.Speed - 320) / 800, 0.03, 0.3)
            end

            if locked and math.Rand(0, 1) <= breachChance then
                hgBlastThatDoor(data.HitEntity, data.HitNormal * 200)
                ApplyInjuriesToRagdoll(ragdoll)
            else
                OpenDoorFaster(data.HitEntity)
            end
        end
        return
    end

    -- Get the ragdoll owner for kick damage
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    
    local target = data.HitEntity
    
    -- Only process if we hit something that can take damage
    if not CanTakeKickDamage(target) then return end
    
    -- Don't damage yourself
    local targetPlayer = hg.RagdollOwner(target) or target
    if attacker == targetPlayer then return end
    
    -- Find which physics bone hit
    local physBone = nil
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if phys == data.PhysObject then
            physBone = i
            break
        end
    end
    
    if not physBone then return end
    
    -- Check if it's a kick bone
    local boneName = GetBoneNameFromPhysBone(ragdoll, physBone)
    if not boneName or not KICK_BONES[boneName] then return end
    
    -- Calculate the distinct shove, dropkick, or tackle response for this impact.
    local speed = data.OurOldVelocity:Length()
    local damage, impactForce, knockback, impactType = CalculateImpact(boneName, speed)
    
    if damage <= 0 then return end
    
    -- Check if kick damage is on cooldown for this attacker-target pair
    if IsKickOnCooldown(attacker, target) then return end
    
    -- Calculate force direction and magnitude
    local forceDir = data.OurOldVelocity:GetNormalized()
    local force = forceDir * impactForce
    
    -- Apply the damage
    ApplyKickDamage(attacker, target, damage, data.HitPos, force, boneName, knockback)

    if impactType == "dropkick" then
        local attackerOrg = attacker.organism
        if attackerOrg and (attackerOrg._ragdollDropkickStaminaUntil or 0) < CurTime() then
            attackerOrg._ragdollDropkickStaminaUntil = CurTime() + 0.75
            attackerOrg.stamina.subadd = (attackerOrg.stamina.subadd or 0) + DROP_KICK_STAMINA_COST

            if attackerOrg.lleg == 1 or attackerOrg.rleg == 1 or attackerOrg.llegdislocation or attackerOrg.rlegdislocation then
                attackerOrg.painadd = (attackerOrg.painadd or 0) + 35
            end
        end

        local targetPlayer = hg.RagdollOwner(target) or target
        if IsValid(targetPlayer) and targetPlayer:IsPlayer() and targetPlayer:Alive() then
            timer.Simple(0, function()
                if IsValid(targetPlayer) and targetPlayer:Alive() then
                    hg.Fake(targetPlayer)
                end
            end)
        end
    elseif impactType == "leg shove" then
        local targetPlayer = hg.RagdollOwner(target) or target
        local ragdollChance = math.Clamp(0.08 + (speed - LEG_SHOVE_SPEED_THRESHOLD) / 900, 0.08, 0.18)
        if IsValid(targetPlayer) and targetPlayer:IsPlayer() and targetPlayer:Alive() and math.Rand(0, 1) <= ragdollChance then
            timer.Simple(0, function()
                if IsValid(targetPlayer) and targetPlayer:Alive() then
                    hg.Fake(targetPlayer)
                end
            end)
        end
    end
    
    -- Record this hit to prevent rapid successive hits
    RecordKickHit(attacker, target)
    
    -- Debug output for developers
    if GetConVar("developer"):GetInt() == 1 then
        local targetPlayer = hg.RagdollOwner(target) or target
        print(string.format("[KICK DAMAGE] %s landed a %s on %s with %s for %.1f damage (speed: %.1f)",
            attacker:GetName(), 
            impactType,
            targetPlayer:GetName(), 
            boneName, 
            damage, 
            speed))
    end
end)

-- Periodic cleanup of hit tracker to prevent memory leaks
timer.Create("KickDamageCleanup", KICK_DAMAGE_COOLDOWN * 2, 0, function()
    CleanupHitTracker()
end)

print("[RAGDOLL KICK DAMAGE] System loaded successfully with simplified door kicking")
