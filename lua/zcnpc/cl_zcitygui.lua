--[[
	Z-City's own menus, put back when a late load or a missing font takes them.

	The Esc menu, the loot window, the attachments sheet and the ammo drop all
	draw with ZCity_Small / HomigradFontSmall. Those fonts are created in
	initpost/cl_derma_skin.lua and cl_hud.lua, which can miss a client that
	joined while the addon was still mounting. A missing font is not a blank
	label - it is an error every frame, which is the "progress bar spam" on
	med bags and morphine, and the error on almost every weapon pickup that
	draws a markup hint.

	Nothing here replaces those menus. It creates the fonts they already ask
	for, and it keeps hg.chat alive the same way cl_zchat.lua does, so Escape
	has something to close.
]]

if not CLIENT then return end

-- Empty tables so the loot / attachments / ammo windows do not index nil
-- while Z-City is still mounting its own lists.
hg = hg or {}
hg.attachmentsIcons = hg.attachmentsIcons or {}
hg.armorIcons = hg.armorIcons or {}
hg.attachmentslaunguage = hg.attachmentslaunguage or {}
hg.ammotypeshuy = hg.ammotypeshuy or {}
-- ZMainMenu Init does hg.PluvTown.Active with no nil check.
hg.PluvTown = hg.PluvTown or {}

local function Face()
	if ConVarExists("hg_font") then
		local cvar = GetConVar("hg_font")
		if cvar ~= nil then
			local name = cvar:GetString()
			if name ~= "" then return name end
		end
	end

	return "Bahnschrift"
end

-- Only fill a name that is not already a real font. Recreating Z-City's
-- own set (HUDPaint used to do it every 8s, and HomigradFontBig was the
-- wrong size) is the "Z-City font not found / ESC menu broken" report.
local made = {}

local function Missing(name)
	if made[name] then return false end
	-- Z-City's CreateFont wrap caches every name it has already made.
	if isfunction(ZB_GetFontTable) and ZB_GetFontTable(name) then return false end

	return true
end

local function Make(name, size, weight, extra)
	if not Missing(name) then return end

	local data = {
		font = Face(),
		size = size,
		weight = weight or 200,
	}

	if istable(extra) then
		for k, v in pairs(extra) do
			data[k] = v
		end
	end

	surface.CreateFont(name, data)
	made[name] = true
end

local function CreateFonts()
	-- Z-City already registered its skin: its CreateFont calls have run.
	if istable(hg) and istable(hg.VGUI) and hg.VGUI.MainSkin then
		return true
	end

	local ok = pcall(function()
		Make("ZCity_VerySuperTiny", ScreenScale(5), 200)
		Make("ZCity_SuperTiny", ScreenScale(6), 200)
		Make("ZCity_Fixed_SuperTiny", 18, 200)
		Make("ZCity_Tiny", ScreenScale(8), 200)
		Make("ZCity_Fixed_Tiny", 25, 200)
		Make("ZCity_Small", ScreenScale(15), 200)
		Make("ZCity_Medium", ScreenScale(25), 200)
		Make("ZCity_Fixed_Medium", 55, 200)
		Make("ZCity_Big", ScreenScale(35), 200)
		Make("ZCity_Fixed_Big", 300, 200)
		Make("ZCity_Fixed_Medium_Light", 25, 200)
		Make("ZCity_Fixed_Medium_Light_Blur", 25, 200, { blursize = 4 })
		Make("HomigradFontSmall", 17, 1100, { outline = false })
		Make("HomigradFontVSmall", 12, 400, { outline = false })
		Make("HomigradFont", ScreenScale(10), 1100, { outline = false })
		Make("HomigradFontBig", ScreenScale(12), 1100, { outline = false, shadow = true })
		Make("ZC_MM_Title", ScreenScale(40), 800, { antialias = true })

		if Missing("ZCity_Fixed_Icons_Small") then
			surface.CreateFont("ZCity_Fixed_Icons_Small", {
				font = "fontello",
				size = 22,
				weight = 500,
			})
			made["ZCity_Fixed_Icons_Small"] = true
		end
	end)

	return ok
end

-- After initpost: Z-City's skin has registered. Creating these names first
-- is what used to stamp the wrong sizes into their CreateFont cache.
hook.Add("InitPostEntity", "zcnpc_zcitygui", function()
	timer.Simple(2, CreateFonts)
end)
hook.Add("OnScreenSizeChanged", "zcnpc_zcitygui", function()
	made = {}
	CreateFonts()
end)

if ConVarExists("hg_font") then
	cvars.AddChangeCallback("hg_font", function()
		made = {}
		CreateFonts()
	end, "zcnpc_zcitygui")
end

-- The loot window is vgui.Create("ZFrame") (sh_inventory.lua:178). ZFrame is
-- registered from initpost/menu-n-derma/derma/cl_frame.lua, the same late
-- folder the fonts live in. A client that missed that file gets
-- "failed to create the VGUI component (ZFrame)" and then a nil plyMenu
-- on the next line - which is exactly opening an NPC body's pockets.
-- Same panel Z-City already wrote; we only put it back when it is gone.
local function EnsureBlur()
	if isfunction(hg.DrawBlur) then return end

	local blur = Material("pp/blurscreen")

	function hg.DrawBlur(panel, amount)
		if not IsValid(panel) then return end

		surface.SetDrawColor(0, 0, 0, amount and (amount * 20) or 120)
		surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())

		if blur:IsError() then return end

		surface.SetMaterial(blur)
		surface.SetDrawColor(0, 0, 0, 125)

		local x, y = panel:LocalToScreen(0, 0)

		blur:SetFloat("$blur", amount or 2)
		blur:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
	end
