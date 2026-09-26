--[[
	Artagdoll (DMS active ragdolls) on Z-City bodies.

	Artagdoll finds its ragdolls in two places, and Z-City has taken both of them
	away:

	* NPCs, off the engine's "CreateEntityRagdoll" (init_active_ragdoll.lua:139).
	  A Z-City NPC never leaves an engine death ragdoll behind - with this addon it
	  never even dies the engine way, it lies down as a body of ours - so that hook
	  fires for nothing.
	* players, off Player:CreateRagdoll and "PostPlayerDeath"
	  (init_active_ragdoll.lua:64, 172). Z-City builds its own body in
	  hg.Ragdoll_Create and calls neither, so a dead player's ragdoll is never
	  handed over either.

	Hence "it doesn't work with Z-City": nothing is wrong with Artagdoll, it simply
	never gets to see a single body. Handing them over is most of the work here. The
	rest is deciding who is driving: an active ragdoll pushing a body back onto its
	feet and Z-City animating that same body out of the pose it is lying in cannot
	both be right, so control passes back and forth as the organism's state changes.

	There is nothing to configure. Either the addon is installed, in which case the
	bodies go to it, or it is not, in which case every line here is skipped and the
	rest of the mod carries on exactly as it does on a server that never had it. A
	switch for "installed but not used" would only ever have been a way to break
	half of this by accident.
]]

-- [ragdoll] = true, everything Z-City has finished with. Weak keys: a corpse that
-- fades out takes its entry with it.
ZCNPC.DeadBodies = ZCNPC.DeadBodies or setmetatable({}, { __mode = "k" })

-- Bodies we have handed an active ragdoll. The dead-watch below walks this set
-- instead of every ragdoll in the world - same answer, far less work once a fight
-- has left a dozen corpses on the floor.
ZCNPC.ActiveBodies = ZCNPC.ActiveBodies or setmetatable({}, { __mode = "k" })

--\\ Is it here?
local function Installed()
	return istable(ActiveRagdollManager) and isfunction(ActiveRagdollManager.Run)
		and istable(ActiveRagdoll) and isfunction(ActiveRagdoll.Get)
end

ZCNPC.HasArtagdoll = Installed

-- Artagdoll's own switches; there is no point fighting them. A convar that is
-- not there at all belongs to a version of the addon that never had it, which
-- is not a reason to stay quiet.
local function Switched(name)
	local cvar = GetConVar(name)

	return cvar == nil or cvar:GetBool()
end

