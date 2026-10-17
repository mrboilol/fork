--[[
	NPCs stitching themselves up with 1nazuma's surgical kit.

	Everything else an NPC treats itself with is a moment: pills are swallowed
	where it stands, a wrap costs it a duck behind a wall (sv_medical.lua). The CMS
	kit is not that. It is twelve seconds of kneeling with both hands full and a
	needle in a leg, and the item itself says as much - a player who moves during
	it tears the wound wider than it was.

	So it is treated as the thing it is rather than as a bigger bandage. An NPC
	only reaches for it when there is nobody left to shoot at: no enemy it knows
	about, nothing hostile within earshot, and not while the map is driving it
	somewhere. Then it stops, takes the kit out - the real weapon_cms, so the model
	is in its hands and everyone can see what it is doing - and works for twelve
	seconds with the suturing loop playing off its chest.

	Anything that ends the quiet ends the surgery: somebody comes round the corner,
	it gets shot, it goes down. Nothing is spent and nothing is made worse; it
	simply puts the kit away and waits a while before trying again, because a
	needle dropped in a firefight is a needle you still have.

	What it repairs is what the kit repairs for a player (weapon_cms.lua:1035):
	open wounds and the bleeding from them, arteries in the limbs, and legs, arms
	and a pelvis that have been shot through. Not the carotid, not a chest, not a
	skull - those are the wounds the kit tells a player to find a real surgeon for,
	and an NPC does not get a better version of it.
]]

local cfg = ZCNPC.Config

-- Adopted rather than created: this file is read before the one that owns the
-- registry (sv_core.lua), and both write it the same way so whoever gets there
-- first makes the table and the other one takes it.
ZCNPC.NPCs = ZCNPC.NPCs or setmetatable({}, { __mode = "k" })

local npcRegistry = ZCNPC.NPCs

local CMS_CLASS = "weapon_cms"

-- The item says fourteen. Twelve is what this addon's NPCs take, because they
-- start the clock from a standing decision rather than from a held mouse button
-- and there is no player watching a progress bar to make the difference read.
local USE_TIME = 12

-- The kit's own suturing loop, played off the NPC's chest for the length of the
-- operation. Taking it out is not here: the SWEP emits its own draw sound from
-- Deploy (weapon_medbase.lua:869) the moment the NPC selects it, and playing one
-- as well is the same noise twice.
local SUTURE_LOOP = "weapons/eft/surgicalkit/suturing.wav"
local DONE_SOUND = "snd_jack_hmcd_bandage.wav"

-- How far away something hostile has to be before an NPC will get the needle
-- out. Deliberately most of a street: the whole point of the item is that it is
-- used somewhere nothing is going to walk into.
local ALONE_RANGE = 1400

local RETRY_AFTER = 20 -- seconds before another go once one was interrupted
local START_DELAY = 3 -- seconds of quiet before it believes the quiet

-- What the kit can close, in Z-City's own limb names (weapon_cms.lua:465).
local LIMBS = { "lleg", "rleg", "pelvis", "larm", "rarm" }

function ZCNPC.CmsInstalled()
	return isfunction(weapons.GetStored) and weapons.GetStored(CMS_CLASS) ~= nil
end

local function Enabled()
	if not ZCNPC.Enabled() then return false end
	if cfg.cms and not cfg.cms:GetBool() then return false end

	return ZCNPC.CmsInstalled()
end

--\\ Holding the kit without it curing anybody on contact
-- weapon_cms.lua:164 heals whoever picks it up the moment it changes hands, if
-- that somebody is an NPC - a straight NPCHeal, engine health and the item gone.
-- That is the right answer for an NPC that walks over one on the floor and the
-- wrong one for an NPC we are handing it to on purpose, so the one call is
-- stepped over while our own surgery owns the kit. Everything else the SWEP does
-- is left alone.
local function PatchPickup()
	local stored = weapons.GetStored(CMS_CLASS)
	if not istable(stored) then return end
	if rawget(stored, "zcnpc_cms") then return end

	local orig = rawget(stored, "OwnerChanged") or stored.OwnerChanged

	rawset(stored, "zcnpc_cms", true)
	rawset(stored, "OwnerChanged", function(self, ...)
		local owner = self:GetOwner()

		-- Either kit of ours: its own surgery, or the one it is holding over
		-- somebody on the floor (sv_rescue.lua).
		if IsValid(owner) and (istable(owner.zcnpc_cms) or istable(owner.zcnpc_rescue)) then return end

		if isfunction(orig) then return orig(self, ...) end
	end)
