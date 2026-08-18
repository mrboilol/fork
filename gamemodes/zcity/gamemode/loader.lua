local function IncluderFunc(fileName)
	local ok, err = pcall(function()
		if (fileName:find("sv_")) then
			include(fileName)
		elseif (fileName:find("shared.lua") or fileName:find("sh_")) then
			if (SERVER) then
				AddCSLuaFile(fileName)
			end

			include(fileName)
		elseif (fileName:find("cl_")) then
			if (SERVER) then
				AddCSLuaFile(fileName)
			else
				include(fileName)
			end
		end
	end)
	if not ok then
		MsgC(Color(255, 60, 60), "[MODELOAD-ERROR] " .. fileName .. " :: " .. tostring(err) .. "\n")
	end
end

--прошу обратить внимание что файлы внутри папок загружаются первыми
local function LoadFromDir(directory)
    local files, folders = file.Find(directory .. "/*", "LUA")
    
	for _, v in ipairs(folders) do
        LoadFromDir(directory .. "/" .. v)
	end

	for _, v in ipairs(files) do
		IncluderFunc(directory .. "/" .. v)
	end
end

LoadFromDir("zcity/gamemode/libraries")

--моды лоадер (плывисочная машина), если чё непонятно спрашивайте у меня (мистера поинта). мод много модов.
zb.modesHooks = {}
zb.modes = zb.modes or {}

local chancesfile = "zbattle/modeschances.json"

if SERVER then
	zb.ModesChances = util.JSONToTable(file.Read(chancesfile, "DATA") or "") or {}

	hook.Add("ShutDown", "savechances", function()
		file.Write(chancesfile, util.TableToJSON(zb.ModesChances or {}, true))
	end)

	concommand.Add("zb_getmodeschances", function(ply)
		if not ply:IsAdmin() then return end
		ply:zChatPrint(util.TableToJSON(zb.ModesChances, true))
	end)

	concommand.Add("zb_setmodechance", function(ply, _, args)
		if not ply:IsAdmin() then return end

		local mode = args[1]
		local chance = tonumber(args[2])
		if not zb.ModesChances[mode] or not chance then return end

		zb.ModesChances[mode] = chance
	end)

	concommand.Add("zb_savemodeschances", function(ply)
		if not ply:IsAdmin() then return end
		file.Write(chancesfile, util.TableToJSON(zb.ModesChances or {}, true))
	end)
end

local function addModeHook(MODE, hookName, func)
    zb.modesHooks[MODE.name] = zb.modesHooks[MODE.name] or {}
    zb.modesHooks[MODE.name][hookName] = func

    hook.Add(hookName, "zb_modehook_" .. hookName, function(...)
        local Current = zb.CROUND_MAIN or zb.CROUND or "tdm"

        local modeHooks = zb.modesHooks[Current]
        if modeHooks and modeHooks[hookName] then
            local ModeTable = zb.modes[Current]
            local a, b, c, d, e, f = modeHooks[hookName](ModeTable, ...)

            if a ~= nil then
                return a, b, c, d, e, f
            end
        end
    end)
end

local function InitMode(mode)
	if table.IsEmpty(mode) or mode.Abstract == true then return end
	if not isstring(mode.name) or mode.name == "" then
		ErrorNoHalt("[ZCity] Refusing to register a mode without a name.\n")
		return
	end

	local saved = zb.modes[mode.name] and zb.modes[mode.name].saved or {}

	if mode.base then
		local base = zb.modes[mode.base]
		if not base then
			ErrorNoHalt("[ZCity] Mode '" .. mode.name .. "' is missing base mode '" .. mode.base .. "'.\n")
			return
		end

		table.Inherit(mode, base)

		for key, value in pairs(mode) do
			if istable(value) and istable(base[key]) then
				mode[key] = table.Copy(value)
			end
		end

		if mode.AfterBaseInheritance then
			mode:AfterBaseInheritance()
		end
	end

	zb.modes[mode.name] = mode
	mode.saved = saved

	if SERVER then
		if mode.SetupChances then
			mode:SetupChances()
		else
			zb.ModesChances[mode.name] = zb.ModesChances[mode.name] or mode.Chance
		end
	end

	for hookName, callback in pairs(mode) do
		if isfunction(callback) then
			addModeHook(mode, hookName, callback)
		end
	end
end

local function LoadModes()
	local directory = "zcity/gamemode/modes"
	local files, folders = file.Find(directory .. "/*", "LUA")

	for _, v in ipairs(files) do
		MODE = {}
		IncluderFunc(directory .. "/" .. v)
		InitMode(MODE)
		MODE = nil
	end

	for _, v in ipairs(folders) do
		MODE = {}
		LoadFromDir(directory .. "/" .. v)
		InitMode(MODE)
		MODE = nil
	end
end

LoadModes()

print("ZB modes loaded!")
