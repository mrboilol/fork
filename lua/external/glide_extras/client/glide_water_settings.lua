local VEHICLE_TYPES = {
    [0] = { name = "Undefined Vehicles", key = "undefined", en = "1", fill = "0.04", drain = "0.04", delay = "4.0", offset = "0", damp = "16", bias = "0.2", air = "0.3" },
    [1] = { name = "Cars & Trucks",      key = "car",       en = "1", fill = "0.04", drain = "0.04", delay = "4.0", offset = "0", damp = "16", bias = "0.6", air = "0.6" },
    [2] = { name = "Motorcycles",       key = "bike",      en = "1", fill = "0.06", drain = "0.06", delay = "2.0", offset = "0", damp = "12", bias = "0.1", air = "0.0" },
    [3] = { name = "Helicopters",       key = "heli",      en = "1", fill = "0.08", drain = "0.02", delay = "1.0", offset = "0", damp = "20", bias = "0.7", air = "0.5" },
    [4] = { name = "Planes",             key = "plane",     en = "1", fill = "0.08", drain = "0.02", delay = "1.0", offset = "0", damp = "20", bias = "0.5", air = "0.4" },
    [5] = { name = "Tanks & Heavy",      key = "tank",      en = "1", fill = "0.02", drain = "0.02", delay = "8.0", offset = "-15", damp = "25", bias = "0.1", air = "0.1" },
    [6] = { name = "Boats & Amphibious", key = "boat",      en = "0", fill = "0.01", drain = "0.05", delay = "10.0", offset = "10", damp = "14", bias = "0.0", air = "0.0" }
}

