--[[
	Handing out the loadouts sh_npcweapons.lua describes.

	One roll per NPC when it spawns: pick a class out of its group's list, take
	away whatever it arrived with, give it that.

	An empty list means one of two things, and which one is a setting
	(zcnpc_wep_random, on by default). On, a group nobody has written a list for
	rolls one gun out of everything installed that suits its job
	(sh_npcweapons.lua) - which is the same roll from here down, one class, given
	the same way and held the same way. Off, nothing is touched at all, and a
	Combine soldier turns up with the pulse rifle the spawner gave it.

	That roll only ever replaces, which a written list does not have to. A gun the
	spawner put in an NPC's hands is a choice somebody made and the roll is a
	different answer to the same question; no gun at all is not a question, so a
	refugee who turned up unarmed stays unarmed and a metrocop keeps its stunstick.
	Arming either of them is somebody writing it in their box, which is a choice
	rather than a side effect.

	The list is rolled per NPC rather than per group, which is what makes a squad
	of six with three rifles in the box look like a squad rather than a uniform.

	Nothing is re-rolled later. A gun taken off a body and a gun picked back up off
	the floor are the rest of the addon's business, and an NPC that has been
	disarmed once should stay disarmed rather than quietly re-equip itself the next
	time somebody opens the menu. `zcnpc_rearm` is the exception, and it is a
	console command an admin has to type.

	One roll, but not one hand-over. Combine and metrocops were the two groups the
	list appeared to do nothing to: put a Gail in the Combine box and the squad
	still turned up with pulse rifles and SMGs. The roll was happening, and so was
	the swap - it was simply being undone a moment later, because the gun those two
	arrive with is not in their hands on the frame they are created. It is created
	for them out of `additionalequipment`, and depending on who is doing the
	spawning - the spawn menu, a map's own npc_maker, a wave spawner that calls
	Spawn a tick after Create - that can land after us. We stripped nothing, gave
	the Gail, and the engine handed them a rifle on top of it and selected that.

	So the choice is held rather than handed over: for a couple of seconds after
	an NPC is armed, anything in its hands that is not what it rolled is taken back
	off it. After that the guard is dropped and what an NPC picks up off the floor
	(sv_disarmed.lua) is its own business again.
]]

local cfg = ZCNPC.Config

--\\ Convars, one per group
-- Replicated for the same reason every other setting is: the menu has to be able
-- to show what the server is running before anybody changes it.
for _, group in ipairs(ZCNPC.WeaponGroups) do
	if not ConVarExists(group.cvar) then
		CreateConVar(group.cvar, "", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
			"Weapons " .. group.name .. " spawn with, comma separated. Empty leaves them as they are, "
			.. ZCNPC.WeaponNone .. " spawns them with nothing")
	end
end
--//

-- "Everyone else" is every other humanoid, not every other entity with an AI:
-- an antlion has no hands to put a rifle in, and the skeleton is how the rest of
-- the addon decides the same question.
local function Humanoid(npc)
	for _, bone in ipairs(cfg.RequiredBones) do
		if not npc:LookupBone(bone) then return false end
	end

	return true
end

-- Whether the spawner gave this one a gun, which is the whole of what the
-- randomiser is allowed to replace.
--
-- A club does not count, and not for tidiness: the roll narrows to the job it
-- reads off what an NPC is holding, so a metrocop with a stunstick would be
-- handed another stunstick-shaped thing - variety nobody asked for, in exchange
-- for the riot metrocop the mapper placed. What an NPC spawned holding is left
-- alone everywhere else in the addon for the same reason (zcnpc_melee_pickup).
--
-- `m_spawnEquipment` is read for the same reason NpcRole reads it: the gun asked
-- for is a keyvalue until the engine turns it into a weapon a tick or two later,
-- so an NPC that is about to be armed does not look armed yet, and asking its
-- hands would read half a Combine squad as unarmed. An unclassifiable weapon
-- counts as a gun - on a server with packs mounted that is what it usually is,
-- and the alternative is a randomiser that quietly does nothing on exactly the
-- server it was written for.
local function ArmedWithGun(npc)
	for _, wep in ipairs(npc:GetWeapons() or {}) do
		if IsValid(wep) and ZCNPC.WeaponRole(wep:GetClass()) ~= "melee" then return true end
	end

	if not isfunction(npc.GetInternalVariable) then return false end

	local equip = npc:GetInternalVariable("m_spawnEquipment")
	if not (isstring(equip) and equip ~= "" and equip ~= "0") then return false end

	return ZCNPC.WeaponRole(string.lower(equip)) ~= "melee"
end

