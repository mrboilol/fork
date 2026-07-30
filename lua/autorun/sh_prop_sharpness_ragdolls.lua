
local math = math
local CurTime = CurTime

local function boneCountFixed( rag ) -- "Entity:GetPhysicsObjectNum - Out of bounds physics object - max 14, got 15 (x28)"
    return rag:GetPhysicsObjectCount() + -1

end

local function inWall( pos )
    return bit.band( util.PointContents( pos ), MASK_SOLID_BRUSHONLY ) > 0

end

PROP_SHARPNESS = PROP_SHARPNESS or {}
PROP_SHARPNESS.SkeweredRagdolls = {}

local cutoffDist = 20

local function debugPring( ... )
    --print( ... )

end

function PROP_SHARPNESS.skewerRagdoll( rag, impaledOn, strength, forcedPoint, bloodColor )
    if forcedPoint then
        forcedPoint = impaledOn:LocalToWorld( forcedPoint )

    end

    local bestDist = cutoffDist * 3.5
    local bestBone
    local objects = {}
    local bestBonesObj
    local totalVolume = 0
    local totalMass = 0
    local volumeThresh = 0

    local bestMassC
    local bestPosImpaler

    for bone = 0, boneCountFixed( rag ) do
        local ragsObj = rag:GetPhysicsObjectNum( bone )
        if not IsValid( ragsObj ) then continue end

        table.insert( objects, ragsObj )

        local currVolume = ragsObj:GetVolume()
        local currMass = ragsObj:GetMass()
        totalVolume = totalVolume + currVolume
        totalMass = totalMass + currMass

        local massC = ragsObj:LocalToWorld( ragsObj:GetMassCenter() )
        local criteriaPoint = forcedPoint or impaledOn:NearestPoint( massC )

        local subtProduct = criteriaPoint - massC
        local dirToImpaler = subtProduct:GetNormalized()
        local movedCloser = massC + dirToImpaler * math.min( subtProduct:Length(), cutoffDist )

        local dist = movedCloser:Distance( criteriaPoint )
        if dist < ( bestDist - 1 ) and currVolume >= volumeThresh then
            volumeThresh = math.min( currVolume, 250 )
            bestDist = dist
            bestBone = bone
            bestBonesObj = ragsObj

            bestMassC = massC
            bestPosImpaler = criteriaPoint

        end
    end

    if not bestBonesObj then debugPring( "yield_nobest" ) return end

    local stuffImpaled = impaledOn.propsharp_StuffImpaled
    if stuffImpaled then
        if stuffImpaled[ rag ] then debugPring( "yield_doubleimpale" ) return end

        local div
        if CLIENT then -- cside ragdolls arent laggy, let more of them be impaled 
            div = 1.25

        else
            div = 2

        end

        for ent, _ in pairs( stuffImpaled ) do
            if not IsValid( ent ) then
                stuffImpaled[ent] = nil

            else
                strength = strength / div

            end
        end
    end

    local volume = bestBonesObj:GetVolume()
    if volume < totalVolume / 10 then
        strength = strength / 10

    elseif bestBonesObj:IsMotionEnabled() then
        local objsDirToImpaled = ( bestPosImpaler - bestMassC ):GetNormalized()
        bestBonesObj:SetPos( bestBonesObj:GetPos() + objsDirToImpaled * cutoffDist )

        bestDist = math.max( bestDist + -cutoffDist, 0 )

    end
    if volume < totalVolume / cutoffDist then
        strength = strength / cutoffDist

    end

    if bestDist > 8 then
        strength = strength / ( bestDist - 8 )

    end

    if strength <= 250 then debugPring( "yield_tooweak" ) return end

    local oldMasses = {}

    local impaledOnObj = impaledOn:GetPhysicsObject()

    local ragsMass = totalMass or 100
    local impalersMass

    if IsValid( impaledOnObj ) then
        local mass = impaledOnObj:GetMass()
        if mass ~= 1 then -- gravgun sets mass to 1, HACK
            impalersMass = mass

        end
    end
    if not impalersMass then
        impalersMass = ragsMass

    end

    local impalersStronger = impalersMass >= ragsMass
    if CLIENT and not impalersStronger and impaledOnObj:IsMotionEnabled() then debugPring( "yield_badmix" ) return end -- cant :(

    local bonesNewMass = math.Clamp( impalersMass, 0, ragsMass )
    for ind, boneObj in ipairs( objects ) do
        oldMasses[ind] = boneObj:GetMass()

        local mass = 1
        if ind == 1 then continue end
        if boneObj == bestBonesObj then
            mass = bonesNewMass

        end
        if impalersStronger then
            boneObj:SetMass( mass )

        end
    end

    if not stuffImpaled then
        stuffImpaled = {}
        impaledOn.propsharp_StuffImpaled = stuffImpaled

    end
    stuffImpaled[rag] = true

    if SERVER then
        local block = hook.Run( "prop_sharpness_blockweld", impaledOn, rag )
        if block then return end

        local weld = constraint.Weld( rag, impaledOn, bestBone, 0, strength, true, false )
        if not IsValid( weld ) then debugPring( "yield_weldfail" ) return end
        hook.Run( "prop_sharpness_createweld", weld, "ragdoll" )

        table.insert( PROP_SHARPNESS.SkeweredRagdolls, rag )

        hook.Add( "prop_sharpness_onlaggin", rag, function( self, lagScale )
            if not IsValid( weld ) then return end
            if math.random( 0, 100 ) > lagScale then return end

            self:SetCollisionGroup( COLLISION_GROUP_DEBRIS ) -- intentionally dont restore this

            if math.random( 100, 150 ) > lagScale then return end

            SafeRemoveEntity( weld )

        end )

        weld:CallOnRemove( "prop_sharpness_unskewer", function()
            if not IsValid( rag ) then return end
            for ind, boneObj in pairs( objects ) do
                if not IsValid( boneObj ) then continue end
                boneObj:SetMass( oldMasses[ind] )

            end
            stuffImpaled[rag] = nil
            local rags = PROP_SHARPNESS.SkeweredRagdolls
            for ind, currRag in pairs( rags ) do
                if not IsValid( currRag ) then
                    table.remove( rags, ind )
                    continue

                end
                if currRag == rag then
                    table.remove( rags, ind )

                end
            end
        end )

        return true

    elseif CLIENT then
        local impaleHealth = strength
        local impaledPosLocal = impaledOn:WorldToLocal( bestPosImpaler )
        local impaledAngLocal = impaledOn:WorldToLocalAngles( bestBonesObj:GetAngles() )

        table.insert( PROP_SHARPNESS.SkeweredRagdolls, rag )

        local shutDownWeld = function( shutDownRag )
            hook.Remove( "Think", shutDownRag )
            hook.Remove( "prop_sharpness_onlaggin", rag )
            for ind, boneObj in pairs( objects ) do
                if not IsValid( boneObj ) then continue end
                boneObj:SetMass( oldMasses[ind] )
                boneObj:EnableMotion( true )
                boneObj:Wake()

            end
            stuffImpaled[shutDownRag] = nil
            local rags = PROP_SHARPNESS.SkeweredRagdolls
            for ind, currRag in pairs( rags ) do
                if not IsValid( currRag ) then
                    table.remove( rags, ind )
                    continue

                end
                if currRag == rag then
                    table.remove( rags, ind )

                end
            end
        end

        hook.Add( "prop_sharpness_onlaggin", rag, function( self, fps )
            if math.random( 10, 30 ) < fps then return end
            if math.random( 10, 30 ) < fps then return end

            shutDownWeld( self )

        end )

        hook.Add( "Think", rag, function()
            if not IsValid( impaledOn ) then
                shutDownWeld( rag )
                return

            end
            if impaledOn:IsDormant() then shutDownWeld( rag ) return end
            if not IsValid( bestBonesObj ) then shutDownWeld( rag ) return end

            local impaledPos = impaledOn:LocalToWorld( impaledPosLocal )
            if inWall( impaledPos ) then shutDownWeld( rag ) return end

            local nextSound = rag.sharpness_NextSound or 0
            local soundNeed = rag.sharpness_SoundNeed or 0

            local bestBonesPos = bestBonesObj:GetPos()
            local distToPos = impaledPos:Distance( bestBonesPos )
            if rag:GetPhysicsObject():IsAsleep() and impaledPos:Distance( LocalPlayer():GetPos() ) < 750 then
                for _, boneObj in pairs( objects ) do
                    if not IsValid( boneObj ) then continue end
                    boneObj:EnableMotion( true )
                    boneObj:Wake()

                end
            elseif distToPos > ( soundNeed - CurTime() ) and nextSound < CurTime() then
                rag.sharpness_NextSound = CurTime() + math.Rand( 0.01, 0.05 )
                rag.sharpness_SoundNeed = CurTime() + math.Clamp( distToPos - 5, math.Rand( 1, 2 ), 5 ) * math.Rand( 1, 2 )
                rag:EmitSound( "Flesh_Bloody.ImpactHard" )
                PROP_SHARPNESS.BloodSpray( rag, bestBonesPos, VectorRand(), math.Clamp( math.Rand( 0.1, 0.25 ) * distToPos, 0, 2 ), bloodColor )

            end
            local impaleDamage = 5 + distToPos

            impaleHealth = impaleHealth - impaleDamage
            if impaleHealth <= 0 then shutDownWeld( rag ) return end

            bestBonesObj:SetPos( impaledPos )

            local currAnglesLocal = impaledOn:WorldToLocalAngles( bestBonesObj:GetAngles() )
            impaledAngLocal.p = math.ApproachAngle( impaledAngLocal.p, currAnglesLocal.p, 1 )
            impaledAngLocal.y = math.ApproachAngle( impaledAngLocal.y, currAnglesLocal.y, 1 )
            impaledAngLocal.r = math.ApproachAngle( impaledAngLocal.r, currAnglesLocal.r, 1 )

            bestBonesObj:SetAngles( impaledOn:LocalToWorldAngles( impaledAngLocal ) )

            if IsValid( impaledOnObj ) then
                bestBonesObj:SetVelocity( impaledOnObj:GetVelocity() )

            end

        end )

        return true

    end
end

local timeWindow = 0.5

local function handle( died, rag )

    local impaledTime = died:GetNW2Float( "prop_sharpness_laststabtime" )

    local since = CurTime() - impaledTime

    if since > timeWindow then return end

    local impaledOn = died:GetNW2Entity( "prop_sharpness_laststabber" )

    if not IsValid( impaledOn ) then return end

    local impaleStrength = died:GetNW2Int( "prop_sharpness_impalestrength" )
    if impaleStrength <= 0 then return end -- might happen 

    local forcedPoint
    if died:GetNW2Bool( "prop_sharpness_hasauthedpoint", false ) then
        forcedPoint = died:GetNW2Vector( "prop_sharpness_authedpoint", nil )

    end

    local bloodColor = died:GetNW2Int( "prop_sharpness_bloodcolor", -1 )

    local skewered = PROP_SHARPNESS.skewerRagdoll( rag, impaledOn, impaleStrength, forcedPoint, bloodColor )
    return skewered

end

if CLIENT then
    hook.Add( "CreateClientsideRagdoll", "prop_sharpness_csideskewer", function( died, rag )
        local bloodColor = died:GetBloodColor()
        if bloodColor and bloodColor >= 0 then
            rag.sharpness_BloodColor = bloodColor

        end

        timer.Simple( 0, function()
            if not IsValid( died ) then return end
            if not IsValid( rag ) then return end
            rag.sharpness_Corpse = true

            if handle( died, rag ) then return end -- skewered em

            timer.Simple( math.Rand( 0.05, 0.15 ), function() -- didnt skewer, try again
                if not IsValid( died ) then return end
                if not IsValid( rag ) then return end

                if handle( died, rag ) then return end -- skewered em

                timer.Simple( math.Rand( 0.05, 0.1 ), function() -- didnt skewer, try again
                    if not IsValid( died ) then return end
                    if not IsValid( rag ) then return end

                    handle( died, rag )

                end )
            end )
        end )
    end )
end

hook.Add( "CreateEntityRagdoll", "prop_sharpness_serverskewer", function( died, rag )
    local bloodColor = died.bloodColorHitFix or died:GetBloodColor()
    if bloodColor and bloodColor >= 0 then
        rag.sharpness_BloodColor = bloodColor

    end

    timer.Simple( 0, function()
        if not IsValid( died ) then return end
        if not IsValid( rag ) then return end
        rag.sharpness_Corpse = true
        handle( died, rag )

    end )
end )