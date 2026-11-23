local FIGHT_WINDOW = 15
local SUPPORT_RADIUS = 1200
local GAIN_MUL_REFRESH = 0.5
local SUPPORT_STEP = 0.6
local SUPPORT_FLOOR = 0.3
local OUTNUMBERED_STEP = 0.25
local OUTNUMBERED_CEIL = 1.6

local DEATH_RADIUS = 900
local OTRUB_RADIUS = 500
local CORPSE_RADIUS = 450
local CLOSE_RADIUS = 220
local SEE_DOT = 0.35
local CORPSE_SEE_DOT = 0.5
local CORPSE_INTERVAL = 2
local OTRUB_REPEAT_COOLDOWN = 90
local KILLER_THREAT_RADIUS = 1500

local SURGE_CAP = 2
local SURGE_BUDDY_DEATH = 0.9
local SURGE_BUDDY_OTRUB = 0.4
local SURGE_GANGED_KILL = 0.7

local RELIEF_DURATION = 14
local RELIEF_PANIC_KEEP = 0.5
local RELIEF_MIN_ADRENALINE = 0.3

local STRESS = {
	death = {panic = 0.35, depression = 0.3, fear = 0.5},
	otrub = {panic = 0.16, depression = 0.08, fear = 0.3},
	corpse = {panic = 0.3, depression = 0, fear = 0.15, always = true},
}
local BUDDY_MUL = 2

local FIGHT_DAMAGE = DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST + DMG_SLASH + DMG_CLUB

local EMO = {
	reliefHappiness = 0.35,
	hopeHappiness = 0.15,
	fighterSeeRadius = 3000,
	chanceHappiness = 0.1,
	chanceCooldown = 6,
	chanceCheckDelay = 0.15,
	chancePainJump = 30,
	chancePainHigh = 70,
	disarmWindow = 1,
	stressedDepression = 0.1,
	stressedHurt = 0.35,
	friendlyFireDepression = 0.12,
	friendlyKillDepression = 0.35,
	karmaKillDepression = 0.5,
	karmaKillFull = 30,
	karmaKillLowMul = 0.5,
	friendlyFireCooldown = 8,
	losingInterval = 1,
	losingStart = 0.3,
	losingBadly = 0.5,
	losingConvertRate = 0.012,
	winningHurt = 0.35,
	winningHappiness = 0.01,
	hopelessTime = 20,
	hopelessDepression = 0.2,
	doomedHurt = 0.7,
	doomedDepression = 0.08,
	botchTries = 4,
	botchTryWindow = 3,
	botchDepression = 0.06,
}

local HANDS = {weapon_hg_coolhands = true, weapon_hands_sh = true}

