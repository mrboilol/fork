--[[
	A body on the floor does not fight.

	Going down takes the feet and nothing else. The NPC entity is still there under
	the body it is lying as - hidden, frozen on the spot it collapsed on, its enemy
	memory wiped once on the way down (sv_uncon.lua:279) - and none of that is the
	AI. The AI carries on: it looks around, it finds whoever is standing over the
	body, and it uses what it is still holding on them.

	From the outside that is a rifle hanging in the air shooting at you out of
	nobody, or a stunstick swinging at whoever knelt down to bandage the man holding
	it. Both come out of the hidden entity, which is why they come from chest height
	over a body lying on the floor.

	There are three different answers to "may this NPC attack" and all three have to
	be told:

	* the NPC's own capabilities. sv_getup.lua takes the range ones away for the
	  length of the stand up animation for exactly this reason. A body on the floor
	  wants the same thing, the melee half with it, and for as long as it is down.
	* the weapon's. NPC:CapabilitiesGet is the NPC's own bits or the ones its weapon
	  hands out, so a rifle that says CAP_WEAPON_RANGE_ATTACK1 for itself
	  (homigrad_base/init.lua:60) gives the capability straight back however often it
	  is taken away. Z-City's guns and knives are Lua and can be asked to say nothing
	  while their owner is on the floor. Half-Life 2's own are C++ and cannot, so the
	  rounds are dropped instead, which is the answer sv_getup.lua already gives.
	* Z-City's melee base, which never waits to be asked. Its whole NPC attack runs
	  inside SWEP:GetCapabilities (weapon_melee.lua:1854) - a function the engine
	  calls on every AI think - and it finds its own target, sets its own
	  SCHED_MELEE_ATTACK1 and puts the damage through on a timer of its own
	  (:1795-1845). No capability taken from anybody stops that. The only thing that
	  does is the function not running.

	And the enemy itself, every pass, because sight is not a capability: an NPC
	cleared on the way down has somebody to be angry at again a moment later.

	A knockdown was written to be different from a knockout in exactly this - a body
	with somebody awake in it squirms, keeps hold of its gun and shoots back from
	where it is lying (sv_stun.lua:87) - and it is behind a switch now
	(zcnpc_downed_fight) rather than the way it works, because the shot does not come
	from where the body is. It comes from the entity nobody can see, standing up, at
	the spot the body was standing on when it fell. Firing back off the floor cannot
	look like anything but a gun in mid air until an NPC can be laid down, and
	Z-City's own weapon is worse than that: the stunstick reaches whoever is kneeling
	over the body, which is normally the person bandaging it.
]]

local cfg = ZCNPC.Config

--\\ What it may not do
local NO_FIGHT = {
	CAP_USE_WEAPONS,
	CAP_WEAPON_RANGE_ATTACK1,
	CAP_WEAPON_RANGE_ATTACK2,
	CAP_WEAPON_MELEE_ATTACK1,
	CAP_WEAPON_MELEE_ATTACK2,
	CAP_INNATE_RANGE_ATTACK1,
	CAP_INNATE_RANGE_ATTACK2,
	CAP_INNATE_MELEE_ATTACK1,
	CAP_INNATE_MELEE_ATTACK2,
}

-- Three of these belong to sv_disarmed.lua while an NPC is on its feet, and it
-- holds them off an unarmed one on purpose. Handing those back is its call.
local DISARMED = {
	[CAP_USE_WEAPONS] = true,
	[CAP_INNATE_MELEE_ATTACK1] = true,
	[CAP_INNATE_MELEE_ATTACK2] = true,
}

-- What was taken off each body, so that giving it back is giving back rather than
-- granting: an NPC that never had a melee attack must not come out of this with one.
--
-- Read off CapabilitiesGet, which is the NPC's own bits together with its weapon's,
-- so a capability that only ever came from the rifle is given to the NPC itself
-- here. That is the same trade sv_getup.lua and sv_disarmed.lua make, and it is a
-- harmless one: every CAP_WEAPON_ bit is read by the AI as "with the weapon I am
-- holding", so one left on an NPC with empty hands is one nothing ever asks about.
local muted = setmetatable({}, { __mode = "k" })

local function Mute(npc)
	local now = npc:CapabilitiesGet()
	local had = muted[npc]

	if not had then
		had = {}
		muted[npc] = had
	end

	for i, cap in ipairs(NO_FIGHT) do
		if bit.band(now, cap) == 0 then continue end

		-- Written down as it is taken rather than read once on the way down, because
		-- capabilities are handed back to a body while it is lying there: sv_cuffs.lua
		-- returns everything it was holding the moment a cuffed NPC is floored, and
		-- taken away against a list that says "it never had that" is taken away for
		-- good - the NPC would get back up unable to fight at all.
		had[i] = true
		npc:CapabilitiesRemove(cap)
	end
end

