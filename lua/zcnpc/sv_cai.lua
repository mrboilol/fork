--[[
	Combat Intelligence AI.

	CAI is a second brain bolted onto the stock one: it keeps its own memory of
	who it has seen and where, picks its own targets out of that memory, and hands
	the NPC a schedule several times a second to act on. Two of those three are
	things this addon also does, and left alone they disagree in ways that are
	visible from across the room.

	The first is the one people report as "they shoot dead bodies". CAI decides
	whether somebody is worth shooting with two lines (sh_util.lua:9): is it valid,
	and is its health above zero. FL_NOTARGET, which is the engine's way of saying
	"stop looking at this one" and the way the rest of the addon says it, is only
	honoured for players. A knocked out NPC is a hidden entity with its health
	intact standing exactly where it fell, so to CAI it is a live enemy that has
	simply stopped being visible - and an enemy that stops being visible is what
	suppressing fire is for. It plants an invisible marker on the last place it saw
	it and shoots at that, on purpose, for as long as the memory lasts.

	So the memory is what has to be corrected, not the aim. When a body stops being
	worth shooting the addon says so out loud once (ZCNPC_TargetLost,
	sv_execute.lua) and this listens: every NPC CAI is running forgets that enemy,
	its squad forgets it, the marker comes down and anybody who was suppressing the
	spot is put back on cover. And the question itself is answered properly from
	then on, because a husk with a body on the floor is not a target however much
	health the engine thinks it has.

	The second is the schedules. Everything in this addon that walks an NPC
	somewhere - to a dropped rifle, to a vest, to a wounded ally, to a body worth
	searching, to a friend on the floor who has to be dragged out of it - does it
	by taking the schedule, and CAI takes it straight back on its next tick. While one of those errands is running its brain is left to
	perceive and remember and nothing else, which is the closest thing CAI has to
	"not now". It gets its schedule back the moment the errand ends.

	The third is the one people report as "hostile rebels walk straight past
	civilians". CAI puts every NPC it registers into a squad, and it picks the
	squad off two things: the faction its class is listed under
	(shared/sh_config.lua) and whether there is one within 900 units with room in
	it (sv_squad.lua:58). Every npc_citizen there is - a refugee, a rebel, and a
	rebel somebody spawned hostile - is listed as "resistance", so all three are
	the same faction to it and any two of them standing near each other end up in
	one squad. Joining one is not a label: it writes D_LI at priority 99 in both
	directions between the new member and everybody already in it
	(sv_squad.lua:29), which is the strongest thing an entity relationship can
	say, and it lands on top of whatever hostility the map, the gamemode or the
	spawner had set. So the hostile rebel now likes the refugee, the refugee
	likes it back, and CAI then finishes the job by deleting anything it is
	friendly with out of its own memory and the engine's (sv_target.lua:41).
	Nobody shoots anybody, and it reads as the hostility never having been set.

	So the squad is what has to be corrected, and correcting it is choosing a
	different one rather than refusing to have one: an NPC is put with a squad of
	its faction that it is not at war with, and gets one of its own when there is
	no such squad nearby. Everything CAI does with a squad still works for a
	squad of one. Dispositions are then left exactly as they were found, which is
	the whole of the fix - a squad of people who already agreed with each other
	does not need to be told to.

	Nothing here is a patch to CAI's files. Three of its functions are wrapped and
	the originals are called for everybody who is not one of ours.
]]

local cfg = ZCNPC.Config

local function Enabled()
	if not ZCNPC.Enabled() then return false end
	if cfg.cai and not cfg.cai:GetBool() then return false end

	return istable(CAI)
end

--\\ Who CAI should leave alone, and when
-- The same line sv_execute.lua draws for FL_NOTARGET, asked of the husk rather
-- than of the body: a conscious man on the floor is still worth finishing off and
-- stays shootable, an unconscious or dead one is not.
local function Untargetable(ent)
	if not (IsValid(ent) and ent:IsNPC()) then return false end

	local rag = ent.zcnpc_rag
	if not IsValid(rag) then return false end

	if not ZCNPC.IsDownedTargetable then return true end

	return not ZCNPC.IsDownedTargetable(rag)
end

