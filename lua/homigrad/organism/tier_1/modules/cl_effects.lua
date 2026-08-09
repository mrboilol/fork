local hg = hg or {}
if CLIENT then
	print("Concussion module loaded.")
end
local concussion_smooth = 0
local concussion_sound = nil
local concussion_color_tab = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}
local function clear_concussion_effects(ply, instant)
	concussion_smooth = 0
	if IsValid(ply) and ply.hg_concussion_dsp then
		ply:SetDSP(0, false)
		ply.hg_concussion_dsp = nil
	end
	if concussion_sound then
		if instant then
			concussion_sound:Stop()
		else
			concussion_sound:FadeOut(1.4)
		end
		concussion_sound = nil
	end
end
hook.Add("HG_OrganismClientReset", "hg_concussion_reset", function(ply)
	if ply ~= LocalPlayer() then return end
	clear_concussion_effects(ply, true)
end)
hook.Add("RenderScreenspaceEffects", "hg_concussion_effects", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		clear_concussion_effects(ply, true)
		return
	end
	local org = ply.organism
	if not org then
		clear_concussion_effects(ply, true)
		return
	end
	local concussion = org.concussion or 0
	local smoothSpeed = concussion > concussion_smooth and 8 or 1.4
	concussion_smooth = math.Approach(concussion_smooth, concussion, FrameTime() * smoothSpeed)
	if (concussion <= 0 and concussion_smooth <= 0.01) or org.otrub then
		clear_concussion_effects(ply, false)
		return
	end
	if concussion_smooth > 0 then
		if not concussion_sound then
			local soundPath = "shellshock/" .. math.random(1, 3) .. ".mp3"
			concussion_sound = CreateSound(ply, soundPath)
			concussion_sound:Play()
		end
		if concussion_sound then
			local vol = math.Clamp(concussion_smooth / 5, 0, 1)
			concussion_sound:ChangeVolume(vol, 0.1)
		end
	end
	if concussion_smooth > 1 then
		if ply.hg_concussion_dsp != 14 then
			ply:SetDSP(14, false)
			ply.hg_concussion_dsp = 14
		end
	else
		if ply.hg_concussion_dsp == 14 then
			ply:SetDSP(0, false)
			ply.hg_concussion_dsp = nil
		end
	end
	if concussion_smooth <= 0.35 then return end
	local intensity = math.Clamp((concussion_smooth - 0.35) / 4.5, 0, 1)
	local pulse = math.ease.InOutSine((math.sin(CurTime() * (2.4 + intensity * 3.2)) + 1) * 0.5)
	local horizontal_blur = 8 + (intensity * 18)
	local darken = 0.04 * intensity
	local multiply = 0.85 * intensity + pulse * 0.2
	local color_mul = 0.18
	DrawBloom(darken, multiply, horizontal_blur, 0, 1, color_mul, 134/255, 210/255, 240/255)
	concussion_color_tab["$pp_colour_brightness"] = -0.01 - intensity * 0.055
	concussion_color_tab["$pp_colour_contrast"] = 1 - intensity * 0.08
	concussion_color_tab["$pp_colour_colour"] = 1 - intensity * 0.42
	concussion_color_tab["$pp_colour_addr"] = 0.008 * pulse * intensity
	DrawColorModify(concussion_color_tab)
end)
hg.undernoradrenaline = hg.undernoradrenaline or false
hg.noradrenalineStartTime = hg.noradrenalineStartTime or 0
hg.noradrenalineStation = hg.noradrenalineStation or nil
local tab = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1,
	[ "$pp_colour_colour" ] = 1,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}
local tab2 = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1,
	[ "$pp_colour_colour" ] = 1,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}
