--[[
	ReaSFX.

	ReaSFX is the voice ReAgdoll puts on a body: the scream somebody makes on the
	way down, the crack of a bone going, the radio call that comes off a dead
	Combine a moment later. It is not a system of its own - it registers a handful
	of functions on the global RSFX table and ReAgdoll calls them from its own
	death pipeline.

	Which is the whole problem, because our bodies never go through that pipeline.
	An NPC this addon knocks down is not an NPC dying; it is a live entity being
	hidden and a ragdoll being built to stand in for it, and sv_reagdoll.lua marks
	that ragdoll SPECIAL precisely so ReAgdoll's death handling keeps its hands
	off a man who is going to get back up. The cost of that, until now, was that
	the one who did not get back up died in silence: no scream, no crack, no radio.

	So the four moments that deserve a sound are handed to the pack directly.
	A body that bleeds out on the floor screams the way one that was shot on its
	feet does. A limb coming off cracks. A skull that has been opened cracks
	differently. And the loop is cut short - silently - if the body sits up, since
	a man walking away should not be trailing his own death rattle.

	The pack's own switches are honoured: reagdoll_sfx, reagdoll_sfx_npcs, and the
	per-category ones. Turning ReaSFX off in ReAgdoll's menu turns this off too,
	because it is the same sounds.
]]

local cfg = ZCNPC.Config

local function Enabled()
	if not ZCNPC.Enabled() then return false end
	if cfg.reasfx and not cfg.reasfx:GetBool() then return false end

	return istable(RSFX) and next(RSFX) ~= nil
end

--\\ Which pack, and whether ReAgdoll wants it heard at all
-- ReAgdoll lets a server pick between installed packs by index into the sorted
-- key list, or roll one per reaction. Both are read rather than guessed at,
-- because a server running two packs picked one on purpose.
local function CVar(name)
	local cvar = GetConVar(name)

	return cvar and cvar:GetBool()
end

