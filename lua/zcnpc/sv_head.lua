--[[
	Head shots.

	Two separate things happen when someone gets shot in the head, and Z-City
	keeps them apart:

	* the brain takes organ damage (org.brain). One bullet that actually reaches
	  the brain maxes it out no matter what fired it - the organ handler adds
	  GetDamage()/25 * 3 and clamps at 1 (modules_input/sv_organs.lua:6). Brain
	  damage kills, it never takes the head off.
	* the head takes kinetic damage, which Z-City stacks per hitgroup in
	  org.dmgstack and compares against 100 (sv_input.lua:948). That is what
	  calls hg.ExplodeHead, and that is why a Makarov never pops a player's head
	  while a slug does.

	This addon used to behead an NPC whenever a bullet reached its brain, i.e.
	always - which is why a Makarov was taking heads off. Now the brain hit only
	drops the NPC, and the head is left to Z-City's kinetic stack with
	zcnpc_headgib_damage on top of it. NPCs have that stack tripled
	(sv_input.lua:937), so it is divided back out before the comparison and the
	convar means the same damage it would on a player.

	The first of the two is not quite as absolute as it reads, and that is what
	the lethal head shot below is for. The organ handler adds damage/25 * 3 to a
	brain that has to reach a full 1, and the skull has already taken its cut of
	the round on the way through (modules_input/sv_bone.lua:26), so a weak round
	lands just short, heals off over the next minute, and the NPC gets back up
	with a bullet in its brain. A bullet into a bare head is simply the end of
	that head, whatever fired it. A helmet still counts for something: under one,
	only a round that got through to the brain is lethal on its own.

	Neither of those is a setting any more. A head shot being survivable and a
	bullet through the brain being something to walk off were bugs wearing the
	clothes of options, and there is no server that wants them back.
]]

local cfg = ZCNPC.Config
local entityMeta = FindMetaTable("Entity")

local HEAD_BONE = "ValveBiped.Bip01_Head1"
local NECK_BONE = "ValveBiped.Bip01_Neck1"

--\\ Gore cap placement
-- Gib_Input puts the cap at attachment 3 and parents it there as well
-- (headgib/init_sv.lua:162-167). On the Homigrad player models that attachment sits
-- on the head, but NPC models number their attachments differently - on a combine
-- soldier index 3 is a hand - so the cap ends up hanging off the wrong limb.
--
-- Fix in two parts: hand Gib_Input a neck-shaped attachment 3 so the prop and its
-- gore burst spawn in the right place, then swap the attachment parenting for a
-- bone follow, which is what the client actually renders from.
local function NeckBone(ent)
	return ent:LookupBone(NECK_BONE) or ent:LookupBone(HEAD_BONE)
end

-- ValveBiped spine bones run along their own X axis towards the head and carry
-- their Up out of the back - that is the frame Z-City puts a cuffed player's
-- hands behind them with (weapon_hands_sh.lua:314). An attachment is eye-style
-- instead, X out of the face and Z up, and that is what headboom.mdl and
-- Gib_Input's Vector(0, 0, 5) are built for. So rebuild one around the neck:
-- up the neck becomes Z, out of the chest becomes X.
-- Returns the bone position and that rebuilt frame.
--
-- Bones on a server side ragdoll are already set up, off its physics objects -
-- Z-City reads them the same way in sv_input.lua:947. Asking for them the way the
-- client has to (Entity:SetupBones) is what was throwing here: that method only
-- exists clientside, so every call ended in an error and the cap was never moved
-- at all. Which is why it stayed wherever attachment 3 happens to be - fine on a
-- rebel, out on the hand on a combine soldier.
local function NeckFrame(ent, bone)
	local matrix = ent:GetBoneMatrix(bone)
	local pos, boneAng

	if matrix then
		pos, boneAng = matrix:GetTranslation(), matrix:GetAngles()
	else
		pos, boneAng = ent:GetBonePosition(bone) -- no bone cache on this ragdoll yet
	end

	if not (pos and boneAng) then return end

	return pos, (-boneAng:Up()):AngleEx(boneAng:Forward())
end

-- A position to drop helmets from when the head bone has no physics of its own.
local function HeadDropPos(rag, bone)
	local physBone = rag:TranslateBoneToPhysBone(bone)
	local phys = physBone and physBone >= 0 and rag:GetPhysicsObjectNum(physBone)
	if IsValid(phys) then return phys:GetPos() end

	local matrix = rag:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end

	local pos = select(1, rag:GetBonePosition(bone))
	if pos then return pos end

	return rag:WorldSpaceCenter()
end

-- Index 3 is a real attachment on these models, just not the one Gib_Input
-- thinks it is, so the stand-in only lives for the length of that one call -
-- weapon world models on the same corpse go on reading the genuine article.
--
-- An entity is userdata, so rawget cannot read off it. Its Lua fields live in
-- the table behind GetTable(), and that table is where an override would sit -
-- reading it raw is what tells "somebody else already replaced this" apart from
-- "this is just the metatable's own method", and restoring nil afterwards
-- leaves the corpse exactly as clean as it was found.
local function WithNeckAttachment(rag, bone, run)
	local fields = rag:GetTable()
	local original = fields and rawget(fields, "GetAttachment")

	rag.GetAttachment = function(self, id)
		if id ~= 3 then return entityMeta.GetAttachment(self, id) end

		local pos, ang = NeckFrame(self, bone)
		if pos then return { Pos = pos, Ang = ang } end

		-- Stock Gib_Input indexes att.Pos with no nil check, so a missing
		-- attachment here aborts the stump. Prefer any real attachment 3, then
		-- the bone itself, rather than handing back nil.
		local real = entityMeta.GetAttachment(self, id)
		if real and real.Pos then return real end

		local fallback = HeadDropPos(self, bone)
		return { Pos = fallback, Ang = Angle(0, 0, 0) }
	end

	local ok, err = pcall(run)

	rag.GetAttachment = original

	return ok, err
end

--\\ Safe bone removal for custom ragdolls
-- Gib_RemoveBone walks every child of the head and asks each one for a physics
-- object (headgib/init_sv.lua:12). On Homigrad player models every ValveBiped
-- bone maps to one; on a lot of workshop NPC replacements - and on any skeleton
-- with helper or face bones - TranslateBoneToPhysBone returns -1 and
-- GetPhysicsObjectNum comes back nil. The stock function then indexes that nil
-- and the rest of Gib_Input never runs, which is why the head scales away and
-- the neck stump never appears.
--
-- Stock also drops the severed phys object to 0.1 kg (headgib/init_sv.lua:14)
-- while it is still jointed to the neck. That is the "headshot yeets them into
-- another world" with ArtAgdoll off: any leftover impulse on a tenth of a kilo
-- drags the whole ragdoll through the joint. Keep the stump heavy enough that
-- a push moves it a sane distance.
--
-- Freezing that phys with EnableMotion(false) fixed the yeet but drew a mesh
-- spike on heads: leftover skinned verts stay pinned to a world-frozen bone
-- while the neck rides away with the body. Limbs rarely show it (weights are
-- tighter); a head almost always does. Weld the invisible phys onto its parent
-- instead so it travels with the stump.
-- Not Vector(0, 0, 0), and this is the point blank shotgun crash.
--
-- A bone scaled to a flat zero has a bone matrix with a zero determinant, and
-- anything that has to invert one gets an infinity for its trouble. The renderer
-- inverts them to project a decal: util.Decal against a model works out where the
-- hit lands in each bone's own frame, which means inverting that bone's matrix, and
-- a shotgun is eight bullet holes on one body inside a single tick. That is the
-- whole of "shooting a metrocop in the head with a shotgun crashes" - buckshot
-- takes the head off on the first pellets and then keeps putting decals on the
-- body it has just made unprojectable.
--
-- Z-City hides an amputated limb at Vector(0.01, 0.01, 0.01) for the same reason and
-- calls it vecalmostzero (organism/tier_1/cl_main.lua:962) - its own head gib is the
-- one place it still passes a flat zero (headgib/init_sv.lua:7), which is the path
-- an NPC of ours goes down. Same number here rather than a smaller one of our own:
-- a hundredth of full size is a head a fifth of a millimetre across, gone to look
-- at, and it is the value the rest of the game is already proven at.
local GIB_SCALE = Vector(0.01, 0.01, 0.01)
local GIB_MIN_MASS = 3

local function ScaleSharedBones(rag, phys_bone)
	if not phys_bone or phys_bone < 0 then return end

	local count = rag:GetBoneCount()
	if not count then return end

	for b = 0, count - 1 do
		if rag:TranslateBoneToPhysBone(b) == phys_bone then
			rag:ManipulateBoneScale(b, GIB_SCALE)
		end
	end
end

