--[[
	Headcrab latch for NPCs.

	Z-City only ever does this to players (sv_input.lua:1098): a headcrab hit
	knocks a droppable helmet/mask off, or latches on, knocks them out, and eats
	until the host turns into a headcrabzombie. NPCs never hit that branch
	because the check is gated on `ply`.

	This file is the same fantasy for bodies we manage. Players, Z-City itself
	and Artagdoll are left alone. At the end of the meal the NPC dies as
	"Body with headcrab" and the crab climbs off to hunt again - there is no
	player-class transform to hand an NPC.
]]

local cfg = ZCNPC.Config

local HEADCRABS = {
	["npc_headcrab"] = true,
	["npc_headcrab_fast"] = true,
	["npc_headcrab_black"] = true,
}

local HEADCRAB_MODELS = {
	["npc_headcrab"] = "models/nova/w_headcrab.mdl",
	["npc_headcrab_fast"] = "models/headcrab.mdl",
	["npc_headcrab_black"] = "models/headcrabblack.mdl",
}

local MODEL_TO_CLASS = {
	["models/nova/w_headcrab.mdl"] = "npc_headcrab",
	["models/headcrab.mdl"] = "npc_headcrab_fast",
	["models/headcrabblack.mdl"] = "npc_headcrab_black",
}

local HEAD_BONE = "ValveBiped.Bip01_Head1"
local BODY_NAME = "Body with headcrab"
local STAGGER_TIME = 1.5
local BULLET = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER

-- Nodrop helmets that take several leaps. Hits are counted; the crab only
-- latches when the count reaches `latch`. `stagger` is the hit that floors them
-- for a couple of seconds without the crab sticking.
--
-- Metrocop: 1st bounce + ragdoll, 2nd latch.
-- Combine: 1st bounce, 2nd bounce + ragdoll, 3rd latch.
local HELMET_RULES = {
	["npc_metropolice"] = { latch = 2, stagger = 1 },
	["npc_combine_s"] = { latch = 3, stagger = 2 },
	["metrocop_helmet"] = { latch = 2, stagger = 1 },
	["cmb_helmet"] = { latch = 3, stagger = 2 },
}

local cachedHeadcrab = true

local function RefreshHeadcrab()
	cachedHeadcrab = cfg.headcrab ~= nil and cfg.headcrab:GetBool() or false
end

pcall(cvars.AddChangeCallback, "zcnpc_headcrab", RefreshHeadcrab, "zcnpc_headcrab_cache")
RefreshHeadcrab()

local function HeadcrabEnabled()
	return ZCNPC.Enabled() and cachedHeadcrab
end

--\\ Who may be latched onto
-- Standing managed NPCs, native Z-City organism NPCs, and the ragdoll half of a
-- body we already put on the floor. Zombies and the crabs themselves are out.
local function HostFrom(ent)
	if not IsValid(ent) then return end

	if ent:IsNPC() then
		if ZCNPC.IsZombie(ent) then return end
		if HEADCRABS[ent:GetClass()] then return end
		if not ent.organism then return end
		if IsValid(ent.zcnpc_rag) then return ent.zcnpc_rag end -- hits land on the body

		return ent
	end

	if ent:IsRagdoll() and (ent.zcnpc_npcbody or ZCNPC.Downed[ent] or ent.zcnpc_corpse) then
		return ent
	end
end

local function AlreadyLatched(host)
	if not IsValid(host) then return true end
	if host:GetNetVar("headcrab") then return true end

	local org = host.organism
	if org and org.headcrabon then return true end

	local npc = host.zcnpc_npc
	if IsValid(npc) and npc:GetNetVar("headcrab") then return true end

	return false
end

local function HostArmors(host)
	local armors = host.armors
	if istable(armors) then return armors end

	return host.GetNetVar and host:GetNetVar("Armor", {}) or {}
end

local function HostClass(host)
	if host:IsNPC() then return host:GetClass() end

	local npc = host.zcnpc_npc
	if IsValid(npc) then return npc:GetClass() end

	local info = ZCNPC.Downed[host]
	if info then return info.class end
end

local function Droppable(slot, piece)
	if not piece then return false end
	if not (hg.armor and hg.armor[slot] and hg.armor[slot][piece]) then return false end

	return not hg.armor[slot][piece].nodrop
