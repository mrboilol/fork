hg = hg or {}
hg.ZCityInventoryAddonEnabled = true
hg.ZCityInventoryAddonFileGuards = hg.ZCityInventoryAddonFileGuards or {}
if hg.ZCityInventoryAddonFileGuards["hud_cl_weapon_selector"] then return end
hg.ZCityInventoryAddonFileGuards["hud_cl_weapon_selector"] = true

--
hg = hg or {}
hg.WeaponSelector = hg.WeaponSelector or {}
local WS = hg.WeaponSelector
local SimpleSelector = {
    Draw = WS.WeaponSelectorDraw,
    Change = WS.ChangeSelectionWep,
    Select = WS.SetActuallyWeapon,
    Weapons = WS.GetWeaponTable
}

local function ZCityGetInventorySystem()
	local convar = GetConVar("hg_invsystem")
	if convar then
		return math.Clamp(convar:GetInt(), 0, 2)
	end

    return math.Clamp(GetGlobalInt("InventorySystem", 0), 0, 2)
end

local function ZCitySelectInventoryWeapon(wep)
    if not IsValid(wep) then return end

    input.SelectWeapon(wep)
    net.Start("NI_SelectWeapon")
    net.WriteEntity(wep)
    net.SendToServer()
end

function WS.GetPrintName( self )
    local class = self:GetClass()
    local phrase = language.GetPhrase(class)
    if phrase ~= class and phrase ~= "" then return phrase end
    local printName = self:GetPrintName()
    return isstring(printName) and printName ~= "" and printName or class
end

local function ZCityGetWeaponDescription(wep)
    if not IsValid(wep) then return "" end

    local description = wep.Description
    if not isstring(description) or string.Trim(description) == "" then description = wep.Instructions end
    if not isstring(description) or string.Trim(description) == "" then description = wep.Purpose end
    if not isstring(description) then return "" end

    description = language.GetPhrase(description)
    description = description:gsub("<.->", " ")
    description = description:gsub("[%s\r\n]+", " ")
    return string.Trim(description)
end

WS.Show = 0
WS.Transparent = 0
WS.LastSelectedSlot = 0
WS.LastSelectedSlotPos = 0

WS.SelectedSlot = 0
WS.SelectedSlotPos = 0

function WS.DrawText(text, font, posX, posY, color, textAlign)
    draw.DrawText( text, font, posX + 2, posY + 2, ColorAlpha(color_black,WS.Transparent*255) ,textAlign )
    draw.DrawText( text, font, posX, posY, ColorAlpha(color,WS.Transparent*255) ,textAlign )
end

function WS.GetSelectedWeapon()
    if not IsValid( LocalPlayer() ) or not LocalPlayer():Alive() then return end
    local Weapons = WS.GetWeaponTable( LocalPlayer() )
    return Weapons[WS.SelectedSlot] and Weapons[WS.SelectedSlot][WS.SelectedSlotPos] or Weapons[WS.LastSelectedSlot][WS.LastSelectedSlotPos] or Weapons[0][0]
end

WS.WeaponPickupOrder = WS.WeaponPickupOrder or {}
WS.WeaponPickupSerial = WS.WeaponPickupSerial or 0
WS.OwnedWeaponSnapshot = WS.OwnedWeaponSnapshot or {}

local function ZCityRefreshWeaponPickupOrder(ply)
    if not IsValid(ply) then return {} end

    local weapons = ply:GetWeapons()
    table.sort(weapons, function(a, b) return a:EntIndex() < b:EntIndex() end)

    local current = {}
    for _, wep in ipairs(weapons) do
        current[wep] = true
        if not WS.OwnedWeaponSnapshot[wep] then
            local class = wep:GetClass()
            if class == "weapon_hands_sh" or class == "weapon_hands" then
                WS.WeaponPickupOrder[wep] = -1
            else
                WS.WeaponPickupSerial = WS.WeaponPickupSerial + 1
                WS.WeaponPickupOrder[wep] = WS.WeaponPickupSerial
            end
        end
    end

    WS.OwnedWeaponSnapshot = current
    return weapons
end

local nextPickupOrderRefresh = 0
hook.Add("Think", "ZCityInventory_TrackPickupOrder", function()
    if nextPickupOrderRefresh > CurTime() then return end
    nextPickupOrderRefresh = CurTime() + 0.2

    local ply = LocalPlayer()
    if IsValid(ply) then ZCityRefreshWeaponPickupOrder(ply) end
end)

