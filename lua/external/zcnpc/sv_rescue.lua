--[[
	Dragging a friend out and putting him back together.

	Everything else in this addon that treats a wound treats one on somebody who
	is standing up (sv_medical.lua, sv_cms.lua). The bodies on the floor were
	nobody's business at all: an NPC in cardiac arrest lay there with a brain
	starving on a two minute clock (organism/modules/sv_lungs.lua:383) while its
	entire squad stepped over it, because the only thing on the map that has ever
	been able to kneel down and do something about that is a player.

	So they do it themselves. One of them breaks off, gets to the body, drags it
	out of the open by the collar - crouched, at a walk, with the body trailing at
	its heels - and works on it where the shooting is not:

	  * a wrap on whatever is bleeding, big one first if it has one
	  * a bag of blood, because nothing wakes up under 2900 of it (sv_uncon.lua)
	    and a body that bled down to critical has to be filled back up
	  * chest compressions, which is the only thing that restarts a stopped heart
	  * the surgical kit for what a wrap will not close, if it is carrying one

	None of those four are ours. They are the same functions, the same numbers and
	the same sounds a player gets, borrowed from the files that own them - which is
	why an NPC medic and a player medic save a man the same way and why the PDA in
	somebody else's hands reads the same thing about him either way.

	What makes it work at all is that Z-City's own organism does the rest. Stop the
	bleeding and restart the heart and blood regenerates on its own
	(modules/sv_blood.lua:91); once there is enough of it and the heart is going,
	the wake-up rule in sv_uncon.lua is satisfied and the man gets up by himself.
	Nobody here decides that he lives. It decides that somebody tried.

	It also decides when there is no point in trying. The organism will say what
	resting pulse a body can hold before anybody kneels on it, and a chest that
	cannot hold ten is one the compressions put back into arrest as fast as they
	bring it out (Hopeless, below). That is a man who is not coming back, and
	kneeling on him until a seventy five second clock runs out is not medicine.

	And not the Combine. Everything here is a side looking after its own; Overwatch
	replaces casualties rather than dragging them indoors, which is the same reason
	no soldier goes through anybody's pockets either (sv_looting.lua).

	Only when it is quiet, for the reason the surgery gives at length in sv_cms.lua:
	kneeling over a body with your back to a doorway is not something anybody does
	while being shot at. And only NPC bodies - a player's is Z-City's own ragdoll
	with a player's own physics and controls in it, and pulling on that from here is
	a fight nobody wins.
]]

local cfg = ZCNPC.Config

local SEARCH_FALLBACK = 1000 -- if the convar is missing, how far a body is worth going
local REACH = 72 -- close enough to take hold of somebody
local WALK_GIVE_UP = 18 -- seconds before a body it cannot reach is written off
local REPATH = 1.25
local COOLDOWN = 6 -- between one rescue and the next

-- Nothing hostile this close, or there is no rescue. The same number the body
-- search uses (sv_looting.lua) rather than the surgery's most-of-a-street 1400:
-- this is meant to happen in the lull after a firefight, and the lull is where
-- the bodies are.
local QUIET_RANGE = 1000

-- The drag. Deliberately slow: a man being pulled along the floor at a run is a
-- man being dropped, and the crouch is half the point of it.
local DRAG_TIME = 30 -- seconds before it gives up and treats him where he lies
local DRAG_MIN = 96 -- not worth taking hold of somebody for less than this
local DRAG_MAX = 420 -- and no further than this in one go
local DRAG_ARRIVED = 64
local DRAG_TRAIL = 26 -- how far behind its heels the body is pulled
local DRAG_LIFT = 20 -- and how far off the floor the chest is held
local DRAG_PULL = 3.5 -- how hard, as a multiple of the distance still to close
local DRAG_SPEED = 150 -- and never faster than this
local DRAG_LEASH = 128 -- further behind than this and it waits for him to catch up

-- And how much of his own walk the man doing the pulling has left, because the crouch on
-- its own was not it: a crouch-walk in Source is still a purposeful pace, and what it
-- looked like was a medic strolling through a firefight with a body skating along behind
-- him. Somebody hauling a man's whole weight backwards with one hand does not walk.
--
-- DRAG_TIME went up with it. That number is how long it will keep trying before it gives
-- up and treats him where he lies, so leaving it where it was would have turned a slower
-- walk into a shorter one - the same drag, abandoned halfway to the same wall.
local DRAG_RATE = 0.6

-- Past this the organism has decided: the heart is forced to stop on every think
-- from here up (modules/sv_pulse.lua:81) and no amount of compressions will hold
-- it, and 0.7 is death (modules/sv_lungs.lua:383). A body this far gone is one
-- nobody can do anything for, and spending a squad's last bandage on it is worse
-- than admitting that.
local BRAIN_GONE = 0.6

-- And under this the organism puts it back into arrest, every think, whatever the
-- last compression did (modules/sv_pulse.lua:81).
local ARREST_PULSE = 10

