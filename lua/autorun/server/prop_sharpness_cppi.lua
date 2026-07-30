if not CPPI then return end

hook.Add( "prop_sharpness_blockweld", "sharpness_cppi_compat", function( thing, into )
    local intoWorld = into:IsWorld()
    if intoWorld then return end -- always ok

    local thingsOwner = thing:CPPIGetOwner()
    if not IsValid( thingsOwner ) then return end

    local intosOwner = into:CPPIGetOwner()
    if not IsValid( intosOwner ) then return end
    if thingsOwner == intosOwner then return end -- just fine

    if into:CPPICanTool( thingsOwner, "weld" ) then return end -- allow it

    local forceAllow = hook.Run( "prop_sharpness_allow_cppi_conflictingweld", thing, into, thingsOwner, intosOwner )
    if forceAllow == true then return end -- allow it

    return true -- block

end )
