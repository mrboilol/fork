local WEAPON_CLASS = "weapon_zcity_rangefinder"

local function GetActiveRangefinder(ply)
    ply = IsValid(ply) and ply or LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= WEAPON_CLASS then return end

    return wep
end

local function ReadToggle(value, current)
    local enabled = tonumber(value)
    return enabled == nil and not current or enabled ~= 0
end

concommand.Add("rangefinder_zoompos", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    local current = wep.ZoomPos or Vector(-6, 3.35, 7.85)
    local x = tonumber(args[1]) or current.x
    local y = tonumber(args[2]) or current.y
    local z = tonumber(args[3]) or current.z

    wep.ZoomPos = Vector(x, y, z)
    print(string.format("SWEP.ZoomPos = Vector(%.4f, %.4f, %.4f)", x, y, z))
end)

concommand.Add("rangefinder_scopepos", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    local current = wep.localScopePos or Vector(-1, 5.1582, 3.5166)
    local x = tonumber(args[1]) or current.x
    local y = tonumber(args[2]) or current.y
    local z = tonumber(args[3]) or current.z

    wep.localScopePos = Vector(x, y, z)
    wep.RangefinderUseScopeBone = false

    print(string.format("SWEP.localScopePos = Vector(%.4f, %.4f, %.4f)", x, y, z))
    print("Rangefinder scope bone auto-pos disabled for manual tuning")
end)

concommand.Add("rangefinder_scopebone", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    wep.RangefinderUseScopeBone = ReadToggle(args[1], wep.RangefinderUseScopeBone)
    wep.RangefinderScopeBone = nil

    print("Rangefinder scope bone auto-pos: " .. tostring(wep.RangefinderUseScopeBone))
end)

concommand.Add("rangefinder_rtdebug", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    local mode = tonumber(args[1]) or 0
    wep.RangefinderRTDebug = math.Clamp(math.floor(mode), 0, 2)

    if wep.UpdateRangefinderRTMaterialState then
        wep:UpdateRangefinderRTMaterialState()
    end

    print("Rangefinder RT debug mode: " .. tostring(wep.RangefinderRTDebug))
    print("0 = normal eye render, 1 = material test pattern, 2 = scope-bone render origin")
end)

concommand.Add("rangefinder_rtscopeorigin", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    wep.RangefinderRTUseScopeOrigin = ReadToggle(args[1], wep.RangefinderRTUseScopeOrigin)
    print("Rangefinder RT scope origin: " .. tostring(wep.RangefinderRTUseScopeOrigin))
end)

concommand.Add("rangefinder_rtall", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    local raw = tostring(args[1] or "")
    wep.RangefinderForceAllRT = ReadToggle(string.match(raw, "^-?%d+%.?%d*"), wep.RangefinderForceAllRT)

    if wep.UpdateRangefinderRTMaterialState then
        wep:UpdateRangefinderRTMaterialState()
    end

    print("Rangefinder force all RT materials: " .. tostring(wep.RangefinderForceAllRT))
end)

concommand.Add("rangefinder_lensdisk", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    wep.RangefinderLensDiskSize = tonumber(args[1]) or wep.RangefinderLensDiskSize or 1.65
    wep.RangefinderLensDiskOffset = tonumber(args[2]) or wep.RangefinderLensDiskOffset or 0.04
    wep.RangefinderLensDiskRight = tonumber(args[3]) or wep.RangefinderLensDiskRight or 0
    wep.RangefinderLensDiskUp = tonumber(args[4]) or wep.RangefinderLensDiskUp or 0
    wep.RangefinderLensDiskRotation = tonumber(args[5]) or wep.RangefinderLensDiskRotation or 0

    if args[6] ~= nil then
        wep.RangefinderLensDiskEnabled = (tonumber(args[6]) or 0) ~= 0
    end

    print(string.format(
        "Rangefinder lens disk: size %.4f, offset %.4f, right %.4f, up %.4f, rot %.4f, enabled %s",
        wep.RangefinderLensDiskSize,
        wep.RangefinderLensDiskOffset,
        wep.RangefinderLensDiskRight,
        wep.RangefinderLensDiskUp,
        wep.RangefinderLensDiskRotation,
        tostring(wep.RangefinderLensDiskEnabled)
    ))
end)

