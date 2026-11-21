local Clamp = math.Clamp

local angerTunnel = 0

hook.Add("Player_Death", "hg_psyche_sound_stop", function(ply)
	if ply == LocalPlayer() then
		angerTunnel = 0
	end
end)

local ANGER_LOOP_TAIL = 5

local angerSounds = {}

local function stopAngerSound(name)
	local snd = angerSounds[name]
	if not snd then return end
	if IsValid(snd.station) then snd.station:Stop() end
	angerSounds[name] = nil
end

local function updateAngerSound(name, target, dt)
	local snd = angerSounds[name]
	if not snd then
		if target <= 0.01 then return end
		snd = {vol = 0, loading = true}
		angerSounds[name] = snd
		sound.PlayFile("sound/" .. name, "noblock noplay", function(station)
			if angerSounds[name] ~= snd then
				if IsValid(station) then station:Stop() end
				return
			end
			snd.loading = false
			if not IsValid(station) then angerSounds[name] = nil return end
			snd.station = station
			station:SetVolume(snd.vol)
			station:Play()
		end)
		return
	end
	snd.vol = math.Approach(snd.vol, target, dt * 3)
	if target <= 0 and snd.vol <= 0.01 then stopAngerSound(name) return end
	if snd.loading or not IsValid(snd.station) then return end
	local station = snd.station
	station:SetVolume(snd.vol)
	local length = station:GetLength()
	if length > ANGER_LOOP_TAIL and station:GetTime() >= length - ANGER_LOOP_TAIL then
		station:SetTime(0)
	end
	if station:GetState() == GMOD_CHANNEL_STOPPED then
		station:SetTime(0)
		station:Play()
	end
end

hook.Add("Think", "hg_psyche_anger_sound", function()
	local lply = LocalPlayer()
	local org = IsValid(lply) and lply:Alive() and lply.organism
	local anger = org and not (org.otrub or org.incapacitated) and Clamp(org.psycheAnger or 0, 0, 1) or 0
	local angryTarget, furiousTarget = 0, 0
	if anger >= 0.75 then
		angryTarget = Clamp(math.Remap(anger, 0.75, 0.8, 0.5, 0), 0, 0.5)
		furiousTarget = math.Remap(anger, 0.75, 1, 0.5, 1)
	elseif anger > 0.5 then
		angryTarget = Clamp(math.Remap(anger, 0.5, 0.74, 0, 0.5), 0, 0.5)
	end
	local dt = FrameTime()
	updateAngerSound("angry.mp3", angryTarget, dt)
	updateAngerSound("FURIOUS.mp3", furiousTarget, dt)
end)

local angerMat = Material("effects/shaders/zb_grain2")

local psyche_color_tab = {
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
hook.Add("RenderScreenspaceEffects", "hg_psyche_color", function()
	local lply = LocalPlayer()
	if not IsValid(lply) or not lply:Alive() or not lply.organism then return end
	local org = lply.organism
	local anger = Clamp(org.psycheAnger or 0, 0, 1)
	local angerFrac = Clamp((anger - 0.5) / 0.5, 0, 1)

	psyche_color_tab["$pp_colour_addr"] = 0.07 * angerFrac
	if angerFrac > 0 then DrawColorModify(psyche_color_tab) end

	local K = hg.PsycheCombat
	local angerTarget = K and Clamp((anger - K.angerTunnelStart) / (K.angerTunnelFull - K.angerTunnelStart), 0, 1) or 0
	if org.otrub or org.incapacitated then angerTarget = 0 end
	angerTunnel = Lerp(math.min(FrameTime() * 2.5, 1), angerTunnel, angerTarget)
	if angerTunnel < 0.005 then return end

	local pulse = angerTunnel
	render.UpdateScreenEffectTexture()
	render.UpdateFullScreenDepthTexture()
	angerMat:SetFloat("$c0_x", 0)
	angerMat:SetFloat("$c0_y", -1)
	angerMat:SetFloat("$c0_z", 4096)
	angerMat:SetFloat("$c1_x", pulse * 7)
	angerMat:SetFloat("$c1_y", pulse * 0.45)
	angerMat:SetFloat("$c1_z", 0)
	angerMat:SetFloat("$c2_x", pulse * 0.2)
	angerMat:SetFloat("$c2_y", 0)
	angerMat:SetFloat("$c2_z", 0)
	angerMat:SetFloat("$c3_x", 0)
	render.SetMaterial(angerMat)
	render.DrawScreenQuad()
end)
