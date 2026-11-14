util.AddNetworkString("hg_simplehealth")
util.AddNetworkString("hg_simplehealth_faint")

local SimpleHealth = hg.SimpleHealth
local organism = hg.organism
local CONFIG = SimpleHealth.Config

local CRIT_NONE = SimpleHealth.CRIT_NONE
local CRIT_SOFT = SimpleHealth.CRIT_SOFT
local CRIT_HARD = SimpleHealth.CRIT_HARD
local MODE_SIMPLE = SimpleHealth.MODE_SIMPLE
local MODE_ORGANS = SimpleHealth.MODE_ORGANS

local NET_INTERVAL = 0.25
local NET_KEEPALIVE = 5
local LOW_BRAIN_OXYGEN = 0.28
local BURN_TYPES = bit.bor(DMG_BURN, DMG_SLOWBURN, DMG_PLASMA, DMG_ENERGYBEAM)
local TOXIN_TYPES = bit.bor(DMG_POISON, DMG_NERVEGAS, DMG_RADIATION, DMG_ACID, DMG_PARALYZE)
local PERFUSION_KEYS = {"perfusion", "cerebralPerfusion", "peripheralperfusion", "bodyoxygen", "brainoxygen"}
local LUNG_KEYS = {"lungsL", "lungsR"}

organism.module.simplehealth = {}

local module = organism.module.simplehealth

SimpleHealth.ModuleOverrides = SimpleHealth.ModuleOverrides or {}
SimpleHealth.Tickers = {}
SimpleHealth.Sanitizers = {}

function SimpleHealth.GetState(org)
	return org and org.simpleMode and org.simple or nil
end

function SimpleHealth.AddDamage(org, pool, amount)
	local state = SimpleHealth.GetState(org)
	if not state or not amount or amount <= 0 then return 0 end

	local before = state[pool] or 0
	state[pool] = math.min(before + amount, CONFIG.poolMax)

	return state[pool] - before
end

function SimpleHealth.Heal(org, pool, amount)
	local state = SimpleHealth.GetState(org)
	if not state or not amount or amount <= 0 then return 0 end

	local before = state[pool] or 0
	state[pool] = math.max(before - amount, 0)

	return before - state[pool]
end

local function newState()
	return {
		brute = 0,
		burn = 0,
		toxin = 0,
		oxy = 0,
		health = CONFIG.maxHealth,
		crit = CRIT_NONE,
		contamination = 0,
		heartEfficiency = 1,
	}
end

local function quantizePool(value)
	return math.Clamp(math.Round(value or 0), 0, SimpleHealth.NET_POOL_MAX)
end

local function sendState(owner, org, force)
	local now = CurTime()
	local mode = org.simpleMode or 0
	local state = org.simple
	local crit = state and state.crit or CRIT_NONE
	local countdownEnd = state and state.countdownStart and state.countdownStart + CONFIG.oxy.countdownTime or 0
	local signature = mode * 4 + crit

	if state then
		for _, pool in ipairs(SimpleHealth.POOLS) do
			signature = signature * (SimpleHealth.NET_POOL_MAX + 1) + quantizePool(state[pool])
		end
	end

	local changed = org.simpleNetSignature ~= signature or org.simpleNetCountdown ~= countdownEnd
	local keepAlive = mode > 0 and (org.simpleNetKeepAlive or 0) <= now
	if not force and not keepAlive and (not changed or (org.simpleNetNext or 0) > now) then return end

	org.simpleNetSignature = signature
	org.simpleNetCountdown = countdownEnd
	org.simpleNetNext = now + NET_INTERVAL
	org.simpleNetKeepAlive = now + NET_KEEPALIVE

	net.Start("hg_simplehealth")
		net.WriteUInt(mode, SimpleHealth.NET_MODE_BITS)
		if state then
			net.WriteUInt(crit, SimpleHealth.NET_CRIT_BITS)
			for _, pool in ipairs(SimpleHealth.POOLS) do
				net.WriteUInt(quantizePool(state[pool]), SimpleHealth.NET_POOL_BITS)
			end
			net.WriteFloat(countdownEnd)
		end
	net.Send(owner)
