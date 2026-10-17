--[[
	Half-Life 2's own hazards, put through the organism.

	Z-City rewrote what damage means and never went back for the things Valve
	shipped, so a few of the map's oldest killers stopped working on the bodies
	this addon spends the rest of its time simulating. None of these are bugs in
	Z-City exactly - they are gaps between an engine that deals hit points and a
	body that deals wounds.

	Four of them are answered here. Combine mines and helicopter bombs are a
	pressure wave and nothing else, where every other explosive in Z-City throws
	metal. A hunter's darts deal DMG_DISSOLVE, which is the one damage type the
	organism drops on sight (sv_input.lua:427), so they take engine health off a
	player and leave the body underneath untouched. A rollermine's shock reaches
	almost nobody: the attack turns away anything that is not a player or an NPC on
	its feet, which is every body on the floor and every downed player parked
	intangible inside one, and what does land on somebody standing is small enough
	that the organism reads it as nothing. And a barnacle bites with DMG_CRUSH,
	which the same handler drops sixty lines after DMG_DISSOLVE (sv_input.lua:487),
	so it holds you in its tongue and chews until the map ends without ever taking
	anything off you.
]]

local cfg = ZCNPC.Config

--\\ Mines and helicopter bombs throwing metal
-- Z-City's own grenades explode twice: once as a blast (util.BlastDamage) and once
-- as a few dozen fragments fired as bullets, which is where nearly all of the
-- wounding comes from - a blast leaves bruising and an explosion wound, a fragment
-- leaves a hole that bleeds. Anything the engine explodes only does the first half,
-- so standing next to a Combine mine is survivable in a way that standing next to a
-- grenade is not.
--
-- Same ammunition Z-City throws off its own grenades and off an AP round cooking off
-- (sh_ammostuff.lua:302), so the wounds are the ones players already know.
-- Forty is what a fragment is worth everywhere else in Z-City, grenade or cooked off
-- round alike, so the only thing that separates one explosive from another here is
-- how much of it there is to throw.
local FRAGMENT_DAMAGE = 40

-- Counts in the same money Z-City counts its own in, which is the whole reason this
-- works at all now. Only fragments that are going to reach something get fired (see
-- Fragment below, and the grenade at ent_hg_grenade/init.lua:348 doing the same) - so
-- the count is not how many fragments arrive, it is how finely the sphere around the
-- explosion gets sampled, and everything aimed at open air or a wall is thrown away.
--
-- A body a hundred units off covers something like a hundredth of that sphere, so a
-- few dozen samples is a coin flip on hitting anybody at all: the previous 26 was not
-- a light mine, it was a mine whose fragments almost always missed. Z-City's own
-- numbers are what that scale actually costs - 640 for its HL2 grenade
-- (ent_hg_grenade_hl2grenade), 960 for the anti-tank one, 1200 for a rocket - and
-- they are multiplied up in the source with a comment saying 300 is not frightening.
local FRAGMENT = {
	-- A bouncebomb is a shaped charge on a tripod and Valve gives it a grenade's
	-- blast, so it is priced as Z-City prices the grenade Valve shipped.
	combine_mine = { count = 640, rise = 8 },

	-- Bigger than anything a person carries, and the only thing in Half-Life 2 that
	-- drops one is a gunship that has already decided about you.
	grenade_helicopter = { count = 1100, rise = 4 },
}

-- The grenade's own reach, because a fragment that stops at 900 units is a fragment
-- that cannot cross a courtyard, and nothing else in Z-City throws metal that politely
-- (ent_hg_grenade/init.lua:348, :367).
local FRAGMENT_TRACE = 10000
local FRAGMENT_REACH = 56756
local FRAGMENT_FORCE = 20
local FRAGMENT_PENETRATION = 100 -- MaxPenLen: how deep one is still travelling through

-- Fragments are cheap to reject and expensive to fire, so the burst is spent against a
-- clock rather than a fixed count per frame: a mine in a corridor finishes inside one
-- tick, and a mine in a crowd takes the two or three it needs instead of dribbling a
-- fixed dozen per frame for most of a second.
local FRAGMENT_BUDGET = 0.002

local burst = 0 -- names the timer, so two mines going off together keep both bursts

