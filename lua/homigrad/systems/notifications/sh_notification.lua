local hg_furcity = ConVarExists("hg_furcity") and GetConVar("hg_furcity") or CreateConVar("hg_furcity", 0, bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_LUA_SERVER), "Toggle phrase furryfier :3", 0, 1)

hg.fur = {
	" rawr~",
	" mrrrph~~",
	" meow :3",
	" uwu",
	" >w<",
	" OwO",
	" ^w^",
	" *blushes*",
	" -w-",
	" ~w~",
	" mrrawr~~",
	" mrrp~",
	" mrreow~",
	" mwah~",
	"~",
	"~~"
}

local translateSymbol = {
	["r"] = "w",
	["R"] = "W",
	["l"] = "w",
	["L"] = "W",
	["з"] = "в",
	["З"] = "В",
	["ш"] = "ф",
	["Ш"] = "Ф",
	--["ч"] = "т",
	--["Ч"] = "Т",
	--["у"] = "ю",
	--["У"] = "Ю",
	--["т"] = "в",
	--["Т"] = "В",
}

local repeating = {
	["r"] = true,
	["R"] = true,
	["р"] = true,
	["Р"] = true,
}

// можно сделать чтобы оно просто брало стринг, текущее местоположение буквы и добавляло ещё сверху
//



