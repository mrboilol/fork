--[[
	What an injury leaves behind.

	Z-City tracks a great deal about the state of a body and spends almost none of
	it on an NPC. Every limb has its own damage total, every one of them can be
	dislocated, broken through or taken off, there is a disorientation counter that
	a blast or a blow to the head fills - and an NPC carrying all of it walks and
	shoots exactly as well as one that has just been spawned. All of that reaches a
	player, through hg.StunPlayer, through the view punch, through the screen going
	soft at the edges, and every one of those is written against a player entity
	and returns immediately on anything else.

	So the same numbers are read here and turned into the two things an NPC has
	that a player does not: how fast it moves, and how well it shoots.

	* a leg past zcnpc_limb_threshold stops carrying weight. It gives out the
	  moment it goes, which is the NPC on the floor, and it limps afterwards.
	* a head that has been rung - Z-City's own org.disorientation, which is what
	  its client reads to blur a player's screen - shoots badly and is slow to turn
	  onto a target.
	* a tranquilizer puts a body on the floor while it is still awake, and Z-City's
	  own consciousness decay finishes it a few seconds later.

	Nothing here invents a number. Every threshold is either Z-City's own or a
	convar, and the underlying damage is whatever Z-City's bone module already
	wrote down.
]]

local cfg = ZCNPC.Config

-- [npc] = what is currently applied to it, so it can be taken back off. Weak keys:
-- an NPC that is removed takes its entry with it.
ZCNPC.Status = ZCNPC.Status or setmetatable({}, { __mode = "k" })

--\\ Reading the organism
local LEGS = { { dmg = "lleg", off = "llegamputated", loose = "llegdislocation" },
	{ dmg = "rleg", off = "rlegamputated", loose = "rlegdislocation" } }

local ARMS = { { dmg = "larm", off = "larmamputated", loose = "larmdislocation" },
	{ dmg = "rarm", off = "rarmamputated", loose = "rarmdislocation" } }

-- A limb is finished if it has been shot past the threshold, taken off, or pulled
-- out of its socket - Z-City counts a dislocation as a limb that cannot be used
-- and so does this.
local function Broken(org, limb, threshold)
	return org[limb.off] == true or org[limb.loose] == true or (org[limb.dmg] or 0) >= threshold
end

local function BrokenCount(org, limbs, threshold)
	local n = 0

	for _, limb in ipairs(limbs) do
		if Broken(org, limb, threshold) then n = n + 1 end
	end

	return n
end

-- Both legs past the failure point (or off / out of joint). Used by the wake-up
-- gate as well as the limp: Z-City only blocks get-up at a hard 1.0 on each leg,
-- which is past where we already call a leg finished.
function ZCNPC.BothLegsBroken(org)
	if not istable(org) then return false end

	local threshold = cfg.limb_threshold:GetFloat()

	return Broken(org, LEGS[1], threshold) and Broken(org, LEGS[2], threshold)
end

-- Z-City's own line for "this one cannot see straight": its client blurs a
-- player's screen past three and rolls the camera about (cl_main.lua:430).
local CONCUSSED = 3

local function Concussed(org)
	return (org.disorientation or 0) > CONCUSSED
end

local function Sedated(org)
	return (org.tranquilizer or 0) > 0.5
end

ZCNPC.Sedated = Sedated

--\\ Making limbs fail under pistol fire
-- Z-City only writes org.lleg / org.rarm when the bullet trace hits a bone organ
-- box (modules_input/sv_bone.lua). On a standing NPC those boxes are easy to miss,
-- so a magazine into a thigh can leave the limb total at zero. Flesh and artery
-- hits still hurt; they just never counted toward "this leg is finished".
--
-- When the hit location is clearly a limb, add a share of the round to that limb
-- total so six or seven Makarov hits (damage 8 → organ scale 8/25) cross the
-- default failure point with zcnpc_limb_mul at 2.2. Bone-box hits still use
-- Z-City's own path; this is the share that used to land on flesh and count for
-- nothing.
local BONE_TO_LIMB = {
	["ValveBiped.Bip01_L_Thigh"] = "lleg",
	["ValveBiped.Bip01_L_Calf"] = "lleg",
	["ValveBiped.Bip01_L_Foot"] = "lleg",
	["ValveBiped.Bip01_R_Thigh"] = "rleg",
	["ValveBiped.Bip01_R_Calf"] = "rleg",
	["ValveBiped.Bip01_R_Foot"] = "rleg",
	["ValveBiped.Bip01_L_UpperArm"] = "larm",
	["ValveBiped.Bip01_L_Forearm"] = "larm",
	["ValveBiped.Bip01_L_Hand"] = "larm",
	["ValveBiped.Bip01_R_UpperArm"] = "rarm",
	["ValveBiped.Bip01_R_Forearm"] = "rarm",
	["ValveBiped.Bip01_R_Hand"] = "rarm",
}

