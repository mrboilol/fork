//leaking qiwi hmcd's server side..
//this is REALLY laggy because of particles and blood, but i cant really do much about it without fully rewriting cl code.. maybe later in future updates :/
//for now you can just turn off mgm_cl_blood

if !SERVER then return end

local entm = FindMetaTable("Entity")

local gibs = {
    //"models/gore/gorehead.mdl",
    "models/gore/head_eye01.mdl", "models/gore/head_eye02.mdl", "models/gore/head_headbitbackright.mdl", "models/gore/head_headbitfrontright.mdl", "models/gore/head_headbitfrontleft.mdl", "models/gore/head_headbitbackleft.mdl", "models/gore/head_headbittopright.mdl",
 
    "models/gore/uppertorso.mdl",
    "models/gore/uppertorso_boneslowerleft.mdl",
    "models/gore/rleg_meatbit004r.mdl",
    "models/gore/rleg_meatbit003r.mdl",
    "models/gore/rleg_meatbit002r.mdl",
    "models/gore/rleg_meatbit001r.mdl",
    "models/gore/rleg_legpartfootr001.mdl",
    "models/gore/pelvis.mdl",
    "models/gore/lleg_meatbit001l.mdl",
    "models/gore/lleg_legpartmidl.mdl",
    "models/gore/lleg_legpartfootl002.mdl",
    "models/gore/larm_armgoreupperl.mdl",
    "models/gore/larm_armgorehandl.mdl",
    "models/gore/rarm_armgorehandr.mdl",
    "models/gore/larm_armgorelowerl.mdl",
    "models/gore/rarm_armgoreupperr.mdl",
    "models/gore/rleg_legpartfootr002.mdl",
    "models/gore/rleg_meatbit001r.mdl",
}

local debrisgibs = {
    "models/gore/debris_goredebris01.mdl",
    "models/gore/debris_goredebris02.mdl",
    "models/gore/debris_goredebris03.mdl",
    "models/gore/debris_goredebris04.mdl",
    "models/gore/debris_goredebris01.mdl",
    "models/gore/debris_goredebris02.mdl",
    "models/gore/debris_goredebris03.mdl",
    "models/gore/debris_goredebris04.mdl",
    "models/gore/debris_goredebris01.mdl",
    "models/gore/debris_goredebris02.mdl",
    "models/gore/debris_goredebris03.mdl",
    "models/gore/debris_goredebris04.mdl",
    "models/gore/debris_goredebris01.mdl",
    "models/gore/debris_goredebris02.mdl",
    "models/gore/debris_goredebris03.mdl",
    "models/gore/debris_goredebris04.mdl"    
}

for _, model in ipairs(gibs) do util.PrecacheModel(model) end
for _, model in ipairs(debrisgibs) do util.PrecacheModel(model) end

local IsValid = IsValid
local ents_Create = ents.Create
local VectorRand = VectorRand
local AngleRand = AngleRand             //IM TIRED OF DOING THIS EACH TIME!! //i just realized i could shove it all in one sh_globsetgsns.lua but now its too late, womp womp :p
local table_insert = table.insert
local table_remove = table.remove
local math_min = math.min
local net_Start = net.Start
local net_WriteVector = net.WriteVector
local net_WriteFloat = net.WriteFloat
local net_Broadcast = net.Broadcast
local SafeRemove = SafeRemoveEntityDelayed

local vec_up = Vector(0, 0, 1)
local vec_up20 = Vector(0, 0, 20)
local vec_up40 = Vector(0, 0, 40)

local gibque = {}

local function Gollision(ent, data)
    if data.Speed > 150 then
        local hitpos = data.HitPos
        net_Start("blyadinagoviadina")
            net_WriteVector(hitpos)
            net_WriteVector(VectorRand() * 1)
            net_WriteFloat(6)
        net_Broadcast()
    end
end

