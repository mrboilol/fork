local hg_selfpreservation = ConVarExists("hg_selfpreservation") and GetConVar("hg_selfpreservation") or CreateConVar("hg_selfpreservation", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "controls stumbling and cool wound holding", 0, 1)
local function euphoriaOn(cvar) return hg_selfpreservation:GetBool() and cvar:GetBool() end

local hg_impact = CreateConVar("hg_euphoria_impact", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "GTA/Ready-or-Not style impact reactions on fake ragdolls (knockback + trip)", 0, 1)

local IMPACT_MIN_DMG = 10
local IMPACT_KNOCKBACK = 70
local IMPACT_BONE_PUSH = 90
local IMPACT_BONE_DIST = 150
local IMPACT_TRIP_PUSH = 90
local IMPACT_TRIP_DOWN = 120
local IMPACT_TRIP_ROLL = 180
local IMPACT_TICK_BUDGET = 2
local IMPACT_UP_RATIO = 0.35
local IMPACT_UP_BASE = 0.15
local IMPACT_LIGHT_PUSH = 35
local IMPACT_MID_PUSH = 60

local function nearestImpactPhys(ragdoll, pos)
	local best, bestDist, bestNum
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end
		local dist = phys:GetPos():Distance(pos)
		if not bestDist or dist < bestDist then
			best, bestDist, bestNum = phys, dist, i
		end
	end
	return best, bestDist, bestNum
end

local function partPushCap(ragdoll, physNum)
	local bone = ragdoll:TranslatePhysBoneToBone(physNum)
	local name = bone and bone >= 0 and ragdoll:GetBoneName(bone) or ""
	if string.find(name, "_Hand", 1, true) or string.find(name, "_Foot", 1, true) or string.find(name, "_Toe", 1, true) then return IMPACT_LIGHT_PUSH end
	if string.find(name, "Head", 1, true) or string.find(name, "Neck", 1, true) or string.find(name, "_Forearm", 1, true) or string.find(name, "_Calf", 1, true) then return IMPACT_MID_PUSH end
end

local function takeBudget(ragdoll, strength)
	local tick = engine.TickCount()
	if ragdoll.hgImpactTick ~= tick then
		ragdoll.hgImpactTick = tick
		ragdoll.hgImpactBudget = IMPACT_TICK_BUDGET
	end
	local take = math.min(strength, ragdoll.hgImpactBudget)
	ragdoll.hgImpactBudget = ragdoll.hgImpactBudget - take
	return take
end

local function movingDir(ply)
	local f, b, l, r = hg.KeyDown(ply, IN_FORWARD), hg.KeyDown(ply, IN_BACK), hg.KeyDown(ply, IN_MOVELEFT), hg.KeyDown(ply, IN_MOVERIGHT)
	if not (f or b or l or r) then return nil end

	local ang = ply:EyeAngles()
	local dir = Vector(0, 0, 0)
	if f then dir = dir + ang:Forward() end
	if b then dir = dir - ang:Forward() end
	if l then dir = dir - ang:Right() end
	if r then dir = dir + ang:Right() end
	dir.z = 0
	if dir:LengthSqr() < 0.01 then return nil end
	return dir:GetNormalized()
end

hook.Add("EntityTakeDamage", "HG_EuphoriaImpact", function(ent, dmgInfo)
	if not euphoriaOn(hg_impact) then return end
	if not IsValid(ent) then return end

	local ply, ragdoll
	if ent:IsPlayer() then
		if not ent:Alive() then return end
		ragdoll = ent.FakeRagdoll
		if not IsValid(ragdoll) then return end
		ply = ent
	elseif ent:IsRagdoll() then
		ply = hg.RagdollOwner(ent)
		if not IsValid(ply) then return end
		ragdoll = ent
	else
		return
	end

	local dmgType = dmgInfo:GetDamageType()
	if bit.band(dmgType, DMG_FALL + DMG_CRUSH + DMG_BURN + DMG_POISON + DMG_DROWN) ~= 0 then return end

	local dmg = dmgInfo:GetDamage()
	if dmg < IMPACT_MIN_DMG then return end

	local root = ragdoll:GetPhysicsObject()
	if not IsValid(root) then return end

	local strength = takeBudget(ragdoll, math.Clamp(dmg / 30, 0.4, 1.6))
	if strength <= 0 then return end

	local rootPos = root:GetPos()
	local hitPos = dmgInfo:GetDamagePosition()

	local dir = dmgInfo:GetDamageForce()
	if dir:LengthSqr() <= 1 then
		if hitPos and hitPos:Distance(rootPos) > 1 then
			dir = rootPos - hitPos
		else
			dir = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.3, 0.6))
		end
	end
	if dir:LengthSqr() <= 1 then return end
	dir = dir:GetNormalized()
	local side = math.sqrt(dir.x * dir.x + dir.y * dir.y)
	local maxUp = IMPACT_UP_RATIO * side + IMPACT_UP_BASE
	if dir.z > maxUp then
		dir.z = maxUp
		dir:Normalize()
	end

	local flatDir = Vector(dir.x, dir.y, 0)
	if flatDir:LengthSqr() > 0.01 then flatDir = flatDir:GetNormalized() else flatDir = Vector(0, 0, 0) end

	root:AddVelocity(flatDir * IMPACT_KNOCKBACK * strength)

	if hitPos and hitPos:Distance(rootPos) < 200 then
		local hitPhys, hitDist, hitNum = nearestImpactPhys(ragdoll, hitPos)
		if hitPhys and hitDist < IMPACT_BONE_DIST then
			local push = IMPACT_BONE_PUSH * strength
			local cap = partPushCap(ragdoll, hitNum)
			if cap and push > cap then
				hitPhys:AddVelocity(dir * cap)
				local chest = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 1))
				if IsValid(chest) and chest ~= hitPhys then chest:AddVelocity(dir * (push - cap)) end
			else
				hitPhys:AddVelocity(dir * push)
			end
		end
	end

	ragdoll.hgTensionLinear = false

	local moveDir = movingDir(ply)
	if moveDir then
		local spine = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 1))
		local pelvis = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 0))
		if IsValid(spine) then
			spine:AddVelocity(moveDir * IMPACT_TRIP_PUSH * strength + Vector(0, 0, -IMPACT_TRIP_DOWN * strength))
			local axis = moveDir:Cross(Vector(0, 0, 1))
			if axis:LengthSqr() > 0.01 then
				spine:AddAngleVelocity(-axis * IMPACT_TRIP_ROLL * strength)
			end
		end
		if IsValid(pelvis) then
			pelvis:AddVelocity(moveDir * IMPACT_TRIP_PUSH * 0.6 * strength)
		end
	end
end)