local cc = Material( "effects/shaders/merc_chromaticaberration" )
hook.Add("RenderScreenspaceEffects", "noradrenalineEffect", function()
	local organism = lply:Alive() and lply.organism
	if !organism then
		if hg.undernoradrenaline then
			hg.DynamicMusicV2.Player.Stop()
		end
		hg.undernoradrenaline = false
		hg.noradrenalineIntensity = 0
		return
	end
	local noradrenaline = (organism.noradrenaline or 0)
	local noradrenalineClamped = math.Clamp(noradrenaline, 0, 3) * (organism.consciousness or 1)
	hg.noradrenalineClamped = noradrenalineClamped
	if noradrenaline > 0.0001 and !hg.undernoradrenaline then
		hg.undernoradrenaline = true
		surface.PlaySound("shitty/music/mi_deathcam.mp3")
		hg.DynamicMusicV2.Player.Start("overdose")
		hg.noradrenalineStartTime = SysTime()
		for i = 1, 90 do
			timer.Simple(i/120,function()
				ViewPunch(AngleRand(-1,1))
			end)
		end
	elseif noradrenaline < 0.0001 then
		if hg.undernoradrenaline then
			hg.DynamicMusicV2.Player.Stop()
		end
		hg.noradrenalineIntensity = 0
		hg.undernoradrenaline = false
	end
end)
local grainMat = CreateMaterial("grain2noradrenaline", "screenspace_general",{
	["$pixshader"] = "zb_grain2_ps20b",
	["$basetexture"] = "_rt_FullFrameFB",
	["$texture1"] = "stickers/steamhappy",
	["$texture2"] = "",
	["$texture3"] = "",
	["$ignorez"] = 1,
	["$vertexcolor"] = 1,
	["$vertextransform"] = 1,
	["$copyalpha"] = 1,
	["$alpha_blend_color_overlay"] = 0,
	["$alpha_blend"] = 1,
	["$linearwrite"] = 1,
	["$linearread_basetexture"] = 1,
	["$linearread_texture1"] = 1,
	["$linearread_texture2"] = 1,
	["$linearread_texture3"] = 1,
})
hook.Add("Post Post Processing", "noradrenalineEffect", function()
	if hg.undernoradrenaline and hg.noradrenalineClamped then
		render.UpdateScreenEffectTexture()
		render.UpdateFullScreenDepthTexture()
		local start = math.Clamp((SysTime() - hg.noradrenalineStartTime) * 2, 0, 1) * lply.organism.noradrenaline
		local asad = math.sin(CurTime() * 10) / 4
		grainMat:SetFloat("$c0_x", CurTime() * start)
		grainMat:SetFloat("$c0_y", asad * start)
		grainMat:SetFloat("$c0_z", 1)
		grainMat:SetFloat("$c1_x", (0.2 * hg.noradrenalineClamped) * start)
		grainMat:SetFloat("$c1_y", 0.6 * start)
		grainMat:SetFloat("$c1_z", (0.2 * asad) * start)
		grainMat:SetFloat("$c2_x", 0)
		grainMat:SetFloat("$c2_y", 2 * start)
		grainMat:SetFloat("$c2_z", 6 * start)
		grainMat:SetFloat("$c3_x", 0)
		render.SetMaterial(grainMat)
		render.DrawScreenQuad()
	end
end)
local META = FindMetaTable("Player")
function META:IsStimulated()
	if !self:Alive() then return false end
	return hg.undernoradrenaline or false
end
local META2 = FindMetaTable("Entity")
function META2:IsStimulated()
	return false
end
hg.underberserk = hg.underberserk or false
hg.underberserk2 = hg.underberserk2 or false
hg.berserkStartTime = hg.berserkStartTime or 0
hg.berserkStartTime2 = hg.berserkStartTime2 or 0
hg.berserkStation = hg.berserkStation or nil
hg.berserkMusicPlayed = hg.berserkMusicPlayed or false
hg.berserkMusicLoading = hg.berserkMusicLoading or false
hg.berserkFadeOut = hg.berserkFadeOut or false
hg.berserkFadeOutStartTime = hg.berserkFadeOutStartTime or 0
hg.berserkLastActivationTime = hg.berserkLastActivationTime or 0

local tab = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1,
	[ "$pp_colour_colour" ] = 1,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}
local tab2 = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1,
	[ "$pp_colour_colour" ] = 1,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}
local cc = Material( "effects/shaders/merc_chromaticaberration" )
local offset = CreateClientConVar("berserk_offset", "0.85", true, false, "Set berserk music offset from start", 0, 5)
local bpm = CreateClientConVar("berserk_bpm", "70", true, false, "Set berserk effect bpm", 1, 280)
local path = CreateClientConVar("berserk_path", "sound/zbattle/pharmacia.mp3", true, false, "Set berserk effect music path")
-- These replicated convars are created by sv_berserk.lua, so an admin's
-- setting selects the alternate mode for every connected client.
local altberserk = GetConVar("hg_altberserk") or CreateClientConVar("hg_altberserk", "0", true, false, "Enable alternative berserk mode", 0, 1)
local altberserk3 = GetConVar("hg_altberserk3") or CreateClientConVar("hg_altberserk3", "0", true, false, "Enable alternative berserk mode 3", 0, 1)

local function isAlternativeBerserk()
	return altberserk:GetBool() or altberserk3:GetBool()
end

local function getBerserkMusicPath()
	if altberserk3:GetBool() then return "sound/rage.ogg" end
	if altberserk:GetBool() then return "sound/NIGGARUN.ogg" end

	return path:GetString()
