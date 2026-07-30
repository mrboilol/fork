
local entsMeta = FindMetaTable( "Entity" )

local models = {
    ["models/props_forest/circularsaw01.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = true,
        localPos = Vector( 3, 0, 1 ),
        localPosDist = 10,
        startSpeed = PROP_SHARPNESS.SPEED_SUPERSHARP,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        maxDamage = 50,
        dmgSounds = PROP_SHARPNESS.sawbladeSliceSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,
        canSlice = true,

    },

    ["models/props_mining/railroad_spike01.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetForward,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_DULL,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,
        canSlice = true,

    },
}

PROP_SHARPNESS.AddModels( models )
