util.AddNetworkString("damage_flash")

hook.Add("OnPlayerTakeDamage", "homigrad_damageeffects", function(ply, dmginfo)
    if not IsValid(ply) or not ply:Alive() then return end
    net.Start("damage_flash")
    net.WriteFloat(dmginfo:GetDamage())
    net.Send(ply)
end)