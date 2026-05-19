if SERVER then return end

hg = hg or {}

local function RegisterDeltaCommands()
    local tbl = concommand.GetTable and concommand.GetTable() or {}

    if not tbl["hg_menu"] then
        concommand.Add("hg_menu", function()
            if not hg or not hg.CreateRadialMenu then return end
            hg.CreateRadialMenu()
        end)
    end
end

hook.Add("Initialize", "zcity_delta_register_commands", RegisterDeltaCommands)
hook.Add("InitPostEntity", "zcity_delta_register_commands", RegisterDeltaCommands)

timer.Simple(0, function()
    RegisterDeltaCommands()
end)
