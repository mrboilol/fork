surface.CreateFont("HG_OverheadChat", {
	font = "Tahoma",
	size = 120,
	weight = 800,
	antialias = true,
})

local hg_overheadchat = ConVarExists("hg_overheadchat") and GetConVar("hg_overheadchat") or CreateClientConVar("hg_overheadchat", "1", true, false, "Toggle overhead chat messages above players heads", 0, 1)
local hg_overheadchat_distance = ConVarExists("hg_overheadchat_distance") and GetConVar("hg_overheadchat_distance") or CreateClientConVar("hg_overheadchat_distance", "512", true, false, "The distance (in hammer units) at which overhead chat messages are visible, 0 = inf", 0, 2048)

local math_Clamp = math.Clamp
local utf8_codes, utf8_char = utf8.codes, utf8.char

local font = "HG_OverheadChat"
local maxMessages = 3
local maxLines = 3
local maxLineWidth = 800
local lineStep = 150
local padX, padY = 40, 32
local msgTime = 7
local fadeInTime = 0.2
local fadeOutTime = 2
local edgeFade = 120
local whisperDist = 64
local drawScale = 0.025
local whisperScale = 0.8
local emoteScale = 0.75
local emoteRepeatWindow = 1
local headOffset = Vector(0, 0, 24)
local stackGap = 4
local boxRadius = 40
local underlay = 8

local maxEvents = 5
local eventLife = 12
local eventFade = 2
local tagHeadOffset = Vector(0, 0, 14)
local tagFont = "HomigradFontLarge"
local eventFont = "HomigradFontMedium"
local tagGap = 18
local eventStep = 22

local drawColor = Color(255, 255, 255)
local bgColor = Color(0, 0, 0, 175)
local rimColor = Color(255, 255, 255, 60)
local outlineColor = Color(0, 0, 0, 200)

local function TruncateLine(line)
	local w = select(1, surface.GetTextSize(line))
	if w <= maxLineWidth then return line end

	local out = ""

	for _, code in utf8_codes(line) do
		local test = out .. utf8_char(code)
		if select(1, surface.GetTextSize(test .. "…")) > maxLineWidth then break end
		out = test
	end

	return out .. "…"
end

