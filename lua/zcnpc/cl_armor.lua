--[[
	Draw worn Z-City armour on NPCs and their bodies.

	Players get RenderArmors from the fake/player render override
	(fake/sh_render.lua). That path never runs for NPCs, and Z-City's drawer
	also bails when shouldTransmit / NotSeen are unset — which is common on
	NPCs that just entered PVS. We force those flags for the draw call and
	reuse DrawArmors when it exists.

	Bodies never hit the NPC RenderOverride, so they draw from a cached host
	set (same idea as cl_headcrab) instead of walking every organism ent
	every frame.
]]

ZCNPC = ZCNPC or {}

-- Ragdolls / corpses that currently need an armour draw. Standing NPCs go
-- through AddPass. Filled by the slow scan below and by ZCNPC_ClientDowned.
ZCNPC.ArmorHosts = ZCNPC.ArmorHosts or {}

local DRAW_DIST_SQR = 2500 * 2500 -- ~63m; armour mesh is not worth beyond that

local function ArmorsOf(ent)
	if not IsValid(ent) then return end

	local net = ent.GetNetVar and ent:GetNetVar("Armor")
	if istable(net) and next(net) ~= nil then return net end

	if istable(ent.armors) and next(ent.armors) ~= nil then return ent.armors end
end

local function HasDrawable(armors)
	if not (istable(armors) and istable(hg) and istable(hg.armor)) then return false end

	for placement, piece in pairs(armors) do
		local data = hg.armor[placement] and hg.armor[placement][piece]
		if data and data.model and data.model ~= "" then return true end
	end

	return false
end

local function InDrawRange(ent)
	local ply = LocalPlayer()
	if not IsValid(ply) then return true end

	return ply:GetPos():DistToSqr(ent:GetPos()) <= DRAW_DIST_SQR
end

-- Stock DrawArmors does a full return when GetBoneMatrix is nil, and also
-- rewrites `ent` through hg.GetCurrentCharacter(ply). For a freshly spawned
-- idle NPC matrices are often nil for a frame; for a ragdoll that has not yet
-- been paired as FakeRagdoll, GetCurrentCharacter points at the hidden husk.
-- Draw onto the mesh we were handed, skip broken slots, keep going.
--
-- keepBones: the NPC RenderOverride already ran SetupBones and may have posed
-- the skeleton (get up). Calling SetupBones again here rebuilt the standing
-- bind pose and wiped that animation — every armoured NPC looked like it
-- snapped upright.
local function DrawArmorPieces(src, armors, mesh, keepBones)
	if not (IsValid(src) and IsValid(mesh) and istable(armors) and istable(hg) and istable(hg.armor)) then
		return
	end

	if not keepBones then
		mesh:SetupBones()
	end

	local fem = isfunction(ThatPlyIsFemale) and ThatPlyIsFemale(mesh) or false

	for placement, armor in pairs(armors) do
		local armorData = hg.armor[placement] and hg.armor[placement][armor]
		if not armorData then continue end
		if not armorData.model or armorData.model == "" then continue end

		src.modelArmor = src.modelArmor or {}

		if not IsValid(src.modelArmor[armor]) then
			local model = ClientsideModel(armorData.model)
			if not IsValid(model) then continue end

			model:SetNoDraw(true)
			model:SetModelScale((fem and armorData.femscale) or armorData.scale or 1)

			local fallbackMat = istable(armorData.material) and armorData.material[1] or armorData.material
			local matName = src:GetNWString("ArmorMaterials" .. armor, "")
			if matName == "" and IsValid(mesh) and mesh ~= src then
				matName = mesh:GetNWString("ArmorMaterials" .. armor, fallbackMat)
			else
				matName = matName ~= "" and matName or fallbackMat
			end

			if matName then
				model.materialset = matName
				model:SetSubMaterial(0, matName)
			end

			local skin = src:GetNWInt("ArmorSkins" .. armor, -1)
			if skin < 0 and mesh ~= src then skin = mesh:GetNWInt("ArmorSkins" .. armor, 0) end
			if skin < 0 then skin = 0 end
			model:SetSkin(skin)

			if not armorData.nobonemerge then
				model:AddEffects(EF_BONEMERGE)
			end

			src.modelArmor[armor] = model

			src:CallOnRemove("zcnpc_removearmor_" .. placement, function()
				if IsValid(model) then model:Remove() end
				if src.modelArmor then src.modelArmor[armor] = nil end
			end)
		end

		local model = src.modelArmor[armor]
		if not IsValid(model) then continue end

		local boneName = armorData.bone
		local bone = boneName and mesh:LookupBone(boneName)
		if not bone then continue end

		local matrix = mesh:GetBoneMatrix(bone)
		if not matrix then continue end

		local bonePos, boneAng = matrix:GetTranslation(), matrix:GetAngles()
		local femPos = armorData.femPos
		if fem and isvector(femPos) then
			bonePos:Add(boneAng:Forward() * femPos[1] + boneAng:Up() * femPos[2] + boneAng:Right() * femPos[3])
		end

		local pos, ang = LocalToWorld(armorData[3], armorData[4], bonePos, boneAng)
		model:SetRenderOrigin(pos)
		model:SetRenderAngles(ang)
		model:SetParent(mesh, bone)
		model:DrawModel()
	end
end

