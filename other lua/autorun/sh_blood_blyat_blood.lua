//OG code was made for my zlegacy
//then remade for my homicide
//and here we are

//i hate everything and everyone

// FINAL EDIT: i tried optimizing it as much as i could, but it'll still lag bc of source engine's decal system

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("blyadinagoviadina")
    util.AddNetworkString("fountainbloodoutcome")
    util.AddNetworkString("fountainbloodoutcome2")
    util.AddNetworkString("blyadinagoviadina2")
    util.AddNetworkString("blyadmist2")
    util.AddNetworkString("blyadmist22")
    local net_Start = net.Start
    local net_WriteVector = net.WriteVector
    local net_WriteFloat = net.WriteFloat
    local net_WriteEntity = net.WriteEntity
    local net_Broadcast = net.Broadcast

    hook.Add("OnEntityCreated", "vafli_em23", function(ply) //works?? idk! doesnt seem to for some reason..
	    if !paranoidABC415.svblood:GetBool() then return end
        ply:SetBloodColor(DONT_BLEED)
    end)
    hook.Add("EntityTakeDamage", "vafli_em11112", function(ply, dmginfo, hggg)
        //print(123) 
        if !paranoidABC415.svblood:GetBool() then return end
        ply:SetBloodColor(DONT_BLEED) //navsiakiy
        if dmginfo:IsBulletDamage() and (ply:IsRagdoll() or ply:IsPlayer() or ply:IsNPC()) then

        net_Start("blyadinagoviadina")
            net_WriteVector(dmginfo:GetDamagePosition())
            net_WriteVector(dmginfo:GetDamageForce():GetNormalized())
            net_WriteFloat(dmginfo:GetDamage())
        net_Broadcast()
        net_Start("fountainbloodoutcome")
            net_WriteEntity(ply)
            net_WriteVector(dmginfo:GetDamagePosition())
            net_WriteVector(dmginfo:GetDamageForce():GetNormalized())
            net_WriteFloat(0)
            net_WriteFloat(math.Rand(1.5,3.5))
        net_Broadcast()
        end
    end)
end



//i really need to make it at least function based, not just shit it all in netreceive, but who cares?
//fuck you, past self for this bullshit

local function initshit() //idk why, but i gotta make a function
    
blood_drop = {
	"bleeding/bleeding1.wav",
	"bleeding/bleeding2.wav",
	"bleeding/bleeding3.wav",
	"bleeding/bleeding4.wav",
}

//Mad? — 21:57
//ты либо вручную делаешь то, что нормальный рантайм закэшировал бы за тебя, либо получаешь просадку по фреймрейту на серверах с кучей аддонов

local math_random = math.random
local math_Rand = math.Rand
local math_Clamp = math.Clamp
local math_floor = math.floor
local Vector = Vector
local VectorRand = VectorRand
local Color = Color
local Material = Material
local util_DecalEx = util.DecalEx
local ParticleEmitter = ParticleEmitter
local sound_Play = sound.Play
local CurTime = CurTime
local IsValid = IsValid
local timer_Create = timer.Create
local timer_Remove = timer.Remove
local game_GetWorld = game.GetWorld
local WorldToLocal = WorldToLocal
local LocalToWorld = LocalToWorld

local blood_drop_local = blood_drop
local vec_zero = Vector(0,0,0)
local col_white = Color(255, 255, 255, 255)
local col_blood = Color(40, 0, 0)

local drop_strings = {}
local drop_mats = {}
for i = 1, 11 do
    drop_strings[i] = "effects/droplets/drop" .. i
    drop_mats[i] = Material(drop_strings[i])
end

local blood_strings = {}
local blood_mats = {}
for i = 1, 8 do
    blood_strings[i] = "kotyatki/blood" .. i
    blood_mats[i] = Material(blood_strings[i])
end

local smoke_strings = {}
for i = 1, 9 do
    smoke_strings[i] = "particle/smokesprites_000" .. i
end

local recent_decals = {}
local head = 1
local tail = 1

