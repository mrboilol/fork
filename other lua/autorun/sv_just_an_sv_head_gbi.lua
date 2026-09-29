local tbl = {
    { mdl = "models/headpartial/headpartial.mdl",  pos = Vector(2.5, 2.5, 0), ang = Angle(0, 80, 90) },
    { mdl = "models/headpartial/headpartial1.mdl", pos = Vector(2.5, 2.5, 0), ang = Angle(0, 80, 90) },
    { mdl = "models/headpartial/headpartial2.mdl", pos = Vector(2.5, 2.5, 0), ang = Angle(0, 80, 90) },
    { mdl = "models/headpartial/headpartial4.mdl", pos = Vector(2.5, 2.5, 0), ang = Angle(0, 80, 90) },
    --{ mdl = "models/headpartial/headpartial5.mdl", pos = Vector(4.9, 2.5, 0), ang = Angle(0, 85, 90) } //no no cause female models differ too much from male
}

local tbl2 = {
    "models/gore/head_eye01.mdl",
    "models/gore/head_eye02.mdl",
    "models/gore/head_headbitbackleft.mdl",
    "models/gore/head_headbitbackright.mdl",
    "models/gore/head_headbitfrontleft.mdl",
    "models/gore/head_headbitfrontright.mdl",
    "models/gore/head_headbittopleft.mdl",
    "models/gore/head_headbittopright.mdl",
    "models/gore/debris_goredebris02.mdl",
    "models/gore/debris_goredebris01.mdl",
    "models/gore/debris_goredebris03.mdl",
    "models/gore/debris_goredebris04.mdl",
        "models/gore/debris_goredebris02.mdl",
    "models/gore/debris_goredebris01.mdl",
    "models/gore/debris_goredebris03.mdl",
    "models/gore/debris_goredebris04.mdl"
}

local veczero = Vector(0,0,0)

