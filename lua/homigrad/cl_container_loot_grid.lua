if SERVER then return end

hg = hg or {}

local lootMenuGradient = Material("vgui/gradient-d")
local cooldown = 0

local function GetItemName(class)
	local weapon = weapons.Get(class)
	local entity = scripted_ents.Get(class)
	return (weapon and weapon.PrintName) or (entity and entity.PrintName) or tostring(class)
end

local function GetItemIcon(class)
	local weapon = weapons.Get(class)
	if weapon then
		local icon = weapon.WepSelectIcon2 or weapon.WepSelectIcon
		return icon, icon ~= nil, weapon.WepSelectIcon2 == nil, weapon.WepSelectIcon2box
	end

	local entity = scripted_ents.Get(class)
	if entity and entity.IconOverride then
		return entity.IconOverride, true, false, true
	end
end

local function DrawScrollingText(panel, value, font, x, y, maxWidth, color)
	local textValue = language.GetPhrase(value or "Unknown")
	surface.SetFont(font)
	local textWidth, textHeight = surface.GetTextSize(textValue)
	if textWidth <= maxWidth then
		draw.SimpleText(textValue, font, x, y, color, TEXT_ALIGN_CENTER)
		return
	end

	local left = x - maxWidth / 2
	local screenX, screenY = panel:LocalToScreen(left, y)
	local offset = (textWidth - maxWidth) * ((1 - math.cos(CurTime() * 1.4)) / 2)
	render.SetScissorRect(screenX, screenY, screenX + maxWidth, screenY + textHeight, true)
	surface.SetTextColor(color)
	surface.SetTextPos(left - offset, y)
	surface.DrawText(textValue)
	render.SetScissorRect(0, 0, 0, 0, false)
end

local function SortedItemIDs(items)
	local ids = table.GetKeys(items or {})
	table.sort(ids, function(a, b)
		if isnumber(a) and isnumber(b) then return a < b end
		return tostring(a) < tostring(b)
	end)
	return ids
end

local function GetItemWeight(class)
	local weapon = weapons.Get(class)
	local weight = weapon and (tonumber(weapon.weight) or tonumber(weapon.Weight))
	if weapon and not weight then weight = weapon.weaponInvCategory == 1 and 8 or 3 end
	return tonumber(weight) or 1
end

local function GetItemGridSize(class)
	local weight = GetItemWeight(class)
	if weight >= 8 then return 3, 2 end
	if weight >= 5 then return 2, 2 end
	if weight >= 2.5 then return 2, 1 end
	return 1, 1
end

