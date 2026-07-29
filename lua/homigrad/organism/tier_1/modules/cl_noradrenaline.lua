hg.undernoradrenaline = hg.undernoradrenaline or false
hg.noradrenalineStartTime = hg.noradrenalineStartTime or 0
hg.noradrenalineStation = hg.noradrenalineStation or nil
hg.noradrenalineAltStartTime = hg.noradrenalineAltStartTime or 0
hg.noradrenalineAltActive = hg.noradrenalineAltActive or false
hg.noradrenalineFadeOut = hg.noradrenalineFadeOut or false
hg.noradrenalineFadeOutStartTime = hg.noradrenalineFadeOutStartTime or 0

local altnoradrenaline = CreateClientConVar("hg_altnoradrenaline", "0", true, false, "Enable alternative noradrenaline mode (11s delay, 88 BPM heartbeat)", 0, 1)

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
		if hg.undernoradrenaline and not hg.noradrenalineFadeOut then
			hg.noradrenalineFadeOut = true
			hg.noradrenalineFadeOutStartTime = SysTime()
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

		if altnoradrenaline:GetBool() then
			if IsValid(hg.noradrenalineStation) then
				hg.noradrenalineStation:SetVolume(1)
				hg.noradrenalineFadeOut = false
			else
				sound.PlayFile("sound/NIGGARUN.ogg", "noblock", function(channel)
					hg.noradrenalineStation = channel
					channel:EnableLooping(true)
					channel:SetVolume(1)
				end)
			end
		else
			if hg.DynamicMusicV2 and hg.DynamicMusicV2.Player then
				hg.DynamicMusicV2.Player.Start("overdose")
				hg.DynamicMusicV2.Player.SetVolume(1)
				hg.noradrenalineFadeOut = false
			else
				hg.DynamicMusicV2.Player.Start("overdose")
			end
		end

		hg.noradrenalineStartTime = SysTime()

		if altnoradrenaline:GetBool() then
			hg.noradrenalineAltStartTime = SysTime()
			hg.noradrenalineAltActive = false
		end

	elseif noradrenaline < 0.0001 then
		if hg.undernoradrenaline then
			if altnoradrenaline:GetBool() and IsValid(hg.noradrenalineStation) and not hg.noradrenalineFadeOut then
				hg.noradrenalineFadeOut = true
				hg.noradrenalineFadeOutStartTime = SysTime()
			elseif not altnoradrenaline:GetBool() and not hg.noradrenalineFadeOut then
				hg.noradrenalineFadeOut = true
				hg.noradrenalineFadeOutStartTime = SysTime()
			end
		end

		hg.noradrenalineIntensity = 0

		hg.undernoradrenaline = false
		hg.noradrenalineAltActive = false
	end

	-- Check if 11 seconds have passed for alt mode
	if altnoradrenaline:GetBool() and hg.undernoradrenaline and not hg.noradrenalineAltActive then
		if SysTime() - hg.noradrenalineAltStartTime >= 11 then
			hg.noradrenalineAltActive = true
		end
	end

	-- Handle fade out for noradrenaline music (slower fade: 30 seconds)
	if hg.noradrenalineFadeOut then
		local fadeProgress = (SysTime() - hg.noradrenalineFadeOutStartTime) / 30
		if altnoradrenaline:GetBool() and IsValid(hg.noradrenalineStation) then
			local volume = math.max(0, 1 - fadeProgress)
			hg.noradrenalineStation:SetVolume(volume)
			if fadeProgress >= 1 then
				hg.noradrenalineStation:Stop()
				hg.noradrenalineStation = nil
				hg.noradrenalineFadeOut = false
			end
		elseif not altnoradrenaline:GetBool() and hg.DynamicMusicV2 and hg.DynamicMusicV2.Player then
			local volume = math.max(0, 1 - fadeProgress)
			hg.DynamicMusicV2.Player.SetVolume(volume)
			if fadeProgress >= 1 then
				hg.DynamicMusicV2.Player.Stop()
				hg.noradrenalineFadeOut = false
			end
		end
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

hook.Add("Player_Death", "noradrenalineCleanup", function(ply)
	if ply ~= LocalPlayer() then return end

	if hg.undernoradrenaline and not hg.noradrenalineFadeOut then
		hg.noradrenalineFadeOut = true
		hg.noradrenalineFadeOutStartTime = SysTime()
	end

	hg.undernoradrenaline = false
	hg.noradrenalineAltActive = false
	hg.noradrenalineIntensity = 0
	hg.noradrenalineClamped = 0
end)