end

hook.Add("InitPostEntity", "zcnpc_cms", PatchPickup)
hook.Add("OnReloaded", "zcnpc_cms", PatchPickup)
PatchPickup()
--//

--\\ A surgical kit is not a weapon, and the kit does not know that
-- As far as the AI is concerned the kit is a SWEP like any other. It inherits
-- weapon_base, which tells the engine that every weapon can shoot
-- (weapon_base/init.lua:73) and turns the engine asking for a shot into
-- SWEP:PrimaryAttack (:95). So an NPC that finds an enemy while the needle is out
-- fires the surgical kit at it - and PrimaryAttack goes straight to StartUse, which
-- was written for the only thing that could ever have reached it. Its third line
-- freezes the operator where it stands with Player:SetAllowWeaponsInVehicle
-- (weapon_cms.lua:775), and an NPC is not a player and does not have it.
--
-- That is the twelve-deep error, and twelve is one burst: the engine asks a weapon
-- for a shot as many times as the burst is long. It is rare because it needs
-- somebody to come round the corner during one operation - the surgery already waits
-- for three seconds of quiet before it starts and gives up the moment the quiet ends
-- (Running below), so the window is the half second between those two.
--
-- Nothing of ours goes through PrimaryAttack. The kit is held for the model and the
-- stitching is done here (Finish below), so the kit refusing NPCs outright costs us
-- nothing, and a player's kit is not touched by any of it.
--
-- The whole medbase family rather than the one class we hand out: the surgical kit,
-- the defibrillator and the surv12 all freeze their operator the same way from the
-- same line, so an NPC that walks over any of the three off the floor crashes on the
-- same missing method.
local MEDBASE = "weapon_medbase"

local function NpcHolding(wep)
	local owner = wep.GetOwner and wep:GetOwner()

	return IsValid(owner) and owner:IsNPC()
end

-- GetCapabilities and NPCShoot_* are only ever asked by the AI, so there is no
-- player answer to keep: a kit says it can do nothing and is never asked to shoot.
-- The rest are the player's, so those are refused for NPCs and handed on for
-- everybody else.
--
-- Think is on that list for the same reason StartUse is. Its first question is
-- whether the owner is holding the attack button down (weapon_medbase.lua:149), and
-- Player:KeyDown is another method an NPC does not have - so it is the same crash
-- one layer along, waiting for whatever calls a held weapon's Think on an NPC.
local function PatchNpcUse(stored)
	if not istable(stored) then return end
	if rawget(stored, "zcnpc_cms_noattack") then return end

	rawset(stored, "zcnpc_cms_noattack", true)

	rawset(stored, "GetCapabilities", function() return 0 end)
	rawset(stored, "NPCShoot_Primary", function() end)
	rawset(stored, "NPCShoot_Secondary", function() end)

	for _, name in ipairs({ "PrimaryAttack", "SecondaryAttack", "StartUse", "Think" }) do
		local orig = rawget(stored, name)
		if not isfunction(orig) then continue end

		rawset(stored, name, function(self, ...)
			if NpcHolding(self) then return end

			return orig(self, ...)
		end)
	end
end

local function BlockNpcUse()
	if not (istable(weapons) and isfunction(weapons.GetStored)) then return end

	PatchNpcUse(weapons.GetStored(MEDBASE))

	-- Children keep whatever they write for themselves, and the surgical kit writes
	-- its own PrimaryAttack (weapon_cms.lua:1103), so each is patched where it says
	-- it rather than left to the base.
	for _, wep in ipairs(weapons.GetList()) do
		local class = wep.ClassName
		if not isstring(class) or class == MEDBASE then continue end
		if not weapons.IsBasedOn(class, MEDBASE) then continue end

		PatchNpcUse(weapons.GetStored(class))
	end

	-- And any already in somebody's hands: a weapon copies the class table into its
	-- own when it is created, so one that existed before this ran still holds the old
	-- answers (the same reason sv_disarmed.lua ends this way).
	for _, wep in ipairs(ents.GetAll()) do
		if wep:IsWeapon() and weapons.IsBasedOn(wep:GetClass(), MEDBASE) then
			PatchNpcUse(wep:GetTable())
		end
	end
