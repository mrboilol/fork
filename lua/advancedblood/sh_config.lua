-- Configuration: convars, bleeding profiles, surface categories, LOD tiers, physical constants.
-- Units: 1 game unit = 1 inch (2.54 cm). Blood volume is tracked in millilitres (ml).

local C = {}
ABL.Config = C

------------------------------------------------------------------------------------------
-- Convars
------------------------------------------------------------------------------------------
local SVFLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)

C.sv = {
	enabled      = CreateConVar("abl_enabled", "1", SVFLAGS, "AdvancedBlood master switch (server authoritative).", 0, 1),
	volume       = CreateConVar("abl_volume_scale", "1", SVFLAGS, "Visual blood volume multiplier (1 = matches Z-City bleed rates).", 0.1, 4),
	drying       = CreateConVar("abl_drying_scale", "1", SVFLAGS, "Drying time multiplier (2 = blood stays wet twice as long).", 0.1, 10),
	envTemp      = CreateConVar("abl_env_temperature", "20", SVFLAGS, "Air temperature in C for the drying and setting of ground pools (20 = neutral; warmer dries and sets faster).", -20, 50),
	envHumid     = CreateConVar("abl_env_humidity", "50", SVFLAGS, "Relative humidity in % for the drying of ground pools (50 = neutral; damp air dries slower).", 0, 100),
	netHits      = CreateConVar("abl_net_hits", "1", SVFLAGS, "Send compact wound-impact events to clients.", 0, 1),
	netCollide   = CreateConVar("abl_net_collisions", "1", SVFLAGS, "Send bloody ragdoll collision events to clients.", 0, 1),
	persist      = CreateConVar("abl_persist", "1", SVFLAGS, "Track coarse pools on the server so late joiners see existing blood.", 0, 1),
	hitDecals    = CreateConVar("abl_zcity_hitdecals", "0", SVFLAGS, "Z-City's canned blood decals behind and below every bullet hit: keep them (1) or leave them out (0).", 0, 1),
	dev          = CreateConVar("abl_dev", "0", SVFLAGS, "Enable admin developer commands (abl_dev_*).", 0, 1),
}

if CLIENT then
	C.cl = {
		enabled     = CreateClientConVar("abl_cl_enabled", "1", true, false, "Client-side AdvancedBlood simulation/rendering.", 0, 1),
		newBlood    = ConVarExists("hg_old_blood") and GetConVar("hg_old_blood") or CreateClientConVar("hg_old_blood", "1", true, false, "1 = AdvancedBlood system, 0 = old Z-City blood particles and decals", 0, 1),
		quality     = CreateClientConVar("abl_quality", "3", true, false, "0 = low, 1 = medium, 2 = high, 3 = ultra, 4 = extreme.", 0, 4),
		budget      = CreateClientConVar("abl_budget_ms", "2.5", true, false, "Target CPU milliseconds per frame for the blood simulation.", 0.3, 20),
		simHz       = CreateClientConVar("abl_sim_hz", "165", true, false, "Target update rate (Hz) of high-priority blood (near, visible); lowered automatically when over abl_budget_ms.", 30, 240),
		maxDrops    = CreateClientConVar("abl_max_droplets", "420", true, false, "Hard cap: simulated droplets.", 16, 4000),
		maxBlobs    = CreateClientConVar("abl_max_blobs", "120", true, false, "Hard cap: body-surface blobs.", 8, 1000),
		maxSegs     = CreateClientConVar("abl_max_body_segments", "2400", true, false, "Hard cap: body-surface streak segments (all characters).", 64, 20000),
		maxPools    = CreateClientConVar("abl_max_pools", "56", true, false, "Hard cap: dynamic pools.", 4, 400),
		maxRunoff   = CreateClientConVar("abl_max_runoff", "72", true, false, "Hard cap: world runoff rivulets.", 4, 600),
		maxOverlays = CreateClientConVar("abl_max_overlays", "450", true, false, "Hard cap: wet-stain overlays.", 16, 4000),
		maxParts    = CreateClientConVar("abl_max_particles", "260", true, false, "Hard cap: cheap GMod particles.", 0, 3000),
		maxTraces   = CreateClientConVar("abl_max_traces", "150", true, false, "Hard cap: collision traces per frame.", 10, 2000),
		maxGround   = CreateClientConVar("abl_max_ground_stains", "320", true, false, "Hard cap: blood stains from droplets landing on the ground (oldest removed first).", 16, 4000),
		decalRate   = CreateClientConVar("abl_decals_per_sec", "60", true, false, "Hard cap: engine decals placed per second.", 1, 1000),
		drawDist    = CreateClientConVar("abl_draw_distance", "3500", true, false, "Blood effects beyond this distance are skipped.", 256, 20000),
		sounds      = CreateClientConVar("abl_sounds", "1", true, false, "Drip / splash sounds.", 0, 1),
		takeover    = CreateClientConVar("abl_zcity_takeover", "1", false, false, "In Z-City: AdvancedBlood is the only blood on screen (1), or Z-City's own blood particles and decals run next to it (0). Z-City's physiology runs either way.", 0, 1),
		fleshDecals = CreateClientConVar("abl_engine_hit_decals", "0", true, false, "The engine's own red splat decal on a body at every bullet hit: keep it (1), or clear it and show AdvancedBlood's wound alone (0).", 0, 1),
		stainScale  = CreateClientConVar("abl_stain_scale", "1", true, false, "Stain size multiplier.", 0.25, 4),
		dropScale   = CreateClientConVar("abl_drop_size", "1", true, false, "Size of airborne drops relative to their true size (1: a drop of 0.05 ml is 4.6 mm across).", 0.5, 3),
		debug       = CreateClientConVar("abl_debug", "0", false, false, "Debug overlay bitmask (see abl_debug_help).", 0, 65535),
		debugHud    = CreateClientConVar("abl_debug_hud", "0", false, false, "Show the statistics HUD.", 0, 1),
	}
end

------------------------------------------------------------------------------------------
-- Physical constants (game-scaled)
------------------------------------------------------------------------------------------
C.ML_PER_CU = 16.387            -- ml per cubic unit (1 in^3)
C.MM_PER_UNIT = 25.4
C.DEFAULT_GRAVITY = 600

