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

local ringAlpha = 0
local dotBeat = 0

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
local SOUND_HEART = "health/critbeat.ogg"
local SOUND_HEALTH_ALARM = "health/healthbeat.ogg"
local SOUND_FLATLINE = "health/gg.ogg"
local SOUND_FIBRILLATION = "criticalbeats.ogg"
local CRITBEAT_VOLUME_SCALE = 0.6

local lastPhaseMod = 0
local wasUnconsciousState = false
local unconsciousStartTime
local UNCONSCIOUS_RING_DELAY = 1
local WAKE_CONSCIOUSNESS_THRESHOLD = 0.3
local OTRUB_CONSCIOUSNESS_RECOVERY_SPEED = 20
local OTRUB_SHOCK_DECAY_PER_SECOND = 4
local OTRUB_PAIN_DRAIN_PER_SECOND = 8 * 4.5
local wakeEstimateAnchor = 0
local wakeEstimateSmoothed

local function GetOxygenLevel(org)
    return istable(org.o2) and (org.o2[1] or 100) or 100
end

local function EstimateWakeSeconds(org)
    local oxygen = GetOxygenLevel(org)
    local cannotWake = org.incapacitated
        or org.heartstop
        or (org.blood or 5000) <= 2500
        or (org.pulse or 70) < 15
        or oxygen < 7
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
local hg_simpleecg = CreateClientConVar("hg_simpleecg", "1", true, false, "Use the compact ECG below the health indicator", 0, 1)

local function GetHeartbeatVolume(org)
    if not org then return 0.2 end
    local hurt = math.Clamp((5000 - (org.blood or 5000)) / 5000, 0, 1) * 0.4
         + math.Clamp((org.pain or 0) / 100, 0, 1) * 0.4
         + math.Clamp(org.brain or 0, 0, 1) * 0.2
         + math.Clamp(org.brainHemorrhage or 0, 0, 1) * 0.2
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
local function UpdateRingAudio(pulse, ringAlpha, org, admiring)
    if pulse < 1 or ringAlpha <= 0 then return end

    local prev = lastPhaseMod
    local curr = (lastPhaseMod + FrameTime() * (pulse / 60)) % 1
    lastPhaseMod = curr

    local beatVolume = GetHeartbeatVolumeAdmiring(org, admiring) * ringAlpha
    local fibrillating = pulse > 250
    if fibrillating then
        RequestFibrillationSound(beatVolume)
    end
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

        if fibrillating and hg and hg.healthAlarmActive then
            EmitRingSound(SOUND_HEALTH_ALARM, beatVolume)
        elseif not fibrillating and (abnormalPulse or highStress) then
            EmitRingSound(hg and hg.healthAlarmActive and SOUND_HEALTH_ALARM or SOUND_HEART, beatVolume * CRITBEAT_VOLUME_SCALE)
        elseif not fibrillating then
            EmitRingSound(hg and hg.healthAlarmActive and SOUND_HEALTH_ALARM or "sound/heartbeat/heartbeat_single.wav", beatVolume)
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

