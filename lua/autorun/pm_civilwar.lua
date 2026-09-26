local function AddPlayerModel( name, model )

    list.Set( "PlayerOptionsModel", name, model )
    player_manager.AddValidModel( name, model )
	
end

AddPlayerModel( "union_01", "models/humans/civilwar/male_01.mdl" )
AddPlayerModel( "union_02", "models/humans/civilwar/male_02.mdl" )
AddPlayerModel( "union_03", "models/humans/civilwar/male_03.mdl" )
AddPlayerModel( "union_04", "models/humans/civilwar/male_04.mdl" )
AddPlayerModel( "confederate_06", "models/humans/civilwar/male_06.mdl" )
AddPlayerModel( "confederate_07", "models/humans/civilwar/male_07.mdl" )
AddPlayerModel( "confederate_08", "models/humans/civilwar/male_08.mdl" )
AddPlayerModel( "confederate_09", "models/humans/civilwar/male_09.mdl" )