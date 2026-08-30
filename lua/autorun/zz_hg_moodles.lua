-- The normal Homigrad moodle renderer. The legacy/alternate moodles in
-- zb_health_hud.lua are intentionally bypassed while this file is loaded.
if SERVER then
	AddCSLuaFile()

	local moodle3Files = file.Find("materials/vgui/hud/moodles 3/*.png", "GAME")
	for _, name in ipairs(moodle3Files) do
		resource.AddFile("materials/vgui/hud/moodles 3/" .. name)
	end
	local standaloneMoodle3Files = file.Find("materials/vgui/moodles 3/*.png", "GAME")
	for _, name in ipairs(standaloneMoodle3Files) do
		resource.AddFile("materials/vgui/moodles 3/" .. name)
	end

	local moodleType = CreateConVar("hg_moodletype", "2", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, "Moodle 3 moodles", 2, 2)
	if moodleType:GetInt() ~= 2 then moodleType:SetInt(2) end

	return
end

HGCustomMoodlesActive = true

local enabled = CreateClientConVar("hg_moodles_enabled", "1", true, false, "Show Homigrad moodles")
local moodle3Icons, appearances, lastLevels = {}, {}, {}
local moodlePositions = {}
local hover = {index = nil, scale = 1}

surface.CreateFont("HG_MoodleRageText", {
	font = "VCR OSD Mono",
	size = ScreenScale(8),
	weight = 500,
	antialias = true,
	extended = true,
})

surface.CreateFont("HG_MoodleTitle", {
	font = "VCR OSD Mono",
	size = ScreenScale(9),
	weight = 700,
	antialias = true,
	extended = true,
})

surface.CreateFont("HG_MoodleText", {
	font = "VCR OSD Mono",
	size = ScreenScale(7),
	weight = 500,
	antialias = true,
	extended = true,
})

