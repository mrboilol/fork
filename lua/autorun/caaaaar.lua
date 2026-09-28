local TEMP_MASS_SCALE = 0.25
local MASS_RESTORE_TIME = 1.0

CreateConVar(
    "ragdoll_car_collision_enabled",
    "1",
    FCVAR_ARCHIVE,
    "Enable/Disable Ragdoll Car Collision"
)

if SERVER then

    local function StoreOriginalMass(ragdoll)
        ragdoll._OriginalMass = ragdoll._OriginalMass or {}

        local count = ragdoll:GetPhysicsObjectCount()
        for i = 0, count - 1 do
            local phys = ragdoll:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                ragdoll._OriginalMass[i] = phys:GetMass()
            end
        end
    end

    local function ApplyTemporaryMass(ragdoll)
        if not IsValid(ragdoll) then return end
        if not ragdoll._OriginalMass then return end
        if ragdoll._MassModified then return end

        ragdoll._MassModified = true

        for i, mass in pairs(ragdoll._OriginalMass) do
            local phys = ragdoll:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:SetMass(math.max(mass * TEMP_MASS_SCALE, 5))
                phys:Wake()
            end
        end
    end

    local function RestoreMass(ragdoll)
        if not IsValid(ragdoll) then return end
        if not ragdoll._OriginalMass then return end

        for i, mass in pairs(ragdoll._OriginalMass) do
            local phys = ragdoll:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:SetMass(mass)
                phys:Wake()
            end
        end

        ragdoll._MassModified = false
    end

    hook.Add("OnEntityCreated", "RagdollVehicleCollision_Setup", function(ent)
        if not GetConVar("ragdoll_car_collision_enabled"):GetBool() then return end
        if ent:GetClass() ~= "prop_ragdoll" then return end

        timer.Simple(0, function()
            if not IsValid(ent) then return end
            ent:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
            StoreOriginalMass(ent)
        end)
    end)

    hook.Add("EntityTakeDamage", "RagdollVehicleCollision_TempMass", function(target, dmginfo)
        if not GetConVar("ragdoll_car_collision_enabled"):GetBool() then return end
        if not IsValid(target) or target:GetClass() ~= "prop_ragdoll" then return end

        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsVehicle() then
            ApplyTemporaryMass(target)

            timer.Simple(MASS_RESTORE_TIME, function()
                if IsValid(target) then
                    RestoreMass(target)
                end
            end)
        end
    end)

end

if CLIENT then
    hook.Add("PopulateToolMenu", "RagdollCarCollision_Menu", function()
        spawnmenu.AddToolMenuOption(
            "Utilities",
            "User",
            "EpicVehicleCollisionFix",
            "Epic Vehicle Collision Fix",
            "",
            "",
            function(panel)
                panel:CheckBox("Enable Epic Collisions", "ragdoll_car_collision_enabled")
            end
        )
    end)
end