--[[
	Bodies and NPCs touching each other.

	Z-City lays every body it makes down in COLLISION_GROUP_WEAPON
	(fake/sv_tier_0.lua:106), which is the right group for the problem it was
	solving - a body in a doorway should not be a wall - and it takes NPCs with it.
	The engine's own rules exclude that group from touching anything in
	COLLISION_GROUP_NPC, so a body does not merely fail to knock an NPC over, it
	passes straight through it: throw yourself off a roof onto a combine soldier
	and you land on the floor underneath him.

	Two things are wanted out of that and they are separate. The collision itself,
	which is a body being a body; and what a collision at speed means, which is
	that whoever was standing there is not standing there any more.
]]

local cfg = ZCNPC.Config

-- ShouldCollide is asked of every pair a marked body is in. A GetBool per
-- pair is a hash into the convar table on every shove, every footstep into
-- a corpse, every drag. The switch itself does not change between two of
-- those in the same second.
local collideOn = true

local function RefreshCollide()
	collideOn = cfg.collide ~= nil and cfg.collide:GetBool() or false
end

pcall(cvars.AddChangeCallback, "zcnpc_ragdoll_collide", RefreshCollide, "zcnpc_collide_cache")
RefreshCollide()

--\\ Letting them touch at all
-- The group rules are the engine's and there is no changing them from Lua, but
-- there is a documented way past: an entity with a custom collision check is asked
-- about every pair it is in before the groups get to decide. So the bodies are
-- marked and the question is answered here.
--
-- Marking the body rather than the NPC is deliberate. There are a handful of
-- bodies at a time and there can be a great many NPCs, and an entity that answers
-- this question is answering it for every pair it is ever in.
function ZCNPC.EnableBodyCollision(rag)
	if not IsValid(rag) then return end

	rag.zcnpc_collide = true
	rag:SetCustomCollisionCheck(true)
end

hook.Add("ShouldCollide", "zcnpc_bodies", function(a, b)
	if not collideOn then return end

	local body, npc
	if a.zcnpc_collide and b:IsNPC() then
		body, npc = a, b
	elseif b.zcnpc_collide and a:IsNPC() then
		body, npc = b, a
	else
		return
	end

	-- A downed NPC stays in the world as a hidden, frozen entity under its body
	-- (sv_uncon.lua). Forcing body↔NPC contact for those too meant a hard landing
	-- crushed the invisible half as well as the body - organism death on the body,
	-- engine death ragdoll from the NPC, two corpses, one of them still NoDraw'd.
	-- Its own body must never touch it either: the pelvis FollowBody parks on is
	-- the same point the ragdoll settles on.
	if IsValid(npc.zcnpc_rag) or body.zcnpc_npc == npc then return false end

	-- And not the one dragging it (sv_rescue.lua). A body being pulled along at
	-- somebody's heels is in contact with him for the whole length of the drag, and
	-- every one of those contacts is a shove: the two of them end up wrestling, the
	-- rescuer is pushed off the path it is walking, and the drag goes nowhere.
	local rescue = npc.zcnpc_rescue
	if istable(rescue) and rescue.rag == body then return false end

	return true
end)

-- Our own bodies, the moment they are laid down.
hook.Add("ZCNPC_Downed", "zcnpc_collide", function(_, rag)
	ZCNPC.EnableBodyCollision(rag)
end)

-- And Z-City's, which is where a player's own body comes from. It keeps a register
-- of every one it has made (hg.queue_ragdolls, written in hg.Ragdoll_Create), so
-- there is no need to guess from the model or the collision group: a ragdoll that
-- is in that table is one of Z-City's and nothing else is.
--
-- A frame late, because the entry is written after the entity is created.
hook.Add("OnEntityCreated", "zcnpc_collide", function(ent)
	if ent:GetClass() ~= "prop_ragdoll" then return end

	timer.Simple(0, function()
		if not IsValid(ent) then return end
		if not (istable(hg.queue_ragdolls) and hg.queue_ragdolls[ent]) then return end

		ZCNPC.EnableBodyCollision(ent)
	end)
end)
--//

--\\ Coming down on somebody
-- Z-City runs a "Ragdoll Collide" hook off every body it makes and hands over the
-- collision data with it (fake/sv_tier_0.lua:165), which is everything needed: what
-- was hit, and how fast the two were closing. Its own listeners use it for impact
-- sounds and for hurting the body itself - nothing in it has ever looked at what the
-- body landed on.
--
-- The speed is the whole judgement. A body sliding down against somebody's shins is
-- not a tackle; a body that has just fallen two storeys is. Landing speed from a
-- jump is a couple of hundred units a second, from a real fall several hundred, and
-- a body being dragged along the ground is under fifty.
local KNOCK_COOLDOWN = 1

-- Not the raw closing speed. A leg swinging into somebody at speed while the body
-- it belongs to is stationary is not the same event as the whole body arriving, and
-- data.Speed cannot tell them apart on its own.
local function Arriving(rag, data)
	local speed = data.Speed or 0
	if speed <= 0 then return 0 end

	local vel = data.OurOldVelocity
	if not isvector(vel) then return speed end

	return math.min(speed, vel:Length())
end

hook.Add("Ragdoll Collide", "zcnpc_stomp", function(rag, data)
	if not (ZCNPC.Enabled() and cfg.stomp:GetBool()) then return end
	if not IsValid(rag) then return end

	local npc = data.HitEntity
	if not (IsValid(npc) and npc:IsNPC()) then return end
	if npc == rag.zcnpc_npc then return end -- its own hidden half

	local org = npc.organism
	if not org or org.alive == false then return end
	if IsValid(npc.zcnpc_rag) then return end -- already on the floor

	if (npc.zcnpc_stomped or 0) > CurTime() then return end

	if Arriving(rag, data) < cfg.stomp_speed:GetFloat() then return end

	npc.zcnpc_stomped = CurTime() + KNOCK_COOLDOWN

	ZCNPC.Debug("landed on", npc)

	-- Carried over from whatever hit it, so the two of them end up in a heap
	-- rather than the NPC dropping neatly on the spot. Halved, because a body is
	-- not a truck, and flattened, because being landed on knocks you down and not
	-- up.
	local shove = data.OurOldVelocity
	if isvector(shove) then
		shove = Vector(shove.x, shove.y, 0) * 0.5
	else
		shove = nil
	end

	local downtime = cfg.stomp_downtime:GetFloat()

	-- deferred: this arrives from inside the physics callback, and building a
	-- ragdoll is not something to do while the engine is walking its contact list
	timer.Simple(0, function()
		if IsValid(npc) then ZCNPC.Floor(npc, downtime, shove) end
	end)
end)
--//
