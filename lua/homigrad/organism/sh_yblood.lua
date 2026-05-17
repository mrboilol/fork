local function chekExpie(ent)
    return IsValid(ent) and (ent:GetModel() == "models/blop/expie/expie.mdl" or ent.PlayerClassName == "expie" or ent.IsExpie) or false
end
//god this shit is so complicated for no reason
local function inityblood()
if SERVER then
    util.AddNetworkString("bloody_decal_1")
    util.AddNetworkString("addfountain")

    hook.Add("EntityTakeDamage", "Expied", function(ent, dmginfo)
        if chekExpie(ent) then
            ent:SetBloodColor(BLOOD_COLOR_YELLOW) 
        end
    end)

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
            net.WriteBool(chekExpie(rag))
            net.Broadcast()

            hg.fountains[rag] = {
                bone = rag:LookupBone("ValveBiped.Bip01_Neck1"), 
                lpos = isFem and Vector(4,0,0) or Vector(5,0,0),
                lang = Angle(0,0,0),
                isExpie = chekExpie(rag)
            }

            rag:CallOnRemove("removefountain", function()
                hg.fountains[rag] = nil
                if SetNetVar then SetNetVar("fountains", hg.fountains) end
            end)
            if SetNetVar then SetNetVar("fountains", hg.fountains) end
        end
    end
end

