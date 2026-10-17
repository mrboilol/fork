--[[
	The pieces the settings menu is drawn out of.

	Derma's own controls are here to be laid out in a form, which is what the Q menu
	panel was and why it read as a wall: forty checkboxes with their explanations in
	tooltips nobody hovers over. So the row is the unit instead - a name, what it
	does in a sentence under it, and the control on the right - and everything below
	is the handful of parts a row is made of.

	Three things run through all of them. Nothing changes state instantly: hovers,
	switches and the marker down the side of the page are all a number walked
	towards where it should be, so the window answers a mouse rather than snapping
	at it. Nothing is one flat colour: every surface is a shade with a little light
	dragged across it. And everything that can be clicked makes a noise, because a
	setting that lives on a server two hundred milliseconds away needs to say it
	heard you before the answer gets back.

	Nothing here talks to the server or knows what a setting is. The menu does that
	(cl_f6menu.lua); this is paint, motion and sound.
]]

ZCNPC = ZCNPC or {}
ZCNPC.UI = ZCNPC.UI or {}

local UI = ZCNPC.UI

--\\ The palette
-- Dark, one accent, and the accent is Z-City's own blood red rather than a colour
-- picked out of the air. Four shades of near-black rather than one: what a panel
-- is sitting on is most of how a window reads as having depth, and none of them
-- are grey - there is a little blue in the dark ones and a little red in the light
-- ones, which is the difference between a dark theme and a black rectangle.
UI.Colors = {
	bg = Color(14, 15, 18),
	panel = Color(20, 22, 26),
	side = Color(17, 18, 22),
	row = Color(28, 30, 35),
	rowHover = Color(38, 41, 48),
	line = Color(44, 47, 54),
	text = Color(236, 238, 243),
	dim = Color(152, 158, 168),
	faint = Color(102, 107, 118),
	accent = Color(198, 58, 58),
	accentLit = Color(232, 92, 84),
	accentDim = Color(88, 28, 30),
	good = Color(96, 184, 120),
	off = Color(52, 55, 63),
	white = Color(255, 255, 255),
	black = Color(0, 0, 0),
}

local C = UI.Colors

-- Two colours and how far between them. Everything that lights up under a cursor
-- is one of these with the hover fraction handed to it.
function UI.Mix(from, to, fraction)
	fraction = math.Clamp(fraction or 0, 0, 1)

	return Color(
		from.r + (to.r - from.r) * fraction,
		from.g + (to.g - from.g) * fraction,
		from.b + (to.b - from.b) * fraction,
		from.a + (to.a - from.a) * fraction
	)
end
--//

--\\ Motion
-- A number kept on the panel and walked towards where it should be. Framerate
-- independent, so the same hover takes the same length of time on thirty frames
-- and on three hundred, and it stops dead once it is close enough to stop paying
-- for a lerp on every panel on the screen for the rest of the map.
function UI.Ease(panel, key, target, speed)
	local now = panel[key]

	if now == nil then
		panel[key] = target

		return target
	end

	if math.abs(target - now) < 0.002 then
		panel[key] = target

		return target
	end

	panel[key] = Lerp(math.min(FrameTime() * (speed or 12), 1), now, target)

	return panel[key]
end

-- The one every hover uses: 0 when the cursor is elsewhere, 1 when it is here.
function UI.Hover(panel, speed)
	return UI.Ease(panel, "zcnpc_hover", panel:IsHovered() and 1 or 0, speed or 14)
end
--//

--\\ Sound
-- The window is a client of a server it cannot set anything on directly - every
-- switch in it is a request that takes a round trip - so the click is the only
-- thing that answers immediately, and a menu that answers nothing until the
-- convar lands feels broken rather than slow.
--
-- These used to be Half-Life 2's own, picked because they are already on every
-- disk. They are also the wrong noises: button14 is a bulkhead switch and
-- save_load1 is a hard drive, and a settings window made of them sounds like the
-- inside of a Combine airlock. The menu carries its own instead - Kenney's
-- interface pack, public domain, twelve short clips under a hundred and fifty
-- kilobytes for the whole set.
--
-- Every entry names a stock sound as well, and that one is used if the pack did
-- not arrive: a client mid-download, or somebody running the Lua without the
-- content. Which of the two is in use is worked out once, on the first play,
-- because a file that is still being downloaded when this file is read is on the
-- disk by the time anybody opens the menu.
local soundCvar = CreateClientConVar("zcnpc_menu_sounds", "1", true, false,
	"Play the menu's click and page sounds")

local OURS = "zcnpc/ui/"

-- name, volume, pitch, and the stock sound to fall back on.
UI.Sounds = {
	open = { "open.wav", 0.55, 100, "garrysmod/save_load1.wav" },
	close = { "close.wav", 0.55, 100, "garrysmod/save_load2.wav" },
	page = { "page.wav", 0.45, 100, "garrysmod/ui_click.wav" }, -- changing page in the sidebar
	tab = { "tab.wav", 0.50, 100, "garrysmod/ui_click.wav" }, -- the smaller tabs inside one
	click = { "click.wav", 0.60, 100, "buttons/button14.wav" },
	on = { "toggle_on.wav", 0.55, 100, "buttons/button14.wav" },
	off = { "toggle_off.wav", 0.55, 100, "buttons/button14.wav" },
	slide = { "slide.wav", 0.55, 100, "buttons/blip1.wav" }, -- a slider let go of
	add = { "add.wav", 0.45, 100, "buttons/blip1.wav" },
	drop = { "drop.wav", 0.50, 100, "buttons/blip1.wav" },
	deny = { "deny.wav", 0.50, 100, "buttons/button10.wav" },
}

