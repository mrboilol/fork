
if CLIENT then
    surface.CreateFont("HG_StatsFont",{
        font = "Courier New",
        size = ScreenScale(10),
        extended = true,
        shadow = true,
        weight = 700,
        antialias = true
    })
    concommand.Add("hg_show_stats", function(ply, cmd, args)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or not wep.ishgwep then return end
        wep.hudinspect = CurTime() + 5
    end)

    concommand.Add("hg_toggle_stats", function(ply, cmd, args)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or not wep.ishgwep then return end
        wep.toggle_stats = not wep.toggle_stats
    end)

    concommand.Add("hg_stats", function(ply, cmd, args)
        RunConsoleCommand("hg_show_stats")
    end)
end
