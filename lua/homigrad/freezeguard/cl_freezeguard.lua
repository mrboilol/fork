hg = hg or {}
hg.FreezeGuard = hg.FreezeGuard or {}

local FG = hg.FreezeGuard

local LOST_TIME = 5
local RETRY_MARGIN = 5
local MIN_RETRY_TIME = 10
local DEFAULT_TIMEOUT = 30
local CONNECTION_GRACE = 3
local FREEZE_SCREEN_TIME = 20
local HEARTBEAT_INTERVAL = 2
local NET_WRAP_INTERVAL = 10
local HELLO_DELAY = 2
local MAX_CAUSE = 200
local RELEASE_COMMANDS = {
	"-attack", "-attack2", "-forward", "-back", "-moveleft", "-moveright",
	"-jump", "-duck", "-speed", "-walk", "-use", "-reload",
}
local PREVIOUS_TITLES = {
	running = "lmao you crashed",
	frozen = "your game froze nerd",
}

local COLOR_BG = Color(10, 10, 12, 240)
local COLOR_BOX = Color(24, 24, 28, 255)
local COLOR_ACCENT = Color(220, 60, 60)
local COLOR_TEXT = Color(235, 235, 235)

local cvWatchdog = CreateClientConVar("hg_freezeguard_watchdog_cl", "0", true, false,
	"Break client Lua hangs longer than 5s and log where they were stuck. Slows LuaJIT while on.", 0, 1)

local loaded = false
local lastThink = SysTime()
local lastFreezeAt = 0
local lostSince
local autoRetry = true
local serverResult = ""
local screen
local fps, fpsFrames, fpsWindowStart = 0, 0, SysTime()

local function CreateFonts()
	local h = ScrH()
	surface.CreateFont("hg_freezeguard_title", {font = "Roboto", size = math.Round(h * 0.06), weight = 800})
	surface.CreateFont("hg_freezeguard_text", {font = "Roboto", size = math.Round(h * 0.022), weight = 500})
	surface.CreateFont("hg_freezeguard_log", {font = "Courier New", size = math.Round(h * 0.016), weight = 500})
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "hg_freezeguard", CreateFonts)

