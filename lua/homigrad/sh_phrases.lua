phrases = {
	[1] = {
		{"vo/npc/male01/question", ".ogg", 3, 31},
		{"vo/npc/male01/answer", ".ogg", 1, 40},
		{"vo/npc/male01/sorry", ".ogg", 1, 3},
		{"vo/npc/male01/squad_affirm", ".ogg", 1, 9},
		{"vo/episode_1/npc/male01/cit_remarks", ".ogg", 1, 21},
		{"vo/trainyard/male01/cit_bench", ".ogg", 1, 4},
		{"vo/trainyard/male01/cit_hit", ".ogg", 1, 5},
		{"vo/trainyard/male01/cit_pedestrian", ".ogg", 1, 5},
		{"vo/outland_11a/silo/reb1_idles", ".ogg", 1, 7},
		{"vo/npc/male01/hi", ".ogg", 1, 2},
		//{"vo/npc/male01/startle", ".ogg", 1, 2},
		{"vo/npc/male01/vanswer", ".ogg", 1, 14},
		//{"vo/npc/male01/wetrustedyou", ".ogg", 1, 2},
		//{"vo/npc/male01/whoops", ".ogg", 1, 1},
		//{"vo/npc/male01/yeah", ".ogg", 2, 2},
		//{"vo/npc/male01/gordead_ans", ".ogg", 1, 20},
		//{"vo/npc/male01/heretohelp", ".ogg", 1, 2},
		{"vo/npc/male01/holddownspot", ".ogg", 1, 2},
		{"vo/npc/male01/imstickinghere", ".ogg", 1, 1},
	},
	[2] = {
		{"vo/npc/female01/question", ".ogg", 3, 30},
		{"vo/npc/female01/answer", ".ogg", 1, 40},
		{"vo/npc/female01/sorry", ".ogg", 1, 3},
		{"vo/npc/female01/squad_affirm", ".ogg", 1, 9},
		{"vo/episode_1/npc/female01/cit_remarks", ".ogg", 1, 21},
		{"vo/trainyard/female01/cit_bench", ".ogg", 1, 4},
		{"vo/trainyard/female01/cit_hit", ".ogg", 1, 5},
		{"vo/trainyard/female01/cit_pedestrian", ".ogg", 1, 5},
		{"vo/npc/female01/hi", ".ogg", 1, 2},
		//{"vo/npc/female01/startle", ".ogg", 1, 2},
		{"vo/npc/female01/vanswer", ".ogg", 1, 14},
		//{"vo/npc/female01/wetrustedyou", ".ogg", 1, 2},
		//{"vo/npc/female01/whoops", ".ogg", 1, 1},
		//{"vo/npc/female01/yeah", ".ogg", 2, 2},
		//{"vo/npc/female01/gordead_ans", ".ogg", 1, 20},
		//{"vo/npc/female01/heretohelp", ".ogg", 1, 2},
		{"vo/npc/female01/holddownspot", ".ogg", 1, 2}
	}
}

