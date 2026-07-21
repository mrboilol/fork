if SERVER then return end

hg = hg or {}
hg.OpenedContainer = hg.OpenedContainer or nil
local blurMat = Material("pp/blurscreen")
local Dynamic = 0

local cooldown = 0

local function nameThings(i)
    local weps = weapons.Get(i)
	local entss = scripted_ents.Get(i)
	if weps then return weps.PrintName end
	if entss then return entss.PrintName end
    return tostring(i)
end

local function getIconThing(i)
    if weapons.Get(i) then
        local GunTable = weapons.Get(i)
        local Icon = (GunTable.WepSelectIcon2 ~= nil and GunTable.WepSelectIcon2) or GunTable.WepSelectIcon
        local Overide = GunTable.WepSelectIcon2 == nil and true or false
        local HaveIcon = true
        return Icon, HaveIcon, Overide, false
    end

    local entss = scripted_ents.Get(i)
    if entss then
        local GunTable = scripted_ents.Get(i)
        local Icon = (GunTable.IconOverride ~= nil and GunTable.IconOverride) or GunTable.IconOverride
        local Overide = GunTable.IconOverride == nil and true or false
        if not GunTable.IconOverride then return Icon, false, false, false end
        local HaveIcon = true
        return Icon, HaveIcon, Overide, true
    end
end

