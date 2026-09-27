local MODE = MODE

local respawnDelay = 5

function MODE:CanLaunch()
	return false
end

function MODE:Intermission()
	game.CleanUpMap()

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		ApplyAppearance(ply)
		ply:SetupTeam(0)
	end
end

local function giveBuilderLoadout(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	ply:SetSuppressPickupNotices(true)
	local handsClass = hg.GetHandsWeaponClass and hg.GetHandsWeaponClass(ply) or "weapon_hands_sh"
	ply:Give(handsClass)
	ply:Give("weapon_physgun")
	ply:Give("gmod_tool")
	ply:SelectWeapon(handsClass)
	ply:SetSuppressPickupNotices(false)
	zb.GiveRole(ply, "Builder", Color(60, 160, 255))
end

function MODE:RoundStart()
	for _, ply in player.Iterator() do
		giveBuilderLoadout(ply)
	end
end

function MODE:ShouldRoundEnd()
	return false
end

function MODE:CanSpawn()
	return true
end

function MODE:PlayerDeath(ply)
	timer.Create("zb_builder_respawn_" .. ply:EntIndex(), respawnDelay, 1, function()
		if not IsValid(ply) or ply:Alive() or zb.CROUND ~= "builder" or zb.ROUND_STATE ~= 1 then return end
		ply:Spawn()
		timer.Simple(0, function() giveBuilderLoadout(ply) end)
	end)
end

function MODE:GiveWeapons()
end

function MODE:GiveEquipment()
end

function MODE:RoundThink()
end

function MODE:EndRound()
end