-- Every moodle has four named stages. Analgesia and maximum stamina have
-- separate good/bad ladders because the same numeric level can mean either.
local moodleTexts = {
	fracture = {levels = {
		[1] = {title = "Single Fracture", description = "One limb is fractured and painful to use."},
		[2] = {title = "Multiple Fractures", description = "Two limbs are fractured and movement is becoming difficult."},
		[3] = {title = "Severe Fractures", description = "Three fractured limbs leave you barely mobile."},
		[4] = {title = "Four-Limb Fractures", description = "All four limbs are fractured and nearly unusable."},
	}},
	dislocated = {levels = {
		[1] = {title = "Single Dislocation", description = "One limb joint has been forced out of place."},
		[2] = {title = "Multiple Dislocations", description = "Two limb joints are dislocated and difficult to control."},
		[3] = {title = "Severe Dislocations", description = "Three dislocated limbs leave movement severely impaired."},
		[4] = {title = "Four-Limb Dislocation", description = "Every limb is dislocated and effectively unusable."},
	}},
	analgesia = {
		good = {
			[1] = {title = "Numbed", description = "Pain is being dulled by a mild analgesic effect."},
			[2] = {title = "Analgesia", description = "Medication is providing noticeable pain relief."},
			[3] = {title = "Strong Analgesia", description = "Most pain is suppressed by strong medication."},
			[4] = {title = "Profound Analgesia", description = "Pain is almost completely suppressed for now."},
		},
		bad = {
			[1] = {title = "Medication Load", description = "Medication is beginning to burden your body."},
			[2] = {title = "Excessive Dose", description = "You have taken more pain medication than is safe."},
			[3] = {title = "Overdose", description = "The drug load is suppressing vital bodily functions."},
			[4] = {title = "Fatal Overdose", description = "Respiratory and circulatory failure are becoming imminent."},
		},
	},
	stamina = {
		good = {
			[1] = {title = "Fit", description = "Your maximum stamina is slightly above normal."},
			[2] = {title = "Conditioned", description = "Your endurance is clearly better than average."},
			[3] = {title = "Athletic", description = "Your body can sustain prolonged physical effort."},
			[4] = {title = "Peak Endurance", description = "Your maximum stamina is exceptionally high."},
		},
		bad = {
			[1] = {title = "Poor Endurance", description = "Your maximum stamina is below normal."},
			[2] = {title = "Low Endurance", description = "You tire quickly because your stamina capacity is reduced."},
			[3] = {title = "Very Low Endurance", description = "Even modest activity rapidly exhausts you."},
			[4] = {title = "Ruined Endurance", description = "Your stamina capacity is critically limited."},
		},
	},
	exertion = {levels = {
		[1] = {title = "Winded", description = "Your current stamina is beginning to run low."},
		[2] = {title = "Exerted", description = "Low stamina is slowing your recovery and movement."},
		[3] = {title = "Exhausted", description = "You need to rest before your body can perform normally."},
		[4] = {title = "No Stamina", description = "You are completely spent and need immediate rest."},
	}},
	tired = {levels = {
		[1] = {title = "Slightly Tired", description = "Activity has strained you, but you can keep going."},
		[2] = {title = "Tired", description = "You should slow down and catch your breath."},
		[3] = {title = "Very Exhausted", description = "Movement is difficult and your breathing is labored."},
		[4] = {title = "Exhausted", description = "You can barely breathe or continue moving."},
	}},
	happy = {levels = {
		[1] = {title = "Content", description = "A small lift in mood is helping recovery and resolve."},
		[2] = {title = "Cheerful", description = "Your good mood is improving stamina recovery and strength."},
		[3] = {title = "Happy", description = "Strong morale is improving recovery, damage, and resilience."},
		[4] = {title = "Euphoric", description = "Peak morale is boosting stamina recovery, damage, and resilience."},
	}},
	bleeding = {levels = {
		[1] = {title = "Small Bleed", description = "A wound is releasing blood at a small rate."},
		[2] = {title = "Bleeding", description = "Blood loss is noticeable and should be treated soon."},
		[3] = {title = "Heavy Bleeding", description = "Blood is pouring from a serious wound."},
		[4] = {title = "Catastrophic Bleeding", description = "You are rapidly bleeding out and need immediate treatment."},
	}},
	pain = {levels = {
		[1] = {title = "Mild Pain", description = "A manageable ache is warning you of injury."},
		[2] = {title = "Pain", description = "Persistent pain is beginning to affect your actions."},
		[3] = {title = "Severe Pain", description = "Intense pain is disrupting movement and concentration."},
		[4] = {title = "Agony", description = "Overwhelming pain is pushing you toward unconsciousness."},
	}},
	burning = {levels = {
		[1] = {title = "Burning", description = "Fire has caught on your clothing or body."},
		[2] = {title = "Burning", description = "The flames are spreading and causing serious burns."},
		[3] = {title = "Engulfed", description = "Much of your body is engulfed in flames."},
		[4] = {title = "Consumed by Fire", description = "You are fully ablaze and need to extinguish yourself immediately."},
	}},
	carbon_monoxide = {levels = {
		[1] = {title = "Carbon Monoxide Exposure", description = "A mild headache signals toxic gas exposure."},
		[2] = {title = "Carbon Monoxide Poisoning", description = "Dizziness and confusion are developing from poor oxygen delivery."},
		[3] = {title = "Severe CO Poisoning", description = "Toxic gas is seriously impairing your brain and movement."},
		[4] = {title = "Deadly CO Poisoning", description = "Your blood can no longer deliver enough oxygen to survive."},
	}},
	arrhythmia = {levels = {
		[1] = {title = "Arrhythmia", description = "Your heartbeat is becoming irregular."},
		[2] = {title = "Arrhythmia", description = "An abnormal heart rhythm is affecting circulation."},
		[3] = {title = "Severe Arrhythmia", description = "Your heart rhythm is dangerously unstable."},
		[4] = {title = "Critical Arrhythmia", description = "Your heart is struggling to maintain an effective rhythm."},
	}},
	fibrillation = {levels = {
		[1] = {title = "Palpitations", description = "You can feel an abnormal fluttering heartbeat."},
		[2] = {title = "Palpitations", description = "Your heartbeat is forceful and irregular."},
		[3] = {title = "Ventricular Fibrillation", description = "A dangerously fast, irregular rhythm is weakening circulation."},
		[4] = {title = "Ventricular Fibrillation", description = "Your heart is contracting too chaotically to sustain circulation."},
	}},
	hypoxemia = {levels = {
		[1] = {title = "Hypoxemia", description = "Your blood oxygen level is mildly reduced."},
		[2] = {title = "Severe Hypoxemia", description = "Low oxygen is causing dizziness and numbness."},
		[3] = {title = "Asphyxia", description = "Your tissues are starved of oxygen and consciousness is fading."},
		[4] = {title = "Anoxemia", description = "Extreme oxygen deprivation is causing widespread organ failure."},
	}},
	asystole = {levels = {
		[1] = {title = "Failing Rhythm", description = "Your heart rhythm is losing effective output."},
		[2] = {title = "Critical Arrhythmia", description = "Circulation is failing as your heart loses rhythm."},
		[3] = {title = "Agonal Rhythm", description = "Only weak, ineffective cardiac activity remains."},
		[4] = {title = "Cardiac Arrest", description = "Your heart has stopped producing effective circulation."},
	}},
	low_blood = {levels = {
		[1] = {title = "Low Pulse", description = "Your pulse is slower than normal."},
		[2] = {title = "Bradycardia", description = "A slow pulse is causing weakness and lightheadedness."},
		[3] = {title = "Severe Bradycardia", description = "Your pulse is dangerously slow and circulation is weakening."},
		[4] = {title = "Critical Bradycardia", description = "Your pulse is critically slow and may no longer sustain circulation."},
	}},
	high_blood = {levels = {
		[1] = {title = "Elevated Circulation", description = "Your pressure or pulse is slightly above normal."},
		[2] = {title = "High Blood Pressure", description = "Your cardiovascular system is under noticeable strain."},
		[3] = {title = "Severe Hypertension", description = "Dangerous pressure is stressing your heart and blood vessels."},
		[4] = {title = "Hypertensive Crisis", description = "Extreme pressure threatens immediate organ and vessel damage."},
	}},
	no_eye = {levels = {
		[1] = {title = "Dazzled", description = "Bright light has temporarily impaired your vision."},
		[2] = {title = "Partial Blindness", description = "Eye damage or flashing has removed much of your sight."},
		[3] = {title = "Severe Blindness", description = "Only limited vision remains available to you."},
		[4] = {title = "Blind", description = "You cannot see through your remaining vision."},
	}},
	blinded = {levels = {
		[1] = {title = "Blurred Vision", description = "Your sight is slightly unfocused and unstable."},
		[2] = {title = "Impaired Vision", description = "Disorientation is seriously disturbing your sight."},
		[3] = {title = "Severe Visual Distortion", description = "Your surroundings are difficult to perceive or track."},
		[4] = {title = "Visual Overload", description = "Active interference has made useful vision nearly impossible."},
	}},
	brain_bleed = {levels = {
		[1] = {title = "Intracranial Bleeding", description = "A mild headache and disorientation are developing."},
		[2] = {title = "Brain Hemorrhage", description = "Blood is accumulating inside your skull."},
		[3] = {title = "Severe Brain Hemorrhage", description = "Confusion and neurological function are rapidly worsening."},
		[4] = {title = "Massive Brain Hemorrhage", description = "Critical bleeding is crushing the brain inside your skull."},
	}},
	intracranial_pressure = {levels = {
		[1] = {title = "Raised Intracranial Pressure", description = "Swelling inside your skull is beginning to cause discomfort."},
		[2] = {title = "Intracranial Hypertension", description = "Increasing pressure is impairing normal brain function."},
		[3] = {title = "Severe Cranial Pressure", description = "Brain compression is causing serious neurological deterioration."},
		[4] = {title = "Critical Brain Compression", description = "Extreme pressure threatens herniation and immediate death."},
	}},
	weakness = {levels = {
		[1] = {title = "Weakness", description = "Your limbs feel slightly heavy and unresponsive."},
		[2] = {title = "Reduced Mobility", description = "Poor control and perfusion are limiting your movement."},
		[3] = {title = "Severe Weakness", description = "Your limbs can barely support or obey you."},
		[4] = {title = "Near Paralysis", description = "Almost no useful limb strength or control remains."},
	}},
	bradypnea = {levels = {
		[1] = {title = "Shortness of Breath", description = "Your breathing is slightly behind your oxygen demand."},
		[2] = {title = "Shallow Breathing", description = "Each breath is failing to restore enough oxygen."},
		[3] = {title = "Bradypnea", description = "Your breathing is dangerously slow and ineffective."},
		[4] = {title = "Critical Bradypnea", description = "You can barely draw enough breath to remain conscious."},
	}},
	thorax = {levels = {
		[1] = {title = "Lung Discomfort", description = "Air or blood is beginning to collect around a lung."},
		[2] = {title = "Pleural Pressure", description = "Pressure around the lungs is making breathing difficult."},
		[3] = {title = "Severe Thoracic Injury", description = "A pneumothorax or hemothorax is severely restricting breathing."},
		[4] = {title = "Critical Thoracic Collapse", description = "Your chest injury is preventing effective respiration."},
	}},
	respiratory_arrest = {levels = {
		[1] = {title = "Respiratory Distress", description = "Your breathing is becoming ineffective."},
		[2] = {title = "Respiratory Failure", description = "Your lungs can no longer meet your oxygen needs."},
		[3] = {title = "Agonal Breathing", description = "Only occasional ineffective breaths remain."},
		[4] = {title = "Respiratory Arrest", description = "Effective breathing has completely stopped."},
	}},
	skull = {levels = {
		[1] = {title = "Skull Trauma", description = "Your skull has sustained a concerning impact."},
		[2] = {title = "Skull Fissure", description = "A developing crack is weakening your skull."},
		[3] = {title = "Partial Skull Fracture", description = "Your skull is fractured and no longer fully protecting the brain."},
		[4] = {title = "Broken Skull", description = "Your skull is completely fractured around vulnerable brain tissue."},
	}},
	dislocated_jaw = {levels = {
		[1] = {title = "Jaw Strain", description = "Your jaw joint is damaged and painful to move."},
		[2] = {title = "Dislocated Jaw", description = "Your jaw has been forced out of its normal socket."},
		[3] = {title = "Severe Jaw Dislocation", description = "Your displaced jaw is causing major facial dysfunction."},
		[4] = {title = "Broken Jaw", description = "Your jaw is fractured and painful to move or speak with."},
	}},
	organ_damage = {levels = {
		[1] = {title = "Severe Organ Damage", description = "One or more internal organs are badly damaged."},
		[2] = {title = "Destroyed Organ", description = "An internal organ has been completely destroyed."},
		[3] = {title = "Critical Organ Loss", description = "A vital lung or liver has been destroyed or critically damaged."},
		[4] = {title = "Catastrophic Organ Failure", description = "Essential organs can no longer sustain life."},
	}},
	spine_break = {levels = {
		[1] = {title = "Back Injury", description = "Trauma has weakened part of your spinal column."},
		[2] = {title = "Spinal Injury", description = "Your spine is damaged and neurological function is threatened."},
		[3] = {title = "Spine Fracture", description = "A spinal segment is broken and movement is severely impaired."},
		[4] = {title = "Catastrophic Spine Fracture", description = "A critical spinal segment is broken with devastating consequences."},
	}},
	temperature = {levels = {
		[1] = {title = "Abnormal Temperature", description = "Your body is slightly warmer or colder than normal."},
		[2] = {title = "Temperature Stress", description = "Heat or cold is beginning to impair your body."},
		[3] = {title = "Severe Temperature Exposure", description = "Dangerous heat or cold is overwhelming normal regulation."},
		[4] = {title = "Lethal Temperature", description = "Extreme heat or cold is rapidly killing you."},
	}},
	consciousness = {levels = {
		[1] = {title = "Disoriented", description = "You feel sleepy and slightly confused."},
		[2] = {title = "Confused", description = "You are drowsy and struggling to understand your surroundings."},
		[3] = {title = "Fainting", description = "You are barely conscious and may collapse at any moment."},
		[4] = {title = "Unconscious", description = "You are unresponsive to the world around you."},
	}},
	shock = {levels = {
		[1] = {title = "Vasovagal Response", description = "Your body is beginning to react strongly to trauma."},
		[2] = {title = "Developing Shock", description = "Sweating, dizziness, and drowsiness are setting in."},
		[3] = {title = "Traumatic Shock", description = "Tunnel vision and extreme faintness are overwhelming you."},
		[4] = {title = "Critical Shock", description = "Your body can no longer compensate for the trauma."},
	}},
	seizure = {levels = {
		[1] = {title = "Neurological Instability", description = "Abnormal activity is beginning to disturb your nervous system."},
		[2] = {title = "Seizure Warning", description = "Muscle control and awareness are becoming unreliable."},
		[3] = {title = "Imminent Seizure", description = "A severe seizure may begin at any moment."},
		[4] = {title = "Seizing", description = "You are actively suffering an uncontrolled seizure."},
	}},
	internal_bleed = {levels = {
		[1] = {title = "Minor Internal Bleeding", description = "A small amount of blood is collecting inside your body."},
		[2] = {title = "Internal Bleeding", description = "Hidden blood loss is becoming medically significant."},
		[3] = {title = "Severe Internal Bleeding", description = "Internal blood loss or chest complications require urgent treatment."},
		[4] = {title = "Catastrophic Internal Bleeding", description = "Massive internal loss or hemothorax is immediately life-threatening."},
	}},
	panic = {levels = {
		[1] = {title = "Uneasy", description = "Fear is beginning to interfere with your focus."},
		[2] = {title = "Anxious", description = "Your breathing and attention are becoming difficult to control."},
		[3] = {title = "Panicking", description = "Overwhelming fear is disrupting perception and movement."},
		[4] = {title = "Panic Attack", description = "You have lost control to an acute panic response."},
	}},
	tinnitus = {levels = {
		[1] = {title = "Faint Ringing", description = "A quiet ringing is lingering in your ears."},
		[2] = {title = "Tinnitus", description = "Persistent ringing is interfering with normal hearing."},
		[3] = {title = "Severe Tinnitus", description = "Loud auditory distortion is drowning out your surroundings."},
		[4] = {title = "Deafening Tinnitus", description = "Overwhelming ringing has made useful hearing nearly impossible."},
	}},
	deaf = {levels = {
		[1] = {title = "Muffled Hearing", description = "Sounds around you have become dull and unclear."},
		[2] = {title = "Hearing Loss", description = "You are missing much of the sound around you."},
		[3] = {title = "Severe Hearing Loss", description = "Only loud or nearby sounds remain audible."},
		[4] = {title = "Deaf", description = "You can no longer hear your surroundings."},
	}},
	encumbered = {levels = {
		[1] = {title = "Weighted", description = "Your equipment adds strain without greatly limiting movement."},
		[2] = {title = "Encumbered", description = "Carried weight is noticeably slowing you down."},
		[3] = {title = "Heavily Encumbered", description = "Excessive equipment is severely limiting your mobility."},
		[4] = {title = "Overburdened", description = "Your load makes even basic movement extremely difficult."},
	}},
	nausea = {levels = {
		[1] = {title = "Queasy", description = "You feel slightly unwell and may become nauseated."},
		[2] = {title = "Nausea", description = "Stomach discomfort is giving you the urge to vomit."},
		[3] = {title = "Severe Nausea", description = "You are struggling to keep yourself from vomiting."},
		[4] = {title = "Overwhelming Nausea", description = "Violent sickness signals that something is seriously wrong."},
	}},
	amputated = {levels = {
		[1] = {title = "Severed Limb", description = "A limb has suffered devastating traumatic separation."},
		[2] = {title = "Amputation", description = "A limb is missing and requires immediate stump care."},
		[3] = {title = "Controlled Amputation", description = "A missing limb has been tourniqueted, limiting immediate blood loss."},
		[4] = {title = "Uncontrolled Amputation", description = "An untreated amputated limb is causing catastrophic blood loss."},
	}},
	concussion = {levels = {
		[1] = {title = "Headache", description = "A minor brain injury is causing pain and dizziness."},
		[2] = {title = "Light Concussion", description = "Your balance, focus, and vision are becoming unreliable."},
		[3] = {title = "Concussion", description = "Severe dizziness and confusion are disrupting your actions."},
		[4] = {title = "Cerebral Bruising", description = "Major brain trauma threatens memory and consciousness."},
	}},
	brain_damage = {levels = {
		[1] = {title = "Cognitive Impairment", description = "Brain damage is causing a small mental deficit."},
		[2] = {title = "Neurocognitive Damage", description = "Speech, memory, and balance are noticeably impaired."},
		[3] = {title = "Severe Brain Damage", description = "Coherent thought and bodily control are rapidly deteriorating."},
		[4] = {title = "Catastrophic Brain Damage", description = "Critical brain trauma is shutting down essential functions."},
	}},
	sepsis = {levels = {
		[1] = {title = "Localized Ischemia", description = "Poor circulation is beginning to damage vulnerable tissue."},
		[2] = {title = "Systemic Ischemia", description = "Widespread tissue is suffering from inadequate blood flow."},
		[3] = {title = "Severe Ischemic Shock", description = "Circulatory complications are driving organ dysfunction."},
		[4] = {title = "Septic Collapse", description = "Systemic damage and circulatory failure are becoming fatal."},
	}},
	adrenaline = {levels = {
		[1] = {title = "Tense", description = "A small adrenaline surge is improving alertness."},
		[2] = {title = "Alert", description = "Adrenaline is dulling pain and increasing readiness."},
		[3] = {title = "Fight or Flight", description = "A strong surge is greatly improving stamina and pain tolerance."},
		[4] = {title = "Focused", description = "Extreme adrenaline is driving your body at its limit."},
	}},
	zerlked = {levels = {
		[1] = {title = "Zerlked", description = "Zerlkers are helping you shrug off pain, shock, weakness, and unconsciousness."},
		[2] = {title = "Zerlked", description = "Zerlkers are helping you shrug off pain, shock, weakness, and unconsciousness."},
		[3] = {title = "Zerlked", description = "Zerlkers are helping you shrug off pain, shock, weakness, and unconsciousness."},
		[4] = {title = "Zerlked", description = "Zerlkers are helping you shrug off pain, shock, weakness, and unconsciousness."},
	}},
	anger = {levels = {
		[1] = {title = "Irritated", description = "Slightly angered at something."},
		[2] = {title = "Angry", description = "Anger due to combat is affecting your resolve and resilience."},
		[3] = {title = "Furious", description = "Pain and fear are being replaced by overwhelming rage."},
		[4] = {title = "Enraged", description = "Kill this kid."},
	}},
	rage = {fixed = {
		title = "UNDETERRABLE RAGE",
		description = "YOUR HANDS ARE BRUSHES, ALL ELSE IS A CANVAS. SO USE YOUR INSPIRATION AND paint your magnum opus.",
		descriptionLines = {"YOUR HANDS ARE BRUSHES, ALL ELSE IS A CANVAS.", "SO USE YOUR INSPIRATION AND paint", "your magnum opus."},
	}},
	armored = {levels = {
		[1] = {title = "Lightly Armored", description = "A small amount of armor protects part of your body."},
		[2] = {title = "Armored", description = "One substantial armor piece is protecting you."},
		[3] = {title = "Heavily Armored", description = "Multiple protected areas give strong defensive coverage."},
		[4] = {title = "Fully Armored", description = "Two or more major armor pieces provide excellent protection."},
	}},
}
local function getMoodle3Material(name)
	if moodle3Icons[name] == nil then
		local mat
		-- Zerlked lives in the dedicated Moodle 3 asset folder used by the
		-- content pack. Keep the legacy path as a fallback for older installs.
		if name == "zerlked" then
			mat = Material("vgui/moodles3/zerlked.png", "smooth")
			if not mat or mat:IsError() then
				mat = Material("vgui/hud/moodles 3/zerlked.png", "smooth")
			end
		elseif name == "panic" then
			mat = Material("vgui/moodles 3/panic.png", "smooth")
			if not mat or mat:IsError() then
				mat = Material("vgui/hud/moodles 3/panic.png", "smooth")
			end
		else
			mat = Material("vgui/hud/moodles 3/" .. name .. ".png", "smooth")
		end
		moodle3Icons[name] = mat and not mat:IsError() and mat or false
	end
	return moodle3Icons[name] or nil
