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

surface.CreateFont("HomigradFontTypewriterSmall", {
    font = "Veteran Typewriter",
    size = ScreenScaleH(12),
    weight = 800,
    antialias = true,
    shadow = true
})

local ringAlpha = 0
local lerpBrain = 0
local lerpBrainHemorrhage = 0
local lerpShock = 0
local lerpConsciousness = 0
local peakShock = 40
local dotBeat = 0

local function GetShockConsciousnessThreshold(analgesia)
    return 40 + math.Clamp(analgesia or 0, 0, 1) * 30
end

local dyingRingServerEnd
local dyingRingLocalEnd

local function GetDyingRingTimeLeft(deathStateStart, deathStateEnd)
	if not deathStateEnd then
		dyingRingServerEnd = nil
		dyingRingLocalEnd = nil
		return
	end

	if dyingRingServerEnd ~= deathStateEnd then
		local duration = math.Clamp(deathStateEnd - (deathStateStart or deathStateEnd - 20), 0, 20)
		dyingRingServerEnd = deathStateEnd
		dyingRingLocalEnd = CurTime() + duration
	end

	return math.max((dyingRingLocalEnd or CurTime()) - CurTime(), 0)
end

local ecgAlphaPulseCheck = 0
local awakeECGAlpha = 0
local lastHeartBeat = 0
local heartPhase = 0