hook.Add("Think", "Godzilla took a bite out of Optimus Prime Like Scruff McGruff took a bite out of crime And then Shaq came back covered in a tire track But Jackie Chan jumped out and landed on his back And Batman was injured and trying to get steady When Abraham Lincoln came back with a machete But suddenly something caught his leg and he tripped Indiana Jones took him out with his whip Then he saw Godzilla sneaking up from behind And he reached for his gun which he just couldn't find 'Cause Batman stole it and he shot and he missed And Jackie Chan deflected it with his fist Then he jumped in the air and he did a somersault While Abraham Lincoln tried to pole vault Onto Optimus Prime but they collided in the air Then they both got hit by a Care Bear stare", function()
    local count = #gibque
    if count == 0 then return end

    local limit = math_min(count, 3)
    for i = 1, limit do
        local task = table_remove(gibque, 1)
        if !task then break end

        if task.type == 1 then
            local gib = ents_Create("prop_physics")
            if IsValid(gib) then
                gib:SetModel(task.model)
                gib:SetPos(task.pos + VectorRand(-2, 2))
                gib:SetAngles(AngleRand())
                gib:Spawn()
                gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

                local phys = gib:GetPhysicsObject()
                if IsValid(phys) then
                    phys:SetVelocity(task.vel + vec_up)
                    phys:AddAngleVelocity(VectorRand(-20, 20))
                end
                gib:AddCallback("PhysicsCollide", Gollision)
                SafeRemove(gib, 45)
            end
        elseif task.type == 2 then
            local debris = ents_Create("prop_physics")
            if IsValid(debris) then
                debris:SetModel(task.model)
                debris:SetPos(task.pos + VectorRand(-20, 20))
                debris:SetAngles(AngleRand())
                debris:Spawn()
                debris:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

                local phys = debris:GetPhysicsObject()
                if IsValid(phys) then
                    phys:SetVelocity(task.vel * 1.2 + VectorRand(-100, 100))
                end
                SafeRemove(debris, 15)
            end
        end
    end
end)

local function SpawnGibs(pos, vel, dir, bblood)
    dir = dir or ((isvector(vel) && vel:LengthSqr() > 1) && vel:GetNormalized() or VectorRand())

    if bblood then
        //net_Start("blyadinagoviadina2")
        //    net_WriteVector(pos + vec_up20)
        //    net_WriteVector(dir * 5)
        //net_Broadcast()
        net_Start("blyadmist2")
            net_WriteVector(pos)
        net_Broadcast()
    end


    for _, model in ipairs(gibs) do
        table_insert(gibque, {
            type = 1,
            model = model,
            pos = pos,
            vel = vel
        })
    end

    for _, model in ipairs(debrisgibs) do
        table_insert(gibque, {
            type = 2,
            model = model,
            pos = pos,
            vel = vel
        })
    end
end

local tbl11 = {
    "pelvissmash.mp3",
    "headsmash.mp3",
    "limbrip1.mp3"
}

function entm:Razobrat(bool_blood, vec_velocity, vec_dir, posOverride) //lego
    if !paranoidABC415.svgibbing:GetBool() then return end
    if !IsValid(self) || self:GetClass() ~= "prop_ragdoll" then return end
    if self.GIBBING11 then return end
    self.GIBBING11 = true
    local pos = posOverride or (self:GetPos() + vec_up40)
    local phys = self:GetPhysicsObject()
    local vel = vec_velocity or (IsValid(phys) && phys:GetVelocity()) or Vector()

    self:EmitSound("flesh-impact.mp3", 130, math.random(95,105))
    self:EmitSound(tbl11[math.random(1,#tbl11)], 130, math.random(95,105))
    SpawnGibs(pos, vel, vec_dir, bool_blood or false)

    self:Remove()
end

local function FindRagOwner(rag)
    local owner = RagdollOwner(rag)
    if IsValid(owner) && owner:IsPlayer() then return owner end

    owner = rag:GetNWEntity("RagdollController")
    if IsValid(owner) && owner:IsPlayer() then return owner end

    for _, pl in ipairs(player.GetAll()) do
        if pl:GetNWEntity("Ragdoll") == rag then return pl end
    end

    return nil
end

hook.Add("PostEntityTakeDamage", "IMAFUCKINGBRICKCHARACTERSMASHMYHEADWITHASLEDGEHAMMERMARIO", function(ent, dmginfo)
    if !IsValid(ent) || ent:GetClass() ~= "prop_ragdoll" then return end
    if !paranoidABC415.svgibbing:GetBool() then return end
    local dtype = dmginfo:GetDamageType()
    local isExplosion = bit.band(dtype, 64) ~= 0 || bit.band(dtype, 134217728) ~= 0
    if !isExplosion then return end

    local dmg = dmginfo:GetDamage()
    if !(dmg >= 270 or (dmg >= 100 && dmginfo:GetDamagePosition():Distance(ent:GetPos() + vec_up40) <= 100)) then 
        return 
    end

    local attacker = dmginfo:GetAttacker()
    local inflictor = dmginfo:GetInflictor()

    local function CalcDir(fromPos)
        local origin = dmginfo:GetDamagePosition()
        if not origin or origin == vector_origin then
            origin = IsValid(inflictor) and inflictor:GetPos() or (IsValid(attacker) and attacker:GetPos() or fromPos)
        end

        local d = fromPos - origin
        if d:LengthSqr() < 1 then return VectorRand() end
        return d:GetNormalized()
    end

    local force = math.Clamp(dmg, 110, 220)
    local function CalcVel(dir)
        return dir * force
    end

    local ragPos = ent:GetPos() + vec_up40
    local dir = CalcDir(ragPos)
    local vel = CalcVel(dir)

    ent:Razobrat(true, vel, dir, ragPos)

    return true
end)