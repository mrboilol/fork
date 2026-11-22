hg = hg or {}
hg.HudEdit = hg.HudEdit or {}

local HudEdit = hg.HudEdit
local SAVE_FILE = "hg_hud_layout.txt"
local RECT_MAX_AGE = 0.25
local SNAP_DIST = 14
local WIGGLE_LIMIT = 45

HudEdit.offsets = HudEdit.offsets or {}
HudEdit.rects = HudEdit.rects or {}

local ELEMENTS = {
	{id = "subrosa", label = "Sub Rosa figure"},
	{id = "face", label = "Face"},
	{id = "moodles", label = "Moodles"},
	{id = "chat", label = "Big chat"},
}

local TOGGLES = {
	{label = "Sub Rosa figure", cvar = "hg_hud_subrosa", element = "subrosa"},
	{label = "Moodles", cvar = "hg_hud_moodles", element = "moodles"},
	{label = "Big chat", cvar = "hg_hud_bigchat", element = "chat"},
	{label = "Face (nilguy)", cvar = "hg_hidenilguy", invert = true, element = "face"},
	{label = "Face as first moodle", cvar = "hg_nilguyisamoodle"},
	{label = "Hide big chat box (pop-ups only)", cvar = "zchat_hidebig"},
}

CreateClientConVar("hg_hidenilguy", "0", true, false, "Hide the face HUD box", 0, 1)

local function load()
	local raw = file.Read(SAVE_FILE, "DATA")
	local data = raw and util.JSONToTable(raw)
	if istable(data) then HudEdit.offsets = data end
end

local function save()
	file.Write(SAVE_FILE, util.TableToJSON(HudEdit.offsets))
end

load()

function HudEdit.Offset(id)
	local offset = HudEdit.offsets[id]
	if not offset then return 0, 0 end

	return offset.x or 0, offset.y or 0
end

function HudEdit.Rect(id, x, y, w, h)
	local rect = HudEdit.rects[id]
	if not rect then
		rect = {}
		HudEdit.rects[id] = rect
	end
	rect.x, rect.y, rect.w, rect.h, rect.time = x, y, w, h, SysTime()
end

function HudEdit.PushOffset(id)
	local ox, oy = HudEdit.Offset(id)
	if ox == 0 and oy == 0 then return false end

	local matrix = Matrix()
	matrix:Translate(Vector(ox, oy, 0))
	cam.PushModelMatrix(matrix, true)

	return true
end

function HudEdit.PopOffset(pushed)
	if pushed then cam.PopModelMatrix() end
end

local function toggleFor(id)
	for _, toggle in ipairs(TOGGLES) do
		if toggle.element == id then return toggle end
	end
end

local function setToggle(toggle, shown)
	local on = toggle.invert and not shown or (not toggle.invert and shown)
	RunConsoleCommand(toggle.cvar, on and "1" or "0")
end

local function toggleShown(toggle)
	local cvar = GetConVar(toggle.cvar)
	if not cvar then return not toggle.invert end
	local value = cvar:GetBool()

	return toggle.invert and not value or (not toggle.invert and value)
end

local function elementRect(id)
	if id == "chat" then
		local chat = hg.chat
		if IsValid(chat) and hg.BigChatEnabled() then
			local x, y = chat:GetPos()
			local w, h = chat:GetSize()

			return x, y, w, h
		end

		return
	end

	local rect = HudEdit.rects[id]
	if rect and SysTime() - rect.time < RECT_MAX_AGE then return rect.x, rect.y, rect.w, rect.h end
end

local function hitTest(mx, my)
	for index = #ELEMENTS, 1, -1 do
		local id = ELEMENTS[index].id
		local x, y, w, h = elementRect(id)
		if x and mx >= x and mx <= x + w and my >= y and my <= y + h then return id end
	end
end

local function moveElement(id, dx, dy)
	if id == "chat" then
		if hg.MoveChat then hg.MoveChat(dx, dy) end

		return
	end

	local offset = HudEdit.offsets[id]
	if not offset then
		offset = {x = 0, y = 0}
		HudEdit.offsets[id] = offset
	end
	offset.x, offset.y = offset.x + dx, offset.y + dy
end

local function labelFor(id)
	for _, element in ipairs(ELEMENTS) do
		if element.id == id then return element.label end
	end
end

