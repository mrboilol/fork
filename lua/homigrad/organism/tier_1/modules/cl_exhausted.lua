local hg = hg or {}

local EXHAUSTED_SOUND = "exhaustedloop.ogg"
local EXHAUSTED_THRESHOLD = 0.30

local exhausted_sound = nil

local function is_player_tired(org)
    local stamina = org.stamina
    if not stamina or not isnumber(stamina.max) or stamina.max <= 0 then return false end

    return (stamina[1] or 0) / stamina.max < EXHAUSTED_THRESHOLD
end

hook.Add("RenderScreenspaceEffects", "hg_exhausted_loop", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        if exhausted_sound then
            exhausted_sound:Stop()
            exhausted_sound = nil
        end
        return
    end

    local org = ply.organism
    if not org or not org.stamina or org.otrub or org.alive == false then
        if exhausted_sound then
            exhausted_sound:Stop()
            exhausted_sound = nil
        end
        return
    end

    if is_player_tired(org) then
        if not exhausted_sound then
            exhausted_sound = CreateSound(ply, EXHAUSTED_SOUND)
        end

        if exhausted_sound and not exhausted_sound:IsPlaying() then
            exhausted_sound:Play()
        end
    else
        if exhausted_sound then
            exhausted_sound:Stop()
            exhausted_sound = nil
        end
    end
end)
