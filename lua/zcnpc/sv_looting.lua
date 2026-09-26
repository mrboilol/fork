--[[
	Rebels going through the dead.

	Everything an NPC picks up elsewhere in the addon it picks up off the floor: a
	rifle that fell out of somebody's hands (sv_disarmed.lua), a helmet knocked
	loose (sv_armor.lua). None of it touches a body, and a body is where most of
	what is worth having actually is - a dead metrocop is a stunstick, a bandage,
	a set of cuffs and whatever he was shooting, and all of it stays on him
	forever because only a player has ever been able to search one.

	So rebels search them. Only rebels: a refugee running from the fighting is not
	going to kneel over a corpse in the middle of it, Combine have a supply line,
	and a squad of every NPC on the map converging on the same body is not a
	scavenging economy, it is a queue. Rebels are the faction the fantasy is
	written for and they are the ones who do it.

	Two things are worth crossing the street for and nothing else is:

	  * A better gun, judged the way anybody judges one - what it does per second
	    and how many rounds it holds. An NPC with nothing in its hands takes
	    anything; one already holding a rifle only trades up.
	  * Medicine, but only what it has already used. A rebel that still has its
	    bandage does not take the dead man's; one that spent it on itself an hour
	    ago and is bleeding again does. That is the "recharge" half of it, and it
	    is why searching a body is not a way to farm an infinite bag.

	    All of it, not the four classes this used to name. The rule was only ever
	    "what it can actually press", and what it can press is now most of the
	    medicine in the game (sv_medical.lua) - so a medkit or a tourniquet lying
	    in a dead rebel's pockets is worth the walk, where before it was left on
	    him because nobody had added it to a list.

	Taken is taken. Whatever a rebel lifts off a body is gone from the inventory a
	player would have found there, through the same spent-flag bookkeeping the
	loot menu uses (sv_loot.lua), so the body cannot hand the same rifle to a
	player and to an NPC.

	And one body is one man's to go through. Four rebels reading the same rifle in
	the same pockets is not a queue either - it is four of them walking to one spot,
	one of them taking it, and three kneeling over an empty corpse.

	Only when it is quiet, for the same reason surgery is (sv_cms.lua): kneeling
	over a corpse with your back to a doorway is not something anybody does while
	being shot at.
]]

local cfg = ZCNPC.Config

local SEARCH = 1100 -- how far a body is worth walking to
local REACH = 72 -- close enough to kneel and go through pockets
local GIVE_UP = 18 -- seconds before a body it cannot reach is written off
local REPATH = 1.25
local COOLDOWN = 8 -- between one search and the next
local QUIET_RANGE = 1000 -- nothing hostile this close before kneeling down

-- And before looking again when there was nothing to find. A rebel standing in a
-- street with no bodies in it used to ask that question twice a second forever, and
-- the question is the expensive one here - so the answer is kept for a moment. Short
-- enough that a man who falls nearby is still gone through while it matters.
local NOTHING = 2

-- How long it spends crouched over the body. Long enough to read as somebody going
-- through a dead man's pockets and short enough that a rebel is not out of the fight
-- for it - the same trade the surgery makes at twelve seconds (sv_cms.lua), which is
-- twelve seconds because the item says so and this is not that.
local SEARCH_TIME = 2.5

-- Seconds past its own clock before a search nobody came back for is ended from the
-- hold instead. sv_cms.lua:220 sets out why a pair of feet is not taken on the
-- assumption that somebody else will hand them back.
local STALE = 3

-- What a rebel would rather have, in that order. Not the whole of what it will take -
-- anything else on the body that sv_medical.lua knows how to use is taken too, and Wanted
-- sweeps for that after these four have had their turn. These are the ones with a reason
-- to come first.
local MEDS = {
	"weapon_bandage_sh",
	"weapon_painkillers",
	"weapon_cms",
	-- Not for itself: a bag of blood is no use to a man holding it who is well
	-- enough to be walking about with it. It is on this list because it is now the
	-- one thing that will fill a friend back up to where he can stand
	-- (sv_rescue.lua), and the medics who carry one only carry one.
	"weapon_bloodbag",
}