-- What the resting pulse is built out of, which is where a hopeless resuscitation
-- can be read off before it is attempted. The organism works one out every think and
-- walks the current pulse towards it (modules/sv_pulse.lua:36): seventy, scaled by
-- how much heart there is left, how much brain, how much blood is in him and how
-- cold he is. Under ARREST_PULSE the heart is stopped again as fast as it is started.
--
-- Only the four things compressions cannot reach. Oxygen belongs in that product too
-- and is deliberately left out of this one, because oxygen is the thing CPR is for -
-- counting it would declare every arrest hopeless at the moment it begins, which is
-- the moment there is least of it.
--
-- Blood is in it and belongs there, and the order of the list below is what makes
-- that honest: the bag comes before the compressions, so by the time this is asked a
-- medic carrying one has already emptied it into him. A body still under it is one
-- nobody present can fill back up.
local function Sustainable(org)
	local heart = 1 - math.Clamp(org.heart or 0, 0, 1)
	local brain = math.Clamp(1 - (org.brain or 0) * 1.5, 0, 1)
	local blood = math.Clamp(((org.blood or 0) - 1000) / 4000, 0, 1)
	local temp = math.Clamp(math.Remap(org.temperature or 36.7, 28, 36.7, 0.5, 1), 0.5, 1)

	return 70 * heart * brain * blood * temp
end

-- Somebody the compressions cannot save, however long they go on. Which used to be
-- nobody: CPR is the one treatment with no failure in it - a bout that did not start
-- the heart is not a mistake, it is CPR - so a medic knelt on a chest that was never
-- going to hold a pulse until the seventy five second cap fell, stood up, waited six
-- seconds and knelt back down on it. Forever, on a man with a shredded heart.
local function Hopeless(org)
	return Sustainable(org) < ARREST_PULSE
end

-- Worth a bag of blood. Well above the 2900 that wake-up wants, because the
-- regeneration that closes the rest of the gap only runs on a body that is not
-- bleeding and has a pulse (modules/sv_blood.lua:91), and a rescue that has just
-- started has neither yet.
local BLOOD_LOW = 4200

local TREAT_MAX = 75 -- hard end to one bout of treatment, whatever is left undone
local CPR_BOUT = 6 -- seconds of compressions before it looks up and re-decides
local BANDAGE_TIME = 3
local BLOOD_TIME = 5

local CHEST_BONE = "ValveBiped.Bip01_Spine2"

--\\ Reading the state of things
local function Enabled()
	return false
end

local function SearchRange()
	if not cfg.rescue_range then return SEARCH_FALLBACK end

	return cfg.rescue_range:GetFloat()
end

-- The ones with a red cross on them. IsMedicCitizen is the rebel answer - the
-- spawn menu's medic flag or a group03m model (sv_armor.lua) - and the model name
-- is the rest of it, so a Combine medic out of somebody's model pack counts as one
-- without this file having to have heard of the pack.
local function Medic(npc)
	if ZCNPC.IsMedicCitizen and ZCNPC.IsMedicCitizen(npc) then return true end

	return string.find(string.lower(npc:GetModel() or ""), "medic", 1, true) ~= nil
end

local function Alone(npc)
	if not ZCNPC.NoThreatNear then return true end

	return ZCNPC.NoThreatNear(npc, QUIET_RANGE)
end

-- The bone you take hold of somebody by, and the one Z-City's CPR insists on
-- (weapon_hands_sh.lua:1033). Looked up once per body and kept: it is asked for
-- twice a second for the length of a rescue.
local function ChestPhys(rag)
	local physnum = rag.zcnpc_chestphys

	if physnum == nil then
		local bone = rag:LookupBone(CHEST_BONE)
		physnum = bone and rag:TranslateBoneToPhysBone(bone) or false
		if physnum == false or physnum < 0 then physnum = false end

		rag.zcnpc_chestphys = physnum
	end

	if physnum == false then return rag:GetPhysicsObject() end

	local phys = rag:GetPhysicsObjectNum(physnum)
	if IsValid(phys) then return phys end

	return rag:GetPhysicsObject()
end
--//

--\\ What can be done for him, in the order it is worth doing
-- Each of these is somebody else's function. What is decided here is only which
-- one is worth reaching for next, and that is the order of the list: a wound that
-- is emptying him first, then what is already gone, then the heart, and the kit
-- that costs twelve seconds last.
local function NeedsWrap(org)
	return ZCNPC.NpcNeedsBandage ~= nil and ZCNPC.NpcNeedsBandage(org)
end

-- One compression, and it is Z-City's own (weapon_hands_sh.lua:1043) down to the
-- broken rib. Called from the half second pass, which is the rate the item does it
-- at: its own clock is CurTime() + (1 / 120) * 60, and that is a half second
-- written the long way round.
--
-- The doubling a player with the doctor profession gets is left out. An NPC has no
-- profession, and the difference a medic makes here is the bag of blood it is
-- carrying rather than a multiplier.
local function Compress(npc, rag, org)
	if not org.alive then return end

	org.pulse = math.min((org.pulse or 0) + 5, 70)
	org.CO = math.Approach(org.CO or 0, 0, 1)
	org.COregen = math.Approach(org.COregen or 0, 0, 1)
	org.co2 = math.Approach(org.co2 or 0, 0, 1)

	if math.random(3) == 1 then org.lungsfunction = true end

	-- Compressions break ribs. The same one in fifty a player who is not a doctor
	-- gets, through the organism's own chest input so it is the wound it would be.
	if math.random(50) == 1 and istable(hg) and istable(hg.organism)
		and istable(hg.organism.input_list) and isfunction(hg.organism.input_list.chest)
	then
		local dmg = DamageInfo()
		dmg:SetDamageType(DMG_CRUSH)
		dmg:SetInflictor(npc)
		dmg:SetAttacker(npc)
		hg.organism.input_list.chest(org, 1, 5, dmg)
	end

	if (org.pulse or 0) > 15 then org.heartstop = false end

	local phys = ChestPhys(rag)
	if IsValid(phys) then
		phys:Wake()
		phys:ApplyForceCenter(-vector_up * 6000)
	end
