local goodmood_tab = {
    ["$pp_colour_addr"] = 0,
    ["$pp_colour_addg"] = 0,
    ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"] = 1,
    ["$pp_colour_colour"] = 1,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0,
}

local goodmood_lerp = 0
local hg_despairsystem_convar
local zcity_mental_effects_convar
local zcity_mental_enabled_convar

local function mental_effects_enabled()
    if not zcity_mental_enabled_convar then zcity_mental_enabled_convar = GetConVar("zcity_delta_mental_enabled") end
    if zcity_mental_enabled_convar and not zcity_mental_enabled_convar:GetBool() then return false end
    if not hg_despairsystem_convar then hg_despairsystem_convar = GetConVar("hg_despairsystem") end
    if hg_despairsystem_convar and hg_despairsystem_convar:GetInt() == 0 then return false end
    if not zcity_mental_effects_convar then zcity_mental_effects_convar = GetConVar("zcity_delta_mental_effects_enabled") end
    return not zcity_mental_effects_convar or zcity_mental_effects_convar:GetBool()
end

local function get_target_organism()
    local ply = IsValid(lply) and lply or LocalPlayer()
    if not IsValid(ply) then return nil end
    if IsValid(ply:GetNWEntity("spect")) then return nil end
    if not ply:Alive() then return nil end
    return ply.new_organism or ply.organism
end

hook.Add("Post Post Processing", "hg_goodmood_effect", function()
    local ply = IsValid(lply) and lply or LocalPlayer()
    if not IsValid(ply) then return end
    if IsValid(ply:GetNWEntity("spect")) then
        goodmood_lerp = 0
        return
    end
    if not ply:Alive() then
        goodmood_lerp = 0
        return
    end

    local org = get_target_organism()
    if not mental_effects_enabled() then
        goodmood_lerp = LerpFT(0.1, goodmood_lerp, 0)
        return
    end

    local goodmood = (org and org.goodmood) and math.Clamp(org.goodmood, 0, 1) or 0

    local meter = math.Clamp(tonumber(ply:GetNWFloat("zcity_delta_mental_meter", 0)) or 0, -100, 100)
    if meter > 0 then
        goodmood = math.min(goodmood + math.Clamp(meter / 100, 0, 1) * 0.1, 1)
    end

    goodmood_lerp = LerpFT(0.04, goodmood_lerp, goodmood)

    if goodmood_lerp > 0.001 then
        goodmood_tab["$pp_colour_brightness"] = goodmood_lerp * 0.05
        goodmood_tab["$pp_colour_contrast"] = 1 + goodmood_lerp * 0.1
        goodmood_tab["$pp_colour_colour"] = 1 + goodmood_lerp * 0.2
        DrawColorModify(goodmood_tab)
    end
end)