-- Blood colours (sRGB 0..255, before light) of shaded liquid geometry: airborne drops, beads and
-- hanging drops on bodies. Whole blood is a deep crimson leaning slightly blue (burgundy), never a
-- bright red: red light passes, green and blue are absorbed within a fraction of a millimetre.
-- Z-City compatibility (sh_zcity.lua, client/cl_compat.lua, server/sv_compat.lua).
C.ZCity = {
	-- A headless body: Z-City keeps a "fountain" at its neck and no wound. ABL bleeds it as one
	-- arterial wound of this size, the size Z-City itself gives the stump of an amputated limb.
	stumpSize = 10,
}

C.Colors = {
	fresh   = { 100, 7, 12 },
	wet     = { 88, 6, 11 },
	aging   = { 66, 11, 11 },
	dried   = { 46, 16, 13 },
	body    = { 80, 6, 9 },       -- on skin / soaked into cloth (darker than free blood)
	-- engine decals: their textures carry the blood colour (tools/texgen), this only tints them
	decal   = { 255, 248, 248 },
}

-- Textured blood (tools/texgen) gets its colour from the textures: thickness sets it through
-- absorption, so thin films are lighter and translucent, thick layers deep and opaque. Vertex colours
-- only light and age it.
--   Filter textures (ground stains, runoff trails, settled body streaks) are multiplied over the lit
--   surface, so the surface shows through thin blood. They sit between fresh and dried blood; these
--   linear multipliers pull them either way: fresh deepens green (crimson), drying darkens red and
--   leaves green (brown).
C.Filter = {
	fresh = { 1.0, 0.72, 0.93 },
	aging = { 0.8, 0.86, 0.9 },
	dried = { 0.47, 1.0, 0.86 },
}
-- per-instance variation (venous darker, arterial brighter, dilution): multiplier range on red
C.ToneRange = { 0.86, 1.08 }

-- Venous bleed estimate (ml/s) from a Z-City wound value and pulse; see docs/ZCITY_INTEGRATION.md
C.VENOUS_K = 0.28      -- ml/s per wound point at pulse 70
C.ARTERIAL_K = 0.0563  -- ml/s per artery-size point per pulse bpm
C.POSTMORTEM_OOZE = 0.18   -- fraction of venous flow that keeps draining by gravity after death
C.POSTMORTEM_DECAY = 90    -- seconds for post-mortem drainage to fade

------------------------------------------------------------------------------------------
-- Bleeding profiles (selected by estimated flow rate; arterial wounds are always PULSED)
------------------------------------------------------------------------------------------
-- clot: small wounds bleed intermittently. A forming clot throttles the flow to `level` for
-- shut[1..2] seconds, then pressure (or movement) reopens it for open[1..2] seconds with a
-- short surge of the blood that backed up behind it.
C.Profiles = {
	minor = {
		name = "MINOR", seep = 1.0, gush = 0.0, jet = 0.0,
		beat = 0.05, noiseSigma = 0.45, noiseTau = 5.0,
		spurtRate = 0.0, spurtSpeed = 0, beadMax = 0.22, spreadCap = 0.35,
		clot = { level = 0.08, shut = { 2.5, 7 }, open = { 2, 6 } },
	},
	moderate = {
		name = "MODERATE", seep = 1.0, gush = 0.0, jet = 0.0,
		beat = 0.10, noiseSigma = 0.35, noiseTau = 4.0,
		spurtRate = 0.03, spurtSpeed = 28, beadMax = 0.3, spreadCap = 0.6,
		clot = { level = 0.4, shut = { 1.5, 4 }, open = { 4, 11 } },
	},
	severe = {
		name = "SEVERE", seep = 0.88, gush = 0.12, jet = 0.0, gushSpeed = 22,
		beat = 0.18, noiseSigma = 0.3, noiseTau = 3.0,
		spurtRate = 0.08, spurtSpeed = 40, beadMax = 0.4, spreadCap = 1.0,
	},
	high = {
		name = "HIGH-OUTPUT", seep = 0.6, gush = 0.4, jet = 0.0, gushSpeed = 38,
		beat = 0.25, noiseSigma = 0.25, noiseTau = 2.5,
		spurtRate = 0.15, spurtSpeed = 55, beadMax = 0.5, spreadCap = 1.6,
	},
	pulsed = {
		name = "PULSED", seep = 0.18, gush = 0.0, jet = 0.82, jetSpeed = 165,
		beat = 0.65, noiseSigma = 0.2, noiseTau = 2.0,
		spurtRate = 0.0, spurtSpeed = 0, beadMax = 0.5, spreadCap = 1.2,
	},
}
C.ProfileRate = { minor = 1.5, moderate = 5.0, severe = 12.0 } -- ml/s upper bounds
C.DropSize = { min = 0.3, max = 1.6 }
C.FRESH_WOUND_TIME = 3.0      -- seconds of HIGH-OUTPUT behaviour after a strong hit

-- Posture and movement. Venous pressure at a wound grows with its depth below the heart
-- (about 10 mmHg per 5.4 units of blood column), so a wound on a hanging leg bleeds harder than
-- the same wound on a raised arm. Arterial pressure is ~10x higher, so the effect is smaller.
C.HYDRO_VENOUS = 0.012        -- flow change per unit of height below (+) / above (-) the heart
C.HYDRO_ARTERIAL = 0.003
C.HYDRO_MIN, C.HYDRO_MAX = 0.4, 1.6
C.HEART_BONE = "ValveBiped.Bip01_Spine2"
C.MOVE_PUMP = 1 / 400         -- extra venous flow per u/s of limb speed (muscle pump, exertion)
C.MOVE_PUMP_MAX = 0.3

