--[[
	Which weapons are allowed to take pieces off an NPC.

	Pistols and SMGs can still kill; with zcnpc_gib_heavy_only they just do not
	amputate limbs or blow heads off. Shotguns, carbines and sniper rifles still
	gib, and so do explosions, falls and crush. Category strings match Z-City's
	SWEP.Category names ("Weapons - Shotguns", "Weapons - Carbines",
	"Weapons - Sniper Rifles").

	Limb gib threshold: Z-City amputates at dmgstack > 100 and multiplies that
	stack by 3 for NPCs (sv_input.lua:937), so limbs came off after a few rounds.
	We accumulate the raw stack ourselves (Z-City wipes it every attempt) and only
	let AmputateLimb through once zcnpc_gib_threshold is reached.
]]

local cfg = ZCNPC.Config

local HEAVY_CAT = {
	["Weapons - Shotguns"] = true,
	["Weapons - Carbines"] = true,
	["Weapons - Sniper Rifles"] = true,
}

local HEAVY_CLASS = {
	weapon_shotgun = true,
	weapon_crossbow = true,
}

-- Blast / fall / crush / vehicles - checked before any held SWEP, so landing with
-- a pistol out still gibs. Covers Z-City's DMG_FALL fall damage and bone-crush
-- amputations during the same hit (sv_bone.lua).
local ENV_GIB = DMG_BLAST + DMG_CRUSH + DMG_FALL + DMG_VEHICLE

local GIB_WINDOW = 1.25 -- covers Z-City's 1s dmgstack timer (sv_input.lua:953)

local LIMB_HITGROUP = {
	lleg = HITGROUP_LEFTLEG,
	rleg = HITGROUP_RIGHTLEG,
	larm = HITGROUP_LEFTARM,
	rarm = HITGROUP_RIGHTARM,
}

local HITGROUP_LIMB = {
	[HITGROUP_LEFTLEG] = true,
	[HITGROUP_RIGHTLEG] = true,
	[HITGROUP_LEFTARM] = true,
	[HITGROUP_RIGHTARM] = true,
	[HITGROUP_HEAD] = true,
}

local function WeaponFromDamage(dmgInfo)
	if not dmgInfo then return end

	local inf = dmgInfo:GetInflictor()
	if IsValid(inf) and inf:IsWeapon() then return inf end

	local att = dmgInfo:GetAttacker()
	if IsValid(att) and att.GetActiveWeapon then
		local wep = att:GetActiveWeapon()
		if IsValid(wep) then return wep end
	end

	if IsValid(inf) and inf.GetOwner then
		local owner = inf:GetOwner()
		if IsValid(owner) and owner.GetActiveWeapon then
			local wep = owner:GetActiveWeapon()
			if IsValid(wep) then return wep end
		end
	end
end

-- true = this hit may take a limb or head off an NPC
function ZCNPC.WeaponCanGib(dmgInfo)
	if not cfg.gib_heavy_only:GetBool() then return true end
	if not dmgInfo then return true end

	-- Explosions, falls, crush, vehicles - before looking at a held gun.
	if dmgInfo:IsDamageType(ENV_GIB) then return true end
	if dmgInfo:IsDamageType(DMG_BUCKSHOT) then return true end
	if dmgInfo:IsDamageType(DMG_SNIPER) then return true end

	local wep = WeaponFromDamage(dmgInfo)
	if not IsValid(wep) then
		-- No weapon on the hit (world, tool, scripted) - do not block admin /
		-- environmental gibs that never went through a SWEP.
		return not dmgInfo:IsDamageType(DMG_BULLET)
	end

	local cat = wep.Category
	if isstring(cat) and HEAVY_CAT[cat] then return true end

	local class = wep:GetClass()
	if HEAVY_CLASS[class] then return true end

	if isstring(cat) then
		if string.find(cat, "Shotgun", 1, true) then return true end
		if string.find(cat, "Carbine", 1, true) then return true end
		if string.find(cat, "Sniper", 1, true) then return true end
	end

	return false
end

function ZCNPC.MarkGibWeapon(ent, dmgInfo)
	if not IsValid(ent) then return end

	local org = ent.organism or (IsValid(ent.zcnpc_rag) and ent.zcnpc_rag.organism)
		or (IsValid(ent.zcnpc_npc) and ent.zcnpc_npc.organism)
	if not org then return end

	if ZCNPC.WeaponCanGib(dmgInfo) then
		org.zcnpc_heavy_gib = CurTime() + GIB_WINDOW
		ent.zcnpc_heavy_gib = org.zcnpc_heavy_gib

		if dmgInfo:IsDamageType(ENV_GIB) then
			org.zcnpc_env_gib = CurTime() + GIB_WINDOW
		end

		local other = ent.zcnpc_rag or ent.zcnpc_npc
		if IsValid(other) then other.zcnpc_heavy_gib = org.zcnpc_heavy_gib end
	end
end

function ZCNPC.GibWeaponAllowed(ent, org)
	if not cfg.gib_heavy_only:GetBool() then return true end

	org = org or (IsValid(ent) and ent.organism)
	local untilTime = (org and org.zcnpc_heavy_gib)
		or (IsValid(ent) and ent.zcnpc_heavy_gib)
		or 0

	return untilTime >= CurTime()
end

-- Force the next AmputateLimb / head gib check through (C-menu admin tools).
function ZCNPC.AllowNextGib(org, ent)
	local untilTime = CurTime() + GIB_WINDOW

	if org then
		org.zcnpc_heavy_gib = untilTime
		org.zcnpc_env_gib = untilTime
		org.zcnpc_force_gib = true
	end
	if IsValid(ent) then ent.zcnpc_heavy_gib = untilTime end
end

