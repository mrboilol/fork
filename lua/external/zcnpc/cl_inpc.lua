--[[
	iNPC Opti+ client hold-off.

	inpc_cleanup / inpc_health_regeneration / inpc_airstrike_chane are not
	FCVAR_REPLICATED, so the iNPC Q-menu checkbox / slider writes the CLIENT
	cvar. Server HoldOff alone leaves the UI looking toggleable. Mirror the
	snap-back here while ZCNPC is enabled.

	Idle Patrolling is the other way round: our zcnpc_idle_patrol is the master,
	and the iNPC checkbox is kept in step with it so the two menus cannot disagree.
]]

local HELD_OFF = {
	{ name = "inpc_health_regeneration", value = "0", kind = "bool" },
	{ name = "inpc_cleanup", value = "0", kind = "bool" },
	{ name = "inpc_airstrike_chane", value = "0", kind = "float" },
}

-- The convars are there on a server that mounted the addon and never loaded it,
-- because Z-City was missing. Holding iNPC's own switches down on behalf of an addon
-- that is not running is a checkbox that snaps back for no reason at all.
local function Enabled()
	local cvar = GetConVar("zcnpc_enabled")
	if cvar == nil then return true end
	if ZCNPC.Running and not ZCNPC.Running() then return false end

	return cvar:GetBool()
end

local function Present()
	return ConVarExists("inpc_enabled")
end

local function IsOn(cvar, kind)
	if not cvar then return false end

	if kind == "float" then
		return math.abs(cvar:GetFloat()) > 0.0001
	end

	return cvar:GetBool()
end

local function HoldOff(entry)
	local cvar = GetConVar(entry.name)
	if not IsOn(cvar, entry.kind) then return end

	if entry.kind == "float" then
		cvar:SetFloat(tonumber(entry.value) or 0)
	else
		cvar:SetBool(false)
	end

	RunConsoleCommand(entry.name, entry.value)
end

local function SyncIdlePatrol()
	if not (Enabled() and Present()) then return end

	local ours = GetConVar("zcnpc_idle_patrol")
	local theirs = GetConVar("inpc_patrol")
	if not (ours and theirs) then return end

	local want = ours:GetBool()
	if theirs:GetBool() == want then return end

	theirs:SetBool(want)
	RunConsoleCommand("inpc_patrol", want and "1" or "0")
end

local function HoldAll()
	if not (Enabled() and Present()) then return end

	for i = 1, #HELD_OFF do
		HoldOff(HELD_OFF[i])
	end

	SyncIdlePatrol()
end

local function Install()
	if not Present() then return false end

	HoldAll()

	for i = 1, #HELD_OFF do
		local entry = HELD_OFF[i]
		local name = entry.name
		local id = "zcnpc_cl_inpc_" .. name

		pcall(cvars.RemoveChangeCallback, name, id)
		cvars.AddChangeCallback(name, function(_, _, new)
			if not Enabled() then return end
			if new == "0" or new == "0.0" or new == "0.00" or new == "false" then return end

			timer.Simple(0, function()
				HoldOff(entry)
			end)
		end, id)
	end

	pcall(cvars.RemoveChangeCallback, "inpc_patrol", "zcnpc_cl_inpc_patrol")
	cvars.AddChangeCallback("inpc_patrol", function()
		timer.Simple(0, SyncIdlePatrol)
	end, "zcnpc_cl_inpc_patrol")

	pcall(cvars.RemoveChangeCallback, "zcnpc_idle_patrol", "zcnpc_cl_idle_patrol")
	cvars.AddChangeCallback("zcnpc_idle_patrol", function()
		timer.Simple(0, SyncIdlePatrol)
	end, "zcnpc_cl_idle_patrol")

	timer.Create("zcnpc_cl_inpc_hold", 1, 0, HoldAll)

	return true
end

Install()
hook.Add("InitPostEntity", "zcnpc_cl_inpc", Install)

timer.Create("zcnpc_cl_inpc_retry", 2, 15, function()
	if Install() then
		timer.Remove("zcnpc_cl_inpc_retry")
	end
end)

pcall(cvars.AddChangeCallback, "zcnpc_enabled", function()
	timer.Simple(0, Install)
end, "zcnpc_cl_inpc_enabled")