end

-- Moodle 3 has purpose-made medical symbols. The effects themselves remain
-- shared with the existing renderer, which keeps every threshold in one place.
local function getMoodle3IconName(effect)
	if effect.moodle3Icon then return effect.moodle3Icon end
	local level = effect.level or 1
	local names = {
		fracture = "fractured", dislocated = "dislocated", analgesia = "drugged",
		stamina = "exertion", exertion = "exertion", bleeding = level == 1 and "bleeding" or "bleeding" .. level,
		carbon_monoxide = "hypoxemia", arrhythmia = "arrhythmia", fibrillation = "fibrillation",
		hypoxemia = "hypoxemia", brain_hypoxia = "brain-hypoxia", brain_dying = "brain-dying", asystole = "heart-failure",
		low_blood = "hypotension", high_blood = "hypertension", no_eye = "last-stand", blinded = "confused",
		brain_bleed = "terror", intracranial_pressure = "terror",
		weakness = "encumbered", bradypnea = "dyspnea", thorax = "hemothorax",
		respiratory_arrest = "respiratory-arrest", skull = "intercranial-hypertension",
		dislocated_jaw = "dejawed", organ_damage = effect.icon, spine_break = "fractured",
		shock = "shock", seizure = "seizure", internal_bleed = "internal-bleeding",
		panic = "panic", fear = "trauma", tinnitus = "tinnitus", deaf = "deafness", encumbered = "encumbered",
		nausea = "sick", amputated = "amputation", concussion = "stress", sepsis = "sepsis",
		adrenaline = "adrenaline", zerlked = "zerlked",
		rage = "anger5",
		hunger = level == 1 and "hunger" or "hunger" .. level, full = level == 1 and "full" or "full2",
	}
	local name = names[effect.name]
	if effect.name == "burning" then
		return getMoodle3Material("burning") and "burning" or "hyperthermia"
	end
	if effect.name == "pain" then name = level == 4 and "agony" or level == 3 and "extreme-pain" or "pain" end
	if effect.name == "tired" then name = level >= 3 and "very-tired" or "tired" end
	if effect.name == "consciousness" then name = level == 4 and "unconscious" or level >= 2 and "very-tired" or "tired" end
	if effect.name == "happy" then name = level == 1 and "happy" or "happy" .. level end
	if effect.name == "anger" then name = "anger" .. level end
	if effect.name == "blinded" then name = "confused" end
	if effect.name == "brain_damage" then name = level == 1 and "brain-damage" or "brain-damage" .. level end
	if effect.name == "temperature" then
		name = effect.icon == "veryhot" and "hyperthermia" or effect.icon == "heated" and "hot" or level >= 3 and "hypothermia" or "cold"
	end
	return name