------------------------------------------------------------------------------------------
-- Surface categories. Values are relative multipliers used by impacts, runoff and pools.
--  adhesion : resistance to sliding (runoff threshold)       spread : stain size multiplier
--  absorb   : 0..1, fraction soaked in (less runoff/pooling) splash : splash tendency multiplier
--  runoff   : mobility of surface flow                        film   : pool film thickness (units)
--  dry      : drying speed multiplier (>1 dries faster)       alpha  : stain opacity
--  tint     : colour multiplier                               soak   : use fibrous soak stains
------------------------------------------------------------------------------------------
C.Surfaces = {
	default  = { adhesion = 1.0, spread = 1.0,  absorb = 0.2,  splash = 1.0,  runoff = 0.9,  film = 0.063, dry = 1.0, alpha = 0.95, tint = { 1, 1, 1 } },
	concrete = { adhesion = 1.1, spread = 1.0,  absorb = 0.25, splash = 1.0,  runoff = 0.8,  film = 0.068, dry = 1.1, alpha = 0.93, tint = { 1, 0.95, 0.95 } },
	metal    = { adhesion = 0.6, spread = 1.1,  absorb = 0.0,  splash = 1.25, runoff = 1.3,  film = 0.061, dry = 0.8, alpha = 1.0,  tint = { 1, 1, 1 } },
	wood     = { adhesion = 1.0, spread = 1.0,  absorb = 0.35, splash = 0.9,  runoff = 0.75, film = 0.068, dry = 1.1, alpha = 0.92, tint = { 0.95, 0.95, 0.95 } },
	glass    = { adhesion = 0.45, spread = 1.15, absorb = 0.0, splash = 1.35, runoff = 1.5,  film = 0.057, dry = 0.75, alpha = 0.9, tint = { 1.05, 1, 1 } },
	tile     = { adhesion = 0.55, spread = 1.1, absorb = 0.03, splash = 1.3,  runoff = 1.35, film = 0.061, dry = 0.8, alpha = 0.97, tint = { 1, 1, 1 } },
	stone    = { adhesion = 1.0, spread = 0.95, absorb = 0.2,  splash = 1.0,  runoff = 0.85, film = 0.072, dry = 1.0, alpha = 0.93, tint = { 0.95, 0.95, 0.95 } },
	plastic  = { adhesion = 0.6, spread = 1.05, absorb = 0.0,  splash = 1.2,  runoff = 1.3,  film = 0.061, dry = 0.85, alpha = 0.97, tint = { 1, 1, 1 } },
	dirt     = { adhesion = 1.7, spread = 0.8,  absorb = 0.7,  splash = 0.6,  runoff = 0.25, film = 0.2,  dry = 1.4, alpha = 0.8,  tint = { 0.7, 0.8, 0.8 }, soak = true },
	grass    = { adhesion = 1.7, spread = 0.75, absorb = 0.65, splash = 0.5,  runoff = 0.2,  film = 0.22, dry = 1.2, alpha = 0.7,  tint = { 0.8, 0.9, 0.9 }, soak = true },
	fabric   = { adhesion = 2.2, spread = 1.35, absorb = 0.92, splash = 0.35, runoff = 0.05, film = 0.3,  dry = 0.7, alpha = 0.85, tint = { 0.85, 0.9, 0.9 }, soak = true },
	flesh    = { adhesion = 1.2, spread = 1.0,  absorb = 0.1,  splash = 0.8,  runoff = 0.9,  film = 0.065, dry = 1.0, alpha = 0.95, tint = { 1, 1, 1 } },
	snow     = { adhesion = 1.5, spread = 1.2,  absorb = 0.8,  splash = 0.4,  runoff = 0.15, film = 0.25, dry = 0.3, alpha = 0.9,  tint = { 1.2, 1.1, 1.1 }, soak = true },
}

-- surfaceproperties names -> category
C.SurfaceNames = {
	concrete = "concrete", concrete_block = "concrete", plaster = "concrete", brick = "stone",
	rock = "stone", boulder = "stone", gravel = "dirt", porcelain = "tile", tile = "tile", ceramic = "tile",
	metal = "metal", metalpanel = "metal", metalgrate = "metal", metalvent = "metal", chainlink = "metal",
	metal_box = "metal", solidmetal = "metal", metal_barrel = "metal", floating_metal_barrel = "metal",
	metalvehicle = "metal", canister = "metal", paintcan = "metal", popcan = "metal", weapon = "metal",
	combine_metal = "metal", roller = "metal", slipperymetal = "metal", ladder = "metal", computer = "plastic",
	wood = "wood", wood_crate = "wood", wood_plank = "wood", wood_panel = "wood", wood_solid = "wood",
	wood_furniture = "wood", wood_box = "wood", wood_lowdensity = "wood",
	glass = "glass", glassbottle = "glass", combine_glass = "glass",
	dirt = "dirt", mud = "dirt", sand = "dirt", slipperyslime = "dirt", quicksand = "dirt", antlionsand = "dirt",
	grass = "grass", foliage = "grass",
	carpet = "fabric", cloth = "fabric", paper = "fabric", cardboard = "fabric", papercup = "fabric", mattress = "fabric",
	rubber = "plastic", rubbertire = "plastic", plastic = "plastic", plastic_box = "plastic", plastic_barrel = "plastic",
	flesh = "flesh", alienflesh = "flesh", bloodyflesh = "flesh", armorflesh = "flesh", zombieflesh = "flesh",
	snow = "snow", ice = "glass",
}

-- MAT_* fallback when the surfaceprop name is unknown
C.MatTypes = {
	[MAT_CONCRETE or 67] = "concrete", [MAT_METAL or 77] = "metal", [MAT_WOOD or 87] = "wood",
	[MAT_GLASS or 89] = "glass", [MAT_TILE or 84] = "tile", [MAT_DIRT or 68] = "dirt",
	[MAT_GRASS or 85] = "grass", [MAT_SAND or 78] = "dirt", [MAT_PLASTIC or 76] = "plastic",
	[MAT_FLESH or 70] = "flesh", [MAT_SNOW or 74] = "snow", [MAT_VENT or 86] = "metal",
	[MAT_GRATE or 71] = "metal", [MAT_COMPUTER or 80] = "plastic", [MAT_FOLIAGE or 79] = "grass",
	[MAT_SLOSH or 83] = "dirt",
}

