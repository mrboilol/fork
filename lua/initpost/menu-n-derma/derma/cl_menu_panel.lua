local PANEL = {}
local curent_panel 
local red_select = Color(192,0,0)
local menu_music_path = "sound/rem_mainmenu.mp3"
local menu_music_flags = "noblock noplay"
local menu_music_volume = 0.25
local menu_music_station


local function StopMainMenuMusic()
    if menu_music_station then
        menu_music_station:Stop()
        menu_music_station = nil
    end
end

local function StartMainMenuMusic(owner)
    StopMainMenuMusic()
    sound.PlayFile(menu_music_path, menu_music_flags, function(station)
        if not station then return end
        if not IsValid(owner) or MainMenu ~= owner then
            station:Stop()
            return
        end

        menu_music_station = station
        station:EnableLooping(true)
        station:SetVolume(menu_music_volume)
        station:Play()
    end)
end

local function MenuUnit(num)
    return math.floor(num * math.min(ScrW(), ScrH()) / 1000)
end

local Selects = {
    {Title = "Disconnect", BypassTransition = true, Func = function(luaMenu) luaMenu:PlayDisconnectCutscene() end},
    {Title = "Main Menu", Func = function(luaMenu) gui.ActivateGameUI() luaMenu:Close() end},
    {Title = "Discord", Func = function(luaMenu) luaMenu:Close() gui.OpenURL(DISCORD_URL)  end},
    {Title = "Traitor Role",
    GamemodeOnly = true,
    CreatedFunc = function(self, parent, luaMenu)
        local btnSOE = vgui.Create( "DLabel", self )
        btnSOE:SetText( "###" )
        btnSOE:SetMouseInputEnabled( true )
        btnSOE:SizeToContents()
        btnSOE:SetFont( "ZCity_Small" )
        btnSOE:SetTall( MenuUnit(42) )
        btnSOE:Dock(BOTTOM)
        btnSOE:DockMargin(MenuUnit(20),MenuUnit(10),0,0)
        btnSOE:SetTextColor(Color(255,255,255))
        btnSOE:InvalidateParent()
        btnSOE.RColor = Color(225, 225, 225, 255)
        btnSOE.x = btnSOE:GetX()
        btnSOE.OpenTime = CurTime()
        btnSOE.LineLerp = 0
        btnSOE.strTitle = "SOE"

        function btnSOE:DoClick()
            luaMenu:Close()
            hg.SelectPlayerRole(nil, "soe")
        end
    
        local selfa = self
        function btnSOE:Think()
            local isHovered = self:IsHovered()
            self.LineLerp = LerpFT(0.2, self.LineLerp or 0, isHovered and 1 or 0)
                
            self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, isHovered and 1 or 0)
            self:SetX(self.x + ScreenScaleH(40) + self.HoverLerp * ScreenScaleH(50))

            local elapsed = CurTime() - self.OpenTime
            local charsToShow = math.floor(elapsed * 15)
            local targetText = self.strTitle
            local len = #targetText
            if charsToShow > len then charsToShow = len end
            local ntxt = ""
            for i = 1, len do
                if i <= charsToShow then
                    ntxt = ntxt .. targetText:sub(i, i)
                else
                    ntxt = ntxt .. "#"
                end
            end
            if self:GetText() ~= ntxt then
                self:SetText(ntxt)
                self:SizeToContents()
            end
        end

        function btnSOE:Paint(w, h)
            local isHovered = self:IsHovered()
            local flash = isHovered and (0.5 + 0.5 * math.sin(CurTime() * 10)) or 0
            
            local textColor = self.RColor
            local outlineColor = Color(0, 0, 0, 255)

            if isHovered then
                local v = flash * 255
                textColor = Color(v, v, v, 255)
                local inv = 255 - v
                outlineColor = Color(inv, inv, inv, 255)
            end

            surface.SetFont(self:GetFont())
            local tw, th = surface.GetTextSize(self:GetText())
            
            draw.SimpleTextOutlined(self:GetText(), self:GetFont(), 0, h / 2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, outlineColor)

            if self.LineLerp and self.LineLerp > 0.01 then
                surface.SetDrawColor(255, 255, 255, 255 * self.LineLerp)
                surface.DrawRect(0, h / 2 + th / 2, tw * self.LineLerp, math.max(1, MenuUnit(1)))
            end
            return true
        end

        local btnSTD = vgui.Create( "DLabel", btnSOE )
        btnSTD:SetText( "###" )
        btnSTD:SetMouseInputEnabled( true )
        btnSTD:SizeToContents()
        btnSTD:SetFont( "ZCity_Small" )
        btnSTD:SetTall( MenuUnit(42) )
        btnSTD:Dock(BOTTOM)
        btnSTD:DockMargin(0,MenuUnit(2),0,0)
        btnSTD:SetTextColor(Color(255,255,255))
        btnSTD:InvalidateParent()
        btnSTD.RColor = Color(225, 225, 225, 255)
        btnSTD.x = btnSTD:GetX()
        btnSTD.OpenTime = CurTime()
        btnSTD.LineLerp = 0
        btnSTD.strTitle = "STD"

        function btnSTD:DoClick()
            luaMenu:Close()
            hg.SelectPlayerRole(nil, "standard")
        end
    
        function btnSTD:Think()
            local isHovered = self:IsHovered()
            self.LineLerp = LerpFT(0.2, self.LineLerp or 0, isHovered and 1 or 0)
    
            self:SetX(self.x + ScreenScaleH(35))

            local elapsed = CurTime() - self.OpenTime
            local charsToShow = math.floor(elapsed * 15)
            local targetText = self.strTitle
            local len = #targetText
            if charsToShow > len then charsToShow = len end
            local ntxt = ""
            for i = 1, len do
                if i <= charsToShow then
                    ntxt = ntxt .. targetText:sub(i, i)
                else
                    ntxt = ntxt .. "#"
                end
            end
            if self:GetText() ~= ntxt then
                self:SetText(ntxt)
                self:SizeToContents()
            end
        end

        function btnSTD:Paint(w, h)
            local isHovered = self:IsHovered()
            local flash = isHovered and (0.5 + 0.5 * math.sin(CurTime() * 10)) or 0
            
            local textColor = self.RColor
            local outlineColor = Color(0, 0, 0, 255)

            if isHovered then
                local v = flash * 255
                textColor = Color(v, v, v, 255)
                local inv = 255 - v
                outlineColor = Color(inv, inv, inv, 255)
            end

            surface.SetFont(self:GetFont())
            local tw, th = surface.GetTextSize(self:GetText())
            
            draw.SimpleTextOutlined(self:GetText(), self:GetFont(), 0, h / 2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, outlineColor)

            if self.LineLerp and self.LineLerp > 0.01 then
                surface.SetDrawColor(255, 255, 255, 255 * self.LineLerp)
                surface.DrawRect(0, h / 2 + th / 2, tw * self.LineLerp, math.max(1, MenuUnit(1)))
            end
            return true
        end



        timer.Simple(2.5, function()

            RunConsoleCommand("disconnect")

        end)

    end},

}


--print(string.upper('I wish you good health, Jason Statham'))
surface.CreateFont("ZC_MM_Title", {
    font = "Verily Serif Mono",
    size = ScreenScale(40),
    weight = 800,
    antialias = true

})



surface.CreateFont("ZC_MM_Title", {

    font = "JMH Typewriter",

    size = ScreenScaleH(40),

    weight = 800,

    antialias = true

})

-- local Title = markup.Parse("error")



local Pluv = Material("pluv/pluvkid.jpg")
local LogoistMat = Material("vgui/logoist.png", "noclamp smooth")

local LogoMat = Material("vgui/logo.png")

local BgMat = Material("vgui/background.png")

local EyeMat = Material("huy.png")

local BgMat2 = Material("vgui/background2.png")

local BgMat3 = Material("vgui/background6.png")

local BgMat4 = Material("vgui/pickman.png")

local BgMat4Overlay = Material("vgui/background4.png")

local NoiseMat = Material("vgui/noisevhs")

if NoiseMat:IsError() then

    NoiseMat = Material("vgui/white")

end



local SettingsSelects = {

    -- {Title = "Master Volume", Type = "Slider", Min = 0, Max = 1, CVar = "volume"}, -- Blocked

    -- {Title = "Music Volume", Type = "Slider", Min = 0, Max = 1, CVar = "snd_musicvolume"}, -- Blocked

    -- {Title = "Sensitivity", Type = "Slider", Min = 0.1, Max = 20, CVar = "sensitivity"}, -- Blocked

    {Title = "return", Func = function(luaMenu) luaMenu:SwitchToMain() end}

}



function PANEL:InitializeMarkup()

	local mapname = game.GetMap()

	local prefix = string.find(mapname, "_")

	if prefix then

		mapname = string.sub(mapname, prefix + 1)

	end

	local gm = string.lower(gmod.GetGamemode().Name .. " | " .. string.NiceName(zb ~= nil and zb.GetRoundName or mapname))



    if hg.PluvTown.Active then

        local text = "<font=ZC_MM_Title>meleecity</font>\n<font=ZCity_Small>" .. gm .. "</font>"



        self.SelectedPluv = table.Random(hg.PluvTown.PluvMats)



        return markup.Parse(text)

    end



    local text = "<font=ZC_MM_Title>meleecity</font>\n<font=ZCity_Small>" .. gm .. "</font>"

    return markup.Parse(text)

end



local color_red = Color(90,90,95,120)

local clr_gray = Color(255,255,255,25)

local clr_verygray = Color(10,10,19,235)
local appearance_preview = {
    width = 340,
    height = 920,
    right = 0,
    top = 210,
    enter_time = 1.35,
    enter_delay = 0.35,
    exit_time = 0.7,
    exit_delay = 0.05,
    ambient = Color(0, 0, 0, 255),
    light_right = Color(115, 115, 115, 255),
    light_left = Color(85, 85, 85, 255),
    light_front = Color(92, 92, 92, 255),
    light_back = Color(0, 0, 0, 255),
    light_top = Color(55, 55, 55, 255),
    light_bottom = Color(0, 0, 0, 255),
    fov = 13,
    cam_pos = Vector(100, 0, 65),
    look_ang = Angle(11, 180, 0),
    entity_ang = Angle(0, 0, 0),
    head_yaw = -45,
    head_pitch = 0,
    head_mouse_yaw = 7,
    head_mouse_pitch = 4,
    sequence = "idle_suitcase"
}
local disconnect_cutscene = {
    ui_fade_time = 0.45,
    walk_delay = 0.08,
    walk_time = 2.5,
    walk_distance = 135,
    walk_sequence = "walk_all",
    walk_playback_rate = 1,
    walk_ang = Angle(0, 90, 0),
    black_fade_time = 0.7,
    disconnect_delay = 0.05
}
local menu_profile = {
    left = 30,
    top = 90,
    min_width = 360,
    height = 160,
    medal_size = 50
}
local menu_title = {
    width = 500,
    offset_x = -11,
    spacing = 55
}
local menu_live = {
    drift_x = 14,
    drift_y = 10,
    shake_x = 1,
    shake_y = 1,
    title_x = 30,
    title_y = 25,
    title_mouse_x = 10,
    title_mouse_y = 7,
    title_float_x = 4,
    title_float_y = 3,
    title_hover_scale = 0.08,
    button_hover_scale = 0.02,
    button_drift_x = 4,
    button_drift_y = 1,
    button_shake_x = 0,
    button_shake_y = 0,
    profile_drift_x = 9,
    profile_drift_y = 6,
    bottom_drift_x = 10,
    bottom_drift_y = 6,
    logo_drift_x = 7,
    logo_drift_y = 4,
    enter_x = 18,
    enter_y = 12
}
local menu_profile_fallback_band = {
    icon = Material("vgui/mats_jack_awards/10")
}
local menu_profile_fallback_medal = {
    icon = Material("vgui/mats_jack_awards/pt")
}

local function CleanupPreviewAccessories(ent)
    if not IsValid(ent) or not ent.modelAccess then return end
    for k, v in pairs(ent.modelAccess) do
        if IsValid(v) then
            v:Remove()
        end
        ent.modelAccess[k] = nil
    end
end

function PANEL:GetPreviewAppearance()
    if not hg or not hg.Appearance then return end
    local appearance
    if hg.Appearance.LoadAppearanceFile and hg.Appearance.SelectedAppearance then
        appearance = hg.Appearance.LoadAppearanceFile(hg.Appearance.SelectedAppearance:GetString())
    end
    appearance = appearance or (hg.Appearance.GetRandomAppearance and hg.Appearance.GetRandomAppearance())
    if not appearance or not hg.Appearance.PlayerModels then return end
    local tMdl = hg.Appearance.PlayerModels[1][appearance.AModel] or hg.Appearance.PlayerModels[2][appearance.AModel]
    if not tMdl or not tMdl.mdl then return end
    return table.Copy(appearance), tMdl
end

function PANEL:GetProfileInfo()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return "Unknown", "0 XP", nil
    end

    local username = ply:GetNWString("PlayerName", "")
    if username == "" then
        username = ply:Nick()
    end

    local xp = tostring(math.floor(tonumber(ply.exp) or 0)) .. " XP"
    return username, xp, ply
end

function PANEL:GetLiveMouse()
    local mx, my = gui.MouseX(), gui.MouseY()
    if mx <= 0 and my <= 0 then
        mx = ScrW() * 0.5
        my = ScrH() * 0.5
    end
    local nx = math.Clamp((mx / ScrW() - 0.5) * 2, -1, 1)
    local ny = math.Clamp((my / ScrH() - 0.5) * 2, -1, 1)
    return mx, my, nx, ny
end

function PANEL:GetLiveOffset(xAmount, yAmount)
    local _, _, nx, ny = self:GetLiveMouse()
    return nx * xAmount, ny * yAmount
end

function PANEL:GetLiveShake(seedX, seedY, xAmount, yAmount)
    local t = RealTime()
    return math.sin(t * 1.8 + seedX) * xAmount, math.cos(t * 2.4 + seedY) * yAmount
end

function PANEL:Think()
    if self.DisconnectBlackStart then
        local blackFrac = math.Clamp((CurTime() - self.DisconnectBlackStart) / math.max(disconnect_cutscene.black_fade_time, 0.001), 0, 1)
        self.DisconnectBlackAlpha = 255 * blackFrac
    end

    if self.DisconnectWalkStart and CurTime() >= self.DisconnectWalkStart then
        local walkFrac = math.Clamp((CurTime() - self.DisconnectWalkStart) / disconnect_cutscene.walk_time, 0, 1)
        if walkFrac < 1 and CurTime() > (self.NextFootstep or 0) then
            self.NextFootstep = CurTime() + 0.38
            local vol = 1 - walkFrac
            if LocalPlayer and IsValid(LocalPlayer()) then
                LocalPlayer():EmitSound("player/footsteps/concrete" .. math.random(1,4) .. ".wav", 0, 100, vol)
            end
        end
    end

    self.LiveLerp = LerpFT(0.08, self.LiveLerp or 0, 1)
    self.LogoHoverLerp = LerpFT(0.12, self.LogoHoverLerp or 0, IsValid(self.logoPanel) and self.logoPanel:IsHovered() and 1 or 0)

    local enter = 1 - (self.LiveLerp or 0)
    local dockMouseX, dockMouseY = self:GetLiveOffset(MenuUnit(menu_live.drift_x), MenuUnit(menu_live.drift_y))
    local dockShakeX, dockShakeY = self:GetLiveShake(0.6, 1.1, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))

    if IsValid(self.lDock) and self.lDockBaseMargins then
        self.lDock:DockMargin(
            math.Round(self.lDockBaseMargins[1] + dockMouseX + dockShakeX - MenuUnit(menu_live.enter_x) * enter),
            math.Round(self.lDockBaseMargins[2] + dockMouseY + dockShakeY + MenuUnit(menu_live.enter_y) * enter),
            self.lDockBaseMargins[3],
            self.lDockBaseMargins[4]
        )
    end

    if IsValid(self.logoPanel) and self.logoBaseMargin then
        local logoMouseX, logoMouseY = self:GetLiveOffset(MenuUnit(menu_live.logo_drift_x), MenuUnit(menu_live.logo_drift_y))
        self.logoPanel:DockMargin(
            math.Round(logoMouseX),
            0,
            0,
            math.Round(self.logoBaseMargin + logoMouseY)
        )
    end

    if IsValid(self.profileInfo) and self.profileBasePos then
        local profileMouseX, profileMouseY = self:GetLiveOffset(MenuUnit(menu_live.profile_drift_x), MenuUnit(menu_live.profile_drift_y))
        local profileShakeX, profileShakeY = self:GetLiveShake(1.7, 2.3, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))
        self.profileInfo:SetPos(
            math.Round(self.profileBasePos[1] + profileMouseX + profileShakeX - MenuUnit(menu_live.enter_x) * enter),
            math.Round(self.profileBasePos[2] + profileMouseY + profileShakeY + MenuUnit(menu_live.enter_y) * enter)
        )
    end

    if IsValid(self.bottomDock) and self.bottomDockBasePos then
        local bottomMouseX, bottomMouseY = self:GetLiveOffset(MenuUnit(menu_live.bottom_drift_x), MenuUnit(menu_live.bottom_drift_y))
        local bottomShakeX, bottomShakeY = self:GetLiveShake(2.8, 3.1, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))
        self.bottomDock:SetPos(
            math.Round(self.bottomDockBasePos[1] + bottomMouseX + bottomShakeX - MenuUnit(menu_live.enter_x) * enter),
            math.Round(self.bottomDockBasePos[2] + bottomMouseY + bottomShakeY + MenuUnit(menu_live.enter_y) * enter)
        )
    end
end

function PANEL:CreateProfileInfo()
    local profile = vgui.Create("DPanel", self)
    self.profileInfo = profile
    profile:SetSize(MenuUnit(menu_profile.min_width), MenuUnit(menu_profile.height))
    profile:SetPos(MenuUnit(menu_profile.left), MenuUnit(menu_profile.top))
    self.profileBasePos = {MenuUnit(menu_profile.left), MenuUnit(menu_profile.top)}
    profile:SetMouseInputEnabled(false)
    profile:SetAlpha(0)
    profile.Paint = function() end

    local username = vgui.Create("DLabel", profile)
    username:SetPos(0, 0)
    username:SetFont("ZCity_Small")
    username:SetTextColor(color_white)
    username:SetContentAlignment(7)
    username:SetExpensiveShadow(1, Color(0, 0, 0, 225))

    local medal = vgui.Create("DPanel", profile)
    medal:SetPos(0, MenuUnit(28))
    medal:SetSize(MenuUnit(menu_profile.medal_size), MenuUnit(menu_profile.medal_size))
    medal.Band = nil
    medal.Medal = nil
    medal.Paint = function(this, w, h)
        if this.Band and this.Band.icon then
            surface.SetMaterial(this.Band.icon)
            surface.SetDrawColor(255,255,255,255)
            surface.DrawTexturedRect(0, 0, w, h)
        end
        if this.Medal and this.Medal.icon then
            surface.SetMaterial(this.Medal.icon)
            surface.SetDrawColor(255,255,255,255)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end

    local xp = vgui.Create("DLabel", profile)
    xp:SetPos(MenuUnit(30), MenuUnit(31))
    xp:SetFont("ZCity_Small")
    xp:SetTextColor(Color(175, 175, 175))
    xp:SetContentAlignment(7)
    xp:SetExpensiveShadow(1, Color(0, 0, 0, 225))

    local lastExp = -1
    local lastSkill = -1
    function profile:Think()
        local nameText, xpText, ply = self:GetParent():GetProfileInfo()
        if username:GetText() != nameText then
            username:SetText(nameText)
            username:SizeToContents()
        end
        if xp:GetText() != xpText then
            xp:SetText(xpText)
            xp:SizeToContents()
        end
        if IsValid(ply) and (lastExp != (ply.exp or 0) or lastSkill != (ply.skill or 0) or not medal.Band or not medal.Medal) then
            if ply.GetAwards then
                medal.Band, medal.Medal = ply:GetAwards()
            else
                medal.Band, medal.Medal = menu_profile_fallback_band, menu_profile_fallback_medal
            end
            medal.Band = medal.Band or menu_profile_fallback_band
            medal.Medal = medal.Medal or menu_profile_fallback_medal
            lastExp = ply.exp or 0
            lastSkill = ply.skill or 0
        end
        local medalSize = MenuUnit(menu_profile.medal_size)
        medal:SetSize(medalSize, medalSize)
        medal:SetPos(0, username:GetTall() + MenuUnit(3))
        xp:SetPos(medalSize + MenuUnit(4), username:GetTall() + MenuUnit(5))
        profile:SetWide(math.max(MenuUnit(menu_profile.min_width), username:GetWide() + MenuUnit(8), xp:GetX() + xp:GetWide() + MenuUnit(8)))
    end

    timer.Simple(0, function()
        if not IsValid(profile) then return end
        profile:AlphaTo(255, appearance_preview.enter_time * 0.75, appearance_preview.enter_delay)
    end)