end

local function getMoodle3Icon(effect)
	local name = getMoodle3IconName(effect)
	return name and getMoodle3Material(name) or nil
end

local sharedMoodle3Texts = {
	terror = {levels = {
		[1] = {title = "Neurological Distress", description = "Something is wrong with your brain, but the cause is unclear."},
		[2] = {title = "Brain Dysfunction", description = "A problem inside your skull is affecting normal brain function."},
		[3] = {title = "Severe Brain Dysfunction", description = "Your brain is under serious strain and your condition is worsening."},
		[4] = {title = "Critical Brain Dysfunction", description = "Your brain is failing and vital functions are in danger."},
	}},
	trauma = {levels = {
		[1] = {title = "Distress", description = "Your body is under strain and something is affecting your welfare."},
		[2] = {title = "Severe Distress", description = "Your body is struggling with a serious condition."},
		[3] = {title = "Critical Distress", description = "A serious condition is rapidly worsening your overall state."},
		[4] = {title = "Extreme Distress", description = "Your body is in extreme danger and vital functions are failing."},
	}},
	default = {levels = {
		[1] = {title = "Multiple Conditions", description = "More than one condition is affecting your welfare."},
		[2] = {title = "Worsening Condition", description = "Several conditions are beginning to impair your body."},
		[3] = {title = "Severe Condition", description = "Multiple serious conditions are impairing your body."},
		[4] = {title = "Critical Condition", description = "Multiple critical conditions are threatening your life."},
	}},
}

