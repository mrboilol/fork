if SERVER then return end

local SCREEN = {}

SCREEN.ImageMat = Material("zcity_delta/death/death.png", "noclamp")
SCREEN.MusicPath = "zcity_delta/death.mp3"
SCREEN.FadeDelay = 1.1
SCREEN.FadeDuration = 2.8
SCREEN.ImageDarken = 0.45
SCREEN.RespawnWhiteInSeconds = 0.5
SCREEN.RespawnWhiteOutSeconds = 0.6
SCREEN.RespawnNetName = "zcity_delta_death_respawn"
SCREEN.ReportNetName = "zcity_delta_death_report"
SCREEN.FontFace = "04b11"
SCREEN.FontAntialias = false

local function easeInOut(t)
    t = math.Clamp(t or 0, 0, 1)
    return t * t * (3 - 2 * t)
end

local function isDeathScreenEnabled()
    local cv = GetConVar and GetConVar("zcity_delta_deathscreen_enable") or nil
    if not cv or not cv.GetBool then return true end
    return cv:GetBool()
end

surface.CreateFont("zcity_delta_death_title", { font = SCREEN.FontFace, size = 42, weight = 500, antialias = SCREEN.FontAntialias })
surface.CreateFont("zcity_delta_death_button", { font = SCREEN.FontFace, size = 26, weight = 500, antialias = SCREEN.FontAntialias })

local function stopMusic()
    if SCREEN.Music and SCREEN.Music.Stop then SCREEN.Music:Stop() end
    SCREEN.Music = nil
end

local function playMusic()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if SCREEN.Music then return end
    SCREEN.Music = CreateSound(ply, SCREEN.MusicPath)
    if SCREEN.Music then SCREEN.Music:PlayEx(0, 100) end
end

local function snap(v) return math.floor((v or 0) + 0.5) end

