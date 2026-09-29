//every dev looking at another dev's code will call the last one stupid..
//but then, who's really smart?
//moral of the story: go fuck yourself, GET OUT

//TODO:
// move eye popping lua from eye_pop/ to this addon folder //done
// add random sCArY(!) jumpscare //done e

local limbs = {
    {net = "FractureLArm", bone = "ValveBiped.Bip01_L_Forearm", mdl = "models/bbuster/l_arm_lower/l_arm_lower.mdl", pos = Vector(-30, -2, -41), ang = Angle(0, -90, -20)},
    {net = "FractureLLeg", bone = "ValveBiped.Bip01_L_Calf", mdl = "models/bbuster/l_leg_lower/l_leg_lower.mdl", pos = Vector(-3, -2, 1.5), ang = Angle(90, 5, 20)},
    {net = "FractureRArm", bone = "ValveBiped.Bip01_R_Forearm", mdl = "models/bbuster/r_arm_lower/r_arm_lower.mdl", pos = Vector(18, -2, -52), ang = Angle(0, -90, -10)},
    {net = "FractureRLeg", bone = "ValveBiped.Bip01_R_Calf", mdl = "models/bbuster/r_leg_lower/r_leg_lower.mdl", pos = Vector(-2, 2, 2), ang = Angle(40, 80, 75)},
    {net = "BrokenSpiinne", bone = "ValveBiped.Bip01_Spine4", mdl = "models/Gibs/HGIBS_spine.mdl", pos = Vector(-4, -1, 0), ang = Angle(95, 125, 95), pizdec = true, add = 250, sqr = 1000, chance = 14, scale = 0.9},
    {net = "BrokenRIB1", bone = "ValveBiped.Bip01_Spine4", mdl = "models/Gibs/HGIBS_rib.mdl", pos = Vector(-4, 7, -2), ang = Angle(120, 10, 5), pizdec = true, add = 50, scale = 0.5, sqr = 1000, chance = 28},
    {net = "BrokenRIB2", bone = "ValveBiped.Bip01_Spine4", mdl = "models/Gibs/HGIBS_rib.mdl", pos = Vector(-6, 7.2, -1), ang = Angle(100, 20, 10), pizdec = true, add = 50, scale = 0.5, sqr = 1000, chance = 27},
    {net = "BrokenRIB3", bone = "ValveBiped.Bip01_Spine4", mdl = "models/Gibs/HGIBS_rib.mdl", pos = Vector(-3, 6.4, -1.5), ang = Angle(75, 30, 20), pizdec = true, add = 50, scale = 0.5, sqr = 1000, chance = 26},
    {net = "BrokenRIB4", bone = "ValveBiped.Bip01_Spine4", mdl = "models/Gibs/HGIBS_rib.mdl", pos = Vector(-4, 6, 3), ang = Angle(-140, 95, 95), pizdec = true, add = 50, scale = 0.5, sqr = 1000, chance = 27},
    {net = "BrokenRIB5", bone = "ValveBiped.Bip01_Spine4", mdl = "models/Gibs/HGIBS_rib.mdl", pos = Vector(-8, 6.5, 2.5), ang = Angle(-135, 90, 65), pizdec = true, add = 50, scale = 0.5, sqr = 1000, chance = 25},
    {net = "NECKOUCHH", bone = "ValveBiped.Bip01_Head1", mdl = "models/Gibs/HGIBS_rib.mdl", pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), add = 30, scale = 0, sqr = 1200, chance = 20, dneedsc = true}, //its AWFULLY BROKEN!!
                                                             
}//https://youtu.be/UONcm3HWSTY 🔥🔥 //like and subscribe //now.
local angle_zero = Angle(0,0,0)
// the horrific tests.. https://i.imgur.com/whQ6IXz.jpeg
if SERVER then
    hook.Add("EntityTakeDamage", "TIKTONAHUIIDINAHUIOTSUDA", function(ent, dmginfo)
        if !paranoidABC415.svbones:GetBool() then return end
        if !IsValid(ent) || ent:GetClass() ~= "prop_ragdoll" then return end
        if !(dmginfo:IsDamageType(DMG_FALL) || dmginfo:IsDamageType(DMG_CRUSH)) then return end
        if dmginfo:GetDamage() <= 23 then return end

        local forcepos = dmginfo:GetDamagePosition()

        for _, l in ipairs(limbs) do
            if ent:GetNW2Bool(l.net, false) then continue end

            local b = ent:LookupBone(l.bone)
            if !b then continue end

            local bpos = ent:GetBonePosition(b)
            if !bpos then continue end

            local hitpos = forcepos
            local physbone = ent:TranslateBoneToPhysBone(b)
            local phys = ent:GetPhysicsObjectNum(physbone || 0)
            if IsValid(phys) then
                local velocity = phys:GetVelocity():LengthSqr()
                if velocity < 250000 then continue end 
                bpos = phys:GetPos()
            end

            if hitpos:DistToSqr(bpos) > (l.sqr or 1400) then continue end
            if !(math.random(1,l.chance or 11) == 1) then continue end
            ent:SetNW2Bool(l.net, true)
            ent:EmitSound("bbuster/break/break"..math.random(1,6)..".wav", 70, math.random(95,105))
            dmginfo:ScaleDamage(1.3)
            if IsValid(phys) && !l.pizdec then
                ent:RemoveInternalConstraint(physbone)
                for i = 0, ent:GetPhysicsObjectCount() - 1 do
                    constraint.NoCollide(ent, ent, physbone, i)
                end
                local p = ent:GetBoneParent(b)
                local pp = ent:TranslateBoneToPhysBone(p)
                //constraint.Rope(ent, ent, physbone, pp, Vector(1, 0, 0), Vector(15, 0, 0), 0.1, 0, 0, 0, "", false)
                local paphys = ent:GetPhysicsObjectNum(pp or 0)

                if IsValid(paphys) then
                    local bonepos = phys:GetPos()
                    local lpos2 = paphys:WorldToLocal(bonepos)
                    /*if l.dneedsc then
                        lpos2 = paphys:WorldToLocal(bonepos)
                    else
                        local correce = bonepos + (paphys:GetVelocity() * engine.TickInterval() / 2) //REALLY risky
                        lpos2 = paphys:WorldToLocal(correce)
                    end*/

                    constraint.AdvBallsocket(ent, ent, physbone, pp, Vector(0, 0, 0), lpos2, 0, 0, -100, -100, -120, 10, 10, 10, 0, 0, 0, 0, 0, 0)
                end

            end


            net.Start("blyadinagoviadina")
                net.WriteVector(phys:GetPos()) //yea fuck those pussy liberal 'isvalid' checks! what will you say about this, LEFTISTS?             (jk)
                net.WriteVector(-dmginfo:GetDamageForce():GetNormalized())
                net.WriteFloat(30 + (l.add or 0))
            net.Broadcast() 
            break
        end
    end)