local function LayoutMessage(text)
	surface.SetFont(font)

	local words = {}
	for word in string.gmatch(text, "%S+") do
		words[#words + 1] = word
	end

	if #words == 0 then return {}, 0 end

	local lines = {}
	local cur = ""
	local dropped = false

	for i = 1, #words do
		local word = words[i]
		local test = cur == "" and word or cur .. " " .. word

		if cur == "" or select(1, surface.GetTextSize(test)) <= maxLineWidth then
			cur = test
		else
			lines[#lines + 1] = TruncateLine(cur)
			cur = word

			if #lines >= maxLines then
				dropped = true
				cur = nil
				break
			end
		end
	end

	if cur then
		lines[#lines + 1] = cur
	end

	if dropped then
		lines[#lines] = TruncateLine(lines[#lines] .. "…")
	else
		lines[#lines] = TruncateLine(lines[#lines])
	end

	local widest = 0
	for i = 1, #lines do
		widest = math.max(widest, select(1, surface.GetTextSize(lines[i])))
	end

	return lines, widest
end

hook.Add("OnPlayerChat", "HGOverheadChat", function(ply, strText, bTeam, bDead, bWhisper)
	if bTeam then return end
	if bWhisper == nil then bWhisper = false end
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	local clr = ply:GetPlayerColor():ToColor()

	local list = ply.HGOverheadChat
	if not istable(list) then
		list = {}
		ply.HGOverheadChat = list
	end

	list[#list + 1] = {
		text = tobool(bWhisper) and ("[whisper] " .. tostring(strText)) or tostring(strText),
		color = Color(clr.r, clr.g, clr.b, 255),
		whisper = tobool(bWhisper),
		born = CurTime(),
		die = CurTime() + msgTime,
	}

	while #list > maxMessages do
		table.remove(list, 1)
	end
end)

function hg.AddOverheadMessage(ply, text, color, life, fade)
	if not hg_overheadchat:GetBool() then return end
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	local list = ply.HGOverheadChat
	if not istable(list) then
		list = {}
		ply.HGOverheadChat = list
	end

	local events = ply.HGEventLog
	if not istable(events) then
		events = {}
		ply.HGEventLog = events
	end

	local now = CurTime()
	local last = events[#events]
	text = string.gsub(text, "^%*+", "")
	text = string.gsub(text, "%*+$", "")

	if last and last.text == text and now - last.born < emoteRepeatWindow then
		last.die = now + eventLife
		return
	end

	events[#events + 1] = {
		text = text,
		color = Color(color.r, color.g, color.b, 255),
		born = now,
		die = now + eventLife,
	}

	while #events > maxEvents do
		table.remove(events, 1)
	end
end

local function DrawOverheadChat(ply, eyePos, maxDist)
	local list = ply.HGOverheadChat
	if not istable(list) or #list == 0 then return end

	local time = CurTime()

	if not ply:Alive() then
		ply.HGOverheadChat = nil
		return
	end

	for i = #list, 1, -1 do
		if time >= list[i].die then
			table.remove(list, i)
		end
	end

	if #list == 0 then
		ply.HGOverheadChat = nil
		return
	end

	local character = hg.GetCurrentCharacter(ply)
	if not IsValid(character) then return end

	local bone = character:LookupBone("ValveBiped.Bip01_Head1")
	if not bone then return end

	character:SetupBones()

	local matrix = character:GetBoneMatrix(bone)
	if not matrix then return end

	local headPos = matrix:GetTranslation() + headOffset
	local dist = eyePos:Distance(headPos)

	local stackH = 0

	for i = #list, 1, -1 do
		local msg = list[i]

		local distLimit = msg.whisper and whisperDist or maxDist
		if dist > distLimit then continue end

		local alpha = math_Clamp((msg.die - time) / (msg.fade or fadeOutTime), 0, 1)
			* math_Clamp((time - msg.born) / fadeInTime, 0, 1)
			* math_Clamp((distLimit - dist) / edgeFade, 0, 1)

		if alpha <= 0 then continue end

		if not msg.lines then
			msg.lines, msg.widest = LayoutMessage(msg.text)
		end

		local lines = msg.lines
		local count = #lines
		if count == 0 then continue end

		local panelW = msg.widest + padX * 2
		local panelH = count * lineStep + padY * 2

		local msgPos = headPos + Vector(0, 0, stackH)
		stackH = stackH + panelH * drawScale + stackGap

		local ang = (msgPos - eyePos):Angle()
		ang:RotateAroundAxis(ang:Up(), -90)
		ang:RotateAroundAxis(ang:Forward(), 90)

		local a = 255 * alpha
		local clr = msg.color
		drawColor.r = clr.r
		drawColor.g = clr.g
		drawColor.b = clr.b
		drawColor.a = a

		rimColor.r = clr.r
		rimColor.g = clr.g
		rimColor.b = clr.b
		rimColor.a = 60 * alpha

		bgColor.a = ((msg.whisper or msg.emote) and 120 or 175) * alpha
		outlineColor.a = 200 * alpha

		local msgScale = msg.emote and emoteScale or msg.whisper and whisperScale or 1

		cam.Start3D2D(msgPos, ang, drawScale * msgScale)
			if not msg.whisper and not msg.emote then
				draw.RoundedBox(boxRadius, -panelW / 2 - underlay, -panelH / 2 - underlay, panelW + underlay * 2, panelH + underlay * 2, rimColor)
			end

			draw.RoundedBox(boxRadius, -panelW / 2, -panelH / 2, panelW, panelH, bgColor)

			for j = 1, count do
				draw.SimpleTextOutlined(lines[j], font, 0, -panelH / 2 + padY + (j - 1) * lineStep + lineStep / 2, drawColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, outlineColor)
			end
		cam.End3D2D()
	end
end

hook.Add("PostDrawTranslucentRenderables", "HGOverheadChat", function(depth, skybox)
	if depth or skybox then return end
	if not hg_overheadchat:GetBool() then return end

	local lply = LocalPlayer()
	if not IsValid(lply) then return end

	local eyePos = EyePos()
	local maxDist = hg_overheadchat_distance:GetInt()
	if maxDist <= 0 then maxDist = math.huge end

	local viewEnt = GetViewEntity()
	local drawSelf = IsValid(viewEnt) and viewEnt ~= lply

	local players = player.GetAll()

	for i = 1, #players do
		local ply = players[i]

		if ply ~= lply or drawSelf then
			DrawOverheadChat(ply, eyePos, maxDist)
		end
	end
end)

local tagColor = Color(255, 255, 255)
local tagOutline = Color(0, 0, 0)
local eventColor = Color(255, 255, 255)

hook.Add("HUDPaint", "HGTargetTag", function()
	local lply = LocalPlayer()
	if not IsValid(lply) or not lply:Alive() then return end
	if lply.organism and lply.organism.otrub then return end
	if lply:GetNetVar("disappearance", nil) then return end

	local trace = hg.eyeTrace(lply)
	if not trace or not trace.Hit then return end

	local ent = trace.Entity
	if not IsValid(ent) then return end

	local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
	if not IsValid(ply) and ent:IsRagdoll() then ply = ent end
	if not IsValid(ply) then return end
	if ply.PlayerClassName == "sc_infiltrator" then return end
	if ply:GetNetVar("disappearance", nil) then return end

	local character = ent:IsRagdoll() and ent or hg.GetCurrentCharacter(ply)
	if not IsValid(character) then return end

	local name = ply:GetPlayerName()
	if not isstring(name) or name == "" then return end

	local bone = character:LookupBone("ValveBiped.Bip01_Head1")
	local matrix = bone and character:GetBoneMatrix(bone)
	local worldPos = (matrix and matrix:GetTranslation() or character:GetPos()) + tagHeadOffset
	local screen = worldPos:ToScreen()
	if not screen.visible then return end

	local pcol = ply.GetPlayerColor and ply:GetPlayerColor()
	local col = pcol and pcol:ToColor() or tagColor
	tagColor.r, tagColor.g, tagColor.b, tagColor.a = col.r, col.g, col.b, 255

	local dark = col.r < 50 and col.g < 50 and col.b < 50
	tagOutline.r, tagOutline.g, tagOutline.b, tagOutline.a = dark and 100 or 0, dark and 100 or 0, dark and 100 or 0, 255

	surface.SetFont(tagFont)
	local nameW, nameH = surface.GetTextSize(name)

	draw.SimpleTextOutlined(name, tagFont, screen.x, screen.y, tagColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, tagOutline)

	local events = ply.HGEventLog
	if not istable(events) or #events == 0 then return end

	local time = CurTime()

	for i = #events, 1, -1 do
		if time >= events[i].die then
			table.remove(events, i)
		end
	end

	local x = screen.x + nameW / 2 + tagGap
	local y = screen.y - nameH

	for i = 1, #events do
		local event = events[i]
		local alpha = math_Clamp((event.die - time) / eventFade, 0, 1) * math_Clamp((time - event.born) / fadeInTime, 0, 1)
		local clr = event.color

		eventColor.r, eventColor.g, eventColor.b, eventColor.a = clr.r, clr.g, clr.b, 255 * alpha
		tagOutline.a = 255 * alpha

		draw.SimpleTextOutlined(event.text, eventFont, x, y + (i - 1) * eventStep, eventColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, tagOutline)
	end
end)
