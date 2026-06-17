hg = hg or {}
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
local nosebleedDripNext = {}

hook.Add("PostCleanupMap","removeblooddroplets",function()
	hg.bloodparticles1 = {}
	hg.bloodpositions = {}
	hg.bloodpositionOrder = {}
	hg.bloodcount = 0
	nosebleedDripNext = {}
end)

local function getNosebleedCharacter(ply)
	if hg and hg.GetCurrentCharacter then
		local character = hg.GetCurrentCharacter(ply)
		if IsValid(character) then return character end
	end

	local ragdoll = ply.GetNWEntity and ply:GetNWEntity("FakeRagdoll", NULL) or nil
	if IsValid(ragdoll) then return ragdoll end

	ragdoll = ply.GetNWEntity and ply:GetNWEntity("RagdollDeath", NULL) or nil
	if IsValid(ragdoll) then return ragdoll end

	return ply
end

local function getNosebleedHead(ent)
	if not IsValid(ent) or not ent.LookupBone then return nil end

	local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
	if not bone then return nil end

	if ent.SetupBones then ent:SetupBones() end
	return ent:GetBoneMatrix(bone)
end

local function addNosebleedDrip(ply, pos, ang, activeFrac)
	local now = CurTime()
	if (nosebleedDripNext[ply] or 0) > now then return end

	nosebleedDripNext[ply] = now + math.Rand(0.35, 0.9)
	if math.Rand(0, 1) > math.Clamp(activeFrac + 0.15, 0.2, 0.85) then return end
	if not hg or not hg.addBloodPart then return end

	local vel = vector_up * -30 + ang:Forward() * 2
	hg.addBloodPart(pos, vel, nil, 1.8, 1.8, false, false, ply)
end

local function drawNosebleedForPlayer(ply, eyePos, maxDistanceSqr)
	local bleedUntil = ply:GetNWFloat("ZCity_NosebleedUntil", 0)
	local now = CurTime()
	if bleedUntil <= now then return end

	local character = getNosebleedCharacter(ply)
	if not IsValid(character) then return end
	if character:GetPos():DistToSqr(eyePos) > maxDistanceSqr then return end

	local matrix = getNosebleedHead(character)
	if not matrix then return end

	local pos = matrix:GetTranslation()
	local ang = matrix:GetAngles()
	local remaining = bleedUntil - now
	local activeFrac = math.Clamp(remaining / 45, 0.1, 1)

	local nostril = pos + ang:Right() * 2.7 + ang:Forward() * 3.4 - ang:Up() * 4.9
	addNosebleedDrip(ply, nostril, ang, activeFrac)
end

hook.Add("PostDrawTranslucentRenderables", "ZCity_NosebleedFaceRun", function()
	local lply = LocalPlayer()
	if not IsValid(lply) then return end

	local maxDistance = math.min(hg_blood_draw_distance:GetInt(), 900)
	if maxDistance <= 0 then return end

	local eyePos = EyePos()
	local maxDistanceSqr = maxDistance * maxDistance

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:IsPlayer() then continue end
		drawNosebleedForPlayer(ply, eyePos, maxDistanceSqr)
	end
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

		if part.landed or part.kishki or hg_blood_sprites:GetBool() then
			render_SetMaterial(part[4] or (isExpie and mat_expie_drop or mat_huy))
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
	
	local cap = 10000
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
	if hg and hg.GetWorldSize then
		radius = hg.GetWorldSize()
		radiusSqr = radius * radius
	end
end)