local PHRASES = {
	buddyDeath = {"Holy shit.. they just died...", "THEY JUST FUCKING DIED IN FRONT OF ME", "IM NEXT, IM NEXT!"},
	buddyDown = {"No, no, no, get up!", "They're down.. holy crap..", "Oh fuck- he just dropped down.."},
	friendlyFire = {"DID I JUST HIT MY OWN TEAMMATE?", "I JUST HIT MY OWN TEAM", "WHY DID I DO THAT"},
	friendlyKill = {"WHAT DID I JUST DO", "THEY WERE ON MY SIDE", "WHAT THE FUCK IS WRONG WITH ME"},
	regretKill = {"They didn't have to die...", "That wasn't supposed to happen...", "I killed an innocent person..."},
	calmDown = {
		solo = {"That's it.. I won.", "Oh.. its over.", "Hey.. I got him."},
		ganged = {"Nice.. one down.", "Shit.. there's still more?", "Thats one out of many."},
		group = {"I KNEW WE COULD DO IT!", "I GOT ONE!", "YEAH! ONE DOWN!"},
		fist = {"THAT'S WHAT YOU GET!", "YEAH! HOW'D YOU LIKE THAT?"},
	},
	hope = {
		solo = {"Fuck- I think I finally got him down..", "I got one.."},
		ganged = {"One less on me... I can do this!", "I know I can keep going I just know it..", "I might actually win this..."},
		group = {"WE MIGHT WIN!", "YEAH, HOW'D YOU LIKE THAT?"},
		fist = {"THAT'S WHAT YOU GET!", "I KNEW I HAD IT IN ME!"},
	},
	relief = {
		solo = {"It's over... I'm still alive.", "I'm okay.. Im okay...", "Im fucking shaking after that..."},
		ganged = {"All of them... holy shit, I'm alive...", "I actually made it... I don't believe it..."},
		group = {"We did it... we actually did it.", "That's all of them. We're okay.", "It's over. We made it."},
		fist = {"They're out.. I did it..", "I did that.. With my fists..."},
	},
	chance = {
		solo = {"They're in pain.. I need to keep going.", "They're slowing down, I cant stop now."},
		ganged = {"That one's hurt bad... I might get out of this..", "I got one, I must keep going."},
		group = {"They're breaking! We've got this!", "They're hurt! We might win!"},
		fist = {"I need to keep going, They're going down!", "I felt something of them break."},
	},
	disarm = {
		solo = {"I got their gun- I got it!", "Oh shit- Their gun is gone!"},
		ganged = {"One of them dropped it!"},
		group = {"They dropped their gun..?", "They're unarmed!"},
		fist = {"I gotta hit them before they pick it up!"},
	},
	doomed = {
		solo = {"They're going to kill me, They're actually going to fucking kill me..", "I'm fucking hurt.. I dont know if I can keep going.."},
		ganged = {"Jesus chrsist im going to die to them..", "There's too much of them..!"},
		group = {"Someone help me please...", "Please someone just cover me..."},
		fist = {"One more hit and I'm done...", "They're gonna beat me to fucking death..."},
	},
	botch = {
		solo = {"WHY AM I MISSING", "I CAN'T FUCKING HIT THEM"},
		ganged = {"HOW HAVE I NOT HIT ANYTHING", "I CAN'T HIT ANY OF THEM!"},
		group = {"I'm not hitting shit..", "Fuck, im useless.."},
		fist = {"I can't land anything...", "I can't hit a damn thing!"},
	},
	hopeless = {
		solo = {"I'm going to die to this fucking guy.", "I'm going to die arent I?"},
		ganged = {"I'm not getting out of this.", "This is it."},
		group = {"We're losing...", "We're fucked... we're so fucked..."},
		fist = {"I can't fight back... they're going to kill me with their bare hands...", "I can't even lift my arms anymore..."},
	},
}

local function resolveFighter(ent)
	if not IsValid(ent) then return end
	if ent:IsPlayer() or ent:IsNPC() then return ent end
	local owner = ent.GetOwner and ent:GetOwner()
	if IsValid(owner) and (owner:IsPlayer() or owner:IsNPC()) then return owner end
end

local function resolveVictim(ent)
	if ent:IsPlayer() or ent:IsNPC() then return ent end
	if IsValid(ent.ply) and ent.ply:IsPlayer() then return ent.ply end
end

local downedFighter

local function isActiveFighter(ent)
	if not IsValid(ent) then return false end
	if ent == downedFighter then return true end
	if ent:IsPlayer() then
		return ent:Alive() and not (ent.organism and ent.organism.otrub)
	end
	return ent:Health() > 0
end

local function targetsOrganism(ent, watcher, org)
	if not IsValid(ent) or ent == watcher then return false end
	if ent.organism == org then return true end
	local owner = hg.RagdollOwner and hg.RagdollOwner(ent)
	return IsValid(owner) and owner.organism == org
end

local function isTreating(watcher, org)
	if not org then return false end
	local wep = watcher:GetActiveWeapon()
	if IsValid(wep) and (targetsOrganism(wep.CarryEnt, watcher, org) or targetsOrganism(wep.healbuddy, watcher, org) or targetsOrganism(wep.healsubject, watcher, org)) then
		return true
	end
	local session = hg.Suture and hg.Suture.Sessions and hg.Suture.Sessions[watcher]
	return session ~= nil and targetsOrganism(session.target, watcher, org)
end

