--[[
	Reacting to being shot, client half.

	An HL2 NPC has no flinch worth the name and Z-City adds none, so an NPC being
	shot in the chest looks exactly like an NPC standing still - which is most of
	why a body shot had to knock it over to read as a hit at all. This is the
	reaction instead: the torso folds over the wound, and whatever hands are free go
	to it and stay there while it hurts - both for a body wound when the gun is
	small (pistol), the free hand alone when it is a rifle, and the one that can
	reach for a wound in a limb.

	It is a pose, not an animation - the NPC goes on playing whatever the AI has it
	playing and the pose is laid over the top, the same way the handcuff pose in
	cl_render.lua is. Which means it survives the NPC walking, shooting and dying
	mid reaction rather than fighting any of them.

	Where the wound is comes over the wire as a real position - the hole Z-City's
	bullet trace left in the body (sv_damage.lua). It used to be guessed off the
	bone the organism blamed, a few units along that bone's own axes, and the guess
	was wrong in a way that was hard to look at: ValveBiped spine bones sit on the
	spine, which is at the back of the torso, so the hand for a bullet through the
	chest came to rest on the small of the back. Nothing here assumes which way is
	which any more; the only directions used are ones with an answer - the way the
	NPC is facing, and the line from the bone to the hole.
]]

ZCNPC = ZCNPC or {}

local Pose = ZCNPC.Pose
local BONE = ZCNPC.Bone

local hurt = {} -- [npc] = state

--\\ Tuning
-- Fraction of the reaction spent folding into it. The rest is spent coming back
-- out, so a wound is grabbed fast and let go of slowly.
local ONSET = 0.16

-- Degrees of tilt at the worst of it, split between hunching forward and curling
-- over the wound itself. They add up on a wound in the chest, cancel most of the
-- way out on one in the back, and lean the chest sideways on one in a flank.
local HUNCH = 10
local OVER = 7
local HEAD_DROP = 9

-- How far off the skin the hand ends up. The hole is already on the surface, so
-- this is the thickness of a hand and no more.
local CLUTCH_OUT = 2

-- Where the hand goes when nothing said where the round landed - a crowbar, a
-- blast, a body that fell over. Out of the front of whatever bone was blamed.
local FALLBACK_OUT = 6

-- How far apart the two hands sit when both of them go to the same wound, in units
-- either side of it. Both hands land on the wound rather than one of them holding
-- the other's wrist, so this is only the width of a hand: near enough to be one
-- pair of hands on one hole and far enough not to be two hands in the same place.
local HANDS_APART = 3.5

local ELBOW_OUT = 20
local ELBOW_DOWN = 16
--//

-- Which hand reaches which wound. Grabbing your own upper arm is the other hand's
-- job and a leg is its own side's; everything else is settled by which side of the
-- body the hole is actually on.
local reach = {
	[BONE.l_upperarm] = "r_",
	[BONE.r_upperarm] = "l_",
	[BONE.l_thigh] = "l_",
	[BONE.r_thigh] = "r_",
}

local function Envelope(t)
	if t < ONSET then
		local k = t / ONSET

		return k * k * (3 - 2 * k)
	end

	local k = (t - ONSET) / (1 - ONSET)

	return 1 - k * k
end

--\\ Finding the wound
-- The hole arrives in the NPC's own frame, which is exact and useless a moment
-- later: the NPC keeps walking and its torso keeps animating, and a point pinned to
-- the entity's origin follows neither. So the first time the body is drawn the point
-- is moved into the frame of the bone it belongs to, and read back out of that frame
-- every frame after - a patch of skin rather than a spot in the air.
--
-- Done before anything below bends that bone, because the server measured the hole
-- against the animation and not against the reaction to it.
local function Anchor(npc, state)
	if not state.sent then return true end

	local wound = Pose.Matrix(npc, state.bone)
	if not wound then return false end

	state.at = WorldToLocal(npc:LocalToWorld(state.sent), angle_zero,
		wound:GetTranslation(), wound:GetAngles())
	state.sent = nil

	return true
end

