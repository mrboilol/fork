if SERVER then

    util.AddNetworkString("ServerRagdollTransferDecals")

    hook.Add("CreateEntityRagdoll", "ServerRagdollTransferDecals", function(ent, rag)
        net.Start("ServerRagdollTransferDecals")
        net.WriteEntity(rag)
        net.WriteEntity(ent)
        net.Broadcast()
    end)

end

if CLIENT then

    local SEARCH_RADIUS = 150
    local SEARCH_BOX = Vector(SEARCH_RADIUS, SEARCH_RADIUS, SEARCH_RADIUS)
    local pending = {}

    local CORPSE_CLASSES = {
        ["prop_ragdoll"] = true,
        ["prop_dynamic"] = true,
        ["prop_physics"] = true,
        ["prop_vj_animatable"] = true
    }

    local function IsTrackedNPC(ent)
        if not IsValid(ent) then return false end
        return ent:GetShouldServerRagdoll()
            or ent:GetNWBool("IsZBaseNPC", false)
            or ent.IsVJBaseSNPC == true
            or ent.IsDrGNextbot == true
    end

    local function IsCorpseEntity(ent)
        if not IsValid(ent) then return false end

        local class = ent:GetClass()
        if CORPSE_CLASSES[class] then return true end
        if ent.IsVJBaseCorpse or ent.IsDrGCorpse or string.find(class, "corpse") then return true end

        return false
    end

    local function TrySnatch(fromEnt, pos, mdl, rag)
        if not IsValid(fromEnt) or not IsValid(rag) then return false end
        if rag.DecalTransferDone then return false end
        if not IsCorpseEntity(rag) then return false end
        if rag:GetModel() ~= mdl then return false end
        if rag:GetPos():DistToSqr(pos) > SEARCH_RADIUS * SEARCH_RADIUS then return false end

        rag:SnatchModelInstance(fromEnt)
        rag.DecalTransferDone = true
        return true
    end

    local cleaningUp = false

    hook.Add("PreCleanupMap", "ServerRagdollTransferDecals", function()
        cleaningUp = true
        table.Empty(pending)
    end)

    hook.Add("PostCleanupMap", "ServerRagdollTransferDecals", function()
        cleaningUp = false
    end)

    hook.Add("EntityRemoved", "ServerRagdollTransferDecals", function(ent, fullUpdate)
        if cleaningUp or fullUpdate then return end
        if not IsTrackedNPC(ent) then return end

        local mdl = ent:GetModel()
        if not mdl then return end

        local pos = ent:GetPos()

        for _, rag in ipairs(ents.FindInBox(pos - SEARCH_BOX, pos + SEARCH_BOX)) do
            if TrySnatch(ent, pos, mdl, rag) then return end
        end

        local rescue = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
        if not IsValid(rescue) then return end
        rescue:SetNoDraw(true)
        rescue:SnatchModelInstance(ent)

        pending[#pending + 1] = { copy = rescue, pos = pos, model = mdl, time = CurTime() }
    end)

    hook.Add("OnEntityCreated", "ServerRagdollTransferDecals", function(ent)
        if not IsCorpseEntity(ent) then return end

        local tries = 0
        local function Attempt()
            if not IsValid(ent) then return end
            if ent.DecalTransferDone then return end

            local matched = false
            for i = #pending, 1, -1 do
                local p = pending[i]
                if not IsValid(p.copy) then
                    table.remove(pending, i)
                elseif TrySnatch(p.copy, p.pos, p.model, ent) then
                    if IsValid(p.copy) then p.copy:Remove() end
                    table.remove(pending, i)
                    matched = true
                    break
                end
            end
            if matched then return end

            tries = tries + 1
            if tries < 20 then
                timer.Simple(0, Attempt)
            end
        end
        Attempt()
    end)

    timer.Create("ServerRagdollTransferDecals_Sweep", 0.25, 0, function()
        local now = CurTime()

        for i = #pending, 1, -1 do
            local p = pending[i]

            if not IsValid(p.copy) then
                table.remove(pending, i)
            elseif now - p.time > 15 then
                p.copy:Remove()
                table.remove(pending, i)
            else
                for _, rag in ipairs(ents.FindInBox(p.pos - SEARCH_BOX, p.pos + SEARCH_BOX)) do
                    if TrySnatch(p.copy, p.pos, p.model, rag) then
                        if IsValid(p.copy) then p.copy:Remove() end
                        table.remove(pending, i)
                        break
                    end
                end
            end
        end
    end)

    net.Receive("ServerRagdollTransferDecals", function()
        local rag = net.ReadEntity()
        local ent = net.ReadEntity()

        if IsValid(ent) and IsValid(rag) and not rag.DecalTransferDone then
            rag:SnatchModelInstance(ent)
            rag.DecalTransferDone = true
        end
    end)

end