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
	death = {panic = 0.35, depression = 0.06, fear = 0.5},
	otrub = {panic = 0.16, depression = 0.02, fear = 0.3},
	corpse = {panic = 0.08, depression = 0.025, fear = 0.15},
}
local BUDDY_MUL = 2

local FIGHT_DAMAGE = DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST + DMG_SLASH + DMG_CLUB

local EMO = {
	reliefHappiness = 0.35,
	hopeHappiness = 0.15,
	hopeDepressionMin = 0.15,
	buddyDeathDepression = 0.15,
	friendlyFireDepression = 0.12,
	friendlyKillDepression = 0.35,
	friendlyFireCooldown = 8,
	losingInterval = 1,
	losingStart = 0.3,
	losingConvertRate = 0.012,
	hopelessTime = 20,
	hopelessDepression = 0.2,
	doomedHurt = 0.7,
	doomedDepression = 0.08,
	botchTime = 10,
	botchTryWindow = 3,
	botchDepression = 0.06,
}

local PHRASES = {
	buddyDeath = {"DID I JUST SEE MY TEAMMATE DIE?", "NO. NO. THEY'RE DEAD. THEY'RE ACTUALLY DEAD.", "They were right next to me... and now they're gone."},
	friendlyFire = {"DID I REALLY JUST SHOOT MY OWN TEAMMATE?", "OH GOD, THAT WAS ONE OF OURS!", "No no no, I hit my own guy!"},
	friendlyKill = {"I KILLED THEM. I KILLED MY OWN TEAMMATE.", "What have I done... they were on my side...", "That's on me. I killed them."},
	hope = {"WE HAVE A CHANCE!", "One down! We can do this!", "They can be beaten... keep going!"},
	doomed = {"THEY'RE GOING TO KILL ME.", "I'm hit bad... they're going to finish me...", "I can't take another one... they're going to kill me..."},
	hopeless = {"Holy shit I'm going to die... this is hopeless...", "There's too many... I'm not getting out of this...", "This is it. This is how I die."},
	botch = {"I can't hit them... I can't hit ANYTHING.", "Why won't they go down?!", "I keep missing... I keep fucking missing..."},
}

local relief_phrases = {"It's over.", "They're down. I'm okay.", "That's it... breathe.", "Done. It's done."}
local buddy_phrases = {"No... no, no, no.", "Oh god, not them!", "Shit, they're down!"}
local ganged_phrases = {"There's still more of them!", "One down, keep moving!", "Not done yet!"}

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

local function isActiveFighter(ent)
	if not IsValid(ent) then return false end
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

