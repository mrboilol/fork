local antiquePistolPreview

local function removeAntiquePistolPreview()
    if IsValid(antiquePistolPreview) then
        antiquePistolPreview:Remove()
    end

    antiquePistolPreview = nil
end

concommand.Add("antique_pistol_preview_remove", removeAntiquePistolPreview)

concommand.Add("antique_pistol_preview", function()
    removeAntiquePistolPreview()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local trace = ply:GetEyeTrace()
    antiquePistolPreview = ClientsideModel("models/weapons/antique_pistol.mdl", RENDERGROUP_OPAQUE)
    if not IsValid(antiquePistolPreview) then
        print("[antique_pistol] Failed to create models/weapons/antique_pistol.mdl")
        return
    end

    antiquePistolPreview:SetPos(trace.HitPos + trace.HitNormal * 8)
    antiquePistolPreview:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
    antiquePistolPreview:ResetSequence("idle")
    antiquePistolPreview:SetPlaybackRate(1)
    print("[antique_pistol] Preview spawned. Use antique_pistol_preview_sequence <name> to test animations.")
end)

concommand.Add("antique_pistol_preview_sequence", function(_, _, args)
    if not IsValid(antiquePistolPreview) then
        print("[antique_pistol] Run antique_pistol_preview first.")
        return
    end

    local sequenceName = args[1] or "idle"
    local sequence = antiquePistolPreview:LookupSequence(sequenceName)
    if sequence < 0 then
        print("[antique_pistol] Unknown sequence: " .. sequenceName)
        return
    end

    antiquePistolPreview:ResetSequence(sequence)
    antiquePistolPreview:SetCycle(0)
    antiquePistolPreview:SetPlaybackRate(1)
    print("[antique_pistol] Playing sequence: " .. sequenceName)
end)

hook.Add("ShutDown", "AntiquePistolPreviewCleanup", removeAntiquePistolPreview)
