-- Automated in-game test harness (developer tool).
-- Only active when garrysmod/data/abl_selftest.txt exists on the machine running the server.
-- It spawns bots, applies wounds through Z-City's own API / real bullets, poses ragdolls,
-- positions the camera and asks the (listen-server host) client to capture screenshots and
-- statistics into garrysmod/data/abl_test/. Scenario names map to docs/TESTING.md.

if not ABL.testRun then return end

util.AddNetworkString("abl_st")
file.CreateDir("abl_test")
local LOG = "abl_test/server_log.txt"
file.Write(LOG, "")

local function Log(fmt, ...)
	local s = string.format(fmt, ...)
	print("[ABL-TEST] " .. s)
	file.Append(LOG, string.format("%8.2f ", CurTime()) .. s .. "\n")
end
-- lets the rest of the addon report into the harness log (nil outside test runs)
ABL.TestLog = Log
-- every Z-City bullet wound as the harness sees it (what abl_hit is built from)
hook.Add("PreHomigradDamageBulletBleedAdd", "ABL_SelfTestWound", function(ply, org, dmgInfo, hitgroup, harm, hitBoxs, inputHole, info)
	Log("  zcity wound: %s hitgroup %s dmg %.0f bleed %s restricted %s in %s out %s", tostring(ply), tostring(hitgroup), dmgInfo:GetDamage(), tostring(istable(info) and info.bleed), tostring(istable(info) and info.restricted),
		tostring(istable(info) and istable(info.input_hole) and info.input_hole[1]), tostring(istable(info) and istable(info.output_hole) and info.output_hole[1]))
end)
hook.Add("HomigradDamage", "ABL_SelfTestDamage", function(ply, dmgInfo, hitgroup, ent)
	Log("  zcity damage: %s hitgroup %s dmg %.0f ent %s alive %s", tostring(ply), tostring(hitgroup), dmgInfo:GetDamage(), tostring(ent), tostring(IsValid(ply) and ply:IsPlayer() and ply:Alive()))
end)

local plan = string.Trim(file.Read("abl_selftest.txt", "DATA") or "all")
RunConsoleCommand("abl_dev", "1")

local co, waitUntil = nil, 0
local function Wait(t) waitUntil = CurTime() + t coroutine.yield() end

local host
local function Client(cmd, tbl)
	if not IsValid(host) then return end
	net.Start("abl_st")
	net.WriteString(cmd)
	net.WriteTable(tbl or {})
	net.Send(host)
end

------------------------------------------------------------------------------------------
-- World helpers
------------------------------------------------------------------------------------------
local used = {}
local function Clear(a, b, mask)
	local tr = util.TraceLine({ start = a, endpos = b, mask = mask or MASK_SOLID_BRUSHONLY })
	return not tr.Hit, tr
end

