local Theme = {
    bg          = Color(28, 28, 32),
    bg_overlay  = Color(40, 40, 45, 255),
    card        = Color(38, 40, 45),
    card_hover  = Color(45, 47, 54),
    
    accent      = Color(68, 158, 210),
    accent_dim  = Color(68, 158, 210, 45),
    
    toggle_off  = Color(58, 58, 62),
    toggle_on   = Color(42, 195, 108),
    toggle_knob = Color(248, 248, 250),
    
    text_main   = Color(245, 245, 247),
    text_desc   = Color(185, 188, 195),
    slider_line = Color(255, 255, 255, 25),
    text_box_bg = Color(18, 18, 22, 210),
    
    danger      = Color(220, 72, 58),
    danger_hover= Color(185, 55, 42),
    
    success     = Color(42, 195, 108),
    success_hover= Color(36, 168, 92),
    
    anim_speed  = 10,
    slide_speed = 8,
    entry_speed = 3,
    entry_delay = 0.08,
    corner_rad  = 5
}

local AR_STRUCTURE = {

    ["Performance"] = {
        ["General"] = {
            _desc = "Optimization stuff.",
            { "ar_HandsAnimation", "Enable Hands anims", "bool", nil, nil, "Enable Hands Animations for ragdolls" },
            { "ar_Expressions", "Enable Expressions anims", "bool", nil, nil, "Enable Face Expressions Animations for ragdolls" },
        }
    },

    ["Main"] = {
        ["Core"] = {
            _desc = "Main Active Ragdoll Settings",
            { "ar_enabled", "Enable Artagdoll", "bool", nil, nil, "Toggles the entire active ragdoll system on/off." },
            { "ar_enabled_players", "Enable Artagdoll for Players", "bool", nil, nil, "Toggles for players." },
            { "ar_enabled_npcs", "Enable Artagdoll for NPCs", "bool", nil, nil, "Toggles for NPCs." },
            { nil, "Ragdoll Health Settings", "separator", nil, nil, nil },
            { "sv_health_bleed_sensitivity", "Bleed Sensitivity", 0, 1, 2, "Bleed increase per damage." },
            { "sv_health_bleed_damage_mult", "Bleed Damage Multiplier", 0, 5, 2, "Health loss multiplier." },
            { "sv_health_clotting_mult", "Clotting Speed", 0, 5, 2, "Bleed stop speed." },
            { "sv_health_metab_min", "Min Metabolism", 0, 10, 1, "Min metabolism." },
            { "sv_health_metab_max", "Max Metabolism", 0, 10, 1, "Max metabolism." },
            { "sv_health_max_bleed_tick", "Max Tick Damage", 0, 100, 0, "Max HP loss per tick." },
            { nil, "Presets menu", "separator", nil, nil, nil },
        }
    },
    ["Behaviours"] = {
        ["PlayerStumble"] = {
            _desc = "Player fake-ragdoll stumble settings. NPC and other ragdolls use their own settings.",
            { "hg_euphoria_getup_stumble", "Enable Player Stumbling", "bool", nil, nil, "Enable fake-ragdoll stumbling for players." },
            { "hg_stumble_PushDuration", "Hit Push Duration", 0, 5, 2, "How long hit reactions last." },
            { "hg_stumble_PushPeakForce", "Hit Push Force", 0, 500, 0, "Force from a hit while stumbling." },
            { "hg_stumble_MaxVelocityClamp", "Step Speed Limit", 100, 2000, 0, "Limits step planning speed, not body velocity." },
            { "hg_stumble_VelocitySmoothing", "Step Smoothing", 1, 50, 0, "Smooths speed used for stepping." },
            { "hg_stumble_HipTargetHeight", "Hip Height", 10, 100, 0, "Height for brief vertical support." },
            { "hg_stumble_MaxStepUpHeight", "Max Step Up", 0, 50, 0, "Climb height." },
            { "hg_stumble_MaxStepDownHeight", "Max Step Down", 0, 150, 0, "Drop height." },
            { "hg_stumble_StepHeight", "Foot Lift Height", 0, 50, 0, "Step height." },
            { "hg_stumble_MaxSlopeAngle", "Max Slope Angle", 0, 90, 0, "Slope limit." },
            { "hg_stumble_SearchHeightBuffer", "Search Buffer", 0, 50, 0, "Ground trace offset." },
            { "hg_stumble_PredictionTime", "Step Prediction", 0, 1, 2, "Foot target prediction timing." },
            { "hg_stumble_StepTriggerForward", "Step Trigger", 1, 50, 0, "Distance before a corrective step." },
            { "hg_stumble_MinMovementSpeed", "Movement Threshold", 0, 100, 0, "Speed for moving step targets." },
            { "hg_stumble_StationaryThreshold", "Stationary Threshold", 0, 100, 0, "Speed below which feet can lock." },
            { "hg_stumble_MinStepInterval", "Step Cooldown", 0, 2, 2, "Time between steps." },
            { "hg_stumble_TimeBeforeDecay", "Time Before Decay", 0, 10, 1, "Time before falling." },
            { "hg_stumble_DecayDuration", "Decay Duration", 0, 10, 1, "Fall fade duration." },
        },
        ["Stumble"] = {
            _desc = "NPC and other ragdoll self-balance settings.",
            { nil, "Upright-force config", "separator", nil, nil, nil },
            { "ar_uprightForce", "Upright Force", 0, 1000, 0, "Force keeping ragdoll standing." },
            { "ar_HipTargetHeight", "Hip Height", 10, 100, 0, "Target hip height." },
            { "ar_MaxVelocityClamp", "Max Velocity", 100, 1000, 0, "Movement speed limit." },
            { "ar_VelocitySmoothing", "Smoothing", 1, 50, 0, "Movement interpolation." },
            { nil, "Procedural footplanting", "separator", nil, nil, nil },
            { "ar_MaxStepUpHeight", "Max Step Up", 0, 50, 0, "Climb height." },
            { "ar_MaxStepDownHeight", "Max Step Down", 0, 150, 0, "Drop height." },
            { "ar_StepHeight", "Foot Lift Height", 0, 50, 0, "Step height." },
            { "ar_MaxSlopeAngle", "Max Slope Angle", 0, 90, 0, "Slope limit." },
            { "ar_RaycastDistance", "Trace Range", 50, 500, 0, "Ground search range." },
            { "ar_SearchHeightBuffer", "Search Buffer", 0, 50, 0, "Trace offset." },
            { "ar_PredictionTime", "Step Prediction", 0, 1, 2, "Prediction timing." },
            { "ar_StepTriggerForward", "Trigger (Fwd)", 1, 50, 0, "Forward step threshold." },
            { "ar_StepTriggerSide", "Trigger (Side)", 1, 50, 0, "Side step threshold." },
            { "ar_MinStepInterval", "Step Cooldown", 0, 2, 2, "Time between steps." },
            { nil, "Decay & Foot Lock", "separator", nil, nil, nil },
            { "ar_TimeBeforeDecay", "Time Before Decay", 0, 10, 1, "Time before falling." },
            { "ar_DecayDuration", "Decay Duration", 0, 10, 1, "Fall fade duration." },
            { "ar_FootLockStrength", "Foot Lock", 0, 1, 2, "Ground adhesion." },
        },
        ["WoundGrab"] = {
            _desc = "Ragdolls hold wounds when injured.",
            { "ar_EnableWoundGrab", "Enable WoundGrab", "bool", nil, nil, "Enable wound grabbing." },
            { "ar_GrabTime", "Wound Grab Time", 0, 50, 1, "Hold duration." },
        },
        ["HeadShot"] = {
            _desc = "Headshot physics and reactions.",
            { "ar_FatalHeadshot", "Fatal Headshot", "bool", nil, nil, "Instant death on headshot." },
            { "ar_hs_death_delay", "Death Delay", 0, 10, 1, "Delay before death." },
            { "ar_headshot_force", "Impact Force", 0, 10000, 0, "Impact force." },
            { "ar_headshot_torque", "Impact Spin", 0, 5000, 0, "Rotational force." },
            { "ar_hs_limp_time", "Limp Duration", 0, 10, 2, "Limp time." },
            { "ar_hs_limp_str", "Limp Strength", 0, 10, 2, "Limp intensity." },
            { "ar_hs_stiff_time", "Stiffen Duration", 0, 5, 2, "Stiff time." },
            { "ar_hs_stiff_str", "Stiffen Strength", 0, 10, 2, "Stiff intensity." },
        },
        ["Tumble"] = {
            _desc = "Ragdolls roll down slopes.",
            { "ar_EnableTumble", "Enable Tumble", "bool", nil, nil, "Enable tumbling." },
            { "ar_TumbleSpeed", "Activation Speed", 0, 1000, 0, "Start speed." },
            { "ar_tumble_minspeed", "Stop Threshold", 0, 200, 0, "Stop speed." },
            { "ar_tumble_torque", "Roll Torque", 0, 10000, 0, "Rolling force." },
            { "ar_tumble_lift", "Bounce Factor", 0, 2, 2, "Bounciness." },
            { "ar_tumble_chaos", "Chaos", 0, 3, 2, "Randomness." },
        },
        ["HoldEnvironement"] = {
            _desc = "Ragdolls grab surfaces falling.",
            { "ar_enableHoldEnv", "Enable HoldEnv", "bool", nil, nil, "Enable grabbing." },
            { "ar_holdenv_search_radius", "Search Radius", 0, 25, 0, "Search range." },
            { "ar_holdenv_min_dist", "Min Dist", 0, 17, 0, "Closest distance." },
            { "ar_holdenv_max_dist", "Max Dist", 0, 25, 0, "Furthest distance." },
            { "ar_holdenv_release_vel", "Release Vel", 0, 1000, 0, "Grip break speed." },
            { "ar_holdenv_min_hold", "Min Hold", 0, 10, 0, "Min duration." },
            { "ar_holdenv_max_hold", "Max Hold", 0, 10, 0, "Max duration." },
            { "ar_holdenv_cooldown", "Cooldown", 0, 12, 0, "Grab cooldown." },
            { "ar_holdenv_max_grabs", "Max Grabs", 0, 4, 0, "Consecutive grabs." }, 
        },
        ["Crawling"] = {
            _desc = "Ragdolls crawl when dying.",
            { "ar_enableCrawling", "Enable Crawling", "bool", nil, nil, "Enable crawling." },
        },
        ["Burning"] = {
            _desc = "Burning behavior.",
            { "burn_calf_force", "Leg Kick", 0, 1000, 0, "Leg thrash force." },
            { "burn_arm_force", "Arm Flail", 0, 1000, 0, "Arm thrash force." },
            { "burn_strength", "Burn Strength", 0, 1000, 0, "Overall intensity." },
        }
    }
}