------------------------------------------------------------------------------------------
-- LOD tiers (distance thresholds are scaled by quality and by the performance governor)
------------------------------------------------------------------------------------------
C.LOD_OFF, C.LOD_VERYFAR, C.LOD_LOW, C.LOD_MEDIUM, C.LOD_HIGH, C.LOD_ULTRA = 0, 1, 2, 3, 4, 5
C.LODNames = { [0] = "OFF", "VERYFAR", "LOW", "MEDIUM", "HIGH", "ULTRA" }
C.LODTiers = {
	-- dist: max distance for the tier; drops: per-source droplet quota
	-- hz: update rate of wound emission and droplets; flowHz: body-surface flow (0: none);
	-- runoffHz: world rivulets. The tick itself runs at abl_sim_hz (165), so ULTRA gets every tick.
	[5] = { dist = 420,  bodyflow = true,  hz = 165, flowHz = 165, runoffHz = 82, drops = 110, secondary = 1.0, satellites = 1.0, particlesOnly = false },
	[4] = { dist = 950,  bodyflow = true,  hz = 82,  flowHz = 82,  runoffHz = 41, drops = 70,  secondary = 0.55, satellites = 0.7, particlesOnly = false },
	[3] = { dist = 1700, bodyflow = false, hz = 41,  flowHz = 0,   runoffHz = 20, drops = 36,  secondary = 0.0, satellites = 0.4, particlesOnly = false },
	[2] = { dist = 3000, bodyflow = false, hz = 20,  flowHz = 0,   runoffHz = 10, drops = 12,  secondary = 0.0, satellites = 0.0, particlesOnly = true },
	[1] = { dist = 6000, bodyflow = false, hz = 12,  flowHz = 0,   runoffHz = 5,  drops = 0,   secondary = 0.0, satellites = 0.0, particlesOnly = true },
}
C.QualityScale = { [0] = 0.4, 0.6, 0.8, 1.0, 1.4 }

------------------------------------------------------------------------------------------
-- Simulation tuning
------------------------------------------------------------------------------------------
-- The tick rate targets abl_sim_hz; at low frame rates at most MAX_STEPS ticks run per frame, each
-- stretched up to MAX_TICK seconds, so blood keeps real time while the cost per frame is bounded.
C.MAX_STEPS = 8
C.MAX_TICK = 1 / 30
-- The longest frame the simulation follows in full (s): MAX_STEPS ticks of MAX_TICK cover it, so
-- blood keeps real time down to 4 frames per second. A longer frame (a stall, the game in the
-- background) is this long to the blood and no longer: it does not catch up afterwards.
C.MAX_FRAME = 0.25
-- Surface models of bodies kept (one per model and outfit, about 1.7 MB each), and how long one
-- must have gone unasked for before it may go (s).
C.MESH_KEEP = 24
C.MESH_IDLE = 60
C.DROP_TRACE_HZ = 66      -- collision look-ahead traces per droplet per second (at most)
C.DROP_LOOK_MAX = 0.12    -- s: how far ahead a drop in free flight looks once nothing is near (then ~8 traces/s)
C.DROP_BODY_HZ = 40       -- own-body hitbox tests per droplet per second while it is inside the body's bounds
C.JET_HZ = 50             -- arterial jet segments per second at most (the stream is drawn continuous)
-- A stream in the air is a thread only for so long: surface tension pinches it into drops
-- (Rayleigh: about 12 sqrt(density d^3 / surface tension) for a thread d across; 0.05 s for one
-- of 1 mm, 0.15 s for one of 2 mm). k: seconds per mm^1.5; the limits in seconds.
C.StreamBreak = { k = 0.052, min = 0.04, max = 0.3 }

-- body-surface flow
C.Body = {
	adhesion      = 0.15,   -- ml^(2/3) * (|g_t|/|g|) to overcome before a bead runs (~0.06 ml on vertical skin)
	wetAdhesion   = 0.35,   -- adhesion multiplier on already-wet skin/cloth (follows old trails)
	speed         = 3.2,    -- u/s terminal runnel speed at 1 ml on a vertical surface
	filmLoss      = 0.006,  -- ml deposited per unit travelled on dry surface
	wetFilmLoss   = 0.35,   -- multiplier on wet surface
	minVol        = 0.006,  -- blob dies below this
	pendant       = 0.045,  -- ml detach volume for a hanging drop facing straight down
	edgePendant   = 0.03,   -- ml detach volume at open mesh edges (sleeves, hems, fingertips)
	inertia       = 0.55,   -- fraction of body acceleration felt by surface blood
	flingAccel    = 5200,   -- u/s^2 normal acceleration that flings blood off regardless of volume
	trailSpacing  = 0.8,    -- units between trail points
	trailPoints   = 22,     -- max points per trail
	offset        = 0.22,   -- render offset along the surface normal
	maxPerSource  = 24,     -- beads (runnel heads, resting lenses, hanging drops) per character
	nearDist      = 520,    -- closer than this, fresh body blood is drawn as liquid geometry re-skinned every frame
	glossDist     = 240,    -- closer than this, that liquid also gets its wet reflection pass
	domeDist      = 90,     -- closer than this, beads are raised domes; beyond, flat drops (their relief is below a pixel)
	settleTime    = 6,      -- seconds after a streak segment was last fed until it lies flat as a stain
	stainOffset   = 0.07,   -- render offset of settled body stains near the camera
	holdMax       = 1.6,    -- ml a bead at a wound holds before it runs off as a separate runnel
	spreadCap     = 0.45,   -- ml a free puddle on a flat body area holds before it overflows downhill
	film          = 0.035,  -- units: thickness of blood pooled on skin / soaked into cloth (puddle footprint)
	soak          = 0.02,   -- ml/s per ml^(2/3) of a resting puddle absorbed by cloth / dried on skin
	bridge        = 0.7,    -- max gap (units) blood crosses between mesh pieces (zipper strips, clothing layers)
	contact       = 2.2,    -- units: a drop forming this close to the ground seeps under the body instead of falling
}

