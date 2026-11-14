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
local FACE_PADDING = 0.1
local FACE_CURVE_STEPS = 8
local FACE_FONT = "HGSimpleHealthFace"

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

local DAMAGE_TINT_KEYS = {"brute", "burn", "toxin", "oxy"}
local damageTintLerps = {brute = 0, burn = 0, toxin = 0, oxy = 0}

local function updateDamageTints(state)
	local effects = CONFIG.effects
	local dominant = state and SimpleHealth.GetDominantPool(state)

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

hook.Add("Post Post Pre Post Processing", "hg/simplehealth/screen-effects", function()
	local state = SimpleHealth.GetLocalState()
	if not state and bloodLerp <= EFFECT_MIN and softCritLerp <= EFFECT_MIN then return end

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
	if not alive then return "dead" end
	if state.crit == CRIT_HARD then return "asleep" end
	if state.crit == CRIT_SOFT then return "mortified" end

	local faceConfig = CONFIG.face
	local health = SimpleHealth.GetHealth(state)
	if health <= faceConfig.panickingBelow then return "panicking" end
	if health <= faceConfig.sadBelow then return "sad" end
	if health <= faceConfig.okBelow then return "ok" end

	return "happy"
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

local lastFaceKey

local function updateStatusSound(state)
	if not IsValid(lply) or not lply:Alive() then
		lastFaceKey = nil

		return
	end

	local key = getFaceKey(state, true)
	if lastFaceKey and key ~= lastFaceKey then
		local faceConfig = CONFIG.face
		playOuchie(faceConfig.statusSound, 1, faceConfig.statusVolume)
	end

	lastFaceKey = key
end

SimpleHealth.OnLocalStateChanged = updateStatusSound

local function drawCurve(cx, cy, width, bend, thickness, color)
	local half = width * 0.5
	local lastX, lastY

	surface.SetDrawColor(color)
	for step = 0, FACE_CURVE_STEPS do
		local t = step / FACE_CURVE_STEPS * 2 - 1
		local px = cx + t * half
		local py = cy + (1 - t * t) * bend
		if lastX then
			for offset = 0, thickness - 1 do
				surface.DrawLine(lastX, lastY + offset, px, py + offset)
			end
		end

		lastX, lastY = px, py
	end
end

local function drawEyes(spec, cx, cy, radius, color)
	local spread = radius * 0.38
	local eyeY = cy - radius * 0.18
	local thickness = math.max(math.floor(radius * 0.08), 1)

	for side = -1, 1, 2 do
		local ex = cx + spread * side
		if spec.eyes == "closed" then
			drawCurve(ex, eyeY, radius * 0.3, radius * 0.08, thickness, color)
		else
			local eyeRadius = math.floor(radius * (spec.eyes == "wide" and 0.15 or 0.08))
			draw.RoundedBox(eyeRadius, ex - eyeRadius, eyeY - eyeRadius, eyeRadius * 2, eyeRadius * 2, color)
		end

		if spec.brows then
			local tilt = (spec.brows == "sad" and -1 or 1) * side * radius * 0.07
			local browY = eyeY - radius * 0.28
			for offset = 0, thickness - 1 do
				surface.DrawLine(ex - radius * 0.14, browY + tilt + offset, ex + radius * 0.14, browY - tilt + offset)
			end
		end
	end
end

local function drawMouth(spec, cx, cy, radius, color)
	local mouthY = cy + radius * 0.38
	local thickness = math.max(math.floor(radius * 0.08), 1)
	local width = radius * 0.7

	if spec.mouth == "smile" then
		drawCurve(cx, mouthY - radius * 0.08, width, radius * 0.18, thickness, color)
	elseif spec.mouth == "frown" then
		drawCurve(cx, mouthY + radius * 0.08, width, -radius * 0.18, thickness, color)
	elseif spec.mouth == "flat" then
		drawCurve(cx, mouthY, width * 0.7, 0, thickness, color)
	else
		local mouthW = math.floor(radius * (spec.mouth == "scream" and 0.45 or 0.26))
		local mouthH = math.floor(radius * (spec.mouth == "scream" and 0.4 or 0.2))
		draw.RoundedBox(math.floor(math.min(mouthW, mouthH) * 0.5), cx - mouthW * 0.5, mouthY - mouthH * 0.5, mouthW, mouthH, color)
	end
end

local function drawFallbackFace(key, x, y, size)
	local faceConfig = CONFIG.face
	local spec = faceConfig.states[key]
	local padding = math.floor(size * FACE_PADDING)
	local diameter = size - padding * 2
	local radius = diameter * 0.5
	local cx, cy = x + size * 0.5, y + size * 0.5
	local color = faceConfig.featureColor

	draw.RoundedBox(math.floor(radius), x + padding, y + padding, diameter, diameter, spec.skin)
	drawEyes(spec, cx, cy, radius, color)
	drawMouth(spec, cx, cy, radius, color)

	if spec.sweat then
		local drop = math.floor(radius * 0.14)
		draw.RoundedBox(drop, cx + radius * 0.62, cy - radius * 0.55, drop * 2, drop * 3, faceConfig.sweatColor)
	end

	if spec.sleep then
		draw.SimpleText("z", FACE_FONT, x + size - padding, y + padding, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
end

local function createFaceFont()
	surface.CreateFont(FACE_FONT, {
		font = "Roboto",
		size = math.max(math.floor(ScrH() * CONFIG.face.size * 0.3), 10),
		weight = 800,
	})
end

createFaceFont()
hook.Add("OnScreenSizeChanged", "hg/simplehealth/face-font", createFaceFont)

hook.Add("HUDPaint", "hg/simplehealth/face", function()
	local state = SimpleHealth.GetLocalState()
	if not state or not IsValid(lply) then return end
	if hook.Run("HUDShouldDraw", "HGSimpleHealthFace") == false then return end

	local faceConfig = CONFIG.face
	local size = math.floor(ScrH() * faceConfig.size)
	local x = math.floor(ScrW() * faceConfig.x)
	local y = math.floor(ScrH() * faceConfig.y)
	local key = getFaceKey(state, lply:Alive())
	local material = getFaceMaterial(key)

	draw.RoundedBox(4, x, y, size, size, FACE_BOX_COLOR)

	if not material then
		drawFallbackFace(key, x, y, size)

		return
	end

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(material)
	surface.DrawTexturedRect(x, y, size, size)
end)

local deathDelay = {active = false, wasAlive = false, aliveMode = 0}

local function finishDeathDelay(playSecond)
	deathDelay.active = false

	if playSecond then
		local deathConfig = CONFIG.death
		playOuchie(deathConfig.sound, deathConfig.secondPitch, deathConfig.volume)
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
