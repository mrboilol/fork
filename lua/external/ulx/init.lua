if not ulx then
	ulx = {}

	-- Get data folder up to speed
	include( "data.lua" )

	local sv_modules = file.Find( "external/ulx/modules/*.lua", "LUA" )
	local sh_modules = file.Find( "external/ulx/modules/sh/*.lua", "LUA" )
	local cl_modules = file.Find( "external/ulx/modules/cl/*.lua", "LUA" )

	Msg( "///////////////////////////////\n" )
	Msg( "//       ULX Admin Mod       //\n" )
	Msg( "///////////////////////////////\n" )
	Msg( "// Loading...                //\n" )

	Msg( "//  sh_defines.lua           //\n" )
	include( "sh_defines.lua" )
	Msg( "//  lib.lua                  //\n" )
	include( "lib.lua" )
	Msg( "//  base.lua                 //\n" )
	include( "base.lua" )
	Msg( "//  sh_base.lua              //\n" )
	include( "sh_base.lua" )
	Msg( "//  log.lua                  //\n" )
	include( "log.lua" )

	for _, file in ipairs( sv_modules ) do
		Msg( "//  MODULE: " .. file .. string.rep( " ", 17 - file:len() ) .. "//\n" )
		include( "modules/" .. file )
	end

	for _, file in ipairs( sh_modules ) do
		Msg( "//  MODULE: " .. file .. string.rep( " ", 17 - file:len() ) .. "//\n" )
		include( "modules/sh/" .. file )
	end

	Msg( "//  end.lua                  //\n" )
	include( "end.lua" )
	Msg( "// Load Complete!            //\n" )
	Msg( "///////////////////////////////\n" )

	AddCSLuaFile( "external/ulx/cl_init.lua" )
	AddCSLuaFile( "external/ulx/sh_defines.lua" )
	AddCSLuaFile( "external/ulx/sh_base.lua" )
	AddCSLuaFile( "external/ulx/cl_lib.lua" )

	-- Find c-side modules and load them
	for _, file in ipairs( cl_modules ) do
		AddCSLuaFile( "external/ulx/modules/cl/" .. file )
	end

	for _, file in ipairs( sh_modules ) do
		AddCSLuaFile( "external/ulx/modules/sh/" .. file )
	end
end
