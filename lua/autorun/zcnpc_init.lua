--[[
	Z-City NPC Overhaul
	Extends the Z-City (Homigrad) body simulation onto regular NPCs:
	organism for all humanoid NPCs, real unconsciousness (ragdoll instead of
	the stock instant-kill), knockdowns, wake up, bleedout death, loot on
	downed bodies, lethal head shots, handcuffs and a get up animation.

	Requires the Z-City addon to be installed and loaded.
]]

ZCNPC = ZCNPC or {}
ZCNPC.Version = "2.10.21"

-- Settings and the baked animation data. Both realms need both: the server turns
-- the settings into convars and the client turns them into the Q menu panel, and
-- for the animation the client replays it while the server reads the angles it
-- ends on to decide which way a waking NPC should face.
local sharedFiles = {
	"zcnpc/sh_crashtrace.lua", -- debug only, off unless zcnpc_crashtrace / zcnpc_crashtrace_cl is 1
	"zcnpc/sh_settings.lua",
	"zcnpc/sh_npcweapons.lua", -- spawn loadouts: the groups and the gun list, both realms
	"zcnpc/sh_npcarmor.lua", -- after npcweapons: the same groups, for the other half of one
	"zcnpc/sh_getup_anim.lua",
	"zcnpc/sh_workpose.lua", -- the crouch layer, and the work kinds the client draws hands off
	"zcnpc/sh_properties.lua", -- C-menu organism tools for NPCs (both realms)
}

-- Rendering, posing and the get up animation. These only talk to Z-City from
-- inside their own hooks, so they can load before it does.
local clientFiles = {
	"zcnpc/cl_pose.lua",
	"zcnpc/cl_body.lua",
	"zcnpc/cl_render.lua", -- owns ZCNPC.AddPass, so it comes before anything that adds one
	"zcnpc/cl_armor.lua", -- after cl_render: armour draw pass
	"zcnpc/cl_headcrab.lua", -- after cl_render: registers an AddPass
	"zcnpc/cl_wound.lua",
	"zcnpc/cl_blood.lua", -- after Homigrad may already be up: wraps addBloodPart for NPC budget
	"zcnpc/cl_blooddecal.lua", -- the other half of the same budget: how big what lands is drawn
	"zcnpc/cl_getup.lua",
	"zcnpc/cl_loot.lua", -- after cl_render: registers a pass, and after cl_pose: solves arms with it
	"zcnpc/cl_weapon.lua",
	"zcnpc/cl_medicine.lua", -- medicine's own world model, on an NPC's hand
	"zcnpc/cl_ui.lua", -- the parts the settings window is drawn out of
	"zcnpc/cl_f6menu.lua", -- after cl_ui: owns ZCNPC.OpenMenu
	"zcnpc/cl_menu.lua", -- after cl_f6menu: the Q menu button that opens it
	"zcnpc/cl_inpc.lua", -- hold off iNPC cleanup / regen / airstrike on the client
	"zcnpc/cl_performantrender.lua", -- nil m_hPlayerData PreRender spam
	"zcnpc/cl_zchat.lua", -- rebuild Z-City's chat box when its own hook missed it
	"zcnpc/cl_zcitygui.lua", -- fonts + Esc / loot / med progress bar heals
}

-- The settings menu's own clicks (cl_ui.lua). Named one by one rather than
-- through resource.AddWorkshop, because the addon is ServerContent: a client
-- connecting to a server running it has not subscribed to anything, and these
-- are the only files it needs from us. The menu falls back to Half-Life 2's own
-- sounds if they have not landed, so a slow download is a duller menu rather
-- than a silent one.
local menuSounds = {
	"add", "click", "close", "deny", "drop", "open",
	"page", "slide", "tab", "toggle_off", "toggle_on",
}

if SERVER then
	for _, file in ipairs(sharedFiles) do AddCSLuaFile(file) end
	for _, file in ipairs(clientFiles) do AddCSLuaFile(file) end
	for _, file in ipairs(sharedFiles) do include(file) end

	-- The settings, before anything waits for anything. They are replicated convars, and
	-- what a joining client is sent is whatever the server holds at the moment it joins:
	-- made late they are values nobody has yet, and made after somebody has joined they
	-- may not reach that somebody at all. Loading the rest of the addon waits for Z-City
	-- and may wait forever, so the convars do not wait with it - zcnpc_loaded is what
	-- says whether the rest of it ever arrived.
	include("zcnpc/sv_config.lua")

	-- Lambda mapscripts call SetupTrigger during OnNewGame. That is before
	-- Homigrad is guaranteed to be up, and this addon's own Load() waits for it,
	-- so the method has to be put back here - the same moment as the convars,
	-- and for the same reason: later is a mapscript that already died.
	local lambdaOk, lambdaErr = pcall(include, "zcnpc/sv_lambda.lua")
	if not lambdaOk then
		ErrorNoHalt("[ZCNPC] sv_lambda.lua failed: " .. tostring(lambdaErr) .. "\n")
	end

	-- Before Load(): Homigrad indexes ply.organism on the first sandbox
	-- spawn, and Load() is too late if that spawn is this frame.
	local orgOk, orgErr = pcall(include, "zcnpc/sv_playerorg.lua")
	if not orgOk then
		ErrorNoHalt("[ZCNPC] sv_playerorg.lua failed: " .. tostring(orgErr) .. "\n")
	end

	for _, name in ipairs(menuSounds) do
		resource.AddSingleFile("sound/zcnpc/ui/" .. name .. ".wav")
	end
