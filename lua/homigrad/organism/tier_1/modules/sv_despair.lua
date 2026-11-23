local Clamp, max, min, Approach = math.Clamp, math.max, math.min, math.Approach

local K = {
	interval = 1,
	fightWindow = 15,
	companyRadius = 700,
	hiddenMul = 0.35,

	hopelessDying = 0.25,
	hopelessFull = 0.75,
	oneCompanionMul = 0.35,
	hopelessRise = 1 / 35,
	hopelessFall = 1 / 20,

	losingFull = 25,
	teamLosingMul = 0.85,
	fewMatesLevel = 0.45,
	outOfFightTeamMul = 0.6,
	desolationRise = 1 / 30,
	desolationFall = 1 / 50,

	suicidalStart = 0.2,
	suicidalRise = 1 / 50,
	suicidalFall = 1 / 70,

	hopeDepression = 0.012,
	desolationDepression = 0.006,
	hopeHeartStrain = 1 / 140,
	hopeArrhythmia = 0.004,
	suicidalHeart = 0.5,
	desolationAdrenaline = 0.65,
	suicidalAdrenaline = 0.5,
	adrenalineFloor = 0.15,
	suicidalSuccumb = 0.35,
	hopeSuccumb = 0.1,

	stages = {0.3, 0.55, 0.8},
	thoughtCooldown = 25,
}
hg.organism.DespairConfig = K

local THOUGHTS = {
	hopelessness = {
		{"Where is everyone...?", "Is anyone there? Anyone?", "Nobody's coming, are they..."},
		{"I'm going to die here alone.", "Nobody even knows I'm here...", "Please... someone... anyone..."},
		{"No one's coming. No one was ever coming.", "I'm dying and there's nobody here.", "My heart... it's slowing down..."},
	},
	desolation = {
		{"We're losing this...", "This isn't going well...", "Where did everyone go?"},
		{"We're not getting out of this.", "They're everywhere... we're done.", "I can't stop shaking..."},
		{"I'm going to die here. I know it.", "It's over. It's all over.", "There's nobody left on our side..."},
	},
	suicidal = {
		{"What's even the point anymore...", "Maybe it's better if it just ends.", "I don't care anymore."},
		{"Just get it over with...", "I don't want to feel this anymore.", "Let it end. Please."},
		{"Make it quick. Just make it quick.", "I'm done. I just want it over.", "Why won't it just end already..."},
	},
}

local FIELDS = {"hopelessness", "desolation", "suicidal"}

local function depressionOn()
	local cvar = GetConVar("hg_depression")
	return not cvar or cvar:GetBool()
end

local function isImmune(ply)
	return ply.HasTrait and ply:HasTrait("apathetic")
end

local function clearDespair(org)
	org.hopelessness = 0
	org.desolation = 0
	org.suicidal = 0
	org.despairHeart = 0
	org.despairShake = 0
	org.despairSuccumb = 0
	org.despairAdrenalineMul = 1
	org.despairStage = nil
	org.despairNextThought = nil
end

hook.Add("Org Clear", "HG_Despair", clearDespair)

function hg.organism.GetDespairAdrenalineMul(org)
	return org and org.despairAdrenalineMul or 1
end

local function recent(tbl, ent, now)
	return tbl and (tbl[ent] or 0) > now - K.fightWindow
end

local function isEnemy(ply, other, twoTeams, now)
	if recent(ply.hgFightAttackers, other, now) or recent(ply.hgFightTargets, other, now) then return true end
	return twoTeams and other:Team() ~= ply:Team()
end

local function countCompany(ply, pos, twoTeams, now)
	local r2 = K.companyRadius * K.companyRadius
	local count = 0
	for _, other in player.Iterator() do
		if other == ply or not other:Alive() or other:Team() == TEAM_SPECTATOR then continue end
		if isEnemy(ply, other, twoTeams, now) then continue end
		local otherOrg = other.organism
		if otherOrg and otherOrg.otrub then continue end
		local char = hg.GetCurrentCharacter(other) or other
		if char:GetPos():DistToSqr(pos) <= r2 then count = count + 1 end
	end
	for _, ent in ipairs(ents.FindInSphere(pos, K.companyRadius)) do
		if ent:IsNPC() and ent:Health() > 0 and ent:Disposition(ply) == D_LI then count = count + 1 end
	end
	return count
end

local function teamStanding(ply, counts, twoTeams)
	if not twoTeams then return 0 end
	local mine = max(counts[ply:Team()] or 1, 1)
	local enemy = 0
	for team, n in pairs(counts) do
		if team ~= ply:Team() then enemy = max(enemy, n) end
	end
	local standing = enemy > mine and (enemy - mine) / enemy * K.teamLosingMul or 0
	if mine <= 2 and enemy >= 2 then standing = max(standing, K.fewMatesLevel) end
	return standing
end

