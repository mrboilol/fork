--[[
	An NPC that has lost its gun.

	There are several ways for that to happen now and none of them used to lead
	anywhere good. Shoot the arm off and the gun falls out of it (sv_weapon.lua);
	knock one out and search the body while it is down and the gun leaves with you
	(sv_loot.lua); knock it out, take the gun, let it wake up. In every case what
	stood up was a soldier with empty hands, and what a Half-Life 2 soldier does
	with empty hands is walk at whoever it is angry with. It has no shot to line up
	any more, so nothing stops it closing the distance, and it arrives to hit you -
	or, having no melee attack either, to stand in front of you and look at you.

	That is the whole problem: the AI is still fighting a fight it has no way to
	take part in. So the two things a person would do instead are done here. If the
	gun is close enough to be worth it - and by preference the very gun it just
	lost - it goes and gets it. If it is not, it gets out of the open and stays
	there, which for an engine NPC means the cover it already knows how to find.

	Fetching a gun is optional (zcnpc_weapon_pickup). Charging bare handed was
	never a behaviour anybody chose, and there is no version of it worth keeping
	around to switch back on — off just means hide, not fists.
]]

local cfg = ZCNPC.Config

local SEARCH = 700 -- units around the NPC worth walking for
local REACH = 56 -- close enough to bend down and pick it up
local GIVE_UP = 12 -- seconds before a gun it cannot reach is written off
local RETHINK = 1.5 -- seconds between telling a hiding NPC to keep hiding
local CLOSE_ENEMY = 320 -- inside this, get away before anything else
local REPATH = 1.25 -- seconds between asking whether the walk is going anywhere
local ARRIVE = 0.1 -- how often an NPC on its way to a gun is measured against it

local function WeaponPickupEnabled()
	return not cfg.weapon_pickup or cfg.weapon_pickup:GetBool()
end

--\\ Close enough to bend down
-- Measured flat, with the height allowed separately, because a gun and the man
-- walking to it are not at the same height and the difference is not a distance he
-- has to cover. An NPC's origin is between its feet and a rifle's is wherever it
-- came to rest - on the floor, on the crate it bounced onto, a step below him on a
-- staircase - and a straight line to it spends most of the reach on that drop. The
-- window is deliberately lopsided: a gun above him is one he has to be nearly
-- standing on, a gun below him is still his.
local REACH_SQR = REACH * REACH
local REACH_UP = 72
local REACH_DOWN = 48

local function InReach(npc, wep)
	local from, to = npc:GetPos(), wep:GetPos()

	local dz = to.z - from.z
	if dz > REACH_UP or dz < -REACH_DOWN then return false end

	local dx, dy = to.x - from.x, to.y - from.y

	return dx * dx + dy * dy < REACH_SQR
end
--//

--\\ Walking to it, and noticing that you got there
-- Everything else in here is decided by the half second pass, and arriving cannot
-- be: an NPC at a run crosses a hundred units in half a second and the reach it is
-- measured against is a little over fifty, so the pass that should have caught it
-- standing on the rifle catches it already past - and then does nothing, because as
-- far as it knows it is still walking to where the rifle is. That is the whole of
-- "it does not pick it up the first time": a lap of the room and a second look, for
-- a gun it has already stepped over twice.
--
-- So arriving is asked ten times a second instead, and only of the few NPCs that
-- are on their way to something. The set is empty on a map where nobody has been
-- disarmed, which is nearly always.
local walking = {} -- [npc] = true, while it is on its way to a weapon

local function ClearFetch(npc)
	npc.zcnpc_fetch = nil
	npc.zcnpc_fetchuntil = nil
	npc.zcnpc_fetchpos = nil
	npc.zcnpc_fetchat = nil
	npc.zcnpc_fetchcheck = nil

	if not IsValid(npc.zcnpc_upgrade) then walking[npc] = nil end
end

local function ClearUpgrade(npc)
	npc.zcnpc_upgrade = nil
	npc.zcnpc_upgradeuntil = nil
	npc.zcnpc_upgradepos = nil
	npc.zcnpc_upgradeat = nil
	npc.zcnpc_upgradecheck = nil

	if not IsValid(npc.zcnpc_fetch) then walking[npc] = nil end
end

