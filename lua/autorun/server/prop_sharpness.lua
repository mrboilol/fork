
local IsValid = IsValid
local math = math
local cvarMeta = FindMetaTable( "ConVar" )
local entsMeta = FindMetaTable( "Entity" )
local physMeta = FindMetaTable( "PhysObj" )

do

    local blockProppushVar = CreateConVar( "sharpness_sv_proppushdamage", "1", FCVAR_ARCHIVE, "Do sharpness damage on stuff held/thrown by the physics gun?", 0, 1 )
    hook.Add( "prop_sharpness_blocksharpdamage", "sharpness_noplyproppushdamage", function( sharpEnt, damaged )
        if cvarMeta.GetBool( blockProppushVar ) then return end
        if not damaged:IsPlayer() then return end
        if IsValid( sharpEnt.sharpness_PhysgunHolder ) and damaged ~= sharpEnt.sharpness_PhysgunHolder then return true end
        if sharpEnt.sharpness_Thrower and sharpEnt.sharpness_ThrowType == "physgun" and damaged ~= sharpEnt.sharpness_Thrower then return true end

    end )

    local damageMulVar = CreateConVar( "sharpness_sv_sharpdamagemul", "1", FCVAR_ARCHIVE, "Multiply 'sharp' damage by this amount", 0, 9999 )
    hook.Add( "prop_sharpness_predamage", "sharpness_damagemul", function( _sharpEnt, _takingDamage, hookDat, _sharpData )
        local dmgMul = cvarMeta.GetFloat( damageMulVar )
        if dmgMul == 1 then return end
        hookDat.damage = hookDat.damage * dmgMul

    end )

    local crushMagicNum = 1.025

    local damageLogVar = CreateConVar( "sharpness_sv_nobigdamage", "0", FCVAR_ARCHIVE, "Stops 'sharp' damage from blowing up. Damage will clamp out at around ~275", 0, 1 )
    hook.Add( "prop_sharpness_predamage", "sharpness_damagemath.log", function( _sharpEnt, _takingDamage, hookDat, _sharpData )
        if not cvarMeta.GetBool( damageLogVar ) then return end
        hookDat.damage = math.log( hookDat.damage, crushMagicNum )

    end )
end

local doSelfDamageVar = CreateConVar( "sharpness_sv_selfdamage", "1", FCVAR_ARCHIVE, "Makes sharp props take a bit of 'dulling' damage when they poke stuff.", 0, 1 )
local maxDamageVar = CreateConVar( "sharpness_sv_maxdamage", "-1", FCVAR_ARCHIVE, "Max damage per poke? Default unlimited damage.", -1, 999999999 )
local maxDamageHeldVar = CreateConVar( "sharpness_sv_maxdamage_whenheld", "-1", FCVAR_ARCHIVE, "Max sharpness damage when being held?", -1, 999999999 )

local debugVar = CreateConVar( "sharpness_sv_debug", "0", FCVAR_NONE, "enable developer 1 visualizers to help add sharp props" )
local debugging = debugVar:GetBool()
cvars.AddChangeCallback( "sharpness_sv_debug", function()
    debugging = debugVar:GetBool()

end, "asbool" )

local function dirToPos( startPos, endPos )
    if not startPos then return end
    if not endPos then return end

    return ( endPos - startPos ):GetNormalized()

end


local string_lower = string.lower
local string_find = string.find

local materialAliases = {
    ["grass"] = "dirt",
    ["antlion"] = "flesh",
    ["plaster"] = "generic",
    ["concrete"] = "generic",

}

local potentialMaterials = {
    "dirt",
    "wood",
    "grass",
    "flesh",
    "antlion",
    "plastic",
    "plaster",
    "concrete",
}

local function getMaterialFromString( str )
    str = string_lower( str )
    local theMat = "generic"
    for _, currMat in ipairs( potentialMaterials ) do
        if string_find( str, currMat ) then
            --print( loweredStr, currMat, ent:GetModel() )
            theMat = currMat
            break

        end
    end

    theMat = materialAliases[theMat] or theMat

    return theMat
end

local function getMaterialForEnt( ent )
    if not IsValid( ent ) then return end

    local cached = ent.sharpness_CachedSoundMaterial
    if cached then return cached end

    local theMat
    local stringToCheck = ent:GetMaterial()

    if stringToCheck ~= "" then
        local loweredStr = string_lower( stringToCheck )

        for _, currMat in ipairs( potentialMaterials ) do
            if string_find( loweredStr, currMat ) then
                --print( loweredStr, currMat, ent:GetModel() )
                theMat = currMat
                break

            end
        end
    end

    local bloodColor = ent.bloodColorHitFix or ent:GetBloodColor() or ent.sharpness_BloodColor
    if bloodColor and bloodColor >= 0 then
        theMat = "flesh"

    end

    if not theMat then
        local entsObj = entsMeta.GetPhysicsObject( ent )
        if IsValid( entsObj ) then
            stringToCheck = entsObj:GetMaterial()

        end
        local loweredStr = string_lower( stringToCheck )

        for _, currMat in ipairs( potentialMaterials ) do
            if string_find( loweredStr, currMat ) then
                --print( loweredStr, currMat, ent:GetModel() )
                theMat = currMat
                break

            end
        end
    end

    if not theMat then
        theMat = "generic"

    end

    theMat = materialAliases[theMat] or theMat

    ent.sharpness_CachedSoundMaterial = theMat

    timer.Simple( 5, function() -- props WILL get their material changed
        if not IsValid( ent ) then return end
        ent.sharpness_CachedSoundMaterial = nil

    end )
    return theMat