local function Wanted(npc)
	local id = ZCNPC.WeaponGroupOf(npc)
	if not id then return end
	if id == "other" and not Humanoid(npc) then return end

	-- Its own box, or the one it falls back to: a shotgunner nobody has written a
	-- shotgunner list for is a Combine soldier as far as this is concerned.
	local classes, weights, from = ZCNPC.WeaponListForNpc(id)

	-- Read before Strip takes the gun away below, because the gun is what says what
	-- this one's job is: a Combine shotgunner and a Combine rifleman are both
	-- npc_combine_s and nothing else tells them apart.
	local role = ZCNPC.NpcRole(npc)

	-- Nothing written down for it, so the gun comes out of everything installed
	-- (sh_npcweapons.lua) unless that has been turned off, in which case an empty
	-- box means what it used to and the NPC is left alone. A rolled gun is one gun
	-- rather than a list, so there is nothing left for the weighting or the job
	-- filter below to do to it.
	--
	-- The roll replaces a gun and never issues one. An NPC the spawner left
	-- without one is without one on purpose - a refugee, Kleiner, a workshop
	-- humanoid somebody put in a scene, a metrocop holding a stunstick - and an
	-- empty box is not an instruction to arm anybody; it is the absence of one.
	-- Wanting armed refugees is a list in the refugee box, which outranks this
	-- either way.
	if #classes == 0 then
		if not cfg.wep_random:GetBool() then return end
		if not ArmedWithGun(npc) then return end

		local group = ZCNPC.WeaponGroupById[id]

		return ZCNPC.RandomWeaponFor(role, group and group.role), "random " .. id
	end

	if cfg.wep_roles:GetBool() then
		classes = ZCNPC.WeaponsForRole(classes, role)
	end

	local class = ZCNPC.PickWeighted(classes, weights)

	return class or classes[math.random(#classes)], from or id
end

-- Everything except the one gun it is supposed to be holding. `keep` is an
-- entity rather than a class so that a duplicate of the right class - which is
-- what a late engine equip of the same rifle looks like - still goes.
local function Strip(npc, keep)
	for _, wep in ipairs(npc:GetWeapons() or {}) do
		if IsValid(wep) and wep ~= keep then wep:Remove() end
	end
end

--\\ Holding the choice against whatever arms the NPC next
-- How long a rolled loadout is defended for. Long enough to outlast a spawner
-- that calls Spawn on a later tick, short enough that it is over before an NPC
-- could have walked to a gun on the floor and picked it up.
local GUARD_TIME = 2

-- Checked at these offsets rather than on a Think: an NPC spawn is the only
-- moment this matters and eight calls is cheaper than a per-frame test that is
-- false for the entity's whole life.
local GUARD_STEPS = { 0, 0.05, 0.15, 0.35, 0.6, 1, 1.5, GUARD_TIME }

-- Anything that takes a gun away on purpose ends the guard, or it would be
-- handed straight back: an arm shot off (sv_weapon.lua), a knockout, a gun
-- looted off a body. DropWeapon is the one door all of those come through.
function ZCNPC.ClearLoadoutGuard(npc)
	if not IsValid(npc) then return end

	npc.zcnpc_wepwant = nil
	npc.zcnpc_wepguard = nil
end

local function Enforce(npc)
	if not IsValid(npc) then return end

	local want = npc.zcnpc_wepwant
	if not want then return end

	if (npc.zcnpc_wepguard or 0) < CurTime() then
		ZCNPC.ClearLoadoutGuard(npc)

		return
	end

	-- A body on the floor is holding its gun the way sv_weapon.lua decided, and
	-- the husk behind it is not the thing to give a rifle to.
	if IsValid(npc.zcnpc_rag) then return end

	-- An NPC with a surgical kit out has its rifle put back by the surgery when
	-- it is done with it (sv_cms.lua), and taking the kit out of its hands
	-- halfway through is not the guard's job.
	if istable(npc.zcnpc_cms) then return end

	-- Same for a bandage or a syringe. Both are handed over the same way and put back the
	-- same way (sv_medical.lua), and the guard reading the hand mid-use sees an item where it
	-- expected a rifle - it would take the item away and hand a fresh gun to a hand that is
	-- about to have its own put back into it.
	if istable(npc.zcnpc_meduse) then return end

	if want == ZCNPC.WeaponNone then
		Strip(npc)

		return
	end

	local held
	for _, wep in ipairs(npc:GetWeapons() or {}) do
		if not IsValid(wep) then continue end

		if not held and wep:GetClass() == want then
			held = wep
		else
			ZCNPC.Debug("loadout guard took back", wep:GetClass(), "from", npc)
			wep:Remove()
		end
	end

	if not IsValid(held) then
		held = npc:Give(want)
		if not IsValid(held) then return end
	end

	-- An NPC holding a weapon it has not selected does not shoot, and the engine
	-- equip we just undid may well have been the selected one.
	if npc:GetActiveWeapon() ~= held and isfunction(npc.SelectWeapon) then
		npc:SelectWeapon(want)
	end
end

local function Guard(npc, class)
	npc.zcnpc_wepwant = class
	npc.zcnpc_wepguard = CurTime() + GUARD_TIME

	for _, at in ipairs(GUARD_STEPS) do
		timer.Simple(at, function() Enforce(npc) end)
	end
end
--//

-- True when something was actually given or taken away.
function ZCNPC.ArmNPC(npc, force)
	if not ZCNPC.Enabled() then return false end
	if not (IsValid(npc) and npc:IsNPC()) then return false end
	if npc.zcnpc_loadout and not force then return false end
	if ZCNPC.IsZombie(npc) then return false end
	if cfg.Blacklist[npc:GetClass()] then return false end

	-- ZBase owns its own weapons. Stripping them on the first tick is how
	-- a custom ZBase NPC "never spawned" — Give of a Z-City gun mid-init
	-- aborts ZBaseInit, or leaves the SNPC without the weapon it requires.
	if ZCNPC.IsZBaseNPC and ZCNPC.IsZBaseNPC(npc) then
		npc.zcnpc_loadout = true

		return false
	end

	-- A body on the floor holds its gun in its hand (sv_weapon.lua) and the husk
	-- is not the thing to hand a rifle to.
	if IsValid(npc.zcnpc_rag) then return false end
	if npc:GetNetVar("handcuffed", false) then return false end

	-- A citizen whose model has not said rebel or refugee yet is not a loadout.
	-- Locking that in is how both boxes used to share one list: the first ask
	-- guessed refugee, remembered it, and the rebel box was never read.
	if npc:GetClass() == "npc_citizen" and not ZCNPC.WeaponGroupOf(npc) then
		return false
	end

	local class, id = Wanted(npc)

	-- Rolled once either way, so an NPC that spawned while the box was empty is
	-- not re-armed by a later pass of anything.
	npc.zcnpc_loadout = true

	if not class then return false end

	Strip(npc)

	if class == ZCNPC.WeaponNone then
		npc.zcnpc_nogun = true
		Guard(npc, class)
		ZCNPC.Debug("loadout", id, npc, "unarmed")

		return true
	end

	npc.zcnpc_nogun = nil

	local given = npc:Give(class)
	if not IsValid(given) then
		ZCNPC.Debug("loadout", id, npc, "could not give", class)

		return false
	end

	-- Give equips an NPC that has nothing in its hands, but not every base does
	-- it on the same frame, and an NPC holding a weapon it has not selected does
	-- not shoot. The guard picks the same job up from here.
	Guard(npc, class)

	ZCNPC.Debug("loadout", id, npc, class)

	return true
end

local function TryArm(ent, late)
	if not IsValid(ent) then return end
	if not ent:IsNPC() then return end
	if ent.zcnpc_loadout then return end

	-- A citizen's group is read off its model and its citizen type, and both often
	-- arrive a tick after the entity does - asked on the frame it was created,
	-- every rebel is a refugee. So citizens wait for the second pass, the same way
	-- the rebel armour kit does, and everything else is armed immediately.
	if not late and ent:GetClass() == "npc_citizen" then return end

	ZCNPC.ArmNPC(ent)
end

hook.Add("OnEntityCreated", "zcnpc_npcweapons", function(ent)
	if not (IsValid(ent) and ent:IsNPC()) then return end

	timer.Simple(0, function() TryArm(ent, false) end)
	timer.Simple(0.25, function() TryArm(ent, true) end)
	-- Same third pass the armour kit uses: a spawner that sets the rebel model
	-- after the first tick would otherwise lock the loadout as refugee.
	timer.Simple(0.75, function() TryArm(ent, true) end)
end)

-- Losing a gun on purpose is not the engine arming somebody behind our back, and
-- the guard must not hand it straight back. Every way one leaves an NPC's hands
-- comes through here: an arm shot off, a body searched while it was down, a
-- weapon taken by anything else that announces it.
hook.Add("ZCNPC_Disarmed", "zcnpc_npcweapons", function(npc)
	ZCNPC.ClearLoadoutGuard(npc)
end)

hook.Add("ZCNPC_Downed", "zcnpc_npcweapons", function(npc)
	ZCNPC.ClearLoadoutGuard(npc)
end)

concommand.Add("zcnpc_rearm", function(ply)
	if IsValid(ply) and not (ply:IsSuperAdmin() or game.SinglePlayer() or ply:IsListenServerHost()) then
		ply:ChatPrint("[ZCNPC] Only admins can re-arm NPCs.")

		return
	end

	local count = 0

	for npc in pairs(ZCNPC.NPCs or {}) do
		if IsValid(npc) and ZCNPC.ArmNPC(npc, true) then
			count = count + 1
		end
	end

	local text = "[ZCNPC] re-armed " .. count .. " NPC" .. (count == 1 and "" or "s")

	if IsValid(ply) then ply:ChatPrint(text) end
	print(text)
end, nil, "Give every NPC on the map the loadout its group is set to")
