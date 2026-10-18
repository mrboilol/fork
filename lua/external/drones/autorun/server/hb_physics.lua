AddCSLuaFile()

function hb_physics()
Msg("\n|Hbombs physics module initialized!")
Msg("\n|If you don't want this, delete the hb_physics.lua file\n")

phys = {}
phys.MaxVelocity = 5000
phys.MaxAngularVelocity = 3636.3637695313
physenv.SetPerformanceSettings(phys)

end

hook.Add( "InitPostEntity", "hb_physics", hb_physics )