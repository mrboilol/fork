local PANEL = {}

BlurBackground = hg.DrawBlur

local pickmanA = Material("vgui/pickman.png", "noclamp smooth")
local pickmanB = Material("vgui/pickman", "noclamp smooth")
local pickmanTextureID = surface.GetTextureID("vgui/pickman")

function PANEL:Init()
    self.OpenTime = CurTime()
    self.FadeTime = 0.35
    self.ShakeSeed = math.Rand(0, 512)
end

local function CreateRTVFonts()
    surface.CreateFont("ZCity_RTV_Title", {
        font = "Verily Serif Mono",
        size = RTVUnit(32),
        weight = 800,
        antialias = true
    })

    surface.CreateFont("ZCity_RTV_Tiny", {
        font = "Verily Serif Mono",
        size = RTVUnit(8),
        weight = 200
    })
end

hook.Add("OnScreenSizeChanged", "ZCity_RTV_Fonts", CreateRTVFonts)
CreateRTVFonts()

function PANEL:Init()
    self:SetTitle("")
    self:SetDraggable(false)
    self:ShowCloseButton(false)
    self:SetBorder(false)
    self:SetColorBG(bg)
    self:SetColorBR(border)
    self:SetBlurStrengh(5)
end

function PANEL:Paint( w, h )
    draw.RoundedBox(0, 0, 0, w, h, bg)
    hg.DrawBlur(self, 5)

    surface.SetDrawColor(18, 18, 18, 65)
    surface.SetTexture(gradient_r)
    surface.DrawTexturedRect(0, 0, w, h)

    surface.SetDrawColor(0, 0, 0, 24 * t)
    surface.DrawRect(0, 0, w, h)

    surface.SetDrawColor(70, 70, 70, 160 * t)
    surface.DrawRect(0, 0, w, 2)
    surface.DrawRect(0, h - 2, w, 2)
    surface.DrawRect(0, 0, 2, h)
    surface.DrawRect(w - 2, 0, 2, h)

    local title = "ROCK THE VOTE"
    surface.SetFont("ZC_MM_Title")
    surface.SetTextColor(220, 220, 220, 255 * t)
    local tw, th = surface.GetTextSize(title)
    surface.SetTextPos((w - tw) * 0.5, h * 0.055)
    surface.DrawText(title)

    local subtitle = "SELECT THE NEXT MAP"
    surface.SetFont("ZCity_Veteran")
    surface.SetTextColor(140, 140, 140, 210 * t)
    local sw, _ = surface.GetTextSize(subtitle)
    surface.SetTextPos((w - sw) * 0.5, h * 0.055 + th + 4)
    surface.DrawText(subtitle)
end

vgui.Register("ZB_RTVMenu", PANEL, "ZFrame")
