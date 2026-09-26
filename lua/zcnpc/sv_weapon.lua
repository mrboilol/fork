--[[
	The gun in a downed NPC's hands.

	Nothing has to be drawn for this. A Z-City weapon is rendered from
	SWEP:DrawWorldModel -> SWEP:WorldModel_Transform, which puts the world model on
	the right hand of `owner.FakeRagdoll` when the owner has one and on the owner
	itself when it does not (homigrad_base/sh_worldmodel.lua:566). cl_body.lua
	already points the hidden NPC's FakeRagdoll at the body it is lying as, so the
	gun follows the body's hand on its own.

	What is left is the decision: an NPC that was merely knocked off its feet holds
	on to its weapon, one that is out cold or dead lets go of it.
]]

local cfg = ZCNPC.Config

--\\ Loose guns
-- Z-City marks weapons lying around like this so they are picked up with USE
-- instead of by walking over them (homigrad_base/sv_drop.lua:30,
-- sh_weaponsinv.lua:113). Must run after Spawn: homigrad_base Initialize sets
-- init = false, so marking before Spawn was a no-op and walk-over pickup came back.
local function Loose(ent)
	if not IsValid(ent) then return end

	ent.init = true
	ent.IsSpawned = true
	ent.zcnpc_loose = true
end

-- HL2 NPC guns (weapon_ar2, ...) are not homigrad_base, so the stock inventory
-- hook never sees them as loose. Same USE rule for anything we marked.
hook.Add("PlayerCanPickupWeapon", "zcnpc_loose", function(ply, wep)
	if not (IsValid(wep) and wep.zcnpc_loose) then return end
	if ply.force_pickup then return end
	if ply:GetUseEntity() ~= wep or not ply:KeyPressed(IN_USE) then return false end
end)

--\\ The gun behind the item
-- An NPC using something out of its own kit has the item in its hands and its rifle
-- behind it: the item is given and selected on top of the gun, and the gun sits in the
-- inventory until the item goes away again (sv_medical.lua, sv_cms.lua, sv_rescue.lua).
-- So for the length of one bandage GetActiveWeapon answers with a bandage, and every
-- question in this file is about the gun.
--
-- Dropping the wrong one is not a cosmetic mistake. What gets dropped is what an NPC is
-- then sent back across the room to pick up again (zcnpc_lostwep below), so it would
-- fight its way to a used wrap while the rifle it never let go of sat in an inventory
-- nothing is ever going to look in again.
local ITEM_STATES = { "zcnpc_meduse", "zcnpc_cms", "zcnpc_rescue" }

local function HeldItem(npc)
	for i = 1, #ITEM_STATES do
		local state = npc[ITEM_STATES[i]]

		if istable(state) and IsValid(state.wep) then return state.wep, state.hadclass end
	end
end

-- The gun it is carrying, whatever is in the hand at the moment. Nothing when the hands
-- were empty before the item came out: an NPC that never had a rifle has none to drop,
-- none to hide and none to take away.
function ZCNPC.HeldGun(npc)
	if not IsValid(npc) then return end

	local active = npc:GetActiveWeapon()

	local item, back = HeldItem(npc)
	if not (IsValid(item) and active == item) then return active end
	if not back then return end

	for _, held in ipairs(npc:GetWeapons() or {}) do
		if IsValid(held) and held:GetClass() == back then return held end
	end
end

ZCNPC.HeldItem = HeldItem
--//

-- One weapon out of somebody's hands and onto the floor, and nothing else: no clock, no
-- announcement, no memory of having lost anything. Split out because there are two
-- reasons a gun ends up in the street and only one of them is losing it - an NPC that
-- has just traded a pistol for the rifle at its feet (sv_disarmed.lua) puts the pistol
-- down having lost nothing, and telling the rest of the addon it was disarmed sends it
-- straight back for the gun it deliberately let go of.
--
-- An NPC cannot be told to let go of a weapon the way a player can (Player:DropWeapon
-- has no NPC counterpart), so the held one is replaced by a fresh copy carrying its
-- state over. SetInfo is Z-City's own clip + attachments transfer
-- (homigrad_base/shared.lua:802), so a half empty magazine stays half empty and
-- whatever was bolted to the rail stays bolted to it.
function ZCNPC.PlaceWeapon(wep, pos, ang, vel)
	if not IsValid(wep) then return end

	local class = wep:GetClass()
	local state = wep.GetInfo and wep:GetInfo() or nil

	wep:Remove()

	local drop = ents.Create(class)
	if not IsValid(drop) then return end

	drop:SetPos(pos or vector_origin)
	drop:SetAngles(ang or AngleRand())

	drop:Spawn()

	if state and drop.SetInfo then drop:SetInfo(state) end

	-- After Spawn/Initialize (and a tick later in case OwnerChanged / delayed
	-- init code rewrites the flags), so walk-over never wins.
	Loose(drop)
	timer.Simple(0, function() Loose(drop) end)

	drop:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	local phys = drop:GetPhysicsObject()
	if IsValid(phys) and vel then phys:SetVelocity(vel) end

	return drop
