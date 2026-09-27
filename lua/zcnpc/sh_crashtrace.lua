--[[
	Crash tracer. Debug only, off by default.

	A hard crash takes the console with it, so this writes every step it watches to
	a file and flushes each line before the step runs. After a crash, the last
	">" line with no matching "<" under it is where the game died.

	  server: zcnpc_crashtrace 1     -> data/zcnpc_crashtrace/sv.txt
	  client: zcnpc_crashtrace_cl 1  -> data/zcnpc_crashtrace/cl.txt

	Both are archived, so they are still on after the restart. The previous
	session's file is kept as sv_prev.txt / cl_prev.txt.
]]

ZCNPC = ZCNPC or {}

local REALM = SERVER and "sv" or "cl"
local DIR = "zcnpc_crashtrace"
local CVAR = SERVER and "zcnpc_crashtrace" or "zcnpc_crashtrace_cl"
local HOT_TIME = 3 -- seconds of per-frame hook tracing after anything NPC-related happens
local MAX_LINES = 200000

local cvar = CreateConVar(CVAR, "0", FCVAR_ARCHIVE, "Write a crash trace to data/" .. DIR .. "/" .. REALM .. ".txt", 0, 1)

local out, lines = nil, 0
local hotUntil = 0

local function Open()
	if out then return true end

	file.CreateDir(DIR)

	local path = DIR .. "/" .. REALM .. ".txt"
	if file.Exists(path, "DATA") and isfunction(file.Rename) then
		file.Delete(DIR .. "/" .. REALM .. "_prev.txt")
		file.Rename(path, DIR .. "/" .. REALM .. "_prev.txt", "DATA")
	end

	out = file.Open(path, "w", "DATA")
	lines = 0

	return out ~= nil
end

local function Write(tag, what)
	if not out then return end

	lines = lines + 1
	if lines > MAX_LINES then
		out:Close()
		out = file.Open(DIR .. "/" .. REALM .. ".txt", "w", "DATA")
		lines = 0
		if not out then return end
	end

	out:Write(string.format("%.3f %s %s\n", SysTime(), tag, what))
	out:Flush()
end

function ZCNPC.Trace(what)
	Write("*", tostring(what))
end

local function Heat()
	hotUntil = SysTime() + HOT_TIME
end

local function Relevant(ent)
	return isentity(ent) and IsValid(ent) and (ent:IsNPC() or ent:IsRagdoll())
end

-- Low-rate events: every handler, always.
local ALWAYS = {
	EntityTakeDamage = true, PostEntityTakeDamage = true, ScaleNPCDamage = true,
	HomigradDamage = true, OnNPCKilled = true, CreateEntityRagdoll = true,
	["Ragdoll Collide"] = true, EntityFireBullets = true,
	ZCNPC_Downed = true, ZCNPC_Died = true, ZCNPC_GetUp = true, ZCNPC_WokeUp = true,
	ZCNPC_TargetLost = true, ZCNPC_ClientDowned = true, ZCNPC_ClientWokeUp = true,
	OnNetVarSet = true,
}

-- Only when the first argument is an NPC or a ragdoll.
local FILTERED = {
	OnEntityCreated = true, EntityRemoved = true, ["Org Think"] = true,
}

-- Per-frame: only inside the hot window, entry only (the next line says it returned).
local HOT = {
	Think = true, Tick = true,
	PostDrawOpaqueRenderables = true, PostDrawTranslucentRenderables = true,
	PreDrawOpaqueRenderables = true, PrePlayerDraw = true, PostPlayerDraw = true,
	RenderScreenspaceEffects = true, HUDPaint = true, PreRender = true, PostRender = true,
	["Player-Ragdoll think"] = true,
}

local wrapped = setmetatable({}, { __mode = "k" })

local function Wrap(event, name, fn)
	if wrapped[fn] then return fn end

	local label = event .. " / " .. tostring(name)
	local new

	if HOT[event] then
		new = function(...)
			if hotUntil > SysTime() then Write(">", label) end
			return fn(...)
		end
	elseif FILTERED[event] then
		new = function(a, ...)
			if not Relevant(a) then return fn(a, ...) end

			Write(">", label .. " " .. tostring(a))
			local r1, r2, r3, r4, r5, r6 = fn(a, ...)
			Write("<", label)

			return r1, r2, r3, r4, r5, r6
		end
	else
		new = function(...)
			Heat()
			Write(">", label)
			local r1, r2, r3, r4, r5, r6 = fn(...)
			Write("<", label)

			return r1, r2, r3, r4, r5, r6
		end
	end

	wrapped[new] = true

	return new
end

