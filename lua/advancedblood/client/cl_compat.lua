-- Z-City compatibility, client side: with the takeover on (abl_zcity_takeover, default 1)
-- AdvancedBlood is the only blood on screen. (The server side is server/sv_compat.lua; every
-- Z-City lookup goes through sh_zcity.lua; all of it is described in docs/ZCITY_INTEGRATION.md.)
--
-- Z-City's physiology is not touched: its wound lists, synced bleed rates, pulse and blood volume
-- are what ABL bleeds from (venous and arterial wounds, the neck of a headless body). Its wound
-- think skips its own blood emission while hg.BloodTakenOver() is true. Every other particle it
-- makes (hg.addBloodPart / hg.addBloodPart2, local callers included: bursts, squirts, gib spills,
-- clouds) goes through hg.BloodPartRedirect / hg.BloodCloudRedirect into ABL drops and mist.
-- "hg_bloodimpact" becomes an ABL spray unless an abl_hit already covered that spot; "bloodsquirt2"
-- becomes blood from the mouth.
--
-- With the convar at 0 everything passes straight through to Z-City's own particles.
-- abl_zcity_status prints what is in place and what was caught.

ABL.NoJIT()
ABL.Compat = ABL.Compat or {}
local CP = ABL.Compat
local C, N, Z = ABL.Config, ABL.Net, ABL.ZC

if CP.Uninstall then pcall(CP.Uninstall) end

CP.installed = false
CP.recv = {}
CP.stat = CP.stat or {}
local stat = CP.stat
for _, k in ipairs({ "adopted", "clouds", "impacts", "covered", "coughs", "bursts", "drained",
	"zDrawn", "zDecals", "leakDrawn", "leakDecals", "rewraps" }) do
	stat[k] = stat[k] or 0
end

local function Takeover()
	return C.cl.takeover:GetBool() and ABL.Enabled()
end
CP.Takeover = Takeover

------------------------------------------------------------------------------------------
-- Z-City's particles as ABL drops
------------------------------------------------------------------------------------------
local ADOPT_MAX = 48
local budget, budgetFrame = 0, -1
local holders = setmetatable({}, { __mode = "k" })

local function Budget()
	local f = FrameNumber()
	if f ~= budgetFrame then budgetFrame, budget = f, ADOPT_MAX end
	if budget <= 0 then
		stat.drained = stat.drained + 1
		return false
	end
	budget = budget - 1
	return true
end

local function PartRedirect(pos, vel, w, artery, kishki, owner, hidden)
	if not Takeover() then return false end
	if hidden or not (isvector(pos) and isvector(vel)) or not Budget() then return true end
	local vol
	if kishki then
		local v = C.ZCity.burstVol
		vol = math.Rand(v[1], v[2])
		stat.bursts = stat.bursts + 1
	else
		vol = (artery and 0.05 or 0.025) * math.Rand(0.6, 1.4)
		stat.adopted = stat.adopted + 1
	end
	local d = ABL.Drops.Spawn(pos.x, pos.y, pos.z, vel.x, vel.y, vel.z, vol, nil, 1, artery and 1 or 0)
	if d and artery and IsValid(owner) then
		local h = holders[owner]
		if not h then
			h = {}
			holders[owner] = h
		end
		ABL.Drops.Link(d, h, "zc")
	end
	return true
end

local function CloudRedirect(pos, vel, w, water, owner)
	if not Takeover() then return false end
	if not (isvector(pos) and isvector(vel)) or not Budget() then return true end
	stat.clouds = stat.clouds + 1
	if water then
		ABL.Drops.WaterCloud(pos, vel, 0.05)
	else
		ABL.Drops.Mist(pos, vel, 1, math.Clamp((w or 60) * 0.15, 4, 24))
	end
	return true
end

local function TakenOver()
	return CP.installed and Takeover()
end

local function SetRedirects()
	if not istable(hg) then return end
	hg.BloodPartRedirect = PartRedirect
	hg.BloodCloudRedirect = CloudRedirect
	hg.BloodTakenOver = TakenOver