-- An NPC in the middle of something this addon sent it to do. CAI is welcome to
-- keep watching; it is not welcome to hand out a schedule until this is over.
local function Busy(npc)
	if not IsValid(npc) then return false end

	if IsValid(npc.zcnpc_fetch) then return true end
	if IsValid(npc.zcnpc_fetcharmor) then return true end
	if IsValid(npc.zcnpc_healally) then return true end
	if IsValid(npc.zcnpc_lootbody) then return true end
	if istable(npc.zcnpc_cms) then return true end
	if istable(npc.zcnpc_meduse) then return true end
	if istable(npc.zcnpc_rescue) then return true end
	if (npc.zcnpc_bandagecover or 0) > CurTime() then return true end
	if (ZCNPC.GettingUp and (ZCNPC.GettingUp[npc] or 0) or 0) > CurTime() then return true end

	return false
end
--//

--\\ Making one NPC forget one enemy, everywhere it is written down
-- CAI keeps the same enemy in four places and they expire on different clocks:
-- its own memory (45 seconds after the last sighting), the squad's shared
-- blackboard (which does not check whether the enemy is alive at all), the
-- engine's enemy memory, and - if it was suppressing - an invisible npc_bullseye
-- standing in for the enemy it cannot see. Clearing three of the four leaves an
-- NPC still shooting.
local function ForgetOne(npc, data, victim)
	-- The blackboard first and unconditionally, because it is the squad's and not
	-- this NPC's: a soldier who never saw the body still has to stop being told
	-- about it by the one who did.
	local squad = data.squad
	if istable(squad) and istable(squad.blackboard) and istable(squad.blackboard.enemies) then
		squad.blackboard.enemies[victim] = nil
	end

	local remembered = istable(data.memory) and istable(data.memory.enemies)
		and data.memory.enemies[victim] ~= nil

	local aiming = IsValid(npc) and isfunction(npc.GetEnemy) and npc:GetEnemy() == victim

	-- Everybody else on the map is holding nothing of this one and there is
	-- nothing to correct.
	if not (remembered or aiming or data.combatTarget == victim) then return end

	if remembered then data.memory.enemies[victim] = nil end

	if data.combatTarget == victim then
		data.combatTarget = nil
		data.combatRec = nil
	end

	-- The last place it was seen, which is the thing being shot at rather than the
	-- body: a search walks to it and suppression puts rounds into it on purpose.
	data.search = nil
	data.investigatePos = nil

	-- Suppression aims at an invisible marker standing in for the enemy, so an NPC
	-- doing it has the marker as its engine enemy and not the victim - which is
	-- why the test above cannot see it and why this is a state check.
	local brain = CAI.Brain

	if data.state == CAI.STATE.SUPPRESS or data.state == CAI.STATE.SEARCH then
		if isfunction(brain and brain.StopSuppressing) then brain.StopSuppressing(data) end
		if isfunction(brain and brain.SetState) then
			brain.SetState(data, CAI.STATE.COVER, "zcnpc_target_down")
		end
	end

	if not IsValid(npc) then return end

	if isfunction(npc.ClearEnemyMemory) then
		-- The one-argument form forgets this enemy; the old call took none, which
		-- threw away everything the NPC knew about everybody.
		if not pcall(npc.ClearEnemyMemory, npc, victim) then
			npc:ClearEnemyMemory()
		end
	end

	if aiming and isfunction(npc.SetEnemy) then npc:SetEnemy(NULL) end
end

function ZCNPC.CaiForget(victim)
	if not Enabled() then return end
	if not IsValid(victim) then return end

	local manager = CAI.Manager
	if not (istable(manager) and isfunction(manager.All)) then return end

	for npc, data in pairs(manager.All()) do
		if istable(data) then ForgetOne(npc, data, victim) end
	end
end
--//

--\\ Who belongs in a squad with whom
-- CAI's own two numbers for that, from sv_squad.lua: how far away a squad may be
-- to still be the one an NPC joins, and how many it holds. Both are locals there,
-- and both have to be these numbers rather than numbers of our own - a squad
-- chosen on a different radius is a squad CAI would not have made, which is a
-- second answer to the same question rather than a correction to the first.
local SQUAD_RADIUS = 900
local SQUAD_MAX = 8

