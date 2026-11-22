hg = hg or {}
hg.Dialect = hg.Dialect or {}
local D = hg.Dialect

local cipherPool = {"#", "%", "&", "@", "$", "*", "0", "1", "7", "X", "Z"}

local babble = {
	"npc/combine_soldier/vo/copythat.wav",
	"npc/combine_soldier/vo/prosecuting.wav",
	"npc/combine_soldier/vo/stayalert.wav",
	"npc/combine_soldier/vo/movein.wav",
	"npc/combine_soldier/vo/reportingclear.wav",
	"npc/combine_soldier/vo/containmentproceeding.wav",
	"npc/combine_soldier/vo/targetmyradial.wav",
	"npc/combine_soldier/vo/goactiveintercept.wav",
	"npc/combine_soldier/vo/heavyresistance.wav",
	"npc/combine_soldier/vo/engagedincleanup.wav"
}

function D.Knows(ply)
	local org = IsValid(ply) and ply.organism
	return org and org.dialectCombine and true or false
end

function D.Active(ply)
	local org = IsValid(ply) and ply.organism
	if not org or not org.dialectCombine then return "common" end

	return org.dialect == "combine" and "combine" or "common"
end

if CLIENT then
	hook.Add("radialOptions", "hg-dialect", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:GetNWBool("hg_dialect_known", false) then return end

		local current = ply:GetNWString("hg_dialect", "common")
		local nextDialect = current == "combine" and "common" or "combine"

		hg.radialOptions[#hg.radialOptions + 1] = {
			function()
				net.Start("hg_dialect_set")
					net.WriteString(nextDialect)
				net.SendToServer()

				return 0
			end,
			"Dialect: " .. (current == "combine" and "Combine" or "Common")
		}
	end)

	return
end

util.AddNetworkString("hg_dialect_set")

function D.Encrypt(text)
	local out = {}

	for _, code in utf8.codes(utf8.force(text or "")) do
		local ch = utf8.char(code)
		if ch:match("[%w]") or code > 127 then
			ch = cipherPool[math.random(#cipherPool)]
		end
		out[#out + 1] = ch
	end

	return table.concat(out)
end

function D.Set(ply, dialect)
	local org = IsValid(ply) and ply.organism
	if not org then return false end
	if dialect == "combine" and not org.dialectCombine then return false end

	org.dialect = dialect == "combine" and "combine" or "common"
	ply:SetNWString("hg_dialect", org.dialect)

	return true
end

net.Receive("hg_dialect_set", function(_, ply)
	local dialect = net.ReadString()
	if dialect ~= "combine" and dialect ~= "common" then return end
	if (ply.hgDialectNext or 0) > CurTime() then return end
	ply.hgDialectNext = CurTime() + 0.5

	if not D.Set(ply, dialect) then return end

	ply:Notify(dialect == "combine" and "You switch to the Combine dialect." or "You switch to the common tongue.", 3)
end)

timer.Create("hg_dialect_sync", 0.5, 0, function()
	for _, ply in player.Iterator() do
		local known = D.Knows(ply)
		if ply:GetNWBool("hg_dialect_known", false) ~= known then
			ply:SetNWBool("hg_dialect_known", known)
		end

		local active = D.Active(ply)
		if ply:GetNWString("hg_dialect", "common") ~= active then
			ply:SetNWString("hg_dialect", active)
		end
	end
end)

hook.Add("HG_PlayerCanHearPlayersVoice", "hg-dialect-voice", function(listener, speaker)
	if D.Active(speaker) ~= "combine" or not speaker:Alive() then return end
	if D.Knows(listener) then return end
	if listener == speaker then return end

	if speaker:IsSpeaking() and (speaker.hgDialectBabble or 0) < CurTime() then
		local snd = babble[math.random(#babble)]
		speaker.hgDialectBabble = CurTime() + math.max(SoundDuration(snd) or 0, 0.8) + 0.3
		speaker:EmitSound(snd, 70, speaker.VoicePitch or 100)
	end

	return false, false
end)