if CLIENT then
    local oldEffect = util.Effect
    function util.Effect(name, data, ...)
        if name == "BloodImpact" or name == "bloodspray" then
            if chekExpie(data:GetEntity()) then return end
        end
        return oldEffect(name, data, ...)
    end

    local bloodDecals = {["Blood"] = true, ["RedBlood"] = true, ["Arterial.Blood"] = true, ["Normal.Blood"] = true}
    local oldDecal = util.Decal
    function util.Decal(name, start, finish, ent)
        if chekExpie(ent) then
            local isBlood = bloodDecals[name]
            if not isBlood then
                for prefix, _ in pairs(bloodDecals) do
                    if string.StartWith(name, prefix) then isBlood = true break end
                end
            end
            if isBlood and not string.StartWith(name, "Y") then
                name = "Y" .. name
            end
        end
        return oldDecal(name, start, finish, ent)
    end

    local mat_expie_drop = Material("effects/droplets/drop2")
    
    local texture = Material("decals/z_blood1"):GetTexture("$basetexture")
    local mat_huy = Material("effects/blood_core")
    mat_huy:SetTexture("$basetexture", texture)

    local cloudmat = Material("effects/smoke_b")
    
    hg = hg or {}
    hg.bloodparticles1 = hg.bloodparticles1 or {}
    hg.bloodparticles2 = hg.bloodparticles2 or {}
    
    function hg.addBloodPart(pos, vel, mat, w, h, artery, kishki, owner, impact)
        if LocalPlayer():GetNetVar("disappearance", nil) or (IsValid(owner) and owner:GetNetVar("disappearance", nil)) then return end

        local pos2 = Vector()
        pos2:Set(pos)

        if #hg.bloodparticles1 > 200 then table.remove(hg.bloodparticles1, 1) end
        
        hg.bloodparticles1[#hg.bloodparticles1 + 1] = {
            pos, pos2, vel, mat or mat_huy, w or 2, h or 2, CurTime(),
            artery = artery, kishki = kishki, owner = owner,
            start_velocity = IsValid(owner) and owner:GetVelocity() or vector_origin,
            impact = impact
        }
    end

    function hg.addBloodPart2(pos, vel, mat, w, h, time, water, owner)
        if LocalPlayer():GetNetVar("disappearance", nil) or (IsValid(owner) and owner:GetNetVar("disappearance", nil)) then return end
        time = time or 30
        local pos2 = Vector()
        pos2:Set(pos)
        
        if #hg.bloodparticles2 > 200 then table.remove(hg.bloodparticles2, 1) end
        hg.bloodparticles2[#hg.bloodparticles2 + 1] = {
            pos, pos2, vel, mat or cloudmat, w or 60, h or 60, CurTime() + time, time, 
            water = water, owner = owner
        }
    end

    local hg_bloodimpacts = ConVarExists("hg_bloodimpacts") and GetConVar("hg_bloodimpacts") or CreateConVar("hg_bloodimpacts", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable custom blood impact effects spray cool kill death", 0, 1)

    local function impact(pos, vel, mul, owner)
        local max = math.min(mul, 8)
        local iters = math.ceil(math.random(1, max) * 2.5)
        local velnorm = -vel:GetNormalized() * 5
        
        if hg_bloodimpacts:GetBool() then
            hg.addBloodPart2(pos + velnorm, -vel + Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(-10, 10)) * 5, nil, 25, 25, 0.3, false, owner)
            hg.addBloodPart2(pos + velnorm, -vel / 2 + Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(-10, 10)) * 5, nil, 25, 25, 0.3, false, owner)
            hg.addBloodPart2(pos + velnorm, -vel / 3 + Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(-10, 10)) * 5, nil, 25, 25, 0.3, false, owner)
        end

        for i = 1, iters do
            local size = 1
            hg.addBloodPart(pos, -vel * i / iters + Vector(math.Rand(-20, 20), math.Rand(-20, 20), 0), mat_huy, size, size, false, false, owner, true)
        end
    end

    net.Receive("hg_bloodimpact", function()
        local pos = net.ReadVector()
        local vel = net.ReadVector() * 500
        local mul = net.ReadFloat()
        local amt = math.Clamp(net.ReadInt(8), 0, 32)
        
        local owner = nil
        for _, v in ipairs(ents.FindInSphere(pos, 40)) do
            if v:IsPlayer() or v:IsNPC() or v:IsNextBot() or v:IsRagdoll() then 
                owner = v 
                break 
            end
        end

        for i = 1, amt do impact(pos, vel, mul, owner) end
    end)

    function hg.explode(pos, size, force, owner)
        size = size or 1
        local xx, yy = 12, 12
        local w, h = 360 / xx, 360 / yy
        for x = 1, xx * size do
            for y = 1, yy * size do
                hg.addBloodPart2(pos + VectorRand(-10, 10), VectorRand(-100, 100) * size, cloudmat, 25, 25, 1, false, owner)
                local dir = Vector(0, 0, -1)
                dir:Rotate(Angle(h * y * math.Rand(0.9, 1.1), w * x * math.Rand(0.9, 1.1), 0))
                dir[3] = dir[3] + math.Rand(0.5, 1.5)
                dir:Mul(250 * size)
                hg.addBloodPart(pos, force * 0.2 + dir, mat_huy, math.Rand(5, 10), math.Rand(5, 10), false, true, owner)
            end
        end
    end

    local limbs = {
        ["lleg"] = "ValveBiped.Bip01_L_Calf", ["rleg"] = "ValveBiped.Bip01_R_Calf",
        ["larm"] = "ValveBiped.Bip01_L_Forearm", ["rarm"] = "ValveBiped.Bip01_R_Forearm",
    }

    hook.Add("HG_OrganismChanged", "explodelegs", function(oldorg, org)
        local ply = org.owner
        local ent = hg.GetCurrentCharacter(ply)
        for ind, nam in pairs(limbs) do
            if !oldorg[ind.."amputated"] and org[ind.."amputated"] then
                local bone = ent:LookupBone(nam)
                timer.Simple(0, function()
                    if IsValid(ent.bandagesModel) and ent.bandagesModel.BodygroupsApplied then
                        ent.bandagesModel.BodygroupsApplied = false
                    end
                end)
                if bone then
                    local mat = ent:GetBoneMatrix(bone)
                    if mat then
                        hg.explode(mat:GetTranslation() + mat:GetAngles():Forward() * 8, 0.5, Vector(), ent)
                    end
                end
            end
        end
    end)

    net.Receive("addfountain", function()
        local ent = net.ReadEntity()
        local force = net.ReadVector()
        local isExpie = net.ReadBool()
        if not IsValid(ent) then return end
        
        local bone = ent:LookupBone("ValveBiped.Bip01_Neck1")
        if bone then
            local mat = ent:GetBoneMatrix(bone)
            if mat then
                hg.explode(mat:GetTranslation() + mat:GetAngles():Forward() * 8, 0.5, force, ent)
            end
        end
    end)

    bloodparticles_hook = bloodparticles_hook or {}
    local hg_blood_draw_distance = ConVarExists("hg_blood_draw_distance") and GetConVar("hg_blood_draw_distance") or CreateClientConVar("hg_blood_draw_distance", 1024, true, nil, "distance to draw blood", 0, 4096)
    
    hook.Add("PostCleanupMap", "removeblooddroplets", function()
        hg.bloodparticles1 = {}
        hg.bloodpositions = {}
        hg.bloodcount = 0
    end)

    local lightcolor = Color(0, 0, 0, 255)
    
    bloodparticles_hook[1] = function(anim_pos, mul)
        local int = hg_blood_draw_distance:GetInt()
        local lplypos = LocalPlayer():EyePos()
        local dstsqr = int * int
        local lplyang = LocalPlayer():EyeAngles():Forward()
        
        for i = 1, #hg.bloodparticles1 do
            local part = hg.bloodparticles1[i]
            if not part then continue end
            if (part[1] - lplypos):Dot(lplyang) < 0 then continue end
            if (part[2] - lplypos):LengthSqr() > dstsqr then continue end
            
            local pos = LerpVector(anim_pos, part[2], part[1])
            local light = (render.GetLightColor(pos) + render.ComputeLighting(pos, Vector(0,0,1)) + render.ComputeDynamicLighting(pos, Vector(0,0,1))) * 3

            local isExpie = chekExpie(part.owner)

            if isExpie then
                lightcolor.r = math.min(255 * light[1], 255)
                lightcolor.g = math.min(255 * light[2], 255)
                lightcolor.b = 0
            else
                lightcolor.r = math.min((part.artery and 45 or 20) * light[1], 255)
                lightcolor.g = 0
                lightcolor.b = 0
            end

            if part.kishki then
                render.SetMaterial(part[4])
                render.DrawSprite(pos, part[5], part[6], lightcolor)
            else
                render.SetMaterial(isExpie and mat_expie_drop or mat_huy)
                render.DrawBeam(pos - (part[2] - part[1]) * 1 / mul / 24 * 0.5, pos + (part[2] - part[1]) * 1 / mul / 24 * 0.5, 1, 0, 1, lightcolor)
            end
        end
    end

    local hg_old_blood = ConVarExists("hg_old_blood") and GetConVar("hg_old_blood") or CreateClientConVar("hg_old_blood", 0, true, false, "new decals, or old", 0, 1)

    hg.bloodpositions = hg.bloodpositions or {}
    hg.bloodcount = hg.bloodcount or 0
    
    local function decalBlood(pos, normal, tr, artery, owner)
        local vec = tostring(math.Round(pos[1])) .. tostring(math.Round(pos[2])) .. tostring(math.Round(pos[3]))
        hg.bloodcount = hg.bloodcount + 1
        
        if hg.bloodcount > 10000 then
            hg.bloodpositions = {}
            hg.bloodcount = 0
        end

        local prefix = chekExpie(owner) and "Y" or ""

        if artery then
            if !hg_old_blood:GetBool() then
                hg.bloodpositions[vec] = (hg.bloodpositions[vec] or 0) + 1
                if hg.bloodpositions[vec] < 6 then
                    util.Decal(prefix .. "Arterial.Blood2"..math.Clamp(hg.bloodpositions[vec], 1, 5), pos + normal, pos - normal, owner)
                end
            else
                util.Decal(prefix .. "Arterial.Blood1", pos + normal, pos - normal, owner)
            end
        else
            if !hg_old_blood:GetBool() then
                hg.bloodpositions[vec] = (hg.bloodpositions[vec] or 0) + 1
                if hg.bloodpositions[vec] < 6 then
                    util.Decal(prefix .. "Normal.Blood2"..math.Clamp((hg.bloodpositions[vec] or 0) + math.random(0, 2), 1, 5), pos + normal, pos - normal, owner)
                end
                if hg.bloodpositions[vec] == 50 then
                    util.Decal(prefix .. "Blood", pos + normal, pos - normal, owner)
                end
            else
                util.Decal(prefix .. "Normal.Blood1", pos + normal, pos - normal, owner)
            end
        end
        
        sound.Play("homigrad/blooddrip" .. math.random(1, 4) .. ".wav", pos, math.random(10, 60), tr.MatType == MAT_METAL and math.random(100, 120) or math.random(80, 120))
        if tr.MatType == MAT_METAL then
            sound.Play("zbattle/blood_drop_metal.mp3", pos, math.random(10, 40), math.random(100, 120))
        end
    end

    local tr2 = { collisiongroup = COLLISION_GROUP_WORLD, output = {} }
    function util.IsInWorld( pos )
        tr2.start = pos
        tr2.endpos = pos
        return not util.TraceLine( tr2 ).HitWorld
    end

    local gravity = GetConVar("sv_gravity")
    local radius = 20000
    local radiusSqr = radius * radius

    hook.Add("InitPostEntity", "sizeget", function()
        if hg and hg.GetWorldSize then
            radius = hg.GetWorldSize()
            radiusSqr = radius * radius
        end
    end)

    bloodparticles_hook[2] = function(mul)
        local grav = gravity:GetInt() / 10
        local time = CurTime()
        local gravvec = Vector(0, 0, -40) * mul * (math.max(0.0, grav))

        for i = #hg.bloodparticles1, 1, -1 do
            local part = hg.bloodparticles1[i]
            if not part then table.remove(hg.bloodparticles1, i) continue end
            
            local pos = part[1]
            local posSet = part[2]

            local trData = {
                start = posSet,
                endpos = posSet + part[3] * mul,
                collisiongroup = part.kishki and COLLISION_GROUP_WORLD or COLLISION_GROUP_NONE
            }

            local result = util.TraceLine(trData)
            local hitPos = result.HitPos
            
            if radiusSqr < hitPos:LengthSqr() then table.remove(hg.bloodparticles1, i) continue end
            
            if bit.band(util.PointContents(hitPos), CONTENTS_WATER) == CONTENTS_WATER then
                hg.addBloodPart2(hitPos, part[3] / 20 + VectorRand(-1, 1), nil, nil, nil, nil, true, part.owner)
                table.remove(hg.bloodparticles1, i)
                continue
            end
            
            if time - part[7] >= 30 then
                table.remove(hg.bloodparticles1, i)
                continue
            end

            if result.Hit and result.Entity:IsWorld() then
                table.remove(hg.bloodparticles1, i)
                decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner)
                continue
            else
                local ph = 0
                local shouldhit = true

                if IsValid(result.Entity) then
                    ph = result.Entity:TranslatePhysBoneToBone(result.PhysicsBone)
                    ph = ph != -1 and ph or 0
                    local nam = result.Entity:GetBoneName(ph)
                    shouldhit = !(result.Entity.organism and hg.amputatedlimbs2 and hg.amputatedlimbs2[nam] and result.Entity.organism[hg.amputatedlimbs2[nam].."amputated"])
                end
                
                result.Hit = result.Hit and shouldhit

                if result.Hit then
                    local down = result.HitNormal
                    local nextpos = (result.Normal + down):GetNormalized() * 5
                    local insolid = result.StartSolid and IsValid(result.Entity)
                    
                    if !insolid and (part.nextput or 0) < CurTime() then
                        part.nextput = CurTime() + 1
                        decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner)
                    end

                    if insolid then
                        if result.Entity:IsVehicle() then
                            table.remove(hg.bloodparticles1, i)
                            continue
                        end

                        local center = result.Entity:GetBoneMatrix(ph)
                        local len = result.Entity:BoneLength(ph + 1)
                        if center then
                            center = center:GetTranslation() + (len and center:GetAngles():Forward() * len or Vector(0,0,0)) * 0.5
                            nextpos = -(center - hitPos - Vector(0,0,-40) * 1):GetNormalized() * 5
                        end
                    end

                    local pulldown = (-Vector(0,0,1) * (grav / 600)):Cross(-result.HitNormal:Angle():Right())
                    nextpos:Add(pulldown)
                    part.lerpedmove = LerpVector(1, part.lerpedmove or part[3] * mul, nextpos * mul * 2)
                    
                    if part.lerpedmove:LengthSqr() < 0.1 * mul then
                        decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner)
                        table.remove(hg.bloodparticles1, i)
                        continue
                    end

                    pos:Set(posSet + part.start_velocity * mul)
                    posSet:Set(hitPos + part.lerpedmove + part.start_velocity * mul)
                    part.hashitsomething = true
                else
                    if part.hashitsomething then
                        part.hashitsomething = nil
                        part[3] = (posSet - pos) / mul * 1
                        pos:Set(posSet)
                        posSet:Set(posSet)
                    else
                        pos:Set(posSet + part.start_velocity * mul)
                        posSet:Set(trData.start + part[3] * mul + part.start_velocity * mul)
                    end
                end

                part.lasthit = result.Hit
            end

            part[3] = LerpVector(0.25 * mul, part[3], Vector(0,0,0))
            if !(result.Hit) then
                part[3]:Add(gravvec)
            end
        end
    end//jaws
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
	if mainent and chekExpie(mainent) then util.Decal("YNormal.Blood24", data.HitPos - data.HitNormal * 1, data.HitPos + data.HitNormal * 1, ent) else util.Decal("Normal.Blood24", data.HitPos - data.HitNormal * 1, data.HitPos + data.HitNormal * 1, ent) end
