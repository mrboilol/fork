hg = hg or {}
hg.FreezeGuard = hg.FreezeGuard or {}

local FG = hg.FreezeGuard

FG.DIR = "hg_freezeguard"
FG.REALM = SERVER and "sv" or "cl"
FG.NET = "hg_freezeguard"
FG.FREEZE_TIME = 3
FG.HITCH_TIME = 0.25
FG.SLOW_CALL_TIME = 0.05
FG.MSG_FREEZE = 0
FG.MSG_HELLO = 1
FG.MSG_RESULT = 2

local MAX_EVENTS = 80
local MAX_NET = 15
local MAX_LOGS = 25
local MAX_ERROR_KEYS = 500
local TOP_CLASSES = 10
local SUSPECT_SHARE = 0.5
local SUSPECT_SLACK = 0.1
local WATCHDOG_LIMIT = 5
local WATCHDOG_COUNT = 100000
local WATCHDOG_IDLE = 2
local ARM_TIME = 15
local ERROR_REPORT_COUNTS = {[1] = true, [10] = true, [100] = true, [1000] = true}
local ORGANISM_KEYS = {"alive", "otrub", "consciousness", "blood", "pain", "heartbeat", "o2", "brain", "stamina"}
local LOG_COLOR = Color(255, 90, 90)

FG.events = FG.events or {}
FG.netRing = FG.netRing or {}
FG.errorCounts = FG.errorCounts or {}
FG.errorKeys = FG.errorKeys or 0
FG.beatId = FG.beatId or 0
FG.sessionState = FG.sessionState or "running"

