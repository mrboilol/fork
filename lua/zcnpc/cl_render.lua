--[[
	Rendering managed NPCs.

	Z-City draws players and ragdolls through hg.renderOverride, and everything
	that is "on top of" the animation - hidden amputated limbs, gore caps,
	bandages, the handcuffed pose - lives in there (sh_utility.lua:635,
	fake/sh_render.lua:57). NPCs never get that treatment, which is why an NPC
	that lost an arm on the ground grows it back the moment it stands up: the
	organism still says the limb is gone, nothing hides it.

	So managed NPCs get their own render override with the pieces that make
	sense for them. It is installed only while there is actually something to
	draw (amputation, handcuffs, get up) so untouched NPCs render the stock way.
]]

ZCNPC = ZCNPC or {}

local Pose = ZCNPC.Pose
local BONE = ZCNPC.Bone

ZCNPC.Passes = ZCNPC.Passes or {} -- { order, name, needs(npc), draw(npc) }, lowest order first

function ZCNPC.AddPass(order, name, needs, draw)
	for _, pass in ipairs(ZCNPC.Passes) do
		if pass.name == name then
			pass.order, pass.needs, pass.draw = order, needs, draw

			table.SortByMember(ZCNPC.Passes, "order", true)

			return
		end
	end

	ZCNPC.Passes[#ZCNPC.Passes + 1] = { order = order, name = name, needs = needs, draw = draw }

	table.SortByMember(ZCNPC.Passes, "order", true)
end

--\\ Holding one back
-- There is a moment on the way out of a body when the NPC is standing at the spot
-- it is about to get up on and the animation that puts it there has not started
-- yet: the server has to show the entity before it can tell anybody what to do
-- with it. Drawn as it is, that is the NPC standing to attention next to its own
-- corpse for a frame or two, which is the flicker at the start of getting up.
--
-- So it can be told to draw nothing at all for a moment. Short, and with a time
-- limit rather than a promise to be switched off again, because the thing that
-- would switch it off is the thing that might not arrive.
local held = {}

function ZCNPC.HoldDraw(ent, seconds)
	if not IsValid(ent) then return end

	held[ent] = CurTime() + seconds

	-- force: get-up grace has to own the draw path or the NPC flashes standing
	if ent:IsNPC() then ZCNPC.InstallRender(ent, true) end
end

function ZCNPC.ReleaseDraw(ent)
	held[ent] = nil
end

local function Held(ent)
	local till = held[ent]
	if not till then return false end
	if till > CurTime() then return true end

	held[ent] = nil

	return false
end
--//

--\\ Where the bones actually are
-- A pose written on with SetBoneMatrix lasts until somebody calls SetupBones, and it is not
-- an animation: nothing outside the draw that wrote it knows it happened. That matters
-- because of what else reads an NPC's bones - a weapon working out where the hand is, every
-- frame, from its own entry in the render list (cl_weapon.lua, cl_medicine.lua). Ask for the
-- bones the ordinary way there and the answer is the animation underneath, so a rebel knelt
-- over a body holds its rifle up at the height it was standing at.
--
-- So a pass that poses an NPC says so, and anything that needs a bone off one asks through
-- here instead. Kept as the pose table itself rather than a copy: it is the same table the
-- pass reuses every frame (cl_loot.lua), and re-applying it is what puts the bones back
-- where that pass had them.
-- And the ones it happened to this frame, so whatever has to draw on top of a pose can find
-- them without walking every NPC on the map. Weak keys: an NPC that is gone is gone, and the
-- one thing that reads this clears its own entries as they stop being posed (cl_weapon.lua).
ZCNPC.Posed = setmetatable({}, { __mode = "k" })

function ZCNPC.MarkPosed(npc, pose)
	npc.zcnpc_posed = pose
	npc.zcnpc_posedframe = FrameNumber()
	ZCNPC.Posed[npc] = true
end

-- True when the answer is a pose of ours rather than the animation. The frame number is the
-- whole of the test: a pose is only ever the truth for the frame it was written in, and an
-- NPC that has gone off screen since is one nobody posed this frame.
function ZCNPC.ReadBones(ent)
	if not IsValid(ent) then return false end

	local pose = ent.zcnpc_posed

	if istable(pose) and ent.zcnpc_posedframe == FrameNumber() then
		Pose.Apply(ent, pose)

		return true
	end

	ent:SetupBones()

	return false
end

-- The right hand as that pass left it, for the two things that want the one bone rather than
-- all of them.
function ZCNPC.PosedHand(npc)
	if not (IsValid(npc) and istable(npc.zcnpc_posed)) then return end
	if npc.zcnpc_posedframe ~= FrameNumber() then return end

	-- Kept on the NPC. A bone id never changes for a model and this is read from a
	-- draw, so looking the name up again every frame was hashing a string to be told
	-- the same number as last time. `false` is a model with no right hand, which is
	-- an answer worth remembering too.
	local bone = npc.zcnpc_handbone

	if bone == nil then
		bone = npc:LookupBone("ValveBiped.Bip01_R_Hand") or false
		npc.zcnpc_handbone = bone
	end

	return bone and npc.zcnpc_posed[bone] or nil
end
--//

--\\ The override itself
local function Draw(npc, flags)
	if bit.band(flags, STUDIO_RENDER) ~= STUDIO_RENDER then return end
	if Held(npc) then return end

	npc:SetupBones()

	-- Cleared before the passes rather than after them: a pass that poses is the thing that
	-- sets it, and one that stopped posing this frame must not leave last frame's answer
	-- standing for the weapon to read.
	npc.zcnpc_posed = nil

	for _, pass in ipairs(ZCNPC.Passes) do
		if pass.needs(npc) then pass.draw(npc) end
	end

	npc:DrawModel()
end

-- force: take the model even when something else already set RenderOverride.
-- Get-up needs our Draw pass or the motion capture never reaches the bones and
-- the NPC just pops upright after HoldDraw expires.
function ZCNPC.InstallRender(npc, force)
	-- Players go through hg.renderOverride, which hides the head in first
	-- person. This Draw path does not. organism_ents lists both, and a
	-- player with armour / cuffs / a leftover amputation flag used to
	-- land here on spawn — you saw your own head until you ragdolled.
	if not (IsValid(npc) and npc:IsNPC()) then return false end
	if npc.zcnpc_render then return true end
	if npc.RenderOverride and not force then return false end -- somebody else owns the model

	if force and npc.RenderOverride and npc.RenderOverride ~= Draw then
		npc.zcnpc_render_prev = npc.RenderOverride
	end

	npc.zcnpc_render = true
	npc.RenderOverride = Draw

	return true
end

function ZCNPC.RemoveRender(npc)
	if not npc.zcnpc_render then return end

	npc.zcnpc_render = nil

	if npc.RenderOverride == Draw then
		npc.RenderOverride = npc.zcnpc_render_prev
	end

	npc.zcnpc_render_prev = nil
end

local function Wanted(npc)
	if Held(npc) then return true end

	for _, pass in ipairs(ZCNPC.Passes) do
		if pass.needs(npc) then return true end
	end

	return false
end

-- NPCs that need a render override before (or without) an organism_send packet.
-- Armour NetVar is broadcast; organism bareinfo is PVS-only — without this set,
-- a kitted rebel stands naked until the first organism tick / first step.
ZCNPC.RenderNPCs = ZCNPC.RenderNPCs or {}

function ZCNPC.WatchRender(npc)
	if not IsValid(npc) or not npc:IsNPC() then return end

	ZCNPC.RenderNPCs[npc] = true
	if Wanted(npc) then ZCNPC.InstallRender(npc) end
end

local function RefreshRender(npc)
	if not IsValid(npc) or not npc:IsNPC() then
		ZCNPC.RenderNPCs[npc] = nil

		return
	end

	if Wanted(npc) then
		ZCNPC.InstallRender(npc)
	else
		ZCNPC.RemoveRender(npc)
		ZCNPC.RenderNPCs[npc] = nil
	end
end

-- hg.organism_ents collects every NPC the server ever sent an organism for
-- (cl_statistics.lua:11). RenderNPCs covers armour that arrived earlier.
timer.Create("zcnpc_render", 0.2, 0, function()
	local seen = {}

	if istable(hg) and istable(hg.organism_ents) then
		for npc in pairs(hg.organism_ents) do
			if not (IsValid(npc) and npc:IsNPC()) then continue end

			seen[npc] = true
			RefreshRender(npc)
		end
	end

	for npc in pairs(ZCNPC.RenderNPCs) do
		if seen[npc] then continue end

		if not IsValid(npc) then
			ZCNPC.RenderNPCs[npc] = nil
			continue
		end

		RefreshRender(npc)
	end
end)
--//

--\\ Amputations
-- hg.GoreCalc scales the amputated bone (and everything below it) down to
-- nothing and draws the meat stump in its place - organism/tier_1/cl_main.lua:1004.
-- It only ever reads the organism off the entity it is handed, so an NPC works
-- as its own "player" here.
-- The organism's own field names, written out rather than built. Every one of these
-- used to be a concatenation, five of them per NPC per frame plus five more on every
-- NPC the 0.2s scan looked at, and a concatenation in Lua is a new string and a hash
-- of it - which is a lot of garbage to make in order to ask a question whose answer
-- is no for almost every NPC that has ever been drawn.
local amputations = { "larmamputated", "rarmamputated", "llegamputated", "rlegamputated", "headamputated" }
local amputationCount = #amputations

-- server convars, replicated (sv_config.lua); missing means the server never
-- loaded the addon, in which case there is nothing to draw anyway.
--
-- Held once found. Looking one up by name is a hash into the convar table, and these
-- are asked from inside the render passes - every frame, per NPC - where that is one
-- of the few costs in the whole file big enough to see.
local toggles = {}

local function Toggled(name)
	local cvar = toggles[name]

	if not cvar then
		cvar = GetConVar(name)
		-- Not there yet is not the same as not there at all: a replicated convar
		-- arrives with the connection, so a miss is looked for again rather than
		-- remembered as a miss for the rest of the session.
		if not cvar then return true end

		toggles[name] = cvar
	end

	return cvar:GetBool()
end

-- Not optional. The organism goes on saying the limb is gone whatever is drawn over
-- it, so the off position was never "keep the arm", it was "draw an arm that is not
-- there on a body that cannot use it" - an NPC holding a rifle in a hand it lost,
-- and no way to tell by looking why it will not shoot.
function ZCNPC.IsAmputated(npc)
	-- The organism first. It is a field read and it is nil for every NPC the server
	-- has not sent one for, where the two library checks below are a global lookup
	-- and a type test that answer the same way on every frame of the round.
	local org = npc.new_organism or npc.organism
	if not org then return false end

	for i = 1, amputationCount do
		if org[amputations[i]] then return true end
	end

	return false
end

-- The red ERROR on a stump is the meat chunk itself, not where it sits.
-- Z-City draws models/grub_nugget_small.mdl (cl_main.lua:961) — Episode 2
-- antlion grub. If that pack is not mounted, ClientsideModel still returns
-- a valid entity whose GetModel() is the path you asked for, and the mesh
-- is models/error.mdl. Checking GetModel() for "error" therefore never
-- catches it. Only draw a file that is actually on disk; if none is, hide
-- the limb and leave the stump empty rather than glue an ERROR to it.
local GIB_SCALE = Vector(0.01, 0.01, 0.01)
-- Arms and legs get the watermelon gib and nothing else. headboom is the
-- neck cap (sv_head.lua / cfg.StumpModel) and must not land on a forearm.
-- 1.75 fills an NPC cut; stock 0.4 sits like a pebble on it.
local STUMP_SIZE = 1.75
local STUMP_MODELS = {
	{ path = "models/props_junk/watermelon01_chunk02a.mdl", scale = 0.4 },
	{ path = "models/props_junk/watermelon01_chunk02b.mdl", scale = 0.4 },
}

-- Same tables stock GoreCalc uses (cl_main.lua:964). The earlier walk hung
-- the nugget off GetBoneParent; Z-City measured these numbers against
-- boneIndex - 1, and that is the parent they belong to.
local STUMP_OFF = {
	[1] = {
		["ValveBiped.Bip01_L_Calf"] = { Vector(15.5, 0, 0), Angle(0, 90, 0) },
		["ValveBiped.Bip01_R_Calf"] = { Vector(15.5, 0, 0), Angle(0, 90, 0) },
		["ValveBiped.Bip01_R_Forearm"] = { Vector(11, 0.5, 0.5), Angle(0, 90, 0) },
		["ValveBiped.Bip01_L_Forearm"] = { Vector(11, 0.5, -0.5), Angle(0, 90, 0) },
	},
	[0] = {
		["ValveBiped.Bip01_L_Calf"] = { Vector(17.5, 0, 0), Angle(0, 90, 0) },
		["ValveBiped.Bip01_R_Calf"] = { Vector(17.5, 0, 0), Angle(0, 90, 0) },
		["ValveBiped.Bip01_R_Forearm"] = { Vector(11, 0.5, 0.5), Angle(0, 90, 0) },
		["ValveBiped.Bip01_L_Forearm"] = { Vector(11, 0, -1), Angle(0, 90, 0) },
	},
}

local LIMBS = {
	{ key = "larmamputated", name = "ValveBiped.Bip01_L_Forearm" },
	{ key = "rarmamputated", name = "ValveBiped.Bip01_R_Forearm" },
	{ key = "llegamputated", name = "ValveBiped.Bip01_L_Calf" },
	{ key = "rlegamputated", name = "ValveBiped.Bip01_R_Calf" },
}

local stumpMdl
local nextStumpTry = 0
local grubMissing
local GRUB = "models/grub_nugget_small.mdl"

-- util.IsValidModel, not file.Exists: workshop/GMA content is often invisible
-- to Exists even when ClientsideModel would work. Asked once per try, never
-- from the draw loop itself.
local function ModelOk(path)
	if not isstring(path) or path == "" then return false end

	util.PrecacheModel(path)

	return util.IsValidModel(path)
end

local function GrubMissing()
	if grubMissing ~= nil then return grubMissing end

	grubMissing = not ModelOk(GRUB)

	return grubMissing
end

local function StumpModel()
	if IsValid(stumpMdl) then return stumpMdl end

	local now = CurTime()
	if now < nextStumpTry then return end

	nextStumpTry = now + 2
	stumpMdl = nil

	for i = 1, #STUMP_MODELS do
		local spec = STUMP_MODELS[i]
		if not ModelOk(spec.path) then continue end

		local mdl = ClientsideModel(spec.path)
		if not IsValid(mdl) then continue end

		local got = string.lower(mdl:GetModel() or "")
		if got == "" or got == "models/error.mdl" then
			mdl:Remove()
			continue
		end

		mdl:SetNoDraw(true)
		mdl:SetSubMaterial(0, "models/flesh")
		mdl:SetModelScale((spec.scale or 0.5) * STUMP_SIZE)
		stumpMdl = mdl

		return mdl
	end
end

-- Stock GoreCalc: one bone_apply_matrix. That walk already covers the hand
-- and fingers (cl_bones.lua:71). The extra GetChildBones recursion after
-- the meat-chunk patches ran the same walk once per finger, every frame.
local function HideLimb(ent, bone)
	local mat = ent:GetBoneMatrix(bone)
	if not mat then
		ent:ManipulateBoneScale(bone, GIB_SCALE)

		return
	end

	mat:SetScale(GIB_SCALE)

	if istable(hg) and isfunction(hg.bone_apply_matrix) then
		hg.bone_apply_matrix(ent, bone, mat)
	else
		ent:SetBoneMatrix(bone, mat)
	end
end

local function BoneOf(ent, name)
	local cache = ent.zcnpc_stump_bones
	local cached = cache and cache[name]
	if cached then return cached end

	local bone = ent:LookupBone(name)
	if not bone or bone < 0 then return end

	cache = cache or {}
	cache[name] = bone
	ent.zcnpc_stump_bones = cache

	return bone
end

-- Stock GoreCalc (cl_main.lua:1021): the nugget sits on boneIndex - 1, not
-- GetBoneParent. The offsets below were measured in that frame. A parent
-- fallback puts the same numbers on a different bone and the chunk floats.

local function FemaleOf(ent)
	local cached = ent.zcnpc_stump_fem
	if cached ~= nil then return cached end

	local female = false
	if isfunction(ThatPlyIsFemale) then
		local ok, result = pcall(ThatPlyIsFemale, ent)
		female = ok and result == true
	end

	ent.zcnpc_stump_fem = female

	return female
end

function ZCNPC.GoreCalc(ent, ply)
	if not IsValid(ent) then return end

	local org = ent.new_organism or ent.organism
	if not org then return end

	local stump = StumpModel()
	local offs = STUMP_OFF[FemaleOf(ent) and 1 or 0]

	for i = 1, #LIMBS do
		local limb = LIMBS[i]
		if not org[limb.key] then continue end

		local bone = BoneOf(ent, limb.name)
		if not bone then continue end

		HideLimb(ent, bone)

		local off = IsValid(stump) and offs[limb.name]
		if not off then continue end

		if bone < 1 then continue end

		local parentMat = ent:GetBoneMatrix(bone - 1)
		if not parentMat then continue end

		local pos, ang = LocalToWorld(off[1], off[2], parentMat:GetTranslation(), parentMat:GetAngles())

		stump:SetRenderOrigin(pos)
		stump:SetRenderAngles(ang)
		stump:SetupBones()
		stump:DrawModel()
	end
end

local function OursForGore(ent)
	if not IsValid(ent) then return false end
	if ent.zcnpc_npcbody then return true end
	if ent:IsNPC() then return true end
	if ZCNPC.Downed and ZCNPC.Downed[ent] then return true end

	return false
end

local function InstallGoreWrap()
	if not (istable(hg) and isfunction(hg.GoreCalc)) then return false end
	if ZCNPC.__origGoreCalc then return true end

	ZCNPC.__origGoreCalc = hg.GoreCalc

	function hg.GoreCalc(ent, ply)
		-- Stock always ClientsideModels the Episode 2 grub. If that file is
		-- not here, every stump — player or NPC — is an ERROR. Use ours
		-- on bodies we own, or on NPCs when the grub is missing. Players
		-- stay on stock: that path also hides the viewed head.
		if OursForGore(ent) then
			ZCNPC.GoreCalc(ent, ply)

			return
		end

		if GrubMissing() and not (IsValid(ent) and ent:IsPlayer()) then
			ZCNPC.GoreCalc(ent, ply)

			return
		end

		return ZCNPC.__origGoreCalc(ent, ply)
	end

	return true
end

InstallGoreWrap()
hook.Add("InitPostEntity", "zcnpc_gore", InstallGoreWrap)
hook.Add("HomigradRun", "zcnpc_gore", function()
	timer.Simple(0, InstallGoreWrap)
end)
timer.Create("zcnpc_gore_retry", 1, 0, function()
	if InstallGoreWrap() then timer.Remove("zcnpc_gore_retry") end
end)

ZCNPC.AddPass(20, "gore", ZCNPC.IsAmputated, function(npc)
	ZCNPC.GoreCalc(npc, npc)
end)
--//

--\\ Dressings
-- Bandages and tourniquets are drawn out of the same render override as the gore,
-- and the same way round: hg.RenderBandages bone merges one model over the whole
-- body and switches on a bodygroup per bandaged limb, hg.RenderTourniquets places
-- a separate prop on each tourniquet's bone (weapon_bandage_sh.lua:1077, :977).
-- Both read straight off the entity they are handed, so an NPC stands in for the
-- player they were written for.
--
-- The server hands the list back to the NPC when it gets up (ZCNPC.MoveDressings);
-- until that happened, everything a medic tied on to a body on the floor vanished
-- the moment it stood.
-- Whether anything is tied on at all, first. Nothing is, on almost every NPC that is
-- ever drawn, and it is a field read - so the convar and the two library checks are
-- only paid for by the handful that have actually been treated.
local function Bandaged(npc)
	local worn = npc.bandaged_limbs
	if not (istable(worn) and next(worn) ~= nil) then return false end

	if not Toggled("zcnpc_medical_standing") then return false end

	return istable(hg) and isfunction(hg.RenderBandages)
end

local function Tourniqueted(npc)
	local worn = npc.tourniquets
	if not (istable(worn) and next(worn) ~= nil) then return false end

	if not Toggled("zcnpc_medical_standing") then return false end

	return istable(hg) and isfunction(hg.RenderTourniquets)
end

ZCNPC.AddPass(40, "bandages", Bandaged, function(npc)
	hg.RenderBandages(npc, npc)
end)

ZCNPC.AddPass(41, "tourniquets", Tourniqueted, function(npc)
	hg.RenderTourniquets(npc, npc)
end)
--//

--\\ Handcuffs
-- Z-City poses cuffed players out of weapon_hands_sh: hg.handcuffedhands picks a
-- spot behind the root bone and hg.DragHandsToPos drops both wrists on it
-- (weapon_hands_sh.lua:306, cl_tpik.lua:1689). Neither is reachable here - it
-- needs the player to be holding that SWEP and the arms are then solved by the
-- player-only TPIK code - so the wrists get the same target and a plain two bone
-- IK instead of the solver.
local cuffModel = "models/weapons/spy/w_handcuffs.mdl"
local cuffProp

-- The root bone's own axes: its Up points out of the back, its Right is the
-- model's right. Same offsets Z-City uses on a standing player.
local CUFF_BACK = 6
local CUFF_RIGHT = 2
local HANDS_APART = 3.5
local HAND_ANGLE = { r_ = Angle(90, -15, 180), l_ = Angle(90, 15, 0) }
local ELBOW_OUT = 26
local ELBOW_DOWN = 12

-- Convar first now that it is a held object rather than a lookup by name: a NetVar
-- read is the dearer of the two, and this runs on every NPC on screen every frame.
local function Cuffed(npc)
	return Toggled("zcnpc_cuffs_pose") and npc:GetNetVar("handcuffed", false) == true
end

ZCNPC.AddPass(30, "cuffs", Cuffed, function(npc)
	local root = npc:GetBoneMatrix(0)
	if not root then return end

	local ang = root:GetAngles()
	local base = root:GetTranslation() + ang:Up() * CUFF_BACK + ang:Right() * CUFF_RIGHT
	local norm = ang:Up():Angle()

	for _, side in ipairs({ 1, -1 }) do
		local prefix = side == 1 and "r_" or "l_"

		local shoulder = Pose.Matrix(npc, BONE[prefix .. "upperarm"])
		if not shoulder then continue end

		local target, wrist = LocalToWorld(Vector(0, -HANDS_APART * side, 0), HAND_ANGLE[prefix], base, norm)
		local pole = shoulder:GetTranslation() + ang:Right() * (ELBOW_OUT * side) - vector_up * ELBOW_DOWN

		Pose.SolveLimb(npc, BONE[prefix .. "upperarm"], BONE[prefix .. "forearm"], BONE[prefix .. "hand"], target, pole, wrist)
	end

	-- the cuffs themselves, placed between the wrists exactly the way Z-City
	-- places them on a player (hg.CuffedAnim, weapon_hands_sh.lua:263)
	local rh, lh = Pose.Matrix(npc, BONE.r_hand), Pose.Matrix(npc, BONE.l_hand)
	if not (rh and lh) then return end

	if not IsValid(cuffProp) then
		cuffProp = ClientsideModel(cuffModel, RENDERGROUP_OPAQUE)
		if not IsValid(cuffProp) then return end

		cuffProp:SetNoDraw(true)
	end

	local between = (rh:GetTranslation() - lh:GetTranslation()):Angle()
	between[3] = -rh:GetAngles()[1]

	local pos, cuffAng = LocalToWorld(Vector(-3.5, 0, 0), Angle(0, 0, -90), rh:GetTranslation(), between)

	cuffProp:SetRenderOrigin(pos)
	cuffProp:SetRenderAngles(cuffAng)
	cuffProp:SetupBones()
	cuffProp:DrawModel()
end)
--//

--\\ First-person head
-- Z-City assigns ply.RenderOverride on player_spawn (sh_utility.lua:472).
-- That hook bails when Player(userid) is not valid yet, and our 0.2s scan
-- used to steal the slot in the gap. Either way the local player is drawn
-- with a full-size head until a ragdoll get-up writes the override again.
gameevent.Listen("player_spawn")
local function CityDraw(self, flags)
	if not IsValid(self) or self:IsDormant() then return end

	local pos = self:GetBonePosition(1)
	if not pos or pos:IsEqualTol(self:GetPos(), 0.01) then return end
	if IsValid(self.FakeRagdoll) then return end
	if not (istable(hg) and isfunction(hg.renderOverride)) then return end

	hg.renderOverride(self, self.FakeRagdoll, flags)
end

local function EnsureCityDraw(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	if ply.zcnpc_render then
		ZCNPC.RemoveRender(ply)
	end

	if ply.RenderOverride then return end
	if not (istable(hg) and isfunction(hg.renderOverride)) then return end

	ply.RenderOverride = CityDraw
end

local healUntil = 0

-- Z-City installs the FakeRagdoll NW proxy on PlayerInitialSpawn (server-only)
-- and again on Player Getup. First join never hits either, so the first ragdoll
-- has no follow target and the camera is empty until they stand.
local function EnsureFakeProxy(ply)
	if not IsValid(ply) or ply.zcnpc_fakeproxied then return end

	ply.zcnpc_fakeproxied = true
	hook.Run("Player Getup", ply)
end

local function HealLocalDraw()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	EnsureCityDraw(ply)
	EnsureFakeProxy(ply)
	healUntil = CurTime() + 3
end

hook.Add("player_spawn", "zcnpc_citydraw", function(data)
	local tries = 0

	local function apply()
		local ply = Player(data.userid)
		if not IsValid(ply) then
			tries = tries + 1
			if tries < 15 then timer.Simple(0.1, apply) end

			return
		end

		EnsureCityDraw(ply)
		if ply == LocalPlayer() then
			EnsureFakeProxy(ply)
			healUntil = CurTime() + 3
		end
	end

	timer.Simple(0, apply)
end)

hook.Add("InitPostEntity", "zcnpc_citydraw", function()
	timer.Simple(0, HealLocalDraw)
end)

hook.Add("Think", "zcnpc_citydraw", function()
	if CurTime() > healUntil then return end

	EnsureCityDraw(LocalPlayer())
end)

-- Last resort: if the city draw path is missing, scale the head down so
-- SetupBones still hides it. Leave Z-City's own override alone — GoreCalc
-- resets this to 1 and DrawPlayerRagdoll hides via the bone matrix.
local vecHeadHide = Vector(0.01, 0.01, 0.01)
local tpCvar

hook.Add("PrePlayerDraw", "zcnpc_hidehead", function(ply)
	if ply ~= LocalPlayer() then return end
	if GetViewEntity() ~= ply then return end
	if IsValid(ply.FakeRagdoll) then return end

	if not tpCvar then tpCvar = GetConVar("hg_thirdperson") end
	if tpCvar and tpCvar:GetBool() then return end

	if ply.RenderOverride and not ply.zcnpc_render and ply.RenderOverride ~= CityDraw then
		return
	end

	local bone = ply.zcnpc_headbone
	if bone == nil then
		bone = ply:LookupBone("ValveBiped.Bip01_Head1") or false
		ply.zcnpc_headbone = bone
	end
	if not bone then return end

	if not ply:GetManipulateBoneScale(bone):IsEqualTol(vecHeadHide, 0.01) then
		ply:ManipulateBoneScale(bone, vecHeadHide)
	end
end)
--//
