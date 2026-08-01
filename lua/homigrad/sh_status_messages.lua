
local allowedchars = {
	"ah",
	"AH",
	"ghh",
	"GH",
	"AHHH",
}

local audible_pain = {
	"AAAAAGH..FUCK.. IT HURTS.",
	"I CAN'T TAKE THIS ANYMORE!",
    "Make it STOP make it STOP MAKE IT STOP",
    "Why won't IT STOP",
    "Make me unconscious. PLEASE",
    "Why was I born to feel this why...",
    "I'd do anything for it to stop... ANYTHING.",
    "This isn't living this is being TORTURED",
    "I don't care anymore just STOP the PAIN",
    "Nothing matters EXCEPT MAKING IT STOP...",
    "Every second is an eternity of FIRE.",
    "DEATH WOULD BE MERCY NOW...",
    "Just one moment without the pain..",
	"I WISH I HAD SOME PAINKILLERS NOW. FUCK.",
}

local sharp_pain = {
	"AAAHH",
	"AAAH",
	"AAaaAH",
	"AAaaAH",
	"AAaaAAAGH",
	"AAaaAH",
	"AAaAaaH",
	"AAAAAaaH",
	"AAaaAHHHH",
	"AAaAA",
	"AAAAAa",
	"AAAAaAAAaaaaghh",
	"AAAaaAa",
	"AaaAAaghf",
	"aaAaaAaff",
	"aaahhh",
	"AAAaaGHHH",
	"AAAaaAAHH",
	"AAAaaAAAAAaGHHHH",
	"AAAaaAAAAAaGHAAAHHH",
	"AAAaaAAAAAaGHHAAAAAAHH",
	"AAAaaAAAAAaGHHHH",
	"AAAaaAAAaaAAAaGHHHH",
	"AAAaaAAAaaAAAaAAAAAAAGHHHH",
	"AAAaaAAAAAaGHHHH",
	"AAAaaAAAAAAAAAHHH",
	"AAAaaAAAAAaGHAaaaHH",
	"AAAaaAAAAAaAaaaaaAAAAHH",
	"AAAaaAAAAAaAAAAAAAADGHHHH",
	"AAAaaAAAaaAAAaAAAAAAAAAAAAGGGGGGAGHHHH",
	"AAAaaAAAaaAAAaAAAAAAAAAAAAAAAAAAH",
}

hg.sharp_pain = sharp_pain

local random_phrase = {
		"Nothing ever happens.",
	"Damn, I forgot to pay my child support.",
	"I wonder when rent is due.",
	"Isn't there like a homicide happening?",
	"This is why I never leave the house.",
	"It's kinda chilly in here...",
	"Everything seems too quiet...",
	"Breathing feels oddly satisfying right now.",
	"What if this quiet lasts forever?",
	"Why isn't anything happening?",
	"I can hear my own heartbeat...",
	"The silence is almost deafening.",
	"Time feels... different somehow.",
	"Is anyone even out there?",
	"How long have I been standing here?",
	"The air tastes stale.",
	"I don't remember how I got here.",
	"Nothing ever changes, does it?",
	"Am I awake right now?",
	"The shadows seem deeper than usual.",
	"My thoughts are so loud in this silence.",
	"When did it get so dark?",
	"I feel like I'm being watched.",
	"Everything's exactly where it was before.",
	"Does anyone know I'm here?",
	"The walls feel closer somehow.",
	"What was I thinking about?",
	"Time moves so strangely here.",
	"I can't remember the last time anything changed.",
	"The quiet is starting to feel alive.",
}


local fear_hurt_ironic = {
	"My friends will NEVER believe this story.",
	"This isnt a bad place to die.",
	"How did I get to this point?",
	"At least my life wasn't boring.",
	"I guess this is what happens when you dont pay your bills.",
	"This isn't the worst day to die.",
	"This is fine. Everything's fine.",
	"At least I'll die knowing I was right.",
	"Guess I'm getting what I deserved.",
	"Well, I asked for an adventure.",
	"They'll probably laugh at this funeral.",
	"At least it'll make a good story... if anyone lives to hear it.",
	"I've survived worse... probably.",
}

