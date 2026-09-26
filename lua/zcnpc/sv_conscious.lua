--[[
	Staying awake while being shot.

	Z-City settles unconsciousness out of a single number: org.shock. Every hit adds
	to it (sv_input.lua:812) and it turns into a knockout by either of two routes:

	* over forty, hg.organism.paincheck is true and org.needotrub is set on the spot
	  (modules/sv_pain.lua:110). Ten times four, and the ten is org.shock_turn.
	* over thirty, consciousness is walked down towards 0.1 over about five seconds
	  (:80), and on the way past 0.4 it sets org.needfake - which on an NPC is the
	  10000 damage this addon turns into a knockout.

	A single rifle round leaves shock in the twenties, so two of them anywhere on a
	body cleared both thresholds between them: a burst into a leg switched an NPC off
	exactly as reliably as a bullet through the brain, and every firefight ended with
	everybody asleep on the floor a second after it started.

	What is capped here is how much shock a hit may leave on an NPC that is still
	awake - held just under the lower of those two thresholds - and nothing else is
	touched, so every other way of losing consciousness works exactly as Z-City wrote
	it:

	* bleeding out. Blood caps consciousness on its own (modules/sv_blood.lua:103)
	  and asks for the knockout outright below 2400 (:176), which is how a body ends
	  up on the floor when nobody finished it off.
	* a broken spine, a missing leg, choking, carbon monoxide.
	* a tranquilizer dart, which takes consciousness by a route of its own
	  (modules/sv_pain.lua:87) and is exempt here besides.
	* a damaged brain, which rolls for a seizure every tick and drops the NPC where
	  it stands (sv_organism.lua:519) - nothing to do with shock, and untouched.
	* the head, which is the one place a bullet reaches something the thinking runs
	  on. That is the exception below, and the only one gunfire gets.

	Nor does any of it touch how long a body that is already down stays down. That is
	the same number read against a threshold ten times lower (org.shock_turn drops to
	1 while otrub, :39), and it is the right answer to a different question: a body
	is out for as long as the pain says, it just takes a great deal more than pain to
	put it there.
]]

local cfg = ZCNPC.Config

-- Just under the thirty of modules/sv_pain.lua:80, and so well under the forty of
-- hg.organism.paincheck as well. Z-City's own ceiling on the same number is seventy,
-- so this is a limit on how far one hit gets rather than a rewrite of the scale: a
-- body still reads as being in shock, deep into it, it just does not read as being
-- past the point of staying conscious.
local PAIN_LIMIT = 29

-- What a head shot leaves behind when it does not kill: past hg.organism.paincheck's
-- forty, so the organism holds the body down itself for as long as it lasts. It
-- decays at four a second on a body that is out (:49), which is something like ten
-- seconds of lying there - about as long as our own knockouts last for every other
-- reason.
local HEAD_SHOCK = 45

-- How long a head shot stays exempt from the cap. A tick would do - see HeadTrauma
-- below - and this is a few seconds of slack on top, for a hit that had to be handed
-- to a timer before the body could go down. Short either way: the next magazine into
-- the same chest is back to being a chest.
local KO_WINDOW = 6

--\\ The exception
-- Asked once per round that got into a head, by the head shot detection in
-- sv_head.lua, and it answers whether this one puts the NPC out. Anything that
-- reached the brain never needs luck - it is a bullet in the part the thinking runs
-- on. A round that only cracked the skull, which is what a helmet leaves of one,
-- gets a single roll of zcnpc_headshot_ko, and that roll is the only way gunfire on
-- its own still drops an NPC where it stands.
--
-- Being put out and staying out are two different things and both are settled here.
-- The knockout itself is immediate, by the caller; how long it lasts is the shock
-- left behind, which is what the organism reads to keep a body under - so it is
-- written up past the threshold and exempted from the cap while it does its work.
function ZCNPC.HeadKnockout(org, reachedBrain)
	if not istable(org) then return false end
	if not (reachedBrain or math.random() < cfg.headshot_ko:GetFloat()) then return false end

	org.zcnpc_headko = CurTime() + KO_WINDOW
	org.shock = math.max(org.shock or 0, HEAD_SHOCK)

	return true