function HudEdit.Open()
	if IsValid(HudEdit.panel) then HudEdit.panel:Remove() end

	local panel = vgui.Create("DPanel")
	HudEdit.panel = panel
	panel:SetSize(ScrW(), ScrH())
	panel:SetPos(0, 0)
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)

	local drag
	local hovered

	function panel:Paint(w, h)
		surface.SetDrawColor(0, 0, 0, 90)
		surface.DrawRect(0, 0, w, h)

		for _, element in ipairs(ELEMENTS) do
			local x, y, rw, rh = elementRect(element.id)
			if x then
				local active = hovered == element.id or (drag and drag.id == element.id)
				surface.SetDrawColor(255, 255, 255, active and 255 or 140)
				surface.DrawOutlinedRect(x, y, rw, rh, active and 2 or 1)
				draw.SimpleText(element.label, "HomigradFontSmall", x + 4, y - 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			end
		end

		if drag then
			surface.SetDrawColor(255, 255, 255, 40)
			surface.DrawRect(math.floor(w * 0.5), 0, 1, h)
			surface.DrawRect(0, math.floor(h * 0.5), w, 1)

			surface.SetDrawColor(80, 220, 255, 230)
			if drag.lineX then surface.DrawRect(math.Clamp(math.floor(drag.lineX), 0, w - 1), 0, 1, h) end
			if drag.lineY then surface.DrawRect(0, math.Clamp(math.floor(drag.lineY), 0, h - 1), w, 1) end
		end

		draw.SimpleText("Hud editor: drag elements with left mouse, right click an element to erase it, Esc to finish", "HomigradFontMedium", w * 0.5, 14, color_white, TEXT_ALIGN_CENTER)
	end

	local function snapAxis(pos, size, screen)
		local best, bestDist, line
		local anchors = {{0, 0}, {size * 0.5, screen * 0.5}, {size, screen}}
		for _, anchor in ipairs(anchors) do
			local dist = math.abs(pos + anchor[1] - anchor[2])
			if dist <= SNAP_DIST and (not bestDist or dist < bestDist) then
				best, bestDist, line = anchor[2] - anchor[1], dist, anchor[2]
			end
		end

		if best then return best, line end

		return pos
	end

	local function wiggleSnap(state, axis, delta, raw, size, screen)
		local snapped, line = snapAxis(raw, size, screen)
		local freeKey, wiggleKey = "free" .. axis, "wiggle" .. axis

		if not line then
			state[freeKey], state[wiggleKey] = false, 0

			return raw
		end

		if state[freeKey] then return raw end

		state[wiggleKey] = (state[wiggleKey] or 0) + math.abs(delta)
		if state[wiggleKey] > WIGGLE_LIMIT then
			state[freeKey] = true

			return raw
		end

		return snapped, line
	end

	function panel:OnMousePressed(code)
		local x, y = self:CursorPos()
		local id = hitTest(x, y)
		if not id then return end

		if code == MOUSE_LEFT then
			local rx, ry, rw, rh = elementRect(id)
			drag = {id = id, x = x, y = y, rawX = rx, rawY = ry, curX = rx, curY = ry, w = rw, h = rh}
		elseif code == MOUSE_RIGHT then
			local toggle = toggleFor(id)
			if toggle then setToggle(toggle, false) end
		end
	end

	function panel:OnMouseReleased()
		if drag then save() end
		drag = nil
	end

	function panel:Think()
		local x, y = self:CursorPos()
		hovered = hitTest(x, y)

		if drag then
			local dx, dy = x - drag.x, y - drag.y
			drag.rawX, drag.rawY = drag.rawX + dx, drag.rawY + dy
			drag.x, drag.y = x, y

			if drag.id == "chat" then
				local cx, cy = elementRect("chat")
				if cx then drag.curX, drag.curY = cx, cy end
			end

			local snapX, lineX = wiggleSnap(drag, "X", dx, drag.rawX, drag.w, ScrW())
			local snapY, lineY = wiggleSnap(drag, "Y", dy, drag.rawY, drag.h, ScrH())
			drag.lineX, drag.lineY = lineX, lineY

			moveElement(drag.id, snapX - drag.curX, snapY - drag.curY)
			drag.curX, drag.curY = snapX, snapY
		end

		for _, check in ipairs(self.checks or {}) do
			local shown = toggleShown(check.toggle)
			if check:GetChecked() ~= shown then
				check.updating = true
				check:SetChecked(shown)
				check.updating = false
			end
		end
	end

	function panel:OnKeyCodePressed(key)
		if key ~= KEY_ESCAPE then return end

		self:Remove()
		timer.Simple(0, function()
			if IsValid(MainMenu) then return end
			hook.Run("OnPauseMenuShow")
		end)
	end

	local list = vgui.Create("DPanel", panel)
	list:SetSize(math.max(ScrW() * 0.2, 300), 40 + (#TOGGLES + 2) * 26)
	list:SetPos(16, 40)
	function list:Paint(w, h)
		surface.SetDrawColor(0, 0, 0, 220)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("Elements", "HomigradFontMedium", 8, 6, color_white)
	end

	panel.checks = {}
	for index, toggle in ipairs(TOGGLES) do
		local check = vgui.Create("DCheckBoxLabel", list)
		check:SetPos(10, 14 + index * 26)
		check:SetText(toggle.label)
		check:SetTextColor(color_white)
		check:SizeToContents()
		check:SetChecked(toggleShown(toggle))
		check.toggle = toggle
		function check:OnChange(value)
			if self.updating then return end
			setToggle(self.toggle, value)
		end
		panel.checks[#panel.checks + 1] = check
	end

	local reset = vgui.Create("DButton", list)
	reset:SetText("Reset positions")
	reset:SetPos(10, 14 + (#TOGGLES + 1) * 26)
	reset:SetSize(130, 22)
	function reset:DoClick()
		HudEdit.offsets = {}
		save()
		if hg.ResetChat then hg.ResetChat() end
	end

	local done = vgui.Create("DButton", list)
	done:SetText("Done")
	done:SetPos(150, 14 + (#TOGGLES + 1) * 26)
	done:SetSize(80, 22)
	function done:DoClick()
		panel:Remove()
	end
end

concommand.Add("hg_hud_edit", function()
	HudEdit.Open()
end)

hook.Add("OnShowZCityPause", "HudEditEsc", function()
	if IsValid(HudEdit.panel) then HudEdit.panel:Remove() end
end)

list.Set("DesktopWindows", "HomigradHudEditor", {
	title = "Edit HUD",
	icon = "icon64/tool.png",
	init = function()
		RunConsoleCommand("-menu_context")
		timer.Simple(0.1, HudEdit.Open)
	end
})
