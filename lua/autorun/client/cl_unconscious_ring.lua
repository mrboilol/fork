local function DrawArc(x, y, radius, thickness, start_ang, end_ang, roughness, color)
    surface.SetDrawColor(color.r, color.g, color.b, color.a)
    draw.NoTexture()
    
    local segs = roughness
    local step = (end_ang - start_ang) / segs
    
    for i = 0, segs - 1 do
        local a1 = math.rad(start_ang + i * step)
        local a2 = math.rad(start_ang + (i + 1) * step)
        
        local cos1, sin1 = math.cos(a1), math.sin(a1)
        local cos2, sin2 = math.cos(a2), math.sin(a2)
        
        local p1 = { x = x + cos1 * (radius - thickness), y = y - sin1 * (radius - thickness) }
        local p2 = { x = x + cos1 * radius, y = y - sin1 * radius }
        local p3 = { x = x + cos2 * radius, y = y - sin2 * radius }
        local p4 = { x = x + cos2 * (radius - thickness), y = y - sin2 * (radius - thickness) }
        
        surface.DrawPoly({p1, p2, p3, p4})
    end
end

surface.CreateFont("UnconsciousDots", {
    font = "Bahnschrift",
    size = 120,
    weight = 800,
    antialias = true
})

surface.CreateFont("HomigradCriticalWarning", {
    font = "Bahnschrift",
    size = ScreenScaleH(14),
    weight = 800,
    antialias = true,
    shadow = true
})

surface.CreateFont("OtrubCriticalMessage", {
    font = "Veteran Typewriter",
    size = ScreenScaleH(16),
    weight = 800,
    antialias = true,
    shadow = true
})

local ringAlpha = 0
local lerpBrain = 0
local lerpShock = 0
local lerpConsciousness = 0
local peakShock = 40
local dotBeat = 0

local ecgAlphaPulseCheck = 0
local awakeECGAlpha = 0
local lastHeartBeat = 0
local heartPhase = 0

-- Better sound system from oldring
local SOUND_HEART = "health/critbeat.ogg"
local SOUND_FLATLINE = "health/gg.ogg"
local SOUND_FIBRILLATION = "criticalbeats.ogg"
local CRITBEAT_VOLUME_SCALE = 0.6

local lastPhaseMod = 0
local wasUnconsciousState = false
local flatlinePlayedThisUnconscious = false
local wasHeartbeatZero = false
local soundGen = 0
local heartStations = {}
local heartStationsLoading = false
local heartStationNext = 1
local flatlineStation = nil
local flatlineLoading = false

-- Track consciousness loss for sudden drop detection
local lastConsciousness = 1
local consciousnessDropTime = 0
local consciousnessDropAmount = 0

local nearDeathClasses = {
    ["furry"] = true,
    ["Gordon"] = true,
    ["Combine"] = true,
}

local hg_unconsciousring = CreateClientConVar("hg_unconsciousring", "1", true, false, "Enable unconscious ring", 0, 1)
local hg_unconsciousclassic = CreateClientConVar("hg_unconsciousclassic", "0", true, false, "Use classic dots instead of EKG line", 0, 1)

local function GetHeartbeatVolume(org)
    if not org then return 0.2 end
    local hurt = math.Clamp((5000 - (org.blood or 5000)) / 5000, 0, 1) * 0.4
         + math.Clamp((org.pain or 0) / 100, 0, 1) * 0.4
         + math.Clamp(org.brain or 0, 0, 1) * 0.2
    return math.Clamp(0.2 + hurt, 0.2, 1.0)
end

