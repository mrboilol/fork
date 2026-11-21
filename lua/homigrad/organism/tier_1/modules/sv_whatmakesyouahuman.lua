local Clamp, Approach = math.Clamp, math.Approach

local LINES = {
	panic = {
		civilian = {"Oh god oh god oh god...", "I cant- I cant fucking focus...", "I CANT FOCUS!", "I need to clear my head...", "I cant' breathe properly...", "Make it stop.. make it stop..."},
		trained = {"Just breathe...", "I need to find somewhere to relax.", "I need cover.", "I need to move.", "I need to get my shit in order."},
	},
	adrenaline = {
		civilian = {"My heart's going crazy...", "Everything's so loud...", "Why- why am I shaking...", "Im shaking.. im fucking shaking..."},
		trained = {"Im starting to get anxious.", "Im starting to shake...", "I need to keep going...", "I cant panic.. not now.."},
	},
	crash = {
		civilian = {"Why am I shaking now? It's over...", "I think I'm gonna be sick...", "My legs are getting weak from that...", "Im dizzy and still shaking..."},
		trained = {"Still shaking.. I need to relax.", "Its over. Im still shaking though.", "Im still shaking.", "Here come the shakes..."},
	},
	shotAt = {
		civilian = {"THEY'RE SHOOTING AT ME! THEY'RE SHOOTING AT ME!", "WHY ARE THEY SHOOTING- WHY!?", "OH GOD IM GOING TO FUCKING DIE", "STOP SHOOTING STOP SHOOTING!"},
		trained = {"That's too close...", "Someone's angry at me...", "Im fucking pinned...", "Im being shot at..."},
	},
	witness = {
		civilian = {"They just... they just died. Right there.", "Oh god, they're not moving...", "That could've been me...", "I watched them die..."},
		trained = {"Can't help them now...", "They're gone..", "..."},
	},
	corpse = {
		civilian = {"Don't look at them.. just don't...", "Holy shit.. are they...?", "That was a person..."},
		trained = {"Don't look. Just dont look...", "Don't think about it..."},
	},
	firstKill = {
		civilian = {"I killed someone... I actually killed someone...", "Why- Why aren't they moving...", "Oh god, what did I just do..."},
		trained = {"First one.", "They're down."},
	},
	isolation = {
		civilian = {"Nobody's coming... nobody's coming for me...", "I'm alone and dying...", "WONT ANYONE COME FOR ME!?"},
		trained = {"Nobody's coming...", "Im on my own...", "No help's coming..."},
	},
	anger = {
		civilian = {"Fuck you. FUCK YOU!", "Oh, you're dead. You're DEAD.", "Im not fucking running from this.", "Come here. COME HERE!"},
		trained = {"Im not going down.", "Im refusing to run.", "I need to fight back."},
	},
}

local MELEE_BASES = {weapon_melee = true}

local function getTraining(ply)
	return hg.GetPsycheTraining and hg.GetPsycheTraining(ply) or 0
end

local function getSorrow(org)
	return Clamp(((tonumber(org.depression) or 0) - 0.1) / 0.5, 0, 1)
end

