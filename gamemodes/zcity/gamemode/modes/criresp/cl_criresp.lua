local MODE = MODE
MODE.name = "criresp"
local submode = "sobr"
local swatDeploymentTime = 0
local modeSound
local introDuration = 10
local victoryDuration = 6
local victoryScreenDuration = victoryDuration
local soundGeneration = 0
local introChannel
local introReady = false
local introPending = false
local introGeneration = 0

local function StopIntro()
	introGeneration = introGeneration + 1
	introReady = false
	introPending = false
	if IsValid(introChannel) then
		introChannel:Stop()
		introChannel = nil
	end
end

local function StartIntro()
	local channel = introChannel
	if not IsValid(channel) then
		PreloadIntro(true)
		return
	end
	if not introReady then
		introPending = true
		return
	end

	channel:SetTime(0)
	channel:Play()
	local gen = introGeneration
	local trackDuration = channel:GetLength()
	if not isnumber(trackDuration) or trackDuration <= 0 then
		trackDuration = introDuration
	end
	timer.Simple(trackDuration, function()
		if gen ~= introGeneration then return end
		if introChannel == channel and IsValid(channel) then
			channel:Stop()
			introChannel = nil
			introReady = false
		end
	end)
end

local function PreloadIntro(autoPlay)
	introGeneration = introGeneration + 1
	local gen = introGeneration
	introReady = false
	if IsValid(introChannel) then
		introChannel:Stop()
		introChannel = nil
	end
	introPending = autoPlay or introPending

	sound.PlayFile("sound/Crirespstart.mp3", "noplay noblock", function(channel)
		if gen ~= introGeneration then
			if IsValid(channel) then channel:Stop() end
			return
		end
		if not IsValid(channel) then
			introPending = false
			return
		end

		introChannel = channel
		introReady = true
		if introPending then
			introPending = false
			StartIntro()
		end
	end)
end

local function PlayModeSound(path, duration, playToEnd, onReady)
	soundGeneration = soundGeneration + 1
	local generation = soundGeneration
	if IsValid(modeSound) then modeSound:Stop() end

	sound.PlayFile("sound/" .. path, "noplay noblock", function(channel)
		if generation ~= soundGeneration then
			if IsValid(channel) then channel:Stop() end
			return
		end
		if not IsValid(channel) then return end

		modeSound = channel
		channel:Play()
		local fileDuration = channel:GetLength()
		if not isnumber(fileDuration) or fileDuration <= 0 then fileDuration = duration end
		if onReady then onReady(fileDuration) end

		timer.Simple(playToEnd and fileDuration or duration, function()
			if modeSound ~= channel then return end
			if not playToEnd and IsValid(channel) then channel:Stop() end
			modeSound = nil
		end)
	end)
end

net.Receive("criresp_start", function()
	submode = net.ReadString() or "sobr"
	swatDeploymentTime = CurTime() + net.ReadUInt(7)
	StopIntro()
	PreloadIntro()
end)

local function TeamInfo(team_)
	if team_ == 1 then
		return {
			objective = "This is my fucking house, bitches, I can do what I want.",
			name = submode == "us" and "an Armed Robber" or "a Chechen Terrorist",
			color1 = Color(228, 49, 49),
			color2 = Color(228, 49, 49)
		}
	end
	return {
		objective = "Negotiations failed, eliminate the threat. 10-4",
		name = submode == "sobr" and "an SOBR Operator" or "a US Special Forces Operator",
		color1 = Color(68, 10, 255),
		color2 = Color(68, 10, 255)
	}
end

function MODE:RenderScreenspaceEffects()
	if (menuShownAt or 0) + 1 < CurTime() then
		zb.RemoveFade()
	end

	if zb.ROUND_BEGIN + 85 < CurTime() then
		if songfade <= 0.01 and IsValid(song) then
			song:Stop()
			song = nil
			surface.PlaySound(lply:Team() == 0 and "zbattle/criresp/barricadedsuspectstart.mp3" or "snd_jack_hmcd_policesiren.wav")
		elseif IsValid(song) then
			songfade = Lerp(0.01, songfade, 0)
			song:SetVolume(songfade)
		end
	end
