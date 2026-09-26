--[[
	Electricity.

	Z-City has two weapons whose whole purpose is to put somebody on the floor
	without killing them, and neither of them could do it to an NPC.

	The stunstick was doing what a length of pipe does: club damage, some pain, and
	the NPC carries on walking towards you. A metrocop's baton is not a pipe - it is
	the thing they carry instead of shooting people, and the entire point of it is
	that one hit ends the argument. So a hit puts the body down, and a hit to the
	head puts whoever is in it out.

	The taser never worked on an NPC at all: the shot lands, the prongs go in and
	nothing happens, because everything past the trace was written for a player -
	InVehicle, Alive, FakeRagdoll and hg.StunPlayer are all Player methods and an
	NPC has none of them, so the shot walks into the player path and dies on the
	first call. The SWEP is wrapped from here rather than edited there, so this
	works on a stock Z-City; a build carrying the "HomigradTaserNPC" patch is
	answered too, and the two cannot both fire on one shot. Past that it is the
	same five to seven seconds, held down by the same org.stun a tasered player is
	held down by, convulsing through the same hg.ShadowControl.

	Neither of these is a knockdown of the sort in sv_damage.lua. That is a shove
	that happens to land somebody on the floor, weighed in force and rolled for; this
	is a weapon doing the one thing it is for, so there is nothing to weigh and
	nothing to roll - and nothing to configure either. A stun weapon that sometimes
	stuns is not a setting anybody wants.
]]

--\\ Who counts
-- Z-City replaces the engine's stunstick with its own on spawn
-- (sv_util.lua:1210), so in practice there is one class; the engine's is here for
-- the map that hands one out directly and the NPC that is still holding it.
local batons = {
	weapon_hg_stunstick = true,
	weapon_stunstick = true,
}

local function Baton(dmgInfo)
	local wep = dmgInfo:GetInflictor()
	if not (IsValid(wep) and wep:IsWeapon()) then return false end

	-- An addon's own stun baton says so and is taken at its word.
	return wep.ZCNPCStun == true or batons[wep:GetClass()] == true
end

-- A hitgroup on a standing NPC is HITGROUP_GENERIC for everything - it is read off
-- the physics bone a trace ended on and a standing NPC has none - so where the
-- baton landed has to be worked out from where it landed. Which is honest enough
-- for a melee weapon: the damage position is the trace's hit position
-- (weapon_melee.lua:1256), the exact point the baton met the body.
local HEAD_BONE = "ValveBiped.Bip01_Head1"
local HEAD_REACH = 14 -- units from the head that still counts as the head

-- The same ladder the rest of the addon climbs for this (sv_sound.lua, sv_getup.lua):
-- a bone matrix if the server has one, the physics object if the body is a ragdoll,
-- and the bone position last. EyePos is the floor of it - the view offset rather than
-- the skull, but it is on every entity and it is inside the head.
local function HeadPos(ent)
	local bone = ent:LookupBone(HEAD_BONE)
	if not bone then return ent:EyePos() end

	local matrix = ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end

	local physBone = ent:TranslateBoneToPhysBone(bone)
	local phys = physBone and physBone >= 0 and ent:GetPhysicsObjectNum(physBone)
	if IsValid(phys) then return phys:GetPos() end

	local pos = ent:GetBonePosition(bone)

	return isvector(pos) and pos or ent:EyePos()
end

local function HeadHit(ent, dmgInfo, hitgroup, inputHole)
	if hitgroup == HITGROUP_HEAD then return true end

	local pos = ZCNPC.HitPos(ent, dmgInfo, inputHole)
	if not pos then return false end

	return pos:DistToSqr(HeadPos(ent)) <= HEAD_REACH * HEAD_REACH
end
--//