local AR_DefaultPresets = {
["Realistic"] = {
        cvars = {
            ar_holdenv_min_dist = 5,
            sv_health_bleed_damage_mult = 1,
            sv_health_metab_max = 5,
            ar_HipTargetHeight = 40,
            sv_health_metab_min = 2,
            ar_enabled_npcs = 1,
            ar_TumbleSpeed = 45,
            ar_EnableTumble = 1,
            sv_health_bleed_sensitivity = 0.15,
            burn_calf_force = 100,
            ar_GrabTime = 5,
            sv_health_clotting_mult = 1,
            ar_enabled = 1,
            ar_enabled_players = 1,
            ar_EnableWoundGrab = 1,
            burn_arm_force = 57,
            ar_VelocitySmoothing = 15,
            ar_hs_stiff_str = 4,
            ar_hs_stiff_time = 0.65,
            ar_hs_limp_str = 1.5,
            ar_enableHoldEnv = 1,
            ar_PredictionTime = 0.39,
            ar_headshot_torque = 1500,
            ar_TimeBeforeDecay = 1.5,
            ar_headshot_force = 3000,
            ar_StepHeight = 20,
            ar_holdenv_release_vel = 200,
            ar_holdenv_cooldown = 3,
            ar_tumble_chaos = 1,
            ar_MaxStepDownHeight = 20,
            ar_MaxSlopeAngle = 45,
            ar_hs_death_delay = 4,
            ar_FatalHeadshot = 1,
            ar_uprightForce = 245,
            ar_holdenv_max_hold = 2,
            ar_holdenv_search_radius = 15,
            ar_DecayDuration = 1.5,
            sv_health_max_bleed_tick = 50,
            ar_StepTriggerSide = 10,
            ar_StepTriggerForward = 10,
            ar_hs_limp_time = 1.8,
            ar_SearchHeightBuffer = 25,
            ar_MaxStepUpHeight = 18,
            ar_MinStepInterval = 0.45,
            burn_strength = 4,
            ar_holdenv_max_dist = 15,
            ar_enableCrawling = 1,
            ar_holdenv_min_hold = 1,
            ar_FootLockStrength = 0.28,
            hg_euphoria_getup_stumble = 1,
            hg_stumble_MaxVelocityClamp = 408,
            hg_stumble_VelocitySmoothing = 15,
            hg_stumble_HipTargetHeight = 40,
            hg_stumble_MaxStepDownHeight = 20,
            hg_stumble_StepHeight = 20,
            hg_stumble_MaxSlopeAngle = 45,
            hg_stumble_SearchHeightBuffer = 25,
            hg_stumble_PredictionTime = 0.39,
            hg_stumble_StepTriggerForward = 10,
            hg_stumble_MinStepInterval = 0.45,
            hg_stumble_TimeBeforeDecay = 1.5,
            hg_stumble_DecayDuration = 1.5,
            hg_stumble_MaxStepUpHeight = 18,
            ar_tumble_lift = 0.5,
            ar_tumble_minspeed = 35,
            ar_RaycastDistance = 200,
            ar_holdenv_max_grabs = 2,
            ar_tumble_torque = 5000,
            ar_MaxVelocityClamp = 408
        },
        isDefault = true,
        desc = "Realistic Stumbling and physics."
    }
}

