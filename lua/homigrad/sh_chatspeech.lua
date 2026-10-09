HG_CHAT_SPEECH = HG_CHAT_SPEECH or {}
local CHAT_SPEECH = HG_CHAT_SPEECH
local soundPrefix = "panoptisscon/"
local letterInterval = 0.10
local maxLetters = 48

if CLIENT then
	CreateClientConVar("hg_otherspeech", "0", true, true, "Chat speech sounds: 0 - normal, 1 - speak1-2.ogg, 2 - newspeech", 0, 2)
end

if SERVER then
	for byte = string.byte("A"), string.byte("Z") do
		local path = soundPrefix .. string.char(byte) .. ".wav"
		resource.AddFile("sound/" .. path)
		util.PrecacheSound(path)
	end

	local function letterSound(ply, letter, index, count)
		local mode = ply:GetInfoNum("hg_otherspeech", 0)
		if mode == 1 then return "speak" .. math.random(1, 2) .. ".ogg" end
		if mode == 2 then
			local soundIndex = index == 1 and 1 or index == count and 15 or math.random(2, 14)

			return "newspeech/speak" .. soundIndex .. ".mp3"
		end
		return soundPrefix .. letter .. ".wav"
	end

	function CHAT_SPEECH:Speak(ply, text)
		if not IsValid(ply) or not ply:Alive() then return end

		local letters = {}
		for letter in string.gmatch(string.upper(text or ""), "[A-Z]") do
			letters[#letters + 1] = letter
			if #letters >= maxLetters then break end
		end
		if #letters == 0 then return end
		if #letters == 1 and ply:GetInfoNum("hg_otherspeech", 0) == 2 then letters[2] = letters[1] end

		local finishAt = CurTime() + #letters * letterInterval + 0.1
		local speech = {}
		ply.HGChatSpeech = speech
		ply.HGChatSpeechUntil = finishAt
		hook.Run("StartVoice", ply, ply)
		for index, letter in ipairs(letters) do
			timer.Simple((index - 1) * letterInterval, function()
				if IsValid(ply) and ply:Alive() and ply.HGChatSpeech == speech then
					if ply.HGChatSpeechSound then ply:StopSound(ply.HGChatSpeechSound) end
					ply.HGChatSpeechSound = letterSound(ply, letter, index, #letters)
					ply:EmitSound(ply.HGChatSpeechSound, 70, 100, 0.8, CHAN_VOICE)
				end
			end)
		end
		timer.Simple(#letters * letterInterval + 0.1, function()
			if IsValid(ply) and ply.HGChatSpeech == speech then
				ply.HGChatSpeech = nil
				ply.HGChatSpeechUntil = nil
				hook.Run("EndVoice", ply, ply)
			end
		end)
	end

	hook.Add("PlayerSay", "HG_ChatSpeech", function(ply, text)
		if ply.HGChatSpeechText == text and (ply.HGChatSpeechAt or 0) >= CurTime() then return end

		timer.Simple(0, function() CHAT_SPEECH:Speak(ply, text) end)
	end)
end
