--[[
	Z-City duct tape bridge.

	weapon_ducttape already welds ragdoll bones / props / doors. Players cannot
	stand while FakeRagdoll.DuctTape still has bonds — Should Fake Up "DuctTaped"
	wears the tape down and returns false. ZCNPC wake-up never asked that hook, so
	a taped NPC stood up through the welds and the ragdoll was deleted under them.

	We do not edit Z-City. WakeUp is wrapped (same wear-down as the player hook),
	the downed monitor tracks the lock so cutting the tape unlocks standing, and
	Artagdoll stays pinned to the floor while bonds remain.
]]

local function TapeTable(rag)
	if not IsValid(rag) then return end

	local dtape = rag.DuctTape
	if not istable(dtape) then return end
	if not next(dtape) then return end

	return dtape
end

function ZCNPC.IsDuctTaped(rag)
	local dtape = TapeTable(rag)
	if not dtape then return false end

	for _, tbl in pairs(dtape) do
		if istable(tbl) and (tbl[2] or 0) > 0 then
			return true
		end
	end

	return next(dtape) ~= nil
end

-- Mirrors weapon_ducttape.lua "Should Fake Up" / "DuctTaped". True = still held.
local function WearTape(rag)
	local dtape = TapeTable(rag)
	if not dtape then return false end

	for i, tbl in pairs(dtape) do
		if istable(tbl) and (tbl[2] or 0) > 0 then
			tbl[2] = tbl[2] - 0.2
			rag:EmitSound("tape_friction" .. math.random(3) .. ".mp3", 65)

			if tbl[2] <= 0 then
				if IsValid(tbl[1]) then
					tbl[1]:Remove()
					tbl[1] = nil
				end

				dtape[i] = nil
			end

			break
		end
	end

	return next(dtape) ~= nil
end

-- Called from the downed monitor: remember the lock, and when the last bond is
-- cut (melee / slash / wear) shorten wakeAfter so they can stand shortly after.
function ZCNPC.DuctTapeTick(rag, info)
	if not (IsValid(rag) and istable(info)) then return false end

	local taped = ZCNPC.IsDuctTaped(rag)

	if info.zcnpc_ductlock and not taped then
		local elapsed = CurTime() - (info.downAt or CurTime())
		info.wakeAfter = math.min(info.wakeAfter or 999, elapsed + 0.35)
		ZCNPC.Debug("duct tape released", IsValid(info.npc) and info.npc or rag)
	end

	info.zcnpc_ductlock = taped

	return taped
end

function ZCNPC.InstallDuctTape()
	if ZCNPC.__ducttape_wrapped then return true end

	local oldWake = ZCNPC.WakeUp
	if not isfunction(oldWake) then return false end

	ZCNPC.__ducttape_wrapped = true

	function ZCNPC.WakeUp(rag, info)
		if ZCNPC.Enabled() and WearTape(rag) then
			-- Same pacing as the player hook (fakecd + 1s): do not grind every monitor tick.
			if istable(info) then
				local elapsed = CurTime() - (info.downAt or CurTime())
				info.wakeAfter = math.max(info.wakeAfter or 0, elapsed + 1)
				info.zcnpc_ductlock = true
			end

			ZCNPC.Debug("duct tape holding", IsValid(info and info.npc) and info.npc or rag)

			return
		end

		if istable(info) then
			info.zcnpc_ductlock = false
		end

		return oldWake(rag, info)
	end

	ZCNPC.Debug("Duct Tape bridge armed")

	return true
end

hook.Add("InitPostEntity", "zcnpc_ducttape_retry", function()
	if ZCNPC.InstallDuctTape then ZCNPC.InstallDuctTape() end
end)

timer.Create("zcnpc_ducttape_retry", 2, 10, function()
	if not ZCNPC.InstallDuctTape then return end
	if ZCNPC.InstallDuctTape() then
		timer.Remove("zcnpc_ducttape_retry")
	end
end)
