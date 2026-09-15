if SERVER then
    resource.AddFile("resource/fonts/arnopro.ttf")
    util.AddNetworkString("HG_SuicideCutscene")
    local hg_cutscene = ConVarExists("hg_cutscene") and GetConVar("hg_cutscene") or CreateConVar("hg_cutscene", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enable suicide cutscene", 0, 1)
    local hg_suicidal = ConVarExists("hg_suicidal") and GetConVar("hg_suicidal") or CreateConVar("hg_suicidal", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Suicide behavior: 0 = normal, 1 = unrestricted, 2 = unrestricted and increases depression", 0, 2)

    concommand.Add("suicide", function(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if ply.organism and ply.organism.incapacitated then
            ply.organism.deathStateKilled = true
            ply:Kill()
            return
        end
        if not hg.CanSuicide(ply) then return end
        if ply.StartHeadcrabRemovalAttempt and ply:StartHeadcrabRemovalAttempt() then return end
		if ply:GetNWFloat("rem_urges_end", 0) > CurTime() or ply.remUrgeEnd then return end
        local suicideMode = hg_suicidal:GetInt()

        if suicideMode == 0 and not ply.suiciding and ply.organism and (ply.organism.depression or 0) < 0.5 then
			if ply:GetInfoNum("hg_newthoughts", 0) > 0 and ply.Thought then
				ply:Thought("You shouldn't do this.", 6, "depression_block_suicide", 0)
			else
				ply:Notify("I can't do it.", 6, "depression_block_suicide", 0)
			end
			return
		end
        if suicideMode == 0 and not ply.suiciding and hg.StartSuicideUrge then
			hg.StartSuicideUrge(ply)
			return
		end

        local wep = ply:GetActiveWeapon()
        local has_gun = IsValid(wep) and wep.ishgweapon and not wep.ismelee and not wep.ismelee2 and wep:Clip1() > 0

        if not has_gun then
            ply.suiciding = not ply.suiciding
            return
        end

        if not hg_cutscene:GetBool() then
            -- The server controls whether suicide uses the cutscene.
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