-- A mine is a mine until something takes it off the map, and there is no way to ask
-- an entity on its way out whether it left in a bang or was tidied away. Everything
-- that tidies is a known moment, though, so those moments are marked and the rest is
-- taken to be a detonation.
local quiet = false

local function Quiet() quiet = true end

hook.Add("PreCleanupMap", "zcnpc_hl2", Quiet)
hook.Add("ShutDown", "zcnpc_hl2", Quiet)
hook.Add("PostCleanupMap", "zcnpc_hl2", function() quiet = false end)

local AMMO = "Metal Debris"

-- The ammunition entry Z-City fires its own fragments out of, and specifically the
-- BulletSettings inside it, because that is where the numbers that make a fragment
-- behave like one actually live (sh_ammostuff.lua:760) and nothing downstream goes
-- looking for them there. A bullet handed over without a Speed is not a slow
-- fragment: the physical bullet path reads bullet.Speed, then the top level of the
-- ammunition table, and then gives up and uses 320 (phys_bullets/sh_plugin.lua:121)
-- - and "Metal Debris" keeps its 700 one level further down, so every fragment was
-- leaving the mine at under half the speed of the same fragment off a grenade.
local function Debris()
	local types = istable(hg) and hg.ammotypeshuy
	local ammo = istable(types) and types[AMMO]

	if not istable(ammo) then return end

	return istable(ammo.BulletSettings) and ammo.BulletSettings or {}
end

-- Fired off worldspawn rather than off the mine, because the mine is gone: this runs
-- a frame after the entity that used to be here was removed, and there is nothing
-- left to fire from or to point the blame at except whoever dropped it. Z-City fires
-- its own cooked off rounds the same way and off the same entity.
--
-- The bullet itself is the grenade's, field for field (ent_hg_grenade/init.lua:351),
-- because a fragment is only a fragment if it carries all of it: the Callback is what
-- turns a hit into a wound, and the speed, width and penetration are what decide how
-- much of a body it goes through once it is one. Z-City's own cooked off AP round is
-- the shorter version of this same call and leaves most of them out
-- (sh_ammostuff.lua:297), which is a fragment that arrives with a number and nothing
-- else - worth copying from once and worth not copying from twice.
local function Throw(pos, spec, attacker)
	local settings = Debris()
	if not settings then return end

	local world = game.GetWorld()
	if not isfunction(world.FireLuaBullets) then return end

	if not IsValid(attacker) then attacker = world end

	-- The half of a Z-City bullet that turns it into a wound. Every explosive in the
	-- addon that throws metal hangs this on its fragments - the grenade
	-- (ent_hg_grenade/init.lua:371), the claymore (ent_claymore/init.lua:62) - and it
	-- is what walks the hole through the body, spends the penetration and leaves
	-- something that bleeds. Without it a fragment resolves as a plain engine bullet:
	-- it lands, and the only thing it has to say is a number.
	local wound = isfunction(hg.bulletHit) and hg.bulletHit or nil

	local spread = Vector(0, 0, 0)
	local thrown = 0

	-- Only fragments that are going to reach something are fired. A bullet is far
	-- more expensive than the trace that decides whether to fire it, and most of a
	-- sphere is wall - Z-City's own grenade does the same before every one of its
	-- fragments, and it is the reason a grenade going off in a corridor does not
	-- cost what a grenade going off in a field does.
	local function Fragment()
		local dir = VectorRand(-1, 1):GetNormalized()

		-- Biased away from the horizon the way the grenade biases it, so the ground
		-- and the ceiling take their share instead of everything flying out at
		-- shin height.
		dir[3] = dir[3] > 0 and math.abs(dir[3] - 0.5) or -math.abs(dir[3] + 0.5)
		dir:Normalize()

		local tr = util.QuickTrace(pos, dir * FRAGMENT_TRACE)
		if not tr.Hit or tr.HitSky or tr.HitWorld then return end

		world:FireLuaBullets({
			Src = pos,
			Dir = dir,
			Spread = spread,
			Damage = FRAGMENT_DAMAGE,
			Force = FRAGMENT_FORCE,
			Distance = FRAGMENT_REACH,
			AmmoType = AMMO,
			Attacker = attacker,
			Inflictor = attacker,
			DisableLagComp = true,
			Callback = wound,

			-- Off the ammunition rather than left to be guessed at, for the same
			-- reason the grenade reads them off it: these are what decide how far a
			-- fragment travels, how much of a body it goes through and how wide the
			-- hole is when it gets there.
			Speed = settings.Speed,
			Diameter = settings.Diameter,
			Penetration = settings.Penetration,
			MaxPenLen = FRAGMENT_PENETRATION,
			penetrated = 0,

			-- Empty rather than absent. Neither path filters nothing by default: the
			-- plain one falls back to whoever fired (sh_luabullets.lua:534) and the
			-- penetrating one to the entity the call was made on
			-- (sh_luabullets.lua:969), and both of those are worldspawn here - which
			-- is a fragment that ignores every wall on the map and comes through them
			-- to find somebody two rooms away.
			Filter = {},
			TraceFilter = {},
		}, true)
	end

	-- Spread over frames for the same reason Z-City spreads its own, and against the
	-- same clock it uses: a burst resolved in one tick is a visible hitch, and a
	-- fragment landing a frame late is not something anybody can see. Named per burst
	-- so two mines going off together do not eat each other's timer.
	burst = burst + 1

	local name = "zcnpc_hl2_frag_" .. burst

	timer.Create(name, 0, 0, function()
		local until_ = SysTime() + FRAGMENT_BUDGET

		repeat
			thrown = thrown + 1
			Fragment()

			if thrown >= spec.count then
				timer.Remove(name)

				return
			end
		until SysTime() >= until_
	end)
