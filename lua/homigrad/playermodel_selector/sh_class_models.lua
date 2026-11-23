hg = hg or {}

local CLASS_MODELS = {
	["models/eradium/protogen_player.mdl"] = {class = "furry", data = {instant = true}},
	["models/zcity/player/zombie_classic.mdl"] = {class = "headcrabzombie"},
	["models/player/vortigaunt.mdl"] = {class = "Vortigaunt"},
	["models/crusader/rainworld/scug.mdl"] = {class = "Slugcat"},
	["models/crusader/rainworld/scugarti.mdl"] = {class = "Slugcat"},
	["models/crusader/rainworld/scuggorm.mdl"] = {class = "Slugcat"},
	["models/crusader/rainworld/scugriv.mdl"] = {class = "Slugcat"},
	["models/crusader/rainworld/scugsaint.mdl"] = {class = "Slugcat"},
	["models/player/combine_soldier.mdl"] = {class = "Combine"},
	["models/player/combine_super_soldier.mdl"] = {class = "Combine"},
	["models/player/police.mdl"] = {class = "Metrocop"},
	["models/gfreakman/gordonf_highpoly.mdl"] = {class = "Gordon"},
	["models/humans/gordon/group01/gordoncitizen.mdl"] = {class = "Gordon"},
}

local function registerClassModels()
	local known = {}
	for _, mdl in pairs(player_manager.AllValidModels()) do
		known[string.lower(mdl)] = true
	end
	for mdl, entry in pairs(CLASS_MODELS) do
		if not known[mdl] and file.Exists(mdl, "GAME") then
			player_manager.AddValidModel(entry.class .. " " .. string.GetFileFromFilename(mdl):StripExtension(), mdl)
		end
	end
end

hook.Add("InitPostEntity", "ZC_PMS_ClassModels", registerClassModels)

function hg.GetModelPlayerClass(mdl)
	return isstring(mdl) and CLASS_MODELS[string.lower(mdl)] or nil
end
