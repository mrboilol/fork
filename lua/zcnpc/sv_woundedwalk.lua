--[[
	Wounded Walk bridge.

	Wounded Walk 2.0 slows NPCs from engine Health / MaxHealth (Think +
	EntityTakeDamage in nai_wound_all.lua). Z-City NPCs keep a full bar while
	the organism is the real injury, so WW almost never fires — or fires on the
	wrong number.

	We do not edit that addon. While it is present, organism NPCs expose a
	virtual Health() derived from legs / bleed / blood / pain, which WW already
	knows how to read. Our own SetPlaybackRate limp steps aside so the two
	slowdowns do not stack (see ZCNPC.WoundedWalkOwnsMove).
]]

local cfg = ZCNPC.Config

local ENTITY = FindMetaTable("Entity")
local BLOOD_FULL = 5000

local function InstallHealthMirror()
	if ZCNPC.__ww_health_installed then return end
	ZCNPC.__ww_health_installed = true

	if not isfunction(ZCNPC.__real_health) then
		ZCNPC.__real_health = ENTITY.Health
	end

	if not isfunction(ZCNPC.__real_maxhealth) then
		ZCNPC.__real_maxhealth = ENTITY.GetMaxHealth
	end

	local realH = ZCNPC.__real_health
	local realM = ZCNPC.__real_maxhealth

	function ENTITY:Health()
		local virt = self.zcnpc_ww_health
		if virt ~= nil then return virt end

		return realH(self)
	end

	function ENTITY:GetMaxHealth()
		local virt = self.zcnpc_ww_maxhealth
		if virt ~= nil then return virt end

		return realM(self)
	end
end

-- Held rather than looked up. Both questions below are asked on every "Org Think" -
-- this file's own hook and the limp in sv_status.lua - so answering them by name was
-- hashing a string into the convar table twice per NPC per tick, on the hottest hook
-- in the addon and for an addon most servers do not have. Same reasoning
-- ZCNPC.Enabled() is cached for (sv_config.lua:98).
--
-- Once found it stays found: nothing takes a convar back out of that table. Until
-- then it is looked for on a one second timer instead, because Wounded Walk either
-- loaded with the map or is not there - and the case that is neither is somebody
-- mounting it mid-session, which a second covers well enough.
local wwMove = nil

local function FindWW()
	if wwMove ~= nil then return wwMove end
	if not ConVarExists("nai_npc_movement_enabled") then return nil end

	wwMove = GetConVar("nai_npc_movement_enabled")
	if wwMove == nil then return nil end

	-- Arming it here rather than from the think is the other half of the same
	-- saving: the guard that made re-installing free still cost a table read every
	-- NPC every tick, and there is exactly one moment it needs to happen.
	InstallHealthMirror()
	timer.Remove("zcnpc_woundedwalk_probe")
	ZCNPC.Debug("Wounded Walk bridge armed")

	return wwMove
end

function ZCNPC.WoundedWalkPresent()
	return wwMove ~= nil
end

-- True when WW should be the one scaling NPC move velocity. Presence first: it is
-- the question that says no on every server without the addon, and it is now a nil
-- test rather than two calls into the engine.
local cachedWW = true

local function RefreshWW()
	cachedWW = cfg.woundedwalk ~= nil and cfg.woundedwalk:GetBool() or false
end

pcall(cvars.AddChangeCallback, "zcnpc_woundedwalk", RefreshWW, "zcnpc_ww_cache")
RefreshWW()

function ZCNPC.WoundedWalkOwnsMove()
	if wwMove == nil then return false end
	if not (ZCNPC.Enabled() and cachedWW) then
		return false
	end

	return wwMove:GetBool()
end

local function ClearVirt(npc)
	if not IsValid(npc) then return end

	npc.zcnpc_ww_health = nil
	npc.zcnpc_ww_maxhealth = nil
end