end


local damageScales = {
    ["wood"] = 0.75,
    ["flesh"] = 1,
    ["plastic"] = 0.8,
    ["generic"] = 0.25, -- metal, concrete, etc
    ["dirt"] = 2,

}

function PROP_SHARPNESS.scaleDamageForEntsMaterial( ent, dmg )
    local mat = getMaterialForEnt( ent )
    return dmg * damageScales[ mat ], mat

end


PROP_SHARPNESS = PROP_SHARPNESS or {}

function PROP_SHARPNESS.CanBleed( ent )
    local color = ent.bloodColorHitFix or ent:GetBloodColor()
    if not color then return end
    return color >= 0

end

function PROP_SHARPNESS.SHARP_POINTY( _, dirRef, collisonNormal ) -- one end is pointy
    local product = dirRef:Dot( collisonNormal )
    if product > -0.75 then return 0 end
    return -product, dirRef

end
function PROP_SHARPNESS.SHARP_DUALPOINTY( _, dirRef, collisonNormal ) -- both ends are pointy
    local product = math.abs( dirRef:Dot( collisonNormal ) )
    if product < 0.75 then return 0 end
    return product, dirRef -- WRONG

end
function PROP_SHARPNESS.SHARP_PLANAR( sharpEnt, dirRef, collisonNormal ) -- flat plane of pointy ( eg sawblade )
    local product = math.abs( dirRef:Dot( collisonNormal ) )
    if product > 0.5 then
        return 0

    else
        local sharpsPos = sharpEnt:GetPos()
        local sharpDir = sharpEnt:WorldToLocal( -collisonNormal + sharpsPos )
        sharpDir.z = 0
        sharpDir:Normalize()
        sharpDir = sharpEnt:LocalToWorld( sharpDir ) - sharpsPos

        return math.min( ( 1 - product ) * 1.5, 1 ), sharpDir

    end
end

PROP_SHARPNESS.skewerSnd = {
    "ambient/machines/slicer1.wav",
    "ambient/machines/slicer2.wav",
    "ambient/machines/slicer3.wav",
    "ambient/machines/slicer4.wav",

}
PROP_SHARPNESS.skewerSndNonMetallic = {
    "ambient/machines/slicer2.wav",
    "ambient/machines/slicer3.wav",

}

PROP_SHARPNESS.sawbladeSliceSound = {
    "d1_town.Slicer"

}

PROP_SHARPNESS.bashingSound = {
    "physics/body/body_medium_break2.wav",
    "physics/body/body_medium_break3.wav",
    "physics/body/body_medium_break4.wav",

}

PROP_SHARPNESS.metalstickSounds = {
    "physics/metal/sawblade_stick1.wav",
    "physics/metal/sawblade_stick2.wav",
    "physics/metal/sawblade_stick3.wav",

}

PROP_SHARPNESS.woodStickSounds = {
    "physics/wood/wood_solid_impact_bullet2.wav",
    "physics/wood/wood_solid_impact_bullet3.wav",
    "physics/wood/wood_box_impact_bullet1.wav",
    "physics/wood/wood_box_impact_bullet4.wav",

}


PROP_SHARPNESS.IMPALE_STRONG = 25000
PROP_SHARPNESS.IMPALE_MEDIUM = 8000
PROP_SHARPNESS.IMPALE_WEAK = 2500


PROP_SHARPNESS.SPEED_SUPERSHARP = 5
PROP_SHARPNESS.SHARPNESS_SUPERSHARP = 0.9

PROP_SHARPNESS.SPEED_ALWAYSDMG = 75
PROP_SHARPNESS.SHARPNESS_SHARP = 0.75

PROP_SHARPNESS.SPEED_DULL = 100
PROP_SHARPNESS.SHARPNESS_DULL = 0.5

PROP_SHARPNESS.SPEED_BLUNT = 125
PROP_SHARPNESS.SHARPNESS_BLUNT = 0.05

PROP_SHARPNESS.SPEED_CRUSH = 300
PROP_SHARPNESS.SHARPNESS_CRUSH = 0.5


local dirCache = {}

function PROP_SHARPNESS.sharpDataWithDirection( data, newDir, invertDir )
    local key = tostring( data ) .. tostring( newDir ) .. tostring( invertDir )

    local cached = dirCache[key]
    if cached then return cached end -- table.Copy is heavy on lua perf and memory

    local new = table.Copy( data )
    new.dirFunc = newDir
    new.invertDir = invertDir

    dirCache[key] = new
    return new

end

local appendCache = {}

