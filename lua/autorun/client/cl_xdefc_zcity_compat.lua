if not CLIENT then return end

-- ragdoll sync
local function getZCityRag(ply)
    local rag = ply:GetNWEntity("RagdollDeath", NULL)
    if IsValid(rag) then return rag, true end

    rag = ply:GetNWEntity("FakeRagdoll", NULL)
    if IsValid(rag) then return rag, false end

    return nil, false
end

hook.Add("Think", "xdefc_zcity_rag_sync", function()
    if not istable(xdefc) or not istable(xdefc.main) then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:GetNWBool("XDEFC_Enabled") then continue end

        local zcRag, isDead = getZCityRag(ply)

        if IsValid(zcRag) then
            if ply.xdefc_rag ~= zcRag then
                if IsValid(ply.xdefc_rag) then
                    ply.xdefc_rag.xdefc_ply = nil
                end

                ply.xdefc_rag = zcRag
                zcRag.xdefc_ply = ply
                
                if isDead then
                    ply.xdefc_dead_zc = CurTime() + (xdefc.main.eventEnabled(ply, "Dying") and 2 or 0.5) 
                else
                    ply.xdefc_dead_zc = nil
                end
            end

            -- continuously refresh face to prevent freezing
            xdefc.main.setupFace(ply)

            if ply.xdefc_dead_zc then
                if xdefc.main.eventEnabled(ply, "Dying") then
                    local le1 = 1 - math.Clamp((ply.xdefc_dead_zc - CurTime() - 1.75) / 0.25, 0, 1)
                    local le2 = math.Clamp((CurTime() - ply.xdefc_dead_zc + 1) / 2, 0, 1)
                    xdefc.main.eventTrigger(ply, "Dying", le1 * (1 - le2), 0.25)
                    xdefc.main.eventTrigger(ply, "Dead", le1 * le2, 0.25)
                else
                    local le2 = math.Clamp((CurTime() - ply.xdefc_dead_zc + 0.5) / 0.5, 0, 1)
                    xdefc.main.eventTrigger(ply, "Dead", le2, 0.25)
                end
            end

        else
            -- cleanup when player stops ragdolling
            if IsValid(ply.xdefc_rag) and ply.xdefc_rag.xdefc_ply == ply then
                ply.xdefc_rag.xdefc_ply = nil
            end
            ply.xdefc_rag = nil
            ply.xdefc_dead_zc = nil
        end
    end
end)

-- apply flexes and bodygroups to ragdoll
hook.Add("PreDrawOpaqueRenderables", "xdefc_zcity_rag_flex", function()
    if not istable(xdefc) or not istable(xdefc.main) then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:GetNWBool("XDEFC_Enabled") then continue end

        local rag = ply.xdefc_rag
        if not IsValid(rag) or rag.xdefc_ply ~= ply then continue end

        if ply.xdefc_scale_f then
            rag:SetFlexScale(ply.xdefc_scale_f * 1.05)
        end

        if ply.xdefc_flexes_f then
            for k, v in pairs(ply.xdefc_flexes_f) do
                rag:SetFlexWeight(k, v)
            end
        end

        -- sync expression bodygroups to the ragdoll
        if ply.xdefc_groups then
            for _, v in ipairs(rag:GetBodyGroups()) do
                if v.submodels and #v.submodels > 0 and isnumber(ply.xdefc_groups[v.id]) then
                    rag:SetBodygroup(v.id, ply.xdefc_groups[v.id])
                end
            end
        end
    end
end)

hook.Add("PlayerSpawn", "xdefc_zcity_cleanup", function(ply)
    if not IsValid(ply) then return end

    if IsValid(ply.xdefc_rag) then
        ply.xdefc_rag.xdefc_ply = nil
    end

    ply.xdefc_rag = nil
    ply.xdefc_dead_zc = nil
end)

-- network stuff

-- hurt
net.Receive("xdefc_zcity_hurtexpression", function()
    local ply = net.ReadEntity()
    if not IsValid(ply) then return end
    if not xdefc or not xdefc.main then return end

    xdefc.main.eventTrigger(ply, "Hurt", 1, 0.5)
end)

-- reload
net.Receive("xdefc_zcity_reloadexpression", function()
    local ply = net.ReadEntity()
    local reloadTime = net.ReadFloat()

    if not IsValid(ply) then return end
    if not xdefc or not xdefc.main then return end

    xdefc.main.eventTrigger(ply, "Reload", 1, reloadTime)
end)

-- attack
net.Receive("xdefc_zcity_attack", function()
    local ply = net.ReadEntity()
    if not IsValid(ply) then return end
    if not xdefc or not xdefc.main then return end

    xdefc.main.eventTrigger(ply, "Attack", 1, 0.25)
end)

