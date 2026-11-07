CAI.Aircraft = CAI.Aircraft or {}
local AC = CAI.Aircraft

AC.Tracked = AC.Tracked or {}

local CLASSES = {
    npc_helicopter = { radius = 1300, height = 900 },
    npc_combinegunship = { radius = 1100, height = 800 },
    npc_combinedropship = { radius = 1500, height = 1000, drops = true },
}

local NODE_COUNT = 6
local RING_MOVE_DIST = 350
local MIN_SKY_CLEARANCE = 400
local LEASH_MULT = 2.2
local LEASH_GRACE = 5
local LEASH_NUDGE = 600

local DROP_HEIGHT = 300
local DROP_ARRIVE_DIST = 220
local DROP_TIMEOUT = 30
local DROP_INTERVAL = 1
local DROP_DESCENT_TIME = 2.5
local DROP_SETTLE_TIME = 3
local DROP_WEAPONS = { "weapon_ar2", "weapon_smg1" }

local function NodeName(ent, index)
    return "cai_air_" .. ent:EntIndex() .. "_" .. index
end

local function BuildRing(ent, state)
    state.nodes = {}
    for i = 1, NODE_COUNT do
        local node = ents.Create("path_track")
        if not IsValid(node) then return false end
        node:SetKeyValue("targetname", NodeName(ent, i))
        node:SetKeyValue("target", NodeName(ent, i % NODE_COUNT + 1))
        node:SetPos(ent:GetPos())
        node:Spawn()
        state.nodes[i] = node
    end
    for _, node in ipairs(state.nodes) do node:Activate() end
    ent:CallOnRemove("CAI_AircraftPath", function()
        for _, node in ipairs(state.nodes) do SafeRemoveEntity(node) end
        AC.Tracked[ent] = nil
    end)
    return true
end

