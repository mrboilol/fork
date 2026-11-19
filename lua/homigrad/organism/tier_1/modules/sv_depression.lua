local max, min, Clamp, Approach = math.max, math.min, math.Clamp, math.Approach
hg.organism.module.depression = {}
local module = hg.organism.module.depression
local hg_depression = CreateConVar("hg_depression", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enable depression and its mechanics", 0, 1)
local hg_selfharm = CreateConVar("hg_selfharm", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Depression can push you into self harm", 0, 1)
local depression_happiness_cost = 1.5

local depression_max = 1
local depression_drain_time = 210
local depression_drain_calm_mul = 3
local depression_drain_treated_mul = 3.5
local depression_treated_gain_mul = 0.25
local depression_cotard_gain = 0.012
local depression_adrenaline_suppress_start = 0.5
local depression_adrenaline_suppress_min = 0.1
local selfharm_adrenaline_threshold = 1.5
local selfharm_adrenaline_delay = 3
local depression_wake_relief = 0.2
local depression_wake_relief_time = 35
local depression_untreated_bleed_delay = 45
local depression_stages = {0.25, 0.6, 0.85}
local depression_succumb_max = 0.3
local depression_calm_dying = 0.2
local depression_panic_strain = {
	suppressedPanic = 0.2,
	suppressedStart = 20,
	suppressedRamp = 20,
	suppressedGain = 0.025,
	overPanic = 0.75,
	overGain = 0.035,
	recoverMul = 2,
}

local selfharm_threshold = 0.6
local selfharm_roll_time_min = 5
local selfharm_roll_time_max = 12
local selfharm_chance_min = 0.25
local selfharm_chance_max = 0.7
local selfharm_pending_time = 45
local selfharm_weapon_grace = 3
local selfharm_duration_min = 5
local selfharm_duration_max = 10
local selfharm_initial_delay = 15
local selfharm_wave_time = 4
local selfharm_wave_interval_min = 5
local selfharm_wave_interval_max = 7
local selfharm_wave_presses = 10

local selfharm_phrases = {
	"I CAN'T DO THIS ANYMORE. I'M GOING TO DIE ANYWAY.",
	"Holy shit I can't do anything... just make it stop...",
	"WHAT'S THE POINT, THEY'RE GOING TO KILL ME ANYWAY.",
	"I can't... I can't fucking do this... make it stop...",
}

local selfharm_pending_phrases = {
	"I'M GOING TO FUCKING DIE. I'M GOING TO DIE.",
	"Holy shit I can't do anything... I'm going to die...",
	"It's over... there's nothing I can do...",
}

local depression_stage_cooldown = 30
local depression_after_panic_window = 60
local depression_dark_thought_min = 45
local depression_dark_thought_max = 120
local depression_thought_pools = {
	fight = {
		{"How are they winning!?", "I can't keep up with this...", "This is bad..."},
		{"Nothing's working... why is NOTHING working?!", "They're going to kill me. They're really going to kill me.", "Why isn't anything working!?"},
	},
	grief = {
		{"Holy shit.. I just saw them die...","I'm next aren't I?", "They just died in front of me..."},
		{"Jesus christ.. He just died...", "I keep seeing their face...", "Oh god- I just saw them fucking die..."},
	},
	guilt = {
		{"WHAT THE FUCK DID I JUST DO.", "I DIDN'T MEAN TO DO THAT!", "THAT WAS ME WASN'T IT!?"},
		{"I KILLED THEM. I JUST KILLED THEM.", "WHAT IS WRONG WITH ME", "DID I JUST KILL MY FRIEND?"},
		{"WHY THE FUCK DID I DO THAT!?", "THEY'RE GONE BECAUSE OF ME", "HOW WILL I EVER LIVE WITH THIS"},
	},
	recovery = {
		{"I feel a little better... I think I'm going to be okay.", "The weight is lifting... slowly.", "Breathe... Just breathe..."},
		{"I can think again... it's not as dark as it was.", "My mind feels a little less cluttered...", "I feel a little happier now..."},
		{"I'm not that far down anymore... I can hold on.", "It's easing... a bit.", "Maybe I have a chance."},
	},
	aftermath = {
		{"My mind feels a little more clear...", "That was way too close...", "I need a second..."},
		{"Next time I won't be this lucky...", "I can't get it out of my head...", "I almost died back there. I ALMOST DIED."},
		{"I can't keep doing this...", "I won't survive the next one...", "Why am I even still trying..."},
	},
}

local depression_minigame_phrase_interval_min = 2
local depression_minigame_phrase_interval_max = 4
local depression_minigame_phrases = {
	"Wh-what are you doing?",
	"Dont do that.",
	"That's too close...",
	"Put that away.",
}

local depression_suicide_aim_phrases = {
	"no-no.. i dont want to do this..",
	"stop.. please.. dont make me..",
	"i-i cant.. i wont.. please..",
	"no-no no.. someone help me..",
	"dont... i dont want to die..",
	"not now.. please, not now..",
}

util.AddNetworkString("rem_selfharm_press")
util.AddNetworkString("rem_selfharm_end")

local function isDepressionImmune(org)
	local owner = org and org.owner

	return IsValid(owner) and owner.HasTrait and owner:HasTrait("apathetic")
end

local GOOD_EMOTION_IDS = {
	witness_hope = true,
	witness_relief = true,
	buddy_heal = true,
	emotion_chance = true,
	emotion_disarm = true,
}
local GOOD_EMOTION_COLOR = Color(110, 170, 255)

local function showDepressionThought(owner, text, duration, id)
	local clr = GOOD_EMOTION_IDS[id] and GOOD_EMOTION_COLOR or nil
	if owner:GetInfoNum("hg_newthoughts", 0) > 0 then
		owner:Thought(text, duration, id, 0, clr)
	else
		owner:Notify(text, duration, id, 0, nil, clr)
	end
end

function hg.organism.EmotionThought(owner, text, duration, id)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	local now = CurTime()
	local K = hg.PsycheCombat
	if K and owner.hgLastEmotionText == text and now - (owner.hgLastEmotionTime or 0) < K.thoughtRepeatWindow then return end
	owner.hgLastEmotionText = text
	owner.hgLastEmotionTime = now

	showDepressionThought(owner, text, duration, id)
end

local function isSelfHarmWeapon(wep)
	if not IsValid(wep) or not wep.Canselfharm then return false end

	return wep.ismelee2 or wep.Base == "weapon_melee"
end

local function hasSelfHarmWeapon(owner)
	local wep = owner.GetActiveWeapon and owner:GetActiveWeapon()

	return isSelfHarmWeapon(wep)
end

local function findInventorySelfHarmWeapon(owner)
	for _, wep in ipairs(owner:GetWeapons()) do
		if isSelfHarmWeapon(wep) then return wep end
	end
end

local function autoEquipSelfHarmWeapon(owner)
	if hasSelfHarmWeapon(owner) then return true end
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return false end

	local found = findInventorySelfHarmWeapon(owner)
	if not IsValid(found) then return false end

	owner:SelectWeapon(found:GetClass())
	if owner.SetActiveWeapon then owner:SetActiveWeapon(found) end

	return true
end

local function hasStrongAdrenaline(org)
	return (org.adrenaline or 0) >= selfharm_adrenaline_threshold
end

function hg.organism.StartSelfHarm(owner)
	if not hg_depression:GetBool() then return end
	if not IsValid(owner) or not owner:IsPlayer() then return end

	local org = owner.organism
	if not org or not org.alive or owner.selfharming then return end
	if isDepressionImmune(org) then return end
	if hasStrongAdrenaline(org) then return end
	if owner.suiciding or owner.remUrgeEnd then return end
	if (owner.remUrgeCooldown or 0) > CurTime() then return end

	owner.selfharming = true
	local dur = math.Rand(selfharm_duration_min, selfharm_duration_max)
	org.selfharmUntil = CurTime() + dur
	org.selfharmPendingUntil = nil
	owner:SetNWFloat("rem_selfharm_pending", 0)
	org.selfharmNextWave = nil
	org.selfharmWaveStart = CurTime()
	org.selfharmWaveEnd = org.selfharmUntil
	org.selfharmNextCut = CurTime() + 1
	org.selfharmPresses = 0
	owner:SetNWBool("selfharming", true)
	owner:SetNWFloat("rem_selfharm_wave_end", org.selfharmWaveEnd)

	if org.isPly then
		showDepressionThought(owner, selfharm_phrases[math.random(#selfharm_phrases)], 12, "selfharm")
	end
end

function hg.organism.EndSelfHarm(owner, finished)
	if not IsValid(owner) then return end

	owner.selfharming = false
	owner:SetNWBool("selfharming", false)

	local org = owner.organism
	if org then
		if finished then
			org.depression = math.max((org.depression or 0) - 0.2, 0)
		end

		org.selfharmUntil = 0
		org.selfharmPendingUntil = nil
		org.selfharmGrace = nil

		if owner:IsPlayer() then
			owner:SetNWFloat("rem_selfharm_pending", 0)
		end

		local cooldown = CurTime() + math.Rand(15, 25)
		org.selfharmNextRoll = cooldown
		owner.remUrgeCooldown = math.max(owner.remUrgeCooldown or 0, cooldown)
		org.selfharmNextWave = nil
		org.selfharmWaveEnd = nil
		org.selfharmWaveStart = nil
		org.selfharmNextCut = nil
		org.selfharmPresses = 0
	end

	if owner:IsPlayer() then
		owner:SetNWFloat("rem_selfharm_wave_end", 0)

		if finished then
			net.Start("rem_selfharm_end")
			net.Send(owner)
		end
	end
end

module[1] = function(org)
	org.depression = 0
	org.depressionadd = 0
	org.depressionCause = nil
	org.depressionHopeless = nil
	org.depressionSuccumb = 0
	org.hopelessO2Mul = nil
	org.depressionThoughtStage = nil
	org.depressionNextStageThought = nil
	org.depressionNextDarkThought = nil
	org.depressionNextMinigamePhrase = nil
	org.depressionWakeReliefUntil = nil
	org.depressionUntreatedBleedSince = nil
	org.depressionTreatmentUntil = nil
	org.depressionWasUnconscious = false
	org.selfharmNextRoll = CurTime() + selfharm_initial_delay
	org.selfharmUntil = 0
	org.selfharmPendingUntil = nil
	org.selfharmGrace = nil
	org.selfharmNextWave = nil
	org.selfharmWaveEnd = nil
	org.selfharmWaveStart = nil
	org.selfharmNextCut = nil
	org.selfharmPresses = 0

	local owner = org.owner
	if IsValid(owner) then
		owner.selfharming = false
		owner:SetNWBool("selfharming", false)
		owner:SetNWFloat("rem_selfharm_pending", 0)

		if owner:IsPlayer() then
			owner:SetNWFloat("rem_selfharm_wave_end", 0)
		end
	end
end

local function doSelfHarmCut(owner)
	local wep = owner.GetActiveWeapon and owner:GetActiveWeapon()
	if not IsValid(wep) or not wep.DoSelfHarmCut then return end

	wep:DoSelfHarmCut()
end

function hg.organism.RecordDepressionTreatment(org, failed)
	if not org then return end
	if isDepressionImmune(org) then return end

	org.depressionTreatmentUntil = CurTime() + depression_untreated_bleed_delay
	org.depressionUntreatedBleedSince = nil
	if failed then
		org.depressionWakeReliefUntil = nil
	end
end

local function applyWakeRelief(org)
	if (org.bleed or 0) <= 0 and (org.internalBleed or 0) <= 0 then return end

	org.depression = max((org.depression or 0) - depression_wake_relief, 0)
	org.depressionWakeReliefUntil = CurTime() + depression_wake_relief_time
	org.depressionUntreatedBleedSince = nil
	org.depressionTreatmentUntil = CurTime() + depression_wake_relief_time
end

local function updateSelfHarmCutTick(owner, org)
	local now = CurTime()

	if not org.selfharmNextCut then return end
	if now < org.selfharmNextCut then return end

	local presses = org.selfharmPresses or 0
	org.selfharmPresses = 0
	org.selfharmNextCut = now + 1

	if presses < 2 and org.alive and not org.heartstop then
		doSelfHarmCut(owner)
	end
end

local function updateSelfHarm(owner, org)
	updateSelfHarmCutTick(owner, org)

	if (org.selfharmUntil or 0) < CurTime() then
		hg.organism.EndSelfHarm(owner, true)
		return
	end

	if org.otrub or owner.suiciding or org.larmamputated or hasStrongAdrenaline(org) then
		hg.organism.EndSelfHarm(owner)
		return
	end

	if not hasSelfHarmWeapon(owner) then
		org.selfharmGrace = org.selfharmGrace or CurTime() + selfharm_weapon_grace

		if CurTime() > org.selfharmGrace then
			hg.organism.EndSelfHarm(owner)
		end
	else
		org.selfharmGrace = nil
	end
end

local function updatePending(owner, org)
	if owner.selfharming then return end

	if (org.selfharmPendingUntil or 0) < CurTime() then
		if owner:GetNWFloat("rem_selfharm_pending", 0) ~= 0 then
			owner:SetNWFloat("rem_selfharm_pending", 0)
		end

		return
	end

	if org.otrub or owner.suiciding or org.larmamputated or hasStrongAdrenaline(org) then
		org.selfharmPendingUntil = nil
		owner:SetNWFloat("rem_selfharm_pending", 0)
		return
	end

	if not hasSelfHarmWeapon(owner) then
		if (org.selfharmNextEquip or 0) < CurTime() then
			org.selfharmNextEquip = CurTime() + 1

			autoEquipSelfHarmWeapon(owner)
		end

		return
	end

	org.selfharmNextEquip = nil

	hg.organism.StartSelfHarm(owner)
end

local function rollSelfHarm(owner, org)
	if hasStrongAdrenaline(org) then
		org.selfharmNextRoll = CurTime() + selfharm_adrenaline_delay
		return
	end
	if (org.depression or 0) < selfharm_threshold then return end
	if (org.selfharmNextRoll or 0) > CurTime() then return end

	org.selfharmNextRoll = CurTime() + math.Rand(selfharm_roll_time_min, selfharm_roll_time_max)

	if org.otrub or owner.suiciding or org.larmamputated then return end

	local frac = Clamp((org.depression - selfharm_threshold) / (depression_max - selfharm_threshold), 0, 1)
	local chance = Lerp(frac, selfharm_chance_min, selfharm_chance_max)

	if math.Rand(0, 1) > chance then return end

	if hasSelfHarmWeapon(owner) then
		hg.organism.StartSelfHarm(owner)
		return
	end

	if autoEquipSelfHarmWeapon(owner) then
		hg.organism.StartSelfHarm(owner)
		return
	end

	org.selfharmPendingUntil = CurTime() + selfharm_pending_time
	owner:SetNWFloat("rem_selfharm_pending", org.selfharmPendingUntil)

	if org.isPly then
		showDepressionThought(owner, table.Random(selfharm_pending_phrases), 12, "selfharmpending")
	end
end

local function getDyingLevel(org)
	local blood = Clamp((4000 - (org.blood or 5000)) / 1500, 0, 1)
	local bleed = Clamp(((org.bleed or 0) - 2) / 8, 0, 1)
	local o2 = Clamp((18 - (org.o2 and org.o2[1] or 30)) / 12, 0, 1)
	local fading = Clamp((0.7 - (org.consciousness or 1)) / 0.4, 0, 1)
	local internal = (org.internalBleed or 0) > 0.5 and 0.5 or 0

	return max(blood, bleed, o2, fading, internal)
end

local function getTreatment(org)
	if CurTime() < (org.betaBlockerUntil or 0) then return 1 end

	return Clamp(max(org.analgesia or 0, (org.painkiller or 0) * 0.4), 0, 1)
end

local function getStage(dep)
	for i = #depression_stages, 1, -1 do
		if dep >= depression_stages[i] then return i end
	end

	return 0
end

local function clearDepression(owner, org)
	if owner.selfharming then hg.organism.EndSelfHarm(owner) end
	org.depression = 0
	org.depressionadd = 0
	org.depressionCause = nil
	org.depressionHopeless = nil
	org.depressionSuccumb = 0
	org.hopelessO2Mul = nil
	org.depressionThoughtStage = nil
	org.depressionNextStageThought = nil
	org.depressionNextDarkThought = nil
	org.depressionNextMinigamePhrase = nil
	org.depressionUntreatedBleedSince = nil
	org.depressionPanicStrain = nil
	org.selfharmPendingUntil = nil
	if owner:IsPlayer() then owner:SetNWFloat("rem_selfharm_pending", 0) end
end

local function updateDepressionThoughts(owner, org, dying, inFight)
	local now = CurTime()
	if org.panicattackActive then
		org.depressionPanicSeen = now
	end
	local stage = getStage(org.depression or 0)
	local shown = org.depressionThoughtStage or 0
	if stage < shown then
		org.depressionThoughtStage = stage
		if not org.otrub and now >= (org.depressionNextStageThought or 0) then
			org.depressionNextStageThought = now + depression_stage_cooldown
			local recovery = depression_thought_pools.recovery[stage + 1]
			showDepressionThought(owner, recovery[math.random(#recovery)], 6, "depression_recovery")
		end
		return
	end
	if stage == 0 or org.otrub then return end

	local afterPanic = not org.panicattackActive and now - (org.depressionPanicSeen or -1000) < depression_after_panic_window

	local cause = org.depressionCause
	local context = dying >= 0.35 and "dying" or inFight and "fight" or afterPanic and "aftermath" or depression_thought_pools[cause] and cause or "aftermath"
	local pool = (context == "dying" and hg.DepressionDyingThoughts or depression_thought_pools[context])[stage]

	if stage > shown and now >= (org.depressionNextStageThought or 0) then
		org.depressionThoughtStage = stage
		org.depressionNextStageThought = now + depression_stage_cooldown
		org.depressionNextDarkThought = now + math.Rand(depression_dark_thought_min, depression_dark_thought_max)
		showDepressionThought(owner, pool[math.random(#pool)], 6, "depression_stage")
	elseif now >= (org.depressionNextDarkThought or now + 1) then
		org.depressionNextDarkThought = now + math.Rand(depression_dark_thought_min, depression_dark_thought_max)
		showDepressionThought(owner, pool[math.random(#pool)], 6, "depression_dark")
	end
end

module[2] = function(owner, org, timeValue)
	if isDepressionImmune(org) then
		clearDepression(owner, org)
		return
	end

	if owner.selfharming and (not org.alive or org.heartstop) then
		hg.organism.EndSelfHarm(owner)
	end

	if not org.alive then return end
	if org.heartstop then return end
	if org.depressionWasUnconscious and not org.otrub then
		applyWakeRelief(org)
	end
	org.depressionWasUnconscious = org.otrub and true or false

	local now = CurTime()
	local dying = getDyingLevel(org)
	local treatment = getTreatment(org)
	local inFight = (org.panicGunfightUntil or 0) > now or (org.hgLosing or 0) > 0
	local add = 0

	if (org.cotard or 0) > 0 then
		add = add + depression_cotard_gain * org.cotard * timeValue
	end

	if (org.depressionadd or 0) > 0 then
		local applied = min(org.depressionadd, timeValue / 5)
		org.depressionadd = max(org.depressionadd - applied, 0)
		add = add + applied
	end

	local strainConfig = depression_panic_strain
	local panic = Clamp(tonumber(org.panicattack) or 0, 0, 1)
	local strain = org.depressionPanicStrain or 0
	if not org.otrub and (org.panicGunfightUntil or 0) > now and panic >= strainConfig.suppressedPanic then
		strain = strain + timeValue
	else
		strain = max(strain - timeValue * strainConfig.recoverMul, 0)
	end
	org.depressionPanicStrain = strain
	if not org.otrub then
		add = add + strainConfig.suppressedGain * Clamp((strain - strainConfig.suppressedStart) / strainConfig.suppressedRamp, 0, 1) * timeValue
		add = add + strainConfig.overGain * Clamp((panic - strainConfig.overPanic) / (1 - strainConfig.overPanic), 0, 1) * timeValue
		if add > 0 and not org.depressionCause then org.depressionCause = "fight" end
	end

	local adrenaline = org.adrenaline or 0
	if adrenaline > depression_adrenaline_suppress_start then
		add = add * max(1 - adrenaline * 0.2, depression_adrenaline_suppress_min)
	end
	add = add * Lerp(treatment, 1, depression_treated_gain_mul)

	if now < (org.depressionWakeReliefUntil or 0) then
		add = 0
	end
	if add > 0 and hg.organism.ShieldEmotion then
		add = hg.organism.ShieldEmotion(org, add, depression_happiness_cost)
	end
	if add > 0 then
		org.panicattackadd = max((org.panicattackadd or 0) - add, 0)
		org.panicattack = max((org.panicattack or 0) - add, 0)
	end

	org.depression = Clamp((org.depression or 0) + add, 0, depression_max)

	local drainRate = timeValue / depression_drain_time
	if not inFight and dying < depression_calm_dying and not org.otrub then
		drainRate = drainRate * depression_drain_calm_mul
	end
	drainRate = drainRate * Lerp(treatment, 1, depression_drain_treated_mul)
	drainRate = drainRate * Lerp(Clamp(tonumber(org.goodmood) or 0, 0, 1), 1, 1.75)
	if org.superfighter then
		drainRate = drainRate * 4
	end

	org.depression = max((org.depression or 0) - drainRate, 0)

	local dep = org.depression
	org.depressionHopeless = nil
	org.hopelessO2Mul = nil
	org.depressionSuccumb = Clamp((dep - depression_stages[1]) / (depression_stages[3] - depression_stages[1]), 0, 1) * depression_succumb_max

	if owner:IsPlayer() then
		updateDepressionThoughts(owner, org, dying, inFight)

		if owner.suiciding and (owner.hgSuicideAim or 0) > 0 and (org.depressionNextMinigamePhrase or 0) < CurTime() then
			org.depressionNextMinigamePhrase = CurTime() + math.Rand(depression_minigame_phrase_interval_min, depression_minigame_phrase_interval_max)
			showDepressionThought(owner, table.Random(depression_suicide_aim_phrases), 3, "depression_suicide_aim")
		elseif (owner.selfharming or owner.suiciding or owner.remUrgeEnd) and (org.depressionNextMinigamePhrase or 0) < CurTime() then
			org.depressionNextMinigamePhrase = CurTime() + math.Rand(depression_minigame_phrase_interval_min, depression_minigame_phrase_interval_max)
			showDepressionThought(owner, table.Random(depression_minigame_phrases), 3, "depression_minigame")
		elseif not owner.selfharming and not owner.suiciding and not owner.remUrgeEnd then
			org.depressionNextMinigamePhrase = nil
		end
	end

	if owner.selfharming then
		updateSelfHarm(owner, org)
	elseif owner:IsPlayer() and hg_selfharm:GetBool() then
		rollSelfHarm(owner, org)
		updatePending(owner, org)
	elseif org.selfharmPendingUntil then
		org.selfharmPendingUntil = nil
		owner:SetNWFloat("rem_selfharm_pending", 0)
	end
end

function hg.organism.GetWitnessTrauma(org)
	local trauma = org and tonumber(org.witnessTrauma) or 0
	if trauma <= 0 then return 0 end
	return trauma * math.exp(-(CurTime() - (org.witnessTraumaAt or 0)) / hg.PsycheCombat.noDepressionTraumaDecay)
end

function hg.organism.AddDepression(org, amount, cause)
	if not org then return 0 end
	if isDepressionImmune(org) then
		org.depression = 0
		org.depressionadd = 0
		return 0
	end
	if not isnumber(amount) or amount <= 0 then return org.depressionadd or 0 end
	if hg.GetPsycheTraining then amount = amount * Lerp(hg.GetPsycheTraining(org.owner), 1, hg.PsycheCombat.trainedDepressionMul) end
	if org.buddyNear and hg.Buddy then amount = amount * (1 - hg.Buddy.Config.moodResist) end

	if not hg_depression:GetBool() and cause and cause ~= "dying" then
		local K = hg.PsycheCombat
		local current = org.adrenalineAdd or 0
		if current >= 0 and current < K.noDepressionSurgeCap then
			org.adrenalineAdd = min(current + amount * K.noDepressionSurge, K.noDepressionSurgeCap)
		end
		org.goodmood = max(Clamp(tonumber(org.goodmood) or 1, 0, 1) - amount * K.noDepressionHappinessCost, 0)
		org.witnessTrauma = min(hg.organism.GetWitnessTrauma(org) + amount * K.noDepressionTraumaGain, 1)
		org.witnessTraumaAt = CurTime()
	end

	org.depressionadd = Clamp((org.depressionadd or 0) + amount, 0, depression_max)
	if cause then org.depressionCause = cause end

	return org.depressionadd
end

concommand.Add("selfharm", function(ply)
	if not hg_depression:GetBool() then return end
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	if not ply.organism or ply.selfharming or ply.suiciding or ply.remUrgeEnd then return end
	if (ply.remUrgeCooldown or 0) > CurTime() then return end
	if ply.organism and (ply.organism.depression or 0) < selfharm_threshold then
		if ply:GetInfoNum("hg_newthoughts", 0) > 0 then
			ply:Thought("You shouldn't do this.", 6, "depression_block_selfharm", 0)
		else
			ply:Notify("I can't do it.", 6, "depression_block_selfharm", 0)
		end
		return
	end

	if not hasSelfHarmWeapon(ply) then
		if not autoEquipSelfHarmWeapon(ply) then
			ply:ChatPrint("You need a weapon with SWEP.Canselfharm enabled to self harm.")
			return
		end
	end

	hg.organism.StartSelfHarm(ply)
end)

net.Receive("rem_selfharm_press", function(_, ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local org = ply.organism
	if not org then return end
	if not org.selfharmWaveEnd or org.selfharmWaveEnd < CurTime() then return end

	org.selfharmPresses = (org.selfharmPresses or 0) + 1
end)