local AR_Presets = {}
local PRESET_FILE = "artagdoll/presets.txt"

local function SavePresetsToFile()
    if not file.Exists("artagdoll", "DATA") then
        file.CreateDir("artagdoll")
    end
    
    local toSave = {}
    for name, data in pairs(AR_Presets) do
        if not data.isDefault then
            toSave[name] = data
        end
    end
    
    file.Write(PRESET_FILE, util.TableToJSON(toSave, true))
end

local function LoadPresetsFromFile()
    AR_Presets = table.Copy(AR_DefaultPresets)
    
    if file.Exists(PRESET_FILE, "DATA") then
        local content = file.Read(PRESET_FILE, "DATA")
        if content then
            local decoded = util.JSONToTable(content)
            if decoded then
                for name, data in pairs(decoded) do
                    AR_Presets[name] = data
                end
            end
        end
    end
end

local function SendChange(cvar, value)
    timer.Simple(0, function()
        if net then
            net.Start("change_setting")
            net.WriteString(cvar)
            net.WriteFloat(value)
            net.SendToServer()
        end
    end)
end

local function GetAllCVars()
    local cvars = {}
    for _, settings in pairs(AR_STRUCTURE) do
        for _, subcatData in pairs(settings) do
            if type(subcatData) == "table" then
                for _, s in ipairs(subcatData) do
                    if s[1] then
                        local cvar = GetConVar(s[1])
                        if cvar then cvars[s[1]] = cvar:GetFloat() end
                    end
                end
            end
        end
    end
    return cvars
