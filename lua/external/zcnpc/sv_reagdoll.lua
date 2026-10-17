--[[
	ReAgdoll on Z-City bodies.

	ReAgdoll finds its ragdolls in three places, and Z-City has taken two of them
	away:

	* NPCs, off the engine's "CreateEntityRagdoll" (reaction_selector.lua:236). A
	  Z-City NPC that this addon lays down never dies the engine way, so that hook
	  only ever sees the corpse of an NPC that died on its feet - which ReAgdoll
	  gets right on its own, and which this file therefore leaves entirely alone.
	* players, off "PlayerDeath" (reaction_selector.lua:145). That path builds a
	  prop_ragdoll of its own and Removes whatever GetRagdollEntity handed it - on
	  Z-City that is the real corpse, with the organism and the loot on it. Held
	  off, and held off twice.
	* everything else, off "OnEntityCreated", three ticks after the ragdoll exists
	  (reaction_selector.lua:469). Our downed bodies come out of that sweep, and
	  what the sweep hands them is a death: one ten-to-thirty second animation, a
	  hundred hit points of ReAgdoll's own, bones that break, and rigor at the end
	  of it.

	A body of ours on the floor is not a corpse, so the third path is claimed before
	it can fire and the body is driven from here instead: short cycles of ReAgdoll's
	own floor reactions with a limp pause between them, at a strength that follows
	how conscious the organism still is, and with every verdict ReAgdoll would pass
	on a corpse held off it. Dying hands the body back - that is the one moment its
	full death reaction is exactly what a body wants.

	Two systems pushing the same bones is the launch that sv_artagdoll.lua avoids.
	When ArtAgdoll is enabled for NPCs, it drives these bodies. ReAgdoll takes over
	only when ArtAgdoll is unavailable or disabled.

	There is nothing here to configure beyond that. ReAgdoll's own menu already owns
	every question worth asking - how hard bodies move (reagdoll_animation_force),
	whether they hold their wounds, whether they stiffen - and a second set of
	switches for the same things would only ever have been a way to make the two
	disagree.
]]

-- [ragdoll] = per-body drive state. Weak keys: a body that fades out takes its
-- entry with it.
ZCNPC.ReagBodies = ZCNPC.ReagBodies or setmetatable({}, { __mode = "k" })

-- Models ReAgdoll cannot describe. RD_ragdollphysics walks a fixed list of
-- ValveBiped bones and returns on the first one it cannot find - before it records
-- the ragdoll at all - so "no entry afterwards" is the only way to ask. Asked once
-- per body rather than four times a second.
local unfit = setmetatable({}, { __mode = "k" })

--\\ Is it here?
local function Installed()
	return istable(RDReagdollMaster) and isfunction(RDReagdollMaster.Activate)
		and isfunction(RDReagdollMaster.Kill)
		and istable(RDSelector) and isfunction(RDSelector.Generic_Death)
		and istable(RDragdollstats) and istable(RD_RAGDOLL_STATE)
		and isfunction(RD_ragdollphysics)
end

-- ReAgdoll has been through here, whether or not it reached the end of itself. Both
-- of these are set by files that run before anything below them can go wrong -
-- RDSelector on the first line of output_manager.lua, RD_RAGDOLL_STATE a few lines
-- into reaction_selector.lua - so either of them standing on its own is an install
-- that started and stopped.
local function Present()
	return Installed()
		or istable(RDSelector) or istable(RD_RAGDOLL_STATE)
		or istable(RDragdollstats) or istable(RD_ListOfCvars)
end

-- What the menu's footer is told, which is a looser question than the one that gates
-- driving a body. Half of ReAgdoll on a body is worse than none of it, so Installed()
-- stays strict everywhere below; but a half loaded ReAgdoll is still one somebody
-- installed, and a footer reading "not installed" about an addon that is visibly
-- running sends people looking in the wrong place for the reason.
ZCNPC.HasReagdoll = Present

--\\ Finishing a load that stopped halfway
-- ReAgdoll declares its sixty convars in lua/autorun/server/cvars.lua and binds each
-- one to a global, and every other file reads those globals rather than the convars.
-- Three places then include that file again on their own account - reaction_selector,
-- output_manager, its client menu - and all three spell it "autorun/server/Cvars.lua",
-- with a capital. Loose files on Windows do not care. A .gma does: gmad lowercases
-- every path it packs, so the lookup misses, the include throws, and whichever file
-- asked is abandoned at that line.
--
-- Nothing about that is visible until the addon is mounted without the autorun pass
-- that would have run the lowercase copy first - enabling it from the addon list
-- mid-session is exactly that - and then the capitalised include is the only thing
-- that would have bound the globals, and it is the one that fails. What is left is a
-- ReAgdoll whose hooks are all registered and whose convars are all nil:
--
--   [ReAgdoll] lua/responses/death_faces.lua:268: attempt to index global
--   'rdcvar_deathface' (a nil value)
--
-- once per frame, forever. And the same missing globals take the rest of the addon
-- with them: RD_Welcomemessage reads rdcvar_sfx_index before it calls
-- RDSelector.Preload (startup.lua:51), so it dies there, Preload never runs, and
-- RDReagdollMaster - which lives in one of the files Preload includes - never exists.
-- That is the global Installed() looks for, which is why a ReAgdoll in this state
-- reported itself as not installed.
--
-- Both halves are one repair, and it is ReAgdoll's own file doing it: included under
-- the name it actually has. CreateConVar hands back convars that already exist, so
-- running it a second time costs nothing and changes nothing on an install that was
-- fine.
local RD_CVARS = "autorun/server/cvars.lua"

-- rdcvar_deathface = DeclareVars( "reagdoll_deathfaces", 1, FCVAR_ARCHIVE, ... )
local DECLARES = "([%w_]+)%s*=%s*DeclareVars%s*%(%s*[\"']([%w_]+)[\"']"

local TRIES = 5 -- a genuinely broken install is not worth an include a second forever
local tried = 0

-- Read out of ReAgdoll's own source rather than listed here. Sixty names that belong
-- to somebody else's addon and change when they rename one is not a list to keep a
-- copy of, and the line each convar is declared on already carries both halves of
-- what is needed.
local function Declared()
	local src = file.Read(RD_CVARS, "LUA")

	-- Somebody else's lua/autorun/server/cvars.lua is a real possibility and not one
	-- to go including on a hunch, so the file has to look like the file.
	if not (isstring(src) and src:find("DeclareVars", 1, true) and src:find("reagdoll_", 1, true)) then return end

	return src
end

local function Bound(src)
	for global in src:gmatch(DECLARES) do
		if _G[global] == nil then return false end
	end

	return true
end

