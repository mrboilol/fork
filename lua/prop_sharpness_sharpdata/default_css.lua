
local entsMeta = FindMetaTable( "Entity" )

local models = {
    ["models/props/cs_militia/circularsaw01.mdl"] = {
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
    ["models/props/de_inferno/railingspikedgate.mdl"] = PROP_SHARPNESS.generic_SHARP_UPWARD_SPIKE,
    ["models/props/de_inferno/railingspiked.mdl"] = PROP_SHARPNESS.generic_SHARP_UPWARD_SPIKE
}

PROP_SHARPNESS.AddModels( models )