end

local function die(org, cause)
	organism.SetDeathCause(org, "simplehealth: " .. cause)
	org.alive = false
end

module[1] = function(org)
	local owner = org.owner
	local isPlayer = IsValid(owner) and owner:IsPlayer()
	local mode = isPlayer and SimpleHealth.ConVar:GetInt() or 0

	org.simpleMode = mode > 0 and mode or nil
	org.simple = org.simpleMode and newState() or nil
	org.simpleNetSignature = nil
	if org.simple then org.simple.aedMark = org.aedResuscitationUntil end

	SimpleHealth.WrapInputs()

	if isPlayer then sendState(owner, org, true) end
end

SimpleHealth.ModuleOverrides.pulse = function(owner, org, timeValue)
	if not org.alive then
		organism.BeginPostMortemDecay(org)
		org.heartstop = true

		return
	end

	org.postMortemVitals = nil
	org.postMortemStart = nil
	org.ischemia = 0

	local brainBefore = org.brain
	organism.MaintainSimplifiedCirculation(org)
	org.brain = brainBefore

	local state = org.simple
	local heartDamage = org.simpleMode == MODE_ORGANS and math.Clamp(tonumber(org.heart) or 0, 0, 1) or 0
	local heartEfficiency = heartDamage >= CONFIG.organs.heartMax and 0 or 1 - heartDamage
	state.heartEfficiency = heartEfficiency
	if heartEfficiency >= 1 then return end

	org.cardiacOutput = heartEfficiency
	for _, key in ipairs(PERFUSION_KEYS) do
		org[key] = math.min(tonumber(org[key]) or 1, heartEfficiency)
	end

	if org.brainoxygen < LOW_BRAIN_OXYGEN then
		org.consciousness = math.min(org.consciousness or 1, 0.15 + org.brainoxygen / LOW_BRAIN_OXYGEN * 0.55)
	end
end

SimpleHealth.ModuleOverrides.lungs = function(owner, org, timeValue, callback)
	for _, sanitize in ipairs(SimpleHealth.Sanitizers) do
		sanitize(owner, org, org.simple, timeValue)
	end

	callback(owner, org, timeValue)
end

local function tickOxy(owner, org, state, timeValue)
	local oxyConfig = CONFIG.oxy
	local now = CurTime()
	local crit = state.crit
	local adrenaline = math.Clamp((tonumber(org.adrenaline) or 0) / CONFIG.adrenalineFull, 0, 1)
	local gainMul = Lerp(adrenaline, 1, oxyConfig.adrenalineGainMul)
	if (state.aedResistUntil or 0) > now then gainMul = gainMul * oxyConfig.aedGainMul end

	local delivery = math.Clamp(tonumber(org.brainoxygen) or 1, 0, 1)
	local deficit = math.Clamp((oxyConfig.deliveryFull - delivery) / oxyConfig.deliveryFull, 0, 1)
	local gain = deficit * oxyConfig.deliveryGain
	if state.heartEfficiency <= 0 then gain = gain + oxyConfig.heartDestroyedGain end
	if crit == CRIT_HARD then gain = gain + oxyConfig.hardCritGain end

	local overdose, sedative = SimpleHealth.GetOverdose(org)
	gain = gain + math.min(sedative, overdose) * oxyConfig.sedativeGain + (state.oxyGainBonus or 0)

	local oxy = state.oxy
	if crit == CRIT_SOFT and oxy < oxyConfig.softCritCap then
		oxy = math.min(oxy + oxyConfig.softCritGain * gainMul * timeValue, oxyConfig.softCritCap)
	end

	oxy = oxy + gain * gainMul * timeValue

	local floor = crit == CRIT_SOFT and oxyConfig.softCritCap or 0
	if gain <= 0 and crit ~= CRIT_HARD and oxy > floor then
		oxy = math.max(oxy - oxyConfig.regen * timeValue, floor)
	end

	oxy = oxy - oxyConfig.adrenalineClear * adrenaline * timeValue
	state.oxy = math.Clamp(oxy, 0, CONFIG.poolMax)
	state.oxyGain = gain

	if state.oxy > oxyConfig.brainDamageStart then
		local range = math.max(oxyConfig.brainDamageFull - oxyConfig.brainDamageStart, 1)
		local severity = math.Clamp((state.oxy - oxyConfig.brainDamageStart) / range, 0, 1)
		org.brain = math.min((org.brain or 0) + oxyConfig.brainDamageRate * severity * timeValue, 1)
	end