local function Unmute(npc)
	if not IsValid(npc) then
		muted[npc] = nil

		return
	end

	-- Cuffed is somebody else's kind of not fighting, and sv_cuffs.lua owns every
	-- capability an NPC has for as long as it lasts (sv_cuffs.lua:96). The record is
	-- kept rather than given back, because the set it hands over at the other end is
	-- the one it read while this was in force: dropped here, an NPC uncuffed later
	-- would be one that never gets its rifle back.
	if npc:GetNetVar("handcuffed", false) then return end

	local had = muted[npc]
	muted[npc] = nil
	if not had then return end

	for i, cap in ipairs(NO_FIGHT) do
		if not had[i] then continue end
		if npc.zcnpc_canfight == false and DISARMED[cap] then continue end

		npc:CapabilitiesAdd(cap)
	end
end
--//

--\\ Whether there is anything here that may attack
-- Asked by every part of this file, of the NPC rather than of the body, because the
-- NPC is the half that does the attacking.
--
-- "Somebody awake in there" is a question sv_execute.lua already asks of every body,
-- for a reason that is the other side of this one: a body worth finishing off is a
-- body that could still finish you.
local function Silenced(npc)
	if not IsValid(npc) then return false end

	-- Standing up is still being on the floor, and it is the one part of it this
	-- file could not see. ZCNPC.WakeUp hands the body back before it starts the
	-- animation - zcnpc_rag and the Downed entry are both cleared first
	-- (sv_uncon.lua:762) - so IsHidden is false for the whole length of a stand-up
	-- while the model everyone can see is still lying where it fell.
	--
	-- Rounds were caught anyway, by a belt of exactly this shape in sv_getup.lua. A
	-- swing has no bullet to catch and the capabilities taken there do not touch
	-- Z-City's melee base, which attacks from inside GetCapabilities whatever the
	-- NPC is allowed to do - so a metrocop that got up early clubbed whoever was
	-- kneeling over it. Asked before the switch, because the switch is about a body
	-- with somebody awake in it fighting back and this is not that: it is an
	-- animation, and nothing may swing out of the middle of one.
	if (ZCNPC.GettingUp and (ZCNPC.GettingUp[npc] or 0) or 0) > CurTime() then return true end

	if not (isfunction(ZCNPC.IsHidden) and ZCNPC.IsHidden(npc)) then return false end
	if not cfg.downed_fight:GetBool() then return true end

	return not (isfunction(ZCNPC.IsDownedTargetable) and ZCNPC.IsDownedTargetable(npc.zcnpc_rag))
end

ZCNPC.IsSilenced = Silenced
--//

--\\ Not being asked to fight either
-- weapon_melee.lua:1796: a swing is a named timer on the weapon and the damage is
-- in the timer rather than in the animation, so one that was already running lands
-- on whoever is standing there a third of a second after the body does.
local function StopSwing(npc)
	if not IsValid(npc) then return end

	local wep = npc:GetActiveWeapon()
	if not IsValid(wep) then return end

	local id = wep:EntIndex() .. "_NPCAttack"
	if timer.Exists(id) then timer.Remove(id) end
end

-- sv_getup.lua asks for this at the other end of a knockdown: the wake-up hands the
-- weapon back, and a swing started before the body went down is a timer that
-- outlives everything else about it.
ZCNPC.StopNpcSwing = StopSwing

local function Quiet(npc)
	Mute(npc)

	-- Every pass rather than only on the way down. A swing is half a second long and
	-- a pass is a quarter of one, so the timer that was running when the body landed
	-- is still running on the pass after it.
	StopSwing(npc)

	-- Cleared rather than remembered: everything above reads GetEnemy, and an NPC
	-- that gets back up should find out who it is fighting by looking.
	if IsValid(npc:GetEnemy()) then npc:SetEnemy(NULL) end
	if isfunction(npc.ClearEnemyMemory) then npc:ClearEnemyMemory() end

	-- The belt for the weapons whose capabilities are not ours to change: a schedule
	-- that has already been chosen goes on being run, and this is what replaces it.
	-- Nothing of ours is interrupted by it - a husk has nothing to do while its body
	-- is on the floor - and it costs nothing on an entity nobody can see.
	npc:StopMoving()
	npc:SetSchedule(SCHED_IDLE_STAND)
end
--//

--\\ The weapons that answer for themselves
-- Z-City's two weapon families are the ones an NPC is given in this game: the guns
-- are homigrad_base and the stunstick a metrocop spawns with is weapon_melee.
local FAMILIES = { "homigrad_base", "weapon_melee" }

local function InFamily(class)
	for _, base in ipairs(FAMILIES) do
		if class == base or weapons.IsBasedOn(class, base) then return true end
	end

	return false
end

-- Nothing at all while the owner is on the floor, and the original never runs -
-- which is the point for the melee base, where the attack is inside the function
-- being skipped. Everybody still standing gets the answer they always got.
local function Patch(tbl, inherited)
	if not istable(tbl) or tbl.zcnpc_downfight then return end
	if not isfunction(inherited) then return end

	tbl.zcnpc_downfight = true
	tbl.GetCapabilities = function(wep, ...)
		local owner = wep.GetOwner and wep:GetOwner()

		if IsValid(owner) and Silenced(owner) then return 0 end

		return inherited(wep, ...)
	end
