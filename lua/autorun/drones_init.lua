local ROOT = "external/drones/"

local function sendAndInclude(path)
	if SERVER then AddCSLuaFile(path) end
	include(path)
end

for _, f in ipairs(file.Find(ROOT .. "autorun/*.lua", "LUA")) do
	sendAndInclude(ROOT .. "autorun/" .. f)
end

for _, f in ipairs(file.Find(ROOT .. "autorun/client/*.lua", "LUA")) do
	local path = ROOT .. "autorun/client/" .. f
	if SERVER then AddCSLuaFile(path) else include(path) end
end

if SERVER then
	for _, f in ipairs(file.Find(ROOT .. "autorun/server/*.lua", "LUA")) do
		include(ROOT .. "autorun/server/" .. f)
	end
end

local function exists(path)
	return file.Exists(path, "LUA")
end

local function loadFolder(dir)
	local cl = exists(dir .. "cl_init.lua") and dir .. "cl_init.lua" or dir .. "shared.lua"
	if SERVER then
		if exists(cl) then AddCSLuaFile(cl) end
		local sv = exists(dir .. "init.lua") and dir .. "init.lua" or dir .. "shared.lua"
		if not exists(sv) then return false end
		include(sv)
	else
		if not exists(cl) then return false end
		include(cl)
	end
	return true
end

local function registerAll(sub, global, makeTable, register)
	local base = ROOT .. sub .. "/"
	local files, folders = file.Find(base .. "*", "LUA")
	local old = _G[global]

	for _, f in ipairs(files) do
		if string.GetExtensionFromFilename(f) ~= "lua" then continue end
		local class = string.StripExtension(f)
		local tab = makeTable(class, base .. class)
		_G[global] = tab
		sendAndInclude(base .. f)
		register(tab, class)
	end

	for _, class in ipairs(folders) do
		local tab = makeTable(class, base .. class)
		_G[global] = tab
		if loadFolder(base .. class .. "/") then register(tab, class) end
	end

	_G[global] = old
end

registerAll("entities", "ENT", function(class, folder)
	return {ClassName = class, Folder = folder}
end, scripted_ents.Register)

registerAll("weapons", "SWEP", function(class, folder)
	return {ClassName = class, Folder = folder, Primary = {}, Secondary = {}}
end, weapons.Register)

for _, f in ipairs(file.Find(ROOT .. "effects/*.lua", "LUA")) do
	local path = ROOT .. "effects/" .. f
	if SERVER then
		AddCSLuaFile(path)
	else
		local old = EFFECT
		EFFECT = {}
		include(path)
		effects.Register(EFFECT, string.StripExtension(f))
		EFFECT = old
	end
end