local fear_phrases = {
	"I dont want to die today.",
	"I don't want to die like this.",
	"Is this really how it ends?",
	"Im scared of death.",
	"There's no way out, is there?",
	"I dont want to die.",
	"I wish I had a way out.",
	"I regret so many things.",
	"This can't be it.",
	"I can't believe this is happening to me.",
	"I dont want to die anymore.",
	"What if I don't make it..?",
	"This is worse than I thought.",
	"I dont want it to end like this.",
	"I can't give up yet.",
	"I never thought it would be like this.",
	"Why is this happening to me...",
	"I think im going to die here.",
	"I cant see the end.",
	"This is it.",
	"Calm breaths. Deep breaths...",
	"I should have stayed home today.",
	"I should have stayed in bed.",
	"I should have never come to this place.",
	"Why did I come here?",
	"I dont want my last thought to be fear.",
	"I regret so much.",
	"There's so much I haven't done.",
	"I wish I had more time.",

}

local situation_fear_phrases = {
	"Im not safe here.",
	"Im scared...",
	"I'm in danger.",
	"Things are going wrong.",
	"I need to get out of here.",
	"This isn't going to end well.",
	"I dont know what to do.",
	"I need to go somewhere else.",
	"My life is in danger.",
}

local panicattack_phrases = {
	"I CAN'T... I CAN BARELY BREATHE!",
	"My chest is... convulsing...?",
	"I'm gonna make it... I am gonna make it..",
	"What the fuck..?",
	"Shit.. What is happening?",
	"Something is very wrong with me.",
	"Relax..!",
	"I need a second.. Just one second.",
	"I cant form a single thought in my head!",
	"I can't think straight..!",
	"My hands won't stop shaking.",
	"I need space..",
	"I am losing control of myself..",
	"Focus now.",
	"Not now.. Not now..",
	"I can't settle down!",
	"This is way too much..!",
    "I don't want to die.",
}

local is_aimed_at_phrases = {
    "Oh God. This is it.",
    "Don't. move.",
    "Is this really how I die?",
    "I should've run. Why didn't I run?",
    "Please don't pull the trigger. Please.",
    "I can see their finger on the trigger.",
    "I don't want to die. Not like this.",
    "If I beg, will it make it worse?",
    "This can't be real. This can't be real.",
    "Someone help me. Please. Someone.",
    "I don't want to die in a place like this.",
    "I don't want my last thought to be fear.",
    "I don't want to die.",
}

local near_death_poetic = {
	"I CANT STOP DYING. WHY CANT I STOP DYING, I DONT WANT TO GO YET, THIS ISNT HOW ITS SUPPOSED TO END",
	"I cant go, I cant go yet. This isnt how its supposed to end I dont want to die I dont want to die...",
	"Its hopeless, ill just die here like a dog without anyone willing to help a dying, helpless man.",
	"Why is it me, out of all the people today why did it have to be me...",
	"Everything is so dark and weak and heavy and I cant move and I cant breathe and I cant see and I cant think and I dont want to die...",
	"Someone help me, please, I dont want to die like this, I dont want to die like this, I dont want to die like this...",
	"What happens after death? Is this it? will I be accepted into heaven or hell? I never had time to think I dont want to die a sinner..",
	"This is it isnt it? No one will fucking help me, no one will save me, no one will even notice me, I am going to die here and no one will care.",
	"This is fucking hopeless, I cant move, I cant see, I cant do ANYTHING, IM GOING TO FUCKING DIE",
	"I have so much regrets, so much I didnt do, so much I didnt say and experience, this is how I fucking die and its a pathetic way to die.",
	"Why is it so dark and heavy and cold and I cant move and I cant breathe and I cant see and I cant think and I dont want to die...",
}

local near_death_positive = {
	"I don't want to die.",
	"I have to survive.",
	"There's still a chance.",
	"I can't let fear win.",
	"Just one more try.",
	"I refuse to die here.",
	"Alright... think this through.",
	"Just stay still. Moving makes it worse.",
	"Breathe slow. Panic won't help.",
	"It's not over until it's over.",
	"Pain is just a signal. Ignore it.",
	"If this is it... at least it's gonna be quick.",
	"I've survived worse. Probably.",
	"I dont want to die.",
	"There is still a way out of this.",
	"This cant be how it ends.",
	"I'm not sure if this is the end.",
	"This isn't how I pictured it.",
}

