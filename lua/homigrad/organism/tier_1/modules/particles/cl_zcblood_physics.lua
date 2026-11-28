ZCBlood = ZCBlood or {}

local util_TraceLine = util.TraceLine
local table_remove = table.remove
local math_random = math.random
local render_SetMaterial = render.SetMaterial
local render_DrawBeam = render.DrawBeam
local render_DrawSprite = render.DrawSprite

local tr = {}
local gravity = GetConVar("sv_gravity")
local radiusSqr = 20000 * 20000

hook.Add("InitPostEntity", "zcblood_worldsize", function()
	if hg and hg.GetWorldSize then
		local radius = hg.GetWorldSize()
		radiusSqr = radius * radius
	end
end)

local stack, stackCount = {}, 0
local maxSpotLayers = 12

local function decalBlood(pos, normal, trace, artery, owner, quiet)
	if quiet then
		util.Decal(artery and "Arterial.Blood21" or "Normal.Blood21", pos + normal, pos - normal, owner)
		return
	end

	stackCount = stackCount + 1
	if stackCount > 40000 then stack, stackCount = {}, 0 end

	local key = math.Round(pos[1]) .. " " .. math.Round(pos[2]) .. " " .. math.Round(pos[3])
	local count = (stack[key] or 0) + 1
	stack[key] = count

	if count < maxSpotLayers then
		local tier = math.Clamp(artery and count or count + math_random(0, 2), 1, 5)
		util.Decal((artery and "Arterial.Blood2" or "Normal.Blood2") .. tier, pos + normal, pos - normal, owner)
	end

	local metal = trace.MatType == MAT_METAL
	sound.Play("gore/blood" .. math_random(1, 6) .. ".mp3", pos, math_random(10, 60), metal and math_random(100, 120) or math_random(80, 120))
	if metal then
		sound.Play("zbattle/blood_drop_metal.mp3", pos, math_random(10, 40), math_random(100, 120))
	end
end

local mat_huy = Material("effects/blood_core")
local lightcolor = Color(0, 0, 0, 255)
local streamColor = Color(0, 0, 0, 255)
local glossColor = Color(0, 0, 0, 255)
local arterialTint = {175, 12, 8}
local venousTint = {95, 5, 4}
local glossTint = {255, 150, 140}
local glossAlpha = 120
local streamWidth = {arterial = 1.7, venous = 1}
local streamMinLength = 0.6
local streamLink = 9
local streamLookback = 4
local runWidth = 0.7

local function tint(col, rgb, light, alpha)
	col.r = math.min(rgb[1] * light[1], 255)
	col.g = math.min(rgb[2] * light[2], 255)
	col.b = math.min(rgb[3] * light[3], 255)
	col.a = alpha or 255
	return col
end

