--[[
	Getting up, server half.

	The body has to survive long enough for the client to animate out of the pose
	it is lying in, and it has to stop moving while it does - a body that is still
	settling drags the whole animation along with it. The NPC itself is held in
	place too, because the HL2 AI would otherwise walk off mid-animation.

	The one decision that cannot be left to the client is which way the NPC ends
	up facing. The motion capture in sh_getup_anim.lua rolls the body over on its
	way up, so where it finishes looking is fixed by the animation and by which
	way the body happens to be lying - not something to pick freely. So this
	picks the animation, works out the resulting angle, and turns the NPC to it.
	The client then reads that same angle back off the NPC to know where to start.
]]

local cfg = ZCNPC.Config
local Anim = ZCNPC.GetUpAnim

util.AddNetworkString("zcnpc_getup")

ZCNPC.GettingUp = ZCNPC.GettingUp or {} -- [npc] = time it is back on its feet

--\\ Reading a pose off a body
-- Phys objects first. On a server ragdoll GetBoneMatrix / GetBonePosition often
-- answer with the standing bind pose at the entity origin (sv_sound.lua has the
-- same note). Preferring that made Upright() think every body was already on its
-- feet, so PlanGetUp returned nil and WakeUp snapped the NPC upright with no
-- animation. Every bone that matters here is driven by a physics object, and
-- those always know where they are.
local function BoneTransform(rag, name)
	local bone = rag:LookupBone(name)
	if not bone then return end

	local physBone = rag:TranslateBoneToPhysBone(bone)
	local phys = physBone and physBone >= 0 and rag:GetPhysicsObjectNum(physBone)
	if IsValid(phys) then return phys:GetPos(), phys:GetAngles() end

	local matrix = rag:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation(), matrix:GetAngles() end

	return rag:GetBonePosition(bone)
end

-- Which way the body is pointing, so the NPC stands up in line with it instead
-- of snapping back to whatever angle it collapsed with. nil when the body is
-- folded up tight enough that pelvis and head give no usable direction.
function ZCNPC.BodyYaw(rag)
	local pelvis = BoneTransform(rag, "ValveBiped.Bip01_Pelvis")
	local head = BoneTransform(rag, "ValveBiped.Bip01_Head1")
	if not (pelvis and head) then return end

	local dir = head - pelvis
	dir.z = 0
	if dir:LengthSqr() < 4 then return end

	return dir:Angle().y
end

-- ValveBiped spine bones carry their own Z out of the chest, so where that
-- points decides whether the body is on its back or its front.
local function FaceUp(rag)
	local _, ang = BoneTransform(rag, "ValveBiped.Bip01_Spine2")
	if not ang then _, ang = BoneTransform(rag, "ValveBiped.Bip01_Spine1") end
	if not ang then return false end

	return ang:Up().z > 0
end

-- A body is not always lying down when it is time to get up: an active ragdoll may
-- have pushed it back onto its feet, or it may be draped over a table. Playing a
-- motion capture that starts flat on the floor from there looks like the body
-- collapses first, so those cases skip the animation and just stand up.
--
-- Ground must be MASK_SOLID, not BRUSHONLY: bodies on prop floors / debris /
-- displacements that brush-only misses look "floating" and used to skip every
-- get up. Standing pelvis sits at ~40, a lying one at ~10.
local UPRIGHT_HEIGHT = 34

local function Upright(rag)
	local pelvis = BoneTransform(rag, "ValveBiped.Bip01_Pelvis")
	local head = BoneTransform(rag, "ValveBiped.Bip01_Head1")
	if not (pelvis and head) then return false end

	-- still folded / flat: head is not clearly above the hips
	if head.z - pelvis.z < UPRIGHT_HEIGHT * 0.7 then return false end

	local tr = util.TraceLine({
		start = pelvis,
		endpos = pelvis - vector_up * 200,
		mask = MASK_SOLID,
		filter = rag,
	})

	if not tr.Hit then return false end

	return (pelvis.z - tr.HitPos.z) > UPRIGHT_HEIGHT
