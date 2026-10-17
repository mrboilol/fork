ULib = ULib or {} -- Init table

include( "external/ulib/shared/defines.lua" )
include( "external/ulib/shared/misc.lua" )
include( "external/ulib/shared/util.lua" )
include( "external/ulib/shared/hook.lua" )
include( "external/ulib/shared/tables.lua" )
include( "external/ulib/client/commands.lua" )
include( "external/ulib/shared/messages.lua" )
include( "external/ulib/shared/player.lua" )
include( "external/ulib/client/cl_util.lua" )
include( "external/ulib/client/draw.lua" )
include( "external/ulib/shared/commands.lua" )
include( "external/ulib/shared/sh_ucl.lua" )
include( "external/ulib/shared/plugin.lua" )
include( "external/ulib/shared/cami_global.lua" )
include( "external/ulib/shared/cami_ulib.lua" )

--Shared modules
local files = file.Find( "external/ulib/modules/*.lua", "LUA" )
if #files > 0 then
	for _, file in ipairs( files ) do
		Msg( "[ULIB] Loading SHARED module: " .. file .. "\n" )
		include( "external/ulib/modules/" .. file )
	end
end

--Client modules
local files = file.Find( "external/ulib/modules/client/*.lua", "LUA" )
if #files > 0 then
	for _, file in ipairs( files ) do
		Msg( "[ULIB] Loading CLIENT module: " .. file .. "\n" )
		include( "external/ulib/modules/client/" .. file )
	end
end

local needs_auth = {}

local function onEntCreated( ent )
	if ent:IsPlayer() and needs_auth[ ent:UserID() ] then
		hook.Call( ULib.HOOK_UCLAUTH, _, ent ) -- Because otherwise the server might call this before the player is created
		needs_auth[ ent:UserID() ] = nil
	end
end
hook.Add( "OnEntityCreated", "ULibPlayerAuthCheck", onEntCreated, HOOK_MONITOR_HIGH ) -- Listen for player creations

local function onInitPostEntity()
	if LocalPlayer():IsValid() then
		hook.Call( ULib.HOOK_LOCALPLAYERREADY, _, LocalPlayer() )
		RunConsoleCommand( "ulib_cl_ready" )
	end
end
hook.Add( "InitPostEntity", "ULibLocalPlayerReady", onInitPostEntity, HOOK_MONITOR_HIGH ) -- Flag server when LocalPlayer() should be valid

-- We're trying to make sure that the player auths after the player object is created, this function is part of that check
function authPlayerIfReady( ply, userid )
	if ply and ply:IsValid() then
		hook.Call( ULib.HOOK_UCLAUTH, _, ply ) -- Call hook
	else
		needs_auth[ userid ] = true
	end
end
