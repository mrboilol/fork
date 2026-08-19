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
		surface.PlaySound("shitty/music/mi_deathcam.ogg")
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
-- Berserk rendering/music lives in modules/cl_berserk.lua.  An older copy used to
-- live here with the same hook IDs, which overwrote alternate-berserk soundtrack
-- selection depending on module load order.

--// Overdose visual effects
local overdose_smooth = 0
local overdose_color_tab = {
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
hook.Add("HG_OrganismClientReset", "hg_overdose_reset", function(ply)
	if ply ~= LocalPlayer() then return end
	overdose_smooth = 0
end)
hook.Add("RenderScreenspaceEffects", "overdoseEffect", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		overdose_smooth = 0
		return
	end
	local org = ply.organism
	if not org or org.otrub then
		overdose_smooth = 0
		return
	end

	local analgesia = org.analgesia or 0
	local painkiller = org.painkiller or 0
	local overdosed = analgesia > 1.5 or painkiller > 2.4
	overdose_smooth = math.Approach(overdose_smooth, overdosed and 1 or 0, FrameTime() * 2.5)
	if overdose_smooth < 0.01 then return end

	local strength = math.Clamp((math.max(analgesia, painkiller / 1.6) - 1.5) / 1.5, 0, 1)
	local i = overdose_smooth * (0.55 + strength * 0.45)

	local t = CurTime()
	ViewPunch(Angle(
		math.sin(t * 2.3) * i * 0.7,
		math.cos(t * 1.9) * i * 0.9,
		math.sin(t * 1.1 + 1) * i * 0.5
	))

	if i > 0.05 then
		DrawToyTown(2, i * 0.4 * ScrH())
	end
	if strength > 0.4 then
		DrawMotionBlur(0.08 * i, 0.25 * i, 0.02)
	end

	overdose_color_tab["$pp_colour_colour"] = 1 - i * 0.3
	overdose_color_tab["$pp_colour_brightness"] = i * 0.05
	overdose_color_tab["$pp_colour_contrast"] = 1 + i * 0.12
	DrawColorModify(overdose_color_tab)

	DrawBloom(0.05 * i, 0.9 * i, 9 * i, 5 * i, 1, 1, 0.55, 0.7, 1)
end)