-- Where the hand is going, and which way "out of the body" is once it gets there.
-- Out is the line from the bone to the hole with the part that runs along the bone
-- taken out of it, so on a spine bone it points through the skin on whichever side
-- the round went in, and on a limb it points off the limb.
--
-- Asked twice per frame, before and after the chest folds: the wound rides round
-- with the chest, and a hand sent to where it used to be is a hand in the air.
local function Where(npc, state)
	local wound = Pose.Matrix(npc, state.bone)
	if not wound then return end

	local ang = wound:GetAngles()
	local origin = wound:GetTranslation()

	if not state.at then
		local ahead = npc:GetAngles():Forward()

		return origin + ahead * FALLBACK_OUT, ahead
	end

	local at = LocalToWorld(state.at, angle_zero, origin, ang)

	local axis = ang:Forward()
	local out = at - origin
	out = out - axis * out:Dot(axis)

	-- straight down the middle of the bone: nothing to push away from, so use the
	-- front of the body, which is where a hand would go looking anyway
	if out:LengthSqr() < 1 then return at, npc:GetAngles():Forward() end

	return at, out:GetNormalized()
end
--//

--\\ The pose
-- ValveBiped limb and spine bones run along their own +X towards the child bone, so
-- tilting the chest means aiming that axis somewhere else - and "somewhere else" is
-- a direction in the world, which is the one frame there is nothing to get backwards
-- about. Pose.Aim takes the shortest rotation onto it, which leaves whatever twist
-- the animation had.
--
-- hg.bone_apply_matrix carries the bone's children with it (cl_bones.lua:61), which
-- is what makes this a fold rather than a shear: the arms, the head and the gun in
-- the hand all ride the chest round.
local function Lean(npc, bone, dir, degrees)
	if degrees < 0.1 then return end

	local id = npc:LookupBone(bone)
	local matrix = id and npc:GetBoneMatrix(id)
	if not matrix then return end

	local ang = matrix:GetAngles()
	local tilted = ang:Forward() + dir * math.tan(math.rad(math.min(degrees, 60)))

	local folded = Matrix()
	folded:SetAngles(Pose.Aim(ang, tilted:GetNormalized()))
	folded:SetTranslation(matrix:GetTranslation())
	folded:SetScale(matrix:GetScale())

	hg.bone_apply_matrix(npc, id, folded)
end

-- An arm the organism has written off is scaled away to nothing by the gore pass
-- (cl_render.lua), so sending it to the wound moves a stump nobody can see and
-- leaves the hole uncovered.
local amputated = { r_ = "rarmamputated", l_ = "larmamputated" }

local function HandThere(npc, prefix)
	local org = npc.new_organism or npc.organism

	return not (org and org[amputated[prefix]])
end

-- Free enough to leave the gun alone: there, and not holding anything anyone can
-- see. NPCs carry their weapon in the right hand, so on an armed one that leaves
-- the left. Used for limb wounds - swinging a rifle up to your own shoulder looks
-- wrong.
local function HandFree(npc, prefix)
	if not HandThere(npc, prefix) then return false end
	if prefix ~= "r_" then return true end

	local wep = npc:GetActiveWeapon()

	return not (IsValid(wep) and not wep:GetNoDraw())
end

-- Small enough that both hands can leave the gun for a body wound (pistols,
-- revolvers, melee). A rifle / AR-2 / SMG keeps the right hand on the grip, so
-- only the free hand goes to the hole.
local SMALL_HOLD = {
	pistol = true,
	revolver = true,
	melee = true,
	melee2 = true,
	knife = true,
	grenade = true,
	slam = true,
	normal = true,
	fist = true,
}

local function SmallGun(wep)
	if not IsValid(wep) or wep:GetNoDraw() then return true end

	if wep.IsPistolHoldType then
		local ok, small = pcall(wep.IsPistolHoldType, wep)
		if ok then return small and true or false end
	end

	if wep.IsPistol then return true end
	-- Z-City inventory: 2 = sidearm, 1 = primary
	if wep.weaponInvCategory == 2 then return true end
	if wep.weaponInvCategory == 1 then return false end

	local ht = wep.HoldType or (wep.GetHoldType and wep:GetHoldType()) or ""

	return SMALL_HOLD[ht] or false
end

local function HoldingLarge(npc)
	local wep = npc:GetActiveWeapon()

	return IsValid(wep) and not wep:GetNoDraw() and not SmallGun(wep)
end