end

function PANEL:CreateAppearancePreview()
    local tbl, tMdl = self:GetPreviewAppearance()
    if not tbl or not tMdl then return end

    if hg.Appearance and hg.Appearance.PrecacheModels then
        hg.Appearance.PrecacheModels()
    end

    local holderW = MenuUnit(appearance_preview.width)
    local holderH = MenuUnit(appearance_preview.height)
    local targetX = ScrW() - holderW - MenuUnit(appearance_preview.right)
    local targetY = MenuUnit(appearance_preview.top)

    self.previewHolder = vgui.Create("DPanel", self)
    local holder = self.previewHolder
    holder:SetSize(holderW, holderH)
    holder:SetPos(targetX, ScrH())
    holder:SetAlpha(0)
    holder.TargetX = targetX
    holder.TargetY = targetY
    holder.ClosedY = ScrH()
    holder:SetMouseInputEnabled(false)
    holder.Paint = function() end

    local preview = vgui.Create("DModelPanel", holder)
    self.previewModel = preview
    preview.OwnerMenu = self
    preview:Dock(FILL)
    preview:SetModel(util.IsValidModel(tostring(tMdl.mdl)) and tostring(tMdl.mdl) or "models/player/group01/female_01.mdl")
    preview:SetFOV(appearance_preview.fov)
    preview:SetLookAng(appearance_preview.look_ang)
    preview:SetCamPos(appearance_preview.cam_pos)
    preview:SetAmbientLight(appearance_preview.ambient)
    preview:SetDirectionalLight(BOX_RIGHT, appearance_preview.light_right)
    preview:SetDirectionalLight(BOX_LEFT, appearance_preview.light_left)
    preview:SetDirectionalLight(BOX_FRONT, appearance_preview.light_front)
    preview:SetDirectionalLight(BOX_BACK, appearance_preview.light_back)
    preview:SetDirectionalLight(BOX_TOP, appearance_preview.light_top)
    preview:SetDirectionalLight(BOX_BOTTOM, appearance_preview.light_bottom)
    preview:SetMouseInputEnabled(false)
    preview.AppearanceTable = tbl

    local oldPaint = preview.Paint
    preview.Paint = function(pnl, w, h)
        DisableClipping(true)
        oldPaint(pnl, w, h)
        DisableClipping(false)
    end

    function preview:LayoutEntity(ent)
        local appearance = self.AppearanceTable
        if not appearance or not hg or not hg.Appearance or not hg.Appearance.PlayerModels then return end

        local modelData = hg.Appearance.PlayerModels[1][appearance.AModel] or hg.Appearance.PlayerModels[2][appearance.AModel]
        if not modelData or not modelData.mdl then return end

        local colorData = appearance.AColor or color_white
        ent:SetNWVector("PlayerColor", Vector((colorData.r or 255) / 255, (colorData.g or 255) / 255, (colorData.b or 255) / 255))

        local targetPos = Vector(0, 0, 0)
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene then
            if self.OwnerMenu.DisconnectWalkStart and CurTime() >= self.OwnerMenu.DisconnectWalkStart then
                local walkFrac = math.Clamp((CurTime() - self.OwnerMenu.DisconnectWalkStart) / disconnect_cutscene.walk_time, 0, 1)
                targetPos = Vector(0, walkFrac * disconnect_cutscene.walk_distance, 0)
            end
        end
        ent:SetPos(targetPos)

        local targetEntityAngle = self.EntityAngleOverride or appearance_preview.entity_ang
        self.EntityAngle = LerpAngle(RealFrameTime() * 6, self.EntityAngle or targetEntityAngle, targetEntityAngle)
        ent:SetAngles(self.EntityAngle)

        local sequenceName = self.SequenceNameOverride or appearance_preview.sequence
        local seq = ent:LookupSequence(sequenceName)
        
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene and (not seq or seq < 0) then
            local fallbacks = {"walk_suitcase", "walk_all", "walk", "walk_all_suitcase"}
            for _, v in ipairs(fallbacks) do
                seq = ent:LookupSequence(v)
                if seq and seq >= 0 then
                    sequenceName = v
                    break
                end
            end
        end

        if (not seq or seq < 0) and sequenceName != appearance_preview.sequence then
            sequenceName = appearance_preview.sequence
            seq = ent:LookupSequence(sequenceName)
        end
        if seq and seq >= 0 then
            if self.ActiveSequenceName != sequenceName then
                ent:ResetSequence(seq)
                self.ActiveSequenceName = sequenceName
            end
            ent:SetPlaybackRate(self.SequencePlaybackRate or 1)
            ent:FrameAdvance(RealFrameTime() * (self.SequencePlaybackRate or 1))
        end

        local owner = self.OwnerMenu
        local nx, ny = 0, 0
        if IsValid(owner) and owner.GetLiveMouse then
            local _, _, newNX, newNY = owner:GetLiveMouse()
            nx, ny = newNX, newNY
        end
        local targetYaw = appearance_preview.head_yaw - nx * appearance_preview.head_mouse_yaw
        local targetPitch = appearance_preview.head_pitch - ny * appearance_preview.head_mouse_pitch
        self.HeadYawLerp = LerpFT(0.08, self.HeadYawLerp or appearance_preview.head_yaw, targetYaw)
        self.HeadPitchLerp = LerpFT(0.08, self.HeadPitchLerp or appearance_preview.head_pitch, targetPitch)
        ent:SetPoseParameter("head_yaw", self.HeadYawLerp)
        ent:SetPoseParameter("head_pitch", self.HeadPitchLerp)
        
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene then
            ent:SetPoseParameter("move_x", 1)
            ent:SetPoseParameter("move_y", 0)
        end
        
        ent:SetSubMaterial()
        self:SetCamPos(appearance_preview.cam_pos)
        self:SetFOV(appearance_preview.fov)
        self:SetLookAng(appearance_preview.look_ang)

        if ent:GetModel() != modelData.mdl then
            CleanupPreviewAccessories(ent)
            ent:SetModel(modelData.mdl)
            self:SetModel(modelData.mdl)
            self.ActiveSequenceName = nil
        end

        local clothes = appearance.AClothes or {}
        local mats = ent:GetMaterials()
        for k, v in SortedPairs(modelData.submatSlots or {}) do
            local slot = 1
            for i = 1, #mats do
                if mats[i] == v then
                    slot = i - 1
                    break
                end
            end
            local sexID = modelData.sex and 2 or 1
            local clothMat = hg.Appearance.Clothes[sexID] and hg.Appearance.Clothes[sexID][clothes[k]]
            ent:SetSubMaterial(slot, clothMat or (hg.Appearance.Clothes[sexID] and hg.Appearance.Clothes[sexID].normal) or nil)
        end

        local facemapSlot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelData.mdl]
        for i = 1, #mats do
            if facemapSlot and hg.Appearance.FacemapsSlots[mats[i]] and hg.Appearance.FacemapsSlots[mats[i]][appearance.AFacemap] then
                ent:SetSubMaterial(i - 1, hg.Appearance.FacemapsSlots[mats[i]][appearance.AFacemap])
            end
        end

        appearance.ABodygroups = appearance.ABodygroups or {}
        for k, v in SortedPairs(ent:GetBodyGroups()) do
            if not appearance.ABodygroups[v.name] then continue end
            local bodygroupData = hg.Appearance.Bodygroups[v.name]
            local bodygroupSet = bodygroupData and bodygroupData[modelData.sex and 2 or 1] and bodygroupData[modelData.sex and 2 or 1][appearance.ABodygroups[v.name]]
            if not bodygroupSet then continue end
            for i = 0, #v.submodels do
                if bodygroupSet[1] == v.submodels[i] then
                    ent:SetBodygroup(k - 1, i)
                    break
                end
            end
        end
    end

    function preview:PostDrawModel(ent)
        local appearance = self.AppearanceTable
        if not appearance or not appearance.AAttachments then return end
        for _, attach in ipairs(appearance.AAttachments) do
            local accessoryData = hg.Accessories and hg.Accessories[attach]
            if accessoryData then
                DrawAccesories(ent, ent, attach, accessoryData, false, true)
            end
        end
        ent:SetupBones()
    end

    function preview:OnRemove()
        if IsValid(self.Entity) then
            CleanupPreviewAccessories(self.Entity)
        end
    end

    timer.Simple(0, function()
        if not IsValid(holder) then return end
        holder:MoveTo(targetX, targetY, appearance_preview.enter_time, 0, appearance_preview.enter_delay)
        holder:AlphaTo(255, appearance_preview.enter_time * 0.75, appearance_preview.enter_delay)
    end)
end

function PANEL:Init()
    self:SetAlpha(0)
    self:SetSize(ScrW(), ScrH())
    self:Center()
    self:SetTitle("")
    self:SetDraggable(false)
    self:SetBorder(false)
    self:SetColorBG(clr_verygray)
    self:SetDraggable(false)
    self:ShowCloseButton(false)
    curent_panel = nil
    self.Title, self.TitleShadow = self:InitializeMarkup()
    self.LiveLerp = 0
    self.LogoHoverLerp = 0
    self.DisconnectCutscene = false
    self.DisconnectBackgroundAlpha = 255
    self.DisconnectBlackAlpha = 0
    StartMainMenuMusic(self)

        end

    end



    if IsValid(ZCityAppearanceMusic) then

        local t = ZCityAppearanceMusic:GetTime()

        if isnumber(t) and t >= 0 then

            ZCityMenuMusicState.appearanceTime = t

        end

    end



    if IsValid(ZCityIntroMusic) then

        local t = ZCityIntroMusic:GetTime()

        if isnumber(t) and t >= 0 then

            ZCityMenuMusicState.introTime = t

        end

    end

end



local function ZCityResumeMainMusic()

    local seekTime = ZCityMenuMusicState.mainTime or 0



    if IsValid(ZCityMainMenuMusic) then

        ZCityMainMenuMusic:Play()

        if seekTime > 0 then

            ZCityMainMenuMusic:SetTime(seekTime)

        end

        ZCityMainMenuMusic:SetVolume(0.25)

        return

    end



    sound.PlayFile("sound/quehice.ogg", "noblock", function(station)

        if not IsValid(station) then return end

        station:EnableLooping(true)

        station:SetVolume(0.25)

        station:Play()

        if seekTime > 0 then

            station:SetTime(seekTime)

        end

        ZCityMainMenuMusic = station

    end)

    self.lDock = vgui.Create("DPanel", self)
    local lDock = self.lDock
    lDock:Dock(LEFT)
    lDock:SetSize(ScrW() / 3, ScrH())
    lDock:DockMargin(0, MenuUnit(90), MenuUnit(10), MenuUnit(90))
    self.lDockBaseMargins = {0, MenuUnit(90), MenuUnit(10), MenuUnit(90)}
    lDock.Paint = function(this, w, h)
        if hg.PluvTown.Active then
            surface.SetDrawColor(color_white)
            surface.SetMaterial(self.SelectedPluv or Pluv)
            surface.DrawTexturedRect(0, MenuUnit(27), MenuUnit(35), MenuUnit(27))
        end
    end

    self:CreateAppearancePreview()
    self:CreateProfileInfo()

    self.Buttons = {}
    for k, v in ipairs(Selects) do
        if v.GamemodeOnly and engine.ActiveGamemode() != "zcity" then continue end
        self:AddSelect(lDock, v.Title, v)
    end

    local logoPanel = vgui.Create("DPanel", lDock)
    local logoAspect = math.max(1, LogoistMat:Height()) / math.max(1, LogoistMat:Width())
    self.logoPanel = logoPanel
    logoPanel:Dock(BOTTOM)
    logoPanel:SetTall(1)
    logoPanel:SetMouseInputEnabled(true)
    logoPanel:DockMargin(0, 0, 0, MenuUnit(menu_title.spacing))
    self.logoBaseMargin = MenuUnit(menu_title.spacing)
    logoPanel.Think = function(this)
        local maxW = math.max(1, this:GetWide() - MenuUnit(12))
        local drawW = math.min(MenuUnit(menu_title.width), maxW)
        local drawH = drawW * logoAspect
        this:SetTall(math.ceil(drawH * (1 + menu_live.title_hover_scale) + MenuUnit(8)))
    end
    logoPanel.Paint = function(this, w, h)
        local driftX, driftY = self:GetLiveOffset(MenuUnit(menu_live.logo_drift_x), MenuUnit(menu_live.logo_drift_y))
        local shakeX, shakeY = self:GetLiveShake(6.4, 7.2, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))
        local scale = 1 + (self.LogoHoverLerp or 0) * menu_live.title_hover_scale
        local maxW = math.max(1, w - MenuUnit(12))
        local baseW = math.min(MenuUnit(menu_title.width), maxW)
        local baseH = baseW * logoAspect
        local drawW = baseW * scale
        local drawH = baseH * scale
        local maxX = math.max(0, w - drawW)
        local maxY = math.max(0, h - drawH)
        local drawX = math.Clamp(MenuUnit(menu_title.offset_x) + driftX + shakeX, 0, maxX)
        local drawY = math.Clamp((h - drawH) * 0.5 + driftY + shakeY, 0, maxY)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(LogoistMat)
        surface.DrawTexturedRect(drawX, drawY, drawW, drawH)
    end


    local bottomDock = vgui.Create("DPanel", self)
    self.bottomDock = bottomDock
    bottomDock:SetPos(ScreenScale(1), ScrH() - ScrH()/10)
    bottomDock:SetSize(ScreenScale(190), ScreenScaleH(40))
    self.bottomDockBasePos = {ScreenScale(1), ScrH() - ScrH()/10}
    bottomDock.Paint = function(this, w, h) end
    self.panelparrent = vgui.Create("DPanel", self)
    self.panelparrent:SetPos(0, 0)
    self.panelparrent:SetSize(ScrW(), ScrH())
    self.panelparrent:MoveToBack()
    self.panelparrent.Paint = function(this, w, h) end
    

    -- Check for Intro Mode

    if not ZCityHasSeenIntro then

        self.IsIntro = true

        

    end

    

    local zteam = vgui.Create("DLabel", bottomDock)
    zteam:Dock(BOTTOM)
    zteam:DockMargin(ScreenScale(10), 0, 0, 0)
    zteam:SetFont("ZCity_Tiny")
    zteam:SetTextColor(clr_gray)
    zteam:SetText("EARLY-ACCESS")
    zteam:SetContentAlignment(4)
    zteam:SizeToContents()
end

    self.TargetState = "Main"

local gradient_d = surface.GetTextureID("vgui/gradient-d")
local gradient_r = surface.GetTextureID("vgui/gradient-r")
local gradient_l = surface.GetTextureID("vgui/gradient-l")
local menu_gradient_right = Color(18,18,18,65)

local clr_1 = Color(100,100,100,35)
function PANEL:Paint(w,h)
    local backgroundAlpha = math.Clamp(self.DisconnectBackgroundAlpha or 255, 0, 255)
    if backgroundAlpha > 0 then
        local bgMul = backgroundAlpha / 255
        draw.RoundedBox(0, 0, 0, w, h, Color(self.ColorBG.r, self.ColorBG.g, self.ColorBG.b, (self.ColorBG.a or 255) * bgMul))
        hg.DrawBlur(self, 5)
        surface.SetDrawColor(menu_gradient_right.r, menu_gradient_right.g, menu_gradient_right.b, menu_gradient_right.a * bgMul)
        surface.SetTexture(gradient_r)
        surface.DrawTexturedRect(0,0,w,h)
        surface.SetDrawColor(self.ColorBG.r, self.ColorBG.g, self.ColorBG.b, (self.ColorBG.a or 255) * bgMul)
        surface.SetTexture(gradient_l)
        surface.DrawTexturedRect(0,0,w,h)
        surface.SetDrawColor(clr_1.r, clr_1.g, clr_1.b, clr_1.a * bgMul)
        surface.SetTexture(gradient_d)
        surface.DrawTexturedRect(0,0,w,h)
    end
    if (self.DisconnectBlackAlpha or 0) > 0 then
        surface.SetDrawColor(0, 0, 0, self.DisconnectBlackAlpha)
        surface.DrawRect(0, 0, w, h)
    end
end

function PANEL:PlayDisconnectCutscene()
    if self.DisconnectCutscene then return end
    self.DisconnectCutscene = true
    self.DisconnectFadeStart = CurTime()
    self.DisconnectBackgroundAlpha = 255
    self.DisconnectBlackAlpha = 0
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)

    StopMainMenuMusic()

    if IsValid(self.previewHolder) then
        self.previewHolder:SetVisible(true)
        self.previewHolder:SetAlpha(255)
    end

    if IsValid(self.previewModel) then
        self.previewModel.SequenceNameOverride = disconnect_cutscene.walk_sequence
        self.previewModel.SequencePlaybackRate = disconnect_cutscene.walk_playback_rate
        self.previewModel.EntityAngleOverride = disconnect_cutscene.walk_ang
        self.previewModel.ActiveSequenceName = nil
    end

    for _, child in ipairs(self:GetChildren()) do
        if child != self.previewHolder then
            child:AlphaTo(0, disconnect_cutscene.ui_fade_time, 0, function()
                if IsValid(child) then
                    child:SetVisible(false)
                end
            end)
        end
    end

    local function startBlackFade()
        if not IsValid(self) then return end
        self.DisconnectBlackStart = CurTime()
        self.DisconnectBlackAlpha = 0
        timer.Simple(disconnect_cutscene.black_fade_time + disconnect_cutscene.disconnect_delay, function()
            if IsValid(self) then
                RunConsoleCommand("disconnect")
            end
        end)
    end

    self.DisconnectWalkStart = CurTime() + disconnect_cutscene.ui_fade_time + disconnect_cutscene.walk_delay

    timer.Simple(disconnect_cutscene.ui_fade_time + disconnect_cutscene.walk_delay + disconnect_cutscene.walk_time, function()
        if IsValid(self) then
            startBlackFade()
        end
    end)
end

