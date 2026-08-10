CAI.Config = CAI.Config or {}
local C = CAI.Config

CAI.STATE = {
    IDLE = 0,
    PATROL = 1,
    ENGAGE = 2,
    COVER = 3,
    FLANK = 4,
    SUPPRESS = 5,
    SEARCH = 6,
    RETREAT = 7,
    INVESTIGATE = 8,
    REGROUP = 9,
}

CAI.STATE_NAMES = {}
for k, v in pairs(CAI.STATE) do CAI.STATE_NAMES[v] = k end

CAI.ROLE = {
    LEADER = 1,
    SUPPRESSOR = 2,
    FLANKER = 3,
    SUPPORT = 4,
    BREACHER = 5,
    REAR = 6,
    GRENADIER = 7,
}
CAI.ROLE_NAMES = {}
for k, v in pairs(CAI.ROLE) do CAI.ROLE_NAMES[v] = k end

C.NPCClasses = {
    ["npc_combine_s"] = { faction = "combine" },
    ["npc_metropolice"] = { faction = "combine" },
    ["npc_citizen"] = { faction = "resistance" },
    ["npc_alyx"] = { faction = "resistance" },
    ["npc_barney"] = { faction = "resistance" },
    ["npc_monk"] = { faction = "resistance" },
    ["npc_eli"] = { faction = "resistance" },
    ["npc_kleiner"] = { faction = "resistance" },
    ["npc_magnusson"] = { faction = "resistance" },
    ["npc_mossman"] = { faction = "resistance" },
    ["npc_fisherman"] = { faction = "resistance" },
    ["npc_odessa"] = { faction = "resistance" },
    ["npc_breen"] = { faction = "resistance" },
    ["npc_gman"] = { faction = "resistance" },
    ["npc_hunter"] = { faction = "combine", noCover = true, lightTouch = true },
}

function CAI.RegisterNPCClass(class, tbl)
    C.NPCClasses[class] = tbl or { faction = "custom" }
end

C.LOD = {

    { dist = 1500, interval = 0.15 },
    { dist = 3500, interval = 0.40 },
    { dist = 6000, interval = 1.00 },
    { dist = math.huge, interval = 3.0 },
}
C.MaxBrainThinksPerTick = 12
C.ManagerTickRate = 0.05

C.Cover = {
    SearchRadius = 1200,
    MinEnemyDist = 250,
    IdealEnemyDist = 900,
    AllyCrowdDist = 110,
    CacheLifetime = 8,
    CompromiseTime = 1.6,
    Weights = {
        distSelf = 1.0,
        distEnemy = 1.2,
        losBlocked = 3.0,
        crowding = 1.5,
        danger = 2.5,
        flankRisk = 1.2,
        history = 1.0,
    },
}

C.Memory = {
    EnemyTTL = 45,
    SoundTTL = 20,
    DangerTTL = 30,
    FadeTick = 2,
}

C.Morale = {
    Start = 75,
    Min = 0,
    Max = 100,
    AllyDeathNear = -18, AllyDeathRadius = 700,
    LowHealth = -15,
    OutOfAmmoClip = -6,
    KillConfirm = 12,
    Outnumbered = -10,
    Reinforced = 8,
    Explosion = -12, ExplosionRadius = 500,
    RegenPerTick = 1.5,
    BreakThreshold = 25,
    ShakenThreshold = 45,
}

C.Suppression = {
    Radius = 140,
    PerBullet = 9,
    Explosion = 45,
    Decay = 14,
    Max = 100,
    PinnedAt = 55,
    PanicAt = 85,
    AccuracyPenaltySteps = { [30] = 1, [60] = 2, [85] = 3 },
}

C.WeaponPatterns = {
    { pattern = "shotgun", archetype = "shotgun" },
    { pattern = "sniper", archetype = "sniper" }, { pattern = "awp", archetype = "sniper" },
    { pattern = "crossbow", archetype = "sniper" },
    { pattern = "m249", archetype = "lmg" }, { pattern = "lmg", archetype = "lmg" },
    { pattern = "mg42", archetype = "lmg" }, { pattern = "minigun", archetype = "lmg" },
    { pattern = "rpg", archetype = "rocket" }, { pattern = "rocket", archetype = "rocket" },
    { pattern = "launcher", archetype = "rocket" }, { pattern = "grenade", archetype = "rocket" },
    { pattern = "smg", archetype = "smg" }, { pattern = "mp5", archetype = "smg" },
    { pattern = "mac10", archetype = "smg" }, { pattern = "uzi", archetype = "smg" },
    { pattern = "pistol", archetype = "pistol" }, { pattern = "357", archetype = "pistol" },
    { pattern = "deagle", archetype = "pistol" }, { pattern = "revolver", archetype = "pistol" },
}

