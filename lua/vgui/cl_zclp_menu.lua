local PANEL = {}

local function phrase(key)
    return ZCLP.GetPhrase(key)
end

local function makePreviewText(name, preset)
    if not istable(preset) then
        return "-"
    end

    local wepCount = istable(preset.weapons) and #preset.weapons or 0
    local armorCount = istable(preset.armor) and table.Count(preset.armor) or 0
    local clothesCount = istable(preset.clothes) and #preset.clothes or 0
    local version = (preset.meta and preset.meta.zcityVersion) or "unknown"

    return string.format(
        "%s %s\n%s %d\n%s %d\n%s %d\n%s %s",
        name,
        "",
        phrase("preview_weapons"),
        wepCount,
        phrase("preview_armor"),
        armorCount,
        phrase("preview_clothes"),
        clothesCount,
        phrase("preview_meta"),
        version
    )
end

function PANEL:Init()
    self:SetTitle(phrase("title"))
    self:SetSize(ScrW() * 0.42, ScrH() * 0.6)
    self:Center()
    self:MakePopup()

    self.Presets = {}
    self.SelectedPreset = nil
    self.AutoSpawnPreset = nil

    self.Top = vgui.Create("DPanel", self)
    self.Top:Dock(TOP)
    self.Top:SetTall(36)
    self.Top:DockMargin(8, 8, 8, 0)
    self.Top.Paint = nil

    self.NameInput = vgui.Create("DTextEntry", self.Top)
    self.NameInput:Dock(FILL)
    self.NameInput:SetPlaceholderText(phrase("name_hint"))
    self.NameInput:SetFont("DermaDefaultBold")
    self.NameInput.Paint = function(s, w, h)
        local isFocus = s:HasFocus()
        local col = isFocus and Color(60, 60, 60, 255) or Color(30, 30, 30, 255)
        local border = isFocus and Color(200, 0, 0, 255) or Color(80, 80, 80, 255)
        
        -- Background
        draw.RoundedBox(4, 0, 0, w, h, border)
        draw.RoundedBox(2, 1, 1, w - 2, h - 2, col)
        
        if s:GetText() == "" and not isFocus then
            draw.SimpleText(s:GetPlaceholderText(), "DermaDefault", 8, h / 2, Color(180, 180, 180, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        
        s:DrawTextEntryText(color_white, Color(100, 0, 0), color_white)
    end

    self.AutoSpawn = vgui.Create("DCheckBoxLabel", self.Top)
    self.AutoSpawn:Dock(RIGHT)
    self.AutoSpawn:SetWide(200)
    self.AutoSpawn:DockMargin(10, 8, 0, 0)
    self.AutoSpawn:SetText(phrase("autospawn"))
    self.AutoSpawn:SetValue(false)
    self.AutoSpawn.OnChange = function(_, val)
        if self._settingValue then return end
        
        if not val then
            ZCLP.ClientAutoSpawn = nil
            ZCLP.SaveLocalPresets()
            self:UpdateAutoSpawn(nil)
            return
        end

        if not self.SelectedPreset then 
            self._settingValue = true
            self.AutoSpawn:SetValue(false)
            self._settingValue = nil
            chat.AddText(Color(255, 120, 120), "[ZCLP] ", color_white, phrase("no_selection"))
            return 
        end
        
        ZCLP.ClientAutoSpawn = self.SelectedPreset
        ZCLP.SaveLocalPresets()
        self:UpdateAutoSpawn(self.SelectedPreset)
    end

    self.List = vgui.Create("DListView", self)
    self.List:Dock(LEFT)
    self.List:SetWide(self:GetWide() * 0.45)
    self.List:DockMargin(8, 0, 8, 8)
    self.List:AddColumn("S"):SetFixedWidth(24) -- Status column
    self.List:AddColumn("Preset"):SetFixedWidth(146)
    self.List:AddColumn("W")
    self.List:AddColumn("A")
    self.List:AddColumn("C")

    self.Preview = vgui.Create("DLabel", self)
    self.Preview:Dock(FILL)
    self.Preview:DockMargin(0, 0, 8, 8)
    self.Preview:SetWrap(true)
    self.Preview:SetText("-")
    self.Preview:SetContentAlignment(7)

    self.Bottom = vgui.Create("DPanel", self)
    self.Bottom:Dock(BOTTOM)
    self.Bottom:SetTall(36)
    self.Bottom:DockMargin(8, 0, 8, 8)
    self.Bottom.Paint = nil

    self.GivePanel = vgui.Create("DPanel", self)
    self.GivePanel:Dock(BOTTOM)
    self.GivePanel:SetTall(32)
    self.GivePanel:DockMargin(8, 0, 8, 4)
    self.GivePanel.Paint = nil

    local function addButton(text, parent, dockMode, callback)
        local button = vgui.Create("DButton", parent)
        button:Dock(dockMode)
        button:SetText(text)
        button:DockMargin(0, 0, 6, 0)
        button.DoClick = callback
        return button
    end

    local refreshBtn = addButton("", self.Bottom, RIGHT, function()
        ZCLP.LoadLocalPresets()
        self:SetPresets(ZCLP.ClientPresets)
        self:UpdateAutoSpawn(ZCLP.ClientAutoSpawn)
    end)
    refreshBtn:SetWide(36)
    refreshBtn:SetIcon("icon16/arrow_refresh.png")
    refreshBtn:SetTooltip(phrase("refresh"))

    addButton(phrase("create"), self.Bottom, LEFT, function()
        local name = string.Trim(self.NameInput:GetValue() or "")
        if name == "" then
            chat.AddText(Color(255, 120, 120), "[ZCLP] ", color_white, phrase("invalid_name"))
            return
        end
        net.Start("zclp_create_preset")
        net.WriteString(name)
        net.SendToServer()
    end):SetWide(85)

    addButton(phrase("load"), self.Bottom, LEFT, function()
        if not self.SelectedPreset then return end
        net.Start("zclp_load_preset")
        net.WriteString(self.SelectedPreset)
        net.WriteTable(self.Presets[self.SelectedPreset] or {})
        net.SendToServer()
    end):SetWide(85)

    addButton(phrase("remove"), self.Bottom, LEFT, function()
        if not self.SelectedPreset then return end
        
        ZCLP.ClientPresets[self.SelectedPreset] = nil
        if ZCLP.ClientAutoSpawn == self.SelectedPreset then
            ZCLP.ClientAutoSpawn = nil
        end
        
        ZCLP.SaveLocalPresets()
        self:SetPresets(ZCLP.ClientPresets)
        self:UpdateAutoSpawn(ZCLP.ClientAutoSpawn)
        
        chat.AddText(Color(120, 190, 255), "[ZCLP] ", color_white, phrase("deleted"))
    end):SetWide(85)

    addButton(phrase("update"), self.Bottom, LEFT, function()
        if not self.SelectedPreset then return end
        net.Start("zclp_update_preset")
        net.WriteString(self.SelectedPreset)
        net.SendToServer()
    end):SetWide(83)

    local giveBtn = addButton(phrase("give"), self.GivePanel, RIGHT, function()
        if not self.SelectedPreset then return end

        local menu = DermaMenu()
        menu:AddOption(phrase("select_player")):SetIcon("icon16/user.png")
        menu:AddSpacer()

        local players = player.GetAll()
        table.sort(players, function(a, b) return a:Nick() < b:Nick() end)

        for _, ply in ipairs(players) do
            if ply == LocalPlayer() then continue end
            menu:AddOption(ply:Nick(), function()
                if not IsValid(ply) then return end
                net.Start("zclp_give_preset")
                net.WriteString(self.SelectedPreset)
                net.WriteTable(self.Presets[self.SelectedPreset] or {})
                net.WriteEntity(ply)
                net.SendToServer()
            end):SetIcon("icon16/user_go.png")
        end

        menu:Open()
    end)
    giveBtn:SetWide(100)
    giveBtn:SetIcon("icon16/user_go.png")

    self.List.OnRowSelected = function(_, _, row)
        local name = row:GetColumnText(2)
        self.SelectedPreset = name
        self.NameInput:SetValue(name)
        self.Preview:SetText(makePreviewText(name, self.Presets[name]))

        self._settingValue = true
        -- Checkbox reflects if THIS preset is the autospawn one
        self.AutoSpawn:SetValue(self.AutoSpawnPreset ~= nil)
        self._settingValue = nil
    end

    self.List.DoDoubleClick = function(_, _, row)
        local name = row:GetColumnText(2)
        if not name or name == "" then return end
        self.SelectedPreset = name
        self.NameInput:SetValue(name)
        net.Start("zclp_load_preset")
        net.WriteString(name)
        net.WriteTable(self.Presets[name] or {})
        net.SendToServer()
    end
end

function PANEL:SetPresets(presets)
    self.Presets = presets or {}
    self.List:Clear()

    local names = table.GetKeys(self.Presets)
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)

    for _, name in ipairs(names) do
        local preset = self.Presets[name]
        local wepCount = istable(preset and preset.weapons) and #preset.weapons or 0
        local armorCount = istable(preset and preset.armor) and table.Count(preset.armor) or 0
        local clothesCount = istable(preset and preset.clothes) and #preset.clothes or 0
        
        local isAuto = self.AutoSpawnPreset == name
        self.List:AddLine(isAuto and "★" or "", name, wepCount, armorCount, clothesCount)
    end

    if self.SelectedPreset and self.Presets[self.SelectedPreset] then
        self.Preview:SetText(makePreviewText(self.SelectedPreset, self.Presets[self.SelectedPreset]))
    else
        self.Preview:SetText("-")
    end
end

function PANEL:UpdateAutoSpawn(name)
    self.AutoSpawnPreset = name
    self._settingValue = true
    -- Checkbox shows 'Checked' if ANY preset is set for autospawn, 
    -- or if specifically the selected one is (depends on how you want to use it).
    -- Let's make it show if ANY autospawn is active globally, OR if selected matches.
    self.AutoSpawn:SetValue(name ~= nil)
    self._settingValue = nil
    
    -- Refresh list to update markers
    self:SetPresets(self.Presets)
end

vgui.Register("ZCLPMenu", PANEL, "DFrame")

function ZCLP.OpenMenu()
    if IsValid(ZCLP.Menu) then
        ZCLP.Menu:Remove()
    end

    ZCLP.LoadLocalPresets()

    ZCLP.Menu = vgui.Create("ZCLPMenu")
    ZCLP.Menu:SetPresets(ZCLP.ClientPresets or {})
    ZCLP.Menu:UpdateAutoSpawn(ZCLP.ClientAutoSpawn)
end