local function makeButton(parent)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetSize(200, 52)
    btn:SetCursor("hand")
    btn:SetZPos(9999)
    btn:SetEnabled(true)
    btn:SetMouseInputEnabled(true)
    btn.Respawning = false

    function btn:Paint(w, h)
        local alpha = parent:GetUiAlpha()
        local hovered = self:IsHovered()
        surface.SetDrawColor(8, 8, 8, math.floor(alpha * (hovered and 0.92 or 0.72)))
        surface.DrawRect(0, 0, w, h)

        local pulse = 0
        if not self.Respawning then
            pulse = (math.sin(RealTime() * 6) * 0.5 + 0.5) * 0.25
        end

        surface.SetDrawColor(170, 0, 0, math.floor(alpha * (hovered and 1 or 0.75 + pulse)))
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        local label = self.Respawning and "respawning..." or "Respawn"
        draw.SimpleText(label, "zcity_delta_death_button", snap(w * 0.5), snap(h * 0.5), Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function(self)
        if self.Respawning then return end
        if not IsValid(LocalPlayer()) or LocalPlayer():Alive() then return end
        self.Respawning = true
        self:SetMouseInputEnabled(false)
        surface.PlaySound("buttons/button15.wav")
        startWhiteIn()
    end

    btn:SetPos(snap(parent:GetWide() * 0.5 - btn:GetWide() * 0.5), parent:GetTall() - btn:GetTall() - 40)
    btn:MoveToFront()
    return btn
end

local function removeScreen()
    stopMusic()
    if IsValid(SCREEN.Panel) then SCREEN.Panel:Remove() end
    SCREEN.Panel = nil
    gui.EnableScreenClicker(false)
end

SCREEN.Respawn = SCREEN.Respawn or { state = "idle", startAt = 0, sent = false }
SCREEN.Report = SCREEN.Report or nil
SCREEN.DebugForced = SCREEN.DebugForced or false

local function startWhiteIn()
    if SCREEN.Respawn.state ~= "idle" then return end
    SCREEN.Respawn.state = "white_in"
    SCREEN.Respawn.startAt = RealTime()
    SCREEN.Respawn.sent = false
end

local function startWhiteOut()
    SCREEN.Respawn.state = "white_out"
    SCREEN.Respawn.startAt = RealTime()
end

hook.Add("HUDPaint", "zcity_delta_death_respawn_white", function()
    if not SCREEN.Respawn or SCREEN.Respawn.state == "idle" then return end
    local now = RealTime()
    local alpha = 0

    if SCREEN.Respawn.state == "white_in" then
        local frac = math.Clamp((now - (SCREEN.Respawn.startAt or 0)) / SCREEN.RespawnWhiteInSeconds, 0, 1)
        alpha = math.floor(255 * easeInOut(frac))
        if frac >= 1 and not SCREEN.Respawn.sent then
            SCREEN.Respawn.sent = true
            SCREEN.Respawn.state = "waiting_spawn"
            if net and net.Start and util and util.NetworkStringToID and util.NetworkStringToID(SCREEN.RespawnNetName) ~= 0 then
                net.Start(SCREEN.RespawnNetName)
                net.SendToServer()
            end
        end
    elseif SCREEN.Respawn.state == "waiting_spawn" then
        alpha = 255
    elseif SCREEN.Respawn.state == "white_out" then
        local frac = math.Clamp((now - (SCREEN.Respawn.startAt or 0)) / SCREEN.RespawnWhiteOutSeconds, 0, 1)
        alpha = math.floor(255 * (1 - easeInOut(frac)))
        if frac >= 1 then
            SCREEN.Respawn.state = "idle"
            SCREEN.Respawn.startAt = 0
            SCREEN.Respawn.sent = false
            return
        end
    end

    if alpha <= 0 then return end
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawRect(0, 0, ScrW(), ScrH())
end)

net.Receive(SCREEN.ReportNetName, function()
    SCREEN.Report = net.ReadTable() or SCREEN.Report
end)

local function createScreen()
    if not SCREEN.DebugForced and not isDeathScreenEnabled() then return end
    if IsValid(SCREEN.Panel) then return end

    local panel = vgui.Create("EditablePanel")
    panel:SetSize(ScrW(), ScrH())
    panel:SetPos(0, 0)
    panel:MakePopup()
    panel:SetKeyboardInputEnabled(false)
    panel:SetMouseInputEnabled(true)
    panel.StartedAt = RealTime()
    panel.ImageAlpha = 0
    panel.MusicStarted = false
    function panel:GetUiAlpha() return self.ImageAlpha or 0 end
    function panel:GetImageAlpha() return self.ImageAlpha or 0 end

    function panel:Think()
        if not IsValid(LocalPlayer()) then removeScreen() return end
        if LocalPlayer():Alive() and not SCREEN.DebugForced then removeScreen() return end

        if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then
            self:SetSize(ScrW(), ScrH())
            if IsValid(self.RespawnButton) then
                self.RespawnButton:SetPos(snap(self:GetWide() * 0.5 - self.RespawnButton:GetWide() * 0.5), self:GetTall() - self.RespawnButton:GetTall() - 40)
            end
        end

        local elapsed = RealTime() - self.StartedAt
        local fadeFrac = math.Clamp((elapsed - SCREEN.FadeDelay) / SCREEN.FadeDuration, 0, 1)
        local eased = easeInOut(fadeFrac)
        self.ImageAlpha = math.floor(255 * eased)

        if fadeFrac > 0 and not self.MusicStarted then
            self.MusicStarted = true
            playMusic()
        end
        if self.MusicStarted and SCREEN.Music and SCREEN.Music.ChangeVolume then
            SCREEN.Music:ChangeVolume(eased, 0.08)
        end
    end

    function panel:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)

        local baseAlpha = self:GetImageAlpha()
        if baseAlpha <= 0 then return end

        local darkAlpha = math.floor(baseAlpha * SCREEN.ImageDarken)
        surface.SetDrawColor(255 - darkAlpha, 255 - darkAlpha, 255 - darkAlpha, baseAlpha)
        surface.SetMaterial(SCREEN.ImageMat)
        surface.DrawTexturedRect(0, 0, w, h)
    end

    panel.RespawnButton = makeButton(panel)

    SCREEN.Panel = panel
    gui.EnableScreenClicker(true)
end

hook.Add("Think", "zcity_delta_death_screen_state", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if SCREEN.DebugForced then
        createScreen()
        return
    end

    if not isDeathScreenEnabled() then
        if IsValid(SCREEN.Panel) then removeScreen() end
        return
    end

    if ply:Alive() then
        if IsValid(SCREEN.Panel) then removeScreen() end
        if SCREEN.Respawn and (SCREEN.Respawn.state == "waiting_spawn" or SCREEN.Respawn.state == "white_in") then
            startWhiteOut()
        end
        return
    end

    createScreen()
end)

hook.Add("ShutDown", "zcity_delta_death_screen_cleanup", removeScreen)

concommand.Add("zcity_delta_deathscreen_toggle", function()
    local cv = GetConVar and GetConVar("zcity_delta_deathscreen_enable") or nil
    local enabled = not (cv and cv.GetBool and cv:GetBool())
    RunConsoleCommand("zcity_delta_deathscreen_enable", enabled and "1" or "0")
    if not enabled then SCREEN.DebugForced = false removeScreen() end
    local text = enabled and "Death screen enabled" or "Death screen disabled"
    if notification and notification.AddLegacy then notification.AddLegacy(text, NOTIFY_GENERIC, 4)
    else chat.AddText(Color(255, 255, 255), text) end
end)

concommand.Add("zcity_delta_deathmenu", function()
    SCREEN.DebugForced = not SCREEN.DebugForced
    if SCREEN.DebugForced then
        createScreen()
        return
    end
    removeScreen()
end)
