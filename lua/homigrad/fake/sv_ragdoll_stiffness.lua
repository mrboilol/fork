local RagdollStiffness = {}

-- Ensure the toggle ConVar exists so the check below is always safe.
CreateConVar("ar_enableStiffness", "1", FCVAR_ARCHIVE, "Enable ragdoll stiffness reactions", 0, 1)

local FORCE_LIMIT = 350
local TORQUE_LIMIT = 380
local DEFAULT_FRICTION = 0.15
local CONSTRAINT_LIFETIME = 10

local RAMP_UP_TIME = 0.4
local RAMP_DOWN_TIME = 0.6

local ParentBones = {
    [0]  = { parent = nil,  offset = Vector(0, 0, 0) },
    [1]  = { parent = 0,    offset = Vector(5, 0, 0) },
    [2]  = { parent = 1,    offset = Vector(8, 0, 0) },
    [3]  = { parent = 1,    offset = Vector(-8, 0, 0) },
    [4]  = { parent = 3,    offset = Vector(0, 0, -10) },
    [5]  = { parent = 4,    offset = Vector(0, 0, -10) },
    [6]  = { parent = 2,    offset = Vector(0, 0, -10) },
    [7]  = { parent = 6,    offset = Vector(0, 0, -10) },
    [8]  = { parent = 0,    offset = Vector(0, 0, -10) },
    [9]  = { parent = 8,    offset = Vector(0, 0, -10) },
    [10] = { parent = 1,    offset = Vector(0, 0, 0) },
    [11] = { parent = 0,    offset = Vector(0, 0, 0) },
    [12] = { parent = 11,   offset = Vector(0, 0, -10) },
    [13] = { parent = 0,    offset = Vector(0, 0, 0) },
    [14] = { parent = 9,    offset = Vector(0, 0, 0) }
}

local STIFF_HEADSHOT = { 0, 1, 2, 3, 9, 12 }
local STIFF_BALANCE  = { 0, 1, 10, 9, 12, 13, 14 }
local STIFF_ALLBODY  = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 }

local activeStiffness = {}

local function CreateConstraint(pos, phys1, phys2, dieTime, ragdoll, targetFriction)
    if not IsValid(phys1) or not IsValid(phys2) then return end

    local constraintEnt = ents.Create("phys_hinge")
    if not IsValid(constraintEnt) then return end

    local startFriction = 0.01

    constraintEnt:SetPos(pos)
    constraintEnt:SetKeyValue("hingeaxis", tostring(VectorRand():GetNormalized()))
    constraintEnt:SetKeyValue("forcelimit", FORCE_LIMIT)
    constraintEnt:SetKeyValue("torquelimit", TORQUE_LIMIT)
    constraintEnt:SetKeyValue("hingefriction", startFriction)
    constraintEnt:SetKeyValue("spawnflags", 1)
    constraintEnt:SetPhysConstraintObjects(phys1, phys2)
    constraintEnt:Spawn()
    constraintEnt:Activate()

    constraint.AddConstraintTable(ragdoll, constraintEnt)

    constraintEnt.StiffData = {
        startTime = CurTime(),
        endTime = CurTime() + (dieTime or CONSTRAINT_LIFETIME),
        targetFriction = targetFriction or DEFAULT_FRICTION,
        currentFriction = startFriction,
        rampUpComplete = false
    }

    return constraintEnt
end