local function collectRecent(tbl, exclude)
	local out = {}
	if not tbl then return out end
	local cutoff = CurTime() - FIGHT_WINDOW
	for ent, when in pairs(tbl) do
		if not IsValid(ent) or when < cutoff then
			tbl[ent] = nil
		elseif ent != exclude and isActiveFighter(ent) then
			out[#out + 1] = ent
		end
	end
	return out
end

local function wasFighting(tbl, ent)
	return tbl and (tbl[ent] or 0) > CurTime() - FIGHT_WINDOW
end

local function hitsFrom(victim, attacker)
	local rec = victim.hgHitsFrom and victim.hgHitsFrom[attacker]
	return rec and rec.t > CurTime() - FIGHT_WINDOW and rec.n or 0
end

local function hitsMeMore(owner, ent)
	local onMe = hitsFrom(owner, ent)
	if onMe == 0 then return false end
	local onTargets = 0
	for target, when in pairs(owner.hgFightTargets or {}) do
		if IsValid(target) and when > CurTime() - FIGHT_WINDOW then
			onTargets = onTargets + hitsFrom(target, ent)
		end
	end
	return onTargets <= onMe
end

local function collectAttackers(owner, exclude)
	local out = {}
	for _, ent in ipairs(collectRecent(owner.hgFightAttackers, exclude)) do
		if hitsMeMore(owner, ent) then out[#out + 1] = ent end
	end
	return out
end

local function countSupporters(owner)
	local seen, count = {}, 0
	for _, target in ipairs(collectRecent(owner.hgFightTargets)) do
		for _, ally in ipairs(collectRecent(target.hgFightAttackers, owner)) do
			if not seen[ally] and not hitsMeMore(owner, ally) and ally:GetPos():DistToSqr(owner:GetPos()) <= SUPPORT_RADIUS * SUPPORT_RADIUS then
				seen[ally] = true
				count = count + 1
			end
		end
	end
	return count
end

function hg.organism.GetAdrenalineGainMul(org)
	local owner = org and org.owner
	if not IsValid(owner) or not owner:IsPlayer() then return 1 end
	local now = CurTime()
	local numb = hg.organism.PsycheAdrenalineNumb and hg.organism.PsycheAdrenalineNumb(org) or 1
	numb = numb * (1 + (hg.organism.GetWitnessTrauma and hg.organism.GetWitnessTrauma(org) or 0) * hg.PsycheCombat.noDepressionTraumaMul)
	numb = numb * (hg.organism.GetDespairAdrenalineMul and hg.organism.GetDespairAdrenalineMul(org) or 1)
	if (org._adrGainMulNext or 0) > now then return (org._adrGainMul or 1) * numb end
	org._adrGainMulNext = now + GAIN_MUL_REFRESH

	local balance = countSupporters(owner) - math.max(#collectAttackers(owner) - 1, 0)
	local mul = 1
	if balance > 0 then
		mul = math.max(1 / (1 + SUPPORT_STEP * balance), SUPPORT_FLOOR)
	elseif balance < 0 then
		mul = math.min(1 + OUTNUMBERED_STEP * -balance, OUTNUMBERED_CEIL)
	end
	org._adrGainMul = mul
	return mul * numb
end

local function emotionThought(ply, set, id, context)
	local list = set[1] and set or set[context] or set.solo
	local text = list[math.random(#list)]
	if hg.organism.EmotionThought then
		hg.organism.EmotionThought(ply, text, 5, id)
	else
		ply:Notify(text, 5, id, 0)
	end
end

local function addDepression(org, amount, cause)
	if hg.organism.AddDepression then hg.organism.AddDepression(org, amount, cause) end
end

local function addHappiness(org, amount)
	if hg.organism.AddHappiness then hg.organism.AddHappiness(org, amount) end
end

local function addSurge(org, amount)
	local current = org.adrenalineAdd or 0
	if current < 0 or current >= SURGE_CAP then return end
	org.adrenalineAdd = math.min(current + amount, SURGE_CAP)
end

local function applyRelief(watcher, org, context)
	if (org.epinephrineStabilizationUntil or 0) > CurTime() then return false end
	local hadStress = (org.adrenaline or 0) >= RELIEF_MIN_ADRENALINE or (org.adrenalineAdd or 0) > 0 or org.panicattackActive
	if not hadStress then return false end
	org.adrenalineAdd = math.min(org.adrenalineAdd or 0, 0)
	org._adrenalineHoldUntil = 0
	org._adrenalineReliefUntil = CurTime() + RELIEF_DURATION
	org.panicattackadd = (org.panicattackadd or 0) * RELIEF_PANIC_KEEP
	emotionThought(watcher, PHRASES.relief, "witness_relief", context)
	return true
end

local function canSee(watcher, pos, radius, dot, ignore1, ignore2)
	local eye = watcher:EyePos()
	local distSqr = eye:DistToSqr(pos)
	if distSqr > radius * radius then return false end
	if distSqr > CLOSE_RADIUS * CLOSE_RADIUS and watcher:GetAimVector():Dot((pos - eye):GetNormalized()) < dot then return false end
	local watcherEnt = hg.GetCurrentCharacter(watcher) or watcher
	return not util.TraceLine({
		start = eye,
		endpos = pos,
		filter = {watcher, watcherEnt, ignore1, ignore2},
		mask = MASK_SHOT
	}).Hit
end

local function isStressImmune(watcher, org)
	return watcher.isTraitor or hg.IsPsycheApathetic(watcher) or org.superfighter or (watcher.IsBerserk and watcher:IsBerserk())
end

local function isEndangered(watcher, org, killer)
	if (org.panicGunfightUntil or 0) > CurTime() then return true end
	if #collectAttackers(watcher) > 0 then return true end
	return IsValid(killer) and killer != watcher and isActiveFighter(killer)
		and killer:GetPos():DistToSqr(watcher:GetPos()) <= KILLER_THREAT_RADIUS * KILLER_THREAT_RADIUS
end

local function applyStress(watcher, org, stress, killer, mul, buddy)
	org.fearadd = math.min((org.fearadd or 0) + stress.fear * mul, 3)
	if stress.always or isEndangered(watcher, org, killer) then
		hg.organism.AddPanicAttack(org, stress.panic * mul, true, false, buddy)
	end
	if buddy and stress.depression > 0 then
		addDepression(org, stress.depression, "grief")
	end
end

local function hasTwoActiveTeams()
	local first
	for _, ply in player.Iterator() do
		if ply:Alive() and ply:Team() != TEAM_SPECTATOR then
			if first == nil then
				first = ply:Team()
			elseif ply:Team() != first then
				return true
			end
		end
	end
	return false
end

local function sharesEnemy(a, b)
	for _, side in ipairs({a.hgFightTargets or {}, a.hgFightAttackers or {}}) do
		for enemy in pairs(side) do
			if enemy != b and (wasFighting(b.hgFightTargets, enemy) or wasFighting(b.hgFightAttackers, enemy)) and wasFighting(side, enemy) then
				return true
			end
		end
	end
	return false
end

local function isBuddy(watcher, victim, twoTeams)
	if victim:IsNPC() then return victim:Disposition(watcher) == D_LI end
	if not victim:IsPlayer() then return false end
	if victim.isTraitor then return false end
	if wasFighting(watcher.hgFightTargets, victim) or wasFighting(watcher.hgFightAttackers, victim) then return false end
	if hg.Buddy and hg.Buddy.IsChosen(watcher, victim) then return true end
	if twoTeams and watcher:Team() == victim:Team() then return true end
	return sharesEnemy(watcher, victim)
end

local function isEnemySide(watcher, victim, twoTeams)
	if victim:IsNPC() then return victim:Disposition(watcher) == D_HT end
	return twoTeams and victim:IsPlayer() and watcher:Team() != victim:Team()
end

local function isFriendlyHit(attacker, victim)
	if not attacker:IsPlayer() or not victim:IsPlayer() then return false end
	if attacker.isTraitor or victim.isTraitor or attacker:Team() != victim:Team() then return false end
	if wasFighting(attacker.hgFightAttackers, victim) or wasFighting(attacker.hgFightTargets, victim) then return false end
	return hasTwoActiveTeams()
end

local function onFriendlyFire(attacker)
	local org = attacker.organism
	if not org or not attacker:Alive() or org.otrub then return end
	local now = CurTime()
	if (attacker.hgFriendlyFireNext or 0) > now then return end
	attacker.hgFriendlyFireNext = now + EMO.friendlyFireCooldown
	addDepression(org, EMO.friendlyFireDepression, "guilt")
	emotionThought(attacker, PHRASES.friendlyFire, "emotion_friendly_fire")
end

local function hurtLevel(org)
	local blood = math.Clamp((4500 - (org.blood or 5000)) / 1500, 0, 1)
	local pain = math.Clamp(((org.pain or 0) - 40) / 50, 0, 1)
	local shock = math.Clamp((org.shock or 0) / 50, 0, 1)
	local legs = hg.IsLimbIncapacitated and (hg.IsLimbIncapacitated(org, "lleg") or hg.IsLimbIncapacitated(org, "rleg")) and 0.5 or 0
	return math.max(blood, pain, shock, legs)
end

local function isStressed(org)
	return org.panicattackActive or (org.depression or 0) >= EMO.stressedDepression or (org.hgLosing or 0) > 0 or hurtLevel(org) >= EMO.stressedHurt
end

local function isFistFighting(ply, now)
	local wep = ply:GetActiveWeapon()
	return IsValid(wep) and HANDS[wep:GetClass()] and (ply.hgFistFightTime or 0) > now - FIGHT_WINDOW
end

local function getFightContext(ply, attackers, now)
	if isFistFighting(ply, now) then return "fist" end
	local enemies = {}
	for _, enemy in ipairs(attackers) do enemies[enemy] = true end
	for _, enemy in ipairs(collectRecent(ply.hgFightTargets)) do enemies[enemy] = true end
	local count = table.Count(enemies)
	local allies = countSupporters(ply)
	if count > allies + 1 then return "ganged" end
	if allies > 0 then return "group" end
	return "solo"
end

local function clearLosing(org)
	org.hgLosing = nil
	org.hgMissTries = nil
	org.hgDoomedSaid = nil
	org.hgHopelessSaid = nil
	org.hgBotchSaid = nil
	org.hgFightContext = nil
end

local function updateLosing(ply, org, now)
	local attackers = collectAttackers(ply)
	if #attackers == 0 then
		org.hgMissTries = nil
		org.hgLosing = math.max((org.hgLosing or 0) - EMO.losingInterval * 2, 0)
		if org.hgLosing <= 0 and #collectRecent(ply.hgFightTargets) == 0 then clearLosing(org) end
		return
	end

	local context = getFightContext(ply, attackers, now)
	org.hgFightContext = context

	local landed = 0
	for _, enemy in ipairs(attackers) do
		if wasFighting(ply.hgFightTargets, enemy) then landed = landed + 1 end
	end
	local hurt = hurtLevel(org)
	local outnumbered = math.max(#attackers - 1 - countSupporters(ply), 0)
	local losing = math.Clamp(hurt * 0.6 + (landed == 0 and 0.3 or 0) + outnumbered * 0.2, 0, 1)

	if losing >= EMO.losingStart then
		org.hgLosing = (org.hgLosing or 0) + EMO.losingInterval * losing
		if losing >= EMO.losingBadly or org.panicattackActive then
			addDepression(org, EMO.losingConvertRate * losing * EMO.losingInterval, "fight")
		end
	elseif landed > 0 and hurt < EMO.winningHurt and outnumbered == 0 then
		org.hgLosing = math.max((org.hgLosing or 0) - EMO.losingInterval * 2, 0)
		addHappiness(org, EMO.winningHappiness * EMO.losingInterval)
		if hg.organism.RelieveStress then hg.organism.RelieveStress(org, hg.PsycheCombat.winRelief * EMO.losingInterval) end
	else
		org.hgLosing = math.max((org.hgLosing or 0) - EMO.losingInterval, 0)
	end

	if hurt >= EMO.doomedHurt and losing >= EMO.losingStart and not org.hgDoomedSaid then
		org.hgDoomedSaid = true
		addDepression(org, EMO.doomedDepression, "fight")
		emotionThought(ply, PHRASES.doomed, "emotion_doomed", context)
	elseif (org.hgMissTries or 0) >= EMO.botchTries and (ply.hgLastAttackTry or 0) > now - EMO.botchTryWindow and not org.hgBotchSaid then
		org.hgBotchSaid = true
		addDepression(org, EMO.botchDepression, "fight")
		emotionThought(ply, PHRASES.botch, "emotion_botch", context)
	elseif (org.hgLosing or 0) >= EMO.hopelessTime and (org.panicattackActive or (org.depression or 0) >= 0.25) and not org.hgHopelessSaid then
		org.hgHopelessSaid = true
		addDepression(org, EMO.hopelessDepression, "fight")
		emotionThought(ply, PHRASES.hopeless, "emotion_hopeless", context)
	end
end

local function reactAsFighter(watcher, org, victim, isDeath, victimPos, victimEnt)
	local gangedBy = collectAttackers(watcher, victim)
	if #gangedBy > 0 then
		addSurge(org, SURGE_GANGED_KILL * (isDeath and 1 or 0.6) * hg.organism.GetAdrenalineGainMul(org))
	end
	if not canSee(watcher, victimPos, EMO.fighterSeeRadius, SEE_DOT, victim, victimEnt) then return end
	if hg.organism.RelieveStress then hg.organism.RelieveStress(org, hg.PsycheCombat.killRelief * (isDeath and 1 or 0.6)) end

	downedFighter = victim
	local context = getFightContext(watcher, collectAttackers(watcher), CurTime())
	downedFighter = nil
	local stressed = isStressed(org)
	if #gangedBy > 0 or #collectRecent(watcher.hgFightTargets, victim) > 0 then
		addHappiness(org, EMO.hopeHappiness * (isDeath and 1 or 0.8))
		emotionThought(watcher, stressed and PHRASES.hope or PHRASES.calmDown, "witness_hope", context)
		return
	end

	addHappiness(org, EMO.reliefHappiness * (isDeath and 1 or 0.8))
	if (stressed or wasFighting(watcher.hgFightAttackers, victim)) and not applyRelief(watcher, org, context) then
		emotionThought(watcher, PHRASES.calmDown, "witness_hope", context)
	end
end

local CHANCE_BONES = {"skull", "jaw", "pelvis", "spine1", "spine2", "spine3"}
local CHANCE_LIMBS = {"lleg", "rleg", "larm", "rarm"}

local function countBroken(org)
	local count = 0
	for _, key in ipairs(CHANCE_BONES) do
		if (tonumber(org[key]) or 0) >= 1 then count = count + 1 end
	end
	if hg.IsLimbFractured then
		for _, limb in ipairs(CHANCE_LIMBS) do
			if hg.IsLimbFractured(org, limb) then count = count + 1 end
		end
	end
	return count
end

local function totalPain(org)
	return (org.pain or 0) + (org.painadd or 0) + (org.headpainadd or 0)
end

local function onChance(attacker, victim, set, id)
	if not IsValid(attacker) or not attacker:IsPlayer() or not attacker:Alive() then return end
	local org = attacker.organism
	if not org or org.otrub then return end
	if not wasFighting(attacker.hgFightAttackers, victim) or not isStressed(org) then return end
	local now = CurTime()
	if (attacker.hgChanceNext or 0) > now then return end
	attacker.hgChanceNext = now + EMO.chanceCooldown
	addHappiness(org, EMO.chanceHappiness)
	emotionThought(attacker, set, id, org.hgFightContext)
end

local function checkChance(attacker, victim, painBefore, brokenBefore)
	if not IsValid(attacker) or not IsValid(victim) then return end
	local org = victim.organism
	if not org or org.alive == false or org.otrub then return end
	local pain = totalPain(org)
	if countBroken(org) > brokenBefore or pain - painBefore >= EMO.chancePainJump or (painBefore < EMO.chancePainHigh and pain >= EMO.chancePainHigh) then
		onChance(attacker, victim, PHRASES.chance, "emotion_chance")
	end
end

local function latestAttacker(victim)
	local latest, latestTime
	local cutoff = CurTime() - FIGHT_WINDOW
	for ent, when in pairs(victim.hgFightAttackers or {}) do
		if IsValid(ent) and when >= cutoff and (not latestTime or when > latestTime) then
			latest, latestTime = ent, when
		end
	end
	return latest
end

function hg.organism.GetKillKarmaLoss(killer, victim)
	local harmed = zb and zb.HarmDoneKarma and zb.HarmDoneKarma[victim]
	return harmed and tonumber(harmed[killer]) or 0
end

local function killGuilt(watcher, victim, friendly)
	local loss = hg.organism.GetKillKarmaLoss(watcher, victim)
	local amount = math.Clamp(loss / EMO.karmaKillFull, 0, 1) * EMO.karmaKillDepression
	if friendly then amount = math.max(amount, EMO.friendlyKillDepression) end
	local karma = tonumber(watcher.Karma) or 100
	amount = amount * Lerp(math.Clamp((100 - karma) / 100, 0, 1), 1, 1 + EMO.karmaKillLowMul)
	return amount, loss
end

local function onVictimDown(victim, killer, isDeath)
	if not IsValid(victim) then return end
	if killer == victim then killer = nil end
	killer = IsValid(killer) and killer or latestAttacker(victim)

	local victimOrg = victim.organism
	local stressful = victim:IsPlayer() or victimOrg != nil
	local victimEnt = hg.GetCurrentCharacter(victim) or victim
	if not IsValid(victimEnt) then victimEnt = victim end
	local victimPos = victimEnt:WorldSpaceCenter()
	local radius = isDeath and DEATH_RADIUS or OTRUB_RADIUS
	local stress = isDeath and STRESS.death or STRESS.otrub
	local twoTeams = hasTwoActiveTeams()
	local now = CurTime()
	local witnessed = {}

	for _, watcher in player.Iterator() do
		if watcher == victim or not watcher:Alive() then continue end
		local org = watcher.organism
		if not org or org.otrub then continue end

		watcher.hgWitnessNext = watcher.hgWitnessNext or {}
		if not isDeath and (watcher.hgWitnessNext[victim] or 0) > now then continue end

		if isTreating(watcher, victimOrg) then
			watcher.hgWitnessNext[victim] = now + OTRUB_REPEAT_COOLDOWN
			witnessed[watcher] = true
			continue
		end

		local friendlyKill = watcher == killer and ((victim:IsNPC() and victim:Disposition(watcher) == D_LI) or (victim.hgFriendlyFireBy and (victim.hgFriendlyFireBy[watcher] or 0) > now - FIGHT_WINDOW))
		local guiltAmount, karmaLoss = 0, 0
		if watcher == killer and isDeath then
			guiltAmount, karmaLoss = killGuilt(watcher, victim, friendlyKill)
		end

		if friendlyKill or karmaLoss > 0 then
			watcher.hgWitnessNext[victim] = now + OTRUB_REPEAT_COOLDOWN
			witnessed[watcher] = true
			if isDeath then
				addDepression(org, guiltAmount, "guilt")
				emotionThought(watcher, friendlyKill and PHRASES.friendlyKill or PHRASES.regretKill, "emotion_friendly_kill")
			end
			continue
		end

		if watcher == killer or wasFighting(watcher.hgFightTargets, victim) or wasFighting(watcher.hgFightAttackers, victim) then
			watcher.hgWitnessNext[victim] = now + OTRUB_REPEAT_COOLDOWN
			witnessed[watcher] = true
			reactAsFighter(watcher, org, victim, isDeath, victimPos, victimEnt)
			continue
		end

		if not (stressful or (victim:IsNPC() and victim:Disposition(watcher) == D_LI)) or isStressImmune(watcher, org) then continue end
		if not canSee(watcher, victimPos, radius, SEE_DOT, victim, victimEnt) then continue end

		watcher.hgWitnessNext[victim] = now + OTRUB_REPEAT_COOLDOWN
		witnessed[watcher] = true

		if isBuddy(watcher, victim, twoTeams) then
			addSurge(org, (isDeath and SURGE_BUDDY_DEATH or SURGE_BUDDY_OTRUB) * hg.organism.GetAdrenalineGainMul(org))
			applyStress(watcher, org, stress, killer, BUDDY_MUL, true)
			emotionThought(watcher, isDeath and PHRASES.buddyDeath or PHRASES.buddyDown, "witness_buddy")
		else
			applyStress(watcher, org, stress, killer, 1)
			if isDeath and hg.organism.PsycheWitnessDeath and not isEnemySide(watcher, victim, twoTeams) then hg.organism.PsycheWitnessDeath(watcher, org, victimPos) end
		end
	end

	if isDeath then victim.hgDeathWitnesses = witnessed end
end

hook.Add("EntityTakeDamage", "WitnessStressTrackFight", function(target, dmgInfo)
	if not dmgInfo:IsDamageType(FIGHT_DAMAGE) then return end
	local victim = resolveVictim(target)
	if not victim then return end
	local attacker = resolveFighter(dmgInfo:GetAttacker())
	if not attacker or attacker == victim then return end
	if attacker:IsPlayer() and isTreating(attacker, victim.organism) then return end

	local now = CurTime()
	if isFriendlyHit(attacker, victim) then
		victim.hgFriendlyFireBy = victim.hgFriendlyFireBy or {}
		victim.hgFriendlyFireBy[attacker] = now
		onFriendlyFire(attacker)
		return
	end
	victim.hgFightAttackers = victim.hgFightAttackers or {}
	victim.hgFightAttackers[attacker] = now
	victim.hgHitsFrom = victim.hgHitsFrom or {}
	local rec = victim.hgHitsFrom[attacker]
	if rec and rec.t > now - FIGHT_WINDOW then
		rec.n = rec.n + 1
		rec.t = now
	else
		victim.hgHitsFrom[attacker] = {n = 1, t = now}
	end
	victim.hgLastEnemyHit = attacker
	victim.hgLastEnemyHitTime = now
	local victimOrg = victim.organism
	if attacker:IsPlayer() and victimOrg and not victimOrg.otrub and victimOrg.alive ~= false then
		local painBefore, brokenBefore = totalPain(victimOrg), countBroken(victimOrg)
		timer.Simple(EMO.chanceCheckDelay, function() checkChance(attacker, victim, painBefore, brokenBefore) end)
	end
	attacker.hgFightTargets = attacker.hgFightTargets or {}
	attacker.hgFightTargets[victim] = now
	if attacker.organism then
		attacker.organism.hgMissTries = 0
		attacker.organism.hgBotchSaid = nil
	end
	if dmgInfo:IsDamageType(DMG_CLUB) and attacker:IsPlayer() then
		local wep = attacker:GetActiveWeapon()
		if IsValid(wep) and HANDS[wep:GetClass()] then
			attacker.hgFistFightTime = now
			victim.hgFistFightTime = now
		end
	end
end)

hook.Add("PlayerDeath", "WitnessStressDeath", function(victim, _, attacker)
	onVictimDown(victim, resolveFighter(attacker), true)
end)

hook.Add("OnNPCKilled", "WitnessStressNPCDeath", function(victim, attacker)
	onVictimDown(victim, resolveFighter(attacker), true)
end)

hook.Add("HG_OnOtrub", "WitnessStressOtrub", function(victim)
	onVictimDown(victim, nil, false)
end)

hook.Add("RagdollDeath", "WitnessStressCorpseMemory", function(ply, ragdoll)
	ragdoll.hgDeathWitnesses = ply.hgDeathWitnesses
	ply.hgDeathWitnesses = nil
end)

hook.Add("PlayerSpawn", "WitnessStressReset", function(ply)
	ply.hgFightAttackers = nil
	ply.hgFightTargets = nil
	ply.hgHitsFrom = nil
	ply.hgWitnessNext = nil
	ply.hgSeenCorpses = nil
	ply.hgSeenCorpseCount = nil
	ply.hgFriendlyFireBy = nil
	ply.hgFriendlyFireNext = nil
	ply.hgLastEnemyHit = nil
	ply.hgLastEnemyHitTime = nil
	ply.hgChanceNext = nil
	ply.hgFistFightTime = nil
	if ply.organism then clearLosing(ply.organism) end
end)

hook.Add("PlayerDroppedWeapon", "WitnessStressDisarm", function(ply, wep)
	if not IsValid(ply) or not ply:Alive() or not IsValid(wep) or wep:GetClass() == "weapon_hands_sh" or wep:GetClass() == "weapon_hg_coolhands" then return end
	if (ply.hgLastEnemyHitTime or 0) < CurTime() - EMO.disarmWindow then return end
	local attacker = ply.hgLastEnemyHit
	if attacker == ply then return end
	onChance(attacker, ply, PHRASES.disarm, "emotion_disarm")
end)

hook.Add("KeyPress", "WitnessStressFightBack", function(ply, key)
	if key ~= IN_ATTACK then return end
	local now = CurTime()
	local org = ply.organism
	if org then
		if (ply.hgLastAttackTry or 0) < now - EMO.botchTryWindow then org.hgMissTries = 0 end
		org.hgMissTries = (org.hgMissTries or 0) + 1
	end
	ply.hgLastAttackTry = now
end)

timer.Create("WitnessStressLosing", EMO.losingInterval, 0, function()
	local now = CurTime()
	for _, ply in player.Iterator() do
		local org = ply.organism
		if not ply:Alive() or not org or org.otrub or isStressImmune(ply, org) then continue end
		updateLosing(ply, org, now)
	end
end)

timer.Create("WitnessStressCorpses", CORPSE_INTERVAL, 0, function()
	local corpses = {}
	for owner, org in pairs(hg.organism.list) do
		if IsValid(owner) and org.alive == false and owner:IsRagdoll() then
			corpses[#corpses + 1] = owner
		end
	end
	if #corpses == 0 then return end

	for _, watcher in player.Iterator() do
		if not watcher:Alive() then continue end
		local org = watcher.organism
		if not org or org.otrub or isStressImmune(watcher, org) then continue end
		if (org.panicGunfightUntil or 0) > CurTime() then continue end

		watcher.hgSeenCorpses = watcher.hgSeenCorpses or {}
		for _, corpse in ipairs(corpses) do
			if watcher.hgSeenCorpses[corpse] then continue end
			if corpse.hgDeathWitnesses and corpse.hgDeathWitnesses[watcher] then
				watcher.hgSeenCorpses[corpse] = true
				continue
			end
			if isTreating(watcher, corpse.organism) then
				watcher.hgSeenCorpses[corpse] = true
				continue
			end
			if canSee(watcher, corpse:WorldSpaceCenter(), CORPSE_RADIUS, CORPSE_SEE_DOT, corpse) then
				watcher.hgSeenCorpses[corpse] = true
				watcher.hgSeenCorpseCount = (watcher.hgSeenCorpseCount or 0) + 1
				applyStress(watcher, org, STRESS.corpse, nil, 1 / watcher.hgSeenCorpseCount)
				if hg.organism.PsycheSeeCorpse then hg.organism.PsycheSeeCorpse(watcher, org, 1 / watcher.hgSeenCorpseCount) end
			end
		end
	end
end)
