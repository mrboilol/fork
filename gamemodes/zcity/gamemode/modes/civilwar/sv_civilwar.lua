MODE.name = "civilwar"
MODE.PrintName = "Civil War"

MODE.Chance = 0.05

MODE.LootSpawn = false

MODE.ForBigMaps = true

local consumables = {
    "weapon_bandage_sh",
}

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    return 1, true
end

util.AddNetworkString("civilwar_start")
util.AddNetworkString("civilwar_roundend")

function MODE:Intermission()
    game.CleanUpMap()

    for i, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        ply:SetupTeam(ply:Team())
    end

    net.Start("civilwar_start")
    net.Broadcast()
end

function MODE:CheckAlivePlayers()
    local unionPlayers = {}
    local confederatePlayers = {}

    for _, ply in ipairs(team.GetPlayers(0)) do
        if ply:Alive() and not ply:GetNetVar("handcuffed", false) then
            table.insert(unionPlayers, ply)
        end
    end

    for _, ply in ipairs(team.GetPlayers(1)) do
        if ply:Alive() and not ply:GetNetVar("handcuffed", false) then
            table.insert(confederatePlayers, ply)
        end
    end

    return {unionPlayers, confederatePlayers}
end

function MODE:EndRound()
    timer.Simple(2, function()
        net.Start("civilwar_roundend")
        net.WriteInt(0, 3)
        net.Broadcast()
    end)
end

function MODE:ShouldRoundEnd()
    local endround = zb:CheckWinner(self:CheckAlivePlayers())
    return endround
end

function MODE:RoundStart()
end

function MODE:GiveEquipment()
    local players = {}
    for _, ply in player.Iterator() do
        if ply:Team() ~= TEAM_SPECTATOR then
            players[#players + 1] = ply
        end
    end
    table.Shuffle(players)

    local numUnion = math.ceil(#players / 2)
    for i, ply in ipairs(players) do
        local isUnion = i <= numUnion
        ply:SetupTeam(isUnion and 0 or 1)
        ply:SetPlayerClass(isUnion and "north" or "confederate")
        zb.GiveRole(ply, isUnion and "Union Soldier" or "Confederate Soldier", isUnion and Color(127, 120, 255) or Color(139, 0, 0))

        local hands = ply:Give("weapon_hands_sh")
        ply:SelectWeapon(hands)

        local flintlock = ply:Give("weapon_flintlock")
        if IsValid(flintlock) then
            ply:GiveAmmo(5, flintlock:GetPrimaryAmmoType(), true)
        end

        local musket = ply:Give("weapon_musket")
        if IsValid(musket) then
            ply:GiveAmmo(5, musket:GetPrimaryAmmoType(), true)
        end

        for _, itemName in ipairs(consumables) do
            ply:Give(itemName)
        end
    end
end

function MODE:GetTeamSpawn()
    return zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_CT")),
           zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T"))
end

function MODE:RoundThink()
end

function MODE:CanLaunch()
    local activePlayers = 0

    for _, ply in player.Iterator() do
        if ply:Team() ~= TEAM_SPECTATOR then
            activePlayers = activePlayers + 1
        end
    end

    if activePlayers < 2 then
        return false
    end

    return true
end

return MODE
