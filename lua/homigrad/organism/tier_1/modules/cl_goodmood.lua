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
    local goodmood = (org and org.goodmood) and math.Clamp(org.goodmood, 0, 1) or 0

    goodmood_lerp = LerpFT(0.04, goodmood_lerp, goodmood)

    if goodmood_lerp > 0.001 then
        goodmood_tab["$pp_colour_brightness"] = goodmood_lerp * 0.05
        goodmood_tab["$pp_colour_contrast"] = 1 + goodmood_lerp * 0.1
        goodmood_tab["$pp_colour_colour"] = 1 + goodmood_lerp * 0.2
        DrawColorModify(goodmood_tab)
    end
end)