end

local function HelmetRules(host)
	local armors = HostArmors(host)
	local helm = istable(armors) and armors.head
	if not helm then return end
	if Droppable("head", helm) then return end -- droppable pieces are knocked off instead

	if HELMET_RULES[helm] then return HELMET_RULES[helm] end

	local class = HostClass(host)
	if class and HELMET_RULES[class] then return HELMET_RULES[class] end
end

local function HitCount(host)
	return host.zcnpc_headcrab_hits
		or (IsValid(host.zcnpc_npc) and host.zcnpc_npc.zcnpc_headcrab_hits)
		or 0
end

local function SetHitCount(host, n)
	host.zcnpc_headcrab_hits = n

	local npc = host:IsNPC() and host or host.zcnpc_npc
	if IsValid(npc) then npc.zcnpc_headcrab_hits = n end

	local rag = host:IsRagdoll() and host or (IsValid(npc) and npc.zcnpc_rag)
	if IsValid(rag) then rag.zcnpc_headcrab_hits = n end
end
--//

--\\ Armor drop (same nodrop rule Z-City uses on players)

local function TryKnockArmor(host)
	local armors = HostArmors(host)
	if not istable(armors) then return false end

	local helm = Droppable("head", armors.head) and armors.head
	local mask = Droppable("face", armors.face) and armors.face
	local piece = helm or mask
	if not piece then return false end

	if not isfunction(hg.DropArmorForce) then return false end

	local dropped = hg.DropArmorForce(host, piece)
	if IsValid(dropped) then
		local bone = host:LookupBone(HEAD_BONE)
		if bone then
			local matrix = host:GetBoneMatrix(bone)
			if matrix then dropped:SetPos(matrix:GetTranslation()) end
		end
	end

	host.ArmorCD = CurTime() + 5

	return true
end

-- Shove the living crab away so the bounce reads as a bounce, not a free hit.
local function BounceCrab(crab, host)
	if not (IsValid(crab) and IsValid(host)) then return end

	local away = (crab:GetPos() - host:WorldSpaceCenter()):GetNormalized()
	if away:LengthSqr() < 0.01 then away = -host:GetForward() end

	away.z = 0.45
	away:Normalize()

	crab:SetPos(crab:GetPos() + away * 12 + Vector(0, 0, 10))

	local phys = crab:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(away * 280 + Vector(0, 0, 160))
	else
		crab:SetVelocity(away * 280 + Vector(0, 0, 160))
	end

	host:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 3) .. ".wav", 70, math.random(95, 110))
end
--//

--\\ Latch / clear
-- mode: "release" (climb off alive), "kill" (dies on the head), nil (just clear)
local function HeadPos(ent)
	local bone = ent:LookupBone(HEAD_BONE)
	if not bone then return ent:WorldSpaceCenter(), ent:GetAngles() end

	local matrix = ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation(), matrix:GetAngles() end

	local physBone = ent:TranslateBoneToPhysBone(bone)
	local phys = physBone and physBone >= 0 and ent:GetPhysicsObjectNum(physBone)
	if IsValid(phys) then return phys:GetPos(), phys:GetAngles() end

	return ent:WorldSpaceCenter(), ent:GetAngles()
end