local function can_place_decal(pos)
    local ct = CurTime()
    while tail < head do
        local d = recent_decals[tail]
        if ct - d.t < 5 then 
            break
        end
        recent_decals[tail] = nil
        tail = tail + 1
    end
    
    local count = 0
    for i = tail, head - 1 do
        local d = recent_decals[i]
        if d.pos:DistToSqr(pos) < 15 then
            count = count + 1
            if count >= 7 then
                return false
            end
        end
    end
    
    local next_decal = recent_decals[head]
    if next_decal then
        next_decal.pos = pos
        next_decal.t = ct
    else
        recent_decals[head] = {pos = pos, t = ct}
    end
    
    head = head + 1
    return true
end

if CLIENT then
    net.Receive("blyadinagoviadina", function()
        if !paranoidABC415.clblood:GetBool() then return end
        local pos = net.ReadVector()
        local dir = net.ReadVector()
        local dmg = net.ReadFloat()

        if !dir || dir == vec_zero then
            dir = Vector(0, 0, -1)
        end

        local emitter = ParticleEmitter(pos)
        if !emitter then return end
        //main particles
        local count = math_Clamp(math_floor(dmg / 4), 10, 25)
        local gravity_1 = Vector(0, 0, -450)
        for i = 1, count do
            local part = emitter:Add(drop_strings[math_random(1,11)], pos + dir * 1.5)
            if part then
                local speed = dmg * 2 + math_Rand(70,120)
                local spread = 0.01 + (dmg / 700)
                local vel = dir * speed + VectorRand() * (speed * spread)

                part:SetVelocity(vel)
                part:SetDieTime(10)
                part:SetStartAlpha(255)
                part:SetEndAlpha(0)
                part:SetStartSize(math_Clamp(1 + (dmg), 3, 4))
                part:SetGravity(gravity_1)
                part:SetAirResistance(10)
                part:SetCollide(true)
                part:SetRoll(math_Rand(0, 360))
                part:SetRollDelta(math_Rand(-20, 20))

                local decalSize = math_Clamp(dmg / math_random(8,16), 5, 9)
                part:SetCollideCallback( function( p, hitpos, hitnormal )
                    sound_Play(blood_drop_local[math_random(1, #blood_drop_local)], hitpos, 55, 100,1)
                    if can_place_decal(hitpos) then
                        util_DecalEx(drop_mats[math_random(1,11)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_white, decalSize, decalSize)
                    end
                    p:SetDieTime( 0 )
                end)
            end
        end

        local entryCount = math_Clamp(math_floor(dmg / 2), 5, 20)
        local gravity_2 = Vector(0, 0, -600)
        for i = 1, entryCount do            
            local part = emitter:Add(drop_strings[math_random(1,11)], pos)
            if part then
                local speed = math_random(20, 80)
                local vel = -dir * speed + VectorRand() * (speed * 0.1)

                part:SetVelocity(vel)
                part:SetDieTime(10)
                part:SetStartAlpha(200)
                part:SetEndAlpha(0)
                part:SetStartSize(math_Rand(2, 3))
                part:SetEndSize(0)
                part:SetGravity(gravity_2)
                part:SetAirResistance(40)
                part:SetCollide(true)
                part:SetColor(60, 0, 0)
                
                local decalSize = math_Clamp(dmg / math_random(16,32), 4, 8)
                part:SetCollideCallback( function( p, hitpos, hitnormal )
                    if can_place_decal(hitpos) then
                        util_DecalEx(drop_mats[math_random(1,11)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_white, decalSize, decalSize)
                    end
                    p:SetDieTime( 0 )
                end)
            end
        end

        //additional STRONGEr particles
        local count = math_Clamp(math_floor(dmg / 4.5), 10, 30)
        for i = 1, count do
            local part = emitter:Add(drop_strings[math_random(1,11)], pos + dir * 1.5)
            if part then
                local speed = dmg * 5 + math_Rand(220,290)
                local spread = 0.01 + (dmg / 1100)
                local vel = dir * speed + VectorRand() * (speed * spread)

                part:SetVelocity(vel)
                part:SetDieTime(10)
                part:SetStartAlpha(255)
                part:SetEndAlpha(0)
                part:SetStartSize(math_Clamp(1 + (dmg), 3, 4))
                part:SetGravity(gravity_1)
                part:SetAirResistance(10)
                part:SetCollide(true)
                part:SetRoll(math_Rand(0, 360))
                part:SetRollDelta(math_Rand(-20, 20))

                local decalSize = math_Clamp(dmg / math_random(8,16), 4, 8)
                part:SetCollideCallback( function( p, hitpos, hitnormal )
                    if can_place_decal(hitpos) then
                        util_DecalEx(drop_mats[math_random(1,11)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_white, decalSize, decalSize)
                    end
                    //debugoverlay.Cross(hitpos,5,5,Color(255,0,0),true)
                    p:SetDieTime( 0 )
                    
                end)
            end
        end
        emitter:Finish()
    end)
end

if CLIENT then

    net.Receive("blyadinagoviadina2", function()
        if !paranoidABC415.clblood:GetBool() then return end
        local pos = net.ReadVector()
        local dir = net.ReadVector()

        if not dir or dir == vec_zero then
            dir = Vector(0, 0, -1)
        end

        local emitter = ParticleEmitter(pos)
        if not emitter then return end
//i have absolutely NO IDEA why custom decals wont work
//prolly because source engine is ass
// edit: i dont remember what i was talking about here
        local gravity_3 = Vector(0, 0, -350)
        for i = 1, math_random(50,100) do
            local part = emitter:Add(blood_strings[math_random(1,8)], pos + dir * 1.5)
            if part then
                local speed = math_Rand(10,40)
                local spread = math_Rand(10,20)
                local vel = dir * speed + VectorRand() * (speed * spread)
                part:SetVelocity(vel)
                part:SetDieTime(10)
                part:SetStartAlpha(255)
                part:SetEndAlpha(0)
                part:SetStartSize(math_Rand(12,19))
                part:SetGravity(gravity_3)
                part:SetAirResistance(10)
                part:SetCollide(true)
                part:SetRoll(math_Rand(0, 360))
                part:SetRollDelta(math_Rand(-20, 20))

                local decalSize = math_Rand(3,5)
                part:SetCollideCallback( function( p, hitpos, hitnormal )
                    if can_place_decal(hitpos) then
                        util_DecalEx(blood_mats[math_random(1,8)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_blood, decalSize / 4, decalSize / 4)
                    end
                    p:SetDieTime( 0 )
                    sound_Play(blood_drop_local[math_random(1, #blood_drop_local)], hitpos, 55, 100,1)
                end)
            end
        end

        emitter:Finish()
    end)
    net.Receive("blyadmist2", function()
        if !paranoidABC415.clblood:GetBool() then return end
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end

        local gravity_mist = Vector(0, 0, -35)

        for i = 1, math_random(45, 75) do
            local part = emitter:Add(smoke_strings[math_random(1, 9)], pos + VectorRand() * 25)
            if part then
                part:SetVelocity(VectorRand() * 50 + Vector(0,0,math_Rand(-10,30)))
                part:SetDieTime(15)
                part:SetStartAlpha(140)
                part:SetEndAlpha(85)
                part:SetColor(70,0,0)
                part:SetStartSize(math_Rand(50,65))
                part:SetGravity(gravity_mist)
                part:SetAirResistance(1)
                part:SetCollide(true)
                part:SetRoll(math_Rand(0, 360))
                part:SetRollDelta(math_Rand(-0.5, 0.5))
                local decalSize = math_Rand(3,5)
                part:SetCollideCallback( function( p, hitpos, hitnormal )
                    if can_place_decal(hitpos) then
                        util_DecalEx(blood_mats[math_random(1,8)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_blood, decalSize / 4, decalSize / 4)
                    end
                    p:SetDieTime( 0 )
                    sound_Play(blood_drop_local[math_random(1, #blood_drop_local)], hitpos, 55, 100,1)
                end)
            end
        end

        emitter:Finish()        
    end)


    net.Receive("fountainbloodoutcome", function()
        if !paranoidABC415.clblood:GetBool() then return end
        local ent = net.ReadEntity()
        local pos = net.ReadVector()
        local dir = net.ReadVector()
        local power = net.ReadFloat()
        local duration = net.ReadFloat()

        if !dir || dir == vec_zero then dir = Vector(0, 0, -1) end
        
        local endtime = CurTime() + (duration || 2)
        local timerid = "blood_fountain_" .. tostring(pos.x) .. "_" .. tostring(pos.y) .. "_" .. tostring(CurTime())
        
        local bone = nil
        local lpos = nil
        local lrot = nil

        if IsValid(ent) then
            local closestDist = 999999
            for i = 0, ent:GetBoneCount() - 1 do
                local bpos = ent:GetBonePosition(i)
                if bpos then
                    local dist = bpos:DistToSqr(pos)
                    if dist < closestDist then
                        closestDist = dist
                        bone = i
                    end
                end
            end

            if bone then
                local bpos, bang = ent:GetBonePosition(bone)
                if bpos and bang then
                    lpos, lrot = WorldToLocal(pos, dir:Angle(), bpos, bang)
                else
                    lpos, lrot = WorldToLocal(pos, dir:Angle(), ent:GetPos(), ent:GetAngles())
                    bone = nil
                end
            else
                lpos, lrot = WorldToLocal(pos, dir:Angle(), ent:GetPos(), ent:GetAngles())
            end
        end

        local gravity_f1 = Vector(0, 0, -500)
        local gravity_f2 = Vector(0, 0, -600)

        timer_Create(timerid, 0.05, 0, function()
            if CurTime() > endtime || (lpos && !IsValid(ent)) then
                timer_Remove(timerid)
                return
            end

            local curpos = pos
            local curdir = dir

            if IsValid(ent) then
                local bpos, bang
                if bone then
                    bpos, bang = ent:GetBonePosition(bone)
                end
                if !bpos or !bang then
                    bpos, bang = ent:GetPos(), ent:GetAngles()
                end
                local wpos, wang = LocalToWorld(lpos, lrot, bpos, bang)
                curpos = wpos
                curdir = wang:Forward()
            end
            
            local emitter = ParticleEmitter(curpos)
            if !emitter then return end

            local part = emitter:Add(drop_strings[math_random(1,11)], curpos + curdir * 1.5)
            if part then
                local speed = power * 2 + math_Rand(10,300)
                local spread = 0.035 + (power / 1000)
                local vel = curdir * speed + VectorRand() * (speed * spread)

                part:SetVelocity(vel)
                part:SetDieTime(2)
                part:SetStartAlpha(255)
                part:SetEndAlpha(0)
                part:SetStartSize(math_Clamp(2 + (power / 10), 3, 5))
                part:SetGravity(gravity_f1)
                part:SetAirResistance(5)
                part:SetCollide(true)
                part:SetRoll(math_Rand(0, 360))

                local decalsize = math_Clamp(power / math_random(10,20), 3, 5)
                part:SetCollideCallback(function(p, hitpos, hitnormal)
                    sound_Play(blood_drop_local[math_random(1, #blood_drop_local)], hitpos, 55, 100,1)
                    if can_place_decal(hitpos) then
                        util_DecalEx(drop_mats[math_random(1,11)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_white, decalsize, decalsize)
                    end
                    p:SetDieTime(0)
                end)
            end
       
            local part = emitter:Add(drop_strings[math_random(1,11)], curpos)
            if part then
                local speed = math_random(20, 50)
                local vel = -curdir * speed + VectorRand() * (speed * 0.2)

                part:SetVelocity(vel)
                part:SetDieTime(2)
                part:SetStartAlpha(200)
                part:SetEndAlpha(0)
                part:SetStartSize(math_Rand(2, 3))
                part:SetEndSize(0)
                part:SetGravity(gravity_f2)
                part:SetAirResistance(30)
                part:SetCollide(true)
                part:SetColor(60, 0, 0)
                local decalsize = math_Clamp(power / math_random(10,20), 2, 4)
                part:SetCollideCallback(function(p, hitpos, hitnormal)
                    sound_Play(blood_drop_local[math_random(1, #blood_drop_local)], hitpos, 55, 100,1)
                    if can_place_decal(hitpos) then
                        util_DecalEx(drop_mats[math_random(1,11)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_white, decalsize, decalsize)
                    end
                    p:SetDieTime(0)
                end)
            end

            emitter:Finish()
        end)
    end)

    net.Receive("fountainbloodoutcome2", function()
        if !paranoidABC415.clblood:GetBool() then return end
        local ent = net.ReadEntity()
        local pos = net.ReadVector()
        local dir = net.ReadVector()
        local power = net.ReadFloat()
        local duration = net.ReadFloat()

        if !dir || dir == vec_zero then dir = Vector(0, 0, -1) end
        
        local endtime = CurTime() + (duration || 2)
        local timerid = "blood_fountain_" .. tostring(pos.x) .. "_" .. tostring(pos.y) .. "_" .. tostring(CurTime())
        
        local bone = nil
        local lpos = nil
        local lrot = nil

        if IsValid(ent) then
            local closestDist = 999999
            for i = 0, ent:GetBoneCount() - 1 do
                local bpos = ent:GetBonePosition(i)
                if bpos then
                    local dist = bpos:DistToSqr(pos)
                    if dist < closestDist then
                        closestDist = dist
                        bone = i
                    end
                end
            end

            if bone then
                local bpos, bang = ent:GetBonePosition(bone)
                if bpos and bang then
                    lpos, lrot = WorldToLocal(pos, dir:Angle(), bpos, bang)
                else
                    lpos, lrot = WorldToLocal(pos, dir:Angle(), ent:GetPos(), ent:GetAngles())
                    bone = nil
                end
            else
                lpos, lrot = WorldToLocal(pos, dir:Angle(), ent:GetPos(), ent:GetAngles())
            end
        end

        local gravity_f1 = Vector(0, 0, -500)
        local gravity_f2 = Vector(0, 0, -600)
        local gravity_mist = Vector(0, 0, -35)
        local emitter = ParticleEmitter(pos)
        if !emitter then return end
        for i = 1, math_random(15, 20) do
            local part = emitter:Add(smoke_strings[math_random(1, 9)], pos)
            if part then
                part:SetVelocity(VectorRand() * 3 + Vector(0,0,math_Rand(-5,15)))
                part:SetDieTime(10)
                part:SetStartAlpha(90)
                part:SetEndAlpha(35)
                part:SetColor(50,0,0)
                part:SetStartSize(math_Rand(5,15))
                part:SetGravity(gravity_mist)
                part:SetAirResistance(10)
                part:SetCollide(true)
                part:SetRoll(math_Rand(0, 360))
                part:SetRollDelta(math_Rand(-1, 1))
                part:SetAirResistance(50)
                local decalSize = math_Rand(1,1)
                part:SetCollideCallback( function( p, hitpos, hitnormal )
                    if can_place_decal(hitpos) then
                        util_DecalEx(blood_mats[math_random(1,8)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_blood, decalSize / 4, decalSize / 4)
                    end
                    p:SetDieTime( 0 )
                    sound_Play(blood_drop_local[math_random(1, #blood_drop_local)], hitpos, 55, 100,1)
                end)
            end
        end

        timer_Create(timerid, 0.02, 0, function()
            if CurTime() > endtime || (lpos && !IsValid(ent)) then
                timer_Remove(timerid)
                return
            end

            local curpos = pos
            local curdir = dir

            if IsValid(ent) then
                local bpos, bang
                if bone then
                    bpos, bang = ent:GetBonePosition(bone)
                end
                if !bpos or !bang then
                    bpos, bang = ent:GetPos(), ent:GetAngles()
                end
                local wpos, wang = LocalToWorld(lpos, lrot, bpos, bang)
                curpos = wpos
                curdir = wang:Forward()
            end
            
            local emitter = ParticleEmitter(curpos)
            if !emitter then return end

            local part = emitter:Add(drop_strings[math_random(1,11)], curpos + curdir * 1.5)
            if part then
                local speed = power * 2 + math_Rand(10,300)
                local spread = 0.035 + (power / 1000)
                local vel = curdir * speed + VectorRand() * (speed * spread)

                part:SetVelocity(vel)
                part:SetDieTime(2)
                part:SetStartAlpha(255)
                part:SetEndAlpha(0)
                part:SetStartSize(math_Clamp(2 + (power / 10), 3, 5))
                part:SetGravity(gravity_f1)
                part:SetAirResistance(5)
                part:SetCollide(true)
                part:SetRoll(math_Rand(0, 360))

                local decalsize = math_Clamp(power / math_random(10,20), 3, 5)
                part:SetCollideCallback(function(p, hitpos, hitnormal)
                    sound_Play(blood_drop_local[math_random(1, #blood_drop_local)], hitpos, 55, 100,1)
                    if can_place_decal(hitpos) then
                        util_DecalEx(drop_mats[math_random(1,11)], game_GetWorld(), hitpos + hitnormal, VectorRand() * 360, col_white, decalsize, decalsize)
                    end
                    p:SetDieTime(0)
                end)
            end
        end)
    end)
end

end

initshit()


if SERVER then return end
//somethign
