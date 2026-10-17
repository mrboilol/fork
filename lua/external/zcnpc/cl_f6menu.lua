--[[
	The settings menu.

	F6, or the button in the Q menu, or zcnpc_menu in a console. What used to be
	eight pages of Utilities is one window with the same settings in it, laid out so
	that what a setting does is on the screen next to the setting rather than in a
	tooltip - which is the whole reason it is here: the registry has a sentence for
	every one of them and the Q menu form had nowhere to put it.

	Everything still goes through the server. The convars are replicated, so a
	client can read all of them and set none of them, and that is also the right
	arrangement for settings that decide how the whole server plays: the menu asks
	(sv_menu.lua answers) and a client who is not an admin gets the window read only
	rather than not at all, because "why does that not happen here" is a fair
	question to be able to answer by looking.
]]

ZCNPC = ZCNPC or {}

local UI = ZCNPC.UI

local PRESET_FILE = "zcnpc_presets.json"
local REFRESH = 0.5 -- seconds between re-reading the server's value
local SETTLE = 0.25 -- seconds a slider is left alone before its value is sent

local keyCvar = CreateClientConVar("zcnpc_menu_key", tostring(KEY_F6), true, false,
	"Key that opens the Z-City NPC Overhaul menu. 0 for none")

--\\ Reading the server, asking the server
-- Two questions, and telling them apart is the difference between an answer and a
-- support thread: a server without the addon, and a server that has it sitting next to
-- a Z-City that never loaded, which from here looks exactly like a broken install and is
-- not one. Both are read out of one number the server sets (sv_config.lua), because the
-- convars themselves are on this client either way - it made its own copies so the
-- server's values would have something to land on (sh_settings.lua).
local function Loaded()
	local cvar = GetConVar("zcnpc_loaded")

	return cvar and cvar:GetInt() or 0
end

function ZCNPC.Installed()
	return Loaded() >= 1
end

function ZCNPC.Running()
	return Loaded() >= 2
end

local function MayChange()
	local ply = LocalPlayer()
	if not IsValid(ply) then return false end

	return game.SinglePlayer() or ply:IsSuperAdmin() or ply:IsListenServerHost()
end

local function Value(setting)
	local cvar = GetConVar(setting.cvar)
	if not cvar then return setting.default end

	if setting.type == "bool" then return cvar:GetBool() and 1 or 0 end

	return cvar:GetFloat()
end

local function Ask(cvar, value)
	net.Start("zcnpc_set")
		net.WriteString(cvar)
		net.WriteFloat(value)
	net.SendToServer()
end

