local function DrawArc(x, y, radius, thickness, startAng, endAng, segments, color)
    surface.SetDrawColor(color.r, color.g, color.b, color.a)
    draw.NoTexture()

    local step = (endAng - startAng) / segments
    for i = 0, segments - 1 do
        local a1 = math.rad(startAng + i * step)
        local a2 = math.rad(startAng + (i + 1) * step)
        local cos1, sin1 = math.cos(a1), math.sin(a1)
        local cos2, sin2 = math.cos(a2), math.sin(a2)

        surface.DrawPoly({
            { x = x + cos1 * (radius - thickness), y = y - sin1 * (radius - thickness) },
            { x = x + cos1 * radius, y = y - sin1 * radius },
            { x = x + cos2 * radius, y = y - sin2 * radius },
            { x = x + cos2 * (radius - thickness), y = y - sin2 * (radius - thickness) }
        })
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

surface.CreateFont("HomigradFontTypewriterSmall", {
    font = "Veteran Typewriter",
    size = ScreenScaleH(12),
    weight = 800,
    antialias = true,
    shadow = true
})

surface.CreateFont("HomigradECGVitals", {
    font = "Bahnschrift",
    size = 13,
    weight = 700,
    antialias = true,
    shadow = true
})

local ringAlpha = 0
local dotBeat = 0
local compactBorderInset = 0
local compactBoxX
local compactBoxY

local function GetShockConsciousnessThreshold(analgesia, painkiller)
    local medication = math.max((analgesia or 0) + (painkiller or 0) * 0.3, 0)
    return 25 * (medication * 4 + 1)
end

local ecgAlphaPulseCheck = 0
local awakeECGAlpha = 0
local lastECGState
local ecgStateAlertUntil = 0
local ecgStateAlertDuration = 1
local lastHeartBeat = 0
local heartPhase = 0

local awakeECGSeverityByState = {
    normal_sinus = 0,
    sinus_bradycardia = 0.15,
    sinus_tachycardia = 0.15,
    hypothermia_bradycardia = 0.3,
    atrial_fibrillation = 0.65,
    ventricular_ectopy = 0.75,
    ventricular_fibrillation = 0.95,
    sinus_pause = 0.4,
    junctional_escape = 0.5,
    cerebral_bradycardia = 0.55,
    cerebral_irregular = 0.6,
    compressed_tachycardia = 0.6,
    av_block_partial = 0.65,
    ventricular_escape = 0.7,
    extreme_tachycardia = 0.75,
    av_block_complete = 0.8,
    terminal_tachycardia = 0.9,
    pea = 0.95,
    asystole = 1,
}

local function GetAwakeECGSeverity(ecgState)
    return awakeECGSeverityByState[ecgState] or 0.5
end

local function SmoothAlpha(current, target, speed)
    return Lerp(1 - math.exp(-FrameTime() * speed), current, target)
end

local function UpdateECGStateAlert(ecgState)
    if not lastECGState then
        lastECGState = ecgState
        return 0
    end

    if ecgState ~= lastECGState then
        if ecgState == "normal_sinus" then
            local previousSeverity = GetAwakeECGSeverity(lastECGState)
            ecgStateAlertDuration = Lerp(previousSeverity, 3, 7)
            ecgStateAlertUntil = CurTime() + ecgStateAlertDuration
        else
            ecgStateAlertUntil = 0
        end
        lastECGState = ecgState
    end

    if ecgState ~= "normal_sinus" then return 0 end
    return math.Clamp((ecgStateAlertUntil - CurTime()) / math.max(ecgStateAlertDuration, 0.01), 0, 1)
end

-- Better sound system from oldring
local SOUND_HEART = "health/critbeat.mp3"
local SOUND_HEALTH_ALARM = "health/healthbeat.mp3"
local SOUND_FLATLINE = "health/gg.mp3"
local SOUND_FIBRILLATION = "criticalbeats.mp3"
local CRITBEAT_VOLUME_SCALE = 0.6

local lastPhaseMod = 0
local wasUnconsciousState = false
local unconsciousStartTime
local UNCONSCIOUS_RING_DELAY = 1
local WAKE_CONSCIOUSNESS_THRESHOLD = 0.3
local OTRUB_CONSCIOUSNESS_RECOVERY_SPEED = 20
local OTRUB_SHOCK_DECAY_PER_SECOND = 4
local OTRUB_PAIN_DRAIN_PER_SECOND = 8 * 4.5
local INCAPACITATION_DEATH_TIME = 25
local wakeEstimateAnchor = 0
local wakeEstimateSmoothed