local function DrawEKG(state, centerX, centerY, width, height, heartbeat, pulse, ecgState, palpitations, color, ringAlpha)
    local time = CurTime()
    if state.lastUpdate == 0 then state.lastUpdate = time end
    local dt = time - state.lastUpdate
    state.lastUpdate = time

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

    local function getAtrialFibrillationH(phase, beatIndex)
        -- No organized P waves; coarse fibrillatory baseline with irregular,
        -- variably shaped ventricular complexes.
        local h = math.sin((phase * 13 + beatIndex * 0.37) * math.pi * 2) * 0.055
        local qrsStart = beatIndex % 3 == 0 and 0.31 or 0.22
        if phase > qrsStart and phase < qrsStart + 0.12 then
            h = h + getSinusH((phase - qrsStart + 0.2) * 2.5)
        end
        return h
    end

    local function getVentricularFibrillationH(phase, beatIndex)
        -- Chaotic electrical activity with no pulse-producing QRS complexes.
        return math.sin((phase * 9 + beatIndex * 0.63) * math.pi * 2) * 0.38
            + math.sin((phase * 17 + beatIndex * 0.19) * math.pi * 2) * 0.16
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

    local function getH(rawPhase)
        local rhythm = ecgState or "normal_sinus"
        if rhythm == "asystole" or heartbeat < 1 then return 0 end

        local phase = rawPhase % 1
        local beatIndex = math.floor(rawPhase)
        local h

        if rhythm == "ventricular_fibrillation" then
            h = getVentricularFibrillationH(phase, beatIndex)
        elseif rhythm == "atrial_fibrillation" then
            h = getAtrialFibrillationH(phase, beatIndex)
        elseif rhythm == "ventricular_escape" or rhythm == "terminal_tachycardia" then
            h = getWideComplexH(phase)
        elseif rhythm == "ventricular_ectopy" and beatIndex % 4 == 3 then
            h = getWideComplexH(phase)
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

        local palpitationK = math.Clamp(tonumber(palpitations) or 0, 0, 1)
		palpitationK = palpitationK * math.Clamp((heartbeat - 120) / 100, 0, 1)
        if rhythm ~= "asystole" and rhythm ~= "pea" and rhythm ~= "ventricular_fibrillation" and palpitationK > 0 then
            h = Lerp(palpitationK, h, getPalpitationH(phase))
        end

        if rhythm == "pea" then
            h = getSinusH(phase) * 0.18
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

local function GetRecoveryColor(progress, alpha)
    progress = math.Clamp(progress or 0, 0, 1)
    local r, g, b
    if progress < 0.5 then
        local stage = progress / 0.5
        r, g, b = Lerp(stage, 210, 235), Lerp(stage, 55, 155), Lerp(stage, 45, 55)
    else
        local stage = (progress - 0.5) / 0.5
        r, g, b = Lerp(stage, 235, 120), Lerp(stage, 155, 220), Lerp(stage, 55, 165)
    end
    return Color(r, g, b, 255 * alpha)
end

local function FormatWakeEstimate(seconds)
    if not seconds then return "UNSTABLE" end
    if seconds <= 1 then return "WAKING" end
    if seconds >= 600 then return "WAKING >10m" end
    if seconds >= 60 then
        return string.format("WAKING ~%dm %02ds", math.floor(seconds / 60), math.ceil(seconds) % 60)
    end
    return string.format("WAKING ~%ds", math.ceil(seconds))
end