-- The walk, re-aimed when it needs to be. Armour and the body search have done
-- this all along and the gun was the one errand that did not (sv_armor.lua): a
-- schedule re-issued every pass restarts the walk from nowhere every pass, so it
-- was only ever issued once - and then a forced walk that ended short, one the
-- combat AI took back, and a rifle that has rolled since all left an NPC standing
-- still with somewhere to be.
--
-- `at` is where it was standing a moment ago, and it is the only way to tell those
-- apart from here: somewhere it cannot reach looks exactly like somewhere it is on
-- its way to, and the difference is whether it has moved since.
--
-- Returns the three things the caller remembers, or nothing when there is nothing
-- to change.
local function Approach(npc, goal, lastGoal, lastAt, due)
	local origin = npc:GetPos()

	local movedGoal = not lastGoal or lastGoal:DistToSqr(goal) > 48 * 48
	local stuck = due and lastAt and origin:DistToSqr(lastAt) < 24 * 24

	if npc:GetCurrentSchedule() ~= SCHED_FORCED_GO_RUN or movedGoal or stuck then
		npc:ClearSchedule()
		npc:SetLastPosition(goal)
		npc:SetSchedule(SCHED_FORCED_GO_RUN)

		return Vector(goal), Vector(origin), CurTime() + REPATH
	end

	if due then return lastGoal, Vector(origin), CurTime() + REPATH end
end
--//

--\\ What counts as a gun worth crossing a street for
-- Z-City's own guns all descend from homigrad_base, which is what separates them
-- from its bandages (weapon_base), its knives (weapon_melee) and its handcuffs
-- (weapon_tpik_base) without naming any of them. The engine weapons are listed
-- because only some of them have the NPC support to be fired at all.
local engineGuns = {
	["weapon_ar2"] = true,
	["weapon_smg1"] = true,
	["weapon_pistol"] = true,
	["weapon_357"] = true,
	["weapon_shotgun"] = true,
	["weapon_crossbow"] = true,
	["weapon_alyxgun"] = true,
	["weapon_annabelle"] = true,
}

-- Read once per class. weapons.IsBasedOn walks a SWEP's whole inheritance chain, and
-- these are asked of every weapon lying near every NPC on the map twice a second - of
-- perhaps two dozen distinct classes, over and over, for an answer that cannot change
-- while the map is running.
local isGun, isMelee = {}, {}

local function ClearClasses()
	isGun, isMelee = {}, {}
end

hook.Add("OnReloaded", "zcnpc_disarmed_classes", ClearClasses)

local function IsGun(class)
	local answer = isGun[class]

	if answer == nil then
		answer = engineGuns[class] == true or weapons.IsBasedOn(class, "homigrad_base") == true
		isGun[class] = answer
	end

	return answer
end

-- The body search (sv_looting.lua) is asking the same question about the same
-- kind of thing, one pocket further in.
ZCNPC.IsGunClass = IsGun

--\\ A knife is not something to pick up
-- Fetching, above, has never offered anybody a knife: IsGun is what it looks for
-- and Z-City's melee weapons are not guns. They were being picked up all the same,
-- by the engine, which walks an NPC over anything lying on the floor that says it
-- may be taken - and every one of Z-City's melee weapons says so
-- (weapon_melee.lua:2028). A Lua weapon is not pickable by an NPC unless it opts
-- in like that, so opting them back out is the whole of the switch.
--
-- Which is worth doing because of what an NPC does with one. It has a rifle it
-- cannot use any more and it has just found a crowbar, so it stops looking for a
-- rifle, and the AI that had nothing to do at range now has something: walk at
-- whoever it is angry with. That is the same charge sv_disarmed.lua exists to
-- stop, arriving by a different door.
--
-- What an NPC spawned holding is a different question and is left alone - a
-- metrocop's stunstick is its own.
local MELEE = "weapon_melee"

local function MeleePickupEnabled()
	return not cfg.melee_pickup or cfg.melee_pickup:GetBool()
end

local function IsMelee(class)
	local answer = isMelee[class]

	if answer == nil then
		answer = class == MELEE or weapons.IsBasedOn(class, MELEE) == true
		isMelee[class] = answer
	end

	return answer
end

ZCNPC.IsMeleeWeapon = IsMelee

-- The answer while the switch is on is the one the weapon would have given, not a
-- flat yes: a weapon somebody wrote to refuse NPCs for a reason of its own keeps
-- refusing them.
local function Wrap(tbl, inherited)
	if not istable(tbl) or tbl.zcnpc_melee then return end

	tbl.zcnpc_melee = true
	tbl.CanBePickedUpByNPCs = function(wep, ...)
		if not MeleePickupEnabled() then return false end
		if isfunction(inherited) then return inherited(wep, ...) end

		return true
	end
end