end

local function getBerserkBPM()
	if altberserk3:GetBool() then return 75 end
	if altberserk:GetBool() then return 88 end

	return bpm:GetInt()
end

local function startBerserkMusic(musicPath)
	if IsValid(hg.berserkStation) then
		hg.berserkStation:EnableLooping(true)
		hg.berserkStation:SetVolume(1)
		hg.berserkFadeOut = false
		hg.berserkMusicPlayed = true
		return
	end

	if hg.berserkMusicLoading then return end

	hg.berserkMusicLoading = true
	hg.berserkMusicPlayed = true
	sound.PlayFile(musicPath, "noblock", function(channel)
		hg.berserkMusicLoading = false

		if not IsValid(channel) then
			hg.berserkMusicPlayed = false
			return
		end

		if not hg.underberserk and not hg.underberserk2 then
			channel:Stop()
			hg.berserkMusicPlayed = false
			return
		end

		hg.berserkStation = channel
		channel:EnableLooping(true)
		channel:SetVolume(1)
		hg.berserkFadeOut = false
	end)
end

hook.Add("RenderScreenspaceEffects", "berserkEffect", function()
	local organism = lply:Alive() and lply.organism
	if !organism then
		hg.underberserk = false
		hg.underberserk2 = false

		if IsValid(hg.berserkStation) then hg.berserkStation:Stop() end
		hg.berserkStation = nil
		hg.berserkFadeOut = false
		hg.berserkMusicPlayed = false

		hg.notificationFont = "HuyFont"
		hg.berserkIntensity = 0
		return
	end
	local berserk = (organism.berserk or 0)
	local berserkClamped = math.Clamp(berserk, 0, 3) * (organism.consciousness or 1)
	if berserk > 0.0001 and (!hg.underberserk and !hg.underberserk2) then
		-- Prevent re-activation within 15 seconds of last activation
		if SysTime() - hg.berserkLastActivationTime < 15 then
			return
		end

		hg.underberserk = true
		hg.berserkMusicPlayed = false
		hg.berserkLastActivationTime = SysTime()
		if not hg.berserkActivationSoundPlayed then
			hg.berserkActivationSoundPlayed = true
			if isAlternativeBerserk() then
				-- Start looping music immediately for alternate modes to avoid duplicate playback.
				startBerserkMusic(getBerserkMusicPath())
			else
				surface.PlaySound("zbattle/deathsample.ogg")
			end
		end

		hg.berserkStartTime = SysTime()
		local part = CreateParticleSystem( LocalPlayer(), "[2]sparkle1", PATTACH_POINT_FOLLOW, 1)
		hg.currentNotification = nil
		hg.notifications = {}
		hg.CreateNotificationBerserk("I feel...")

		local disorientedDuration = altberserk3:GetBool() and 0 or altberserk:GetBool() and 11 or 3.95
		timer.Simple(disorientedDuration, function()
			if IsValid(part) then
				part:StopEmission( false, true, false )
			end

			for i = 1, 30 do
				timer.Simple(i/120,function()
					ViewPunch(AngleRand(-1,1))
				end)
			end
			hg.underberserk = false
			hg.underberserk2 = true

			-- Prevent music from playing again if it already played during this berserk session
			if not hg.berserkMusicPlayed then
				startBerserkMusic(getBerserkMusicPath())
			elseif IsValid(hg.berserkStation) then
				hg.berserkStation:EnableLooping(true)
				hg.berserkStation:SetVolume(1)
				hg.berserkFadeOut = false
			end

			hg.currentNotification = nil
			hg.notifications = {}
			hg.CreateNotificationBerserk("GREAT.")
			hg.berserkStartTime2 = SysTime()
		end)
	elseif berserk < 0.0001 then
		hg.underberserk = false
		hg.underberserk2 = false
		hg.berserkActivationSoundPlayed = false
		hg.berserkLastActivationTime = 0
		if IsValid(hg.berserkStation) then hg.berserkStation:Stop() end
		hg.berserkStation = nil
		hg.berserkFadeOut = false
		hg.berserkMusicPlayed = false

		hg.notificationFont = "HuyFont"
		hg.berserkIntensity = 0
	end
	if hg.underberserk then
		local intensity = (SysTime() - hg.berserkStartTime)
		local altMultiplier = isAlternativeBerserk() and 0.25 or 1
		tab[ "$pp_colour_contrast" ] = (intensity / 4) * altMultiplier
		tab[ "$pp_colour_addr" ] = (intensity / 20) * altMultiplier
		tab[ "$pp_colour_brightness" ] = (intensity / 20) * altMultiplier
		DrawColorModify(tab)
		DrawBloom( 0.65, (intensity * 2) * altMultiplier, 9, 9, 1, 1, (intensity / 32) * altMultiplier, 0.2, 0.2 )

		render.UpdateScreenEffectTexture()
			cc:SetFloat("$c0_x", ((3.5 - intensity) * altMultiplier) * 1.5)
			cc:SetInt("$c0_y", 1)
			render.SetMaterial(cc)
		render.DrawScreenQuad()
	end
	if hg.underberserk2 and IsValid(hg.berserkStation) then
		--local intensity = ((hg.berserkStartTime2 + SysTime()) / 60) * 70 % 1
		--intensity = math.abs(math.cos(1 - (intensity * 2))) * berserkClamped
		local currentBpm = getBerserkBPM()
		local stationTime = hg.berserkStation:GetTime()
		local intensity = 1 - ((stationTime - offset:GetFloat()) / 60 * currentBpm)
		-- Guard against NaN from invalid station time
		if intensity ~= intensity then intensity = 0 end
		intensity = (intensity - math.Round(intensity)) % 1
		intensity = math.Clamp((intensity * 0.25 + 0.75), 0, 1)
		intensity = math.ease.InExpo(intensity) * berserkClamped * 2--math.abs(math.cos(1 - (intensity * 2))) * berserkClamped
		-- Guard against NaN from easing function
		if intensity ~= intensity then intensity = 0 end

		tab2[ "$pp_colour_mulr" ] = (1.5 * math.min(1, berserk * 4)) + (intensity / 5)
		tab2[ "$pp_colour_addr" ] = (0.1 * math.min(1, berserk * 4)) + intensity / 64
		tab2[ "$pp_colour_colour" ] = 1 - math.Clamp(intensity, 0, 0.9)
		tab2[ "$pp_colour_mulg" ] = 0
		tab2[ "$pp_colour_mulb" ] = 0
		DrawColorModify(tab2)
		DrawBloom( 0.65, intensity, 9, 9, 1, 1, intensity / 16, 0.2, 0.2 )
		hg.notificationFont = "BerserkFont"
		hg.berserkIntensity = intensity
		hg.berserkClamped = berserkClamped
	end
	if IsValid(hg.berserkStation) then
		if hg.berserkFadeOut then
			local fadeProgress = (SysTime() - hg.berserkFadeOutStartTime) / 30
			local volume = math.max(0, 1 - fadeProgress)
			hg.berserkStation:SetVolume(volume)
			if fadeProgress >= 1 then
				hg.berserkStation:Stop()
				hg.berserkStation = nil
				hg.berserkFadeOut = false
				hg.berserkMusicPlayed = false
			end
		else
			hg.berserkStation:SetVolume(math.min(1, (organism.otrub and 0) or berserkClamped))
		end
	end
end)
local grainMat = CreateMaterial("grain2berserk","screenspace_general",{
	["$pixshader"] = "zb_grain2_ps20b",
	["$basetexture"] = "_rt_FullFrameFB",
	["$texture1"] = "stickers/steamhappy",
	["$texture2"] = "",
	["$texture3"] = "",
	["$ignorez"] = 1,
	["$vertexcolor"] = 1,
	["$vertextransform"] = 1,
	["$copyalpha"] = 1,
	["$alpha_blend_color_overlay"] = 0,
	["$alpha_blend"] = 1,
	["$linearwrite"] = 1,
	["$linearread_basetexture"] = 1,
	["$linearread_texture1"] = 1,
	["$linearread_texture2"] = 1,
	["$linearread_texture3"] = 1,
})
hook.Add("Post Post Processing", "berserkEffect", function()
	if hg.underberserk2 and hg.berserkClamped then
		render.UpdateScreenEffectTexture()
		render.UpdateFullScreenDepthTexture()
		grainMat:SetFloat("$c0_x", CurTime())
		grainMat:SetFloat("$c0_y", 0.5)
		grainMat:SetFloat("$c0_z", 2)
		grainMat:SetFloat("$c1_x", 0.2 * hg.berserkClamped)
		grainMat:SetFloat("$c1_y", 1.5)
		grainMat:SetFloat("$c1_z", 0.2)
		grainMat:SetFloat("$c2_x", 6)
		grainMat:SetFloat("$c2_y", 0)
		grainMat:SetFloat("$c2_z", 0)
		grainMat:SetFloat("$c3_x", 0)
		render.SetMaterial(grainMat)
		render.DrawScreenQuad()
	end
end)
hook.Add("HG_CalcView","InsaneRollCam",function(ply, origin, angles, fova)
	if ply:Alive() and hg.underberserk2 and IsValid(hg.berserkStation) and hg.berserkClamped then
		local currentBpm = getBerserkBPM()
		local stationTime = hg.berserkStation:GetTime()
		local intensity = 1 - ((stationTime - offset:GetFloat()) / 60 * currentBpm)
		-- Guard against NaN
		if intensity ~= intensity then intensity = 0 end
		if hg.berserkIntensity ~= hg.berserkIntensity then hg.berserkIntensity = 0 end
		if hg.berserkClamped ~= hg.berserkClamped then hg.berserkClamped = 0 end
		
		angles[1] = angles[1] - hg.berserkIntensity * 0.2
		angles[3] = math.cos(CurTime() * 0.3) * hg.berserkClamped + hg.berserkIntensity * 2 * (intensity % 2 > 1 and 1 or -1)
		fova[1] = fova[1] + hg.berserkIntensity * -2
	end
end)
local META = FindMetaTable("Player")
function META:IsBerserk()
	if !self:Alive() then return false end

	return hg.underberserk2 or false
