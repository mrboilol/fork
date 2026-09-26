--[[
	Players get an organism before Homigrad reads it.

	Homigrad's Add only hangs { owner = ply }. Clear is what fills canmove,
	blood, consciousness. That Clear is on the custom "Player Spawn" hook,
	which sh_utility fires on the next tick after the engine PlayerSpawn.
	Sandbox loadout, handcuffs, KeyPress, IsBerserk and StartCommand all
	run in the gap. If PlayerInitialSpawn missed Add entirely (listen
	server, lua refresh, Homigrad still including), they index nil and
	that is the eleven-error dump on join.

	This file is included from autorun, not from Load(). The rest of the
	addon can wait; these hooks cannot.

	Hang itself returns the organism table. That is for callers who asked
	for it. It must never be the hook callback: hook.Call stops at the
	first non-nil, and a table here ate giveHands, CreateInv, and every
	other Player Spawn / PlayerLoadout / PlayerCanPickupWeapon listener.
]]

local wrappedClear
local wrappedAdd
local wrappedGCC
local wrapped = {}

local function Ready()
	return istable(hg) and istable(hg.organism) and isfunction(hg.organism.Add)
end

-- IsValid(function) indexes the function and dies (util.lua:318).
-- FakeRagdoll is supposed to be an entity; a method, Unheard, or a leftover
-- token sitting in that slot is what GetCurrentCharacter hits on the first
-- Org Think after join.
local function InstanceFake(ent)
	if not isentity(ent) then return nil end

	local t = isfunction(ent.GetTable) and ent:GetTable()
	if istable(t) then return rawget(t, "FakeRagdoll") end

	return ent.FakeRagdoll
end

function ZCNPC.SanitizeFakeRagdoll(ent)
	if not isentity(ent) then return end

	local rag = InstanceFake(ent)
	if rag == nil then rag = ent.FakeRagdoll end
	if rag == nil or rag == false then return end
	if isentity(rag) then return end

	-- Hide a metatable method / written function so the next IsValid is safe.
	ent.FakeRagdoll = NULL
end

local function Hang(ply)
	if not (isentity(ply) and IsValid(ply) and ply:IsPlayer()) then return nil end
	if not Ready() then return nil end

	ZCNPC.SanitizeFakeRagdoll(ply)

	if not istable(ply.organism) then
		hg.organism.Add(ply)
	end

	if not istable(ply.organism) then return nil end

	if ply.organism.canmove == nil and isfunction(hg.organism.Clear) then
		pcall(hg.organism.Clear, ply.organism)
	end

	return ply.organism
end

-- Hook callbacks must not return the organism. hook.Call treats any
-- non-nil as "done" and skips giveHands / inventory / the rest of spawn.
local function HangQuiet(ply)
	Hang(ply)
end

local function PatchClear()
	if not (Ready() and isfunction(hg.organism.Clear)) then return end
	if hg.organism.Clear == wrappedClear then return end

	local old = hg.organism.Clear
	wrappedClear = function(org)
		if not istable(org) then return end

		return old(org)
	end
	hg.organism.Clear = wrappedClear
end

-- Homigrad's InitialSpawn Add wipes a finished organism back to { owner }.
-- Keep a complete one. A ragdoll transfer still Add's: the rag has none.
local function PatchAdd()
	if not Ready() then return end
	if hg.organism.Add == wrappedAdd then return end

	local old = hg.organism.Add
	wrappedAdd = function(ent)
		if isentity(ent) and IsValid(ent) and istable(ent.organism) and ent.organism.canmove ~= nil
			and hg.organism.list and hg.organism.list[ent] == ent.organism then
			return ent.organism
		end

		return old(ent)
	end
	hg.organism.Add = wrappedAdd
end

-- Stock GetCurrentCharacter does IsValid(ply.FakeRagdoll). A function there
-- is the lungs error on spawn (sv_tier_0.lua:863).
local function PatchGetCurrentCharacter()
	if not (istable(hg) and isfunction(hg.GetCurrentCharacter)) then return end
	if hg.GetCurrentCharacter == wrappedGCC then return end

	wrappedGCC = function(ply)
		if not isentity(ply) or not IsValid(ply) then return false end

		ZCNPC.SanitizeFakeRagdoll(ply)

		local rag = ply.FakeRagdoll
		if not (isentity(rag) and IsValid(rag)) then
			local ok, nw = pcall(function()
				return ply:GetNWEntity("FakeRagdoll", NULL)
			end)
			if ok and isentity(nw) and IsValid(nw) then rag = nw end
		end

		if isentity(rag) and IsValid(rag) and rag ~= ply then
			-- First-join prime (sv_prime.lua) and a failed FakeUp can leave a
			-- ragdoll in this slot after the player is already on their feet.
			-- Damage traces then walk that leftover's bones — "the brain has
			-- been moved", frontal shots hit skull and only knock out.
			if ply:IsPlayer() and ply:Alive() then
				local org = ply.organism
				local faked = (istable(org) and org.fake)
					or ply:GetMoveType() == MOVETYPE_NONE
				if not faked then return ply end
			end

			return rag
		end

		return ply
	end

	hg.GetCurrentCharacter = wrappedGCC
end