local broken_limb = {
	"FUCK. FUCK. ITS DEFINITELY BROKEN!",
	"I CAN FEEL THE BONE PIECES MOVING!",
	"IT'S FUCKING BROKEN. I THINK..",
	"It hurts just thinking about it. Definitely broken.",
	"I don't think it should bend here.",
	"Oh fuck. It is snapped.",
	"I don't see any open fracture, but I feel like I broke something",
}

local dislocated_limb = {
	"My limb is at a really weird angle...",
	"I have to get this bone back in.",
	"No... I have to move it back in place.",
	"It just hurts so much there. I might need a check up.",
	"My limb is out of place.",
}

local hungry_a_bit = {
    "Mgh, I'm hungry...",
    "Some food would be great...",
    "I'm hungry...",
    "I should eat something.",
}

local very_hungry = {
    "My stomach... Ugh...",
    "If I don't eat, I'll feel even worse...",
    "Stomach... Damn it... I feel sick",
}

local after_unconscious = {
    "What happened? It hurts...",
	"Where am I? Why does it hurt...",
	"I-I thought I was going to die...",
	"My head... What happened?",
	"Did I almost die a second ago?",
	"It felt like I died.",
	"The heavens didn't take me?",
	"Ohh-fuck... my head is aching...",
	"Oh it's gonna be hard to get up right now... but I have to...",
	"I don't recognize this place at all... or do I?",
	"I don't want to experience this EVER AGAIN!",
}

local thirsty_a_bit = {
    "I'm thirsty...",
    "Some water would be great...",
    "I should drink something.",
}

local very_thirsty = {
    "My throat is so dry...",
    "If I don't drink, I'll feel even worse...",
    "Water... Damn it... I feel sick",
}

local good_mood_phrases = {
    "I feel great!",
    "Life is good.",
    "I can take on the world!",
    "Everything is going my way.",
    "I'm on top of the world!",
}

local slight_braindamage_phraselist = {
	"I don't understand...",
	"It doesn't make sense...",
	"Where am I?",
	"Huh? What is this..?",
	"I don't know what is happening...",
	"Hello?",
	"Ughhh ohhhh...      huh...",
	"What... is happening?",
}

local braindamage_phraselist = {
	"Bbbee.. wheea mgh?!",
	"Bmmeee... mehk...",
	"Mm--hhhh. Mmm?",
	"Ghmgh whhh...",
	"Ahgg...mg?",
	"Hgghh... D-Dmmh.",
	"Lmmmphf, mp-hf!",
	"Heeelllhhpphp...",
	"Nghh... Gmh?",
	"Ggg... Bgh..",
	"Bhrhraihin.",
}

local internalbleed_phrases = {
	"That's... that's blood I just vomited...",
	"Oh, that's blood...",
	"Fuck, I just puked blood...",
	"Oh shit... I don't feel good...",
}
hg.internalbleed_phrases = internalbleed_phrases

local adrenaline_phrases = {
    "Im so incredibly anxious.",
    "Focus... just focus...",
    "My hands are so shaky.",
    "I can't calm down.",
    "I feel at edge.",
    "I need to chill out, literally...",
}

local cold_phraselist = {
	"It's getting very cold..",
	"Too cold for me.",
	"I'm shivering, fucking hell, man.",
	"Extremely chilly out here..",
	"Need something to heat up...",
	"I feel pretty cold...",
	"I feel sick from that cold, fuck."
}

local freezing_phraselist = {
	"I.. ca.. can't feel m-my b-body..",
	"I can't.. f-feel my legs...",
	"I'm f-fuck-king fre-ezing..",
	"I-I think-k my face is num-mb..",
	"Cold-d..",
	"I.. can't feel any-ythi-ing..",
}

local numb_phraselist = {
	"It's not.. cold anymore..",
	"Why... does it feel warm..?",
	"I think I'm okay... I think...",
	"Finally some warmth...",
	"I'm warm again... Somehow...",
	"I was just freezing... Where did this heat come from..?",
}

local hot_phraselist = {
	"I'm so sweaty..",
	"This heat is killing me..",
	"My clothing is covered in sweat, fuck.",
	"My sweat fucking reeks. I should really cool down...",
	"It's a bit too hot, fuck, man.",
	"I'm heating up real bad...",
	"Why is it so hot in here?",
}