function ZCBlood.DrawDrops(anim_pos)
	local drawDistance = GetConVar("hg_blood_draw_distance")
	local int = drawDistance and drawDistance:GetInt() or 1024
	local dstsqr = int * int
	local eye = EyePos()
	local fwd = EyeAngles():Forward()
	local recent = {}
	local linkSqr = streamLink * streamLink

	for i = 1, #hg.bloodparticles1 do
		local part = hg.bloodparticles1[i]
		if not part or part.hidden then continue end

		local pos = LerpVector(anim_pos, part[2], part[1])
		local toPart = pos - eye
		if toPart:Dot(fwd) < -16 or toPart:LengthSqr() > dstsqr then continue end

		local light = render.GetLightColor(pos) + render.ComputeLighting(pos, vector_up) + render.ComputeDynamicLighting(pos, vector_up)

		if part.kishki then
			render_SetMaterial(part[4])
			lightcolor.r = math.min((part.artery and 45 or 10) * light[1] * 3, 255)
			render_DrawSprite(pos, part[5], part[6], lightcolor)
			continue
		end

		local col = tint(streamColor, part.artery and arterialTint or venousTint, light)
		local gloss = tint(glossColor, glossTint, light, glossAlpha)
		local width = (part.artery and streamWidth.arterial or streamWidth.venous) * math.Clamp((part[5] or 2) / 2, 0.6, 1.5)
		if part.run then width = width * runWidth end

		local streak = (part[2] - part[1]) * 0.5
		if streak:LengthSqr() < streamMinLength * streamMinLength then
			streak = streak:LengthSqr() > 0 and streak:GetNormalized() * streamMinLength or vector_up * streamMinLength
		end
		local tail, head = pos - streak, pos + streak

		render_SetMaterial(mat_huy)
		render_DrawBeam(tail, head, width, 0, 1, col)

		if not part.run then
			local owner = part.owner or part
			local chain = recent[owner]
			if not chain then
				chain = {}
				recent[owner] = chain
			end

			local best, bestDist
			for n = #chain, math.max(#chain - streamLookback + 1, 1), -1 do
				local other = chain[n]
				if other.artery == part.artery then
					local dist = other.pos:DistToSqr(pos)
					if dist < linkSqr and (not bestDist or dist < bestDist) then best, bestDist = other, dist end
				end
			end

			if best then
				render_DrawBeam(best.pos, pos, (best.width + width) * 0.45, 0, 1, col)
				render_DrawBeam(best.pos, pos, (best.width + width) * 0.12, 0, 1, gloss)
			end

			chain[#chain + 1] = {pos = pos, width = width, artery = part.artery}
		end

		render_DrawBeam(tail, head, width * 0.3, 0, 1, gloss)
	end
end

local dropDrag = 0.003
local floorZ = 0.7
local ceilingZ = -0.3
local splashSpeed = 220
local splashCount = 3
local splashSpread = 0.3
local runSpeed = 12
local runLength = {12, 40}
local runTrailStep = 4
local bodyGrip = 0.3
local bodyRest = 2
local dropLife = 30
local splashCap = 1600

local function splash(part, pos, normal, speed)
	if part.kishki or part.satellite or speed < splashSpeed then return end
	if #hg.bloodparticles1 + splashCount > splashCap then return end

	for i = 1, math_random(1, splashCount) do
		local side = VectorRand()
		side:Sub(normal * side:Dot(normal))
		side:Normalize()

		local vel = side * speed * math.Rand(0.1, splashSpread) + normal * speed * math.Rand(0.05, 0.15)
		hg.addBloodPart(pos + normal, vel, part[4], part[5] * 0.5, part[6] * 0.5, part.artery, nil, part.owner)

		local child = hg.bloodparticles1[#hg.bloodparticles1]
		if child then
			child.satellite = true
			child.launched = true
		end
	end
end

local function startRun(part, pos, normal)
	part.run = {normal = normal, left = math.Rand(runLength[1], runLength[2]), trail = 0}
	part[3] = Vector()
	part[1]:Set(pos)
	part[2]:Set(pos + normal * 0.5)
end

local function stepRun(part, mul)
	local run = part.run
	local normal = run.normal
	local down = -vector_up - normal * -normal.z
	if down:LengthSqr() < 0.01 then return false end
	down:Normalize()

	local posSet = part[2]
	local step = down * runSpeed * mul * math.Rand(0.5, 1.2)

	tr.start = posSet
	tr.endpos = posSet + step
	tr.filter = nil
	tr.collisiongroup = COLLISION_GROUP_WORLD
	local ahead = util_TraceLine(tr)
	if ahead.Hit and ahead.HitNormal.z >= floorZ then
		decalBlood(ahead.HitPos, ahead.HitNormal, ahead, part.artery, part.owner)
		return false
	end

	local nextPos = ahead.HitPos
	tr.start = nextPos + normal * 2
	tr.endpos = nextPos - normal * 4
	local wall = util_TraceLine(tr)

	part[1]:Set(posSet)
	if not wall.Hit then
		part.run = nil
		part[3] = down * runSpeed - normal * runSpeed * 0.5
		posSet:Set(nextPos)
		return true
	end

	run.normal = wall.HitNormal
	posSet:Set(wall.HitPos + wall.HitNormal * 0.5)

	local moved = step:Length()
	run.left = run.left - moved
	run.trail = run.trail + moved
	if run.trail >= runTrailStep then
		run.trail = 0
		decalBlood(wall.HitPos, wall.HitNormal, wall, part.artery, part.owner, true)
	end

	return run.left > 0
end

function ZCBlood.Physics(mul)
	local grav = math.max(gravity:GetFloat(), 0)
	local time = CurTime()

	for i = #hg.bloodparticles1, 1, -1 do
		local part = hg.bloodparticles1[i]
		if not part or time - part[7] >= (part.lifetime or dropLife) then table_remove(hg.bloodparticles1, i) continue end

		if not part.launched then
			part.launched = true
			part[3] = part[3] + (part.start_velocity or vector_origin)
		end

		if part.run then
			if not stepRun(part, mul) then table_remove(hg.bloodparticles1, i) end
			continue
		end

		local vel = part[3]
		vel.z = vel.z - grav * mul
		local speed = vel:Length()
		vel:Mul(1 - math.min(dropDrag * speed * mul, 0.9))

		local pos, posSet = part[1], part[2]
		tr.start = posSet
		tr.endpos = posSet + vel * mul
		tr.filter = part.ignore
		tr.collisiongroup = part.kishki and COLLISION_GROUP_WORLD or COLLISION_GROUP_NONE
		local result = util_TraceLine(tr)
		local hitPos = result.HitPos

		if radiusSqr < hitPos:LengthSqr() then table_remove(hg.bloodparticles1, i) continue end

		if bit.band(util.PointContents(hitPos), CONTENTS_WATER) == CONTENTS_WATER then
			hg.addBloodPart2(hitPos, vel / 20 + VectorRand(-1, 1), nil, nil, nil, nil, true)
			table_remove(hg.bloodparticles1, i)
			continue
		end

		local ent = result.Entity
		local shouldhit = result.Hit
		if shouldhit and IsValid(ent) then
			local ph = ent:TranslatePhysBoneToBone(result.PhysicsBone)
			ph = ph ~= -1 and ph or 0
			local nam = ent:GetBoneName(ph)
			local limb = hg.amputatedlimbs2 and hg.amputatedlimbs2[nam]
			shouldhit = not (ent.organism and limb and ent.organism[limb .. "amputated"])

			if result.StartSolid or ent:IsVehicle() then
				part.ignore = ent
				shouldhit = false
			end
		end

		pos:Set(posSet)

		if not shouldhit then
			posSet:Set(tr.endpos)
			continue
		end

		local normal = result.HitNormal
		if result.HitWorld or not IsValid(ent) or not (ent:IsRagdoll() or ent:IsPlayer() or ent:IsNPC()) then
			splash(part, hitPos, normal, speed)

			if normal.z >= floorZ or normal.z <= ceilingZ or part.kishki then
				decalBlood(hitPos, normal, result, part.artery, part.owner)
				table_remove(hg.bloodparticles1, i)
			else
				decalBlood(hitPos, normal, result, part.artery, part.owner)
				startRun(part, hitPos, normal)
			end

			continue
		end

		if (part.nextput or 0) < time then
			part.nextput = time + 1
			decalBlood(hitPos, normal, result, part.artery, part.owner)
		end

		vel:Sub(normal * vel:Dot(normal))
		vel:Mul(bodyGrip)
		if vel:LengthSqr() < bodyRest * bodyRest then
			decalBlood(hitPos, normal, result, part.artery, part.owner)
			table_remove(hg.bloodparticles1, i)
			continue
		end
		vel:Add(ent:GetVelocity())
		posSet:Set(hitPos + normal * 0.5)
	end
end

hook.Add("PostCleanupMap", "zcblood_physics", function()
	stack, stackCount = {}, 0
end)
