if not ULib then
	ULib = {}

	-- For historical purposes
	if not ULib.consoleCommand then ULib.consoleCommand = game.ConsoleCommand end

	file.CreateDir( "ulib" )

	Msg( "///////////////////////////////\n" )
	Msg( "//      Ulysses Library      //\n" )
	Msg( "///////////////////////////////\n" )
	Msg( "// Loading...                //\n" )

	Msg( "//  shared/defines.lua       //\n" )
	include( "external/ulib/shared/defines.lua" )
	Msg( "//  shared/misc.lua          //\n" )
	include( "external/ulib/shared/misc.lua" )
	Msg( "//  shared/util.lua          //\n" )
	include( "external/ulib/shared/util.lua" )
	Msg( "//  shared/hook.lua          //\n" )
	include( "external/ulib/shared/hook.lua" )
	Msg( "//  shared/table.lua         //\n" )
	include( "external/ulib/shared/tables.lua" )
	Msg( "//  shared/player.lua        //\n" )
	include( "external/ulib/shared/player.lua" )
	Msg( "//  server/player.lua        //\n" )
	include( "external/ulib/server/player.lua" )
	Msg( "//  server/bans.lua          //\n" )
	include( "external/ulib/server/bans.lua" )
	Msg( "//  shared/messages.lua      //\n" )
	include( "external/ulib/shared/messages.lua" )
	Msg( "//  shared/commands.lua      //\n" )
	include( "external/ulib/shared/commands.lua" )
	Msg( "//  server/concommand.lua    //\n" )
	include( "external/ulib/server/concommand.lua" )
	Msg( "//  server/util.lua          //\n" )
	include( "external/ulib/server/util.lua" )
	Msg( "//  shared/sh_ucl.lua        //\n" )
	include( "external/ulib/shared/sh_ucl.lua" )
	Msg( "//  server/ucl.lua           //\n" )
	include( "external/ulib/server/ucl.lua" )
	Msg( "//  server/phys.lua          //\n" )
	include( "external/ulib/server/phys.lua" )
	Msg( "//  server/player_ext.lua    //\n" )
	include( "server/player_ext.lua" )
	Msg( "//  server/entity_ext.lua    //\n" )
	include( "server/entity_ext.lua" )
	Msg( "//  shared/plugin.lua        //\n" )
	include( "external/ulib/shared/plugin.lua" )
	Msg( "//  shared/cami_global.lua   //\n" )
	include( "shared/cami_global.lua" )
	Msg( "//  shared/cami_ulib.lua     //\n" )
	include( "shared/cami_ulib.lua" )
	Msg( "// Load Complete!            //\n" )
	Msg( "///////////////////////////////\n" )

	AddCSLuaFile( "external/ulib/cl_init.lua" )
	AddCSLuaFile( "autorun/ulib_init.lua" )
	local folder = "external/ulib/shared"
	local files = file.Find( folder .. "/" .. "*.lua", "LUA" )
	for _, file in ipairs( files ) do
		AddCSLuaFile( folder .. "/" .. file )
	end

	folder = "external/ulib/client"
	files = file.Find( folder .. "/" .. "*.lua", "LUA" )
	for _, file in ipairs( files ) do
		AddCSLuaFile( folder .. "/" .. file )
	end

	--Shared modules
	local files = file.Find( "external/ulib/modules/*.lua", "LUA" )
	if #files > 0 then
		for _, file in ipairs( files ) do
			Msg( "[ULIB] Loading SHARED module: " .. file .. "\n" )
			include( "external/ulib/modules/" .. file )
			AddCSLuaFile( "external/ulib/modules/" .. file )
		end
	end

	--Server modules
	local files = file.Find( "external/ulib/modules/server/*.lua", "LUA" )
	if #files > 0 then
		for _, file in ipairs( files ) do
			Msg( "[ULIB] Loading SERVER module: " .. file .. "\n" )
			include( "external/ulib/modules/server/" .. file )
		end
	end

	--Client modules
	local files = file.Find( "external/ulib/modules/client/*.lua", "LUA" )
	if #files > 0 then
		for _, file in ipairs( files ) do
			Msg( "[ULIB] Loading CLIENT module: " .. file .. "\n" )
			AddCSLuaFile( "external/ulib/modules/client/" .. file )
		end
	end

	local function clReady( ply )
		if ply.ulib_ready then return end
		ply.ulib_ready = true
		hook.Call( ULib.HOOK_LOCALPLAYERREADY, _, ply )
	end
	concommand.Add( "ulib_cl_ready", clReady ) -- Called when the c-side player object is ready
end