local function GetHeartbeatVolumeAdmiring(org, admiring)
    if not org then return 0.2 end
    if admiring then
        -- When admiring self, make heartbeats loud and clear with abnormal heart rate
        local abnormalPulse = (org.heartbeat < 40 and org.heartbeat >= 1) or org.heartbeat > 100
        if abnormalPulse then
            return 1.0 -- Maximum volume when admiring with abnormal heart rate
        end
    end
    -- Normal volume calculation
    local hurt = math.Clamp((5000 - (org.blood or 5000)) / 5000, 0, 1) * 0.4
         + math.Clamp((org.pain or 0) / 100, 0, 1) * 0.4
         + math.Clamp(org.brain or 0, 0, 1) * 0.2

    return math.Clamp(0.2 + hurt, 0.2, 1.0)
end

-- Phase crossing detection from oldring
local function PhaseCrossed(prev, curr, threshold)
    if prev <= curr then
        return prev < threshold and curr >= threshold
    end
    return prev < threshold or curr >= threshold
end

-- Audio reset function from oldring
local function ResetRingAudio()
    soundGen = soundGen + 1
    wasUnconsciousState = false
    flatlinePlayedThisUnconscious = false
    wasHeartbeatZero = false

    for i = 1, #heartStations do
        local st = heartStations[i]
        if IsValid(st) then
            st:Stop()
        end
    end

    heartStations = {}
    heartStationsLoading = false
    heartStationNext = 1

    if IsValid(flatlineStation) then
        flatlineStation:Stop()
    end
    flatlineStation = nil
    flatlineLoading = false
end

-- Ensure heart sound stations are loaded (pooling)
local function EnsureHeartStations()
    if heartStationsLoading or (#heartStations > 0) then return end
    heartStationsLoading = true

    local gen = soundGen
    local filePath = "sound/" .. SOUND_HEART

    for i = 1, 4 do
        sound.PlayFile(filePath, "noblock noplay", function(station)
            if gen ~= soundGen then
                if IsValid(station) then station:Stop() end
                return
            end
            if IsValid(station) then
                station:SetVolume(0)
                heartStations[i] = station
            end
            if i == 4 then
                heartStationsLoading = false
            end
        end)
    end
end

-- Ensure flatline sound station is loaded
local function EnsureFlatlineStation()
    if flatlineLoading or IsValid(flatlineStation) then return end
    flatlineLoading = true

    local gen = soundGen
    local filePath = "sound/" .. SOUND_FLATLINE

    sound.PlayFile(filePath, "noblock noplay", function(station)
        flatlineLoading = false
        if gen ~= soundGen then
            if IsValid(station) then station:Stop() end
            return
        end
        if IsValid(station) then
            station:SetVolume(0)
            flatlineStation = station
        end
    end)
end

-- Play a sound station with volume
local function PlayStation(station, volume)
    if not IsValid(station) then return end
    station:SetTime(0)
    station:SetVolume(math.Clamp(volume or 1, 0, 1))
    station:Play()
end

-- Emit ring sound with station pooling from oldring
local function EmitRingSound(soundPath, volume)
    if hg_unconsciousclassic and hg_unconsciousclassic:GetBool() then return end
    if soundPath == SOUND_HEART then
        EnsureHeartStations()

        local st = heartStations[heartStationNext]
        heartStationNext = (heartStationNext % 4) + 1

        if IsValid(st) then
            PlayStation(st, volume)
        else
            sound.PlayFile("sound/" .. soundPath, "noblock noplay", function(station)
                if IsValid(station) then
                    PlayStation(station, volume)
                end
            end)
        end
    elseif soundPath == SOUND_FLATLINE then
        EnsureFlatlineStation()

        if IsValid(flatlineStation) then
            PlayStation(flatlineStation, volume)
        else
            sound.PlayFile("sound/" .. soundPath, "noblock noplay", function(station)
                if IsValid(station) then
                    PlayStation(station, volume)
                end
            end)
        end
    else
        sound.PlayFile("sound/" .. soundPath, "noblock noplay", function(station)
            if IsValid(station) then
                PlayStation(station, volume)
            end
        end)
    end
end

-- Update ring audio with phase-based triggering from oldring
local function UpdateRingAudio(pulse, ringAlpha, org, admiring)
    if pulse < 1 or ringAlpha <= 0 then return end

    local prev = lastPhaseMod
    local curr = (lastPhaseMod + FrameTime() * (pulse / 60)) % 1
    lastPhaseMod = curr

    local beatVolume = GetHeartbeatVolumeAdmiring(org, admiring) * ringAlpha
    if PhaseCrossed(prev, curr, 0.239) then
        -- Use heartthump for abnormal heart rates or high stress, normal heartbeat otherwise
        local abnormalPulse = (pulse < 40 and pulse >= 1) or pulse > 100
        local highStress = false
        if org then
            local hurt = math.Clamp((5000 - (org.blood or 5000)) / 5000, 0, 1) * 0.4
                 + math.Clamp((org.pain or 0) / 100, 0, 1) * 0.4
                 + math.Clamp(org.brain or 0, 0, 1) * 0.2
            highStress = hurt > 0.3
        end

        -- When admiring with abnormal pulse, use full volume
        if admiring and abnormalPulse then
            beatVolume = 1.0
        end

        local fibrillating = pulse > 250
        if fibrillating then
            EmitRingSound(SOUND_FIBRILLATION, beatVolume)
        elseif abnormalPulse or highStress then
            EmitRingSound(SOUND_HEART, beatVolume * CRITBEAT_VOLUME_SCALE)
        else
            EmitRingSound("sound/heartbeat/heartbeat_single.wav", beatVolume)
        end
    end
end

local alertPlayed = false
local alertSound = nil

local g_PulseCheckTarget = nil
local g_PulseCheckData = nil

usermessage.Hook("hg_StartPulseCheckECG", function(msg)
    g_PulseCheckTarget = msg:ReadEntity()
    g_PulseCheckData = {
        started = CurTime(),
        nextBeat = CurTime(),
        counted = 0,
        completed = false,
        finalBPM = 0
    }
end)

-- Local variables for faster access
local math = math
local surface = surface
local draw = draw
local Color = Color

local centerEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
local pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }

