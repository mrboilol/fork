if SERVER then return end

hg = hg or {}

local cooldown = 0
local closeDuration = 0.18
local openDuration = 0.34

local function GetItemName(class)
	local weapon = weapons.Get(class)
	local entity = scripted_ents.Get(class)
	return language.GetPhrase((weapon and weapon.PrintName) or (entity and entity.PrintName) or tostring(class))
end

local function ResolveMaterial(icon)
	if not icon or icon == "" or icon == "null" then return end
	if isnumber(icon) then
		if icon > 0 then return icon, true end
		return
	end
	if isstring(icon) then
		local material = Material(icon, "smooth")
		if not material:IsError() then return material, false end
		return
	end
	if tostring(icon):lower():find("null", 1, true) then return end
	if icon.IsError and icon:IsError() then return end
	return icon, false
end

local function GetItemIcon(class)
	local weapon = weapons.Get(class)
	if weapon then
		local candidates = {weapon.WepSelectIcon2, weapon.WepSelectIcon, weapon.IconOverride}
		for _, candidate in ipairs(candidates) do
			local icon, isTexture = ResolveMaterial(candidate)
			if icon then return icon, isTexture end
		end
	end

	local entity = scripted_ents.Get(class)
	if entity then
		local icon, isTexture = ResolveMaterial(entity.IconOverride)
		if icon then return icon, isTexture end
	end

	local icon = Material("entities/" .. class .. ".png", "smooth")
	if not icon:IsError() then return icon, false end

	icon = Material("vgui/entities/" .. class, "smooth")
	if not icon:IsError() then return icon, false end
end

local function SortedItemIDs(items)
	local ids = table.GetKeys(items or {})
	table.sort(ids, function(a, b)
		if isnumber(a) and isnumber(b) then return a < b end
		return tostring(a) < tostring(b)
	end)
	return ids
end

local function EaseOutBack(value)
	local c1 = 1.70158
	local c3 = c1 + 1
	value = value - 1
	return 1 + c3 * value * value * value + c1 * value * value
end

local function DrawIcon(icon, isTexture, x, y, w, h, alpha)
	if isTexture then
		surface.SetTexture(icon)
	else
		surface.SetMaterial(icon)
	end
	surface.SetDrawColor(0, 0, 0, math.floor(alpha * 0.65))
	surface.DrawTexturedRect(x + 2, y + 3, w, h)
	surface.SetDrawColor(255, 255, 255, alpha)
	surface.DrawTexturedRect(x, y, w, h)
end