end

-- The item in the hand for the length of the action, the way the surgical kit has always
-- been (the cms entry below). Three seconds of a medic kneeling over a man with nothing in
-- its hands and a wound closing by itself is the same bug the kit had, and the wrap and the
-- bag are what a rescue is mostly made of.
--
-- Which item it is comes from the same function that decides whether it can be spent at
-- all, so what is held is what is about to be used - a medic out of field dressings and
-- down to a big one holds the big one. Nothing is spent here: the item is put away by
-- Treat when the action ends and the spending is done by finish.
local function HoldFor(npc, state, class)
	if not isstring(class) then return end

	local wep = ZCNPC.NpcHoldItem and ZCNPC.NpcHoldItem(npc, class)
	if IsValid(wep) then state.wep = wep end
end

local ACTIONS = {
	{
		name = "bandage",
		time = BANDAGE_TIME,
		want = function(npc, org)
			return NeedsWrap(org) and ZCNPC.NpcCanBandage ~= nil and ZCNPC.NpcCanBandage(npc) ~= nil
		end,
		start = function(npc, state)
			HoldFor(npc, state, ZCNPC.NpcCanBandage and ZCNPC.NpcCanBandage(npc))
		end,
		finish = function(npc, rag, org)
			return ZCNPC.NpcBandage(npc, rag, org)
		end,
	},
	{
		name = "blood",
		time = BLOOD_TIME,
		want = function(npc, org)
			if (org.blood or 0) >= BLOOD_LOW then return false end

			return ZCNPC.NpcCanBlood ~= nil and ZCNPC.NpcCanBlood(npc) ~= nil
		end,
		start = function(npc, state)
			if not ZCNPC.NpcCanBlood then return end

			local _, class = ZCNPC.NpcCanBlood(npc)
			HoldFor(npc, state, class)
		end,
		finish = function(npc, rag, org)
			return ZCNPC.NpcBloodBag(npc, rag, org)
		end,
	},
	{
		name = "cpr",
		time = CPR_BOUT,
		want = function(_, org)
			if org.heartstop ~= true then return false end

			return not Hopeless(org)
		end,
		tick = function(npc, rag, org)
			-- It stops the moment the heart is going again and the pass picks
			-- whatever is next. A heart that stops again gets another bout.
			if not org.heartstop then return false end

			-- And the moment there is no longer any point, without waiting out the
			-- rest of the bout: pushing on a chest puts no blood back in a man and
			-- mends none of the muscle being pushed on, so one that drops under the
			-- line halfway through a bout stays under it.
			if Hopeless(org) then return false end

			Compress(npc, rag, org)

			return true
		end,
		-- Nothing to hand over at the end: every compression has already done
		-- whatever it was going to do. And a bout that did not restart the heart is
		-- not a failed treatment to be struck off the list - it is CPR, which is
		-- what you keep doing.
		finish = function()
			return true
		end,
	},
	{
		name = "cms",
		time = nil, -- the kit's own twelve seconds, read below
		want = function(npc, org)
			if not (ZCNPC.CmsInstalled and ZCNPC.CmsInstalled()) then return false end
			if cfg.cms and not cfg.cms:GetBool() then return false end
			if not (ZCNPC.CmsTreatable and ZCNPC.CmsTreatable(org)) then return false end

			return ZCNPC.KitHasItem ~= nil and ZCNPC.KitHasItem(npc, ZCNPC.CmsKit.class)
		end,
		start = function(npc, state)
			-- The real kit, so the model is in its hands and anybody watching can
			-- see what it is doing. Give() is safe here only because the kit's
			-- pick-up heal steps over an owner that is mid-rescue (sv_cms.lua).
			local kit = ZCNPC.CmsKit
			local wep = npc:Give(kit.class)

			if IsValid(wep) then
				state.wep = wep
				npc:SelectWeapon(kit.class)
			end

			state.sound = CreateSound(npc, kit.loop)
			if state.sound then state.sound:Play() end
		end,
		finish = function(npc, rag, org)
			local kit = ZCNPC.CmsKit
			local did = ZCNPC.CmsStitch(rag, org)

			npc:EmitSound(kit.done, 70, math.random(95, 105))
			if ZCNPC.MarkLootSpent then ZCNPC.MarkLootSpent(npc, kit.class) end

			return did
		end,
	},
}

local function ActionTime(action)
	if action.name ~= "cms" then return action.time end

	return (istable(ZCNPC.CmsKit) and ZCNPC.CmsKit.time) or 12
end

-- Anything at all this one could do for that one. The whole of the decision to go:
-- a squad that walks across a street to stand over a body it has no answer for is
-- worse than a squad that stays in cover.
local function Wanted(npc, org, failed)
	for i = 1, #ACTIONS do
		local action = ACTIONS[i]

		if not (failed and failed[action.name]) and action.want(npc, org) then
			return action
		end
	end
end
--//

