local Created = false;

local function hbombssettings( CPanel )
	sounds={}
	sounds[1]="vo/npc/male01/answer39.wav"
	sounds[2]="vo/npc/male01/answer35.wav"
	sounds[3]="vo/npc/male01/doingsomething.wav"
	sounds[4]="vo/npc/male01/answer38.wav"
	Created = true;

	local logo = vgui.Create( "DImageButton" );
	logo:SetImage( "hud/hbombs.png" );
	logo:SetSize( 300, 300 );
	LocalPlayer().clicks = 0
	logo.DoClick = function()
		LocalPlayer().clicks = LocalPlayer().clicks + 1
		if LocalPlayer().clicks >=5 then
			LocalPlayer():ConCommand("kill")
			LocalPlayer():ConCommand("say I kept clicking!\n")
			LocalPlayer().clicks = 0
			local snd = Sound( "vo/npc/male01/answer11.wav");
			surface.PlaySound( snd );
			
		else			
			local snd = Sound( table.Random(sounds) );
			surface.PlaySound( snd );
		end
	end

	CPanel:AddPanel( logo );
		
	local shockwave = CPanel:AddControl( "CheckBox", { Label = "Should all nukes unweld and unfreeze?", Command = "hb_shockwave_unfreeze" } );
	shockwave.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_shockwave_unfreeze" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_shockwave_unfreeze" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end
	local realsound = CPanel:AddControl( "CheckBox", { Label = "Should the sound travel realistically?", Command = "hb_realistic_sound" } );
	realsound.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_realistic_sound" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_realistic_sound" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end

	local decals = CPanel:AddControl( "CheckBox", { Label = "Should bombs leave scorch marks behind?", Command = "hb_decals" } );
	decals.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_shockwave_unfreeze" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_decals" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end
	
	local easyuse = CPanel:AddControl( "CheckBox", { Label = "Should bombs be easily armed?", Command = "hb_easyuse" } );
	easyuse.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_easyuse" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_easyuse" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end
	
	local fragility = CPanel:AddControl( "CheckBox", { Label = "Should bombs arm when hit or dropped?", Command = "hb_fragility" } );
	fragility.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_fragility" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_fragility" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end
	
	local emp = CPanel:AddControl( "CheckBox", { Label = "Should air detonated nukes produce emp?", Command = "hb_nuclear_emp" } );
	emp.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_nuclear_emp" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_nuclear_emp" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end
	local safeemp = CPanel:AddControl( "CheckBox", { Label = "Should the server reduce emp lag?", Command = "hb_safeemp" } );
	safeemp.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_safeemp" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_safeemp" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end
	local sh = CPanel:AddControl( "CheckBox", { Label = "Should there be sound shake?", Command = "hb_sound_shake" } );
	sh.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_sound_shake" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_sound_shake" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end
	local fallout = CPanel:AddControl( "CheckBox", { Label = "Should there be nuclear fallout?", Command = "hb_nuclear_fallout" } );
	fallout.OnChange = function( panel, bVal ) 
		if( LocalPlayer():IsSuperAdmin() and !Created ) then
			if( ( bVal and 1 or 0 ) == cvars.Number( "hb_nuclear_fallout" ) ) then return end
			net.Start( "hbombs_cvar" );
				net.WriteString( "hb_fallout" );
				net.WriteFloat( bVal and 1 or 0 );
			net.SendToServer();
		end
	end
	
	timer.Simple( 0.1, function() 
		if( sh ) then
			sh:SetValue( GetConVarNumber( "hb_sound_shake" ) );
		end
		if( fallout ) then
			fallout:SetValue( GetConVarNumber( "hb_nuclear_fallout " ) );
		end
		if( easyuse ) then
			easyuse:SetValue( GetConVarNumber( "hb_easyuse" ) );
		end
		if( realsound ) then
			realsound:SetValue( GetConVarNumber( "hb_realistic_sound" ) );
		end
		if( safeemp ) then
			easyuse:SetValue( GetConVarNumber( "hb_safeemp" ) );
		end
		if( fragility ) then
			fragility:SetValue( GetConVarNumber( "hb_fragility" ) );
		end
		if( emp ) then
			emp:SetValue( GetConVarNumber( "hb_nuclear_emp" ) );
		end
		if( shockwave ) then
			shockwave:SetValue( GetConVarNumber( "hb_shockwave_unfreeze" ) );
		end
		
		if( decals ) then
			decals:SetValue( GetConVarNumber( "hb_decals" ) );
		end
		Created = false;

	end );

end




hook.Add( "PopulateToolMenu", "PopulateHbombsMenus", function()

	spawnmenu.AddToolMenuOption( "Utilities", "HBOMBS", "HbombsSettings", "Settings", "", "", hbombssettings )

end );

hook.Add( "AddToolMenuCategories", "CreateHbombsCategories", function()

	spawnmenu.AddToolCategory( "Utilities", "HBOMBS", "HBOMBS" );

end );
