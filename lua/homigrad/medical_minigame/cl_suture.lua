hg.Suture = hg.Suture or {}

local EVENT_PUNCTURE = 1
local EVENT_SLIP = 2

local SLIT_LENGTH = math.min(560, ScrH() * 0.55)
local SLIT_GAP = 46
local DOT_RADIUS = 9
local HIT_RADIUS = 22
local SLIP_DISTANCE = 70

local colThread = Color(255, 255, 255)
local colDot = Color(255, 255, 255, 140)
local colNext = Color(255, 255, 255, 255)
local colSteel = Color(200, 205, 212)
local colSteelDark = Color(95, 100, 110)

local TWEEZER_W, TWEEZER_H = 180, 468
local TWEEZER_TIP_X, TWEEZER_TIP_Y = 0.45, 0.075

local function LoadTweezerMaterial(name)
	local mat = Material("homigrad/tweezers/" .. name .. ".png", "smooth noclamp")
	return not mat:IsError() and mat or nil
end

local tweezerOpenMat = LoadTweezerMaterial("open")
local tweezerClosedMat = LoadTweezerMaterial("closed")

local function DrawThickLine(x1, y1, x2, y2, width, col)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	if len <= 0 then return end
	local nx, ny = -dy / len * width * 0.5, dx / len * width * 0.5

	surface.SetDrawColor(col)
	draw.NoTexture()
	surface.DrawPoly({
		{x = x1 - nx, y = y1 - ny},
		{x = x2 - nx, y = y2 - ny},
		{x = x2 + nx, y = y2 + ny},
		{x = x1 + nx, y = y1 + ny},
	})
end

