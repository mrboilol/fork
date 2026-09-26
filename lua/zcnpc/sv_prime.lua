--[[
	First-join ragdoll.

	Z-City's client FakeRagdoll proxy and the world-model path only finish
	after one get-up. Until then the guns in your hands are invisible and
	the first ragdoll camera has nothing to follow. Drop the player for a
	tenth of a second the first time they spawn on the server, then stand
	them back up. After that the real ragdolls work.
]]

local HOLD = 0.1
local FIRST_WAIT = 0.2
local RETRY = 0.2
local TRIES = 15

local function Ready(ply)
	if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) then return false end
	if ply:InVehicle() then return false end
	if isentity(ply.FakeRagdoll) and IsValid(ply.FakeRagdoll) then return false end
	if ply:GetMoveType() == MOVETYPE_NONE then return false end
	if not (istable(hg) and isfunction(hg.Fake) and isfunction(hg.FakeUp)) then return false end
	if not istable(ply.organism) then return false end

	return true
end

local function Stand(ply, pos, ang)
	if not IsValid(ply) then return end
	if not ply:Alive() then return end
	if not (isentity(ply.FakeRagdoll) and IsValid(ply.FakeRagdoll)) then return end

	hg.FakeUp(ply, true, true)
	ply:ConCommand("-duck")

	if pos then ply:SetPos(pos) end
	if ang then ply:SetEyeAngles(ang) end
end

local function Drop(ply)
	if not Ready(ply) then return false end

	local pos, ang = ply:GetPos(), ply:EyeAngles()

	ply.zcnpc_priming = true
	hg.Fake(ply)

	if not (isentity(ply.FakeRagdoll) and IsValid(ply.FakeRagdoll)) then
		ply.zcnpc_priming = nil

		return false
	end

	timer.Simple(HOLD, function()
		if not IsValid(ply) then return end

		Stand(ply, pos, ang)
		ply.zcnpc_priming = nil
		ply.zcnpc_primesched = nil
		ply.zcnpc_needprime = nil
		ply.zcnpc_primed = true
	end)

	return true
end

local function Schedule(ply)
	if not IsValid(ply) then return end
	if ply.zcnpc_primed or ply.zcnpc_priming or ply.zcnpc_primesched then return end

	ply.zcnpc_primesched = true

	local tries = 0

	local function try()
		if not IsValid(ply) then return end
		if ply.zcnpc_primed or ply.zcnpc_priming then return end
		if Drop(ply) then return end

		tries = tries + 1
		if tries < TRIES then
			timer.Simple(RETRY, try)
		else
			ply.zcnpc_primesched = nil
		end
	end

	timer.Simple(FIRST_WAIT, try)
end

hook.Add("PlayerInitialSpawn", "zcnpc_prime", function(ply)
	ply.zcnpc_needprime = true
end)

-- Z-City's own spawn hook: organism and loadout are already on the player.
-- FakeUp sets OverrideSpawn, so the get-up Spawn() does not run this again.
hook.Add("Player Spawn", "zcnpc_prime", function(ply)
	if ply.zcnpc_primed or ply.zcnpc_priming then return end
	if not ply.zcnpc_needprime then return end

	Schedule(ply)
end)

-- Addon loaded after the first spawn already happened (Homigrad came up late).
for _, ply in ipairs(player.GetAll()) do
	if ply:Alive() and not ply.zcnpc_primed then
		ply.zcnpc_needprime = true
		Schedule(ply)
	end
end