-- 0 = fine, 1 = wrecked. Tuned so WW's default 30% HP threshold starts biting
-- once a leg is meaningfully hurt or blood is going, not only at death's door.
local function Hurt01(org)
	local threshold = cfg.limb_threshold:GetFloat()
	if threshold <= 0 then threshold = 0.45 end

	local lleg = org.lleg or 0
	local rleg = org.rleg or 0
	local legsBroken = 0

	if org.llegamputated or org.llegdislocation or lleg >= threshold then legsBroken = legsBroken + 1 end
	if org.rlegamputated or org.rlegdislocation or rleg >= threshold then legsBroken = legsBroken + 1 end

	local legScore = 0
	if legsBroken >= 2 then
		legScore = 1
	elseif legsBroken == 1 then
		legScore = 0.7
	else
		legScore = math.Clamp(math.max(lleg, rleg) / threshold, 0, 1) * 0.5
	end

	local bleed = math.Clamp((org.bleed or 0) / 35, 0, 1) * 0.4
	local bloodLoss = math.Clamp(1 - ((org.blood or BLOOD_FULL) / BLOOD_FULL), 0, 1) * 0.55
	local pain = math.Clamp((org.pain or 0) / 60, 0, 1) * 0.25
	local shock = math.Clamp((org.shock or 0) / 40, 0, 1) * 0.2

	return math.Clamp(math.max(legScore, bloodLoss) + bleed * 0.5 + pain * 0.35 + shock * 0.25, 0, 1)
end

local function Mirror(npc, org)
	if org.alive == false then
		ClearVirt(npc)

		return
	end

	-- Keep a stable denominator so WW's % threshold means the same on every class.
	npc.zcnpc_ww_maxhealth = 100

	local hurt = Hurt01(org)
	-- Never report 0 while the organism is alive — WW and HL2 both treat that as dead.
	npc.zcnpc_ww_health = math.max(1, math.floor(100 * (1 - hurt * 0.92)))
end

function ZCNPC.InstallWoundedWalk()
	if FindWW() then return end

	-- Not there yet, which is either not there at all or loaded after us. The timer
	-- takes itself out the moment it finds one.
	timer.Create("zcnpc_woundedwalk_probe", 1, 0, FindWW)
end

hook.Add("Org Think", "zcnpc_woundedwalk", function(owner, org)
	-- Nothing to bridge to, which is most servers: one nil test, ahead of the two
	-- convars and the validity checks that used to be read first.
	if wwMove == nil then return end

	if not (ZCNPC.Enabled() and cachedWW) then
		if IsValid(owner) then ClearVirt(owner) end

		return
	end

	if not (IsValid(owner) and owner:IsNPC()) then return end
	if not (istable(org) and org.fakePlayer) then return end

	-- Hidden NPC under a ragdoll is not walking; leave real Health alone. Only the
	-- tick a knockdown lands in ever gets here - see the ZCNPC_Downed hook below -
	-- so this is the belt to its braces rather than the way out it looks like.
	if IsValid(owner.zcnpc_rag) then
		ClearVirt(owner)

		return
	end

	Mirror(owner, org)
end)

-- The override has to come off the moment the NPC stops walking, and going down is
-- the one way out the hook above cannot see: the organism moves onto the body
-- (ZCNPC.MoveOrganism), so hg.organism.list stops naming the NPC and "Org Think" is
-- called with the ragdoll from then on. Every line up there that asks owner:IsNPC()
-- goes quiet for this NPC, the clause that was meant to clear the override included.
--
-- Leaving it on is what made healed NPCs unkillable. Mirror never reports less than
-- 1 - nothing alive is allowed to read as dead - so a husk that fell with the
-- override still on it answers Health() with a live number for the rest of the round,
-- through a wake-up and everything after it. Anything that decides "this one is
-- finished" by asking Health() (sv_medical.lua, Wounded Walk's own damage hook, the
-- HL2 AI) is told no, every time, whatever has just been done to it.
hook.Add("ZCNPC_Downed", "zcnpc_woundedwalk", function(npc)
	ClearVirt(npc)
end)

-- Standing back up is the other half of it. Mirror puts the override back on the next
-- organism tick if the body still needs slowing down, and the gap between the two is
-- a tick of honest engine health rather than a stale number from before the fall.
hook.Add("ZCNPC_WokeUp", "zcnpc_woundedwalk", function(npc)
	ClearVirt(npc)
end)

hook.Add("EntityRemoved", "zcnpc_woundedwalk", function(ent)
	if IsValid(ent) then ClearVirt(ent) end
end)
