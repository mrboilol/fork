if CLIENT then return end

-- Z-City compatibility: intercepts door open inputs fired by LegAttack (player kicks).
-- PlayerUse never fires for Z-City kicks, so we hook AcceptInput instead.
-- When a player kick tries to open a barricaded door, we push the barricade at
-- 2x normal force and block the door from opening.

local IsValid = IsValid
local util_TraceLine = util.TraceLine
local timer_Simple = timer.Simple

hook.Add("AcceptInput", "DoorBar_ZCityKickCompat", function(ent, input, activator, caller, value)
    if not IsValid(ent) or ent:GetClass() ~= "prop_door_rotating" then return end

    -- Z-City LegAttack fires "openawayfrom" specifically; we only intercept that.
    -- Intercepting "open" too would block our own Fire("Open") animation call.
    if input:lower() ~= "openawayfrom" then return end

    -- Only intercept inputs triggered directly by a player (leg kick fires these)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if ent.DoorBlocked then return true end

    local door_locked = ent:GetInternalVariable("m_bLocked") ~= 0
    if not door_locked then return end

    local trentpos = ent:GetPos()
    local obb_maxs = ent:OBBMaxs()
    local convardist = GetConVarNumber("door_barricading_distance")

    local hitnormal = activator:GetEyeTrace().HitNormal

    local doorpos = trentpos - ent:GetRight() * (obb_maxs.x * 7) - ent:GetUp() * (obb_maxs.z * 0.5)
    local idealpos  = doorpos + hitnormal * -0.1
    local idealpos2 = doorpos + hitnormal * -convardist

    local doortr = util_TraceLine({ start = idealpos, endpos = idealpos2, filter = ent })
    local doortrhit = doortr.HitPos

    local min = Vector(
        math.min(idealpos.x, doortrhit.x),
        math.min(idealpos.y, doortrhit.y),
        math.min(idealpos.z, doortrhit.z)
    )
    local max = Vector(
        math.max(idealpos.x, doortrhit.x),
        math.max(idealpos.y, doortrhit.y),
        math.max(idealpos.z, doortrhit.z)
    )

    local barricade_ent
    for _, candidate in ipairs(ents.FindInBox(min, max)) do
        if candidate == activator then return end
        if candidate:GetClass() == ent:GetClass() then return end
        local phys = candidate:GetPhysicsObject()
        if IsValid(phys) and phys:GetMass() > 1 then
            if util.IsValidModel(candidate:GetModel()) and trentpos:Distance(candidate:GetPos()) < convardist * 2 then
                barricade_ent = candidate
                break
            end
        end
    end

    if not IsValid(barricade_ent) then return end

    -- Push barricade at 2x the normal door_barricading_forcepower
    local pushpower = GetConVarNumber("door_barricading_forcepower") * 2
    local physbarricade = barricade_ent:GetPhysicsObject()
    if pushpower > 0 then
        physbarricade:SetVelocity(-(trentpos - barricade_ent:GetPos()) * pushpower * 10 / physbarricade:GetMass())
    end

    ent.DoorBlocked = true
    ent.LastDoorSpeed = ent:GetKeyValues()["speed"]
    ent:SetKeyValue("speed", 25)
    ent:Fire("Open", 1, 0, activator)
    ent:Fire("Close", 1, 0.3, activator)
    timer_Simple(1, function()
        if IsValid(ent) then
            ent.DoorBlocked = false
            ent:SetKeyValue("speed", ent.LastDoorSpeed)
        end
    end)
    timer_Simple(0.2, function()
        if IsValid(ent) then ent:EmitSound("physics/wood/wood_crate_impact_hard2.wav") end
    end)

    return true -- block the original open input
end)
