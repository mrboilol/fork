hg = hg or {}
hg.FreezeGuard = hg.FreezeGuard or {}

local FG = hg.FreezeGuard

util.AddNetworkString("hg_freezeguard")

local WATCH_INTERVAL = 0.5
local HEARTBEAT_INTERVAL = 5
local NET_WRAP_INTERVAL = 10
local IDLE_DEATH_TIME = 1
local FROZEN_DEATH_TTL = 60
local REJOIN_WINDOW = 300
local REVIVE_DELAY = 1
local MSG_COOLDOWN = 2
local MAX_CAUSE = 200
local MAX_STATE = 16

local cvWatchdog = CreateConVar("hg_freezeguard_watchdog", "0", FCVAR_ARCHIVE,
	"Break server Lua hangs longer than 5s and log where they were stuck. Slows LuaJIT while on.", 0, 1)
local cvRevive = CreateConVar("hg_freezeguard_revive", "1", FCVAR_ARCHIVE,
	"Bring players back if they died or dropped while their game was frozen (once per round).", 0, 1)

FG.revivedRound = FG.revivedRound or {}
FG.pendingRejoin = FG.pendingRejoin or {}

local revivedRound = FG.revivedRound
local pendingRejoin = FG.pendingRejoin
local lastCmd = {}
local lastGood = {}
local frozenDeaths = {}
local timingOut = {}
local nextMsg = {}
local loaded = false
local lastThink = SysTime()
local hadPlayers = false

local function RoundStamp()
	return zb and zb.ROUND_START or 0
end

local function RoundAllowsRevive()
	return not zb or zb.ROUND_STATE == 1
end

local function Capture(ply)
	local weapons = {}
	for _, wep in ipairs(ply:GetWeapons()) do weapons[#weapons + 1] = wep:GetClass() end

	local active = ply:GetActiveWeapon()
	local char = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply)
	local body = IsValid(char) and char or ply

	return {
		pos = body:GetPos(),
		ang = ply:EyeAngles(),
		team = ply:Team(),
		armor = ply:Armor(),
		weapons = weapons,
		active = IsValid(active) and active:GetClass() or nil,
		round = RoundStamp(),
	}
end

local function Revive(ply, save, why)
	if not cvRevive:GetBool() or not save or ply:Alive() or ply.initialspawn then return false end
	if save.round ~= RoundStamp() or not RoundAllowsRevive() then return false end

	local sid = ply:SteamID64()
	if revivedRound[sid] == save.round then return false end
	revivedRound[sid] = save.round

	ply:Spawn()
	ply:SetTeam(save.team)
	ply:SetPos(save.pos)
	ply:SetEyeAngles(Angle(save.ang.p, save.ang.y, 0))
	ply:StripWeapons()
	for _, class in ipairs(save.weapons) do ply:Give(class) end
	if save.active then ply:SelectWeapon(save.active) end
	ply:SetArmor(save.armor)
	FG.Event("revived " .. ply:Nick() .. " (" .. why .. ")")

	return true
end

local function TryFrozenRevive(ply)
	local death = frozenDeaths[ply]
	if not death or SysTime() - death.at > FROZEN_DEATH_TTL then return false end

	frozenDeaths[ply] = nil

	return Revive(ply, death.save, "died while frozen")
end

local function Reply(ply, msg)
	net.Start("hg_freezeguard")
	net.WriteUInt(FG.MSG_RESULT, 2)
	net.WriteString(msg)
	net.Send(ply)
end

local function StartTimeout(ply, now)
	if timingOut[ply] then return end

	local lines = {}
	FG.PlayerLines(ply, lines)
	timingOut[ply] = {since = now, lines = lines}
	FG.Event(ply:Nick() .. " stopped responding")
end

local function EndTimeout(ply, now)
	local info = timingOut[ply]
	if not info then return end

	timingOut[ply] = nil
	local duration = now - info.since
	FG.Event(string.format("%s responding again after %.1fs", ply:Nick(), duration))

	local revived = TryFrozenRevive(ply)
	if revived then Reply(ply, "You died while frozen, so you were put back where you were.") end

	local extra = {
		string.format("%s timed out for %.1fs and came back", ply:Nick(), duration),
		"revived: " .. (revived and "yes" or "no"),
		"",
		"--- player when the timeout started ---",
	}
	table.Add(extra, info.lines)
	FG.SaveLog("timeout", FG.Report("player timed out", extra))
end

local function Watch()
	local now = SysTime()
	for _, ply in ipairs(player.GetHumans()) do
		if ply:IsTimingOut() then
			StartTimeout(ply, now)
			continue
		end

		EndTimeout(ply, now)
		if ply:Alive() and now - (lastCmd[ply] or 0) < WATCH_INTERVAL then lastGood[ply] = Capture(ply) end
	end
end

