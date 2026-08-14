-- ZCity startup sound scanner
--
-- Checks static sound paths referenced by Lua files after mounted content has
-- finished loading. Reports are written to garrysmod/data/zcity_asset_scan/.

if SERVER then AddCSLuaFile() end

ZCityAssetScanner = ZCityAssetScanner or {}

local Scanner = ZCityAssetScanner

Scanner.ReportDirectory = "zcity_asset_scan"
Scanner.MaxConsoleResults = 200
Scanner.MaxSourceSize = 2 * 1024 * 1024

local realmName = SERVER and "server" or "client"
local colourPrefix = Color(90, 190, 255)
local colourGood = Color(100, 220, 120)
local colourBad = Color(255, 105, 105)
local colourText = Color(225, 225, 225)

local soundExtensions = {
	wav = true,
	mp3 = true,
	ogg = true
}

local function PrintPrefix(colour, message)
	MsgC(colourPrefix, "[ZCity Sound Scan] ", colour or colourText, message, "\n")
end

local function NormaliseSlashes(path)
	return string.gsub(path, "\\", "/")
end

local function StartsWith(path, prefix)
	return string.sub(path, 1, #prefix) == prefix
end

local function GetExtension(path)
	return string.match(string.lower(path), "%.([%w]+)$")
end

local function IsLiteralPath(path)
	if path == "" or #path > 260 then return false end
	if string.find(path, "[%c%%*?{}<>:]") then return false end
	if string.find(path, "://", 1, true) then return false end
	if string.find(path, "%.%.", 1, true) then return false end
	return true
end

local function CanonicalSoundPath(rawPath)
	local path = string.Trim(NormaliseSlashes(rawPath or ""))
	path = string.gsub(path, "^/+", "")
	if not IsLiteralPath(path) then return nil end

	local lowerPath = string.lower(path)
	if StartsWith(lowerPath, "data/") or StartsWith(lowerPath, "screenshots/") then return nil end

	local extension = GetExtension(path)
	if not soundExtensions[extension] then return nil end
	local stem = string.sub(path, 1, #path - #extension - 1)
	if not string.find(stem, "[%w]") then return nil end

	if not StartsWith(lowerPath, "sound/") then
		path = "sound/" .. path
	end

	return path
end

local function AddSoundReference(references, rawPath, sourcePath)
	local path = CanonicalSoundPath(rawPath)
	if not path then return end

	local key = string.lower(path)
	local entry = references[key]
	if not entry then
		entry = {
			path = path,
			sources = {}
		}
		references[key] = entry
	end

	entry.sources[sourcePath] = true
end

local function CollectQuotedSounds(contents, sourcePath, references)
	-- Ignore examples and disabled paths left in ordinary Lua comments.
	local searchable = string.gsub(contents, "%-%-%[%[.-%]%]", "")
	searchable = string.gsub(searchable, "%-%-%[=%[.-%]=%]", "")
	searchable = string.gsub(searchable, "%-%-[^\r\n]*", "")

	for value in string.gmatch(searchable, '"(.-)"') do
		AddSoundReference(references, value, sourcePath)
	end

	for value in string.gmatch(searchable, "'(.-)'") do
		AddSoundReference(references, value, sourcePath)
	end
end

local function CollectLuaFiles(directory, output, visited)
	directory = NormaliseSlashes(directory)
	if visited[directory] then return end
	visited[directory] = true

	local files, directories = file.Find(directory .. "/*", "GAME", "nameasc")
	files = files or {}
	directories = directories or {}

	for _, fileName in ipairs(files) do
		if string.lower(string.GetExtensionFromFilename(fileName) or "") == "lua" then
			output[#output + 1] = directory .. "/" .. fileName
		end
	end

	for _, childDirectory in ipairs(directories) do
		CollectLuaFiles(directory .. "/" .. childDirectory, output, visited)
	end
end

local function SortedSourceList(sourceSet)
	local output = {}
	for sourcePath in pairs(sourceSet) do
		output[#output + 1] = sourcePath
	end
	table.sort(output)
	return output
end

local function BuildReport(startedAt, luaFiles, references, missing, skippedFiles)
	local lines = {
		"ZCity startup sound scan",
		"Realm: " .. realmName,
		"Completed: " .. os.date("%Y-%m-%d %H:%M:%S"),
		string.format("Duration: %.3f seconds", SysTime() - startedAt),
		"Lua files scanned: " .. #luaFiles,
		"Oversized/unreadable Lua files skipped: " .. skippedFiles,
		"Unique static sound references: " .. table.Count(references),
		"Missing sounds: " .. #missing,
		""
	}

	if #missing == 0 then
		lines[#lines + 1] = "No missing static sounds were found."
	else
		lines[#lines + 1] = "Missing sound paths and their Lua references:"
		lines[#lines + 1] = ""

		for _, entry in ipairs(missing) do
			lines[#lines + 1] = "[MISSING] " .. entry.path
			for _, sourcePath in ipairs(SortedSourceList(entry.sources)) do
				lines[#lines + 1] = "  - " .. sourcePath
			end
			lines[#lines + 1] = ""
		end
	end

	lines[#lines + 1] = "Note: the scanner checks literal .wav, .mp3, and .ogg paths found in Lua. Dynamically built paths cannot be inferred."
	return table.concat(lines, "\n")
end

function Scanner.Run(requester)
	if Scanner.Running then
		PrintPrefix(colourText, "A scan is already running.")
		return
	end

	Scanner.Running = true
	local startedAt = SysTime()
	PrintPrefix(colourText, "Scanning mounted Lua sound references on the " .. realmName .. "...")

	local luaFiles = {}
	local visited = {}
	CollectLuaFiles("lua", luaFiles, visited)

	local activeGamemode = engine.ActiveGamemode()
	if activeGamemode and activeGamemode ~= "" then
		CollectLuaFiles("gamemodes/" .. activeGamemode .. "/gamemode", luaFiles, visited)
	end

	table.sort(luaFiles)

	local references = {}
	local skippedFiles = 0
	for _, sourcePath in ipairs(luaFiles) do
		local size = file.Size(sourcePath, "GAME") or -1
		if size <= Scanner.MaxSourceSize then
			local contents = file.Read(sourcePath, "GAME")
			if contents then
				CollectQuotedSounds(contents, sourcePath, references)
			else
				skippedFiles = skippedFiles + 1
			end
		else
			skippedFiles = skippedFiles + 1
		end
	end

	local missing = {}
	for _, entry in pairs(references) do
		if not file.Exists(entry.path, "GAME") then
			missing[#missing + 1] = entry
		end
	end
	table.sort(missing, function(left, right)
		return string.lower(left.path) < string.lower(right.path)
	end)

	file.CreateDir(Scanner.ReportDirectory)
	local reportPath = Scanner.ReportDirectory .. "/latest_" .. realmName .. ".txt"
	local report = BuildReport(startedAt, luaFiles, references, missing, skippedFiles)
	file.Write(reportPath, report)

	Scanner.LastMissing = missing
	Scanner.LastReportPath = "data/" .. reportPath
	Scanner.Running = false

	if #missing == 0 then
		PrintPrefix(colourGood, "Complete: no missing static sounds found. Report: " .. Scanner.LastReportPath)
	else
		PrintPrefix(colourBad, string.format("Complete: %d missing sound(s).", #missing))
		local consoleLimit = math.min(#missing, Scanner.MaxConsoleResults)
		for index = 1, consoleLimit do
			local entry = missing[index]
			local sources = SortedSourceList(entry.sources)
			PrintPrefix(colourBad, "MISSING " .. entry.path .. " (from " .. (sources[1] or "unknown") .. ")")
		end
		if #missing > consoleLimit then
			PrintPrefix(colourText, string.format("%d more result(s) are in the full report.", #missing - consoleLimit))
		end
		PrintPrefix(colourText, "Full report: " .. Scanner.LastReportPath)
	end

	if IsValid(requester) then
		requester:ChatPrint(string.format("Sound scan found %d missing sound(s). See the %s console and %s.", #missing, realmName, Scanner.LastReportPath))
	end
end

local function CanRunCommand(requester)
	if CLIENT then return true end
	return not IsValid(requester) or requester:IsSuperAdmin()
end

concommand.Add("zcity_asset_scan", function(requester)
	if not CanRunCommand(requester) then
		requester:ChatPrint("Only a superadmin can run the server sound scan.")
		return
	end
	Scanner.Run(requester)
end)

concommand.Add("zcity_asset_scan_report", function(requester)
	if not CanRunCommand(requester) then return end
	if not Scanner.LastReportPath then
		PrintPrefix(colourText, "No scan report exists in this session yet.")
		return
	end
	PrintPrefix(colourText, "Latest report: " .. Scanner.LastReportPath)
end)

-- Autorun can execute before every mounted addon has finished initialization.
-- A short delay keeps the scan automatic while avoiding startup false positives.
timer.Simple(3, function()
	Scanner.Run()
end)
