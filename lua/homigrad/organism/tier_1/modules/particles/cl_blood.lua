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
	if bleedUntil <= now then
		nosebleedDripNext[ply] = nil
		return
	end

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
local lightcolor = Color(0, 0, 0, 255)

local function setBloodParticleColor(part, light)
	if part.artery then
		-- Arterial blood needs to remain visibly fresh-red even in dark areas;
		-- multiplying pure red by map lighting made it look almost black indoors.
		lightcolor.r = math.min(175 + light[1] * 100, 255)
		lightcolor.g = math.min(24 + light[2] * 38, 90)
		lightcolor.b = math.min(16 + light[3] * 24, 55)
	else
		local normalBrightness = part.kishki and 10 or 20
		lightcolor.r = math.min(normalBrightness * light[1], 255)
		lightcolor.g = 0
		lightcolor.b = 0
	end
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
		if part.landed or part.kishki or hg_blood_sprites:GetBool() then
			render_SetMaterial(part[4] or mat_huy)
			if part.kishki then
				render_SetMaterial(part[4])
				setBloodParticleColor(part, light)
			else
				setBloodParticleColor(part, light)
			end
			render_DrawSprite(pos, part[5], part[6], lightcolor)
		else
			local len = (part[2] - part[1]):LengthSqr()
			render_SetMaterial(mat_huy)
			setBloodParticleColor(part, light)
			--part.lerpeddiff = LerpVector(FrameTime() * 1, part.lerpeddiff or Vector(), (part[2] - part[1]))
			--if len > 1 * 1 then
				render_SetMaterial(mat_huy)
				--part.lerpedshit = LerpFT(!part.lasthit and 1 or mul * 1, part.lerpedshit or 1, part.lasthit and 7 or 1)
				--render_DrawBeam(pos - (len < 2 and (part[2] - part[1]):GetNormalized() * part.lerpedshit or (part[2] - part[1])) * 0.5 / mul / 24,pos + (part[2] - part[1]) * 0.5 / mul / 24, part.lerpedshit, 0, 1, part[9] or lightcolor )
				--render_DrawBeam(pos - (part[2] - part[1]) * part.lerpedshit / mul / 24 * 0.5,pos + (part[2] - part[1]) * part.lerpedshit / mul / 24 * 0.5, part.lerpedshit, 0, 1, part[9] or lightcolor )
				
				--render_DrawBeam(pos - (len < 2 and (part[2] - part[1]):GetNormalized() * 2 or (part[2] - part[1])) * 0.5 / mul / 24,pos + (part[2] - part[1]) * 0.5 / mul / 24, 1, 0, 1, part[9] or lightcolor )
				render_DrawBeam(pos - (part[2] - part[1]) * 1 / mul / 24 * 0.5,pos + (part[2] - part[1]) * 1 / mul / 24 * 0.5, 1, 0, 1, part[9] or lightcolor )

				--lightcolor.r = lightcolor.r * 0.25
				--debugoverlay.Line(part[2], part[1], 1, lightcolor, false)	
			--end
		end
	end
	--render.OverrideBlend( false )
end

local hg_old_blood = ConVarExists("hg_old_blood") and GetConVar("hg_old_blood") or CreateClientConVar("hg_old_blood", 0, true, false, "new decals, or old", 0, 1)

hg.bloodpositions = hg.bloodpositions or {}
hg.bloodcount = hg.bloodcount or 0
local bloodDripSoundChance = 2 / 3
local bloodDripSoundVolume = 0.2
local bloodDecalCellSize = 4

local function playBloodDripImpact(pos, tr, artery)
	if math.Rand(0, 1) > bloodDripSoundChance then return end

	if artery then
		if tr.MatType == MAT_METAL then
			sound.Play("zbattle/blood_drop_metal.mp3", pos, math.random(98, 106), math.random(100, 120), bloodDripSoundVolume)
		else
			sound.Play("newblooddrip/sndBloodDrip" .. math_random(1, 3) .. ".wav", pos, math.random(96, 104), math.random(80, 120), bloodDripSoundVolume)
		end
		return
	end

	sound.Play("gore/blood" .. math_random(1, 6) .. ".mp3", pos, math.random(85, 95), math.random(80, 120), bloodDripSoundVolume)
end

