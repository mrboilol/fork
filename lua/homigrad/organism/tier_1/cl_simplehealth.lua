local SimpleHealth = hg.SimpleHealth
local CONFIG = SimpleHealth.Config
local LerpFT = LerpFT or Lerp

local CRIT_SOFT = SimpleHealth.CRIT_SOFT
local CRIT_HARD = SimpleHealth.CRIT_HARD

local OXY_EFFECT_FULL = 250
local EFFECT_MIN = 0.005
local SHOCK_COVERAGE = 4.2
local SHOCK_BORDER_MAX = 0.86
local SHOCK_BORDER_DIVISOR = 1.8
local SHOCK_BORDER_EXPONENT = 0.78
local SHOCK_TIME_OFFSET = 9750
local TINT_BASE_GAIN = 0.08
local TINT_PULSE_GAIN = 0.24
local TINT_GRAIN_SCALE = 4096
local FACE_BOX_COLOR = Color(15, 15, 15, 200)
local FACE_PADDING = 0.16

local VIGNETTE_MATERIAL = Material("effects/shaders/zb_vignette")
local TINT_MATERIAL = Material("effects/shaders/zb_grain2")

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

function SimpleHealth.GetOxyEffectTarget()
	local state = SimpleHealth.GetLocalState()
	if not state or not IsValid(lply) or not lply:Alive() then return end
	if state.countdownEnd > CurTime() then return OXY_EFFECT_FULL end

	local effects = CONFIG.effects
	local oxy = state.oxy
	if oxy <= effects.oxyStart then return 0 end

	local rising = math.Clamp((oxy - effects.oxyStart) / (effects.oxyStrong - effects.oxyStart), 0, 1)
	local closing = math.Clamp((oxy - effects.oxyStrong) / (CONFIG.oxy.countdownStart - effects.oxyStrong), 0, 1)
	local severity = rising * effects.oxyStrongAmount + closing * (effects.oxyCloseAmount - effects.oxyStrongAmount)

	return severity * OXY_EFFECT_FULL
end

local hg_vignette_scale = GetConVar("hg_vignette_scale")

local function vignetteScale()
	hg_vignette_scale = hg_vignette_scale or GetConVar("hg_vignette_scale")

	return hg_vignette_scale and hg_vignette_scale:GetFloat() or 1
end

local function drawTintedVignette(strength, color, pulseSpeed)
	local scale = vignetteScale()
	local coverage = SHOCK_COVERAGE * strength
	local border = math.Clamp((coverage / SHOCK_BORDER_DIVISOR) ^ SHOCK_BORDER_EXPONENT * SHOCK_BORDER_MAX, 0, SHOCK_BORDER_MAX)

	render.UpdateScreenEffectTexture()
	VIGNETTE_MATERIAL:SetFloat("$c2_x", CurTime() + SHOCK_TIME_OFFSET)
	VIGNETTE_MATERIAL:SetFloat("$c0_z", border * scale)
	VIGNETTE_MATERIAL:SetFloat("$c1_y", coverage * scale)
	render.SetMaterial(VIGNETTE_MATERIAL)
	render.DrawScreenQuad()

	local wave = math.ease.InOutSine(math.abs(math.cos(CurTime() * pulseSpeed)))
	local pulse = strength * (0.78 + wave * 0.2)
	local tint = (strength * TINT_BASE_GAIN + pulse * TINT_PULSE_GAIN) * scale

	render.UpdateScreenEffectTexture()
	TINT_MATERIAL:SetFloat("$c0_x", 0)
	TINT_MATERIAL:SetFloat("$c0_y", -1)
	TINT_MATERIAL:SetFloat("$c0_z", TINT_GRAIN_SCALE)
	TINT_MATERIAL:SetFloat("$c1_x", strength * 3.2 + pulse * 5.8)
	TINT_MATERIAL:SetFloat("$c1_y", (strength * 0.08 + pulse * 0.22) * 1.3)
	TINT_MATERIAL:SetFloat("$c1_z", 0)
	TINT_MATERIAL:SetFloat("$c2_x", tint * color.r / 255)
	TINT_MATERIAL:SetFloat("$c2_y", tint * color.g / 255)
	TINT_MATERIAL:SetFloat("$c2_z", tint * color.b / 255)
	TINT_MATERIAL:SetFloat("$c3_x", 0)
	render.SetMaterial(TINT_MATERIAL)
	render.DrawScreenQuad()