end

local function tickRegen(owner, org, state, timeValue)
	local damageConfig = CONFIG.damage
	if damageConfig.bruteRegen > 0 then state.brute = math.max(state.brute - damageConfig.bruteRegen * timeValue, 0) end
	if damageConfig.burnRegen > 0 then state.burn = math.max(state.burn - damageConfig.burnRegen * timeValue, 0) end
end

table.insert(SimpleHealth.Tickers, tickOxy)
table.insert(SimpleHealth.Tickers, tickRegen)

local function updateCrit(org, state)
	local previous = state.crit
	state.health = SimpleHealth.GetHealth(state)
	state.crit = SimpleHealth.GetCritState(state.health, org.adrenaline)

	if state.crit >= CRIT_SOFT then org.needfake = true end
	if state.crit == CRIT_HARD then org.needotrub = true end

	if state.crit ~= previous then
		hook.Run("hg/simplehealth/crit-changed", org.owner, org, state.crit, previous)
	end
end

local function updateCountdown(owner, org, state)
	local oxyConfig = CONFIG.oxy
	local now = CurTime()
	local wasCounting = state.countdownStart ~= nil

	if state.oxy > oxyConfig.countdownStart and org.otrub then
		state.countdownStart = state.countdownStart or now
	else
		state.countdownStart = nil
	end

	local counting = state.countdownStart ~= nil
	if counting ~= wasCounting then
		hook.Run("hg/simplehealth/countdown-changed", owner, org, counting)
	end

	org.defibDeathGrace = nil
	org.deathStateRemaining = nil

	local elapsed = counting and now - state.countdownStart or 0
	org.incapacitated = counting and elapsed >= oxyConfig.countdownTrackAt
	org.incapReason = org.incapacitated and "oxy" or nil
	if org.incapacitated then
		org.deathStateEnd = state.countdownStart + oxyConfig.countdownTime
	end

	return counting and elapsed >= oxyConfig.countdownTime
end

module[2] = function(owner, org, timeValue)
	local state = SimpleHealth.GetState(org)
	if not state or not org.alive then return end

	for _, tick in ipairs(SimpleHealth.Tickers) do
		tick(owner, org, state, timeValue)
	end

	updateCrit(org, state)

	local countdownExpired = updateCountdown(owner, org, state)
	local brainIgnored = organism.IsBrainDamageIgnored and organism.IsBrainDamageIgnored(org)

	if countdownExpired then
		die(org, "oxy countdown expired")
	elseif org.otrub and (tonumber(org.blood) or CONFIG.contamination.normalBlood) < CONFIG.deathBlood then
		die(org, "blood below " .. CONFIG.deathBlood .. " while unconscious")
	elseif not brainIgnored and (tonumber(org.brain) or 0) >= CONFIG.brainDeath then
		die(org, "brain death")
	end

	sendState(owner, org)
end

local function classifyDamage(dmgInfo)
	if dmgInfo:IsDamageType(DMG_DROWN) then return "oxy" end
	if dmgInfo:IsDamageType(TOXIN_TYPES) then return "toxin" end
	if dmgInfo:IsDamageType(BURN_TYPES) then return "burn" end

	return "brute"
