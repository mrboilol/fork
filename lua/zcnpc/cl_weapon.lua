--[[
	The gun in the body's hand rather than in thin air.

	A weapon is drawn on whoever owns it, and while an NPC is down its owner is a
	hidden entity lying underneath the body. Z-City's own guns handle this: their
	world model transform asks for owner.FakeRagdoll first and falls back to the
	owner (homigrad_base/sh_worldmodel.lua:566), and cl_body.lua points that field
	at the body. Everything else does not.

	* Z-City's melee weapons - the stunstick a metrocop carries, the combat knife -
	  are built on weapon_melee, which is not built on homigrad_base. Its NPC branch
	  reads the right hand bone straight off the owner (weapon_melee.lua:184), which
	  is the invisible one. So the stunstick hangs in the air where the NPC was
	  standing when it went down.
	* stock Half-Life 2 weapons are drawn by the engine, parented to the owner's
	  hand attachment, and there is no Lua in the path at all.

	Two fixes, because they are two different problems. The first is a matter of
	pointing the bone lookups somewhere else; the second needs the weapon drawn
	again from scratch, because nothing about it is ours to redirect.

	And then the same thing again on an NPC that never went down at all. The arms
	of somebody kneeling over a body are solved at draw time rather than animated
	(cl_loot.lua), so the engine's idea of where the hand is does not move with
	them. Z-City's weapons find the pose by themselves because they read the bone
	from Lua; the engine's do not, and get the copy treatment.
]]

ZCNPC = ZCNPC or {}

local Pose = ZCNPC.Pose

local BONE_RH = "ValveBiped.Bip01_R_Hand"
local ATTACH_RH = "anim_attachment_RH"

--\\ Pointing a hidden NPC's bones at its body
-- Every one of these is "where is this part of this NPC", and while it is lying on
-- the floor the honest answer is a bone on the body. The hidden entity is frozen at
-- the spot it collapsed on and never drawn, so there is nothing that wants the old
-- answer.
--
-- An entity is userdata and its Lua fields live in the table behind GetTable(), so
-- an override goes there and reading it raw is what tells "somebody else replaced
-- this" apart from "this is the metatable's own method".
-- SetupBones is one of these because it belongs to the same question: a caller that
-- wants a bone matrix off an entity asks it to work its bones out first, and the
-- bones it needs worked out are the body's.
local proxied = { "LookupBone", "GetBoneMatrix", "GetBonePosition", "GetBoneCount", "GetBoneName", "SetupBones" }

local function Proxy(npc, rag)
	local fields = npc:GetTable()
	if not fields or rawget(fields, "zcnpc_boneproxy") then return end

	local saved = {}

	for _, name in ipairs(proxied) do
		saved[name] = rawget(fields, name)

		-- A bone matrix is whatever the bones were last set up as, and nothing says
		-- that happened this frame: the gun and the body it belongs on are two
		-- entries in the render list, in either order, and the body can be culled
		-- while the small thing in its hand is not. Z-City reads the matrix without
		-- asking (the line that would is commented out at
		-- homigrad_base/sh_worldmodel.lua:589), so a gun could be left in the hand
		-- of wherever the body was the last time anybody drew it. Asked for here
		-- instead, the same way medicine asks (cl_medicine.lua), and free when the
		-- answer is already worked out for this frame.
		local setup = name == "GetBoneMatrix"

		-- The body can go before the pairing does - it is removed a moment after
		-- the get up animation ends, and it can be cleaned up by an admin at any
		-- time - so there is always somewhere for the question to go.
		local base = npc[name]

		npc[name] = function(self, a, b)
			if IsValid(rag) then
				if setup then rag:SetupBones() end

				return rag[name](rag, a, b)
			end

			return base(self, a, b)
		end
	end

	fields.zcnpc_boneproxy = saved
end

local function Unproxy(npc)
	local fields = IsValid(npc) and npc:GetTable()
	local saved = fields and rawget(fields, "zcnpc_boneproxy")
	if not saved then return end

	for _, name in ipairs(proxied) do
		npc[name] = saved[name]
	end

	fields.zcnpc_boneproxy = nil