local function Repair()
	if Installed() or not Present() then return end
	if tried >= TRIES then return end

	local src = Declared()
	if not src then return end

	-- Every global already bound means ReAgdoll's own startup is fine and has simply
	-- not finished yet: Preload runs a frame behind reaction_selector on a healthy
	-- load (reaction_selector.lua:27), and stepping in during that frame would only
	-- mean every module of it getting included twice. There is nothing wrong here to
	-- fix, so nothing below this line is ours to do.
	if Bound(src) then return end

	tried = tried + 1

	-- Under the name it has. If this works it is the whole repair: the globals come
	-- back with the flags, bounds and defaults ReAgdoll gave them, and RD_ListOfCvars
	-- comes back with them.
	local ok, err = pcall(include, RD_CVARS)
	if not ok then ZCNPC.Debug("ReAgdoll's own cvars.lua would not load:", err) end

	-- Whatever is still nil, tied back to the convar it belongs to. This is the file
	-- having stopped partway through itself rather than not run at all, and the
	-- convars it got to are registered even though the globals are not.
	for global, name in src:gmatch(DECLARES) do
		if _G[global] == nil then
			local cvar = GetConVar(name)

			if cvar then _G[global] = cvar end
		end
	end

	if not Bound(src) then return end

	ZCNPC.Debug("rebound ReAgdoll's convar globals")

	-- The other half of what RD_Welcomemessage was in the middle of when it died.
	-- REASFX is a separate addon and reagdoll_sfx defaults to on without it, which is
	-- ReAgdoll's next error rather than ours, and turning it off is what its own
	-- checkforaddons does on the branch it never reached (startup.lua:63).
	if istable(RSFX) and table.Count(RSFX) == 0 and rdcvar_sfx and rdcvar_sfx:GetBool() then
		rdcvar_sfx:SetBool(false)
	end

	-- And the call it never made. Everything ReAgdoll animates a body with lives in
	-- the files this includes, RDReagdollMaster among them.
	if istable(RDSelector) and isfunction(RDSelector.Preload) and not istable(RDReagdollMaster) then
		local ok, err = pcall(RDSelector.Preload)

		if not ok then
			ZCNPC.Debug("ReAgdoll's own Preload would not run:", err)
			return
		end
	end

	if Installed() then
		tried = 0
		print("[ZCNPC] ReAgdoll had loaded without its convars; finished loading it")
	end
end

Repair()
hook.Add("InitPostEntity", "zcnpc_reagdoll_repair", Repair)
--//

-- ReAgdoll's own switches; there is no point fighting them. A convar that is not
-- there at all belongs to a version of the addon that never had it, which is not a
-- reason to stay quiet.
local function Switched(name)
	local cvar = GetConVar(name)

	return cvar == nil or cvar:GetBool()
end

function ZCNPC.ReagdollReady()
	return ZCNPC.Enabled() and Installed() and Switched("reagdoll_enabled")
end

-- Our bodies are NPC bodies. reagdoll_players is held off below.
function ZCNPC.ReagdollDrives()
	if ZCNPC.HasArtagdoll and ZCNPC.HasArtagdoll()
		and Switched("ar_enabled") and Switched("ar_enabled_npcs") then return false end

	return ZCNPC.ReagdollReady() and Switched("reagdoll_npcs")
end
--//

--\\ ArtAgdoll stands down
-- ar_enabled is the switch ZCNPC.ArtagdollReady already reads (sv_artagdoll.lua:193),
-- so holding it off is most of the hand-over on its own: every route through that
-- file gates on it, and ArtAgdoll's own CreateEntityRagdoll / DMS_Init read it too -
-- which is the half that matters for the corpse of an NPC that died standing, since
-- that is a body ReAgdoll picks up by itself.
--
-- Put back the moment we stop driving. A convar we turned off is not ours to keep.
local AR_ENABLED = "ar_enabled"
local heldAr = nil -- what ar_enabled said before we took it

local function HoldArtagdoll()
	local cvar = GetConVar(AR_ENABLED)
	if not cvar then return end

	if ZCNPC.ReagdollDrives() then
		if not cvar:GetBool() then return end

		if heldAr == nil then heldAr = cvar:GetString() end
		cvar:SetBool(false)
		ZCNPC.Debug("ReAgdoll is driving, held off", AR_ENABLED)
	elseif heldAr ~= nil then
		local was = heldAr
		heldAr = nil

		cvar:SetString(was)
		ZCNPC.Debug("ReAgdoll stopped driving, gave back", AR_ENABLED)
	end
end

-- The guarantee, for the ArtAgdoll that shipped without ar_enabled: Switched() reads
-- a missing convar as "on", so the hold-off above would have nothing to hold and
-- both systems would drive the same bodies.
if isfunction(ZCNPC.ArtagdollReady) and not ZCNPC.__reagArtagdollReady then
	ZCNPC.__reagArtagdollReady = ZCNPC.ArtagdollReady

	function ZCNPC.ArtagdollReady()
		if ZCNPC.ReagdollDrives() then return false end

		return ZCNPC.__reagArtagdollReady()
	end
end
--//

--\\ Held off on ReAgdoll's side
-- reagdoll_players: its PlayerDeath handler builds a prop_ragdoll of its own and
-- then Removes whatever Player:GetRagdollEntity returned (reaction_selector.lua:184).
-- On Z-City that is the real corpse - the one carrying the organism, the armour and
-- the loot - so the switch is not a matter of taste, and Z-City's own brainfuck
-- spasms are the death twitch a player is supposed to get anyway.
--
-- Forced every second, because a menu click is one console command away from
-- deleting a body.
local HELD_OFF = { "reagdoll_players" }

local function HoldOff(name)
	local cvar = GetConVar(name)
	if not cvar or not cvar:GetBool() then return end

	cvar:SetBool(false)
	ZCNPC.Debug("held off", name)
end

local function HoldOffAll()
	if not ZCNPC.ReagdollReady() then return end

	for i = 1, #HELD_OFF do
		HoldOff(HELD_OFF[i])
	end
end

local function InstallHoldOff()
	HoldOffAll()
	HoldArtagdoll()

	for i = 1, #HELD_OFF do
		local name = HELD_OFF[i]
		local id = "zcnpc_reagdoll_holdoff_" .. name

		pcall(cvars.RemoveChangeCallback, name, id)
		cvars.AddChangeCallback(name, function(_, _, new)
			if not ZCNPC.ReagdollReady() then return end
			if new == "0" or new == "false" then return end

			timer.Simple(0, function() HoldOff(name) end)
		end, id)
	end

	-- Same again for ar_enabled, and for a sharper reason than a deleted body. The
	-- second-by-second sweep below would take it back within a second of anyone
	-- switching it on, and a second is long enough for an NPC to die on its feet: that
	-- corpse is the one body ReAgdoll finds entirely by itself, and ArtAgdoll's own
	-- CreateEntityRagdoll would be reading a convar that says yes at the same moment
	-- (init_active_ragdoll.lua:141). Two systems on one corpse is the launch.
	pcall(cvars.RemoveChangeCallback, AR_ENABLED, "zcnpc_reagdoll_holdoff_ar")
	cvars.AddChangeCallback(AR_ENABLED, function(_, _, new)
		if not ZCNPC.ReagdollDrives() then return end
		if new == "0" or new == "false" then return end

		timer.Simple(0, HoldArtagdoll)
	end, "zcnpc_reagdoll_holdoff_ar")