local function BlockMeleePickup()
	local base = weapons.GetStored(MELEE)
	if not istable(base) then return end -- no Z-City melee: nothing opted in

	-- Children are merged out of the base every time one is created
	-- (weapons.Get), so the base covers all of them - except the few that answer
	-- for themselves, which are patched where they say it.
	for _, wep in ipairs(weapons.GetList()) do
		local class = wep.ClassName

		if class ~= MELEE and IsMelee(class) then
			local stored = weapons.GetStored(class)

			if istable(stored) and rawget(stored, "CanBePickedUpByNPCs") then
				Wrap(stored, stored.CanBePickedUpByNPCs)
			end
		end
	end

	Wrap(base, base.CanBePickedUpByNPCs)

	-- And the ones already lying on the floor. A weapon copies its class table
	-- into its own when it is created, so a knife that existed before this ran
	-- is still holding the old answer.
	for _, wep in ipairs(ents.GetAll()) do
		if wep:IsWeapon() and IsMelee(wep:GetClass()) then
			Wrap(wep:GetTable(), wep.CanBePickedUpByNPCs)
		end
	end
end

BlockMeleePickup()
hook.Add("InitPostEntity", "zcnpc_melee_pickup", BlockMeleePickup)
--//

-- A weapon lying in the world has no owner. One in somebody's hands does, and
-- walking up to a rifle another soldier is holding is not fetching it.
local function Loose(wep)
	return IsValid(wep) and not IsValid(wep:GetOwner()) and not wep:IsPlayerHolding()
end

--\\ The weapons there are
-- Every weapon entity on the map, held or lying down, because which of those a weapon
-- is changes constantly and being on the list does not. Weak keys, so one that is
-- removed takes its entry with it and nothing has to be told it has gone.
--
-- Both searches below were a sphere before this: seven hundred units around every NPC
-- with empty hands, four hundred and twenty around every NPC with a gun in them, twice
-- a second each. The second is the expensive one, because nearly every NPC has a gun -
-- a firefight that ends with a dozen soldiers standing and a dozen rifles on the floor
-- was two dozen sweeps of the whole world every second, every one of them asking about
-- the same two dozen weapons. Which is most of what "it lags once a few of them are
-- dead" was.
local guns = setmetatable({}, { __mode = "k" })

hook.Add("OnEntityCreated", "zcnpc_disarmed_guns", function(ent)
	if IsValid(ent) and ent:IsWeapon() then guns[ent] = true end
end)

local function ScanGuns()
	for _, ent in ipairs(ents.GetAll()) do
		if ent:IsWeapon() then guns[ent] = true end
	end
end

-- The ones that were already lying about, map placed or spawned before this loaded.
hook.Add("InitPostEntity", "zcnpc_disarmed_guns", ScanGuns)
hook.Add("PostCleanupMap", "zcnpc_disarmed_guns", ScanGuns)
ScanGuns()
--//

local function WantedGun(npc, class)
	if not IsGun(class) then return false end
	if npc.zcnpc_fetchbad and npc.zcnpc_fetchbad[class] then return false end
	if ZCNPC.CanHoldClass and not ZCNPC.CanHoldClass(npc, class) then return false end

	return true
end

local function FindGun(npc)
	-- The one it lost, if it is still lying where it fell. Everything else being
	-- equal an NPC should want its own rifle back, and it usually is the nearest
	-- thing anyway - this only settles the case where it is not.
	local own = npc.zcnpc_lostwep
	local origin = npc:GetPos()
	local searchSqr = SEARCH * SEARCH

	if Loose(own) and own:GetPos():DistToSqr(origin) < searchSqr
		and WantedGun(npc, own:GetClass()) then
		return own
	end

	local best, bestDist

	for wep in pairs(guns) do
		if not IsValid(wep) then
			guns[wep] = nil
		elseif Loose(wep) then
			local dist = wep:GetPos():DistToSqr(origin)

			if dist < searchSqr and not (bestDist and dist >= bestDist)
				and WantedGun(npc, wep:GetClass()) then
				best, bestDist = wep, dist
			end
		end
	end

	return best
end
--//

--\\ Picking one up
-- There is no NPC:PickupWeapon, so the weapon on the floor is exchanged for a
-- fresh one in the hand, which is the same trick ZCNPC.DropWeapon does in the
-- other direction and for the same reason. GetInfo/SetInfo is Z-City's own state
-- transfer (homigrad_base/shared.lua:802), so a half empty magazine stays half
-- empty and whatever was bolted to the rail stays bolted to it.
local function TakeGun(npc, wep)
	if not (IsValid(npc) and IsValid(wep)) then return false end
	if IsValid(npc:GetActiveWeapon()) then return false end -- the AI got there first

	local class = wep:GetClass()
	if ZCNPC.CanHoldClass and not ZCNPC.CanHoldClass(npc, class) then return false end
	local state = wep.GetInfo and wep:GetInfo() or nil

	local given = npc:Give(class)

	-- Refused the class outright, which walking back to it will not change: a
	-- weapon whose SWEP will not attach to an NPC at all, or one the loadout guard
	-- is about to take off it again. Remembered, so the next search offers it
	-- something else rather than starting the same walk to the same rifle - which
	-- is the loop that reads from the floor as an NPC that cannot pick anything up.
	if not IsValid(given) then
		npc.zcnpc_fetchbad = npc.zcnpc_fetchbad or {}
		npc.zcnpc_fetchbad[class] = true

		ZCNPC.Debug("refused", class, "-", npc)

		return false
	end

	if state and given.SetInfo then given:SetInfo(state) end
	wep:Remove()

	npc:EmitSound("items/itempickup.wav", 60, math.random(95, 105))
	ZCNPC.Debug("picked its weapon back up:", npc, class)

	return true
