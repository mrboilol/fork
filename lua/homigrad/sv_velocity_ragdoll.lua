if not SERVER then return end

-- Ragdoll on high speed. This function is meant to be called from the
-- authoritative stumble loop (sv_tumbling.lua) so it does not spawn its own
-- Player Think/Think hooks and duplicate state checks.
local GROUND_VEL_RAGDOLL = 580
local AIR_VEL_RAGDOLL = 500

function hg.TryVelocityRagdoll(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply:Alive() then return end
    if IsValid(ply.FakeRagdoll) then return end -- already ragdolled
    if ply:InVehicle() then return end -- skip vehicles
    if ply:GetMoveType() == MOVETYPE_NOCLIP then return end -- ignore noclip

    local speed = ply:GetVelocity():Length()
    if ply:IsOnGround() then
        if speed >= GROUND_VEL_RAGDOLL then
            hg.Fake(ply)
        end
    else
        if speed >= AIR_VEL_RAGDOLL then
            hg.Fake(ply)
        end
    end
end