--\\ Held off while we are running
-- Two of Artagdoll's switches do not mix with Z-City, and leaving them as menu
-- options only ever meant somebody turned one on by accident and got a second
-- corpse or a body on the far side of the map:
--
-- * ar_FatalHeadshot - the head-snap reaction that lightens bones, zeroes drag
--   and punches the head. Even capped, on a Z-City body (already shoved by the
--   organism's own hit force, often mid-handover) it is the path that sends an
--   NPC out of the world.
-- * ar_enabled_players - Artagdoll's Player:CreateRagdoll builds a second doll
--   next to Z-City's FakeRagdoll / RagdollDeath. No bridge is worth that; the
--   switch is simply held off, so it cannot be turned on while we are loaded.
--
-- Forced every second and on every change, deferred a frame so we win over a
-- menu click that lands in the same tick as Artagdoll's own callback.
--
-- Holding the cvar off is not enough on its own. Older Artagdoll installs
-- CreateRagdoll at file load regardless of ar_enabled_players, and only takes
-- it back off from the change callback - so if the cvar is already false when
-- that file runs (because we held it off a moment earlier), the override stays
-- and every player death still leaves two corpses. The function itself is
-- stripped every tick as well.
local HELD_OFF = { "ar_FatalHeadshot", "ar_enabled_players" }

local function HoldOff(name)
	local cvar = GetConVar(name)
	if not cvar or not cvar:GetBool() then return end

	cvar:SetBool(false)
	ZCNPC.Debug("held off", name)
end

-- Z-City's CreateRagdoll is a no-op (fake/sv_tier_0.lua:8): death bodies are
-- FakeRagdoll / RagdollDeath. Artagdoll's builds a fresh prop_ragdoll and
-- spectates it. While we are loaded that path must not exist.
--
-- GetRagdollEntity must not hand Artagdoll the Z-City corpse either. The old
-- strip pointed Fedhoria at RagdollDeath on purpose "so there is only one body",
-- and that is exactly how a dead player ended up with injured's procedural pulse
-- forever: Fedhoria found the real corpse, ActiveRagdoll.new ran before the
-- organism was on it (IsCorpse was false with no org), and PoliceTheDead only
-- walks bodies we already know about - which player corpses never were.
local function SrcOf(fn)
	if not isfunction(fn) then return "" end

	local info = debug.getinfo(fn, "S")

	return info and (info.short_src or "") or ""
end

local function IsOursOrZCity(src)
	if string.find(src, "zcnpc", 1, true) then return true end
	if string.find(src, "sv_tier_0", 1, true) then return true end
	if string.find(src, "fake/", 1, true) then return true end

	return false
end

local function StripPlayerRagdoll()
	local PLAYER = FindMetaTable("Player")
	if not PLAYER then return false end

	-- Z-City's CreateRagdoll is already a no-op. Anything else — Artagdoll,
	-- a late workshop copy, a file that is not named init_active_ragdoll —
	-- builds a second corpse next to RagdollDeath. Keep putting ours back;
	-- they can overwrite us after we load.
	local createSrc = SrcOf(PLAYER.CreateRagdoll)
	if not IsOursOrZCity(createSrc) then
		PLAYER.CreateRagdoll = function() return false end
		ZCNPC.Debug("stripped player CreateRagdoll from", createSrc)
	end

	local getSrc = SrcOf(PLAYER.GetRagdollEntity)
	-- Put Z-City's answer back: RagdollDeath / FakeRagdoll. ArtAgdoll's version
	-- only knew about the spectate-doll it built. Fedhoria is stripped below so
	-- restoring the real corpse here does not hand it an active ragdoll again.
	if not IsOursOrZCity(getSrc) then
		PLAYER.GetRagdollEntity = function(self)
			local dead = self:GetNWEntity("RagdollDeath")
			if IsValid(dead) then return dead end

			local fake = self.FakeRagdoll

			return IsValid(fake) and fake or NULL
		end
	end

	return true
end

-- Artagdoll's PostPlayerDeath "Fedhoria" starts an active ragdoll on whatever
-- GetRagdollEntity returns, 0.05s later (init_active_ragdoll.lua:172). Holding
-- ar_enabled_players off should stop it; removing the hook is the half that
-- still works when a workshop copy ignores the cvar or wins a race with HoldOff.
local function StripFedhoria()
	hook.Remove("PostPlayerDeath", "Fedhoria")
end

local function HoldOffCvars()
	if not ZCNPC.Enabled() then return end

	for i = 1, #HELD_OFF do
		HoldOff(HELD_OFF[i])
	end

	-- Artagdoll can load after us and put CreateRagdoll back. Every second
	-- is cheap next to a second corpse on every death.
	StripPlayerRagdoll()
end

local function HoldOffAll()
	if not ZCNPC.Enabled() then return end

	HoldOffCvars()
	StripFedhoria()
end

local function InstallHoldOff()
	HoldOffAll()

	for i = 1, #HELD_OFF do
		local name = HELD_OFF[i]
		local id = "zcnpc_holdoff_" .. name

		pcall(cvars.RemoveChangeCallback, name, id)
		cvars.AddChangeCallback(name, function(_, _, new)
			if not ZCNPC.Enabled() then return end
			if new == "0" or new == "false" then return end

			timer.Simple(0, function() HoldOff(name) end)
		end, id)
	end
end

pcall(cvars.RemoveChangeCallback, "ar_FatalHeadshot", "zcnpc_nofatal")
pcall(cvars.RemoveChangeCallback, "zcnpc_enabled", "zcnpc_nofatal_enabled")
hook.Remove("InitPostEntity", "zcnpc_nofatal")
if timer.Exists("zcnpc_nofatal") then timer.Remove("zcnpc_nofatal") end

InstallHoldOff()
hook.Add("InitPostEntity", "zcnpc_holdoff", InstallHoldOff)
-- Cvars and CreateRagdoll every second (workshop copies flip them back).
-- Fedhoria hook remove stays on its own slower timer.
timer.Create("zcnpc_holdoff", 1, 0, HoldOffCvars)
timer.Create("zcnpc_holdoff_fedhoria", 5, 0, function()
	if ZCNPC.Enabled() then StripFedhoria() end
end)
cvars.AddChangeCallback("zcnpc_enabled", function()
	timer.Simple(0, InstallHoldOff)
end, "zcnpc_holdoff_enabled")

function ZCNPC.ArtagdollReady()
	-- The organism owns Z-City bodies; Artagdoll remains available for ordinary NPC ragdolls.
	return false
end

-- Our bodies are NPC bodies. Player support is held off above on purpose.
local function BodyReady()
	return ZCNPC.ArtagdollReady() and Switched("ar_enabled_npcs")
end

-- How long a body is given to finish dying before the active ragdoll comes off
-- and it is just a body. Four seconds is the longest of Artagdoll's own four head
-- shot reactions (ar_hs_death_delay, the decerebrate one), so all of them get to
-- play out. Artagdoll's own answer to the same question is however long two
-- hundred hit points take to bleed away, which is minutes of a corpse fighting to
-- stand up, and that is not a length anybody was ever going to want.
local DEATH_TIME = 4
--//

--\\ Undoing what the stiffener does
-- One of Artagdoll's four head shot reactions braces the body with ballsockets
-- (behaviors/headshot.lua:72), and on its way past it lightens every physics object
-- on the ragdoll and takes the damping off them (physics/stiff.lua). That is most of
-- "sometimes they behave fine and sometimes they fly away": the reaction is one of
-- four picked at random, so three head shots in four are ordinary, and the fourth
-- used to leave the body light with no damping permanently, so the next push it took
-- - a round, the floor, Artagdoll's own head shot punch - moved it much too far and
-- nothing slowed it down again.
--
-- Artagdoll's own copy of that is fixed, and its stiffener now restores what it
-- changes. This stays as the guarantee, because the fix is in a file that belongs to
-- another addon and a workshop update would take it back out: the values are recorded
-- before the reaction and put back after it either way, and a body whose mass and
-- damping are already right is restored to what they already are.
local function Snapshot(rag)
	if rag.zcnpc_physsnap then return end

	local snap = {}

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		local lin, ang = phys:GetDamping()
		snap[i] = { mass = phys:GetMass(), lin = lin, ang = ang }
	end

	rag.zcnpc_physsnap = snap
end

function ZCNPC.RestorePhysics(rag)
	if not IsValid(rag) then return end

	local snap = rag.zcnpc_physsnap
	if not snap then return end

	for i, saved in pairs(snap) do
		local phys = rag:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		-- A part that has been shot off is a separate question and Z-City has
		-- already answered it (ZCNPC.SaneGibMass): putting a whole head's weight
		-- back onto a stump is not a restoration.
		if phys:GetMass() < saved.mass then phys:SetMass(saved.mass) end

		phys:SetDamping(saved.lin, saved.ang)
	end
end

-- Wrapping the stiffener rather than chasing the one behaviour that uses it: the
-- pair is meant to be symmetrical and only Remove is missing its half.
local function InstallStiffenerGuard()
	if not (istable(RagdollStiffener) and isfunction(RagdollStiffener.Apply)) then return end
	if ZCNPC.__stiffApply then return end

	ZCNPC.__stiffApply = RagdollStiffener.Apply
	ZCNPC.__stiffRemove = RagdollStiffener.Remove

	function RagdollStiffener.Apply(ent, amount)
		if IsValid(ent) then Snapshot(ent) end

		return ZCNPC.__stiffApply(ent, amount)
	end

	function RagdollStiffener.Remove(ent)
		local ret = ZCNPC.__stiffRemove(ent)

		ZCNPC.RestorePhysics(ent)

		return ret
	end
end

InstallStiffenerGuard()
hook.Add("InitPostEntity", "zcnpc_artagdoll_stiff", InstallStiffenerGuard)

-- Everything a body should have back before anybody else looks at it: its weight,
-- its damping, and no splints. Called wherever we stop driving one.
function ZCNPC.TamePhysics(rag)
	if not IsValid(rag) then return end

	if istable(RagdollStiffener) and isfunction(RagdollStiffener.Remove) then
		RagdollStiffener.Remove(rag) -- restores through the wrapper above
	else
		ZCNPC.RestorePhysics(rag)
	end
end
--//

--\\ One health bar, not two
-- Artagdoll gives every ragdoll it animates two hundred hit points (activeragdoll.lua:69)
-- and bleeds them away on a timer of its own (classes/health.lua:84). Z-City decides
-- the same question - is there anybody left in this body - out of blood, pulse and
-- organ damage, and two systems racing to kill the same body is one too many.
--
-- This used to be settled by marking Artagdoll's entry dead on arrival, which its
-- damage path and its bleed loop both skip (classes/health.lua:64, 100). It worked,
-- and it cost more than it looked like: a dead entry is also skipped by the injured
-- behaviour, which reads the same record to decide how hard a body still fights
-- (behaviors/injured.lua:28), so every living body Artagdoll got from us went limp
-- - and shooting one did nothing, because that damage path was switched off too.
--
-- So the entry is kept alive and told what to say instead. zcnpc_body_hp is the one
-- number; this writes it in and holds off the bleed loop that would otherwise walk
-- it down on its own schedule.
local function HealthEntry(rag)
	if not (istable(DMS_Health) and istable(DMS_Health.Active)) then return end

	return DMS_Health.Active[rag]
end

local function MuteHealth(rag)
	if not (istable(DMS_Health) and isfunction(DMS_Health.new)) then return end

	local data = DMS_Health.new(rag, 100)
	if not data then return end

	data.dead = false
	data.zcnpc_shared = true

	ZCNPC.PushHealth(rag, data)
end

-- Called every monitor tick while a body is down, and once when it is handed over.
-- Strictly one way: the damage a body takes is counted once, by ZCNPC.BodyDamage
-- off Z-City's own damage handling, and Artagdoll is told the answer. Reading its
-- number back as well would count every round twice, and its own handler only sees
-- a body while the active ragdoll is running - an unconscious one, the case this is
-- most needed for, it never sees at all.
function ZCNPC.PushHealth(rag, data)
	data = data or HealthEntry(rag)
	if not (data and data.zcnpc_shared) then return end

	local hp, max = ZCNPC.BodyHP(rag)
	if not hp then return end

	hp = math.max(hp, 0)

	-- deliberately left alive, however low the number gets. A record marked dead is
	-- skipped by the behaviour that reads it, which freezes the body at whatever
	-- strength it was holding rather than letting go of it; and Artagdoll's own idea
	-- of dying is to destroy the active ragdoll on the spot, which is the collapse
	-- skipped entirely. Death goes through ZCNPC.ActiveDie below, off Z-City's
	-- verdict and nothing else.
	data.dead = false

	-- the bleed loop is Z-City's job on these bodies, and it is doing it properly:
	-- blood volume, arteries, clotting. Pushing the tick out past the next one of
	-- ours keeps the second, blunter version from ever running.
	data.nextBleedTick = CurTime() + 1

	if data.currentHP == hp and data.maxHP == max then return end

	data.maxHP = max
	data.currentHP = hp
end

-- dmgpos: where the hit that put this body down landed, which is what the stumble
-- behaviour leans away from (behaviors/stumble.lua reads ar.dmgpos)
function ZCNPC.ActiveOn(rag, dmgpos, ownDeath)
	if not (IsValid(rag) and ZCNPC.ArtagdollReady()) then return false end
	if rag.zcnpc_gettingup then return false end
	if ActiveRagdoll.Get(rag) then
		ZCNPC.ActiveBodies[rag] = true

		return true
	end
	if rag:GetPhysicsObjectCount() < 2 then return false end
	if not rag:LookupBone("ValveBiped.Bip01_Pelvis") then return false end

	-- before anything of Artagdoll's has touched the body, so what is recorded is
	-- the weight and damping the model shipped with
	Snapshot(rag)

	-- A body that is dying is the one case Artagdoll should run its own course on:
	-- the death flail and the limp that follows are its whole point.
	if not ownDeath then MuteHealth(rag) end

	ActiveRagdollManager.Run(rag, dmgpos)
	ZCNPC.ActiveBodies[rag] = true
	if ZCNPC.WatchBody then ZCNPC.WatchBody(rag) end

	ZCNPC.Debug("active ragdoll on", rag)

	return true
end

function ZCNPC.ActiveOff(rag)
	if not IsValid(rag) then return end

	-- Cut the moan loop even when ArtAgdoll itself is not installed / already gone.
	if ZCNPC.StopBodySound then ZCNPC.StopBodySound(rag) end

	if not Installed() then return end

	ZCNPC.ActiveBodies[rag] = nil

	local ar = ActiveRagdoll.Get(rag)
	if not (ar and ar.Destroy) then return end

	ar.zcnpc_drive_pin = nil
	ar:Destroy()

	-- whatever it was holding the body together with goes with it
	ZCNPC.TamePhysics(rag)

	ZCNPC.Debug("active ragdoll off", rag)
end

function ZCNPC.IsActive(rag)
	return IsValid(rag) and Installed() and ActiveRagdoll.Get(rag) ~= nil
end
--//

--\\ Nothing starts an active ragdoll on a corpse
-- Everywhere else in this file is a place that stops one, and stopping is a thing
-- that has to happen at a moment - which is exactly what a body can be missing. The
-- gap is small and real: ActiveRagdollManager defers the whole of its work by a
-- twentieth of a second (activeragdollmanager.lua:43), so a hand-over that was
-- correct when it was asked for lands on a body that has died since, and lands after
-- everything that would have called it off has already run. The watchdog below
-- catches it, but not before a corpse has spent up to a second sitting itself back
-- up.
--
-- So the question is asked at the other end instead, where there is no gap to leave:
-- ActiveRagdoll.new is the one door into an active ragdoll, and a corpse is turned
-- away at it. Every route in is covered by that - ours, Artagdoll's own engine death
-- hook firing a frame late, another addon's, a second hand-over from a path nobody
-- thought of - and none of them has to be found first.
--
-- The exception is the collapse, which is the one active ragdoll a corpse is meant
-- to have: a body dying with somebody still in it goes over rather than switching
-- off, and that is what zcnpc_throes is the length of.
function ZCNPC.IsCorpse(rag)
	if not IsValid(rag) then return false end
	if (rag.zcnpc_throes or 0) > CurTime() then return false end -- mid-collapse, and meant to be

	if rag.zcnpc_dead then return true end
	if rag.zcnpc_playercorpse then return true end -- Z-City player RagdollDeath: never animate
	if rag.zcnpc_headkill then return true end -- lethal head shot: never hand over a living AR
	if rag.headexploded or rag.noHead then return true end -- a body with no head is finished
	if (rag.zcnpc_hp or 1) <= 0 then return true end

	-- A dead player's body, even before the organism lands on it. Without this,
	-- ActiveRagdoll.new wins the race against PostPlayerDeath and injured starts
	-- pulsing a corpse that IsCorpse could not yet see.
	local ply = rag.ply
	if IsValid(ply) and ply:IsPlayer() and not ply:Alive() then return true end

	local org = rag.organism

	return org ~= nil and org.alive == false
end

local function InstallCorpseGuard()
	if not (istable(ActiveRagdoll) and isfunction(ActiveRagdoll.new)) then return end
	if ZCNPC.__arNew then return end

	ZCNPC.__arNew = ActiveRagdoll.new

	function ActiveRagdoll.new(ragdoll, animModel, dmgpos)
		if IsValid(ragdoll) and ragdoll.organism then return nil end
		if ZCNPC.Enabled() and ZCNPC.IsCorpse(ragdoll) then
			ZCNPC.Debug("refused an active ragdoll on a corpse:", ragdoll)

			return nil
		end

		return ZCNPC.__arNew(ragdoll, animModel, dmgpos)
	end
end

InstallCorpseGuard()
hook.Add("InitPostEntity", "zcnpc_artagdoll_guard", InstallCorpseGuard)
--//

--\\ Dying
-- A body Z-City has finished with is finished, and Artagdoll had no way of hearing
-- it. Left to itself it treats every ragdoll it picks up as somebody with two
-- hundred hit points to lose and takes them away at somewhere between a tenth and
-- five a second (classes/health.lua:107) - so a corpse spent the next several
-- minutes as a man still fighting to get up, out of a body Z-City had already
-- declared dead, bled dry and turned into loot. And nothing could be done about it
-- from the outside: the one thing that would have ended it early is Artagdoll's own
-- damage path, and that never sees a round fired at a Z-City body, because Z-City
-- answers EntityTakeDamage first and keeps the hit.
--
-- So both halves of it are said here instead. This is the end - the breathing loop
-- stops, the face relaxes, the hands let go and the active ragdoll comes off, which
-- is the whole difference between a corpse and a corpse that is still trying to
-- stand up.
function ZCNPC.ActiveDie(rag)
	if not IsValid(rag) then return end

	rag.zcnpc_throes = nil
	rag.zcnpc_dead = true
	ZCNPC.DeadBodies[rag] = true -- what the watchdog below reads
	ZCNPC.ActiveBodies[rag] = nil
	rag.DMS_IsHeadshot = false

	if not Installed() then return end
	if not ActiveRagdoll.Get(rag) then return ZCNPC.ActiveOff(rag) end

	local data = HealthEntry(rag)
	if data then
		data.currentHP = 0
		data.zcnpc_shared = nil -- nothing left to push into it
	end

	if istable(DMS_Health) and isfunction(DMS_Health.Die) then DMS_Health:Die(rag) end

	-- DMS_Health.Die destroys the active ragdoll itself, but only where there was a
	-- record for it to find
	ZCNPC.ActiveOff(rag)

	-- The state machine is locked shut as well as switched off. Artagdoll reads this
	-- flag before it decides anything (dms_physics.lua:85), so a body that somehow
	-- gets handed a second active ragdoll - another addon, a stray hand-over, the
	-- engine's own death ragdoll hook firing late - is still a corpse when it does.
	local ar = ActiveRagdoll.Get(rag)
	if ar then ar.DMS_HeadshotLocked = true end

	-- The splints are the other half, and Artagdoll takes them off itself now
	-- (behaviors/headshot.lua). It can only do that from inside its own reaction
	-- though, and a body reaching this line has just been declared dead by something
	-- that is not Artagdoll - so this is here for the body that died mid-reaction and
	-- never got to the end of it.
	ZCNPC.TamePhysics(rag)

	-- Injured leaves spin on the spine. Zero it or the torso keeps nodding
	-- after the controller is gone.
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			phys:SetVelocity(vector_origin)
			phys:SetAngleVelocity(vector_origin)
		end
	end

	if ZCNPC.EeerStopMotion then ZCNPC.EeerStopMotion(rag) end

	ZCNPC.Debug("body stopped", rag)
end

-- Belt and braces. The guard above is the half that stops an active ragdoll being
-- started on a corpse; this is the half that catches a body that died with one
-- already running and told nobody. There is no shortage of ways for that to happen -
-- Z-City can write org.alive itself from any of a dozen places, another addon can
-- kill a body outright, a head can come off something that was never ours to lay
-- down - and the symptom is always the same one: no pulse, and the body still
-- fighting to stand up.
--
-- So the causes are not enumerated. Asked once a second of every body we know is
-- being animated, and every body already marked dead - not of every ragdoll on the
-- map, which was the old walk and cost a Get lookup per corpse long after the fight.
local function Police(rag, seen)
	if seen[rag] or not IsValid(rag) then return end
	seen[rag] = true

	if not ZCNPC.IsCorpse(rag) then return end
	if not ActiveRagdoll.Get(rag) then
		ZCNPC.ActiveBodies[rag] = nil

		return
	end

	ZCNPC.Debug("corpse was still moving", rag)
	ZCNPC.ActiveDie(rag)
end

function ZCNPC.PoliceTheDead()
	if not Installed() then return end

	local seen = {}

	for rag in pairs(ZCNPC.DeadBodies) do
		if not IsValid(rag) then
			ZCNPC.DeadBodies[rag] = nil
		else
			Police(rag, seen)
		end
	end

	for rag in pairs(ZCNPC.ActiveBodies) do
		if not IsValid(rag) then
			ZCNPC.ActiveBodies[rag] = nil
		else
			Police(rag, seen)
		end
	end
end

timer.Create("zcnpc_deadwatch", 1, 0, ZCNPC.PoliceTheDead)

-- The injured behaviour plays one of six dying animations and reads the health left
-- to decide how hard the body drives itself through them (behaviors/injured.lua:47).
-- Under a fifth it stops steering that at all and shakes instead (:58), which is the
-- collapse - so a corpse is given a twentieth, well clear of the line.
--
-- It has to be written before ActiveRagdoll.new runs, which asks for a record of its
-- own and two hundred hit points with it (activeragdoll.lua:69): DMS_Health.new hands
-- back whatever is already there rather than replacing it (classes/health.lua:28), so
-- whichever of the two gets there first is the one that counts.
-- Low on purpose. Injured's OnStart sets strength to 5 and only later scales off
-- health percent - at a twentieth of the bar that is the twitch branch, but the
-- opening frame is still a full-strength dying animation into a body that often
-- already carries the kill shove. That is most of "they fly when they die".
local DYING_HP = 5
local DYING_STRENGTH = 1.15
-- How fast a corpse may still be moving when the collapse starts. Above this the
-- stumble it just had, or the head shot shove, is bled off before injured takes over.
local DEATH_MAX_SPEED = 120
local DEATH_MAX_SPIN = 180

local function DyingHealth(rag)
	if not (istable(DMS_Health) and isfunction(DMS_Health.new)) then return end

	-- the shared record belonged to the living body; this one is the corpse's
	if istable(DMS_Health.Active) then DMS_Health.Active[rag] = nil end

	local data = DMS_Health.new(rag, 100)
	if not data then return end

	data.dead = false
	data.currentHP = DYING_HP

	-- Artagdoll's own bleed loop is what used to decide how long a body took to die
	-- and it is the wrong tool twice over: it is a second opinion on a question
	-- Z-City has already answered, and it answers it in minutes.
	data.isBleeding = false
	data.nextBleedTick = math.huge

	return data
end

-- A body that has settled is asleep, and Artagdoll's state machine steps over
-- sleeping physics entirely (dms_physics.lua:51) - so a body that died lying still
-- would never be handed its own collapse.
local function Wake(rag)
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then phys:Wake() end
	end
end

-- Kill shoves and a brief living stumble both land before the collapse. Cap what
-- they left so the dying animation is thrashing a body that is already mostly still,
-- not one mid-flight.
local function SettleForDeath(rag)
	local maxSqr = DEATH_MAX_SPEED * DEATH_MAX_SPEED
	local spinSqr = DEATH_MAX_SPIN * DEATH_MAX_SPIN

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		local vel = phys:GetVelocity()
		local speedSqr = vel:LengthSqr()
		if speedSqr > maxSqr then
			phys:SetVelocity(vel * (DEATH_MAX_SPEED / math.sqrt(speedSqr)))
		end

		local spin = phys:GetAngleVelocity()
		local turnSqr = spin:LengthSqr()
		if turnSqr > spinSqr then
			phys:AddAngleVelocity(spin * (DEATH_MAX_SPIN / math.sqrt(turnSqr) - 1))
		end
	end
end

local LIVING_LAYERS = { "woundgrab", "holdenv", "wallstunt" }

local function Collapse(rag)
	if not (IsValid(rag) and Installed() and istable(DMS)) then return end

	local ar = ActiveRagdoll.Get(rag)
	if not ar then return end

	-- Fatal Headshot is held off while we are running, so the flag is never a reason
	-- to skip the ordinary collapse. Cleared anyway in case another addon set it.
	rag.DMS_IsHeadshot = false

	-- Everything else is handed "stumble" by DMS:Setup, which is the behaviour that
	-- puts feet back under a body and pushes it upright. "Injured" is the one that
	-- plays a death out instead: one of six dying animations, and at the health a
	-- dying body is given, shaking its way through it.
	if isfunction(DMS.Switch) then DMS:Switch(ar, "injured") end

	-- Injured.OnStart sets strength to 5 before OnUpdate ever sees the dying HP.
	-- Hold it down for the whole collapse; the twitch branch only softens relative
	-- to whatever strength is already there, so leaving 5 means a launch.
	if ar.SetStrength then ar:SetStrength(DYING_STRENGTH) end

	-- Layers are the things a body does as well as whatever it is doing: bracing
	-- against a wall it is sliding down, holding on to the ledge it went over, one
	-- hand pressed to the wound. All of them are somebody keeping themselves alive
	-- and none of them belongs on a corpse - and the wound grab has a second reason
	-- to go, which is that it welds a hand to the bone nearest a position fixed when
	-- the active ragdoll was built, and on a body Artagdoll found by itself that
	-- position came off its own damage tracking.
	if istable(ar.ActiveLayers) and isfunction(DMS.RemoveLayer) then
		for _, layer in ipairs(LIVING_LAYERS) do
			if ar.ActiveLayers[layer] then DMS:RemoveLayer(ar, layer) end
		end
	end

	-- and no new one, which is a flag of Artagdoll's own: one grab per body, asked
	-- for by the same three behaviours a corpse is about to be in (:204).
	ar.WoundGrabPlayed = true

	-- Nothing decides anything after this. The lock is Artagdoll's own way of saying
	-- the state machine has nothing left to say (:85); without it the body goes back
	-- to picking behaviours off its posture and its speed every half second, and
	-- "face down, not moving" is not the same question as "alive".
	ar.DMS_HeadshotLocked = true

	-- Last, because the switch above has a voice of its own and it is the wrong one:
	-- every behaviour that means "hurt" is mapped to the same looped reaction
	-- (dms_core.lua:19), so a body told to lie down and die would have groaned its way
	-- through the whole collapse, and gone on groaning after it. A reaction played over
	-- another stops it (utils/soundmanager.lua:91), and this one is not looped, so the
	-- rattle is the last thing the body does. Artagdoll plays it itself for a head shot
	-- (dms_physics.lua:74), which is the branch above, and for nothing else - so a body
	-- that bled out on the floor used to die in silence.
	ZCNPC.BodySound(rag, "Death")
end

-- Weight and damping go back on early so the collapse is a body coming to rest.
-- Waiting out a second and a half left the light, undamped bones under the dying
-- animation for most of the throe - which is how a corpse still sailed.
local TAME_DELAY = 0.35

-- handOver: whether the active ragdoll still has to be started. Bodies Artagdoll
-- found by itself, off the engine's own death ragdoll, are already running.
function ZCNPC.DeathThroes(rag, handOver)
	if not IsValid(rag) then return end

	rag.zcnpc_dead = true
	ZCNPC.DeadBodies[rag] = true
	-- Fatal Headshot is held off; strip any flag Artagdoll's ScaleNPCDamage left
	rag.DMS_IsHeadshot = false
	if ZCNPC.WatchBody then ZCNPC.WatchBody(rag, DEATH_TIME + 1) end

	local seconds = DEATH_TIME

	-- a body with nothing on its shoulders has nothing left to do with the time
	if rag.headexploded or rag.noHead then seconds = 0 end

	if seconds <= 0 or not BodyReady() then return ZCNPC.ActiveDie(rag) end

	-- Written before the hand-over rather than after it, because the corpse guard
	-- reads it: this body is already marked dead, and the collapse is the one active
	-- ragdoll a dead body is allowed. Cleared again by ActiveDie on either of the
	-- ways out below.
	rag.zcnpc_throes = CurTime() + seconds

	if handOver and not ZCNPC.ActiveOn(rag, rag.zcnpc_dmgpos, true) then return ZCNPC.ActiveDie(rag) end

	-- after the line above and still in time: what that starts is a timer, and the
	-- record has only to be there by the time it fires
	DyingHealth(rag)
	SettleForDeath(rag)
	Wake(rag)

	if handOver then
		-- nothing to hand a collapse to yet: ActiveRagdollManager defers the active
		-- ragdoll by a twentieth of a second (activeragdollmanager.lua:43) and
		-- DMS:Setup defers the first behaviour by a frame on top of that
		timer.Simple(0.1, function()
			if not IsValid(rag) then return end

			SettleForDeath(rag)
			Collapse(rag)
		end)
	else
		Collapse(rag)
	end

	-- Hold the dying animation's strength down every tick of the collapse: injured
	-- OnUpdate keeps writing its own numbers, and under 20% HP those are "current
	-- strength plus a twitch" - so without this the SetStrength above only lasts
	-- until the first physics tick. Speed is only bled off for the first second -
	-- after that the body should be free to settle under gravity.
	local holdUntil = CurTime() + seconds
	local settleUntil = CurTime() + 1
	local holdId = "zcnpc_dyingstr_" .. rag:EntIndex()
	timer.Create(holdId, 0.05, 0, function()
		if not IsValid(rag) or CurTime() > holdUntil or rag.zcnpc_throes == nil then
			timer.Remove(holdId)

			return
		end

		local ar = ActiveRagdoll.Get(rag)
		if ar and ar.SetStrength then ar:SetStrength(DYING_STRENGTH) end
		if CurTime() <= settleUntil then SettleForDeath(rag) end
	end)

	-- the weight and the damping go back on while the collapse is still running, so
	-- the last half of it is a body coming to rest instead of one still accelerating
	timer.Simple(math.min(TAME_DELAY, seconds), function() ZCNPC.RestorePhysics(rag) end)

	timer.Simple(seconds, function()
		if not IsValid(rag) then return end

		local till = rag.zcnpc_throes
		if not till or till > CurTime() + 0.05 then return end -- already stopped, or pushed back

		ZCNPC.ActiveDie(rag)
	end)
end

-- Finishing one off. A corpse still moving is a corpse that has not finished dying,
-- and a round into it is the plainest way anyone has ever said stop. Waiting out the
-- collapse is the alternative, and waiting is exactly what "I cannot kill it" is.
--
-- Deliberate hits only, and DMG_CRUSH is what tells them apart: the impact of a
-- ragdoll against the world arrives here as well (sv_input.lua:1499, crush at :1411),
-- and a body collapsing hits the floor within half a second of starting - so a
-- collapse would have ended itself every single time.
local FINISH = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER + DMG_BLAST + DMG_SLASH + DMG_CLUB

hook.Add("HomigradDamage", "zcnpc_artagdoll_finish", function(victim, dmgInfo, _, ent)
	if not ZCNPC.Enabled() then return end

	-- the first argument is the player behind a body rather than the body itself
	-- whenever there is one (sv_input.lua:888); the fourth is always what was hit
	local rag = IsValid(ent) and ent or victim

	if not (IsValid(rag) and rag.zcnpc_corpse and ZCNPC.IsActive(rag)) then return end
	if not dmgInfo:IsDamageType(FINISH) then return end

	ZCNPC.ActiveDie(rag)
end)
--//

--\\ Who is driving
-- Living bodies keep an active ragdoll for the whole time they are on the floor.
-- Consciousness (and otrub / heartstop) only scales how hard that ragdoll fights;
-- destroying and recreating it on every KO was what left a body awake but unable
-- to stand with no writhing left - ActiveOff tore the controller down, and the
-- next ActiveOn often never came back while CanWakeUp was still false.
--
-- org.fake used to be on the off-list, and it is why an active ragdoll only ever
-- turned up on NPCs that were killed outright. "fake" means the organism wants
-- this body on the floor rather than on its feet (sv_organism.lua:526), which is
-- the whole reason the NPC went down in the first place. Lying there is exactly
-- the state Artagdoll is for. The active ragdoll comes off for get-up, death,
-- a lethal head shot, and a broken spine (full paralysis - no tumble / writhe).
local function SpineBroken(org)
	if not (istable(hg) and istable(hg.organism)) then return false end

	local s1 = hg.organism.fake_spine1 or 1
	local s2 = hg.organism.fake_spine2 or 1
	local s3 = hg.organism.fake_spine3 or 0.5

	return (org.spine1 or 0) >= s1
		or (org.spine2 or 0) >= s2
		or (org.spine3 or 0) >= s3
end

-- Legs gone / ruined: still writhe on the floor, just never stumble upright.
-- A broken spine is different - that is full paralysis, AR off (see WantsActive).
local function LegsRuined(org)
	if org.llegamputated or org.rlegamputated then return true end

	return (org.lleg or 0) >= 1 and (org.rleg or 0) >= 1
end

local function OutCold(org)
	return org.otrub == true
		or org.heartstop == true
		or (org.consciousness or 1) <= 0.4
end

function ZCNPC.IsOutCold(org)
	return istable(org) and OutCold(org)
end

-- 0 = limp, 1 = full ArtAgdoll strength. Consciousness, otrub, heartstop, and
-- the body's own HP (zcnpc_body_hp) — Unconsciousness and bleed-out already
-- write those, this only reads them. Do not tear the controller down for KO.
function ZCNPC.ActiveStrengthScale(rag)
	local org = rag and rag.organism
	if not org then return 1 end
	if org.heartstop or org.otrub then return 0 end

	local c = math.Clamp(org.consciousness or 1, 0, 1)
	local scale
	if c <= 0.4 then
		scale = 0.05 * (c / 0.4)
	else
		scale = 0.2 + 0.8 * ((c - 0.4) / 0.6)
	end

	if isfunction(ZCNPC.BodyHP) then
		local hp, max = ZCNPC.BodyHP(rag)
		if hp and max and max > 0 then
			scale = scale * math.Clamp(hp / max, 0, 1)
		end
	end

	return scale
end

function ZCNPC.ShouldScaleActiveStrength(rag)
	if not IsValid(rag) then return false end
	if rag.zcnpc_dead or rag.zcnpc_corpse then return false end
	if (rag.zcnpc_throes or 0) > CurTime() then return false end
	if not rag.organism then return false end
	if not (ZCNPC.ActiveBodies[rag] or (ZCNPC.Downed and ZCNPC.Downed[rag])) then return false end

	return true
end

-- Scale every SetStrength ArtAgdoll makes on our living bodies. Injured rewrites
-- strength every tick off its own health bar; without this that would ignore
-- consciousness entirely, and a KO would still thrash at full injured power.
local function InstallStrengthGate()
	if not (istable(ActiveRagdoll) and isfunction(ActiveRagdoll.SetStrength)) then return end
	if ZCNPC.__arSetStrength then return end

	ZCNPC.__arSetStrength = ActiveRagdoll.SetStrength

	function ActiveRagdoll:SetStrength(val)
		val = tonumber(val) or 0
		self.zcnpc_want_strength = val

		local rag = self.ragdoll
		if IsValid(rag) and ZCNPC.ShouldScaleActiveStrength(rag) then
			val = val * ZCNPC.ActiveStrengthScale(rag)
		end

		-- Injured rewrites strength every DMS tick; skip the controller call when
		-- the scaled value has not actually moved.
		local prev = self.zcnpc_applied_strength
		if prev and math.abs(prev - val) < 0.02 then
			self.Strength = val

			return
		end

		self.Strength = val
		self.zcnpc_applied_strength = val

		return ZCNPC.__arSetStrength(self, val)
	end
end

InstallStrengthGate()
hook.Add("InitPostEntity", "zcnpc_artagdoll_strength", InstallStrengthGate)

-- Pin a body off stumble / crawl / tumble. Stumble applies upright forces that
-- do not go through SetStrength, so a KO would still climb onto its feet if
-- left on that behaviour. Injured is the floor path; how hard it fights is
-- ActiveStrengthScale (consciousness / otrub / body HP), not a second on/off.
local function PinFloor(ar)
	if not ar then return end

	ar.zcnpc_drive_pin = true

	local beh = ar.CurrentBehavior
	if beh == "stumble" or beh == "crawling" or beh == "tumble" or beh == "none" then
		if istable(DMS) and isfunction(DMS.Switch) then DMS:Switch(ar, "injured") end
	end

	if istable(ar.ActiveLayers) and ar.ActiveLayers.wallstunt
		and istable(DMS) and isfunction(DMS.RemoveLayer) then
		DMS:RemoveLayer(ar, "wallstunt")
	end

	-- Switch("injured") starts a voice clip. A KO body has nothing to say.
	local rag = ar.ragdoll
	if IsValid(rag) and ZCNPC.IsOutCold(rag.organism) and ZCNPC.StopBodySound then
		ZCNPC.StopBodySound(rag)
	end
end

local function UnpinFloor(ar)
	if not ar or not ar.zcnpc_drive_pin then return end

	ar.zcnpc_drive_pin = nil
end

-- Setup always Switch("stumble") next tick. A KO body must not take that
-- upright start; injured + strength 0 is the same limp the scale already is.
if ZCNPC.__dmsSwitch and istable(DMS) then
	DMS.Switch = ZCNPC.__dmsSwitch
	ZCNPC.__dmsSwitch = nil
end

hook.Remove("InitPostEntity", "zcnpc_artagdoll_limpswitch")

local function InstallKoStumble()
	if not (istable(DMS) and isfunction(DMS.Switch)) then return end
	if ZCNPC.__dmsKoSwitch then return end

	ZCNPC.__dmsKoSwitch = DMS.Switch

	function DMS:Switch(ar, name)
		local rag = ar and ar.ragdoll
		if name == "stumble" and IsValid(rag)
			and (rag.zcnpc_throes or 0) <= CurTime()
			and not rag.zcnpc_dead
			and ZCNPC.IsOutCold(rag.organism)
		then
			name = "injured"
		end

		return ZCNPC.__dmsKoSwitch(self, ar, name)
	end
end

InstallKoStumble()
hook.Add("InitPostEntity", "zcnpc_artagdoll_kostumble", InstallKoStumble)

-- DMS only starts a voice clip when it Switches into a behaviour. Knockout calls
-- SoundManager:Stop and often leaves the body on "injured", so waking up never
-- hits Switch again and the floor stays silent (tranq → wake → writhe, no moans).
local BEHAVIOR_VOICE = {
	burning = { reaction = "burn", looped = true },
	falling = { reaction = "flying", looped = true },
	stumble = { reaction = "bullet", looped = true },
	injured = { reaction = "bullet", looped = true },
}

local function ResumeBodyVoice(rag, ar)
	if not (IsValid(rag) and ar) then return end
	if rag.zcnpc_gettingup then return end
	if ZCNPC.IsBodySilent and ZCNPC.IsBodySilent(rag.organism) then return end
	if not (istable(SoundManager) and isfunction(SoundManager.Play)) then return end

	local sfx = BEHAVIOR_VOICE[ar.CurrentBehavior] or BEHAVIOR_VOICE.injured

	SoundManager:Play(rag, sfx.reaction, sfx.looped)
end

function ZCNPC.DriveActive(rag)
	if not (IsValid(rag) and Installed()) then return end

	local ar = ActiveRagdoll.Get(rag)
	if not ar then return end

	local org = rag.organism
	if not org then return end

	-- Consciousness / HP can move without any behaviour calling SetStrength
	-- again (stumble only sets it in OnStart). Re-apply so the scale gate
	-- sees the new number — that is Unconsciousness, not a second on/off.
	if ar.SetStrength then
		local want = ar.zcnpc_want_strength
		if not want and istable(ActiveRagdollManager) and istable(ActiveRagdollManager.Config) then
			want = ActiveRagdollManager.Config.DefaultStrength
		end

		ar:SetStrength(want or 2.5)
	end

	local cold = OutCold(org)
	local wasCold = rag.zcnpc_was_outcold == true
	rag.zcnpc_was_outcold = cold

	if cold or LegsRuined(org) or (ZCNPC.IsDuctTaped and ZCNPC.IsDuctTaped(rag)) then
		PinFloor(ar)
		-- Injured.Switch starts a looped scream. Stop after the switch, every
		-- time, not only on the otrub edge — that edge is what left Knocked
		-- Out bodies yelling.
		if cold then
			ZCNPC.StopBodySound(rag)
		end
	else
		UnpinFloor(ar)
		if wasCold and istable(DMS) and isfunction(DMS.Switch) then
			DMS:Switch(ar, "stumble")
		end
	end

	if not cold then
		local muted = not (istable(SoundManager) and istable(SoundManager.ActiveSounds)
			and SoundManager.ActiveSounds[rag]
			and not SoundManager.ActiveSounds[rag].FadingOut)
		if wasCold or muted then
			ResumeBodyVoice(rag, ar)
		end
	end
end

local nextPinTick = 0
hook.Add("Tick", "zcnpc_artagdoll_pin", function()
	if not Installed() then return end
	if not next(ZCNPC.ActiveBodies) then return end

	local now = CurTime()
	if now < nextPinTick then return end
	nextPinTick = now + 0.05

	for rag in pairs(ZCNPC.ActiveBodies) do
		if not IsValid(rag) then
			ZCNPC.ActiveBodies[rag] = nil
			continue
		end

		local ar = ActiveRagdoll.Get(rag)
		if not ar then continue end
		if rag.zcnpc_dead or rag.zcnpc_corpse then continue end
		if (rag.zcnpc_throes or 0) > now then continue end

		if ZCNPC.IsOutCold(rag.organism) then
			PinFloor(ar)
			if ar.SetStrength then ar:SetStrength(ar.zcnpc_want_strength or 0) end
			ZCNPC.StopBodySound(rag)
			continue
		end

		if not ar.zcnpc_drive_pin then continue end

		if ar.SetStrength and ar.zcnpc_want_strength then
			ar:SetStrength(ar.zcnpc_want_strength)
		end

		-- Already on injured with no wallstunt: PinFloor would no-op Switch.
		local beh = ar.CurrentBehavior
		if beh ~= "injured" or (ar.ActiveLayers and ar.ActiveLayers.wallstunt) then
			PinFloor(ar)
		end
	end
end)

local function WantsActive(rag)
	local org = rag.organism
	if not org then return false end

	if rag.zcnpc_gettingup then return false end
	if rag.zcnpc_dead then return false end
	if rag.headexploded or rag.noHead then return false end
	if bit.band(rag:GetFlags(), FL_DISSOLVING) == FL_DISSOLVING then return false end

	if org.alive == false then return false end -- the death flail is started once, by ZCNPC_Died
	-- Knocked out stays on the controller. Strength is ActiveStrengthScale.
	-- A lethal head shot sets brain and the kill latch a frame before KillDowned
	-- runs. Starting a living stumble in that gap is the body trying to stand up
	-- into the kill shove - and that is the launch.
	if (org.brain or 0) >= 1 then return false end
	if rag.zcnpc_headkill then return false end
	local npc = rag.zcnpc_npc
	if IsValid(npc) and npc.zcnpc_headkill then return false end
	-- Broken spine: real paralysis. Any active behaviour (stumble / tumble /
	-- injured) still moves the body; the look we want is a ragdoll that does
	-- nothing, so the controller comes off entirely.
	if SpineBroken(org) then return false end

	return true
end

function ZCNPC.UpdateActive(rag)
	if not IsValid(rag) then return end

	ZCNPC.PushHealth(rag)

	if not BodyReady() then return ZCNPC.ActiveOff(rag) end
	-- A finished corpse must not keep injured's torso pulse. The old
	-- early-return left the controller running forever if ActiveDie missed
	-- a frame or ArtAgdoll started one after KillDowned.
	if rag.zcnpc_corpse then
		if (rag.zcnpc_throes or 0) <= CurTime() then
			return ZCNPC.ActiveDie(rag)
		end

		return
	end
	if rag.zcnpc_dead then return ZCNPC.ActiveOff(rag) end

	if WantsActive(rag) then
		local had = ZCNPC.IsActive(rag)

		ZCNPC.ActiveOn(rag, rag.zcnpc_dmgpos)

		if had then
			ZCNPC.DriveActive(rag)
		else
			-- Run is deferred 0.05s; Drive then so the scale / pin land on
			-- the same controller Setup just built.
			timer.Simple(0.05, function()
				if IsValid(rag) then ZCNPC.DriveActive(rag) end
			end)
			timer.Simple(0.12, function()
				if IsValid(rag) then ZCNPC.DriveActive(rag) end
			end)
		end
	else
		ZCNPC.ActiveOff(rag)
	end
end

-- Pulse came back (CPR / adrenaline / etc.) on a body that is still ours - not a
-- KillDowned corpse. Strength / pin follow consciousness inside DriveActive; the
-- active ragdoll itself was never taken off for heartstop alone.
function ZCNPC.PulseRestored(rag)
	if not IsValid(rag) then return end
	if rag.zcnpc_corpse or rag.zcnpc_dead then return end
	if rag.zcnpc_headkill or rag.headexploded or rag.noHead then return end

	local org = rag.organism
	if not org or org.alive == false then return end

	ZCNPC.Debug("pulse restored, active ragdoll:", rag)
	ZCNPC.UpdateActive(rag)
end

hook.Add("Org Think", "zcnpc_pulse_restore", function(owner, org)
	if not (ZCNPC.Enabled() and istable(org) and org.fakePlayer) then return end
	if not IsValid(owner) then return end

	-- While downed the organism lives on the ragdoll (MoveOrganism in sv_uncon).
	local rag = owner.zcnpc_rag
	if not IsValid(rag) and owner:IsRagdoll() and ZCNPC.Downed and ZCNPC.Downed[owner] then
		rag = owner
	end

	if not IsValid(rag) then
		org.zcnpc_was_heartstop = org.heartstop == true
		org.zcnpc_was_outcold = OutCold(org)

		return
	end

	local stopped = org.heartstop == true
	local was = org.zcnpc_was_heartstop == true
	org.zcnpc_was_heartstop = stopped

	local cold = OutCold(org)
	local wasCold = org.zcnpc_was_outcold == true
	org.zcnpc_was_outcold = cold

	if (was and not stopped) or (wasCold and not cold) then
		ZCNPC.PulseRestored(rag)
	elseif not wasCold and cold then
		ZCNPC.DriveActive(rag)
	end
end)
--//

--\\ Sound
-- Artagdoll voices the bodies it animates out of DMS:Switch, which starts a looped
-- reaction for whichever behaviour is taking over (dms_core.lua:120) - laboured
-- breathing for a body that is still fighting, the rattle for one that is not. The
-- clips themselves ship separately, under sound/SFX/<gender>/<reaction>; without
-- them SoundManager finds nothing and stays quiet, which is the whole of "it has
-- no sounds".
--
-- What is wanted from this side is the rattle on the way out: Artagdoll only plays
-- it for a head shot (dms_physics.lua:74), so a body that bled out on the floor -
-- most of the ones this addon makes - died in silence.
--
-- On our bodies CreateSound("^SFX/...") was driving lip-sync (TalkEndTime) while
-- often producing nothing audible - the caret makes Source treat the path as a
-- sentence. We replay through CreateSound without the caret so the patch is both
-- audible and stoppable (EmitSound could not be cut off when the body stood up).
local function SoundReady()
	return istable(SoundManager) and isfunction(SoundManager.Play)
end

local function OurSoundBody(ent)
	if not IsValid(ent) then return false end
	if ZCNPC.ActiveBodies and ZCNPC.ActiveBodies[ent] then return true end
	if ZCNPC.Downed and ZCNPC.Downed[ent] then return true end
	if ent.zcnpc_corpse or ent.zcnpc_dead then return true end

	return false
end

local REACTION_SND = {
	burn = { volume = 1.1, level = 75 },
	bullet = { volume = 0.95, level = 70 },
	flying = { volume = 0.9, level = 75 },
	death = { volume = 0.75, level = 75 },
	Death = { volume = 0.75, level = 75 },
}

function ZCNPC.StopBodySound(rag)
	if not IsValid(rag) then return end

	if istable(SoundManager) then
		if isfunction(SoundManager.Stop) then SoundManager:Stop(rag, 0) end

		if istable(SoundManager.ActiveSounds) then
			local data = SoundManager.ActiveSounds[rag]
			if data and data.Patch and data.Patch.Stop then data.Patch:Stop() end
			SoundManager.ActiveSounds[rag] = nil
		end
	end

	if RagdollFaceAnimator and isfunction(RagdollFaceAnimator.LipsSyncs) then
		RagdollFaceAnimator:LipsSyncs(rag, 0)
	end
end

local function SilentClip(ent, reactionType)
	if not OurSoundBody(ent) then return false end
	if ent.zcnpc_gettingup then return true end

	local reaction = string.lower(tostring(reactionType or ""))
	local dying = reaction == "death"
		or (ent.zcnpc_throes or 0) > CurTime()
		or ent.zcnpc_corpse
	if dying then return false end

	return ZCNPC.IsBodySilent and ZCNPC.IsBodySilent(ent.organism) or false
end

local function InstallSoundPlay()
	if not istable(SoundManager) then return end

	-- Play is the door DMS:Switch uses. ExecutePlay is the clip itself.
	-- Knocked Out must die at both: injured starts a looped scream, and
	-- CreateSound never hits EntityEmitSound.
	if isfunction(SoundManager.Play) and not ZCNPC.__smPlay then
		ZCNPC.__smPlay = SoundManager.Play

		function SoundManager:Play(ent, reaction, looped)
			if SilentClip(ent, reaction) then return end

			return ZCNPC.__smPlay(self, ent, reaction, looped)
		end
	end

	if not isfunction(SoundManager.ExecutePlay) then return end
	if ZCNPC.__smExecutePlay then return end

	ZCNPC.__smExecutePlay = SoundManager.ExecutePlay

	function SoundManager:ExecutePlay(ent, reactionType)
		if not OurSoundBody(ent) then
			return ZCNPC.__smExecutePlay(self, ent, reactionType)
		end

		if not IsValid(ent) or not reactionType then return end

		-- Standing up / frozen for the get-up pose: never start a new clip.
		if ent.zcnpc_gettingup then return end

		-- Out cold: do not start a clip. Otherwise the face still chews air.
		-- Death / throes are the exception - that is the rattle on the way out.
		local reaction = string.lower(tostring(reactionType))
		local dying = reaction == "death"
			or (ent.zcnpc_throes or 0) > CurTime()
			or ent.zcnpc_corpse
		if not dying and ZCNPC.IsBodySilent and ZCNPC.IsBodySilent(ent.organism) then
			return
		end

		local files, folder = self:FindSounds(ent, reactionType)
		local fileCount = files and #files or 0
		if fileCount == 0 then return end

		local data = self.ActiveSounds[ent]
		if not data or data.FadingOut then return end

		local pick = files[1]
		if fileCount > 1 then
			for _ = 1, 5 do
				pick = files[math.random(fileCount)]
				if pick ~= data.LastFile then break end
			end
		end

		data.LastFile = pick

		local cleanPath = folder .. pick
		local cfg = REACTION_SND[reactionType] or { volume = 1.0, level = 75 }

		if data.Patch and data.Patch.Stop then data.Patch:Stop() end

		-- No "^" prefix: that is what made the stock path silent / unsyncable.
		local patch = CreateSound(ent, cleanPath)
		if not patch then return end

		data.Patch = patch
		if patch.SetSoundLevel then patch:SetSoundLevel(cfg.level) end
		if patch.PlayEx then patch:PlayEx(cfg.volume, math.random(95, 105)) end

		-- Pin to the head immediately; ArtAgdoll's own Think uses GetBonePosition
		-- which on a server ragdoll often stays in the chest.
		if patch.SetPos and ZCNPC.BodyVoicePos then
			patch:SetPos(ZCNPC.BodyVoicePos(ent))
		end

		local duration = SoundDuration(cleanPath) or 1.0
		if duration <= 0 then duration = 1.0 end

		local ct = CurTime()
		data.TalkEndTime = ct + duration
		data.BaseVolume = cfg.volume
		data.NextPlayTime = ct + duration + math.Rand(0.4, 1.0)
	end
end

InstallSoundPlay()
hook.Add("InitPostEntity", "zcnpc_artagdoll_sound", InstallSoundPlay)

-- Keep the patch on the skull while it plays. Runs after ArtAgdoll's SoundManager
-- Think so our head phys position wins over its torso GetBonePosition.
local nextHeadSound = 0
hook.Add("Think", "zcnpc_artagdoll_soundpos", function()
	local ct = CurTime()
	if ct < nextHeadSound then return end
	nextHeadSound = ct + 0.05

	if not (istable(SoundManager) and istable(SoundManager.ActiveSounds) and ZCNPC.BodyVoicePos) then
		return
	end

	for ent, data in pairs(SoundManager.ActiveSounds) do
		if not OurSoundBody(ent) then continue end
		if not (data and data.Patch and data.Patch.SetPos) then continue end
		if data.FadingOut then continue end

		local pos = ZCNPC.BodyVoicePos(ent)
		local last = data.zcnpc_soundpos
		if last and last:DistToSqr(pos) < 4 then continue end

		data.zcnpc_soundpos = pos
		data.Patch:SetPos(pos)
	end
end)

function ZCNPC.BodySound(rag, reaction, looped)
	if not (IsValid(rag) and SoundReady()) then return end

	SoundManager:Play(rag, reaction, looped or false)
end
--//

--\\ Handing the bodies over
-- dmgpos is where the round went in, which is read off Z-City's own bullet trace
-- (ZCNPC.LastHit, sv_damage.lua) rather than off Artagdoll's DMS_LastDmgPos. Its
-- version is written from every EntityTakeDamage there is, and the last one an NPC
-- takes before it goes down is the organism killing itself off a DamageInfo with no
-- position on it at all - so it came out as the world origin, and a body that had
-- just taken a burst to the chest reached for whichever bone was nearest the middle
-- of the map. Nothing is better than wrong here: no position means no wound grab.
hook.Add("ZCNPC_Downed", "zcnpc_artagdoll", function(npc, rag)
	rag.zcnpc_dmgpos = ZCNPC.LastHit(npc)

	ZCNPC.UpdateActive(rag)
end)

-- Getting up needs the body to hold still, and StartGetUp freezes its physics
-- objects to make sure of it. An active ragdoll would go on pushing against them,
-- and a body still wearing the stiffener's splints cannot be posed at all.
hook.Add("ZCNPC_GetUp", "zcnpc_artagdoll", function(npc, rag)
	if IsValid(rag) then rag.zcnpc_gettingup = true end

	ZCNPC.StopBodySound(rag)
	ZCNPC.ActiveOff(rag)
	ZCNPC.TamePhysics(rag)
end)

hook.Add("ZCNPC_WokeUp", "zcnpc_artagdoll_sound", function(_, _, rag)
	ZCNPC.StopBodySound(rag)
end)

-- Dying on the ground: the one time a body is handed over to be let go of rather
-- than held up, so the collapse plays out - for as long as a collapse lasts, and no
-- longer.
--
-- Only for a body that was still being driven when it died, though, and that is the
-- difference between a death and a death throe. Most of the bodies this addon makes
-- die out cold: knocked out, heart stopped, forty-five seconds of lying perfectly
-- still, and then the bleed-out timer runs out. Handing that one a collapse is a
-- corpse that has been quiet for a minute suddenly hauling itself half upright to
-- die a second time, which is what "it is dead and the ragdoll is still alive" looks
-- like from the outside. There is nobody left in that body to go over with it. So it
-- simply stops, and the collapse is kept for the bodies it means something on - one
-- that was awake and fighting the floor a moment ago.
hook.Add("ZCNPC_Died", "zcnpc_artagdoll", function(rag)
	-- Headshot / headless: never hand over a death throe. That is the "corpse is
	-- still alive" look, and a collapse into leftover punch velocity is a launch.
	if rag.zcnpc_headkill or rag.headexploded or rag.noHead then
		return ZCNPC.ActiveDie(rag)
	end

	-- Arrest / KO already had nobody in them. A throe here is the corpse
	-- sitting up after "Knocked out." / a stopped heart.
	if ZCNPC.IsOutCold(rag.organism) or (rag.organism and rag.organism.heartstop) then
		return ZCNPC.ActiveDie(rag)
	end

	if not (BodyReady() and ZCNPC.IsActive(rag)) then return ZCNPC.ActiveDie(rag) end

	ZCNPC.ActiveOff(rag) -- the living body's active ragdoll, with its shared health

	ZCNPC.DeathThroes(rag, true)
end)

-- An NPC that died on its feet leaves an engine death ragdoll behind, and that one
-- Artagdoll does find by itself, off the same hook. Finding it is the only part it
-- gets right: what it found is a corpse, and it hands it two hundred hit points and
-- the behaviour for somebody trying to stand up. So the length of the collapse has to
-- be put back on these as well.
hook.Add("CreateEntityRagdoll", "zcnpc_artagdoll", function(owner, rag)
	if not (IsValid(owner) and owner:IsNPC() and IsValid(rag)) then return end
	if ZCNPC.DropEngineRagdoll and ZCNPC.DropEngineRagdoll(owner, rag) then return end
	if not ZCNPC.ArtagdollReady() then return end

	local dmgpos = ZCNPC.LastHit(owner)

	rag.zcnpc_corpse = true -- it was one from the moment it was created

	-- This body is allowed its collapse, and saying so has to come first. The
	-- organism arrives on it dead (sv_core.lua hands it over with alive false), so to
	-- the corpse guard it is a corpse from its first frame - and the active ragdoll
	-- Artagdoll is about to start on it, a twentieth of a second from now, would have
	-- been turned away before our own timer below got a word in. A body that has this
	-- instant become one is the exact case a collapse is for.
	rag.zcnpc_throes = CurTime() + DEATH_TIME

	-- Artagdoll's own CreateEntityRagdoll copies owner.DMS_IsHeadshot onto the doll
	-- and may run after this hook. Fatal Headshot is held off, so strip both ends
	-- next frame - after that copy - and keep the ordinary collapse.
	owner.DMS_IsHeadshot = false
	rag.DMS_IsHeadshot = false
	timer.Simple(0, function()
		if IsValid(rag) then rag.DMS_IsHeadshot = false end
	end)

	-- Artagdoll starts these itself a twentieth of a second from now, so there is
	-- nothing yet to give a length to
	timer.Simple(0.1, function()
		if not IsValid(rag) then return end

		if not ZCNPC.IsActive(rag) then
			rag.zcnpc_throes = nil -- never taken up, so nothing is collapsing

			return
		end

		rag.zcnpc_dmgpos = dmgpos

		ZCNPC.DeathThroes(rag, false)
	end)
end)

--\\ Player corpses stay dead
-- Players are not handed over for a living stumble. Artagdoll still finds them
-- two other ways: PostPlayerDeath "Fedhoria" (stripped above) and the engine's
-- CreateEntityRagdoll, which DMS_Init treats under ar_enabled_npcs rather than
-- the player switch. Either path lands injured on the Z-City RagdollDeath - the
-- procedural pulse / twitch that reads as a corpse forever convulsing.
--
-- Mark the body a corpse and kill any ArtAgdoll that beat us there. Z-City's own
-- brainfuck spasms (organism/sv_brainfuck.lua) stay: they are the death twitch
-- players are supposed to get. Fedhoria / ar_enabled_players stay held off above.
local function StillPlayerCorpse(rag)
	if not IsValid(rag) then return end

	rag.zcnpc_playercorpse = true
	rag.zcnpc_dead = true
	rag.zcnpc_throes = nil
	ZCNPC.DeadBodies[rag] = true

	if Installed() then ZCNPC.ActiveDie(rag) end
end

function ZCNPC.StillPlayerCorpse(rag)
	StillPlayerCorpse(rag)
end

hook.Add("RagdollDeath", "zcnpc_artagdoll_player", function(ply, rag)
	if not ZCNPC.Enabled() then return end
	if not (IsValid(ply) and ply:IsPlayer() and IsValid(rag)) then return end

	StillPlayerCorpse(rag)

	-- BrainfuckStart / Fedhoria race this hook; kill ArtAgdoll again after both.
	timer.Simple(0.2, function()
		StillPlayerCorpse(rag)
	end)
end)

hook.Add("PostPlayerDeath", "zcnpc_artagdoll_player", function(ply)
	if not ZCNPC.Enabled() then return end

	local rag = ply:GetNWEntity("RagdollDeath")
	if not IsValid(rag) then rag = ply.FakeRagdoll end
	if not IsValid(rag) then return end

	StillPlayerCorpse(rag)

	-- After Fedhoria's 0.05s and ActiveRagdollManager's extra 0.05s deferral.
	timer.Simple(0.15, function()
		StillPlayerCorpse(rag)
	end)
end)

-- Engine / Artagdoll death ragdoll for a player. Z-City already built
-- FakeRagdoll / RagdollDeath. Leaving this doll is the second corpse.
hook.Add("CreateEntityRagdoll", "zcnpc_artagdoll_noplayer", function(owner, rag)
	if not ZCNPC.Enabled() then return end
	if not (IsValid(owner) and owner:IsPlayer() and IsValid(rag)) then return end

	local keep = owner:GetNWEntity("RagdollDeath")
	if not IsValid(keep) then keep = owner.FakeRagdoll end
	if rag == keep then
		StillPlayerCorpse(rag)

		return
	end

	rag.zcnpc_drop = true
	rag:Remove()
	timer.Simple(0, function()
		if IsValid(rag) and rag ~= keep then rag:Remove() end
	end)
end)

-- Anything that slipped past CreateEntityRagdoll (ents.Create of a doll
-- that never went through the engine hook) still has to go.
local function DropExtraPlayerRagdolls(ply)
	if not IsValid(ply) then return end

	local keep = ply:GetNWEntity("RagdollDeath")
	if not IsValid(keep) then keep = ply.FakeRagdoll end
	if not IsValid(keep) then return end

	local model = keep:GetModel()
	local pos = keep:GetPos()

	for _, ent in ipairs(ents.FindInSphere(pos, 96)) do
		if ent == keep then continue end
		if not (IsValid(ent) and ent:GetClass() == "prop_ragdoll") then continue end
		if ent:GetModel() ~= model then continue end
		if ent.zcnpc_keepbody or ent.zcnpc_npcbody then continue end
		if ZCNPC.Downed and ZCNPC.Downed[ent] then continue end
		if ent.zcnpc_playercorpse then continue end
		if IsValid(ent.ply) and ent.ply ~= ply then continue end
		if ent.organism then continue end

		ent:Remove()
	end
end

hook.Add("PostPlayerDeath", "zcnpc_artagdoll_nodupe", function(ply)
	if not ZCNPC.Enabled() then return end

	timer.Simple(0, function() DropExtraPlayerRagdolls(ply) end)
	timer.Simple(0.15, function() DropExtraPlayerRagdolls(ply) end)
end)
--//
