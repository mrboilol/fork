
if SERVER then
    util.AddNetworkString("bloody_decal_1")
    util.AddNetworkString("hg_head_blood_decal")
    util.AddNetworkString("hg_clear_blood_decals")

    local function ApplyHeadBloodDecal(ent)
        if not IsValid(ent) then return end

        net.Start("hg_head_blood_decal")
        net.WriteEntity(ent)
        net.Broadcast()
    end

    local bloodDecalReplayLimit = 16

    local function ApplyBloodDecal(ent)
        if not IsValid(ent) then return end

        net.Start("bloody_decal_1")
        net.WriteEntity(ent)
        net.Broadcast()
    end

    -- Record ordinary hit blood server-side. The visible decal is emitted
    -- immediately and the compact count lets a new ragdoll rebuild the same
    -- bloodiness instead of starting clean after an entity swap.
    function hg.AddOrganismBloodDecal(ply, amount)
        if not IsValid(ply) then return end

        amount = math.max(tonumber(amount) or 1, 1)
        ply.HG_BloodDecalCount = math.min((ply.HG_BloodDecalCount or 0) + amount, bloodDecalReplayLimit)

        local target = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
        for i = 1, amount do
            ApplyBloodDecal(IsValid(target) and target or ply)
        end
    end

    local function ReapplyHeadBloodDecal(ply, ragdoll)
        if not IsValid(ply) then return end
        if ply.HG_HeadBloodDecal then
            ApplyHeadBloodDecal(IsValid(ragdoll) and ragdoll or hg.GetCurrentCharacter(ply))
        end
    end

    local function ReapplyBloodDecals(ply, ragdoll)
        if not IsValid(ply) then return end

        local target = IsValid(ragdoll) and ragdoll or hg.GetCurrentCharacter(ply)
        for i = 1, ply.HG_BloodDecalCount or 0 do
            ApplyBloodDecal(target)
        end
    end

    hook.Add("Fake", "HG_HeadBloodDecal_Fake", function(ply, ragdoll)
        ReapplyHeadBloodDecal(ply, ragdoll)
        ReapplyBloodDecals(ply, ragdoll)
    end)

    hook.Add("RagdollDeath", "HG_HeadBloodDecal_Death", function(ply, ragdoll)
        ReapplyHeadBloodDecal(ply, ragdoll)
        ReapplyBloodDecals(ply, ragdoll)
    end)

    hook.Add("Player Think", "HG_WashBloodDecals", function(ply)
        local character = hg.GetCurrentCharacter(ply)
        local deathRagdoll = ply.RagdollDeath
        if ply:WaterLevel() <= 0
            and (not IsValid(character) or character:WaterLevel() <= 0)
            and (not IsValid(deathRagdoll) or deathRagdoll:WaterLevel() <= 0) then return end
        if ply.HG_NextBloodWash and ply.HG_NextBloodWash > CurTime() then return end

        ply.HG_NextBloodWash = CurTime() + 0.5
        ply.HG_HeadBloodDecal = nil
        ply.HG_BloodDecalCount = nil

        local targets = {
            ply,
            character,
            deathRagdoll,
        }

        for _, ent in ipairs(targets) do
            if IsValid(ent) then
                net.Start("hg_clear_blood_decals")
                net.WriteEntity(ent)
                net.Broadcast()
            end
        end
    end)

    return
end


function ClearDecalToEnt(ent)
	if not IsValid(ent) or not ent.decalshuy then return end

	for id, original in pairs(ent.decalshuy) do
		ent:SetSubMaterial(id - 1, original or "")
	end

	ent.decalshuy = nil
	ent.hgBloodDecalMaterials = nil
	ent.hgBloodDecalRenderTargets = nil
	ent.hgBloodDecalMaterialVersion = nil
end

local matRepl = Material("decals/decalsplash")
local bloodMaterialVersion = 4
local curmat
local curmat2

local function CopyMaterialValue(value)
	local valueType = type(value)

	if valueType == "ITexture" then return value:GetName() end
	if valueType == "Vector" or valueType == "VMatrix" or valueType == "Angle" then return tostring(value) end
	if valueType == "boolean" then return value and 1 or 0 end
	if valueType == "string" or valueType == "number" then return value end
	if valueType != "table" then return nil end

	local copy = {}
	for key, child in pairs(value) do
		local copied = CopyMaterialValue(child)
		if copied != nil then copy[key] = copied end
	end

	return copy
