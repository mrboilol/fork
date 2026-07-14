-- ======================================================
--  Universal Pickup History Addon (Clientside)
--  Compatible with any gamemode / addon
-- ======================================================

if SERVER then return end

local pickupHistory = {}
local typeState = {}

local font = "HomigradFont"
local color_bg = Color(0, 0, 0, 200)
local color_outline_def = Color(145, 0, 0, 255)
local color_text_def = Color(255, 255, 255, 255)

local displayTime = 5
local typeSpeed = 15
local maxBoxWidth = ScreenScale(200)

local function GetAccentColor()
    return color_outline_def
end

local function GetTextColor()
    return color_text_def
end

local function AddPickupNotification(text, isLoss)
    if not isstring(text) or text == "" then return end

    local id = tostring(CurTime()) .. "_" .. math.random(1, 100000)
    pickupHistory[#pickupHistory + 1] = {
        text = text,
        time = CurTime(),
        id = id,
        isLoss = isLoss or false
    }

    typeState[id] = {
        t = 0,
        len = #text,
        smoothW = 0
    }
end

hook.Add("HUDItemPickedUp", "UniversalPickup_Item", function(itemName)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local name = language.GetPhrase(itemName)
    AddPickupNotification(name)
    return true
end)

hook.Add("HUDAmmoPickedUp", "UniversalPickup_Ammo", function(itemName, amount)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local name = language.GetPhrase(itemName)
    AddPickupNotification(amount .. " " .. name)
    return true
end)

hook.Add("HUDWeaponPickedUp", "UniversalPickup_Weapon", function(wep)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not IsValid(wep) then return end

    local class = wep:GetClass()
    if class == "weapon_hands" or class == "weapon_hands_sh" then return end

    local name = language.GetPhrase(wep:GetPrintName() or class)
    AddPickupNotification(name)
    return true
end)

-- === HUD ОТРИСОВКА ===
hook.Add("HUDPaint", "UniversalPickup_Paint", function()
    if #pickupHistory == 0 then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local scrW, scrH = ScrW(), ScrH()
    local startX = scrW - ScreenScale(20)
    local startY = scrH * 0.4

    local padding = ScreenScale(3)
    local spacing = ScreenScale(1)

    local color_outline = GetAccentColor()
    local color_text = GetTextColor()

    local currentY = startY

    for i = #pickupHistory, 1, -1 do
        local pickup = pickupHistory[i]
        local elapsed = CurTime() - pickup.time

        local typeDuration = #pickup.text / typeSpeed
        local idleEnd = typeDuration + displayTime

        local charCount = #pickup.text
        local alpha = 255

        if elapsed < typeDuration then
            charCount = math.floor(elapsed * typeSpeed)
        elseif elapsed > idleEnd then
            local outElapsed = elapsed - idleEnd
            charCount = math.max(0, #pickup.text - math.floor(outElapsed * typeSpeed))

            if charCount <= 0 then
                local fade = math.Clamp(outElapsed - (#pickup.text / typeSpeed), 0, 1)
                alpha = 255 * (1 - fade)

                if fade >= 1 then
                    typeState[pickup.id] = nil
                    table.remove(pickupHistory, i)
                    continue
                end
            end
        end

        local text = string.sub(pickup.text, 1, charCount)
        local prefix = pickup.isLoss and "- " or "+ "
        local displayText = prefix .. text

        surface.SetFont(font)
        local tw, th = surface.GetTextSize(displayText)

        local targetWidth = math.min(tw + padding * 2, maxBoxWidth)
        local s = typeState[pickup.id]

        if s then
            s.smoothW = Lerp(FrameTime() * 10, s.smoothW or 0, targetWidth)
        end

        local boxWidth = s and s.smoothW or targetWidth
        local boxHeight = th + padding

        local drawX = startX - boxWidth
        local drawY = currentY

        draw.RoundedBox(0, drawX, drawY, boxWidth, boxHeight,
            Color(color_bg.r, color_bg.g, color_bg.b, math.min(color_bg.a, alpha)))

        surface.SetDrawColor(
            color_outline.r,
            color_outline.g,
            color_outline.b,
            math.min(color_outline.a, alpha)
        )
        surface.DrawOutlinedRect(drawX, drawY, boxWidth, boxHeight, 1)

        render.SetScissorRect(drawX, drawY, drawX + boxWidth, drawY + boxHeight, true)
        draw.SimpleText(
            displayText,
            font,
            drawX + boxWidth / 2,
            drawY + boxHeight / 2,
            Color(color_text.r, color_text.g, color_text.b, math.min(color_text.a, alpha)),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        render.SetScissorRect(0, 0, 0, 0, false)

        currentY = currentY + boxHeight + spacing
    end
end)
