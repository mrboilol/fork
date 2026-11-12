local Clamp, Approach = math.Clamp, math.Approach

local LINES = {
	panic = {
		civilian = {"Oh god oh god oh god...", "Where do I- where?!", "Move, MOVE, just move!", "No no no no no...", "I can't breathe, I can't think...", "Make it stop, make it stop!"},
		trained = {"Okay, breathe. Get to cover first.", "Slow down. Panicking gets you killed.", "Breathe in... breathe out... now move.", "Too exposed. Move first, think after.", "Scared's fine. Freezing isn't."},
	},
	adrenaline = {
		civilian = {"My heart's going crazy...", "Everything's so loud...", "I can do this. I can do this.", "My hands won't stay still..."},
		trained = {"Alright. Who's next.", "Easy... front sight, squeeze.", "Good. Keep it going.", "Stay on it. Don't get cocky."},
	},
	crash = {
		civilian = {"Why am I shaking now? It's over...", "I think I'm gonna be sick...", "My legs feel like jelly...", "I need to sit down..."},
		trained = {"Here come the shakes. Ride it out.", "Hands are shaking. That's normal. Breathe.", "Coming down... check yourself for holes.", "Shake it off. Reset."},
	},
	shotAt = {
		civilian = {"THEY'RE SHOOTING AT ME! THEY'RE SHOOTING AT ME!", "Too close, too close, that was too close!", "I can't get my head up!", "Stop shooting, please stop shooting!"},
		trained = {"Fuck, that's close- stay down!", "Pinned. Wait for them to reload.", "Don't pop up in the same spot.", "Where the hell is that coming from..."},
	},
	witness = {
		civilian = {"They just... they just died. Right there.", "Oh god, they're not moving...", "That could've been me...", "I watched them die..."},
		trained = {"Can't help them now. Focus.", "They're gone. Don't look at it.", "Later. Deal with it later."},
	},
	corpse = {
		civilian = {"Don't look at it... don't look at it...", "There's so much blood...", "That was a person..."},
		trained = {"Don't look. Keep moving.", "Not now. Think about it later."},
	},
	firstKill = {
		civilian = {"I killed someone... I actually killed someone...", "They're not getting up... I did that...", "Oh god, what did I just do..."},
		trained = {"First one. Don't think about it. Not yet.", "They're down. That's it. Move."},
	},
	isolation = {
		civilian = {"Nobody's coming... nobody's coming for me...", "I'm alone... I'm going to die alone here...", "Please, someone... anyone..."},
		trained = {"Nobody's coming. Patch yourself up.", "On my own and hit... stop the bleeding first.", "No help's coming. Figure it out."},
	},
	anger = {
		civilian = {"You son of a bitch...", "Oh, you're dead. You're DEAD.", "That's it. I'm not running.", "Come here. COME HERE!"},
		trained = {"Wrong person to hit.", "Alright. My turn.", "Stay angry. Stay sharp.", "Not backing down from this."},
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
	updateThresholdThoughts(owner, org, K)
end)

local function onKill(victim, attacker)
	if not IsValid(victim) or not IsValid(attacker) then return end
	if not attacker:IsPlayer() and attacker.GetOwner then attacker = attacker:GetOwner() end
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim or not attacker:Alive() then return end
	if not victim:IsPlayer() and not victim.organism then return end
	if attacker.hgPsycheHasKilled or attacker.isTraitor then return end
	attacker.hgPsycheHasKilled = true

	if victim.hgFriendlyFireBy and (victim.hgFriendlyFireBy[attacker] or 0) > CurTime() - 15 then return end
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
