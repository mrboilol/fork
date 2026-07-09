CreateConVar("hg_altberserk", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enable alternative berserk mode server-wide", 0, 1)
CreateConVar("hg_altberserk3", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Enable alternative berserk mode 3 server-wide", 0, 1)

hook.Add("Player Think", "Berserk", function(ply, time, dtime)
    if !ply:IsBerserk() or ply:GetMoveType() == MOVETYPE_NOCLIP then return end

    local org = ply.organism
    if org then
        -- Berserk immediately restores and maintains the airway.
        org.trachea = 0
        org.tracheaPath = nil
    end

    local velocity = ply:GetVelocity():Length2DSqr()
    if velocity > 100000 then
        local plyPos = ply:GetPos()
        for _, v in ipairs(ents.FindInSphere(plyPos, 64)) do
            if v == ply then continue end
<<<<<<< HEAD
            local isPlayer = v:IsPlayer()
            local Phys = isPlayer and v:GetPhysicsObject() or v:GetPhysicsObjectNum(0)

            if isPlayer then
                v:ViewPunch(Angle(-5,0,0))
            end

            local AimVec = (v:GetPos() - plyPos):GetNormalized()
=======
            local Phys = v:IsPlayer() and v:GetPhysicsObject() or v:GetPhysicsObjectNum(0)
            if v:IsPlayer() then
                v:ViewPunch(Angle(-5,0,0))
            end
            local AimVec = (v:GetPos() - ply:GetPos()):GetNormalized()
>>>>>>> 8e5ef9bd (some changes i already made)
            local force = velocity / 800000
            if IsValid(Phys) then
<<<<<<< HEAD
                if isPlayer then v:SetVelocity(AimVec * 500 * force) end
                Phys:ApplyForceOffset(AimVec * 500 * force, plyPos)

=======
                if v:IsPlayer() then v:SetVelocity(AimVec * 500 * force) end
                Phys:ApplyForceOffset(AimVec * 500 * force, ply:GetPos())
>>>>>>> 8e5ef9bd (some changes i already made)
                v:SetPhysicsAttacker(ply, 5)
            end
        end
    end
end)