end
--//

--\\ Trading up
-- Everything above is about an NPC with nothing in its hands, and for a long time
-- that was the only NPC that ever went to fetch anything: a metrocop with a pistol
-- would stand next to the AR2 its squad mate had just dropped and go on firing nine
-- millimetre at you. Which is not what a person does, and not what the rest of the
-- addon does either - a rebel searching a body already takes a better gun off it
-- (sv_looting.lua) and has done all along.
--
-- Same measure as that search, deliberately: ZCNPC.WeaponScore is damage a second
-- and a magazine, and the two have to agree or an NPC will walk across a room for
-- something it would then refuse to keep.
--
-- What its job is has no say here. A shotgunner is issued a shotgun (zcnpc_wep_roles,
-- sv_npcweapons.lua) and that is a quartermaster's decision made at spawn; a man
-- who has lost his and finds a rifle on the floor picks up the rifle.
local UPGRADE_SEARCH = 420 -- shorter than SEARCH: worth a few steps, not a trek
local UPGRADE_GAIN = 1.35 -- and worth those steps, so a third better again
local UPGRADE_GIVE_UP = 8

-- And how long an NPC that looked and found nothing waits before looking again. A
-- street does not fill up with rifles between two passes half a second apart, and this
-- is the question nearly every armed NPC on the map asks - which is what made it worth
-- asking less often.
local UPGRADE_NOTHING = 3

local function CanUpgrade(npc)
	if not (cfg.weapon_upgrade and cfg.weapon_upgrade:GetBool()) then return false end
	if not WeaponPickupEnabled() then return false end

	-- Told to spawn unarmed (sv_npcweapons.lua), and mid-swap, which is what stops
	-- the drop below calling straight back in here through ZCNPC_Disarmed and
	-- picking the gun it just put down back up.
	if npc.zcnpc_nogun or npc.zcnpc_swapping then return false end

	-- Its spawn loadout is still being held against the engine (sv_npcweapons.lua),
	-- and a gun taken off the floor inside that window is one the guard takes back
	-- off it a tick later.
	if (npc.zcnpc_wepguard or 0) > CurTime() then return false end

	if not ZCNPC.CanUseWeapon(npc) then return false end
	if ZCNPC.HasHeadcrab and ZCNPC.HasHeadcrab(npc) then return false end

	-- Where an NPC puts its feet is the map's to say (sv_core.lua), and the walk to
	-- the gun is a schedule.
	if ZCNPC.MapDriven(npc) then return false end

	-- Errands that already own the feet, and every one of them outranks this: it
	-- has a working gun in its hands, so a better one is the least urgent thing an
	-- NPC can be doing. Same list the body search stands down for (sv_looting.lua),
	-- read the same way.
	if istable(npc.zcnpc_cms) then return false end
	if istable(npc.zcnpc_meduse) then return false end
	if IsValid(npc.zcnpc_fetch) or IsValid(npc.zcnpc_fetcharmor) then return false end
	if IsValid(npc.zcnpc_healally) or IsValid(npc.zcnpc_lootbody) then return false end
	if (npc.zcnpc_bandagecover or 0) > CurTime() then return false end

	-- And not with a man standing over it. Turning your back on somebody that close
	-- to go and pick something up is how you die holding it.
	local enemy = npc:GetEnemy()

	return not (IsValid(enemy) and npc:GetPos():DistToSqr(enemy:GetPos()) < CLOSE_ENEMY * CLOSE_ENEMY)
end