-- deleteonbreak is off, and it has to be: constraint.Weld hands that flag to
-- Ent2:DeleteOnRemove(Ent1), and both of ours are the same ragdoll, so a true
-- there is a body told to delete itself as it is being deleted.
local function AttachGibToParent(rag, bone, phys_bone, phys)
	local parentBone = rag:GetBoneParent(bone)
	if not parentBone or parentBone < 0 then return end

	local parentPhysBone = rag:TranslateBoneToPhysBone(parentBone)
	if not parentPhysBone or parentPhysBone < 0 or parentPhysBone == phys_bone then return end

	local parentPhys = rag:GetPhysicsObjectNum(parentPhysBone)
	if not IsValid(parentPhys) then return end

	phys:SetPos(parentPhys:GetPos())
	phys:SetAngles(parentPhys:GetAngles())

	rag.zcnpc_gibWelds = rag.zcnpc_gibWelds or {}
	local old = rag.zcnpc_gibWelds[phys_bone]
	if IsValid(old) then old:Remove() end

	rag.zcnpc_gibWelds[phys_bone] = constraint.Weld(rag, rag, phys_bone, parentPhysBone, 0, 0, false)
end

-- Once per body per bone, for the lifetime of that body. The engine hands out one
-- constraint per joint and freeing one twice is freeing a pointer twice, so this is
-- the difference between a beheading and a segfault - and a head gib reaches here
-- three times over as things stand: once on the way through SafeRemoveBone and
-- again from each of the two ZCNPC.SaneGibMass passes behind it.
local function CutInternalJoint(rag, phys_bone)
	rag.zcnpc_gibCut = rag.zcnpc_gibCut or {}
	if rag.zcnpc_gibCut[phys_bone] then return end

	rag.zcnpc_gibCut[phys_bone] = true

	-- Stock only strips Lua constraints and leaves the internal one
	-- (headgib/init_sv.lua:15 commented out) - that joint is what still yeets the
	-- torso when the stump gets any leftover impulse. Z-City uses the same call on
	-- player beheads (sv_input.lua:1555).
	pcall(function() rag:RemoveInternalConstraint(phys_bone) end)
end

local function SafeRemoveBone(rag, bone, phys_bone, nohuys)
	if not bone or bone < 0 then return end

	if not nohuys then
		rag:ManipulateBoneScale(bone, GIB_SCALE)
		if phys_bone and phys_bone >= 0 then ScaleSharedBones(rag, phys_bone) end
	end

	if not phys_bone or phys_bone < 0 then return end

	rag.gibRemove = rag.gibRemove or {}
	if rag.gibRemove[phys_bone] then return end

	local phys = rag:GetPhysicsObjectNum(phys_bone)
	if not IsValid(phys) then return end

	CutInternalJoint(rag, phys_bone)

	phys:EnableCollisions(false)
	phys:SetMass(GIB_MIN_MASS)
	phys:SetVelocityInstantaneous(vector_origin)
	phys:AddAngleVelocity(-phys:GetAngleVelocity())
	phys:SetDamping(30, 30)

	AttachGibToParent(rag, bone, phys_bone, phys)
	phys:EnableMotion(true)
	phys:Wake()

	rag.gibRemove[phys_bone] = phys
end

local function SafeRemoveBoneTree(rag, bone, phys_bone, nohuys)
	rag.gibRemove = rag.gibRemove or {}

	SafeRemoveBone(rag, bone, phys_bone, nohuys)

	-- Every bone once. A skeleton is a tree and this walk assumed one, which is
	-- true of every model anybody ships on purpose and is not something to bet a
	-- recursive descent on: one bone that lists an ancestor among its children and
	-- this never returns, which in Lua is a C stack overflow taken inside a damage
	-- callback. The guard costs a table per beheading.
	local seen = { [bone] = true }

	local function walk(parent)
		for _, child in pairs(rag:GetChildBones(parent)) do
			if child ~= 0 and not seen[child] then
				seen[child] = true

				SafeRemoveBone(rag, child, rag:TranslateBoneToPhysBone(child), nohuys)
				walk(child)
			end
		end
	end

	walk(bone)
end

if not ZCNPC.__origGibRemoveBone and isfunction(Gib_RemoveBone) then
	ZCNPC.__origGibRemoveBone = Gib_RemoveBone

	function Gib_RemoveBone(rag, bone, phys_bone, nohuys)
		if not IsValid(rag) then return end

		SafeRemoveBoneTree(rag, bone, phys_bone, nohuys)
	end
end

-- Meat chunks are prop_physics with collide callbacks. Eight to ten of them per
-- head, times three or four bodies in one fight, is a physics spike the server
-- feels as a hitch. Cap the count and share a per-tick budget across everyone.
local GORE_MAX = 4
local GORE_BUDGET = 12
local goreTick, goreSpent = 0, 0

local function GoreCount(want)
	local tick = engine.TickCount()
	if tick ~= goreTick then
		goreTick = tick
		goreSpent = 0
	end

	local left = GORE_BUDGET - goreSpent
	if left <= 0 then return 0 end

	local n = math.min(want or GORE_MAX, GORE_MAX, left)
	goreSpent = goreSpent + n

	return n
end

if not ZCNPC.__origSpawnMeatGore and isfunction(SpawnMeatGore) then
	ZCNPC.__origSpawnMeatGore = SpawnMeatGore

	function SpawnMeatGore(mainent, pos, count, force, scale)
		local n = GoreCount(count or GORE_MAX)
		if n <= 0 then return end

		return ZCNPC.__origSpawnMeatGore(mainent, pos, n, force, scale)
	end
end

-- When the head bone itself has no physics object, stock Gib_Input still dies on
-- the armour drop (phys_obj:GetPos at headgib/init_sv.lua:176) even after the
-- bone walk is safe. Run the same sequence ourselves with a fallback position.
local HEAD_SOUNDS_GIB = {
	"player/zombie_head_explode_01.wav",
	"player/zombie_head_explode_02.wav",
	"player/zombie_head_explode_03.wav",
	"player/zombie_head_explode_04.wav",
	"player/zombie_head_explode_05.wav",
	"player/zombie_head_explode_06.wav",
}

local function FindStump(rag)
	for _, child in ipairs(rag:GetChildren()) do
		if IsValid(child) and child:GetModel() == cfg.StumpModel then return child end
	end
end