end

-- ReAgdoll's PlayerDeath builds a fresh prop_ragdoll and deletes whatever
-- GetRagdollEntity returned. Holding the cvar off is not enough if that
-- hook is already registered.
local function StripReagPlayerDeath()
	local list = hook.GetTable()["PlayerDeath"]
	if not istable(list) then return end

	for name, fn in pairs(list) do
		if not isfunction(fn) then continue end

		local info = debug.getinfo(fn, "S")
		local src = info and (info.short_src or "") or ""
		local n = string.lower(tostring(name))
		if string.find(src, "reaction_selector", 1, true)
			or string.find(src, "reagdoll", 1, true)
			or string.find(n, "reagdoll", 1, true)
		then
			hook.Remove("PlayerDeath", name)
		end
	end
end

InstallHoldOff()
StripReagPlayerDeath()
hook.Add("InitPostEntity", "zcnpc_reagdoll_holdoff", function()
	InstallHoldOff()
	StripReagPlayerDeath()
end)
timer.Create("zcnpc_reagdoll_holdoff", 1, 0, function()
	-- On the same second, because the state this repairs is one an addon mounted
	-- mid-session arrives in, and that can happen at any point after we loaded.
	Repair()

	HoldOffAll()
	StripReagPlayerDeath()
	HoldArtagdoll()
end)
cvars.AddChangeCallback("zcnpc_enabled", function()
	timer.Simple(0, InstallHoldOff)
end, "zcnpc_reagdoll_enabled")
--//

--\\ Undoing what RD_ragdollphysics does
-- ReAgdoll normalises every body it takes to one set of masses and inertias so its
-- animations read the same on every model (reaction_selector.lua:369). That is the
-- right call for a corpse and a liberty on a body somebody is about to pick up:
-- Z-City weighs a man by his bones and the hands SWEP reads that weight straight
-- back out to decide how hard you have to pull. The two sets of numbers happen to be
-- close, so this is not a fix for anything anyone would see - it is the guarantee
-- that a body handed back is the body Z-City made.
--
-- The collision group is recorded for the same reason. RD_ragdollphysics writes its
-- own: 11 by default, which is what sv_uncon already used, and 1 if
-- reagdoll_physics_nocollide_all is on - which is a body that collides with nothing,
-- including the floor it is supposed to be lying on.
local function Snapshot(rag)
	if rag.zcnpc_reagsnap then return end

	local snap = { colgroup = rag:GetCollisionGroup(), bones = {} }

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		local lin, ang = phys:GetDamping()
		snap.bones[i] = {
			mass = phys:GetMass(),
			inertia = phys:GetInertia(),
			lin = lin,
			ang = ang,
		}
	end

	rag.zcnpc_reagsnap = snap
end

function ZCNPC.ReagRestorePhysics(rag)
	if not IsValid(rag) then return end

	local snap = rag.zcnpc_reagsnap
	if not snap then return end

	-- A part that has been shot off is a separate question and ZCNPC.SaneGibMass has
	-- already answered it (sv_head.lua): it holds the stump at a minimum weight and
	-- damps it hard so a loose phys does not spike through the mesh. Putting a whole
	-- head's weight and no damping back onto one is not a restoration.
	local gibs = rag.gibRemove

	for i, saved in pairs(snap.bones) do
		if gibs and gibs[i] then continue end

		local phys = rag:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		phys:SetMass(saved.mass)
		phys:SetInertia(saved.inertia)
		phys:SetDamping(saved.lin, saved.ang)
	end
end
--//

--\\ Claiming a body
-- RD_spawned is ReAgdoll's own "somebody else owns this one" flag, read by the
-- OnEntityCreated sweep three ticks after the ragdoll is created
-- (reaction_selector.lua:473). ZCNPC_Downed runs in the same tick as ents.Create,
-- so writing it there wins that race with room to spare - and losing it would mean
-- a living body handed a thirty second death animation.
local function Reserve(rag)
	if not IsValid(rag) then return end

	rag.RD_spawned = true
end

-- Everything ReAgdoll decides about a body it thinks is dying, said "no" to in one
-- place, because all three answers live in the same bitfield:
--
-- * SPECIAL   - no broken bones (ragdoll_master.lua:465) and no death rattle
--               (output_manager.lua:141). A man on the floor with somebody still in
--               him has the bones he had a second ago.
-- * INVINCIBLE- RD_lifemetric returns on it before it reads anything else
--               (ragdoll_master.lua:279). Z-City decides what a round does to a
--               body; a second hundred hit points on the side, with its own instant
--               kills for a head shot and a blast, is one opinion too many.
-- * STIFF     - RDstiff refuses to run while it is set (body_stiff.lua:94), which is
--               the only way to refuse it: every floor reaction ReAgdoll ships
--               declares no follow-up animation, and Activate reads that as "stiffen
--               five sixths of the way through" (ragdoll_master.lua:252). Rigor on a
--               body that is still breathing is a body that cannot be posed, cannot
--               be dragged straight and cannot get up. Cleared when it dies, where
--               the same flag is what lets the death reaction stiffen properly.
local function Refuse(stats)
	stats.State = bit.bor(stats.State or 0,
		RD_RAGDOLL_STATE.SPECIAL + RD_RAGDOLL_STATE.INVINCIBLE + RD_RAGDOLL_STATE.STIFF)
end

local function Allow(stats)
	stats.State = bit.band(stats.State or 0, bit.bnot(
		RD_RAGDOLL_STATE.SPECIAL + RD_RAGDOLL_STATE.INVINCIBLE + RD_RAGDOLL_STATE.STIFF))
end

-- Two things ReAgdoll does off the ragdoll's own collision callback, and neither
-- belongs on a body of ours (puppetmaster.lua:80):
--
-- * it holds on to the environment - a phys_lengthconstraint from a hand to whatever
--   the hand touched, the world included, for up to five seconds. On a body that
--   spends its whole life lying on the floor being dragged, that is a man welded to
--   the ground by one wrist.
-- * it resets Time_On_Air, which is the clock the puppet reads to decide the body is
--   falling and swap to the flailing animation. We keep that clock ourselves below,
--   which is the half of it worth keeping.
--
-- Holding the wound is a different thing entirely and stays: that constraint goes
-- from the hand to the body's own chest, so it travels with the body.
local function StripCallbacks(rag)
	local ids = rag.reagdoll_callbacks
	if not ids then return end

	for _, id in pairs(ids) do
		rag:RemoveCallback("PhysicsCollide", id)
	end

	rag.reagdoll_callbacks = nil
end

