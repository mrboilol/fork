if CLIENT then return end

local min, max, Clamp = math.min, math.max, math.Clamp

hg = hg or {}

util.AddNetworkString("zcity_delta_moodles_extra")

if hg.ptsd_server_builtin then return end
hg.ptsd_server_builtin = true
hg.PTSD = hg.PTSD or {}

local cvEnabled = CreateConVar("hg_ptsd_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable PTSD trauma system", 0, 1)
local cvEffectsEnabled = CreateConVar("hg_ptsd_effects_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable PTSD gameplay and screen effects", 0, 1)
local cvDecayRate = CreateConVar("hg_ptsd_decay_rate", "0.35", FCVAR_ARCHIVE + FCVAR_REPLICATED, "PTSD trauma recovery per second once safe", 0, 5)
local cvDecayDelay = CreateConVar("hg_ptsd_decay_delay", "12", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Seconds after trauma before PTSD recovery starts", 0, 120)
local cvTraumaWound = CreateConVar("hg_ptsd_trauma_wound", "0.45", FCVAR_ARCHIVE + FCVAR_REPLICATED, "PTSD trauma per damage taken", 0, 5)
local cvTraumaDeath = CreateConVar("hg_ptsd_trauma_death", "8", FCVAR_ARCHIVE + FCVAR_REPLICATED, "PTSD trauma from witnessing death", 0, 50)
local cvTraumaCorpse = CreateConVar("hg_ptsd_trauma_corpse", "3", FCVAR_ARCHIVE + FCVAR_REPLICATED, "PTSD trauma from seeing a corpse", 0, 50)
local cvTraumaHead = CreateConVar("hg_ptsd_trauma_head_explosion", "14", FCVAR_ARCHIVE + FCVAR_REPLICATED, "PTSD trauma from seeing a head explosion", 0, 60)
local cvTraumaGunfire = CreateConVar("hg_ptsd_trauma_gunfire", "2.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "PTSD trauma from nearby confirmed bullet hits", 0, 10)
local cvTraumaExplosion = CreateConVar("hg_ptsd_trauma_explosion", "18", FCVAR_ARCHIVE + FCVAR_REPLICATED, "PTSD trauma from blast damage", 0, 60)
local cvTraumaCombat = CreateConVar("hg_ptsd_trauma_combat", "3", FCVAR_ARCHIVE + FCVAR_REPLICATED, "PTSD trauma per combat second", 0, 60)
local cvFlashbackMin = CreateConVar("hg_ptsd_flashback_min", "75", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Minimum PTSD trauma for full flashback memories", 0, 100)
local cvRandomFlashMin = CreateConVar("hg_ptsd_random_flash_min", "180", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Minimum random PTSD flashback interval", 30, 3600)
local cvRandomFlashMax = CreateConVar("hg_ptsd_random_flash_max", "420", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum random PTSD flashback interval", 30, 3600)
local cvOpioidTraumaMul = CreateConVar("hg_ptsd_opioid_trauma_mul", "0.4", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Trauma multiplier at high analgesia", 0, 1)
local cvOpioidDecayBoost = CreateConVar("hg_ptsd_opioid_decay_boost", "4", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Trauma decay multiplier at high analgesia", 1, 20)
local cvDebug = CreateConVar("hg_ptsd_debug", "0", FCVAR_ARCHIVE, "Print PTSD trauma changes", 0, 1)

local function is_enabled()
	return cvEnabled:GetBool()
end

local function effects_enabled()
	return is_enabled() and cvEffectsEnabled:GetBool()
end

local function get_org(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return nil end
	return ply.organism
end

local function resolve_harm_attacker(victim, attacker)
	if IsValid(attacker) and attacker:IsPlayer() then return attacker end
	if IsValid(attacker) and attacker.GetOwner then
		local owner = attacker:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then return owner end
	end
	if IsValid(victim) and victim.GetPhysicsAttacker then
		local physicsAttacker = victim:GetPhysicsAttacker()
		if IsValid(physicsAttacker) and physicsAttacker:IsPlayer() then return physicsAttacker end
	end
	if zb and zb.HarmDone and IsValid(victim) then
		local mostHarm, culprit = 0, nil
		for candidate, harm in pairs(zb.HarmDone[victim] or {}) do
			if IsValid(candidate) and candidate:IsPlayer() and harm > mostHarm then
				mostHarm, culprit = harm, candidate
			end
		end
		return culprit
	end
end

local function get_opioid_level(org)
	if not org then return 0 end
	local analgesia = max(tonumber(org.analgesia) or 0, tonumber(org.analgesiaAdd) or 0)
	if analgesia < 0.2 then return 0 end
	return Clamp((analgesia - 0.2) / 1.5, 0, 1)
end

local function schedule_next_flash(state)
	local minTime = math.floor(cvRandomFlashMin:GetFloat())
	local maxTime = math.floor(cvRandomFlashMax:GetFloat())
	if minTime <= 0 then minTime = 180 end
	if maxTime <= 0 then maxTime = 420 end
	if minTime > maxTime then minTime, maxTime = maxTime, minTime end
	state.nextFlash = CurTime() + math.random(minTime, maxTime)
end

local function get_state(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return nil end

	ply.__hg_ptsd = ply.__hg_ptsd or {
		trauma = 0,
		lastTraumaEvent = 0,
		inCombat = false,
		lastCombatTime = 0,
		lastOwnDamageTrauma = 0,
		lastNearbyHitTrauma = 0,
		lastCorpseCheck = 0,
		lastCorpseCacheClean = 0,
		seenCorpses = {},
		panicTrauma = 0,
		flashbackUntil = 0,
		nextFlash = 0,
		memorySerial = 0,
		nextMemoryCapture = 0,
		recoveryBoostUntil = 0,
		lastReason = "",
	}

	if (ply.__hg_ptsd.nextFlash or 0) <= 0 then
		schedule_next_flash(ply.__hg_ptsd)
	end

	return ply.__hg_ptsd
end

local function trauma_level(trauma)
	if trauma < 50 then return 0, "building" end
	if trauma < 75 then return 1, "visible" end
	return 2, "severe"
end

local function publish_state(ply, org)
	local state = get_state(ply)
	if not state then return nil end

	local trauma = Clamp(tonumber(state.trauma) or 0, 0, 100)
	state.trauma = trauma

	local intensity = Clamp(trauma / 100, 0, 1)
	local level, label = trauma_level(trauma)
	if (state.flashbackUntil or 0) > CurTime() then
		label = "flashback"
	end

	local panicRisk = Clamp((trauma - 25) / 75, 0, 1)
	if (state.flashbackUntil or 0) > CurTime() then
		panicRisk = max(panicRisk, 0.78)
	end
	ply:SetNWFloat("hg_ptsd_trauma", trauma)
	ply:SetNWFloat("hg_ptsd_intensity", intensity)
	ply:SetNWFloat("hg_ptsd_panic_risk", panicRisk)
	ply:SetNWFloat("hg_ptsd_flashback_until", state.flashbackUntil or 0)
	ply:SetNWInt("hg_ptsd_memory_serial", state.memorySerial or 0)
	ply:SetNWString("hg_ptsd_state", is_enabled() and label or "disabled")

	if org then
		org.ptsdTrauma = trauma
		org.ptsdIntensity = intensity
		org.ptsdPanicRisk = panicRisk
		org.ptsdState = is_enabled() and label or "disabled"
		org.ptsdFlashback = (state.flashbackUntil or 0) > CurTime()
	end

	return {
		trauma = trauma,
		intensity = intensity,
		level = level,
		state = label,
		panicRisk = panicRisk,
		flashback = (state.flashbackUntil or 0) > CurTime(),
	}
end

local function set_combat(state, duration)
	state.inCombat = true
	state.lastCombatTime = CurTime()
	state.combatDuration = tonumber(duration) or 15
end

local function adjust_trauma(ply, amount, reason, flags)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if not is_enabled() then return end

	local state = get_state(ply)
	if not state then return end

	local org = get_org(ply)
	amount = tonumber(amount) or 0
	flags = flags or {}

	if amount > 0 then
		local opioid = get_opioid_level(org)
		if opioid > 0 then
			amount = amount * Lerp(opioid, 1, cvOpioidTraumaMul:GetFloat())
		end
		state.lastTraumaEvent = CurTime()
		state.lastReason = tostring(reason or "")
		if flags.combat then set_combat(state, 15) end
		-- Store a client-side snapshot of actual trauma. These become the only
		-- images used by PTSD flashbacks; ordinary brain-damage memories stay separate.
		if amount >= 0.25 and CurTime() >= (state.nextMemoryCapture or 0) then
			state.memorySerial = (state.memorySerial or 0) + 1
			state.nextMemoryCapture = CurTime() + 6
		end
	elseif amount < 0 and not flags.allowNegative then
		return
	end

	local before = state.trauma or 0
	state.trauma = Clamp(before + amount, 0, 100)

	if cvDebug:GetBool() and amount ~= 0 and math.abs(state.trauma - before) > 0.01 then
		print(string.format("[hg_ptsd] %s %+0.2f trauma (%s) => %0.2f", ply:Nick(), amount, tostring(reason or "?"), state.trauma))
	end

	return publish_state(ply, org)
end

local function add_trauma(ply, amount, reason, flags)
	if amount <= 0 then return end
	return adjust_trauma(ply, amount, reason, flags)
end

local function reduce_trauma(ply, amount, reason)
	if amount <= 0 then return end
	return adjust_trauma(ply, -amount, reason, {allowNegative = true})
end

function hg.PTSD.IsEnabled()
	return is_enabled()
end

function hg.PTSD.AreEffectsEnabled()
	return effects_enabled()
end

function hg.PTSD.GetState(ply, org)
	if not IsValid(ply) or not ply:IsPlayer() then return nil end
	return publish_state(ply, org or get_org(ply))
end

function hg.PTSD.GetTrauma(ply)
	local state = get_state(ply)
	return state and (state.trauma or 0) or 0
end

function hg.PTSD.AddTrauma(ply, amount, reason, flags)
	return add_trauma(ply, amount, reason, flags)
end

function hg.PTSD.ReduceTrauma(ply, amount, reason)
	return reduce_trauma(ply, amount, reason)
end

function hg.PTSD.ApplyBetaBlockerStressReset(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	local state = get_state(ply)
	if state then
		state.flashbackUntil = 0
		state.recoveryBoostUntil = CurTime() + 60
	end
	reduce_trauma(ply, 10, "beta_blocker")
end

function hg.PTSD.GetMedicalProgressModifier(ply)
	if not effects_enabled() then return 1 end
	local state = hg.PTSD.GetState(ply)
	if not state then return 1 end
	return Clamp(1 - state.panicRisk * 0.18, 0.75, 1)
end

GetMedicalProgressModifier = function(ply, target, minigameType, progressDelta)
	return hg.PTSD.GetMedicalProgressModifier(ply, target, minigameType, progressDelta)
end

local function reset_state(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	ply.__hg_ptsd = {
		trauma = 0,
		lastTraumaEvent = 0,
		inCombat = false,
		lastCombatTime = 0,
		lastOwnDamageTrauma = 0,
		lastNearbyHitTrauma = 0,
		lastCorpseCheck = 0,
		lastCorpseCacheClean = 0,
		seenCorpses = {},
		panicTrauma = 0,
		flashbackUntil = 0,
		nextFlash = 0,
		memorySerial = 0,
		nextMemoryCapture = 0,
		recoveryBoostUntil = 0,
		lastReason = "",
	}

	schedule_next_flash(ply.__hg_ptsd)
	publish_state(ply, get_org(ply))
end

hook.Add("Org Clear", "hg_ptsd_org_clear", function(org)
	org.ptsdTrauma = 0
	org.ptsdIntensity = 0
	org.ptsdPanicRisk = 0
	org.ptsdState = "stable"
	org.ptsdFlashback = false
end)

hook.Add("PlayerInitialSpawn", "hg_ptsd_initial_spawn", function(ply)
	reset_state(ply)
end)

hook.Add("PlayerSpawn", "hg_ptsd_spawn_reset", function(ply)
	timer.Simple(0, function()
		if IsValid(ply) then reset_state(ply) end
	end)
end)

local function is_ragdoll_corpse(ent)
	if not IsValid(ent) or not ent:IsRagdoll() then return false end
	if hg.RagdollOwner then
		local owner = hg.RagdollOwner(ent)
		if IsValid(owner) and owner:Alive() then return false end
	end
	return true
end

local function can_see_entity(ply, ent)
	if not IsValid(ply) or not IsValid(ent) then return false end
	local startPos = ply:EyePos()
	local endPos = ent:IsPlayer() and ent:EyePos() or ent:WorldSpaceCenter()
	local tr = util.TraceLine({
		start = startPos,
		endpos = endPos,
		filter = ply,
	})
	return (not tr.Hit) or tr.Entity == ent
end

local amputated_limbs = {
	llegamputated = true,
	rlegamputated = true,
	rarmamputated = true,
	larmamputated = true,
	headamputated = true,
}

local function corpse_trauma_multiplier(ent)
	local mul = 1
	local org = ent.organism
	if not org and hg.RagdollOwner then
		local owner = hg.RagdollOwner(ent)
		if IsValid(owner) then org = owner.organism end
	end
	if org then
		for limb in pairs(amputated_limbs) do
			if org[limb] then mul = mul + 0.5 end
		end
	end
	return Clamp(mul, 1, 3)
end

local function is_in_danger(org)
	if not org or org.otrub then return false end
	local o2 = org.o2 and org.o2[1] or 100
	local blood = org.blood or 5000
	local bleed = org.bleed or 0
	local bp = org.bloodpressure or 93
	return o2 < 18 or org.choking or org.lungsfunction == false or (blood < 3800 and bleed > 0.05) or bp < 55 or org.heartstop or (org.brain or 0) >= 0.6
end

local function danger_severity(org)
	if not org then return 0 end
	local o2 = org.o2 and org.o2[1] or 100
	local blood = org.blood or 5000
	local bleed = org.bleed or 0
	local bp = org.bloodpressure or 93
	local severity = 0
	severity = max(severity, Clamp((18 - o2) / 18, 0, 1))
	if bleed > 0.05 then severity = max(severity, Clamp((3800 - blood) / 1400, 0, 1)) end
	severity = max(severity, Clamp((60 - bp) / 60, 0, 1))
	severity = max(severity, Clamp(((org.brain or 0) - 0.45) / 0.35, 0, 1))
	if org.heartstop or org.lungsfunction == false then severity = 1 end
	return severity
end

local function update_decay(owner, org, state, timeValue)
	if state.inCombat and CurTime() - (state.lastCombatTime or 0) > (state.combatDuration or 15) then
		state.inCombat = false
	end

	if state.inCombat then
		local combatAdd = cvTraumaCombat:GetFloat() * timeValue
		local opioid = get_opioid_level(org)
		if opioid > 0 then
			combatAdd = combatAdd * Lerp(opioid, 1, cvOpioidTraumaMul:GetFloat())
		end
		state.trauma = Clamp((state.trauma or 0) + combatAdd, 0, 100)
		state.lastTraumaEvent = CurTime()
		return
	end

	if (state.trauma or 0) <= 0 then return end
	if CurTime() - (state.lastTraumaEvent or 0) < cvDecayDelay:GetFloat() then return end

	local decay = cvDecayRate:GetFloat()
	local opioid = get_opioid_level(org)
	if opioid > 0 then
		decay = decay * Lerp(opioid, 1, cvOpioidDecayBoost:GetFloat())
	end
	if (state.recoveryBoostUntil or 0) > CurTime() then
		decay = decay * 2.5
	end
	if org and (org.goodmood or 0) > 0.4 then
		decay = decay * (1 + Clamp(org.goodmood, 0, 1) * 0.6)
	end

	state.trauma = max((state.trauma or 0) - decay * timeValue, 0)
end

local function update_flashback(owner, org, state)
	local now = CurTime()
	if (state.flashbackUntil or 0) > now then
		if org and not org.otrub then
			org.adrenalineAdd = (org.adrenalineAdd or 0) + 0.01
			org.fearadd = min((org.fearadd or 0) + 0.01, 3)
		end
		return
	end

	-- Trauma below 50 only builds the stored memory pool. At 50 visual distress
	-- is enabled client-side; full replaying flashbacks begin at 75 or higher.
	if (state.trauma or 0) < max(75, cvFlashbackMin:GetFloat()) then return end
	if now < (state.nextFlash or 0) then return end
	if org and org.otrub then return end

	state.flashbackUntil = now + math.Rand(2.5, 5.0)
	schedule_next_flash(state)
	if org then
		org.adrenalineAdd = (org.adrenalineAdd or 0) + 0.25
		org.fearadd = min((org.fearadd or 0) + 0.18, 3)
	end
end

local function update_corpse_witness(owner, org, state)
	local now = CurTime()
	if now < (state.lastCorpseCheck or 0) then return end
	state.lastCorpseCheck = now + 2

	for _, ent in ipairs(ents.FindInSphere(owner:GetPos(), 400)) do
		if not IsValid(ent) then continue end
		if ent == owner then continue end
		if not (is_ragdoll_corpse(ent) or (ent:IsPlayer() and not ent:Alive())) then continue end

		local idx = ent:EntIndex()
		if state.seenCorpses[idx] then continue end
		if not can_see_entity(owner, ent) then continue end

		state.seenCorpses[idx] = true
		add_trauma(owner, cvTraumaCorpse:GetFloat() * corpse_trauma_multiplier(ent), "corpse", {combat = false})
	end

	if now >= (state.lastCorpseCacheClean or 0) then
		state.lastCorpseCacheClean = now + 30
		for idx in pairs(state.seenCorpses) do
			if not IsValid(Entity(idx)) then
				state.seenCorpses[idx] = nil
			end
		end
	end
end

local function absorb_panic(org, state, timeValue)
	if not org or not effects_enabled() then return end
	if not org.panicattackActive then
		state.panicWasActive = false
		state.panicTrauma = 0
		return
	end
	if org.otrub or (org.berserk or 0) > 0 or (org.noradrenaline or 0) > 0 then return end
	if not state.panicWasActive then
		state.panicWasActive = true
		state.panicTrauma = 0
	end

	-- Panic is an acute traumatic event. It can worsen PTSD, but each attack has a
	-- bounded contribution so the panic/PTSD relationship cannot self-amplify forever.
	local add = min(timeValue * (0.18 + (org.panicattack or 0) * 0.22), max(8 - (state.panicTrauma or 0), 0))
	if add <= 0 then return end
	state.panicTrauma = (state.panicTrauma or 0) + add
	state.trauma = Clamp((state.trauma or 0) + add, 0, 100)
	state.lastTraumaEvent = CurTime()
	state.lastReason = "panicattack"
end

local function send_moodles_extra(owner, org)
	if not org then return end
	if owner.__hg_ptsd_moodles_next_send and CurTime() < owner.__hg_ptsd_moodles_next_send then return end
	owner.__hg_ptsd_moodles_next_send = CurTime() + 0.5

	net.Start("zcity_delta_moodles_extra")
	net.WriteFloat(org.satiety or 0)
	net.WriteFloat(org.internalBleed or 0)
	net.WriteFloat(org.hungry or 0)
	net.Send(owner)
end

hook.Add("Org Think", "hg_ptsd_bridge", function(owner, org, timeValue)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end

	if not is_enabled() then
		owner:SetNWFloat("hg_ptsd_trauma", 0)
		owner:SetNWFloat("hg_ptsd_intensity", 0)
		owner:SetNWFloat("hg_ptsd_panic_risk", 0)
		owner:SetNWFloat("hg_ptsd_flashback_until", 0)
		owner:SetNWString("hg_ptsd_state", "disabled")
		if org then
			org.ptsdTrauma = 0
			org.ptsdIntensity = 0
			org.ptsdPanicRisk = 0
			org.ptsdState = "disabled"
			org.ptsdFlashback = false
		end
		return
	end

	local state = get_state(owner)
	if not state then return end

	update_decay(owner, org, state, timeValue)
	update_flashback(owner, org, state)
	update_corpse_witness(owner, org, state)
	absorb_panic(org, state, timeValue)
	publish_state(owner, org)
	send_moodles_extra(owner, org)
end)

local function own_damage_trauma(ply, damage, reason, combat)
	local state = get_state(ply)
	if not state then return end
	local now = CurTime()
	if now - (state.lastOwnDamageTrauma or 0) < 0.15 then return end
	state.lastOwnDamageTrauma = now
	add_trauma(ply, Clamp(damage * cvTraumaWound:GetFloat(), 0.5, 24), reason or "wound", {combat = combat ~= false})
end

local function is_severely_hurt_witness_target(target, damage)
	if not IsValid(target) then return false end
	if target:IsPlayer() then
		local org = get_org(target)
		return not target:Alive()
			or (org and ((org.bleed or 0) >= 2 or org.incapacitated or org.critical))
			or target:Health() - damage <= 0
	end

	return target:IsNPC() and target:Health() - damage <= 0
end

hook.Add("HomigradDamage", "hg_ptsd_damage_gain", function(ply, dmgInfo)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	local org = get_org(ply)
	if org and org.otrub then return end

	local dmg = (dmgInfo and dmgInfo.GetDamage and dmgInfo:GetDamage()) or 0
	if dmg <= 0 then return end

	local reason = "wound"
	local combat = true
	if dmgInfo and dmgInfo.IsDamageType and dmgInfo:IsDamageType(DMG_BLAST) then
		reason = "explosion"
		add_trauma(ply, Clamp(cvTraumaExplosion:GetFloat() * 0.4 + dmg * cvTraumaWound:GetFloat(), 1, 28), reason, {combat = true})
		return
	end

	own_damage_trauma(ply, dmg, reason, combat)
end)

hook.Add("EntityTakeDamage", "hg_ptsd_nearby_hit", function(target, dmgInfo)
	if not IsValid(target) or not dmgInfo then return end
	if not (target:IsPlayer() or target:IsNPC()) then return end
	local damage = dmgInfo:GetDamage()
	if damage <= 0 then return end

	if target:IsPlayer() then
		if dmgInfo:IsBulletDamage() then
			own_damage_trauma(target, damage, "wound", true)
		end
	end

	if not dmgInfo:IsBulletDamage() then return end
	if not is_severely_hurt_witness_target(target, damage) then return end
	local attacker = resolve_harm_attacker(target, dmgInfo:GetAttacker())

	local targetPos = target:GetPos()
	for _, ply in ipairs(player.GetAll()) do
		if ply == target then continue end
		if IsValid(attacker) and ply == attacker then continue end
		if not IsValid(ply) or not ply:Alive() then continue end
		local state = get_state(ply)
		if not state then continue end

		local dist = ply:GetPos():Distance(targetPos)
		if dist > 200 then continue end
		if CurTime() - (state.lastNearbyHitTrauma or 0) < 0.2 then continue end

		state.lastNearbyHitTrauma = CurTime()
		local falloff = 1 - Clamp(dist / 200, 0, 1)
		add_trauma(ply, cvTraumaGunfire:GetFloat() * max(falloff, 0.35), "nearby_hit", {combat = true})
	end
end)

hook.Add("PlayerDeath", "hg_ptsd_kill_trauma", function(victim, inflictor, attacker)
	if IsValid(victim) and victim:IsPlayer() then
		add_trauma(victim, 25, "own_death", {combat = false})
	end
end)

local function witness_death_trauma(victim, ent, amount, reason, radius, attacker)
	if not IsValid(ent) then return end
	local pos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
	local now = CurTime()

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if ply == victim then continue end
		if IsValid(attacker) and ply == attacker then continue end

		local state = get_state(ply)
		if not state then continue end
		local key = "death_" .. ent:EntIndex()
		if state[key] and now < state[key] then continue end

		local dist = ply:EyePos():Distance(pos)
		if dist > radius then continue end
		if not can_see_entity(ply, ent) then continue end

		state[key] = now + 4
		local falloff = 1 - Clamp(dist / radius, 0, 1)
		add_trauma(ply, amount * max(falloff, 0.35), reason, {combat = false})
	end
end

hook.Add("HG_HeadExploded", "hg_ptsd_head_explosion", function(rag, victim)
	witness_death_trauma(victim, rag, cvTraumaHead:GetFloat(), "head_explosion", 900, resolve_harm_attacker(victim))
end)

hook.Add("RagdollDeath", "hg_ptsd_death_witness", function(victim, rag)
	witness_death_trauma(victim, rag, cvTraumaDeath:GetFloat(), "witness_death", 700, resolve_harm_attacker(victim))
end)

concommand.Add("hg_ptsd", function(ply, cmd, args)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:IsAdmin() then return end
	local val = tonumber(args and args[1])
	if not val then
		ply:ChatPrint("Usage: hg_ptsd <0-100>")
		return
	end

	local state = get_state(ply)
	if not state then return end
	state.trauma = Clamp(val, 0, 100)
	state.lastTraumaEvent = CurTime()
	publish_state(ply, get_org(ply))
	ply:ChatPrint("[Debug] PTSD trauma set to " .. tostring(math.Round(state.trauma, 1)))
end)

concommand.Add("hg_ptsd_flashback", function(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:IsAdmin() then return end
	local state = get_state(ply)
	if not state then return end
	state.flashbackUntil = CurTime() + 5
	state.trauma = max(state.trauma or 0, cvFlashbackMin:GetFloat())
	publish_state(ply, get_org(ply))
	ply:ChatPrint("[Debug] PTSD flashback triggered.")
end)
