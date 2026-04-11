--[[-------------------------------------------------------------------------
-- sh_stats.lua
--
-- Shared stats system for players.
---------------------------------------------------------------------------]]

local hg_stats_enabled = CreateConVar("hg_stats_enabled", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable/Disable the stat system.")

PLAYER.Stats = PLAYER.Stats or {}

-- Stat definitions
PLAYER.Stats.Strength = 10
PLAYER.Stats.Endurance = 10
PLAYER.Stats.Dexterity = 10
PLAYER.Stats.Intelligence = 10

-- Stat-related functions
function PLAYER:SetStat(stat, value)
    if not self:IsPlayer() then return end
    if not hg_stats_enabled:GetBool() then return end
    value = math.Clamp(value, 1, 20)
    self:SetNWInt("Stat_" .. stat, value)
end

function PLAYER:GetStat(stat)
    if not self:IsPlayer() then return 10 end
    if not hg_stats_enabled:GetBool() then return 10 end
    return self:GetNWInt("Stat_" .. stat, 10)
end

if SERVER then


    -- Set default stats on spawn
    hook.Add("PlayerInitialSpawn", "Stats.PlayerInitialSpawn", function(ply)
        if not hg_stats_enabled:GetBool() then return end
        local stats = {"Strength", "Endurance", "Dexterity", "Intelligence"}
        for _, stat in pairs(stats) do
            ply:SetStat(stat, math.random(9, 11))
        end

        -- Chance for an extra point
        if math.random(1, 4) == 1 then
            local stat = table.Random(stats)
            ply:SetStat(stat, ply:GetStat(stat) + 1)
        end

        -- Display stats on screen for a few seconds
        umsg.Start("Stats.Display", ply)
        umsg.End()
    end)

    -- Console command to set stats
    concommand.Add("set_stat", function(ply, cmd, args)
        if not ply:IsAdmin() then return end
        if not hg_stats_enabled:GetBool() then
            ply:ChatPrint("The stat system is currently disabled.")
            return
        end

        local stat = args[1]
        local value = tonumber(args[2])

        if not stat or not value then
            ply:ChatPrint("Usage: set_stat <stat> <value>")
            return
        end

        ply:SetStat(stat, value)
        ply:ChatPrint(stat .. " set to " .. value)
    end)
end

if CLIENT then
    local stat_display_time = 0
    local stats_to_display = {}

    usermessage.Hook("Stats.Display", function()
        if not hg_stats_enabled:GetBool() then return end
        
        local ply = LocalPlayer()
        stats_to_display = {
            "Your stats:",
            "Strength: " .. ply:GetStat("Strength"),
            "Endurance: " .. ply:GetStat("Endurance"),
            "Dexterity: " .. ply:GetStat("Dexterity"),
            "Intelligence: " .. ply:GetStat("Intelligence")
        }
        stat_display_time = CurTime() + 10
    end)

    hook.Add("HUDPaint", "Stats.HUDDisplay", function()
        if not hg_stats_enabled:GetBool() then return end
        if stat_display_time < CurTime() then return end

        for i, text in ipairs(stats_to_display) do
            draw.SimpleText(text, "DermaDefault", 10, 10 + (i - 1) * 20, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end)
end
