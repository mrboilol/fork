if SERVER then return end

local SCREEN = {}

SCREEN.ImageMat = Material("zcity_delta/death/death.png", "noclamp")
SCREEN.LogBackgroundMat = Material("zcity_delta/death/background.png", "noclamp")
SCREEN.DocumentMat = Material("zcity_delta/death/document.png", "noclamp")
SCREEN.MusicPath = "zcity_delta/death.mp3"
SCREEN.LogsMusicPath = "zcity_delta/Documents.mp3"
SCREEN.FadeDelay = 1.1
SCREEN.FadeDuration = 2.8
SCREEN.ImageDarken = 0.45
SCREEN.StartHoldSeconds = 0.5
SCREEN.RespawnWhiteInSeconds = 0.5
SCREEN.RespawnWhiteOutSeconds = 0.6
SCREEN.RespawnNetName = "zcity_delta_death_respawn"
SCREEN.ReportNetName = "zcity_delta_death_report"
SCREEN.FontFace = "04b11"
SCREEN.FontAntialias = false
SCREEN.LogsTransitionSpeed = 5
SCREEN.DocumentPeekFrac = 0.16
SCREEN.DocumentDragSpeed = 10
SCREEN.ModelPanelWidthFrac = 0.26
SCREEN.ModelPanelInsetX = 0.11
SCREEN.ModelPanelInsetY = 0.19
SCREEN.ModelPanelInsetBottom = 0.24
SCREEN.DocumentAspect = 150 / 225
SCREEN.DocumentBaseWidth = 150
SCREEN.DocumentBaseHeight = 225
SCREEN.DocumentScale = 2.65
SCREEN.LogsBackgroundShade = 18
SCREEN.WoundMarkerSize = 10
SCREEN.WoundMarkerAlpha = 210

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
surface.CreateFont("zcity_delta_death_doc_name", { font = SCREEN.FontFace, size = 34, weight = 500, antialias = SCREEN.FontAntialias })
surface.CreateFont("zcity_delta_death_doc_text", { font = SCREEN.FontFace, size = 16, weight = 500, antialias = SCREEN.FontAntialias })

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

local function switchMusic(path)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if SCREEN.MusicPath == path and SCREEN.Music then return end
    stopMusic()
    SCREEN.MusicPath = path
    playMusic()
end

local function formatLifeTime(seconds)
    seconds = math.max(math.floor(seconds or 0), 0)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

local function getReport()
    return SCREEN.Report or {
        name = "UNKNOWN", lifeSeconds = 0, kills = 0, damageDealt = 0,
        damageTaken = 0, usedObjects = 0, distance = 0,
        lastAttacker = "Unknown cause", appearance = nil, wounds = {}
    }
end

local function buildReportLines()
    local report = getReport()
    return {
        "NAME: " .. string.upper(report.name or "UNKNOWN"),
        "LIFETIME: " .. formatLifeTime(report.lifeSeconds),
        "KILLS: " .. tostring(report.kills or 0),
        "DAMAGE DEALT: " .. tostring(report.damageDealt or 0),
        "DAMAGE TAKEN: " .. tostring(report.damageTaken or 0),
        "OBJECTS USED: " .. tostring(report.usedObjects or 0),
        "DISTANCE WALKED: " .. tostring(report.distance or 0) .. " M",
        "LAST THREAT: " .. tostring(report.lastAttacker or "Unknown cause")
    }
end

local function snap(v) return math.floor((v or 0) + 0.5) end

