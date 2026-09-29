local Clamp = math.Clamp

hg.organism.module.psyche = {}
local module = hg.organism.module.psyche

local combat_response_cooldown = 0.35
local gunfight_response_cooldown = 1.5
local gunfight_adrenaline_cap = 1.5

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
local derealization_color = Color(180, 160, 255)

local function psycheThought(owner, phrases, delay, key, clr)
	local newThoughts = owner:GetInfoNum("hg_newthoughts", 0) > 0
	local messages = phrases[newThoughts and "legacy" or "new"]
	local msg = messages[math.random(#messages)]
	return owner:Thought(msg, delay, key, 0, clr)
end

module[1] = function(org)
	org.psycheAnger = 0
	org.psycheAngerLastHit = 0
	org.psychePainMul = 1
end

module[2] = function(owner, org, timeValue)
	local anger = Clamp(org.anger or 0, 0, 1)
	org.psycheAnger = anger
	org.psychePainMul = 1

	if org.isPly and owner:Alive() then
		local panic = org.panicattack or 0
		if panic >= 0.55 then
			psycheThought(owner, derealization_phrases, math.Rand(18, 28), "psyche_derealization", derealization_color)
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