C.WeaponResponses = {
    shotgun = { idealDist = 1100, aggression = -0.3, keepDistance = true },
    sniper = { idealDist = 500, aggression = -0.2, stayHidden = true },
    lmg = { idealDist = 900, aggression = -0.25, avoidExposure = true },
    rocket = { idealDist = 1200, aggression = -0.4, scatter = true },
    smg = { idealDist = 350, aggression = 0.35 },
    pistol = { idealDist = 400, aggression = 0.45 },
    rifle = { idealDist = 700, aggression = 0.0 },
}

C.SoundPatterns = {
    { pattern = "footstep", type = "footstep", radius = 450 },
    { pattern = "doors/", type = "door", radius = 900 },
    { pattern = "glass", type = "glass", radius = 1100 },
    { pattern = "reload", type = "reload", radius = 600 },
    { pattern = "clipin", type = "reload", radius = 600 },
    { pattern = "explode", type = "explosion", radius = 2500 },
    { pattern = "explosion", type = "explosion", radius = 2500 },
    { pattern = "physics", type = "physics", radius = 550 },
    { pattern = "weapons/", type = "gunshot", radius = 2000 },
}
C.SuppressedGunshotMult = 0.35

C.Search = {
    MaxPoints = 6,
    PointRadius = 900,
    DwellTime = 2.2,
    GiveUpAfter = 55,
    VerticalBonus = 1.4,
}

C.Formations = {
    LINE = { {0,-90}, {0,90}, {0,-180}, {0,180}, {0,-270}, {0,270} },
    WEDGE = { {-80,-80}, {-80,80}, {-160,-160}, {-160,160}, {-240,0} },
    DIAMOND = { {-100,-100}, {-100,100}, {-200,0}, {100,0}, {-300,0} },
    FILE = { {-90,0}, {-180,0}, {-270,0}, {-360,0}, {-450,0} },
    STACK = { {-45,35}, {-90,-35}, {-135,35}, {-180,-35}, {-225,35} },
    CIRCLE = { {120,0}, {-120,0}, {0,120}, {0,-120}, {85,85} },
}

