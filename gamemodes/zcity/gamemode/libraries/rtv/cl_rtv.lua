local maps = {}
local time = 0
local votes = {}
local blacklistedMaps = {}
local winmap = ""
local rtvStarted = false
local rtvEnded = false
local activeRTVMenu

local VoteCD = 0
local maxChoices = 8
local placeholderIconA = Material("vgui/wii_moves")
local placeholderIconB = Material("vgui/wii_moves.png")

local function GetPlaceholderIcon()
    if placeholderIconA and not placeholderIconA:IsError() then
        return placeholderIconA
    end
    if placeholderIconB and not placeholderIconB:IsError() then
        return placeholderIconB
    end
    return Material("icon64/tool.png")
end

local function FormatMapName(mapName)
    if mapName == "random" then
        return "Random Map"
    end

    local parts = string.Explode("_", tostring(mapName))
    if #parts > 1 then
        table.remove(parts, 1)
    end

    if #parts == 0 then
        parts = {tostring(mapName)}
    end

    for i = 1, #parts do
        local part = parts[i]
        if part and part ~= "" then
            parts[i] = string.upper(string.Left(part, 1)) .. string.sub(part, 2)
        end
    end

    return table.concat(parts, " ")
end

function zb.IsRTVActive()
    return rtvStarted
end

local function RTVUnit(num)
    return math.floor(num * math.min(ScrW(), ScrH()) / 1000)
end

function zb.RTVMenu()
    system.FlashWindow()

    if IsValid(activeRTVMenu) then
        activeRTVMenu:Remove()
    end

    local RTVMenu = vgui.Create("ZB_RTVMenu")
    RTVMenu:SetSize(math.min(RTVUnit(760), ScrW() - RTVUnit(40)), math.min(RTVUnit(760), ScrH() - RTVUnit(40)))
    RTVMenu:Center()
    RTVMenu:SetTitle("")
    RTVMenu:SetBackgroundBlur(false)
    RTVMenu:ShowCloseButton(false)
    RTVMenu:SetDraggable(false)
    RTVMenu:MakePopup()
    RTVMenu:SetKeyboardInputEnabled(false)

    local MAPSPanel = vgui.Create("DPanel", RTVMenu)
    MAPSPanel:Dock(FILL)
    MAPSPanel:DockMargin(RTVUnit(12), RTVUnit(48), RTVUnit(12), RTVUnit(18))
    function MAPSPanel.Paint() end

    local selectedButton
    for k, v in ipairs(maps) do
        local MapButton = vgui.Create("ZB_RTVButton", MAPSPanel)
        MapButton:Dock(TOP)
        MapButton:DockMargin(0, 0, 0, RTVUnit(4))
        MapButton:SetSize(0, RTVUnit(34))
        
        if v == "random" then
            MapButton.DisplayName = "Random Map"
            MapButton.Map = "random"
            MapButton.MapIcon = Material("icon64/random.png")
            if MapButton.MapIcon:IsError() then
                MapButton.MapIcon = nil
            end
        else
            MapButton.DisplayName = FormatMapName(v)
            MapButton.Map = v
            MapButton.MapIcon = Material("maps/thumb/" .. MapButton.Map .. ".png")
            if MapButton.MapIcon:IsError() then
                MapButton.MapIcon = nil
            end
        end

        if not didSetPreview then
            SetPreview(MapButton.Map, MapButton.DisplayName, MapButton.MapIcon)
            didSetPreview = true
        end

        MapButton.Blacklisted = (MapButton.Map ~= "random" and blacklistedMaps[MapButton.Map]) or false
        MapButton:Disabled(MapButton.Blacklisted)

        MapButton.OnPreviewHover = function(self)
            SetPreview(self.Map, self.DisplayName, self.MapIcon)
        end

        function MapButton:Think()
            self.Votes = votes[self.Map] or 0
            if self.Map == winmap then 
                self.Win = true 
            else 
                self.Win = false 
            end
        end

        function MapButton:DoClick()
            if VoteCD > CurTime() then return end
            if self.Blacklisted then return end
            SetPreview(self.Map, self.DisplayName, self.MapIcon)
            net.Start("ZB_RockTheVote_vote")
                net.WriteString(self.Map)
            net.SendToServer()
            if IsValid(selectedButton) then
                selectedButton:SetSelected(false)
            end
            selectedButton = self
            self:SetSelected(true)
            VoteCD = CurTime() + 1
        end
    end

    local button = vgui.Create("DButton", RTVMenu)
    button:SetPos(RTVMenu:GetWide() - RTVUnit(48), RTVUnit(12))
    button:SetSize(RTVUnit(36), RTVUnit(14))
    button:SetText("")

    function button:Paint(w, h)
        local hovered = self:IsHovered()

        surface.SetDrawColor(hovered and 95 or 30, hovered and 95 or 30, hovered and 95 or 30, hovered and 190 or 110)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(155, 155, 155, 210)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local x, y = w / 2, h / 2
        local txt = "Exit"
        surface.SetFont("ZCity_RTV_Tiny")
        surface.SetTextColor(255, 255, 255, 255)
        local tw, th = surface.GetTextSize(txt)
        surface.SetTextPos(x - tw / 2, y - th / 2)
        surface.DrawText(txt)
    end

    function button:DoClick()
        if IsValid(RTVMenu) then
            RTVMenu:Remove()
        end
    end
end

function zb.StartRTV()
    local incomingMaps = net.ReadTable()
    if istable(incomingMaps) then
        maps = {}
        for i = 1, math.min(#incomingMaps, maxChoices) do
            maps[i] = incomingMaps[i]
        end
    else
        maps = {}
    end
    time = net.ReadFloat()
    local incomingBlacklist = net.ReadTable()
    blacklistedMaps = istable(incomingBlacklist) and incomingBlacklist or {}
    votes = {}
    winmap = ""
    rtvEnded = false
    zb.RTVMenu()
    rtvStarted = true
end

net.Receive("RTVMenu", function()
    local hasData = net.ReadBool()
    if hasData then
        local incomingMaps = net.ReadTable()
        if istable(incomingMaps) then
            maps = {}
            for i = 1, math.min(#incomingMaps, maxChoices) do
                maps[i] = incomingMaps[i]
            end
        end
        time = net.ReadFloat()
        local incomingBlacklist = net.ReadTable()
        blacklistedMaps = istable(incomingBlacklist) and incomingBlacklist or blacklistedMaps
    end
    zb.RTVMenu()
end)

function zb.RTVregVote()
    votes = net.ReadTable()
end

function zb.EndRTV()
    winmap = net.ReadString()
    rtvEnded = true
end

net.Receive("ZB_RockTheVote_start", zb.StartRTV)
net.Receive("ZB_RockTheVote_voteCLreg", zb.RTVregVote)
net.Receive("ZB_RockTheVote_end", zb.EndRTV)
