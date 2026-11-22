local SimpleHealth = hg.SimpleHealth
local CONFIG = SimpleHealth.Config
local LerpFT = LerpFT or Lerp

local CRIT_SOFT = SimpleHealth.CRIT_SOFT
local CRIT_HARD = SimpleHealth.CRIT_HARD

local OXY_EFFECT_FULL = 250
local EFFECT_MIN = 0.005
local FACE_BOX_COLOR = Color(25, 25, 35, 240)
local FACE_OUTLINE_COLOR = Color(255, 255, 255, 255)
local FACE_PADDING = 0.16


SimpleHealth.Local = SimpleHealth.Local or {mode = 0, crit = 0, brute = 0, burn = 0, toxin = 0, oxy = 0, countdownEnd = 0}

local function resetLocal(state)
	state.crit = 0
	state.countdownEnd = 0
	for _, pool in ipairs(SimpleHealth.POOLS) do
		state[pool] = 0
	end
end

net.Receive("hg_simplehealth", function()
	local state = SimpleHealth.Local
	state.mode = net.ReadUInt(SimpleHealth.NET_MODE_BITS)
	if state.mode == 0 then
		resetLocal(state)

		return
	end

	state.crit = net.ReadUInt(SimpleHealth.NET_CRIT_BITS)
	for _, pool in ipairs(SimpleHealth.POOLS) do
		state[pool] = net.ReadUInt(SimpleHealth.NET_POOL_BITS)
	end

	state.countdownEnd = net.ReadFloat()
	SimpleHealth.OnLocalStateChanged(state)
end)

function SimpleHealth.GetLocalState()
	local state = SimpleHealth.Local
	if state.mode == 0 then return end

	return state
end

function SimpleHealth.GetOxyEffectTarget(o2Target)
	local state = SimpleHealth.GetLocalState()
	if not state or not IsValid(lply) or not lply:Alive() then return o2Target end
	if state.countdownEnd > CurTime() then return OXY_EFFECT_FULL end

	local effects = CONFIG.effects
	local oxy = state.oxy
	local critTarget = SimpleHealth.GetCritDepth(state) ^ effects.critDepthExponent * OXY_EFFECT_FULL
	if oxy <= effects.oxyStart then return math.max(o2Target, critTarget, 0) end

	local rising = math.Clamp((oxy - effects.oxyStart) / (effects.oxyStrong - effects.oxyStart), 0, 1)
	local closing = math.Clamp((oxy - effects.oxyStrong) / (CONFIG.oxy.countdownStart - effects.oxyStrong), 0, 1)
	local severity = rising * effects.oxyStrongAmount + closing * (effects.oxyCloseAmount - effects.oxyStrongAmount)

	return math.max(severity * OXY_EFFECT_FULL, o2Target, critTarget)
end

local hg_vignette_scale = GetConVar("hg_vignette_scale")

local function vignetteScale()
	hg_vignette_scale = hg_vignette_scale or GetConVar("hg_vignette_scale")

	return hg_vignette_scale and hg_vignette_scale:GetFloat() or 1
end

function hg.DrawEdgeVignette(r, g, b, alpha, depth)
	if alpha <= 0 then return end

	local w, h = ScrW(), ScrH()
	local size = math.max(math.floor(h * depth), 2)
	local steps = 32
	local stripe = math.max(math.ceil(size / steps), 1)
	for i = 0, steps - 1 do
		local fade = 1 - i / steps
		surface.SetDrawColor(r, g, b, math.floor(alpha * fade * fade))
		local offset = i * stripe
		surface.DrawRect(offset, offset, w - offset * 2, stripe)
		surface.DrawRect(offset, h - offset - stripe, w - offset * 2, stripe)
		surface.DrawRect(offset, offset + stripe, stripe, h - offset * 2 - stripe * 2)
		surface.DrawRect(w - offset - stripe, offset + stripe, stripe, h - offset * 2 - stripe * 2)
	end