local resolved = {}

local function Path(entry)
	local found = resolved[entry]

	if found == nil then
		found = file.Exists("sound/" .. OURS .. entry[1], "GAME") and (OURS .. entry[1]) or entry[4]
		resolved[entry] = found
	end

	return found
end

function UI.Sound(name)
	if not soundCvar:GetBool() then return end

	local entry = UI.Sounds[name]
	if not entry then return end

	-- Through the player rather than surface.PlaySound because that one has no
	-- volume: a click is meant to be underneath whatever is being listened to,
	-- not a cabinet door in the middle of it. On a channel of the menu's own, so
	-- that clicking around in here cannot cut off something the player is
	-- carrying, wearing or standing next to.
	local ply = LocalPlayer()
	local path = Path(entry)

	if IsValid(ply) then
		ply:EmitSound(path, 60, entry[3], entry[2], CHAN_USER_BASE + 9)
	else
		surface.PlaySound(path)
	end
end
--//

--\\ Fonts
-- Sized off the screen so the menu is the same size on a laptop and on a 4K
-- monitor, and rebuilt if the resolution changes under it.
local function Scale(size)
	return math.max(1, math.Round(size * math.max(ScrH() / 1080, 0.75)))
end

UI.Scale = Scale

local FONTS = {
	zcnpc_title = { size = 27, weight = 800 },
	zcnpc_sub = { size = 16, weight = 500 },
	zcnpc_tab = { size = 17, weight = 600 },
	zcnpc_label = { size = 18, weight = 600 },
	zcnpc_help = { size = 15, weight = 400 },
	zcnpc_value = { size = 16, weight = 600 },
	zcnpc_chip = { size = 15, weight = 500 },
	zcnpc_micro = { size = 13, weight = 700 },
}

function UI.BuildFonts()
	for name, data in pairs(FONTS) do
		surface.CreateFont(name, {
			font = "Roboto",
			size = Scale(data.size),
			weight = data.weight,
			antialias = true,
			extended = true,
		})
	end
end

UI.BuildFonts()
hook.Add("OnScreenSizeChanged", "zcnpc_ui_fonts", UI.BuildFonts)
--//

--\\ Bits of paint
local GRADIENT_DOWN = Material("gui/gradient_down")
local GRADIENT_UP = Material("gui/gradient_up")
local GRADIENT_RIGHT = Material("gui/gradient")
local BLUR = Material("pp/blurscreen")

-- Rounded corners, drawn rather than handed to draw.RoundedBox, which is wrong
-- for this menu in two ways that both read as "the corners are cut".
--
-- It clamps the corner to half the width and never to half the height, so a
-- three pixel accent strip asked for a nine pixel corner draws its top and its
-- bottom corner tiles through each other and comes out torn. Several things in
-- here are that shape.
--
-- And it picks the corner tile that is only just larger than the corner it was
-- asked for, so a thirteen pixel corner is a sixteen pixel tile drawn at almost
-- one to one - which puts that tile's own stair-stepping, at full size, on every
-- button and every switch in the window. Always taking the largest tile means
-- the curve is only ever being scaled down, and a curve scaled down is a smooth
-- one.
local CORNER = surface.GetTextureID("gui/corner512")

-- Which corners are round: nil is square, the same way Derma's own reads.
function UI.BoxEx(x, y, w, h, colour, radius, tl, tr, bl, br)
	w, h = math.Round(w), math.Round(h)
	if w <= 0 or h <= 0 then return end

	x, y = math.Round(x), math.Round(y)

	surface.SetDrawColor(colour.r, colour.g, colour.b, colour.a or 255)

	local r = math.min(math.Round(radius or Scale(6)), math.floor(w / 2), math.floor(h / 2))

	if r < 1 then
		surface.DrawRect(x, y, w, h)

		return
	end

	-- Everything that is not a corner, in three rectangles: the full height band
	-- between the corner columns, and the two columns between the corner rows.
	surface.DrawRect(x + r, y, w - r * 2, h)
	surface.DrawRect(x, y + r, r, h - r * 2)
	surface.DrawRect(x + w - r, y + r, r, h - r * 2)

	surface.SetTexture(CORNER)

	local right, bottom = x + w - r, y + h - r

	if tl then surface.DrawTexturedRectUV(x, y, r, r, 0, 0, 1, 1)
	else surface.DrawRect(x, y, r, r) end

	if tr then surface.DrawTexturedRectUV(right, y, r, r, 1, 0, 0, 1)
	else surface.DrawRect(right, y, r, r) end

	if bl then surface.DrawTexturedRectUV(x, bottom, r, r, 0, 1, 1, 0)
	else surface.DrawRect(x, bottom, r, r) end

	if br then surface.DrawTexturedRectUV(right, bottom, r, r, 1, 1, 0, 0)
	else surface.DrawRect(right, bottom, r, r) end
end

function UI.Box(x, y, w, h, colour, radius)
	UI.BoxEx(x, y, w, h, colour, radius, true, true, true, true)
end

-- A colour laid over something and faded out across it. What keeps a panel from
-- reading as a flat rectangle, and it is one draw call.
function UI.Fade(x, y, w, h, colour, dir)
	local mat = GRADIENT_DOWN

	if dir == "up" then
		mat = GRADIENT_UP
	elseif dir == "right" then
		mat = GRADIENT_RIGHT
	end

	surface.SetDrawColor(colour)
	surface.SetMaterial(mat)
	surface.DrawTexturedRect(x, y, w, h)
end

