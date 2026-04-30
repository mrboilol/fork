
--[[
    Created by Homigrad Development Team
    Please do not re-use without asking for permission first.
]]

util.AddNetworkString("damage_flash")
util.AddNetworkString("headtrauma_flash")
util.AddNetworkString("unconscious_effect")

hook.Add("OnPlayerTakeDamage", "homigrad_damageeffects", function(ply, dmginfo)
    net.Start("damage_flash")
    net.WriteFloat(dmginfo:GetDamage())
    net.Send(ply)

    -- Player thoughts
    local damageType = dmginfo:GetDamageType()
    if bit.band(damageType, DMG_BULLET) == DMG_BULLET then
        if ply:Health() <= 25 then
            PlayerThought(ply, "It's so hot... Why is it so hot when they shot me?")
        end
    elseif bit.band(damageType, DMG_SLASH) == DMG_SLASH then
        if ply:Health() <= 30 then
            PlayerThought(ply, "That cut is deep... I need to stop the bleeding.")
        end
    elseif bit.band(damageType, DMG_BURN) == DMG_BURN then
        PlayerThought(ply, "The fire... it burns!")
    end
end)

function PlayerThought(ply, text)
    ply:Notify(text)
end
