hg = hg or {}
hg.ChatLog = hg.ChatLog or {}

local ChatLog = hg.ChatLog

ChatLog.RANGE_NEAR = 450
ChatLog.RANGE_TALK = 900
ChatLog.RANGE_YELL = 1800
ChatLog.RANGE_SCREAM = 3000
ChatLog.RANGE_GUNSHOT = 6000
ChatLog.RANGE_SWING = 170
ChatLog.NET_ID_BITS = 6
ChatLog.NET_ARG_BITS = 5

local NEAR = ChatLog.RANGE_NEAR
local TALK = ChatLog.RANGE_TALK
local YELL = ChatLog.RANGE_YELL
local SCREAM = ChatLog.RANGE_SCREAM
local GUNSHOT = ChatLog.RANGE_GUNSHOT
local SWING = ChatLog.RANGE_SWING

ChatLog.Events = {
	{key = "scream", range = SCREAM, cooldown = 1.5, seen = "{a} screams in pain!", heard = "You hear a scream {dir}."},
	{key = "painyell", range = YELL, cooldown = 1.5, seen = "{a} yells in pain!", heard = "You hear someone yelling in pain {dir}."},
	{key = "gasp", range = TALK, cooldown = 2.5, repeatEvery = 10, seen = "{a} gasps for air!", heard = "You hear someone gasping {dir}."},
	{key = "agonal", range = NEAR, cooldown = 6, repeatEvery = 45, seen = "{a} wheezes, struggling to breathe.", heard = "You hear ragged breathing {dir}."},
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
	{key = "death", range = TALK, cooldown = 2, seen = "{a} goes completely still.", heard = "You hear a body slump to the floor {dir}."},
	{key = "gesture", range = TALK, cooldown = 1, seen = "{a} {g}."},
	{key = "surrender", range = TALK, cooldown = 1.5, seen = "{a} raises their hands."},
	{key = "kneel", range = TALK, cooldown = 1.5, seen = "{a} kneels down."},
	{key = "softcrit", range = TALK, cooldown = 3, seen = "{a} collapses!", heard = "You hear a body hit the floor {dir}."},
	{key = "hardcrit", range = TALK, cooldown = 3, seen = "{a} goes limp!", heard = "You hear a body slump to the floor {dir}."},
	{key = "stopbreathing", range = NEAR, cooldown = 10, repeatEvery = 120, seen = "{a} stops breathing!"},
	{key = "airgasp", range = TALK, cooldown = 15, repeatEvery = 45, seen = "{a} is gasping for air!", heard = "You hear someone gasping {dir}."},
	{key = "coughblood", range = TALK, cooldown = 10, repeatEvery = 30, seen = "{a} coughs up blood!", heard = "You hear wet coughing {dir}."},
	{key = "laugh", range = YELL, cooldown = 4, repeatEvery = 20, seen = "{a} laughs maniacally!", heard = "You hear someone laughing {dir}."},
	{key = "getup", range = TALK, cooldown = 2, seen = "{a} gets back up."},
	{key = "wake", range = TALK, cooldown = 3, seen = "{a} stirs and wakes up."},
	{key = "blooddrip", range = NEAR, cooldown = 6, repeatEvery = 120, repeatGroup = "blood", noOverhead = true, seen = "{ap} blood drips onto the floor.", heard = "You hear blood dripping {dir}."},
	{key = "bloodpool", range = TALK, cooldown = 8, repeatEvery = 120, repeatGroup = "blood", noOverhead = true, seen = "{a} is leaving a puddle of blood!", heard = "You hear blood splattering on the floor {dir}."},
	{key = "propimpact", range = TALK, cooldown = 0.5, world = true, heard = "You hear something heavy crash {dir}."},
	{key = "propflyby", range = NEAR, cooldown = 1.5, world = true, heard = "Something whips past {dir}."},
	{key = "bulletimpact", range = GUNSHOT, cooldown = 1.5, world = true, heard = "A bullet smacks into something {dir}!"},
	{key = "bulletflyby", range = GUNSHOT, cooldown = 1, world = true, heard = "A bullet cracks past {dir}!"},
	{key = "swingnear", range = SWING, cooldown = 1.2, noOverhead = true, seen = "{a} swings {w} right beside you!", heard = "Something swishes through the air {dir}."},
	{key = "swingfist", range = SWING, cooldown = 1.2, noOverhead = true, seen = "{a} throws a punch right beside you!", heard = "You hear a fist cut the air {dir}."},
	{key = "grenaderoll", range = NEAR, cooldown = 3, world = true, heard = "You hear something metallic rolling {dir}."},
	{key = "medbandage", range = TALK, cooldown = 2, seen = "{a} bandages {tp} wounds.", self = "{a} bandages their wounds."},
	{key = "medsplint", range = TALK, cooldown = 2, seen = "{a} splints {tp} limb.", self = "{a} splints their limb."},
	{key = "medtourniquet", range = TALK, cooldown = 2, seen = "{a} ties a tourniquet around {tp} limb.", self = "{a} ties a tourniquet around their limb."},
	{key = "medsuture", range = TALK, cooldown = 2, seen = "{a} stitches {tp} wounds shut.", self = "{a} stitches their wounds shut."},
	{key = "medamputate", range = TALK, cooldown = 2, seen = "{a} cuts off {tp} limb!", self = "{a} cuts off their own limb!"},
	{key = "medinject", range = TALK, cooldown = 2, article = "a", seen = "{a} injects {t} with {w}.", self = "{a} injects themselves with {w}."},
	{key = "medpills", range = TALK, cooldown = 2, seen = "{a} gives {t} some pills.", self = "{a} swallows some pills."},
	{key = "medneedle", range = TALK, cooldown = 2, seen = "{a} jabs a needle into {tp} chest!", self = "{a} jabs a needle into their chest!"},
	{key = "medfixdisloc", range = TALK, cooldown = 2, seen = "{a} sets {tp} dislocated joint back into place.", self = "{a} pops their joint back into place.", heard = "You hear a sickening pop {dir}."},
	{key = "critblow", range = TALK, cooldown = 0.5, targeted = true, toActor = true, crit = true, seen = "{a} lands a crushing blow on {t}!", mine = "You land a crushing blow on {t}!", heard = "You hear a sickening thud {dir}."},
	{key = "critshot", range = TALK, cooldown = 0.5, targeted = true, toActor = true, crit = true, seen = "{ap} shot tears right into {t}!", mine = "Your shot tears right into {t}!"},
	{key = "organhit", range = TALK, cooldown = 0.5, targeted = true, toActor = true, crit = true, seen = "{a} hits something vital inside {t}!", mine = "You hit something vital inside {t}!"},
	{key = "bonebreak", range = TALK, cooldown = 0.3, targeted = true, toActor = true, crit = true, seen = "{a} breaks {tp} {bone}!", mine = "You break {tp} {bone}!", heard = "You hear a sickening crack {dir}."},
	{key = "knockout", range = TALK, cooldown = 1, targeted = true, toActor = true, crit = true, seen = "{a} knocks {t} out cold!", mine = "You knock {t} out cold!"},
}