-- At war, in either direction. Both directions because the relationship being
-- written over is written both ways: the refugee that stops being a target is
-- also the refugee that stops shooting back, and either half of that is enough
-- to say these two do not belong in one squad.
--
-- D_FR counts with D_HT. Something that is afraid of an NPC is not its ally, and
-- squadding the two would tell it to hold formation on what it is running from.
--
-- The medic and the rescue need the same question answered and one copy of it is
-- enough (ZCNPC.NpcAtWar in sv_core.lua).
local AtWar = ZCNPC.NpcAtWar

local function SquadAccepts(squad, npc)
	if not istable(squad) or not istable(squad.members) then return false end

	for _, member in ipairs(squad.members) do
		if IsValid(member) and member ~= npc and AtWar(member, npc) then return false end
	end

	return true
end

-- CAI's Place, with the one condition it is missing. Same faction, same radius,
-- same size limit, nearest first - and not a squad this NPC is at war with.
local function Place(npc)
	local squads = CAI.Squad
	if not (istable(squads) and istable(squads.Squads)) then return false end
	if not (isfunction(squads.Create) and isfunction(squads.AddMember)) then return false end

	local manager = CAI.Manager
	if not (istable(manager) and isfunction(manager.Get) and manager.Get(npc)) then return false end

	local classes = istable(CAI.Config) and CAI.Config.NPCClasses
	local info = istable(classes) and classes[npc:GetClass()]
	local faction = istable(info) and info.faction or "custom"

	local best, bestDist = nil, SQUAD_RADIUS * SQUAD_RADIUS

	for _, squad in pairs(squads.Squads) do
		if squad.faction ~= faction then continue end
		if #squad.members >= SQUAD_MAX then continue end
		if not SquadAccepts(squad, npc) then continue end

		-- The leader when there is one, the first member when there is not, which
		-- is the anchor CAI measures from.
		local anchor = squad.leader or squad.members[1]
		if not IsValid(anchor) then continue end

		local dist = anchor:GetPos():DistToSqr(npc:GetPos())
		if dist < bestDist then best, bestDist = squad, dist end
	end

	squads.AddMember(best or squads.Create(faction), npc)

	return true
end