for typeId, info in pairs(VEHICLE_TYPES) do
    CreateConVar("glide_water_enable_" .. info.key, info.en, {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    CreateConVar("glide_water_fill_" .. info.key, info.fill, {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    CreateConVar("glide_water_drain_" .. info.key, info.drain, {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    CreateConVar("glide_water_delay_" .. info.key, info.delay, {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    CreateConVar("glide_water_offset_" .. info.key, info.offset, {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    CreateConVar("glide_water_damp_" .. info.key, info.damp, {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    CreateConVar("glide_water_bias_" .. info.key, info.bias, {FCVAR_ARCHIVE, FCVAR_REPLICATED})
    CreateConVar("glide_water_air_" .. info.key, info.air, {FCVAR_ARCHIVE, FCVAR_REPLICATED})
end

CreateConVar("glide_water_sounds", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED})
CreateConVar("glide_water_particles", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED})
CreateConVar("glide_water_debug_notify", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED})
CreateConVar("glide_water_debug_logs", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED})

hook.Add("PopulateToolMenu", "GlideWaterPhysics_AddControlPanel", function()
    spawnmenu.AddToolMenuOption(
        "Options",               
        "Glide Custom Addons",   
        "GlideWaterPhysicsMenu", 
        "Glide Water Physics",   
        "", "",
        function(panel)
            panel:ClearControls()

            panel:Help("Configure how vehicles behave when entering water.")

            -- ── GLOBAL OPTIONS ───────────────────────────────────────────────
            local mainForm = vgui.Create("DForm", panel)
            mainForm:SetLabel("Global Settings")
            panel:AddItem(mainForm)

            local cb_sounds    = mainForm:CheckBox("Enable Sounds", "glide_water_sounds")
            local cb_particles = mainForm:CheckBox("Enable Particles", "glide_water_particles")

            -- ── COLLAPSIBLE VEHICLE SECTIONS ─────────────────────────────────
            local uiElements = {}

            for typeId = 0, 6 do
                local info = VEHICLE_TYPES[typeId]
                if not info then continue end

                local vForm = vgui.Create("DForm", panel)
                vForm:SetLabel(info.name)
                vForm:SetExpanded(false) 
                panel:AddItem(vForm)

                local en   = vForm:CheckBox("Enable Sinking", "glide_water_enable_" .. info.key)
                local del  = vForm:NumSlider("Sink Delay (s)", "glide_water_delay_" .. info.key, 0, 30, 1)
                local fill = vForm:NumSlider("Sink Speed", "glide_water_fill_" .. info.key, 0.01, 0.5, 3)
                local dr   = vForm:NumSlider("Drain Speed", "glide_water_drain_" .. info.key, 0.01, 0.5, 3)
                local off  = vForm:NumSlider("Floating Height", "glide_water_offset_" .. info.key, -50, 50, 0)
                local dmp  = vForm:NumSlider("Water Damping", "glide_water_damp_" .. info.key, 1, 50, 0)
                local bias = vForm:NumSlider("Nose-Dive", "glide_water_bias_" .. info.key, 0.0, 1.0, 2)
                local air  = vForm:NumSlider("Rear Float", "glide_water_air_" .. info.key, 0.0, 1.0, 2)
                
                uiElements[info.key] = { en = en, delay = del, fill = fill, drain = dr, offset = off, damp = dmp, bias = bias, air = air }
            end

            -- ── DEBUG SETTINGS ───────────────────────────────────────────────
            local debugForm = vgui.Create("DForm", panel)
            debugForm:SetLabel("Debug Menu")
            panel:AddItem(debugForm)

            local cb_notify = debugForm:CheckBox("Chat Notifications", "glide_water_debug_notify")
            local cb_logs   = debugForm:CheckBox("Console Logs", "glide_water_debug_logs")

            -- ── RESET BUTTON ─────────────────────────────────────────────────
            panel:Help("\n")
            local resetBtn = panel:Button("Reset All to Defaults")
            resetBtn.DoClick = function()
                RunConsoleCommand("glide_water_sounds", "1")
                RunConsoleCommand("glide_water_particles", "1")
                RunConsoleCommand("glide_water_debug_notify", "0")
                RunConsoleCommand("glide_water_debug_logs", "0")

                if IsValid(cb_sounds)    then cb_sounds:SetValue(1) end
                if IsValid(cb_particles) then cb_particles:SetValue(1) end
                if IsValid(cb_notify)    then cb_notify:SetValue(0) end
                if IsValid(cb_logs)      then cb_logs:SetValue(0) end

                for typeId = 0, 6 do
                    local info = VEHICLE_TYPES[typeId]
                    if not info then continue end

                    RunConsoleCommand("glide_water_enable_" .. info.key, info.en)
                    RunConsoleCommand("glide_water_fill_" .. info.key, info.fill)
                    RunConsoleCommand("glide_water_drain_" .. info.key, info.drain)
                    RunConsoleCommand("glide_water_delay_" .. info.key, info.delay)
                    RunConsoleCommand("glide_water_offset_" .. info.key, info.offset)
                    RunConsoleCommand("glide_water_damp_" .. info.key, info.damp)
                    RunConsoleCommand("glide_water_bias_" .. info.key, info.bias)
                    RunConsoleCommand("glide_water_air_" .. info.key, info.air)

                    local ui = uiElements[info.key]
                    if ui then
                        if IsValid(ui.en)     then ui.en:SetValue(tonumber(info.en)) end
                        if IsValid(ui.delay)  then ui.delay:SetValue(tonumber(info.delay)) end
                        if IsValid(ui.fill)   then ui.fill:SetValue(tonumber(info.fill)) end
                        if IsValid(ui.drain)  then ui.drain:SetValue(tonumber(info.drain)) end
                        if IsValid(ui.offset) then ui.offset:SetValue(tonumber(info.offset)) end
                        if IsValid(ui.damp)   then ui.damp:SetValue(tonumber(info.damp)) end
                        if IsValid(ui.bias)   then ui.bias:SetValue(tonumber(info.bias)) end
                        if IsValid(ui.air)    then ui.air:SetValue(tonumber(info.air)) end
                    end
                end
            end
        end
    )
end)