ChatLog.COLOR_CRIT = Color(255, 90, 90)

ChatLog.CritBones = {"ribs", "skull", "jaw", "neck", "spine", "pelvis", "left arm", "right arm", "left leg", "right leg"}

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

ChatLog.FirstPersonLines = {}
for _, line in ipairs({
	"I can't stay awake...",
	"I'm about to pass out...",
	"Everything is going dark...",
	"I can't stay awake much longer...",
	"My body is shutting down...",
	"SO MANY ROUNDS- THEY'RE ALL AROUND ME-",
	"FUCK- BULLETS EVERYWHERE- I CAN'T MOVE-",
	"THEY'RE PINNING ME- I NEED COVER-",
	"I'M BEING HIT- AGAIN- AGAIN-",
	"THEY'RE TEARING ME APART-",
	"I'M GETTING SHREDDED-",
	"THEY'RE RAKING ME- I NEED TO MOVE-",
	"ROUNDS ALL OVER- AND I'M HIT-",
	"I'm in pain.",
	"I CAN'T TAKE THE PAIN!",
	"I'm going into shock!",
	"I feel lightheaded.",
	"I feel very weak.",
	"I'M ABOUT TO PASS OUT FROM BLOOD LOSS!",
	"I can't stand up, it hurts too much.",
	"The pain keeps me on the ground!",
	"I can't fix it, the pain is too much!",
	"I'm afraid.",
	"I'm terrified.",
	"I'm in danger.",
	"I'm panicking.",
	"I can't stop panicking.",
	"I'm starting to panic.",
	"Panic is clouding my head.",
	"I'm in severe pain.",
	"My injuries hurt so much.",
	"I'm in extreme pain.",
	"The pain is overwhelming me.",
	"My chest hurts.",
	"Something is poking at my lungs.",
	"My leg hurts when I move.",
	"I can't move comfortably on this leg.",
	"My jaw hurts when I speak.",
	"My jaw is killing me.",
	"My jaw hurts when I talk.",
	"Talking makes my jaw hurt.",
	"I'm close to death.",
	"I'm burning!",
	"I'm at my limit.",
	"I can't hold on much longer.",
}) do
	ChatLog.FirstPersonLines[line] = true
end

local keepFirstPerson = false

function ChatLog.SecondPerson(msg)
	if not isstring(msg) or msg == "" then return msg end
	if keepFirstPerson then return msg end

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

local NarrateInner

function ChatLog.Narrate(msg)
	if not isstring(msg) or msg == "" then return msg end

	keepFirstPerson = ChatLog.FirstPersonLines[msg] == true
	local result = NarrateInner(msg)
	keepFirstPerson = false

	return result
end

NarrateInner = function(msg)
	if not IsShouted(msg) then return ChatLog.SecondPerson(msg) end

	local limbCondition = LimbCondition(msg)
	if limbCondition then return limbCondition end

	if true then return msg end

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
	if keepFirstPerson then
		result = string.gsub(result, "%f[%a']i%f[^%a']", "I")
		result = string.gsub(result, "%f[%a']i('%a+)", "I%1")
	end

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
