local CUT_REACH = 80
local CUT_RADIUS = 5
local CUT_TIME = 1.5
local CUT_SAMPLES = 12
local SLIP_CHANCE = 0.04
local CLUMSY_SLIP_CHANCE = 0.5

local function IsSharp(wep)
	return IsValid(wep) and bit.band(tonumber(wep.DamageType) or 0, DMG_SLASH) ~= 0
end

local function IsLiveTrap(ent)
	if not ent.DisarmTrap or ent.timer or ent.Disarmed or ent.Exploded or not ent.lpos or not ent.trapSetTime then return false end
	if not (IsValid(ent.ent) or ent.ent == Entity(0)) then return false end
	return CurTime() - ent.trapSetTime >= (ent.TrapSettleTime or 1.5)
end

local function AimedTrap(ply)
	local eye = ply:EyePos()
	local aim = ply:GetAimVector()
	local best, bestDist, bestPoint

	for _, ent in ipairs(ents.FindInSphere(eye, CUT_REACH + 200)) do
		if not IsLiveTrap(ent) then continue end

		local a = ent:GetPos()
		local b = ent.ent:LocalToWorld(ent.lpos)
		for i = 0, CUT_SAMPLES do
			local p = LerpVector(i / CUT_SAMPLES, a, b)
			local t = (p - eye):Dot(aim)
			if t <= 0 or t > CUT_REACH then continue end

			local d = p:Distance(eye + aim * t)
			if d < CUT_RADIUS and (not bestDist or d < bestDist) then
				best, bestDist, bestPoint = ent, d, p
			end
		end
	end

	if not best then return end

	local tr = util.TraceLine({start = eye, endpos = bestPoint, mask = MASK_SOLID_BRUSHONLY})
	if tr.Hit then return end

	return best, bestPoint
end

local function FinishCut(ply, trap, point)
	local chance = ply:HasTrait("clumsy") and CLUMSY_SLIP_CHANCE or SLIP_CHANCE
	sound.Play("npc/roller/blade_cut.wav", point, 60, math.random(140, 160), 0.6)

	if math.Rand(0, 1) < chance then
		trap:Arm(CurTime() - trap.timeToBoom + 1)
	else
		trap:DisarmTrap()
	end
end

timer.Create("HGTripwireCut", 0.1, 0, function()
	local now = CurTime()

	for _, ply in player.Iterator() do
		local state = ply.HGTripwireCut

		if not ply:Alive() or not ply:KeyDown(IN_ATTACK2) or hg.GetCurrentCharacter(ply) ~= ply or not IsSharp(ply:GetActiveWeapon()) then
			ply.HGTripwireCut = nil
			continue
		end

		local trap, point = AimedTrap(ply)
		if not trap then
			ply.HGTripwireCut = nil
			continue
		end

		if not state or state.trap ~= trap then
			ply.HGTripwireCut = {trap = trap, start = now}
			continue
		end

		if now - state.start >= CUT_TIME then
			ply.HGTripwireCut = nil
			FinishCut(ply, trap, point)
		end
	end
end)