end

if CLIENT then
    local IsValid = IsValid
    local LocalToWorld = LocalToWorld
    local pairs = pairs
    local ipairs = ipairs

    local function getitornot(rag, l)
        rag.bonemodels = rag.bonemodels or {}
        
        if !IsValid(rag.bonemodels[l.net]) then
            local model = ClientsideModel(l.mdl, RENDERGROUP_OPAQUE)
            if IsValid(model) then 
                model:SetNoDraw(true)
                rag.bonemodels[l.net] = model
            end
        end
        return rag.bonemodels[l.net]
    end

    local bache = {}
    local function indexbone(rag, bame)
        local mdl = rag:GetModel()
        if !mdl then return end
        
        bache[mdl] = bache[mdl] or {}
        if bache[mdl][bame] == nil then
            bache[mdl][bame] = rag:LookupBone(bame) or false
        end
        return bache[mdl][bame]
    end

    local function drawbonevisual(rag, b, l)
        if !rag:GetNW2Bool(l.net, false) then return end

        local ent = getitornot(rag, l)
        if !IsValid(ent) then return end

        local p, a = rag:GetBonePosition(b)
        if !p or !a then return end

        local wpos, wang = LocalToWorld(l.pos, l.ang, p, a)
        ent:SetPos(wpos)
        ent:SetAngles(wang)
        ent:SetupBones()
        
        render.SetLightingOrigin(wpos)
        render.ResetModelLighting(1, 1, 1)
        render.SetModelLighting(BOX_TOP, 1, 1, 1)

        ent:SetModelScale(l.scale or 1)
        ent:DrawModel()
    end

    local maxxs = 1500 * 1500 

    hook.Add("PostDrawOpaqueRenderables", "russianspyware", function()
        local rorigin = EyePos()
        local ragdolls = ents.FindByClass("prop_ragdoll")

        for i = 1, #ragdolls do
            local rag = ragdolls[i]
            if !IsValid(rag) or rag:IsDormant() then continue end
            
            if rag:GetPos():DistToSqr(rorigin) > maxxs then continue end

            for j = 1, #limbs do
                local l = limbs[j]
                local b = indexbone(rag, l.bone)
                if !b then continue end

                drawbonevisual(rag, b, l)
            end
        end
    end)

    hook.Add("EntityRemoved", "russianspywareclean", function(ent)
        if ent:GetClass() == "prop_ragdoll" and ent.bonemodels then
            for _, mdl in pairs(ent.bonemodels) do
                if IsValid(mdl) then mdl:Remove() end
            end
        end
    end)

    RunConsoleCommand("violence_hblood", "0")
end