end

-- Every entity leaving the map comes through here, so the class is asked first: it is
-- the one question that says no to nearly all of them, and it is cheaper than the two
-- convars behind it.
local function Detonated(ent, fullUpdate)
	if quiet or fullUpdate or not IsValid(ent) then return end

	local spec = FRAGMENT[ent:GetClass()]
	if not spec then return end
	if not (ZCNPC.Enabled() and cfg.hl2_shrapnel:GetBool()) then return end

	local pos = ent:WorldSpaceCenter() + vector_up * spec.rise
	local owner = ent:GetOwner()

	if not IsValid(owner) then owner = ent:GetCreator() end

	timer.Simple(0, function() Throw(pos, spec, owner) end)
end
--//

--\\ Hunter flechettes
-- The darts and the little explosion each one makes a moment after it lands are both
-- dealt as DMG_DISSOLVE, which is the first thing Z-City's damage handler looks for
-- and the one type it refuses outright (sv_input.lua:427) - the handler returns
-- before it has read anything else, so the organism never hears about the hit at all
-- and the engine takes the damage off raw health instead. That is the whole of why a
-- hunter can empty a burst into somebody and leave them standing there unmarked with
-- a health bar going down.
--
-- The type is wrong rather than the damage, and DMG_DISSOLVE is refused for a good
-- reason - it is also what a combine ball does, and a body being deleted should not
-- be a body being wounded - so the only thing changed here is what the darts say
-- they are. A dart in the chest is a stab wound. The burst it goes off in is a blast.
local FLECHETTE = "hunter_flechette"

local function Flechette(dmgInfo)
	local inflictor = dmgInfo:GetInflictor()
	if IsValid(inflictor) and inflictor:GetClass() == FLECHETTE then return true end

	-- A dart that has already removed itself leaves the hunter holding the bag, and
	-- a hunter deals nothing else that dissolves.
	local attacker = dmgInfo:GetAttacker()

	return IsValid(attacker) and attacker:GetClass() == "npc_hunter"
end

ZCNPC.BeforeDamage.hl2_flechettes = function(ent, dmgInfo)
	if not cfg.hl2_flechettes:GetBool() then return end
	if not dmgInfo:IsDamageType(DMG_DISSOLVE) then return end
	if not ent.organism then return end
	if not Flechette(dmgInfo) then return end

	-- The dart itself arrives through DispatchTraceAttack and is flagged never to
	-- gib; the burst a second later is radius damage and is not. It is the only
	-- thing that separates them, since both come off the same dart with the same
	-- damage type.
	local direct = dmgInfo:IsDamageType(DMG_NEVERGIB)

	dmgInfo:SetDamageType(direct and DMG_SLASH or DMG_BLAST)
	dmgInfo:SetDamage(direct and cfg.hl2_flechette_hit:GetFloat() or cfg.hl2_flechette_blast:GetFloat())
end
--//

