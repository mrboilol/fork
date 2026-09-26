--[[
	Core: gives the Z-City organism to additional NPC classes, names them,
	turns engine deaths into proper Z-City corpses and adds fall damage.
]]

local cfg = ZCNPC.Config

ZCNPC.Tracked = ZCNPC.Tracked or {} -- NPCs that got their organism from THIS addon

--\\ Class / model eligibility
local function HasHumanSkeleton(ent)
	for _, bone in ipairs(cfg.RequiredBones) do
		if not ent:LookupBone(bone) then return false end
	end
	return true
end

function ZCNPC.ShouldManage(ent)
	if not IsValid(ent) or not ent:IsNPC() then return false end

	local class = ent:GetClass()
	if cfg.Blacklist[class] then return false end
	if ZCNPC.IsZombie(ent) then return false end

	-- Natives are Z-City's (sv_npcstuff.lua npcorg). That hook reads GetClass
	-- on the same frame as OnEntityCreated, when the class is often still
	-- empty, so the three HL2 soldiers spawn with no organism and this addon
	-- used to refuse to hang one. If they already have it, SetupNPC returns
	-- before this is asked. If they do not, they are ours.
	if cfg.NativeClasses[class] then
		return HasHumanSkeleton(ent)
	end

	if not cfg.allnpcs:GetBool() then
		if not cfg.HumanClasses[class] then return false end
	end

	return HasHumanSkeleton(ent)
end

-- ZBase copies its table onto an engine class (often npc_combine_s /
-- npc_citizen / npc_zbase_snpc) after ents.Create. IsZBaseNPC is only
-- true once that copy has run.
function ZCNPC.IsZBaseNPC(ent)
	if not IsValid(ent) then return false end
	if ent.IsZBaseNPC then return true end
	if isfunction(ent.GetNWBool) and ent:GetNWBool("IsZBaseNPC", false) then return true end
	if ent.ZBaseInitialized or ent.ZBase_Spawned then return true end
	if isstring(ent.NPCName) and istable(ZBaseNPCs) and ZBaseNPCs[ent.NPCName] then
		return true
	end

	return false
end

-- Empty GetModel is not "no body". The class still has a stock mesh; the
-- ragdoll and a late SetModel on the NPC both use this so a kick does not
-- walk past someone who has not finished arriving.
function ZCNPC.ResolveNPCModel(ent)
	if not IsValid(ent) then return cfg.FallbackRagdollModel end

	local mdl = isfunction(ent.GetModel) and ent:GetModel() or nil
	if isstring(mdl) and mdl ~= "" then return mdl end

	local class = isfunction(ent.GetClass) and ent:GetClass() or ""
	return (cfg.ClassModels and cfg.ClassModels[class]) or cfg.FallbackRagdollModel
end
--//

--\\ NPCs the map is driving
-- Everything in this addon that moves an NPC does it by taking the schedule off
-- it: fetching a dropped rifle (sv_disarmed.lua), walking to a piece of armour
-- (sv_armor.lua), crossing to a wounded ally or ducking into cover
-- (sv_medical.lua), patrolling an empty street (sv_inpc.lua). On a map that is
-- only a room and some spawned NPCs, that schedule was standing still, and
-- taking it is free.
--
-- On a map somebody built it is not. A scripted_sequence waiting for its cue, an
-- ai_goal_assault holding a squad at a rally point, a citizen following whoever
-- it was told to follow - the schedule is the map, and pulling an NPC off it
-- reads from the floor as a garrison that abandons its post and wanders at you,
-- which is what these chores were doing on the scripted maps.
--
-- So the question is asked in one place and answered for all of them, rather
-- than five chores each guessing.
local SF_WAIT_FOR_SCRIPT = 128