local function LootingEnabled()
	return ZCNPC.Enabled() and (not cfg.looting or cfg.looting:GetBool())
end

-- Which end of a rifle is the better one. Shared with the swap an NPC makes for a
-- gun on the floor (sv_disarmed.lua), and it has to be the same measure in both or
-- an NPC will cross a room for something it would then refuse to keep.
local Score = ZCNPC.WeaponScore

--\\ Bodies
local function OwnerAlive(rag)
	if not (istable(hg) and isfunction(hg.RagdollOwner)) then return false end

	local owner = hg.RagdollOwner(rag)

	return IsValid(owner) and owner:IsPlayer() and owner:Alive()
end

-- A body somebody is finished with. Not one of ours that is still breathing on
-- the floor - that one may get up, and going through a wounded man's pockets
-- while he watches is not what was asked for - and not a player who is merely
-- down.
local function DeadBody(rag)
	if not (IsValid(rag) and rag:IsRagdoll()) then return false end
	if ZCNPC.Downed and ZCNPC.Downed[rag] then return false end
	if rag.zcnpc_gettingup then return false end

	local weapons = rag.inventory and rag.inventory.Weapons
	if not (istable(weapons) and next(weapons) ~= nil) then return false end

	if OwnerAlive(rag) then return false end

	local org = rag.organism
	if istable(org) and org.alive ~= false then return false end

	return true
end

--\\ One body, one pair of hands
-- A dead metrocop with four rebels round it is not a scavenging economy, it is a
-- scrum: they all read the same rifle in the same pockets, they all walk to the same
-- spot, and the first one to finish takes it while the other three kneel over an
-- empty body and then stand up again.
--
-- So a body is claimed by whoever is going through it, and the claim is read off the
-- searcher rather than off a flag on the body - the same arrangement the rescue
-- arrived at and for the same reason (sv_rescue.lua at length). Only the searcher's
-- own state can make it true, so no way out of a search has to remember to release
-- anything: a name with no search behind it answers no by itself and is wiped in
-- passing, rather than becoming a body nobody may touch for the rest of the round.
local function Searcher(rag)
	local npc = rag.zcnpc_lootedby
	if not IsValid(npc) then
		rag.zcnpc_lootedby = nil

		return nil
	end

	if npc.zcnpc_lootbody ~= rag then
		rag.zcnpc_lootedby = nil

		return nil
	end

	return npc
end

-- Anybody but this one is going through him.
local function Claimed(npc, rag)
	local by = Searcher(rag)

	return by ~= nil and by ~= npc
end
--//

local function NeedsMed(npc, class)
	if not ZCNPC.KitHasItem then return false end

	-- A kit off a corpse is no use to an NPC that has no code to open one, and the
	-- surgery is the one thing here that lives in another addon.
	if class == "weapon_cms" and not (ZCNPC.CmsInstalled and ZCNPC.CmsInstalled()) then
		return false
	end

	-- Pills are asked about as pills rather than as a class, because a bottle is a bottle
	-- and there are five kinds of them once a medicine pack is mounted (sv_medical.lua).
	if ZCNPC.NpcNeedsPainkillers then
		local pills = ZCNPC.NpcNeedsPainkillers(npc, class)

		if pills ~= nil then return pills end
	end

	-- Already carrying one. The point of the search is what it has run out of.
	return not ZCNPC.KitHasItem(npc, class)
end