--\\ Rollermines
-- A rollermine's shock is the mine's entire reason to exist and in Z-City it does
-- nothing whatsoever, standing or lying down, and the reason is not the amount.
--
-- ShockTouch is the whole attack, and it turns almost everybody away at the door. It
-- wants prey that is a player or carries FL_NPC, so a body on the floor is refused
-- outright - a ragdoll is neither, and the hidden NPC underneath one of ours is in
-- godmode and not solid. A downed player is refused for a second reason on top of the
-- first: hg.Fake parks them inside their own ragdoll's head with MOVETYPE_NOCLIP and
-- COLLISION_GROUP_IN_VEHICLE, so the mine knows exactly where they are, rolls straight
-- at them and passes through without ever touching. And standing up, what does arrive
-- is a single-figure DMG_SHOCK - the organism spends electricity as pain and shock and
-- almost nothing as blood (sv_input.lua:1179), so single figures divided down come out
-- as a body that has noticed nothing at all.
--
-- Re-pricing what the mine deals is therefore most of the way to useless, because
-- almost none of the time does it deal anything. The shock is done from here instead,
-- for everybody: the mine is asked who it is up against and what it can reach, and
-- past that point it is the same current the taser puts through somebody, priced the
-- same, holding them down the same way and shaking the same limbs (sv_stun.lua). The
-- mine's own shock is still re-priced further down for the one case it does land on,
-- so a mine that catches somebody standing before this loop sees it is not wasted.
local ROLLERMINE = "npc_rollermine"
local ROLLER_REACH = 42
local ROLLER_COOLDOWN = 2.5
local SHOCK_TIME = 1.4

-- Search radius is a body long: an entity's origin is nowhere near where a mine
-- actually is (a ragdoll's is its pelvis, a standing player's is between their
-- feet). Reach is measured to the nearest part of the body; this is only the
-- cheap first cut that turns up candidates.
local ROLLER_SEARCH = 96
local ROLLER_SEARCH_SQR = ROLLER_SEARCH * ROLLER_SEARCH

local shocked = {} -- [rollermine] = when it may shock again

-- The mines themselves, not a FindByClass every fifth of a second. Weak keys so
-- a removed mine does not stay in the table; CallOnRemove is what actually
-- drops it, the weakness is only for anything the engine takes away behind us.
local rollers = setmetatable({}, { __mode = "k" })

local function TrackRoller(ent)
	if not (IsValid(ent) and ent:GetClass() == ROLLERMINE) then return end

	rollers[ent] = true
	ent:CallOnRemove("zcnpc_hl2_roller", function(e)
		rollers[e] = nil
		shocked[e] = nil
	end)
end

hook.Add("OnEntityCreated", "zcnpc_hl2_rollers", function(ent)
	-- npc_rollermine is an NPC. A timer per casing was the rest of the map.
	if not (IsValid(ent) and ent:IsNPC()) then return end

	timer.Simple(0, function() TrackRoller(ent) end)
end)

local function ScanRollers()
	for roller in pairs(rollers) do
		if not IsValid(roller) then
			rollers[roller] = nil
			shocked[roller] = nil
		end
	end

	for _, ent in ipairs(ents.FindByClass(ROLLERMINE)) do
		TrackRoller(ent)
	end
end

hook.Add("InitPostEntity", "zcnpc_hl2_rollers", ScanRollers)
hook.Add("PostCleanupMap", "zcnpc_hl2_rollers", ScanRollers)
hook.Add("HomigradRun", "zcnpc_hl2_rollers", function()
	timer.Simple(0, ScanRollers)
end)

ScanRollers()

-- The mine's own shock, in the one case it lands: somebody on their feet that it reached
-- before the sweep below did. Everything Z-City does with it afterwards is already
-- right, so the only thing said here is what it was worth - and the cooldown is claimed
-- on the way past, so the two paths are one attack rather than two doses of the same one.
ZCNPC.BeforeDamage.hl2_rollermines = function(ent, dmgInfo)
	if not cfg.hl2_rollermines:GetBool() then return end
	if not dmgInfo:IsDamageType(DMG_SHOCK) then return end
	if not ent.organism then return end

	local attacker = dmgInfo:GetAttacker()
	if not (IsValid(attacker) and attacker:GetClass() == ROLLERMINE) then return end

	shocked[attacker] = math.max(shocked[attacker] or 0, CurTime() + ROLLER_COOLDOWN)

	local pain = cfg.hl2_rollermine_pain:GetFloat()

	-- Raised, never lowered. A mine that has been turned up by another addon, or a
	-- map that hands out a harder one, is not something to quietly undo. This is also
	-- what makes the sweep's own shock pass straight through here untouched.
	if dmgInfo:GetDamage() >= pain then return end

	dmgInfo:SetDamage(pain)