end

------------------------------------------------------------------------------------------
-- Impact sprays. Z-City sends "hg_bloodimpact" for bullet entries and exits (abl_hit already
-- spatters those), bone breaks, skull fractures and melee. A spray waits a moment and is dropped
-- if an abl_hit landed near it meanwhile.
------------------------------------------------------------------------------------------
local SPRAY_WAIT, HIT_NEAR, HIT_KEEP = 0.25, 40, 1
local pendingSprays, recentHits = {}, {}
local sprayRng

function CP.NoteHit(x, y, z)
	if #recentHits >= 64 then table.remove(recentHits, 1) end
	recentHits[#recentHits + 1] = { x, y, z, RealTime() }
end

local function Covered(pos, now)
	for i = #recentHits, 1, -1 do
		local h = recentHits[i]
		if now - h[4] > HIT_KEEP then
			table.remove(recentHits, i)
		else
			local dx, dy, dz = h[1] - pos.x, h[2] - pos.y, h[3] - pos.z
			if dx * dx + dy * dy + dz * dz < HIT_NEAR * HIT_NEAR then return true end
		end
	end
	return false
end

local function Spray(pos, dir, mul, amt)
	if not ABL.InWorld(pos.x, pos.y, pos.z) then return end
	local dx, dy, dz = ABL.Norm(-dir.x, -dir.y, -dir.z)
	if dx == 0 and dy == 0 and dz == 0 then dx, dy, dz = 0, 0, 1 end
	sprayRng = sprayRng or ABL.RNG(1977)
	mul = math.Clamp(tonumber(mul) or 1, 0, 20)
	local n = math.Clamp(math.floor(math.Clamp(amt, 1, 8) * 3 + mul), 3, 36)
	local vk = 0.8 + mul / 20
	for _ = 1, n do
		local cx, cy, cz = ABL.Emission.Cone(sprayRng, dx, dy, dz, 0.45)
		local sp = sprayRng:Range(60, 220) * vk
		ABL.Drops.Spawn(pos.x + dx * 2, pos.y + dy * 2, pos.z + dz * 2, cx * sp, cy * sp, cz * sp + 15, sprayRng:Range(0.02, 0.07), nil, 1, 2)
	end
	if mul >= 4 then ABL.Drops.Mist(pos, Vector(dx, dy, dz) * 40, math.min(math.floor(mul / 2), 6), 6 + mul) end
end

local function FlushSprays()
	if #pendingSprays == 0 then return end
	local now = RealTime()
	for i = #pendingSprays, 1, -1 do
		local sp = pendingSprays[i]
		if now >= sp[5] then
			table.remove(pendingSprays, i)
			if Covered(sp[1], now) then
				stat.covered = stat.covered + 1
			else
				Spray(sp[1], sp[2], sp[3], sp[4])
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Net receivers of Z-City's blood messages, replaced. fn(orig, len, ply) decides what becomes of
-- one message; the original receiver is kept and called while the takeover is off.
------------------------------------------------------------------------------------------
local RECEIVERS = {}

local function Replace(name)
	local fn = RECEIVERS[name]
	local cur = net.Receivers and net.Receivers[name]
	if not isfunction(cur) then return false end
	local r = CP.recv[name]
	if r and r.wrap == cur then return true end
	local orig = cur
	local wrap = function(len, ply) return fn(orig, len, ply) end
	CP.recv[name] = { orig = orig, wrap = wrap }
	net.Receive(name, wrap)
	return true
end

RECEIVERS["hg_bloodimpact"] = function(orig, len, ply)
	if not Takeover() then return orig(len, ply) end
	stat.impacts = stat.impacts + 1
	local pos, dir = net.ReadVector(), net.ReadVector()
	local mul, amt = net.ReadFloat(), net.ReadInt(8)
	if #pendingSprays < 32 then pendingSprays[#pendingSprays + 1] = { pos, dir, mul, amt, RealTime() + SPRAY_WAIT } end
end

-- Blood coughed or vomited up (a lung or stomach wound, bleeding inside): the same event, as ABL
-- droplets out of the mouth (cl_emission.lua) instead of Z-City's particles.
RECEIVERS["bloodsquirt2"] = function(orig, len, ply)
	if not Takeover() then return orig(len, ply) end
	stat.coughs = stat.coughs + 1
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end
	local boneName = net.ReadString()
	local m = net.ReadMatrix()
	local pos = net.ReadVector()
	local dir = net.ReadVector()
	local owner = isfunction(hg.RagdollOwner) and hg.RagdollOwner(ent) or nil
	local ok, err = pcall(ABL.Emission.Cough, IsValid(owner) and owner or ent, boneName, m, pos, dir)
	if not ok then ErrorNoHalt("[AdvancedBlood] cough: " .. tostring(err) .. "\n") end
end

local function WrapReceivers()
	for name in pairs(RECEIVERS) do Replace(name) end
end

------------------------------------------------------------------------------------------
-- Counts of what Z-City's particle code draws and stamps, for abl_zcity_status.
------------------------------------------------------------------------------------------
local lastCount, lastOn

local function Lists()
	if not istable(hg) then return nil, nil end
	local a, b = hg.bloodparticles1, hg.bloodparticles2
	return istable(a) and a or nil, istable(b) and b or nil
end

local function Drain()
	local t1, t2 = Lists()
	if not t1 and not t2 then return end
	local on = Takeover()
	-- decals Z-City's particle code has stamped since the last frame (it stamps while it draws:
	-- they belong to the state the takeover was in then)
	local bc = tonumber(hg.bloodcount) or 0
	if lastCount and bc > lastCount then
		stat.zDecals = stat.zDecals + (bc - lastCount)
		if lastOn then
			stat.leakDecals = stat.leakDecals + (bc - lastCount)
			stat.lastLeak = RealTime()
		end
	end
	lastCount, lastOn = bc, on