end

hook.Add("HomigradDamage", "hg/simplehealth/damage-pools", function(victim, dmgInfo)
	local org = IsValid(victim) and victim.organism
	local state = SimpleHealth.GetState(org)
	if not state then return end

	local damage = dmgInfo:GetDamage()
	if damage <= 0 then return end

	local damageConfig = CONFIG.damage
	local pool = classifyDamage(dmgInfo)
	if pool == "burn" and dmgInfo:IsDamageType(DMG_BLAST) then
		local burnShare = damageConfig.blastBurnShare
		SimpleHealth.AddDamage(org, "brute", damage * (1 - burnShare) * damageConfig.bruteScale)
		SimpleHealth.AddDamage(org, "burn", damage * burnShare * damageConfig.burnScale)

		return
	end

	SimpleHealth.AddDamage(org, pool, damage * damageConfig[pool .. "Scale"])
end)

local GATED_INPUTS = {
	heart = MODE_ORGANS,
	liver = MODE_ORGANS,
	flank = MODE_ORGANS,
	gut = MODE_ORGANS,
	lungsL = MODE_ORGANS,
	lungsR = MODE_ORGANS,
	trachea = false,
	eyeL = false,
	eyeR = false,
}

SimpleHealth.OriginalInputs = SimpleHealth.OriginalInputs or {}
SimpleHealth.InputWrappers = SimpleHealth.InputWrappers or {}
SimpleHealth.InputHandlers = SimpleHealth.InputHandlers or {}

local function wrapInput(inputList, name, allowedMode)
	local original = inputList[name]
	if not isfunction(original) or original == SimpleHealth.InputWrappers[name] then return end

	SimpleHealth.OriginalInputs[name] = original

	local function wrapper(org, ...)
		local mode = org.simpleMode
		if not mode then return original(org, ...) end
		if mode ~= allowedMode then return 0 end

		local handler = SimpleHealth.InputHandlers[name]
		if handler then return handler(original, org, ...) end

		return original(org, ...)
	end

	SimpleHealth.InputWrappers[name] = wrapper
	inputList[name] = wrapper
end

function SimpleHealth.WrapInputs()
	local inputList = organism.input_list
	if not inputList then return end

	for name, allowedMode in pairs(GATED_INPUTS) do
		wrapInput(inputList, name, allowedMode)
	end
end

SimpleHealth.WrapInputs()
hook.Add("InitPostEntity", "hg/simplehealth/wrap-inputs", SimpleHealth.WrapInputs)

local function sanitizeOrgans(owner, org)
	org.trachea = 0
	org.eyeL = 0
	org.eyeR = 0

	if org.simpleMode == MODE_ORGANS then
		org.heart = math.min(tonumber(org.heart) or 0, CONFIG.organs.heartMax)

		return
	end

	org.heart = 0
	org.liver = 0
	org.flank = 0
	org.gut = 0
	org.pneumothorax = 0
	org.hemothorax = 0
	org.hemothoraxL = 0
	org.hemothoraxR = 0
	org.hemothoraxTrauma = 0
	org.cardiacTamponade = 0

	for _, key in ipairs(LUNG_KEYS) do
		local lung = org[key]
		if istable(lung) then
			lung[1] = 0
			lung[2] = 0
		end
	end
end

table.insert(SimpleHealth.Sanitizers, sanitizeOrgans)

function SimpleHealth.AddContamination(org, amount)
	local state = SimpleHealth.GetState(org)
	if not state or not amount or amount <= 0 then return end

	state.contamination = math.min(state.contamination + amount, CONFIG.contamination.max)
end

