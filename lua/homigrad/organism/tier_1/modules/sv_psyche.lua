local Clamp = math.Clamp

hg.organism.module.psyche = {}
local module = hg.organism.module.psyche

local combat_response_cooldown = 0.35
local gunfight_response_cooldown = 1.5
local gunfight_adrenaline_cap = 1.5

module[1] = function(org)
	org.psycheAnger = 0
	org.psycheAngerLastHit = 0
	org.psychePainMul = 1
end

module[2] = function(owner, org, timeValue)
	local anger = Clamp(org.anger or 0, 0, 1)
	org.psycheAnger = anger
	org.psychePainMul = 1

	local K = hg.PsycheCombat
	local mood = Clamp(tonumber(org.goodmood) or 0, 0, 1)
	local peak = org.moodPeak or mood
	peak = mood >= peak and mood or math.max(peak - timeValue / K.moodPeakMemory, mood)
	org.moodPeak = peak

	local dep = Clamp(tonumber(org.depression) or 0, 0, 1)
	local depMem = org.depressionMemory or 0
	depMem = dep >= depMem and dep or math.max(depMem - timeValue / K.depressionMemoryTime, dep)
	org.depressionMemory = depMem
end

function hg.organism.GetFightLean(org)
	local K = hg.PsycheCombat
	local peak = Clamp(tonumber(org.moodPeak) or tonumber(org.goodmood) or 0, 0, 1)
	local depMem = Clamp(tonumber(org.depressionMemory) or 0, 0, 1)

	return Clamp(K.leanBase + peak * K.leanMood - depMem * K.leanDepression, K.leanMin, K.leanMax)
end

local function getCombatPlayer(ent)
	if not IsValid(ent) then return end
	if ent:IsPlayer() then return ent end
	local owner = hg.RagdollOwner and hg.RagdollOwner(ent)
	return IsValid(owner) and owner:IsPlayer() and owner or nil
end

local function getOpponent(ent)
	local ply = getCombatPlayer(ent)
	if ply then return ply end
	if IsValid(ent) and ent:IsNPC() then return ent end
end

local function isFriendlyNPC(ent, watcher)
	return IsValid(ent) and ent:IsNPC() and IsValid(watcher) and ent:Disposition(watcher) == D_LI
end

local function addCombatResponse(org, angerAmount, adrenalineAmount, opponent)
	if not org or not hg.organism.RileAnger then return end
	local now = CurTime()
	if (org._combatResponseNext or 0) > now then
		if IsValid(opponent) and (opponent:IsPlayer() or opponent:IsNPC()) then
			org.angerOpponent = opponent
			org.angerOpponentUntil = now + 45
		end
		return
	end
	org._combatResponseNext = now + combat_response_cooldown
	hg.organism.RileAnger(org, angerAmount, adrenalineAmount, opponent)
end

local function triggerCombatResponses(target, dmgInfo)
	local bullet = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
	local inflictor = dmgInfo:GetInflictor()
	local inflictorClass = IsValid(inflictor) and inflictor:GetClass() or ""
	local inflictorBase = IsValid(inflictor) and inflictor.Base or ""
	local melee = dmgInfo:IsDamageType(DMG_CLUB + DMG_SLASH)
		or (IsValid(inflictor) and inflictor.ismelee2)
		or inflictorBase == "weapon_melee"
		or inflictorClass == "weapon_melee"
	local blast = dmgInfo:IsDamageType(DMG_BLAST)
	if not bullet and not melee and not blast then return end

	local targetPlayer = getCombatPlayer(target)
	local attackerPlayer = getCombatPlayer(dmgInfo:GetAttacker())
	if targetPlayer and attackerPlayer == targetPlayer then return end
	if not targetPlayer and not attackerPlayer then return end

	local severity = Clamp((tonumber(dmgInfo:GetDamage()) or 0) / 40, 0.25, 1)
	local attackerAnger, attackerAdrenaline = 0.08, 0.18
	local victimAnger, victimAdrenaline = 0.16, 0.5
	if melee then
		attackerAnger, attackerAdrenaline = 0.14, 0.25
		victimAnger, victimAdrenaline = 0.2, 0.35
	elseif blast then
		attackerAnger, attackerAdrenaline = 0.08, 0.25
		victimAnger, victimAdrenaline = 0.18, 0.65
	end

	if IsValid(attackerPlayer) and not isFriendlyNPC(target, attackerPlayer) then
		addCombatResponse(attackerPlayer.organism, attackerAnger * severity, attackerAdrenaline * severity, getOpponent(target))
		if hg.organism.CombatSuccess then hg.organism.CombatSuccess(attackerPlayer.organism, hg.PsycheCombat.hitRelief * severity) end
	end
	if IsValid(targetPlayer) and IsValid(dmgInfo:GetAttacker()) and not dmgInfo:GetAttacker():IsWorld() then
		addCombatResponse(targetPlayer.organism, victimAnger * severity, victimAdrenaline * severity, getOpponent(dmgInfo:GetAttacker()))
	end
end

hook.Add("HomigradDamage", "PsycheCombatAnger", function(target, dmgInfo)
	triggerCombatResponses(target, dmgInfo)
end)

hook.Add("EntityFireBullets", "PsycheCombatGunfire", function(shooter)
	local player = getCombatPlayer(shooter)
	if not IsValid(player) or not player:Alive() then return end
	local org = player.organism
	if not org or org.otrub then return end
	if (org._gunfightAngerNext or 0) > CurTime() then return end
	org._gunfightAngerNext = CurTime() + gunfight_response_cooldown
	local adrenalineAmount = (org.adrenaline or 0) < gunfight_adrenaline_cap and 0.3 or 0
	hg.organism.RileAnger(org, 0.05, adrenalineAmount)
end)
