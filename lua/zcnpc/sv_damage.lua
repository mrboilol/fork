--[[
	What a hit does to an NPC that is still on its feet.

	Z-City computes knock forces only for player victims
	(see "if ply then ... hg.StunPlayer" in organism/tier_1/sv_input.lua:896),
	so we replicate the same force math for NPC victims here - and, like there,
	keep being knocked over apart from being knocked out.
]]

local cfg = ZCNPC.Config

util.AddNetworkString("zcnpc_wound")

-- mirror of the (local) RagdollForceBoneMul from organism/tier_1/sv_input.lua
local ForceBoneMul = {
	[HITGROUP_LEFTLEG] = 0.5,
	[HITGROUP_RIGHTLEG] = 0.5,
	[HITGROUP_GENERIC] = 1,
	[HITGROUP_LEFTARM] = 0.5,
	[HITGROUP_RIGHTARM] = 0.5,
	[HITGROUP_CHEST] = 1,
	[HITGROUP_STOMACH] = 1,
	[HITGROUP_HEAD] = 0.5,
}

local BULLET = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER

-- Leg kicks come in as club damage from a player who is mid kick, and Z-City
-- announces that on the attacker for the length of the swing (sv_legkick.lua).
function ZCNPC.IsLegKick(dmgInfo)
	local att = dmgInfo:GetAttacker()
	if not (IsValid(att) and att:IsPlayer()) then return false end

	return att:GetNWFloat("InLegKick", 0) > CurTime()
end

--\\ Leg kicks: kicked NPCs fall over like players do and get back up shortly after.
-- Players are floored via hg.Fake in sv_legkick.lua ("if ent:IsPlayer() then ... hg.Fake(ent)"),
-- NPC victims got nothing there - we ragdoll them through our unconsciousness pipeline
-- with a short wake time instead of the regular zcnpc_wakeup_time knockout.
hook.Add("HomigradDamage", "zcnpc_kick", function(victim, dmgInfo)
	if not ZCNPC.Enabled() or not cfg.kick_ragdoll:GetBool() then return end
	if not (IsValid(victim) and victim:IsNPC()) then return end
	if not dmgInfo:IsDamageType(DMG_CLUB) then return end
	if not ZCNPC.IsLegKick(dmgInfo) then return end

	-- Already on the floor: downtime is extended by zcnpc_down_extend (+0.9).
	-- Flooring again would only fight that with a max() against kick_downtime.
	if IsValid(victim.zcnpc_rag) then return end

	-- Campaign actors used to have the organism stripped so chores would not
	-- steal their schedule. The kick reads the organism, so a missing one is
	-- put back here. MapDriven still keeps patrol / loot / medic off them.
	local org = victim.organism
	if not org and ZCNPC.HangOrganism then
		org = ZCNPC.HangOrganism(victim)
	end
	if not org or org.alive == false then return end

	local att = dmgInfo:GetAttacker()

	local dir = dmgInfo:GetDamageForce()
	dir = dir:LengthSqr() > 0 and dir:GetNormalized() or att:GetAimVector()
	dir.z = 0
	if dir:LengthSqr() < 0.01 then -- kick aimed straight down (curbstomp angle)
		dir = att:EyeAngles():Forward()
		dir.z = 0
	end
	dir:Normalize()

	-- A kick knocks someone over. It does not throw them across the room, and it
	-- used to: the shove was well over 300 units a second before the body had even
	-- worked out which way was down. zcnpc_kick_force is the whole of it now, with
	-- a little lift so the body leaves its feet instead of skidding.
	local force = cfg.kick_force:GetFloat()
	local shove = dir * (force + math.min(dmgInfo:GetDamage(), 25) * force * 0.03) + Vector(0, 0, force * 0.35)
	local downFor = cfg.kick_downtime:GetFloat()

	-- defer: HomigradDamage can fire from inside the "Org Think" iteration
	timer.Simple(0, function()
		if not IsValid(victim) then return end
		ZCNPC.MakeUnconscious(victim, downFor, shove)
	end)
end)

