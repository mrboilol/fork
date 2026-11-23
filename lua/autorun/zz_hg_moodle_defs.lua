if SERVER then
	AddCSLuaFile()
	return
end

hg = hg or {}

local MB = hg.MoodleBase
if not MB then return end

local Define = MB.Define

local function num(org, key, fallback)
	local value = org[key]
	return isnumber(value) and value or fallback or 0
end

local function high(value, stops)
	local rank = 0
	for level = 1, 4 do if value >= stops[level] then rank = level end end
	return rank
end

local function low(value, stops)
	local rank = 0
	for level = 1, 4 do if value <= stops[level] then rank = level end end
	return rank
end

local function pct(value)
	return math.floor(value * 100) .. "%"
end

local function countEntries(tbl)
	if not istable(tbl) then return 0 end
	local count = 0
	for _, value in pairs(tbl) do if value ~= nil and value ~= false and value ~= "" then count = count + 1 end end
	return count
end

local function gauge(id, position, key, stops, def)
	def.position = position
	def.active = function(_, org)
		local value = num(org, key)
		local level = high(value, stops)
		if level > 0 then return level, pct(value) end
	end
	Define(id, def)
end

local limbKeys = {"larm", "rarm", "lleg", "rleg"}
local circulationStops = {0.1, 0.3, 0.6, 0.85}
local mentalStops = {0.5, 0.625, 0.75, 0.875}
local staminaStops = {0.75, 0.5, 0.25, 0.1}
local severeStops = {0.25, 0.5, 0.75, 0.95}

local function tourniquetLimb(bone)
	if not isstring(bone) then return nil end
	local side = string.find(bone, "_L_", 1, true) and "l" or string.find(bone, "_R_", 1, true) and "r" or nil
	if not side then return nil end
	if string.find(bone, "Arm", 1, true) or string.find(bone, "Hand", 1, true) then return side .. "arm" end
	if string.find(bone, "Thigh", 1, true) or string.find(bone, "Calf", 1, true) or string.find(bone, "Foot", 1, true) then return side .. "leg" end
end

local function tourniquetedLimbs(ply)
	local result = {}
	for _, data in pairs(ply:GetNetVar("Tourniquets", {}) or {}) do
		local limb = tourniquetLimb(istable(data) and data[3] or nil)
		if limb then result[limb] = true end
	end
	return result
end