function hg.OpenContainerLootGrid(options)
	options = options or {}
	local ent = options.ent
	if not IsValid(ent) then return end

	if IsValid(hg.ContainerLootMenu) then
		hg.ContainerLootMenu:Remove()
	end

	local items = options.items or {}
	local ids = SortedItemIDs(items)
	local menu = vgui.Create("DPanel")
	hg.ContainerLootMenu = menu
	menu.ent = ent
	menu.entindex = ent:EntIndex()
	menu.Created = CurTime()
	menu.Buttons = {}
	menu.RWasDown = input.IsKeyDown(KEY_R)
	menu:SetPos(0, 0)
	menu:SetSize(ScrW(), ScrH())
	menu:SetPaintBackground(false)
	menu:SetKeyboardInputEnabled(false)
	menu:SetMouseInputEnabled(true)
	menu:MakePopup()
	menu:SetKeyboardInputEnabled(false)

	menu.Paint = nil

	local released = false
	local function Release()
		if released then return end
		released = true
		if options.onClose then options.onClose(ent) end
	end

	function menu:Close()
		if self.Closing then return end
		self.Closing = CurTime()
		self:SetMouseInputEnabled(false)
		for _, button in ipairs(self.Buttons) do
			if IsValid(button) then button:SetMouseInputEnabled(false) end
		end
		Release()
	end

	menu.OnRemove = function(self)
		Release()
		if hg.ContainerLootMenu == self then
			hg.ContainerLootMenu = nil
			gui.EnableScreenClicker(false)
		end
	end

	local function CanContinueLooting(self)
		if not IsValid(self.ent) then return false end
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() or (ply.organism and ply.organism.otrub) then return false end
		if self.ent:GetPos():DistToSqr(ply:GetPos()) > (options.maxDistance or 125) ^ 2 then return false end
		if options.canLoot and options.canLoot(self.ent, ply) == false then return false end
		return true
	end

	local function UpdateAnchors(self)
		if not IsValid(self.ent) then return false end
		local mins, maxs = self.ent:WorldSpaceAABB()
		local center = self.ent:WorldSpaceCenter():ToScreen()
		local top = Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, maxs.z + 4):ToScreen()
		if not center.visible or not top.visible then return false end
		self.OriginX = center.x
		self.OriginY = center.y
		self.AnchorX = top.x
		self.AnchorY = top.y
		return true
	end

	function menu:Think()
		if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then
			self:SetSize(ScrW(), ScrH())
		end

		if not self.Closing then
			if not CanContinueLooting(self) or not UpdateAnchors(self) then
				self:Close()
			else
				local rDown = input.IsKeyDown(KEY_R)
				if rDown and not self.RWasDown then self:Close() end
				self.RWasDown = rDown
			end
		end

		local now = CurTime()
		local closeProgress = self.Closing and math.Clamp((now - self.Closing) / closeDuration, 0, 1) or 0
		if self.Closing and closeProgress >= 1 then
			self:Remove()
			return
		end

		local anchorX = self.AnchorX or ScrW() * 0.5
		local anchorY = self.AnchorY or ScrH() * 0.5
		local originX = self.OriginX or anchorX
		local originY = self.OriginY or anchorY
		for _, button in ipairs(self.Buttons) do
			if not IsValid(button) then continue end

			if button.Taking then
				local takeProgress = math.Clamp((now - button.Taking) / 0.14, 0, 1)
				button:SetAlpha(math.floor(255 * (1 - takeProgress)))
				button:SetPos(button.TakeX, button.TakeY - takeProgress * 10)
				if takeProgress >= 1 then button:Remove() end
				continue
			end

			local openProgress = math.Clamp((now - self.Created - button.OpenDelay) / openDuration, 0, 1)
			local motion = EaseOutBack(openProgress)
			local scale = math.max(0.01, 0.42 + motion * 0.58)
			local targetX = anchorX + button.OffsetX
			local targetY = anchorY + button.OffsetY
			local centerX = Lerp(motion, originX, targetX)
			local centerY = Lerp(motion, originY, targetY)
			if closeProgress > 0 then centerY = centerY - closeProgress * 8 end
			local width = math.floor(button.BaseW * scale)
			local height = math.floor(button.BaseH * scale)
			button:SetSize(width, height)
			button:SetPos(
				math.Clamp(math.floor(centerX - width * 0.5), 4, math.max(4, ScrW() - width - 4)),
				math.Clamp(math.floor(centerY - height * 0.5), 4, math.max(4, ScrH() - height - 4))
			)
			button:SetAlpha(math.floor(255 * openProgress * (1 - closeProgress)))
			button:SetMouseInputEnabled(not self.Closing and openProgress >= 0.7)
		end
	end

	local scale = math.Clamp(ScrH() / 1080, 0.75, 1.15)
	local buttonW = math.floor(76 * scale)
	local buttonH = math.floor(88 * scale)
	local spacingX = math.floor(82 * scale)
	local spacingY = math.floor(82 * scale)
	local perRow = math.max(1, math.min(6, #ids))

	for sequence, itemID in ipairs(ids) do
		local item = items[itemID]
		local class = item and item.class
		if not class then continue end

		local row = math.floor((sequence - 1) / perRow)
		local firstInRow = row * perRow + 1
		local rowCount = math.min(perRow, #ids - firstInRow + 1)
		local column = sequence - firstInRow + 1
		local button = vgui.Create("DButton", menu)
		button:SetText("")
		button:SetSize(buttonW, buttonH)
		button.BaseW = buttonW
		button.BaseH = buttonH
		button.OffsetX = (column - (rowCount + 1) * 0.5) * spacingX
		button.OffsetY = -buttonH * 0.58 - row * spacingY
		button.OpenDelay = (sequence - 1) * 0.045
		button.ItemID = itemID
		button.Item = item
		button.Slot = string.format("%02d", sequence)
		button.Icon, button.IconIsTexture = GetItemIcon(class)
		button:SetTooltip(GetItemName(class))
		button:SetAlpha(0)
		menu.Buttons[#menu.Buttons + 1] = button

		button.OnCursorEntered = function()
			surface.PlaySound("arc9_eft_shared/generic_mag_pouch_out" .. math.random(7) .. ".mp3")
		end

		button.DoClick = function(self)
			if self.Taking or menu.Closing or cooldown > CurTime() then return end
			cooldown = CurTime() + 0.3
			if options.onTake then options.onTake(ent, self.ItemID, self.Item) end
			surface.PlaySound("arc9_eft_shared/generic_mag_pouch_in" .. math.random(7) .. ".mp3")
			self.Taking = CurTime()
			self.TakeX, self.TakeY = self:GetPos()
			self:SetMouseInputEnabled(false)
		end

		button.Paint = function(self, w, h)
			local hovered = self:IsHovered() and not self.Taking
			local iconHeight = h - math.floor(22 * scale)
			if hovered then
				draw.RoundedBox(math.floor(8 * scale), 2, 2, w - 4, iconHeight, Color(255, 255, 255, 22))
				surface.SetDrawColor(255, 255, 255, 105)
				surface.DrawOutlinedRect(2, 2, w - 4, iconHeight, 1)
			end

			if self.Icon then
				local maxW = w - math.floor(12 * scale)
				local maxH = iconHeight - math.floor(8 * scale)
				local drawW, drawH = maxW, maxH
				if not self.IconIsTexture then
					local materialW = math.max(self.Icon:Width(), 1)
					local materialH = math.max(self.Icon:Height(), 1)
					local ratio = math.min(maxW / materialW, maxH / materialH)
					drawW = materialW * ratio
					drawH = materialH * ratio
				end
				DrawIcon(self.Icon, self.IconIsTexture, (w - drawW) * 0.5, (iconHeight - drawH) * 0.5, drawW, drawH, 255)
			else
				draw.RoundedBox(math.floor(6 * scale), w * 0.2, iconHeight * 0.12, w * 0.6, iconHeight * 0.7, Color(12, 12, 12, 185))
				draw.SimpleText("?", "ZCity_Tiny", w * 0.5, iconHeight * 0.47, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			draw.SimpleText(self.Slot, "ZCity_SuperTiny", w * 0.5 + 1, h - 1, Color(0, 0, 0, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(self.Slot, "ZCity_SuperTiny", w * 0.5, h - 2, hovered and color_white or Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
	end

	UpdateAnchors(menu)
	if #menu.Buttons == 0 then menu:Close() end
	return menu
end