--\\ The stunstick
-- Down either way, and the difference is who is still in the body when it lands.
-- ZCNPC.Floor is a body on the floor with somebody awake inside it: it squirms, it
-- keeps hold of its gun, it is still worth shooting at, and it gets up again
-- shortly. Firing back off the floor is a switch of its own now and off by default
-- (sv_downedfight.lua): the shot came from the hidden entity standing where the body
-- fell rather than from the body. The head hit goes through the organism instead,
-- which is what
-- makes it a knockout rather than a fall - ZCNPC.HeadKnockout leaves enough shock
-- behind that Z-City holds the body under on its own, for about as long as any
-- other knockout in the mod.
hook.Add("HomigradDamage", "zcnpc_stunstick", function(victim, dmgInfo, hitgroup, _, _, _, inputHole)
	if not (ZCNPC.Enabled() and IsValid(victim)) then return end
	if not Baton(dmgInfo) then return end

	-- Either an NPC on its feet or the body one is already lying in. A baton means
	-- something to both, and something different to each.
	if not (victim:IsNPC() or IsValid(victim.zcnpc_npc)) then return end
	if ZCNPC.IsZombie(victim) then return end

	local org = ZCNPC.ResolveOrganism(victim)
	if not org or org.alive == false then return end

	local head = HeadHit(victim, dmgInfo, hitgroup, inputHole)

	-- Whoever is in there goes out, wherever they are. What HeadKnockout leaves behind
	-- is shock, which is what Z-City reads to hold a body under, so this works on
	-- somebody squirming on the floor exactly as it works on somebody standing up.
	if head then ZCNPC.HeadKnockout(org, true) end

	ZCNPC.Debug("stunstick", head and "to the head" or "to the body", victim)

	-- Already down, and the only thing a baton had left to add was the line above.
	if not victim:IsNPC() or IsValid(victim.zcnpc_rag) then return end

	-- deferred by a frame, like every other way of putting an NPC down from inside
	-- damage handling: "HomigradDamage" can run from inside the "Org Think" loop
	timer.Simple(0, function()
		if not IsValid(victim) then return end

		if head then
			ZCNPC.MakeUnconscious(victim)
		else
			ZCNPC.Floor(victim)
		end
	end)
end)
--//

--\\ The taser
-- Hg.ShadowControl's own numbering (sv_control.lua:20), and the same set of it the
-- player path drives: both arms and both legs, all the way out to the hands. Not
-- the spine and not the head - a body whose chest is being steered does not convulse,
-- it sits up.
local CONVULSE = { 2, 3, 4, 5, 6, 7, 8, 9, 11, 12 }

local SHAKE_DAMP = 50
local SHAKE_WANDER = 5 -- degrees of noise on the angle it is dragged towards
local TASER_SOUND = "tazer.wav"

local shaking = {} -- [ragdoll] = when the current is switched off

-- Every limb dragged hard towards one angle that is nearly the opposite of the way
-- the chest is facing, jittered a little each tick. Nothing can reach it - the arms
-- and legs are jointed to a body that is not going anywhere - so what it looks like
-- is every muscle pulling at once, which is what a taser does. Pulse scales it,
-- exactly as the player path scales it: a heart going fast is a body being driven
-- hard.
local function Convulse(rag)
	local org = rag.organism
	if not org then return false end

	local bone = rag:LookupBone("ValveBiped.Bip01_Spine2")
	local spine = bone and rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(bone))
	if not IsValid(spine) then return false end

	local ang = spine:GetAngles()
	ang:Add(AngleRand(-SHAKE_WANDER, SHAKE_WANDER))
	ang:RotateAroundAxis(ang:Up(), 180)

	local mul = 1000 * (org.pulse or 70) / 70

	for _, num in ipairs(CONVULSE) do
		hg.ShadowControl(rag, num, 0.001, ang, mul, SHAKE_DAMP, vector_origin, 0, 0)
	end

	return true
end

local function StopShaking(rag)
	shaking[rag] = nil

	if IsValid(rag) then rag:StopSound(TASER_SOUND) end
end

hook.Add("Think", "zcnpc_taser", function()
	if not next(shaking) then return end

	for rag, until_ in pairs(shaking) do
		if not IsValid(rag) or CurTime() > until_ or not Convulse(rag) then
			StopShaking(rag)
		end
	end
end)

hook.Add("ZCNPC_WokeUp", "zcnpc_taser", function(_, _, rag)
	StopShaking(rag)
end)

hook.Add("ZCNPC_Died", "zcnpc_taser", function(rag)
	StopShaking(rag)
end)

-- Current through a body, whatever it came out of. The prongs are one way of getting
-- it there and a rollermine sitting on somebody's chest is another (sv_hl2.lua), and
-- past the point where it arrives there is nothing to tell between them: the same
-- limbs pulled the same way for as long as it lasts, and the same noise while it is.
-- A second dose while the first one is still running extends it rather than starting
-- a second sound over the top of the first.
function ZCNPC.Electrify(rag, seconds)
	if not IsValid(rag) or not isnumber(seconds) or seconds <= 0 then return false end

	local until_ = CurTime() + seconds

	if shaking[rag] then
		shaking[rag] = math.max(shaking[rag], until_)
	else
		shaking[rag] = until_
		rag:EmitSound(TASER_SOUND)
	end

	return true
