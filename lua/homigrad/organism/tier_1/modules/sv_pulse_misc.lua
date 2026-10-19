local max = math.max
local Clamp = math.Clamp

local function getLowPulseSeverity(pulse)
	return Clamp((70 - max(tonumber(pulse) or 0, 0)) / 70, 0, 1)
end

local ENCLOSURE_SAMPLE_INTERVAL = 2
local ENCLOSURE_TRACE_LEN = 32768
local ENCLOSURE_INDOOR_COLD = 0.35
local ENCLOSURE_ROCK_COLD = 1.9
local ENCLOSURE_ROCK_FULL = 768
local enclosureUp = Vector(0, 0, ENCLOSURE_TRACE_LEN)
local enclosureTrace = {mask = MASK_SOLID_BRUSHONLY}

local function measureOverheadRock(start)
	local rock, enclosed = 0, false
	for _ = 1, 6 do
		enclosureTrace.start = start
		enclosureTrace.endpos = start + enclosureUp
		local tr = util.TraceLine(enclosureTrace)
		if not tr.Hit or tr.HitSky then return rock, enclosed end
		enclosed = true
		local entry = tr.HitPos + vector_up
		enclosureTrace.start = entry
		enclosureTrace.endpos = entry + enclosureUp
		local inside = util.TraceLine(enclosureTrace)
		if inside.AllSolid then return ENCLOSURE_ROCK_FULL, true end
		if not inside.StartSolid then return rock, true end
		local thickness = inside.FractionLeftSolid * ENCLOSURE_TRACE_LEN
		rock = rock + thickness + 1
		if rock >= ENCLOSURE_ROCK_FULL then return rock, true end
		start = entry + vector_up * (thickness + 1)
	end
	return rock, enclosed
end

local function getEnclosureCold(ent)
	local now = CurTime()
	if (ent.hgEnclosureColdNext or 0) > now then return ent.hgEnclosureCold or 0 end
	ent.hgEnclosureColdNext = now + ENCLOSURE_SAMPLE_INTERVAL

	local rock, enclosed = measureOverheadRock(ent:WorldSpaceCenter())
	local cold = enclosed and ENCLOSURE_INDOOR_COLD + Clamp(rock / ENCLOSURE_ROCK_FULL, 0, 1) * ENCLOSURE_ROCK_COLD or 0
	ent.hgEnclosureCold = cold
	return cold
end

local hypotensionThoughts = {
	"My limbs feel weak and cold...",
	"I can barely make myself move...",
	"My body feels heavy and sluggish...",
}
local hypertensionThoughts = {
	"My blood pressure feels dangerously high...",
	"My head is pounding from the pressure...",
	"I feel pressure building in my head...",
}

