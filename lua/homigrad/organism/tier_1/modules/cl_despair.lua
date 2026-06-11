local despairFont = "ZCity_Despair_Text"
if hg and hg.despair_builtin then return end
local despair_font = function()
	return "Mx437 IBM PS/55 re."
end
surface.CreateFont(despairFont, {
	font = despair_font(),
	size = ScreenScaleH(20),
	weight = 700,
	antialias = true
})

local heatMat = Material("effects/shaders/zb_heat")
local chromaticMat = Material("effects/shaders/merc_chromaticaberration")
local vignetteMat = Material("effects/shaders/zb_vignette")
local despairTab = {
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

local despairLerp = 0
local despairTextLerp = 0
local despairSound
local despairSoundVol = 0
local despairSoundLoading = false
local panicSound
local panicSoundVol = 0
local panicSoundLoading = false
local panicThoughtLerp = 0

local panicThoughts = {
	"Im hopeless.",
	"boi im cooked 😭",
	"I dont want to be here anymore.",
	"Everything is wrong.",
	"I cant take this anymore.",
	"Why wont it stop...",
	"Why is this happening to me...",
	"I'm losing control.",
	"Help me...",
	"This is not real...",
}

local function get_target_organism()
	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return nil end
	if IsValid(ply:GetNWEntity("spect")) then return nil end
	if not ply:Alive() then return nil end
	return ply.new_organism or ply.organism
end

local function stop_despair_sound(force)
	if not IsValid(despairSound) then return end
	if force then
		despairSound:Stop()
		despairSound = nil
		despairSoundVol = 0
		return
	end
	despairSoundVol = math.max(despairSoundVol - FrameTime() * 0.4, 0)
	despairSound:SetVolume(despairSoundVol)
	if despairSoundVol <= 0.001 then
		despairSound:Stop()
		despairSound = nil
	end
end

local function stop_panic_sound(force)
	if not IsValid(panicSound) then return end
	if force then
		panicSound:Stop()
		panicSound = nil
		panicSoundVol = 0
		return
	end
	panicSoundVol = math.max(panicSoundVol - FrameTime() * 0.5, 0)
	panicSound:SetVolume(panicSoundVol)
	if panicSoundVol <= 0.001 then
		panicSound:Stop()
		panicSound = nil
	end
end

hook.Add("Post Post Processing", "hg_despair_effect", function()
	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return end
	if IsValid(ply:GetNWEntity("spect")) then
		despairLerp = 0
		despairTextLerp = 0
		stop_despair_sound(true)
		stop_panic_sound(true)
		return
	end
	if not ply:Alive() then
		despairLerp = 0
		despairTextLerp = 0
		stop_despair_sound(true)
		stop_panic_sound(true)
		return
	end

	local org = get_target_organism()
	local despair = (org and org.despair) and math.Clamp(org.despair, 0, 1) or 0
	if org and org.otrub then
		despair = 0
		despairLerp = 0
		despairTextLerp = 0
		stop_despair_sound(true)
		stop_panic_sound(true)
	end

	despairLerp = LerpFT(0.04, despairLerp, despair)

	if despairLerp > 0.001 then
		render.UpdateScreenEffectTexture()
		heatMat:SetFloat("$c0_x", -CurTime() * 0.18)
		heatMat:SetFloat("$c0_y", 0.012 + despairLerp * 0.05)
		heatMat:SetFloat("$c2_x", (math.sin(CurTime() * 0.75) - 1.5) * (0.25 + despairLerp))
		render.SetMaterial(heatMat)
		render.DrawScreenQuad()

		despairTab["$pp_colour_brightness"] = -0.03 - despairLerp * 0.16
		despairTab["$pp_colour_contrast"] = 1 - despairLerp * 0.15
		despairTab["$pp_colour_colour"] = 1 - despairLerp * 0.85
		DrawColorModify(despairTab)
	end

	-- Panic attack chromatic aberration and vignette
	local panicAttack = (org and org.panicAttack) or false
	if panicAttack then
		render.UpdateScreenEffectTexture()
		chromaticMat:SetFloat("$c0_x", 0.15 + math.sin(CurTime() * 8) * 0.05)
		chromaticMat:SetInt("$c0_y", 1)
		render.SetMaterial(chromaticMat)
		render.DrawScreenQuad()

		render.UpdateScreenEffectTexture()
		vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
		vignetteMat:SetFloat("$c0_z", 2.5)
		vignetteMat:SetFloat("$c1_y", 3.0)
		render.SetMaterial(vignetteMat)
		render.DrawScreenQuad()
	end

	-- Panic attack overrides despair sound
	local panicAttack = (org and org.panicAttack) or false
	if despair > 0 and not panicAttack then
		if not IsValid(despairSound) and not despairSoundLoading then
			despairSoundLoading = true
			sound.PlayFile("sound/desolate.mp3", "noblock noplay", function(channel)
				despairSoundLoading = false
				if not IsValid(channel) then return end
				channel:SetVolume(0)
				channel:Play()
				channel:EnableLooping(true)
				despairSound = channel
			end)
		end

		local targetVol = math.Remap(despair, 0.25, 1, 0.15, 1)
		despairSoundVol = math.Approach(despairSoundVol, targetVol, FrameTime() * 0.5)
		if IsValid(despairSound) then
			despairSound:SetVolume(despairSoundVol)
		end
	else
		stop_despair_sound(false)
	end

	-- Panic attack sound
	local panicAttack = (org and org.panicAttack) or false
	if panicAttack then
		if not IsValid(panicSound) and not panicSoundLoading then
			panicSoundLoading = true
			sound.PlayFile("sound/panic.mp3", "noblock noplay", function(channel)
				panicSoundLoading = false
				if not IsValid(channel) then return end
				channel:SetVolume(0)
				channel:Play()
				channel:EnableLooping(true)
				panicSound = channel
			end)
		end

		local targetVol = 1
		panicSoundVol = math.Approach(panicSoundVol, targetVol, FrameTime() * 2)
		if IsValid(panicSound) then
			panicSound:SetVolume(panicSoundVol)
		end
	else
		stop_panic_sound(false)
	end
end)

hook.Add("DrawOverlay", "hg_despair_text", function()
	local org = get_target_organism()
	if org and org.otrub then
		despairTextLerp = 0
		panicThoughtLerp = 0
		return
	end
	local despair = (org and org.despair) and math.Clamp(org.despair, 0, 1) or 0
	local target = math.Clamp((despair - 0.5) / 0.5, 0, 1)
	despairTextLerp = LerpFT(0.03, despairTextLerp, target)

	if despairTextLerp <= 0.001 then return end

	local time = CurTime()
	local sway = 10 + 16 * despairTextLerp
	local x = ScrW() * 0.5 + math.sin(time * 0.7) * sway + math.cos(time * 0.33) * sway * 0.7
	local y = ScrH() * 0.08 + math.sin(time * 0.51) * sway * 0.4
	local alpha = math.floor(255 * despairTextLerp)

	draw.SimpleText("im so fucking scared", despairFont, x + 2, y + 2, Color(0, 0, 0, math.floor(alpha * 0.7)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("im so fucking scared", despairFont, x, y, Color(235, 235, 235, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

local panicThoughtIndex = 0
local panicThoughtNextTime = 0

hook.Add("Think", "hg_panic_thoughts_notify", function()
	local org = get_target_organism()
	if not org then return end
	
	local panicAttack = org.panicAttack or false
	local time = CurTime()

	if panicAttack then
		if time >= panicThoughtNextTime then
			panicThoughtIndex = (panicThoughtIndex % #panicThoughts) + 1
			local thought = panicThoughts[panicThoughtIndex]
			
			if hg and hg.CreateNotification then
				hg.CreateNotification(thought, 2, Color(255, 100, 100), true)
			end
			
			panicThoughtNextTime = time + 2
		end
	else
		panicThoughtIndex = 0
		panicThoughtNextTime = 0
	end
end)

hook.Add("Player_Death", "hg_despair_cleanup", function(ply)
	if not IsValid(lply) then return end
	if ply ~= lply and ply ~= lply:GetNWEntity("spect") then return end
	stop_despair_sound(true)
	stop_panic_sound(true)
end)

hook.Add("Player Spawn", "hg_despair_cleanup", function(ply)
	if not IsValid(lply) then return end
	if ply ~= lply then return end
	stop_despair_sound(true)
	stop_panic_sound(true)
end)