local function convertPoisons(owner, org, state)
	local contaminationConfig = CONFIG.contamination
	local now = CurTime()

	for key, onset in pairs(contaminationConfig.poisonOnset) do
		local started = org[key]
		if isnumber(started) and started + onset <= now then
			SimpleHealth.AddContamination(org, contaminationConfig.poisonDose[key])
			org[key] = nil
			org[key .. "notificate"] = nil
			hook.Run("hg/simplehealth/poisoned", owner, org, key)
		end
	end

	local shock = tonumber(org.hemotransfusionshock) or 0
	if shock > 0 then
		SimpleHealth.AddContamination(org, shock * contaminationConfig.wrongBloodPerShock)
		org.hemotransfusionshock = 0
	end

	org.sepsisSource = 0
end

table.insert(SimpleHealth.Sanitizers, convertPoisons)

local function tickBloodExchange(org, state, timeValue)
	local toxinConfig = CONFIG.toxin
	local contaminationConfig = CONFIG.contamination
	local blood = math.max(tonumber(org.blood) or contaminationConfig.normalBlood, 0)
	local lastBlood = state.lastBlood or blood
	state.lastBlood = blood

	local delta = blood - lastBlood
	if delta < 0 and lastBlood > 0 then
		state.contamination = state.contamination * math.Clamp(blood / lastBlood, 0, 1)
		SimpleHealth.Heal(org, "toxin", -delta * toxinConfig.bloodLossHealPerMl)

		return
	end

	local transfused = delta - (tonumber(org.bloodRegenRate) or 0) * timeValue
	if transfused <= contaminationConfig.transfusionMinMl then return end

	state.contamination = state.contamination * lastBlood / math.max(lastBlood + transfused, 1)
	SimpleHealth.Heal(org, "toxin", transfused * toxinConfig.transfusionHealPerMl)
end

function SimpleHealth.GetOverdose(org)
	local toxinConfig = CONFIG.toxin
	local opioid = math.max((tonumber(org.analgesia) or 0) - toxinConfig.opioidSafeDose, 0)
	local painkiller = math.max((tonumber(org.painkiller) or 0) - toxinConfig.painkillerSafeDose, 0)
	local sedative = math.max((tonumber(org.tranquilizer) or 0) - toxinConfig.tranquilizerSafeDose, 0)

	return math.min(opioid + painkiller + sedative, toxinConfig.overdoseCap), sedative
end

local function tickToxin(owner, org, state, timeValue)
	local toxinConfig = CONFIG.toxin

	tickBloodExchange(org, state, timeValue)

	if state.contamination > 0 then
		SimpleHealth.AddDamage(org, "toxin", state.contamination * CONFIG.contamination.toxinGain * timeValue)
	end

	local overdose = SimpleHealth.GetOverdose(org)
	if overdose > 0 then
		SimpleHealth.AddDamage(org, "toxin", overdose * toxinConfig.overdoseGain * timeValue)
	end

	state.thiamineActive = (tonumber(org.thiamine) or 0) > 0
	if state.thiamineActive then
		SimpleHealth.Heal(org, "toxin", toxinConfig.thiamineHeal * timeValue)
		state.contamination = math.max(state.contamination - toxinConfig.thiamineContaminationClear * timeValue, 0)
	end

	SimpleHealth.Heal(org, "toxin", toxinConfig.regen * (state.toxinRegenMul or 1) * timeValue)
end

local function tickResuscitation(owner, org, state, timeValue)
	local oxyConfig = CONFIG.oxy
	local now = CurTime()

	if (org.cprSupportUntil or 0) > now and (state.nextCprClear or 0) <= now then
		state.nextCprClear = now + oxyConfig.cprCycle
		SimpleHealth.Heal(org, "oxy", oxyConfig.cprClear)
	end

	local aedMark = org.aedResuscitationUntil
	if aedMark and aedMark > now and aedMark ~= state.aedMark then
		state.aedMark = aedMark
		state.aedResistUntil = now + oxyConfig.aedResistTime
	end
end

table.insert(SimpleHealth.Tickers, tickToxin)
table.insert(SimpleHealth.Tickers, tickResuscitation)

