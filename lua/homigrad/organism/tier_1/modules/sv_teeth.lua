if SERVER then
    hg = hg or {}
    hg.organism = hg.organism or {}
    hg.organism.module = hg.organism.module or {}

    hg.organism.module.teeth = {}
    local module = hg.organism.module.teeth

    -- init: create 32 teeth, track broken count and pain timer
    module[1] = function(org)
        org.teeth_state = {}
        for i = 1, 32 do
            org.teeth_state[i] = 0 -- 0 intact, 1 broken
        end
        org.teeth_broken = 0
        org.nextTeethPain = nil
    end

    -- tick: periodic pain based on broken teeth
    module[2] = function(owner, org, timeValue)
        -- no teeth pain when dead
        if not org.alive or (owner:IsPlayer() and not owner:Alive()) then
            org.nextTeethPain = nil
            return
        end

        local broken = org.teeth_broken or 0
        -- stop pulses after heal
        if broken <= 0 then
            org.nextTeethPain = nil
            return
        end

        if broken > 0 then
            if not org.nextTeethPain or org.nextTeethPain <= CurTime() then
                -- random 2-5s pulse
                org.nextTeethPain = CurTime() + math.Rand(2, 5)
                org.painadd = org.painadd + (2 * broken)
            end
        end
    end

    -- called when jaw takes damage; breaks one tooth and adds slight bleeding
    function hg.organism.TeethOnJawDamage(org, delta, dmgInfo, boneindex)
        if (delta or 0) <= 0 then return end

        -- find first intact tooth and break it
        local brokeIndex
        org.teeth_state = org.teeth_state or {}
        for i = 1, 32 do
            if (org.teeth_state[i] or 0) < 1 then
                org.teeth_state[i] = 1
                org.teeth_broken = (org.teeth_broken or 0) + 1
                brokeIndex = i
                break
            end
        end
        if not brokeIndex then return end -- all teeth already broken

        -- add very slight bleeding wound at jaw/head
        local owner = org.owner
        if not IsValid(owner) then return end
        local ent = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
        local physBone = boneindex
        local bone
        -- guard physBone type
        if type(physBone) == "number" then
            bone = ent:TranslatePhysBoneToBone(physBone)
        elseif type(physBone) == "string" then
            bone = ent:LookupBone(physBone)
        end
        bone = bone or ent:LookupBone("ValveBiped.Bip01_Head1") or 0

        -- tiny wound; will coagulate over time via blood module
        -- skip bleeding if dead
        if not org.alive or (owner:IsPlayer() and not owner:Alive()) then return end
        hg.organism.AddWoundManual(owner, 0.02, Vector(0,0,0), Angle(0,0,0), bone, CurTime())
    end
end
