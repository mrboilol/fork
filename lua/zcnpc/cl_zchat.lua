--[[
	Z-City's chat box, put back when it is missing.

	Not our bug and not our panel. hg.chat is built once, from an InitPostEntity
	hook (zchat/sh_chat.lua:17), and two of the three places that use it afterwards
	never check that it is there:

		sh_chat.lua:38   hg.chat:SetActive(true)    -- opening the chat
		sh_chat.lua:45   hg.chat:GetActive()        -- the Escape menu

	The function that builds it does check (line 10), so the omission is clearly
	an oversight rather than a rule.

	Escape itself is Z-City's OpenMainMenu. Replacing that hook is what killed
	the pause menu: without this addon their panel opens fine. We only keep
	OnShowZCityPause from throwing on a nil hg.chat, so their OpenMainMenu
	can finish.
]]

if not CLIENT then return end

local PANEL = "zChatbox"

local function Heal()
	if not istable(hg) then return end
	if IsValid(hg.chat) then return end
	if not vgui.GetControlTable(PANEL) then return end
	if not IsValid(LocalPlayer()) then return end

	local ok, pnl = pcall(vgui.Create, PANEL)
	if ok and IsValid(pnl) then
		hg.chat = pnl
		if hg.chat.SetActive then hg.chat:SetActive(false) end
	end
end

-- Their hook: `if !hg.chat:GetActive() then return end`. Nil chat throws
-- inside OpenMainMenu and Escape never reaches vgui.Create("ZMainMenu").
-- Do not build a chat here and do not return false unless chat is actually open.
local function SafeZChat()
	if not (istable(hg) and IsValid(hg.chat)) then return end
	if not hg.chat:GetActive() then return end

	hg.chat:SetActive(false)

	return false
end

local function InstallChat()
	hook.Add("OnShowZCityPause", "ZChat", SafeZChat)
end

-- Hands off OnPauseMenuShow. Their OpenMainMenu is the menu.
hook.Remove("OnPauseMenuShow", "zcnpc_zcity_pause")
hook.Remove("OnPauseMenuShow", "!zcnpc_zcity_esc")
timer.Remove("zcnpc_zcity_pause")

InstallChat()
hook.Add("InitPostEntity", "zcnpc_zchat", function()
	timer.Simple(0, InstallChat)
	timer.Simple(1, InstallChat)
end)
hook.Add("HomigradRun", "zcnpc_zchat", function()
	timer.Simple(0, InstallChat)
end)

hook.Add("PlayerBindPress", "ZChat", function(_, bind, pressed)
	if not (isstring(bind) and pressed and bind:lower():find("messagemode", 1, true)) then
		return
	end

	Heal()
	if not (istable(hg) and IsValid(hg.chat)) then return end

	hg.chat:SetActive(true)

	return true
end)

timer.Create("zcnpc_zchat", 2, 0, Heal)
