if SERVER then return end

hg = hg or {}

local containerMenu
local cooldown = 0
local red = Color(255, 0, 0, 255)

local function ItemName(class)
	local weapon = weapons.Get(class)
	if weapon then return weapon.PrintName end

	local entity = scripted_ents.Get(class)
	if entity then return entity.PrintName end

	return class
end

local function ItemIcon(class)
	local weapon = weapons.Get(class)
	if weapon then return weapon.WepSelectIcon2 or weapon.WepSelectIcon end

	local entity = scripted_ents.Get(class)
	if entity then return entity.IconOverride end
end

local function OpenSandboxContainer(ent, loot)
	if IsValid(containerMenu) then containerMenu:Remove() end
	if not IsValid(ent) then return end

	local sizeX = math.Clamp(ScrW() / 3, 420, 700)
	local sizeY = math.Clamp(ScrH() / 2.5, 300, 560)
	containerMenu = vgui.Create("DFrame")
	containerMenu.ent = ent
	containerMenu:SetTitle("")
	containerMenu:SetSize(sizeX, sizeY)
	containerMenu:Center()
	containerMenu:MakePopup()
	containerMenu:SetKeyboardInputEnabled(false)
	containerMenu:ShowCloseButton(true)

	containerMenu.Paint = function(self, w, h)
		draw.RoundedBox(0, 2, 2, w - 4, h - 4, Color(0, 0, 0, 215))
		surface.SetDrawColor(red)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText("Container", "HomigradFontSmall", w / 2, 16, color_white, TEXT_ALIGN_CENTER)
		draw.SimpleText("R - Close | LMB - Take", "HomigradFontSmall", 12, h - 24, Color(255, 255, 255, 70), TEXT_ALIGN_LEFT)
	end

	function containerMenu:Think()
		if not IsValid(self.ent) or not LocalPlayer():Alive() then self:Close() return end
		if self.ent:GetPos():DistToSqr(LocalPlayer():GetPos()) > 125 ^ 2 then self:Close() return end
		if input.IsKeyDown(KEY_R) then self:Close() end
	end

	local scroll = vgui.Create("DScrollPanel", containerMenu)
	scroll:Dock(FILL)
	scroll:DockMargin(12, 42, 12, 34)
	scroll.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(red)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local grid = vgui.Create("DGrid", scroll)
	grid:Dock(TOP)
	grid:DockMargin(10, 10, 10, 10)
	grid:SetCols(5)
	grid:SetColWide((sizeX - 72) / 5)
	grid:SetRowHeight((sizeX - 72) / 5)

	for itemID, item in pairs(loot) do
		local button = vgui.Create("DButton", grid)
		button:SetText("")
		button:SetSize((sizeX - 86) / 5, (sizeX - 86) / 5)
		button:DockMargin(3, 3, 3, 3)
		local icon = ItemIcon(item.class)
		local material = icon and (isstring(icon) and Material(icon) or icon)
		local name = ItemName(item.class)

		button.DoClick = function()
			if cooldown > CurTime() then return end
			cooldown = CurTime() + 0.2
			net.Start("hg_sandbox_container_take")
				net.WriteEntity(ent)
				net.WriteUInt(itemID, 10)
			net.SendToServer()
		end

		button.Paint = function(self, w, h)
			local shade = self:IsHovered() and 220 or 115
			surface.SetDrawColor(shade, 25, 25, 170)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(red)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			if material then
				surface.SetMaterial(material)
				surface.SetDrawColor(color_white)
				surface.DrawTexturedRect(5, 5, w - 10, h - 30)
			end
			draw.SimpleText(language.GetPhrase(name), "DermaDefault", w / 2, h - 17, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		grid:AddItem(button)
	end
end

net.Receive("hg_sandbox_container_open", function()
	local ent = net.ReadEntity()
	local loot = net.ReadTable()
	OpenSandboxContainer(ent, loot)
end)