function PROP_SHARPNESS.sharpDataWithAppended( data, appendData )
    local key = tostring( data ) .. tostring( appendData )

    local cached = appendCache[key]
    if cached then return cached end

    local new = table.Copy( data )
    for appendKey, appendVal in pairs( appendData ) do
        new[appendKey] = appendVal

    end

    appendCache[key] = new
    appendData = nil
    return new

end


PROP_SHARPNESS.generic_SUPERSHARP_UPWARD_SPIKE = {
    typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
    dirFunc = entsMeta.GetUp,
    startSpeed = PROP_SHARPNESS.SPEED_SUPERSHARP,
    sharpness = PROP_SHARPNESS.SHARPNESS_SUPERSHARP,
    dmgSounds = PROP_SHARPNESS.skewerSnd,
    impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,

}

PROP_SHARPNESS.generic_SHARP_UPWARD_SPIKE = {
    typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
    dirFunc = entsMeta.GetUp,
    startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
    sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
    dmgSounds = PROP_SHARPNESS.skewerSnd,
    impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,

}

PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE = {
    typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
    dirFunc = entsMeta.GetUp,
    startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
    sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
    dmgSounds = PROP_SHARPNESS.skewerSnd,
    impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

}

PROP_SHARPNESS.generic_DULL_UPWARD_SPIKE = {
    typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
    dirFunc = entsMeta.GetUp,
    startSpeed = PROP_SHARPNESS.SPEED_BLUNT, -- intentional
    sharpness = PROP_SHARPNESS.SHARPNESS_DULL,
    dmgSounds = PROP_SHARPNESS.skewerSnd,
    impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

}

PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE = {
    typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
    dirFunc = entsMeta.GetUp,
    invertDir = true,
    startSpeed = PROP_SHARPNESS.SPEED_BLUNT, -- intentional
    sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
    dmgSounds = PROP_SHARPNESS.skewerSnd,
    impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,

}

PROP_SHARPNESS.generic_IMPALING_BASHING_DOWNWARD = {
    typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
    dirFunc = entsMeta.GetUp,
    invertDir = true,
    localPos = Vector( 0, 0, 0 ),
    localPosDist = 50,
    startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
    sharpness = PROP_SHARPNESS.SHARPNESS_CRUSH,
    dmgType = DMG_CRUSH,
    dmgSounds = PROP_SHARPNESS.bashingSound,
    impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

}

PROP_SHARPNESS.generic_DUALBASH_IBEAM = { -- takes alot of speed to make this deal damage, but its an instakill
    typeTransformer = PROP_SHARPNESS.SHARP_DUALPOINTY,
    dirFunc = entsMeta.GetForward,
    startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
    sharpness = PROP_SHARPNESS.SHARPNESS_CRUSH,
    dmgType = DMG_CRUSH,
    dmgSounds = PROP_SHARPNESS.bashingSound,
    impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,
    sticks = true,
    stickSounds = {
        "d1_town.CarHit",

    },

}
PROP_SHARPNESS.generic_DUALSHARP_IBEAM = table.Copy( PROP_SHARPNESS.generic_DUALBASH_IBEAM )
PROP_SHARPNESS.generic_DUALSHARP_IBEAM.sharpness = PROP_SHARPNESS.SHARPNESS_DULL

PROP_SHARPNESS.generic_DUALSHARP_REBAR = { -- same as ibeam, but less intense sounds, and stronger impaling
    typeTransformer = PROP_SHARPNESS.SHARP_DUALPOINTY,
    dirFunc = entsMeta.GetUp,
    startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
    sharpness = PROP_SHARPNESS.SHARPNESS_DULL,
    dmgSounds = PROP_SHARPNESS.skewerSnd,
    impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,
    sticks = true,

}

PROP_SHARPNESS.generic_DUALSHARP_WOODSPLINTERS = { -- takes little speed, and does little damage
    typeTransformer = PROP_SHARPNESS.SHARP_DUALPOINTY,
    dirFunc = entsMeta.GetUp,
    startSpeed = PROP_SHARPNESS.SPEED_DULL,
    sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
    dmgSounds = PROP_SHARPNESS.skewerSndNonMetallic,
    maxDamage = "mass", -- makes maxdamage based off the ent's mass, 2x of mass if frozen, 1x if not
    impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,
    sticks = true,
    sticksIntoOnly = { flesh = true, wood = true, dirt = true },
    stickSounds = PROP_SHARPNESS.woodStickSounds,

}

PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS = table.Copy( PROP_SHARPNESS.generic_DUALSHARP_WOODSPLINTERS )
PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS.typeTransformer = PROP_SHARPNESS.SHARP_POINTY

PROP_SHARPNESS.generic_PLANARFORW_CRUSHCUTTER = {
    typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
    dirFunc = entsMeta.GetForward,
    invertDir = nil,
    startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
    sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
    dmgSounds = PROP_SHARPNESS.bashingSound,
    impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,
    sticks = true,
    canSlice = true,

}
PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER = table.Copy( PROP_SHARPNESS.generic_PLANARFORW_CRUSHCUTTER )
PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER.startSpeed = PROP_SHARPNESS.SPEED_BLUNT


