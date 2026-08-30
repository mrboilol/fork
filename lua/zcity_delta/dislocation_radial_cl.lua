if SERVER then return end

hook.Add("radialOptions", "zcity_delta_dislocation_minigame", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or not ply.organism or ply.organism.otrub then return end
    if not hg or not hg.radialOptions then return end

    if (ply.tried_fixing_limb or 0) > CurTime() then return end

    local function AddOption(label, group, target)
        hg.radialOptions[#hg.radialOptions + 1] = {
            function()
                ply.tried_fixing_limb = CurTime() + 0.5
                if IsValid(target) then
                    RunConsoleCommand("hg_med_dislocation", tostring(group), tostring(target:EntIndex()))
                else
                    RunConsoleCommand("hg_med_dislocation", tostring(group))
                end
            end,
            label
        }
    end

    local function HasDislocation(ent, group)
        if not IsValid(ent) then return false end
        local eorg = ent.new_organism or ent.organism
        if not eorg then return false end
        if group == 1 then return eorg.llegdislocation or eorg.rlegdislocation end
        if group == 2 then return eorg.larmdislocation or eorg.rarmdislocation end
        if group == 3 then return eorg.jawdislocation end
        return false
    end

    local trace = hg.eyeTrace(ply)
    local target = trace and trace.Entity
    if IsValid(target) and target:IsRagdoll() and hg.RagdollOwner then
        target = hg.RagdollOwner(target) or target
    end

    if HasDislocation(ply, 1) then
        AddOption("Fix dislocation (leg)", 1)
    elseif IsValid(target) and target:IsPlayer() and HasDislocation(target, 1) then
        AddOption("Fix " .. target:GetPlayerName() .. "'s dislocation (leg)", 1, target)
    end

    if HasDislocation(ply, 2) then
        AddOption("Fix dislocation (arm)", 2)
    elseif IsValid(target) and target:IsPlayer() and HasDislocation(target, 2) then
        AddOption("Fix " .. target:GetPlayerName() .. "'s dislocation (arm)", 2, target)
    end

    if HasDislocation(ply, 3) then
        AddOption("Fix dislocation (jaw)", 3)
    elseif IsValid(target) and target:IsPlayer() and HasDislocation(target, 3) then
        AddOption("Fix " .. target:GetPlayerName() .. "'s dislocation (jaw)", 3, target)
    end
end)