end

-- Takes the weapon off the NPC and leaves it in the world at pos/ang.
-- Returns the new entity, or nil when there was nothing to drop.
function ZCNPC.DropWeapon(npc, pos, ang, vel)
	if not IsValid(npc) then return end

	-- One drop per gun. Headshot kills used to race UpdateWeaponHold and KillDowned
	-- into this twice in the same tick; the second call still saw a weapon if the
	-- first Remove had not settled, and spawned a twin.
	if (npc.zcnpc_droplock or 0) > CurTime() then return npc.zcnpc_lostwep end

	local wep = ZCNPC.HeldGun(npc)
	if not IsValid(wep) then return end

	-- The item goes away with it: the hand it was in is the hand that just lost the gun,
	-- and whatever it was in the middle of is over.
	if ZCNPC.CancelNpcItem then ZCNPC.CancelNpcItem(npc, "lost the gun") end

	local class = wep:GetClass()

	npc.zcnpc_droplock = CurTime() + 0.2

	local drop = ZCNPC.PlaceWeapon(wep, pos or npc:GetPos() + npc:OBBCenter(), ang, vel)
	if not IsValid(drop) then return end

	-- Remembered so it can be gone back for. Every way an NPC can lose a gun comes
	-- through here, so this is also the one place that can say it just happened -
	-- and a whole second of walking at somebody bare handed is a second too long to
	-- wait for the next pass of the timer.
	npc.zcnpc_lostwep = drop
	hook.Run("ZCNPC_Disarmed", npc, drop)

	ZCNPC.Debug("dropped", class, "from", npc)

	return drop
end

-- Where a gun leaving a body's right hand ends up.
local function HandDrop(rag)
	if not IsValid(rag) then return end

	local bone = rag:LookupBone("ValveBiped.Bip01_R_Hand")
	if not bone then return rag:GetPos() + vector_up * 6, AngleRand() end

	local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(bone))
	if not IsValid(phys) then return rag:GetPos() + vector_up * 6, AngleRand() end

	return phys:GetPos() + vector_up * 2, phys:GetAngles(), phys:GetVelocity()
end

ZCNPC.HandDrop = HandDrop
--//

--\\ Holding on
-- Only a body that could get up by itself keeps its grip. The arm checks match the
-- ones Z-City uses to make a player let go: an amputated or wrecked right arm drops
-- whatever it was holding (organism/tier_1/sv_input.lua "rarmdown").
function ZCNPC.HoldsWeapon(npc, rag)
	if not (IsValid(npc) and IsValid(rag)) then return false end
	if not IsValid(ZCNPC.HeldGun(npc)) then return false end

	local org = rag.organism or npc.organism
	if not org then return false end

	if org.alive == false then return false end
	if org.otrub or org.fake then return false end
	if (org.consciousness or 1) <= 0.4 then return false end
	if org.rarmamputated then return false end
	if (org.rarm or 0) >= 1 then return false end
	if npc:GetNetVar("handcuffed", false) then return false end

	return true
end

-- Called for every downed body, and once more the moment it goes down.
function ZCNPC.UpdateWeaponHold(npc, rag, info)
	if not IsValid(npc) then return end

	local wep = ZCNPC.HeldGun(npc)
	if not IsValid(wep) then return end

	local holds = ZCNPC.HoldsWeapon(npc, rag)
	if info.holding ~= nil and holds == info.holding then return end

	info.holding = holds

	-- Hiding the weapon is what stops it being drawn at all: the visible gun is the
	-- world model DrawWorldModel puts in the hand, and the engine only asks a SWEP
	-- to draw that while the weapon itself is not hidden.
	wep:SetNoDraw(not holds)

	if holds then return end

	local drop = ZCNPC.DropWeapon(npc, HandDrop(rag))
	if not IsValid(drop) then return end

	-- gone from the hands for good, so it must not also be findable inside the body
	ZCNPC.TakeLoot(rag, info, drop:GetClass())
