-- dji_mavic_hud.lua
-- HUD для DJI Mavic 3
-- Путь: addons/FPV drone/lua/autorun/client/dji_mavic_hud.lua

local function IsMavicDrone()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    local drone = ply:GetNWEntity("kamikaze_")
    return IsValid(drone) and drone:GetClass() == "dji_mavic3"
end

-- Загружаем текстуры
local MV_map = Material("HUD/MAVIC/MV_map.png")
local MV_exit = Material("HUD/MAVIC/MV_exit.png")
local MV_basevid = {
    [1] = Material("HUD/MAVIC/MV_basevid.png"),
    [3] = Material("HUD/MAVIC/MV_basevid3.png"),
    [7] = Material("HUD/MAVIC/MV_basevid7.png")
}
local MV_rec = Material("HUD/MAVIC/MV_rec.png")
local MV_video = Material("HUD/MAVIC/MV_video.png")
local MV_cut = Material("HUD/MAVIC/MV_cut.png")
local MV_batter1 = Material("HUD/MAVIC/MV_batter1.png")
local MV_batter2 = Material("HUD/MAVIC/MV_batter2.png")
local MV_autoandssd = Material("HUD/MAVIC/MV_autoandssd.png")
local MV_sput = Material("HUD/MAVIC/MV_sput.png")
local MV_more = Material("HUD/MAVIC/MV_more.png")

-- Текстуры сигнала
local MV_signal = {
    [1] = Material("HUD/MAVIC/MV_signal1.png"),
    [2] = Material("HUD/MAVIC/MV_signal2.png"),
    [3] = Material("HUD/MAVIC/MV_signal3.png"),
    [4] = Material("HUD/MAVIC/MV_signal4.png")
}

-- Шрифты
surface.CreateFont("Mavic_Battery_Font", { 
    font = "Arial", 
    size = 20, 
    weight = 700, 
    antialias = true,
    shadow = false,
    outline = false
})

