
for k,v in pairs(file.Find("external/vgui/dcodeviewer/themes/*", "LUA")) do
	AddCSLuaFile("external/vgui/dcodeviewer/themes/" .. v)
end

for k,v in pairs(file.Find("external/vgui/dcodeviewer/scripts/*", "LUA")) do
	AddCSLuaFile("external/vgui/dcodeviewer/scripts/" .. v)
end

for k,v in pairs(file.Find("external/vgui/dcodeviewer/languages/*", "LUA")) do
	AddCSLuaFile("external/vgui/dcodeviewer/languages/" .. v)
end