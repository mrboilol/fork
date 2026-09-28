if SERVER then
    util.AddNetworkString("PhysgunImpact_UpdateSettings")

    if not ConVarExists("physgunimpact_cooldown") then
        CreateConVar("physgunimpact_cooldown", "0.05", {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    end
    if not ConVarExists("physgunimpact_multiplier") then
        CreateConVar("physgunimpact_multiplier", "0.01", {FCVAR_ARCHIVE, FCVAR_REPLICATED}) 
    end
    if not ConVarExists("physgunimpact_speed") then
        CreateConVar("physgunimpact_speed", "300", {FCVAR_ARCHIVE, FCVAR_REPLICATED}) 
    end

    local heldEntities = {}

    local cooldownTime = GetConVar("physgunimpact_cooldown"):GetFloat()
    local damageMultiplier = GetConVar("physgunimpact_multiplier"):GetFloat()
    local speedThreshold = GetConVar("physgunimpact_speed"):GetInt()

    local lastDamage = {}

    net.Receive("PhysgunImpact_UpdateSettings", function(len, ply)
        if not ply:IsAdmin() then return end

        local newCooldown = net.ReadFloat()
        local newMultiplier = net.ReadFloat()
        local newSpeed = net.ReadFloat()

        if newCooldown >= 0.05 and newCooldown <= 5 then
            cooldownTime = math.Round(newCooldown, 2) 
            GetConVar("physgunimpact_cooldown"):SetFloat(cooldownTime)
        end

        if newMultiplier >= 1 and newMultiplier <= 2 then 
            damageMultiplier = math.Round(newMultiplier, 1) 
            GetConVar("physgunimpact_multiplier"):SetFloat(damageMultiplier)
        end

        if newSpeed >= 100 and newSpeed <= 25000 then
            speedThreshold = math.floor(newSpeed)
            GetConVar("physgunimpact_speed"):SetInt(speedThreshold)
        end
    end)

    hook.Add("PhysgunPickup", "PhysgunImpact_SaveHeld", function(ply, ent)
        heldEntities[ply] = ent
    end)

    hook.Add("PhysgunDrop", "PhysgunImpact_ClearHeld", function(ply, ent)
        heldEntities[ply] = nil
    end)

    hook.Add("Think", "PhysgunImpact_ApplyDamage", function()
        for ply, heldEnt in pairs(heldEntities) do
            if not (IsValid(ply) and ply:Alive() and IsValid(heldEnt)) then
                heldEntities[ply] = nil
                continue
            end

            local physObj = heldEnt:GetPhysicsObject()
            if not IsValid(physObj) then continue end

            local speed = physObj:GetVelocity():Length()

            if speed > speedThreshold then
                local boxMin = heldEnt:LocalToWorld(heldEnt:OBBMins())
                local boxMax = heldEnt:LocalToWorld(heldEnt:OBBMaxs())
                local nearEnts = ents.FindInBox(boxMin, boxMax)

                for _, ent in ipairs(nearEnts) do
                    if ent == heldEnt or ent == ply then continue end
                    if not (ent:IsNPC() or ent:IsPlayer()) then continue end
                    if ent:Health() <= 0 then continue end
                    
                    if ent:IsPlayer() and ent:GetMoveType() == MOVETYPE_NOCLIP then continue end

                    local now = CurTime()
                    if not lastDamage[ent] or (now - lastDamage[ent]) > cooldownTime then
                        local dmgAmount = math.Clamp(speed * damageMultiplier, 5, 1000) 
                        local dmgInfo = DamageInfo()
                        dmgInfo:SetDamage(dmgAmount)
                        dmgInfo:SetDamageType(DMG_CRUSH)
                        dmgInfo:SetAttacker(ply)
                        dmgInfo:SetInflictor(heldEnt)
                        dmgInfo:SetDamagePosition(ent:GetPos())
                        ent:TakeDamageInfo(dmgInfo)
                        lastDamage[ent] = now
                    end
                end
            end
        end
    end)
end

if CLIENT then
    local cooldownSlider, multiplierSlider, speedSlider

    local function SendSettings()
        net.Start("PhysgunImpact_UpdateSettings")
        net.WriteFloat(cooldownSlider:GetValue())
        net.WriteFloat(multiplierSlider:GetValue())
        net.WriteFloat(speedSlider:GetValue())
        net.SendToServer()
    end

    hook.Add("PopulateToolMenu", "PhysgunImpact_Menu", function()
        spawnmenu.AddToolMenuOption("Utilities", "Physgun Impact", "Settings", "Settings", "", "", function(panel)
            panel:ClearControls()
            
            cooldownSlider = panel:NumSlider("Cooldown Time (sec)", "physgunimpact_cooldown", 0.05, 5, 2)  
            multiplierSlider = panel:NumSlider("Damage Multiplier", "physgunimpact_multiplier", 1, 2, 1) 
            speedSlider = panel:NumSlider("Speed Threshold", "physgunimpact_speed", 100, 25000, 0)       

            cooldownSlider.OnValueChanged = function()
                SendSettings()
            end
            multiplierSlider.OnValueChanged = function()
                SendSettings()
            end
            speedSlider.OnValueChanged = function()
                SendSettings()
            end
        end)
    end)

    local cooldownTime = GetConVar("physgunimpact_cooldown"):GetFloat()
    local damageMultiplier = GetConVar("physgunimpact_multiplier"):GetFloat()
    local speedThreshold = GetConVar("physgunimpact_speed"):GetInt()

    cvars.AddChangeCallback("physgunimpact_cooldown", function(_, _, newVal)
        cooldownTime = tonumber(newVal) or cooldownTime
        SendSettings()
    end)

    cvars.AddChangeCallback("physgunimpact_multiplier", function(_, _, newVal)
        damageMultiplier = tonumber(newVal) or damageMultiplier
        SendSettings()
    end)

    cvars.AddChangeCallback("physgunimpact_speed", function(_, _, newVal)
        speedThreshold = tonumber(newVal) or speedThreshold
        SendSettings()
    end)
end
