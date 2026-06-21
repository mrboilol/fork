local hg = hg or {}

local EXHAUSTED_SOUND = "exhaustedloop.ogg"
local EXHAUSTED_STAMINA_START = 100 -- sound begins at this stamina level (quiet)
local EXHAUSTED_STAMINA_END = 15 -- sound reaches max volume at this stamina level

local exhausted_sound = nil

local function get_exhausted_volume(stamina_val)
    if stamina_val <= EXHAUSTED_STAMINA_END then return 1 end
    if stamina_val >= EXHAUSTED_STAMINA_START then return 0 end

    return math.Clamp((EXHAUSTED_STAMINA_START - stamina_val) / (EXHAUSTED_STAMINA_START - EXHAUSTED_STAMINA_END), 0, 1)
end

hook.Add("RenderScreenspaceEffects", "hg_exhausted_loop", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        if exhausted_sound then
            exhausted_sound:FadeOut(0.5)
            exhausted_sound = nil
        end
        return
    end

    local org = ply.organism
    if not org or not org.stamina or org.otrub or org.alive == false then
        if exhausted_sound then
            exhausted_sound:FadeOut(0.5)
            exhausted_sound = nil
        end
        return
    end

    local stamina_val = org.stamina[1] or 0
    local target = get_exhausted_volume(stamina_val)

    if target > 0 then
        if not exhausted_sound then
            exhausted_sound = CreateSound(ply, EXHAUSTED_SOUND)
            if exhausted_sound then
                exhausted_sound:PlayEx(0, 100)
            end
        end

        if exhausted_sound then
            exhausted_sound:ChangeVolume(target, 0.2)
        end
    else
        if exhausted_sound then
            exhausted_sound:FadeOut(0.5)
            exhausted_sound = nil
        end
    end
end)
