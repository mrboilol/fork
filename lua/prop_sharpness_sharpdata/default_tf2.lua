
local entsMeta = FindMetaTable( "Entity" )

local bonesaw = table.Copy( PROP_SHARPNESS.generic_SHARP_UPWARD_SPIKE )
bonesaw.dirFunc = entsMeta.GetForward

local models = {
    ["models/props_forest/saw_blade.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetRight,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.sawbladeSliceSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        canSlice = true,

    },
    ["models/props_forest/saw_blade_large.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetRight,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.sawbladeSliceSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        canSlice = true,

    },
    ["models/props_forest/sawblade_moving.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetRight,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.sawbladeSliceSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        canSlice = true,

    },
    ["models/props_swamp/chainsaw.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetRight,
        invertDir = nil,
        localPos = Vector( 25, -4, -3 ),
        localPosDist = 25,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.sawbladeSliceSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        canSlice = true,

    },

    ["models/weapons/w_models/w_bonesaw.mdl"] = bonesaw,
    ["models/weapons/w_models/c_bonesaw.mdl"] = bonesaw,
    ["models/weapons/c_models/c_bonesaw/c_bonesaw_xmas.mdl"] = bonesaw,
    ["models/weapons/c_models/c_ubersaw/c_ubersaw.mdl"] = bonesaw,
    ["models/weapons/c_models/c_ubersaw/c_ubersaw_xmas.mdl"] = bonesaw,

    ["models/props_medieval/fort_wall.mdl"] = PROP_SHARPNESS.generic_SHARP_UPWARD_SPIKE,
    ["models/props_medieval/fort_wall_short.mdl"] = PROP_SHARPNESS.generic_SHARP_UPWARD_SPIKE,
    ["models/props_medieval/portcullis.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/props_medieval/portcullis_small.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,

    ["models/weapons/w_models/w_knife.mdl"] = PROP_SHARPNESS.generic_SUPERSHARP_UPWARD_SPIKE,
    ["models/weapons/w_models/w_shovel.mdl"] = PROP_SHARPNESS.sharpDataWithAppended( PROP_SHARPNESS.generic_SUPERSHARP_UPWARD_SPIKE, {
        startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,
    } ),

}

PROP_SHARPNESS.AddModels( models )
