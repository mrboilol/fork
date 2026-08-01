ZCLP.ClientPresets = ZCLP.ClientPresets or {}
ZCLP.ClientAutoSpawn = ZCLP.ClientAutoSpawn or nil

local DATA_DIR = "zcity_loadout_presets"

local function phrase(key)
    if not ZCLP or not ZCLP.GetPhrase then
        return key
    end
    return ZCLP.GetPhrase(key)
end

local function getLocalPath()
    local id = IsValid(LocalPlayer()) and LocalPlayer():SteamID64() or "unknown"
    return string.format("%s/%s.json", DATA_DIR, id)
end

function ZCLP.SaveLocalPresets()
    if not file.Exists(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end

    local data = {
        presets = ZCLP.ClientPresets,
        autospawn = ZCLP.ClientAutoSpawn
    }

    local json = util.TableToJSON(data, true)
    if json then
        file.Write(getLocalPath(), json)
    end
end

function ZCLP.LoadLocalPresets()
    local path = getLocalPath()
    if not file.Exists(path, "DATA") then
        ZCLP.ClientPresets = {}
        ZCLP.ClientAutoSpawn = nil
        return
    end

    local raw = file.Read(path, "DATA")
    local data = util.JSONToTable(raw or "")

    if istable(data) then
        -- Compatibility check
        if not data.presets and not data.autospawn then
            ZCLP.ClientPresets = data
            ZCLP.ClientAutoSpawn = nil
        else
            ZCLP.ClientPresets = data.presets or {}
            ZCLP.ClientAutoSpawn = data.autospawn
        end
    else
        ZCLP.ClientPresets = {}
        ZCLP.ClientAutoSpawn = nil
    end
end

-- Initial load
timer.Simple(1, function()
    ZCLP.LoadLocalPresets()
end)

net.Receive("zclp_save_snapshot", function()
    local name = net.ReadString()
    local snapshot = net.ReadTable()
    local isUpdate = net.ReadBool()

    if name ~= "" and istable(snapshot) then
        ZCLP.ClientPresets[name] = snapshot
        ZCLP.SaveLocalPresets()

        if IsValid(ZCLP.Menu) then
            ZCLP.Menu:SetPresets(ZCLP.ClientPresets)
        end

        chat.AddText(Color(120, 190, 255), "[ZCLP] ", color_white, phrase(isUpdate and "updated" or "saved"))
    end
end)

net.Receive("zclp_respawned", function()
    if ZCLP.ClientAutoSpawn and ZCLP.ClientPresets[ZCLP.ClientAutoSpawn] then
        net.Start("zclp_load_preset")
        net.WriteString(ZCLP.ClientAutoSpawn)
        net.WriteTable(ZCLP.ClientPresets[ZCLP.ClientAutoSpawn])
        net.SendToServer()
    end
end)

net.Receive("zclp_notify", function()
    local key = net.ReadString()
    local str = phrase(key)

    local argCount = net.ReadUInt(4)
    if argCount > 0 then
        local args = {}
        for i = 1, argCount do
            args[i] = net.ReadString()
        end
        str = string.format(str, unpack(args))
    end

    chat.AddText(Color(120, 190, 255), "[ZCLP] ", color_white, str)
end)

if not ZCLP._DesktopWindowRegistered then
    ZCLP._DesktopWindowRegistered = true
    list.Add("DesktopWindows", {
        icon = ZCLP.MenuIcon or "icon16/package.png",
        title = "Z-City Presets",
        init = function()
            RunConsoleCommand("zclp_menu")
        end
    })
end
