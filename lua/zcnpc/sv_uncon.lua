--[[
	Unconsciousness for NPCs.

	Stock Z-City kills an NPC with 10000 damage the moment its organism
	demands a knockout ("needfake", see z_city .. organism/tier_1/sv_organism.lua:528).
	We intercept exactly that kill, put the NPC into a real unconscious
	ragdoll instead (like players), let medics treat it, let it wake up,
	and only turn it into a corpse when the organism actually dies.
]]

local cfg = ZCNPC.Config

ZCNPC.Downed = ZCNPC.Downed or {} -- [ragdoll] = info

-- Every husk this file has put GODMODE on, so that it can be taken off again by
-- somebody other than the code path that was supposed to. GODMODE is total - shoot
-- it, kick it, set it on fire and nothing happens - so one left behind is an NPC
-- nobody can touch for the rest of the round, and "sometimes" is the word that comes
-- back about it every time, because it takes an unusual way out of a knockdown to
-- leave one: a body removed by a cleanup, an addon that took the ragdoll, a wake-up
-- that threw part way through.
--
-- Ours only. An admin tool or a map may have set the flag on an NPC for reasons of
-- its own and taking that off would be this deciding something it was never asked
-- about, which is the same line sv_head.lua draws around its own hold.
--
-- Weak keys: an NPC that is gone takes its entry with it.
ZCNPC.Godded = ZCNPC.Godded or setmetatable({}, { __mode = "k" })

local function HoldGod(npc)
	npc:AddFlags(FL_GODMODE)
	ZCNPC.Godded[npc] = true
end

-- notarget: cleared alongside it everywhere the two were set together.
local function ReleaseGod(npc, notarget)
	ZCNPC.Godded[npc] = nil

	if not IsValid(npc) then return end

	npc:RemoveFlags(notarget and (FL_NOTARGET + FL_GODMODE) or FL_GODMODE)
end

ZCNPC.HoldGod = HoldGod
ZCNPC.ReleaseGod = ReleaseGod

-- The husk sits in IN_VEHICLE / MOVETYPE_NONE. Putting those back on a
-- standing NPC is walking through them. MOVETYPE_NONE also drops the hull:
-- STEP alone does not rebuild it, SOLID_BBOX does.
local HUSK_GROUP = {
	[COLLISION_GROUP_IN_VEHICLE] = true,
	[COLLISION_GROUP_DEBRIS] = true,
	[COLLISION_GROUP_DEBRIS_TRIGGER] = true,
	[COLLISION_GROUP_WEAPON] = true,
	[COLLISION_GROUP_WORLD] = true,
}

local HUSK_MOVE = {
	[MOVETYPE_NONE] = true,
	[MOVETYPE_NOCLIP] = true,
}

function ZCNPC.RestoreStanding(npc, info)
	if not (IsValid(npc) and npc:IsNPC()) then return end

	local group = info and info.colgroup
	if group == nil or HUSK_GROUP[group] then
		group = COLLISION_GROUP_NPC
	end

	local move = info and info.movetype
	if move == nil or HUSK_MOVE[move] then
		move = MOVETYPE_STEP
	end

	npc:SetSolid(SOLID_BBOX)
	npc:SetMoveType(move)
	npc:SetCollisionGroup(group)
end

util.AddNetworkString("zcnpc_body")

-- Tells clients which body an NPC is currently lying as, so Z-City's client side
-- bleeding follows the body instead of staying with the hidden NPC. See cl_body.lua.
--
-- getup says an animation is on its way, and it is here rather than in the get up
-- message itself because of when the two arrive. Showing the NPC entity has to
-- come before anything can be said about it, so there is a moment where an NPC is
-- standing next to the body it has not climbed out of yet. This is the earliest
-- anybody can be told that moment is coming.
local function SyncBody(npc, rag, down, getup)
	if not IsValid(npc) then return end
	if down and not IsValid(rag) then return end

	-- The same pairing on the body itself, because the message below is said once
	-- and to everybody at once. Anybody who was not there to hear it - a player who
	-- connected afterwards, or one on the far side of the map, where neither entity
	-- exists to be paired with the other - reads it off the body instead, the first
	-- time they can see the body at all (cl_body.lua). Without it their Z-City draws
	-- the gun on the hand of the hidden NPC, which is the rifle hanging in the air
	-- over a body on the floor.
	if IsValid(rag) then rag:SetNWEntity("zcnpc_npc", down and npc or NULL) end

	net.Start("zcnpc_body")
		net.WriteBool(down)
		net.WriteUInt(npc:EntIndex(), 16)
		net.WriteUInt(IsValid(rag) and rag:EntIndex() or 0, 16)
		net.WriteBool(getup or false)
	net.Broadcast()
end

ZCNPC.SyncBody = SyncBody

function ZCNPC.ShowWeapon(npc)
	if not IsValid(npc) then return end

	local wep = npc:GetActiveWeapon()
	if IsValid(wep) then wep:SetNoDraw(false) end
end

function ZCNPC.HideWeapon(npc)
	if not IsValid(npc) then return end

	local wep = npc:GetActiveWeapon()
	if IsValid(wep) then wep:SetNoDraw(true) end
end

--\\ Ragdoll creation (simplified NPC version of hg.Ragdoll_Create)
-- HL2 NPCs often report Entity:GetVelocity() near zero while sprinting - the real
-- move speed lives in ground locomotion. Bullet damage, meanwhile, inflates
-- GetVelocity() into a launch. Headshots must read loco; kicks still use the
-- entity velocity plus their shove.
local HEADKILL_INERTIA = 0.75 -- horizontal leftover from a run, not the bullet punch
local HEADKILL_DROP = 320 -- standing pose + no Z speed was the slow-mo crumple

local function LocoVelocity(npc)
	if npc.GetGroundSpeedVelocity then
		local loco = npc:GetGroundSpeedVelocity()
		if isvector(loco) and loco:LengthSqr() > 1 then return loco end
	end

	if npc.GetCurrentSpeed then
		local speed = npc:GetCurrentSpeed()
		if isnumber(speed) and speed > 1 then
			local dir = npc:GetAngles():Forward()
			dir.z = 0
			if dir:LengthSqr() > 0.01 then
				dir:Normalize()

				return dir * speed
			end
		end
	end

	-- Last resort: entity velocity, but never punch-scale leftovers.
	local vel = npc:GetVelocity()
	local maxKeep = 320
	local speed = vel:Length()
	if speed > maxKeep then vel = vel * (maxKeep / speed) end

	return vel
end

