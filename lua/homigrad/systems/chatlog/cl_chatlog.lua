local ChatLog = hg.ChatLog

local IsValid = IsValid
local EyePos = EyePos
local EyeAngles = EyeAngles

local HEAD_BONE = "ValveBiped.Bip01_Head1"
local VIEW_DOT = -0.1
local LOS_CLEAR_FRACTION = 0.97
local NEARBY_DIST = 250
local FAR_DIST = 1800
local VERTICAL_DIST = 160
local FRONT_YAW = 50
local BACK_YAW = 130
local OVERHEAD_LIFE = 3
local OVERHEAD_FADE = 2.5
local MIN_YELL_LETTERS = 2

local EMOTE_COLOR = ChatLog.COLOR_AROUND
local HEARD_COLOR = ChatLog.COLOR_AROUND
local SAY_COLOR = ChatLog.COLOR_STATEMENT
local OVERHEAD_COLOR = Color(235, 235, 235)

local VOICE_ROLL_CHANCE = 0.3
local VOICE_ROLL_COOLDOWN = 20

local knownSpeakers = setmetatable({}, {__mode = "k"})
local voiceOwners = {}
local voiceRollNext = {}

local traceFilter = {}
local traceData = {filter = traceFilter, mask = MASK_VISIBLE}

function ChatLog.Name(ply)
	if not IsValid(ply) then return "Someone" end

	local name = ply.GetPlayerName and ply:GetPlayerName()
	if isstring(name) and name ~= "" then return name end

	return ply:Nick()
end

local function NameColor(ply)
	if IsValid(ply) and ply.GetPlayerColor then return ply:GetPlayerColor():ToColor() end

	return EMOTE_COLOR
end

function ChatLog.SourcePos(ent, fallback)
	if not IsValid(ent) or ent:IsDormant() then return fallback end

	local character = hg.GetCurrentCharacter(ent)
	if not IsValid(character) then return fallback end

	local bone = character:LookupBone(HEAD_BONE)
	local matrix = bone and character:GetBoneMatrix(bone)

	return matrix and matrix:GetTranslation() or fallback
end

local function ClearLine(ent, from, to)
	traceFilter[1] = LocalPlayer()
	traceFilter[2] = hg.GetCurrentCharacter(LocalPlayer())
	traceFilter[3] = ent
	traceFilter[4] = IsValid(ent) and hg.GetCurrentCharacter(ent) or ent
	traceData.start = from
	traceData.endpos = to

	return util.TraceLine(traceData).Fraction >= LOS_CLEAR_FRACTION
end

function ChatLog.IsVisible(ent, pos)
	local lply = LocalPlayer()
	if ent == lply then return true end

	local eyePos = EyePos()
	local delta = pos - eyePos
	local dist = delta:Length()
	if dist < 1 then return true end
	if delta:Dot(EyeAngles():Forward()) < dist * VIEW_DOT then return false end
	if ClearLine(ent, eyePos, pos) then return true end

	local character = IsValid(ent) and hg.GetCurrentCharacter(ent)

	return IsValid(character) and ClearLine(ent, eyePos, character:WorldSpaceCenter())
end

local function ActorPresent(actor)
	if not IsValid(actor) then return false end
	if not actor:IsDormant() then return true end

	local character = hg.GetCurrentCharacter(actor)

	return IsValid(character) and not character:IsDormant()
end

function ChatLog.DirectionPhrase(pos)
	local delta = pos - EyePos()
	local dist = delta:Length()
	if dist < NEARBY_DIST then return "right next to you" end

	local height = math.abs(delta.z)
	local flatDist = math.sqrt(delta.x * delta.x + delta.y * delta.y)
	if height > VERTICAL_DIST and height > flatDist then
		return delta.z > 0 and "above you" or "below you"
	end

	local yaw = math.AngleDifference(delta:Angle().y, EyeAngles().y)
	local absYaw = math.abs(yaw)
	local far = dist > FAR_DIST
	local side
	if absYaw <= FRONT_YAW then
		side = far and "ahead" or "in front of you"
	elseif absYaw >= BACK_YAW then
		side = "behind you"
	else
		side = yaw > 0 and "to your left" or "to your right"
	end

	return far and "in the distance " .. side or side
end

