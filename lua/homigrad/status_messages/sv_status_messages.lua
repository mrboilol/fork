util.AddNetworkString("hg_status_message")

hg.status_messages = hg.status_messages or {}

function hg.status_messages.Send(player, message, severity)
    if not IsValid(player) then return end
    if not player:GetInfoNum("hg_showinfo", 1) == 1 then return end

    net.Start("hg_status_message")
    net.WriteString(message)
    net.WriteUInt(severity, 4)
    net.Send(player)
end