local function CreateNPCRagdoll(npc, addVel)
	local mdl = ZCNPC.ResolveNPCModel(npc)
	if not isstring(mdl) or mdl == "" then return end

	-- Only pin a stock HL2 mesh on the NPC itself. A custom class with an
	-- empty GetModel still gets a ragdoll (the fallback path), but writing
	-- male_07 onto the living entity is how workshop SNPCs vanished.
	-- Never touch a ZBase mesh: that spawn is mid-flight or already custom.
	local have = isfunction(npc.GetModel) and npc:GetModel() or nil
	local class = isfunction(npc.GetClass) and npc:GetClass() or ""
	if (not isstring(have) or have == "") and isfunction(npc.SetModel)
		and cfg.ClassModels and cfg.ClassModels[class]
		and not (ZCNPC.IsZBaseNPC and ZCNPC.IsZBaseNPC(npc))
	then
		npc:SetModel(mdl)
	end

	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end

	rag:SetModel(mdl)
	rag:SetPos(npc:GetPos())
	rag:SetAngles(npc:GetAngles())
	rag:SetSkin(npc:GetSkin() or 0)
	rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	rag:Spawn()
	rag:Activate()

	if rag:GetPhysicsObjectCount() <= 1 then -- model has no ragdoll physics
		rag:Remove()
		return
	end

	rag:AddEFlags(EFL_NO_DAMAGE_FORCES + EFL_DONTBLOCKLOS)
	rag.zcnpc_npcbody = true
	rag.zcnpc_keepbody = true

	for _, bg in ipairs(npc:GetBodyGroups() or {}) do
		rag:SetBodygroup(bg.id, npc:GetBodygroup(bg.id))
	end

	hg.cacheModel(rag)

	-- Z-City's "Ragdoll Collide" -> fall/impact sounds. Queued out of the physics
	-- callback: impact damage on an organism body reaches every knockdown, gib,
	-- loot drop and ArtAgdoll hand-over, and building or tearing down physics
	-- objects while the engine walks its contact list is a hard crash.
	rag:AddCallback("PhysicsCollide", function(_, data)
		local pending = rag.zcnpc_collides
		if pending then
			pending[#pending + 1] = data
			return
		end

		rag.zcnpc_collides = { data }
		timer.Simple(0, function()
			if not IsValid(rag) then return end

			local list = rag.zcnpc_collides
			rag.zcnpc_collides = nil

			for _, d in ipairs(list) do
				if not IsValid(rag) then return end
				if IsValid(d.PhysObject) and IsValid(d.HitObject) then
					hook.Run("Ragdoll Collide", rag, d)
				end
			end
		end)
	end)

	local velocity
	if npc.zcnpc_headkill then
		-- Loco XY only. Z-City's bullet punch lives in GetVelocity and is what
		-- launched these; StarveHeadPunch already took DamageForce off. A
		-- standing pose with z clamped near zero is a statue that folds over
		-- a second — the slow-mo headshot fall.
		velocity = LocoVelocity(npc) * HEADKILL_INERTIA
		velocity.z = math.min(velocity.z, -HEADKILL_DROP)
	else
		velocity = npc:GetVelocity()
	end
	velocity = velocity + (addVel or vector_origin)

	for physNum = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(physNum)
		if not IsValid(phys) then continue end

		local bone = rag:TranslatePhysBoneToBone(physNum)
		if bone and bone >= 0 then
			local matrix = npc:GetBoneMatrix(bone)
			if matrix then
				phys:SetPos(matrix:GetTranslation())
				phys:SetAngles(matrix:GetAngles())
			end
			phys:SetMass(hg.IdealMassPlayer[rag:GetBoneName(bone)] or 4)
		end

		phys:SetVelocity(velocity)
		phys:Wake()
	end

	return rag
end
--//

--\\ Organism transfer helpers
local function MoveOrganism(from, to)
	local org = from.organism
	if not org then return end

	to.organism = org
	org.owner = to
	hg.organism.list[to] = org
	hg.organism.list[from] = nil
	from.organism = nil

	-- Whatever the modules would have said to a player about this body, they say to
	-- whichever half is holding it now (ZCNPC.Silence)
	ZCNPC.Silence(to)

	zb.net.list[to] = zb.net.list[to] or {}
	table.Merge(zb.net.list[to], zb.net.list[from] or {})

	to:SetNetVar("wounds", org.wounds or {})
	to:SetNetVar("arterialwounds", org.arterialwounds or {})

	to.fullsend = true
	hg.send_bareinfo(org)

	return org
end

-- Dressings are not part of the organism. Z-City keeps them in a field on the
-- entity that was treated with a NetVar mirroring it to the client, which draws
-- them (weapon_bandage_sh.lua:1077, :977) - so they stay behind on whichever half
-- of the NPC the medic was working on. Treat a body on the ground, stand the NPC
-- up, and every bandage on it is gone. Z-City has the same problem with players
-- and solves it by copying both across whenever one becomes the other
-- (weapon_bandage_sh.lua:897); this is that copy, in both directions.
local dressings = {
	{ field = "bandaged_limbs", netvar = "bandaged_limbs" },
	{ field = "tourniquets", netvar = "Tourniquets" },
}

function ZCNPC.MoveDressings(from, to)
	if not (IsValid(from) and IsValid(to)) then return end

	for _, dressing in ipairs(dressings) do
		local worn = from[dressing.field]

		to[dressing.field] = worn
		to:SetNetVar(dressing.netvar, worn or {})

		from[dressing.field] = nil
		from:SetNetVar(dressing.netvar, {})
	end
end
--//

--\\ Going down
-- downFor (optional): minimum seconds on the ground before a wake up attempt,
--   defaults to the zcnpc_wakeup_time convar. Used by leg kicks for short knockdowns.
-- addVel (optional): extra velocity for the falling body (kick/shove impulse).
-- allowDead (optional): lay down an NPC whose organism already wrote alive=false.
function ZCNPC.MakeUnconscious(npc, downFor, addVel, allowDead)
	if not IsValid(npc) or not npc:IsNPC() then return end
	-- Nothing downstream of here means anything on a zombie, and something else
	-- may well have handed it an organism. This is the gate for all of it: being
	-- laid on the floor is the door every other part of the addon comes through.
	if ZCNPC.IsZombie(npc) then return end

	if IsValid(npc.zcnpc_rag) then
		-- already down: a shorter request must not shorten an existing knockout,
		-- but a knockout request may extend a short kick-down
		local info = ZCNPC.Downed[npc.zcnpc_rag]
		if info then
			local wanted = downFor or cfg.wakeup_time:GetFloat()
			info.wakeAfter = math.max(info.wakeAfter or 0, wanted)
		end

		local org = npc.zcnpc_rag.organism
		if org then org.zcnpc_pendingdown = nil end -- don't leave the kill-intercept latch armed

		return npc.zcnpc_rag
	end

	local org = npc.organism
	if not org then return end
	-- allowDead: lungs already wrote alive=false on a standing NPC (cardiac
	-- arrest that finished the brain before they hit the floor). The usual
	-- gate would leave them walking around dead.
	if org.alive == false and not allowDead then return end

	local rag = CreateNPCRagdoll(npc, addVel)
	if not IsValid(rag) then return end

	org.zcnpc_pendingdown = nil
	MoveOrganism(npc, rag)
	ZCNPC.MoveDressings(npc, rag)

	rag:CallOnRemove("zcnpc_organism", hg.organism.Remove, rag)
	rag.FakeRagdoll = rag -- some Z-City medicine checks org.owner.FakeRagdoll (e.g. painkillers)
	rag:SetNWString("PlayerName", npc:GetNWString("PlayerName"))
	rag:SetNWVector("PlayerColor", npc:GetNWVector("PlayerColor"))

	-- Armour keeps protecting the body; NetVar must follow or the client never
	-- draws the props (Z-City's npcloot only copies the Lua table).
	if ZCNPC.TransferArmor then
		ZCNPC.TransferArmor(npc, rag)
	else
		rag.armors = npc.armors
		if istable(npc.armors) then
			if rag.SyncArmor then
				rag:SyncArmor()
			else
				rag:SetNetVar("Armor", npc.armors)
			end
		end
	end

	local info = {
		npc = npc,
		class = npc:GetClass(),
		downAt = CurTime(),
		wakeAfter = downFor or cfg.wakeup_time:GetFloat(),
		colgroup = npc:GetCollisionGroup(),
		movetype = npc:GetMoveType(),
	}
	ZCNPC.Downed[rag] = info
	npc.zcnpc_rag = rag
	rag.zcnpc_npc = npc

	-- hide and freeze the NPC while its body lies on the ground.
	-- GODMODE always: the husk must not die the engine way. FL_NOTARGET only
	-- while unconscious — conscious bodies stay finishable (sv_execute.lua).
	npc:SetNoDraw(true)
	npc:DrawShadow(false)
	HoldGod(npc)
	npc:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	npc:SetMoveType(MOVETYPE_NONE)
	npc:SetNPCState(NPC_STATE_NONE)
	npc:StopMoving()
	if npc.ClearEnemyMemory then npc:ClearEnemyMemory() end

	if ZCNPC.UpdateDownedTargetable then
		ZCNPC.UpdateDownedTargetable(rag, info)
	else
		npc:AddFlags(FL_NOTARGET)
	end

	local wep = npc:GetActiveWeapon()
	if IsValid(wep) then wep:SetNoDraw(true) end

	-- Fire belongs on the body now. Leaving it on the hidden entity is a second
	-- ignition source under the ragdoll, and Artagdoll only sees the doll.
	if npc:IsOnFire() then
		npc:Extinguish()
		rag:Ignite(math.Rand(8, 15))
	end

	rag:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(6) .. ".wav", 60, math.random(90, 105))

	SyncBody(npc, rag, true)

	if ZCNPC.FlushVoice then ZCNPC.FlushVoice(npc, rag) end

	ZCNPC.Debug("downed", npc, info.class)
	hook.Run("ZCNPC_Downed", npc, rag, org)

	return rag
end

-- Knocked off its feet, which is not the same thing as knocked out. The body goes
-- down exactly the same way - it is the only way an NPC can be on the floor at all
-- - but nothing is done to the organism, so there is still somebody inside it: it
-- squirms, it holds on to its gun, and the monitor stands it up again as soon as
-- the short timer is out and nothing else is keeping it there. If the hit that
-- floored it did enough damage to knock it out on its own, that is the organism's
-- call to make and it stays down.
function ZCNPC.Floor(npc, downFor, shove)
	return ZCNPC.MakeUnconscious(npc, downFor or cfg.knockdown_time:GetFloat(), shove)
end

-- True while the NPC entity is the hidden half of a body on the ground. That
-- entity must never take damage or leave an engine death ragdoll - the body is
-- the only corpse there is.
function ZCNPC.IsHidden(npc)
	return IsValid(npc) and npc:IsNPC() and IsValid(npc.zcnpc_rag)
end

-- GODMODE alone is not enough once bodies are forced to collide with NPCs: a
-- falling player can still put crush through, and anything that slips past and
-- kills the entity spawns a second ragdoll on top of ours. Swallow husk hits
-- that were not redirected onto the body (sv_execute.lua), and if an engine
-- corpse still appears, throw it away.
hook.Add("EntityTakeDamage", "zcnpc_hidden_immortal", function(ent, dmgInfo)
	if not ZCNPC.IsHidden(ent) then return end

	-- Conscious finish-off: leave damage for zcnpc_execute_redirect (same hook).
	local rag = ent.zcnpc_rag
	if ZCNPC.IsDownedTargetable and ZCNPC.IsDownedTargetable(rag) then
		return
	end

	dmgInfo:SetDamage(0)
	dmgInfo:SetDamageForce(vector_origin)

	return true
end)

hook.Add("ScaleNPCDamage", "zcnpc_hidden_immortal", function(npc, _, dmgInfo)
	if not ZCNPC.IsHidden(npc) then return end

	local rag = npc.zcnpc_rag
	if ZCNPC.IsDownedTargetable and ZCNPC.IsDownedTargetable(rag) then
		return
	end

	dmgInfo:SetDamage(0)
end)

hook.Add("CreateEntityRagdoll", "zcnpc_hidden_noragdoll", function(ent, rag)
	if not (ZCNPC.Enabled() and IsValid(rag)) then return end
	if ZCNPC.DropEngineRagdoll and ZCNPC.DropEngineRagdoll(ent, rag) then return end
	if not ZCNPC.IsHidden(ent) then return end

	local ours = ent.zcnpc_rag
	if rag == ours then return end

	-- Same-frame remove races the engine still wiring the corpse up; next tick
	-- is enough and matches the headshot duplicate cleanup in sv_head.lua.
	rag.zcnpc_drop = true
	timer.Simple(0, function()
		if IsValid(rag) and rag ~= ours then rag:Remove() end
	end)
end)
--//

--\\ Speed limit for bodies
-- Every push a body takes turns into speed by way of the mass it lands on, and some
-- of the masses involved are not chosen with that in mind: Z-City drops a severed
-- part to a tenth of a kilo (headgib/init_sv.lua:14), so anything still aimed at a
-- head that has already come off is dividing by almost nothing. Spin is the same
-- story and it is the louder half of it - a spinning bone drags the next one through
-- the joint, that one drags the spine, and the whole body cartwheels off across the
-- map, which is why a push landing on one of the light bones can throw everything.
--
-- Rather than chase every push - and there are a lot of them, across three addons,
-- half of which are somebody else's to change - nothing on a body of ours is allowed
-- to travel or turn faster than a body plausibly can. A ragdoll thrown by an
-- explosion moves at a few hundred units a second and a body tumbling downhill turns
-- at a few hundred degrees, so the defaults leave every real impulse untouched and
-- only ever catch the absurd ones.
--
-- The other thing that goes wrong here does not need a threshold at all. Divide by
-- a zero mass, or push something that is already at infinity, and what comes back
-- is NaN - and NaN compares false against everything, so it slips past every limit
-- written as a comparison, spreads through the joints to the rest of the ragdoll
-- within a tick or two, and leaves a body that is nowhere and cannot be rendered.
-- It has to be tested for on its own terms, which is the one value not equal to
-- itself.
local function Sane(v)
	return v.x == v.x and v.y == v.y and v.z == v.z
		and math.abs(v.x) ~= math.huge and math.abs(v.y) ~= math.huge and math.abs(v.z) ~= math.huge
end

local function ClampBody(rag, maxSpeed, maxSpin)
	local maxSqr = maxSpeed * maxSpeed
	local spinSqr = maxSpin * maxSpin

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		-- a body that has settled is the usual case and costs nothing to skip
		if not IsValid(phys) or phys:IsAsleep() then continue end

		local vel = phys:GetVelocity()
		local spin = phys:GetAngleVelocity()

		-- Nothing to salvage out of a broken number, so the bone is simply stopped
		-- where it is. Stopping it before it has been passed on through a joint is
		-- what keeps the rest of the body out of it.
		if not (Sane(vel) and Sane(spin) and Sane(phys:GetPos())) then
			phys:SetVelocityInstantaneous(vector_origin)
			phys:AddAngleVelocity(-spin)
			phys:Sleep()
			continue
		end

		if maxSpeed > 0 then
			local speedSqr = vel:LengthSqr()
			if speedSqr > maxSqr then phys:SetVelocity(vel / math.sqrt(speedSqr) * maxSpeed) end
		end

		-- there is no setter for angular velocity, only an adder, so the excess is
		-- subtracted back off
		if maxSpin > 0 then
			local turnSqr = spin:LengthSqr()
			if turnSqr > spinSqr then
				phys:AddAngleVelocity(spin * (maxSpin / math.sqrt(turnSqr) - 1))
			end
		end
	end
end

ZCNPC.Ragdolls = ZCNPC.Ragdolls or {} -- [ragdoll] = true, every NPC body in the world

-- Bodies that need their speed watched right now. Walking every physics bone of
-- every corpse every tick is what made three or four kills hitch the server -
-- most of those bodies are asleep on the floor and have nothing left to clamp.
-- Mark a body hot when something disturbs it; after a few seconds of stillness
-- it drops out of the Think loop and only the registry keeps it.
ZCNPC.HotBodies = ZCNPC.HotBodies or {}

local WATCH_TIME = 4

function ZCNPC.WatchBody(rag, seconds)
	if not IsValid(rag) then return end

	ZCNPC.Ragdolls[rag] = true

	-- Pellet spray used to rewrite HotBodies every hit and keep the Think clamp
	-- at full cost for the whole magazine. Only extend when the new window is
	-- meaningfully longer than what is already booked.
	local till = CurTime() + (seconds or WATCH_TIME)
	local cur = ZCNPC.HotBodies[rag]
	if cur and cur >= till - 0.25 then return end

	ZCNPC.HotBodies[rag] = till
end

-- Full clamp every Think while hot is correct for NaN, but a sustained spray does
-- not need every bone re-read on every frame - once per ~30ms is enough to catch
-- launches without changing how the body feels under normal impulses.
local nextBodyClamp = 0

hook.Add("Think", "zcnpc_bodyspeed", function()
	-- Most ticks there is nothing hot: a settled fight leaves corpses asleep and
	-- the registry alone. Bail before reading the convars.
	if not next(ZCNPC.HotBodies) then return end

	local now = CurTime()
	if now < nextBodyClamp then return end
	nextBodyClamp = now + 0.03

	-- Both limits at zero still walks the hot bodies, because the check for a
	-- broken number is in the same loop and is not one of the limits: a speed
	-- limit is a matter of taste and NaN is a body that has left the world.
	local maxSpeed = cfg.body_maxspeed:GetFloat()
	local maxSpin = cfg.body_maxspin:GetFloat()

	for rag, until_ in pairs(ZCNPC.HotBodies) do
		if not IsValid(rag) or until_ < now then
			ZCNPC.HotBodies[rag] = nil
			if not IsValid(rag) then ZCNPC.Ragdolls[rag] = nil end
		else
			-- Same clamp for every hot body. Headshot used to wipe velocity every
			-- tick via zcnpc_headfalltill (slow-mo fall); launch is capped once in
			-- sv_head.lua instead.
			ClampBody(rag, maxSpeed, maxSpin)
		end
	end
end)

hook.Add("ZCNPC_Downed", "zcnpc_bodyspeed", function(_, rag)
	ZCNPC.WatchBody(rag)
end)

-- Bodies that were never ours to lay down: an NPC that died on its feet leaves one
-- behind, and it is just as capable of having its head taken off.
hook.Add("CreateEntityRagdoll", "zcnpc_bodyspeed", function(owner, rag)
	if IsValid(owner) and owner:IsNPC() and IsValid(rag) then ZCNPC.WatchBody(rag) end
end)

-- A hit on a settled body can spin it again; put it back under the clamp for a
-- moment instead of leaving every corpse in the Think loop forever.
hook.Add("HomigradDamage", "zcnpc_bodyspeed", function(victim)
	if IsValid(victim) and victim:IsRagdoll() and ZCNPC.Ragdolls[victim] then
		ZCNPC.WatchBody(victim, 2)
	end
end)
--//

--\\ Intercepting Z-City's "unconscious NPC = 10000 damage" kill.
-- Same-name re-add replaces Z-City's hook entry in place, which keeps
-- ordering deterministic (a separate hook could run after theirs and
-- never see the damage - their hook returns a value for NPC victims).
local function KillSignature(ent, dmgInfo)
	local org = ent.organism
	return org ~= nil
		and org.needfake == true
		and ent:IsNPC()
		and dmgInfo:GetDamage() >= 9999
		and dmgInfo:GetAttacker() == ent
end

-- Anything that has to change a DamageInfo before Z-City reads it has to say so from
-- in here, because there is nowhere later to say it from. Z-City's handler is the
-- first one registered, so a second EntityTakeDamage hook always runs after it has
-- already decided; and "HomigradDamage" is only reached by damage that got past its
-- first few lines, which some types never do - DMG_DISSOLVE is dropped on sight
-- (sv_input.lua:427) and is the whole of what a hunter's darts deal.
--
-- Named, like a hook, so that a file refreshing itself replaces its own entry rather
-- than leaving the old one behind to run twice.
ZCNPC.BeforeDamage = ZCNPC.BeforeDamage or {}

-- Something else wrapping the hook entry (a debug tracer, another addon) must not
-- read as "Z-City put its hook back": wrapping that again stacks one of ours per
-- heal, each calling the next, until the stack runs out.
ZCNPC.OwnWrappers = ZCNPC.OwnWrappers or setmetatable({}, { __mode = "k" })

local function Unwrapped(fn)
	local seen = 0
	while ZCNPC.TraceOriginal and ZCNPC.TraceOriginal[fn] and seen < 16 do
		fn = ZCNPC.TraceOriginal[fn]
		seen = seen + 1
	end

	return fn
end

function ZCNPC.InstallDamageWrapper()
	local hooks = hook.GetTable()["EntityTakeDamage"]
	local orig = hooks and hooks["homigrad-damage"]
	if not orig or ZCNPC.OwnWrappers[Unwrapped(orig)] then return end

	ZCNPC.__orig = orig
	ZCNPC.__wrapper = function(ent, dmgInfo)
		if ZCNPC.Enabled() then
			for _, edit in pairs(ZCNPC.BeforeDamage) do edit(ent, dmgInfo) end
		end

		if ZCNPC.Enabled() and KillSignature(ent, dmgInfo) then
			local org = ent.organism
			if not org.zcnpc_pendingdown then
				org.zcnpc_pendingdown = true
				-- defer: this fires from inside Z-City's "Org Think" loop over
				-- hg.organism.list, mutating that table here is unsafe
				timer.Simple(0, function()
					if not IsValid(ent) then return end
					if not ZCNPC.MakeUnconscious(ent) and ent.organism then
						ent.organism.zcnpc_pendingdown = nil -- let the stock kill happen next time
					end
				end)
			end
			return true -- swallow the kill
		end

		return orig(ent, dmgInfo)
	end

	ZCNPC.OwnWrappers[ZCNPC.__wrapper] = true
	hook.Add("EntityTakeDamage", "homigrad-damage", ZCNPC.__wrapper)
	ZCNPC.Debug("damage wrapper installed")
end

ZCNPC.InstallDamageWrapper()
hook.Add("InitPostEntity", "zcnpc_wrapper", ZCNPC.InstallDamageWrapper)
hook.Add("HomigradRun", "zcnpc_wrapper", ZCNPC.InstallDamageWrapper)

-- Self-heal if Z-City re-registers its hook after a lua refresh. Was every
-- monitor tick (0.25s) and walked hook.GetTable each time — once every few
-- seconds is enough and identical in practice.
timer.Create("zcnpc_wrapper_heal", 5, 0, function()
	if ZCNPC.Enabled() then ZCNPC.InstallDamageWrapper() end
end)
--//

--\\ Waking up
-- A lying pelvis sits about ten units off the floor. Anything much higher is either
-- hanging from something or still in the air, and standing up from there puts the
-- NPC at whatever height GetUpPos invents - mid-fall, mid-grab, or mid-nothing.
local GROUND_REACH = 48
local MAX_MOVE = 200

local function PelvisPos(rag)
	local bone = rag.zcnpc_pelvis_bone
	if bone == nil then
		bone = rag:LookupBone("ValveBiped.Bip01_Pelvis") or false
		rag.zcnpc_pelvis_bone = bone
	end
	if not bone then return rag:WorldSpaceCenter() end

	local physBone = rag.zcnpc_pelvis_phys
	if physBone == nil then
		physBone = rag:TranslateBoneToPhysBone(bone)
		rag.zcnpc_pelvis_phys = physBone
	end

	local phys = physBone and physBone >= 0 and rag:GetPhysicsObjectNum(physBone)
	if IsValid(phys) then return phys:GetPos() end

	local matrix = rag:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end

	local pos = rag:GetBonePosition(bone)

	return isvector(pos) and pos or rag:WorldSpaceCenter()
end

local function OnTheGround(rag)
	local pelvis = PelvisPos(rag)
	local tr = util.TraceLine({
		start = pelvis,
		endpos = pelvis - vector_up * (GROUND_REACH + 8),
		mask = MASK_SOLID,
		filter = rag,
	})

	if not tr.Hit then return false end

	return (pelvis.z - tr.HitPos.z) <= GROUND_REACH
end

-- Entity:GetVelocity on a ragdoll is often nothing useful: the bones are what move.
-- The fastest awake bone is the honest answer, and a body whose every bone is asleep
-- is settled by definition.
local function MovingTooFast(rag)
	local maxSqr = MAX_MOVE * MAX_MOVE

	if rag:GetVelocity():LengthSqr() > maxSqr then return true end

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if not IsValid(phys) or phys:IsAsleep() then continue end
		if phys:GetVelocity():LengthSqr() > maxSqr then return true end
	end

	return false
end

-- Artagdoll will happily brace a body against a ledge or a wall and hold it there
-- with almost no velocity, which is exactly the case the speed check used to miss:
-- hanging still, then waking up into empty air.
local function HungUp(rag)
	if not (istable(ActiveRagdoll) and isfunction(ActiveRagdoll.Get)) then return false end

	local ar = ActiveRagdoll.Get(rag)
	if not ar then return false end

	local beh = ar.CurrentBehavior
	if beh == "falling" or beh == "wallstunt" then return true end
	if ar.ActiveLayers and ar.ActiveLayers.wallstunt then return true end

	local hold = ar.holdEnv
	if not hold then return false end

	local left, right = hold.left, hold.right

	return (left and left.grabbing) or (right and right.grabbing) or false
end

local function CanWakeUp(org, rag)
	if org.alive == false then return false end
	if org.otrub or org.fake then return false end
	if org.heartstop then return false end
	if (org.blood or 0) < 2900 then return false end
	if (org.consciousness or 1) <= 0.4 then return false end
	if ((org.stun or 0) - CurTime()) > 0 then return false end
	if ((org.lightstun or 0) - CurTime()) > 0 then return false end
	-- A headcrab on the face is not something you stand up under. Cleared only
	-- when the meal ends (or the body dies mid-way) in sv_headcrab.lua.
	if org.headcrabon then return false end
	if IsValid(rag) and rag:GetNetVar("headcrab") then return false end
	-- Still under. The drug takes consciousness by a route of its own
	-- (modules/sv_pain.lua:87) and it is slow, so for a few seconds after being
	-- darted an NPC is on the floor with every other reason to stand up and none
	-- of them the right answer.
	if ZCNPC.Sedated and ZCNPC.Sedated(org) then return false end
	if (org.spine1 or 0) >= hg.organism.fake_spine1 then return false end
	if (org.spine2 or 0) >= hg.organism.fake_spine2 then return false end
	if (org.spine3 or 0) >= hg.organism.fake_spine3 then return false end
	-- Hard Z-City failure only. The softer zcnpc_limb_threshold is for the limp
	-- and a one-shot knockdown — using it here meant a bandaged NPC (lleg 0.95)
	-- still counted as "both legs broken" and never stood up.
	if org.llegamputated or org.rlegamputated then return false end
	if (org.lleg or 0) >= 1 and (org.rleg or 0) >= 1 then return false end
	-- Burning: stay down until the flames are out. Fire lives on the body after
	-- MakeUnconscious moves it off the hidden NPC.
	if IsValid(rag) and rag:IsOnFire() then return false end

	-- Somebody has hold of him. A man being walked out of a doorway by his chest, or knelt
	-- over with a bandage, does not get to his feet halfway through - and he used to. What
	-- that looked like was one NPC standing up and walking off while another went on
	-- dragging the empty floor behind it, or a medic three seconds into a wrap with nobody
	-- left in front of it. Cleared the moment the rescue is finished with him, whichever
	-- way it finishes (sv_rescue.lua), and it is the rescuer that is asked rather than a
	-- flag, so nothing can leave a body pinned down here.
	if ZCNPC.BeingRescued and ZCNPC.BeingRescued(rag) then return false end
	if HungUp(rag) then return false, true end
	if MovingTooFast(rag) then return false, true end
	if not OnTheGround(rag) then return false, true end

	return true
end

-- True when there is literally nowhere to stand (Z-City's own hard line).
local function LegsBlockStand(org)
	if org.llegamputated or org.rlegamputated then return true end

	return (org.lleg or 0) >= 1 and (org.rleg or 0) >= 1
end

-- Push the wake timer out from "now" by `seconds`. A body that was about to
-- stand up is put back under; one that still had time left gets that much more.
function ZCNPC.ExtendDown(rag, seconds)
	if not (IsValid(rag) and seconds and seconds > 0) then return end

	local info = ZCNPC.Downed[rag]
	if not info then return end

	local elapsed = CurTime() - (info.downAt or CurTime())
	info.wakeAfter = math.max(info.wakeAfter or 0, elapsed) + seconds
end

function ZCNPC.WakeUp(rag, info)
	local npc = info.npc
	local org = rag.organism
	if not (IsValid(npc) and org) then return end

	-- find a clear spot above the body (hg.GetUpPos filters target.FakeRagdoll)
	local pos
	local pelvis = rag:LookupBone("ValveBiped.Bip01_Pelvis")
	local matrix = pelvis and rag:GetBoneMatrix(pelvis)
	npc.FakeRagdoll = rag
	pos = hg.GetUpPos(npc, matrix and matrix:GetTranslation() or rag:GetPos(), 50, 50) or rag:GetPos()
	npc.FakeRagdoll = nil

	-- Decided before the body is touched, while it is still lying the way it fell:
	-- the animation rolls the NPC over on the way up, so where it ends up facing
	-- follows from the animation rather than from the direction the body points.
	local plan = ZCNPC.PlanGetUp(rag)

	MoveOrganism(rag, npc) -- also clears hg.organism.list[rag], so the rag's removal callback becomes a no-op
	ZCNPC.MoveDressings(rag, npc)
	org.zcnpc_pendingdown = nil -- fresh state for the next knockout intercept

	npc:SetPos(pos + Vector(0, 0, 2))
	npc:SetAngles(Angle(0, plan and plan.yaw or ZCNPC.BodyYaw(rag) or npc:GetAngles().y, 0))
	npc:SetNoDraw(false)
	npc:DrawShadow(true)
	npc.zcnpc_headkill = nil
	npc.zcnpc_headgod = nil
	if ZCNPC.ReleaseHeadHold then ZCNPC.ReleaseHeadHold(npc) end
	ReleaseGod(npc, true)
	ZCNPC.RestoreStanding(npc, info)
	npc:SetNPCState(NPC_STATE_ALERT)

	npc.zcnpc_rag = nil
	ZCNPC.Downed[rag] = nil

	SyncBody(npc, rag, false, plan ~= nil)

	npc:EmitSound("player/falling_foley/fall_foley" .. math.random(13) .. ".wav", 60, math.random(95, 110))

	ZCNPC.Debug("woke up", npc, info.class)
	hook.Run("ZCNPC_WokeUp", npc, org, rag, info)

	-- the animation needs the body to stay put for a moment longer, and the gun
	-- stays out of sight until the NPC is actually standing
	if not ZCNPC.StartGetUp(npc, rag, plan) then
		rag:Remove()
		ZCNPC.ShowWeapon(npc)
	end
end
--//

--\\ Dying on the ground
function ZCNPC.IsHomigradWeapon(class)
	return weapons.IsBasedOn(class, "homigrad_base")
		or weapons.IsBasedOn(class, "weapon_medkit_sh") or class == "weapon_medkit_sh"
		or weapons.IsBasedOn(class, "weapon_melee") or class == "weapon_melee"
end

-- wep: the live weapon this entry stands for, so its real clip and attachments carry over
function ZCNPC.AddLoot(rag, class, wep)
	rag.inventory = rag.inventory or {}
	rag.inventory.Weapons = rag.inventory.Weapons or {}
	if rag.inventory.Weapons[class] then return end

	if IsValid(wep) and wep.GetInfo then
		rag.inventory.Weapons[class] = wep:GetInfo()
	else
		local weapon = weapons.Get(class)
		rag.inventory.Weapons[class] = weapon and weapon.GetInfo and weapon:GetInfo() or true
	end

	rag:SetNetVar("Inventory", rag.inventory)
end

local AddLoot = ZCNPC.AddLoot

function ZCNPC.KillDowned(rag, info)
	local org = rag.organism
	local npc = info.npc

	if org then
		org.alive = false
		rag.fullsend = true
		hg.send_bareinfo(org)
	end

	-- anything the body already offered while it was down is either still in its
	-- inventory or was carried off by a looter - either way it must not come back
	if IsValid(npc) then
		ZCNPC.SyncLootSpent(npc, rag, info)

		-- The hand lets go of the weapon and it falls where the hand was, rather
		-- than vanishing inside the body to be found by searching it the way
		-- Z-City's own corpses hide theirs. A dead man's gun is on the floor next
		-- to him, and being able to see it there is most of what tells you a fight
		-- is over.
		--
		-- Class is read before DropWeapon: that call Removes the held SWEP, and
		-- GetClass on a removed entity is not something to lean on - when it came
		-- back nil, TakeLoot never cleared the inventory copy BuildDownedLoot put
		-- there, so a headshot kill left the gun on the floor and again inside the
		-- body.
		local wep = npc:GetActiveWeapon()
		if IsValid(wep) then
			local class = wep:GetClass()
			ZCNPC.DropWeapon(npc, ZCNPC.HandDrop(rag))
			ZCNPC.TakeLoot(rag, info, class)
		elseif info.wepclass then
			-- UpdateWeaponHold already dropped it; make sure the pocket is empty too
			ZCNPC.TakeLoot(rag, info, info.wepclass)
		end
	end

	-- Before npc:Remove: the loot kit / spent flags live on the NPC entity.
	-- Kit + spent, not a fresh NativeLoot dump: looting a living body then
	-- finishing it must not grow a second vanilla stash.
	if ZCNPC.FinalizeCorpseLoot then
		ZCNPC.FinalizeCorpseLoot(rag, info)
	else
		-- Fallback only: NativeLoot may use { class, chance } entries.
		for _, entry in ipairs(cfg.NativeLoot[info.class] or {}) do
			local class = isstring(entry) and entry or (istable(entry) and (entry.class or entry[1])) or nil
			if isstring(class) and not (info.offered and info.offered[class]) then
				AddLoot(rag, class)
			end
		end
	end

	if IsValid(npc) then
		-- Said before the husk goes, because after it there is nothing left to
		-- name: everyone still aiming at this one is holding the entity and the
		-- place it was standing, and neither of those stops being shot at just
		-- because the entity was removed (sv_execute.lua).
		if ZCNPC.ReleaseAttackers then
			ZCNPC.ReleaseAttackers(npc, rag:WorldSpaceCenter())
		end

		-- Remove() can still drop an engine ragdoll on some NPC classes.
		-- The body on the floor is already the corpse. Flag first so
		-- CreateEntityRagdoll drops that doll before anyone copies onto it.
		if npc.SetShouldServerRagdoll then npc:SetShouldServerRagdoll(false) end
		npc.DontCreateRagdoll = true
		npc.zcnpc_noragdoll = true

		npc:Remove() -- silent removal, the body on the ground IS the corpse
	end

	ZCNPC.Downed[rag] = nil
	rag.zcnpc_corpse = true
	rag.zcnpc_keepbody = true
	rag:SetNWBool("zcnpc_corpse", true)

	-- The pairing goes with the husk. An entity index is handed out again as soon as
	-- it is free, so a body still pointing at the one it used to have is a body that
	-- pairs itself with whatever got the number next.
	rag:SetNWEntity("zcnpc_npc", NULL)

	if ZCNPC.ScheduleParkCorpse then ZCNPC.ScheduleParkCorpse(rag) end

	local function sweep()
		if IsValid(rag) and ZCNPC.SweepDupes then ZCNPC.SweepDupes(rag) end
	end

	sweep()
	timer.Simple(0, sweep)
	timer.Simple(0.08, sweep)

	ZCNPC.Debug("died while downed", info.class)
	hook.Run("ZCNPC_Died", rag, org)
end

-- A second prop_ragdoll of the same model on top of ours: engine death,
-- Manhunt's generic, CreateEntityRagdoll racing Remove(). The body we kept
-- is the corpse; anything else in the same spot is a duplicate.
--
-- After KillDowned the husk is gone, so "same NPC" must still match on the
-- stale pointer — IsValid(npc) is false and used to skip the real dupe.
function ZCNPC.SweepDupes(keep)
	if not IsValid(keep) then return end

	local pos = keep:GetPos()
	local model = keep:GetModel()
	local npc = keep.zcnpc_npc

	for _, ent in ipairs(ents.FindInSphere(pos, 96)) do
		if ent == keep then continue end
		if not (IsValid(ent) and ent:GetClass() == "prop_ragdoll") then continue end
		if ent:GetModel() ~= model then continue end
		if IsValid(ent.ply) and ent.ply:IsPlayer() then continue end
		if ent.zcnpc_playercorpse then continue end

		local otherDowned = ZCNPC.Downed and ZCNPC.Downed[ent]
		local sameNpc = npc ~= nil and ent.zcnpc_npc == npc

		-- Another living / parked body: keep it unless it is the same NPC.
		if (ent.zcnpc_keepbody or otherDowned) and not sameNpc then
			continue
		end

		if sameNpc or ent.zcnpc_drop then
			ent:Remove()
			continue
		end

		-- Empty engine leftover on top of ours (no organism, not a body we kept).
		if not ent.zcnpc_keepbody and not otherDowned and not ent.organism then
			ent:Remove()
		end
	end
end
--//

--\\ Shooting a body that is already down
-- The organism has no idea what to do with this. Its answer is bleeding out: the
-- heart stops, the brain starves, and minutes later the body is a corpse, which is
-- right for a body that was left alone and no answer at all for one that is being
-- shot to pieces. Every round is real damage and none of it is fatal on its own, so
-- a whole magazine into a chest changes nothing anyone can see and the body squirms
-- on. That is the "shooting the ragdoll doesn't kill it" of it.
--
-- So a body carries a damage total of its own, on the same scale as any other
-- damage. Artagdoll keeps exactly such a number for the ragdolls it animates, and
-- when it is installed the two are kept in step (sv_artagdoll.lua) so there is only
-- ever one of them to reason about.
function ZCNPC.BodyHP(rag)
	local max = cfg.body_hp:GetFloat()
	if max <= 0 then return end

	return math.min(rag.zcnpc_hp or max, max), max
end

function ZCNPC.BodyDamage(rag, amount)
	if not (IsValid(rag) and amount and amount > 0) then return end
	-- headshot kill is already on a timer; don't race it
	if (rag.zcnpc_deferredkill or 0) > CurTime() then return end

	local hp, max = ZCNPC.BodyHP(rag)
	if not hp then return end

	hp = hp - amount
	rag.zcnpc_hp = hp

	hook.Run("ZCNPC_BodyHurt", rag, hp, max)

	if hp > 0 then return end

	-- deferred: this arrives from inside Z-City's damage handling, which is itself
	-- called from the "Org Think" walk over hg.organism.list
	timer.Simple(0, function()
		if not IsValid(rag) then return end
		if (rag.zcnpc_deferredkill or 0) > CurTime() then return end

		local info = ZCNPC.Downed[rag]
		if info then ZCNPC.KillDowned(rag, info) end
	end)
end

-- Fires for a ragdoll victim because the organism it is carrying has fakePlayer set
-- (sv_input.lua:888), and carries the damage Z-City has already taken armour and
-- hit location out of.
hook.Add("HomigradDamage", "zcnpc_bodyhp", function(victim, dmgInfo)
	if not (ZCNPC.Enabled() and IsValid(victim) and victim:IsRagdoll()) then return end
	if not ZCNPC.Downed[victim] then return end

	ZCNPC.BodyDamage(victim, dmgInfo:GetDamage())
end)

-- Hits on a body that is already down push the wake timer out. Crush from the
-- floor settling is out of it - only deliberate damage (and kicks get their own
-- longer bump).
local DOWN_EXTEND = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER + DMG_BLAST + DMG_SLASH + DMG_CLUB

local function DownedRagFromHit(victim, hitEnt)
	local a, b = victim, hitEnt

	for _ = 1, 2 do
		local ent = a
		if IsValid(ent) then
			if ent:IsRagdoll() and ZCNPC.Downed[ent] then return ent end
			if ent:IsNPC() and IsValid(ent.zcnpc_rag) and ZCNPC.Downed[ent.zcnpc_rag] then
				return ent.zcnpc_rag
			end
		end
		a, b = b, a
	end
end

hook.Add("HomigradDamage", "zcnpc_down_extend", function(victim, dmgInfo, _, hitEnt)
	if not ZCNPC.Enabled() then return end
	if not dmgInfo:IsDamageType(DOWN_EXTEND) then return end

	local rag = DownedRagFromHit(victim, hitEnt)
	if not rag then return end

	local add = cfg.hit_extend:GetFloat()
	if dmgInfo:IsDamageType(DMG_CLUB) and ZCNPC.IsLegKick(dmgInfo) then
		add = cfg.kick_extend:GetFloat()
	end

	if add <= 0 then return end

	ZCNPC.ExtendDown(rag, add)
end)
--//

--\\ Monitor: death & wake conditions + catching knockouts the kill-intercept missed
-- What a stopped heart is worth. Nothing, when the organism is the one deciding: it
-- already kills a body that has been without oxygen long enough, on the line a player
-- dies on and by a route that has nothing to do with us (organism/modules/sv_lungs.lua:383,
-- brain 0.7 and about two minutes of hypoxia to reach it, which runs on our bodies
-- because the organism they carry has fakePlayer set).
--
-- Our own clock off the heart stopping is what this was, and it was the bug: forty-five
-- seconds in, a body with a brain barely touched was written off as a corpse and every
-- medicine on the map refused it - while 1nazuma's PDA, reading the same organism,
-- reported cardiac arrest and a man still worth saving. It was right and we were early.
-- Now cardiac arrest is cardiac arrest, for as long as the body can take it, and what
-- happens in that window is the point of a defibrillator and a bag of blood.
--
-- The fallback below is that same two-minute window, not the old 45-second
-- write-off. Lungs should flip org.alive when the brain hits 0.7. If that
-- think never finished (Notify on an NPC, a missing head bone, o2 never
-- draining), arrest lasted forever — "cardiac arrest cannot kill a NPC".
local BRAIN_ARREST_FALLBACK = 120

-- How long a body that is otherwise free to stand is held down by its pose alone.
local POSE_GIVEUP = 5

local function HeartstopDeath()
	if cfg.death_brain:GetBool() then
		return BRAIN_ARREST_FALLBACK
	end

	return cfg.death_time:GetFloat()
end

timer.Create("zcnpc_monitor", 0.25, 0, function()
	local enabled = ZCNPC.Enabled()
	local heartAfter = HeartstopDeath()
	local wakeOn = enabled and cfg.wakeup:GetBool()
	local wakeAfter = wakeOn and cfg.wakeup_time:GetFloat() or 0
	local now = CurTime()

	-- downed bodies
	for rag, info in pairs(ZCNPC.Downed) do
		if not IsValid(rag) or not rag.organism then
			-- body got cleaned up: bring the NPC back with a fresh organism (or drop the entry)
			ZCNPC.Downed[rag] = nil

			local npc = info.npc
			if IsValid(npc) then
				npc.zcnpc_rag = nil
				npc:SetNoDraw(false)
				npc:DrawShadow(true)
				ReleaseGod(npc, true)
				ZCNPC.RestoreStanding(npc, info)
				npc:SetNPCState(NPC_STATE_ALERT)

				ZCNPC.ShowWeapon(npc)
				SyncBody(npc, rag, false)

				if ZCNPC.HangOrganism then
					ZCNPC.HangOrganism(npc)
				else
					hg.organism.Add(npc)
					if istable(npc.organism) then
						hg.organism.Clear(npc.organism)
						npc.organism.fakePlayer = true
					end
				end
			end

			continue
		end

		local org = rag.organism

		if not IsValid(info.npc) then
			-- A wound-only manhunt finish used to delete the hidden NPC. That is
			-- not a real death: the body on the floor is still a downed person.
			local held = rag.zcnpc_mh_woundonly or rag.zcnpc_mh_holdremove or rag.zcnpc_mh_wounded
			if held then
				if not rag.zcnpc_mh_wounded and ZCNPC.ManhuntWoundFinish then
					ZCNPC.ManhuntWoundFinish(rag)
				end

				if org.alive == false then
					ZCNPC.KillDowned(rag, info)
				end

				continue
			end

			-- NPC entity vanished (admin cleanup etc.) - the body becomes a plain corpse
			ZCNPC.KillDowned(rag, info)
			continue
		end

		-- A lethal head shot knocks the body down first and kills a fraction of a
		-- second later (sv_head.lua). brain is already 1 in that window on purpose,
		-- so without this latch the monitor would finish them on the same pass and
		-- the delay would never happen.
		if (rag.zcnpc_deferredkill or 0) > now then
			ZCNPC.UpdateWeaponHold(info.npc, rag, info)
			ZCNPC.UpdateActive(rag)
			-- FollowBody is owned by the 0.05s Think in sv_sound.lua

			continue
		end

		-- org.alive is the organism's own verdict and the first line here on purpose:
		-- with the brain deciding it is the only one of these that ever fires for a
		-- body that was left to bleed out. The rest are the deaths the organism has no
		-- way of knowing about - a head that is gone, a brain wrecked by the bullet
		-- rather than by hypoxia, and a body shot to pieces on the floor.
		-- A wound-only manhunt finish writes brain / spine flags the animation
		-- uses for the kill, then we clamp them. Without this latch the monitor
		-- would finish the body on the same pass the execution is still playing.
		local woundHold = rag.zcnpc_mh_woundonly or rag.zcnpc_mh_holdremove
			or (IsValid(info.npc) and (info.npc.zcnpc_mh_woundonly or info.npc.zcnpc_mh_holdremove))
		local woundDone = rag.zcnpc_mh_wounded
			or (IsValid(info.npc) and info.npc.zcnpc_mh_wounded)

		-- During the execution, ignore the animation's brain / head flags.
		-- After it, those flags stay clamped; bleed-out and body HP still kill.
		local stoppedAt = org.heartstoptime or info.downAt
		if not woundHold and (org.alive == false
			or (rag.zcnpc_hp or 1) <= 0
			or (heartAfter and org.heartstop and stoppedAt and (now - stoppedAt) > heartAfter)
			or (org.heartstop and (org.brain or 0) >= 0.7)
			or (not woundDone and ((org.brain or 0) >= 1 or org.headamputated)))
		then
			ZCNPC.KillDowned(rag, info)
			continue
		end

		-- losing consciousness on the ground means letting go of the gun, and of the
		-- fight to stay upright
		ZCNPC.UpdateWeaponHold(info.npc, rag, info)
		ZCNPC.UpdateActive(rag)
		-- FollowBody: Think path in sv_sound.lua (was duplicated here every 0.25s)

		-- Bandage knocks a fully ruined leg from 1.0 to 0.95. The moment that
		-- clears the hard "both legs gone" lock, do not wait out a long knockdown
		-- or KO timer — stand up shortly and limp if need be.
		local legsLock = LegsBlockStand(org)
		if info.zcnpc_legslock and not legsLock and not org.otrub then
			local elapsed = now - (info.downAt or now)
			info.wakeAfter = math.min(info.wakeAfter or 999, elapsed + 1.2)
		end
		info.zcnpc_legslock = legsLock

		-- Duct tape: track the weld lock and unlock wakeAfter when the last bond
		-- is cut. WakeUp itself still wears tape the same way players do.
		if ZCNPC.DuctTapeTick then
			ZCNPC.DuctTapeTick(rag, info)
		end

		-- Finish-off window: NOTARGET follows otrub / consciousness.
		if ZCNPC.UpdateDownedTargetable then
			ZCNPC.UpdateDownedTargetable(rag, info)
		end

		-- Open wounds hold wake-up until shortly after bleeding stops.
		local bleedAdd = cfg.bleed_extend:GetFloat()
		if bleedAdd > 0 and (org.bleed or 0) > 0.05 then
			info.wakeAfter = math.max(info.wakeAfter or 0, now - info.downAt + bleedAdd)
		end

		-- CanWakeUp walks every phys bone + TraceLine — only when the timer is up.
		local ready = (now - info.downAt) > (info.wakeAfter or wakeAfter)
		if wakeOn and ready then
			local canWake, poseBlocked = CanWakeUp(org, rag)
			if poseBlocked then
				info.poseBlockedSince = info.poseBlockedSince or now
			else
				info.poseBlockedSince = nil
			end

			if canWake then
				ZCNPC.WakeUp(rag, info)
			elseif poseBlocked and ZCNPC.ActiveBodies and ZCNPC.ActiveBodies[rag] then
				rag.zcnpc_wakecheck = true
				ZCNPC.ActiveOff(rag)
			elseif poseBlocked and now - info.poseBlockedSince > POSE_GIVEUP and not MovingTooFast(rag) then
				-- Every other reason to stay down is already clear; only the lie of the
				-- body is. Lying across a prop or another body can fail the ground and
				-- speed checks forever, and that was a body that never got up.
				ZCNPC.WakeUp(rag, info)
			elseif not poseBlocked then
				rag.zcnpc_wakecheck = nil
			end
		else
			rag.zcnpc_wakecheck = nil
			info.poseBlockedSince = nil
		end
	end

	-- Nothing that is not lying down keeps it. Everything above hands the flag back
	-- itself and this is here for the times one of them did not get to: the sweep
	-- costs a walk over however many husks are down right now, which is the same
	-- number of bodies the loop above just went through, and it is the difference
	-- between one missed hand-back and an NPC nothing can hurt again.
	--
	-- A head shot's own hold is left alone. It has an end of its own and a watchdog
	-- to enforce it (sv_head.lua), and a second opinion arriving between the two
	-- would be this letting the engine kill an NPC the head shot is a tick away from
	-- laying down properly.
	for npc in pairs(ZCNPC.Godded) do
		if not IsValid(npc) then
			ZCNPC.Godded[npc] = nil
		elseif not IsValid(npc.zcnpc_rag) then
			-- An active head-shot hand-over still owns the flag for up to HOLD_MAX.
			-- Anything else standing with it is a leftover: the kill never arrived,
			-- or zcnpc_headgod stuck after the hold table dropped the NPC.
			if npc.zcnpc_headgod and (npc.zcnpc_headhold or 0) > now then
				continue
			end

			ZCNPC.Debug("godmode outlived a knockdown, releasing", npc)
			npc.zcnpc_headkill = nil
			if ZCNPC.ReleaseHeadHold then ZCNPC.ReleaseHeadHold(npc) end
			ReleaseGod(npc, true)
		end
	end

	-- Same leftover, seen from the other side: a standing NPC still marked
	-- headkill / headgod whose hold has expired. HomigradDamage used to zero
	-- every later head shot on that mark, which is "immortal" with no Godded
	-- entry left to sweep.
	local orgList = hg.organism and hg.organism.list
	if orgList then
		for owner in pairs(orgList) do
			if not (IsValid(owner) and owner:IsNPC()) then continue end
			if IsValid(owner.zcnpc_rag) then continue end
			if (owner.zcnpc_headhold or 0) > now then continue end
			if not (owner.zcnpc_headkill or owner.zcnpc_headgod or ZCNPC.Godded[owner]) then
				continue
			end

			ZCNPC.Debug("standing leftover god/headkill, releasing", owner)
			owner.zcnpc_headkill = nil
			if ZCNPC.ReleaseHeadHold then ZCNPC.ReleaseHeadHold(owner) end
			if ZCNPC.Godded[owner] then ReleaseGod(owner, true) end
		end
	end

	if not enabled then return end

	-- walking NPCs whose organism says "knocked out" (otrub persists between
	-- organism ticks; needfake is normally caught by the damage wrapper).
	-- Collect first: MakeUnconscious inserts into hg.organism.list and
	-- mutating a table while pairs() walks it is undefined behaviour.
	if not orgList then return end

	local toDown
	local toFinish

	for owner, org in pairs(orgList) do
		if not (IsValid(owner) and owner:IsNPC() and not IsValid(owner.zcnpc_rag)) then
			continue
		end
		if ZCNPC.IsZombie(owner) then continue end

		-- Lungs already buried them while they were still on their feet.
		if org.alive == false then
			toFinish = toFinish or {}
			toFinish[#toFinish + 1] = owner
			continue
		end

		-- Arrest, or the organism asking to go down. Heartstop does not set
		-- needotrub (Z-City left that line commented out), so without this
		-- they walk around with no pulse until someone shoots them.
		if org.heartstop or org.otrub or org.fake then
			toDown = toDown or {}
			toDown[#toDown + 1] = owner
		end
	end

	if toFinish then
		for _, owner in ipairs(toFinish) do
			local rag = ZCNPC.MakeUnconscious(owner, nil, nil, true)
			if IsValid(rag) then
				local info = ZCNPC.Downed[rag]
				if info then ZCNPC.KillDowned(rag, info) end
			end
		end
	end

	if toDown then
		for _, owner in ipairs(toDown) do
			ZCNPC.MakeUnconscious(owner)
		end
	end
end)
--//

--\\ Map cleanup safety
hook.Add("PreCleanupMap", "zcnpc_cleanup", function()
	for rag, info in pairs(ZCNPC.Downed) do
		if IsValid(info.npc) then info.npc:Remove() end
		if IsValid(rag) then rag:Remove() end
	end

	ZCNPC.Downed = {}
end)
--//