end

local traumaLerp = 0

local function updateDamageTints(state)
	local effects = CONFIG.effects
	local traumaTarget = 0
	if state then
		local range = math.max(effects.traumaVignetteFull - effects.traumaVignetteStart, 1)
		local trauma = (state.brute or 0) + (state.burn or 0)
		traumaTarget = math.Clamp((trauma - effects.traumaVignetteStart) / range, 0, 1) ^ effects.traumaVignetteExponent * effects.traumaVignetteStrength
	end

	traumaLerp = LerpFT(effects.lerp, traumaLerp, traumaTarget)
end

local bloodTab = {
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

local bloodLerp = 0
local softCritLerp = 0
local dofLerp = 0
local critLerp = 0

hook.Add("Post Post Pre Post Processing", "hg/simplehealth/screen-effects", function()
	local state = SimpleHealth.GetLocalState()
	if not state and bloodLerp <= EFFECT_MIN and softCritLerp <= EFFECT_MIN and traumaLerp <= EFFECT_MIN and dofLerp <= EFFECT_MIN and critLerp <= EFFECT_MIN then return end

	local effects = CONFIG.effects
	local org = state and IsValid(lply) and lply:Alive() and (lply.new_organism or lply.organism)
	local bloodTarget = 0
	local softCritTarget = 0
	local critTarget = 0

	if org then
		local blood = tonumber(org.blood) or effects.bloodStart
		bloodTarget = math.Clamp((effects.bloodStart - blood) / (effects.bloodStart - CONFIG.deathBlood), 0, 1)
		critTarget = SimpleHealth.GetCritDepth(state) ^ effects.critDepthExponent
		softCritTarget = state.crit >= CRIT_SOFT and Lerp(critTarget, 1, effects.critStrengthMax) or critTarget
	end

	bloodLerp = LerpFT(effects.lerp, bloodLerp, bloodTarget)
	softCritLerp = LerpFT(effects.lerp, softCritLerp, softCritTarget)
	critLerp = LerpFT(effects.lerp, critLerp, critTarget)

	local colorSeverity = math.max(bloodLerp, critLerp * effects.critDesaturate)
	if colorSeverity > EFFECT_MIN then
		bloodTab["$pp_colour_colour"] = 1 - colorSeverity
		bloodTab["$pp_colour_brightness"] = -effects.bloodDarken * bloodLerp - effects.critDarken * critLerp
		DrawColorModify(bloodTab)
	end

	local dofTarget = org and math.Clamp((effects.bleedDofStart - (tonumber(org.blood) or effects.bleedDofStart)) / (effects.bleedDofStart - CONFIG.deathBlood), 0, 1) or 0
	dofLerp = LerpFT(effects.lerp, dofLerp, dofTarget)
	local dofAmount = math.max(dofLerp * effects.bleedDofIntensity, critLerp * effects.critDofIntensity)
	if dofAmount > EFFECT_MIN then
		DrawBokehDOF(dofAmount, 1, 0)
	end

	updateDamageTints(org and state or nil)
end)

local HEALTH_VIGNETTE_COLOR = {170, 0, 0}
local HEALTH_VIGNETTE_ALPHA = 235
local HEALTH_VIGNETTE_DEPTH = 0.3

hook.Add("HUDPaint", "hg/simplehealth/vignette", function()
	if not IsValid(lply) or not lply:Alive() or not SimpleHealth.GetLocalState() then return end

	local effects = CONFIG.effects
	local strength = math.max(traumaLerp, softCritLerp * effects.softCritStrength) * vignetteScale()
	if strength <= EFFECT_MIN then return end

	local amount = math.Clamp(strength, 0, 1)
	hg.DrawEdgeVignette(HEALTH_VIGNETTE_COLOR[1], HEALTH_VIGNETTE_COLOR[2], HEALTH_VIGNETTE_COLOR[3], HEALTH_VIGNETTE_ALPHA * amount, HEALTH_VIGNETTE_DEPTH * (0.4 + 0.6 * amount))
end)

local faceMaterials = {}

local function getFaceMaterial(key)
	local cached = faceMaterials[key]
	if cached ~= nil then return cached or nil end

	local path = string.format(CONFIG.face.materialPath, key)
	local material = file.Exists("materials/" .. path, "GAME") and Material(path, "smooth") or false
	if material and material:IsError() then material = false end
	faceMaterials[key] = material

	return material or nil
end

local function getFaceKey(state, alive)
	if not alive then return end
	if state.crit == CRIT_HARD then return "hardcrit" end
	if state.crit == CRIT_SOFT then return "softcrit" end

	local faceConfig = CONFIG.face
	local health = SimpleHealth.GetHealth(state)
	if health <= (SimpleHealth.GetCritThresholds()) + 5 then return "softcrit" end
	if health < faceConfig.criticalBelow then return "critical" end
	if health < faceConfig.woundedBelow then return "wounded" end
	if health < faceConfig.hurtBelow then return "hurt" end

	return "healthy"
end

local function isFacePale()
	local org = IsValid(lply) and (lply.new_organism or lply.organism)
	local blood = org and tonumber(org.blood)

	return blood ~= nil and blood < CONFIG.face.paleBloodBelow
end

SimpleHealth.GetFaceKey = getFaceKey
SimpleHealth.GetFaceMaterial = getFaceMaterial
SimpleHealth.IsFacePale = isFacePale
SimpleHealth.NilguyMoodle = CreateClientConVar("hg_nilguyisamoodle", "0", true, false, "1 = the face is the first moodle instead of a separate HUD box", 0, 1)

local function playOuchie(path, pitch, volume)
	sound.PlayFile("sound/" .. path, "noplay noblock", function(station)
		if not IsValid(station) then return end

		station:SetPlaybackRate(pitch or 1)
		station:SetVolume(volume or 1)
		station:Play()
	end)
end

local FACE_RANK = {healthy = 1, hurt = 2, wounded = 3, critical = 4, softcrit = 5, hardcrit = 6}

local lastFaceKey
local lastFacePale = false
local lastDamageTotal
local shakeStart = -10
local shakeScale = 1

local function updateFaceSound()
	local state = SimpleHealth.GetLocalState()
	if not state or not IsValid(lply) or not lply:Alive() then
		lastFaceKey = nil
		lastFacePale = false

		return
	end

	local key = getFaceKey(state, true)
	local pale = isFacePale()
	local faceConfig = CONFIG.face
	local worse = lastFaceKey and FACE_RANK[key] > FACE_RANK[lastFaceKey]
	if lastFaceKey and key ~= lastFaceKey then
		shakeStart = RealTime()
		shakeScale = 1
	end

	local blip = (worse and key == "critical") or (lastFaceKey and pale and not lastFacePale)
	if worse or blip then
		playOuchie(faceConfig.statusSound, 1, faceConfig.statusVolume)
	end

	if blip then
		playOuchie(faceConfig.blipSound, 1, faceConfig.blipVolume)
	end

	lastFaceKey = key
	lastFacePale = pale
end

hook.Add("Think", "hg/simplehealth/face-sound", updateFaceSound)

local function updateDamageShake(state)
	if not IsValid(lply) or not lply:Alive() then
		lastDamageTotal = nil

		return
	end

	local total = state.brute + state.burn
	local gained = lastDamageTotal and total - lastDamageTotal or 0
	if gained > 0 then
		shakeStart = RealTime()
		shakeScale = math.Clamp(0.6 + gained / 25, 0.6, 1.5)
		if hg.AddDamageFlash then
			hg.AddDamageFlash(math.Clamp(0.3 + gained / 20, 0.3, 1.2), 0.6 + math.Clamp(total / 100, 0, 1) * 0.9)
		end
	end
	lastDamageTotal = total
end

local function getFaceShake(size)
	local faceConfig = CONFIG.face
	local age = RealTime() - shakeStart
	if age >= faceConfig.shakeTime then return 0, 0 end

	local fade = 1 - age / faceConfig.shakeTime

	return math.sin(age * 32) * faceConfig.shakeHit * shakeScale * fade * fade * size, 0
end

SimpleHealth.OnLocalStateChanged = updateDamageShake
SimpleHealth.GetFaceShake = getFaceShake

local bigChat = GetConVar("sv_bigchat")
local CHAT_HAT_HEIGHT = 20
local FACE_CHAT_GAP = 6

local function getFaceAnchor(size)
	local faceConfig = CONFIG.face
	bigChat = bigChat or GetConVar("sv_bigchat")

	if not hg.MoodlesEnabled() then
		local margin = math.floor(ScrH() * faceConfig.y)
		local y = ScrH() - size - margin
		if hg.SubRosaEnabled() then return math.floor((ScrW() - size) * 0.5), y end
		if hg.BigChatEnabled() then return ScrW() - size - margin, y end

		return math.floor((ScrW() - size) * 0.5), y
	end

	if not hg.BigChatEnabled() then
		return math.floor(ScrW() * faceConfig.x), math.floor(ScrH() * faceConfig.y)
	end

	local chatX, chatY, chatW
	local chat = hg.chat
	if IsValid(chat) then
		chatX, chatY = chat:GetPos()
		chatW = chat:GetWide()
	else
		chatW = cookie.GetNumber("zchat_bounds_v2_w", ScrW() / 6)
		chatX = cookie.GetNumber("zchat_bounds_v2_x", ScrW() - chatW - ScrW() * 0.008)
		chatY = cookie.GetNumber("zchat_bounds_v2_y", ScrH() - ScrH() * 0.5 - ScrH() * 0.06)
	end

	local x = math.floor(chatX + chatW - size)
	local y = math.floor(chatY - CHAT_HAT_HEIGHT - FACE_CHAT_GAP - size)

	return math.Clamp(x, 0, ScrW() - size), math.max(y, 0)
end

local deathDelay = {active = false, wasAlive = false, aliveMode = 0}

local function nildoy()
	if not IsValid(lply) then return end
	if SimpleHealth.NilguyMoodle:GetBool() and HGCustomMoodlesActive and hg.MoodlesEnabled() then return end
	if GetConVar("hg_hidenilguy"):GetBool() then return end

	local alive = lply:Alive()
	local state = SimpleHealth.GetLocalState()
	if alive then
		if not state then return end
	elseif deathDelay.aliveMode <= 0 then
		return
	end
	if hook.Run("HUDShouldDraw", "HGSimpleHealthFace") == false then return end

	local faceConfig = CONFIG.face
	local size = math.floor(ScrH() * faceConfig.size)
	local x, y = getFaceAnchor(size)
	if hg.HudEdit then
		local ox, oy = hg.HudEdit.Offset("face")
		x, y = x + ox, y + oy
		hg.HudEdit.Rect("face", x, y, size, size)
	end

	surface.SetDrawColor(FACE_BOX_COLOR)
	surface.DrawRect(x, y, size, size)
	surface.SetDrawColor(FACE_OUTLINE_COLOR)
	hg.DrawOutline(x, y, size, size, 1.5)

	local key = alive and getFaceKey(state, true) or "hardcrit"
	local material = getFaceMaterial(alive and isFacePale() and key .. "_pale" or key)
	if not material then return end

	local shakeX, shakeY = 0, 0
	if alive then shakeX, shakeY = getFaceShake(size) end
	local padding = math.floor(size * FACE_PADDING)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(material)
	surface.DrawTexturedRect(x + padding + math.floor(shakeX), y + padding + math.floor(shakeY), size - padding * 2, size - padding * 2)
end

hook.Add("HUDPaint", "hg/simplehealth/face", nildoy)
hook.Add("HG_DeathOverlayHUD", "hg/simplehealth/face", nildoy)
hook.Add("HG_DeathTransitionHUD", "hg/simplehealth/face", nildoy)

local function finishDeathDelay(playSecond)
	deathDelay.active = false

	if playSecond then
		local deathConfig = CONFIG.death
		playOuchie(deathConfig.sound, deathConfig.secondPitch, deathConfig.volume)
		playOuchie(deathConfig.sound, deathConfig.highPitch, deathConfig.volume)
	end
end

local function startDeathDelay()
	local deathConfig = CONFIG.death
	deathDelay.active = true
	deathDelay.endTime = RealTime() + deathConfig.delay
	deathDelay.nextMute = 0
	lastFaceKey = nil

	RunConsoleCommand("stopsound")
	playOuchie(deathConfig.sound, deathConfig.firstPitch, deathConfig.volume)
end

function SimpleHealth.UpdateDeathDelay()
	if not IsValid(lply) then return false end

	local alive = lply:Alive()
	if alive then
		deathDelay.aliveMode = SimpleHealth.Local.mode
		if not deathDelay.wasAlive then SimpleHealth.Local.deathCause = nil end
		if deathDelay.active then finishDeathDelay(false) end
	elseif deathDelay.wasAlive and deathDelay.aliveMode > 0 then
		startDeathDelay()
	end

	deathDelay.wasAlive = alive
	if deathDelay.active and RealTime() >= deathDelay.endTime then finishDeathDelay(true) end

	return deathDelay.active
end

local DEATH_CAUSE_COLOR = Color(200, 40, 40)

net.Receive("hg_simplehealth_death", function()
	local key = net.ReadString()
	local cause = CONFIG.deathCauses[key] or CONFIG.deathCauses.unknown
	SimpleHealth.Local.deathCause = cause

	if IsValid(hg.chat) and hg.chat.AddLine then
		hg.chat:AddLine({DEATH_CAUSE_COLOR, cause})
	end

	if hg.BigChatHidden and hg.BigChatHidden() and hg.PushChatPopup then
		hg.PushChatPopup({DEATH_CAUSE_COLOR, cause})
	end
end)

function SimpleHealth.GetDeathCauseText()
	return SimpleHealth.Local.deathCause
end

function SimpleHealth.HoldsDeathScreen()
	return SimpleHealth.UpdateDeathDelay()
end

hook.Add("Think", "hg/simplehealth/death-delay", function()
	if not SimpleHealth.UpdateDeathDelay() then return end
	if RealTime() < deathDelay.nextMute then return end

	deathDelay.nextMute = RealTime() + CONFIG.death.muteInterval
	lply:ConCommand("soundfade 100 99999")
end)

hook.Add("EntityEmitSound", "hg/simplehealth/death-silence", function()
	if deathDelay.active then return false end
end)

hook.Add("ModifyTinnitusFactor", "hg/simplehealth/death-silence", function(value)
	if deathDelay.active then return 100 end
end)

local FAINT_COLOR = Color(150, 150, 150)
local FAINT_LINES = {
	[SimpleHealth.FAINT_FOOTSTEPS] = "You hear muffled footsteps nearby.",
	[SimpleHealth.FAINT_GUNFIRE] = "You hear muffled gunfire nearby.",
}

net.Receive("hg_simplehealth_faint", function()
	local kind = net.ReadUInt(SimpleHealth.NET_FAINT_BITS)
	local line = FAINT_LINES[kind]
	if kind == SimpleHealth.FAINT_SPEECH then
		line = "You faintly hear someone say \"" .. net.ReadString() .. "\""
	end

	if not line then return end

	if IsValid(hg.chat) and hg.chat.AddLine then
		hg.chat:AddLine({FAINT_COLOR, line})

		return
	end

	chat.AddText(FAINT_COLOR, line)
end)