end

-- The five to seven seconds of the player path, and the same discount for somebody
-- who cannot feel it. Painkillers are not insulation, so this is Z-City's own answer
-- rather than ours: a drugged body rides it out in about a second.
local function TaserTime(org)
	local drugged = org and (org.analgesia or 0) > 0.5

	return math.random(5, 7) * (drugged and 0.2 or 1)
end

-- The trace hit something that is not a player and not a player's body. It is ours
-- if it is an NPC we look after, or a body one of them is lying in; anything else -
-- a prop, a corpse from another addon, a door - is somebody else's business and
-- saying so is what leaves the shot doing nothing rather than erroring out halfway
-- through.
local function Tasered(target)
	if not IsValid(target) then return end
	if ZCNPC.IsZombie(target) then return end

	if target:IsNPC() then return target end

	local npc = target.zcnpc_npc

	return IsValid(npc) and npc or nil
end

-- One shot is one answer. A Z-City carrying the "HomigradTaserNPC" patch calls this
-- from inside SWEP:Shoot and the wrapper below calls it again the moment Shoot
-- returns; both are the same trigger pull, and a taser cannot go off twice in a
-- frame, so the frame it went off in is the whole of the guard.
local answered = 0

local Unmark -- the wrapper below leaves a mark on the target to get here

local function TaserNPC(target, wep, attacker, tr)
	if not ZCNPC.Enabled() then return end

	local npc = Tasered(target)
	if not npc then return end

	local org = ZCNPC.ResolveOrganism(npc)
	if not org or org.alive == false then return end

	if answered == CurTime() then return true end
	answered = CurTime()

	-- Whichever way the shot arrived here, the mark has done its job, and the
	-- damage below must not be dealt to a body that is pretending to have one.
	Unmark()

	-- The prongs are a wound, small and real, and the body should have it: five points
	-- of it exactly as a player takes them, so armour stops them the same way and the
	-- hole is in the right place. Dealt to whatever the prongs actually went into
	-- rather than to the NPC behind it - a body on the floor holds the organism and
	-- the hidden NPC under it is in godmode, so damage aimed there lands nowhere.
	local dmg = DamageInfo()
	dmg:SetDamage(5)
	dmg:SetAttacker(IsValid(attacker) and attacker or target)
	dmg:SetInflictor(IsValid(wep) and wep or target)
	dmg:SetDamageType(DMG_SLASH)
	dmg:SetDamagePosition(tr and tr.HitPos or target:WorldSpaceCenter())
	dmg:SetDamageForce((tr and tr.Normal or vector_origin) * 50)
	target:TakeDamageInfo(dmg)

	if not IsValid(npc) then return true end

	local time = TaserTime(org)

	ZCNPC.Debug("tasered for", math.Round(time, 1), "seconds:", npc)

	-- Deferred for the same reason as everything else that puts an NPC down out of a
	-- damage path, and because the damage above may have put it down already.
	timer.Simple(0, function()
		if not IsValid(npc) then return end

		local rag = ZCNPC.MakeUnconscious(npc, time)
		if not IsValid(rag) then return end

		-- org.stun is what a tasered player is held down by (hg.StunPlayer), and it
		-- is one of the things our own wake up check reads, so the body stays where
		-- it is until the current stops rather than trying to stand up mid shock.
		local body = rag.organism or org

		body.stun = math.max(body.stun or 0, CurTime() + time)
		body.tasered = CurTime() + time

		ZCNPC.Electrify(rag, time)
	end)

	return true
end

hook.Add("HomigradTaserNPC", "zcnpc_taser", TaserNPC)
--//

--\\ Getting told about the shot
-- The patch above is one branch in Z-City's own SWEP and it is not on every copy
-- of Z-City, so the shot is caught here as well - and here is enough on its own.
--
-- The stock path cannot be let past the trace with anything that is not a player
-- in front of it, so the wrapper works out what the shot is about to hit before
-- letting it go and, when that is not a player and not a player's own body, leaves
-- the path the one answer it understands: "this one is already a body". That is the
-- first thing it asks (weapon_taser.lua:195) and the only way out of the function
-- that is not an error, and by the time it is asked the trigger pull has already
-- happened - the round is gone, the shot is heard, the sights have kicked - so
-- nothing is lost by stopping there. Everything past it is done here instead.
local TASER = "weapon_taser"
local TASER_RANGE = 220 -- the length of the SWEP's own trace

