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
	{key = "injury", range = NEAR, cooldown = 0.4, noOverhead = true, seen = "{ap} {inj}."},
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
	["The edges of my vision are going dark... I need air..."] = "Your oxygen levels are low.",
	["My head is swimming... I need oxygen..."] = "Your oxygen levels are low. Your head is swimming.",
	["Breathe... just breathe..."] = "You force yourself to breathe slowly.",
	["Why can't I breathe properly..."] = "You can't breathe properly.",
	["I'm panting and it's not helping..."] = "You are panting, and it isn't helping.",
	["The edges of my vision are starting to blur..."] = "Your vision is starting to blur.",
	["I NEED AIR... I CAN'T BREATHE..."] ="You are struggling to breathe. You need air.",
	["IM SUFFOCATING TO FUCKING DEATH."] = "You are suffocating.",
	["WHY CANT I BREATHE. I NEED AIR..."] = "You can't breathe. Your lungs are burning for air.",
	["IT'S GETTING HARDER TO BREATHE... I NEED AIR..."] = "You are struggling to breathe.",
	["I CANT FUCKING BREATHE."] = "You can't draw a breath.",
	["I CAN'T... I CAN BARELY BREATHE!"] = "You can barely breathe.",
	["I NEED WATER!!"] = "You desperately need water.",
	["GET ME A MEDIC, NOW!"] = "You need a medic, now.",
	["LOOK AT ME! I'M IN PIECES!"] = "You look down at yourself. You are in pieces.",
	["I'M DYING... I CAN'T FEEL MY PULSE"] = "You are dying. You can't feel your pulse.",
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

local INTERJECTION_PHRASES = {
	"WHAT THE FUCK",
	"WHAT THE HELL",
	"OH MY GOD",
	"HOLY SHIT",
	"HOLY FUCK",
	"JESUS CHRIST",
	"GOD DAMN IT",
	"GOD DAMN",
	"OH GOD",
	"OH FUCK",
	"OH SHIT",
}

local INTERJECTION_WORDS = {}
for word in string.gmatch("FUCK FUCKING FUCKED SHIT DAMN DAMMIT GOD JESUS CHRIST HOLY OH OHH AH AGH AGHH HEY NO NONONO NOO YES PLEASE", "%S+") do
	INTERJECTION_WORDS[word] = true
end

local PLEA_WORDS = {}
for word in string.gmatch("STOP WHY ME KILL HELP ANYONE SOMEBODY SOMEONE NOW", "%S+") do
	PLEA_WORDS[word] = true
end

local MAX_REPEAT_LENGTH = 4

local function IsShouted(msg)
	return msg == string.upper(msg) and msg ~= string.lower(msg)
end

local function IsScream(word)
	if string.find(word, "^FU+CK") then return true end

	return #word >= 3 and string.find(word, "^[AGHNFU]+$") ~= nil and (string.find(word, "AA") ~= nil or string.find(word, "GH") ~= nil)
end

local function CollapseRepeats(words)
	for size = 1, MAX_REPEAT_LENGTH do
		local i = 1
		while i + 2 * size - 1 <= #words do
			local same = true
			for k = 0, size - 1 do
				if words[i + k] ~= words[i + size + k] then
					same = false
					break
				end
			end

			if same then
				for _ = 1, size do table.remove(words, i + size) end
			else
				i = i + 1
			end
		end
	end
end

