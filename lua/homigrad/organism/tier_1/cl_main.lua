local hg = hg

hg.bonetohitgroup = {
	["ValveBiped.Bip01_Head1"] = HITGROUP_HEAD,
	["ValveBiped.Bip01_L_UpperArm"] = HITGROUP_LEFTARM,
	["ValveBiped.Bip01_L_Forearm"] = HITGROUP_LEFTARM,
	["ValveBiped.Bip01_L_Hand"] = HITGROUP_LEFTARM,
	["ValveBiped.Bip01_R_UpperArm"] = HITGROUP_RIGHTARM,
	["ValveBiped.Bip01_R_Forearm"] = HITGROUP_RIGHTARM,
	["ValveBiped.Bip01_R_Hand"] = HITGROUP_RIGHTARM,
	["ValveBiped.Bip01_Pelvis"] = HITGROUP_CHEST,
	["ValveBiped.Bip01_Spine2"] = HITGROUP_CHEST,
	["ValveBiped.Bip01_Spine1"] = HITGROUP_STOMACH,
	["ValveBiped.Bip01_Spine4"] = HITGROUP_CHEST,
	["ValveBiped.Bip01_Spine"] = HITGROUP_STOMACH,
	["ValveBiped.Bip01_L_Thigh"] = HITGROUP_LEFTLEG,
	["ValveBiped.Bip01_L_Calf"] = HITGROUP_LEFTLEG,
	["ValveBiped.Bip01_L_Foot"] = HITGROUP_LEFTLEG,
	["ValveBiped.Bip01_R_Thigh"] = HITGROUP_RIGHTLEG,
	["ValveBiped.Bip01_R_Calf"] = HITGROUP_RIGHTLEG,
	["ValveBiped.Bip01_R_Foot"] = HITGROUP_RIGHTLEG
}

hg.amputeetable = {
	--["ValveBiped.Bip01_L_UpperArm"] = "larm",
	["ValveBiped.Bip01_L_Forearm"] = "larm",
	["ValveBiped.Bip01_L_Hand"] = "larm",
	--["ValveBiped.Bip01_R_UpperArm"] = "rarm",
	["ValveBiped.Bip01_R_Forearm"] = "rarm",
	["ValveBiped.Bip01_R_Hand"] = "rarm",
	--["ValveBiped.Bip01_L_Thigh"] = "lleg",
	["ValveBiped.Bip01_L_Calf"] = "lleg",
	["ValveBiped.Bip01_L_Foot"] = "lleg",
	--["ValveBiped.Bip01_R_Thigh"] = "rleg",
	["ValveBiped.Bip01_R_Calf"] = "rleg",
	["ValveBiped.Bip01_R_Foot"] = "rleg"
}

--[[hg.amputeetable = {
	[HITGROUP_LEFTLEG] = "lleg",
	[HITGROUP_RIGHTLEG] = "rleg",
	[HITGROUP_LEFTARM] = "larm",
	[HITGROUP_RIGHTARM] = "rarm",
	//[HITGROUP_HEAD] = 0.5
}--]]

hook.Add("ScalePlayerDamage", "remove-effects", function(ent, hitgroup, dmgInfo)
	if dmgInfo:IsDamageType(DMG_BUCKSHOT + DMG_BULLET + DMG_SLASH) then
		return true
	end
end)

local min = math.min
local pain_mat = Material("sprites/mat_jack_hmcd_narrow")

local tab = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0,
}

local tabblood = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0,
}

surface.CreateFont("RemDeathStateFont", {
	font = "Lora",
	size = ScreenScale(22),
	weight = 1100,
	outline = true
})

local remDeathStateColor = Color(255, 255, 255, 0)
local remDeathStateStation
local remDeathStateLoading
local remHeartStopped = false
local remFibrillationStation
local remFibrillationLoading
local remFibrillationStopping
local remHeartStopLoading

local function GetLocalDeathState()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	local org = ply.new_organism or ply.organism
	local deathStateEnd = org and tonumber(org.deathStateEnd)
	if not org or not org.otrub or not org.incapacitated or not deathStateEnd or deathStateEnd <= CurTime() then return end

	return org, deathStateEnd
end

local function StopRemDeathStateSound()
	if IsValid(remDeathStateStation) then remDeathStateStation:Stop() end
	remDeathStateStation = nil
end

local function PlayRemHeartStopSound(uncon)
	if remHeartStopLoading then return end

	remHeartStopLoading = true
	sound.PlayFile("sound/" .. (uncon and "rem_heartstopuncon.wav" or "rem_heartstop.wav"), "noblock noplay", function(station)
		remHeartStopLoading = nil
		if not IsValid(station) then return end
		station:SetVolume(1)
		station:Play()
	end)
end

local function PlayRemDeathStateSound()
	if IsValid(remDeathStateStation) then return end
	if remDeathStateLoading then return end

	remDeathStateLoading = true
	sound.PlayFile("sound/rem_deathstatefull.mp3", "noplay", function(station)
		remDeathStateLoading = nil
		if not IsValid(station) then return end
		if not GetLocalDeathState() then station:Stop() return end
		remDeathStateStation = station
		station:EnableLooping(true)
		station:SetVolume(1)
		station:Play()
	end)
end

local function StartRemFibrillationSound()
 if IsValid(remFibrillationStation) then
  remFibrillationStopping = nil
  remFibrillationStation:Play()
  if remFibrillationStation.ChangeVolume then remFibrillationStation:ChangeVolume(1, 1) else remFibrillationStation:SetVolume(1) end
  return
 end
 if remFibrillationLoading then return end

 remFibrillationLoading = true
 sound.PlayFile("sound/rem_fibrillation.mp3", "noplay", function(station)
  remFibrillationLoading = nil
  if not IsValid(station) then return end
  local ply = LocalPlayer()
  local org = IsValid(ply) and (ply.new_organism or ply.organism)
  if not IsValid(ply) or not ply:Alive() or not org or not org.fibrillation then station:Stop() return end
  remFibrillationStation = station
  station:EnableLooping(true)
  station:SetVolume(0)
  station:Play()
  if station.ChangeVolume then station:ChangeVolume(1, 1) else station:SetVolume(1) end
 end)
end

local function StopRemFibrillationSound()
 if not IsValid(remFibrillationStation) or remFibrillationStopping then return end
 remFibrillationStopping = true
 if remFibrillationStation.ChangeVolume then
  remFibrillationStation:ChangeVolume(0, 1)
 else
  remFibrillationStation:Stop()
  remFibrillationStation = nil
  remFibrillationStopping = nil
  return
 end
 timer.Simple(1.05, function()
  if not remFibrillationStopping or not IsValid(remFibrillationStation) then return end
  remFibrillationStation:Stop()
  remFibrillationStation = nil
  remFibrillationStopping = nil
 end)
end

hook.Add("Think", "RemCardiacSounds", function()
 local ply = LocalPlayer()
 if not IsValid(ply) then return end

 local org = ply:Alive() and (ply.new_organism or ply.organism)
 local heartstop = org and org.heartstop or false
 local fibrillation = org and org.fibrillation or false

 if heartstop and not remHeartStopped then PlayRemHeartStopSound(org.otrub) end
 remHeartStopped = heartstop

 if fibrillation then
  StartRemFibrillationSound()
 else
  StopRemFibrillationSound()
 end
end)

hook.Add("Think", "RemDeathStateSound", function()
	if GetLocalDeathState() then
		PlayRemDeathStateSound()
	else
		StopRemDeathStateSound()
	end
end)

local k1, k2, k3

local upDir = Vector(0, 0, 1)
local fwdDir = Vector(0, 2.5, 0)
local rightDir = Vector(2.5, 0, 0)

local function plyCommand(ply,cmd)
	local time = CurTime()
	ply.cmdtimer = ply.cmdtimer or time

	if cmd == "soundfade 100 99999" then
		if IsValid(hg.chat) then
			hg.chat:SetRealAlpha(0)

			timer.Create("otrubhuy", 1, 1, function()
				if lply.organism and not lply.organism.otrub then lply:ConCommand("soundfade 0 1") end
				hg.chat:AnimateRealAlpha(255)
			end)
		end
	end

	if ply.cmdtimer < time then
		ply.cmdtimer = time + 0.1

		ply:ConCommand(cmd)
	end
end

local clr_black1 = Color( 0, 0, 0, 255)
local clr_black2 = Color( 0, 0, 0, 255)
local hg_forced_firstperson_death = ConVarExists("hg_firstperson_death") and GetConVar("hg_firstperson_death") or CreateClientConVar("hg_firstperson_death", "1", true, false, "Toggle first-person death camera view", 0, 1)
local hg_forced_deathfadeout = ConVarExists("hg_deathfadeout") and GetConVar("hg_deathfadeout") or CreateClientConVar("hg_deathfadeout", "0", true, true, "Toggle screen fade and sound mute on death", 0, 1)