local HITGROUP_TO_LIMB = {
	[HITGROUP_LEFTLEG] = "lleg",
	[HITGROUP_RIGHTLEG] = "rleg",
	[HITGROUP_LEFTARM] = "larm",
	[HITGROUP_RIGHTARM] = "rarm",
}

local LIMB_DMG = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER + DMG_SLASH + DMG_CLUB

-- Torso / head hitgroups are never limbs. Skip the bone walk (standing NPCs
-- still come in as HITGROUP_GENERIC and go through the cache below).
local NOT_LIMB_HITGROUP = {
	[HITGROUP_HEAD] = true,
	[HITGROUP_CHEST] = true,
	[HITGROUP_STOMACH] = true,
	[HITGROUP_GEAR] = true,
}

-- Cache LookupBone ids on the entity once. Spray used to re-resolve twelve
-- bone names on every pellet.
local function LimbBoneCache(victim)
	local cache = victim.zcnpc_limb_bones
	if cache then return cache end

	cache = {}
	for bone, limb in pairs(BONE_TO_LIMB) do
		local id = victim:LookupBone(bone)
		if id then
			cache[#cache + 1] = { id = id, limb = limb }
		end
	end

	victim.zcnpc_limb_bones = cache

	return cache
end

local function LimbFromHit(victim, hitgroup, dmgInfo, inputHole)
	local fromGroup = HITGROUP_TO_LIMB[hitgroup or -1]
	if fromGroup then return fromGroup end
	if NOT_LIMB_HITGROUP[hitgroup or -1] then return end

	local pos = ZCNPC.HitPos and ZCNPC.HitPos(victim, dmgInfo, inputHole)
	if not isvector(pos) then return end

	-- Nearest limb bone to the hole. Standing NPCs often report HITGROUP_GENERIC;
	-- the wound position still knows which side was hit.
	local best, bestDist
	local bones = LimbBoneCache(victim)

	for i = 1, #bones do
		local entry = bones[i]
		local matrix = victim:GetBoneMatrix(entry.id)
		if not matrix then continue end

		local dist = matrix:GetTranslation():DistToSqr(pos)
		if not bestDist or dist < bestDist then
			best, bestDist = entry.limb, dist
		end
	end

	-- Within about a metre of a limb bone - further away is torso/head noise.
	if best and bestDist and bestDist < (40 * 40) then return best end
end

hook.Add("HomigradDamage", "zcnpc_limbfragility", function(victim, dmgInfo, hitgroup, _, _, _, inputHole)
	if not (ZCNPC.Enabled() and cfg.limbs:GetBool()) then return end
	if not (IsValid(victim) and victim:IsNPC()) then return end
	if not dmgInfo:IsDamageType(LIMB_DMG) then return end

	local org = victim.organism
	if not (istable(org) and org.fakePlayer) or org.alive == false then return end

	local limb = LimbFromHit(victim, hitgroup, dmgInfo, inputHole)
	if not limb then return end

	local threshold = cfg.limb_threshold:GetFloat()
	local prev = org[limb] or 0
	local already = org[limb .. "amputated"]
		or org[limb .. "dislocation"]
		or prev >= threshold

	-- Pellet spam from one shotgun blast: one add / one floor per shot, not per pellet.
	local stamp = victim.zcnpc_limbshot
	if stamp == CurTime() and victim.zcnpc_limbshot_which == limb then return end
	victim.zcnpc_limbshot = CurTime()
	victim.zcnpc_limbshot_which = limb

	-- Another round into a leg that already failed: put them down again. Organ
	-- damage is capped at 1, so LegGaveOut alone never sees a "new" break here.
	if already and (limb == "lleg" or limb == "rleg") and not IsValid(victim.zcnpc_rag) then
		timer.Simple(0, function()
			if IsValid(victim) then ZCNPC.FloorBrokenLimb(victim) end
		end)
	end

	if org[limb .. "amputated"] then return end

	-- Same organ scale Z-City uses (damage/25), times the mul, then a share so a
	-- Makarov (8 → 0.32) at mul 1.0 needs about a dozen hits to reach 0.45.
	local add = (dmgInfo:GetDamage() / 25) * cfg.limb_mul:GetFloat() * 0.1
	if add <= 0 then return end

	org[limb] = math.min(1, prev + add)
end)
--//

--\\ Putting it on the NPC
-- Movement is animation on an NPC: how fast one walks is the ground speed baked
-- into the sequence it is playing, so slowing the sequence is slowing the NPC.
-- It costs a little more than that - everything else the NPC does slows with it,
-- including the rate it works a bolt - which on a man dragging a shattered leg is
-- not the wrong answer.
--
-- It has to be written back regularly. The engine sets the playback rate itself
-- whenever an NPC picks a new activity, so anything written once is gone at the
-- next schedule.
local function ApplySpeed(npc, rate)
	if npc:GetPlaybackRate() ~= rate then npc:SetPlaybackRate(rate) end
end

-- Never zero, however ruined the legs are. A playback rate of nought does not mean
-- "does not get anywhere", it means the skeleton stops: the cycle cannot advance, so
-- an NPC part way into one of Half-Life 2's activity transitions can never finish it
-- and is left holding whichever frame the transition opened on for good. What that
-- looks like is the thing it was reported as - a man sliding about with his arms out,
-- not animating at all - and it survived a wake-up, because the rate is written on
-- the NPC and the wake-up has no reason to touch it.
--
-- A crawl reads the same from the outside and costs nothing: StopMoving below is what
-- actually keeps a man with two dead legs where he is, and it always was.
local CRAWL_RATE = 0.15

-- Nowhere left to stand: Z-City's own hard line, and the one CanWakeUp draws in the
-- same words (sv_uncon.lua). Not zcnpc_limb_threshold, which is a softer line drawn
-- for a different question.
--
-- The difference between the two is a bandage. A wrap does not mend a leg that has
-- been shot through, it takes it from 1.0 to 0.95 and stops there - one twentieth,
-- once, and only ever off a limb at exactly 1 (weapon_hg_medicine_base.lua:412). So
-- 0.95 is not a stage of healing, it is the mark a wrapped leg carries for the rest
-- of the round, and nothing but a splint or the surgical kit ever moves it again.
--
-- Which is the whole of what was reported after a teammate's bandage. 0.95 is over
-- the soft threshold, so a wrapped man counted as both legs gone for good, and both
-- halves of that answer were being written onto him every tick from then on: the
-- playback rate that used to be zero, and a StopMoving. The combat AI does not stop
-- asking for a walk because we cancelled the last one, so it asks again, gets
-- cancelled again, and a man who is told to stop moving ten times a second while
-- something keeps starting him off is a man dropping into the front of a walk
-- transition and never coming out of it - on the schedule's own cadence, which is
-- the sitting down over and over that came with it.
--
-- CanWakeUp had this right and said so at length: the soft threshold is for the limp
-- and for a one-shot knockdown, and using it to mean "cannot stand up" left bandaged
-- NPCs on the floor for good. It means "cannot walk at all" here, which is the same
-- claim about the same legs, so it is drawn the same way. A wrapped man limps.
local function LegsGone(org)
	if org.llegamputated or org.rlegamputated then return true end

	return (org.lleg or 0) >= 1 and (org.rleg or 0) >= 1
end

-- Two separate things go wrong with a rung head and Source has a knob for each.
-- Proficiency is the spread the AI fires with, from a marksman down to somebody
-- who has never held a rifle (WEAPON_PROFICIENCY_POOR is roughly a tenfold cone).
-- Yaw speed is how fast the NPC can turn onto what it is shooting at, which is
-- the difference between being tracked and being lost.
local POOR_YAW = 30

local function ApplyAim(npc, state)
	if state.proficiency == nil then
		state.proficiency = npc.GetCurrentWeaponProficiency and npc:GetCurrentWeaponProficiency()
		state.yaw = npc.GetMaxYawSpeed and npc:GetMaxYawSpeed()
	end

	if npc.SetCurrentWeaponProficiency then npc:SetCurrentWeaponProficiency(WEAPON_PROFICIENCY_POOR) end
	if npc.SetMaxYawSpeed then npc:SetMaxYawSpeed(POOR_YAW) end
end

local function ClearAim(npc, state)
	if state.proficiency == nil then return end

	if npc.SetCurrentWeaponProficiency then npc:SetCurrentWeaponProficiency(state.proficiency) end
	if state.yaw and npc.SetMaxYawSpeed then npc:SetMaxYawSpeed(state.yaw) end

	state.proficiency, state.yaw = nil, nil
end

function ZCNPC.ClearStatus(npc)
	local state = ZCNPC.Status[npc]
	if not state then return end

	if IsValid(npc) then
		ClearAim(npc, state)
		npc:SetPlaybackRate(1)
	end

	ZCNPC.Status[npc] = nil
end

-- The one way out the tick below cannot see. Going down moves the organism onto the
-- body (ZCNPC.MoveOrganism), which takes the NPC out of hg.organism.list - so "Org
-- Think" is called with the ragdoll from then on and every line of the tick that
-- reads owner:IsNPC() stops running for this NPC. The clause in there that was meant
-- to undo all of this on the way down has therefore never once fired.
--
-- What it left behind is a playback rate. A limp writes 0.55 and two ruined legs
-- wrote 0, and both stayed on the husk for as long as it lay there: the entity woke
-- up with its animation still scaled or stopped outright, which is an NPC walking
-- about without animating. sh_workpose.lua ends its crouch off this same hook and
-- says why at length.
hook.Add("ZCNPC_Downed", "zcnpc_status", function(npc)
	ZCNPC.ClearStatus(npc)
end)
--//

--\\ A leg going out from under somebody
-- The moment a leg crosses the line is the moment the NPC hits the ground, and it
-- is a knockdown rather than a knockout: there is nobody switched off here, only
-- somebody whose leg has stopped working. It gets up again - slowly, and on one
-- leg - unless the rest of the damage has an opinion of its own.
--
-- Both legs gone is Z-City's own answer already (sv_organism.lua:102 puts a body
-- with two ruined legs on the floor and keeps it there), so this is about the
-- first one: a short burst through a thigh and that side stops holding.
local FALL_DOWNTIME = 6

