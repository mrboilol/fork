hg.bloodparticles1 = hg.bloodparticles1 or {}
bloodparticles_hook = bloodparticles_hook or {}

local tr = {
	//filter = function(ent) return not ent:IsPlayer() and not ent:IsRagdoll() end
}

local col_red_darker = Color(122,0,0)
local col_red = Color(200,0,0)
local vecDown = Vector(0, 0, -40)
local vecZero = Vector(0, 0, 0)
local LerpVector = LerpVector
local math_random = math.random
local table_remove = table.remove
local util_Decal = util.Decal
local util_TraceLine = util.TraceLine
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
local render_DrawBeam = render.DrawBeam
local render_GetLightColor = render.GetLightColor

local hg_blood_draw_distance = ConVarExists("hg_blood_draw_distance") and GetConVar("hg_blood_draw_distance") or CreateClientConVar("hg_blood_draw_distance", 1024, true, nil, "distance to draw blood", 0, 4096)
local hg_blood_sprites = ConVarExists("hg_blood_sprites") and GetConVar("hg_blood_sprites") or CreateClientConVar("hg_blood_sprites", 1, true, nil, "blood is sprites or trails", 0, 1)

hook.Add("PostCleanupMap","removeblooddroplets",function()
	hg.bloodparticles1 = {}
	hg.bloodpositions = {}
	hg.bloodcount = 0
	hg.groundbloodstains = {}
	hg.fadinggroundbloodstains = {}
end)