local function DrawEKG(state, centerX, centerY, width, height, heartbeat, pulse, color, ringAlpha)
    local time = CurTime()
    if state.lastUpdate == 0 then state.lastUpdate = time end
    local dt = time - state.lastUpdate
    state.lastUpdate = time

    -- Increment heart phase based on heartbeat (BPM to beats per second)
    state.phase = state.phase + dt * (heartbeat / 60)

    local sweepSpeed = width / 4
    local oldSweepPos = state.sweepPos
    state.sweepPos = (state.sweepPos + dt * sweepSpeed) % width

    -- Calculate morph factor for high heartbeat & low pulse (looks like a sinewave)
    local hbFactor = math.Clamp((heartbeat - 90) / 60, 0, 1)
    local pulseFactor = math.Clamp((65 - pulse) / 35, 0, 1)
    local sineMorphFactor = hbFactor * pulseFactor

    -- Clean ECG waveform (P-QRS-T complex) from oldring
    local function getH(phase)
        phase = phase % 1
        local h = 0

        -- P wave: small bump
        if phase > 0.05 and phase < 0.15 then
            h = h + math.sin((phase - 0.05) / 0.1 * math.pi) * 0.12
        -- QRS complex: the main spike
        elseif phase > 0.2 and phase < 0.32 then
            local p = (phase - 0.2) / 0.12
            if p < 0.15 then -- Q
                h = h - math.sin(p / 0.15 * math.pi) * 0.15
            elseif p < 0.5 then -- R
                h = h + math.sin((p - 0.15) / 0.35 * math.pi) * 1.0
            else -- S
                h = h - math.sin((p - 0.5) / 0.5 * math.pi) * 0.25
            end
        -- T wave: medium bump
        elseif phase > 0.45 and phase < 0.65 then
            h = h + math.sin((phase - 0.45) / 0.2 * math.pi) * 0.22
        end

        if sineMorphFactor > 0 then
            local sineH = math.sin(phase * 2 * math.pi) * 0.35
            h = Lerp(sineMorphFactor, h, sineH)
        end

        return h
    end

    -- Fill all indices between oldSweepPos and newSweepPos to ensure no gaps
    local steps = math.max(1, math.floor(math.abs(state.sweepPos - oldSweepPos)))
    if state.sweepPos < oldSweepPos then steps = math.max(1, math.floor(width - oldSweepPos + state.sweepPos)) end

    for i = 0, steps do
        local p = (oldSweepPos + i) % width
        -- Interpolate heartPhase for this specific pixel
        local p_phase = state.phase - (dt * (heartbeat / 60) * (1 - i/steps))
        state.points[math.floor(p)] = getH(p_phase)
    end

    -- Clear a small gap ahead of the sweepPos
    local gap = 12
    for i = 1, gap do
        state.points[math.floor((state.sweepPos + i) % width)] = nil
    end

    -- Draw the buffered points
    local startX = centerX - width / 2
    local lastX, lastY

    local function drawSegment(sx, sy, slastX, slastY, sthick)
        if slastX then
            local sdy = sy - slastY
            if math.abs(sdy) > 1 then
                local ssy = sdy > 0 and slastY or sy
                surface.DrawRect(sx - sthick, ssy, sthick * 2 + 1, math.abs(sdy) + 1)
            else
                surface.DrawRect(sx - sthick, sy - sthick, sthick * 2 + 1, sthick * 2 + 1)
            end
        else
            surface.DrawRect(sx - sthick, sy - sthick, sthick * 2 + 1, sthick * 2 + 1)
        end
    end

    for i = 0, width - 1 do
        local h_val = state.points[i]
        if h_val == nil then
            lastX, lastY = nil, nil
            continue
        end

        local x = startX + i
        local y = centerY - (h_val * height / 2)

        local dist = state.sweepPos - i
        if dist < 0 then dist = dist + width end

        -- Matching the reference image: bright leading edge with a long, dim persistent tail
        local alphaMult = math.exp(-dist / (width * 0.08)) -- Sharp initial drop
        alphaMult = math.max(alphaMult, math.Clamp(0.18 * (1 - dist / width), 0, 0.18)) -- Long dim tail

        local currentAlpha = color.a * alphaMult
        local shadowAlpha = 180 * alphaMult * ringAlpha

        draw.NoTexture()
        local thick = 2

        -- Draw Shadow first
        surface.SetDrawColor(0, 0, 0, shadowAlpha)
        drawSegment(x, y, lastX, lastY, thick + 1)

        -- Draw Main Line
        surface.SetDrawColor(color.r, color.g, color.b, currentAlpha)
        drawSegment(x, y, lastX, lastY, thick)

        lastX, lastY = x, y
    end