local function LegGaveOut(npc, org, broken)
	local was = org.zcnpc_legsdown or 0
	org.zcnpc_legsdown = broken

	if broken <= was then return end -- nothing new gave out
	if IsValid(npc.zcnpc_rag) then return end -- already on the floor

	ZCNPC.Debug("leg gave out on", npc)

	-- Straight down. A leg folding is not a shove, and the shove is what the
	-- knockdown path uses to throw a body clear of whatever hit it.
	timer.Simple(0, function()
		if IsValid(npc) then ZCNPC.Floor(npc, FALL_DOWNTIME) end
	end)
end

-- Another round into a leg that already failed: the first break put them down
-- once; further hits on that same dead leg put them down again (they do not
-- stand there absorbing shots into a limb that cannot hold them).
function ZCNPC.FloorBrokenLimb(npc, downtime)
	if not (IsValid(npc) and npc:IsNPC()) then return end
	if IsValid(npc.zcnpc_rag) then return end

	ZCNPC.Debug("floored by hit to a ruined limb:", npc)
	ZCNPC.Floor(npc, downtime or FALL_DOWNTIME)
end
--//

--\\ A dart
-- Z-City's own handling of a sedative is entirely internal: the dart adds to
-- org.tranquilizer (sv_input.lua:828) and the pain module walks consciousness down
-- from there (modules/sv_pain.lua:87), so the NPC keeps walking about, keeps
-- shooting, and then falls over some seconds later when the number finally reaches
-- Z-City's threshold. Which is not what being darted looks like.
--
-- So the collapse is brought forward to the dart itself and the knockout is left
-- exactly where Z-City has it. The order is the point: down first, awake, and out
-- afterwards - the body drops, lies there for a moment still trying to work out
-- what happened, and then stops.
local SEDATED_DOWNTIME = 60