-- Any valid entity satisfies the check; the weapon is used because it is the one
-- entity in reach that nothing could mistake for a corpse. It is taken off again
-- as soon as the function it was there for has returned, and once more a frame
-- later in case that function died on the way.
local marked

function Unmark()
	local mark = marked
	marked = nil

	if not mark then return end

	local ent = mark.ent
	if not (IsValid(ent) or ent == game.GetWorld()) then return end
	if ent.FakeRagdoll ~= mark.token then return end

	ent.FakeRagdoll = nil
end

local function Mark(ent, token)
	Unmark()

	if ent.FakeRagdoll ~= nil then return false end

	ent.FakeRagdoll = token
	marked = { ent = ent, token = token }

	return true
end

-- Where the shot is going, worked out the way the SWEP works it out: off the same
-- muzzle, its own reach, its own mask and filter, and inside the same lag
-- compensation window - so that what is marked here and what it hits there are the
-- same entity even when the man being aimed at is moving.
local function ShotTrace(wep, owner)
	local _, pos, ang = wep:GetTrace(true)
	if not (isvector(pos) and isangle(ang)) then return end

	local compensated = owner:IsPlayer()

	if compensated then owner:LagCompensation(true) end

	local tr = util.TraceLine({
		start = pos,
		endpos = pos + ang:Forward() * TASER_RANGE,
		filter = compensated and { wep } or { wep, owner },
		mask = MASK_SHOT,
	})

	if compensated then owner:LagCompensation(false) end

	return tr
end

-- Somebody's own body is a player as far as the stock path is concerned, and the
-- stock path is right about it, so it is left alone. Everything else is ours to
-- stop.
local function StockCanCope(ent)
	if ent:IsPlayer() then return true end

	local owner = isfunction(hg.RagdollOwner) and hg.RagdollOwner(ent)

	return IsValid(owner)
end

local function Shoot(wep, original, ...)
	local owner = wep:GetOwner()
	if not (ZCNPC.Enabled() and IsValid(owner) and wep:Clip1() > 0) then
		return original(wep, ...)
	end

	local tr = ShotTrace(wep, owner)

	-- A trace that reached the end of its 220 units hit nothing at all, and the
	-- entity it reports for that is NULL, which cannot be asked anything.
	local target = tr and tr.Hit and tr.Entity ~= NULL and tr.Entity
	if not (target and not StockCanCope(target)) then return original(wep, ...) end

	local clip = wep:Clip1()
	local stopped = Mark(target, wep)
	local ret = original(wep, ...)

	Unmark()
	timer.Simple(0, Unmark)

	-- The trigger may not have been pulled at all: half of Shoot is the reasons not
	-- to fire, and a round that is still in the weapon is the plainest sign of one.
	if stopped and wep:Clip1() < clip then TaserNPC(target, wep, owner, tr) end

	return ret
end

-- weapons.Get copies every field into a table of its own, so a taser that was
-- created before this ran is holding the function it was built with: the class is
-- wrapped for the ones still to come and the entity for the ones already here.
local function Wrap(tbl)
	if not (istable(tbl) and isfunction(tbl.Shoot)) then return end
	if rawget(tbl, "zcnpc_taser") then return end

	local original = tbl.Shoot

	tbl.zcnpc_taser = true
	tbl.Shoot = function(self, ...) return Shoot(self, original, ...) end
end

local function InstallTaser()
	Wrap(weapons.GetStored(TASER))

	for _, wep in ipairs(ents.FindByClass(TASER)) do
		if IsValid(wep) then Wrap(wep:GetTable()) end
	end
end

InstallTaser()
hook.Add("InitPostEntity", "zcnpc_taser", InstallTaser)
hook.Add("OnReloaded", "zcnpc_taser", InstallTaser)

hook.Add("OnEntityCreated", "zcnpc_taser", function(ent)
	if not (IsValid(ent) and ent:GetClass() == TASER) then return end

	timer.Simple(0, function()
		if IsValid(ent) then Wrap(ent:GetTable()) end
	end)
end)
--//
