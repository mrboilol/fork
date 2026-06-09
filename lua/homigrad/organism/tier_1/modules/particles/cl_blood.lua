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
	hg.bloodpositionOrder = {}
	hg.bloodcount = 0
end)

local mat_huy = Material("effects/blood_core")
local mat_expie_drop = Material("effects/droplets/drop2")
local lightcolor = Color(0, 0, 0, 255)

local expieModels_b = {
	["models/blop/expie/expie.mdl"] = true,
	["models/assassingecko/geckoexpie/geckoexpie.mdl"] = true,
	["models/assassingecko/geckoexpie/femgeckoexpie.mdl"] = true,
}
local function isExpieOwner(owner)
	if not IsValid(owner) then return false end
	return expieModels_b[owner:GetModel()] or owner.PlayerClassName == "expie" or owner.IsExpie or false
end
bloodparticles_hook[1] = function(anim_pos, mul)
	 
	local int = hg_blood_draw_distance:GetInt()
	local pos = lply:EyePos()
	--render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
	local dstsqr = int * int
	local lplypos = LocalPlayer():EyePos()
	local lplyang = LocalPlayer():EyeAngles():Forward()
	for i = 1, #hg.bloodparticles1 do
		local part = hg.bloodparticles1[i]
		if not part then continue end
		if (pos - lplypos):Dot(lplyang) < 0 then continue end
		if (part[2] - pos):LengthSqr() > dstsqr then continue end
		--if !hg.isVisible(part[1],LocalPlayer():GetShootPos(),LocalPlayer(),MASK_VISIBLE) then continue end
		--render_SetMaterial(part[4])
		local pos = LerpVector(anim_pos, part[2], part[1])
		
		local light1 = render.GetLightColor(pos)
		local light2 = render.ComputeLighting(pos, vector_up * 1)
		local light3 = render.ComputeDynamicLighting(pos, vector_up * 1)

		local light = (light1 + light2 + light3) * 3

		local isExpie = isExpieOwner(part.owner)

		if part.kishki then
			render_SetMaterial(part[4])
			if isExpie then
				lightcolor.r = math.min(255 * light[1], 255)
				lightcolor.g = math.min(255 * light[2], 255)
				lightcolor.b = 0
			else
				lightcolor.r = math.min((part.artery and 45 or 10) * light[1], 255)
				lightcolor.g = 0
				lightcolor.b = 0
			end
			render_DrawSprite(pos, part[5], part[6], lightcolor)
		else
			local len = (part[2] - part[1]):LengthSqr()
			render_SetMaterial(isExpie and mat_expie_drop or mat_huy)
			if isExpie then
				lightcolor.r = math.min(255 * light[1], 255)
				lightcolor.g = math.min(255 * light[2], 255)
				lightcolor.b = 0
			else
				lightcolor.r = math.min((part.artery and 45 or 20) * light[1], 255)
				lightcolor.g = 0
				lightcolor.b = 0
			end
			render_DrawBeam(pos - (part[2] - part[1]) * 1 / mul / 24 * 0.5,pos + (part[2] - part[1]) * 1 / mul / 24 * 0.5, 1, 0, 1, part[9] or lightcolor )
		end
	end
	--render.OverrideBlend( false )
end

local hg_old_blood = ConVarExists("hg_old_blood") and GetConVar("hg_old_blood") or CreateClientConVar("hg_old_blood", 0, true, false, "new decals, or old", 0, 1)

hg.bloodpositions = hg.bloodpositions or {}
hg.bloodpositionOrder = hg.bloodpositionOrder or {}
hg.bloodcount = hg.bloodcount or 0
local function decalBlood(pos, normal, tr, artery, owner)
	local vec = tostring(math.Round(pos[1]))..tostring(math.Round(pos[2]))..tostring(math.Round(pos[3]))

	hg.bloodcount = hg.bloodcount + 1
	
	if not hg.bloodpositions[vec] then
		hg.bloodpositionOrder[#hg.bloodpositionOrder + 1] = vec
	end
	
	local cap = 150000
	if hg.bloodcount > cap then
		local toRemove = hg.bloodcount - cap
		for i = 1, toRemove do
			if #hg.bloodpositionOrder > 0 then
				local oldVec = table.remove(hg.bloodpositionOrder, 1)
				if oldVec then
					hg.bloodpositions[oldVec] = nil
					hg.bloodcount = hg.bloodcount - 1
				end
			end
		end
	end

	local prefix = isExpieOwner(owner) and "Y" or ""
	local matType = tr.MatType
	local isMetal = matType == MAT_METAL
	local vol = math.random(10, 60)
	local pitch = isMetal and math.random(100, 120) or math.random(80, 120)
	
	sound.Play("homigrad/blooddrip" .. math_random(1, 4) .. ".wav", pos, vol, pitch)
	if isMetal then
		sound.Play("zbattle/blood_drop_metal.mp3", pos, math.random(10, 40), pitch)
	end

	if artery then
		if not hg_old_blood:GetBool() then
			hg.bloodpositions[vec] = (hg.bloodpositions[vec] or 0) + 1
			if hg.bloodpositions[vec] < 6 then
				util.Decal(prefix .. "Arterial.Blood2"..math.Clamp(hg.bloodpositions[vec], 1, 5), pos + normal, pos - normal, owner)
			end
		else
			util.Decal(prefix .. "Arterial.Blood1", pos + normal, pos - normal, owner)
		end
	else
		if not hg_old_blood:GetBool() then
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
	
	-- Age-based deletion (60 seconds)
	local maxAge = 60
	for i = #hg.bloodparticles1, 1, -1 do
		local part = hg.bloodparticles1[i]
		if part and part.spawnTime and (time - part.spawnTime) > maxAge then
			table_remove(hg.bloodparticles1, i)
		end
	end
	
	-- Emergency cap only when very high (raised to 150000)
	local cap = 150000
	while #hg.bloodparticles1 > cap do
		table_remove(hg.bloodparticles1, 1)
	end
	
	for i = #hg.bloodparticles1, 1, -1 do
		local part = hg.bloodparticles1[i]
		if not part then table_remove(hg.bloodparticles1, i) continue end
		
		local pos = part[1]
		local posSet = part[2]

		tr.start = posSet
		tr.endpos = tr.start + part[3] * mul
		tr.collisiongroup = part.kishki and COLLISION_GROUP_WORLD or COLLISION_GROUP_NONE

		result = util_TraceLine(tr)
		local hitPos = result.HitPos
		
		if radiusSqr < hitPos:LengthSqr() then table_remove(hg.bloodparticles1, i) continue end
		
        if bit.band(util.PointContents(hitPos), CONTENTS_WATER) == CONTENTS_WATER then
			hg.addBloodPart2(hitPos, part[3] / 20 + VectorRand(-1, 1), nil, nil, nil, nil, true)

			table_remove(hg.bloodparticles1, i)
			continue
		end

		if result.Hit then
			local dir = result.HitNormal
			decalBlood(result.HitPos, dir, result, part.artery, part.owner)
			
			table_remove(hg.bloodparticles1, i)
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

			if result.Hit then
				local dir = result.HitNormal
				decalBlood(result.HitPos, dir, result, part.artery, part.owner)
				
				table_remove(hg.bloodparticles1, i)
				continue
			else
				if part.hashitsomething then
					part.hashitsomething = nil
					part[3] = (posSet - pos) / mul * 1
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