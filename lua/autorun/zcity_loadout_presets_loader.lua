if SERVER then
    AddCSLuaFile("autorun/client/cl_zclp_spawnmenu.lua")
    AddCSLuaFile("vgui/cl_zclp_menu.lua")
    AddCSLuaFile("autorun/sh_zclp_core.lua")
    include("autorun/sh_zclp_core.lua")
    include("autorun/server/sv_zclp_presets.lua")
else
    include("autorun/sh_zclp_core.lua")
    include("vgui/cl_zclp_menu.lua")
    include("autorun/client/cl_zclp_spawnmenu.lua")
end