local function BetterGun(npc, floor)
	local origin = npc:GetPos()
	local searchSqr = UPGRADE_SEARCH * UPGRADE_SEARCH
	local refused = npc.zcnpc_fetchbad
	local best, bestScore, bestDist

	for wep in pairs(guns) do
		if not IsValid(wep) then
			guns[wep] = nil

			continue
		end

		if not Loose(wep) then continue end

		local dist = wep:GetPos():DistToSqr(origin)
		if dist >= searchSqr then continue end

		local class = wep:GetClass()

		-- Classes the engine has already refused to hand this NPC. Reading it here is
		-- what stops the walk that never ends: a rifle Give says no to is one the swap
		-- cannot complete, and without this the NPC put its own gun down in front of it,
		-- picked it back up because that was all there was to pick up, and set off for
		-- the same refused rifle again on the next pass. From the outside that is a man
		-- standing over a corpse looting his own last gun instead of the better one.
		if refused and refused[class] then continue end
		if not IsGun(class) then continue end
		if ZCNPC.CanHoldClass and not ZCNPC.CanHoldClass(npc, class) then continue end

		local score = ZCNPC.WeaponScore(class)
		if score < floor * UPGRADE_GAIN then continue end

		-- The best gun going, and the nearest of the ones that tie - two of the
		-- same rifle on the floor should not be a coin toss over which to walk to.
		if not best or score > bestScore or (score == bestScore and dist < bestDist) then
			best, bestScore, bestDist = wep, score, dist
		end
	end

	return best
end

-- The better gun into the hand first, and only then its own onto the floor. Which is
-- safe because of what Give does to an NPC: the engine equips the new weapon, makes it
-- active and leaves the old one in the inventory - "NPCs always take the new weapon" -
-- so the swap is one weapon being given and then one being put down, and there is never
-- a moment with empty hands in the middle of it.
--
-- The other order is what "it stands there picking its own gun back up" was. Its rifle
-- went on the floor, Give said no to the new class, and the only thing left to do was
-- pick the old one back up - from where the next pass walked it to the same refused
-- rifle and did the whole thing again. So the refusal is written down as well, where the
-- search that chose it will read it (BetterGun).
local function SwapGun(npc, wep)
	if not (IsValid(npc) and IsValid(wep)) then return false end

	local class = wep:GetClass()
	if ZCNPC.CanHoldClass and not ZCNPC.CanHoldClass(npc, class) then return false end

	local state = wep.GetInfo and wep:GetInfo() or nil

	-- The one it is holding, read before Give makes that the new one.
	local old = ZCNPC.HeldGun(npc)

	npc.zcnpc_swapping = true

	local given = npc:Give(class)

	if not IsValid(given) then
		npc.zcnpc_swapping = nil

		npc.zcnpc_fetchbad = npc.zcnpc_fetchbad or {}
		npc.zcnpc_fetchbad[class] = true

		ZCNPC.Debug("refused", class, "-", npc)

		return false
	end

	if state and given.SetInfo then given:SetInfo(state) end
	wep:Remove()

	-- And its own into the street, out of the hand that was holding it, where the next
	-- man along can have it. Placed rather than dropped: ZCNPC.DropWeapon is for a gun
	-- that was lost, and it says so out loud (sv_weapon.lua) - which would send this NPC
	-- straight back for the pistol it just chose to put down.
	if IsValid(old) and old ~= given then
		local bone = npc:LookupBone("ValveBiped.Bip01_R_Hand")

		ZCNPC.PlaceWeapon(old, bone and npc:GetBonePosition(bone) or npc:WorldSpaceCenter(), AngleRand())
	end

	-- An NPC holding a weapon it has not selected does not fire it.
	if isfunction(npc.SelectWeapon) then npc:SelectWeapon(class) end

	npc:EmitSound("items/itempickup.wav", 60, math.random(95, 105))
	ZCNPC.Debug("traded up to", class, "-", npc)

	-- It put that one down on purpose, so it is not the one to go back for.
	npc.zcnpc_lostwep = nil
	npc.zcnpc_swapping = nil

	return true
end

-- Standing over the better gun. Split out for the same reason Arrive below is: the
-- arrival poll has to be able to ask it without re-deciding the walk.
local function ArriveUpgrade(npc, wep)
	if not InReach(npc, wep) then return false end

	SwapGun(npc, wep)
	ClearUpgrade(npc)

	return true
end

