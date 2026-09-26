--[[
	Ignore Players, meant literally.

	The checkbox in the spawn menu's NPC tab is the engine convar
	ai_ignoreplayers, and all the engine does with it is stop NPCs noticing
	players by themselves. Two things walk straight past that, and Z-City does
	both:

	* a relationship set on the entity. Z-City's player classes loop over every
	  NPC on the map whenever somebody spawns or changes class and write
	  AddEntityRelationship(ply, D_HT, 99) on the ones their faction hates
	  (playerclass/classes/sh_rebel.lua:272, sh_combine.lua:330, sh_refuge.lua:287,
	  and again from an OnEntityCreated hook for NPCs spawned later). A specific
	  relationship is looked up before anything general, so the NPC hates that
	  player no matter what the convar says.
	* an enemy it already has. Being shot hands the shooter over as one, so an
	  NPC nobody was fighting fights back the moment it is hit - which is the
	  engine's own behaviour, and not what somebody who ticked "ignore players"
	  asked for.

	So while the convar is on, players are made neutral to every NPC, any player
	held as an enemy is let go of, and a shot that was going to be fired at one
	is not fired. Turn it off and the dispositions that were replaced go back on,
	because a rebel who liked you is not the same as a rebel who was told to
	ignore you.

	Nothing here is switchable: the switch is the one in the NPC tab.
]]

local D_NEUTRAL = D_NU

-- Same list sv_core.lua already keeps. A second walk of ents.GetAll and a
-- second OnEntityCreated timer per casing was the same tax paid twice.
ZCNPC.NPCs = ZCNPC.NPCs or setmetatable({}, { __mode = "k" })
local npcs = ZCNPC.NPCs

local ignore = GetConVar("ai_ignoreplayers")
local applied = false

local function Cvar()
	if not ignore then ignore = GetConVar("ai_ignoreplayers") end

	return ignore
end

-- The addon's own switch counts too: zcnpc_enabled 0 means nothing here touches an
-- NPC, and a run of it that had already made players invisible puts that back on
-- its way out (Enforce below reads the same answer).
function ZCNPC.IgnoringPlayers()
	if not ZCNPC.Enabled() then return false end

	local cvar = Cvar()

	return cvar ~= nil and cvar:GetBool()
end

hook.Add("OnEntityCreated", "zcnpc_ignoreplayers", function(ent)
	if not (IsValid(ent) and ent:IsNPC()) then return end

	timer.Simple(0, function()
		if not IsValid(ent) then return end

		-- Z-City writes its faction relationship from its own OnEntityCreated
		-- hook, so a fresh NPC is hostile before the timer comes round again.
		if ZCNPC.IgnoringPlayers() then
			local players = ZCNPC.Players and ZCNPC.Players() or player.GetAll()

			for i = 1, #players do
				ZCNPC.NeutraliseToward(ent, players[i])
			end
		end
	end)
end)

--\\ Making one player invisible to one NPC, and putting it back
-- The disposition being replaced is remembered per player, because there is no
-- way to ask an NPC what it would think of somebody if it had not been told:
-- once the override is on, Disposition answers with the override.
local function Saved(npc)
	local saved = npc.zcnpc_ignore_rel
	if not saved then
		saved = {}
		npc.zcnpc_ignore_rel = saved
	end

	return saved
end

local function DropEnemy(npc, ply)
	if npc:GetEnemy() ~= ply then return end

	npc:SetEnemy(NULL)
	if npc.ClearEnemyMemory then npc:ClearEnemyMemory() end

	if npc:GetNPCState() == NPC_STATE_COMBAT then
		npc:SetNPCState(NPC_STATE_ALERT)
	end
end

function ZCNPC.NeutraliseToward(npc, ply)
	if not (IsValid(npc) and npc:IsNPC() and IsValid(ply) and ply:IsPlayer()) then return end
	if not isfunction(npc.AddEntityRelationship) then return end

	local disposition = isfunction(npc.Disposition) and npc:Disposition(ply) or nil

	if disposition ~= D_NEUTRAL then
		local saved = Saved(npc)
		if saved[ply] == nil and disposition ~= nil then saved[ply] = disposition end

		npc:AddEntityRelationship(ply, D_NEUTRAL, 0)
	end

	DropEnemy(npc, ply)