function ZCNPC.ClearHeadcrab(host, mode)
	if not IsValid(host) then return end

	if mode == true then mode = "release" end

	local model = host:GetNetVar("headcrab")
	local class = host.zcnpc_headcrab_class
		or (isstring(model) and MODEL_TO_CLASS[model])
		or "npc_headcrab"

	local org = host.organism
	if org then
		class = org.zcnpc_headcrab_class or class
		org.headcrabon = nil
		org.zcnpc_headcrab_class = nil
		org.noHead = false
		-- headcrabevent is left alone: the finale sets it so ZCNPC_Died
		-- knows the crab was already handled on purpose
	end

	host:SetNetVar("headcrab", false)
	host.zcnpc_headcrab_class = nil
	host.noHead = false

	local npc = host.zcnpc_npc
	if IsValid(npc) then
		npc:SetNetVar("headcrab", false)
		npc.zcnpc_headcrab_class = nil
		npc.noHead = false
	end

	if not isstring(model) or model == "" then return end

	local pos = HeadPos(host)

	if mode == "kill" then
		host:EmitSound("npc/headcrab/die" .. math.random(1, 2) .. ".wav", 75, math.random(95, 105))
		host:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 70, math.random(90, 110))

		local gib = ents.Create("prop_physics")
		if IsValid(gib) then
			gib:SetModel(model)
			gib:SetPos(pos + Vector(0, 0, 4))
			gib:SetAngles(AngleRand())
			gib:Spawn()
			gib:Activate()

			local phys = gib:GetPhysicsObject()
			if IsValid(phys) then
				phys:SetVelocity(VectorRand() * 120 + Vector(0, 0, 80))
				phys:AddAngleVelocity(VectorRand() * 400)
			end

			timer.Simple(8, function()
				if IsValid(gib) then gib:Remove() end
			end)
		end

		ZCNPC.Debug("headcrab killed on", host, class)

		return
	end

	if mode ~= "release" then return end

	local crab = ents.Create(class)
	if not IsValid(crab) then return end

	crab:SetPos(pos + Vector(0, 0, 8))
	crab:SetAngles(Angle(0, math.random(0, 360), 0))
	crab:Spawn()
	crab:Activate()

	local phys = crab:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(VectorRand() * 40 + Vector(0, 0, 80))
	end

	ZCNPC.Debug("headcrab released from", host, class)
end

function ZCNPC.HasHeadcrab(ent)
	if not IsValid(ent) then return false end
	if ent:GetNetVar("headcrab") then return true end

	local org = ent.organism
	if org and org.headcrabon then return true end

	return false
end

function ZCNPC.AddHeadcrab(host, model, class)
	if not IsValid(host) then return end

	local org = host.organism
	if not org or org.alive == false then return end

	host:SetNetVar("headcrab", model)
	host.zcnpc_headcrab_class = class
	host.noHead = true
	host:SetNWString("PlayerName", BODY_NAME)

	org.headcrabon = CurTime()
	org.headcrabevent = false
	org.zcnpc_headcrab_class = class
	org.noHead = true
	org.brain = math.max(org.brain or 0, 0.3)
	org.shock = math.max(org.shock or 0, 100)
	org.needotrub = true
	org.otrub = true

	local npc = host:IsNPC() and host or host.zcnpc_npc
	if IsValid(npc) then
		npc:SetNetVar("headcrab", model)
		npc.zcnpc_headcrab_class = class
		npc.noHead = true
		npc:SetNWString("PlayerName", BODY_NAME)
	end

	-- deferred: HomigradDamage runs inside Org Think; going down mutates the list
	timer.Simple(0, function()
		if not IsValid(host) then return end

		local standing = host:IsNPC() and host or nil
		if IsValid(standing) and not IsValid(standing.zcnpc_rag) then
			ZCNPC.MakeUnconscious(standing)
		end

		local rag = IsValid(standing) and standing.zcnpc_rag or (host:IsRagdoll() and host)
		if IsValid(rag) then
			rag:SetNetVar("headcrab", model)
			rag.zcnpc_headcrab_class = class
			rag.noHead = true
			rag:SetNWString("PlayerName", BODY_NAME)

			-- stay down for the whole meal; wake checks still refuse while latched
			local info = ZCNPC.Downed[rag]
			if info then info.wakeAfter = math.max(info.wakeAfter or 0, 70) end
		end
	end)

	ZCNPC.Debug("headcrab latched onto", host, class)
end
--//