end

-- Runs after the loot hook, so info.wepclass is already filled in
hook.Add("ZCNPC_Downed", "zcnpc_weapon", function(npc, rag)
	local info = ZCNPC.Downed[rag]
	if not info then return end

	-- MakeUnconscious hid the weapon along with the NPC; this hands it back to the
	-- hand when the body is in a state to hold it, and lets go of it for real when
	-- it is not.
	ZCNPC.UpdateWeaponHold(npc, rag, info)
end)
--//

--\\ Arms it no longer has
-- Z-City takes the gun off a player when the arm holding it goes and never had an
-- opinion about NPCs, so an NPC with both arms shot off would walk over to a dropped
-- rifle, pick it up and shoot back with it - the gun hanging in the air where the
-- hand used to be, since the bone it is drawn from is scaled away with the rest of
-- the limb.
--
-- Same rule as the player and the same one HoldsWeapon uses on a body: the right arm
-- is the one that holds a weapon in this game, amputated or broken through counts as
-- gone. A missing left arm is left alone - Z-City lets a one-armed player keep
-- shooting, and there is nothing to look wrong about it.
local TWO_HAND = {
	rifle = true,
	shotgun = true,
	sniper = true,
	smg = true,
	launcher = true,
}

function ZCNPC.NeedsTwoHands(class)
	local role = ZCNPC.WeaponRole and ZCNPC.WeaponRole(class)

	return role ~= nil and TWO_HAND[role] == true
end

function ZCNPC.LeftArmGone(org)
	if not org then return false end

	return org.larmamputated == true or (org.larm or 0) >= 1
end

function ZCNPC.CanUseWeapon(npc)
	if not cfg.armless:GetBool() then return true end

	local org = ZCNPC.ResolveOrganism(npc)
	if not org then return true end

	return not (org.rarmamputated or (org.rarm or 0) >= 1)
end

-- Right arm holds it; left arm is the off hand a rifle needs. A one-armed
-- soldier can still fire a pistol. Asked by the floor fetch so it does not
-- hand the rifle back the moment UpdateArms puts it down.
function ZCNPC.CanHoldClass(npc, class)
	if not cfg.armless:GetBool() then return true end
	if not ZCNPC.CanUseWeapon(npc) then return false end
	if not ZCNPC.NeedsTwoHands(class) then return true end

	local org = ZCNPC.ResolveOrganism(npc)

	return not ZCNPC.LeftArmGone(org)
end

function ZCNPC.CanReloadWeapon(npc)
	if not cfg.armless:GetBool() then return true end

	local org = ZCNPC.ResolveOrganism(npc)
	if not org then return true end
	if not ZCNPC.CanUseWeapon(npc) then return false end

	return not ZCNPC.LeftArmGone(org)
end

-- Covers the arm coming off while the gun is already in it, and every way a weapon
-- can arrive that the AI was never asked about (a spawner, another addon).
--
-- Only the gun in the hand is dealt with here. Whether the NPC may hold one at all
-- is a capability, and there is exactly one owner of that (sv_disarmed.lua), which
-- takes it away from anything standing there with empty hands - an arm it no longer
-- has among the reasons for them being empty.
local function IsPistol(class)
	return ZCNPC.WeaponRole and ZCNPC.WeaponRole(class) == "pistol"
end

local function KitPistol(npc)
	local kit = ZCNPC.EnsureLootKit and ZCNPC.EnsureLootKit(npc)
	if not istable(kit) then return end

	for i = 1, #kit do
		local class = kit[i]
		if IsPistol(class) and not (npc.zcnpc_lootspent and npc.zcnpc_lootspent[class]) then
			return class
		end
	end
end

local function GroupPistol(npc)
	if not (ZCNPC.WeaponGroupOf and ZCNPC.WeaponListForNpc) then return end

	local list = ZCNPC.WeaponListForNpc(ZCNPC.WeaponGroupOf(npc))
	if not istable(list) then return end

	for i = 1, #list do
		if IsPistol(list[i]) then return list[i] end
	end
end