contextPhrases = {
	[1] = { -- male phrases
		["Scared"] = {
			"vo/npc/male01/gordead_ques06.ogg",
			"vo/npc/male01/gordead_ques10.ogg",
			"vo/npc/male01/ohno.ogg",
			"vo/npc/male01/okimready01.ogg",
			"vo/npc/male01/uhoh.ogg",
			"vo/npc/male01/goodgod.ogg",
			"vo/npc/male01/gordead_ans05.ogg",
			"vo/npc/male01/gordead_ans15.ogg",
			"vo/npc/male01/startle01.ogg",
			"vo/npc/male01/startle02.ogg",
			"vo/npc/male01/no01.ogg",
			"vo/npc/male01/gordead_ans04.ogg",
			"vo/npc/male01/gordead_ques13.ogg",
			"vo/episode_1/npc/male01/cit_alert_head06.ogg",
			"vo/episode_1/npc/male01/cit_alert_head07.ogg",
			"vo/episode_1/npc/male01/cit_alert_zombie03.ogg",
			"vo/episode_1/npc/male01/cit_alert_zombie09.ogg",
			"vo/episode_1/npc/male01/cit_buddykilled11.ogg",
			"vo/episode_1/npc/male01/cit_evac_casualty02.ogg",
			"vo/episode_1/npc/male01/cit_evac_casualty05.ogg",
			"vo/episode_1/npc/male01/cit_evac_defendus06.ogg",
			"vo/trainyard/male01/cit_window_use03.ogg",
			"vo/outland_12/reb1_lastwaveannounced05.ogg",
			"vo/outland_02/griggs_cantholdout.ogg",
			"vo/npc/male01/gordead_ans06.ogg",
			"vo/npc/male01/gordead_ans14.ogg",

		},
		["Yell"] = {
			"vo/episode_1/npc/male01/cit_pain06.ogg",
			"vo/episode_1/npc/male01/cit_pain07.ogg",
			"vo/episode_1/npc/male01/cit_pain04.ogg",
			"vo/episode_1/npc/male01/cit_shock02.ogg",
			"vo/episode_1/npc/male01/cit_shock03.ogg",
			"vo/episode_1/npc/male01/cit_shock04.ogg",
			"vo/outland_02/griggs_fightlion_01.ogg",
			"vo/npc/male01/no02.ogg",
			--"vo/npc/male01/cit_dropper04.ogg",
			"vo/npc/male01/headsup02.ogg"

		},
		["Cheer"] = {
			"vo/coast/odessa/male01/nlo_cheer01.ogg",
			"vo/coast/odessa/male01/nlo_cheer02.ogg",
			"vo/coast/odessa/male01/nlo_cheer03.ogg",
			"vo/coast/odessa/male01/nlo_cheer04.ogg",
			"vo/outland_11/dogfight/reb1_str_dogcheers01.ogg",
			"vo/outland_11/dogfight/reb1_str_dogcheers02.ogg",
			"vo/outland_11/dogfight/reb1_str_dogcheers04.ogg",
			"vo/outland_12/reb1_striderdown05.ogg",
			"vo/outland_12/reb1_striderdown08.ogg",
		},
		["Satisfied"] = {
			"vo/npc/male01/evenodds.ogg",
			"vo/npc/male01/okimready01.ogg",
			"vo/npc/male01/okimready02.ogg",
			"vo/npc/male01/yeah02.ogg",
			"vo/npc/male01/littlecorner01.ogg",
			"vo/npc/male01/nice.ogg",
			"vo/npc/male01/oneforme.ogg",
			"vo/npc/male01/question07.ogg",
			"vo/npc/male01/question10.ogg",
			"vo/npc/male01/question13.ogg",
			"vo/npc/male01/question16.ogg",
			"vo/npc/male01/question23.ogg",
			"vo/npc/male01/fantastic01.ogg",
			"vo/episode_1/npc/male01/cit_evac_ok01.ogg",
			"vo/episode_1/npc/male01/cit_evac_ok04.ogg",
			"vo/episode_1/npc/male01/cit_greet_alyx02.ogg",
			"vo/episode_1/npc/male01/cit_reachtrain01.ogg",
			"vo/episode_1/npc/male01/cit_thesearesomuchfun.ogg",
			"vo/episode_1/npc/male01/cit_youbet.ogg",
			"vo/coast/barn/male01/youmadeit.ogg",
			"vo/outland_12/reb1_prepare_battle_02.ogg",
			"vo/outland_12/reb1_striderdown06.ogg",
			"vo/outland_12/reb1_striderdown07.ogg",
			"vo/outland_02/griggs_betweenwave_09.ogg"
		},
		["Yell for help"] = {
			"vo/npc/male01/runforyourlife01.ogg",
			"vo/npc/male01/runforyourlife02.ogg",
			"vo/npc/male01/runforyourlife03.ogg",
			"vo/npc/male01/help01.ogg",
			"vo/npc/male01/strider_run.ogg",
			"vo/npc/male01/watchout.ogg",
			"vo/episode_1/npc/male01/cit_alert_rollers04.ogg",
			"vo/episode_1/npc/male01/cit_evac_casualty08.ogg",
			"vo/episode_1/npc/male01/cit_evac_casualty11.ogg",
			"vo/episode_1/npc/male01/cit_runforit.ogg",
			"vo/coast/bugbait/sandy_help.ogg", --
			"vo/streetwar/sniper/male01/c17_09_help01.ogg", --
			"vo/streetwar/sniper/male01/c17_09_help02.ogg", --
		},
		["Someone died"] = {
			"vo/episode_1/npc/male01/cit_buddykilled01.ogg",
			"vo/episode_1/npc/male01/cit_buddykilled07.ogg",
			"vo/episode_1/npc/male01/cit_buddykilled04.ogg",
			"vo/episode_1/npc/male01/cit_buddykilled11.ogg",
			"vo/episode_1/npc/male01/cit_buddykilled12.ogg",
			"vo/episode_1/npc/male01/cit_buddykilled02.ogg",
			"vo/npc/male01/gordead_ques01.ogg",
			"vo/npc/male01/gordead_ques02.ogg",
			"vo/npc/male01/gordead_ques07.ogg",
			"vo/episode_1/npc/male01/cit_evac_casualty06.ogg",
			"vo/episode_1/npc/male01/cit_evac_casualty09.ogg",
			"vo/coast/bugbait/sandy_holdstill.ogg", --
			"vo/coast/bugbait/sandy_poorlaszlo.ogg", --
			"vo/coast/cardock/le_whohurt.ogg", --
			"vo/coast/odessa/male01/nlo_cubdeath01.ogg",
			"vo/coast/odessa/male01/nlo_cubdeath02.ogg",
			"vo/outland_12/reb1_buildingexplo03.ogg", --
			"vo/outland_12/reb1_buildingexplo06.ogg", --
			"vo/outland_12/reb1_lastwaveannounced03.ogg", --
			"vo/outland_12/reb1_prepare_battle_08.ogg", --
			"vo/npc/male01/gordead_ques06.ogg",
		},
		["Die!"] = {
			"vo/episode_1/npc/male01/cit_kill01.ogg",
			"vo/episode_1/npc/male01/cit_kill02.ogg",
			"vo/episode_1/npc/male01/cit_kill04.ogg",
			"vo/episode_1/npc/male01/cit_kill14.ogg",
			"vo/episode_1/npc/male01/cit_kill19.ogg",
			"vo/episode_1/npc/male01/cit_kill20.ogg",
			"vo/episode_1/npc/male01/cit_kill17.ogg",
			"vo/episode_1/npc/male01/cit_kill07.ogg",
			"vo/episode_1/npc/male01/cit_kill09.ogg",
			"vo/episode_1/npc/male01/cit_kill10.ogg",
			"vo/episode_1/npc/male01/cit_kill16.ogg",
			"vo/npc/male01/gotone02.ogg",
			"vo/npc/male01/likethat.ogg",
			"vo/npc/male01/gotone01.ogg",
			"vo/npc/male01/gotone02.ogg",
			"vo/outland_08/chopper/rebc_chop_hit02.ogg", --
			"vo/outland_12/reb1_striderdown11.ogg", --
			"vo/outland_12/reb1_striderdown12.ogg", --
		},
	},
	[2] = { -- female phrases
		["Scared"] = {
			"vo/npc/female01/gordead_ques06.ogg",
			"vo/npc/female01/gordead_ques10.ogg",
			"vo/npc/female01/ohno.ogg",
			"vo/npc/female01/okimready01.ogg",
			"vo/npc/female01/uhoh.ogg",
			"vo/npc/female01/goodgod.ogg",
			"vo/npc/female01/gordead_ans05.ogg",
			"vo/npc/female01/gordead_ans15.ogg",
			"vo/npc/female01/startle01.ogg",
			"vo/npc/female01/startle02.ogg",
			"vo/npc/female01/no01.ogg",
			"vo/npc/female01/no02.ogg",
			"vo/npc/female01/gordead_ans04.ogg",
			"vo/npc/female01/gordead_ques13.ogg",
			"vo/npc/female01/gordead_ques10.ogg",
			"vo/episode_1/npc/female01/cit_alert_head06.ogg",
			"vo/episode_1/npc/female01/cit_alert_head07.ogg",
			"vo/episode_1/npc/female01/cit_alert_zombie03.ogg",
			"vo/episode_1/npc/female01/cit_alert_zombie09.ogg",
			"vo/episode_1/npc/female01/cit_buddykilled11.ogg",
			"vo/episode_1/npc/female01/cit_evac_casualty02.ogg",
			"vo/episode_1/npc/female01/cit_evac_casualty05.ogg",
			"vo/episode_1/npc/female01/cit_evac_defendus06.ogg",
			"vo/episode_1/npc/female01/cit_kill06.ogg",
			"vo/trainyard/female01/cit_window_use03.ogg",
		},
		["Yell"] = {
			"vo/episode_1/npc/female01/cit_shock03.ogg",
			"vo/episode_1/npc/female01/cit_shock04.ogg",
		},
		["Cheer"] = {
			"vo/coast/odessa/female01/nlo_cheer01.ogg",
			"vo/coast/odessa/female01/nlo_cheer02.ogg",
			"vo/coast/odessa/female01/nlo_cheer03.ogg",
		},
		["Satisfied"] = {
			"vo/npc/female01/evenodds.ogg",
			"vo/npc/female01/okimready01.ogg",
			"vo/npc/female01/okimready02.ogg",
			"vo/npc/female01/yeah02.ogg",
			"vo/npc/female01/littlecorner01.ogg",
			"vo/npc/female01/nice.ogg",
			"vo/npc/female01/oneforme.ogg",
			"vo/npc/female01/question07.ogg",
			"vo/npc/female01/question10.ogg",
			"vo/npc/female01/question13.ogg",
			"vo/npc/female01/question16.ogg",
			"vo/npc/female01/question23.ogg",
			"vo/npc/female01/fantastic01.ogg",
			"vo/episode_1/npc/female01/cit_evac_ok01.ogg",
			"vo/episode_1/npc/female01/cit_evac_ok04.ogg",
			"vo/episode_1/npc/female01/cit_greet_alyx02.ogg",
			"vo/episode_1/npc/female01/cit_reachtrain01.ogg",
			"vo/episode_1/npc/female01/cit_thesearesomuchfun.ogg",
			"vo/episode_1/npc/female01/cit_youbet.ogg",
			"vo/coast/barn/female01/youmadeit.ogg"
		},
		["Yell for help"] = {
			"vo/npc/female01/runforyourlife01.ogg",
			"vo/npc/female01/runforyourlife02.ogg",
			"vo/npc/female01/runforyourlife03.ogg",
			"vo/npc/female01/help01.ogg",
			"vo/npc/female01/no02.ogg",
			"vo/npc/female01/strider_run.ogg",
			"vo/npc/female01/watchout.ogg",
			"vo/episode_1/npc/female01/cit_alert_rollers04.ogg",
			"vo/episode_1/npc/female01/cit_evac_casualty08.ogg",
			"vo/episode_1/npc/female01/cit_evac_casualty11.ogg",
			"vo/episode_1/npc/female01/cit_runforit.ogg",
		},
		["Someone died"] = {
			"vo/episode_1/npc/female01/cit_buddykilled01.ogg",
			"vo/episode_1/npc/female01/cit_buddykilled07.ogg",
			"vo/episode_1/npc/female01/cit_buddykilled04.ogg",
			"vo/episode_1/npc/female01/cit_buddykilled11.ogg",
			"vo/episode_1/npc/female01/cit_buddykilled12.ogg",
			"vo/episode_1/npc/female01/cit_buddykilled02.ogg",
			"vo/npc/female01/gordead_ques01.ogg",
			"vo/npc/female01/gordead_ques02.ogg",
			"vo/npc/female01/gordead_ques07.ogg",
			"vo/episode_1/npc/female01/cit_evac_casualty06.ogg",
			"vo/episode_1/npc/female01/cit_evac_casualty09.ogg",
			"vo/coast/odessa/female01/nlo_cubdeath01.ogg",
			"vo/coast/odessa/female01/nlo_cubdeath02.ogg",
		},
		["Die!"] = {
			"vo/episode_1/npc/female01/cit_kill01.ogg",
			"vo/episode_1/npc/female01/cit_kill02.ogg",
			"vo/episode_1/npc/female01/cit_kill04.ogg",
			"vo/episode_1/npc/female01/cit_kill14.ogg",
			"vo/episode_1/npc/female01/cit_kill19.ogg",
			"vo/episode_1/npc/female01/cit_kill20.ogg",
			"vo/episode_1/npc/female01/cit_kill17.ogg",
			"vo/episode_1/npc/female01/cit_kill07.ogg",
			"vo/episode_1/npc/female01/cit_kill09.ogg",
			"vo/episode_1/npc/female01/cit_kill10.ogg",
			"vo/episode_1/npc/female01/cit_kill16.ogg",
			"vo/npc/female01/gotone02.ogg",
			"vo/npc/female01/likethat.ogg",
			"vo/npc/female01/gotone01.ogg",
			"vo/npc/female01/gotone02.ogg",
		},
	}
}