local function DrawCircle(x, y, radius, col)
	local poly = {}
	for i = 0, 20 do
		local a = math.rad(i / 20 * 360)
		poly[#poly + 1] = {x = x + math.cos(a) * radius, y = y + math.sin(a) * radius}
	end
	surface.SetDrawColor(col)
	draw.NoTexture()
	surface.DrawPoly(poly)
end

local function DistanceToSegment(px, py, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local lenSqr = dx * dx + dy * dy
	local t = lenSqr > 0 and math.Clamp(((px - ax) * dx + (py - ay) * dy) / lenSqr, 0, 1) or 0
	local cx, cy = ax + dx * t, ay + dy * t
	return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
end

local function DrawFallbackHemostat(x, y)
	DrawThickLine(x, y, x + 20, y + 300, 5, colSteel)
	DrawThickLine(x, y, x - 20, y + 300, 5, colSteelDark)
end

local function DrawTweezers(x, y, angle, closed)
	local mat = closed and tweezerClosedMat or tweezerOpenMat
	if not mat then
		DrawFallbackHemostat(x, y)
		return
	end

	local w, h = TWEEZER_W, TWEEZER_H
	local offX, offY = (0.5 - TWEEZER_TIP_X) * w, (0.5 - TWEEZER_TIP_Y) * h
	local rad = math.rad(-angle)
	local cx = x + offX * math.cos(rad) - offY * math.sin(rad)
	local cy = y + offX * math.sin(rad) + offY * math.cos(rad)

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRectRotated(cx, cy, w, h, angle)
end

local PANEL = {}

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:Center()
	self:MakePopup()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:SetDraggable(false)
	self:SetCursor("none")

	self.CenterX = ScrW() / 2
	self.CenterY = ScrH() / 2
	self.Target = hg.Suture.NextTarget
	self.HandX, self.HandY = self:CursorPos()
	self.LastMX = self.HandX
	self.HandAngle = 0
	self.Squeeze = 0
	self.ShakeEnd = 0
	self.FlashAlpha = 0
	self:SetChoice(hg.Suture.NextChoice)
end

function PANEL:SetChoice(choice)
	self.Choice = choice or {label = "", index = 0, count = 0, stitches = 4}
	self.Stitches = math.max(self.Choice.stitches, 2)
	self.Done = 0
	self.OnPath = false
	self.Dots = {}

	local startY = self.CenterY - SLIT_LENGTH / 2
	for i = 1, self.Stitches do
		local side = i % 2 == 1 and -1 or 1
		self.Dots[i] = {
			x = self.CenterX + side * SLIT_GAP,
			y = startY + (i - 0.5) / self.Stitches * SLIT_LENGTH,
		}
	end
end

function PANEL:Slip()
	self.OnPath = false
	self.ShakeEnd = CurTime() + 0.3
	self.FlashAlpha = 140
	surface.PlaySound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav")

	net.Start("hg_suture_event")
		net.WriteUInt(EVENT_SLIP, 2)
	net.SendToServer()
end

function PANEL:Puncture()
	self.Done = self.Done + 1
	surface.PlaySound("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav")

	net.Start("hg_suture_event")
		net.WriteUInt(EVENT_PUNCTURE, 2)
	net.SendToServer()

	if self.Done >= self.Stitches then
		self.Finished = true
		net.Start("hg_suture_finish")
		net.SendToServer()
		timer.Simple(0.35, function()
			if IsValid(self) then self:Remove() end
		end)
	end
end

function PANEL:OnMousePressed(code)
	if code == MOUSE_RIGHT then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(code)
	if code ~= KEY_R or self.Finished or self.Choice.count <= 1 then return end
	net.Start("hg_suture_cycle")
	net.SendToServer()
end

function PANEL:Think()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() or (lp.organism and lp.organism.otrub) then
		self:Remove()
		return
	end

	local mx, my = self:CursorPos()
	local ft = FrameTime()
	self.HandX = Lerp(math.min(ft * 18, 1), self.HandX, mx)
	self.HandY = Lerp(math.min(ft * 18, 1), self.HandY, my)
	self.HandAngle = Lerp(ft * 5, self.HandAngle, math.Clamp((mx - self.LastMX) * 2, -15, 15))
	self.LastMX = mx
	self.Squeeze = math.Approach(self.Squeeze, self.OnPath and 1 or 0, ft * 6)
	self.FlashAlpha = math.Approach(self.FlashAlpha, 0, ft * 300)

	local nextDot = self.Dots[self.Done + 1]
	if self.Finished or not nextDot or not input.IsMouseDown(MOUSE_LEFT) then
		self.OnPath = false
		return
	end

	if self.Done > 0 then
		local last = self.Dots[self.Done]
		local dist = DistanceToSegment(self.HandX, self.HandY, last.x, last.y, nextDot.x, nextDot.y)
		if self.OnPath and dist > SLIP_DISTANCE then
			self:Slip()
			return
		end
		if not self.OnPath then
			self.OnPath = dist <= HIT_RADIUS * 2
			if not self.OnPath then return end
		end
	else
		self.OnPath = true
	end

	if math.Distance(self.HandX, self.HandY, nextDot.x, nextDot.y) <= HIT_RADIUS then
		self:Puncture()
	end
end

function PANEL:Paint(w, h)
	local shake = self.ShakeEnd > CurTime() and 6 or 0
	local ox, oy = math.Rand(-shake, shake), math.Rand(-shake, shake)
	local cx, cy = self.CenterX + ox, self.CenterY + oy
	local progress = self.Done / self.Stitches

	surface.SetDrawColor(0, 0, 0, 240)
	surface.DrawRect(0, 0, w, h)

	local halfWidth = 26 * (1 - progress) + 2
	local lastLeftX, lastRightX, lastY
	local segments = 32
	for i = 0, segments do
		local t = i / segments
		local y = cy - SLIT_LENGTH / 2 + t * SLIT_LENGTH
		local bulge = math.sin(t * math.pi) * halfWidth
		if lastY then
			DrawThickLine(lastLeftX, lastY, cx - bulge, y, 3, colThread)
			DrawThickLine(lastRightX, lastY, cx + bulge, y, 3, colThread)
		end
		lastLeftX, lastRightX, lastY = cx - bulge, cx + bulge, y
	end

	for i = 2, self.Stitches do
		local a, b = self.Dots[i - 1], self.Dots[i]
		DrawThickLine(a.x + ox, a.y + oy, b.x + ox, b.y + oy, i <= self.Done and 3 or 2, i <= self.Done and colThread or colDot)
	end

	for i, dot in ipairs(self.Dots) do
		if i <= self.Done then
			DrawCircle(dot.x + ox, dot.y + oy, DOT_RADIUS * 0.6, colThread)
		elseif i == self.Done + 1 then
			local pulse = 1 + math.sin(CurTime() * 8) * 0.25
			DrawCircle(dot.x + ox, dot.y + oy, DOT_RADIUS * pulse, colNext)
		else
			DrawCircle(dot.x + ox, dot.y + oy, DOT_RADIUS * 0.8, colDot)
		end
	end

	if self.OnPath and self.Done > 0 then
		local last = self.Dots[self.Done]
		DrawThickLine(last.x + ox, last.y + oy, self.HandX, self.HandY, 2, colThread)
	end

	if self.FlashAlpha > 0 then
		surface.SetDrawColor(200, 20, 20, self.FlashAlpha)
		surface.DrawRect(0, 0, w, h)
	end

	DrawTweezers(self.HandX, self.HandY, self.HandAngle, self.Squeeze > 0.5)

	local edgeY = math.max(ScreenScaleH(14), 28)
	draw.SimpleTextOutlined(self.Choice.label, "ZCity_Small", w * 0.5, edgeY, Color(255, 255, 255, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1.5, Color(0, 0, 0, 220))
	local hint = "Hold LMB and trace the dots in order   [RMB] stop"
	if self.Choice.count > 1 then
		hint = hint .. "   [R] switch wound (" .. self.Choice.index .. "/" .. self.Choice.count .. ")"
	end
	draw.SimpleTextOutlined(hint, "ZCity_Small", w * 0.5, h - edgeY, Color(200, 200, 200, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1.5, Color(0, 0, 0, 220))
	draw.DrawText(self.Done .. "/" .. self.Stitches, "HomigradFontLarge", cx - SLIT_GAP - 120, cy - 20, Color(255, 255, 255), TEXT_ALIGN_RIGHT)
end

function PANEL:OnRemove()
	if not self.Finished then
		net.Start("hg_suture_cancel")
		net.SendToServer()
	end
	if hg.Suture.Panel == self then hg.Suture.Panel = nil end
end

vgui.Register("hg_suture_minigame", PANEL, "DFrame")

local function ReadChoice()
	return {
		label = net.ReadString(),
		index = net.ReadUInt(6),
		count = net.ReadUInt(6),
		stitches = net.ReadUInt(4),
	}
end

net.Receive("hg_suture_start", function()
	hg.Suture.NextTarget = net.ReadEntity()
	hg.Suture.NextChoice = ReadChoice()

	if IsValid(hg.Suture.Panel) then
		hg.Suture.Panel.Target = hg.Suture.NextTarget
		hg.Suture.Panel:SetChoice(hg.Suture.NextChoice)
		return
	end

	hg.Suture.Panel = vgui.Create("hg_suture_minigame")
end)

net.Receive("hg_suture_target", function()
	local choice = ReadChoice()
	if IsValid(hg.Suture.Panel) then
		hg.Suture.Panel:SetChoice(choice)
	end
end)