local function Upgrade(npc)
	if not CanUpgrade(npc) then
		ClearUpgrade(npc)

		return
	end

	local held = npc:GetActiveWeapon()
	if not IsValid(held) then return end

	local heldClass = held:GetClass()

	-- A gun trades up for a gun, and a club trades up for anything. Anything else
	-- in an NPC's hands is a job in progress rather than a weapon.
	local melee = IsMelee(heldClass)
	if not (IsGun(heldClass) or melee) then return end

	-- Zero for a club, so the first gun it sees beats it.
	local floor = melee and 0 or ZCNPC.WeaponScore(heldClass)

	local wep = npc.zcnpc_upgrade
	if not (Loose(wep) and ZCNPC.WeaponScore(wep:GetClass()) >= floor * UPGRADE_GAIN) then wep = nil end

	if not wep then
		if (npc.zcnpc_upgradenext or 0) > CurTime() then return end

		wep = BetterGun(npc, floor)
	end

	if not wep then
		ClearUpgrade(npc)
		npc.zcnpc_upgradenext = CurTime() + UPGRADE_NOTHING

		return
	end

	npc.zcnpc_upgrade = wep
	npc.zcnpc_upgradeuntil = npc.zcnpc_upgradeuntil or (CurTime() + UPGRADE_GIVE_UP)
	walking[npc] = true

	if ArriveUpgrade(npc, wep) then return end

	-- Written off rather than chased forever: it still has a gun, so failing to
	-- reach a better one costs it nothing but the walk.
	if CurTime() > npc.zcnpc_upgradeuntil then
		ClearUpgrade(npc)

		return
	end

	local due = (npc.zcnpc_upgradecheck or 0) < CurTime()
	local goal, at, check = Approach(npc, wep:GetPos(), npc.zcnpc_upgradepos, npc.zcnpc_upgradeat, due)

	if check then
		npc.zcnpc_upgradepos, npc.zcnpc_upgradeat, npc.zcnpc_upgradecheck = goal, at, check
	end
end
--//

--\\ The two capabilities that make an unarmed NPC walk at you
-- CAP_USE_WEAPONS is what the whole business of standing off and shooting hangs
-- on; with it gone the AI has nothing to do at range and closes in. Both melee
-- capabilities are what it intends to do when it arrives. Taking all three away
-- leaves an NPC that treats the enemy as something to keep away from, which is
-- what an unarmed one should think.
--
-- What it had is read once and before anything is removed, so giving it back is
-- giving back rather than granting: an NPC that never had a melee attack must not
-- come out of this with one.
local caps = { CAP_USE_WEAPONS, CAP_INNATE_MELEE_ATTACK1, CAP_INNATE_MELEE_ATTACK2 }

local function Fighting(npc, allowed)
	if npc.zcnpc_capsheld == nil then
		local had = {}
		local now = npc:CapabilitiesGet()

		for i, cap in ipairs(caps) do had[i] = bit.band(now, cap) ~= 0 end

		npc.zcnpc_capsheld = had
	end

	if npc.zcnpc_canfight == allowed then return end
	npc.zcnpc_canfight = allowed

	for i, cap in ipairs(caps) do
		if not allowed then
			npc:CapabilitiesRemove(cap)
		elseif npc.zcnpc_capsheld[i] then
			npc:CapabilitiesAdd(cap)
		end
	end
end
--//

--\\ Keeping out of it
local function Hide(npc)
	if (npc.zcnpc_hidenext or 0) > CurTime() then return end
	npc.zcnpc_hidenext = CurTime() + RETHINK

	local enemy = npc:GetEnemy()
	if not IsValid(enemy) then return end

	-- Cover is somewhere to be, and being somewhere is no use with a man standing
	-- over you. Close up, the first thing to do is not be there.
	if npc:GetPos():DistToSqr(enemy:GetPos()) < CLOSE_ENEMY * CLOSE_ENEMY then
		npc:SetSchedule(SCHED_RUN_FROM_ENEMY)
	else
		npc:SetSchedule(SCHED_TAKE_COVER_FROM_ENEMY)
	end
end

-- Standing over it. Split out because two things ask: the half second pass, which
-- is where the walk is decided, and the arrival poll, which is the only one fast
-- enough to catch the moment.
local function Arrive(npc, wep)
	if not InReach(npc, wep) then return false end

	-- Handed back the moment it has something to fight with, rather than on the
	-- next pass: half a second of holding a rifle it is not allowed to fire is
	-- half a second of walking towards you with it.
	if TakeGun(npc, wep) then
		Fighting(npc, true)
		ClearFetch(npc)
	elseif IsValid(npc:GetActiveWeapon()) then
		-- Something armed it on the way over. Nothing left to fetch.
		ClearFetch(npc)
	end

	-- Anything else is a refusal, and it keeps the gun: the give-up timer owns how
	-- long it goes on trying. Dropping the target here is what used to send it back
	-- to the search to choose the same rifle again from scratch.
	return true
end