local function Darted(npc, org)
	if not cfg.tranq:GetBool() then return end

	local sedated = Sedated(org)
	local was = org.zcnpc_sedated == true
	org.zcnpc_sedated = sedated

	if not sedated or was then return end
	if IsValid(npc.zcnpc_rag) then return end

	ZCNPC.Debug("sedated", npc)

	-- Long enough that nothing but the drug wearing off stands it up again. The
	-- monitor asks ZCNPC.Sedated as well before it lets one up, so this is only
	-- the floor under that.
	timer.Simple(0, function()
		if IsValid(npc) then ZCNPC.Floor(npc, SEDATED_DOWNTIME) end
	end)
end
--//

--\\ The tick
-- "Org Think" is run once per organism per tick over the whole of hg.organism.list
-- (organism/tier_0/sv_tier_0.lua:79), which is the same walk Z-City's own modules
-- hang off, so this costs a table lookup on top of work that is happening anyway.
-- ConVar floats cached: Org Think hits every organism every tick.
local cachedLimbThreshold = 0.45
local cachedStatusSpeed = 0.55
local cachedConcussion = true
local cachedLimbs = true
local cachedStatus = true

local function RefreshStatusCvars()
	if cfg.limb_threshold then cachedLimbThreshold = cfg.limb_threshold:GetFloat() end
	if cfg.status_speed then cachedStatusSpeed = cfg.status_speed:GetFloat() end
	if cfg.status_concussion then cachedConcussion = cfg.status_concussion:GetBool() end
	if cfg.limbs then cachedLimbs = cfg.limbs:GetBool() end
	if cfg.status then cachedStatus = cfg.status:GetBool() end
