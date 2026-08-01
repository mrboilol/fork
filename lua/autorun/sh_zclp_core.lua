ZCLP = ZCLP or {}

ZCLP.Version = "1.0.0"
ZCLP.UniqueId = "zcity_loadout_presets_subaddon"
ZCLP.MaxPresets = 40
ZCLP.MaxNameLength = 48
ZCLP.MenuIcon = "zcity_loadout_presets/icon.png"

ZCLP.Langs = {
    en = {
        title = "huytown presets",
        incompat = "if you see me tell sancho to update version local variable",
        open_menu = "Open loadout presets",
        request_failed = "nigger try again",
        create = "Create Preset",
        load = "Load Preset",
        remove = "Delete Preset",
        update = "Update Preset",
        refresh = "Refresh",
        name_hint = "Preset name...",
        no_selection = "Select a preset first.",
        saved = "Preset saved.",
        loaded = "Preset loaded.",
        deleted = "Preset deleted.",
        updated = "Preset updated.",
        limit = "Preset limit reached.",
        invalid_name = "Invalid preset name.",
        not_found = "Preset not found.",
        give = "Give to Player",
        select_player = "Select Player",
        given = "Preset given to %s.",
        received = "You received a loadout preset from %s.",
        autospawn = "Spawn with preset",
        preview_weapons = "Weapons:",
        preview_armor = "Armor:",
        preview_clothes = "Clothes:",
        preview_meta = "saved with version:",
        tab_name = "Z-City Presets",
        menu_name = "Loadout Presets"
    }
}

local function getLang()
    return "en"
end

function ZCLP.GetPhrase(key)
    local lang = getLang()
    local tbl = ZCLP.Langs[lang] or ZCLP.Langs.en
    return tbl[key] or ZCLP.Langs.en[key] or key
end

function ZCLP.IsCompatible()
    if not hg or not isstring(hg.Version) then
        return false
    end

    if SERVER and not hg.AddArmor then
        return false
    end

    return true
end

if CLIENT then
    concommand.Add("zclp_menu", function()
        if not ZCLP.IsCompatible() then
            chat.AddText(Color(255, 120, 120), "[ZCLP] ", color_white, ZCLP.GetPhrase("incompat"))
            return
        end
        ZCLP.OpenMenu()
    end)
end