local function decalBlood(pos, normal, tr, artery, owner, decalWeight)
	-- Pool nearby splashes so a single burst does not immediately evict older
	-- engine decals from the client's finite decal buffer. Small drops begin
	-- with the smallest decal; more blood in the same spot advances it through
	-- the larger decal materials instead of making every drop look identical.
	local vec = math.Round(pos[1] / bloodDecalCellSize)..":"..math.Round(pos[2] / bloodDecalCellSize)..":"..math.Round(pos[3] / bloodDecalCellSize)

	hg.bloodcount = hg.bloodcount + 1
	
	if hg.bloodcount > 10000 then
		hg.bloodpositions = {}
		hg.bloodcount = 0
	end

	-- я не знаю насколько большой можно делать такие таблицы... надеюсь, что это не так страшно выйдет

	local cell = hg.bloodpositions[vec]
	if !istable(cell) then
		cell = {hits = tonumber(cell) or 0, volume = 0, decalSize = 0}
		hg.bloodpositions[vec] = cell
	end

	cell.hits = cell.hits + 1
	cell.volume = math.min(cell.volume + math.Clamp(tonumber(decalWeight) or 1, 0.35, 6), 12)
	local decalSize = math.Clamp(math.ceil(cell.volume / 2.2), 1, 5)
	local grew = decalSize > cell.decalSize
	if grew then cell.decalSize = decalSize end
	local now = CurTime()
	local placeArterialDecal = artery and (cell.lastArterialDecal or 0) + 1.5 <= now
	if grew or placeArterialDecal then cell.lastArterialDecal = now end

	if artery then
		if !hg_old_blood:GetBool() then
			if grew or placeArterialDecal then
				util.Decal("Arterial.Blood2"..decalSize, pos + normal, pos - normal, owner)
			end
			playBloodDripImpact(pos, tr, true)
		else
			util.Decal("Arterial.Blood1", pos + normal, pos - normal, owner)
			playBloodDripImpact(pos, tr, true)
		end
	else
		if !hg_old_blood:GetBool() then
			playBloodDripImpact(pos, tr, false)

			if grew then
				util.Decal("Normal.Blood2"..decalSize, pos + normal, pos - normal, owner)
			end
		else
			util.Decal("Normal.Blood1", pos + normal, pos - normal, owner)
			playBloodDripImpact(pos, tr, false)
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
		
		if radiusSqr < hitPos:LengthSqr() then
			part.active = false
			table_remove(hg.bloodparticles1, i)
			continue
		end
		
        if bit.band(util.PointContents(hitPos), CONTENTS_WATER) == CONTENTS_WATER then
			hg.addBloodPart2(hitPos, part[3] / 20 + VectorRand(-1, 1), nil, nil, nil, nil, true)

			part.active = false
			table_remove(hg.bloodparticles1, i)
			continue
		end
		
		if time - part[7] >= 30 then
			part.active = false
			table_remove(hg.bloodparticles1, i)

			continue
		end

		if result.Hit and result.Entity:IsWorld() then
			part.active = false
			table_remove(hg.bloodparticles1, i)
			local dir = result.HitNormal
			decalBlood(result.HitPos, dir, result, part.artery, part.owner, part.decalWeight)
			
			
			--sound.Play("zbattle/blood_drop.mp3", hitPos, math.random(10, 60), math.random(120, 120))
			--sound.Play("homigrad/blooddrip" .. math_random(1, 4) .. ".ogg", hitPos, math.random(10, 60), math.random(80, 120))
			
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
				--local down = vecDown * mul * (math.max(0, grav))
				local down = result.HitNormal
				local nextpos = (result.Normal + down):GetNormalized() * 5
				
				if !insolid and (part.nextput or 0) < CurTime() then
					part.nextput = CurTime() + 1

					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner, part.decalWeight)
				end

				local insolid = result.StartSolid and IsValid(result.Entity)
				if insolid then
					if result.Entity:IsVehicle() then
						part.active = false
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
					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner, part.decalWeight)
					
					part.active = false
					table_remove(hg.bloodparticles1, i)
					
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
			local gravityMul = 1
			if part.gravityRampEnd and time < part.gravityRampEnd then
				gravityMul = math.Clamp(math.Remap(time, part.gravityRampStart or part[7], part.gravityRampEnd, 0.12, 1), 0.12, 1)
			end
			part[3]:Add(gravvec * gravityMul)
		--else
			--part[3]:Set(vecDown * mul * (math.max(0.1, grav)))
		end
	end
end