end

-- The window is the whole of the exemption, and it does not need to be any wider than
-- one tick: all it has to survive is the gap between the hit and org.otrub being set,
-- after which the body is out and the cap steps aside on its own.
--
-- It was tempting to write this as "or the brain is damaged", on the grounds that a
-- bullet in there is not something anybody shakes off in six seconds. That would have
-- been permanent rather than long: brain damage under a tenth does not heal at all
-- (modules/sv_lungs.lua:398 stops decaying it there), so an NPC that walked away from
-- a graze to the brain would have been exempt for the rest of the round - and the next
-- magazine into its chest would knock it out, which is the thing this file exists to
-- stop. Z-City has its own answer for a damaged brain and it is a much better one:
-- past 0.05 it rolls for a seizure every tick and drops the NPC where it stands
-- (sv_organism.lua:519), which is not shock, is not touched here, and does not care
-- where the round that put it there landed.
local function HeadTrauma(org)
	return (org.zcnpc_headko or 0) > CurTime()
end
--//

--\\ The cap
-- Only ours. org.fakePlayer marks an organism as belonging to an NPC rather than to a
-- player (sv_core.lua:64, and Z-City's own sv_npcstuff.lua:60 for its three classes);
-- a player's shock is a player's business.
-- Org Think hits every organism. fakePlayer first so a player is one field
-- read, not two convar lookups, and the knockout switch is held rather than
-- hashed every tick.
local cachedBulletKo = true

local function RefreshShockCvars()
	if cfg.bullet_ko then cachedBulletKo = cfg.bullet_ko:GetBool() end
end

pcall(cvars.AddChangeCallback, "zcnpc_bullet_ko", RefreshShockCvars, "zcnpc_shock_ko")
RefreshShockCvars()

local function Capped(org)
	if not (istable(org) and org.fakePlayer) then return false end
	if not ZCNPC.Enabled() then return false end
	if cachedBulletKo then return false end
	if org.alive == false then return false end

	-- already out, so there is no knockout left to prevent, and how long it stays out
	-- is a question Z-City answers well: the same shock against a threshold ten times
	-- lower (modules/sv_pain.lua:39), decaying at four a second. Capping here would
	-- have cut every knockout in the mod short, whatever had put the body down.
	if org.otrub then return false end

	if (org.tranquilizer or 0) > 0 then return false end
	if HeadTrauma(org) then return false end

	return true
end

local function Cap(org)
	if not Capped(org) then return end

	if (org.shock or 0) > PAIN_LIMIT then org.shock = PAIN_LIMIT end
end

-- Where a hit is capped, and it has to be here rather than only on the tick after:
-- Z-City adds the shock inside its damage handling (sv_input.lua:812) and runs this
-- hook at the end of the same call (:888), while the pain module that reads it runs
-- from "Org Think" - and whether our own "Org Think" lands before or after Z-City's
-- is not something a hook name decides. One rifle round is twenty-something points
-- of shock, so a second one can cross forty and be read as a knockout inside a single
-- tick; catching it in the damage path means it is already down to PAIN_LIMIT before
-- anything gets to look at it.
hook.Add("HomigradDamage", "zcnpc_shock", function(victim)
	if not IsValid(victim) then return end

	Cap(victim.organism)
end)

-- And where it is held. Damage is not the only thing that raises shock: past eighty
-- pain the pain module walks it up towards seventy on its own (modules/sv_pain.lua:77)
-- and would have got there eventually with nothing but a bad enough wound behind it.
-- Ordering does not matter for this one - it is a climb of four a second against a cap
-- reapplied every tick, so it never gets more than a frame's worth above the line.
--
-- "Org Think" is run once per organism per tick, over the whole of hg.organism.list
-- (organism/tier_0/sv_tier_0.lua:79).
hook.Add("Org Think", "zcnpc_shock", function(_, org)
	Cap(org)
end)
--//
