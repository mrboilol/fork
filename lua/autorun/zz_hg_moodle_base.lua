if SERVER then
	AddCSLuaFile()
	return
end

hg = hg or {}
hg.MoodleBase = hg.MoodleBase or {}

local MB = hg.MoodleBase

MB.Variants = {"chipped", "unchipped", "simplehealth"}
MB.ShowValue = {chipped = true}

local enabledConVar = CreateClientConVar("hg_newmoodles", "0", true, false, "1 = use the new moodle base and disable the normal moodle renderer", 0, 1)

local definitions = {}
local sorted = {}

local layout = {
	x = 20,
	y = 0.32,
	gap = 8,
	columnGap = 12,
	padding = 10,
	spacing = 4,
	maxTextWidth = 300,
	bottomMargin = 20,
	accent = 4,
}

local levelColors = {
	bad = {Color(255, 205, 70), Color(255, 140, 40), Color(255, 70, 50), Color(190, 20, 45)},
	good = {Color(120, 220, 120), Color(90, 230, 130), Color(70, 235, 170), Color(70, 215, 255)},
}

local wrapCache = {}

function MB.Enabled()
	return enabledConVar:GetBool()
end

function MB.Define(id, definition)
	definition.id = id
	definition.position = definition.position or 100
	definitions[id] = definition

	sorted = {}
	for _, entry in pairs(definitions) do sorted[#sorted + 1] = entry end
	table.sort(sorted, function(a, b)
		if a.position == b.position then return a.id < b.id end
		return a.position < b.position
	end)
end

function MB.Get(id)
	return definitions[id]
end

function MB.GetVariant(ply, org)
	if org.simpleMode or hg.SimpleHealth and hg.SimpleHealth.ConVar and hg.SimpleHealth.ConVar:GetInt() > 0 then return "simplehealth" end
	if ply:GetNWBool("hg_chipped") then return "chipped" end
	return "unchipped"
end

local function resolve(field, variant, level, value, ply, org)
	if field == nil then return end
	if isstring(field) then return field end
	if isfunction(field) then return field(level, value, ply, org, variant) end

	local entry = field[variant]
	if entry == nil then entry = field.all end
	if entry == nil then entry = field[level] or field[#field] end
	if not entry then return end
	if isfunction(entry) then return entry(level, value, ply, org, variant) end
	if istable(entry) then return entry[level] or entry[#entry] end

	return entry
end

function MB.Evaluate(definition, ply, org, variant)
	local level, value = definition.active(ply, org, variant)
	if not level then return end
	if level == true then level = 1 end
	level = math.Clamp(math.floor(level), 1, 4)

	local name = resolve(definition.name, variant, level, value, ply, org)
	if not name or name == "" then return end

	local mood = definition.mood or "bad"
	if isfunction(mood) then mood = mood(level, value, ply, org) end

	return {
		id = definition.id,
		name = name,
		description = resolve(definition.description, variant, level, value, ply, org) or "",
		level = level,
		mood = mood,
		value = MB.ShowValue[variant] and value ~= nil and tostring(value) or nil,
	}
end

function MB.Collect(ply, org)
	local variant = MB.GetVariant(ply, org)
	local list = {}

	for _, definition in ipairs(sorted) do
		local entry = MB.Evaluate(definition, ply, org, variant)
		if entry then list[#list + 1] = entry end
	end

	return list, variant
end

local function wrap(text, maxWidth)
	local key = maxWidth .. text
	if wrapCache[key] then return wrapCache[key] end

	surface.SetFont("DermaDefault")
	local lines, line = {}, ""
	for word in string.gmatch(text, "%S+") do
		local attempt = line == "" and word or line .. " " .. word
		if line ~= "" and surface.GetTextSize(attempt) > maxWidth then
			lines[#lines + 1] = line
			line = word
		else
			line = attempt
		end
	end
	if line ~= "" then lines[#lines + 1] = line end

	wrapCache[key] = lines
	return lines
end

local function measure(entry)
	surface.SetFont("DermaDefaultBold")
	local titleW, titleH = surface.GetTextSize(entry.name)
	local valueW = 0
	if entry.value then
		surface.SetFont("DermaDefault")
		valueW = surface.GetTextSize(entry.value) + layout.padding
	end

	surface.SetFont("DermaDefault")
	local lines = wrap(entry.description, layout.maxTextWidth)
	local lineH = select(2, surface.GetTextSize("A"))
	local textW = titleW + valueW
	for _, line in ipairs(lines) do textW = math.max(textW, (surface.GetTextSize(line))) end

	local descH = #lines * lineH
	local totalH = titleH + (descH > 0 and descH + layout.spacing or 0) + layout.padding * 2

	return textW + layout.padding * 2 + layout.accent, totalH, titleH, lineH, lines
end

local function drawEntry(x, y, entry)
	local totalW, totalH, titleH, lineH, lines = measure(entry)
	local padding = layout.padding
	local color = levelColors[entry.mood] and levelColors[entry.mood][entry.level] or levelColors.bad[entry.level]

	surface.SetDrawColor(25, 25, 35, 240)
	surface.DrawRect(x, y, totalW, totalH)

	surface.SetDrawColor(color.r, color.g, color.b, 255)
	surface.DrawRect(x, y, layout.accent, totalH)
	surface.DrawOutlinedRect(x, y, totalW, totalH)

	local textX = x + layout.accent + padding
	draw.SimpleText(entry.name, "DermaDefaultBold", textX, y + padding, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	if entry.value then
		draw.SimpleText(entry.value, "DermaDefault", x + totalW - padding, y + padding, Color(color.r, color.g, color.b, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end

	local lineY = y + padding + titleH + layout.spacing
	for _, line in ipairs(lines) do
		draw.SimpleText(line, "DermaDefault", textX, lineY, Color(200, 200, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		lineY = lineY + lineH
	end

	return totalW, totalH
end

hook.Add("HUDPaint", "HG_MoodleBase", function()
	if not MB.Enabled() then return end
	if hg.MoodlesEnabled and not hg.MoodlesEnabled() then return end
	if HUD and HUD.enabled == false then return end

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	local org = ply.new_organism or ply.organism
	if not istable(org) or org.alive == false then return end

	local list = MB.Collect(ply, org)
	if #list == 0 then return end

	local offsetX, offsetY = 0, 0
	if hg.HudEdit and hg.HudEdit.Offset then offsetX, offsetY = hg.HudEdit.Offset("moodles") end

	local startY = ScrH() * layout.y + offsetY
	local limitY = ScrH() - layout.bottomMargin
	local x, y, columnW = layout.x + offsetX, startY, 0

	for _, entry in ipairs(list) do
		local _, entryH = measure(entry)
		if y > startY and y + entryH > limitY then
			x = x + columnW + layout.columnGap
			y, columnW = startY, 0
		end

		local w, h = drawEntry(x, y, entry)
		columnW = math.max(columnW, w)
		y = y + h + layout.gap
	end
end)