-- Lambda turns teammate collision off so two HEV suits can occupy one doorway
-- (DisablePlayerCollide / NoCollideWithTeammates). Z-City's kick is a hull
-- trace. A trace that respects that flag goes through the friend and never
-- calls hg.Fake. The swing still happens; the connect is what we do here,
-- by who is standing in front, not by whether the engine let the hull touch.
local KICK_REACH = 96
local KICK_DOT = 0.35
local KICK_FRAME = 0.38

local function EnsureKickOrganism(ent)
	if ZCNPC.HangOrganism then
		return ZCNPC.HangOrganism(ent)
	end

	return ent.organism
end

local function KickVisible(from, ent)
	if not (IsValid(from) and IsValid(ent)) then return false end

	local start = from:EyePos()
	local dest = ent:WorldSpaceCenter()
	local tr = util.TraceLine({
		start = start,
		endpos = dest,
		filter = {from, ent},
	})

	return not tr.Hit
end

local function InKickArc(ply, ent)
	if not (IsValid(ply) and IsValid(ent)) then return false end

	local start = ply:WorldSpaceCenter()
	local dest = ent:WorldSpaceCenter()
	local to = dest - start
	local distSqr = to:LengthSqr()
	if distSqr > KICK_REACH * KICK_REACH then return false end

	local fwd = ply:GetAimVector()
	fwd.z = 0
	if fwd:LengthSqr() < 0.01 then return false end
	fwd:Normalize()

	-- Origin of an NPC is its feet. A cone from the eyes to that point, in
	-- close, points almost straight down and misses every time. Flat XY is
	-- the kick: who is in front of you, not who is under your chin.
	to.z = 0
	if to:LengthSqr() < 16 then return true end
	to:Normalize()

	return to:Dot(fwd) >= KICK_DOT
end

function ZCNPC.ConnectKick(ply)
	if not ZCNPC.Enabled() or not cfg.kick_ragdoll:GetBool() then return end
	if not (IsValid(ply) and ply:Alive()) then return end
	if ply:GetNWFloat("InLegKick", 0) <= CurTime() then return end

	local forward = ply:GetAimVector()
	forward.z = 0
	if forward:LengthSqr() < 0.01 then
		forward = ply:GetAngles():Forward()
		forward.z = 0
	end
	forward:Normalize()

	local force = cfg.kick_force:GetFloat()
	local downFor = cfg.kick_downtime:GetFloat()
	local shove = forward * force + Vector(0, 0, force * 0.35)

	local function Hit(ent)
		if not IsValid(ent) or ent == ply then return end
		if not InKickArc(ply, ent) then return end

		local close = ply:WorldSpaceCenter():DistToSqr(ent:WorldSpaceCenter()) < (48 * 48)
		if not close and not KickVisible(ply, ent) then return end

		if ent:IsPlayer() then
			if not ent:Alive() or IsValid(ent.FakeRagdoll) then return end
			if isfunction(hg.Fake) then
				hg.Fake(ent)
			end
			ent:SetVelocity(forward * 150)
			return
		end

		if not ent:IsNPC() then return end
		if IsValid(ent.zcnpc_rag) then return end
		if ZCNPC.IsZombie(ent) then return end

		local class = ent:GetClass()
		if cfg.Blacklist[class] then return end

		-- No model is not a skip. Bones are missing on the same tick, so
		-- ShouldManage is false; the class still says this is a body.
		local known = cfg.NativeClasses[class] or cfg.HumanClasses[class]
		if not known and not ent.organism then
			if ZCNPC.ShouldManage and not ZCNPC.ShouldManage(ent) then
				if not (cfg.allnpcs and cfg.allnpcs:GetBool()) then return end
			end
		end

		local org = EnsureKickOrganism(ent)
		if not org or org.alive == false then return end

		ZCNPC.MakeUnconscious(ent, downFor, shove)
	end

	for _, tgt in ipairs(player.GetAll()) do
		Hit(tgt)
	end

	for npc in pairs(ZCNPC.NPCs or {}) do
		Hit(npc)
	end
end

local PLAYER = FindMetaTable("Player")

