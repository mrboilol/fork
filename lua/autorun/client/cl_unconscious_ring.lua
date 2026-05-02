
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

local ringAlpha = 0
local lerpBrain = 0
local lerpShock = 0
local lerpConsciousness = 0
local peakShock = 40
local dotBeat = 0
local flatlinePlayed = false
local flatlineSound

local ecgAlpha = 0
local ecgAlphaPulseCheck = 0
local lastHeartBeat = 0
local beatSound = nil
local critSound = nil
local asystoleSound = nil
local heartPhase = 0

local g_PulseCheckTarget = nil
local g_PulseCheckData = nil
local g_TopLeftECGData = nil

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

local hg_unconsciousring = CreateClientConVar("hg_unconsciousring", "1", true, false, "Enable unconscious ring", 0, 1)
local hg_unconsciousclassic = CreateClientConVar("hg_unconsciousclassic", "0", true, false, "Use classic dots instead of EKG line", 0, 1)

-- Local variables for faster access
local math = math
local surface = surface
local draw = draw
local Color = Color

local centerEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
local topLeftEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
local pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }

local function DrawEKG(state, centerX, centerY, width, height, pulse, color, ringAlpha, bloodpressure)
    local time = CurTime()
    if state.lastUpdate == 0 then state.lastUpdate = time end
    local dt = time - state.lastUpdate
    state.lastUpdate = time
    
    -- Increment heart phase based on pulse
    -- pulse is BPM, so pulse/60 is beats per second
    state.phase = state.phase + dt * (pulse / 60)
    
    local sweepSpeed = width / 4
    local oldSweepPos = state.sweepPos
    state.sweepPos = (state.sweepPos + dt * sweepSpeed) % width

    local amplitudeScale = math.Clamp((bloodpressure or 93) / 93, 0.1, 1.5)

    -- Fill all indices between oldSweepPos and newSweepPos to ensure no gaps
    local function getH(phase, scale)
        phase = phase % 1
        local h = 0
        
        -- P wave: small bump
        if phase > 0.05 and phase < 0.15 then
            h = h + math.sin((phase - 0.05) / 0.1 * math.pi) * 0.12 * scale
        -- QRS complex: the main spike
        elseif phase > 0.2 and phase < 0.32 then
            local p = (phase - 0.2) / 0.12
            if p < 0.15 then -- Q
                h = h - math.sin(p / 0.15 * math.pi) * 0.15 * scale
            elseif p < 0.5 then -- R
                h = h + math.sin((p - 0.15) / 0.35 * math.pi) * 1.0 * scale
            else -- S
                h = h - math.sin((p - 0.5) / 0.5 * math.pi) * 0.25 * scale
            end
        -- T wave: medium bump
        elseif phase > 0.45 and phase < 0.65 then
            h = h + math.sin((phase - 0.45) / 0.2 * math.pi) * 0.22 * scale
        end
        
        return h
    end

    local steps = math.max(1, math.floor(math.abs(state.sweepPos - oldSweepPos)))
    if state.sweepPos < oldSweepPos then steps = math.max(1, math.floor(width - oldSweepPos + state.sweepPos)) end

    for i = 0, steps do
        local p = (oldSweepPos + i) % width
        -- Interpolate heartPhase for this specific pixel
        local p_phase = state.phase - (dt * (pulse / 60) * (1 - i/steps))
        state.points[math.floor(p)] = getH(p_phase, amplitudeScale)
    end
    
    -- Clear a small gap ahead of the sweepPos
    local gap = 12
    for i = 1, gap do
        state.points[math.floor((state.sweepPos + i) % width)] = nil
    end
    
    -- Draw the buffered points
    local startX = centerX - width / 2
    local lastX, lastY
    
    -- Move drawSegment outside for efficiency
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
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then 
        ringAlpha = 0
        peakShock = 40
        return 
    end
    
    local org = ply.organism
    if not org then 
        ringAlpha = 0
        peakShock = 40
        return 
    end
    
    local isUnconscious = org.otrub
    local pulse = org.heartbeat or org.pulse or 70
    local brain = org.brain or 0
    local bloodpressure = org.bloodpressure or 93
    local consciousness = org.consciousness or 0
    local shock = org.shock or 0
    local isCritical = (org.critical == true) or (pulse < 1 and brain >= 0.02) or (brain >= 0.34)
    local admiring = ply:GetNWBool("mcd_admiring", false)
    heartPhase = heartPhase + FrameTime() * (pulse / 60)

    if isUnconscious and isCritical and not flatlinePlayed then
        flatlinePlayed = true
        if IsValid(flatlineSound) then flatlineSound:Stop() end
        flatlineSound = CreateSound(LocalPlayer(), "health/gg.ogg")
        if IsValid(flatlineSound) then
            flatlineSound:Play()
        end

    elseif not isUnconscious and flatlinePlayed then
        flatlinePlayed = false
        if IsValid(flatlineSound) then
            flatlineSound:Stop()
        end
        timer.Remove("flatline_fade")
    end
    
    if isUnconscious then
        local currentShock = org.shock or 0
        if currentShock > peakShock then
            peakShock = currentShock
        end
        ringAlpha = math.Approach(ringAlpha, 1, FrameTime() * 2)
        dotBeat = math.floor(CurTime()) % 3
    else
        ringAlpha = math.Approach(ringAlpha, 0, FrameTime() * 3)
        if ringAlpha <= 0 then
            peakShock = 40
            centerEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
        end
    end
    
    if ringAlpha <= 0 and not showTopLeftECG and not showPulseCheckECG then return end
    
    lerpBrain = math.Approach(lerpBrain, org.brain or 0, FrameTime() * 2)
    lerpShock = math.Approach(lerpShock, org.shock or 0, FrameTime() * 50)
    lerpConsciousness = math.Approach(lerpConsciousness, org.consciousness or 0, FrameTime() * 2)
    
    local scrW, scrH = ScrW(), ScrH()
    local centerX, centerY = scrW / 2, scrH / 2
    
    surface.SetDrawColor(0, 0, 0, 90 * ringAlpha)
    surface.DrawRect(0, 0, scrW, scrH)
    
    local ringColor = isCritical and Color(200, 0, 0, 255 * ringAlpha) or Color(220, 220, 220, 255 * ringAlpha)
    local dotColor = isCritical and ringColor or Color(255, 255, 255, 255 * ringAlpha)
    
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
    
    DrawArc(centerX, centerY, radius, thickness, 0, 360, 60, Color(40, 40, 40, 100 * ringAlpha))
    DrawArc(centerX, centerY, radius, thickness, 90, 90 - (progress * 360), 80, ringColor)
    
    if hg_unconsciousclassic:GetBool() then
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
        DrawEKG(centerEKGState, centerX, centerY, 540, 140, pulse, dotColor, ringAlpha, bloodpressure)
    end


    local showTopLeftECG = false
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
    elseif (admiring or (pulse < 40 or pulse > 150)) and not org.otrub then
        showTopLeftECG = true
    end

    if showTopLeftECG and not g_TopLeftECGData then
        g_TopLeftECGData = {
            started = CurTime(),
            nextBeat = CurTime(),
            counted = 0,
            completed = false,
            finalBPM = 0
        }
    elseif not showTopLeftECG and g_TopLeftECGData then
        g_TopLeftECGData = nil
    end

    if showPulseCheckECG then
        ecgAlphaPulseCheck = math.Approach(ecgAlphaPulseCheck, 1, FrameTime() * 2)
    else
        ecgAlphaPulseCheck = math.Approach(ecgAlphaPulseCheck, 0, FrameTime() * 3)
    end

    if showTopLeftECG then
        ecgAlpha = math.Approach(ecgAlpha, 1, FrameTime() * 2)
    else
        ecgAlpha = math.Approach(ecgAlpha, 0, FrameTime() * 3)
    end

    if ecgAlphaPulseCheck > 0 then
        local boxW, boxH = 300, 150
        local boxX, boxY = ScrW() / 2 - boxW / 2, ScrH() - boxH - 20

        surface.SetDrawColor(50, 50, 50, 150 * ecgAlphaPulseCheck)
        surface.DrawRect(boxX, boxY, boxW, boxH)
        surface.SetDrawColor(255, 255, 255, 200 * ecgAlphaPulseCheck)
        surface.DrawOutlinedRect(boxX, boxY, boxW, boxH)

        local target_org = g_PulseCheckTarget.organism or {}
        local target_pulse = target_org.heartbeat or target_org.pulse or 70
        local target_bp = target_org.bloodpressure or 93

        if g_PulseCheckData and not g_PulseCheckData.completed then
            if target_org.heartstop or target_pulse <= 0 then
                g_PulseCheckData.completed = true
                g_PulseCheckData.finalBPM = "No Pulse"
            elseif CurTime() >= g_PulseCheckData.started + 10 then
                g_PulseCheckData.completed = true
                g_PulseCheckData.finalBPM = g_PulseCheckData.counted * 6
            else
                local timeNow = CurTime()
                while timeNow >= g_PulseCheckData.nextBeat and g_PulseCheckData.nextBeat <= g_PulseCheckData.started + 10 do
                    g_PulseCheckData.counted = g_PulseCheckData.counted + 1
                    local dynamicRate = math.max(target_pulse, 1)
                    g_PulseCheckData.nextBeat = g_PulseCheckData.nextBeat + (60 / dynamicRate)
                    if target_pulse < 1 then
                        surface.PlaySound("health/gg.ogg")
                    elseif target_pulse > 150 or (target_bp or 93) > 140 then
                        surface.PlaySound("health/critbeat.ogg")
                    else
                        surface.PlaySound("health/beat.ogg")
                    end
                end
            end
        end

        DrawEKG(pulseCheckEKGState, boxX + boxW / 2, boxY + boxH / 2, boxW - 20, boxH - 20, target_pulse, Color(255, 255, 255, 255), ecgAlphaPulseCheck, target_bp)

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

        draw.SimpleText(displayText, "HomigradFontTypewriterSmall", boxX + boxW / 2, boxY + 10, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
    else
        pulseCheckEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
    end

    if ecgAlpha > 0 then
        local boxW, boxH = 300, 150
        local boxX, boxY = 20, 20

        surface.SetDrawColor(50, 50, 50, 150 * ecgAlpha)
        surface.DrawRect(boxX, boxY, boxW, boxH)
        surface.SetDrawColor(255, 255, 255, 200 * ecgAlpha)
        surface.DrawOutlinedRect(boxX, boxY, boxW, boxH)

        if g_TopLeftECGData and not g_TopLeftECGData.completed then
            if org.heartstop or pulse <= 0 then
                g_TopLeftECGData.completed = true
                g_TopLeftECGData.finalBPM = "No Pulse"
            elseif CurTime() >= g_TopLeftECGData.started + 10 then
                g_TopLeftECGData.completed = true
                g_TopLeftECGData.finalBPM = g_TopLeftECGData.counted * 6
            else
                local timeNow = CurTime()
                while timeNow >= g_TopLeftECGData.nextBeat and g_TopLeftECGData.nextBeat <= g_TopLeftECGData.started + 10 do
                    g_TopLeftECGData.counted = g_TopLeftECGData.counted + 1
                    local dynamicRate = math.max(pulse, 1)
                    g_TopLeftECGData.nextBeat = g_TopLeftECGData.nextBeat + (60 / dynamicRate)
                end
            end
        end

        DrawEKG(topLeftEKGState, boxX + boxW / 2, boxY + boxH / 2, boxW - 20, boxH - 20, pulse, Color(255, 255, 255, 255), ecgAlpha, bloodpressure)

        local displayText = ""
        if g_TopLeftECGData then
            if g_TopLeftECGData.completed then
                if type(g_TopLeftECGData.finalBPM) == "number" then
                    displayText = g_TopLeftECGData.counted .. " x 6 = " .. g_TopLeftECGData.finalBPM .. " BPM"
                else
                    displayText = g_TopLeftECGData.finalBPM
                end
            else
                displayText = "Counting: " .. g_TopLeftECGData.counted
            end
        end

        draw.SimpleText(displayText, "HomigradFontTypewriterSmall", boxX + boxW / 2, boxY + 10, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
    else
        topLeftEKGState = { points = {}, sweepPos = 0, lastUpdate = 0, phase = 0 }
    end

    -- Heartbeat sounds
    local abnormalPulse = (pulse < 40 and pulse >= 1) or pulse > 150
    if admiring or org.otrub or abnormalPulse then
        local currentHeartBeat = math.floor(heartPhase)
        if currentHeartBeat > lastHeartBeat then
            lastHeartBeat = currentHeartBeat

            if pulse < 1 then
                if not IsValid(asystoleSound) then
                    sound.PlayFile("sound/health/gg.ogg", "noblock noplay", function(station)
                        if IsValid(station) then
                            station:Play()
                            asystoleSound = station
                        end
                    end)
                end
            else
                if IsValid(asystoleSound) then
                    asystoleSound:Stop()
                    asystoleSound = nil
                end

                local isSevere = pulse > 150 or (bloodpressure or 93) > 140
                local soundFile = isSevere and "critbeat.ogg" or "beat.ogg"
                sound.PlayFile("sound/health/" .. soundFile, "noblock noplay", function(station) if IsValid(station) then station:Play() end end)
            end
        end
    else
        if IsValid(asystoleSound) then asystoleSound:Stop(); asystoleSound = nil end
    end
end)