function hg.organism.UpdateCirculatoryEffects(owner, org, timeValue, o2Value, arrhythmiaComplication)
	local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
	local adrenalineStabilizer = totalAdrenaline > 0.8

	local hasAntiIschemia = (org.tranexamic_acid or 0) > 0 or (org.thiamine or 0) > 0

	if org.ischemia > 0 then
		if org.ischemia > 1 and not adrenalineStabilizer and not hasAntiIschemia then
			local ischemiaK = math.Clamp((org.ischemia - 1) / 5, 0, 1)
			local damage = timeValue * ischemiaK * 0.007
			org.brain = math.min(org.brain + damage * 0.2, 1)
			org.heart = math.min(org.heart + damage, 1)
			org.liver = math.min(org.liver + damage * 0.5, 1)
			org.stomach = math.min(org.stomach + damage * 0.3, 1)
			org.intestines = math.min(org.intestines + damage * 0.3, 1)
		end

		local decayRate = (adrenalineStabilizer or hasAntiIschemia) and timeValue / 4 or timeValue / 10
		decayRate = decayRate * (1 - math.Clamp(arrhythmiaComplication * 0.9, 0, 0.9))
		org.ischemia = math.max(org.ischemia - decayRate, 0)
	end

	if org.hypotension > 0.55 then
		local disorientK = math.Clamp((org.hypotension - 0.55) / 0.35, 0, 1)
		org.disorientation = math.max(org.disorientation, 0.25 + disorientK * 1.25)

		if org.isPly and not org.otrub then
			org.owner:Notify(hypotensionThoughts[math.random(#hypotensionThoughts)], 40, "hypotension", 0, nil, Color(170, 170, 220))
		end
	end

	if org.hypotension > 0.64 then
		local shockK = math.Clamp((org.hypotension - 0.64) / 0.36, 0, 1)
		org.shock = math.Approach(org.shock, math.max(org.shock, shockK * 20), timeValue * (0.5 + shockK * 1.5))
	end

	if org.hypotension > 0.5 and o2Value <= 15 then
		local lowK = math.Clamp((org.hypotension - 0.35) / 0.5, 0, 1)
		org.consciousness = math.Approach(org.consciousness, 0.75, timeValue * (0.08 + lowK * 0.11))
		if org.isPly and not org.otrub then
			org.owner:Notify("My limbs feel weak...", true, "low_perfusion", 0, nil, Color(200, 170, 170))
		end
	end

	if org.hypertension > 0.35 and org.isPly and not org.otrub then
		org.owner:Notify(hypertensionThoughts[math.random(#hypertensionThoughts)], 40, "hypertension", 0, nil, Color(220, 170, 170))
	end

	if org.hypertension > 0 then
		local highK = math.Clamp(org.hypertension * 1.27, 0, 1)
		local adrenalineMitigation = math.Clamp(org.adrenaline / 3, 0, 1) * 0.25
		local effectiveHighK = highK * (1 - adrenalineMitigation)
		org.disorientation = math.max(org.disorientation, 0.25 + effectiveHighK * 1.5)
		org.shock = math.Approach(org.shock, math.max(org.shock, 10 + effectiveHighK * 20), timeValue * (0.4 + effectiveHighK * 1.4))
	end

	local fearless = IsValid(owner) and owner.HasTrait and owner:HasTrait("gurajchaka_child")
	if fearless then
		org.fear = 0
		org.fearadd = 0
	else
	org.fear = math.Approach(org.fear, (org.otrub and 0 or (org.fearadd > 0 and 1 or -1)), org.otrub and timeValue * 0.5 or (org.fearadd > 0 and (org.fear < 0 and timeValue * 5 * org.fearadd or timeValue / 5 * org.fearadd) or (org.fear <= 0 and timeValue / 240 or timeValue / 50)))
	-- less time to start fearing, more time to become calm again
	-- if no fear, in 3 minutes become slightly talkative, so would say random phrases to calm themselves in a current situation
	local gainfear = hg.organism.should_gain_fear(org)
	org.fearadd = math.Approach(org.fearadd, 0, gainfear and timeValue or timeValue / 4.9) -- 15 seconds to stop fearing something and start to calm down
	local fearGainRate = gainfear and timeValue / 5 or 0
	org.fearadd = math.Approach(org.fearadd, 1, fearGainRate)
	end
end

function hg.organism.UpdateBodyTemperature(owner, org, timeValue)
	local lowPulseCold = Clamp(getLowPulseSeverity(org.pulse) / (55 / 70), 0, 1)
	local needed_temp = math.min(36.7 - lowPulseCold * 5.7, org.lowBloodTemperatureTarget or 36.7)
	if IsValid(owner) then
		local character = hg.GetCurrentCharacter(owner)
		if not IsValid(character) then character = owner end
		local envCold = getEnclosureCold(character)
		if envCold > 0 then needed_temp = math.min(needed_temp, 36.7 - envCold) end
	end
	if StormFox2 and StormFox2.Loaded and StormFox2.Setting.SFEnabled() and IsValid(owner) then
		local character = hg.GetCurrentCharacter(owner)
		if not IsValid(character) then character = owner end
		local inWater = character:WaterLevel() > 0
		if inWater or StormFox2.Wind.IsEntityInWind(character) then
			local cold = math.max(10 - StormFox2.Temperature.Get(), 0)
			needed_temp = math.min(needed_temp, math.max(20, 36.7 - cold * (inWater and 0.4 or 0.25)))
		end
	end
	local changeRate = timeValue / 60
	changeRate = changeRate * (org.temperature < needed_temp and math.Clamp(org.heatbuff / 60, 1, 2) or 1)
	local equipmentChangeRate = hook.Run("ZC_BodyTemperature", owner, org, timeValue, changeRate, 1, 1)
	changeRate = equipmentChangeRate or changeRate
	if math.abs(org.tempchanging) < changeRate then
		org.temperature = math.Approach(org.temperature, needed_temp, changeRate)
	else
		org.needed_temp = needed_temp
	end
end
