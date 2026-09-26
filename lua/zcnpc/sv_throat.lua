--[[
	A knife across an NPC's throat.

	Z-City can already do this and mostly does not. The carotid is a real organ
	with a real box around it, and the box is two of them, one either side of the
	neck bone, each a quarter of a unit thick
	(organism/tier_0/sh_hitboxorgans_manual.lua:64). A blade has to pass through
	that quarter unit for hg.organism.input_list.arteria to hear about it, which
	is a fraction of the neck, which is a fraction of a man - so cutting a throat
	on purpose came down to a swing landing inside half a unit of the right place,
	and a knife to the neck came out as a cut on the neck.

	Nothing here widens that box or touches how it works on players. What it does
	is answer the same question a second time for an NPC, off where the blade
	landed rather than off what it passed through: within zcnpc_throat_edge of the
	neck bone is across the throat, and zcnpc_throat_cut is how often that opens
	the artery. Z-City's own trace still gets the first say, and when it has
	already cut - org.arteria is 1 - this is a no-op, because a throat can only be
	opened once.

	What an opened carotid is is Z-City's business and it is not gentle: o2 falls
	off a cliff (modules/sv_blood.lua:99) while the artery pumps blood out at a
	rate set by the pulse, so an NPC with its throat cut has some seconds of
	being able to fight and then no more of them, unless somebody gets a tourniquet
	on it (weapon_hg_medicine_base.lua:613).

	A man who never saw it coming is easier to cut than one facing you, which is
	the whole of why anybody creeps up behind anybody. So the roll is doubled from
	behind, and doubled for a body already on the floor.
]]

local cfg = ZCNPC.Config

local NECK = "ValveBiped.Bip01_Neck1"

-- Doubled, not made certain: a slit throat from behind should be the way it
-- usually goes and not the way it always goes.
local SURPRISE = 2

-- Sounds like the cut it is rather than like a stab. Z-City voices its own
-- suicide with the blade's flesh hit, so a blade that brought one is asked first.
local CUT_SOUND = "player/flesh/flesh_bullet_impact_03.wav"

-- How much of an artery this counts as opening. Z-City's own cut throat passes 5
-- (weapon_melee.lua:1064) and anything at or above 2 is past hitArtery's own
-- one-in-five gate for a light slash, which has already had its say by the time
-- we are asked (modules_input/sv_organs.lua:166).
local CUT_DAMAGE = 5

--\\ Was that a blade
-- Z-City's melee weapons are one base with a damage type on it: DMG_SLASH is the
-- knives and DMG_CLUB is the crowbars and stunsticks, so a blade is a melee weapon
-- that arrived as a slash. Which keeps a manhack out of it - DMG_SLASH with no
-- weapon behind it at all - and keeps every knife in, including ones nobody here
-- has heard of.
local function Blade(dmgInfo)
	if not dmgInfo:IsDamageType(DMG_SLASH) then return false end

	local IsMelee = ZCNPC.IsMeleeWeapon
	if not IsMelee then return false end

	local inflictor = dmgInfo:GetInflictor()
	if IsValid(inflictor) and inflictor:IsWeapon() and IsMelee(inflictor:GetClass()) then return true end

	-- A swing lands out of a timer on the weapon and the inflictor on it is not
	-- always the weapon (weapon_melee.lua:1819). What is in the attacker's hands
	-- at the time is the same knife.
	local att = dmgInfo:GetAttacker()
	local held = IsValid(att) and att.GetActiveWeapon and att:GetActiveWeapon()

	return IsValid(held) and IsMelee(held:GetClass())
end
--//

--\\ Did it land on the throat
-- Off the entry hole Z-City hands over, which is where the blade went in rather
-- than where the man is (ZCNPC.HitPos, sv_damage.lua). Measured against the neck
-- bone of whichever of the two bodies took the hit, since a downed NPC is a
-- ragdoll standing in for it and its bones are the ones in the world.
local function NeckHit(ent, dmgInfo, inputHole)
	local bone = ent:LookupBone(NECK)
	if not bone then return end

	local pos = ZCNPC.HitPos(ent, dmgInfo, inputHole)
	if not pos then return end

	local neck = ent:GetBonePosition(bone)
	if not isvector(neck) then return end

	local edge = cfg.throat_edge and cfg.throat_edge:GetFloat() or 6

	if neck:DistToSqr(pos) > edge * edge then return end

	return pos