end

local function EnsureZFrame()
	if vgui.GetControlTable("ZFrame") then return true end

	EnsureBlur()

	local PANEL = {}
	local color_blacky = Color(25, 25, 30, 220)
	local color_reddy = Color(155, 0, 0, 240)

	function PANEL:Init()
		self.Itensens = {}
		self:SetAlpha(0)
		self:SetTitle("")
		self.DrawBorder = true
		self.ColorBG = Color(color_blacky:Unpack())
		self.ColorBR = Color(color_reddy:Unpack())
		self.BlurStrengh = 2

		timer.Simple(0, function()
			if IsValid(self) and self.First then self:First() end
		end)
	end

	function PANEL:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, self.ColorBG)
		if isfunction(hg.DrawBlur) then hg.DrawBlur(self, self.BlurStrengh) end

		if self.DrawBorder then
			surface.SetDrawColor(self.ColorBR)
			surface.DrawOutlinedRect(0, 0, w, h, 1.5)
		end
	end

	function PANEL:SetBorder(drawBorder)
		self.DrawBorder = drawBorder
	end

	function PANEL:SetColorBG(color)
		self.ColorBG = color
	end

	function PANEL:SetColorBR(color)
		self.ColorBR = color
	end

	function PANEL:SetBlurStrengh(value)
		self.BlurStrengh = value
	end

	function PANEL:First()
		self:SetY(self:GetY() + self:GetTall())
		self:MoveTo(self:GetX(), self:GetY() - self:GetTall(), 0.4, 0, 0.2, function() end)
		self:AlphaTo(255, 0.2, 0.1, nil)

		if self.PostInit then self:PostInit() end
	end

	function PANEL:Close()
		if self.Closing then return end

		self.Closing = true
		self:MoveTo(self:GetX(), ScrH() / 2 + self:GetTall(), 5, 0, 0.3, function() end)
		self:AlphaTo(0, 0.2, 0, function()
			if self.OnClose then self:OnClose() end
			self:Remove()
		end)
		self:SetKeyboardInputEnabled(false)
		self:SetMouseInputEnabled(false)
	end

	vgui.Register("ZFrame", PANEL, "DFrame")

	return vgui.GetControlTable("ZFrame") ~= nil
end

-- After initpost, and only if their Register never ran. Doing this on the
-- same InitPostEntity as their IncludeDir can register a stand-in ZFrame
-- that ZMainMenu then inherits.
hook.Add("InitPostEntity", "zcnpc_zcitygui_zframe", function()
	timer.Simple(3, EnsureZFrame)
end)

if ZCNPC.__origVguiCreate then
	vgui.Create = ZCNPC.__origVguiCreate
	ZCNPC.__origVguiCreate = nil
end

timer.Remove("zcnpc_zcitygui_chat")

-- Medicine Think / HUD: KeyDown on a non-player owner, or GetHolding before
-- the NetworkVar exists, is the morphine / blood-bag progress bar spam.
local MEDICINE = {
	"weapon_bandage_sh",
	"weapon_bloodbag",
	"weapon_morphine",
	"weapon_morphine_injector",
	"weapon_adrenaline",
	"weapon_mannitol",
	"weapon_painkillers",
	"weapon_medkit_sh",
	"weapon_hg_medicine_base",
	"weapon_medbase",
}

local function WrapThink(tbl)
	if not istable(tbl) or tbl.zcnpc_gui_think then return end

	local old = tbl.Think
	if not isfunction(old) then return end

	tbl.zcnpc_gui_think = true
	tbl.Think = function(self, ...)
		local owner = self.GetOwner and self:GetOwner()
		if IsValid(owner) and not owner:IsPlayer() then return end

		local ok, err = pcall(old, self, ...)
		if not ok then return end

		return err
	end
end

local function PatchMedicine()
	if not isfunction(weapons.GetStored) then return end

	for i = 1, #MEDICINE do
		WrapThink(weapons.GetStored(MEDICINE[i]))
	end

	if not isfunction(weapons.GetList) then return end

	for _, wep in ipairs(weapons.GetList()) do
		if istable(wep) and (wep.Base == "weapon_bandage_sh"
			or wep.Base == "weapon_hg_medicine_base"
			or wep.Base == "weapon_medbase") then
			WrapThink(wep)
		end
	end
end

PatchMedicine()
hook.Add("InitPostEntity", "zcnpc_zcitygui_med", function()
	timer.Simple(0, PatchMedicine)
end)
timer.Create("zcnpc_zcitygui_med", 2, 6, PatchMedicine)

-- Weapon pickup HUD markup: a missing font or a nil attachment table throws
-- once per pickup. Swallow that draw rather than dump the console.
-- Fonts are not recreated here: doing that every few seconds overwrote
-- Z-City's own set (wrong HomigradFontBig size, missing shadow) and is
-- what broke the ESC menu and sandbox UI after the last update.
hook.Remove("HUDPaint", "zcnpc_zcitygui_fonts")
