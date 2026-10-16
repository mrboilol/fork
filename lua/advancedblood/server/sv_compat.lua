-- Z-City compatibility, server side. (The client side is client/cl_compat.lua; every Z-City lookup
-- goes through sh_zcity.lua; the whole of it is described in docs/ZCITY_INTEGRATION.md.)
--
-- Nothing in this file touches Z-City's physiology: damage, the organism, wounds, blood volume,
-- clotting, pain and death run as Z-City runs them. What it deals with is the blood Z-City's
-- server code puts on the world by itself, next to the blood AdvancedBlood shows for the same
-- injury:
--
--   hook PostEntityTakeDamage / "ResponsiveHits_PostEntityTakeDamage" (homigrad/sv_util.lua):
--      an engine blood decal behind and another below every bullet hit;

local C, N, Z = ABL.Config, ABL.Net, ABL.ZC

ABL.CompatSV = ABL.CompatSV or {}
local SV = ABL.CompatSV
SV.stat = SV.stat or { hits = 0 }
local stat = SV.stat

if SV.wrapDecal and util.Decal == SV.wrapDecal then util.Decal = SV.origDecal end
if SV.wrapEffect and util.Effect == SV.wrapEffect then util.Effect = SV.origEffect end
SV.wrapDecal, SV.wrapEffect = nil, nil

local function Suppressing()
	return ABL.Enabled() and not C.sv.hitDecals:GetBool() and Z.Present()
end
SV.Suppressing = Suppressing

------------------------------------------------------------------------------------------
-- Z-City's canned hit decals: on every bullet hit it stamps an engine blood decal on whatever
-- lies 25 to 200 units behind the victim and another on the floor under that point, whatever the
-- bullet did. With ABL the blood that leaves a body is thrown, flies and lands where it lands (and
-- none is thrown forward without an exit), so for bodies ABL bleeds for the pair is left out. The
-- original also switches the engine's own bleeding off for the body it is called for; that part
-- is kept.
------------------------------------------------------------------------------------------
local REWRAP_MAX = 8
SV.hookWraps = 0
local function WrapResponsiveHits()
	local set = hook.GetTable().PostEntityTakeDamage
	local orig = set and set["ResponsiveHits_PostEntityTakeDamage"]
	if not isfunction(orig) or ABL.wrapResponsiveHits == orig then return end
	-- (something that keeps putting its own function there is left alone after a few times:
	-- abl_zcity_status shows the hook as not wrapped then)
	if SV.hookWraps >= REWRAP_MAX then return end
	SV.hookWraps = SV.hookWraps + 1
	ABL.origResponsiveHits = orig
	local function wrapped(ent, dmg, ...)
		if C.sv.hitDecals:GetBool() or not ABL.Enabled() or not IsValid(ent) or not istable(ent.organism) then
			return orig(ent, dmg, ...)
		end
		if (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) and ent:GetBloodColor() ~= DONT_BLEED then
			ent.bloodColorHitFix = ent:GetBloodColor()
			ent:SetBloodColor(DONT_BLEED)
		end
		stat.hits = stat.hits + 1
	end
	ABL.wrapResponsiveHits = wrapped
	hook.Add("PostEntityTakeDamage", "ResponsiveHits_PostEntityTakeDamage", wrapped)
end

local function Install()
	if not Z.Present() then return false end
	WrapResponsiveHits()
	if not SV.told then
		SV.told = true
		ABL.Print("Z-City found: its canned hit decals are %s", Suppressing() and "left to AdvancedBlood" or "kept (abl_zcity_hitdecals 1 or abl_enabled 0)")
	end
	return true
end
SV.Install = Install

-- Install returns a status for direct callers. Never return that status from a
-- lifecycle hook: either true OR false stops Garry's Mod's hook dispatch and can
-- skip Z-City's map-point, spawn, RTV and round-related initialization.
hook.Add("InitPostEntity", "ABL_CompatSV", function()
	Install()
end)
hook.Add("HomigradRun", "ABL_CompatSV", function() timer.Simple(0, Install) end)
timer.Simple(0, Install)
-- (Z-City loaded again puts its own hit-decal hook back: looked at now and then)
timer.Create("ABL_CompatSVWatch", 10, 0, function()
	if Z.Present() then WrapResponsiveHits() end
end)

------------------------------------------------------------------------------------------
-- abl_zcity_status: the server's part of the answer (asked for by the client command, at most
-- once a second per player).
------------------------------------------------------------------------------------------
net.Receive(N.ZCS, function(_, ply)
	if not IsValid(ply) then return end
	local now = CurTime()
	if (ply.ABL_zcsNext or 0) > now then return end
	ply.ABL_zcsNext = now + 1
	local set = hook.GetTable().PostEntityTakeDamage
	local rh = set and set["ResponsiveHits_PostEntityTakeDamage"]
	local orgs = 0
	for _, p in ipairs(player.GetAll()) do
		if istable(p.organism) then orgs = orgs + 1 end
	end
	local org = istable(ply.organism) and ply.organism or nil
	net.Start(N.ZCS)
	net.WriteBool(Z.Present())
	net.WriteBool(Suppressing())
	-- 0 = Z-City has no such hook, 1 = it is there and not wrapped, 2 = wrapped
	net.WriteUInt(not isfunction(rh) and 0 or (rh == ABL.wrapResponsiveHits and 2 or 1), 2)
	net.WriteUInt(math.min(stat.hits, 16777215), 24)
	net.WriteUInt(math.min(orgs, 255), 8)
	net.WriteBool(org ~= nil)
	if org then
		net.WriteFloat(tonumber(org.blood) or 0)
		net.WriteFloat(tonumber(org.bleed) or 0)
		net.WriteFloat(tonumber(org.pulse) or 0)
		net.WriteUInt(math.min(istable(org.wounds) and #org.wounds or 0, 255), 8)
		net.WriteUInt(math.min(istable(org.arterialwounds) and #org.arterialwounds or 0, 255), 8)
	end
	net.Send(ply)
end)