end

-- Whose body this is, so the mine can be asked whether it wants to shock them. A
-- player's own ragdoll answers through Z-City, one of ours answers through the NPC
-- still hidden underneath it, and anything else on the floor is scenery.
local function Behind(rag)
	local owner = isfunction(hg.RagdollOwner) and hg.RagdollOwner(rag)
	if IsValid(owner) then return owner end

	local npc = rag.zcnpc_npc

	return IsValid(npc) and npc or nil
end

-- A rollermine somebody has hacked with the gravity gun is friendly and stays
-- friendly here too, so a body on the floor is only shocked by a mine that would
-- have gone for the person standing up.
--
-- Asked the other way round - who it likes rather than who it hates - because a mine
-- has an opinion about far fewer things than it will happily roll into. D_HT is what
-- it says about a class it has a line for; a hidden NPC in godmode, or anything an
-- addon spawned that the AI relationship table has never heard of, comes back D_ER,
-- and reading that as "leave them alone" is most of why a mine would shock nobody at
-- all. A hacked mine is D_LI towards the player and a Combine mine is D_LI towards
-- Combine, which is the whole of what needs protecting.
local function Hostile(roller, person)
	if not isfunction(roller.Disposition) then return true end

	return roller:Disposition(person) ~= D_LI
end

-- How close the mine is to the body rather than to the entity's origin. A ragdoll's
-- origin is its pelvis and a standing player's is between their feet, so a mine resting
-- against somebody's chest was being measured to a point most of a body away and coming
-- back out of range.
local function Reach(ent, pos)
	if ent:IsRagdoll() then
		local count = ent:GetPhysicsObjectCount() or 0
		local best = math.huge

		for i = 0, count - 1 do
			local phys = ent:GetPhysicsObjectNum(i)

			if IsValid(phys) then
				best = math.min(best, pos:DistToSqr(phys:GetPos()))
			end
		end

		if best < math.huge then return math.sqrt(best) end
	end

	return pos:Distance(ent:NearestPoint(pos))
end

-- A mine on the floor above is within arm's reach of somebody's head through six inches
-- of concrete, and the sphere has no opinion about walls. Only world geometry is asked
-- about: everything else that could be in the way - a body, a chair, another mine - is
-- something a rollermine climbs over on its way to you anyway.
local function Blocked(pos, ent)
	return util.TraceLine({
		start = pos,
		endpos = ent:WorldSpaceCenter(),
		mask = MASK_SOLID_BRUSHONLY,
	}).Hit
end

-- Who the mine has found, and which of the three ways of being shocked applies to
-- them. A body on the floor already holds its organism and is shocked where it lies;
-- anybody still on their feet has to be put down first, and Z-City does that for a
-- player while this addon does it for an NPC.
-- Prefixed because PLAYER and NPC are both taken at global scope, and a local by
-- either name would quietly shadow a metatable for the rest of the file.
local KIND_BODY, KIND_PLAYER, KIND_NPC = "body", "player", "npc"

local function Kind(ent)
	if ent:IsRagdoll() then
		local org = ent.organism

		return org and KIND_BODY or nil, org
	end

	if ent:IsPlayer() then
		-- Already down is already answered: the ragdoll they are parked inside is in
		-- this same sphere and is the thing actually worth shocking.
		if IsValid(ent.FakeRagdoll) or not ent:Alive() then return end

		return KIND_PLAYER, ent.organism
	end

	if not ent:IsNPC() then return end
	if ZCNPC.IsZombie(ent) then return end
	if IsValid(ent.zcnpc_rag) then return end -- down already, under a body in this sphere

	return KIND_NPC, ZCNPC.ResolveOrganism(ent)
end