end

local function SavePreset(presetName)
    if not presetName or presetName == "" then
        notification.AddLegacy("Preset name can't be empty", NOTIFY_ERROR, 3)
        return false
    end
    
    if AR_Presets[presetName] and AR_Presets[presetName].isDefault then
        notification.AddLegacy("Cannot overwrite default preset!", NOTIFY_ERROR, 3)
        return false
    end

    AR_Presets[presetName] = {
        cvars = GetAllCVars(),
        date = os.date("%Y-%m-%d %H:%M:%S")
    }
    SavePresetsToFile()
    notification.AddLegacy("Saved preset: " .. presetName, NOTIFY_GENERIC, 3)
    surface.PlaySound("garrysmod/save_load1.wav")
    return true
end

local function ImportPreset(jsonString)
    if not jsonString or jsonString == "" then return false end
    
    local decoded = util.JSONToTable(jsonString)
    if not decoded then 
        notification.AddLegacy("Invalid JSON string!", NOTIFY_ERROR, 3)
        return false 
    end
    
    local count = 0
    for name, data in pairs(decoded) do
        local cvars = data.cvars or data
        
        if cvars["ar_enabled"] or cvars["ar_uprightForce"] or cvars["ar_enable"] then
            local mappedCVars = {}
            for k, v in pairs(cvars) do
                local newK = k
                if k == "ar_enable" then newK = "ar_enabled" end
                if k == "ar_enableWoundGrab" then newK = "ar_EnableWoundGrab" end
                if k == "ar_WoundGrabTime" then newK = "ar_GrabTime" end
                if k == "ar_enableHeadShotReact" then newK = "ar_FatalHeadshot" end
                if k == "ar_enableWallStunt" then newK = "ar_enableHoldEnv" end
                
                if GetConVar(newK) then
                    mappedCVars[newK] = v
                end
            end
            
            AR_Presets[name] = {
                cvars = mappedCVars,
                date = os.date("%Y-%m-%d %H:%M:%S"),
                imported = true
            }
            count = count + 1
        end
    end
    
    if count > 0 then
        SavePresetsToFile()
        notification.AddLegacy("Imported " .. count .. " presets.", NOTIFY_GENERIC, 3)
        surface.PlaySound("garrysmod/save_load1.wav")
        return true
    else
        notification.AddLegacy("No valid presets found in JSON.", NOTIFY_ERROR, 3)
        return false
    end
end

local function LoadPreset(presetName)
    if not AR_Presets[presetName] then return false end
    local preset = AR_Presets[presetName]
    
    local loadedCount = 0
    for cvar, value in pairs(preset.cvars) do
        if GetConVar(cvar) then
            RunConsoleCommand(cvar, tostring(value))
            SendChange(cvar, value)
            loadedCount = loadedCount + 1
        end
    end
    
    notification.AddLegacy("Loaded: " .. presetName, NOTIFY_GENERIC, 3)
    surface.PlaySound("garrysmod/save_load2.wav")
    
    timer.Simple(0.1, function() RunConsoleCommand("spawnmenu_reload") end)
    return true
end

local function DeletePreset(presetName)
    if AR_Presets[presetName] then
        if AR_Presets[presetName].isDefault then
            notification.AddLegacy("Cannot delete default preset!", NOTIFY_ERROR, 3)
            return false
        end
        
        AR_Presets[presetName] = nil
        SavePresetsToFile()
        notification.AddLegacy("Deleted: " .. presetName, NOTIFY_GENERIC, 3)
        surface.PlaySound("buttons/button14.wav")
        return true
    end
    return false
end

LoadPresetsFromFile()

local function LerpColor(delta, from, to)
    return Color(
        Lerp(delta, from.r, to.r),
        Lerp(delta, from.g, to.g),
        Lerp(delta, from.b, to.b),
        Lerp(delta, from.a, to.a)
    )
end

local function smoothstep(x)
    return x * x * (3 - 2 * x)
end

local function WrapText(text, font, maxWidth)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines = {}
    local currentLine = ""
    local _, h = surface.GetTextSize("W")
    
    for _, word in ipairs(words) do
        local testLine = currentLine == "" and word or (currentLine .. " " .. word)
        local tw = surface.GetTextSize(testLine)
        if tw > maxWidth then
            table.insert(lines, currentLine)
            currentLine = word
        else
            currentLine = testLine
        end
    end
    table.insert(lines, currentLine)
    return lines, #lines * h
end

