if SERVER then
    resource.AddFile("resource/fonts/arnopro.ttf")

    local depressionThreshold = 0.5

    local function isDepressionBlocking(ply)
        local cvar = GetConVar("hg_depression")
        if not cvar or not cvar:GetBool() then return false end
        if ply.remUrgeEnd then return false end

        return not ply.organism or (ply.organism.depression or 0) < depressionThreshold
    end

    local function stopSuicide(ply)
        ply.suiciding = false
        ply.startsuicide = nil
        ply:SetNWBool("suiciding", false)
    end

    concommand.Add("suicide", function(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if ply.organism and (ply.organism.incapacitated or (not hg.organism.IncapacitationEnabled() and ply.organism.otrub)) then
            ply.organism.deathStateKilled = true
            ply:Kill()
            return
        end
        if ply.StartHeadcrabRemovalAttempt and ply:StartHeadcrabRemovalAttempt() then return end
        if ply:GetNWFloat("rem_urges_end", 0) > CurTime() or ply.remUrgeEnd then return end

        if ply.suiciding then
            stopSuicide(ply)
            return
        end

        if not hg.CanSuicide(ply) then return end
        if isDepressionBlocking(ply) then return end

        ply.suiciding = true
        ply:SetNWBool("suiciding", true)
        ply.startsuicide = CurTime() - 2
    end)

    hook.Add("Player Think", "HG_SuicideDepressionStop", function(ply)
        if ply.suiciding and ply:Alive() and isDepressionBlocking(ply) then
            stopSuicide(ply)
        end
    end)

    hook.Add("PlayerDeath", "HG_ResetSuicide", function(ply)
        stopSuicide(ply)
    end)

    hook.Add("PlayerSpawn", "HG_ResetSuicideSpawn", function(ply)
        stopSuicide(ply)
    end)
end