-- DMG_SHOCK is a type the organism already understands and already handles the way
-- electricity should be handled - all of it as pain and shock, almost none of it as
-- blood (sv_input.lua:1179) - so there is nothing to invent here. The inflictor is set
-- for a reason: one branch further down that same function asks the inflictor for its
-- class without checking it exists.
local function Hurt(roller, target, pos)
	local dmg = DamageInfo()
	dmg:SetDamage(cfg.hl2_rollermine_pain:GetFloat())
	dmg:SetAttacker(roller)
	dmg:SetInflictor(roller)
	dmg:SetDamageType(DMG_SHOCK)
	dmg:SetDamagePosition(pos)
	dmg:SetDamageForce(vector_origin)

	target:TakeDamageInfo(dmg)
end

local function Arc(roller, pos)
	roller:EmitSound("NPC_RollerMine.Shock")

	local spark = EffectData()
	spark:SetOrigin(pos)
	spark:SetNormal(vector_up)
	spark:SetMagnitude(2)
	spark:SetScale(1)
	util.Effect("Sparks", spark)
end

-- org.stun is what a tasered player is held down by (hg.StunPlayer) and one of the
-- things our own wake up check reads, so a body under current stays where it is instead
-- of trying to stand up between jolts. org.tasered is the convulsion itself.
local function Held(org, time)
	if not org then return end

	org.stun = math.max(org.stun or 0, CurTime() + time)
	org.tasered = CurTime() + time
end

local function Shock(roller, ent, kind, org)
	local pos = kind == KIND_BODY and ent:WorldSpaceCenter() or ent:NearestPoint(roller:WorldSpaceCenter())

	Arc(roller, pos)
	Hurt(roller, ent, pos)

	local down = cfg.hl2_rollermine_stun:GetFloat()
	local time = math.max(down, SHOCK_TIME)

	if kind == KIND_BODY then
		Held(org, time)
		ZCNPC.Electrify(ent, time)

		return
	end

	-- Nothing below this line is a knockdown anybody asked for.
	if down <= 0 then return end

	if kind == KIND_PLAYER then
		-- Z-City's own way of putting a player on the floor, prongs or otherwise: it
		-- builds the ragdoll if there is not one yet and sets the hold itself
		-- (sv_util.lua:507).
		if isfunction(hg.StunPlayer) then hg.StunPlayer(ent, time) end

		Held(ent.organism, time)
		ZCNPC.Electrify(ent.FakeRagdoll, time)

		return
	end

	-- Deferred for the same reason everything else that puts an NPC down out of a
	-- damage path is, and because the shock above may have put it down already.
	timer.Simple(0, function()
		if not IsValid(ent) then return end

		local rag = ZCNPC.MakeUnconscious(ent, time)
		if not IsValid(rag) then return end

		Held(rag.organism or org, time)
		ZCNPC.Electrify(rag, time)
	end)
end

timer.Create("zcnpc_hl2_rollermines", 0.2, 0, function()
	if not (ZCNPC.Enabled() and cfg.hl2_rollermines:GetBool()) then return end
	if not next(rollers) then return end

	-- Everybody the organism already knows about: standing NPCs, players, and
	-- the bodies they are parked inside. FindInSphere would hand back every
	-- crate and spent shell in a body-length radius, once per mine.
	local people = istable(hg) and istable(hg.organism) and hg.organism.list
	if not people then return end

	local now = CurTime()

	for roller in pairs(rollers) do
		if not IsValid(roller) then
			rollers[roller] = nil
			shocked[roller] = nil

			continue
		end

		if (shocked[roller] or 0) > now then continue end

		-- A mine in somebody's hands is a mine they are carrying, not one that is
		-- attacking them, and the gravity gun is how you are meant to deal with these.
		if roller:IsPlayerHolding() then continue end

		local center = roller:WorldSpaceCenter()

		for ent in pairs(people) do
			if not IsValid(ent) or ent == roller then continue end
			if center:DistToSqr(ent:GetPos()) >= ROLLER_SEARCH_SQR then continue end

			local kind, org = Kind(ent)
			if not (kind and org and org.alive ~= false) then continue end
			if Reach(ent, center) > ROLLER_REACH then continue end

			local person = kind == KIND_BODY and Behind(ent) or ent
			if not (IsValid(person) and Hostile(roller, person)) then continue end
			if Blocked(center, ent) then continue end

			shocked[roller] = now + ROLLER_COOLDOWN
			Shock(roller, ent, kind, org)

			break
		end
	end
end)

--//