hook.Add("Player Spawn", "removeownblooddroplets", function(ply)
	if ply ~= LocalPlayer() then return end

	local parts1, parts2 = hg.bloodparticles1, hg.bloodparticles2
	for i = #parts1, 1, -1 do
		local part = parts1[i]
		if part and part.owner == ply then
			parts1[i] = parts1[#parts1]
			table_remove(parts1)
		end
	end
	for i = #parts2, 1, -1 do
		local part = parts2[i]
		if part and part.owner == ply then
			parts2[i] = parts2[#parts2]
			table_remove(parts2)
		end
	end
end)

local mat_huy = Material("effects/blood_core")
local lightcolor = Color(0, 0, 0, 255)
bloodparticles_hook[1] = function(anim_pos, mul)
	 
	local int = hg_blood_draw_distance:GetInt()
	--render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
	local dstsqr = int * int
	local lplypos = EyePos()
	local lplyang = EyeAngles():Forward()
	for i = 1, #hg.bloodparticles1 do
		local part = hg.bloodparticles1[i]
		if not part then continue end
		if part.hidden then continue end
		if (part[2] - lplypos):Dot(lplyang) < 0 then continue end
		if (part[2] - lplypos):LengthSqr() > dstsqr then continue end
		--if !hg.isVisible(part[1],LocalPlayer():GetShootPos(),LocalPlayer(),MASK_VISIBLE) then continue end
		--render_SetMaterial(part[4])
		local pos = LerpVector(anim_pos, part[2], part[1])

		local time = CurTime()
		local light
		if not part.lightcache_time or time - part.lightcache_time > 0.25 then
			local light1 = render.GetLightColor(pos)
			local light2 = render.ComputeLighting(pos, vector_up * 1)
			local light3 = render.ComputeDynamicLighting(pos, vector_up * 1)
			part.lightcache = (light1 + light2 + light3) * 3
			part.lightcache_time = time
		end
		light = part.lightcache

		if part.kishki then
			render_SetMaterial(part[4])
			lightcolor.r = math.min((part.artery and 45 or 10) * light[1], 255)
			render_DrawSprite(pos, part[5], part[6], lightcolor)
		else
			local len = (part[2] - part[1]):LengthSqr()
			--part.lerpeddiff = LerpVector(FrameTime() * 1, part.lerpeddiff or Vector(), (part[2] - part[1]))
			--if len > 1 * 1 then
				render_SetMaterial(mat_huy)
				lightcolor.r = math.min((part.artery and 45 or 20) * light[1], 255)
				--part.lerpedshit = LerpFT(!part.lasthit and 1 or mul * 1, part.lerpedshit or 1, part.lasthit and 7 or 1)
				--render_DrawBeam(pos - (len < 2 and (part[2] - part[1]):GetNormalized() * part.lerpedshit or (part[2] - part[1])) * 0.5 / mul / 24,pos + (part[2] - part[1]) * 0.5 / mul / 24, part.lerpedshit, 0, 1, part[9] or lightcolor )
				--render_DrawBeam(pos - (part[2] - part[1]) * part.lerpedshit / mul / 24 * 0.5,pos + (part[2] - part[1]) * part.lerpedshit / mul / 24 * 0.5, part.lerpedshit, 0, 1, part[9] or lightcolor )
				
				--render_DrawBeam(pos - (len < 2 and (part[2] - part[1]):GetNormalized() * 2 or (part[2] - part[1])) * 0.5 / mul / 24,pos + (part[2] - part[1]) * 0.5 / mul / 24, 1, 0, 1, part[9] or lightcolor )
				local width = math.Clamp((part[5] or 1) * 0.42, part.tiny and 0.04 or 0.18, 1.35)
				render_DrawBeam(pos - (part[2] - part[1]) * 1 / mul / 24 * 0.5,pos + (part[2] - part[1]) * 1 / mul / 24 * 0.5, width, 0, 1, part[9] or lightcolor )

				--lightcolor.r = lightcolor.r * 0.25
				--debugoverlay.Line(part[2], part[1], 1, lightcolor, false)	
			--end
		end
	end
	--render.OverrideBlend( false )
end

local hg_old_blood = ConVarExists("hg_old_blood") and GetConVar("hg_old_blood") or CreateClientConVar("hg_old_blood", 0, true, false, "new decals, or old", 0, 1)

cvars.RemoveChangeCallback("hg_old_blood", "hg_refresh_old_blood_decals")
cvars.AddChangeCallback("hg_old_blood", function(_, oldValue, newValue)
	if oldValue == newValue then return end
	hg.bloodpositions = {}
	hg.groundbloodstains = {}
	hg.fadinggroundbloodstains = {}
end, "hg_refresh_old_blood_decals")

hg.bloodpositions = hg.bloodpositions or {}
hg.bloodcount = hg.bloodcount or 0
local bloodDripSoundChance = 2 / 3

local hg_blood_ground_limit = ConVarExists("hg_blood_ground_limit") and GetConVar("hg_blood_ground_limit") or CreateClientConVar("hg_blood_ground_limit", 600, true, false, "Maximum persistent ground blood stains", 1, 2000)
local hg_blood_ground_lifetime = ConVarExists("hg_blood_ground_lifetime") and GetConVar("hg_blood_ground_lifetime") or CreateClientConVar("hg_blood_ground_lifetime", 900, true, false, "Seconds before ground blood fades", 30, 7200)
local hg_blood_ground_fade = ConVarExists("hg_blood_ground_fade") and GetConVar("hg_blood_ground_fade") or CreateClientConVar("hg_blood_ground_fade", 20, true, false, "Seconds ground blood takes to fade", 1, 120)

hg.groundbloodstains = hg.groundbloodstains or {}
hg.fadinggroundbloodstains = hg.fadinggroundbloodstains or {}

local groundBloodMaterials = {}
for i = 1, 6 do
	groundBloodMaterials[i] = Material("bloodspill/blood" .. i)
end

local groundBloodColor = Color(92, 0, 0, 255)
local render_DrawQuadEasy = render.DrawQuadEasy

local function fadeGroundBlood(stain, now)
	stain.fadeStart = now
	stain.fadeEnd = now + math.max(hg_blood_ground_fade:GetFloat(), 0.1)
	hg.fadinggroundbloodstains[#hg.fadinggroundbloodstains + 1] = stain
end

local function addGroundBlood(pos, normal, artery, tiny)
	if hg_old_blood:GetBool() then return false end
	if normal.z < 0.55 then return false end

	local now = CurTime()
	local stains = hg.groundbloodstains
	local limit = math.max(hg_blood_ground_limit:GetInt(), 1)
	while #stains >= limit do
		fadeGroundBlood(table.remove(stains, 1), now)
	end

	local size
	if tiny then
		size = math.Rand(0.8, 1.7)
	elseif artery then
		size = math.Rand(11, 22)
	else
		size = math.Rand(7, 15)
	end

	stains[#stains + 1] = {
		pos = pos + normal * 0.2,
		normal = normal,
		material = groundBloodMaterials[math_random(#groundBloodMaterials)],
		size = size,
		rotation = math_random(0, 359),
		created = now,
	}

	return true
end

hook.Add("Think", "hg_persistent_ground_blood", function()
	local now = CurTime()
	local stains = hg.groundbloodstains
	local lifetime = math.max(hg_blood_ground_lifetime:GetFloat(), 0.1)
	local limit = math.max(hg_blood_ground_limit:GetInt(), 1)

	for i = #stains, 1, -1 do
		if now - stains[i].created >= lifetime then
			fadeGroundBlood(table.remove(stains, i), now)
		end
	end

	while #stains > limit do
		fadeGroundBlood(table.remove(stains, 1), now)
	end

	local fading = hg.fadinggroundbloodstains
	for i = #fading, 1, -1 do
		if fading[i].fadeEnd <= now then
			table_remove(fading, i)
		end
	end

	while #fading > limit do
		table_remove(fading, 1)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "hg_draw_persistent_ground_blood", function()
	local eyePos = EyePos()
	local eyeForward = EyeAngles():Forward()
	local drawDistance = hg_blood_draw_distance:GetInt()
	local drawDistanceSqr = drawDistance * drawDistance

	local function drawStain(stain, alpha)
		local offset = stain.pos - eyePos
		if offset:LengthSqr() > drawDistanceSqr or offset:Dot(eyeForward) < -stain.size then return end
		groundBloodColor.a = alpha
		render_SetMaterial(stain.material)
		render_DrawQuadEasy(stain.pos, stain.normal, stain.size, stain.size, groundBloodColor, stain.rotation)
	end

	for i = 1, #hg.groundbloodstains do
		drawStain(hg.groundbloodstains[i], 255)
	end

	local now = CurTime()
	for i = 1, #hg.fadinggroundbloodstains do
		local stain = hg.fadinggroundbloodstains[i]
		local alpha = math.Clamp((stain.fadeEnd - now) / (stain.fadeEnd - stain.fadeStart), 0, 1) * 255
		drawStain(stain, alpha)
	end
end)

local function playBloodDripImpact(pos, tr)
	if math.Rand(0, 1) > bloodDripSoundChance then return end

	sound.Play("gore/blood" .. math_random(1, 6) .. ".mp3", pos, math.random(10, 60), tr.MatType == MAT_METAL and math.random(100, 120) or math.random(80, 120))
	if tr.MatType == MAT_METAL then
		sound.Play("zbattle/blood_drop_metal.mp3", pos, math.random(10, 40), tr.MatType == MAT_METAL and math.random(100, 120) or math.random(80, 120))
	end
end

local tinyNormalDecalIds = {1, 2, 3, 4, 6, 7, 8, 9, 10, 11}
local tinyNormalDecals = {}
for i = 1, #tinyNormalDecalIds do
	tinyNormalDecals[i] = Material("effects/droplets/drop" .. tinyNormalDecalIds[i] .. "_1")
end
local tinyArterialDecal = Material("effects/droplets/drop12_1")
local oldTinyNormalDecals = {}
for i = 1, 10 do
	oldTinyNormalDecals[i] = Material("decals/z_blood" .. i)
end
local oldTinyArterialDecal = Material("decals/arterial_blood1")

local function decalBlood(pos, normal, tr, artery, owner, tiny)
	if not pos or not normal then return end
	if normal:LengthSqr() < 0.0001 then normal = vector_up end
	if tr.HitWorld and addGroundBlood(pos, normal, artery, tiny) then
		if not tiny or math.random(7) == 1 then playBloodDripImpact(pos, tr) end
		return
	end
	if tiny then
		local oldBlood = hg_old_blood:GetBool()
		local decal = artery and (oldBlood and oldTinyArterialDecal or tinyArterialDecal)
			or (oldBlood and oldTinyNormalDecals[math.random(#oldTinyNormalDecals)] or tinyNormalDecals[math.random(#tinyNormalDecals)])
		local target = IsValid(tr.Entity) and tr.Entity or game.GetWorld()
		local scale = math.Rand(0.12, 0.24)
		util.DecalEx(decal, target, pos, normal, color_white, scale, scale)
		if math.random(7) == 1 then playBloodDripImpact(pos, tr) end
		return
	end

	local vec = tostring(math.Round(pos[1]))..tostring(math.Round(pos[2]))..tostring(math.Round(pos[3]))

	hg.bloodcount = hg.bloodcount + 1
	
	if hg.bloodcount > 10000 then
		hg.bloodpositions = {}
		hg.bloodcount = 0
	end

	-- я не знаю насколько большой можно делать такие таблицы... надеюсь, что это не так страшно выйдет

	if artery then
		if !hg_old_blood:GetBool() then
			local howmuch = 1
			
			//timer.Simple(0.1, function()
				hg.bloodpositions[vec] = (hg.bloodpositions[vec] or 0) + 1
				if hg.bloodpositions[vec] < 6 then
					util.Decal("Arterial.Blood2"..math.Clamp(hg.bloodpositions[vec], 1, 5), pos + normal, pos - normal, owner)
				end
				playBloodDripImpact(pos, tr)
			//end)
		else
			util.Decal("Arterial.Blood1", pos + normal, pos - normal, owner)
			playBloodDripImpact(pos, tr)
		end
	else
		if !hg_old_blood:GetBool() then
			local howmuch = 1
			
			//timer.Simple(0.1, function()
				hg.bloodpositions[vec] = (hg.bloodpositions[vec] or 0) + 1
				
				playBloodDripImpact(pos, tr)

				if hg.bloodpositions[vec] < 6 then
					util.Decal("Normal.Blood2"..math.Clamp((hg.bloodpositions[vec] or 0) + math.random(0, 2), 1, 5), pos + normal, pos - normal, owner)
				end

				if hg.bloodpositions[vec] == 50 then
					util.Decal("Blood", pos + normal, pos - normal, owner)
				end

			//end)
		else
			util.Decal("Normal.Blood1", pos + normal, pos - normal, owner)
			playBloodDripImpact(pos, tr)
		end
	end
end
--дурак, просто смотри сколько ентити стоит в одном месте
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
	radius = hg.GetWorldSize()
    radiusSqr = radius * radius
end)

bloodparticles_hook[2] = function(mul)
	local grav = gravity:GetInt() / 10
    local time = CurTime()
	local gravvec = vecDown * mul * (math.max(0.0, grav))
	local lplypos = LocalPlayer():EyePos()
	local dsqr = hg_blood_draw_distance:GetInt()
	dsqr = dsqr * dsqr
	for i = #hg.bloodparticles1, 1, -1 do
		local part = hg.bloodparticles1[i]
		if not part then hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]; table_remove(hg.bloodparticles1) continue end
		if time - part[7] >= 30 then
			hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]; table_remove(hg.bloodparticles1)
			continue
		end

		if (part[1] - lplypos):LengthSqr() > dsqr then continue end
		
		local pos = part[1]
		local posSet = part[2]

		tr.start = posSet
		tr.endpos = tr.start + part[3] * mul
		tr.collisiongroup = part.kishki and COLLISION_GROUP_WORLD or COLLISION_GROUP_NONE

		local result = util_TraceLine(tr)
		local hitPos = result.HitPos
		
		if radiusSqr < hitPos:LengthSqr() then hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]; table_remove(hg.bloodparticles1) continue end

        local checkWater = time >= (part.nextwater or 0)
        if checkWater then part.nextwater = time + 0.08 end
        if checkWater and bit.band(util.PointContents(hitPos), CONTENTS_WATER) == CONTENTS_WATER then
			if not part.hidden then hg.addBloodPart2(hitPos, part[3] / 20 + VectorRand(-1, 1), nil, nil, nil, nil, true, part.owner) end

			hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]; table_remove(hg.bloodparticles1)
			continue
		end
		if result.Hit and result.Entity:IsWorld() then
			hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]; table_remove(hg.bloodparticles1)
			local dir = result.HitNormal
			decalBlood(result.HitPos, dir, result, part.artery, part.owner, part.tiny)
			
			
			--sound.Play("zbattle/blood_drop.mp3", hitPos, math.random(10, 60), math.random(120, 120))
			--sound.Play("homigrad/blooddrip" .. math_random(1, 4) .. ".wav", hitPos, math.random(10, 60), math.random(80, 120))
			
			continue
		else
			local ph = 0
			local shouldhit = true
			if IsValid(result.Entity) then
				ph = result.Entity:TranslatePhysBoneToBone(result.PhysicsBone)
				ph = ph != -1 and ph or 0
				local nam = result.Entity:GetBoneName(ph)
				
				shouldhit = !(result.Entity.organism and hg.amputatedlimbs2[nam] and result.Entity.organism[hg.amputatedlimbs2[nam].."amputated"])
			end
			
			result.Hit = result.Hit and shouldhit
			if result.Hit and part.tiny then
				decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner, true)
				hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]
				table_remove(hg.bloodparticles1)
				continue
			end

			if result.Hit then
				local insolid = result.StartSolid and IsValid(result.Entity)
				--local down = vecDown * mul * (math.max(0, grav))
				local down = result.HitNormal
				local nextpos = (result.Normal + down):GetNormalized() * 5
				
				if !insolid and (part.nextput or 0) < time then
					part.nextput = time + 1

					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner, part.tiny)
				end

				if insolid then
					if result.Entity:IsVehicle() then
						hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]; table_remove(hg.bloodparticles1)
					
						continue
					end

					local center = result.Entity:GetBoneMatrix(ph)
					local len = result.Entity:BoneLength(ph + 1)

					if center then
						center = center:GetTranslation() + (len and center:GetAngles():Forward() * len or vector_origin) * 0.5
						nextpos = -(center - hitPos - vecDown * 1):GetNormalized() * 5
					end
				end

				local pulldown = (-vector_up * (grav / 600)):Cross(-result.HitNormal:Angle():Right())
				nextpos:Add(pulldown)
				part.lerpedmove = LerpVector(1, part.lerpedmove or part[3] * mul, nextpos * mul * 2)
				
				if part.lerpedmove:LengthSqr() < 0.1 * mul then
					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner, part.tiny)
					
					hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]; table_remove(hg.bloodparticles1)
					
					continue
				end

				pos:Set(posSet + part.start_velocity * mul)
				posSet:Set(hitPos + part.lerpedmove + part.start_velocity * mul)
				part.hashitsomething = true
			else
				if part.hashitsomething then
					part.hashitsomething = nil
					--part[3][3] = 0
					part[3] = (posSet - pos) / mul * 1--part.lerpedmove / mul
					--part.lerpedmove = nil
					pos:Set(posSet)
					posSet:Set(posSet)
				else
					pos:Set(posSet + part.start_velocity * mul)
					posSet:Set(tr.start + part[3] * mul + part.start_velocity * mul)
				end
			end

			part.lasthit = result.Hit
		end

		part[3] = LerpVector(0.25 * mul, part[3], vecZero)
		if !(result.Hit) then
			part[3]:Add(gravvec)
		--else
			--part[3]:Set(vecDown * mul * (math.max(0.1, grav)))
		end
	end
end