local function countSupporters(owner)
	local seen, count = {}, 0
	for _, target in ipairs(collectRecent(owner.hgFightTargets)) do
		for _, ally in ipairs(collectRecent(target.hgFightAttackers, owner)) do
			if not seen[ally] and ally:GetPos():DistToSqr(owner:GetPos()) <= SUPPORT_RADIUS * SUPPORT_RADIUS then
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
	if (org._adrGainMulNext or 0) > now then return org._adrGainMul or 1 end
	org._adrGainMulNext = now + GAIN_MUL_REFRESH

	local balance = countSupporters(owner) - math.max(#collectRecent(owner.hgFightAttackers) - 1, 0)
	local mul = 1
	if balance > 0 then
		mul = math.max(1 / (1 + SUPPORT_STEP * balance), SUPPORT_FLOOR)
	elseif balance < 0 then
		mul = math.min(1 + OUTNUMBERED_STEP * -balance, OUTNUMBERED_CEIL)
	end
	org._adrGainMul = mul
	return mul
end

local function emotionThought(ply, list, id)
	if hg.organism.EmotionThought then
		hg.organism.EmotionThought(ply, list[math.random(#list)], 5, id)
	else
		ply:Notify(list[math.random(#list)], 5, id, 0)
	end
end

local function addDepression(org, amount)
	if hg.organism.AddDepression then hg.organism.AddDepression(org, amount) end
end

local function addHappiness(org, amount)
	if hg.organism.AddHappiness then hg.organism.AddHappiness(org, amount) end
end

local function addSurge(org, amount)
	local current = org.adrenalineAdd or 0
	if current < 0 or current >= SURGE_CAP then return end
	org.adrenalineAdd = math.min(current + amount, SURGE_CAP)
end

local function applyRelief(watcher, org)
	addHappiness(org, EMO.reliefHappiness)
	if (org.epinephrineStabilizationUntil or 0) > CurTime() then return end
	local hadStress = (org.adrenaline or 0) >= RELIEF_MIN_ADRENALINE or (org.adrenalineAdd or 0) > 0 or org.panicattackActive
	if not hadStress then return end
	org.adrenalineAdd = math.min(org.adrenalineAdd or 0, 0)
	org._adrenalineHoldUntil = 0
	org._adrenalineReliefUntil = CurTime() + RELIEF_DURATION
	org.panicattackadd = (org.panicattackadd or 0) * RELIEF_PANIC_KEEP
	watcher:Notify(relief_phrases[math.random(#relief_phrases)], 4, "witness_relief", 0)
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
	return watcher.isTraitor or org.superfighter or (watcher.IsBerserk and watcher:IsBerserk())
end

local function isEndangered(watcher, org, killer)
	if (org.panicGunfightUntil or 0) > CurTime() then return true end
	if #collectRecent(watcher.hgFightAttackers) > 0 then return true end
	return IsValid(killer) and killer != watcher and isActiveFighter(killer)
		and killer:GetPos():DistToSqr(watcher:GetPos()) <= KILLER_THREAT_RADIUS * KILLER_THREAT_RADIUS
end

local function applyStress(watcher, org, stress, killer, mul)
	org.fearadd = math.min((org.fearadd or 0) + stress.fear * mul, 3)
	if isEndangered(watcher, org, killer) then
		hg.organism.AddPanicAttack(org, stress.panic * mul, true, false, mul > 1)
	elseif hg.organism.AddDepression then
		hg.organism.AddDepression(org, stress.depression * mul)
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
	if not victim:IsPlayer() then return false end
	if victim.isTraitor then return false end
	if wasFighting(watcher.hgFightTargets, victim) or wasFighting(watcher.hgFightAttackers, victim) then return false end
	if twoTeams and watcher:Team() == victim:Team() then return true end
	return sharesEnemy(watcher, victim)
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
	addDepression(org, EMO.friendlyFireDepression)
	emotionThought(attacker, PHRASES.friendlyFire, "emotion_friendly_fire")
end

local function hurtLevel(org)
	local blood = math.Clamp((4500 - (org.blood or 5000)) / 1500, 0, 1)
	local pain = math.Clamp(((org.pain or 0) - 40) / 50, 0, 1)
	local shock = math.Clamp((org.shock or 0) / 50, 0, 1)
	local legs = hg.IsLimbIncapacitated and (hg.IsLimbIncapacitated(org, "lleg") or hg.IsLimbIncapacitated(org, "rleg")) and 0.5 or 0
	return math.max(blood, pain, shock, legs)
end

local function clearLosing(org)
	org.hgLosing = nil
	org.hgNoHitSince = nil
	org.hgDoomedSaid = nil
	org.hgHopelessSaid = nil
	org.hgBotchSaid = nil
end

local function updateLosing(ply, org, now)
	local attackers = collectRecent(ply.hgFightAttackers)
	if #attackers == 0 then
		org.hgNoHitSince = nil
		org.hgLosing = math.max((org.hgLosing or 0) - EMO.losingInterval * 2, 0)
		if org.hgLosing <= 0 then clearLosing(org) end
		return
	end

	local landed = 0
	for _, enemy in ipairs(attackers) do
		if wasFighting(ply.hgFightTargets, enemy) then landed = landed + 1 end
	end
	local hurt = hurtLevel(org)
	local outnumbered = math.max(#attackers - 1 - countSupporters(ply), 0)
	local losing = math.Clamp(hurt * 0.6 + (landed == 0 and 0.3 or 0) + outnumbered * 0.2, 0, 1)

	if landed > 0 then
		org.hgNoHitSince = nil
	elseif (ply.hgLastAttackTry or 0) > now - EMO.botchTryWindow then
		org.hgNoHitSince = org.hgNoHitSince or now
	end

	if losing >= EMO.losingStart then
		org.hgLosing = (org.hgLosing or 0) + EMO.losingInterval * losing
		if org.panicattackActive then
			addDepression(org, EMO.losingConvertRate * losing * EMO.losingInterval)
		end
	else
		org.hgLosing = math.max((org.hgLosing or 0) - EMO.losingInterval, 0)
	end

	if hurt >= EMO.doomedHurt and not org.hgDoomedSaid then
		org.hgDoomedSaid = true
		addDepression(org, EMO.doomedDepression)
		emotionThought(ply, PHRASES.doomed, "emotion_doomed")
	elseif org.hgNoHitSince and now - org.hgNoHitSince >= EMO.botchTime and not org.hgBotchSaid then
		org.hgBotchSaid = true
		addDepression(org, EMO.botchDepression)
		emotionThought(ply, PHRASES.botch, "emotion_botch")
	elseif org.panicattackActive and org.hgLosing >= EMO.hopelessTime and not org.hgHopelessSaid then
		org.hgHopelessSaid = true
		addDepression(org, EMO.hopelessDepression)
		emotionThought(ply, PHRASES.hopeless, "emotion_hopeless")
	end
end

local function reactAsFighter(watcher, org, victim, isDeath)
	local gangedBy = collectRecent(watcher.hgFightAttackers, victim)
	if #gangedBy > 0 then
		addSurge(org, SURGE_GANGED_KILL * (isDeath and 1 or 0.6) * hg.organism.GetAdrenalineGainMul(org))
		if (org.depression or 0) >= EMO.hopeDepressionMin then
			addHappiness(org, EMO.hopeHappiness * (isDeath and 1 or 0.6))
			emotionThought(watcher, PHRASES.hope, "witness_hope")
		else
			watcher:Notify(ganged_phrases[math.random(#ganged_phrases)], 3, "witness_ganged", 0)
		end
		return
	end
	if #collectRecent(watcher.hgFightTargets, victim) > 0 then return end
	applyRelief(watcher, org)
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

		if watcher == killer and victim.hgFriendlyFireBy and (victim.hgFriendlyFireBy[watcher] or 0) > now - FIGHT_WINDOW then
			watcher.hgWitnessNext[victim] = now + OTRUB_REPEAT_COOLDOWN
			witnessed[watcher] = true
			if isDeath then
				addDepression(org, EMO.friendlyKillDepression)
				emotionThought(watcher, PHRASES.friendlyKill, "emotion_friendly_kill")
			end
			continue
		end

		if watcher == killer or wasFighting(watcher.hgFightTargets, victim) or wasFighting(watcher.hgFightAttackers, victim) then
			watcher.hgWitnessNext[victim] = now + OTRUB_REPEAT_COOLDOWN
			witnessed[watcher] = true
			reactAsFighter(watcher, org, victim, isDeath)
			continue
		end

		if not stressful or isStressImmune(watcher, org) then continue end
		if not canSee(watcher, victimPos, radius, SEE_DOT, victim, victimEnt) then continue end

		watcher.hgWitnessNext[victim] = now + OTRUB_REPEAT_COOLDOWN
		witnessed[watcher] = true

		if isBuddy(watcher, victim, twoTeams) then
			addSurge(org, (isDeath and SURGE_BUDDY_DEATH or SURGE_BUDDY_OTRUB) * hg.organism.GetAdrenalineGainMul(org))
			applyStress(watcher, org, stress, killer, BUDDY_MUL)
			if isDeath then
				addDepression(org, EMO.buddyDeathDepression)
				emotionThought(watcher, PHRASES.buddyDeath, "witness_buddy")
			else
				watcher:Notify(buddy_phrases[math.random(#buddy_phrases)], 3, "witness_buddy", 0)
			end
		else
			applyStress(watcher, org, stress, killer, 1)
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
	attacker.hgFightTargets = attacker.hgFightTargets or {}
	attacker.hgFightTargets[victim] = now
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
	ply.hgWitnessNext = nil
	ply.hgSeenCorpses = nil
	ply.hgSeenCorpseCount = nil
	ply.hgFriendlyFireBy = nil
	ply.hgFriendlyFireNext = nil
	if ply.organism then clearLosing(ply.organism) end
end)

hook.Add("KeyPress", "WitnessStressFightBack", function(ply, key)
	if key == IN_ATTACK then ply.hgLastAttackTry = CurTime() end
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
			end
		end
	end
end)