surface.CreateFont("Mavic_Satellites_Font", {
    font = "Arial",
    size = 28,
    weight = 900,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

surface.CreateFont("Mavic_Height_Font", {
    font = "Arial",
    size = 48,
    weight = 900,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

surface.CreateFont("Mavic_Distance_Font", {
    font = "Arial",
    size = 48,
    weight = 900,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

surface.CreateFont("Mavic_Speed_Font", {
    font = "Arial",
    size = 31,
    weight = 700,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

-- Шрифт для RES&FPS (верхняя надпись)
surface.CreateFont("Mavic_ResFPS_Title_Font", {
    font = "Arial",
    size = 24,
    weight = 700,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

-- Шрифт для 4K 60 (нижняя надпись, крупнее)
surface.CreateFont("Mavic_ResFPS_Value_Font", {
    font = "Arial",
    size = 36,
    weight = 900,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

-- Шрифт для EV (верхняя надпись)
surface.CreateFont("Mavic_EV_Title_Font", {
    font = "Arial",
    size = 24,
    weight = 700,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

-- Шрифт для 0.0 (нижняя надпись)
surface.CreateFont("Mavic_EV_Value_Font", {
    font = "Arial",
    size = 36,
    weight = 900,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

-- Шрифт для Memory (верхняя надпись)
surface.CreateFont("Mavic_Memory_Title_Font", {
    font = "Arial",
    size = 24,
    weight = 700,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

-- Шрифт для 00:00 (нижняя надпись)
surface.CreateFont("Mavic_Memory_Value_Font", {
    font = "Arial",
    size = 36,
    weight = 900,
    antialias = true,
    shadow = true,
    shadowcolor = Color(0, 0, 0, 255),
    outline = false
})

-- Переменные для редких изменений
local lastSatelliteUpdate = 0
local currentSatelliteCount = 24

local lastFPSUpdate = 0
local currentFPS = 60

-- EV значение (всегда 0.0)
local evValue = "0.0"

-- Memory значение (всегда 00:00)
local memoryValue = "00:00"

hook.Add("HUDPaint", "Mavic_HUD", function()
    if not IsMavicDrone() then return end

    local screenW, screenH = ScrW(), ScrH()
    local ply = LocalPlayer()
    local drone = ply:GetNWEntity("kamikaze_")
    
    if not IsValid(drone) then return end

    local batteryLevel = drone:GetNWFloat("Mavic_BatteryLevel", 1.0)
    local signalLevel = drone:GetNWInt("Mavic_SignalLevel", 1)
    local zoomLevel = drone:GetNWInt("Mavic_ZoomLevel", 1)
    
    -- Получаем позицию дрона и его скорость
    local dronePos = drone:GetPos()
    local velocity = drone:GetVelocity()
    
    -- Конвертация скорости в км/ч
    local verticalSpeedKmh = math.abs(velocity.z) * 0.068
    local horizontalSpeedKmh = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) * 0.068
    
    verticalSpeedKmh = math.floor(verticalSpeedKmh + 0.5)
    horizontalSpeedKmh = math.floor(horizontalSpeedKmh + 0.5)
    
    -- Точка взлёта
    local spawnPos = Vector(
        drone:GetNWFloat("Mavic_SpawnPosX", 0),
        drone:GetNWFloat("Mavic_SpawnPosY", 0),
        drone:GetNWFloat("Mavic_SpawnPosZ", 0)
    )
    
    if spawnPos:IsZero() then 
        spawnPos = dronePos 
    end
    
    -- Спутники
    local currentTime = CurTime()
    if currentTime - lastSatelliteUpdate > 30 then
        lastSatelliteUpdate = currentTime
        if math.random(1, 100) <= 2 then
            currentSatelliteCount = 23
        else
            currentSatelliteCount = 24
        end
    end
    
    -- FPS
    if currentTime - lastFPSUpdate > 45 then
        lastFPSUpdate = currentTime
        if math.random(1, 100) <= 3 then
            currentFPS = 59
        else
            currentFPS = 60
        end
    end
    
    -- Высота
    local height = dronePos.z / 39.37
    height = math.floor(height + 0.5)
    
    -- Дистанция
    local horizontalDist = math.sqrt(
        math.pow(dronePos.x - spawnPos.x, 2) + 
        math.pow(dronePos.y - spawnPos.y, 2)
    ) / 39.37
    horizontalDist = math.floor(horizontalDist + 0.5)

    -- 🗺️ КАРТА
    local mapX = 28
    local mapY = screenH - 37 - 104
    local mapWidth = 105
    local mapHeight = 104
    
    surface.SetMaterial(MV_map)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(mapX, mapY, mapWidth, mapHeight)

    -- H с вертикальной скоростью
    surface.SetFont("Mavic_Height_Font")
    surface.SetTextColor(255, 255, 255, 255)
    local hText = "H " .. height .. "m"
    local hX = mapX + mapWidth + 30
    
    local hTextWidth, hTextHeight = surface.GetTextSize(hText)
    local hY = mapY + mapHeight - hTextHeight - 2
    
    surface.SetTextPos(hX, hY)
    surface.DrawText(hText)
    
    -- Вертикальная скорость
    surface.SetFont("Mavic_Speed_Font")
    local vSpeedText = verticalSpeedKmh .. " km/h"
    local vSpeedWidth, vSpeedHeight = surface.GetTextSize(vSpeedText)
    local vSpeedX = hX
    local vSpeedY = hY - vSpeedHeight - 10
    
    surface.SetTextPos(vSpeedX, vSpeedY)
    surface.DrawText(vSpeedText)

    -- D с горизонтальной скоростью
    surface.SetFont("Mavic_Distance_Font")
    local dText = "D " .. horizontalDist .. "m"
    local dX = hX + 350
    
    surface.SetTextPos(dX, hY)
    surface.DrawText(dText)
    
    -- Горизонтальная скорость
    surface.SetFont("Mavic_Speed_Font")
    local hSpeedText = horizontalSpeedKmh .. " km/h"
    local hSpeedWidth, hSpeedHeight = surface.GetTextSize(hSpeedText)
    local hSpeedX = dX
    local hSpeedY = hY - hSpeedHeight - 10
    
    surface.SetTextPos(hSpeedX, hSpeedY)
    surface.DrawText(hSpeedText)

    -- 🎥 REC (правая часть экрана)
    local rightMargin = 20
    local recX = screenW - rightMargin - 112
    local recY = screenH / 2 - 56
    
    -- БАЗОВЫЙ ВИДЕО ЭЛЕМЕНТ
    local baseX = recX - 180
    local baseY = screenH / 2 - 203
    
    local currentBaseVid = MV_basevid[zoomLevel] or MV_basevid[1]
    surface.SetMaterial(currentBaseVid)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(baseX, baseY, 104, 406)
    
    -- REC
    surface.SetMaterial(MV_rec)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(recX, recY, 112, 112)
    
    -- CUT
    local cutX = recX + (112 - 56) / 2
    local cutY = recY - 94 - 42
    
    surface.SetMaterial(MV_cut)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(cutX, cutY, 56, 42)
    
    -- VIDEO
    local videoX = recX + (112 - 60) / 2
    local videoY = recY + 112 + 94
    
    surface.SetMaterial(MV_video)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(videoX, videoY, 60, 45)
    
    -- 📀 AUTO & SSD
    local autoX = screenW - 20 - 548
    local autoY = screenH - 29 - 5 - 61
    
    surface.SetMaterial(MV_autoandssd)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(autoX, autoY, 548, 61)
    
    -- Располагаем над нижней чёрной линией
    local bottomBlackLineY = screenH - 10
    
    -- 📺 RES&FPS (над нижней чёрной линией)
    -- Верхняя надпись RES&FPS
    surface.SetFont("Mavic_ResFPS_Title_Font")
    surface.SetTextColor(255, 255, 255, 255)
    local titleText = "RES&FPS"
    local titleWidth, titleHeight = surface.GetTextSize(titleText)
    
    -- Нижняя надпись 4K 60
    surface.SetFont("Mavic_ResFPS_Value_Font")
    local valueText = "4K " .. currentFPS
    local valueWidth, valueHeight = surface.GetTextSize(valueText)
    
    -- Позиция для блока RES&FPS (правее AUTO&SSD)
    local blockX = autoX + 548 - 275 -- Смещение влево на 275px от правого края AUTO&SSD
    local blockY = bottomBlackLineY - valueHeight - titleHeight - 30 -- Над чёрной линией
    
    -- 💾 MEMORY (слева от RES&FPS)
    -- Верхняя надпись Memory
    surface.SetFont("Mavic_Memory_Title_Font")
    surface.SetTextColor(255, 255, 255, 255)
    local memoryTitleText = "Memory"
    local memoryTitleWidth, memoryTitleHeight = surface.GetTextSize(memoryTitleText)
    
    -- Нижняя надпись 00:00
    surface.SetFont("Mavic_Memory_Value_Font")
    local memoryValueText = memoryValue
    local memoryValueWidth, memoryValueHeight = surface.GetTextSize(memoryValueText)
    
    -- Позиция для Memory (слева от RES&FPS с отступом 50px)
    local memoryBlockX = blockX - memoryValueWidth - 140
    
    -- Рисуем верхнюю надпись Memory
    surface.SetFont("Mavic_Memory_Title_Font")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(memoryBlockX, blockY)
    surface.DrawText(memoryTitleText)
    
    -- Рисуем нижнюю надпись 00:00
    surface.SetFont("Mavic_Memory_Value_Font")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(memoryBlockX, blockY + memoryTitleHeight - 3)
    surface.DrawText(memoryValueText)
    
    -- Рисуем верхнюю надпись RES&FPS
    surface.SetFont("Mavic_ResFPS_Title_Font")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(blockX, blockY)
    surface.DrawText(titleText)
    
    -- Рисуем нижнюю надпись (4K 60)
    surface.SetFont("Mavic_ResFPS_Value_Font")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(blockX, blockY + titleHeight - 3)
    surface.DrawText(valueText)
    
    -- 📊 EV (справа от RES&FPS)
    -- Верхняя надпись EV
    surface.SetFont("Mavic_EV_Title_Font")
    surface.SetTextColor(255, 255, 255, 255)
    local evTitleText = "EV"
    local evTitleWidth, evTitleHeight = surface.GetTextSize(evTitleText)
    
    -- Нижняя надпись 0.0
    surface.SetFont("Mavic_EV_Value_Font")
    local evValueText = evValue
    local evValueWidth, evValueHeight = surface.GetTextSize(evValueText)
    
    -- Позиция для EV (справа от RES&FPS с отступом 50px)
    local evBlockX = blockX + math.max(valueWidth, titleWidth) + 50
    
    -- Рисуем верхнюю надпись EV
    surface.SetFont("Mavic_EV_Title_Font")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(evBlockX, blockY)
    surface.DrawText(evTitleText)
    
    -- Рисуем нижнюю надпись 0.0
    surface.SetFont("Mavic_EV_Value_Font")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(evBlockX, blockY + evTitleHeight - 3)
    surface.DrawText(evValueText)
    
    -- 🔋 ВЕРХНЯЯ ПАНЕЛЬ
    local topPanelY = 29 + 15
    
    -- 🔋 БАТАРЕЯ
    local batterX = screenW - 454 - 69
    local batterY = topPanelY
    
    -- Фон батареи
    surface.SetMaterial(MV_batter1)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(batterX, batterY, 69, 69)
    
    -- Круг батареи
    if batteryLevel > 0 then
        local centerX = batterX + 34.5
        local centerY = batterY + 34.5
        local radius = 34.5
        local maxAngle = batteryLevel * 360
        
        for angle = 0, maxAngle - 1, 1 do
            local rad1 = math.rad(angle)
            local rad2 = math.rad(math.min(angle + 1, maxAngle))
            
            local x1 = centerX + math.sin(rad1) * radius
            local y1 = centerY - math.cos(rad1) * radius
            local x2 = centerX + math.sin(rad2) * radius
            local y2 = centerY - math.cos(rad2) * radius
            
            local texCoords = {
                {x = 0.5, y = 0.5},
                {x = 0.5 + math.sin(rad1) * 0.5, y = 0.5 - math.cos(rad1) * 0.5},
                {x = 0.5 + math.sin(rad2) * 0.5, y = 0.5 - math.cos(rad2) * 0.5}
            }
            
            surface.SetMaterial(MV_batter2)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawPoly({
                {x = centerX, y = centerY, u = texCoords[1].x, v = texCoords[1].y},
                {x = x1, y = y1, u = texCoords[2].x, v = texCoords[2].y},
                {x = x2, y = y2, u = texCoords[3].x, v = texCoords[3].y}
            })
        end
    end
    
    -- Число батареи
    local batteryValue = math.floor(batteryLevel * 100 + 0.5)
    local textColor
    if batteryValue <= 9 then
        textColor = Color(225, 36, 76, 255)
    elseif batteryValue <= 20 then
        textColor = Color(220, 130, 35, 255)
    else
        textColor = Color(0, 228, 143, 255)
    end
    
    surface.SetFont("Mavic_Battery_Font")
    surface.SetTextColor(textColor)
    
    local text = tostring(batteryValue)
    local textWidth = surface.GetTextSize(text)
    surface.SetTextPos(batterX + 34.5 - textWidth/2, batterY + 34.5 - 10)
    surface.DrawText(text)
    
    -- СИГНАЛ
    local signalX = batterX + 69 + 100
    local signalY = batterY + (69 - 39) / 2
    
    if MV_signal[signalLevel] then
        surface.SetMaterial(MV_signal[signalLevel])
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(signalX, signalY, 69, 39)
    end
    
    -- СПУТНИК
    local sputX = signalX + 69 + 50
    local sputY = batterY + (69 - 35) / 2
    
    surface.SetMaterial(MV_sput)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(sputX, sputY, 35, 35)
    
    -- Количество спутников
    surface.SetFont("Mavic_Satellites_Font")
    surface.SetTextColor(255, 255, 255, 255)
    local satText = tostring(currentSatelliteCount)
    local satX = sputX + 35 + 15
    local satY = sputY + (35 - 28) / 2
    surface.SetTextPos(satX, satY)
    surface.DrawText(satText)
    
    -- MORE
    local moreX = satX + 50 + 80
    local moreY = batterY + (69 - 28) / 2
    
    surface.SetMaterial(MV_more)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(moreX, moreY, 50, 28)
    
    -- ВЫХОД
    surface.SetMaterial(MV_exit)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(44, batterY + (69 - 63) / 2, 42, 63)
end)

-- Отключаем стандартный HUD
hook.Add("HUDShouldDraw", "Mavic_HUD_Control", function(name)
    if IsMavicDrone() then
        if name == "CHudHealth" or 
           name == "CHudBattery" or 
           name == "CHudAmmo" or 
           name == "CHudSecondaryAmmo" or
           name == "CHudDamageIndicator" then
            return false
        end
    end
end)

print("[MAVIC HUD] Loaded successfully with Memory, RES&FPS and EV")