hg.bloodparticles1 = hg.bloodparticles1 or {}
bloodparticles_hook = bloodparticles_hook or {}

local tr = {
	//filter = function(ent) return not ent:IsPlayer() and not ent:IsRagdoll() end
}

local col_red_darker = Color(122,0,0)
local col_red = Color(200,0,0)
local vecDown = Vector(0, 0, -40)
local vecZero = Vector(0, 0, 0)
local gravity = GetConVar("sv_gravity")
local LerpVector = LerpVector
local math_random = math.random
local table_remove = table.remove
local util_TraceLine = util.TraceLine
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
local render_DrawBeam = render.DrawBeam
local render_GetLightColor = render.GetLightColor

local hg_blood_draw_distance = ConVarExists("hg_blood_draw_distance") and GetConVar("hg_blood_draw_distance") or CreateClientConVar("hg_blood_draw_distance", 1024, true, nil, "distance to draw blood", 0, 4096)
local hg_blood_sprites = ConVarExists("hg_blood_sprites") and GetConVar("hg_blood_sprites") or CreateClientConVar("hg_blood_sprites", 1, true, nil, "blood is sprites or trails", 0, 1)

function hg.ResetBloodDecals()
	hg.bloodpositions = {}
	hg.bloodcount = 0
	hg.groundbloodstains = {}
	hg.fadinggroundbloodstains = {}
end

hook.Add("PostCleanupMap","removeblooddroplets",function()
	hg.bloodparticles1 = {}
	hg.ResetBloodDecals()
end)

concommand.Add("hg_cleardecals", function()
	RunConsoleCommand("r_cleardecals")
	hg.ResetBloodDecals()
end)

