local ZW = ZCityWind
local config = ZW.Config

hook.Add("PopulateToolMenu", "ZCityWindMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Z-City Ballistics", "ZCityWindSettings", "Ballistics & Wind Settings", "", "", function(panel)
        panel:ClearControls()

        -- Title
        local title = panel:Help("Z-City Realistic Ballistics & Wind Simulation")
        title:SetFont("DermaDefaultBold")
        panel:Help("Configure physical bullets, wind deflection forces, and barometric atmosphere conditions.")

        local isAdmin = LocalPlayer():IsAdmin()

        -- CLIENT SETTINGS
        local clientGroup = panel:Help("\n--- CLIENT / VISUAL SETTINGS ---")
        clientGroup:SetFont("DermaDefaultBold")
        clientGroup:SetTextColor(Color(0, 128, 255))

        local dbgDraw = panel:CheckBox("Draw Bullet Trajectories & Hits", "cl_zcity_wind_debug_draw")
        panel:ControlHelp("Draws the flight path of your bullets and marks client/server hit locations. Useful for debugging.")

        -- SERVER SETTINGS
        local serverGroup = panel:Help("\n--- SERVER SETTINGS (ADMIN ONLY) ---")
        serverGroup:SetFont("DermaDefaultBold")
        if isAdmin then
            serverGroup:SetTextColor(Color(0, 200, 100))
        else
            serverGroup:SetTextColor(Color(200, 50, 50))
            panel:Help("⚠️ You are not an Admin. Server settings are read-only.")
        end

        local windMul = panel:NumSlider("Wind Deflection Multiplier", "sv_zcity_wind_multiplier", 0, 5, 2)
        windMul:SetEnabled(isAdmin)
        panel:ControlHelp("Multiplies the wind force applied to physical bullets. Set to 0 to disable wind deflection.")

        local replaceZC = panel:CheckBox("Enable Wind on Z-City Weapons", "sv_zcity_wind_replace_zcity_bullets")
        replaceZC:SetEnabled(isAdmin)
        panel:ControlHelp("Enables physical, wind-affected bullets on native Z-City and Homigrad weapon bases.")

        local replaceSB = panel:CheckBox("Enable Wind on Sandbox Weapons", "sv_zcity_wind_replace_sandbox_bullets")
        replaceSB:SetEnabled(isAdmin)
        panel:ControlHelp("Converts standard GMod weapon trace bullets (HL2, CSS, etc.) into physical wind-affected bullets.")

        local suppress = panel:CheckBox("Enable Near-Miss Suppression Effects", "sv_zcity_wind_suppression")
        suppress:SetEnabled(isAdmin)
        panel:ControlHelp("Applies screen shake and suppression overlay to players when high-velocity bullets fly near their head.")

        -- ATMOSPHERE SETTINGS
        local atmosGroup = panel:Help("\n--- ATMOSPHERIC PHYSICS (ADMIN ONLY) ---")
        atmosGroup:SetFont("DermaDefaultBold")
        atmosGroup:SetTextColor(isAdmin and Color(210, 180, 0) or Color(150, 150, 150))

        local atmosToggle = panel:CheckBox("Enable Realistic Atmosphere", "sv_zcity_wind_atmosphere")
        atmosToggle:SetEnabled(isAdmin)
        panel:ControlHelp("Enables barometric formulas calculating air density, temperature, pressure, and humidity to realistically scale bullet drag.")

        local seaLevel = panel:NumSlider("Map Sea Level Z Coordinate", "sv_zcity_wind_sea_level", -16384, 16384, 0)
        seaLevel:SetEnabled(isAdmin)
        panel:ControlHelp("The absolute Z height coordinate on this map that counts as 0m (sea level) for atmospheric formulas.")

        local btnCalibrate = panel:Button("Calibrate Sea Level at My Feet", "zcity_wind_set_sealevel")
        btnCalibrate:SetEnabled(isAdmin)
        panel:ControlHelp("Traces down from your current position to detect the exact ground level and saves it as the 0m baseline for this map.")

        -- DEBUG LOGS
        local debugToggle = panel:CheckBox("Enable Server Console Telemetry", "sv_zcity_wind_debug")
        debugToggle:SetEnabled(isAdmin)
        panel:ControlHelp("Prints detailed tick-by-tick ballistics data (velocity, coordinates, humidity, temp, drag) to the server console.")

        -- WIND OVERRIDES
        local overrideGroup = panel:Help("\n--- WIND OVERRIDES (ADMIN ONLY) ---")
        overrideGroup:SetFont("DermaDefaultBold")
        overrideGroup:SetTextColor(isAdmin and Color(210, 100, 0) or Color(150, 150, 150))

        local speedOverride = panel:NumSlider("Wind Speed Override (m/s)", nil, 0, 50, 1)
        speedOverride:SetEnabled(isAdmin)

        local yawOverride = panel:NumSlider("Wind Direction Override (deg)", nil, 0, 360, 0)
        yawOverride:SetEnabled(isAdmin)

        local btnApplyOverride = panel:Button("Apply Custom Static Wind", "")
        btnApplyOverride:SetEnabled(isAdmin)
        btnApplyOverride.DoClick = function()
            LocalPlayer():ConCommand("zcity_wind_test " .. speedOverride:GetValue() .. " " .. yawOverride:GetValue())
        end
        panel:ControlHelp("Sets a static wind force and direction across the map.")

        local btnResetOverride = panel:Button("Reset All Wind Overrides", "zcity_wind_test reset")
        btnResetOverride:SetEnabled(isAdmin)
        panel:ControlHelp("Disables all custom overrides and restores weather-driven wind calculations (e.g. StormFox 2).")
    end)
end)