-- Which hands go to this wound.
--
-- A wound in the body: both hands when the gun is small enough to let go of
-- (HK USP and friends), one free hand when it is a rifle or AR-2 - the right
-- stays on the grip and the left covers the hole. A limb keeps the one hand that
-- can reach it without dragging a rifle there. Nothing to reach with means no
-- reaction.
local BOTH = { "r_", "l_" }
local RIGHT = { "r_" }
local LEFT = { "l_" }

local function Hands(npc, state)
	local fixed = reach[state.bone]

	-- a wound on an arm goes ungrabbed rather than swinging a rifle up to it
	if fixed then return HandFree(npc, fixed) and { fixed } or nil end

	local right, left = HandThere(npc, "r_"), HandThere(npc, "l_")

	-- rifle in the right hand: clutch with the free one only
	if right and left and HoldingLarge(npc) then return LEFT end

	if right and left then return BOTH end
	if right then return RIGHT end
	if left then return LEFT end
end

-- Along the skin and level, so two hands sit side by side over the hole rather than
-- one of them being pushed into the body. Straight up or down the body there is no
-- side to speak of, which leaves the NPC's own.
local function Across(npc, out)
	local side = out:Cross(vector_up)
	if side:LengthSqr() < 0.01 then return npc:GetAngles():Right() end

	return side:GetNormalized()
end

local function Clutch(npc, state, strength, at, out)
	local hands = Hands(npc, state)
	if not hands then return end

	local across = #hands > 1 and Across(npc, out) or nil

	for _, prefix in ipairs(hands) do
		local shoulder = Pose.Matrix(npc, BONE[prefix .. "upperarm"])
		local hand = Pose.Matrix(npc, BONE[prefix .. "hand"])
		if not (shoulder and hand) then continue end

		-- elbows out and down, away from the chest the hand is crossing
		local side = prefix == "r_" and 1 or -1

		local on = at + out * CLUTCH_OUT
		if across then on = on + across * (HANDS_APART * side) end

		local target = LerpVector(strength, hand:GetTranslation(), on)
		local pole = shoulder:GetTranslation() + npc:GetAngles():Right() * (ELBOW_OUT * side)
			- vector_up * ELBOW_DOWN

		Pose.SolveLimb(npc, BONE[prefix .. "upperarm"], BONE[prefix .. "forearm"],
			BONE[prefix .. "hand"], target, pole)
	end
end

local function Draw(npc)
	local state = hurt[npc]
	if not state then return end

	local t = (CurTime() - state.start) / state.length

	if t >= 1 then
		hurt[npc] = nil

		return
	end

	if not Anchor(npc, state) then return end

	local at, out = Where(npc, state)
	if not at then return end

	local strength = Envelope(t)
	local ahead = npc:GetAngles():Forward()

	-- one tilt, out of two reasons to tilt: doubling over, and curling round the
	-- wound. Their sum carries both the direction and how far, so a round through
	-- the chest folds hard over it, one through the back barely folds at all, and
	-- one through a flank leans the chest that way.
	local fold = ahead * HUNCH + out * OVER

	Lean(npc, BONE.spine1, fold:GetNormalized(), fold:Length() * strength)
	Lean(npc, BONE.neck, ahead, HEAD_DROP * strength)

	at, out = Where(npc, state)
	if not at then return end

	Clutch(npc, state, strength, at, out)
end
--//

local function Toggled(name)
	local cvar = GetConVar(name)

	return cvar == nil or cvar:GetBool()
end

ZCNPC.AddPass(25, "wound", function(npc) return hurt[npc] ~= nil end, Draw)

net.Receive("zcnpc_wound", function()
	local index = net.ReadUInt(16)
	local bone = net.ReadString()
	local length = net.ReadFloat()
	local sent = net.ReadBool() and net.ReadVector() or nil

	if length <= 0 or not Toggled("zcnpc_pain_reaction") then return end

	local npc = Entity(index)
	if not IsValid(npc) then return end
	if not npc:LookupBone(bone) then return end

	hurt[npc] = { bone = bone, start = CurTime(), length = length, sent = sent }

	-- the render override is otherwise picked up by a timer that runs five times a
	-- second, and a reaction that starts a fifth of a second late has missed most
	-- of what it was reacting to
	ZCNPC.InstallRender(npc)
end)

hook.Add("EntityRemoved", "zcnpc_wound", function(ent)
	hurt[ent] = nil
end)
