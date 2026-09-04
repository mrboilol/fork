local Clamp, min, max, Approach = math.Clamp, math.min, math.max, math.Approach

hg.organism.module.psyche = {}
local module = hg.organism.module.psyche

local combat_response_cooldown = 0.35
local gunfight_response_cooldown = 1.5
local gunfight_adrenaline_cap = 1.5
local apathy_pain_start = 35
local apathy_pain_speed = 90
local apathy_blood_start = 3400
local apathy_blood_speed = 150
local apathy_otrub_speed = 220
local apathy_fear_start = 0.6
local apathy_fear_speed = 150
local apathy_decay = 180
local apathy_decay_comfort = 60
local apathy_fear_cap = 0.4
local apathy_witness_radius = 700
local apathy_witness_gain = 0.25
local apathy_kill_relief = 0.2
local desens_cap = 20

local anger_phrases = {
	legacy = {
	"You feel your blood boiling.",
	"Your hands are shaking with rage.",
	"You want to hurt something. Anything.",
	"A red haze creeps into the edges of your vision.",
	"Your teeth are clenched so hard it hurts.",
	"You can barely think straight anymore.",
	"Every sound they make infuriates you.",
	"You are going to make them pay.",
	"The anger swallowed the fear whole.",
	"Your heartbeat pounds in your ears like a war drum.",
	"You are no longer thinking. Only reacting.",
	"Someone is going to answer for this.",
	"You feel like you could tear a door off its hinges.",
	"It takes everything you have not to scream."
},
	new = {
		"I want to kill someone so bad.",
		"I'm so fucking angry.",
		"I need to make them pay.",
		"I can't let them get away with this.",
		"I want to hurt them back.",
		"I can barely think past how angry I am.",
		"I need to hit something.",
		"I'm done being pushed around."
	}
}
local apathy_phrases = {
	legacy = {
	"You feel numb inside.",
	"Nothing seems to matter anymore.",
	"The world looks faded, like an old photograph.",
	"You are so tired of all this.",
	"You watch your own hands like they belong to a stranger.",
	"Even the noise sounds muffled and distant.",
	"You can't remember the last time you felt anything.",
	"What's the point of any of this?",
	"Your thoughts are slow and grey like ash.",
	"You just want to sit down and stop.",
	"Hunger, pain, fear — it all blends into one grey hum.",
	"Somewhere inside, you know you should care. You don't.",
	"The light seems weaker than it was yesterday.",
	"You are merely existing, not living."
},
	new = {
		"I feel completely numb.",
		"Nothing matters right now.",
		"I just want to sit down and stop.",
		"I don't have the energy to care anymore.",
		"Everything feels distant.",
		"I feel empty.",
		"I don't know why I'm still trying.",
		"I just want this to be over."
	}
}
local fear_phrases = {
	legacy = {"You are in fear."},
	new = {
		"I'm scared.",
		"I don't want to die here.",
		"I need to get out of here.",
		"Please, not like this.",
		"I just want to survive."
	}
}
local derealization_phrases = {
	legacy = {
	"This doesn't feel real.",
	"The world looks wrong, like a rough sketch of itself.",
	"You are watching yourself from far away.",
	"Your own voice sounds like a stranger's.",
	"Everything is moving too slow, or too fast. You can't tell.",
	"The walls feel like paper. The air feels like water.",
	"You know this place, but it doesn't know you.",
	"Reality is coming apart at the edges.",
	"You are not sure you actually exist right now.",
	"The world feels like a memory of itself."
},
	new = {
		"This doesn't feel real.",
		"I feel like I'm watching this happen to someone else.",
		"I can't tell what is real anymore.",
		"Everything feels wrong.",
		"My own voice doesn't sound like mine.",
		"I feel far away from my body."
	}
}
local anger_color = Color(255, 110, 110)
local apathy_color = Color(170, 170, 170)
local fear_color = Color(190, 190, 255)
local derealization_color = Color(180, 160, 255)