local function CleanPart(part)
	local words = {}
	for word in string.gmatch(part, "[%w']+") do
		if not INTERJECTION_WORDS[word] and not IsScream(word) then words[#words + 1] = word end
	end

	CollapseRepeats(words)

	local meaningful = false
	for _, word in ipairs(words) do
		if not PLEA_WORDS[word] then
			meaningful = true
			break
		end
	end

	if not meaningful then return end

	return table.concat(words, " ")
end

local function ShoutFallback(msg)
	if string.find(msg, "KILL") or string.find(msg, "DEATH") then return "You beg for it to end." end
	if string.find(msg, "HELP") or string.find(msg, "ANYONE") or string.find(msg, "SOMEBODY") then return "You cry out for help." end
	if string.find(msg, "STOP") or string.find(msg, "PLEASE") then return "You beg for it to stop." end

	return "You scream in agony."
end

local LIMB_WORDS = {"SHOULDER", "ELBOW", "HIP", "KNEE", "ANKLE", "SHIN", "THIGH", "WRIST", "ARM", "LEG", "FOOT", "HAND"}
local DISLOCATION_PHRASES = {"DISLOCATED", "POPPED OUT", "OUT OF THE SOCKET", "OUT OF PLACE", "HANGING LOOSE"}
local BREAK_PHRASES = {"BROKEN", "SNAP"}

local function ContainsAny(msg, phrases)
	for _, phrase in ipairs(phrases) do
		if string.find(msg, phrase, 1, true) then return true end
	end

	return false
end

local function LimbCondition(msg)
	local condition = ContainsAny(msg, DISLOCATION_PHRASES) and "dislocated" or ContainsAny(msg, BREAK_PHRASES) and "broken"
	if not condition then return end

	for _, limb in ipairs(LIMB_WORDS) do
		if string.find(msg, "%f[%a]" .. limb .. "%f[%A]") then
			return "Your " .. string.lower(limb) .. " is " .. condition .. "."
		end
	end
end

function ChatLog.Narrate(msg)
	if not isstring(msg) or msg == "" then return msg end
	if not IsShouted(msg) then return ChatLog.SecondPerson(msg) end

	local override = ChatLog.SecondPersonOverrides[msg]
	if override then return override end

	local limbCondition = LimbCondition(msg)
	if limbCondition then return limbCondition end

	local text = string.gsub(msg, "%.%.+", ",")
	text = string.gsub(text, "%-+", ",")
	for _, phrase in ipairs(INTERJECTION_PHRASES) do
		text = string.gsub(text, "%f[%a']" .. phrase .. "%f[^%a']", ",")
	end

	local sentences = {}
	for body, ending in string.gmatch(text, "([^%.%!%?]+)([%.%!%?]*)") do
		local parts = {}
		for part in string.gmatch(body, "[^,]+") do
			local cleaned = CleanPart(part)
			if cleaned and cleaned ~= parts[#parts] then parts[#parts + 1] = cleaned end
		end

		if #parts > 0 then
			local sentence = ChatLog.SecondPerson(table.concat(parts, ", "))
			sentences[#sentences + 1] = sentence .. (string.find(ending, "?", 1, true) and "?" or ".")
		end
	end

	if #sentences == 0 then return ShoutFallback(msg) end

	local result = string.lower(table.concat(sentences, " "))
	result = string.gsub(result, "^%l", string.upper)
	result = string.gsub(result, "([%.%?]%s+)(%l)", function(separator, letter) return separator .. string.upper(letter) end)

	return result
end

local function Amount(org, key)
	return tonumber(org[key]) or 0
end

local function LungCollapsed(lung)
	return istable(lung) and (tonumber(lung[1]) or 0) >= 1
end

ChatLog.Injuries = {
	{text = "neck looks horribly caved in", check = function(org) return Amount(org, "trachea") >= 1 end},
	{text = "neck is bent at a sickening angle", check = function(org) return Amount(org, "spine3") >= 1 end},
	{text = "chest looks caved in", check = function(org) return Amount(org, "chest") >= 1 end},
	{text = "skull looks caved in", check = function(org) return Amount(org, "skull") >= 1 end},
	{text = "jaw hangs crooked and loose", check = function(org) return Amount(org, "jaw") >= 1 end},
	{text = "back looks horribly twisted", check = function(org) return Amount(org, "spine1") >= 1 or Amount(org, "spine2") >= 1 end},
	{text = "hips look crooked and wrong", check = function(org) return Amount(org, "pelvis") >= 1 end},
	{text = "chest rises unevenly", check = function(org) return LungCollapsed(org.lungsL) or LungCollapsed(org.lungsR) end},
	{text = "stomach looks swollen and bruised", check = function(org) return Amount(org, "gut") >= 1 or Amount(org, "liver") >= 1 end},
	{text = "left eye is a bloody mess", check = function(org) return Amount(org, "eyeL") >= 1 end},
	{text = "right eye is a bloody mess", check = function(org) return Amount(org, "eyeR") >= 1 end},
}

local LIMB_SEGMENTS = {
	{"larm", "up", "left upper arm", "left shoulder", "weirdly bent"},
	{"larm", "down", "left forearm", "left elbow", "weirdly bent"},
	{"rarm", "up", "right upper arm", "right shoulder", "weirdly bent"},
	{"rarm", "down", "right forearm", "right elbow", "weirdly bent"},
	{"lleg", "up", "left thigh", "left hip", "bent at the wrong angle"},
	{"lleg", "down", "left shin", "left knee", "bent at the wrong angle"},
	{"rleg", "up", "right thigh", "right hip", "bent at the wrong angle"},
	{"rleg", "down", "right shin", "right knee", "bent at the wrong angle"},
}

for _, segment in ipairs(LIMB_SEGMENTS) do
	local healthKey = segment[1] .. "_" .. segment[2]
	ChatLog.Injuries[#ChatLog.Injuries + 1] = {
		text = segment[3] .. " looks " .. segment[5],
		check = function(org) return Amount(org, healthKey) >= 1 end,
	}
end

for _, segment in ipairs(LIMB_SEGMENTS) do
	local dislocationKey = segment[1] .. "_" .. segment[2] .. "_disl"
	ChatLog.Injuries[#ChatLog.Injuries + 1] = {
		text = segment[4] .. " looks out of place",
		check = function(org) return org[dislocationKey] and true or false end,
	}
end
