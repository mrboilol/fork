local hg_ragdoll_rest = CreateConVar("hg_ragdoll_rest", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "rest/friction assist on fake ragdolls", 0, 1)

local REST_LIN = 4
local REST_ANG = 5
local REST_MAX_SPEED = 35
local REST_GROUND_TRACE = 30
local REST_MAX_DTIME = 0.05

local function isFloppyBone(ragdoll, physNum)
	local floppy = ragdoll.hg_floppy_bones
	if not floppy then return false end
	local bone = ragdoll:TranslatePhysBoneToBone(physNum)
	if bone < 0 then return false end
	return floppy[ragdoll:GetBoneName(bone)] == true
end

hook.Add("Think", "HG_PhysicsRest", function()
	if not hg_ragdoll_rest:GetBool() then return end

	local now = SysTime()
	for i, ply in player.Iterator() do
		local ragdoll = ply.FakeRagdoll
		if not IsValid(ragdoll) then continue end
		if ragdoll.isSliding or ragdoll.isDropkicking or ragdoll.hgStumbleActive or ragdoll.hgStumblePending then continue end
		if not ply:Alive() then continue end

		local rootPhys = ragdoll:GetPhysicsObject()
		if not IsValid(rootPhys) then continue end
		if rootPhys:GetVelocity():Length() > REST_MAX_SPEED then continue end

		if hg.KeyDown(ply, IN_FORWARD) or hg.KeyDown(ply, IN_BACK) or
			hg.KeyDown(ply, IN_MOVELEFT) or hg.KeyDown(ply, IN_MOVERIGHT) or
			hg.KeyDown(ply, IN_USE) or hg.KeyDown(ply, IN_ATTACK) or hg.KeyDown(ply, IN_ATTACK2) or hg.KeyDown(ply, IN_DUCK) then
			continue
		end

		if ragdoll.hgTensionUntil and ragdoll.hgTensionUntil > now then continue end
		if ragdoll.hgSettleUntil and ragdoll.hgSettleUntil > now then continue end
		if ragdoll.hgWoundGrab or ragdoll.hgWallGrab or ragdoll.hgGetUp then continue end

		local rootPos = rootPhys:GetPos()
		if not util.TraceLine({
			start = rootPos,
			endpos = rootPos - vector_up * REST_GROUND_TRACE,
			filter = {ply, ragdoll},
			mask = MASK_SOLID,
		}).Hit then continue end

		local dtime = math.min((now - (ragdoll.hgRestLast or now)) * game.GetTimeScale(), REST_MAX_DTIME)
		ragdoll.hgRestLast = now
		if dtime <= 0 then continue end

		local linK = math.min(REST_LIN * dtime, 1)
		local angK = math.min(REST_ANG * dtime, 1)

		for j = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			if isFloppyBone(ragdoll, j) then continue end
			local phys = ragdoll:GetPhysicsObjectNum(j)
			if not IsValid(phys) then continue end

			local lv = phys:GetVelocity()
			if lv:LengthSqr() > 4 then
				phys:AddVelocity(Vector(-lv.x * linK, -lv.y * linK, 0))
			end

			local av = phys:GetAngleVelocity()
			if av:LengthSqr() > 1 then
				phys:AddAngleVelocity(-av * angK)
			end
		end
	end
end)
