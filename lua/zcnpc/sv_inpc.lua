--[[
	iNPC Opti+ soft-compat.

	iNPC is an AI layer on stock HL2 NPCs. It does not need a deep feature bridge,
	but a few of its switches fight Z-City bodies / future chaos:

	* inpc_health_regeneration - engine HP regen next to the organism
	* inpc_cleanup - g_ragdoll_maxcount 0 eats living downed bodies
	* inpc_airstrike_chane - random map bombing (held at 0)

	We do not edit that addon. While both are loaded those are held off (same idea
	as Artagdoll's Fatal Headshot): forced every second, snapped back on every
	menu toggle, and installed again if iNPC loads after us. Regen / cleanup wraps
	stay as a backup if a workshop copy ignores the cvar. The hidden half of a
	body skips inpcAI (wrap) without clearing npc.inpcUseAI — flipping that flag
	on knockdowns broke Idle Patrol / AI for everyone after Resume races.

	Idle Patrolling: iNPC's enemy scan returns true when it merely samples a
	hostile-faction husk still lying on the floor (Health > 0), so the patrol
	branch never runs. We filter those husks and nudge idle NPCs into PATROL.
	Master switch is zcnpc_idle_patrol (Q-menu); it keeps inpc_patrol in step.

	Nothing the map is driving is nudged anywhere - a sequence, an assault rally
	point, a follow order. ZCNPC.MapDriven in sv_core.lua is the question, and
	the patrol below is the loudest of the several chores that ask it.
]]

-- value: string written to the cvar. kind: "bool" or "float".
util.AddNetworkString("hg_cleardecals")

local HELD_OFF = {
	{ name = "inpc_health_regeneration", value = "0", kind = "bool" },
	{ name = "inpc_cleanup", value = "0", kind = "bool" },
	{ name = "inpc_airstrike_chane", value = "0", kind = "float" },
}

local RAGDOLL_SAFE = {
	g_ragdoll_fadespeed = "600",
	g_ragdoll_important_maxcount = "2",
	g_ragdoll_lvfadespeed = "100",
	g_ragdoll_maxcount = "8",
}

local function Present()
	return ConVarExists("inpc_enabled")
end

function ZCNPC.InpcPresent()
	return Present()
end

local function IsOn(cvar, kind)
	if not cvar then return false end

	if kind == "float" then
		return math.abs(cvar:GetFloat()) > 0.0001
	end

	return cvar:GetBool()
end

local function HoldOff(entry)
	local name = entry.name
	local cvar = GetConVar(name)
	if not IsOn(cvar, entry.kind) then return end

	-- Set* alone loses to some menu / ARCHIVE write races on listen servers.
	if entry.kind == "float" then
		cvar:SetFloat(tonumber(entry.value) or 0)
	else
		cvar:SetBool(false)
	end

	RunConsoleCommand(name, entry.value)
	ZCNPC.Debug("held off", name)
end

local function HoldAll()
	if not (ZCNPC.Enabled() and Present()) then return end

	for i = 1, #HELD_OFF do
		HoldOff(HELD_OFF[i])
	end

	-- If cleanup had already nuked ragdoll limits before we snapped the cvar, undo it.
	local maxcount = GetConVar("g_ragdoll_maxcount")
	if maxcount and maxcount:GetInt() == 0 then
		for cname, value in pairs(RAGDOLL_SAFE) do
			RunConsoleCommand(cname, value)
		end
	end
end

local function InstallHoldOffCallbacks()
	for i = 1, #HELD_OFF do
		local entry = HELD_OFF[i]
		local name = entry.name
		local id = "zcnpc_inpc_" .. name

		pcall(cvars.RemoveChangeCallback, name, id)
		cvars.AddChangeCallback(name, function(_, _, new)
			if not ZCNPC.Enabled() then return end
			if new == "0" or new == "0.0" or new == "0.00" or new == "false" then return end

			-- Defer a frame so we win over the menu click / iNPC's own callback.
			timer.Simple(0, function()
				HoldOff(entry)
			end)
		end, id)
	end
end

-- Do NOT flip npc.inpcUseAI. That field is how iNPC opts a unit into its whole
-- tick path; clearing it on knockdowns raced ResumeAI / init order and left
-- standing NPCs (or worse, shared state) without AI. Hidden husks are skipped
-- inside inpcAI instead, and specialized AI is gated with inpcStopAIUntil.
local function PauseAI(npc)
	if not IsValid(npc) then return end

	npc.inpcStopAIUntil = CurTime() + 86400
	npc.zcnpc_inpc_paused = true
end

local function ResumeAI(npc)
	if not IsValid(npc) then return end
	if not npc.zcnpc_inpc_paused then return end

	npc.zcnpc_inpc_paused = nil
	npc.inpcStopAIUntil = nil

	-- Make sure the unit is still opted into iNPC after a long knockdown.
	if npc.inpcUseAI == nil and npc.inpcFaction ~= nil then
		npc.inpcUseAI = true
	end
end

local function IsOrganismNpc(npc)
	if not IsValid(npc) then return false end
	if istable(npc.organism) and npc.organism.fakePlayer then return true end
	if IsValid(npc.zcnpc_rag) then return true end

	return false
end

local function WrapInpcAI()
	if not isfunction(inpcAI) then return end
	if ZCNPC.__inpc_ai_wrapped then return end
	ZCNPC.__inpc_ai_wrapped = true

	local old = inpcAI

	function inpcAI(npc)
		if ZCNPC.Enabled() and IsValid(npc) and ZCNPC.IsHidden(npc) then
			return
		end

		return old(npc)
	end
end

local function WrapRegen()
	if not isfunction(inpcHealthRegeneration) then return end
	if ZCNPC.__inpc_regen_wrapped then return end
	ZCNPC.__inpc_regen_wrapped = true

	local old = inpcHealthRegeneration

	function inpcHealthRegeneration(npc)
		if ZCNPC.Enabled() and IsOrganismNpc(npc) then
			return
		end

		return old(npc)
	end
end

-- Backup if the cvar somehow stays on: never let cleanup zero ragdoll limits.
local function WrapCleanup()
	if not isfunction(inpcCleanup) then return end
	if ZCNPC.__inpc_cleanup_wrapped then return end
	ZCNPC.__inpc_cleanup_wrapped = true

	local old = inpcCleanup

	function inpcCleanup()
		if not ZCNPC.Enabled() then
			return old()
		end

		if not GetConVar("inpc_enabled"):GetBool() then return end

		local cleanupCvar = GetConVar("inpc_cleanup")
		if not cleanupCvar or not cleanupCvar:GetBool() then return end

		HoldOff(HELD_OFF[2]) -- inpc_cleanup

		local maxcount = GetConVar("g_ragdoll_maxcount")
		if maxcount and maxcount:GetInt() == 0 then
			for cname, value in pairs(RAGDOLL_SAFE) do
				RunConsoleCommand(cname, value)
			end
		end

		timer.Simple(0, function()
			for _, v in ipairs(ents.FindByClass("weapon_*")) do
				if IsValid(v) and v:GetOwner() == NULL then
					v:Remove()
				end
			end

			for _, v in ipairs(ents.FindByClass("ai_weapon_*")) do
				if IsValid(v) and v:GetOwner() == NULL then
					v:Remove()
				end
			end

			for _, class in ipairs({ "item_ammo_ar2_altfire", "item_healthvial" }) do
				for _, v in ipairs(ents.FindByClass(class)) do
					if IsValid(v) then v:Remove() end
				end
			end

		end)
	end
end

-- Block airstrike calls even if the float cvar races back on for a tick.
local function WrapAirstrike()
	if not isfunction(inpcCallAirstrike) then return end
	if ZCNPC.__inpc_airstrike_wrapped then return end
	ZCNPC.__inpc_airstrike_wrapped = true

	local old = inpcCallAirstrike

	function inpcCallAirstrike(...)
		if ZCNPC.Enabled() then
			HoldOff(HELD_OFF[3]) -- inpc_airstrike_chane

			return
		end

		return old(...)
	end
end

-- Hidden downed husks stay in the NPC registry with Health > 0.
-- iNPC's checkForEnemies returns true as soon as it *samples* a D_HT NPC —
-- even when it never SetEnemy (unarmed civ / not visible). That skips the
-- Idle Patrolling branch forever once any enemy-faction body is on the floor.
local function IsUseableEnemy(ent)
	if not IsValid(ent) then return false end

	if ent:IsPlayer() then
		return ent:Alive()
	end

	if not ent:IsNPC() then return false end
	if ent:Health() <= 0 then return false end

	if ZCNPC.IsHidden(ent) then
		local rag = ent.zcnpc_rag

		return ZCNPC.IsDownedTargetable ~= nil and ZCNPC.IsDownedTargetable(rag)
	end

	return true
end

local function ClearBadEnemy(npc)
	if not IsValid(npc) then return end

	local enemy = npc:GetEnemy()
	if not IsValid(enemy) then return end
	if IsUseableEnemy(enemy) then return end

	npc:SetEnemy(NULL)
	if npc.ClearEnemyMemory then
		npc:ClearEnemyMemory()
	end
end

local function WrapEnemyScan(name)
	local fn = _G[name]
	if not isfunction(fn) then return end
	if ZCNPC["__" .. name .. "_wrapped"] then return end
	ZCNPC["__" .. name .. "_wrapped"] = true

	_G[name] = function(npc)
		if not ZCNPC.Enabled() then
			return fn(npc)
		end

		ClearBadEnemy(npc)

		local result = fn(npc)

		ClearBadEnemy(npc)

		-- Saw a hostile husk in the sample but never locked a real enemy → allow patrol.
		if result and not IsUseableEnemy(npc:GetEnemy()) then
			return false
		end

		return result
	end
end

local function WrapEnemyScans()
	WrapEnemyScan("inpcCheckForEnemies")
	WrapEnemyScan("inpcCheckForEnemiesOld")
end

local function IdlePatrolWanted()
	local ours = ZCNPC.Config and ZCNPC.Config.idle_patrol
	if ours and not ours:GetBool() then return false end

	local theirs = GetConVar("inpc_patrol")

	return not theirs or theirs:GetBool()
end

-- Keep iNPC's own Idle Patrolling switch in step with ours. Off here means off
-- there; on here turns theirs back on so the Q-menu toggle is the one that counts.
-- Left alone when our addon is disabled — iNPC's menu is theirs again.
local function SyncIdlePatrol()
	if not Present() then return end
	if not ZCNPC.Enabled() then return end

	local ours = ZCNPC.Config and ZCNPC.Config.idle_patrol
	if not ours then return end

	local want = ours:GetBool()
	local cvar = GetConVar("inpc_patrol")
	if not cvar then return end

	if want then
		if not cvar:GetBool() then
			cvar:SetBool(true)
			RunConsoleCommand("inpc_patrol", "1")
		end
	elseif cvar:GetBool() then
		cvar:SetBool(false)
		RunConsoleCommand("inpc_patrol", "0")
	end
end

-- Belt and braces: if iNPC still never reaches the patrol branch (ALERT stuck,
-- wrong schedule), kick standing AI into PATROL ourselves.
local function PatrolAssist()
	if not (ZCNPC.Enabled() and Present()) then return end
	if not GetConVar("inpc_enabled"):GetBool() then return end
	if not IdlePatrolWanted() then return end
	if GetConVar("ai_disabled") and GetConVar("ai_disabled"):GetBool() then return end

	local npcs = ZCNPC.NPCs
	if not npcs then return end

	for npc in pairs(npcs) do
		if not IsValid(npc) then continue end
		if not npc.inpcUseAI then continue end
		if ZCNPC.IsHidden(npc) then continue end
		if npc.inpcIsDeployedManhack then continue end
		if (ZCNPC.GettingUp and (ZCNPC.GettingUp[npc] or 0) > CurTime()) then continue end

		-- The map's own orders outrank an empty street (sv_core.lua). This is the
		-- loudest of the chores that move an NPC - it runs on every idle unit
		-- every two seconds - so a garrison told to hold a rally point walked off
		-- it within a tick of being placed.
		if ZCNPC.MapDriven(npc) then continue end

		-- And so does a needle already in its own leg (sv_cms.lua). An NPC halfway
		-- through the surgical kit is standing in an empty street with no enemy and
		-- nothing on its schedule, which is this pass's own description of somebody
		-- who ought to be walking - so every two seconds it sent one off mid
		-- operation, which is the one thing the kit says ruins it.
		if istable(npc.zcnpc_cms) then continue end
		if istable(npc.zcnpc_meduse) then continue end

		ClearBadEnemy(npc)
		if IsUseableEnemy(npc:GetEnemy()) then continue end

		local sched = npc:GetCurrentSchedule()
		if sched == SCHED_PATROL_WALK or sched == SCHED_PATROL_RUN then continue end
		if sched == SCHED_FORCED_GO_RUN or sched == SCHED_RANGE_ATTACK1 then continue end
		if sched == SCHED_CHASE_ENEMY or sched == SCHED_RUN_FROM_ENEMY then continue end

		local state = npc:GetNPCState()
		if state == NPC_STATE_DEAD then continue end
		if state == NPC_STATE_COMBAT and IsUseableEnemy(npc:GetEnemy()) then continue end

		if state ~= NPC_STATE_IDLE then
			npc:SetNPCState(NPC_STATE_IDLE)
		end

		if math.random() < 0.75 then
			npc:SetSchedule(SCHED_PATROL_WALK)
		else
			npc:SetSchedule(SCHED_PATROL_RUN)
		end
	end
end

function ZCNPC.InstallInpc()
	if not Present() then return false end

	HoldAll()
	SyncIdlePatrol()
	InstallHoldOffCallbacks()
	WrapRegen()
	WrapCleanup()
	WrapAirstrike()
	WrapEnemyScans()
	WrapInpcAI()

	timer.Create("zcnpc_inpc_hold", 1, 0, function()
		if not (ZCNPC.Enabled() and Present()) then return end

		HoldAll()
		SyncIdlePatrol()
		WrapRegen()
		WrapCleanup()
		WrapAirstrike()
		WrapEnemyScans()
		WrapInpcAI()
	end)

	timer.Create("zcnpc_inpc_patrol", 2, 0, PatrolAssist)

	SyncIdlePatrol()
	pcall(cvars.RemoveChangeCallback, "zcnpc_idle_patrol", "zcnpc_inpc_idle_patrol")
	cvars.AddChangeCallback("zcnpc_idle_patrol", function()
		timer.Simple(0, SyncIdlePatrol)
	end, "zcnpc_inpc_idle_patrol")

	-- Heal units left with inpcUseAI=false from older PauseAI builds.
	local npcs = ZCNPC.NPCs
	if npcs then
		for npc in pairs(npcs) do
			if IsValid(npc) and npc.inpcFaction ~= nil and npc.inpcUseAI == false and not ZCNPC.IsHidden(npc) then
				npc.inpcUseAI = true
				npc.inpcStopAIUntil = nil
				npc.zcnpc_inpc_ai = nil
				npc.zcnpc_inpc_paused = nil
			end
		end
	end

	ZCNPC.Debug("iNPC Opti+ bridge armed")

	return true
end

hook.Add("InitPostEntity", "zcnpc_inpc_retry", function()
	if ZCNPC.InstallInpc then ZCNPC.InstallInpc() end
end)

timer.Create("zcnpc_inpc_retry", 2, 15, function()
	if not ZCNPC.InstallInpc then return end
	if ZCNPC.InstallInpc() then
		timer.Remove("zcnpc_inpc_retry")
	end
end)

pcall(cvars.AddChangeCallback, "zcnpc_enabled", function()
	timer.Simple(0, function()
		if ZCNPC.InstallInpc then ZCNPC.InstallInpc() end
	end)
end, "zcnpc_inpc_enabled")

-- After a knockdown we leave them on NPC_STATE_ALERT / combat leftovers.
-- iNPC only starts Idle Patrolling from IDLE + SCHED_IDLE_STAND, so nudge
-- them there once the get-up animation is done and nobody is shooting them.
local function SchedulePatrolReady(npc)
	if not IsValid(npc) then return end
	if IsValid(npc.zcnpc_rag) then return end
	if ZCNPC.GettingUp and (ZCNPC.GettingUp[npc] or 0) > CurTime() then
		timer.Simple(0.25, function()
			SchedulePatrolReady(npc)
		end)

		return
	end

	-- One the map is driving is left where it stands: its behaviour picks it back
	-- up on its own, and SCHED_IDLE_STAND is the one order that would stop it.
	if ZCNPC.MapDriven(npc) then return end

	if IsValid(npc:GetEnemy()) then return end

	npc:SetNPCState(NPC_STATE_IDLE)
	npc:SetSchedule(SCHED_IDLE_STAND)
end

hook.Add("ZCNPC_Downed", "zcnpc_inpc", function(npc)
	if not (ZCNPC.Enabled() and Present()) then return end

	PauseAI(npc)
end)

hook.Add("ZCNPC_WokeUp", "zcnpc_inpc", function(npc)
	if not Present() then return end

	ResumeAI(npc)

	if ZCNPC.Enabled() then
		timer.Simple(0.2, function()
			SchedulePatrolReady(npc)
		end)
	end
end)

hook.Add("ZCNPC_Died", "zcnpc_inpc", function(rag)
	local npc = IsValid(rag) and rag.zcnpc_npc
	if IsValid(npc) then ResumeAI(npc) end
end)

-- Body vanished without WakeUp (cleanup / missing rag): still unstick iNPC AI.
hook.Add("EntityRemoved", "zcnpc_inpc_rag", function(ent)
	if not (IsValid(ent) and ent:IsRagdoll()) then return end

	local npc = ent.zcnpc_npc
	if IsValid(npc) and npc.zcnpc_rag == ent then
		ResumeAI(npc)
	end
end)
