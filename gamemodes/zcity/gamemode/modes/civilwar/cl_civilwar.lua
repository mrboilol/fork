MODE.name = "civilwar"

local MODE = MODE

local CivilWarSound = nil

net.Receive("civilwar_start", function()
    if CivilWarSound then
        CivilWarSound:Stop()
        CivilWarSound = nil
    end
 
    sound.PlayFile("sound/civilwar_start.wav", "noplay", function(station)
        if IsValid(station) then
            station:SetVolume(1)
            station:Play()
            CivilWarSound = station
        end
    end)
 
    zb.RemoveFade()
end)

local teams = {
    [0] = {
        objective = "Defeat the Confederate forces and preserve the Union.",
        name = "Union Soldier",
        color1 = Color(127, 120, 255),
        color2 = Color(25, 110, 25),
    },
    [1] = {
        objective = "Defeat the Union forces and secure Southern independence.",
        name = "Confederate Soldier",
        color1 = Color(139, 0, 0),
        color2 = Color(184, 31, 31),
    },
}

function MODE:RenderScreenspaceEffects()
    if zb.ROUND_START + 7.5 < CurTime() then return end
    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(), 0, 1)
    surface.SetDrawColor(0, 0, 0, 255 * fade)
    surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

function MODE:HUDPaint()
    if zb.ROUND_START + 8.5 < CurTime() then return end

    local lply = LocalPlayer()
    if not lply:Alive() then return end
    zb.RemoveFade()

    local sw, sh = ScrW(), ScrH()
    local fade = math.Clamp(zb.ROUND_START + 8 - CurTime(), 0, 1)
    local team_id = lply:Team()
    
    if not teams[team_id] then return end
    
    draw.SimpleText("ZBattle | American Civil War", "ZB_HomicideMediumLarge", 
        sw * 0.5, sh * 0.1, Color(139, 69, 19, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    local role_color = teams[team_id].color1
    role_color.a = 255 * fade
    
    draw.SimpleText("You are " .. teams[team_id].name, "ZB_HomicideMediumLarge", 
        sw * 0.5, sh * 0.5, role_color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    local objective_color = teams[team_id].color2
    objective_color.a = 255 * fade
    
    draw.SimpleText(teams[team_id].objective, "ZB_HomicideMedium", 
        sw * 0.5, sh * 0.9, objective_color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local CreateEndMenu

net.Receive("civilwar_roundend", function()
    surface.PlaySound("ambient/alarms/warningbell1.wav")
    CreateEndMenu()
end)

local colGray = Color(85, 85, 85, 255)
local colRed = Color(130, 10, 10)
local colRedUp = Color(160, 30, 30)
local colBlue = Color(10, 10, 160)
local colBlueUp = Color(40, 40, 160)
local col = Color(255, 255, 255, 255)
local colSpect1 = Color(75, 75, 75, 255)

BlurBackground = BlurBackground or hg.DrawBlur

if IsValid(hmcdEndMenu) then
    hmcdEndMenu:Remove()
    hmcdEndMenu = nil
end

CreateEndMenu = function()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end

    hmcdEndMenu = vgui.Create("ZFrame")

    local sizeX, sizeY = ScrW() / 2.5, ScrH() / 1.2
    local posX, posY = ScrW() / 1.3 - sizeX / 2, ScrH() / 2 - sizeY / 2

    hmcdEndMenu:SetPos(posX, posY)
    hmcdEndMenu:SetSize(sizeX, sizeY)
    hmcdEndMenu:MakePopup()
    hmcdEndMenu:SetKeyboardInputEnabled(false)
    hmcdEndMenu:ShowCloseButton(false)

    local closebutton = vgui.Create("DButton", hmcdEndMenu)
    closebutton:SetPos(5, 5)
    closebutton:SetSize(ScrW() / 20, ScrH() / 30)
    closebutton:SetText("")
    
    closebutton.DoClick = function()
        if IsValid(hmcdEndMenu) then
            hmcdEndMenu:Close()
            hmcdEndMenu = nil
        end
    end

    closebutton.Paint = function(self, w, h)
        surface.SetDrawColor(122, 122, 122, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
        surface.SetFont("ZB_InterfaceMedium")
        surface.SetTextColor(col.r, col.g, col.b, col.a)
        local lengthX, lengthY = surface.GetTextSize("Close")
        surface.SetTextPos(lengthX - lengthX / 1.1, 4)
        surface.DrawText("Close")
    end

    hmcdEndMenu.Paint = function(self, w, h)
        BlurBackground(self)
        surface.SetFont("ZB_InterfaceMediumLarge")
        surface.SetTextColor(col.r, col.g, col.b, col.a)
        local lengthX, lengthY = surface.GetTextSize("Players:")
        surface.SetTextPos(w / 2 - lengthX / 2, 20)
        surface.DrawText("Players:")
        surface.SetDrawColor(139, 69, 19, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
    DScrollPanel:SetPos(10, 80)
    DScrollPanel:SetSize(sizeX - 20, sizeY - 90)
    
    function DScrollPanel:Paint(w, h)
        BlurBackground(self)
        surface.SetDrawColor(139, 69, 19, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    for i, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        local but = vgui.Create("DButton", DScrollPanel)
        but:SetSize(100, 50)
        but:Dock(TOP)
        but:DockMargin(8, 6, 8, -1)
        but:SetText("")
        
        but.Paint = function(self, w, h)
            local teamColor = (ply:Team() == 0 and colBlue) or (ply:Team() == 1 and colRed) or colGray
            local teamColorUp = (ply:Team() == 0 and colBlueUp) or (ply:Team() == 1 and colRedUp) or colSpect1
            
            surface.SetDrawColor(teamColor.r, teamColor.g, teamColor.b, teamColor.a)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(teamColorUp.r, teamColorUp.g, teamColorUp.b, teamColorUp.a)
            surface.DrawRect(0, h / 2, w, h / 2)
            
            local playerColor = ply:GetPlayerColor():ToColor()
            surface.SetFont("ZB_InterfaceMediumLarge")
            surface.SetTextColor(0, 0, 0, 255)
            surface.SetTextPos(w / 2 + 1, h / 2 - 12 + 1)
            surface.DrawText(ply:GetPlayerName() or "He quited...")
            surface.SetTextColor(playerColor.r, playerColor.g, playerColor.b, playerColor.a)
            surface.SetTextPos(w / 2, h / 2 - 12)
            surface.DrawText(ply:GetPlayerName() or "He quited...")
            
            surface.SetFont("ZB_InterfaceMediumLarge")
            surface.SetTextColor(255, 255, 255, 255)
            surface.SetTextPos(15, h / 2 - 12)
            surface.DrawText((ply:Name() .. (not ply:Alive() and " - died" or "")) or "He quited...")
            
            surface.SetFont("ZB_InterfaceMediumLarge")
            surface.SetTextColor(255, 255, 255, 255)
            surface.SetTextPos(w - 45, h / 2 - 12)
            surface.DrawText(ply:Frags() or "0")
        end

        function but:DoClick()
            if ply:IsBot() then
                chat.AddText(Color(255, 0, 0), "no, you can't")
                return
            end
            gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
        end

        DScrollPanel:AddItem(but)
    end
    
    return true
end

function MODE:RoundStart()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end