concommand.Add("rangefinder_shadow", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    wep.RangefinderOpticShadow = ReadToggle(args[1], wep.RangefinderOpticShadow)

    local scopeBlackout = tonumber(args[2])
    local blackoutSize = tonumber(args[3])
    local fallbackDivisor = tonumber(args[4])
    local maskScale = tonumber(args[5])
    local maskShift = tonumber(args[6])
    local maskDistMul = tonumber(args[7])

    if scopeBlackout and scopeBlackout >= 10 then
        wep.scope_blackout = scopeBlackout
    end

    if blackoutSize and blackoutSize >= 100 then
        wep.blackoutsize = blackoutSize
    end

    if fallbackDivisor and fallbackDivisor >= 2 then
        wep.RangefinderOpticFallbackDivisor = fallbackDivisor
    end

    if maskScale and maskScale > 0 then
        wep.RangefinderOpticMaskScale = maskScale
    end

    if maskShift and maskShift >= 0 then
        wep.RangefinderOpticMaskShift = maskShift
    end

    if maskDistMul and maskDistMul > 0 then
        wep.RangefinderOpticMaskDistMul = maskDistMul
    end

    print(string.format(
        "Rangefinder Z-City optic shadow: %s, scope_blackout %.4f, blackoutsize %.4f, fallbackDivisor %.4f, maskScale %.4f, maskShift %.4f, maskDistMul %.4f",
        tostring(wep.RangefinderOpticShadow),
        wep.scope_blackout or 0,
        wep.blackoutsize or 0,
        wep.RangefinderOpticFallbackDivisor or 0,
        wep.RangefinderOpticMaskScale or 0,
        wep.RangefinderOpticMaskShift or 0,
        wep.RangefinderOpticMaskDistMul or 0
    ))
end)

concommand.Add("rangefinder_materials", function(ply)
    local wep = GetActiveRangefinder(ply)
    if not wep then return end

    if wep.RefreshRangefinderLensSubMaterials then
        wep:RefreshRangefinderLensSubMaterials()
    end

    if wep.UpdateRangefinderRTMaterialState then
        wep:UpdateRangefinderRTMaterialState()
    end

    print("Rangefinder lens material: " .. tostring(wep.RangefinderLensMaterial))
    print("Rangefinder lens submaterial: " .. tostring(wep.RangefinderLensSubMaterial))
    print("Rangefinder lens submaterials: " .. table.concat(wep.RangefinderLensSubMaterials or {}, ", "))
    print("Rangefinder scope bone auto-pos: " .. tostring(wep.RangefinderUseScopeBone))
    print("Rangefinder local scope pos: " .. tostring(wep.localScopePos))
    print("Rangefinder bone scope pos: " .. tostring(wep.RangefinderBoneScopePos))
    print("Rangefinder RT debug mode: " .. tostring(wep.RangefinderRTDebug))
    print("Rangefinder RT scope origin: " .. tostring(wep.RangefinderRTUseScopeOrigin))
    print("Rangefinder force all RT materials: " .. tostring(wep.RangefinderForceAllRT))
    print(string.format(
        "Rangefinder lens disk: size %.4f, offset %.4f, right %.4f, up %.4f, rot %.4f, enabled %s",
        wep.RangefinderLensDiskSize or 0,
        wep.RangefinderLensDiskOffset or 0,
        wep.RangefinderLensDiskRight or 0,
        wep.RangefinderLensDiskUp or 0,
        wep.RangefinderLensDiskRotation or 0,
        tostring(wep.RangefinderLensDiskEnabled)
    ))
    print(string.format(
        "Rangefinder Z-City optic shadow: %s, scope_blackout %.4f, blackoutsize %.4f, fallbackDivisor %.4f, maskScale %.4f, maskShift %.4f, maskDistMul %.4f, last diffa %.4f %.4f miss %.4f, fov %.4f, allowed %s, axisdot %.4f, screenSafe %s",
        tostring(wep.RangefinderOpticShadow),
        wep.scope_blackout or 0,
        wep.blackoutsize or 0,
        wep.RangefinderOpticFallbackDivisor or 0,
        wep.RangefinderOpticMaskScale or 0,
        wep.RangefinderOpticMaskShift or 0,
        wep.RangefinderOpticMaskDistMul or 0,
        wep.RangefinderLastOpticRight or 0,
        wep.RangefinderLastOpticUp or 0,
        wep.RangefinderLastOpticMiss or 0,
        wep.RangefinderLastRTFOV or 0,
        tostring(wep.RangefinderLastRTAllowed),
        wep.RangefinderLastAxisDot or 0,
        tostring(wep.RangefinderLastScreenSafe)
    ))

    local model = wep:GetWM()
    if not IsValid(model) then
        print("Rangefinder model is not valid yet")
        return
    end

    for index, matPath in ipairs(model:GetMaterials() or {}) do
        local subMaterial = model.GetSubMaterial and model:GetSubMaterial(index - 1) or ""
        print(string.format("[%d] %s | sub: %s", index, matPath, tostring(subMaterial)))
    end
end)