if SERVER then
    local function RemoveHeadAccessories(rag) //messy
        if !IsValid(rag) then return end
        
        local children = rag:GetChildren()
        local atts = rag:GetAttachments()

        for i = 1, #children do
            local child = children[i]
            if IsValid(child) then
                local shouldRemove = false

                local attID = child:GetParentAttachment()
                if attID && attID > 0 && atts then
                    local attData = atts[attID]
                    local attName = attData && attData.name
                    if attName then
                        attName = string.lower(attName)
                        if attName == "eyes" || attName == "forward" || attName == "head" || attName == "mouth" || string.find(attName, "eye") || string.find(attName, "head") then
                            shouldRemove = true
                        end
                    end
                end

                if !shouldRemove then
                    local hasHead = child:LookupBone("ValveBiped.Bip01_Head1") || child:LookupBone("ValveBiped.Bip01_Head")
                    local hasPelvis = child:LookupBone("ValveBiped.Bip01_Pelvis")
                    local hasSpine = child:LookupBone("ValveBiped.Bip01_Spine") || child:LookupBone("ValveBiped.Bip01_Spine2")
                    if hasHead && !hasPelvis && !hasSpine then
                        shouldRemove = true
                    end
                end

                if !shouldRemove then
                    local mdl = child:GetModel()
                    if mdl then
                        mdl = string.lower(mdl)
                        if string.find(mdl, "glass") || string.find(mdl, "goggle") || string.find(mdl, "mask") || string.find(mdl, "hat") || string.find(mdl, "cap") || string.find(mdl, "helmet") || string.find(mdl, "hair") || string.find(mdl, "head") || string.find(mdl, "visor") || string.find(mdl, "ear") then
                            if !string.find(mdl, "playermodel") && !string.find(mdl, "player/") then
                                shouldRemove = true
                            end
                        end
                    end
                end

                if shouldRemove then
                    child:Remove()
                end
            end
        end
    end
    util.AddNetworkString("gibmaheadbru")

    local IsValid = IsValid
    local math_Clamp = math.Clamp
    local math_random = math.random
    local net_Start = net.Start
    local net_WriteEntity = net.WriteEntity
    local net_WriteVector = net.WriteVector
    local net_WriteFloat = net.WriteFloat
    local net_Broadcast = net.Broadcast


    
    hook.Add("EntityTakeDamage", "mgmmgmgmmgmmgmmgmmmgmmmggmggmmgmgmgmg12432gGG", function(ent, dmginfo)
        if !paranoidABC415.svheadgibbing:GetBool() then return end
        if !(dmginfo:IsDamageType(DMG_BULLET) || dmginfo:IsDamageType(DMG_BUCKSHOT) || dmginfo:IsDamageType(DMG_CLUB)) then return end
        if IsValid(ent) && ent:GetClass() == "prop_ragdoll" then
            if ent:GetNW2Bool("gibhead22", false) then
                local inx = ent:LookupBone("ValveBiped.Bip01_Head1")
                if inx then
                    local pos = ent:GetBonePosition(inx)
                    if pos && pos:DistToSqr(dmginfo:GetDamagePosition()) <= 44 then
                        dmginfo:SetDamage(0)
                        return true
                    end
                end
                return
            end

            if !ent.headhp then ent.headhp = 150 end
            local inx = ent:LookupBone("ValveBiped.Bip01_Head1")
            if not inx then return end

            local pos = ent:GetBonePosition(inx)
            local dpos = dmginfo:GetDamagePosition()

            if dpos == veczero then return end

            if pos:DistToSqr(dpos) <= 42 then
                if ent.headhp <= -1 then return end
                local damage = dmginfo:GetDamage()
                ent.headhp = math_Clamp(ent.headhp - damage,-1,100)
                //print(ent.headhp)
                
                if ent.headhp <= 0 then
                    //print("boom")
                    ent.headhp = -1
                    dmginfo:ScaleDamage(100)
                    
                    local rndIdx = math_random(1, #tbl)
                    RemoveHeadAccessories(ent) 
                    ent:SetNW2Int("goremidx", rndIdx)
                    ent:SetNW2Bool("gibhead22", true)
                    sound.Play("headsmash.mp3",pos + Vector(0,0,5),80,math_random(90,105))
                    sound.Play("flesh-impact.mp3",pos + Vector(0,0,5),80,math_random(90,105))
                    local physidx = ent:TranslateBoneToPhysBone(inx)
                    if physidx && physidx != -1 then
                        local phys_obj = ent:GetPhysicsObjectNum(physidx)
                        //ent:RemoveInternalConstraint(phys_bone) 
                        ent:ManipulateBoneScale(inx, veczero)
                        if IsValid(phys_obj) then //shitty
                            phys_obj:EnableCollisions(false)
                            phys_obj:SetMass(0.1) 
                            //phys_obj:SetVelocity(veczero)
                            constraint.RemoveAll(phys_obj)
                        end
                    end


                    if paranoidABC415.svblood:GetBool() then
                        local sidx = ent:LookupBone("ValveBiped.Bip01_Spine4")
                        if sidx then
                            local spos, sang = ent:GetBonePosition(sidx)
                            if spos && sang then
                                local cData = tbl[rndIdx] or tbl[1]

                                local kirky, ang1 = LocalToWorld(cData.pos, cData.ang, spos, sang)

                                local dir = ang1:Up()
                                
                                net_Start("fountainbloodoutcome2")
                                    net_WriteEntity(ent)
                                    net_WriteVector(kirky)
                                    net_WriteVector(dir)
                                    net_WriteFloat(2.0)
                                    net_WriteFloat(15)
                                net_Broadcast()
                            end
                        end
                    end
                    
                    net_Start("gibmaheadbru")
                        net_WriteVector(pos)
                        net_WriteVector(dmginfo:GetDamageForce())
                    net_Broadcast()
                end
            end
        end
    end)
end

if CLIENT then
    local IsValid = IsValid
    local LocalToWorld = LocalToWorld
    local pairs = pairs
    local ClientsideModel = ClientsideModel
    local VectorRand = VectorRand
    local AngleRand = AngleRand
    local table_insert = table.insert
    local table_remove = table.remove
    local math_min = math.min
    local math_random = math.random

    local que = {}

    net.Receive("gibmaheadbru", function()
        local pos = net.ReadVector()
        local force = net.ReadVector()

        for i = 1, 6 do
            table_insert(que, {
                pos = pos,
                force = force,
                model = tbl2[math_random(1, #tbl2)]
            })
        end
    end)

    hook.Add("Think", "thinkthequepro", function()
        local count = #que
        if count == 0 then return end

        for i = 1, 20 do
            local task = table_remove(que, 1)
            if !task then break end

            local gib = ClientsideModel(task.model, RENDERGROUP_OPAQUE)
            if IsValid(gib) then
                gib:SetPos(task.pos + VectorRand(-3, 3))
                gib:SetAngles(AngleRand(-180, 180))

                gib:PhysicsInit(SOLID_VPHYSICS)
                gib:SetMoveType(MOVETYPE_VPHYSICS)
                gib:SetSolid(SOLID_VPHYSICS)
                gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

                local phys = gib:GetPhysicsObject()
                if IsValid(phys) then
                    phys:Wake()
                    phys:SetVelocity((task.force * 0.03) + VectorRand(-15, 15) + Vector(0, 0, 30))
                    phys:AddAngleVelocity(VectorRand(-400, 400))
                end
                SafeRemoveEntityDelayed(gib, 20)
            end
        end
    end)
    
    local function getitornot(rag)
        rag.bonemodels = rag.bonemodels or {}
        
        if !IsValid(rag.bonemodels["gorehead"]) then
            local mdlidx = rag:GetNW2Int("goremidx", 1)
            local modelData = tbl[mdlidx] or tbl[1]
            
            local model = ClientsideModel(modelData.mdl, RENDERGROUP_OPAQUE)
            if IsValid(model) then 
                model:SetNoDraw(true)
                rag.bonemodels["gorehead"] = model
            end
        end
        return rag.bonemodels["gorehead"]
    end

    local function indexbone(rag, bame)
        if !rag._boneCache then rag._boneCache = {} end
        if rag._boneCache[bame] == nil then
            rag._boneCache[bame] = rag:LookupBone(bame) or false
        end
        return rag._boneCache[bame]
    end

    local function drawbonevisual(rag, b)
        if !rag:GetNW2Bool("gibhead22", false) then return end

        local idx = indexbone(rag, "ValveBiped.Bip01_Head1")
        if idx then 
            rag:ManipulateBoneScale(idx, veczero) 
        end

        local ent = getitornot(rag)
        if !IsValid(ent) then return end

        local p, a = rag:GetBonePosition(b)
        if !p || !a then return end

        local mdlidx = rag:GetNW2Int("goremidx", 1)
        local cData = tbl[mdlidx] or tbl[1]

        local wpos, wang = LocalToWorld(cData.pos, cData.ang, p, a)
        ent:SetPos(wpos)
        ent:SetAngles(wang)
        ent:SetupBones()

        ent:FrameAdvance()
        
        render.SetLightingOrigin(wpos)
        render.ResetModelLighting(1, 1, 1)
        render.SetModelLighting(BOX_TOP, 1, 1, 1)

        ent:DrawModel()
    end

    local maxxs = 4000 * 4000 

    hook.Add("PostDrawOpaqueRenderables", "russianspyware2", function()
        local rorigin = EyePos()
        local ragdolls = ents.FindByClass("prop_ragdoll")

        for i = 1, #ragdolls do
            local rag = ragdolls[i]
            if !IsValid(rag) || rag:IsDormant() then continue end
            
            if rag:GetPos():DistToSqr(rorigin) > maxxs then continue end

            local b = indexbone(rag, "ValveBiped.Bip01_Spine4")
            if !b then continue end

            drawbonevisual(rag, b)
        end
    end)

    hook.Add("EntityRemoved", "russianspywareclean2", function(ent)
        if ent:GetClass() == "prop_ragdoll" && ent.bonemodels then
            for _, mdl in pairs(ent.bonemodels) do
                if IsValid(mdl) then mdl:Remove() end
            end
        end
    end)
end