function hg.OpenContainerLootGrid(options)
	options = options or {}
	local ent = options.ent
	if not IsValid(ent) then return end

	if IsValid(hg.ContainerLootMenu) then
		hg.ContainerLootMenu:Remove()
	end

	local items = options.items or {}
	ent.hgContainerFoundLoot = ent.hgContainerFoundLoot or {}
	local foundLoot = ent.hgContainerFoundLoot
	local sizeX = math.floor(math.min(math.max(ScrW() * 0.62, 420), ScrW() - 20, 980))
	local sizeY = math.floor(math.min(math.max(ScrH() * 0.74, 360), ScrH() - 20, 760))
	local menu = vgui.Create("ZFrame")
	hg.ContainerLootMenu = menu
	menu.ent = ent
	menu.entindex = ent:EntIndex()
	menu:SetTitle("")
	menu:SetSize(sizeX, sizeY)
	menu:Center()
	menu:MakePopup()
	menu:SetKeyboardInputEnabled(false)
	menu:ShowCloseButton(true)
	menu:SetVisible(true)
	menu:SetMouseInputEnabled(true)
	menu:SetColorBG(Color(0, 0, 0, 245))
	menu:SetColorBR(Color(255, 255, 255, 255))
	menu.Created = CurTime()

	menu.Paint = function(self, w, h)
		if hg.DrawBlur then hg.DrawBlur(self, 2) end
		surface.SetDrawColor(0, 0, 0, 245)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(40, 40, 40, 55)
		surface.SetMaterial(lootMenuGradient)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	if IsValid(menu.btnClose) then
		menu.btnClose:SetVisible(false)
		menu.btnClose:SetMouseInputEnabled(false)
	end

	local close = menu:Add("DButton")
	close:SetPos(sizeX - 38, 10)
	close:SetSize(28, 28)
	close:SetText("X")
	close.Paint = function(self, w, h)
		surface.SetDrawColor(self:IsHovered() and Color(34, 34, 34, 235) or Color(20, 20, 20, 235))
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText(self:GetText(), "ZCity_Menu_Settings_Small", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	close.DoClick = function() menu:Close() end

	menu.PaintOver = function(self, w, h)
		draw.DrawText(options.title or "Container", "ZCity_Menu_Settings_Small", 14, 12, color_white, TEXT_ALIGN_LEFT)
		draw.DrawText(options.helpText or "Hold LMB - Search | LMB - Take | R - Close", "ZCity_Tiny", w / 2, h - h * 0.04, Color(255, 255, 255, 45), TEXT_ALIGN_CENTER)
	end

	local released = false
	local function Release()
		if released then return end
		released = true
		if options.onClose then options.onClose(ent) end
		if hg.ContainerLootMenu == menu then hg.ContainerLootMenu = nil end
	end

	menu.OnRemove = Release
	function menu:Think()
		if not IsValid(self.ent) then self:Close() return end
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() or (ply.organism and ply.organism.otrub) then self:Close() return end
		if self.ent:GetPos():DistToSqr(ply:GetPos()) > (options.maxDistance or 125) ^ 2 then self:Close() return end
		if input.IsKeyDown(KEY_R) then self:Close() end
	end

	local cols = ScrW() < 900 and 5 or 6
	local gap = math.max(math.floor(ScrH() * 0.004), 4)
	local scrollLane = 16
	local minRows = ScrH() < 720 and 6 or 7
	local boardMaxW = sizeX - 28 - scrollLane
	local boardMaxH = sizeY - 88
	local cell = math.floor(math.max(math.min((boardMaxW - (cols + 1) * gap) / cols, (boardMaxH - (minRows + 1) * gap) / minRows), 42))
	local boardW = cols * cell + (cols + 1) * gap
	local ids = SortedItemIDs(items)
	local used = {}
	local maxRow = 1
	local layouts = {}
	local function CanPlace(x, y, blockW, blockH)
		if x + blockW - 1 > cols then return false end
		for yy = y, y + blockH - 1 do
			for xx = x, x + blockW - 1 do
				if used[yy] and used[yy][xx] then return false end
			end
		end
		return true
	end
	local function Occupy(x, y, blockW, blockH)
		for yy = y, y + blockH - 1 do
			used[yy] = used[yy] or {}
			for xx = x, x + blockW - 1 do used[yy][xx] = true end
		end
		maxRow = math.max(maxRow, y + blockH - 1)
	end
	for _, itemID in ipairs(ids) do
		local item = items[itemID]
		if not item or not item.class then continue end
		local blockW, blockH = GetItemGridSize(item.class)
		for y = 1, 80 do
			local placed = false
			for x = 1, cols do
				if CanPlace(x, y, blockW, blockH) then
					Occupy(x, y, blockW, blockH)
					layouts[itemID] = {x = x, y = y, w = blockW, h = blockH}
					placed = true
					break
				end
			end
			if placed then break end
		end
	end
	local rows = math.max(minRows, maxRow)
	local boardH = rows * cell + (rows + 1) * gap

	local scroll = vgui.Create("DScrollPanel", menu)
	scroll:SetPos(math.floor((sizeX - boardW - scrollLane) / 2), 44)
	scroll:SetSize(boardW + scrollLane, sizeY - 88)
	scroll.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, 245)
		surface.DrawRect(0, 0, boardW, h)
		surface.SetDrawColor(40, 40, 40, 55)
		surface.SetMaterial(lootMenuGradient)
		surface.DrawTexturedRect(0, 0, boardW, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawOutlinedRect(0, 0, boardW, h, 1)
	end

	local sbar = scroll:GetVBar()
	sbar:SetHideButtons(true)
	sbar.Paint = function(self, w, h) draw.RoundedBox(0, w - 4, 0, 4, h, Color(30, 30, 30, 180)) end
	sbar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(0, w - 4, 0, 4, h, Color(115, 115, 115, 230)) end

	local grid = vgui.Create("DPanel", scroll)
	grid:SetSize(boardW, boardH)
	grid.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(24, 24, 24, 245))
		for row = 0, rows - 1 do
			for col = 0, cols - 1 do
				surface.SetDrawColor(42, 42, 42, 175)
				surface.DrawOutlinedRect(gap + col * (cell + gap), gap + row * (cell + gap), cell, cell, 1)
			end
		end
		surface.SetDrawColor(85, 85, 85, 230)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	scroll:AddItem(grid)

	for _, itemID in ipairs(ids) do
		local item = items[itemID]
		local class = item and item.class
		local layout = layouts[itemID]
		if not class or not layout then continue end

		local button = vgui.Create("DButton", grid)
		button:SetText("")
		button:SetPos(gap + (layout.x - 1) * (cell + gap), gap + (layout.y - 1) * (cell + gap))
		button:SetSize(layout.w * cell + (layout.w - 1) * gap, layout.h * cell + (layout.h - 1) * gap)
		button.RevealTime = math.Clamp(0.45 + GetItemWeight(class) * 0.24, 0.65, 4)
		button.Think = function(self)
			if foundLoot[itemID] then return end
			if self:IsHovered() and input.IsMouseDown(MOUSE_LEFT) then
				self.RevealStart = self.RevealStart or CurTime()
				self.RevealProgress = math.Clamp((CurTime() - self.RevealStart) / self.RevealTime, 0, 1)
				if self.RevealProgress >= 1 then
					foundLoot[itemID] = true
					self.HoldLock = true
					surface.PlaySound("arc9_eft_shared/generic_mag_pouch_in" .. math.random(7) .. ".ogg")
				end
			else
				self.RevealStart = nil
				self.RevealProgress = 0
				if not input.IsMouseDown(MOUSE_LEFT) then self.HoldLock = nil end
			end
		end
		button.DoClick = function(self)
			if self.HoldLock then self.HoldLock = nil return end
			if not foundLoot[itemID] then return end
			if cooldown > CurTime() then return end
			cooldown = CurTime() + 0.3
			if options.onTake then options.onTake(ent, itemID, item) end
			surface.PlaySound("arc9_eft_shared/generic_mag_pouch_in" .. math.random(7) .. ".ogg")
			self:Remove()
		end

		button.col1 = 100
		button.Paint = function(self, w, h)
			local found = foundLoot[itemID]
			self.col1 = Lerp(0.1, self.col1, self:IsHovered() and 180 or 100)
			if self:IsHovered() then
				self.SoundKD = self.SoundKD or 0
				if self.SoundKD < CurTime() then
					surface.PlaySound("arc9_eft_shared/generic_mag_pouch_out" .. math.random(7) .. ".ogg")
				end
				self.SoundKD = CurTime() + 0.1
			end

			surface.SetDrawColor(38 + self.col1 / 8, 38 + self.col1 / 8, 38 + self.col1 / 8, 235)
			surface.DrawRect(0, 0, w, h)
			for yy = 0, layout.h - 1 do
				for xx = 0, layout.w - 1 do
					surface.SetDrawColor(70, 70, 70, 145)
					surface.DrawOutlinedRect(xx * (cell + gap), yy * (cell + gap), cell, cell, 1)
				end
			end
			if not found then
				draw.SimpleText("?", "ZCity_Small", w / 2, h / 2, Color(225, 225, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				if (self.RevealProgress or 0) > 0 then
					surface.SetDrawColor(150, 150, 150, 210)
					surface.DrawRect(6, h - 10, (w - 12) * self.RevealProgress, 4)
				end
				surface.SetDrawColor(self.col1, self.col1, self.col1, 210)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				return
			end
			local icon, hasIcon, override, quad = GetItemIcon(class)
			if icon then self.Icon = self.Icon or (isstring(icon) and Material(icon)) or icon end
			if hasIcon and self.Icon then
				if override and isnumber(icon) then surface.SetTexture(self.Icon) else surface.SetMaterial(self.Icon) end
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(quad and w / 5 + 5 or -5, 5, quad and (w / 2 + 2.5) or (w + 10), quad and h / 1.3 or h - 10)
			end
			surface.SetDrawColor(self.col1, self.col1, self.col1, 210)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			DrawScrollingText(self, GetItemName(class), "ZCity_Tiny", w / 2, hasIcon and h / 1.3 or h / 3, w - 10, color_white)
		end
	end

	return menu
end
