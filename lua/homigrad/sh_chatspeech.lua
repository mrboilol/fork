HG_CHAT_SPEECH = HG_CHAT_SPEECH or {}
local CHAT_SPEECH = HG_CHAT_SPEECH
local soundPrefix = "panoptisscon/"
local letterInterval = 0.16
local maxLetters = 48

if SERVER then
	-- These sounds are emitted from the server, so explicitly ship and precache
	-- every letter instead of relying on clients already having this content.
	for byte = string.byte("A"), string.byte("Z") do
		local path = soundPrefix .. string.char(byte) .. ".wav"
		resource.AddFile("sound/" .. path)
		util.PrecacheSound(path)
	end

	function CHAT_SPEECH:Speak(ply, text)
		if not IsValid(ply) or not ply:Alive() then return end

		local letters = {}
		for letter in string.gmatch(string.upper(text or ""), "[A-Z]") do
			letters[#letters + 1] = letter
			if #letters >= maxLetters then break end
		end
		if #letters == 0 then return end

		-- Keep generated letter speech in the same lifecycle as live voice.
		local finishAt = CurTime() + #letters * letterInterval + 0.1
		ply.HGChatSpeechUntil = math.max(ply.HGChatSpeechUntil or 0, finishAt)
		hook.Run("StartVoice", ply, ply)
		for index, letter in ipairs(letters) do
			timer.Simple((index - 1) * letterInterval, function()
				if IsValid(ply) and ply:Alive() then
					ply:EmitSound(soundPrefix .. letter .. ".wav", 70, 100, 0.8, CHAN_VOICE)
				end
			end)
		end
		timer.Simple(#letters * letterInterval + 0.1, function()
			if IsValid(ply) and (ply.HGChatSpeechUntil or 0) <= CurTime() then
				ply.HGChatSpeechUntil = nil
				hook.Run("EndVoice", ply, ply)
			end
		end)
	end

	hook.Add("PlayerSay", "HG_ChatSpeech", function(ply, text)
		-- ZChat calls Speak directly before its PlayerSay hook; skip the duplicate.
		if ply.HGChatSpeechText == text and (ply.HGChatSpeechAt or 0) >= CurTime() then return end

		timer.Simple(0, function() CHAT_SPEECH:Speak(ply, text) end)
	end)
end