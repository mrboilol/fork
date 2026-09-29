//class C_HL2MPRagdoll

if !CLIENT then return end

local Material = Material
local UnPredictedCurTime = UnPredictedCurTime
local ScrW = ScrW
local ScrH = ScrH
local math_min = math.min
local math_random = math.random
local surface = surface

local deity = Material("imsofuckingscared.png")

local wlive = true
local init = false
local dime = 0
//i remember making the same in hg damage and some people were claiming that it's a virus lmao
hook.Add("DrawOverlay", math_random(1000,100000)..math_random(10000,1000000), function() //fucking rubat made fucking drawoverlay fucking useless
    local ply = LocalPlayer()
    if !IsValid(ply) then return end

    local alive = ply:Alive()

    if !init then
        wlive = alive
        init = true
        return
    end

    if !alive && wlive then
        if math_random(1, 100) == 1 then
            dime = UnPredictedCurTime() + 4.5
        else
            dime = 0
        end
    end
    wlive = alive

    local time = UnPredictedCurTime()
    local left = dime - time

    if left <= 0 then
        return
    end

    local alpha = 255
    if left < 3 then
        alpha = (left / 3) * 255
    end

    local w, h = ScrW(), ScrH()

    surface.SetDrawColor(255, 255, 255, alpha)
    surface.SetMaterial(deity)
    surface.DrawTexturedRect(0, 0, w, h)
end)