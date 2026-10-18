AddCSLuaFile()


if (CLIENT) then
     function gbehelp( ply, text, public)
         if (string.find(text, "!hb") != nil) then
			 chat.AddText("Console commands:")
             chat.AddText("hb_easyuse [0/1] - Should nukes interact on use?")
	         chat.AddText("hb_fragility [0/1] - Should nukes arm, launch on damage?")
	         chat.AddText("hb_unfreeze [0/1] - Should nukes unfreeze stuff?")
			 chat.AddText("hb_deleteconstraints [0/1] - Should nukes delete constraints?")
			 chat.AddText("hb_explosion_damage  [0/1] - Should nukes do damage upon explosion?")
		 end
     end
end
hook.Add( "OnPlayerChat", "hbhelp", hbhelp )