--[[
    Created by Homigrad Development Team
    Please do not re-use without asking for permission first.
]]

local flashMat = Material("vgui/flash.png")
local flashAlpha = 0
local flashStarted = 0
local flashUntil = 0

net.Receive("damage_flash", function(len)
    local dmg = net.ReadFloat()
    local severity = math.Clamp(dmg / 50, 0, 1)
    if severity <= 0 then return end

    local now = CurTime()
    local duration = Lerp(severity, 0.15, 1.2)
    if flashUntil <= now then flashAlpha = 0 end
    flashAlpha = math.max(flashAlpha, Lerp(severity, 50, 255))
    flashStarted = now
    flashUntil = math.max(flashUntil, now + duration)
end)

hook.Add("HUDPaint", "homigrad_damageeffects", function()
    if flashUntil <= CurTime() then return end

    local fade = math.Clamp((flashUntil - CurTime()) / math.max(flashUntil - flashStarted, 0.001), 0, 1)
    surface.SetDrawColor(255, 255, 255, flashAlpha * fade)
    surface.SetMaterial(flashMat)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end)
