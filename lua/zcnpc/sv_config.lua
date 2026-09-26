ZCNPC.Config = ZCNPC.Config or {}
local cfg = ZCNPC.Config

--\\ ConVars
-- Built straight out of the settings registry in sh_settings.lua, which is also
-- what the Q menu panel is built out of, so the two can never drift apart.
--
-- All replicated, and not only the handful the client has to read to draw an NPC
-- correctly. The menu is the other reader: a slider has to show where a setting
-- currently stands before anybody moves it, and a server only convar does not
-- exist on the client at all - so every panel would have opened on its defaults
-- and quietly written them back over whatever the server was actually running.
-- Replicated also settles who may change them, which is the server and nobody
-- else; the menu asks (sv_menu.lua) rather than sets.
--
-- Half the job, though: the flag enforces the server's value on a convar of the same
-- name that the client already has, and does not create one there. The client makes its
-- own from the same registry (sh_settings.lua) - without that half these are unreadable
-- from a dedicated server, and readable from a listen one, which is a difference that
-- hides for a very long time.
for _, setting in ipairs(ZCNPC.Settings) do
	local min, max = setting.min or 0, setting.max or 1

	cfg[setting.key] = ConVarExists(setting.cvar) and GetConVar(setting.cvar)
		or CreateConVar(setting.cvar, tostring(setting.default),
			FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, setting.help, min, max)
end

