-- arghahghahaha randgdol tumbel melecity so tuff
local player_GetAll = player.GetAll
local util_TraceLine = util.TraceLine
local util_TraceHull = util.TraceHull
local IsValid = IsValid
local CurTime = CurTime

local function PlayBoneBreakSound(entity)
    if math.random() < 0.5 then
                entity:EmitSound("owfuck"..math.random(1, 9)..".ogg")
    else
        entity:EmitSound("newbonebreak/break"..math.random(10)..".wav")
    end
end

local TUMBLE_SPEED_THRESHOLD = 250
local TUMBLE_COOLDOWN = 2
local GAP_CHECK_DIST = 30 
local WALL_CHECK_DIST = 20
local WALL_CHECK_HEIGHT = 10

local BASE_TRIP_CHANCE = 0.1
local MAX_TRIP_CHANCE = 0.8

hook.Add("Think", "stanleytumbler", function()
    -- Disabled: restore default ragdoll behavior, no stumbling.
end)