local function CreateHeader(text, index)
    local header = vgui.Create("DPanel")
    header:SetTall(36)
    header:Dock(TOP)
    header:DockMargin(6, index == 1 and 8 or 18, 6, 6)
    local spawnTime = SysTime()
    local delay = index * Theme.entry_delay
    header.Paint = function(self, w, h)
        local progress = math.Clamp((SysTime() - spawnTime - delay) * Theme.entry_speed, 0, 1)
        progress = smoothstep(progress)
        local xOffset = (1 - progress) * -30
        surface.SetAlphaMultiplier(progress)
        draw.RoundedBox(3, xOffset, 0, 3, h, Theme.accent)
        draw.SimpleText(text, "DermaLarge", 14 + xOffset, h/2, Theme.text_main, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetAlphaMultiplier(1)
    end
    return header
end

local function CreateDescription(text, index)
    local desc = vgui.Create("DPanel")
    desc:Dock(TOP)
    desc:DockMargin(14, 0, 14, 10)
    local spawnTime = SysTime()
    local delay = index * Theme.entry_delay
    local lines, textH = WrapText(text, "DermaDefault", 300)
    desc.Paint = function(self, w, h)
        local progress = math.Clamp((SysTime() - spawnTime - delay) * Theme.entry_speed, 0, 1)
        progress = smoothstep(progress)
        local xOffset = (1 - progress) * 15
        surface.SetAlphaMultiplier(progress)
        draw.RoundedBox(Theme.corner_rad, xOffset, 0, w, h, Color(Theme.accent.r, Theme.accent.g, Theme.accent.b, 15))
        surface.SetDrawColor(Theme.accent.r, Theme.accent.g, Theme.accent.b, 80)
        surface.DrawRect(xOffset, 0, 2, h)
        for i, line in ipairs(lines) do
            draw.SimpleText(line, "DermaDefault", 10 + xOffset, 8 + (i-1)*15, Theme.text_desc)
        end
        surface.SetAlphaMultiplier(1)
    end
    desc.PerformLayout = function(self, w)
        lines, textH = WrapText(text, "DermaDefault", w - 24)
        self:SetTall(textH + 16)
    end
    return desc
end

local function CreatePresetManager()
    local presetPanel = vgui.Create("DPanel")
    presetPanel:Dock(TOP)
    presetPanel:DockMargin(6, 6, 6, 6)
    presetPanel:SetTall(270)
    
    local spawnTime = SysTime()
    presetPanel.Paint = function(self, w, h)
        local progress = math.Clamp((SysTime() - spawnTime) * Theme.entry_speed, 0, 1)
        progress = smoothstep(progress)
        surface.SetAlphaMultiplier(progress)
        draw.RoundedBox(Theme.corner_rad, 0, 0, w, h, Theme.card)
        draw.SimpleText("Presets", "DermaDefaultBold", 12, 12, Theme.text_main)
        surface.SetAlphaMultiplier(1)
    end
    
    local listPanel = vgui.Create("DPanel", presetPanel)
    listPanel:Dock(TOP)
    listPanel:DockMargin(10, 38, 10, 10)
    listPanel:SetTall(120)
    listPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Theme.bg)
    end
    
    local presetList = vgui.Create("DListView", listPanel)
    presetList:Dock(FILL)
    presetList:SetMultiSelect(false)
    presetList:AddColumn("Name")
    presetList:AddColumn("Type")
    
    for _, col in pairs(presetList.Columns) do
        col.Header:SetTextColor(Color(255, 255, 255)) 
    end

    presetList.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Theme.bg)
    end
    
    timer.Simple(0, function() if IsValid(presetList) then presetList:FixColumnsLayout() end end)
    
    presetList.OnRowSelected = function(panel, index, row)
        presetPanel.selectedPreset = row:GetValue(1)
    end
    
    local function RefreshList()
        presetList:Clear()
        for name, data in pairs(AR_Presets) do
            local typeStr = data.isDefault and "Default" or "User"
            local line = presetList:AddLine(name, typeStr)
            
            for _, col in pairs(line.Columns) do
                col:SetTextColor(Theme.text_main)
            end

            if data.isDefault then
                line.Paint = function(self, w, h)
                    if self:IsSelected() then draw.RoundedBox(0,0,0,w,h,Theme.accent) 
                    else draw.RoundedBox(0,0,0,w,h, Color(Theme.bg.r+10, Theme.bg.g+10, Theme.bg.b+10)) end
                end
            end
        end
    end
    RefreshList()
    
    local buttonContainer = vgui.Create("DPanel", presetPanel)
    buttonContainer:Dock(TOP)
    buttonContainer:DockMargin(10, 0, 10, 0)
    buttonContainer:SetTall(70)
    buttonContainer.Paint = function() end
    
    local row1 = vgui.Create("DPanel", buttonContainer)
    row1:Dock(TOP)
    row1:SetTall(30)
    row1.Paint = function() end

    local row2 = vgui.Create("DPanel", buttonContainer)
    row2:Dock(TOP)
    row2:SetTall(30)
    row2:DockMargin(0, 5, 0, 0)
    row2.Paint = function() end
    
    local function StyleButton(btn, color, hoverColor)
        btn:SetTextColor(Theme.text_main)
        btn.targetColor = color
        btn.currentColor = color
        btn.Paint = function(self, w, h)
            local hover = self:IsHovered()
            local pressed = self:IsDown()
            self.targetColor = pressed and Color(color.r * 0.7, color.g * 0.7, color.b * 0.7) or (hover and hoverColor or color)
            self.currentColor = LerpColor(FrameTime() * Theme.anim_speed, self.currentColor, self.targetColor)
            draw.RoundedBox(Theme.corner_rad, 0, 0, w, h, self.currentColor)
        end
    end

    local saveBtn = vgui.Create("DButton", row1)
    saveBtn:Dock(LEFT)
    saveBtn:SetWide(135)
    saveBtn:SetText("Save Preset")
    StyleButton(saveBtn, Theme.success, Theme.success_hover)
    saveBtn.DoClick = function()
        Derma_StringRequest("Save Preset", "Name:", "", function(name)
            if SavePreset(name) then RefreshList() end
        end)
    end
    
    local loadBtn = vgui.Create("DButton", row1)
    loadBtn:Dock(FILL)
    loadBtn:DockMargin(5, 0, 0, 0)
    loadBtn:SetText("Load Preset")
    StyleButton(loadBtn, Theme.accent, Color(85, 175, 220))
    loadBtn.DoClick = function()
        if presetPanel.selectedPreset then LoadPreset(presetPanel.selectedPreset) end
    end
    
    local importBtn = vgui.Create("DButton", row2)
    importBtn:Dock(LEFT)
    importBtn:SetWide(135)
    importBtn:SetText("Import JSON")
    StyleButton(importBtn, Color(200, 150, 50), Color(220, 170, 70))
    importBtn.DoClick = function()
        Derma_StringRequest("Import Preset", "Paste JSON code here:", "", function(json)
            if ImportPreset(json) then RefreshList() end
        end)
    end
    
    local deleteBtn = vgui.Create("DButton", row2)
    deleteBtn:Dock(FILL)
    deleteBtn:DockMargin(5, 0, 0, 0)
    deleteBtn:SetText("Delete")
    StyleButton(deleteBtn, Theme.danger, Theme.danger_hover)
    deleteBtn.DoClick = function()
        if presetPanel.selectedPreset then
            if AR_Presets[presetPanel.selectedPreset].isDefault then
                notification.AddLegacy("Default presets cannot be deleted.", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button10.wav")
                return
            end
            Derma_Query("Delete this preset?", "Confirm", "Yes", function()
                if DeletePreset(presetPanel.selectedPreset) then RefreshList() end
            end, "No")
        end
    end
    
    return presetPanel
end

local function BuildPanel(panel, data)
    if not data then return end
    panel:ClearControls()
    
    local elementIndex = 0

    panel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Theme.bg_overlay)
    end

    for categoryName, settings in pairs(data) do
        if categoryName ~= "Core" then
            elementIndex = elementIndex + 1
            panel:AddItem(CreateHeader(categoryName, elementIndex))
        end
        
        if settings._desc then
            elementIndex = elementIndex + 1
            panel:AddItem(CreateDescription(settings._desc, elementIndex))
        end

        for _, setting in ipairs(settings) do
            elementIndex = elementIndex + 1
            
            local cvarName = setting[1]
            local label = setting[2]
            local settingType = setting[3]
            local desc = setting[6]
            
            local spawnTime = SysTime()
            local delay = elementIndex * Theme.entry_delay

            if settingType == "separator" then
                local sep = vgui.Create("DPanel")
                sep:Dock(TOP)
                sep:SetTall(30)
                sep:DockMargin(6, 10, 6, 0)
                
                sep.Paint = function(self, w, h)
                    local progress = math.Clamp((SysTime() - spawnTime - delay) * Theme.entry_speed, 0, 1)
                    progress = smoothstep(progress)
                    surface.SetAlphaMultiplier(progress)

                    draw.SimpleText(label, "DermaDefaultBold", 6, h-10, Theme.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    
                    surface.SetDrawColor(Theme.slider_line)
                    surface.DrawLine(6, h-2, w-6, h-2)

                    surface.SetAlphaMultiplier(1)
                end
                panel:AddItem(sep)
            
            elseif settingType == "bool" then
                local toggle = vgui.Create("DButton")
                toggle:SetText("")
                toggle:Dock(TOP)
                toggle:DockMargin(6, 3, 6, 3)
                
                local cv = GetConVar(cvarName)
                toggle.state = cv and cv:GetBool() or false
                toggle.animValue = toggle.state and 1 or 0
                toggle.cardColor = Theme.card
                toggle.hoverAmt = 0
                
                toggle.Think = function(self)
                    if not cv then cv = GetConVar(cvarName) return end
                    local cur = cv:GetBool()
                    if self.state ~= cur then
                        self.state = cur
                    end
                end

                local descLines, descH = WrapText(desc or "", "DermaDefault", 300)
                
                toggle.Paint = function(self, w, h)
                    local progress = math.Clamp((SysTime() - spawnTime - delay) * Theme.entry_speed, 0, 1)
                    progress = smoothstep(progress)
                    self.hoverAmt = Lerp(FrameTime() * Theme.slide_speed, self.hoverAmt, self:IsHovered() and 1 or 0)
                    local xOffset = ((1 - progress) * -40) + (self.hoverAmt * 4)
                    surface.SetAlphaMultiplier(progress)
                    self.cardColor = LerpColor(FrameTime() * Theme.anim_speed, self.cardColor, self:IsHovered() and Theme.card_hover or Theme.card)
                    draw.RoundedBox(Theme.corner_rad, xOffset, 0, w, h, self.cardColor)
                    self.animValue = Lerp(FrameTime() * 7, self.animValue, self.state and 1 or 0)
                    local switchW, switchH = 38, 20
                    local switchX = xOffset + w - switchW - 10
                    local switchY = 10
                    local bgColor = LerpColor(self.animValue, Theme.toggle_off, Theme.toggle_on)
                    draw.RoundedBox(switchH/2, switchX, switchY, switchW, switchH, bgColor)
                    local knobPos = 2 + ((switchW - 18) * self.animValue)
                    draw.RoundedBox(8, switchX + knobPos, switchY + 2, 16, 16, Theme.toggle_knob)
                    draw.SimpleText(label, "DermaDefaultBold", xOffset + 10, 10 + switchH/2, Theme.text_main, 0, 1)
                    if desc then
                        for i, line in ipairs(descLines) do
                            draw.SimpleText(line, "DermaDefault", xOffset + 10, 36 + (i-1)*15, Theme.text_desc)
                        end
                    end
                    surface.SetAlphaMultiplier(1)
                end
                
                toggle.DoClick = function(self)
                    self.state = not self.state
                    local val = self.state and 1 or 0
                    RunConsoleCommand(cvarName, tostring(val))
                    SendChange(cvarName, val)
                    surface.PlaySound("garrysmod/ui_click.wav")
                end
                
                toggle.PerformLayout = function(self, w)
                    if desc then
                        descLines, descH = WrapText(desc, "DermaDefault", w - 20)
                        self:SetTall(38 + descH + 6)
                    else
                        self:SetTall(40)
                    end
                end
                panel:AddItem(toggle)

            else
                local min, max, decimals = setting[3], setting[4], setting[5]
                local sliderPanel = vgui.Create("DPanel")
                sliderPanel:Dock(TOP)
                sliderPanel:DockMargin(6, 3, 6, 3)
                sliderPanel.cardColor = Theme.card
                sliderPanel.hoverAmt = 0
                
                local descLines, descH = WrapText(desc or "", "DermaDefault", 300)
                local slider = vgui.Create("DNumSlider", sliderPanel)
                slider:SetMin(min)
                slider:SetMax(max)
                slider:SetDecimals(decimals or 0)
                slider:SetConVar(cvarName)
                
                local cv = GetConVar(cvarName)
                slider:SetValue(cv and cv:GetFloat() or 0)

                slider.Think = function(self)
                    if not cv then cv = GetConVar(cvarName) return end
                    local cur = cv:GetFloat()
                    if not self:IsEditing() and math.abs(self:GetValue() - cur) > 0.001 then
                        self:SetValue(cur)
                    end
                end
                
                if slider.Label then slider.Label:SetVisible(false) end
                if slider.TextArea then
                    slider.TextArea:SetTextColor(Theme.text_main)
                    slider.TextArea.Paint = function(s, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Theme.text_box_bg)
                        s:DrawTextEntryText(Theme.text_main, Theme.accent, Theme.text_main)
                    end
                end
                
                slider.OnValueChanged = function(_, val)
                    SendChange(cvarName, val)
                end
                
                sliderPanel.Paint = function(self, w, h)
                    local progress = math.Clamp((SysTime() - spawnTime - delay) * Theme.entry_speed, 0, 1)
                    progress = smoothstep(progress)
                    self.hoverAmt = Lerp(FrameTime() * Theme.slide_speed, self.hoverAmt, self:IsHovered() and 1 or 0)
                    local xOffset = ((1 - progress) * -40) + (self.hoverAmt * 4)
                    surface.SetAlphaMultiplier(progress)
                    self.cardColor = LerpColor(FrameTime() * Theme.anim_speed, self.cardColor, self:IsHovered() and Theme.card_hover or Theme.card)
                    draw.RoundedBox(Theme.corner_rad, xOffset, 0, w, h, self.cardColor)
                    draw.SimpleText(label, "DermaDefaultBold", xOffset + 10, 14, Theme.text_main, 0, 1)
                    local yPos = 28
                    if desc then
                        for _, line in ipairs(descLines) do
                            draw.SimpleText(line, "DermaDefault", xOffset + 10, yPos, Theme.text_desc)
                            yPos = yPos + 15
                        end
                        yPos = yPos + 4
                    end
                    if IsValid(slider) then
                        slider:SetPos(xOffset + 5, yPos)
                        slider:SetWide(w - 12)
                        slider:SetTall(22)
                    end
                    surface.SetAlphaMultiplier(1)
                end
                
                sliderPanel.PerformLayout = function(self, w)
                    if desc then
                        descLines, descH = WrapText(desc, "DermaDefault", w - 20)
                        self:SetTall(28 + descH + 32)
                    else
                        self:SetTall(56)
                    end
                end
                panel:AddItem(sliderPanel)
            end
        end
    end
end

local function BuildCreditsPanel(panel)
    panel:ClearControls()
    
    panel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Theme.bg_overlay)
    end

    panel:AddItem(CreateHeader("About Artagdoll", 1))
    
    local aboutText = "Artagdoll upgrades the ragdoll physics and make them behave with realism. Inspired by Euphoria Engine (as seen in Rockstar Games). For info: the mod was made in 2 years by 1 guy !"
    panel:AddItem(CreateDescription(aboutText, 2))
    
    panel:AddItem(CreateHeader("Credits", 3))

    local creditsCard = vgui.Create("DPanel")
    creditsCard:Dock(TOP)
    creditsCard:DockMargin(6, 3, 6, 3)
    
    local credits = {
        { role = "Main Dev of Artagdoll:", name = "Idk.mdl" },
        { role = "UI Design:", name = "Idk.mdl, mister.bingler for the help!" },
        { role = "Special Thanks:", name = "The GMod Community" }
    }
    
    local spawnTime = SysTime()
    
    creditsCard.PerformLayout = function(self, w)
        local padding = 15
        local y = padding
        surface.SetFont("DermaDefaultBold")
        local _, lineH = surface.GetTextSize("W")
        
        for _, data in ipairs(credits) do
            local _, textH = WrapText(data.name, "DermaDefault", w - (padding * 2))
            y = y + lineH + textH + 10
        end
        self:SetTall(y + 5)
    end

    creditsCard.Paint = function(self, w, h)
        local progress = math.Clamp((SysTime() - spawnTime - (4 * Theme.entry_delay)) * Theme.entry_speed, 0, 1)
        progress = smoothstep(progress)
        surface.SetAlphaMultiplier(progress)

        draw.RoundedBox(Theme.corner_rad, 0, 0, w, h, Theme.card)
        
        local x = 15
        local y = 15
        
        for _, data in ipairs(credits) do
            draw.SimpleText(data.role, "DermaDefaultBold", x, y, Theme.accent)
            surface.SetFont("DermaDefaultBold")
            local _, titleH = surface.GetTextSize(data.role)
            y = y + titleH + 2
            
            local lines, textH = WrapText(data.name, "DermaDefault", w - 30)
            for i, line in ipairs(lines) do
                draw.SimpleText(line, "DermaDefault", x, y + ((i-1) * 15), Theme.text_main)
            end
            
            y = y + textH + 10
        end

        surface.SetAlphaMultiplier(1)
    end
    
    panel:AddItem(creditsCard)