-- In place, so neither priority nor order changes. ULib keeps the real table
-- behind GetULibTable; stock hook.GetTable is the real table.
local function WrapHooks()
	local ulib = isfunction(hook.GetULibTable) and hook.GetULibTable()

	local function Traced(event)
		return ALWAYS[event] or FILTERED[event] or HOT[event]
	end

	if ulib then
		local back = hook.GetTable()

		for event, prios in pairs(ulib) do
			if not Traced(event) then continue end

			for prio = -2, 2 do
				for name, entry in pairs(prios[prio] or {}) do
					if not wrapped[entry.fn] then
						entry.fn = Wrap(event, name, entry.fn)
						if back[event] then back[event][name] = entry.fn end
					end
				end
			end
		end

		return
	end

	for event, list in pairs(hook.GetTable()) do
		if not Traced(event) then continue end

		for name, fn in pairs(list) do
			if isfunction(fn) and not wrapped[fn] then list[name] = Wrap(event, name, fn) end
		end
	end
end

-- Deferred callbacks from the systems in play. Source is taken when the timer is
-- made, so the trace names the line that asked for it.
local WATCH = { "zcnpc", "system_", "combat_intelligence", "active_ragdoll", "homigrad/npc", "organism", "fake/" }

local function Watched(src)
	for i = 1, #WATCH do
		if string.find(src, WATCH[i], 1, true) then return true end
	end

	return false
end

local function WrapTimerFn(fn, level)
	if not isfunction(fn) then return fn end

	local info = debug.getinfo(level, "Sl")
	if not (info and Watched(info.short_src or "")) then return fn end

	local label = "timer " .. info.short_src .. ":" .. tostring(info.currentline)

	return function(...)
		Write(">", label)
		local r1, r2 = fn(...)
		Write("<", label)

		return r1, r2
	end
end

local function WrapTimers()
	if ZCNPC.__traceTimers then return end

	local simple, create = timer.Simple, timer.Create
	ZCNPC.__traceTimers = { simple = simple, create = create }

	timer.Simple = function(delay, fn)
		return simple(delay, WrapTimerFn(fn, 3))
	end

	timer.Create = function(id, delay, reps, fn)
		return create(id, delay, reps, WrapTimerFn(fn, 3))
	end
end

local function WrapNet()
	if SERVER or ZCNPC.__traceNet then return end

	local incoming = net.Incoming
	ZCNPC.__traceNet = incoming

	function net.Incoming(len, client)
		local name = util.NetworkIDToString(net.ReadHeader())
		if not name then return end

		local fn = net.Receivers[string.lower(name)]
		if not fn then return end

		if string.find(name, "organism", 1, true) or string.find(name, "zcnpc", 1, true)
			or string.find(name, "wound", 1, true) or string.find(name, "blood", 1, true) then
			Heat()
		end

		Write(">", "net " .. name)
		fn(len - 16, client)
		Write("<", "net " .. name)
	end
end

local function WrapPasses()
	if SERVER or not istable(ZCNPC.Passes) then return end

	for _, pass in ipairs(ZCNPC.Passes) do
		if wrapped[pass.draw] then continue end

		local fn, label = pass.draw, "pass " .. tostring(pass.name)
		pass.draw = function(npc)
			Write(">", label .. " " .. tostring(npc))
			fn(npc)
			Write("<", label)
		end
		wrapped[pass.draw] = true
	end
end

local function WrapCai()
	if CLIENT or not (istable(CAI) and istable(CAI.Brain) and isfunction(CAI.Brain.Think)) then return end
	if wrapped[CAI.Brain.Think] then return end

	local think = CAI.Brain.Think
	CAI.Brain.Think = function(data, ...)
		local label = "CAI think " .. tostring(istable(data) and data.ent)
		Write(">", label)
		local r1, r2 = think(data, ...)
		Write("<", label)

		return r1, r2
	end
	wrapped[CAI.Brain.Think] = true
end

local function Install()
	if not cvar:GetBool() then return end
	if not Open() then return end

	WrapTimers()
	WrapNet()
	WrapHooks()
	WrapPasses()
	WrapCai()
end

local function Beat()
	if not out then return end

	Install() -- hooks added since the last pass

	local npcs = 0
	for _, ent in ipairs(ents.GetAll()) do
		if ent:IsNPC() then npcs = npcs + 1 end
	end

	Write("*", "alive, npcs " .. npcs)
end

hook.Add("InitPostEntity", "zcnpc_crashtrace", function()
	Install()
	ZCNPC.Trace("InitPostEntity")
end)

cvars.AddChangeCallback(CVAR, function(_, _, new)
	if new == "1" then
		Install()
		ZCNPC.Trace("trace on")
	elseif out then
		ZCNPC.Trace("trace off")
		out:Close()
		out = nil
	end
end, "zcnpc_crashtrace")

if ZCNPC.__traceBeat == nil then
	ZCNPC.__traceBeat = true
	-- made through the untouched timer.Create so the beat itself is never traced
	timer.Create("zcnpc_crashtrace", 1, 0, function() Beat() end)
end

Install()
