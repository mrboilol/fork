
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

local hg_unconsciousring = CreateClientConVar("hg_unconsciousring", "1", true, false, "Enable unconscious ring", 0, 1)
local hg_unconsciousclassic = CreateClientConVar("hg_unconsciousclassic", "0", true, false, "Use classic dots instead of EKG line", 0, 1)

-- Local variables for faster access
local math = math
local surface = surface
local draw = draw
local Color = Color

local ekgPoints = {}
local sweepPos = 0
local lastSweepUpdate = 0

local function DrawEKG(centerX, centerY, width, height, pulse, color, ringAlpha)
    local time = CurTime()
    if lastSweepUpdate == 0 then lastSweepUpdate = time end
    local dt_sweep = time - lastSweepUpdate
    
    local interval = 60 / pulse
    local sweepSpeed = width / 4
    
    local oldSweepPos = sweepPos
    sweepPos = (sweepPos + dt_sweep * sweepSpeed) % width
    lastSweepUpdate = time

    -- Update current position with new waveform data
    -- Fill all indices between oldSweepPos and newSweepPos to ensure no gaps
    local function getH(t)
        local beatTime = t % interval
        if beatTime < 0.1 then return math.sin(beatTime * math.pi * 10) * 0.15
        elseif beatTime < 0.15 then return 0
        elseif beatTime < 0.18 then return -math.sin((beatTime - 0.15) * math.pi * 33) * 0.2
        elseif beatTime < 0.22 then return math.sin((beatTime - 0.18) * math.pi * 25) * 1.0
        elseif beatTime < 0.25 then return -math.sin((beatTime - 0.22) * math.pi * 33) * 0.3
        elseif beatTime < 0.4 then return 0
        elseif beatTime < 0.55 then return math.sin((beatTime - 0.4) * math.pi * 6.6) * 0.2
        end
        return 0
    end

    local steps = math.max(1, math.floor(math.abs(sweepPos - oldSweepPos)))
    if sweepPos < oldSweepPos then steps = math.max(1, math.floor(width - oldSweepPos + sweepPos)) end

    for i = 0, steps do
        local p = (oldSweepPos + i) % width
        local t = time - (dt_sweep * (1 - i/steps))
        ekgPoints[math.floor(p)] = getH(t)
    end
    
    -- Clear a small gap ahead of the sweepPos
    local gap = 10
    for i = 1, gap do
        ekgPoints[math.floor((sweepPos + i) % width)] = nil
    end
    
    -- Draw the buffered points
    local startX = centerX - width / 2
    local lastX, lastY
    
    for i = 0, width - 1 do
        local h_val = ekgPoints[i]
        if h_val == nil then 
            lastX, lastY = nil, nil
            continue 
        end
        
        local x = startX + i
        local y = centerY - (h_val * height / 2)
        
        local dist = sweepPos - i
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

        -- Shadow brush is slightly larger
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
            ekgPoints = {}
            sweepPos = 0
            lastSweepUpdate = 0
        end
    end
    
    if ringAlpha <= 0 then return end
    
    lerpBrain = math.Approach(lerpBrain, org.brain or 0, FrameTime() * 2)
    lerpShock = math.Approach(lerpShock, org.shock or 0, FrameTime() * 50)
    lerpConsciousness = math.Approach(lerpConsciousness, org.consciousness or 0, FrameTime() * 2)
    
    local pulse = org.heartbeat or org.pulse or 70
    local brain = org.brain or 0
    local consciousness = org.consciousness or 0
    local shock = org.shock or 0
    local isCritical = (org.critical == true) or (pulse < 1 and brain >= 0.02) or (brain >= 0.34)
    
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
        DrawEKG(centerX, centerY, 540, 140, pulse, dotColor, ringAlpha)
    end
end)