-- Whether the addon came up, which is three answers rather than two, and none of them
-- can be read off the presence of a convar: the client has a copy of every one of these
-- from the moment it loaded its own half (sh_settings.lua), so "there is no such convar"
-- now only ever means the client is missing the addon, never the server.
--
-- 1 the moment this file runs, because this file running is the addon being on the
-- server; 2 when Load() gets past Z-City in the autorun file. So a client that reads 0
-- is on a server without the addon, one that reads 1 is on a server that has it next to
-- a Z-City that never loaded - which is the state that looks like a broken install and
-- is not one - and 2 is the addon running. Set rather than defaulted, so a value a
-- client reads is always one the server actually sent (garrysmod-issues #3323).
local NOT_HERE, NO_ZCITY, RUNNING = 0, 1, 2

cfg.loaded = ConVarExists("zcnpc_loaded") and GetConVar("zcnpc_loaded")
	or CreateConVar("zcnpc_loaded", tostring(NOT_HERE), FCVAR_REPLICATED,
		"Read only: 0 the addon is not on this server, 1 it is and Z-City was not found, 2 it is running",
		NOT_HERE, RUNNING)

if cfg.loaded:GetInt() < NO_ZCITY then cfg.loaded:SetInt(NO_ZCITY) end

--\\ What the ragdoll bridges are doing, said out loud
-- The menu's footer reports which of the two active ragdoll addons is here and
-- which one the bodies are actually going to, and neither question can be asked
-- from the client. Artagdoll's own convars are replicated and were being read
-- directly, but "the convar exists" is only "the addon is installed" - it says
-- nothing about ReAgdoll having taken the bodies off it a second ago. ReAgdoll's
-- convars are worse than that: they are made in lua/autorun/server, so a client
-- cannot see them at all and the row would have read "not installed" on every
-- server that has it.
--
-- So the server answers instead, in the one place that knows: 0 nowhere to be
-- found, 1 installed and standing by, 2 driving the bodies.
local BRIDGE_NONE, BRIDGE_IDLE, BRIDGE_DRIVING = 0, 1, 2

local function BridgeCvar(name, addon)
	return ConVarExists(name) and GetConVar(name)
		or CreateConVar(name, tostring(BRIDGE_NONE), FCVAR_REPLICATED,
			"Read only: whether " .. addon .. " is installed (1) and driving Z-City bodies (2)",
			BRIDGE_NONE, BRIDGE_DRIVING)
end

-- Both names are in ZCNPC.ServerCvars (sh_settings.lua), which is where the client
-- gets its copy of each to read these values off.
cfg.bridge_artagdoll = BridgeCvar("zcnpc_bridge_artagdoll", "Artagdoll")
cfg.bridge_reagdoll = BridgeCvar("zcnpc_bridge_reagdoll", "ReAgdoll")
cfg.bridge_manhunt = BridgeCvar("zcnpc_bridge_manhunt", "Manhunt Executions")
cfg.bridge_eeer = BridgeCvar("zcnpc_bridge_eeer", "EEER")

-- Asked of the bridge files rather than answered here: they are the ones holding
-- each other off, and they are loaded after this. Missing means the file never
-- loaded, which reads the same as the addon not being there.
local function BridgeState(installed, driving)
	if not (isfunction(installed) and installed()) then return BRIDGE_NONE end

	return isfunction(driving) and driving() and BRIDGE_DRIVING or BRIDGE_IDLE
end

local function RefreshBridges()
	local artagdoll = BridgeState(ZCNPC.HasArtagdoll, ZCNPC.ArtagdollReady)
	local reagdoll = BridgeState(ZCNPC.HasReagdoll, ZCNPC.ReagdollDrives)
	local manhunt = BridgeState(ZCNPC.HasManhunt, ZCNPC.ManhuntReady)
	local eeer = BridgeState(ZCNPC.HasEeer, ZCNPC.EeerReady)

	if cfg.bridge_artagdoll:GetInt() ~= artagdoll then cfg.bridge_artagdoll:SetInt(artagdoll) end
	if cfg.bridge_reagdoll:GetInt() ~= reagdoll then cfg.bridge_reagdoll:SetInt(reagdoll) end
	if cfg.bridge_manhunt:GetInt() ~= manhunt then cfg.bridge_manhunt:SetInt(manhunt) end
	if cfg.bridge_eeer:GetInt() ~= eeer then cfg.bridge_eeer:SetInt(eeer) end
end

-- The same second the two bridges hold each other off on, so the footer never
-- disagrees with what is actually happening for longer than that.
timer.Create("zcnpc_bridges", 1, 0, RefreshBridges)
timer.Simple(0, RefreshBridges)
--//

-- Cached: Enabled() sits on every HomigradDamage / Org Think / timer tick.
-- Two GetBool reads per call used to land once per organism per hook per tick.
local hgNoOrganismNPCs = GetConVar("hg_noorganismnpcs")
local enabledOn = true
local hgOff = false

local function RefreshEnabled()
	enabledOn = cfg.enabled ~= nil and cfg.enabled:GetBool() or false
	if not hgNoOrganismNPCs then hgNoOrganismNPCs = GetConVar("hg_noorganismnpcs") end
	hgOff = hgNoOrganismNPCs ~= nil and hgNoOrganismNPCs:GetBool() or false
end

pcall(cvars.AddChangeCallback, "hg_noorganismnpcs", RefreshEnabled, "zcnpc_hg_noorganismnpcs")
pcall(cvars.AddChangeCallback, "zcnpc_enabled", RefreshEnabled, "zcnpc_enabled_cache")

function ZCNPC.Enabled()
	return enabledOn and not hgOff
end

RefreshEnabled()

function ZCNPC.Debug(...)
	if not cfg.debug:GetBool() then return end
	print("[ZCNPC]", ...)
end
--//

--\\ NPC classes natively handled by Z-City's own sv_npcstuff.lua.
-- Z-City hangs the organism when it can. If that hook misses (class not
-- ready on spawn), SetupNPC hangs one. Unconsciousness and loot on a
-- downed death are ours either way.
cfg.NativeClasses = {
	["npc_metropolice"] = true,
	["npc_combine_s"] = true,
	["npc_citizen"] = true,
}

-- Mirror of the (local) loot table in z_city/lua/homigrad/sv_npcstuff.lua,
-- used when a native NPC bleeds out on the ground instead of dying the engine way.
-- Entries are a class string (always) or { class, chance } / { class = "...", chance = n }.
-- Chance is rolled once when the kit is first built (EnsureLootKit), then remembered.
cfg.NativeLoot = {
	["npc_metropolice"] = {
		"weapon_hg_stunstick",
		"weapon_medkit_sh",
		{ "weapon_bandage_sh", 0.90 },
		"weapon_handcuffs",
		"weapon_walkie_talkie"
	},
	["npc_combine_s"] = {
		"weapon_melee",
		"weapon_hg_hl2nade_tpik",
		{ "weapon_bandage_sh", 0.90 },
		"weapon_handcuffs"
	},
	["npc_citizen"] = {
		"weapon_smallconsumable",
		{ "weapon_bandage_sh", 0.90 },
		{ "weapon_painkillers", 0.45 },
	}
}
--//

--\\ Extra classes that get the organism from this addon (used when zcnpc_allnpcs 0,
-- with zcnpc_allnpcs 1 any NPC that passes the bone check qualifies anyway)
cfg.HumanClasses = {
	["npc_alyx"] = true,
	["npc_barney"] = true,
	["npc_monk"] = true,
	["npc_kleiner"] = true,
	["npc_eli"] = true,
	["npc_mossman"] = true,
	["npc_magnusson"] = true,
	["npc_breen"] = true,
	["npc_odessa"] = true,
	["npc_gman"] = true,
	["npc_fisherman"] = true,
}

-- Stock HL2 bodies. GetModel is empty on a template spawn and on the first
-- tick after OnEntityCreated; the ragdoll still needs a path, so the class
-- picks one rather than walking away from the kick.
cfg.ClassModels = {
	["npc_combine_s"] = "models/combine_soldier.mdl",
	["npc_metropolice"] = "models/police.mdl",
	["npc_citizen"] = "models/Humans/Group01/male_07.mdl",
	["npc_alyx"] = "models/alyx.mdl",
	["npc_barney"] = "models/barney.mdl",
	["npc_monk"] = "models/monk.mdl",
	["npc_kleiner"] = "models/kleiner.mdl",
	["npc_eli"] = "models/eli.mdl",
	["npc_mossman"] = "models/mossman.mdl",
	["npc_magnusson"] = "models/magnusson.mdl",
	["npc_breen"] = "models/breen.mdl",
	["npc_odessa"] = "models/odessa.mdl",
	["npc_gman"] = "models/gman.mdl",
	["npc_fisherman"] = "models/Humans/Group01/male_07.mdl",
}

cfg.FallbackRagdollModel = "models/Humans/Group01/male_07.mdl"

-- Never touch these, even with zcnpc_allnpcs 1 (non-biped, mechanical or broken skeletons)
cfg.Blacklist = {
	["npc_headcrab"] = true,
	["npc_headcrab_fast"] = true,
	["npc_headcrab_black"] = true,
	["npc_barnacle"] = true,
	["npc_manhack"] = true,
	["npc_rollermine"] = true,
	["npc_turret_floor"] = true,
	["npc_turret_ceiling"] = true,
	["npc_turret_ground"] = true,
	["npc_cscanner"] = true,
	["npc_clawscanner"] = true,
	["npc_combinegunship"] = true,
	["npc_combinedropship"] = true,
	["npc_helicopter"] = true,
	["npc_strider"] = true,
	["npc_hunter"] = true,
	["npc_antlion"] = true,
	["npc_antlionguard"] = true,
	["npc_antlion_worker"] = true,
	["npc_antlion_grub"] = true,
	["npc_dog"] = true,
	["npc_crow"] = true,
	["npc_pigeon"] = true,
	["npc_seagull"] = true,
	["npc_stalker"] = true,
	["npc_vortigaunt"] = true,
	["npc_bullseye"] = true,
	["npc_grenade_frag"] = true,
	["npc_satchel"] = true,
	["npc_tripmine"] = true,
	["npc_sniper"] = true,
	["npc_combine_camera"] = true,
}

-- The undead are not in the business of bleeding out, passing out or waking up
-- again, so none of this addon has anything useful to say about them: it would
-- knock a zombie down, take its pulse, hand it a knockout timer and wait for it
-- to come round. They are excluded outright rather than switchable.
--
-- The list is the four Half-Life 2 classes and the two torsos; the pattern after
-- it is for everything else, since a zombie from a workshop addon is named like
-- one and there is nothing else to recognise it by.
cfg.ZombieClasses = {
	["npc_zombie"] = true,
	["npc_zombie_torso"] = true,
	["npc_zombine"] = true,
	["npc_fastzombie"] = true,
	["npc_fastzombie_torso"] = true,
	["npc_poisonzombie"] = true,
}

function ZCNPC.IsZombie(ent)
	if not IsValid(ent) then return false end

	local cached = ent.zcnpc_iszombie
	if cached ~= nil then return cached end

	local class = ent:GetClass()
	local yes = cfg.ZombieClasses[class]
		or class:find("zombie", 1, true) ~= nil
		or class:find("zombine", 1, true) ~= nil

	ent.zcnpc_iszombie = yes

	return yes
end

-- Z-City style overhead names (SetNWString "PlayerName") + colors
cfg.Names = {
	["npc_alyx"] = { "Alyx", Vector(255, 170, 100) / 255 },
	["npc_barney"] = { "Barney", Vector(80, 130, 255) / 255 },
	["npc_monk"] = { "Father Grigori", Vector(200, 170, 90) / 255 },
	["npc_kleiner"] = { "Kleiner", Vector(200, 200, 200) / 255 },
	["npc_eli"] = { "Eli", Vector(200, 200, 200) / 255 },
	["npc_mossman"] = { "Mossman", Vector(200, 200, 200) / 255 },
	["npc_magnusson"] = { "Magnusson", Vector(200, 200, 200) / 255 },
	["npc_breen"] = { "Breen", Vector(140, 140, 200) / 255 },
	["npc_odessa"] = { "Odessa", Vector(160, 200, 160) / 255 },
	["npc_gman"] = { "G-Man", Vector(100, 100, 120) / 255 },
	["npc_fisherman"] = { "Fisherman", Vector(160, 160, 120) / 255 },
}

-- Bones that must exist for the organism/ragdoll pipeline to work
cfg.RequiredBones = {
	"ValveBiped.Bip01_Head1",
	"ValveBiped.Bip01_Pelvis",
	"ValveBiped.Bip01_L_Calf",
	"ValveBiped.Bip01_R_Calf",
}
--//

--\\ Models we borrow from Z-City
cfg.StumpModel = "models/gleb/zcity/headboom.mdl" -- gore cap Gib_Input hangs on a beheaded body
--//
