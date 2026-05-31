
local allowedchars = {
	"ah",
	"AH",
	"ghh",
	"GH",
	"AHHH",
}

local audible_pain = {
	"WHY... WHY DOES IT HURT THIS MUCH",
	"JESUS CHRIST I CAN FEEL THE PAIN- AAAAGHHH",
    "Make it STOP make it STOP MAKE IT STOP",
    "PLEASE JUST MAKE ME UNCONSCIOUS ALREADY",
    "EVERYTHING IN MY BODY HURTS SO MUCH...",
    "Why was I born to feel this why...",
    "IT HURTS- IT HURTS SO MUCH",
    "IM BURNING- IM BURNING ALIVE",
    "MOMMY- I WANT MY MOMMY",
    "Nothing matters EXCEPT MAKING IT STOP...",
    "THIS FEELS LIKE THE DEEPEST PIT OF HELL",
    "DEATH WOULD BE MERCY NOW...",
    "Just one moment without the pain..",
	"I WISH I HAD SOME PAINKILLERS NOW. FUCK.",
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
}

local fear_hurt_ironic = {
	"My friends will NEVER believe this story.",
	"This isnt a bad place to die.",
	"How did I get to this point?",
	"At least my life wasn't boring.",
	"I guess this is what happens when you dont pay your bills.",
	"This isn't the worst day to die.",
	"This is actually pretty funny.",
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
	"Calm breaths. Deep breaths...",

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
	"Trying to stand... but I just can't...",
	"Breathing's just shallow sips of nothing...",
	"Can't tell if my eyes are open or not anymore...",
	"Last thing I'll taste is my own blood and copper.",
	"Eyes keep sliding off things.",
	"Can't remember how standing works.",
	"Everything echoes inside my skull.",
	"Blinking takes too long to come back.",
	"Fingers won't close around anything.",
	"Lungs refuse to be full.",
	"Regrets are pointless now.",
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
	"God damn it, I think I broke something.",
	"I can feel the pieces moving, I think I broke it.",
	"I heard something break.",
	"Jesus christ, I think I actually broke something...",
	"The angle of my limb is so off, I think its broken.",
	"Oh fuck. It is snapped.",
	"Fuck me, I think I broke something.",
}