end
--//

--\\ Picking the animation
-- nil means there is nothing to play and the caller should just stand the NPC up.
function ZCNPC.PlanGetUp(rag)
	if not (ZCNPC.Enabled() and cfg.getup:GetBool()) then
		ZCNPC.Debug("getup skipped: disabled")
		return
	end
	if not istable(Anim) then
		ZCNPC.Debug("getup skipped: no anim data")
		return
	end

	-- Direction is nice to have; a curled body still gets the motion capture
	-- rather than snapping upright because yaw could not be read.
	local lie = ZCNPC.BodyYaw(rag)
	if not lie and IsValid(rag) then lie = rag:GetAngles().y end
	if not lie then
		ZCNPC.Debug("getup skipped: no body yaw")
		return
	end

	if Upright(rag) then
		ZCNPC.Debug("getup skipped: body already upright")
		return
	end

	local faceUp = FaceUp(rag)
	local variant = faceUp and Anim.faceup or Anim.facedown
	if not (istable(variant) and variant.length) then
		ZCNPC.Debug("getup skipped: missing variant", faceUp and "faceup" or "facedown")
		return
	end

	-- zcnpc_getup_time 0 keeps the capture's own timing; anything else stretches
	-- or squeezes it to that many seconds.
	--
	-- Its own timing is not the same thing as the right timing, though. These are
	-- Left 4 Dead survivors getting off the floor with a horde on them, and they
	-- come back up in a second and a half - on an NPC that was lying there bleeding
	-- it reads as the clip being fast forwarded. zcnpc_getup_speed is the dial for
	-- that, and it defaults to slower than recorded.
	local override = cfg.getup_time:GetFloat()
	local speed = math.max(cfg.getup_speed:GetFloat(), 0.05)

	return {
		faceUp = faceUp,
		-- rotated so the body starts out lying the way it really is: the animation
		-- lies along `lieYaw` and finishes facing `endYaw`, and the difference
		-- between the two is how far the roll carries it round
		yaw = math.NormalizeAngle(lie + variant.endYaw - variant.lieYaw),
		length = override > 0 and override or (variant.length / speed),
	}
end
--//

--\\ Playing it
local function FreezeBody(rag)
	rag.zcnpc_gettingup = true
	rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then phys:EnableMotion(false) end
	end
end

-- HideWeapon only stops the model drawing. The AI still has CAP_USE_WEAPONS and
-- will happily fire mid-animation from the standing pose nobody can see yet.
--
-- The melee half is on the list for the same reason and was missing from it. A
-- stand-up is the one window where the body has already been handed back - WakeUp
-- clears zcnpc_rag and the Downed entry before it starts the animation
-- (sv_uncon.lua:762) - so every "is this one on the floor" test in the addon says
-- no for the length of it, including the one that silences a body's weapons
-- (sv_downedfight.lua). Rounds were still caught by the belt below; a swing has no
-- bullet to catch, so a metrocop stood back up early and clubbed whoever was
-- kneeling over it while the model everyone can see was still lying down.
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

local function MuteWeapons(npc)
	local now = npc:CapabilitiesGet()

	if npc.zcnpc_getup_caps == nil then
		local had = {}

		for i, cap in ipairs(NO_FIGHT) do
			had[i] = bit.band(now, cap) ~= 0
		end

		npc.zcnpc_getup_caps = had
	end

	for _, cap in ipairs(NO_FIGHT) do
		if bit.band(now, cap) ~= 0 then npc:CapabilitiesRemove(cap) end
	end
end

local function UnmuteWeapons(npc)
	if not IsValid(npc) then return end

	local had = npc.zcnpc_getup_caps
	npc.zcnpc_getup_caps = nil
	if not had then return end

	-- Disarmed NPCs keep CAP_USE_WEAPONS off on purpose (sv_disarmed.lua).
	if npc.zcnpc_canfight == false then return end

	for i, cap in ipairs(NO_FIGHT) do
		if had[i] then npc:CapabilitiesAdd(cap) end
	end