local function Stats(rag)
	return RDragdollstats[rag]
end

-- Puppets are removed as their die time runs out, and each removal calls
-- RDReagdollMaster.Kill (puppetmaster.lua:477). Kill with no follow-up animation is
-- the death: it drops the target entity, tears out the collision callbacks, lets go
-- of the wound, stiffens, and latches DEAD - and DEAD is read by every puppet's Think
-- as "stop now" (puppetmaster.lua:206), so one expired cycle would be the last one
-- this body ever got.
--
-- Kill with a follow-up does none of that. It removes the puppet and calls the
-- follow-up. So the follow-up is set, to a function that does nothing: the next cycle
-- is started by the monitor tick, which is where every other decision about this body
-- is already made.
local function NoChain() end

local function Claim(rag)
	if unfit[rag] then return end
	if Stats(rag) then return Stats(rag) end

	Reserve(rag)

	if rag:GetPhysicsObjectCount() < 2 then
		unfit[rag] = true

		return
	end

	-- before anything of ReAgdoll's has touched the body, so what is recorded is the
	-- weight, inertia and damping the model shipped with
	Snapshot(rag)

	RD_ragdollphysics(rag)

	-- RD_ragdollphysics sets the collision group before the bone walk that can bail,
	-- so this is put back whether the claim took or not.
	local snap = rag.zcnpc_reagsnap
	if snap and rag:GetCollisionGroup() ~= snap.colgroup then
		rag:SetCollisionGroup(snap.colgroup)
	end

	local stats = Stats(rag)
	if not stats then
		-- a model missing one of the sixteen bones ReAgdoll needs
		unfit[rag] = true
		ZCNPC.ReagRestorePhysics(rag)
		ZCNPC.Debug("ReAgdoll cannot describe", rag:GetModel())

		return
	end

	Refuse(stats)
	stats.NextAnim = NoChain

	ZCNPC.ReagBodies[rag] = ZCNPC.ReagBodies[rag] or {}

	if ZCNPC.WatchBody then ZCNPC.WatchBody(rag) end
	ZCNPC.Debug("ReAgdoll on", rag)

	return stats
end
--//

--\\ The puppets
-- ReAgdoll drives a ragdoll with puppetmaster entities: one motion controller each,
-- turning a set of the body's bones towards the same bones of an animation playing on
-- a model nobody can see. A floor reaction is two or three of them at once - torso,
-- legs, and sometimes the thighs on their own at a fraction of the strength - and
-- RDragdollstats only ever remembers the last one made, so the set has to be found
-- rather than looked up.
--
-- Found once per pass and shared, not once per body: this is called for every body on
-- the floor within the same tick.
local puppetsAt, puppetsBy = -1, {}

local function Puppets(rag)
	local now = CurTime()

	if now ~= puppetsAt then
		puppetsAt = now
		puppetsBy = {}

		for _, master in ipairs(ents.FindByClass("puppetmaster")) do
			if not master.GetRagdoll then continue end

			local owner = master:GetRagdoll()
			if not IsValid(owner) then continue end

			local list = puppetsBy[owner]
			if list then
				list[#list + 1] = master
			else
				puppetsBy[owner] = { master }
			end
		end
	end

	return puppetsBy[rag]
end

-- Removing a puppet is what Kill is for, and Kill is only safe here because the
-- follow-up is set: see NoChain above. The puppets a reaction made beyond the one
-- ReAgdoll remembers are removed the same way, which is also what their own die-time
-- timer would have done.
--
-- The one ReAgdoll remembers is then forgotten, which matters more than it looks:
-- RDragdollstats never clears Master itself, and the wound grab reads it back without
-- checking it (holdwound.lua:96 tests it against nil, and a removed entity is not
-- nil). A cleared field is the one value that check answers correctly.
local function StopPuppets(rag)
	local stats = Stats(rag)
	if stats then stats.Master = nil end

	local list = Puppets(rag)
	if not list then return end

	for i = 1, #list do
		local master = list[i]
		if IsValid(master) then master:Remove() end
	end

	puppetsAt = -1 -- the cached set is a tick out of date now
end

local function LivePuppet(rag)
	local list = Puppets(rag)
	if not list then return false end

	for i = 1, #list do
		if IsValid(list[i]) then return true end
	end

	return false
end
--//

--\\ How hard a body is still fighting
-- ZCNPC.ActiveStrengthScale is the answer sv_artagdoll.lua already worked out - nought
-- for a knockout or a stopped heart, and a curve off consciousness above it - and
-- there is no reason for a body to fight differently depending on which addon is
-- moving it. Read, never written.
local function Strength(rag)
	if isfunction(ZCNPC.ActiveStrengthScale) then return ZCNPC.ActiveStrengthScale(rag) end

	local org = rag.organism
	if not org then return 1 end
	if org.heartstop or org.otrub then return 0 end

	return math.Clamp(org.consciousness or 1, 0, 1)
end

-- Below this a body is limp, and a limp body does not need three motion controllers
-- to say so. The puppets come off and it is a plain ragdoll until it comes round.
local LIMP = 0.08

-- A body being carried should stay alive in the hands and not fight them. Z-City
-- drags by pulling one bone towards where you are looking (weapon_hands_sh.lua), and
-- a body turning every bone as hard as it can while you do that is a body that will
-- not go where it is put.
local CARRY_SCALE = 0.35

-- Which bodies are in somebody's hands, and by which physics bone. wep.CarryEnt and
-- wep.CarryBone are what sv_pulse.lua already reads for the same question. Built once
-- per tick, for the same reason as Puppets.
--
-- The bone matters as much as the body does: the pelvis is nought, so there is no
-- number here that can stand for "not carried" and the table has to be asked whether
-- it has an entry rather than what the entry says.
local carriedAt, carried = -1, {}

local function BuildCarried()
	local now = CurTime()
	if now == carriedAt then return end

	carriedAt = now
	carried = {}

	for _, ply in ipairs(player.GetAll()) do
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) then continue end

		local ent = wep.CarryEnt
		if not IsValid(ent) then continue end

		carried[ent] = isnumber(wep.CarryBone) and wep.CarryBone or -1
	end
end

local function Carried(rag)
	BuildCarried()

	return carried[rag] ~= nil
end

-- Which bone, or nothing if this body is not being held by one we can name.
local function CarriedBone(rag)
	BuildCarried()

	local bone = carried[rag]

	return (bone and bone >= 0) and bone or nil
end
--//

--\\ Writhing on the floor
-- One cycle of ReAgdoll's own floor reactions, then a limp pause, then another. Its
-- own length for a death is ten to thirty seconds (reagdoll_animation_min / _max),
-- which is right for a body that has one animation left in it and far too long for a
-- body that may be on the floor for a minute: the puppet's strength fades to nothing
-- over its die time (puppetmaster.lua:328), so a single long cycle is a man who
-- struggles once and then lies still while still perfectly conscious.
local CYCLE_MIN, CYCLE_MAX = 4, 8