-- What this particular body has that this particular rebel wants, or nil.
local function Wanted(npc, rag)
	local weapons = rag.inventory and rag.inventory.Weapons
	if not istable(weapons) then return end

	-- Same question the floor pickup asks of a dropped weapon, one pocket further
	-- in (sv_disarmed.lua): a bandage in the inventory is not a gun.
	local IsGun = ZCNPC.IsGunClass
	if not IsGun then return end

	-- Nothing in its hands is a score of zero, so anything at all beats it. The gun it is
	-- carrying rather than whatever is in the hand this second: an NPC part way through
	-- using a bandage is holding a bandage (sv_medical.lua), which scores nothing, and it
	-- would set off across the street for a rifle it already owns.
	local held = ZCNPC.HeldGun(npc)
	local floor = IsValid(held) and Score(held:GetClass()) or 0
	local gun, gunScore

	-- Classes the engine has already refused to hand this NPC, which is the same note
	-- the floor trade keeps (sv_disarmed.lua). Without reading it a body with one
	-- unattachable rifle in its pockets is a body a rebel walks back to for the rest
	-- of the round, kneels over, fails to take anything from, and sets off for again.
	local refused = npc.zcnpc_fetchbad

	for class in pairs(weapons) do
		if not isstring(class) then continue end
		if refused and refused[class] then continue end

		if IsGun(class) then
			local score = Score(class)

			if score > floor and (not gunScore or score > gunScore) then
				gun, gunScore = class, score
			end
		end
	end

	if gun then return gun, "gun" end

	for i = 1, #MEDS do
		local class = MEDS[i]

		if weapons[class] and NeedsMed(npc, class) then return class, "med" end
	end

	-- And then anything else on him this addon knows what to do with. The four above are
	-- the order it would rather have them in; this is everything that was left off that
	-- list because nobody had thought of it yet - a medkit, a tourniquet, a syringe out of
	-- a pack from the workshop. sv_medical.lua answers what counts, because it is the file
	-- that has to use the thing afterwards, and a corpse robbed of a syringe nothing here
	-- can press is a player's syringe taken for nothing.
	if not ZCNPC.NpcUsesItem then return end

	local rest = {}

	for class in pairs(weapons) do
		if isstring(class) and ZCNPC.NpcUsesItem(class) and NeedsMed(npc, class) then
			rest[#rest + 1] = class
		end
	end

	-- Sorted only so that a body with two of them is searched the same way twice. Any of
	-- them is something the NPC is short of, so there is no better one to prefer.
	if #rest == 0 then return end

	table.sort(rest)

	return rest[1], "med"
end
--//

--\\ Taking it
local function Strip(rag, class)
	local info = ZCNPC.Downed and ZCNPC.Downed[rag] or nil

	if ZCNPC.TakeLoot then
		ZCNPC.TakeLoot(rag, info, class)

		return
	end

	local weapons = rag.inventory and rag.inventory.Weapons
	if weapons then
		weapons[class] = nil
		rag:SetNetVar("Inventory", rag.inventory)
	end
end

-- Guns are carried; medicine is not. An NPC has no bag, and the kit roll is the
-- only place it keeps anything (sv_loot.lua), so a bandage lifted off a body is
-- written back into that roll and un-spent. From there self-heal finds it the
-- same way it finds the one the NPC spawned with.
local function Restock(npc, class)
	npc.zcnpc_lootkit = npc.zcnpc_lootkit or {}
	npc.zcnpc_lootspent = npc.zcnpc_lootspent or {}
	npc.zcnpc_lootspent[class] = nil

	for i = 1, #npc.zcnpc_lootkit do
		if npc.zcnpc_lootkit[i] == class then return end
	end

	npc.zcnpc_lootkit[#npc.zcnpc_lootkit + 1] = class
end

-- The new gun into the hand before the old one leaves it. An NPC given a weapon keeps
-- hold of the one it is already carrying - sv_medical.lua leans on exactly that to put
-- a bandage in a hand that still owns a rifle - so there is no moment here with empty
-- hands, and a class the engine refuses costs the NPC nothing.
--
-- It used to cost it its rifle. The old gun was destroyed first and the new one asked
-- for afterwards, so a refusal left a rebel kneeling over a body with nothing at all;
-- and what an NPC with nothing in its hands does is go and find a gun on the floor
-- (sv_disarmed.lua), the nearest of which is the one it was holding a moment ago. That
-- is the whole of "it stands there looting its own last gun instead of the better one".
local function TakeGun(npc, rag, class)
	local weapons = rag.inventory and rag.inventory.Weapons
	local state = istable(weapons) and istable(weapons[class]) and weapons[class] or nil

	local old = ZCNPC.HeldGun(npc)
	local given = npc:Give(class)

	if not IsValid(given) then
		-- Written down where the floor trade keeps the same note, because walking back
		-- to this body will not change the answer.
		npc.zcnpc_fetchbad = npc.zcnpc_fetchbad or {}
		npc.zcnpc_fetchbad[class] = true

		ZCNPC.Debug("refused", class, "off a body -", npc)

		return false
	end

	-- GetInfo / SetInfo is Z-City's own clip + attachment transfer, the same one
	-- the floor pickup uses (sv_disarmed.lua), so a half empty magazine off a
	-- corpse stays half empty.
	if state and isfunction(given.SetInfo) then given:SetInfo(state) end

	-- Removed rather than dropped at its feet. A rifle left in the street is one more
	-- physics object per trade and one more thing for every other NPC's floor search to
	-- read, and the gun it just replaced is by definition the worse of the two.
	if IsValid(old) and old ~= given then old:Remove() end

	npc:SelectWeapon(class)

	-- The spawn loadout guard is over long before this, but a rifle chosen off a
	-- body is a choice and nothing should be able to hand the old one back.
	if ZCNPC.ClearLoadoutGuard then ZCNPC.ClearLoadoutGuard(npc) end

	npc.zcnpc_nogun = nil

	return true
end

local function Take(npc, rag)
	local class, kind = Wanted(npc, rag)
	if not class then return false end

	if kind == "gun" then
		if not TakeGun(npc, rag, class) then return false end
	else
		Restock(npc, class)
	end

	Strip(rag, class)

	npc:EmitSound("items/itempickup.wav", 60, math.random(95, 105))
	ZCNPC.Debug("looted a body", npc, class, kind)

	return true
end
--//

--\\ Kneeling over it
-- Arriving used to be the whole of it: a rebel got within reach of a body and the
-- inventory changed hands in the same tick, so what anybody watching saw was a man
-- walk up to a corpse, not break stride, and walk off with its rifle. The comment two
-- screens up has said "kneel" since this file was written and nothing here ever did.
--
-- Now it crouches over the body for a few seconds first. The crouch is an animation
-- layer on the NPC itself, out of the model's own cover-low sequence (sh_workpose.lua):
-- it moves, the server's hitboxes move with it, and the rifle in its hand comes down
-- with the hand. What the client adds is the arms, because no stock animation has a man
-- going through somebody's pockets in it (cl_loot.lua).
--
-- The feet are taken rather than argued with, for the reason sv_cms.lua sets out at
-- length - the combat AI hands out a schedule the moment it has an opinion and every
-- one of them moves them, so a stand re-issued from the half second pass buys half a
-- second of walking each time it loses. An NPC that cannot path cannot be sent
-- anywhere by anybody, and a crouch drawn on an NPC that is walking is a man sliding
-- across the floor on his heels.
local FEET = { CAP_MOVE_GROUND, CAP_MOVE_JUMP, CAP_MOVE_CLIMB }

local searching = {} -- [npc] = true, for the length of one search

local function HoldStill(npc)
	local caps = npc:CapabilitiesGet()

	-- Read once and kept, so one it never had is not handed out at the end of the
	-- search as though it had been.
	if not npc.zcnpc_lootcaps then
		local had = {}

		for i, cap in ipairs(FEET) do
			had[i] = bit.band(caps, cap) ~= 0
		end

		npc.zcnpc_lootcaps = had
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

local function FreeFeet(npc)
	local had = npc.zcnpc_lootcaps
	npc.zcnpc_lootcaps = nil

	if not (had and IsValid(npc)) then return end

	for i, cap in ipairs(FEET) do
		if had[i] then npc:CapabilitiesAdd(cap) end
	end
end

local function StartCrouch(npc, rag)
	local till = CurTime() + SEARCH_TIME

	npc.zcnpc_lootcrouch = till
	searching[npc] = true

	-- Turned to face it, so the crouch is over the body rather than past it. Set
	-- rather than asked for: facing a position is a schedule, and the feet have just
	-- been taken away, so there is nothing left to turn it with.
	local to = rag:WorldSpaceCenter() - npc:GetPos()
	if to:LengthSqr() > 1 then npc:SetAngles(Angle(0, to:Angle().y, 0)) end

	-- Stand still over it. No crouch layer and no hand IK: those moved the
	-- server's hitboxes and stretched an arm at the body, which is the whole of
	-- what this used to look like and both of those are gone on purpose.
	if ZCNPC.EndWork then ZCNPC.EndWork(npc) end

	HoldStill(npc)
end

local function EndCrouch(npc)
	npc.zcnpc_lootcrouch = nil
	searching[npc] = nil

	FreeFeet(npc)

	if IsValid(npc) and ZCNPC.EndWork then ZCNPC.EndWork(npc) end
end
--//

--\\ Getting there
-- Every way out of a search comes through here, so this is where the crouch is
-- stood back up out of: the quiet ending, the body being taken away, the rebel
-- being floored, and the ordinary finish.
local function ClearSearch(npc)
	npc.zcnpc_lootbody = nil
	npc.zcnpc_lootuntil = nil
	npc.zcnpc_lootpos = nil
	npc.zcnpc_lootat = nil
	npc.zcnpc_lootcheck = nil

	if npc.zcnpc_lootcrouch then EndCrouch(npc) end
end

-- Ten times a second, because half a second of feet is half a second of walking.
-- Only the reasons to stop are decided by the pass below (ZCNPC.UpdateBodyLoot).
timer.Create("zcnpc_loot_hold", 0.1, 0, function()
	if not next(searching) then return end

	for npc in pairs(searching) do
		if not (IsValid(npc) and npc.zcnpc_lootcrouch) then
			searching[npc] = nil

			continue
		end

		-- Finishing one is the half second pass's job, and the pass is the thing that
		-- stops being called: a rebel floored mid-search leaves the organism list it
		-- is walked from, switch looting off and it never comes back to this NPC.
		if CurTime() > npc.zcnpc_lootcrouch + STALE then
			ClearSearch(npc)

			continue
		end

		HoldStill(npc)
	end
end)

--\\ The bodies there are
-- Every ragdoll on the map, which is a far smaller thing than it sounds: bodies are
-- counted in tens where entities are counted in thousands. Weak keys, so a corpse that
-- fades out takes its entry with it and nothing has to be told that it has gone.
--
-- This was a sphere, eleven hundred units wide, per rebel, twice a second - and it
-- fired hardest exactly when it hurt most, because a rebel only asks when there is
-- something it wants and what makes it want anything is a fight having just ended.
-- Which is the shape of "it lags after a few of them die": a dozen fresh corpses, a
-- dozen rebels who each now want something, and every one of them sweeping the world
-- for it.
local corpses = setmetatable({}, { __mode = "k" })

local function Track(rag)
	if not (IsValid(rag) and rag:IsRagdoll()) then return end

	corpses[rag] = true
end

-- Both kinds arrive as a prop_ragdoll: the ones this addon lays down (sv_uncon.lua)
-- and Z-City's own player bodies. A tick late, because a ragdoll on the frame it is
-- created has neither an inventory nor an organism on it yet - and being a tick late
-- costs nothing, since nobody is going through anybody's pockets in the tick they
-- fell.
hook.Add("OnEntityCreated", "zcnpc_looting_bodies", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "prop_ragdoll" then return end

	timer.Simple(0, function() Track(ent) end)
end)

hook.Add("ZCNPC_Downed", "zcnpc_looting_bodies", function(_, rag) Track(rag) end)

-- And the ones already lying about. Both now and on the map load hook, because this file
-- is loaded from either of them - whichever of Z-City and this addon mounted second
-- (zcnpc_init.lua) - so neither one of the two is the one that is certain to happen
-- after there are entities to find.
local function Scan()
	for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do Track(rag) end
end

hook.Add("InitPostEntity", "zcnpc_looting_bodies", Scan)
hook.Add("PostCleanupMap", "zcnpc_looting_bodies", Scan)
Scan()

local function FindBody(npc)
	local origin = npc:GetPos()
	local searchSqr = SEARCH * SEARCH
	local best, bestDist

	-- Range first, then the cheap refusals, and what this particular rebel wants off
	-- this particular body last: Wanted walks a body's whole inventory and scores every
	-- gun in it, so it is asked of the nearest body that could have anything rather
	-- than of all of them.
	for rag in pairs(corpses) do
		if not IsValid(rag) then
			corpses[rag] = nil

			continue
		end

		local dist = rag:GetPos():DistToSqr(origin)
		if dist >= searchSqr then continue end
		if bestDist and dist >= bestDist then continue end
		if Claimed(npc, rag) then continue end
		if not DeadBody(rag) then continue end
		if not Wanted(npc, rag) then continue end

		best, bestDist = rag, dist
	end

	return best
end
--//

-- Within reach: crouch, go through it, stand up. The give-up clock above stops
-- running here on purpose - it is for a body that cannot be reached, and this one has
-- been.
local function Search(npc, rag)
	local till = npc.zcnpc_lootcrouch

	if not till then
		StartCrouch(npc, rag)

		return
	end

	if CurTime() < till then
		HoldStill(npc)

		return
	end

	Take(npc, rag)
	ClearSearch(npc)
	npc.zcnpc_lootnext = CurTime() + COOLDOWN
end

local function Walk(npc, rag)
	local origin = npc:GetPos()
	local goal = rag:GetPos()

	if npc.zcnpc_lootcrouch or origin:DistToSqr(goal) < REACH * REACH then
		Search(npc, rag)

		return
	end

	if CurTime() > (npc.zcnpc_lootuntil or 0) then
		ClearSearch(npc)
		npc.zcnpc_lootnext = CurTime() + GIVE_UP

		return
	end

	-- Same repath shape as the armour fetch: the combat AI takes the schedule back
	-- every time it has an opinion, so it is re-issued whenever the NPC is not
	-- running, the body has moved, or it has stopped making ground.
	local sched = npc:GetCurrentSchedule()
	local lastGoal = npc.zcnpc_lootpos
	local lastAt = npc.zcnpc_lootat
	local movedGoal = not lastGoal or lastGoal:DistToSqr(goal) > 48 * 48
	local due = (npc.zcnpc_lootcheck or 0) < CurTime()
	local stuck = due and lastAt and origin:DistToSqr(lastAt) < 24 * 24

	if sched ~= SCHED_FORCED_GO_RUN or movedGoal or stuck then
		npc:ClearSchedule()
		npc:SetLastPosition(goal)
		npc:SetSchedule(SCHED_FORCED_GO_RUN)
		npc.zcnpc_lootpos = Vector(goal)
		npc.zcnpc_lootat = Vector(origin)
		npc.zcnpc_lootcheck = CurTime() + REPATH
	elseif due then
		npc.zcnpc_lootat = Vector(origin)
		npc.zcnpc_lootcheck = CurTime() + REPATH
	end
end
--//

function ZCNPC.UpdateBodyLoot(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return end

	if not LootingEnabled() then
		ClearSearch(npc)

		return
	end

	if IsValid(npc.zcnpc_rag) then
		ClearSearch(npc)

		return
	end

	if not (ZCNPC.IsRebelCitizen and ZCNPC.IsRebelCitizen(npc)) then return end

	-- Where a scripted rebel stands is the map's to say (sv_core.lua), and a body
	-- across the room is not worth leaving a rally point for.
	if ZCNPC.MapDriven(npc) then
		ClearSearch(npc)

		return
	end

	-- Everything from here down is somebody else having this NPC, and a search under
	-- way is given up rather than parked. Parking it was free while arriving was
	-- instant; now it is a crouch, and the pass that would finish one is the pass
	-- these lines are returning out of - so a parked search is a rebel drawn kneeling
	-- over a body through the middle of somebody else's surgery, until the hold's own
	-- stale clock notices seconds later.
	if ZCNPC.IsZombie(npc) then ClearSearch(npc) return end
	if (ZCNPC.GettingUp[npc] or 0) > CurTime() then ClearSearch(npc) return end
	if npc:GetNetVar("handcuffed", false) then ClearSearch(npc) return end
	if ZCNPC.HasHeadcrab and ZCNPC.HasHeadcrab(npc) then ClearSearch(npc) return end
	if istable(npc.zcnpc_cms) then ClearSearch(npc) return end
	if istable(npc.zcnpc_rescue) then ClearSearch(npc) return end
	-- An item already out of a pocket (sv_medical.lua). Under a second, but a search
	-- started inside it is a kneel that begins with a bandage in the hand.
	if istable(npc.zcnpc_meduse) then ClearSearch(npc) return end

	-- Errands that already own the feet. Treating a wound outranks looting for
	-- one, and so does fetching a gun that is nearer than any body.
	if IsValid(npc.zcnpc_fetch) or IsValid(npc.zcnpc_fetcharmor) then ClearSearch(npc) return end
	if IsValid(npc.zcnpc_healally) then ClearSearch(npc) return end
	if (npc.zcnpc_bandagecover or 0) > CurTime() then ClearSearch(npc) return end

	local org = ZCNPC.ResolveOrganism(npc)
	if not org or org.alive == false or org.otrub then ClearSearch(npc) return end

	if not ZCNPC.NoThreatNear(npc, QUIET_RANGE) then
		ClearSearch(npc)

		return
	end

	local rag = npc.zcnpc_lootbody

	-- Claimed is asked of the body it is already on as well as of a new one, and it can
	-- only ever be somebody else by the time it is: two rebels that pick the same body
	-- in the same pass both wrote their name on it, and the second one wins. Better the
	-- one that gives up gives up now, on the way over, than at the body.
	if not (DeadBody(rag) and not Claimed(npc, rag) and Wanted(npc, rag)) then
		rag = nil
		ClearSearch(npc)
	end

	if not rag then
		if (npc.zcnpc_lootnext or 0) > CurTime() then return end

		rag = FindBody(npc)

		if not rag then
			npc.zcnpc_lootnext = CurTime() + NOTHING

			return
		end

		npc.zcnpc_lootbody = rag
		npc.zcnpc_lootuntil = CurTime() + GIVE_UP

		-- The body's half of the claim. The searcher's half is the line above, which is
		-- what Claimed actually reads - this is only so that the other rebels have
		-- somewhere to read it from.
		rag.zcnpc_lootedby = npc
	end

	Walk(npc, rag)
end

-- A rebel that gets floored mid-search is not going through anybody's pockets, and it
-- is the one way out of a crouch the pass above cannot see: the organism moves to the
-- body, so the NPC leaves the list this is walked from and UpdateBodyLoot is never
-- called for it again. Without this the hold's stale clock is what ends the search,
-- three seconds later, with the feet still taken.
hook.Add("ZCNPC_Downed", "zcnpc_looting", function(npc)
	if not (IsValid(npc) and npc.zcnpc_lootcrouch) then return end

	ClearSearch(npc)
end)

-- Tick owned by sv_disarmed's organism.list walk, the same as armour pickup and
-- self-heal: one walk of the list, not four.