--\\ Damage hook: helmet off / bounce / latch
hook.Add("HomigradDamage", "zcnpc_headcrab", function(victim, dmgInfo)
	if not HeadcrabEnabled() then return end
	if not IsValid(victim) or not dmgInfo then return end

	local attacker = dmgInfo:GetAttacker()
	if not (IsValid(attacker) and attacker:IsNPC()) then return end

	local class = attacker:GetClass()
	if not HEADCRABS[class] then return end

	local host = HostFrom(victim)
	if not IsValid(host) then return end
	if AlreadyLatched(host) then return end

	local org = host.organism
	if not org or org.alive == false then return end
	if host.noHead or org.headamputated then return end

	-- droppable head/face armour eats the leap once, then the crab is free to try again
	if TryKnockArmor(host) then
		ZCNPC.Debug("headcrab knocked armour off", host)
		BounceCrab(attacker, host)
		dmgInfo:SetDamage(0)
		dmgInfo:SetDamageForce(vector_origin)

		return
	end

	local rules = HelmetRules(host)
	if rules then
		local hits = HitCount(host) + 1
		SetHitCount(host, hits)

		dmgInfo:SetDamage(0)
		dmgInfo:SetDamageForce(vector_origin)

		if hits < rules.latch then
			BounceCrab(attacker, host)

			if hits == rules.stagger then
				local standing = host:IsNPC() and host or host.zcnpc_npc
				if IsValid(standing) then
					timer.Simple(0, function()
						if IsValid(standing) then ZCNPC.Floor(standing, STAGGER_TIME) end
					end)
				end

				ZCNPC.Debug("headcrab staggered", host, "hit", hits, "/", rules.latch)
			else
				ZCNPC.Debug("headcrab bounced off", host, "hit", hits, "/", rules.latch)
			end

			return
		end

		-- final leap: fall through to latch below (no bounce — crab sticks)
	end

	local model = HEADCRAB_MODELS[class]
	if not model then return end

	ZCNPC.AddHeadcrab(host, model, class)
	SetHitCount(host, 0)

	-- swallow leftover engine HP: HomigradDamage returns false for NPCs, and a
	-- leap that also kills the entity would spawn a second corpse next to ours
	dmgInfo:SetDamage(0)
	dmgInfo:SetDamageForce(vector_origin)

	-- the living crab is now the prop on the head
	if IsValid(attacker) then attacker:Remove() end
end)

-- Headshot into a body that still has a crab on it kills the crab with the host.
-- Corpse or mid-meal body: either way the crab does not climb off alive.
-- HomigradDamage is called as (victim, dmgInfo, hitgroup, ...) from sv_input.lua.
hook.Add("HomigradDamage", "zcnpc_headcrab_headshot", function(victim, dmgInfo, hitgroup)
	if not HeadcrabEnabled() then return end
	if not (IsValid(victim) and dmgInfo) then return end
	if not dmgInfo:IsDamageType(BULLET) then return end
	if not ZCNPC.HasHeadcrab(victim) then return end

	local headHit = hitgroup == HITGROUP_HEAD
		or (victim.zcnpc_headwound or 0) > CurTime()

	if not headHit then
		local bone = victim:LookupBone(HEAD_BONE)
		if bone then
			local matrix = victim:GetBoneMatrix(bone)
			local headPos = matrix and matrix:GetTranslation()
			if headPos and dmgInfo:GetDamagePosition():DistToSqr(headPos) < (16 * 16) then
				headHit = true
			end
		end
	end

	if not headHit then return end

	ZCNPC.ClearHeadcrab(victim, "kill")
end)
--//

--\\ Carry the latch across the NPC <-> body hand-off
hook.Add("ZCNPC_Downed", "zcnpc_headcrab", function(npc, rag, org)
	if not (IsValid(npc) and IsValid(rag)) then return end

	local model = npc:GetNetVar("headcrab") or (org and org.headcrabon and rag:GetNetVar("headcrab"))
	if not model and org and org.zcnpc_headcrab_class then
		model = HEADCRAB_MODELS[org.zcnpc_headcrab_class]
	end

	if not model then return end

	rag:SetNetVar("headcrab", model)
	rag.zcnpc_headcrab_class = npc.zcnpc_headcrab_class or org.zcnpc_headcrab_class
	rag.noHead = true
	rag:SetNWString("PlayerName", BODY_NAME)
end)

hook.Add("ZCNPC_WokeUp", "zcnpc_headcrab", function(npc, org, rag)
	-- should not happen while latched; if it does, keep the crab on the standing host
	if not IsValid(npc) then return end

	local model = IsValid(rag) and rag:GetNetVar("headcrab") or npc:GetNetVar("headcrab")
	if not model then return end

	npc:SetNetVar("headcrab", model)
	npc:SetNWString("PlayerName", BODY_NAME)
end)
--//