-- The pause is not only for the look of it. ZCNPC.WakeUp waits for a body to be
-- still (MovingTooFast, sv_uncon.lua:614) before it will stand up, so a body that is
-- never still is a body that never gets up - and being healed and then getting up is
-- the whole point of healing one.
local GAP_MIN, GAP_MAX = 0.8, 2.2

-- RDsquirm reads its die time off a global that RDSelector.Activate happens to leave
-- behind (squirm.lua:11 against output_manager.lua:393). Calling the reactions
-- directly means setting it, the same way the code they were written for does; the
-- other three take the argument.
local function StartCycle(rag, state)
	local seconds = math.Rand(CYCLE_MIN, CYCLE_MAX)

	_G.dietime = seconds

	RDSelector.Generic_Death(rag, seconds)

	state.nextCycle = CurTime() + seconds + math.Rand(GAP_MIN, GAP_MAX)

	-- Activate defers by a frame, and every puppet adds a collision callback of its
	-- own as it spawns (puppetmaster.lua:121) - a new one per cycle, on a body that
	-- may be on the floor for minutes. Taken off as soon as they exist rather than
	-- left to the next monitor pass, because a quarter of a second of that callback is
	-- long enough for a hand to brush the floor and be welded to it.
	timer.Simple(engine.TickInterval() * 2, function()
		if IsValid(rag) then StripCallbacks(rag) end
	end)
end

-- Two numbers ReAgdoll's own reactions can land on that mean "do not move at all",
-- both from the same slip: math.random with fractional arguments floors them, so
-- math.random(.75, 2.0) is math.random(0, 2) and comes up 0 one time in three
-- (wounded.lua:12, deathpose.lua:18-20). A cycle that rolls it is a body that lies
-- perfectly still through a reaction that was supposed to be it struggling.
--
-- The first strength a puppet is given is the one its reaction meant - a fifteenth
-- for squirming legs, a fifth for cowering thighs - so it is kept and scaled, rather
-- than flattened to one number for every bone.
local function DrivePuppet(master, scale)
	local base = master.zcnpc_reag_base

	if base == nil then
		base = master:GetModifier()
		if base <= 0 then base = 1 end

		master.zcnpc_reag_base = base
	end

	if master:GetPlaySpeed() <= 0 then master:SetPlaySpeed(1) end

	local want = base * scale
	if math.abs((master:GetModifier() or 0) - want) < 0.01 then return end

	master:SetModifier(want)
end

local function Drive(rag)
	local list = Puppets(rag)
	if not list then return end

	local scale = Strength(rag)
	if Carried(rag) then scale = scale * CARRY_SCALE end

	for i = 1, #list do
		local master = list[i]
		if IsValid(master) then DrivePuppet(master, scale) end
	end
end
--//

--\\ The bone somebody has hold of
-- Feeling for a pulse is taking hold of a hand or the head and pressing reload
-- (weapon_hands_sh.lua:934), and ReAgdoll takes both halves of that away from a body
-- it is animating:
--
-- * the wound grab welds the hand shut. It is a phys_lengthconstraint from the hand to
--   the wound at a length of five hundredths of a unit and a force limit of ten and a
--   half thousand (holdwound.lua:24-26), and Z-City pulls a carried bone at three
--   thousand at the absolute most (weapon_hands_sh.lua:895). So the hand does not
--   come, and a grip more than a hundred units from where you are aiming is dropped on
--   the spot (:901). The body somebody wants a pulse from is a body that has been shot,
--   and a body that has been shot is the one holding its wound - with one or both of
--   the only two hands the check will accept.
-- * the puppet goes on turning whatever bone you have hold of, which is the same drop
--   for the same reason a little slower.
--
-- ReAgdoll's own answer to the second is DeactivateBone, which is how its own wound
-- grab frees the arm it is about to use (holdwound.lua:101). Said every pass, because
-- every new cycle is a new puppet that never heard of it.
local HAND_SIDE = {
	["ValveBiped.Bip01_L_Hand"] = "L",
	["ValveBiped.Bip01_R_Hand"] = "R",
}

local function BoneName(rag, physbone)
	local bone = rag:TranslatePhysBoneToBone(physbone)
	if not isnumber(bone) or bone < 0 then return end

	return rag:GetBoneName(bone)
end

-- Which hand is welded shut, if the one being held is. Only that side is let go of:
-- the other hand is not in anybody's way, and a body that keeps hold of its wound
-- while you feel its wrist is the whole reason the animation is worth having.
local function ReleaseHand(rag, physbone)
	if not isfunction(RDHoldWound and RDHoldWound.Kill) then return end

	local held = rag.RD_HoldWound
	if not istable(held) then return end

	local side = HAND_SIDE[BoneName(rag, physbone) or ""]
	if not side then return end
	if not IsValid(held[side]) then return end

	RDHoldWound.Kill(rag, side)
	ZCNPC.Debug("ReAgdoll let go of the", side, "hand for a grip", rag)
end

local function FreeGrip(rag)
	local physbone = CarriedBone(rag)
	if not physbone then return end

	ReleaseHand(rag, physbone)

	local list = Puppets(rag)
	if not list then return end

	for i = 1, #list do
		local master = list[i]

		if IsValid(master) and isfunction(master.DeactivateBone) then
			master:DeactivateBone(physbone)
		end
	end
end
--//

--\\ Holding a body to what it is
-- Said every pass rather than once at the hand-over, because every one of them is
-- written by somebody else in between:
--
-- * Time_On_Air is the puppet's own falling clock and it is the puppet that winds it
--   (puppetmaster.lua:286). Half a second of it, on a body moving at all, is the
--   puppet swapping its model for a policeman and its animation for the one used
--   mid-air - and two seconds is the falling scream on top. A body writhing on the
--   ground is moving; it is not falling. Ours is held at nought, which is what the
--   collision callback used to do before it was taken off.
-- * NextAnim is rewritten to "" by every Activate (ragdoll_master.lua:133), which is
--   the DEAD latch one expired cycle later. See NoChain.
-- * DEAD itself, in case anything else set it: while a body is in ZCNPC.Downed there
--   is somebody in it.
-- * the collision callbacks, which every new puppet adds another of. StartCycle takes
--   them off as they appear; this is the guarantee for the one that appeared some
--   other way.
local function Assert(rag, stats)
	stats.Time_On_Air = 0
	stats.NextAnim = NoChain

	Refuse(stats)
	StripCallbacks(rag)

	stats.State = bit.band(stats.State, bit.bnot(RD_RAGDOLL_STATE.DEAD + RD_RAGDOLL_STATE.FLYING))
end