else
	for _, file in ipairs(sharedFiles) do include(file) end
	for _, file in ipairs(clientFiles) do include(file) end

	return
end

local function Load()
	if ZCNPC.Loaded then return end

	-- Z-City bootstraps from its own lua/autorun/loader.lua and fires "HomigradRun" when done
	if not (istable(hg) and hg.loaded and istable(hg.organism)) then return end

	-- sv_config.lua is already in: it runs the moment this file does, so the convars
	-- are on a client before it connects.
	include("zcnpc/sv_core.lua")
	include("zcnpc/sv_getup.lua")
	include("zcnpc/sv_uncon.lua")
	include("zcnpc/sv_execute.lua") -- after uncon: finish-off while conscious on the floor
	include("zcnpc/sv_conscious.lua") -- before sv_head: the head shot path calls into it
	include("zcnpc/sv_gib.lua") -- before sv_head: HomigradDamage must mark heavy weapons first
	include("zcnpc/sv_head.lua")
	include("zcnpc/sv_headcrab.lua") -- after sv_head / sv_uncon: uses MakeUnconscious + Downed
	include("zcnpc/sv_loot.lua")
	include("zcnpc/sv_weapon.lua") -- after sv_loot: its ZCNPC_Downed hook reads info.wepclass
	include("zcnpc/sv_disarmed.lua")
	include("zcnpc/sv_downedfight.lua") -- after disarmed: hands back the capabilities it owns to it
	include("zcnpc/sv_armor.lua") -- after disarmed: same fetch AI, must not fight its schedules
	include("zcnpc/sv_npcweapons.lua") -- after armor: the rebel / refugee split is read off it
	include("zcnpc/sv_sound.lua")
	include("zcnpc/sv_cuffs.lua")
	include("zcnpc/sv_damage.lua")
	include("zcnpc/sv_throat.lua") -- after damage: reads the entry hole off ZCNPC.HitPos
	include("zcnpc/sv_stun.lua")
	include("zcnpc/sv_status.lua")
	include("zcnpc/sv_woundedwalk.lua") -- after status: shares the limp / WW ownership gate
	include("zcnpc/sv_collide.lua")
	include("zcnpc/sv_medical.lua")
	include("zcnpc/sv_cms.lua") -- after medical: shares its kit bookkeeping (ZCNPC.KitHasItem)
	include("zcnpc/sv_looting.lua") -- after cms + disarmed: NoThreatNear, IsGunClass
	include("zcnpc/sv_rescue.lua") -- after medical + cms: spends their items, borrows their needle
	include("zcnpc/sv_pulse.lua")
	include("zcnpc/sv_artagdoll.lua")
	include("zcnpc/sv_reagdoll.lua") -- after artagdoll: wraps its gate and takes the bodies off it
	include("zcnpc/sv_beartrap.lua") -- after gib + uncon: AllowNextGib, Floor / ExtendDown
	include("zcnpc/sv_inpc.lua")
	include("zcnpc/sv_ducttape.lua") -- after uncon: wraps ZCNPC.WakeUp
	include("zcnpc/sv_hl2.lua") -- after uncon + stun: BeforeDamage, MakeUnconscious, Electrify
	include("zcnpc/sv_ignoreplayers.lua") -- makes the NPC tab's own checkbox mean what it says
	include("zcnpc/sv_prime.lua") -- first-join ragdoll so guns / ragdoll cam init

	-- Bridges to other addons. Every one of them is inert without the addon it is
	-- named after and none of the addon's own behaviour depends on any of them, so
	-- they load last and out of the way.
	include("zcnpc/sv_cai.lua") -- after execute: listens for its ZCNPC_TargetLost
	include("zcnpc/sv_reasfx.lua") -- after reagdoll: the bodies it voices are the ones kept off it
	include("zcnpc/sv_berserk.lua") -- Fury-13 killstreak counts NPC deaths
	include("zcnpc/sv_organs.lua") -- organ / artery chance sliders
	include("zcnpc/sv_inventory.lua") -- after loot: kit grenades instead of HL2 frags
	include("zcnpc/sv_manhunt.lua") -- Manhunt Executions keep wounds on the body
	include("zcnpc/sv_eeer.lua") -- EEER expressions on our ragdolls

	include("zcnpc/sv_menu.lua")

	if ZCNPC.InstallWoundedWalk then ZCNPC.InstallWoundedWalk() end
	if ZCNPC.InstallBearTrap then ZCNPC.InstallBearTrap() end
	if ZCNPC.InstallInpc then ZCNPC.InstallInpc() end
	if ZCNPC.InstallDuctTape then ZCNPC.InstallDuctTape() end

	ZCNPC.Loaded = true

	-- 2 is "running" (sv_config.lua). It was already 1 from the moment that file loaded,
	-- which is what tells a client the difference between a server without this addon
	-- and a server that has it next to a Z-City that never arrived.
	if ZCNPC.Config and ZCNPC.Config.loaded then ZCNPC.Config.loaded:SetInt(2) end

	print("[ZCNPC] Z-City NPC Overhaul " .. ZCNPC.Version .. " loaded")
end

-- Z-City may load before or after this file depending on addon mount order,
-- so try immediately and also wait for its ready-hook.
Load()
hook.Add("HomigradRun", "zcnpc_load", Load)
hook.Add("InitPostEntity", "zcnpc_load", function()
	Load()

	if not ZCNPC.Loaded then
		for i = 1, 3 do
			MsgC(Color(255, 60, 60), "[ZCNPC] Z-City (Homigrad) not found! Z-City NPC Overhaul is disabled.\n")
		end
	end
end)