local function Push(list, entry, max)
	list[#list + 1] = entry
	if #list > max then table.remove(list, 1) end
end

local function Add(lines, key, value)
	lines[#lines + 1] = key .. ": " .. tostring(value)
end

function FG.Event(msg)
	Push(FG.events, os.date("%H:%M:%S") .. "  " .. msg, MAX_EVENTS)
end

hook.Add("OnLuaError", "hg_freezeguard", function(err, realm, stack, addon)
	if FG.errorKeys > MAX_ERROR_KEYS then
		FG.errorCounts = {}
		FG.errorKeys = 0
	end

	local count = (FG.errorCounts[err] or 0) + 1
	if count == 1 then FG.errorKeys = FG.errorKeys + 1 end
	FG.errorCounts[err] = count
	if not ERROR_REPORT_COUNTS[count] then return end

	local top = istable(stack) and istable(stack[1]) and stack[1]
	local where = top and string.format(" @ %s:%s", tostring(top.File), tostring(top.Line)) or ""
	local source = addon and ", " .. addon or ""
	FG.Event(string.format("lua error x%d (%s%s): %s%s", count, tostring(realm), source, tostring(err), where))
end)

function FG.Timed(label, dt)
	if dt < FG.SLOW_CALL_TIME then return end

	FG.Event(string.format("slow %s: %.0f ms", label, dt * 1000))
	local slow = FG.lastSlow
	local now = SysTime()
	if slow and now - slow.at < 1 and slow.dt >= dt then return end
	FG.lastSlow = {label = label, dt = dt, at = now}
end

local wrappedNet = setmetatable({}, {__mode = "k"})

local function WrapReceiver(name, fn)
	local label = "net " .. name
	local wrapper = function(len, ply)
		local entry = {at = SysTime(), name = name, bytes = math.floor(len / 8)}
		Push(FG.netRing, entry, MAX_NET)
		fn(len, ply)
		entry.dt = SysTime() - entry.at
		FG.Timed(label, entry.dt)
	end
	wrappedNet[wrapper] = true

	return wrapper
end

function FG.WrapNet()
	for name, fn in pairs(net.Receivers) do
		if isfunction(fn) and not wrappedNet[fn] then net.Receivers[name] = WrapReceiver(name, fn) end
	end
end

function FG.Suspect(gap, now)
	if FG.hangTrace then return "a Lua hang, broken by the watchdog (stack below)" end

	local slow = FG.lastSlow
	FG.lastSlow = nil
	local inWindow = slow and slow.at >= now - gap - SUSPECT_SLACK
	if inWindow and slow.dt >= gap * SUSPECT_SHARE then
		return string.format("%s took %.2fs", slow.label, slow.dt)
	end

	return "nothing in tracked Lua was slow, so likely engine side (physics, rendering, disk). "
		.. "Check the entity counts below; turn on the watchdog convar to catch Lua hangs"
end

function FG.PlayerLines(ply, lines)
	if not IsValid(ply) then return end

	Add(lines, "player", ply:Nick() .. " (" .. ply:SteamID() .. ")")
	Add(lines, "alive", ply:Alive())
	Add(lines, "health", ply:Health())
	Add(lines, "team", team.GetName(ply:Team()) .. " (" .. ply:Team() .. ")")
	Add(lines, "position", ply:GetPos())
	Add(lines, "ping", ply:Ping())
	local wep = ply:GetActiveWeapon()
	Add(lines, "weapon", IsValid(wep) and wep:GetClass() or "none")
	local rag = ply:GetNWEntity("FakeRagdoll")
	Add(lines, "fake ragdoll", IsValid(rag) and tostring(rag) or "no")

	local org = ply.organism
	if not istable(org) then return end

	for _, key in ipairs(ORGANISM_KEYS) do
		local value = org[key]
		if value ~= nil and not istable(value) then Add(lines, "organism." .. key, value) end
	end
end

local function ClassSummary()
	local counts, total = {}, 0
	for _, ent in ipairs(ents.GetAll()) do
		total = total + 1
		local class = ent:GetClass()
		counts[class] = (counts[class] or 0) + 1
	end

	local list = {}
	for class, n in pairs(counts) do list[#list + 1] = {class, n} end
	table.sort(list, function(a, b) return a[2] > b[2] end)

	local parts = {}
	for i = 1, math.min(TOP_CLASSES, #list) do parts[i] = list[i][1] .. " x" .. list[i][2] end

	return total, table.concat(parts, ", ")
end

local function NetLines(lines, now)
	for _, entry in ipairs(FG.netRing) do
		local took = entry.dt and string.format("%.1f ms", entry.dt * 1000) or "errored or never finished"
		lines[#lines + 1] = string.format("%.1fs ago  %s  %d bytes  %s", now - entry.at, entry.name, entry.bytes, took)
	end
end

function FG.Report(header, extra)
	local now = SysTime()
	local lines = {"=== " .. header .. " ==="}
	Add(lines, "time", os.date("%Y-%m-%d %H:%M:%S"))
	Add(lines, "server", GetHostName())
	Add(lines, "map", game.GetMap())
	for _, line in ipairs(extra or {}) do lines[#lines + 1] = line end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "--- state ---"
	Add(lines, "realm", FG.REALM)
	Add(lines, "lua memory", string.format("%.1f MB", collectgarbage("count") / 1024))
	Add(lines, "players", player.GetCount())
	local total, top = ClassSummary()
	Add(lines, "entities", total)
	Add(lines, "most common", top)
	if zb then Add(lines, "round state", zb.ROUND_STATE) end
	if FG.ExtraState then FG.ExtraState(lines) end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "--- last net messages (oldest first) ---"
	NetLines(lines, now)

	lines[#lines + 1] = ""
	lines[#lines + 1] = "--- recent events (oldest first) ---"
	for _, line in ipairs(FG.events) do lines[#lines + 1] = line end

	return table.concat(lines, "\n")
end

function FG.SaveLog(kind, text)
	file.CreateDir(FG.DIR)
	local path = string.format("%s/%s_%s_%s.txt", FG.DIR, FG.REALM, os.date("%Y-%m-%d_%H-%M-%S"), kind)
	file.Write(path, text)

	local old = file.Find(FG.DIR .. "/" .. FG.REALM .. "_*.txt", "DATA", "datedesc")
	for i = MAX_LOGS + 1, #old do file.Delete(FG.DIR .. "/" .. old[i]) end

	MsgC(LOG_COLOR, "[FreezeGuard] ", color_white, "log saved to garrysmod/data/" .. path .. "\n")
	for _, line in ipairs(string.Explode("\n", text)) do MsgN(line) end

	return path
end

local function SessionPath()
	return FG.DIR .. "/session_" .. FG.REALM .. ".txt"
end

function FG.WriteSession()
	file.CreateDir(FG.DIR)
	file.Write(SessionPath(), "state=" .. FG.sessionState .. "\n" .. FG.Report("last heartbeat before the session ended"))
end

function FG.ReadPreviousSession()
	local text = file.Read(SessionPath(), "DATA")
	if not text then return end

	local state = string.match(text, "^state=(%a+)")
	if not state or state == "clean" then return end

	local body = string.gsub(text, "^state=%a+\n", "")

	return state, body
end

function FG.Beat()
	FG.beatId = FG.beatId + 1
end

local seenId, seenAt, lastHookAt = -1, 0, 0

local function Watchdog()
	local now = SysTime()
	if FG.beatId ~= seenId or now - lastHookAt > WATCHDOG_IDLE then
		seenId, seenAt = FG.beatId, now
	end
	lastHookAt = now
	if now - seenAt < WATCHDOG_LIMIT then return end

	seenAt = now
	FG.hangTrace = debug.traceback("stack of the hung code:", 2)
	FG.Event("watchdog broke a Lua hang after " .. WATCHDOG_LIMIT .. "s without a frame")
	error("[FreezeGuard] broke a Lua hang that ran " .. WATCHDOG_LIMIT .. "s without a frame", 2)
end

function FG.SetWatchdog(on)
	local current = debug.gethook()
	local ours = current ~= nil and current == FG.watchdogFn

	if on and (current == nil or ours) then
		FG.watchdogFn = Watchdog
		debug.sethook(Watchdog, "", WATCHDOG_COUNT)
	elseif on then
		FG.Event("watchdog not started: debug.sethook is already used by another addon")
	elseif ours then
		debug.sethook()
		FG.watchdogFn = nil
	end
end

function FG.ArmWatchdog(duration)
	FG.SetWatchdog(true)
	timer.Create("hg_freezeguard_arm", duration, 1, function()
		FG.SetWatchdog(FG.WatchdogWanted and FG.WatchdogWanted() or false)
	end)
end

hook.Add("PreCleanupMap", "hg_freezeguard", function()
	FG.Event("map cleanup started")
	FG.ArmWatchdog(ARM_TIME)
end)

hook.Add("PostCleanupMap", "hg_freezeguard", function()
	FG.Event("map cleanup finished")
end)