function ZCNPC.ReagOn(rag)
	if not IsValid(rag) then return false end
	if rag.zcnpc_gettingup then return false end

	local stats = Claim(rag)
	if not stats then return false end

	local state = ZCNPC.ReagBodies[rag]
	if not state then return false end

	Assert(rag, stats)

	-- Before the limp branch below, because the wound grab outlives the puppet that
	-- asked for it: the constraint has a removal timer of its own, several seconds long
	-- (holdwound.lua:47), and a body that goes out cold in the middle of one keeps the
	-- welded hand it had. That is the hand somebody is trying to feel a pulse in.
	FreeGrip(rag)

	if Strength(rag) <= LIMP then
		-- out cold: nothing to animate, and three motion controllers saying so is
		-- three motion controllers of nothing
		if LivePuppet(rag) then StopPuppets(rag) end
		state.nextCycle = nil

		return true
	end

	local now = CurTime()

	-- the last time there was somebody in this body fighting the floor, which is the
	-- one thing worth knowing about it when it dies
	state.droveAt = now

	if LivePuppet(rag) then
		Drive(rag)

		return true
	end

	-- the pause between cycles, which is also the window a body needs to be still
	-- enough in to be allowed to stand up
	local nextCycle = state.nextCycle
	if nextCycle and now < nextCycle then return true end

	StartCycle(rag, state)

	return true
end

-- Everything of ReAgdoll's comes off and the body is the body Z-City made: no
-- puppets, no rigor splints, no hand welded to a wound, no collision callbacks, and
-- its own weight back. Called wherever we stop driving one.
function ZCNPC.ReagOff(rag)
	if not IsValid(rag) then return end
	if not Installed() then return end
	-- A collapse is not a body we are driving, and taking it off one is a corpse that
	-- stopped dying halfway through. ZCNPC.ReagThroes owns these until it is finished
	-- with them.
	if (rag.zcnpc_reagthroes or 0) > CurTime() then return end

	local state = ZCNPC.ReagBodies[rag]
	if state then state.nextCycle = nil end

	local stats = Stats(rag)
	if not stats then return end

	StopPuppets(rag)

	if isfunction(RDHoldWound and RDHoldWound.Kill) then RDHoldWound.Kill(rag) end

	StripCallbacks(rag)
	ZCNPC.ReagClearStiff(rag)
	ZCNPC.ReagRestorePhysics(rag)

	ZCNPC.Debug("ReAgdoll off", rag)
end

-- The rigor splints are phys_hinge entities between neighbouring bones, added to the
-- ragdoll's own constraint table and removed on a timer of their own
-- (body_stiff.lua:45). "On a timer of their own" is the problem: getting up is now,
-- and a body wearing them cannot be posed into the animation that stands it up.
--
-- Only phys_hinge is taken. The other thing ReAgdoll constrains a body with is a
-- length constraint, and both kinds of those are somebody else's to remove - a broken
-- bone should stay broken, and the wound grab has RDHoldWound.Kill.
function ZCNPC.ReagClearStiff(rag)
	if not IsValid(rag) then return end

	local list = rag.Constraints
	if istable(list) then
		for key, ent in pairs(list) do
			if IsValid(ent) and ent:GetClass() == "phys_hinge" then
				ent:Remove()
				list[key] = nil
			end
		end
	end

	local stats = Stats(rag)
	if stats then
		stats.State = bit.band(stats.State or 0, bit.bnot(RD_RAGDOLL_STATE.STIFF))
	end
end
--//

--\\ Dying
-- How long a corpse is given to finish dying. ReAgdoll's own answer is ten to thirty
-- seconds (reagdoll_animation_min / _max), which is a corpse still fighting the floor
-- half a minute after it was declared dead - and its strength has faded to nothing
-- long before the end of that anyway.
local DEATH_TIME = 6

-- Which deaths ReAgdoll is allowed to be told about. The list is short on purpose:
-- these four are the branches of Select_Reaction that only animate.
--
-- Fire is the one that must never get through. RDSelector.Fire ends in
-- RDBurnfx.MakeCorpse, which Removes the ragdoll and spawns a charple model in its
-- place (fire_effects.lua) - and the ragdoll it would remove is the corpse, with the
-- loot, the armour and the organism on it. Everything unrecognised comes through as a
-- bullet, which is the ordinary collapse.
local DEATH_TYPES = DMG_BULLET + DMG_BUCKSHOT + DMG_CRUSH + DMG_SLASH

local function DeathType(rag)
	local dmgtype = rag.zcnpc_reag_dmgtype or 0
	local kept = bit.band(dmgtype, DEATH_TYPES)

	return kept == 0 and DMG_BULLET or kept
end

local function DeathPos(rag)
	local pos = rag.zcnpc_reag_dmgpos or rag.zcnpc_dmgpos

	return isvector(pos) and pos or rag:WorldSpaceCenter()
end

-- Stop, and stay stopped. No rigor: a body that reaches this line has been declared
-- finished by something that is not ReAgdoll - a head shot, a head that came off, a
-- corpse being shot again - and every one of those wants a limp body on the floor,
-- which is the whole reason sv_head.lua goes out of its way to get one.
function ZCNPC.ReagDie(rag)
	if not IsValid(rag) then return end
	-- The hand-over itself, and nothing longer. ZCNPC_Died is answered in this file and
	-- in sv_artagdoll.lua, and that file's answer reaches ActiveDie for these bodies
	-- (its own gate is held off, so that is where it sends them) - so one of the two
	-- would stop the collapse the instant the other started it, and which one is hook
	-- order between two files, which is not something to lean on.
	--
	-- A tenth of a second, because the sentence a moment later is a different sentence:
	-- the finish-off hook in that same file puts a round into a corpse that has not
	-- finished dying and calls ActiveDie for it (sv_artagdoll.lua:829), and being able
	-- to end a collapse that way is the whole point of it.
	if (rag.zcnpc_reaghandover or 0) > CurTime() then return end
	if not Installed() then return end

	local stats = Stats(rag)
	if not stats then return end

	rag.zcnpc_reagthroes = nil -- whatever it was still doing, it has been finished off
	ZCNPC.ReagOff(rag)

	-- Nothing decides anything after this. DEAD is ReAgdoll's own way of saying so:
	-- every puppet's Think stops on it, its face and hand animations drop the body,
	-- and Kill returns on it - so a second hand-over from a path nobody thought of is
	-- still a corpse when it lands.
	stats.NextAnim = ""
	stats.State = bit.bor(stats.State or 0, RD_RAGDOLL_STATE.DEAD)

	ZCNPC.Debug("ReAgdoll stopped", rag)
end

