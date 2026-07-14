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
    Select = WS.SetActuallyWeapon
}

local function ZCityGetInventorySystem()
    return math.Clamp(GetGlobalInt("InventorySystem", 0), 0, 2)
end

function WS.GetPrintName( self )
	local class = self:GetClass()
	local phrase = language.GetPhrase(class)
	return phrase ~= class and phrase or self:GetPrintName()
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

function WS.GetWeaponTable( ply )
    if not IsValid( ply ) or not ply:Alive() then return end
    local WeaponsGet = ply:GetWeapons()
    local FormatedTable = {
        [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {},
    }

    table.sort(WeaponsGet, function(a, b) return (a.SlotPos or 0) > (b.SlotPos or 0) end)

    for k,wep in ipairs(WeaponsGet) do
        local tTbl = FormatedTable[wep.Slot or 0]
        local iMinPos = math.min( (wep.SlotPos and wep.SlotPos) or 1, ((#tTbl or 0) + 1)) - 1
        local iPos = tTbl[ iMinPos ] and #tTbl + 1 or iMinPos
        tTbl[ iPos ] = wep
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
    }
}

WS.BodySquareSize = 116
WS.BodyIconSize = 88

local zcity_slot_square = Color(0, 0, 0, 220)
local zcity_slot_highlight = Color(255, 255, 255, 42)
local zcity_slot_outline = Color(235, 235, 235, 215)
local zcity_slot_progress = Color(245, 245, 245, 245)
local zcity_slot_text = Color(245, 245, 245, 255)
local zcity_slot_icon_tint = Color(255, 255, 255, 255)
local zcity_slot_gradient = Material("vgui/gradient-d")
local ZCityWeaponIconCache = {}

local function ZCityWepText(wep, key)
    if not IsValid(wep) then return "" end
    local value = wep[key]
    if isfunction(value) then value = value(wep) end
    return tostring(value or ""):lower()
end

local function ZCityGetBodySlotForWeapon(wep)
    if not IsValid(wep) then return "pocket" end

    local category = tonumber(wep.weaponInvCategory or 0) or 0
    if category == 1 then return "longgun" end
    if category == 2 then return "pistol" end
    if category == 3 or category == 5 or category == 6 then return "melee" end

    local class = ZCityWepText(wep, "GetClass")
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

local function ZCityGetSlotHoldDuration(ply, wep)
    local duration = WS.HoldDuration or 0.62

    if IsValid(ply) and ZCityIsHandsWeapon(wep) then
        local active = ply:GetActiveWeapon()
        if IsValid(active) and ZCityIsBackpackDrawWeaponForSelector(active) then
            return WS.HolsterAwayDuration or 0.95
        end
    end

    if IsValid(wep) and ZCityIsBackpackDrawWeaponForSelector(wep) and ZCityIsBodyHolsterBlocked(ply) then
        return ZCityGetBackpackHoldDuration()
    end

    return duration
end

local function ZCityCancelBackpackDraw(finished)
    if not WS.BackpackEarlySelect then return end

    net.Start("ZCityBackpackDrawCancel")
        net.WriteBool(finished == true)
    net.SendToServer()
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
        pos = pos,
        iconOffset = data.iconOffset or 1
    }
end

local function ZCityGetBodyLabelPos(ent, place, wep)
    local owner = IsValid(wep) and wep:GetOwner() or LocalPlayer()
    local data = ZCityGetHolsterDataForWeapon(owner, wep, place)
    local bone = ent:LookupBone(data.bone)
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

local function ZCityDrawBodySquare(place, entry, ent, alpha)
    if not entry then return end

    local pos = ZCityGetBodyLabelPos(ent, place, entry.wep)
    if not pos then return end

    local dist = EyePos():Distance(pos)
    if dist > 220 then return end

    local screen = pos:ToScreen()
    if not screen.visible then return end

    local aMul = math.Clamp(alpha or 0, 0, 1)
    local size = WS.BodySquareSize or 116
    local iconSize = WS.BodyIconSize or 88
    local x = math.floor(screen.x - size / 2)
    local y = math.floor(screen.y - size / 2)
    local icon = ZCityGetSWEPSelectIcon(entry.wep)
    local progress = WS.ConfirmProgress or 0

    surface.SetDrawColor(ZCityAlpha(zcity_slot_square, aMul))
    surface.DrawRect(x, y, size, size)

    surface.SetMaterial(zcity_slot_gradient)
    surface.SetDrawColor(ZCityAlpha(zcity_slot_highlight, aMul))
    surface.DrawTexturedRect(x, y, size, size)

    surface.SetDrawColor(ZCityAlpha(zcity_slot_outline, aMul))
    ZCityDrawOutlinedBox(x, y, size, size, 3)

    surface.SetDrawColor(ZCityAlpha(zcity_slot_progress, aMul))
    ZCityDrawProgressStroke(x, y, size, size, 4, progress)

    if icon then
        local drawW = iconSize
        local drawH = icon.boxed and iconSize or math.floor(iconSize * 0.56)
        local drawX = math.floor(screen.x - drawW / 2)
        local drawY = math.floor(screen.y - drawH / 2 - 8)

        surface.SetDrawColor(ZCityAlpha(zcity_slot_icon_tint, aMul))
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
    draw.SimpleTextOutlined(entry.name or "", "ZCity_SuperTiny", screen.x, labelY + 11, ZCityAlpha(zcity_slot_text, aMul), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220 * aMul))
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

    local selected = WS.GetSelectedWeapon()
    if not IsValid(selected) or selected:GetClass() == "weapon_hands_sh" then return end

    local place = ZCityGetBodySlotForWeapon(selected)
    ZCityDrawBodySquare(place, {
        name = WS.GetPrintName(selected),
        selected = true,
        wep = selected
    }, ent, WS.BodyAlpha)
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

