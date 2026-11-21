--for poor people with laptops
hg = hg or {}

local referenceWidth, referenceHeight = 1920, 1080
local minimumScale, maximumScale = 0.65, 1.5
local cachedWidth, cachedHeight, cachedScale = 0, 0, 1
local registeredFonts = {}

local function refreshScale()
	local width, height = ScrW(), ScrH()
	if width == cachedWidth and height == cachedHeight then return false end

	cachedWidth, cachedHeight = width, height
	cachedScale = math.Clamp(math.min(width / referenceWidth, height / referenceHeight), minimumScale, maximumScale)
	return true
end

function hg.UIScale()
	refreshScale()
	return cachedScale
end

function hg.SX(value)
	return value * hg.UIScale()
end

hg.SY = hg.SX

function hg.UIPixel(value)
	return math.max(1, math.floor(hg.SX(value) + 0.5))
end

function hg.DrawOutline(x, y, w, h, thickness)
	local whole = math.floor(thickness)
	local fraction = thickness - whole
	if whole > 0 then surface.DrawOutlinedRect(x, y, w, h, whole) end
	if fraction <= 0.01 then return end

	local color = surface.GetDrawColor()
	surface.SetDrawColor(color.r, color.g, color.b, color.a * fraction)
	surface.DrawOutlinedRect(x + whole, y + whole, w - whole * 2, h - whole * 2, 1)
	surface.SetDrawColor(color.r, color.g, color.b, color.a)
end

local function createRegisteredFont(name, definition)
	local scaled = table.Copy(definition)
	scaled.size = math.max(1, math.floor((definition.referenceSize or definition.size or 16) * hg.UIScale() + 0.5))
	scaled.referenceSize = nil
	surface.CreateFont(name, scaled)
end

function hg.RegisterUIFont(name, definition)
	registeredFonts[name] = table.Copy(definition)
	createRegisteredFont(name, registeredFonts[name])
end

hook.Add("OnScreenSizeChanged", "HG_UIResolutionChanged", function()
	cachedWidth, cachedHeight = 0, 0
	refreshScale()
	for name, definition in pairs(registeredFonts) do
		createRegisteredFont(name, definition)
	end
	hook.Run("HG_UIResolutionChanged", ScrW(), ScrH(), cachedScale)
end)

refreshScale()