-- flow core (cl_flowcore.lua): blood on a body as a liquid in channels
C.Flow = {
	-- cross-section of a rivulet: a parabola, area = 2/3 width x height
	aspect     = 8,        -- width / height while its contact line is free (a contact angle near 28 degrees)
	hMax       = 0.045,    -- units: the tallest a rivulet stands (about 1.1 mm); with more blood it only widens
	wCap       = 0.3,      -- units: the widest a stream gets on a body; more blood than that stands higher (a bulge)
	hBead      = 0.12,     -- units: ... up to the height of a drop
	wSheet     = 1.0,      -- units: ... and then widens again, to a sheet no wider than this. More blood than
	                       -- fills that stands higher still: it runs over what held it back, and where the
	                       -- surface is steep it does not stay at all (it drops off)
	-- transport: mean speed u = kFlow * slope * h^2 / mu (units/s, h in units). rho g / (3.5 muInf)
	-- for blood (1060 kg/m3, 3.45 mPa s at high shear) down a vertical surface, in game units
	kFlow      = 21900,
	maxSpeed   = 10,       -- units/s: no stream on a body runs faster (about 25 cm/s)
	level      = 1.0,      -- weight of the film's own height difference where gravity presses it on
	capillary  = 1.5,      -- ... and everywhere: surface tension evens out jumps in height along a stream
	subHz      = 60,       -- liquid steps per second at least (the step of a slow frame is split, and
	                       -- split further while a fast stream crosses short cells)
	maxSub     = 8,
	farHz      = 12,       -- steps per second of bodies too far away for full body flow
	-- cost: what the flow of all characters may take per frame, as a share of abl_budget_ms. The most
	-- important character is stepped every frame, the others while there is time left (their steps
	-- get longer, their liquid is drawn between its last two states as always).
	stepShare  = 0.36,     -- share of the budget for the solver
	stepWait   = 0.25,     -- s: no character waits longer than this for its step
	nodeCost   = 1.3,      -- microseconds one node costs per step (measured; plans how many short steps fit)
	nodePx     = 4,        -- pixels between two nodes at least: streams far from the camera are laid with
	coarseMax  = 4,        -- longer stretches (up to this many times the spacing)
	-- nodes
	spacing    = 0.35,     -- units between nodes
	minSpacing = 0.2,      -- ... at least, where the path turns onto another triangle
	minCell    = 0.2,      -- units: the shortest stretch a node stands for
	maxNodes   = 260,      -- per channel
	maxNodesSrc = 900,     -- per character
	-- the head and the wound
	cutFlow    = 0.3,      -- ml/s: a wound that bleeds less than this first beads at a few points along the cut
	cutLen     = 0.22,     -- units: length of the cut the beads stand on (plus cutGrow for a large wound value)
	cutGrow    = 0.25,
	woundSoak  = 0.5,      -- ml of blood the cloth right round a wound takes up (plus woundSoakSev for a large
	woundSoakSev = 1.0,    -- wound value): the soaked patch that grows round the opening
	woundSoakShare = 0.25, -- share of what comes out of the wound that goes into it while it is not full
	rootHold   = 0.002,    -- ml that stay at the wound as its wet opening
	rootRate   = 40,       -- 1/s: how fast the wound's blood passes to the bead on it
	headFull   = 0.14,     -- ml: a head with more than this sheds the rest into the stream behind it
	headShed   = 0.6,      -- ... this share of it, at every node it lays
	shedMax    = 0.03,     -- ml at most per node (what a node of a full stream holds)
	trailVol   = 0.0016,   -- ml of thin rivulet a head leaves at every node behind it (never a gap behind the bead)
	gapDraw    = 0.6,      -- units: a gap between mesh pieces wider than this is not drawn across
	spillSpeed = 1.2,      -- units/s: how fast blood creeps away from a puddle that runs over
	meanderLen = 1.6,      -- units of path over which a rivulet's heading wanders
	meanderAmp = 0.26,     -- radians (rms) it wanders off the fall line
	respawn    = 0.02,     -- ml at the end of a headless channel that start a new head
	mergeDist  = 0.17,     -- units: a head this close to another channel joins it; so does one whose edge
	mergeMax   = 0.5,      -- touches the other stream's edge (by their drawn widths), up to this far apart
	mergeWorld = 0.6,      -- ... on walls and floors (their streams are wider apart and drawn wider)
	worldChans = 40,       -- channels kept per region of the map (the oldest dry one goes first)
	worldShare = 0.5,      -- of abl_max_flow_nodes: what dry streams on walls may keep (bodies come first)
	landDist   = 1.0,      -- units: a drop landing this close to a channel is drawn into it
	landChans  = 12,       -- streams begun by landed drops, per character; beyond that a drop goes into the
	landFar    = 2.5,      -- nearest channel within this many units, or stays a spot
	maxChans   = 28,       -- channels per character (the least of those that no longer run makes way)
	checkEvery = 0.08,     -- units travelled between two looks for another channel
	-- branches
	branchVol  = 0.02,     -- ml standing at a node (beyond what a stream leaves there) before it may break out
	branchCos  = 0.4,      -- cosine between the channel's line and the fall line below which gravity pulls blood out
	                       -- of it (about 66 degrees: a rivulet that only wanders off the fall line keeps its bed)
	branchSpeed = 3.0,     -- units/s: a surge this fast may overshoot a bend
	branchBend = 0.03,     -- 1 - cosine of the bend (about 14 degrees) it overshoots at
	branchShare = 0.35,    -- share of the blood at the node an overshoot takes
	branchChance = 0.2,    -- per look (about three a second) at a bend that qualifies
	branchRate = 10,       -- 1/s: how fast a branch draws on its parent's node
	branchMax  = 3,        -- branches per channel
	branchEvery = 5,       -- s between two branches of one channel
	branchFree = 1.2,      -- units a branch runs before it may fall back into its parent
	-- rheology
	clotTime   = 60,       -- s (times abl_drying_scale) out of the vessel until blood sets: game time, not clinical
	clotVisc   = 30,       -- steepness of the rise in viscosity toward the gel point
	shearTau   = 0.25,     -- s: how long blood remembers the shear it flowed at
	tempK      = 0.02,     -- viscosity rise per degree C of cooling (about 2 % per degree)
	warmSkin   = 4,        -- degrees C fresh blood is warmer than skin
	warmCloth  = 10,       -- ... than clothing
	coolTau    = 3,        -- s: a thin film takes this long to come to the surface's temperature
	-- surface
	narrowTau  = 2.5,      -- s: how slowly a rivulet's contact line gives way when it holds less blood
	widenTau   = 0.12,     -- s: how fast it widens when it holds more
	thinH      = 0.0025,   -- units: blood thinner than this (0.06 mm) no longer runs, it is film
	thinTau    = 4,        -- s: ... and becomes film at this pace
	absorb     = 0.006,    -- ml/s per unit^2 of cloth under the stream (times the material's absorbency)
	soakCap    = 0.06,     -- ml of blood a unit length of cloth along the stream takes up
	soakDepth  = 0.02,     -- units: how deep cloth soaks (width of the soaked band = volume / depth / length)
	filmDry    = 35,       -- s (times abl_drying_scale): time constant of a film drying to a stain
	wetTime    = 45,       -- s: how long a stretch stays wet (glossy) after blood last ran over it
	stainDry   = 90,       -- s: time constant of wet stains on walls and floors (books only)
	-- drawing
	widthGain  = 2.2,      -- drawn / simulated width of a thin trickle (skin and cloth spread it wider than a clean
	                       -- rivulet); a wide stream is drawn nearer its own width (widthWide)
	widthWide  = 1.15,
	widthRef   = 0.06,     -- units: simulated width around which the gain falls from the one to the other
	minWidth   = 0.0012,   -- units of width per unit of distance: a stream stays about 1.5 pixels wide
	lutRef     = 0.03,     -- units: the depth the lookups call 1 (0.75 mm; tools/texgen Gen.FlowDepth)
	stainRef   = 0.006,    -- units: the depth the stain lookup calls 1 (what lies on a surface is thin but dense)
	stainMax   = 0.0055,   -- units: the deepest a stain is drawn (blood in cloth scatters light: red, not black)
	bodyK      = 0.75,     -- brightness of the liquid's own colour (what blood scatters back) under the light there
	stainBody  = 0.45,     -- ... of what a stream has left (dried blood, blood in the cloth: darker, browner)
	stainRow   = 0.55,     -- how dense that own colour is for a given stain (1: as dense as liquid of that depth)
	sheenK     = 3.0,      -- brightness of the mirrored surroundings relative to the light on the body
	specK      = 0.5,      -- brightness of the key light's highlight line (stretches of it: an unbroken white line
	skyK       = 0.1,      -- down a stream is a wire), and of the line the sky above leaves
	clothDull  = 0.4,      -- absorbency from which blood on a surface no longer shines (it is in the cloth)
	ragSkin    = 0.07,     -- how uneven the margin of what a stream leaves is on skin (share of its width) ...
	ragCloth   = 0.22,     -- ... and on cloth that soaks it (blood wicks along the weave)
	specSlope  = 1.0,      -- how far across the stream a highlight moves per unit of tilt (1 / the slope of its edge)
	headGain   = 1.0,      -- drawn / simulated contact radius of the head
	headShow   = 0.25,     -- ml: the head's drawn size stops growing here
	trackK     = 0.75,     -- width of the track a head leaves, relative to the head
	bakeDist   = 160,      -- units: beyond this a channel that has stopped is drawn from baked strips while it dries
	-- detail by distance (units; the governor's LOD scale shortens them all under load)
	lineDist   = 150,      -- highlight lines along streams
	haloDist   = 400,      -- the band of cloth soaked around a stream
	viewSpeed  = 8,        -- units/s at the top of the velocity view's scale
	viewMass   = 0.02,     -- ml per node at the top of the mass view's scale
}

-- world runoff
C.Runoff = {
	adhesion     = 0.20,   -- ~0.1 ml needed to run down a vertical concrete wall
	speed        = 5.5,
	filmLoss     = 0.008,
	pendant      = 0.06,
	checkDist    = 1.4,
	trailSpacing = 1.1,
	trailPoints  = 40,
	offset       = 0.12,
	coag         = 75,     -- seconds for flowing blood to double its effective viscosity (clotting)
	forkVol      = 0.9,    -- ml above which a running rivulet may split into two fingers
	forkRate     = 0.25,   -- forks per second per ml above forkVol
	collect      = 0.6,    -- ml a stopped rivulet needs on a gentle slope to gather into a pool
}

-- pools (cl_pools.lua: simulation, cl_poolcanvas.lua: render-target canvases)
C.Pool = {
	minVolume   = 2.0,     -- ml collected in one 8-unit cell (decaying) before it becomes a pool
	minVolumeRunoff = 0.2, -- the same for blood that a stream brings (the pool begins where the stream arrives)
	minStains   = 25,      -- ground stains within minStainsR before dripped blood may become a pool
	minStainsR  = 16,
	mergeFactor = 0.9,     -- pools merge when their outlines come this close (fraction of the reach)
	attractR    = 14,
	attractMin  = 3,
	attractMax  = 6,
	attractArea = 60,
	eatFilm     = 0.02,
	overflow    = 0.05,    -- fraction of the pool per second (per unit of overshoot) running over a ledge
	sheen       = 0.9,     -- strength of the view-dependent wet reflection on fresh pools
	envStrength = 1.0,     -- brightness of the mirrored cubemap (abl_pool_envmap 1), as the map stores it. How much
	                       -- of it a pool shows is Fresnel's reflectance (2 % from above, 40 % at ten degrees),
	                       -- taking the place of that much of the blood's own colour
	envSaturation = "[0.35 0.35 0.35]",  -- how much of the mirrored surroundings' colour is kept: a low, blurred cubemap
	                       -- of a blue sky laid over dark red is violet, which no pool of blood is; what the eye
	                       -- takes from a real one is a pale sheen
	mirrorMax   = 0.14,    -- the most of the cubemap a level pool shows, however low the view (an engine limit:
	                       -- see cl_pools.lua, P.Draw)
	slopeRun    = 0.08,    -- sin(slope) above which pools feed runoff
	slopeCreep  = 0.08,    -- sin(slope) above which a wet pool stretches / pushes lobes downhill
	life        = 900,     -- seconds a dried pool stays before fading
	fade        = 25,
	dryBase     = 240,     -- seconds to dry at ~10 ml on concrete
	offset      = 0.12,    -- units above the floor (plus the traced ground relief under the canvas)
	-- field stamps per pool
	maxBlobs    = 16,      -- body, arrival lobes, feeders, necks
	maxSats     = 12,      -- satellite droplet / spatter stamps
	probeDirs   = 16,      -- directions probed for walls and ledges
	spreadTau   = 1.1,     -- s: viscous spreading time scale (grows with the radius)
	matureTau   = 2.5,     -- s: the spreading front works through the stamp's shape in about this long
	-- canvas (one render-target slot per pool, rebuilt when the pool changes)
	edgeNoise   = 0.075,   -- field units of tiled noise added before thresholding (irregular rim)
	noiseWorld  = 26,      -- units per edge-noise / mottling tile
	sheenWorld  = 40,      -- units per reflection pattern tile (abl_pool_envmap 0)
	crackWorld  = 9,       -- units per craquelure tile of old dried pools
	wetRamp     = 0.125,   -- field units over which the wet core fades into the dried margin
	maxCanvas   = 110,     -- units: largest canvas half-size
	-- colours (sRGB 0..255, before light). The rim is the thin film at the edge (drawn translucent,
	-- the floor shows through it), the body the even thick layer: wet blood is a deep burgundy-crimson,
	-- ageing darkens it, dried blood is a dark red-brown with a darker drying ring.
	palette = {
		wetFresh = { rim = { 108, 15, 18 }, body = { 80, 6, 11 } },
		wetAged  = { rim = { 106, 18, 20 }, body = { 64, 5, 9 } },
		dryFresh = { rim = { 52, 17, 14 },  body = { 72, 25, 19 } },
		dryOld   = { rim = { 46, 17, 14 },  body = { 66, 27, 21 } },
		thin     = { rim = { 116, 18, 21 }, body = { 92, 9, 13 } },     -- thin film on smooth floors
		-- a liquid pool is coloured by its depth cell by cell: from the rim colour of its state (a thin
		-- film) over the body colour (one film deep) to these (deeper than that), dried blood from
		-- dryThin over dryBody to dryDeep
		wetDeep  = { 58, 3, 7 },
		dryThin  = { 83, 45, 41 },      -- (as a filter: half the red, a quarter of the green, a fifth of the blue)
		dryBody  = { 84, 35, 23 },
		dryDeep  = { 52, 21, 15 },
	},
	rimTranslucency = 0.5,  -- page A's alpha at the outline (it rises to 1 with the layer's depth)
	rimBand     = 0,        -- ... and how far above that the blood's own colour is fully there (nothing: a band
	                        -- here shows the filter alone as a scarlet outline)
	-- what a thin layer lets through, as a multiple of its colour in linear light (red, green,
	-- blue): the colour of a thin wet film (108, 15, 18) times this is 0.85, 0.045, 0.05; a film
	-- of fresh blood passes nearly all red and a twentieth of green and blue. The thin film's own
	-- colour is dark for that reason: what makes thin blood bright on a light floor is the floor,
	-- through the filter, and on a dark floor it is dark.
	filterGain  = { 5.7, 9.4, 8.3 },
	glint       = 0.5,      -- strength of the sun's reflection on wet pools (the texture doubles it: at 0.5 the
	                        -- core is full white, the halo round it a third and less)
	-- the liquid (cl_poolsim.lua)
	sim = {
		res       = 0.25,   -- the film a cell keeps when blood runs off it, in films of the surface
		memory    = 0.35,   -- a cell that has been wet holds the contact line back this much of what a dry one does
		-- roughness: how much more than one film the roughest spots of a floor hold back
		rough     = { default = 0.9, concrete = 1.2, metal = 0.3, wood = 1.0, glass = 0.2, tile = 0.4, stone = 1.2, plastic = 0.3,
		              dirt = 1.6, grass = 1.8, fabric = 1.2, flesh = 0.6, snow = 1.0 },
		-- how much faster than on a hard floor blood sets on a surface that draws the plasma out of it
		clot      = { default = 1, fabric = 1.4, dirt = 1.3, grass = 1.2, snow = 0.8 },
		-- surface tension on the contact line: what a dry cell holds back grows by this share for a
		-- cell with nothing wet around it and falls by as much for one in a deep bay (by the wet
		-- share of the ring of 16 cells around it; 7 of them are wet along a straight front)
		tension   = 0.35,
		edge      = 0.3,    -- edge noise on the lattice's field (the outline's fine wobble, in parts of a cell)
		rim       = 0.07,   -- units: width of the band over which the rim film becomes the opaque body
		crackWorld = 12,    -- units per tile of the crack mask (plates of about 1.3 units)
		crackFrom = 0.8,    -- films of dried blood on a cell from which it cracks ...
		crackSpan = 1.0,    -- ... and over how many more the cracks reach their full width
		crackMax  = 0.8,    -- how far a crack opens at most (1: the mask's whole width)
		budget    = 0.6,    -- ms a frame for the liquid's steps at full quality (pools wait their turn beyond it)
		evap      = 0.000224, -- units of layer that dry off a wet cell per second (a film on concrete in about
		                    -- five minutes: game time, like the drying of everything else; abl_drying_scale)
		soak      = 0.55,   -- the surface takes up this much of a film, times its absorbency
		edgeDry   = 1.3,    -- films that stand at a ledge before the first blood goes over it
		edgeWet   = 0.7,    -- ... and once the edge is wet
		exitNear  = 3,      -- units downhill of where a pool formed at which a stream takes over, on a steep
		exitFar   = 10,     -- floor / on one that barely slopes (in between: 1.2 / sin of the slope)
		-- what is shown follows the liquid: a cell at the pool's edge that the blood has just reached
		-- fills in at an even pace, over as long as the edge took to cross the cell before it: this
		-- long at least (0.4-unit cells; coarser ones take longer; a cell the edge has left behind
		-- catches up three times as fast), easeMax at most; blood that lands on a dry floor grows
		-- from where it landed, each cell over easeBirth
		-- drying: a wet cell with nothing wet on any of its eight sides would dry this many times
		-- faster than one in the middle of the pool (air reaches the contact line from the side
		-- as well: the edge dries first, and the drying moves inward from it)
		edgeDrying = 2.5,
		-- the meniscus: the share of the mirror the slope at the near edge loses; the far slope's
		-- light (what it mirrors at its glancing angle, as a share of the light at the place: a
		-- thin line; more is a painted ring); how far apart (units) the layer is compared with
		-- itself to find its slope
		rimShade  = 0.8,
		rimGlow   = 0.3,
		rimReach  = 0.09,
		ease      = 0.2,
		easeMax   = 2.5,
		easeBirth = 0.9,
		morph     = 0.6,    -- s over which the picture turns into the next when the cells change size or a pool is taken in
		paintDuty = 0.0165, -- share of the time a pool in view may spend on its repaints (0.25 ms a frame at 66 fps)
	},
}