function PROP_SHARPNESS.AddModels( models )
    local mdlData = PROP_SHARPNESS.ModelData
    for mdl, data in pairs( models ) do
        if not data.typeTransformer or not isfunction( data.typeTransformer ) then
            error( "SHARPNESS: Can't add " .. mdl .. ", invalid .typeTransformer" )

        end
        if not data.dirFunc or not isfunction( data.typeTransformer ) then
            error( "SHARPNESS: Can't add " .. mdl .. ", invalid .dirFunc" )

        end
        if not data.startSpeed or not isnumber( data.startSpeed ) then
            error( "SHARPNESS: Can't add " .. mdl .. ", invalid .startSpeed" )

        end
        if not data.sharpness or not isnumber( data.sharpness ) then
            error( "SHARPNESS: Can't add " .. mdl .. ", invalid .sharpness" )

        end
        if not data.dmgSounds or not istable( data.dmgSounds ) then
            error( "SHARPNESS: Can't add " .. mdl .. ", invalid .dmgSounds" )

        end
        if data.localPosDist and not isnumber( data.localPosDist ) then
            error( "SHARPNESS: Can't add " .. mdl .. ", invalid .localPosDist" )

        end
        if data.localPos and not isvector( data.localPos ) then
            error( "SHARPNESS: Can't add " .. mdl .. ", invalid .localPos" )

        end
        mdlData[mdl] = data

    end
end

local refreshed = true

local function gobble()
    refreshed = nil
    PROP_SHARPNESS.ModelData = {}

    local count = 0

    local dataFiles = file.Find( "prop_sharpness_sharpdata/*.lua", "LUA" )
    for _, name in ipairs( dataFiles ) do
        local success = ProtectedCall( function( nameProtected ) include( "prop_sharpness_sharpdata/" .. nameProtected ) end, name )
        if success then
            count = count + 1

        end
    end
    print( "prop_sharpness: Gobbled " .. count .. " sharp data files..." )

end

hook.Add( "PostCleanupMap", "prop_sharpness_gobble", function()
    if not refreshed then return end
    gobble()

end )

hook.Add( "InitPostEntity", "prop_sharpness_gobble", function()
    gobble()

end )

local sparkClipMaxs = Vector( 1, 1, 1 )
local sparkClipMins = -sparkClipMaxs

