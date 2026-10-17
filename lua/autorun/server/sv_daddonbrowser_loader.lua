
resource.AddWorkshop("3705662940")

AddCSLuaFile("includes/modules/ttfname.lua")

for k,v in pairs(file.Find("external/vgui/daddonbrowser/*", "LUA")) do
	AddCSLuaFile("external/vgui/daddonbrowser/" .. v)
end