local LastSelected = 0

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
    if inventorySystem == 1 then
        ZCityResetSlotHold(false)
        if SimpleSelector.Change then return SimpleSelector.Change(ply, key, pressed, code) end
        return
    elseif inventorySystem ~= 0 then
        ZCityResetSlotHold(false)
        if tAcceptKeys[key] or key == "invnext" or key == "invprev" or key == "lastinv" then return true end
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
    if canUseSelector( ply ) then return end
    --print(canUseSelector( ply ))
    --print("Table")
    --PrintTable( WS.GetWeaponTable( ply ) )
    if iPos or key == "invnext" or key == "invprev" or key == "lastinv" then

        local Weapons = WS.GetWeaponTable( ply )

        WS.Show = CurTime() + 4
        --print(key)
        surface.PlaySound("arc9_eft_shared/weapon_generic_rifle_spin"..math.random(10)..".ogg")
        if iPos then
            iPos = iPos - 1
            if LastSelected ~= iPos then
                WS.SelectedSlotPos = -1
            end
            WS.SelectedSlotPos = (Weapons[iPos] and LastSelected == iPos and WS.SelectedSlotPos + 1 > #Weapons[iPos] and 0 or math.min( WS.SelectedSlotPos + 1, #Weapons[iPos] )) or 0
            WS.SelectedSlot = iPos
            LastSelected = iPos

            local selectedWep = WS.GetSelectedWeapon()
            WS.HoldStart = CurTime()
            WS.HoldWeapon = selectedWep
            WS.HoldSlotBind = key
            WS.HoldSlotKeyCode = code or tSlotFallbackKeys[key]
            WS.BackpackEarlySelect = ZCityIsBodyHolsterBlocked(ply) and ZCityIsBackpackDrawWeaponForSelector(selectedWep)
            WS.BackpackEarlyWeapon = WS.BackpackEarlySelect and selectedWep or nil
            WS.BackpackEarlySelected = false
            WS.BackpackPreviousWeapon = WS.BackpackEarlySelect and ply:GetActiveWeapon() or nil
            WS.ConfirmProgress = 0

            if WS.BackpackEarlySelect then
                ZCityStartBackpackDraw(ply, selectedWep, ZCityGetSlotHoldDuration(ply, selectedWep))
            end
            --print(WS.SelectedSlotPos)
            --print(iPos)
            --print( Weapons[WS.SelectedSlot][WS.SelectedSlotPos] )
        elseif key == "invprev" then
            WS.SelectedSlotPos = WS.SelectedSlotPos - 1
            --print(WS.SelectedSlotPos)
            if Weapons[WS.SelectedSlot] and WS.SelectedSlotPos < 0  then
                GetUpper(Weapons)
            end
            ZCityResetSlotHold(false)
            --WS.SelectedSlot = Weapons[WS.SelectedSlot] and #Weapons[WS.SelectedSlot] > (WS.SelectedSlotPos + 1) and WS.SelectedSlot + 1 or WS.SelectedSlot + 1 > #Weapons - 1 and 0 or 0
        elseif key == "invnext" then
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
            input.SelectWeapon( WS.LastInv )
            WS.LastInv = oldwep
        end

        return true
    end
end

function WS.SetActuallyWeapon( ply, cmd )
    local inventorySystem = ZCityGetInventorySystem()
    if inventorySystem == 1 then
        ZCityResetSlotHold(false)
        if SimpleSelector.Select then return SimpleSelector.Select(ply, cmd) end
        return
    end

    if inventorySystem ~= 0 or not IsValid( ply ) or not ply:Alive() then
        ZCityResetSlotHold(false)
        return
    end

    local selectedWep = WS.GetSelectedWeapon()
    local holdingConfirm = WS.Show > CurTime() and IsValid(WS.HoldWeapon) and IsValid(selectedWep) and selectedWep == WS.HoldWeapon and ZCityIsHeldSlotKeyDown()

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
            input.SelectWeapon(selectedWep)
        end

        WS.LastSelectedSlot = WS.SelectedSlot
        WS.LastSelectedSlotPos = WS.SelectedSlotPos
        WS.Selected = CurTime() + 0.2
        WS.Show = CurTime() + 0.2
        ZCityResetSlotHold(false, true)
        surface.PlaySound("arc9_eft_shared/weapon_generic_spin"..math.random(1,10)..".ogg")
    end
end

hook.Add( "PlayerBindPress", "WeaponSelector_PlayerBindPress", WS.ChangeSelectionWep )

hook.Add( "HUDPaint", "WeaponSelector_Draw", function()
    WS.WeaponSelectorDraw( LocalPlayer() )
    WS.DrawBodySlotSelector( LocalPlayer() )
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