concommand.Add("rangefinder_fakepos", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep or not wep.FakePosIdle or not wep.FakePosZoom then return end

    local aiming = wep:IsZoom()
    local current = aiming and wep.FakePosZoom or wep.FakePosIdle
    local x = tonumber(args[1]) or current.x
    local y = tonumber(args[2]) or current.y
    local z = tonumber(args[3]) or current.z

    if aiming then
        wep.FakePosZoom = Vector(x, y, z)
        print(string.format("SWEP.FakePosZoom = Vector(%.4f, %.4f, %.4f)", x, y, z))
    else
        wep.FakePosIdle = Vector(x, y, z)
        print(string.format("SWEP.FakePosIdle = Vector(%.4f, %.4f, %.4f)", x, y, z))
    end
end)

concommand.Add("rangefinder_fakeang", function(ply, cmd, args)
    local wep = GetActiveRangefinder(ply)
    if not wep or not wep.FakeAngIdle or not wep.FakeAngZoom then return end

    local aiming = wep:IsZoom()
    local current = aiming and wep.FakeAngZoom or wep.FakeAngIdle
    local p = tonumber(args[1]) or current.p
    local y = tonumber(args[2]) or current.y
    local r = tonumber(args[3]) or current.r

    if aiming then
        wep.FakeAngZoom = Angle(p, y, r)
        print(string.format("SWEP.FakeAngZoom = Angle(%.4f, %.4f, %.4f)", p, y, r))
    else
        wep.FakeAngIdle = Angle(p, y, r)
        print(string.format("SWEP.FakeAngIdle = Angle(%.4f, %.4f, %.4f)", p, y, r))
    end
end)

local debugPhysics = CreateClientConVar("rangefinder_debug_phys", "0", true, false, "Draw wireframe bounding boxes around rangefinders on the ground")

hook.Add("PostDrawTranslucentRenderables", "ZCity_Rangefinder_DebugPhysics", function()
    if not debugPhysics:GetBool() then return end

    for _, ent in ipairs(ents.FindByClass(WEAPON_CLASS)) do
        if IsValid(ent) and not IsValid(ent:GetOwner()) then
            local mins, maxs = ent:OBBMins(), ent:OBBMaxs()

            render.SetColorMaterial()
            render.DrawWireframeBox(ent:GetPos(), ent:GetAngles(), mins, maxs, Color(0, 255, 0), true)

            if debugoverlay and debugoverlay.Cross then
                debugoverlay.Cross(ent:GetPos(), 1, 0.05, Color(255, 0, 0), true)
            end
        end
    end
end)

concommand.Add("rangefinder_print_obb", function(ply)
    local wep = GetActiveRangefinder(ply)
    if not wep then
        print("You must hold the rangefinder to print its info.")
        return
    end

    print("[Rangefinder Debug]")
    print("Model: " .. wep:GetModel())
    print("OBBMins: " .. tostring(wep:OBBMins()))
    print("OBBMaxs: " .. tostring(wep:OBBMaxs()))

    local phys = wep:GetPhysicsObject()
    if IsValid(phys) then
        print("Physics Object: VALID")
        print("Physics Mass: " .. tostring(phys:GetMass()))
        print("Physics Material: " .. tostring(phys:GetMaterial()))
    else
        print("Physics Object: INVALID (no physics active)")
    end
end)