function hg.FurrifyPhrase(msg)
	local iter = utf8.codes(msg)
	local len = 0
	local chars = {}

	for i, code in iter do
		len = len + 1
		chars[len] = utf8.char(code)
	end

	-- local lastpos = 0
	-- while lastpos != -1 do
	--     local newpos = string.find(msg, "[rR]", lastpos)

	-- end


	--i нельзя менять
	for i = #chars, 1, -1 do
		if repeating[chars[i]] and math.random(2) == 1 then
			for i2 = 1, math.random(3) do
				table.insert(chars, i, chars[i])
			end
		elseif translateSymbol[chars[i]] and math.random(2) == 1 then
			chars[i] = translateSymbol[chars[i]]
		end
	end--legendary

	msg = table.concat(chars)

	if math.random(4) == 1 then
		msg = msg..hg.fur[math.random(#hg.fur)]
	end

	return msg
end

if SERVER then
	for i = 1, 15 do
		resource.AddFile("sound/newspeech/speak" .. i .. ".mp3")
	end
end

if CLIENT then
	local hg_omori = CreateClientConVar("hg_omori", "1", true, false, "Thought sounds: 0 - old, 1 - new", 0, 1)
	local hg_old_notificate = ConVarExists("hg_old_notificate") and GetConVar("hg_old_notificate") or CreateConVar("hg_old_notificate",0,{FCVAR_USERINFO,FCVAR_ARCHIVE},"Toggle old notifications (chatprints)",0,1)
	local hg_newthoughts = ConVarExists("hg_newthoughts") and GetConVar("hg_newthoughts") or CreateClientConVar("hg_newthoughts", "0", true, true, "Toggle new stacked injury thoughts", 0, 1)

	local registerFont = hg.RegisterUIFont or function(name, definition)
		definition = table.Copy(definition)
		definition.size = math.max(1, math.floor((definition.referenceSize or definition.size) * math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.65, 1.5) + 0.5))
		definition.referenceSize = nil
		surface.CreateFont(name, definition)
	end

	registerFont("BerserkFont", {
		font = "Who asks Satan",
		referenceSize = 56,
		extended = true,
		weight = 400,
		antialias = true,
	})

	registerFont("HuyFont", {
		font = "BudgetLabel",
		extended = true,
		referenceSize = 18,
		weight = 0,
		blursize = 0,
		scanlines = 0,
		antialias = true,
		strikeout = false,
		shadow = false,
		outline = false,
	})

	registerFont("SmallHuyFont", {
		font = "BudgetLabel",
		extended = true,
		referenceSize = 16,
		weight = 0,
		blursize = 0,
		scanlines = 0,
		antialias = true,
		strikeout = false,
		shadow = false,
		outline = false,
	})

	registerFont("ThoughtFont", {
		font = "BudgetLabel",
		extended = true,
		referenceSize = 25,
		weight = 0,
		blursize = 0,
		scanlines = 0,
		antialias = true,
		strikeout = false,
		shadow = false,
		outline = false,
	})

	hg.notifications = hg.notifications or {}
	hg.thoughts = hg.thoughts or {}
	hg.notificationFont = "HuyFont"
	local thoughtSound
	local oldclick = 0
	local oldNotification

	local function StopThoughtSound()
		if thoughtSound then thoughtSound:Stop() end
		thoughtSound = nil
		oldclick = 0
		oldNotification = nil
	end

	cvars.AddChangeCallback("hg_newthoughts", function()
		StopThoughtSound()
		hg.currentNotification = nil
		hg.notifications = {}
		hg.thoughts = {}
	end, "hg_clear_notification_mode_switch")

	hook.Add("Player_Death","removeNotifications",function(ply)
		if ply != lply then return end
		StopThoughtSound()

		//hg.currentNotification = nil
		hg.notifications = {}
		hg.thoughts = {}
	end)

	hook.Add("Player Spawn","removeNotificationsa",function(ply)
		if ply != lply then return end
		StopThoughtSound()

		hg.currentNotification = nil
		hg.notifications = {}
		hg.thoughts = {}
	end)

	hook.Add("HG_OnOtrub","removeNotificationsb",function(ply)
		if ply != lply then return end
		StopThoughtSound()

		//hg.currentNotification = nil
		hg.notifications = {}
		hg.thoughts = {}
	end)

	local defaultShowTimer = 3

	local function CreateNotification(msg, showTimer, clr, priority)
		if hg_furcity:GetBool() or lply.PlayerClassName == "furry" then
			msg = hg.FurrifyPhrase(msg)
		end

		if lply:IsBerserk() then
			return
		end

		priority = priority or 0
		local current = hg.currentNotification
		if current and priority > (current[5] or 0) then
			StopThoughtSound()
			if priority == 110 then
				local elapsed = math.max(CurTime() - current[2], 0)
				local speed = 0.06 * ((lply.organism and lply.organism.brain or 0) > 0.1 and 3 or 1)
				local visible = math.min(math.ceil(elapsed / speed), utf8.len(current[1]))
				if visible > 0 and visible < utf8.len(current[1]) then
					msg = utf8.sub(current[1], 1, visible) .. "-" .. msg
				end
			else
				table.insert(hg.notifications, 1, {current[1], current[3], current[4], current[5] or 0})
			end
			hg.currentNotification = nil
		end
		local notification = {msg, (showTimer or defaultShowTimer), clr or Color(255, 255, 255, 255), priority}
		local index = #hg.notifications + 1
		for i, queued in ipairs(hg.notifications) do
			if notification[4] > (queued[4] or 0) then index = i break end
		end
		table.insert(hg.notifications, index, notification)
	end

	local function CreateNotificationBerserk(msg, showTimer, clr)
		StopThoughtSound()
		if hg_furcity:GetBool() or lply.PlayerClassName == "furry" then
			msg = hg.FurrifyPhrase(msg) -- uhhhh... hate to break it to you but-
		end

		local tbl = hg.currentNotification

		local clr = tbl and tbl[4] and IsColor(tbl[4]) and tbl[4] or Color(255, 255, 255, 255)
		if tbl and clr and tbl[1] then
			chat.AddText(Color(clr.r, clr.g, clr.b, 255), (last_message or tbl[1]).."\n")
		end

		hg.currentNotification = nil
		hg.notifications = {}

		table.insert(hg.notifications, {msg, (showTimer or defaultShowTimer), clr or Color(255, 255, 255, 255)})
	end

	local function CreateThought(msg, clr, group)
		if not hg_newthoughts:GetBool() then return end
		if lply:IsBerserk() then return end

		local now = CurTime()
		for _, thought in ipairs(hg.thoughts) do
			if thought[1] == msg and now - (thought[2] or 0) < 18 then return end
		end
		if group == "combat" or group == "faint" then
			for _, thought in ipairs(hg.thoughts) do
				chat.AddText(Color(thought[3].r, thought[3].g, thought[3].b, 255), thought[1] .. "\n")
			end
			hg.thoughts = {}
		elseif group then
			for i = #hg.thoughts, 1, -1 do
				if hg.thoughts[i][4] == group then table.remove(hg.thoughts, i) end
			end
		end
		table.insert(hg.thoughts, {msg, now, clr or Color(255, 255, 255, 255), group})

		while #hg.thoughts > 3 do
			local tbl = hg.thoughts[1]
			local clr = tbl[3]
			chat.AddText(Color(clr.r, clr.g, clr.b, 255), tbl[1] .. "\n")
			table.remove(hg.thoughts, 1)
		end
	end

	local PLAYER = FindMetaTable("Player")

	function PLAYER:Notify(...)
		return CreateNotification(...)
	end

	function PLAYER:NotifyBerserk(...)
		return CreateNotificationBerserk(...)
	end

	function PLAYER:Thought(...)
		return CreateThought(...)
	end

	net.Receive("HGNotificate",function()
		local msg = net.ReadString()
		local clr = net.ReadColor()
		local priority = net.ReadUInt(7)

		if msg == "" then return end

		CreateNotification(msg, showtime, clr, priority)
	end)

	net.Receive("HGNotificateBerserk",function()
		local msg = net.ReadString()
		local clr = net.ReadColor()

		if msg == "" then return end

		CreateNotificationBerserk(msg, showtime, clr)
	end)

	net.Receive("HGThought",function()
		local msg = net.ReadString()
		local clr = net.ReadColor()
		local group = net.ReadString()

		if msg == "" then return end
		if not hg_newthoughts:GetBool() then return end

		CreateThought(msg, clr, group != "" and group or nil)
	end)

	hg.CreateNotification = CreateNotification
	hg.CreateNotificationBerserk = CreateNotificationBerserk
	hg.CreateThought = CreateThought
	local colred = Color(255,0,0)

	local time_spent = CurTime()
	local coloruse = Color(255,255,255,255)
	local function NotificationsThink()
		//if hg.currentNotification or #hg.notifications == 0 then return end
		if #hg.notifications == 0 then return end
		if hg.currentNotification then return end
		if !lply:Alive() then hg.notifications = {} return end
		if lply.organism and lply.organism.otrub then return end
		local tbl = hg.notifications[1]

		if tbl and istable(tbl) and not table.IsEmpty(tbl) then
			/*if hg.currentNotification then
				local tbl2 = hg.currentNotification

				local clr = tbl2 and tbl2[4] and IsColor(tbl2[4]) and tbl2[4] or Color(255, 255, 255, 255)
				if tbl2 and clr and tbl2[1] then
					chat.AddText(Color(coloruse.r, coloruse.g, coloruse.b, 255), (last_message or tbl2[1]).."\n")
				end

				hg.currentNotification = nil
			end*/

			hg.currentNotification = {tbl[1], time_spent, tbl[2], tbl[3], tbl[4]}

			table.remove(hg.notifications,1)
		end--показываем только одну нотификацию за раз (остальные держим в уме....)
	end

	local colBrown = Color(40,40,40)
	local ColorNotification = Color(48,4,4,0)
	local maxtimefade = 1

	local last_message
	local last_time

	local vector_one = Vector( 1, 1, 0)

	local bluewhite = Color(187, 187, 255)
	local function GetThoughtInstability(org)
		local o2 = istable(org.o2) and (tonumber(org.o2[1]) or 30) or 30
		local oxygen = math.Clamp((18 - o2) / 18, 0, 1)
		local blood = math.Clamp((4300 - (tonumber(org.blood) or 5000)) / 1300, 0, 1)
		local consciousness = math.Clamp((0.65 - (tonumber(org.consciousness) or 1)) / 0.65, 0, 1)
		local brainOxygen = math.Clamp((0.55 - (tonumber(org.brainoxygen) or 1)) / 0.55, 0, 1)
		return math.max(oxygen, blood * 0.8, consciousness, brainOxygen)
	end

	local function GetThoughtRedness(instability)
		return math.Clamp(instability, 0, 1) ^ 0.75 * 0.85
	end

	local function GetThoughtShake(instability)
		return instability * 4 + instability ^ 2 * 12
	end

	local function NotificationsDraw()
		time_spent = CurTime()
		lply = LocalPlayer()
		local org = lply.organism
		if not org or not org.pain or not org.brain then return end
		//if org.otrub and !last_message then return end

		//if hg_old_notificate:GetBool() then return end
		local tbl = hg.currentNotification

		if tbl and istable(tbl) and not table.IsEmpty(tbl) then
			if oldNotification != tbl then
				StopThoughtSound()
				oldNotification = tbl
			end
			local msg, time, timeshow, clr = tbl[1], tbl[2], tbl[3], tbl[4]

			local mul = org.brain > 0.1 and 3 or 1
			local time_one_symbol = 0.06 * mul
			local time_to_read = (utf8.len(msg) * time_one_symbol)
			local wait = math.Clamp(time_to_read / 3 * math.Clamp(1 - #hg.notifications / 1, 0.25, 1), 1, 4) + timeshow

			if (time + time_to_read + wait > time_spent) then
				local part = math.min(1 - (time + time_to_read - time_spent) / time_to_read, 1)
				local part2 = (wait + math.min(time + time_to_read - time_spent, 0)) / wait

				local click = math.ceil(part * utf8.len(msg))

				if not last_message and utf8.len(msg) != click and utf8.sub(utf8.force(msg), click, click) == "." then
					tbl[2] = tbl[2] + FrameTime() / 1.5
				end

				if click != oldclick and not last_message then
					local isThoughtStart = oldclick == 0
					local soundIndex = isThoughtStart and 1 or click == utf8.len(msg) and 15 or math.random(2, 14)
					local snd = hg_omori:GetBool() and "newspeech/speak" .. soundIndex .. ".mp3" or "speak" .. math.random(1, 2) .. ".ogg"
					if thoughtSound then thoughtSound:Stop() end
					thoughtSound = CreateSound(lply, snd)
					thoughtSound:SetSoundLevel(0)
					thoughtSound:PlayEx(hg_omori:GetBool() and 0.35 or 0.8, math.random(97, 103))
					oldclick = hg_omori:GetBool() and isThoughtStart and click == utf8.len(msg) and -1 or click
				end

				local txt = utf8.sub(utf8.force(msg), 1, click)

				coloruse.r = clr.r
				coloruse.g = math.min(math.Clamp(((90 - org.pain) / 90) * 255, 0, 255), clr.g)
				coloruse.b = math.min(math.Clamp(((90 - org.pain) / 90) * 255, 0, 255), clr.g)

				local instability = GetThoughtInstability(org)
				local redness = GetThoughtRedness(instability)
				coloruse.r = Lerp(redness, coloruse.r, 255)
				coloruse.g = Lerp(redness, coloruse.g, 25)
				coloruse.b = Lerp(redness, coloruse.b, 25)

				if (org.otrub or !lply:Alive()) then
					if not last_message then
						txt = utf8.sub(txt, utf8.len(txt), utf8.len(txt)) == utf8.force(" ") and utf8.sub(txt, 1, utf8.len(txt) - 1) or txt
						last_message = txt..(click != utf8.len(msg) and "-" or "")
						last_time = time_spent
						tbl[4] = Color(coloruse.r, coloruse.g, coloruse.b, 255)
					end
				else
					last_message = nil
					last_time = nil
				end

				local font = hg.notificationFont

				surface.SetFont(font)
				local txtw, txth = surface.GetTextSize(last_message or txt)

				local col = coloruse
				col.a = 255 * (last_time and (last_time + 2 - time_spent) or part2)
				colBrown.a = 255 * (last_time and (last_time + 2 - time_spent) or part2)

				if hg.underberserk2 then
					local scale = 1

					scale = (1 + ((hg.berserkIntensity or 0) / 4))

					local rand = org.berserk * 2 * (col.a / 255)

					local uiScale = hg.UIScale and hg.UIScale() or 1
					local x, y = ScrW() / 2 + math.Rand(-rand, rand) * uiScale, ScrH() - 180 * uiScale + math.Rand(-rand, rand) * uiScale

					local m = Matrix()
					m:Translate( Vector( x, y, 0 ) )
					m:Scale( vector_one * ( scale or 3) )
					m:Translate( Vector( -txtw / 2, 0, 0 ) )

					col.r = col.r + math.min(1, hg.berserkIntensity) * 255
					col.g = col.g - math.min(1, hg.berserkIntensity) * 200
					col.b = col.b - math.min(1, hg.berserkIntensity) * 200

					render.PushFilterMag( TEXFILTER.ANISOTROPIC )

					cam.PushModelMatrix( m, true )
					DisableClipping(true)
						local col2
						for i = 1, 40 do // erm maybe 40 is too much? idk i don't care :3 :3 :3
							col2 = HSVToColor(350 + (math.sin(SysTime() + i / 50) * 10 * hg.berserkIntensity), 0.8, 0.9)
							local posX = -math.sin(RealTime() * 7) * i / 2 * hg.berserkIntensity
							local posY = -math.cos(RealTime() * 7) * i / 2 * hg.berserkIntensity
							draw.SimpleText(last_message or txt, font, posX, posY, ColorAlpha(col2, col.a - i * 5), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						end

						draw.GlowingText(last_message or txt, font, 0, 0, ColorAlpha(col2, col.a), ColorAlpha(col2, math.min(col.a, 50)), ColorAlpha(col2, math.min(col.a, 10)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						-- draw.SimpleTextOutlined(last_message or txt, font, 0, 0, ColorAlpha(col, col.a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, colBrown)
					DisableClipping(false)
					cam.PopModelMatrix()

					render.PopFilterMag()
				elseif lply.PlayerClassName == "furry" then
					local shake = GetThoughtShake(instability)
					local uiScale = hg.UIScale and hg.UIScale() or 1
					local x, y = ScrW() / 2 - txtw / 2 + (math.Rand(0, org.pain > 10 and org.pain / 10 or 0) + math.Rand(0, (255 - clr.g) / 255 * 2) + math.Rand(-shake, shake)) * uiScale, ScrH() - 180 * uiScale + (math.Rand(0, org.pain > 10 and org.pain / 10 or 0) + math.Rand(0, (255 - clr.g) / 255 * 2) + math.Rand(-shake, shake)) * uiScale

					draw.SimpleText(last_message or txt, "ZB_ProotOSMedium", x + 2, y + 2, ColorAlpha(color_black, col.a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(last_message or txt, "ZB_ProotOSMedium", x, y, ColorAlpha(bluewhite, col.a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				else
					local shake = GetThoughtShake(instability)
					local uiScale = hg.UIScale and hg.UIScale() or 1
					local x, y = ScrW() / 2 - txtw / 2 + (math.Rand(0, org.pain > 10 and org.pain / 10 or 0) + math.Rand(0, (255 - clr.g) / 255 * 2) + math.Rand(-shake, shake)) * uiScale, ScrH() - 180 * uiScale + (math.Rand(0, org.pain > 10 and org.pain / 10 or 0) + math.Rand(0, (255 - clr.g) / 255 * 2) + math.Rand(-shake, shake)) * uiScale

					draw.SimpleTextOutlined(last_message or txt, font, x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1.5, colBrown)
				end
			else
				local tbl = hg.currentNotification

				local clr = tbl and tbl[4] and IsColor(tbl[4]) and tbl[4] or Color(255, 255, 255, 255)
				if tbl and clr and tbl[1] then
					//MsgC(Color(clr.r, clr.g, clr.b, 255), (last_message or tbl[1]).."\n")
					chat.AddText(Color(clr.r, clr.g, clr.b, 255), (last_message or tbl[1]).."\n")
				end

				last_message = nil
				last_time = nil

				hg.currentNotification = nil
			end
		end
	end

	local thoughtBrown = Color(20, 20, 20)
	local function ThoughtsDraw()
		if not hg_newthoughts:GetBool() then return end
		if #hg.thoughts == 0 then return end
		if not lply:Alive() then hg.thoughts = {} return end

		local time = CurTime()
		local duration = 4.5
		local fade = 0.6
		local org = LocalPlayer().organism
		local instability = org and GetThoughtInstability(org) or 0
		local shake = GetThoughtShake(instability)
		local redness = GetThoughtRedness(instability)

		for i = #hg.thoughts, 1, -1 do
			local tbl = hg.thoughts[i]
			local delta = time - tbl[2]

			if delta >= duration then
				local clr = tbl[3]
				chat.AddText(Color(clr.r, clr.g, clr.b, 255), tbl[1] .. "\n")
				table.remove(hg.thoughts, i)
			else
				local clr = tbl[3]
				local alpha = math.min(delta / fade, 1, (duration - delta) / fade) * 255
				local uiScale = hg.UIScale and hg.UIScale() or 1
				local y = ScrH() - 270 * uiScale - (i - 1) * 32 * uiScale

				thoughtBrown.a = alpha
				draw.SimpleTextOutlined(tbl[1], "ThoughtFont", ScrW() / 2 + math.Rand(-shake, shake), y + math.Rand(-shake, shake), Color(Lerp(redness, clr.r, 255), Lerp(redness, clr.g, 25), Lerp(redness, clr.b, 25), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, thoughtBrown)
			end
		end
	end

	hook.Add("DrawOverlay", "HGNotificationsThink", function()
		NotificationsDraw()
		ThoughtsDraw()
	end)
	hook.Add("Think", "HGNotificationsThink", NotificationsThink)
else
	concommand.Add("hg_notify", function(ply, cmd, args)
		if not ply:IsAdmin() then return end
		for i, ply in pairs(player.GetListByName(args[1])) do
			//(ply, msg, delay, msgKey, showTime, func, clr)
			ply:Notify(args[2], 6, nil, 0, nil, Color(args[3] or 255, args[4] or 255, args[5] or 255))
		end
	end)
end