local function Pack()
	local names = {}

	for name in pairs(RSFX) do
		if istable(RSFX[name]) then names[#names + 1] = name end
	end

	if #names == 0 then return end

	table.sort(names)

	if CVar("reagdoll_sfx_randompack") then return RSFX[names[math.random(#names)]] end

	if isstring(RD_RSFXAddonName) and istable(RSFX[RD_RSFXAddonName]) then
		return RSFX[RD_RSFXAddonName]
	end

	local index = GetConVar("reagdoll_sfx_selected")
	index = index and index:GetInt() or 1

	return RSFX[names[math.Clamp(index, 1, #names)]]
end

-- ReAgdoll's own master switches. Absent convars mean ReAgdoll is not installed,
-- and a sound pack with nothing to hang off is one nobody asked to hear.
local function Allowed(category)
	if not GetConVar("reagdoll_sfx") then return false end
	if not CVar("reagdoll_sfx") then return false end
	if not CVar("reagdoll_sfx_npcs") then return false end

	return category == nil or CVar(category)
end
--//

--\\ What killed it
-- ReaSFX has five death voices and the difference between them is what the last
-- thing to happen was. Nothing in ZCNPC_Died carries that, so it is remembered as
-- it happens: one field per body, overwritten by every hit, read once at the end.
local BURN = bit.bor(DMG_BURN, DMG_SLOWBURN, DMG_DIRECT)
local BLAST = bit.bor(DMG_BLAST, DMG_BLAST_SURFACE)
local BULLET = bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER)
local FLY_SPEED = 500

local function Remember(rag, dmgInfo)
	local kind = "blunt"

	if dmgInfo:IsDamageType(BURN) then
		kind = "burn"
	elseif dmgInfo:IsDamageType(BLAST) then
		kind = "explode"
	elseif dmgInfo:IsDamageType(BULLET) then
		kind = "bullet"
	end

	rag.zcnpc_sfxkind = kind
end

hook.Add("EntityTakeDamage", "zcnpc_reasfx", function(ent, dmgInfo)
	if not Enabled() then return end
	if not (IsValid(ent) and ent:IsRagdoll()) then return end
	if not (ZCNPC.Ragdolls and ZCNPC.Ragdolls[ent]) then return end

	Remember(ent, dmgInfo)
end)

-- A body still travelling when it dies gets the falling scream instead, which is
-- the same call ReAgdoll makes for one thrown off a roof.
local function Flying(rag)
	local phys = rag:GetPhysicsObject()
	if not IsValid(phys) then return false end

	return phys:GetVelocity():Length() > FLY_SPEED
end

local CATEGORY = {
	bullet = { fn = "Bullet", cvar = "reagdoll_sfx_bullets" },
	blunt = { fn = "Blunt", cvar = "reagdoll_sfx_blunt" },
	explode = { fn = "Explode", cvar = "reagdoll_sfx_explosions" },
	burn = { fn = "Burn", cvar = "reagdoll_sfx_fire" },
	fly = { fn = "Fly", cvar = "reagdoll_sfx_fly" },
}

local function Play(rag, kind)
	local entry = CATEGORY[kind]
	if not entry then return false end
	if not Allowed(entry.cvar) then return false end

	local pack = Pack()
	local fn = pack and pack[entry.fn]
	if not isfunction(fn) then return false end

	local ok, err = pcall(fn, rag)
	if not ok then
		ZCNPC.Debug("ReaSFX", entry.fn, "failed:", err)

		return false
	end

	rag.zcnpc_sfxplaying = true

	return true
end
--//

--\\ The four moments
hook.Add("ZCNPC_Died", "zcnpc_reasfx", function(rag, org)
	if not Enabled() then return end
	if not IsValid(rag) then return end

	-- A skull that has been opened is a different noise from a chest that has
	-- been. ReAgdoll plays this one on top of the voice rather than instead of it.
	if istable(org) and ((org.skull or 0) >= 1 or (org.brain or 0) > 0) then
		if Allowed("reagdoll_sfx_gorehs") then
			local pack = Pack()
			if pack and isfunction(pack.GoreHeadshot) then pcall(pack.GoreHeadshot, rag) end
		end
	end

	local kind = Flying(rag) and "fly" or (rag.zcnpc_sfxkind or "blunt")

	Play(rag, kind)
end)

-- OnAmputateLimb is Z-City's own, and it fires for players as well as for us -
-- theirs are ReAgdoll's business and are left to it.
hook.Add("OnAmputateLimb", "zcnpc_reasfx", function(_, ent)
	if not Enabled() then return end
	if not IsValid(ent) then return end
	if not (ZCNPC.Ragdolls and ZCNPC.Ragdolls[ent]) then return end
	if not Allowed("reagdoll_sfx_gorebones") then return end

	local pack = Pack()
	if pack and isfunction(pack.GoreBone) then pcall(pack.GoreBone, ent) end
end)

-- Standing back up.
--
-- Remove is the pack's own way of cutting a loop short, but it does one more
-- thing on the way out: a Combine model gets its post-mortem radio call. That is
-- exactly right for a corpse and exactly wrong for somebody who just sat up, and
-- the pack decides which by a flag it sets on the body itself. So the flag is
-- raised for the length of the call and put back after - the loop stops, the
-- radio does not, and a body that dies later can still make it.
local function Hush(rag)
	if not (Enabled() and IsValid(rag)) then return end
	if not rag.zcnpc_sfxplaying then return end

	local pack = Pack()
	if not (pack and isfunction(pack.Remove)) then return end

	local played = rag.REAplayed
	rag.REAplayed = true

	pcall(pack.Remove, rag, true)

	rag.REAplayed = played
	rag.zcnpc_sfxplaying = nil
end

hook.Add("ZCNPC_WokeUp", "zcnpc_reasfx", function(_, _, rag)
	Hush(rag)
end)

hook.Add("ZCNPC_GetUp", "zcnpc_reasfx", function(_, rag)
	Hush(rag)
end)
--//