-- A squad that was right when it was formed and is not any more. Relationships
-- are set by whoever is spawning - a gamemode's wave, a map's own trigger, a
-- weapon that turns a crowd on somebody - and any of them can land after CAI has
-- already put the two together, which no amount of care at the moment of joining
-- can catch. So the question is asked again on a slow timer, and an NPC that has
-- since fallen out with the people around it is placed again from scratch.
local function Regroup()
	if not Enabled() then return end

	local squads = CAI.Squad
	if not (istable(squads) and istable(squads.Squads)) then return end
	if not isfunction(squads.RemoveMember) then return end

	-- Collected first: leaving a squad rewrites the member list being walked, and
	-- re-placing rewrites the table of squads around it.
	local leaving = {}

	for _, squad in pairs(squads.Squads) do
		if not istable(squad.members) then continue end

		-- Whoever was there first keeps the squad, and only the ones who disagree
		-- with them leave. Asking "is this member at war with any other" instead
		-- would answer yes for both sides of every falling out and empty the whole
		-- squad to settle an argument between two of its eight.
		local kept = {}

		for _, member in ipairs(squad.members) do
			if not IsValid(member) then continue end

			local war = false
			for _, other in ipairs(kept) do
				if AtWar(member, other) then war = true break end
			end

			if war then
				leaving[#leaving + 1] = { squad = squad, npc = member }
			else
				kept[#kept + 1] = member
			end
		end
	end

	for _, split in ipairs(leaving) do
		if IsValid(split.npc) then
			squads.RemoveMember(split.squad, split.npc)
			Place(split.npc)

			ZCNPC.Debug("split", split.npc, "out of a squad it is at war with")
		end
	end
end
--//

--\\ The three wrappers
local installed = false

local function Install()
	if installed then return end
	if not istable(CAI) then return end

	local util = CAI.Util
	local brain = CAI.Brain
	if not (istable(util) and istable(brain)) then return end
	if not (isfunction(util.IsTargetable) and isfunction(brain.Think)) then return end

	installed = true

	-- 1. A husk with a body on the floor is not somebody to shoot at.
	local targetable = util.IsTargetable
	util.IsTargetable = function(ent, ...)
		if Enabled() and Untargetable(ent) then return false end

		return targetable(ent, ...)
	end

	-- 2. Perceive and remember, but do not hand out a schedule, while the addon
	-- has the NPC walking somewhere.
	--
	-- Everything a tick does apart from deciding and acting still happens, which
	-- is not politeness: memory, suppression and morale all decay on the clock
	-- rather than per tick, so an NPC that skipped them for a four second errand
	-- would come back with a four second hole in what it knows and still be as
	-- pinned down as it was when it left.
	local think = brain.Think
	brain.Think = function(data, dt, ...)
		local npc = istable(data) and data.ent

		-- The hidden half of a body on the floor. Unregistered on ZCNPC_Downed, but
		-- CAI registers a tenth of a second after spawn and can land after that.
		if Enabled() and ZCNPC.IsHidden and ZCNPC.IsHidden(npc) then return end

		if Enabled() and Busy(npc) then
			if isfunction(brain.Perceive) then pcall(brain.Perceive, data) end

			local memory = CAI.Memory
			if istable(memory) and isfunction(memory.Fade) then pcall(memory.Fade, data) end

			local suppression = CAI.Suppression
			if istable(suppression) and isfunction(suppression.Decay) then
				pcall(suppression.Decay, data, dt)
			end

			local morale = CAI.Morale
			if istable(morale) and isfunction(morale.Regen) then pcall(morale.Regen, data, dt) end

			return
		end

		return think(data, dt, ...)
	end

	-- 3. A squad is people who agree with each other, not people who share a
	-- faction column. Ours runs instead of CAI's rather than around it, because
	-- the damage is done by the join itself and there is nothing to undo
	-- afterwards - the D_LI it writes over a hostility is not recoverable, the
	-- old value is simply gone.
	local squads = CAI.Squad
	if istable(squads) and isfunction(squads.Place) then
		local place = squads.Place
		squads.Place = function(npc, ...)
			-- Everything Place needs is optional and read off CAI at the time, so a
			-- version of it that keeps its squads somewhere else falls through to
			-- its own rather than losing them.
			if Enabled() and IsValid(npc) then
				local ok, handled = pcall(Place, npc)
				if ok and handled then return end
			end

			return place(npc, ...)
		end

		timer.Create("zcnpc_cai_regroup", 3, 0, Regroup)
	end

	ZCNPC.Debug("Combat Intelligence AI bridge installed")
end

-- Immediately when CAI is already up, which it is on a normal boot: it loads from
-- its own lua/autorun and this file is included from ours. Being late used to cost
-- nothing, because the two wrappers above are read at the moment they are called
-- and it does not matter when they were put there. The third one does: CAI writes
-- over a hostility the first time it puts an NPC in a squad and the old value is
-- gone, so a wrapper installed after the map's own NPCs were registered is a
-- wrapper that arrived after the damage. The waits below are still there for a
-- CAI that loads late.
Install()

hook.Add("InitPostEntity", "zcnpc_cai", function()
	Install()
	timer.Simple(1, Install)
end)

hook.Add("OnReloaded", "zcnpc_cai", function()
	installed = false
	Install()
end)

timer.Simple(1, Install)
--//

--\\ Listening
-- Said once, by whoever decided the body was finished with: a knockout
-- (sv_execute.lua) or the death that follows one (sv_uncon.lua).
hook.Add("ZCNPC_TargetLost", "zcnpc_cai", function(victim)
	ZCNPC.CaiForget(victim)
end)

-- A frozen entity is not a soldier and there is nothing for a brain to decide
-- about it. It is put back in when it stands up, because CAI only ever registers
-- an NPC on the frame it was created.
hook.Add("ZCNPC_Downed", "zcnpc_cai", function(npc)
	if not Enabled() then return end

	local manager = CAI.Manager
	if not (istable(manager) and isfunction(manager.Unregister)) then return end
	if not (istable(manager.NPCs) and manager.NPCs[npc]) then return end

	npc.zcnpc_cai_had = true
	manager.Unregister(npc)
end)

hook.Add("ZCNPC_WokeUp", "zcnpc_cai", function(npc)
	if not Enabled() then return end
	if not (IsValid(npc) and npc.zcnpc_cai_had) then return end

	npc.zcnpc_cai_had = nil

	local manager = CAI.Manager
	if istable(manager) and isfunction(manager.Register) then manager.Register(npc) end
end)
--//