-- Dying with somebody still in it. This is the one body ReAgdoll's own death reaction
-- is exactly right for, and the one moment everything held off it above is let go:
-- the bones may break, the face may set, the hand may reach for the wound, and the
-- body may stiffen at the end - because this time it really is dying.
function ZCNPC.ReagThroes(rag)
	if not IsValid(rag) then return ZCNPC.ReagDie(rag) end
	if not (ZCNPC.ReagdollDrives() and isfunction(RDSelector.Select_Reaction)) then
		return ZCNPC.ReagDie(rag)
	end

	local stats = Claim(rag)
	if not stats then return ZCNPC.ReagDie(rag) end

	-- Both written before the reaction starts, because both are read by things that may
	-- run before this function returns. See ZCNPC.ReagDie for the difference between
	-- them: one is the hand-over, the other is the collapse.
	rag.zcnpc_reaghandover = CurTime() + 0.1
	rag.zcnpc_reagthroes = CurTime() + DEATH_TIME

	-- the living body's cycle, and the flags that kept it a living body
	StopPuppets(rag)
	ZCNPC.ReagClearStiff(rag)
	Allow(stats)

	stats.NextAnim = ""
	stats.State = bit.band(stats.State, bit.bnot(RD_RAGDOLL_STATE.DEAD))
	stats.Time_Snapshot = CurTime()

	local dmgpos = DeathPos(rag)
	local _, hitgroup = RD_PhysDamagePos(dmgpos, rag)

	RDSelector.Select_Reaction(rag, DEATH_TIME, dmgpos, DeathType(rag), hitgroup)

	if ZCNPC.WatchBody then ZCNPC.WatchBody(rag, DEATH_TIME + 1) end
	ZCNPC.Debug("ReAgdoll collapse", rag)

	-- Its own weight back while the collapse is still running, so the last of it is a
	-- body coming to rest rather than one still being turned.
	timer.Simple(DEATH_TIME, function()
		if not IsValid(rag) then return end

		rag.zcnpc_reagthroes = nil
		ZCNPC.ReagRestorePhysics(rag)
	end)
end
--//

--\\ Being shot on the ground
-- RD_lifemetric is where ReAgdoll answers a round, and it is held off our living
-- bodies entirely - it keeps a second health bar, breaks bones off the damage force
-- and kills outright on a head shot or a blast, and Z-City has already decided all
-- four of those. What it does that nothing else does is flinch, so the flinch is said
-- here instead, off the damage Z-City actually kept.
local TWITCH_GAP = 0.3
local HOLD_GAP = 5

hook.Add("HomigradDamage", "zcnpc_reagdoll", function(victim, dmgInfo, _, ent)
	if not ZCNPC.ReagdollDrives() then return end

	-- the first argument is the player behind a body rather than the body itself
	-- whenever there is one (sv_input.lua:888); the fourth is always what was hit
	local rag = IsValid(ent) and ent or victim
	if not (IsValid(rag) and rag:IsRagdoll()) then return end

	local stats = Stats(rag)
	if not stats then return end

	local pos = dmgInfo:GetDamagePosition()
	if isvector(pos) and pos ~= vector_origin then rag.zcnpc_reag_dmgpos = pos end
	rag.zcnpc_reag_dmgtype = dmgInfo:GetDamageType()

	if rag.zcnpc_corpse or rag.zcnpc_dead then return end
	if not (ZCNPC.Downed and ZCNPC.Downed[rag]) then return end

	local state = ZCNPC.ReagBodies[rag]
	if not state then return end

	local now = CurTime()

	if isfunction(RDBodyTwitch and RDBodyTwitch.Twitch) and (state.twitchAt or 0) < now then
		state.twitchAt = now + TWITCH_GAP
		RDBodyTwitch.Twitch(rag)
	end

	-- A hand pressed to a fresh wound, which is the best thing ReAgdoll does and the
	-- one part of it that reads as a man rather than a ragdoll. Its own chance roll
	-- (reagdoll_hold_chance) is left to it; the interval is ours, because Z-City
	-- reports a burst one round at a time and the grab takes the whole arm off the
	-- motion controller each time it is asked for.
	--
	-- Only while a cycle is actually running. Taking an arm off a controller that is
	-- not there is nothing, and reaching for a wound is something a body does while it
	-- is still struggling.
	if not isfunction(RDHoldWound and RDHoldWound.Activate) then return end
	if not Switched("reagdoll_hold") then return end
	if (state.holdAt or 0) > now then return end
	if not IsValid(stats.Master) then return end
	if Strength(rag) <= LIMP then return end -- nobody home to reach with
	-- and not into somebody's hands. FreeGrip would let go of it again on the next pass
	-- anyway; not welding a hand shut a quarter of a second before unwelding it is the
	-- shorter way round, and it does not matter which hand was being held.
	if Carried(rag) then return end

	state.holdAt = now + HOLD_GAP
	RDHoldWound.Activate(rag, rag.zcnpc_reag_dmgpos)
end)
--//

--\\ Who is driving
local function SpineBroken(org)
	if not (istable(hg) and istable(hg.organism)) then return false end

	local s1 = hg.organism.fake_spine1 or 1
	local s2 = hg.organism.fake_spine2 or 1
	local s3 = hg.organism.fake_spine3 or 0.5

	return (org.spine1 or 0) >= s1
		or (org.spine2 or 0) >= s2
		or (org.spine3 or 0) >= s3
end

-- The same list sv_artagdoll.lua works from, for the same reasons: a body being stood
-- up, a body that is finished, a body with nothing on its shoulders, and a broken
-- spine - which is real paralysis, and the one case where the right look is a ragdoll
-- doing nothing at all.
local function WantsReagdoll(rag)
	local org = rag.organism
	if not org then return false end

	if rag.zcnpc_gettingup then return false end
	if rag.zcnpc_dead then return false end
	if rag.headexploded or rag.noHead then return false end
	if bit.band(rag:GetFlags(), FL_DISSOLVING) == FL_DISSOLVING then return false end

	if org.alive == false then return false end -- the collapse is started once, by ZCNPC_Died
	-- Out cold is Strength() == 0: ReagOn already drops the puppets. Taking
	-- the whole claim off is why a body that came round never squirmed again.
	if (org.brain or 0) >= 1 then return false end
	if rag.zcnpc_headkill then return false end

	local npc = rag.zcnpc_npc
	if IsValid(npc) and npc.zcnpc_headkill then return false end

	if SpineBroken(org) then return false end

	return true
end

function ZCNPC.UpdateReagdoll(rag)
	if not IsValid(rag) then return end

	if not ZCNPC.ReagdollDrives() then return ZCNPC.ReagOff(rag) end
	if rag.zcnpc_corpse then
		if (rag.zcnpc_reagthroes or 0) <= CurTime() then
			return ZCNPC.ReagDie(rag)
		end

		return
	end
	if rag.zcnpc_dead then return ZCNPC.ReagOff(rag) end

	if WantsReagdoll(rag) then
		ZCNPC.ReagOn(rag)
	else
		ZCNPC.ReagOff(rag)
	end
end