--\\ One body, one pair of hands
-- Two men taking hold of the same chest is not a queue, it is a tug of war. The pull
-- is a SetVelocity on one physics object ten times a second (Pull below), so a second
-- rescuer does not wait his turn - he overwrites the first one's pull with his own,
-- every pass, and the body skids back and forth between the two of them while both
-- walk off in different directions.
--
-- The claim was already written down, on the body and in the rescuer's own state, and
-- what was wrong with it was the question being asked of it: "is somebody rescuing
-- something", rather than "is somebody rescuing this". Those two come apart the
-- moment a name is left on a body whose rescuer has moved on, and keeping them
-- together meant every way out of a rescue remembering to take the name off - the
-- ordinary end, giving up, being shot, being floored, being disarmed mid-treatment,
-- and the pass simply never being called again.
--
-- So it is read off the rescuer instead, and only the rescuer's own state can make it
-- true. Nothing has to remember anything: a name with no rescue behind it answers no
-- by itself, and is wiped in passing so the body does not become one nobody may touch
-- for the rest of the round.
local function Holder(rag)
	local npc = rag.zcnpc_rescuer
	if not IsValid(npc) then
		rag.zcnpc_rescuer = nil

		return nil
	end

	local state = npc.zcnpc_rescue

	if not (istable(state) and state.rag == rag) then
		rag.zcnpc_rescuer = nil

		return nil
	end

	return npc
end

-- The one pair of hands the state above cannot see. Z-City hangs a player's carried
-- entity off the player, one net var per hand (sh_utility.lua:445), and a player
-- hauling a body across a room is the same single chest and the same SetVelocity - so
-- an NPC deciding to help is an NPC fighting him for it.
--
-- This is the only test in the claim that walks a table, which is why Savable asks the
-- claim last: by then the body has already been ruled in on everything cheaper.
-- The list itself is asked for once a frame rather than once a body: player.GetAll
-- builds a fresh table every call, and this is called of every body every rescuer is
-- considering (sv_core.lua keeps the copy).
local function PlayerDragging(rag)
	local players = ZCNPC.Players and ZCNPC.Players() or player.GetAll()

	for i = 1, #players do
		local ply = players[i]

		if ply:GetNetVar("carryent") == rag or ply:GetNetVar("carryent2") == rag then
			return true
		end
	end

	return false
end

-- Anybody but this one has hold of him.
local function Taken(npc, rag)
	-- A player's hands outrank everybody's, this NPC's own included, and that is why
	-- they are read first rather than after the claim. Running asks this every pass,
	-- so an NPC already halfway across a room with a body drops him the moment a
	-- player takes hold of it - which is the whole point of asking. Two of them
	-- pulling one chest in halves is what there is instead.
	if PlayerDragging(rag) then return true end

	local holder = Holder(rag)

	return holder ~= nil and holder ~= npc
end
--//

--\\ Who is worth going to
-- Only bodies this addon laid down. A player's body is Z-City's own, with the
-- player's physics and camera attached to it, and a downed player has their own
-- ways out of it - dragging on that from here would be two systems pulling one
-- ragdoll in different directions.
local function Savable(npc, rag, info)
	if not (IsValid(rag) and istable(info)) then return false end
	if not IsValid(info.npc) then return false end

	local org = rag.organism
	if not istable(org) then return false end
	if org.alive == false then return false end
	if org.headamputated then return false end
	if (org.brain or 0) >= BRAIN_GONE then return false end
	if rag.zcnpc_gettingup then return false end
	if rag:IsOnFire() then return false end

	-- Cuffed or taped is a prisoner, and a prisoner cannot stand up whatever is
	-- done for him (sv_uncon.lua, sv_ducttape.lua). Cutting one loose is not
	-- something an NPC has any business deciding.
	if rag:GetNetVar("handcuffed", false) then return false end
	if info.npc:GetNetVar("handcuffed", false) then return false end
	if ZCNPC.IsDuctTaped and ZCNPC.IsDuctTaped(rag) then return false end

	if not (ZCNPC.NpcFriendly and ZCNPC.NpcFriendly(npc, info.npc)) then return false end

	-- Somebody already has him. One man being worked on by three is three men in
	-- the open and a queue, and three hands on one chest is the tug of war above.
	if Taken(npc, rag) then return false end

	return true
end

local function FindBody(npc)
	local origin = npc:GetPos()
	local range = SearchRange()
	local rangeSqr = range * range
	local best, bestDist

	-- Range first. Every body on the map is walked here on every pass, and one
	-- subtraction rules out all the ones lying somewhere else - ahead of the dozen
	-- reasons Savable has for saying no, one of which now walks the players. Same
	-- body chosen: the two questions do not depend on each other.
	for rag, info in pairs(ZCNPC.Downed or {}) do
		if IsValid(rag) then
			local dist = rag:GetPos():DistToSqr(origin)

			if dist < rangeSqr and not (bestDist and dist >= bestDist)
				and Savable(npc, rag, info) and Wanted(npc, rag.organism)
			then
				best, bestDist = rag, dist
			end
		end
	end

	return best
end

-- Anybody at all, or only the ones with a kit and a red cross. The rest of the
-- refusals are on the pass below; these are about who this NPC is rather than what it
-- is currently doing.
local function CanRescue(npc)
	if ZCNPC.IsZombie and ZCNPC.IsZombie(npc) then return false end

	-- Not the overwatch line. A soldier who goes down is a casualty Overwatch replaces
	-- and the squad steps over him - which is the same reason none of them go through
	-- pockets either (sv_looting.lua), and it is the one faction in the game the
	-- fantasy is not written for. Civil Protection is not included: a metrocop is a
	-- conscript, and hauling a mate out of the street is a thing a conscript does.
	if ZCNPC.IsCombine and ZCNPC.IsCombine(npc) then return false end

	if cfg.rescue_medic and cfg.rescue_medic:GetBool() and not Medic(npc) then return false end

	return true