local function EstimateWakeSeconds(org)
    local brainOxygen = math.Clamp(org.brainoxygen or 1, 0, 1)
    local cannotWake = org.incapacitated
        or org.heartstop
        or brainOxygen < 0.20
        or (org.trachea or 0) >= 0.5

    local brainSeverity = math.Clamp(((org.brain or 0) - 0.325) / 0.675, 0, 1)
    local hemorrhageSeverity = math.Clamp(((org.brainHemorrhage or 0) - 0.05) / 0.95, 0, 1)
    local brainDrain = (brainSeverity > 0 and (0.17 + brainSeverity * 0.06) or 0)
        + hemorrhageSeverity * (0.02 + hemorrhageSeverity * 0.12)

    if cannotWake or brainDrain >= (1 / OTRUB_CONSCIOUSNESS_RECOVERY_SPEED) then return nil end

    local analgesia = math.max(org.analgesia or 0, 0)
    local painkiller = math.max(org.painkiller or 0, 0)
    local shockThreshold = GetShockConsciousnessThreshold(analgesia, painkiller)
    local shockSeconds = math.max((org.shock or 0) - shockThreshold, 0) / OTRUB_SHOCK_DECAY_PER_SECOND

    -- Pain above 80 keeps driving shock toward at least 55 on the server.
    -- Account for the time needed to drain below that gate instead of letting
    -- a large shock value fall outside the old ring percentage calculation.
    local adrenaline = math.max(org.adrenaline or 0, 0)
    local painModifier = math.max(1 - adrenaline / 4, 0.75)
        * math.max(1 - (analgesia + painkiller * 0.3), 0)
    local painSeconds = 0
    if painModifier > 0.001 and (org.pain or 0) > 80 then
        local targetAveragePain = 80 / painModifier
        local adrenalinePacing = math.max(math.max(1 - adrenaline, 0.05) / (1 + adrenaline * 1.5), 0.02)
        local medicationDrain = (painkiller * 0.3 + analgesia) * 4
        local painDrain = math.max((OTRUB_PAIN_DRAIN_PER_SECOND + medicationDrain) * adrenalinePacing, 0.05)
        painSeconds = math.max((org.avgpain or org.pain or 0) - targetAveragePain, 0) / painDrain
    end

    local tranquilizer = math.max(org.tranquilizer or 0, 0)
    local sedationSeconds = math.max(tranquilizer - 1, 0) * 5 + math.min(tranquilizer, 1) * 30
    local settleSeconds = math.max(shockSeconds, painSeconds, sedationSeconds)
    local recoveryStart = tranquilizer > 0.05 and 0 or math.Clamp(org.consciousness or 0, 0, 1)
    local recoveryRate = math.max(1 / OTRUB_CONSCIOUSNESS_RECOVERY_SPEED - brainDrain, 0.001)
    local recoverySeconds = math.max(WAKE_CONSCIOUSNESS_THRESHOLD - recoveryStart, 0) / recoveryRate

    return math.max(settleSeconds + recoverySeconds, 0)
end

local function UpdateWakeEstimate(org)
    local estimate = EstimateWakeSeconds(org)
    if not estimate then
        wakeEstimateAnchor = 0
        wakeEstimateSmoothed = nil
        return nil, 0
    end

    if not wakeEstimateSmoothed or estimate > wakeEstimateSmoothed + 2 then
        wakeEstimateSmoothed = estimate
    else
        wakeEstimateSmoothed = SmoothAlpha(wakeEstimateSmoothed, estimate, 2)
    end

    wakeEstimateAnchor = math.max(wakeEstimateAnchor, wakeEstimateSmoothed, 1)
    local progress = math.Clamp(1 - wakeEstimateSmoothed / wakeEstimateAnchor, 0, 1)
    return wakeEstimateSmoothed, progress
end
local flatlinePlayedThisLife = false
local wasHeartbeatZero = false
local soundGen = 0
local heartStations = {}
local heartStationsLoading = false
local heartStationNext = 1
local flatlineStation = nil
local flatlineLoading = false
local fibrillationStation = nil
local fibrillationLoading = false
local fibrillationPlaying = false
local fibrillationRequested = false
local fibrillationVolume = 0

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
         + math.Clamp(org.brainHemorrhage or 0, 0, 1) * 0.2
    return math.Clamp(0.2 + hurt, 0.2, 1.0)
end

local function GetMechanicalPulseStrength(org)
    if not org then return 0 end

    local palpable = math.Clamp((tonumber(org.pulse) or 0) / 70, 0, 1.25)
    local output = math.Clamp(tonumber(org.cardiacOutput) or palpable, 0, 1.25)
    local stroke = math.Clamp(tonumber(org.strokeVolume) or output, 0, 1.25)
    local pressure = math.Clamp((tonumber(org.bloodPressure) or (palpable * 92)) / 92, 0, 1.25)

    -- The weakest mechanical value owns the audible thump. Electrical activity
    -- can remain visible during PEA or VF without manufacturing a heartbeat.
    return math.Clamp(math.min(palpable, output, stroke, pressure), 0, 1)
end

local function IsVentricularFibrillation(org)
    return org and (org.ecgState == "ventricular_fibrillation" or org.fibrillation == true)
end

local function IsCirculationCritical(org)
    if not org then return false end
    if org.heartstop or org.ecgState == "asystole" or org.ecgState == "pea" then return true end

    local systolic = tonumber(org.systolic)
    local output = tonumber(org.cardiacOutput)
    local stroke = tonumber(org.strokeVolume)
    local pressure = tonumber(org.bloodPressure)

    return (systolic and systolic < 75)
        or (pressure and pressure < 50)
        or (output and output < 0.3)
        or (stroke and stroke < 0.25)
        or (tonumber(org.cardiacTamponade) or 0) > 0.55
end

local function GetHeartbeatVolumeAdmiring(org, admiring)
    if not org then return 0.2 end
    if admiring then
        -- When admiring self, make heartbeats loud and clear with abnormal heart rate
        local heartRate = tonumber(org.heartbeat) or 0
        local abnormalPulse = (heartRate < 40 and heartRate >= 1) or heartRate > 100
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

    if IsValid(fibrillationStation) then
        fibrillationStation:Stop()
    end
    fibrillationStation = nil
    fibrillationLoading = false
    fibrillationPlaying = false
    fibrillationRequested = false
    fibrillationVolume = 0
end

hook.Add("Player Spawn", "ResetUnconsciousRingFlatline", function(ply)
    if ply == LocalPlayer() then
        flatlinePlayedThisLife = false
        wasHeartbeatZero = false
    end
end)
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

local function RequestFibrillationSound(volume)
    if hg_unconsciousclassic and hg_unconsciousclassic:GetBool() then return end
    if hg and hg.healthAlarmActive then return end
    if hg and hg.criticalBeatsActive then return end
    fibrillationRequested = true
    fibrillationVolume = math.max(fibrillationVolume, math.Clamp(volume or 1, 0, 1))
end

