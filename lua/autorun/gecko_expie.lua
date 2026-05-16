list.Set( "PlayerOptionsModel", "Gecko's Expie", "models/assassingecko/geckoexpie/geckoexpie.mdl" )
player_manager.AddValidModel( "Gecko's Expie", "models/assassingecko/geckoexpie/geckoexpie.mdl" )
player_manager.AddValidHands( "Gecko's Expie", "models/assassingecko/geckoexpie/geckoexpiearms.mdl", 0, "00000000" )

list.Set( "PlayerOptionsModel", "Gecko's Expie Fem", "models/assassingecko/geckoexpie/femgeckoexpie.mdl" )
player_manager.AddValidModel( "Gecko's Expie Fem", "models/assassingecko/geckoexpie/femgeckoexpie.mdl" )
player_manager.AddValidHands( "Gecko's Expie Fem", "models/assassingecko/geckoexpie/geckoexpiearms.mdl", 0, "00000000" )

hook.Add("PreDrawPlayerHands", "Gecko Expie hands", function(hands, vm, ply, wpn)
    if IsValid(hands) and hands:GetModel() == "models/assassingecko/geckoexpie/geckoexpiearms.mdl" then
        hands:SetSkin(ply:GetSkin())

        local handWarmersGroup = 1
        local modelWarmersGroup = ply:GetBodygroup(2)

        local handHoodieGroup = 2
        local modelHoodieGroup = ply:GetBodygroup(4)

        local handRForearmBandageGroup = 3
        local modelRForearmBandageGroup = ply:GetBodygroup(15)

        local handLForearmBandageGroup = 4
        local modelLForearmBandageGroup = ply:GetBodygroup(16)

        local handRHandBandageGroup = 5
        local modelRHandBandageGroup = ply:GetBodygroup(17)

        local handLHandBandageGroup = 6
        local modelLHandBandageGroup = ply:GetBodygroup(18)

        if modelWarmersGroup == 1 then
            hands:SetBodygroup(handWarmersGroup, 1)
        elseif modelWarmersGroup == 2 then
            hands:SetBodygroup(handWarmersGroup, 2)
        elseif modelWarmersGroup == 3 then
            hands:SetBodygroup(handWarmersGroup, 3)
        elseif modelWarmersGroup == 4 then
            hands:SetBodygroup(handWarmersGroup, 4)
        else
            hands:SetBodygroup(handWarmersGroup, 0)
        end

        if modelHoodieGroup == 1 then
            hands:SetBodygroup(handHoodieGroup, 1)
        elseif modelHoodieGroup == 2 then
            hands:SetBodygroup(handHoodieGroup, 2)
        elseif modelHoodieGroup == 3 then
            hands:SetBodygroup(handHoodieGroup, 3)
        else
            hands:SetBodygroup(handHoodieGroup, 0)
        end

        if modelRForearmBandageGroup == 1 then
            hands:SetBodygroup(handRForearmBandageGroup, 1)
        else 
            hands:SetBodygroup(handRForearmBandageGroup, 0)
        end

        if modelLForearmBandageGroup == 1 then
            hands:SetBodygroup(handLForearmBandageGroup, 1)
        else 
            hands:SetBodygroup(handLForearmBandageGroup, 0)
        end

        if modelRHandBandageGroup == 1 then
            hands:SetBodygroup(handRHandBandageGroup, 1)
        else 
            hands:SetBodygroup(handRHandBandageGroup, 0)
        end

        if modelLHandBandageGroup == 1 then
            hands:SetBodygroup(handLHandBandageGroup, 1)
        else 
            hands:SetBodygroup(handLHandBandageGroup, 0)
        end

    end
end)

local Category = "Wemi"        

local NPC =
{
	Name = "Gecko's Expie (Friendly)",                         
	Class = "npc_citizen",                           
	Health = "100",                                  
	KeyValues = { citizentype = 4, },                 
	Model = "models/assassingecko/geckoexpie/geckoexpie_npc.mdl",  
	Weapons = { "weapon_ar2","weapon_smg1","weapon_pistol","weapon_shotgun","weapon_rpg" },         
	Category = Category
}

list.Set( "NPC", "Gecko's Expie (Friendly)", NPC )                       

local NPC =
{
	Name = "Gecko's Expie (Hostile)",                          
	Class = "npc_combine_s",                         
	Health = "100",   
	Numgrenades = "4",                                                            
	Model = "models/assassingecko/geckoexpie/geckoexpie_npc_hostile.mdl",   
	Weapons = { "weapon_ar2","weapon_smg1","weapon_pistol","weapon_shotgun","weapon_rpg" },         
	Category = Category
}

list.Set( "NPC", "Gecko's Expie (Hostile)", NPC ) 
