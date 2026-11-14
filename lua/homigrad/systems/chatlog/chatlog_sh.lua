hg = hg or {}
hg.ChatLog = hg.ChatLog or {}

local ChatLog = hg.ChatLog

ChatLog.RANGE_NEAR = 450
ChatLog.RANGE_TALK = 900
ChatLog.RANGE_YELL = 1800
ChatLog.RANGE_SCREAM = 3000
ChatLog.RANGE_GUNSHOT = 6000
ChatLog.NET_ID_BITS = 6
ChatLog.NET_ARG_BITS = 5

local NEAR = ChatLog.RANGE_NEAR
local TALK = ChatLog.RANGE_TALK
local YELL = ChatLog.RANGE_YELL
local SCREAM = ChatLog.RANGE_SCREAM
local GUNSHOT = ChatLog.RANGE_GUNSHOT

ChatLog.Events = {
	{key = "scream", range = SCREAM, cooldown = 1.5, seen = "{a} screams in pain!", heard = "You hear a scream {dir}."},
	{key = "painyell", range = YELL, cooldown = 1.5, seen = "{a} yells in pain!", heard = "You hear someone yelling in pain {dir}."},
	{key = "groan", range = TALK, cooldown = 2, seen = "{a} groans in agony.", heard = "You hear someone groaning {dir}."},
	{key = "gasp", range = TALK, cooldown = 2.5, seen = "{a} gasps for air!", heard = "You hear someone gasping {dir}."},
	{key = "agonal", range = NEAR, cooldown = 6, seen = "{a} wheezes, struggling to breathe.", heard = "You hear ragged breathing {dir}."},
	{key = "shout", range = YELL, cooldown = 1, seen = "{a} shouts!", heard = "You hear someone shouting {dir}."},
	{key = "fallscream", range = SCREAM, cooldown = 3, seen = "{a} screams as they fall!", heard = "You hear a scream {dir}."},
	{key = "punch", range = TALK, cooldown = 0.4, targeted = true, seen = "{a} punches {t}!", heard = "You hear scuffling {dir}."},
	{key = "strike", range = TALK, cooldown = 0.4, targeted = true, seen = "{a} strikes {t}!", heard = "You hear scuffling {dir}."},
	{key = "melee", range = TALK, cooldown = 0.4, targeted = true, seen = "{a} hits {t} with {w}!", heard = "You hear scuffling {dir}."},
	{key = "slash", range = TALK, cooldown = 0.4, targeted = true, seen = "{a} slashes {t} with {w}!", heard = "You hear scuffling {dir}."},
	{key = "shoot", range = GUNSHOT, cooldown = 0.6, targeted = true, seen = "{a} shoots {t}!"},
	{key = "gunshot", range = GUNSHOT, cooldown = 1.5, seen = "{a} fires {w}!", heard = "You hear gunshots {dir}."},
	{key = "shove", range = TALK, cooldown = 0.6, targeted = true, seen = "{a} shoves {t}!", heard = "You hear scuffling {dir}."},
	{key = "grab", range = TALK, cooldown = 1, targeted = true, seen = "{a} grabs {t}!"},
	{key = "disarm", range = TALK, cooldown = 0.5, targeted = true, article = "the", seen = "{a} knocks {w} out of {tp} hands!", heard = "You hear something clatter {dir}."},
	{key = "fall", range = TALK, cooldown = 1, seen = "{a} falls over!", heard = "You hear a thud {dir}."},
	{key = "drop", range = TALK, cooldown = 1, seen = "{a} drops to the ground."},
	{key = "getup", range = TALK, cooldown = 1, seen = "{a} gets back up."},
	{key = "collapse", range = TALK, cooldown = 2, seen = "{a} collapses and goes limp!", heard = "You hear a body hit the floor {dir}."},
	{key = "death", range = TALK, cooldown = 2, seen = "{a} goes completely still."},
	{key = "gesture", range = TALK, cooldown = 1, seen = "{a} {g}."},
	{key = "surrender", range = TALK, cooldown = 1.5, seen = "{a} raises their hands."},
	{key = "kneel", range = TALK, cooldown = 1.5, seen = "{a} kneels down."},
	{key = "softcrit", range = TALK, cooldown = 3, seen = "{a} collapses!", heard = "You hear a body hit the floor {dir}."},
	{key = "hardcrit", range = TALK, cooldown = 3, seen = "{a} goes limp!"},
	{key = "stopbreathing", range = NEAR, cooldown = 10, seen = "{a} stops breathing!"},
	{key = "airgasp", range = TALK, cooldown = 15, seen = "{a} is gasping for air!", heard = "You hear someone gasping {dir}."},
	{key = "coughblood", range = TALK, cooldown = 10, seen = "{a} coughs up blood!", heard = "You hear wet coughing {dir}."},
}

ChatLog.Gestures = {
	"waves",
	"nods",
	"signals to wait",
	"signals danger",
	"gestures thanks",
	"beckons",
	"signals to regroup",
	"waves for help",
	"points",
	"flips someone off",
	"gives a thumbs up",
}

ChatLog.GestureIndex = {
	hello = 1,
	acknowledge = 2,
	wait = 3,
	danger = 4,
	thanks = 5,
	omw = 6,
	regroup = 7,
	help = 8,
	point = 9,
	point_of = 9,
	fuckyou = 10,
	thumb_up = 11,
}

ChatLog.ByKey = {}