end
--//

--\\ Somewhere better than here
-- Out of the open, which is the whole of what a drag is for. Where the shooting
-- came from is the best thing to hide a body from, and the NPC's own enemy is
-- where that is - including a dead one, which is the usual case here: the fight
-- has just ended, the man who did this is on the floor across the street, and the
-- rest of his side will be along.
local function ThreatPos(npc)
	local enemy = npc:GetEnemy()

	return IsValid(enemy) and enemy:WorldSpaceCenter() or nil
end

-- Whether one point can see another through the map. Brushes only, so a crate or a
-- parked car is not read as cover - those are things a rifle goes through and a
-- rescue that trusts them is a rescue in the open.
local function Visible(from, to)
	local tr = util.TraceLine({
		start = from,
		endpos = to,
		mask = MASK_SOLID_BRUSHONLY,
	})

	return not tr.Hit
end

-- Twelve directions, the furthest clear run in each, and the one that ends up
-- somewhere the shooting cannot see. There is no node graph in this: a rescue
-- happens where somebody fell and that is as often as not a room the mapper never
-- put a node in, and NPC:FindSpot on a map without a graph hands back nothing at
-- all.
local RAYS = 12

local function SafeSpot(npc, rag)
	local origin = rag:WorldSpaceCenter()
	local floorAt = Vector(origin.x, origin.y, rag:GetPos().z)
	local threat = ThreatPos(npc)
	local best, bestScore

	for i = 0, RAYS - 1 do
		local dir = Angle(0, i * (360 / RAYS), 0):Forward()

		-- How far along that line the body can actually go. Brushes only: a chair
		-- or another body is something a dragged man slides over, and tracing
		-- against everything means every direction ends at the rescuer's own feet.
		local tr = util.TraceLine({
			start = origin,
			endpos = origin + dir * DRAG_MAX,
			mask = MASK_SOLID_BRUSHONLY,
		})

		local dist = (tr.HitPos - origin):Length() - 24
		if dist < DRAG_MIN then continue end

		local spot = floorAt + dir * dist

		-- Standing on something. A clear run that ends over a stairwell is a body
		-- thrown down it.
		local ground = util.TraceLine({
			start = spot + vector_up * 24,
			endpos = spot - vector_up * 96,
			mask = MASK_SOLID_BRUSHONLY,
		})

		if not ground.Hit then continue end

		spot = ground.HitPos

		-- Never towards the shooting, whatever else is right about it.
		if threat and spot:Distance(threat) < origin:Distance(threat) then continue end

		-- Out of sight is worth more than anything else, and being up against
		-- something is the next best thing when there is nothing to hide from.
		local score = 0

		if threat and not Visible(spot + vector_up * 32, threat) then
			score = score + 4000
		end

		if tr.Hit then score = score + 600 end

		-- Shorter is better between two that are equally out of the way: every
		-- yard of it is a yard spent in the open with both hands full.
		score = score - dist

		if not bestScore or score > bestScore then
			best, bestScore = spot, score
		end
	end

	-- Nothing worth moving him for. Either there was nowhere to go, or nowhere that
	-- is out of sight and he is already out of sight where he is lying - which is
	-- what a corner, a doorway or a room he fell in already is. Then the drag is
	-- skipped and he is treated where he lies, which is the right answer and not a
	-- failure to find one.
	if not best then return nil end
	if threat and bestScore < 4000 and not Visible(floorAt + vector_up * 32, threat) then
		return nil
	end

	return best
end
--//

--\\ Feet, and the crouch they walk in
-- The treat phase takes the feet the way the surgery does and for the same reason
-- (sv_cms.lua at length): a stand re-issued from a half second pass buys half a
-- second of walking every time it loses the argument, and a crouch drawn on an NPC
-- that is walking is a man sliding across the floor on his heels.
--
-- The drag cannot take them - it is going somewhere - so that half is a forced
-- walk re-issued whenever the AI takes it back, with the movement activity set to
-- the model's own crouch walk.
local FEET = { CAP_MOVE_GROUND, CAP_MOVE_JUMP, CAP_MOVE_CLIMB }

local working = {} -- [npc] = true, for the length of one rescue

local function HoldStill(npc, state)
	local caps = npc:CapabilitiesGet()

	if not state.caps then
		local had = {}

		for i, cap in ipairs(FEET) do
			had[i] = bit.band(caps, cap) ~= 0
		end

		state.caps = had
	end

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

-- Read out of _G rather than named directly, so a branch of the engine without the
-- enum is one missing crouch rather than a nil handed to the AI.
local CROUCH_WALK = isnumber(_G.ACT_WALK_CROUCH) and _G.ACT_WALK_CROUCH or nil

-- [model] = sequence id, or false for a model with nothing to crouch-walk with.
-- Asked once per model: a model that has no such sequence must not be handed the
-- activity at all, because an NPC told to move in an animation it does not have is
-- an NPC that stops moving.
local crouchSeq = {}

local function CrouchWalk(npc)
	if not CROUCH_WALK then return end

	local model = npc:GetModel()
	local seq = crouchSeq[model]

	if seq == nil then
		seq = npc:SelectWeightedSequence(CROUCH_WALK)
		if not isnumber(seq) or seq < 0 then seq = false end

		crouchSeq[model] = seq
	end

	if seq == false then return end

	npc:SetMovementActivity(CROUCH_WALK)
	npc:SetMovementSequence(seq)

	npc.zcnpc_dragcrouch = true