end
--//

--\\ Weapons the engine draws by itself
-- A scripted weapon has a Lua draw and the redirection above reaches inside it. A
-- stock Half-Life 2 rifle does not: the engine parents the world model to the
-- owner's hand attachment in C++, so the only way to move it is to hide the real
-- one and draw a copy where it belongs.
local copies = setmetatable({}, { __mode = "k" }) -- [weapon] = clientside model

local function Scripted(wep)
	return weapons.GetStored(wep:GetClass()) ~= nil
end

local function Copy(wep)
	local model = wep:GetModel()
	if not model or model == "" then return end

	local copy = copies[wep]

	if not IsValid(copy) then
		copy = ClientsideModel(model, RENDERGROUP_OPAQUE)
		if not IsValid(copy) then return end

		copy:SetNoDraw(true)
		copies[wep] = copy
	elseif copy:GetModel() ~= model then
		copy:SetModel(model)
	end

	return copy
end

-- Where the engine would have put it, asked of the body instead of the NPC. The
-- offset between the hand and the grip is baked into the world model itself, which
-- is why this is the attachment and not the bone: on the attachment the model lands
-- in the hand, on the bone it lands through it.
local function HandFrame(rag)
	local id = rag:LookupAttachment(ATTACH_RH)
	local att = id and id > 0 and rag:GetAttachment(id)

	if att then return att.Pos, att.Ang end

	local bone = rag:LookupBone(BONE_RH)
	local matrix = bone and rag:GetBoneMatrix(bone)
	if not matrix then return end

	return matrix:GetTranslation(), matrix:GetAngles()
end

local function DrawOnBody(wep, rag)
	local copy = Copy(wep)
	if not copy then return end

	local pos, ang = HandFrame(rag)
	if not pos then return end

	copy:SetRenderOrigin(pos)
	copy:SetRenderAngles(ang)
	copy:SetupBones()
	copy:DrawModel()
end

-- Only the ones that need it, and only while they need it. Drawn after the body
-- rather than as part of it, because a weapon is not part of a body: it has its own
-- model, its own materials and its own place in the render list.
hook.Add("PostDrawOpaqueRenderables", "zcnpc_weapon", function(_, skybox)
	if skybox then return end

	for npc, rag in pairs(ZCNPC.Bodies) do
		if not (IsValid(npc) and IsValid(rag)) then continue end
		if rag:IsDormant() then continue end

		local wep = npc.GetActiveWeapon and npc:GetActiveWeapon()
		if not IsValid(wep) or Scripted(wep) then continue end

		-- the server shows the weapon exactly while the body is still holding on
		-- to it (ZCNPC.UpdateWeaponHold), so its own visibility is the answer
		if wep:GetNoDraw() then continue end

		DrawOnBody(wep, rag)
	end
end)

-- and the real one stays out of sight, since what the engine draws is the thing in
-- the wrong place. Clientside, because the server's nodraw means something else on
-- this entity - it is how it says whether the body is still gripping the weapon.
local function HideReal(npc, hide)
	local wep = npc.GetActiveWeapon and npc:GetActiveWeapon()
	if not IsValid(wep) or Scripted(wep) then return end

	wep:SetPredictable(false)
	wep:DrawShadow(not hide)
	wep:SetRenderMode(hide and RENDERMODE_TRANSALPHA or RENDERMODE_NORMAL)
	wep:SetColor(hide and Color(255, 255, 255, 0) or Color(255, 255, 255, 255))
end
--//