local function Fetch(npc, wep)
	npc.zcnpc_fetch = wep
	npc.zcnpc_fetchuntil = npc.zcnpc_fetchuntil or (CurTime() + GIVE_UP)
	walking[npc] = true

	if Arrive(npc, wep) then return end

	-- Given up on: either it cannot get there or something is in the way, and
	-- standing in the open failing to reach a rifle is worse than hiding.
	if CurTime() > npc.zcnpc_fetchuntil then
		ClearFetch(npc)
		npc.zcnpc_nofetch = CurTime() + GIVE_UP

		return
	end

	local due = (npc.zcnpc_fetchcheck or 0) < CurTime()
	local goal, at, check = Approach(npc, wep:GetPos(), npc.zcnpc_fetchpos, npc.zcnpc_fetchat, due)

	if check then
		npc.zcnpc_fetchpos, npc.zcnpc_fetchat, npc.zcnpc_fetchcheck = goal, at, check
	end
end

-- The NPC is standing, awake and holding nothing. Everything above is which of
-- the two things it does about that.
local function Unarmed(npc)
	-- Told to spawn with nothing (sv_npcweapons.lua). "Unarmed" was a choice
	-- somebody made in the menu, so it is not something to fix by fetching a
	-- rifle off the floor - it keeps out of the fight instead.
	if npc.zcnpc_nogun or not WeaponPickupEnabled() then
		ClearFetch(npc)
		Hide(npc)
		return
	end

	local wep = npc.zcnpc_fetch
	if not Loose(wep) then wep = nil end

	if not wep and (npc.zcnpc_nofetch or 0) < CurTime() then wep = FindGun(npc) end

	if wep then
		Fetch(npc, wep)
	else
		Hide(npc)
	end
end

-- A gun user is an NPC the engine gave CAP_USE_WEAPONS to, which is every class
-- that fights with one and none of the ones that do not. Read off the record
-- Fighting keeps, because by the time this is asked the capability may well have
-- been taken away by the answer to it.
local function GunUser(npc)
	local had = npc.zcnpc_capsheld
	if had then return had[1] end

	return bit.band(npc:CapabilitiesGet(), CAP_USE_WEAPONS) ~= 0
end