local function WrapKick()
	if PLAYER == nil or PLAYER._ZCNPCKickWrap == true then
		return PLAYER ~= nil and PLAYER._ZCNPCKickWrap == true
	end
	if not isfunction(PLAYER.LegAttack) then return false end

	PLAYER._ZCNPCKickWrap = true
	local oldKick = PLAYER.LegAttack
	function PLAYER:LegAttack(...)
		oldKick(self, ...)
		if self:GetNWFloat("InLegKick", 0) <= CurTime() then return end

		timer.Simple(KICK_FRAME, function()
			if IsValid(self) then ZCNPC.ConnectKick(self) end
		end)
	end

	return true
end

WrapKick()
hook.Add("InitPostEntity", "zcnpc_kick_wrap", WrapKick)
hook.Add("HomigradRun", "zcnpc_kick_wrap", WrapKick)
timer.Create("zcnpc_kick_wrap", 1, 8, function()
	if WrapKick() then timer.Remove("zcnpc_kick_wrap") end
end)
--//

--\\ Knockdowns
-- HomigradDamage fires for NPC victims too (first arg is the NPC when org.fakePlayer is set).
--
-- Two things changed here, and both are about the difference between staggering
-- and being switched off. The threshold now sits where Z-City's own hard stun sits
-- for a player - 7000, the point at which hg.StunPlayer joins hg.LightStunPlayer
-- (sv_input.lua:910) - instead of at the 4500 that only ever meant "slowed down".
-- And what happens above it is a knockdown with its own short timer rather than
-- the full knockout, which parked the NPC on the floor for zcnpc_wakeup_time with
-- org.stun on top making sure it could not get up early.
--
-- Bullets are out of it entirely by default. Being shot in the chest is not a
-- shove; a rifle round carries enough damage force to clear any threshold worth
-- having, so every burst put an NPC on the ground, and once it is on the ground it
-- is finished. That is what zcnpc_pain_reaction is for instead: it reacts to the
-- hit without giving up the fight.
hook.Add("HomigradDamage", "zcnpc_knockdown", function(victim, dmgInfo, hitgroup)
	if not ZCNPC.Enabled() or not cfg.knockdown:GetBool() then return end
	if not (IsValid(victim) and victim:IsNPC()) then return end
	local inflictor = dmgInfo:GetInflictor()
	local class = IsValid(inflictor) and inflictor:GetClass()
	if class == "weapon_hands_sh" or class == "weapon_hg_coolhands" then return end
	if dmgInfo:IsDamageType(BULLET) and not cfg.knockdown_bullets:GetBool() then return end

	local org = victim.organism
	if not org or org.alive == false then return end

	-- same scale the player path uses: force length * hitgroup mul * 0.5
	local len = dmgInfo:GetDamageForce():Length() * (ForceBoneMul[hitgroup] or 1) * 0.5
	if len <= cfg.knockdown_force:GetFloat() then return end
	if ZCNPC.ResistKnockdown(victim) then return end

	org.lightstun = math.max(org.lightstun or 0, CurTime() + 2)

	-- defer: HomigradDamage can fire from inside the "Org Think" iteration
	timer.Simple(0, function()
		if IsValid(victim) then ZCNPC.Floor(victim) end
	end)
end)
--//

--\\ Where the round went in
-- Two things want this and neither had it. The pose a wounded NPC pulls, below, and
-- Artagdoll, which leans a body away from the shot and puts its hands on the wound
-- (sv_artagdoll.lua).
--
-- Artagdoll keeps a position of its own for the purpose, off every EntityTakeDamage
-- there is (init_active_ragdoll.lua:209), and on a Z-City NPC it is always wrong.
-- The last damage an NPC takes before it goes down is not the round that felled it,
-- it is the 10000 the organism deals itself once it wants the body on the floor
-- (sv_organism.lua:528) - and that DamageInfo is built out of a damage figure and an
-- attacker, nothing else, so the position on it is the world origin. Which is a real
-- place, somewhere out in the middle of the map, and the nearest bone to it gets
-- treated as the wound. That is the body clutching its own pelvis after a round
-- through the chest.
--
-- Z-City knows exactly where the round went in: it traces the bullet through the
-- organs and hands the entry hole over as the seventh argument of "HomigradDamage"
-- (sv_input.lua:888). So that is what gets remembered, with the impact point behind
-- it for everything with no hole to speak of - a crowbar, a blast, a fall.
local HIT_MEMORY = 2 -- seconds a wound counts as fresh
local HIT_RANGE = 100 -- anything further off the body than this is not on it

