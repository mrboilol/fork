hg = hg or {}
hg.Appearance = hg.Appearance or {}
hg.Traits = hg.Traits or {}

local Traits = hg.Traits
local APmodule = hg.Appearance
local plymeta = FindMetaTable("Player")

Traits.Registry = Traits.Registry or {}
Traits.StartingPoints = Traits.StartingPoints or 0
Traits.MaxSelected = Traits.MaxSelected or 32
local hg_johnmode = CreateConVar("hg_johnmode", "0", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bypass trait conflicts and point costs", 0, 1)
Traits.Categories = Traits.Categories or {
	positive = true,
	neutral = true,
	negative = true
}

local function NormalizeTraitID(id)
	if not isstring(id) then return nil end

	id = string.lower(string.Trim(id))
	if id == "" or #id > 64 or string.find(id, "[^%w_%-]") then return nil end

	return id
end

local function NormalizeCategory(category)
	category = isstring(category) and string.lower(string.Trim(category)) or "neutral"
	return Traits.Categories[category] and category or nil
end

local function NormalizePoints(category, points)
	points = math.abs(math.Round(tonumber(points) or 0))
	if category == "positive" then return -points end
	if category == "negative" then return points end
	return 0
end

function Traits.Register(id, data)
	id = NormalizeTraitID(id)
	if not id then error("[Traits] Trait IDs may only contain letters, numbers, underscores, and dashes", 2) end
	if not istable(data) then error("[Traits] Trait data must be a table", 2) end

	local category = NormalizeCategory(data.Category or data.Type)
	if not category then error("[Traits] Invalid category for trait '" .. id .. "'", 2) end

	local trait = table.Copy(data)
	trait.ID = id
	trait.Name = isstring(trait.Name) and trait.Name or string.NiceName(id)
	trait.Description = isstring(trait.Description) and trait.Description or ""
	trait.Category = category
	trait.Points = NormalizePoints(category, trait.Points or trait.Cost)
	trait.SortOrder = tonumber(trait.SortOrder) or 0
	trait.Modifiers = istable(trait.Modifiers) and trait.Modifiers or {}
	trait.Bonuses = istable(trait.Bonuses) and trait.Bonuses or {}

	Traits.Registry[id] = trait
	return trait
end

function Traits.Get(id)
	return Traits.Registry[NormalizeTraitID(id) or ""]
end

function Traits.GetByCategory(category)
	category = NormalizeCategory(category)
	if not category then return {} end

	local result = {}
	for _, trait in pairs(Traits.Registry) do
		if trait.Category == category then
			result[#result + 1] = trait
		end
	end

	table.sort(result, function(a, b)
		if a.SortOrder != b.SortOrder then return a.SortOrder < b.SortOrder end
		if a.Name != b.Name then return a.Name < b.Name end
		return a.ID < b.ID
	end)

	return result
end

function Traits.NormalizeSelection(selection)
	if not istable(selection) then return {} end

	local selected = {}
	local seen = {}
	for key, value in pairs(selection) do
		local id = value
		if isstring(key) and value == true then id = key end
		id = NormalizeTraitID(id)

		if id and Traits.Registry[id] and not seen[id] then
			seen[id] = true
			selected[#selected + 1] = id
		end
	end

	table.sort(selected)
	return selected
end

function Traits.GetPointBalance(selection)
	local balance = Traits.StartingPoints
	for _, id in ipairs(Traits.NormalizeSelection(selection)) do
		balance = balance + Traits.Registry[id].Points
	end

	return balance
end

function Traits.IsJohnMode()
	return hg_johnmode:GetBool()
end

function Traits.ValidateSelectionFormat(selection)
	if selection == nil then return true end
	if not istable(selection) then return false, "Trait selection is damaged" end
	if table.Count(selection) > Traits.MaxSelected then
		return false, "Too many traits selected"
	end

	local supplied = {}
	for key, value in pairs(selection) do
		local id = value
		if isstring(key) and value == true then id = key end
		id = NormalizeTraitID(id)
		if not id or supplied[id] then return false, "Trait selection contains an invalid trait" end
		supplied[id] = true
	end

	return true
end

function Traits.ValidateSelection(selection, requireBalance)
	local formatValid, formatReason = Traits.ValidateSelectionFormat(selection)
	if not formatValid then return false, Traits.StartingPoints, {}, formatReason end

	local normalized = Traits.NormalizeSelection(selection)
	for key, value in pairs(selection or {}) do
		local id = value
		if isstring(key) and value == true then id = key end
		id = NormalizeTraitID(id)
		if not Traits.Registry[id] then
			return false, Traits.StartingPoints, {}, "Trait selection contains an unregistered trait"
		end
	end

	local balance = Traits.GetPointBalance(normalized)
	if not Traits.IsJohnMode() then
		for _, id in ipairs(normalized) do
			local conflicts = Traits.Registry[id].Conflicts
			if istable(conflicts) then
				for _, conflict in ipairs(conflicts) do
					for _, otherID in ipairs(normalized) do
						local other = Traits.Registry[otherID]
						if otherID != id and (otherID == conflict or other.Category == conflict) then
							return false, balance, normalized, Traits.Registry[id].Name .. " cannot be combined with " .. other.Name
						end
					end
				end
			end
		end
	end
	if requireBalance != false and balance < 0 and not Traits.IsJohnMode() then
		return false, balance, normalized, "You need 0 or more trait points"
	end

	return true, balance, normalized
end

function Traits.SelectionHas(selection, id)
	id = NormalizeTraitID(id)
	if not id then return false end

	for _, selectedID in ipairs(Traits.NormalizeSelection(selection)) do
		if selectedID == id then return true end
	end

	return false
end

local function RunTraitCallback(trait, callbackName, ply)
	local callback = trait and trait[callbackName]
	if not isfunction(callback) then return end

	local success, err = pcall(callback, ply, trait)
	if not success then
		ErrorNoHalt("[Traits] " .. trait.ID .. " " .. callbackName .. " failed: " .. tostring(err) .. "\n")
	end
end

function Traits.ApplyToPlayer(ply, selection)
	if CLIENT then return false, "Traits are server-authoritative" end
	if not IsValid(ply) or not ply:IsPlayer() then return false, "Invalid player" end

	local valid, balance, normalized, reason = Traits.ValidateSelection(selection, true)
	if not valid then return false, reason, balance end

	local oldSelection = Traits.NormalizeSelection(ply.HGTraitSelection)
	local oldSet = {}
	local newSet = {}
	for _, id in ipairs(oldSelection) do oldSet[id] = true end
	for _, id in ipairs(normalized) do newSet[id] = true end

	for _, id in ipairs(oldSelection) do
		if not newSet[id] then RunTraitCallback(Traits.Registry[id], "OnRemove", ply) end
	end

	ply.HGTraitSelection = table.Copy(normalized)
	ply.HGTraits = newSet
	ply:SetNWString("hg_traits", table.concat(normalized, ","))
	ply:SetNWInt("hg_trait_points", balance)

	for _, id in ipairs(normalized) do
		local trait = Traits.Registry[id]
		if not oldSet[id] then RunTraitCallback(trait, "OnSelect", ply) end
		RunTraitCallback(trait, "OnApply", ply)
	end

	hook.Run("HGTraitsChanged", ply, oldSelection, table.Copy(normalized), balance)
	return true, nil, balance
end

function Traits.GetPlayerSelection(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return {} end
	if SERVER then return table.Copy(ply.HGTraitSelection or {}) end

	local encoded = ply:GetNWString("hg_traits", "")
	if ply.HGTraitSelectionCacheString == encoded then
		return table.Copy(ply.HGTraitSelectionCache or {})
	end

	local selection = encoded == "" and {} or string.Explode(",", encoded, false)
	selection = Traits.NormalizeSelection(selection)
	ply.HGTraitSelectionCacheString = encoded
	ply.HGTraitSelectionCache = selection
	return table.Copy(selection)
end

function Traits.GetPlayerMultiplier(ply, key, default)
	local value = tonumber(default) or 1
	local hasVibrams = false
	for _, id in ipairs(Traits.GetPlayerSelection(ply)) do
		if id == "vibrams" then hasVibrams = true end
		local modifier = Traits.Registry[id].Modifiers[key]
		if isnumber(modifier) then value = value * modifier end
	end
	if key == "movement_speed" and hasVibrams and value < 1 then value = 1 - (1 - value) * 0.35 end
	return value
end

function Traits.GetPlayerBonus(ply, key, default)
	local value = tonumber(default) or 0
	for _, id in ipairs(Traits.GetPlayerSelection(ply)) do
		local bonus = Traits.Registry[id].Bonuses[key]
		if isnumber(bonus) then value = value + bonus end
	end
	return value
end

function Traits.GetSpawnAmputationLimbPool(ply)
	local available = {larm = true, rarm = true, lleg = true, rleg = true}
	local constrained = false

	for _, id in ipairs(Traits.GetPlayerSelection(ply)) do
		local pool = Traits.Registry[id].AmputationLimbPool
		if istable(pool) then
			local allowed = {}
			for _, limb in ipairs(pool) do
				if available[limb] then allowed[limb] = true end
			end
			available = allowed
			constrained = true
		end
	end

	if constrained and next(available) == nil then
		available = {larm = true, rarm = true, lleg = true, rleg = true}
	end

	local result = {}
	for _, limb in ipairs({"larm", "rarm", "lleg", "rleg"}) do
		if available[limb] then result[#result + 1] = limb end
	end
	return result
end

function plymeta:HasTrait(id)
	if SERVER and self.HGTraits then return self.HGTraits[NormalizeTraitID(id) or ""] == true end
	return Traits.SelectionHas(Traits.GetPlayerSelection(self), id)
end

function plymeta:GetTraitPointBalance()
	if SERVER then return Traits.GetPointBalance(self.HGTraitSelection) end
	return self:GetNWInt("hg_trait_points", Traits.StartingPoints)
end

function plymeta:GetTraitMultiplier(key, default)
	return Traits.GetPlayerMultiplier(self, key, default)
end

function plymeta:GetTraitBonus(key, default)
	return Traits.GetPlayerBonus(self, key, default)
end

APmodule.SkeletonAppearanceTable = APmodule.SkeletonAppearanceTable or {}
APmodule.SkeletonAppearanceTable.ATraits = APmodule.SkeletonAppearanceTable.ATraits or {}

local previousValidator = APmodule.AppearanceValidater
function APmodule.AppearanceValidater(tblAppearance)
	if not istable(tblAppearance) then return false end
	if isfunction(previousValidator) and not previousValidator(tblAppearance) then return false end

	local valid = Traits.ValidateSelectionFormat(tblAppearance.ATraits)
	return valid
end
