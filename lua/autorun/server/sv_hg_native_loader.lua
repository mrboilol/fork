-- Optional HG Rust acceleration loader.
-- The gamemode remains fully usable without the native DLL.

if not SERVER then return end

HG = HG or {}
HG.Native = HG.Native or {}

local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY)
local cvRust = CreateConVar(
    "hg_rust",
    "1",
    FLAGS,
    "Use the optional hg_native Rust acceleration module when installed."
)

HG.Native.Loaded = HG.Native.Loaded or false
HG.Native.Enabled = false
HG.Native.Module = nil
HG.Native.LastError = nil

local function modulePath()
    if not system.IsWindows() or jit.arch ~= "x64" then
        return nil
    end

    return "lua/bin/gmsv_hg_native_win64.dll"
end

local function setEnabled()
    HG.Native.Enabled = HG.Native.Loaded and cvRust:GetBool()
end

function HG.Native.IsAvailable()
    return HG.Native.Loaded == true
end

function HG.Native.IsEnabled()
    return HG.Native.Enabled == true
end

function HG.Native.GetBackend()
    return HG.Native.IsEnabled() and "rust" or "glua"
end

function HG.Native.TryLoad()
    if HG.Native.Loaded then
        setEnabled()
        return true
    end

    if not cvRust:GetBool() then
        HG.Native.Enabled = false
        return false
    end

    local path = modulePath()
    if not path then
        HG.Native.LastError = "starter build only supports 64-bit Windows server GMod"
        HG.Native.Enabled = false
        print("[HG Native] Unsupported platform; using GLua backend.")
        return false
    end

    -- Check first so a missing optional binary never causes require() noise.
    if not file.Exists(path, "GAME") then
        HG.Native.LastError = "native module not installed"
        HG.Native.Enabled = false
        print("[HG Native] DLL not found; using GLua backend.")
        return false
    end

    local ok, err = pcall(require, "hg_native")
    if not ok then
        HG.Native.LastError = tostring(err)
        HG.Native.Enabled = false
        ErrorNoHalt("[HG Native] Failed to load hg_native; using GLua backend: " .. tostring(err) .. "\n")
        return false
    end

    if not istable(hg_native) or hg_native.loaded ~= true or hg_native.backend ~= "rust" then
        HG.Native.LastError = "hg_native loaded but did not expose the expected API marker"
        HG.Native.Enabled = false
        ErrorNoHalt("[HG Native] Invalid hg_native module; using GLua backend.\n")
        return false
    end

    HG.Native.Module = hg_native
    HG.Native.Loaded = true
    HG.Native.LastError = nil
    setEnabled()

    print(string.format(
        "[HG Native] Rust backend ready (v%s). hg_rust=%s",
        tostring(hg_native.version or "unknown"),
        cvRust:GetBool() and "1" or "0"
    ))

    return true
end

hook.Add("Initialize", "HG.Native.LoadOptionalRust", function()
    HG.Native.TryLoad()
end)

cvars.AddChangeCallback("hg_rust", function(_, _, newValue)
    if tonumber(newValue) == 1 and not HG.Native.Loaded then
        HG.Native.TryLoad()
    else
        setEnabled()
    end

    print("[HG Native] Active backend: " .. HG.Native.GetBackend())
end, "HG.Native.BackendSwitch")