--\\ Eating, thrashing, finale
-- Timings match Z-City's player Org Think (sv_headcrab.lua): pain 20-30s,
-- thrash after 30s, kill and release at 60s.
hook.Add("Org Think", "zcnpc_headcrab", function(owner, org, _)
	if not HeadcrabEnabled() then return end
	if not (IsValid(owner) and org and org.headcrabon) then return end

	-- players stay on Z-City's own Headcrab think
	if owner:IsPlayer() then return end

	local started = org.headcrabon
	local now = CurTime()
	local host = owner

	if host:GetNWString("PlayerName", "") ~= BODY_NAME then
		host:SetNWString("PlayerName", BODY_NAME)
	end
	host.noHead = true
	org.noHead = true
	org.brain = math.max(org.brain or 0, 0.3)
	org.otrub = true
	org.needotrub = true

	-- thrash the body once the crab has been eating a while
	if (started + 30) < now and (org.brain or 0) < 1 and (org.spine3 or 0) < 1 and host:IsRagdoll() then
		local mul = ((started + 60) - now) / 60
		if mul > 0 then
			local count = host:GetPhysicsObjectCount()
			if count > 0 then
				local phys = host:GetPhysicsObjectNum(math.random(0, count - 1))
				if IsValid(phys) then
					phys:ApplyForceCenter(VectorRand() * (750 * mul))
				end
			end
		end

		if ZCNPC.WatchBody then ZCNPC.WatchBody(host, 1) end
	end

	if org.alive ~= false and (started + 20) < now and (started + 30) > now then
		if (org.zcnpc_headcrab_pain or 0) < now then
			org.zcnpc_headcrab_pain = now + 1.2
			host:EmitSound("npc/zombie/zombie_pain" .. math.random(6) .. ".wav", 80, math.random(80, 90))
			org.painadd = (org.painadd or 0) + 15
			org.shock = math.max(org.shock or 0, 40)
		end
	end

	-- meal finished: die, keep the name, crab climbs off and hunts again
	if org.alive ~= false and (started + 60) < now and not org.headcrabevent then
		org.headcrabevent = true

		host:EmitSound("npc/zombie/zombie_alert" .. math.random(3) .. ".wav", 80, math.random(60, 70))
		host:EmitSound("neck_snap_01.wav", 80, 80, 1, CHAN_AUTO)

		ZCNPC.ClearHeadcrab(host, "release")

		org.alive = false
		org.brain = 1
		host:SetNWString("PlayerName", BODY_NAME)

		timer.Simple(0, function()
			if not IsValid(host) then return end

			host:SetNWString("PlayerName", BODY_NAME)

			local info = ZCNPC.Downed[host]
			if info then
				ZCNPC.KillDowned(host, info)
			elseif host:IsNPC() then
				local d = DamageInfo()
				d:SetDamage(10000)
				d:SetDamageType(DMG_GENERIC)
				d:SetAttacker(game.GetWorld())
				d:SetInflictor(game.GetWorld())
				host:TakeDamageInfo(d)
			end

			if IsValid(host) then host:SetNWString("PlayerName", BODY_NAME) end
		end)
	end
end)
--//

--\\ Death while latched
-- Mid-meal / early kill: the crab STAYS on the corpse (so a headshot can kill it).
-- Beheading: crab dies with the head. Finale already released it alive.
hook.Add("ZCNPC_Died", "zcnpc_headcrab", function(rag, org)
	if not IsValid(rag) then return end
	if not (rag:GetNetVar("headcrab") or (org and org.headcrabon)) then return end

	if org and org.headcrabevent then
		rag:SetNWString("PlayerName", BODY_NAME)

		return
	end

	if rag.noHead or rag.headexploded or (org and org.headamputated) then
		ZCNPC.ClearHeadcrab(rag, "kill")

		return
	end

	-- leave the crab on the corpse; name sticks
	rag:SetNWString("PlayerName", BODY_NAME)
end)

-- If something else clears the organism, drop the netvar so the client stops drawing.
hook.Add("Org Clear", "zcnpc_headcrab", function(org)
	if not org then return end

	org.headcrabon = nil
	org.headcrabevent = false
	org.zcnpc_headcrab_class = nil

	local owner = org.owner
	if IsValid(owner) and not owner:IsPlayer() then
		owner:SetNetVar("headcrab", false)
		owner.zcnpc_headcrab_class = nil
	end
end)
--//