local function landBloodParticle(part, result, i)
	local hitPos = result.HitPos
	local nearbyCount = 0
	for j = 1, #hg.bloodparticles1 do
		local other = hg.bloodparticles1[j]
		if other and other.landed then
			local distSqr = other[1]:DistToSqr(hitPos)
			if distSqr < 144 then -- 12 units radius
				nearbyCount = nearbyCount + 1
			end
		end
	end
	
	if nearbyCount >= 5 then
		-- Falls on a big puddle of blood, landing wouldn't provide much impact so it despawns (absorbs)
		table_remove(hg.bloodparticles1, i)
		return true
	elseif nearbyCount > 0 then
		-- Landing on a bunch of particles should move on to the next empty space!
		local slideDir = (part[3]:Cross(result.HitNormal)):Cross(result.HitNormal):GetNormalized()
		if slideDir:LengthSqr() < 0.1 then
			slideDir = result.HitNormal:Angle():Right()
		end
		local slideOffset = slideDir * math.Rand(6, 12)
		local testPos = hitPos + slideOffset
		
		local testTr = {
			start = testPos + result.HitNormal * 5,
			endpos = testPos - result.HitNormal * 10,
			mask = MASK_SOLID_BRUSHONLY
		}
		local testResult = util_TraceLine(testTr)
		if testResult.Hit then
			hitPos = testResult.HitPos
		end
	end
	
	part.landed = true
	part[1] = hitPos + result.HitNormal * 0.1 -- slightly offset from surface to avoid z-fighting
	part[2] = part[1]
	part[3] = Vector(0, 0, 0) -- zero velocity
	
	-- Increase its size slightly when on the ground to look like a splat/puddle
	part[5] = part[5] * math.Rand(1.8, 2.5)
	part[6] = part[5]
	return false
end

bloodparticles_hook[2] = function(mul)
	local grav = gravity:GetInt() / 10
    local time = CurTime()
	local gravvec = vecDown * mul * (math.max(0.0, grav))
	
	-- Age-based deletion for flying particles only
	local maxAge = 30
	for i = #hg.bloodparticles1, 1, -1 do
		local part = hg.bloodparticles1[i]
		if part and not part.landed and part.spawnTime and (time - part.spawnTime) > maxAge then
			table_remove(hg.bloodparticles1, i)
		end
	end
	
	-- Count flying vs landed particles
	local landedCount = 0
	local flyingCount = 0
	for i = 1, #hg.bloodparticles1 do
		local part = hg.bloodparticles1[i]
		if part then
			if part.landed then
				landedCount = landedCount + 1
			else
				flyingCount = flyingCount + 1
			end
		end
	end

	-- Cap landed particles to prevent memory issues
	local landedCap = 15000
	if landedCount > landedCap then
		local toRemove = landedCount - landedCap
		for i = #hg.bloodparticles1, 1, -1 do
			if toRemove <= 0 then break end
			local part = hg.bloodparticles1[i]
			if part and part.landed then
				table_remove(hg.bloodparticles1, i)
				toRemove = toRemove - 1
			end
		end
	end

	-- Cap mid-air particles to prevent CPU lag
	local flyingCap = 2000
	if flyingCount > flyingCap then
		local toRemove = flyingCount - flyingCap
		for i = #hg.bloodparticles1, 1, -1 do
			if toRemove <= 0 then break end
			local part = hg.bloodparticles1[i]
			if part and not part.landed then
				table_remove(hg.bloodparticles1, i)
				toRemove = toRemove - 1
			end
		end
	end
	
	for i = #hg.bloodparticles1, 1, -1 do
		local part = hg.bloodparticles1[i]
		if not part then table_remove(hg.bloodparticles1, i) continue end
		
		-- Skip physics if already landed on the floor
		if part.landed then continue end
		
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

		if result.Hit and result.Entity:IsWorld() then
			local dir = result.HitNormal
			decalBlood(result.HitPos, dir, result, part.artery, part.owner)
			
			if landBloodParticle(part, result, i) then continue end
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
				local down = result.HitNormal
				local nextpos = (result.Normal + down):GetNormalized() * 5
				
				local insolid = result.StartSolid and IsValid(result.Entity)
				if not insolid and (part.nextput or 0) < CurTime() then
					part.nextput = CurTime() + 1

					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner)
				end

				if insolid then
					if result.Entity:IsVehicle() then
						table_remove(hg.bloodparticles1, i)
					
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
					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner)
					
					table_remove(hg.bloodparticles1, i)
					
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