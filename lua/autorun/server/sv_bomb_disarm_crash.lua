hg = hg or {}

local CRASH_DELAY = 6
local CLOSE_WINDOW = 20
local NOTIFY_CLOSENESS = 0.5
local STAMINA_DRAIN_MAX = 0.9

function hg.BombDisarmCrash(ply, timeLeft)
	if not IsValid(ply) then return end

	local closeness = 1 - math.Clamp((timeLeft or CLOSE_WINDOW) / CLOSE_WINDOW, 0, 1)
	local name = "hg_bomb_disarm_crash_" .. ply:EntIndex()

	timer.Create(name, CRASH_DELAY, 1, function()
		if not IsValid(ply) or not ply:Alive() then return end

		local org = ply.organism
		if not org then return end

		org.adrenalineAdd = math.min(org.adrenalineAdd or 0, 0)
		org._adrenalineHoldUntil = 0
		org.adrenaline = 0

		if closeness > 0 and org.stamina then
			hg.organism.ConsumeStamina(org, org.stamina.range * STAMINA_DRAIN_MAX * closeness)
		end

		if closeness >= NOTIFY_CLOSENESS then
			ply:Notify("Holy shit- that was close...", 6, "bomb_disarm", 0, nil, Color(200, 190, 255))
		end
	end)
end