if CLIENT then
	local function randomPhrase()
		RunConsoleCommand("hg_phrase")
	end

	local mClamp, mRandom = math.Clamp, math.random

	concommand.Add("hg_phrase", function(ply, cmd, args)
		local gender = ThatPlyIsFemale(ply) and 2 or 1
		local i = (#args > 0 and mClamp(tonumber(args[1]),1,#phrases[gender])) or mRandom(#phrases[gender])
		if (#args < 2 and not #args == 0) then return end
 		local num = (#args > 1 and mClamp(tonumber(args[2]),phrases[gender][tonumber(i)][3],phrases[gender][tonumber(i)][4])) or mRandom(phrases[gender][tonumber(i)][3], phrases[gender][tonumber(i)][4])
		net.Start("hg_phrase")
		net.WriteInt(i, 8)
		net.WriteInt(num, 8)
		net.SendToServer()
	end)

	hook.Add("radialOptions", "4", function()
		local organism = lply.organism or {}

		if lply:Alive() and not organism.otrub and lply.PlayerClassName ~= "Gordon" then
			--hg.radialOptions[#hg.radialOptions + 1] = {randomPhrase, (LocalPlayer().PlayerClassName == "Slugcat" and "Wáaaaǎa\nWāaaàaâ") or (LocalPlayer().PlayerClassName == "Gordon" and "...") or "Say something"}
			hg.radialOptions[#hg.radialOptions + 1] = {
				[1] = function(mouseClick)
					if mouseClick == 1 or organism.pain > 60 then
						randomPhrase()
					else
						--print(lply:GetPlayerClass())
						if lply.PlayerClassName and lply:GetPlayerClass() and !lply:GetPlayerClass().CanUseDefaultPhrase then return end
						local tbl = {}
						for context, phrases in pairs(contextPhrases[1]) do
							if lply.organism.pain > 30 and (context == "Satisfied" or context == "Cheer") then continue end
							
							tbl[#tbl + 1] = {
								[1] = function()
									RunConsoleCommand("hg_phrase_context", context)
								end,
								[2] = context
							}
						end
						hg.CreateRadialMenu(tbl)
						return -1
					end
				end,
				[2] = organism.pain > 60 and (organism.pain <= 100 and "Yell in pain" or "Moan in pain") or (lply.PlayerClassName == "furry" and "Meow") or "Do Phrase\nRMB - Menu"
			}
		end
	end)
end

-- no more svside 🥺