end

-- Handed back rather than left for the AI to overwrite. It does overwrite it - that
-- is why the crouch is written every pass above - but only when it next picks a
-- movement activity, and a rescuer that lets go of a body standing still does not
-- pick one until it walks somewhere. Until then it is still carrying the drag's
-- crouch, so the first steps it takes afterwards are in a crouch it has no reason
-- to be in.
local WALK = isnumber(_G.ACT_WALK) and _G.ACT_WALK or nil

local walkSeq = {}

local function WalkNormally(npc)
	if not npc.zcnpc_dragcrouch then return end
	npc.zcnpc_dragcrouch = nil

	if not WALK then return end

	local model = npc:GetModel()
	local seq = walkSeq[model]

	if seq == nil then
		seq = npc:SelectWeightedSequence(WALK)
		if not isnumber(seq) or seq < 0 then seq = false end

		walkSeq[model] = seq
	end

	if seq == false then return end

	npc:SetMovementActivity(WALK)
	npc:SetMovementSequence(seq)
end
--//

--\\ The pull
-- A body is a dozen loose weights in a bag and the only one being held is the
-- chest, which is what dragging somebody is. The rest of him follows through his
-- own joints, so the legs trail and the head lolls without any of it being posed.
local function Pull(npc, rag)
	local phys = ChestPhys(rag)
	if not IsValid(phys) then return end

	local want = npc:GetPos() - npc:GetForward() * DRAG_TRAIL + vector_up * DRAG_LIFT
	local to = want - phys:GetPos()
	local vel = to * DRAG_PULL

	local speedSqr = vel:LengthSqr()
	if speedSqr > DRAG_SPEED * DRAG_SPEED then
		vel = vel * (DRAG_SPEED / math.sqrt(speedSqr))
	end

	phys:Wake()
	phys:SetVelocity(vel)

	-- Z-City's own damping on a carried body (weapon_hands_sh.lua:1115). Without it
	-- the chest spins on the spot as it is dragged and takes the rest with it.
	phys:AddAngleVelocity(-phys:GetAngleVelocity() / 8)
end

-- The rescuer's own pace, and the same knob the limp is done with: an NPC's ground speed
-- comes out of the animation it is walking, so scaling the animation scales the walk
-- (sv_status.lua:221). Written back every pass rather than once when the drag starts,
-- because the engine picks the rate itself the moment the AI chooses a new activity - and
-- the drag re-issues its schedule every time the body catches up.
local function Slow(npc, rate)
	if npc:GetPlaybackRate() ~= rate then npc:SetPlaybackRate(rate) end
end

-- Read by sv_status.lua, which owns this knob the rest of the time. A limp and a drag are
-- both a reason to be slow and stacking them multiplies into a crawl, so the drag says so
-- and the limp stands aside - the same arrangement the Wounded Walk bridge already has
-- with it (ZCNPC.WoundedWalkOwnsMove).
function ZCNPC.DragOwnsMove(npc)
	if not IsValid(npc) then return false end

	local state = npc.zcnpc_rescue

	return istable(state) and state.phase == "drag"
end

-- Ten times a second, both halves. Only the reasons to stop are decided by the
-- half second pass, the same split every other errand in the addon uses.
timer.Create("zcnpc_rescue_hold", 0.1, 0, function()
	if not next(working) then return end

	for npc in pairs(working) do
		local state = IsValid(npc) and npc.zcnpc_rescue

		if not istable(state) then
			working[npc] = nil

			continue
		end

		-- The pass finishes a rescue and the pass is the thing that stops being
		-- called: switch the addon off mid-drag, or floor the rescuer, and nothing
		-- comes back to it. Taking a pair of feet away is not something to do on
		-- the assumption that somebody else will hand them back (sv_cms.lua).
		if CurTime() > (state.until_ or 0) + 3 then
			ZCNPC.CancelRescue(npc, "nobody came back for it")

			continue
		end

		if state.phase == "treat" then
			HoldStill(npc, state)
			ZCNPC.HoldWork(npc)
		elseif state.phase == "drag" and IsValid(state.rag) then
			Pull(npc, state.rag)
			Slow(npc, DRAG_RATE)
		end
	end
end)
--//

--\\ Starting and ending
local function StopLoop(state)
	if not state.sound then return end

	state.sound:Stop()
	state.sound = nil
end

-- Puts the kit away and the rifle back. Between the two of them this is every
-- way out of a rescue: finished, interrupted, and the rescuer going down.
local function Release(npc, state, why)
	StopLoop(state)
	working[npc] = nil

	local wep = state.wep
	state.wep = nil
	if IsValid(wep) then wep:Remove() end

	local rag = state.rag
	if IsValid(rag) and rag.zcnpc_rescuer == npc then rag.zcnpc_rescuer = nil end

	if not IsValid(npc) then return end

	FreeFeet(npc, state)

	-- His own pace back. If there is a reason of its own for him to be slow, sv_status.lua
	-- writes it again on the next tick - it runs every one of them.
	Slow(npc, 1)
	WalkNormally(npc)

	-- After the kit is gone, not before: while this is set the kit's own pick-up
	-- heal is stepped over (sv_cms.lua) and the last thing it does on its way out
	-- must still be stepped over.
	npc.zcnpc_rescue = nil
	ZCNPC.EndWork(npc)
	npc.zcnpc_rescuenext = CurTime() + COOLDOWN

	local back = state.hadclass
	if back then
		-- Only if it still has it: losing the rifle mid-rescue is one of the ways
		-- one ends, and re-selecting a gun that is on the floor now leaves an NPC
		-- aiming an empty hand.
		for _, held in ipairs(npc:GetWeapons() or {}) do
			if IsValid(held) and held:GetClass() == back then
				npc:SelectWeapon(back)

				break
			end
		end
	end

	ZCNPC.Debug("rescue ended", npc, why or "?")