end

function AddDecalToEnt(ent, id, --[[optional]] entIndex, tex, clear, x, y, rot, size, alpha)
	if !IsValid(ent) then return end

	local subm = ent:GetSubMaterial(id - 1) != "" and ent:GetSubMaterial(id - 1) or ent:GetMaterials()[id]
	if !subm then
		print("Invalid submaterial entered for weapon "..tostring(Entity(entIndex)).."; change SWEP.bloodID to something else or remove it completely if you don't wanna bother.")
			
		return
	end

	ent.decalshuy = ent.decalshuy or {}
	if ent.hgBloodDecalMaterialVersion != bloodMaterialVersion then
		ent.hgBloodDecalMaterials = {}
		ent.hgBloodDecalRenderTargets = {}
		ent.hgBloodDecalMaterialVersion = bloodMaterialVersion
	else
		ent.hgBloodDecalMaterials = ent.hgBloodDecalMaterials or {}
		ent.hgBloodDecalRenderTargets = ent.hgBloodDecalRenderTargets or {}
	end

	local firstime = ent.decalshuy[id] == nil
	if not firstime then
		subm = ent.decalshuy[id] != "" and ent.decalshuy[id] or ent:GetMaterials()[id]
	end

	local mata = Material(subm)
	if !mata then return end

	local basetexture = mata:GetTexture("$basetexture")
	if !basetexture then return end

	-- Replacing $basetexture with a render target changes the entire outfit and
	-- can make VertexLitGeneric player materials render black. Blood belongs in
	-- a transparent detail layer so the model keeps its original base texture.
	-- Do not steal an existing detail slot; that can contain the clothing pattern.
	local olddetail = mata:GetTexture("$detail")
	if olddetail and olddetail:GetName() != "error" then return end

	if firstime then
		ent.decalshuy[id] = ent:GetSubMaterial(id - 1)
	end

	-- CreateMaterial accepts texture names, not the ITexture objects returned by
	-- GetKeyValues. Convert the clone data so bump/phong textures stay valid.
	local tabla = CopyMaterialValue(mata:GetKeyValues())
	-- Source's internal material flags are added by CreateMaterial itself.
	-- Passing its serialized copies back in declares each flag twice.
	tabla["$flags"] = nil
	tabla["$flags2"] = nil
	tabla["$flags_defined"] = nil
	tabla["$flags_defined2"] = nil
	
	-- you should set up entIndex for CSModels since their entIndex is -1
	local materialKey = mata:GetName()..":"..(entIndex or ent:EntIndex())..":"..id..":v"..bloodMaterialVersion

	local size = size or 512

	local tex = tex or matRepl
	
	local rt = ent.hgBloodDecalRenderTargets[id]
	local newRenderTarget = not rt
	if not rt then
		rt = GetRenderTargetEx("hg_blood_rt_"..util.CRC(materialKey), size, size, RT_SIZE_OFFSCREEN, MATERIAL_RT_DEPTH_SHARED, 0, CREATERENDERTARGETFLAGS_HDR, IMAGE_FORMAT_ARGB8888)
		ent.hgBloodDecalRenderTargets[id] = rt
	end

	local mat = ent.hgBloodDecalMaterials[id]
	if not mat then
		-- Clone the complete source material, then add the blood overlay. Keeping
		-- its original shader parameters preserves phong, tint, bumpmaps and alpha.
		tabla["$basetexture"] = basetexture:GetName()
		tabla["$detail"] = rt:GetName()
		tabla["$detailscale"] = 1
		tabla["$detailblendfactor"] = 1
		tabla["$detailblendmode"] = 2
		mat = CreateMaterial("hg_blood_"..util.CRC(materialKey), mata:GetShader(), tabla)
		ent.hgBloodDecalMaterials[id] = mat
	end

	render.PushRenderTarget(rt)

	local resetBaseTexture = clear or firstime or newRenderTarget
	if resetBaseTexture then
		render.Clear(0, 0, 0, 0, true)
	end

	local x, y = x or math.random(0, size), y or math.random(0, size)
	local rot = rot or math.Rand(-180, 180)
	
	cam.Start2D()
		surface.SetDrawColor( 255, 255, 255, alpha or math.random(100, 255) )
		surface.SetMaterial( tex )
		--surface.SetTexture(surface.GetTextureID("zbattle/blood"))
		local rand = math.Clamp(math.random(), 0.5, 1)
		surface.DrawTexturedRectRotated(x, y, size * rand, size * rand, rot)
	cam.End2D()

	render.PopRenderTarget()

	mat:SetTexture("$basetexture", basetexture)
	mat:SetTexture("$detail", rt)
	mat:SetFloat("$detailscale", 1)
	mat:SetFloat("$detailblendfactor", 1)
	mat:SetInt("$detailblendmode", 2)

	curmat = mat
	curmat2 = mata

	ent:SetSubMaterial(id - 1, "!"..mat:GetName())
	--print(ent:GetSubMaterial(id - 1), 1, "!"..mat:GetName(), 2)