local function PatchPlayerMeta()
	local meta = FindMetaTable("Player")
	if not meta or meta._ZCNPCOrgGuard then return end

	local function wrap(name)
		local old = meta[name]
		if not isfunction(old) then return end

		meta[name] = function(self, ...)
			if not istable(self.organism) then
				Hang(self)
			end
			if not istable(self.organism) then return false end

			return old(self, ...)
		end
	end

	wrap("IsBerserk")
	wrap("IsStimulated")
	meta._ZCNPCOrgGuard = true
end

-- Replace Homigrad's own spawn hook so Clear never sees nil.
local function PatchHomigradSpawn()
	if not Ready() then return end

	hook.Add("PlayerInitialSpawn", "homigrad-organism", function(ply)
		HangQuiet(ply)
	end)

	hook.Add("Player Spawn", "homigrad-organism", function(ply)
		HangQuiet(ply)
		if istable(ply.organism) then
			hg.organism.Clear(ply.organism)
		end
	end)
end

local function WrapNamed(event, name)
	local list = hook.GetTable()[event]
	if not list or not isfunction(list[name]) then return end

	local key = event .. "\0" .. name
	if wrapped[key] == list[name] then return end

	local old = list[name]
	local new = function(a, b, c, d, e, f)
		if isentity(a) and IsValid(a) and a:IsPlayer() then
			HangQuiet(a)
			if not istable(a.organism) then return end
		end

		return old(a, b, c, d, e, f)
	end

	hook.Add(event, name, new)
	wrapped[key] = new
end

local function WrapHomigradReaders()
	WrapNamed("PlayerCanPickupWeapon", "handcuffDisallowpickup")
	WrapNamed("StartCommand", "hg_lol")
	WrapNamed("Player Think", "sethuynyis")
	WrapNamed("Player Think", "Berserk")
	WrapNamed("KeyPress", "huy-hg")
	WrapNamed("CanListenOthers", "CantHaveShitInDetroit")
	WrapNamed("player_spawn", "homigrad-spawn3")
end

-- Brainfuck does IsValid(owner.FakeRagdoll). Clear the bad value instead
-- of skipping the think — lungs still has to walk the same field.
local function PatchBrainfuck()
	local list = hook.GetTable()["Org Think"]
	if not list or not isfunction(list.BrainfuckThink) then return end

	local key = "Org Think\0BrainfuckThink"
	if wrapped[key] == list.BrainfuckThink then return end

	local old = list.BrainfuckThink
	local new = function(owner, org, dt)
		if not isentity(owner) or not IsValid(owner) then return end

		ZCNPC.SanitizeFakeRagdoll(owner)

		return old(owner, org, dt)
	end

	hook.Add("Org Think", "BrainfuckThink", new)
	wrapped[key] = new
end

-- Sandbox has no mysqloo connection. Abnormality detection still
-- Execute's on PlayerInitialSpawn and the error is the join dump.
local function PatchMySQL()
	if not istable(mysql) or not isfunction(mysql.RawQuery) then return end
	if mysql._ZCNPCConnGuard then return end

	local old = mysql.RawQuery
	function mysql:RawQuery(query, callback, flags, ...)
		if self.module == "mysqloo" and self.connection == nil then
			return
		end

		return old(self, query, callback, flags, ...)
	end

	mysql._ZCNPCConnGuard = true
end

local function HangAll()
	if not Ready() then return end

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then
			if not istable(ply.organism) or ply.organism.canmove == nil then
				Hang(ply)
			else
				ZCNPC.SanitizeFakeRagdoll(ply)
			end
		end
	end
end

-- giveHands is PlayerLoadout. If anything else still ate that hook,
-- Hands are missing and Q-menu Give has nothing to holster against.
local function EnsureHands(ply)
	if not (isentity(ply) and IsValid(ply) and ply:IsPlayer() and ply:Alive()) then
		return
	end
	if ply:HasWeapon("weapon_hands_sh") then return end
	if not (istable(weapons) and isfunction(weapons.GetStored) and weapons.GetStored("weapon_hands_sh")) then
		return
	end

	ply:Give("weapon_hands_sh")
end

local function Install()
	if not Ready() then return false end

	PatchClear()
	PatchAdd()
	PatchGetCurrentCharacter()
	PatchPlayerMeta()
	PatchHomigradSpawn()
	WrapHomigradReaders()
	PatchBrainfuck()
	PatchMySQL()
	HangAll()

	return true
end

-- These used to be Hang itself. A leftover from a lua refresh would
-- keep eating loadout / pickup / think. Take them off by name.
hook.Remove("PlayerLoadout", "!zcnpc_player_org")
hook.Remove("StartCommand", "!zcnpc_player_org")
hook.Remove("KeyPress", "!zcnpc_player_org")
hook.Remove("Player Think", "!zcnpc_player_org")
hook.Remove("PlayerCanPickupWeapon", "!zcnpc_player_org")

hook.Add("PlayerInitialSpawn", "!zcnpc_player_org", HangQuiet)
hook.Add("PlayerSpawn", "!zcnpc_player_org", HangQuiet)
hook.Add("Player Spawn", "!zcnpc_player_org", HangQuiet)
hook.Add("PlayerLoadout", "zcnpc_player_org_loadout", HangQuiet)

hook.Add("Player Spawn", "zcnpc_ensure_hands", function(ply)
	HangQuiet(ply)
	timer.Simple(0, function()
		EnsureHands(ply)
	end)
end)

hook.Add("HomigradRun", "zcnpc_player_org", Install)
hook.Add("InitPostEntity", "zcnpc_player_org", Install)

Install()

timer.Create("zcnpc_player_org", 0.25, 0, function()
	Install()
end)
