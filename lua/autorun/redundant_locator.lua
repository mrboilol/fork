local function GetAddonNames()
	local addonsMounted = {}

	for k, v in ipairs(engine.GetAddons()) do -- Gets workshop addons.
		if v.mounted then
			table.insert(addonsMounted, "\""..v.title.."\"")
		end
	end
	local legacyFiles, legacyFolders = file.Find("addons/*", "MOD_WRITE") -- Gets legacy addons.
	for k, v in ipairs(legacyFolders) do
		table.insert(addonsMounted, "\""..v.."\"")
	end
	
	PrintTable(addonsMounted)
end
concommand.Add( "redundants_GetAddons", function() GetAddonNames() end, nil, "Gives you the names of all enabled addons, so you can use them as arguments." )

local function GetGameNames()
	local gamesMounted = {"cstrike", "hl2", "garrysmod"} -- Base game.

	for k, v in ipairs(engine.GetGames()) do -- Mounted games.
		if v.mounted then
			table.insert(gamesMounted, v.folder)
		end
	end
	PrintTable(gamesMounted)
end
concommand.Add( "redundants_GetGames", function() GetGameNames() end, nil, "Gives you the names of all mounted games, so you can use them as arguments." )

local function CheckAddonAgainstGame(args)
	local title, game = args[1], args[2]
	if !title or !game then
		print("Usage: \"redundants_CheckAddonAgainstGame addonname gamename\". Checks if the addon has files from the game.")
		return
	end
	
	local textTable = {}
	local foldersToCheck = {"materials", "models", "sound", "particles"} -- First we check addons from the workshop
	local found = false

	local index = 0
	while index < #foldersToCheck do
		index = index + 1
		local files, dirs = file.Find(foldersToCheck[index].."/*", title)
		for k, v in ipairs(dirs) do
			table.insert(foldersToCheck, foldersToCheck[index].."/"..v)
		end
		for k, v in ipairs(files) do
			if file.Exists( foldersToCheck[index].."/"..v, game ) then
				print("\""..title.."\" has file from "..game..": "..foldersToCheck[index].."/"..v)
				table.insert(textTable, title..", "..game..": "..foldersToCheck[index].."/"..v)
				found = true
			end
		end
	end
	
	if found then 
		file.Write("redundancies.txt", table.concat(textTable, "\n"))
		print("Result saved to garrysmod/data/redundancies.txt")
		return 
	end
	
	foldersToCheck = {"addons/"..title.."/materials", "addons/"..title.."/models", "addons/"..title.."/sound", "addons/"..title.."/particles"} -- If we don't find any, It could've been a legacy addon. Check that.
	index = 0
	while index < #foldersToCheck do
		index = index + 1
		local files, dirs = file.Find(foldersToCheck[index].."/*", "MOD")
		for k, v in ipairs(dirs) do
			table.insert(foldersToCheck, foldersToCheck[index].."/"..v)
		end
		for k, v in ipairs(files) do
			local fixedup = string.gsub(foldersToCheck[index].."/"..v, "addons/"..title.."/", "")
			if file.Exists( fixedup, game ) then
				print("\"addons/"..title.."\" has file from "..game..": "..fixedup)
				table.insert(textTable, "addons/"..title..", "..game..": "..fixedup)
				found = true
			end
		end
	end
	
	if !found then
		print("No redundancies found.")
	else
		file.Write("redundancies.txt", table.concat(textTable, "\n"))
		print("Result saved to garrysmod/data/redundancies.txt")
	end
end
concommand.Add( "redundants_CheckAddonAgainstGame", function(ply, cmd, args) CheckAddonAgainstGame(args) end, nil, "Usage: \"redundants_CheckAddonAgainstGame addonname gamename\". Checks if the addon has files from the game." )

local function CheckMapAgainstGame(args) -- The BSP file can have content packed inside it. We can check that.
	local gameName = args[1]
	if !gameName then
		print("Usage: \"redundants_CheckMapAgainstGame gamename\". Checks if the map you're playing on right now has files from the specified game.")
		return
	end
	
	local textTable = {}
	local foldersToCheck = {"materials", "models", "sound", "particles"}
	local found = false

	local index = 0
	while index < #foldersToCheck do
		index = index + 1
		local files, dirs = file.Find(foldersToCheck[index].."/*", "BSP")
		for k, v in ipairs(dirs) do
			table.insert(foldersToCheck, foldersToCheck[index].."/"..v)
		end
		for k, v in ipairs(files) do
			if file.Exists( foldersToCheck[index].."/"..v, gameName ) then
				print(game.GetMap()..".bsp has file from "..gameName..": "..foldersToCheck[index].."/"..v)
				table.insert(textTable, game.GetMap()..".bsp, "..gameName..": "..foldersToCheck[index].."/"..v)
				found = true
			end
		end
	end
	
	if !found then
		print("No redundancies found.")
	else
		file.Write("redundancies.txt", table.concat(textTable, "\n"))
		print("Result saved to garrysmod/data/redundancies.txt")
	end
end

concommand.Add( "redundants_CheckMapAgainstGame", function(ply, cmd, args) CheckMapAgainstGame(args) end, nil, "Usage: \"redundants_CheckMapAgainstGame gamename\". Checks if the map you're playing on right now has files from the specified game." )