end

hook.Add("InitPostEntity", "zcnpc_status_cvars", RefreshStatusCvars)
timer.Simple(0, RefreshStatusCvars)
for _, name in ipairs({
	"zcnpc_limb_threshold", "zcnpc_status_speed", "zcnpc_status_concussion",
	"zcnpc_limb_damage", "zcnpc_status_effects",
}) do
	cvars.AddChangeCallback(name, RefreshStatusCvars, "zcnpc_status_" .. name)
end

hook.Add("Org Think", "zcnpc_status", function(owner, org)
	if not (ZCNPC.Enabled() and IsValid(owner) and owner:IsNPC()) then return end
	if not (istable(org) and org.fakePlayer) then return end

	if org.alive == false then return ZCNPC.ClearStatus(owner) end

	local threshold = cachedLimbThreshold
	local legs = BrokenCount(org, LEGS, threshold)

	if cachedLimbs then
		LegGaveOut(owner, org, legs)
		Darted(owner, org)

		-- Hard failure only (LegsGone). Soft threshold damage already knocks them
		-- down once via LegGaveOut; re-flooring every tick while both legs sit above
		-- the limp line is what kept bandaged NPCs on the floor.
		if LegsGone(org) and not IsValid(owner.zcnpc_rag) and not org.zcnpc_leglock then
			org.zcnpc_leglock = true
			timer.Simple(0, function()
				if istable(org) then org.zcnpc_leglock = nil end
				if IsValid(owner) and not IsValid(owner.zcnpc_rag) then
					ZCNPC.Floor(owner, FALL_DOWNTIME)
				end
			end)
		end
	end

	if not cachedStatus then return ZCNPC.ClearStatus(owner) end

	-- A body on the floor is not walking or aiming, and the NPC behind it is a
	-- hidden entity with its own reasons for standing still. Only ever reached in the
	-- tick a knockdown lands in - after that the organism is the body's and this hook
	-- is called with the body - so the ZCNPC_Downed hook above is what really undoes
	-- this, and this is the belt to its braces.
	if IsValid(owner.zcnpc_rag) then return ZCNPC.ClearStatus(owner) end

	local arms = BrokenCount(org, ARMS, threshold)
	local limping = legs > 0
	-- Not legs >= 2 (LegsGone says why at length). Two legs over the soft threshold
	-- is a bad limp; two legs actually gone is the only thing that is no walk at all.
	local bothLegs = LegsGone(org)
	local rung = cachedConcussion and (Concussed(org) or Sedated(org))
	-- an arm that cannot hold a rifle steady is the same problem as a head that
	-- cannot aim one, and it arrives by the same route
	local shaky = rung or arms > 0

	if not (limping or shaky) then return ZCNPC.ClearStatus(owner) end

	local state = ZCNPC.Status[owner]
	if not state then
		state = {}
		ZCNPC.Status[owner] = state
	end

	-- One bad leg is a limp. Two is no walk at all - StopMoving every tick because
	-- the schedule keeps asking for ground speed that is no longer there.
	--
	-- Wounded Walk (when installed) scales SetMoveVelocity from the virtual Health
	-- our bridge exposes. Stacking that with SetPlaybackRate reads as half-speed
	-- twice over, so the playback limp steps aside while WW owns movement.
	local wwMove = ZCNPC.WoundedWalkOwnsMove and ZCNPC.WoundedWalkOwnsMove()

	-- A man hauling somebody's weight backwards out of the open is already being slowed by
	-- the thing that has him doing it (sv_rescue.lua), and that is the same knob. Two
	-- reasons to be slow multiply rather than add, and a limping medic at both of them at
	-- once is a medic who never gets the body anywhere.
	local dragging = ZCNPC.DragOwnsMove and ZCNPC.DragOwnsMove(owner)

	if bothLegs then
		if not wwMove then ApplySpeed(owner, CRAWL_RATE) end
		owner:StopMoving()
	elseif dragging then
		-- nothing: the rate is the drag's while the drag lasts, and it puts it back itself
	elseif not wwMove then
		ApplySpeed(owner, limping and cachedStatusSpeed or 1)
	elseif limping then
		-- WW is slowing move velocity; keep animation at full rate so the limp
		-- does not compound. Clear any leftover rate from before WW loaded.
		ApplySpeed(owner, 1)
	end

	if shaky then
		ApplyAim(owner, state)
	else
		ClearAim(owner, state)
	end
end)
--//