local KIT_POOLS = {"brute", "burn"}

function SimpleHealth.OnBandageApplied(org)
	SimpleHealth.Heal(org, "burn", CONFIG.medicine.bandageBurnHeal)
end

function SimpleHealth.AppendKitHealData(org, entries, rotations, cost, available)
	local state = SimpleHealth.GetState(org)
	if not state then return rotations, cost end

	local medicineConfig = CONFIG.medicine
	for _, pool in ipairs(KIT_POOLS) do
		local affordable = cost + medicineConfig.kitCost <= available + 0.001
		if affordable and state[pool] >= medicineConfig.kitMinDamage then
			cost = cost + medicineConfig.kitCost
			rotations = rotations + 1
			entries[#entries + 1] = {
				key = "simple_" .. pool,
				pool = pool,
				cost = medicineConfig.kitCost,
				heal = medicineConfig.kitHeal[pool],
				simplePool = true,
			}
		end
	end

	return rotations, cost
end

function SimpleHealth.ApplyKitHeal(org, data)
	local healed = SimpleHealth.Heal(org, data.pool, data.heal)

	return healed > 0 and CONFIG.medicine.kitHealedScore or 0
end

local DEFAULT_COAGULATION = 1.2
local DEFAULT_BLOOD_REGENERATION = 1.2
local DESTROYED = 1

local function organDamage(org, key)
	return math.Clamp(tonumber(org[key]) or 0, 0, 1)
end

