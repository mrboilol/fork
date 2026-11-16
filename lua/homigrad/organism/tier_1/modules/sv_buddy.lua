hg.Buddy = hg.Buddy or {}
local B = hg.Buddy

B.Config = {
	thinkInterval = 1,
	nearRadius = 600,
	moodResist = 0.5,
	happinessMul = 1.75,
	happinessRate = 0.003,
	hearMul = 2,
	healHappiness = 0.15,
	healCooldown = 4,
	teamPairChance = 0.75,
	combatWindow = 15,
}

local HEAL_THOUGHTS = {
	"They're patching me up... I'm not alone.",
	"Thank god they're here...",
	"I feel a little better with them here.",
}

local twoTeamsCache, twoTeamsAt = false, 0

local function twoTeams()
	local now = CurTime()
	if now < twoTeamsAt then return twoTeamsCache end
	twoTeamsAt = now + 1
	twoTeamsCache = false

	local first
	for _, ply in player.Iterator() do
		if not ply:Alive() or ply:Team() == TEAM_SPECTATOR then continue end
		if first == nil then
			first = ply:Team()
		elseif ply:Team() ~= first then
			twoTeamsCache = true
			break
		end
	end

	return twoTeamsCache
end

function B.Choice(ply)
	local sid = ply:GetInfo("hg_buddy")
	if not sid or sid == "" then return nil end

	for _, other in player.Iterator() do
		if other ~= ply and other:SteamID64() == sid then return other end
	end
end

function B.Refresh(ply)
	ply.hgBuddyEnt = B.Choice(ply)
	return ply.hgBuddyEnt
end

function B.IsChosen(a, b)
	if a == b or not IsValid(a) or not IsValid(b) or not a:IsPlayer() or not b:IsPlayer() then return false end
	if a.hgBuddyEnt ~= b and b.hgBuddyEnt ~= a then return false end

	return not (twoTeams() and a:Team() ~= b:Team())
end

local function inCombat(ply, org, now)
	return (org.panicGunfightUntil or 0) > now or (org.hgLosing or 0) > 0 or (ply.hgLastEnemyHitTime or 0) > now - B.Config.combatWindow
end

local function thinkPlayer(ply, now)
	local C = B.Config
	local org = ply.organism
	local buddy = B.Refresh(ply)
	if IsValid(buddy) and not B.IsChosen(ply, buddy) then buddy = nil end
	if not IsValid(buddy) then
		for _, other in player.Iterator() do
			if other ~= ply and other.hgBuddyEnt == ply and B.IsChosen(ply, other) then
				buddy = other
				break
			end
		end
	end

	ply:SetNWEntity("hg_buddy", IsValid(buddy) and buddy or NULL)
	ply:SetNWBool("hg_buddycombat", org and ply:Alive() and inCombat(ply, org, now) or false)
	if not org then return end

	local near = IsValid(buddy) and buddy:Alive() and ply:Alive() and not org.otrub and buddy:GetPos():DistToSqr(ply:GetPos()) <= C.nearRadius * C.nearRadius
	org.buddyNear = near or nil

	if near and org.alive and hg.organism.AddHappiness then
		hg.organism.AddHappiness(org, C.happinessRate * C.thinkInterval)
	end
end

timer.Create("HG_BuddyThink", B.Config.thinkInterval, 0, function()
	local now = CurTime()
	for _, ply in player.Iterator() do
		if IsValid(ply) and ply:IsPlayer() then thinkPlayer(ply, now) end
	end
end)

local function canSpeak(speaker)
	local org = speaker.organism
	if not speaker:Alive() or not org or org.otrub or org.holdingbreath or org.neckslit or org.seizureActive then return false end

	return (tonumber(org.brain) or 0) <= 0.05
end

hook.Add("CanListenOthers", "HG_BuddyHearing", function(speaker, listener)
	if not IsValid(speaker) or not IsValid(listener) or not B.IsChosen(speaker, listener) then return end
	if not canSpeak(speaker) or not listener:Alive() then return end
	if listener.organism and listener.organism.otrub then return end

	local reach = 3000 * B.Config.hearMul
	if speaker:GetPos():DistToSqr(listener:GetPos()) > reach * reach then return end

	return true, true
end)

hook.Add("HG_HealedOther", "HG_BuddyHealMood", function(healer, target)
	target = (hg.RagdollOwner and hg.RagdollOwner(target)) or target
	if not IsValid(target) or not target:IsPlayer() or not B.IsChosen(target, healer) then return end

	local org = target.organism
	local now = CurTime()
	if not org or org.otrub or (target.hgBuddyHealNext or 0) > now then return end
	target.hgBuddyHealNext = now + B.Config.healCooldown

	hg.organism.AddHappiness(org, B.Config.healHappiness)
	if hg.organism.EmotionThought then
		hg.organism.EmotionThought(target, HEAL_THOUGHTS[math.random(#HEAL_THOUGHTS)], 5, "buddy_heal")
	end
end)

function B.BiasTeams()
	local C = B.Config
	local paired = {}
	local pool = {}

	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then pool[#pool + 1] = ply end
		B.Refresh(ply)
	end

	for _, ply in RandomPairs(pool) do
		local buddy = ply.hgBuddyEnt
		if not IsValid(buddy) or buddy:Team() == TEAM_SPECTATOR or paired[ply] or paired[buddy] then continue end
		paired[ply], paired[buddy] = true, true
		if ply:Team() == buddy:Team() or math.Rand(0, 1) > C.teamPairChance then continue end

		local swap
		for _, other in RandomPairs(pool) do
			if other:Team() == ply:Team() and not paired[other] and other ~= ply then
				swap = other
				break
			end
		end
		if not swap then continue end

		local buddyTeam = buddy:Team()
		buddy:SetTeam(ply:Team())
		swap:SetTeam(buddyTeam)
		paired[swap] = true
	end
end
