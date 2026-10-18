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

    local function isParalyzedOrDying(org)
        if not org then return false end
        local cfg = hg.organism or {}
        local ecg = org.ecgState
        return org.paralyzed or org.cervicalParalysis
            or (tonumber(org.spine1) or 0) >= (cfg.fake_spine1 or 1)
            or (tonumber(org.spine2) or 0) >= (cfg.fake_spine2 or 1)
            or (tonumber(org.spine3) or 0) >= (cfg.fake_spine3 or 0.75)
            or org.critical == true or org.heartstop
            or ecg == "asystole" or ecg == "pea" or ecg == "ventricular_fibrillation" or org.fibrillation == true
            or (tonumber(org.systolic) or 999) < 75
            or (tonumber(org.bloodPressure) or 999) < 50
            or (tonumber(org.cardiacOutput) or 999) < 0.3
            or (tonumber(org.strokeVolume) or 999) < 0.25
            or (tonumber(org.cardiacTamponade) or 0) > 0.55
            or (tonumber(org.brain) or 0) > 0.4
            or (tonumber(org.brainHemorrhage) or 0) >= 0.4
            or (tonumber(org.brainSwelling) or 0) >= 0.45
    end

    concommand.Add("suicide", function(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if ply.organism and (ply.organism.incapacitated or (not hg.organism.IncapacitationEnabled() and ply.organism.otrub) or isParalyzedOrDying(ply.organism)) then
            ply.organism.deathStateKilled = true
            ply:Kill()
            return
        end
        if ply.StartHeadcrabRemovalAttempt and ply:StartHeadcrabRemovalAttempt() then return end
        if ply:GetNWFloat("rem_urges_end", 0) > CurTime() or ply.remUrgeEnd then return end

        if hg.WallBang.Active(ply) then
            hg.WallBang.Stop(ply)
            return
        end

        if ply.suiciding then
            stopSuicide(ply)
            return
        end

        if isDepressionBlocking(ply) then return end
        if not hg.CanSuicide(ply) then
            hg.WallBang.Start(ply)
            return
        end

        ply.suiciding = true
        ply:SetNWBool("suiciding", true)
        ply.startsuicide = CurTime() - 2
    end)

    hook.Add("Player Think", "HG_SuicideDepressionStop", function(ply)
        if ply.suiciding and ply:Alive() and isDepressionBlocking(ply) then
            stopSuicide(ply)
        end
        if hg.WallBang.Active(ply) and isDepressionBlocking(ply) then
            hg.WallBang.Stop(ply)
        end
    end)

    hook.Add("PlayerDeath", "HG_ResetSuicide", function(ply)
        stopSuicide(ply)
    end)

    hook.Add("PlayerSpawn", "HG_ResetSuicideSpawn", function(ply)
        stopSuicide(ply)
    end)
end