local function DrawECGStatusBox(x, y, w, h, borderInset, color, alpha, statusText, ecgState)
    surface.SetDrawColor(0, 0, 0, 165 * alpha)
    surface.DrawRect(x, y, w, h)

    surface.SetDrawColor(45, 45, 45, 155 * alpha)
    surface.DrawOutlinedRect(x, y, w, h)

    local inset = math.Clamp(borderInset or 0, 0, math.min(w, h) * 0.2)
    surface.SetDrawColor(color.r, color.g, color.b, color.a)
    for thickness = 0, 1 do
        surface.DrawOutlinedRect(x + inset + thickness, y + inset + thickness,
            w - (inset + thickness) * 2, h - (inset + thickness) * 2)
    end

    draw.SimpleText(statusText, "HomigradFontTypewriterSmall", x + 10, y + 7, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    local rhythmText = string.upper(string.gsub(ecgState or "normal_sinus", "_", " "))
    draw.SimpleText(rhythmText, "HomigradFontTypewriterSmall", x + w - 10, y + 7,
        Color(220, 220, 220, 210 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

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
    local pulse = org.pulse or 70
    local ecgState = org.ecgState or "normal_sinus"
    local brain = org.brain or 0
    local brainHemorrhage = org.brainHemorrhage or 0
    local consciousness = org.consciousness or 0
    local isCritical = (org.critical == true) or (heartbeat < 1 and brain >= 0.02) or (brain > 0.4) or (brainHemorrhage >= 0.4)
    local admiring = ply:GetNWBool("mcd_admiring", false) and not ply.mcd_admire_local_cancel
    fibrillationRequested = false
    fibrillationVolume = 0

    -- Allow a new flatline only after the heart has actually recovered.
    if heartbeat >= 1 and wasHeartbeatZero then
        flatlinePlayedThisLife = false
    end
    wasHeartbeatZero = heartbeat < 1

    -- Asystole can happen while awake. Play its cue once, independent of
    -- whether the unconscious-ring UI is currently visible.
    if heartbeat < 1 and not flatlinePlayedThisLife and not (hg_unconsciousclassic and hg_unconsciousclassic:GetBool()) then
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
        or (org.bloodpressure and org.bloodpressure < 50)
        or brainHemorrhage >= 0.25
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
    local abnormalPulse = (heartbeat < 40 and heartbeat >= 1) or heartbeat > 100
    local abnormalECG = ecgState ~= "normal_sinus"
    local sinusECGTail = UpdateECGStateAlert(ecgState)
    local showAwakeECG = not isUnconscious and not lowConsciousness
        and (abnormalECG or sinusECGTail > 0 or admiring)
    
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
        local awakeECGTargetAlpha = abnormalECG and Lerp(severity, 0.28, 0.92)
            or (0.22 * sinusECGTail)

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
    
    if otrubECGAlpha > 0.01 then
        local scrW, scrH = ScrW(), ScrH()
        local boxScale = math.Clamp(scrH / 1080, 0.75, 1.2)
        local simpleECG = hg_simpleecg:GetBool()
        local boxW = (simpleECG and 300 or 360) * boxScale
        local boxH = (simpleECG and 100 or 150) * boxScale
        local edgeMargin = 24 * boxScale
        local boxX, boxY = scrW - boxW - edgeMargin, scrH - boxH - edgeMargin

        if simpleECG then
            local indicator = HUD and HUD.dynamicIndicator
            if indicator and indicator.active then
                boxX = indicator.x
                boxY = math.Clamp(indicator.y + indicator.h + 10 * boxScale,
                    edgeMargin, scrH - boxH - edgeMargin)
            else
                boxX = edgeMargin
                boxY = math.Clamp(scrH * 0.5 + 120 * boxScale,
                    edgeMargin, scrH - boxH - edgeMargin)
            end

            surface.SetDrawColor(0, 0, 0, 130 * otrubECGAlpha)
            surface.DrawRect(boxX, boxY, boxW, boxH)
            surface.SetDrawColor(110, 125, 120, 120 * otrubECGAlpha)
            surface.DrawOutlinedRect(boxX, boxY, boxW, boxH)
        end

        local traceCenterY = simpleECG and (boxY + boxH * 0.5) or (boxY + boxH * 0.62)
        local traceWidth = simpleECG and (boxW - 16 * boxScale) or (boxW - 28 * boxScale)
        local traceHeight = simpleECG and (boxH - 16 * boxScale) or (boxH - 52 * boxScale)
        
        if isUnconscious or lowConsciousness then
            local wakeSeconds, wakeProgress = UpdateWakeEstimate(org)
            local borderInset = (1 - wakeProgress) * 14 * boxScale
            local statusText = FormatWakeEstimate(wakeSeconds)
            local statusColor = GetRecoveryColor(wakeProgress, otrubECGAlpha)

            if not wakeSeconds then
                borderInset = (8 + math.sin(CurTime() * 2) * 2) * boxScale
                statusColor = Color(220, 45, 40, 255 * otrubECGAlpha)
                statusText = "UNSTABLE"
            elseif lowConsciousness and not isUnconscious then
                wakeProgress = math.Clamp(consciousness / 0.4, 0, 1)
                borderInset = (1 - wakeProgress) * 14 * boxScale
                statusColor = GetRecoveryColor(wakeProgress, otrubECGAlpha)
                statusText = "CONSCIOUSNESS FALLING"
            end

            if not simpleECG then
                DrawECGStatusBox(boxX, boxY, boxW, boxH, borderInset, statusColor,
                    otrubECGAlpha, statusText, ecgState)
            end

            if not simpleECG and hg_unconsciousclassic and hg_unconsciousclassic:GetBool() then
                lastPhaseMod = 0
                local dotText = isCritical and ({".!", "..!", "...!"})[dotBeat + 1]
                    or ({".", "..", "..."})[dotBeat + 1]
                draw.SimpleText(dotText, "UnconsciousDots", boxX + boxW / 2, boxY + boxH / 2 + 8,
                    statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                UpdateRingAudio(heartbeat, otrubECGAlpha, org, admiring)
                DrawEKG(centerEKGState, boxX + boxW / 2, traceCenterY,
                    traceWidth, traceHeight, heartbeat, pulse, ecgState,
                    org.palpitations, statusColor, otrubECGAlpha)
            end
        else
            local severity = abnormalECG and GetAwakeECGSeverity(ecgState) or 0
            local awakeColor = abnormalECG
                and Color(Lerp(severity, 205, 255), Lerp(severity, 220, 55), Lerp(severity, 205, 45), 255 * otrubECGAlpha)
                or Color(205, 225, 215, 255 * otrubECGAlpha)
            local borderInset = severity * 10 * boxScale
            local statusText = abnormalECG and "RHYTHM ALERT" or "SINUS RHYTHM"

            if not simpleECG then
                DrawECGStatusBox(boxX, boxY, boxW, boxH, borderInset, awakeColor,
                    otrubECGAlpha, statusText, ecgState)
            end
            DrawEKG(centerEKGState, boxX + boxW / 2, traceCenterY,
                traceWidth, traceHeight, heartbeat, pulse, ecgState,
                org.palpitations, awakeColor, otrubECGAlpha)
        end
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
            local target_heartbeat = target_org.heartbeat or 75
            local target_pulse = target_org.pulse or 70
            local target_ecgState = target_org.ecgState or "normal_sinus"
            local target_bp = target_org.bloodpressure or 93
            local target_brain = target_org.brain or 0
            local target_hemorrhage = target_org.brainHemorrhage or 0
            local target_isCritical = (target_org.critical == true) or (target_heartbeat < 1 and target_brain >= 0.02) or (target_brain > 0.4) or (target_hemorrhage >= 0.4)
            if target_heartbeat > 250 then
                RequestFibrillationSound(GetHeartbeatVolume(target_org))
            end

            local targetECGColor = target_isCritical and Color(200, 0, 0, 255) or Color(255, 255, 255, 255)
            DrawEKG(pulseCheckEKGState, boxX + boxW / 2, boxY + boxH / 2, boxW - 20, boxH - 20, target_heartbeat, target_pulse, target_ecgState, target_org.palpitations, targetECGColor, ecgAlphaPulseCheck)
        end
    else
        pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
    end


    local abnormalPulse = (heartbeat < 40 and heartbeat >= 1) or heartbeat > 100
    if heartbeat > 250 and (admiring or isUnconscious or abnormalPulse or isCheckingPulse) then
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

                    local vol = GetHeartbeatVolumeAdmiring(org, admiring)
                    local hasHealthHUD = (className == "Gordon" or className == "Combine" or className == "furry")
                    local highStress = vol > 0.5
                    local fibrillating = heartbeat > 250
                    if (abnormalPulse and hasHealthHUD) or highStress or admiring then
                        if fibrillating then
                            if hg and hg.healthAlarmActive then
                                EmitRingSound(SOUND_HEALTH_ALARM, vol)
                            else
                                RequestFibrillationSound(vol)
                            end
                        else
                            EmitRingSound(hg and hg.healthAlarmActive and SOUND_HEALTH_ALARM or SOUND_HEART, vol * CRITBEAT_VOLUME_SCALE)
                        end
                    else
                        EmitRingSound(hg and hg.healthAlarmActive and SOUND_HEALTH_ALARM or "sound/heartbeat/heartbeat_single.wav", vol)
                    end
                end
            end
        end
    end

    -- Critical-beats is only for fibrillation. As soon as the local heart is
    -- asystolic, clear any request so the existing fade-out branch runs.
    if heartbeat < 1 then
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
