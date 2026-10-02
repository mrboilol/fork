local OPEN_MENU_NET = "IKFoot_OpenMenu"

util.AddNetworkString(OPEN_MENU_NET)

hook.Add("PlayerSay", "IKFoot_ChatOpenMenu", function(ply, text)
	if not isstring(text) then return end

	local normalized = string.Trim(string.lower(text))
	if normalized ~= "!ikfoot" and normalized ~= "/ikfoot" then return end

	net.Start(OPEN_MENU_NET)
	net.Send(ply)

	return ""
end)
