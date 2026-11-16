hg = hg or {}
hg.ZCityInventoryAddonEnabled = true
hg.ZCityInventoryAddonAutorun = true

if SERVER then
    AddCSLuaFile()
end

local sides = {
    ["sv_"] = "sv_",
    ["sh_"] = "sh_",
    ["cl_"] = "cl_",
    ["_sv"] = "sv_",
    ["_sh"] = "sh_",
    ["_cl"] = "cl_",
}

local files = {
    -- The authoritative loot/inventory implementation is loaded recursively
    -- from homigrad/sh_inventory.lua and homigrad/sv_inventory.lua. Loading the
    -- legacy copies here afterwards replaces their net receivers, hooks and
    -- Player:OpenInventory method with the old non-grid implementation.
    "zcity_inventory/new_inventory/cl_inventory.lua",
    "zcity_inventory/new_inventory/sv_inventory.lua",
    "zcity_inventory/hud/cl_weapon_selector.lua",
}

local function AddFile(path)
    if not file.Exists(path, "LUA") then return end

    local name = string.GetFileFromFilename(path)
    local fileSide = string.lower(string.Left(name, 3))
    local fileSide2 = string.lower(string.Right(string.sub(name, 1, -5), 3))
    local side = sides[fileSide] or sides[fileSide2]

    if SERVER and side == "sv_" then
        include(path)
    elseif side == "sh_" then
        if SERVER then AddCSLuaFile(path) end
        include(path)
    elseif side == "cl_" then
        if SERVER then
            AddCSLuaFile(path)
        else
            include(path)
        end
    else
        if SERVER then AddCSLuaFile(path) end
        include(path)
    end
end

local function LoadZCityInventoryAddon()
    if hg.ZCityInventoryAddonLoadedByAutorun then return end
    hg.ZCityInventoryAddonLoadedByAutorun = true
    hg.ZCityInventoryAddonLoaded = true
    hg.ZCityInventoryAddonEnabled = true

    for _, path in ipairs(files) do
        AddFile(path)
    end

end

hook.Add("HomigradRun", "ZCityInventoryAddonLoader", LoadZCityInventoryAddon)

timer.Simple(0, function()
    if hg and hg.loaded then
        LoadZCityInventoryAddon()
    end
end)
