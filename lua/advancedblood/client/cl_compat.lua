ABL.NoJIT()
ABL.Compat = ABL.Compat or {}
local CP = ABL.Compat
local C, N, Z = ABL.Config, ABL.Net, ABL.ZC

if CP.Uninstall then pcall(CP.Uninstall) end

CP.installed = false
CP.recv = {}
CP.stat = CP.stat or {}
local stat = CP.stat
for _, k in ipairs({ "landed", "adopted", "clouds", "coughs", "drained", "zDrawn", "zDecals", "leakDrawn", "leakDecals", "rewraps" }) do
	stat[k] = stat[k] or 0
end

local function Takeover()
	return C.cl.takeover:GetBool() and ABL.Enabled()
end
CP.Takeover = Takeover

local LAND_MAX = 48
local budget, budgetFrame = 0, -1

local function Budget()
	local f = FrameNumber()
	if f ~= budgetFrame then budgetFrame, budget = f, LAND_MAX end
	if budget <= 0 then
		stat.drained = stat.drained + 1
		return false
	end
	budget = budget - 1
	return true
end

local function LandRedirect(pos, normal, tr, artery, amount, size, vel)
	if not Takeover() then return false end
	if not Budget() then return true end
	stat.landed = stat.landed + 1
	local vol = math.Clamp((amount or 0.2) * (artery and 0.09 or 0.06), 0.004, 0.45)
	local vx, vy, vz = -normal.x * 60, -normal.y * 60, -normal.z * 60
	if isvector(vel) then
		local into = vel:Dot(normal)
		vx, vy, vz = vel.x, vel.y, vel.z
		if into > -60 then
			local k = -60 - into
			vx, vy, vz = vx + normal.x * k, vy + normal.y * k, vz + normal.z * k
		end
	end
	ABL.Drops.Spawn(pos.x + normal.x, pos.y + normal.y, pos.z + normal.z, vx, vy, vz, vol, nil, 1, artery and 1 or 0)
	return true
end

local BURST_VOL_MIN, BURST_VOL_MAX = 0.1, 0.35

local function PartRedirect(pos, vel, w, artery, kishki, owner, hidden)
	if not Takeover() then return false end
	if hidden or not (isvector(pos) and isvector(vel)) or not Budget() then return true end
	local vol
	if kishki then
		vol = math.Rand(BURST_VOL_MIN, BURST_VOL_MAX)
	else
		vol = (artery and 0.05 or 0.025) * math.Rand(0.6, 1.4)
	end
	stat.adopted = stat.adopted + 1
	ABL.Drops.Spawn(pos.x, pos.y, pos.z, vel.x, vel.y, vel.z, vol, nil, 1, artery and 1 or 0)
	return true
end

local function CloudRedirect(pos, vel, w, water)
	if not Takeover() then return false end
	if not (isvector(pos) and isvector(vel)) or not Budget() then return true end
	stat.clouds = stat.clouds + 1
	if water then
		ABL.Drops.WaterCloud(pos, vel, 0.05)
	else
		ABL.Drops.Mist(pos, vel, 2, math.Clamp((w or 60) * 0.4, 8, 24))
	end
	return true
end

local function TakenOver()
	return CP.installed and Takeover()
end

local function SetRedirects()
	if not istable(hg) then return end
	hg.BloodLandRedirect = LandRedirect
	hg.BloodPartRedirect = PartRedirect
	hg.BloodCloudRedirect = CloudRedirect
	hg.BloodTakenOver = TakenOver
end

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

local function Install()
	if CP.installed then return true end
	if not Z.Present() then return false end
	SetRedirects()
	WrapReceivers()
	hook.Add("PreRender", "ABL_CompatDrain", Drain)
	hook.Add("PostDrawTranslucentRenderables", "ABL_CompatWitness", Witness)
	CP.installed = true
	ABL.Print("Z-City integration installed (takeover %s)", Takeover() and "on" or "off")
	return true
end
CP.Install = Install

function CP.Uninstall()
	if istable(hg) then
		if hg.BloodLandRedirect == LandRedirect then hg.BloodLandRedirect = nil end
		if hg.BloodPartRedirect == PartRedirect then hg.BloodPartRedirect = nil end
		if hg.BloodCloudRedirect == CloudRedirect then hg.BloodCloudRedirect = nil end
		if hg.BloodTakenOver == TakenOver then hg.BloodTakenOver = nil end
	end
	for name, r in pairs(CP.recv or {}) do
		if net.Receivers and net.Receivers[name] == r.wrap then net.Receive(name, r.orig) end
	end
	hook.Remove("PreRender", "ABL_CompatDrain")
	hook.Remove("PostDrawTranslucentRenderables", "ABL_CompatWitness")
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

local REWRAP_MAX = 8
local function InPlace()
	if not istable(hg) then return true end
	if hg.BloodLandRedirect ~= LandRedirect or hg.BloodPartRedirect ~= PartRedirect or hg.BloodCloudRedirect ~= CloudRedirect or hg.BloodTakenOver ~= TakenOver then return false end
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
if IsValid(LocalPlayer()) then timer.Simple(0, Install) end

local function State(present, ok, what)
	if not present then return "not in this Z-City" end
	if not ok then return "NOT TAKEN OVER (Z-City's own is running)" end
	if not Takeover() then return "passed through (takeover off)" end
	return what
end

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
	Path("wound drips and arterial jets (think)", true, hg.BloodTakenOver == TakenOver, "skipped, AdvancedBlood bleeds them")
	Path("gore particles landing on floors", isfunction(hg.addBloodPart), hg.BloodLandRedirect == LandRedirect, string.format("into AdvancedBlood stains and pools, %d", stat.landed))
	P("  over the per-frame budget, dropped: %d", stat.drained)
	local cur = net.Receivers and net.Receivers["bloodsquirt2"]
	local r = CP.recv["bloodsquirt2"]
	Path("net bloodsquirt2 (blood coughed up)", isfunction(cur), r ~= nil and r.wrap == cur, string.format("as AdvancedBlood drops, %d", stat.coughs))
	if stat.rewraps > 0 then P("  put back in place %d time(s)%s", stat.rewraps, stat.rewraps >= REWRAP_MAX and " - GIVEN UP, something keeps undoing it" or "") end
	P("Z-City gore particles (impacts, fountains, gibs, clouds): RUNNING")
	P("  Z-City particles on screen: %d particle-frames; their decals: %d%s",
		stat.leakDrawn, stat.leakDecals, stat.lastLeak and string.format(" (last %.0f s ago)", RealTime() - stat.lastLeak) or "")
	P("  seen in all, takeover on or off: %d particle-frames, %d decals; in the lists now: %d", stat.zDrawn, stat.zDecals, (t1 and #t1 or 0) + (t2 and #t2 or 0))
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
	P("Duplicate wound bleeding: %d%s", on and open or 1, on and "" or " (the takeover is off: Z-City's wound blood runs next to AdvancedBlood's)")
	return out, on and open or 1
end

net.Receive(N.ZCS, function()
	local present, sup = net.ReadBool(), net.ReadBool()
	local rh = net.ReadUInt(2)
	local hits = net.ReadUInt(24)
	local orgs = net.ReadUInt(8)
	print(string.format("Server: Z-City %s; canned hit decals are %s", present and "detected" or "NOT detected",
		sup and "SUPPRESSED" or "KEPT (abl_zcity_hitdecals 1, abl_enabled 0 or no Z-City)"))
	if present then
		print(string.format("  decals behind every bullet hit (hook)            %s, %d left out", rh == 2 and "wrapped" or (rh == 1 and "NOT WRAPPED" or "not in this Z-City"), hits))
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
