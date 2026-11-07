AddCSLuaFile()

HG_SoundFallback = HG_SoundFallback or {log = {}, resolved = {}}

local M = HG_SoundFallback
M.played = M.played or {}
local audioExtensions = {wav = true, mp3 = true, ogg = true}
local LOG_COMMAND = "hg_soundlog"
local MAX_NET_ENTRIES = 100
local MAX_PLAYED_BYTES = 48000
local MAX_CHAT_LINES = 8

local function logMissing(path, replacement)
	for _, entry in ipairs(M.log) do
		if entry.name == path then return end
	end

	M.log[#M.log + 1] = {name = path, to = replacement}
end

local function nextSibling(path)
	local stem, number, extension = path:match("^(.-)(%d+)(%.%w+)$")
	if not stem then return end

	local dir, base = stem:match("^(.*/)([^/]*)$")
	if not dir then dir, base = "", stem end

	local pattern = "^" .. string.PatternSafe(base:lower()) .. "(%d+)" .. string.PatternSafe(extension:lower()) .. "$"
	local candidates = {}
	for _, fileName in ipairs(file.Find("sound/" .. stem .. "*" .. extension, "GAME") or {}) do
		local digits = fileName:lower():match(pattern)
		if digits then candidates[#candidates + 1] = digits end
	end
	if #candidates == 0 then return end

	table.sort(candidates, function(a, b) return tonumber(a) < tonumber(b) end)

	local chosen = candidates[1]
	local current = tonumber(number)
	for _, digits in ipairs(candidates) do
		if tonumber(digits) > current then
			chosen = digits
			break
		end
	end

	return dir .. base .. chosen .. extension
end

function M.Resolve(name)
	if not isstring(name) or name == "" then return name end

	local known = M.resolved[name]
	if known then return known end

	local prefix, path = name:match("^([%*#@<>%^%(%)}%$!%?&~`%+]*)(.*)$")
	path = path:gsub("\\", "/")

	local result = name
	local extension = path:match("%.(%w+)$")
	if extension and audioExtensions[extension:lower()] then
		if file.Exists("sound/" .. path, "GAME") then
			if SERVER then M.played[#M.played + 1] = path end
		else
			local replacement = nextSibling(path)
			logMissing(path, replacement)
			if replacement then result = prefix .. replacement end
		end
	elseif not sound.GetProperties(name) then
		logMissing(path)
	end

	M.resolved[name] = result
	return result
end

local function wrapNameFirst(owner, key)
	local original = owner[key]
	owner[key] = function(name, ...)
		return original(M.Resolve(name), ...)
	end
end

local function wrapNameSecond(owner, key)
	local original = owner[key]
	owner[key] = function(first, name, ...)
		return original(first, M.Resolve(name), ...)
	end
end

if not M.wrapped then
	M.wrapped = true

	local entMeta = FindMetaTable("Entity")
	wrapNameFirst(_G, "EmitSound")
	wrapNameFirst(_G, "SoundDuration")
	wrapNameFirst(sound, "Play")
	wrapNameSecond(_G, "CreateSound")
	wrapNameSecond(entMeta, "EmitSound")
	wrapNameSecond(entMeta, "StopSound")
end

local function formatEntry(realm, entry)
	return "[" .. realm .. "] " .. entry.name .. " -> " .. (entry.to or "no replacement")
end

if SERVER then
	util.AddNetworkString(LOG_COMMAND)

	hook.Add("HG_PlayerSay", "HG_SoundLog", function(ply, _, text)
		if not text:Trim():lower():match("^[!/]?" .. LOG_COMMAND .. "$") then return end

		local count = math.min(#M.log, MAX_NET_ENTRIES)
		net.Start(LOG_COMMAND)
			net.WriteUInt(count, 8)
			for i = 1, count do
				net.WriteString(formatEntry("SV", M.log[i]))
			end

			local played, bytes = {}, 0
			for _, path in ipairs(M.played) do
				bytes = bytes + #path + 1
				if bytes > MAX_PLAYED_BYTES then break end
				played[#played + 1] = path
			end
			net.WriteUInt(#played, 16)
			for _, path in ipairs(played) do
				net.WriteString(path)
			end
		net.Send(ply)
	end)
else
	net.Receive(LOG_COMMAND, function()
		local lines = {}
		for i = 1, net.ReadUInt(8) do
			lines[i] = net.ReadString()
		end
		for _ = 1, net.ReadUInt(16) do
			local path = net.ReadString()
			if not file.Exists("sound/" .. path, "GAME") then
				lines[#lines + 1] = "[CL] " .. path .. " -> missing on this client (server has it)"
			end
		end
		for _, entry in ipairs(M.log) do
			lines[#lines + 1] = formatEntry("CL", entry)
		end

		chat.AddText(Color(255, 200, 80), "[hg_soundlog] ", color_white, #lines .. " missing sound(s) since map load")
		for i, line in ipairs(lines) do
			print(line)
			if i <= MAX_CHAT_LINES then chat.AddText(color_white, line) end
		end
		if #lines > MAX_CHAT_LINES then
			chat.AddText(color_white, "Full list in console.")
		end
	end)
end