-- stains & overlays
C.Stain = {
	dryBase   = 70,        -- seconds for a small stain to dry
	cellSize  = 3,         -- decal stacking cell
	cellCap   = 5,         -- decals per cell before we stop stacking
	offset    = 0.1,
}

C.BloodMap = {
	cap    = 3000,
	maxR   = 16,
	pinWet = 0.7,
	pinDry = 0.35,
	seedK  = 0.6,
	seedMinCov = 0.35,
	pinMinR    = 6,
	pinMinArea = 250,
}

C.Smear = {
	tick       = 0.1,
	ragTick    = 0.2,
	dist       = 1500,
	stride     = 26,
	footSide   = 4.5,
	footLen    = 9,
	footW      = 3.6,
	pickup     = 1.2,
	push       = 1.5,
	pushReach  = 5,
	stainPickup = 0.25,
	maxLoad    = 3,
	minLoad    = 0.08,
	keep       = 0.7,
	printWet   = 20,
	contactH   = 7,
	dragStep   = 4,
	dragPickup = 0.8,
	dragPush   = 2.5,
	dragKeep   = 0.82,
	dragW      = 4,
}

-- ground impact stains (droplets landing on floor-like world surfaces, cl_groundstains.lua)
C.Ground = {
	-- colour: the stain filter (ground/stainfilter) aged through C.Filter; fresh -> aging at `agingK`
	-- of the drying time, dried at 1
	agingK   = 0.45,
	offset   = 0.07,             -- units above the surface (plus any bump found under the footprint)
	cellCap  = 6,                -- stains per 2.5-unit spot before new blood adds to the newest one
	rate     = 90,               -- max new ground stains per second
	tinyD    = 0.3,              -- stain diameter (units) below which a drop leaves a tiny spot
	maxHalf  = 14,               -- largest quad half-size (units)
	maxDry   = 400,              -- seconds after which a chunk's colours stop being refreshed
	drawDist = 2200,
	sheen    = 0.5,              -- what a wet stain mirrors of the light around it, times Fresnel: half of what a
	                             -- smooth liquid would (a film on a rough floor is no mirror)
	gloss    = false,
}