C.Voice = {
    BasePath = "combat_intelligence_ai/",

    Events = {
        enemy_spotted = "enemy_spotted",
        taking_fire = "taking_fire",
        reload = "reload",
        grenade = "grenade",
        retreat = "retreat",
        cover_me = "cover_me",
        flanking = "flanking",
        breach = "breach",
        clear = "clear",
        idle = "idle",
        panic = "panic",
        victory = "victory",
        death = "death",
        hurt = "hurt",
        suppressing = "suppressing",
        moving = "moving",
        searching = "searching",
        enemy_lost = "enemy_lost",
        need_backup = "need_backup",
    },
    SquadCooldown = 1.2,

    Defaults = {
    combine = {
        enemy_spotted = {
            "npc/combine_soldier/vo/contact.ogg",
            "npc/combine_soldier/vo/contactconfim.ogg",
            "npc/combine_soldier/vo/contactconfirmprosecuting.ogg",
            "npc/combine_soldier/vo/callcontacttarget1.ogg",
            "npc/combine_soldier/vo/targetone.ogg",
            "npc/combine_soldier/vo/viscon.ogg",
            "npc/combine_soldier/vo/goactiveintercept.ogg",
        },
        taking_fire = {
            "npc/combine_soldier/vo/cover.ogg",
            "npc/combine_soldier/vo/coverhurt.ogg",
            "npc/combine_soldier/vo/heavyresistance.ogg",
            "npc/combine_soldier/vo/hardenthatposition.ogg",
        },
        reload = {
            "npc/combine_soldier/vo/coverme.ogg",
            "npc/combine_soldier/vo/displace.ogg",
        },
        grenade = {
            "npc/combine_soldier/vo/bouncerbouncer.ogg",
            "npc/combine_soldier/vo/ripcordripcord.ogg",
        },
        retreat = {
            "npc/combine_soldier/vo/displace.ogg",
            "npc/combine_soldier/vo/displace2.ogg",
            "npc/combine_soldier/vo/prison_soldier_fallback_b4.ogg",
        },
        cover_me = {
            "npc/combine_soldier/vo/coverme.ogg",
        },
        flanking = {
            "npc/combine_soldier/vo/closing.ogg",
            "npc/combine_soldier/vo/closing2.ogg",
            "npc/combine_soldier/vo/unitismovingin.ogg",
            "npc/combine_soldier/vo/fixsightlinesmovein.ogg",
            "npc/combine_soldier/vo/sweepingin.ogg",
        },
        breach = {
            "npc/combine_soldier/vo/gosharp.ogg",
            "npc/combine_soldier/vo/gosharpgosharp.ogg",
            "npc/combine_soldier/vo/movein.ogg",
        },
        clear = {
            "npc/combine_soldier/vo/reportingclear.ogg",
            "npc/combine_soldier/vo/reportallpositionsclear.ogg",
            "npc/combine_soldier/vo/sightlineisclear.ogg",
            "npc/combine_soldier/vo/sectorissecurenovison.ogg",
            "npc/combine_soldier/vo/cleaned.ogg",
        },
        idle = {
            "npc/combine_soldier/vo/stayalert.ogg",
            "npc/combine_soldier/vo/stayalertreportsightlines.ogg",
            "npc/combine_soldier/vo/reportallradialsfree.ogg",
            "npc/combine_soldier/vo/teamdeployedandscanning.ogg",
        },
        panic = {
            "npc/combine_soldier/vo/overwatchsectoroverrun.ogg",
            "npc/combine_soldier/vo/overwatchteamisdown.ogg",
            "npc/combine_soldier/vo/isfinalteamunitbackup.ogg",
            "npc/combine_soldier/vo/heavyresistance.ogg",
        },
        victory = {
            "npc/combine_soldier/vo/onedown.ogg",
            "npc/combine_soldier/vo/flatline.ogg",
            "npc/combine_soldier/vo/affirmativewegothimnow.ogg",
            "npc/combine_soldier/vo/overwatchtarget1sterilized.ogg",
            "npc/combine_soldier/vo/thatsitwrapitup.ogg",
        },
        death = {
            "npc/combine_soldier/die1.ogg",
            "npc/combine_soldier/die2.ogg",
            "npc/combine_soldier/die3.ogg",
        },
        hurt = {
            "npc/combine_soldier/pain1.ogg",
            "npc/combine_soldier/pain2.ogg",
            "npc/combine_soldier/pain3.ogg",
            "npc/combine_soldier/vo/requestmedical.ogg",
            "npc/combine_soldier/vo/requeststimdose.ogg",
        },
        suppressing = {
            "npc/combine_soldier/vo/suppressing.ogg",
            "npc/combine_soldier/vo/hardenthatposition.ogg",
        },
        moving = {
            "npc/combine_soldier/vo/movein.ogg",
            "npc/combine_soldier/vo/unitismovingin.ogg",
            "npc/combine_soldier/vo/unitisclosing.ogg",
            "npc/combine_soldier/vo/inbound.ogg",
        },
        searching = {
            "npc/combine_soldier/vo/motioncheckallradials.ogg",
            "npc/combine_soldier/vo/sweepingin.ogg",
            "npc/combine_soldier/vo/teamdeployedandscanning.ogg",
            "npc/combine_soldier/vo/noviscon.ogg",
        },
        enemy_lost = {
            "npc/combine_soldier/vo/lostcontact.ogg",
            "npc/combine_soldier/vo/noviscon.ogg",
            "npc/combine_soldier/vo/hasnegativemovement.ogg",
            "npc/combine_soldier/vo/targetblackout.ogg",
        },
        need_backup = {
            "npc/combine_soldier/vo/overwatchrequestreinforcement.ogg",
            "npc/combine_soldier/vo/overwatchrequestreserveactivation.ogg",
            "npc/combine_soldier/vo/isfinalteamunitbackup.ogg",
        },
    },

    resistance = {
        enemy_spotted = {
            "vo/npc/male01/combine01.ogg",
            "vo/npc/male01/combine02.ogg",
            "vo/npc/male01/heretheycome01.ogg",
            "vo/npc/male01/overthere01.ogg",
            "vo/npc/male01/overthere02.ogg",
            "vo/npc/male01/behindyou01.ogg",
            "vo/npc/male01/upthere01.ogg",
            "vo/npc/male01/headsup01.ogg",
        },
        taking_fire = {
            "vo/npc/male01/takecover02.ogg",
            "vo/npc/male01/getdown02.ogg",
            "vo/npc/male01/incoming02.ogg",
            "vo/npc/male01/watchout.ogg",
        },
        reload = {
            "vo/npc/male01/gottareload01.ogg",
            "vo/npc/male01/coverwhilereload01.ogg",
            "vo/npc/male01/coverwhilereload02.ogg",
        },
        grenade = {
            "vo/npc/male01/incoming02.ogg",
            "vo/npc/male01/getdown02.ogg",
            "vo/npc/male01/headsup02.ogg",
        },
        retreat = {
            "vo/npc/male01/runforyourlife01.ogg",
            "vo/npc/male01/runforyourlife02.ogg",
            "vo/npc/male01/runforyourlife03.ogg",
            "vo/npc/male01/gethellout.ogg",
            "vo/npc/male01/strider_run.ogg",
        },
        cover_me = {
            "vo/npc/male01/coverwhilereload01.ogg",
            "vo/npc/male01/coverwhilereload02.ogg",
        },
        flanking = {
            "vo/npc/male01/squad_away01.ogg",
            "vo/npc/male01/squad_away02.ogg",
            "vo/npc/male01/squad_away03.ogg",
            "vo/npc/male01/letsgo01.ogg",
        },
        breach = {
            "vo/npc/male01/letsgo01.ogg",
            "vo/npc/male01/letsgo02.ogg",
            "vo/npc/male01/squad_follow03.ogg",
            "vo/npc/male01/okimready01.ogg",
        },
        clear = {
            "vo/npc/male01/yeah02.ogg",
            "vo/npc/male01/nice.ogg",
            "vo/npc/male01/fantastic01.ogg",
            "vo/npc/male01/finally.ogg",
        },
        idle = {
            "vo/npc/male01/question01.ogg",
            "vo/npc/male01/question03.ogg",
            "vo/npc/male01/question05.ogg",
            "vo/npc/male01/question07.ogg",
            "vo/npc/male01/question11.ogg",
            "vo/npc/male01/question12.ogg",
            "vo/npc/male01/question20.ogg",
            "vo/npc/male01/question21.ogg",
            "vo/npc/male01/question23.ogg",
            "vo/npc/male01/question26.ogg",
            "vo/npc/male01/question28.ogg",
            "vo/npc/male01/waitingsomebody.ogg",
            "vo/npc/male01/doingsomething.ogg",
        },
        panic = {
            "vo/npc/male01/ohno.ogg",
            "vo/npc/male01/goodgod.ogg",
            "vo/npc/male01/uhoh.ogg",
            "vo/npc/male01/no01.ogg",
            "vo/npc/male01/help01.ogg",
        },
        victory = {
            "vo/npc/male01/gotone01.ogg",
            "vo/npc/male01/gotone02.ogg",
            "vo/npc/male01/nice.ogg",
            "vo/npc/male01/yeah02.ogg",
            "vo/npc/male01/likethat.ogg",
        },
        death = {
            "vo/npc/male01/pain07.ogg",
            "vo/npc/male01/pain08.ogg",
            "vo/npc/male01/pain09.ogg",
        },
        hurt = {
            "vo/npc/male01/imhurt01.ogg",
            "vo/npc/male01/imhurt02.ogg",
            "vo/npc/male01/ow01.ogg",
            "vo/npc/male01/ow02.ogg",
            "vo/npc/male01/pain01.ogg",
            "vo/npc/male01/pain03.ogg",
            "vo/npc/male01/pain05.ogg",
            "vo/npc/male01/myarm01.ogg",
            "vo/npc/male01/myleg01.ogg",
            "vo/npc/male01/hitingut01.ogg",
        },
        suppressing = {
            "vo/npc/male01/evenodds.ogg",
            "vo/npc/male01/likethat.ogg",
        },
        moving = {
            "vo/npc/male01/letsgo01.ogg",
            "vo/npc/male01/letsgo02.ogg",
            "vo/npc/male01/squad_approach02.ogg",
            "vo/npc/male01/squad_approach03.ogg",
            "vo/npc/male01/squad_approach04.ogg",
        },
        searching = {
            "vo/npc/male01/overhere01.ogg",
            "vo/npc/male01/upthere01.ogg",
            "vo/npc/male01/upthere02.ogg",
            "vo/npc/male01/uhoh.ogg",
        },
        enemy_lost = {
            "vo/npc/male01/uhoh.ogg",
            "vo/npc/male01/whoops01.ogg",
        },
        need_backup = {
            "vo/npc/male01/help01.ogg",
            "vo/npc/male01/overhere01.ogg",
        },
    },
    },

    Chatter = {
        idle = { npcGap = 20, squadGap = 8 },
        cover_me = { npcGap = 14, squadGap = 6 },
        moving = { npcGap = 12, squadGap = 5 },
        searching = { npcGap = 10, squadGap = 5 },
        suppressing = { npcGap = 10, squadGap = 5 },
    },

    RadioOffClicks = {
        "npc/combine_soldier/vo/off1.ogg",
        "npc/combine_soldier/vo/off2.ogg",
        "npc/combine_soldier/vo/off3.ogg",
    },
}

C.Plan = {
    Interval = 3.5,
    FlankMinMembers = 3,
    RetreatMoraleAvg = 30,
    PushAdvantage = 1.6,
}