local function UpdateFibrillationSound()
    if fibrillationRequested then
        if fibrillationPlaying then return end

        fibrillationPlaying = true
        if IsValid(fibrillationStation) then
            PlayStation(fibrillationStation, fibrillationVolume)
            return
        end

        if fibrillationLoading then return end
        fibrillationLoading = true
        local gen = soundGen
        sound.PlayFile("sound/" .. SOUND_FIBRILLATION, "noblock noplay", function(station)
            fibrillationLoading = false
            if gen ~= soundGen or not fibrillationPlaying then
                if IsValid(station) then station:Stop() end
                return
            end
            if IsValid(station) then
                fibrillationStation = station
                station:EnableLooping(true)
                PlayStation(fibrillationStation, fibrillationVolume)
            end
        end)
    elseif fibrillationPlaying then
        fibrillationPlaying = false
        if IsValid(fibrillationStation) and fibrillationStation:GetState() == GMOD_CHANNEL_PLAYING then
            if fibrillationStation.FadeOut then
                fibrillationStation:FadeOut(0.5)
            else
                fibrillationStation:SetVolume(0)
                fibrillationStation:Stop()
            end
        end
    end
end

-- Update ring audio with phase-based triggering from oldring
local function UpdateRingAudio(heartRate, ringAlpha, org, admiring)
    if heartRate < 1 or ringAlpha <= 0 then return end

    local prev = lastPhaseMod
    local curr = (lastPhaseMod + FrameTime() * (heartRate / 60)) % 1
    lastPhaseMod = curr

    local mechanicalStrength = GetMechanicalPulseStrength(org)
    local beatVolume = GetHeartbeatVolumeAdmiring(org, admiring) * ringAlpha * mechanicalStrength
    local fibrillating = IsVentricularFibrillation(org)
    if fibrillating then
        RequestFibrillationSound(GetHeartbeatVolumeAdmiring(org, admiring) * ringAlpha)
    end
    if PhaseCrossed(prev, curr, 0.239) then
        -- Use heartthump for abnormal heart rates or high stress, normal heartbeat otherwise
        local abnormalPulse = (heartRate < 40 and heartRate >= 1) or heartRate > 100
        local highStress = false
        if org then
            local hurt = math.Clamp((5000 - (org.blood or 5000)) / 5000, 0, 1) * 0.4
                 + math.Clamp((org.pain or 0) / 100, 0, 1) * 0.4
                 + math.Clamp(org.brain or 0, 0, 1) * 0.2
            highStress = hurt > 0.3
        end

        -- When admiring with abnormal pulse, use full volume
        if admiring and abnormalPulse then
            beatVolume = mechanicalStrength
        end

        if fibrillating and hg and hg.healthAlarmActive then
            EmitRingSound(SOUND_HEALTH_ALARM, GetHeartbeatVolumeAdmiring(org, admiring) * ringAlpha)
        elseif mechanicalStrength > 0.02 and not fibrillating and (abnormalPulse or highStress) then
            EmitRingSound(hg and hg.healthAlarmActive and SOUND_HEALTH_ALARM or SOUND_HEART, beatVolume * CRITBEAT_VOLUME_SCALE)
        elseif mechanicalStrength > 0.02 and not fibrillating then
            EmitRingSound(hg and hg.healthAlarmActive and SOUND_HEALTH_ALARM or "sound/heartbeat/heartbeat_single.ogg", beatVolume)
        end
    end
end

local alertPlayed = false
local alertSound = nil

local g_PulseCheckTarget = nil

usermessage.Hook("hg_StartPulseCheckECG", function(msg)
    g_PulseCheckTarget = msg:ReadEntity()
end)
-- Local variables for faster access
local math = math
local surface = surface
local draw = draw
local Color = Color

local centerEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
local pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }

local function DrawEKG(state, centerX, centerY, width, height, org, color, ringAlpha)
    org = org or {}
    local heartbeat = math.Clamp(tonumber(org.heartbeat) or 0, 0, 300)
    local ecgState = org.ecgState or "normal_sinus"
    local palpitations = tonumber(org.palpitations) or 0
    local arrhythmia = math.Clamp(tonumber(org.arrhythmia) or 0, 0, 1)
    local ischemia = math.max(
        math.Clamp(1 - (tonumber(org.myocardialOxygen) or 1), 0, 1),
        math.Clamp(tonumber(org.ischemia) or 0, 0, 1)
    )
    local hypoxia = math.max(
        math.Clamp(tonumber(org.hypoxia) or 0, 0, 1),
        math.Clamp((12 - ((org.o2 and tonumber(org.o2[1])) or 30)) / 12, 0, 1)
    )
    local tamponade = math.Clamp(tonumber(org.cardiacTamponade) or 0, 0, 1)
    local temperature = tonumber(org.temperature) or 36.7
    local time = CurTime()
    if state.lastUpdate == 0 then state.lastUpdate = time end
    local dt = time - state.lastUpdate
    state.lastUpdate = time
    if state.rhythm ~= ecgState then
        state.rhythm = ecgState
        state.rhythmStartedAt = time
    end

    local fibrillationFine = math.Clamp(math.max(
        (tonumber(org.severeHypoxiaTime) or 0) / 35,
        ecgState == "ventricular_fibrillation" and (time - (state.rhythmStartedAt or time)) / 90 or 0
    ), 0, 1)

    -- Increment heart phase based on heartbeat (BPM to beats per second)
    state.phase = state.phase + dt * (heartbeat / 60)

    local sweepSpeed = width / 4
    local oldSweepPos = state.sweepPos
    state.sweepPos = (state.sweepPos + dt * sweepSpeed) % width

    local function getSinusH(phase)
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

        return h
    end

    local function getWideComplexH(phase)
        phase = phase % 1
        if phase < 0.08 or phase > 0.58 then return 0 end

        local p = (phase - 0.08) / 0.5
        if p < 0.58 then
            return math.sin(p / 0.58 * math.pi) * 0.85
        end
        return -math.sin((p - 0.58) / 0.42 * math.pi) * 0.45
    end

    local function getJunctionalH(phase)
        local h = getSinusH(phase)
        -- The sinus P wave is absent; occasional retrograde P waves appear
        -- just after the narrow escape complex.
        if phase > 0.05 and phase < 0.15 then
            h = h - math.sin((phase - 0.05) / 0.1 * math.pi) * 0.12
        elseif phase > 0.36 and phase < 0.44 then
            h = h - math.sin((phase - 0.36) / 0.08 * math.pi) * 0.1
        end
        return h
    end

    local function getHypothermiaH(phase)
        local h = 0
        -- Hypothermia lengthens PR, widens QRS, and prolongs QT. The positive
        -- notch after the QRS is an Osborn/J wave.
        if phase > 0.06 and phase < 0.16 then
            h = math.sin((phase - 0.06) / 0.1 * math.pi) * 0.12
        elseif phase > 0.29 and phase < 0.51 then
            h = getWideComplexH((phase - 0.21) * 2.25)
        elseif phase > 0.51 and phase < 0.59 then
            h = math.sin((phase - 0.51) / 0.08 * math.pi) * 0.18
        elseif phase > 0.64 and phase < 0.9 then
            h = math.sin((phase - 0.64) / 0.26 * math.pi) * 0.2
        end
        return h
    end

    local function rhythmNoise(index, lane)
        local value = math.sin(index * 12.9898 + lane * 78.233) * 43758.5453
        return value - math.floor(value)
    end

    local function getAtrialBeat(rawPhase)
        local block = math.floor(rawPhase / 16)
        local offset = rawPhase - block * 16
        local weights, total = {}, 0
        for i = 0, 15 do
            local weight = 0.58 + rhythmNoise(block * 16 + i, 1) * 0.9
            weights[i] = weight
            total = total + weight
        end

        local elapsed = 0
        local scale = 16 / total
        for i = 0, 15 do
            local duration = weights[i] * scale
            if offset < elapsed + duration then
                return block * 16 + i, (offset - elapsed) / duration, duration
            end
            elapsed = elapsed + duration
        end

        return block * 16 + 15, 1, weights[15] * scale
    end

    local function getAtrialFibrillationH(rawPhase)
        local beatIndex, phase, duration = getAtrialBeat(rawPhase)
        local h = math.sin(rawPhase * math.pi * 2 * 5.4 + math.sin(rawPhase * math.pi * 2 * 0.37) * 0.8) * 0.052
        h = h + math.sin(rawPhase * math.pi * 2 * 7.1 + beatIndex * 0.31) * 0.022

        local qrsStart = 0.16
        local qrsWidth = math.Clamp(0.095 / duration, 0.06, 0.17)
        if phase >= qrsStart and phase < qrsStart + qrsWidth then
            local qrsPhase = (phase - qrsStart) / qrsWidth
            local amplitude = 0.84 + rhythmNoise(beatIndex, 2) * 0.24
            if qrsPhase < 0.16 then
                h = h - math.sin(qrsPhase / 0.16 * math.pi) * 0.13 * amplitude
            elseif qrsPhase < 0.52 then
                h = h + math.sin((qrsPhase - 0.16) / 0.36 * math.pi) * amplitude
            else
                h = h - math.sin((qrsPhase - 0.52) / 0.48 * math.pi) * 0.22 * amplitude
            end
        end

        local tStart = qrsStart + qrsWidth + 0.075 / duration
        local tWidth = math.Clamp(0.19 / duration, 0.12, 0.34)
        if phase >= tStart and phase < tStart + tWidth then
            h = h + math.sin((phase - tStart) / tWidth * math.pi) * 0.2
        end

        return h
    end

    local function getVentricularFibrillationH(rawPhase)
        local irregularity = math.sin(rawPhase * math.pi * 2 * 0.16) * 0.72
        local h = math.sin(rawPhase * math.pi * 2 * 1.14 + irregularity)
        h = h + math.sin(rawPhase * math.pi * 2 * 2.47 + math.sin(rawPhase * math.pi * 2 * 0.29)) * 0.34
        h = h + math.sin(rawPhase * math.pi * 2 * 3.81 + 1.1) * 0.16
        local envelope = math.Clamp(0.7 + math.sin(rawPhase * math.pi * 2 * 0.22) * 0.16 + math.sin(rawPhase * math.pi * 2 * 0.51 + 0.8) * 0.1, 0.36, 1)
        local amplitude = Lerp(fibrillationFine, 0.54, 0.20)
        return math.Clamp(h * envelope * amplitude, -0.75, 0.75)
    end

    local function getPVCH(phase)
        if phase < 0.12 or phase > 0.7 then return 0 end
        local p = (phase - 0.12) / 0.58
        if p < 0.64 then return math.sin(p / 0.64 * math.pi) * 1.15 end
        return math.sin((p - 0.64) / 0.36 * math.pi) * 0.42
    end

    local function getPalpitationH(phase)
        -- Sustained tachycardia progressively merges QRS and T waves into the
        -- broad sine-like ventricular-tachycardia morphology.
        return math.sin(phase * math.pi * 2) * 0.62
    end

    local function getAVBlockH(phase, complete)
        local h = getSinusH(phase)
        -- Extra atrial activity makes the P-to-QRS relationship visibly
        -- prolonged (partial block) or dissociated (complete block).
        if phase > 0.58 and phase < 0.68 then
            h = h + math.sin((phase - 0.58) / 0.1 * math.pi) * 0.12
        end
        if complete and phase > 0.78 and phase < 0.88 then
            h = h + math.sin((phase - 0.78) / 0.1 * math.pi) * 0.12
        end
        return h
    end

    local function getCerebralH(phase, beatIndex)
        if beatIndex % 5 == 0 and phase > 0.1 and phase < 0.7 then
            return getWideComplexH(phase)
        end

        local h = getSinusH(phase)
        -- Intracranial hemorrhage can lengthen QT and invert/warp T waves.
        if phase > 0.45 and phase < 0.65 then
            h = h - math.sin((phase - 0.45) / 0.2 * math.pi) * 0.48
        elseif phase > 0.68 and phase < 0.9 then
            h = h - math.sin((phase - 0.68) / 0.22 * math.pi) * 0.16
        end
        return h
    end

    local function getH(rawPhase, tracePos)
        local rhythm = ecgState or "normal_sinus"
        if rhythm == "asystole" or heartbeat < 1 then
            return math.sin((tracePos or 0) * math.pi * 15 + time * 0.7) * 0.007
                + math.sin((tracePos or 0) * math.pi * 33 + time * 0.19) * 0.003
        end

        local phase = rawPhase % 1
        local beatIndex = math.floor(rawPhase)
        local h
        local pvcStrength = math.max(arrhythmia * 0.7, palpitations * 0.8, ischemia * 0.55, hypoxia * 0.45)
        local pvcPeriod = math.max(3, math.floor(Lerp(math.Clamp(pvcStrength, 0, 1), 14, 4)))
        local pvcBeat = pvcStrength >= 0.18 and beatIndex % pvcPeriod == pvcPeriod - 1
        local compensatoryPause = pvcStrength >= 0.18 and beatIndex % pvcPeriod == 0

        if rhythm == "ventricular_fibrillation" then
            h = getVentricularFibrillationH(rawPhase)
        elseif rhythm == "atrial_fibrillation" then
            h = getAtrialFibrillationH(rawPhase)
        elseif rhythm == "ventricular_escape" or rhythm == "terminal_tachycardia" then
            h = getWideComplexH(phase)
        elseif rhythm == "ventricular_ectopy" and beatIndex % 3 == 2 then
            h = getPVCH(phase)
        elseif rhythm == "ventricular_ectopy" and beatIndex % 3 == 0 then
            h = 0
        elseif rhythm == "junctional_escape" then
            h = getJunctionalH(phase)
        elseif rhythm == "hypothermia_bradycardia" then
            h = getHypothermiaH(phase)
        elseif rhythm == "av_block_partial" then
            h = getAVBlockH(phase, false)
        elseif rhythm == "av_block_complete" then
            h = getAVBlockH(phase, true)
        elseif rhythm == "cerebral_bradycardia" or rhythm == "cerebral_irregular" then
            h = getCerebralH(phase, beatIndex)
        elseif rhythm == "sinus_pause" and beatIndex % 4 == 3 then
            -- Suppressed sinus-node output: a full missed cycle creates the
            -- temporary electrical gap before escape activity takes over.
            h = 0
        elseif rhythm == "extreme_tachycardia" and beatIndex % 5 == 0 then
            h = getWideComplexH(phase)
        else
			h = getSinusH(phase)
            if rhythm == "compressed_tachycardia" then
                -- At this rate the next P wave starts before the prior T wave
                -- has fully settled, visually compressing the P-QRS-T complex.
                if phase > 0.7 and phase < 0.92 then
                    h = h + math.sin((phase - 0.7) / 0.22 * math.pi) * 0.1
                end
            end
        end

        if pvcBeat and rhythm ~= "ventricular_fibrillation" and rhythm ~= "atrial_fibrillation" and rhythm ~= "terminal_tachycardia" then
            h = getPVCH(phase)
        elseif compensatoryPause and rhythm ~= "ventricular_fibrillation" and rhythm ~= "atrial_fibrillation" and rhythm ~= "terminal_tachycardia" then
            h = 0
        end

        local palpitationK = math.Clamp(tonumber(palpitations) or 0, 0, 1)
		palpitationK = palpitationK * math.Clamp((heartbeat - 120) / 100, 0, 1)
        if rhythm ~= "asystole" and rhythm ~= "pea" and rhythm ~= "ventricular_fibrillation" and rhythm ~= "atrial_fibrillation" and palpitationK > 0 then
            h = Lerp(palpitationK, h, getPalpitationH(phase))
        end

        if rhythm == "pea" then
            h = getSinusH(phase) * 0.72
        end

        if rhythm ~= "ventricular_fibrillation" and rhythm ~= "atrial_fibrillation" and rhythm ~= "asystole" then
            if phase > 0.33 and phase < 0.44 then
                h = h - ischemia * 0.12
            elseif phase > 0.45 and phase < 0.65 then
                h = h - math.sin((phase - 0.45) / 0.2 * math.pi) * ischemia * 0.52
            end

            local cold = math.Clamp((35 - temperature) / 6, 0, 1)
            if cold > 0 and phase > 0.33 and phase < 0.42 then
                h = h + math.sin((phase - 0.33) / 0.09 * math.pi) * cold * 0.23
            end

            if tamponade >= 0.55 then
                local qrs = (phase > 0.2 and phase < 0.32)
                    or ((rhythm == "ventricular_escape" or rhythm == "terminal_tachycardia") and phase > 0.08 and phase < 0.58)
                    or (rhythm == "hypothermia_bradycardia" and phase > 0.29 and phase < 0.59)
                if qrs then h = h * (beatIndex % 2 == 0 and 1 or Lerp(tamponade, 1, 0.45)) end
            end
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
        state.points[math.floor(p)] = getH(p_phase, p / width)
    end

    -- Clear a small gap ahead of the sweepPos
    local gap = 12
    for i = 1, gap do
        state.points[math.floor((state.sweepPos + i) % width)] = nil
    end

    -- Draw the buffered points
    local startX = centerX - width / 2
    local lastX, lastY

    local function drawSegment(sx, sy, slastX, slastY, thickness)
        if not slastX then return end

        -- Native lines preserve diagonal strokes instead of building a QRS
        -- complex from vertical rectangles. Add parallel passes for the soft
        -- shadow without relying on polygon rendering in HUDPaint.
        if thickness > 2 then
            surface.DrawLine(slastX, slastY - 1, sx, sy - 1)
            surface.DrawLine(slastX - 1, slastY, sx - 1, sy)
            surface.DrawLine(slastX + 1, slastY, sx + 1, sy)
            surface.DrawLine(slastX, slastY + 1, sx, sy + 1)
        end
        surface.DrawLine(slastX, slastY, sx, sy)
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
        drawSegment(x, y, lastX, lastY, thick + 2)

        -- Draw Main Line
        surface.SetDrawColor(color.r, color.g, color.b, currentAlpha)
        drawSegment(x, y, lastX, lastY, thick)

        lastX, lastY = x, y
    end