local function lungSeverity(org)
	local damage = 0
	for _, key in ipairs(LUNG_KEYS) do
		local lung = org[key]
		damage = damage + (istable(lung) and math.Clamp(tonumber(lung[1]) or 0, 0, 1) or 0)
	end

	return math.max(damage / #LUNG_KEYS, math.Clamp(tonumber(org.pneumothorax) or 0, 0, 1))
end

SimpleHealth.ModuleOverrides.liver = function(owner, org)
	if not org.alive then return end

	local bleedMul = 1
	if org.simpleMode == MODE_ORGANS then
		local organConfig = CONFIG.organs
		bleedMul = (1 + organDamage(org, "liver") * organConfig.liverBleedMul)
			* (1 + organDamage(org, "flank") * organConfig.flankBleedMul)
			* (1 + organDamage(org, "gut") * organConfig.gutBleedMul)
	end

	org.bleedingmul = bleedMul
	org.coagulation_multiplier = DEFAULT_COAGULATION
	org.blood_regeneration_multiplier = DEFAULT_BLOOD_REGENERATION
end

local function tickOrgans(owner, org, state, timeValue)
	if org.simpleMode ~= MODE_ORGANS then
		state.toxinRegenMul = 1
		state.oxyGainBonus = 0

		return
	end

	local organConfig = CONFIG.organs
	local liver = organDamage(org, "liver")
	local flank = organDamage(org, "flank")
	local gut = organDamage(org, "gut")
	local flankDestroyed = flank >= DESTROYED

	local flankRegenMul = flankDestroyed and 1 - organConfig.flankDestroyedRegenPenalty or 1
	state.toxinRegenMul = math.max((1 - liver * organConfig.liverRegenPenalty) * flankRegenMul, 0)

	if not state.thiamineActive then
		local organToxin = liver * organConfig.liverToxinGain
		if flankDestroyed then organToxin = organToxin + organConfig.flankDestroyedToxinGain end
		SimpleHealth.AddDamage(org, "toxin", organToxin * timeValue)
	end

	local lungStart = organConfig.lungGainStart
	local lungLoad = math.max(lungSeverity(org) - lungStart, 0) / (1 - lungStart)
	state.oxyGainBonus = lungLoad * CONFIG.oxy.lungGain

	local treated = (tonumber(org.tranexamic_acid) or 0) > 0 or (tonumber(org.internalBleedHeal) or 0) > 0
	if treated then return end

	local floors = organConfig.internalBleedFloor
	local bleedFloor = liver * floors.liver + flank * floors.flank + gut * floors.gut
	if bleedFloor > (tonumber(org.internalBleed) or 0) then org.internalBleed = bleedFloor end
end

table.insert(SimpleHealth.Tickers, tickOrgans)

local function abdominalHit(key)
	return function(original, org, bone, dmg, dmgInfo, ...)
		local organConfig = CONFIG.organs
		local before = organDamage(org, key)
		local result = original(org, bone, dmg, dmgInfo, ...)

		if before >= DESTROYED then
			organism.AddPain(org, organConfig.destroyedHitPain, "body")
			org.internalBleed = (tonumber(org.internalBleed) or 0) + organConfig.destroyedHitBleed

			return result
		end

		local harmed = organDamage(org, key) - before
		local owner = org.owner
		if harmed < organConfig.stunDamageMin or not IsValid(owner) or not owner:IsPlayer() then return result end

		local duration = Lerp(harmed, organConfig.stunMin, organConfig.stunMax)
		timer.Simple(0, function()
			if not IsValid(owner) or not owner:Alive() or owner.organism ~= org then return end

			local remaining = (tonumber(org.stun) or 0) - CurTime()
			hg.StunPlayer(owner, math.max(duration, remaining))
		end)

		return result
	end
end

SimpleHealth.InputHandlers.liver = abdominalHit("liver")
SimpleHealth.InputHandlers.flank = abdominalHit("flank")
SimpleHealth.InputHandlers.gut = abdominalHit("gut")

local THOUGHT_COLOR = Color(255, 150, 150)
local FAINT_SOUND_KEYS = {
	[SimpleHealth.FAINT_FOOTSTEPS] = "footsteps",
	[SimpleHealth.FAINT_GUNFIRE] = "gunfire",
}

SimpleHealth.FaintListeners = SimpleHealth.FaintListeners or {}

local faintListeners = SimpleHealth.FaintListeners

function SimpleHealth.GetCrit(ply)
	local state = IsValid(ply) and SimpleHealth.GetState(ply.organism)

	return state and state.crit or CRIT_NONE
end

function SimpleHealth.IsWhisperForced(ply)
	return SimpleHealth.GetCrit(ply) == CRIT_SOFT
end

local function stateThought(owner, key, text)
	if not IsValid(owner) or not owner:IsPlayer() or not owner.Thought then return end

	owner:Thought(text, CONFIG.chat.thoughtCooldown, "simplehealth_" .. key, 1, THOUGHT_COLOR)
end

hook.Add("hg/simplehealth/crit-changed", "hg/simplehealth/chat", function(owner, org, crit, previous)
	if not IsValid(owner) or not owner:IsPlayer() then return end

	if crit == CRIT_SOFT or previous == CRIT_SOFT then owner.ChatWhisper = crit == CRIT_SOFT end

	if crit == CRIT_SOFT and previous == CRIT_NONE then
		hg.ChatLog.Emit("softcrit", owner)
		stateThought(owner, "softcrit", "I can't get up...")
	elseif crit == CRIT_HARD then
		stateThought(owner, "hardcrit", "Everything is going dark")
	end
end)

hook.Add("hg/simplehealth/countdown-changed", "hg/simplehealth/chat", function(owner, org, counting)
	if counting and IsValid(owner) then hg.ChatLog.Emit("stopbreathing", owner) end
end)

hook.Add("hg/simplehealth/poisoned", "hg/simplehealth/chat", function(owner)
	stateThought(owner, "poisoned", "Something is wrong with me... I feel sick.")
end)

local function tickSymptoms(owner, org, state)
	local oxyConfig = CONFIG.oxy
	local organConfig = CONFIG.organs
	local now = CurTime()

	if state.oxy >= oxyConfig.gaspAt and not state.gasping then
		state.gasping = true
		hg.ChatLog.Emit("airgasp", owner)
		if not org.otrub then stateThought(owner, "gasp", "I can't breathe...") end
	elseif state.oxy < oxyConfig.gaspAt - oxyConfig.gaspHysteresis then
		state.gasping = false
	end

	local bleedingInside = (tonumber(org.internalBleed) or 0) >= organConfig.coughBloodAt
	if bleedingInside and not org.otrub and (state.nextCoughBlood or 0) <= now then
		state.nextCoughBlood = now + organConfig.coughBloodInterval
		organism.CoughBlood(org)
		hg.ChatLog.Emit("coughblood", owner)
	end

	faintListeners[owner] = org.otrub and true or nil
end

table.insert(SimpleHealth.Tickers, tickSymptoms)

local function sendFaint(listener, kind, text)
	net.Start("hg_simplehealth_faint")
		net.WriteUInt(kind, SimpleHealth.NET_FAINT_BITS)
		if kind == SimpleHealth.FAINT_SPEECH then net.WriteString(text) end
	net.Send(listener)
end

local function isFaintListener(listener)
	local org = IsValid(listener) and listener:Alive() and listener.organism

	return org and org.otrub and SimpleHealth.GetState(org) ~= nil
end

local function forEachFaintListener(source, pos, range, callback)
	local rangeSqr = range * range

	for listener in pairs(faintListeners) do
		if not isFaintListener(listener) then
			faintListeners[listener] = nil
		elseif listener ~= source and hg.GetCurrentCharacter(listener):GetPos():DistToSqr(pos) <= rangeSqr then
			callback(listener)
		end
	end
end

local function sendFaintSound(listener, kind)
	local key = FAINT_SOUND_KEYS[kind]
	local now = CurTime()
	listener.hgSimpleFaintNext = listener.hgSimpleFaintNext or {}
	if (listener.hgSimpleFaintNext[key] or 0) > now then return end

	listener.hgSimpleFaintNext[key] = now + CONFIG.chat.faintSoundCooldown
	sendFaint(listener, kind)
end

local function partialSpeech(text)
	local chatConfig = CONFIG.chat
	text = utf8.force(text)

	local length = utf8.len(text)
	if not length or length <= 0 then return end

	local keep = math.max(math.floor(length * math.Rand(chatConfig.faintKeepMin, chatConfig.faintKeepMax)), 1)
	local first = math.random(1, length - keep + 1)

	return "..." .. utf8.sub(text, first, first + keep - 1) .. "..."
end

hook.Add("HG_PlayerSay", "hg/simplehealth/faint-speech", function(speaker, textTable)
	if next(faintListeners) == nil then return end
	if not IsValid(speaker) or not speaker:Alive() or (speaker.organism and speaker.organism.otrub) then return end

	local text = textTable[1]
	if not isstring(text) or text == "" then return end

	local chatConfig = CONFIG.chat
	forEachFaintListener(speaker, speaker:GetPos(), chatConfig.faintHearRange, function(listener)
		if math.Rand(0, 1) > chatConfig.faintHearChance then return end

		local partial = partialSpeech(text)
		if partial then sendFaint(listener, SimpleHealth.FAINT_SPEECH, partial) end
	end)
end)

hook.Add("PlayerFootstep", "hg/simplehealth/faint-footsteps", function(ply, pos)
	if next(faintListeners) == nil then return end

	forEachFaintListener(ply, pos, CONFIG.chat.faintHearRange, function(listener)
		sendFaintSound(listener, SimpleHealth.FAINT_FOOTSTEPS)
	end)
end)

hook.Add("EntityFireBullets", "hg/simplehealth/faint-gunfire", function(shooter)
	if next(faintListeners) == nil or not IsValid(shooter) then return end

	forEachFaintListener(shooter, shooter:GetPos(), CONFIG.chat.faintGunfireRange, function(listener)
		sendFaintSound(listener, SimpleHealth.FAINT_GUNFIRE)
	end)
end)