function ZCNPC.UpdateDisarmed(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return end
	if IsValid(npc.zcnpc_rag) then return end -- on the floor, which has its own rules
	if ZCNPC.IsZombie(npc) then return end

	-- Halfway through a trade. Its old gun is on the floor and the new one is not in
	-- its hands yet, so an NPC read right now is an NPC with nothing - and what this
	-- function does about nothing is send it to fetch the gun it deliberately just
	-- put down. ZCNPC.DropWeapon announces every loss through ZCNPC_Disarmed, which
	-- is how a swap arrives back here mid-swap.
	if npc.zcnpc_swapping then return end

	-- Still climbing off the floor. Its feet are not its own to send anywhere yet
	-- (sv_getup.lua holds them still for the length of the animation) and a schedule
	-- handed to it now would be a schedule it spends the animation fighting.
	if (ZCNPC.GettingUp[npc] or 0) > CurTime() then return end

	-- Nor are they while it has hold of somebody (sv_rescue.lua). A rifle on the
	-- floor is worth going back for later; a man is worth going back for now, and
	-- the two errands both being schedules is the two of them fighting.
	if istable(npc.zcnpc_rescue) then return end

	local org = ZCNPC.ResolveOrganism(npc)
	if org and org.alive == false then return end

	-- Cuffed is a different kind of out of the fight and sv_cuffs.lua owns it.
	if npc:GetNetVar("handcuffed", false) then return end

	-- An arm it does not have is the one case where the gun on the floor is not
	-- the answer, so it is not offered one. It hides instead.
	local armed = IsValid(npc:GetActiveWeapon())
	local able = ZCNPC.CanUseWeapon(npc)

	Fighting(npc, armed or not GunUser(npc))

	if armed then
		ClearFetch(npc)
		npc.zcnpc_nofetch = nil

		-- Holding something, which used to be the end of the matter. It is not: what
		-- it is holding may be a pistol with a rifle lying next to it. Only for an
		-- NPC that shoots, though - a gun is not an upgrade to something with no way
		-- to fire one.
		if GunUser(npc) then Upgrade(npc) end

		return
	end

	if not GunUser(npc) then return end

	-- The capabilities above are still taken away from it - an unarmed NPC that
	-- has nothing to do at range still must not close the distance - but where it
	-- stands is the map's to say (sv_core.lua). Both answers below are a schedule,
	-- and a scripted NPC has one already.
	if ZCNPC.MapDriven(npc) then
		ClearFetch(npc)
		ClearUpgrade(npc)

		return
	end

	if able then
		Unarmed(npc)
	else
		Hide(npc)
	end
end

timer.Create("zcnpc_disarmed", 0.5, 0, function()
	if not ZCNPC.Enabled() then return end
	if not (istable(hg) and istable(hg.organism) and istable(hg.organism.list)) then return end

	-- Asked once for the pass, not once per NPC: the kit being on the workshop
	-- and the Q-menu switches do not change between two bodies in the same tick.
	local healOn = not cfg.selfheal or cfg.selfheal:GetBool()
	local armorOn = not cfg.armor_pickup or cfg.armor_pickup:GetBool()
	local lootOn = not cfg.looting or cfg.looting:GetBool()
	local cmsOn = ZCNPC.CmsInstalled and ZCNPC.CmsInstalled() and (not cfg.cms or cfg.cms:GetBool())
	local rebelOf = ZCNPC.IsRebelCitizen

	for npc in pairs(hg.organism.list) do
		if not (IsValid(npc) and npc:IsNPC()) then continue end

		-- The hidden half of a body is still on this list. It cannot fetch a
		-- gun or wrap a wound, and the chores below would only ask the same
		-- questions of it every half second until it stood up or died.
		if IsValid(npc.zcnpc_rag) then continue end

		-- One walk of the list for both, and in this order: an arm that can no
		-- longer hold a rifle drops it here, and what to do about empty hands is
		-- decided immediately after rather than half a second later.
		ZCNPC.UpdateArms(npc)
		ZCNPC.UpdateDisarmed(npc)

		-- Same pass as self-heal / armour (was a second full walk of organism.list).
		-- Heal first: cover-before-bandage and medic ally runs must own the feet
		-- before a loose vest sends them the other way.
		--
		-- Then, in order of how badly it is wanted: a wound closed, a leftover
		-- rescue hold cancelled, a vest, the surgical kit that costs twelve
		-- seconds of standing still, and last a body across the room. Each of
		-- the five stands down for any earlier one that is already holding the
		-- feet, so the order here is the order they get a chance rather than a
		-- priority anybody has to trust.
		if healOn and ZCNPC.UpdateSelfHeal then ZCNPC.UpdateSelfHeal(npc) end

		-- Rescue is off. Only a leftover hold still needs cancelling.
		if istable(npc.zcnpc_rescue) and ZCNPC.UpdateRescue then
			ZCNPC.UpdateRescue(npc)
		end

		if armorOn and ZCNPC.UpdateArmorPickup then ZCNPC.UpdateArmorPickup(npc) end

		-- Mid-surgery must still run when the switch is off, so a needle already
		-- in a leg is put away rather than left kneeling forever.
		if ZCNPC.UpdateCms and (cmsOn or istable(npc.zcnpc_cms)) then
			ZCNPC.UpdateCms(npc)
		end

		-- Same for a search already under way. Fresh looks are rebels only, and
		-- only while looting is on: everybody else used to walk the whole
		-- function just to be told they were the wrong kind of citizen.
		if ZCNPC.UpdateBodyLoot then
			local looting = npc.zcnpc_lootcrouch or IsValid(npc.zcnpc_lootbody)

			if looting or (lootOn and rebelOf and rebelOf(npc)) then
				ZCNPC.UpdateBodyLoot(npc)
			end
		end
	end
end)

-- Arriving, ten times a second, for the few NPCs on their way to a weapon.
--
-- Nothing is decided here. Whether to go at all, where to walk, when to give up
-- and what outranks what are all the half second pass's, unchanged; this asks the
-- one question that cannot wait half a second for an answer, which is whether the
-- NPC is standing on the thing yet. Twenty units of travel between looks instead
-- of a hundred, against a reach of fifty six.
timer.Create("zcnpc_disarmed_reach", ARRIVE, 0, function()
	if not ZCNPC.Enabled() then return end
	if not next(walking) then return end

	for npc in pairs(walking) do
		if not (IsValid(npc) and npc:IsNPC()) then
			walking[npc] = nil

			continue
		end

		-- Down, mid-swap or holding somebody: the three that can begin between two
		-- passes of the timer that would otherwise have cleared the errand.
		if IsValid(npc.zcnpc_rag) or npc.zcnpc_swapping or istable(npc.zcnpc_rescue) then continue end

		local wep = npc.zcnpc_fetch

		if IsValid(wep) then
			if not Loose(wep) then
				ClearFetch(npc)
			else
				Arrive(npc, wep)
			end
		end

		wep = npc.zcnpc_upgrade

		if IsValid(wep) then
			if not Loose(wep) then
				ClearUpgrade(npc)
			else
				ArriveUpgrade(npc, wep)
			end
		end

		if not (IsValid(npc.zcnpc_fetch) or IsValid(npc.zcnpc_upgrade)) then
			walking[npc] = nil
		end
	end
end)

-- The moment the gun leaves the hand, rather than up to half a second later with
-- the AI already walking. Both the events that take one away come through here.
hook.Add("ZCNPC_Disarmed", "zcnpc_disarmed", function(npc)
	ZCNPC.UpdateDisarmed(npc)
end)
--//