end

-- Returns true when it took the body over: the caller must not remove it itself.
function ZCNPC.StartGetUp(npc, rag, plan)
	if not (IsValid(npc) and IsValid(rag)) then return false end

	plan = plan or ZCNPC.PlanGetUp(rag)
	if not plan then return false end

	-- announced before the body is frozen, so anything else driving it (an active
	-- ragdoll, for one) can let go first
	hook.Run("ZCNPC_GetUp", npc, rag, plan)

	FreezeBody(rag)

	-- The gun goes away for the length of the animation, and this is the levitating
	-- one. A Z-City world model is drawn on the hand of the owner's FakeRagdoll if
	-- it has one and on the owner itself otherwise (homigrad_base/sh_worldmodel.lua:566),
	-- and getting up is exactly the moment that link is cut: the body is no longer
	-- the NPC's stand-in, so the gun jumps to the NPC's own hand - which is up in
	-- the standing pose at the spot it is about to occupy, while the model everyone
	-- can see is still down on the floor playing the animation. The result is a
	-- rifle hanging in mid air waiting for its owner to arrive.
	--
	-- An NPC that was floored while still holding it keeps hold of it: it is only
	-- hidden, and ZCNPC.ShowWeapon below hands it back the moment it is standing.
	ZCNPC.HideWeapon(npc)
	MuteWeapons(npc)

	-- A swing that was already in flight when the body was floored is a named timer
	-- on the weapon with the damage inside it (weapon_melee.lua:1796), so it lands
	-- however quiet the AI has gone since. sv_downedfight.lua kills one on the way
	-- down; this is the other end, where the wake-up handed the weapon back.
	if ZCNPC.StopNpcSwing then ZCNPC.StopNpcSwing(npc) end

	ZCNPC.GettingUp[npc] = CurTime() + plan.length
	npc:StopMoving()
	npc:SetSchedule(SCHED_IDLE_STAND)

	net.Start("zcnpc_getup")
		net.WriteUInt(npc:EntIndex(), 16)
		net.WriteUInt(rag:EntIndex(), 16)
		net.WriteFloat(plan.length)
		net.WriteBool(plan.faceUp)
	net.Broadcast()

	ZCNPC.Debug("getting up", npc, plan.faceUp and "face up" or "face down", plan.length .. "s")

	timer.Simple(plan.length, function()
		if not IsValid(npc) then return end

		UnmuteWeapons(npc)
		ZCNPC.ShowWeapon(npc)
		-- Get-up is the other end of MOVETYPE_NONE. Restore again here in
		-- case a follow-body noclip hop or a second knockdown snapshot
		-- left the hull off after WakeUp.
		if ZCNPC.RestoreStanding then ZCNPC.RestoreStanding(npc) end
	end)

	timer.Simple(plan.length + 0.1, function()
		if IsValid(rag) then rag:Remove() end
	end)

	return true
end

-- Belt and braces: a schedule that already started firing can still spit a round
-- out after the caps are gone. Kill those bullets for the length of the stand-up.
hook.Add("EntityFireBullets", "zcnpc_getup_noshoot", function(ent, data)
	local npc = ent
	if IsValid(ent) and ent:IsWeapon() then npc = ent:GetOwner() end
	if not IsValid(npc) then return end

	local till = ZCNPC.GettingUp[npc]
	if not till or till < CurTime() then return end

	data.Num = 0

	return true
end)

-- The AI would otherwise walk off mid-animation and drag the pose with it
timer.Create("zcnpc_getup", 0.1, 0, function()
	for npc, till in pairs(ZCNPC.GettingUp) do
		if not IsValid(npc) or till < CurTime() then
			if IsValid(npc) then UnmuteWeapons(npc) end
			ZCNPC.GettingUp[npc] = nil
			continue
		end

		npc:StopMoving()
		npc:SetSchedule(SCHED_IDLE_STAND)
		MuteWeapons(npc) -- in case something re-granted CAP_USE_WEAPONS this tick
	end
end)
--//