end

hook.Add("InitPostEntity", "zcnpc_cms_noattack", BlockNpcUse)
hook.Add("OnReloaded", "zcnpc_cms_noattack", BlockNpcUse)
BlockNpcUse()
--//

--\\ Is there anything here worth stitching, and is it quiet enough to do it
local function Treatable(org)
	if not istable(org) then return false end
	if org.alive == false then return false end

	if istable(org.wounds) and #org.wounds > 0 then return true end

	if istable(org.arterialwounds) then
		for _, wound in ipairs(org.arterialwounds) do
			-- The carotid is the one artery the kit gives up on.
			if wound[7] ~= "arteria" then return true end
		end
	end

	for i = 1, #LIMBS do
		if (org[LIMBS[i]] or 0) > 0 then return true end
	end

	return false
end

ZCNPC.CmsTreatable = Treatable

local function Threat(npc, ent)
	if not IsValid(ent) or ent == npc then return false end

	if ent:IsPlayer() then
		if not ent:Alive() then return false end
	elseif ent:IsNPC() then
		if ent:Health() <= 0 then return false end

		-- A body on the floor is not somebody to keep the kit in the bag for, and
		-- the husk behind it is not standing anywhere (sv_uncon.lua).
		if ZCNPC.IsHidden(ent) then return false end
	else
		return false
	end

	if not isfunction(npc.Disposition) then return false end

	return npc:Disposition(ent) == D_HT
end

-- Nothing alive and hostile within `range`, and nothing it is already angry with.
-- Shared with the body search (sv_looting.lua) and the rescue (sv_rescue.lua), which
-- want the same answer to the same question for the same reason: all three are things a
-- person only does when they are fairly sure they are not about to be shot.
--
-- And all three ask it in the same tick, of the same NPC, over the same thousand units,
-- because they are all called from one walk of the organism list (sv_disarmed.lua). So
-- the answer is kept for the tick it was worked out in: three sweeps of the world become
-- one, and nothing has to know that anybody else asked. Keyed on the range as well,
-- since the surgery's idea of quiet is wider than the other two.
--
-- Only for the tick. A firefight starting is exactly the news this is for, and a cache
-- with a life of its own is a rebel kneeling down in front of somebody who has just
-- walked round the corner.
local quiet = setmetatable({}, { __mode = "k" })

function ZCNPC.NoThreatNear(npc, range)
	if not (IsValid(npc) and npc:IsNPC()) then return false end

	range = range or ALONE_RANGE

	local last = quiet[npc]
	if last and last.at == CurTime() and last.range == range then return last.answer end

	local answer = true

	if Threat(npc, npc:GetEnemy()) then
		answer = false
	else
		-- The people rather than the sphere. Threat says no to anything that is not
		-- a player or an NPC before it asks anything else, so these two lists are
		-- the same question FindInSphere was being asked and none of the scenery it
		-- used to come back with. Distance by hand because that is what the sphere
		-- was for, and squared because a square root to compare against a constant
		-- is a square root nobody needs.
		local origin = npc:GetPos()
		local rangeSqr = range * range

		for other in pairs(npcRegistry) do
			if IsValid(other) and origin:DistToSqr(other:GetPos()) < rangeSqr and Threat(npc, other) then
				answer = false

				break
			end
		end

		if answer then
			local players = ZCNPC.Players and ZCNPC.Players() or player.GetAll()

			for i = 1, #players do
				local ply = players[i]

				if origin:DistToSqr(ply:GetPos()) < rangeSqr and Threat(npc, ply) then
					answer = false

					break
				end
			end
		end
	end

	if last then
		last.at, last.range, last.answer = CurTime(), range, answer
	else
		quiet[npc] = { at = CurTime(), range = range, answer = answer }
	end

	return answer
end

local function Alone(npc)
	return ZCNPC.NoThreatNear(npc, ALONE_RANGE)
end
--//