--\\ A hand that has been moved out from under the gun
-- The other half of the same problem, on an NPC that is still standing. The crouch itself is
-- an animation the server plays now (sh_workpose.lua) and the engine's attachment follows it
-- like it follows any other, but what the hands are doing in that crouch is still solved at
-- draw time (cl_loot.lua) - and an engine weapon is parented to the hand attachment in C++,
-- worked out from the animation rather than from where the arm was put. So a medic with both
-- hands on somebody's chest has a rifle hanging where the crouch alone would have left it.
--
-- Nothing can be redirected here, for the same reason as on a body: there is no Lua in the
-- path. So the same answer - the real one is hidden and a copy is drawn where the hand
-- actually is. Z-City's own weapons are left alone: those read the hand bone themselves
-- from Lua (homigrad_base/sh_worldmodel.lua:595) and the pose is what they find there.
--
-- The grip is not the hand bone. Where a world model sits relative to the hand is baked into
-- the attachment, so what is needed is the step from one to the other - and then that step
-- taken again from the posed hand.
--
-- Measured off a hidden copy of the model rather than off the NPC (cl_pose.lua), which is the
-- whole point: on the NPC the hand is posed and the attachment is not, and the gap between
-- them is the bug. On the copy neither is posed, so the two agree, and what they agree on is
-- a property of the model - the attachment hangs off that bone at a fixed offset - so it is
-- true for every pose and worth measuring once.
local grips = {}

local function GripOffset(model)
	local known = grips[model]
	if known ~= nil then return known or nil end

	local ref = Pose and Pose.Reference and Pose.Reference(model)
	if not IsValid(ref) then return end

	ref:InvalidateBoneCache()
	ref:SetupBones()

	local id = ref:LookupAttachment(ATTACH_RH)
	local att = id and id > 0 and ref:GetAttachment(id)
	local bone = ref:LookupBone(BONE_RH)
	local hand = bone and ref:GetBoneMatrix(bone)

	if not (att and hand) then
		grips[model] = false

		return
	end

	local pos, ang = WorldToLocal(att.Pos, att.Ang, hand:GetTranslation(), hand:GetAngles())

	grips[model] = { pos = pos, ang = ang }

	return grips[model]
end

local posed = {} -- [npc] = true while a copy is being drawn in place of the real weapon

local function DrawInPosedHand(npc)
	local wep = npc.GetActiveWeapon and npc:GetActiveWeapon()
	if not IsValid(wep) or Scripted(wep) then return false end
	if wep:GetNoDraw() then return false end

	local hand = ZCNPC.PosedHand(npc)
	if not hand then return false end

	local grip = GripOffset(npc:GetModel())
	if not grip then return false end

	local copy = Copy(wep)
	if not copy then return false end

	local pos, ang = LocalToWorld(grip.pos, grip.ang, hand:GetTranslation(), hand:GetAngles())

	copy:SetRenderOrigin(pos)
	copy:SetRenderAngles(ang)
	copy:SetupBones()
	copy:DrawModel()

	return true
end

-- After the NPC, so the pose it was drawn in is still the one on its bones, and only over the
-- ones that were actually posed this frame. A body on the floor is the loop above; this is
-- the ones on their feet, and an NPC cannot be both.
hook.Add("PostDrawOpaqueRenderables", "zcnpc_weapon_posed", function(_, skybox)
	if skybox then return end

	for npc in pairs(ZCNPC.Posed) do
		if not IsValid(npc) then
			ZCNPC.Posed[npc] = nil
			posed[npc] = nil

			continue
		end

		local body = ZCNPC.Bodies and ZCNPC.Bodies[npc]
		local drew = not IsValid(body) and DrawInPosedHand(npc)

		-- Only on the way in and the way out. HideReal writes a render mode and a colour, and
		-- doing that every frame to every armed NPC on the map is work for nothing.
		if drew ~= (posed[npc] or false) then
			posed[npc] = drew or nil
			HideReal(npc, drew)
		end

		-- Standing up again, and its own weapon visible again: nothing left here to come back
		-- for until the next crouch puts it back on the list.
		if not drew and not posed[npc] then ZCNPC.Posed[npc] = nil end
	end
end)
--//

hook.Add("ZCNPC_ClientDowned", "zcnpc_weapon", function(npc, rag)
	Proxy(npc, rag)
	HideReal(npc, true)
end)

hook.Add("ZCNPC_ClientWokeUp", "zcnpc_weapon", function(npc)
	Unproxy(npc)
	HideReal(npc, false)
end)