local function mergeMoodle3Effects(effects)
	local result, byIcon = {}, {}
	for _, effect in ipairs(effects) do
		local iconName = getMoodle3IconName(effect)
		local current = iconName and byIcon[iconName] or nil
		if not current then
			effect.moodle3Icon = iconName
			if iconName then byIcon[iconName] = effect end
			result[#result + 1] = effect
		else
			current.name = "moodle3_shared_" .. string.gsub(iconName, "[^%w_]", "_")
			current.level = math.max(current.level, effect.level)
			current.priority = math.min(current.priority, effect.priority)
			if current.mood == "bad" or effect.mood == "bad" then current.mood = "bad" end
			current.value = nil
			current.sharedMoodle3Text = sharedMoodle3Texts[iconName] or sharedMoodle3Texts.default
		end
	end
	return result
end

local function number(value, fallback) return isnumber(value) and value or (fallback or 0) end
local function orgNumber(org, key, fallback) return number(org[key], fallback) end
local function tableNumber(org, key, index, fallback)
	local value = org[key]
	return istable(value) and number(value[index], fallback) or (fallback or 0)
end
local function o2Value(org) return istable(org.o2) and number(org.o2[1], 30) or number(org.o2, 30) end
local function o2Maximum(org) return istable(org.o2) and number(org.o2.range, 30) or 30 end

local function highRank(value, thresholds)
	local rank = 0
	for level = 1, 4 do if value >= thresholds[level] then rank = level end end
	return rank
end

local function lowRank(value, thresholds)
	local rank = 0
	for level = 1, 4 do if value <= thresholds[level] then rank = level end end
	return rank
end

local function add(effects, name, icon, level, mood, priority, value)
	effects[#effects + 1] = {
		name = name, icon = icon, level = math.Clamp(math.floor(number(level, 1)), 1, 4),
		mood = mood or "bad", priority = priority or 100, value = value,
	}
end

local function burningFireCount(ent)
	if not IsValid(ent) or not ent:IsOnFire() then return 0 end
	return math.max(istable(ent.fires) and table.Count(ent.fires) or 0, 1)
end

local limbKeys = {"larm", "rarm", "lleg", "rleg"}
local function countFractures(org)
	local count = 0
	for _, limb in ipairs(limbKeys) do
		if orgNumber(org, limb, 0) >= 0.95 and org[limb .. "amputated"] ~= true then count = count + 1 end
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
local function countEntries(tbl)
	if not istable(tbl) then return 0 end
	local count = 0
	for _, value in pairs(tbl) do if value ~= nil and value ~= false and value ~= "" then count = count + 1 end end
	return count
end
local function tourniquetLimb(bone)
	if not isstring(bone) then return nil end
	local side = string.find(bone, "_L_", 1, true) and "l" or string.find(bone, "_R_", 1, true) and "r" or nil
	if not side then return nil end
	if string.find(bone, "Arm", 1, true) or string.find(bone, "Hand", 1, true) then return side .. "arm" end
	if string.find(bone, "Thigh", 1, true) or string.find(bone, "Calf", 1, true) or string.find(bone, "Foot", 1, true) then return side .. "leg" end
end
local function getTourniquetedLimbs(ply)
	local result = {}
	for _, data in pairs(ply:GetNetVar("Tourniquets", {}) or {}) do
		local limb = tourniquetLimb(istable(data) and data[3] or nil)
		if limb then result[limb] = true end
	end
	return result
end

local function buildEffects(ply, org)
	local effects = {}

	local fractures = countFractures(org)
	if fractures > 0 then add(effects, "fracture", "fracture", fractures, "bad", 50, fractures) end
	local dislocations = countDislocations(org)
	if dislocations > 0 then add(effects, "dislocated", "dislocated", dislocations, "bad", 51, dislocations) end

	local analgesia, painkiller = orgNumber(org, "analgesia", 0), orgNumber(org, "painkiller", 0)
	if analgesia > 0 or painkiller > 0 then
		local level, mood, icon = 1, "good", "analgesia"
		if analgesia > 2 or painkiller > 5 then level, mood, icon = 4, "bad", "analgesia2"
		elseif analgesia > 1.5 or painkiller > 4 then level, mood, icon = 3, "bad", "analgesia2"
		elseif analgesia > 1 or painkiller > 3 then level, mood, icon = 2, "bad", "analgesia2"
		elseif analgesia >= 0.75 then level, icon = 4, "analgesia2"
		elseif analgesia >= 0.5 then level, icon = 3, "analgesia2"
		elseif analgesia >= 0.25 or painkiller >= 1.5 then level = 2 end
		add(effects, "analgesia", icon, level, mood, 10, math.Round(math.max(analgesia, painkiller), 1))
	end

	local stamina = istable(org.stamina) and org.stamina or nil
	if stamina then
		local staminaMax = number(stamina.max, number(stamina.range, 180))
		local staminaFraction = math.Clamp(number(stamina[1], staminaMax) / math.max(staminaMax, 1), 0, 1)
		if staminaFraction < 0.75 then
			local level = lowRank(staminaFraction, {0.75, 0.5, 0.25, 0.1})
			-- Moodle 3 reserves tired/very-tired for consciousness. Exertion shows
			-- actual stamina depletion in place of the fitness moodle.
			add(effects, "exertion", "exertion", level, "bad", 13, math.floor(staminaFraction * 100) .. "%")
		end
	end

	local goodmood = math.Clamp(orgNumber(org, "goodmood", 0), 0, 1)
	if goodmood > 0 then add(effects, "happy", "happy", math.ceil(goodmood * 4), "good", 15, math.floor(goodmood * 100) .. "%") end
	if org.berserkActive2 == true then add(effects, "rage", "rage", 4, "bad", -90) end
	local hungry = math.Clamp(orgNumber(org, "hungry", 0), 0, 100)
	local satiety = math.Clamp(orgNumber(org, "satiety", 0), 0, 100)
	local hungerSystem = GetConVar("hg_hungersystem")
	if hungerSystem and hungerSystem:GetBool() and hungry > 10 then
		add(effects, "hunger", "hunger", highRank(hungry, {10, 30, 55, 75}), "bad", 17, math.floor(hungry) .. "%")
	elseif hungerSystem and hungerSystem:GetBool() and satiety >= 80 then
		add(effects, "full", "full", satiety >= 95 and 2 or 1, "good", 17, math.floor(satiety) .. "%")
	end

	local bleed = orgNumber(org, "bleed", 0)
	if bleed > 0 then
		local level = bleed > 0.15 and 4 or bleed > 0.1 and 3 or bleed > 0.05 and 2 or 1
		add(effects, "bleeding", ({"lowbleed", "bleeding", "bigbleed", "bigbadbleed"})[level], level, "bad", 20, math.Round(bleed, 2))
	end
	local pain = orgNumber(org, "pain", 0)
	if pain > 20 and org.berserkActive2 ~= true then
		local level = pain >= 85 and 4 or pain >= 60 and 3 or pain > 45 and 2 or 1
		add(effects, "pain", ({"smallpain", "pain", "superpain", "agony"})[level], level, "bad", 21, math.floor(pain))
	end
	-- vFire is attached to the fake ragdoll while the player is unconscious.
	-- Read both entities so the moodle survives fake/downed state transitions.
	local character = hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
	local fireCount = math.max(burningFireCount(ply), burningFireCount(character))
	if fireCount > 0 then
		add(effects, "burning", "burning", math.Clamp(fireCount, 1, 4), "bad", -75, fireCount)
	end
	local co = orgNumber(org, "CO", 0)
	if co > 5 then
		local level = co >= 25 and 4 or co >= 20 and 3 or co >= 10 and 2 or 1
		add(effects, "carbon_monoxide", "crabon", level, "bad", 22, math.floor(math.Clamp(co / 30, 0, 1) * 100) .. "%")
	end

	local heartRate = orgNumber(org, "heartbeat", orgNumber(org, "pulse", 70))
	local palpitations = math.Clamp(orgNumber(org, "palpitations", 0), 0, 1)
	local arrhythmia = math.Clamp(orgNumber(org, "arrhythmia", 0), 0, 1)
	local unstableRhythm = org.unstableRhythm
	local irregular = arrhythmia > 0.1 or unstableRhythm ~= nil
	local fibrillating = org.fibrillation == true
		or palpitations > 0.05
		or unstableRhythm == "atrial_fibrillation"
		or (irregular and heartRate >= 190)
	if not org.heartstop and fibrillating then
		local level = org.fibrillation and 4 or highRank(math.max(palpitations, arrhythmia, math.Clamp((heartRate - 160) / 140, 0, 1)), {0.1, 0.3, 0.6, 0.85})
		add(effects, "fibrillation", "fibrillation", level, "bad", org.fibrillation and -95 or 24, math.floor(heartRate) .. " bpm")
	elseif not org.heartstop and irregular then
		add(effects, "arrhythmia", "arrhythmia", highRank(arrhythmia, {0.1, 0.3, 0.6, 0.85}), "bad", 24.5, math.floor(heartRate) .. " bpm")
	end

	local oxygen, oxygenMax = o2Value(org), o2Maximum(org)
	if oxygen < math.min(28, oxygenMax) then
		local level = oxygen < 8 and 4 or oxygen < 14 and 3 or oxygen < 23 and 2 or 1
		add(effects, "hypoxemia", "hypoxemia", level, "bad", 26, math.floor(oxygen))
	end
	local brainOxygen = math.Clamp(orgNumber(org, "brainoxygen", 1), 0, 1)
	local hypoxiaTime = orgNumber(org, "hypoxiaTime", 0)
	if brainOxygen < 0.55 and hypoxiaTime > 2 then
		add(effects, "brain_hypoxia", "hypoxemia", lowRank(brainOxygen, {0.55, 0.42, 0.28, 0.15}), "bad", 26.5, math.floor(brainOxygen * 100) .. "%")
	end
	if org.heartstop == true then add(effects, "asystole", "asystole", 4, "bad", -100) end

	local pulse = math.max(orgNumber(org, "pulse", 70), 0)
	if not org.heartstop and pulse > 0 and pulse < 60 then
		local level = pulse < 30 and 4 or pulse < 40 and 3 or pulse < 50 and 2 or 1
		add(effects, "low_blood", level >= 3 and "superlowblood" or "lowblood", level, "bad", 27, math.floor(pulse) .. " bpm")
	end
	local hypertension = math.Clamp(orgNumber(org, "hypertension", 0), 0, 1)
	if not org.heartstop and hypertension > 0 then
		local level = math.Clamp(math.ceil(hypertension * 4), 1, 4)
		add(effects, "high_blood", "highblood", level, "bad", 28)
	end

	local flash = number(amtflashed, 0)
	if org.blindness ~= nil or flash >= 0.2 then
		local level = org.blindness == 0 and 4 or org.blindness ~= nil and 2 or highRank(flash, {0.2, 0.5, 0.8, 1.2})
		add(effects, "no_eye", "noeye", level, "bad", 29)
	end
	local disorientation = orgNumber(org, "disorientation", 0)
	local pepperBlind = ply:GetNWFloat("PS_BlindEndTime", 0) > CurTime()
	if disorientation > 0.2 or pepperBlind then
		local level = highRank(disorientation, {0.2, 1, 2.5, 3.5})
		if pepperBlind then level = math.max(level, 2) end
		add(effects, "blinded", "blinded", level, "bad", 30)
	end

	local hemorrhage = orgNumber(org, "brainHemorrhage", 0)
	if hemorrhage > 0 then add(effects, "brain_bleed", "brainbleed", highRank(hemorrhage, {0.0001, 0.25, 0.5, 0.75}), "bad", 31, math.floor(hemorrhage * 100) .. "%") end
	local intracranialPressure = orgNumber(org, "intracranialPressure", 0)
	if intracranialPressure >= 0.15 then add(effects, "intracranial_pressure", "intrapressure", highRank(intracranialPressure, {0.15, 0.35, 0.6, 0.85}), "bad", 32, math.floor(intracranialPressure * 100) .. "%") end

	-- Match the pain and shock penalties used by movement's effective speed
	-- multiplier so weakness reflects impaired control even when limb strength
	-- and perfusion are otherwise normal. Zerlkers suppress those two functional
	-- penalties, but not weakness from damaged limbs or poor circulation.
	local zerlkersWeaknessResistance = math.Clamp(orgNumber(org, "zerlkers", 0), 0, 1)
	local painControl = math.Clamp(60 / (pain + 1), 0.35, 1)
	local shockControl = math.Clamp(10 / (orgNumber(org, "shock", 0) + 1), 0.45, 1)
	painControl = Lerp(zerlkersWeaknessResistance, painControl, 1)
	shockControl = Lerp(zerlkersWeaknessResistance, shockControl, 1)
	local control = math.min(orgNumber(org, "peripheralperfusion", 1), orgNumber(org, "perfusionMoveMul", 1), orgNumber(org, "legstrength", 1), orgNumber(org, "armstrength", 1))
	control = control * painControl * shockControl
	if control < 0.75 then add(effects, "weakness", "weakness", lowRank(control, {0.75, 0.55, 0.35, 0.2}), "bad", 33, math.floor(control * 100) .. "%") end

	local o2Regen = istable(org.o2) and number(org.o2.curregen, 0) or 0
	local o2Demand = orgNumber(org, "losing_oxy", 0)
	if o2Demand > 0 and org.lungsfunction ~= false and org.respiratoryArrest ~= true and o2Regen < o2Demand and not org.holdingbreath then
		local deficit = math.Clamp(1 - o2Regen / o2Demand, 0, 1)
		add(effects, "bradypnea", "bradyapnea", highRank(deficit, {0.1, 0.3, 0.55, 0.8}), "bad", 34, math.floor(deficit * 100) .. "%")
	end
	local pneumothorax, hemothorax = orgNumber(org, "pneumothorax", 0), orgNumber(org, "hemothorax", 0)
	local thorax = math.max(pneumothorax, hemothorax)
	if thorax > 0.01 then add(effects, "thorax", "superthorax", highRank(thorax, {0.01, 0.1, 0.3, 0.7}), "bad", 35, math.floor(thorax * 100) .. "%") end
	if org.lungsfunction == false or org.respiratoryArrest == true then add(effects, "respiratory_arrest", "nolungs", 4, "bad", -90) end

	local skull = orgNumber(org, "skull", 0)
	if skull >= 0.6 then add(effects, "skull", skull >= 1 and "skull2" or "skull1", skull >= 1 and 4 or 3, "bad", 53, math.floor(skull * 100) .. "%") end
	local jawBroken = orgNumber(org, "jaw", 0) >= 1
	local jawDislocated = org.jawdislocation == true or org.jawdislocated == true
	if jawBroken or jawDislocated then
		add(effects, "dislocated_jaw", "dislocatedjaw", jawBroken and 4 or 2, "bad", 54)
	end

	local heart, trachea = orgNumber(org, "heart", 0), orgNumber(org, "trachea", 0)
	local liver, stomach, intestines = orgNumber(org, "liver", 0), orgNumber(org, "stomach", 0), orgNumber(org, "intestines", 0)
	local lungL, lungR = tableNumber(org, "lungsL", 1, 0), tableNumber(org, "lungsR", 1, 0)
	local lungPenetratedL, lungPenetratedR = tableNumber(org, "lungsL", 2, 0), tableNumber(org, "lungsR", 2, 0)
	local organPeak = math.max(heart, trachea, liver, stomach, intestines, lungL, lungR)
	local hasRespiratoryOrganDamage = math.max(trachea, lungL, lungR, lungPenetratedL, lungPenetratedR) > 0
	if organPeak >= 0.6 or hasRespiratoryOrganDamage then
		local combatLevel = organPeak >= 1 and 2 or 1
		if lungL >= 0.8 or lungR >= 0.8 or liver >= 0.8 then combatLevel = 3 end
		if heart >= 0.8 or trachea >= 0.8 or (lungL >= 0.8 and lungR >= 0.8) then combatLevel = 4 end
		if heart >= 1 or trachea >= 1 or (lungL >= 1 and lungR >= 1) then combatLevel = 5 end
		-- Organ loss is trauma in Moodle 3 as well, including lungs and trachea.
		-- Reserve dyspnea for the separate breathing-deficit moodle above.
		local organIcon = "combat" .. combatLevel
		add(effects, "organ_damage", organIcon, math.min(combatLevel, 4), "bad", 55)
	end

	local spine1, spine2, spine3 = orgNumber(org, "spine1", 0), orgNumber(org, "spine2", 0), orgNumber(org, "spine3", 0)
	if spine1 >= 0.95 or spine2 >= 0.95 or spine3 >= 0.95 then
		add(effects, "spine_break", "spinebreak", (spine2 >= 0.95 or spine3 >= 0.95) and 4 or 3, "bad", 56)
	end

	local temperature = orgNumber(org, "temperature", 36.7)
	if temperature >= 40 then
		add(effects, "temperature", "veryhot", 4, "bad", 36, math.Round(temperature, 1) .. " C")
	elseif temperature > 37.5 then
		add(effects, "temperature", "heated", temperature >= 39.3 and 3 or temperature >= 38.4 and 2 or 1, "bad", 36, math.Round(temperature, 1) .. " C")
	elseif temperature < 36 then
		local level = temperature < 31 and 4 or temperature < 33 and 3 or temperature < 35 and 2 or 1
		add(effects, "temperature", level >= 3 and "cold2" or "cold1", level, "bad", 36, math.Round(temperature, 1) .. " C")
	end

	local consciousness = orgNumber(org, "consciousness", 1)
	if consciousness < 0.9 then
		local level = lowRank(consciousness, {0.9, 0.75, 0.5, 0.25})
		if org.otrub == true then level = 4 end
		add(effects, "consciousness", level == 4 and "otrub" or "sleepy" .. level, level, "bad", 37, math.floor(consciousness * 100) .. "%")
	end
	local shock = orgNumber(org, "shock", 0)
	if shock > 10 then add(effects, "shock", "shock", highRank(shock, {10, 20, 30, 40}), "bad", 38, math.floor(shock)) end
	if org.seizureActive == true then add(effects, "seizure", "seizureing", 4, "bad", -80) end
	local internalBleed = orgNumber(org, "internalBleed", 0)
	local complication = orgNumber(org, "internalBleedComplication", 0)
	if internalBleed > 0.05 then
		local level = highRank(internalBleed, {0.05, 0.5, 1.5, 2.5})
		if thorax > 0.01 or complication > 0.01 then level = math.max(level, 3) end
		if hemothorax >= 0.5 or complication >= 0.65 then level = 4 end
		add(effects, "internal_bleed", "internalbleed", level, "bad", 39, math.Round(internalBleed, 2))
	end

	local panic = math.Clamp(orgNumber(org, "panicattack", 0), 0, 1)
	if org.panicattackActive == true then
		add(effects, "panic", "panicmaxxing", org.panicattackActive and 4 or highRank(panic, {0.1, 0.35, 0.6, 0.85}), "bad", 40, math.floor(panic * 100) .. "%")
	end
	local fear = math.Clamp(orgNumber(org, "fear", 0), 0, 1)
	if fear > 0.1 then
		add(effects, "fear", "trauma", highRank(fear, {0.1, 0.35, 0.6, 0.85}), "bad", 39.5, math.floor(fear * 100) .. "%")
	end

	local tinnitusTime = math.max(number(ply.tinnitus, 0) - CurTime(), 0)
	local temporalDamage = orgNumber(org, "brainTemporal", 0)
	if tinnitusTime > 0 or temporalDamage > 0.1 then
		local tinnitusSeverity = math.max(math.Clamp(tinnitusTime / 40, 0, 1), math.Clamp(temporalDamage, 0, 1))
		add(effects, "tinnitus", "tinitus", highRank(tinnitusSeverity, {0.01, 0.25, 0.5, 0.75}), "bad", 41)
		if tinnitusTime >= 20 or temporalDamage >= 0.75 then
			add(effects, "deaf", "deaf", (tinnitusTime >= 40 or temporalDamage >= 1) and 4 or 3, "bad", 42)
		end
	end

	local weight, maxWeight = orgNumber(org, "weight", 0), math.max(orgNumber(org, "maxweight", 60), 1)
	local weightFraction = weight / maxWeight
	if weightFraction > 0.5 then add(effects, "encumbered", "encumbered", highRank(weightFraction, {0.5, 0.7, 0.85, 0.95}), "bad", 60, math.floor(weightFraction * 100) .. "%") end
	local nausea = orgNumber(org, "wantToVomit", 0)
	if nausea > 0.2 then add(effects, "nausea", "nausea", highRank(nausea, {0.2, 0.6, 0.8, 0.9}), "bad", 43, math.floor(nausea * 100) .. "%") end

	local tourniqueted = getTourniquetedLimbs(ply)
	local amputations, untreatedAmputation = 0, false
	for _, limb in ipairs(limbKeys) do
		if org[limb .. "amputated"] == true then
			amputations = amputations + 1
			if not tourniqueted[limb] then untreatedAmputation = true end
		end
	end
	if amputations > 0 then add(effects, "amputated", "amputated", untreatedAmputation and 4 or 3, "bad", -70, amputations) end

	local concussion = orgNumber(org, "concussion", 0)
	if concussion > 0.1 then add(effects, "concussion", "concussion", highRank(concussion, {0.1, 0.25, 0.5, 0.75}), "bad", 44, math.floor(concussion * 100) .. "%") end
	local brain = orgNumber(org, "brain", 0)
	if brain > 0.01 then
		if brain >= 0.35 then
			add(effects, "brain_dying", "dranbamage", 4, "bad", -85, math.floor(brain * 100) .. "%")
		else
			local level = highRank(brain, {0.01, 0.1, 0.18, 0.25})
			add(effects, "brain_damage", "dranbamage", level, "bad", 45, math.floor(brain * 100) .. "%")
		end
	end
	local ischemia, transfusionShock = orgNumber(org, "ischemia", 0), orgNumber(org, "hemotransfusionshock", 0)
	if ischemia > 0.1 or transfusionShock > 0.1 then
		local severity = math.max(ischemia, transfusionShock * 2)
		add(effects, "sepsis", "sepsis", highRank(severity, {0.1, 0.5, 1, 1.5}), "bad", 46, math.floor(severity * 100) .. "%")
	end

	local adrenaline = orgNumber(org, "adrenaline", 0)
	if adrenaline > 0.3 then add(effects, "adrenaline", "adrenaline", highRank(adrenaline, {0.3, 0.8, 1.5, 2.1}), "good", 11, math.Round(adrenaline, 1)) end
	local zerlkers = orgNumber(org, "zerlkers", 0)
	if zerlkers > 0 then
		-- A second concurrent dose is the Zerlkers overdose threshold. Keep the
		-- dedicated icon, but immediately swap it onto the bad moodle backing.
		local zerlkersOverdose = orgNumber(org, "zerlkersOverdose", 0)
		local mood = (zerlkers >= 2 or zerlkersOverdose > 0) and "bad" or "good"
		add(effects, "zerlked", "zerlked", math.Clamp(math.ceil(zerlkers * 4), 1, 4), mood, 10.5, math.ceil(zerlkers * 120) .. "s")
	end
	local anger = math.Clamp(orgNumber(org, "anger", 0), 0, 1)
	if anger > 0.01 then add(effects, "anger", "anger", math.ceil(anger * 4), "good", 14, math.floor(anger * 100) .. "%") end
	local armorCount = countEntries(ply:GetNetVar("Armor", {}) or {})
	if armorCount > 0 then add(effects, "armored", "armored", armorCount >= 2 and 4 or 2, "good", 16, armorCount) end

	table.sort(effects, function(a, b)
		if a.priority == b.priority then return a.name < b.name end
		return a.priority < b.priority
	end)
	return effects
end

local function drawGlowingRageText(text, font, x, y)
	local glowPulse = 0.75 + math.abs(math.sin(CurTime() * 4)) * 0.25
	for radius = 4, 1, -1 do
		local glow = Color(255, 0, 0, (5 - radius) * 14 * glowPulse)
		draw.SimpleText(text, font, x - radius, y, glow, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(text, font, x + radius, y, glow, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(text, font, x, y - radius, glow, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(text, font, x, y + radius, glow, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	draw.SimpleText(text, font, x, y, Color(255, 70, 70), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function drawTooltip(effect, pos, mx, my, berserkActive)
	if not effect or not pos or not mx or (mx == 0 and my == 0) then return end

	local rageActive = effect.name == "rage"
	local tooltipMood = effect.mood
	local tooltipLevel = effect.level
	local textData = effect.sharedMoodle3Text or moodleTexts[effect.name] or {}
	local textLevels = textData[tooltipMood] or textData.levels
	local levelText = rageActive and textData.fixed or textLevels and textLevels[tooltipLevel] or nil
	local title = levelText and levelText.title or effect.name
	local description = levelText and levelText.description or "An active condition is affecting you."
	local descriptionLines = rageActive and levelText and levelText.descriptionLines or {description}
	local details = not rageActive and "Severity " .. tooltipLevel .. " of 4" or nil
	if details and effect.value ~= nil then details = details .. " - " .. tostring(effect.value) end

	local titleFont = "HG_MoodleTitle"
	local descriptionFont = rageActive and "HG_MoodleRageText" or "HG_MoodleText"
	local descriptionLineSpacing = rageActive and 1 or 0
	surface.SetFont(titleFont)
	local titleWidth, titleHeight = surface.GetTextSize(title)
	surface.SetFont(descriptionFont)
	local descriptionWidth, descriptionHeight = 0, 0
	local descriptionHeights = {}
	for index, line in ipairs(descriptionLines) do
		local width, height = surface.GetTextSize(line)
		descriptionWidth = math.max(descriptionWidth, width)
		descriptionHeight = descriptionHeight + height
		descriptionHeights[index] = height
	end
	descriptionHeight = descriptionHeight + math.max(#descriptionLines - 1, 0) * descriptionLineSpacing
	local detailsWidth, detailsHeight = 0, 0
	if details then
		surface.SetFont("HG_MoodleText")
		detailsWidth, detailsHeight = surface.GetTextSize(details)
	end

	local padding, lineSpacing = 10, 4
	local totalWidth = math.max(titleWidth, descriptionWidth, detailsWidth) + padding * 2
	local totalHeight = titleHeight + lineSpacing + descriptionHeight + (details and lineSpacing + detailsHeight or 0) + padding * 2
	local baseX = pos.x + pos.size * 0.5 - totalWidth * 0.5
	local baseY = pos.y - totalHeight - 12
	local centerX, centerY = pos.x + pos.size * 0.5, pos.y - totalHeight * 0.5 - 12
	local parallaxX = math.Clamp((mx - centerX) * 0.1, -15, 15)
	local parallaxY = math.Clamp((my - centerY) * 0.1, -15, 15)
	local tooltipX = math.Clamp(baseX + parallaxX, 10, ScrW() - totalWidth - 10)
	local tooltipY = math.Clamp(baseY + parallaxY, 10, ScrH() - totalHeight - 10)

	surface.SetDrawColor(25, 25, 35, 240)
	surface.DrawRect(tooltipX, tooltipY, totalWidth, totalHeight)
	local outline = tooltipMood == "good" and Color(90, 220, 120, 255) or Color(255, 50, 50, 255)
	surface.SetDrawColor(outline.r, outline.g, outline.b, outline.a)
	surface.DrawOutlinedRect(tooltipX, tooltipY, totalWidth, totalHeight)
	local textX, textY = tooltipX + padding, tooltipY + padding
	draw.SimpleText(title, titleFont, textX, textY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	textY = textY + titleHeight + lineSpacing
	for index, line in ipairs(descriptionLines) do
		if rageActive then
			drawGlowingRageText(line, descriptionFont, textX, textY)
		else
			draw.SimpleText(line, descriptionFont, textX, textY, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
		textY = textY + descriptionHeights[index] + descriptionLineSpacing
	end
	textY = textY - descriptionLineSpacing
	if details then
		textY = textY + lineSpacing
		draw.SimpleText(details, "HG_MoodleText", textX, textY, outline, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end

local function drawMoodle3Severity(x, y, size, effect, age)
	local exempt = effect.name == "full" or effect.name == "happy"
	local severe = not exempt and effect.level >= 3
	local severity = not exempt and math.Clamp((effect.level - 1) / 3, 0, 1) or 0
	local fadeIn = math.Clamp((age or 0) * 0.8, 0, 1)
	local pulse = 0.85 + math.sin(CurTime() * 2.5) * 0.15
	local gradient = getMoodle3Material("SeverityGradient")
	if gradient and severity > 0 then
		surface.SetMaterial(gradient)
		surface.SetDrawColor(255, 45, 35, math.floor((25 + 155 * severity) * fadeIn * pulse))
		surface.DrawTexturedRect(x + 1, y + 1, size - 2, size - 2)
	end

	local border = Color(255, math.floor(255 - 205 * severity), math.floor(255 - 215 * severity), 255)
	surface.SetDrawColor(border.r, border.g, border.b, border.a)
	surface.DrawOutlinedRect(x, y, size, size, 2)
	if severe then
		local alert = getMoodle3Material("moodlealert")
		if alert then
			surface.SetMaterial(alert)
			surface.SetDrawColor(255, 255, 255, math.floor(220 * fadeIn * pulse))
			surface.DrawTexturedRect(x, y - size, size, size)
		end
	end
end

local function clearMoodleDrawState()
	moodlePositions = {}
	hover.index = nil
end

-- cl_berserk.lua derives this intensity from the music station time and its
-- configured BPM. Normalize it so the HUD follows that beat without keeping a
-- second clock that could drift away from the rest of the berserk effects.
local function getBerserkBeatPulse()
	if not hg then return 0 end

	local intensity = number(hg.berserkIntensity, 0)
	local maximum = number(hg.berserkClamped, 0) * 2
	if intensity ~= intensity or maximum ~= maximum or maximum <= 0.001 then return 0 end

	return math.Clamp((intensity / maximum - 0.15) / 0.85, 0, 1)
end

local function drawMoodles()
	if not enabled:GetBool() or (HUD and HUD.enabled == false) then
		clearMoodleDrawState()
		return
	end

	local ply = LocalPlayer()
	if not IsValid(ply) then
		clearMoodleDrawState()
		return
	end
	if not ply:Alive() then
		clearMoodleDrawState()
		local size = HUD and HUD.status_effects_size or 62
		local x, y = math.max(12, ScrH() * 0.015), ScrH() - math.max(12, ScrH() * 0.015) - size
		local deceased = {name = "deceased", level = 4, mood = "bad"}
		drawMoodle3Severity(x, y, size, deceased, 1)
		local icon = getMoodle3Material("deceased")
		if icon then
			surface.SetMaterial(icon)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(x + 2, y + 2, size - 4, size - 4)
		end
		return
	end

	local org = ply.new_organism or ply.organism
	if not istable(org) or org.alive == false then
		clearMoodleDrawState()
		return
	end

	local berserkActive = org.berserkActive2 == true
	local effects, now = buildEffects(ply, org), CurTime()
	-- Moodle 3 deliberately has no catch-all icon. Do not leave empty slots
	-- for conditions that do not have a meaningful Moodle 3 representation.
	local supported = {}
	for _, effect in ipairs(effects) do
		if effect.name == "rage" or getMoodle3Icon(effect) then supported[#supported + 1] = effect end
	end
	effects = mergeMoodle3Effects(supported)
	table.sort(effects, function(a, b)
		local aScore = (a.mood == "bad" and 100 or 0) + (a.level or 0) * 10
		local bScore = (b.mood == "bad" and 100 or 0) + (b.level or 0) * 10
		if aScore == bScore then
			if a.priority == b.priority then return a.name < b.name end
			return a.priority < b.priority
		end
		return aScore > bScore
	end)
	local active = {}
	for _, effect in ipairs(effects) do
		active[effect.name] = true
		if not appearances[effect.name] or lastLevels[effect.name] ~= effect.level then appearances[effect.name] = now end
		lastLevels[effect.name] = effect.level
	end
	for name in pairs(appearances) do
		if not active[name] then appearances[name], lastLevels[name] = nil, nil end
	end

	local baseSize = HUD and HUD.status_effects_size or 62
	local spacing = math.max(HUD and HUD.status_effects_spacing or 59, baseSize + 4)
	local gap = spacing - baseSize
	local edgeMargin = math.max(12, ScrH() * 0.015)
	local rowMargin = edgeMargin
	local rawPositions = {}
	local nextX = edgeMargin
	local rightEdge = ScrW() - edgeMargin
	for index, effect in ipairs(effects) do
		local effectSize = baseSize
		if nextX + effectSize > rightEdge and #rawPositions > 0 then
			nextX = edgeMargin
			rowMargin = rowMargin + effectSize + gap
		end
		rawPositions[#rawPositions + 1] = {
			x = nextX,
			y = ScrH() - rowMargin - effectSize,
			size = effectSize,
			effect = effect,
		}
		nextX = nextX + effectSize + gap
	end
	effects = {}
	for index, pos in ipairs(rawPositions) do effects[index] = pos.effect end

	local mx, my = gui.MousePos()
	local hoveredIndex = nil
	if mx and my and not (mx == 0 and my == 0) then
		for index, pos in ipairs(rawPositions) do
			if mx >= pos.x and mx <= pos.x + pos.size and my >= pos.y and my <= pos.y + pos.size then
				hoveredIndex = index
				break
			end
		end
	end
	hover.index = hoveredIndex
	hover.scale = Lerp(0.2, hover.scale, hoveredIndex and 1.35 or 1)

	local mouseOffsetX, mouseOffsetY = 0, 0
	if hoveredIndex then
		local hovered = rawPositions[hoveredIndex]
		mouseOffsetX = math.Clamp((mx - hovered.x - hovered.size * 0.5) * 0.15, -30, 30)
		mouseOffsetY = math.Clamp((my - hovered.y - hovered.size * 0.5) * 0.15, -30, 30)
	end

	local pain = orgNumber(org, "pain", 0)
	local painShakeX, painShakeY = 0, 0
	if pain > 20 then
		local intensity = math.min((pain - 20) / 80, 1) * 5
		painShakeX = math.sin(now * 120) * intensity * 0.8 + math.sin(now * 70) * intensity * 0.4
		painShakeY = math.cos(now * 2) * intensity * 0.8 + math.cos(now * 2.4) * intensity * 0.4
	end

	local berserkBeat = berserkActive and getBerserkBeatPulse() or 0
	local berserkKick = berserkBeat * berserkBeat

	moodlePositions = {}
	for index, pos in ipairs(rawPositions) do
		local effect = pos.effect
		local size = pos.size
		-- Rage is also a moodle: let it receive the berserk crack/distortion
		-- treatment so the effect remains visible even when it is the only one.
		local distortThis = berserkActive
		local scale, offsetX, offsetY = 1, 0, 0
		local repelX, repelY = 0, 0

		if hoveredIndex then
			local distanceIndex = index - hoveredIndex
			if distanceIndex == 0 then
				scale, offsetX, offsetY = hover.scale, mouseOffsetX, mouseOffsetY
			else
				local hovered = rawPositions[hoveredIndex]
				local dx, dy = pos.x - hovered.x, pos.y - hovered.y
				local distance = math.sqrt(dx * dx + dy * dy)
				if distance > 0 then
					local strength = (hover.scale - 1) * size * 0.8 / (1 + math.abs(distanceIndex) * 0.3)
					repelX, repelY = dx / distance * strength, dy / distance * strength * 0.5
				end
			end
		end

		local age = now - (appearances[effect.name] or now)
		local appearanceShake = 0
		if age < 1.5 then
			local easeOut = (1 - age / 1.5) ^ 3
			appearanceShake = math.sin(age * 18) * easeOut * 30
		end

		local beatShakeX, beatShakeY = 0, 0
		if distortThis then
			beatShakeX = math.sin(now * 75 + index * 2.3) * berserkKick * 6
			beatShakeY = -berserkKick * 5 + math.cos(now * 63 + index * 1.7) * berserkKick * 3
		end

		local finalX = pos.x + repelX + appearanceShake + painShakeX + beatShakeX
		local finalY = pos.y + repelY + painShakeY + beatShakeY
		finalX = math.Clamp(finalX, 10, ScrW() - size - 10)
		finalY = math.Clamp(finalY, 10, ScrH() - size - 10)
		local drawSize = size * scale * (1 + berserkKick * 0.1)
		local drawX = finalX - (drawSize - size) * 0.5
		local drawY = finalY - (drawSize - size) * 0.5
		drawMoodle3Severity(drawX, drawY, drawSize, effect, age)
		-- Berserk is Moodle 3's anger level 5: retain each moodle's frame and
		-- severity, but replace every active symbol except its own rage moodle
		-- with the break marker.
		local icon = effect.name == "zerlked" and getMoodle3Material("zerlked") or (berserkActive and effect.name ~= "rage" and getMoodle3Material("moodlebreak") or getMoodle3Icon(effect))
		if icon then
			surface.SetMaterial(icon)
			local iconSize = drawSize - 4
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(drawX + 2 + offsetX, drawY + 2 + offsetY, iconSize, iconSize)
		end

		moodlePositions[index] = {x = finalX, y = finalY, size = size, effect = effect}
	end

	if hoveredIndex then drawTooltip(effects[hoveredIndex], moodlePositions[hoveredIndex], mx, my, berserkActive) end
end

hook.Add("HUDPaint", "HG_NormalMoodles", drawMoodles)
