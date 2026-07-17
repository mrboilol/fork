local function inityblood()
if SERVER then
    util.AddNetworkString("bloody_decal_1")
    util.AddNetworkString("addfountain")

    function ClearDecalToEnt(ent)
        if ent.decalshuy then
            ent:SetSubMaterial()
            ent.decalshuy = nil
        end
    end

    local matRepl = Material("decals/decalsplash")

    function AddDecalToEnt(ent, id, entIndex, tex, clear, x, y, rot, size, alpha)
        local subm = ent:GetSubMaterial(id - 1) != "" and ent:GetSubMaterial(id - 1) or ent:GetMaterials()[id]
        if !subm then return end

        local mata = Material(subm)
        if !IsValid(ent) then return end
        if !mata then return end
        
        ent.decalshuy = ent.decalshuy or {}
        local firstime = !ent.decalshuy[id]

        local mat = CreateMaterial(mata:GetName()..(entIndex or ent:EntIndex()).."256", mata:GetShader(), {})
        local basetexture = mata:GetTexture("$basetexture")
        if !basetexture then return end

        mat:SetTexture("$basetexture", basetexture)

        local sizew = basetexture:Width()
        local sizeh = basetexture:Height()
        size = size or 512

        tex = tex or matRepl
        
        local rt = GetRenderTargetEx("vms_rt_"..util.CRC(mat:GetName()), size, size, RT_SIZE_OFFSCREEN, MATERIAL_RT_DEPTH_SHARED, 0, CREATERENDERTARGETFLAGS_HDR, IMAGE_FORMAT_ARGB8888)

        render.PushRenderTarget(rt)

        if clear or firstime then
            render.Clear(0, 0, 0, 0, true)
        end

        x, y = x or math.random(0, size), y or math.random(0, size)
        rot = rot or math.Rand(-180, 180)
        
        cam.Start2D()
            surface.SetDrawColor( 255, 255, 255, alpha or math.random(100, 255) )
            surface.SetMaterial( tex )
            local rand = math.Clamp(math.random(), 0.5, 1)
            surface.DrawTexturedRectRotated(x, y, size * rand, size * rand, rot)
        cam.End2D()

        render.PopRenderTarget()

        mat:SetTexture("$detail", rt)
        mat:SetFloat("$detailscale", 1)
        mat:SetFloat("$detailblendfactor", 1)
        mat:SetInt("$detailblendmode", 2)

        ent.decalshuy[id] = ent:GetSubMaterial(id - 1)
        ent:SetSubMaterial(id - 1, "!"..mat:GetName())
    end

    function AddDecalToEnt2(ent, entIndex, tex, clear, x, y, rot, size, alpha)
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

local headpos_male, headpos_female, headang = Vector(0,0,5), Vector(-2,0,4), Angle(0,0,-0)

util.AddNetworkString("addfountain")

hg.fountains = hg.fountains or {}
local headboom_mdl = Model("models/gleb/zcity/headboom.mdl")
local sounds = {
	Sound("player/zombie_head_explode_01.wav"),
	Sound("player/zombie_head_explode_02.wav"),
	Sound("player/zombie_head_explode_03.wav"),
	Sound("player/zombie_head_explode_04.wav"),
	Sound("player/zombie_head_explode_05.wav"),
	Sound("player/zombie_head_explode_06.wav")
}
util.PrecacheModel(headboom_mdl)
for _, snd in ipairs(sounds) do
	util.PrecacheSound(snd)
