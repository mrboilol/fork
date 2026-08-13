local hg = hg or {}

local EXHAUSTED_SOUND = "exhaustedloop.mp3"
local EXHAUSTED_STAMINA_START = 100 -- sound begins at this stamina level (quiet)
local EXHAUSTED_STAMINA_END = 15 -- sound reaches max volume at this stamina level

local exhausted_sound = nil
local exhausted_sound_loading = false
local exhausted_volume = 0
local exhausted_target = 0

local function get_exhausted_volume(stamina_val)
    if stamina_val <= EXHAUSTED_STAMINA_END then return 1 end
    if stamina_val >= EXHAUSTED_STAMINA_START then return 0 end

    return math.Clamp((EXHAUSTED_STAMINA_START - stamina_val) / (EXHAUSTED_STAMINA_START - EXHAUSTED_STAMINA_END), 0, 1)
end

local function start_exhausted_sound()
    if exhausted_sound_loading or IsValid(exhausted_sound) then return end

    exhausted_sound_loading = true
    sound.PlayFile("sound/" .. EXHAUSTED_SOUND, "noblock noplay", function(station)
        exhausted_sound_loading = false
        if not IsValid(station) then return end
        if exhausted_target <= 0 then
            station:Stop()
            return
        end

        station:SetVolume(0)
        station:EnableLooping(true)
        station:Play()
        exhausted_sound = station
    end)
end

local function update_exhausted_sound(target)
    exhausted_target = target
    if target > 0 then
        start_exhausted_sound()
    end

    if not IsValid(exhausted_sound) then
        exhausted_sound = nil
        exhausted_volume = 0
        return
    end

    exhausted_volume = math.Approach(exhausted_volume, target, FrameTime() * 2)
    exhausted_sound:SetVolume(exhausted_volume)
    if target <= 0 and exhausted_volume <= 0.001 then
        exhausted_sound:Stop()
        exhausted_sound = nil
    end
end

hook.Add("RenderScreenspaceEffects", "hg_exhausted_loop", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        update_exhausted_sound(0)
        return
    end

    local org = ply.organism
    if not org or not org.stamina or org.otrub or org.alive == false then
        update_exhausted_sound(0)
        return
    end

    local stamina_val = org.stamina[1] or 0
    update_exhausted_sound(get_exhausted_volume(stamina_val))
end)