end

if SERVER then
local grub, mat, gamemod = Model("models/grub_nugget_small.mdl"), "models/flesh", engine.ActiveGamemode()
local meatModels = {
	Model("models/props_junk/watermelon01_chunk02a.mdl"),
}
local gibRemoveTime = 60
local psmg = SpawnMeatGore

input_list.brain = function(org, bone, dmg, dmgInfo)
	if dmgInfo:IsDamageType(DMG_BLAST) then dmg = dmg / 50 end
	local oldDmg = org.brain
	local result = damageOrgan(org, dmg * 1, dmgInfo, "brain")

	hg.AddHarmToAttacker(dmgInfo, (org.brain - oldDmg) * 15, "Brain damage harm")

	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
		local dmgPos = dmgInfo:GetDamagePosition()
		local dirCool = dmgInfo:GetDamageForce():GetNormalized()

		if !chekExpie(org.owner) then local effdata = EffectData()
		effdata:SetOrigin(dmgPos)
		effdata:SetRadius(dmg / 10)
		effdata:SetMagnitude(dmg / 10)
		effdata:SetScale(1)
		util.Effect("BloodImpact",effdata) end

		local ent = hg.GetCurrentCharacter(org.owner)
		
		if !ent.organism.SpawnedBrainChunks and math.random(5) == 1 then
			SpawnMeatGore(ent, dmgPos + dirCool * 5, 3, dirCool * 1000, 0.4)
			ent.organism.SpawnedBrainChunks = true
		end
	end

	if org.brain >= 0.01 and (org.brain - oldDmg) > 0.01 and math.random(3) == 1 then
		--hg.applyFencingToPlayer(org.owner, org)
		org.shock = 70

		timer.Simple(0.1, function()
			local rag = hg.GetCurrentCharacter(org.owner)

			if IsValid(rag) and rag:IsRagdoll() then
				hg.applyFencingToPlayer(org.owner, org) -- looks more appealing anyways
				--local stype = "rigor"--hg.getRandomSpasm()
				--hg.applySpasm(rag, stype)
				--if rag.organism then rag.organism.spasm, rag.organism.spasmType = true, stype end
			end
		end)
	end

	org.consciousness = math.Approach(org.consciousness, 0, dmg * 3)
	
	org.disorientation = org.disorientation + dmg * 1
	org.shock = org.shock + dmg * 3
	org.painadd = org.painadd + dmg * 10
	return result
end

SpawnMeatGore = function(mainent, pos, count, force, scale)
	force = force or Vector(0,0,0)
	shouldBeYellow = chekExpie(mainent)

	for i = 1, (count or math.random(8, 10)) do
		local ent = ents.Create("prop_physics")
		if not IsValid(ent) then continue end

		ent:SetModel(meatModels[math.random(#meatModels)])
		if shouldBeYellow then
			ent:SetMaterial("models/balloon/balloon")
			ent:SetColor(Color(190, 195, 10,200)) 
		end
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