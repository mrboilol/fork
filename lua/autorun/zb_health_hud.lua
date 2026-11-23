--мяу мяу
if SERVER then
	local ICONS = {
		"materials/vgui/hud/bloodmeter.png",
		"materials/vgui/hud/pulsemeter.png",
		"materials/vgui/hud/assimilationmeter.png",
		"materials/vgui/hud/o2meter.png",
		"materials/vgui/hud/o2meter_alt.png",
	}

	for _, path in ipairs(ICONS) do resource.AddFile(path) end

	AddCSLuaFile("autorun/zb_health_hud.lua")

	return
end

local math_min, math_max, math_floor, math_abs = math.min, math.max, math.floor, math.abs
local Color = Color
local draw_SimpleText = draw.SimpleText
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawRect = surface.DrawRect
local surface_DrawOutlinedRect = surface.DrawOutlinedRect
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect
local ScrW, ScrH = ScrW, ScrH
local FrameTime = FrameTime
local Lerp = Lerp
local CurTime = CurTime

local cvar_enabled = CreateClientConVar("mzb_MoodleHud_enabled", "1", true, false)
local cvar_alt_icons = CreateClientConVar("mzb_nopixelicons", "0", true, false)

local USE_ALT_ICONS = cvar_alt_icons:GetBool()

local function getOrgVal(org, key, def)
	local v = org[key]
	return type(v) == "number" and v or (def or 0)
end

local function getO2Value(org)
	if not org.o2 then return 30 end
	if type(org.o2) == "table" then
		return org.o2[1] or 30
	end
	return type(org.o2) == "number" and org.o2 or 30
end

local function getO2Max(org)
	if not org.o2 then return 30 end
	if type(org.o2) == "table" then
		return org.o2.range or 30
	end
	return 30
end

local function lerpCol(ratio, from, to)
	ratio = math_min(math_max(ratio, 0), 1)
	return Color(
		math_floor((from.r or 0) + ((to.r or 0) - (from.r or 0)) * ratio),
		math_floor((from.g or 0) + ((to.g or 0) - (from.g or 0)) * ratio),
		math_floor((from.b or 0) + ((to.b or 0) - (from.b or 0)) * ratio),
		255
	)
end

HUD = {
	enabled = cvar_enabled:GetBool(),
	bar_y = 4440,
	bar_scale = 0,
	use_alt_icons = USE_ALT_ICONS,
	smooth = 0.35,
	blood_hide_threshold = 4500,
	pulse_hide_min = 60,
	pulse_hide_max = 100,
	stable_time = 15,
	oxygen_threshold = 28,
}

local icons = {}

local smooth = {
	blood = 5000,
	conscious = 1.0,
	pain = 0,
	pulse = 70,
	heartbeat = 70,
	bloodPressure = 92,
	systolic = 120,
	diastolic = 80,
	cardiacOutput = 1,
	strokeVolume = 1,
	assimilation = 0,
	o2 = 30,
	bleed = 0,
	internalBleed = 0,
	cardiacTamponade = 0,

	temperature = 36.7,
	pneumothorax = 0,
	analgesia = 0,
	brain = 0,
	brainSwelling = 0,
	wantToVomit = 0,

	adrenaline = 0,
	shock = 0,
	disorientation = 0,
	concussion = 0,
	ischemia = 0,
	hemotransfusionshock = 0,
}

local stability = {
	blood = {last_value = 5000, last_change = 0, hidden = false},
	pulse = {last_value = 70, last_change = 0, hidden = false},
}

local function load_icons()
	if icons.loaded and icons.alt == HUD.use_alt_icons then return end
	icons.loaded = true
	icons.alt = HUD.use_alt_icons

	local fixed_icons = {
		blood = "vgui/hud/bloodmeter.png",
		pulse = "vgui/hud/pulsemeter.png",
		assimilation = "vgui/hud/assimilationmeter.png",
	}

	local suffix = HUD.use_alt_icons and "_alt" or ""
	local dynamic_icons = {
		o2 = "vgui/hud/o2meter" .. suffix .. ".png",
	}

	for name, path in pairs(fixed_icons) do
		local mat = Material(path, "smooth")
		icons[name] = (mat and not mat:IsError()) and mat or false
	end

	for name, path in pairs(dynamic_icons) do
		local mat = Material(path, "smooth")
		icons[name] = (mat and not mat:IsError()) and mat or false
	end
end