local function IsNpcVictim(victim)
	if not IsValid(victim) then return false end
	if victim:IsNPC() then return true end
	if victim.zcnpc_npcbody and victim:IsRagdoll() then return true end
	if victim:IsRagdoll() and ZCNPC.Downed and ZCNPC.Downed[victim] then return true end

	return false
end

-- Z-City wipes dmgstack after every amputation attempt, so we keep a running
-- total of how much raw stack this limb/head has actually taken.
local function AccrueGibStack(org, hitgroup)
	if not (org and hitgroup and HITGROUP_LIMB[hitgroup]) then return end

	local slot = org.dmgstack and org.dmgstack[hitgroup]
	local now = slot and slot[1]
	org.zcnpc_lacc = org.zcnpc_lacc or {}
	org.zcnpc_llast = org.zcnpc_llast or {}

	if not now then
		org.zcnpc_llast[hitgroup] = 0
		return
	end

	local last = org.zcnpc_llast[hitgroup] or 0
	if now > last then
		org.zcnpc_lacc[hitgroup] = (org.zcnpc_lacc[hitgroup] or 0) + (now - last)
	end

	org.zcnpc_llast[hitgroup] = now
end

local function LimbStack(org, limb)
	local hitgroup = LIMB_HITGROUP[limb]
	if not hitgroup then return 0 end

	return (org.zcnpc_lacc and org.zcnpc_lacc[hitgroup]) or 0
end

-- PreHomigradDamage: mark heavy weapons before bone crush AmputateLimb (sv_bone.lua).
-- HomigradDamage: accrue stack after Z-City writes dmgstack. Split so each half of
-- the work runs once per hit instead of twice.
hook.Add("PreHomigradDamage", "zcnpc_gib_weapon", function(victim, dmgInfo)
	if not (ZCNPC.Enabled() and cfg.gib_heavy_only:GetBool()) then return end
	if not IsNpcVictim(victim) then return end

	ZCNPC.MarkGibWeapon(victim, dmgInfo)
end)

hook.Add("HomigradDamage", "zcnpc_gib_weapon", function(victim, dmgInfo, hitgroup)
	if not ZCNPC.Enabled() then return end
	if not IsNpcVictim(victim) then return end
	if not (hitgroup and HITGROUP_LIMB[hitgroup]) then return end

	-- One accrue per victim+hitgroup per tick (buckshot was scheduling eight).
	local stamp = victim.zcnpc_gib_acc_stamp
	if stamp and stamp.t == CurTime() and stamp.hg == hitgroup then return end
	victim.zcnpc_gib_acc_stamp = { t = CurTime(), hg = hitgroup }

	timer.Simple(0, function()
		if not IsValid(victim) then return end
		local org = victim.organism
			or (IsValid(victim.zcnpc_rag) and victim.zcnpc_rag.organism)
			or (IsValid(victim.zcnpc_npc) and victim.zcnpc_npc.organism)
		AccrueGibStack(org, hitgroup)
	end)
end)

--\\ Block light-weapon / under-threshold limb amputation on NPCs
local function InstallAmputateWrap()
	if not isfunction(hg.organism.AmputateLimb) then return end
	if ZCNPC.__origAmputateLimb then return end

	ZCNPC.__origAmputateLimb = hg.organism.AmputateLimb

	function hg.organism.AmputateLimb(org, limb)
		local owner = org and org.owner
		local isNpc = IsValid(owner) and (
			owner:IsNPC()
			or owner.zcnpc_npcbody
			or (ZCNPC.Downed and ZCNPC.Downed[owner])
			or IsValid(owner.zcnpc_npc)
		)

		if isNpc then
			if org.zcnpc_force_gib then
				org.zcnpc_force_gib = nil
			else
				if cfg.gib_heavy_only:GetBool() and not ZCNPC.GibWeaponAllowed(owner, org) then
					ZCNPC.Debug("amputation blocked (light weapon):", limb, "on", owner)
					return
				end

				local hitgroup = LIMB_HITGROUP[limb]
				if hitgroup then
					AccrueGibStack(org, hitgroup)
				end

				local acc = LimbStack(org, limb)
				local threshold = cfg.gib_threshold:GetFloat()
				local envOk = (org.zcnpc_env_gib or 0) >= CurTime()

				-- Fall / crush / blast bone snaps may fire with no bullet stack yet.
				-- Those stay allowed. Bullet/dmgstack amputations need the threshold.
				if acc < threshold and not (envOk and acc <= 0) then
					ZCNPC.Debug("amputation blocked (threshold):", limb, acc, "/", threshold, "on", owner)
					return
				end
			end

			-- Spent for this limb so a follow-up tick does not re-fire on leftovers.
			local hitgroup = LIMB_HITGROUP[limb]
			if hitgroup and org.zcnpc_lacc then
				org.zcnpc_lacc[hitgroup] = nil
				if org.zcnpc_llast then org.zcnpc_llast[hitgroup] = nil end
			end
		end

		-- AmputateLimb always SpawnMeatGores at scale 1. Arms and legs need
		-- a bigger chunk than a headshot pebble; head gore is a different call.
		local meat
		if isNpc and isfunction(SpawnMeatGore) then
			meat = SpawnMeatGore
			function SpawnMeatGore(mainent, pos, count, force, scale)
				return meat(mainent, pos, count, force, (scale or 1) * 1.75)
			end
		end

		local ok, a, b, c = pcall(ZCNPC.__origAmputateLimb, org, limb)
		if meat then SpawnMeatGore = meat end
		if not ok then error(a) end

		return a, b, c
	end
end

InstallAmputateWrap()
hook.Add("HomigradRun", "zcnpc_gib_amputate", InstallAmputateWrap)
--//