local heatstroke_phraselist = {
	"I NEED WATER!!",
	"Please... water...",
	"I feel dizzy... Fuuck-",
	"MY HEAD!- It hurts..",
	"My head is aching..",
}

local heatvomit_phraselist = {
	"That heat..- I'm gonna vomit-",
	"Ugghhh... I'm about to puke-",
	"Fuuck.. Oughhh.. I don't feel-"
}

local internal_bleeding_phrases = {
	"Something is bleeding inside me...",
	"I can feel blood building up inside...",
	"Something inside me is badly wrong...",
}

local arrhythmia_phrases = {
	"My heartbeat feels wrong...",
	"My heart is skipping and stumbling...",
	"My chest feels out of rhythm...",
}

local tachycardia_phrases = {
	"My heart is racing...",
	"My heart is beating far too fast...",
	"I can feel my pulse pounding...",
}

local bradycardia_phrases = {
	"My heartbeat is slowing down...",
	"My heart is beating so slowly...",
	"My heart is barely keeping up...",
}

local low_perfusion_phrases = {
	"My limbs feel weak and cold...",
	"I can barely move...",
	"Everything feels heavy and sluggish...",
}

local hg_showthoughts = ConVarExists("hg_showthoughts") and GetConVar("hg_showthoughts") or CreateClientConVar("hg_showthoughts", "1", true, true, "Show the thoughts of your character", 0, 1)