end

-- D_LI at 0 and D_HT at 99 is Z-City's own pairing, and the priority only ever
-- decides which of two enemies is picked first, so putting a hate back at 99 is
-- putting back what was there.
local function Restore(npc)
	local saved = npc.zcnpc_ignore_rel
	if not saved then return end

	npc.zcnpc_ignore_rel = nil

	if not (IsValid(npc) and isfunction(npc.AddEntityRelationship)) then return end

	for ply, disposition in pairs(saved) do
		if IsValid(ply) and isnumber(disposition) and disposition ~= D_NEUTRAL then
			local priority = (disposition == D_HT or disposition == D_FR) and 99 or 0

			npc:AddEntityRelationship(ply, disposition, priority)
		end
	end
end
--//

local function Enforce()
	local on = ZCNPC.IgnoringPlayers()

	if not on then
		if not applied then return end
		applied = false

		for npc in pairs(npcs) do
			if IsValid(npc) then Restore(npc) end
		end

		ZCNPC.Debug("ai_ignoreplayers off, relationships restored")

		return
	end

	local players = ZCNPC.Players and ZCNPC.Players() or player.GetAll()
	if #players == 0 then return end

	applied = true

	for npc in pairs(npcs) do
		if not IsValid(npc) then
			npcs[npc] = nil
			continue
		end

		for i = 1, #players do
			ZCNPC.NeutraliseToward(npc, players[i])
		end
	end
end

timer.Create("zcnpc_ignoreplayers", 0.5, 0, Enforce)

pcall(cvars.AddChangeCallback, "ai_ignoreplayers", function()
	timer.Simple(0, Enforce)
end, "zcnpc_ignoreplayers")

-- Z-City rewrites its faction relationships on spawn / class change, so the
-- override has to go back on after them rather than only every half second.
hook.Add("PlayerSpawn", "zcnpc_ignoreplayers", function(ply)
	if not ZCNPC.IgnoringPlayers() then return end

	timer.Simple(0.1, function()
		if not (IsValid(ply) and ZCNPC.IgnoringPlayers()) then return end

		for npc in pairs(npcs) do
			if IsValid(npc) then ZCNPC.NeutraliseToward(npc, ply) end
		end
	end)
end)

-- Retaliation. The engine hands an attacker over as an enemy without anybody
-- having to see anything, which is the one way a player can still become a
-- target while the convar is on.
hook.Add("PostEntityTakeDamage", "zcnpc_ignoreplayers", function(ent, dmgInfo)
	if not ZCNPC.IgnoringPlayers() then return end
	if not (IsValid(ent) and ent:IsNPC()) then return end

	local attacker = dmgInfo:GetAttacker()
	if not (IsValid(attacker) and attacker:IsPlayer()) then return end

	timer.Simple(0, function()
		if not (IsValid(ent) and IsValid(attacker)) then return end
		if not ZCNPC.IgnoringPlayers() then return end

		ZCNPC.NeutraliseToward(ent, attacker)
	end)
end)

-- Last word: a burst that was already lined up on a player. The relationship is
-- gone by the next pass either way, but the shot in this tick would still land.
hook.Add("EntityFireBullets", "zcnpc_ignoreplayers", function(ent, data)
	if not ZCNPC.IgnoringPlayers() then return end
	if not IsValid(ent) then return end

	local npc = ent
	if ent:IsWeapon() then npc = ent:GetOwner() end
	if not (IsValid(npc) and npc:IsNPC()) then return end

	local enemy = npc:GetEnemy()
	if not (IsValid(enemy) and enemy:IsPlayer()) then return end

	ZCNPC.NeutraliseToward(npc, enemy)

	return false
end)

Enforce()
