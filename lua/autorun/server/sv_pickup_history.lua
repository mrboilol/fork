if not SERVER then return end

hg = hg or {}

util.AddNetworkString("HG_PickupHistory_Dropped")

function hg.NotifyPickupHistoryDrop(ply, itemName)
    if not IsValid(ply) or not ply:IsPlayer() or not isstring(itemName) or itemName == "" then return end

    net.Start("HG_PickupHistory_Dropped")
    net.WriteString(itemName)
    net.Send(ply)
end

hook.Add("PlayerDropWeapon", "HG_PickupHistory_WeaponDrop", function(ply, wep)
    if not IsValid(wep) or wep.HGImpactDropNotificationPending then return end

    local name = wep.GetPrintName and wep:GetPrintName() or wep.PrintName or wep:GetClass()
    hg.NotifyPickupHistoryDrop(ply, name)
end)