end

function AddDecalToEnt2(ent, entIndex, tex, clear, x, y, rot, size, alpha) -- adds to all submats
	for id, val in ipairs(ent:GetMaterials()) do
		AddDecalToEnt(ent, id, entIndex, tex, clear, x, y, rot, size, alpha)
	end
end

local matBlood = Material("zbattle/blood")
net.Receive("bloody_decal_1", function()
	local self = net.ReadEntity()

	if IsValid(self) then
		local mdl = self.worldModel2
		mdl = IsValid(mdl) and mdl or self.worldModel
		mdl = IsValid(mdl) and mdl or self.NPCworldModel
		mdl = IsValid(mdl) and mdl or self
		
		if self.bloodID then
			AddDecalToEnt(mdl, self.bloodID, self:EntIndex(), matBlood, false, nil, nil, nil, nil, self.DamageType != DMG_SLASH and 100)
		else
			AddDecalToEnt2(mdl, self:EntIndex(), matBlood, false, nil, nil, nil, nil, self.DamageType != DMG_SLASH and 100)
		end
	end
end)

net.Receive("hg_head_blood_decal", function()
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end

	-- Keep a skull wound visible without covering every material in an opaque blood sheet.
	AddDecalToEnt2(ent, ent:EntIndex(), matBlood, false, nil, nil, nil, 192, 110)
end)

net.Receive("hg_clear_blood_decals", function()
	ClearDecalToEnt(net.ReadEntity())
end)

--[[
local wep = Entity(1):GetActiveWeapon()
local wm = wep.worldModel2--wep:GetWM()
--"effects/droplets/drop3_1"
AddDecalToEnt2(wm, wep:EntIndex(), Material("zbattle/blood"), false)--"decals/blood1", true)
--]]
--AddDecalToEnt2(Entity(1), Entity(1):EntIndex(), Material("zbattle/blood"), false)

-- local matat = Material("models/weapons/m4a1/weapon_m4a1_dm")
-- local white = Material("vgui/white")
-- hook.Add("HUDPaint", "testBlood", function()
-- 	do return end
-- 	if !curmat then return end
-- 	--render.SuppressEngineLighting(true)
-- 	--render.SetLightingMode(2)
-- 	--render.SetAmbientLight( 255, 255, 255 )
-- 	--render.ResetModelLighting( 1, 0, 0 )
-- 	print(surface.GetTextureID(curmat:GetTexture("$detail"):GetName()))
-- 	render.SetLightmapTexture(white:GetTexture("$basetexture"))
-- 	surface.SetTexture(surface.GetTextureID(curmat2:GetName()))
-- 	surface.SetDrawColor(255,255,255,255)
-- 	surface.DrawTexturedRect(0,0,255,255)
-- 	surface.SetMaterial(curmat)
-- 	surface.SetDrawColor(255,255,255,255)
-- 	surface.DrawTexturedRect(255,0,255,255)
-- 	surface.SetTexture(surface.GetTextureID(matat:GetName()))
-- 	surface.SetDrawColor(255,255,255,255)
-- 	surface.DrawTexturedRect(255+255,0,255,255)
-- 	surface.SetMaterial(matat)
-- 	surface.SetDrawColor(255,255,255,255)
-- 	surface.DrawTexturedRect(255+255+255,0,255,255)
-- 	--[[surface.SetTexture(surface.GetTextureID(curmat:GetTexture("$detail"):GetName()))
-- 	surface.SetDrawColor(255,255,255,255)
-- 	surface.DrawTexturedRect(255+255+255+255,0,255,255)--]]
-- 	--render.SetLightingMode(0)
-- 	--render.SuppressEngineLighting(false)
-- end)
