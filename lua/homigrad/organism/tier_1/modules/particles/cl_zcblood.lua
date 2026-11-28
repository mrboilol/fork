ZCBlood = ZCBlood or {}

local util_TraceLine = util.TraceLine
local table_remove = table.remove

local hg_supercheapblood = ConVarExists("hg_supercheapblood") and GetConVar("hg_supercheapblood") or CreateClientConVar("hg_supercheapblood", 0, true, false, "0 = advanced blood, 1 = cheapest old Z-City blood, 2 = ZCici blood (1 and 2 turn AdvancedBlood off)", 0, 2)

local function isActive()
	return hg_supercheapblood:GetInt() == 2
end

local dropFit = {0.1289, 0.1875, 0.1836, 0.2305, nil, 0.1289, 0.3203, 0.1406, 0.1211, 0.1016, 0.1875}
local dropTierScale = 0.07

local function scaleDrops()
	for tier = 1, 5 do
		for shape, fit in pairs(dropFit) do
			Material("zcblood/drops/drop" .. shape .. "_" .. tier):SetFloat("$decalscale", tier * dropTierScale * fit)
		end
	end
end

scaleDrops()
hook.Add("InitPostEntity", "zcblood_dropscale", scaleDrops)

local landFloorZ = 0.7
local landMemory = 4
local landings = {}

local engineDecal = util.ZCBloodEngineDecal or util.Decal
util.ZCBloodEngineDecal = engineDecal

function util.Decal(name, start, finish, filter)
	local mapped = isActive() and ZCBlood.DecalMap[name]
	if mapped then
		name = mapped

		local normal = (start - finish):GetNormalized()
		if IsValid(filter) and normal.z > landFloorZ then
			landings[filter] = {pos = (start + finish) * 0.5, time = CurTime()}
		end
	end

	return engineDecal(name, start, finish, filter)
end

local poolShapes = 6
local poolBaseMat = "zcblood/pools/blood"
local poolWetMat = "zcblood/wet/puddle_human"
local poolMinSize, poolMaxSize = 5, 80
local poolSizePerMl = 0.6
local poolSpreadRate, poolSpreadShare = 25, 0.5
local poolStillSpeed, poolStillTime = 5, 3
local poolMoveBreak = 64
local poolDieScale = 100
local poolAlpha, poolWetAlpha = 255, 225
local poolLife, poolFade = 300, 10
local poolCap = 160
local poolFallbackBone = "ValveBiped.Bip01_Spine"
local arterialWeight = 3
local landFallback = 5
local poolJoinDist = 16

local pools = {}
local tracking = {}

local function isSolid(pos)
	return bit.band(util.PointContents(pos), CONTENTS_SOLID) == CONTENTS_SOLID
end

local function maxPoolSize(pos, limit)
	for size = 1, limit do
		for x = -1, 1 do
			for y = -1, 1 do
				if x ~= 0 or y ~= 0 then
					local spot = pos + Vector(x * size, y * size, 0)
					local start = spot + vector_up
					if not isSolid(start) and not util_TraceLine({start = start, endpos = spot - vector_up * 4, mask = MASK_DEADSOLID}).Hit then
						return size - 1
					end
				end
			end
		end
	end

	return limit
end

local function bleedingPos(ent, wounds, arterial)
	local best, bestFlow

	for _, wound in pairs(wounds or {}) do
		local flow = wound[1] or 0
		if flow > 0 and (not bestFlow or flow > bestFlow) then best, bestFlow = wound, flow end
	end
	for _, wound in pairs(arterial or {}) do
		local flow = (wound[1] or 0) * arterialWeight
		if flow > 0 and (not bestFlow or flow > bestFlow) then best, bestFlow = wound, flow end
	end

	local pos = best and hg.organism.GetWoundTransform(ent, best)
	if pos then return pos end

	local bone = ent:LookupBone(poolFallbackBone)
	return bone and ent:GetBonePosition(bone) or ent:GetPos()