local function OnFreeze(ply)
	local gap = net.ReadFloat()
	local cause = string.sub(net.ReadString(), 1, MAX_CAUSE)
	if gap ~= gap or gap < 0 then return end

	local revived = TryFrozenRevive(ply)
	local lines = {
		string.format("%s reported their game froze for %.1fs", ply:Nick(), gap),
		"client suspect: " .. cause,
		"revived: " .. (revived and "yes" or "no"),
		"",
		"--- player now ---",
	}
	FG.PlayerLines(ply, lines)
	FG.SaveLog("client_freeze", FG.Report("player froze", lines))

	if revived then
		Reply(ply, "haha you froze so you came back")
	else
		Reply(ply, "nothing needed fixing its cool")
	end
end

local function OnHello(ply)
	local state = string.sub(net.ReadString(), 1, MAX_STATE)
	if state ~= "" then FG.Event(ply:Nick() .. " joined, their last session ended as: " .. state) end

	local sid = ply:SteamID64()
	local pending = pendingRejoin[sid]
	if not pending then return end

	pendingRejoin[sid] = nil
	if SysTime() - pending.at > REJOIN_WINDOW then return end

	timer.Simple(REVIVE_DELAY, function()
		if not IsValid(ply) then return end
		if not Revive(ply, pending.save, "rejoined after dropping while frozen") then return end

		Reply(ply, "you froze so ur back")
	end)
end

local function OnServerHitch(gap, now)
	FG.Event(string.format("server hitch %.2fs", gap))
	if gap < FG.FREEZE_TIME then return end

	local lines = {
		string.format("the server froze for %.1fs", gap),
		"suspect: " .. FG.Suspect(gap, now),
	}
	if FG.hangTrace then
		lines[#lines + 1] = FG.hangTrace
		FG.hangTrace = nil
	end
	FG.SaveLog("server_freeze", FG.Report("server froze", lines))
end

local function PrunePending()
	local now = SysTime()
	for sid, pending in pairs(pendingRejoin) do
		if now - pending.at > REJOIN_WINDOW then pendingRejoin[sid] = nil end
	end
end

net.Receive("hg_freezeguard", function(_, ply)
	local kind = net.ReadUInt(2)
	local now = SysTime()
	nextMsg[ply] = nextMsg[ply] or {}
	if (nextMsg[ply][kind] or 0) > now then return end
	nextMsg[ply][kind] = now + MSG_COOLDOWN

	if kind == FG.MSG_FREEZE then
		OnFreeze(ply)
	elseif kind == FG.MSG_HELLO then
		OnHello(ply)
	end
end)

hook.Add("StartCommand", "hg_freezeguard", function(ply)
	lastCmd[ply] = SysTime()
end)

hook.Add("PostPlayerDeath", "hg_freezeguard", function(ply)
	if ply:IsBot() then return end

	local idle = SysTime() - (lastCmd[ply] or 0)
	if idle < IDLE_DEATH_TIME then return end

	frozenDeaths[ply] = {at = SysTime(), save = lastGood[ply]}
	FG.Event(string.format("%s died while not responding (no input for %.1fs)", ply:Nick(), idle))
end)

hook.Add("PlayerDisconnected", "hg_freezeguard", function(ply)
	local info = timingOut[ply]
	if info or ply:IsTimingOut() then
		local death = frozenDeaths[ply]
		local save = ply:Alive() and lastGood[ply] or death and death.save
		if save then pendingRejoin[ply:SteamID64()] = {at = SysTime(), save = save} end

		local lines = {ply:Nick() .. " dropped while not responding", "", "--- player when the timeout started ---"}
		table.Add(lines, info and info.lines or {})
		FG.SaveLog("drop", FG.Report("player dropped while frozen", lines))
	end

	PrunePending()
	lastCmd[ply] = nil
	lastGood[ply] = nil
	frozenDeaths[ply] = nil
	timingOut[ply] = nil
	nextMsg[ply] = nil
end)

hook.Add("Think", "hg_freezeguard", function()
	local now = SysTime()
	local gap = now - lastThink
	lastThink = now
	FG.Beat()

	if loaded and hadPlayers and gap >= FG.HITCH_TIME then OnServerHitch(gap, now) end
	hadPlayers = player.GetCount() > 0
end)

hook.Add("InitPostEntity", "hg_freezeguard", function()
	local state, body = FG.ReadPreviousSession()
	if state then
		FG.SaveLog("crash", "=== the server's last session ended without shutting down (" .. state .. ") ===\n" .. body)
	end

	FG.sessionState = "running"
	FG.WriteSession()
	FG.WrapNet()
	FG.SetWatchdog(cvWatchdog:GetBool())
	timer.Create("hg_freezeguard_watch", WATCH_INTERVAL, 0, Watch)
	timer.Create("hg_freezeguard_net", NET_WRAP_INTERVAL, 0, FG.WrapNet)
	timer.Create("hg_freezeguard_heartbeat", HEARTBEAT_INTERVAL, 0, FG.WriteSession)
	lastThink = SysTime()
	loaded = true
end)

hook.Add("ShutDown", "hg_freezeguard", function()
	if not loaded then return end

	FG.sessionState = "clean"
	FG.WriteSession()
end)

cvars.AddChangeCallback("hg_freezeguard_watchdog", function(_, _, new)
	FG.SetWatchdog(new == "1")
end, "hg_freezeguard")