local function tissueFindings(org)
	local SoftTissue = hg.SoftTissue
	local found, worst = {}, 0
	if not SoftTissue then return found, worst end

	for _, limb in ipairs(SoftTissue.LIMBS) do
		for _, kind in ipairs(SoftTissue.KINDS) do
			local value = SoftTissue.Get(org, kind, limb)
			local key = SoftTissue.GetSeverityKey(value)
			if key then
				found[#found + 1] = {value = value, text = string.lower(SoftTissue.LIMB_NAMES[limb]) .. " " .. SoftTissue.Config.wording[kind][key]}
				worst = math.max(worst, SoftTissue.Config.severityRank[key])
			end
		end
	end
	table.sort(found, function(a, b) return a.value > b.value end)

	return found, worst
end

local function muscleFindings(org)
	local SoftTissue = hg.SoftTissue
	local found, worst = {}, 0
	if not SoftTissue then return found, worst end

	for limb in pairs(SoftTissue.Config.muscle.limbs) do
		local value = SoftTissue.GetMuscle(org, limb)
		local key = SoftTissue.GetSeverityKey(value, SoftTissue.Config.muscle.severity)
		if key then
			found[#found + 1] = {value = value, text = string.lower(SoftTissue.LIMB_NAMES[limb]) .. " " .. SoftTissue.Config.wording.muscle[key]}
			worst = math.max(worst, SoftTissue.Config.severityRank[key])
		end
	end
	table.sort(found, function(a, b) return a.value > b.value end)

	return found, worst
end

local function joinFindings(found)
	local parts = {}
	for index = 1, math.min(#found, 3) do parts[index] = found[index].text end
	local text = table.concat(parts, ", ")

	return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2) .. "."
end

local function countFractures(org)
	local count = 0
	for _, limb in ipairs(limbKeys) do
		if hg.IsLimbFractured(org, limb) and org[limb .. "amputated"] ~= true then count = count + 1 end
	end
	return count
end

local function countDislocations(org)
	local count = 0
	for _, limb in ipairs(limbKeys) do
		if org[limb .. "dislocation"] == true or org[limb .. "dislocated"] == true then count = count + 1 end
	end
	return count
end

local irregularECG = {
	ventricular_ectopy = 0.35, ventricular_bigeminy = 0.65, atrial_fibrillation = 0.65, hypothermia_bradycardia = 0.45,
	av_block_partial = 0.45, av_block_complete = 0.75, ventricular_escape = 0.75, junctional_escape = 0.55,
	sinus_pause = 0.55, cerebral_irregular = 0.55, ventricular_tachycardia = 0.9, torsades_de_pointes = 0.95,
}

local function cardiac(org)
	if org.heartstop then return end

	local ecgState, unstable = org.ecgState, org.unstableRhythm
	local irregularSeverity = irregularECG[ecgState] or 0
	local fibrillating = org.fibrillation == true or ecgState == "atrial_fibrillation" or ecgState == "ventricular_fibrillation"
		or (not ecgState and unstable == "atrial_fibrillation")
	local arrhythmia = math.Clamp(num(org, "arrhythmia"), 0, 1)
	local abnormal = irregularSeverity > 0 or unstable ~= nil or arrhythmia >= 0.1 or fibrillating
	local deficit = isnumber(org.cardiacOutput) and math.Clamp(1 - org.cardiacOutput, 0, 1) or 0
	local severity = math.max(arrhythmia, irregularSeverity, fibrillating and 1 or 0, math.Clamp(num(org, "palpitations"), 0, 1),
		math.Clamp(num(org, "heartStrain"), 0, 1), deficit >= 0.3 and deficit or 0)

	if abnormal or severity >= 0.1 then return abnormal, severity end
end

local function circulation(org)
	if org.heartstop then return end

	local pulse = math.max(num(org, "pulse", 70), 0)
	local surge = num(org, "adrenaline") > 4
	local lowSeverity = math.Clamp((70 - pulse) / 40, 0, 1)
	local highSeverity = math.max(math.Clamp((pulse - 100) / 80, 0, 1), surge and 0.6 or 0)
	local lowActive = pulse > 0 and pulse < 70
	local highActive = pulse > 100 or surge

	if lowActive and not surge and (not highActive or lowSeverity >= highSeverity) then
		return "low", high(math.max(lowSeverity, 0.1), circulationStops), pulse
	elseif highActive then
		return "high", high(math.max(highSeverity, 0.1), circulationStops), pulse
	end
end

local function circulationValue(org, pulse)
	return math.floor(pulse) .. " bpm / " .. math.floor(math.max(tonumber(org.bloodPressure) or 0, 0)) .. " MAP"
end

local function analgesiaState(org)
	local analgesia, painkiller = num(org, "analgesia"), num(org, "painkiller")
	if analgesia <= 0 and painkiller <= 0 then return end
	if analgesia > 2 or painkiller > 5 then return 4, "bad" end
	if analgesia > 1.5 or painkiller > 4 then return 3, "bad" end
	if analgesia > 1 or painkiller > 3 then return 2, "bad" end
	if analgesia >= 0.75 then return 4, "good" end
	if analgesia >= 0.5 then return 3, "good" end
	if analgesia >= 0.25 or painkiller >= 1.5 then return 2, "good" end
	return 1, "good"
end

local function normalBlood()
	local config = hg.organism and hg.organism.config
	return math.max(tonumber(config and config.NORMAL_BLOOD_VOLUME_ML) or tonumber(hg.organism and hg.organism.normalBloodVolume) or 5000, 1)
end

local function oxygenState(org)
	local oxygen = istable(org.o2) and num(org.o2, 1, 30) or num(org, "o2", 30)
	local maximum = istable(org.o2) and num(org.o2, "range", 30) or 30
	local state = hg.SimpleHealth and hg.SimpleHealth.GetLocalState and hg.SimpleHealth.GetLocalState()
	if state and state.oxy then
		oxygen = math.min(oxygen, maximum * (1 - math.Clamp(state.oxy / hg.SimpleHealth.Config.oxy.countdownStart, 0, 1)))
	end

	return oxygen, maximum
end

local function chestKind(org)
	local pneumothorax, hemothorax = num(org, "pneumothorax"), num(org, "hemothorax")
	local tamponade, lungWater, pneumonia = num(org, "cardiacTamponade"), num(org, "lungWater"), num(org, "pneumonia")
	local thorax = math.max(pneumothorax, hemothorax, tamponade, lungWater, pneumonia)
	if thorax <= 0.01 then return end

	if pneumonia >= thorax then return "pneumonia", pneumonia end
	if lungWater >= thorax then return "lungwater", lungWater end
	if pneumothorax > 0.05 and hemothorax > 0.05 then return "hemopneumothorax", thorax end
	if tamponade >= pneumothorax and tamponade >= hemothorax then return "tamponade", tamponade end
	if hemothorax > pneumothorax then return "hemothorax", thorax end

	return "pneumothorax", pneumothorax
end

Define("asystole", {
	position = 0,
	active = function(_, org) if org.heartstop == true then return 4 end end,
	name = {chipped = "Asystole", unchipped = "Heart Stopped", simplehealth = "Heart Stopped"},
	description = "Your heart is not beating. You need CPR or a defibrillator.",
})

Define("respiratory_arrest", {
	position = 1,
	active = function(_, org) if org.lungsfunction == false or org.respiratoryArrest == true then return 4 end end,
	name = {chipped = "Respiratory Arrest", all = "Not Breathing"},
	description = "Your lungs have stopped working. You need rescue breaths.",
})

Define("seizure", {
	position = 2,
	active = function(_, org) if org.seizureActive == true then return 4 end end,
	name = "Seizure",
	description = "You are convulsing and cannot control your body.",
})

Define("consciousness", {
	position = 3,
	active = function(_, org)
		local consciousness = num(org, "consciousness", 1)
		if consciousness >= 0.9 then return end
		return org.otrub == true and 4 or low(consciousness, {0.9, 0.75, 0.5, 0.25}), pct(consciousness)
	end,
	name = {"Drowsy", "Groggy", "Fading", "Unconscious"},
	description = {
		"You feel sleepy and slow.",
		"Your thoughts are slipping away.",
		"You are about to pass out.",
		"You are out cold.",
	},
})

Define("rage", {
	position = 4,
	active = function(_, org) if org.berserkActive2 == true then return 4 end end,
	name = "Berserk",
	description = "Rage has taken over. You feel no pain.",
})

Define("bleeding", {
	position = 10,
	active = function(_, org)
		local bleed = num(org, "bleed")
		local level = high(bleed, {0.2, 1.5, 5, 12})
		if level > 0 then return level, math.Round(bleed, 2) end
	end,
	name = {
		chipped = {"Minor Bleeding", "Bleeding", "Severe Bleeding", "Arterial Bleeding"},
		all = {"Scratched", "Bleeding", "Bleeding Badly", "Gushing Blood"},
	},
	description = {
		"You are losing a little blood.",
		"You are bleeding steadily. Bandage the wound.",
		"You are losing blood fast. Stop it now.",
		"Blood is pouring out. You will die without help.",
	},
})

Define("hypovolemia", {
	position = 11,
	active = function(_, org)
		local volume = normalBlood()
		local blood = math.Clamp(num(org, "blood", volume), 0, volume)
		local level = high(1 - blood / volume, {0.1, 0.25, 0.4, 0.55})
		if level > 0 then return level, math.floor(blood) .. " ml" end
	end,
	name = {
		chipped = {"Mild Blood Loss", "Blood Loss", "Severe Blood Loss", "Critical Blood Loss"},
		all = {"Lightheaded", "Weak and Pale", "Fading", "Nearly Bled Out"},
	},
	description = {
		"You have lost some blood.",
		"You have lost a lot of blood and feel weak.",
		"Your body is starving for blood.",
		"You are about to bleed out.",
	},
})

Define("shock", {
	position = 12,
	active = function(_, org)
		local shock = num(org, "shock")
		local level = high(shock, {10, 20, 30, 40})
		if level > 0 then return level, math.floor(shock) end
	end,
	name = {
		chipped = "Shock",
		all = {"Clammy", "Cold Sweat", "Going Into Shock", "Collapsing"},
	},
	description = "Your body is overwhelmed and struggling to stay in control.",
})

Define("low_blood", {
	position = 13,
	active = function(_, org)
		local kind, level, pulse = circulation(org)
		if kind == "low" then return level, circulationValue(org, pulse) end
	end,
	name = {
		chipped = {"Low Perfusion", "Hypotension", "Severe Hypotension", "Circulatory Collapse"},
		all = {"Light Headed", "Faint", "Very Faint", "Barely Conscious"},
	},
	description = "Your heart is not moving enough blood around your body.",
})

Define("high_blood", {
	position = 14,
	active = function(_, org)
		local kind, level, pulse = circulation(org)
		if kind == "high" then return level, circulationValue(org, pulse) end
	end,
	name = {
		chipped = {"Raised Pulse", "High Pulse", "Very High Pulse", "Extreme Pulse"},
		all = {"Pounding Pulse", "Racing Pulse", "Heart Hammering", "Heart Redlining"},
	},
	description = "Your heart is working much harder than normal.",
})

Define("arrhythmia", {
	position = 15,
	active = function(_, org)
		local abnormal, severity = cardiac(org)
		if abnormal ~= nil then return high(math.max(severity, 0.1), circulationStops), pct(severity) end
	end,
	name = {
		chipped = function(level, _, _, org)
			local abnormal = cardiac(org)
			if abnormal then return ({"Skipped Beats", "Arrhythmia", "Severe Arrhythmia", "Lethal Arrhythmia"})[level] end
			return ({"Mild Heart Strain", "Heart Strain", "Severe Heart Strain", "Heart Failing"})[level]
		end,
		all = {"Fluttering Heart", "Irregular Heartbeat", "Chest Pounding", "Heart Failing"},
	},
	description = function(_, _, _, org)
		if cardiac(org) then return "Your heartbeat has lost its rhythm." end
		return "Your heart is under heavy strain and may start to lose rhythm."
	end,
})

Define("palpitations", {
	position = 16,
	active = function(_, org)
		if org.heartstop then return end
		local rate = num(org, "heartbeat", num(org, "pulse", 70))
		if rate >= 100 then
			return high(math.max(math.Clamp((rate - 100) / 150, 0, 1), 0.1), circulationStops), math.floor(rate) .. " bpm"
		elseif rate > 0 and rate <= 45 then
			return high(math.max(math.Clamp((45 - rate) / 30, 0, 1), 0.1), circulationStops), math.floor(rate) .. " bpm"
		end
	end,
	name = {
		chipped = function(_, _, _, org) return num(org, "heartbeat", num(org, "pulse", 70)) >= 100 and "Tachycardia" or "Bradycardia" end,
		all = function(_, _, _, org) return num(org, "heartbeat", num(org, "pulse", 70)) >= 100 and "Heart Racing" or "Slow Heartbeat" end,
	},
	description = function(_, _, _, org)
		return num(org, "heartbeat", num(org, "pulse", 70)) >= 100 and "Your heart is beating too fast." or "Your heart is beating too slowly."
	end,
})

Define("pain", {
	position = 17,
	active = function(_, org)
		if org.berserkActive2 == true then return end
		local pain = num(org, "pain")
		if pain <= 20 then return end
		return pain >= 85 and 4 or pain >= 60 and 3 or pain > 45 and 2 or 1, math.floor(pain)
	end,
	name = {"Aching", "Pain", "Severe Pain", "Agony"},
	description = {
		"Something hurts.",
		"You are in pain and it is hard to focus.",
		"The pain is overwhelming.",
		"You can barely think through the agony.",
	},
})

Define("hypoxemia", {
	position = 20,
	active = function(_, org)
		local oxygen, maximum = oxygenState(org)
		if oxygen >= math.min(28, maximum) then return end
		return oxygen < 8 and 4 or oxygen < 14 and 3 or oxygen < 23 and 2 or 1, math.floor(oxygen)
	end,
	name = {
		chipped = {"Low Oxygen", "Hypoxemia", "Severe Hypoxemia", "Critical Hypoxemia"},
		all = {"Short of Breath", "Gasping", "Suffocating", "Blacking Out"},
	},
	description = {
		"You are not getting quite enough air.",
		"Your body is starved of oxygen.",
		"You are suffocating.",
		"You are about to black out from lack of air.",
	},
})

Define("carbon_monoxide", {
	position = 21,
	active = function(_, org)
		local co, co2 = num(org, "CO"), num(org, "co2")
		local coLevel = co > 5 and (co >= 25 and 4 or co >= 20 and 3 or co >= 10 and 2 or 1) or 0
		local co2Level = co2 >= 8 and (co2 >= 24 and 4 or co2 >= 18 and 3 or co2 >= 12 and 2 or 1) or 0
		local level = math.max(coLevel, co2Level)
		if level > 0 then return level, pct(math.Clamp(math.max(coLevel > 0 and co / 30 or 0, co2Level > 0 and co2 / 30 or 0), 0, 1)) end
	end,
	name = {
		chipped = function(_, _, _, org) return num(org, "CO") > 5 and "Carbon Monoxide" or "CO2 Buildup" end,
		all = {"Stale Air", "Dizzy and Sick", "Poisoned Air", "Choking on Fumes"},
	},
	description = "The air you are breathing is making you ill.",
})

Define("bradypnea", {
	position = 22,
	active = function(_, org)
		local level, value = 0, nil
		local regen = istable(org.o2) and num(org.o2, "curregen") or 0
		local demand = num(org, "losing_oxy")
		if demand > 0 and org.lungsfunction ~= false and org.respiratoryArrest ~= true and regen < demand and not org.holdingbreath then
			local deficit = math.Clamp(1 - regen / demand, 0, 1)
			level, value = high(deficit, {0.1, 0.3, 0.55, 0.8}), pct(deficit)
		end

		local slow = math.Clamp(num(org, "bradyapnea"), 0, 1)
		if slow > 0.05 and org.respiratoryArrest ~= true and org.lungsfunction ~= false then
			local slowLevel = high(slow, {0.05, 0.3, 0.6, 0.85})
			if slowLevel > level then level, value = slowLevel, pct(slow) end
		end

		if level > 0 then return level, value end
	end,
	name = {
		chipped = {"Slow Breathing", "Bradypnea", "Severe Bradypnea", "Respiratory Failure"},
		all = {"Shallow Breaths", "Labored Breathing", "Barely Breathing", "Gasping for Air"},
	},
	description = "You are not breathing enough to keep up with your body's needs.",
})

Define("choking", {
	position = 23,
	active = function(_, org) if org.vomitInThroat then return 4 end end,
	name = {chipped = "Airway Obstruction", all = "Choking"},
	description = "Something is blocking your airway.",
})

local chestKinds = {"pneumothorax", "hemothorax", "hemopneumothorax", "tamponade", "lungwater", "pneumonia"}

for index, kind in ipairs(chestKinds) do
	local common = kind == "lungwater" or kind == "pneumonia"
	local function text(field)
		return function(level)
			local texts = hg.MoodlePleuralTexts and hg.MoodlePleuralTexts[kind]
			local entry = texts and texts[math.max(level, 1)]
			return entry and entry[field] or ""
		end
	end

	Define(kind, {
		position = 24 + index * 0.1,
		active = function(_, org)
			local current, severity = chestKind(org)
			if current ~= kind then return end

			local texts = hg.MoodlePleuralTexts and hg.MoodlePleuralTexts[kind]
			local level = texts and high(severity, texts.thresholds) or 1
			return math.max(level, 1), pct(severity)
		end,
		name = {chipped = text("title"), unchipped = common and text("title") or false, simplehealth = common and text("title") or false},
		description = {chipped = text("description"), unchipped = common and text("description") or false, simplehealth = common and text("description") or false},
	})
end

gauge("brain_bleed", 30, "brainHemorrhage", {0.0001, 0.25, 0.5, 0.75}, {
	name = {
		chipped = {"Minor Brain Bleed", "Brain Hemorrhage", "Severe Brain Hemorrhage", "Massive Brain Hemorrhage"},
		unchipped = {"Headache", "Throbbing Headache", "Splitting Headache", "Blinding Headache"},
		simplehealth = false,
	},
	description = "Blood is pooling inside your skull.",
})

Define("skull", {
	position = 31,
	active = function(_, org)
		local skull = num(org, "skull")
		if skull >= 0.6 then return skull >= 1 and 4 or 2, pct(skull) end
	end,
	name = {chipped = {[2] = "Cracked Skull", [4] = "Skull Fracture"}, unchipped = "Head Trauma", simplehealth = false},
	description = "Your skull has taken serious damage.",
})

gauge("intracranial_pressure", 32, "intracranialPressure", {0.15, 0.35, 0.6, 0.85}, {
	name = {
		chipped = "Intracranial Pressure",
		unchipped = {"Pressure in Head", "Pounding Head", "Skull Pounding", "Head About to Burst"},
		simplehealth = false,
	},
	description = "Pressure is building inside your skull.",
})

gauge("concussion", 33, "concussion", {0.1, 0.25, 0.5, 0.75}, {
	name = {
		chipped = {"Mild Concussion", "Concussion", "Severe Concussion", "Critical Concussion"},
		all = {"Dazed", "Dizzy", "Seeing Stars", "Reeling"},
	},
	description = "Your head took a hard hit and you cannot think straight.",
})

Define("brain_damage", {
	position = 34,
	active = function(_, org)
		local brain = num(org, "brain")
		local level = high(brain, {0.01, 0.1, 0.18, 0.25})
		if level > 0 then return level, pct(brain) end
	end,
	name = {
		chipped = {"Minor Brain Damage", "Brain Damage", "Severe Brain Damage", "Brain Failing"},
		all = {"Foggy", "Confused", "Mind Slipping", "Fading Away"},
	},
	description = {
		"Your thoughts feel slightly off.",
		"Your brain is damaged and you are confused.",
		"Your brain is badly damaged.",
		"Your brain is dying.",
	},
})

Define("brain_hypoxia", {
	position = 35,
	active = function(_, org)
		local oxygen = math.Clamp(num(org, "brainoxygen", 1), 0, 1)
		if oxygen < 0.55 and num(org, "hypoxiaTime") > 2 then return low(oxygen, {0.55, 0.42, 0.28, 0.15}), pct(oxygen) end
	end,
	name = {chipped = "Cerebral Hypoxia", unchipped = false, simplehealth = false},
	description = "Your brain is not getting enough oxygen.",
})

gauge("brain_fog", 36, "brainFog", {0.05, 0.3, 0.6, 0.85}, {
	name = {
		chipped = {"Mild Cerebral Hypoperfusion", "Cerebral Hypoperfusion", "Severe Cerebral Hypoperfusion", "Critical Cerebral Hypoperfusion"},
		all = {"Hazy", "Foggy Head", "Barely Thinking", "Mind Shutting Down"},
	},
	description = "Not enough blood is reaching your brain.",
})

Define("no_eye", {
	position = 37,
	active = function(_, org)
		local flash = isnumber(amtflashed) and amtflashed or 0
		if org.blindness == nil and flash < 0.2 then return end
		return org.blindness == 0 and 4 or org.blindness ~= nil and 2 or high(flash, {0.2, 0.5, 0.8, 1.2})
	end,
	name = {"Flash Blinded", "Vision Loss", "Nearly Blind", "Blind"},
	description = "You cannot see properly.",
})

Define("blinded", {
	position = 38,
	active = function(ply, org)
		local pepper = ply:GetNWFloat("PS_BlindEndTime", 0) > CurTime()
		local disorientation = num(org, "disorientation")
		if disorientation <= 0.2 and not pepper then return end
		local level = high(disorientation, {0.2, 1, 2.5, 3.5})
		return pepper and math.max(level, 2) or level
	end,
	name = {"Blurred Vision", "Disoriented", "Badly Disoriented", "Blinded"},
	description = "Your vision and balance are failing.",
})

Define("tinnitus", {
	position = 39,
	active = function(ply, org)
		local time = math.max(num(ply, "tinnitus") - CurTime(), 0)
		local temporal = num(org, "brainTemporal")
		if time <= 0 and temporal <= 0.1 then return end
		return high(math.max(math.Clamp(time / 40, 0, 1), math.Clamp(temporal, 0, 1)), {0.01, 0.25, 0.5, 0.75})
	end,
	name = "Ringing Ears",
	description = "A high-pitched whine is drowning out everything else.",
})

Define("deaf", {
	position = 39.1,
	active = function(ply, org)
		local time = math.max(num(ply, "tinnitus") - CurTime(), 0)
		local temporal = num(org, "brainTemporal")
		if time >= 20 or temporal >= 0.75 then return (time >= 40 or temporal >= 1) and 4 or 3 end
	end,
	name = "Deafened",
	description = "You cannot hear anything.",
})

Define("tissue_damage", {
	position = 40,
	active = function(_, org)
		local found, worst = tissueFindings(org)
		if worst > 0 then return worst, math.floor(found[1].value) end
	end,
	name = {
		chipped = {"Minor Tissue Damage", "Tissue Damage", "Severe Tissue Damage", "Critical Tissue Damage"},
		all = {"Cuts and Bruises", "Wounded", "Badly Wounded", "Mangled"},
	},
	description = function(_, _, _, org) return joinFindings((tissueFindings(org))) end,
})

Define("muscle_damage", {
	position = 41,
	active = function(_, org)
		local found, worst = muscleFindings(org)
		if worst > 0 then return worst, pct(found[1].value) end
	end,
	name = {
		chipped = {"Muscle Strain", "Torn Muscle", "Ruptured Muscle", "Ruined Muscle"},
		all = {"Sore Muscles", "Torn Muscles", "Ruptured Muscles", "Ruined Muscles"},
		simplehealth = false,
	},
	description = function(_, _, _, org) return joinFindings((muscleFindings(org))) end,
})

Define("burning", {
	position = 42,
	active = function(ply)
		local character = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
		local count = 0
		for _, ent in ipairs({ply, character}) do
			if IsValid(ent) and ent:IsOnFire() then count = math.max(count, istable(ent.fires) and table.Count(ent.fires) or 1) end
		end
		if count > 0 then return math.Clamp(count, 1, 4), count end
	end,
	name = "On Fire",
	description = "You are burning. Put the fire out.",
})

Define("fracture", {
	position = 43,
	active = function(_, org)
		local fractures = countFractures(org)
		local axial = num(org, "pelvis") >= 0.95 or num(org, "chest") >= 0.95
		if fractures > 0 then return axial and 4 or math.ceil(fractures / 2), fractures end
		if axial then return 4, 1 end
	end,
	name = {
		chipped = {"Fracture", "Multiple Fractures", "Severe Fractures", "Critical Fractures"},
		all = {"Broken Bone", "Broken Bones", "Badly Broken", "Shattered"},
	},
	description = "Broken bones make moving painful. Splint the limb.",
})

Define("dislocated", {
	position = 44,
	active = function(_, org)
		local count = countDislocations(org)
		if count > 0 then return count, count end
	end,
	name = {"Dislocated Joint", "Dislocated Joints", "Dislocated Joints", "Dislocated Joints"},
	description = "A joint is out of place. It needs to be popped back in.",
})

Define("dislocated_jaw", {
	position = 45,
	active = function(_, org)
		if num(org, "jaw") >= 1 then return 4 end
		if org.jawdislocation == true or org.jawdislocated == true then return 2 end
	end,
	name = {[2] = "Dislocated Jaw", [4] = "Broken Jaw"},
	description = "Your jaw is hurt and you cannot speak clearly.",
})

Define("amputated", {
	position = 46,
	active = function(ply, org)
		local tourniqueted = tourniquetedLimbs(ply)
		local count, untreated = 0, false
		for _, limb in ipairs(limbKeys) do
			if org[limb .. "amputated"] == true then
				count = count + 1
				if not tourniqueted[limb] then untreated = true end
			end
		end
		if count > 0 then return untreated and 4 or 3, count end
	end,
	name = {[3] = "Amputated Limb", [4] = "Bleeding Stump"},
	description = {[3] = "You lost a limb, but the stump is tied off.", [4] = "You lost a limb and it is still bleeding. Tie it off."},
})

Define("spine_break", {
	position = 47,
	active = function(_, org)
		local spine1, spine2, spine3 = num(org, "spine1"), num(org, "spine2"), num(org, "spine3")
		if spine1 >= 0.95 or spine2 >= 0.95 or spine3 >= 0.95 then return (spine2 >= 0.95 or spine3 >= 0.95) and 4 or 3 end
	end,
	name = {chipped = "Spinal Fracture", all = "Broken Back"},
	description = "Your spine is broken. Moving makes it worse.",
})

Define("organ_damage", {
	position = 48,
	active = function(_, org)
		local heart, trachea = num(org, "heart"), num(org, "trachea")
		local liver, gut, flank = num(org, "liver"), num(org, "gut"), num(org, "flank")
		local lungL = istable(org.lungsL) and num(org.lungsL, 1) or 0
		local lungR = istable(org.lungsR) and num(org.lungsR, 1) or 0
		local threat = math.max(
			math.Clamp((heart - 0.5) / 0.5, 0, 1),
			math.Clamp((trachea - 0.5) / 0.5, 0, 1),
			math.Clamp((math.max(lungL, lungR) - 0.7) / 0.3, 0, 1) * 0.75,
			(lungL >= 0.8 and lungR >= 0.8) and 1 or 0,
			math.Clamp((liver - 0.7) / 0.3, 0, 1) * 0.75,
			math.Clamp((flank - 0.7) / 0.3, 0, 1) * 0.6,
			math.Clamp((gut - 0.8) / 0.2, 0, 1) * 0.5
		)
		if threat >= 0.25 then return high(threat, severeStops), pct(threat) end
	end,
	name = {
		chipped = {"Minor Organ Damage", "Organ Damage", "Severe Organ Damage", "Organ Failure"},
		all = {"Deep Ache", "Internal Pain", "Severe Internal Pain", "Organs Failing"},
	},
	description = "Something inside your body is badly hurt.",
})

Define("internal_bleed", {
	position = 49,
	active = function(_, org)
		local internal = num(org, "internalBleed")
		if internal <= 0.05 then return end
		local level = high(internal, {0.05, 1.5, 5, 10})
		local thorax = chestKind(org)
		if thorax or num(org, "internalBleedComplication") > 0.01 then level = math.max(level, 3) end
		if num(org, "hemothorax") >= 0.5 or num(org, "internalBleedComplication") >= 0.65 then level = 4 end
		return level, math.Round(internal, 2)
	end,
	name = {
		chipped = {"Minor Internal Bleeding", "Internal Bleeding", "Severe Internal Bleeding", "Massive Internal Bleeding"},
		unchipped = {"Aching Inside", "Bruised Inside", "Swelling Inside", "Bleeding Inside"},
		simplehealth = false,
	},
	description = "You are bleeding inside. Only a surgeon can stop it.",
})

Define("weakness", {
	position = 50,
	active = function(_, org)
		local resistance = math.Clamp(num(org, "zerlkers"), 0, 1)
		local painControl = Lerp(resistance, math.Clamp(60 / (num(org, "pain") + 1), 0.35, 1), 1)
		local shockControl = Lerp(resistance, math.Clamp(10 / (num(org, "shock") + 1), 0.45, 1), 1)
		local control = math.min(num(org, "peripheralperfusion", 1), num(org, "perfusionMoveMul", 1), num(org, "legstrength", 1), num(org, "armstrength", 1))
		control = control * painControl * shockControl
		if control < 0.75 then return low(control, {0.75, 0.55, 0.35, 0.2}), pct(control) end
	end,
	name = {"Weak", "Very Weak", "Crippled", "Helpless"},
	description = "Your body cannot put out its usual strength.",
})

Define("temperature", {
	position = 51,
	active = function(_, org)
		local temperature = num(org, "temperature", 36.7)
		local value = math.Round(temperature, 1) .. " C"
		if temperature >= 40 then return 4, value end
		if temperature > 37.5 then return temperature >= 39.3 and 3 or temperature >= 38.4 and 2 or 1, value end
		if temperature < 36 then return temperature < 31 and 4 or temperature < 33 and 3 or temperature < 35 and 2 or 1, value end
	end,
	name = {
		chipped = function(level, _, _, org)
			if num(org, "temperature", 36.7) >= 36 then return ({"Elevated Temperature", "Fever", "High Fever", "Hyperthermia"})[level] end
			return ({"Chilled", "Cold", "Hypothermia", "Severe Hypothermia"})[level]
		end,
		all = function(level, _, _, org)
			if num(org, "temperature", 36.7) >= 36 then return ({"Feeling Warm", "Feverish", "Burning Up", "Overheating"})[level] end
			return ({"Chilly", "Cold", "Freezing", "Frozen Stiff"})[level]
		end,
	},
	description = function(_, _, _, org)
		if num(org, "temperature", 36.7) >= 36 then return "Your body is too hot." end
		return "Your body is losing heat."
	end,
})

Define("sepsis", {
	position = 52,
	active = function(_, org)
		local ischemia, transfusion = num(org, "ischemia"), num(org, "hemotransfusionshock")
		local infection, leukopenia = num(org, "infection"), num(org, "leukopenia")
		if ischemia <= 0.1 and transfusion <= 0.1 and infection <= 0.15 and leukopenia <= 0.3 then return end

		local level = math.max(math.min(high(ischemia, {0.1, 0.5, 1, 1.5}), 3), (infection > 0.15 or leukopenia > 0.3) and 1 or 0)
		if transfusion > 0.1 then level = math.max(level, transfusion >= 0.6 and 3 or 2) end
		if num(org, "septicShock") > 0 then level = 4 end

		return level, pct(math.max(ischemia, transfusion, infection, leukopenia))
	end,
	name = {
		chipped = {"Infection", "Sepsis", "Severe Sepsis", "Septic Shock"},
		unchipped = {"Feeling Ill", "Fever and Chills", "Very Ill", "Dying of Infection"},
		simplehealth = false,
	},
	description = "Something is wrong with your blood and you feel ill.",
})

gauge("hepatic_failure", 53, "hepaticFailure", severeStops, {
	name = {chipped = {"Liver Stress", "Liver Damage", "Liver Failure", "Acute Liver Failure"}, unchipped = false, simplehealth = false},
	description = "Your liver can no longer clean your blood.",
})

gauge("renal_failure", 54, "renalFailure", severeStops, {
	name = {chipped = {"Kidney Stress", "Kidney Damage", "Kidney Failure", "Acute Kidney Failure"}, unchipped = false, simplehealth = false},
	description = "Your kidneys can no longer filter your blood.",
})

gauge("rhabdo", 55, "rhabdo", severeStops, {
	name = {chipped = {"Muscle Breakdown", "Rhabdomyolysis", "Severe Rhabdomyolysis", "Critical Rhabdomyolysis"}, unchipped = false, simplehealth = false},
	description = "Broken-down muscle is flooding your blood and straining your kidneys.",
})

gauge("hyperkalemia", 56, "hyperkalemia", severeStops, {
	name = {chipped = {"High Potassium", "Hyperkalemia", "Severe Hyperkalemia", "Critical Hyperkalemia"}, unchipped = false, simplehealth = false},
	description = "Too much potassium in your blood threatens your heart rhythm.",
})

Define("acidbase", {
	position = 57,
	active = function(_, org)
		local acidosis, alkalosis = num(org, "acidosis"), num(org, "alkalosis")
		local level = high(math.max(acidosis, alkalosis), {0.05, 0.3, 0.6, 0.85})
		if level > 0 then return level, string.format("pH %.2f", num(org, "bloodph", 7.4)) end
	end,
	name = {
		chipped = function(level, _, _, org)
			local texts = num(org, "alkalosis") > num(org, "acidosis") and hg.MoodleAlkalosisTexts or hg.MoodleAcidosisTexts
			return texts and texts[level].title
		end,
		unchipped = false,
		simplehealth = false,
	},
	description = function(level, _, _, org)
		local texts = num(org, "alkalosis") > num(org, "acidosis") and hg.MoodleAlkalosisTexts or hg.MoodleAcidosisTexts
		return texts and texts[level].description
	end,
})

Define("vascular_clot", {
	position = 58,
	active = function(_, org)
		local embolism, burden = math.Clamp(num(org, "pulmonaryEmbolism"), 0, 1), math.Clamp(num(org, "clotBurden"), 0, 1)
		if embolism > 0.05 then return high(embolism, {0.05, 0.3, 0.6, 0.85}), pct(embolism) end
		if burden > 0.1 then return high(burden, {0.1, 0.3, 0.6, 0.85}), pct(burden) end
	end,
	name = {
		chipped = function(_, _, _, org) return num(org, "pulmonaryEmbolism") > 0.05 and "Pulmonary Embolism" or "Blood Clots" end,
		unchipped = false,
		simplehealth = false,
	},
	description = function(_, _, _, org)
		if num(org, "pulmonaryEmbolism") > 0.05 then return "A clot is blocking blood flow through your lungs." end
		return "Clots are forming in your blood."
	end,
})

Define("nausea", {
	position = 59,
	active = function(_, org)
		local nausea = num(org, "nausea")
		local level = high(nausea, {0.2, 0.4, 0.6, 0.8})
		if level > 0 then return level, pct(math.min(nausea, 1)) end
	end,
	name = {"Queasy", "Nauseous", "Sick", "Retching"},
	description = "Your stomach is turning and you may vomit.",
})

Define("encumbered", {
	position = 60,
	active = function(ply, org)
		local weight = num(org, "weight")
		if ply == LocalPlayer() and hg.GetCarryWeight then weight = hg.GetCarryWeight(ply) end
		local fraction = weight / math.max(num(org, "maxweight", 60), 1)
		if fraction > 0.5 then return high(fraction, {0.5, 0.7, 0.85, 0.95}), pct(fraction) end
	end,
	name = {"Loaded", "Encumbered", "Heavily Encumbered", "Overburdened"},
	description = "You are carrying more than you can comfortably handle.",
})

Define("exertion", {
	position = 61,
	active = function(_, org)
		local stamina = istable(org.stamina) and org.stamina or nil
		if not stamina then return end
		local maximum = num(stamina, "max", num(stamina, "range", 180))
		local fraction = math.Clamp(num(stamina, 1, maximum) / math.max(maximum, 1), 0, 1)
		if fraction < 0.75 then return low(fraction, staminaStops), pct(fraction) end
	end,
	name = {"Winded", "Out of Breath", "Exhausted", "Collapsing"},
	description = "You are running out of stamina.",
})

for _, pool in ipairs({"legs", "arms"}) do
	Define("tired_" .. pool, {
		position = pool == "legs" and 62 or 63,
		active = function(_, org)
			if not istable(org.stamina) or not hg.GetLimbStaminaFraction then return end
			local fraction = hg.GetLimbStaminaFraction(org, pool)
			if fraction < 0.75 then return low(fraction, staminaStops), pct(fraction) end
		end,
		name = pool == "legs" and {"Tired Legs", "Heavy Legs", "Burning Legs", "Legs Giving Out"} or {"Tired Arms", "Heavy Arms", "Burning Arms", "Arms Giving Out"},
		description = pool == "legs" and "Your legs are running out of strength." or "Your arms are running out of strength.",
	})
end

Define("analgesia", {
	position = 64,
	active = function(_, org)
		local level = analgesiaState(org)
		if level then return level, math.Round(math.max(num(org, "analgesia"), num(org, "painkiller")), 1) end
	end,
	mood = function(_, _, _, org) return select(2, analgesiaState(org)) end,
	name = function(level, _, _, org)
		if select(2, analgesiaState(org)) == "bad" then return ({"Overmedicated", "Opioid Overdose", "Severe Overdose", "Critical Overdose"})[level] end
		return ({"Numbed", "Pain Relief", "Heavy Pain Relief", "Deep Pain Relief"})[level]
	end,
	description = function(_, _, _, org)
		if select(2, analgesiaState(org)) == "bad" then return "The medication is too much for your body." end
		return "Medication is dulling your pain."
	end,
})

Define("poisoning", {
	position = 65,
	active = function(_, org)
		local tranquilizer, poison = num(org, "tranquilizer"), num(org, "poisonLoad")
		if tranquilizer <= 0 and poison <= 0 then return end
		local level = math.max(tranquilizer > 0 and high(tranquilizer, {0.01, 3, 10, 25}) or 0, poison > 0 and poison + 1 or 0)
		if tranquilizer > 0 and poison > 0 then level = level + 1 end
		return level
	end,
	name = {
		chipped = function(_, _, _, org) return num(org, "poisonLoad") > 0 and "Poisoned" or "Sedated" end,
		all = function(_, _, _, org) return num(org, "poisonLoad") > 0 and "Poisoned" or "Drowsy From Drugs" end,
	},
	description = "A foreign substance is working through your body.",
})

Define("adrenaline", {
	position = 66,
	mood = "good",
	active = function(_, org)
		local adrenaline = num(org, "adrenaline")
		local level = high(adrenaline, {0.3, 0.8, 1.5, 2.1})
		if level > 0 then return level, math.Round(adrenaline, 1) end
	end,
	name = {"Alert", "Adrenaline", "Adrenaline Rush", "Adrenaline Overload"},
	description = "Adrenaline is sharpening you and numbing the pain.",
})

Define("zerlked", {
	position = 67,
	active = function(_, org)
		local zerlkers = num(org, "zerlkers")
		if zerlkers > 0 then return math.Clamp(math.ceil(zerlkers * 4), 1, 4), math.ceil(zerlkers * 120) .. "s" end
	end,
	mood = function(_, _, _, org) return (num(org, "zerlkers") >= 2 or num(org, "zerlkersOverdose") > 0) and "bad" or "good" end,
	name = "Zerlkers",
	description = "The drug is hiding your pain and weakness. It will wear off.",
})

Define("tourniquet", {
	position = 68,
	mood = "good",
	active = function(ply)
		local count = table.Count(tourniquetedLimbs(ply))
		if count > 0 then return math.min(count, 4), count end
	end,
	name = "Tourniquet On",
	description = "A tourniquet is stopping the bleeding. Do not leave it on too long.",
})

Define("bandaged", {
	position = 69,
	mood = "good",
	active = function(ply)
		local count = countEntries(ply:GetNetVar("bandaged_limbs", {}))
		if count > 0 then return math.min(count, 4), count end
	end,
	name = "Bandaged",
	description = "Your wounds are dressed and healing.",
})

Define("armored", {
	position = 70,
	mood = "good",
	active = function(ply)
		local count = countEntries(ply:GetNetVar("Armor", {}))
		if count > 0 then return count >= 2 and 4 or 2, count end
	end,
	name = "Armored",
	description = "Armor is protecting parts of your body.",
})

gauge("panic", 71, "panicattack", {0.03, 0.35, 0.6, 0.85}, {
	name = {"Nervous", "Anxious", "Panicking", "Panic Attack"},
	description = "Fear is taking over your body.",
})

gauge("anger", 72, "anger", {0.01, 0.25, 0.5, 0.75}, {
	mood = "good",
	name = {"Irritated", "Angry", "Furious", "Enraged"},
	description = "Anger is driving you on.",
})

gauge("happy", 73, "goodmood", {0.1, 0.35, 0.6, 0.85}, {
	mood = "good",
	name = {"Content", "Happy", "Joyful", "Euphoric"},
	description = "You feel good.",
})

gauge("depression", 74, "depression", {0.03, 0.25, 0.6, 0.85}, {
	name = {"Unhappy", "Dreary", "Miserable", "Despairing"},
	description = {
		"Something feels off about the world.",
		"Nothing seems worth the effort.",
		"You feel hollow and miserable.",
		"You cannot see any way forward.",
	},
})

Define("self_harm", {
	position = 75,
	active = function(_, org)
		local convar = GetConVar("hg_selfharm")
		local depression = math.Clamp(num(org, "depression"), 0, 1)
		if depression >= 0.6 and convar and convar:GetBool() then return high(depression, {0.6, 0.7, 0.8, 0.9}), pct(depression) end
	end,
	name = "Self-Harm Urges",
	description = "Your despair is pushing you to hurt yourself.",
})

gauge("hopelessness", 76, "hopelessness", mentalStops, {
	name = "Hopeless",
	description = "You are sure nothing will get better.",
})

gauge("desolation", 77, "desolation", mentalStops, {
	name = "Desolate",
	description = "You feel completely alone.",
})

gauge("suicidal", 78, "suicidal", mentalStops, {
	name = "Suicidal",
	description = "You want it all to end.",
})

gauge("cotard", 79, "cotard", {0.01, 0.5, 0.75, 0.95}, {
	name = {chipped = "Cotard Delusion", all = "Feeling Dead"},
	description = "You are convinced you are already dead.",
})

Define("hunger", {
	position = 80,
	active = function(_, org)
		local system = GetConVar("hg_hungersystem")
		local hungry = math.Clamp(num(org, "hungry"), 0, 100)
		if system and system:GetBool() and hungry > 10 then return high(hungry, {10, 30, 55, 75}), math.floor(hungry) .. "%" end
	end,
	name = {"Peckish", "Hungry", "Starving", "Famished"},
	description = "You need to eat.",
})

Define("full", {
	position = 80.1,
	mood = "good",
	active = function(_, org)
		local system = GetConVar("hg_hungersystem")
		local satiety = math.Clamp(num(org, "satiety"), 0, 100)
		if system and system:GetBool() and math.Clamp(num(org, "hungry"), 0, 100) <= 10 and satiety >= 80 then
			return satiety >= 95 and 2 or 1, math.floor(satiety) .. "%"
		end
	end,
	name = {"Well Fed", "Stuffed"},
	description = "You are full and your body is recovering.",
})

Define("thirst", {
	position = 81,
	active = function(_, org)
		local system = GetConVar("hg_thirstsystem")
		local thirst = math.Clamp(num(org, "thirst"), 0, 100)
		if system and system:GetBool() and thirst > 10 then return high(thirst, {10, 30, 55, 75}), math.floor(thirst) .. "%" end
	end,
	name = {"Thirsty", "Parched", "Dehydrated", "Severely Dehydrated"},
	description = "You need to drink.",
})

Define("airway_blocked", {
	position = 23.1,
	active = function(_, org)
		if org.breathObstructed and not org.vomitInThroat and not org.holdingbreath then return 4 end
	end,
	name = {chipped = "Airway Obstructed", all = "Cannot Breathe"},
	description = "Water, an obstruction or bad air is stopping you from drawing a breath.",
})

Define("stroke_risk", {
	position = 36.5,
	active = function(_, org)
		local risk = math.Clamp(num(org, "strokeRisk"), 0, 1)
		if risk > 0.35 then return high(risk, {0.35, 0.5, 0.7, 0.9}), pct(num(org, "strokeExposure")) end
	end,
	name = {
		chipped = {"Elevated Stroke Risk", "High Stroke Risk", "Impending Stroke", "Imminent Stroke"},
		unchipped = {"Throbbing Temples", "Pounding Head", "Face Tingling", "Head About to Burst"},
		simplehealth = false,
	},
	description = "Pressure on the vessels in your brain is dangerously high.",
})

gauge("spinal_cord_failure", 47.1, "spinalBradypnea", {0.05, 0.3, 0.6, 0.85}, {
	name = {chipped = {"Cord Compression", "Spinal Cord Injury", "Severe Spinal Cord Injury", "Spinal Cord Failure"}, unchipped = false, simplehealth = false},
	description = "Your damaged spinal cord is failing to drive your breathing and heart.",
})

Define("immobilization", {
	position = 45.5,
	active = function(_, org)
		local value = num(org, "immobilization")
		local level = high(value, {10, 30, 60, 85})
		if level > 0 then return level, math.floor(value) end
	end,
	name = {
		chipped = {"Reduced Mobility", "Limited Mobility", "Barely Mobile", "Immobilized"},
		all = {"Moving Stiffly", "Hard to Move", "Barely Moving", "Cannot Move"},
	},
	description = "Your injuries are keeping you from moving freely.",
})

Define("splinted", {
	position = 67.5,
	mood = "good",
	active = function(ply)
		local count = countEntries(ply:GetNetVar("Splints", {}))
		if count > 0 then return math.min(count, 4), count end
	end,
	name = "Splinted",
	description = "A splint is holding the broken limb in place while it heals.",
})

Define("pain_habit", {
	position = 17.5,
	mood = "good",
	active = function(_, org)
		local habit = math.Clamp(num(org, "painHabit"), 0, 1)
		if habit >= 0.1 then return high(habit, {0.1, 0.35, 0.6, 0.85}), pct(habit) end
	end,
	name = {"Getting Used to It", "Pain Habituation", "Dulled to Pain", "Numb to Pain"},
	description = "You have stopped feeling the constant pain as much. The injury is still there.",
})

gauge("streptokinase", 66.1, "streptokinase", {0.01, 0.5, 1, 1.5}, {
	mood = "good",
	name = {chipped = "Thrombolytic Active", unchipped = false, simplehealth = false},
	description = "Clot-busting medication is working through your blood.",
})

Define("tranexamic_acid", {
	position = 66.2,
	mood = "good",
	active = function(_, org)
		local dose = num(org, "tranexamic_acid")
		local level = high(dose, {0.01, 2, 5, 8})
		if level > 0 then return level, math.Round(dose, 1) end
	end,
	name = {chipped = "Tranexamic Acid Active", unchipped = false, simplehealth = false},
	description = "Clotting medication is slowing your bleeding but raising clot risk.",
})

Define("antibiotics", {
	position = 66.3,
	mood = "good",
	active = function(_, org)
		local seconds = num(org, "antibiotics")
		local level = high(seconds, {1, 90, 180, 300})
		if level > 0 then return level, math.ceil(seconds) .. "s" end
	end,
	name = {chipped = "Antibiotics Active", unchipped = false, simplehealth = false},
	description = "Antibiotics are fighting infection in your blood.",
})

Define("naloxone", {
	position = 66.4,
	mood = "good",
	active = function(_, org)
		local dose = num(org, "naloxone")
		local level = high(dose, {0.01, 1, 2, 3})
		if level > 0 then return level, math.Round(dose, 1) end
	end,
	name = {chipped = "Opioid Reversal", unchipped = false, simplehealth = false},
	description = "Naloxone is blocking opioids, including your painkillers.",
})

Define("lactate", {
	position = 58.5,
	active = function(_, org)
		local lactate = num(org, "lactaid", 1)
		local level = high(lactate, {2, 4, 8, 14})
		if level > 0 then return level, math.Round(lactate, 1) .. " mmol/L" end
	end,
	name = {chipped = {"Raised Lactate", "Hyperlactatemia", "Severe Hyperlactatemia", "Lactic Acidosis"}, unchipped = false, simplehealth = false},
	description = "Your tissues are not getting enough oxygen and are building up lactic acid.",
})

Define("holding_breath", {
	position = 24.9,
	mood = "good",
	active = function(_, org) if org.holdingbreath then return 1 end end,
	name = "Holding Breath",
	description = "You are holding your breath.",
})

Define("simple_countdown", {
	position = 5,
	active = function(_, org)
		local state = hg.SimpleHealth and hg.SimpleHealth.GetLocalState and hg.SimpleHealth.GetLocalState()
		if state and state.countdownEnd and state.countdownEnd > CurTime() then return 4, math.ceil(state.countdownEnd - CurTime()) .. "s" end
	end,
	name = {simplehealth = "Dying"},
	description = "Your death countdown is running. Get help now.",
})

Define("simple_toxin", {
	position = 53,
	active = function(_, org)
		local state = hg.SimpleHealth and hg.SimpleHealth.GetLocalState and hg.SimpleHealth.GetLocalState()
		local maximum = hg.SimpleHealth and hg.SimpleHealth.Config and hg.SimpleHealth.Config.maxHealth
		if not state or not isnumber(state.toxin) or not maximum then return end
		local fraction = state.toxin / maximum
		local level = high(fraction, {0.05, 0.25, 0.5, 0.75})
		if level > 0 then return level, math.floor(state.toxin) end
	end,
	name = {simplehealth = {"Mild Toxins", "Poisoned", "Badly Poisoned", "Lethal Toxins"}},
	description = "Toxins in your blood are eating away at your health.",
})