-- The same shape again, as solid geometry, for the stencil to be cut out of.
--
-- It cannot be the textured one. A corner tile is an opaque quarter disc on a
-- transparent square, and transparency is a blending instruction: the stencil
-- operation runs before the blend and does not know about it, so every one of those
-- transparent pixels writes into the mask exactly like the opaque ones do. The mask
-- that came out was the whole rectangle, corners and all, which is the plain
-- rectangle the mask was added to stop being.
--
-- Sixteen segments to the quarter, which at the thirteen pixel corner of a switch is
-- a segment every eight tenths of a pixel. The arc has no antialiasing on it, unlike
-- the tile, and does not need any: what is being cut out is a white wash at six to
-- forty alpha, and half a pixel of it either way at the edge of a curve is not
-- something that can be seen.
local ARC = 16

local function ShapePoly(x, y, w, h, r, tl, tr, bl, br)
	-- The flat middle of the shape, in the same three rectangles UI.BoxEx uses, so the
	-- mask and the thing it is masking agree exactly everywhere that is not a curve.
	-- They are also what is left if the arc below is ever thrown away for winding: a
	-- gloss missing from four corners is the old fault, and a gloss missing altogether
	-- would be a new one.
	surface.DrawRect(x + r, y, w - r * 2, h)
	surface.DrawRect(x, y + r, r, h - r * 2)
	surface.DrawRect(x + w - r, y + r, r, h - r * 2)

	local poly = {}

	-- Anticlockwise on paper is clockwise on a screen, because y counts downwards - and
	-- clockwise is the only winding surface.DrawPoly draws.
	local function Corner(cx, cy, from, round)
		if not round then
			poly[#poly + 1] = { x = cx, y = cy }

			return
		end

		for i = 0, ARC do
			local a = math.rad(from - i * (90 / ARC))

			poly[#poly + 1] = { x = cx + math.cos(a) * r, y = cy - math.sin(a) * r }
		end
	end

	Corner(tl and x + r or x, tl and y + r or y, 180, tl)
	Corner(tr and x + w - r or x + w, tr and y + r or y, 90, tr)
	Corner(br and x + w - r or x + w, br and y + h - r or y + h, 0, br)
	Corner(bl and x + r or x, bl and y + h - r or y + h, -90, bl)

	draw.NoTexture()
	surface.DrawPoly(poly)
end

-- The same light, cut to the shape it is lighting.
--
-- Every panel in this menu is a rounded box with a gradient dragged down it, and
-- that gradient was a plain rectangle: over a rounded corner it painted a square
-- highlight exactly where the curve was meant to be, so the corner read as
-- squared off. On a switch, where the corner is half the height of the whole
-- control, it read as the ends being sliced flat. It is the same one draw call
-- with the shape held in the stencil buffer around it.
--
-- x/y/w/h and the corners are the shape; fadeW / fadeH are how far the light
-- reaches into it, which is usually the top half or two thirds.
local function BeginMask(x, y, w, h, radius, tl, tr, bl, br)
	if tl == nil and tr == nil and bl == nil and br == nil then
		tl, tr, bl, br = true, true, true, true
	end

	w, h = math.Round(w), math.Round(h)
	x, y = math.Round(x), math.Round(y)

	local r = math.min(math.Round(radius or Scale(6)), math.floor(w / 2), math.floor(h / 2))

	render.ClearStencil()
	render.SetStencilEnable(true)

	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	-- The shape is drawn with the colour writes off: it is only here to leave its
	-- outline behind, and what is under it is already the right colour.
	render.OverrideColorWriteEnable(true, false)

	surface.SetDrawColor(255, 255, 255, 255)

	if r < 1 then
		surface.DrawRect(x, y, w, h)
	else
		ShapePoly(x, y, w, h, r, tl, tr, bl, br)
	end

	render.OverrideColorWriteEnable(false, false)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)
end

local function EndMask()
	render.SetStencilEnable(false)
	render.ClearStencil()
end

function UI.Gloss(x, y, w, h, colour, radius, fadeW, fadeH, dir, tl, tr, bl, br)
	if (colour.a or 255) <= 0 then return end

	BeginMask(x, y, w, h, radius, tl, tr, bl, br)
	UI.Fade(x, y, fadeW or w, fadeH or h, colour, dir)
	EndMask()
end

-- The same mask around anything else. For the strips of accent that run along
-- the top edge of a card: three pixels tall against a nine pixel corner, so
-- drawn plainly they reach out past the curve at both ends.
function UI.Clip(x, y, w, h, radius, draw, tl, tr, bl, br)
	BeginMask(x, y, w, h, radius, tl, tr, bl, br)
	draw()
	EndMask()
end

-- A hairline. Used everywhere a panel meets another one, because a one pixel
-- lighter line does more for an edge than a heavier colour difference does.
function UI.Line(x, y, w, h, colour)
	surface.SetDrawColor(colour)
	surface.DrawRect(x, y, w, h)
end

-- Rounded boxes stacked outwards, each one fainter and a pixel bigger. Not a real
-- blur, but at eight steps under the corner of a window nobody has ever been able
-- to tell, and it is what makes the window sit above the game instead of on it.
--
-- All of it lands outside the panel drawing it, which is the one place the clip
-- rectangle has to be let go of - and put straight back, because everything after
-- this in the same paint does belong inside the window.
function UI.Shadow(x, y, w, h, radius, depth, alpha)
	depth = depth or Scale(9)
	alpha = alpha or 120

	DisableClipping(true)

	for i = depth, 1, -1 do
		local fade = (1 - i / depth) ^ 2

		draw.RoundedBox(radius + i, x - i, y - i, w + i * 2, h + i * 2,
			Color(0, 0, 0, alpha * fade))
	end

	DisableClipping(false)
end

-- The game behind the window, out of focus. Fades in with the window so opening
-- it is a movement rather than a cut, and dimmed rather than blacked out - what
-- is behind the menu is NPCs falling over, which is the thing being tuned.
function UI.Blur(panel, opened, amount)
	local x, y = panel:LocalToScreen(0, 0)
	local grown = math.Clamp((SysTime() - (opened or 0)) / 0.35, 0, 1)

	DisableClipping(true)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(BLUR)

	for i = 1, 3 do
		BLUR:SetFloat("$blur", grown * (amount or 5) * (i / 3))
		BLUR:Recompute()

		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
	end

	surface.SetDrawColor(0, 0, 0, 150 * grown)
	surface.DrawRect(-x, -y, ScrW(), ScrH())

	DisableClipping(false)
end

-- Left to right, so a row of them reads as one strip of text rather than three
-- labels that happen to be next to each other.
function UI.Text(text, font, x, y, colour, align)
	return draw.SimpleText(text, font, x, y, colour, align or TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

-- The same, letter by letter with air between them. Only for the small upper case
-- headings: spread out like that they read as a label on a section rather than as
-- a very short sentence, which is the one thing surface.CreateFont cannot be
-- asked for. ASCII only, which every heading in this menu is.
function UI.TextSpaced(text, font, x, y, colour, spacing)
	surface.SetFont(font)
	surface.SetTextColor(colour)

	local cursor = x

	for i = 1, #text do
		local char = string.sub(text, i, i)

		surface.SetTextPos(cursor, y)
		surface.DrawText(char)

		cursor = cursor + surface.GetTextSize(char) + spacing
	end

	return cursor - x - spacing
end

-- Word wrap for the sentence under a setting's name. surface.GetTextSize needs the
-- font set, so this is only ever called from a Paint.
function UI.Wrap(text, font, maxWidth)
	surface.SetFont(font)

	local lines, line = {}, ""

	for word in string.gmatch(text or "", "%S+") do
		local try = line == "" and word or (line .. " " .. word)

		if surface.GetTextSize(try) > maxWidth and line ~= "" then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end

	if line ~= "" then lines[#lines + 1] = line end

	return lines
end
--//

--\\ A switch
-- Two states and a knob that slides between them, with the track lighting up
-- underneath it - the colour is what says which state it is in from across the
-- window, and the slide is what says the click landed.
function UI.Toggle(parent)
	local toggle = vgui.Create("DButton", parent)
	toggle:SetText("")
	toggle:SetSize(Scale(50), Scale(26))

	toggle.on = false
	toggle.slide = 0

	function toggle:SetOn(state)
		self.on = state and true or false
	end

	function toggle:GetOn()
		return self.on
	end

	-- Called by Derma before whatever the menu hung on DoClick, which is where the
	-- state is actually flipped - so this is still looking at the old one.
	function toggle:DoClickInternal()
		if not self:IsEnabled() then return end

		UI.Sound(self.on and "off" or "on")
	end

	function toggle:Paint(w, h)
		local slide = UI.Ease(self, "slide", self.on and 1 or 0, 16)
		local enabled = self:IsEnabled()
		local hover = UI.Hover(self)

		local track = UI.Mix(C.off, C.accent, slide)
		if not enabled then track = ColorAlpha(track, 90) end

		UI.Box(0, 0, w, h, track, h / 2)
		UI.Gloss(0, 0, w, h, Color(255, 255, 255, 18 + 22 * hover), h / 2, w, h * 0.6, "down")

		local pad = Scale(3)
		local size = h - pad * 2
		local x = pad + (w - size - pad * 2) * slide

		-- The knob throws a little shadow onto the track, which is the whole
		-- reason it reads as sitting in a groove.
		UI.Box(x, pad + Scale(1), size, size, Color(0, 0, 0, 70), size / 2)
		UI.Box(x, pad, size, size, enabled and C.text or C.dim, size / 2)
	end

	return toggle
end
--//

--\\ A slider
-- Dragged anywhere on the track, and the number is always in view: a setting that
-- reads "knockdown force" means nothing without the number next to it.
function UI.Slider(parent, min, max, decimals)
	local slider = vgui.Create("DPanel", parent)
	slider:SetSize(Scale(220), Scale(28))
	slider:SetPaintBackground(false)

	slider.min = min or 0
	slider.max = max or 1
	slider.decimals = decimals or 2
	slider.value = slider.min
	slider.held = false

	local track = vgui.Create("DPanel", slider)
	track:Dock(FILL)
	track:DockMargin(0, 0, Scale(62), 0)

	local entry = vgui.Create("DTextEntry", slider)
	entry:Dock(RIGHT)
	entry:SetWide(Scale(56))
	entry:SetFont("zcnpc_value")
	entry:SetDrawBackground(false)
	entry:SetTextColor(C.text)
	entry:SetNumeric(true)
	entry:SetUpdateOnType(false)

	entry.Paint = function(self, w, h)
		UI.Box(0, 0, w, h, C.bg, Scale(5))

		-- The box is the number's, and it says so by lighting up while it is
		-- being typed in rather than only when it is hovered.
		local live = UI.Ease(self, "zcnpc_edit", (self:IsEditing() or self:IsHovered()) and 1 or 0, 14)
		if live > 0.01 then
			UI.Box(0, h - Scale(2), w, Scale(2), ColorAlpha(C.accent, 255 * live), Scale(1))
		end

		self:DrawTextEntryText(C.text, C.accent, C.text)
	end

	-- The box is half of the control, so it goes read only with the rest of it -
	-- otherwise somebody who may not change a setting can still type into it and
	-- be told off by the server for every keystroke.
	local setEnabled = slider.SetEnabled

	slider.SetEnabled = function(self, state)
		setEnabled(self, state)
		entry:SetEnabled(state)
	end

	local function Fraction()
		local span = slider.max - slider.min
		if span <= 0 then return 0 end

		return math.Clamp((slider.value - slider.min) / span, 0, 1)
	end

	function slider:SetValue(value, quiet)
		value = math.Clamp(tonumber(value) or self.min, self.min, self.max)

		local step = 10 ^ self.decimals
		value = math.Round(value * step) / step

		local moved = math.abs(value - self.value) > 0.0000001
		self.value = value

		if not entry:IsEditing() then entry:SetValue(tostring(value)) end

		if moved and not quiet and isfunction(self.OnValue) then self:OnValue(value) end
	end

	function slider:GetValue()
		return self.value
	end

	local function Drag(self, x)
		local span = self.max - self.min
		local fraction = math.Clamp(x / math.max(track:GetWide(), 1), 0, 1)

		self:SetValue(self.min + span * fraction)
	end

	track.Paint = function(self, w, h)
		local enabled = slider:IsEnabled()
		local live = UI.Ease(self, "zcnpc_live", (self:IsHovered() or slider.held) and 1 or 0, 14)

		local thick = Scale(6) + Scale(2) * live
		local y = h / 2 - thick / 2
		local fill = math.max(w * Fraction(), thick)

		UI.Box(0, y, w, thick, C.bg, thick / 2)

		local bar = enabled and UI.Mix(C.accent, C.accentLit, live) or C.off
		UI.Box(0, y, fill, thick, bar, thick / 2)

		-- The filled part is the only thing on the row with any light in it, so
		-- it gets a sheen down it rather than being one flat red.
		if enabled then
			UI.Gloss(0, y, fill, thick, Color(255, 255, 255, 40), thick / 2, fill, thick * 0.6, "down")
		end

		local knob = Scale(14) + Scale(4) * live
		local kx = math.Clamp(fill - knob / 2, 0, w - knob)

		UI.Box(kx, h / 2 - knob / 2 + Scale(1), knob, knob, Color(0, 0, 0, 80), knob / 2)
		UI.Box(kx, h / 2 - knob / 2, knob, knob, enabled and C.text or C.dim, knob / 2)
	end

	track.OnMousePressed = function(self, key)
		if key ~= MOUSE_LEFT or not slider:IsEnabled() then return end

		slider.held = true
		self:MouseCapture(true)
		Drag(slider, self:CursorPos())
	end

	track.OnMouseReleased = function(self, key)
		if not slider.held then return end

		slider.held = false
		self:MouseCapture(false)

		UI.Sound("slide")

		if isfunction(slider.OnRelease) then slider:OnRelease(slider.value) end
	end

	track.Think = function(self)
		if not slider.held then return end

		Drag(slider, self:CursorPos())
	end

	entry.OnEnter = function(self)
		slider:SetValue(self:GetValue())
		if isfunction(slider.OnRelease) then slider:OnRelease(slider.value) end
	end

	entry.OnLoseFocus = function(self)
		slider:SetValue(self:GetValue())
		if isfunction(slider.OnRelease) then slider:OnRelease(slider.value) end
	end

	return slider
end

--\\ A weight
-- The small sibling of the slider above, for the loadout pages: a bar of whole
-- numbers with no box of its own, thin enough to sit under the name of the thing it
-- belongs to. Drawn as that many segments out of the scale rather than as a filled
-- fraction, because the number means tickets in a raffle and counting them is the
-- point - "this one has three and that one has one" is the thing to be able to read
-- off it at a glance.
function UI.Weight(parent, min, max)
	local bar = vgui.Create("DPanel", parent)
	bar:SetTall(Scale(10))
	bar:SetPaintBackground(false)

	bar.min = min or 1
	bar.max = max or 10
	bar.value = bar.min
	bar.held = false

	function bar:SetValue(value, quiet)
		value = math.Clamp(math.Round(tonumber(value) or self.min), self.min, self.max)

		local moved = value ~= self.value
		self.value = value

		if moved and not quiet and isfunction(self.OnValue) then self:OnValue(value) end
	end

	function bar:GetValue()
		return self.value
	end

	local function Steps(self)
		return self.max - self.min + 1
	end

	local function Drag(self, x)
		local steps = Steps(self)
		local slot = math.floor(x / math.max(self:GetWide(), 1) * steps)

		self:SetValue(self.min + math.Clamp(slot, 0, steps - 1))
	end

	bar.Paint = function(self, w, h)
		local enabled = self:IsEnabled()
		local live = UI.Ease(self, "zcnpc_live", (self:IsHovered() or self.held) and 1 or 0, 14)
		local steps = Steps(self)
		local gap = Scale(2)
		local seg = (w - gap * (steps - 1)) / steps

		for i = 1, steps do
			local x = (i - 1) * (seg + gap)
			local on = i <= (self.value - self.min + 1)
			local colour = C.bg

			if on then
				colour = enabled and UI.Mix(C.accent, C.accentLit, live) or C.off
			elseif live > 0.01 then
				colour = UI.Mix(C.bg, C.line, live)
			end

			UI.Box(x, 0, seg, h, colour, Scale(2))
		end
	end

	bar.OnMousePressed = function(self, key)
		if key ~= MOUSE_LEFT or not self:IsEnabled() then return end

		self.held = true
		self:MouseCapture(true)
		Drag(self, self:CursorPos())
	end

	bar.OnMouseReleased = function(self, key)
		if not self.held then return end

		self.held = false
		self:MouseCapture(false)

		UI.Sound("slide")

		if isfunction(self.OnRelease) then self:OnRelease(self.value) end
	end

	bar.Think = function(self)
		if not self.held then return end

		Drag(self, self:CursorPos())
	end

	return bar
end
--//

--\\ A row
-- The unit the whole menu is built out of: what it is called, what it does, and
-- the control that changes it. Under the cursor it lifts a shade and grows a mark
-- down its left edge, which is there to answer "which of these am I about to
-- change" on a page of thirty of them.
function UI.Row(parent, label, help)
	local row = vgui.Create("DPanel", parent)
	row:Dock(TOP)
	row:DockMargin(0, 0, 0, Scale(7))
	row:DockPadding(Scale(16), Scale(11), Scale(16), Scale(11))
	row:SetTall(Scale(58))

	row.label = label or ""
	row.help = help or ""
	row.hovered = false

	row.Paint = function(self, w, h)
		-- The control counts as the row: a cursor on the switch at the end of a
		-- line has not left the line.
		local hover = UI.Ease(self, "zcnpc_hover",
			(self:IsHovered() or self:IsChildHovered() or self.hovered) and 1 or 0, 14)

		local radius = Scale(7)

		UI.Box(0, 0, w, h, UI.Mix(C.row, C.rowHover, hover), radius)
		UI.Gloss(0, 0, w, h, Color(255, 255, 255, 6 + 10 * hover), radius, w, h, "down")

		-- Grown out of the middle rather than faded in, so the eye catches it as
		-- movement at the edge of a page it is reading down.
		if hover > 0.01 then
			local mark = h * 0.62 * hover

			UI.Box(0, h / 2 - mark / 2, Scale(3), mark, ColorAlpha(C.accent, 255 * hover), Scale(2))
		end

		local pad = Scale(16) + Scale(3) * hover

		UI.Text(self.label, "zcnpc_label", pad, Scale(10), C.text)

		if self.help == "" then return end

		local width = w - pad - Scale(16) - (self.controlWidth or 0) - Scale(18)
		local lines = UI.Wrap(self.help, "zcnpc_help", width)
		local y = Scale(10) + draw.GetFontHeight("zcnpc_label") + Scale(3)

		for i = 1, math.min(#lines, self.maxLines or 3) do
			UI.Text(lines[i], "zcnpc_help", pad, y, UI.Mix(C.dim, C.text, hover * 0.35))
			y = y + draw.GetFontHeight("zcnpc_help")
		end
	end

	-- The row is as tall as its sentence needs it to be, which is only knowable
	-- once it has a width - so it is measured on the first layout pass.
	row.PerformLayout = function(self, w)
		local control = self.control

		if IsValid(control) then
			self.controlWidth = control:GetWide()
			control:SetPos(w - control:GetWide() - Scale(16), self:GetTall() / 2 - control:GetTall() / 2)
		end

		local text = Scale(10) + draw.GetFontHeight("zcnpc_label") + Scale(3)

		if self.help ~= "" then
			local width = w - Scale(32) - (self.controlWidth or 0) - Scale(18)
			local lines = math.min(#UI.Wrap(self.help, "zcnpc_help", width), self.maxLines or 3)

			text = text + lines * draw.GetFontHeight("zcnpc_help")
		end

		local want = math.max(Scale(54), text + Scale(13))
		if math.abs(self:GetTall() - want) > 1 then self:SetTall(want) end
	end

	function row:SetControl(control)
		self.control = control
		control:SetParent(self)
		self:InvalidateLayout(true)
	end

	return row
end
--//

--\\ A button that looks like it does something
-- Two kinds: the quiet one, which is a row that happens to be clickable, and the
-- accent one for the single thing on a page somebody came to press.
function UI.Button(parent, text, accent)
	local button = vgui.Create("DButton", parent)
	button:SetText("")
	button:SetTall(Scale(38))

	button.label = text or ""
	button.accent = accent and true or false

	function button:DoClickInternal()
		if not self:IsEnabled() then return end

		UI.Sound("click")
	end

	button.Paint = function(self, w, h)
		local enabled = self:IsEnabled()
		local hover = enabled and UI.Hover(self) or 0
		local down = (enabled and self:IsDown()) and Scale(1) or 0

		local base = self.accent and C.accentDim or C.row
		local hot = self.accent and C.accent or C.rowHover
		local colour = UI.Mix(base, hot, hover)

		if not enabled then colour = ColorAlpha(base, 90) end

		local radius = Scale(6)

		UI.Box(0, down, w, h - down, colour, radius)
		UI.Gloss(0, down, w, h - down, Color(255, 255, 255, 10 + 18 * hover), radius,
			w, (h - down) * 0.55, "down")

		-- A line of the accent under the quiet ones as they light up, so they are
		-- still obviously the same family as the loud one.
		if enabled and not self.accent and hover > 0.01 then
			UI.Box(Scale(10), h - Scale(2), (w - Scale(20)) * hover, Scale(2),
				ColorAlpha(C.accent, 255 * hover), Scale(1))
		end

		draw.SimpleText(self.label, "zcnpc_tab", w / 2, h / 2 + down,
			enabled and C.text or C.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function button:SetLabel(value)
		self.label = value or ""
	end

	return button
end

-- The smaller one: a pill in a strip of them, one of which is on. Used for the
-- kinds of NPC on the loadouts page.
function UI.Tab(parent, text, selected)
	local tab = vgui.Create("DButton", parent)
	tab:SetText("")
	tab:SetTall(Scale(32))

	tab.label = text or ""
	tab.IsOn = selected or function() return false end

	function tab:DoClickInternal()
		UI.Sound("tab")
	end

	tab.Paint = function(self, w, h)
		local on = UI.Ease(self, "zcnpc_on", self:IsOn() and 1 or 0, 14)
		local hover = UI.Hover(self)

		local colour = UI.Mix(UI.Mix(C.row, C.rowHover, hover), C.accentDim, on)

		UI.Box(0, 0, w, h, colour, Scale(16))
		UI.Gloss(0, 0, w, h, Color(255, 255, 255, 8 + 14 * hover), Scale(16), w, h * 0.6, "down")

		if on > 0.01 then
			UI.Box(w / 2 - (w * 0.3) * on, h - Scale(3), (w * 0.6) * on, Scale(2),
				ColorAlpha(C.accent, 255 * on), Scale(1))
		end

		draw.SimpleText(self.label, "zcnpc_chip", w / 2, h / 2,
			UI.Mix(C.dim, C.text, math.max(on, hover)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return tab
end

-- And the strip they sit in, which wraps.
--
-- It was five of them docked to the left at a fixed 128 wide, which is fine for
-- five and broken for eight: the Combine line alone is four boxes now
-- (sh_npcweapons.lua), and a docked row does not wrap - the ones that did not fit
-- were simply squeezed off the right hand edge of the window, past the point where
-- there was nothing left to click.
--
-- So each one is as wide as its own name needs, packed left to right, and moved
-- onto another line when the next will not fit. The strip then tells its parent how
-- tall it turned out, which is what keeps the page under it where it should be: one
-- line on a wide window, three at the narrowest the window can be dragged to.
function UI.TabRow(parent)
	local row = vgui.Create("DPanel", parent)
	row:SetPaintBackground(false)
	row:SetTall(Scale(32))

	row.tabs = {}

	function row:Add(text, selected)
		local tab = UI.Tab(self, text, selected)
		self.tabs[#self.tabs + 1] = tab

		return tab
	end

	row.PerformLayout = function(self, w)
		local gap = Scale(6)
		local tall = Scale(32)

		-- Not yet docked to anything. Packing against a width of nothing puts every
		-- tab on a line of its own and then tells the page the strip is that tall,
		-- which is a page that jumps on the frame it opens.
		if w < Scale(64) then return end

		local x, y = 0, 0

		surface.SetFont("zcnpc_chip")

		for _, tab in ipairs(self.tabs) do
			local text = surface.GetTextSize(tab.label or "")
			-- The pill is drawn with a Scale(16) corner at each end, so the padding
			-- is what keeps a short name off the curve rather than a taste in
			-- margins. Never wider than the strip: a name longer than the window
			-- gets a line of its own and is clipped, which is still a button.
			local wide = math.min(math.max(text + Scale(30), Scale(64)), w)

			if x > 0 and x + wide > w then
				x = 0
				y = y + tall + gap
			end

			tab:SetPos(x, y)
			tab:SetSize(wide, tall)

			x = x + wide + gap
		end

		-- Own height last, and only when it has actually changed: SetTall lays the
		-- strip out again, so an unconditional one here is a loop.
		local need = y + tall

		if math.abs(self:GetTall() - need) > 1 then
			self:SetTall(need)

			local up = self:GetParent()
			if not IsValid(up) then return end

			up:InvalidateLayout()

			-- And the panel above that, which on every page here is the scroll
			-- panel that owns the canvas: the canvas is sized to its children from
			-- out there, so a strip that has grown a line is something the
			-- scrollbar has to be told about too.
			local outer = up:GetParent()
			if IsValid(outer) then outer:InvalidateLayout() end
		end
	end

	return row
end
--//

--\\ A box to type in
-- The same three lines in three places, and the underline that grows while it has
-- the keyboard is what tells somebody the window is listening to them rather than
-- to the game behind it.
function UI.TextEntry(parent, placeholder)
	local entry = vgui.Create("DTextEntry", parent)
	entry:SetFont("zcnpc_chip")
	entry:SetTall(Scale(32))
	entry:SetUpdateOnType(false)
	entry:SetPlaceholderText(placeholder or "")

	entry.Paint = function(self, w, h)
		local live = UI.Ease(self, "zcnpc_live", (self:IsEditing() or self:IsHovered()) and 1 or 0, 14)

		UI.Box(0, 0, w, h, UI.Mix(C.bg, C.row, live * 0.5), Scale(6))
		UI.Line(Scale(8), h - Scale(2), w - Scale(16), Scale(1), ColorAlpha(C.line, 255 - 120 * live))

		if live > 0.01 then
			UI.Box(w / 2 - ((w - Scale(16)) / 2) * live, h - Scale(2), (w - Scale(16)) * live, Scale(2),
				ColorAlpha(C.accent, 255 * live), Scale(1))
		end

		self:DrawTextEntryText(C.text, C.accent, C.dim)
	end

	return entry
end
--//

--\\ Scroll bars that match everything else
-- Thin, and out of the way: the bar itself is barely there until the grip is
-- under a cursor.
function UI.Scroll(parent)
	local scroll = vgui.Create("DScrollPanel", parent)
	local bar = scroll:GetVBar()

	bar:SetWide(Scale(6))
	bar:SetHideButtons(true)

	bar.Paint = function(_, w, h)
		UI.Box(0, 0, w, h, ColorAlpha(C.bg, 160), Scale(3))
	end

	bar.btnGrip.Paint = function(self, w, h)
		local hover = UI.Ease(self, "zcnpc_hover", (self:IsHovered() or self.Depressed) and 1 or 0, 14)

		UI.Box(0, 0, w, h, UI.Mix(C.line, C.accent, hover), Scale(3))
	end

	return scroll
end
--//

--\\ A heading inside a page
-- A tick of the accent, the name spread out small and upper case, and a line that
-- fades away to the right rather than running the full width - a hard rule across
-- a page cuts it in two, and these are meant to group rows, not separate them.
function UI.Heading(parent, text)
	local heading = vgui.Create("DPanel", parent)
	heading:Dock(TOP)
	heading:DockMargin(0, Scale(10), 0, Scale(8))
	heading:SetTall(Scale(28))

	heading.Paint = function(_, w, h)
		local y = h / 2 - draw.GetFontHeight("zcnpc_micro") / 2 - Scale(2)

		UI.Box(0, y + Scale(3), Scale(3), draw.GetFontHeight("zcnpc_micro") - Scale(4), C.accent, Scale(2))

		local width = UI.TextSpaced(string.upper(text), "zcnpc_micro", Scale(10), y, C.dim, Scale(1))
		local from = Scale(10) + width + Scale(12)

		UI.Fade(from, h - Scale(9), math.max(w - from, 0), Scale(1), C.line, "right")
	end

	return heading
end

-- A sentence on its own, for the things a row would be the wrong shape for.
function UI.Note(parent, text, colour)
	local note = vgui.Create("DPanel", parent)
	note:Dock(TOP)
	note:DockMargin(0, 0, 0, Scale(10))
	note:SetTall(Scale(24))

	note.Paint = function(self, w, h)
		local pad = Scale(12)
		local lines = UI.Wrap(text, "zcnpc_help", w - pad - Scale(4))
		local height = draw.GetFontHeight("zcnpc_help")

		-- The bar down the side is what makes a paragraph read as an aside rather
		-- than as a row somebody forgot to put a control on.
		UI.Box(0, 0, Scale(2), math.max(#lines * height, height), ColorAlpha(colour or C.line, 150), Scale(1))

		for i, line in ipairs(lines) do
			UI.Text(line, "zcnpc_help", pad, (i - 1) * height, colour or C.dim)
		end

		local want = math.max(height, #lines * height)
		if math.abs(self:GetTall() - want) > 1 then self:SetTall(want) end
	end

	return note
end
--//

--\\ Something to answer
-- Derma_Query and Derma_Message are the last two grey Windows-98 boxes anybody
-- sees while using this menu, and they turn up on top of it - so they are the two
-- worth having our own of. Same paint as everything else, and a question that
-- can be answered with the keyboard, since it is asked over a window that has it.
local function Modal(title, text)
	local panel = vgui.Create("DFrame")
	panel:SetSize(Scale(440), Scale(210))
	panel:Center()
	panel:SetTitle("")
	panel:ShowCloseButton(false)
	panel:SetDraggable(false)
	panel:DockPadding(Scale(22), Scale(20), Scale(22), Scale(18))
	panel:MakePopup()

	panel:SetAlpha(0)
	panel:AlphaTo(255, 0.1, 0)

	local function Strip(w)
		UI.Box(0, 0, w, Scale(3), C.accent, 0)
	end

	panel.Paint = function(self, w, h)
		UI.Shadow(0, 0, w, h, Scale(9))
		UI.Box(0, 0, w, h, C.panel, Scale(9))
		UI.Gloss(0, 0, w, h, Color(255, 255, 255, 8), Scale(9), w, h * 0.5, "down")

		UI.Clip(0, 0, w, h, Scale(9), function() Strip(w) end, true, true, false, false)

		local pad = Scale(22)
		local y = Scale(22)

		UI.Text(title, "zcnpc_label", pad, y, C.text)

		y = y + draw.GetFontHeight("zcnpc_label") + Scale(8)

		for _, line in ipairs(UI.Wrap(text, "zcnpc_help", w - pad * 2)) do
			UI.Text(line, "zcnpc_help", pad, y, C.dim)
			y = y + draw.GetFontHeight("zcnpc_help")
		end
	end

	local row = vgui.Create("DPanel", panel)
	row:Dock(BOTTOM)
	row:SetTall(Scale(38))
	row:SetPaintBackground(false)

	UI.Sound("tab")

	return panel, row
end

local function Dismiss(panel)
	panel:SetMouseInputEnabled(false)
	panel:SetKeyboardInputEnabled(false)
	panel:AlphaTo(0, 0.08, 0, function(_, self)
		if IsValid(self) then self:Remove() end
	end)
end

function UI.Alert(title, text)
	local panel, row = Modal(title, text)

	local ok = UI.Button(row, "All right", true)
	ok:Dock(RIGHT)
	ok:SetWide(Scale(140))
	ok.DoClick = function() Dismiss(panel) end

	panel.OnKeyCodePressed = function(_, key)
		if key == KEY_ENTER or key == KEY_ESCAPE then Dismiss(panel) end
	end

	return panel
end

function UI.Confirm(title, text, label, onYes)
	local panel, row = Modal(title, text)

	local no = UI.Button(row, "Leave it")
	no:Dock(RIGHT)
	no:SetWide(Scale(130))
	no.DoClick = function() Dismiss(panel) end

	local yes = UI.Button(row, label or "Do it", true)
	yes:Dock(RIGHT)
	yes:DockMargin(0, 0, Scale(8), 0)
	yes:SetWide(Scale(150))
	yes.DoClick = function()
		Dismiss(panel)

		if isfunction(onYes) then onYes() end
	end

	panel.OnKeyCodePressed = function(_, key)
		if key == KEY_ESCAPE then Dismiss(panel) end
	end

	return panel
end
--//