end

-- Whether somebody is working on this body at this moment. Asked by the wake-up rule
-- (sv_uncon.lua), and asked of the rescuer rather than of a flag on the body: a rescue that
-- ended badly enough to leave a flag behind must not be able to hold a man on the floor for
-- the rest of the round.
function ZCNPC.BeingRescued(rag)
	if not IsValid(rag) then return false end

	return Holder(rag) ~= nil
end

function ZCNPC.CancelRescue(npc, why)
	if not IsValid(npc) then return end

	local state = npc.zcnpc_rescue
	if not istable(state) then return end

	Release(npc, state, why or "cancelled")
end

local function Begin(npc, rag)
	-- Checked here and not only in the search. The search decides who is worth going
	-- to; this is the one line that actually takes hold of him, and it is the only
	-- place the answer has to be true at the moment the claim is written. Trusting
	-- the caller is what made a single owner a convention rather than a rule.
	if Taken(npc, rag) then return nil end

	local held = npc:GetActiveWeapon()

	local state = {
		rag = rag,
		phase = "walk",
		until_ = CurTime() + WALK_GIVE_UP,
		failed = {},
		hadclass = IsValid(held) and held:GetClass() or nil,
	}

	-- The state first. Holder reads the claim back through it, so a body named
	-- before its rescuer has anything to show for it is a body that reads as free.
	npc.zcnpc_rescue = state
	rag.zcnpc_rescuer = npc
	working[npc] = true

	ZCNPC.Debug("rescue started", npc, rag)

	return state
end
--//

--\\ The three phases
local function Repath(npc, state, goal, run)
	local origin = npc:GetPos()
	local sched = run and SCHED_FORCED_GO_RUN or SCHED_FORCED_GO
	local last = state.goal
	local moved = not last or last:DistToSqr(goal) > 48 * 48
	local due = (state.check or 0) < CurTime()
	local stuck = due and state.at and origin:DistToSqr(state.at) < 24 * 24

	if npc:GetCurrentSchedule() ~= sched or moved or stuck then
		npc:ClearSchedule()
		npc:SetLastPosition(goal)
		npc:SetSchedule(sched)

		state.goal = Vector(goal)
		state.at = Vector(origin)
		state.check = CurTime() + REPATH
	elseif due then
		state.at = Vector(origin)
		state.check = CurTime() + REPATH
	end

	-- Every pass rather than only when the schedule is re-issued: the AI writes its
	-- own movement activity whenever it thinks, and a crouch that is only set once
	-- lasts until the next one of those.
	if not run then CrouchWalk(npc) end
end

local function StartTreat(npc, state)
	state.phase = "treat"
	state.until_ = CurTime() + TREAT_MAX

	-- Full rate again: the drag is over and what is left is a kneel. Working on a man in
	-- slow motion is not the effect the drag was after.
	Slow(npc, 1)
	state.action = nil
	state.goal = nil
	state.at = nil
	state.check = nil

	-- Turned to face him, so the kneel is over the body rather than past it. Set
	-- rather than asked for: facing a position is a schedule and the feet are about
	-- to be taken away, so there would be nothing left to turn it with.
	local rag = state.rag
	if IsValid(rag) then
		local to = rag:WorldSpaceCenter() - npc:GetPos()
		if to:LengthSqr() > 1 then npc:SetAngles(Angle(0, to:Angle().y, 0)) end
	end

	-- One crouch for the whole of it, not one per treatment: a layer started per bandage
	-- would have the medic stand up and kneel down again between the wrap and the
	-- needle. Which pair of hands goes in it changes per treatment and is set as each
	-- one begins (Treat below); the crouch under them does not.
	--
	-- Release is what actually ends the pose. The clock handed over here is the hard end
	-- of one bout of treatment, for the case where nobody gets round to it.
	ZCNPC.BeginWork(npc, ZCNPC.Work.TREAT, rag, state.until_)

	HoldStill(npc, state)
end

local function StartDrag(npc, state, spot)
	state.phase = "drag"
	state.until_ = CurTime() + DRAG_TIME
	state.spot = spot
	state.goal = nil
	state.at = nil
	state.check = nil

	ZCNPC.Debug("dragging", npc, math.floor(npc:GetPos():Distance(spot)))
end

-- Getting to him.
local function Walk(npc, state)
	local rag = state.rag

	if npc:GetPos():DistToSqr(rag:GetPos()) > REACH * REACH then
		if CurTime() > state.until_ then
			Release(npc, state, "could not reach him")

			return
		end

		Repath(npc, state, rag:GetPos(), true)

		return
	end

	local spot = SafeSpot(npc, rag)

	if spot then
		StartDrag(npc, state, spot)
	else
		StartTreat(npc, state)
	end
end