local awakeECGSeverityByState = {
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

-- Better sound system from oldring
local SOUND_HEART = "health/critbeat.ogg"
local SOUND_FLATLINE = "health/gg.ogg"
local SOUND_FIBRILLATION = "criticalbeats.ogg"
local CRITBEAT_VOLUME_SCALE = 0.6

local lastPhaseMod = 0
local wasUnconsciousState = false
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
local hg_3dzity = GetConVar("hg_3dzity") or CreateClientConVar("hg_3dzity", "1", true, false, "Toggle 3D UI for containers and medical sweps", 0, 1)

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

        if not fibrillating and (abnormalPulse or highStress) then
            EmitRingSound(SOUND_HEART, beatVolume * CRITBEAT_VOLUME_SCALE)
        elseif not fibrillating then
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

local function DrawEKG(state, centerX, centerY, width, height, heartbeat, pulse, ecgState, color, ringAlpha)
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
	local scavDyingMode = GetConVar("hg_scavdying") and GetConVar("hg_scavdying"):GetInt() or 0
	local deathStateEnd = org.deathStateEnd and org.deathStateEnd > 0 and org.deathStateEnd or nil
	local deathStateStart = org.deathStateStart and org.deathStateStart > 0 and org.deathStateStart or nil
	local deathStatePendingEnd = org.deathStatePendingEnd and org.deathStatePendingEnd > 0 and org.deathStatePendingEnd or nil
	local deathStateFadeStart = org.deathStateFadeStart and org.deathStateFadeStart > 0 and org.deathStateFadeStart or nil
	local hideDyingRing = org.incapacitated and scavDyingMode == 0 and (deathStateEnd or (deathStateFadeStart and CurTime() >= deathStateFadeStart))
    local heartbeat = org.heartbeat or 75
    local pulse = org.pulse or 70
    local ecgState = org.ecgState or "normal_sinus"
    local brain = org.brain or 0
    local brainHemorrhage = org.brainHemorrhage or 0
    local bloodpressure = org.bloodpressure or 93
    local consciousness = org.consciousness or 0
    local shock = org.shock or 0
    local isCritical = (org.critical == true) or (heartbeat < 1 and brain >= 0.02) or (brain > 0.4) or (brainHemorrhage >= 0.4)
    local admiring = ply:GetNWBool("mcd_admiring", false) and not ply.mcd_admire_local_cancel
    fibrillationRequested = false
    fibrillationVolume = 0

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
    local isCritical = (org.critical == true) or (heartbeat < 1 and brain >= 0.02) or (brain > 0.4) or (brainHemorrhage >= 0.4)
    local abnormalPulse = (heartbeat < 40 and heartbeat >= 1) or heartbeat > 100
    local fibrillating = heartbeat > 250
    local isElectricalArrest = org.heartstop or ecgState == "pea" or ecgState == "asystole"
    local abnormalECG = ecgState ~= "normal_sinus"

    local showAwakeECG = not isUnconscious and not lowConsciousness and (abnormalPulse or abnormalECG or admiring or recentSuddenDrop or fibrillating or isCritical or isElectricalArrest)
    
	if isUnconscious and not hideDyingRing then
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
        local awakeECGTargetAlpha = 0.15
        if ply:KeyDown(IN_ATTACK2) then
            -- Keep the sight picture clear: aiming makes the ECG very faint,
            -- with increasingly severe rhythms fading almost completely out.
            awakeECGTargetAlpha = Lerp(GetAwakeECGSeverity(ecgState), 0.07, 0.01)
        end
        awakeECGAlpha = Lerp(FrameTime() * 4, awakeECGAlpha, awakeECGTargetAlpha)
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

    if ringAlpha <= 0 and not showPulseCheckECG and not (abnormalPulse or abnormalECG or admiring or recentSuddenDrop or fibrillating or isCritical or isElectricalArrest) then
        UpdateFibrillationSound()
        return
    end
    local showOtrubECG = isUnconscious or lowConsciousness or recentSuddenDrop or (not isUnconscious and (abnormalPulse or abnormalECG or admiring or fibrillating or isElectricalArrest))

    local otrubECGAlpha = (isUnconscious or lowConsciousness) and ringAlpha or awakeECGAlpha
    
    if otrubECGAlpha > 0.01 then
        lerpBrain = Lerp(FrameTime() * 3, lerpBrain, org.brain or 0)
        lerpBrainHemorrhage = Lerp(FrameTime() * 3, lerpBrainHemorrhage, brainHemorrhage)
        lerpShock = Lerp(FrameTime() * 6, lerpShock, org.shock or 0)
        lerpConsciousness = Lerp(FrameTime() * 3, lerpConsciousness, org.consciousness or 0)
        
        local scrW, scrH = ScrW(), ScrH()
        local centerX, centerY = scrW / 2, scrH / 2
        
        -- Only draw dark background and ring for unconscious players
        if isUnconscious or lowConsciousness then
            surface.SetDrawColor(0, 0, 0, 90 * otrubECGAlpha)
            surface.DrawRect(0, 0, scrW, scrH)
            
			local dyingRing = org.incapacitated and deathStateEnd and scavDyingMode > 0
			local ringColor = (isCritical or dyingRing) and Color(200, 0, 0, 255 * otrubECGAlpha) or Color(220, 220, 220, 255 * otrubECGAlpha)
            local dotColor = isCritical and ringColor or Color(255, 255, 255, 255 * otrubECGAlpha)
            
            local progress = 0
			if dyingRing then
				progress = math.Clamp((GetDyingRingTimeLeft(deathStateStart, deathStateEnd) or 0) / 20, 0, 1)
			elseif isCritical then
                local brainProgress = math.Clamp((0.70 - lerpBrain) / (0.70 - 0.02), 0, 1)
                local hemorrhageProgress = math.Clamp(1 - lerpBrainHemorrhage, 0, 1)
                progress = math.min(brainProgress, hemorrhageProgress)
            else
                local shockLimit = math.max(GetShockConsciousnessThreshold(org.analgesia or 0), 0.02)
                local shockProgress = math.Clamp((shockLimit - lerpShock) / shockLimit, 0, 1)
                local consciousnessProgress = math.Clamp(lerpConsciousness / 0.10, 0, 1)
                progress = math.min(shockProgress, consciousnessProgress)
            end
            
            local radius = 280
            local thickness = 12
            
            DrawArc(centerX, centerY, radius, thickness, 0, 360, 60, Color(40, 40, 40, 100 * otrubECGAlpha))
            DrawArc(centerX, centerY, radius, thickness, 90, 90 - (progress * 360), 80, ringColor)
            
            if hg_unconsciousclassic and hg_unconsciousclassic:GetBool() then
                lastPhaseMod = 0
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
                UpdateRingAudio(heartbeat, otrubECGAlpha, org, admiring)
                DrawEKG(centerEKGState, centerX, centerY, 540, 140, heartbeat, pulse, ecgState, ringColor, otrubECGAlpha)
            end
        else
            -- For awake players with abnormal heartbeat or admiring, just show the ECG line without background/ring
            local ecgColor = isCritical and Color(255, 0, 0, 255 * otrubECGAlpha) or Color(255, 255, 255, 255 * otrubECGAlpha)
            DrawEKG(centerEKGState, centerX, centerY, 540, 140, heartbeat, pulse, ecgState, ecgColor, otrubECGAlpha)
            
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
        if not IsValid(g_PulseCheckTarget) then
            g_PulseCheckTarget = nil
            g_PulseCheckData = nil
            pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
            ecgAlphaPulseCheck = 0
        else
            local boxW, boxH = 400, 200
            local boxX, boxY = ScrW() / 2 - boxW / 2, ScrH() - boxH - 60

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
                                RequestFibrillationSound(vol)
                            elseif abnormalPulse or highStress then
                                EmitRingSound(SOUND_HEART, vol * CRITBEAT_VOLUME_SCALE)
                            else
                                EmitRingSound("sound/heartbeat/heartbeat_single.wav", vol)
                            end
                        end
                    end
                end
            end

            local targetECGColor = target_isCritical and Color(200, 0, 0, 255) or Color(255, 255, 255, 255)
            DrawEKG(pulseCheckEKGState, boxX + boxW / 2, boxY + boxH / 2, boxW - 20, boxH - 20, target_heartbeat, target_pulse, target_ecgState, targetECGColor, ecgAlphaPulseCheck)

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
                            RequestFibrillationSound(vol)
                        else
                            EmitRingSound(SOUND_HEART, vol * CRITBEAT_VOLUME_SCALE)
                        end
                    else
                        EmitRingSound("sound/heartbeat/heartbeat_single.wav", vol)
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


end)

local function GetPulseCheckDisplayText()
    local target = g_PulseCheckTarget
    local data = g_PulseCheckData
    local org = (IsValid(target) and target.organism) or {}
    local heartbeat = org.heartbeat or 70

    if heartbeat < 1 or org.heartstop then
        return "NO PULSE"
    end

    if data then
        if data.completed then
            if type(data.finalBPM) == "number" then
                return data.counted .. " x 6 = " .. data.finalBPM .. " BPM"
            else
                return tostring(data.finalBPM)
            end
        else
            return "Counting: " .. data.counted
        end
    end

    return "PULSE: " .. heartbeat .. " BPM"
end