local function SkyTop(center, height)
    local tr = util.TraceLine({
        start = center + vector_up * 64,
        endpos = center + vector_up * height,
        mask = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos - vector_up * 120 or tr.HitPos
end

local function PlaceRing(state, center, info)
    local top = SkyTop(center, info.height)
    if top.z - center.z < MIN_SKY_CLEARANCE then return false end
    for i, node in ipairs(state.nodes) do
        local yaw = math.rad((i - 1) / NODE_COUNT * 360)
        local dir = Vector(math.cos(yaw), math.sin(yaw), 0)
        local tr = util.TraceLine({ start = top, endpos = top + dir * info.radius, mask = MASK_SOLID_BRUSHONLY })
        node:SetPos(tr.Hit and tr.HitPos - dir * 150 or tr.HitPos)
    end
    state.ringCenter = center
    return true
end

local function NearestNode(ent, state)
    local best, bestDist = 1, math.huge
    for i, node in ipairs(state.nodes) do
        local dist = node:GetPos():DistToSqr(ent:GetPos())
        if dist < bestDist then best, bestDist = i, dist end
    end
    return NodeName(ent, best)
end

local function FollowRing(ent, state)
    ent:Fire("SetTrack", NearestNode(ent, state))
    ent:Fire("StartPatrol")
end

local function FindTarget(ent)
    local current = ent:GetEnemy()
    if IsValid(current) and current:GetClass() ~= "npc_bullseye" and CAI.Util.IsTargetable(current) then
        return current
    end
    local range = CAI.CVNum("cai_aircraft_range")
    local best, bestDist = nil, range * range
    local origin = ent:GetPos()
    local function consider(candidate)
        if ent:Disposition(candidate) ~= D_HT or not CAI.Util.IsTargetable(candidate) then return end
        local dist = candidate:GetPos():DistToSqr(origin)
        if dist < bestDist then best, bestDist = candidate, dist end
    end
    for _, ply in ipairs(player.GetAll()) do consider(ply) end
    for npc in pairs(CAI.Manager.All()) do
        if IsValid(npc) then consider(npc) end
    end
    return best
end

local function FindLandingZone(ent, target)
    local away = ent:GetPos() - target:GetPos()
    away.z = 0
    local baseYaw = away:Angle().y
    for attempt = 0, 5 do
        local yaw = math.rad(baseYaw + attempt * 60)
        local spot = target:GetPos() + Vector(math.cos(yaw), math.sin(yaw), 0) * math.Rand(500, 900)
        local area = navmesh.GetNearestNavArea(spot, false, 400, false, true)
        if IsValid(area) then spot = area:GetClosestPointOnArea(spot) end
        local tr = util.TraceLine({
            start = spot + vector_up * 96,
            endpos = spot - vector_up * 1024,
            mask = MASK_SOLID_BRUSHONLY,
        })
        if tr.Hit and not tr.StartSolid and not tr.HitSky then
            local ground = tr.HitPos
            if SkyTop(ground, DROP_HEIGHT + 200).z - ground.z >= DROP_HEIGHT then return ground end
        end
    end
end

local function SpawnTrooper(ent, ground, target)
    local trooper = ents.Create("npc_combine_s")
    if not IsValid(trooper) then return end

    local start = ent:GetPos() - vector_up * 90
    local offset = VectorRand()
    offset.z = 0
    offset:Normalize()
    local spot = ground + offset * math.Rand(60, 180)
    local tr = util.TraceHull({
        start = spot + vector_up * 96,
        endpos = spot - vector_up * 256,
        mins = Vector(-16, -16, 0),
        maxs = Vector(16, 16, 72),
        mask = MASK_NPCSOLID_BRUSHONLY,
    })
    local landing = (tr.Hit and not tr.StartSolid) and tr.HitPos or ground

    trooper:SetPos(start)
    trooper:SetAngles(Angle(0, ent:GetAngles().y, 0))
    trooper:SetKeyValue("additionalequipment", DROP_WEAPONS[math.random(#DROP_WEAPONS)])
    trooper:Spawn()
    trooper:Activate()
    trooper:SetMoveType(MOVETYPE_NONE)
    trooper:SetNotSolid(true)
    trooper.cai_airdropUntil = CurTime() + DROP_DESCENT_TIME + 1

    local began = CurTime()
    local id = "CAI_Airdrop" .. trooper:EntIndex()
    timer.Create(id, 0, 0, function()
        if not IsValid(trooper) then
            timer.Remove(id)
            return
        end
        local frac = (CurTime() - began) / DROP_DESCENT_TIME
        trooper:SetPos(LerpVector(math.min(frac, 1), start, landing))
        if frac < 1 then return end
        timer.Remove(id)
        trooper:SetMoveType(MOVETYPE_STEP)
        trooper:SetNotSolid(false)
        trooper:DropToFloor()
        trooper.falling, trooper.zcnpc_falling = false, false
        trooper.cai_airdropUntil = nil
        if IsValid(target) and CAI.Util.IsTargetable(target) then
            trooper:SetEnemy(target)
            trooper:UpdateEnemyMemory(target, target:GetPos())
        end
    end)
end

local function UpdateDrop(ent, state, info, target)
    local now = CurTime()
    if state.dropPhase == nil then
        local count = math.floor(CAI.CVNum("cai_dropship_troops"))
        local ground = count > 0 and IsValid(target) and FindLandingZone(ent, target)
        if not ground then
            if count <= 0 or IsValid(target) then state.dropPhase = "done" end
            return false
        end
        state.dropPhase, state.dropGround, state.dropsLeft, state.dropDeadline = "inbound", ground, count, now + DROP_TIMEOUT
        local hover = ground + vector_up * DROP_HEIGHT
        for _, node in ipairs(state.nodes) do node:SetPos(hover) end
        ent:Fire("StopPatrol")
        ent:Fire("SetTrack", NodeName(ent, 1))
        ent:Fire("FlyToSpecificTrackViaPath", NodeName(ent, 1))
        return true
    end
    if state.dropPhase == "inbound" then
        local hover = state.dropGround + vector_up * DROP_HEIGHT
        if ent:GetPos():Distance(hover) < DROP_ARRIVE_DIST then
            state.dropPhase, state.nextTrooperAt = "unloading", now
        elseif now > state.dropDeadline then
            state.dropPhase = "done"
            return false
        end
        return true
    end
    if state.dropPhase == "unloading" then
        if state.dropsLeft > 0 then
            if now >= state.nextTrooperAt then
                state.nextTrooperAt = now + DROP_INTERVAL
                state.dropsLeft = state.dropsLeft - 1
                SpawnTrooper(ent, state.dropGround, target)
                if state.dropsLeft == 0 then state.dropLeaveAt = now + DROP_SETTLE_TIME end
            end
            return true
        end
        if now < state.dropLeaveAt then return true end
        state.dropPhase = "done"
        state.ringCenter = nil
    end
    return false
end

local function Prepare(ent, class)
    if class == "npc_combinegunship" then
        ent:Fire("OmniscientOn")
    elseif class == "npc_helicopter" then
        ent:Fire("GunOn")
    elseif class == "npc_combinedropship" then
        ent:Fire("SetGunRange", "4000")
    end
    if ent.SetMaxLookDistance then ent:SetMaxLookDistance(CAI.CVNum("cai_aircraft_range")) end
end

local function ThinkAircraft(ent, state)
    local class = ent:GetClass()
    local info = CLASSES[class]
    local target = FindTarget(ent)

    if IsValid(target) then
        ent:SetEnemy(target)
        ent:UpdateEnemyMemory(target, target:GetPos())
    end

    if info.drops and state.dropPhase ~= "done" and UpdateDrop(ent, state, info, target) then return end
    if not IsValid(target) then return end

    local center = target:GetPos()
    if not state.ringCenter or state.ringCenter:DistToSqr(center) > RING_MOVE_DIST * RING_MOVE_DIST then
        local moved = PlaceRing(state, center, info)
        if moved and not state.following then
            state.following = true
            FollowRing(ent, state)
        end
    end

    local flat = ent:GetPos() - center
    flat.z = 0
    local now = CurTime()
    if flat:Length() <= info.radius * LEASH_MULT then
        state.leashedSince = nil
        return
    end
    state.leashedSince = state.leashedSince or now
    if now - state.leashedSince < LEASH_GRACE then return end

    FollowRing(ent, state)
    ent:Fire("FlyToSpecificTrackViaPath", NearestNode(ent, state))
    ent:SetVelocity(-flat:GetNormalized() * LEASH_NUDGE)
end

function AC.Register(ent)
    if not IsValid(ent) or AC.Tracked[ent] or not CLASSES[ent:GetClass()] then return end
    local state = {}
    if not BuildRing(ent, state) then return end
    AC.Tracked[ent] = state
    Prepare(ent, ent:GetClass())
    FollowRing(ent, state)
end

CAI.SafeHook("OnEntityCreated", "CAI_AircraftRegister", function(ent)
    timer.Simple(0.2, function()
        if CAI.Enabled() and CAI.CVBool("cai_aircraft") then AC.Register(ent) end
    end)
end)

timer.Create("CAI_Aircraft", 1, 0, function()
    if not CAI.Enabled() or not CAI.CVBool("cai_aircraft") then return end
    local aiDisabled = GetConVar("ai_disabled")
    if aiDisabled and aiDisabled:GetBool() then return end
    for ent, state in pairs(AC.Tracked) do
        if not IsValid(ent) or ent:Health() <= 0 then
            AC.Tracked[ent] = nil
        else
            local ok, err = pcall(ThinkAircraft, ent, state)
            if not ok then ErrorNoHaltWithStack(CAI.PrintPrefix .. "aircraft error: " .. tostring(err)) end
        end
    end
end)
