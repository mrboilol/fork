--[[
	The Q menu entry.

	Utilities -> Z-City NPC Overhaul used to be eight pages of checkboxes and
	sliders, which is the wrong shape for this addon: every setting has a sentence
	explaining it and a Derma form has nowhere to put one, so all forty of them were
	tooltips nobody reads. The settings live in their own window now
	(cl_f6menu.lua), and this is the way in for somebody who goes looking for them
	where they used to be.

	Nothing is duplicated here on purpose. One list of settings, one place they are
	drawn, and this page is a button.
]]

ZCNPC = ZCNPC or {}

local TAB = "Utilities"
local SECTION = "Z-City NPC Overhaul"

local function KeyName()
	local cvar = GetConVar("zcnpc_menu_key")
	local key = cvar and cvar:GetInt() or 0
	if key <= 0 then return end

	local name = input.GetKeyName(key)

	return name and string.upper(name) or nil
end

local function Build(panel)
	panel:SetName("Z-City NPC Overhaul")

	if not ZCNPC.Installed() then
		panel:Help("This server is not running Z-City NPC Overhaul, so there is nothing here to change.")

		return
	end

	if not ZCNPC.Running() then
		panel:Help("Z-City NPC Overhaul is on this server, but Z-City itself never loaded, so none of it is "
			.. "doing anything. The server console says so on startup.")

		return
	end

	local key = KeyName()

	local open = panel:Button(key and ("Open the settings menu (" .. key .. ")") or "Open the settings menu")
	open.DoClick = function()
		-- The spawn menu is in the way of a window that wants the mouse.
		local menu = g_SpawnMenu
		if IsValid(menu) and menu:IsVisible() then menu:Close() end

		ZCNPC.OpenMenu()
	end

	panel:Help("Every setting, the three presets, and what each kind of NPC spawns holding. "
		.. (key and ("Also on " .. key .. ", ") or "Also ") .. "or zcnpc_menu in the console.")
end

hook.Add("PopulateToolMenu", "zcnpc_menu", function()
	spawnmenu.AddToolMenuOption(TAB, SECTION, "zcnpc_open", "Settings", "", "", Build, {
		Icon = "icon16/wrench.png",
	})
end)
