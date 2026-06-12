
local allowedchars = {
	"ah",
	"AH",
	"ghh",
	"GH",
	"AHHH",
}

local audible_pain = {
	"You are experiencing excruciating pain.",
	"You are in severe pain."
}

local despair_phrases = {
    "What's the point anymore?",
    "Everything feels so heavy.",
    "I'm so tired of fighting.",
    "Is this all there is?",
    "I just want it to be over.",
    "I feel so empty.",
    "Nothing makes sense.",
    "I'm lost.",
    "I can't see a way out.",
    "This is hopeless."
}

local sharp_pain = {
	"You are in agony."
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
	"You are losing blood.",
	"Your condition is critical.",
	"You are close to blacking out.",
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

local function get_broken_limb_message(org)
	if org.rarm == 1 then return "Your right arm is broken." end
	if org.larm == 1 then return "Your left arm is broken." end
	if org.rleg == 1 then return "Your right leg is broken." end
	if org.lleg == 1 then return "Your left leg is broken." end
end

local function get_dislocated_limb_message(org)
	if org.rarmdislocation or org.rarm == 0.5 then return "Your right arm is dislocated." end
	if org.larmdislocation or org.larm == 0.5 then return "Your left arm is dislocated." end
	if org.rlegdislocation or org.rleg == 0.5 then return "Your right leg is dislocated." end
	if org.llegdislocation or org.lleg == 0.5 then return "Your left leg is dislocated." end
end

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
    "You are awake.",
	"You regain consciousness.",
	"You wake up.",
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
	"Reality becomes a myth.",
	"You suffer a traumatic brain injury.",
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

local bleeding_out_phrases = {
    "Why did this happen to me why...",
    "I feel so weak...",
    "So dark.. everything is so dark and cold...",
    "I feel like i want to pass out, but i dont want to...",
    "Its so hard to move...",
    "Im so numb... but i can still feel the cold...",
    "Im going to die arent i?",
}

local low_o2_phrases = {
	"I can't get enough air.",
	"My chest is fighting for every breath.",
	"Everything is getting dark.",
	"I need air right now.",
	"My lungs aren't keeping up.",
	"I can't breathe right.",
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

local cooked_phrases = {
    "its so over 😭",
    "son im cooked 😭🙏",
    "nga im so fried 🥹",
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
	local despair = org.despair
	local temperature = org.temperature
	local broken_dislocated = org.just_damaged_bone and ((org.just_damaged_bone - CurTime()) < -3)
	local adrenaline = org.adrenaline or 0

	local fearBoost = (fear > 0.75 and adrenaline > 0.5) and 2.0 or 0

	return (broken_dislocated) and 5
		or (pain > 65) and 5
		or (despair > 0.5) and 5
		or (temperature < 31 and 0.5)
		or (temperature > 38 and 0.5)
		or (blood < 3000 and 0.3)
		or (fearBoost > 0 and fearBoost)
		or (brain > 0.1 and brain * 5)
		or (fear < -0.5 and 0.05)
		or -0.1
end

function IsAimedAt(ply)
    return ply.aimed_at or 0
end

local function pick_message(org, list, key)
	if not istable(list) or #list == 0 then return "" end

	local index = math.random(#list)
	local last = org[key]

	if #list > 1 and list[index] == last then
		index = index % #list + 1
	end

	local msg = list[index]
	org[key] = msg

	return msg
end

local function reset_pain_message_state(org)
	org.pain_message_state = nil
	org.pain_message_locked = nil
end

local function get_pain_message_pool()
	local pool = {}

	for _, msg in ipairs(audible_pain) do
		pool[#pool + 1] = msg
	end

	for _, msg in ipairs(sharp_pain) do
		local exists = false

		for _, old in ipairs(pool) do
			if old == msg then
				exists = true
				break
			end
		end

		if not exists then
			pool[#pool + 1] = msg
		end
	end

	return pool
end

local function pick_pain_message(org)
	local list = get_pain_message_pool()
	if #list == 0 then return "" end

	if org.pain_message_locked then return "" end

	local state = org.pain_message_state

	if not istable(state) or state.count != #list then
		state = {
			index = 1,
			repeats = 0,
			count = #list,
			exhausted = false
		}

		org.pain_message_state = state
	end

	if state.exhausted then
		org.pain_message_locked = true
		return ""
	end

	local msg = list[state.index]

	state.repeats = state.repeats + 1

	if state.repeats >= 2 then
		state.repeats = 0
		state.index = state.index + 1

		if state.index > #list then
			state.exhausted = true
			org.pain_message_locked = true
		end
	end

	return msg
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
	local broken_dislocated = org.just_damaged_bone and ((org.just_damaged_bone + 3 - CurTime()) < -3)
	local o2 = org.o2 and org.o2[1] or 30
	local fear = org.fear or 0
	local adrenaline = org.adrenaline or 0
	local positive_thinking = (goodmood and goodmood > 0.5) or (org.despair and org.despair < 0.1)

	if fear >= 1.0 and math.random(10) > 3 then
		positive_thinking = false
	elseif adrenaline > 1.3 and fear < 0.5 then
		positive_thinking = true
	end

	if pain < 30 then
		reset_pain_message_state(org)
	end

	if broken_dislocated and org.just_damaged_bone then
        org.just_damaged_bone = nil
    end
	
	local broken_limb_message = get_broken_limb_message(org)
	local dislocated_limb_message = get_dislocated_limb_message(org)
	local broken_notify = broken_limb_message != nil
	local dislocated_notify = dislocated_limb_message != nil
	local after_unconscious_notify = org.after_otrub
	local heartbeat = org.heartbeat or 70

	if not isnumber(pain) then return "" end

	local str = ""

	local most_wanted_phraselist

	if o2 < 12 then
		most_wanted_phraselist = low_o2_phrases
	elseif pain > 100 then
		most_wanted_phraselist = sharp_pain
	elseif pain > 75 then
		most_wanted_phraselist = audible_pain
	elseif ((blood < 3250 and heartbeat >= 30 and heartbeat <= 250) or (broken_dislocated) or (broken_notify) or (dislocated_notify)) then
		if pain > 75 and (broken_dislocated) then
			most_wanted_phraselist = math.random(2) == 1 and audible_pain or {broken_notify and broken_limb_message or dislocated_limb_message}
		elseif pain > 75 then
			most_wanted_phraselist = audible_pain
		elseif broken_dislocated then
			most_wanted_phraselist = {broken_notify and broken_limb_message or dislocated_limb_message}
		end

		if not most_wanted_phraselist then
			if (broken_notify or dislocated_notify) and (blood < 3100) then
				most_wanted_phraselist = blood < 2900 and (near_death_poetic) or (math.random(2) == 1 and {broken_notify and broken_limb_message or dislocated_limb_message} or near_death_poetic)
			--elseif(broken_dislocated_notify)then
				--most_wanted_phraselist = (broken_notify and broken_limb or dislocated_limb)
			elseif(blood < 3100)then
				most_wanted_phraselist = positive_thinking and near_death_positive or near_death_poetic
			end
		end
	elseif after_unconscious_notify then
		most_wanted_phraselist = after_unconscious
	elseif not most_wanted_phraselist and org.despair and org.despair > 0.5 and math.random(2) == 1 then
		most_wanted_phraselist = despair_phrases
	elseif not most_wanted_phraselist and blood < 3750 then
		local combined_phrases = {}
		for _, phrase in ipairs(bleeding_out_phrases) do table.insert(combined_phrases, phrase) end
		for _, phrase in ipairs(near_death_poetic) do table.insert(combined_phrases, phrase) end
		if hg.internalbleed_phrases then
			for _, phrase in ipairs(hg.internalbleed_phrases) do table.insert(combined_phrases, phrase) end
		end
		most_wanted_phraselist = combined_phrases
	elseif not most_wanted_phraselist and adrenaline > 1.5 then
		most_wanted_phraselist = adrenaline_phrases
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
		if most_wanted_phraselist == sharp_pain then
			str = pick_pain_message(org)
		elseif most_wanted_phraselist == audible_pain then
			str = pick_pain_message(org)
		else
			str = pick_message(org, most_wanted_phraselist, "last_status_message")
		end

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

	local str = pick_message(org, needed_list, "last_typed_phraselist")
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
		return Color(
			math.floor(255 * (1 - t * 0.5)),
			math.floor(255 * (1 - t * 0.3)),
			255
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

function hg.get_status_message_notify_key(ply)
	if not IsValid(ply) or not ply.organism then return "phrase" end

	local org = ply.organism

	if org.brain > 0.1 then return "phrase_brain" end
	if org.pain > 75 then return "phrase_pain" end

	return "phrase"
end

function hg.get_status_message_notify_delay(ply)
	if not IsValid(ply) or not ply.organism then return 1 end

	local org = ply.organism

	if org.brain > 0.1 then return 2.5 end
	if org.pain > 75 then return 4 end

	return 1
end
