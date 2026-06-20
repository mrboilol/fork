if SERVER then
    resource.AddFile("resource/fonts/arnopro.ttf")
    util.AddNetworkString("HG_SuicideCutscene")

    concommand.Add("suicide", function(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if not hg.CanSuicide(ply) then return end

        local wep = ply:GetActiveWeapon()
        local has_gun = IsValid(wep) and wep.ishgweapon and not wep.ismelee and not wep.ismelee2 and wep:Clip1() > 0

        if not has_gun then
            ply.suiciding = not ply.suiciding
            return
        end

        if ply:GetInfoNum("hg_cutscene", 1) == 0 then
            -- Cutscene disabled: toggle normal suicide mode immediately, no cutscene or forced firing
            ply.suiciding = not ply.suiciding
            ply:SetNWBool("suiciding", ply.suiciding)
            ply.startsuicide = ply.suiciding and (CurTime() - 2) or nil
            return
        end

        if ply:GetNWBool("suiciding") or ply.suiciding then return end
        if ply.suicideCutscene then return end

        ply.suicideCutscene = true
        ply.suicideCutsceneWep = wep

        net.Start("HG_SuicideCutscene")
        net.WriteBool(true)
        net.Send(ply)

        timer.Simple(4.0, function()
            if IsValid(ply) and ply:Alive() and ply.suicideCutscene then
                local activeWep = ply:GetActiveWeapon()
                if IsValid(ply.suicideCutsceneWep) and activeWep == ply.suicideCutsceneWep then
                    ply:SetNWBool("suiciding", true)
                    ply.suiciding = true
                    ply.startsuicide = CurTime()
                else
                    ply.suicideCutscene = false
                    ply.suicideCutsceneWep = nil
                    net.Start("HG_SuicideCutscene")
                    net.WriteBool(false)
                    net.Send(ply)
                end
            end
        end)

        timer.Simple(7.0, function()
            if IsValid(ply) and ply:Alive() and ply.suicideCutscene and ply.suiciding then
                local activeWep = ply:GetActiveWeapon()
                if IsValid(ply.suicideCutsceneWep) and activeWep == ply.suicideCutsceneWep then
                    if activeWep.Shoot then
                        activeWep:Shoot(true)
                    else
                        activeWep:PrimaryAttack()
                    end
                end
            end
        end)

        timer.Simple(8.0, function()
             if IsValid(ply) then
                if ply.suicideCutscene then
                    ply.suicideCutscene = false
                    ply.suicideCutsceneWep = nil
                    ply:SetNWBool("suiciding", false)
                    ply.suiciding = false
                    ply.startsuicide = nil
                    net.Start("HG_SuicideCutscene")
                    net.WriteBool(false)
                    net.Send(ply)
                end
            end
        end)
    end)

    net.Receive("HG_SuicideCutscene", function(len, ply)
        local cancel = net.ReadBool()
        if cancel and ply.suicideCutscene then
            -- Client rejected cutscene, continue normal suicide like non-gun behavior
            ply.suicideCutscene = false
            ply.suicideCutsceneWep = nil
            ply.suiciding = not ply.suiciding
            ply:SetNWBool("suiciding", ply.suiciding)
            ply.startsuicide = ply.suiciding and (CurTime() - 2) or nil
        end
    end)

    hook.Add("PlayerDeath", "HG_ResetSuicideCutscene", function(ply)
        if ply.suicideCutscene then
            ply.suicideCutscene = false
            ply.suicideCutsceneWep = nil
            net.Start("HG_SuicideCutscene")
            net.WriteBool(false)
            net.Send(ply)
        end
        ply:SetNWBool("suiciding", false)
        ply.suiciding = false
        ply.startsuicide = nil
    end)

    hook.Add("PlayerSpawn", "HG_ResetSuicideCutsceneSpawn", function(ply)
        ply:SetNWBool("suiciding", false)
        ply.suiciding = false
        ply.startsuicide = nil
        ply.suicideCutscene = false
        ply.suicideCutsceneWep = nil
        net.Start("HG_SuicideCutscene")
        net.WriteBool(false)
        net.Send(ply)
    end)

    hook.Add("PlayerSwitchWeapon", "HG_SuicideCutscene_NoSwitch", function(ply, oldWep, newWep)
        if ply.suicideCutscene then
            return true
        end
    end)
end