-- Already in the inventory, then the loot kit, then the group's box, then the
-- HL2 pistol. The kit is mostly bandages, so without a fallback the rifle hit
-- the floor and the fetch handed it straight back.
--
-- Second return is the weapon already in the hand, when there is one. HasWeapon
-- is a player method and is nil on an NPC, which is exactly when this runs:
-- left arm gone, rifle dropped, pistol next.
local function PistolClass(npc)
	for _, wep in ipairs(npc:GetWeapons() or {}) do
		if IsValid(wep) and IsPistol(wep:GetClass()) then return wep:GetClass(), wep end
	end

	local active = npc:GetActiveWeapon()
	if IsValid(active) and IsPistol(active:GetClass()) then
		return active:GetClass(), active
	end

	return KitPistol(npc) or GroupPistol(npc) or "weapon_pistol"
end

local function DrawPistol(npc)
	if not IsValid(npc) then return end

	local class, held = PistolClass(npc)
	if not class then return end

	if not IsValid(held) then
		held = npc:Give(class)
		if not IsValid(held) then return end

		ZCNPC.Debug("one-armed draw", npc, class)
	end

	if isfunction(npc.SelectWeapon) then npc:SelectWeapon(class) end
end

function ZCNPC.UpdateArms(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return end
	if not cfg.armless:GetBool() then return end
	if IsValid(npc.zcnpc_rag) then return end -- a body on the ground has its own rule

	local org = ZCNPC.ResolveOrganism(npc)
	if not org then return end

	if not ZCNPC.CanUseWeapon(npc) then
		if not IsValid(ZCNPC.HeldGun(npc)) then return end

		local bone = npc:LookupBone("ValveBiped.Bip01_R_Hand")
		local pos = bone and npc:GetBonePosition(bone)

		ZCNPC.DropWeapon(npc, pos, AngleRand())

		return
	end

	-- Left arm gone: a rifle needs two hands. The pistol in the kit does not.
	if not ZCNPC.LeftArmGone(org) then return end

	local gun = ZCNPC.HeldGun(npc)
	if not IsValid(gun) then
		DrawPistol(npc)

		return
	end

	if not ZCNPC.NeedsTwoHands(gun:GetClass()) then return end

	local bone = npc:LookupBone("ValveBiped.Bip01_R_Hand")
	local pos = bone and npc:GetBonePosition(bone)

	-- DropWeapon announces ZCNPC_Disarmed, and that fetch prefers the gun it
	-- just lost. The rifle is at its feet, so it was back in the hand before
	-- DrawPistol ran. Hold the fetch, forget that rifle, then draw a pistol.
	npc.zcnpc_swapping = true
	ZCNPC.DropWeapon(npc, pos, AngleRand())
	npc.zcnpc_lostwep = nil
	DrawPistol(npc)
	npc.zcnpc_swapping = nil
end

-- A magazine change is two hands. The engine reload schedule is cancelled and
-- the clip is left empty rather than magically filling itself.
hook.Add("Think", "zcnpc_noreload", function()
	if not ZCNPC.Enabled() then return end
	if not cfg.armless:GetBool() then return end

	local now = CurTime()
	if (ZCNPC._noreload_at or 0) > now then return end
	ZCNPC._noreload_at = now + 0.25

	if not (istable(hg) and istable(hg.organism) and istable(hg.organism.list)) then return end

	for npc in pairs(hg.organism.list) do
		if not (IsValid(npc) and npc:IsNPC()) then continue end
		if IsValid(npc.zcnpc_rag) then continue end
		if ZCNPC.CanReloadWeapon(npc) then continue end

		local wep = ZCNPC.HeldGun(npc)
		if not IsValid(wep) then continue end

		if npc:IsCurrentSchedule(SCHED_RELOAD) or npc:IsCurrentSchedule(SCHED_HIDE_AND_RELOAD) then
			npc:ClearSchedule()
		end

		if wep.Clip1 and wep:Clip1() <= 0 then
			npc:SetSchedule(SCHED_TAKE_COVER_FROM_ENEMY)
		end
	end
end)

-- The arm can come off in the same frame the NPC is holding a gun, and half a second
-- of a rifle floating next to a stump is exactly the thing being fixed.
hook.Add("OnAmputateLimb", "zcnpc_armless", function(org, ent, limb)
	if not ZCNPC.Enabled() then return end
	if limb ~= "rarm" and limb ~= "larm" then return end

	ZCNPC.UpdateArms(IsValid(org.owner) and org.owner or ent)
end)
--//
