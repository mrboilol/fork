if SERVER then return end

local PANEL = {}

local circleMat = Material("vgui/circle")

local function IsBruiceKitActive()
    local lp = LocalPlayer()
    if not IsValid(lp) then return false end
    local wep = lp:GetActiveWeapon()
    if not IsValid(wep) then return false end
    return wep:GetClass() == "weapon_bruicekit"
end

local function LoadHudMaterial(path, fallbackPath)
    local paths = {path}
    if fallbackPath then
        paths[#paths + 1] = fallbackPath
    end

    for _, materialPath in ipairs(paths) do
        local mat = Material(materialPath, "smooth noclamp")
        if type(mat) == "IMaterial" and not mat:IsError() then
            return mat
        end
    end

    return nil
end

local function SetHudMaterial(mat)
    if type(mat) ~= "IMaterial" or mat:IsError() then return false end
    surface.SetMaterial(mat)
    return true
end

local handMat = LoadHudMaterial("homigrad/hand.png", "homigrad/hand")
local handStatusFrameDuration = 0.8
local handStatusStepDuration = 0.1
local handFrameSequence = {1, 2, 3}
local handStatusSequence = {0, 2, 3}
local handFrames = {
    [0] = {},
    [2] = {},
    [3] = {},
}
local handPlaybackFrames = {}

for _, status in ipairs(handStatusSequence) do
    for _, frame in ipairs(handFrameSequence) do
        local mat = LoadHudMaterial(
            "homigrad/handanim/" .. frame .. "_" .. status .. ".png",
            "homigrad/handanim/" .. frame .. "_" .. status
        )

        if mat then
            handFrames[status][#handFrames[status] + 1] = mat
        end
    end
end

for _, status in ipairs(handStatusSequence) do
    local frames = handFrames[status]
    local playback = {}

    if frames and #frames > 0 then
        for i = 1, #frames do
            playback[#playback + 1] = frames[i]
        end

        for i = #frames - 1, 1, -1 do
            playback[#playback + 1] = frames[i]
        end
    end

    handPlaybackFrames[status] = playback
end

local bleedFrames = {}
local bleedFrameCount = 6

for i = 1, bleedFrameCount do
    bleedFrames[i] = LoadHudMaterial("homigrad/bleedanim/" .. i .. ".png", "homigrad/bleedanim/" .. i)
end

local syringeBaseMat = LoadHudMaterial("homigrad/syringe/s2.png", "homigrad/syringe/s2")
local syringePlungerFrames = {}
local syringePlungerFrameDuration = 0.09
local amputationVisualStateCache = {}
local dislocationLimbLabels = {
    larm = "LEFT ARM",
    rarm = "RIGHT ARM",
    lleg = "LEFT LEG",
    rleg = "RIGHT LEG",
    jaw = "JAW"
}

local function GetAmputationVisualStateKey(target, limb)
    local targetId = "self"
    if IsValid(target) then
        targetId = "ent:" .. target:EntIndex()
    end

    return targetId .. ":" .. tostring(limb or "unknown")
end

local function GetAmputationVisualState(target, limb)
    return amputationVisualStateCache[GetAmputationVisualStateKey(target, limb)]
end

local function SetAmputationVisualState(target, limb, state)
    amputationVisualStateCache[GetAmputationVisualStateKey(target, limb)] = state
end

local function ClearAmputationVisualState(target, limb)
    amputationVisualStateCache[GetAmputationVisualStateKey(target, limb)] = nil
end

local function ClearAllAmputationVisualState()
    amputationVisualStateCache = {}

    if hg and hg.MedicalMinigame then
        hg.MedicalMinigame.NextTarget = nil
        hg.MedicalMinigame.NextLimb = nil
        hg.MedicalMinigame.NextProgress = 0
    end
end

local function IsLocalPlayerUnconscious()
    local lp = LocalPlayer()
    return IsValid(lp) and lp.organism and lp.organism.otrub
end

for i = 1, 3 do
    syringePlungerFrames[i] = LoadHudMaterial("homigrad/syringe/s1_" .. i .. ".png", "homigrad/syringe/s1_" .. i)
end

local medicalMusicPath = "sound/homigrad/medical_minigame_trade.mp3"

local function NormalizeAngleDiff(diff)
    if diff > math.pi then diff = diff - 2 * math.pi end
    if diff < -math.pi then diff = diff + 2 * math.pi end
    return diff
end

local function AppendBandageTrail(points, fromAngle, toAngle, step)
    if not isnumber(fromAngle) or not isnumber(toAngle) then return end

    step = math.max(step or math.rad(2), 0.0001)

    if #points == 0 then
        points[1] = { angle = fromAngle }
    else
        local lastAngle = points[#points].angle
        if math.abs(NormalizeAngleDiff(lastAngle - fromAngle)) > 0.0005 then
            points[#points + 1] = { angle = fromAngle }
        end
    end

    local diff = NormalizeAngleDiff(toAngle - fromAngle)
    local distance = math.abs(diff)

    if distance <= step then
        points[#points + 1] = { angle = toAngle }
        return
    end

    local steps = math.max(math.ceil(distance / step), 1)
    for i = 1, steps do
        local t = i / steps
        points[#points + 1] = {
            angle = fromAngle + diff * t
        }
    end
end

local function DrawBandageTrail(panel, points, radius, alpha, thickness, col)
    if #points <= 1 then return end

    thickness = thickness or 15
    local c = col or color_white
    surface.SetDrawColor(c.r, c.g, c.b, alpha or 180)
    
    for i = 1, #points - 1 do
        local p1 = points[i]
        local p2 = points[i + 1]
        
        local a1, a2 = p1.angle, p2.angle
        
        -- Calculate the four polygon points for a thick line segment
        local r1 = radius
        local r2 = radius + thickness
        
        local cos1, sin1 = math.cos(a1), math.sin(a1)
        local cos2, sin2 = math.cos(a2), math.sin(a2)
        
        local p1x, p1y = panel.CenterX + cos1 * r1, panel.CenterY + sin1 * r1
        local p2x, p2y = panel.CenterX + cos2 * r1, panel.CenterY + sin2 * r1
        local p3x, p3y = panel.CenterX + cos2 * r2, panel.CenterY + sin2 * r2
        local p4x, p4y = panel.CenterX + cos1 * r2, panel.CenterY + sin1 * r2
        
        draw.NoTexture()
        surface.DrawPoly({
            { x = p1x, y = p1y },
            { x = p2x, y = p2y },
            { x = p3x, y = p3y },
            { x = p4x, y = p4y }
        })
    end
end

local function DrawBandageRing(panel, radius, alpha, thickness, col)
    thickness = thickness or 15
    local segments = 96
    local innerRadius = radius
    local outerRadius = radius + thickness

    local c = col or color_white
    surface.SetDrawColor(c.r, c.g, c.b, alpha or 180)

    for i = 0, segments - 1 do
        local a1 = math.rad((i / segments) * 360)
        local a2 = math.rad(((i + 1) / segments) * 360)
        local cos1, sin1 = math.cos(a1), math.sin(a1)
        local cos2, sin2 = math.cos(a2), math.sin(a2)

        draw.NoTexture()
        surface.DrawPoly({
            {x = panel.CenterX + cos1 * innerRadius, y = panel.CenterY + sin1 * innerRadius},
            {x = panel.CenterX + cos2 * innerRadius, y = panel.CenterY + sin2 * innerRadius},
            {x = panel.CenterX + cos2 * outerRadius, y = panel.CenterY + sin2 * outerRadius},
            {x = panel.CenterX + cos1 * outerRadius, y = panel.CenterY + sin1 * outerRadius}
        })
    end
end

local function DrawFallbackHand(x, y, angle)
    local rad = math.rad(angle or 0)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local points = {
        {x = -105, y = 150},
        {x = -70, y = -120},
        {x = -25, y = -155},
        {x = 5, y = -55},
        {x = 45, y = -175},
        {x = 85, y = -165},
        {x = 55, y = -35},
        {x = 105, y = -160},
        {x = 145, y = -130},
        {x = 95, y = -10},
        {x = 160, y = -80},
        {x = 200, y = -40},
        {x = 120, y = 95},
        {x = 70, y = 65},
        {x = 25, y = 175},
        {x = -45, y = 185}
    }

    local poly = {}
    for _, point in ipairs(points) do
        poly[#poly + 1] = {
            x = x + (point.x * cosA - point.y * sinA),
            y = y + (point.x * sinA + point.y * cosA)
        }
    end

    draw.NoTexture()
    surface.SetDrawColor(30, 30, 30, 120)
    surface.DrawPoly(poly)

    for _, point in ipairs(poly) do
        point.x = x + ((point.x - x) * 0.94)
        point.y = y + ((point.y - y) * 0.94)
    end

    surface.SetDrawColor(255, 255, 255, 245)
    surface.DrawPoly(poly)
end

local function DrawRotatedBar(x, y, width, height, angleDeg, color)
    local halfW = width * 0.5
    local halfH = height * 0.5
    local rad = math.rad(angleDeg or 0)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local corners = {
        {-halfW, -halfH},
        {halfW, -halfH},
        {halfW, halfH},
        {-halfW, halfH}
    }
    local poly = {}

    for i = 1, 4 do
        local corner = corners[i]
        poly[i] = {
            x = x + corner[1] * cosA - corner[2] * sinA,
            y = y + corner[1] * sinA + corner[2] * cosA
        }
    end

    draw.NoTexture()
    surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
    surface.DrawPoly(poly)
end

local function DrawFilledCircle(x, y, radius, color, segments)
    segments = segments or 48

    local poly = {}
    for i = 0, segments do
        local a = math.rad((i / segments) * 360)
        poly[#poly + 1] = {
            x = x + math.cos(a) * radius,
            y = y + math.sin(a) * radius
        }
    end

    draw.NoTexture()
    surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
    surface.DrawPoly(poly)
end

local function DrawOutlinedBone(x, y, width, height, angleDeg, outlineColor, innerColor)
    outlineColor = outlineColor or Color(255, 255, 255, 255)
    innerColor = innerColor or Color(0, 0, 0, 255)

    local endOffset = (width * 0.5) - (height * 0.3)
    local rad = math.rad(angleDeg or 0)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local function RotateOffset(localX, localY)
        return x + localX * cosA - localY * sinA, y + localX * sinA + localY * cosA
    end

    DrawRotatedBar(x, y, width, height * 0.46, angleDeg, outlineColor)

    local lx, ly = RotateOffset(-endOffset, 0)
    local rx, ry = RotateOffset(endOffset, 0)
    DrawFilledCircle(lx, ly - height * 0.22, height * 0.26, outlineColor, 24)
    DrawFilledCircle(lx, ly + height * 0.22, height * 0.26, outlineColor, 24)
    DrawFilledCircle(rx, ry - height * 0.22, height * 0.26, outlineColor, 24)
    DrawFilledCircle(rx, ry + height * 0.22, height * 0.26, outlineColor, 24)

    DrawRotatedBar(x, y, width - 10, math.max(height * 0.3, 8), angleDeg, innerColor)
    DrawFilledCircle(lx, ly - height * 0.22, height * 0.16, innerColor, 20)
    DrawFilledCircle(lx, ly + height * 0.22, height * 0.16, innerColor, 20)
    DrawFilledCircle(rx, ry - height * 0.22, height * 0.16, innerColor, 20)
    DrawFilledCircle(rx, ry + height * 0.22, height * 0.16, innerColor, 20)
end

local function DrawAmputationBlade(x, y, width, height, angleDeg)
    local rad = math.rad(angleDeg or 0)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local bladePoly = {
        {-width * 0.44, -height * 0.12},
        {width * 0.24, -height * 0.2},
        {width * 0.5, -height * 0.02},
        {width * 0.26, height * 0.17},
        {-width * 0.48, height * 0.1}
    }
    local drawPoly = {}

    for i, point in ipairs(bladePoly) do
        drawPoly[i] = {
            x = x + point[1] * cosA - point[2] * sinA,
            y = y + point[1] * sinA + point[2] * cosA
        }
    end

    DrawRotatedBar(x - width * 0.31 * cosA, y - width * 0.31 * sinA, width * 0.22, height * 0.24, angleDeg, Color(65, 28, 18, 255))
    DrawRotatedBar(x - width * 0.42 * cosA, y - width * 0.42 * sinA, width * 0.05, height * 0.28, angleDeg, Color(220, 210, 200, 255))

    draw.NoTexture()
    surface.SetDrawColor(240, 165, 170, 185)
    surface.DrawPoly(drawPoly)

    local shinePoly = {}
    for i, point in ipairs(bladePoly) do
        shinePoly[i] = {
            x = x + (point[1] * 0.88) * cosA - (point[2] * 0.72) * sinA,
            y = y + (point[1] * 0.88) * sinA + (point[2] * 0.72) * cosA
        }
    end

    surface.SetDrawColor(255, 215, 220, 105)
    surface.DrawPoly(shinePoly)
end

local function GetHandDrawPosition(x, y, angleDeg)
    -- Cursor hotspot sits between the fingers, not at the texture center.
    local hotspotOffsetX = -115
    local hotspotOffsetY = -120
    local rad = math.rad(angleDeg or 0)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local rotatedX = hotspotOffsetX * cosA - hotspotOffsetY * sinA
    local rotatedY = hotspotOffsetX * sinA + hotspotOffsetY * cosA

    return x - rotatedX, y - rotatedY
end

local function GetAnimatedHandMaterial(panel)
    local status = 0
    if panel.HandSqueezeStartTime then
        local elapsed = CurTime() - panel.HandSqueezeStartTime
        local statusStep = math.min(math.floor(elapsed / handStatusStepDuration), 2)
        status = handStatusSequence[statusStep + 1] or 3
    end

    local frames = handPlaybackFrames[status]
    if frames and #frames > 0 then
        local frameIndex = (math.floor(CurTime() / handStatusFrameDuration) % #frames) + 1
        return frames[frameIndex] or frames[1]
    end

    return handMat
end

local function GetAnimatedSyringePlungerMaterial(panel)
    if #syringePlungerFrames <= 0 then return nil end
    if not panel or panel.GameType ~= "syringe" then
        return syringePlungerFrames[1]
    end

    if panel.Dragging and panel.SyringeGrabbed and panel.HandSqueezeStartTime then
        local elapsed = CurTime() - panel.HandSqueezeStartTime
        local frameIndex = (math.floor(elapsed / syringePlungerFrameDuration) % #syringePlungerFrames) + 1
        return syringePlungerFrames[frameIndex] or syringePlungerFrames[1]
    end

    local progressFrame = math.Clamp(math.floor(panel.Progress * #syringePlungerFrames) + 1, 1, #syringePlungerFrames)
    return syringePlungerFrames[progressFrame] or syringePlungerFrames[1]
end

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:Center()
    self:MakePopup()
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(false)
    
    -- Hide the default cursor
    self:SetCursor("none")

    self.Progress = 0
    self.Turns = 0
    self.LastAngle = nil
    self.AccumulatedAngle = 0
    self.WrapAngle = 0
    self.GameType = (hg and hg.MedicalMinigame and hg.MedicalMinigame.NextType) or "bandage"
    self.TargetTurns = (self.GameType == "bandage") and 1 or (hg.MedicalMinigame.RequiredTurns or 6)
    self.BandageCompletions = hg.MedicalMinigame.NextCompletions or 0
    self.BandageRequiredCompletions = hg.MedicalMinigame.NextRequiredCompletions or 3
    
    self.CenterX = ScrW() / 2
    self.CenterY = ScrH() / 2
    self.Radius = 150
    self.MaxBandageDistance = 345
    self.BandageFollowSpeed = 2.2
    self.WrapSpeedMultiplier = 0.6
    self.VisualWrapThicknessStep = 1.5
    
    self.LastProgressSent = 0
    self.FluidVisualProgress = 0
    
    self.CurrentAngleObj = Angle(0, 0, 0)
    self.TargetAngleObj = Angle(0, 0, 0)
    
    self.TrailPoints = {}
    self.CompletedWraps = 0

    self.TourniquetStage = 1
    self.TourniquetStrapProgress = 0
    self.TourniquetStrapGrabbed = false
    self.TourniquetTubeAccumulatedAngle = 0
    self.TourniquetTubeRotation = 0
    self.TourniquetTubeRequiredTurns = 4.5 -- Increased for harder turning
    self.TourniquetLastTubeAngle = nil
    self.TourniquetStageSwitchUntil = 0
    self.TourniquetTurnCount = 0 -- Track turns for increasing pain

    self.SyringeGrabbed = false
    self.SyringeGrabOffsetY = 0

    -- Parameters for smooth hand movement
    self.HandX, self.HandY = self:CursorPos()
    self.HandAngle = 0
    self.LastMX, self.LastMY = self.HandX, self.HandY
    self.ShakeX = 0
    self.ShakeY = 0

    if self.GameType == "syringe" then
        local currentAmount, totalAmount = self:GetSyringeAmounts()
        self.SyringeTotalAmount = totalAmount
        self.SyringeStartAmount = currentAmount
        self.SyringeStartRemainingFraction = totalAmount > 0 and math.Clamp(currentAmount / totalAmount, 0, 1) or 0
        self.SyringeStartUsedFraction = 1 - self.SyringeStartRemainingFraction
        self.FluidVisualProgress = self.SyringeStartUsedFraction
    elseif self.GameType == "dislocation" then
        self.DislocationTarget = hg and hg.MedicalMinigame and hg.MedicalMinigame.NextTarget or LocalPlayer()
        self.DislocationLimb = hg and hg.MedicalMinigame and hg.MedicalMinigame.NextLimb or "larm"
        self.DislocationSide = (hg and hg.MedicalMinigame and hg.MedicalMinigame.NextDislocationSide) or 1
        self.Progress = math.Clamp((hg and hg.MedicalMinigame and hg.MedicalMinigame.NextProgress) or 0, 0, 1)
        self.LastProgressSent = self.Progress
        local sign = self.DislocationSide >= 0 and 1 or -1
        self.DislocationFixedBoneWidth = 230
        self.DislocationFixedBoneHeight = 90
        self.DislocationMoveBoneWidth = 220
        self.DislocationMoveBoneHeight = 84
        self.DislocationMoveAngle = -18 * sign
        self.DislocationFixedBoneX = self.CenterX - (260 * sign)
        self.DislocationFixedBoneY = self.CenterY + 140
        local fixedEndOffset = (self.DislocationFixedBoneWidth * 0.5) - (self.DislocationFixedBoneHeight * 0.3)
        local fixedEndX = self.DislocationFixedBoneX + fixedEndOffset * sign
        local fixedEndY = self.DislocationFixedBoneY
        self.DislocationMoveX = fixedEndX + (265 * sign)
        self.DislocationMoveY = fixedEndY - 220
        self.DislocationMoveStartX = self.DislocationMoveX
        self.DislocationMoveStartY = self.DislocationMoveY
        self.DislocationVelX = 0
        self.DislocationVelY = 0
        self.DislocationDrag = 2.6
        self.DislocationMaxSpeed = 120  
        self.DislocationMaxTravel = 300
        self.DislocationAimMaxLen = 50
        self.DislocationImpulseScale = 4.0
        self.DislocationImpulseCap = 950
        self.DislocationSnapWindow = 18
        self.DislocationStableSpeed = 260
        self.DislocationAppliedForce = 0
    elseif self.GameType == "amputation" then
        self.AmputationTarget = hg and hg.MedicalMinigame and hg.MedicalMinigame.NextTarget or LocalPlayer()
        self.AmputationLimb = hg and hg.MedicalMinigame and hg.MedicalMinigame.NextLimb or "larm"
        self.Progress = math.Clamp((hg and hg.MedicalMinigame and hg.MedicalMinigame.NextProgress) or 0, 0, 1)
        self.LastProgressSent = self.Progress
        self.AmputationRequiredTravel = 8000
        self.AmputationSawRange = 190
        self.AmputationZoneHalfHeight = 115
        self.AmputationCutY = self.CenterY + 28
        local savedState = GetAmputationVisualState(self.AmputationTarget, self.AmputationLimb)
        self.AmputationKnifeOffsetX = math.Clamp(savedState and savedState.offsetX or 0, -self.AmputationSawRange, self.AmputationSawRange)
        self.AmputationKnifeAngle = savedState and savedState.angle or 0
        self.AmputationKnifeBaseY = self.AmputationCutY - 130
        self.AmputationKnifeSink = 220
        self.AmputationKnifeSwayX = savedState and savedState.swayX or 0
        self.AmputationVisualProgress = math.max(self.Progress, savedState and savedState.visualProgress or 0)
        self.AmputationMaxSwipeSpeed = 0
        self.AmputationSmoothedMoveX = 0
        self.AmputationFillSpeedCap = 520
    end

end

function PANEL:StartMusic()
    if not hg or not hg.MedicalMinigame then return end

    local existingChannel = hg.MedicalMinigame.SoundChannel
    if existingChannel and existingChannel.Stop then
        existingChannel:Stop()
    end

    sound.PlayFile(medicalMusicPath, "noplay noblock", function(channel)
        if not IsValid(self) then
            if channel and channel.Stop then
                channel:Stop()
            end
            return
        end

        if not channel or not channel.Play then return end

        self.MusicChannel = channel
        hg.MedicalMinigame.SoundChannel = channel

        if channel.SetVolume then
            channel:SetVolume(1)
        end

        if channel.EnableLooping then
            channel:EnableLooping(true)
        end

        channel:Play()
    end)
end

function PANEL:StopMusic()
    local channel = self.MusicChannel or (hg and hg.MedicalMinigame and hg.MedicalMinigame.SoundChannel)
    self.MusicChannel = nil

    if hg and hg.MedicalMinigame and hg.MedicalMinigame.SoundChannel == channel then
        hg.MedicalMinigame.SoundChannel = nil
    end

    if not channel or not channel.Stop then return end

    if not channel.SetVolume then
        channel:Stop()
        return
    end

    local fadeTime = 0.45
    local fadeSteps = 9
    local fadeId = "hg_medical_music_fade_" .. math.floor(SysTime() * 1000000)

    for step = 1, fadeSteps do
        timer.Create(fadeId .. "_" .. step, (fadeTime / fadeSteps) * step, 1, function()
            if not channel or not channel.Stop then return end

            local volume = math.max(1 - (step / fadeSteps), 0)
            if channel.SetVolume then
                channel:SetVolume(volume)
            end

            if step == fadeSteps and channel.Stop then
                channel:Stop()
            end
        end)
    end
end

function PANEL:OnMousePressed(code)
    if code == MOUSE_LEFT then
        self.Dragging = true
        self.HandSqueezeStartTime = CurTime()
        local mx, my = self:CursorPos()
        if self.GameType == "dislocation" then
            local boneX = self.DislocationMoveX or 0
            local boneY = self.DislocationMoveY or 0
            local dx = mx - boneX
            local dy = my - boneY
            local grabRadius = 115
            self.DislocationAiming = (dx * dx + dy * dy) <= (grabRadius * grabRadius)
            if self.DislocationAiming then
                self.DislocationAimStartX = mx
                self.DislocationAimStartY = my
                self.DislocationAimX = mx
                self.DislocationAimY = my
                self.DislocationAimStartTime = SysTime()
                self.DislocationVelX = 0
                self.DislocationVelY = 0
                self.DislocationAppliedForce = 0
            end
            return
        end

        if self.GameType == "amputation" then
            self.AmputationLastMouseX = mx
            return
        end

        if self.GameType == "syringe" then
            local layout = self:GetSyringeLayout()
            self.SyringeGrabbed = self:IsNearSyringePlunger(mx, my, layout)
            if self.SyringeGrabbed then
                self.SyringeGrabOffsetY = my - layout.handleY
            else
                self.SyringeGrabOffsetY = 0
            end
            return
        end

        local ang = math.deg(math.atan2(my - self.CenterY, mx - self.CenterX))
        self.TargetAngleObj.y = ang
        
        if not self.Started then
            self.CurrentAngleObj.y = ang
            self.Started = true
        end
    elseif code == MOUSE_RIGHT then
        self:Remove()
    end
end

function PANEL:OnMouseReleased(code)
    if code == MOUSE_LEFT then
        local shouldFinishSyringe = self.GameType == "syringe" and self.Progress > 0
        if self.GameType == "dislocation" and self.DislocationAiming then
            local mx, my = self:CursorPos()
            local startX = self.DislocationAimStartX or mx
            local startY = self.DislocationAimStartY or my
            local aimX = (self.DislocationAimX or mx) - startX
            local aimY = (self.DislocationAimY or my) - startY
            local len = math.sqrt((aimX * aimX) + (aimY * aimY))
            local maxLen = self.DislocationAimMaxLen or 150
            local clampedLen = math.min(len, maxLen)

            if clampedLen > 0.001 then
                local dirX = aimX / len
                local dirY = aimY / len
                local impulse = math.Clamp(clampedLen * (self.DislocationImpulseScale or 4.0), 0, self.DislocationImpulseCap or 780)
                self.DislocationVelX = (self.DislocationVelX or 0) + dirX * impulse
                self.DislocationVelY = (self.DislocationVelY or 0) + dirY * impulse
                self.DislocationAppliedForce = math.Clamp(clampedLen / maxLen, 0, 1.6)

                net.Start("hg_medical_minigame_progress")
                net.WriteFloat(0)
                net.WriteFloat(math.Clamp(math.abs(self.DislocationAppliedForce or 0), 0, 1.6))
                net.SendToServer()
            else
                self.DislocationAppliedForce = 0
            end

            self.DislocationAiming = false
            self.DislocationAimStartX = nil
            self.DislocationAimStartY = nil
            self.DislocationAimX = nil
            self.DislocationAimY = nil
            self.DislocationAimStartTime = nil
        end
        self.Dragging = false
        self.LastAngle = nil
        self.HandSqueezeStartTime = nil
        self.TourniquetStrapGrabbed = false
        self.TourniquetLastTubeAngle = nil
        self.SyringeGrabbed = false
        self.SyringeGrabOffsetY = 0

        if shouldFinishSyringe then
            self:Finish()
        end
    end
end

function PANEL:GetRemainingBandage()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 0 end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return 0 end

    local modeValues = wep.GetNetVar and wep:GetNetVar("modeValues", wep.modeValues or {}) or wep.modeValues or {}
    if self.GameType == "tourniquet" then
        if wep:GetClass() == "weapon_medkit_sh" then
            return tonumber(modeValues[4]) or 0
        end

        return tonumber(modeValues[1]) or 0
    end

    if self.GameType == "syringe" then
        if wep:GetClass() == "weapon_medkit_sh" then
            return tonumber(modeValues[3]) or 0
        end

        return tonumber(modeValues[1]) or 0
    end

    return tonumber(modeValues[1]) or 0
end

function PANEL:GetDisplayProgress()
    if self.GameType == "tourniquet" then
        local tubeProgress = math.Clamp(self.TourniquetTubeAccumulatedAngle / (2 * math.pi * self.TourniquetTubeRequiredTurns), 0, 1)
        if self.TourniquetStage <= 1 then
            return self.TourniquetStrapProgress
        end

        return tubeProgress
    end

    return self.Progress
end

function PANEL:GetSyringeAmounts()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 0, 1 end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return 0, 1 end

    local modeValueIndex = (wep:GetClass() == "weapon_medkit_sh") and 3 or 1
    local modeValues = wep.GetNetVar and wep:GetNetVar("modeValues", wep.modeValues or {}) or wep.modeValues or {}
    local currentAmount = math.max(tonumber(modeValues[modeValueIndex]) or 0, 0)
    local configuredValue = wep.modeValuesdef and wep.modeValuesdef[modeValueIndex]
    local totalAmount = math.max(tonumber(istable(configuredValue) and configuredValue[1] or configuredValue) or currentAmount or 1, 0.0001)

    return currentAmount, totalAmount
end

function PANEL:GetSyringeDisplayUsedFraction()
    local startRemainingFraction = math.Clamp(self.SyringeStartRemainingFraction or 1, 0, 1)
    local startUsedFraction = math.Clamp(self.SyringeStartUsedFraction or 0, 0, 1)
    return math.Clamp(startUsedFraction + (self.Progress * startRemainingFraction), 0, 1)
end

function PANEL:BeginTourniquetTubeStage()
    self.TourniquetStage = 2
    self.TourniquetStrapGrabbed = false
    self.TourniquetLastTubeAngle = nil
    self.TourniquetTubeAccumulatedAngle = 0
    self.TourniquetTubeRotation = 0
    self.TourniquetStageSwitchUntil = CurTime() + 0.25
end

function PANEL:ResetWrapProgress()
    self.Progress = 0
    self.AccumulatedAngle = 0
    self.WrapAngle = 0
    self.LastProgressSent = 0
    self.LastAngle = nil
    self.TrailPoints = {}
end

function PANEL:CommitVisualWrap()
    self.CompletedWraps = self.CompletedWraps + 1
    self.WrapAngle = math.max(self.WrapAngle - (2 * math.pi), 0)
end

function PANEL:CompleteWrap()
    if self.Progress > self.LastProgressSent then
        net.Start("hg_medical_minigame_progress")
        net.WriteFloat(self.Progress - self.LastProgressSent)
        net.SendToServer()
    end

    -- Increment completions for threshold-based healing
    self.BandageCompletions = (self.BandageCompletions or 0) + 1

    -- Check if required completions reached
    if self.BandageCompletions >= (self.BandageRequiredCompletions or 3) then
        self:Finish()
        return
    end

    self:CommitVisualWrap()

    self:ResetWrapProgress()
end

function PANEL:ThinkTourniquet(mx, my)
    local limbRadius = 92
    local strapAnchorX = self.CenterX + limbRadius - 4
    local strapAnchorY = self.CenterY - limbRadius + 2
    local strapStartX = strapAnchorX + 18
    local strapEndX = self.CenterX + 320
    local strapY = strapAnchorY
    local knobX = self.CenterX
    local knobY = self.CenterY + 10

    if self.TourniquetStage == 1 then
        local nearStrap = math.abs(my - strapY) <= 80
        local normalized = math.Clamp((mx - strapStartX) / (strapEndX - strapStartX), 0, 1)

        if not self.TourniquetStrapGrabbed and nearStrap and normalized <= 0.18 then
            self.TourniquetStrapGrabbed = true
        end

        if self.TourniquetStrapGrabbed and nearStrap then
            self.TourniquetStrapProgress = math.max(self.TourniquetStrapProgress, normalized)
        end

        if self.TourniquetStrapProgress >= 1 then
            self:BeginTourniquetTubeStage()
        end
    elseif self.TourniquetStage == 2 then
        if self.TourniquetStageSwitchUntil > CurTime() then
            self.TourniquetLastTubeAngle = nil
            return
        end

        local distToKnob = math.Distance(mx, my, knobX, knobY)
        if distToKnob <= 155 then
            local angle = math.atan2(my - knobY, mx - knobX)

            if self.TourniquetLastTubeAngle then
                local diff = NormalizeAngleDiff(angle - self.TourniquetLastTubeAngle)
                local prevAccumulated = self.TourniquetTubeAccumulatedAngle
                self.TourniquetTubeAccumulatedAngle = self.TourniquetTubeAccumulatedAngle + math.abs(diff)
                self.TourniquetTubeRotation = self.TourniquetTubeRotation + math.deg(diff)

                -- Track quarter-turns for pain
                local quarterTurns = math.floor(self.TourniquetTubeAccumulatedAngle / (math.pi / 2))
                if quarterTurns > (self.TourniquetTurnCount or 0) then
                    self.TourniquetTurnCount = quarterTurns
                    -- Send pain to server - increases with each turn
                    local painAmount = (2 + (quarterTurns * 1.5)) * 0.1 -- Base 2 pain, +1.5 per quarter-turn, multiplied by 0.1 (reduced by 3x)
                    net.Start("hg_medical_minigame_tourniquet_pain")
                    net.WriteFloat(painAmount)
                    net.SendToServer()
                end

                if self.TourniquetTubeAccumulatedAngle >= (2 * math.pi * self.TourniquetTubeRequiredTurns) then
                    self:Finish()
                    return
                end
            end

            self.TourniquetLastTubeAngle = angle
        else
            self.TourniquetLastTubeAngle = nil
        end
    end
end

function PANEL:GetSyringeLayout()
    local sourceWidth = 700
    local sourceHeight = 1300
    local baseSpriteHeight = 940
    local plungerSpriteHeight = 940
    local baseSpriteWidth = math.floor(baseSpriteHeight * (sourceWidth / sourceHeight))
    local plungerSpriteWidth = math.floor(plungerSpriteHeight * (sourceWidth / sourceHeight))
    local barrelCenterX = 342
    local barrelCenterY = 581
    local plungerCenterX = barrelCenterX
    local handleSourceY = 210
    local plungerTravelSource = 130
    local barrelScreenCenterX = self.CenterX + 0
    local baseCenterX = barrelScreenCenterX - 8.5
    local baseCenterY = self.CenterY + 135
    local plungerCenterY = self.CenterY + 20
    local baseX = baseCenterX - (baseSpriteWidth * (barrelCenterX / sourceWidth))
    local baseY = baseCenterY - (baseSpriteHeight * (barrelCenterY / sourceHeight))
    local plungerBaseY = plungerCenterY - (plungerSpriteHeight * (barrelCenterY / sourceHeight)) - 220
    local fullPlungerTravel = plungerSpriteHeight * (plungerTravelSource / sourceHeight)
    local startUsedFraction = math.Clamp(self.SyringeStartUsedFraction or 0, 0, 1)
    local startRemainingFraction = math.Clamp(self.SyringeStartRemainingFraction or 1, 0, 1)
    local displayUsedFraction = self:GetSyringeDisplayUsedFraction()
    local plungerY = plungerBaseY + (displayUsedFraction * fullPlungerTravel)

    return {
        baseX = baseX,
        baseY = baseY,
        baseWidth = baseSpriteWidth,
        baseHeight = baseSpriteHeight,
        plungerX = barrelScreenCenterX - (plungerSpriteWidth * (plungerCenterX / sourceWidth)),
        plungerY = plungerY,
        plungerWidth = plungerSpriteWidth,
        plungerHeight = plungerSpriteHeight,
        plungerTravel = fullPlungerTravel,
        sessionTravel = math.max(fullPlungerTravel * startRemainingFraction, 1),
        handleX = barrelScreenCenterX,
        handleY = plungerY + (plungerSpriteHeight * (handleSourceY / sourceHeight)),
        handleBaseY = plungerBaseY + (startUsedFraction * fullPlungerTravel) + (plungerSpriteHeight * (handleSourceY / sourceHeight)),
        handleRadius = plungerSpriteWidth * 0.18,
        sourceWidth = sourceWidth,
        sourceHeight = sourceHeight
    }
end

function PANEL:IsNearSyringePlunger(mx, my, layout)
    layout = layout or self:GetSyringeLayout()
    return math.Distance(mx, my, layout.handleX, layout.handleY) <= layout.handleRadius
end

function PANEL:ThinkSyringe(mx, my)
    local layout = self:GetSyringeLayout()
    if not self.SyringeGrabbed then
        return
    end

    local handleTargetY = my - (self.SyringeGrabOffsetY or 0)
    local normalized = math.Clamp((handleTargetY - layout.handleBaseY) / layout.sessionTravel, 0, 1)
    local newProgress = math.max(self.Progress, normalized)
    if newProgress <= self.Progress then return end

    self.Progress = newProgress

    if self.Progress - self.LastProgressSent >= 0.02 then
        net.Start("hg_medical_minigame_progress")
        net.WriteFloat(self.Progress - self.LastProgressSent)
        net.SendToServer()
        self.LastProgressSent = self.Progress
    end

    if self.Progress >= 1 then
        self:Finish()
    end
end

function PANEL:ThinkAmputation(mx, my)
    local sawRange = self.AmputationSawRange or 175
    local clampedX = math.Clamp(mx, self.CenterX - sawRange, self.CenterX + sawRange)
    local targetOffsetX = clampedX - self.CenterX
    local sideTilt = (targetOffsetX / sawRange) * 34
    local moveX = (mx - (self.AmputationLastMouseX or mx))
    self.AmputationSmoothedMoveX = Lerp(FrameTime() * 7, self.AmputationSmoothedMoveX or moveX, moveX)
    local smoothMoveX = self.AmputationSmoothedMoveX or moveX
    local movementSwayX = math.Clamp(smoothMoveX * 1.15, -14, 14)
    local movementSwayAngle = math.Clamp(smoothMoveX * 0.11, -1.8, 1.8)
    local targetAngle = sideTilt + movementSwayAngle

    self.AmputationKnifeSwayX = Lerp(FrameTime() * 2.1, self.AmputationKnifeSwayX or movementSwayX, movementSwayX)
    self.AmputationKnifeOffsetX = Lerp(FrameTime() * 1.0, self.AmputationKnifeOffsetX or targetOffsetX, targetOffsetX)
    self.AmputationKnifeAngle = Lerp(FrameTime() * 1.35, self.AmputationKnifeAngle or targetAngle, targetAngle)
    local visualProgressTarget = math.max(self.Progress, self.AmputationVisualProgress or self.Progress)
    self.AmputationVisualProgress = Lerp(FrameTime() * 0.95, self.AmputationVisualProgress or visualProgressTarget, visualProgressTarget)
    SetAmputationVisualState(self.AmputationTarget, self.AmputationLimb, {
        offsetX = self.AmputationKnifeOffsetX or 0,
        angle = self.AmputationKnifeAngle or 0,
        swayX = self.AmputationKnifeSwayX or 0,
        visualProgress = self.AmputationVisualProgress or self.Progress
    })

    if not self.Dragging or not input.IsMouseDown(MOUSE_LEFT) then
        self.AmputationLastMouseX = mx
        return
    end

    if math.abs(my - (self.AmputationCutY or self.CenterY)) > (self.AmputationZoneHalfHeight or 115) then
        self.AmputationLastMouseX = mx
        return
    end

    local moveDistance = math.abs(moveX)
    local swipeSpeed = moveDistance / math.max(FrameTime(), 0.001)
    local cappedSwipeSpeed = math.min(swipeSpeed, self.AmputationFillSpeedCap or 520)
    local effectiveMoveDistance = cappedSwipeSpeed * FrameTime()
    local delta = math.min(effectiveMoveDistance / math.max(self.AmputationRequiredTravel or 5600, 1), 1 - self.Progress)

    if delta > 0 then
        self.Progress = math.min(self.Progress + delta, 1)
        self.AmputationMaxSwipeSpeed = math.max(self.AmputationMaxSwipeSpeed or 0, swipeSpeed)

        if self.Progress - self.LastProgressSent >= 0.01 then
            net.Start("hg_medical_minigame_progress")
            net.WriteFloat(self.Progress - self.LastProgressSent)
            net.WriteFloat(self.AmputationMaxSwipeSpeed or swipeSpeed)
            net.SendToServer()

            self.LastProgressSent = self.Progress
            self.AmputationMaxSwipeSpeed = 0
            surface.PlaySound("physics/flesh/flesh_squishy_impact_hard2.wav")
        end
    end

    if self.Progress >= 1 then
        self:Finish()
    end

    self.AmputationLastMouseX = mx
end

function PANEL:GetDislocationLabel()
    return dislocationLimbLabels[self.DislocationLimb] or "JOINT"
end

function PANEL:ThinkDislocation(mx, my)
    local dt = FrameTime()
    local now = SysTime()
    local aiming = self.DislocationAiming == true and self.Dragging and input.IsMouseDown(MOUSE_LEFT)
    if aiming then
        self.DislocationAimX = mx
        self.DislocationAimY = my
        local startX = self.DislocationAimStartX or mx
        local startY = self.DislocationAimStartY or my
        local aimX = mx - startX
        local aimY = my - startY
        local len = math.sqrt((aimX * aimX) + (aimY * aimY))
        local maxLen = self.DislocationAimMaxLen or 150
        self.DislocationAppliedForce = math.Clamp(len / maxLen, 0, 1.6)
        self.DislocationVelX = 0
        self.DislocationVelY = 0

        -- Apply pain when attempting relocation
        if not self.DislocationLastPainTime or now - self.DislocationLastPainTime > 0.5 then
            local painAmount = 3 + (self.DislocationAppliedForce * 5) -- Base 3 pain, +5 based on force
            net.Start("hg_medical_minigame_dislocation_pain")
            net.WriteFloat(painAmount)
            net.SendToServer()
            self.DislocationLastPainTime = now

            -- Play body hitting sound
            if LocalPlayer() then
                LocalPlayer():EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1, 6) .. ".wav", 55, math.random(90, 110))
            end
        end
    else
        local drag = math.exp(-dt * (self.DislocationDrag or 2.6))
        self.DislocationVelX = (self.DislocationVelX or 0) * drag
        self.DislocationVelY = (self.DislocationVelY or 0) * drag

        local maxSpeed = self.DislocationMaxSpeed or 820
        local speed = math.sqrt((self.DislocationVelX or 0) ^ 2 + (self.DislocationVelY or 0) ^ 2)
        if speed > maxSpeed and speed > 0.001 then
            local scale = maxSpeed / speed
            self.DislocationVelX = (self.DislocationVelX or 0) * scale
            self.DislocationVelY = (self.DislocationVelY or 0) * scale
        end

        self.DislocationMoveX = (self.DislocationMoveX or 0) + (self.DislocationVelX or 0) * dt
        self.DislocationMoveY = (self.DislocationMoveY or 0) + (self.DislocationVelY or 0) * dt

        local startX = self.DislocationMoveStartX or self.DislocationMoveX or 0
        local startY = self.DislocationMoveStartY or self.DislocationMoveY or 0
        local dx = (self.DislocationMoveX or 0) - startX
        local dy = (self.DislocationMoveY or 0) - startY
        local dist = math.sqrt((dx * dx) + (dy * dy))
        local maxTravel = self.DislocationMaxTravel or 330
        if dist > maxTravel and dist > 0.001 then
            local scale = maxTravel / dist
            self.DislocationMoveX = startX + dx * scale
            self.DislocationMoveY = startY + dy * scale
            self.DislocationVelX = (self.DislocationVelX or 0) * 0.35
            self.DislocationVelY = (self.DislocationVelY or 0) * 0.35
        end

        local speed2 = math.sqrt((self.DislocationVelX or 0) ^ 2 + (self.DislocationVelY or 0) ^ 2)
        self.DislocationAppliedForce = math.Clamp(speed2 / 900, 0, 1.6)
    end

    local fixedX = self.DislocationFixedBoneX or self.CenterX
    local fixedY = self.DislocationFixedBoneY or self.CenterY
    local fixedW = self.DislocationFixedBoneWidth or 230
    local fixedH = self.DislocationFixedBoneHeight or 90
    local fixedSign = (self.DislocationSide or 1) >= 0 and 1 or -1
    local fixedEndOffset = (fixedW * 0.5) - (fixedH * 0.3)
    local fixedEndX = fixedX + fixedEndOffset * fixedSign
    local fixedEndY = fixedY

    local moveX = self.DislocationMoveX or self.CenterX
    local moveY = self.DislocationMoveY or self.CenterY
    local moveW = self.DislocationMoveBoneWidth or 220
    local moveH = self.DislocationMoveBoneHeight or 84
    local moveAng = self.DislocationMoveAngle or (-18 * fixedSign)
    local moveEndOffset = (moveW * 0.5) - (moveH * 0.3)
    local moveContactSign = -fixedSign
    local moveRad = math.rad(moveAng)
    local moveCos, moveSin = math.cos(moveRad), math.sin(moveRad)
    local moveEndX = moveX + (moveEndOffset * moveContactSign) * moveCos
    local moveEndY = moveY + (moveEndOffset * moveContactSign) * moveSin

    local diffX = moveEndX - fixedEndX
    local diffY = moveEndY - fixedEndY
    local distanceToSocket = math.sqrt((diffX * diffX) + (diffY * diffY))
    local speed = math.sqrt((self.DislocationVelX or 0) ^ 2 + (self.DislocationVelY or 0) ^ 2)
    local withinSnap = distanceToSocket <= (self.DislocationSnapWindow or 30)
    local stableForce = math.abs(self.DislocationAppliedForce or 0) <= 1.45

    if withinSnap and stableForce then
        local distanceFactor = 1 - math.Clamp(distanceToSocket / math.max(self.DislocationSnapWindow or 24, 1), 0, 1)
        local speedFactor = 1 - math.Clamp(speed / math.max(self.DislocationStableSpeed or 120, 1), 0, 1)
        local gain = math.max(distanceFactor * speedFactor, 0) * dt * 0.9
        local newProgress = math.min(self.Progress + gain, 1)

        if newProgress > self.Progress then
            self.Progress = newProgress
            if self.Progress - self.LastProgressSent >= 0.01 then
                net.Start("hg_medical_minigame_progress")
                net.WriteFloat(self.Progress - self.LastProgressSent)
                net.WriteFloat(math.Clamp(math.abs(self.DislocationAppliedForce or 0), 0, 1.6))
                net.SendToServer()
                self.LastProgressSent = self.Progress
            end
        end
    end

    if self.Progress >= 1 then
        self:Finish()
    end
end

function PANEL:GetSyringeFluidColor()
    local ply = LocalPlayer()
    if not IsValid(ply) then return Color(160, 70, 180, 175) end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return Color(160, 70, 180, 175) end

    local class = wep:GetClass()
    if class == "weapon_fentanyl" then
        return Color(175, 55, 55, 180)
    end

    if class == "weapon_medkit_sh" and wep.mode == 3 then
        return Color(90, 175, 120, 180)
    end

    return Color(160, 70, 180, 175)
end

function PANEL:Think()
    local mx, my = self:CursorPos()
    if self.GameType == "bandage" then
        local currentBandageRad = math.rad(self.CurrentAngleObj.y)
        local bandageX = self.CenterX + math.cos(currentBandageRad) * self.Radius
        local bandageY = self.CenterY + math.sin(currentBandageRad) * self.Radius
        local distFromBandage = math.Distance(mx, my, bandageX, bandageY)
        self.CursorTooFar = distFromBandage > self.MaxBandageDistance
    else
        self.CursorTooFar = false
    end
    
    -- Smoothly follow the cursor with the hand
    local lerpSpeed = FrameTime() * 10
    self.HandX = Lerp(lerpSpeed, self.HandX, mx)
    self.HandY = Lerp(lerpSpeed, self.HandY, my)

    -- Calculate hand tilt based on movement
    local dx = mx - self.LastMX
    local targetTilt = math.Clamp(dx * 2, -15, 15) -- Tilt up to 15 degrees
    self.HandAngle = Lerp(FrameTime() * 5, self.HandAngle, targetTilt)
    
    self.LastMX, self.LastMY = mx, my

    if self.GameType == "dislocation" then
        self:ThinkDislocation(mx, my)
    elseif self.GameType == "amputation" then
        self:ThinkAmputation(mx, my)
    elseif self.Dragging and input.IsMouseDown(MOUSE_LEFT) then
        if self.GameType == "tourniquet" then
            self:ThinkTourniquet(mx, my)
        elseif self.GameType == "syringe" then
            self:ThinkSyringe(mx, my)
        elseif self.CursorTooFar then
            self.LastAngle = nil
        else
            local ang = math.deg(math.atan2(my - self.CenterY, mx - self.CenterX))
            local targetRad = math.rad(ang)
            local currentTargetRad = math.rad(self.TargetAngleObj.y)
            local aimDiff = NormalizeAngleDiff(targetRad - currentTargetRad)

            if aimDiff <= 0 then
                self.TargetAngleObj.y = ang
            end

            local bandageLerpSpeed = FrameTime() * self.BandageFollowSpeed
            self.CurrentAngleObj = LerpAngle(bandageLerpSpeed, self.CurrentAngleObj, self.TargetAngleObj)
            
            local currentRad = math.rad(self.CurrentAngleObj.y)
            
            if self.LastAngle then
                local diff = NormalizeAngleDiff(currentRad - self.LastAngle)

                -- Only count wrapping progress when rotating to the left.
                local leftDiff = math.max(-diff, 0) * self.WrapSpeedMultiplier

                self.AccumulatedAngle = self.AccumulatedAngle + leftDiff
                self.WrapAngle = self.WrapAngle + leftDiff
                
                if leftDiff > 0.001 then
                    AppendBandageTrail(
                        self.TrailPoints,
                        self.LastAngle,
                        currentRad,
                        math.rad(1.5)
                    )
                end

                while self.WrapAngle >= (2 * math.pi) do
                    self:CommitVisualWrap()
                end

                self.Progress = math.min(self.AccumulatedAngle / (2 * math.pi * self.TargetTurns), 1)
                
                if self.Progress - self.LastProgressSent >= 0.05 then
                    net.Start("hg_medical_minigame_progress")
                    net.WriteFloat(self.Progress - self.LastProgressSent)
                    net.SendToServer()
                    self.LastProgressSent = self.Progress
                end
                
                if self.Progress >= 1 then
                    self:CompleteWrap()
                end
            end
            
            self.LastAngle = currentRad
        end
    else
        self.Dragging = false
        self.LastAngle = nil
        self.HandSqueezeStartTime = nil
    end

    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() or IsLocalPlayerUnconscious() then
        if not IsValid(lp) or not lp:Alive() then
            ClearAllAmputationVisualState()
        end

        self:Remove()
        return
    end
    if self.GameType ~= "amputation" and self.GameType ~= "dislocation" and self:GetRemainingBandage() <= 0 then
        self:Finish()
        return
    end
end

function PANEL:Finish()
    if self.Finished then return end
    self.Finished = true
    self:StopMusic()
    
    if (self.GameType == "bandage" or self.GameType == "syringe" or self.GameType == "amputation" or self.GameType == "dislocation") and self.Progress > self.LastProgressSent then
        net.Start("hg_medical_minigame_progress")
        net.WriteFloat(self.Progress - self.LastProgressSent)
        if self.GameType == "amputation" then
            net.WriteFloat(0)
        elseif self.GameType == "dislocation" then
            net.WriteFloat(math.abs(self.DislocationAppliedForce or 0))
        end
        net.SendToServer()
    end

    net.Start("hg_medical_minigame_finish")
    net.WriteString(self.GameType or "")
    net.WriteFloat(math.Clamp(self.Progress or 0, 0, 1))
    net.SendToServer()

    if self.GameType == "amputation" then
        ClearAmputationVisualState(self.AmputationTarget, self.AmputationLimb)
    end
    
    if self.GameType == "syringe" then
        surface.PlaySound("snd_jack_hmcd_needleprick.wav")
    elseif self.GameType == "dislocation" then
        surface.PlaySound("physics/flesh/flesh_impact_hard6.wav")
    elseif self.GameType == "amputation" then
        surface.PlaySound("physics/body/body_medium_break3.wav")
    else
        surface.PlaySound("snd_jack_hmcd_bandage.wav")
    end
    
    self:AlphaTo(0, 0.2, 0, function()
        self:Remove()
    end)
end

function PANEL:OnRemove()
    self:StopMusic()

    if not self.Finished and self.GameType == "amputation" and self.Progress > self.LastProgressSent then
        net.Start("hg_medical_minigame_progress")
        net.WriteFloat(self.Progress - self.LastProgressSent)
        net.WriteFloat(self.AmputationMaxSwipeSpeed or 0)
        net.SendToServer()
    end

    if not self.Finished and self.GameType == "dislocation" and self.Progress > self.LastProgressSent then
        net.Start("hg_medical_minigame_progress")
        net.WriteFloat(self.Progress - self.LastProgressSent)
        net.WriteFloat(math.abs(self.DislocationAppliedForce or 0))
        net.SendToServer()
    end

    if hg and hg.MedicalMinigame and hg.MedicalMinigame.Panel == self then
        hg.MedicalMinigame.Panel = nil
    end

    gui.EnableScreenClicker(false)
end

function PANEL:DrawCommonOverlays(progress, showBleedIndicator)
    local lp = LocalPlayer()
    local shakeX, shakeY = 0, 0
    if showBleedIndicator == nil then
        showBleedIndicator = true
    end

    if IsValid(lp) then
        local pain = lp:GetNWFloat("pain", 0)
        if lp.organism and lp.organism.pain then pain = lp.organism.pain end
        if pain > 10 then
            local intensity = math.min(pain / 20, 15)
            local t = CurTime()
            shakeX = math.sin(t * 9.5) * intensity
            shakeY = math.cos(t * 12.0) * intensity * 0.7
        end
    end

    if showBleedIndicator and IsValid(lp) then
        local bleed = 0
        if lp.organism and lp.organism.bleed then
            bleed = lp.organism.bleed
        else
            bleed = lp:GetNWFloat("bleed", 0)
        end

        local woundSeverity = 0
        local wounds = lp.GetNetVar and lp:GetNetVar("wounds", nil)
        if istable(wounds) then
            for _, wound in ipairs(wounds) do
                if istable(wound) then
                    woundSeverity = woundSeverity + math.max(tonumber(wound[1]) or 0, 0)
                end
            end
        end

        local arterialSeverity = 0
        local arterialWounds = lp.GetNetVar and lp:GetNetVar("arterialwounds", nil)
        if istable(arterialWounds) then
            arterialSeverity = #arterialWounds * 12
        end

        local bleedVisualStrength = math.max(bleed, woundSeverity * 0.18, arterialSeverity)
        local targetIndicatorSize = math.Clamp(48 + (bleedVisualStrength * 20), 62, 165)
        self.BleedIndicatorSize = Lerp(FrameTime() * 8, self.BleedIndicatorSize or targetIndicatorSize, targetIndicatorSize)
        local indicatorSize = self.BleedIndicatorSize
        if bleed > 0.01 then
            local frameSpeed = math.Clamp(0.18 - (bleed * 0.01), 0.06, 0.18)
            local frameIndex = (math.floor(CurTime() / frameSpeed) % math.max(bleedFrameCount, 1)) + 1
            local frameMat = bleedFrames[frameIndex] or bleedFrames[1]
            local glowRadius = (indicatorSize + 24) * 0.5

            draw.NoTexture()
            local glowPoly = {}
            for i = 0, 32 do
                local a = math.rad((i / 32) * 360)
                glowPoly[#glowPoly + 1] = {
                    x = self.CenterX + math.cos(a) * glowRadius,
                    y = self.CenterY + math.sin(a) * glowRadius
                }
            end

            if SetHudMaterial(frameMat) then
                surface.SetDrawColor(255, 255, 255, 35)
                surface.DrawPoly(glowPoly)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(self.CenterX - indicatorSize / 2, self.CenterY - indicatorSize / 2, indicatorSize, indicatorSize)
            else
                surface.SetDrawColor(120, 0, 0, 80)
                surface.DrawPoly(glowPoly)
                surface.SetDrawColor(170, 20, 20, 220)
                draw.NoTexture()
                local bloodPoly = {}
                local dropRadius = indicatorSize * 0.32
                local topY = self.CenterY - indicatorSize * 0.16

                bloodPoly[#bloodPoly + 1] = {x = self.CenterX, y = topY - dropRadius * 1.2}
                for i = 0, 20 do
                    local a = math.rad((i / 20) * 360)
                    bloodPoly[#bloodPoly + 1] = {
                        x = self.CenterX + math.cos(a) * dropRadius,
                        y = topY + math.sin(a) * dropRadius
                    }
                end
                bloodPoly[#bloodPoly + 1] = {x = self.CenterX, y = self.CenterY + indicatorSize * 0.36}
                surface.DrawPoly(bloodPoly)
            end
        end
    end

    local progressSegments = 64
    local startAngle = -math.pi / 2
    local endAngle = startAngle + (progress * 2 * math.pi)
    
    if progress > 0 then
        local ringCol = (self.GameType == "bandage" and IsBruiceKitActive()) and Color(120, 255, 120) or Color(255, 255, 255)
        surface.SetDrawColor(ringCol.r, ringCol.g, ringCol.b, 40)
        for i = 0, progressSegments * progress do
            local a1 = startAngle + (i / progressSegments) * 2 * math.pi
            local a2 = startAngle + ((i + 1) / progressSegments) * 2 * math.pi
            if a2 > endAngle then a2 = endAngle end
            local r1 = self.Radius + 40
            local r2 = self.Radius + 45
            local p1x, p1y = self.CenterX + math.cos(a1) * r1, self.CenterY + math.sin(a1) * r1
            local p2x, p2y = self.CenterX + math.cos(a2) * r1, self.CenterY + math.sin(a2) * r1
            local p3x, p3y = self.CenterX + math.cos(a2) * r2, self.CenterY + math.sin(a2) * r2
            local p4x, p4y = self.CenterX + math.cos(a1) * r2, self.CenterY + math.sin(a1) * r2
            surface.DrawPoly({
                {x = p1x, y = p1y},
                {x = p2x, y = p2y},
                {x = p3x, y = p3y},
                {x = p4x, y = p4y}
            })
        end
    end

    if self.GameType ~= "syringe" then
        local handDrawX, handDrawY = GetHandDrawPosition(self.HandX + shakeX, self.HandY + shakeY, self.HandAngle)
        local currentHandMat = GetAnimatedHandMaterial(self)
        if SetHudMaterial(currentHandMat) then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRectRotated(handDrawX, handDrawY, 650, 500, self.HandAngle)
        else
            DrawFallbackHand(handDrawX, handDrawY, self.HandAngle)
        end
    end
end

function PANEL:PaintTourniquet(w, h)
    surface.SetDrawColor(0, 0, 0, 240)
    surface.DrawRect(0, 0, w, h)

    local stage = self.TourniquetStage
    local limbRadius = 92
    local strapAnchorX = self.CenterX + limbRadius - 2
    local strapAnchorY = self.CenterY - limbRadius + 18
    local strapStartX = strapAnchorX + 18
    local strapEndX = self.CenterX + 320
    local strapY = strapAnchorY
    local buckleX = self.CenterX + limbRadius - 34
    local knobX = self.CenterX
    local knobY = self.CenterY + 10
    local strapProgressX = Lerp(self.TourniquetStrapProgress, strapStartX, strapEndX)

    surface.SetDrawColor(40, 30, 25, 255)
    draw.NoTexture()
    local limbPoly = {}
    for i = 0, 64 do
        local a = math.rad((i / 64) * 360)
        limbPoly[#limbPoly + 1] = {
            x = self.CenterX + math.cos(a) * limbRadius,
            y = self.CenterY + math.sin(a) * limbRadius
        }
    end
    surface.DrawPoly(limbPoly)

    if stage == 1 then
        draw.NoTexture()
        surface.SetDrawColor(185, 35, 35, 255)
        surface.DrawPoly({
            {x = self.CenterX - limbRadius - 10, y = self.CenterY - 30},
            {x = self.CenterX + limbRadius - 10, y = self.CenterY - 30},
            {x = self.CenterX + limbRadius + 10, y = self.CenterY + 30},
            {x = self.CenterX - limbRadius + 10, y = self.CenterY + 30}
        })

        surface.SetDrawColor(190, 45, 45, 255)
        surface.DrawLine(self.CenterX + 6, self.CenterY - limbRadius - 4, strapAnchorX, strapAnchorY)
        surface.DrawLine(self.CenterX + 14, self.CenterY - limbRadius + 4, strapAnchorX, strapAnchorY)
        surface.DrawLine(self.CenterX + 22, self.CenterY - limbRadius + 12, strapAnchorX, strapAnchorY)

        draw.RoundedBox(6, strapAnchorX - 8, strapAnchorY - 8, 16, 16, Color(220, 55, 55, 255))
        surface.SetDrawColor(190, 70, 70, 95)
        surface.DrawLine(strapStartX, strapY, strapEndX, strapY)

        local strapWidth = math.max((strapProgressX - strapAnchorX) + 18, 28)
        draw.RoundedBox(4, strapAnchorX, strapY - 11, strapWidth, 22, Color(190, 40, 40, 255))
        draw.RoundedBox(4, strapProgressX - 11, strapY - 11, 22, 22, Color(235, 80, 80, 255))

        surface.SetDrawColor(255, 160, 160, 170)
        surface.DrawRect(strapStartX - 5, strapY - 5, 10, 10)
        surface.DrawRect(strapEndX - 5, strapY - 5, 10, 10)
    else
        draw.NoTexture()
        surface.SetDrawColor(245, 245, 245, 255)
        surface.DrawPoly({
            {x = self.CenterX - limbRadius - 8, y = self.CenterY - 26},
            {x = self.CenterX + limbRadius - 8, y = self.CenterY - 26},
            {x = self.CenterX + limbRadius + 8, y = self.CenterY + 26},
            {x = self.CenterX - limbRadius + 8, y = self.CenterY + 26}
        })

        draw.RoundedBox(5, buckleX - 10, strapY - 26, 20, 52, Color(150, 150, 150, 255))
        draw.RoundedBox(4, buckleX, strapY - 13, math.max((strapEndX - buckleX) + 18, 20), 26, Color(240, 240, 240, 255))

        draw.RoundedBox(8, knobX - 72, knobY - 72, 144, 144, Color(30, 30, 30, 245))
        draw.RoundedBox(6, knobX - 28, knobY - 28, 56, 56, Color(175, 175, 175, 255))
        DrawRotatedBar(knobX, knobY, 116, 18, self.TourniquetTubeRotation, Color(245, 245, 245, 255)) -- Single stick instead of cross

        if self.TourniquetStageSwitchUntil > CurTime() then
            local alpha = math.Clamp((self.TourniquetStageSwitchUntil - CurTime()) / 0.25, 0, 1) * 180
            surface.SetDrawColor(0, 0, 0, alpha)
            surface.DrawRect(0, 0, w, h)
        end
    end

    self:DrawCommonOverlays(self:GetDisplayProgress(), false)
end

function PANEL:PaintSyringe(w, h)
    surface.SetDrawColor(0, 0, 0, 240)
    surface.DrawRect(0, 0, w, h)

    local layout = self:GetSyringeLayout()
    local fluidColor = self:GetSyringeFluidColor()
    local fluidSourceLeft = 311
    local fluidSourceTop = 600
    local fluidSourceWidth = 72
    local fluidSourceHeight = 170
    local fluidX = layout.baseX + (layout.baseWidth * (fluidSourceLeft / layout.sourceWidth))
    local fluidWidth = layout.baseWidth * (fluidSourceWidth / layout.sourceWidth)
    local fluidTopY = layout.baseY + (layout.baseHeight * (fluidSourceTop / layout.sourceHeight))
    local fluidHeight = layout.baseHeight * (fluidSourceHeight / layout.sourceHeight)
    local fluidBottomY = fluidTopY + fluidHeight
    local barrelTopY = layout.baseY + (layout.baseHeight * (390 / layout.sourceHeight))
    local barrelBottomY = layout.baseY + (layout.baseHeight * (955 / layout.sourceHeight))
    self.FluidVisualProgress = self:GetSyringeDisplayUsedFraction()
    local remainingFluidHeight = math.max(fluidHeight * (1 - self.FluidVisualProgress), 0)
    local fluidY = fluidBottomY - remainingFluidHeight
    local plungerMat = GetAnimatedSyringePlungerMaterial(self)

    surface.SetDrawColor(fluidColor.r, fluidColor.g, fluidColor.b, 45)
    surface.DrawRect(fluidX - 6, fluidTopY - 6, fluidWidth + 12, fluidHeight + 12)

    surface.SetDrawColor(fluidColor.r, fluidColor.g, fluidColor.b, fluidColor.a or 180)
    if remainingFluidHeight > 0 then
        surface.DrawRect(fluidX, fluidY, fluidWidth, remainingFluidHeight)
    end

    if plungerMat and SetHudMaterial(plungerMat) then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(layout.plungerX, layout.plungerY, layout.plungerWidth, layout.plungerHeight)
    end

    if SetHudMaterial(syringeBaseMat) then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(layout.baseX, layout.baseY, layout.baseWidth, layout.baseHeight)
    else
        draw.RoundedBox(12, layout.baseX + layout.baseWidth * 0.42, layout.baseY + layout.baseHeight * 0.3, layout.baseWidth * 0.16, layout.baseHeight * 0.43, Color(25, 25, 25, 210))
        draw.RoundedBox(6, fluidX, fluidTopY, fluidWidth, fluidHeight, Color(55, 55, 55, 120))
        draw.RoundedBox(4, layout.baseX + layout.baseWidth * 0.455, layout.baseY + layout.baseHeight * 0.69, layout.baseWidth * 0.09, layout.baseHeight * 0.05, Color(30, 30, 30, 240))
    end

    self:DrawCommonOverlays(self.Progress, false)
end

function PANEL:PaintAmputation(w, h)
    surface.SetDrawColor(0, 0, 0, 240)
    surface.DrawRect(0, 0, w, h)

    local stumpRadius = 132
    local cutY = self.AmputationCutY or (self.CenterY + 28)
    local knifeX = self.CenterX + (self.AmputationKnifeOffsetX or 0) + (self.AmputationKnifeSwayX or 0)
    local knifeY = (self.AmputationKnifeBaseY or (cutY - 150)) + ((self.AmputationKnifeSink or 110) * (self.AmputationVisualProgress or self.Progress))

    DrawFilledCircle(self.CenterX, self.CenterY + 54, stumpRadius + 10, Color(245, 245, 245, 255), 64)
    DrawFilledCircle(self.CenterX, self.CenterY + 54, stumpRadius, Color(112, 72, 12, 255), 64)
    DrawFilledCircle(self.CenterX, self.CenterY + 54, stumpRadius * 0.25, Color(245, 245, 245, 255), 42)
    DrawFilledCircle(self.CenterX, self.CenterY + 54, stumpRadius * 0.09, Color(180, 180, 180, 255), 24)

    DrawAmputationBlade(knifeX, knifeY, 455, 150, self.AmputationKnifeAngle or -14)

    draw.SimpleText("The faster you move the knife, the stronger the pain.", "Trebuchet24", self.CenterX, self.CenterY + 255, Color(235, 235, 235, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintDislocation(w, h)
    surface.SetDrawColor(0, 0, 0, 240)
    surface.DrawRect(0, 0, w, h)

    local fixedX = self.DislocationFixedBoneX or (self.CenterX - 200)
    local fixedY = self.DislocationFixedBoneY or (self.CenterY + 120)
    local fixedW = self.DislocationFixedBoneWidth or 230
    local fixedH = self.DislocationFixedBoneHeight or 90
    local moveX = self.DislocationMoveX or (self.CenterX + 160)
    local moveY = self.DislocationMoveY or (self.CenterY - 80)
    local moveW = self.DislocationMoveBoneWidth or 220
    local moveH = self.DislocationMoveBoneHeight or 84
    local moveAng = self.DislocationMoveAngle or -18
    local fixedSign = (self.DislocationSide or 1) >= 0 and 1 or -1
    local fixedEndOffset = (fixedW * 0.5) - (fixedH * 0.3)
    local fixedEndX = fixedX + fixedEndOffset * fixedSign
    local fixedEndY = fixedY
    local moveEndOffset = (moveW * 0.5) - (moveH * 0.3)
    local moveContactSign = -fixedSign
    local moveRad = math.rad(moveAng)
    local moveCos, moveSin = math.cos(moveRad), math.sin(moveRad)
    local moveEndX = moveX + (moveEndOffset * moveContactSign) * moveCos
    local moveEndY = moveY + (moveEndOffset * moveContactSign) * moveSin
    local forceFill = math.Clamp(math.abs(self.DislocationAppliedForce or 0), 0, 1)
    local diffX = moveEndX - fixedEndX
    local diffY = moveEndY - fixedEndY
    local aligned = math.sqrt((diffX * diffX) + (diffY * diffY)) <= (self.DislocationSnapWindow or 30)

    DrawOutlinedBone(fixedX, fixedY, fixedW, fixedH, 0, Color(255, 255, 255, 255), Color(0, 0, 0, 255))
    DrawOutlinedBone(moveX, moveY, moveW, moveH, moveAng, Color(255, 255, 255, 255), Color(0, 0, 0, 255))

    DrawFilledCircle(fixedEndX, fixedEndY, 12, aligned and Color(205, 255, 205, 190) or Color(255, 255, 255, 120), 22)
    DrawFilledCircle(moveEndX, moveEndY, 10, aligned and Color(205, 255, 205, 190) or Color(255, 255, 255, 60), 22)

    if self.DislocationAiming then
        local startX = self.DislocationAimStartX or self.CenterX
        local startY = self.DislocationAimStartY or self.CenterY
        local aimX = (self.DislocationAimX or startX) - startX
        local aimY = (self.DislocationAimY or startY) - startY
        local len = math.sqrt((aimX * aimX) + (aimY * aimY))
        if len > 0.001 then
            local maxLen = 260
            local clamped = math.min(len, maxLen)
            local dirX = aimX / len
            local dirY = aimY / len
            local ax2 = moveX + dirX * clamped
            local ay2 = moveY + dirY * clamped
            surface.SetDrawColor(255, 255, 255, 170)
            surface.DrawLine(moveX, moveY, ax2, ay2)
        end
    end

    local meterWidth = 240
    local meterX = self.CenterX - meterWidth * 0.5
    local meterY = self.CenterY + 155
    draw.RoundedBox(6, meterX, meterY, meterWidth, 18, Color(50, 50, 50, 220))
    draw.RoundedBox(6, meterX + 3, meterY + 3, math.max((meterWidth - 6) * forceFill, 0), 12, Color(200, 200, 200, 245))

    draw.SimpleText("Push the dislocated bone back into the other bone.", "Trebuchet24", self.CenterX, self.CenterY - 170, Color(245, 245, 245, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(self:GetDislocationLabel(), "DermaLarge", self.CenterX, self.CenterY - 128, Color(255, 230, 180, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Hold the bone, pull the mouse, and release to shove it that way.", "Trebuchet18", self.CenterX, self.CenterY + 205, Color(220, 220, 220, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    self:DrawCommonOverlays(self.Progress, false)
end

function PANEL:Paint(w, h)
    if self.GameType == "tourniquet" then
        self:PaintTourniquet(w, h)
        return
    end

    if self.GameType == "syringe" then
        self:PaintSyringe(w, h)
        return
    end

    if self.GameType == "amputation" then
        self:PaintAmputation(w, h)
        return
    end

    if self.GameType == "dislocation" then
        self:PaintDislocation(w, h)
        return
    end

    surface.SetDrawColor(0, 0, 0, 240)
    surface.DrawRect(0, 0, w, h)
    
    -- Central part of the limb
    surface.SetDrawColor(40, 30, 25, 255)
    draw.NoTexture()
    local segments = 64
    local limbRadius = 80
    local poly = {}
    for i = 0, segments do
        local a = math.rad((i / segments) * 360)
        table.insert(poly, { x = self.CenterX + math.cos(a) * limbRadius, y = self.CenterY + math.sin(a) * limbRadius })
    end
    surface.DrawPoly(poly)
    
    -- The bandage no longer stacks in layers and instead thickens outward from the circle
    local baseWrapThickness = 8
    local wrapThicknessStep = self.VisualWrapThicknessStep or 1.5
    local currentWrapProgress = math.Clamp(self.WrapAngle / (2 * math.pi), 0, 1)
    local completedBandThickness = baseWrapThickness + (self.CompletedWraps * wrapThicknessStep)
    local activeBandThickness = baseWrapThickness + ((self.CompletedWraps + currentWrapProgress) * wrapThicknessStep)

    local wrapCol = IsBruiceKitActive() and Color(120, 255, 120) or Color(255, 255, 255)
    if self.CompletedWraps > 0 then
        DrawBandageRing(self, limbRadius, 215, completedBandThickness, wrapCol)
    end

    DrawBandageTrail(self, self.TrailPoints, limbRadius, 255, activeBandThickness, wrapCol)

    -- Coordinates of the current delayed bandage position
    local drawAngleRad = math.rad(self.CurrentAngleObj.y)
    local bx = self.CenterX + math.cos(drawAngleRad) * self.Radius
    local by = self.CenterY + math.sin(drawAngleRad) * self.Radius

    -- Draw the white bandage circle under the hand
    local circleRadius = 55 -- Increased from 35
    surface.SetDrawColor(wrapCol.r, wrapCol.g, wrapCol.b, 255)
    draw.NoTexture()
    local circlePoly = {}
    for i = 0, 32 do
        local a = math.rad((i / 32) * 360)
        table.insert(circlePoly, { x = bx + math.cos(a) * circleRadius, y = by + math.sin(a) * circleRadius })
    end
    surface.DrawPoly(circlePoly)

    -- Draw completion counter in center
    local completions = self.BandageCompletions or 0
    local required = self.BandageRequiredCompletions or 3
    local counterText = completions .. "/" .. required
    local counterColor = Color(255, 255, 255, 255)
    draw.DrawText(counterText, "HomigradFontLarge", self.CenterX, self.CenterY - 20, counterColor, TEXT_ALIGN_CENTER)

    self:DrawCommonOverlays(self.Progress, true)
end

vgui.Register("hg_medical_minigame", PANEL, "DFrame")

hook.Add("HG_OnOtrub", "hg_medical_minigame_close_on_otrub", function(ply)
    if ply ~= LocalPlayer() then return end
    if not hg or not hg.MedicalMinigame then return end

    local panel = hg.MedicalMinigame.Panel
    if IsValid(panel) then
        panel:Remove()
    end
end)

hook.Add("Think", "hg_medical_minigame_clear_amputation_on_death", function()
    local lp = LocalPlayer()
    if not IsValid(lp) or lp:Alive() then return end

    ClearAllAmputationVisualState()
end)

net.Receive("hg_medical_minigame_start", function()
    if IsValid(hg.MedicalMinigame.Panel) then return end
    if IsLocalPlayerUnconscious() then return end
    hg.MedicalMinigame.NextType = net.ReadString()
    hg.MedicalMinigame.NextTarget = nil
    hg.MedicalMinigame.NextLimb = nil
    hg.MedicalMinigame.NextDislocationSide = nil
    hg.MedicalMinigame.NextCompletions = nil
    hg.MedicalMinigame.NextRequiredCompletions = nil

    if hg.MedicalMinigame.NextType == "amputation" then
        hg.MedicalMinigame.NextTarget = net.ReadEntity()
        hg.MedicalMinigame.NextLimb = net.ReadString()
        hg.MedicalMinigame.NextProgress = net.ReadFloat()
    elseif hg.MedicalMinigame.NextType == "dislocation" then
        hg.MedicalMinigame.NextTarget = net.ReadEntity()
        hg.MedicalMinigame.NextLimb = net.ReadString()
        hg.MedicalMinigame.NextProgress = net.ReadFloat()
        hg.MedicalMinigame.NextDislocationSide = net.ReadInt(3)
    elseif hg.MedicalMinigame.NextType == "bandage" then
        hg.MedicalMinigame.NextTarget = net.ReadEntity()
        hg.MedicalMinigame.NextProgress = net.ReadFloat()
        hg.MedicalMinigame.NextCompletions = net.ReadInt(8)
        hg.MedicalMinigame.NextRequiredCompletions = net.ReadInt(8)
    end

    hg.MedicalMinigame.Panel = vgui.Create("hg_medical_minigame")
end)