local function SafeGibInput(rag, bone, force)
	-- noHead, not gibRemove: stock may have filled gibRemove and then died on the
	-- armour drop, leaving a scaled-away head with no stump. That body still needs
	-- the rest of this path.
	if rag.noHead or rag.headexploded then return end

	rag.gibRemove = rag.gibRemove or {}

	local phys_bone = rag:TranslateBoneToPhysBone(bone)
	local partial = phys_bone and rag.gibRemove[phys_bone]

	-- A partial stock run already made the noise and scaled the bones; don't
	-- replay that half, just finish what it never reached.
	if not partial then
		rag:EmitSound(HEAD_SOUNDS_GIB[math.random(#HEAD_SOUNDS_GIB)], 70, math.random(95, 105), 2)
		SafeRemoveBoneTree(rag, bone, phys_bone)

		local neckBone = rag:LookupBone(NECK_BONE)
		if neckBone then rag:ManipulateBonePosition(neckBone, Vector(-1, 0, 0)) end
	end

	local stump = FindStump(rag)
	local pos, ang

	if not stump then
		local att = rag:GetAttachment(3)

		if att and att.Pos and att.Ang then
			local female = isfunction(ThatPlyIsFemale) and ThatPlyIsFemale(rag)
			pos, ang = LocalToWorld(female and Vector(-2, 0, 4) or Vector(0, 0, 5), Angle(0, 0, 0), att.Pos, att.Ang)
		else
			pos, ang = NeckFrame(rag, NeckBone(rag) or bone)
			if not pos then pos, ang = HeadDropPos(rag, bone), Angle(0, 0, 0) end
		end

		stump = ents.Create("prop_dynamic")
		if IsValid(stump) then
			stump:SetModel(cfg.StumpModel)
			stump:SetPos(pos)
			stump:SetAngles(ang or Angle(0, 0, 0))
			stump:SetParent(rag, 3)
			stump:Spawn()
		end

		if isfunction(SpawnMeatGore) then SpawnMeatGore(stump or rag, pos, nil, force) end
	else
		pos = stump:GetPos()
	end

	local dropPos = HeadDropPos(rag, bone)
	local armors = rag.GetNetVar and rag:GetNetVar("Armor", {}) or {}

	if istable(armors) and isfunction(hg.DropArmorForce) and istable(rag.armors) then
		for _, slot in ipairs({ "head", "face" }) do
			local piece = armors[slot]
			if not piece then continue end

			-- Every one of these is a way the drop ends in something worse than a
			-- helmet staying on a head that is gone. A piece Z-City has never heard
			-- of walks straight into indexing nil inside DropArmorForce. One it is
			-- not actually wearing does too, off table.HasValue on the first line of
			-- it. And a piece with no model of its own - which is what a metrocop's
			-- helmet and vest are, worn but never dropped (sh_armorstuff.lua:493) -
			-- becomes an entity with an empty model asked to build physics out of it,
			-- and the engine goes down rather than complain (garrysmod-issues #6754).
			local data = istable(hg.armor) and istable(hg.armor[slot]) and hg.armor[slot][piece]
			if not istable(data) then continue end
			if data.nodrop then continue end
			if not (isstring(data.model) and data.model ~= "") then continue end
			if not table.HasValue(rag.armors, piece) then continue end

			local dropped = hg.DropArmorForce(rag, piece)
			if IsValid(dropped) then dropped:SetPos(dropPos) end
		end
	end

	rag.noHead = true
	rag:SetNWString("PlayerName", "Beheaded body")

	if istable(hg) and not (hg.fountains and hg.fountains[rag]) then
		local neck = rag:LookupBone(NECK_BONE) or NeckBone(rag)

		hg.fountains = hg.fountains or {}
		hg.fountains[rag] = {
			bone = neck,
			lpos = (isfunction(ThatPlyIsFemale) and ThatPlyIsFemale(rag)) and Vector(4, 0, 0) or Vector(5, 0, 0),
			lang = Angle(0, 0, 0),
		}

		net.Start("addfountain")
		net.WriteEntity(rag)
		net.WriteVector(force or vector_origin)
		net.Broadcast()

		if isfunction(SetNetVar) then SetNetVar("fountains", hg.fountains) end

		rag:CallOnRemove("removefountain", function()
			if not istable(hg) then return end
			hg.fountains[rag] = nil
			if isfunction(SetNetVar) then SetNetVar("fountains", hg.fountains) end
		end)
	end
end

local function HeadHasPhysics(rag, bone)
	local phys_bone = rag:TranslateBoneToPhysBone(bone)
	if not phys_bone or phys_bone < 0 then return false end

	return IsValid(rag:GetPhysicsObjectNum(phys_bone))
end

if not ZCNPC.__origGibInput and isfunction(Gib_Input) then
	ZCNPC.__origGibInput = Gib_Input

	function Gib_Input(rag, bone, force)
		if not IsValid(rag) then return end

		local neck = rag.zcnpc_npcbody and cfg.headfix:GetBool() and NeckBone(rag)
		local safe = not HeadHasPhysics(rag, bone)

		local function run()
			if safe then
				SafeGibInput(rag, bone, force)
				return
			end

			-- Bone walk is patched, but armour drops and attachment math can
			-- still blow up on odd skeletons. Finish the stump ourselves if so.
			local ok, err = pcall(ZCNPC.__origGibInput, rag, bone, force)
			if ok then return end

			ErrorNoHalt("[ZCNPC] gore cap: " .. tostring(err) .. "\n")
			if not rag.noHead then SafeGibInput(rag, bone, force) end
		end

		if neck then
			local ok, err = WithNeckAttachment(rag, neck, run)
			if not ok then
				ErrorNoHalt("[ZCNPC] gore cap: " .. tostring(err) .. "\n")
				if not rag.noHead then
					WithNeckAttachment(rag, neck, function()
						SafeGibInput(rag, bone, force)
					end)
				end
			end
		else
			run()
		end

		ZCNPC.SaneGibMass(rag)
		if ZCNPC.WatchBody then ZCNPC.WatchBody(rag) end
	end
end

-- Where the cap ends up in the neck bone's own frame, and it is worth writing
-- out rather than measuring, because measuring is what kept going wrong.
--
-- Gib_Input offsets the cap from attachment 3 by Vector(0, 0, 5) on a male model
-- and Vector(-2, 0, 4) on a female one, at the attachment's own angles. Feed it
-- the eye-style frame NeckFrame builds - forward out of the chest, up along the
-- neck - and those offsets fall out as plain multiples of the bone's axes: up the
-- neck is the bone's X, out of the back is its Z. So five units up the neck is
-- Vector(5, 0, 0) in bone space, which is exactly where Z-City hangs the blood
-- fountain for the same body (headgib/init_sv.lua:192), and the female offset
-- adds two units towards the back on top of four up.
--
-- The rotation is the same frame swap written as an angle: pitch 90 lays the
-- prop's forward down the bone's -Z and stands its up along the bone's X.
--
-- How far up the neck is zcnpc_headgib_drop rather than Z-City's five, because
-- five is measured on a Homigrad player model and an NPC neck is not that neck.
-- On a combine soldier or a rebel the cap ended up hovering a good inch clear of
-- the collar with daylight under it, which is the whole of "the thing that pops
-- out sits too high". The offset towards the back on a female model is Z-City's
-- own and is kept in proportion with it.
local STUMP_BACK_FEMALE = 2
local STUMP_REFERENCE = 5 -- what the female offsets below are written against
local STUMP_ANGLE = Angle(90, 0, 0)

local function StumpOffset(rag)
	local up = cfg.headgib_drop:GetFloat()

	if not (isfunction(ThatPlyIsFemale) and ThatPlyIsFemale(rag)) then return Vector(up, 0, 0) end

	return Vector(up * 0.8, 0, STUMP_BACK_FEMALE * up / STUMP_REFERENCE)
end

function ZCNPC.AnchorHeadStump(rag, stump)
	local bone = NeckBone(rag)
	if not bone then return end

	stump:SetParent(NULL)
	stump:FollowBone(rag, bone)
	stump:SetLocalPos(StumpOffset(rag))
	stump:SetLocalAngles(STUMP_ANGLE)

	ZCNPC.Debug("re-anchored gore cap on", rag)
end

-- Catches every cap Z-City spawns on a body of ours, no matter which of its code
-- paths did the beheading (our kills, a head shot into a corpse, admin tools).
hook.Add("OnEntityCreated", "zcnpc_headstump", function(ent)
	-- the model and the parent are only assigned after this hook returns
	if ent:GetClass() ~= "prop_dynamic" then return end

	timer.Simple(0, function()
		if not IsValid(ent) or ent:GetModel() ~= cfg.StumpModel then return end
		if not cfg.headfix:GetBool() then return end

		local rag = ent:GetParent()
		if not (IsValid(rag) and rag.zcnpc_npcbody) then return end

		ZCNPC.AnchorHeadStump(rag, ent)
	end)
end)
--//

--\\ Finding the organism
-- It moves onto the body the moment an NPC goes down, and a head shot heavy
-- enough to do that arrives in the very same frame, so whichever of the two the
-- caller happens to be holding, the other one is worth asking. Reading it off
-- the NPC alone is what used to let a head come off unconditionally: the lookup
-- came back nil and every threshold below it was comparing against nothing.
function ZCNPC.ResolveOrganism(ent)
	if not IsValid(ent) then return end
	if ent.organism then return ent.organism end

	local rag = ent.zcnpc_rag
	if IsValid(rag) and rag.organism then return rag.organism end

	local npc = ent.zcnpc_npc
	if IsValid(npc) and npc.organism then return npc.organism end
end
--//

--\\ Is this hit big enough to take a head off?
-- Z-City keeps the running total in org.dmgstack[HITGROUP_HEAD][1] and wipes it
-- a frame after it fires, so it is only readable during the hit that caused it.
local NPC_STACK_MUL = 3 -- what sv_input.lua:937 multiplies an NPC's stack by
local STACK_MEMORY = 0.5

local function LiveStack(ent, org)
	local stack = org and org.dmgstack and org.dmgstack[HITGROUP_HEAD]
	stack = stack and stack[1]
	if not stack then return end

	-- Divide the NPC bonus back out so the threshold means the same damage it
	-- would mean on a player. A body on the ground is not an NPC any more and
	-- never got the bonus in the first place.
	if IsValid(ent) and ent:IsNPC() then return stack / NPC_STACK_MUL end

	return stack
end

-- Copied off the organism while the stack is still there, because several of the
-- decisions below are deferred by a frame and land after Z-City has wiped it.
-- Buckshot arrives as one hit per pellet within a single tick and Z-City stacks
-- those together, so the largest total seen inside the window is the one to keep.
function ZCNPC.RememberHeadDamage(ent, org, dmgInfo)
	local stack = LiveStack(ent, org)
	if not (stack and IsValid(ent)) then return end

	if (ent.zcnpc_headstack_till or 0) < CurTime() then ent.zcnpc_headstack = nil end

	ent.zcnpc_headstack = math.max(ent.zcnpc_headstack or 0, stack)
	ent.zcnpc_headstack_till = CurTime() + STACK_MEMORY

	-- which way the head is thrown when it does come off, and how hard the body
	-- goes down: needed on every hit to the head, not only the ones that reach
	-- the brain, because either can be the one that takes the head off
	if dmgInfo then ent.zcnpc_headforce = ZCNPC.ClampedForce(dmgInfo) end
end

local function Remembered(ent)
	if not IsValid(ent) then return end
	if (ent.zcnpc_headstack_till or 0) < CurTime() then return end

	return ent.zcnpc_headstack
end

-- nil means nothing has shot this head at all, which is how a beheading that did
-- not come from a bullet is recognised (the admin limb tool, a Fury syringe,
-- another addon) - those always go through.
function ZCNPC.HeadStack(ent, org)
	local live = LiveStack(ent, org)
	if live then return live end
	if not IsValid(ent) then return end

	return Remembered(ent) or Remembered(ent.zcnpc_rag) or Remembered(ent.zcnpc_npc)
end

-- Class is read off the live NPC, the hidden half of a downed body, or
-- zcnpc_class stamped on the rag when the NPC entity is already gone.
function ZCNPC.IsMetrocop(ent)
	if not IsValid(ent) then return false end

	if ent:IsNPC() then return ent:GetClass() == "npc_metropolice" end

	if ent.zcnpc_class == "npc_metropolice" then return true end

	local npc = ent.zcnpc_npc
	if IsValid(npc) and npc:GetClass() == "npc_metropolice" then return true end

	local info = ZCNPC.Downed and ZCNPC.Downed[ent]
	if info and info.class == "npc_metropolice" then return true end

	return false
end

-- On the floor (knocked down / KO / already a corpse from bleed-out). Standing
-- metrocops keep the head; once they are down it can come off.
function ZCNPC.IsDownedBody(ent)
	if not IsValid(ent) then return false end

	if ent:IsNPC() then
		local rag = ent.zcnpc_rag
		return IsValid(rag) and ZCNPC.Downed and ZCNPC.Downed[rag] ~= nil
	end

	if ZCNPC.Downed and ZCNPC.Downed[ent] then return true end
	if ent.zcnpc_corpse then return true end

	return false
end

function ZCNPC.HeadGibAllowed(ent, org)
	if not cfg.headgib:GetBool() then return false end
	-- Metrocops: lethal head shots still kill while upright, but the head only
	-- comes off once the body is already on the floor.
	if ZCNPC.IsMetrocop(ent) and not ZCNPC.IsDownedBody(ent) then return false end

	local stack = ZCNPC.HeadStack(ent, org)

	-- nil stack = admin / scripted beheading with nothing to measure - always ok.
	-- A real round also needs a heavy weapon when gib_heavy_only is on.
	if stack == nil then return true end
	if stack <= cfg.headgib_damage:GetFloat() then return false end
	if ZCNPC.GibWeaponAllowed and not ZCNPC.GibWeaponAllowed(ent, org) then return false end

	return true
end
--//

--\\ Taking the head off a body
-- Gib_Input leaves the severed part behind as an invisible physics object still
-- jointed to the neck - the internal joint is never cut, only the Lua constraints
-- on it are. Stock drops that object to 0.1 kg; SafeRemoveBone above keeps it at
-- GIB_MIN_MASS instead. This still restores anything that slipped through at the
-- stock weight (another addon's Gib_RemoveBone, a partial stock run).
function ZCNPC.SaneGibMass(rag)
	if not IsValid(rag) then return end

	for i, phys in pairs(rag.gibRemove or {}) do
		if not IsValid(phys) then continue end

		if phys:GetMass() < GIB_MIN_MASS then phys:SetMass(GIB_MIN_MASS) end

		phys:EnableCollisions(false)
		phys:SetVelocityInstantaneous(vector_origin)
		phys:AddAngleVelocity(-phys:GetAngleVelocity())
		phys:SetDamping(30, 30)

		if isnumber(i) then
			CutInternalJoint(rag, i)
			-- Keep motion on: a world-frozen gib phys is the head-mesh spike.
			phys:EnableMotion(true)

			local weld = rag.zcnpc_gibWelds and rag.zcnpc_gibWelds[i]
			if not IsValid(weld) then
				-- Parent bone unknown here; snap to pelvis as a last resort so the
				-- phys is at least on the body rather than stranded in the air.
				local pelvis = rag:LookupBone("ValveBiped.Bip01_Pelvis")
				local parentPhysBone = pelvis and rag:TranslateBoneToPhysBone(pelvis)
				local parentPhys = parentPhysBone and parentPhysBone ~= i and rag:GetPhysicsObjectNum(parentPhysBone)
				if IsValid(parentPhys) then
					phys:SetPos(parentPhys:GetPos())
					phys:SetAngles(parentPhys:GetAngles())
					rag.zcnpc_gibWelds = rag.zcnpc_gibWelds or {}
					rag.zcnpc_gibWelds[i] = constraint.Weld(rag, rag, i, parentPhysBone, 0, 0, false)
				end
			end
		end
	end
end

local SaneGibMass = ZCNPC.SaneGibMass

--\\ The sound of a round finding a head
-- Z-City only ever voices the head shots that take the head clean off: the pop is
-- inside Gib_Input (headgib/init_sv.lua:153) and nothing else says anything. Every
-- other lethal head shot is carried by whatever Z-City's bone module happened to
-- emit on the way past, which is a skull crack on the first hit and silence on the
-- rest of them - so shooting a body in the head, which has usually cracked already,
-- was silent, while shooting a standing NPC in the head was not.
--
-- One sound, from the head, on every lethal head shot, whichever of the two it is.
local HEAD_SOUNDS = {
	"physics/flesh/flesh_squishy_impact_hard1.wav",
	"physics/flesh/flesh_squishy_impact_hard2.wav",
	"physics/flesh/flesh_squishy_impact_hard3.wav",
	"physics/flesh/flesh_squishy_impact_hard4.wav",
}

-- The entity origin is no use on a ragdoll - it stays wherever the body was
-- created while the head is off somewhere on the end of a neck.
local function HeadPos(ent)
	local bone = ent:LookupBone(HEAD_BONE) or ent:LookupBone(NECK_BONE)
	if not bone then return ent:WorldSpaceCenter() end

	local matrix = ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end

	local physBone = ent:TranslateBoneToPhysBone(bone)
	local phys = physBone and physBone >= 0 and ent:GetPhysicsObjectNum(physBone)
	if IsValid(phys) then return phys:GetPos() end

	return ent:WorldSpaceCenter()
end

-- gibbed: the head is coming off, and Gib_Input has a far louder noise for that
-- already. Doubling them up reads as an echo.
function ZCNPC.HeadshotSound(ent, gibbed)
	if not (IsValid(ent) and cfg.headshot_sound:GetBool()) then return end
	if gibbed then return end

	-- one per body: a shotgun puts eight pellets through a head inside one tick
	if (ent.zcnpc_headsound or 0) > CurTime() then return end
	ent.zcnpc_headsound = CurTime() + 0.5

	sound.Play(HEAD_SOUNDS[math.random(#HEAD_SOUNDS)], HeadPos(ent), 75, math.random(90, 105), 1)
end
--//

function ZCNPC.GibHead(rag, force)
	if not IsValid(rag) or not isfunction(Gib_Input) then return end
	if rag.noHead or rag.headexploded then return end

	local head = rag:LookupBone(HEAD_BONE)
	if not head then return end

	-- Gore direction only - never feed bullet force into Gib_Input, or the stump
	-- inherits a truck hit.
	rag.zcnpc_npcbody = true
	Gib_Input(rag, head, vector_origin)
	SaneGibMass(rag)

	rag.headexploded = true

	-- Artagdoll's head shot reaction throws the head back and lets the body follow
	-- it down (behaviors/headshot.lua:43), which is worth watching once and absurd
	-- on a body that no longer has one: the punch lands on an invisible stump and
	-- the whole ragdoll is dragged along behind it.
	rag.DMS_IsHeadshot = false

	local org = rag.organism
	if org then
		org.headamputated = true
		org.brain = 1
		rag.fullsend = true
		hg.send_bareinfo(org)
	end

	-- Said here rather than left to whatever is going to notice, because there is
	-- nothing left to wait for: a body with no head on it is finished, by every
	-- route that could still be pending and regardless of which of them was going to
	-- get there. Whatever was animating it stops on this line, and the guard in
	-- sv_artagdoll.lua sees to it that nothing starts again afterwards - which is the
	-- whole of a headless body that went on struggling.
	ZCNPC.ActiveDie(rag)

	ZCNPC.Debug("head gibbed on", rag)
end

-- Mark NPC corpses so the gore cap fix and the attachment stand-in apply to them
-- as well - these bodies come from Z-City's own "npcloot" hook, not from us.
hook.Add("CreateEntityRagdoll", "zcnpc_npcbody", function(ent, rag)
	if not (IsValid(ent) and ent:IsNPC() and IsValid(rag)) then return end
	if ZCNPC.DropEngineRagdoll and ZCNPC.DropEngineRagdoll(ent, rag) then return end

	rag.zcnpc_npcbody = true
	rag.zcnpc_npc = rag.zcnpc_npc or ent
	rag.zcnpc_class = ent:GetClass()

	if not ZCNPC.Enabled() then return end
	if (ent.zcnpc_headwound or 0) < CurTime() then return end

	-- the engine killed it upright (armour ate the brain damage, explosion, ...)
	-- but the last thing that hit it was still a head shot. Decide here while the
	-- damage stack that caused it is still on the organism.
	if not ZCNPC.HeadGibAllowed(ent, ZCNPC.ResolveOrganism(ent) or rag.organism) then return end

	-- vector_origin on purpose: headforce is only remembered for diagnostics;
	-- feeding it into Gib_Input launches the stump.
	timer.Simple(0, function() ZCNPC.GibHead(rag, vector_origin) end)
end)

hook.Add("ZCNPC_Downed", "zcnpc_npcbody", function(npc, rag)
	rag.zcnpc_npcbody = true
	rag.zcnpc_keepbody = true
	if IsValid(npc) then rag.zcnpc_class = npc:GetClass() end
end)
--//

--\\ Lethal head shots
-- Drop them first, kill them a beat later. Instant KillDowned on a standing NPC
-- stacked impulses on top of each other and launched the corpse; knocking them out
-- as a normal body and only then finishing the job lets the fall play out as a fall.
--
-- Launch comes from Z-City punching the hit bone with DamageForce after
-- HomigradDamage returns (sv_input.lua:920), and from ArtAgdoll fighting the
-- floor into that punch. Fix at the source: zero DamageForce on lethal head
-- shots, BulkHead so any leftover punch divides by real mass, and keep ArtAgdoll
-- off / dead - no whole-body speed cap and no Soften Think wipe (those broke
-- kicks and pinned corpses into slow-mo).
local HEAD_KILL_DELAY = 0.3
local HEAD_BULK_MASS = 55 -- resists Z-City's ApplyForceCenter that runs after our hook

-- Bulk the head up BEFORE HomigradDamage returns: Z-City punches it with the full
-- force length immediately after (sv_input.lua:920), and mass is what that punch
-- divides by. Velocity is left alone — zeroing a 55 kg head on a fresh standing
-- ragdoll is an anchor, and that was the slow-mo fall. DamageForce is already
-- starved on this path.
local function BulkHead(rag)
	if not (IsValid(rag) and rag:IsRagdoll()) then return end

	local bone = rag:LookupBone(HEAD_BONE) or rag:LookupBone(NECK_BONE)
	if not bone then return end

	local physBone = rag:TranslateBoneToPhysBone(bone)
	if not physBone or physBone < 0 then return end

	local phys = rag:GetPhysicsObjectNum(physBone)
	if not IsValid(phys) then return end

	if phys:GetMass() < HEAD_BULK_MASS then phys:SetMass(HEAD_BULK_MASS) end
end

-- Starve Z-City's post-hook ApplyForceCenter without touching kick shove paths
-- (those write addVel into CreateNPCRagdoll, not DamageForce on a corpse).
local function StarveHeadPunch(dmgInfo)
	if dmgInfo then dmgInfo:SetDamageForce(vector_origin) end
end

-- Standing NPCs are the one case Z-City lets engine HP through
-- (sv_input.lua:1121 returns false for NPCs). A lethal head shot then kills the
-- NPC for real, CreateEntityRagdoll fires, and ArtAgdoll's DMS_Init sees
-- DMS_IsHeadshot - that corpse is the launch. Bodies already on the ground never
-- hit this path: the NPC is GODMODE'd and the ragdoll takes the round instead.
--
-- A hand-over rather than a state, and that difference is a bug worth naming.
-- GODMODE goes on so the engine cannot kill the NPC out from under the ragdoll that
-- is one tick away from replacing it, and it is supposed to come off again the
-- moment that ragdoll exists - MakeUnconscious puts its own back on the husk
-- (sv_uncon.lua). What it must never do is stay on an NPC that is still standing,
-- because GODMODE is total: shoot its legs and nothing happens, kick it and nothing
-- happens, shoot it in the head again and it survives that too, and every hit after
-- that goes down the "already dying" branch below and renews the flag. Which is
-- exactly what it did whenever the hand-over fell through.
--
-- And the hand-over falls through in two ordinary ways. MakeUnconscious hands back
-- nothing for a model with no ragdoll physics, and nothing for an organism that
-- died in the tick between the hit and the deferred kill. Both were meant to be
-- covered by a plain engine kill, and that kill was being swallowed by the GODMODE
-- set three lines above it.
--
-- So the hold has an end, and something watches for the end being reached.
local HOLD_MAX = 1

local holding = {} -- [npc] = true, while it is waiting to become a body

local function HoldStandingHeadshot(npc, dmgInfo)
	if not (IsValid(npc) and npc:IsNPC()) then return end

	npc.zcnpc_headkill = true
	npc.DMS_IsHeadshot = false

	-- Only ours to hand back if it was not already on. An admin tool, a map or
	-- another addon may have set it, and taking it off again would be this deciding
	-- something it was never asked about. If the flag is already ours from a
	-- knockdown that never handed it back, take ownership of the hold so the
	-- watchdog can strip it — otherwise EngineKill hits GODMODE and they stand
	-- there for the rest of the round.
	if bit.band(npc:GetFlags(), FL_GODMODE) == 0 then
		npc.zcnpc_headgod = true
		npc:AddFlags(FL_GODMODE)
		if ZCNPC.Godded then ZCNPC.Godded[npc] = true end
	elseif ZCNPC.Godded and ZCNPC.Godded[npc] then
		npc.zcnpc_headgod = true
	end

	npc.zcnpc_headhold = CurTime() + HOLD_MAX
	holding[npc] = true

	-- Cut off any HL2 sentence already in flight (citizen "Ow!" on the same hit).
	if npc.SentenceStop then npc:SentenceStop() end

	if dmgInfo then
		dmgInfo:SetDamage(0)
		StarveHeadPunch(dmgInfo)
	end
end

-- What the hold was standing in for, when there is no body to hand over to.
local function EngineKill(npc)
	local d = DamageInfo()
	d:SetDamage(10000)
	d:SetDamageType(DMG_GENERIC)
	d:SetAttacker(game.GetWorld())
	d:SetInflictor(game.GetWorld())

	npc:TakeDamageInfo(d)
end

-- Take the hold off a standing NPC.
--
-- `dying` is for the caller that is about to kill it by hand: the head is still
-- finished, so the mark stays and ArtAgdoll is still told not to make a headshot
-- corpse out of what is left. Without it the mark goes too, which is the only way
-- back to being an ordinary NPC that ordinary damage works on - and that is the
-- right answer for a kill that is not going to happen at all.
function ZCNPC.ReleaseHeadHold(npc, dying)
	holding[npc] = nil

	if not IsValid(npc) then return end

	npc.zcnpc_headhold = nil

	-- The husk behind a body on the floor keeps all of it: its GODMODE belongs to
	-- the knockdown now and comes off when the knockdown does.
	if IsValid(npc.zcnpc_rag) then
		npc.zcnpc_headgod = nil

		return
	end

	if npc.zcnpc_headgod or (ZCNPC.Godded and ZCNPC.Godded[npc]) then
		npc.zcnpc_headgod = nil
		if ZCNPC.ReleaseGod then
			ZCNPC.ReleaseGod(npc, true)
		else
			npc:RemoveFlags(FL_GODMODE)
		end
	end

	if not dying then npc.zcnpc_headkill = nil end
end

-- Empty a tick after any head shot, because everything that completes the hand-over
-- drops the hold. It exists for the hand-over that does not complete at all - an
-- error thrown inside the deferred kill, an organism that went away underneath it -
-- since the price of missing one is an NPC nothing can hurt for the rest of the
-- round.
timer.Create("zcnpc_headhold", 0.5, 0, function()
	if not next(holding) then return end

	local now = CurTime()

	for npc in pairs(holding) do
		if not IsValid(npc) then
			holding[npc] = nil
		elseif IsValid(npc.zcnpc_rag) then
			ZCNPC.ReleaseHeadHold(npc, true)
		elseif (npc.zcnpc_headhold or 0) < now then
			ZCNPC.Debug("head shot hand-over never arrived, releasing", npc)

			-- Let go first and finish the job second. The kill is a plain engine
			-- kill and GODMODE is precisely what stops one, which is the whole of
			-- what went wrong here in the first place. Released without the mark, so
			-- that an NPC which somehow survives this is a normal NPC again rather
			-- than a latched one nobody can shoot.
			ZCNPC.ReleaseHeadHold(npc)
			EngineKill(npc)
		end
	end
end)

-- The body arrived: the hold did its job and the knockdown owns the flag from here.
hook.Add("ZCNPC_Downed", "zcnpc_headhold", function(npc)
	if holding[npc] then ZCNPC.ReleaseHeadHold(npc, true) end
end)

-- Engine death ragdoll that slipped through before SetDamage(0): kill the
-- ArtAgdoll headshot reaction immediately and remove the duplicate once ours
-- exists.
hook.Add("CreateEntityRagdoll", "zcnpc_headkill_engine", function(ent, rag)
	if not (ZCNPC.Enabled() and IsValid(ent) and ent:IsNPC() and ent.zcnpc_headkill and IsValid(rag)) then
		return
	end
	if ZCNPC.DropEngineRagdoll and ZCNPC.DropEngineRagdoll(ent, rag) then return end

	rag.DMS_IsHeadshot = false
	rag.zcnpc_headkill = true
	rag.zcnpc_npcbody = true

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		phys:SetVelocityInstantaneous(vector_origin)
		phys:AddAngleVelocity(-phys:GetAngleVelocity())
	end

	timer.Simple(0, function()
		if not IsValid(rag) then return end
		if ZCNPC.ActiveDie then ZCNPC.ActiveDie(rag) end
	end)

	timer.Simple(0.05, function()
		if not IsValid(rag) then return end

		local ours = IsValid(ent) and ent.zcnpc_rag
		if IsValid(ours) and ours ~= rag then rag:Remove() end
	end)
end)

-- Headshot corpses must not keep an active ragdoll: a living stumble into the
-- kill is the other half of the launch, and DeathThroes look like "still alive".
local function LimpHeadshot(rag)
	if not IsValid(rag) then return end

	rag.zcnpc_headkill = true
	rag.DMS_IsHeadshot = false

	local org = rag.organism
	if org then
		org.brain = 1
		org.shock = math.max(org.shock or 0, 100)
		org.otrub = true
	end

	if ZCNPC.ActiveOff then ZCNPC.ActiveOff(rag) end
	if ZCNPC.EeerLetFall then ZCNPC.EeerLetFall(rag) end
end

local function FinishHeadKill(rag, force, gib)
	if not IsValid(rag) then return end

	-- Once per body, and the flag goes up before any of the work rather than
	-- after. BeheadBody keeps second callers off with zcnpc_deferredkill, and the
	-- first thing this used to do was clear it - so anything reached from inside the
	-- beheading that came back round through BeheadBody found the door open again
	-- and booked a second pass over a body already halfway through its first.
	if rag.zcnpc_headfinished then return end
	rag.zcnpc_headfinished = true

	rag.zcnpc_deferredkill = nil

	-- Fatal Headshot is held off while this addon is running (sv_artagdoll.lua).
	rag.DMS_IsHeadshot = false

	-- Head off before the body is declared dead, so nothing still animating treats
	-- a stump as a man with a chest wound. Gore force is zeroed: SpawnMeatGore
	-- only needs a direction for the chunks, and feeding it the bullet force is
	-- how the stump used to inherit a truck hit.
	--
	-- Metrocops: gib was earned while upright but HeadGibAllowed blocks it until
	-- the body is on the floor — which is exactly where we are now.
	if gib and (not ZCNPC.IsMetrocop(rag) or ZCNPC.IsDownedBody(rag)) then
		ZCNPC.GibHead(rag, vector_origin)
	end

	if ZCNPC.WatchBody then ZCNPC.WatchBody(rag, 5) end

	-- No death throe on a headshot: ActiveOff + KillDowned leaves a limp corpse.
	-- That is the whole point of the delay - the fall already happened.
	LimpHeadshot(rag)
	if ZCNPC.ActiveDie then ZCNPC.ActiveDie(rag) end

	local info = ZCNPC.Downed[rag]
	if info then ZCNPC.KillDowned(rag, info) end
end

function ZCNPC.BeheadBody(rag, force, gib)
	if not IsValid(rag) then return end

	LimpHeadshot(rag)
	BulkHead(rag)

	-- already waiting on an earlier pellet from the same shot
	if (rag.zcnpc_deferredkill or 0) > CurTime() then
		rag.zcnpc_pendinggib = rag.zcnpc_pendinggib or gib
		if force then rag.zcnpc_headforce = force end

		return
	end

	rag.zcnpc_deferredkill = CurTime() + HEAD_KILL_DELAY
	rag.zcnpc_pendinggib = gib
	if force then rag.zcnpc_headforce = force end

	ZCNPC.HeadshotSound(rag, false)

	timer.Simple(HEAD_KILL_DELAY, function()
		if not IsValid(rag) then return end

		FinishHeadKill(rag, rag.zcnpc_headforce or force, rag.zcnpc_pendinggib)
	end)
end

function ZCNPC.HeadshotKill(npc, force, gib)
	if not IsValid(npc) then return end

	-- Latch before MakeUnconscious: blocks engine death, ArtAgdoll DMS_IsHeadshot
	-- corpses, and CreateNPCRagdoll copying bullet-inflated NPC velocity.
	HoldStandingHeadshot(npc)

	-- If a knockdown doll already exists, kill its active ragdoll before the
	-- headshot hand-over - otherwise it can wake into the kill.
	if IsValid(npc.zcnpc_rag) then LimpHeadshot(npc.zcnpc_rag) end

	-- No kill shove. Writing the bullet force onto every bone was the launch with
	-- ArtAgdoll off - the body just goes limp where it stood. Spawn velocity is
	-- clamped inside CreateNPCRagdoll when zcnpc_headkill is set.
	-- Guarded, because everything below the hold depends on getting here. An error
	-- thrown inside the knockdown - a bad model, another addon's hook on the way
	-- down - used to leave the function with the flag still on and nothing left that
	-- would ever take it off, and that NPC stood there unkillable. Now it is the same
	-- outcome as no ragdoll at all, which is the case immediately below.
	local rag = IsValid(npc.zcnpc_rag) and npc.zcnpc_rag or nil

	if not rag then
		local ok, made = pcall(ZCNPC.MakeUnconscious, npc, nil, nil)

		if ok then
			rag = made
		else
			ErrorNoHalt("[zcnpc] head shot knockdown failed: " .. tostring(made) .. "\n")
		end
	end

	if not IsValid(rag) then
		-- Nothing to hand the hold over to: no ragdoll physics on this model, or an
		-- organism that stopped being one underneath us. Let go before the kill and
		-- not after - the kill is a plain engine kill and the hold is GODMODE, so
		-- this order is the difference between a dead NPC and one that stands there
		-- immune to everything for the rest of the round.
		ZCNPC.ReleaseHeadHold(npc, true)
		EngineKill(npc)

		return
	end

	LimpHeadshot(rag)
	BulkHead(rag)
	ZCNPC.BeheadBody(rag, force, gib)
end

-- Z-City runs "PreHomigradDamage" before the organs take their share and
-- "HomigradDamage" after (sv_input.lua:610 and 888), so the difference between the
-- two is exactly what this one hit reached. Reading the organs on their own would
-- not do: the damage slowly heals itself (sv_organism.lua:627), so a value left
-- over from an earlier hit drifts out from under us.
--
-- Four boxes sit on the head bone (sh_hitboxorgans_manual.lua:9): two around the
-- braincase feeding org.skull, the jaw in front of them, and the brain inside.
-- Their damage is what says "this round went into the head", and it says it the
-- same way whether the target is standing or lying down - unlike the hitgroup,
-- which is read off a physics bone a standing NPC does not have.
--
-- A helmet is an organ on that same bone and it is what cuts the trace short of
-- the three (sv_equipment.lua:321), so anything that did reach them is already
-- past the helmet.
local headOrgans = { "brain", "skull", "jaw" }
local BULLET = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER
local MELEE = DMG_CLUB + DMG_SLASH
local HEAD_SLOTS = { "head", "face" }

-- Helmets live on armors.head; welding / ballistic masks on armors.face. Both
-- are organ hitboxes that cut the trace short (sv_equipment.lua protec). Counting
-- only .head made a Welding Mask (mask3) look like a bare head to our lethal
-- headshot path — a gas pistol to the mask still set brain = 1 and beheaded.
function ZCNPC.HeadProtected(ent)
	if not IsValid(ent) then return false end

	local armors = ent.armors
	if not istable(armors) then
		local org = ent.organism
		local owner = org and org.owner
		armors = IsValid(owner) and owner.armors or nil
	end

	if not (istable(armors) and istable(hg) and istable(hg.armor)) then return false end

	for _, slot in ipairs(HEAD_SLOTS) do
		local piece = armors[slot]
		if not piece then continue end

		local data = hg.armor[slot] and hg.armor[slot][piece]
		if data and (data.protection or 0) > 0 then return true end
	end

	return false
end

local HeadProtected = ZCNPC.HeadProtected

-- Rubber, gas, beanbag. Z-City types these as DMG_CLUB and they still write
-- brain damage — 35/25*3 from an Osa is a full 1 — so the lethal path and
-- ExplodeHead used to treat a non-lethal pistol like a rifle. That is the
-- "shot him in the head with a PB-4 Osa, he lived, then nothing could hurt
-- him": GODMODE went on for a kill that was never supposed to happen.
local NONLETHAL_CLASS = {
	weapon_osapb = true,
	weapon_zoraki = true,
	["weapon_mp-80"] = true,
}

local NONLETHAL_AMMO = {
	["18x45mmtraumatic"] = true,
	["18x45mmflashdefense"] = true,
	[".45rubber"] = true,
	["12/70beanbag"] = true,
}

local function AmmoKey(name)
	if not isstring(name) then return "" end

	return string.lower((string.gsub(name, "%s+", "")))
end

function ZCNPC.IsNonlethalHit(dmgInfo)
	if not dmgInfo then return false end

	local inf = dmgInfo.GetInflictor and dmgInfo:GetInflictor()
	local att = dmgInfo.GetAttacker and dmgInfo:GetAttacker()
	local wep = (IsValid(inf) and inf:IsWeapon() and inf)
		or (IsValid(att) and att.GetActiveWeapon and att:GetActiveWeapon())

	if IsValid(wep) then
		if NONLETHAL_CLASS[wep:GetClass()] then return true end

		local ammo = wep.Primary and wep.Primary.Ammo
		if NONLETHAL_AMMO[AmmoKey(ammo)] then return true end
	end

	if istable(hg) and istable(hg.ammotypes) and isfunction(dmgInfo.GetAmmoType) then
		local id = dmgInfo:GetAmmoType()
		local name = isnumber(id) and id > 0 and game.GetAmmoName(id)
		if NONLETHAL_AMMO[AmmoKey(name)] then return true end
	end

	return false
end

local IsNonlethalHit = ZCNPC.IsNonlethalHit

hook.Add("PreHomigradDamage", "zcnpc_headshot", function(victim, dmgInfo)
	local org = IsValid(victim) and victim.organism
	if not org then return end

	-- Do not call SetupBones here: it is clientside-only. On the server the method
	-- is nil, so the hook errored on every shot, skipped zcnpc_prehead / lethal
	-- hold, and the NPC died via engine HP — corpse with no Armor NetVar, so worn
	-- pieces vanished instead of transferring to the ragdoll.

	-- Z-City's protec() turns a stopped bullet into DMG_CLUB mid-trace. Remember
	-- what arrived so HomigradDamage can tell "armour ate it" from a real club.
	org.zcnpc_wasbullet = istable(dmgInfo) and dmgInfo.IsDamageType and dmgInfo:IsDamageType(BULLET) or false

	local before = org.zcnpc_prehead or {}
	for _, organ in ipairs(headOrgans) do before[organ] = org[organ] or 0 end

	org.zcnpc_prehead = before
end)

-- Readable once. The snapshot is dropped on the way out so that a hit which
-- never ran a "PreHomigradDamage" of its own - a ragdoll landing on its head
-- goes straight to "HomigradDamage" (sv_input.lua:1499) - cannot read a stale
-- one and pass itself off as a shot to the head.
local function HeadHit(org)
	local before = org.zcnpc_prehead
	org.zcnpc_prehead = nil

	if not before then return false, false end

	local brain = org.brain or 0
	local bone = (org.skull or 0) > before.skull or (org.jaw or 0) > before.jaw

	return brain > before.brain, bone, brain
end

function ZCNPC.ClampedForce(dmgInfo)
	local force = dmgInfo:GetDamageForce()
	local len = force:Length()

	return len > 2500 and force / len * 2500 or force
end

local ClampedForce = ZCNPC.ClampedForce

-- Whether the round that just killed this head also takes it off. The kinetic
-- stack is readable right now, during the hit that filled it, and a frame later
-- it is gone (sv_input.lua:1034).
--
-- ZCNPC.HeadGibAllowed lets an empty stack through, because a beheading with no
-- round behind it - the limb tool, a Fury syringe - has nothing to measure
-- against the threshold. Here there is a round, so an empty stack is not
-- "unmeasurable", it is "barely registered", and the head stays on.
-- Threshold only. Metrocop "must be on the floor" is enforced in HeadGibAllowed /
-- FinishHeadKill: a standing headshot still earns a gib, and the head comes off
-- once the body is down (HEAD_KILL_DELAY), not while they are upright.
local function GibsHead(ent, org)
	if not cfg.headgib:GetBool() then return false end

	local stack = ZCNPC.HeadStack(ent, org)
	if not (stack ~= nil and stack > cfg.headgib_damage:GetFloat()) then return false end
	if ZCNPC.GibWeaponAllowed and not ZCNPC.GibWeaponAllowed(ent, org) then return false end

	return true
end

hook.Add("HomigradDamage", "zcnpc_headshot", function(victim, dmgInfo)
	if not (ZCNPC.Enabled() and IsValid(victim)) then return end

	local org = victim.organism
	if not org or org.alive == false then return end

	local npc = victim:IsNPC()
	local body = victim.zcnpc_npcbody and victim:IsRagdoll()

	if not (npc or body) then return end

	-- taken whether or not this particular pellet reached the brain: the head's
	-- kinetic total is a separate thing from brain damage and it is only readable
	-- here, during the hit that filled it
	ZCNPC.RememberHeadDamage(victim, org, dmgInfo)

	if IsNonlethalHit(dmgInfo) then
		org.zcnpc_nonlethal = CurTime() + 0.35
	end

	-- read before anything can return: leaving the snapshot behind would let the
	-- next hit that arrives without a "PreHomigradDamage" of its own pick it up
	local brainHit, boneHit, brain = HeadHit(org)

	if npc and IsValid(victim.zcnpc_rag) then return end -- the body on the ground takes the hits

	local protected = HeadProtected(victim)
	-- protec() converts a stopped round to DMG_CLUB. That is not a crowbar: do
	-- not treat it as melee-to-the-head, and do not let the NPC 3x kinetic stack
	-- turn a rubber slug on a Welding Mask into ExplodeHead.
	local armorStop = org.zcnpc_wasbullet and not dmgInfo:IsDamageType(BULLET) and protected

	local meleeHead = false
	if npc and not armorStop and cfg.melee_headdown:GetBool()
		and dmgInfo:IsDamageType(MELEE) and not ZCNPC.IsLegKick(dmgInfo) then
		if brainHit or boneHit then
			meleeHead = true
		elseif victim.LastHitGroup and victim:LastHitGroup() == HITGROUP_HEAD then
			meleeHead = true
		else
			local pos = dmgInfo:GetDamagePosition()
			local bone = victim:LookupBone(HEAD_BONE)
			local headPos = bone and victim:GetBonePosition(bone)
			if isvector(pos) and isvector(headPos) and pos:DistToSqr(headPos) < 22 * 22 then
				meleeHead = true
			end
		end
	end

	if meleeHead then
		org.zcnpc_meleehead = CurTime() + 0.35
		if IsNonlethalHit(dmgInfo) then org.zcnpc_nonlethal = CurTime() + 0.35 end
		if (org.brain or 0) > 0.7 then org.brain = 0.7 end
		if (org.skull or 0) > 0.7 then org.skull = 0.7 end
		org.shock = math.min(org.shock or 0, 45)
		StarveHeadPunch(dmgInfo)
		dmgInfo:SetDamage(math.min(dmgInfo:GetDamage(), 8))

		local inflictor = dmgInfo:GetInflictor()
		local class = IsValid(inflictor) and inflictor:GetClass()
		local fists = class == "weapon_hands_sh" or class == "weapon_hg_coolhands"
		if not fists or (victim.zcnpc_nextFistFloor or 0) <= CurTime() and math.random(4) == 1 then
			if fists then victim.zcnpc_nextFistFloor = CurTime() + 8 end
			ZCNPC.Debug("melee to the head on", victim)
			timer.Simple(0, function()
				if IsValid(victim) then ZCNPC.Floor(victim) end
			end)
		end

		return
	end

	if not (brainHit or boneHit) then return end

	-- A rubber / gas round to the head floors them. It does not finish the
	-- brain or put GODMODE on. The organ handler can still write brain = 1
	-- off a 35-damage Osa slug; put that back under the line a head dies on.
	if IsNonlethalHit(dmgInfo) then
		org.zcnpc_nonlethal = CurTime() + 0.35
		if (org.brain or 0) > 0.7 then org.brain = 0.7 end
		if (org.skull or 0) > 0.7 then org.skull = 0.7 end
		StarveHeadPunch(dmgInfo)

		if npc then
			timer.Simple(0, function()
				if IsValid(victim) then ZCNPC.Floor(victim) end
			end)
		end

		return
	end

	if armorStop then
		org.zcnpc_armorstop = CurTime() + 0.15
		-- dmgstack is written after HomigradDamage returns (sv_input.lua:935)
		timer.Simple(0, function()
			if istable(org) then org.dmgstack = {} end
		end)
	end

	-- remembered for the corpse: an engine kill still has to know the last thing
	-- that hit this body was a head shot
	victim.zcnpc_headwound = CurTime() + 0.5
	victim.zcnpc_headforce = ClampedForce(dmgInfo)

	-- One round, one dead head. Z-City only ever gets there by arithmetic, and a
	-- weak round falls short of every part of it: the brain takes damage/25*3
	-- (modules_input/sv_organs.lua:9) and has to reach a full 1 to be fatal, while
	-- the skull it came through has already eaten a share of the round on the way
	-- in (modules_input/sv_bone.lua:26). A pistol lands just under, the damage
	-- heals off over the next minute, and the NPC gets up again with a bullet
	-- through its brain - which is the "they survive having their brains blown
	-- out" this switch is here to end. The kinetic stack that takes a head clean
	-- off is a far higher bar again, and stays where it was.
	--
	-- Head armour (helmet or face mask with protection) is still armour: a hit
	-- that only cracked the skull under one goes back to being worth what Z-City
	-- says it is worth. Past the plate and into the brain there is nothing left
	-- to protect. A stopped round (armorStop) is never lethal here.
	-- instakill_head used to gate this whole block and defaulted off, which is
	-- the "latest update broke headshots — only a knockout unless the head is
	-- destroyed" report. A bare-head hit or a round that reached the brain is
	-- the end of that head. The convar only still holds ExplodeHead off a
	-- living one (kinetic stack vs beheading), not whether they die.
	if not armorStop and not IsNonlethalHit(dmgInfo) and dmgInfo:IsDamageType(BULLET)
		and (brainHit or not protected) then
		-- a shotgun puts eight pellets through a head in one shot and each of them
		-- arrives here separately, all of them while the kill is still a frame away
		if victim.zcnpc_headkill then
			-- later pellets still punch the head after this hook; keep it heavy and
			-- starve each leftover ApplyForceCenter / engine HP tick the same way.
			-- A standing NPC with the mark and no body is a kill that did not
			-- arrive. Swallow only while the hand-over is still live. After that
			-- the mark used to zero every later head shot forever — that is the
			-- rare "nothing can hurt them" after a headshot that never laid them
			-- down.
			if npc and not IsValid(victim.zcnpc_rag) then
				if (victim.zcnpc_headhold or 0) > CurTime() then
					StarveHeadPunch(dmgInfo)
					dmgInfo:SetDamage(0)

					return
				end

				victim.zcnpc_headkill = nil
				ZCNPC.ReleaseHeadHold(victim)
			else
				if body then BulkHead(victim) end
				if npc then HoldStandingHeadshot(victim, dmgInfo) else StarveHeadPunch(dmgInfo) end

				return
			end
		end

		-- what the rest of the mod reads to mean the head is finished: the shock
		-- that keeps the body down, and a brain with nothing left of it
		org.shock = 100
		org.brain = 1

		-- Standing: zero engine HP + force before EntityTakeDamage returns, or the
		-- NPC dies for real and ArtAgdoll gets a DMS_IsHeadshot corpse. Downed:
		-- starve the ragdoll punch and limp ArtAgdoll immediately.
		if npc then
			HoldStandingHeadshot(victim, dmgInfo)
		else
			victim.zcnpc_headkill = true
			StarveHeadPunch(dmgInfo)
			BulkHead(victim)
			LimpHeadshot(victim)
		end

		ZCNPC.Debug("lethal head shot on", victim)

		-- deferred for the same reason as the knockout below. Whether the head
		-- comes off is settled here rather than above, because the pellets that
		-- were turned away by the guard still went through RememberHeadDamage on
		-- their way past - all eight of them count towards the threshold, not just
		-- the first one to arrive.
		timer.Simple(0, function()
			if not IsValid(victim) then return end

			local force, gib = victim.zcnpc_headforce, GibsHead(victim, victim.organism)

			if victim:IsNPC() then
				ZCNPC.HeadshotKill(victim, force, gib)
			else
				ZCNPC.BeheadBody(victim, force, gib)
			end
		end)

		return
	end

	-- Being switched off by a hit is the one thing a bullet may still do to something
	-- that is still awake, and a head is the only place it may do it from: everywhere
	-- else the pain of being shot no longer reaches that far (sv_conscious.lua). Into
	-- the brain it is not luck and never was - anything that reaches the part the
	-- thinking runs on drops whoever was doing the thinking, and that is not a
	-- switch, it is what a brain is. Short of the brain - a cracked skull, which is
	-- what a helmet leaves of a head shot - it is one roll of zcnpc_headshot_ko, and
	-- losing that roll is what leaves the crowbar below something to do.
	local out = ZCNPC.HeadKnockout(org, brainHit)

	if out then
		ZCNPC.Debug("head shot knockout on", victim, "brain", brain)

		-- a body is already on the floor, and what it was short of was a reason to
		-- stay there. The shock HeadKnockout leaves behind is that reason.
		if not npc then return end

		-- deferred: this runs inside Z-City's damage handling, which is itself called
		-- from the "Org Think" walk over hg.organism.list, and going down writes to
		-- that table.
		-- The head itself is not touched here - Z-City's kinetic stack decides that,
		-- and it goes through our hg.ExplodeHead wrapper below.
		timer.Simple(0, function()
			if IsValid(victim) then ZCNPC.MakeUnconscious(victim) end
		end)

		return
	end

	if not npc then return end
end)

-- A chest shot that somehow wrote brain = 1 (a heart hit, a misfired head
-- hitbox, the old forced path) is the "two rounds in the ribs and they drop
-- dead" report. With the slider off that write is put back, and the torso is
-- left to bleed and the heart the way Z-City already does for a player.
hook.Add("PreHomigradDamage", "zcnpc_chest_instakill", function(victim, dmgInfo)
	local org = IsValid(victim) and victim.organism
	if not org then return end

	org.zcnpc_prebrain = org.brain or 0
end)

hook.Add("HomigradDamage", "zcnpc_chest_instakill", function(victim, dmgInfo)
	if not (ZCNPC.Enabled() and IsValid(victim) and victim.organism) then return end
	-- Players are Z-City's. Putting this clamp on them is why a frontal
	-- headshot (or a suicide) only knocked the player out: the brain hit
	-- wrote 1, zcnpc_headwound is an NPC flag, and this put it back to 0.85.
	if not (victim:IsNPC() or victim.zcnpc_npcbody) then return end
	if not (cfg.instakill_chest and not cfg.instakill_chest:GetBool()) then return end

	local org = victim.organism
	local before = org.zcnpc_prebrain
	if before == nil then return end
	if (victim.zcnpc_headwound or 0) > CurTime() then return end
	if (org.brain or 0) < 1 then return end
	if before >= 1 then return end

	org.brain = math.min(before + 0.15, 0.85)
	ZCNPC.Debug("chest shot held off a forced brain death on", victim)
end)
--//

--\\ Stock head explosion
-- Z-City fires this as soon as a hitgroup's kinetic stack passes 100, and on a
-- player it is simply lethal: ply:Kill(), head off, done (sv_input.lua:398). On an
-- NPC the same call does two unrelated things - it sets the shock that puts the
-- body down, and then tries to behead a ragdoll it looks up through the
-- "RagdollDeath" net var, which only players ever get (fake/sv_tier_0.lua:449) -
-- so the beheading half quietly does nothing while the shock half is all that
-- lands.
--
-- The wrapper used to return early when the hit was too small for our own gib
-- threshold, and that took the shock with it. A Deagle round to the head fell
-- straight through the gap: strong enough for Z-City to call this at all, too
-- weak for us to behead, and so the NPC walked away from a head shot that would
-- have killed a player outright. A Makarov never reached this code and killed
-- through plain brain damage instead, which is exactly the asymmetry that showed
-- up in game.
--
-- Now the call is always lethal, the same way it is for a player, and
-- zcnpc_headgib_damage only decides whether the head physically comes off.
if not ZCNPC.__origExplodeHead then
	ZCNPC.__origExplodeHead = hg.ExplodeHead

	function hg.ExplodeHead(ent)
		if not (ZCNPC.Enabled() and IsValid(ent)) then return ZCNPC.__origExplodeHead(ent) end

		local org = ZCNPC.ResolveOrganism(ent)
		local ours = (ent:IsNPC() and org ~= nil) or ent.zcnpc_npcbody == true

		if not ours then return ZCNPC.__origExplodeHead(ent) end

		-- Once per body. Z-City compares the kinetic stack against its threshold on
		-- every hit, and once the stack is over it every further hit inside the same
		-- half second is over it too - so a shotgun fired into a face at contact
		-- range reaches this eight times in one tick, once per pellet. Each of those
		-- used to run the whole of it: a ragdoll built, Gib_Input spawning a cap and
		-- its gibs, the particle burst, the constraint sweep. Eight of that inside a
		-- single tick is the point blank buckshot crash.
		if (ent.zcnpc_exploded or 0) > CurTime() then return end

		-- NPC kinetic stacks are multiplied by 3 (sv_input.lua:937). A stopped
		-- rubber / gas-pistol hit on a Welding Mask still lands as CLUB and can
		-- push the head stack over 100 without ever wrecking the brain — players
		-- do not get that mul, so we refuse a beheading unless the brain is gone
		-- or our own lethal headshot path already marked the kill.
		-- org is nil on a body of ours whose organism has already been handed on, and
		-- reading .brain off that nil threw from inside Z-City's damage walk, which
		-- took the rest of the hit with it.
		if org and (org.zcnpc_meleehead or 0) > CurTime() then
			return
		end

		if org and (org.zcnpc_nonlethal or 0) > CurTime() then
			return
		end

		if org and HeadProtected(ent) and (org.brain or 0) < 0.8 and not ent.zcnpc_headkill then
			if (org.zcnpc_armorstop or 0) > CurTime() - 0.2 then
				org.dmgstack = {}
			end

			return
		end

		-- Forced insta-kill is off: Z-City still calls this once the kinetic stack
		-- crosses its own line, and that is a beheading of a living head. Hold it
		-- unless the brain is already gone.
		if org and cfg.instakill_head and not cfg.instakill_head:GetBool()
			and (org.brain or 0) < 1 and not ent.zcnpc_headkill then
			return
		end

		ent.zcnpc_exploded = CurTime() + 0.5

		local gib = ZCNPC.HeadGibAllowed(ent, org)

		if not gib then ZCNPC.Debug("head shot survived the gib threshold on", ent, ZCNPC.HeadStack(ent, org)) end

		if ent:IsNPC() then
			if not org or org.alive == false then return end

			org.shock = 100 -- the one thing the stock call did get right on an NPC
			ZCNPC.HeadKnockout(org, true) -- and exempt from the cap, being a head

			-- Same standing-death trap as HomigradDamage: ExplodeHead can fire from
			-- the dmgstack timer after EntityTakeDamage has already returned, so
			-- GODMODE here is what stops a late engine corpse if HP was already low.
			HoldStandingHeadshot(ent)

			-- deferred: this is reached from inside Z-City's damage handling,
			-- itself called from the "Org Think" walk over hg.organism.list, and
			-- going down mutates that table
			timer.Simple(0, function()
				if IsValid(ent) then ZCNPC.HeadshotKill(ent, ent.zcnpc_headforce, gib) end
			end)

			return
		end

		-- one of our bodies took the hit while it was already on the ground.
		-- ApplyForceCenter has usually already run by the time ExplodeHead is
		-- reached (sv_input.lua:920 then :1004); HomigradDamage should have
		-- starved that punch already. BulkHead + LimpHeadshot cover leftovers.
		BulkHead(ent)
		ZCNPC.BeheadBody(ent, ent.zcnpc_headforce, gib)
	end
end
--//