-- Where this hit landed, or nil if there is no answer worth having. Read straight out
-- of the arguments rather than off anything stored, because "HomigradDamage" is one
-- hook with several of ours on it and nothing decides which of them runs first.
function ZCNPC.HitPos(ent, dmgInfo, inputHole)
	if not IsValid(ent) then return end

	local pos = istable(inputHole) and inputHole[1]
	if not isvector(pos) then pos = dmgInfo:GetDamagePosition() end
	if not isvector(pos) or pos:IsZero() then return end
	if pos:DistToSqr(ent:WorldSpaceCenter()) > HIT_RANGE * HIT_RANGE then return end

	-- a copy: the hole belongs to Z-City's trace and is reused by the next pellet
	return Vector(pos)
end

function ZCNPC.RememberHit(ent, dmgInfo, inputHole)
	local pos = ZCNPC.HitPos(ent, dmgInfo, inputHole)
	if not pos then return end

	ent.zcnpc_hitpos = pos
	ent.zcnpc_hittime = CurTime()

	return pos
end

-- nil rather than a guess. A body that keeled over from blood loss minutes after the
-- last round touched it has nothing to clutch, and no wound at all reads better than
-- a wound in the wrong place - which is the whole of what was wrong here.
function ZCNPC.LastHit(ent)
	if not IsValid(ent) then return end
	if (CurTime() - (ent.zcnpc_hittime or -HIT_MEMORY)) > HIT_MEMORY then return end

	return ent.zcnpc_hitpos
end

hook.Add("HomigradDamage", "zcnpc_hitpos", function(victim, dmgInfo, _, _, _, _, inputHole)
	if not ZCNPC.Enabled() then return end

	ZCNPC.RememberHit(victim, dmgInfo, inputHole)
end)
--//

--\\ Which part of it this hit went into
-- Read off the organism rather than off the hitgroup: a hitgroup comes from the
-- physics bone the trace ended on, and a standing NPC has no physics bones, so it is
-- HITGROUP_GENERIC for everything. The limb totals Z-City keeps on the organism
-- answer the same way standing or lying down.
--
-- The bone is where a reaction hangs off. Where on it the hand goes is the entry
-- hole (ZCNPC.HitPos above), because a bone is not a place: ValveBiped spine bones
-- sit on the spine, at the back of the torso, so a hand placed a few units off
-- Spine2 lands on the small of the back whichever side the round came from. Shooting
-- somebody in the chest and watching them grab their own back was exactly that.
--
-- torso marks the two that are worth going down over, and armour is what keeps them
-- empty: these are organ totals, so a round stopped by a chest plate never reaches
-- one of them and never counts as a hit to the chest.
local painParts = {
	{ organ = "chest", bone = "ValveBiped.Bip01_Spine2", torso = true },
	{ organ = "stomach", bone = "ValveBiped.Bip01_Spine", torso = true },
	{ organ = "larm", bone = "ValveBiped.Bip01_L_UpperArm" },
	{ organ = "rarm", bone = "ValveBiped.Bip01_R_UpperArm" },
	{ organ = "lleg", bone = "ValveBiped.Bip01_L_Thigh" },
	{ organ = "rleg", bone = "ValveBiped.Bip01_R_Thigh" },
}

local PAIN = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER + DMG_SLASH + DMG_CLUB + DMG_BLAST

-- Snapshot before the organs take their share, so the difference is what this one
-- hit did - reading the totals afterwards would react to damage that is minutes old
-- and healing off (sv_organism.lua:627).
hook.Add("PreHomigradDamage", "zcnpc_pain", function(victim)
	local org = IsValid(victim) and victim:IsNPC() and victim.organism
	if not org then return end

	local before = org.zcnpc_prepain or {}
	for _, part in ipairs(painParts) do before[part.organ] = org[part.organ] or 0 end

	org.zcnpc_prepain = before
end)
--//