end

-- Spectator and other medical HUDs use the same rhythm renderer so new server
-- ECG states cannot silently fall back to the old high-rate/low-pulse sinewave.
hg = hg or {}
hg.DrawOrganismECG = DrawEKG
hg.IsOrganismCirculationCritical = IsCirculationCritical

hook.Add("HUDPaint", "DrawUnconsciousRing", function()
    if not hg_unconsciousring:GetBool() then
        if hg then hg.healthAlarmActive = false end
        ringAlpha = 0
        lastPhaseMod = 0
        ResetRingAudio()
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        if hg then hg.healthAlarmActive = false end
        ringAlpha = 0
        unconsciousStartTime = nil
        lastPhaseMod = 0
        ResetRingAudio()
        return
    end
    
    local org = ply.organism
    if not org then 
        if hg then hg.healthAlarmActive = false end
        ringAlpha = 0
        unconsciousStartTime = nil
        lastPhaseMod = 0
        ResetRingAudio()
        return 
    end
    
	local isUnconscious = org.otrub
	if isUnconscious and not wasUnconsciousState then
		unconsciousStartTime = CurTime()
		ringAlpha = 0
		wakeEstimateAnchor = 0
		wakeEstimateSmoothed = nil
	elseif not isUnconscious and wasUnconsciousState then
		unconsciousStartTime = nil
		wakeEstimateAnchor = 0
		wakeEstimateSmoothed = nil
    end

    local heartbeat = org.heartbeat or 75
    local ecgState = org.ecgState or "normal_sinus"
    local brain = org.brain or 0
    local brainHemorrhage = org.brainHemorrhage or 0
    local consciousness = org.consciousness or 0
    local replicatedOrg = ply.new_organism or org
    local incapacitated = replicatedOrg.incapacitated or org.incapacitated or false
    local deathStateEnd = tonumber(replicatedOrg.deathStateEnd or org.deathStateEnd)
    local incapacitationProgress = 0
    if isUnconscious and incapacitated and deathStateEnd and deathStateEnd > CurTime() then
        local remaining = math.max(deathStateEnd - CurTime(), 0)
        incapacitationProgress = math.Clamp((INCAPACITATION_DEATH_TIME - remaining) / INCAPACITATION_DEATH_TIME, 0, 1)
    end
    local incapacitationWhite = math.ease.InOutSine(incapacitationProgress)
    local isCritical = (org.critical == true)
        or (ecgState == "asystole" and brain >= 0.02)
        or IsCirculationCritical(org)
        or IsVentricularFibrillation(org)
        or (brain > 0.4)
        or (brainHemorrhage >= 0.4)
        or (tonumber(org.brainSwelling) or 0) >= 0.45
    local admiring = ply:GetNWBool("mcd_admiring", false) and not ply.mcd_admire_local_cancel
    fibrillationRequested = false
    fibrillationVolume = 0

    -- Allow a new flatline only after the heart has actually recovered.
    if ecgState ~= "asystole" and wasHeartbeatZero then
        flatlinePlayedThisLife = false
    end
    wasHeartbeatZero = ecgState == "asystole"

    -- Asystole can happen while awake. Play its cue once, independent of
    -- whether the unconscious-ring UI is currently visible.
    if ecgState == "asystole" and not flatlinePlayedThisLife and not (hg_unconsciousclassic and hg_unconsciousclassic:GetBool()) then
        EmitRingSound(SOUND_FLATLINE, 1.0)
        flatlinePlayedThisLife = true
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
        or (org.hypotension and org.hypotension > 0.55)
        or IsCirculationCritical(org)
        or IsVentricularFibrillation(org)
        or (org.hemothorax and org.hemothorax > 0.55)
        or (org.cardiacTamponade and org.cardiacTamponade > 0.4)
        or brainHemorrhage >= 0.25
        or (org.brainSwelling and org.brainSwelling >= 0.35)
        or (heartbeat < 30 or heartbeat > 170)
    
    local healthAlarmActive = ply:Alive() and not isUnconscious and isNearDeathClass and isInBadHealth
    if hg then hg.healthAlarmActive = healthAlarmActive end

    if not healthAlarmActive then
        if alertPlayed then
            if IsValid(alertSound) then alertSound:Stop() end
            alertPlayed = false
            alertSound = nil
        end
    elseif not alertPlayed then
        sound.PlayFile("sound/health/alert.mp3", "noblock noplay", function(s)
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
    local pulse = math.max(tonumber(org.pulse) or heartbeat, 0)
    local abnormalPulse = (heartbeat < 40 and heartbeat >= 1) or heartbeat > 100
    local severeMechanicalPulse = (pulse > 0 and pulse < 45) or pulse > 125
    local abnormalECG = ecgState ~= "normal_sinus"
    local sinusECGTail = UpdateECGStateAlert(ecgState)
    local showAwakeECG = not isUnconscious and not lowConsciousness
        and (abnormalECG or severeMechanicalPulse or sinusECGTail > 0 or admiring)
    
	local unconsciousElapsed = isUnconscious and (CurTime() - (unconsciousStartTime or CurTime())) or 0
	if isUnconscious and unconsciousElapsed >= UNCONSCIOUS_RING_DELAY then
        ringAlpha = SmoothAlpha(ringAlpha, 1, 1.5)
        dotBeat = math.floor(CurTime()) % 3
	elseif isUnconscious then
		ringAlpha = SmoothAlpha(ringAlpha, 0, 8)
    elseif lowConsciousness then
        ringAlpha = SmoothAlpha(ringAlpha, 0.4, 3)
        dotBeat = math.floor(CurTime()) % 3
    else
        ringAlpha = SmoothAlpha(ringAlpha, 0, 4)
        if ringAlpha <= 0.01 and not showAwakeECG then
            ringAlpha = 0
                centerEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
            lastPhaseMod = 0
            ResetRingAudio()
        end
    end
    wasUnconsciousState = isUnconscious

    -- Active non-sinus rhythms remain visible. Severity now increases opacity;
    -- a recovered sinus trace gets a short tail and then fades away.
    if showAwakeECG then
        local severity = abnormalECG and GetAwakeECGSeverity(ecgState) or 0
        local awakeECGTargetAlpha = abnormalECG and Lerp(severity, 0.28, 0.92) or (severeMechanicalPulse and 0.45 or (0.22 * sinusECGTail))

        if admiring then awakeECGTargetAlpha = math.max(awakeECGTargetAlpha, 0.24) end
        if ply:KeyDown(IN_ATTACK2) then awakeECGTargetAlpha = awakeECGTargetAlpha * 0.65 end
        awakeECGAlpha = SmoothAlpha(awakeECGAlpha, awakeECGTargetAlpha, 5)
    else
        awakeECGAlpha = SmoothAlpha(awakeECGAlpha, 0, 3)
    end
    
    local showPulseCheckECG = false

    local isCheckingPulse = false
    if IsValid(g_PulseCheckTarget) then
        local wep = ply:GetActiveWeapon()
        local isHandsWeapon = IsValid(wep) and (wep:GetClass() == "weapon_hands_sh" or wep:GetClass() == "weapon_hg_coolhands")
        if isHandsWeapon and wep.GetCarrying and IsValid(wep:GetCarrying()) and wep:GetCarrying() == g_PulseCheckTarget then
            isCheckingPulse = true
        else
            g_PulseCheckTarget = nil
        end
    end

    if isCheckingPulse then
        showPulseCheckECG = true
    end

    -- Determine if we should show otrub ECG (for unconscious or awake with abnormal heartbeat/admiring/recent sudden drop)

    if ringAlpha <= 0 and awakeECGAlpha <= 0.01 and not showPulseCheckECG then
        UpdateFibrillationSound()
        return
    end
    local otrubECGAlpha = (isUnconscious or lowConsciousness) and ringAlpha or awakeECGAlpha
    local incapPromptX, incapPromptY
    
    if otrubECGAlpha > 0.01 then
        local scrW, scrH = ScrW(), ScrH()
        local boxScale = math.Clamp(scrH / 1080, 0.75, 1.2)
        local centerX, centerY = scrW * 0.5, scrH * 0.5
        local ecgCenterY = centerY - math.min(scrH * 0.1, ScreenScaleH(92)) * incapacitationWhite
        local showLegacyECG = abnormalECG
            or (not isUnconscious and not lowConsciousness and (sinusECGTail > 0 or admiring))

        if isUnconscious or lowConsciousness then
            local _, wakeProgress = UpdateWakeEstimate(org)
            local ringColor = isCritical
                and Color(210, 35, 30, 255 * ringAlpha)
                or Color(220, 220, 220, 255 * ringAlpha)
            local radius = math.min(280, scrH * 0.32)
            incapPromptX = centerX
            incapPromptY = math.min(centerY + radius + ScreenScaleH(18), scrH - ScreenScaleH(30))

            surface.SetDrawColor(0, 0, 0, 90 * ringAlpha)
            surface.DrawRect(0, 0, scrW, scrH)
            DrawArc(centerX, centerY, radius, 12, 0, 360, 60,
                Color(40, 40, 40, 100 * ringAlpha))
            DrawArc(centerX, centerY, radius, 12, 90, 90 - wakeProgress * 360, 80, ringColor)

            if hg_unconsciousclassic and hg_unconsciousclassic:GetBool() then
                lastPhaseMod = 0
                local dotText = isCritical and ({".!", "..!", "...!"})[dotBeat + 1]
                    or ({".", "..", "..."})[dotBeat + 1]
                draw.SimpleText(dotText, "UnconsciousDots", centerX, centerY,
                    ringColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            UpdateRingAudio(heartbeat, ringAlpha, org, admiring)
        end

        if showLegacyECG and not (hg_unconsciousclassic and hg_unconsciousclassic:GetBool()) then
            local severity = GetAwakeECGSeverity(ecgState)
            local ecgR = abnormalECG and Lerp(severity, 220, 255) or 230
            local ecgG = abnormalECG and Lerp(severity, 220, 50) or 230
            local ecgB = abnormalECG and Lerp(severity, 220, 40) or 230
            local ecgColor = Color(
                Lerp(incapacitationWhite, ecgR, abnormalECG and 70 or 24),
                Lerp(incapacitationWhite, ecgG, abnormalECG and 12 or 24),
                Lerp(incapacitationWhite, ecgB, abnormalECG and 10 or 24),
                255 * otrubECGAlpha
            )
            DrawEKG(centerEKGState, centerX, ecgCenterY, 540, 140, org, ecgColor, otrubECGAlpha)
        end
    end

    if isUnconscious and incapacitated and deathStateEnd and deathStateEnd > CurTime() then
        local remaining = math.max(deathStateEnd - CurTime(), 0)
        local seconds = math.max(math.ceil(remaining), 0)
        local fade = math.Clamp((INCAPACITATION_DEATH_TIME - remaining) / 1.25, 0, 1)
        local urgency = math.Clamp((5 - remaining) / 5, 0, 1)
        local pulseAlpha = 0.82 + math.abs(math.sin(CurTime() * 6)) * 0.18 * urgency
        local promptBase = Lerp(incapacitationWhite, 235, 24)
        local promptColor = Color(
            Lerp(urgency, promptBase, Lerp(incapacitationWhite, 235, 90)),
            Lerp(urgency, promptBase, Lerp(incapacitationWhite, 55, 12)),
            Lerp(urgency, promptBase, Lerp(incapacitationWhite, 45, 10)),
            245 * fade * pulseAlpha
        )
        local promptOutline = Lerp(incapacitationWhite, 0, 255)

        if not incapPromptX then
            local radius = math.min(280, ScrH() * 0.32)
            incapPromptX = ScrW() * 0.5
            incapPromptY = math.min(ScrH() * 0.5 + radius + ScreenScaleH(18), ScrH() - ScreenScaleH(30))
        end

        draw.SimpleTextOutlined(
            "You are incapacitated - death in " .. seconds .. "s",
            "OtrubCriticalMessage",
            incapPromptX,
            incapPromptY,
            promptColor,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP,
            2,
            Color(promptOutline, promptOutline, promptOutline, 220 * fade)
        )
    end

    if showPulseCheckECG then
        ecgAlphaPulseCheck = Lerp(FrameTime() * 4, ecgAlphaPulseCheck, 1)
    else
        ecgAlphaPulseCheck = Lerp(FrameTime() * 6, ecgAlphaPulseCheck, 0)
    end

    if ecgAlphaPulseCheck > 0.01 then
        if not IsValid(g_PulseCheckTarget) then
            g_PulseCheckTarget = nil
            pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
            ecgAlphaPulseCheck = 0
        else
            local boxW, boxH = 300, 150
            local boxX, boxY = ScrW() / 2 - boxW / 2, ScrH() - boxH - 60
            local handBone = ply:LookupBone("ValveBiped.Bip01_L_Hand") or ply:LookupBone("ValveBiped.Bip01_R_Hand")
            local handMatrix = handBone and ply:GetBoneMatrix(handBone)
            if handMatrix then
                local handScreen = handMatrix:GetTranslation():ToScreen()
                if handScreen.visible then
                    boxX = math.Clamp(handScreen.x - boxW / 2, 10, ScrW() - boxW - 10)
                    boxY = math.Clamp(handScreen.y - boxH - 36, 10, ScrH() - boxH - 10)
                end
            end

            surface.SetDrawColor(0, 0, 0, 150 * ecgAlphaPulseCheck)
            surface.DrawRect(boxX, boxY, boxW, boxH)
            surface.SetDrawColor(255, 255, 255, 200 * ecgAlphaPulseCheck)
            surface.DrawOutlinedRect(boxX, boxY, boxW, boxH)

            local target_org = g_PulseCheckTarget.organism or {}
            local target_brain = target_org.brain or 0
            local target_hemorrhage = target_org.brainHemorrhage or 0
            local target_isCritical = (target_org.critical == true)
                or IsCirculationCritical(target_org)
                or IsVentricularFibrillation(target_org)
                or (target_brain > 0.4)
                or (target_hemorrhage >= 0.4)
                or (tonumber(target_org.brainSwelling) or 0) >= 0.45
            if IsVentricularFibrillation(target_org) then
                RequestFibrillationSound(GetHeartbeatVolume(target_org))
            end

            local targetECGColor = target_isCritical and Color(200, 0, 0, 255) or Color(255, 255, 255, 255)
            DrawEKG(pulseCheckEKGState, boxX + boxW / 2, boxY + boxH * 0.52, boxW - 20, boxH - 28, target_org, targetECGColor, ecgAlphaPulseCheck)
        end
    else
        pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
    end


    local abnormalPulse = (heartbeat < 40 and heartbeat >= 1) or heartbeat > 100 or severeMechanicalPulse
    if IsVentricularFibrillation(org) and (admiring or isUnconscious or abnormalPulse or isCheckingPulse) then
        RequestFibrillationSound(GetHeartbeatVolumeAdmiring(org, admiring))
    end
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

                    local mechanicalStrength = GetMechanicalPulseStrength(org)
                    local vol = GetHeartbeatVolumeAdmiring(org, admiring) * mechanicalStrength
                    local hasHealthHUD = (className == "Gordon" or className == "Combine" or className == "furry")
                    local highStress = vol > 0.5
                    local fibrillating = IsVentricularFibrillation(org)
                    if (abnormalPulse and hasHealthHUD) or highStress or admiring then
                        if fibrillating then
                            if hg and hg.healthAlarmActive then
                                EmitRingSound(SOUND_HEALTH_ALARM, vol)
                            else
                                RequestFibrillationSound(vol)
                            end
                        elseif mechanicalStrength > 0.02 then
                            EmitRingSound(hg and hg.healthAlarmActive and SOUND_HEALTH_ALARM or SOUND_HEART, vol * CRITBEAT_VOLUME_SCALE)
                        end
                    elseif mechanicalStrength > 0.02 then
                        EmitRingSound(hg and hg.healthAlarmActive and SOUND_HEALTH_ALARM or "sound/heartbeat/heartbeat_single.ogg", vol)
                    end
                end
            end
        end
    end

    -- Critical-beats is only for fibrillation. As soon as the local heart is
    -- asystolic, clear any request so the existing fade-out branch runs.
    if ecgState == "asystole" then
        fibrillationRequested = false
        fibrillationVolume = 0
    end
    UpdateFibrillationSound()
    
    if healthAlarmActive then
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
            draw.SimpleText(msg, font, ScrW() / 2, ScrH() * 0.2, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end


end)