function PROP_SHARPNESS.DoSharpPoke( sharpData, currSharpDat, sharpEnt, takingDamage )
    local isWorld
    if not IsValid( takingDamage ) then
        if takingDamage and takingDamage:IsWorld() then
            isWorld = true-- we stick into the world...

        else
            return

        end
    end

    if hook.Run( "prop_sharpness_blocksharpdamage", sharpEnt, takingDamage ) then return end

    local dirRef = sharpData.dirFunc( sharpEnt )
    if sharpData.invertDir then
        dirRef = -dirRef

    end

    local forCollide, pointyDir = sharpData.typeTransformer( sharpEnt, dirRef, currSharpDat.collisonNormal )
    local sharpness = sharpData.sharpness * forCollide
    if sharpness <= 0 then return end

    if debugging then
        local oldPos = sharpEnt:GetPos()
        debugoverlay.Line( oldPos, oldPos + pointyDir * 250, 10, color_white, true )

    end

    local dealingsCenter = sharpEnt:WorldSpaceCenter()
    local takingsCenter = takingDamage:WorldSpaceCenter()
    local nearest = sharpEnt:NearestPoint( takingsCenter )

    local localPos = sharpData.localPos -- some specific part of the ent is sharp
    local localPosDist = sharpData.localPosDist
    local sharpPoint
    if localPos then
        sharpPoint = sharpEnt:LocalToWorld( localPos )

    end

    local worldPokeResult
    if isWorld then
        local trStart = sharpPoint or dealingsCenter
        worldPokeResult = util.TraceLine( {
            start = trStart,
            endpos = trStart + pointyDir * sharpEnt:GetModelRadius() * 2,
            filter = sharpEnt,
            mask = MASK_SOLID_BRUSHONLY,

        } )
    end

    if sharpPoint and localPosDist then
        if debugging then
            debugoverlay.Cross( sharpPoint, 5, 5, color_white, true )

        end
        if isWorld then
            if worldPokeResult.HitPos:Distance( sharpPoint ) > localPosDist then return end

        else
            local takersNearest = takingDamage:NearestPoint( sharpPoint )

            local hitSomewhereDull = takersNearest:Distance( sharpPoint ) > localPosDist
            if hitSomewhereDull then return end
            if debugging then
                debugoverlay.Line( takersNearest, sharpPoint, 5, color_white, true )
                debugoverlay.Text( takersNearest, takersNearest:Distance( sharpPoint ), 5, false )

            end
        end
    end

    local isRagdoll = takingDamage:IsRagdoll()
    local alive = takingDamage:IsPlayer() or takingDamage:IsNPC() or takingDamage:IsNextBot()
    local minSharpSpeed = sharpData.startSpeed
    local dmgVel = currSharpDat.oldVel
    local speed = currSharpDat.speed or currSharpDat.oldVel:Length()

    local overMin = speed - minSharpSpeed
    local damage = overMin * sharpness

    local sharpEntsMat, takingDamagesMat

    damage, sharpEntsMat = PROP_SHARPNESS.scaleDamageForEntsMaterial( sharpEnt, damage )

    if isWorld then
        if worldPokeResult.HitWorld then
            takingDamagesMat = getMaterialFromString( util.GetSurfacePropName( worldPokeResult.SurfaceProps ) )

        end
    else
        damage, takingDamagesMat = PROP_SHARPNESS.scaleDamageForEntsMaterial( takingDamage, damage ) -- so we dont instakill glide cars, etc

    end

    local hookDat = { damage = damage }
    hook.Run( "prop_sharpness_predamage", sharpEnt, takingDamage, hookDat, sharpData )

    damage = hookDat.damage

    damage = math.floor( damage )
    if damage <= 0 then return end

    local maxDamage = sharpData.maxDamage
    if maxDamage then
        if isstring( maxDamage ) and maxDamage == "mass" then
            local sharpEntsObj = entsMeta.GetPhysicsObject( sharpEnt )
            if IsValid( sharpEntsObj ) then
                local mass = physMeta.GetMass( sharpEntsObj )
                local frozen = not physMeta.IsMotionEnabled( sharpEntsObj )
                if frozen then
                    maxDamage = mass * 2

                else
                    maxDamage = mass

                end
            else
                maxDamage = nil
            end
        end
        if maxDamage then
            damage = math.min( damage, maxDamage )

        end
    end

    local maxDmg = cvarMeta.GetInt( maxDamageVar )
    if maxDmg >= 0 then
        damage = math.min( damage, maxDmg )

    end

    local maxDmgHeld = cvarMeta.GetInt( maxDamageHeldVar )
    if maxDmgHeld >= 0 and IsValid( sharpEnt.sharpness_Holder ) then
        damage = math.min( damage, maxDmgHeld )

    end

    if sharpData.impaleStrength then
        local color = takingDamage.bloodColorHitFix or takingDamage:GetBloodColor()

        if isRagdoll then
            PROP_SHARPNESS.skewerRagdoll( takingDamage, sharpEnt, sharpData.impaleStrength, sharpData.localPos, color )

        elseif alive then
            takingDamage:SetNW2Float( "prop_sharpness_laststabtime", CurTime() )
            takingDamage:SetNW2Entity( "prop_sharpness_laststabber", sharpEnt )
            takingDamage:SetNW2Int( "prop_sharpness_impalestrength", sharpData.impaleStrength )

            if color then
                takingDamage:SetNW2Int( "prop_sharpness_bloodcolor", color )

            end

            takingDamage:SetNW2Bool( "prop_sharpness_hasauthedpoint", isvector( sharpPoint ) )

            if sharpPoint then
                takingDamage:SetNW2Vector( "prop_sharpness_authedpoint", sharpData.localPos )

            end
        end
    end

    local dmgType = sharpData.dmgType
    if not dmgType then
        if sharpData.canSlice and speed > math.random( 450, 550 ) then -- slice zombies!
            dmgType = bit.bor( DMG_SLASH, DMG_CRUSH )

        else
            dmgType = DMG_SLASH

        end
    end

    local sharpEntsTbl = entsMeta.GetTable( sharpEnt )

    local attacker
    if IsValid( sharpEntsTbl.sharpness_Holder ) then
        attacker = sharpEntsTbl.sharpness_Holder

    end
    if not attacker and IsValid( sharpEntsTbl.sharpness_Thrower ) then
        attacker = sharpEntsTbl.sharpness_Thrower

    end
    if not attacker then
        if CPPI and IsValid( sharpEnt:CPPIGetOwner() ) then
            attacker = sharpEnt:CPPIGetOwner()

        elseif IsValid( sharpEnt:GetCreator() ) then
            attacker = sharpEnt:GetCreator()

        elseif IsValid( sharpEnt:GetOwner() ) then
            attacker = sharpEnt:GetOwner()

        end
    end
    if not attacker then
        attacker = sharpEnt -- :(

    end

    local dmgInfo = DamageInfo()
    dmgInfo:SetAttacker( attacker )
    dmgInfo:SetInflictor( sharpEnt )
    dmgInfo:SetDamage( damage )
    dmgInfo:SetDamageType( dmgType )
    dmgInfo:SetDamagePosition( nearest )
    dmgInfo:SetDamageForce( dmgVel )

    if debugging then
        print( "SHARPNESS: " .. sharpEnt:GetModel() .. " with mat " .. sharpEntsMat .. " dealt " .. math.Round( damage ) .. " damage to", takingDamage, "of mat " .. takingDamagesMat )

    end

    takingDamage:TakeDamageInfo( dmgInfo )

    if cvarMeta.GetBool( doSelfDamageVar ) then -- for servers with simple prop damage, etc
        local multiplier = 0.05
        local selfDamage = damage * multiplier
        local selfDmgInfo = DamageInfo()
        selfDmgInfo:SetAttacker( sharpEnt )
        selfDmgInfo:SetInflictor( sharpEnt )
        selfDmgInfo:SetDamage( selfDamage )
        selfDmgInfo:SetDamageType( DMG_SLASH )
        selfDmgInfo:SetDamagePosition( nearest )
        selfDmgInfo:SetDamageForce( dmgVel * multiplier )
        sharpEnt:TakeDamageInfo( selfDmgInfo )

    end


    local bloodRef = sharpPoint or sharpEnt:WorldSpaceCenter()
    if takingDamagesMat == "flesh" then -- bluud!
        local scale = math.Clamp( damage / math.random( 8, math.max( 10, damage ) ), 8, 12 )
        PROP_SHARPNESS.BloodSpray( takingDamage, nearest, dirToPos( bloodRef, takingsCenter ), scale )

    end

    if sharpEntsMat == "generic" and takingDamagesMat == "generic" then -- sparks!
        local scale = math.Clamp( damage / math.random( 8, math.max( 10, damage ) ), 8, 12 )
        local nearestInside
        if not isWorld and util.IsInWorld( nearest ) then
            nearestInside = nearest

        else
            local nearestInsideResult = util.TraceHull( {
                start = sharpPoint or dealingsCenter,
                endpos = dealingsCenter + pointyDir * sharpEnt:GetModelRadius() * 2,
                filter = sharpEnt,
                mask = MASK_SOLID_BRUSHONLY,
                mins = sparkClipMins,
                maxs = sparkClipMaxs,

            } )
            nearestInside = nearestInsideResult.HitPos

        end
        PROP_SHARPNESS.SparkSpray( nearestInside, dirToPos( takingsCenter, bloodRef ), scale )

    end

    sharpEntsTbl.sharpness_NextDealDamage = CurTime() + 0.15

    if alive or isRagdoll then
        local paths = sharpData.dmgSounds
        local path = paths[math.random( 1, #paths )]
        local pitch = math.Clamp( 120 - ( damage / 2 ), 50, 120 )
        if pitch < 65 then
            sharpEnt:EmitSound( paths[math.random( 1, #paths )], 85, 90, 1, CHAN_STATIC )

        end
        sharpEnt:EmitSound( path, 80, pitch, 1 )

        timer.Simple( 0, function()
            local dir = dirToPos( bloodRef, takingsCenter )
            PROP_SHARPNESS.BloodSpray( takingDamage, nearest, dir + VectorRand(), math.Clamp( damage / math.random( 1, 10 ), 4, 10 ) )

        end )
    elseif sharpData.sticks then -- STICKING
        local goodStick = speed > minSharpSpeed * 4
        local scriptedStick = sharpData.sticksIntoOnly and takingDamagesMat and sharpData.sticksIntoOnly[takingDamagesMat]
        if ( scriptedStick and goodStick ) or ( sharpness >= 0.75 and damage > 25 and goodStick ) then
            if currSharpDat.preCollideAng then
                sharpEnt:SetAngles( currSharpDat.preCollideAng )

            end
            PROP_SHARPNESS.HandlePropSticking( sharpEnt, takingDamage, sharpData, pointyDir )

        end
    end
end

do
    local function handleSharpCollide( sharpEnt, colData, sharpData )
        local minSharpSpeed = sharpData.startSpeed
        local speed = colData.Speed
        if speed < minSharpSpeed then return end

        if sharpEnt.sharpness_NextDealDamage > CurTime() then return end
        local preCollideAng = sharpEnt:GetAngles()

        timer.Simple( 0, function() -- dont break default zombie slicing!
            if not IsValid( sharpEnt ) then return end

            local takingDamage = colData.HitEntity

            local oldVel = colData.TheirOldVelocity - colData.OurOldVelocity
            local velDir = oldVel:GetNormalized()

            local collisonNormal = ( -colData.HitNormal * 0.30 ) + ( velDir * 0.60 )
            collisonNormal:Normalize()

            local currSharpDat = {
                speed = speed,
                oldVel = oldVel,
                preCollideAng = preCollideAng,
                collisonNormal = collisonNormal,

            }

            PROP_SHARPNESS.DoSharpPoke( sharpData, currSharpDat, sharpEnt, takingDamage )

        end )
    end
    local string_lowerCreated = string.lower
    local getModel = entsMeta.GetModel

    hook.Add( "OnEntityCreated", "prop_sharpness_findsharp", function( ent )
        timer.Simple( 0, function() -- another use for PostEntityCreated
            if not IsValid( ent ) then return end

            local model = getModel( ent )
            if not model then return end -- someone reported this as a bug once and now im paranoid

            model = string_lowerCreated( model )
            local modelData = PROP_SHARPNESS.ModelData
            if not modelData then
                gobble() -- evil error
                modelData = PROP_SHARPNESS.ModelData

            end
            local sharpData = modelData[model]
            if not sharpData then return end

            ent.sharpness_NextDealDamage = 0
            ent.IsSharp = true

            if debugging then
                print( "SHARPNESS: Made \"" .. model .. "\" sharp." )

            end

            if ent:IsScripted() then
                local hasOldCollide = isfunction( ent.PhysicsCollide )
                ent.sharpness_OldPhysicsCollide = ent.PhysicsCollide -- kinda hacky
                function ent:PhysicsCollide( colData, collider )
                    if hasOldCollide then
                        self:sharpness_OldPhysicsCollide( colData, collider )

                    end
                    handleSharpCollide( self, colData, sharpData )

                end
            else
                ent:AddCallback( "PhysicsCollide", function( sharpEnt, colData )
                    handleSharpCollide( sharpEnt, colData, sharpData )

                end )
            end
        end )
    end )
end

-- always do sharp damage if player falls on a sharp prop
hook.Add( "GetFallDamage", "prop_sharpness_sharplanding", function( ply, speed )
    local landEnt = ply:GetGroundEntity()

    if not IsValid( landEnt ) then return end
    if not landEnt.IsSharp then return end

    local model = landEnt:GetModel()
    if not model then return end

    local sharpData = PROP_SHARPNESS.ModelData[model]
    if not sharpData then return end

    local plyVel = ply:GetVelocity()

    local currSharpDat = {
        speed = speed,
        oldVel = plyVel,
        collisonNormal = plyVel:GetNormalized(),

    }

    PROP_SHARPNESS.DoSharpPoke( sharpData, currSharpDat, landEnt, ply )

end )

-- terminator nextbot base support
hook.Add( "GetTermFallDamage", "prop_sharpness_sharplanding", function( bot, landEnt, fallHeight, originalDamage )
    if not IsValid( landEnt ) then return end
    if not landEnt.IsSharp then return end

    local model = landEnt:GetModel()
    if not model then return end

    local sharpData = PROP_SHARPNESS.ModelData[model]
    if not sharpData then return end

    local botsVel = Vector( 0, 0, -fallHeight / 2 )

    local currSharpDat = {
        speed = fallHeight,
        oldVel = botsVel,
        collisonNormal = botsVel:GetNormalized(),

    }

    PROP_SHARPNESS.DoSharpPoke( sharpData, currSharpDat, landEnt, bot )

end )


local vec_zero = Vector( 0, 0, 0 )

function PROP_SHARPNESS.HandlePropSticking( thing, into, sharpData, dir )
    local freeze
    local weld
    local nudgeThem
    local nudgeUs

    local thingsObj = entsMeta.GetPhysicsObject( thing )
    local intoObj

    if into:IsWorld() then
        freeze = true
        nudgeUs = thingsObj:IsMotionEnabled()

    else
        intoObj = entsMeta.GetPhysicsObject( into )
        if IsValid( intoObj ) then
            local intosFrozen = not intoObj:IsMotionEnabled()
            local thingsFrozen = not thingsObj:IsMotionEnabled()
            if not intosFrozen and not thingsFrozen then
                weld = true
                nudgeUs = true

            elseif thingsFrozen and not intosFrozen then
                weld = true
                nudgeThem = true

            else
                freeze = true

            end
        else
            intoObj = nil

        end
    end


    if not ( freeze or weld ) then
        return

    end

    local nudgeSize = math.random( 10, 15 )

    local paths = sharpData.stickSounds
    local path = paths[math.random( 1, #paths )]
    local pitch = math.random( 95, 105 )
    thing:EmitSound( path, 80, pitch, 1 )

    if weld then -- check if we can do this weld
        local block, freezeInstead = hook.Run( "prop_sharpness_blockweld", thing, into )
        if block then
            weld = nil

        end
        if freezeInstead then
            freeze = true

        end
    end

    local strength = math.min( thingsObj:GetMass() * 100, intoObj and intoObj:GetMass() * 100 or math.huge )

    if freeze then
        local time
        local newWeld
        if #constraint.GetTable( thing ) >= 1 then -- if we're part of a contraption, weld then freeze later
            -- welding to world, any sensible prop protection will handle this but here's a hook anyway
            local block = hook.Run( "prop_sharpness_blockworldweld", thing, into )
            if not block then
                strength = strength / 2
                newWeld = constraint.Weld( thing, game.GetWorld(), 0, 0, strength, false )

            end
        end

        local wasWeld

        if newWeld and IsValid( newWeld ) then
            time = 10 -- kill constraint and freeze ent if its forgotten about
            wasWeld = true
            nudgeSize = nudgeSize / 4
            thing:ForcePlayerDrop()

            local noCollide = constraint.NoCollide( thing, game.GetWorld(), 0, 0, true )
            newWeld:DeleteOnRemove( noCollide )
            hook.Run( "prop_sharpness_createweld", newWeld, "fakefrozen" )
            if debugging then
                print( "SHARPNESS: made fakefreezing world weld" )

            end

            thingsObj:SetVelocity( vec_zero )

        else
            time = 0 -- freeze now
            if debugging then
                print( "SHARPNESS: froze sharp obj" )

            end
        end

        timer.Simple( time, function()
            if not IsValid( thing ) then return end
            if not IsValid( thingsObj ) then return end -- might happen 
            if time ~= 0 and thingsObj:GetVelocity():Length() > 15 then return end -- dont break whatever is making this move
            if wasWeld and not IsValid( newWeld ) then return end -- weld broke

            thing.sharpness_FrozenStuck = true
            thingsObj:EnableMotion( false )
            SafeRemoveEntity( newWeld )

        end )
    elseif weld then
        local newWeld = constraint.Weld( thing, into, 0, 0, strength, false )
        if not IsValid( newWeld ) then return end

        thing:ForcePlayerDrop()
        into:ForcePlayerDrop()

        local noCollide = constraint.NoCollide( thing, into, 0, 0, true )
        newWeld:DeleteOnRemove( noCollide )

        hook.Run( "prop_sharpness_createweld", newWeld, "prop" )
        if debugging then
            print( "SHARPNESS: made prop weld" )

        end
        timer.Simple( 0, function()
            if not IsValid( thingsObj ) then return end
            if not IsValid( intoObj ) then return end

            thingsObj:SetVelocity( intoObj:GetVelocity() )

        end )
    end

    if nudgeUs then
        thing:SetPos( thing:GetPos() + dir * nudgeSize )

    end
    if nudgeThem then
        into:SetPos( into:GetPos() + -dir * nudgeSize )

    end
end

hook.Add( "GravGunPickupAllowed", "sharpness_unfreezestuck", function( ply, ent )
    if not ent.sharpness_FrozenStuck then return end
    local entsObj = entsMeta.GetPhysicsObject( ent )
    if not IsValid( entsObj ) then return end
    if entsObj:IsMotionEnabled() then ent.sharpness_FrozenStuck = nil return end

    if not ply:KeyPressed( IN_ATTACK2 ) then return end
    entsObj:EnableMotion( true )
    ent.sharpness_FrozenStuck = nil
    ent.sharpness_NextDealDamage = CurTime() + 0.5

end )

hook.Add( "OnPhysgunPickup", "sharpness_clearstuck", function( ply, ent )
    if not ent.sharpness_FrozenStuck then return end
    ent.sharpness_FrozenStuck = nil
    ent.sharpness_NextDealDamage = CurTime() + 0.5

end )


local function manageThrownSharpThing( thrower, thrown, throwType ) -- GIVE CORRECT ATTACKER
    local thrownsObj = entsMeta.GetPhysicsObject( thrown )
    if not IsValid( thrownsObj ) then return end
    if not thrownsObj:IsMotionEnabled() then return end

    thrown.sharpness_ThrowType = throwType
    thrown.sharpness_Thrower = thrower
    thrown.sharpness_ThrowFriction = 5

    local timerName  = "prop_sharpness_thrownattacker_" .. thrown:GetCreationID()

    local function stopThrow()
        timer.Remove( timerName )
        if not IsValid( thrown ) then return end

        thrown.sharpness_Thrower = nil
        thrown.sharpness_ThrowType = nil
        thrown.sharpness_ThrowFriction = nil

    end

    timer.Create( timerName, 1, 0, function()
        if not IsValid( thrown ) then stopThrow() return end
        if not IsValid( thrownsObj ) then stopThrow() return end
        if not thrownsObj:IsMotionEnabled() then stopThrow() return end
        if thrownsObj:GetVelocity():Length() <= 5 then
            thrown.sharpness_ThrowFriction = ( thrown.sharpness_ThrowFriction or 0 ) + -1
            if thrown.sharpness_ThrowFriction <= 0 then
                stopThrow()
                return

            end
        end
    end )
end

-- ALWAYS MAKE THE ATTACKER THE THROWER
hook.Add( "EntityTakeDamage", "prop_sharpness_alwayscorrectattacker", function( _victim, dmg )
    local inflictor = dmg:GetInflictor()
    if not IsValid( inflictor ) then return end
    if not inflictor.IsSharp then return end
    if not IsValid( inflictor.sharpness_Thrower ) then return end

    dmg:SetAttacker( inflictor.sharpness_Thrower )

end )

hook.Add( "PhysgunPickup", "prop_sharpness", function( picker, picked )
    if not picked.IsSharp then return end
    picked.sharpness_PhysgunHolder = picker
    picked.sharpness_Holder = picker

end )
hook.Add( "PhysgunDrop", "prop_sharpness", function( picker, picked )
    if not picked.IsSharp then return end
    picked.sharpness_PhysgunHolder = nil
    picked.sharpness_Holder = nil
    manageThrownSharpThing( picker, picked, "physgun" )

end )

hook.Add( "GravGunOnPickedUp", "prop_sharpness", function( picker, picked )
    if not picked.IsSharp then return end
    picked.sharpness_Holder = picker

end )
hook.Add( "GravGunOnDropped", "prop_sharpness", function( dropper, picked )
    if not picked.IsSharp then return end
    picked.sharpness_Holder = nil
    manageThrownSharpThing( dropper, picked, "gravgun" )

end )
hook.Add( "GravGunPunt", "prop_sharpness", function( punter, punted )
    if not punted.IsSharp then return end
    punted.sharpness_Holder = nil
    manageThrownSharpThing( punter, punted, "gravgun" )

end )

hook.Add( "OnPlayerPhysicsPickup", "prop_sharpness", function( _, picked )
    if not picked.IsSharp then return end
    picked.sharpness_Holder = picker

end )
hook.Add( "OnPlayerPhysicsDrop", "prop_sharpness", function( dropper, dropped, thrown )
    if not dropped.IsSharp then return end
    dropped.sharpness_Holder = nil
    manageThrownSharpThing( dropper, dropped, "use" )

end )