-- The monitor calls this every quarter second for every body on the floor.
-- Release the previous controller before handing the body to the next one.
if isfunction(ZCNPC.UpdateActive) and not ZCNPC.__reagUpdateActive then
	ZCNPC.__reagUpdateActive = ZCNPC.UpdateActive

	function ZCNPC.UpdateActive(rag)
		if not ZCNPC.ReagdollDrives() then ZCNPC.ReagOff(rag) end
		ZCNPC.__reagUpdateActive(rag)
		if ZCNPC.ReagdollDrives() then ZCNPC.UpdateReagdoll(rag) end
	end
end

-- ActiveOff is called in two quite different senses. sv_head.lua means it: a body
-- with a round through its brain goes limp on that line and the kill lands a fraction
-- of a second later. sv_artagdoll.lua's own UpdateActive means only "there is no
-- ArtAgdoll here", which is true four times a second while it is held off. Asking
-- whether the body still wants driving tells the two apart - and it is the same
-- question our own tick is about to ask anyway.
if isfunction(ZCNPC.ActiveOff) and not ZCNPC.__reagActiveOff then
	ZCNPC.__reagActiveOff = ZCNPC.ActiveOff

	function ZCNPC.ActiveOff(rag)
		ZCNPC.__reagActiveOff(rag)

		if not IsValid(rag) then return end
		if not WantsReagdoll(rag) then ZCNPC.ReagOff(rag) end
	end
end

if isfunction(ZCNPC.ActiveDie) and not ZCNPC.__reagActiveDie then
	ZCNPC.__reagActiveDie = ZCNPC.ActiveDie

	function ZCNPC.ActiveDie(rag)
		ZCNPC.__reagActiveDie(rag)
		ZCNPC.ReagDie(rag)
	end
end

-- "Is something animating this body." Read by the finish-off hook in
-- sv_artagdoll.lua, which is a round into a corpse that has not finished dying, and
-- means exactly the same thing about a ReAgdoll collapse.
if isfunction(ZCNPC.IsActive) and not ZCNPC.__reagIsActive then
	ZCNPC.__reagIsActive = ZCNPC.IsActive

	function ZCNPC.IsActive(rag)
		if not IsValid(rag) then return false end
		if Installed() and LivePuppet(rag) then return true end

		return ZCNPC.__reagIsActive(rag)
	end
end
--//

--\\ Handing the bodies over
-- Claimed in the same tick the ragdoll is created, which is the whole point of being
-- here rather than waiting for the monitor: ReAgdoll's OnEntityCreated sweep fires
-- three ticks from now, and what it would hand this body is a death.
hook.Add("ZCNPC_Downed", "zcnpc_reagdoll", function(npc, rag)
	if not IsValid(rag) then return end

	Reserve(rag)

	if not ZCNPC.ReagdollDrives() then return end

	-- where the round that put this body down went in, which is what the wound grab
	-- reaches for. Read off Z-City's own bullet trace rather than ReAgdoll's damage
	-- tracking: the last hit an NPC takes before it goes down is the organism killing
	-- itself off a DamageInfo with no position on it at all.
	if isfunction(ZCNPC.LastHit) then
		local pos = ZCNPC.LastHit(npc)
		if isvector(pos) then rag.zcnpc_reag_dmgpos = pos end
	end

	ZCNPC.UpdateReagdoll(rag)
end)

-- Getting up needs the body to hold still, and StartGetUp freezes its physics objects
-- to make sure of it. A motion controller would go on turning them, and a body still
-- wearing rigor splints cannot be posed at all.
hook.Add("ZCNPC_GetUp", "zcnpc_reagdoll", function(_, rag)
	if not IsValid(rag) then return end

	rag.zcnpc_gettingup = true
	ZCNPC.ReagOff(rag)
end)

hook.Add("ZCNPC_WokeUp", "zcnpc_reagdoll", function(_, _, rag)
	ZCNPC.ReagOff(rag)
end)

-- Only for a body that was still moving when it died, which is the difference between
-- a death and a death throe. Most of the bodies this addon makes die out cold:
-- knocked out, heart stopped, a minute of lying perfectly still, and then the
-- bleed-out timer runs out. Handing that one a collapse is a corpse that has been
-- quiet for a minute hauling itself half upright to die a second time.
--
-- Asked of the drive clock rather than of the organism, because by the time this hook
-- runs the organism is a stopped heart and a strength of nought no matter how it got
-- there. Three seconds is one gap between cycles and a little over.
local FIGHT_MEMORY = 3

local function Fighting(rag)
	local state = ZCNPC.ReagBodies[rag]
	if not state then return false end

	return CurTime() - (state.droveAt or 0) < FIGHT_MEMORY
end

hook.Add("ZCNPC_Died", "zcnpc_reagdoll", function(rag)
	if not IsValid(rag) then return end
	if not Installed() then return end

	if rag.zcnpc_headkill or rag.headexploded or rag.noHead then
		return ZCNPC.ReagDie(rag)
	end

	if ZCNPC.IsOutCold and ZCNPC.IsOutCold(rag.organism) then
		return ZCNPC.ReagDie(rag)
	end

	if not (ZCNPC.ReagdollDrives() and Stats(rag)) then return ZCNPC.ReagDie(rag) end
	if not Fighting(rag) then return ZCNPC.ReagDie(rag) end

	ZCNPC.ReagThroes(rag)
end)
--//

--\\ Player corpses stay out of it
-- reagdoll_players is held off above, which closes the PlayerDeath path that would
-- have deleted the corpse outright. ReAgdoll still finds a player's body two other
-- ways - the OnEntityCreated sweep, and the engine's own CreateEntityRagdoll if
-- anything ever builds one - and both of those would animate a Z-City corpse that is
-- already twitching under Z-City's brainfuck spasms.
local function StayDead(rag)
	if not IsValid(rag) then return end

	Reserve(rag)

	if not Installed() then return end
	if not Stats(rag) then return end

	ZCNPC.ReagDie(rag)
end

hook.Add("RagdollDeath", "zcnpc_reagdoll_player", function(ply, rag)
	if not ZCNPC.Enabled() then return end
	if not (IsValid(ply) and ply:IsPlayer() and IsValid(rag)) then return end

	StayDead(rag)

	-- after the sweep's three ticks, and after Z-City's own spasms start
	timer.Simple(0.2, function() StayDead(rag) end)
end)

hook.Add("PostPlayerDeath", "zcnpc_reagdoll_player", function(ply)
	if not ZCNPC.Enabled() then return end

	local rag = ply:GetNWEntity("RagdollDeath")
	if not IsValid(rag) then rag = ply.FakeRagdoll end
	if not IsValid(rag) then return end

	StayDead(rag)

	timer.Simple(0.2, function() StayDead(rag) end)
end)

hook.Add("CreateEntityRagdoll", "zcnpc_reagdoll_noplayer", function(owner, rag)
	if not ZCNPC.Enabled() then return end
	if not (IsValid(owner) and owner:IsPlayer() and IsValid(rag)) then return end

	StayDead(rag)

	timer.Simple(0.12, function() StayDead(rag) end)
end)
--//