end

local function Witness(depth, skybox)
	if depth or skybox then return end
	local t1, t2 = Lists()
	local n = (t1 and #t1 or 0) + (t2 and #t2 or 0)
	if n == 0 then return end
	stat.zDrawn = stat.zDrawn + n
	if Takeover() then
		stat.leakDrawn = stat.leakDrawn + n
		stat.lastLeak = RealTime()
	end
end

------------------------------------------------------------------------------------------
-- Install, keep in place, take off
------------------------------------------------------------------------------------------
local function Install()
	if CP.installed then return true end
	if not Z.Present() then return false end
	SetRedirects()
	WrapReceivers()
	hook.Add("PreRender", "ABL_CompatDrain", Drain)
	hook.Add("PostDrawTranslucentRenderables", "ABL_CompatWitness", Witness)
	hook.Add("Think", "ABL_CompatSprays", FlushSprays)
	CP.installed = true
	ABL.Print("Z-City integration installed (takeover %s)", Takeover() and "on" or "off")
	return true
end
CP.Install = Install

function CP.Uninstall()
	if istable(hg) then
		if hg.BloodPartRedirect == PartRedirect then hg.BloodPartRedirect = nil end
		if hg.BloodCloudRedirect == CloudRedirect then hg.BloodCloudRedirect = nil end
		if hg.BloodTakenOver == TakenOver then hg.BloodTakenOver = nil end
	end
	for name, r in pairs(CP.recv or {}) do
		if net.Receivers and net.Receivers[name] == r.wrap then net.Receive(name, r.orig) end
	end
	hook.Remove("PreRender", "ABL_CompatDrain")
	hook.Remove("PostDrawTranslucentRenderables", "ABL_CompatWitness")
	hook.Remove("Think", "ABL_CompatSprays")
	CP.recv = {}
	CP.installed = false
end

hook.Add("InitPostEntity", "ABL_CompatInstall", function()
	if Install() then return end
	timer.Create("ABL_CompatRetry", 1, 30, function()
		if Install() then timer.Remove("ABL_CompatRetry") end
	end)
end)
hook.Add("HomigradRun", "ABL_CompatInstall", function() timer.Simple(0, Install) end)

-- The redirects and receivers are still in place? A few times at most: something that keeps
-- putting its own function back is left alone after that, and abl_zcity_status says so.
local REWRAP_MAX = 8
local function InPlace()
	if not istable(hg) then return true end
	if hg.BloodPartRedirect ~= PartRedirect or hg.BloodCloudRedirect ~= CloudRedirect or hg.BloodTakenOver ~= TakenOver then return false end
	for name in pairs(RECEIVERS) do
		local cur = net.Receivers and net.Receivers[name]
		local r = CP.recv[name]
		if isfunction(cur) and not (r and r.wrap == cur) then return false end
	end
	return true
end

local function Watch()
	if not CP.installed or stat.rewraps >= REWRAP_MAX then return end
	if InPlace() then return end
	stat.rewraps = stat.rewraps + 1
	SetRedirects()
	WrapReceivers()
	ABL.Print("Z-City integration put back in place (%d)", stat.rewraps)
end
timer.Create("ABL_CompatWatch", 5, 0, Watch)
if IsValid(LocalPlayer()) then timer.Simple(0, Install) end -- lua refresh

------------------------------------------------------------------------------------------
-- abl_zcity_status
------------------------------------------------------------------------------------------
local function State(present, ok, what)
	if not present then return "not in this Z-City" end
	if not ok then return "NOT TAKEN OVER (Z-City's own is running)" end
	if not Takeover() then return "passed through (takeover off)" end
	return what
end

-- Lines of the report, and the number of Z-City blood paths that can still draw.
function CP.Status()
	local out = {}
	local function P(s, ...) out[#out + 1] = string.format(s, ...) end
	local on = Takeover()
	local present = Z.Present()
	P("AdvancedBlood: %s (abl_enabled %d, abl_cl_enabled %d)", ABL.Enabled() and "ACTIVE" or "OFF", C.sv.enabled:GetInt(), C.cl.enabled:GetInt())
	local sig = {}
	for _, s in ipairs(Z.Signals()) do sig[#sig + 1] = (s[2] and "+" or "-") .. s[1] end
	P("Z-City: %s (gamemode %s; %s)", present and "DETECTED" or "NOT DETECTED", tostring(engine.ActiveGamemode()), table.concat(sig, " "))
	if not present then
		P("Nothing of Z-City's is touched; AdvancedBlood has no wounds to bleed from outside Z-City.")
		return out, 0
	end
	local t1, t2 = Lists()
	local open = 0
	local function Path(label, isThere, ok, what)
		if isThere and not ok then open = open + 1 end
		P("  %-46s %s", label, State(isThere, ok, what))
	end
	P("Takeover: %s (abl_zcity_takeover %d)%s", on and "ON" or "OFF", C.cl.takeover:GetInt(), CP.installed and "" or " - NOT INSTALLED YET")
	Path("wound drips, arterial jets, fountain (think)", true, hg.BloodTakenOver == TakenOver, "skipped, AdvancedBlood bleeds them")
	Path("hg.addBloodPart (bursts, squirts, gib spills)", isfunction(hg.addBloodPart), hg.BloodPartRedirect == PartRedirect, string.format("as AdvancedBlood drops, %d + %d burst blobs", stat.adopted, stat.bursts))
	Path("hg.addBloodPart2 (clouds, mist)", isfunction(hg.addBloodPart2), hg.BloodCloudRedirect == CloudRedirect, string.format("as AdvancedBlood mist, %d", stat.clouds))
	P("  over the per-frame budget, dropped: %d", stat.drained)
	for _, e in ipairs({ { "hg_bloodimpact", "net hg_bloodimpact (impact spray)", "as AdvancedBlood spray, %d (" .. stat.covered .. " covered by abl_hit)", "impacts" },
		{ "bloodsquirt2", "net bloodsquirt2 (blood coughed up)", "as AdvancedBlood drops, %d", "coughs" } }) do
		local cur = net.Receivers and net.Receivers[e[1]]
		local r = CP.recv[e[1]]
		Path(e[2], isfunction(cur), r ~= nil and r.wrap == cur, string.format(e[3], stat[e[4]]))
	end
	if stat.rewraps > 0 then P("  put back in place %d time(s)%s", stat.rewraps, stat.rewraps >= REWRAP_MAX and " - GIVEN UP, something keeps undoing it" or "") end
	P("Z-City visual blood: %s", not on and "RUNNING (takeover off)" or (open == 0 and "SUPPRESSED" or "PARTLY RUNNING"))
	P("  Z-City particles on screen with the takeover on: %d particle-frames; their decals: %d%s",
		stat.leakDrawn, stat.leakDecals, stat.lastLeak and string.format(" (last %.0f s ago)", RealTime() - stat.lastLeak) or "")
	P("  seen in all, takeover on or off: %d particle-frames, %d decals; in the lists now: %d", stat.zDrawn, stat.zDecals, (t1 and #t1 or 0) + (t2 and #t2 or 0))
	-- physiology: Z-City's organism, as this client has it
	local lp = LocalPlayer()
	local orgs = 0
	for _, p in ipairs(player.GetAll()) do
		if istable(p.organism) then orgs = orgs + 1 end
	end
	local org = IsValid(lp) and istable(lp.organism) and lp.organism or nil
	P("Z-City physiology: %s (organisms on this client %d%s)", orgs > 0 and "ACTIVE" or "no organism seen", orgs,
		org and string.format("; yours: blood %.0f ml, pulse %.0f", tonumber(org.blood) or 0, tonumber(org.pulse) or 0) or "")
	local nw = 0
	for _, src in ipairs(ABL.Sources.list) do nw = nw + #src.woundList end
	P("AdvancedBlood bleeding: %s (%d bleeding bodies, %d wounds, %d drops in the air)", ABL.Enabled() and "ACTIVE" or "OFF", #ABL.Sources.list, nw, ABL.Drops.Count())
	P("Duplicate visual systems: %d%s", on and open or 1, on and "" or " (the takeover is off: Z-City's blood runs next to AdvancedBlood's)")
	return out, on and open or 1
end

net.Receive(N.ZCS, function()
	local present, sup = net.ReadBool(), net.ReadBool()
	local rh = net.ReadUInt(2)
	local decal, effect = net.ReadBool(), net.ReadBool()
	local hits, decals, effects = net.ReadUInt(24), net.ReadUInt(24), net.ReadUInt(24)
	local orgs = net.ReadUInt(8)
	print(string.format("Server: Z-City %s; its blood decals and puffs are %s", present and "detected" or "NOT detected",
		sup and "SUPPRESSED" or "KEPT (abl_zcity_hitdecals 1, abl_enabled 0 or no Z-City)"))
	if present then
		print(string.format("  decals behind every bullet hit (hook)            %s, %d left out", rh == 2 and "wrapped" or (rh == 1 and "NOT WRAPPED" or "not in this Z-City"), hits))
		print(string.format("  blood decals by name (cuts, claws, gibs, charges) %s, %d left out", decal and "caught" or "something else replaced util.Decal since (ABL's part may still run inside it: watch the count)", decals))
		print(string.format("  blood puffs by name (brain hits)                  %s, %d left out", effect and "caught" or "something else replaced util.Effect since (ABL's part may still run inside it: watch the count)", effects))
		print(string.format("  physiology: %d player organisms run by Z-City", orgs))
	end
	if net.ReadBool() then
		local blood, bleed, pulse = net.ReadFloat(), net.ReadFloat(), net.ReadFloat()
		local nv, na = net.ReadUInt(8), net.ReadUInt(8)
		print(string.format("  yours on the server: blood %.0f ml, bleeding %.2f, pulse %.0f, wounds %d + %d arterial", blood, bleed, pulse, nv, na))
	end
end)

concommand.Add("abl_zcity_status", function()
	for _, line in ipairs((CP.Status())) do print(line) end
	net.Start(N.ZCS)
	net.SendToServer()
end)
