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
local FACE_TEXT_COLOR = Color(20, 20, 20)
local FACE_TINT_ALPHA = 60
local FACE_BORDER = 2
local FACE_PADDING = 0.1
local FACE_ICON = 0.22
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

local function drawSoftCritVignette(strength)
	local effects = CONFIG.effects
	local scale = vignetteScale()
	local coverage = SHOCK_COVERAGE * strength
	local border = math.Clamp((coverage / SHOCK_BORDER_DIVISOR) ^ SHOCK_BORDER_EXPONENT * SHOCK_BORDER_MAX, 0, SHOCK_BORDER_MAX)

	render.UpdateScreenEffectTexture()
	VIGNETTE_MATERIAL:SetFloat("$c2_x", CurTime() + SHOCK_TIME_OFFSET)
	VIGNETTE_MATERIAL:SetFloat("$c0_z", border * scale)
	VIGNETTE_MATERIAL:SetFloat("$c1_y", coverage * scale)
	render.SetMaterial(VIGNETTE_MATERIAL)
	render.DrawScreenQuad()

	local wave = math.ease.InOutSine(math.abs(math.cos(CurTime() * effects.softCritPulseSpeed)))
	local pulse = strength * (0.78 + wave * 0.2)
	local tint = (strength * TINT_BASE_GAIN + pulse * TINT_PULSE_GAIN) * scale
	local color = effects.softCritColor

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
		softCritTarget = state.crit == CRIT_SOFT and 1 or 0
	end

	bloodLerp = LerpFT(effects.lerp, bloodLerp, bloodTarget)
	softCritLerp = LerpFT(effects.lerp, softCritLerp, softCritTarget)

	if bloodLerp > EFFECT_MIN then
		bloodTab["$pp_colour_colour"] = 1 - bloodLerp
		bloodTab["$pp_colour_brightness"] = -effects.bloodDarken * bloodLerp
		DrawColorModify(bloodTab)
	end

	if softCritLerp > EFFECT_MIN then
		drawSoftCritVignette(softCritLerp * effects.softCritStrength)
	end
end)

local faceStates = {}
for _, entry in ipairs(CONFIG.face.states) do
	faceStates[entry.key] = entry
end

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

	local faceConfig = CONFIG.face
	local health = SimpleHealth.GetHealth(state)
	if state.crit == CRIT_HARD or health <= CONFIG.hardCritHealth then return "hardcrit" end
	if state.crit == CRIT_SOFT or health <= CONFIG.softCritHealth then return "softcrit" end
	if health <= faceConfig.badlyHurtBelow then return "badly_hurt" end
	if health <= faceConfig.hurtBelow then return "hurt" end

	return "healthy"
end

local function createFaceFont()
	surface.CreateFont(FACE_FONT, {
		font = "Roboto",
		size = math.max(math.floor(ScrH() * CONFIG.face.size * 0.4), 12),
		weight = 800,
	})
end

createFaceFont()
hook.Add("OnScreenSizeChanged", "hg/simplehealth/face-font", createFaceFont)

local function drawFallbackFace(entry, x, y, size)
	local padding = math.floor(size * FACE_PADDING)
	local inner = size - padding * 2

	draw.RoundedBox(math.floor(inner * 0.5), x + padding, y + padding, inner, inner, entry.color)
	draw.SimpleText(entry.label, FACE_FONT, x + size * 0.5, y + size * 0.5, FACE_TEXT_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function drawDominantTint(tint, x, y, size)
	local icon = math.floor(size * FACE_ICON)

	surface.SetDrawColor(tint.r, tint.g, tint.b, FACE_TINT_ALPHA)
	surface.DrawRect(x, y, size, size)
	surface.SetDrawColor(tint.r, tint.g, tint.b, 255)
	surface.DrawOutlinedRect(x, y, size, size, FACE_BORDER)
	surface.DrawRect(x + size - icon, y, icon, icon)
end

hook.Add("HUDPaint", "hg/simplehealth/face", function()
	local state = SimpleHealth.GetLocalState()
	if not state or not IsValid(lply) then return end
	if hook.Run("HUDShouldDraw", "HGSimpleHealthFace") == false then return end

	local faceConfig = CONFIG.face
	local size = math.floor(ScrH() * faceConfig.size)
	local x = math.floor(ScrW() * faceConfig.x)
	local y = math.floor(ScrH() * faceConfig.y)
	local entry = faceStates[getFaceKey(state, lply:Alive())]
	local material = getFaceMaterial(entry.key)

	draw.RoundedBox(4, x, y, size, size, FACE_BOX_COLOR)

	if material then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(material)
		surface.DrawTexturedRect(x, y, size, size)
	else
		drawFallbackFace(entry, x, y, size)
	end

	local dominant = lply:Alive() and SimpleHealth.GetDominantPool(state)
	if dominant then drawDominantTint(faceConfig.tints[dominant], x, y, size) end
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