--\\ Barnacles
-- A barnacle picks you up and chews, and nothing happens, forever. The grab is fine -
-- the tongue finds prey with a box query down the column under it and filters on
-- almost nothing, so a Z-City player is as grabbable as any other - and so is the
-- lift. It is the bite that goes nowhere.
--
-- BitePrey deals DMG_SLASH + DMG_ALWAYSGIB and then ors DMG_CRUSH into it, with a
-- comment saying why: crush is the type that carries no physics force, and a barnacle
-- does not want to punch what it is holding. Z-City reads that or the wrong way round.
-- DMG_CRUSH is refused nine lines into the damage handler (sv_input.lua:487) - it
-- returns true, which is also "handled, take nothing off the engine either" - so the
-- bite is dropped twice over and the victim is left on exactly the health they had.
-- And a barnacle only lets a player go once that health reaches zero, so it never
-- does: it holds you upside down and bites, indefinitely.
--
-- Retyped rather than re-dealt, the same way the darts above are, so the barnacle
-- keeps every other thing it decides - when it bites, how often, when it swallows,
-- when it lets go.
local BARNACLE = "npc_barnacle"

-- The barnacle itself, because where it is is the direction of the bite. It builds
-- its damage with itself as both attacker and inflictor, so either will do and both
-- are asked in case another addon has been through the same code.
local function Barnacle(dmgInfo)
	local attacker = dmgInfo:GetAttacker()
	if IsValid(attacker) and attacker:GetClass() == BARNACLE then return attacker end

	local inflictor = dmgInfo:GetInflictor()

	return IsValid(inflictor) and inflictor:GetClass() == BARNACLE and inflictor or nil
end

-- Small on purpose. DMG_CRUSH was on the bite so that the barnacle would not throw
-- what it is holding, and that much of it was right; the force here is only what the
-- wound needs to know which way the mouth was.
local BARNACLE_FORCE = 60
local BARNACLE_STANDOFF = 24 -- far enough back along the bite to start outside the body

ZCNPC.BeforeDamage.hl2_barnacles = function(ent, dmgInfo)
	if not cfg.hl2_barnacles:GetBool() then return end
	if not dmgInfo:IsDamageType(DMG_CRUSH) then return end
	if not ent.organism then return end

	local barnacle = Barnacle(dmgInfo)
	if not barnacle then return end

	-- Set outright rather than ored into what is there, because what is there is the
	-- whole of the problem: DMG_CRUSH is why the organism never hears this, and
	-- DMG_ALWAYSGIB alongside it is a barnacle asking for a body in pieces on a hit
	-- it means to survive long enough to swallow.
	dmgInfo:SetDamageType(DMG_SLASH)

	-- One bite is one bite, whoever is in the tongue. Half-Life 2 charges a player 15
	-- and everything else every point it has left in a single go, because an NPC in a
	-- barnacle is scenery being cleaned up; here there is a body underneath either
	-- way and it can be left to decide how many bites it has in it.
	dmgInfo:SetDamage(cfg.hl2_barnacle_bite:GetFloat())

	-- A barnacle builds its damage with neither a position nor a force, and a wound
	-- needs both: the force is what the organism takes its direction from - it sets it,
	-- normalises it and traces the hole along it (sv_input.lua:579) - and the position
	-- is where that trace starts. Left as they came, the trace is zero long from the
	-- middle of the body outwards and finds nothing to wound.
	--
	-- A barnacle is always above what it is eating, so the bite runs from the mouth
	-- down into the body, and it starts a little short of the body so that the trace
	-- arrives at the surface the way a shot from outside would.
	local center = ent:WorldSpaceCenter()
	local dir = center - barnacle:WorldSpaceCenter()

	dir = dir:IsZero() and -vector_up or dir:GetNormalized()

	dmgInfo:SetDamagePosition(center - dir * BARNACLE_STANDOFF)
	dmgInfo:SetDamageForce(dir * BARNACLE_FORCE)
end
--//

--\\ One pass over everything that leaves the map
-- EntityRemoved fires for every entity on the server and both halves of this file
-- want it, so they share the one handler rather than paying the dispatch twice.
hook.Add("EntityRemoved", "zcnpc_hl2", function(ent, fullUpdate)
	shocked[ent] = nil

	Detonated(ent, fullUpdate)
end)
--//