net.Receive("hg_cleardecals", function()
	RunConsoleCommand("r_cleardecals")
	hg.ResetBloodDecals()
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
	local distance = hg_blood_draw_distance:GetInt()
	local distanceSqr = distance * distance
	local eyePos, eyeForward = EyePos(), EyeAngles():Forward()
	for i = 1, #hg.bloodparticles1 do
		local part = hg.bloodparticles1[i]
		if not part or part.hidden then continue end
		if (part[2] - eyePos):Dot(eyeForward) < 0 then continue end
		if (part[2] - eyePos):LengthSqr() > distanceSqr then continue end
		local pos = LerpVector(anim_pos, part[2], part[1])
		local light1 = render_GetLightColor(pos)
		local light2 = render.ComputeLighting(pos, vector_up)
		local light3 = render.ComputeDynamicLighting(pos, vector_up)
		local light = (light1 + light2 + light3) * 3
		lightcolor.b = 0
		if part.kishki then
			render_SetMaterial(part[4])
			lightcolor.r = part.artery and math.Clamp(90 * light[1], 150, 255) or math.min(10 * light[1], 255)
			lightcolor.g = part.artery and lightcolor.r * 0.06 or 0
			render_DrawSprite(pos, part[5], part[6], lightcolor)
		else
			render_SetMaterial(mat_huy)
			lightcolor.r = part.artery and math.Clamp(90 * light[1], 150, 255) or math.min(20 * light[1], 255)
			lightcolor.g = part.artery and lightcolor.r * 0.06 or 0
			local beamMotion = (part[2] - part[1]) / mul / 24
			local size = part[5] or 1
			local maxLength = part.maxBeamLength or size
			if beamMotion:LengthSqr() > maxLength * maxLength then
				beamMotion = beamMotion:GetNormalized() * maxLength
			end
			render_DrawBeam(pos - beamMotion * 0.5, pos + beamMotion * 0.5, size, 0, 1, part[9] or lightcolor)
		end
	end
end

local hg_old_blood = ConVarExists("hg_old_blood") and GetConVar("hg_old_blood") or CreateClientConVar("hg_old_blood", 1, true, false, "1 = AdvancedBlood system, 0 = old Z-City blood particles and decals", 0, 1)
local hg_oldblood = ConVarExists("hg_oldblood") and GetConVar("hg_oldblood") or CreateClientConVar("hg_oldblood", 0, true, false, "Use old Z-City blood decals", 0, 1)
local function useOldBlood()
	return not hg_old_blood:GetBool() or hg_oldblood:GetBool()
end

cvars.RemoveChangeCallback("hg_old_blood", "hg_refresh_old_blood_decals")
cvars.AddChangeCallback("hg_old_blood", function(_, oldValue, newValue)
	if oldValue == newValue then return end
	table.Empty(hg.bloodparticles1)
	if hg.bloodparticles2 then table.Empty(hg.bloodparticles2) end
	hg.bloodpositions = {}
	hg.bloodcount = 0
	hg.groundbloodstains = {}
	hg.fadinggroundbloodstains = {}
end, "hg_refresh_old_blood_decals")
cvars.RemoveChangeCallback("hg_oldblood", "hg_refresh_oldblood_decals")
cvars.AddChangeCallback("hg_oldblood", function(_, oldValue, newValue)
	if oldValue == newValue then return end
	hg.bloodpositions = {}
	hg.bloodcount = 0
end, "hg_refresh_oldblood_decals")

hg.bloodpositions = hg.bloodpositions or {}
hg.bloodcount = hg.bloodcount or 0
local bloodDripSoundChance = 2 / 3

local oldBloodDecals = {}
local oldArterialBloodDecals = {}
for i = 1, 10 do
	oldBloodDecals[i] = Material("decals/z_blood" .. i)
	oldArterialBloodDecals[i] = Material("decals/arterial_blood" .. i)
end
local poolTrace = {mask = MASK_SOLID_BRUSHONLY}
local function isDecalExSafe(target)
	return not IsValid(target) or target:IsWorld() or string.sub(target:GetModel() or "", 1, 1) == "*"
end

local bloodDecalDiameterMul = 7

local function getBloodDecalScale(amount, particleSize, material)
	local diameter = math.max(0.5 + math.sqrt(amount or 0.2) * 1.5, particleSize or 0) * bloodDecalDiameterMul
	local materialScale = material:GetFloat("$decalscale") or 1
	if materialScale <= 0 then materialScale = 1 end
	return diameter / (math.max(material:Width(), material:Height(), 1) * materialScale)
end

local function placeOldBloodDecal(pos, normal, target, artery, amount, particleSize)
	if not isDecalExSafe(target) then
		util.Decal(artery and "Arterial.Blood1" or "Normal.Blood1", pos + normal, pos - normal)
		return
	end
	local decals = artery and oldArterialBloodDecals or oldBloodDecals
	local material = decals[math_random(#decals)]
	local scale = getBloodDecalScale(amount, particleSize, material)
	util.DecalEx(material, target or game.GetWorld(), pos, normal, color_white, scale, scale)
end

local function playBloodDripImpact(pos, tr)
	if math.Rand(0, 1) > bloodDripSoundChance then return end

	sound.Play("gore/blood" .. math_random(1, 6) .. ".mp3", pos, math.random(10, 60), tr.MatType == MAT_METAL and math.random(100, 120) or math.random(80, 120))
	if tr.MatType == MAT_METAL then
		sound.Play("zbattle/blood_drop_metal.mp3", pos, math.random(10, 40), tr.MatType == MAT_METAL and math.random(100, 120) or math.random(80, 120))
	end
end

local newBloodDecalMaterials = {}
local bloodCellSize = 6
local bloodMaxLayers = 24

local function bumpBloodCount(pos)
	local key = math.Round(pos[1] / bloodCellSize) .. "," .. math.Round(pos[2] / bloodCellSize) .. "," .. math.Round(pos[3] / bloodCellSize)
	hg.bloodcount = hg.bloodcount + 1
	if hg.bloodcount > 40000 then
		hg.bloodpositions = {}
		hg.bloodcount = 1
	end
	local count = (hg.bloodpositions[key] or 0) + 1
	hg.bloodpositions[key] = count
	return count
end

local function placeNewBloodDecal(pos, normal, target, artery, amount, particleSize, trail)
	local count = bumpBloodCount(pos)
	if count > bloodMaxLayers then return end
	if trail then count = 1 end
	local name = artery and "Arterial.Blood2" .. math.Clamp(count, 1, 5) or "Normal.Blood2" .. math.Clamp(count + math_random(0, 2), 1, 5)
	if not isDecalExSafe(target) then
		util.Decal(name, pos + normal, pos - normal)
		return
	end
	local material = newBloodDecalMaterials[name]
	if not material then
		material = Material(util.DecalMaterial(name))
		newBloodDecalMaterials[name] = material
	end
	local scale = getBloodDecalScale(amount, particleSize, material) * (1 + (math.min(count, 6) - 1) * 0.15)
	util.DecalEx(material, target or game.GetWorld(), pos, normal, color_white, scale, scale)
end

function hg.DepositBodyBloodRunoff(pos, amount, artery, particleSize)
	if hg.BloodLandRedirect and hg.BloodLandRedirect(pos, vector_up, nil, artery, amount, particleSize) then return end
	poolTrace.start = pos + vector_up * 2
	poolTrace.endpos = pos - vector_up * 256
	local result = util_TraceLine(poolTrace)
	if result.HitWorld and result.HitNormal.z >= 0.55 then
		if useOldBlood() then
			placeOldBloodDecal(result.HitPos, result.HitNormal, nil, artery, amount or 0.2, particleSize)
			return
		end
		placeNewBloodDecal(result.HitPos, result.HitNormal, nil, artery, amount or 0.2, particleSize)
	end
end

local function isOrganismEnt(ent)
	return IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsRagdoll() or ent.organism ~= nil)
end

local smearMinSpeed = 30
local smearSpeedPerStep = 45
local smearMaxSteps = 12
local dripMinSteps = 4
local dripMaxSteps = 10
local dripChance = 0.65

local function placeBloodStreak(place, pos, normal, target, artery, dir, headSize, steps, startFade)
	local side = normal:Cross(dir)
	local drift = math.Rand(-0.1, 0.1)
	local spacing = headSize * bloodDecalDiameterMul * 0.32
	local p = pos
	for i = 1, steps do
		local fade = startFade * (1 - (i - 1) / steps)
		drift = drift + math.Rand(-0.04, 0.04)
		p = p + (dir + side * drift) * spacing * math.max(fade, 0.3)
		place(p, normal, target, artery, 0, headSize * fade, true)
	end
end

function hg.BloodPoolCovers(pos, normal)
	if normal.z < 0.64 or not (ABL and ABL.Pools and ABL.Pools.Find) then return false end
	return ABL.Pools.Find(pos.x, pos.y, pos.z, normal.x, normal.y, normal.z, 1.5) ~= nil
end

local function decalBlood(pos, normal, tr, artery, owner, tiny, amount, particleSize, vel)
	if not pos or not normal then return end
	if normal:LengthSqr() < 0.0001 then normal = vector_up end
	amount = math.max(amount or (tiny and 0.2 or artery and 2.5 or 1), 0.05)
	if isOrganismEnt(tr.Entity) then
		hg.DepositBodyBloodRunoff(pos, amount, artery, particleSize)
		return
	end
	if hg.BloodLandRedirect and hg.BloodLandRedirect(pos, normal, tr, artery, amount, particleSize, vel) then return end
	if hg.BloodPoolCovers(pos, normal) then
		if not tiny or math.random(7) == 1 then playBloodDripImpact(pos, tr) end
		return
	end

	local steps, dir = 0
	if vel and not tiny then
		local tangent = vel - normal * vel:Dot(normal)
		local tangentLen = tangent:Length()
		if tangentLen > smearMinSpeed then
			steps = math.min(math.floor(tangentLen / smearSpeedPerStep) + 3, smearMaxSteps)
			dir = tangent / tangentLen
		else
			amount = amount * 1.25
			particleSize = (particleSize or 0) * 1.15
		end
	end

	local target = IsValid(tr.Entity) and tr.Entity or nil
	local place = useOldBlood() and placeOldBloodDecal or placeNewBloodDecal
	place(pos, normal, target, artery, amount, particleSize)
	if not tiny and isDecalExSafe(target) then
		local headSize = math.max(0.5 + math.sqrt(amount) * 1.5, particleSize or 0)
		if steps > 0 then
			placeBloodStreak(place, pos, normal, target, artery, dir, headSize, steps, 0.8)
		end
		if math.abs(normal.z) < 0.7 and math.Rand(0, 1) < dripChance then
			local down = vecDown - normal * vecDown:Dot(normal)
			if down:LengthSqr() > 0.01 then
				down:Normalize()
				local side = normal:Cross(down)
				local runs = (artery or amount > 1.5) and math_random(1, 3) or 1
				for _ = 1, runs do
					local start = pos + side * math.Rand(-0.6, 0.6) * headSize * 1.25
					placeBloodStreak(place, start, normal, target, artery, down, headSize, math_random(dripMinSteps, dripMaxSteps), math.Rand(0.3, 0.5))
				end
			end
		end
	end
	if not tiny or math.random(7) == 1 then playBloodDripImpact(pos, tr) end
end
hg.DecalBloodHit = decalBlood
--дурак, просто смотри сколько ентити стоит в одном месте
local tr2 = { collisiongroup = COLLISION_GROUP_WORLD, output = {} }

function util.IsInWorld( pos )
	tr2.start = pos
	tr2.endpos = pos

	return not util.TraceLine( tr2 ).HitWorld
end

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
		if time - part[7] >= (part.lifetime or 30) then
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
			decalBlood(result.HitPos, dir, result, part.artery, part.owner, part.tiny, part.volume, part.size, part[3])

			
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
			local onBody = result.Hit and isOrganismEnt(result.Entity)
			if result.Hit and part.tiny and not onBody then
				decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner, true, part.volume, part.size)
				hg.bloodparticles1[i] = hg.bloodparticles1[#hg.bloodparticles1]
				table_remove(hg.bloodparticles1)
				continue
			end

			if result.Hit then
				local insolid = result.StartSolid and IsValid(result.Entity)
				--local down = vecDown * mul * (math.max(0, grav))
				local down = result.HitNormal
				local nextpos = (result.Normal + down):GetNormalized() * 5
				
				if !insolid and not onBody and (part.nextput or 0) < time then
					part.nextput = time + 1

					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner, part.tiny, part.volume, part.size)
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
					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner, part.tiny, part.volume, part.size)
					
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