local function update_stability(blood_val, pulse_val)
	local now = CurTime()

	if math_abs(blood_val - stability.blood.last_value) > 50 then
		stability.blood.last_value = blood_val
		stability.blood.last_change = now
		stability.blood.hidden = false
	end

	if math_abs(pulse_val - stability.pulse.last_value) > 3 then
		stability.pulse.last_value = pulse_val
		stability.pulse.last_change = now
		stability.pulse.hidden = false
	end

	if blood_val >= HUD.blood_hide_threshold and (now - stability.blood.last_change) >= HUD.stable_time then
		stability.blood.hidden = true
	end

	if pulse_val >= HUD.pulse_hide_min and pulse_val <= HUD.pulse_hide_max and (now - stability.pulse.last_change) >= HUD.stable_time then
		stability.pulse.hidden = true
	end
end

local function draw_bar()
	if not HUD.enabled then return end

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end

	local org = ply.organism
	local scale = math_max(HUD.bar_scale, 0.5)

	local base_bar_h = 34
	local base_bar_w = 440
	local bar_h = math_floor(base_bar_h * scale)
	local bar_w = math_floor(base_bar_w * scale)
	local bar_y = ScrH() + HUD.bar_y

	local max_bar_w = ScrW() * 0.95
	local max_scale = max_bar_w / base_bar_w
	if scale > max_scale then
		scale = max_scale
		bar_w = math_floor(base_bar_w * scale)
		bar_h = math_floor(base_bar_h * scale)
	end

	local bar_x = ScrW() * 0.5 - bar_w * 0.5
	local pad = math_floor(5 * scale)
	local icon_size = math_floor(26 * scale)

	load_icons()

	local dt = math_min(FrameTime() * 60, 1)
	local s = HUD.smooth

	local o2_val = getO2Value(org)
	local o2_max = getO2Max(org)

	smooth.blood = Lerp(s * dt, smooth.blood or 5000, getOrgVal(org, "blood", 5000))
	smooth.conscious = Lerp(s * dt, smooth.conscious or 1.0, getOrgVal(org, "consciousness", 1))
	smooth.pain = Lerp(s * dt, smooth.pain or 0, getOrgVal(org, "pain", 0))
	smooth.pulse = Lerp(s * dt, smooth.pulse or 70, getOrgVal(org, "pulse", 70))
	smooth.heartbeat = Lerp(s * dt, smooth.heartbeat or 70, getOrgVal(org, "heartbeat", 70))
	smooth.bloodPressure = Lerp(s * dt, smooth.bloodPressure or 92, getOrgVal(org, "bloodPressure", 92))
	smooth.systolic = Lerp(s * dt, smooth.systolic or 120, getOrgVal(org, "systolic", 120))
	smooth.diastolic = Lerp(s * dt, smooth.diastolic or 80, getOrgVal(org, "diastolic", 80))
	smooth.cardiacOutput = Lerp(s * dt, smooth.cardiacOutput or 1, getOrgVal(org, "cardiacOutput", 1))
	smooth.strokeVolume = Lerp(s * dt, smooth.strokeVolume or 1, getOrgVal(org, "strokeVolume", 1))
	smooth.assimilation = Lerp(s * dt, smooth.assimilation or 0, getOrgVal(org, "assimilated", 0))
	smooth.o2 = Lerp(s * dt, smooth.o2 or o2_max, o2_val)
	smooth.bleed = Lerp(s * dt, smooth.bleed or 0, getOrgVal(org, "bleed", 0))
	smooth.internalBleed = Lerp(s * dt, smooth.internalBleed or 0, getOrgVal(org, "internalBleed", 0))
	smooth.cardiacTamponade = Lerp(s * dt, smooth.cardiacTamponade or 0, getOrgVal(org, "cardiacTamponade", 0))

	smooth.temperature = Lerp(s * dt, smooth.temperature or 36.7, getOrgVal(org, "temperature", 36.7))
	smooth.pneumothorax = Lerp(s * dt, smooth.pneumothorax or 0, getOrgVal(org, "pneumothorax", 0))
	smooth.hemothorax = Lerp(s * dt, smooth.hemothorax or 0, getOrgVal(org, "hemothorax", 0))
	smooth.analgesia = Lerp(s * dt, smooth.analgesia or 0, getOrgVal(org, "analgesia", 0))
	smooth.brain = Lerp(s * dt, smooth.brain or 0, getOrgVal(org, "brain", 0))
	smooth.brainHemorrhage = Lerp(s * dt, smooth.brainHemorrhage or 0, getOrgVal(org, "brainHemorrhage", 0))
	smooth.brainSwelling = Lerp(s * dt, smooth.brainSwelling or 0, getOrgVal(org, "brainSwelling", 0))
	smooth.wantToVomit = Lerp(s * dt, smooth.wantToVomit or 0, getOrgVal(org, "wantToVomit", 0))

	smooth.adrenaline = Lerp(s * dt, smooth.adrenaline or 0, getOrgVal(org, "adrenaline", 0))
	smooth.shock = Lerp(s * dt, smooth.shock or 0, getOrgVal(org, "shock", 0))
	smooth.disorientation = Lerp(s * dt, smooth.disorientation or 0, getOrgVal(org, "disorientation", 0))
	smooth.concussion = Lerp(s * dt, smooth.concussion or 0, getOrgVal(org, "concussion", 0))
	smooth.ischemia = Lerp(s * dt, smooth.ischemia or 0, getOrgVal(org, "ischemia", 0))
    smooth.hemotransfusionshock = Lerp(s * dt, smooth.hemotransfusionshock or 0, getOrgVal(org, "hemotransfusionshock", 0))

	update_stability(smooth.blood or 5000, smooth.heartbeat or 70)

	local segs = {}

	local blood_val = smooth.blood or 5000
	if not stability.blood.hidden then
		local r_blood = math_min(blood_val / 5000, 1)
		local c_blood = r_blood < 0.5 and lerpCol(r_blood * 2, Color(80, 255, 80), Color(255, 180, 50)) or lerpCol((r_blood - 0.5) * 2, Color(255, 180, 50), Color(255, 50, 50))
		table.insert(segs, {label = "BLOOD", val = math_floor(blood_val), suf = "ml", ratio = r_blood, col = c_blood, w = math_floor(95 * scale), icon = "blood", prio = 1})
	end

	local o2_val = smooth.o2 or o2_max
	local r_o2 = math_min(o2_val / o2_max, 1)
	local c_o2 = lerpCol(r_o2, Color(255, 50, 50), Color(80, 200, 255))
	if o2_val < HUD.oxygen_threshold or (#segs == 0 and not stability.pulse.hidden) then
		table.insert(segs, {label = "O2", val = math_floor(o2_val), suf = "%", ratio = r_o2, col = c_o2, w = math_floor(75 * scale), icon = "o2", prio = 2})
	end

	local assim_val = smooth.assimilation or 0
	if assim_val > 0.005 then
		local r_assim = assim_val
		table.insert(segs, {label = "ASSIMILATION", val = math_floor(assim_val * 100), suf = "%", ratio = r_assim, col = Color(180, 50, 255, 255), w = math_floor(105 * scale), icon = "assimilation", prio = 3})
	end

	-- heartbeat is the electrical rate in BPM; pulse is the legacy palpable
	-- circulation-strength value and must not be presented as a rate.
	local pulse_val = smooth.heartbeat or 70
	if not stability.pulse.hidden then
		local r_pulse = math_min(pulse_val / 180, 1)
		local c_pulse = (pulse_val < 50 or pulse_val > 130) and Color(255, 80, 80) or Color(180, 220, 255)
		table.insert(segs, {label = "HR", val = math_floor(pulse_val), suf = "bpm", ratio = r_pulse, col = c_pulse, w = math_floor(80 * scale), icon = "pulse", prio = 4})
	end

	local hasPressure = tonumber(org.systolic) ~= nil and tonumber(org.diastolic) ~= nil
	if hasPressure then
		local systolic = math_floor((smooth.systolic or 0) + 0.5)
		local diastolic = math_floor((smooth.diastolic or 0) + 0.5)
		local pressureAbnormal = systolic < 100 or systolic > 140 or diastolic < 60 or diastolic > 90
		if pressureAbnormal then
			local map = smooth.bloodPressure or (diastolic + (systolic - diastolic) / 3)
			local pressureColor = map < 60 and Color(255, 70, 70) or (map > 110 and Color(255, 165, 65) or Color(180, 220, 255))
			table.insert(segs, {label = "BP", val = systolic .. "/" .. diastolic, suf = "", ratio = math.Clamp(map / 110, 0, 1), col = pressureColor, w = math_floor(92 * scale), icon = "pulse", prio = 5})
		end
	end

	local etco2 = tonumber(org.etco2)
	if etco2 then
		smooth.etco2 = Lerp(s * dt, smooth.etco2 or etco2, etco2)
		local etco2Val = math_floor(smooth.etco2 + 0.5)
		if etco2Val < 35 or etco2Val > 45 then
			local etco2Color = (etco2Val < 20 or etco2Val > 55) and Color(255, 70, 70) or Color(255, 165, 65)
			table.insert(segs, {label = "ETCO2", val = "ETCO2 " .. etco2Val, suf = "", ratio = math.Clamp(etco2Val / 60, 0, 1), col = etco2Color, w = math_floor(92 * scale), icon = "o2", prio = 6})
		end
	else
		smooth.etco2 = nil
	end

	local wbc = tonumber(org.wbc)
	if wbc and (wbc < 4.5 or wbc > 11) then
		local wbcVal = math.Round(wbc, 1)
		local wbcColor = wbc < 1.5 and Color(255, 70, 70) or Color(255, 165, 65)
		table.insert(segs, {label = "WBC", val = "WBC " .. wbcVal, suf = "", ratio = math.Clamp(wbc / 15, 0, 1), col = wbcColor, w = math_floor(92 * scale), icon = "pulse", prio = 7})
	end

	if #segs == 0 then return end

	table.sort(segs, function(a, b) return a.prio < b.prio end)

	local total_width = pad
	for _, seg in ipairs(segs) do total_width = total_width + seg.w + pad end

	if total_width > bar_w then
		local new_scale = (bar_w - pad) / (total_width - pad)
		scale = scale * new_scale * 0.98
		bar_w = math_floor(base_bar_w * scale)
		bar_h = math_floor(base_bar_h * scale)
		bar_x = ScrW() * 0.5 - bar_w * 0.5
		pad = math_floor(5 * scale)
		icon_size = math_floor(26 * scale)

		for i, seg in ipairs(segs) do
			segs[i].w = math_floor(segs[i].w * new_scale * 0.98)
		end
	end

	local x = bar_x + pad

	for _, seg in ipairs(segs) do
		local icon = icons[seg.icon]
		if icon and not icon:IsError() then
			surface_SetDrawColor(255, 255, 255, 255)
			surface_SetMaterial(icon)
			surface_DrawTexturedRect(x, bar_y + (bar_h - icon_size) * 0.5, icon_size, icon_size)
		else
			local letters = {blood = "B", o2 = "O", assimilation = "A", pulse = "♥"}
			surface_SetDrawColor(40, 40, 50, 200)
			surface_DrawRect(x + 1, bar_y + (bar_h - icon_size) * 0.5 + 1, icon_size - 2, icon_size - 2)
			surface_SetDrawColor(seg.col.r, seg.col.g, seg.col.b, 255)
			surface_DrawRect(x + 2, bar_y + (bar_h - icon_size) * 0.5 + 2, icon_size - 4, icon_size - 4)
			draw_SimpleText(letters[seg.icon] or "?", "TargetID", x + icon_size * 0.5, bar_y + bar_h * 0.5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local meter_x = x + icon_size + math_floor(3 * scale)
		local meter_w = seg.w - icon_size - math_floor(10 * scale)
		local meter_y = bar_y + pad + math_floor(2 * scale)
		local meter_h = bar_h - pad * 2 - math_floor(4 * scale)

		surface_SetDrawColor(30, 30, 40, 180)
		surface_DrawRect(meter_x, meter_y, meter_w, meter_h)

		surface_SetDrawColor(seg.col.r, seg.col.g, seg.col.b, 200)
		surface_DrawRect(meter_x, meter_y, meter_w * seg.ratio, meter_h)

		surface_SetDrawColor(80, 80, 90, 230)
		surface_DrawOutlinedRect(meter_x, meter_y, meter_w, meter_h)

		local value_text = seg.val .. (seg.suf or "")
		local text_x = meter_x + math_floor(4 * scale)
		local text_y = bar_y + bar_h * 0.5
		draw_SimpleText(value_text, "DermaDefault", text_x, text_y, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		x = x + seg.w + pad
	end
end

cvars.AddChangeCallback("mzb_MoodleHud_enabled", function(name, old, new)
	HUD.enabled = tonumber(new) ~= 0
end)

cvars.AddChangeCallback("mzb_nopixelicons", function(name, old, new)
	USE_ALT_ICONS = tonumber(new) ~= 0
	HUD.use_alt_icons = USE_ALT_ICONS
end)

concommand.Add("mzb_nopixelicons", function(ply, cmd, args)
	local newValue
	if args[1] then
		local val = tonumber(args[1])
		if val ~= nil then
			newValue = val ~= 0
		end
	end

	if newValue == nil then
		newValue = not USE_ALT_ICONS
	end

	USE_ALT_ICONS = newValue
	HUD.use_alt_icons = USE_ALT_ICONS
	RunConsoleCommand("mzb_nopixelicons", tostring(USE_ALT_ICONS and 1 or 0))

	local status = USE_ALT_ICONS and "ON" or "OFF"
	chat.AddText(Color(0, 200, 255), "Alternative icons: ", USE_ALT_ICONS and Color(100, 255, 100, 255) or Color(255, 100, 100, 255), status)
end)

hook.Add("PopulateToolMenu", "ZMoodle_PopulateMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "Zcity", "ZMoodle_Settings", "Zcity Moodle", "", "", function(panel)
		panel:ClearControls()

		panel:CheckBox("Enable HUD", "mzb_MoodleHud_enabled")
		panel:CheckBox("Show moodles", "hg_hud_moodles")
	end)
end)

hook.Add("HUDPaint", "ZB_Health_Bar", draw_bar)