--\\ Twelve seconds of not going anywhere
-- Standing still that long is not something an NPC does on its own: the combat AI
-- hands it a schedule the moment it has an opinion and every one of them moves its
-- feet. Re-issuing a stand is how the rest of the addon owns a pair of feet
-- (sv_getup.lua), and on its own it was not enough for twelve seconds of them: it
-- was re-issued from the half second pass, so anything that pushed a walk got half
-- a second of walking out of it, twenty-odd times over one operation. Which is the
-- one thing the item says must not happen - a player who moves mid-surgery tears
-- the wound wider than it was.
--
-- So the feet are taken rather than argued with. The movement capabilities go for
-- as long as the needle is out, and an NPC that cannot path cannot be sent
-- anywhere by anybody - not by its squad, not by an AI addon that has never heard
-- of us. The stand is still re-issued underneath ten times a second, because a
-- schedule that is already walking does not stop when the capability under it is
-- taken away.
local FEET = { CAP_MOVE_GROUND, CAP_MOVE_JUMP, CAP_MOVE_CLIMB }

local operating = {} -- [npc] = true, for the length of one operation

local function HoldStill(npc, state)
	local caps = npc:CapabilitiesGet()

	-- Read once and kept, so one it never had is not handed out at the end of the
	-- surgery as though it had been.
	if not state.caps then
		local had = {}

		for i, cap in ipairs(FEET) do
			had[i] = bit.band(caps, cap) ~= 0
		end

		state.caps = had
	end

	-- Every tick rather than once: an NPC that picks something up rebuilds its own
	-- capabilities, and so do the AI addons.
	for _, cap in ipairs(FEET) do
		if bit.band(caps, cap) ~= 0 then npc:CapabilitiesRemove(cap) end
	end

	npc:StopMoving()

	if npc:GetCurrentSchedule() ~= SCHED_IDLE_STAND then
		npc:SetSchedule(SCHED_IDLE_STAND)
	end
end

local function FreeFeet(npc, state)
	local had = state.caps
	state.caps = nil

	if not (had and IsValid(npc)) then return end

	for i, cap in ipairs(FEET) do
		if had[i] then npc:CapabilitiesAdd(cap) end
	end
end

-- Seconds past its own clock before an operation nobody is coming back for is
-- ended from here instead.
local STALE = 3

timer.Create("zcnpc_cms_hold", 0.1, 0, function()
	if not next(operating) then return end

	for npc in pairs(operating) do
		local state = IsValid(npc) and npc.zcnpc_cms

		if not istable(state) then
			operating[npc] = nil

			continue
		end

		-- Finishing one is the half second pass's job, and the pass is the thing
		-- that stops being called: switch the addon off mid-operation and it never
		-- comes back to this NPC. Taking a pair of feet away is not something to do
		-- on the assumption that somebody else will hand them back, so the hold
		-- ends the operations that outlive their own clock.
		if CurTime() > state.until_ + STALE then
			ZCNPC.CancelCms(npc, "nobody came back for it")

			continue
		end

		HoldStill(npc, state)
	end
end)
--//

--\\ Starting, ending and finishing
local function StopLoop(state)
	if not state.sound then return end

	state.sound:Stop()
	state.sound = nil
end

-- Puts the rifle back in the hands it came out of. The kit is removed rather
-- than dropped: it was never a thing lying in the world, it came out of the
-- NPC's own kit roll and the roll is what is spent.
local function PutAway(npc, state)
	StopLoop(state)

	operating[npc] = nil

	local wep = state.wep
	if IsValid(wep) then wep:Remove() end

	if not IsValid(npc) then return end

	FreeFeet(npc, state)

	-- After the kit is gone, not before: while this is set the SWEP's own
	-- pick-up heal is stepped over, and the last thing the kit does on its way out
	-- must still be stepped over.
	npc.zcnpc_cms = nil

	local back = state.hadclass
	if not back then return end

	-- Only if it is still holding it. Losing the rifle mid-surgery is one of the
	-- things that ends a surgery, and re-selecting a gun that is on the floor now
	-- leaves an NPC aiming an empty hand.
	for _, held in ipairs(npc:GetWeapons() or {}) do
		if IsValid(held) and held:GetClass() == back then
			npc:SelectWeapon(back)

			return
		end
	end
