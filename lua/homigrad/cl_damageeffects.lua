--[[
    Created by Homigrad Development Team
    Please do not re-use without asking for permission first.
]]

-- Damage flash
local _flashAlpha = 0
net.Receive("damage_flash", function(len)
    local dmg = net.ReadFloat()
    local maxDmg = 50
    local intensity = math.Clamp(dmg / maxDmg, 0, 1)
    _flashAlpha = intensity * 255
end)

hook.Add("RenderScreenspaceEffects", "homigrad_damageeffects", function()
    -- Damage flash
    if _flashAlpha > 0 then
        _flashAlpha = math.Approach(_flashAlpha, 0, FrameTime() * 150)
        surface.SetDrawColor(255, 0, 0, _flashAlpha)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
end)