end

local DAMAGE_TINT_KEYS = {"toxin"}
local damageTintLerps = {toxin = 0}
local traumaLerp = 0

local function updateDamageTints(state)
	local effects = CONFIG.effects
	local dominant = state and SimpleHealth.GetDominantPool(state)

	local traumaTarget = 0
	if state then
		local range = math.max(effects.traumaVignetteFull - effects.traumaVignetteStart, 1)
		local trauma = (state.brute or 0) + (state.burn or 0)
		traumaTarget = math.Clamp((trauma - effects.traumaVignetteStart) / range, 0, 1) ^ 1.5 * effects.traumaVignetteStrength
	end

	traumaLerp = LerpFT(effects.lerp, traumaLerp, traumaTarget)
	if traumaLerp > EFFECT_MIN then
		drawTintedVignette(traumaLerp, effects.traumaVignetteColor, effects.traumaVignettePulseSpeed)
	end

	for _, pool in ipairs(DAMAGE_TINT_KEYS) do
		local target = 0
		if pool == dominant then
			local range = math.max(effects.damageTintFull - effects.damageTintMin, 1)
			target = math.Clamp((state[pool] - effects.damageTintMin) / range, 0, 1) * effects.damageTintStrength
		end

		damageTintLerps[pool] = LerpFT(effects.lerp, damageTintLerps[pool], target)
		if damageTintLerps[pool] > EFFECT_MIN then
			drawTintedVignette(damageTintLerps[pool], effects.damageTints[pool], effects.damageTintPulseSpeed)
		end
	end
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