for id, event in ipairs(ChatLog.Events) do
	event.id = id
	ChatLog.ByKey[event.key] = event
end

ChatLog.COLOR_STATEMENT = Color(255, 255, 255)
ChatLog.COLOR_THOUGHT = Color(235, 70, 70)
ChatLog.COLOR_GOOD = Color(110, 170, 255)
ChatLog.COLOR_AROUND = Color(255, 160, 60)

local GOOD_BLUE_MARGIN = 30

function ChatLog.ThoughtColor(clr, group)
	local bluish = clr and clr.b > clr.r + GOOD_BLUE_MARGIN
	if group == "good" or bluish then return ChatLog.COLOR_GOOD end

	return ChatLog.COLOR_THOUGHT
end

local SUBJECT_WORDS = {
	["i"] = "you",
	["i'm"] = "you're",
	["im"] = "you're",
	["i've"] = "you've",
	["i'll"] = "you'll",
	["i'd"] = "you'd",
}

local OBJECT_WORDS = {
	["me"] = "you",
	["my"] = "your",
	["mine"] = "yours",
	["myself"] = "yourself",
}

local SUBJECT_VERBS = {
	["am"] = "are",
	["was"] = "were",
}

local SENTENCE_BREAK = "[%.%!%?%-]"

ChatLog.SecondPersonOverrides = {
	["STOP STOP STOP HELP HELP IT HURTS WHY IM GONNA DIE IM GONNA DIE"] = "IT WON'T STOP- IT HURTS- YOU'RE GOING TO DIE- YOU'RE GOING TO DIE-",
	["NO NO NO NO PLEASE IT HURTS IT HURTS HELP ME HELP ME"] = "NO NO NO- IT HURTS- IT HURTS- YOU NEED HELP- YOU NEED HELP-",
	["AAAGH HELP HELP SOMEBODY HELP ME I'M DYING I'M DYING"] = "YOU SCREAM FOR ANYBODY- YOU'RE DYING- YOU'RE DYING-",
	["MAKE IT STOP MAKE IT STOP PLEASE GOD MAKE IT STOP"] = "YOU BEG FOR IT TO STOP- PLEASE GOD- MAKE IT STOP-",
	["PLEASE PLEASE PLEASE STOP IT HURTS WHY WHY WHY"] = "YOU CAN'T TAKE IT- IT HURTS- WHY- WHY- WHY-",
	["I'm down! Cover me, please, cover me!"] = "You're down! You need someone to cover you!",
	["I'M HIT, SOMEONE HELP ME!"] = "YOU'RE HIT, YOU NEED HELP!",
	["I CAN'T STOP THE BLEEDING I CAN'T I JUST CAN'T PLEASE HELP ME"] = "YOU CAN'T STOP THE BLEEDING- YOU CAN'T- YOU NEED HELP-",
	["no-no no.. someone help me.."] = "no-no no.. you need someone to help you..",
	["stop.. please.. dont make me.."] = "stop.. please.. you don't want to..",
}

local function MatchCase(replacement, original, caps, sentenceStart)
	if caps then return string.upper(replacement) end
	if #original > 1 and original == string.upper(original) then return string.upper(replacement) end
	if sentenceStart or string.find(original, "^%u") and #original > 1 then
		return string.upper(string.sub(replacement, 1, 1)) .. string.sub(replacement, 2)
	end

	return replacement
end

local function Adjacent(separator)
	return separator ~= nil and string.find(separator, "^%s+$") ~= nil
end

function ChatLog.SecondPerson(msg)
	if not isstring(msg) or msg == "" then return msg end

	local override = ChatLog.SecondPersonOverrides[msg]
	if override then return override end

	local words = {}
	for startPos, word, endPos in string.gmatch(msg, "()([%a']+)()") do
		words[#words + 1] = {startPos = startPos, word = word, endPos = endPos, lower = string.lower(word)}
	end
	if #words == 0 then return msg end

	local caps = msg == string.upper(msg) and msg ~= string.lower(msg)
	for i, entry in ipairs(words) do
		local previous = words[i - 1]
		entry.separator = string.sub(msg, previous and previous.endPos or 1, entry.startPos - 1)
	end

	for i, entry in ipairs(words) do
		local subject = SUBJECT_WORDS[entry.lower]
		local object = OBJECT_WORDS[entry.lower]
		if subject then
			local previous = words[i - 1]
			local sentenceStart = not previous or string.find(entry.separator, SENTENCE_BREAK) ~= nil
			entry.replacement = MatchCase(subject, "x", caps, sentenceStart)

			local nextWord = words[i + 1]
			if entry.lower == "i" and nextWord and Adjacent(nextWord.separator) and SUBJECT_VERBS[nextWord.lower] then
				nextWord.replacement = MatchCase(SUBJECT_VERBS[nextWord.lower], nextWord.word, caps, false)
			end
			if entry.lower == "i" and previous and Adjacent(entry.separator) and SUBJECT_VERBS[previous.lower] then
				previous.replacement = MatchCase(SUBJECT_VERBS[previous.lower], previous.word, caps, false)
			end
		elseif object then
			entry.replacement = MatchCase(object, entry.word, caps, false)
		end
	end

	local buffer = {}
	for _, entry in ipairs(words) do
		buffer[#buffer + 1] = entry.separator
		buffer[#buffer + 1] = entry.replacement or entry.word
	end
	buffer[#buffer + 1] = string.sub(msg, words[#words].endPos)

	return table.concat(buffer)
end
