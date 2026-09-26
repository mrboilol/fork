--[[
	Draw a latched headcrab on NPC bodies.

	Z-City only renders this through the player ragdoll override
	(fake/sh_render.lua → hg.RenderHeadcrab). Our bodies never enter that path,
	so the same ClientsideModel is drawn here off the head bone whenever an NPC
	or one of our ragdolls carries the "headcrab" NetVar.
]]

ZCNPC = ZCNPC or {}

local HEAD_BONE = "ValveBiped.Bip01_Head1"
local OFFSET_POS = Vector(-1, 0, 0)
local OFFSET_ANG = Angle(-90, -90, -20)

-- Hosts we currently draw a crab on. Filled by the slow scan below and by the
-- body-pairing net message; PostDraw only walks this set.
ZCNPC.HeadcrabHosts = ZCNPC.HeadcrabHosts or {}

local function HeadcrabModel(ent)
	local model = ent:GetNetVar("headcrab")
	if not isstring(model) or model == "" then return end

	return model
end

local function EnsureModel(ent, path)
	local mdl = ent.zcnpc_headcrabmodel
	if IsValid(mdl) then
		if mdl:GetModel() ~= path then mdl:SetModel(path) end

		return mdl
	end

	mdl = ClientsideModel(path)
	if not IsValid(mdl) then return end

	mdl:SetNoDraw(true)
	ent.zcnpc_headcrabmodel = mdl

	ent:CallOnRemove("zcnpc_headcrab_mdl", function()
		if IsValid(mdl) then mdl:Remove() end
	end)

	return mdl
end

local function ClearModel(ent)
	local mdl = ent.zcnpc_headcrabmodel
	if IsValid(mdl) then mdl:Remove() end
	ent.zcnpc_headcrabmodel = nil

	-- hg.RenderHeadcrab caches on this field when we hand the body to it
	mdl = ent.headcrabmodel
	if IsValid(mdl) then mdl:Remove() end
	ent.headcrabmodel = nil
end

function ZCNPC.DrawHeadcrab(ent)
	if not IsValid(ent) then return end

	local path = HeadcrabModel(ent)
	if not path then
		ClearModel(ent)
		ZCNPC.HeadcrabHosts[ent] = nil

		return
	end

	-- Prefer Z-City's own drawer when it is there; same offsets, same model cache.
	if isfunction(hg.RenderHeadcrab) then
		hg.RenderHeadcrab(ent, ent)

		return
	end

	local mdl = EnsureModel(ent, path)
	if not IsValid(mdl) then return end

	local bone = ent:LookupBone(HEAD_BONE)
	if not bone then
		ClearModel(ent)

		return
	end

	local head = ent:GetBoneMatrix(bone)
	if not head then return end

	local pos, ang = LocalToWorld(OFFSET_POS, OFFSET_ANG, head:GetTranslation(), head:GetAngles())

	mdl:SetRenderOrigin(pos)
	mdl:SetRenderAngles(ang)
	mdl:SetupBones()
	mdl:DrawModel()
end

local function Track(ent)
	if IsValid(ent) and HeadcrabModel(ent) then
		ZCNPC.HeadcrabHosts[ent] = true
	end
end

-- Standing NPCs go through our render override passes.
ZCNPC.AddPass(50, "headcrab", function(npc)
	return HeadcrabModel(npc) ~= nil
end, function(npc)
	ZCNPC.DrawHeadcrab(npc)
end)

-- Slow scan: organism ents + paired bodies. Cheap, and latch/clear is rare.
timer.Create("zcnpc_headcrab_scan", 0.35, 0, function()
	local hosts = ZCNPC.HeadcrabHosts

	for ent in pairs(hosts) do
		if not IsValid(ent) or not HeadcrabModel(ent) then
			if IsValid(ent) then ClearModel(ent) end
			hosts[ent] = nil
		end
	end

	for npc, rag in pairs(ZCNPC.Bodies or {}) do
		Track(npc)
		Track(rag)
	end

	-- Only scan organism ents when we might still be missing a latched host
	-- (corpses / unpaired rags). Full walk every tick is wasteful on corpse piles.
	if not (istable(hg) and istable(hg.organism_ents)) then return end

	for ent in pairs(hg.organism_ents) do
		if IsValid(ent) and (ent:IsRagdoll() or ent:IsNPC()) and not hosts[ent] then
			Track(ent)
		end
	end
end)

-- Ragdolls (the usual case once latched). Standing NPCs already draw via AddPass.
hook.Add("PostDrawOpaqueRenderables", "zcnpc_headcrab", function(_, skybox)
	if skybox then return end

	local hosts = ZCNPC.HeadcrabHosts
	if not next(hosts) then return end

	for ent in pairs(hosts) do
		if not IsValid(ent) then
			hosts[ent] = nil
			continue
		end

		if ent:IsDormant() then continue end
		if ent:IsNPC() and ent.zcnpc_render then continue end

		ZCNPC.DrawHeadcrab(ent)
	end
end)
