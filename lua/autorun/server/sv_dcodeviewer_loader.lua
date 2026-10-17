
for k,v in pairs(file.Find("vgui/dcodeviewer/themes/*", "LUA")) do
	AddCSLuaFile("vgui/dcodeviewer/themes/" .. v)
end

for k,v in pairs(file.Find("vgui/dcodeviewer/scripts/*", "LUA")) do
	AddCSLuaFile("vgui/dcodeviewer/scripts/" .. v)
end

for k,v in pairs(file.Find("vgui/dcodeviewer/languages/*", "LUA")) do
	AddCSLuaFile("vgui/dcodeviewer/languages/" .. v)
end