function PANEL:AddSelect( pParent, strTitle, tbl )
    local id = #self.Buttons + 1
    self.Buttons[id] = vgui.Create( "DLabel", pParent )
    local btn = self.Buttons[id]
    btn:SetText( string.rep("#", #(curent_panel == string.lower(strTitle) and strTitle ~= 'Traitor Role' and '[ '..strTitle..' ]' or strTitle)) )
    btn:SetMouseInputEnabled( true )
    btn:SizeToContents()
    btn:SetFont( "ZCity_Small" )
    btn:SetTall( MenuUnit(42) )
    btn:Dock(BOTTOM)
    btn:DockMargin(MenuUnit(15),MenuUnit(2),0,0)
    btn.Func = tbl.Func
    btn.HoveredFunc = tbl.HoveredFunc
    local luaMenu = self 
    if tbl.CreatedFunc then tbl.CreatedFunc(btn, self, luaMenu) end
    btn.RColor = Color(225,225,225)
    btn.OpenTime = CurTime()
    btn.LineLerp = 0
    btn.HoverLerp = 0
    function btn:DoClick()
        if luaMenu.DisconnectCutscene then return end
		for i = 1, 3 do
			surface.PlaySound("shitty/tap_depress.wav")
		end

        if tbl.BypassTransition then
            btn.Func(luaMenu)
            return
        end

        for _, child in ipairs(luaMenu:GetChildren()) do
            if child ~= luaMenu.panelparrent then
                child:AlphaTo(0, 0.2, 0, function()
                    if IsValid(child) then child:SetVisible(false) end
                end)
            end
        end

        luaMenu.panelparrent:AlphaTo(0,0.2,0,function()
            if IsValid(luaMenu.panelparrent) then
                luaMenu.panelparrent:Remove()
            end
            luaMenu.panelparrent = vgui.Create("DPanel", luaMenu)
            
            luaMenu.panelparrent:SetPos(0, 0)
            luaMenu.panelparrent:SetSize(ScrW(), ScrH())
            luaMenu.panelparrent:MoveToFront()
            luaMenu.panelparrent.Paint = function(this, w, h) end
            btn.Func(luaMenu,luaMenu.panelparrent)
            curent_panel = string.lower(strTitle)
        end)
    end

    function btn:Think()
        local isHovered = self:IsHovered() or (IsValid(self:GetChild(0)) and self:GetChild(0):IsHovered()) or (IsValid(self:GetChild(0)) and IsValid(self:GetChild(0):GetChild(0)) and self:GetChild(0):GetChild(0):IsHovered())

        self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, isHovered and 1 or 0)
        self.LineLerp = LerpFT(0.2, self.LineLerp or 0, isHovered and 1 or 0)
        local mouseX, mouseY = luaMenu:GetLiveOffset(MenuUnit(menu_live.button_drift_x), MenuUnit(menu_live.button_drift_y))
        local shakeX, shakeY = luaMenu:GetLiveShake(id * 0.91, id * 1.27, MenuUnit(menu_live.button_shake_x), MenuUnit(menu_live.button_shake_y))
        self:DockMargin(
            math.Round(MenuUnit(15) + mouseX * 0.3 + shakeX + self.HoverLerp * MenuUnit(2)),
            math.Round(MenuUnit(2) + mouseY * 0.1 + shakeY),
            0,
            0
        )

        local elapsed = CurTime() - self.OpenTime
        local charsToShow = math.floor(elapsed * 15)
        local targetText = (curent_panel == string.lower(strTitle) and strTitle ~= 'Traitor Role') and '[ '..strTitle..' ]' or strTitle
        local len = #targetText

        if charsToShow > len then charsToShow = len end

        local ntxt = ""
        for i = 1, len do
            if i <= charsToShow then
                ntxt = ntxt .. targetText:sub(i, i)
            else
                ntxt = ntxt .. "#"
            end
        end

        if self:GetText() ~= ntxt then
            surface.PlaySound("shitty/tap-resonant.wav")
            self:SetText(ntxt)
            self:SizeToContents()
        end
    end

    function btn:Paint(w, h)
        local isHovered = self:IsHovered() or (IsValid(self:GetChild(0)) and self:GetChild(0):IsHovered()) or (IsValid(self:GetChild(0)) and IsValid(self:GetChild(0):GetChild(0)) and self:GetChild(0):GetChild(0):IsHovered())
        local flash = isHovered and (0.5 + 0.5 * math.sin(CurTime() * 10)) or 0
        
        local textColor = self.RColor
        local outlineColor = Color(0, 0, 0, 255)

        if isHovered then
            local v = flash * 255
            textColor = Color(v, v, v, 255)
            local inv = 255 - v
            outlineColor = Color(inv, inv, inv, 255)
        end

        surface.SetFont(self:GetFont())
        local tw, th = surface.GetTextSize(self:GetText())
        local scale = 1 + (self.HoverLerp or 0) * menu_live.button_hover_scale
        local matrix = Matrix()
        matrix:Translate(Vector(0, h * (1 - scale) * 0.5, 0))
        matrix:Scale(Vector(scale, scale, 1))
        cam.PushModelMatrix(matrix)
        draw.SimpleTextOutlined(self:GetText(), self:GetFont(), 0, h / 2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, outlineColor)

        if self.LineLerp and self.LineLerp > 0.01 then
            surface.SetDrawColor(255, 255, 255, 255 * self.LineLerp)
            surface.DrawRect(0, h / 2 + th / 2, tw * self.LineLerp, math.max(1, MenuUnit(1)))
        end
        cam.PopModelMatrix()
        return true
    end



    surface.SetTextPos(self.LogoX + textShakeX, titleY + textShakeY)

    surface.DrawText(text1)

    

    if self.IsIntro then

        local enterText = "press enter"

        surface.SetFont("ZCity_Veteran")

        local tw, th = surface.GetTextSize(enterText)

        local tx = w - tw - ScreenScale(20)

        local ty = h - th - ScreenScale(20)

        

        -- Blink logic

        local blinkSpeed = 2

        local alpha = math.abs(math.sin(CurTime() * blinkSpeed)) * 255

        

        surface.SetTextColor(255, 0, 0, alpha)

        surface.SetTextPos(tx, ty)

        surface.DrawText(enterText)

        

        -- Intro Sequence Fade to Black

        if self.IntroSequenceActive then

            local elapsedTime = CurTime() - self.IntroStartTime

            local duration = 3 -- Fade out duration

            local fadeAlpha = math.Clamp((elapsedTime / duration) * 255, 0, 255)

            

            surface.SetDrawColor(0, 0, 0, fadeAlpha)

            surface.DrawRect(0, 0, w, h)

            

            if elapsedTime >= duration then

                self:Close()

                

                -- Create Fade Out Panel (Black -> Clear)

                local fadePanel = vgui.Create("DPanel")

                fadePanel:SetSize(ScrW(), ScrH())

                fadePanel:MakePopup()

                fadePanel:SetKeyboardInputEnabled(false)

                fadePanel:SetMouseInputEnabled(false)

                fadePanel.StartTime = CurTime()

                fadePanel.Duration = 3

                

                function fadePanel:Paint(pw, ph)

                    local et = CurTime() - self.StartTime

                    local a = 255 - math.Clamp((et / self.Duration) * 255, 0, 255)

                    surface.SetDrawColor(0, 0, 0, a)

                    surface.DrawRect(0, 0, pw, ph)

                    

                    if et >= self.Duration then

                        self:Remove()

                    end

                end

                

                -- Mark intro as seen

                ZCityHasSeenIntro = true

            end

        end

    end

end

function PANEL:Close()
    if self.DisconnectCutscene then return end
    StopMainMenuMusic()
    if IsValid(self.previewModel) and IsValid(self.previewModel.Entity) then
        CleanupPreviewAccessories(self.previewModel.Entity)
    end
    if IsValid(self.previewHolder) then
        self.previewHolder:MoveTo(self.previewHolder.TargetX or self.previewHolder:GetX(), self.previewHolder.ClosedY or ScrH(), appearance_preview.exit_time, 0, appearance_preview.exit_delay)
        self.previewHolder:AlphaTo(0, appearance_preview.exit_time * 0.75, appearance_preview.exit_delay)
    end
    self:AlphaTo(0, appearance_preview.exit_time, 0, function()
        if IsValid(self) then
            self:Remove()
        end
    end)
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
end

function PANEL:OnRemove()
    StopMainMenuMusic()
end

vgui.Register( "ZMainMenu", PANEL, "ZFrame")



hook.Add("OnPauseMenuShow","OpenMainMenu",function()

    local run = hook.Run("OnShowZCityPause")

    if run then

        return run

    end



    if MainMenu and IsValid(MainMenu) then
        if MainMenu.DisconnectCutscene then
            return false
        end
        MainMenu:Close()

        MainMenu = nil

        return false

    end



    MainMenu = vgui.Create("ZMainMenu")

    MainMenu:MakePopup()

    return false

end)





hook.Add("InitPostEntity", "ZCityOpenIntroMenu", function()

    -- Show intro once when the player first enters the game
    if ZCityHasSeenIntro then return end

    timer.Simple(0.5, function()

        if MainMenu and IsValid(MainMenu) then MainMenu:Remove() end

        MainMenu = vgui.Create("ZMainMenu")

        MainMenu:MakePopup()

        -- Force intro state

        MainMenu.IsIntro = true

        MainMenu:SetAlpha(255) -- Force visible immediately

        -- Auto-start intro sequence
        MainMenu.IntroSequenceActive = true
        MainMenu.IntroStartTime = CurTime()

    end)

end)



hook.Add("OnPauseMenuShow","OpenMainMenu",function()

    local run = hook.Run("OnShowZCityPause")

    if run then

        return run

    end



    if MainMenu and IsValid(MainMenu) then

        if MainMenu.IsIntro then

            return false -- Prevent closing intro menu with ESC

        end

        MainMenu:Close()

        MainMenu = nil

        return false

    end



    MainMenu = vgui.Create("ZMainMenu")

    MainMenu:MakePopup()

    return false

end)

local PANEL = {}



local red_select = Color(200,200,200)



local Selects = {

    {Title = "return", Func = function(luaMenu) luaMenu:Close() end},

    {Title = "main menu", Func = function(luaMenu) gui.ActivateGameUI() luaMenu:Close() end},

    {Title = "settings", Func = function(luaMenu) luaMenu:SwitchToSettings() end},

    {Title = "discord", Func = function(luaMenu) luaMenu:Close() gui.OpenURL("https://discord.gg/ZXUCAwuke2")  end},

    {Title = "achievements", Func = function(luaMenu) luaMenu:SwitchToAchievements() end},

    {Title = "appearance", Func = function(luaMenu) luaMenu:SwitchToAppearance() end},

    {Title = "traitor menu", GamemodeOnly = true, Func = function(luaMenu) luaMenu:SwitchToTraitorMenu() end},

    {Title = "disconnect", Func = function(luaMenu)

        if IsValid(ZCityMainMenuMusic) then ZCityMainMenuMusic:SetVolume(0) end

        if IsValid(ZCityAppearanceMusic) then ZCityAppearanceMusic:SetVolume(0) end



        local fade = vgui.Create("DPanel")

        fade:SetSize(ScrW(), ScrH())

        fade:SetPos(0, 0)

        fade:SetDrawOnTop(true)

        fade:SetAlpha(0)

        fade.Paint = function(s, w, h)

            surface.SetDrawColor(255, 0, 0, 255)

            surface.DrawRect(0, 0, w, h)

        end

        fade:AlphaTo(255, 0.3)



        local lbl = vgui.Create("DLabel", fade)

        lbl:SetText("goodbye.")

        lbl:SetFont("ZC_MM_Title")

        lbl:SetTextColor(Color(255, 255, 255))

        lbl:SizeToContents()

        lbl:Center()

        local cx, cy = lbl:GetPos()

        lbl.Think = function(s)

            s:SetPos(cx + math.random(-2, 2), cy + math.random(-2, 2))

        end



        for i = 1, 3 do

            sound.PlayFile("sound/goodbye.mp3", "noblock", function(station)

                if IsValid(station) then

                    station:SetPlaybackRate(0.9)

                    station:SetVolume(1)

                    station:Play()

                end

            end)

        end



        timer.Simple(2.5, function()

            RunConsoleCommand("disconnect")

        end)

    end},

}



surface.CreateFont("ZCity_Veteran", {

    font = "Veteran Typewriter",

    size = ScreenScaleH(18),

    weight = 500,

    antialias = true

})



surface.CreateFont("ZC_MM_Title", {

    font = "JMH Typewriter",

    size = ScreenScaleH(40),

    weight = 800,

    antialias = true

})

-- local Title = markup.Parse("error")



local Pluv = Material("pluv/pluvkid.jpg")

local LogoMat = Material("vgui/logo.png")

local BgMat = Material("vgui/background.png")

local EyeMat = Material("huy.png")

local BgMat2 = Material("vgui/background2.png")

local BgMat3 = Material("vgui/background6.png")

local BgMat4 = Material("vgui/pickman.png")

local BgMat4Overlay = Material("vgui/background4.png")

local NoiseMat = Material("vgui/noisevhs")

if NoiseMat:IsError() then

    NoiseMat = Material("vgui/white")

end



local SettingsSelects = {

    -- {Title = "Master Volume", Type = "Slider", Min = 0, Max = 1, CVar = "volume"}, -- Blocked

    -- {Title = "Music Volume", Type = "Slider", Min = 0, Max = 1, CVar = "snd_musicvolume"}, -- Blocked

    -- {Title = "Sensitivity", Type = "Slider", Min = 0.1, Max = 20, CVar = "sensitivity"}, -- Blocked

    {Title = "return", Func = function(luaMenu) luaMenu:SwitchToMain() end}

}



function PANEL:InitializeMarkup()

	local mapname = game.GetMap()

	local prefix = string.find(mapname, "_")

	if prefix then

		mapname = string.sub(mapname, prefix + 1)

	end

	local gm = string.lower(gmod.GetGamemode().Name .. " | " .. string.NiceName(zb ~= nil and zb.GetRoundName or mapname))



    if hg.PluvTown.Active then

        local text = "<font=ZC_MM_Title>meleecity</font>\n<font=ZCity_Small>" .. gm .. "</font>"



        self.SelectedPluv = table.Random(hg.PluvTown.PluvMats)



        return markup.Parse(text)

    end



    local text = "<font=ZC_MM_Title>meleecity</font>\n<font=ZCity_Small>" .. gm .. "</font>"

    return markup.Parse(text)

end



local color_red = Color(90,90,95,120)

local clr_gray = Color(255,255,255,25)

local clr_verygray = Color(10,10,19,235)

-- Global variable to persist music across menu opens

ZCityMainMenuMusic = ZCityMainMenuMusic or nil

ZCityAppearanceMusic = ZCityAppearanceMusic or nil

ZCityIntroMusic = ZCityIntroMusic or nil

ZCityHasSeenIntro = ZCityHasSeenIntro or false

ZCityMenuMusicState = ZCityMenuMusicState or {

    mainTime = 0,

    appearanceTime = 0,

    introTime = 0,

    lastRoundState = nil,

    pendingResume = false,

    pendingResumeTime = 0

}



local function ZCityCaptureMenuMusicTimes()

    if IsValid(ZCityMainMenuMusic) then

        local t = ZCityMainMenuMusic:GetTime()

        if isnumber(t) and t >= 0 then

            ZCityMenuMusicState.mainTime = t

        end

    end



    if IsValid(ZCityAppearanceMusic) then

        local t = ZCityAppearanceMusic:GetTime()

        if isnumber(t) and t >= 0 then

            ZCityMenuMusicState.appearanceTime = t

        end

    end



    if IsValid(ZCityIntroMusic) then

        local t = ZCityIntroMusic:GetTime()

        if isnumber(t) and t >= 0 then

            ZCityMenuMusicState.introTime = t

        end

    end

end



local function ZCityResumeMainMusic()

    local seekTime = ZCityMenuMusicState.mainTime or 0



    if IsValid(ZCityMainMenuMusic) then

        ZCityMainMenuMusic:Play()

        if seekTime > 0 then

            ZCityMainMenuMusic:SetTime(seekTime)

        end

        ZCityMainMenuMusic:SetVolume(0.25)

        return

    end



    sound.PlayFile("sound/quehice.ogg", "noblock", function(station)

        if not IsValid(station) then return end

        station:EnableLooping(true)

        station:SetVolume(0.25)

        station:Play()

        if seekTime > 0 then

            station:SetTime(seekTime)

        end

        ZCityMainMenuMusic = station

    end)

end



local function ZCityResumeAppearanceMusic()

    local seekTime = ZCityMenuMusicState.appearanceTime or 0



    if IsValid(ZCityAppearanceMusic) then

        ZCityAppearanceMusic:Play()

        if seekTime > 0 then

            ZCityAppearanceMusic:SetTime(seekTime)

        end

        ZCityAppearanceMusic:SetVolume(1)

        return

    end



    sound.PlayFile("sound/sexualdeviants.mp3", "noblock", function(station)

        if not IsValid(station) then return end

        station:EnableLooping(true)

        station:SetVolume(1)

        station:Play()

        if seekTime > 0 then

            station:SetTime(seekTime)

        end

        ZCityAppearanceMusic = station

    end)

end



local function ZCityResumeIntroMusic()

    local seekTime = ZCityMenuMusicState.introTime or 0



    if IsValid(ZCityIntroMusic) then

        ZCityIntroMusic:Play()

        if seekTime > 0 then

            ZCityIntroMusic:SetTime(seekTime)

        end

        return

    end



    sound.PlayFile("sound/itbegins.mp3", "noblock", function(station)

        if not IsValid(station) then return end

        station:Play()

        if seekTime > 0 then

            station:SetTime(seekTime)

        end

        ZCityIntroMusic = station

    end)

end



local function ZCityResumeActiveMenuMusic()

    if not IsValid(MainMenu) then return end



    if MainMenu.IsIntro and MainMenu.IntroSequenceActive then

        ZCityResumeIntroMusic()

        return

    end



    if MainMenu.CurrentState == "Appearance" or MainMenu.TargetState == "Appearance" then

        ZCityResumeAppearanceMusic()

        return

    end



    ZCityResumeMainMusic()

end



hook.Add("Think", "ZCityMenuMusicRoundSync", function()

    ZCityCaptureMenuMusicTimes()



    local roundState = zb and zb.ROUND_STATE

    if not isnumber(roundState) then return end



    if ZCityMenuMusicState.lastRoundState ~= roundState then

        if roundState == 1 then

            ZCityMenuMusicState.pendingResume = true

            ZCityMenuMusicState.pendingResumeTime = CurTime() + 0.1

        end

        ZCityMenuMusicState.lastRoundState = roundState

    end



    if ZCityMenuMusicState.pendingResume and CurTime() >= ZCityMenuMusicState.pendingResumeTime then

        ZCityMenuMusicState.pendingResume = false

        ZCityResumeActiveMenuMusic()

    end

end)



function PANEL:Init()

    self:SetAlpha( 0 )

    self:SetSize( ScrW(), ScrH() )

    -- self:Center()

    self:SetTitle( "" )

    self:SetDraggable( false )

    self:SetBorder( false )

    self:SetColorBG(clr_verygray)

    self:SetDraggable( false )

    self:ShowCloseButton( false )

    

    -- Check for Intro Mode

    if not ZCityHasSeenIntro then

        self.IsIntro = true

        

    end

    

    self.CurrentState = "Main"

    self.TargetState = "Main"

    self.TransitionProgress = 1 -- Start in stable state



    -- self.Title, self.TitleShadow = self:InitializeMarkup()



    timer.Simple(0,function()

        if self.First then

            self:First()

        end

    end)



    if LogoMat and LogoMat.IsError and LogoMat:IsError() then

        LogoMat = Material("vgui/logo")

    end



    self.LogoX = ScreenScaleH(20)

    self.LogoY = ScreenScaleH(20)

    

    surface.SetFont("ZC_MM_Title")

    local _, th = surface.GetTextSize("huytown: guppy slaughter")

    self.LogoH = th



    self.MenuTop = self.LogoY + self.LogoH + ScreenScaleH(60)

    

    surface.SetFont("ZCity_Veteran")

    local widest = 0

    for _, v in ipairs(Selects) do

        if v.GamemodeOnly and engine.ActiveGamemode() != "zcity" then continue end

        local w = surface.GetTextSize(v.Title)

        if w > widest then

            widest = w

        end

    end

    self.MenuW = math.max(ScreenScaleH(260), widest + ScreenScaleH(40))

    self.MenuX = self.LogoX -- Align with logo



    self.lDock = vgui.Create("DPanel",self)

    local lDock = self.lDock

    lDock:SetSize(0, 0)

    lDock:SetVisible(false)



    if LocalPlayer and IsValid(LocalPlayer()) then

        LocalPlayer():SetDSP(31) -- Muffled/Underwater effect

    end

    

    -- Play Background Music (Persistent)

    if IsValid(ZCityMainMenuMusic) then

        ZCityMainMenuMusic:Play()

        ZCityMainMenuMusic:SetVolume(0.25) -- Lower volume

    else

        sound.PlayFile("sound/quehice.ogg", "noblock", function(station, errCode, errStr)

            if IsValid(station) then

                station:EnableLooping(true)

                station:SetVolume(0.25) -- Lower volume

                station:Play()

                ZCityMainMenuMusic = station

            else

                print("Error playing menu music:", errCode, errStr)

            end

        end)

    end



    self.Buttons = {}

    self.menuList = vgui.Create("DScrollPanel", self)

    self.menuList:SetPos(self.MenuX, self.MenuTop)

    local maxMenuHeight = math.min(ScrH() - self.MenuTop - ScreenScaleH(40), ScrH() * 0.8)

    self.menuList:SetSize(math.min(self.MenuW, ScrW() * 0.9), maxMenuHeight)

    self.menuList.ButtonHeight = ScreenScaleH(18)

    self.menuList.Spacing = ScreenScaleH(8)

    self.menuList.PushStrong = ScreenScaleH(6)

    self.menuList.PushWeak = ScreenScaleH(3)

    

    if self.IsIntro then

        self.menuList:SetVisible(false)

    end

    

    for k,v in ipairs(Selects) do

        if v.GamemodeOnly and engine.ActiveGamemode() != "zcity" then continue end

        self:AddSelect( self.menuList, v.Title, v )

    end

    self.menuList.PerformLayout = function(panel)

        local y = 0

        local w = panel:GetWide()

        for i, btn in ipairs(self.Buttons) do

            if IsValid(btn) then

                -- btn:SetSize(w, panel.ButtonHeight) -- Don't force width, use content size

                btn:SizeToContents()

                btn:SetWide(btn:GetWide() + ScreenScaleH(8))

                btn:SetTall(math.max(panel.ButtonHeight, btn:GetTall())) -- Use max height

                btn.BaseY = y

                y = y + btn:GetTall() + panel.Spacing

            end

        end

        local canvas = panel:GetCanvas()

        if IsValid(canvas) then

            canvas:SetTall(y)

        end

    end

    self.menuList.Think = function(panel)

        local transitionShake = self.TransitionShakeStrength or 0

        local waveAmp = 0.35 + transitionShake * 1.25

        local baseOffsetX = (self.TransitionShakeX or 0) * 0.22

        local baseOffsetY = (self.TransitionShakeY or 0) * 0.22

        local t = CurTime()

        for i, btn in ipairs(self.Buttons) do

            if IsValid(btn) and btn.BaseY then

                local waveX = math.sin(t * 28 + i * 0.75) * waveAmp

                local waveY = math.cos(t * 24 + i * 0.65) * waveAmp * 0.85

                btn:SetPos(math.Round(baseOffsetX + waveX), btn.BaseY + math.Round(baseOffsetY + waveY))

            end

        end

    end

    self.menuList:InvalidateLayout(true)



    self.rDock = vgui.Create("DPanel",self)

    local rDock = self.rDock

    rDock:SetSize(0, 0)

    rDock:SetVisible(false)

    

    -- Flashing Images Logic

    self.FlashImages = {

        Material("vgui/numerals.png"),

        Material("vgui/pills.png"),

        Material("vgui/knifedark.png")

    }

    self.NextFlashTime = CurTime() + math.random(5, 10)

    self.CurrentFlashImage = nil

    self.FlashState = "Idle" -- Idle, In, Stay, Out

    self.FlashAlpha = 0

    self.FlashStartTime = 0

    self.FlashDurationIn = 1

    self.FlashDurationStay = 3

    self.FlashDurationOut = 2

end



function PANEL:Think()

    if LocalPlayer and IsValid(LocalPlayer()) then

        -- Enforce DSP every frame to prevent decay/override

        LocalPlayer():SetDSP(31, false)

    end

    

    -- Flash Image State Machine

    if self.CurrentState == "Settings" or self.TargetState == "Settings" then

        local ct = CurTime()

        if self.FlashState == "Idle" then

            if ct >= self.NextFlashTime then

                self.FlashState = "In"

                self.CurrentFlashImage = table.Random(self.FlashImages)

                self.FlashStartTime = ct

                self.FlashAlpha = 0

            end

        elseif self.FlashState == "In" then

            local progress = (ct - self.FlashStartTime) / self.FlashDurationIn

            self.FlashAlpha = math.Clamp(progress, 0, 1) * 255

            if progress >= 1 then

                self.FlashState = "Stay"

                self.FlashStartTime = ct

            end

        elseif self.FlashState == "Stay" then

            self.FlashAlpha = 255

            if ct - self.FlashStartTime >= self.FlashDurationStay then

                self.FlashState = "Out"

                self.FlashStartTime = ct

            end

        elseif self.FlashState == "Out" then

            local progress = (ct - self.FlashStartTime) / self.FlashDurationOut

            self.FlashAlpha = math.Clamp(1 - progress, 0, 1) * 255

            if progress >= 1 then

                self.FlashState = "Idle"

                self.NextFlashTime = ct + math.random(5, 15) -- Random interval

                self.CurrentFlashImage = nil

            end

        end

    else

        -- Reset if not in settings

        self.FlashState = "Idle"

        self.CurrentFlashImage = nil

        self.NextFlashTime = CurTime() + math.random(2, 5) -- Shorter delay when returning

    end

    

    if self.IsIntro and not self.IntroSequenceActive then

        -- Auto-start intro sequence immediately
        self.IntroSequenceActive = true
        self.IntroStartTime = CurTime()

        -- Play valve.mp3 sound
        sound.PlayFile("sound/valve.mp3", "noblock noplay", function(station)
            if IsValid(station) then
                station:SetVolume(1)
                station:EnableLooping(false)
                station:Play()
            end
        end)

        ZCityHasSeenIntro = true

        -- Fade out background music if playing
        if IsValid(ZCityMainMenuMusic) then
            local music = ZCityMainMenuMusic
            local duration = 3
            local startTime = CurTime()
            local startVol = music:GetVolume()

            local id = "ZCityMusicFadeOut"
            hook.Add("Think", id, function()
                if not IsValid(music) then hook.Remove("Think", id) return end

                local elapsed = CurTime() - startTime
                local progress = elapsed / duration

                if progress >= 1 then
                    music:SetVolume(0)
                    music:Pause()
                    hook.Remove("Think", id)
                else
                    music:SetVolume(startVol * (1 - progress))
                end
            end)
        end

        -- Auto-fade intro after 5 seconds
        timer.Simple(5, function()
            if IsValid(self) then
                self:AlphaTo(0, 1, 0, function()
                    if IsValid(self) then
                        self:Close()
                    end
                end)
            end
        end)

    end

    

    -- Transition Logic

    self.TransitionProgress = math.min(self.TransitionProgress + FrameTime() * 2, 1) -- 0.5 sec duration



    -- If we are switching between Traitor menus, we force the state update instantly but animate the alpha

    if (self.TargetState == "TraitorMenu" and self.CurrentState == "TraitorPresets") or (self.TargetState == "TraitorPresets" and self.CurrentState == "TraitorMenu") then

        if self.TransitionProgress >= 1 then

            self.CurrentState = self.TargetState

        end

    elseif self.TransitionProgress >= 1 and self.CurrentState ~= self.TargetState then

        self.CurrentState = self.TargetState

        

        -- Finalize transition visibility

        if self.CurrentState == "Settings" then

            if IsValid(self.menuList) then self.menuList:SetVisible(false) end

            if IsValid(self.SettingsList) then self.SettingsList:SetVisible(true) end

            if IsValid(self.AppearancePanel) then self.AppearancePanel:SetVisible(false) end

            if IsValid(self.AchievementsPanel) then self.AchievementsPanel:SetVisible(false) end

            if IsValid(self.TraitorMenuPanel) then self.TraitorMenuPanel:SetVisible(false) end

            if IsValid(self.TraitorPresetsPanel) then self.TraitorPresetsPanel:SetVisible(false) end

        elseif self.CurrentState == "Main" then

            if IsValid(self.menuList) then 

                if not self.IsIntro then

                    self.menuList:SetVisible(true) 

                else

                    self.menuList:SetVisible(false)

                end

            end

            if IsValid(self.SettingsList) then self.SettingsList:SetVisible(false) end

            if IsValid(self.AppearancePanel) then self.AppearancePanel:SetVisible(false) end

            if IsValid(self.AchievementsPanel) then self.AchievementsPanel:SetVisible(false) end

            if IsValid(self.TraitorMenuPanel) then self.TraitorMenuPanel:SetVisible(false) end

            if IsValid(self.TraitorPresetsPanel) then self.TraitorPresetsPanel:SetVisible(false) end

        elseif self.CurrentState == "Appearance" then

            if IsValid(self.menuList) then self.menuList:SetVisible(false) end

            if IsValid(self.SettingsList) then self.SettingsList:SetVisible(false) end

            if IsValid(self.AppearancePanel) then self.AppearancePanel:SetVisible(true) end

            if IsValid(self.AchievementsPanel) then self.AchievementsPanel:SetVisible(false) end

            if IsValid(self.TraitorMenuPanel) then self.TraitorMenuPanel:SetVisible(false) end

        elseif self.CurrentState == "Achievements" then

            if IsValid(self.menuList) then self.menuList:SetVisible(false) end

            if IsValid(self.SettingsList) then self.SettingsList:SetVisible(false) end

            if IsValid(self.AppearancePanel) then self.AppearancePanel:SetVisible(false) end

            if IsValid(self.AchievementsPanel) then self.AchievementsPanel:SetVisible(true) end

            if IsValid(self.TraitorMenuPanel) then self.TraitorMenuPanel:SetVisible(false) end

        elseif self.CurrentState == "TraitorMenu" then

            if IsValid(self.menuList) then self.menuList:SetVisible(false) end

            if IsValid(self.SettingsList) then self.SettingsList:SetVisible(false) end

            if IsValid(self.AppearancePanel) then self.AppearancePanel:SetVisible(false) end

            if IsValid(self.AchievementsPanel) then self.AchievementsPanel:SetVisible(false) end

            if IsValid(self.TraitorMenuPanel) then 

                self.TraitorMenuPanel:SetVisible(true) 

                self.TraitorMenuPanel:SetMouseInputEnabled(true)

            end

            if IsValid(self.TraitorPresetsPanel) then 

                -- Keep visible if we are transitioning to presets

                if self.TargetState ~= "TraitorPresets" then

                    self.TraitorPresetsPanel:SetVisible(false) 

                    self.TraitorPresetsPanel:SetMouseInputEnabled(false)

                end

            end

        elseif self.CurrentState == "TraitorPresets" then

            if IsValid(self.menuList) then self.menuList:SetVisible(false) end

            if IsValid(self.SettingsList) then self.SettingsList:SetVisible(false) end

            if IsValid(self.AppearancePanel) then self.AppearancePanel:SetVisible(false) end

            if IsValid(self.AchievementsPanel) then self.AchievementsPanel:SetVisible(false) end

            if IsValid(self.TraitorMenuPanel) then 

                -- Keep visible if we are transitioning to loadout

                if self.TargetState ~= "TraitorMenu" then

                    self.TraitorMenuPanel:SetVisible(false) 

                    self.TraitorMenuPanel:SetMouseInputEnabled(false)

                end

            end

            if IsValid(self.TraitorPresetsPanel) then 

                self.TraitorPresetsPanel:SetVisible(true) 

                self.TraitorPresetsPanel:SetMouseInputEnabled(true)

            end

        end

    end

    

    -- Calculate Visual T (0 = Main, 1 = Target)

    -- This logic assumes we only transition from Main <-> Something.

    -- If we go Settings <-> Appearance directly, it might be weird, but for now we assume Main is the hub.

    local visual_t = 0

    if self.TargetState == "Settings" or self.TargetState == "Appearance" or self.TargetState == "Achievements" or self.TargetState == "TraitorMenu" or self.TargetState == "TraitorPresets" then

        if (self.TargetState == "TraitorMenu" and self.CurrentState == "TraitorPresets") or (self.TargetState == "TraitorPresets" and self.CurrentState == "TraitorMenu") then

            visual_t = self.TransitionProgress

        else

            visual_t = self.TransitionProgress

        end

    elseif self.TargetState == "Main" then

        visual_t = 1 - self.TransitionProgress

    end

    local eased_t = visual_t * visual_t * (3 - 2 * visual_t)



    local transitionShakeStrength = 0

    if self.CurrentState ~= self.TargetState or self.TransitionProgress < 1 then

        transitionShakeStrength = math.Clamp(1 - math.abs(visual_t - 0.5) * 2, 0, 1)

    end

    self.TransitionShakeStrength = transitionShakeStrength

    local transitionShakeAmount = 4.2 * transitionShakeStrength

    if not self.NextTransitionShakeSample or CurTime() >= self.NextTransitionShakeSample then

        self.NextTransitionShakeSample = CurTime() + 0.035

        self.TargetTransitionShakeX = math.Rand(-transitionShakeAmount, transitionShakeAmount)

        self.TargetTransitionShakeY = math.Rand(-transitionShakeAmount * 0.55, transitionShakeAmount * 0.55)

        self.TargetTransitionImageShakeX = math.Rand(-transitionShakeAmount * 0.8, transitionShakeAmount * 0.8)

        self.TargetTransitionImageShakeY = math.Rand(-transitionShakeAmount * 0.65, transitionShakeAmount * 0.65)

    end

    local shakeLerp = math.Clamp(FrameTime() * 22, 0, 1)

    self.TransitionShakeX = Lerp(shakeLerp, self.TransitionShakeX or 0, self.TargetTransitionShakeX or 0)

    self.TransitionShakeY = Lerp(shakeLerp, self.TransitionShakeY or 0, self.TargetTransitionShakeY or 0)

    self.TransitionImageShakeX = Lerp(shakeLerp, self.TransitionImageShakeX or 0, self.TargetTransitionImageShakeX or 0)

    self.TransitionImageShakeY = Lerp(shakeLerp, self.TransitionImageShakeY or 0, self.TargetTransitionImageShakeY or 0)

    

    -- Alpha handling for buttons during transition

    if IsValid(self.menuList) then

        if self.IsIntro then

            self.menuList:SetVisible(false)

        else

            if self.TargetState == "Settings" or self.TargetState == "Appearance" or self.TargetState == "Achievements" or self.TargetState == "TraitorMenu" or self.TargetState == "TraitorPresets" then

                if self.CurrentState ~= "Main" then

                    self.menuList:SetAlpha(255)

                    self.menuList:SetVisible(false)

                else

                    self.menuList:SetAlpha(255)

                    -- Don't hide it, let it move offscreen

                end

            elseif self.TargetState == "Main" then

                self.menuList:SetVisible(true)

                self.menuList:SetAlpha(255)

            end

        end

    end

    

    if IsValid(self.SettingsList) then

        if self.TargetState == "Settings" then

            self.SettingsList:SetVisible(true)

            self.SettingsList:SetAlpha(255 * visual_t)

            if IsValid(self.SettingsReturnBtn) then

                self.SettingsReturnBtn:SetVisible(true)

                self.SettingsReturnBtn:SetAlpha(255 * visual_t)

            end

        elseif self.TargetState == "Main" and self.CurrentState == "Settings" then

             -- Fade out quickly

             local alpha = math.Clamp(1 - ((1 - visual_t) * 3), 0, 1) * 255

             self.SettingsList:SetAlpha(alpha)

             if alpha <= 0 then self.SettingsList:SetVisible(false) end

             

             if IsValid(self.SettingsReturnBtn) then

                self.SettingsReturnBtn:SetAlpha(alpha)

                if alpha <= 0 then self.SettingsReturnBtn:SetVisible(false) end

             end

        end

    end



    if IsValid(self.AppearancePanel) then

        if self.TargetState == "Appearance" then

            self.AppearancePanel:SetVisible(true)

            self.AppearancePanel:SetAlpha(255 * visual_t)

        elseif self.TargetState == "Main" and self.CurrentState == "Appearance" then

             -- Fade out quickly

             local alpha = math.Clamp(1 - ((1 - visual_t) * 3), 0, 1) * 255

             self.AppearancePanel:SetAlpha(alpha)

             if alpha <= 0 then self.AppearancePanel:SetVisible(false) end

        end

    end



    if IsValid(self.AchievementsPanel) then

        if self.TargetState == "Achievements" then

            self.AchievementsPanel:SetVisible(true)

            self.AchievementsPanel:SetAlpha(255 * visual_t)

        elseif self.TargetState == "Main" and self.CurrentState == "Achievements" then

            local alpha = math.Clamp(1 - ((1 - visual_t) * 3), 0, 1) * 255

            self.AchievementsPanel:SetAlpha(alpha)

            if alpha <= 0 then self.AchievementsPanel:SetVisible(false) end

        end

    end



    if IsValid(self.TraitorMenuPanel) then

        if self.TargetState == "TraitorMenu" or self.TargetState == "TraitorPresets" or (self.TargetState == "Main" and (self.CurrentState == "TraitorMenu" or self.CurrentState == "TraitorPresets")) then

            self.TraitorMenuPanel:SetVisible(true)

        else

            self.TraitorMenuPanel:SetVisible(false)

        end

    end



    if IsValid(self.TraitorPresetsPanel) then

        if self.TargetState == "TraitorMenu" or self.TargetState == "TraitorPresets" or (self.TargetState == "Main" and (self.CurrentState == "TraitorMenu" or self.CurrentState == "TraitorPresets")) then

            self.TraitorPresetsPanel:SetVisible(true)

        else

            self.TraitorPresetsPanel:SetVisible(false)

        end

    end



    if IsValid(self.menuList) then

        local y = self.MenuTop

        local x = self.MenuX

        if self.CurrentState ~= "Main" and self.TargetState ~= "Main" then

            if (self.CurrentState == "TraitorMenu" or self.CurrentState == "TraitorPresets") and (self.TargetState == "TraitorMenu" or self.TargetState == "TraitorPresets") then

                y = self.MenuTop + ScrH()

                self.menuList:SetVisible(false)

            else

                y = self.MenuTop - ScrH()

                if self.CurrentState == "Achievements" or self.TargetState == "Achievements" then

                    x = self.MenuX + ScrW()

                    y = self.MenuTop

                end

            end

        else

            if self.TargetState == "Appearance" or (self.TargetState == "Main" and self.CurrentState == "Appearance") then

                y = self.MenuTop - ScrH() * eased_t

            elseif self.TargetState == "Settings" or (self.TargetState == "Main" and self.CurrentState == "Settings") then

                x = self.MenuX - ScrW() * eased_t

            elseif self.TargetState == "Achievements" or (self.TargetState == "Main" and self.CurrentState == "Achievements") then

                x = self.MenuX + ScrW() * eased_t

            elseif self.TargetState == "TraitorMenu" or (self.TargetState == "Main" and self.CurrentState == "TraitorMenu") or self.TargetState == "TraitorPresets" or (self.TargetState == "Main" and self.CurrentState == "TraitorPresets") then

                y = self.MenuTop + ScrH() * eased_t

            end

        end

        self.menuList:SetPos(x + (self.TransitionShakeX or 0), y + (self.TransitionShakeY or 0))

    end



    if IsValid(self.AppearancePanel) then

        if self.TargetState == "Appearance" or (self.TargetState == "Main" and self.CurrentState == "Appearance") then

            self.AppearancePanel:SetPos(self.TransitionShakeX or 0, ScrH() * (1 - eased_t) + (self.TransitionShakeY or 0))

        else

            self.AppearancePanel:SetPos(0 + (self.TransitionShakeX or 0), 0 + (self.TransitionShakeY or 0))

        end

    end



    if IsValid(self.SettingsList) then

        if self.TargetState == "Settings" or (self.TargetState == "Main" and self.CurrentState == "Settings") then

            self.SettingsList:SetPos(self.MenuX + ScrW() * (1 - eased_t) + (self.TransitionShakeX or 0), self.MenuTop + (self.TransitionShakeY or 0))

        else

            self.SettingsList:SetPos(self.MenuX + (self.TransitionShakeX or 0), self.MenuTop + (self.TransitionShakeY or 0))

        end

    end



    if IsValid(self.SettingsReturnBtn) then

        local baseX = self.SettingsReturnBtn.BaseX or ScreenScale(20)

        local baseY = self.SettingsReturnBtn.BaseY or (ScrH() - ScreenScale(40))

        if self.TargetState == "Settings" or (self.TargetState == "Main" and self.CurrentState == "Settings") then

            self.SettingsReturnBtn:SetPos(baseX + ScrW() * (1 - eased_t) + (self.TransitionShakeX or 0), baseY + (self.TransitionShakeY or 0))

        else

            self.SettingsReturnBtn:SetPos(baseX + (self.TransitionShakeX or 0), baseY + (self.TransitionShakeY or 0))

        end

    end



    if IsValid(self.AchievementsPanel) then

        if self.TargetState == "Achievements" or (self.TargetState == "Main" and self.CurrentState == "Achievements") then

            self.AchievementsPanel:SetPos(-ScrW() * (1 - eased_t) + (self.TransitionShakeX or 0), 0 + (self.TransitionShakeY or 0))

        else

            self.AchievementsPanel:SetPos(0 + (self.TransitionShakeX or 0), 0 + (self.TransitionShakeY or 0))

        end

    end



    if IsValid(self.TraitorMenuPanel) then

        if self.TargetState == "TraitorMenu" then

            if self.CurrentState == "TraitorPresets" then

                self.TraitorMenuPanel:SetAlpha(255 * visual_t)

                self.TraitorMenuPanel:SetPos(0, 0)

                self.TraitorMenuPanel:SetMouseInputEnabled(true)

            else

                self.TraitorMenuPanel:SetAlpha(255 * visual_t)

                self.TraitorMenuPanel:SetPos(0, -ScrH() * (1 - visual_t))

                self.TraitorMenuPanel:SetMouseInputEnabled(true)

            end

            self.TraitorMenuPanel:SetVisible(true)

        elseif self.TargetState == "Main" and self.CurrentState == "TraitorMenu" then

            self.TraitorMenuPanel:SetAlpha(255)

            self.TraitorMenuPanel:SetPos(0, -ScrH() * (1 - visual_t))

            self.TraitorMenuPanel:SetMouseInputEnabled(false)

        elseif self.TargetState == "TraitorPresets" and self.CurrentState == "TraitorMenu" then

            self.TraitorMenuPanel:SetAlpha(255 * (1 - visual_t))

            self.TraitorMenuPanel:SetPos(0, 0)

            self.TraitorMenuPanel:SetMouseInputEnabled(false)

            self.TraitorMenuPanel:SetVisible(true)

        else

            if self.CurrentState ~= "TraitorMenu" then

                self.TraitorMenuPanel:SetAlpha(0)

                self.TraitorMenuPanel:SetPos(0, 0)

                self.TraitorMenuPanel:SetVisible(false)

            end

        end

    end



    if IsValid(self.TraitorPresetsPanel) then

        if self.TargetState == "TraitorPresets" then

            if self.CurrentState == "TraitorMenu" then

                self.TraitorPresetsPanel:SetAlpha(255 * visual_t)

                self.TraitorPresetsPanel:SetPos(0, 0)

                self.TraitorPresetsPanel:SetMouseInputEnabled(false)

            else

                self.TraitorPresetsPanel:SetAlpha(255 * visual_t)

                self.TraitorPresetsPanel:SetPos(0, -ScrH() * (1 - visual_t))

                self.TraitorPresetsPanel:SetMouseInputEnabled(true)

            end

            self.TraitorPresetsPanel:SetVisible(true)

        elseif self.TargetState == "Main" and self.CurrentState == "TraitorPresets" then

            self.TraitorPresetsPanel:SetAlpha(255)

            self.TraitorPresetsPanel:SetPos(0, -ScrH() * (1 - visual_t))

            self.TraitorPresetsPanel:SetMouseInputEnabled(false)

        elseif self.TargetState == "TraitorMenu" and self.CurrentState == "TraitorPresets" then

            self.TraitorPresetsPanel:SetAlpha(255 * (1 - visual_t))

            self.TraitorPresetsPanel:SetPos(0, 0)

            self.TraitorPresetsPanel:SetMouseInputEnabled(false)

            self.TraitorPresetsPanel:SetVisible(true)

        else

            if self.CurrentState ~= "TraitorPresets" then

                self.TraitorPresetsPanel:SetAlpha(0)

                self.TraitorPresetsPanel:SetPos(0, 0)

                self.TraitorPresetsPanel:SetVisible(false)

            end

        end

    end

end



function PANEL:SwitchToSettings()

    self.TargetState = "Settings"

    self.TransitionProgress = 0

    self:CreateSettingsPanel()

end



function PANEL:FadeMusic(channel, targetVolume, duration, onComplete)

    if not IsValid(channel) then return end

    

    local startVolume = channel:GetVolume()

    local startTime = CurTime()

    local id = "ZCityMusicFade_" .. tostring(channel)

    

    hook.Add("Think", id, function()

        if not IsValid(channel) then hook.Remove("Think", id) return end

        

        local elapsed = CurTime() - startTime

        local progress = math.Clamp(elapsed / duration, 0, 1)

        

        channel:SetVolume(Lerp(progress, startVolume, targetVolume))

        

        if progress >= 1 then

            hook.Remove("Think", id)

            if onComplete then onComplete() end

        end

    end)

end



function PANEL:SwitchToAppearance()

    self.TargetState = "Appearance"

    self.TransitionProgress = 0

    self:CreateAppearancePanel()

    

    -- Music Transition

    if IsValid(ZCityMainMenuMusic) then

        self:FadeMusic(ZCityMainMenuMusic, 0, 1, function()

            if IsValid(ZCityMainMenuMusic) then ZCityMainMenuMusic:Pause() end

        end)

    end

    

    if IsValid(ZCityAppearanceMusic) then

        ZCityAppearanceMusic:Play()

        ZCityAppearanceMusic:SetVolume(0)

        self:FadeMusic(ZCityAppearanceMusic, 1, 1)

    else

        sound.PlayFile("sound/sexualdeviants.mp3", "noblock", function(station, errCode, errStr)

            if IsValid(station) then

                station:EnableLooping(true)

                station:SetVolume(0)

                station:Play()

                self:FadeMusic(station, 1, 1)

                ZCityAppearanceMusic = station

            else

                print("Error playing appearance music (sound/sexualdeviants.mp3):", errCode, errStr)

                -- Try without sound/ prefix just in case

                sound.PlayFile("sexualdeviants.mp3", "noblock", function(station2, errCode2, errStr2)

                    if IsValid(station2) then

                        station2:EnableLooping(true)

                        station2:SetVolume(0)

                        station2:Play()

                        self:FadeMusic(station2, 1, 1)

                        ZCityAppearanceMusic = station2

                    else

                         print("Error playing appearance music fallback (sexualdeviants.mp3):", errCode2, errStr2)

                    end

                end)

            end

        end)

    end

end



function PANEL:SwitchToTraitorMenu()

    if self.CurrentState == "TraitorPresets" then

        self.TargetState = "TraitorMenu"

        self.TransitionProgress = 0

    else

        self.TargetState = "TraitorMenu"

        self.TransitionProgress = 0

    end

    self:CreateTraitorMenuPanel()

end



function PANEL:SwitchToTraitorPresets()

    if self.CurrentState == "TraitorMenu" then

        self.TargetState = "TraitorPresets"

        self.TransitionProgress = 0

    else

        self.TargetState = "TraitorPresets"

        self.TransitionProgress = 0

    end

    self:CreateTraitorMenuPanel()

end



function PANEL:SwitchToAchievements()

    self.TargetState = "Achievements"

    self.TransitionProgress = 0

    self:CreateAchievementsPanel()

    if hg and hg.achievements and hg.achievements.LoadAchievements then

        hg.achievements.LoadAchievements()

    end

end



function PANEL:SwitchToMain()

    self.TargetState = "Main"

    self.TransitionProgress = 0

    

    -- Music Transition

    if IsValid(ZCityAppearanceMusic) then

        self:FadeMusic(ZCityAppearanceMusic, 0, 1, function()

            if IsValid(ZCityAppearanceMusic) then ZCityAppearanceMusic:Stop() end

        end)

    end

    

    if IsValid(ZCityMainMenuMusic) then

        ZCityMainMenuMusic:Play()

        self:FadeMusic(ZCityMainMenuMusic, 0.5, 1) -- Return to 0.5 as per Init

    end

end



function PANEL:CreateSettingsPanel()

    if IsValid(self.SettingsList) then return end

    

    self.SettingsList = vgui.Create("DScrollPanel", self)

    self.SettingsList:SetPos(self.MenuX, self.MenuTop)

    -- Extend width to cover more of the screen (e.g., 75% of screen width)

    local maxSettingsHeight = math.min(ScrH() - self.MenuTop - ScreenScale(60), ScrH() * 0.8)

    self.SettingsList:SetSize(math.min(ScrW() * 0.75, ScrW() * 0.9), maxSettingsHeight)

    self.SettingsList:SetAlpha(0)

    self.SettingsList:SetVisible(false)

    self.SettingsList.ButtonHeight = ScreenScale(18)

    self.SettingsList.Spacing = ScreenScale(8)

    

    -- "hg_settings" Integration

    -- Iterate over hg.settings.tbl categories

    if hg and hg.settings and hg.settings.tbl then

        for categoryName, items in SortedPairs(hg.settings.tbl) do

            -- Category Header

            local catLbl = vgui.Create("DLabel", self.SettingsList)

            catLbl:SetText(string.lower(categoryName))

            catLbl:SetFont("ZCity_Veteran")

            catLbl:SizeToContentsY()

            catLbl:Dock(TOP)

            catLbl:SetTextColor(Color(255, 0, 0)) -- Red for categories

            catLbl:DockMargin(0, ScreenScale(5), 0, ScreenScale(2))

            

            for _, item in SortedPairs(items) do

                local conVarName = item[2]

                local title = item[3]

                local isBool = (GetConVar(conVarName) and GetConVar(conVarName):GetMax() == 1) or false

                local conVar = GetConVar(conVarName)

                

                if not conVar then continue end

                

                local pnl = vgui.Create("DPanel", self.SettingsList)

                pnl:SetTall(ScreenScale(25))

                pnl:Dock(TOP)

                pnl:DockMargin(0, 0, 0, ScreenScale(2))

                pnl.Paint = function() end -- Transparent background

                

                local lbl = vgui.Create("DLabel", pnl)

                lbl:SetText(string.lower(title))

                lbl:SetFont("ZCity_Veteran")

                lbl:SizeToContentsY()

                lbl:Dock(LEFT)

                lbl:SetTextColor(Color(200, 200, 200))

                lbl:SetWide(self.SettingsList:GetWide() * 0.6) -- Dynamic width based on panel size

                lbl:SetWrap(false) -- Ensure it doesn't wrap weirdly, but width should be enough now

                

                pnl:SetTall(math.max(ScreenScale(25), lbl:GetTall() + ScreenScale(4)))

                

                if isBool then

                    -- Container for Off/On buttons

                    local toggleContainer = vgui.Create("DPanel", pnl)

                    toggleContainer:Dock(RIGHT)

                    toggleContainer:SetWide(ScreenScale(80))

                    toggleContainer.Paint = function() end



                    local btnOn = vgui.Create("DButton", toggleContainer)

                    local btnOff = vgui.Create("DButton", toggleContainer)



                    -- Helper to update visuals

                    local function UpdateToggleVisuals()

                        local state = conVar:GetBool()

                        

                        -- Off Button

                        btnOff.Paint = function(s, w, h)

                            if not state then -- Active (OFF is active)

                                surface.SetDrawColor(255, 255, 255, 255)

                                surface.DrawRect(0, 0, w, h)

                                s:SetTextColor(Color(0, 0, 0))

                            else -- Inactive

                                surface.SetDrawColor(0, 0, 0, 0)

                                -- surface.DrawRect(0, 0, w, h)

                                s:SetTextColor(Color(255, 255, 255))

                            end

                        end



                        -- On Button

                        btnOn.Paint = function(s, w, h)

                            if state then -- Active (ON is active)

                                surface.SetDrawColor(255, 255, 255, 255)

                                surface.DrawRect(0, 0, w, h)

                                s:SetTextColor(Color(0, 0, 0))

                            else -- Inactive

                                surface.SetDrawColor(0, 0, 0, 0)

                                -- surface.DrawRect(0, 0, w, h)

                                s:SetTextColor(Color(255, 255, 255))

                            end

                        end

                    end



                    -- Setup Off Button

                    btnOff:SetText("off")

                    btnOff:SetFont("ZCity_Veteran")

                    btnOff:Dock(LEFT)

                    btnOff:SetWide(ScreenScale(35))

                    btnOff:DockMargin(0, 0, ScreenScale(4), 0)

                    btnOff.DoClick = function()

                        conVar:SetBool(false)

                        UpdateToggleVisuals()

                        sound.PlayFile("sound/press3.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

                    end



                    -- Setup On Button

                    btnOn:SetText("on")

                    btnOn:SetFont("ZCity_Veteran")

                    btnOn:Dock(LEFT) -- Next to Off

                    btnOn:SetWide(ScreenScale(35))

                    btnOn.DoClick = function()

                        conVar:SetBool(true)

                        UpdateToggleVisuals()

                        sound.PlayFile("sound/press3.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

                    end



                    UpdateToggleVisuals()

                else

                    -- Slider for non-bools

                    local slider = vgui.Create("DNumSlider", pnl)

                    slider:Dock(RIGHT)

                    slider:SetWide(self.SettingsList:GetWide() * 0.4) -- Use remaining space

                    slider:SetMin(conVar:GetMin() or 0)

                    slider:SetMax(conVar:GetMax() or 100)

                    slider:SetDecimals(item[4] and 2 or 0)

                    slider:SetConVar(conVarName)

                    -- Ensure value is initialized immediately for visual alignment

                    if conVar then slider:SetValue(conVar:GetFloat()) end

                    slider.Label:SetVisible(false) -- Hide default label

                    

                    -- Custom Slider Styling (Manhunt 2 Style / Long Box)

                    slider.TextArea:SetFont("ZCity_Veteran")

                    local faintWhite = Color(255, 255, 255, 150) -- Faint white (Increased visibility)

                    slider.TextArea:SetTextColor(faintWhite)

                    slider.TextArea.Paint = function(s, w, h)

                        -- Transparent background for text area

                        s:DrawTextEntryText(faintWhite, Color(200, 200, 200), faintWhite)

                    end

                    

                    slider.Slider.Paint = function(s, w, h)

                        -- White Outline

                        surface.SetDrawColor(255, 255, 255, 255)

                        surface.DrawOutlinedRect(0, h/2 - ScreenScale(6), w, ScreenScale(12), 1)

                        

                        -- Black Empty Space (Background of the bar)

                        surface.SetDrawColor(0, 0, 0, 255)

                        surface.DrawRect(1, h/2 - ScreenScale(6) + 1, w - 2, ScreenScale(12) - 2)

                        

                        -- White Fill

                        local val = s:GetValue() -- Get fractional value (0-1)

                        -- DNumSlider's Slider is a DSlider, which has m_fValue (0-1)

                        -- But we can also calculate it if needed. s.m_fSlideX is usually the knob position.

                        

                        -- Let's rely on s.m_fSlideX which is updated by DSlider

                        local fillW = math.Clamp(s.m_fSlideX * (w - 2), 0, w - 2)

                        

                        surface.SetDrawColor(255, 255, 255, 255)

                        surface.DrawRect(1, h/2 - ScreenScale(6) + 1, fillW, ScreenScale(12) - 2)

                    end

                    

                    -- Hide Knob (or make it invisible as the fill represents the value)

                    slider.Slider.Knob.Paint = function(s, w, h)

                        -- Invisible knob

                    end

                end

            end

        end

    end

    

    -- Add Return Button at the bottom (Separate from scroll list)

    if not IsValid(self.SettingsReturnBtn) then

        local btn = vgui.Create("DLabel", self)

        self.SettingsReturnBtn = btn

        btn:SetText("return")

        btn:SetMouseInputEnabled(true)

        btn:SetFont("ZCity_Veteran")

        btn:SetTall(ScreenScale(18))

        btn:SizeToContents()

        btn:SetWide(btn:GetWide() + ScreenScale(8))

        btn.BaseX = ScreenScale(20)

        btn.BaseY = ScrH() - ScreenScaleH(40)

        btn:SetPos(btn.BaseX, btn.BaseY)

        btn:SetTextColor(Color(255, 255, 255))

        btn:SetAlpha(0)

        btn:SetVisible(false)

        

        btn.DoClick = function()

            sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

            self:SwitchToMain()

        end

        

        -- Add paint method for hover effect

        btn.Paint = function(self, w, h)

            local font = self:GetFont()

            local text = self:GetText()

            surface.SetFont(font)

            local tw, th = surface.GetTextSize(text)



            if self:IsHovered() then

                if not self.HoveredSoundPlayed then

                    sound.PlayFile("sound/hover.ogg", "noblock", function(station) if IsValid(station) then station:Play() end end)

                    self.HoveredSoundPlayed = true

                end

                

                local alpha = 255

                if math.random() > 0.9 then alpha = math.random(50, 200) end

                

                surface.SetDrawColor(255, 255, 255, alpha)

                surface.DrawRect(0, 0, tw, h)

                self:SetTextColor(Color(0, 0, 0, alpha))

            else

                self.HoveredSoundPlayed = false

                self:SetTextColor(Color(255, 255, 255))

            end

            

            local offX, offY = 0, 0

            if math.random() > 0.9 then

                 offX = math.random(-2, 2)

                 offY = math.random(-2, 2)

            end

            

            draw.SimpleText(text, font, offX, h/2 + offY, self:GetTextColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            

            if self:IsHovered() and math.random() > 0.7 then

                local offsetX = math.random(-5, 5)

                local offsetY = math.random(-2, 2)

                draw.SimpleText(text, font, offsetX, h/2 + offsetY, Color(0, 0, 0, math.random(50, 150)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            end

            return true

        end

    end

end



function PANEL:CreateAchievementButton(parent, ach)

    local button = vgui.Create("DPanel", parent)

    ach.img = isstring(ach.img) and Material(ach.img) or ach.img

    button:SetMouseInputEnabled(true)

    button:SetTall(ScreenScale(45))

    button:Dock(TOP)

    button:DockMargin(0, 0, 0, ScreenScale(6))

    button.Padding = ScreenScale(10)



    -- Hover State

    button.IsHoveredState = false

    button.OnCursorEntered = function(s)

        s.IsHoveredState = true

        sound.PlayFile("sound/hover.ogg", "noblock", function(station) if IsValid(station) then station:Play() end end)

    end

    button.OnCursorExited = function(s)

        s.IsHoveredState = false

    end



    function button:UpdateDesc()

        local width = self:GetWide() - self.Padding * 2

        if width <= 0 then return end

        if self.DescWidth == width then return end

        self.DescWidth = width

        -- Faint gray description

        self.DescMarkup = markup.Parse("<font=ZCity_Small><color=180,180,180>" .. string.lower(ach.description) .. "</color></font>", width)

    end



    function button:PerformLayout()

        self:UpdateDesc()

    end



    function button:Paint(w, h)

        self:UpdateDesc()

        self.lerpcolor = Lerp(FrameTime() * 10, self.lerpcolor or 0, 0)



        local localach = hg.achievements.GetLocalAchievements()

        local val = localach and localach[ach.key] and localach[ach.key].value or ach.start_value

        local progress = math.Clamp(val / ach.needed_value, 0, 1)



        -- Background (Faint Black/Transparent)

        surface.SetDrawColor(0, 0, 0, 100)

        surface.DrawRect(0, 0, w, h)

        

        -- Hover Flash

        if self.IsHoveredState then

            local alpha = math.random(20, 40)

            surface.SetDrawColor(255, 255, 255, alpha)

            surface.DrawRect(0, 0, w, h)

        end

        

        -- Border (Faint White)

        surface.SetDrawColor(255, 255, 255, 30)

        surface.DrawOutlinedRect(0, 0, w, h)



        -- Progress Bar (Bottom)

        local barH = ScreenScale(3)

        -- Bar Background

        surface.SetDrawColor(0, 0, 0, 200)

        surface.DrawRect(1, h - barH - 1, w - 2, barH)

        

        -- Bar Fill (Faint White)

        surface.SetDrawColor(255, 255, 255, 150)

        surface.DrawRect(1, h - barH - 1, (w - 2) * progress, barH)



        -- Text Handling

        local nameColor = Color(235, 235, 235)

        local percentText = ach.showpercent and (math.floor(progress * 100) .. "%") or ""

        

        -- Shake effect on hover

        local shakeX, shakeY = 0, 0

        if self.IsHoveredState and math.random() > 0.8 then

            shakeX = math.random(-1, 1)

            shakeY = math.random(-1, 1)

        end



        draw.SimpleText(string.lower(ach.name), "ZCity_Veteran", self.Padding + shakeX, ScreenScale(4) + shakeY, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        

        if percentText ~= "" then

            surface.SetFont("ZCity_Veteran")

            local tw = surface.GetTextSize(percentText)

            draw.SimpleText(percentText, "ZCity_Veteran", w - self.Padding - tw + shakeX, ScreenScale(4) + shakeY, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        end



        if self.DescMarkup then

            -- markup:Draw(x, y, alignx, aligny, alpha)

            self.DescMarkup:Draw(self.Padding + shakeX, ScreenScale(22) + shakeY, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 255)

        end

    end



    return button

end



function PANEL:UpdateAchievementsList()

    if not IsValid(self.AchievementsScroll) then return end

    self.AchievementsScroll:Clear()



    for i, ach in pairs(hg.achievements.achievements_data.created_achevements) do

        self.AchievementsScroll:AddItem(self:CreateAchievementButton(self.AchievementsScroll, ach))

    end

end



function PANEL:CreateAchievementsPanel()

    if IsValid(self.AchievementsPanel) then return end



    self.AchievementsPanel = vgui.Create("DPanel", self)

    self.AchievementsPanel:SetSize(ScrW(), ScrH())

    self.AchievementsPanel:SetPos(0, 0)

    self.AchievementsPanel:SetAlpha(0)

    self.AchievementsPanel:SetVisible(false)

    self.AchievementsPanel.Paint = function() end



    local listW = math.max(ScreenScale(320), ScrW() * 0.6)

    local listX = ScreenScale(28)

    local listY = ScreenScaleH(80) -- Moved up since title is gone

    local listH = math.max(ScrH() * 0.5, ScrH() - listY - ScreenScaleH(80))



    self.AchievementsScroll = vgui.Create("DScrollPanel", self.AchievementsPanel)

    self.AchievementsScroll:SetPos(listX, listY)

    self.AchievementsScroll:SetSize(listW, listH)



    local sbar = self.AchievementsScroll:GetVBar()

    sbar:SetHideButtons(true)

    function sbar:Paint(w, h)

        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 80))

    end

    function sbar.btnGrip:Paint(w, h)

        self.lerpcolor = Lerp(FrameTime() * 10, self.lerpcolor or 0.2, (self:IsHovered() and 0.8 or 0.6))

        draw.RoundedBox(0, 0, 0, w, h, Color(140 * self.lerpcolor, 120 * self.lerpcolor, 90 * self.lerpcolor))

    end



    local btn = vgui.Create("DLabel", self.AchievementsPanel)

    btn:SetText("return")

    btn:SetMouseInputEnabled(true)

    btn:SetFont("ZCity_Veteran")

    btn:SetTall(ScreenScale(18))

    btn:SizeToContents()

    local padding = ScreenScale(4)

    btn:SetWide(btn:GetWide() + padding * 2)

    btn:SetPos(ScreenScale(20), ScrH() - ScreenScaleH(40))

    btn:SetTextColor(Color(255, 255, 255))

    btn.DoClick = function()

        sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

        self:SwitchToMain()

    end



    btn.Paint = function(self, w, h)

        local font = self:GetFont()

        local text = self:GetText()

        surface.SetFont(font)

        local tw, th = surface.GetTextSize(text)



        if self:IsHovered() then

            if not self.HoveredSoundPlayed then

                sound.PlayFile("sound/hover.ogg", "noblock", function(station) if IsValid(station) then station:Play() end end)

                self.HoveredSoundPlayed = true

            end

            

            local alpha = 255

            if math.random() > 0.9 then alpha = math.random(50, 200) end

            

            surface.SetDrawColor(255, 255, 255, alpha)

            surface.DrawRect(padding, 0, tw, h)

            self:SetTextColor(Color(0, 0, 0, alpha))

        else

            self.HoveredSoundPlayed = false

            self:SetTextColor(Color(255, 255, 255))

        end

        

        local offX, offY = 0, 0

        if math.random() > 0.9 then

             offX = math.random(-2, 2)

             offY = math.random(-2, 2)

        end

        

        draw.SimpleText(text, font, padding + offX, h/2 + offY, self:GetTextColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        

        if self:IsHovered() and math.random() > 0.7 then

            local offsetX = math.random(-5, 5)

            local offsetY = math.random(-2, 2)

            draw.SimpleText(text, font, padding + offsetX, h/2 + offsetY, Color(0, 0, 0, math.random(50, 150)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        end

        return true

    end



    self:UpdateAchievementsList()

end



function PANEL:CreateTraitorMenuPanel()

    if IsValid(self.TraitorMenuPanel) then return end



    self.TraitorMenuPanel = vgui.Create("DPanel", self)

    self.TraitorMenuPanel:SetSize(ScrW(), ScrH())

    self.TraitorMenuPanel:SetPos(0, 0)

    self.TraitorMenuPanel:SetAlpha(0)

    self.TraitorMenuPanel:SetVisible(false)



    self.TraitorMenuPanel.Paint = function(pnl, w, h)

        local progress = self.TransitionProgress

        if self.TargetState == "Main" then

            progress = 1 - self.TransitionProgress

        end

        surface.SetDrawColor(10, 10, 15, 150)

        surface.DrawRect(0, 0, w, h)

    end



    local outerMargin = math.max(ScreenScale(10), 10)

    local availableW = math.max(ScrW() - outerMargin * 2, 260)

    local topMargin = math.Clamp(ScreenScaleH(80), 24, ScrH() * 0.2)

    local bottomMargin = math.Clamp(ScreenScaleH(60), 20, ScrH() * 0.15)

    local listH = math.Clamp(ScrH() - topMargin - bottomMargin, 180, math.max(ScrH() - 20, 180))

    local listY = math.max((ScrH() - listH) * 0.5, 10)



    local presetsW = math.Clamp(ScrW() * 0.54, 340, availableW)

    local presetsX = math.max((ScrW() - presetsW) * 0.5, outerMargin)



    local gapW = math.Clamp(ScreenScale(12), 8, 20)

    local desiredInfoW = math.Clamp(ScrW() * 0.32, 240, ScrW() * 0.54)

    local desiredLoadoutW = math.Clamp(ScrW() * 0.5, 340, ScrW() * 0.74)

    local desiredTotalW = desiredInfoW + gapW + desiredLoadoutW

    local infoW = desiredInfoW

    local loadoutW = desiredLoadoutW



    if desiredTotalW > availableW then

        local widthWithoutGap = math.max(availableW - gapW, 320)

        local totalWithoutGap = math.max(desiredInfoW + desiredLoadoutW, 1)

        infoW = math.max(180, math.floor(widthWithoutGap * (desiredInfoW / totalWithoutGap)))

        loadoutW = math.max(140, widthWithoutGap - infoW)

    end



    local traitorTotalW = math.min(infoW + gapW + loadoutW, availableW)

    local traitorX = math.max((ScrW() - traitorTotalW) * 0.5, outerMargin)



    -- Left Panel: Presets (Separate from sliding TraitorMenuPanel)

    self.TraitorPresetsPanel = vgui.Create("DPanel", self)

    self.TraitorPresetsPanel:SetSize(ScrW(), ScrH())

    self.TraitorPresetsPanel:SetPos(0, 0)

    self.TraitorPresetsPanel:SetAlpha(0)

    self.TraitorPresetsPanel:SetVisible(false)

    self.TraitorPresetsPanel.Paint = function(pnl, w, h)

        surface.SetDrawColor(10, 10, 15, 150)

        surface.DrawRect(0, 0, w, h)

    end

    

    local leftPanel = vgui.Create("DPanel", self.TraitorPresetsPanel)

    leftPanel:SetPos(presetsX, listY)

    leftPanel:SetSize(presetsW, listH)

    leftPanel.Paint = function(pnl, w, h)

        draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 10, 230))

        surface.SetDrawColor(200, 200, 200, 150)

        surface.DrawOutlinedRect(0, 0, w, h, 2)

    end



    local infoPanel = vgui.Create("DPanel", self.TraitorMenuPanel)

    infoPanel:SetPos(traitorX, listY)

    infoPanel:SetSize(infoW, listH)

    infoPanel.Paint = function(pnl, w, h)

        draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 10, 230))

        surface.SetDrawColor(200, 200, 200, 150)

        surface.DrawOutlinedRect(0, 0, w, h, 2)

    end



    local rightPanel = vgui.Create("DPanel", self.TraitorMenuPanel)

    rightPanel:SetPos(traitorX + infoW + gapW, listY)

    rightPanel:SetSize(loadoutW, listH)

    rightPanel.Paint = function(pnl, w, h)

        draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 10, 230))

        surface.SetDrawColor(200, 200, 200, 150)

        surface.DrawOutlinedRect(0, 0, w, h, 2)

    end



    -- State

    local savedData = file.Read("meleecity_traitor_loadout.txt", "DATA")

    local parsedLoadout = nil

    if isstring(savedData) and savedData ~= "" then

        local ok, parsed = pcall(util.JSONToTable, savedData)

        if ok and istable(parsed) then

            parsedLoadout = parsed

        end

    end



    local TraitorItems = {

        ["weapon_pl15"] = {cost = 15, name = "PL-15"},

        ["weapon_buck200knife"] = {cost = 3, name = "Buck 200 Knife"},

        ["weapon_sogknife"] = {cost = 3, name = "SOG Knife"},

        ["weapon_fiberwire"] = {cost = 3, name = "Fiber Wire"},

        ["weapon_hg_rgd_tpik"] = {cost = 6, name = "RGD-5 Grenade"},

        ["weapon_adrenaline"] = {cost = 4, name = "Epipen"},

        ["weapon_pepperspray_tpik"] = {cost = 4, name = "Pepper Spray"},

        ["weapon_hg_shuriken"] = {cost = 2, name = "Shuriken"},

        ["weapon_hg_smokenade_tpik"] = {cost = 3, name = "Smoke Grenade"},

        ["weapon_traitor_ied"] = {cost = 6, name = "IED"},

        ["weapon_traitor_poison1"] = {cost = 3, name = "Tetrodotoxin Syringe"},

        ["weapon_traitor_poison2"] = {cost = 2, name = "VX vial"},

        ["weapon_traitor_poison4"] = {cost = 3, name = "Curare vial"},

        ["weapon_traitor_poison3"] = {cost = 6, name = "Cyanide Canister"},

        ["weapon_traitor_suit"] = {cost = 5, name = "Traitor Suit"},

        ["weapon_hg_jam"] = {cost = 1, name = "Door Jam"},

        ["weapon_p22"] = {cost = 8, name = "Walther P22"},

        ["weapon_taser"] = {cost = 8, name = "Taser"},

    }

    local TraitorAddons = {

        ["weapon_p22_extra_mag"] = {cost = 2, name = "P22 Extra Magazine", parent = "weapon_p22"},

        ["weapon_p22_silencer"] = {cost = 2, name = "P22 Silencer", parent = "weapon_p22"},

        ["weapon_pl15_extra_mag"] = {cost = 3, name = "PL-15 Extra Magazine", parent = "weapon_pl15"},

        ["weapon_pl15_silencer"] = {cost = 2, name = "PL-15 Silencer", parent = "weapon_pl15"},

    }

    local WeaponAddonOrder = {

        ["weapon_p22"] = {"weapon_p22_extra_mag", "weapon_p22_silencer"},

        ["weapon_pl15"] = {"weapon_pl15_extra_mag", "weapon_pl15_silencer"},

    }



    local Skillsets = {

        ["none"] = {cost = 0, name = "None", desc = "No special skillset."},

        ["infiltrator"] = {cost = 10, name = "Infiltrator", desc = "Can break necks, disguise as ragdolls."},

        ["assassin"] = {cost = 12, name = "Assassin", desc = "Disarm people quickly, proficient in shooting."},

        ["chemist"] = {cost = 5, name = "Chemist", desc = "Resistant to chemicals, detects chemical agents in air."},

        ["martial_artist"] = {cost = 30, name = "Martial Artist", desc = "Nunchucks, buffed fists/kicks/melee, +40% stamina, disarm + neck break, no flashlight."}

    }



    local maxPoints = 30

    local currentPoints = 0

    local currentLoadout = {weapons = {}, skillset = "none"}

    local WeaponExclusions = {

        ["weapon_buck200knife"] = {

            ["weapon_sogknife"] = true,

        },

        ["weapon_sogknife"] = {

            ["weapon_buck200knife"] = true,

        },

    }



    local function HasWeaponConflict(selectedWeapons, weaponId)

        local exclusions = WeaponExclusions[weaponId]

        if exclusions then

            for _, selectedId in ipairs(selectedWeapons) do

                if selectedId ~= weaponId and exclusions[selectedId] then

                    return true

                end

            end

        end



        for _, selectedId in ipairs(selectedWeapons) do

            if selectedId ~= weaponId then

                local selectedExclusions = WeaponExclusions[selectedId]

                if selectedExclusions and selectedExclusions[weaponId] then

                    return true

                end

            end

        end



        return false

    end



    local function GetSortedIdsByCost(sourceTable)

        local ids = {}

        for id in pairs(sourceTable) do

            table.insert(ids, id)

        end

        table.sort(ids, function(a, b)

            local aInfo = sourceTable[a]

            local bInfo = sourceTable[b]

            if aInfo.cost == bInfo.cost then

                return aInfo.name < bInfo.name

            end

            return aInfo.cost > bInfo.cost

        end)

        return ids

    end



    local skillsetOrder = GetSortedIdsByCost(Skillsets)

    local itemOrder = GetSortedIdsByCost(TraitorItems)



    local function SanitizeLoadout(rawLoadout)

        local normalizedLoadout = {weapons = {}, skillset = "none"}

        if type(rawLoadout) ~= "table" then

            rawLoadout = {}

        end



        if type(rawLoadout.skillset) == "string" and Skillsets[rawLoadout.skillset] then

            normalizedLoadout.skillset = rawLoadout.skillset

        end



        local totalPoints = Skillsets[normalizedLoadout.skillset].cost

        local usedWeapons = {}

        local rawWeaponIds = {}

        if type(rawLoadout.weapons) == "table" then

            for k, v in pairs(rawLoadout.weapons) do

                local weaponId

                if type(v) == "string" then

                    weaponId = v

                elseif type(k) == "string" and v == true then

                    weaponId = k

                end



                if weaponId and not usedWeapons[weaponId] and (TraitorItems[weaponId] or TraitorAddons[weaponId]) then

                    usedWeapons[weaponId] = true

                    table.insert(rawWeaponIds, weaponId)

                end

            end

        end



        usedWeapons = {}

        for _, weaponId in ipairs(rawWeaponIds) do

            local baseInfo = TraitorItems[weaponId]

            if baseInfo and not usedWeapons[weaponId] and not HasWeaponConflict(normalizedLoadout.weapons, weaponId) then

                local weaponCost = baseInfo.cost

                if totalPoints + weaponCost <= maxPoints then

                    usedWeapons[weaponId] = true

                    table.insert(normalizedLoadout.weapons, weaponId)

                    totalPoints = totalPoints + weaponCost

                end

            end

        end



        for _, weaponId in ipairs(rawWeaponIds) do

            local addonInfo = TraitorAddons[weaponId]

            if addonInfo and not usedWeapons[weaponId] and usedWeapons[addonInfo.parent] then

                local weaponCost = addonInfo.cost

                if totalPoints + weaponCost <= maxPoints then

                    usedWeapons[weaponId] = true

                    table.insert(normalizedLoadout.weapons, weaponId)

                    totalPoints = totalPoints + weaponCost

                end

            end

        end



        return normalizedLoadout

    end



    currentLoadout = SanitizeLoadout(parsedLoadout or {})



    local function EncodeLoadout(loadoutData)

        local dataStr = util.TableToJSON(loadoutData)

        if not isstring(dataStr) or dataStr == "" then

            dataStr = "{\"weapons\":[],\"skillset\":\"none\"}"

        end

        return dataStr

    end



    local function SaveLoadout()

        currentLoadout = SanitizeLoadout(currentLoadout)

        local dataStr = EncodeLoadout(currentLoadout)

        file.Write("meleecity_traitor_loadout.txt", dataStr)

        local cv = GetConVar("hmcd_traitor_loadout")

        if cv then cv:SetString(dataStr) end

    end



    SaveLoadout()



    local infoContent = vgui.Create("DPanel", infoPanel)

    infoContent:Dock(FILL)

    infoContent.Paint = function() end



    local lblInfoTitle = vgui.Create("DLabel", infoContent)

    lblInfoTitle:Dock(TOP)

    lblInfoTitle:SetText("SELECTED ITEM")

    lblInfoTitle:SetFont("ZCity_Veteran")

    lblInfoTitle:SetTextColor(Color(255, 255, 255))

    lblInfoTitle:SetContentAlignment(5)

    lblInfoTitle:SizeToContentsY()

    lblInfoTitle:DockMargin(0, ScreenScale(10), 0, ScreenScale(5))



    local previewIconMat = nil

    local previewImagePanel = vgui.Create("DPanel", infoContent)

    previewImagePanel:Dock(TOP)

    previewImagePanel:SetTall(math.Clamp(listH * 0.36, ScreenScale(120), ScreenScale(220)))

    previewImagePanel:DockMargin(ScreenScale(10), 0, ScreenScale(10), ScreenScale(10))

    previewImagePanel.Paint = function(pnl, w, h)

        draw.RoundedBox(0, 0, 0, w, h, Color(20, 20, 20, 220))

        surface.SetDrawColor(200, 200, 200, 80)

        surface.DrawOutlinedRect(0, 0, w, h, 1)

        if previewIconMat then

            local pad = ScreenScale(4)

            local drawW = w - pad * 2

            local drawH = h - pad * 2

            local matW = math.max(previewIconMat:Width(), 1)

            local matH = math.max(previewIconMat:Height(), 1)

            local iconScale = math.min(drawW / matW, drawH / matH)

            local iconW = matW * iconScale

            local iconH = matH * iconScale

            local iconX = (w - iconW) * 0.5

            local iconY = (h - iconH) * 0.5

            surface.SetDrawColor(255, 255, 255, 255)

            surface.SetMaterial(previewIconMat)

            surface.DrawTexturedRect(iconX, iconY, iconW, iconH)

        else

            draw.SimpleText("?", "ZCity_Veteran", w / 2, h / 2, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        end

    end



    local lblPreviewName = vgui.Create("DLabel", infoContent)

    lblPreviewName:Dock(TOP)

    lblPreviewName:DockMargin(ScreenScale(10), 0, ScreenScale(10), ScreenScale(2))

    lblPreviewName:SetFont("ZCity_Veteran")

    lblPreviewName:SetTextColor(Color(255, 255, 255))

    lblPreviewName:SetContentAlignment(5)

    lblPreviewName:SetText("None")

    lblPreviewName:SizeToContentsY()



    local lblPreviewCost = vgui.Create("DLabel", infoContent)

    lblPreviewCost:Dock(TOP)

    lblPreviewCost:DockMargin(ScreenScale(10), 0, ScreenScale(10), ScreenScale(8))

    lblPreviewCost:SetFont("ZCity_Veteran")

    lblPreviewCost:SetTextColor(Color(200, 200, 200))

    lblPreviewCost:SetContentAlignment(5)

    lblPreviewCost:SetText("")

    lblPreviewCost:SizeToContentsY()



    local lblPreviewDescTitle = vgui.Create("DLabel", infoContent)

    lblPreviewDescTitle:Dock(TOP)

    lblPreviewDescTitle:DockMargin(ScreenScale(10), 0, ScreenScale(10), ScreenScale(4))

    lblPreviewDescTitle:SetFont("ZCity_Veteran")

    lblPreviewDescTitle:SetTextColor(Color(220, 220, 220))

    lblPreviewDescTitle:SetContentAlignment(5)

    lblPreviewDescTitle:SetText("DESCRIPTION")

    lblPreviewDescTitle:SizeToContentsY()



    local previewDescScroll = vgui.Create("DScrollPanel", infoContent)

    previewDescScroll:Dock(FILL)

    previewDescScroll:DockMargin(ScreenScale(10), 0, ScreenScale(10), ScreenScale(10))

    local dsbar = previewDescScroll:GetVBar()

    dsbar:SetHideButtons(true)

    function dsbar:Paint(w, h) draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 80)) end

    function dsbar.btnGrip:Paint(w, h) draw.RoundedBox(0, 0, 0, w, h, Color(200, 200, 200, 130)) end



    local lblPreviewDesc = vgui.Create("DLabel", previewDescScroll)

    lblPreviewDesc:Dock(TOP)

    lblPreviewDesc:SetFont("ZCity_Veteran")

    lblPreviewDesc:SetTextColor(Color(200, 200, 200))

    lblPreviewDesc:SetWrap(true)

    lblPreviewDesc:SetAutoStretchVertical(true)

    lblPreviewDesc:SetText("None")



    local previewWeaponId = nil

    local function ResolvePreviewWeaponId()

        if previewWeaponId and TraitorItems[previewWeaponId] then

            return previewWeaponId

        end

        for _, weaponId in ipairs(currentLoadout.weapons) do

            if TraitorItems[weaponId] then

                return weaponId

            end

        end

        return nil

    end



    local function UpdatePreviewPanel()

        local weaponId = ResolvePreviewWeaponId()

        local itemInfo = weaponId and TraitorItems[weaponId] or nil

        local swep = weaponId and weapons.GetStored(weaponId) or nil

        local iconMat = nil

        local instructions = "None"



        if itemInfo then

            lblPreviewName:SetText(itemInfo.name)

            lblPreviewCost:SetText(itemInfo.cost .. " pts")

            if swep then

                if isstring(swep.Instructions) and swep.Instructions ~= "" then

                    instructions = swep.Instructions

                end

                if swep.WepSelectIcon then

                    if isstring(swep.WepSelectIcon) and swep.WepSelectIcon ~= "" then

                        iconMat = Material(swep.WepSelectIcon)

                    elseif type(swep.WepSelectIcon) == "IMaterial" then

                        iconMat = swep.WepSelectIcon

                    end

                end

                if not iconMat and isstring(swep.IconOverride) and swep.IconOverride ~= "" then

                    iconMat = Material(swep.IconOverride)

                end

            end

        else

            lblPreviewName:SetText("None")

            lblPreviewCost:SetText("")

        end



        lblPreviewName:SizeToContentsY()

        lblPreviewCost:SizeToContentsY()

        lblPreviewDesc:SetText(instructions)

        lblPreviewDesc:SetWide(math.max(previewDescScroll:GetWide() - ScreenScale(20), ScreenScale(120)))

        lblPreviewDesc:InvalidateLayout(true)



        if iconMat and not iconMat:IsError() then

            previewIconMat = iconMat

        else

            previewIconMat = nil

        end

    end



    local RefreshLoadoutUI



    -- === LEFT PANEL: PRESETS ===

    local presetsBottomPanel = vgui.Create("DPanel", leftPanel)

    presetsBottomPanel:Dock(BOTTOM)

    presetsBottomPanel:SetTall(ScreenScale(30))

    presetsBottomPanel.Paint = function() end



    local btnPresetsReturn = vgui.Create("DButton", presetsBottomPanel)

    btnPresetsReturn:Dock(RIGHT)

    btnPresetsReturn:DockMargin(0, ScreenScale(5), ScreenScale(10), ScreenScale(5))

    btnPresetsReturn:SetText("RETURN")

    btnPresetsReturn:SetFont("ZCity_Veteran")

    btnPresetsReturn:SetTextColor(Color(255, 255, 255))

    btnPresetsReturn:SizeToContentsX()

    btnPresetsReturn:SetWide(btnPresetsReturn:GetWide() + ScreenScale(20))

    btnPresetsReturn.Paint = function(s, w, h)

        local bgColor = s:IsHovered() and Color(150, 150, 150, 150) or Color(50, 50, 50, 150)

        draw.RoundedBox(0, 0, 0, w, h, bgColor)

        surface.SetDrawColor(200, 200, 200, 100)

        surface.DrawOutlinedRect(0, 0, w, h)

    end

    btnPresetsReturn.DoClick = function()

        sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

        self:SwitchToMain()

    end



    local btnGoToLoadout = vgui.Create("DButton", presetsBottomPanel)

    btnGoToLoadout:Dock(RIGHT)

    btnGoToLoadout:DockMargin(0, ScreenScale(5), ScreenScale(10), ScreenScale(5))

    btnGoToLoadout:SetText("LOADOUT")

    btnGoToLoadout:SetFont("ZCity_Veteran")

    btnGoToLoadout:SetTextColor(Color(255, 255, 255))

    btnGoToLoadout:SizeToContentsX()

    btnGoToLoadout:SetWide(btnGoToLoadout:GetWide() + ScreenScale(20))

    btnGoToLoadout.Paint = function(s, w, h)

        local bgColor = s:IsHovered() and Color(150, 150, 150, 150) or Color(50, 50, 50, 150)

        draw.RoundedBox(0, 0, 0, w, h, bgColor)

        surface.SetDrawColor(200, 200, 200, 100)

        surface.DrawOutlinedRect(0, 0, w, h)

    end

    btnGoToLoadout.DoClick = function()

        if self.LastSwitchTime and CurTime() - self.LastSwitchTime < 1 then return end

        self.LastSwitchTime = CurTime()

        sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

        self:SwitchToTraitorMenu()

    end



    local lblTitlePresets = vgui.Create("DLabel", leftPanel)

    lblTitlePresets:Dock(TOP)

    lblTitlePresets:SetText("TRAITOR PRESETS")

    lblTitlePresets:SetFont("ZCity_Veteran")

    lblTitlePresets:SetTextColor(Color(255, 255, 255))

    lblTitlePresets:SetContentAlignment(5)

    lblTitlePresets:SizeToContentsY()

    lblTitlePresets:DockMargin(0, ScreenScale(10), 0, ScreenScale(5))



    local presetsScroll = vgui.Create("DScrollPanel", leftPanel)

    presetsScroll:Dock(FILL)

    presetsScroll:DockMargin(ScreenScale(10), 0, ScreenScale(10), ScreenScale(10))

    local psbar = presetsScroll:GetVBar()

    psbar:SetHideButtons(true)

    function psbar:Paint(w, h) draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 80)) end

    function psbar.btnGrip:Paint(w, h) draw.RoundedBox(0, 0, 0, w, h, Color(200, 200, 200, 150)) end



    local function LoadPresets()

        local data = file.Read("meleecity_traitor_presets.txt", "DATA")

        if data then return util.JSONToTable(data) or {} end

        return {}

    end

    local function SavePresets(presets)

        file.Write("meleecity_traitor_presets.txt", util.TableToJSON(presets))

    end



    local function RefreshPresetsUI()

        presetsScroll:Clear()

        local presets = LoadPresets()



        local btnCreate = vgui.Create("DButton", presetsScroll)

        btnCreate:Dock(TOP)

        btnCreate:SetTall(ScreenScale(25))

        btnCreate:DockMargin(0, 0, 0, ScreenScale(5))

        btnCreate:SetText("+ CREATE NEW PRESET")

        btnCreate:SetFont("ZCity_Veteran")

        btnCreate:SetTextColor(Color(255, 255, 255))

        btnCreate.Paint = function(s, w, h)

            local bgColor = s:IsHovered() and Color(150, 150, 150, 150) or Color(30, 30, 30, 150)

            draw.RoundedBox(0, 0, 0, w, h, bgColor)

            surface.SetDrawColor(200, 200, 200, 50)

            surface.DrawOutlinedRect(0, 0, w, h)

        end

        btnCreate.DoClick = function()

            Derma_StringRequest("New Preset", "Enter a name for the new preset:", "Preset " .. (#presets + 1), function(text)

                table.insert(presets, {name = text, loadout = table.Copy(currentLoadout)})

                SavePresets(presets)

                RefreshPresetsUI()

                sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

            end)

        end



        for i, preset in ipairs(presets) do

            local pnl = vgui.Create("DPanel", presetsScroll)

            pnl:Dock(TOP)

            pnl:SetTall(ScreenScale(25))

            pnl:DockMargin(0, 0, 0, ScreenScale(2))

            pnl.Paint = function(s, w, h)

                draw.RoundedBox(0, 0, 0, w, h, Color(30, 30, 30, 150))

                surface.SetDrawColor(200, 200, 200, 50)

                surface.DrawOutlinedRect(0, 0, w, h)

            end



            local lblName = vgui.Create("DLabel", pnl)

            lblName:Dock(LEFT)

            lblName:DockMargin(ScreenScale(5), 0, 0, 0)

            lblName:SetText(preset.name)

            lblName:SetFont("ZCity_Veteran")

            lblName:SetTextColor(Color(255, 255, 255))

            lblName:SizeToContentsX()



            local btnDelete = vgui.Create("DButton", pnl)

            btnDelete:Dock(RIGHT)

            btnDelete:SetWide(ScreenScale(20))

            btnDelete:SetText("X")

            btnDelete:SetFont("ZCity_Veteran")

            btnDelete:SetTextColor(Color(255, 100, 100))

            btnDelete.Paint = function(s, w, h)

                if s:IsHovered() then draw.RoundedBox(0, 0, 0, w, h, Color(255, 0, 0, 50)) end

            end

            btnDelete.DoClick = function()

                table.remove(presets, i)

                SavePresets(presets)

                RefreshPresetsUI()

                sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

            end



            local btnLoad = vgui.Create("DButton", pnl)

            btnLoad:Dock(RIGHT)

            btnLoad:SetText("LOAD")

            btnLoad:SetFont("ZCity_Veteran")

            btnLoad:SetTextColor(Color(200, 255, 200))

            btnLoad:SizeToContentsX()

            btnLoad:SetWide(btnLoad:GetWide() + ScreenScale(10))

            btnLoad.Paint = function(s, w, h)

                if s:IsHovered() then draw.RoundedBox(0, 0, 0, w, h, Color(0, 255, 0, 50)) end

            end

            btnLoad.DoClick = function()

                currentLoadout = SanitizeLoadout(table.Copy(preset.loadout or {}))

                previewWeaponId = nil

                SaveLoadout()

                RefreshLoadoutUI()

                sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

            end

        end

    end

    RefreshPresetsUI()



    -- === RIGHT PANEL: LOADOUT ===

    local rightContentContainer = vgui.Create("DPanel", rightPanel)

    rightContentContainer:Dock(FILL)

    rightContentContainer.Paint = function() end



    local lblTitleLoadout = vgui.Create("DLabel", rightContentContainer)

    lblTitleLoadout:Dock(TOP)

    lblTitleLoadout:SetText("TRAITOR LOADOUT")

    lblTitleLoadout:SetFont("ZCity_Veteran")

    lblTitleLoadout:SetTextColor(Color(255, 255, 255))

    lblTitleLoadout:SetContentAlignment(5)

    lblTitleLoadout:SizeToContentsY()

    lblTitleLoadout:DockMargin(0, ScreenScale(10), 0, ScreenScale(5))



    local lblPoints = vgui.Create("DLabel", rightContentContainer)

    lblPoints:Dock(TOP)

    lblPoints:SetFont("ZCity_Veteran")

    lblPoints:SetTextColor(Color(200, 200, 200))

    lblPoints:SetContentAlignment(5)

    lblPoints:SizeToContentsY()

    lblPoints:DockMargin(0, 0, 0, ScreenScale(10))



    local loadoutScroll = vgui.Create("DScrollPanel", rightContentContainer)

    loadoutScroll:Dock(FILL)

    loadoutScroll:DockMargin(ScreenScale(10), 0, ScreenScale(10), ScreenScale(10))

    local lsbar = loadoutScroll:GetVBar()

    lsbar:SetHideButtons(true)

    function lsbar:Paint(w, h) draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 80)) end

    function lsbar.btnGrip:Paint(w, h) draw.RoundedBox(0, 0, 0, w, h, Color(200, 200, 200, 150)) end



    RefreshLoadoutUI = function()

        loadoutScroll:Clear()

        currentLoadout = SanitizeLoadout(currentLoadout)

        UpdatePreviewPanel()



        currentPoints = 0

        for _, wep in pairs(currentLoadout.weapons) do

            if TraitorItems[wep] then

                currentPoints = currentPoints + TraitorItems[wep].cost

            elseif TraitorAddons[wep] then

                currentPoints = currentPoints + TraitorAddons[wep].cost

            end

        end

        if Skillsets[currentLoadout.skillset] then

            currentPoints = currentPoints + Skillsets[currentLoadout.skillset].cost

        end



        lblPoints:SetText("Points: " .. currentPoints .. " / " .. maxPoints)

        if currentPoints > maxPoints then

            lblPoints:SetTextColor(Color(255, 100, 100))

        else

            lblPoints:SetTextColor(Color(200, 200, 200))

        end



        local function AddCategory(title)

            local catLbl = vgui.Create("DLabel", loadoutScroll)

            catLbl:SetText(title)

            catLbl:SetFont("ZCity_Veteran")

            catLbl:SetTextColor(Color(220, 220, 220))

            catLbl:Dock(TOP)

            catLbl:DockMargin(0, ScreenScale(5), 0, ScreenScale(2))

            catLbl:SizeToContentsY()

        end



        AddCategory("SKILLSETS")

        for _, id in ipairs(skillsetOrder) do

            local info = Skillsets[id]

            local btn = vgui.Create("DButton", loadoutScroll)

            btn:Dock(TOP)

            btn:SetTall(ScreenScale(20))

            btn:DockMargin(0, 0, 0, ScreenScale(2))

            btn:SetText("")

            btn.Paint = function(s, w, h)

                local isSelected = (currentLoadout.skillset == id)

                local bgColor = isSelected and Color(100, 100, 100, 150) or Color(30, 30, 30, 150)

                if s:IsHovered() then bgColor = Color(150, 150, 150, 150) end

                draw.RoundedBox(0, 0, 0, w, h, bgColor)

                surface.SetDrawColor(200, 200, 200, 50)

                surface.DrawOutlinedRect(0, 0, w, h)

                draw.SimpleText(info.name .. " (" .. info.cost .. " pts)", "ZCity_Veteran", ScreenScale(5), h/2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                if isSelected then

                    draw.SimpleText("+", "ZCity_Veteran", w - ScreenScale(5), h / 2, Color(255, 70, 70), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                end

            end

            btn.DoClick = function()

                local oldSkillset = currentLoadout.skillset

                local costDiff = info.cost - (Skillsets[oldSkillset] and Skillsets[oldSkillset].cost or 0)

                if currentPoints + costDiff > maxPoints then

                    surface.PlaySound("buttons/button10.wav")

                    return

                end

                currentLoadout.skillset = id

                SaveLoadout()

                RefreshLoadoutUI()

                sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

            end

        end



        AddCategory("WEAPONS & ITEMS")

        for _, id in ipairs(itemOrder) do

            local info = TraitorItems[id]

            local btn = vgui.Create("DButton", loadoutScroll)

            btn:Dock(TOP)

            btn:SetTall(ScreenScale(20))

            btn:DockMargin(0, 0, 0, ScreenScale(2))

            btn:SetText("")

            btn.Paint = function(s, w, h)

                local isSelected = table.HasValue(currentLoadout.weapons, id)

                local isDisabled = not isSelected and HasWeaponConflict(currentLoadout.weapons, id)

                local bgColor = isSelected and Color(100, 100, 100, 150) or Color(30, 30, 30, 150)

                if s:IsHovered() and not isDisabled then bgColor = Color(150, 150, 150, 150) end

                draw.RoundedBox(0, 0, 0, w, h, bgColor)

                surface.SetDrawColor(200, 200, 200, 50)

                surface.DrawOutlinedRect(0, 0, w, h)

                draw.SimpleText(info.name .. " (" .. info.cost .. " pts)", "ZCity_Veteran", ScreenScale(5), h/2, isDisabled and Color(160, 160, 160) or Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                if isDisabled then

                    draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 190))

                end

                if isSelected then

                    draw.SimpleText("+", "ZCity_Veteran", w - ScreenScale(5), h / 2, Color(255, 70, 70), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                end

            end

            btn.DoRightClick = function()

                previewWeaponId = id

                UpdatePreviewPanel()

                sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

            end

            btn.DoClick = function()

                local isDisabled = not table.HasValue(currentLoadout.weapons, id) and HasWeaponConflict(currentLoadout.weapons, id)

                if isDisabled then

                    surface.PlaySound("buttons/button10.wav")

                    return

                end

                if table.HasValue(currentLoadout.weapons, id) then

                    table.RemoveByValue(currentLoadout.weapons, id)

                    local addonOrder = WeaponAddonOrder[id]

                    if addonOrder then

                        for _, addonId in ipairs(addonOrder) do

                            table.RemoveByValue(currentLoadout.weapons, addonId)

                        end

                    end

                    if previewWeaponId == id then

                        previewWeaponId = nil

                    end

                else

                    if currentPoints + info.cost > maxPoints then

                        surface.PlaySound("buttons/button10.wav")

                        return

                    end

                    table.insert(currentLoadout.weapons, id)

                    previewWeaponId = id

                end

                SaveLoadout()

                RefreshLoadoutUI()

                sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

            end



            local addonOrder = WeaponAddonOrder[id]

            if addonOrder and table.HasValue(currentLoadout.weapons, id) then

                for _, addonId in ipairs(addonOrder) do

                    local addonInfo = TraitorAddons[addonId]

                    if addonInfo then

                        local addonBtn = vgui.Create("DButton", loadoutScroll)

                        addonBtn:Dock(TOP)

                        addonBtn:SetTall(ScreenScale(18))

                        addonBtn:DockMargin(ScreenScale(10), 0, 0, ScreenScale(2))

                        addonBtn:SetText("")

                        addonBtn.Paint = function(s, w, h)

                            local isSelected = table.HasValue(currentLoadout.weapons, addonId)

                            local bgColor = isSelected and Color(100, 100, 100, 150) or Color(25, 25, 25, 150)

                            if s:IsHovered() then bgColor = Color(140, 140, 140, 150) end

                            draw.RoundedBox(0, 0, 0, w, h, bgColor)

                            surface.SetDrawColor(200, 200, 200, 40)

                            surface.DrawOutlinedRect(0, 0, w, h)

                            draw.SimpleText("↳ " .. addonInfo.name .. " (" .. addonInfo.cost .. " pts)", "ZCity_Veteran", ScreenScale(5), h / 2, Color(235, 235, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                            if isSelected then

                                draw.SimpleText("+", "ZCity_Veteran", w - ScreenScale(5), h / 2, Color(255, 70, 70), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                            end

                        end

                        addonBtn.DoClick = function()

                            if not table.HasValue(currentLoadout.weapons, id) then

                                surface.PlaySound("buttons/button10.wav")

                                return

                            end

                            if table.HasValue(currentLoadout.weapons, addonId) then

                                table.RemoveByValue(currentLoadout.weapons, addonId)

                            else

                                if currentPoints + addonInfo.cost > maxPoints then

                                    surface.PlaySound("buttons/button10.wav")

                                    return

                                end

                                table.insert(currentLoadout.weapons, addonId)

                            end

                            previewWeaponId = id

                            SaveLoadout()

                            RefreshLoadoutUI()

                            sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

                        end

                    end

                end

            end

        end

    end

    RefreshLoadoutUI()



    local bottomPanel = vgui.Create("DPanel", rightPanel)

    bottomPanel:Dock(BOTTOM)

    bottomPanel:SetTall(ScreenScale(30))

    bottomPanel.Paint = function() end



    local btnReturn = vgui.Create("DButton", bottomPanel)

    btnReturn:Dock(RIGHT)

    btnReturn:DockMargin(0, ScreenScale(5), ScreenScale(10), ScreenScale(5))

    btnReturn:SetText("RETURN")

    btnReturn:SetFont("ZCity_Veteran")

    btnReturn:SetTextColor(Color(255, 255, 255))

    btnReturn:SizeToContentsX()

    btnReturn:SetWide(btnReturn:GetWide() + ScreenScale(20))

    btnReturn.Paint = function(s, w, h)

        local bgColor = s:IsHovered() and Color(150, 150, 150, 150) or Color(50, 50, 50, 150)

        draw.RoundedBox(0, 0, 0, w, h, bgColor)

        surface.SetDrawColor(200, 200, 200, 100)

        surface.DrawOutlinedRect(0, 0, w, h)

    end

    btnReturn.DoClick = function()

        sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

        self:SwitchToMain()

    end



    local btnClear = vgui.Create("DButton", bottomPanel)

    btnClear:Dock(RIGHT)

    btnClear:DockMargin(0, ScreenScale(5), ScreenScale(10), ScreenScale(5))

    btnClear:SetText("CLEAR")

    btnClear:SetFont("ZCity_Veteran")

    btnClear:SetTextColor(Color(255, 150, 150))

    btnClear:SizeToContentsX()

    btnClear:SetWide(btnClear:GetWide() + ScreenScale(20))

    btnClear.Paint = function(s, w, h)

        local bgColor = s:IsHovered() and Color(150, 50, 50, 150) or Color(50, 50, 50, 150)

        draw.RoundedBox(0, 0, 0, w, h, bgColor)

        surface.SetDrawColor(200, 100, 100, 100)

        surface.DrawOutlinedRect(0, 0, w, h)

    end

    btnClear.DoClick = function()

        currentLoadout.weapons = {}

        currentLoadout.skillset = "none"

        previewWeaponId = nil

        SaveLoadout()

        RefreshLoadoutUI()

        sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

    end



    local btnGoToPresets = vgui.Create("DButton", bottomPanel)

    btnGoToPresets:Dock(RIGHT)

    btnGoToPresets:DockMargin(0, ScreenScale(5), ScreenScale(10), ScreenScale(5))

    btnGoToPresets:SetText("PRESETS")

    btnGoToPresets:SetFont("ZCity_Veteran")

    btnGoToPresets:SetTextColor(Color(255, 255, 255))

    btnGoToPresets:SizeToContentsX()

    btnGoToPresets:SetWide(btnGoToPresets:GetWide() + ScreenScale(20))

    btnGoToPresets.Paint = function(s, w, h)

        local bgColor = s:IsHovered() and Color(150, 150, 150, 150) or Color(50, 50, 50, 150)

        draw.RoundedBox(0, 0, 0, w, h, bgColor)

        surface.SetDrawColor(200, 200, 200, 100)

        surface.DrawOutlinedRect(0, 0, w, h)

    end

    btnGoToPresets.DoClick = function()

        if self.LastSwitchTime and CurTime() - self.LastSwitchTime < 1 then return end

        self.LastSwitchTime = CurTime()

        sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

        self:SwitchToTraitorPresets()

    end

end



function PANEL:CreateAppearancePanel()

    if IsValid(self.AppearancePanel) then return end



    if hg.Appearance.PrecacheModels then

        hg.Appearance.PrecacheModels()

    end

    

    self.AppearancePanel = vgui.Create("ZAppearance", self)

    self.AppearancePanel:SetSize(ScrW(), ScrH())

    self.AppearancePanel:SetPos(0, 0)

    self.AppearancePanel:SetAlpha(0)

    self.AppearancePanel:SetVisible(false)

    

    -- Custom behavior for embedded panel

    self.AppearancePanel.IsEmbedded = true

    

    -- Override Close to switch back to main

    local oldClose = self.AppearancePanel.Close

    self.AppearancePanel.Close = function(pnl)

        -- Save appearance to file

        local currentAppearance = self.AppearancePanel.AppearanceTable

        if currentAppearance and hg.Appearance then

             local fileName = hg.Appearance.SelectedAppearance and hg.Appearance.SelectedAppearance:GetString() or "main"

             if fileName == "" then fileName = "main" end

             

             hg.Appearance.CreateAppearanceFile(fileName, currentAppearance)



             -- Send to server to apply immediately

             net.Start("Get_Appearance")

                 net.WriteTable(currentAppearance)

                 net.WriteBool(false) -- Not random

             net.SendToServer()

        end



        -- Don't actually remove, just switch state

        self:SwitchToMain()

    end

end



function PANEL:OnRemove()

    if LocalPlayer and IsValid(LocalPlayer()) then

        LocalPlayer():SetDSP(0) -- Reset DSP

    end

    

    if IsValid(ZCityMainMenuMusic) then

        ZCityMainMenuMusic:Pause()

    end

    

    if IsValid(ZCityAppearanceMusic) then

        ZCityAppearanceMusic:Stop()

    end



    if IsValid(ZCityIntroMusic) then

        ZCityIntroMusic:Stop()

    end

end



--[[

["5.42.211.48:24215"]:

		["addr"]	=	5.42.211.48:24215

		["map"]	=	hmcd_metropolis_extended

		["max_players"]	=	20

		["name"]	=	Z-City 1 | Beta | RU

		["players"]	=	20

["5.42.211.48:24217"]:

		["addr"]	=	5.42.211.48:24217

		["map"]	=	hmcd_metropolis_extended

		["max_players"]	=	20

		["name"]	=	Z-City 2 | Beta | RU

		["players"]	=	18

]]

local cardcolor = Color(15,15,25,220)

local green_color = Color(55,225,55)

function PANEL:AddServerCard(serverTbl)

    local main = self

    local card = vgui.Create("DPanel",self.rDock)

    card:Dock(TOP)

    card:SetSize(500,ScreenScaleH(45))

    card:DockMargin(5,5,5,5)

    card:DockPadding(15,5,15,15)

    card.Info = serverTbl

    function card:Paint(w,h)

        draw.RoundedBox( 4, 0, 0, w, h, cardcolor )



        draw.RoundedBox( 0, 0, h-h/5, w, h/5, cardcolor )

        draw.RoundedBox( 0, 2.5, h-h/5 +3, w* (card.Info["players"]/card.Info["max_players"]) - 5 , h/6, color_red )

    end



    local lbl = vgui.Create("DLabel",card)

    lbl:Dock(BOTTOM)

    lbl:SetFont("ZCity_Tiny")

    lbl:SetText(card.Info["players"].."/"..card.Info["max_players"])

    lbl:SizeToContents()

    lbl:SetTall(ScreenScaleH(17))



    local lbl = vgui.Create("DLabel",card)

    lbl:Dock(LEFT)

    lbl:SetFont("ZCity_Small")

    lbl:SetText(string.lower(card.Info["name"]))

    lbl:SizeToContents()

    lbl:SetTall(ScreenScaleH(19))



    local connectButton = vgui.Create("DButton",card)

    connectButton:Dock(RIGHT)

    connectButton:SetFont("ZCity_Small")

    connectButton:SetText("connect")

    connectButton:SizeToContents()

    connectButton:SetTall(ScreenScaleH(19))

    connectButton.HoverLerp = 0

    connectButton.RColor = Color(255,255,255)

    function connectButton:Paint(w,h)

        return false

    end



    function connectButton:Think()

        self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, self:IsHovered() and 1 or 0)

        local v = self.HoverLerp

        self:SetTextColor( self.RColor:Lerp( green_color, v ) )

    end



    function connectButton:DoClick()

        permissions.AskToConnect( card.Info["addr"] )

    end

end



function PANEL:First( ply )

    --self:MoveTo(self:GetX(), self:GetY() - self:GetTall()/2, 0.5, 0, 0.2, function() end)

    self:AlphaTo( 255, 0.1, 0, nil )

end



local gradient_d = surface.GetTextureID("vgui/gradient-d")

local gradient_r = surface.GetTextureID("vgui/gradient-r")

local gradient_l = surface.GetTextureID("vgui/gradient-l")



function PANEL:Paint(w,h)

    -- Black Background Layer (Always behind everything)

    surface.SetDrawColor(0, 0, 0, 255)

    surface.DrawRect(0, 0, w, h)

    

    -- Transition Logic for Backgrounds

    local progress = 0

    if self.TargetState == "Settings" or self.TargetState == "Appearance" or self.TargetState == "Achievements" or self.TargetState == "TraitorMenu" or self.TargetState == "TraitorPresets" then

        progress = self.TransitionProgress

    elseif self.TargetState == "Main" then

        progress = 1 - self.TransitionProgress

    end

    local imageTransitionShakeX = self.TransitionImageShakeX or 0

    local imageTransitionShakeY = self.TransitionImageShakeY or 0

    

    -- Main Background

    if progress < 1 or self.TargetState == "Appearance" or self.TargetState == "TraitorMenu" or self.TargetState == "TraitorPresets" then

        -- Keep drawing if we are going to these menus

        surface.SetDrawColor( 80, 80, 80, 255 )

        if self.TargetState == "Settings" or (self.TargetState == "Main" and self.CurrentState == "Settings") or self.TargetState == "Achievements" or (self.TargetState == "Main" and self.CurrentState == "Achievements") then

             surface.SetDrawColor( 80, 80, 80, 255 * (1 - progress) )

        elseif self.TargetState == "TraitorMenu" or (self.TargetState == "Main" and self.CurrentState == "TraitorMenu") or self.TargetState == "TraitorPresets" or (self.TargetState == "Main" and self.CurrentState == "TraitorPresets") then

             surface.SetDrawColor( 80, 80, 80, 255 )

        end

        

        local mat = BgMat

        if self.IsIntro then mat = EyeMat end



        if not mat:IsError() then

            surface.SetMaterial( mat )

            local scale = 1.1

            local zoomedW, zoomedH = w * scale, h * scale

            local offsetX, offsetY

            if self.TargetState == "Settings" or (self.TargetState == "Main" and self.CurrentState == "Settings") then

                offsetX = (w - zoomedW) / 2 - (w * progress)

                offsetY = (h - zoomedH) / 2

            elseif self.TargetState == "Appearance" or (self.TargetState == "Main" and self.CurrentState == "Appearance") then

                offsetX = (w - zoomedW) / 2

                offsetY = (h - zoomedH) / 2 - (h * progress)

            elseif self.TargetState == "Achievements" or (self.TargetState == "Main" and self.CurrentState == "Achievements") then

                offsetX = (w - zoomedW) / 2 + (w * progress)

                offsetY = (h - zoomedH) / 2

            elseif self.TargetState == "TraitorMenu" or (self.TargetState == "Main" and self.CurrentState == "TraitorMenu") or self.TargetState == "TraitorPresets" or (self.TargetState == "Main" and self.CurrentState == "TraitorPresets") then

                -- Move the main background DOWN as camera moves UP

                offsetX = (w - zoomedW) / 2

                offsetY = (h - zoomedH) / 2 + (h * progress)

            else

                offsetX = (w - zoomedW) / 2

                offsetY = (h - zoomedH) / 2

            end

            

            local shakeX = math.random(-2, 2)

            local shakeY = math.random(-2, 2)

            

            surface.DrawTexturedRect(offsetX + shakeX + imageTransitionShakeX, offsetY + shakeY + imageTransitionShakeY, zoomedW, zoomedH)

        end

    end

    

    -- Background 2 (Settings) - Moves In from Right

    if progress > 0 and (self.TargetState == "Settings" or (self.TargetState == "Main" and self.CurrentState == "Settings")) then

        surface.SetDrawColor( 80, 80, 80, 255 * progress )

        if not BgMat2:IsError() then

            surface.SetMaterial( BgMat2 )

            local scale = 1.1

            local zoomedW, zoomedH = w * scale, h * scale

            local offsetX = (w - zoomedW) / 2 + (w * (1 - progress))

            local offsetY = (h - zoomedH) / 2

            

            local shakeX = math.random(-2, 2)

            local shakeY = math.random(-2, 2)

            

            surface.DrawTexturedRect(offsetX + shakeX + imageTransitionShakeX, offsetY + shakeY + imageTransitionShakeY, zoomedW, zoomedH)

        end

    end



    -- Background 3 (Appearance)

    if progress > 0 and (self.TargetState == "Appearance" or (self.TargetState == "Main" and self.CurrentState == "Appearance")) then

        surface.SetDrawColor( 80, 80, 80, 255 * progress )

        if not BgMat3:IsError() then

            surface.SetMaterial( BgMat3 )

            local scale = 1.1

            local zoomedW, zoomedH = w * scale, h * scale

            local offsetX = (w - zoomedW) / 2

            local sep = h * 0.12

            local offsetY

            if self.TargetState == "Appearance" then

                offsetY = (h - zoomedH) / 2 + sep + (h * (1 - progress))

            else

                offsetY = (h - zoomedH) / 2 + sep + h

            end

            

            local shakeX = math.random(-2, 2)

            local shakeY = math.random(-2, 2)

            

            surface.DrawTexturedRect(offsetX + shakeX + imageTransitionShakeX, offsetY + shakeY + imageTransitionShakeY, zoomedW, zoomedH)

        end

    end



    if progress > 0 and (self.TargetState == "TraitorMenu" or (self.TargetState == "Main" and self.CurrentState == "TraitorMenu") or self.TargetState == "TraitorPresets" or (self.TargetState == "Main" and self.CurrentState == "TraitorPresets")) then

        surface.SetDrawColor( 255, 255, 255, 255 * progress )

        if self.TargetState == "TraitorPresets" and self.CurrentState == "TraitorMenu" then

            surface.SetDrawColor( 255, 255, 255, 255 )

        elseif self.TargetState == "TraitorMenu" and self.CurrentState == "TraitorPresets" then

            surface.SetDrawColor( 255, 255, 255, 255 )

        end



        local bgMat5 = Material("vgui/background5.png")

        if not bgMat5:IsError() then

            surface.SetMaterial( bgMat5 )

            local scale = 1.1

            local zoomedW, zoomedH = w * scale, h * scale

            local offsetX = (w - zoomedW) / 2

            

            -- If viewpoint moves UP, background moves DOWN. 

            -- Starts at -h (above screen) and moves to 0.

            local offsetY = (h - zoomedH) / 2 - h * (1 - progress)

            

            if (self.TargetState == "TraitorPresets" and self.CurrentState == "TraitorMenu") or (self.TargetState == "TraitorMenu" and self.CurrentState == "TraitorPresets") then

                offsetY = (h - zoomedH) / 2

            end



            local shakeX = math.random(-2, 2)

            local shakeY = math.random(-2, 2)

            

            surface.DrawTexturedRect(offsetX + shakeX + imageTransitionShakeX, offsetY + shakeY + imageTransitionShakeY, zoomedW, zoomedH)

        end

    end



    if progress > 0 and (self.TargetState == "Achievements" or (self.TargetState == "Main" and self.CurrentState == "Achievements")) then

        if not BgMat4:IsError() then

            surface.SetMaterial(BgMat4)

            local scale = 1.1

            local zoomedW, zoomedH = w * scale, h * scale

            local offsetX = (w - zoomedW) / 2 - (w * (1 - progress))

            local offsetY = (h - zoomedH) / 2

            local shakeX = math.random(-2, 2)

            local shakeY = math.random(-2, 2)

            surface.SetDrawColor(255, 255, 255, 255 * progress)

            surface.DrawTexturedRect(offsetX + shakeX + imageTransitionShakeX, offsetY + shakeY + imageTransitionShakeY, zoomedW, zoomedH)

        end



        if not BgMat4Overlay:IsError() then

            surface.SetMaterial(BgMat4Overlay)

            local scale = 1.1

            local zoomedW, zoomedH = w * scale, h * scale

            local offsetX = (w - zoomedW) / 2 - (w * (1 - progress))

            local offsetY = (h - zoomedH) / 2

            local shakeX = math.random(-2, 2)

            local shakeY = math.random(-2, 2)

            surface.SetDrawColor(255, 255, 255, 200 * progress)

            surface.DrawTexturedRect(offsetX + shakeX + imageTransitionShakeX, offsetY + shakeY + imageTransitionShakeY, zoomedW, zoomedH)

        end

    end



    

    -- Draw Flashing Image (Bottom Right in Settings) - BEFORE VHS

    if self.CurrentFlashImage and type(self.CurrentFlashImage) == "IMaterial" and not self.CurrentFlashImage:IsError() and self.FlashAlpha > 0 and (self.TargetState == "Settings" or self.CurrentState == "Settings") then

        surface.SetDrawColor(80, 80, 80, self.FlashAlpha) -- Made darker (150 -> 80)

        surface.SetMaterial(self.CurrentFlashImage)

        

        -- Made wider as requested (160 vs 128)

        local imgW = ScreenScale(160) 

        -- Made taller as requested (180 vs 128)

        local imgH = ScreenScale(180)

        

        -- Slide offset to move with Settings background

        local slideOffset = w * (1 - progress)

        

        -- Located directly at bottom right corner (no margin) + slide offset

        local imgX = (w - imgW) + slideOffset

        local imgY = h - imgH

        

        -- Micro Shakes

        local shakeX = math.random(-2, 2)

        local shakeY = math.random(-2, 2)

        

        surface.DrawTexturedRect(imgX + shakeX + imageTransitionShakeX, imgY + shakeY + imageTransitionShakeY, imgW, imgH)

    end



    -- VHS Static Effect (On top of backgrounds AND flashing images)

    surface.SetMaterial(NoiseMat)

    -- Reset to white/transparent to let the material handle the look, slightly transparent

    surface.SetDrawColor(255, 255, 255, 40) 

    local noiseU = math.random()

    local noiseV = math.random()

    surface.DrawTexturedRectUV(0, 0, w, h, noiseU, noiseV, noiseU + (w/256), noiseV + (h/256))

    

    -- Occasional stronger glitch line

    if math.random() > 0.995 then

        surface.SetDrawColor(60, 60, 60, 50)

        surface.DrawRect(0, math.random(0, h), w, math.random(1, 2))

    end

    

    -- Title Transition Logic

    local text1 = "huytown: guppy slaughter"

    

    surface.SetFont("ZC_MM_Title")

    

    -- Always Draw Main Title (No Transition)

    local time = CurTime()

    local blink_chance = math.sin(time * 0.5)

    local color_val = 0

    if blink_chance > 0.8 then

        local blink_speed = 20

        color_val = (math.sin(time * blink_speed) + 1) / 2 * 255

    end

    

    surface.SetTextColor(255, color_val, color_val, 255)

    

    local textShakeX = math.random(-10, 10) * 0.1

    local textShakeY = math.random(-10, 10) * 0.1

    if math.random() > 0.9 then

        textShakeX = textShakeX + math.random(-3, 3)

        textShakeY = textShakeY + math.random(-3, 3)

    end

    

    local titleY = self.LogoY

    local titleX = self.LogoX
    
    if self.IsIntro then
        -- Position title at bottom middle for intro
        surface.SetFont("ZC_MM_Title")
        local tw, th = surface.GetTextSize(text1)
        titleX = (w - tw) / 2
        titleY = h - th - ScreenScale(50)
        
        -- Fade out title during intro sequence
        if self.IntroSequenceActive then
            local elapsedTime = CurTime() - self.IntroStartTime
            local duration = 5
            local fadeAlpha = math.Clamp(1 - (elapsedTime / duration), 0, 1)
            surface.SetTextColor(255, color_val, color_val, 255 * fadeAlpha)
        end
    else
    if self.TargetState == "Appearance" or (self.TargetState == "Main" and self.CurrentState == "Appearance") then

        titleY = self.LogoY - ScrH() * progress

    elseif self.TargetState == "TraitorMenu" or (self.TargetState == "Main" and self.CurrentState == "TraitorMenu") or self.TargetState == "TraitorPresets" or (self.TargetState == "Main" and self.CurrentState == "TraitorPresets") then

        titleY = self.LogoY + ScrH() * progress

        

        if (self.TargetState == "TraitorPresets" and self.CurrentState == "TraitorMenu") or (self.TargetState == "TraitorMenu" and self.CurrentState == "TraitorPresets") then

            titleY = self.LogoY + ScrH()

        end

    end

    

    if self.CurrentState ~= "Main" and self.TargetState ~= "Main" then

        if (self.CurrentState == "TraitorMenu" or self.CurrentState == "TraitorPresets") and (self.TargetState == "TraitorMenu" or self.TargetState == "TraitorPresets") then

            -- Leave titleY as is (it was set above)

        else

            titleY = self.LogoY - ScrH()

            if self.CurrentState == "Settings" or self.TargetState == "Settings" or self.CurrentState == "Achievements" or self.TargetState == "Achievements" then

                titleY = self.LogoY

                end
            end

        end

    end



    surface.SetTextPos(self.LogoX + textShakeX, titleY + textShakeY)

    surface.DrawText(text1)

    

    if self.IsIntro then

        local enterText = "press enter"

        surface.SetFont("ZCity_Veteran")

        local tw, th = surface.GetTextSize(enterText)

        local tx = w - tw - ScreenScale(20)

        local ty = h - th - ScreenScale(20)

        

        -- Blink logic

        local blinkSpeed = 2

        local alpha = math.abs(math.sin(CurTime() * blinkSpeed)) * 255

        

        surface.SetTextColor(255, 0, 0, alpha)

        surface.SetTextPos(tx, ty)

        surface.DrawText(enterText)

        

        -- Intro Sequence Fade to Black

        if self.IntroSequenceActive then

            local elapsedTime = CurTime() - self.IntroStartTime

            local duration = 3 -- Fade out duration

            local fadeAlpha = math.Clamp((elapsedTime / duration) * 255, 0, 255)

            

            surface.SetDrawColor(0, 0, 0, fadeAlpha)

            surface.DrawRect(0, 0, w, h)

            

            if elapsedTime >= duration then

                self:Close()

                

                -- Create Fade Out Panel (Black -> Clear)

                local fadePanel = vgui.Create("DPanel")

                fadePanel:SetSize(ScrW(), ScrH())

                fadePanel:MakePopup()

                fadePanel:SetKeyboardInputEnabled(false)

                fadePanel:SetMouseInputEnabled(false)

                fadePanel.StartTime = CurTime()

                fadePanel.Duration = 3

                

                function fadePanel:Paint(pw, ph)

                    local et = CurTime() - self.StartTime

                    local a = 255 - math.Clamp((et / self.Duration) * 255, 0, 255)

                    surface.SetDrawColor(0, 0, 0, a)

                    surface.DrawRect(0, 0, pw, ph)

                    

                    if et >= self.Duration then

                        self:Remove()

                    end

                end

                

                -- Mark intro as seen

                ZCityHasSeenIntro = true

            end

        end

    end

end



function PANEL:AddSelect( pParent, strTitle, tbl )

    local id = #self.Buttons + 1

    self.Buttons[id] = vgui.Create( "DLabel", pParent )

    local btn = self.Buttons[id]

    btn:SetText( strTitle )

    btn:SetMouseInputEnabled( true )

    btn:SetFont( "ZCity_Veteran" )

    btn:SizeToContents()

    btn:SetWide(btn:GetWide() + ScreenScale(8))

    btn:SetTall( math.max(ScreenScale(18), btn:GetTall()) )

    btn:SetPos(0, 0)

    btn:SetContentAlignment(4)

    btn.Func = tbl.Func

    btn.HoveredFunc = tbl.HoveredFunc

    local luaMenu = self 

    if tbl.CreatedFunc then tbl.CreatedFunc(btn, self, luaMenu) end

    

    function btn:DoClick()

        sound.PlayFile("sound/press.mp3", "noblock", function(station) if IsValid(station) then station:Play() end end)

        btn.Func(luaMenu)

    end



    function btn:Think() 

        self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, self:IsHovered() and 1 or 0) 

        if self.HoverLerp < 0.01 then self.HoverLerp = 0 end

        if self.HoverLerp > 0.99 then self.HoverLerp = 1 end



        local v = self.HoverLerp 

        local targetText = self:IsHovered() and string.upper(strTitle) or strTitle 

        local crw = self:GetText() 



        if crw ~= targetText then 

            local ntxt = "" 

            for i = 1, #strTitle do 

                local char = strTitle:sub(i, i) 

                if i <= math.ceil(#strTitle * v) then 

                    ntxt = ntxt .. string.upper(char) 

                else 

                    ntxt = ntxt .. char 

                end 

            end 

            if self:GetText() ~= ntxt then 

                self:SetText(ntxt) 

            end 

        end 

    end



    function btn:Paint(w, h)

        local font = self:GetFont()

        local text = self:GetText()

        surface.SetFont(font)

        local tw, th = surface.GetTextSize(text)

        

        -- Add padding to width for border

        local padding = ScreenScale(4)

        local totalW = tw + padding * 2



        if self:IsHovered() then

            if not self.HoveredSoundPlayed then

                sound.PlayFile("sound/hover.ogg", "noblock", function(station) if IsValid(station) then station:Play() end end)

                self.HoveredSoundPlayed = true

            end

            

            local alpha = 255

            if math.random() > 0.9 then alpha = math.random(50, 200) end

            

            surface.SetDrawColor(255, 255, 255, alpha)

            surface.DrawRect(0, 0, totalW, h)

            self:SetTextColor(Color(0, 0, 0, alpha))

        else

            self.HoveredSoundPlayed = false

            self:SetTextColor(Color(255, 255, 255))

        end

        

        local offX, offY = 0, 0

        if math.random() > 0.9 then

             offX = math.random(-2, 2)

             offY = math.random(-2, 2)

        end

        

        draw.SimpleText(text, font, padding + offX, h/2 + offY, self:GetTextColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        

        if self:IsHovered() and math.random() > 0.7 then

            local offsetX = math.random(-5, 5)

            local offsetY = math.random(-2, 2)

            draw.SimpleText(text, font, padding + offsetX, h/2 + offsetY, Color(0, 0, 0, math.random(50, 150)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        end

        return true

    end

end



function PANEL:Close()

    -- Removed valve.mp3 playback on menu close

    self:AlphaTo( 0, 0.1, 0, function() self:Remove() end)

    self:SetKeyboardInputEnabled(false)

    self:SetMouseInputEnabled(false)

end



vgui.Register( "ZMainMenu", PANEL, "ZFrame")



hook.Add("OnPauseMenuShow","OpenMainMenu",function()

    local run = hook.Run("OnShowZCityPause")

    if run then

        return run

    end



    if MainMenu and IsValid(MainMenu) then

        if MainMenu.IsIntro then

            return false -- Prevent closing intro menu with ESC

        end

        MainMenu:Close()

        MainMenu = nil

        return false

    end



    MainMenu = vgui.Create("ZMainMenu")

    MainMenu:MakePopup()

    return false

end)


hook.Add("OnPauseMenuShow","OpenMainMenu",function()

    local run = hook.Run("OnShowZCityPause")

    if run then

        return run

    end



    if MainMenu and IsValid(MainMenu) then

        if MainMenu.IsIntro then

            return false -- Prevent closing intro menu with ESC

        end

        MainMenu:Close()

        MainMenu = nil

        return false

    end



    MainMenu = vgui.Create("ZMainMenu")

    MainMenu:MakePopup()

    return false

end)


timer.Simple(0, function()

    if not ZCityHasSeenIntro and not (MainMenu and IsValid(MainMenu)) and LocalPlayer and IsValid(LocalPlayer()) then

        MainMenu = vgui.Create("ZMainMenu")

        MainMenu:MakePopup()

    end

end)