-- Find a flat spot at least `open` units clear around, away from spots used before.
-- opts.wall: need a vertical wall at 25..60 units; opts.ceil: need a ceiling at 90..170 units.
local FindSpot
function FindSpot(opts)
	local base = opts.base or host:GetPos()
	for ring = 0, 22 do
		local r = ring * 110
		local n = math.max(1, ring * 6)
		for k = 1, n do
			local a = k / n * math.pi * 2 + ring
			local p = base + Vector(math.cos(a) * r, math.sin(a) * r, 0)
			local okU = true
			for _, u in ipairs(used) do if u:DistToSqr(p) < 260 * 260 then okU = false break end end
			if okU then
				local tr = util.TraceLine({ start = p + Vector(0, 0, 80), endpos = p - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
				local outdoorOk = true
				if tr.Hit and opts.indoor then
					-- dim scenes: a roof overhead
					local up = util.TraceLine({ start = tr.HitPos + Vector(0, 0, 8), endpos = tr.HitPos + Vector(0, 0, 16000), mask = MASK_SOLID_BRUSHONLY })
					outdoorOk = up.Hit and not up.HitSky
				end
				if tr.Hit and opts.outdoor then
					-- bright scenes: open sky above and a hard floor (grass soaks and hides stains)
					local up = util.TraceLine({ start = tr.HitPos + Vector(0, 0, 8), endpos = tr.HitPos + Vector(0, 0, 16000), mask = MASK_SOLID_BRUSHONLY })
					outdoorOk = up.HitSky and tr.MatType ~= MAT_GRASS and tr.MatType ~= MAT_DIRT and tr.MatType ~= MAT_SAND
				end
				if outdoorOk and tr.Hit and tr.HitNormal.z > 0.97 and not tr.StartSolid and util.IsInWorld(tr.HitPos + Vector(0, 0, 40)) then
					local floor = tr.HitPos
					local head = Clear(floor + Vector(0, 0, 4), floor + Vector(0, 0, opts.ceil and 90 or 120))
					if head then
						local clearDirs, wallDir, wallDist = 0, nil, nil
						for i = 0, 7 do
							local d = Vector(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4), 0)
							local ok, t2 = Clear(floor + Vector(0, 0, 40), floor + Vector(0, 0, 40) + d * (opts.open or 110))
							if ok then clearDirs = clearDirs + 1
							elseif opts.wall and math.abs(t2.HitNormal.z) < 0.1 then
								local dist = t2.Fraction * (opts.open or 110)
								if dist > 25 and dist < 60 and not wallDir then wallDir, wallDist = d, dist end
							end
						end
						local ceilOk = true
						local ceilH
						if opts.ceil then
							local ok, t3 = Clear(floor + Vector(0, 0, 4), floor + Vector(0, 0, 170))
							ceilOk = (not ok) and t3.HitNormal.z < -0.9 and t3.Fraction * 166 > 80
							ceilH = t3.HitPos.z - floor.z
						end
						local need = opts.wall and 4 or 7
						if clearDirs >= need and ceilOk and (not opts.wall or wallDir) then
							used[#used + 1] = floor
							return floor, wallDir, wallDist, ceilH
						end
					end
				end
			end
		end
	end
	if opts.outdoor then
		-- no bright hard floor left: accept any valid spot
		opts.outdoor = nil
		return FindSpot(opts)
	end
	return nil
end

local botsUsed = {}
local function NewBot()
	local before = {}
	for _, b in ipairs(player.GetBots()) do before[b] = true end
	RunConsoleCommand("bot")
	Wait(1.5)
	for _, b in ipairs(player.GetBots()) do
		if not before[b] then botsUsed[#botsUsed + 1] = b return b end
	end
	-- server full: reuse the least recently used bot, respawned so it starts clean
	local reuse = table.remove(botsUsed, 1) or player.GetBots()[1]
	if IsValid(reuse) then
		botsUsed[#botsUsed + 1] = reuse
		reuse:Spawn()
		Wait(0.5)
		Log("  reusing %s", reuse:Nick())
		return reuse
	end
	Log("  no bot available")
end

local function Place(bot, pos, yaw)
	if not IsValid(bot) then return end
	if not bot:Alive() then bot:Spawn() end
	if IsValid(bot.FakeRagdoll) and hg and hg.FakeUp then hg.FakeUp(bot, true, true) end
	bot:SetPos(pos + Vector(0, 0, 2))
	bot:SetEyeAngles(Angle(0, yaw, 0))
	bot:SetLocalVelocity(vector_origin)
	-- engine bots wander on their own: hold them in place (the runner scenario unfreezes its bot)
	bot:Freeze(true)
	ABL.DevHeal(bot)
	timer.Simple(1, function()
		if not IsValid(bot) then Log("  place: bot vanished") return end
		Log("  place: %s alive=%s dist=%.1f fake=%s movetype=%d rendermode=%d", bot:Nick(), tostring(bot:Alive()), bot:GetPos():Distance(pos), tostring(IsValid(bot.FakeRagdoll)), bot:GetMoveType(), bot:GetRenderMode())
	end)
end

-- Host must stay alive and inside the PVS of the scene (net events use the PVS of the hit).
-- It is parked on a free standing spot near the camera with godmode; the view itself comes
-- from the client harness CalcView override.
local function ParkHost(near)
	if not host:Alive() then host:Spawn() end
	host:GodEnable()
	if istable(host.organism) then host.organism.godmode = true end
	local mins, maxs = host:GetHull()
	for _, off in ipairs({ Vector(0, 0, 0), Vector(60, 0, 0), Vector(-60, 0, 0), Vector(0, 60, 0), Vector(0, -60, 0), Vector(90, 90, 0), Vector(-90, -90, 0) }) do
		local p = near + off
		local down = util.TraceLine({ start = p + Vector(0, 0, 40), endpos = p - Vector(0, 0, 200), mask = MASK_PLAYERSOLID_BRUSHONLY })
		if down.Hit then
			local stand = down.HitPos + Vector(0, 0, 2)
			local hull = util.TraceHull({ start = stand, endpos = stand, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID, filter = host })
			if not hull.Hit then
				host:SetMoveType(MOVETYPE_WALK)
				host:SetPos(stand)
				host:SetLocalVelocity(vector_origin)
				return true
			end
		end
	end
	return false
end

-- camera: position relative to a target point, looking at it
local function View(camPos, lookAt)
	Client("view", { pos = camPos, ang = (lookAt - camPos):Angle() })
	ParkHost(Vector(camPos.x, camPos.y, lookAt.z) + (camPos - lookAt):GetNormalized() * 60)
end

local function Shot(name) Client("shot", { name = name }) Wait(0.35) end
-- same frame again with the debug overlays (wounds, beads, gravity tangents), readable in any lighting
local function DebugShot(name, mask)
	Client("debug", { mask = mask or 9 })
	Wait(0.3)
	Shot(name .. "_dbg")
	Client("debug", { mask = 0 })
end
local function Stats(name) Client("stats", { name = name }) Wait(0.1) end

local function Fake(bot)
	if hg and hg.Fake then hg.Fake(bot) end
	Wait(0.5)
	return ABL.DevRagdollOf(bot)
end

------------------------------------------------------------------------------------------
-- Scenarios
------------------------------------------------------------------------------------------
local T = {}
local order = {}
-- (scenarios named here only run when asked for by name, not as part of "all")
local onRequest = { soak = true, gunshot = true, gunshot_skin = true, gunshot_pose = true }
local function Add(name, fn) T[name] = fn if not onRequest[name] then order[#order + 1] = name end end

-- Other modules of this addon (lua/neurotrauma) bring their own scenarios and use this harness's
-- bots, camera and log. Theirs run only when asked for by name.
local driven = {}   -- bot -> function(bot, cmd): a scene of another module drives this bot
ABL.SelfTest = {
	Add = function(name, fn) onRequest[name] = true T[name] = fn end,
	Log = Log, Wait = Wait, Client = Client, NewBot = NewBot, Place = Place, View = View, Shot = Shot,
	FindSpot = function(opts) return FindSpot(opts) end,
	Host = function() return host end,
	Drive = function(bot, fn) driven[bot] = fn end,
}

Add("mesh_check", function()
	local p = FindSpot({ open = 120, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	View(p + Vector(70, 30, 50), p + Vector(0, 0, 40))
	Wait(2)
	Client("meshcheck", { ent = bot:EntIndex() })
	Wait(3)
	Shot("mesh_check")
	Client("meshcheck", { ent = -1 })
end)

-- engine capabilities the pool canvases rely on (render targets, blend ops, $distancealpha)
Add("rt_probe", function()
	Client("rtprobe", {})
	Wait(2)
end)

Add("decal_orient", function()
	local p, wallDir, wallDist = FindSpot({ open = 110, wall = true, outdoor = true })
	if not p then Log("decal_orient: no wall spot") return end
	local wallPoint = p + Vector(0, 0, 40) + wallDir * wallDist
	Client("decaltest", { floor = p, wall = wallPoint, wallNormal = -wallDir })
	Wait(1)
	View(p + Vector(0, 0, 90) - wallDir * 5, p + Vector(0.01, 0, 0))
	Wait(0.6)
	Shot("decal_orient_floor")
	View(wallPoint - wallDir * 70 + Vector(0, 0, 10), wallPoint)
	Wait(0.6)
	Shot("decal_orient_wall")
end)

Add("upright", function()
	local p = FindSpot({ open = 120, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	View(p + Vector(65, -35, 52), p + Vector(0, 0, 38))
	ABL.DevAddWound(bot, "chest", 8, false, 3, 0.55, 0.5)
	Wait(3) Shot("t01_upright_3s")
	Wait(6) Shot("t01_upright_9s") DebugShot("t01_upright_9s")
	Wait(8) Shot("t01_upright_17s") Stats("t01_upright")
end)

Add("high_wound", function()
	local p = FindSpot({ open = 120, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 90)
	View(p + Vector(40, 60, 50), p + Vector(0, 0, 36))
	-- top of the chest hitbox (Spine4 has no hitbox on most models)
	ABL.DevAddWound(bot, "chest", 14, false, 3, 0.9, 0.35)
	Wait(4) Shot("t02_high_4s") DebugShot("t02_high_4s")
	Wait(8) Shot("t02_high_12s") DebugShot("t02_high_12s") Stats("t02_high")
end)

Add("low_wound", function()
	local p = FindSpot({ open = 120, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	View(p + Vector(55, -25, 30), p + Vector(0, 0, 18))
	ABL.DevAddWound(bot, "lthigh", 10, false, 3, 0.4, 0.5)
	Wait(6) Shot("t03_low_6s") DebugShot("t03_low_6s")
	Wait(9) Shot("t03_low_15s") DebugShot("t03_low_15s") Stats("t03_low")
end)

local runBot

-- Leg / foot close-up: a wound on the outside of the thigh, viewed from that side at knee height.
-- Blood must run as a rivulet around the leg's contour, gather at the shoe and hang / drip there,
-- and stay on the leg while the character walks.
Add("leg_flow", function()
	local p = FindSpot({ open = 200, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 90)
	-- run 14: the body faced +x, so its left side (the wound, hitbox side 4) faces +y
	ABL.DevAddWound(bot, "lthigh", 12, false, 4, 0.45, 0.5)
	View(p + Vector(8, 44, 22), p + Vector(0, 0, 16))
	Wait(5) Shot("t24_leg_5s")
	Wait(7) Shot("t24_leg_12s") DebugShot("t24_leg_12s")
	View(p + Vector(10, 24, 7), p + Vector(0, 2, 3))
	Wait(4) Shot("t24_foot_16s")
	Stats("t24_leg")
	-- walking: the blood must stay on the moving leg
	View(p + Vector(-90, 40, 30), p + Vector(0, 60, 16))
	bot:Freeze(false)
	runBot = bot
	Wait(2.6) Shot("t24_leg_walk")
	runBot = nil
	bot:Freeze(true)
	Stats("t24_leg_walk")
end)
hook.Add("StartCommand", "ABL_SelfTestRun", function(ply, cmd)
	if not ply:IsBot() then return end
	cmd:ClearMovement()
	cmd:ClearButtons()
	local drive = driven[ply]
	if drive then drive(ply, cmd) return end
	if ply ~= runBot then return end
	local phase = math.floor(CurTime() / 2.2) % 2
	cmd:SetForwardMove(phase == 0 and 260 or -260)
	cmd:SetButtons(IN_SPEED)
end)

Add("running", function()
	local p = FindSpot({ open = 260, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	ABL.DevAddWound(bot, "rthigh", 16, false, 3, 0.5, 0.5)
	View(p + Vector(0, -170, 90), p + Vector(0, 0, 10))
	Wait(1)
	bot:Freeze(false)
	runBot = bot
	Wait(9)
	runBot = nil
	bot:Freeze(true)
	Shot("t04_running_trail") Stats("t04_running")
end)

Add("ragdoll_transition", function()
	local p = FindSpot({ open = 140, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	View(p + Vector(70, -40, 55), p + Vector(0, 0, 30))
	ABL.DevAddWound(bot, "chest", 12, false, 3, 0.55, 0.5)
	Wait(6) Shot("t05_before_fake")
	Fake(bot)
	Wait(2) Shot("t05_after_fake_2s")
	Wait(6) Shot("t05_after_fake_8s") Stats("t05_ragdoll")
end)

local function PoseTest(name, preset, bone, side, cam, look, times, freeze)
	local p = FindSpot({ open = 150, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	local rag = Fake(bot)
	if not IsValid(rag) then Log("%s: fake failed", name) return end
	Wait(1)
	ABL.DevPose(rag, preset, freeze)
	Wait(1.2)
	local ok, err = ABL.DevAddWound(bot, bone, 12, false, side, 0.5, 0.5)
	Log("  wound on %s: %s %s (wounds now %d, alive %s)", bone, tostring(ok), tostring(err or ""), istable(bot.organism) and #bot.organism.wounds or -1, tostring(bot:Alive()))
	View(p + cam, p + look)
	local t = 0
	for _, tt in ipairs(times) do
		Wait(tt - t) t = tt
		Shot(string.format("%s_%ds", name, tt))
		DebugShot(string.format("%s_%ds", name, tt))
	end
	Stats(name)
	if freeze then ABL.DevPose(rag, "free") end
end

Add("ragdoll_back", function() PoseTest("t06_back", "back", "chest", 3, Vector(34, 28, 44), Vector(0, 0, 6), { 4, 12, 20 }) end)
Add("ragdoll_side", function() PoseTest("t07_side", "side", "chest", 3, Vector(8, 55, 36), Vector(0, 0, 8), { 4, 12, 20 }) end)
Add("ragdoll_upside", function() PoseTest("t08_upside", "upside", "lthigh", 3, Vector(60, 0, 45), Vector(0, 0, 40), { 4, 10, 18 }, true) end)

Add("ragdoll_rotate", function()
	local p = FindSpot({ open = 180, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	ABL.DevAddWound(bot, "chest", 14, false, 3, 0.5, 0.5)
	Wait(4)
	local rag = Fake(bot)
	View(p + Vector(90, -60, 70), p + Vector(0, 0, 20))
	ABL.DevPose(rag, "spin")
	Wait(0.4) Shot("t09_spin_a")
	Wait(0.5) Shot("t09_spin_b")
	Wait(3) Shot("t09_spin_settled") Stats("t09_rotate")
end)

Add("ragdoll_fall", function()
	local p = FindSpot({ open = 180, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	ABL.DevAddWound(bot, "stomach", 16, false, 3, 0.5, 0.5)
	ABL.DevAddWound(bot, "lupperarm", 8, false, 3, 0.5, 0.5)
	Wait(4)
	local rag = Fake(bot)
	View(p + Vector(110, -70, 80), p + Vector(0, 0, 40))
	ABL.DevPose(rag, "drop")
	Wait(0.35) Shot("t10_falling")
	Wait(1.2) Shot("t11_landed")
	Wait(4) Shot("t11_after") Stats("t10_fall")
end)

Add("wall_exit", function()
	local p, wallDir, wallDist = FindSpot({ open = 110, wall = true, outdoor = true })
	if not p then Log("wall_exit: no wall spot") return end
	local bot = NewBot()
	-- bot faces away from the wall so the exit wound points at it
	Place(bot, p, (-wallDir):Angle().y)
	local wallPoint = p + Vector(0, 0, 45) + wallDir * wallDist
	View(p - wallDir * 60 + Vector(0, 0, 55) + wallDir:Cross(Vector(0, 0, 1)) * 40, wallPoint)
	Wait(1)
	ABL.DevShoot(host, bot, 35, "front", "chest")
	Wait(0.25) ABL.DevShoot(host, bot, 35, "front", "upperchest")
	Wait(1.5) Shot("t12_wall_exit_2s")
	Wait(6) Shot("t12_wall_exit_8s") Stats("t12_wall")
end)

Add("spray_wall", function()
	local p, wallDir, wallDist = FindSpot({ open = 110, wall = true, outdoor = true })
	if not p then Log("spray_wall: no wall spot") return end
	local wallPoint = p + Vector(0, 0, 50) + wallDir * wallDist
	local side = wallDir:Cross(Vector(0, 0, 1))
	-- perpendicular, oblique and glancing sprays
	Client("spray", { pos = wallPoint - wallDir * 45, dir = wallDir, speed = 260, count = 14, vol = 0.05 })
	Client("spray", { pos = wallPoint - wallDir * 30 - side * 50, dir = (wallDir * 0.5 + side):GetNormalized(), speed = 320, count = 14, vol = 0.05 })
	Client("spray", { pos = wallPoint - wallDir * 12 + side * 60 + Vector(0, 0, 10), dir = (wallDir * 0.25 - side):GetNormalized(), speed = 380, count = 12, vol = 0.05 })
	Client("spray", { pos = wallPoint - wallDir * 30 + Vector(0, 0, 30), dir = (wallDir + Vector(0, 0, 0.2)):GetNormalized(), speed = 200, count = 30, vol = 0.12 })
	View(wallPoint - wallDir * 85 + Vector(0, 0, 5), wallPoint - Vector(0, 0, 10))
	Wait(1.5) Shot("t14_wall_1s")
	Wait(6) Shot("t14_wall_7s")
	Wait(8) Shot("t14_wall_15s") Stats("t14_wall")
end)

Add("spray_ceiling", function()
	local p, _, _, ceilH = FindSpot({ open = 90, ceil = true })
	if not p then Log("spray_ceiling: no ceiling spot") return end
	-- drag limits how high drops fly: spray from 45 units under the ceiling
	Client("spray", { pos = p + Vector(0, 0, ceilH - 45), dir = Vector(0, 0, 1), speed = 320, count = 45, vol = 0.12, cone = 0.1 })
	View(p + Vector(90, 20, 30), p + Vector(0, 0, ceilH * 0.6))
	Wait(1.5) Shot("t15_ceiling_1s")
	Wait(5) Shot("t15_ceiling_6s")
	Wait(8) Shot("t15_ceiling_14s") Stats("t15_ceiling")
end)

Add("slope", function()
	local p = FindSpot({ open = 160, outdoor = true })
	local plate = ents.Create("prop_physics")
	plate:SetModel("models/hunter/plates/plate2x4.mdl")
	plate:SetPos(p + Vector(0, 0, 22))
	plate:SetAngles(Angle(18, 0, 0))
	plate:Spawn()
	local po = plate:GetPhysicsObject()
	if IsValid(po) then po:EnableMotion(false) end
	Wait(0.5)
	View(p + Vector(-10, 70, 55), p + Vector(0, 0, 22))
	-- a steady pour onto one spot of the tilted plate (~3 ml/s for 8 s, like a bleeding wound above it)
	for i = 1, 32 do
		Client("spray", { pos = p + Vector(-12, 0, 50), dir = Vector(0, 0, -1), speed = 30, count = 6, vol = 0.12, cone = 0.02 })
		Wait(0.25)
		if i == 16 then Shot("t13_slope_4s") end
	end
	Wait(2) Shot("t13_slope_10s") DebugShot("t13_slope_10s", 48)
	Wait(10) Shot("t13_slope_20s") Stats("t13_slope")
	Wait(1)
	plate:Remove()
end)

-- Ground impact stains: tiny spatter, drips from different heights, heavy impacts and glancing
-- drops on a hard floor. The same pattern is laid again with fast drying to see dried stains.
local function GroundPattern(p)
	Client("spray", { pos = p + Vector(-14, 10, 30), dir = Vector(0.2, 0, -1), speed = 160, count = 45, vol = 0.002, cone = 0.45 })
	for i = 0, 5 do
		Client("spray", { pos = p + Vector(-10 + i * 4, -6, 18 + i * 10), dir = Vector(0, 0, -1), speed = 5, count = 1, vol = 0.05 + i * 0.01, cone = 0 })
	end
	for i = 0, 2 do
		Client("spray", { pos = p + Vector(9, -12 + i * 10, 40), dir = Vector(0, 0, -1), speed = 420, count = 1, vol = 0.3, cone = 0 })
	end
	Client("spray", { pos = p + Vector(-22, 14, 8), dir = Vector(1, 0, -0.35):GetNormalized(), speed = 330, count = 8, vol = 0.06, cone = 0.06 })
end

Add("ground_stains", function()
	local p = FindSpot({ open = 140, outdoor = true })
	View(p + Vector(-30, -30, 62), p)
	GroundPattern(p)
	Wait(2.5) Shot("t22_ground_fresh")
	View(p + Vector(-10, -10, 30), p + Vector(-2, 0, 0))
	Wait(0.6) Shot("t22_ground_close")
	View(p + Vector(40, 26, 7), p + Vector(0, -4, 0))
	Wait(0.6) Shot("t22_ground_grazing")
	local p2 = p + Vector(0, 70, 0)
	RunConsoleCommand("abl_drying_scale", "0.05")
	Wait(0.3)
	GroundPattern(p2)
	Wait(10)
	View(p2 + Vector(-30, -30, 62), p2)
	Wait(0.6) Shot("t22_ground_dried")
	RunConsoleCommand("abl_drying_scale", "1")
	Stats("t22_ground")
end)

-- Many drops raining on one area with a low cap: variety between neighbours, and the cap holds.
Add("ground_rain", function()
	local p = FindSpot({ open = 140, outdoor = true })
	Client("cvar", { name = "abl_max_ground_stains", value = "120" })
	View(p + Vector(-40, -40, 80), p)
	for _ = 1, 20 do
		Client("spray", { pos = p + Vector(0, 0, 60), dir = Vector(0, 0, -1), speed = 60, count = 15, vol = 0.03, cone = 0.2, area = 18 })
		Wait(0.2)
	end
	Wait(2) Shot("t23_ground_rain") Stats("t23_ground_rain")
	Client("cvar", { name = "abl_max_ground_stains", value = "320" })
end)

-- wound on the back of a body lying face up: blood must seep out underneath and pool around it
Add("back_wound", function()
	local p = FindSpot({ open = 150, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	local rag = Fake(bot)
	if not IsValid(rag) then Log("back_wound: fake failed") return end
	Wait(1)
	ABL.DevPose(rag, "back")
	Wait(1.2)
	ABL.DevAddWound(bot, "chest", 16, false, 4, 0.5, 0.5)
	ABL.DevAddWound(bot, "stomach", 10, false, 4, 0.5, 0.4)
	View(p + Vector(30, 35, 70), p + Vector(0, 0, 0))
	Wait(6) Shot("t21_back_wound_6s")
	Wait(10) Shot("t21_back_wound_16s") DebugShot("t21_back_wound_16s", 41)
	Wait(10) Shot("t21_back_wound_26s") Stats("t21_back_wound")
end)

-- The pool liquid on its own: volume kept, where a volume comes to rest, what a step and a
-- repaint cost (client log lines "poolsim ...").
onRequest.poolsim = true
Add("poolsim", function()
	Client("clear", {})
	Wait(0.5)
	Client("poolsim", {})
	Wait(6)
end)

-- Ground pools. A gallery of all ten families side by side (fully spread), close-ups, then the
-- same pools through drying; a real pour that grows one pool (lobes, satellites) and then merges
-- it with a second one; a pool against a wall; a pool reaching the edge of a raised plate.
local FAMS = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J" }
local FAM_VOL = { 70, 260, 150, 110, 380, 180, 300, 80, 120, 200 }

Add("pool_gallery", function()
	local p = FindSpot({ open = 220, outdoor = true })
	local list = {}
	for i, f in ipairs(FAMS) do
		local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
		list[#list + 1] = { fam = f, vol = FAM_VOL[i], dx = (col - 2) * 58, dy = (0.5 - row) * 64, drips = (f == "A" or f == "H") and 6 or 0 }
	end
	Client("pooldemo", { pos = p, list = list })
	View(p + Vector(0, -170, 165), p + Vector(0, -8, 0))
	Wait(2.5) Shot("tP_gallery_overview")
	DebugShot("tP_gallery_overview", 32)
	-- the canvas pages themselves (HUD panels) and texel readback
	Client("cvar", { name = "abl_pool_debug", value = "24" })
	Wait(0.4) Shot("tP_pages")
	Client("cvar", { name = "abl_pool_debug", value = "0" })
	Client("poolprobe", {})
	Wait(0.3)
	-- close-ups: row 1 (A B C D E) and row 2 (F G H I J), two at a time from low angles
	for i = 1, 10, 2 do
		local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
		local c = p + Vector((col - 2) * 58 + (col < 4 and 29 or 0), (0.5 - row) * 64, 0)
		View(c + Vector(0, -62, 46), c)
		Wait(0.8) Shot(string.format("tP_gallery_close_%s%s", FAMS[i], FAMS[i + 1] or ""))
	end
	-- a very close, grazing view (wet reflection, outline at high magnification)
	local e = p + Vector(58 * 2, 32, 0)
	View(e + Vector(-8, -30, 11), e)
	Wait(0.8) Shot("tP_gallery_grazing")
	View(e + Vector(0, -14, 22), e + Vector(0, 2, 0))
	Wait(0.8) Shot("tP_gallery_macro")
	Client("cvar", { name = "abl_pool_debug", value = "1" })
	Wait(0.4) Shot("tP_gallery_macro_noreflect")
	Client("cvar", { name = "abl_pool_debug", value = "5" })
	Wait(0.4) Shot("tP_gallery_macro_plain")
	Client("cvar", { name = "abl_pool_debug", value = "0" })
	-- the other reflection mode (abl_pool_envmap), same two views
	Client("cvar", { name = "abl_pool_envmap", value = "0" })
	Wait(0.6) Shot("tP_gallery_macro_alt")
	View(e + Vector(-8, -30, 11), e)
	Wait(0.8) Shot("tP_gallery_grazing_alt")
	Client("cvar", { name = "abl_pool_envmap", value = "1" })
	Wait(0.3)
	-- drying: rim first, then the wet core retreats, dried, old
	View(p + Vector(0, -170, 165), p + Vector(0, -8, 0))
	for _, st in ipairs({ { 0.75, "ageing" }, { 0.5, "drying" }, { 0.25, "late" }, { 0, "dried" } }) do
		Client("pooldry", { wet = st[1] })
		Wait(1.4) Shot("tP_gallery_" .. st[2])
	end
	Client("pooldry", { wet = 0, dryT = 600 })
	Wait(1.4) Shot("tP_gallery_old")
	View(e + Vector(0, -40, 34), e)
	Wait(0.8) Shot("tP_gallery_old_close")
	Stats("tP_gallery")
end)

local function Pour(pos, n, every, perStep, vol, shots)
	for i = 1, n do
		Client("spray", { pos = pos + Vector(0, 0, 45), dir = Vector(0, 0, -1), speed = 20, count = perStep, vol = vol, cone = 0.03 })
		Wait(every)
		if shots and shots[i] then shots[i]() end
	end
end

Add("pool_growth", function()
	local p = FindSpot({ open = 160, outdoor = true })
	View(p + Vector(-38, -48, 58), p + Vector(6, 4, 0))
	-- ~2 ml/s from 45 units up: a pool forms, spreads, pushes lobes, throws spatter
	Pour(p, 64, 0.25, 4, 0.12, {
		[10] = function() Shot("tP_growth_2s") end,
		[28] = function() Shot("tP_growth_7s") end,
		[64] = function() Shot("tP_growth_16s") DebugShot("tP_growth_16s", 32) end,
	})
	View(p + Vector(-14, -30, 26), p + Vector(4, 2, 0))
	Wait(0.8) Shot("tP_growth_close")
	-- heavy bleeding (~12 ml/s) from two sources 11 units apart: each pool grows until they meet
	-- and continue as one mass
	local a, b = p + Vector(40, 30, 0), p + Vector(51, 34, 0)
	View(a + Vector(-30, -52, 50), a + Vector(6, 3, 0))
	for i = 1, 70 do
		Client("spray", { pos = a + Vector(0, 0, 40), dir = Vector(0, 0, -1), speed = 15, count = 5, vol = 0.25, cone = 0.04 })
		Client("spray", { pos = b + Vector(0, 0, 40), dir = Vector(0, 0, -1), speed = 15, count = 5, vol = 0.25, cone = 0.04 })
		Wait(0.2)
		if i == 20 then Shot("tP_merge_4s") end
		if i == 45 then Shot("tP_merge_9s") end
	end
	Wait(1.5) Shot("tP_merge_16s") DebugShot("tP_merge_16s", 32)
	View(a + Vector(-6, -30, 24), a + Vector(6, 3, 0))
	Wait(0.8) Shot("tP_merge_close")
	Stats("tP_growth")
end)

Add("pool_wall", function()
	local p, wallDir, wallDist = FindSpot({ open = 110, wall = true, outdoor = true })
	if not p then Log("pool_wall: no wall spot") return end
	local q = p + wallDir * (wallDist - 8)
	local side = wallDir:Cross(Vector(0, 0, 1))
	View(q - wallDir * 45 + side * 25 + Vector(0, 0, 50), q + wallDir * 3)
	Pour(q, 72, 0.25, 4, 0.14, { [72] = function() Shot("tP_wall_18s") DebugShot("tP_wall_18s", 32) end })
	Stats("tP_wall")
end)

Add("pool_ledge", function()
	local p = FindSpot({ open = 170, outdoor = true })
	local plate = ents.Create("prop_physics")
	plate:SetModel("models/hunter/plates/plate1x1.mdl")
	plate:SetPos(p + Vector(0, 0, 16))
	plate:SetAngles(Angle(0, 0, 0))
	plate:Spawn()
	local po = plate:GetPhysicsObject()
	if IsValid(po) then po:EnableMotion(false) end
	Wait(0.5)
	local top = p + Vector(15, 0, 16 + 1.8)
	View(top + Vector(40, -55, 45), top + Vector(4, 0, -6))
	Pour(top, 80, 0.25, 4, 0.14, {
		[40] = function() Shot("tP_ledge_10s") end,
		[80] = function() Shot("tP_ledge_20s") DebugShot("tP_ledge_20s", 32) end,
	})
	Stats("tP_ledge")
	Wait(1)
	plate:Remove()
end)

-- The liquid pools (cl_poolsim.lua), one behaviour a scene. Asked for by name:
--   harness.ps1 -Plan "pool_floor,pool_views,pool_dry,pool_slope,pool_materials,pool_streams,pool_merge,pool_overflow"
-- and pool_rates, pool_stress, pool_long (half an hour) on their own. Blood arrives at a steady
-- rate at points on the floor (client "poolfeed"); "poolwatch" logs the pools' figures over time.
for _, name in ipairs({ "poolsim", "pool_floor", "pool_views", "pool_dry", "pool_slope", "pool_materials", "pool_streams", "pool_merge", "pool_overflow", "pool_rates", "pool_stress", "pool_long", "pool_story", "pool_sim_off", "pool_sim_on",
	"pool_accept", "pool_inflow", "pool_gravity", "pool_join", "pool_meet", "pool_material" }) do
	onRequest[name] = true
end

local function PoolSpot(open)
	local p = FindSpot({ open = open or 160, outdoor = true })
	Client("clear", {})
	Wait(0.4)
	return p
end

local function PoolProfile(name)
	Client("profile", { name = name, reset = true })
	Wait(0.1)
end

local function PoolView(n)
	Client("cvar", { name = "abl_pool_view", value = tostring(n) })
	Wait(0.7)
end

-- One inlet on a level floor: 2 ml/s for 20 s, then left alone.
Add("pool_floor", function()
	local p = PoolSpot()
	View(p + Vector(-30, -44, 50), p + Vector(2, 2, 0))
	Client("poolwatch", { name = "floor", every = 1, secs = 45 })
	Client("poolfeed", { pos = p, rate = 2, secs = 20 })
	Wait(2) Shot("tQ_floor_02s")
	Wait(4) Shot("tQ_floor_06s")
	Wait(6) Shot("tQ_floor_12s")
	Wait(7) Shot("tQ_floor_20s")
	View(p + Vector(-10, -22, 20), p + Vector(1, 1, 0))
	Wait(0.6) Shot("tQ_floor_close")
	View(p + Vector(-6, -30, 9), p)
	Wait(0.6) Shot("tQ_floor_grazing")
	View(p + Vector(-2, -9, 12), p + Vector(0, 2, 0))
	Wait(0.6) Shot("tQ_floor_macro")
	View(p + Vector(-30, -44, 50), p + Vector(2, 2, 0))
	Wait(16) Shot("tQ_floor_40s")
	Stats("tQ_floor")
end)

-- The developer views of a pool that is being fed, and the overlay.
Add("pool_views", function()
	local p = PoolSpot()
	View(p + Vector(-12, -26, 26), p + Vector(1, 1, 0))
	Client("poolfeed", { pos = p, rate = 3, secs = 40 })
	Client("poolfeed", { pos = p + Vector(5, 2, 0), rate = 1, secs = 40 })
	Wait(9) Shot("tQ_view_0")
	for v = 1, 7 do
		PoolView(v)
		Shot("tQ_view_" .. v)
	end
	PoolView(0)
	DebugShot("tQ_view_overlay", 32)
	Client("poolfeed", { stop = true })
end)

-- Drying at ten times the speed: the thin rim first, the middle sets, dries, cracks; then
-- fresh blood onto the dried pool.
Add("pool_dry", function()
	local p = PoolSpot()
	RunConsoleCommand("abl_drying_scale", "0.1")
	Wait(0.6)
	View(p + Vector(-14, -30, 30), p + Vector(1, 1, 0))
	Client("poolwatch", { name = "dry", every = 3, secs = 84 })
	Client("poolfeed", { pos = p, rate = 12, secs = 5 })
	Client("poolfeed", { pos = p + Vector(4, -1, 0), rate = 4, secs = 5 })
	Wait(6) Shot("tQ_dry_06s")
	Wait(6) Shot("tQ_dry_12s")
	Wait(8) Shot("tQ_dry_20s")
	PoolView(3) Shot("tQ_dry_20s_state") PoolView(0)
	Wait(6) Shot("tQ_dry_28s")
	Wait(8) Shot("tQ_dry_36s")
	Wait(10) Shot("tQ_dry_46s")
	-- fresh blood at the dried pool's edge
	Client("poolfeed", { pos = p + Vector(3, 3, 0), rate = 4, secs = 4 })
	Wait(2) Shot("tQ_rewet_02s")
	Wait(4) Shot("tQ_rewet_06s")
	PoolView(3) Shot("tQ_rewet_06s_state") PoolView(0)
	Wait(14) Shot("tQ_rewet_22s")
	Stats("tQ_dry")
	-- and long after
	Client("pooldry", { wet = 0, dryT = 600 })
	Wait(1.6) Shot("tQ_dry_old")
	View(p + Vector(-3, -12, 14), p + Vector(0, 1, 0))
	Wait(0.8) Shot("tQ_dry_old_close")
	RunConsoleCommand("abl_drying_scale", "1")
	Wait(0.3)
end)

-- A tilted plate at three angles: 2.5 ml/s for 10 s onto one spot.
Add("pool_slope", function()
	for _, deg in ipairs({ 4, 10, 20 }) do
		local p = PoolSpot()
		local plate = ents.Create("prop_physics")
		plate:SetModel("models/hunter/plates/plate2x4.mdl")
		plate:SetPos(p + Vector(0, 0, 22))
		plate:SetAngles(Angle(deg, 0, 0))
		plate:Spawn()
		local po = plate:GetPhysicsObject()
		if IsValid(po) then po:EnableMotion(false) end
		Wait(0.5)
		View(p + Vector(-10, 70, 55), p + Vector(0, 0, 22))
		Client("poolwatch", { name = "slope" .. deg, every = 2, secs = 24 })
		Client("poolfeed", { pos = p + Vector(-14, 0, 40), rate = 2.5, secs = 10 })
		Wait(4) Shot("tQ_slope" .. deg .. "_04s")
		Wait(8) Shot("tQ_slope" .. deg .. "_12s")
		Wait(11) Shot("tQ_slope" .. deg .. "_23s")
		Stats("tQ_slope" .. deg)
		plate:Remove()
		Wait(0.5)
	end
end)

-- The same 40 ml on eight surface profiles (the profile is named; the floor is the map's).
local MATS = { "concrete", "tile", "metal", "glass", "wood", "fabric", "dirt", "plastic" }
Add("pool_materials", function()
	local p = PoolSpot()
	View(p + Vector(0, -86, 96), p + Vector(0, -4, 0))
	for i, m in ipairs(MATS) do
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		Client("poolfeed", { pos = p + Vector((col - 1.5) * 24, (0.5 - row) * 26, 0), rate = 4, secs = 10, surf = m })
	end
	Client("poolwatch", { name = "materials", every = 6, secs = 31, max = 8 })
	Wait(5) Shot("tQ_mat_05s")
	Wait(7) Shot("tQ_mat_12s")
	Wait(18) Shot("tQ_mat_30s")
	for i = 1, 8, 2 do
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		local c = p + Vector((col - 1.5) * 24 + 12, (0.5 - row) * 26, 0)
		View(c + Vector(0, -34, 30), c)
		Wait(0.7) Shot("tQ_mat_close_" .. MATS[i] .. "_" .. MATS[i + 1])
	end
	Stats("tQ_materials")
end)

-- Three inlets of different strength feeding what becomes one pool.
Add("pool_streams", function()
	local p = PoolSpot()
	View(p + Vector(-20, -36, 40), p + Vector(2, 3, 0))
	Client("poolwatch", { name = "streams", every = 2, secs = 32 })
	Client("poolfeed", { pos = p, rate = 2.5, secs = 16 })
	Client("poolfeed", { pos = p + Vector(4.5, 1.5, 0), rate = 1.5, secs = 16 })
	Client("poolfeed", { pos = p + Vector(-2, 4.5, 0), rate = 1.0, secs = 16, kind = "runoff" })
	Wait(3) Shot("tQ_streams_03s")
	Wait(5) Shot("tQ_streams_08s")
	Wait(8) Shot("tQ_streams_16s")
	PoolView(1) Shot("tQ_streams_16s_depth") PoolView(0)
	Wait(12) Shot("tQ_streams_30s")
	Stats("tQ_streams")
end)

-- Two pools 8 units apart, each fed until they meet: the bridge, then one pool.
Add("pool_merge", function()
	local p = PoolSpot()
	local a, b = p + Vector(-4, 0, 0), p + Vector(4, 1, 0)
	View(p + Vector(-18, -40, 44), p + Vector(0, 1, 0))
	Client("poolwatch", { name = "merge", every = 2, secs = 50 })
	Client("poolfeed", { pos = a, rate = 6, secs = 24 })
	Client("poolfeed", { pos = b, rate = 5, secs = 24 })
	Wait(6) Shot("tQ_merge_06s")
	Wait(6) Shot("tQ_merge_12s")
	Wait(4) Shot("tQ_merge_16s")
	Wait(4) Shot("tQ_merge_20s")
	PoolView(1) Shot("tQ_merge_20s_depth") PoolView(0)
	Wait(4) Shot("tQ_merge_25s")
	View(p + Vector(-4, -22, 20), p + Vector(0, 1, 0))
	Wait(0.7) Shot("tQ_merge_close")
	View(p + Vector(-18, -40, 44), p + Vector(0, 1, 0))
	Wait(20) Shot("tQ_merge_48s")
	Stats("tQ_merge")
end)

-- A raised plate, blood arriving three units from its edge: it stands at the edge, goes over.
Add("pool_overflow", function()
	local p = PoolSpot(170)
	local plate = ents.Create("prop_physics")
	plate:SetModel("models/hunter/plates/plate1x1.mdl")
	plate:SetPos(p + Vector(0, 0, 16))
	plate:SetAngles(Angle(0, 0, 0))
	plate:Spawn()
	local po = plate:GetPhysicsObject()
	if IsValid(po) then po:EnableMotion(false) end
	Wait(0.5)
	local top = p + Vector(22, 2, 16 + 1.8)
	View(top + Vector(36, -50, 40), top + Vector(2, 0, -8))
	Client("poolwatch", { name = "overflow", every = 2, secs = 30 })
	Client("poolfeed", { pos = top + Vector(0, 0, 10), rate = 5, secs = 18 })
	Wait(4) Shot("tQ_over_04s")
	Wait(6) Shot("tQ_over_10s")
	Wait(8) Shot("tQ_over_18s")
	DebugShot("tQ_over_18s", 32)
	Wait(10) Shot("tQ_over_29s")
	Stats("tQ_overflow")
	plate:Remove()
	Wait(0.5)
end)

-- The whole of it in one close view, on a raised plate: a small flow arrives two units from
-- the edge, wets a spot, becomes a pool, widens with a thin rim and a deeper middle, reaches
-- the edge, stands there, goes over; the flow stops, the pool settles; then (drying at ten
-- times the speed) the rim dries, the middle sets and dries, a stain is left.
Add("pool_story", function()
	local p = PoolSpot(170)
	local plate = ents.Create("prop_physics")
	plate:SetModel("models/hunter/plates/plate1x1.mdl")
	plate:SetPos(p + Vector(0, 0, 16))
	plate:SetAngles(Angle(0, 0, 0))
	plate:Spawn()
	local po = plate:GetPhysicsObject()
	if IsValid(po) then po:EnableMotion(false) end
	Wait(0.5)
	local top = p + Vector(22.2, -3, 16 + 1.8)
	View(top + Vector(10, -22, 17), top + Vector(0, 1, 0))
	Client("poolwatch", { name = "story", every = 2, secs = 96 })
	-- (a small flow for 22 s, then a heavier one: the layer rises at the edge and goes over)
	Client("poolfeed", { pos = top + Vector(0, 0, 10), rate = 1.5, secs = 22 })
	timer.Simple(22, function() Client("poolfeed", { pos = top + Vector(0, 0, 10), rate = 6, secs = 8 }) end)
	local at = 0
	local function Until(t)
		if t > at then Wait(t - at) end
		at = t
	end
	for _, t in ipairs({ 1, 2, 4, 7, 11, 16, 22, 30 }) do
		Until(t)
		Shot(string.format("tQ_story_%02ds", t))
		at = at + 0.35
	end
	Until(38)
	Shot("tQ_story_38s_settled")
	at = at + 0.35
	RunConsoleCommand("abl_drying_scale", "0.1")
	for _, t in ipairs({ 44, 50, 56, 64, 74, 90 }) do
		Until(t)
		Shot(string.format("tQ_story_%02ds_drying", t))
		at = at + 0.35
	end
	PoolView(3) Shot("tQ_story_90s_state") PoolView(0)
	Stats("tQ_story")
	RunConsoleCommand("abl_drying_scale", "1")
	plate:Remove()
	Wait(0.5)
end)

-- The acceptance scenes (docs/TESTING.md, "Pool acceptance"). They all use one spot, so that a
-- run of today can be laid beside a run of last week: the first run found it, and it is written
-- down here.
local ACCEPT_SPOT = Vector(901.6, -413.9, -144.0)   -- gm_construct
local BURST_SCALE = 0.35
local function AcceptSpot()
	local p = game.GetMap() == "gm_construct" and ACCEPT_SPOT or FindSpot({ open = 170, outdoor = true })
	game.SetTimeScale(1)
	Log("accept spot: Vector(%.1f, %.1f, %.1f)", p.x, p.y, p.z)
	Client("clear", {})
	Wait(0.4)
	return p
end

local function Plate(p, model, ang)
	local plate = ents.Create("prop_physics")
	plate:SetModel(model or "models/hunter/plates/plate1x1.mdl")
	plate:SetPos(p + Vector(0, 0, model and 22 or 16))
	plate:SetAngles(ang or Angle(0, 0, 0))
	plate:Spawn()
	local po = plate:GetPhysicsObject()
	if IsValid(po) then po:EnableMotion(false) end
	Wait(0.5)
	return plate
end

-- The final test: one source, one surface (the floor), one pool, a camera that does not move.
-- Blood arrives slowly (1 ml/s for 10 s), then faster (3 for 8 s), then fast (8 for 5 s), then
-- stops; the pool settles; then it dries at ten times the speed; then a little fresh blood
-- lands on one side of the dried pool. Bursts of consecutive frames at every stage
-- (tA_<stage>_NNN.jpg; a captured frame takes about 43 ms, so a burst runs at 23 frames a
-- second), the pool's own figures twice a second, the log of what changed on screen, the
-- profile of the active phase, a scan of every cell.
Add("pool_accept", function()
	local p = AcceptSpot()
	View(p + Vector(-2, -17, 15), p + Vector(0, 1, 0))
	Wait(0.5)
	Client("pooltrace", { on = true })
	Client("profile", { reset = true })
	Client("poolwatch", { name = "accept", every = 0.5, secs = 122, pin = true })
	local t0 = CurTime()
	local function Until(t)
		local w = t0 + t - CurTime()
		if w > 0 then Wait(w) end
	end
	-- (a burst: the game runs slowed while the frames are taken, so that a captured frame, which
	-- takes about 43 ms, is 15 ms of the game's time: the frames of a game at 66 a second)
	local function Burst(name, at, frames)
		Until(at)
		game.SetTimeScale(BURST_SCALE)
		Client("poolburst", { name = "tA_" .. name, frames = frames })
		Wait(frames * 0.017 + 0.5)
		game.SetTimeScale(1)
	end
	Client("poolfeed", { pos = p, rate = 1, secs = 10, jitter = 0.05 })
	timer.Simple(10, function() Client("poolfeed", { pos = p, rate = 3, secs = 8, jitter = 0.05 }) end)
	timer.Simple(18, function() Client("poolfeed", { pos = p, rate = 8, secs = 5, jitter = 0.05 }) end)
	Burst("1_begin", 1.6, 200)
	Burst("2_low", 7, 120)
	Burst("3_medium", 12, 150)
	Burst("4_high", 18.5, 200)
	Burst("5_stop", 22.4, 200)
	Burst("6_settle", 28.2, 120)
	Burst("6_rest", 33, 60)
	Until(36)
	PoolProfile("tA_accept_active")
	Client("scan", { name = "A_active" })
	Shot("tA_still_36s_settled")
	PoolView(1) Shot("tA_still_36s_depth")
	PoolView(0)
	RunConsoleCommand("abl_drying_scale", "0.1")
	Burst("7_dry_a", 42, 40)
	Until(46) Shot("tA_still_46s_drying")
	PoolView(3) Shot("tA_still_46s_state")
	PoolView(0)
	Burst("8_dry_b", 52, 40)
	Until(56) Shot("tA_still_56s_drying")
	PoolView(3) Shot("tA_still_56s_state")
	PoolView(0)
	Burst("9_dry_c", 64, 40)
	Until(68) Shot("tA_still_68s_drying")
	PoolView(3) Shot("tA_still_68s_state")
	PoolView(0)
	Until(96) Shot("tA_still_96s_dried")
	PoolView(3) Shot("tA_still_96s_state")
	PoolView(0)
	-- fresh blood onto one side of the dried pool
	RunConsoleCommand("abl_drying_scale", "1")
	Until(100)
	Client("poolfeed", { pos = p + Vector(2.4, -0.6, 0), rate = 1.5, secs = 3, jitter = 0.05 })
	Burst("10_rewet", 100.2, 200)
	Until(106) Shot("tA_still_106s_rewet")
	PoolView(3) Shot("tA_still_106s_rewet_state")
	PoolView(0)
	Until(120)
	Shot("tA_still_120s_rewet")
	Stats("tA_accept")
	Client("scan", { name = "A_end" })
	Client("pooltrace", { dump = "accept", t0 = 0, t1 = 34 })
end)

-- The liquid's steps under five frame clocks, without the game's own (client "poolclock").
onRequest.pool_clock = true
Add("pool_clock", function()
	Client("clear", {})
	Wait(0.5)
	Client("poolclock", {})
	Wait(8)
end)

-- One inlet (4 ml/s for 12 s) at whatever frame rate the game was started with (fps_max on
-- the command line: harness.ps1 -Extra "+fps_max 120"); the figures every second and the frame
-- rate reached. Runs at different rates are laid side by side.
onRequest.pool_fps = true
Add("pool_fps", function()
	local p = AcceptSpot()
	View(p + Vector(-2, -17, 15), p + Vector(0, 1, 0))
	Wait(1)
	Client("fps", { name = "before" })
	Client("poolwatch", { name = "fps", every = 1, secs = 26, pin = true })
	Client("poolfeed", { pos = p, rate = 4, secs = 12, jitter = 0 })
	Wait(13)
	Client("fps", { name = "fed" })
	Wait(13.5)
	Client("fps", { name = "rest" })
	Client("scan", { name = "A_fps" })
	Stats("tA_fps")
end)

-- Inflow: the same 36 ml at 1, 3 and 9 ml/s on the same floor (what the pool is like when it
-- has received them, and 20 s later), then 45 ml at the three rates 1.5 units from an edge
-- (how much goes over it).
Add("pool_inflow", function()
	local p = AcceptSpot()
	View(p + Vector(-20, -36, 40), p + Vector(0, 2, 0))
	for _, rate in ipairs({ 1, 3, 9 }) do
		Client("clear", {})
		Wait(0.5)
		local secs = 36 / rate
		Client("poolwatch", { name = "inflow_" .. rate, every = 1, secs = secs + 20 })
		Client("poolfeed", { pos = p, rate = rate, secs = secs, jitter = 0.05 })
		Wait(secs)
		Shot("tA_inflow_" .. rate .. "_end")
		PoolView(1) Shot("tA_inflow_" .. rate .. "_end_depth")
		PoolView(0)
		Wait(18.5)
		Stats("tA_inflow_" .. rate)
	end
	for _, rate in ipairs({ 1, 3, 9 }) do
		Client("clear", {})
		Wait(0.5)
		local plate = Plate(p)
		local top = p + Vector(22.2, -3, 17.8)
		local secs = 45 / rate
		Client("poolwatch", { name = "inflow_edge_" .. rate, every = 2, secs = secs + 14 })
		Client("poolfeed", { pos = top + Vector(0, 0, 10), rate = rate, secs = secs, jitter = 0.05 })
		Wait(secs + 14)
		Stats("tA_inflow_edge_" .. rate)
		plate:Remove()
		Wait(0.5)
	end
end)

-- Gravity: 2 ml/s for 12 s onto a plate tilted 2, 4 and 7 degrees; the reach downhill and
-- uphill from where the blood arrives, every second.
Add("pool_gravity", function()
	local p = AcceptSpot()
	for _, deg in ipairs({ 2, 4, 7 }) do
		Client("clear", {})
		Wait(0.5)
		local plate = Plate(p, "models/hunter/plates/plate2x4.mdl", Angle(deg, 0, 0))
		View(p + Vector(-10, 70, 55), p + Vector(0, 0, 22))
		Client("poolwatch", { name = "gravity" .. deg, every = 1, secs = 22 })
		Client("poolfeed", { pos = p + Vector(-14, 0, 40), rate = 2, secs = 12, jitter = 0.05 })
		Wait(12) Shot("tA_gravity" .. deg .. "_12s")
		Wait(10) Shot("tA_gravity" .. deg .. "_22s")
		Stats("tA_gravity" .. deg)
		plate:Remove()
		Wait(0.5)
	end
end)

-- Joins, frame by frame: a stream that runs down a wall into the pool at its foot, and a pool
-- on a tilted plate that hands its blood to a stream.
Add("pool_join", function()
	local p, wallDir, wallDist = FindSpot({ open = 110, wall = true, outdoor = true })
	if p then
		Client("clear", {})
		Wait(0.4)
		local foot = p + wallDir * wallDist
		local wallPoint = foot + Vector(0, 0, 30)
		local side = wallDir:Cross(Vector(0, 0, 1))
		View(foot - wallDir * 15 + side * 5 + Vector(0, 0, 10), foot - wallDir * 1.5 + Vector(0, 0, 2.5))
		Wait(0.5)
		Client("poolwatch", { name = "join_wall", every = 2, secs = 30 })
		Client("poolburst", { name = "tA_join_wall", frames = 230, every = 2 })
		-- about 2 ml/s onto one spot of the wall, 30 units up
		local t0 = CurTime()
		timer.Create("ABL_TestJoinPour", 0.2, 130, function()
			Client("spray", { pos = wallPoint - wallDir * 10, dir = wallDir, speed = 60, count = 4, vol = 0.1, cone = 0.03 })
		end)
		Wait(26)
		Shot("tA_join_wall_26s")
		Stats("tA_join_wall")
		Log("  pool_join wall part took %.0f s", CurTime() - t0)
	else
		Log("pool_join: no wall spot")
	end
	local q = AcceptSpot()
	local plate = Plate(q, "models/hunter/plates/plate2x4.mdl", Angle(10, 0, 0))
	-- (the pool's downhill tip, where it hands its blood to the stream, 7 units from the inlet)
	View(q + Vector(-6.5, 10, 32), q + Vector(-6.5, 0, 24.6))
	Wait(0.5)
	Client("poolwatch", { name = "join_slope", every = 2, secs = 22 })
	Client("poolfeed", { pos = q + Vector(-14, 0, 40), rate = 2.5, secs = 14, jitter = 0.05 })
	Wait(1.5)
	Client("poolburst", { name = "tA_join_slope", frames = 200, every = 2 })
	Wait(14)
	Shot("tA_join_slope_tip")
	View(q + Vector(-6, 17, 36), q + Vector(-6, 0, 21.5))
	Wait(4)
	Shot("tA_join_slope_20s")
	Client("scan", { name = "A_join" })
	Stats("tA_join_slope")
	plate:Remove()
	Wait(0.5)
end)

-- Two pools meeting, frame by frame: 8 units apart, 6 and 5 ml/s for 24 s.
Add("pool_meet", function()
	local p = AcceptSpot()
	local a, b = p + Vector(-4, 0, 0), p + Vector(4, 1, 0)
	View(p + Vector(0, -19, 24), p + Vector(0, 1, 0))
	Wait(0.5)
	Client("pooltrace", { on = true })
	Client("poolwatch", { name = "meet", every = 1, secs = 44, max = 3 })
	Client("poolfeed", { pos = a, rate = 6, secs = 24, jitter = 0.05 })
	Client("poolfeed", { pos = b, rate = 5, secs = 24, jitter = 0.05 })
	Wait(7)
	-- (slowed as in pool_accept: 620 frames are 9.7 s of the game's time)
	game.SetTimeScale(BURST_SCALE)
	Client("poolburst", { name = "tA_meet", frames = 620, every = 1, x = 460, y = 270, w = 1000, h = 560 })
	Wait(620 * 0.017 + 0.5)
	game.SetTimeScale(1)
	Wait(26)
	Stats("tA_meet")
	Client("scan", { name = "A_meet" })
	Client("pooltrace", { dump = "meet", t0 = 0, t1 = 40 })
end)

-- The material of thin, normal and deep blood: a pool being fed, seen at a low angle, with and
-- without its mirror, and its depth.
Add("pool_material", function()
	local p = AcceptSpot()
	View(p + Vector(-3, -30, 8.5), p + Vector(0, 1, 0))
	Wait(0.5)
	Client("poolwatch", { name = "material", every = 2, secs = 24 })
	Client("poolfeed", { pos = p, rate = 4, secs = 16, jitter = 0.05 })
	Wait(11)
	Shot("tA_material_low_mirror")
	Client("cvar", { name = "abl_pool_debug", value = "1" })
	Wait(0.4) Shot("tA_material_low_plain")
	Client("cvar", { name = "abl_pool_debug", value = "0" })
	PoolView(1) Shot("tA_material_low_depth")
	PoolView(0)
	View(p + Vector(-2, -13, 15), p + Vector(0, 1, 0))
	Wait(0.6) Shot("tA_material_high_mirror")
	Client("cvar", { name = "abl_pool_debug", value = "1" })
	Wait(0.4) Shot("tA_material_high_plain")
	Client("cvar", { name = "abl_pool_debug", value = "0" })
	Wait(8)
	View(p + Vector(-3, -30, 8.5), p + Vector(0, 1, 0))
	Wait(0.6) Shot("tA_material_rest_mirror")
	Stats("tA_material")
end)

-- The shape lab (client "poollab"): contact-line variants side by side, drawn outside the game.
onRequest.pool_lab = true
Add("pool_lab", function()
	Client("clear", {})
	Wait(0.5)
	Client("poollab", {})
	Wait(25)
end)

-- The earlier pools (field stamps) for the scenes that follow, and back.
Add("pool_sim_off", function()
	Client("cvar", { name = "abl_pool_sim", value = "0" })
	Wait(0.5)
end)
Add("pool_sim_on", function()
	Client("cvar", { name = "abl_pool_sim", value = "1" })
	Wait(0.5)
end)

-- The same inlet (2 ml/s for 10 s) at four frame rates: the figures over time must agree.
Add("pool_rates", function()
	local p = PoolSpot()
	for _, burn in ipairs({ 0, 42, 92, 192 }) do
		Client("clear", {})
		Wait(0.4)
		View(p + Vector(-30, -44, 50), p + Vector(2, 2, 0))
		Client("burn", { ms = burn })
		Wait(1)
		Client("poolwatch", { name = "rate_burn" .. burn, every = 2, secs = 22 })
		Client("poolfeed", { pos = p, rate = 2, secs = 10, jitter = 0 })
		Wait(22.5)
		Client("fps", {})
		Shot("tQ_rate_burn" .. burn)
		Stats("tQ_rate_burn" .. burn)
		Client("burn", { ms = 0 })
		Wait(0.5)
	end
end)

-- 1, 10, 25, 50 and 100 pools, each fed 1.5 ml/s for 10 s: what they cost while they grow and
-- once they lie still.
Add("pool_stress", function()
	local p = FindSpot({ open = 260, outdoor = true })
	Client("cvar", { name = "abl_max_pools", value = "140" })
	View(p + Vector(0, -250, 200), p + Vector(0, -20, 0))
	for _, n in ipairs({ 1, 10, 25, 50, 100 }) do
		Client("clear", {})
		Wait(0.6)
		local list = {}
		for k = 0, n - 1 do
			list[#list + 1] = p + Vector((k % 10 - 4.5) * 24, (math.floor(k / 10) - 4.5) * 24, 0)
		end
		Client("poolfeed", { list = list, rate = 1.5, secs = 10 })
		Wait(3)
		Client("profile", { reset = true })
		Wait(6.5)
		PoolProfile("tQ_stress_" .. n .. "_fed")
		Client("scan", { name = "stress_" .. n })
		Shot("tQ_stress_" .. n)
		Wait(10)
		Client("profile", { reset = true })
		Wait(5)
		PoolProfile("tQ_stress_" .. n .. "_later")
		Stats("tQ_stress_" .. n)
	end
	Client("clear", {})
	Client("cvar", { name = "abl_max_pools", value = "56" })
	Wait(0.5)
end)

-- Half an hour: a wound's worth over the first minute and three smaller pools, fresh blood
-- again after ten minutes; figures, the books and the profile at 30 s, 1, 2, 5, 10, 20, 30 min.
Add("pool_long", function()
	local p = PoolSpot(200)
	View(p + Vector(-10, -80, 80), p + Vector(8, 0, 0))
	Client("poolwatch", { name = "long", every = 30, secs = 1800, max = 6 })
	Client("poolfeed", { pos = p, rate = 3, secs = 60 })
	Client("poolfeed", { pos = p + Vector(34, 8, 0), rate = 1, secs = 30 })
	Client("poolfeed", { pos = p + Vector(-20, 26, 0), rate = 0.5, secs = 120 })
	Client("poolfeed", { pos = p + Vector(22, -24, 0), rate = 4, secs = 8 })
	local at = 0
	for _, t in ipairs({ 30, 60, 120, 300, 600, 1200, 1800 }) do
		Wait(t - at)
		at = t
		Shot("tQ_long_" .. t .. "s")
		PoolProfile("tQ_long_" .. t .. "s")
		Stats("tQ_long_" .. t .. "s")
		at = at + 0.6
		if t == 600 then
			Client("poolfeed", { pos = p + Vector(4, 3, 0), rate = 2, secs = 12 })
		end
	end
	View(p + Vector(-4, -24, 22), p + Vector(2, 0, 0))
	Wait(0.8) Shot("tQ_long_close")
end)

-- Headshots: a standing bot shot through the head from the front (entry and exit marks, the
-- response, then the body going down and bleeding), and a ragdolled bot shot from above.
Add("headshot", function()
	local p = FindSpot({ open = 160, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	Wait(0.8)
	local body = ABL.ZC.GetBody(bot)
	local head = ABL.DevHitboxCenter(body, "head")
	local fwd, right = bot:GetForward(), bot:GetRight()
	View(head + fwd * 26 + right * 16 + Vector(0, 0, 3), head)
	Wait(0.5)
	ABL.DevShootAt(host, head + Vector(0, 0, 1.5), (fwd + right * 0.3):GetNormalized(), 30)
	Wait(0.1) Shot("tH_head_impact")
	Wait(1) Shot("tH_head_1s")
	Wait(2.5)
	-- follow the body to the ground
	local rag = ABL.DevRagdollOf(bot)
	local hb = IsValid(rag) and ABL.DevHitboxCenter(rag, "head")
	Log("  headshot: ragdoll %s head %s", tostring(rag), tostring(hb))
	if hb then View(hb + Vector(16, -18, 20), hb) end
	Wait(0.6) Shot("tH_head_down_4s")
	if hb then View(hb + Vector(-18, 16, 16), hb) end
	Wait(0.6) Shot("tH_head_down_other_4s")
	-- close-ups of the wounds themselves, framed by the client (it knows where the marks are)
	Client("viewmark", { kind = "entry", dist = 12 })
	Wait(0.5) Shot("tH_head_entry_close")
	-- (which of it is streams: one colour a channel; what stays as it was is something else)
	Client("cvar", { name = "abl_flow_view", value = "8" })
	Wait(0.3) Shot("tH_head_entry_paths")
	Client("cvar", { name = "abl_flow_view", value = "0" })
	Client("viewmark", { kind = "exit", dist = 13 })
	Wait(0.5) Shot("tH_head_exit_close")
	Wait(7)
	Client("viewmark", { kind = "entry", dist = 12 })
	Wait(0.5) Shot("tH_head_entry_13s")
	hb = IsValid(rag) and ABL.DevHitboxCenter(rag, "head")
	if hb then View(hb + Vector(16, -18, 20), hb) end
	Wait(0.6) Shot("tH_head_13s")
	Stats("tH_head")

	-- a character already down: shot from above, a lower-energy round
	local bot2 = NewBot()
	Place(bot2, p + Vector(70, 0, 0), 0)
	local rag2 = Fake(bot2)
	if not IsValid(rag2) then Log("headshot: fake failed") return end
	Wait(1)
	ABL.DevPose(rag2, "back")
	Wait(1.5)
	local h2 = ABL.DevHitboxCenter(rag2, "head")
	if not h2 then return end
	View(h2 + Vector(14, -16, 22), h2)
	ABL.DevShootAt(host, h2 + Vector(0, 0, 1), Vector(0.3, 0.2, 1):GetNormalized(), 18)
	Wait(0.1) Shot("tH_down_impact")
	Wait(5) Shot("tH_down_5s")
	Stats("tH_down")
end)

-- Gunshot wounds: one controlled case per character. What the projectile was (a real Z-City
-- cartridge), where it struck and from how far decide the wound; each case logs its wound record
-- (classification, what was crossed, entry / exit relation, how Z-City's wounds bleed through it,
-- what the reservoir lost against what was shown) and is photographed at the entry, at the exit and
-- with the wound overlay (abl_debug 512).
local function Wounds(name) Client("wounds", { name = name }) Wait(0.1) end

Add("gunshot", function()
	local p = FindSpot({ open = 260, outdoor = true })
	local n = 0
	local V = Vector
	-- No two characters share a row or a column: a bullet that leaves one body meets no other.
	local SLOTS = 11
	local function Slot(i)
		return p + V((i - 5) * 46, ((i * 4) % SLOTS - 5) * 46, 0)
	end
	local function Stand()
		local bot = NewBot()
		Place(bot, Slot(n % SLOTS), 0)
		n = n + 1
		return bot
	end
	-- from: where the gun is, in the target's own frame (x: to its right, y: in front, z: above).
	-- o.off: aim offset in that frame, or a list of offsets (a sweep: one shot each, until o.stop
	-- says the wanted wound has been made); o.at = { bone, local position }: aim at a point in a
	-- bone's space instead of a hitbox centre.
	local function Case(name, key, from, ammo, dist, o)
		o = o or {}
		local bot = o.bot or Stand()
		Wait(0.9)
		local body = ABL.ZC.GetBody(bot)
		local fwd, right, up = bot:GetForward(), bot:GetRight(), V(0, 0, 1)
		local fromDir = (right * from.x + fwd * from.y + up * from.z):GetNormalized()
		local offs = o.off
		if not offs then offs = { V(0, 0, 0) } elseif isvector(offs) then offs = { offs } end
		local aim
		for i, off in ipairs(offs) do
			local base
			if o.at then
				local bone = body:LookupBone(o.at[1])
				local m = bone and body:GetBoneMatrix(bone)
				base = m and LocalToWorld(o.at[2], angle_zero, m:GetTranslation(), m:GetAngles()) or nil
			else
				base = ABL.DevHitboxCenter(body, key)
			end
			if not base then Log("  case %s: no aim point (%s)", name, tostring(key)) return bot end
			aim = base + right * off.x + fwd * off.y + up * off.z
			if i == 1 then
				View(aim + (fromDir + right * 0.5 + up * 0.2):GetNormalized() * 36, aim)
				Wait(0.4)
			end
			Log("  case %s: %s at %s (offset %.1f %.1f %.1f) from %s units", name, tostring(ammo), tostring(o.at and o.at[1] or key), off.x, off.y, off.z, tostring(dist))
			ABL.DevShootAt(host, aim, fromDir, o.damage, dist, ammo)
			if i == 1 then Wait(0.12) Shot("tG_" .. name .. "_impact") end
			if #offs > 1 then
				Wait(0.5)
				if not bot:Alive() or (o.stop and o.stop(bot)) then break end
				body = ABL.ZC.GetBody(bot)
			end
		end
		Wait(1.6)
		Wounds("tG_" .. name)
		Client("viewmark", { kind = "entry", dist = 11 })
		Wait(0.4) Shot("tG_" .. name .. "_entry")
		Client("viewmark", { kind = "exit", dist = 12, newerThan = 3 })
		Wait(0.4) Shot("tG_" .. name .. "_exit")
		Client("viewmark", { kind = "entry", dist = 30 })
		Wait(0.3) DebugShot("tG_" .. name, 512)
		return bot
	end
	local function ArteryOpen(bot)
		local org = bot.organism
		return istable(org) and istable(org.arterialwounds) and #org.arterialwounds > 0
	end

	-- flesh only, just under the skin of the thigh: a graze (three paths, ever shallower)
	Case("graze", "lthigh", V(0, 1, 0), "9x19mmparabellum", 80, { off = { V(-3.4, 0, 4), V(-3.7, 0, 0), V(-4.0, 0, -4) } })
	-- a service pistol round into the chest: stops inside (no exit)
	Case("retained", "chest", V(0, 1, 0), "9x19mmparabellum", 80)
	-- an intermediate rifle round through the chest: entry and exit on one line
	Case("through", "chest", V(0.25, 1, 0), "7.62x39mm", 80)
	-- a pistol round into the belly: most of that bleeding stays inside
	Case("abdomen", "belly", V(0, 1, 0), "9x19mmparabellum", 80, { off = V(1.5, 0, 0) })
	-- the artery of the thigh (Z-City keeps it as a thin line along the bone), from the front
	Case("femoral", "lthigh", V(0, 1, 0), "9x19mmparabellum", 80,
		{ at = { "ValveBiped.Bip01_L_Thigh", V(9, 2, -1) }, off = { V(0, 0, 0), V(0.25, 0, 0), V(-0.25, 0, 0), V(0, 0, 0.3) }, stop = ArteryOpen })
	-- the carotid, from the front and a little to the side
	Case("carotid", "neck", V(0.35, 1, 0), "9x19mmparabellum", 80,
		{ at = { "ValveBiped.Bip01_Neck1", V(3.5, -2, 2.3) }, off = { V(0, 0, 0), V(0, 0, 0.3), V(0, 0, -0.3) }, stop = ArteryOpen })
	-- muzzle against the temple
	Case("contact", "head", V(-1, 0.1, 0), "9x19mmparabellum", 2.5)
	-- a heavy pistol round into the face from 20 cm
	Case("near", "head", V(0.1, 1, 0), ".45acp", 10, { off = V(0, 0, -1) })
	-- a full-power rifle round through the skull
	Case("skull", "head", V(0.2, 1, 0.05), "7.62x51mm", 80, { off = V(0, 0, 1.2) })
	-- through the calf from the side (bone or flesh, as it comes)
	Case("limb", "lcalf", V(-1, 0.1, 0), "5.56x45mm", 80)
	-- buckshot into the chest from two metres
	Case("buckshot", "chest", V(0, 1, 0), "12/70gauge", 100)
	-- two bodies in line: the bullet that leaves the first is an intermediate-target hit on the second
	do
		local front = Stand()
		local behind = NewBot()
		Place(behind, front:GetPos() - front:GetForward() * 34, 0)
		Wait(0.6)
		Case("inline", "chest", V(0, 1, 0), "7.62x39mm", 80, { bot = front })
	end
	-- blood coughed up (Z-City: a lung or stomach wound, bleeding inside): out of the mouth
	do
		local bot = Stand()
		Wait(1.2)
		local head = ABL.DevHitboxCenter(ABL.ZC.GetBody(bot), "head")
		if head and hg and hg.organism and hg.organism.Vomit then
			View(head + (bot:GetForward() + bot:GetRight() * 0.6 + Vector(0, 0, 0.1)):GetNormalized() * 40, head - Vector(0, 0, 6))
			Wait(0.4)
			Log("  case cough: hg.organism.Vomit")
			hg.organism.Vomit(bot)
			Wait(0.35) Shot("tG_cough_0")
			Wait(0.5) Shot("tG_cough_1")
			Wait(1.5) Shot("tG_cough_2")
			Wounds("tG_cough")
		end
	end
	Wait(8)
	Wounds("tG_all_later")
	Stats("tG_gunshot")
end)

-- Entry wounds on bare skin by range, and a wound over time. Four bodies lie on their backs and
-- are shot in the forehead from straight above with the same pistol round: muzzle on the skin, a
-- hand away, an arm away, and from across the room. Then the bleeding is stopped (the wounds are
-- closed) and the drying time shortened: the wet film sets, crusts and dries.
Add("gunshot_skin", function()
	local p = FindSpot({ open = 200, outdoor = true })
	local cases = {
		{ "contact", 2.5 }, { "near", 10 }, { "medium", 30 }, { "distant", 90 },
	}
	local rags = {}
	for i, c in ipairs(cases) do
		local bot = NewBot()
		Place(bot, p + Vector((i - 2.5) * 62, ((i * 2) % 5 - 2) * 46, 0), 0)
		local rag = Fake(bot)
		if not IsValid(rag) then Log("gunshot_skin: fake failed") return end
		Wait(0.8)
		ABL.DevPose(rag, "back", false)
		Wait(1.8)
		local aim = ABL.DevHitboxCenter(rag, "head")
		if not aim then return end
		-- the forehead: a little way up the head from its middle, shot from above
		local hb = rag:LookupBone("ValveBiped.Bip01_Head1")
		local m = hb and rag:GetBoneMatrix(hb)
		if m then aim = aim + m:GetForward() * 1.6 end
		local from = Vector(0.04, 0.03, 1):GetNormalized()
		View(aim + Vector(9, 5, 15), aim)
		Wait(0.3)
		Log("  skin %s: 9x19mmparabellum into the forehead from %s units", c[1], tostring(c[2]))
		ABL.DevShootAt(host, aim, from, nil, c[2], "9x19mmparabellum")
		Wait(0.12) Shot("tGS_" .. c[1] .. "_impact")
		Wait(1.6)
		Wounds("tGS_" .. c[1])
		Client("viewmark", { kind = "entry", dist = 9, newerThan = 4 })
		Wait(0.4) Shot("tGS_" .. c[1] .. "_entry")
		Client("viewmark", { kind = "entry", dist = 5, newerThan = 6 })
		Wait(0.4) Shot("tGS_" .. c[1] .. "_close")
		rags[i] = { rag = rag, bot = bot, name = c[1] }
	end
	-- time: the last body, still bleeding
	local last = rags[#rags]
	local function Look()
		Client("viewmark", { kind = "entry", dist = 6 })
		Wait(0.4)
	end
	Wait(4) Look() Shot("tGS_age_0_bleeding")
	for _, r in ipairs(rags) do
		if IsValid(r.rag) then ABL.DevHeal(r.rag) end
		if IsValid(r.bot) and r.bot:Alive() then ABL.DevHeal(r.bot) end
	end
	RunConsoleCommand("abl_drying_scale", "0.1")
	Wait(4) Look() Shot("tGS_age_1_setting")
	Wait(5) Look() Shot("tGS_age_2_clotted")
	Wounds("tGS_clotted")
	Wait(16) Look() Shot("tGS_age_3_dried")
	Wounds("tGS_dried")
	RunConsoleCommand("abl_drying_scale", "1")
end)

-- The same wound on bodies in other positions: lying on the back (shot from above: the exit is
-- underneath), on the side, and on a running body (the wound must stay where it was made).
Add("gunshot_pose", function()
	local p = FindSpot({ open = 220, outdoor = true })
	local function Lying(name, preset, off)
		local bot = NewBot()
		Place(bot, p + off, 0)
		local rag = Fake(bot)
		if not IsValid(rag) then Log("%s: fake failed", name) return end
		Wait(1)
		ABL.DevPose(rag, preset, false)
		Wait(1.6)
		local aim = ABL.DevHitboxCenter(rag, "chest")
		if not aim then return end
		local from = Vector(0.25, 0.15, 1):GetNormalized()
		View(aim + (from + Vector(0.5, 0.3, 0)):GetNormalized() * 44, aim)
		Wait(0.3)
		Log("  %s: 7.62x39mm into the chest of a lying body, from above", name)
		ABL.DevShootAt(host, aim, from, nil, 80, "7.62x39mm")
		Wait(0.12) Shot(name .. "_impact")
		Wait(2.2)
		Wounds(name)
		Client("viewmark", { kind = "entry", dist = 12 })
		Wait(0.4) Shot(name .. "_entry")
		Client("viewmark", { kind = "entry", dist = 30 })
		Wait(0.3) DebugShot(name, 512)
		Wait(5) Shot(name .. "_8s")
	end
	Lying("tGP_back", "back", Vector(-70, 0, 0))
	Lying("tGP_side", "side", Vector(70, 60, 0))
	-- a running body
	local bot = NewBot()
	Place(bot, p + Vector(0, -90, 0), 90)
	Wait(1.2)
	local body = ABL.ZC.GetBody(bot)
	local aim = ABL.DevHitboxCenter(body, "lthigh")
	if aim then
		ABL.DevShootAt(host, aim, -bot:GetRight(), nil, 80, "9x19mmparabellum")
		Wait(0.8)
		View(p + Vector(-120, -40, 40), p + Vector(0, -40, 20))
		bot:Freeze(false)
		runBot = bot
		Wait(2.4) Shot("tGP_running")
		Client("viewmark", { kind = "entry", dist = 16 })
		Wait(0.25) Shot("tGP_running_mark")
		runBot = nil
		bot:Freeze(true)
		Wait(1)
		Wounds("tGP_running")
	end
end)

Add("repeated", function()
	local p = FindSpot({ open = 130, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	View(p + Vector(70, 30, 50), p + Vector(0, 0, 36))
	ABL.DevShoot(host, bot, 20, "front", "chest")
	Wait(1) ABL.DevShoot(host, bot, 20, "right", "rupperarm")
	Wait(1) ABL.DevShoot(host, bot, 20, "front", "lthigh")
	Wait(6) Shot("t16_repeated") Stats("t16_repeated")
end)

Add("arterial", function()
	local p = FindSpot({ open = 200, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	View(p + Vector(40, -140, 60), p + Vector(40, 0, 30))
	ABL.DevAddWound(bot, "neck", 14, true, 3, 0.5, 0.5)
	Wait(1.5) Shot("tA_arterial_jet_a")
	Wait(0.3) Shot("tA_arterial_jet_b")
	Wait(8) Shot("tA_arterial_8s") Stats("tA_arterial")
end)

Add("drag", function()
	local p = FindSpot({ open = 260, outdoor = true })
	local bot = NewBot()
	Place(bot, p, 0)
	ABL.DevAddWound(bot, "chest", 14, false, 3, 0.5, 0.5)
	ABL.DevAddWound(bot, "stomach", 10, false, 4, 0.5, 0.5)
	Wait(3)
	local rag = Fake(bot)
	Wait(4)
	View(p + Vector(0, -160, 110), p + Vector(60, 0, 0))
	ABL.DevDrag(rag, Vector(1, 0, 0), 110)
	Wait(3) Shot("t27_drag") Stats("t27_drag")
end)

Add("many_players", function()
	local p = FindSpot({ open = 260, outdoor = true })
	local bots = {}
	for i = 1, 6 do
		local b = NewBot()
		bots[i] = b
		Place(b, p + Vector((i - 3.5) * 40, 0, 0), 90)
		ABL.DevAddWound(b, (i % 2 == 0) and "chest" or "lthigh", 10 + i, false, 3, 0.5, 0.5)
		if i % 3 == 0 then ABL.DevAddWound(b, "neck", 10, true, 3, 0.5, 0.5) end
	end
	View(p + Vector(0, -220, 110), p + Vector(0, 0, 30))
	Wait(10) Shot("t17_many") Stats("t17_many")
	for _, b in ipairs(bots) do ABL.DevShoot(host, b, 30, "front", "chest") end
	Wait(3) Shot("t18_high_activity") Stats("t18_high_activity")
end)

-- Worst case in close view: six bleeding characters (two arterial), sprays of fine droplets every
-- half second, two pours growing pools that merge, then everyone shot. The profiler reports the
-- cost of every part, frame times over each stretch, and memory before / after clearing.
local function Profile(name, reset, floor) Client("profile", { name = name, reset = reset, floor = floor }) Wait(floor and 0.6 or 0.1) end
Add("stress", function()
	local p = FindSpot({ open = 260, outdoor = true })
	local bots = {}
	for i = 1, 6 do
		local b = NewBot()
		bots[i] = b
		Place(b, p + Vector((i - 3.5) * 36, 0, 0), 90)
		ABL.DevAddWound(b, (i % 2 == 0) and "chest" or "lthigh", 9 + i, false, 3, 0.5, 0.5)
		if i % 3 == 0 then ABL.DevAddWound(b, "neck", 10, true, 3, 0.5, 0.5) end
	end
	View(p + Vector(0, -150, 80), p + Vector(0, 0, 28))
	Client("profile", { reset = true })
	Wait(5)
	Profile("tS_bleeding_5s", true)
	local a, b2 = p + Vector(-30, -45, 0), p + Vector(-18, -42, 0)
	for k = 1, 30 do
		Client("spray", { pos = p + Vector(-70 + (k % 5) * 35, -30, 72), dir = Vector(0, 0.25, -1), speed = 210, count = 28, vol = 0.03, cone = 0.5 })
		Client("spray", { pos = a + Vector(0, 0, 40), dir = Vector(0, 0, -1), speed = 15, count = 5, vol = 0.25, cone = 0.04 })
		Client("spray", { pos = b2 + Vector(0, 0, 40), dir = Vector(0, 0, -1), speed = 15, count = 5, vol = 0.25, cone = 0.04 })
		Wait(0.5)
		if k == 15 then Shot("tS_stress_8s") end
	end
	Shot("tS_stress_15s")
	Profile("tS_spray_15s", true)
	Stats("tS_stress")
	for _, bt in ipairs(bots) do ABL.DevShoot(host, bt, 30, "front", "chest") end
	Wait(4)
	Shot("tS_stress_shot")
	Profile("tS_after_shots", true)
	-- memory after everything is cleared (leaks show as a heap that does not come back down)
	Client("clear", {})
	Wait(3)
	Profile("tS_cleared", true, true)
end)

-- Long session: the stress scene over and over (new characters each time, wounds, sprays, pours,
-- everyone shot, bodies left bleeding, then cleared). The profile after each round shows whether
-- cost or the Lua heap creep up over time.
Add("soak", function()
	local p = FindSpot({ open = 260, outdoor = true })
	View(p + Vector(0, -150, 80), p + Vector(0, 0, 28))
	for round = 1, 6 do
		local bots = {}
		for i = 1, 6 do
			local b = NewBot()
			bots[i] = b
			Place(b, p + Vector((i - 3.5) * 36, 0, 0), 90)
			ABL.DevAddWound(b, (i % 2 == 0) and "chest" or "lthigh", 9 + i, false, 3, 0.5, 0.5)
			if i % 3 == 0 then ABL.DevAddWound(b, "neck", 10, true, 3, 0.5, 0.5) end
		end
		Client("profile", { reset = true })
		local a, b2 = p + Vector(-30, -45, 0), p + Vector(-18, -42, 0)
		for k = 1, 36 do
			Client("spray", { pos = p + Vector(-70 + (k % 5) * 35, -30, 72), dir = Vector(0, 0.25, -1), speed = 210, count = 28, vol = 0.03, cone = 0.5 })
			if k % 2 == 0 then
				Client("spray", { pos = a + Vector(0, 0, 40), dir = Vector(0, 0, -1), speed = 15, count = 5, vol = 0.25, cone = 0.04 })
				Client("spray", { pos = b2 + Vector(0, 0, 40), dir = Vector(0, 0, -1), speed = 15, count = 5, vol = 0.25, cone = 0.04 })
			end
			Wait(0.5)
		end
		for _, bt in ipairs(bots) do
			if IsValid(bt) then ABL.DevShoot(host, bt, 60, "front", (round % 2 == 0) and "head" or "chest") end
		end
		Wait(6)
		Profile("tK_round" .. round, true)
		if round == 1 or round == 6 then Shot("tK_round" .. round) end
		-- next round starts from an empty scene
		for _, b in ipairs(player.GetBots()) do b:Kick("ABL soak round") end
		botsUsed = {}
		Wait(0.5)
		for _, r in ipairs(ents.FindByClass("prop_ragdoll")) do r:Remove() end
		Client("clear", {})
		Wait(2.5)
		Profile("tK_cleared" .. round, true, true)
	end
end)

------------------------------------------------------------------------------------------
-- The visual audit (docs/VISUAL_AUDIT.md): one kind of blood a scene, at one spot, from fixed
-- close cameras, so that a look can be compared before and after a change. On request only.
-- Pool shapes come from where the pool lies and repeat from run to run; which stain or drop
-- picture a hit gets comes out of shuffled bags and does not.
------------------------------------------------------------------------------------------
local function Snap(name, w) Client("shot", { name = name }) Wait(w or 0.35) end
local function Mirror(on) Client("cvar", { name = "abl_pool_debug", value = on and "0" or "1" }) Wait(0.4) end

-- Small pools as wounds make them (a few ml, slowly), one of them on a floor already spattered.
-- Seen from above, at 45 degrees and at a low angle; with and without the mirror.
onRequest.audit_pool = true
Add("audit_pool", function()
	local p = AcceptSpot()
	local a, b, c = p + Vector(-9, 0, 0), p, p + Vector(10, 1, 0)
	local cams = {
		{ "top", Vector(0, -3, 26), Vector(0, 0, 0) },
		{ "mid", Vector(0, -17, 16), Vector(0, 0, 0) },
		{ "low", Vector(-2, -32, 6), Vector(0, 0, 0) },
		{ "close", Vector(-9, -7, 6.5), Vector(-9, 0, 0) },
	}
	local function Round(tag)
		for _, cam in ipairs(cams) do
			View(p + cam[2], p + cam[3])
			Wait(0.6)
			Snap("tV_pool_" .. tag .. "_" .. cam[1])
			Client("sheeninfo", { name = cam[1] })
			Mirror(false) Snap("tV_pool_" .. tag .. "_" .. cam[1] .. "_plain")
			Mirror(true)
		end
	end
	View(p + cams[2][2], p)
	Client("spray", { pos = c + Vector(0, 0, 34), dir = Vector(0, 0, -1), speed = 60, count = 16, vol = 0.06, cone = 0.22 })
	Wait(1.5)
	Client("poolwatch", { name = "audit", every = 2, secs = 30 })
	Client("poolfeed", { pos = a, rate = 0.5, secs = 8, jitter = 0.05 })
	Client("poolfeed", { pos = b, rate = 1, secs = 8, jitter = 0.05 })
	Client("poolfeed", { pos = c, rate = 0.8, secs = 8, jitter = 0.05 })
	Wait(4.5) Snap("tV_pool_fed_mid")
	Wait(8)
	-- (which pass a look comes from: the stains without their mirror, then without their filter)
	View(p + cams[1][2], p + cams[1][3])
	Wait(0.6)
	Client("cvar", { name = "abl_ground_debug", value = "1" })
	Wait(0.4) Snap("tV_pool_top_nogloss")
	Client("cvar", { name = "abl_ground_debug", value = "2" })
	Wait(0.4) Snap("tV_pool_top_nofilter")
	Client("cvar", { name = "abl_ground_debug", value = "0" })
	Wait(0.3)
	Round("rest")
	-- at rest, from the same camera: what still changes on screen without any cause
	View(p + cams[2][2], p)
	Wait(0.6)
	game.SetTimeScale(BURST_SCALE)
	Client("poolburst", { name = "tV_pool_still", frames = 40 })
	Wait(40 * 0.017 + 0.5)
	game.SetTimeScale(1)
	Stats("tV_pool")
end)

-- Drops in the air beside a head (a size everybody knows), in a game slowed twenty times:
-- 0.01, 0.05, 0.2 and 0.6 ml, left to right.
onRequest.audit_drops = true
Add("audit_drops", function()
	local p = AcceptSpot()
	local bot = NewBot()
	Place(bot, p + Vector(0, 14, 0), -90)
	Wait(1.2)
	-- (a bot stands facing +x whatever it was told: the drops hang in front of its face, at its depth)
	local head = ABL.DevHitboxCenter(ABL.ZC.GetBody(bot), "head") or (p + Vector(0, 14, 64))
	View(head + Vector(9, -22, 0), head + Vector(9, 0, 0))
	Wait(0.6)
	game.SetTimeScale(0.1)
	for i, v in ipairs({ 0.01, 0.05, 0.2, 0.6 }) do
		Client("spray", { pos = head + Vector(4 + i * 2.6, 0, 3), dir = Vector(0, 0, -1), speed = 1, count = 1, vol = v, cone = 0.01 })
	end
	Client("stats", { name = "tV_drops_air" })
	Snap("tV_drops_a", 0.02)
	Snap("tV_drops_b", 0.03)
	Snap("tV_drops_c", 0.04)
	game.SetTimeScale(1)
	Wait(1.5)
	-- and as they are met in play: a handful thrown down past the face, seen from four steps away
	View(head + Vector(9, -60, 4), head + Vector(9, 0, -6))
	Wait(0.6)
	game.SetTimeScale(0.1)
	Client("spray", { pos = head + Vector(11, 0, 6), dir = Vector(0, 0, -1), speed = 60, count = 12, vol = 0.05, cone = 0.3 })
	Snap("tV_drops_play_a", 0.03)
	Snap("tV_drops_play_b", 0.04)
	game.SetTimeScale(1)
	Stats("tV_drops")
end)

-- Blood running on a body: over cloth (the thigh) and over skin (head and neck).
onRequest.audit_stream = true
Add("audit_stream", function()
	local p = AcceptSpot()
	local bot = NewBot()
	Place(bot, p, 90)
	Wait(1.2)
	local body = ABL.ZC.GetBody(bot)
	local head = ABL.DevHitboxCenter(body, "head") or (p + Vector(0, 0, 64))
	ABL.DevAddWound(bot, "lthigh", 12, false, 4, 0.45, 0.5)
	ABL.DevAddWound(bot, "head", 6, false, 3, 0.6, 0.5)
	View(p + Vector(5, 24, 21), p + Vector(0, 0, 16))
	Wait(5) Snap("tV_stream_leg_5s")
	Wait(7) Snap("tV_stream_leg_12s")
	View(p + Vector(3, 13, 17), p + Vector(0, 2, 13))
	Wait(0.6) Snap("tV_stream_leg_close")
	Client("cvar", { name = "abl_flow_view", value = "1" })
	Wait(0.4) Snap("tV_stream_leg_close_depth")
	Client("cvar", { name = "abl_flow_view", value = "0" })
	for i, off in ipairs({ Vector(0, 17, 1), Vector(13, 11, 1), Vector(-13, 11, 1), Vector(0, -17, 1) }) do
		View(head + off, head)
		Wait(0.6) Snap("tV_stream_head_" .. i)
	end
	View(p + Vector(6, 20, 9), p + Vector(0, 2, 3))
	Wait(0.6) Snap("tV_stream_foot")
	Stats("tV_stream")
end)

-- An arterial jet from the neck, close, as single frames and as a run of frames.
onRequest.audit_jet = true
Add("audit_jet", function()
	local p = AcceptSpot()
	local bot = NewBot()
	Place(bot, p, 0)
	Wait(1.2)
	-- (the wound is at the nape and a bot stands facing +x: the jet leaves toward -x)
	local neck = ABL.DevHitboxCenter(ABL.ZC.GetBody(bot), "neck") or (p + Vector(0, 0, 58))
	View(neck + Vector(-14, -30, 4), neck + Vector(-14, 0, -3))
	ABL.DevAddWound(bot, "neck", 14, true, 3, 0.5, 0.5)
	Wait(1.5) Snap("tV_jet_a")
	Wait(0.3) Snap("tV_jet_b")
	game.SetTimeScale(BURST_SCALE)
	Client("poolburst", { name = "tV_jet_run", frames = 30 })
	Wait(30 * 0.017 + 0.5)
	game.SetTimeScale(1)
	View(neck + Vector(-30, -75, 0), neck + Vector(-30, 0, -28))
	Wait(0.6) Snap("tV_jet_whole")
	View(p + Vector(-40, -26, 16), p + Vector(-40, 0, 0))
	Wait(4) Snap("tV_jet_floor")
	Stats("tV_jet")
end)

-- Drops against a wall and what runs down from them, close.
onRequest.audit_wall = true
Add("audit_wall", function()
	local p, wallDir, wallDist = FindSpot({ open = 110, wall = true, outdoor = true })
	if not p then Log("audit_wall: no wall spot") return end
	Client("clear", {})
	Wait(0.4)
	local wallPoint = p + Vector(0, 0, 50) + wallDir * wallDist
	local side = wallDir:Cross(Vector(0, 0, 1))
	View(wallPoint - wallDir * 30 + side * 6, wallPoint - Vector(0, 0, 8))
	Client("spray", { pos = wallPoint - wallDir * 45, dir = wallDir, speed = 260, count = 14, vol = 0.05 })
	Client("spray", { pos = wallPoint - wallDir * 30 + Vector(0, 0, 14), dir = (wallDir + Vector(0, 0, 0.2)):GetNormalized(), speed = 200, count = 30, vol = 0.12 })
	Wait(1.5) Snap("tV_wall_1s")
	Wait(5) Snap("tV_wall_6s")
	View(wallPoint - wallDir * 13 + side * 3 - Vector(0, 0, 6), wallPoint - Vector(0, 0, 12))
	Wait(0.6) Snap("tV_wall_close")
	Wait(8)
	View(wallPoint - wallDir * 30 + side * 6, wallPoint - Vector(0, 0, 8))
	Wait(0.6) Snap("tV_wall_15s")
	View(p + wallDir * (wallDist - 22) + Vector(0, 0, 12), p + wallDir * wallDist)
	Wait(0.6) Snap("tV_wall_foot")
	Stats("tV_wall")
end)

-- The pool alone, as close as a player who crouches over it, and as it is met in play: the
-- edge filling the frame while it moves and at rest, the camera going round the settled pool,
-- a dim place, a slope, and a pool that begins from drops. (tM_* pictures and bursts.)
-- (a measurement: the pools without the filter under their colour, for the scenes that follow)
onRequest.pool_nofilter = true
Add("pool_nofilter", function() Client("cvar", { name = "abl_pool_debug", value = "2" }) Wait(0.3) end)
-- (measurements: the load governor's budget at its largest, so that nothing is scaled down and
-- a profile shows what full quality costs; and back)
-- After the fight: six characters whose wounds have been closed. Nothing runs any more; what is
-- on them dries, for minutes. What blood costs in which nothing happens, seen from near.
onRequest.perf_idle = true
Add("perf_idle", function()
	local p = FindSpot({ open = 260, outdoor = true })
	local bots = {}
	for i = 1, 6 do
		local b = NewBot()
		bots[i] = b
		Place(b, p + Vector((i - 3.5) * 36, 0, 0), 90)
		ABL.DevAddWound(b, (i % 2 == 0) and "chest" or "lthigh", 9 + i, false, 3, 0.5, 0.5)
		if i % 3 == 0 then ABL.DevAddWound(b, "head", 6, false, 3, 0.6, 0.5) end
	end
	View(p + Vector(0, -150, 80), p + Vector(0, 0, 36))
	Client("profile", { reset = true })
	Wait(14)
	Profile("tI_bleeding", true)
	Shot("tI_bleeding")
	for _, b in ipairs(bots) do if IsValid(b) then ABL.DevHeal(b) end end
	Wait(8) Profile("tI_stopped_8s", true)
	Client("flowdump", { name = "tI_stopped_8s" })
	Wait(22) Profile("tI_stopped_30s", true)
	Client("flowdump", { name = "tI_stopped_30s" })
	Shot("tI_stopped_30s")
	Wait(30) Profile("tI_stopped_60s", true)
	Client("flowdump", { name = "tI_stopped_60s" })
	Shot("tI_stopped_60s")
	local chest = IsValid(bots[2]) and ABL.DevHitboxCenter(ABL.ZC.GetBody(bots[2]), "chest") or (p + Vector(-54, 0, 48))
	View(chest + Vector(4, -34, 2), chest + Vector(0, 0, -6))
	Wait(0.6) Shot("tI_close_chest_60s")
	local leg = IsValid(bots[1]) and ABL.DevHitboxCenter(ABL.ZC.GetBody(bots[1]), "lthigh") or (p + Vector(-90, 0, 24))
	View(leg + Vector(6, -30, 0), leg + Vector(0, 0, -6))
	Wait(0.6) Shot("tI_close_leg_60s")
	View(p + Vector(0, -150, 80), p + Vector(0, 0, 36))
	Wait(38) Profile("tI_stopped_100s", true)
	Client("flowdump", { name = "tI_stopped_100s" })
	Shot("tI_stopped_100s")
	-- ... and as bodies on the ground: nothing on them moves at all
	for _, b in ipairs(bots) do if IsValid(b) and b:Alive() then b:Kill() end end
	Wait(12) Profile("tI_bodies_12s", true)
	Client("flowdump", { name = "tI_bodies_12s" })
	Shot("tI_bodies_12s")
	Wait(20) Profile("tI_bodies_32s", true)
	Client("flowdump", { name = "tI_bodies_32s" })
end)

-- A clean slate between two measuring scenes: no bots (a bot that is used again comes back in
-- whatever state the scene before left it), no bodies, no blood.
onRequest.reset_bots = true
Add("reset_bots", function()
	for _, b in ipairs(player.GetBots()) do b:Kick("ABL test reset") end
	botsUsed = {}
	Wait(0.5)
	for _, r in ipairs(ents.FindByClass("prop_ragdoll")) do r:Remove() end
	Client("clear", {})
	Wait(1.5)
end)

-- Strips against nodes. Blood that has stopped, on a body that lies still, drawn from its static
-- strips and, within the same seconds and from the same place: with its soft pieces from their
-- nodes (abl_flow_debug 4), all from its nodes (1), from its nodes with every vertex position
-- through a Vector (3), and from strips again. They are to be one picture five times
-- (tools/harness/framechange.ps1 counts what differs).
onRequest.audit_still = true
Add("audit_still", function()
	local p = AcceptSpot()
	local bot = NewBot()
	Place(bot, p, 0)
	Wait(1.2)
	ABL.DevAddWound(bot, "lthigh", 12, false, 4, 0.45, 0.5)
	ABL.DevAddWound(bot, "chest", 10, false, 3, 0.5, 0.5)
	ABL.DevAddWound(bot, "head", 6, false, 3, 0.6, 0.5)
	View(p + Vector(40, 70, 50), p + Vector(0, 0, 36))
	Wait(12)
	Snap("tW_bleeding")
	ABL.DevHeal(bot)
	-- (what is on it dries in seconds: the test is of the drawing, not of the drying)
	RunConsoleCommand("abl_drying_scale", "0.15")
	Wait(4)
	if IsValid(bot) and bot:Alive() then bot:Kill() end
	Wait(16)
	local rag, best = nil, 1e9
	for _, r in ipairs(ents.FindByClass("prop_ragdoll")) do
		local d = r:GetPos():DistToSqr(p)
		if d < best then rag, best = r, d end
	end
	local c = IsValid(rag) and rag:WorldSpaceCenter() or (p + Vector(0, 0, 10))
	Client("flowdump", { name = "tW_still" })
	for k, cam in ipairs({ Vector(8, 34, 40), Vector(-20, 14, 22), Vector(22, -12, 20) }) do
		View(c + cam, c)
		Wait(0.8)
		Wait(1.5)
		for q, dbg in ipairs({ "0", "4", "1", "3", "0" }) do
			Client("cvar", { name = "abl_flow_debug", value = dbg })
			Wait(0.5) Snap(string.format("tW_still%d_%03d", k, q - 1))
		end
	end
	Client("flowdump", { name = "tW_still_end" })
	RunConsoleCommand("abl_drying_scale", "1")
	Stats("tW_still")
end)

onRequest.probe_mesh = true
Add("probe_mesh", function() Client("probemesh", {}) Wait(1.5) end)
onRequest.perf_budget_max = true
Add("perf_budget_max", function() Client("cvar", { name = "abl_budget_ms", value = "20" }) Wait(0.3) end)
onRequest.perf_budget_std = true
Add("perf_budget_std", function() Client("cvar", { name = "abl_budget_ms", value = "2.5" }) Wait(0.3) end)
onRequest.pool_fullpaint = true
Add("pool_fullpaint", function() Client("cvar", { name = "abl_pool_debug", value = "32" }) Wait(0.3) end)
onRequest.pool_filter = true
Add("pool_filter", function() Client("cvar", { name = "abl_pool_debug", value = "0" }) Wait(0.3) end)

onRequest.audit_pool_macro = true
Add("audit_pool_macro", function()
	local p = AcceptSpot()
	local function Burst(name, frames)
		game.SetTimeScale(BURST_SCALE)
		Client("poolburst", { name = name, frames = frames })
		Wait(frames * 0.017 + 0.5)
		game.SetTimeScale(1)
	end
	local macro, look = Vector(-1, -6.8, 2.8), Vector(0, -1.2, 0)
	-- 1. a level floor in the sun: 1.5 ml/s for 12 s
	View(p + macro, p + look)
	Wait(0.5)
	local t0 = CurTime()
	Client("poolfeed", { pos = p, rate = 1.5, secs = 12, jitter = 0.05 })
	Wait(2.2)
	Burst("tM_macro_grow", 130)
	Wait(math.max(0, t0 + 17 - CurTime()))
	Snap("tM_macro_rest")
	Client("pooltone", { name = "sun" })
	Mirror(false) Snap("tM_macro_rest_plain")
	Mirror(true)
	View(p + Vector(-2, -10, 9), p)
	Wait(0.6) Snap("tM_close_rest")
	View(p + Vector(-10, -70, 64), p)
	Wait(0.6) Snap("tM_play_rest")
	View(p + Vector(-3, -30, 8.5), p)
	Wait(0.6) Snap("tM_low_rest")
	-- the camera on an arc round the settled pool
	Client("orbit", { center = p, dist = 13, z = 7, a0 = -125, a1 = -55, secs = 1.5 })
	Burst("tM_orbit", 100)
	Client("orbit", { center = p + Vector(0, -1.6, 0), dist = 5.5, z = 2.6, a0 = -110, a1 = -70, secs = 1.5 })
	Burst("tM_orbit_macro", 100)
	-- 2. a dim place
	local q = FindSpot({ open = 90, indoor = true })
	if q then
		Log("  dim spot: Vector(%.1f, %.1f, %.1f)", q.x, q.y, q.z)
		View(q + Vector(-2, -10, 9), q)
		Client("poolfeed", { pos = q, rate = 1.5, secs = 10, jitter = 0.05 })
		Wait(14)
		Snap("tM_dim_close")
		Client("pooltone", { name = "dim" })
		View(q + macro, q + look)
		Wait(0.6) Snap("tM_dim_macro")
		View(q + Vector(-3, -30, 8.5), q)
		Wait(0.6) Snap("tM_dim_low")
	else
		Log("  audit_pool_macro: no dim spot")
	end
	-- 3. a slope of four degrees
	Client("clear", {})
	Wait(0.5)
	local plate = Plate(p, "models/hunter/plates/plate2x4.mdl", Angle(4, 0, 0))
	View(p + Vector(-8, 30, 42), p + Vector(-6, 0, 23))
	Client("poolfeed", { pos = p + Vector(-14, 0, 40), rate = 2, secs = 8, jitter = 0.05 })
	Wait(4) Snap("tM_slope_4s")
	Wait(4) Snap("tM_slope_8s")
	Wait(8) Snap("tM_slope_16s")
	plate:Remove()
	Client("clear", {})
	Wait(0.5)
	-- 4. a pool that begins from drops: one of 0.06 ml every 0.12 s from 40 units up
	local d = p + Vector(24, 6, 0)
	View(d + Vector(-2, -10, 9), d)
	Wait(0.5)
	for i = 1, 110 do
		Client("spray", { pos = d + Vector(0, 0, 40), dir = Vector(0, 0, -1), speed = 20, count = 1, vol = 0.06, cone = 0.05 })
		Wait(0.12)
		if i == 20 then Snap("tM_drip_2s", 0.05) end
		if i == 50 then Snap("tM_drip_6s", 0.05) end
	end
	Wait(1) Snap("tM_drip_14s")
	View(d + macro, d + look)
	Wait(0.6) Snap("tM_drip_macro")
	Stats("tM_macro")
end)

Add("disconnect", function()
	local bot = botsUsed[#botsUsed]
	if IsValid(bot) then
		Stats("t19_before_kick")
		bot:Kick("ABL self-test")
		Wait(3)
		Stats("t19_after_kick")
	end
end)

Add("cleanup", function()
	Stats("t20_before_cleanup")
	game.CleanUpMap()
	Wait(2)
	Stats("t20_after_cleanup")
end)

-- Every scenario starts from a clean scene (no bleeding bots from earlier scenarios, no old blood),
-- so screenshots and timings belong to that scenario alone. These two inspect what the previous
-- scenarios left behind.
local keepState = { disconnect = true, cleanup = true }

local function ResetScene()
	for _, b in ipairs(player.GetBots()) do b:Kick("ABL scenario reset") end
	botsUsed = {}
	-- ragdolls of kicked / dead bots stay behind otherwise
	Wait(0.3)
	for _, r in ipairs(ents.FindByClass("prop_ragdoll")) do r:Remove() end
	-- the scene is empty again, so the good (bright, hard-floored) spots near the host can be reused
	used = {}
	Client("clear", {})
	Wait(1.5)
end

local function RunAll()
	Wait(6)
	Log("maxplayers %d, Z-City %s", game.MaxPlayers(), tostring(ABL.ZC.Present()))
	if game.MaxPlayers() < 4 then Log("WARNING: maxplayers too low for multi-bot scenarios") end
	ParkHost(host:GetPos())
	Client("begin", {})
	Wait(2)
	local list = order
	if plan ~= "all" and plan ~= "" then
		list = {}
		for name in string.gmatch(plan, "[%w_]+") do if T[name] then list[#list + 1] = name end end
	end
	for idx, name in ipairs(list) do
		Log("=== %s", name)
		if idx > 1 and not keepState[name] then ResetScene() end
		local ok, err = pcall(function()
			local sub = coroutine.create(T[name])
			while true do
				local ok2, e2 = coroutine.resume(sub)
				if not ok2 then error(e2) end
				if coroutine.status(sub) == "dead" then break end
				coroutine.yield()
			end
		end)
		if not ok then Log("FAILED %s: %s", name, tostring(err)) end
		Wait(1.5)
	end
	for _, b in ipairs(player.GetBots()) do b:Kick("ABL self-test done") end
	Log("DONE")
	Client("finish", {})
end

hook.Add("PlayerInitialSpawn", "ABL_SelfTest", function(ply)
	if ply:IsBot() or IsValid(host) then return end
	host = ply
	timer.Simple(2, function()
		co = coroutine.create(RunAll)
	end)
end)

hook.Add("Think", "ABL_SelfTest", function()
	if not co or CurTime() < waitUntil then return end
	local ok, err = coroutine.resume(co)
	if not ok then Log("HARNESS ERROR %s", tostring(err)) co = nil return end
	if coroutine.status(co) == "dead" then co = nil end
end)

-- Harness control file (garrysmod/data/abl_command.txt): whitelisted commands only, so a test
-- driver outside the game can restart the map (reloading all Lua) or quit between runs.
timer.Create("ABL_SelfTestCommand", 1, 0, function()
	if not file.Exists("abl_command.txt", "DATA") then return end
	local c = string.Trim(file.Read("abl_command.txt", "DATA") or "")
	file.Delete("abl_command.txt")
	if c == "restart" then
		Log("restart requested")
		game.ConsoleCommand("changelevel " .. game.GetMap() .. "\n")
	elseif c == "quit" then
		game.ConsoleCommand("quit\n")
	end
end)
