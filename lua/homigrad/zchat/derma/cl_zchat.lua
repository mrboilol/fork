--made by mrrp :3

hg = hg or {}
hg.zchatConVars = hg.zchatConVars or {}

local maxLength = GetConVar("zchat_maxmessagelength") or CreateConVar("zchat_maxmessagelength", "256", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Maximum message length allowed")

local NoDrop = CreateClientConVar("zchat_dropcharacters", 0, true, false, "Play the character dropping animation when erasing text", 0, 1)
local ShowTextBoxInactive = CreateClientConVar("zchat_showtextboxinactive", 1, true, false, "Showing your text in textbox while chat is turned off", 0, 1)

hg.zchatConVars["zchat_dropcharacters"] = {
	name = "zchat_dropcharacters",
	default = "0",
	description = "Show erased characters briefly when deleting text",
	min = 0,
	max = 1,
	type = "bool",
	decimals = 0
}

hg.zchatConVars["zchat_showtextboxinactive"] = {
	name = "zchat_showtextboxinactive",
	default = "1",
	description = "Show your unsent text while chat is inactive",
	min = 0,
	max = 1,
	type = "bool",
	decimals = 0
}

hg.zchatConVars["zchat_opaquebackground"] = nil

local function CallbackBind(self, callback)
	return function(_, ...)
		return callback(self, ...)
	end
end

local function PaintMarkupOverride(text, font, x, y, color, alignX, alignY, alpha)
	alpha = alpha or 255

	surface.SetTextPos(x + 1, y + 1)
	surface.SetTextColor(0, 0, 0, alpha)
	surface.SetFont(font)
	surface.DrawText(text)

	surface.SetTextPos(x, y)
	surface.SetTextColor(color.r, color.g, color.b, alpha)
	surface.SetFont(font)
	surface.DrawText(text)
end

local function MenuUnit(num)
	return math.floor(num * math.min(ScrW(), ScrH()) / 1000)
end

local settingsOutlineColor = Color(255, 255, 255, 255)
local settingsFillColor = Color(0, 0, 0, 245)
local settingsOverlayColor = Color(0, 0, 0, 170)
local settingsColorWhite = Color(255, 255, 255, 240)
local settingsColorText = Color(225, 225, 225)
local settingsColorTextDim = Color(160, 160, 160)
local chatPanelColor = Color(0, 0, 0, 255)
local chatButtonIdle = Color(0, 0, 0, 255)
local chatButtonHover = Color(30, 30, 30, 255)
local settingsIcon = Material("radialmenu/settings.png")
local chatResizeEdge = 8
local chatTopGrip = 26
local chatMinHeight = 140
local chatHatHeight = 20
local chatHatGap = 0
local chatHatWidthPadding = 0
local settingsRowHeight = 36
local settingsSliderWidth = 120
local settingsNumberWidth = 60
local settingsStringWidth = 170
local bigChat = GetConVar("sv_bigchat") or CreateConVar("sv_bigchat", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "1 - big SS13-style zchat on the right, 0 - normal zchat", 0, 1)
local gradient_d = Material("vgui/gradient-d")

local CHAT_STYLES = {
	big = {
		box = Color(25, 25, 35, 240),
		outline = Color(255, 255, 255, 255),
		thickness = 1.5,
		cookiePrefix = "zchat_bounds_v2_",
		minWidth = 180,
		maxEntries = 150,
		persistent = true,
		width = 1 / 6,
		height = 0.5,
		rightMargin = 0.008,
		bottomMargin = 0.06,
	},
	normal = {
		box = Color(25, 25, 35, 240),
		outline = Color(255, 255, 255, 255),
		thickness = 1.5,
		cookiePrefix = "zchat_bounds_",
		minWidth = 260,
		maxEntries = 100,
		persistent = false,
		width = 0.3,
		height = 0.2,
		x = 0.02,
		y = 0.67,
	},
}

local function ChatStyle()
	return hg.BigChatEnabled() and CHAT_STYLES.big or CHAT_STYLES.normal
end

local function RunZChatConVar(name, value)
	RunConsoleCommand(name, tostring(value))
end

local function GetZChatSettingTitle(data)
	if data.name == "zchat_font" then return "Font" end
	if data.name == "zchat_fontaa" then return "Anti-Aliasing" end
	if data.name == "zchat_fontsize" then return "Font Size" end
	if data.name == "zchat_fontweight" then return "Font Weight" end
	if data.name == "zchat_maxmessagelength" then return "Message Length" end
	if data.name == "zchat_dropcharacters" then return "Delete Effect" end
	if data.name == "zchat_showtextboxinactive" then return "Show Inactive Text" end
	if data.name == "zchat_hidebig" then return "Hide Big Chat" end

	local text = data.name:gsub("^zchat_", ""):gsub("_", " ")
	return text:gsub("(%a)([%w_']*)", function(first, rest)
		return string.upper(first) .. string.lower(rest)
	end)
end

local function PaintSettingRow(self, w, h)
	surface.SetDrawColor(20, 20, 30, 120)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(settingsColorWhite.r, settingsColorWhite.g, settingsColorWhite.b, 90)
	surface.DrawRect(0, h - MenuUnit(1), w, MenuUnit(1))
end

local function PaintEntryPanel(self, w, h)
	local style = ChatStyle()
	surface.SetDrawColor(style.box)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(style.outline)
	hg.DrawOutline(0, 0, w, h, style.thickness)
end

local function PaintHatPanel(self, w, h)
	local style = ChatStyle()
	surface.SetDrawColor(style.box)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(style.outline)
	hg.DrawOutline(0, 0, w, h, style.thickness)
end

local function PaintSettingsButton(self, w, h)
	surface.SetDrawColor(self:IsHovered() and chatButtonHover or chatButtonIdle)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(settingsOutlineColor)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(settingsIcon)
	surface.DrawTexturedRect(math.floor((w - 16) * 0.5), math.floor((h - 16) * 0.5), 16, 16)
end

local function PaintSettingsTextButton(self, w, h)
	surface.SetDrawColor(self:IsHovered() and chatButtonHover or chatButtonIdle)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(settingsOutlineColor)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	draw.SimpleText(self:GetText(), "ZCity_Menu_Settings_Small", w * 0.5, h * 0.5, settingsColorWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function CreateZChatBoolRow(parent, data, convar)
	local row = parent:Add("DPanel")
	row:Dock(TOP)
	row:DockMargin(MenuUnit(10), MenuUnit(4), MenuUnit(10), MenuUnit(4))
	row:SetTall(MenuUnit(settingsRowHeight))
	row.Paint = PaintSettingRow

	local title = row:Add("DLabel")
	title:SetFont("ZCity_Menu_Settings_Small")
	title:SetTextColor(settingsColorText)
	title:SetText(GetZChatSettingTitle(data))
	title:SizeToContents()

	local toggle = row:Add("DButton")
	toggle:SetSize(MenuUnit(46), MenuUnit(22))
	toggle:SetText("")
	local animProgress = convar:GetBool() and 1 or 0
	local targetProgress = animProgress
	function row:PerformLayout(w, h)
		title:SetPos(MenuUnit(12), math.floor((h - title:GetTall()) * 0.5))
		toggle:SetPos(w - MenuUnit(78), math.floor((h - toggle:GetTall()) * 0.5))
	end
	function toggle:Paint(w, h)
		animProgress = Lerp(FrameTime() * 8, animProgress, targetProgress)
		local bgR = Lerp(animProgress, 60, 155)
		local bgG = Lerp(animProgress, 60, 30)
		local bgB = Lerp(animProgress, 60, 30)
		draw.RoundedBox(MenuUnit(3), 0, 0, w, h, Color(20, 20, 20, 230))
		draw.RoundedBox(MenuUnit(3), 1, 1, w - 2, h - 2, Color(bgR, bgG, bgB, 200))
		local slsize = h - MenuUnit(6)
		local slPos = Lerp(animProgress, MenuUnit(3), w - slsize - MenuUnit(3))
		draw.RoundedBox(MenuUnit(2), slPos, MenuUnit(3), slsize, slsize, Color(245, 245, 245))
	end
	function toggle:DoClick()
		local newValue = not convar:GetBool()
		RunZChatConVar(data.name, newValue and "1" or "0")
		targetProgress = newValue and 1 or 0
	end
end

local function CreateZChatNumberRow(parent, data, convar)
	local row = parent:Add("DPanel")
	row:Dock(TOP)
	row:DockMargin(MenuUnit(10), MenuUnit(4), MenuUnit(10), MenuUnit(4))
	row:SetTall(MenuUnit(settingsRowHeight))
	row.Paint = PaintSettingRow

	local title = row:Add("DLabel")
	title:SetFont("ZCity_Menu_Settings_Small")
	title:SetTextColor(settingsColorText)
	title:SetText(GetZChatSettingTitle(data))
	title:SizeToContents()

	local decimals = data.decimals or 0
	local min = data.min or 0
	local max = data.max or math.max(convar:GetFloat(), 1)
	local sliderW = MenuUnit(settingsSliderWidth)
	local sliderBg = row:Add("DButton")
	sliderBg:SetSize(sliderW, MenuUnit(24))
	sliderBg:SetText("")

	local curVal = decimals > 0 and convar:GetFloat() or convar:GetInt()
	local frac = math.Clamp((curVal - min) / math.max(0.0001, max - min), 0, 1)
	local isDragging = false

	local function NormalizeValue(val)
		val = math.Clamp(val, min, max)
		if decimals > 0 then
			return math.Round(val, decimals)
		end

		return math.Round(val)
	end

	local function FormatValue(val)
		if decimals > 0 then
			return string.format("%." .. decimals .. "f", val)
		end

		return tostring(math.Round(val))
	end

	local function ApplyFraction(rawFrac)
		frac = math.Clamp(rawFrac, 0, 1)
		RunZChatConVar(data.name, NormalizeValue(min + frac * (max - min)))
	end

	function sliderBg:Paint(w, h)
		local trackY = h / 2 - MenuUnit(1)
		surface.SetDrawColor(20, 20, 20, 230)
		surface.DrawRect(0, trackY, w, MenuUnit(2))
		surface.SetDrawColor(settingsColorWhite.r, settingsColorWhite.g, settingsColorWhite.b, 220)
		surface.DrawRect(0, trackY, w * frac, MenuUnit(2))
		local knobX = math.Clamp(w * frac - MenuUnit(3), 0, w - MenuUnit(6))
		draw.RoundedBox(MenuUnit(2), knobX, h / 2 - MenuUnit(4), MenuUnit(6), MenuUnit(8), Color(245, 245, 245))
	end

	function sliderBg:OnMousePressed(mouseCode)
		if mouseCode == MOUSE_LEFT then
			isDragging = true
			self:MouseCapture(true)
			ApplyFraction(self:CursorPos() / math.max(self:GetWide(), 1))
		end
	end

	function sliderBg:OnMouseReleased(mouseCode)
		if mouseCode == MOUSE_LEFT then
			isDragging = false
			self:MouseCapture(false)
		end
	end

	function sliderBg:OnCursorMoved(x)
		if isDragging then
			ApplyFraction(x / math.max(self:GetWide(), 1))
		end
	end

	function sliderBg:Think()
		if not isDragging then
			local cur = decimals > 0 and convar:GetFloat() or convar:GetInt()
			frac = math.Clamp((cur - min) / math.max(0.0001, max - min), 0, 1)
		end
	end

	local valLabel = row:Add("DTextEntry")
	valLabel:SetSize(MenuUnit(settingsNumberWidth), MenuUnit(24))
	valLabel:SetFont("ZCity_Menu_Settings_Tiny")
	valLabel:SetTextColor(settingsColorText)
	valLabel:SetText(FormatValue(curVal))
	valLabel:SetNumeric(true)
	valLabel:SetUpdateOnType(false)
	valLabel.Paint = function(self, w, h)
		surface.SetDrawColor(20, 20, 20, 240)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(settingsColorWhite.r, settingsColorWhite.g, settingsColorWhite.b, 120)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		self:DrawTextEntryText(settingsColorText, Color(120, 130, 180), settingsColorText)
	end

	local function CommitValueText()
		local numVal = tonumber(valLabel:GetText())
		if not numVal then
			local cur = decimals > 0 and convar:GetFloat() or convar:GetInt()
			valLabel:SetText(FormatValue(cur))
			return
		end

		numVal = NormalizeValue(numVal)
		RunZChatConVar(data.name, numVal)
		valLabel:SetText(FormatValue(numVal))
	end

	function valLabel:OnEnter()
		CommitValueText()
		self:KillFocus()
	end

	function valLabel:OnLoseFocus()
		CommitValueText()
	end

	function valLabel:Think()
		if not self:HasFocus() then
			local cur = decimals > 0 and convar:GetFloat() or convar:GetInt()
			local curText = FormatValue(cur)
			if self:GetText() != curText then
				self:SetText(curText)
			end
		end
	end
	function row:PerformLayout(w, h)
		local ctrlX = w - MenuUnit(32)
		title:SetPos(MenuUnit(12), math.floor((h - title:GetTall()) * 0.5))
		sliderBg:SetPos(ctrlX - sliderW, math.floor((h - sliderBg:GetTall()) * 0.5))
		valLabel:SetPos(ctrlX - sliderW - MenuUnit(settingsNumberWidth + 10), math.floor((h - valLabel:GetTall()) * 0.5))
	end
end

local function CreateZChatStringRow(parent, data, convar)
	local row = parent:Add("DPanel")
	row:Dock(TOP)
	row:DockMargin(MenuUnit(10), MenuUnit(4), MenuUnit(10), MenuUnit(4))
	row:SetTall(MenuUnit(settingsRowHeight))
	row.Paint = PaintSettingRow

	local title = row:Add("DLabel")
	title:SetFont("ZCity_Menu_Settings_Small")
	title:SetTextColor(settingsColorText)
	title:SetText(GetZChatSettingTitle(data))
	title:SizeToContents()

	local ctrlW = MenuUnit(settingsStringWidth)
	local textEntry = row:Add("DTextEntry")
	textEntry:SetSize(ctrlW, MenuUnit(24))
	textEntry:SetText(convar:GetString())
	textEntry:SetUpdateOnType(true)
	textEntry:SetFont("ZCity_Menu_Settings_Tiny")
	textEntry.Paint = function(self, w, h)
		surface.SetDrawColor(20, 20, 20, 240)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(settingsColorWhite.r, settingsColorWhite.g, settingsColorWhite.b, 120)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		self:DrawTextEntryText(color_white, Color(120, 130, 180), color_white)
	end
	function textEntry:OnValueChange(val)
		RunZChatConVar(data.name, val)
	end
	function row:PerformLayout(w, h)
		local ctrlX = w - MenuUnit(32)
		title:SetPos(MenuUnit(12), math.floor((h - title:GetTall()) * 0.5))
		textEntry:SetPos(ctrlX - ctrlW, math.floor((h - textEntry:GetTall()) * 0.5))
	end
end

local function ClampChatBounds(x, y, w, h)
	local minWidth = ChatStyle().minWidth
	local maxW = math.max(minWidth, ScrW() - 8)
	local maxH = math.max(chatMinHeight, ScrH() - 8)
	w = math.Clamp(w, minWidth, maxW)
	h = math.Clamp(h, chatMinHeight, maxH)
	x = math.Clamp(x, 0, ScrW() - w)
	y = math.Clamp(y, 0, ScrH() - h)
	return math.floor(x), math.floor(y), math.floor(w), math.floor(h)
end

local function SaveChatBounds(panel)
	local x, y = panel:GetPos()
	local w, h = panel:GetSize()
	x, y, w, h = ClampChatBounds(x, y, w, h)
	local prefix = ChatStyle().cookiePrefix
	cookie.Set(prefix .. "x", x)
	cookie.Set(prefix .. "y", y)
	cookie.Set(prefix .. "w", w)
	cookie.Set(prefix .. "h", h)
end

local function SyncHatPanel(panel)
	if not IsValid(panel.hatPanel) then return end

	local x, y = panel:GetPos()
	local w, h = panel:GetSize()
	panel.hatPanel:SetPos(x - math.floor(chatHatWidthPadding * 0.5), y - chatHatHeight - chatHatGap)
	panel.hatPanel:SetSize(w + chatHatWidthPadding, chatHatHeight)
	panel.hatPanel:SetAlpha(panel.bActive and panel:GetAlpha() or 0)
end

local function GetSavedChatBounds()
	local style = ChatStyle()
	local defaultW = ScrW() * style.width
	local defaultH = ScrH() * style.height
	local defaultX = style.x and ScrW() * style.x or ScrW() - defaultW - ScrW() * style.rightMargin
	local defaultY = style.y and ScrH() * style.y or ScrH() - defaultH - ScrH() * style.bottomMargin
	local prefix = style.cookiePrefix
	local onLeft = style.persistent and hg.ChatOnLeft and hg.ChatOnLeft()
	if onLeft or (style.persistent and hg.SplitChatEnabled()) then defaultX = ScrW() * style.rightMargin end
	local w = cookie.GetNumber(prefix .. "w", defaultW)
	local h = cookie.GetNumber(prefix .. "h", defaultH)
	local x = onLeft and defaultX or cookie.GetNumber(prefix .. "x", defaultX)
	local y = cookie.GetNumber(prefix .. "y", defaultY)
	return ClampChatBounds(x, y, w, h)
end

local function OpenZChatSettings()
	if IsValid(hg.zchatSettingsOverlay) then
		hg.zchatSettingsOverlay:Remove()
	end

	local overlay = vgui.Create("DButton")
	hg.zchatSettingsOverlay = overlay
	overlay:SetText("")
	overlay:SetCursor("arrow")
	overlay:SetSize(ScrW(), ScrH())
	overlay:SetPos(0, 0)
	overlay:SetAlpha(0)
	overlay:MakePopup()
	overlay.DoClick = function()
		overlay:Remove()
	end
	function overlay:Paint(w, h)
		surface.SetDrawColor(settingsOverlayColor)
		surface.DrawRect(0, 0, w, h)
	end
	overlay:AlphaTo(255, 0.12, 0)

	local frame = vgui.Create("DPanel", overlay)
	overlay.BoxPanel = frame
	frame:SetSize(math.min(ScrW() * 0.46, 760), math.min(ScrH() * 0.68, 760))
	frame:Center()
	frame.TargetY = frame:GetY()
	frame:SetY(frame.TargetY + 10)
	frame:SetAlpha(0)
	frame:MoveTo(frame:GetX(), frame.TargetY, 0.12, 0, -1)
	frame:AlphaTo(255, 0.12, 0)
	function frame:Paint(w, h)
		surface.SetDrawColor(settingsFillColor)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(settingsOutlineColor)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("settings", "ZCity_Menu_Settings_Small", w * 0.5, 24, settingsColorWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	frame.OnMousePressed = function() end

	local close = frame:Add("DButton")
	close:SetPos(frame:GetWide() - 38, 10)
	close:SetSize(28, 28)
	close:SetText("X")
	close.Paint = PaintSettingsTextButton
	close.DoClick = function()
		overlay:Remove()
	end

	local scroll = frame:Add("DScrollPanel")
	scroll:Dock(FILL)
	scroll:DockMargin(14, 54, 14, 14)

	local settings = {}
	for name, data in pairs(hg.zchatConVars or {}) do
		if isstring(name) and name:StartWith("zchat_") then
			settings[#settings + 1] = data
		end
	end

	table.sort(settings, function(a, b)
		return a.name < b.name
	end)

	for _, data in ipairs(settings) do
		local convar = GetConVar(data.name)
		if not convar then continue end

		if data.type == "bool" then
			CreateZChatBoolRow(scroll, data, convar)
		elseif data.type == "number" then
			CreateZChatNumberRow(scroll, data, convar)
		else
			CreateZChatStringRow(scroll, data, convar)
		end
	end
end

local PANEL = {}

function PANEL:Init()
	self.text = ""
	self.linkButtons = {}
	self.alpha = 0
	self.fadeDelay = 15
	self.fadeDuration = 5
	self.yAnimDuration = 1

	self.yAnim = 5
end

function PANEL:BuildLinkButtons()
	for _, button in ipairs(self.linkButtons) do
		if IsValid(button) then button:Remove() end
	end
	self.linkButtons = {}

	if not self.markup or not self.markup.blocks then return end
	for _, block in ipairs(self.markup.blocks) do
		local url = block.url
		if isstring(url) and url:match("^https?://") then
			local linkURL = url
			local linkText = block.text
			local linkFont = block.font
			local button = vgui.Create("DButton", self)
			button:SetText("")
			button:SetCursor("hand")
			button:SetPos(block.offset.x, (block.height - block.thisY) + block.offset.y)
			button:SetSize(block.thisX, block.thisY)
			button.Paint = function(panel, width, height)
				if not panel:IsHovered() then return end

				surface.SetFont(linkFont)
				surface.SetTextColor(255, 255, 255, 255)
				surface.SetTextPos(0, 0)
				surface.DrawText(linkText)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawRect(0, height - 1, width, 1)
			end
			button.DoClick = function()
				if not Derma_Query then
					gui.OpenURL(linkURL)
					return
				end

				Derma_Query(
					linkURL,
					"Link",
					"Open", function() gui.OpenURL(linkURL) end,
					"Copy", function() SetClipboardText(linkURL) end,
					"Cancel", function() end
				)
			end
			self.linkButtons[#self.linkButtons + 1] = button
		end
	end
end

function PANEL:QueueLinkButtonBuild()
	if self.linkBuildQueued then return end
	self.linkBuildQueued = true

	timer.Simple(0, function()
		if not IsValid(self) then return end
		self.linkBuildQueued = false
		self:BuildLinkButtons()
	end)
end

function PANEL:SetMarkup(text)
	self.text = text

	self.markupWidth = self:GetWide()
	self.markup = hg.markup.Parse(self.text, self.markupWidth)
	self.markup.onDrawText = PaintMarkupOverride

	self:SetTall(self.markup:GetHeight())
	self:QueueLinkButtonBuild()

	timer.Simple(self.fadeDelay, function()
		if not IsValid(self) or ChatStyle().persistent then return end

		self:StartFade()
	end)

	self:CreateAnimation(self.yAnimDuration, {
		index = 4,
		target = {yAnim = 0},
		easing = "outQuint"
	})

	self:CreateAnimation(0.5, {
		index = 3,
		target = {alpha = 255},
	})
end

function PANEL:StartFade()
	self:CreateAnimation(self.fadeDuration, {
		index = 3,
		target = {alpha = 0}
	})
end

function PANEL:Unfade()
	self:CreateAnimation(0.3, {
		index = 3,
		target = {alpha = 255}
	})
end

function PANEL:UpdateMarkup(text)
	if self.text == text then return end

	local oldHeight = self:GetTall()
	self.text = text
	self.markupWidth = self:GetWide()
	self.markup = hg.markup.Parse(self.text, self.markupWidth)
	self.markup.onDrawText = PaintMarkupOverride

	local height = self.markup:GetHeight()
	if height ~= oldHeight then self:SetTall(height) end

	return height ~= oldHeight
end

function PANEL:PerformLayout(width, height)
	if self.markup and self.markupWidth == width then return end

	self.markupWidth = width
	self.markup = hg.markup.Parse(self.text, width)
	self.markup.onDrawText = PaintMarkupOverride

	self:SetTall(self.markup:GetHeight())
	self:QueueLinkButtonBuild()
end

function PANEL:Paint(width, height)
	local newAlpha

	if (hg.chat:GetActive()) then
		newAlpha = math.max(hg.chat.alpha, self.alpha)
	else
		newAlpha = self.alpha - (255 - hg.chat.realAlpha)
	end

	DisableClipping(true)
		local chatboxX, chatboxY = hg.chat:GetPos()
		local wide, tall = hg.chat:GetSize()

		render.SetScissorRect(chatboxX, chatboxY, chatboxX + wide, chatboxY + tall, true)
			self.markup:draw(0, self.yAnim, nil, nil, newAlpha)
		render.SetScissorRect(0, 0, 0, 0, false)
	DisableClipping(false)
end

vgui.Register("zChatMessage", PANEL, "Panel")

PANEL = {}

DEFINE_BASECLASS("DTextEntry")

function PANEL:Init()
	self:SetFont("zChatFont")
	self:SetUpdateOnType(true)
	self:SetHistoryEnabled(true)

	self.History = hg.chat.messageHistory
	self.droppedCharacters = {}

	self.prevText = ""

	self:SetTextColor(color_white)

	self:SetPaintBackground(false)

	self.m_bLoseFocusOnClickAway = false
end

function PANEL:AllowInput(newCharacter)
	local text = self:GetText()
	local maxLen = maxLength:GetInt()

	-- we can't check for the proper length using utf-8 since AllowInput is called for single bytes instead of full characters
	if (string.len(text .. newCharacter) > maxLen) then
		surface.PlaySound("common/talk.ogg")
		return true
	end
end

function PANEL:Think()
	local text = self:GetText()
	local maxLen = maxLength:GetInt()

	if (text:utf8len() > maxLen) then
		local newText = text:utf8sub(0, maxLen)

		self:SetText(newText)
		self:SetCaretPos(newText:utf8len())
	end
end

local gradient_l = Material("vgui/gradient-l")

function PANEL:Paint(w, h)
	for k, v in ipairs(self.droppedCharacters) do
		local text = v.text
		v.alpha = v.alpha - FrameTime() * 750

		DisableClipping(true)
			surface.SetTextColor(150, 150, 150, v.alpha)
			surface.SetTextPos(v.x, v.y)
			surface.SetFont("zChatFont")
			surface.DrawText(text)
		DisableClipping(false)

		if v.alpha <= 0 then
			table.remove(self.droppedCharacters, k)
		end
	end

	if ShowTextBoxInactive:GetBool() and !hg.chat:GetActive() and self.prevText != "" then
		DisableClipping(true)
		surface.SetAlphaMultiplier(1)
			surface.SetTextColor(150, 150, 150, 55)
			surface.SetTextPos(0, 0)
			surface.SetFont("zChatFont")
			surface.DrawText(self.prevText)
		surface.SetAlphaMultiplier(1)
		DisableClipping(false)
	end

	BaseClass.Paint(self, w, h)
end

function PANEL:OnValueChange(text)
	local prevText = self.prevText

	if NoDrop:GetBool() then
		local len1, len2 = string.utf8len(prevText), string.utf8len(text)

		if len1 > len2 then
			local droppedText = string.utf8sub(prevText, self:GetCaretPos() + 1, self:GetCaretPos() + (len1 - len2))

			local droppedChars = string.Explode(utf8.charpattern, droppedText)
			for k, v in ipairs(droppedChars) do
				local data = {}
				data.text = v

				surface.SetFont("zChatFont")
				-- local tw1 = surface.GetTextSize(text)
				local tw2 = surface.GetTextSize(v)

				data.x = tw2 * (self:GetCaretPos())

				-- local panelWide = self:GetWide()

				-- if data.x > panelWide then
				-- 	data.x = data.x - (data.x - panelWide)
				-- end

				data.y = 8

				data.alpha = 255

				table.insert(self.droppedCharacters, data)
			end
		end
	end

	local parent = self:GetParent()
	local chatbox = IsValid(parent) and parent:GetParent() or nil
	if IsValid(chatbox) and chatbox.OnEntryTextChanged then
		chatbox:OnEntryTextChanged(prevText, text)
	end

	self.prevText = text
end

vgui.Register("zChatboxEntry", PANEL, "DTextEntry")

PANEL = {}

AccessorFunc(PANEL, "bActive", "Active", FORCE_BOOL)
AccessorFunc(PANEL, "realAlpha", "RealAlpha", FORCE_NUMBER)

function PANEL:Init()
	hg.chat = self

	self.entries = {}
	self.messageHistory = {}
	self.Dragging = {0, 0}
	self.Sizing = nil
	self.m_iMinWidth = 340
	self.m_iMinHeight = 180

	self.alpha = 255
	self.realAlpha = 255
	self.dragState = nil
	self.chatPersistent = ChatStyle().persistent

	local x, y, w, h = GetSavedChatBounds()
	self:SetSize(w, h)
	self:SetPos(x, y)

	self.hatPanel = vgui.Create("EditablePanel")
	self.hatPanel.Paint = PaintHatPanel

	self.settingsButton = self.hatPanel:Add("DButton")
	self.hatPanel.settingsButton = self.settingsButton
	self.settingsButton:Dock(RIGHT)
	self.settingsButton:SetWide(26)
	self.settingsButton:SetText("")
	self.settingsButton.Paint = PaintSettingsButton
	self.settingsButton.DoClick = OpenZChatSettings

	self.dragHandle = self.hatPanel:Add("DButton")
	self.dragHandle:Dock(FILL)
	self.dragHandle:DockMargin(0, 0, 4, 0)
	self.dragHandle:SetText("")
	self.dragHandle:SetCursor("sizeall")
	self.dragHandle.Paint = function() end
	self.dragHandle.DoClick = function() end
	self.dragHandle.OnMousePressed = function(_, mouseCode)
		if mouseCode == MOUSE_LEFT and self:GetActive() then
			self:BeginDrag("move")
		end
	end
	self.dragHandle.OnMouseReleased = function(_, mouseCode)
		if mouseCode == MOUSE_LEFT then
			self:StopDrag()
		end
	end

	local entryPanel = self:Add("Panel")
	self.entryPanel = entryPanel
	entryPanel:SetZPos(1)
	entryPanel:Dock(BOTTOM)
	entryPanel:DockMargin(4, 0, 4, 4)
	entryPanel:SetTall(30)
	entryPanel.Paint = PaintEntryPanel

	self.entry = entryPanel:Add("zChatboxEntry")
	self.entry:Dock(FILL)
	self.entry:DockMargin(4, 0, 4, 0)
	self.entry.OnEnter = CallbackBind(self, self.OnMessageSent)

	self.history = self:Add("DScrollPanel")
	self.history:Dock(FILL)
	self.history:DockMargin(4, 2, 4, 4)

	self.spacer = self.history:Add("DPanel")
	self.spacer:Dock(TOP)
	self.spacer:SetTall(0)
	self.spacer.Paint = function() end

	SyncHatPanel(self)
	self:SetActive(false)
end

local gray = Color(255, 255, 255, 100)
local black = Color(0, 0, 0, 200)

function PANEL:PerformLayout(w, h)
	SyncHatPanel(self)
end

function PANEL:RefreshFonts()
	surface.SetFont("zChatFont")
	local _, textH = surface.GetTextSize("Hg")
	self.entry:SetFont("zChatFont")
	self.entryPanel:SetTall(math.max(30, textH + 10))

	for _, panel in ipairs(self.entries) do
		if IsValid(panel) then
			panel:InvalidateLayout(true)
		end
	end

	self.history:InvalidateLayout(true)
	self:InvalidateLayout(true)
	SaveChatBounds(self)
end

function PANEL:GetResizeMask(x, y)
	local left = x <= chatResizeEdge
	local right = x >= self:GetWide() - chatResizeEdge
	local top = y <= chatResizeEdge
	local bottom = y >= self:GetTall() - chatResizeEdge

	if not left and not right and not top and not bottom then
		return nil
	end

	local cursor = "arrow"

	if (left and top) or (right and bottom) then
		cursor = "sizenwse"
	elseif (right and top) or (left and bottom) then
		cursor = "sizenesw"
	elseif left or right then
		cursor = "sizewe"
	elseif top or bottom then
		cursor = "sizens"
	end

	return {
		left = left,
		right = right,
		top = top,
		bottom = bottom,
		cursor = cursor
	}
end

function PANEL:BeginDrag(kind, mask)
	local mouseX, mouseY = gui.MousePos()
	local x, y = self:GetPos()
	local w, h = self:GetSize()

	self.dragState = {
		kind = kind,
		mask = mask,
		mouseX = mouseX,
		mouseY = mouseY,
		x = x,
		y = y,
		w = w,
		h = h
	}

	self:MouseCapture(true)
end

function PANEL:StopDrag()
	if not self.dragState then return end
	self.dragState = nil
	self:MouseCapture(false)
	SaveChatBounds(self)
	SyncHatPanel(self)
end

function PANEL:OnMousePressed(mouseCode)
	if mouseCode != MOUSE_LEFT or not self:GetActive() then return end

	local x, y = self:ScreenToLocal(gui.MousePos())
	local mask = self:GetResizeMask(x, y)

	if mask then
		self:BeginDrag("resize", mask)
		self:SetCursor(mask.cursor)
		return
	end

end

function PANEL:OnMouseReleased(mouseCode)
	if mouseCode == MOUSE_LEFT then
		self:StopDrag()
	end
end

function PANEL:Think()
	if self.chatPersistent ~= ChatStyle().persistent then self:ApplyChatMode() end

	local historyShown = self.bActive or not (hg.BigChatHidden and hg.BigChatHidden())
	if self.history:IsVisible() ~= historyShown then
		self.history:SetVisible(historyShown)
		self:UpdateEntryVisibility()
	end

	if IsValid(self.spacer) then
		local used = 0
		for _, panel in ipairs(self.entries) do
			if IsValid(panel) then used = used + panel:GetTall() end
		end

		local gap = math.max(0, self.history:GetTall() - used - 4)
		if math.abs(self.spacer:GetTall() - gap) >= 1 then
			self.spacer:SetTall(gap)
			self.history:InvalidateLayout(true)
			local bar = self.history:GetVBar()
			if gap > 0 or self:IsScrolledToBottom() then bar:SetScroll(bar.CanvasSize) end
		end
	end

	if self.pinBottomUntil and FrameNumber() <= self.pinBottomUntil then
		self.history:InvalidateLayout(true)
		local bar = self.history:GetVBar()
		bar:SetScroll(bar.CanvasSize)
	end

	local state = self.dragState

	if state then
		local mouseX, mouseY = gui.MousePos()
		local dx = mouseX - state.mouseX
		local dy = mouseY - state.mouseY

		if state.kind == "move" then
			local x, y, w, h = ClampChatBounds(state.x + dx, state.y + dy, state.w, state.h)
			self:SetPos(x, y)
			self:SetSize(w, h)
		else
			local x = state.x
			local y = state.y
			local w = state.w
			local h = state.h
			local right = state.x + state.w
			local bottom = state.y + state.h
			local mask = state.mask

			if mask.left then
				x = math.min(state.x + dx, right - ChatStyle().minWidth)
				w = right - x
			end

			if mask.right then
				w = math.max(ChatStyle().minWidth, state.w + dx)
			end

			if mask.top then
				y = math.min(state.y + dy, bottom - chatMinHeight)
				h = bottom - y
			end

			if mask.bottom then
				h = math.max(chatMinHeight, state.h + dy)
			end

			x, y, w, h = ClampChatBounds(x, y, w, h)
			self:SetPos(x, y)
			self:SetSize(w, h)
		end

		self:InvalidateLayout()
	end

	SyncHatPanel(self)
end

function PANEL:Paint(w, h)
	local style = ChatStyle()
	if not self.bActive and hg.BigChatHidden and hg.BigChatHidden() then return end

	surface.SetDrawColor(style.box)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(style.outline)
	hg.DrawOutline(0, 0, w, h, style.thickness)

	surface.SetAlphaMultiplier(1)
		self.history:PaintManual()
		local bar = self.history:GetVBar()
		bar:SetAlpha(self.bActive and self:GetAlpha() or 0)
	surface.SetAlphaMultiplier(self:GetAlpha() / 255)

	if not self.bActive then
		if style.persistent then self:SetAlpha(self.realAlpha * (hg.DeathHUDAlpha and hg.DeathHUDAlpha() or 1)) end
		return
	end

	DisableClipping(true)
		draw.SimpleText("Hold left ALT and press ENTER to whisper", "zChatFontSmall", 5, h * 1.01 + 1, black)
		draw.SimpleText("Hold left ALT and press ENTER to whisper", "zChatFontSmall", 4, h * 1.01, gray)

		local lply = LocalPlayer()
		if IsValid(lply) and lply.organism and lply.organism.otrub then
			draw.SimpleText("Your messages are currently not visible to anyone.", "zChatFontSmall", w - 3, h * 1.01 + 1, black, TEXT_ALIGN_RIGHT)
			draw.SimpleText("Your messages are currently not visible to anyone.", "zChatFontSmall", w - 4, h * 1.01, gray, TEXT_ALIGN_RIGHT)
		end
	DisableClipping(false)

	self:SetAlpha((self.alpha - (255 - self.realAlpha)) * (hg.DeathHUDAlpha and hg.DeathHUDAlpha() or 1))
end

function PANEL:UpdateEntryVisibility()
	local pending = ShowTextBoxInactive:GetBool() and (self.entry.prevText or "") ~= ""
	local hidden = hg.BigChatHidden and hg.BigChatHidden() and not self.bActive
	local visible = not hidden and (not ChatStyle().persistent or self.bActive or pending)
	if self.entryPanel:IsVisible() == visible then return end

	self.entryPanel:SetVisible(visible)
	self:InvalidateLayout(true)
end

function PANEL:ApplyChatMode()
	local persistent = ChatStyle().persistent
	self.chatPersistent = persistent

	for _, panel in ipairs(self.entries) do
		if IsValid(panel) then
			if persistent then panel:Unfade() else panel:StartFade() end
		end
	end

	if not self.bActive then self:SetAlpha(persistent and self.realAlpha or 0) end
	self:ApplySavedBounds()
	self:UpdateEntryVisibility()
	if self.RefreshFonts then self:RefreshFonts() end
end

function PANEL:ApplySavedBounds()
	local x, y, w, h = GetSavedChatBounds()
	self:SetSize(w, h)
	self:SetPos(x, y)
	self:InvalidateLayout(true)
	SyncHatPanel(self)
end

function PANEL:OpenSettings()
	OpenZChatSettings()
end

function PANEL:SetActive(bActive, bRemovePrev)
	if (bActive) then
		self:SetAlpha(255)
		self:SetRealAlpha(255)
		self:MakePopup()
		self.entry:RequestFocus()
		self.hatPanel:SetMouseInputEnabled(true)
		self.hatPanel:SetKeyboardInputEnabled(false)

		input.SetCursorPos(self:LocalToScreen(10, self:GetTall() + 10))

		hook.Run("StartChat")
	else
		self:SetAlpha(ChatStyle().persistent and self.realAlpha or 0)
		self:SetMouseInputEnabled(false)
		self:SetKeyboardInputEnabled(false)
		self.hatPanel:SetMouseInputEnabled(false)
		self.hatPanel:SetKeyboardInputEnabled(false)

		if bRemovePrev then
			self.entry:SetText("")
			self.entry.prevText = ""
		end

		gui.EnableScreenClicker(false)

		hook.Run("FinishChat")
	end

	self.bActive = bActive
	self:UpdateEntryVisibility()
	SyncHatPanel(self)

	self.history:InvalidateLayout(true)
	local bar = self.history:GetVBar()
	bar:SetScroll(bar.CanvasSize)
	self.pinBottomUntil = bActive and FrameNumber() + 3 or nil
end

function PANEL:OnRemove()
	if IsValid(self.hatPanel) then
		self.hatPanel:Remove()
	end
end

function PANEL:AnimateAlpha(newAlpha)
	self:CreateAnimation(1, {
		index = 1,
		target = {alpha = newAlpha},
	})
end

function PANEL:AnimateRealAlpha(newAlpha)
	self:CreateAnimation(1, {
		index = 2,
		target = {realAlpha = newAlpha},
	})
end

function PANEL:SetRealAlpha(alpha)
	self.realAlpha = alpha
end

function PANEL:ToggleSettingsPanel()
	if IsValid(self.settingsFrame) then
		self.settingsFrame:SetVisible(not self.settingsFrame:IsVisible())
		if self.settingsFrame:IsVisible() then
			self.settingsFrame:MakePopup()
		end
		return
	end

	local minWidth = self.m_iMinWidth or 340
	local minHeight = self.m_iMinHeight or 180

	local frame = vgui.Create("DFrame")
	frame:SetSize(320, 210)
	frame:SetTitle("Chat Settings")
	frame:SetDeleteOnClose(false)
	frame:MakePopup()
	local x, y = self:LocalToScreen(self:GetWide() + 8, 0)
	frame:SetPos(math.Clamp(x, 0, ScrW() - frame:GetWide()), math.Clamp(y, 0, ScrH() - frame:GetTall()))

	local settingsList = frame:Add("DScrollPanel")
	settingsList:Dock(FILL)
	settingsList:DockMargin(4, 4, 4, 4)

	local sizeSlider = settingsList:Add("DNumSlider")
	sizeSlider:Dock(TOP)
	sizeSlider:SetText("Font Size")
	sizeSlider:SetMinMax(4, 30)
	sizeSlider:SetDecimals(1)
	sizeSlider:SetConVar("zchat_fontsize")

	local weightSlider = settingsList:Add("DNumSlider")
	weightSlider:Dock(TOP)
	weightSlider:SetText("Font Weight")
	weightSlider:SetMinMax(200, 1000)
	weightSlider:SetDecimals(0)
	weightSlider:SetConVar("zchat_fontweight")

	local aaCheck = settingsList:Add("DCheckBoxLabel")
	aaCheck:Dock(TOP)
	aaCheck:SetText("Font Anti-Aliasing")
	aaCheck:SetConVar("zchat_fontaa")
	aaCheck:SizeToContents()
	aaCheck:DockMargin(8, 6, 0, 0)

	local inactiveCheck = settingsList:Add("DCheckBoxLabel")
	inactiveCheck:Dock(TOP)
	inactiveCheck:SetText("Show Text While Inactive")
	inactiveCheck:SetConVar("zchat_showtextboxinactive")
	inactiveCheck:SizeToContents()
	inactiveCheck:DockMargin(8, 4, 0, 0)

	local dropCheck = settingsList:Add("DCheckBoxLabel")
	dropCheck:Dock(TOP)
	dropCheck:SetText("Drop Deleted Characters")
	dropCheck:SetConVar("zchat_dropcharacters")
	dropCheck:SizeToContents()
	dropCheck:DockMargin(8, 4, 0, 0)

	local resetButton = settingsList:Add("DButton")
	resetButton:Dock(TOP)
	resetButton:SetText("Reset Chat Position and Size")
	resetButton:DockMargin(0, 8, 0, 0)
	resetButton.DoClick = function()
		local w = math.max(minWidth, math.floor(ScrW() * 0.36))
		local h = math.max(minHeight, math.floor(ScrH() * 0.26))
		local xReset = math.floor(ScrW() * 0.02)
		local yReset = math.floor(ScrH() * 0.62)
		self:SetSize(w, h)
		self:SetPos(xReset, yReset)
		ChatPosX:SetInt(xReset)
		ChatPosY:SetInt(yReset)
		ChatSizeW:SetInt(w)
		ChatSizeH:SetInt(h)
	end

	self.settingsFrame = frame
end

function PANEL:OnMessageSent()
	local text = self.entry:GetText()

	if (text:find("%S")) then
		local lastEntry = hg.chat.messageHistory[#hg.chat.messageHistory]

		-- only add line to textentry history if it isn't the same message
		if (lastEntry != text) then
			if (#hg.chat.messageHistory >= 20) then
				table.remove(hg.chat.messageHistory, 1)
			end

			hg.chat.messageHistory[#hg.chat.messageHistory + 1] = text
		end

		net.Start("zChatMessage")
			net.WriteString(text)
		net.SendToServer()
	end

	self:SetActive(false, true)
end

local function BuildLineMarkup(elements)
	local buffer = {
		"<font=zChatFont>"
	}

	buffer = hook.Run("ModifyMessageBuffer", buffer, CHAT_SPEAKER) or buffer

	for _, v in ipairs(elements) do
		if (type(v) == "IMaterial") then
			local texture = v:GetName()

			if (texture) then
				buffer[#buffer + 1] = string.format("<img=%s,%dx%d> ", texture, v:Width(), v:Height())
			end
		elseif (istable(v) and v.r and v.g and v.b) then
			buffer[#buffer + 1] = string.format("<color=%d,%d,%d>", v.r, v.g, v.b)
		elseif (type(v) == "Player") then
			local color = team.GetColor(v:Team())

			buffer[#buffer + 1] = string.format("<color=%d,%d,%d>%s", color.r, color.g, color.b,
				v:GetName():gsub("<", "&lt;"):gsub(">", "&gt;"))
		else
			local text = tostring(v):gsub("<", "&lt;"):gsub(">", "&gt;")
			text = text:gsub("(https?://[%w%-%._~:/%?#%[%]@!$&'%(%)%*%+,;=]+)", "<url=%1><color=88,101,242>%1</color></url>")
			buffer[#buffer + 1] = text
		end
	end

	return table.concat(buffer)
end

function PANEL:IsScrolledToBottom()
	local bar = self.history:GetVBar()
	return !self:GetActive() or bar.Scroll >= bar.CanvasSize - 1
end

function PANEL:UpdateLine(panel, elements)
	if not IsValid(panel) then return end

	local stick = self:IsScrolledToBottom()
	local markup = BuildLineMarkup(elements)
	panel.baseMarkup = markup
	if not panel:UpdateMarkup(markup) then return end

	self.history:InvalidateLayout(true)
	if stick then
		local bar = self.history:GetVBar()
		bar:SetScroll(bar.CanvasSize)
	end
end

local REPEAT_MARKUP = "<color=150,150,150> (%dx)"

function PANEL:MergeRepeat(panel)
	if not IsValid(panel) then return panel end

	panel.streaming = nil

	local index
	for i = #self.entries, 1, -1 do
		if self.entries[i] == panel then
			index = i
			break
		end
	end

	local previous = index and self.entries[index - 1]
	if not IsValid(previous) or previous.streaming or previous.baseMarkup ~= panel.baseMarkup then return panel end

	previous.repeatCount = (previous.repeatCount or 1) + 1
	previous:UpdateMarkup(previous.baseMarkup .. string.format(REPEAT_MARKUP, previous.repeatCount))

	table.remove(self.entries, index)
	panel:SetVisible(false)
	panel:Remove()

	self.history:InvalidateLayout(true)
	if self:IsScrolledToBottom() then
		local bar = self.history:GetVBar()
		bar:SetScroll(bar.CanvasSize)
	end

	return previous
end

function PANEL:AddLine(elements, streaming, noPopup)
	if not streaming and not noPopup and not self.bActive and hg.BigChatHidden and hg.BigChatHidden() and hg.PushChatPopup then
		hg.PushChatPopup(elements)
	end

	local panel = self.history:Add("zChatMessage")
	panel:Dock(TOP)
	panel:InvalidateParent(true)

	local markup = BuildLineMarkup(elements)
	panel.baseMarkup = markup
	panel:SetMarkup(markup)

	if (#self.entries >= ChatStyle().maxEntries) then
		local oldPanel = table.remove(self.entries, 1)

		if (IsValid(oldPanel)) then
			oldPanel:Remove()
		end
	end

	local bar = self.history:GetVBar()
	local bScroll = !self:GetActive() or bar.Scroll == bar.CanvasSize -- only scroll when we're not at the bottom/inactive

	if bScroll then
		bar:SetScroll(bar.CanvasSize)
	end

	self.entries[#self.entries + 1] = panel

	if streaming then
		panel.streaming = true

		return panel
	end

	return self:MergeRepeat(panel)
end

local popups = {}
local POPUP_HOLD, POPUP_FADE, POPUP_MAX, POPUP_RISE = 1.8, 3.2, 8, 40
local POPUP_LIFE = POPUP_HOLD + POPUP_FADE

local function PushPopup(elements)
	local segments, color = {}, color_white
	for _, v in ipairs(elements) do
		if type(v) == "IMaterial" then
			continue
		elseif type(v) == "Player" then
			segments[#segments + 1] = {team.GetColor(v:Team()), v:GetName()}
		elseif istable(v) and v.r and v.g and v.b then
			color = v
		else
			segments[#segments + 1] = {color, tostring(v)}
		end
	end
	if #segments == 0 then return end

	popups[#popups + 1] = {segments = segments, born = CurTime()}
	while #popups > POPUP_MAX do table.remove(popups, 1) end
end

hg.PushChatPopup = PushPopup

function hg.MoveChat(dx, dy)
	local chat = hg.chat
	if not IsValid(chat) then return end

	local x, y = chat:GetPos()
	local w, h = chat:GetSize()
	x, y, w, h = ClampChatBounds(x + dx, y + dy, w, h)
	chat:SetPos(x, y)
	SaveChatBounds(chat)
	SyncHatPanel(chat)
end

function hg.ResetChat()
	local prefix = ChatStyle().cookiePrefix
	for _, key in ipairs({"x", "y", "w", "h"}) do cookie.Delete(prefix .. key) end
	if IsValid(hg.chat) then hg.chat:ApplySavedBounds() end
end

local popupLineHeight = 0

local SPLIT_RIGHT, SPLIT_BOTTOM, SPLIT_WIDTH, SPLIT_LINES = 0.64, 0.34, 0.2, 5

local function SplitPopupAnchor()
	local ox, oy = 0, 0
	if hg.HudEdit then ox, oy = hg.HudEdit.Offset("popups") end

	return ScrW() * SPLIT_RIGHT + ox, ScrH() * SPLIT_BOTTOM + oy
end

function hg.HiddenChatAnchor()
	if hg.SplitChatEnabled() then
		local right, bottom = SplitPopupAnchor()

		return right, bottom, #popups * popupLineHeight
	end

	local x, y, w, h = GetSavedChatBounds()

	return x + w - 8, y + h - 6, #popups * popupLineHeight
end

local function RegisterSplitRect()
	if not hg.HudEdit or not hg.SplitChatEnabled() then return end

	local scale = hg.UIScale and hg.UIScale() or 1
	local right, bottom = SplitPopupAnchor()
	local w, h = ScrW() * SPLIT_WIDTH, math.max(popupLineHeight, 24 * scale) * SPLIT_LINES
	hg.HudEdit.Rect("popups", right - w, bottom - h, w, h)
end

local function DrawPopups(deathAlpha)
	if #popups == 0 then return end

	local now = CurTime()
	local scale = hg.UIScale and hg.UIScale() or 1
	local right, baseY = hg.HiddenChatAnchor()

	surface.SetFont("zChatFont")
	local _, lineHeight = surface.GetTextSize("Hg")
	lineHeight = lineHeight + 4 * scale
	popupLineHeight = lineHeight

	for i = #popups, 1, -1 do
		local popup = popups[i]
		local age = now - popup.born
		if age > POPUP_LIFE then
			table.remove(popups, i)
		else
			local progress = math.max(age - POPUP_HOLD, 0) / POPUP_FADE
			local alpha = (1 - progress) * 255 * deathAlpha
			local y = baseY - lineHeight * 0.5 - (#popups - i) * lineHeight - progress * POPUP_RISE * scale

			local total = 0
			for _, segment in ipairs(popup.segments) do
				total = total + surface.GetTextSize(segment[2])
			end

			local x = right - total
			for _, segment in ipairs(popup.segments) do
				local color = segment[1]
				draw.SimpleText(segment[2], "zChatFont", x + 1, y + 1, Color(0, 0, 0, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(segment[2], "zChatFont", x, y, Color(color.r, color.g, color.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				x = x + surface.GetTextSize(segment[2])
			end
		end
	end
end

hook.Add("HUDPaint", "zChatHiddenPopups", function()
	if not LocalPlayer():Alive() then return end
	RegisterSplitRect()
	DrawPopups(hg.DeathHUDAlpha and hg.DeathHUDAlpha() or 1)
end)

local function DrawDeathPopups()
	DrawPopups(1)
end

hook.Add("HG_DeathOverlayHUD", "zChatHiddenPopups", DrawDeathPopups)
hook.Add("HG_DeathTransitionHUD", "zChatHiddenPopups", DrawDeathPopups)

cvars.AddChangeCallback("zchat_hidebig", function()
	if IsValid(hg.chat) and hg.chat.UpdateEntryVisibility then hg.chat:UpdateEntryVisibility() end
end, "zchat_hidebig_refresh")

function PANEL:AddMessage(...)
	self:AddLine({...})

	chat.PlaySound()
end

function PANEL:ClearLines()
	for _, panel in ipairs(self.entries) do
		if IsValid(panel) then panel:Remove() end
	end

	self.entries = {}
	self.history:InvalidateLayout(true)
end

do
	local wasDead = false

	hook.Add("Think", "zChatClearOnRespawn", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		if not ply:Alive() then
			wasDead = true
		elseif wasDead then
			wasDead = false
			popups = {}
			if IsValid(hg.chat) and hg.chat.ClearLines then hg.chat:ClearLines() end
		end
	end)
end

hook.Add("HG_DeathOverlayHUD", "zChat", function()
	local chat = hg.chat
	if not IsValid(chat) then return end

	if IsValid(chat.hatPanel) then chat.hatPanel:PaintManual() end
	chat:PaintManual()
end)

vgui.Register("zChatbox", PANEL, "EditablePanel")

concommand.Add("zchat_settings", function()
	OpenZChatSettings()
end)
