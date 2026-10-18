AddCSLuaFile()
util.AddNetworkString( "hbombs_cvar" )
util.AddNetworkString( "hbombs_net" )
util.AddNetworkString( "hbombs_general" )
util.AddNetworkString( "hbombs_announcer" )
SetGlobalString ( "hb_ver", 5 )

TOTAL_BOMBS = 0
net.Receive( "hbombs_cvar", function( len, pl ) 
	if( !pl:IsAdmin() ) then return end
	local cvar = net.ReadString();
	local val = net.ReadFloat();
	if( GetConVar( tostring( cvar ) ) == nil ) then return end
	if( GetConVarNumber( tostring( cvar ) ) == tonumber( val ) ) then return end

	game.ConsoleCommand( tostring( cvar ) .." ".. tostring( val ) .."\n" );

end );


function source_debug( ply, command)
	ply:ChatPrint("Engine Tickrate: \n"..tostring(1/engine.TickInterval()))
end
concommand.Add( "source_debug", source_debug )

function hbversion( ply, command, arguments )
    ply:ChatPrint( "Hbombs 5/14/16" )
end
concommand.Add( "hb_version", hbversion )


function hb_spawn(ply)
	ply.gasmasked=false
	ply.hazsuited=false
	net.Start( "hbombs_net" )        
		net.WriteBit( false )
		ply:StopSound("breathing")
	net.Send(ply)
end
hook.Add( "PlayerSpawn", "hb_spawn", hb_spawn )	


