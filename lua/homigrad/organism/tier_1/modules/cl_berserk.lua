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
local altberserk = CreateClientConVar("hg_altberserk", "0", true, false, "Enable alternative berserk mode (11s disoriented, NIGGARUN.ogg, 88 BPM)", 0, 1)
local altberserk3 = CreateClientConVar("hg_altberserk3", "0", true, false, "Enable alternative berserk mode 3 (immediate rage.ogg loop and 75 BPM effect)", 0, 1)

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

		if IsValid(hg.berserkStation) and not hg.berserkFadeOut then
			hg.berserkFadeOut = true
			hg.berserkFadeOutStartTime = SysTime()
		end

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
		if IsValid(hg.berserkStation) and not hg.berserkFadeOut then
			hg.berserkFadeOut = true
			hg.berserkFadeOutStartTime = SysTime()
		end

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
		--intensity = math.sqrt(math.sqrt(intensity))
		intensity = math.Clamp((intensity * 0.25 + 0.75), 0, 1)
		intensity = math.ease.InExpo(intensity) * berserkClamped * 2--math.abs(math.cos(1 - (intensity * 2))) * berserkClamped
		-- Guard against NaN from easing function
		if intensity ~= intensity then intensity = 0 end

		tab2[ "$pp_colour_mulr" ] = (1.5 * math.min(1, berserk * 4)) + (intensity / 5)
		tab2[ "$pp_colour_addr" ] = (0.1 * math.min(1, berserk * 4)) + intensity / 64
		-- tab[ "$pp_colour_contrast" ] = 1 + intensity / 8

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
		
		grainMat:SetFloat("$c0_x", CurTime()) -- time
		grainMat:SetFloat("$c0_y", 0.5) -- gate
		grainMat:SetFloat("$c0_z", 2) -- Pixelize
		grainMat:SetFloat("$c1_x", 0.2 * hg.berserkClamped) -- lerp
		grainMat:SetFloat("$c1_y", 1.5) -- vignette intensity
		grainMat:SetFloat("$c1_z", 0.2) -- BlurIntensity
		grainMat:SetFloat("$c2_x", 6) -- r
		grainMat:SetFloat("$c2_y", 0) -- g
		grainMat:SetFloat("$c2_z", 0) -- b
		grainMat:SetFloat("$c3_x", 0) -- ImageIntensity
	
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
		--print(fova)
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
--local alphacolor = Color(255,255,255,255)

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
		--alphacolor.a = hg.berserkIntensity
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
				--render.DrawBox(vector_origin, angle_zero, maxs, mins, color_white)
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