-- Walking him out. The body is pulled by the 0.1s timer above; what is decided
-- here is only whether to keep going.
local function Drag(npc, state)
	local rag = state.rag
	local spot = state.spot

	local body = rag:GetPos()
	local arrived = body:DistToSqr(spot) < DRAG_ARRIVED * DRAG_ARRIVED

	if arrived or CurTime() > state.until_ then
		StartTreat(npc, state)

		return
	end

	-- Ahead of the body rather than at the spot: the rescuer is walking backwards
	-- in effect, and if it is allowed to path straight to a spot the body is caught
	-- on it walks off without him. Standing still while he catches up is what
	-- somebody dragging a man actually does.
	if npc:GetPos():DistToSqr(body) > DRAG_LEASH * DRAG_LEASH then
		npc:StopMoving()
		state.goal = nil

		return
	end

	Repath(npc, state, spot, false)
end

-- Working on him.
local function Treat(npc, state)
	local rag = state.rag
	local org = rag.organism
	local now = CurTime()
	local action = state.action

	if action then
		if isfunction(action.def.tick) and action.def.tick(npc, rag, org) == false then
			action.until_ = now -- it says it is finished early
		end

		if now < action.until_ then return end

		state.action = nil

		-- Back to a pair of working hands between treatments. The crouch stays; what
		-- the arms are doing in it is per treatment (cl_loot.lua).
		ZCNPC.SetWorkKind(npc, ZCNPC.Work.TREAT)

		local ok = action.def.finish(npc, rag, org)
		if not ok then state.failed[action.def.name] = true end

		StopLoop(state)

		local wep = state.wep
		state.wep = nil
		if IsValid(wep) then wep:Remove() end

		ZCNPC.Debug("rescue treatment", npc, action.def.name, ok and "done" or "did nothing")

		return
	end

	if now > state.until_ then
		Release(npc, state, "out of time")

		return
	end

	local def = Wanted(npc, org, state.failed)
	if not def then
		Release(npc, state, "nothing left to do for him")

		return
	end

	state.action = { def = def, until_ = now + (ActionTime(def) or 3) }

	-- Compressions are stacked hands and a lean, once every half second, and that is
	-- the rate this file compresses at rather than one somebody picked to look right.
	-- Everything else is a pair of hands working on a chest (cl_loot.lua).
	ZCNPC.SetWorkKind(npc, def.name == "cpr" and ZCNPC.Work.CPR or ZCNPC.Work.TREAT)

	if isfunction(def.start) then def.start(npc, state) end

	ZCNPC.Debug("rescue treating", npc, def.name)
end
--//

--\\ The pass, from the 0.5s walk in sv_disarmed.lua
local function Running(npc, state)
	-- The pass is the one thing certain to be running for every rescue, so it is
	-- what puts one back on the list the timer walks. A reloaded file starts with
	-- an empty list and a rescue in progress.
	working[npc] = true

	if not Enabled() then
		Release(npc, state, "switched off")

		return
	end

	if IsValid(npc.zcnpc_rag) then
		Release(npc, state, "went down")

		return
	end

	if npc:GetNetVar("handcuffed", false) then
		Release(npc, state, "cuffed")

		return
	end

	local org = ZCNPC.ResolveOrganism(npc)
	if not istable(org) or org.alive == false or org.otrub then
		Release(npc, state, "not conscious")

		return
	end

	if not Alone(npc) then
		Release(npc, state, "no longer alone")

		return
	end

	local rag = state.rag
	local info = IsValid(rag) and ZCNPC.Downed and ZCNPC.Downed[rag]

	-- He got up, or he died, or somebody took the body away. All three are the end
	-- of it and only one of them is a failure.
	if not (info and Savable(npc, rag, info)) then
		Release(npc, state, IsValid(rag) and "no longer his to save" or "body gone")

		return
	end

	if state.phase == "walk" then
		Walk(npc, state)
	elseif state.phase == "drag" then
		Drag(npc, state)
	else
		Treat(npc, state)
	end
end

function ZCNPC.UpdateRescue(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return end

	-- Teammate rescue is off: dragging a friend out and kneeling on his chest
	-- stretched the healer's arms at the body and left hitboxes / godmode in a
	-- mess. Any rescue already under way is dropped rather than finished.
	if istable(npc.zcnpc_rescue) then
		ZCNPC.CancelRescue(npc, "disabled")
	end
end
--//

--\\ The ways one ends without the pass noticing first
-- A rescuer that gets floored leaves the organism list the pass is walked from, so
-- UpdateRescue is never called for it again: without this the hold's own stale
-- clock is what ends the rescue, three seconds later, with the feet still taken.
hook.Add("ZCNPC_Downed", "zcnpc_rescue", function(npc)
	ZCNPC.CancelRescue(npc, "downed")
end)

hook.Add("ZCNPC_Disarmed", "zcnpc_rescue", function(npc)
	if not (IsValid(npc) and istable(npc.zcnpc_rescue)) then return end

	-- Only mid-treatment. A rifle knocked out of somebody's hands while they are
	-- dragging a man is not a reason to drop him; a kit knocked out of them is.
	if npc.zcnpc_rescue.phase == "treat" then
		ZCNPC.CancelRescue(npc, "disarmed")
	end
end)

-- Being shot at is the whole reason this only happens when nobody is about.
hook.Add("HomigradDamage", "zcnpc_rescue", function(victim)
	if not (IsValid(victim) and istable(victim.zcnpc_rescue)) then return end

	ZCNPC.CancelRescue(victim, "took a hit")
end)
--//