end

local function SilenceWeapons()
	if not (istable(weapons) and isfunction(weapons.GetStored)) then return end

	-- The bases, where the function is written. Children are merged out of them
	-- every time one is created (weapons.Get), so everything that spawns from here
	-- on comes out of the same patch.
	for _, base in ipairs(FAMILIES) do
		local stored = weapons.GetStored(base)
		if istable(stored) then Patch(stored, rawget(stored, "GetCapabilities")) end
	end

	-- A child that writes its own answer keeps its own answer, so it is patched
	-- where it says it.
	for _, wep in ipairs(weapons.GetList()) do
		local class = wep.ClassName
		if not (isstring(class) and InFamily(class)) then continue end

		local stored = weapons.GetStored(class)
		if istable(stored) and rawget(stored, "GetCapabilities") then
			Patch(stored, rawget(stored, "GetCapabilities"))
		end
	end

	-- And the ones already in somebody's hands. A weapon copies the class table into
	-- its own when it is created, so a stunstick that existed before this ran is
	-- still holding the old answer - the same reason sv_disarmed.lua ends this way.
	for _, wep in ipairs(ents.GetAll()) do
		if wep:IsWeapon() and InFamily(wep:GetClass()) then
			Patch(wep:GetTable(), wep.GetCapabilities)
		end
	end
end

SilenceWeapons()
hook.Add("InitPostEntity", "zcnpc_downfight", SilenceWeapons)

-- A Lua refresh registers the weapon over again, and the fresh table has never been
-- patched however many times this file has run.
hook.Add("OnReloaded", "zcnpc_downfight", SilenceWeapons)
--//

--\\ Rounds that got out anyway
-- Half-Life 2's own rifles never stopped saying they could shoot, and a burst that
-- had already started can put one more round out after everything above. Same
-- answer, and for the same reason, as the one sv_getup.lua gives for the length of
-- a stand up (sv_getup.lua:266).
hook.Add("EntityFireBullets", "zcnpc_downfight", function(ent, data)
	local npc = ent
	if IsValid(ent) and ent:IsWeapon() then npc = ent:GetOwner() end
	if not (IsValid(npc) and Silenced(npc)) then return end

	data.Num = 0

	return true
end)
--//

--\\ Swings that got out anyway
-- The same belt for the other kind of attack, and melee needs one more than a rifle
-- does. A round is a bullet in flight and there is a hook to catch it in; a swing is
-- a timer with the damage written inside it (weapon_melee.lua:1814), created up to
-- half a second before it lands, and by then the weapon has stopped being asked
-- anything. Everything above is about a swing not starting - this is the one that
-- already did, whatever door it came through.
--
-- Narrow on purpose. Only what came out of this NPC's own hands: its weapon, or the
-- NPC itself for a punch or a kick. A grenade it threw while it was still standing
-- is not the body on the floor attacking anybody, and neither is its own bleeding.
hook.Add("EntityTakeDamage", "zcnpc_downfight", function(ent, dmgInfo)
	local npc = dmgInfo:GetAttacker()
	if not (IsValid(npc) and npc:IsNPC()) then return end
	if ent == npc then return end
	if not Silenced(npc) then return end

	local inflictor = dmgInfo:GetInflictor()
	if not (inflictor == npc or (IsValid(inflictor) and inflictor:IsWeapon())) then return end

	dmgInfo:SetDamage(0)
	dmgInfo:SetDamageForce(vector_origin)

	return true
end)
--//

hook.Add("ZCNPC_Downed", "zcnpc_downfight", function(npc)
	if not (IsValid(npc) and Silenced(npc)) then return end

	Quiet(npc)
end)

-- Before sv_getup.lua takes the range capabilities away again for the length of the
-- animation: what it hands back at the end of one is whatever it found here.
hook.Add("ZCNPC_WokeUp", "zcnpc_downfight", function(npc)
	Unmute(npc)
end)

timer.Create("zcnpc_downfight", 0.25, 0, function()
	for _, info in pairs(ZCNPC.Downed) do
		local npc = info.npc
		if not IsValid(npc) then continue end

		if Silenced(npc) then
			Quiet(npc)
		elseif muted[npc] then
			-- Came round on the floor with the switch on. Its capabilities were taken
			-- from it while it was out and this is the pass that notices.
			Unmute(npc)
		end
	end

	-- Every way back onto its feet rather than only waking up: a body cleaned up by
	-- an admin puts its NPC back on its feet through a door of its own
	-- (sv_uncon.lua:971), and an NPC that came out of that still unable to fight is
	-- an NPC that stands there and takes it.
	for npc in pairs(muted) do
		if not IsValid(npc) then
			muted[npc] = nil
		elseif not IsValid(npc.zcnpc_rag) then
			Unmute(npc)
		end
	end
end)