local function UpdateStiffnessRamping(ragdoll)
    if not IsValid(ragdoll) then return end

    local ragIndex = ragdoll:EntIndex()
    local stiffData = activeStiffness[ragIndex]
    if not stiffData or not stiffData.constraints then return end

    local curTime = CurTime()
    local anyActive = false

    for i = #stiffData.constraints, 1, -1 do
        local constraintEnt = stiffData.constraints[i]
        if not IsValid(constraintEnt) or not constraintEnt.StiffData then
            table.remove(stiffData.constraints, i)
        else
            anyActive = true
            local data = constraintEnt.StiffData
            local elapsed = curTime - data.startTime
            local timeUntilEnd = data.endTime - curTime
            local newFriction = data.currentFriction

            if not data.rampUpComplete then
                if elapsed < RAMP_UP_TIME then
                    local progress = elapsed / RAMP_UP_TIME
                    progress = 1 - (1 - progress) ^ 3
                    newFriction = Lerp(progress, 0.01, data.targetFriction)
                else
                    newFriction = data.targetFriction
                    data.rampUpComplete = true
                end
            elseif timeUntilEnd < RAMP_DOWN_TIME then
                local progress = timeUntilEnd / RAMP_DOWN_TIME
                progress = progress ^ 2
                newFriction = Lerp(progress, 0.01, data.targetFriction)
            end

            if math.abs(newFriction - data.currentFriction) > 0.01 then
                data.currentFriction = newFriction
                constraintEnt:Fire("SetHingeFriction", tostring(newFriction), 0)
            end
        end
    end

    if not anyActive then
        activeStiffness[ragIndex] = nil
    end
end

local function BuildStiffBones(ragdoll, boneSet, dieTime, friction)
    if not IsValid(ragdoll) then return end
    local cvar = GetConVar("ar_enableStiffness")
    if cvar and cvar:GetBool() == false then return end

    local ragIndex = ragdoll:EntIndex()
    if not activeStiffness[ragIndex] then
        activeStiffness[ragIndex] = { constraints = {}, thinkHook = "HG_RagdollStiffness_" .. ragIndex }
        hook.Add("Think", activeStiffness[ragIndex].thinkHook, function()
            UpdateStiffnessRamping(ragdoll)
        end)
    end

    local stiffData = activeStiffness[ragIndex]

    for _, id in ipairs(boneSet) do
        local info = ParentBones[id]
        if info and info.parent ~= nil then
            local phys1 = ragdoll:GetPhysicsObjectNum(id)
            local phys2 = ragdoll:GetPhysicsObjectNum(info.parent)
            if IsValid(phys1) and IsValid(phys2) then
                local localOffset = info.offset or vector_origin
                local worldPos = phys2:LocalToWorld(localOffset)
                local constraintEnt = CreateConstraint(worldPos, phys1, phys2, dieTime, ragdoll, friction)
                if IsValid(constraintEnt) then
                    table.insert(stiffData.constraints, constraintEnt)
                    constraintEnt:CallOnRemove("HG_Cleanup_Stiff_" .. ragIndex, function()
                        if activeStiffness[ragIndex] then
                            table.RemoveByValue(activeStiffness[ragIndex].constraints, constraintEnt)
                            if #activeStiffness[ragIndex].constraints == 0 then
                                hook.Remove("Think", activeStiffness[ragIndex].thinkHook)
                                activeStiffness[ragIndex] = nil
                            end
                        end
                    end)
                end
            end
        end
    end

    timer.Simple(dieTime or CONSTRAINT_LIFETIME, function()
        if IsValid(ragdoll) and activeStiffness[ragIndex] then
            for _, constraintEnt in ipairs(activeStiffness[ragIndex].constraints) do
                if IsValid(constraintEnt) then
                    SafeRemoveEntity(constraintEnt)
                end
            end
        end
    end)
end

function RagdollStiffness.ActivateAllBody(ragdoll, dieTime)
    BuildStiffBones(ragdoll, STIFF_ALLBODY, dieTime, math.Rand(0.2, 0.4))
end

function RagdollStiffness.ActivateHeadshot(ragdoll, dieTime)
    BuildStiffBones(ragdoll, STIFF_HEADSHOT, dieTime, math.Rand(0.4, 0.7))
end

function RagdollStiffness.ActivateBalancing(ragdoll, dieTime)
    BuildStiffBones(ragdoll, STIFF_BALANCE, dieTime, 0.75)
end

hook.Add("EntityRemoved", "HG_RagdollStiffness_Cleanup", function(ent)
    local ragIndex = ent:EntIndex()
    if activeStiffness[ragIndex] then
        hook.Remove("Think", activeStiffness[ragIndex].thinkHook)
        activeStiffness[ragIndex] = nil
    end
end)

return RagdollStiffness
