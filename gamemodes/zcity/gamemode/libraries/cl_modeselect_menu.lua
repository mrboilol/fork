if CLIENT then
    local isMenuOpen = nil
    zb.availableModes = zb.availableModes or {}

    zb.RoundList = zb.RoundList or {}
    zb.nextround = zb.nextround or nil
    zb.forcemode = zb.forcemode or "random"
    local queueManagerInstance = nil

    --;; The worst part of the job is taking the shit you wrote and making it readable
    local COL_BG        = Color(28, 28, 28, 240)
    local COL_BORDER    = Color(75, 75, 75, 255)
    local COL_CAT       = Color(60, 60, 60, 255)
    local COL_CATBAR    = Color(42, 42, 42, 255)
    local COL_ROW       = Color(43, 43, 43, 235)
    local COL_ROW_HOV   = Color(56, 56, 56, 240)
    local COL_ROWBAR    = Color(47, 47, 47, 235)
    local COL_ACCENT    = Color(160, 45, 45, 255)
    local COL_ACCENT_H  = Color(190, 60, 60, 255)
    local COL_GREEN     = Color(80, 125, 65, 255)
    local COL_GREEN_H   = Color(100, 150, 85, 255)
    local COL_ORANGE    = Color(220, 150, 45, 255)
    local COL_TEXT      = Color(235, 235, 235, 235)
    local COL_TEXT_DIM  = Color(140, 140, 140, 220)
    local COL_TOGGLE_BG = Color(28, 28, 28, 255)

    local menufont = "Bahnschrift"

    surface.CreateFont("ZB_QM_Title",    {font = menufont, size = 26, weight = 500, antialias = true})
    surface.CreateFont("ZB_QM_Category", {font = menufont, size = 21, weight = 400, antialias = true})
    surface.CreateFont("ZB_QM_Item",     {font = menufont, size = 19, weight = 400, antialias = true})
    surface.CreateFont("ZB_QM_Small",    {font = menufont, size = 14, weight = 300, antialias = true})
    surface.CreateFont("ZB_QM_Btn",      {font = menufont, size = 16, weight = 500, antialias = true})

    local SND_CLICK   = "shitty/tap_depress.ogg"
    local SND_RELEASE = "shitty/tap_release.ogg"
    local SND_HOVER   = "shitty/tap-resonant.ogg"



    net.Receive("ZB_SendModesInfo", function()
        zb.availableModes = net.ReadTable()
        if IsValid(queueManagerInstance) then queueManagerInstance:RebuildModes() end
    end)

    net.Receive("ZB_SendRoundList", function()
        zb.RoundList = net.ReadTable()
        zb.nextround = net.ReadString()
        zb.forcemode = net.ReadString()
        table.insert(zb.RoundList, 1, zb.nextround)
        zb.nextround = nil
        if IsValid(queueManagerInstance) then queueManagerInstance:QueueUpdate() end
    end)

    net.Receive("ZB_NotifyRoundListChange", function()
        local playerName = net.ReadString()
        chat.AddText(Color(180, 180, 255), playerName, COL_TEXT, " has modified the game mode queue")
        net.Start("ZB_RequestRoundList")
        net.SendToServer()
    end)

    local function GetModeName(key)
        for _, mode in ipairs(zb.availableModes) do
            if mode.key == key then return mode.name end
        end
        return key
    end
    local function ForceActive()
        return zb.forcemode and zb.forcemode ~= "random" and zb.forcemode ~= ""
    end

    local function DrawFrameBG(self, w, h)
            if hg and hg.DrawBlur then hg.DrawBlur(self, 4) end
            surface.SetDrawColor(COL_BG)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(120, 120, 130, 12)
            local sp = 64
            local ox = (CurTime() * 18) % sp
            for x = 0, math.ceil(w / sp) do
                surface.DrawRect(x * sp - ox, 0, 1, h)
            end
            local oy = (CurTime() * 18) % sp
            for y = 0, math.ceil(h / sp) do
                surface.DrawRect(0, y * sp - oy + sp, w, 1)
            end
            surface.SetDrawColor(COL_BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local function ZcityBUTT(btn, base, hover, txtColor)
        base     = base     or COL_ROW
        hover    = hover    or COL_ROW_HOV
        txtColor = txtColor or COL_TEXT
        btn:SetFont("ZB_QM_Btn")
        btn:SetTextColor(txtColor)
        btn.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
        btn.Paint = function(self, w, h)
            local c = self:IsHovered() and hover or base
            draw.RoundedBox(0, 0, 0, w, h, c)
            surface.SetDrawColor(0, 0, 0, 55)
            surface.DrawRect(0, h - 3, w, 3)
        end
    end

    local function CreateToggle(parent, getState, onClick)
        local toggle = vgui.Create("DButton", parent)
        toggle:SetText("")
        toggle:SetSize(52, 24)
        local animProgress = getState() and 1 or 0
        toggle.Paint = function(self, w, h)
                local target = getState() and 1 or 0
                animProgress = Lerp(FrameTime() * 10, animProgress, target)
                local bgColor = Color(
                    Lerp(animProgress, 180, 80),
                    Lerp(animProgress, 30, 120),
                    Lerp(animProgress, 30, 50)
                )
            draw.RoundedBox(0, 0, 0, w, h, COL_TOGGLE_BG)
            draw.RoundedBox(0, 2, 2, w - 4, h - 4, Color(0, 0, 0, 30))
            local slsize = h - 12
            local slPos = Lerp(animProgress, 6, w - slsize - 6)
            draw.RoundedBox(0, slPos, 6, slsize, slsize, bgColor)
            surface.SetDrawColor(0, 0, 0, Lerp(animProgress, 150, 40))
            surface.DrawRect(slPos, slsize + 4, slsize, 3)
        end
        toggle.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
        toggle.DoClick = function()
            surface.PlaySound(SND_CLICK)
            onClick()
        end
        return toggle
    end

    local function StyleScroll(scroll)
            local bar = scroll:GetVBar()
            bar:SetWide(8)
            bar:SetHideButtons(true)
            bar.Paint = function(self, w, h)
                surface.SetDrawColor(0, 0, 0, 70)
                surface.DrawRect(1, 0, w - 2, h)
            end
        bar.btnGrip.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and Color(120, 120, 120) or Color(90, 90, 90))
            surface.DrawRect(1, 0, w - 2, h)
        end
    end

    local function CreateCategoryBar(parent, text)
        local bar = vgui.Create("DPanel", parent)
        bar:Dock(TOP)
        bar:SetTall(38)
        bar:DockMargin(0, 0, 0, 8)
        bar.Paint = function(self, w, h)
            surface.SetDrawColor(COL_CAT)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(COL_CATBAR)
            surface.DrawRect(0, h - 5, w, 5)
            draw.SimpleText(text, "ZB_QM_Category", w / 2, h / 2 - 2, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return bar
    end

    local function AddCloseButton(parent, frame)
        local btn = vgui.Create("DButton", parent)
        btn:SetSize(38, 38)
        btn:Dock(RIGHT)
        btn:DockMargin(0, 1, 6, 1)
        btn:SetText("")
        btn.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(255, 110, 110) or COL_TEXT
            local m = 12
            surface.SetDrawColor(col)
            for i = -1, 1 do
                surface.DrawLine(m, m + i, w - m, h - m + i)
                surface.DrawLine(w - m, m + i, m, h - m + i)
            end
        end
        btn.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
        btn.DoClick = function()
            surface.PlaySound(SND_RELEASE)
            frame:Close()
        end
        return btn
    end

    local function MakeContent(frame)
        local content = vgui.Create("DPanel", frame)
        content.Paint = nil
        frame.PerformLayout = function(_, w, h)
            content:SetPos(2, 2)
            content:SetSize(w - 4, h - 4)
        end
        return content
    end

    local function CreateAvailableRow(parent, mode, manager)
        local row = vgui.Create("DPanel", parent)
        row:SetTall(54)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 8)
        local statusText, statusCol
            if mode.canlaunch == 1 then
                statusText, statusCol = "Ready to launch", COL_GREEN_H
            elseif mode.canlaunch == 0 then
                statusText, statusCol = "Cannot launch (no points / blocked)", COL_ACCENT_H
            else
                statusText, statusCol = mode.key, COL_TEXT_DIM
            end
        row.Paint = function(self, w, h)
            local forced = (zb.forcemode == mode.key)
            surface.SetDrawColor(self:IsHovered() and COL_ROW_HOV or COL_ROW)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(forced and COL_ORANGE or COL_ROWBAR)
            surface.DrawRect(0, h - 3, w, 3)
            draw.RoundedBox(0, 16, h / 2 - 4, 8, 8, statusCol)
            draw.SimpleText(mode.name, "ZB_QM_Item", 34, h / 2 - 8, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            --draw.SimpleText(forced and "proverka" or statusText, "ZB_QM_Small", 34, h / 2 + 11, forced and COL_ORANGE or COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local toggle = CreateToggle(row,
            function() return zb.forcemode == mode.key end,
            function()
                local target = (zb.forcemode == mode.key) and "random" or mode.key
                net.Start("AdminSetGameMode")
                    net.WriteString("setforcemode")
                    net.WriteString(target)
                    net.WriteBool(false)
                net.SendToServer()
                zb.forcemode = target
            end)
        toggle:Dock(RIGHT)
        toggle:DockMargin(10, 15, 16, 15)
        toggle:SetTooltip("Force this mode every round")
        local addBtn = vgui.Create("DButton", row)
        addBtn:SetWide(90)
        addBtn:Dock(RIGHT)
        addBtn:DockMargin(8, 12, 0, 12)
        addBtn:SetText("+ Queue")
        ZcityBUTT(addBtn, COL_GREEN, COL_GREEN_H)
        addBtn.DoClick = function()
            table.insert(zb.RoundList, mode.key)
            surface.PlaySound(SND_CLICK)
            manager:QueueUpdate()
        end
        return row
    end
    local ROW_H, ROW_GAP = 44, 8
    local STRIDE = ROW_H + ROW_GAP
    local function OpenQueueManager()
        if IsValid(queueManagerInstance) then queueManagerInstance:Close() end
        local frame = vgui.Create("ZFrame")
        frame:SetSize(math.Clamp(ScrW() * 0.62, 900, 1280), math.Clamp(ScrH() * 0.72, 560, 780))
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        frame:SetBorder(false)
        frame:MakePopup()
        frame.Paint = DrawFrameBG
        queueManagerInstance = frame
        local content = MakeContent(frame)
        local header = vgui.Create("DPanel", content)
        header:Dock(TOP)
        header:SetTall(42)
        header:DockMargin(0, 0, 0, 10)
        header.Paint = function(self, w, h)
            surface.SetDrawColor(COL_CAT)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(COL_CATBAR)
            surface.DrawRect(0, h - 5, w, 5)
            draw.SimpleText("Game Mode Queue", "ZB_QM_Title", w / 2, h / 2 - 2, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        AddCloseButton(header, frame)
        local body = vgui.Create("DPanel", content)
        body:Dock(FILL)
        body.Paint = nil
        local leftPanel = vgui.Create("DPanel", body)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(frame:GetWide() * 0.55)
        leftPanel:DockMargin(0, 0, 6, 0)
        leftPanel.Paint = nil
        CreateCategoryBar(leftPanel, "Available Game Modes")
        local searchBar = vgui.Create("DTextEntry", leftPanel)
        searchBar:Dock(TOP)
        searchBar:DockMargin(0, 0, 0, 8)
        searchBar:SetTall(32)
        searchBar:SetFont("ZB_QM_Item")
        searchBar.Paint = function(self, w, h)
            surface.SetDrawColor(COL_TOGGLE_BG)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(70, 70, 70, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            self:DrawTextEntryText(COL_TEXT, Color(120, 120, 120), COL_TEXT)
            if self:GetText() == "" then
                draw.SimpleText("Search game modes...", "ZB_QM_Item", 8, h / 2, COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        local dscroll = vgui.Create("DScrollPanel", leftPanel)
        dscroll:Dock(FILL)
        dscroll:DockMargin(5, 5, 5, 5)
        
        local modeItems = {}
        
        local function UpdateSearch(filter)
            filter = filter:lower()
            
            for _, item in ipairs(modeItems) do
                local visible = filter == "" or string.find(item.Mode.name:lower(), filter)
                item:SetVisible(visible)
            end
            
            dscroll:InvalidateLayout()
        end
        
        searchBar.OnChange = function(self)
            UpdateSearch(self:GetValue())
        end
        
        local allowedModes = {
            ["tdm"] = true,
            ["cstrike"] = true,
            ["hmcd"] = true,
            ["suicidelunatic"] = true,
            ["hl2dm"] = true,
            ["riot"] = true,
            ["gwars"] = true,
            ["criresp"] = true,
        }
        
        for i, mode in SortedPairsByMemberValue(zb.availableModes,"canlaunch",true) do
            if !LocalPlayer():IsSuperAdmin() and !allowedModes[mode.key] then continue end
            
            local modeBtn = CreateModeItem(dscroll, mode)
            table.insert(modeItems, modeBtn)
            
            modeBtn:SetCursor("hand")
            modeBtn:SetTooltip("Click to select/unselect mode")
            
            local inQueue = false
            for _, queuedModeKey in ipairs(zb.RoundList) do
                if queuedModeKey == mode.key then
                    inQueue = true
                    break
                end
            end

            local indicator = vgui.Create("DPanel", modeBtn)
            indicator:SetSize(16, 7)
            indicator:SetPos(8, 4)
            indicator.IndiColor = Color(0, 0, 0, 0)
            indicator.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, indicator.IndiColor)
            end

            if mode.canlaunch == 1 then
                indicator.IndiColor = Color(0,255,34)
                indicator:SetTooltip("This mode can launch")
            end

            if inQueue then
                indicator.IndiColor = Color(255, 155, 0, 255)
                indicator:SetTooltip("This mode is already in queue")
            end
     
            if mode.canlaunch == 0 then
                indicator.IndiColor = Color(255,0,0,255)
                indicator:SetTooltip("This mode can't launch")
            end
            
            if command == "setmode" or command == "setforcemode" then
                local selectBtn = vgui.Create("DButton", modeBtn)
                selectBtn:SetSize(80, 26)
                selectBtn:Dock(RIGHT)
                selectBtn:DockMargin(5, 7, 5, 7)
                selectBtn:SetText("Select")
                selectBtn.DoClick = function()
                    net.Start("AdminSetGameMode")
                    net.WriteString(command)
                    net.WriteString(mode.key)
                    net.WriteBool(false) 
                    net.SendToServer()
                    frame:Close()
                end
            end
        end
        

        local batchPanel = vgui.Create("DPanel", leftPanel)
        batchPanel:Dock(BOTTOM)
        batchPanel:DockMargin(5, 5, 5, 5)
        batchPanel:SetTall(80)
        StyleElement(batchPanel, Color(40, 40, 40, 200))
        
        local batchTitle = vgui.Create("DLabel", batchPanel)
        batchTitle:SetText("Batch Operations")
        batchTitle:SetFont("DermaDefaultBold")
        batchTitle:SetTextColor(Color(255, 255, 255))
        batchTitle:Dock(TOP)
        batchTitle:DockMargin(0, 5, 0, 5)
        batchTitle:SetContentAlignment(5)
        
        local addToQueueBtn = vgui.Create("DButton", batchPanel)
        addToQueueBtn:SetText("Add Selected to Beginning of Queue")
        addToQueueBtn:Dock(TOP)
        addToQueueBtn:DockMargin(5, 0, 5, 5)
        addToQueueBtn:SetTall(26)
        addToQueueBtn.DoClick = function()
            local selectedCount = 0
            
            local selectedKeys = {}
            for key, selected in pairs(selectedModes) do
                if selected then
                    table.insert(selectedKeys, 1, key) 
                    selectedCount = selectedCount + 1
                end
            end
            
            for i = 1, #selectedKeys do
                table.insert(zb.RoundList, 1, selectedKeys[i])
            end
            
            if selectedCount > 0 then
                queuePanel:QueueUpdate()
                
                /*net.Start("ZB_UpdateRoundList")
                    net.WriteTable(zb.RoundList)
                    net.WriteBool(false)
                net.SendToServer()*/
                
                chat.AddText(Color(0, 255, 0), "Added " .. selectedCount .. " modes to beginning of queue!")
                
                selectedModes = {}
                for _, item in ipairs(modeItems) do
                    item.Selected = false
                end
            else
                chat.AddText(Color(255, 0, 0), "No modes selected!")
            end
        end
        
        local addToEndBtn = vgui.Create("DButton", batchPanel)
        addToEndBtn:SetText("Add Selected to End of Queue")
        addToEndBtn:Dock(TOP)
        addToEndBtn:DockMargin(5, 0, 5, 0)
        addToEndBtn:SetTall(26)
        addToEndBtn.DoClick = function()
            local selectedCount = 0
            
            for key, selected in pairs(selectedModes) do
                if selected then
                    table.insert(zb.RoundList, key)
                    selectedCount = selectedCount + 1
                end
            end
            
            if selectedCount > 0 then
                queuePanel:QueueUpdate()
                
                /*net.Start("ZB_UpdateRoundList")
                    net.WriteTable(zb.RoundList)
                    net.WriteBool(false)
                net.SendToServer()*/
                
                chat.AddText(Color(0, 255, 0), "Added " .. selectedCount .. " modes to end of queue!")
                

                selectedModes = {}
                for _, item in ipairs(modeItems) do
                    item.Selected = false
                end
            else
                chat.AddText(Color(255, 0, 0), "No modes selected!")
            end
        end
        
        local refreshBtn = vgui.Create("DButton", leftPanel)
        refreshBtn:SetText("Refresh Data")
        refreshBtn:Dock(BOTTOM)
        refreshBtn:DockMargin(5, 5, 5, 5)
        refreshBtn:SetTall(30)
        refreshBtn.DoClick = function()
            net.Start("ZB_RequestRoundList")
            net.SendToServer()
        end
        
        timer.Create("QueueAutoRefresh", 5, 0, function()
            if IsValid(frame) then
                //net.Start("ZB_RequestRoundList")
                //net.SendToServer()
            else
                timer.Remove("QueueAutoRefresh")
            end
        end)
        
        frame.OnClose = function()
            timer.Remove("QueueAutoRefresh")
            queuePanelInstance = nil
        end
        
        net.Start("ZB_RequestRoundList")
        net.SendToServer()
    end

    local statsPanelInstance = nil
    local adminStatsRows = {}

    net.Receive("ZB_AdminStatsSend", function()
        adminStatsRows = net.ReadTable() or {}

        if IsValid(statsPanelInstance) and statsPanelInstance.RefreshRows then
            statsPanelInstance:RefreshRows()
        end
    end)

    net.Receive("ZB_AdminStatsSaveResult", function()
        local ok = net.ReadBool()
        local message = net.ReadString()

        chat.AddText(ok and Color(0, 255, 0) or Color(255, 80, 80), message)
    end)

    local function OpenPlayerStatsMenu()
        if not LocalPlayer():IsSuperAdmin() then return end
        if IsValid(statsPanelInstance) then return end

        local frame = vgui.Create("ZFrame")
        statsPanelInstance = frame
        frame:SetSize(900, 560)
        frame:Center()
        frame:SetTitle("Player SQL Stats")
        frame:MakePopup()

        local topPanel = vgui.Create("DPanel", frame)
        topPanel:Dock(TOP)
        topPanel:SetTall(35)
        topPanel:DockMargin(5, 5, 5, 5)

        local search = vgui.Create("DTextEntry", topPanel)
        search:Dock(FILL)
        search:SetPlaceholderText("Search name or SteamID64")

        local refreshBtn = vgui.Create("DButton", topPanel)
        refreshBtn:Dock(RIGHT)
        refreshBtn:SetWide(100)
        refreshBtn:SetText("Refresh")
        StyleElement(refreshBtn)

        local leftPanel = vgui.Create("DPanel", frame)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(350)
        leftPanel:DockMargin(5, 0, 5, 5)

        local list = vgui.Create("DListView", leftPanel)
        list:Dock(FILL)
        list:AddColumn("Player")
        list:AddColumn("SteamID64")
        list:AddColumn("Status")

        local rightPanel = vgui.Create("DScrollPanel", frame)
        rightPanel:Dock(FILL)
        rightPanel:DockMargin(0, 0, 5, 5)

        local selectedRow
        local entries = {}
        local achievementEntries = {}

        local function AddEntry(parent, label, key, value)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(0, 0, 0, 4)

            local title = vgui.Create("DLabel", row)
            title:Dock(LEFT)
            title:SetWide(110)
            title:SetText(label)
            title:SetTextColor(Color(255, 255, 255))

            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            entry:SetText(tostring(value or 0))

            entries[key] = entry
        end

        local function AddAchievementEntry(parent, key, value)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(0, 0, 0, 4)

            local title = vgui.Create("DLabel", row)
            title:Dock(LEFT)
            title:SetWide(110)
            title:SetText(key)
            title:SetTextColor(Color(255, 255, 255))

            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            entry:SetText(tostring(value or 0))

            achievementEntries[key] = entry
        end

        local function ShowPlayer(row)
            selectedRow = row
            entries = {}
            achievementEntries = {}
            rightPanel:Clear()

            if not row then return end

            local title = vgui.Create("DLabel", rightPanel)
            title:Dock(TOP)
            title:SetTall(32)
            title:SetFont("DermaDefaultBold")
            title:SetText(row.name .. " | " .. row.steamid .. (row.active and " | ACTIVE" or ""))
            title:SetTextColor(Color(255, 255, 255))

            AddEntry(rightPanel, "XP", "experience", row.experience)
            AddEntry(rightPanel, "Skill", "skill", row.skill)
            AddEntry(rightPanel, "Deaths", "deaths", row.deaths)
            AddEntry(rightPanel, "Kills", "kills", row.kills)
            AddEntry(rightPanel, "Suicides", "suicides", row.suicides)
            AddEntry(rightPanel, "Headshots", "headshots", row.headshots)
            AddEntry(rightPanel, "Karma", "karma", row.karma)

            local achTitle = vgui.Create("DLabel", rightPanel)
            achTitle:Dock(TOP)
            achTitle:SetTall(28)
            achTitle:SetFont("DermaDefaultBold")
            achTitle:SetText("Achievements")
            achTitle:SetTextColor(Color(255, 255, 255))

            for key, value in SortedPairs(row.achievements or {}) do
                AddAchievementEntry(rightPanel, key, value)
            end

            local saveBtn = vgui.Create("DButton", rightPanel)
            saveBtn:Dock(TOP)
            saveBtn:SetTall(34)
            saveBtn:DockMargin(0, 8, 0, 0)
            saveBtn:SetText("Save Stats")
            StyleElement(saveBtn)
            saveBtn.DoClick = function()
                if not selectedRow then return end

                local data = {name = selectedRow.name}
                for key, entry in pairs(entries) do
                    data[key] = entry:GetText()
                end

                data.achievements = {}
                for key, entry in pairs(achievementEntries) do
                    data.achievements[key] = entry:GetText()
                end

                net.Start("ZB_AdminStatsSave")
                    net.WriteString(selectedRow.steamid)
                    net.WriteTable(data)
                net.SendToServer()
            end
        end

        function frame:RefreshRows()
            local needle = search:GetText():lower()
            list:Clear()

            for _, row in ipairs(adminStatsRows) do
                local name = tostring(row.name or "Unknown")
                local steamID64 = tostring(row.steamid or "")

                if needle == "" or name:lower():find(needle, 1, true) or steamID64:find(needle, 1, true) then
                    local line = list:AddLine(name, steamID64, row.active and "Online" or "Offline")
                    line.RowData = row
                end
            end
        end

        list.OnRowSelected = function(panel, index, line)
            ShowPlayer(line.RowData)
        end

        search.OnValueChange = function()
            frame:RefreshRows()
        end

        refreshBtn.DoClick = function()
            net.Start("ZB_AdminStatsRequest")
            net.SendToServer()
        end

        frame.OnClose = function()
            statsPanelInstance = nil
        end

        net.Start("ZB_AdminStatsRequest")
        net.SendToServer()
    end

    local function OpenAdminMenu()
        if IsValid(isMenuOpen) then return end

        isMenuOpen = vgui.Create("ZFrame")
        local frame = isMenuOpen
        frame:SetSize(300, 252)
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        frame:SetBorder(false)
        frame:MakePopup()

        local setModeBtn = vgui.Create("DButton", frame)
        setModeBtn:SetText("Set Next Mode")
        setModeBtn:Dock(TOP)
        setModeBtn:DockMargin(5, 10, 5, 2)
        setModeBtn:SetSize(300, 40)
        StyleElement(setModeBtn)
        setModeBtn.DoClick = function()
            OpenModeSelection("setmode") 
        end

        local setForceModeBtn = vgui.Create("DButton", frame)
        setForceModeBtn:SetText("Set Auto Next Mode")
        setForceModeBtn:Dock(TOP)
        setForceModeBtn:DockMargin(5, 2, 5, 2)
        setForceModeBtn:SetSize(300, 40)
        StyleElement(setForceModeBtn)
        setForceModeBtn.DoClick = function()
            OpenModeSelection("setforcemode")
        end
        
        local queueModeBtn = vgui.Create("DButton", frame)
        queueModeBtn:SetText("Manage Game Mode Queue")
        queueModeBtn:Dock(TOP)
        queueModeBtn:DockMargin(5, 2, 5, 2)
        queueModeBtn:SetSize(300, 40)
        StyleElement(queueModeBtn)
        queueModeBtn.DoClick = function()
            OpenModeSelection("queue")
        end

        if LocalPlayer():IsSuperAdmin() then
            local statsBtn = vgui.Create("DButton", frame)
            statsBtn:SetText("Player SQL Stats")
            statsBtn:Dock(TOP)
            statsBtn:DockMargin(5, 2, 5, 2)
            statsBtn:SetSize(300, 40)
            StyleElement(statsBtn)
            statsBtn.DoClick = function()
                OpenPlayerStatsMenu()
            end
        end

        local manageBtn = BigButton("Manage Game Mode Queue", COL_ROW, COL_ROW_HOV)
        manageBtn.DoClick = function()
            surface.PlaySound(SND_CLICK)
            OpenQueueManager()
        end

        local endBtn = BigButton("End Round", COL_ACCENT, COL_ACCENT_H)
        endBtn.DoClick = function()
            surface.PlaySound(SND_CLICK)
            net.Start("AdminEndRound")
            net.SendToServer()
            frame:Close()
        end
        frame.OnClose = function()
            isMenuOpen = false
        end
    end

    hook.Add("InitPostEntity", "RequestModeData", function()
        if LocalPlayer():IsAdmin() then
            timer.Simple(2, function()
                net.Start("ZB_RequestRoundList")
                net.SendToServer()
            end)
        end
    end)

    local f6Key = KEY_F6

    hook.Add("PlayerButtonDown", "OpenAdminMenuF6", function(ply, key)
        if key == f6Key and LocalPlayer():IsAdmin() and not IsValid(isMenuOpen) then
            OpenAdminMenu()
        end
    end)
end