function string.Random(length)
	local length = tonumber(length)

    if length < 1 then return end

    local result = {}

    for i = 1, length do
        result[i] = allowedchars[math.random(#allowedchars)]
    end

    return table.concat(result)
end

function hg.nothing_happening(ply)
	if not IsValid(ply) then return end

	return ply.organism and ply.organism.fear < -0.6
end

function hg.fearful(ply)
	if not IsValid(ply) then return end

	local org = ply.organism
	return org and (org.fear or 0) > 0.5 and (org.adrenaline or 0) > 0.5
end

function hg.situation_fear(ply)
	if not IsValid(ply) then return end

	local org = ply.organism
	return org and (org.fear or 0) > 0.75 and (org.adrenaline or 0) > 0.5
end

function hg.likely_to_phrase(ply)
	local org = ply.organism

	local pain = org.pain
	local brain = org.brain
	local blood = org.blood
	local fear = org.fear
	local panicattack = org.panicattack or 0
	local internalBleed = org.internalBleed or 0
	local arrhythmia = org.arrhythmia or 0
	local hypotension = org.hypotension or 0
	local temperature = org.temperature
	local broken_dislocated = org.just_damaged_bone and ((org.just_damaged_bone - CurTime()) < -3)
	local adrenaline = org.adrenaline or 0

	local fearBoost = (fear > 0.75 and adrenaline > 0.5) and 2.0 or 0

	return (broken_dislocated) and 5
		or (pain > 65) and 5
		or (panicattack > 0.55 and 1.2)
		or (temperature < 35 and (temperature < 31 and 1.25 or 0.65))
		or (temperature > 38 and (temperature >= 40 and 1.25 or 0.65))
		or (blood < 3000 and 0.3)
		or (fearBoost > 0 and fearBoost)
		or (brain > 0.1 and brain * 5)
		or (fear < -0.5 and 0.05)
		or -0.1
end

function IsAimedAt(ply)
    return ply.aimed_at or 0
end

local function get_status_message(ply)
	if not IsValid(ply) then
		if CLIENT then
			ply = lply
		else
			return
		end
	end

	local nomessage = hook.Run("HG_CanThoughts", ply) --ply.PlayerClassName == "Gordon" || ply.PlayerClassName == "Combine"
	if nomessage ~= nil and nomessage == false then return "" end

    if ply:GetInfoNum("hg_showthoughts", 1) == 0 then return "" end

	local org = ply.organism
	
	if not org or not org.brain then return "" end

	local pain = org.pain
	local brain = org.brain
	local temperature = org.temperature
	local blood = org.blood or 5000
	local hungry = org.hungry
	local thirst = org.thirst
	local goodmood = org.goodmood
	local panicattack = org.panicattack or 0
	local broken_dislocated = org.just_damaged_bone and ((org.just_damaged_bone + 3 - CurTime()) < -3)
	local o2 = org.o2 and org.o2[1] or 30
	local fear = org.fear or 0
	local adrenaline = org.adrenaline or 0
	local internalBleed = org.internalBleed or 0
	local arrhythmia = org.arrhythmia or 0
	local hypotension = org.hypotension or 0
	local positive_thinking = goodmood and goodmood > 0.5

	if fear >= 1.0 and math.random(10) > 3 then
		positive_thinking = false
	elseif adrenaline > 1.3 and fear < 0.5 then
		positive_thinking = true
	end

	if broken_dislocated and org.just_damaged_bone then
        org.just_damaged_bone = nil
    end
	
	local broken_notify = (org.rarm == 1) or (org.larm == 1) or (org.rleg == 1) or (org.lleg == 1)
	local dislocated_notify = (org.rarm == 0.5) or (org.larm == 0.5) or (org.rleg == 0.5) or (org.lleg == 0.5)
	local after_unconscious_notify = org.after_otrub
	local heartbeat = org.heartbeat or 70

	if not isnumber(pain) then return "" end

	local str = ""

	local most_wanted_phraselist

	if org.heartstop then
		most_wanted_phraselist = bradycardia_phrases
	elseif o2 < 12 then
		-- sv_lungs owns the immediate breathing symptom alerts. Keep periodic
		-- low-O2 thoughts in the shared dying-status pool so they do not repeat
		-- those callouts.
		most_wanted_phraselist = near_death_poetic
	elseif blood < 3750 then
		-- sv_blood owns the immediate faintness and hemorrhage alerts. Blood loss
		-- still gets priority for recurring status thoughts, but shares the same
		-- dying pool as the other terminal conditions.
		most_wanted_phraselist = near_death_poetic
	elseif pain > 100 then
		most_wanted_phraselist = sharp_pain
	elseif pain > 75 then
		most_wanted_phraselist = audible_pain
	elseif internalBleed > 0.1 then
		most_wanted_phraselist = internal_bleeding_phrases
	elseif org.fibrillation or org.unstableRhythm or arrhythmia > 0.35 then
		most_wanted_phraselist = arrhythmia_phrases
	elseif heartbeat >= 150 then
		most_wanted_phraselist = tachycardia_phrases
	elseif heartbeat > 0 and heartbeat <= 45 then
		most_wanted_phraselist = bradycardia_phrases
	elseif hypotension > 0.5 then
		most_wanted_phraselist = low_perfusion_phrases
	elseif temperature < 35 then
		if temperature < 29 then
			most_wanted_phraselist = numb_phraselist
		elseif temperature < 31 then
			most_wanted_phraselist = freezing_phraselist
		else
			most_wanted_phraselist = cold_phraselist
		end
	elseif temperature > 38 then
		most_wanted_phraselist = temperature >= 40 and heatstroke_phraselist or hot_phraselist
	elseif ((blood < 3250 and heartbeat >= 30 and heartbeat <= 250) or (broken_dislocated) or (broken_notify) or (dislocated_notify)) then
		if pain > 75 and (broken_dislocated) then
			most_wanted_phraselist = math.random(2) == 1 and audible_pain or (broken_notify and broken_limb or dislocated_limb)
		elseif pain > 75 then
			most_wanted_phraselist = audible_pain
		elseif broken_dislocated then
			most_wanted_phraselist = (broken_notify and broken_limb or dislocated_limb)
		end

		if not most_wanted_phraselist then
			if (broken_dislocated_notify) and (blood < 3100) then
				most_wanted_phraselist = blood < 2900 and (near_death_poetic) or (math.random(2) == 1 and (broken_notify and broken_limb or dislocated_limb) or near_death_poetic)
			--elseif(broken_dislocated_notify)then
				--most_wanted_phraselist = (broken_notify and broken_limb or dislocated_limb)
			elseif(blood < 3100)then
				most_wanted_phraselist = positive_thinking and near_death_positive or near_death_poetic
			end
		end
	elseif after_unconscious_notify then
		most_wanted_phraselist = after_unconscious
	elseif not most_wanted_phraselist and adrenaline > 1.5 then
		most_wanted_phraselist = adrenaline_phrases
	elseif panicattack > 0.55 then
		most_wanted_phraselist = panicattack_phrases
	elseif hg.nothing_happening(ply) then
		most_wanted_phraselist = random_phrase

		if goodmood and goodmood > 0.8 and math.random(5) == 1 then
			most_wanted_phraselist = good_mood_phrases
		end
	elseif not most_wanted_phraselist and hg.situation_fear(ply) then
		most_wanted_phraselist = situation_fear_phrases
	elseif not most_wanted_phraselist and hg.fearful(ply) then
		if positive_thinking and math.random(3) == 1 then
			most_wanted_phraselist = near_death_positive
		else
			most_wanted_phraselist = ((IsAimedAt(ply) > 0.9) and is_aimed_at_phrases or (math.random(10) == 1 and fear_hurt_ironic or fear_phrases))
		end
	end
	
	if most_wanted_phraselist then
		str = most_wanted_phraselist[math.random(#most_wanted_phraselist)]

		return str
	else
		return ""
	end
end

local allowedlist_types = {
	heatvomit = heatvomit_phraselist,
	hg_situationfear = situation_fear_phrases,
}

function hg.get_phraselist(ply, type)
	if not IsValid(ply) then
		if CLIENT then
			ply = lply
		else
			return
		end
	end
	
	local nomessage = ply.PlayerClassName == "Gordon" || ply.PlayerClassName == "Combine"

	if nomessage then return "" end
    if ply:GetInfoNum("hg_showthoughts", 1) == 0 then return "" end

	local org = ply.organism	
	if not org or not org.brain then return "" end

	if not isstring(type) or not allowedlist_types[type] then return "" end

	local needed_list = allowedlist_types[type]

	local str = needed_list[math.random(#needed_list)]
	return str
end

function hg.get_notify_color(ply)
	if not IsValid(ply) then return Color(255, 255, 255) end
	local org = ply.organism
	if not org then return Color(255, 255, 255) end

	local pain = org.pain or 0
	local shock = org.shock or 0
	local adrenaline = org.adrenaline or 0
	local fear = org.fear or 0
	local analgesia = org.analgesia or 0
	local consciousness = org.consciousness or 1
	local o2 = (org.o2 and org.o2[1]) or 30
	local pulse = org.pulse or 70
	local blood = org.blood or 5000
	local hurt = org.hurt or 0
	local lasthit = org.lasthit or 0
	local recentDamage = lasthit > 0 and (CurTime() - lasthit) < 3

	local dyingBlood = blood < 3750
	local dyingO2 = o2 < 12
	local dyingPulse = pulse < 40 and pulse > 0
	local dying = dyingO2 or dyingPulse or (blood < 2500) or dyingBlood
	local inPain = pain > 30
	local inShock = shock > 20
	local inAdrenalineOrFear = (adrenaline > 0.5) or (fear > 0.5)
	local highAnalgesia = analgesia > 1.0
	local lowConsciousness = consciousness < 0.6

	if highAnalgesia then
		return Color(255, 100, 255)
	end

	if dying then
		local tO2 = dyingO2 and math.Clamp(1 - (o2 / 12), 0, 1) or 0
		local tBlood = dyingBlood and math.Clamp(1 - (blood / 3750), 0, 1) or 0
		local t = math.max(tO2, tBlood)
		local gray = math.floor(220 - t * 70)
		return Color(
			math.min(gray + 25, 255),
			math.max(gray - 12, 0),
			math.max(gray - 12, 0)
		)
	end

	if inPain or recentDamage then
		local t = math.Clamp(pain / 100, 0, 1)
		return Color(255, math.floor(255 * (1 - t * 0.85)), math.floor(255 * (1 - t * 0.85)))
	end

	if inShock then
		local t = math.Clamp(shock / 80, 0, 1)
		return Color(255, math.floor(255 * (1 - t * 0.5)), math.floor(255 * (1 - t * 0.5)))
	end

	if lowConsciousness then
		local t = math.Clamp(1 - consciousness / 0.6, 0, 1)
		local gray = math.floor(255 * (1 - t * 0.55))
		return Color(gray, gray, gray)
	end

	if inAdrenalineOrFear then
		return Color(255, 230, 180)
	end

	return Color(255, 255, 255)
end

function hg.get_status_message(ply)
	local txt = get_status_message(ply)

	return txt
end
