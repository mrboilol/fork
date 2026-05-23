util.AddNetworkString("damage_flash")

hook.Add("OnPlayerTakeDamage", "homigrad_damageeffects", function(ply, dmginfo)
    net.Start("damage_flash")
    net.WriteFloat(dmginfo:GetDamage())
    net.Send(ply)
end)