local function Compile(template)
	if not template then return end

	local parts = {}
	local last = 1
	for startPos, token, endPos in string.gmatch(template, "(){(%w+)}()") do
		if startPos > last then parts[#parts + 1] = string.sub(template, last, startPos - 1) end
		parts[#parts + 1] = {token}
		last = endPos
	end
	if last <= #template then parts[#parts + 1] = string.sub(template, last) end

	return parts
end

for _, event in ipairs(ChatLog.Events) do
	event.seenParts = Compile(event.seen)
	event.heardParts = Compile(event.heard)
	event.selfParts = Compile(event.self)
	event.selfOverheadParts = event.self and Compile((string.gsub(event.self, "^{a} ", "")))
	event.overheadParts = event.seen and Compile((string.gsub(event.seen, "^{a} ", "")))
end

local function TokenValue(token, ctx)
	if token == "a" then return ctx.actorName, ctx.actorColor end
	if token == "ap" then return ctx.actorName .. "'s", ctx.actorColor end
	if token == "inj" then return ctx.injury end
	if token == "t" then return ctx.targetSelf and "you" or ctx.targetName, not ctx.targetSelf and ctx.targetColor end
	if token == "tp" then return ctx.targetSelf and "your" or ctx.targetName .. "'s", not ctx.targetSelf and ctx.targetColor end
	if token == "w" then return ctx.weapon end
	if token == "g" then return ctx.gesture end
	if token == "dir" then return ctx.dir end

	return ""
end

local function BuildElements(parts, ctx, textColor)
	local elements = {}
	local current

	local function Append(text, clr)
		clr = clr or textColor
		if clr ~= current then
			elements[#elements + 1] = clr
			current = clr
		end
		elements[#elements + 1] = text
	end

	for _, part in ipairs(parts) do
		if isstring(part) then
			Append(part)
		else
			Append(TokenValue(part[1], ctx))
		end
	end

	return elements
end

local function BuildText(parts, ctx)
	local buffer = {}
	for _, part in ipairs(parts) do
		buffer[#buffer + 1] = isstring(part) and part or (TokenValue(part[1], ctx))
	end

	return table.concat(buffer)
end

local function WeaponText(event, wep)
	local article = event.article or "their"
	if not IsValid(wep) or not wep.GetPrintName then return article .. " weapon" end

	return article .. " " .. string.lower(wep:GetPrintName())
end

local function AddChatLine(elements)
	if IsValid(hg.chat) and hg.chat.AddLine then hg.chat:AddLine(elements) end
end

net.Receive("hg_chatlog_event", function()
	local event = ChatLog.Events[net.ReadUInt(ChatLog.NET_ID_BITS)]
	local actor = net.ReadEntity()
	local target = net.ReadEntity()
	local extra = net.ReadEntity()
	local arg = net.ReadUInt(ChatLog.NET_ARG_BITS)
	local netPos = net.ReadVector()
	if not event then return end

	local lply = LocalPlayer()
	if not IsValid(lply) then return end

	local pos = ChatLog.SourcePos(actor, netPos)
	local seen = ActorPresent(actor) and event.seenParts ~= nil and ChatLog.IsVisible(actor, pos)
	local targetSelf = target == lply
	if not seen and not (targetSelf and event.seenParts) and not event.heardParts then return end

	local ctx = {
		actorName = seen and ChatLog.Name(actor) or "Someone",
		actorColor = seen and NameColor(actor) or EMOTE_COLOR,
		targetSelf = targetSelf,
		targetName = ChatLog.Name(target),
		targetColor = NameColor(target),
		weapon = WeaponText(event, extra),
		gesture = ChatLog.Gestures[arg] or "gestures",
	}

	if seen or (targetSelf and event.seenParts) then
		local selfAct = event.selfParts and IsValid(target) and target == actor
		AddChatLine(BuildElements(selfAct and event.selfParts or event.seenParts, ctx, EMOTE_COLOR))
		if seen and actor ~= lply and hg.AddOverheadMessage and not event.noOverhead then
			hg.AddOverheadMessage(actor, "*" .. BuildText(selfAct and event.selfOverheadParts or event.overheadParts, ctx) .. "*", OVERHEAD_COLOR, OVERHEAD_LIFE, OVERHEAD_FADE)
		end
		return
	end

	ctx.dir = ChatLog.DirectionPhrase(pos)
	AddChatLine(BuildElements(event.heardParts, ctx, HEARD_COLOR))
end)

local function SayVerb(text, whisper)
	if whisper then return "whispers" end

	local letters = string.gsub(text, "[^%a]", "")
	if #letters >= MIN_YELL_LETTERS and letters == string.upper(letters) then return "yells" end
	if string.find(text, "!%s*$") then return "exclaims" end
	if string.find(text, "%?%s*$") then return "asks" end

	return "says"
end

local function VoiceMismatch(ply, name)
	local owner = voiceOwners[name]
	if not IsValid(owner) then
		voiceOwners[name] = ply

		return
	end

	if owner == ply then return end

	local now = CurTime()
	if (voiceRollNext[ply] or 0) > now then return end
	voiceRollNext[ply] = now + VOICE_ROLL_COOLDOWN
	if math.random() > VOICE_ROLL_CHANCE then return end

	timer.Simple(0, function()
		AddChatLine({ChatLog.COLOR_THOUGHT, "That doesn't sound like " .. name .. "."})
	end)
end

function ChatLog.SayElements(ply, text, whisper)
	local verb = SayVerb(text, whisper)
	local quoted = " " .. verb .. ", \"" .. text .. "\""
	local pos = ChatLog.SourcePos(ply, ply:EyePos())
	local seen = ply == LocalPlayer() or ActorPresent(ply) and ChatLog.IsVisible(ply, pos)
	if seen then knownSpeakers[ply] = true end

	if seen or knownSpeakers[ply] then
		if ply ~= LocalPlayer() then VoiceMismatch(ply, ChatLog.Name(ply)) end
		if seen then return {NameColor(ply), ChatLog.Name(ply), SAY_COLOR, quoted} end

		return {NameColor(ply), ChatLog.Name(ply), SAY_COLOR, " " .. ChatLog.DirectionPhrase(pos) .. quoted}
	end

	return {SAY_COLOR, "Someone " .. ChatLog.DirectionPhrase(pos) .. quoted}
end