end

local function Cancel(npc, why)
	if not IsValid(npc) then return end

	local state = npc.zcnpc_cms
	if not istable(state) then return end

	PutAway(npc, state)

	-- Nothing spent and no new hole: a needle put away in a hurry is a needle you
	-- still have, and an NPC that got shot at halfway through has enough wrong
	-- with it already. The wait is so it does not kneel back down in the same
	-- doorway the moment the shooting pauses.
	npc.zcnpc_cms_retry = CurTime() + RETRY_AFTER

	ZCNPC.Debug("cms cancelled", npc, why or "?")
end

ZCNPC.CancelCms = Cancel

-- Everything weapon_cms.lua:1035 does for a player, against an organism - the one
-- inside the NPC holding the kit, or the one in the body it is kneeling over
-- (sv_rescue.lua), which is the same set of wounds and the same needle either way.
-- The entity passed in is only who the netvars go out as, and it is a fallback at
-- that: an organism holding itself is asked instead.
local function Stitch(ent, org)
	local owner = IsValid(org.owner) and org.owner or ent
	local did = false

	if istable(org.arterialwounds) and #org.arterialwounds > 0 then
		local keep = {}

		for _, wound in ipairs(org.arterialwounds) do
			if wound[7] == "arteria" then
				keep[#keep + 1] = wound
			else
				org[wound[7]] = 0
				did = true
			end
		end

		org.arterialwounds = keep
		owner:SetNetVar("arterialwounds", keep)
	end

	if istable(org.wounds) and #org.wounds > 0 then
		org.wounds = {}
		org.bleed = 0
		owner:SetNetVar("wounds", org.wounds)
		did = true
	end

	for i = 1, #LIMBS do
		local limb = LIMBS[i]

		if (org[limb] or 0) > 0 then
			org[limb] = 0
			did = true
		end
	end

	return did
end

-- The needle, and what it takes to be seen holding it. The rescue works out of the
-- same kit roll on somebody else's wounds, and none of that is worth a second copy
-- of: the item's class, its own suturing loop, the note it ends on, and how long a
-- kit takes in this addon's hands.
ZCNPC.CmsStitch = Stitch
ZCNPC.CmsKit = {
	class = CMS_CLASS,
	loop = SUTURE_LOOP,
	done = DONE_SOUND,
	time = USE_TIME,
}

local function Finish(npc)
	local state = npc.zcnpc_cms
	if not istable(state) then return end

	local org = ZCNPC.ResolveOrganism(npc)

	PutAway(npc, state)

	if istable(org) then Stitch(npc, org) end

	npc:EmitSound(DONE_SOUND, 70, math.random(95, 105))

	if ZCNPC.MarkLootSpent then ZCNPC.MarkLootSpent(npc, CMS_CLASS) end

	ZCNPC.Debug("cms surgery done", npc)
end

local function Begin(npc)
	local held = npc:GetActiveWeapon()

	local state = {
		until_ = CurTime() + USE_TIME,
		hadclass = IsValid(held) and held:GetClass() or nil,
	}

	-- Set before the kit is handed over: PatchPickup reads it to know this is our
	-- surgery rather than an NPC stumbling over a kit on the floor.
	npc.zcnpc_cms = state

	local wep = npc:Give(CMS_CLASS)
	if not IsValid(wep) then
		npc.zcnpc_cms = nil
		npc.zcnpc_cms_retry = CurTime() + RETRY_AFTER

		return false
	end

	state.wep = wep
	npc:SelectWeapon(CMS_CLASS)

	-- Before the first pass rather than at it: the half second between deciding and
	-- being told to stand still was a step out of cover.
	operating[npc] = true
	HoldStill(npc, state)

	state.sound = CreateSound(npc, SUTURE_LOOP)
	if state.sound then state.sound:Play() end

	ZCNPC.Debug("cms surgery started", npc)

	return true
end
--//

--\\ The pass, from the 0.5s walk in sv_disarmed.lua
-- Only the reasons to stop are decided here. The feet are held ten times a second
-- by the timer above, because half a second of them is half a second of walking.
local function Running(npc, state)
	-- The half second pass is the one thing that is certain to be walking every
	-- surgery, so it is what puts a surgery back on the list of feet to hold. A
	-- reloaded file starts with an empty list and an operation in progress.
	operating[npc] = true

	if not Enabled() then
		Cancel(npc, "switched off")

		return
	end

	if IsValid(npc.zcnpc_rag) then
		Cancel(npc, "went down")

		return
	end

	if npc:GetNetVar("handcuffed", false) then
		Cancel(npc, "cuffed")

		return
	end

	local org = ZCNPC.ResolveOrganism(npc)
	if not istable(org) or org.alive == false or org.otrub then
		Cancel(npc, "not conscious")

		return
	end

	if not Alone(npc) then
		Cancel(npc, "no longer alone")

		return
	end

	if CurTime() >= state.until_ then
		Finish(npc)
	end
end

function ZCNPC.UpdateCms(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return end

	local state = npc.zcnpc_cms
	if istable(state) then
		Running(npc, state)

		return
	end

	if not Enabled() then return end
	if IsValid(npc.zcnpc_rag) then return end
	if ZCNPC.IsZombie(npc) then return end
	if (npc.zcnpc_cms_retry or 0) > CurTime() then return end
	-- Not with something else already in its hands (sv_medical.lua): Give would put the kit
	-- on top of a bandage and the bandage's own put-away would take the kit back off again.
	if istable(npc.zcnpc_meduse) then return end
	if npc:GetNetVar("handcuffed", false) then return end
	if ZCNPC.HasHeadcrab and ZCNPC.HasHeadcrab(npc) then return end
	if (ZCNPC.GettingUp[npc] or 0) > CurTime() then return end

	-- Twelve seconds on one knee is a schedule, and where a scripted NPC stands is
	-- the map's to say (sv_core.lua).
	if ZCNPC.MapDriven(npc) then return end

	-- Mid-errand: fetching a gun, crossing to a vest, kneeling over an ally. Those
	-- own the feet and the kit can wait for them.
	if IsValid(npc.zcnpc_fetch) or IsValid(npc.zcnpc_fetcharmor) then return end
	if IsValid(npc.zcnpc_healally) then return end

	-- A body search holds the feet the same way this does, and both snapshotting the
	-- capabilities at once loses whichever restore runs first. Waiting is free: a
	-- search is two and a half seconds and this needs three of quiet to start anyway.
	if npc.zcnpc_lootcrouch then return end

	-- Same reason, and a stronger one: a rescue (sv_rescue.lua) is holding the feet
	-- for as long as it takes to walk a man out and work on him, and it borrows this
	-- very kit to do the stitching with. Its own wounds can wait until it has put
	-- somebody else's back together.
	if istable(npc.zcnpc_rescue) then return end

	if not (ZCNPC.KitHasItem and ZCNPC.KitHasItem(npc, CMS_CLASS)) then return end

	local org = ZCNPC.ResolveOrganism(npc)
	if not Treatable(org) then return end
	if org.otrub then return end

	-- Quiet has to hold for a few seconds before it is believed. Without this an
	-- NPC kneels down in the half second between the man it was shooting at going
	-- behind a wall and coming back out of it.
	if not Alone(npc) then
		npc.zcnpc_cms_quiet = nil

		return
	end

	if not npc.zcnpc_cms_quiet then
		npc.zcnpc_cms_quiet = CurTime() + START_DELAY

		return
	end

	if npc.zcnpc_cms_quiet > CurTime() then return end

	npc.zcnpc_cms_quiet = nil
	Begin(npc)
end
--//

-- A body on the floor is not doing surgery on itself, and the two ways one gets
-- there are the two ways this ends without the pass noticing first.
hook.Add("ZCNPC_Downed", "zcnpc_cms", function(npc)
	Cancel(npc, "downed")
end)

hook.Add("ZCNPC_Disarmed", "zcnpc_cms", function(npc)
	if not (IsValid(npc) and istable(npc.zcnpc_cms)) then return end

	Cancel(npc, "disarmed")
end)

-- Being shot at is the whole of the reason this only happens when nobody is
-- about, so being hit is not something to work through.
hook.Add("HomigradDamage", "zcnpc_cms", function(victim)
	if not (IsValid(victim) and istable(victim.zcnpc_cms)) then return end

	Cancel(victim, "took a hit")
end)