-- keepBones: do not rebuild the skeleton (see DrawArmorPieces).
function ZCNPC.DrawArmor(ent, owner, keepBones)
	if not IsValid(ent) then return end

	owner = IsValid(owner) and owner or ent
	if owner.GetNetVar and owner:GetNetVar("HideArmorRender", false) then return end
	if ent.GetNetVar and ent:GetNetVar("HideArmorRender", false) then return end

	local armors = ArmorsOf(ent) or ArmorsOf(owner)
	if not HasDrawable(armors) then return end

	-- Keep DrawArmors happy if something else still calls it, and keep our own
	-- path from being gated by a stale PVS flag on a body we are already drawing.
	local tEnt, nEnt = ent.shouldTransmit, ent.NotSeen
	local tOwn, nOwn = owner.shouldTransmit, owner.NotSeen
	ent.shouldTransmit, ent.NotSeen = true, false
	owner.shouldTransmit, owner.NotSeen = true, false

	-- Point GetCurrentCharacter at the visible mesh for any stock code path.
	local hadFake = owner.FakeRagdoll
	if not isentity(hadFake) then hadFake = nil end
	if ent:IsRagdoll() and owner ~= ent then
		owner.FakeRagdoll = ent
	end

	DrawArmorPieces(owner, armors, ent, keepBones)

	owner.FakeRagdoll = hadFake
	ent.shouldTransmit, ent.NotSeen = tEnt, nEnt
	owner.shouldTransmit, owner.NotSeen = tOwn, nOwn
end

ZCNPC.AddPass(35, "armor", function(npc)
	-- Same reason the gun is hidden: armour is parented to standing bones while
	-- the body is still on the floor in the get up pose.
	if ZCNPC.IsGettingUp and ZCNPC.IsGettingUp(npc) then return false end

	return HasDrawable(ArmorsOf(npc))
end, function(npc)
	ZCNPC.DrawArmor(npc, npc, true)
end)

local function TrackBody(rag, owner)
	if not IsValid(rag) or not rag:IsRagdoll() then return end

	local src = IsValid(owner) and owner or rag
	if HasDrawable(ArmorsOf(rag) or ArmorsOf(src)) then
		ZCNPC.ArmorHosts[rag] = src
	end
end

local function WatchArmorEnt(ent)
	if not IsValid(ent) then return end

	if ent:IsNPC() and HasDrawable(ArmorsOf(ent)) and ZCNPC.WatchRender then
		ZCNPC.WatchRender(ent)
	elseif ent:IsRagdoll() then
		TrackBody(ent, ent.zcnpc_npc)
	end
end

-- Armour NetVar is broadcast; install the draw path the moment it lands, without
-- waiting for organism_ents / the 0.2s render timer.
hook.Add("OnNetVarSet", "zcnpc_armor_render", function(index, key, var)
	if key ~= "Armor" then return end
	if not istable(var) then return end

	timer.Simple(0, function()
		WatchArmorEnt(Entity(index))
	end)

	-- ArmorVarSet rebuilds modelArmor after 0.1s; re-assert the override after that.
	timer.Simple(0.15, function()
		WatchArmorEnt(Entity(index))
	end)
end)

hook.Add("ZCNPC_ClientDowned", "zcnpc_armor", function(npc, rag)
	-- Immediate track: do not wait for the 0.35s scan or the body looks naked
	-- for a few frames after the ragdoll appears.
	TrackBody(rag, npc)
end)

hook.Add("ZCNPC_ClientWokeUp", "zcnpc_armor", function(npc, rag)
	if IsValid(rag) then ZCNPC.ArmorHosts[rag] = nil end
	if IsValid(npc) and HasDrawable(ArmorsOf(npc)) and ZCNPC.WatchRender then
		ZCNPC.WatchRender(npc)
	end
end)

-- Slow scan: build the draw set. Armour changes are rare vs frame rate.
timer.Create("zcnpc_armor_scan", 0.35, 0, function()
	local hosts = ZCNPC.ArmorHosts
	for rag in pairs(hosts) do
		if not IsValid(rag) then
			hosts[rag] = nil
		else
			local owner = hosts[rag]
			local src = IsValid(owner) and owner or rag
			if not HasDrawable(ArmorsOf(rag) or ArmorsOf(src)) then
				hosts[rag] = nil
			end
		end
	end

	for npc, rag in pairs(ZCNPC.Bodies or {}) do
		TrackBody(rag, npc)
		if IsValid(npc) and HasDrawable(ArmorsOf(npc)) and ZCNPC.WatchRender then
			ZCNPC.WatchRender(npc)
		end
	end

	if not (istable(hg) and istable(hg.organism_ents)) then return end

	for ent in pairs(hg.organism_ents) do
		if not IsValid(ent) then continue end

		if ent:IsNPC() and HasDrawable(ArmorsOf(ent)) and ZCNPC.WatchRender then
			ZCNPC.WatchRender(ent)
		elseif ent:IsRagdoll() and (ent.zcnpc_npcbody or ent.zcnpc_corpse) and not hosts[ent] then
			TrackBody(ent, ent.zcnpc_npc)
		end
	end
end)

hook.Add("PostDrawOpaqueRenderables", "zcnpc_armor", function(_, skybox)
	if skybox then return end

	local hosts = ZCNPC.ArmorHosts
	if not next(hosts) then return end

	for rag, owner in pairs(hosts) do
		if not IsValid(rag) then
			hosts[rag] = nil
			continue
		end

		if rag:IsDormant() or not InDrawRange(rag) then continue end

		ZCNPC.DrawArmor(rag, IsValid(owner) and owner or rag)
	end
end)