local function psycheThought(ply, key, ignoreGlobal)
	local K = hg.PsycheCombat
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	local org = ply.organism
	if not org or org.otrub or not hg.organism.EmotionThought then return end

	local now = CurTime()
	if not ignoreGlobal and not K.thoughtPriority[key] and now - (ply.hgLastEmotionTime or 0) < K.thoughtGlobalCooldown then return end
	ply.hgPsycheThoughtNext = ply.hgPsycheThoughtNext or {}
	if (ply.hgPsycheThoughtNext[key] or 0) > now then return end

	local set = LINES[key]
	local list = getTraining(ply) >= K.trainedLineThreshold and set.trained or set.civilian
	local index = math.random(#list)
	if list[index] == ply.hgLastEmotionText and #list > 1 then index = index % #list + 1 end

	ply.hgPsycheThoughtNext[key] = now + (K.thoughtCooldowns[key] or 30)
	hg.organism.EmotionThought(ply, list[index], K.thoughtDuration, "psyche_" .. key)
end

function hg.organism.PsychePanicGainMul(org, combatEvent)
	local K = hg.PsycheCombat
	local mul = Lerp(getTraining(org.owner), 1, K.trainedPanicGainMul) * Lerp(getSorrow(org), 1, K.sorrowPanicNumb) * (1 - hg.GetAngerShield(org) * K.angerPanicShield)
	if org.buddyNear and hg.Buddy then mul = mul * (1 - hg.Buddy.Config.moodResist) end
	if combatEvent and hg.organism.GetAdrenalineGainMul then
		hg.organism.GetAdrenalineGainMul(org)
		local ganged = org._adrGainMul or 1
		if ganged > 1 then mul = mul * (1 + (ganged - 1) * K.outnumberedPanicWeight) end
	end

	return mul
end

function hg.organism.PsychePanicDecayMul(org)
	local K = hg.PsycheCombat
	local mul = 1 + getTraining(org.owner) * K.trainedDecayBonus
	if org.psycheInCover then mul = mul * K.coverDecayMul end
	if (org.panicLastGain or 0) < CurTime() - K.calmAfter then mul = mul * K.calmDecayMul end

	return mul
end

function hg.organism.PsycheAdrenalineNumb(org)
	return Lerp(getSorrow(org), 1, hg.PsycheCombat.sorrowAdrenalineNumb)
end

function hg.organism.PsycheHitPanicMul(ply, attacker)
	if not IsValid(ply) or not IsValid(attacker) or attacker == ply then return 1 end
	local K = hg.PsycheCombat
	local dir = attacker:GetPos() - ply:GetPos()
	dir.z = 0
	dir:Normalize()
	local aim = ply:GetAimVector()
	aim.z = 0
	aim:Normalize()

	return aim:Dot(dir) < K.surpriseDot and K.surpriseHitMul or 1
end

function hg.organism.PsycheNearMiss(ply, org)
	local K = hg.PsycheCombat
	local now = CurTime()
	org.psycheShotAtHeat = (org.psycheShotAtHeat or 0) * math.exp(-(now - (org.psycheShotAtTime or now)) / K.shotAtWindow) + 1
	org.psycheShotAtTime = now
	if org.psycheShotAtHeat >= K.shotAtCount then psycheThought(ply, "shotAt") end
end

function hg.organism.PsycheWitnessDeath(watcher, org, pos)
	local K = hg.PsycheCombat
	if watcher:EyePos():DistToSqr(pos) > K.bystanderDeathRadius * K.bystanderDeathRadius then return end
	if hg.organism.AddDepression then hg.organism.AddDepression(org, K.bystanderDeathSorrow, "grief") end
	psycheThought(watcher, "witness")
end

function hg.organism.PsycheSeeCorpse(watcher, org, mul)
	local K = hg.PsycheCombat
	if hg.organism.AddDepression then hg.organism.AddDepression(org, K.corpseSorrow * mul, "aftermath") end
	psycheThought(watcher, "corpse")
end

local function updateCrash(owner, org, timeValue, K)
	local adrenaline = tonumber(org.adrenaline) or 0
	org.psycheAdrenalinePeak = math.max(org.psycheAdrenalinePeak or 0, adrenaline)
	local peak = org.psycheAdrenalinePeak

	if peak >= K.crashMinPeak and adrenaline <= K.crashEnd and (org.adrenalineAdd or 0) <= 0 then
		local strength = Clamp((peak - K.crashMinPeak) / (K.crashScalePeak - K.crashMinPeak), K.crashMinStrength, 1)
		org.adrenalineCrash = math.max(org.adrenalineCrash or 0, strength)
		org.psycheAdrenalinePeak = adrenaline
		psycheThought(owner, "crash")
	end

	org.adrenalineCrash = Approach(org.adrenalineCrash or 0, 0, timeValue / K.crashDuration)
end

local function updateCover(owner, org, now, K)
	if now < (org.psycheCoverNext or 0) then return end
	org.psycheCoverNext = now + K.coverCheckInterval
	org.psycheInCover = false

	local attacker = owner.lastPanicAttacker
	if not IsValid(attacker) or attacker == owner or (owner.lastPanicAttackTime or 0) < now - K.coverMemory then return end
	if attacker:IsPlayer() and not attacker:Alive() then return end

	local attackerChar = attacker:IsPlayer() and hg.GetCurrentCharacter(attacker) or attacker
	local attackerEye = attacker.EyePos and attacker:EyePos() or attacker:WorldSpaceCenter()
	org.psycheInCover = util.TraceLine({
		start = owner:EyePos(),
		endpos = attackerEye,
		filter = {owner, hg.GetCurrentCharacter(owner), attacker, attackerChar},
		mask = MASK_SHOT
	}).Hit
end

local function isMeleeWeapon(wep)
	return IsValid(wep) and (wep.ismelee or wep.ismelee2 or MELEE_BASES[wep.Base]) and true or false
end

local function updateMelee(owner, org, now, K)
	if now < (org.psycheMeleeNext or 0) then return end
	org.psycheMeleeNext = now + 0.2
	local eye = owner:EyePos()
	local radiusSqr = K.meleeRadius * K.meleeRadius

	for _, other in player.Iterator() do
		if other == owner or not other:Alive() then continue end
		if not other:KeyDown(IN_ATTACK) or not isMeleeWeapon(other:GetActiveWeapon()) then continue end
		local otherEye = other:EyePos()
		if otherEye:DistToSqr(eye) > radiusSqr then continue end
		if other:GetAimVector():Dot((eye - otherEye):GetNormalized()) < K.meleeDot then continue end

		org.psycheMeleeNext = now + K.meleeCooldown
		hg.organism.AddPanicAttack(org, K.meleePanic, true, false, true, true)
		return
	end
end

local function updateOxygen(org, timeValue, K)
	local o2 = org.o2 and tonumber(org.o2[1]) or 30
	local severity = Clamp((K.o2PanicStart - o2) / (K.o2PanicStart - K.o2PanicFull), 0, 1)
	if org.holdingbreath and o2 > K.o2PanicFull then severity = 0 end
	if org.choking then severity = math.max(severity, K.chokingPanic) end
	if severity <= 0 then return end

	hg.organism.AddPanicAttack(org, timeValue * K.o2PanicRate * severity, true, false, true, true)
end

local function hasCompany(owner, radius, now)
	local radiusSqr = radius * radius
	local attackers = owner.hgFightAttackers
	for _, other in player.Iterator() do
		if other == owner or not other:Alive() then continue end
		if attackers and (attackers[other] or 0) > now - 15 then continue end
		if other:GetPos():DistToSqr(owner:GetPos()) <= radiusSqr then return true end
	end

	return false
end

local function updateIsolation(owner, org, timeValue, now, K)
	local wounded = (tonumber(org.blood) or 5000) < K.isolationBlood or (tonumber(org.pain) or 0) > K.isolationPain
	if not wounded then
		org.psycheIsolatedFor = 0
		return
	end

	if now >= (org.psycheIsolationNext or 0) then
		org.psycheIsolationNext = now + K.isolationCheck
		org.psycheAlone = not hasCompany(owner, K.isolationRadius, now)
	end

	if not org.psycheAlone then
		org.psycheIsolatedFor = 0
		return
	end

	org.psycheIsolatedFor = (org.psycheIsolatedFor or 0) + timeValue
	if org.psycheIsolatedFor < K.isolationTime then return end
	if hg.organism.AddDepression then hg.organism.AddDepression(org, timeValue * K.isolationRate, "dying") end
	psycheThought(owner, "isolation")
end

local function updateAnger(owner, org, timeValue, K)
	local anger = Clamp(tonumber(org.anger) or 0, 0, 1)
	if anger < K.angerThoughtAt * 0.6 then
		org.psycheAngerArmed = true
	elseif org.psycheAngerArmed and anger >= K.angerThoughtAt then
		org.psycheAngerArmed = false
		psycheThought(owner, "anger")
	end

	if anger < K.angerPanicDrainStart or (org.panicattackadd or 0) <= 0 then return end
	local drain = timeValue * K.angerPanicDrain * (anger - K.angerPanicDrainStart) / (1 - K.angerPanicDrainStart)
	org.panicattackadd = Approach(org.panicattackadd, 0, drain)
end

local function updateThresholdThoughts(owner, org, K)
	local panic = tonumber(org.panicattack) or 0
	if panic < K.panicThoughtAt * 0.6 then
		org.psychePanicArmed = true
	elseif org.psychePanicArmed and panic >= K.panicThoughtAt then
		org.psychePanicArmed = false
		psycheThought(owner, "panic")
	end

	local adrenaline = tonumber(org.adrenaline) or 0
	if adrenaline < K.adrenalineThoughtAt * 0.6 then
		org.psycheAdrenalineArmed = true
	elseif org.psycheAdrenalineArmed and adrenaline >= K.adrenalineThoughtAt and panic < K.panicThoughtAt then
		org.psycheAdrenalineArmed = false
		psycheThought(owner, "adrenaline")
	end
end

function hg.organism.RelieveStress(org, amount)
	if not org or not isnumber(amount) or amount <= 0 then return end
	org.depression = Clamp((tonumber(org.depression) or 0) - amount, 0, 1)
	org.depressionadd = math.max((tonumber(org.depressionadd) or 0) - amount, 0)
	org.panicattackadd = math.max((tonumber(org.panicattackadd) or 0) - amount, 0)
end

function hg.organism.CombatSuccess(org, amount)
	if not org then return end
	local now = CurTime()
	if (org._successNext or 0) > now then return end
	org._successNext = now + hg.PsycheCombat.successCooldown
	hg.organism.RelieveStress(org, amount)
end

local function entDown(ent)
	if not IsValid(ent) then return true end
	if ent:IsPlayer() then
		local oorg = ent.organism
		return not ent:Alive() or (oorg and (oorg.otrub or oorg.alive == false)) or false
	end
	return ent:Health() <= 0
end

local function latestStamp(tbl, latest)
	if not tbl then return latest end
	for ent, when in pairs(tbl) do
		if IsValid(ent) and when > latest then latest = when end
	end
	return latest
end

local function updateDisengage(owner, org, now, timeValue, K)
	local last = latestStamp(owner.hgFightTargets, latestStamp(owner.hgFightAttackers, 0))
	if now - last < K.disengageAfter or now < (org.panicGunfightUntil or 0) then
		org.psycheEngaged = true
		return
	end

	local opp = org.angerOpponent
	local alive = not entDown(opp)
	local threat = alive and owner:GetPos():DistToSqr(opp:GetPos()) < K.angerFleeDistance * K.angerFleeDistance

	if org.psycheEngaged then
		org.psycheEngaged = nil
		local stressed = (org.adrenaline or 0) >= 0.3 or (org.adrenalineAdd or 0) > 0
		if alive and not threat and stressed and now >= (org.epinephrineStabilizationUntil or 0) then
			org.adrenalineAdd = math.min(org.adrenalineAdd or 0, 0)
			org._adrenalineHoldUntil = 0
			org._adrenalineReliefUntil = now + K.fleeReliefDuration
		end
	end

	if threat then return end
	if now < (org.angerCombatUntil or 0) then org.angerCombatUntil = now end

	local anger = tonumber(org.anger) or 0
	if anger <= 0 then return end
	local drop = math.min(anger, timeValue * K.angerDisengageDecay)
	org.anger = anger - drop

	local depression = Clamp(tonumber(org.depression) or 0, 0, 1)
	if alive and depression >= K.angerFleeDepression then
		local panic = math.max(tonumber(org.panicattackadd) or 0, 0)
		org.panicattackadd = math.max(panic, math.min(panic + drop * K.angerFleePanic, 1 - depression))
	end
end

local function updateAdrenalineIdle(org, now, timeValue, K)
	local adrenaline = tonumber(org.adrenaline) or 0
	local previous = org.psycheAdrLast or adrenaline
	local receiving = adrenaline > previous + 0.0005
		or (org.adrenalineAdd or 0) > 0
		or now < (org._adrenalineHoldUntil or 0)
		or org.panicattackActive
		or org.psycheEngaged
		or now < (org.panicGunfightUntil or 0)
		or now < (org.epinephrineStabilizationUntil or 0)
		or now < (org._berserkEndTime or 0)
		or now < (org._noradrenalineEndTime or 0)
	if receiving or not org.psycheAdrActiveAt then
		org.psycheAdrActiveAt = now
		org.psycheAdrLast = adrenaline
		return
	end

	local ramp = Clamp((now - org.psycheAdrActiveAt - K.adrenalineIdleAfter) / K.adrenalineIdleRamp, 0, 1)
	if ramp > 0 and adrenaline > 0 then
		adrenaline = Approach(adrenaline, 0, timeValue / 25 * (K.adrenalineIdleMul - 1) * ramp)
		org.adrenaline = adrenaline
	end
	org.psycheAdrLast = adrenaline
end

hook.Add("Org Think", "CombatPsyche", function(owner, org, timeValue)
	if not org.isPly or not IsValid(owner) or not owner:IsPlayer() then return end
	local K = hg.PsycheCombat
	if not K then return end

	if not owner:Alive() or org.otrub then
		org.psycheAdrenalinePeak = 0
		org.adrenalineCrash = Approach(org.adrenalineCrash or 0, 0, timeValue / K.crashDuration)
		return
	end

	local now = CurTime()
	updateCrash(owner, org, timeValue, K)
	updateCover(owner, org, now, K)
	updateMelee(owner, org, now, K)
	updateOxygen(org, timeValue, K)
	updateIsolation(owner, org, timeValue, now, K)
	updateAnger(owner, org, timeValue, K)
	updateDisengage(owner, org, now, timeValue, K)
	updateAdrenalineIdle(org, now, timeValue, K)
	updateThresholdThoughts(owner, org, K)
end)

local function onKill(victim, attacker)
	if not IsValid(victim) or not IsValid(attacker) then return end
	if not attacker:IsPlayer() and attacker.GetOwner then attacker = attacker:GetOwner() end
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim or not attacker:Alive() then return end
	if not victim:IsPlayer() and not victim.organism then return end
	if victim:IsNPC() then return end
	if attacker.hgPsycheHasKilled or attacker.isTraitor then return end
	attacker.hgPsycheHasKilled = true

	if victim.hgFriendlyFireBy and (victim.hgFriendlyFireBy[attacker] or 0) > CurTime() - 15 then return end
	if hg.organism.GetKillKarmaLoss and hg.organism.GetKillKarmaLoss(attacker, victim) > 0 then return end
	local K = hg.PsycheCombat
	local training = getTraining(attacker)
	local org = attacker.organism
	if not org or training >= K.firstKillTrainingMax then return end

	if hg.organism.AddDepression then hg.organism.AddDepression(org, K.firstKillSorrow * (1 - training / K.firstKillTrainingMax), "aftermath") end
	psycheThought(attacker, "firstKill", true)
end

hook.Add("PlayerDeath", "CombatPsycheFirstKill", function(victim, _, attacker)
	onKill(victim, attacker)
end)

hook.Add("OnNPCKilled", "CombatPsycheFirstKill", function(victim, attacker)
	onKill(victim, attacker)
end)

hook.Add("PlayerSpawn", "CombatPsycheReset", function(ply)
	ply.hgPsycheHasKilled = nil
	ply.hgPsycheThoughtNext = nil
	ply.hgLastEmotionText = nil
	local org = ply.organism
	if not org then return end
	org.psycheShotAtHeat = 0
	org.psycheIsolatedFor = 0
	org.psycheAlone = false
	org.psycheInCover = false
end)