-- Lambda campaign maps drive named / map-placed NPCs with scripted_sequence
-- and aiscripted_schedule. Between cues they look idle, so patrol / medical /
-- loot used to steal the schedule and the station froze: Barney at the Nova
-- Prospekt door, scenes missing razor_train_cop_1.
--
-- The organism stays. A kick (and the rest of the body) reads it, and taking
-- it off was why Barney could not be floored. What stays on the map's rails
-- is the schedule: MapDriven answers that for every chore, not the body.
function ZCNPC.IsCampaignActor(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return false end
	if engine.ActiveGamemode() ~= "lambda" then return false end

	local class = npc:GetClass()
	if cfg.HumanClasses[class] then return true end

	local name = isfunction(npc.GetName) and npc:GetName() or ""
	if isstring(name) and name ~= "" then return true end

	if isfunction(npc.CreatedByMap) and npc:CreatedByMap() then return true end

	return false
end

function ZCNPC.ReleaseCampaignActor(ent)
	if not IsValid(ent) then return end

	if istable(hg) and istable(hg.organism) and isfunction(hg.organism.Remove) and ent.organism ~= nil then
		pcall(hg.organism.Remove, ent)
	end

	ent.organism = nil
	if ZCNPC.Tracked ~= nil then
		ZCNPC.Tracked[ent] = nil
	end
end

function ZCNPC.MapDriven(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return false end

	-- Mid sequence. Not a matter of taste and so not switchable: an NPC pulled
	-- out of one halfway is how a map's own set pieces come apart.
	if npc:GetNPCState() == NPC_STATE_SCRIPT then return true end

	if ZCNPC.IsCampaignActor(npc) then return true end

	if not cfg.respect_scripts:GetBool() then return false end

	-- Named in a sequence that has not begun, or placed to be woken by one.
	if npc:GetCurrentSchedule() == SCHED_WAIT_FOR_SCRIPT then return true end
	if npc:HasSpawnFlags(SF_WAIT_FOR_SCRIPT) then return true end

	-- An ai_goal_* holds it: assault, standoff, follow, act busy, lead. Z-City's
	-- own NPCs ask this the same way before choosing a schedule of their own
	-- (z_city/lua/homigrad/abnormalty_detection/swarm/npc_swarm.lua:441).
	if isfunction(npc.IsRunningBehavior) and npc:IsRunningBehavior() then return true end

	return false
end
--//

--\\ Whose side an NPC is on
-- Two errands ask this and both used to answer it with Disposition == D_LI: whether
-- a medic crosses a street to bandage somebody (sv_medical.lua) and whether a
-- soldier drags him out of the open (sv_rescue.lua). It is the wrong test, and it
-- is wrong in both directions at once.
--
-- Too loose, which is the half people report: a rebel somebody spawned hostile
-- bandages the rebels it is shooting at. Half-Life 2's own relationship table has
-- CLASS_CITIZEN_REBEL liking CLASS_CITIZEN_REBEL, by class, so the two kinds of
-- rebel like each other before anybody has said anything - and nothing about
-- "hostile" is written between them, because the way one is made hostile is a
-- relationship to a player. Combat Intelligence used to make it worse by writing
-- D_LI at priority 99 across a squad, which sv_cai.lua now heads off, but the class
-- default was underneath it the whole time.
--
-- Too strict, which is the half nobody thought to look for: two Combine soldiers do
-- not like each other. CLASS_COMBINE against itself is D_NU in that same table -
-- neutral, which is all a squad needs in order not to shoot itself - while the rebel
-- entry is D_LI. So rebels dragged their wounded out of the street and Combine never
-- did, and from the floor that reads as the body being too heavy for them.
--
-- So an ally is not somebody the table says you like. It is somebody you are not at
-- war with who also agrees with you about the people around you.
local HOSTILE = { [D_HT] = true, [D_FR] = true }

-- At war, in either direction. Being hated counts as hating: whichever way round
-- the table holds it, these are not two men on one side. D_FR is in with D_HT
-- because something running from an NPC is not its ally either.
function ZCNPC.NpcAtWar(a, b)
	if not (IsValid(a) and IsValid(b)) then return false end
	if not (isfunction(a.Disposition) and isfunction(b.Disposition)) then return false end

	if HOSTILE[a:Disposition(b)] then return true end

	return HOSTILE[b:Disposition(a)] or false
end

-- Disagreeing about a third party, which is the part no relationship between the
-- two of them can be wrong about. One of them wants that man dead and the other is
-- looking after him: whatever they are to each other, they are not on one side.
--
-- Only the flat contradiction counts. Neutral is not an opinion - an NPC that has
-- never been told anything about anybody is not thereby everyone's enemy - so a
-- disagreement has to be one saying D_LI against the other saying D_HT.
local function Split(a, b, other)
	if not IsValid(other) or other == a or other == b then return false end

	local da = a:Disposition(other)
	if da == D_LI then return HOSTILE[b:Disposition(other)] or false end

	if HOSTILE[da] then return b:Disposition(other) == D_LI end

	return false
end

-- The players are where the answer usually is, and Z-City's player classes are why.
-- Choosing rebel writes D_LI onto every resistance NPC on the map and D_HT onto
-- every Combine one (playerclass/classes/sh_rebel.lua:272); choosing refugee writes
-- the opposite pair. So a hostile rebel and a friendly one hold opposite opinions of
-- the same man however they feel about each other, and two Combine soldiers hold the
-- same one - which is the whole of both bugs, read off the one relationship nobody
-- overwrites.
--
-- player.GetAll builds a table per call and this is asked of every NPC inside a
-- search radius by two errands on the same pass. The list changes when somebody
-- connects, not between two questions in one frame.
local plyList, plyFrame = {}, -1

local function Players()
	local frame = FrameNumber()
	if frame ~= plyFrame then
		plyFrame = frame
		plyList = player.GetAll()
	end

	return plyList
end

-- True when the two of them belong to the same side. Cheapest question first: being
-- at war is one relationship lookup and settles most pairs outright.
function ZCNPC.SameSide(a, b)
	if not (IsValid(a) and IsValid(b)) then return false end
	if a == b then return true end
	if not (isfunction(a.Disposition) and isfunction(b.Disposition)) then return false end

	if HOSTILE[a:Disposition(b)] then return false end
	if HOSTILE[b:Disposition(a)] then return false end

	for _, ply in ipairs(Players()) do
		if Split(a, b, ply) then return false end
	end

	-- Nobody on the map to disagree about, or nobody either of them has an opinion
	-- of. What is left is the fight itself: an NPC shooting at somebody the other is
	-- looking after is the one piece of evidence that survives an empty server.
	if isfunction(a.GetEnemy) and Split(a, b, a:GetEnemy()) then return false end
	if isfunction(b.GetEnemy) and Split(a, b, b:GetEnemy()) then return false end

	return true
end

ZCNPC.Players = Players
--//

--\\ Who else is on the map
-- Everybody who is not a prop, for the errands that want the few entities that can
-- be shot at rather than all of them. ents.FindInSphere is the natural way to write
-- "anybody near me" and the wrong way to ask it here: it hands back the whole
-- contents of a sphere - crates, doors, spent shells, every bandage anybody has
-- ever dropped - so that the caller can throw away all but the handful that are
-- people, and the throwing away is per entity per NPC per pass. A map with a
-- thousand pieces of scenery on it costs the same as a map with a thousand rebels.
--
-- So track the people instead and let the callers walk this. Same shape of answer,
-- and its size is the number of NPCs alive rather than the size of the map.
-- Written the way sv_armor.lua writes its armour registry, and adopted rather than
-- created so it does not matter who loads first (sv_cms.lua asks before this file
-- is read).
--
-- Weak keys: a removed NPC should not be kept alive by being remembered. The
-- CallOnRemove is what actually keeps this clean - the weakness is only there so
-- that anything the engine takes away behind our back cannot leak either.
ZCNPC.NPCs = ZCNPC.NPCs or setmetatable({}, { __mode = "k" })

local function TrackNPC(ent)
	if not (IsValid(ent) and ent:IsNPC()) then return end

	ZCNPC.NPCs[ent] = true
	ent:CallOnRemove("zcnpc_npc_registry", function(e)
		ZCNPC.NPCs[e] = nil
	end)
end

hook.Add("OnEntityCreated", "zcnpc_npc_registry", function(ent)
	-- IsNPC is valid here even when GetClass is not. A timer per casing /
	-- debris / dropped mag is what a firefight used to pay for this list.
	if not (IsValid(ent) and ent:IsNPC()) then return end

	timer.Simple(0, function() TrackNPC(ent) end)
end)

-- Whatever was already standing there before this file was read (lua refresh,
-- late load, a Homigrad restart).
local function ScanNPCs()
	for _, ent in ipairs(ents.GetAll()) do TrackNPC(ent) end
end

hook.Add("InitPostEntity", "zcnpc_npc_registry", ScanNPCs)
hook.Add("HomigradRun", "zcnpc_npc_registry", function() timer.Simple(0, ScanNPCs) end)
hook.Add("PostCleanupMap", "zcnpc_npc_registry", ScanNPCs)

ScanNPCs()
--//

--\\ Names (same NW keys Z-City uses for its own NPCs)
local function PrettyClassName(class)
	local name = class:gsub("^npc_", ""):gsub("_", " ")
	return name:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
end

local defaultColor = Vector(200, 200, 200) / 255

function ZCNPC.ApplyName(ent)
	if not cfg.names:GetBool() then return end

	local class = ent:GetClass()
	local data = cfg.Names[class]
	local name = data and data[1] or PrettyClassName(class)
	local color = data and data[2] or defaultColor

	ent:SetNWString("PlayerName", name)
	ent:SetNWVector("PlayerColor", color)
	ent.GetPlayerName = function() return name end
end
--//

--\\ The inner monologue, on somebody who has nobody to show it to
-- The organism modules talk to whoever owns them as if it were a player, and
-- almost everything they say is behind org.isPly. One line is not: the lungs
-- module types at anybody whose analgesia is over 1.5
-- (organism/tier_1/modules/sv_lungs.lua:274) without the guard the three lines
-- around it have, and that module runs for every organism with fakePlayer set.
--
-- Notify, NotifyBerserk and ResetNotification are on the Player metatable and
-- nowhere else (sv_notification.lua:153), so an NPC on painkillers took the whole
-- Org Think pass down with it - every organism on the map for that tick, not only
-- its own.
--
-- No-ops rather than anything that reaches a screen: the messages are somebody's
-- own thoughts about their own body, and an NPC has nobody to think at. Anything
-- that asks first (a bear trap taking a leg off, ent_pat_beartrap:202) gets the
-- same nothing it got when the method was missing.
local function Unheard() return false end

function ZCNPC.Silence(ent)
	if not IsValid(ent) then return end
	if ent.Notify == Unheard then return end

	ent.Notify = Unheard
	ent.NotifyBerserk = Unheard
	ent.ResetNotification = Unheard

	-- Combat Stims (and the lungs module it ships) ask this on every tick.
	-- Players have it; an NPC does not, and the next line after it is Notify.
	if not isfunction(ent.IsBerserk) then
		ent.IsBerserk = Unheard
	end
end

-- The lungs module types at org.owner whenever analgesia is over 1.5, with no
-- isPly guard (sv_lungs.lua:274). Combat Stims puts every NPC over that line,
-- and a corpse Z-City built itself was never handed Unheard - so one think of
-- one stimmed soldier is a Lua error, and the hook that walks every organism
-- then does it again next tick (the x2594 in the console).
--
-- Silence the owner the module is about to talk to, then let it run. Hooking
-- Org Think ourselves is too late: Z-City registered that hook first and the
-- lungs are inside it.
local wrappedLungs

local function PatchLungsNotify()
	if not (istable(hg) and istable(hg.organism) and istable(hg.organism.module)) then
		return
	end

	local lungs = hg.organism.module.lungs
	if not (istable(lungs) and isfunction(lungs[2])) then return end
	if lungs[2] == wrappedLungs then return end

	local orig = lungs[2]

	wrappedLungs = function(owner, org, timeValue)
		local held = org and org.owner

		if isentity(held) and IsValid(held) then
			if ZCNPC.SanitizeFakeRagdoll then ZCNPC.SanitizeFakeRagdoll(held) end
			if not held:IsPlayer() then
				ZCNPC.Silence(held)
			end
		end

		if isentity(owner) and IsValid(owner) then
			if ZCNPC.SanitizeFakeRagdoll then ZCNPC.SanitizeFakeRagdoll(owner) end
			if owner ~= held and not owner:IsPlayer() then
				ZCNPC.Silence(owner)
			end
		end

		return orig(owner, org, timeValue)
	end

	lungs[2] = wrappedLungs
end

local function SilenceList()
	if not (istable(hg) and istable(hg.organism) and istable(hg.organism.list)) then
		return
	end

	for owner, org in pairs(hg.organism.list) do
		if isentity(owner) and IsValid(owner) and not owner:IsPlayer() then
			ZCNPC.Silence(owner)
		end

		local held = istable(org) and org.owner
		if isentity(held) and IsValid(held) and held ~= owner and not held:IsPlayer() then
			ZCNPC.Silence(held)
		end
	end
end

ZCNPC.PatchLungsNotify = PatchLungsNotify
--//

--\\ Organism attach
-- Homigrad's Add only hangs { owner = ent }. Clear is what fills blood,
-- canmove, consciousness. Call Clear(nil) and every Org Clear hook dies
-- (mildronate, then the rest of the spawn). Lambda can fire PlayerSpawn
-- / "Player Spawn" before PlayerInitialSpawn has hung one: spectator
-- queue, late Homigrad, a lua refresh. One place hangs it, and finishes
-- it, for a player or an NPC.
function ZCNPC.HangOrganism(ent)
	if not IsValid(ent) then return nil end
	if ZCNPC.SanitizeFakeRagdoll then ZCNPC.SanitizeFakeRagdoll(ent) end
	if not (istable(hg) and istable(hg.organism) and isfunction(hg.organism.Add)) then
		return nil
	end

	if istable(ent.organism) then
		if ent.organism.canmove == nil and isfunction(hg.organism.Clear) then
			pcall(hg.organism.Clear, ent.organism)
		end

		return ent.organism
	end

	if ent:IsNPC() then
		if ZCNPC.IsZombie(ent) then return nil end

		local class = isfunction(ent.GetClass) and ent:GetClass() or ""
		if cfg.Blacklist[class] then return nil end

		-- Wait. Do not SetModel. Custom SNPCs often arrive with an empty
		-- GetModel for a tick and then put their own mesh on. Pinning the
		-- citizen fallback here replaced that mesh — or crashed the spawn
		-- outright — which is "workshop NPCs do not appear".
		local have = isfunction(ent.GetModel) and ent:GetModel() or nil
		if not isstring(have) or have == "" then
			return nil
		end

		-- ZBaseInitialize is still copying its table / calling Spawn.
		-- Hanging an organism in that gap is the same abort as npcorg.
		if istable(ZBaseNPCs) and not ZCNPC.IsZBaseNPC(ent)
			and (ent.SpawnModel ~= nil or ent.ZBaseInitialized == false)
		then
			return nil
		end
	end

	hg.organism.Add(ent)
	if not istable(ent.organism) then return nil end

	if isfunction(hg.organism.Clear) then
		pcall(hg.organism.Clear, ent.organism)
	end

	if ent:IsNPC() then
		ent.organism.fakePlayer = true
		ZCNPC.Silence(ent)
		if ZCNPC.ApplyName then ZCNPC.ApplyName(ent) end
	end

	return ent.organism
end

local wrappedClear

local function PatchOrganismClear()
	if not (istable(hg) and istable(hg.organism) and isfunction(hg.organism.Clear)) then
		return
	end
	if hg.organism.Clear == wrappedClear then return end

	local old = hg.organism.Clear
	wrappedClear = function(org)
		if not istable(org) then return end

		return old(org)
	end
	hg.organism.Clear = wrappedClear
end

local function PatchPlayerOrgGuards()
	local meta = FindMetaTable("Player")
	if not meta or meta._ZCNPCOrgGuard then return end

	local function wrap(name)
		local old = meta[name]
		if not isfunction(old) then return end

		meta[name] = function(self, ...)
			if not istable(self.organism) then return false end

			return old(self, ...)
		end
	end

	wrap("IsBerserk")
	wrap("IsStimulated")
	meta._ZCNPCOrgGuard = true
end

local function EnsurePlayerOrganism(ply)
	if not (IsValid(ply) and ply:IsPlayer()) then return end

	ZCNPC.HangOrganism(ply)
end

-- "!" so this runs before Homigrad's Clear(ply.organism) and before
-- inventory Give trips handcuffs / KeyPress / IsBerserk.
hook.Add("PlayerInitialSpawn", "!zcnpc_player_org", EnsurePlayerOrganism)
hook.Add("PlayerSpawn", "!zcnpc_player_org", EnsurePlayerOrganism)
hook.Add("Player Spawn", "!zcnpc_player_org", EnsurePlayerOrganism)

for _, ply in ipairs(player.GetAll()) do
	EnsurePlayerOrganism(ply)
end

timer.Create("zcnpc_player_org", 1, 0, function()
	if not ZCNPC.Enabled() then return end

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and not istable(ply.organism) then
			ZCNPC.HangOrganism(ply)
		end
	end
end)

function ZCNPC.SetupNPC(ent)
	if not ZCNPC.Enabled() then return end

	if ent.organism then -- someone (Z-City) already did it
		-- Z-City's own three classes hand themselves one, and they are drugged out
		-- of the same kit as everybody else (sv_medical.lua) by a pass that walks
		-- every organism on the map. Not ours to manage, but ours to keep quiet.
		-- A ragdoll corpse is the other half: npcloot never called Silence, and
		-- that is the owner the lungs module talks to after they go down.
		if not ent:IsPlayer() then
			ZCNPC.Silence(ent)
		end

		return
	end

	if not ZCNPC.ShouldManage(ent) then return end

	if not ZCNPC.HangOrganism(ent) then return end

	ZCNPC.Tracked[ent] = true

	ZCNPC.Debug("organism attached to", ent, ent:GetClass())
end

local function TrySetup(ent)
	if not IsValid(ent) then return end
	ZCNPC.SetupNPC(ent)
	if ent.organism then return end

	-- Bones are not always there on the first tick. One more try after
	-- the model has finished arriving.
	timer.Simple(0.5, function()
		if IsValid(ent) and not ent.organism then ZCNPC.SetupNPC(ent) end
	end)
end

hook.Add("OnEntityCreated", "zcnpc_organism", function(ent)
	-- next tick: the model/bones are set by then. Z-City's npcorg is
	-- deferred to this same tick so ZBase can finish Spawn first.
	-- Only NPCs: a timer per prop is the same firefight tax as the registry.
	if not (IsValid(ent) and ent:IsNPC()) then return end

	timer.Simple(0, function() TrySetup(ent) end)
end)

-- Z-City's npcorg runs inside OnEntityCreated — the same stack as
-- ents.Create. ZBase does ents.Create(engine class) and only then
-- Initialize / SetModel / Spawn. Add + Clear + SyncArmor in that gap
-- aborts ZBaseInitialize, which is a custom ZBase NPC that never appears.
-- Move that work to the next tick, after Spawn has finished.
local function DeferNativeOrg()
	local hooks = hook.GetTable()["OnEntityCreated"]
	local old = hooks and hooks.npcorg
	if not isfunction(old) then return end
	if old == ZCNPC.__npcorg then return end

	local wrapped = function(ent)
		if not (IsValid(ent) and ent:IsNPC()) then
			return old(ent)
		end

		timer.Simple(0, function()
			if IsValid(ent) and not ent.organism then old(ent) end
		end)
	end

	ZCNPC.__npcorg = wrapped
	hook.Add("OnEntityCreated", "npcorg", wrapped)
	ZCNPC.Debug("deferred Z-City npcorg past ents.Create")
end

DeferNativeOrg()
hook.Add("HomigradRun", "zcnpc_defer_npcorg", function()
	timer.Simple(0, DeferNativeOrg)
end)
timer.Create("zcnpc_defer_npcorg", 5, 0, DeferNativeOrg)

-- Already on the map when this file loads (Load waits for Homigrad).
for _, ent in ipairs(ents.GetAll()) do
	if IsValid(ent) and ent:IsNPC() then
		TrySetup(ent)
	end
end

-- Late class / late model: walk the registry, hang whatever is still empty.
timer.Create("zcnpc_org_backfill", 1, 0, function()
	if not ZCNPC.Enabled() then return end

	for npc in pairs(ZCNPC.NPCs or {}) do
		if IsValid(npc) and not npc.organism and not IsValid(npc.zcnpc_rag) then
			ZCNPC.SetupNPC(npc)
		end
	end
end)

-- Already standing there when we load, and Z-City rewriting lungs after a
-- lua refresh: both leave Notify missing on whoever the module is about to
-- talk to.
local function InstallSilence()
	PatchLungsNotify()
	PatchOrganismClear()
	PatchPlayerOrgGuards()
	SilenceList()
end

InstallSilence()
hook.Add("InitPostEntity", "zcnpc_lungs_notify", InstallSilence)
hook.Add("HomigradRun", "zcnpc_lungs_notify", function()
	timer.Simple(0, InstallSilence)
end)
timer.Create("zcnpc_lungs_notify", 5, 0, InstallSilence)
--//

--\\ Mark a finished NPC body
-- The organism stays on hg.organism.list and keeps thinking — that is what
-- keeps a dead body bleeding. These only name the ragdoll as a corpse for
-- loot / execute / ReAgdoll, they do not zero bleed or take it off the list.
function ZCNPC.ParkCorpse(rag)
	if not IsValid(rag) then return end
	if ZCNPC.Downed and ZCNPC.Downed[rag] then return end

	rag.zcnpc_corpse = true
	rag.zcnpc_keepbody = true
	rag:SetNWBool("zcnpc_corpse", true)
end

function ZCNPC.ScheduleParkCorpse(rag)
	ZCNPC.ParkCorpse(rag)
end

--\\ Engine ragdoll that must not exist
-- KillDowned / a knockdown already has a body on the floor. Some NPC classes
-- still emit a CreateEntityRagdoll from Remove() or an engine kill, and the
-- hooks below would copy the organism onto that second doll. Drop it before
-- any of them run — Remove() is deferred, so later hooks in the same call
-- still see a valid entity unless they ask this first.
function ZCNPC.HasOwnBody(ent)
	if not IsValid(ent) then return false end

	return IsValid(ent.zcnpc_rag) or IsValid(ent.zcnpc_mh_body)
end

function ZCNPC.DropEngineRagdoll(ent, rag)
	if not (IsValid(ent) and IsValid(rag) and ent:IsNPC()) then return false end
	if rag.zcnpc_drop then return true end
	if rag == ent.zcnpc_rag or rag == ent.zcnpc_mh_body then return false end
	if rag.zcnpc_keepbody then return false end

	if not (ZCNPC.Enabled() and (ZCNPC.HasOwnBody(ent) or ent.zcnpc_noragdoll or ent.DontCreateRagdoll)) then
		return false
	end

	rag.zcnpc_drop = true
	timer.Simple(0, function()
		if IsValid(rag) then rag:Remove() end
	end)

	return true
end

--\\ Engine-style death of a managed NPC -> Z-City corpse
-- (mirrors the "npcloot" CreateEntityRagdoll hook from z_city/lua/homigrad/sv_npcstuff.lua,
--  which only processes Z-City's own 3 classes)
function ZCNPC.TransferOrganismToCorpse(ent, rag)
	if not (IsValid(ent) and IsValid(rag) and ent.organism) then return end

	local newOrg = hg.organism.Add(rag)
	table.Merge(newOrg, ent.organism)

	ZCNPC.Silence(rag)

	hook.Run("RagdollDeath", ent, rag)

	zb.net.list[rag] = zb.net.list[rag] or {}
	table.Merge(zb.net.list[rag], zb.net.list[ent] or {})

	newOrg.alive = false
	newOrg.owner = rag
	rag:CallOnRemove("organism", hg.organism.Remove, rag)
	rag.fullsend = true
	hg.send_bareinfo(newOrg)

	rag:SetNetVar("wounds", newOrg.wounds or {})
	rag:SetNetVar("arterialwounds", newOrg.arterialwounds or {})

	rag:SetNWString("PlayerName", ent:GetNWString("PlayerName"))
	rag:SetNWVector("PlayerColor", ent:GetNWVector("PlayerColor"))

	-- npcloot (natives) and this path both used to leave corpses without an Armor
	-- NetVar; TransferArmor pushes the worn kit the client actually draws.
	if ZCNPC.TransferArmor then ZCNPC.TransferArmor(ent, rag) end

	hg.organism.list[ent] = nil
	ent.organism = nil

	-- Death lines fire in Event_Killed, often before this ragdoll exists.
	-- Keep the pairing so EntityEmitSound can move them onto the body.
	ent.zcnpc_rag = rag
	rag.zcnpc_npc = ent

	rag.zcnpc_corpse = true
	rag.zcnpc_keepbody = true
	rag:SetNWBool("zcnpc_corpse", true)

	if ZCNPC.FlushVoice then ZCNPC.FlushVoice(ent, rag) end

	return newOrg
end

hook.Add("CreateEntityRagdoll", "zcnpc_corpse", function(ent, rag)
	if not (IsValid(ent) and ent:IsNPC()) then return end
	if ZCNPC.DropEngineRagdoll(ent, rag) then return end
	if IsValid(ent.zcnpc_rag) and rag ~= ent.zcnpc_rag then return end
	if IsValid(rag) then ZCNPC.Silence(rag) end

	ent.zcnpc_rag = rag
	rag.zcnpc_npc = ent
	if ZCNPC.FlushVoice then
		ZCNPC.FlushVoice(ent, rag)
		timer.Simple(0, function()
			if IsValid(ent) and IsValid(rag) then ZCNPC.FlushVoice(ent, rag) end
		end)
	end

	if not ZCNPC.Tracked[ent] then return end -- native classes are handled by Z-City's own hook
	if not ent.organism then return end

	ZCNPC.TransferOrganismToCorpse(ent, rag)
	ZCNPC.Tracked[ent] = nil
end)
--//

--\\ Fall damage + ragdoll on landing
-- Z-City's tracker only covers its own 3 classes; players also LightStun when
-- landing speed > 600 (fake/sv_input.lua:58). NPCs only took the damage half, so
-- they stuck the landing on their feet. Floor them the same way a shove does.
--
-- Walk every organism NPC (ours and native), not only ZCNPC.Tracked: natives
-- already get damage from Z-City's own fall loop, but never the ragdoll.
local vecforce = Vector(5000, 5000, -30000)
local math_random = math.random
local FALL_TICK = 0.2
local FALL_RAGDOLL = 6 -- metres of drop before they go limp (players ~600 u/s)
local FALL_DAMAGE = 10

timer.Create("zcnpc_falldamage", FALL_TICK, 0, function()
	if not ZCNPC.Enabled() or not cfg.falldamage:GetBool() then return end
	if not (istable(hg) and istable(hg.organism) and istable(hg.organism.list)) then return end

	for npc, org in pairs(hg.organism.list) do
		-- Players share this list; skip before IsNPC meta where possible.
		if not org or not org.fakePlayer then continue end
		if not (IsValid(npc) and npc:IsNPC()) then continue end
		if IsValid(npc.zcnpc_rag) then continue end
		if ZCNPC.IsZombie(npc) then continue end
		if org.alive == false then continue end

		local zPos = npc:GetPos().z
		if npc:IsOnGround() then
			if npc.zcnpc_falling then
				local fallVel = (npc.zcnpc_topZ - zPos) / 39.37
				if fallVel > 0 then
					local ours = ZCNPC.Tracked[npc]

					-- Damage: only for NPCs Z-City does not already cover (Tracked).
					-- Natives keep their own fall damage from sv_npcstuff.lua.
					if ours and fallVel >= FALL_DAMAGE then
						local world = IsValid(game.GetWorld()) and game.GetWorld() or npc

						local d = DamageInfo()
						d:SetDamage(fallVel * fallVel)
						d:SetDamageForce(vecforce)
						d:SetDamageType(DMG_FALL)
						d:SetAttacker(world)
						d:SetInflictor(world)

						npc:TakeDamageInfo(d)
						if fallVel >= 30 then
							npc:EmitSound("player/pl_pain" .. math_random(5, 7) .. ".wav", 75, math_random(95, 105))
						end
						npc:EmitSound(math_random(2) == 2 and "player/pl_fallpain1.wav" or "player/pl_fallpain3.wav", 75, math_random(95, 105))
					end

					-- Ragdoll on landing: everyone with an organism.
					if fallVel >= FALL_RAGDOLL and ZCNPC.Floor then
						local downFor = cfg.knockdown_time and cfg.knockdown_time:GetFloat() or 3
						if fallVel >= 15 then downFor = downFor * 1.5 end

						timer.Simple(0, function()
							if IsValid(npc) and not IsValid(npc.zcnpc_rag) then
								ZCNPC.Floor(npc, downFor)
							end
						end)
					end

					npc.zcnpc_falling = false
				end
			end
		else
			if not npc.zcnpc_falling then
				npc.zcnpc_falling = true
				npc.zcnpc_topZ = zPos
			elseif zPos > npc.zcnpc_topZ then
				npc.zcnpc_topZ = zPos
			end
		end
	end
end)
--//