end

hook.Add("PopulateToolMenu", "AR_Menu", function()
    spawnmenu.AddToolTab("AR_Tab", "Artagdoll", "icon16/user_suit.png")

    spawnmenu.AddToolMenuOption("AR_Tab", "Main", "AR_Main", "Settings", "", "", function(panel)
        BuildPanel(panel, AR_STRUCTURE["Main"])
        panel:AddItem(CreatePresetManager())
        
        local resetBtn = vgui.Create("DButton")
        resetBtn:SetText("Reset to Defaults")
        resetBtn:Dock(TOP)
        resetBtn:DockMargin(10, 28, 10, 10)
        resetBtn:SetTall(40)
        resetBtn:SetTextColor(Theme.text_main)
        resetBtn:SetFont("DermaDefaultBold")
        resetBtn.targetColor = Theme.danger
        resetBtn.currentColor = Theme.danger
        resetBtn.hoverAmt = 0
        
        local spawnTime = SysTime()
        resetBtn.Paint = function(self, w, h)
            local progress = math.Clamp((SysTime() - spawnTime - 0.5) * Theme.entry_speed, 0, 1)
            progress = smoothstep(progress)
            
            self.hoverAmt = Lerp(FrameTime() * 9, self.hoverAmt, self:IsHovered() and 1 or 0)
            self.targetColor = self:IsHovered() and Theme.danger_hover or Theme.danger
            self.currentColor = LerpColor(FrameTime() * Theme.anim_speed, self.currentColor, self.targetColor)
            
            surface.SetAlphaMultiplier(progress)
            draw.RoundedBox(Theme.corner_rad, self.hoverAmt * 3, 0, w, h, self.currentColor)
            surface.SetAlphaMultiplier(1)
        end
        
        resetBtn.DoClick = function()
            Derma_Query("Reset all settings to default?", "Confirm", "Yes", function()
                timer.Simple(0, function()
                    if net then
                        net.Start("ar_reset_defaults")
                        net.SendToServer()
                    end
                end)
            end, "No")
        end
        
        panel:AddItem(resetBtn)
    end)

    local behaviorMenus = {
        { id = "AR_PlayerStumble", name = "Player Stumbling", key = "PlayerStumble" },
        { id = "AR_Stumble", name = "NPC / Other Ragdoll Stumbling", key = "Stumble" },
        { id = "AR_WoundGrab", name = "Wound Grab", key = "WoundGrab" },
        { id = "AR_Headshots", name = "Headshots", key = "HeadShot" },
        { id = "AR_Tumble", name = "Tumble", key = "Tumble" },
        { id = "AR_HoldEnv", name = "Hold Environment", key = "HoldEnvironement" },
        { id = "AR_Crawling", name = "Crawling", key = "Crawling" },
        { id = "AR_Burning", name = "Burning", key = "Burning" },
    }

    for _, menu in ipairs(behaviorMenus) do
        spawnmenu.AddToolMenuOption("AR_Tab", "Behaviours", menu.id, menu.name, "", "", function(panel)
            BuildPanel(panel, { [menu.key] = AR_STRUCTURE["Behaviours"][menu.key] })
        end)
    end

    spawnmenu.AddToolMenuOption("AR_Tab", "Main", "AR_Performance", "Performance", "", "", function(panel)
        BuildPanel(panel, AR_STRUCTURE["Performance"])
    end)

    spawnmenu.AddToolMenuOption("AR_Tab", "Main", "AR_Credits", "Credits", "", "", function(panel)
        BuildCreditsPanel(panel)
    end)
end)