--\\ Rounds in the chest put people on the ground
-- Not by force - that is the knockdown above and force is the wrong measure of this;
-- a rifle round carries enough of it to knock a man over on paper and does not
-- actually do so, which is why bullets are excluded from it. What puts somebody down
-- after being shot twice in the chest is not the shove, it is being shot twice in
-- the chest. So it is counted rather than weighed.
--
-- Rolled per NPC, because the alternative is a rule everyone in the firefight obeys
-- to the round: every soldier on the street standing up to exactly the second bullet
-- and falling on exactly the third reads as a mechanic, and the same fight with one
-- of them dropping on the first and another taking three reads as people.
--
-- Only what got through counts, and the count is per shot rather than per bullet: a
-- shotgun's pellets all arrive inside a single tick and eight of them are one hit,
-- not eight. Nothing here touches the organism, so this is being knocked off your
-- feet and not being knocked out - it is back up in zcnpc_knockdown_time unless the
-- wounds themselves are what keep it there, which by then they often are.
--
-- How long to leave the standing wound pose up before flooring. Matched to the
-- onset window in cl_wound.lua so the hands are seen on the hole first.
local FLOOR_AFTER_CLUTCH = 0.85

local function BodyShot(npc, org)
	if npc.zcnpc_bodyhit == CurTime() then return end -- another pellet from the same shot
	npc.zcnpc_bodyhit = CurTime()

	local need = npc.zcnpc_bodyneed

	if not need then
		local want = cfg.bullet_down:GetFloat()
		if want < 1 then return end

		need = math.max(1, math.random(want - 1, want + 1))
		npc.zcnpc_bodyneed = need
	end

	local hits = (npc.zcnpc_bodyhits or 0) + 1
	npc.zcnpc_bodyhits = hits

	if hits < need then return end

	-- a fresh roll for the next time it is on its feet, so an NPC that gets up and
	-- goes back to the fight is not one round from the floor for the rest of it
	npc.zcnpc_bodyhits, npc.zcnpc_bodyneed = 0, nil

	if ZCNPC.ResistKnockdown(npc) then return end

	ZCNPC.Debug("floored by", hits, "rounds in the body:", npc)

	-- long enough for the body to land and be seen to land, and it is what Z-City
	-- reads to keep somebody off their feet for a moment (sv_input.lua:910)
	org.lightstun = math.max(org.lightstun or 0, CurTime() + 1)

	-- Not the same frame as the wound pose. Flooring hides the NPC and shows the
	-- ragdoll; the clutch is drawn on the NPC, so timer.Simple(0) made "shot in the
	-- chest" look like an instant knockdown with no hands at all. Wait out the
	-- onset of the reaction so it reads, then put them down.
	npc.zcnpc_pendingfloor = CurTime() + FLOOR_AFTER_CLUTCH
	timer.Simple(FLOOR_AFTER_CLUTCH, function()
		if not IsValid(npc) then return end
		if (npc.zcnpc_pendingfloor or 0) > CurTime() + 0.05 then return end
		npc.zcnpc_pendingfloor = nil
		ZCNPC.Floor(npc)
	end)
end
--//

--\\ Reacting to a wound
-- An NPC that is not being knocked over should still look like it was hit. The pose
-- itself is drawn on the client (cl_wound.lua); this is the part that decides there
-- was a wound worth reacting to and hands over where it landed.
hook.Add("HomigradDamage", "zcnpc_pain", function(victim, dmgInfo, _, _, _, _, inputHole)
	if not (ZCNPC.Enabled() and IsValid(victim) and victim:IsNPC()) then return end

	local org = victim.organism
	if not org then return end

	local before = org.zcnpc_prepain
	org.zcnpc_prepain = nil

	if not before then return end
	if org.alive == false or org.otrub then return end
	if IsValid(victim.zcnpc_rag) then return end -- already on the floor, nothing to clutch with
	if not dmgInfo:IsDamageType(PAIN) then return end

	local hurt, worst

	for _, part in ipairs(painParts) do
		local taken = (org[part.organ] or 0) - (before[part.organ] or 0)

		if taken > (worst or 0.01) then hurt, worst = part, taken end
	end

	if not hurt then return end

	if not cfg.pain:GetBool() then
		-- Still floor on body shots when the pose is switched off; otherwise the
		-- count above would arm a knockdown that never fires.
		if hurt.torso and dmgInfo:IsDamageType(BULLET) then BodyShot(victim, org) end

		return
	end

	-- Pose first, floor second. BodyShot used to run before Wounded and hide the
	-- NPC on the next tick, which is why hands stopped reaching for the torso.
	ZCNPC.Wounded(victim, hurt.bone, worst, ZCNPC.HitPos(victim, dmgInfo, inputHole))

	if hurt.torso and dmgInfo:IsDamageType(BULLET) then BodyShot(victim, org) end
end)