end

    function Gib_Input(rag, bone, force)
        if not IsValid(rag) then return end
        
        local gibRemove = rag.gibRemove

        if not gibRemove then
            rag.gibRemove = {}
            gibRemove = rag.gibRemove
            gib_ragdols[rag] = true
        end

        local phys_bone = rag:TranslateBoneToPhysBone(bone)
        local phys_obj = rag:GetPhysicsObjectNum(phys_bone)
        
        if (not gibRemove[phys_bone]) and (bone == rag:LookupBone("ValveBiped.Bip01_Head1")) then
            rag:EmitSound(sounds[math.random(#sounds)], 70, math.random(95, 105), 2)

            Gib_RemoveBone(rag, bone, phys_bone)
            rag:ManipulateBonePosition(rag:LookupBone("ValveBiped.Bip01_Neck1"),Vector(-1,0,0))

            local ent = ents.Create("prop_dynamic")
            ent:SetModel(headboom_mdl)
            local att = rag:GetAttachment(3) or rag:GetAttachment(1)
            local isFem = ThatPlyIsFemale and ThatPlyIsFemale(rag) or false
            local pos, ang = LocalToWorld(isFem and headpos_female or headpos_male, headang, att and att.Pos or rag:GetPos(), att and att.Ang or rag:GetAngles())
            ent:SetPos(pos)
            ent:SetAngles(ang)
            ent:SetParent(rag, 3)
            ent:Spawn()

            SpawnMeatGore(rag, pos, nil, force)

            local armors = rag:GetNetVar("Armor",{})

            if armors["head"] and hg.armor and hg.armor["head"] and !hg.armor["head"][armors["head"]].nodrop then
                local aent = hg.DropArmorForce(rag, armors["head"])
                if IsValid(aent) then aent:SetPos(phys_obj:GetPos()) end
            end
            
            if armors["face"] and hg.armor and hg.armor["face"] and !hg.armor["face"][armors["face"]].nodrop then
                local aent = hg.DropArmorForce(rag, armors["face"])
                if IsValid(aent) then aent:SetPos(phys_obj:GetPos()) end
            end

            rag.noHead = true
            rag:SetNWString("PlayerName", "Beheaded body")

            net.Start("addfountain")
            net.WriteEntity(rag)
            net.WriteVector(force or vector_origin)
            net.Broadcast()

            hg.fountains[rag] = {
                bone = rag:LookupBone("ValveBiped.Bip01_Neck1"), 
                lpos = isFem and Vector(4,0,0) or Vector(5,0,0),
                lang = Angle(0,0,0),
            }

            rag:CallOnRemove("removefountain", function()
                hg.fountains[rag] = nil
                if SetNetVar then SetNetVar("fountains", hg.fountains) end
            end)
            if SetNetVar then SetNetVar("fountains", hg.fountains) end
        end
    end
end

if SERVER then

local function PhysCallback( ent, data, mainent )
	--data.HitPos -- data.HitNormal
	if data.DeltaTime < 0.2 then return end
	ent:EmitSound("physics/flesh/flesh_squishy_impact_hard"..math.random(4)..".wav")
	-- if !data.HitEntity:IsPlayer() and !data.HitEntity:IsRagdoll() and math.abs(data.HitNormal.z) < 0.75 then
	-- 	ent:SetMoveType(MOVETYPE_NONE)
	-- 	ent:SetSolid(SOLID_NONE)

	-- 	local tr = util.QuickTrace(data.HitPos - data.HitNormal * 1, data.HitNormal)
	-- 	ent:SetPos(tr.HitPos)
	-- 	local entindex = ent:EntIndex()
	-- 	local speed = math.Rand(0.2,0.4)
	-- 	local randspeed = math.Rand(-0.3,0.3)
	-- 	local needDecal = CurTime() + 1
	-- 	ent:SetModelScale(0, 10)
	-- 	SafeRemoveEntityDelayed(ent, 10)
	-- 	timer.Create("meatMove"..entindex, 0.1, 0, function()
	-- 		if !IsValid(ent) then timer.Remove("meatMove"..entindex) return end
	-- 		local tr = util.QuickTrace(ent:GetPos(), -data.HitNormal:Angle():Up())
	-- 		if math.abs(tr.HitNormal.z) > 0.75 then timer.Remove("meatMove"..entindex) return end
	-- 		local ang = data.HitNormal:Angle()
	-- 		ent:SetPos(ent:GetPos() - ang:Up() * speed + ang:Right() * randspeed)
	-- 		randspeed = LerpFT(0.05,randspeed, 0)
	-- 		if needDecal < CurTime() then
	-- 			needDecal = CurTime() + math.Rand(1,3)
	-- 			util.Decal("Normal.Blood24", ent:GetPos() - data.HitNormal * 1, ent:GetPos() + data.HitNormal * 1, ent)
	-- 		end
	-- 	end)
	-- end
	util.Decal("Normal.Blood24", data.HitPos - data.HitNormal * 1, data.HitPos + data.HitNormal * 1, ent)
end

if SERVER then
local grub, mat, gamemod = Model("models/grub_nugget_small.mdl"), "models/flesh", engine.ActiveGamemode()
local meatModels = {
	Model("models/props_junk/watermelon01_chunk02a.mdl"),
}
local gibRemoveTime = 60
local psmg = SpawnMeatGore

hg.organism.input_list = hg.organism.input_list or {}
local input_list = hg.organism.input_list

-- brain input function is defined in sv_organs.lua

SpawnMeatGore = function(mainent, pos, count, force, scale)
	force = force or Vector(0,0,0)
	for i = 1, (count or math.random(8, 10)) do
		local ent = ents.Create("prop_physics")
		if not IsValid(ent) then continue end

		ent:SetModel(meatModels[math.random(#meatModels)])
		ent:SetSubMaterial(0, mat)
		ent:SetPos(pos)
		ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		ent:SetModelScale(math.Rand(0.8,1.1) * (scale or 1))
		ent:SetAngles(AngleRand(-180,180))
		ent:Spawn()
		ent:Activate()

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetVelocity(mainent:GetVelocity() + VectorRand(-65,65) + force / 10)
			phys:AddAngleVelocity(VectorRand(-65,65))
		end

		if zb.CROUND and zb.CROUND ~= "hmcd" or gamemod == "sandbox" then
			ent:DrawShadow(false)
			ent:SetModelScale(0, gibRemoveTime)
			SafeRemoveEntityDelayed(ent, gibRemoveTime)
		end

		ent:AddCallback( "PhysicsCollide", function(lol,data) PhysCallback(ent,data,mainent) end)
	end
end
end
end
end

hook.Add("Initialize","we came here to rock the microphonnee", function()
inityblood()
end)
hook.Add("InitPostEntity","we came here to rock the microphoneeeu", function()
inityblood()
end)

inityblood()
