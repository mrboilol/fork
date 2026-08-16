hook.Add("PhysgunDrop", "SealRestoreJump", function(ply, ent)
    if IsValid(ent) and ent:GetClass() == "sealplush1" then
        ent.IsHeld = false
        if ent.StartIdleMovement then
            ent:StartIdleMovement()
        else
        end
    end
end)