local Clamp = math.Clamp

local snd_musicvolume = GetConVar("snd_musicvolume")

local angerTunnel = 0

hook.Add("Player_Death", "hg_psyche_sound_stop", function(ply)
	if ply == LocalPlayer() then
		angerTunnel = 0
	end
end)

local ANGER_ROLE_TRACKS = {
	["Juggernaut"] = "sound/zbattle/ussr2.ogg",
	["Active Shooter"] = "sound/zbattle/ger1.ogg",
}
local ANGER_ROLE_PATHS = {}
for _, path in pairs(ANGER_ROLE_TRACKS) do ANGER_ROLE_PATHS[#ANGER_ROLE_PATHS + 1] = path end

local function angerRoleTrack()
	local role = LocalPlayer().role
	local name = istable(role) and role.name
	return name and ANGER_ROLE_TRACKS[name]
end

local angerSounds = {}

local function stopAngerSound(path)
	local snd = angerSounds[path]
	if not snd then return end
	if IsValid(snd.station) then snd.station:Stop() end
	angerSounds[path] = nil
end

local function updateAngerSound(path, target, dt)
	local snd = angerSounds[path]
	if not snd then
		if target <= 0.01 then return end
		snd = {path = path, vol = 0, loading = true}
		angerSounds[path] = snd
		sound.PlayFile(path, "noblock noplay", function(station)
			if angerSounds[path] ~= snd then
				if IsValid(station) then station:Stop() end
				return
			end
			snd.loading = false
			if not IsValid(station) then angerSounds[path] = nil return end
			snd.station = station
			station:EnableLooping(true)
			station:SetVolume(snd.vol * snd_musicvolume:GetFloat())
			station:Play()
		end)
		return
	end

	snd.vol = math.Approach(snd.vol, target, dt * 3)
	if target <= 0 and snd.vol <= 0.01 then stopAngerSound(path) return end
	if snd.loading or not IsValid(snd.station) then return end
	local station = snd.station
	station:SetVolume(snd.vol * snd_musicvolume:GetFloat())
	if station:GetState() == GMOD_CHANNEL_STOPPED then
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
	local rolePath = angerRoleTrack()
	if rolePath then
		updateAngerSound(rolePath, math.max(angryTarget, furiousTarget), dt)
		angryTarget, furiousTarget = 0, 0
	end
	for _, path in ipairs(ANGER_ROLE_PATHS) do
		if path ~= rolePath then updateAngerSound(path, 0, dt) end
	end
	updateAngerSound("sound/angry.mp3", angryTarget, dt)
	updateAngerSound("sound/FURIOUS.mp3", furiousTarget, dt)
end)

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

	if hg.DrawEdgeVignette then
		hg.DrawEdgeVignette(70, 0, 0, 200 * angerTunnel, 0.12 + 0.28 * angerTunnel)
	end
end)