end
--//

--\\ Did it see the knife
-- Behind is a half turn away from where it is looking, which for a standing NPC
-- is where its head is pointed rather than where its feet are: an NPC covering a
-- corridor and looking down it is not caught out by somebody in front of it.
local function Unaware(npc, org)
	if org.otrub or org.alive == false then return true end
	if IsValid(npc.zcnpc_rag) then return true end -- on the floor
	if npc:IsRagdoll() then return true end

	if not npc:IsNPC() then return false end

	-- Nothing to be alert about. An NPC standing around has no more reason to
	-- expect a knife than a body does.
	local enemy = npc:GetEnemy()
	if not IsValid(enemy) then return true end

	return false
end

local function Behind(npc, pos)
	if not (npc:IsNPC() and isvector(pos)) then return false end

	local eyes = npc.EyeAngles and npc:EyeAngles() or npc:GetAngles()
	local to = pos - npc:WorldSpaceCenter()

	to.z = 0
	if to:LengthSqr() < 1 then return false end

	return eyes:Forward():Dot(to:GetNormalized()) < 0
end

local function Chance(npc, org, att)
	local base = cfg.throat_cut and cfg.throat_cut:GetFloat() or 0
	if base <= 0 then return 0 end

	if Unaware(npc, org) then return math.min(base * SURPRISE, 1) end

	local from = IsValid(att) and att:WorldSpaceCenter() or nil
	if from and Behind(npc, from) then return math.min(base * SURPRISE, 1) end

	return math.min(base, 1)
end
--//

--\\ Opening it
-- Everything Z-City's own cut throat does, which is the artery itself and a
-- handful of bleeding cuts around it so there is something to see. The direction
-- is the swing's, so the arterial spray comes off the neck the way the blade went.
local function Cut(ent, org, dmgInfo, pos)
	local list = istable(hg) and istable(hg.organism) and hg.organism.input_list
	local artery = istable(list) and list.arteria
	if not isfunction(artery) then return false end

	local dir = dmgInfo:GetDamageForce()
	if not isvector(dir) or dir:LengthSqr() < 1 then dir = -ent:GetAngles():Forward() end

	artery(org, 0, CUT_DAMAGE, dmgInfo, nil, dir:GetNormalized(), pos)

	if org.arteria ~= 1 then return false end

	-- Spread over the next couple of seconds the way Z-City's own does, so the cut
	-- opens up rather than arriving whole.
	if isfunction(hg.organism.AddWoundManual) then
		for _ = 1, 5 do
			hg.organism.AddWoundManual(ent, 50, VectorRand(-2, 2), angle_zero, NECK, CurTime() + math.Rand(0, 2))
		end
	end

	ent:EmitSound(CUT_SOUND, 60, math.random(95, 105))

	-- A cut throat is a thing to panic about. Both are Z-City's own numbers for
	-- somebody who has just had theirs cut (weapon_melee.lua:1070).
	org.fear = math.max(org.fear or 0, 1)
	org.painadd = (org.painadd or 0) + 10

	return true
end
--//

hook.Add("HomigradDamage", "zcnpc_throat", function(victim, dmgInfo, _, _, _, _, inputHole)
	if not (ZCNPC.Enabled() and IsValid(victim)) then return end

	local org = victim.organism
	if not org then return end

	-- Standing NPC, or the body one is lying as. Both are the same neck.
	local npc = victim:IsNPC()
	local body = victim.zcnpc_npcbody and victim:IsRagdoll()
	if not (npc or body) then return end

	-- Already cut, and it cannot be cut twice. Asked before any of the work below
	-- because Z-City's own trace opening it is the common case on a clean swing.
	if org.arteria == 1 then return end

	if not Blade(dmgInfo) then return end

	local pos = NeckHit(victim, dmgInfo, inputHole)
	if not pos then return end

	-- The NPC decides how alert it is even when the body took the hit.
	local subject = npc and victim or (IsValid(victim.zcnpc_npc) and victim.zcnpc_npc) or victim

	if math.random() > Chance(subject, org, dmgInfo:GetAttacker()) then return end

	if Cut(victim, org, dmgInfo, pos) then
		ZCNPC.Debug("throat cut:", victim)
	end
end)