local colRed = Color(255, 0, 0, 255)
local function OpenContainer(ent)
    local name = "Container"
	local sizeX, sizeY = ScrW() / 3, ScrH() / 2.5
	zbSandboxContainerMenu = vgui.Create("DFrame")
	zbSandboxContainerMenu.ent = ent
	zbSandboxContainerMenu.entindex = ent:EntIndex()

	zbSandboxContainerMenu:SetTitle("")
	zbSandboxContainerMenu:SetSize(sizeX, sizeY)
	local cx, cy = (ScrW() - sizeX) / 2, (ScrH() - sizeY) / 2
	zbSandboxContainerMenu:SetPos(cx, cy + 100)
	zbSandboxContainerMenu:MakePopup()
	zbSandboxContainerMenu:SetKeyBoardInputEnabled(false)
	zbSandboxContainerMenu:ShowCloseButton(true)
	zbSandboxContainerMenu:SetVisible(true)
	zbSandboxContainerMenu:SetMouseInputEnabled(true)
	zbSandboxContainerMenu.Created = CurTime()
    zbSandboxContainerMenu:SetAlpha(0)
    zbSandboxContainerMenu.OnClose = function() zbSandboxContainerMenu = nil end

    zbSandboxContainerMenu:MoveTo(cx, cy, 0.5, 0, 0.3)
    zbSandboxContainerMenu:AlphaTo(255, 0.2, 0.1, nil)

    function zbSandboxContainerMenu:Close()
		self.Closing = true

        self:MoveTo(0, 500, 0.5, 0, 0.3, function()
            self:Remove()
        end)
        self:AlphaTo(0, 0.1, 0, nil)
        self:SetKeyboardInputEnabled(false)
        self:SetMouseInputEnabled(false)
    end

	zbSandboxContainerMenu.Paint = function(self, w, h)
		draw.RoundedBox(0, 2.5, 2.5, w - 5, h - 5, Color(0, 0, 0, 140))
		surface.SetDrawColor(255, 0, 0, 128)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
		surface.SetDrawColor(92, 0, 0, 240)
		surface.DrawRect(w / 2 - 100, 10, 200, 20)
		draw.DrawText(name, "HomigradFontSmall", w / 2, 10, color_white, TEXT_ALIGN_CENTER)
		draw.DrawText("R - Close", "HomigradFontSmall", w * 0.012, h - h * 0.055, Color(255, 255, 255, 15), TEXT_ALIGN_LEFT)
	end

	function zbSandboxContainerMenu:Think()
		local entity = self.ent
		if not IsValid(entity) then self:Close() return end
		if LocalPlayer().organism.otrub or not LocalPlayer():Alive() then self:Remove() return end
		if (entity:GetPos() - LocalPlayer():GetPos()):LengthSqr() > 125 ^ 2 then self:Remove() return end
		if input.IsKeyDown(KEY_R) then self:Close() end
	end

    local DScrollPanel = vgui.Create("DScrollPanel", zbSandboxContainerMenu)
	DScrollPanel:SetPos(sizeX / 30, sizeY / 12)
	DScrollPanel:SetSize(sizeX - sizeX / 16, sizeY - sizeY / 7)
	DScrollPanel:Dock(FILL)
	DScrollPanel:DockMargin(2, 8, 2, 20)
	function DScrollPanel:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 100))
		surface.SetDrawColor(255, 0, 0, 128)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
	end

	local sbar = DScrollPanel:GetVBar()
	sbar:SetHideButtons(true)
	function sbar:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 100))
		surface.SetDrawColor(255, 0, 0, 128)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
	end
	function sbar.btnUp:Paint(w, h) end
	function sbar.btnDown:Paint(w, h) end
	function sbar.btnGrip:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(148, 0, 0, 100))
		surface.SetDrawColor(255, 0, 0, 128)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
	end

	local grid = vgui.Create("DGrid", DScrollPanel)
	grid:Dock(FILL)
	grid:DockMargin(12, 10, 0, 0)
	grid:SetCols(5)
	grid:SetColWide(sizeX / 5 - sizeX / 16 / 9)
	grid:SetRowHeight(sizeY / 6.5 + sizeY / 32)

    for k, item in pairs(ent.Loot) do
        local button = vgui.Create("DButton", zbSandboxContainerMenu)
		button:SetText("")
		button:DockMargin(5, 0, 2, 0)
		button:SetSize(sizeX / 5.8, sizeY / 5.8)
		button.Think = function(self) end

		button.DoClick = function()
			if cooldown > CurTime() then return end
			cooldown = CurTime() + 0.5
			surface.PlaySound("arc9_eft_shared/generic_mag_pouch_in" .. math.random(7) .. ".ogg")
			grid.SoundKD = CurTime() + 0.2
            net.Start("hg_sandbox_container_take")
                net.WriteEntity(ent)
                net.WriteUInt(k, 10)
            net.SendToServer()
			button:Remove()
		end

		local name = nameThings(item.class)
		button.col1 = 100
		button.Paint = function(self, w, h)
			button.col1 = Lerp(0.1, button.col1, button:IsHovered() and 255 or 100)
			if button:IsHovered() then
				button.SoundKD = button.SoundKD or 0
				if (grid.SoundKD or 0) < CurTime() and button.SoundKD < CurTime() then
					surface.PlaySound("arc9_eft_shared/generic_mag_pouch_out" .. math.random(7) .. ".ogg")
				end
				button.SoundKD = CurTime() + 0.1
			end
			surface.SetDrawColor(button.col1, 25, 25, 150)
			surface.DrawRect(0, 0, w, h)
			local Icon, HaveIcon, Overide, Quad = getIconThing(item.class)
			if Icon then button.Icon = button.Icon or (isstring(Icon) and Material(Icon)) or Icon end
			if HaveIcon then
				surface.SetMaterial(button.Icon)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(Quad and w / 5 + 5 or -5, 5, Quad and (w / 2 + 2.5) or (w + 10), Quad and h / 1.3 or h - 10)
			end
			surface.SetDrawColor(colRed)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			local Text = language.GetPhrase(name)
			local SubText = utf8.sub(Text, 14)
			Text = utf8.sub(Text, 1, 13) .. "\n" .. utf8.sub(Text, 14)
			draw.DrawText(Text, "DermaDefault", w / 2, (HaveIcon and h / ((#SubText > 0 and 1.65) or 1.3)) or h / 3, color_white, TEXT_ALIGN_CENTER)
		end
		grid:AddItem(button)
    end

    zbSandboxContainerMenu:SlideDown(0.5)
end

net.Receive("hg_sandbox_container_open", function()
    local ent = net.ReadEntity()
    hg.OpenedContainer = ent
    ent.Loot = net.ReadTable()
    OpenContainer(ent)
end)

zbSandboxContainerMenu = zbSandboxContainerMenu or nil
if IsValid(zbSandboxContainerMenu) then
    zbSandboxContainerMenu:Remove()
    zbSandboxContainerMenu = nil
end