local function getStage(value)
	for i = #K.stages, 1, -1 do
		if value >= K.stages[i] then return i end
	end
	return 0
end

local function updateThoughts(ply, org, now)
	local best, bestValue = nil, 0
	for _, field in ipairs(FIELDS) do
		local value = org[field] or 0
		if value >= bestValue then best, bestValue = field, value end
	end
	org.despairStage = org.despairStage or {}
	for _, field in ipairs(FIELDS) do
		local stage = getStage(org[field] or 0)
		if stage < (org.despairStage[field] or 0) then org.despairStage[field] = stage end
	end
	if not best or org.otrub then return end
	local stage = getStage(bestValue)
	if stage == 0 or stage <= (org.despairStage[best] or 0) or now < (org.despairNextThought or 0) then return end
	org.despairStage[best] = stage
	org.despairNextThought = now + K.thoughtCooldown
	local pool = THOUGHTS[best][stage]
	if hg.organism.EmotionThought then
		hg.organism.EmotionThought(ply, pool[math.random(#pool)], 6, "despair_" .. best)
	end
end

local function updatePlayer(ply, org, counts, twoTeams, now)
	local dt = K.interval
	local gameplay = depressionOn() and 1 or K.hiddenMul
	local dying = hg.organism.GetDyingLevel and hg.organism.GetDyingLevel(org) or 0

	if not org.otrub then
		local char = hg.GetCurrentCharacter(ply) or ply
		local company = countCompany(ply, char:GetPos(), twoTeams, now)
		local alone = company == 0 and 1 or company == 1 and K.oneCompanionMul or 0
		local hopeTarget = Clamp((dying - K.hopelessDying) / (K.hopelessFull - K.hopelessDying), 0, 1) * alone
		local hope = org.hopelessness or 0
		org.hopelessness = Approach(hope, hopeTarget, dt * (hopeTarget > hope and K.hopelessRise or K.hopelessFall))

		local inFight = (org.panicGunfightUntil or 0) > now or (org.hgLosing or 0) > 0
		local losing = Clamp((org.hgLosing or 0) / K.losingFull, 0, 1)
		local team = teamStanding(ply, counts, twoTeams) * (inFight and 1 or K.outOfFightTeamMul)
		local desoTarget = max(losing, team)
		local deso = org.desolation or 0
		org.desolation = Approach(deso, desoTarget, dt * (desoTarget > deso and K.desolationRise or K.desolationFall))

		local h, d = org.hopelessness, org.desolation
		local suicidalTarget = Clamp(max(min(h, d) * 1.3, (max(h, d) - 0.55) * 2), 0, 1) * Lerp(Clamp(org.depression or 0, 0, 1), 0.7, 1)
		if suicidalTarget < K.suicidalStart then suicidalTarget = 0 end
		local s = org.suicidal or 0
		org.suicidal = Approach(s, suicidalTarget, dt * (suicidalTarget > s and K.suicidalRise or K.suicidalFall))
	end

	local h, d, s = org.hopelessness or 0, org.desolation or 0, org.suicidal or 0
	org.despairHeart = Clamp((h + s * K.suicidalHeart) * gameplay, 0, 1)
	org.despairShake = d * gameplay
	org.despairSuccumb = (s * K.suicidalSuccumb + h * K.hopeSuccumb) * gameplay
	org.despairAdrenalineMul = max(1 - (d * K.desolationAdrenaline + s * K.suicidalAdrenaline) * gameplay, K.adrenalineFloor)

	if hg.organism.AddDepression then
		if h > 0 then hg.organism.AddDepression(org, h * K.hopeDepression * gameplay * dt, "dying") end
		if d > 0 then hg.organism.AddDepression(org, d * K.desolationDepression * gameplay * dt) end
	end
	if h > 0 and dying > 0 and not org.heartstop then
		local load = h * dying * gameplay * dt
		org.heartStrain = Clamp((org.heartStrain or 0) + load * K.hopeHeartStrain, 0, 1)
		org.arrhythmia = Clamp((org.arrhythmia or 0) + load * K.hopeArrhythmia, 0, 1)
	end

	updateThoughts(ply, org, now)
end

timer.Create("HG_Despair", K.interval, 0, function()
	local now = CurTime()
	local counts, teams = {}, 0
	for _, ply in player.Iterator() do
		if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
			local team = ply:Team()
			if not counts[team] then teams = teams + 1 end
			counts[team] = (counts[team] or 0) + 1
		end
	end
	local twoTeams = teams >= 2

	for _, ply in player.Iterator() do
		local org = ply.organism
		if not org then continue end
		if not ply:Alive() or not org.alive or isImmune(ply) then
			if (org.hopelessness or 0) > 0 or (org.desolation or 0) > 0 or (org.suicidal or 0) > 0 then clearDespair(org) end
			continue
		end
		updatePlayer(ply, org, counts, twoTeams, now)
	end
end)