function WS.GetWeaponTable( ply )
    if not IsValid( ply ) or not ply:Alive() then return end
    if ZCityGetInventorySystem() == 1 and SimpleSelector.Weapons then
        return SimpleSelector.Weapons(ply)
    end

    local WeaponsGet = ZCityRefreshWeaponPickupOrder(ply)
    local FormatedTable = {
        [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {},
    }

    local grouped = {
        [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {},
    }

    for _, wep in ipairs(WeaponsGet) do
        local slot = math.Clamp(tonumber(wep.Slot) or 0, 0, 5)
        grouped[slot][#grouped[slot] + 1] = wep
    end

    for slot = 0, 5 do
        table.sort(grouped[slot], function(a, b)
            local aOrder = WS.WeaponPickupOrder[a] or 0
            local bOrder = WS.WeaponPickupOrder[b] or 0
            if aOrder ~= bOrder then return aOrder > bOrder end
            return (a.SlotPos or 0) < (b.SlotPos or 0)
        end)

        for index, wep in ipairs(grouped[slot]) do
            FormatedTable[slot][index - 1] = wep
        end
    end

    return FormatedTable
end

local scrW, scrH = ScrW(), ScrH()

local AcsentColor = Color(155,0,0)
local gradient_u = Material("vgui/gradient-d")

function WS.WeaponSelectorDraw( ply )
    if ZCityGetInventorySystem() == 1 and SimpleSelector.Draw then
        return SimpleSelector.Draw(ply)
    end
end

local JudgeSelector = {
    Show = 0,
    Transparent = 0,
    LastSelectedSlot = 0,
    LastSelectedSlotPos = 0,
    SelectedSlot = 0,
    SelectedSlotPos = 0,
    BoxAnim = {},
    SlotBadgeAnim = {},
    CornerFlashWeapon = nil,
    InfoAlpha = 0,
    InfoWeapon = nil,
}

local judgeAccent = Color(190, 190, 190)
local judgePanel = Color(9, 9, 9)
local judgeInactiveIcon = Color(175, 175, 175)
local judgeName = Color(235, 235, 235)
local judgeShadow = Color(0, 0, 0, 215)
local judgeIconCache = setmetatable({}, {__mode = "k"})
local judgeTextureCache = {}
local judgeAcceptKeys = {
    slot1 = 1,
    slot2 = 2,
    slot3 = 3,
    slot4 = 4,
    slot5 = 5,
    slot6 = 6,
}

local function ZCityJudgeFontFace()
    local font = GetConVar("hg_font")
    return font and font:GetString() ~= "" and font:GetString() or "x14y24pxHeadUpDaisy"
end

surface.CreateFont("ZCityJudgeWeaponName", {
    font = ZCityJudgeFontFace(),
    size = ScreenScale(7),
    weight = 600,
    antialias = true,
})

surface.CreateFont("ZCityJudgeWeaponNameSmall", {
    font = ZCityJudgeFontFace(),
    size = ScreenScale(5.5),
    weight = 600,
    antialias = true,
})

surface.CreateFont("ZCityJudgeSlotBadge", {
    font = ZCityJudgeFontFace(),
    size = math.floor(ScreenScale(6) + 0.5),
    weight = 700,
    antialias = true,
})

surface.CreateFont("ZCityJudgeInfoLabel", {
    font = ZCityJudgeFontFace(),
    size = ScreenScale(5.5),
    weight = 700,
    antialias = true,
})

surface.CreateFont("ZCityJudgeInfoText", {
    font = ZCityJudgeFontFace(),
    size = ScreenScale(5.5),
    weight = 500,
    antialias = true,
})

local ZCityJudgeCorners

local function ZCityJudgeWrapText(text, font, maxWide)
    surface.SetFont(font)
    local lines = {}
    for _, paragraph in ipairs(string.Explode("\n", text)) do
        local current = ""
        for _, word in ipairs(string.Explode(" ", paragraph)) do
            local candidate = current == "" and word or current .. " " .. word
            if current ~= "" and surface.GetTextSize(candidate) > maxWide then
                lines[#lines + 1] = current
                current = word
            else
                current = candidate
            end
        end
        if current ~= "" then lines[#lines + 1] = current end
    end
    return lines
end

local function ZCityJudgeDrawInfoPanel(wep, x, y, wide, alpha)
    if not IsValid(wep) then return end
    local author = isstring(wep.Author) and wep.Author or ""
    local instructions = isstring(wep.Instructions) and wep.Instructions or ""
    if author == "" and instructions == "" then return end

    JudgeSelector.InfoAlpha = LerpFT(0.2, JudgeSelector.InfoAlpha or 0, 1)
    if JudgeSelector.InfoWeapon ~= wep then
        JudgeSelector.InfoWeapon = wep
        JudgeSelector.InfoAlpha = 0
    end
    local fade = JudgeSelector.InfoAlpha * JudgeSelector.InfoAlpha * (3 - 2 * JudgeSelector.InfoAlpha)
    if fade < 0.001 then return end

    local paddingX = math.max(8, math.floor(ScreenScale(5) + 0.5))
    local paddingY = math.max(6, math.floor(ScreenScale(4) + 0.5))
    local innerWide = wide - paddingX * 2
    surface.SetFont("ZCityJudgeInfoText")
    local _, fontTall = surface.GetTextSize("Wg")
    local lineTall = fontTall + math.max(2, math.floor(ScreenScale(1) + 0.5))
    local gap = math.floor(ScreenScale(3) + 0.5)
    local authorLines = author ~= "" and ZCityJudgeWrapText(author, "ZCityJudgeInfoText", innerWide) or {}
    local infoLines = instructions ~= "" and ZCityJudgeWrapText(instructions, "ZCityJudgeInfoText", innerWide) or {}
    local contentTall = 0
    if #authorLines > 0 then contentTall = contentTall + lineTall + #authorLines * lineTall end
    if #infoLines > 0 then contentTall = contentTall + (#authorLines > 0 and gap or 0) + lineTall + #infoLines * lineTall end
    if contentTall <= 0 then return end

    local tall = contentTall + paddingY * 2
    surface.SetDrawColor(judgePanel.r, judgePanel.g, judgePanel.b, alpha * fade * 220)
    surface.DrawRect(x, y, wide, tall)
    ZCityJudgeCorners(x, y, wide, tall, alpha * fade, 0)

    local textX, textY = x + paddingX, y + paddingY
    local labelColor = Color(judgeAccent.r, judgeAccent.g, judgeAccent.b, alpha * fade * 200)
    local textColor = Color(200, 200, 200, alpha * fade * 255)
    if #authorLines > 0 then
        draw.DrawText("Manufacturer", "ZCityJudgeInfoLabel", textX, textY, labelColor, TEXT_ALIGN_LEFT)
        textY = textY + lineTall
        for _, line in ipairs(authorLines) do
            draw.DrawText(line, "ZCityJudgeInfoText", textX, textY, textColor, TEXT_ALIGN_LEFT)
            textY = textY + lineTall
        end
    end
    if #infoLines > 0 then
        if #authorLines > 0 then textY = textY + gap end
        draw.DrawText("Information", "ZCityJudgeInfoLabel", textX, textY, labelColor, TEXT_ALIGN_LEFT)
        textY = textY + lineTall
        for _, line in ipairs(infoLines) do
            draw.DrawText(line, "ZCityJudgeInfoText", textX, textY, textColor, TEXT_ALIGN_LEFT)
            textY = textY + lineTall
        end
    end
end

local function ZCityJudgeWeaponTable(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local weapons = ply:GetWeapons()
    local cache = JudgeSelector.WeaponTableCache
    local validCount = 0
    local cacheValid = cache and cache.ply == ply
    for _, wep in ipairs(weapons) do
        if not IsValid(wep) then continue end
        validCount = validCount + 1
        if cacheValid then
            local cached = cache.meta[wep]
            if not cached
                or cached.slot ~= (tonumber(wep.Slot) or 0)
                or cached.position ~= (tonumber(wep.SlotPos) or 0)
                or cached.class ~= wep:GetClass() then
                cacheValid = false
            end
        end
    end
    if cacheValid and cache.count == validCount then return cache.slots end

    local validWeapons = {}
    for _, wep in ipairs(weapons) do
        if IsValid(wep) then validWeapons[#validWeapons + 1] = wep end
    end
    table.sort(validWeapons, function(a, b)
        local slotA, slotB = tonumber(a.Slot) or 0, tonumber(b.Slot) or 0
        if slotA ~= slotB then return slotA < slotB end
        local posA, posB = tonumber(a.SlotPos) or 0, tonumber(b.SlotPos) or 0
        if posA ~= posB then return posA < posB end
        local classA, classB = a:GetClass(), b:GetClass()
        return classA == classB and a:EntIndex() < b:EntIndex() or classA < classB
    end)

    local slots = {}
    for slot = 0, 5 do slots[slot] = {count = 0} end
    local meta = {}
    for _, wep in ipairs(validWeapons) do
        local slot = math.Clamp(tonumber(wep.Slot) or 0, 0, 5)
        local slotTable = slots[slot]
        slotTable[slotTable.count] = wep
        slotTable.count = slotTable.count + 1
        meta[wep] = {
            slot = tonumber(wep.Slot) or 0,
            position = tonumber(wep.SlotPos) or 0,
            class = wep:GetClass(),
        }
    end

    JudgeSelector.WeaponTableCache = {ply = ply, count = validCount, meta = meta, slots = slots}
    return slots
end

local function ZCityJudgeFindWeapon(slots, target)
    if not IsValid(target) then return end
    for slot = 0, 5 do
        local slotTable = slots[slot]
        for position = 0, slotTable.count - 1 do
            if slotTable[position] == target then return slot, position end
        end
    end
end

local function ZCityJudgeSelectedWeapon(slots)
    slots = slots or ZCityJudgeWeaponTable(LocalPlayer())
    local slotTable = slots and slots[JudgeSelector.SelectedSlot]
    local wep = slotTable and slotTable[JudgeSelector.SelectedSlotPos]
    return IsValid(wep) and wep or nil
end

local function ZCityJudgeSelectFallback(slots, ply)
    local slot, position = ZCityJudgeFindWeapon(slots, ply:GetActiveWeapon())
    if slot then
        JudgeSelector.SelectedSlot, JudgeSelector.SelectedSlotPos = slot, position
        return slots[slot][position]
    end

    for slotID = 0, 5 do
        if slots[slotID].count > 0 then
            JudgeSelector.SelectedSlot, JudgeSelector.SelectedSlotPos = slotID, 0
            return slots[slotID][0]
        end
    end
end

local function ZCityJudgeIconInfo(icon)
    if not icon then return end
    local cache = isnumber(icon) and judgeTextureCache or judgeIconCache
    local cached = cache[icon]
    if cached then return icon, cached[1], cached[2] end

    local wide, tall
    if isnumber(icon) then
        wide, tall = surface.GetTextureSize(icon)
    elseif isfunction(icon.Width) and isfunction(icon.Height) and (not isfunction(icon.IsError) or not icon:IsError()) then
        wide, tall = icon:Width(), icon:Height()
    end
    if not isnumber(wide) or not isnumber(tall) or wide <= 0 or tall <= 0 then return end

    cache[icon] = {wide, tall}
    return icon, wide, tall
end

local function ZCityJudgeDrawIcon(wep, x, y, wide, tall, alpha, muted)
    local icon, iconWide, iconTall = ZCityJudgeIconInfo(wep.WepSelectIcon2)
    if not icon then icon, iconWide, iconTall = ZCityJudgeIconInfo(wep.WepSelectIcon) end
    if not icon then return false end

    local pad = math.max(2, math.floor(ScreenScale(1.5) + 0.5))
    wide, tall = wide - pad * 2, tall - pad * 2
    if wide <= 0 or tall <= 0 then return false end
    local scale = math.min(wide / iconWide, tall / iconTall) * (muted and 0.95 or math.Clamp(tonumber(wep.WSIconScale) or 1.05, 0.75, 1.15))
    local drawWide, drawTall = iconWide * scale, iconTall * scale
    local drawX, drawY = x + (wide - drawWide) * 0.5 + pad, y + (tall - drawTall) * 0.5 + pad

    render.PushFilterMag(TEXFILTER.ANISOTROPIC)
    render.PushFilterMin(TEXFILTER.ANISOTROPIC)
    local tint = muted and judgeInactiveIcon or color_white
    surface.SetDrawColor(tint.r, tint.g, tint.b, alpha)
    if isnumber(icon) then surface.SetTexture(icon) else surface.SetMaterial(icon) end
    surface.DrawTexturedRect(drawX, drawY, drawWide, drawTall)
    render.PopFilterMin()
    render.PopFilterMag()
    return true
end

local function ZCityJudgeFitName(name, maxWide)
    local font = "ZCityJudgeWeaponName"
    surface.SetFont(font)
    if surface.GetTextSize(name) <= maxWide then return name, font end

    font = "ZCityJudgeWeaponNameSmall"
    surface.SetFont(font)
    if surface.GetTextSize(name) <= maxWide then return name, font end

    local suffix = "..."
    while #name > 0 and surface.GetTextSize(name .. suffix) > maxWide do
        name = string.sub(name, 1, #name - 1)
    end
    return name .. suffix, font
end

local function ZCityJudgeUTF8Length(text)
    local length = 0
    for index = 1, #text do
        local byte = string.byte(text, index)
        if byte < 128 or byte >= 192 then length = length + 1 end
    end
    return length
end

local function ZCityJudgeUTF8Prefix(text, characterCount)
    if characterCount <= 0 then return "" end
    local length = 0
    for index = 1, #text do
        local byte = string.byte(text, index)
        if byte < 128 or byte >= 192 then
            length = length + 1
            if length > characterCount then return string.sub(text, 1, index - 1) end
        end
    end
    return text
end

local function ZCityJudgeScramble(text)
    text = tostring(text or "")
    local ply = LocalPlayer()
    if not ply.organism or not ply.organism.brain or ply.organism.brain <= 0.05 then return text end

    local characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"
    local scrambled = {}
    for index = 1, #text do
        if string.sub(text, index, index) == " " then
            scrambled[index] = " "
        else
            local character = math.random(#characters)
            scrambled[index] = string.sub(characters, character, character)
        end
    end
    return table.concat(scrambled)
end

ZCityJudgeCorners = function(x, y, wide, tall, alpha, flash)
    local line = math.max(1, math.floor(ScreenScale(0.5) + 0.5))
    local inset = math.max(2, math.floor(ScreenScale(1) + 0.5))
    local length = math.min(math.max(line * 3, math.floor(ScreenScale(5) + 0.5)) + math.floor(ScreenScale(1.75) * flash), math.floor(math.min(wide, tall) / 2) - inset)
    if length <= line then return end

    local left, top = math.floor(x + inset), math.floor(y + inset)
    local right, bottom = math.floor(x + wide - inset - line), math.floor(y + tall - inset - line)
    local white = 190 + 65 * flash
    surface.SetDrawColor(white, white, white, alpha * (160 + 38 * flash))
    surface.DrawRect(left, top, length, line)
    surface.DrawRect(left, top, line, length)
    surface.DrawRect(right - length + line, bottom, length, line)
    surface.DrawRect(right, bottom - length + line, line, length)
end

function JudgeSelector.Draw(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local now = CurTime()
    if JudgeSelector.Show < now then
        JudgeSelector.SelectedSlot = JudgeSelector.LastSelectedSlot
        JudgeSelector.SelectedSlotPos = -1
        JudgeSelector.Transparent = 0
        JudgeSelector.InfoAlpha = 0
        JudgeSelector.InfoWeapon = nil
        return
    end

    local slots = ZCityJudgeWeaponTable(ply)
    local selected = ZCityJudgeSelectedWeapon(slots) or ZCityJudgeSelectFallback(slots, ply)
    if not IsValid(selected) then return end
    JudgeSelector.Transparent = LerpFT(0.2, JudgeSelector.Transparent, math.min(JudgeSelector.Show - now, 1))

    local screenWide, screenTall = ScrW(), ScrH()
    local slotCount = 0
    for slot = 0, 5 do if slots[slot].count > 0 then slotCount = slotCount + 1 end end
    local cardWide = screenWide * 0.085
    local columnGap = math.max(2, math.floor(ScreenScale(2) + 0.5))
    local rowGap = math.max(1, math.floor(ScreenScale(1) + 0.5))
    local groupWide = slotCount * cardWide + math.max(0, slotCount - 1) * columnGap
    local x = (screenWide - groupWide) * 0.5
    local firstY = screenTall * 0.05
    local compactTall, selectedTall = screenTall * 0.025, screenTall * 0.12

    for slot = 0, 5 do
        local slotTable = slots[slot]
        if slotTable.count < 1 then continue end
        local rowY = firstY
        local badgeTarget = slot == JudgeSelector.SelectedSlot and 1 or 0
        JudgeSelector.SlotBadgeAnim[slot] = LerpFT(0.18, JudgeSelector.SlotBadgeAnim[slot] or 0, badgeTarget)
        local badgeAlpha = JudgeSelector.Transparent * JudgeSelector.SlotBadgeAnim[slot] * 255
        if badgeAlpha > 0.5 then
            local badgeSize = math.floor(ScreenScale(7) + 0.5)
            local badgeX, badgeY = math.floor(x + (cardWide - badgeSize) * 0.5), math.floor(firstY - badgeSize - ScreenScale(1.5))
            surface.SetDrawColor(judgePanel.r, judgePanel.g, judgePanel.b, badgeAlpha * 0.8)
            surface.DrawRect(badgeX, badgeY, badgeSize, badgeSize)
            surface.SetDrawColor(judgeAccent.r, judgeAccent.g, judgeAccent.b, badgeAlpha * 0.32)
            surface.DrawOutlinedRect(badgeX, badgeY, badgeSize, badgeSize, 1)
            draw.SimpleText(slot + 1, "ZCityJudgeSlotBadge", badgeX + badgeSize * 0.5, badgeY + badgeSize * 0.5 - 2, Color(220, 220, 220, badgeAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        for position = 0, slotTable.count - 1 do
            local wep = slotTable[position]
            local isSelected = wep == selected
            local targetTall = isSelected and selectedTall or compactTall
            local animation = JudgeSelector.BoxAnim[wep] or {tall = compactTall}
            JudgeSelector.BoxAnim[wep] = animation
            animation.tall = LerpFT(0.18, animation.tall, targetTall)
            local drawTall = animation.tall
            surface.SetDrawColor(judgePanel.r, judgePanel.g, judgePanel.b, JudgeSelector.Transparent * (isSelected and 220 or 135))
            surface.DrawRect(x, rowY, cardWide, drawTall)

            if isSelected then
                local cornerLength, inset, cornerSafe = math.max(3, math.floor(ScreenScale(5) + 0.5)), math.max(2, math.floor(ScreenScale(1) + 0.5)), 0
                cornerSafe = inset + cornerLength + math.max(1, math.floor(ScreenScale(0.5) + 0.5))
                local titleTall = math.max(ScreenScale(8), compactTall)
                local titleY = rowY + drawTall - titleTall
                local fittedName, font = ZCityJudgeFitName(ZCityJudgeScramble(WS.GetPrintName(wep)), math.max(0, cardWide - cornerSafe * 2))
                surface.SetFont(font)
                local nameWide, nameTall = surface.GetTextSize(fittedName)
                surface.SetDrawColor(judgeAccent.r, judgeAccent.g, judgeAccent.b, JudgeSelector.Transparent * 45)
                surface.DrawRect(x + ScreenScale(3), titleY, cardWide - ScreenScale(6), 1)
                if JudgeSelector.NameAnimWeapon ~= wep then
                    JudgeSelector.NameAnimWeapon = wep
                    JudgeSelector.NameAnimStarted = nil
                end
                local nameRoom = titleY - rowY - cornerSafe
                local nameReveal = math.Clamp(nameRoom / math.max(1, ScreenScale(3)), 0, 1)
                if nameReveal >= 0.65 then JudgeSelector.NameAnimStarted = JudgeSelector.NameAnimStarted or now end
                local characters = ZCityJudgeUTF8Length(fittedName)
                local duration = math.Clamp(characters * 0.02, 0.14, 0.27)
                local visibleCharacters = JudgeSelector.NameAnimStarted and math.min(characters, math.floor((now - JudgeSelector.NameAnimStarted) / duration * characters)) or 0
                local visibleName = ZCityJudgeUTF8Prefix(fittedName, visibleCharacters)
                render.SetScissorRect(math.ceil(x + cornerSafe), math.ceil(titleY), math.floor(x + cardWide - cornerSafe), math.floor(rowY + drawTall - ScreenScale(1)), true)
                draw.DrawText(visibleName, font, x + (cardWide - nameWide) * 0.5 + 1, titleY + (titleTall - nameTall) * 0.5 - ScreenScale(1) + 1, Color(judgeShadow.r, judgeShadow.g, judgeShadow.b, JudgeSelector.Transparent * nameReveal * 210), TEXT_ALIGN_LEFT)
                draw.DrawText(visibleName, font, x + (cardWide - nameWide) * 0.5, titleY + (titleTall - nameTall) * 0.5 - ScreenScale(1), Color(judgeName.r, judgeName.g, judgeName.b, JudgeSelector.Transparent * nameReveal * 255), TEXT_ALIGN_LEFT)
                render.SetScissorRect(0, 0, 0, 0, false)

                local iconLeft, iconTop = math.ceil(x + cornerSafe), math.ceil(rowY + cornerSafe)
                local iconRight, iconBottom = math.floor(x + cardWide - cornerSafe), math.floor(titleY - ScreenScale(1.25))
                if iconRight > iconLeft and iconBottom > iconTop then
                    render.SetScissorRect(iconLeft, iconTop, iconRight, iconBottom, true)
                    local drawn = ZCityJudgeDrawIcon(wep, iconLeft, iconTop, iconRight - iconLeft, iconBottom - iconTop, JudgeSelector.Transparent * 255, false)
                    if not drawn and wep.DrawWeaponSelection then wep:DrawWeaponSelection(iconLeft, iconTop, iconRight - iconLeft, iconBottom - iconTop, JudgeSelector.Transparent * 230) end
                    render.SetScissorRect(0, 0, 0, 0, false)
                end

                if JudgeSelector.CornerFlashWeapon ~= wep then
                    JudgeSelector.CornerFlashWeapon = wep
                    JudgeSelector.CornerFlashStarted = now
                end
                local age = now - (JudgeSelector.CornerFlashStarted or now)
                local flash = age < 0.1 and math.Clamp(age / 0.1, 0, 1) or age < 0.3 and math.Clamp(1 - (age - 0.1) / 0.2, 0, 1) or 0
                ZCityJudgeCorners(x, rowY, cardWide, drawTall, JudgeSelector.Transparent, flash)
            else
                ZCityJudgeDrawIcon(wep, x, rowY, cardWide, drawTall, JudgeSelector.Transparent * 95, true)
            end
            rowY = rowY + drawTall + rowGap
        end
        x = x + cardWide + columnGap
    end

    local infoWide = math.min(screenWide * 0.22, 320)
    ZCityJudgeDrawInfoPanel(selected, screenWide - infoWide - math.floor(ScreenScale(8) + 0.5), math.floor(screenTall * 0.055 + 0.5), infoWide, JudgeSelector.Transparent)
end

local function ZCityJudgeStep(slots, direction, useSelected)
    local ordered, index = {}, nil
    local selected = useSelected and ZCityJudgeSelectedWeapon(slots) or LocalPlayer():GetActiveWeapon()
    for slot = 0, 5 do
        for position = 0, slots[slot].count - 1 do
            local entry = {slot = slot, position = position, wep = slots[slot][position]}
            ordered[#ordered + 1] = entry
            if entry.wep == selected then index = #ordered end
        end
    end
    if #ordered < 1 then return false end
    index = index or (direction > 0 and 0 or 1)
    local entry = ordered[((index - 1 + direction) % #ordered) + 1]
    JudgeSelector.SelectedSlot, JudgeSelector.SelectedSlotPos = entry.slot, entry.position
    return true
end

local judgeLastBind
local judgeLastBindCode
local judgeLastBindTime = 0

function JudgeSelector.Change(ply, key, pressed, code)
    if pressed == false or not IsValid(ply) or not ply:Alive() or (ply.organism and ply.organism.otrub) then return end
    local active = ply:GetActiveWeapon()
    if IsAiming(ply) or (IsValid(active) and active:GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK)) then return end

    key = string.lower(string.match(tostring(key or ""), "^([^%s;]+)") or "")
    local slot = judgeAcceptKeys[key]
    if not slot and key ~= "invnext" and key ~= "invprev" and key ~= "lastinv" then return end
    if key == "lastinv" and not IsValid(JudgeSelector.LastInv) then return end
    local bindTime = SysTime()
    if slot and key == judgeLastBind and code == judgeLastBindCode and bindTime - judgeLastBindTime < 0.075 then return true end

    local slots = ZCityJudgeWeaponTable(ply)
    if slot and slots[slot - 1].count < 1 then return true end
    judgeLastBind = key
    judgeLastBindCode = code
    judgeLastBindTime = bindTime
    local wasOpen = JudgeSelector.Show > CurTime()
    JudgeSelector.Show = CurTime() + 4
    surface.PlaySound("arc9_eft_shared/weapon_generic_rifle_spin" .. math.random(10) .. ".ogg")
    if slot then
        slot = slot - 1
        JudgeSelector.SelectedSlotPos = wasOpen and JudgeSelector.SelectedSlot == slot and (JudgeSelector.SelectedSlotPos + 1) % slots[slot].count or 0
        JudgeSelector.SelectedSlot = slot
    elseif key == "invnext" then
        ZCityJudgeStep(slots, 1, wasOpen)
    elseif key == "invprev" then
        ZCityJudgeStep(slots, -1, wasOpen)
    else
        JudgeSelector.Show = 0
        local previous = ply:GetActiveWeapon()
        ZCitySelectInventoryWeapon(JudgeSelector.LastInv)
        JudgeSelector.LastInv = previous
    end
    return true
end

function JudgeSelector.Select(ply, cmd)
    if not IsValid(ply) or not ply:Alive() or JudgeSelector.Show <= CurTime() then return end
    if not cmd:KeyDown(IN_ATTACK) and not cmd:KeyDown(IN_ATTACK2) then return end
    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
    if JudgeSelector.Selected and JudgeSelector.Selected > CurTime() then return end

    local target = ZCityJudgeSelectedWeapon()
    local active = ply:GetActiveWeapon()
    if IsValid(target) then
        if target ~= active then JudgeSelector.LastInv = IsValid(active) and active or nil end
        ZCitySelectInventoryWeapon(target)
    end
    JudgeSelector.LastSelectedSlot = JudgeSelector.SelectedSlot
    JudgeSelector.LastSelectedSlotPos = JudgeSelector.SelectedSlotPos
    JudgeSelector.Selected = CurTime() + 0.2
    JudgeSelector.Show = CurTime() + 0.2
    surface.PlaySound("arc9_eft_shared/weapon_generic_spin" .. math.random(1, 10) .. ".ogg")
end

SimpleSelector.Draw = JudgeSelector.Draw
SimpleSelector.Change = JudgeSelector.Change
SimpleSelector.Select = JudgeSelector.Select

WS.BodyAlpha = WS.BodyAlpha or 0
WS.HoldStart = WS.HoldStart or 0
WS.HoldWeapon = WS.HoldWeapon or nil
WS.HoldSlotBind = WS.HoldSlotBind or nil
WS.HoldSlotKeyCode = WS.HoldSlotKeyCode or nil
WS.HoldDuration = 0.62
WS.HolsterAwayDuration = 0.95
WS.HoldDurationNoHolster = 1.15
WS.BackpackHoldDurationFallback = 1.45
WS.BackpackHoldDurationMin = 1.05
WS.BackpackHoldDurationMax = 3.0
WS.BackpackEarlySelect = WS.BackpackEarlySelect or false
WS.BackpackEarlyWeapon = WS.BackpackEarlyWeapon or nil
WS.BackpackEarlySelected = WS.BackpackEarlySelected or false
WS.BackpackPreviousWeapon = WS.BackpackPreviousWeapon or nil
WS.ConfirmProgress = WS.ConfirmProgress or 0

WS.BodyPlaces = {
    pistol = {
        bone = "ValveBiped.Bip01_R_Thigh",
        pos = Vector(0, -2, 1),
        iconOffset = 20
    },
    longgun = {
        bone = "ValveBiped.Bip01_Spine2",
        pos = Vector(5, 8, -4),
        iconOffset = -20
    },
    backpack = {
        bone = "ValveBiped.Bip01_Spine2",
        pos = Vector(0, 0, 0),
        iconOffset = 6,
        frontTorso = true,
        front = 18,
        up = -5,
        right = 0
    },
    pocket = {
        bone = "ValveBiped.Bip01_Pelvis",
        pos = Vector(3.0, 7.5, 1.0),
        iconOffset = -20
    },
    melee = {
        bone = "ValveBiped.Bip01_Pelvis",
        pos = Vector(5.0, 5.0, 0.0),
        iconOffset = -20
    },
    hands = {
        bone = "ValveBiped.Bip01_R_Hand",
        fallbackBone = "ValveBiped.Bip01_Pelvis",
        pos = Vector(0, 0, 0),
        iconOffset = 8
    }
}

WS.BodySquareSize = 116
WS.BodyIconSize = 88

local zcity_slot_square = Color(0, 0, 0, 220)
local zcity_slot_highlight = Color(255, 255, 255, 42)
local zcity_slot_outline = Color(235, 235, 235, 215)
local zcity_slot_progress = Color(0, 0, 0, 255)
local zcity_slot_text = Color(245, 245, 245, 255)
local zcity_slot_icon_tint = Color(255, 255, 255, 255)
local zcity_slot_gradient = Material("vgui/gradient-d")
local ZCityWeaponIconCache = {}

WS.DialAlpha = WS.DialAlpha or 0
WS.DialPop = WS.DialPop or 0
WS.DialAngle = WS.DialAngle or nil

local function ZCityWrapWeaponDescription(text, maxWidth)
    surface.SetFont("ZCity_SuperTiny")

    local lines, current = {}, ""
    for word in string.gmatch(text, "%S+") do
        local candidate = current == "" and word or current .. " " .. word
        if current ~= "" and surface.GetTextSize(candidate) > maxWidth then
            lines[#lines + 1] = current
            current = word
        else
            current = candidate
        end
    end

    if current ~= "" then lines[#lines + 1] = current end
    return lines
end

local function ZCityDrawWeaponDescription(wep, slotX, slotY, slotSize, alpha)
    local description = ZCityGetWeaponDescription(wep)
    if description == "" then return end

    local maxWidth = math.min(ScrW() * 0.34, 460)
    local lines = ZCityWrapWeaponDescription(description, maxWidth - 16)
    if #lines == 0 then return end

    surface.SetFont("ZCity_SuperTiny")
    local _, lineHeight = surface.GetTextSize("Hg")
    local padding = 8
    local width = maxWidth
    local height = lineHeight * #lines + padding * 2
    local x = math.Clamp(slotX + slotSize * 0.5 - width * 0.5, 8, ScrW() - width - 8)
    local belowY = slotY + slotSize + 10
    local y = belowY + height <= ScrH() - 8 and belowY or slotY - height - 10
    y = math.Clamp(y, 8, ScrH() - height - 8)

    surface.SetDrawColor(0, 0, 0, 210 * alpha)
    surface.DrawRect(x, y, width, height)
    surface.SetDrawColor(235, 235, 235, 95 * alpha)
    surface.DrawOutlinedRect(x, y, width, height, 1)

    for index, line in ipairs(lines) do
        local textY = y + padding + (index - 1) * lineHeight
        draw.SimpleTextOutlined(line, "ZCity_SuperTiny", x + width * 0.5, textY, Color(240, 240, 240, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 230 * alpha))
    end
end

local function ZCityWepText(wep, key)
    if not IsValid(wep) then return "" end
    local value = wep[key]
    if isfunction(value) then value = value(wep) end
    return tostring(value or ""):lower()
end

local function ZCityGetBodySlotForWeapon(wep)
    if not IsValid(wep) then return "pocket" end

    local class = wep:GetClass()
    if class == "weapon_hands_sh" or class == "weapon_hands" then return "hands" end

    local category = tonumber(wep.weaponInvCategory or 0) or 0
    if category == 1 then return "longgun" end
    if category == 2 then return "pistol" end
    if category == 3 or category == 5 or category == 6 then return "melee" end

    class = ZCityWepText(wep, "GetClass")
    local printName = ZCityWepText(wep, "GetPrintName")
    local catName = ZCityWepText(wep, "Category")
    local scrappersSlot = ZCityWepText(wep, "ScrappersSlot")

    if scrappersSlot == "secondary"
        or catName:find("pistol", 1, true)
        or class:find("glock", 1, true)
        or class:find("pistol", 1, true)
        or class:find("usp", 1, true)
        or class:find("m9", 1, true)
        or class:find("pl15", 1, true)
        or printName:find("glock", 1, true) then
        return "pistol"
    end

    if scrappersSlot == "primary"
        or catName:find("carbine", 1, true)
        or catName:find("rifle", 1, true)
        or catName:find("shotgun", 1, true)
        or catName:find("smg", 1, true)
        or class:find("ar15", 1, true)
        or class:find("m4", 1, true)
        or class:find("rifle", 1, true)
        or class:find("shotgun", 1, true) then
        return "longgun"
    end

    if wep.IsPistolHoldType then
        return wep:IsPistolHoldType() and "pistol" or "longgun"
    end

    return "pocket"
end


local function ZCityIsBodyHolsterBlocked(ply)
    if not IsValid(ply) then return false end

    if ply:GetNWBool("ZCityBodyHolsterBlocked", false) then return true end

    -- ФОИДбак.
    if ZCityHasBodyAppearanceHolsterBlock then
        return ZCityHasBodyAppearanceHolsterBlock(ply)
    end

    return false
end

local zcityBackpackDurationCache
local function ZCityGetBackpackHoldDuration()
    if zcityBackpackDurationCache then return zcityBackpackDurationCache end

    local duration = 0
    if SoundDuration then
        duration = math.max(
            SoundDuration("sounds/backpack.mp3") or 0,
            SoundDuration("backpack.mp3") or 0
        )
    end

    if duration <= 0 then duration = WS.BackpackHoldDurationFallback or WS.HoldDurationNoHolster or 1.15 end
    zcityBackpackDurationCache = math.Clamp(duration, WS.BackpackHoldDurationMin or 0.85, WS.BackpackHoldDurationMax or 2.4)
    return zcityBackpackDurationCache
end

local function ZCityIsBackpackDrawWeaponForSelector(wep)
    if not IsValid(wep) then return false end
    local place = ZCityGetBodySlotForWeapon(wep)
    return place == "pistol" or place == "longgun"
end

local function ZCityIsHandsWeapon(wep)
    if not IsValid(wep) then return false end
    local class = wep:GetClass()
    return class == "weapon_hands_sh" or class == "weapon_hands"
end

local function ZCityGetWeaponActionDuration(wep, field, fallback, minimum, maximum)
    if not IsValid(wep) then return fallback end

    local base = tonumber(wep[field]) or fallback
    local ergonomics = math.Clamp(tonumber(wep.Ergonomics) or 1, 0.35, 2.5)
    return math.Clamp(base / ergonomics, minimum, maximum)
end

local function ZCityGetSlotHoldDuration(ply, wep)
    local drawingHands = ZCityIsHandsWeapon(wep)
    local duration = drawingHands and 0 or ZCityGetWeaponActionDuration(wep, "CooldownDeploy", WS.HoldDuration or 0.62, 0.35, 2.4)
    local active = IsValid(ply) and ply:GetActiveWeapon() or nil

    -- Empty hands are already ready.  Any real item must be put away before
    -- drawing hands or another item, so object-to-object switches pay both costs.
    if IsValid(active) and active ~= wep and not ZCityIsHandsWeapon(active) then
        local holsterDuration = ZCityGetWeaponActionDuration(active, "CooldownHolster", WS.HolsterAwayDuration or 0.95, 0.35, 2.4)
        duration = drawingHands and holsterDuration or duration + holsterDuration
    end

    if IsValid(wep) and ZCityIsBackpackDrawWeaponForSelector(wep) and ZCityIsBodyHolsterBlocked(ply) then
        return math.max(duration, ZCityGetBackpackHoldDuration())
    end

    if IsValid(wep) and wep.NoHolster then
        return math.Clamp(math.max(duration, WS.HoldDurationNoHolster or 1.15), 0, 4)
    end

    return math.Clamp(duration, 0, 4)
end

local function ZCitySendBackpackDrawCancel(finished)
    net.Start("ZCityBackpackDrawCancel")
        net.WriteBool(finished == true)
    net.SendToServer()
end

local function ZCityCancelBackpackDraw(finished)
    if not WS.BackpackEarlySelect then return end
    ZCitySendBackpackDrawCancel(finished)
end

local function ZCityStartBackpackDraw(ply, wep, duration)
    if not IsValid(ply) or not IsValid(wep) then return end
    if not ZCityIsBodyHolsterBlocked(ply) or not ZCityIsBackpackDrawWeaponForSelector(wep) then return end

    duration = math.Clamp(tonumber(duration) or ZCityGetBackpackHoldDuration(), 0.25, 4)

    net.Start("ZCityBackpackDrawStart")
        net.WriteEntity(wep)
        net.WriteFloat(duration)
    net.SendToServer()
end

local function ZCityPlayBackpackReachPreview(wep, duration)
    if not IsValid(wep) or not wep.PlayAnim or not wep.AnimList then return end
    if (wep.ZCityNextBackpackReachPreview or 0) > CurTime() then return end

    local anim = wep.AnimList["deploy"] and "deploy" or wep.AnimList["draw"] and "draw" or wep.AnimList["idle"] and "idle"
    if not anim then return end

    wep.ZCityNextBackpackReachPreview = CurTime() + math.max((duration or 1.15) * 0.45, 0.35)
    wep:PlayAnim(anim, math.max((duration or 1.15) * 1.7, 1.25), true)
end

function WS.ShouldDelayBackpackDraw(ply, wep)
    return ZCityIsBodyHolsterBlocked(ply) and ZCityIsBackpackDrawWeaponForSelector(wep)
end

function WS.GetBackpackDrawDuration(ply, wep)
    return ZCityGetSlotHoldDuration(ply, wep)
end

function WS.StartBackpackDraw(ply, wep, duration)
    ZCityStartBackpackDraw(ply, wep, duration)
end

function WS.CancelBackpackDraw(finished)
    ZCitySendBackpackDrawCancel(finished)
end

function WS.PlayBackpackReachPreview(wep, duration)
    ZCityPlayBackpackReachPreview(wep, duration)
end

local function ZCityShouldUseBackpackSource(ply, wep, place)
    if not IsValid(ply) or not IsValid(wep) then return false end
    if not ZCityIsBodyHolsterBlocked(ply) then return false end

    return place == "pistol" or place == "longgun" or ZCityIsBackpackDrawWeaponForSelector(wep)
end

local function ZCityGetFlatBodyAng(ent)
    local ang = EyeAngles()
    if IsValid(ent) and ent:IsPlayer() then
        ang = ent:EyeAngles()
    elseif IsValid(ent) then
        ang = ent:GetAngles()
    end

    return Angle(0, ang.y, 0)
end

local function ZCityGetHolsterDataForWeapon(ply, wep, place)
    local data = WS.BodyPlaces[place] or WS.BodyPlaces.pocket

    if ZCityShouldUseBackpackSource(ply, wep, place) then
        local backpack = WS.BodyPlaces.backpack or data
        return {
            bone = backpack.bone,
            fallbackBone = backpack.fallbackBone,
            pos = backpack.pos,
            iconOffset = backpack.iconOffset or 1,
            frontTorso = backpack.frontTorso == true,
            front = backpack.front,
            up = backpack.up,
            right = backpack.right
        }
    end

    if not IsValid(wep) then return data end

    local bone = wep.holsteredBone or data.bone
    local pos = wep.holsteredPos or data.pos

    return {
        bone = bone,
        fallbackBone = data.fallbackBone,
        pos = pos,
        iconOffset = data.iconOffset or 1
    }
end

local function ZCityGetBodyLabelPos(ent, place, wep)
    local owner = IsValid(wep) and wep:GetOwner() or LocalPlayer()
    local data = ZCityGetHolsterDataForWeapon(owner, wep, place)
    local bone = ent:LookupBone(data.bone)
    if not bone and data.fallbackBone then
        bone = ent:LookupBone(data.fallbackBone)
    end
    if not bone then return end

    local matrix = ent:GetBoneMatrix(bone)
    if not matrix then return end

    local pos
    if data.frontTorso then

        local flatAng = ZCityGetFlatBodyAng(IsValid(owner) and owner or ent)
        pos = matrix:GetTranslation()
            + flatAng:Forward() * (data.front or 18)
            + flatAng:Right() * (data.right or 0)
            + flatAng:Up() * (data.up or -5)
    else
        pos = LocalToWorld(data.pos, angle_zero, matrix:GetTranslation(), matrix:GetAngles())
    end

    local dir = EyePos() - pos
    if dir:LengthSqr() > 0.01 then
        dir:Normalize()
        pos = pos + dir * (data.iconOffset or 1)
    else
        local flatAng = ZCityGetFlatBodyAng(ent)
        pos = pos + flatAng:Forward() * (data.iconOffset or 1)
    end

    return pos
end

local function ZCityIsUsableIconValue(icon)
    if icon == nil or icon == false then return false end
    if isstring(icon) then return icon ~= "" and icon ~= "null" end

    local iconType = type(icon)
    if iconType == "IMaterial" then
        local iconText = tostring(icon):lower()
        if iconText:find("null", 1, true) then return false end
        if icon.IsError and icon:IsError() then return false end
        return true
    end

    if isnumber(icon) then return icon > 0 end
    return false
end

local function ZCityMaterialFromPath(path)
    if not isstring(path) or path == "" then return nil end

    path = path:gsub("^materials/", "")
    path = path:gsub("\\", "/")

    -- Material() типа "vgui/icon" и "vgui/icon.png"
    return Material(path, "smooth")
end

local function ZCityGetSWEPSelectIcon(wep)
    if not IsValid(wep) then return nil end

    -- у хомиграда в основномм WepSelectIcon2 + WepSelectIcon2box
    local candidates = {
        { value = wep.WepSelectIcon2, boxed = wep.WepSelectIcon2box },
        { value = wep.WepSelectIcon, boxed = false },
        { value = wep.IconOverride, boxed = true }
    }

    for _, candidate in ipairs(candidates) do
        local icon = candidate.value
        if ZCityIsUsableIconValue(icon) then
            local iconType = type(icon)

            if iconType == "IMaterial" then
                return { kind = "material", value = icon, boxed = candidate.boxed == true }
            end

            if isnumber(icon) then
                return { kind = "texture", value = icon, boxed = candidate.boxed == true }
            end

            if isstring(icon) then
                local mat = ZCityMaterialFromPath(icon)
                if mat and not (mat.IsError and mat:IsError()) then
                    return { kind = "material", value = mat, boxed = candidate.boxed ~= false }
                end
            end
        end
    end

    return nil
end

local function ZCityDrawDialIcon(icon, centerX, centerY, width, alpha)
    if not icon then return end

    local height = icon.boxed and width or width * 0.55
    local x = math.floor(centerX - width * 0.5)
    local y = math.floor(centerY - height * 0.5)

    surface.SetDrawColor(0, 0, 0, 185 * alpha)
    if icon.kind == "material" then
        surface.SetMaterial(icon.value)
    else
        surface.SetTexture(icon.value)
    end
    surface.DrawTexturedRect(x + 2, y + 2, width, height)

    surface.SetDrawColor(245, 245, 245, 255 * alpha)
    if icon.kind == "material" then
        surface.SetMaterial(icon.value)
    else
        surface.SetTexture(icon.value)
    end
    surface.DrawTexturedRect(x, y, width, height)

    return x, y, width, height
end

function WS.DrawDialSelector(ply)
    local enabled = ZCityGetInventorySystem() == 2 and IsValid(ply) and ply:Alive()
    local open = enabled and WS.Show > CurTime()
    local animationSpeed = math.Clamp(FrameTime() * 14, 0, 1)
    WS.DialAlpha = Lerp(animationSpeed, WS.DialAlpha or 0, open and 1 or 0)
    WS.DialPop = Lerp(animationSpeed, WS.DialPop or 0, open and 1 or 0)

    if not enabled or WS.DialAlpha < 0.01 then return end

    local weapons = WS.GetWeaponTable(ply)
    if not weapons then return end

    local occupied = {}
    local selectedIndex
    for slot = 0, 5 do
        local slotWeapons = weapons[slot]
        if slotWeapons and IsValid(slotWeapons[0]) then
            occupied[#occupied + 1] = {
                slot = slot,
                weapons = slotWeapons
            }
            if slot == WS.SelectedSlot then selectedIndex = #occupied end
        end
    end

    if #occupied == 0 then return end
    if not selectedIndex then
        selectedIndex = 1
        WS.SelectedSlot = occupied[1].slot
        WS.SelectedSlotPos = 0
    end

    local step = 360 / #occupied
    local focusAngle = 135
    local targetAngle = focusAngle - (selectedIndex - 1) * step
    if WS.DialAngle == nil then
        WS.DialAngle = targetAngle
    else
        WS.DialAngle = WS.DialAngle + math.AngleDifference(targetAngle, WS.DialAngle) * math.Clamp(FrameTime() * 11, 0, 1)
    end

    local uiScale = math.Clamp(ScrH() / 1080, 0.75, 1.1)
    local popScale = Lerp(WS.DialPop, 0.82, 1)
    local centerX = ScrW() - 112 * uiScale
    local centerY = ScrH() - 112 * uiScale
    local radius = 59 * uiScale * popScale
    local alpha = WS.DialAlpha

    local function drawSlot(data, focused)
        local slotPosition
        for index, candidate in ipairs(occupied) do
            if candidate == data then
                slotPosition = index
                break
            end
        end

        local angle = math.rad(WS.DialAngle + (slotPosition - 1) * step)
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        local slotAlpha = alpha * (focused and 1 or 0.48)
        local iconWidth = (focused and 68 or 48) * uiScale * popScale
        local selectedPosition = math.Clamp(WS.SelectedSlotPos or 0, 0, #data.weapons)
        local wep = focused and (data.weapons[selectedPosition] or data.weapons[0]) or data.weapons[0]
        local iconX, iconY, iconW, iconH = ZCityDrawDialIcon(ZCityGetSWEPSelectIcon(wep), x, y, iconWidth, slotAlpha)

        draw.SimpleTextOutlined(tostring(data.slot + 1), "ZCity_SuperTiny", x - iconWidth * 0.52, y - iconWidth * 0.45, Color(245, 245, 245, 255 * slotAlpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 220 * slotAlpha))

        local additional = #data.weapons
        if additional > 0 then
            local badgeX = iconX and (iconX + iconW) or (x + iconWidth * 0.5)
            local badgeY = iconY and (iconY + iconH) or (y + iconWidth * 0.3)
            draw.SimpleTextOutlined("+" .. additional, "ZCity_SuperTiny", badgeX, badgeY, Color(245, 245, 245, 255 * slotAlpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 235 * slotAlpha))
        end
    end

    for _, data in ipairs(occupied) do
        if data.slot ~= WS.SelectedSlot then drawSlot(data, false) end
    end
    drawSlot(occupied[selectedIndex], true)
end

local function ZCityDrawOutlinedBox(x, y, w, h, outlineWidth)
    outlineWidth = outlineWidth or 2
    for i = 0, outlineWidth - 1 do
        surface.DrawOutlinedRect(x + i, y + i, w - i * 2, h - i * 2)
    end
end

local function ZCityAlpha(color, alphaMul)
    return Color(color.r, color.g, color.b, math.Clamp((color.a or 255) * alphaMul, 0, 255))
end

local function ZCityDrawProgressStroke(x, y, w, h, thickness, progress)
    progress = math.Clamp(progress or 0, 0, 1)
    if progress <= 0 then return end

    local remaining = (w * 2 + h * 2) * progress

    local function drawSegment(sx, sy, sw, sh, amount, horizontal, reverse)
        if amount <= 0 then return 0 end
        local len = math.min(amount, horizontal and sw or sh)

        if horizontal then
            if reverse then
                surface.DrawRect(sx + sw - len, sy, len, sh)
            else
                surface.DrawRect(sx, sy, len, sh)
            end
        else
            if reverse then
                surface.DrawRect(sx, sy + sh - len, sw, len)
            else
                surface.DrawRect(sx, sy, sw, len)
            end
        end

        return amount - len
    end

    remaining = drawSegment(x, y, w, thickness, remaining, true, false)
    remaining = drawSegment(x + w - thickness, y, thickness, h, remaining, false, false)
    remaining = drawSegment(x, y + h - thickness, w, thickness, remaining, true, true)
    drawSegment(x, y, thickness, h, remaining, false, true)
end

local function ZCityGetBodyScreenPosition(pos, size)
    local screenWidth, screenHeight = ScrW(), ScrH()
    local centerX, centerY = screenWidth * 0.5, screenHeight * 0.5
    local margin = size * 0.5 + 28
    local screen = pos:ToScreen()
    local onScreen = screen.visible
        and screen.x >= margin and screen.x <= screenWidth - margin
        and screen.y >= margin and screen.y <= screenHeight - margin

    if onScreen then
        return screen.x, screen.y, false, 0, 0
    end

    local directionX, directionY
    if screen.visible then
        directionX = screen.x - centerX
        directionY = screen.y - centerY
    else
        local delta = pos - EyePos()
        local eyeAngles = EyeAngles()
        directionX = delta:Dot(eyeAngles:Right())
        directionY = -delta:Dot(eyeAngles:Up())
        if delta:Dot(eyeAngles:Forward()) < 0 then
            directionX = -directionX
            directionY = -directionY
        end
    end

    local length = math.sqrt(directionX * directionX + directionY * directionY)
    if length < 0.001 then
        directionX, directionY, length = 0, 1, 1
    end

    local normalX, normalY = directionX / length, directionY / length
    local edgeScale = math.min(
        (centerX - margin) / math.max(math.abs(normalX), 0.001),
        (centerY - margin) / math.max(math.abs(normalY), 0.001)
    )

    return centerX + normalX * edgeScale, centerY + normalY * edgeScale, true, normalX, normalY
end

local function ZCityDrawOffscreenPointer(centerX, centerY, size, directionX, directionY, alpha)
    local perpendicularX, perpendicularY = -directionY, directionX
    local tipDistance = size * 0.5 + 18
    local baseDistance = size * 0.5 + 5
    local halfWidth = 7
    local tipX = centerX + directionX * tipDistance
    local tipY = centerY + directionY * tipDistance
    local baseX = centerX + directionX * baseDistance
    local baseY = centerY + directionY * baseDistance
    local leftX = baseX + perpendicularX * halfWidth
    local leftY = baseY + perpendicularY * halfWidth
    local rightX = baseX - perpendicularX * halfWidth
    local rightY = baseY - perpendicularY * halfWidth

    draw.NoTexture()
    surface.SetDrawColor(0, 0, 0, 240 * alpha)
    surface.DrawPoly({
        {x = tipX, y = tipY},
        {x = leftX, y = leftY},
        {x = rightX, y = rightY}
    })
    surface.SetDrawColor(235, 235, 235, 180 * alpha)
    surface.DrawLine(tipX, tipY, leftX, leftY)
    surface.DrawLine(leftX, leftY, rightX, rightY)
    surface.DrawLine(rightX, rightY, tipX, tipY)
end

local function ZCityDrawBodySquare(place, entry, ent, alpha, presentation)
    if not entry then return end

    presentation = presentation or {}

    local pos = ZCityGetBodyLabelPos(ent, place, presentation.anchorWep or entry.wep)
    if not pos then return end

    local dist = EyePos():Distance(pos)
    if dist > 220 then return end

    local aMul = math.Clamp((alpha or 0) * (presentation.opacity or 1), 0, 1)
    local brightness = math.Clamp(presentation.brightness or 1, 0, 1)
    local scale = math.Clamp(presentation.scale or 1, 0.45, 1)
    local size = (WS.BodySquareSize or 116) * scale
    local iconSize = (WS.BodyIconSize or 88) * scale
    local screenX, screenY, isOffscreen, directionX, directionY = ZCityGetBodyScreenPosition(pos, size)
    local offsetX = presentation.offsetX or 0
    local offsetY = presentation.offsetY or 0
    if isOffscreen then
        offsetX = offsetX - directionX * math.abs(offsetX)
        offsetY = offsetY - directionY * math.abs(offsetY)
    end
    local cardMargin = size * 0.5 + 5
    screenX = math.Clamp(screenX + offsetX, cardMargin, ScrW() - cardMargin)
    screenY = math.Clamp(screenY + offsetY, cardMargin, ScrH() - cardMargin)
    local x = math.floor(screenX - size / 2)
    local y = math.floor(screenY - size / 2)
    local icon = ZCityGetSWEPSelectIcon(entry.wep)
    local progress = WS.ConfirmProgress or 0

    surface.SetDrawColor(ZCityAlpha(zcity_slot_square, aMul))
    surface.DrawRect(x, y, size, size)

    surface.SetMaterial(zcity_slot_gradient)
    surface.SetDrawColor(ZCityAlpha(zcity_slot_highlight, aMul))
    surface.DrawTexturedRect(x, y, size, size)

    if presentation.dark then
        surface.SetDrawColor(0, 0, 0, (presentation.shadowAlpha or 135) * aMul)
        surface.DrawRect(x, y, size, size)
    end

    surface.SetDrawColor(ZCityAlpha(zcity_slot_outline, aMul * brightness))
    ZCityDrawOutlinedBox(x, y, size, size, 3)

    if presentation.progress ~= false then
        surface.SetDrawColor(ZCityAlpha(zcity_slot_progress, aMul))
        ZCityDrawProgressStroke(x, y, size, size, 4, progress)
    end

    if icon then
        local drawW = iconSize
        local drawH = icon.boxed and iconSize or math.floor(iconSize * 0.56)
        local drawX = math.floor(screenX - drawW / 2)
        local drawY = math.floor(screenY - drawH / 2 - 8)

        surface.SetDrawColor(
            zcity_slot_icon_tint.r * brightness,
            zcity_slot_icon_tint.g * brightness,
            zcity_slot_icon_tint.b * brightness,
            zcity_slot_icon_tint.a * aMul
        )
        if icon.kind == "material" then
            surface.SetMaterial(icon.value)
            surface.DrawTexturedRect(drawX, drawY, drawW, drawH)
        elseif icon.kind == "texture" then
            surface.SetTexture(icon.value)
            surface.DrawTexturedRect(drawX, drawY, drawW, drawH)
        end
    end

    local labelY = y + size - 25
    surface.SetDrawColor(0, 0, 0, 175 * aMul)
    surface.DrawRect(x + 3, labelY, size - 6, 22)
    draw.SimpleTextOutlined(entry.name or "", "ZCity_SuperTiny", screenX, labelY + 11, ZCityAlpha(zcity_slot_text, aMul * brightness), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220 * aMul))

    if entry.slotNumber then
        draw.SimpleTextOutlined(tostring(entry.slotNumber), "ZCity_SuperTiny", x + 8, y + 8, ZCityAlpha(zcity_slot_text, aMul * brightness), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220 * aMul))
    end

    if isOffscreen and presentation.pointer ~= false then
        ZCityDrawOffscreenPointer(screenX, screenY, size, directionX, directionY, aMul)
    end

    return x, y, size
end

function WS.DrawBodySlotSelector(ply)
    if not IsValid(ply) or not ply:Alive() or ZCityGetInventorySystem() ~= 0 then
        WS.BodyAlpha = Lerp(FrameTime() * 10, WS.BodyAlpha or 0, 0)
        return
    end

    local target = WS.Show > CurTime() and 1 or 0
    WS.BodyAlpha = Lerp(FrameTime() * 10, WS.BodyAlpha or 0, target)
    if WS.BodyAlpha < 0.01 then return end

    local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
    if not IsValid(ent) then return end

    local weapons = WS.GetWeaponTable(ply)
    local slotWeapons = weapons and weapons[WS.SelectedSlot]
    if not slotWeapons or not slotWeapons[0] then return end

    WS.SelectedSlotPos = math.Clamp(WS.SelectedSlotPos or 0, 0, #slotWeapons)
    local selected = slotWeapons[WS.SelectedSlotPos] or slotWeapons[0]
    if not IsValid(selected) then return end

    local visible = {}
    local minDuration, maxDuration
    for index = 0, #slotWeapons do
        local wep = slotWeapons[index]
        if IsValid(wep) then
            local duration = ZCityGetSlotHoldDuration(ply, wep)
            visible[#visible + 1] = {wep = wep, duration = duration}
            minDuration = minDuration and math.min(minDuration, duration) or duration
            maxDuration = maxDuration and math.max(maxDuration, duration) or duration
        end
    end

    -- The row runs from quick-access gear to slow bag draws. Slower items get
    -- a deeper shadow, so players can read the unholster cost before choosing.
    table.sort(visible, function(a, b)
        if a.duration ~= b.duration then return a.duration < b.duration end
        return a.wep:EntIndex() < b.wep:EntIndex()
    end)

    -- Keep each selectable card distinct; the old overlap made it unclear
    -- which item the scroll wheel had focused.
    local rowStep = WS.BodySquareSize * 1.08
    for index, item in ipairs(visible) do
        local durationK = maxDuration > minDuration and math.Clamp((item.duration - minDuration) / (maxDuration - minDuration), 0, 1) or 0
        local isSelected = item.wep == selected
        local place = ZCityGetBodySlotForWeapon(item.wep)
        local drawX, drawY, drawSize = ZCityDrawBodySquare(place, {
            name = WS.GetPrintName(item.wep),
            selected = isSelected,
            wep = item.wep,
            slotNumber = (tonumber(item.wep.Slot) or 0) + 1
        }, ent, WS.BodyAlpha, {
            anchorWep = item.wep,
            scale = isSelected and 1 or 0.82,
            opacity = isSelected and 1 or 0.86,
            brightness = isSelected and 1 or (0.68 - durationK * 0.18),
            offsetX = (index - (#visible + 1) / 2) * rowStep,
            dark = not isSelected,
            shadowAlpha = 70 + durationK * 145,
            pointer = isSelected,
            progress = isSelected
        })

        if isSelected and drawX and drawY and drawSize then
            ZCityDrawWeaponDescription(item.wep, drawX, drawY, drawSize, WS.BodyAlpha)
        end

    end
end

local tAcceptKeys = {
    ["slot1"] = 1,
    ["slot2"] = 2,
    ["slot3"] = 3,
    ["slot4"] = 4,
    ["slot5"] = 5,
    ["slot6"] = 6,
}

local tSlotFallbackKeys = {
    ["slot1"] = KEY_1,
    ["slot2"] = KEY_2,
    ["slot3"] = KEY_3,
    ["slot4"] = KEY_4,
    ["slot5"] = KEY_5,
    ["slot6"] = KEY_6,
}

local function ZCityResetSlotHold(fadeOut, finished)
    ZCityCancelBackpackDraw(finished == true)

    WS.HoldStart = 0
    WS.HoldWeapon = nil
    WS.HoldSlotBind = nil
    WS.HoldSlotKeyCode = nil
    WS.BackpackEarlySelect = false
    WS.BackpackEarlyWeapon = nil
    WS.BackpackEarlySelected = false
    WS.BackpackPreviousWeapon = nil
    if fadeOut then
        WS.ConfirmProgress = Lerp(FrameTime() * 14, WS.ConfirmProgress or 0, 0)
    else
        WS.ConfirmProgress = 0
    end
end

local function ZCityGetHandsWeapon(ply)
    local hands = ply:GetWeapon("weapon_hands_sh")
    if IsValid(hands) then return hands end

    hands = ply:GetWeapon("weapon_hands")
    return IsValid(hands) and hands or nil
end

local function ZCityBeginHeldSelection(ply, selectedWep, bind, code)
    if not IsValid(selectedWep) then return end

    ZCityCancelBackpackDraw(false)
    WS.HoldStart = CurTime()
    WS.HoldWeapon = selectedWep
    WS.HoldSlotBind = bind
    WS.HoldSlotKeyCode = code or tSlotFallbackKeys[bind]
    WS.BackpackEarlySelect = ZCityIsBodyHolsterBlocked(ply) and ZCityIsBackpackDrawWeaponForSelector(selectedWep)
    WS.BackpackEarlyWeapon = WS.BackpackEarlySelect and selectedWep or nil
    WS.BackpackEarlySelected = false
    WS.BackpackPreviousWeapon = WS.BackpackEarlySelect and ply:GetActiveWeapon() or nil
    WS.ConfirmProgress = 0

    if WS.BackpackEarlySelect then
        ZCityStartBackpackDraw(ply, selectedWep, ZCityGetSlotHoldDuration(ply, selectedWep))
    end
end

local function ZCityPutActiveWeaponAway(ply, activeWep, bind, code)
    local hands = ZCityGetHandsWeapon(ply)
    if not IsValid(hands) or not IsValid(activeWep) or ZCityIsHandsWeapon(activeWep) then return false end

    local weapons = WS.GetWeaponTable(ply)
    for slot = 0, 5 do
        for position = 0, #(weapons[slot] or {}) do
            if weapons[slot][position] == hands then
                WS.SelectedSlot = slot
                WS.SelectedSlotPos = position
                WS.LastInv = activeWep
                WS.Show = CurTime() + 4
                ZCityBeginHeldSelection(ply, hands, bind, code)
                return true
            end
        end
    end

    return false
end

local function ZCityIsHeldSlotKeyDown()
    if WS.HoldSlotKeyCode and input.IsKeyDown(WS.HoldSlotKeyCode) then return true end

    local fallback = WS.HoldSlotBind and tSlotFallbackKeys[WS.HoldSlotBind]
    return fallback and input.IsKeyDown(fallback) or false
end

--[[
    Table:
        [1]	=	Weapon [52][weapon_hands_sh]
        [2]	=	Weapon [117][weapon_bigconsumable]
        [3]	=	Weapon [121][weapon_handcuffs_key]
        [4]	=	Weapon [122][weapon_handcuffs]
        [5]	=	Weapon [123][weapon_traitor_poison1]
        [6]	=	Weapon [124][weapon_traitor_suit]
        [7]	=	Weapon [125][weapon_matches]

    TableFormated:
    [0]:
		[0]	=	Weapon [126][weapon_physgun]
		[1]	=	Weapon [52][weapon_hands_sh]
    [1]:
    [2]:
    [3]:
		[1]	=	Weapon [117][weapon_bigconsumable]
		[2]	=	Weapon [121][weapon_handcuffs_key]
		[3]	=	Weapon [122][weapon_handcuffs]
		[4]	=	Weapon [123][weapon_traitor_poison1]
		[5]	=	Weapon [125][weapon_matches]
    [4]:
    [5]:
		[1]	=	Weapon [124][weapon_traitor_suit]
--]]

local function GetUpper(Weapons)
    if #LocalPlayer():GetWeapons() < 1 then return end
    WS.SelectedSlot = WS.SelectedSlot < 0 and #Weapons or WS.SelectedSlot - 1
    WS.SelectedSlotPos = Weapons[WS.SelectedSlot] and #Weapons[WS.SelectedSlot] or 0

    --print(WS.SelectedSlot, WS.SelectedSlotPos)

    if Weapons[WS.SelectedSlot] == nil or Weapons[WS.SelectedSlot][WS.SelectedSlotPos] == nil then
        GetUpper(Weapons)
    end
end

local function GetDown(Weapons)
    if #LocalPlayer():GetWeapons() < 1 then return end
    WS.SelectedSlot = WS.SelectedSlot > #Weapons and 0 or WS.SelectedSlot + 1
    WS.SelectedSlotPos = 0

    --print(WS.SelectedSlot, WS.SelectedSlotPos)

    if Weapons[WS.SelectedSlot] == nil or Weapons[WS.SelectedSlot][WS.SelectedSlotPos] == nil then
        GetDown(Weapons)
    end
end

local function get_active_tool(ply, tool)
    local activeWep = ply:GetActiveWeapon()
    if not IsValid(activeWep) or activeWep:GetClass() ~= "gmod_tool" or activeWep.Mode ~= tool then return end
    return activeWep:GetToolObject(tool)
end

local function canUseSelector(ply)
    local wep = ply:GetActiveWeapon()
    local tool = get_active_tool(ply, "submaterial")
    if tool and IsValid(ply:GetEyeTraceNoCursor().Entity) then
        return true
    end

    return IsAiming(ply) or (IsValid(wep) and wep:GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK)) or (lply.organism and lply.organism.pain and lply.organism.pain > 100) or ZCityGetInventorySystem() == 2
end

function WS.ChangeSelectionWep( ply, key, pressed, code )
    local inventorySystem = ZCityGetInventorySystem()
    if inventorySystem == 1 or inventorySystem == 2 then
        ZCityResetSlotHold(false)
        if pressed == false then
            if inventorySystem == 2 and (tAcceptKeys[key] or key == "invnext" or key == "invprev" or key == "lastinv") then
                return true
            end
            return
        end
        if SimpleSelector.Change then
            local result = SimpleSelector.Change(ply, key, pressed, code)
            if inventorySystem == 2 and (tAcceptKeys[key] or key == "invnext" or key == "invprev" or key == "lastinv") then
                return true
            end
            return result
        end
        return
    end

    local iPos = tAcceptKeys[key]
    if pressed == false then
        if iPos and WS.HoldSlotBind == key then
            ZCityResetSlotHold(true)
        end
        return
    end

    if not IsValid( ply ) or not ply:Alive() then return end
    if ply.organism and ply.organism.otrub then return end

    if iPos then
        local requestedSlot = iPos - 1
        local activeWep = ply:GetActiveWeapon()
        local activeSlot = IsValid(activeWep) and math.Clamp(tonumber(activeWep.Slot) or 0, 0, 5) or -1
        local focusedWep = WS.Show > CurTime() and WS.SelectedSlot == requestedSlot and WS.GetSelectedWeapon() or nil
        if activeSlot == requestedSlot and (not IsValid(focusedWep) or focusedWep == activeWep)
            and ZCityPutActiveWeaponAway(ply, activeWep, key, code) then
            return true
        end
    end

    if canUseSelector( ply ) then return end
    --print(canUseSelector( ply ))
    --print("Table")
    --PrintTable( WS.GetWeaponTable( ply ) )
    if iPos or key == "invnext" or key == "invprev" or key == "lastinv" then

        local Weapons = WS.GetWeaponTable( ply )

        local selectorWasOpen = WS.Show > CurTime()
        WS.Show = CurTime() + 4
        --print(key)
        surface.PlaySound("arc9_eft_shared/weapon_generic_rifle_spin"..math.random(10)..".mp3")
        if iPos then
            iPos = iPos - 1
            if not Weapons[iPos] or not Weapons[iPos][0] then return true end

            local preserveSelection = selectorWasOpen and WS.SelectedSlot == iPos
            WS.SelectedSlotPos = preserveSelection and math.Clamp(WS.SelectedSlotPos or 0, 0, #Weapons[iPos]) or 0
            WS.SelectedSlot = iPos

            local selectedWep = WS.GetSelectedWeapon()
            ZCityBeginHeldSelection(ply, selectedWep, key, code)
            --print(WS.SelectedSlotPos)
            --print(iPos)
            --print( Weapons[WS.SelectedSlot][WS.SelectedSlotPos] )
        elseif key == "invprev" then
            local slotWeapons = Weapons[WS.SelectedSlot]
            if WS.Show > CurTime() and WS.HoldSlotBind and slotWeapons and #slotWeapons > 0 then
                local count = #slotWeapons + 1
                WS.SelectedSlotPos = (WS.SelectedSlotPos - 1) % count
                ZCityBeginHeldSelection(ply, slotWeapons[WS.SelectedSlotPos], WS.HoldSlotBind, WS.HoldSlotKeyCode)
                return true
            end

            WS.SelectedSlotPos = WS.SelectedSlotPos - 1
            --print(WS.SelectedSlotPos)
            if Weapons[WS.SelectedSlot] and WS.SelectedSlotPos < 0  then
                GetUpper(Weapons)
            end
            ZCityResetSlotHold(false)
            --WS.SelectedSlot = Weapons[WS.SelectedSlot] and #Weapons[WS.SelectedSlot] > (WS.SelectedSlotPos + 1) and WS.SelectedSlot + 1 or WS.SelectedSlot + 1 > #Weapons - 1 and 0 or 0
        elseif key == "invnext" then
            local slotWeapons = Weapons[WS.SelectedSlot]
            if WS.Show > CurTime() and WS.HoldSlotBind and slotWeapons and #slotWeapons > 0 then
                local count = #slotWeapons + 1
                WS.SelectedSlotPos = (WS.SelectedSlotPos + 1) % count
                ZCityBeginHeldSelection(ply, slotWeapons[WS.SelectedSlotPos], WS.HoldSlotBind, WS.HoldSlotKeyCode)
                return true
            end

            WS.SelectedSlotPos = WS.SelectedSlotPos + 1
            --print(WS.SelectedSlotPos)
            if Weapons[WS.SelectedSlot] and WS.SelectedSlotPos > #Weapons[WS.SelectedSlot] then
                GetDown(Weapons)
            end
            ZCityResetSlotHold(false)
        elseif key == "lastinv" and IsValid(WS.LastInv) then
            WS.Show = 0
            WS.LastInv = WS.LastInv or "weapon_hands_sh"
            local oldwep = ply:GetActiveWeapon()
            ZCitySelectInventoryWeapon(WS.LastInv)
            WS.LastInv = oldwep
        end

        return true
    end
end

function WS.SetActuallyWeapon( ply, cmd )
    local inventorySystem = ZCityGetInventorySystem()
    if inventorySystem == 1 or inventorySystem == 2 then
        ZCityResetSlotHold(false)
        if SimpleSelector.Select then return SimpleSelector.Select(ply, cmd) end
        return
    end

    if inventorySystem ~= 0 or not IsValid( ply ) or not ply:Alive() then
        ZCityResetSlotHold(false)
        return
    end

    local selectedWep = WS.GetSelectedWeapon()
    local holdingConfirm = WS.Show > CurTime() and IsValid(WS.HoldWeapon) and IsValid(selectedWep) and selectedWep == WS.HoldWeapon
        and ZCityIsHeldSlotKeyDown()

    if not holdingConfirm then
        ZCityResetSlotHold(true)
        return
    end

    if WS.Selected and WS.Selected > CurTime() then
        WS.ConfirmProgress = 0
        return
    end

    WS.Show = CurTime() + 0.25

    local holdDuration = ZCityGetSlotHoldDuration(ply, selectedWep)
    local progress = math.Clamp((CurTime() - (WS.HoldStart or CurTime())) / holdDuration, 0, 1)
    WS.ConfirmProgress = Lerp(FrameTime() * 18, WS.ConfirmProgress or 0, progress)

    if WS.BackpackEarlySelect and WS.BackpackEarlyWeapon == selectedWep then
        ZCityPlayBackpackReachPreview(selectedWep, holdDuration)
    end

    if progress >= 1 then
        if WS.BackpackEarlySelect and IsValid(WS.BackpackPreviousWeapon) then
            WS.LastInv = WS.BackpackPreviousWeapon
        else
            WS.LastInv = WS.LastInv ~= ply:GetActiveWeapon() and WS.LastInv or ply:GetActiveWeapon()
        end
        if ply:GetActiveWeapon() ~= selectedWep then
            ZCitySelectInventoryWeapon(selectedWep)
        end

        WS.LastSelectedSlot = WS.SelectedSlot
        WS.LastSelectedSlotPos = WS.SelectedSlotPos
        WS.Selected = CurTime() + 0.2
        WS.Show = CurTime() + 0.2
        ZCityResetSlotHold(false, true)
        surface.PlaySound("arc9_eft_shared/weapon_generic_spin"..math.random(1,10)..".mp3")
    end
end

hook.Add( "PlayerBindPress", "WeaponSelector_PlayerBindPress", WS.ChangeSelectionWep )

hook.Add( "HUDPaint", "WeaponSelector_Draw", function()
    WS.WeaponSelectorDraw( LocalPlayer() )
    WS.DrawBodySlotSelector( LocalPlayer() )
    WS.DrawDialSelector( LocalPlayer() )
end)

hook.Add( "StartCommand", "WeaponSelector_StartCommand", WS.SetActuallyWeapon )

local tHideElements = {
    ["CHudWeaponSelection"] = true
}

hook.Add("HUDShouldDraw", "WeaponSelector_HUDShouldDraw", function(sElementName)
    if tHideElements[sElementName] then return false end
end)

-- Я ТАК ЗАДОЛБАЛСЯ ПРОСТО УБЕЙТЕ МЕНЯ ХАХАХАХАХАХАХАХАХАХААХАХАХАХАХАХА
-- ПОЛЧАСА Я ПЫТАЛСЯ СДЕЛАТЬ НОРМЛАЬНОЕ ПЕРЕКЛЮЧЕНИЕ ГОВНА!!!
-- ЗАТО ПОЛУЧИЛОСЬ!!!!
-- УЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭ
--[[
    /\_/\
    |_ _|
    |   |__
   /_|_____\ -- IT'S SO OVER
--]]
