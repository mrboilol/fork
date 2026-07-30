
if SERVER then
    local nextThink = 0
    hook.Add( "Think", "prop_sharpness_lagfind", function()
        local cur = CurTime()

        if nextThink > cur then return end
        nextThink = cur + 1

        if not PROP_SHARPNESS.SkeweredRagdolls or #PROP_SHARPNESS.SkeweredRagdolls <= 1 then nextThink = cur + 5 return end

        local lagScale = physenv.GetLastSimulationTime() * 1000
        if lagScale > 5 then
            hook.Run( "prop_sharpness_onlaggin", lagScale )

        end
    end )
else
    local nextThink = 0
    hook.Add( "Think", "prop_sharpness_lagfind", function()
        local cur = CurTime()

        if nextThink > cur then return end
        nextThink = cur + 1

        if not PROP_SHARPNESS.SkeweredRagdolls or #PROP_SHARPNESS.SkeweredRagdolls <= 1 then nextThink = cur + 5 return end

        local fps = 1 / FrameTime()
        if fps < 30 then
            hook.Run( "prop_sharpness_onlaggin", fps )

        end
    end )
end