-- impact physics thresholds on K = sqrt(We) * Re^(1/4)
C.Impact = {
	rho = 1060, sigma = 0.058, mu = 0.0040,   -- blood (SI)
	kDeposit = 57,          -- below: smooth round deposit
	kCrown   = 160,         -- above: spines + satellites
	kBreakup = 420,         -- above: airborne secondary droplets
	maxSecondary = 7,
	maxGeneration = 2,
}

-- wound events (sh_wound.lua: what the server classifies; cl_wounds.lua: what a client derives)
C.Wound = {
	-- muzzle to skin, units (1 unit ~ 1.9 cm). No single threshold fits every weapon: these are
	-- typical handgun values, scaled by the projectile's energy class on the client
	contactDist  = 3,       -- pressed against the skin or nearly so
	nearDist     = 16,      -- soot still reaches the skin (about 30 cm)
	mediumDist   = 42,      -- unburnt powder still marks the skin (about 80 cm)
	muzzleAhead  = 22,      -- when only the shooter's eye position is known, the muzzle is this far in front of it
	maxRecords   = 64,      -- wound records kept per client (the oldest dry ones go first)
	-- conservation (cl_wounds.lua): no more blood leaves the wounds than the reservoir lost
	internalShare = 0.6,    -- of a wound's blood, how much stays in the body at internal = 1 (heart)
	muscleShare  = 0.15,    -- and how much the muscle around the track holds back at muscle = 1 (thigh)
	credit       = 30,      -- ml that may be shown before the reservoir has been seen to fall
	govPrior     = 0.55,    -- assumed loss / nominal rate of a slow bleed the reservoir never shows
	govStart     = 0.36,    -- ... of a heavy wound in its first seconds, until the first report (measured after: 0.3 to 0.7)
	govFree      = 0.8,     -- ml/s per body: bleeding below this is never throttled (Z-City makes it good, the reservoir does not show it)
	govMin       = 0.25,    -- the governor closes no further than this while blood is paid in at least that fast
	govTau       = 1.6,     -- seconds over which what is paid in is evened out (the reservoir reports in steps)
	creditTime   = 20,      -- seconds the bank is spread over when it is more than what is paid in
	surge        = 0.15,    -- extra flow of a fresh wound over its steady rate (after its onset, fading)
	-- How a wound begins and ends (cl_emission.lua, Respond). The flow of a wound that has just
	-- opened rises from nothing through two lags of this many seconds each: a tenth of the steady
	-- rate after about half of it, a quarter after one, six tenths after two, nine tenths after
	-- four. Chosen to look right at Z-City's bleed rates, not measured on anybody.
	onset        = { arterial = 0.10, venous = 0.12, small = 0.25, smallSev = 1.6 },
	offset       = 0.22,    -- the same for a wound that has closed (it thins out and breaks up first)
	closeMax     = 3,       -- seconds a closed wound may take to run out, at most
	deathFall    = 0.9,     -- seconds: how fast the pressure goes when the heart stops
	shareTau     = 0.35,    -- seconds: how fast seeping turns into pouring or a jet, and back
	linkDist     = 5,       -- units: Z-City's wound record lies this close to the hole the hit reported
	-- temporary cavity: the stretch of tissue around the track. Never drawn; it widens bruising,
	-- soft-tissue damage and the first release of blood. By energy class, times a velocity factor
	cavityEnergy   = { [0] = 0.25, 0.05, 0.15, 0.3, 0.6, 0.85, 1.0 },
	cavityVelocity = { [0] = 1.0, 0.6, 0.85, 1.15 },
	grazeDepth   = 1.4,     -- units: a flesh-only path that stays shallower than this under the skin is a graze
	grazeCos     = 0.45,    -- ... and strikes at more than ~63 degrees from the surface normal
	-- pressure left in the circulation by blood volume (ml; Z-City: 5000 full, unconscious near 2500)
	pressureFull = 4300, pressureLow = 1700, pressureMin = 0.2,
	-- a wound's surface: seconds (times abl_drying_scale) for the blood on it to clot and to dry
	-- once it has stopped bleeding
	clotTime     = 45,
	dryTime      = 150,
	bruiseTime   = 40,      -- seconds for the bruise around a wound to come up
	internalDelay = 5,      -- seconds until a retained projectile's track has filled and bleeds outward at full rate
	grazeBleed   = 0.12,    -- share of the booked bleed a graze shows (Z-City books a graze like any other hit; skin and fat ooze)
}

-- wound marks on the body (cl_woundfx.lua)
C.WoundFX = {
	maxPerSource = 14,      -- marks per character (entry, exit and graze marks; the oldest go first)
	drawDist     = 1100,
	detailDist   = 500,     -- beyond this only a mark's main layers are drawn (no stippling, bruise detail)
	exitReach    = 24,      -- units: how far along the bullet line the far surface is looked for
	warmDist     = 1500,    -- players this close get their surface model built before they are hit
	gloss        = 0.34,    -- wet-blood reflection on a wound at most (of the light on it)
	spreadMl     = 120,
	spreadMin    = 0.6,
	spreadMax    = 2.6,
	spreadHalf   = 7,
}