function FG.ExtraState(lines)
	local timedOut, sinceReceived = GetTimeoutInfo()
	lines[#lines + 1] = "fps: " .. fps
	local status = timedOut and "timing out" or "ok"
	lines[#lines + 1] = string.format("connection: %s, last packet %.1fs ago", status, sinceReceived)
	FG.PlayerLines(LocalPlayer(), lines)
end

local function CloseScreen(mode)
	if not IsValid(screen) then return end
	if mode and screen.mode ~= mode then return end

	screen:Remove()
	screen = nil
end

local function Label(value)
	return isfunction(value) and value() or value
end

local function AddButton(bar, label, onClick)
	local button = vgui.Create("DButton", bar)
	button:SetText("")
	button:Dock(LEFT)
	button:DockMargin(0, 0, ScrH() * 0.01, 0)
	button:SetWide(ScrW() * 0.14)
	button.Paint = function(self, w, h)
		draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and COLOR_ACCENT or COLOR_BOX)
		draw.SimpleText(Label(label), "hg_freezeguard_text", w / 2, h / 2, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.DoClick = onClick
end

local function ShowScreen(opts)
	CloseScreen()

	local w, h = ScrW(), ScrH()
	local side = w * 0.12
	local panel = vgui.Create("EditablePanel")
	panel:SetSize(w, h)
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(false)
	panel:DockPadding(side, h * 0.3, side, h * 0.08)
	panel.mode = opts.mode
	panel.closeAt = opts.autoClose and RealTime() + opts.autoClose
	panel.Paint = function(_, pw, ph)
		surface.SetDrawColor(COLOR_BG)
		surface.DrawRect(0, 0, pw, ph)
		draw.SimpleText(opts.title, "hg_freezeguard_title", side, ph * 0.08, COLOR_ACCENT)
		draw.DrawText(Label(opts.subtitle), "hg_freezeguard_text", side, ph * 0.16, COLOR_TEXT)
	end
	panel.Think = function(self)
		if self.closeAt and RealTime() >= self.closeAt then CloseScreen() end
	end

	local bar = vgui.Create("Panel", panel)
	bar:Dock(BOTTOM)
	bar:SetTall(h * 0.05)
	bar:DockMargin(0, h * 0.02, 0, 0)
	for _, button in ipairs(opts.buttons) do AddButton(bar, button[1], button[2]) end

	local log = vgui.Create("DTextEntry", panel)
	log:Dock(FILL)
	log:SetMultiline(true)
	log:SetVerticalScrollbarEnabled(true)
	log:SetFont("hg_freezeguard_log")
	log:SetText(opts.log or "")
	log.Paint = function(self, lw, lh)
		draw.RoundedBox(4, 0, 0, lw, lh, COLOR_BOX)
		self:DrawTextEntryText(COLOR_TEXT, COLOR_ACCENT, COLOR_TEXT)
	end

	screen = panel
end

local function Rejoin()
	FG.Event("rejoining the server")
	FG.sessionState = "retry"
	FG.WriteSession()
	RunConsoleCommand("retry")
end

local function RetryAt()
	local cv = GetConVar("cl_timeout")
	local limit = cv and cv:GetFloat() or DEFAULT_TIMEOUT

	return math.max(limit - RETRY_MARGIN, MIN_RETRY_TIME)
end

local function LostRejoin()
	local _, since = GetTimeoutInfo()
	local extra = {string.format("no packets from the server for %.1fs, rejoining", since)}
	FG.SaveLog("connection_lost", FG.Report("host stopped responding", extra))
	Rejoin()
end

local function LostSubtitle()
	local _, since = GetTimeoutInfo()
	local head = string.format("No packets from the server for %.0f seconds.", since)
	if not autoRetry then return head .. "\nauto rejoin is off gg" end

	return head .. string.format("\ncoming back in %.0f seconds if it does not come back", math.max(0, RetryAt() - since))
end

local function ShowLostScreen()
	autoRetry = true
	ShowScreen({
		mode = "lost",
		title = "host exploded",
		subtitle = LostSubtitle,
		log = FG.Report("host stopped responding"),
		buttons = {
			{"rejoin", LostRejoin},
			{function() return autoRetry and "no more auto rejoin" or "auto rejoin is off gg" end, function() autoRetry = false end},
			{"close", function() CloseScreen() end},
		},
	})
end

local function CheckConnection(now)
	local timedOut, since = GetTimeoutInfo()
	local lost = timedOut and since >= LOST_TIME and now - lastFreezeAt > CONNECTION_GRACE

	if lost then
		if not lostSince then
			lostSince = now
			FG.Event("host stopped responding")
			ShowLostScreen()
		end
		if autoRetry and since >= RetryAt() then
			autoRetry = false
			LostRejoin()
		end

		return
	end

	if not lostSince then return end

	FG.Event(string.format("server came back after %.1fs", now - lostSince))
	lostSince = nil
	CloseScreen("lost")
	chat.AddText(COLOR_ACCENT, "[FreezeGuard] ", COLOR_TEXT, "The server is responding again.")
end

local function Recover()
	for _, cmd in ipairs(RELEASE_COMMANDS) do RunConsoleCommand(cmd) end
	RunConsoleCommand("stopsound")
	collectgarbage()

	return {"released held keys", "stopped stuck sounds", "cleared lua goyslop"}
end

local function ShowFreezeScreen(gap, text, path, actions)
	local closeAt = RealTime() + FREEZE_SCREEN_TIME
	serverResult = "asking the server to check on you..."

	ShowScreen({
		mode = "freeze",
		title = "you froze nerd",
		subtitle = function()
			return string.format("yo game stopped responding for %.1f seconds.\nReset: %s.\nServer: %s\nLog: garrysmod/data/%s",
				gap, table.concat(actions, ", "), serverResult, path)
		end,
		log = text,
		autoClose = FREEZE_SCREEN_TIME,
		buttons = {
			{
				function() return string.format("Continue (%.0f)", math.max(0, closeAt - RealTime())) end,
				function() CloseScreen() end,
			},
			{"rejoin", Rejoin},
			{"copy log (give to host)", function() SetClipboardText(text) end},
		},
	})
end

local function OnFreeze(gap, now)
	lastFreezeAt = now

	local suspect = FG.Suspect(gap, now)
	local extra = {string.format("your game froze for %.1fs", gap), "suspect: " .. suspect}
	if FG.hangTrace then
		extra[#extra + 1] = FG.hangTrace
		FG.hangTrace = nil
	end

	local actions = Recover()
	extra[#extra + 1] = "reset: " .. table.concat(actions, ", ")
	local text = FG.Report("your game froze", extra)
	local path = FG.SaveLog("freeze", text)

	net.Start("hg_freezeguard")
	net.WriteUInt(FG.MSG_FREEZE, 2)
	net.WriteFloat(gap)
	net.WriteString(string.sub(suspect, 1, MAX_CAUSE))
	net.SendToServer()

	ShowFreezeScreen(gap, text, path, actions)
end

local function ShowPrevious(state, body)
	if state == "retry" then
		chat.AddText(COLOR_ACCENT, "[FreezeGuard] ", COLOR_TEXT, "Rejoined after the connection problem.")

		return
	end

	local text = "=== your last session ended without shutting down (" .. state .. ") ===\n" .. body
	local path = FG.SaveLog("previous_" .. state, text)
	ShowScreen({
		mode = "previous",
		title = PREVIOUS_TITLES[state] or "your last session died",
		subtitle = "ur last session ended without shutting down cleanly. You're back in.\n"
			.. "below is what was going on right before it happened.\nLog: garrysmod/data/" .. path,
		log = text,
		buttons = {
			{"continue", function() CloseScreen() end},
			{"copy log (give to host)", function() SetClipboardText(text) end},
		},
	})
end

local function CountFps(now)
	fpsFrames = fpsFrames + 1
	if now - fpsWindowStart < 1 then return end

	fps = fpsFrames
	fpsFrames, fpsWindowStart = 0, now
end

net.Receive("hg_freezeguard", function()
	if net.ReadUInt(2) ~= FG.MSG_RESULT then return end

	serverResult = net.ReadString()
	FG.Event("server: " .. serverResult)
	chat.AddText(COLOR_ACCENT, "[FreezeGuard] ", COLOR_TEXT, serverResult)
end)

hook.Add("Think", "hg_freezeguard", function()
	local now = SysTime()
	local gap = now - lastThink
	lastThink = now
	FG.Beat()
	CountFps(now)
	if not loaded then return end

	if gap >= FG.HITCH_TIME then FG.Event(string.format("hitch %.2fs", gap)) end
	if gap >= FG.FREEZE_TIME then OnFreeze(gap, now) end
	CheckConnection(now)
end)

hook.Add("InitPostEntity", "hg_freezeguard", function()
	local state, body = FG.ReadPreviousSession()

	FG.sessionState = "running"
	FG.WriteSession()
	FG.WrapNet()
	FG.SetWatchdog(cvWatchdog:GetBool())
	timer.Create("hg_freezeguard_net", NET_WRAP_INTERVAL, 0, FG.WrapNet)
	timer.Create("hg_freezeguard_heartbeat", HEARTBEAT_INTERVAL, 0, FG.WriteSession)
	lastThink = SysTime()
	loaded = true

	timer.Simple(HELLO_DELAY, function()
		net.Start("hg_freezeguard")
		net.WriteUInt(FG.MSG_HELLO, 2)
		net.WriteString(state or "")
		net.SendToServer()

		if state then ShowPrevious(state, body) end
	end)
end)

hook.Add("ShutDown", "hg_freezeguard", function()
	if not loaded then return end

	if FG.sessionState == "running" then
		FG.sessionState = SysTime() - lastThink >= FG.FREEZE_TIME and "frozen" or "clean"
	end
	FG.WriteSession()
end)

cvars.AddChangeCallback("hg_freezeguard_watchdog_cl", function(_, _, new)
	FG.SetWatchdog(new == "1")
end, "hg_freezeguard")
