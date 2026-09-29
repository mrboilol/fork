if SERVER then
    local IsValid = IsValid
    local math_random = math.random
    local string_find = string.find
    local string_lower = string.lower
    local ipairs = ipairs
    local table_insert = table.insert

    local mache = {}

    local function ApplyEyeSubMat(ent, side)
        local mdl = ent:GetModel()
        if !mdl then return end

        if !mache[mdl] then
            mache[mdl] = { r = {}, l = {} }
            local mats = ent:GetMaterials() or {}
            for i, mat in ipairs(mats) do
                local name = string_lower(mat)
                if string_find(name, "eye") || string_find(name, "pupil") then
                    if string_find(name, "%f[%a]r%f[%A]") || string_find(name, "_r") then
                        table_insert(mache[mdl].r, i - 1)
                    end
                    if string_find(name, "%f[%a]l%f[%A]") || string_find(name, "_l") then
                        table_insert(mache[mdl].l, i - 1)
                    end
                end
            end
        end

        local indices = mache[mdl][side]
        if indices then
            for i = 1, #indices do
                ent:SetSubMaterial(indices[i], "models/flesh")
            end
        end
    end

    hook.Add("EntityTakeDamage", "EyesAttachmentReplace", function(ent, dmginfo)
        if !paranoidABC415.sveyes:GetBool() then return end
        if !IsValid(ent) || ent:GetClass() ~= "prop_ragdoll" then return end
        if ent:GetNW2Bool("gibhead22", false) then return end
        if !(dmginfo:IsDamageType(DMG_BULLET) || dmginfo:IsDamageType(DMG_BUCKSHOT)) then return end

        local attId = ent._eyeAttId
        if !attId then
            attId = ent:LookupAttachment("eyes")
            ent._eyeAttId = attId
        end
        if attId == 0 then return end

        local att = ent:GetAttachment(attId)
        if !att then return end

        local hitPos = dmginfo:GetDamagePosition()
        if hitPos:DistToSqr(att.Pos) > 50 then return end
        if !(math_random(1, 2) == 1) then return end

        local side = -(hitPos - att.Pos):Dot(att.Ang:Right()) > 0 and "l" or "r"
        local nwKey = side == "r" and "eyeeeR" or "eyeeeL"

        local stg = ent:GetNWInt(nwKey, 0)
        if stg >= 3 then return end

        if stg == 0 then
            ApplyEyeSubMat(ent, side)
        end

        ent:SetNWInt(nwKey, stg + 1)
    end)
end

if CLIENT then
    local IsValid = IsValid
    local LocalToWorld = LocalToWorld
    local ClientsideModel = ClientsideModel
    local VectorRand = VectorRand
    local math_random = math.random
    local math_min = math.min
    local table_insert = table.insert
    local table_remove = table.remove
    local ents_FindByClass = ents.FindByClass
    local EyePos = EyePos

    local models = {}
    local laststages = {}
    local eyePropQueue = {}

    local maxxxx = 1500 * 1500

    local offset_r = Vector(-4, .25, -2)
    local offset_l = Vector(-4, 0, -2)
    local ang_eye = Angle(10, 0, 0)

    local mdl_eye_r = "models/gore/head_eye01.mdl"
    local mdl_eye_l = "models/gore/head_eye02.mdl"

    util.PrecacheModel(mdl_eye_r)
    util.PrecacheModel(mdl_eye_l)

    local function QueueEyeSpawn(rag, side, mdl)
        if rag:GetNW2Bool("gibhead22", false) then return end

        local attId = rag._eyeAttId or rag:LookupAttachment("eyes")
        rag._eyeAttId = attId
        if attId == 0 then return end

        local att = rag:GetAttachment(attId)
        if !att then return end

        local offset = (side == "r") and offset_r or offset_l
        local wPos, wAng = LocalToWorld(offset, ang_eye, att.Pos, att.Ang)

        table_insert(eyePropQueue, {
            mdl = mdl,
            pos = wPos,
            ang = wAng,
            vel = att.Ang:Forward() * math_random(25, 50) + VectorRand(-5, 5)
        })
    end

    local function glaza(rag, att, mdl, side, offset, angle)
        local nwKey = (side == "r") and "eyeeeR" or "eyeeeL"
        local stg2 = rag:GetNWInt(nwKey, 0)
        if stg2 == 0 || stg2 >= 3 then return end

        if !IsValid(models[mdl]) then
            models[mdl] = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
            if IsValid(models[mdl]) then models[mdl]:SetNoDraw(true) end
        end

        local ent = models[mdl]
        if IsValid(ent) then
            local wPos, wAng = LocalToWorld(offset, angle, att.Pos, att.Ang)
            ent:SetPos(wPos)
            ent:SetAngles(wAng)
            ent:SetupBones()
            ent:DrawModel()
        end
    end

    hook.Add("PostDrawOpaqueRenderables", "j13i4ethqqgihdva", function()
        local eyePos = EyePos()
        local rags = ents_FindByClass("prop_ragdoll")

        for i = 1, #rags do
            local rag = rags[i]
            if !IsValid(rag) || rag:IsDormant() then continue end
            if rag:GetNW2Bool("gibhead22", false) then continue end
            if rag:GetPos():DistToSqr(eyePos) > maxxxx then continue end

            local attId = rag._eyeAttId
            if !attId then
                attId = rag:LookupAttachment("eyes")
                rag._eyeAttId = attId
            end
            if attId == 0 then continue end

            local att = rag:GetAttachment(attId)
            if !att then continue end

            glaza(rag, att, mdl_eye_r, "r", offset_r, ang_eye)
            glaza(rag, att, mdl_eye_l, "l", offset_l, ang_eye)
        end
    end)

    hook.Add("Think", "slomaimneebnalo", function()
        local qCount = #eyePropQueue
        if qCount > 0 then
            local limit = math_min(qCount, 1)
            for i = 1, limit do
                local task = table_remove(eyePropQueue, 1)
                if !task then break end

                local prop = ents.CreateClientProp(task.mdl)
                if IsValid(prop) then
                    prop:SetPos(task.pos)
                    prop:SetAngles(task.ang)
                    prop:Spawn()
                    prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

                    local phys = prop:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:Wake()
                        phys:SetVelocity(task.vel)
                    end
                    SafeRemoveEntityDelayed(prop, 20)
                end
            end
        end

        local rags = ents_FindByClass("prop_ragdoll")
        for i = 1, #rags do
            local rag = rags[i]
            if !IsValid(rag) || rag:IsDormant() then continue end
            
            local id = rag:EntIndex()
            if id == -1 then continue end

            if !laststages[id] then laststages[id] = {r = 0, l = 0} end
            local hasNoHead = rag:GetNW2Bool("gibhead22", false)

            local curR = rag:GetNWInt("eyeeeR", 0)
            if curR >= 3 && laststages[id].r < 3 && laststages[id].r > 0 && !hasNoHead then
                QueueEyeSpawn(rag, "r", mdl_eye_r)
            end
            laststages[id].r = curR

            local curL = rag:GetNWInt("eyeeeL", 0)
            if curL >= 3 && laststages[id].l < 3 && laststages[id].l > 0 && !hasNoHead then
                QueueEyeSpawn(rag, "l", mdl_eye_l)
            end
            laststages[id].l = curL
        end
    end)

    hook.Add("EntityRemoved", "ClearEyesStagesCache", function(ent)
        local id = ent:EntIndex()
        if id != -1 && laststages[id] then
            laststages[id] = nil
        end
    end)
end