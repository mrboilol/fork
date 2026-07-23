if SERVER then
    AddCSLuaFile()
    return
end

local function ApplyDIHHealAnimation()
    local stored = weapons.GetStored("weapon_defibrilator_homigrad")
    if not istable(stored) or stored.__hg_restrained_healanim then return end

    stored.__hg_restrained_healanim = true
    stored.Animation = function(self)
        local owner = self:GetOwner()
        if not IsValid(owner) or not owner.GetAimVector or not self.BoneSet or not self.GetHolding then return end
        if owner.zmanipstart ~= nil and owner.organism and not owner.organism.larmamputated then return end

        local aimvec = owner:GetAimVector()
        local hold = self:GetHolding()
        local ducking = owner:IsFlagSet(FL_ANIMDUCKING)

        self:BoneSet("r_upperarm", vector_origin, Angle(30 - hold / 5, -30 + hold / 2 + 20 * aimvec[3] * (ducking and -3 or -1), 5 - hold / 4))
        self:BoneSet("r_forearm", vector_origin, Angle(hold / 25, -hold / 2.5, 35 - hold / 1.4))
        self:BoneSet("l_upperarm", vector_origin, Angle(0, -10, 0))
        self:BoneSet("l_forearm", vector_origin, Angle(0, 10, 0))
    end
end

local function ScheduleDIHHealAnimation()
    timer.Simple(0, ApplyDIHHealAnimation)
    timer.Simple(1, ApplyDIHHealAnimation)
    timer.Simple(5, ApplyDIHHealAnimation)
end

hook.Add("Initialize", "zcity_delta_dih_healanim", ScheduleDIHHealAnimation)
hook.Add("InitPostEntity", "zcity_delta_dih_healanim_post", ScheduleDIHHealAnimation)
hook.Add("OnReloaded", "zcity_delta_dih_healanim_reload", ScheduleDIHHealAnimation)

timer.Simple(0, ScheduleDIHHealAnimation)