local function AskPreset(id, values)
	local list = {}

	if not id then
		for cvar, value in pairs(values or {}) do
			if ZCNPC.SettingByCvar[cvar] then list[#list + 1] = { cvar, value } end
		end
	end

	net.Start("zcnpc_preset")
		net.WriteString(id or "")
		net.WriteUInt(#list, 8)

		for _, entry in ipairs(list) do
			net.WriteString(entry[1])
			net.WriteFloat(entry[2])
		end
	net.SendToServer()
end

-- Each entry is its name and how many tickets it holds in the roll. The weight
-- always goes with the name rather than only when it has been changed, because the
-- other end has no way to ask what the client left out.
local function AskWeapons(group, classes, weights)
	net.Start("zcnpc_weapons")
		net.WriteString(group)
		net.WriteUInt(#classes, 8)

		for _, class in ipairs(classes) do
			net.WriteString(class)
			net.WriteUInt(ZCNPC.CleanWeight(weights and weights[class]), 8)
		end
	net.SendToServer()
end

local function AskArmor(group, pieces, weights)
	net.Start("zcnpc_armor")
		net.WriteString(group)
		net.WriteUInt(#pieces, 8)

		for _, piece in ipairs(pieces) do
			net.WriteString(piece)
			net.WriteUInt(ZCNPC.CleanWeight(weights and weights[piece]), 8)
		end
	net.SendToServer()
end
--//

--\\ Saved presets
-- On the machine that saved them: they are somebody's preferences rather than the
-- server's, and a player who sets a server up the way they like it should be able
-- to do the same on the next one.
local function Saved()
	local raw = file.Read(PRESET_FILE, "DATA")
	local saved = raw and util.JSONToTable(raw)

	return istable(saved) and saved or {}
end

local function Store(saved)
	file.Write(PRESET_FILE, util.TableToJSON(saved, true))
end

local function Snapshot()
	local values = {}

	for _, setting in ipairs(ZCNPC.Settings) do
		values[setting.cvar] = Value(setting)
	end

	return values
end

-- Which preset the server is running, if it is running one at all. Compared
-- loosely because a float that went out as 0.55 comes back off a convar as
-- 0.550000011920929.
local function CurrentPreset()
	for _, preset in ipairs(ZCNPC.Presets) do
		local match = true

		for cvar, want in pairs(ZCNPC.PresetValues(preset)) do
			local setting = ZCNPC.SettingByCvar[cvar]

			if setting and math.abs(Value(setting) - want) > 0.001 then
				match = false
				break
			end
		end

		if match then return preset.name end
	end

	local values = Snapshot()

	for name, preset in pairs(Saved()) do
		local match = true

		for cvar, want in pairs(preset) do
			if values[cvar] and math.abs(values[cvar] - want) > 0.001 then
				match = false
				break
			end
		end

		if match then return name end
	end
end
--//

--\\ Controls that follow the server
-- Setting a control's value in code fires the same callback as dragging it, so
-- every one of these has to be able to say "this is me, not the player".
local function Watch(panel, apply)
	panel.Think = function(self)
		if (self.zcnpc_next or 0) > CurTime() then return end
		self.zcnpc_next = CurTime() + REFRESH

		local may = MayChange()
		if self:IsEnabled() ~= may then self:SetEnabled(may) end

		apply(self)
	end
end

local function BoolRow(parent, setting)
	local row = UI.Row(parent, setting.label, setting.help)
	local toggle = UI.Toggle(row)

	row:SetControl(toggle)

	toggle:SetOn(Value(setting) >= 0.5)
	toggle:SetEnabled(MayChange())

	toggle.DoClick = function(self)
		if not self:IsEnabled() then return end

		local want = not self:GetOn()
		self:SetOn(want)

		Ask(setting.cvar, want and 1 or 0)

		-- The convar takes a round trip; reading it before it lands would flip the
		-- switch back for half a second.
		self.zcnpc_next = CurTime() + REFRESH
	end

	Watch(toggle, function(self)
		self:SetOn(Value(setting) >= 0.5)
	end)

	return row
end

local function FloatRow(parent, setting)
	local row = UI.Row(parent, setting.label, setting.help)
	local slider = UI.Slider(row, setting.min or 0, setting.max or 1, setting.decimals or 2)

	row:SetControl(slider)

	slider:SetValue(Value(setting), true)
	slider:SetEnabled(MayChange())

	-- Dragging fires on every pixel, so what the server hears is the value the
	-- slider was let go on rather than sixty of them on the way there.
	slider.OnValue = function(self)
		self.zcnpc_send = CurTime() + SETTLE
	end

	slider.OnRelease = function(self)
		self.zcnpc_send = CurTime()
	end

	Watch(slider, function(self)
		if self.zcnpc_send then
			if self.zcnpc_send > CurTime() then return end

			self.zcnpc_send = nil
			Ask(setting.cvar, self:GetValue())
			self.zcnpc_next = CurTime() + REFRESH

			return
		end

		if self.held then return end

		self:SetValue(Value(setting), true)
	end)

	return row
end

local function SettingRow(parent, setting)
	if setting.type == "bool" then return BoolRow(parent, setting) end

	return FloatRow(parent, setting)
end
--//

--\\ Pages
local Pages = {}

local function Header(parent)
	if not ZCNPC.Installed() then
		UI.Note(parent, "This server is not running Z-City NPC Overhaul, so there is nothing here to change.",
			UI.Colors.accent)

		return false
	end

	if not ZCNPC.Running() then
		UI.Note(parent, "Z-City NPC Overhaul is on this server, but Z-City itself never loaded, so none of "
			.. "this is doing anything. The server console says so on startup.", UI.Colors.accent)

		return false
	end

	if not MayChange() then
		UI.Note(parent, "These are server settings and you are not an admin, so this window is read only.",
			UI.Colors.accent)
	end

	return true
end

function Pages.Settings(parent, category)
	if not Header(parent) then return end

	for _, setting in ipairs(ZCNPC.SettingsIn(category.id)) do
		SettingRow(parent, setting)
	end

	-- The two that are not the server's: which key opens this window, and whether
	-- it makes any noise. Both are this machine's alone, so they are on rather
	-- than off for somebody without rights on the server.
	if category.id ~= "general" then return end

	UI.Heading(parent, "This machine")

	local row = UI.Row(parent, "Menu key", "Opens this window. Also on the Q menu under Utilities, and zcnpc_menu in the console")
	local binder = vgui.Create("DBinder", row)
	binder:SetSize(UI.Scale(130), UI.Scale(32))
	binder:SetConVar("zcnpc_menu_key")

	binder.Paint = function(self, w, h)
		local key = self:GetSelectedNumber() or 0
		-- Waiting for a key is a field on the panel rather than something it can be
		-- asked for, and which field depends on the version of Derma.
		local waiting = self.Trapping or self.m_bTrapping
		local name = waiting and "press a key" or (key > 0 and string.upper(input.GetKeyName(key) or "?") or "none")
		local live = UI.Ease(self, "zcnpc_live", (waiting or self:IsHovered()) and 1 or 0, 14)

		UI.Box(0, 0, w, h, UI.Mix(UI.Colors.row, UI.Colors.rowHover, live), UI.Scale(6))
		UI.Gloss(0, 0, w, h, Color(255, 255, 255, 8 + 12 * live), UI.Scale(6), w, h * 0.6, "down")

		if waiting then
			UI.Box(UI.Scale(8), h - UI.Scale(3), w - UI.Scale(16), UI.Scale(2), UI.Colors.accent, UI.Scale(1))
		end

		draw.SimpleText(name, "zcnpc_tab", w / 2, h / 2,
			waiting and UI.Colors.accentLit or UI.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	row:SetControl(binder)

	local sounds = UI.Row(parent, "Menu sounds",
		"The clicks this window makes when a page is turned or something is pressed. Yours, not the server's")
	local toggle = UI.Toggle(sounds)

	sounds:SetControl(toggle)

	toggle:SetOn(GetConVar("zcnpc_menu_sounds"):GetBool())

	toggle.DoClick = function(self)
		local want = not self:GetOn()

		self:SetOn(want)
		RunConsoleCommand("zcnpc_menu_sounds", want and "1" or "0")
	end
end

--\\ Loadouts
-- One list of guns per kind of NPC, and the list is what one of them spawns
-- holding. Empty means untouched, which is the default and the only honest one:
-- somebody who has not opened this page has not asked for a Combine soldier with
-- a shotgun.
local function WeaponTitle(class)
	if class == ZCNPC.WeaponNone then return "Nothing (unarmed)" end

	for _, entry in ipairs(ZCNPC.NpcWeapons()) do
		if entry.class == class then return entry.title end
	end

	return class
end

-- One entry of a list: what it is, how many tickets it holds, and what that comes
-- to as a chance. The percentage is worked out by the caller, which is the only
-- place that knows what it is being divided by - the whole list for a gun, the one
-- slot for a piece of armour.
--
-- `Send` is handed in for the same reason: the two pages talk to two different net
-- messages and the row does not need to know which.
local function EntryRow(parent, opts)
	local row = vgui.Create("DPanel", parent)
	row:Dock(TOP)
	row:DockMargin(0, 0, 0, UI.Scale(4))
	row:SetTall(UI.Scale(46))

	local weights = opts.weights
	local name = opts.name

	row.Paint = function(self, w, h)
		local hover = UI.Ease(self, "zcnpc_hover", (self:IsHovered() or self:IsChildHovered()) and 1 or 0, 14)

		UI.Box(0, 0, w, h, UI.Mix(UI.Colors.row, UI.Colors.rowHover, hover), UI.Scale(5))
		UI.Box(0, h * 0.25, UI.Scale(2), h * 0.5, ColorAlpha(UI.Colors.accent, 90 + 120 * hover), UI.Scale(1))

		local top = UI.Scale(9)

		UI.Text(opts.title, "zcnpc_chip", UI.Scale(10), top, opts.blank and UI.Colors.dim or UI.Colors.text)

		-- Right up against the × so the eye reads down a column of percentages.
		local share = opts.Share and opts.Share(ZCNPC.CleanWeight(weights[name]))
		if share then
			UI.Text(math.Round(share * 100) .. "%", "zcnpc_chip", w - UI.Scale(38), top,
				UI.Mix(UI.Colors.faint, UI.Colors.text, hover), TEXT_ALIGN_RIGHT)
		end
	end

	local drop = vgui.Create("DButton", row)
	drop:Dock(RIGHT)
	drop:SetWide(UI.Scale(32))
	drop:SetText("")

	drop.DoClickInternal = function() UI.Sound("drop") end

	drop.Paint = function(self, w, h)
		local hover = UI.Hover(self)

		draw.SimpleText("×", "zcnpc_label", w / 2, UI.Scale(15),
			UI.Mix(UI.Colors.faint, UI.Colors.accentLit, hover), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	drop.DoClick = function()
		if not MayChange() then return end

		local keep = {}
		for _, entry in ipairs(opts.chosen) do
			if entry ~= name then keep[#keep + 1] = entry end
		end

		opts.Send(keep, weights)
	end

	local bar = UI.Weight(row, ZCNPC.WeightMin, ZCNPC.WeightMax)
	bar:Dock(BOTTOM)
	bar:DockMargin(UI.Scale(10), 0, UI.Scale(38), UI.Scale(8))
	bar:SetValue(ZCNPC.CleanWeight(weights[name]), true)
	bar:SetEnabled(MayChange())
	bar:SetTooltip("How likely this one is. Everything starts on one, which is an even split; ten next to a one is ten times as many of the first")

	-- Painted from the live number while dragging and only sent on release, so the
	-- percentage above follows the cursor without a convar round trip per pixel.
	bar.OnValue = function(self, value)
		weights[name] = value
	end

	bar.OnRelease = function(_, value)
		if not MayChange() then return end

		weights[name] = value
		opts.Send(opts.chosen, weights)
	end

	return row
end

-- Which box a group with an empty one of its own is actually reading, so both
-- pages can say so instead of claiming nothing was chosen. Only the Combine
-- subgroups have a parent (sh_npcweapons.lua), so this is nil for most of them and
-- the wording underneath is the wording it always had.
local function Inherited(group, byId, ListFor)
	local id = group.parent

	for _ = 1, 4 do
		if not id then return end

		local from = byId[id]
		if not from then return end

		local list = ListFor(from.id)
		if #list > 0 then return from end

		id = from.parent
	end
end

function Pages.Loadouts(parent)
	if not Header(parent) then return end

	UI.Note(parent, "What an NPC spawns holding. A list of several is rolled per NPC, so three rifles in the Combine box means a squad with three different rifles in it. The bar under each one is how many tickets it holds in that roll and the percentage is what that comes to - leave them all on one for an even split. An empty list leaves them exactly as they are now, which is what every one of these starts as.")

	UI.Note(parent, "Rebels and Refugees are two different boxes. A gun added under Rebels is not given to Refugees, and the other way around. The picker on the right is only the catalogue - it writes into whichever tab is selected.")

	UI.Note(parent, "The overwatch line is four boxes because a shotgunner, an elite and a Nova Prospekt guard are three different jobs sharing one entity class. Leave the three narrow ones empty and they read the Combine soldiers box, so this is four answers only if you want four.")

	local state = { group = ZCNPC.WeaponGroups[1] }

	--\\ Which kind of NPC
	local tabs = UI.TabRow(parent)
	tabs:Dock(TOP)
	tabs:DockMargin(0, UI.Scale(8), 0, UI.Scale(10))

	local body = vgui.Create("DPanel", parent)
	body:Dock(TOP)
	body:DockMargin(0, 0, 0, UI.Scale(8))
	body:SetTall(UI.Scale(320))
	body:SetPaintBackground(false)

	local chosenPanel = UI.Scroll(body)
	chosenPanel:Dock(LEFT)
	chosenPanel:SetWide(UI.Scale(300))

	-- Rows go in the canvas, which is the part that scrolls.
	local chosenBody = chosenPanel:GetCanvas()

	local pickPanel = vgui.Create("DPanel", body)
	pickPanel:Dock(FILL)
	pickPanel:DockMargin(UI.Scale(10), 0, 0, 0)
	pickPanel:SetPaintBackground(false)

	local search = UI.TextEntry(pickPanel, "Search weapons")
	search:Dock(TOP)
	search:SetUpdateOnType(true)

	local pickList = UI.Scroll(pickPanel)
	pickList:Dock(FILL)
	pickList:DockMargin(0, UI.Scale(8), 0, 0)

	local pickBody = pickList:GetCanvas()

	local FillChosen, FillPicker

	-- Whether an empty box means "leave them alone" or "surprise me", which is the
	-- one thing on this page that is decided somewhere else (General).
	local function Randomised()
		local cvar = GetConVar("zcnpc_wep_random")

		return cvar and cvar:GetBool() or false
	end

	function FillChosen()
		chosenPanel:Clear()

		local chosen, weights = ZCNPC.WeaponListFor(state.group.id)
		local from = #chosen == 0 and Inherited(state.group, ZCNPC.WeaponGroupById, ZCNPC.WeaponListFor) or nil

		local title = vgui.Create("DPanel", chosenBody)
		title:Dock(TOP)
		title:DockMargin(0, 0, 0, UI.Scale(6))
		title:SetTall(UI.Scale(20))
		title.Paint = function(_, w, h)
			local text = "SPAWNS WITH — ONE OF THESE"

			if #chosen == 0 then
				if from then
					text = "USING THE " .. string.upper(from.name) .. " LIST"
				elseif Randomised() then
					text = "SPAWNS WITH — A RANDOM GUN INSTEAD OF ITS OWN"
				else
					text = "SPAWNS WITH — WHATEVER IT ALREADY HAD"
				end
			end

			UI.Text(text, "zcnpc_help", 0, h / 2 - draw.GetFontHeight("zcnpc_help") / 2, UI.Colors.faint)
		end

		-- Read fresh out of the table each frame rather than worked out once, so a
		-- bar being dragged moves every percentage in the column with it.
		local function Total()
			local total = 0
			for _, entry in ipairs(chosen) do
				total = total + ZCNPC.CleanWeight(weights[entry])
			end

			return total
		end

		local function Send(list, tickets)
			AskWeapons(state.group.id, list, tickets)
		end

		for _, class in ipairs(chosen) do
			EntryRow(chosenBody, {
				name = class,
				title = WeaponTitle(class),
				blank = class == ZCNPC.WeaponNone,
				chosen = chosen,
				weights = weights,
				Send = Send,
				Share = function(weight)
					local total = Total()

					return total > 0 and weight / total or nil
				end,
			})
		end

		if #chosen == 0 then
			if from then
				UI.Note(chosenBody, "Nothing of their own, so " .. state.group.name .. " roll the "
					.. from.name .. " list instead. Add one gun here and it is theirs alone.")
			elseif Randomised() then
				UI.Note(chosenBody, "Nothing chosen and Randomised weapons is on, in General, so each of "
					.. state.group.name .. " that turned up with a gun swaps it for one rolled out of everything "
					.. "installed that suits its job. No machineguns, launchers or admin weapons come out of that "
					.. "roll, and one that turned up without a gun stays that way - empty hands or a stunstick are "
					.. "somebody's choice too, and this replaces a gun rather than issuing one. Add one gun here "
					.. "and this box wins.")
			else
				UI.Note(chosenBody, "Nothing chosen, so nothing is taken away from them either: " .. state.group.name
					.. " spawn with whatever the map or the spawn menu gave them.")
			end
		end

		if #chosen > 1 and GetConVar("zcnpc_wep_roles"):GetBool() then
			UI.Note(chosenBody, "Match the gun to the job is on, in General. Each NPC rolls only the entries here that suit what it was carrying, so a shotgunner reads these percentages across the shotguns alone.")
		end
	end

	local function Add(class)
		if not MayChange() then return end

		-- Fresh copies, this tab only. Mutating the table ParseWeaponList just
		-- handed back and sending it under the wrong id is how two boxes used
		-- to look like one pool.
		local chosen, weights = ZCNPC.WeaponListFor(state.group.id)
		local list, tickets = {}, {}

		for i = 1, #chosen do
			local entry = chosen[i]
			if entry == class then return end

			list[i] = entry
			tickets[entry] = weights[entry]
		end

		list[#list + 1] = class

		AskWeapons(state.group.id, list, tickets)
	end

	function FillPicker()
		pickList:Clear()

		local filter = string.lower(string.Trim(search:GetValue() or ""))
		local entries = ZCNPC.NpcWeapons()

		-- Unarmed is a choice somebody can make, and it is not a weapon, so it is
		-- written in rather than found.
		table.insert(entries, 1, { class = ZCNPC.WeaponNone, title = "Nothing (unarmed)", category = "" })

		local shown, category = 0, nil

		for _, entry in ipairs(entries) do
			local haystack = string.lower(entry.title .. " " .. entry.class)
			if filter ~= "" and not string.find(haystack, filter, 1, true) then continue end

			if entry.category ~= "" and entry.category ~= category then
				category = entry.category
				UI.Heading(pickBody, entry.category)
			end

			local button = vgui.Create("DButton", pickBody)
			button:Dock(TOP)
			button:DockMargin(0, 0, 0, UI.Scale(4))
			button:SetTall(UI.Scale(30))
			button:SetText("")

			button.DoClickInternal = function() UI.Sound("add") end

			button.Paint = function(self, w, h)
				local hover = UI.Hover(self)

				UI.Box(0, 0, w, h, UI.Mix(UI.Colors.row, UI.Colors.rowHover, hover), UI.Scale(5))
				UI.Gloss(0, 0, w, h, Color(255, 255, 255, 4 + 10 * hover), UI.Scale(5), w, h * 0.6, "down")

				UI.Text(entry.title, "zcnpc_chip", UI.Scale(10) + UI.Scale(3) * hover,
					h / 2 - draw.GetFontHeight("zcnpc_chip") / 2, UI.Mix(UI.Colors.dim, UI.Colors.text, hover))

				draw.SimpleText("+", "zcnpc_label", w - UI.Scale(16), h / 2 - UI.Scale(1),
					UI.Mix(UI.Colors.faint, UI.Colors.good, hover), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			button.DoClick = function() Add(entry.class) end

			shown = shown + 1
		end

		if shown == 0 then
			UI.Note(pickBody, "Nothing matches that.")
		end
	end

	search.OnValueChange = function() FillPicker() end

	for _, group in ipairs(ZCNPC.WeaponGroups) do
		local tab = tabs:Add(group.name, function() return state.group == group end)
		tab:SetTooltip(group.help)

		tab.DoClick = function()
			state.group = group

			FillChosen()
			FillPicker()
		end
	end

	FillChosen()
	FillPicker()

	-- The server's answer comes back as a convar, and nothing tells the window
	-- when: the chosen list is re-read when it changes rather than on a timer that
	-- rebuilds it whether it changed or not.
	local last = {}
	local lastRandom = Randomised()

	parent.Think = function()
		if (parent.zcnpc_next or 0) > CurTime() then return end
		parent.zcnpc_next = CurTime() + REFRESH

		-- Switched on the General page while this one is open, and it decides what
		-- an empty box means, so an empty box has to be redrawn saying so.
		if lastRandom ~= Randomised() then
			lastRandom = not lastRandom

			FillChosen()
		end

		for _, group in ipairs(ZCNPC.WeaponGroups) do
			local cvar = GetConVar(group.cvar)
			local value = cvar and cvar:GetString() or ""

			if last[group.id] ~= value then
				last[group.id] = value

				-- The box above the shown one counts as the shown one while it is
				-- the box being read (Inherited above).
				if state.group == group or state.group.parent == group.id then FillChosen() end
			end
		end
	end
	--//

	UI.Heading(parent, "NPCs already on the map")

	local rearm = UI.Button(parent, "Give them their loadout now")
	rearm:Dock(TOP)
	rearm:SetEnabled(MayChange())
	rearm.DoClick = function() RunConsoleCommand("zcnpc_rearm") end

	UI.Note(parent, "A loadout is rolled once, when an NPC spawns. This rolls it again for every NPC standing on the map right now, which is how to see a change without spawning anything.")
end
--//

--\\ Armour
-- The same page for the other half of a loadout, with one difference that is the
-- whole of the difference between a gun and a vest: a gun list is rolled once and
-- the NPC holds one thing, armour is worn a piece per placement. So the list is a
-- pool, one piece is rolled for each placement it mentions, and the chosen column
-- says so by grouping what is in it under the slot it will be worn on.
local function ArmorTitle(piece)
	if piece == ZCNPC.ArmorNone then return "Nothing (unarmoured)" end

	for _, entry in ipairs(ZCNPC.NpcArmor()) do
		if entry.piece == piece then return entry.title end
	end

	return piece
end

local function ArmorPlacementOf(piece)
	for _, entry in ipairs(ZCNPC.NpcArmor()) do
		if entry.piece == piece then return entry.placement end
	end
end

local function ArmorChosenRow(parent, group, piece, chosen, weights, Share)
	return EntryRow(parent, {
		name = piece,
		title = ArmorTitle(piece),
		blank = piece == ZCNPC.ArmorNone,
		chosen = chosen,
		weights = weights,
		Share = Share,
		Send = function(list, tickets)
			AskArmor(group.id, list, tickets)
		end,
	})
end

function Pages.Armour(parent)
	if not Header(parent) then return end

	if #ZCNPC.NpcArmor() == 0 then
		UI.Note(parent, "Z-City has not registered any armour, so there is nothing to choose from. This page fills itself in from whatever armour the server has installed.")

		return
	end

	UI.Note(parent, "What an NPC spawns wearing. One piece is rolled for each placement the list mentions, so two helmets and a vest is a squad where everybody has the vest and one of the two helmets. The bar under each one is how many tickets it holds in its slot's roll and the percentage is what that comes to. A slot the list says nothing about is left alone. An empty list leaves them exactly as they are now.")

	UI.Note(parent, "Same boxes as the guns page, including the three narrow Combine ones: an empty one of those is dressed out of the Combine soldiers box, so an elite only wears something of its own once somebody has put it there.")

	local state = { group = ZCNPC.ArmorGroups[1] }

	local tabs = UI.TabRow(parent)
	tabs:Dock(TOP)
	tabs:DockMargin(0, UI.Scale(8), 0, UI.Scale(10))

	local body = vgui.Create("DPanel", parent)
	body:Dock(TOP)
	body:DockMargin(0, 0, 0, UI.Scale(8))
	body:SetTall(UI.Scale(320))
	body:SetPaintBackground(false)

	local chosenPanel = UI.Scroll(body)
	chosenPanel:Dock(LEFT)
	chosenPanel:SetWide(UI.Scale(300))

	local chosenBody = chosenPanel:GetCanvas()

	local pickPanel = vgui.Create("DPanel", body)
	pickPanel:Dock(FILL)
	pickPanel:DockMargin(UI.Scale(10), 0, 0, 0)
	pickPanel:SetPaintBackground(false)

	local search = UI.TextEntry(pickPanel, "Search armour")
	search:Dock(TOP)
	search:SetUpdateOnType(true)

	local pickList = UI.Scroll(pickPanel)
	pickList:Dock(FILL)
	pickList:DockMargin(0, UI.Scale(8), 0, 0)

	local pickBody = pickList:GetCanvas()

	local FillChosen, FillPicker

	function FillChosen()
		chosenPanel:Clear()

		local chosen, weights = ZCNPC.ArmorListFor(state.group.id)
		local from = #chosen == 0 and Inherited(state.group, ZCNPC.ArmorGroupById, ZCNPC.ArmorListFor) or nil

		local title = vgui.Create("DPanel", chosenBody)
		title:Dock(TOP)
		title:DockMargin(0, 0, 0, UI.Scale(6))
		title:SetTall(UI.Scale(20))
		title.Paint = function(_, w, h)
			local text = "WEARS — ONE FROM EACH SLOT"

			if #chosen == 0 then
				text = from and ("USING THE " .. string.upper(from.name) .. " LIST")
					or "WEARS — WHATEVER IT ALREADY HAD"
			end

			UI.Text(text, "zcnpc_help", 0, h / 2 - draw.GetFontHeight("zcnpc_help") / 2, UI.Colors.faint)
		end

		-- Grouped by slot, because the slot is what decides whether two entries
		-- are alternatives or both worn at once, and a flat list of five names
		-- gives no way to tell which.
		local slots, order, blank = {}, {}, false

		for _, piece in ipairs(chosen) do
			if piece == ZCNPC.ArmorNone then
				blank = true

				continue
			end

			local placement = ArmorPlacementOf(piece) or "other"

			if not slots[placement] then
				slots[placement] = {}
				order[#order + 1] = placement
			end

			table.insert(slots[placement], piece)
		end

		-- A slot's own total, plus the blank ticket if there is one, because that is
		-- what an entry in this slot is actually competing against. Read live so a
		-- bar being dragged moves the rest of its slot with it.
		local function Sharer(pool)
			return function(weight)
				local total = blank and ZCNPC.CleanWeight(weights[ZCNPC.ArmorNone]) or 0

				for _, entry in ipairs(pool) do
					total = total + ZCNPC.CleanWeight(weights[entry])
				end

				return total > 0 and weight / total or nil
			end
		end

		for _, placement in ipairs(order) do
			local pool = slots[placement]
			local count = #pool + (blank and 1 or 0)
			local Share = Sharer(pool)

			UI.Heading(chosenBody, ZCNPC.ArmorPlacementName(placement)
				.. (count > 1 and (" — one of " .. count) or ""))

			for _, piece in ipairs(pool) do
				ArmorChosenRow(chosenBody, state.group, piece, chosen, weights, Share)
			end
		end

		if blank then
			UI.Heading(chosenBody, "Or nothing")

			-- Rolled once per slot rather than once overall, so the one percentage
			-- that would fit here would be wrong for every slot but one.
			ArmorChosenRow(chosenBody, state.group, ZCNPC.ArmorNone, chosen, weights)

			if #order > 0 then
				UI.Note(chosenBody, "Listed next to real pieces, this is one more thing each slot above can roll, and its bar is how many tickets it holds in each of them - a ten here against a helmet on one is a slot where almost nobody gets the helmet.")
			else
				UI.Note(chosenBody, "On its own this means unarmoured: whatever Z-City or another addon put on them is taken off again.")
			end
		end

		if #chosen == 0 then
			if from then
				UI.Note(chosenBody, "Nothing of their own, so " .. state.group.name .. " are dressed out of the "
					.. from.name .. " list instead. Add one piece here and it is theirs alone.")
			else
				UI.Note(chosenBody, "Nothing chosen, so nothing is taken off them either: " .. state.group.name
					.. " wear whatever they were already going to.")
			end
		end
	end

	local function Add(piece)
		if not MayChange() then return end

		local chosen, weights = ZCNPC.ArmorListFor(state.group.id)

		for _, entry in ipairs(chosen) do
			if entry == piece then return end
		end

		chosen[#chosen + 1] = piece

		AskArmor(state.group.id, chosen, weights)
	end

	function FillPicker()
		pickList:Clear()

		local filter = string.lower(string.Trim(search:GetValue() or ""))
		local entries = ZCNPC.NpcArmor()

		table.insert(entries, 1, { piece = ZCNPC.ArmorNone, title = "Nothing (unarmoured)", placement = "" })

		local shown, placement = 0, nil

		for _, entry in ipairs(entries) do
			local haystack = string.lower(entry.title .. " " .. entry.piece)
			if filter ~= "" and not string.find(haystack, filter, 1, true) then continue end

			if entry.placement ~= "" and entry.placement ~= placement then
				placement = entry.placement
				UI.Heading(pickBody, ZCNPC.ArmorPlacementName(entry.placement))
			end

			local button = vgui.Create("DButton", pickBody)
			button:Dock(TOP)
			button:DockMargin(0, 0, 0, UI.Scale(4))
			button:SetTall(UI.Scale(30))
			button:SetText("")

			button.DoClickInternal = function() UI.Sound("add") end

			button.Paint = function(self, w, h)
				local hover = UI.Hover(self)

				UI.Box(0, 0, w, h, UI.Mix(UI.Colors.row, UI.Colors.rowHover, hover), UI.Scale(5))
				UI.Gloss(0, 0, w, h, Color(255, 255, 255, 4 + 10 * hover), UI.Scale(5), w, h * 0.6, "down")

				UI.Text(entry.title, "zcnpc_chip", UI.Scale(10) + UI.Scale(3) * hover,
					h / 2 - draw.GetFontHeight("zcnpc_chip") / 2, UI.Mix(UI.Colors.dim, UI.Colors.text, hover))

				-- Z-City's own protection figure, which is the only thing that
				-- tells two similar looking helmets apart.
				if (entry.protection or 0) > 0 then
					UI.Text(string.format("%g", entry.protection), "zcnpc_help",
						w - UI.Scale(36), h / 2 - draw.GetFontHeight("zcnpc_help") / 2, UI.Colors.faint)
				end

				draw.SimpleText("+", "zcnpc_label", w - UI.Scale(16), h / 2 - UI.Scale(1),
					UI.Mix(UI.Colors.faint, UI.Colors.good, hover), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			button.DoClick = function() Add(entry.piece) end

			shown = shown + 1
		end

		if shown == 0 then
			UI.Note(pickBody, "Nothing matches that.")
		end
	end

	search.OnValueChange = function() FillPicker() end

	for _, group in ipairs(ZCNPC.ArmorGroups) do
		local tab = tabs:Add(group.name, function() return state.group == group end)
		tab:SetTooltip(group.help)

		tab.DoClick = function()
			state.group = group

			FillChosen()
			FillPicker()
		end
	end

	FillChosen()
	FillPicker()

	local last = {}
	parent.Think = function()
		if (parent.zcnpc_next or 0) > CurTime() then return end
		parent.zcnpc_next = CurTime() + REFRESH

		for _, group in ipairs(ZCNPC.ArmorGroups) do
			local cvar = GetConVar(group.cvar)
			local value = cvar and cvar:GetString() or ""

			if last[group.id] ~= value then
				last[group.id] = value

				if state.group == group or state.group.parent == group.id then FillChosen() end
			end
		end
	end

	UI.Note(parent, "Armour is put on once, when an NPC spawns, so a change here shows on the next one to walk in rather than on the ones already standing about.")
end
--//

function Pages.Presets(parent)
	if not Header(parent) then return end

	-- What the server is running now, at the top of the page, because every button
	-- under it is "make it this instead" and that only means anything next to what
	-- it is. Re-read once a second: any of the forty settings changing anywhere
	-- can turn a preset into Custom.
	local now = vgui.Create("DPanel", parent)
	now:Dock(TOP)
	now:DockMargin(0, 0, 0, UI.Scale(10))
	now:SetTall(UI.Scale(56))

	now.Think = function(self)
		if (self.zcnpc_next or 0) > CurTime() then return end
		self.zcnpc_next = CurTime() + 1

		self.zcnpc_text = CurrentPreset() or "Custom"
	end

	now.Paint = function(self, w, h)
		local name = self.zcnpc_text or CurrentPreset() or "Custom"
		local named = name ~= "Custom"

		UI.Box(0, 0, w, h, UI.Colors.row, UI.Scale(7))
		UI.Gloss(0, 0, w, h, Color(255, 255, 255, 8), UI.Scale(7), w, h, "down")
		UI.Box(0, h * 0.2, UI.Scale(3), h * 0.6, named and UI.Colors.accent or UI.Colors.off, UI.Scale(2))

		local pad = UI.Scale(16)
		local top = h / 2 - (draw.GetFontHeight("zcnpc_micro") + draw.GetFontHeight("zcnpc_label")) / 2

		UI.TextSpaced("CURRENTLY LOADED", "zcnpc_micro", pad, top, UI.Colors.faint, UI.Scale(1))
		UI.Text(name, "zcnpc_label", pad, top + draw.GetFontHeight("zcnpc_micro") + UI.Scale(2),
			named and UI.Colors.text or UI.Colors.dim)
	end

	UI.Heading(parent, "The three that come with the addon")

	for _, preset in ipairs(ZCNPC.Presets) do
		local row = UI.Row(parent, preset.name, preset.desc)
		local load = UI.Button(row, "Load", true)
		load:SetSize(UI.Scale(96), UI.Scale(32))
		load:SetEnabled(MayChange())
		load.DoClick = function() AskPreset(preset.id) end

		row:SetControl(load)
	end

	UI.Heading(parent, "Your own")

	local list = vgui.Create("DComboBox", parent)
	list:Dock(TOP)
	list:SetTall(UI.Scale(32))
	list:SetFont("zcnpc_chip")
	list:SetTextColor(UI.Colors.text)
	list:SetSortItems(true)
	list:SetValue("Your saved presets")

	-- Wrapped rather than replaced: this is Derma's own control, and what it does
	-- with a click is open its list.
	local opened = list.DoClickInternal

	list.DoClickInternal = function(self, ...)
		UI.Sound("tab")

		if isfunction(opened) then return opened(self, ...) end
	end

	list.OnSelect = function() UI.Sound("click") end

	list.Paint = function(self, w, h)
		local hover = UI.Ease(self, "zcnpc_hover", (self:IsHovered() or self:IsMenuOpen()) and 1 or 0, 14)

		UI.Box(0, 0, w, h, UI.Mix(UI.Colors.row, UI.Colors.rowHover, hover), UI.Scale(6))
		UI.Gloss(0, 0, w, h, Color(255, 255, 255, 6 + 10 * hover), UI.Scale(6), w, h * 0.6, "down")

		-- Drawn rather than typed: an arrow out of a font is an arrow that is only
		-- there on machines that have that glyph.
		local size = UI.Scale(4)
		local cx, cy = w - UI.Scale(16), h / 2

		surface.SetDrawColor(UI.Mix(UI.Colors.faint, UI.Colors.text, hover))
		draw.NoTexture()
		surface.DrawPoly({
			{ x = cx - size, y = cy - size / 2 },
			{ x = cx + size, y = cy - size / 2 },
			{ x = cx, y = cy + size },
		})
	end

	local function Refill()
		list:Clear()
		list:SetValue("Your saved presets")

		for name, values in SortedPairs(Saved()) do
			list:AddChoice(name, values)
		end
	end

	Refill()

	local buttons = vgui.Create("DPanel", parent)
	buttons:Dock(TOP)
	buttons:DockMargin(0, UI.Scale(8), 0, UI.Scale(8))
	buttons:SetTall(UI.Scale(38))
	buttons:SetPaintBackground(false)

	local load = UI.Button(buttons, "Load selected")
	load:Dock(LEFT)
	load:SetWide(UI.Scale(160))
	load:SetEnabled(MayChange())
	load.DoClick = function()
		local name, values = list:GetSelected()
		if not (name and istable(values)) then return end

		AskPreset(nil, values)
	end

	local drop = UI.Button(buttons, "Delete selected")
	drop:Dock(LEFT)
	drop:DockMargin(UI.Scale(8), 0, 0, 0)
	drop:SetWide(UI.Scale(160))
	drop.DoClick = function()
		local name = list:GetSelected()
		if not name then return end

		local saved = Saved()
		saved[name] = nil
		Store(saved)

		Refill()
	end

	local name = UI.TextEntry(parent, "Name for a new preset")
	name:Dock(TOP)

	local save = UI.Button(parent, "Save what the server is running now")
	save:Dock(TOP)
	save:DockMargin(0, UI.Scale(6), 0, UI.Scale(8))
	save.DoClick = function()
		local given = string.Trim(name:GetValue() or "")
		if given == "" then
			UI.Alert("Nothing to call it", "Give the preset a name in the box above first - it is what you will be picking it out of the list by.")

			return
		end

		local saved = Saved()
		saved[given] = Snapshot()
		Store(saved)

		name:SetValue("")
		Refill()
	end

	UI.Note(parent, "Saved presets are kept on your own machine, so you can load them again on any server you have rights on.")

	UI.Heading(parent, "Back to the start")

	local defaults = UI.Button(parent, "Put every setting back to its default", true)
	defaults:Dock(TOP)
	defaults:SetEnabled(MayChange())
	defaults.DoClick = function()
		UI.Confirm("Back to the defaults",
			"Every setting on every page goes back to the value it shipped with, for everybody on the server. Presets you have saved are not touched.",
			"Put them back", function() RunConsoleCommand("zcnpc_defaults") end)
	end
end
--//

--\\ The window
local frame

local C = UI.Colors
local RADIUS = 10 -- the window's corner, in unscaled pixels

-- The bridge is "installed or not" rather than a setting, so the window reports
-- whether it found its addon instead of offering a switch for it. Drawn as a lamp
-- and a name: green is an addon that is here and being driven. The point of having
-- it in the corner at all is that "why is nothing falling over properly" is nearly
-- always this being off.
--
-- Only the two that actually take the ragdoll. ReAgdoll and Artagdoll cannot
-- both drive at once (sv_reagdoll.lua), so the lamp is "driving", not "found".
-- Manhunt / EEER are bridges as well, but they do not own the body — listing
-- them here was two extra lamps that always said "driving bodies" and answered
-- nothing. The server works the rest out and replicates it (sv_config.lua).
local BRIDGES = {
	{ name = "Artagdoll", cvar = "zcnpc_bridge_artagdoll" },
	{ name = "ReAgdoll", cvar = "zcnpc_bridge_reagdoll" },
}

local BRIDGE_STATE = {
	[0] = { text = "not installed", lamp = false, dim = false },
	[1] = { text = "installed, standing by", lamp = false, dim = true },
	[2] = { text = "driving bodies", lamp = true, dim = true },
}

local function BuildFooter(parent)
	local footer = vgui.Create("DPanel", parent)
	footer:Dock(BOTTOM)
	-- The name and version, then a line per bridge. Counted rather than picked, so
	-- that adding one to the list above cannot quietly push the last one out of
	-- sight.
	footer:SetTall(UI.Scale(24) + draw.GetFontHeight("zcnpc_help") * (#BRIDGES + 1))
	footer:SetPaintBackground(false)

	footer.Paint = function(_, w, h)
		UI.Fade(0, 0, w, 1, C.line, "right")

		local line = draw.GetFontHeight("zcnpc_help")
		local y = UI.Scale(10)

		UI.Text("Z-City NPC Overhaul", "zcnpc_help", 0, y, C.dim)
		UI.Text(ZCNPC.Version or "", "zcnpc_help", w, y, C.faint, TEXT_ALIGN_RIGHT)

		y = y + line + UI.Scale(4)

		for _, bridge in ipairs(BRIDGES) do
			local cvar = GetConVar(bridge.cvar)
			local state = BRIDGE_STATE[cvar and cvar:GetInt() or 0] or BRIDGE_STATE[0]
			local dot = UI.Scale(5)

			UI.Box(0, y + line / 2 - dot / 2, dot, dot, state.lamp and C.good or C.off, dot / 2)
			UI.Text(bridge.name, "zcnpc_help", dot + UI.Scale(7), y, C.faint)
			UI.Text(state.text, "zcnpc_help", w, y, state.dim and C.dim or C.faint, TEXT_ALIGN_RIGHT)

			y = y + line
		end
	end

	return footer
end

local function BuildSidebar(parent, pages)
	local side = vgui.Create("DPanel", parent)
	side:Dock(LEFT)
	side:SetWide(UI.Scale(224))
	side:DockPadding(UI.Scale(12), UI.Scale(12), UI.Scale(12), UI.Scale(12))

	side.Paint = function(_, w, h)
		UI.BoxEx(0, 0, w, h, C.side, UI.Scale(RADIUS), false, false, true, false)
		UI.Fade(0, 0, w, h * 0.4, Color(255, 255, 255, 5), "down")
		UI.Line(w - 1, 0, 1, h, C.line)
	end

	local buttons = {}

	local function Select(entry)
		for _, other in ipairs(buttons) do
			other.on = other.entry == entry

			if other.on then side.mark = other end
		end

		pages(entry)
	end

	for _, entry in ipairs(ZCNPC.MenuPages) do
		local button = vgui.Create("DButton", side)
		button:Dock(TOP)
		button:DockMargin(0, 0, 0, UI.Scale(3))
		button:SetTall(UI.Scale(36))
		button:SetText("")

		button.entry = entry
		button.icon = Material(entry.icon or "icon16/cog.png")

		button.DoClickInternal = function(self)
			-- Clicking the page that is already open is not a page turn.
			if not self.on then UI.Sound("page") end
		end

		button.Paint = function(self, w, h)
			local on = UI.Ease(self, "zcnpc_on", self.on and 1 or 0, 14)
			local hover = UI.Hover(self)

			local colour = UI.Mix(UI.Mix(C.side, C.rowHover, hover), C.accentDim, on)

			UI.Box(0, 0, w, h, colour, UI.Scale(6))

			if on > 0.01 then
				UI.Gloss(0, 0, w, h, ColorAlpha(C.accent, 60 * on), UI.Scale(6), w * 0.7, h, "right")
			end

			-- The icons are 16px stamps, so they are drawn at 16 scaled up rather
			-- than at whatever the row happens to be: a smudged icon is worse than
			-- a small one.
			local icon = UI.Scale(16)

			surface.SetDrawColor(255, 255, 255, 150 + 105 * math.max(on, hover))
			surface.SetMaterial(self.icon)
			surface.DrawTexturedRect(UI.Scale(14), h / 2 - icon / 2, icon, icon)

			UI.Text(entry.name, "zcnpc_tab", UI.Scale(14) + icon + UI.Scale(10),
				h / 2 - draw.GetFontHeight("zcnpc_tab") / 2, UI.Mix(C.dim, C.text, math.max(on, hover)))
		end

		button.DoClick = function(self) Select(self.entry) end

		buttons[#buttons + 1] = button
	end

	-- Over the buttons rather than under them, because the mark belongs to the
	-- sidebar and not to any one page: it slides from the page that was open to
	-- the one that is, which is the window saying which way it just moved.
	side.PaintOver = function(self, w, h)
		local mark = self.mark
		if not IsValid(mark) then return end

		local tall = mark:GetTall() * 0.55
		local y = UI.Ease(self, "zcnpc_mark", mark:GetY() + mark:GetTall() / 2 - tall / 2, 16)

		UI.Box(0, y, UI.Scale(3), tall, C.accent, UI.Scale(2))
	end

	BuildFooter(side)

	if buttons[1] then Select(buttons[1].entry) end

	return side
end

function ZCNPC.CloseMenu()
	if not IsValid(frame) then
		frame = nil

		return
	end

	if frame.zcnpc_closing then return end
	frame.zcnpc_closing = true

	UI.Sound("close")

	-- Let go of the mouse and the keyboard now rather than in a tenth of a second:
	-- the window is over as far as anybody looking at it is concerned, and holding
	-- the keyboard for the length of a fade is how a menu eats a movement key.
	frame:SetMouseInputEnabled(false)
	frame:SetKeyboardInputEnabled(false)

	frame:AlphaTo(0, 0.1, 0, function(_, panel)
		if IsValid(panel) then panel:Remove() end

		frame = nil
	end)
end

function ZCNPC.OpenMenu()
	if IsValid(frame) then return ZCNPC.CloseMenu() end

	local wide = math.min(ScrW() * 0.8, UI.Scale(1000))
	local tall = math.min(ScrH() * 0.85, UI.Scale(700))
	local top = UI.Scale(66)

	frame = vgui.Create("DFrame")
	frame:SetSize(wide, tall)
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetSizable(true)
	frame:SetMinWidth(UI.Scale(760))
	frame:SetMinHeight(UI.Scale(480))
	frame:MakePopup()

	-- Faded in rather than appearing, and the blur behind it grows over the same
	-- moment, so opening the window is one movement instead of the game being
	-- replaced by a rectangle.
	frame.zcnpc_opened = SysTime()
	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.12, 0)

	frame.Paint = function(self, w, h)
		UI.Blur(self, self.zcnpc_opened)
		UI.Shadow(0, 0, w, h, UI.Scale(RADIUS))
		UI.Box(0, 0, w, h, C.bg, UI.Scale(RADIUS))
	end

	-- The window has the keyboard while it is open, so closing it with the key that
	-- opened it is its own job as much as escape's.
	frame.OnKeyCodePressed = function(_, key)
		if key == KEY_ESCAPE or key == keyCvar:GetInt() then ZCNPC.CloseMenu() end
	end

	--\\ The head of the window
	local header = vgui.Create("DPanel", frame)
	header:Dock(TOP)
	header:SetTall(top)

	header.Paint = function(_, w, h)
		UI.BoxEx(0, 0, w, h, C.panel, UI.Scale(RADIUS), true, true, false, false)
		UI.Gloss(0, 0, w, h, Color(255, 255, 255, 8), UI.Scale(RADIUS), w, h, "down",
			true, true, false, false)

		-- Brightest under the title and gone by the middle of the window, which
		-- is a line that belongs to the name rather than a rule across the top.
		UI.Fade(0, h - UI.Scale(2), w * 0.55, UI.Scale(2), C.accent, "right")
		UI.Line(0, h - 1, w, 1, ColorAlpha(C.line, 120))

		local pad = UI.Scale(20)
		local title = draw.GetFontHeight("zcnpc_title")
		local y = h / 2 - (title + draw.GetFontHeight("zcnpc_sub")) / 2

		UI.Box(pad, y + UI.Scale(4), UI.Scale(4), title - UI.Scale(6), C.accent, UI.Scale(2))

		UI.Text("Z-City NPC Overhaul", "zcnpc_title", pad + UI.Scale(14), y, C.text)
		UI.Text("NPCs that bleed, break and get back up", "zcnpc_sub", pad + UI.Scale(14),
			y + title - UI.Scale(2), C.faint)
	end

	-- DFrame only drags from its own top 24 pixels, which on a header this tall is
	-- the strip above the title. Dragging is handed to the whole of it instead -
	-- the frame's own Think does the moving, this only says when it started.
	header.OnMousePressed = function(_, key)
		if key ~= MOUSE_LEFT then return end

		frame.Dragging = { gui.MouseX() - frame:GetX(), gui.MouseY() - frame:GetY() }
		frame:MouseCapture(true)
	end

	local close = vgui.Create("DButton", header)
	close:Dock(RIGHT)
	close:DockMargin(0, UI.Scale(18), UI.Scale(18), UI.Scale(18))
	close:SetWide(UI.Scale(30))
	close:SetText("")

	close.Paint = function(self, w, h)
		local hover = UI.Hover(self)

		if hover > 0.01 then
			UI.Box(0, 0, w, h, ColorAlpha(C.accent, 190 * hover), UI.Scale(6))
		end

		draw.SimpleText("×", "zcnpc_title", w / 2, h / 2 - UI.Scale(2),
			UI.Mix(C.dim, C.text, hover), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	close.DoClick = ZCNPC.CloseMenu
	--//

	local content = vgui.Create("DPanel", frame)
	content:Dock(FILL)
	content:SetPaintBackground(false)

	local page

	local function Show(entry)
		if IsValid(page) then page:Remove() end

		page = UI.Scroll(content)
		page:Dock(FILL)
		page:DockMargin(UI.Scale(18), UI.Scale(14), UI.Scale(12), UI.Scale(14))

		-- Faded in on its own, so a page turn is the sidebar mark sliding and the
		-- new page arriving behind it rather than the whole window blinking.
		page:SetAlpha(0)
		page:AlphaTo(255, 0.14, 0)

		local canvas = page:GetCanvas()

		if entry.build then
			entry.build(canvas)
		else
			Pages.Settings(canvas, entry)
		end
	end

	BuildSidebar(content, Show)

	--\\ The corner to pull on
	-- DFrame sizes from its own bottom right corner, and that corner is covered by
	-- the page. So the grip is a panel of its own that says where the drag started
	-- and lets the frame's Think do the rest.
	local grip = vgui.Create("DPanel", frame)
	grip:SetSize(UI.Scale(18), UI.Scale(18))
	grip:SetCursor("sizenwse")
	grip:SetPaintBackground(false)

	grip.Paint = function(self, w, h)
		local hover = UI.Hover(self)
		local dot = UI.Scale(3)

		for i = 0, 2 do
			UI.Box(w - dot * (i + 1) * 2, h - dot * 2, dot, dot, UI.Mix(C.line, C.accent, hover), dot / 2)
			UI.Box(w - dot * 2, h - dot * (i + 1) * 2, dot, dot, UI.Mix(C.line, C.accent, hover), dot / 2)
		end
	end

	grip.OnMousePressed = function(_, key)
		if key ~= MOUSE_LEFT then return end

		frame.Sizing = { gui.MouseX() - frame:GetWide(), gui.MouseY() - frame:GetTall() }
		frame:MouseCapture(true)
	end

	frame.PerformLayout = function(self, w, h)
		-- DFrame's own layout puts its title label back where it wants it; ours
		-- has none, so this is only here to keep the grip in the corner.
		grip:SetPos(w - grip:GetWide() - UI.Scale(4), h - grip:GetTall() - UI.Scale(4))
	end
	--//

	UI.Sound("open")

	return frame
end

concommand.Add("zcnpc_menu", ZCNPC.OpenMenu, nil, "Open the Z-City NPC Overhaul settings menu")
--//

--\\ The pages, in the order the sidebar shows them
ZCNPC.MenuPages = {}

for _, category in ipairs(ZCNPC.Categories) do
	ZCNPC.MenuPages[#ZCNPC.MenuPages + 1] = category
end

ZCNPC.MenuPages[#ZCNPC.MenuPages + 1] = {
	id = "loadouts",
	name = "NPC Weapons",
	icon = "icon16/gun.png",
	build = Pages.Loadouts,
}

ZCNPC.MenuPages[#ZCNPC.MenuPages + 1] = {
	id = "armour",
	name = "NPC Armour",
	icon = "icon16/shield.png",
	build = Pages.Armour,
}

ZCNPC.MenuPages[#ZCNPC.MenuPages + 1] = {
	id = "presets",
	name = "Presets",
	icon = "icon16/wand.png",
	build = Pages.Presets,
}
--//

--\\ The key
-- F6 is the default because it is free in sandbox. Under the zcity gamemode it is
-- not: the mode menu there is opened straight from a key hook of its own, on that key
-- and no other, with no console command to fall back on
-- (gamemodes/zcity/gamemode/libraries/cl_modeselect_menu.lua:617).
--
-- Sharing the key does not give an admin two windows. It gives them one they can see and
-- one they cannot: ours takes the focus with MakePopup, theirs opens unfocused behind it.
-- And theirs will not open again while that frame is alive, because the frame is the
-- guard and it is cleared from the frame's own close, at the end of an animation that
-- never runs if nobody ever closes it. F6 stops working, and stays that way.
--
-- So we step off the key instead of sharing it, and only while it is still the one we
-- picked - somebody who set F6 themselves keeps it.
local GAMEMODE_KEY_HOOK = "OpenAdminMenuF6"

local function GamemodeOwnsF6()
	local group = hook.GetTable()["PlayerButtonDown"]

	return istable(group) and isfunction(group[GAMEMODE_KEY_HOOK])
end

local function StepOffF6()
	if keyCvar:GetInt() ~= KEY_F6 then return end
	if not GamemodeOwnsF6() then return end

	RunConsoleCommand("zcnpc_menu_key", tostring(KEY_F7))

	MsgC(Color(255, 200, 90),
		"[ZCNPC] F6 belongs to this gamemode's own menu, so the settings window is on F7 (zcnpc_menu_key).\n")
end

-- A second after everything else, because the hook we are looking for belongs to the
-- gamemode and this file is an addon's: ours loads first on any mount order.
hook.Add("InitPostEntity", "zcnpc_menu_key_conflict", function()
	timer.Simple(1, StepOffF6)
end)

-- PlayerButtonDown rather than polling: a key that is held down should open the
-- window once. Nothing is opened while somebody is typing, which includes the
-- console and this window's own search box.
hook.Add("PlayerButtonDown", "zcnpc_menu_key", function(ply, key)
	if ply ~= LocalPlayer() then return end

	local want = keyCvar:GetInt()
	if want <= 0 or key ~= want then return end

	if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return end

	-- Somebody typing is not somebody opening a menu. The window itself is the
	-- exception: it holds the keyboard while it is open, and the same key that
	-- opened it should shut it.
	local focus = vgui.GetKeyboardFocus()
	if IsValid(focus) and focus ~= frame then return end

	ZCNPC.OpenMenu()
end)
--//
