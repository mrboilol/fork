
local entsMeta = FindMetaTable( "Entity" )
local PROP_SHARPNESS = PROP_SHARPNESS

local models = {
    ["models/props_junk/sawblade001a.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.sawbladeSliceSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        canSlice = true,

    },
    ["models/props_c17/trappropeller_blade.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetForward,
        invertDir = nil,
        localPos = Vector( 9.5, -40, 4 ),
        localPosDist = 55,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.sawbladeSliceSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,
        canSlice = true,

    },
    ["models/props_junk/meathook001a.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        localPos = Vector( 0, -7.8, -12.2 ),
        localPosDist = 15,
        startSpeed = PROP_SHARPNESS.SPEED_SUPERSHARP,
        sharpness = PROP_SHARPNESS.SHARPNESS_SUPERSHARP,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,

    },
    ["models/props_c17/pulleyhook01.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        localPos = Vector( -0.3, -13.1, 10.7 ),
        localPosDist = 15,
        startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
        sharpness = PROP_SHARPNESS.SHARPNESS_DULL,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,

    },
    ["models/weapons/w_crowbar.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetForward,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_SUPERSHARP,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,

    },
    ["models/weapons/w_spade.mdl"] = { -- spade'n
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = true,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_SHARP,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        canSlice = true,

    },
    ["models/props_junk/shovel01a.mdl"] = { -- shovl'n
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = true,
        startSpeed = PROP_SHARPNESS.SPEED_DULL,
        sharpness = PROP_SHARPNESS.SHARPNESS_DULL,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        canSlice = true,

    },
    ["models/props_junk/harpoon002a.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetForward,
        invertDir = nil,
        localPos = Vector( 50, 0, 0 ),
        localPosDist = 25,
        startSpeed = PROP_SHARPNESS.SPEED_SUPERSHARP,
        sharpness = PROP_SHARPNESS.SHARPNESS_SUPERSHARP,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,

    },

    ["models/mechanics/wheels/wheel_spike_24.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

    },
    ["models/mechanics/wheels/wheel_spike_48.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_ALWAYSDMG,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

    },

    ["models/props_phx/mechanics/medgear.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.bashingSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

    },
    ["models/props_phx/mechanics/biggear.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_PLANAR,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.bashingSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

    },

    ["models/props_c17/signpole001.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_DUALPOINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,

    },

    ["models/props_citizen_tech/till001a_base01.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_DUALPOINTY,
        dirFunc = entsMeta.GetRight,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,

    },

    ["models/props_c17/metalladder001.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_DUALPOINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.bashingSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

    },
    ["models/props_c17/metalladder002.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_DUALPOINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.bashingSound,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

    },

    ["models/combine_turrets/floor_turret.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = true,
        startSpeed = PROP_SHARPNESS.SPEED_CRUSH,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_MEDIUM,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,

    },



    ["models/props_c17/chair02a.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/nova/chair_plastic01.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/props_interiors/furniture_chair03a.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/props_interiors/furniture_chair01a.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/nova/chair_wood01.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,

    ["models/props_wasteland/prison_throwswitchlever001.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/props_trainstation/trainstation_arch001.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE, -- GUILLOTINE

    ["models/props_c17/furnituretable001a.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/props_c17/furnituretable002a.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/props_c17/furnituretable003a.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,
    ["models/props_c17/furnituredrawer002a.mdl"] = PROP_SHARPNESS.generic_IMPALING_DULL_DOWNWARD_SPIKE,

    ["models/props_c17/trappropeller_lever.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetRight,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

    },

    ["models/hunter/misc/cone1x1.mdl"] = PROP_SHARPNESS.generic_DULL_UPWARD_SPIKE,
    ["models/hunter/misc/cone2x2.mdl"] = PROP_SHARPNESS.generic_DULL_UPWARD_SPIKE,

    ["models/hunter/misc/squarecap1x1x1.mdl"] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    ["models/hunter/misc/squarecap2x1x1.mdl"] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    ["models/hunter/misc/squarecap2x1x2.mdl"] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    ["models/hunter/misc/squarecap2x2x2.mdl"] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    ["models/hunter/misc/cone1x05.mdl"] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    ["models/hunter/misc/cone2x1.mdl"] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    ["models/hunter/misc/cone4x2.mdl"] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    ["models/hunter/misc/cone4x2mirrored.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_DUALPOINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = nil,
        startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_WEAK,

    },

    ["models/props_c17/utilitypole01a.mdl"] = PROP_SHARPNESS.generic_IMPALING_BASHING_DOWNWARD,
    ["models/props_c17/utilitypole01b.mdl"] = PROP_SHARPNESS.generic_IMPALING_BASHING_DOWNWARD,
    ["models/props_c17/utilitypole01d.mdl"] = PROP_SHARPNESS.generic_IMPALING_BASHING_DOWNWARD,
    ["models/props_c17/utilitypole02b.mdl"] = PROP_SHARPNESS.generic_IMPALING_BASHING_DOWNWARD,
    ["models/props_c17/utilitypole03a.mdl"] = PROP_SHARPNESS.generic_IMPALING_BASHING_DOWNWARD,


    -- reeebar
    ["models/props_debris/rebar001a_32.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar001b_48.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar001c_64.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar001d_96.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar002a_32.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar002b_48.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar002c_64.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar002d_96.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar003a_32.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar003b_48.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar003c_64.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar004a_32.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar004b_48.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar004c_64.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar004d_96.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar_cluster001a.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar_cluster001b.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar_cluster002a.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar_cluster002b.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar_medthin01a.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_REBAR,
    ["models/props_debris/rebar_medthin02a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_DUALSHARP_REBAR, entsMeta.GetForward, nil ),
    -- skipping curved ones :(
    ["models/props_debris/rebar_medthin02a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_DUALSHARP_REBAR, entsMeta.GetForward, nil ),


    -- beems
    ["models/props_junk/ibeam01a.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/props_junk/ibeam01a_cluster01.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/box_beam_16.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/box_beam_24.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/box_beam_32.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/box_beam_48.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam_16.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam_32.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam_48.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam_64.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam_96.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam_16_2d.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam2_16.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam2_32.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam2_48.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam2_60.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam2_96.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/i_beam_8.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/l-beam__24.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/l-beam__32.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/l-beam__48.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/u_beam_16.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/u_beam_24.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/u_beam_32.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    ["models/mechanics/solid_steel/u_beam_48.mdl"] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,


    -- board gibs
    ["models/props_debris/wood_chunk01b.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, -- up
    ["models/props_debris/wood_chunk01a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ), -- down
    ["models/props_debris/wood_chunk01c.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk01d.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk01e.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk01f.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,

    -- skipped chunk02

    ["models/props_debris/wood_chunk03a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk03b.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk03c.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk03d.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk03e.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk03f.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,

    ["models/props_debris/wood_chunk04b.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk04e.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,

    ["models/props_debris/wood_chunk05a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk05b.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk05c.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk05d.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk05e.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk05f.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,

    ["models/props_debris/wood_chunk06a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk06b.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk06d.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk06e.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk06f.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,

    ["models/props_debris/wood_chunk07a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk07b.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk07c.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk07d.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk07e.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk07f.mdl"] = PROP_SHARPNESS.generic_DUALSHARP_WOODSPLINTERS,

    ["models/props_debris/wood_chunk08b.mdl"] = PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS,
    ["models/props_debris/wood_chunk08d.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk08e.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),
    ["models/props_debris/wood_chunk08f.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetUp, true ),

    ["models/gibs/wood_gib01a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_DUALSHARP_WOODSPLINTERS, entsMeta.GetForward, nil ), -- forward duelsharp
    ["models/gibs/wood_gib01b.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetForward, nil ), -- forward
    ["models/gibs/wood_gib01c.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetForward, nil ),
    ["models/gibs/wood_gib01d.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetForward, true ), -- back
    ["models/gibs/wood_gib01e.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_DUALSHARP_WOODSPLINTERS, entsMeta.GetForward, nil ),

    ["models/props_wasteland/dockplank01a.mdl"] = PROP_SHARPNESS.sharpDataWithDirection( PROP_SHARPNESS.generic_UPSHARP_WOODSPLINTERS, entsMeta.GetRight, nil ), -- right

    ["models/props_trainstation/tracksign03.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = true,
        startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        localPos = Vector( 0, 0, -53.1 ),
        localPosDist = 25,

    },
    ["models/props_trainstation/tracksign07.mdl"] = {
        typeTransformer = PROP_SHARPNESS.SHARP_POINTY,
        dirFunc = entsMeta.GetUp,
        invertDir = true,
        startSpeed = PROP_SHARPNESS.SPEED_BLUNT,
        sharpness = PROP_SHARPNESS.SHARPNESS_BLUNT,
        dmgSounds = PROP_SHARPNESS.skewerSnd,
        impaleStrength = PROP_SHARPNESS.IMPALE_STRONG,
        sticks = true,
        stickSounds = PROP_SHARPNESS.metalstickSounds,
        localPos = Vector( 0, 0, -53.1 ),
        localPosDist = 45,

    },

    ["models/props_citizen_tech/windmill_blade002a.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_CRUSHCUTTER,

    ["models/xqm/helicopterrotor.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER, -- mix of blunt/crush for sandbox server balance
    ["models/xqm/helicopterrotormedium.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER,
    ["models/xqm/helicopterrotorbig.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER,
    ["models/xqm/helicopterrotorhuge.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_CRUSHCUTTER,
    ["models/xqm/helicopterrotorlarge.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_CRUSHCUTTER,
    ["models/xqm/jetenginepropeller.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER,
    ["models/xqm/jetenginepropellermedium.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER,
    ["models/xqm/jetenginepropellerbig.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER,
    ["models/xqm/jetenginepropellerhuge.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_BLUNTCUTTER,
    ["models/xqm/jetenginepropellerlarge.mdl"] = PROP_SHARPNESS.generic_PLANARFORW_CRUSHCUTTER,

    --[[
    [""] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    [""] = PROP_SHARPNESS.generic_DUALBASH_IBEAM,
    [""] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    [""] = PROP_SHARPNESS.generic_BLUNT_UPWARD_SPIKE,
    --]]

}

PROP_SHARPNESS.AddModels( models )