local function psycheThought(owner, phrases, delay, key, clr)
	local newThoughts = owner:GetInfoNum("hg_newthoughts", 0) > 0
	local messages = phrases[newThoughts and "new" or "legacy"]
	local msg = messages[math.random(#messages)]
	if newThoughts then
		return owner:Thought(msg, delay, key, 0, clr)
	end
	return owner:Notify(msg, delay, key, 0, nil, clr)
end

module[1] = function(org)
	org.psycheAnger = 0
	org.psycheApathy = 0
	org.psycheDesens = 0
	org.psycheAngerLastHit = 0
	org.psychePainMul = 1
end

module[2] = function(owner, org, timeValue)
	local anger = Clamp(org.anger or 0, 0, 1)
	local apathy = org.psycheApathy or 0

	if org.pain > apathy_pain_start then
		apathy = min(apathy + timeValue / apathy_pain_speed * Clamp((org.pain - apathy_pain_start) / 60, 0, 1), 1)
	end
	if (org.blood or 5000) < apathy_blood_start then
		apathy = min(apathy + timeValue / apathy_blood_speed, 1)
	end
	if org.otrub then
		apathy = min(apathy + timeValue / apathy_otrub_speed, 1)
	end
	local fearLevel = Clamp(org.fear or 0, 0, 1)
	if fearLevel > apathy_fear_start then
		apathy = min(apathy + timeValue / apathy_fear_speed * Clamp((fearLevel - apathy_fear_start) / (1 - apathy_fear_start), 0, 1), 1)
	end

	local comfort = (org.satiety or 0) > 500 and org.pain < 20 and (org.blood or 0) > 4500
	local apathyDecayTime = comfort and apathy_decay_comfort or apathy_decay
	if anger > 0.5 then apathyDecayTime = min(apathyDecayTime, apathy_decay_comfort) end
	apathy = Approach(apathy, 0, timeValue / apathyDecayTime)

	org.psycheAnger = anger
	org.psycheApathy = apathy
	org.psychePainMul = 1
	org.fear = min(org.fear, 1 - apathy_fear_cap * apathy)

	if org.isPly and owner:Alive() then
		local panic = org.panicattack or 0
		if panic >= 0.55 then
			psycheThought(owner, derealization_phrases, math.Rand(18, 28), "psyche_derealization", derealization_color)
		end
		if fearLevel > 0.5 and panic < 0.55 then
			psycheThought(owner, fear_phrases, math.Rand(15, 25), "psyche_fear", fear_color)
		end
		if anger > 0.55 then
			psycheThought(owner, anger_phrases, math.Rand(20, 35), "psyche_anger", anger_color)
		end
		if apathy > 0.55 then
			psycheThought(owner, apathy_phrases, math.Rand(30, 50), "psyche_apathy", apathy_color)
		end
	end
end

local function getCombatPlayer(ent)
	if not IsValid(ent) then return end
	if ent:IsPlayer() then return ent end
	local owner = hg.RagdollOwner and hg.RagdollOwner(ent)
	return IsValid(owner) and owner:IsPlayer() and owner or nil
end

local function addCombatResponse(org, angerAmount, adrenalineAmount)
	if not org or not hg.organism.RileAnger then return end
	local now = CurTime()
	if (org._combatResponseNext or 0) > now then return end
	org._combatResponseNext = now + combat_response_cooldown
	hg.organism.RileAnger(org, angerAmount, adrenalineAmount)
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

	if IsValid(attackerPlayer) then addCombatResponse(attackerPlayer.organism, attackerAnger * severity, attackerAdrenaline * severity) end
	if IsValid(targetPlayer) and IsValid(dmgInfo:GetAttacker()) and not dmgInfo:GetAttacker():IsWorld() then
		addCombatResponse(targetPlayer.organism, victimAnger * severity, victimAdrenaline * severity)
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

hook.Add("PlayerDeath", "PsycheApathyWitness", function(victim, inflictor, attacker)
	local pos = victim:GetPos()
	for i, ply in player.Iterator() do
		if ply == victim or not ply:Alive() then continue end
		local org = ply.organism
		if not org then continue end
		if ply:GetPos():DistToSqr(pos) > apathy_witness_radius * apathy_witness_radius then continue end
		local desens = org.psycheDesens or 0
		org.psycheDesens = min(desens + 1, desens_cap)
		org.psycheApathy = min((org.psycheApathy or 0) + apathy_witness_gain / (1 + desens * 0.35), 1)
	end
	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim and attacker.organism then
		local org = attacker.organism
		org.psycheDesens = min((org.psycheDesens or 0) + 1, desens_cap)
		org.psycheApathy = max((org.psycheApathy or 0) - apathy_kill_relief, 0)
	end
end)
