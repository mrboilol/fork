
local entsMeta = FindMetaTable( "Entity" )

local models = {
    ["models/lostcoast/fisherman/harpoon.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetUp,
        localPos = Vector( 10, 5, 7 ),
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        canSlice = false,

    },

    ["models/lostcoast/props_monastery/candlestick.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetUp,
        localPos = Vector( -23, -41, -31 ),
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.bashingSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,
        sticks = false,
        canSlice = false,

    },
}

PROP_SHARPNESS.AddModels( models )