end

function MODE:HUDPaint()
	if endStats then
		local t = CurTime() - endStats.start

		if t < 14 then
			if IsValid(MENUPANELHUYHUY) then MENUPANELHUYHUY:Remove() end

			local alpha = 255 * math.Clamp(t / 2, 0, 1)

			surface.SetDrawColor(0, 0, 0, alpha)
			surface.DrawRect(-1, -1, sw + 2, sh + 2)

			if t > 2 then
				local textAlpha = math.min(alpha, 255 * math.Clamp((t - 2) / 0.7, 0, 1))
				if t > 6.5 then
					textAlpha = textAlpha * math.Clamp(1 - (t - 6.5) / 1.5, 0, 1)
				end

				local title, titleCol
				if endStats.winner == 1 then
					local clean = endStats.arrested + endStats.incap
					local ratio = endStats.total > 0 and clean / endStats.total or 0

					if ratio >= 0.7 then
						title, titleCol = "MISSION ACCOMPLISHED", Color(90, 200, 90)
					elseif ratio >= 0.35 then
						title, titleCol = "SLOPPY MISSION", Color(230, 190, 60)
					else
						title, titleCol = "DISASTROUS MISSION", Color(235, 120, 45)
					end
				elseif endStats.winner == 2 then
					title, titleCol = "MISSION FAILED", criRed
				else
					title, titleCol = "OPERATION OVER", criDim
				end

				draw.SimpleText("CRISIS RESPONSE", "CRI_Med", sw * 0.5, sh * 0.14, ColorAlpha(criRedDark, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(title, "CRI_Title", sw * 0.5, sh * 0.32, ColorAlpha(titleCol, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				draw.SimpleText("SUSPECTS KILLED: " .. endStats.killed .. " / " .. endStats.total, "CRI_Med", sw * 0.5, sh * 0.48, ColorAlpha(criWhite, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("INCAPACITATED: " .. endStats.incap, "CRI_Med", sw * 0.5, sh * 0.55, ColorAlpha(criWhite, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("ARRESTED: " .. endStats.arrested, "CRI_Med", sw * 0.5, sh * 0.62, ColorAlpha(criWhite, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		else
			endStats = nil
		end

		return
	end

	if beginAt then
		local t = CurTime() - beginAt

		if t < 9.5 then
			local alpha = 255 * math.Clamp(t / 0.35, 0, 1)
			if t > 6.5 then
				alpha = 255 * math.Clamp(1 - (t - 6.5) / 2.5, 0, 1)
			end

			surface.SetDrawColor(0, 0, 0, alpha)
			surface.DrawRect(-1, -1, sw + 2, sh + 2)

			if t > 1.5 then
				local info = teams[lply:Team()] or spectatorInfo
				local textAlpha = math.min(alpha, 255 * math.Clamp((t - 1.5) / 0.7, 0, 1))

				draw.SimpleText("CRISIS RESPONSE", "CRI_Title", sw * 0.5, sh * 0.12, ColorAlpha(criRed, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("YOU ARE " .. info.name, "CRI_Title", sw * 0.5, sh * 0.5, ColorAlpha(info.color, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(info.objective, "CRI_Med", sw * 0.5, sh * 0.6, ColorAlpha(criWhite, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		else
			beginAt = nil
		end

		return
	end

	if zb.ROUND_BEGIN + 90 > CurTime() and zb.ROUND_BEGIN < CurTime() then
		local color = Color(255 * -math.sin(CurTime() * 3), 25, 255 * math.sin(CurTime() * 3))
		local text = "SWAT will arrive in: " .. string.FormattedTime(zb.ROUND_BEGIN + 90 - CurTime(), "%02i:%02i")
		draw.SimpleText(text, "CRI_Med", sw * 0.02, sh * 0.95, Color(0, 0, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(text, "CRI_Med", sw * 0.02 - 2, sh * 0.95 - 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

local endWinner = nil
local endStart = 0

net.Receive("cri_roundend", function()
	endWinner = net.ReadBool() and 1 or 0
	endStart = CurTime()
	swatDeploymentTime = 0
	victoryScreenDuration = victoryDuration
	PlayModeSound("Crirespwin.mp3", victoryDuration, true, function(fileDuration)
		victoryScreenDuration = math.max(victoryDuration, fileDuration)
	end)
end)

surface.CreateFont("ZB_CrirespHeader", {
	font = "ITC Avant Garde Gothic",
	size = math.floor(ScrH() * 0.08),
	weight = 700,
	antialias = true,
	extended = true
})

surface.CreateFont("ZB_CrirespMediumLarge", {
	font = "ITC Avant Garde Gothic",
	size = math.floor(ScrH() * 0.04),
	weight = 700,
	antialias = true,
	extended = true
})

function MODE:HUDPaint()
	local preparationLeft = math.max(math.ceil(swatDeploymentTime - CurTime()), 0)
	local introFinished = CurTime() >= (zb.ROUND_START or 0) + introDuration
	if introFinished and preparationLeft > 0 and IsValid(lply) and lply:Team() ~= TEAM_SPECTATOR then
		local label = lply:Team() == 1 and "PREPARE FOR THE ASSAULT" or "DEPLOYMENT IN"
		draw.SimpleText(label .. ": " .. string.FormattedTime(preparationLeft, "%02i:%02i"), "ZB_CrirespMediumLarge", ScrW() * 0.5, ScrH() * 0.12, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if zb.ROUND_START + introDuration > CurTime() then
		if IsValid(lply) and lply:Team() ~= TEAM_SPECTATOR then
			local info = TeamInfo(lply:Team())
			hg.RoundStart.DrawTitle({
				header = "Crisis Response",
				lines = {
					{text = "You are " .. info.name, color = info.color1, font = "ZB_HomicideMediumLarge"}
				},
				objective = info.objective
			}, {startTime = zb.ROUND_START, duration = introDuration})
		end
	end

	if endStart > 0 then
		local t = CurTime() - endStart
		if t < victoryScreenDuration then
			local ina = math.Clamp(t / 0.4, 0, 1)
			local outa = math.Clamp((victoryScreenDuration - t) / 0.6, 0, 1)
			local a = 255 * ina * outa
			local title, titleCol, teamName
			if endWinner == 1 then
				title = "CRIMINALS WIN"
				titleCol = Color(228, 49, 49, a)
				teamName = submode == "us" and "ARMED ROBBERS" or "CHECHEN TERRORISTS"
			else
				title = "SWAT VICTORY"
				titleCol = Color(68, 10, 255, a)
				teamName = submode == "us" and "US SPECIAL FORCES" or "SOBR OPERATORS"
			end
			draw.SimpleText(title, "ZB_CrirespHeader", sw * 0.5, sh * 0.3, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(teamName, "ZB_CrirespMediumLarge", sw * 0.5, sh * 0.3 + ScreenScale(45), Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			endStart = 0
		end
	end

	if hg.PluvTown.Active then
		local fade = math.Clamp(zb.ROUND_START + 10 - CurTime(), 0, 1)
		surface.SetMaterial(hg.PluvTown.PluvMadness)
		surface.SetDrawColor(255, 255, 255, math.random(175, 255) * fade / 2)
		surface.DrawTexturedRect(sw * 0.25, sh * 0.44 - ScreenScale(15), sw / 2, ScreenScale(30))

		draw.SimpleText("SOMEWHERE IN PLUVTOWN", "ZB_ScrappersLarge", sw / 2, sh * 0.44 - ScreenScale(2), Color(0, 0, 0, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function MODE:RoundStart()
	endStart = 0
	endWinner = nil
	StartIntro()
end