local dislocated_limb = {
	"I think my bone is out of place.",
	"I have to get this bone back in.",
	"I heard the bone pop like a gunshot...",
	"Its out of the socket, I can see the bulge...",
	"Dont look, dont- oh god... its out of place.",
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

local bleeding_out_phrases = {
    "Why did this happen to me why...",
    "I feel so weak...",
    "So dark.. everything is so dark and cold...",
    "I feel like i want to pass out, but i dont want to...",
    "Its so hard to move...",
    "Im so numb... but i can still feel the cold...",
    "Im going to die arent i?",
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
    "I cant calm down.",
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

	return ply.organism and ply.organism.fear > 0.5
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

	return (broken_dislocated) and 5
		or (pain > 65) and 5
		or (despair > 0.5) and 5
		or (temperature < 31 and 0.5)
		or (temperature > 38 and 0.5)
		or (blood < 3000 and 0.3)
		--or (fear > 0.5 and 0.7)
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
	local blood = org.blood
	local hungry = org.hungry
	local thirst = org.thirst
	local goodmood = org.goodmood
	local broken_dislocated = org.just_damaged_bone and ((org.just_damaged_bone + 3 - CurTime()) < -3)
    local positive_thinking = (goodmood and goodmood > 0.5) or (org.despair and org.despair < 0.1)

    if org.fear and org.fear >= 1.0 then
        if math.random(10) > 3 then
            positive_thinking = false
        end
    end

	if broken_dislocated and org.just_damaged_bone then
        org.just_damaged_bone = nil
    end
	
	local broken_notify = (org.rarm == 1) or (org.larm == 1) or (org.rleg == 1) or (org.lleg == 1)
	local dislocated_notify = (org.rarm == 0.5) or (org.larm == 0.5) or (org.rleg == 0.5) or (org.lleg == 0.5)
	local after_unconscious_notify = org.after_otrub

	if not isnumber(pain) then return "" end

	local str = ""

	local most_wanted_phraselist

	if not most_wanted_phraselist and org.despair and org.despair > 0.5 and math.random(2) == 1 then
		most_wanted_phraselist = despair_phrases
	end

	if not most_wanted_phraselist and blood < 3750 then
		local combined_phrases = {}
		for _, phrase in ipairs(bleeding_out_phrases) do table.insert(combined_phrases, phrase) end
		for _, phrase in ipairs(near_death_poetic) do table.insert(combined_phrases, phrase) end
		for _, phrase in ipairs(fear_phrases) do table.insert(combined_phrases, phrase) end
		if hg.internalbleed_phrases then
			for _, phrase in ipairs(hg.internalbleed_phrases) do table.insert(combined_phrases, phrase) end
		end
		most_wanted_phraselist = combined_phrases
	end

	local adrenaline = org.adrenaline or 0
	if not most_wanted_phraselist and adrenaline > 1.5 then
		most_wanted_phraselist = adrenaline_phrases
	end

	if (blood < 3100) or (pain > 75) or (broken_dislocated) or (broken_notify) or (dislocated_notify) then
		if pain > 75 and (broken_dislocated) then
			most_wanted_phraselist = math.random(2) == 1 and audible_pain or (broken_notify and broken_limb or dislocated_limb)
		elseif pain > 75 then
			most_wanted_phraselist = audible_pain
		elseif broken_dislocated then
			most_wanted_phraselist = (broken_notify and broken_limb or dislocated_limb)
		end

		if pain > 100 then
			most_wanted_phraselist = sharp_pain
		end

		if not most_wanted_phraselist then
			if (broken_dislocated_notify) and (blood < 3100) then
				most_wanted_phraselist = blood < 2900 and (positive_thinking and near_death_positive or near_death_poetic) or (math.random(2) == 1 and (broken_notify and broken_limb or dislocated_limb) or (positive_thinking and near_death_positive or near_death_poetic))
			elseif(blood < 3100)then
				most_wanted_phraselist = positive_thinking and near_death_positive or near_death_poetic
			end
		end
	elseif after_unconscious_notify then
		most_wanted_phraselist = after_unconscious
	elseif hg.nothing_happening(ply) then
		most_wanted_phraselist = random_phrase

		if goodmood and goodmood > 0.8 and math.random(5) == 1 then
			most_wanted_phraselist = good_mood_phrases
		end
	elseif hg.fearful(ply) then
		if positive_thinking and math.random(3) == 1 then
			most_wanted_phraselist = near_death_positive
		else
			most_wanted_phraselist = ((IsAimedAt(ply) > 0.9) and is_aimed_at_phrases or (math.random(10) == 1 and fear_hurt_ironic or fear_phrases))
		end
	end

	if not org.otrub then
		local o2Val = (org.o2 and org.o2[1]) or 30
		local bloodVal = org.blood or 5000
		local bp = org.bloodpressure or 93
		local heartbeat = org.heartbeat or 70

		-- nga imc ooked
		local lowO2 = o2Val < 10
		local lowBlood = bloodVal < 3000 or bp < 45
		local badHeart = org.heartstop or heartbeat < 30 or heartbeat > 250
		local brainDamage = brain >= 0.15 or org.critical == true

	
		if (lowO2 and lowBlood) or (lowBlood and badHeart) or (lowO2 and badHeart) or brainDamage then
			most_wanted_phraselist = cooked_phrases
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

function hg.get_status_message(ply)
	local txt = get_status_message(ply)

	return txt
end

function hg.is_traumatic_message(ply)
	if not IsValid(ply) then return false end
	local org = ply.organism
	if not org then return false end

	-- huy nigga 67 or sum liek that
	if org.just_damaged_bone and ((org.just_damaged_bone + 3 - CurTime()) < -3) then
		return true
	end

	-- Check for arterial wounds (immediate O2 debuff)
	if org.arterialwounds and #org.arterialwounds > 0 then
		return true
	end

	local o2Val = (org.o2 and org.o2[1]) or 30
	local bloodVal = org.blood or 5000
	local bp = org.bloodpressure or 93
	local heartbeat = org.heartbeat or 70
	local brain = org.brain or 0

	local lowO2 = o2Val < 10
	local lowBlood = bloodVal < 2200 or bp < 55
	local badHeart = org.heartstop or heartbeat < 30
	local brainDamage = brain >= 0.3 or org.critical == true

	if (lowO2 and lowBlood) or (lowBlood and badHeart) or (lowO2 and badHeart) or brainDamage then
		return true
	end

	return false
end
