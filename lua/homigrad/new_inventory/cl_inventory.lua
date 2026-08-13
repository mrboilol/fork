local type = type

local function GetInventorySystem()
	local convar = GetConVar("hg_invsystem")
	if convar then
		return math.Clamp(convar:GetInt(), 0, 2)
	end

	return math.Clamp(GetGlobalInt("InventorySystem", 0), 0, 2)
end

local function GetItemDescription(wep)
	if not IsValid(wep) then return "" end

	local description = wep.Description
	if not isstring(description) or string.Trim(description) == "" then description = wep.Instructions end
	if not isstring(description) or string.Trim(description) == "" then description = wep.Purpose end
	if not isstring(description) then return "" end

	return string.Trim(language.GetPhrase(description))
end

local function GetItemIcon(wep)
	if not IsValid(wep) then return nil end

	local icon2 = wep.WepSelectIcon2
	if type(icon2) == "IMaterial" and icon2:GetName() ~= "null" then
		return icon2
	end

	local icon = wep.WepSelectIcon
	if type(icon) == "IMaterial" and icon:GetName() ~= "null" then
		return icon
	end
	if isnumber(icon) then
		return icon
	end

	if isstring(wep.IconOverride) and wep.IconOverride ~= "" then
		return wep.IconOverride
	end
	return nil
end

local function SelectWeapon(ply, wep)
	if not IsValid(wep) then return end

	net.Start("NI_SelectWeapon")
	net.WriteEntity(wep)
	net.SendToServer()

	if IsValid(ply:GetActiveWeapon()) and wep ~= ply:GetActiveWeapon() then
		surface.PlaySound("arc9_eft_shared/weapon_generic_spin" .. math.random(10) .. ".mp3")
	end
end

local function BuildInventoryOptions(ply)
	local slots = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {} }
	for _, wep in ipairs(ply:GetWeapons()) do
		local slot = wep.Slot or 0
		if slot >= 0 and slot <= 5 then
			table.insert(slots[slot], wep)
		end
	end

	for slot = 0, 5 do
		table.sort(slots[slot], function(a, b) return (a.SlotPos or 0) > (b.SlotPos or 0) end)
	end

	local options = {}
	for slot = 0, 5 do
		local list = slots[slot]
		if #list == 0 then continue end

		local slotName = "Slot " .. (slot + 1)
		if #list == 1 then
			local wep = list[1]
			options[#options + 1] = {
				function() SelectWeapon(ply, wep) end,
				wep:GetPrintName(),
				nil,
				nil,
				GetItemIcon(wep),
				nil,
				nil,
				GetItemDescription(wep)
			}
		else
			local subOptions = {}
			for _, wep in ipairs(list) do
				subOptions[#subOptions + 1] = {
					function() SelectWeapon(ply, wep) end,
					wep:GetPrintName(),
					nil,
					nil,
					GetItemIcon(wep),
					nil,
					nil,
					GetItemDescription(wep)
				}
			end
			options[#options + 1] = {
				function()
					hg.CreateRadialMenu(subOptions, false)
					return -1
				end,
				slotName
			}
		end
	end

	return options
end

hook.Add("PlayerButtonDown", "NI_PlayerButtonDown", function(ply, key)
	if GetInventorySystem() ~= 2 then return end
	if key ~= KEY_1 then return end
	if not ply.organism or ply.organism.otrub then return end

	local options = BuildInventoryOptions(ply)
	if #options == 0 then return end

	hg.CreateRadialMenu(options, false)
end)

hook.Add("PlayerButtonUp", "NI_PlayerButtonUp", function(ply, key)
	if GetInventorySystem() == 2 and key == KEY_1 then
		hg.PressRadialMenu(1)
	end
end)