local mat1 = Material("vgui/gradient-u")
local mat2 = Material("vgui/gradient-d")

local ang1 = Angle()
local ang2 = Angle()

hook.Add("Think", "hg.force.death.convars", function()
	if hg_forced_deathfadeout:GetInt() ~= 0 then
		RunConsoleCommand("hg_deathfadeout", "0")
	end

	if hg_forced_firstperson_death:GetInt() ~= 1 then
		RunConsoleCommand("hg_firstperson_death", "1")
	end

end)

hook.Add("HUDShouldDraw", "hg.HUDShouldDraw", function(id)
	if (fakeTimer and fakeTimer - 2 > CurTime()) then
		return false
	end
end)

hook.Add("HG_OnOtrub", "adsadsadhuy!!", function(ply)
	if ply == LocalPlayer() then
		lply:SetDSP(17)
		plyCommand(lply,"soundfade 100 99999")
	end
end)

hook.Add("Player_Death", "adsadsadhuy!!", function(ply)
	if ply == LocalPlayer() then
		lply:SetDSP(17)
		plyCommand(lply,"soundfade 100 99999")
	end
end)

local alivestart = CurTime()
hg.screens = hg.screens or {}
local screens = hg.screens
local screened = 0
local curscreen = 1
local switch = false
local file_Delete = file.Delete
hg.alivecntr = hg.alivecntr or 0

local function remove_imgs()
	local folder = "dreams"
		if file.Exists(folder, "DATA") then
			local files, _ = file.Find(folder.."/*", "DATA")

			for _, name in pairs(files) do
				file_Delete(folder.."/"..name)
			end
		end
end

local disorientationLerp = 0
local disorientationVignetteMat = Material("effects/shaders/zb_vignette")
local concLerp = 0
local nauseaLerp = 0
local tinnitusConcLerp = 0

hook.Add("Player Spawn", "screenshot_game", function(ply)
	if OverrideSpawn then return end

	if ply == lply then
		disorientationLerp = 0

		alivestart = CurTime()
		lply.tried_fixing_limb = nil

		hg.alivecntr = hg.alivecntr + 1

		for i, screen in ipairs(hg.screens) do
			hg.screens[i] = nil
		end
		remove_imgs()
	end
end)

hook.Add("InitPostEntity", "removeshits", function()
	remove_imgs()
end)

hook.Add("Player Disconnected", "removeshits", function()
	remove_imgs()
end)

