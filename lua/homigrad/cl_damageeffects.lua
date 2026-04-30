--[[
    Created by Homigrad Development Team
    Please do not re-use without asking for permission first.
]]

-- Damage flash
local _flashAlpha = 0
net.Receive("damage_flash", function(len)
    local dmg = net.ReadFloat()
    local maxDmg = 100
    local intensity = math.Clamp(dmg / maxDmg, 0, 1)
    _flashAlpha = intensity * 2
end)

-- Thoughts are now handled by the notification system.

-- Headtrauma flash
local _headtraumaCooldown = false
net.Receive("headtrauma_flash", function(len)
    if _headtraumaCooldown then return end
    _headtraumaCooldown = true
    timer.Simple(1, function()
        _headtraumaCooldown = false
    end)
    local интeнcивнocть = net.ReadFloat()
    интeнcивнocть = math.Clamp(интeнcивнocть, 0.1, 1)
    local длитeльнocть = net.ReadFloat()
    длитeльнocть = math.Clamp(длитeльнocть, 0.1, 2)
    local sound = net.ReadString()
    if sound != "" then
        surface.PlaySound(sound)
    end
    RunConsoleCommand("hg_flash", интeнcивнocть, длитeльнocть)
end)

-- Unconscious effect
net.Receive("unconscious_effect", function(len)
    surface.PlaySound("knocked.wav")
    RunConsoleCommand("hg_flash", 1, 1, 255, 255, 255)
end)

hook.Add("RenderScreenspaceEffects", "homigrad_damageeffects", function()
    -- Damage flash
    if _flashAlpha > 0 then
        _flashAlpha = math.Approach(_flashAlpha, 0, FrameTime() * 2)
        surface.SetDrawColor(255, 0, 0, _flashAlpha * 100)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end


end)