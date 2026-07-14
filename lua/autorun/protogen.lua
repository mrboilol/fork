player_manager.AddValidModel( "Protogen", "models/eradium/protogen_player.mdl" )
player_manager.AddValidHands( "Protogen", "models/eradium/protogen_vm.mdl", 0, "00000000" )

local Category = "Nukude"

local NPC = { 	Name = "Protogen - Friendly",
				Class = "npc_citizen",
				Model = "models/eradium/protogen_ally.mdl",
				Health = "100",
				KeyValues = { citizentype = 4 },
				Weapons = { "weapon_smg1", "weapon_ar2", "weapon_shotgun", "weapon_crossbow" },
				Category = Category	}

list.Set( "NPC", "npc_nukude_proto_f", NPC )

local NPC = { 	Name = "Protogen - Hostile",
				Class = "npc_combine_s",
				Model = "models/eradium/protogen_enemy.mdl",
				Squadname = "Enemies",
				Numgrenades = "3",
				Health = "100",
				Weapons = { "weapon_smg1", "weapon_ar2", "weapon_shotgun" },
				Category = Category	}

list.Set( "NPC", "npc_nukude_proto_h", NPC )