hook.Add("Post Post Pre Post Processing", "hg/simplehealth/screen-effects", function()
	local state = SimpleHealth.GetLocalState()
	if not state and bloodLerp <= EFFECT_MIN and softCritLerp <= EFFECT_MIN and dofLerp <= EFFECT_MIN then return end

	local effects = CONFIG.effects
	local org = state and IsValid(lply) and lply:Alive() and (lply.new_organism or lply.organism)
	local bloodTarget = 0
	local softCritTarget = 0

	if org then
		local blood = tonumber(org.blood) or effects.bloodStart
		bloodTarget = math.Clamp((effects.bloodStart - blood) / (effects.bloodStart - CONFIG.deathBlood), 0, 1)
	end

	if state and IsValid(lply) and lply:Alive() and state.crit == CRIT_SOFT then softCritTarget = 1 end

	bloodLerp = LerpFT(effects.lerp, bloodLerp, bloodTarget)
	softCritLerp = LerpFT(effects.lerp, softCritLerp, softCritTarget)

	if bloodLerp > EFFECT_MIN then
		bloodTab["$pp_colour_colour"] = 1 - bloodLerp
		bloodTab["$pp_colour_brightness"] = -effects.bloodDarken * bloodLerp
		DrawColorModify(bloodTab)
	end

	local dofTarget = org and math.Clamp((effects.bleedDofStart - (tonumber(org.blood) or effects.bleedDofStart)) / (effects.bleedDofStart - CONFIG.deathBlood), 0, 1) or 0
	dofLerp = LerpFT(effects.lerp, dofLerp, dofTarget)
	if dofLerp > EFFECT_MIN then
		DrawBokehDOF(dofLerp * effects.bleedDofIntensity, 1, 0)
	end

	if softCritLerp > EFFECT_MIN then
		drawTintedVignette(softCritLerp * effects.softCritStrength, effects.softCritColor, effects.softCritPulseSpeed)
	end

	updateDamageTints(org and state or nil)
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
	if health < faceConfig.criticalBelow then return "critical" end
	if health < faceConfig.hurtBelow then return "hurt" end

	return "healthy"
end

local function isFacePale()
	local org = IsValid(lply) and (lply.new_organism or lply.organism)
	local blood = org and tonumber(org.blood)

	return blood ~= nil and blood < CONFIG.face.paleBloodBelow
end

SimpleHealth.GetFaceKey = getFaceKey

local function playOuchie(path, pitch, volume)
	sound.PlayFile("sound/" .. path, "noplay noblock", function(station)
		if not IsValid(station) then return end

		station:SetPlaybackRate(pitch or 1)
		station:SetVolume(volume or 1)
		station:Play()
	end)
end

local FACE_RANK = {healthy = 1, hurt = 2, critical = 3, softcrit = 4, hardcrit = 5}

local lastFaceKey
local lastFacePale = false
local lastDamageTotal
local shakeStart = 0

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

	if (worse and key == "critical") or (lastFaceKey and pale and not lastFacePale) then
		playOuchie(faceConfig.blipSound, 1, faceConfig.blipVolume)
	elseif worse then
		playOuchie(faceConfig.statusSound, 1, faceConfig.statusVolume)
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

	local total = state.brute + state.burn + state.toxin + state.oxy
	if lastDamageTotal and total > lastDamageTotal then shakeStart = RealTime() end
	lastDamageTotal = total
end

local function getFaceShake(size)
	local faceConfig = CONFIG.face
	local state = SimpleHealth.GetLocalState()
	local amount = 0

	local age = RealTime() - shakeStart
	if age < faceConfig.shakeTime then
		amount = faceConfig.shakeHit * (1 - age / faceConfig.shakeTime)
	end

	if state and state.crit >= CRIT_SOFT then amount = math.max(amount, faceConfig.shakeCrit) end
	if amount <= 0 then return 0, 0 end

	local now = RealTime()
	amount = amount * size

	return math.sin(now * 95) * amount, math.cos(now * 110) * amount
end

SimpleHealth.OnLocalStateChanged = updateDamageShake

local function nildoy()
	local state = SimpleHealth.GetLocalState()
	if not state or not IsValid(lply) or not lply:Alive() then return end
	if hook.Run("HUDShouldDraw", "HGSimpleHealthFace") == false then return end

	local faceConfig = CONFIG.face
	local size = math.floor(ScrH() * faceConfig.size)
	local x = math.floor(ScrW() * faceConfig.x)
	local y = math.floor(ScrH() * faceConfig.y)
	local shakeX, shakeY = getFaceShake(size)
	x, y = x + math.floor(shakeX), y + math.floor(shakeY)

	surface.SetDrawColor(255, 255, 255, 255)

	local boxMaterial = getFaceMaterial("box")
	if boxMaterial then
		surface.SetMaterial(boxMaterial)
		surface.DrawTexturedRect(x, y, size, size)
	else
		draw.RoundedBox(4, x, y, size, size, FACE_BOX_COLOR)
	end

	local key = getFaceKey(state, true)
	local material = getFaceMaterial(isFacePale() and key .. "_pale" or key)
	if not material then return end

	local padding = math.floor(size * FACE_PADDING)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(material)
	surface.DrawTexturedRect(x + padding, y + padding, size - padding * 2, size - padding * 2)
end

hook.Add("HUDPaint", "hg/simplehealth/face", nildoy)

local deathDelay = {active = false, wasAlive = false, aliveMode = 0}

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

net.Receive("hg_simplehealth_death", function()
	local key = net.ReadString()
	SimpleHealth.Local.deathCause = CONFIG.deathCauses[key] or CONFIG.deathCauses.unknown
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