hook.Add("radialOptions", "DislocatedJoint", function()
    if !lply:Alive() or !lply.organism or lply.organism.otrub then return end
	if (lply.tried_fixing_limb or 0) > CurTime() then return end
	local org = lply.organism
	if org.pain > 60 then return end
    
    if org.llegdislocation or org.rlegdislocation then
        local tbl = {
            function()
				lply.tried_fixing_limb = CurTime() + 0.5
				RunConsoleCommand("hg_fixdislocation", 1, 0)
            end,
            "Fix dislocation (leg)"
        }
        hg.radialOptions[#hg.radialOptions + 1] = tbl
	else
		local ent = hg.eyeTrace(lply).Entity

		if ent.organism and (ent.organism.llegdislocation or ent.organism.rlegdislocation) then
			local tbl = {
				function()
					lply.tried_fixing_limb = CurTime() + 0.5
					RunConsoleCommand("hg_fixdislocation", 1, 1)
				end,
				"Fix "..ent:GetPlayerName().."'s dislocation (leg)"
			}
			hg.radialOptions[#hg.radialOptions + 1] = tbl
		end
    end
end)

hook.Add("radialOptions", "DislocatedJoint2", function()
    if !lply:Alive() or !lply.organism or lply.organism.otrub then return end
	if (lply.tried_fixing_limb or 0) > CurTime() then return end
	local org = lply.organism
	if org.pain > 60 then return end
	
    if org.larmdislocation or org.rarmdislocation then
        local tbl = {
            function()
				lply.tried_fixing_limb = CurTime() + 0.5
				RunConsoleCommand("hg_fixdislocation", 2, 0)
            end,
            "Fix dislocation (arm)"
        }
        hg.radialOptions[#hg.radialOptions + 1] = tbl
	else
		local ent = hg.eyeTrace(lply).Entity

		if ent.organism and (ent.organism.larmdislocation or ent.organism.rarmdislocation) then
			local tbl = {
				function()
					lply.tried_fixing_limb = CurTime() + 0.5
					RunConsoleCommand("hg_fixdislocation", 2, 1)
				end,
				"Fix "..ent:GetPlayerName().."'s dislocation (arm)"
			}
			hg.radialOptions[#hg.radialOptions + 1] = tbl
		end
    end
end)

hook.Add("radialOptions", "DislocatedJaw", function()
    if !lply:Alive() or !lply.organism or lply.organism.otrub then return end
	if (lply.tried_fixing_limb or 0) > CurTime() then return end
	local org = lply.organism
	if org.pain > 60 then return end
	
    if org.jawdislocation then
        local tbl = {
            function()
				lply.tried_fixing_limb = CurTime() + 0.5
				RunConsoleCommand("hg_fixdislocation", 3, 0)
            end,
            "Fix dislocation (jaw)"
        }
        hg.radialOptions[#hg.radialOptions + 1] = tbl
	else
		local ent = hg.eyeTrace(lply).Entity

		if ent.organism and ent.organism.jawdislocation then
			local tbl = {
				function()
					lply.tried_fixing_limb = CurTime() + 0.5
					RunConsoleCommand("hg_fixdislocation", 3, 1)
				end,
				"Fix "..ent:GetPlayerName().."'s dislocation (jaw)"
			}
			hg.radialOptions[#hg.radialOptions + 1] = tbl
		end
    end
end)

hook.Add("PostRender", "screenshot_think", function()
	local org = lply.organism
	
	if not org or not org.brain or org.otrub or !lply:Alive() then return end
	local part = CurTime() - alivestart
	//print(part)
	if part % 60 > 59 and (screened != math.Round(part / 60, 0)) then
		screened = math.Round(part / 60, 0)
		//gui.HideGameUI()

		if gui.IsGameUIVisible() or gui.IsConsoleVisible() or IsValid(vgui.GetHoveredPanel()) then return end

		local data = render.Capture( {
			format = "jpeg",
			x = 0,
			y = 0,
			w = ScrW(),
			h = ScrH(),
			quality = 1,
			//alpha = false
		} )

		if not data then return end

		local name = "dreams/dream"..hg.alivecntr.."_"..(#screens + 1)..".jpeg"
		
		if not file.Exists("dreams", "DATA") then file.CreateDir("dreams") end
		file.Write(name, data)
		
		timer.Simple(1, function()
			screens[#screens + 1] = Material("data/"..name)
		end)
	end
end)

local braindeathstart = CurTime() + 20
local lerpedpart = 0
local lerpedbrain = 0
hook.Add("Post Post Pre Post Processing", "ShowScreens", function()
	local org = lply.organism
	
	if !lply:Alive() then return end
	if not org or not org.brain then return end

	local part = CurTime() - braindeathstart

	local show_multiki = org.brain > 0.1 and org.otrub

	if show_multiki then
		lerpedbrain = LerpFT(0.05, lerpedbrain, org.brain)
		local time = 40 - (lerpedbrain - 0.1) * 20
		if part % time > time / 3 and curscreen <= #screens and screens[curscreen] and !screens[curscreen]:IsError() then
			switch = true
			local part2 = math.ease.InOutSine(math.sin(((part % time) - time / 3) / (time / 3 * 2) * math.pi))
			lerpedpart = LerpFT(0.1, lerpedpart, part2)

			surface.SetDrawColor(255, 255, 255, math.Clamp(lerpedpart * 50, 0, 255))
			surface.SetMaterial(screens[curscreen])
			surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

			DrawToyTown(4, ScrH())
		else
			if switch then
				curscreen = curscreen == #screens and 1 or curscreen + 1
				switch = false
			end
		end
	else

		braindeathstart = CurTime()
	end
end)
local hurtoverlay = Material("zcity/neurotrauma/damageOverlay.png")
local blindoverlay = Material("zcity/neurotrauma/blindoverlay.png")
local addtime = CurTime()

local hg_potatopc
local old = false
local tinnitusSoundFactor
local lerpblood = 0
local hg_gopro = ConVarExists("hg_gopro") and GetConVar("hg_gopro") or CreateClientConVar("hg_gopro", "0", true, false, "Toggle GoPro-like first-person camera view", 0, 1)
hook.Add("Post Post Pre Post Processing", "organism-effects", function()
	local spect = IsValid(lply:GetNWEntity("spect")) and lply:GetNWEntity("spect")
	local organism = lply:Alive() and lply.organism or (viewmode == 1 and IsValid(spect) and spect.organism) or {}
	local new_organism = lply:Alive() and lply.new_organism or (viewmode == 1 and IsValid(spect) and spect.new_organism) or {}

	//hg.DrawAffliction(0, 0, 100, 100, 1, "pale")

	if organism.owner == LocalPlayer() then
		if new_organism.otrub and !old then
			hook.Run("HG_OnOtrub", new_organism.owner)
		end
		
		old = new_organism.otrub
	end

	--LerpVariables(FrameTime(),organism,new_organism)

	if not organism then return end
	local alive = lply:Alive() or (spect and spect:Alive())

	local health = (lply:Alive() and lply:Health()) or 100

	if not alive or follow then end

	local org = organism
	
	if not org.brain then return end
	
	local adrenaline = org.adrenaline or 0
	local pulse = org.pulse or 70
	local pain = org.pain or 0
	local hurt = org.hurt or 0
	local blood = org.blood or 5000
	local bleed = org.bleed or 0
	local o2 = org.o2 and org.o2[1] or 30
	local brain = org.brain or 0
	local otrub = lply:Alive() and org.otrub or false
	local analgesia = organism.analgesia or 0
	local analgesiaVisual = analgesia >= 1 and (org.seizureActive and not org.otrub and math.max(analgesia * 3, 3) or analgesia) or 0
	local zerlkersOverdose = math.Clamp(org.zerlkersOverdose or 0, 0, 1)
	-- Zerlkers does not cure these conditions; it reduces their distracting
	-- visual feedback while the server keeps the real values and consequences.
	local zerlkersVisualMul = 1 - math.Clamp(org.zerlkers or 0, 0, 1) * 0.8
	analgesiaVisual = math.max(analgesiaVisual, 1 + zerlkersOverdose * 2.5)
	local health = health
	local disorientation = org.disorientation or 0
	local immobilization = org.immobilization or 0
	local critical = org.critical or false
	tinnitusSoundFactor = Lerp(FrameTime()*2.5,tinnitusSoundFactor or 0, math.min(math.max( lply.tinnitus and (lply.tinnitus - CurTime()) or 0, 0)*7.5,120))
	local tinnitusSoundFactor2 = tinnitusSoundFactor + (hook.Run("ModifyTinnitusFactor", tinnitusSoundFactor) or 0)

	--print(lply.tinnitus)
	local adrenK = math.min(math.max(1 + adrenaline, 1), 1.2)

	if org.otrub then
		//DrawMotionBlur(0.1, 1., 0.1)
		//lply:ScreenFade( SCREENFADE.IN, clr_black2, 2, 0.5 )
	end
	
	--maybe 56, 30?
	local normaldsp = hg_gopro:GetBool() and 55 or 0
	local target_dsp = normaldsp
	local dsp_fast = false

	if otrub or ((fakeTimer and fakeTimer - 2 > CurTime()) and GetConVar("hg_deathfadeout"):GetBool()) then
		--if otrub or (fakeTimer and fakeTimer - 2 > CurTime()) then
		clr_black1.a = math.Clamp(pain / 50 * 255, 250, 255)
		//lply:ScreenFade( SCREENFADE.IN, clr_black2, 2, 0.5 )
		--lply:ScreenFade( SCREENFADE.IN, Color(0,0,0,255), 2, 0.5 )
		
		if isnumber(zb.ROUND_STATE) and (zb.ROUND_STATE ~= 1) then
			target_dsp = normaldsp
			plyCommand(lply,"soundfade "..tinnitusSoundFactor2.." 25")
		elseif lply:Alive() then
			target_dsp = 17
			dsp_fast = true
			plyCommand(lply,"soundfade 100 25")
		end
	else
		plyCommand(lply,"soundfade "..tinnitusSoundFactor2.." 25")

		if ((disorientation and disorientation > 3) or (brain and brain > 0.2) or lply.PlayerClassName == "headcrabzombie" or lply:GetNetVar("headcrab")) and lply:Alive() then
			target_dsp = 130
		elseif lply.suiciding and lply:Alive() then
			target_dsp = 130
		end
	end

	lply:SetDSP(target_dsp, dsp_fast)

	if not alive then
		return false
	end
	
	local adrenalineDisorientation = math.max(adrenaline - 2.5, 0)
	k1 = Lerp(FrameTime() * 15, k1 or 0, math.min(adrenalineDisorientation, 1.5))
	k2 = ((30 - (o2 or 30)) / 30 + (1 - (consciousnessLerp or 1))) * zerlkersVisualMul -- + brain * 2
	k3 = ((5000 / math.max(blood, 1000)) - 1) * 1.5 * zerlkersVisualMul

	DrawSharpen(k1 * 2, k1 * 1)
	local lowpulse = math.max((70 - pulse) / 70, 0) + math.max(3000 * ((math.cos(CurTime()/2) + 1) / 2 * 0.1 + 1) - (blood * adrenK - 300),0) / 400

	if (lply.PlayerClassName == "headcrabzombie" or lply:GetNetVar("headcrab")) and lply:Alive() then
		disorientation = disorientation + 100
	end

	disorientation = disorientation + amtflashed * 5

	local amount = 1 - math.Clamp(lowpulse + disorientation / 4 + k2 * 2,0,1)

	disorientationLerp = LerpFT(disorientation > disorientationLerp and 1 or 0.01, disorientationLerp, math.max(lply.suiciding and 2.5 or 0, disorientation))

	local disVig = math.Clamp((disorientationLerp - 0.4) / 3.6, 0, 1)
	if disVig > 0.01 and lply:Alive() then
		disVig = disVig * disVig * (3 - 2 * disVig)
		render.UpdateScreenEffectTexture()
		disorientationVignetteMat:SetFloat("$c2_x", CurTime() + 10000)
		disorientationVignetteMat:SetFloat("$c0_z", disVig * 0.45)
		disorientationVignetteMat:SetFloat("$c1_y", disVig * 1.0)
		render.SetMaterial(disorientationVignetteMat)
		render.DrawScreenQuad()
	end

	if (disorientationLerp > 1) and lply:Alive() or brain > 0 then
		local add2 = disorientationLerp - 1
		if not brain_motionblur and lply.PlayerClassName ~= "headcrabzombie" then DrawMotionBlur(0.15 - math.Clamp(add2 / 1, 0, 0.1), add2 * 2, 0.001) end
		if disorientationLerp > 2 then
			local add = (disorientationLerp - 2) * 2
			local time = CurTime() * 3
			local mul = math.Clamp(add / 16, 0, 0.2)

			ang1[1] = math.cos(time) + math.sin(time * 0.5) + math.sin((time - 5) * 1.1)
			ang1[2] = math.sin(time) + math.cos(time * 0.5) + math.sin((time + 1) * 1.1)
			ViewPunch(ang1 * mul * 0.125)
			//ViewPunch2(ang1 * mul * 1 * 0.25)

			//local ang = lply:EyeAngles()
			//lply:SetEyeAngles(ang - ang1 * 0.01)

			ang2[3] = math.Rand(-15,15) * mul
			//SetViewPunchAngles(ang2)
			//ViewPunch(ang1 * mul * 1)
		end
	end
		-- Pain-based screen shake
	if pain > 55 and lply:Alive() and not otrub then
		local painShakeIntensity = math.Clamp((pain - 55) / (120 - 55), 0, 1)
		local shakeMul = painShakeIntensity * 0.5 * zerlkersVisualMul
		local time = CurTime() * (4 + painShakeIntensity * 4)

		ang1[1] = math.sin(time) * shakeMul
		ang1[2] = math.cos(time * 0.7) * shakeMul
		ang1[3] = math.Rand(-1, 1) * shakeMul * 0.5

		ViewPunch(ang1)
	end

	-- cl_screeneffects owns the Z-City low-consciousness/otrub damage overlay.
	-- Keep this additional awake feedback from drawing the same layer twice.
	if not otrub and (org.consciousness < 0.7) then
		lerpblood = LerpFT(0.01, lerpblood or 0, math.Clamp((0.7 - org.consciousness) * 5, 0, 1) * 255)
		local lowblood = (3600 - blood) / 600

		addtime = addtime + FrameTime() / 6
		local amt = (math.cos(addtime) + math.sin(addtime * 3) + math.sin(addtime * 2)) / 90
		local amt2 = (math.sin(addtime) + math.cos(addtime * 5) + math.sin(addtime * 6)) / 90
		local mat = Matrix({
			{1 - amt, amt, 0, -amt2 / 2},
			{amt2, 1 - amt2, 0, -amt / 2},
			{0, 0, 1, 0},
			{0, 0, 0, 1},
		})
		hurtoverlay:SetMatrix("$basetexturetransform", mat)
		surface.SetMaterial(hurtoverlay)
		surface.SetDrawColor(0, 0, 0, lerpblood)
		surface.DrawTexturedRect(-ScrW() * 2.0, -ScrH() * 2.0, ScrW() * 5, ScrH() * 5)
		//ViewPunch(Angle(-amt * 1, amt2 * 1,0))
		//ViewPunch2(Angle(-amt * 1, amt2 * 1,0))
	end


	//pain = math.abs(math.cos(CurTime())) * 40
	if (pain > 0) or (hurt > 0) or (immobilization > 0) or (brain > 0) then
		local k = ((hurt + immobilization / 15) / 2)
		--DrawToyTown(1, k * ScrH())
		local newpain = (pain - 10) * zerlkersVisualMul
		if newpain > 0 then
			//surface.SetDrawColor(0, 0, 0, (newpain / 20) * 255 - math.ease.InOutCirc(math.abs(math.cos(CurTime()))) * 50)
			//surface.SetMaterial(pain_mat)
			//surface.DrawTexturedRect(-1, -1, ScrW()+1, ScrH()+1)
			local blur = math.max((newpain / 30 + brain * 10),0) / 30
			if blur > 0 then
				DrawMaterialOverlay( "sprites/mat_jack_hmcd_scope_aberration", blur )
			end
		end
	end
	hg_potatopc = hg_potatopc or hg.ConVars.potatopc
	local potato = hg_potatopc:GetBool()
	if (k1 > 0) or (k2 > 0) or (k3 > 0) or brain > 0 then
		if !potato then
			DrawToyTown(2, (k3 * 3 + k2 * 1 + brain * 10) * ScrH() / 2)
		else

		end
	end

	--DrawMaterialOverlay( "homigrad/vgui/bloodblur.png", 0)
	local view = render.GetViewSetup()
	--RenderSuperDoF(view.origin,view.angles,0)
	if analgesiaVisual > 1 then
		DrawMaterialOverlay( "particle/warp4_warp_noz", -(analgesiaVisual - 0.5) * math.sin(CurTime()) * 5 / 150 )
	end

	/*

	local amt = (math.cos(addtime) + math.sin(addtime * 3) + math.sin(addtime * 2)) / 90
	local amt2 = (math.sin(addtime) + math.cos(addtime * 5) + math.sin(addtime * 6)) / 90
	surface.SetDrawColor(255,255,255,math.abs(amt * 255 * 30))
	surface.SetMaterial(blindoverlay)

	local mat = Matrix({
		{1 - amt, amt, 0, -amt2 / 2},
		{amt2, 1 - amt2, 0, -amt / 2},
		{0, 0, 1, 0},
		{0, 0, 0, 1},
	})
	blindoverlay:SetMatrix("$basetexturetransform", mat)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

	*/

	tabblood["$pp_colour_colour"] = Lerp(FrameTime() * 30, tabblood["$pp_colour_colour"], math.max(0, (blood / 5000) * (potato and (blood / 5000) or 1) - (!org.otrub and potato and k2 or 0) + (math.max(analgesiaVisual - 1, 0) * math.sin(CurTime()) * 5)))
	//tabblood["$pp_colour_contrast"] = Lerp(FrameTime() * 30, tabblood["$pp_colour_contrast"], health < 80 and math.max(1.5 * ( 1 - math.min(health / 50, 1) ), 1 ) or 1)
	tabblood["$pp_colour_brightness"] = Lerp(FrameTime() * 30, tabblood["$pp_colour_brightness"], (potato and ((blood / 5000 - 1) / 2 - (!org.otrub and k2 / 10 or 0)) or 0) )
	tabblood["$pp_colour_addb"] = 0
	//tabblood["$pp_colour_addg"] = k2 / 15
	//tabblood["$pp_colour_addr"] = k2 / 15
	--tab["$pp_colour_brightness"] = k1 > 1 and -(k1 - 1) / 20 or 0
	--tab["$pp_colour_contrast"] = k1 > 1 and -(k1 - 1) / 10 + 1 or 1
	--DrawBloom( 0.80, 2, 9, 9, 1, 1, 1, 1, 1 )
	//DrawColorModify(tab)
	
	DrawColorModify(tabblood)

	local ent = IsValid(lply.FakeRagdoll) and lply.FakeRagdoll or lply

	if otrub then
		--[[render.PushFilterMag( TEXFILTER.ANISOTROPIC )
		render.PushFilterMin( TEXFILTER.ANISOTROPIC )

		local textOtrub = "You are unconscious. "
		local textOtrub2 =  
			( critical and "You can't be saved." ) or 
			( incapacitated and "You will not get up without someone's help." ) or 
			( 
				"You will probably wake up in "
				..( 	
					( pain < 50 and "about a minute." ) or 
					( pain < 100 and "about two minutes." ) or 
					"a few minutes."
				) 
			)

		local parsed = markup.Parse( 
			"<font=HomigradFontMedium>"..
			( critical and "You're criticaly injured." or textOtrub )..
			"\n<colour=255,"..( critical and 25 or 255 )..","..( critical and 25 or 255 ) ..",255>"..
			( textOtrub2 ).."</colour></font>" 
		)
		--((critical and "You can not be saved.") or 
		--(incapacitated and "You will not get up without someone's help.") or 
		--( "You will probably wake up in " .. (pain < 50 and "about a minute.") ) or 
		--((pain < 100 and "about two minutes.") or "a few minutes.")) -- WTF???
		
		--surface.SetTextColor(255,255,255,255)
		--surface.SetFont("HomigradFontMedium")
		--local txtSizeX, txtSizeY = surface.GetTextSize(textOtrub)
		--surface.SetTextPos(ScrW()/2 - (txtSizeX/2),ScrH()/1.1 - (txtSizeY/2))
		--surface.DrawText(textOtrub)

		parsed:Draw( ScrW()/2, ScrH()/1.1, TEXT_ALIGN_CENTER, nil, nil, TEXT_ALIGN_CENTER )
		
		render.PopFilterMag()
		render.PopFilterMin()--]]
	end
	
	if IsValid(ent) and ent.Blinking and lply:Alive() then
		surface.SetDrawColor(0,0,0,255)
		if amtflashed and amtflashed > 0.1 and amtflashed < 0.8 and ent.Blinking > 0.1 then
			surface.DrawRect(-1, -1,ScrW() + 1,ScrH() + 1)
			//surface.DrawRect(-1,-1,ScrW()+1,ent.Blinking * ScrH())
			//surface.DrawRect(-1,ScrH() + 1,ScrW()+1,-ent.Blinking * ScrH())
		end
	end
end)

hook.Add("OnNetVarSet","wounds_netvar",function(index, key, var)
	if key == "wounds" then
		local ent = Entity(index)
		--local ent = hg.RagdollOwner(ent) or ent
		
		if IsValid(ent) then
			if ent.wounds then
				for i = 1, #ent.wounds do
					if !var or !var[i] then continue end
					var[i][5] = ent.wounds[i][5]
				end
			end

			ent.wounds = var
			--PrintTable(ent.wounds)
			local rag = IsValid(ent:GetNWEntity("FakeRagdoll")) and ent:GetNWEntity("FakeRagdoll")
			rag = IsValid(rag) and rag or IsValid(ent:GetNWEntity("RagdollDeath")) and ent:GetNWEntity("RagdollDeath")
			if IsValid(rag) then
				rag.wounds = var
			end
		end
	end
end)

hook.Add("OnNetVarSet","wounds_netvar2",function(index, key, var)
	if key == "arterialwounds" then
		local ent = Entity(index)
		--local ent = hg.RagdollOwner(ent) or ent
		
		if IsValid(ent) then
			if ent.arterialwounds then
				for i = 1, #ent.arterialwounds do
					if not var[i] then continue end
					var[i][5] = ent.arterialwounds[i][5]
				end
			end

			for i = 1, #var do
				if ent.arterialwounds and ent.arterialwounds[i] then continue end
				hg.queueArterialWoundSound(ent, var[i])
			end

			ent.arterialwounds = var
			local rag = IsValid(ent:GetNWEntity("FakeRagdoll")) and ent:GetNWEntity("FakeRagdoll")
			rag = IsValid(rag) and rag or IsValid(ent:GetNWEntity("RagdollDeath")) and ent:GetNWEntity("RagdollDeath")
			
			if IsValid(rag) then
				rag.arterialwounds = var
			end
		end
	end
end)

hook.Add("Player Spawn", "removewounds", function(ply)
	if OverrideSpawn then return end

	ply.wounds = {}
	ply.arterialwounds = {}

	local rag = IsValid(ply:GetNWEntity("FakeRagdoll")) and ply:GetNWEntity("FakeRagdoll")
	if IsValid(rag) then
		rag.wounds = {}
		rag.arterialwounds = {}
	end
end)

hook.Add("Fake", "huyhuyhuy235", function(ply,ragdoll)
	if not IsValid(ragdoll) then return end

	ragdoll.wounds = ply.wounds
	ragdoll.arterialwounds = ply.arterialwounds
end)

function hg.applyFountain(pos, ang, mul, mul2, forward, ent)
	if bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER then
		if math.random(2) == 1 then return end
		hg.addBloodPart2(pos, ang:Forward() * forward * 0.5 + VectorRand(-25,25) * mul2, nil, nil, nil, nil, true, nil, ent)
		hg.addBloodPart2(pos + VectorRand(-1,1), ang:Forward() * forward * 0.25 + VectorRand(-10,10) * mul2, nil, nil, nil, nil, true, nil, ent)
		//hg.addBloodPart2(pos + VectorRand(-1,1), ang:Forward() * forward * 0.25 + VectorRand(-10,10) * mul2, nil, nil, nil, nil, true, nil, ent)
	else
		hg.addBloodPart(pos, ang:Forward() * forward * 2 * math.abs(math.sin(CurTime() * 3) + math.cos(CurTime() * 5) + math.sin(CurTime() * 2) + 4) * 0.1 + ang:Right() * 15 * (math.sin(CurTime()) * 1) + ang:Right() * math.sin(CurTime() * 2) * 15 + VectorRand(-3, 3),nil,nil,nil,true)
		hg.addBloodPart(pos + VectorRand(-1,1), ang:Forward() * 55 + VectorRand(-25,25) * mul2,nil,nil,nil,nil, nil, ent)
		//hg.addBloodPart(pos + VectorRand(-1,1), ang:Forward() * 55 + VectorRand(-25,25) * mul2,nil,nil,nil,nil, nil, ent)
	end
end

local vecTorso = Vector(1, 1, 1)
local checkpulsebones = {
	["ValveBiped.Bip01_Head1"] = true,
	["ValveBiped.Bip01_R_Hand"] = true,
	["ValveBiped.Bip01_L_Hand"] = true,
}
local arteryDelayedDripSound = "arteryblooddrip/splat-blood"
local arteryDelayedDripCount = 10
local arteryNeckSlitSound = "rem_neckslit.mp3"
local arterySoundDelayMin = 1
local arterySoundDelayMax = 1.25
local arterySoundPitchMin = 95
local arterySoundPitchMax = 110
-- Per-wound rates are replicated as actual blood loss per second.  The old
-- 0.18 threshold belonged to the pre-normalized, per-think value and made even
-- tiny wounds render at maximum intensity after the rate was normalized.
local normalBleedRateVisible = 0.02
local normalBleedRateFull = 6
local normalParticleSizeThin = 0.48
local normalParticleSizeAverage = 0.7
local normalParticleSizeThick = 0.9
local hg_blood_fps = ConVarExists("hg_blood_fps") and GetConVar("hg_blood_fps") or CreateClientConVar("hg_blood_fps", 24, true, nil, "fps to draw blood", 12, 165)
local bloodDown = Vector(0, 0, -1)

local function getWoundVisualIntensity(totalBleedRate, wound, woundCount, fullRate, woundIndex, woundRates)
	local woundBleedRate = woundRates and tonumber(woundRates[woundIndex]) or tonumber(wound.visualBleedRate)
	if woundBleedRate == nil then
		woundBleedRate = math.max(totalBleedRate or 0, 0) / math.max(woundCount or 1, 1)
	end
	woundBleedRate = math.max(woundBleedRate, 0)

	-- Wound size and remaining blood reserve do not participate.  Pressure still
	-- affects how far particles travel, while this value controls only how much
	-- blood is drawn from the loss the wound is currently applying.
	local intensity = math.Clamp(
		(woundBleedRate - normalBleedRateVisible)
			/ math.max(fullRate - normalBleedRateVisible, 0.001),
		0,
		1
	)

	return intensity, woundBleedRate
end

local function getArterialVisualIntensity(org, wounds, wound, woundIndex)
	local rates = org.arterialWoundBleedRates
	local rate = rates and tonumber(rates[woundIndex])
	if rate == nil then
		local totalWeight = 0
		for _, other in pairs(wounds or {}) do
			totalWeight = totalWeight + math.max(tonumber(other[1]) or 0, 0)
		end
		local share = math.max(tonumber(wound[1]) or 0, 0) / math.max(totalWeight, 0.001)
		rate = math.max(org.arterialBleed or 0, 0) * share
	end

	return math.Clamp((rate - 0.04) / 1.2, 0, 1)
end

local function getCirculationStrength(org, pulseOverride)
	local pulse = org.heartstop and 0 or math.max(pulseOverride or org.pulse or 70, 0)
	local circulation = math.Clamp(1 - (org.hypotension or 0) + (org.hypertension or 0) * 0.2, 0, 1.55)
	if pulse <= 0 or circulation <= 0 then return 0 end
	local pulseStrength = math.Clamp(pulse / 70, 0, 1.55)

	-- Both circulation state and an effective pulse contribute to how far blood can be
	-- driven. A strong value can partly compensate for the other, but cannot hide
	-- failed circulation.
	return math.Clamp(math.sqrt(pulseStrength * circulation), 0, 1.55)
end

local function getWoundPressure(org)
	if org.heartstop then return 0, 0 end

	local pulse = math.max(tonumber(org.pulse) or 0, 0)
	local peripheralPressure = math.Clamp(1 - (tonumber(org.hypotension) or 0), 0, 1)
	local cardiacOutput = math.Clamp(tonumber(org.cardiacOutput) or peripheralPressure, 0, 1.5)
	local hypertension = math.Clamp(tonumber(org.hypertension) or 0, 0, 1)
	local pressure = math.Clamp(peripheralPressure * 0.6 + cardiacOutput * 0.4 + hypertension * 0.2, 0, 1.35)

	-- A wound has a brief, stronger outward push with each effective pulse. Low
	-- pressure or a failed pulse therefore becomes a drip instead of a jet.
	local beat = math.max(math.sin(CurTime() * pulse * math.pi / 30), 0)
	return pressure, beat
end

local function emitNormalWoundParticles(ent, pos, outward, intensity, circulation, org)
	local count = intensity >= 0.82 and 3 or intensity >= 0.48 and 2 or 1
	local pressure, beat = getWoundPressure(org)
	local pulseForce = math.Clamp((org.pulse or 0) / 70, 0, 1.5)
	-- Even a mild venous wound should leave the surface before gravity wins.
	-- Pressure and bleed intensity still decide the range, but the launch floor
	-- prevents ordinary blood from appearing to fall straight through the wound.
	local force = (10 + intensity * intensity * 44) * circulation * pressure * (0.72 + beat * 0.58) * pulseForce
	local spread = 0.8 + intensity * 5.5
	local decalWeight = Lerp(intensity, 0.45, 3)
	local particleSize = normalParticleSizeAverage
	if decalWeight <= 0.8 then
		particleSize = normalParticleSizeThin
	elseif decalWeight >= 2.2 then
		particleSize = normalParticleSizeThick
	end

	for _ = 1, count do
		local direction = outward
		if not direction or direction:LengthSqr() <= 0 then
			direction = (VectorRand(-1, 1) + Vector(0, 0, -0.7)):GetNormalized()
		end

		direction = direction:GetNormalized()
		local velocity = direction * force * math.Rand(0.9, 1.2)
			+ VectorRand(-spread, spread)
			+ bloodDown * Lerp(intensity, 0.15, 1.4)
		local particle = hg.addBloodPart(pos + VectorRand(-0.45, 0.45), velocity, nil, particleSize, particleSize, false, nil, ent)
		if particle then
			particle.decalWeight = decalWeight
			particle.gravityRampStart = CurTime() + 0.035
			particle.gravityRampEnd = CurTime() + Lerp(intensity, 0.11, 0.16)
		end
	end
end

local pitchAddClasses = {
	["furry"] = 20,
	["headcrabzombie"] = -60
}
local muffedClasses = {
	["headcrabzombie"] = true
}

local function getArterySoundEnt(ent)
	if not IsValid(ent) then return end

	local rag = ent.GetNWEntity and ent:GetNWEntity("FakeRagdoll")
	if IsValid(rag) then return rag end

	rag = ent.GetNWEntity and ent:GetNWEntity("RagdollDeath")
	if IsValid(rag) then return rag end

	return ent
end

local function getArterialWoundPos(ent, wound)
	local target = getArterySoundEnt(ent)
	if not IsValid(target) then return end

	local bone = target:LookupBone(wound[4] or "")
	if bone then
		local mat = target:GetBoneMatrix(bone)
		if mat and wound[2] and wound[3] then
			local bonePos, boneAng = mat:GetTranslation(), mat:GetAngles()
			if bonePos and boneAng then
				return LocalToWorld(wound[2], wound[3], bonePos, boneAng), target
			end
		end
	end

	return target:GetPos(), target
end

local function randomArteryPitch()
	return math.random(arterySoundPitchMin, arterySoundPitchMax)
end

local function getArteryWoundOwner(ent)
	if ent:IsPlayer() then return ent end

	local owner = ent.GetNWEntity and ent:GetNWEntity("ply")
	if not IsValid(owner) or not owner:IsPlayer() then return end

	local fakeRagdoll = owner:GetNWEntity("FakeRagdoll")
	local deathRagdoll = owner:GetNWEntity("RagdollDeath")
	if fakeRagdoll == ent or deathRagdoll == ent then return owner end
end

local function playRandomArteryDrip(ent, wound, vol)
	local pos = getArterialWoundPos(ent, wound)
	if not pos then return end

	sound.Play(arteryDelayedDripSound .. math.random(1, arteryDelayedDripCount) .. ".wav", pos, 96, randomArteryPitch(), vol or 1)
end

function hg.queueArterialWoundSound(ent, wound)
	if not IsValid(ent) or not wound then return end

	local delay = math.Rand(arterySoundDelayMin, arterySoundDelayMax)
	local artery = wound[7]
	local owner = getArteryWoundOwner(ent)
	local org = IsValid(owner) and owner.organism or ent.organism or {}
	-- Death-ragdoll netvars can arrive before the ragdoll's player link. An
	-- unknown owner must not replay the neck-slit sound for an existing corpse.
	local sourceAlive = IsValid(owner) and owner:Alive()
		or ent:IsNPC() and ent:Health() > 0
	local canPlayNeckSlit = sourceAlive and not org.otrub

	if artery == "arteria" and canPlayNeckSlit then
		local _, target = getArterialWoundPos(ent, wound)
		if IsValid(target) then
			local snd = CreateSound(target, arteryNeckSlitSound)
			if snd then
				snd:SetSoundLevel(92)
				snd:PlayEx(1, randomArteryPitch())
				snd:ChangeVolume(0, delay)
				timer.Simple(delay + 0.05, function()
					if snd then snd:Stop() end
				end)
			end
		end
	end

	timer.Simple(delay, function()
		if not IsValid(ent) then return end
		playRandomArteryDrip(ent, wound, 1)
	end)
end

emitArterialSpray = function(ent, pos, dir, ang, org, woundIndex, size, intensity, isAmputation)
	-- Upstream Z-City arterial visual (zcity/main). Each update launches one
	-- artery-marked blood trail with the original combined right/up oscillation.
	-- Give the pressure pulse enough forward speed and lift to form an arc before
	-- gravity takes over instead of immediately pouring down the body.
	local time = CurTime()
	local pulse = math.max(org.pulse or 0, 0)
	local pulseMul = pulse / 70
	local circulation = getCirculationStrength(org, pulse)
	local arterialPressureMul = circulation * (isAmputation and 1.7 or 2.5)
	if arterialPressureMul <= 0 then
		hg.addBloodPart(pos, bloodDown * 2 + VectorRand(-0.5, 0.5), nil, size, size, true, nil, ent)
		return
	end
	-- Keep the oscillation, but let forward pressure dominate enough for the
	-- arterial trail to read as a fast jet instead of a short local spray.
	-- A fully open carotid (14 bleed) reaches four times the old distance;
	-- smaller or closing arteries scale down from that using their live bleed.
	local bleedRangeMul = 1 + (isAmputation and 1 or 3) * intensity
	local forwardVelocityMul = (isAmputation and 1.55 or 2.5) * bleedRangeMul
	local upwardVelocity = 14 * math.Clamp(pulseMul, 0, 1.5)
	local velocity = (VectorRand(-1, 1) * pulseMul
		+ dir * 5 * forwardVelocityMul * (math.abs(math.sin(time * 2) + math.cos(time * (5 + woundIndex * 2)) + math.sin(time * (1 + woundIndex))) * 0.6 + math.sin(time * 2) + 4) * 0.1
		+ dir:Angle():Right() * 25 * math.sin(time * 2) * math.cos(time * 4)
		+ ang:Up() * 25 * math.sin(time * 3) * math.cos(time)
		+ vector_up * upwardVelocity
		+ VectorRand(-1, 1) * pulseMul) * arterialPressureMul

	local count = intensity >= 0.78 and 3 or intensity >= 0.42 and 2 or 1
	for _ = 1, count do
		local particle = hg.addBloodPart(pos + VectorRand(-0.35, 0.35), velocity + VectorRand(-2, 2), nil, size, size, true, nil, ent)
		if particle then particle.decalWeight = Lerp(intensity, 0.7, 4.5) end
	end
end
local hg_altberserk = GetConVar("hg_altberserk")
local hg_altnoradrenaline = GetConVar("hg_altnoradrenaline")

local function cachedClientThinkBone(ent, boneName)
	ent.ZCClientThinkBones = ent.ZCClientThinkBones or {}
	local bone = ent.ZCClientThinkBones[boneName]
	if bone == nil then
		bone = ent:LookupBone(boneName)
		ent.ZCClientThinkBones[boneName] = bone or false
	end

	return bone == false and nil or bone
end
local hg_heartbeat_volume = ConVarExists("hg_heartbeat_volume") and GetConVar("hg_heartbeat_volume") or CreateClientConVar("hg_heartbeat_volume", 1, true, nil, "heartbeat loudness", 0, 4)

hook.Add("Player-Ragdoll think", "organism-think-client-blood", function(ply, ent, time)
	--local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
	--print(ply,ent,ply.organism.owner,ply.new_organism.owner)
	local organism = ply.organism
	local new_organism = ply.new_organism
	
	local seen = ent.shouldTransmit-- and not ent.NotSeen
	local wounds = ply.wounds
	local arterialwounds = ply.arterialwounds

	local org = ent.organism

	if !org then return end


	if org and org.pulse and org.o2 and org.o2[1] then
		local pulse = org.heartbeat
		org.pulsethink = org.pulsethink or 0
		local speed = math.Clamp(org.heartbeat / 60, 1, 3.3) * 0.5 * (org.o2[1] < 8 and 0 or 1)
		org.pulsethink = org.pulsethink + (org.heartbeat > 1 and 1 or 0) * (org.holdingbreath and 0 or 1) * FrameTime() * 5.6 * (speed) * (org.lungsfunction and 1 or 0) * ((org.alive and !ent.headexploded) and 1 or 0)
		
		local torso = ent:LookupBone("ValveBiped.Bip01_Spine2")
		--local chest = ent:LookupBone("ValveBiped.Bip01_Spine1")
		
		if torso then
			if ent:GetPos():DistToSqr(lply:GetPos()) > 450 * 450 then return end
			local sin = (math.sin(org.pulsethink) + 1) * 0.5
			local amt = 0.05 * sin * math.max(org.pulse / 70, 0.5)
			
			-- Disabled bone scaling to prevent stretchiness
			-- local size = 1 + amt
			-- vecTorso[1] = size
			-- vecTorso[2] = size
			-- vecTorso[3] = size
			-- 
			-- ent:ManipulateBoneScale(torso, vecTorso)
			//ent:ManipulateBoneAngles(torso, Angle(0, amt, 0))

			vecTorso[1] = 0
			vecTorso[2] = amt * 2
			vecTorso[3] = 0
			
			if sin < 0.1 and org.analgesia <= 1.5 and not org.breathed then
				org.lastbreathed = CurTime()
				org.breathed = true
				local heartbeat = org.heartbeat or 0
				local muffed
				local pitch = math.Clamp(heartbeat / 200 * 100, 100, 100) * math.Clamp((org.stamina and org.stamina[1] and (1 + (1 - org.stamina[1] / org.stamina.max) * 0.2) or 1), 1, 1.2)
				local vol = math.Remap(heartbeat, 70, 300, 0, 0.25) + (org.stamina and org.stamina[1] and 1 - org.stamina[1] / org.stamina.max or 0)

				if ent.armors then
					muffed = ent.armors["face"] == "mask2" or ent.PlayerClassName == "Combine"
				end

				if ply.PlayerClassName and muffedClasses[ply.PlayerClassName] then
					muffed = muffedClasses[ply.PlayerClassName]
				end

				local pitchadd = 0
				if ply.PlayerClassName and pitchAddClasses[ply.PlayerClassName] then
					pitchadd = pitchAddClasses[ply.PlayerClassName]
				end

				if vol > 1.5 and ply == lply then
					local amta = (vol - 1.5)
					local ang1 = Angle(amta * -0.5, 0, 0)
					local ang2 = Angle(amta * 5, 0, 0)

					--[[ViewPunch4(ang1)
					--ViewPunch(ang1)

					timer.Simple(speed, function()
						ViewPunch4(-ang1)
						--ViewPunch(-ang2)
					end)--]]

				end

				ply:EmitSound("snds_jack_hmcd_breathing/" .. (ThatPlyIsFemale(ent) and "f" or "m") .. math.random(4) .. ".ogg", min(heartbeat * 1.0 / ( muffed and 2.5 or 4), 45), pitch + pitchadd + math.Rand(-2, 2), vol, CHAN_AUTO, 0, muffed and 16 or 0)
			elseif org.breathed and sin >= 0.1 then
				org.breathed = false
			end

			--ent:ManipulateBonePosition(torso, vecTorso)

			--local size = 1 - 0.02 * math.sin(org.pulsethink)
			--vecTorso[1] = size
			--vecTorso[2] = size
			--vecTorso[3] = size

			--ent:ManipulateBoneScale(chest, vecTorso)
		end
	end

	ply.pulse_breathe = ply.pulse_breathe or {}
	ent.pulse_breathe = ply.pulse_breathe
	
	hg.LerpVariables(FrameTime() * 10, organism, new_organism)
	
	local org = ent.organism or {}
	local owner = ent
	
	if org.pulse and org.heartbeat > 30 and (org.lastpulse or 0) + (1 / math.Clamp(org.heartbeat, 1, 600)) * 60 < CurTime() then
		org.lastpulse = CurTime()
		local pulse = org.heartbeat or 0
		local pain = org.pain or 0
		
		local dist = owner:GetPos():DistToSqr(lply:GetPos())
		local carryent = lply:GetNetVar("carryent")
		local carrybone = lply:GetNetVar("carrybone")
		local cantcheck = org.CantCheckPulse
		local checkingplayer = (IsValid(carryent) and carryent.organism == ply.organism and !cantcheck and checkpulsebones[carryent:GetBoneName(carryent:TranslateBoneToPhysBone(carrybone))])
		
		if dist < 64 * 64 and ((ply == lply and !checkingplayer) or checkingplayer) then
			local vol = checkingplayer and 2 or ((pain > 60 and ply == lply) and 1 or (pulse > 200 and ((200 - 95) / 50 + 0.12 - (pulse - 200) / 1000) or pulse > 95 and (pulse - 95) / 50 + 0.12 or 0.12))
			if not checkingplayer then
				vol = math.Clamp(vol, 0, 0.7) * hg_heartbeat_volume:GetFloat()
			end

			--ply:EmitSound("heartbeat/heartbeat_single.ogg", 55, 60, vol)
			if ent:GetVelocity():LengthSqr() < 10 then
				sound.Play("heartbeat/heartbeat_single.ogg", ply:EyePos(), 55, 60, vol * 1.5)
			else
				EmitSound("heartbeat/heartbeat_single.ogg", ply:EyePos(), ply:EntIndex(), CHAN_AUTO, vol, 55, nil, 60)
			end
		end
	end

--why? because
	if org.pulse and (ent.pulse_breathe.lastbreathe or 0) < CurTime() and org.lastbreathed and org.lastbreathed + 5 < CurTime() then
		local heartbeat = org.heartbeat or 0
		ent.pulse_breathe.lastbreathe = CurTime() + (1 / math.Clamp(org.heartbeat + (org.o2[1] - 30) * 1, 1, 120)) * 90 + ( org.o2[1] < 20 and 5 or 0)
		
		if org.analgesia <= 1.5 and org.heartbeat > 1 then
			if (ent:WaterLevel() < 3) then
				local muffed

				if ent.armors then
					muffed = ent.armors["face"] == "mask2" or ent.PlayerClassName == "Combine"
				end
				
				if org.timeValue and org.o2.curregen <= org.timeValue * 0.5 and org.o2[1] < 20 then
					ply:EmitSound("zcitysnd/real_sonar/"..(ThatPlyIsFemale(ent) and "fe" or "").."male_wheeze"..math.random(5)..".ogg", 40, nil, nil, nil, nil, 1)
				end
				if org.o2[1] < 12 and ply == lply and (ent.pulse_breathe.lastsonimcooked or 0) < CurTime() and math.random(4) == 1 then
					ply:EmitSound("sonimcooked.mp3", 45, math.random(94, 106), 0.85)
					ent.pulse_breathe.lastsonimcooked = CurTime() + math.Rand(12, 24)
				end
			else
				if org.o2[1] < 15 then
					ply:EmitSound("zcitysnd/real_sonar/"..(ThatPlyIsFemale(ent) and "fe" or "").."male_drown"..math.random(5)..".ogg", 60)
				end
			end
		end
	end

	local fountains = GetNetVar("fountains")
	if fountains and fountains[ent] then
		local tbl = fountains[ent]
		if (tbl.time or 0) < CurTime() and org.pulse then
			local mul = 1 / math.max(org.pulse / 40 * 25, 2) * 0.75
			local mul2 = math.max(org.pulse, 1) / 15
			local forward = mul2 * 150
			tbl.time = CurTime() + mul * 0.5
			
			if seen then
				local mat = ent:GetBoneMatrix(tbl.bone)

				if mat then
					local pos, ang = LocalToWorld(tbl.lpos, tbl.lang, mat:GetTranslation(), mat:GetAngles())
					
					hg.applyFountain(pos, ang, mul, mul2, forward, ent)
				end
			else
				local pos, ang = ent:GetPos(), angle_zero
				hg.applyFountain(pos, ang, mul, mul2, forward, ent)
			end
		end
	end

		if org and ent:LookupBone("ValveBiped.Bip01_Head1") then
		local brain = org.brain or 0
		org.brainmist_old = org.brainmist_old or brain
		org.brainmist_next = org.brainmist_next or 0
		if brain > org.brainmist_old and (brain - org.brainmist_old) > 0.005 and time >= org.brainmist_next then
			local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
			local headpos, headang = ent:GetBonePosition(bone)
			if headpos then
				hg.addBloodPart2(headpos + VectorRand(-2, 2), VectorRand(-35, 35) + headang:Forward() * -15, nil, math.Rand(8, 15), math.Rand(8, 15), 0.6, true, ent)
				hg.addBloodPart2(headpos + VectorRand(-2, 2), VectorRand(-25, 25), nil, math.Rand(5, 12), math.Rand(5, 12), 0.45, true, ent)
				hg.addBloodPart2(headpos + VectorRand(-2, 2), VectorRand(-20, 20), nil, math.Rand(3, 8), math.Rand(3, 8), 0.35, true, ent)
				hg.addBloodPart(headpos + VectorRand(-1, 1), VectorRand(-20, 20) + headang:Forward() * -10, nil, 2, 2, true, nil, ent)
				hg.addBloodPart(headpos + VectorRand(-1, 1), VectorRand(-25, 25), nil, 2, 2, true, nil, ent)
			end
			org.brainmist_next = time + 0.2
		end
		org.brainmist_old = brain
	end
	
	if org and org.blood and org.blood > 10 and wounds and #wounds > 0 then
		if (owner:IsPlayer() and owner:Alive()) or not owner:IsPlayer() then
			local circulation = getCirculationStrength(org)
			for i, wound in pairs(wounds) do
				local intensity, woundBleedRate = getWoundVisualIntensity(org.venousBleed, wound, #wounds, normalBleedRateFull, i, org.woundBleedRates)
				if woundBleedRate <= 0.001 then continue end
				local particleInterval = Lerp(intensity, 5, 0.16)

				if (wound[5] or 0) < time then
					local bone = wound[4]
					local boneID = wound[8]
					if not boneID or ent:GetBoneName(boneID) != bone then
						boneID = ent:LookupBone(bone)
						wound[8] = boneID
					end

					if seen and boneID then
						local should = !(hg.amputatedlimbs2[bone] and org[hg.amputatedlimbs2[bone].."amputated"])

						if !should then continue end

						local mat = ent:GetBoneMatrix(boneID)
						if not mat then return end
						local bonePos, boneAng = mat:GetTranslation(), mat:GetAngles()
						if not wound[2] or not wound[3] or not bonePos or not boneAng then return end
						local pos, ang = LocalToWorld(wound[2], wound[3], bonePos, boneAng)

						local water = bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
						if water then
							if (wound[5] or 0) + 1 < time then
								hg.addBloodPart2(pos, VectorRand(-5, 5), nil, nil, nil, nil, true, nil, ent)
							end
						else
							emitNormalWoundParticles(ent, pos, -ang:Forward(), intensity, circulation, org)
						end

						wound[5] = time + (water and 2 or particleInterval)
					else
						local pos = ent:GetPos()

						local water = bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
						if water then
							hg.addBloodPart2(pos, VectorRand(-5, 5), nil, nil, nil, nil, true, nil, ent)
						else
							emitNormalWoundParticles(ent, pos, nil, intensity, circulation, org)
						end

						wound[5] = time + (water and 2 or particleInterval)
					end
				end
			end
		end
	end
	
	if org and org.blood and org.blood > 10 and arterialwounds and #arterialwounds > 0 then
		for i, wound in pairs(arterialwounds) do
			-- Arterial blood is a continuous pressured stream.  The wound timer
			-- below already limits particle emission to the player's blood-FPS
			-- setting; a second pulse-scale gate here made every artery look like
			-- a slow drip instead of a jet.
			if (wound[5] or 0) < time then
				local bone = wound[4]
				local boneID = wound[8]
				if not boneID or ent:GetBoneName(boneID) != bone then
					boneID = ent:LookupBone(bone)
					wound[8] = boneID
				end
				if not boneID then continue end

				local pos, ang = ent:GetBonePosition(boneID)
				if (owner:IsPlayer() and owner:Alive()) or not owner:IsPlayer() then
					local intensity = getArterialVisualIntensity(org, arterialwounds, wound, i)
					local size = math.Rand(0.65, 1.25) * Lerp(intensity, 0.45, 2.1)
					if seen then

						local should = !(hg.amputatedlimbs2[bone] and org[hg.amputatedlimbs2[bone].."amputated"])

						if !should then continue end
						
						local mat = ent:GetBoneMatrix(boneID)
						if not mat then return end
						local bonePos, boneAng = mat:GetTranslation(), mat:GetAngles()
						if not wound[2] or not wound[3] or not bonePos or not boneAng then return end
						local pos = LocalToWorld(wound[2], wound[3], bonePos, boneAng)

						local dir = wound[6]
						local len = dir:Length()
						local _, dir = LocalToWorld(vector_origin, dir:Angle(), vector_origin, boneAng)
						dir = -dir:Forward() * len

						local water = bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
						if water then
							hg.addBloodPart2(pos, VectorRand(-5, 5), nil, nil, nil, nil, true, nil, ent)
						else
							emitArterialSpray(ent, pos, dir, boneAng, org, i, size, intensity, wound[9] == true)
						end

						wound[5] = time + (water and 2 or (0.5 / hg_blood_fps:GetInt()))
					else
						local pos = ent:GetPos()
						local water = bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
						if water then
							hg.addBloodPart2(pos, VectorRand(-5, 5), nil, nil, nil, nil, true, nil, ent)
						else
							hg.addBloodPart(pos, VectorRand(-15, 15), nil, size, size, true, nil, ent)
						end

						wound[5] = time + (water and 2 or 0)
					end
				end
			end
		end
	end
end)

local grub = Model("models/grub_nugget_small.mdl")
--ValveBiped.Bip01_R_Hand
--ValveBiped.Bip01_R_Forearm
--ValveBiped.Bip01_R_Foot
--ValveBiped.Bip01_R_Thigh
--ValveBiped.Bip01_R_Calf
--ValveBiped.Bip01_R_Shoulder
--ValveBiped.Bip01_R_Elbow

local vecalmostzero = Vector(0.01, 0.01, 0.01)

local modelPlacements = {
	[1] = {
		["ValveBiped.Bip01_L_Calf"] = {Vector(15.5, 0, 0), Angle(0, 90, 0)},
		["ValveBiped.Bip01_R_Calf"] = {Vector(15.5, 0, 0), Angle(0, 90, 0)},
		["ValveBiped.Bip01_R_Forearm"] = {Vector(11, 0.5, 0.5), Angle(0, 90, 0)},
		["ValveBiped.Bip01_L_Forearm"] = {Vector(11, 0.5, -0.5), Angle(0, 90, 0)},
	},
	[0] = {
		["ValveBiped.Bip01_L_Calf"] = {Vector(17.5, 0, 0), Angle(0, 90, 0)},
		["ValveBiped.Bip01_R_Calf"] = {Vector(17.5, 0, 0), Angle(0, 90, 0)},
		["ValveBiped.Bip01_R_Forearm"] = {Vector(11, 0.5, 0.5), Angle(0, 90, 0)},
		["ValveBiped.Bip01_L_Forearm"] = {Vector(11, 0, -1), Angle(0, 90, 0)},
	}
}

local limbs = {
	["lleg"] = "ValveBiped.Bip01_L_Calf",
	["rleg"] = "ValveBiped.Bip01_R_Calf",
	["larm"] = "ValveBiped.Bip01_L_Forearm",
	["rarm"] = "ValveBiped.Bip01_R_Forearm",
	["head"] = "ValveBiped.Bip01_Head1"
}

function hg.amputatedbone(ent, bone)
	if ent.organism and hg.amputatedlimbs2[bone] then
		if ent.organism[hg.amputatedlimbs2[bone].."amputated"] then
			return true
		end
	end
end

hg.amputatedlimbs = limbs

hg.amputatedlimbs2 = {}
for k, v in pairs(limbs) do
	hg.amputatedlimbs2[v] = k
end

local vecFull = Vector(1, 1, 1)

function hg.GoreCalc(ent, ply)
	local org = ent.new_organism or ent.organism
	if !org then return end

	for bone, nam in pairs(limbs) do
		if !org[bone.."amputated"] then
			local bon = ent:LookupBone(nam)

			if !ent:GetManipulateBoneScale(bon):IsEqualTol(vecFull, 0.01) then
				ent:ManipulateBoneScale(bon, vecFull)
			end

			continue
		end
		
		local bon = ent:LookupBone(nam)
		local mat = ent:GetBoneMatrix(bon)
		local mat2 = ent:GetBoneMatrix(bon - 1)
		mat:SetScale(vecalmostzero)
		
		hg.bone_apply_matrix(ent, bon, mat)
		
		if IsValid(ply.OldFakeRagdoll) then
			hg.bone_apply_matrix(ply, bon, mat)
		end

		local fem = ThatPlyIsFemale(ent) and 1 or 0
		
		if !modelPlacements[fem][nam] then continue end

		local pos, ang = LocalToWorld(modelPlacements[fem][nam][1], modelPlacements[fem][nam][2], mat2:GetTranslation(), mat2:GetAngles())
		
		if !IsValid(headboom_mdl) then
			headboom_mdl = ClientsideModel(grub)
			headboom_mdl:SetNoDraw(true)
			headboom_mdl:SetSubMaterial(0, "models/flesh")
			headboom_mdl:SetModelScale(0.8)
		end
		
		headboom_mdl:SetRenderOrigin(pos)
		headboom_mdl:SetRenderAngles(ang)
		headboom_mdl:SetupBones()
		headboom_mdl:DrawModel()
	end
end

local prank = {}
local time_troll = 100

local DontCallMe = false
hook.Add("HG.InputMouseApply","zzzzzzzzzzzzbrain_death",function(tbl)
	 

	if lply:Alive() and lply.organism and (lply.organism.brain or 0) > 0.1 then
		if #prank < time_troll then table.insert(prank,1,{tbl.x,tbl.y}) end
		if #prank >= time_troll then table.remove(prank,#prank) end
		
		local amt = lply.organism.brain / 0.3

		local xa = Lerp(1 * amt,tbl.x,prank[#prank][1])// + math.sin(CurTime() / 5) * amt * 10
		local ya = Lerp(1 * amt,tbl.y,prank[#prank][2])// + math.cos(CurTime() / 5) * math.sin(CurTime() / 2) * amt * 10

		tbl.angle.pitch = math.Clamp(tbl.angle.pitch + tbl.y / 100 + ya / 100, -89, 89)
		tbl.angle.yaw = tbl.angle.yaw - tbl.x / 100 - xa / 100
		tbl.override_angle = true
	end

	--[[local actwep = LocalPlayer():GetActiveWeapon()
	if not actwep or not actwep.GetTrace then return end
	local hitpos,pos,ang = actwep:GetTrace()

	local ply = hg.GetCurrentCharacter(Entity(2))
	local dist = ply:EyePos():Distance(LocalPlayer():EyePos())
	ply:SetupBones()
	scr = ply:GetBoneMatrix(ply:LookupBone("ValveBiped.Bip01_Head1")):GetTranslation():ToScreen()

	angle.pitch = math.Clamp(angle.pitch + (scr.y - (pos+ang:Forward() * dist):ToScreen().y) / 50, -89, 89)
	angle.yaw = angle.yaw - (scr.x - (pos+ang:Forward() * dist):ToScreen().x) / 50
	cmd:SetViewAngles(angle)

	return true--]]
end)