end

hook.Add("HUDPaint", "DrawUnconsciousRing", function()
    if not hg_unconsciousring:GetBool() then
        ringAlpha = 0
        peakShock = 40
        lastPhaseMod = 0
        ResetRingAudio()
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        ringAlpha = 0
        peakShock = 40
        lastPhaseMod = 0
        lastConsciousness = 1
        consciousnessDropTime = 0
        consciousnessDropAmount = 0
        ResetRingAudio()
        return
    end
    
    local org = ply.organism
    if not org then 
        ringAlpha = 0
        peakShock = 40
        lastPhaseMod = 0
        ResetRingAudio()
        return 
    end
    
    local isUnconscious = org.otrub
    local heartbeat = org.heartbeat or 70
    local pulse = org.pulse or 70
    local brain = org.brain or 0
    local bloodpressure = org.bloodpressure or 93
    local consciousness = org.consciousness or 0
    local shock = org.shock or 0
    local isCritical = (org.critical == true) or (heartbeat < 1 and brain >= 0.02) or (brain > 0.4)
    local admiring = ply:GetNWBool("mcd_admiring", false) and not ply.mcd_admire_local_cancel

    -- Track sudden consciousness loss
    local consciousnessDelta = lastConsciousness - consciousness
    if consciousnessDelta > 0.1 then
        -- Significant drop detected
        consciousnessDropTime = CurTime()
        consciousnessDropAmount = consciousnessDelta
    end
    lastConsciousness = consciousness

    -- Check if consciousness loss was recent and sudden (within 5 seconds)
    local recentSuddenDrop = (CurTime() - consciousnessDropTime) < 5 and consciousnessDropAmount > 0.15

    -- Reset flatline flag when heartbeat recovers from flatline
    if heartbeat >= 1 and wasHeartbeatZero then
        flatlinePlayedThisUnconscious = false
    end
    wasHeartbeatZero = heartbeat < 1
    
    -- Reset flatline flag when becoming unconscious to ensure asystole plays
    if isUnconscious and not wasUnconsciousState then
        flatlinePlayedThisUnconscious = false
    end
    
    local className = ply.PlayerClassName
    local isNearDeathClass = nearDeathClasses[className] == true
    
    local isInBadHealth = isCritical
        or org.heartstop
        or (org.trachea and org.trachea >= 0.6)
        or (org.skull and org.skull >= 1)
        or (org.heart and org.heart > 0.6)
        or (org.blood and org.blood < 3000)
        or (org.o2 and org.o2[1] and org.o2[1] < 10)
        or (org.bloodpressure and org.bloodpressure < 50)
        or (heartbeat < 30 or heartbeat > 170)
    
    if not ply:Alive() or isUnconscious or not isInBadHealth then
        if alertPlayed then
            if IsValid(alertSound) then alertSound:Stop() end
            alertPlayed = false
            alertSound = nil
        end
    elseif isNearDeathClass and isInBadHealth and not alertPlayed then
        sound.PlayFile("sound/health/alert.ogg", "noblock noplay", function(s)
            if IsValid(s) then
                s:EnableLooping(true)
                s:SetVolume(1.0)
                s:Play()
                alertSound = s
            end
        end)
        alertPlayed = true
    end
    
    heartPhase = heartPhase + FrameTime() * (heartbeat / 60)

    local lowConsciousness = (org.consciousness or 1) < 0.4 and not isUnconscious
    local isCritical = (org.critical == true) or (heartbeat < 1 and brain >= 0.02) or (brain > 0.4)
    local abnormalPulse = (heartbeat < 40 and heartbeat >= 1) or heartbeat > 100
    local fibrillating = heartbeat > 250

    local showAwakeECG = not isUnconscious and not lowConsciousness and (abnormalPulse or admiring or recentSuddenDrop or fibrillating or isCritical)
    
    if isUnconscious then
        if not wasUnconsciousState then
            flatlinePlayedThisUnconscious = false
        end

        local currentShock = org.shock or 0
        if currentShock > peakShock then
            peakShock = currentShock
        end
        ringAlpha = Lerp(FrameTime() * 2, ringAlpha, 1)
        dotBeat = math.floor(CurTime()) % 3
    elseif lowConsciousness then
        ringAlpha = Lerp(FrameTime() * 2, ringAlpha, 0.4)
        dotBeat = math.floor(CurTime()) % 3
    else
        flatlinePlayedThisUnconscious = false
        ringAlpha = Lerp(FrameTime() * 3, ringAlpha, 0)
        if ringAlpha <= 0.01 and not showAwakeECG then
            ringAlpha = 0
            peakShock = 40
            centerEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
            lastPhaseMod = 0
            ResetRingAudio()
        end
    end
    wasUnconsciousState = isUnconscious

    -- Update persistent awake ECG alpha
    if showAwakeECG then
        awakeECGAlpha = Lerp(FrameTime() * 4, awakeECGAlpha, 0.15)
    else
        awakeECGAlpha = Lerp(FrameTime() * 2, awakeECGAlpha, 0)
    end
    
    local showPulseCheckECG = false

    local isCheckingPulse = false
    if IsValid(g_PulseCheckTarget) then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_hands_sh" and wep.GetCarrying and IsValid(wep:GetCarrying()) and wep:GetCarrying() == g_PulseCheckTarget then
            isCheckingPulse = true
        else
            g_PulseCheckTarget = nil
            g_PulseCheckData = nil
        end
    end

    if isCheckingPulse then
        showPulseCheckECG = true
    end

    -- Determine if we should show otrub ECG (for unconscious or awake with abnormal heartbeat/admiring/recent sudden drop)

    if ringAlpha <= 0 and not showPulseCheckECG and not (abnormalPulse or admiring or recentSuddenDrop or fibrillating or isCritical) then return end
    local showOtrubECG = isUnconscious or lowConsciousness or recentSuddenDrop or (not isUnconscious and (abnormalPulse or admiring or fibrillating))

    local otrubECGAlpha = (isUnconscious or lowConsciousness) and ringAlpha or awakeECGAlpha
    
    if otrubECGAlpha > 0.01 then
        lerpBrain = Lerp(FrameTime() * 3, lerpBrain, org.brain or 0)
        lerpShock = Lerp(FrameTime() * 6, lerpShock, org.shock or 0)
        lerpConsciousness = Lerp(FrameTime() * 3, lerpConsciousness, org.consciousness or 0)
        
        local scrW, scrH = ScrW(), ScrH()
        local centerX, centerY = scrW / 2, scrH / 2
        
        -- Only draw dark background and ring for unconscious players
        if isUnconscious or lowConsciousness then
            surface.SetDrawColor(0, 0, 0, 90 * otrubECGAlpha)
            surface.DrawRect(0, 0, scrW, scrH)
            
            local ringColor = isCritical and Color(200, 0, 0, 255 * otrubECGAlpha) or Color(220, 220, 220, 255 * otrubECGAlpha)
            local dotColor = isCritical and ringColor or Color(255, 255, 255, 255 * otrubECGAlpha)
            
            local progress = 0
            if isCritical then
                progress = math.Clamp((0.70 - lerpBrain) / (0.70 - 0.02), 0, 1)
            else
                local shockProgress = math.Clamp((peakShock - lerpShock) / (peakShock - 0.02), 0, 1)
                local consciousnessProgress = math.Clamp(lerpConsciousness / 0.10, 0, 1)
                progress = math.min(shockProgress, consciousnessProgress)
            end
            
            local radius = 280
            local thickness = 12
            
            DrawArc(centerX, centerY, radius, thickness, 0, 360, 60, Color(40, 40, 40, 100 * otrubECGAlpha))
            DrawArc(centerX, centerY, radius, thickness, 90, 90 - (progress * 360), 80, ringColor)
            
            if hg_unconsciousclassic and hg_unconsciousclassic:GetBool() then
                lastPhaseMod = 0
                flatlinePlayedThisUnconscious = false
                local beat = dotBeat
                local dotText = ""

                if isCritical then
                    local redDots = {".!", "..!", "...!"}
                    dotText = redDots[beat + 1]
                else
                    local whiteDots = {".", "..", "..."}
                    dotText = whiteDots[beat + 1]
                end
                
                draw.SimpleText(dotText, "UnconsciousDots", centerX, centerY, dotColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                local isFlatline = heartbeat < 1
                if isFlatline and not flatlinePlayedThisUnconscious then
                    EmitRingSound(SOUND_FLATLINE, 1.0)
                    flatlinePlayedThisUnconscious = true
                end
                UpdateRingAudio(heartbeat, otrubECGAlpha, org, admiring)
                DrawEKG(centerEKGState, centerX, centerY, 540, 140, heartbeat, pulse, ringColor, otrubECGAlpha)
            end
        else
            -- For awake players with abnormal heartbeat or admiring, just show the ECG line without background/ring
            local ecgColor = isCritical and Color(255, 0, 0, 255 * otrubECGAlpha) or Color(255, 255, 255, 255 * otrubECGAlpha)
            DrawEKG(centerEKGState, centerX, centerY, 540, 140, heartbeat, pulse, ecgColor, otrubECGAlpha)
            
            -- Add consciousness meter ring for low opacity ECG when consciousness is low or recently dropped
            if recentSuddenDrop or consciousness < 0.6 then
                local ringRadius = 280
                local ringThickness = 12
                local consciousnessProgress = math.Clamp(lerpConsciousness, 0, 1)
                -- Always use white color when awake (shows consciousness, not brain health)
                local ringColor = Color(220, 220, 220, 255 * otrubECGAlpha)
                
                -- Draw background ring
                DrawArc(centerX, centerY, ringRadius, ringThickness, 0, 360, 60, Color(40, 40, 40, 100 * otrubECGAlpha))
                -- Draw consciousness progress ring (1.0 = full circle, 0 = empty)
                DrawArc(centerX, centerY, ringRadius, ringThickness, 90, 90 - (consciousnessProgress * 360), 80, ringColor)
            end
        end
    end

    if showPulseCheckECG then
        ecgAlphaPulseCheck = Lerp(FrameTime() * 4, ecgAlphaPulseCheck, 1)
    else
        ecgAlphaPulseCheck = Lerp(FrameTime() * 6, ecgAlphaPulseCheck, 0)
    end

    if ecgAlphaPulseCheck > 0.01 then
        local boxW, boxH = 400, 200
        local boxX, boxY = ScrW() / 2 - boxW / 2, ScrH() - boxH - 60

        surface.SetDrawColor(0, 0, 0, 150 * ecgAlphaPulseCheck)
        surface.DrawRect(boxX, boxY, boxW, boxH)
        surface.SetDrawColor(255, 255, 255, 200 * ecgAlphaPulseCheck)
        surface.DrawOutlinedRect(boxX, boxY, boxW, boxH)

        local target_org = g_PulseCheckTarget.organism or {}
        local target_heartbeat = target_org.heartbeat or 70
        local target_pulse = target_org.pulse or 70
        local target_bp = target_org.bloodpressure or 93
        local target_brain = target_org.brain or 0
        local target_isCritical = (target_org.critical == true) or (target_heartbeat < 1 and target_brain >= 0.02) or (target_brain > 0.4)

        if g_PulseCheckData and not g_PulseCheckData.completed then
            if target_org.heartstop or target_heartbeat <= 0 then
                g_PulseCheckData.completed = true
                g_PulseCheckData.finalBPM = "No Pulse"
            elseif CurTime() >= g_PulseCheckData.started + 10 then
                g_PulseCheckData.completed = true
                g_PulseCheckData.finalBPM = g_PulseCheckData.counted * 6
            else
                local timeNow = CurTime()
                while timeNow >= g_PulseCheckData.nextBeat and g_PulseCheckData.nextBeat <= g_PulseCheckData.started + 10 do
                    g_PulseCheckData.counted = g_PulseCheckData.counted + 1
                    local dynamicRate = math.max(target_heartbeat, 1)
                    g_PulseCheckData.nextBeat = g_PulseCheckData.nextBeat + (60 / dynamicRate)
                    if target_heartbeat < 1 then
                        EmitRingSound(SOUND_FLATLINE, 0.8)
                    else
                        local vol = GetHeartbeatVolume(target_org)
                        local abnormalPulse = (target_heartbeat < 40 and target_heartbeat >= 1) or target_heartbeat > 100
                        local highStress = vol > 0.5
                        local fibrillating = target_heartbeat > 250
                        if fibrillating then
                            EmitRingSound(SOUND_FIBRILLATION, vol)
                        elseif abnormalPulse or highStress then
                            EmitRingSound(SOUND_HEART, vol * CRITBEAT_VOLUME_SCALE)
                        else
                            EmitRingSound("sound/heartbeat/heartbeat_single.wav", vol)
                        end
                    end
                end
            end
        end

        DrawEKG(pulseCheckEKGState, boxX + boxW / 2, boxY + boxH / 2, boxW - 20, boxH - 20, target_heartbeat, target_pulse, Color(255, 255, 255, 255), ecgAlphaPulseCheck)

        local displayText = ""
        if g_PulseCheckData then
            if g_PulseCheckData.completed then
                if type(g_PulseCheckData.finalBPM) == "number" then
                    displayText = g_PulseCheckData.counted .. " x 6 = " .. g_PulseCheckData.finalBPM .. " BPM"
                else
                    displayText = g_PulseCheckData.finalBPM
                end
            else
                displayText = "Counting: " .. g_PulseCheckData.counted
            end
        end

        draw.SimpleText(displayText, "HomigradFontTypewriterSmall", boxX + boxW / 2, boxY - 15, Color(255, 255, 255, 255 * ecgAlphaPulseCheck), TEXT_ALIGN_CENTER)
    else
        pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
    end


    local abnormalPulse = (heartbeat < 40 and heartbeat >= 1) or heartbeat > 100
    if heartbeat >= 1 then
        if IsValid(flatlineStation) and flatlineStation:GetState() == GMOD_CHANNEL_PLAYING then
            flatlineStation:Stop()
        end

        if admiring or isUnconscious or abnormalPulse or isCheckingPulse then
            -- Skip oldring sound system when unconscious ring is active with EKG mode
            if not (isUnconscious and ringAlpha > 0.01 and not (hg_unconsciousclassic and hg_unconsciousclassic:GetBool())) then
                local currentHeartBeat = math.floor(heartPhase)
                if currentHeartBeat > lastHeartBeat then
                    lastHeartBeat = currentHeartBeat

                    local vol = GetHeartbeatVolumeAdmiring(org, admiring)
                    local hasHealthHUD = (className == "Gordon" or className == "Combine" or className == "furry")
                    local highStress = vol > 0.5
                    local fibrillating = heartbeat > 250
                    if (abnormalPulse and hasHealthHUD) or highStress or admiring then
                        local soundToPlay = fibrillating and SOUND_FIBRILLATION or SOUND_HEART
                        local volScale = fibrillating and 1 or CRITBEAT_VOLUME_SCALE
                        EmitRingSound(soundToPlay, vol * volScale)
                    else
                        EmitRingSound("sound/heartbeat/heartbeat_single.wav", vol)
                    end
                end
            end
        end
    end
    
    if isNearDeathClass and isInBadHealth then
        local flashCycle = math.floor(CurTime() / 0.65)
        local isVisible = flashCycle % 2 == 0
        if isVisible then
            local msgGroup = math.floor((flashCycle % 8) / 4)
            local msg = msgGroup == 0 and "VITALS CRITICAL" or "SEEK MEDICAL ATTENTION"
            local font = "HomigradFontLarge"
            if className == "Combine" then
                font = "CMBFontSmall"
            elseif className == "Gordon" then
                font = "HEVFontSmall"
            elseif className == "furry" then
                font = "ZB_ProotOSMedium"
            end
            draw.SimpleText(msg, font, ScrW() / 2, ScrH() * 0.88, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Show "Theres nothing you can do." when otrub and critical
    if isUnconscious and isCritical and otrubECGAlpha > 0.01 then
        -- Calculate fade-in based on how critical the condition is (progress from brain damage)
        local criticalProgress = math.Clamp((0.70 - lerpBrain) / (0.70 - 0.02), 0, 1)
        local textAlpha = 255 * otrubECGAlpha * criticalProgress
        draw.SimpleText("Theres nothing you can do.", "OtrubCriticalMessage", ScrW() / 2, ScrH() * 0.35, Color(255, 0, 0, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)