local function drawDocumentLineText(text, font, x, lineY, color, alignX)
    surface.SetFont(font)
    local _, textH = surface.GetTextSize(text or "")
    local y = snap(lineY - textH + 2)
    draw.SimpleText(text, font, x, y, color, alignX or TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function getDocumentLayout(w, h)
    local screenScale = math.min(w / 1920, h / 1080)
    local docW = SCREEN.DocumentBaseWidth * SCREEN.DocumentScale * screenScale
    local docH = SCREEN.DocumentBaseHeight * SCREEN.DocumentScale * screenScale
    local maxH = h * 0.82
    if docH > maxH then
        local ratio = maxH / docH
        docW = docW * ratio
        docH = docH * ratio
    end
    docW = snap(docW)
    docH = snap(docH)
    local docX = snap(w - docW - w * 0.045)
    local fullY = snap(h * 0.055)
    local hiddenY = snap(h - (docH * SCREEN.DocumentPeekFrac))
    return { x = docX, w = docW, h = docH, fullY = fullY, hiddenY = hiddenY }
end

local function makeButton(parent, id, dockRight)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetSize(180, 52)
    btn:SetCursor("hand")
    btn:SetZPos(9999)
    btn:SetEnabled(true)
    btn:SetMouseInputEnabled(true)
    btn.HoldStartAt = nil
    btn.HoldFrac = 0
    btn.HoldDone = false
    btn.HoldBySpace = false
    btn.__Pressed = false

    local function activateLogs()
        if id ~= "logs" then return end
        surface.PlaySound("buttons/button14.wav")
        parent:SetLogsView(not parent:GetLogsView())
    end

    function btn:Paint(w, h)
        local alpha = parent:GetUiAlpha()
        local hovered = self:IsHovered()
        surface.SetDrawColor(8, 8, 8, math.floor(alpha * (hovered and 0.92 or 0.72)))
        surface.DrawRect(0, 0, w, h)

        if id == "start" then
            local fillW = math.floor(w * easeInOut(self.HoldFrac or 0))
            if fillW > 0 then
                surface.SetDrawColor(170, 0, 0, math.floor(alpha * 0.35))
                surface.DrawRect(0, 0, fillW, h)
            end
        end

        local pulse = 0
        if id == "start" and self.HoldStartAt and not self.HoldDone then
            pulse = (math.sin(RealTime() * 10) * 0.5 + 0.5) * 0.35
        end

        surface.SetDrawColor(170, 0, 0, math.floor(alpha * (hovered and 1 or 0.75 + pulse)))
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        local label = parent:GetButtonLabel(id)
        if id == "start" then
            if self.HoldDone then label = "starting..."
            elseif self.HoldStartAt then label = "hold..." end
        end

        draw.SimpleText(label, "zcity_delta_death_button", snap(w * 0.5), snap(h * 0.5), Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function() activateLogs() end

    btn.OnMousePressed = function(self, mc)
        if id == "logs" then
            if mc ~= MOUSE_LEFT then return end
            self.__Pressed = true
            return
        end
        if id ~= "start" then return end
        if mc ~= MOUSE_LEFT then return end
        if self.HoldDone then return end
        if not IsValid(LocalPlayer()) or LocalPlayer():Alive() then return end
        self.HoldStartAt = RealTime()
        self.HoldFrac = 0
        surface.PlaySound("buttons/button15.wav")
    end

    btn.OnMouseReleased = function(self, mc)
        if id == "logs" then
            if mc ~= MOUSE_LEFT then return end
            local wasPressed = self.__Pressed
            self.__Pressed = false
            if wasPressed and self:IsHovered() then activateLogs() end
            return
        end
        if id ~= "start" then return end
        if mc ~= MOUSE_LEFT then return end
        if self.HoldDone then return end
        if self.HoldBySpace then return end
        self.HoldStartAt = nil
        self.HoldFrac = 0
    end

    if dockRight then
        btn:SetPos(parent:GetWide() - btn:GetWide() - 36, parent:GetTall() - btn:GetTall() - 28)
    else
        btn:SetPos(36, parent:GetTall() - btn:GetTall() - 28)
    end

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
    if IsValid(SCREEN.Panel) and isfunction(SCREEN.Panel.ApplyDeathReport) then
        SCREEN.Panel:ApplyDeathReport(SCREEN.Report)
    end
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
    panel.ViewBlend = 0
    panel.TargetView = 0
    panel.DocReveal = 0
    panel.DocRevealTarget = 0
    panel.DocDragging = false
    panel.DocDragStartMouseY = 0
    panel.DocDragStartReveal = 0
    panel.ModelPanel = nil
    panel.Wounds = {}

    function panel:GetLogsView() return (self.TargetView or 0) > 0.5 end
    function panel:SetLogsView(enabled)
        self.TargetView = enabled and 1 or 0
        if not enabled then
            self.DocRevealTarget = 0
            self.DocDragging = false
            switchMusic("zcity_delta/death.mp3")
        else
            self.DocRevealTarget = 0
            switchMusic(SCREEN.LogsMusicPath)
        end
    end

    function panel:GetUiAlpha() return self.ImageAlpha or 0 end
    function panel:GetImageAlpha() return self.ImageAlpha or 0 end

    function panel:GetDocumentRect()
        local layout = getDocumentLayout(self:GetWide(), self:GetTall())
        local reveal = easeInOut(self.DocReveal or 0)
        local y = Lerp(reveal, layout.hiddenY, layout.fullY)
        return layout.x, y, layout.w, layout.h, layout
    end

    function panel:GetModelPanelRect()
        local w, h = self:GetWide(), self:GetTall()
        local x = math.floor(w * SCREEN.ModelPanelInsetX)
        local y = math.floor(h * SCREEN.ModelPanelInsetY)
        local mw = math.floor(w * SCREEN.ModelPanelWidthFrac)
        local mh = math.floor(h * (1 - SCREEN.ModelPanelInsetY - SCREEN.ModelPanelInsetBottom))
        return x, y, mw, mh
    end

    function panel:FitModelCamera()
        if not IsValid(self.ModelPanel) or not IsValid(self.ModelPanel.Entity) then return end
        local ent = self.ModelPanel.Entity
        local mins, maxs = ent:GetRenderBounds()
        local center = (mins + maxs) * 0.5
        local size = math.max((maxs - mins):Length(), 1)
        self.ModelPanel:SetFOV(24)
        self.ModelPanel:SetLookAt(center + Vector(0, 0, size * 0.02))
        self.ModelPanel:SetCamPos(center + Vector(size * 1.6, size * 0.55, size * 0.16))
    end

    function panel:EnsureModelPanel()
        if IsValid(self.ModelPanel) then return end

        local mp = vgui.Create("DModelPanel", self)
        mp:SetMouseInputEnabled(true)
        mp:SetKeyboardInputEnabled(false)
        mp:SetCursor("sizeall")
        mp:SetFOV(24)
        mp:SetCamPos(Vector(140, 50, 45))
        mp:SetLookAt(Vector(0, 0, 36))
        mp.ModelYaw = 35
        mp.ModelPitch = 0
        mp.RotateDragging = false
        mp.RotateStartX = 0
        mp.RotateStartY = 0
        mp.RotateBaseYaw = 35
        mp.RotateBasePitch = 0
        mp.LayoutEntity = function(_, ent)
            if not IsValid(ent) then return end
            ent:SetAngles(Angle(mp.ModelPitch or 0, mp.ModelYaw or 35, 0))
            if ent.FrameAdvance then ent:FrameAdvance(FrameTime()) end
        end
        mp.OnMousePressed = function(self, mc)
            if mc ~= MOUSE_LEFT then return end
            self.RotateDragging = true
            self.RotateStartX = gui.MouseX()
            self.RotateStartY = gui.MouseY()
            self.RotateBaseYaw = self.ModelYaw or 35
            self.RotateBasePitch = self.ModelPitch or 0
            self:MouseCapture(true)
        end
        mp.OnMouseReleased = function(self, mc)
            if mc ~= MOUSE_LEFT then return end
            self.RotateDragging = false
            self:MouseCapture(false)
        end
        mp.Think = function(self)
            if not self.RotateDragging then return end
            local dx = gui.MouseX() - (self.RotateStartX or gui.MouseX())
            local dy = gui.MouseY() - (self.RotateStartY or gui.MouseY())
            self.ModelYaw = (self.RotateBaseYaw or 35) - dx * 0.35
            self.ModelPitch = math.Clamp((self.RotateBasePitch or 0) + dy * 0.12, -22, 18)
        end
        mp:SetAmbientLight(Color(170, 170, 170))
        mp:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
        mp:SetDirectionalLight(BOX_FRONT, Color(220, 220, 220))

        local glow = Material("sprites/light_glow02_add")
        function mp:PaintOver(w, h)
            if not self.Entity or not IsValid(self.Entity) then return end
            if not istable(self.Wounds) or #self.Wounds <= 0 then return end

            local px, py = self:LocalToScreen(0, 0)
            local camPos = self.vCamPos or self:GetCamPos()
            local lookAt = self.vLookatPos or self:GetLookAt()
            local fov = self.fFOV or self:GetFOV()
            local ang = (lookAt - camPos):Angle()

            cam.Start3T(camPos, ang, fov, px, py, w, h)
                render.SetMaterial(glow)
                cam.IgnoreZ(true)
                for _, wound in ipairs(self.Wounds) do
                    local boneName = wound and wound.bone or nil
                    if not boneName then continue end
                    local boneId = self.Entity:LookupBone(boneName)
                    if not boneId then continue end
                    local pos, woundAng
                    local mat = self.Entity:GetBoneMatrix(boneId)
                    if mat and istable(wound.localPos) then
                        local bonePos = mat:GetTranslation()
                        local boneAng = mat:GetAngles()
                        local localPos = Vector(wound.localPos.x or 0, wound.localPos.y or 0, wound.localPos.z or 0)
                        local localAng = istable(wound.localAng) and Angle(wound.localAng.p or 0, wound.localAng.y or 0, wound.localAng.r or 0) or angle_zero
                        pos, woundAng = LocalToWorld(localPos, localAng, bonePos, boneAng)
                    else
                        pos = select(1, self.Entity:GetBonePosition(boneId))
                        woundAng = self.Entity:GetBoneAngle(boneId) or angle_zero
                    end
                    if not isvector(pos) then continue end

                    local dmg = tonumber(wound.dmg) or 0
                    local a = math.Clamp(SCREEN.WoundMarkerAlpha + dmg * 40, 90, 255)
                    woundAng = woundAng or angle_zero
                    local radius = math.Clamp((1.3 + dmg * 0.95) / 4.5, 0.4, 0.95)
                    local viewDir = (camPos - pos):GetNormalized()
                    local surfaceDir = woundAng:Forward()
                    if viewDir:Dot(surfaceDir) < 0 then surfaceDir = -surfaceDir end
                    local drawPos = pos + surfaceDir * math.max(radius * 0.5, 0.22) + viewDir * math.max(radius * 0.35, 0.14)

                    render.SetColorMaterial()
                    render.DrawSphere(drawPos, radius * 1.08, 10, 10, Color(95, 0, 0, math.min(a + 10, 255)))
                    render.DrawSphere(drawPos, radius * 0.76, 10, 10, Color(210, 28, 28, a))
                    render.SetMaterial(glow)
                    render.DrawSprite(drawPos + viewDir * 0.2, radius * 2.2, radius * 2.2, Color(255, 95, 95, math.min(a + 12, 255)))
                end
                cam.IgnoreZ(false)
            cam.End3D()
        end

        self.ModelPanel = mp
    end

    function panel:ApplyDeathReport(report)
        if not istable(report) then return end
        self.Wounds = istable(report.wounds) and report.wounds or {}
        self:EnsureModelPanel()

        local app = istable(report.appearance) and report.appearance or nil
        if not app or not IsValid(self.ModelPanel) then return end

        local model = tostring(app.model or "")
        if model ~= "" then self.ModelPanel:SetModel(model) end

        local ent = self.ModelPanel.Entity
        if not IsValid(ent) then return end
        ent:SetNoDraw(false)
        ent:SetMaterial("")
        ent:SetColor(color_white)
        ent:SetModelScale(1, 0)
        if ent.GetNumSubMaterials and ent.SetSubMaterial then
            local subCount = ent:GetNumSubMaterials() or 0
            for i = 0, math.max(subCount - 1, -1) do ent:SetSubMaterial(i, "") end
        end

        if isnumber(app.skin) then ent:SetSkin(app.skin) end
        if istable(app.bodygroups) then
            for k, v in pairs(app.bodygroups) do
                local idx = tonumber(k)
                if idx then ent:SetBodygroup(idx, tonumber(v) or 0) end
            end
        end
        if istable(app.color) and app.color.r then
            ent:SetColor(Color(app.color.r or 255, app.color.g or 255, app.color.b or 255, app.color.a or 255))
        end
        if isnumber(app.modelScale) and app.modelScale > 0 then ent:SetModelScale(app.modelScale, 0) end
        if istable(app.playerColor) and ent.GetPlayerColor then
            local pc = Vector(app.playerColor.x or 1, app.playerColor.y or 1, app.playerColor.z or 1)
            ent.GetPlayerColor = function() return pc end
        end

        self.ModelPanel.Wounds = self.Wounds
        self:FitModelCamera()
    end

    function panel:IsCursorOverDocument()
        local x, y, w, h = self:GetDocumentRect()
        local mx, my = gui.MouseX(), gui.MouseY()
        return mx >= x and mx <= x + w and my >= y and my <= y + h
    end

    function panel:Think()
        if not IsValid(LocalPlayer()) then removeScreen() return end
        if LocalPlayer():Alive() and not SCREEN.DebugForced then removeScreen() return end

        if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then
            self:SetSize(ScrW(), ScrH())
            if IsValid(self.StartButton) then self.StartButton:SetPos(36, self:GetTall() - self.StartButton:GetTall() - 28) end
            if IsValid(self.LogsButton) then self.LogsButton:SetPos(self:GetWide() - self.LogsButton:GetWide() - 36, self:GetTall() - self.LogsButton:GetTall() - 28) end
            if IsValid(self.ModelPanel) then
                local mx, my, mw, mh = self:GetModelPanelRect()
                self.ModelPanel:SetPos(mx, my)
                self.ModelPanel:SetSize(mw, mh)
            end
        end

        local elapsed = RealTime() - self.StartedAt
        local fadeFrac = math.Clamp((elapsed - SCREEN.FadeDelay) / SCREEN.FadeDuration, 0, 1)
        local eased = easeInOut(fadeFrac)
        self.ImageAlpha = math.floor(255 * eased)
        self.ViewBlend = Lerp(FrameTime() * SCREEN.LogsTransitionSpeed, self.ViewBlend or 0, self.TargetView or 0)
        self.DocReveal = Lerp(FrameTime() * SCREEN.DocumentDragSpeed, self.DocReveal or 0, self.DocRevealTarget or 0)

        if self:GetLogsView() then
            local down = input and input.IsMouseDown and input.IsMouseDown(MOUSE_LEFT) or false
            local lastDown = self.__zcity_delta_doc_down or false
            if down and not lastDown and self:IsCursorOverDocument() then
                self.DocDragging = true
                self.DocDragStartMouseY = gui.MouseY()
                self.DocDragStartReveal = self.DocRevealTarget or self.DocReveal or 0
            elseif not down then self.DocDragging = false end
            self.__zcity_delta_doc_down = down
            if self.DocDragging and down then
                local _, _, _, _, layout = self:GetDocumentRect()
                local dragRange = math.max(layout.hiddenY - layout.fullY, 1)
                local dragDelta = (self.DocDragStartMouseY or gui.MouseY()) - gui.MouseY()
                self.DocRevealTarget = math.Clamp((self.DocDragStartReveal or 0) + dragDelta / dragRange, 0, 1)
            end
        else
            self.DocDragging = false
            self.__zcity_delta_doc_down = false
        end

        if fadeFrac > 0 and not self.MusicStarted then
            self.MusicStarted = true
            playMusic()
        end
        if self.MusicStarted and SCREEN.Music and SCREEN.Music.ChangeVolume then
            SCREEN.Music:ChangeVolume(eased, 0.08)
        end

        if IsValid(self.StartButton) and not self.StartButton.HoldDone then
            local spaceDown = input and input.IsKeyDown and input.IsKeyDown(KEY_SPACE) or false
            if spaceDown and not self.StartButton.HoldStartAt then
                self.StartButton.HoldBySpace = true
                self.StartButton.HoldStartAt = RealTime()
                self.StartButton.HoldFrac = 0
                surface.PlaySound("buttons/button15.wav")
            elseif not spaceDown and self.StartButton.HoldBySpace then
                self.StartButton.HoldBySpace = false
                self.StartButton.HoldStartAt = nil
                self.StartButton.HoldFrac = 0
            end
        end

        if IsValid(self.StartButton) and self.StartButton.HoldStartAt and not self.StartButton.HoldDone then
            local holdElapsed = RealTime() - self.StartButton.HoldStartAt
            local frac = math.Clamp(holdElapsed / SCREEN.StartHoldSeconds, 0, 1)
            self.StartButton.HoldFrac = frac
            if frac >= 1 then
                self.StartButton.HoldDone = true
                self.StartButton.HoldStartAt = nil
                self.StartButton.HoldBySpace = false
                self.StartButton.HoldFrac = 1
                self.StartButton:SetMouseInputEnabled(false)
                if IsValid(self.LogsButton) then self.LogsButton:SetMouseInputEnabled(false) end
                startWhiteIn()
            end
        end
    end

    function panel:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)

        local baseAlpha = self:GetImageAlpha()
        if baseAlpha <= 0 then return end

        local viewFrac = easeInOut(self.ViewBlend or 0)
        local mainAlpha = math.floor(baseAlpha * (1 - viewFrac))
        if mainAlpha > 0 then
            local darkAlpha = math.floor(mainAlpha * SCREEN.ImageDarken)
            surface.SetDrawColor(255 - darkAlpha, 255 - darkAlpha, 255 - darkAlpha, mainAlpha)
            surface.SetMaterial(SCREEN.ImageMat)
            surface.DrawTexturedRect(0, 0, w, h)
        end

        local logsAlpha = math.floor(baseAlpha * viewFrac)
        if logsAlpha > 0 then
            if IsValid(self.ModelPanel) then
                self.ModelPanel:SetVisible(true)
                self.ModelPanel:MoveToFront()
            end
            local shade = SCREEN.LogsBackgroundShade or 18
            surface.SetDrawColor(shade, shade, shade, logsAlpha)
            surface.SetMaterial(SCREEN.LogBackgroundMat)
            surface.DrawTexturedRect(0, 0, w, h)

            local docX, docY, docW, docH = self:GetDocumentRect()
            surface.SetDrawColor(255, 255, 255, logsAlpha)
            surface.SetMaterial(SCREEN.DocumentMat)
            surface.DrawTexturedRect(docX, docY, docW, docH)

            local report = getReport()
            local nameAlpha = math.floor(logsAlpha * 0.96)
            local titleLineY = snap(docY + docH * 0.118)
            drawDocumentLineText(string.upper(report.name or "UNKNOWN"), "zcity_delta_death_doc_name", snap(docX + docW * 0.5), titleLineY, Color(20, 20, 20, nameAlpha), TEXT_ALIGN_CENTER)

            local lines = buildReportLines()
            local textX = snap(docX + docW * 0.09)
            local firstLineY = snap(docY + docH * 0.232)
            local lineStep = snap(docH * 0.066)
            for i, line in ipairs(lines) do
                drawDocumentLineText(line, "zcity_delta_death_doc_text", textX, snap(firstLineY + (i - 1) * lineStep), Color(24, 24, 24, logsAlpha), TEXT_ALIGN_LEFT)
            end
        end
    end

    function panel:GetButtonLabel(id)
        if id == "logs" then return self:GetLogsView() and "back" or "logs" end
        return "start"
    end

    panel.StartButton = makeButton(panel, "start", false)
    panel.LogsButton = makeButton(panel, "logs", true)

    panel:EnsureModelPanel()
    do
        local mx, my, mw, mh = panel:GetModelPanelRect()
        panel.ModelPanel:SetPos(mx, my)
        panel.ModelPanel:SetSize(mw, mh)
    end
    panel.ModelPanel:SetVisible(false)
    if SCREEN.Report then panel:ApplyDeathReport(SCREEN.Report) end

    SCREEN.Panel = panel
    gui.EnableScreenClicker(true)
end

hook.Add("Think", "zcity_delta_death_screen_state", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if SCREEN.DebugForced then
        createScreen()
        if IsValid(SCREEN.Panel) and IsValid(SCREEN.Panel.ModelPanel) then
            SCREEN.Panel.ModelPanel:SetVisible((SCREEN.Panel.ViewBlend or 0) > 0.08)
        end
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
    if IsValid(SCREEN.Panel) and IsValid(SCREEN.Panel.ModelPanel) then
        SCREEN.Panel.ModelPanel:SetVisible((SCREEN.Panel.ViewBlend or 0) > 0.08)
    end
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
        if IsValid(SCREEN.Panel) and SCREEN.Report and isfunction(SCREEN.Panel.ApplyDeathReport) then
            SCREEN.Panel:ApplyDeathReport(SCREEN.Report)
        end
        return
    end
    removeScreen()
end)
