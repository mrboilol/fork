--[[
	The other end of the Q menu panel.

	Every setting is a replicated convar, which means clients can read all of them
	and change none of them - so the panel asks instead. Two things can be asked
	for: one setting, or a whole preset at once.

	Only ever what is in the registry, only ever between the limits it gives, and
	only ever from somebody the server would let type it into its console anyway.
	A client sending its own name for a convar and its own value for it is a client
	setting sv_cheats, and the fact that our own panel would never send such a
	thing is not a reason to accept it.
]]

util.AddNetworkString("zcnpc_set")
util.AddNetworkString("zcnpc_preset")
util.AddNetworkString("zcnpc_weapons")
util.AddNetworkString("zcnpc_armor")

local function Allowed(ply)
	if not IsValid(ply) then return false end
	if ply:IsSuperAdmin() then return true end

	-- singleplayer and a listen server host are the same person as the server
	return game.SinglePlayer() or ply:IsListenServerHost()
end

local function Deny(ply)
	ply:ChatPrint("[ZCNPC] Only admins can change these settings.")
end

-- One place that writes a convar, so the clamping cannot be forgotten at one of
-- the two call sites.
local function Apply(setting, value)
	if setting.type == "bool" then
		value = (tonumber(value) or 0) >= 0.5 and 1 or 0
	else
		value = math.Clamp(tonumber(value) or setting.default, setting.min or 0, setting.max or 1)
	end

	RunConsoleCommand(setting.cvar, tostring(value))

	return value
end

net.Receive("zcnpc_set", function(_, ply)
	if not Allowed(ply) then return Deny(ply) end

	local setting = ZCNPC.SettingByCvar[net.ReadString()]
	if not setting then return end

	local value = Apply(setting, net.ReadFloat())

	ZCNPC.Debug(ply:Nick(), "set", setting.cvar, value)
end)

net.Receive("zcnpc_preset", function(_, ply)
	if not Allowed(ply) then return Deny(ply) end

	local id = net.ReadString()
	local count = net.ReadUInt(8)

	-- A named preset is one of ours and its values are read out of the registry
	-- rather than off the wire. A custom one is somebody's saved panel, which only
	-- exists on the machine that saved it, so it does arrive as a list - and every
	-- entry of it goes through the same door a single setting does.
	local values = {}

	if id ~= "" then
		local preset = ZCNPC.GetPreset(id)
		if not preset then return end

		values = ZCNPC.PresetValues(preset)
	else
		for _ = 1, count do
			values[net.ReadString()] = net.ReadFloat()
		end
	end

	local applied = 0

	for cvar, value in pairs(values) do
		local setting = ZCNPC.SettingByCvar[cvar]

		if setting then
			Apply(setting, value)
			applied = applied + 1
		end
	end

	local name = id ~= "" and (ZCNPC.GetPreset(id).name .. " preset") or "a custom preset"

	for _, other in ipairs(player.GetAll()) do
		other:ChatPrint("[ZCNPC] " .. ply:Nick() .. " loaded " .. name .. ".")
	end

	ZCNPC.Debug(ply:Nick(), "loaded preset", id ~= "" and id or "custom", applied, "settings")
end)

-- The spawn loadouts are the one setting that is not a number, so they have a door
-- of their own - and it is the same door: a list from a client is a list of class
-- names that have to be weapons an NPC can actually be given, which is what
-- ZCNPC.WeaponAllowed answers off the game's own list.
local MAX_WEAPONS = 24 -- a list, not a wardrobe

net.Receive("zcnpc_weapons", function(_, ply)
	if not Allowed(ply) then return Deny(ply) end

	local group = ZCNPC.WeaponGroupById[net.ReadString()]
	if not group then return end

	local count = math.min(net.ReadUInt(8), MAX_WEAPONS)
	local classes, weights = {}, {}

	-- The weight is clamped into range by ZCNPC.CleanWeight on the way through
	-- WeaponListString, so a client sending a hundred is a client sending the top of
	-- the scale rather than a convar with a hundred in it.
	for _ = 1, count do
		local class = net.ReadString()
		classes[#classes + 1] = class
		weights[class] = net.ReadUInt(8)
	end

	local value = ZCNPC.WeaponListString(classes, weights)

	RunConsoleCommand(group.cvar, value)

	ZCNPC.Debug(ply:Nick(), "set", group.cvar, value == "" and "(default)" or value)
end)

-- The same door for the other half of a loadout. A longer list is allowed than
-- for guns because armour is read as a pool per placement rather than as one
-- roll: four helmets and four vests is eight entries and is one sensible squad.
local MAX_ARMOR = 32

net.Receive("zcnpc_armor", function(_, ply)
	if not Allowed(ply) then return Deny(ply) end

	local group = ZCNPC.ArmorGroupById[net.ReadString()]
	if not group then return end

	local count = math.min(net.ReadUInt(8), MAX_ARMOR)
	local pieces, weights = {}, {}

	for _ = 1, count do
		local piece = net.ReadString()
		pieces[#pieces + 1] = piece
		weights[piece] = net.ReadUInt(8)
	end

	local value = ZCNPC.ArmorListString(pieces, weights)

	RunConsoleCommand(group.cvar, value)

	ZCNPC.Debug(ply:Nick(), "set", group.cvar, value == "" and "(default)" or value)
end)

-- Defaults change between versions of the addon and an archived convar does not:
-- once a value has been written to cfg/ it stays there, so a server that ran an
-- older version keeps its old kick force forever without a way to ask for the new
-- one. This is that way, and it is also the answer to a panel somebody has made a
-- mess of.
concommand.Add("zcnpc_defaults", function(ply)
	if IsValid(ply) and not Allowed(ply) then return Deny(ply) end

	for _, setting in ipairs(ZCNPC.Settings) do
		RunConsoleCommand(setting.cvar, tostring(setting.default))
	end

	-- Empty is the default for a loadout, and it means "leave them holding whatever
	-- they came with" rather than "give them nothing".
	for _, group in ipairs(ZCNPC.WeaponGroups) do
		RunConsoleCommand(group.cvar, "")
	end

	for _, group in ipairs(ZCNPC.ArmorGroups or {}) do
		RunConsoleCommand(group.cvar, "")
	end

	print("[ZCNPC] every setting is back at its default")
end, nil, "Put every Z-City NPC Overhaul setting back to its default value")

-- Named so it reads the same way in a console as it does in the panel.
concommand.Add("zcnpc_preset", function(ply, _, args)
	if IsValid(ply) and not Allowed(ply) then return Deny(ply) end

	local preset = ZCNPC.GetPreset(string.lower(args[1] or ""))

	if not preset then
		local names = {}
		for _, entry in ipairs(ZCNPC.Presets) do names[#names + 1] = entry.id end

		print("[ZCNPC] usage: zcnpc_preset <" .. table.concat(names, "|") .. ">")

		return
	end

	for cvar, value in pairs(ZCNPC.PresetValues(preset)) do
		RunConsoleCommand(cvar, tostring(value))
	end

	print("[ZCNPC] " .. preset.name .. " preset loaded")
end, nil, "Load one of the built in setting presets")