end
local META2 = FindMetaTable("Entity")
function META2:IsBerserk()
	return false
end
local HM_sky_material = CreateMaterial("g_sky_HMFrf", "g_Sky", {
	["$topcolor"]      = "[1 0 0.5]",
	["$bottomcolor"]   = "[0 0 1]",
	["$fadebias"]      = "1.0",
	["$hdrscale"]      = "0.25",
	["$duskcolor"]     = "[1 0.3 0.25]",
	["$duskscale"]     = "0.5",
	["$duskintensity"] = "5.0",
	["$sunnormal"]     = "[0 1 1]",
	["$suncolor"]      = "[0 1 1]",
	["$sunsize"]       = "5",
	["$startexture"]   = "skybox/starfield",
	["$starfade"]      = "0",
	["$starscale"]     = "1",
	["$starpos"]       = "1",
	["$starlayers"]    = "4",
})
local maxs = Vector(64, 64, 64)
local mins = -maxs
local matGlow = Material("Sprites/light_glow02_add_noz")
local red = Color(255, 58, 84)
local blue = Color(47, 0, 255)
hook.Add("PostDrawTranslucentRenderables", "berserkSky", function(depth, drawsky, sky3d)
	if !hg.underberserk2 then return end
	if !drawsky then
		cam.Start3D()
			for _, ply in player.Iterator() do
				if ply == LocalPlayer() then continue end
				local distance = ply:GetPos():DistToSqr(EyePos())
				local pos = (IsValid(ply.FakeRagdoll) and ply.FakeRagdoll:WorldSpaceCenter()) or ply:WorldSpaceCenter()
				render.SetMaterial(matGlow)
				local size = 20 * hg.berserkIntensity * (distance / 3000000)
				if size > 1 then
					render.DrawSprite(pos, size * 3, size, red)
					render.DrawSprite(pos, size, size * 3, red)
				end
			end
		cam.End3D()
	end
	if (drawsky or sky3d) then
		local sun_info = util.GetSunInfo()
		if sun_info != nil then HM_sky_material:SetVector("$sunnormal", sun_info.direction) end
		HM_sky_material:SetFloat("$duskscale",math.abs(math.sin(CurTime()*1.5))*1)
		-- Fix division by zero / NaN
		local duskIntensity = 0
		if hg.berserkIntensity and hg.berserkIntensity > 0.001 then
			duskIntensity = 0.2 * hg.berserkIntensity / (hg.berserkIntensity / 3)
		end
		HM_sky_material:SetFloat("$duskintensity", duskIntensity)

		--print(hg.berserkIntensity)
		cam.Start3D(vector_origin, EyeAngles())
			render.SetMaterial(HM_sky_material)
			cam.IgnoreZ(true)
			cam.IgnoreZ(false)
		cam.End3D()
	end
end)

hook.Add("Player_Death", "berserkCleanup", function(ply)
	if ply ~= LocalPlayer() then return end

	hg.underberserk = false
	hg.underberserk2 = false
	hg.berserkActivationSoundPlayed = false
	hg.berserkMusicLoading = false
	hg.berserkMusicPlayed = false
	hg.berserkFadeOut = false

	if IsValid(hg.berserkStation) then
		hg.berserkStation:Stop()
		hg.berserkStation = nil
	end

	hg.notificationFont = "HuyFont"
	hg.berserkIntensity = 0
	hg.berserkClamped = 0
end)