end

local function removePool(pool)
	for _, particle in ipairs(pool.particles) do
		particle:SetLifeTime(0)
		particle:SetDieTime(0.05)
		particle:SetStartSize(0)
		particle:SetEndSize(0)
	end
	pool.dead = true
end

local function addLayer(emitter, mat, pos, ang, size, alpha, lit)
	local particle = emitter:Add(mat, pos)
	particle:SetStartSize(0)
	particle:SetEndSize(size)
	particle:SetDieTime(poolDieScale)
	particle:SetLifeTime(0)
	particle:SetStartAlpha(alpha)
	particle:SetEndAlpha(alpha)
	particle:SetAngles(ang)
	if lit then particle:SetLighting(true) end
	return particle
end

local function poolRadius(pool)
	return math.min(math.sqrt(pool.shown) * poolSizePerMl, pool.size)
end

local function poolAt(pos)
	for _, pool in ipairs(pools) do
		if not pool.dead then
			local reach = poolRadius(pool) + poolJoinDist
			if pos:DistToSqr(pool.pos) < reach * reach then return pool end
		end
	end
end

local function startPool(ent, from)
	local trace = util_TraceLine({start = from + vector_up * 16, endpos = from - vector_up * 128, mask = MASK_DEADSOLID, filter = ent})
	if not trace.Hit then return end

	local size = maxPoolSize(trace.HitPos, poolMaxSize)
	if size < poolMinSize then return end

	local ang = trace.HitNormal:Angle()
	ang.roll = math.random(0, 360)

	local emitter = ParticleEmitter(trace.HitPos, true)
	local shape = math.random(poolShapes)
	local base = addLayer(emitter, poolBaseMat .. shape, trace.HitPos + trace.HitNormal * 0.1, ang, size, poolAlpha, true)
	local wet = addLayer(emitter, poolWetMat .. shape, trace.HitPos + trace.HitNormal * 0.2, ang, size, poolWetAlpha)
	emitter:Finish()

	if #pools >= poolCap then removePool(table_remove(pools, 1)) end

	local pool = {particles = {base, wet}, pos = trace.HitPos, size = size, volume = 0, shown = 0, grown = CurTime()}
	pools[#pools + 1] = pool
	return pool
end

local function recentLanding(ent, owner)
	local best
	for _, key in ipairs({ent, owner}) do
		local land = landings[key]
		if land and CurTime() - land.time < landMemory and (not best or land.time > best.time) then best = land end
	end

	if best and best.pos:DistToSqr(ent:GetPos()) < poolMoveBreak * poolMoveBreak then return best.pos end
end

local function feedPool(ent, bleed, wounds, arterial, dt, owner)
	local state = tracking[ent]
	if not state then
		state = {}
		tracking[ent] = state
	end

	if ent:GetVelocity():Length() > poolStillSpeed then
		state.stillSince = nil
		return
	end

	state.stillSince = state.stillSince or CurTime()
	if bleed <= 0 or CurTime() - state.stillSince < poolStillTime then return end

	local landed = recentLanding(ent, owner)
	local pool = state.pool
	while pool and pool.mergedInto do pool = pool.mergedInto end
	if pool and (pool.dead or ent:GetPos():DistToSqr(pool.pos) > poolMoveBreak * poolMoveBreak) then pool = nil end
	if pool and landed then
		local reach = poolRadius(pool) + poolJoinDist
		if landed:DistToSqr(pool.pos) > reach * reach then pool = nil end
	end
	if not pool then
		local from = landed or CurTime() - state.stillSince > poolStillTime + landFallback and bleedingPos(ent, wounds, arterial)
		if not from then return end
		pool = poolAt(from) or startPool(ent, from)
		state.pool = pool
		if not pool then return end
	end

	pool.volume = pool.volume + bleed * dt
	pool.grown = CurTime()
end

local function mergePools()
	for i = #pools, 1, -1 do
		local small = pools[i]
		if not small.dead then
			for _, big in ipairs(pools) do
				if big ~= small and not big.dead then
					local reach = math.max(poolRadius(big), poolRadius(small))
					if big.shown >= small.shown and small.pos:DistToSqr(big.pos) < reach * reach then
						big.volume = big.volume + small.volume
						big.shown = big.shown + small.shown
						big.grown = math.max(big.grown, small.grown)
						small.mergedInto = big
						removePool(small)
						break
					end
				end
			end
		end
	end
end

local function holdPools(dt)
	local time = CurTime()
	mergePools()

	for i = #pools, 1, -1 do
		local pool = pools[i]
		local age = time - pool.grown

		if pool.dead or age > poolLife + poolFade then
			if not pool.dead then removePool(pool) end
			table_remove(pools, i)
		else
			pool.shown = math.Approach(pool.shown, pool.volume, math.max(poolSpreadRate, (pool.volume - pool.shown) * poolSpreadShare) * dt)
			local frac = math.min(math.sqrt(pool.shown) * poolSizePerMl / pool.size, 0.999)
			local fade = age > poolLife and 1 - (age - poolLife) / poolFade or 1

			for n, particle in ipairs(pool.particles) do
				particle:SetLifeTime(frac * poolDieScale)
				if fade < 1 then
					local alpha = (n == 1 and poolAlpha or poolWetAlpha) * fade
					particle:SetStartAlpha(alpha)
					particle:SetEndAlpha(alpha)
				end
			end
		end
	end
end

local lastPoolThink = CurTime()

hook.Add("Think", "zcblood_pools", function()
	local time = CurTime()
	local dt = time - lastPoolThink
	lastPoolThink = time
	if not isActive() then return end

	local fakes = {}

	for _, ply in player.Iterator() do
		if ply:Alive() then
			local rag = ply:GetNWEntity("FakeRagdoll")
			local ent = IsValid(rag) and rag or ply
			fakes[ent] = true
			feedPool(ent, ply:GetNW2Float("zcbBleed", 0), ent.wounds or ply.wounds, ent.arterialwounds or ply.arterialwounds, dt, ply)
		end
	end

	for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
		local bleed = rag:GetNW2Float("zcbBleed", 0)
		if bleed > 0 and not fakes[rag] then
			feedPool(rag, bleed, rag.wounds, rag.arterialwounds, dt)
		end
	end

	for ent in pairs(tracking) do
		if not IsValid(ent) then tracking[ent] = nil end
	end

	for ent, land in pairs(landings) do
		if not IsValid(ent) or time - land.time > landMemory then landings[ent] = nil end
	end

	holdPools(dt)
end)

local printMats = {[0] = Material("zcblood/footprints/left"), [1] = Material("zcblood/footprints/right")}
local printSize = {[0] = {12, 28}, [1] = {9.5, 28}}
local printColor = Color(90, 7, 6)
local printSteps = 12
local printLife, printFade = 60, 5
local printStance = 6
local printPoolReach = 0.8
local printCap = 1200

local floorPrints = {}

local function inPool(pos)
	for _, pool in ipairs(pools) do
		if not pool.dead then
			local radius = poolRadius(pool) * printPoolReach
			if radius > 0 and pos:DistToSqr(pool.pos) < radius * radius then return true end
		end
	end
	return false
end

local function stepYaw(ply)
	local eyeYaw = ply:EyeAngles().y
	local vel = ply:GetVelocity()
	if vel:Length2D() <= 10 then return eyeYaw end

	local diff = math.NormalizeAngle(vel:Angle().y - eyeYaw)
	if diff > 90 then diff = 180 - diff elseif diff < -90 then diff = -180 - diff end

	return eyeYaw + diff / 2
end

hook.Add("HG_PlayerFootstep_Notify", "zcblood_prints", function(ply, pos, foot)
	if not isActive() or not IsValid(ply) then return end

	if inPool(pos) then ply.zcbBloodySteps = printSteps end

	local steps = ply.zcbBloodySteps or 0
	if steps <= 0 then return end
	ply.zcbBloodySteps = steps - 1

	local yaw = stepYaw(ply)
	local right = Angle(0, yaw, 0):Right()
	local footPos = pos + (foot == 0 and -right or right) * printStance
	local start, finish = footPos + vector_up * 10, footPos - vector_up * 50
	local trace = util_TraceLine({start = start, endpos = finish, filter = ply})
	if not trace.Hit then return end

	if not trace.Entity:IsWorld() then
		engineDecal(foot == 0 and "ZCBlood.PrintLeft" or "ZCBlood.PrintRight", start, finish, ply)
		return
	end

	if #floorPrints >= printCap then table_remove(floorPrints, 1) end
	floorPrints[#floorPrints + 1] = {
		pos = trace.HitPos + trace.HitNormal * 0.1,
		normal = trace.HitNormal,
		yaw = yaw,
		foot = foot == 0 and 0 or 1,
		strength = steps / printSteps,
		die = CurTime() + printLife,
	}
end)

local printDrawColor = Color(0, 0, 0)

hook.Add("PostDrawTranslucentRenderables", "zcblood_prints", function(depth, skybox)
	if skybox then return end

	local time = CurTime()

	for i = #floorPrints, 1, -1 do
		local step = floorPrints[i]
		local left = step.die - time

		if left <= 0 then
			table_remove(floorPrints, i)
		else
			local light = render.GetLightColor(step.pos)
			local bright = math.Clamp((light.x + light.y + light.z) / 3 * 2, 0.15, 1)

			printDrawColor.r = printColor.r * bright
			printDrawColor.g = printColor.g * bright
			printDrawColor.b = printColor.b * bright
			printDrawColor.a = 255 * step.strength * math.min(left / printFade, 1)

			local size = printSize[step.foot]
			render.SetMaterial(printMats[step.foot])
			render.DrawQuadEasy(step.pos, step.normal, size[1], size[2], printDrawColor, step.yaw)
		end
	end
end)

local function clearBlood()
	for _, pool in ipairs(pools) do removePool(pool) end
	pools = {}
	tracking = {}
	landings = {}
	floorPrints = {}

	for _, ply in player.Iterator() do
		ply.zcbBloodySteps = nil
	end
end

hook.Add("PostCleanupMap", "zcblood", clearBlood)

cvars.RemoveChangeCallback("hg_supercheapblood", "zcblood_mode")
cvars.AddChangeCallback("hg_supercheapblood", clearBlood, "zcblood_mode")

concommand.Add("zcblood_debug", function()
	local ply = LocalPlayer()
	local rag = ply:GetNWEntity("FakeRagdoll")
	local ent = IsValid(rag) and rag or ply
	local state = tracking[ent]
	local land = landings[ent] or landings[ply]

	print("[zcblood] bleed", ply:GetNW2Float("zcbBleed", -1), "speed", math.Round(ent:GetVelocity():Length(), 1), "ragdoll", IsValid(rag))
	print("[zcblood] still for", state and state.stillSince and math.Round(CurTime() - state.stillSince, 1) or "-", "has pool", state and state.pool and true or false)
	print("[zcblood] last landing", land and math.Round(CurTime() - land.time, 1) .. "s ago" or "none", "particles", hg and hg.bloodparticles1 and #hg.bloodparticles1 or "?")
	print("[zcblood] active", isActive(), "pools", #pools)
	for i, pool in ipairs(pools) do
		print("  pool", i, "size", pool.size, "volume", math.Round(pool.volume, 1), "shown", math.Round(pool.shown, 1), "radius", math.Round(poolRadius(pool), 1), "dead", pool.dead or false)
	end
end)
