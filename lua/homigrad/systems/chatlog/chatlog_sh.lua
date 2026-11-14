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