-- Long enough to read as a reaction, short enough that an NPC under fire is not
-- permanently clutching itself. A bad wound is held on to for longer.
local PAIN_MIN = 0.9
local PAIN_MAX = 2

-- hitpos (optional): where the round went in, in world space. Sent in the NPC's own
-- frame, because by the time the client draws it the NPC has walked on and a point
-- in the world is no longer a point on a body. The client anchors it to the wound
-- bone from there.
function ZCNPC.Wounded(npc, bone, severity, hitpos)
	local length = math.Clamp(PAIN_MIN + (severity or 0) * 4, PAIN_MIN, PAIN_MAX)

	-- one reaction at a time: a shotgun blast is a dozen separate hits inside one
	-- tick and restarting the pose on each of them would leave it frozen at full
	-- strength for as long as the NPC is being shot at
	if (npc.zcnpc_wound_till or 0) > CurTime() then return end
	npc.zcnpc_wound_till = CurTime() + length

	net.Start("zcnpc_wound")
		net.WriteUInt(npc:EntIndex(), 16)
		net.WriteString(bone)
		net.WriteFloat(length)
		net.WriteBool(hitpos ~= nil)
		if hitpos then net.WriteVector(npc:WorldToLocal(hitpos)) end
	net.Broadcast()
end
--//

--\\ On fire
-- Players in Z-City drop into a ragdoll when they burn (hg.Fake path / fire on
-- FakeRagdoll). Standing NPCs used to walk around on fire until something else
-- floored them. Drop them the same way a shove does - knocked off their feet,
-- not knocked out - and MakeUnconscious moves the flames onto the body so
-- Artagdoll's burning behaviour can see them.
local BURN = DMG_BURN + DMG_SLOWBURN

local function FloorBurning(npc)
	if not (ZCNPC.Enabled() and IsValid(npc) and npc:IsNPC()) then return end
	if IsValid(npc.zcnpc_rag) then return end
	if ZCNPC.IsZombie and ZCNPC.IsZombie(npc) then return end

	local org = npc.organism
	if not org or org.alive == false then return end

	ZCNPC.Debug("floored by fire:", npc)
	ZCNPC.Floor(npc)
end

hook.Add("EntityTakeDamage", "zcnpc_burn", function(ent, dmgInfo)
	if not dmgInfo:IsDamageType(BURN) then return end
	if not (IsValid(ent) and ent:IsNPC()) then return end
	if IsValid(ent.zcnpc_rag) then return end

	timer.Simple(0, function()
		FloorBurning(ent)
	end)
end)

-- Ignite() does not always land a DMG_BURN hit the same tick, and a body that
-- caught fire from a neighbour still needs to go down. Cheap: only the NPCs we
-- already walk for knockouts. Collect first - Floor mutates hg.organism.list.
hook.Add("Think", "zcnpc_burn", function()
	if not ZCNPC.Enabled() then return end
	if (ZCNPC.__burncheck or 0) > CurTime() then return end
	ZCNPC.__burncheck = CurTime() + 0.35

	if not (istable(hg) and istable(hg.organism) and istable(hg.organism.list)) then return end

	local burning
	for owner, org in pairs(hg.organism.list) do
		if not (IsValid(owner) and owner:IsNPC() and org and org.alive ~= false) then continue end
		if IsValid(owner.zcnpc_rag) then continue end
		if not owner:IsOnFire() then continue end

		burning = burning or {}
		burning[#burning + 1] = owner
	end

	if not burning then return end

	for _, npc in ipairs(burning) do
		FloorBurning(npc)
	end
end)
--//
