MODE.name = "criresp"
MODE.PrintName = "Crisis Response"
MODE.end_time = 15

MODE.ForBigMaps = false
MODE.ROUND_TIME = 480
MODE.Chance = 0.05

function MODE:OverrideBalance()
	return true
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
	return 1, true--returning true so guilt bans
end

local function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
end

local assigned = {}
local sniperPly = nil
local shieldGiven = false

function MODE:AssignTeams()
	local players = {}
	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then
			players[#players + 1] = ply
		end
	end
	local numPlayers = #players
	local numSWAT = 1
	if playing <= 4 then
		numSWAT = 1
	elseif playing <= 6 then
		numSWAT = 2
	elseif playing <= 9 then
		numSWAT = 3
	elseif playing <= 13 then
		numSWAT = 4
	elseif playing <= 17 then
		numSWAT = 5
	else
		numSWAT = 6
	end

	for i, ply in ipairs(players) do
		if not IsValid(ply) then continue end

		if i <= numSWAT then
			assigned[ply] = 0
		elseif i <= playing then
			assigned[ply] = 1
		else
			ply:ChatPrint("Crisis Response is limited to 20 players, you are spectating this round")
		end
	end

	if numSWAT >= 4 then
		sniperPly = players[1]
	end
end


local function CountReady()
	local ready, total = 0, 0
	for ply in pairs(assigned) do
		if not IsValid(ply) then assigned[ply] = nil continue end
		total = total + 1
		if ply.criresp_ready then ready = ready + 1 end
	end
	return ready, total
end

local function SyncReady()
	local ready, total = CountReady()

	net.Start("criresp_readycount")
		net.WriteUInt(ready, 8)
		net.WriteUInt(total, 8)
	net.Broadcast()

	if total > 0 and ready >= total and zb.ROUND_STATE == 0 then
		zb.START_TIME = math.min(zb.START_TIME or math.huge, CurTime() + 2)
	end
end

net.Receive("criresp_ready", function(len, ply)
	if zb.CROUND ~= "criresp" or zb.ROUND_STATE ~= 0 then return end
	if assigned[ply] == nil then return end

	ply.criresp_ready = true
	SyncReady()
end)

net.Receive("criresp_over20", function(len, ply)
	if not ply:IsAdmin() then return end
	overlimit:SetBool(net.ReadBool())
end)

net.Receive("criresp_custom", function(len, ply)
	local primary = net.ReadUInt(8)
	local groups = net.ReadString()
	if #groups > 48 then groups = "" end

	local gear, seen = {}, {}
	for i = 1, math.min(net.ReadUInt(4), gearslots) do
		local idx = net.ReadUInt(8)
		if gearlist[idx] and not seen[idx] then
			seen[idx] = true
			table.insert(gear, idx)
		end
	end

	ply.criresp_custom = {
		primary = (primary > 0 and primary <= #primaries) and primary or nil,
		groups = groups,
		gear = #gear > 0 and gear or nil
	}
end)

function MODE:Intermission()
	game.CleanUpMap()
    
    self:AssignTeams()

	self.submode = math.random(2) == 1 and "sobr" or "us"
	self.swatDeployed = false
	self.preparationActive = true
	self.preparationTime = self.submode == "us" and 60 or 30
	
	for k, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		if ply:Team() == 0 then
			ply:KillSilent()
			continue
		end

		ply.crirespDeploying = true
		ply:Spawn()
		ply.crirespDeploying = nil
		ply:SetupTeam(1)
	end

	net.Start("criresp_start")
	net.WriteString(self.submode)
	net.WriteUInt(self.preparationTime, 7)
	net.Broadcast()

	timer.Create("criresp_readysync", 3, 0, function()
		if zb.CROUND ~= "criresp" or zb.ROUND_STATE ~= 0 then
			timer.Remove("criresp_readysync")
			return
		end
		SyncReady()
	end)
end

function MODE:CheckAlivePlayers()
	local swatPlayers = {}
	local banditPlayers = {}

	for _, ply in ipairs(team.GetPlayers(0)) do
		if ply.criresp_sniper then continue end
		if ply:Alive() and not ply:GetNetVar("handcuffed", false) then
			table.insert(swatPlayers, ply)
		end
	end

	for _, ply in ipairs(team.GetPlayers(1)) do
		if ply:Alive() and not ply:GetNetVar("handcuffed", false) then
			table.insert(banditPlayers, ply)
		end
	end

	return {[0] = swatPlayers, [1] = banditPlayers}
end

function MODE:ShouldRoundEnd()
	if not self.swatDeployed then return end
	local aliveTeams = self:CheckAlivePlayers()
	local endround, winner = zb:CheckWinner(aliveTeams)
	return endround
end



function MODE:RoundStart()
    
end

local SWAT_PRESETS = {
	sobr = {
		{ name = "Light Medic",
			primary = "weapon_pp1901", atts = {"holo2", "supressor1"},
			secondary = "weapon_pl15",
			armor = {"ent_armor_vest_sobr3", "ent_armor_helmet_sobr3"},
			items = {"weapon_medkit_sh", "weapon_morphine", "weapon_adrenaline", "weapon_bigbandage_sh", "weapon_bandage_sh", "weapon_tourniquet"} },
		{ name = "Breacher",
			primary = "weapon_sr2", atts = {"holo7", "supressor1"},
			secondary = "weapon_pl15",
			armor = {"ent_armor_vest_sobr2", "ent_armor_helmet_sobr2", "ent_armor_visor_sobr2"},
			items = {"weapon_ram", "weapon_hg_smokenade", "weapon_hg_eft_zarya"},
			nodrop = {"weapon_ram"} },
		{ name = "Heavy",
			primary = "weapon_akz", atts = {"muzzle_545_recoil_2", "holo12", "stock_ak_evo"},
			secondary = "weapon_pl15",
			armor = {"ent_armor_vest_sobr1", "ent_armor_helmet_sobr2"},
			items = {"weapon_hg_eft_zarya", "weapon_hg_eft_rgd5"} },
		{ name = "Shield",
			primary = "weapon_ballistic_shield",
			secondary = "weapon_pl15",
			armor = {"ent_armor_vest_sobr1", "ent_armor_helmet_sobr1", "ent_armor_visor_sobr1"},
			items = {} },
	},
	us = {
		{ name = "Light Medic",
			primary = "weapon_mp5sd", atts = {"holo14"},
			secondary = "weapon_glock17",
			armor = {"ent_armor_vest8", "ent_armor_helmet10"},
			items = {"weapon_medkit_sh", "weapon_morphine", "weapon_adrenaline", "weapon_bigbandage_sh", "weapon_bandage_sh", "weapon_tourniquet"} },
		{ name = "Breacher",
			primary = "weapon_tx15", atts = {"holo8", "muzzle_556_recoil_1", "grip6"},
			secondary = "weapon_glock17",
			armor = {"ent_armor_vest12", "ent_armor_helmet15", "ent_armor_visor_caiman", "ent_armor_mandible_caiman"},
			items = {"weapon_ram", "weapon_hg_smokenade", "weapon_hg_eft_m67"},
			nodrop = {"weapon_ram"} },
		{ name = "Heavy",
			primary = "weapon_m4a1", atts = {"optic14", "stock_ar15_dd_enhanced", "supressor5"},
			secondary = "weapon_glock17",
			armor = {"ent_armor_helmet13", "ent_armor_vest11"},
			items = {"weapon_hg_eft_m67", "weapon_hg_eft_m7920"} },
		{ name = "Shield",
			primary = "weapon_ballistic_shield",
			secondary = "weapon_glock18c",
			armor = {"ent_armor_vest17", "ent_armor_helmet13", "ent_armor_visor_exfil_black", "ent_armor_earcovers_exfil_black"},
			items = {},
			noheadphones = true },
	},
}

local CRIM_PRESETS = {
	sobr = {
		{ name = "Medic",
			armor = {"ent_armor_vest5", "ent_armor_mask5"},
			items = {"weapon_medkit_sh", "weapon_morphine", "weapon_adrenaline", "weapon_bigbandage_sh", "weapon_bandage_sh", "weapon_tourniquet"} },
		{ name = "Medium",
			armor = {"ent_armor_vest9"},
			items = {} },
		{ name = "Heavy",
			primary = "weapon_akm", atts = {"mag6"}, nostock = true,
			armor = {"ent_armor_helmet29", "ent_armor_visor_maska", "ent_armor_vest10"},
			items = {"weapon_hg_pipebomb_tpik"} },
	},
	us = {
		{ name = "Medic",
			armor = {"ent_armor_vest2", "ent_armor_helmet20", "ent_armor_mask5"},
			items = {"weapon_medkit_sh", "weapon_morphine", "weapon_adrenaline", "weapon_bigbandage_sh", "weapon_bandage_sh", "weapon_tourniquet"} },
		{ name = "Standard",
			armor = {"ent_armor_vest26"},
			items = {} },
		{ name = "Heavy",
			primary = "weapon_m3super",
			armor = {"ent_armor_mask5", "ent_armor_vest26"},
			items = {"weapon_hg_type59_tpik"} },
	},
}

local CRIM_RANDOM_PRIMARIES_SOBR = {
	"weapon_ak74", "weapon_vpo136", "weapon_vpo209", "weapon_svt",
	"weapon_toz106", "weapon_m590a1", "weapon_mp5", "weapon_mp5k",
	"weapon_mp9", "weapon_uzi", "weapon_p90", "weapon_skorpion"
}

local CRIM_RANDOM_SECONDARIES_SOBR = {
	"weapon_pb", "weapon_zoraki", "weapon_p22", "weapon_px4beretta",
	"weapon_revolver2", "weapon_revolver357", "weapon_glock17"
}

local CRIM_RANDOM_PRIMARIES_US = {
	"weapon_adar215", "weapon_vpo101", "weapon_sks", "weapon_stm9",
	"weapon_vpo136", "weapon_m590a1", "weapon_870", "weapon_kedr",
	"weapon_uzi", "weapon_mp5k", "weapon_mp9"
}

local CRIM_RANDOM_SECONDARIES_US = {
	"weapon_glock17", "weapon_glock18c", "weapon_glock26",
	"weapon_m9beretta", "weapon_colt9mm"
}

local CRIM_SHARED_ITEMS = {
	"weapon_combatknife", "weapon_bandage_sh", "weapon_painkillers_tpik", "weapon_ducttape"
}

local function ShuffleIndexes(count)
	local t = {}
	for i = 1, count do t[i] = i end
	shuffle(t)
	return t
end

function MODE:GiveWeaponWithAmmo(ply, class, ammoMul, attachments)
	local gun = ply:Give(class)
	if IsValid(gun) and gun.GetMaxClip1 then
		if attachments and #attachments > 0 then
			hg.AddAttachmentForce(ply, gun, attachments)
		end
		ply:GiveAmmo(gun:GetMaxClip1() * ammoMul, gun:GetPrimaryAmmoType(), true)
	end
	return gun
end

function MODE:CanLaunch()
	local points = zb.GetMapPoints( "HMCD_CRI_CT" )
	local points2 = zb.GetMapPoints( "HMCD_CRI_T" )
	local plramount = zb:CheckPlaying()
	return (#points > 3) and (#points2 > 0) and (#plramount > 5)
end

local function GiveSuspect(ply)
	ply:SetSuppressPickupNotices(true)
	ply.noSound = true

	ply:SetPlayerClass("terrorist")
	zb.GiveRole(ply, "Suspect", Color(190, 0, 0))

	local gun = ply:Give(tblweps[1][math.random(#tblweps[1])])
	if IsValid(gun) and gun.GetMaxClip1 then
		ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
	else
		print("WTH???")
	end

	for _, item in ipairs(tblotheritems[1]) do
		ply:Give(item)
	end

	ply:Give("weapon_hands_sh")

	ply:SetSuppressPickupNotices(false)

	timer.Simple(0.5, function()
		if IsValid(ply) then ply.noSound = false end
	end)
end

local function SpawnSWAT(ply, swatPlayers)
	if not IsValid(ply) or ply:Team() ~= 0 then return end

	ply:Spawn()
	ply:Freeze(false)
	ply:SetSuppressPickupNotices(true)
	ply.noSound = true

	ply:SetupTeam(ply:Team())
	ply:SetPlayerClass("swat")

	local inv = ply:GetNetVar("Inventory")
	inv["Weapons"]["hg_sling"] = true
	ply:SetNetVar("Inventory", inv)

	hg.AddArmor(ply, tblarmors[0][math.random(#tblarmors[0])])
	ply:SetNetVar("HideArmorRender", true)
	zb.GiveRole(ply, "SWAT", Color(0, 0, 190))

	table.insert(swatPlayers, ply)

	local custom = ply.criresp_custom
	local primary = (custom and custom.primary) and primaries[custom.primary] or primaries[math.random(#primaries)]

	local gun = ply:Give(primary.wep)
	if IsValid(gun) and gun.GetMaxClip1 then
		hg.AddAttachmentForce(ply, gun, primary.atts)
		ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
	else
		print("WTH???")
	end

	local gun = ply:Give("weapon_glock17")
	if IsValid(gun) and gun.GetMaxClip1 then
		ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
	end

	ply:Give("weapon_handcuffs")

	for _, idx in ipairs((custom and custom.gear) or defaultgear) do
		local gear = gearlist[idx]
		if not gear then continue end

		if gear.item == "weapon_ballistic_shield" then
			if shieldGiven then
				ply:ChatPrint("Another operator already carries the shield")
				continue
			end
			shieldGiven = true
		end

		ply:Give(gear.item)
	end

	ply:Give("weapon_hands_sh")

	if custom and custom.groups and custom.groups ~= "" then
		local groups = string.Explode(" ", custom.groups)
		timer.Simple(0.15, function()
			if not IsValid(ply) or not ply:Alive() then return end
			for k = 0, ply:GetNumBodyGroups() - 1 do
				ply:SetBodygroup(k, tonumber(groups[k + 1]) or 0)
			end
		end)
	end

	ply:SetSuppressPickupNotices(false)
	ply.noSound = false
end

local function SpawnSniper(ply)
	if not IsValid(ply) or ply:Team() ~= 0 then return end

	ply:Spawn()
	ply:Freeze(false)
	ply:SetSuppressPickupNotices(true)
	ply.noSound = true

	ply:SetupTeam(ply:Team())
	ply:SetPlayerClass("swat")

	local pts = zb.GetMapPoints("SNIPERSPAWN_CRI")
	if pts and #pts > 0 then
		local pnt = pts[math.random(#pts)]
		if pnt and pnt.pos then ply:SetPos(pnt.pos) end
	end

	local inv = ply:GetNetVar("Inventory")
	inv["Weapons"]["hg_sling"] = true
	ply:SetNetVar("Inventory", inv)

	zb.GiveRole(ply, "SWAT Sniper", Color(0, 60, 220))

	local gun = ply:Give("weapon_m98b")
	if IsValid(gun) and gun.GetMaxClip1 then
		ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
	end

	ply:Give("weapon_bandage_sh")
	ply:Give("weapon_tourniquet")
	ply:Give("weapon_walkie_talkie")
	ply:Give("weapon_hands_sh")

	ply:SetSuppressPickupNotices(false)
	ply.noSound = false
end


local sniperZone = nil

local function BuildSniperZone()
	sniperZone = nil

	local pts = zb.GetMapPoints("SNIPERZONE_CRI")
	if not pts or #pts < 2 then return end

	local mins = Vector(math.huge, math.huge, math.huge)
	local maxs = Vector(-math.huge, -math.huge, -math.huge)

	for _, pnt in pairs(pts) do
		if not pnt.pos then continue end
		mins.x, mins.y, mins.z = math.min(mins.x, pnt.pos.x), math.min(mins.y, pnt.pos.y), math.min(mins.z, pnt.pos.z)
		maxs.x, maxs.y, maxs.z = math.max(maxs.x, pnt.pos.x), math.max(maxs.y, pnt.pos.y), math.max(maxs.z, pnt.pos.z)
	end

	mins.z = mins.z - 96
	maxs.z = maxs.z + 160

	sniperZone = {mins, maxs}
end

local function GetBody(ply)
	if IsValid(ply.FakeRagdoll) then return ply.FakeRagdoll end
	if IsValid(ply.OldRagdoll) and ply.OldRagdoll:IsRagdoll() then return ply.OldRagdoll end
	return ply
end

local function GetBonePos(body, boneName)
	local boneId = body:LookupBone(boneName)
	if not boneId then return end

	local matrix = body:GetBoneMatrix(boneId)
	return matrix and matrix:GetTranslation() or body:GetBonePosition(boneId)
end

--;; снайпера зовут джон зсити, он любит стрелять в плохих людей, он пережил многое но теперь он стоит на страже порядка славного городка зед, знайте если вы погибли выйдя из здание то это был именно он.
local function SniperShot(ply)
	local body = GetBody(ply)
	local headshot = math.random() <= 0.3

	local target = GetBonePos(body, headshot and "ValveBiped.Bip01_Head1" or "ValveBiped.Bip01_Spine2")
		or body:WorldSpaceCenter()

	local losFilter = {ply, body}

	local src
	for i = 1, 12 do
		local ang = math.Rand(0, math.pi * 2)
		local dist = math.Rand(1200, 2500)
		local test = target + Vector(math.cos(ang) * dist, math.sin(ang) * dist, math.Rand(300, 900))

		local tr = util.TraceLine({start = test, endpos = target, mask = MASK_SHOT, filter = losFilter})
		if tr.Fraction >= 0.98 then
			src = test
			break
		end
	end

	src = src or target + Angle(0, math.Rand(0, 360), 0):Forward() * 64 + Vector(0, 0, 40)

	local attacker = (IsValid(sniperPly) and sniperPly:Alive()) and sniperPly or game.GetWorld()

	game.GetWorld():FireLuaBullets({
		Attacker = attacker,
		Inflictor = game.GetWorld(),
		Src = src,
		Dir = (target - src):GetNormal(),
		Damage = 180,
		Force = 60,
		Num = 1,
		Spread = vector_origin,
		Tracer = 1,
		AmmoType = ".338 Lapua Magnum",
		Penetration = 32.2,
		Diameter = 8.6,
		penetrated = 0,
		limit_ricochet = 0,
		dmgtype = DMG_BULLET,
		DisableLagComp = true,
		Distance = 8000
	})

	sound.Play("mosin/mosin_dist.ogg", src, 120, math.random(95, 105))
end

local function SniperZoneThink()
	if not sniperZone then return end

	local outside = {}
	for _, ply in ipairs(team.GetPlayers(1)) do
		if not ply:Alive() or ply:GetNetVar("handcuffed", false) then continue end
		if GetBody(ply):GetPos():WithinAABox(sniperZone[1], sniperZone[2]) then continue end
		table.insert(outside, ply)
	end

	local cooldown = #outside > 1 and math.max(0.6, 2.5 / #outside) or 2.5

	for _, ply in ipairs(outside) do
		if (ply.criresp_nextsnipe or 0) > CurTime() then continue end

		ply.criresp_nextsnipe = CurTime() + cooldown
		SniperShot(ply)
	end
end

function MODE:RoundStart()
	timer.Remove("criresp_readysync")
	shieldGiven = false

	net.Start("criresp_begin")
	net.Broadcast()

	local swatPlayers = {}

	for ply, teamID in pairs(assigned) do
		if not IsValid(ply) then continue end

		if teamID == 0 then
			ply:SetTeam(0)

			if ply == sniperPly then
				ply.criresp_sniper = true
				timer.Create("SWATSpawn" .. ply:EntIndex(), 90, 1, function()
					SpawnSniper(ply)
				end)
			else
				timer.Create("SWATSpawn" .. ply:EntIndex(), 90, 1, function()
					SpawnSWAT(ply, swatPlayers)
				end)
			end
		else
			ply:SetTeam(1)
			ply:Spawn()
			ply:Freeze(false)
			ply:SetupTeam(1)
			GiveSuspect(ply)
		end
	end

	timer.Create("SWATSpawn", 91, 1, function()
		if #swatPlayers > 0 then
			local ramPlayer = swatPlayers[math.random(#swatPlayers)]
			if not IsValid(ramPlayer) or ramPlayer:Team() == TEAM_SPECTATOR then return end
			ramPlayer:Give("weapon_ram")
		end
	end)

	BuildSniperZone()
	timer.Create("criresp_sniperzone", 0.5, 0, function()
		if zb.CROUND ~= "criresp" or zb.ROUND_STATE ~= 1 then return end
		SniperZoneThink()
	end)
end

function MODE:GiveEquipment()
	timer.Simple(0.5,function()
		local submode = self.submode or "sobr"
		local swatPresets = SWAT_PRESETS[submode]
		local swatIdx = ShuffleIndexes(#swatPresets)
		local swatCount = 0
		local crimPresets = CRIM_PRESETS[submode]
		local crimIdx = ShuffleIndexes(#crimPresets)
		local crimCount = 0
		local randPrimaries = submode == "us" and CRIM_RANDOM_PRIMARIES_US or CRIM_RANDOM_PRIMARIES_SOBR
		local randSecondaries = submode == "us" and CRIM_RANDOM_SECONDARIES_US or CRIM_RANDOM_SECONDARIES_SOBR

		for i, ply in player.Iterator() do
			if ply:Team() == TEAM_SPECTATOR then continue end

			if ply:Team() == 0 then
				local preset = swatPresets[swatIdx[(swatCount % #swatIdx) + 1]]
				swatCount = swatCount + 1

				if !IsValid(ply) or ply:Team() == TEAM_SPECTATOR then continue end
				local timerName = "SWATSpawn" .. ply:EntIndex()
				local preparationTime = self.preparationTime or (submode == "us" and 60 or 30)
				timer.Create(timerName, preparationTime, 1, function()
					if not IsValid(ply) or CurrentRound() ~= self or self.submode ~= submode or ply:Team() ~= 0 then return end

					ply.crirespDeploying = true
					ply:Spawn()
					ply.crirespDeploying = nil
					ply:SetSuppressPickupNotices(true)
					ply.noSound = true
					ply:SetupTeam(0)
					ply:SetPlayerClass("swat")

					local inv = ply:GetNetVar("Inventory", {})
					inv["Weapons"] = inv["Weapons"] or {}
					inv["Weapons"]["hg_sling"] = true
					ply:SetNetVar("Inventory", inv)

					hg.AddArmor(ply, preset.armor)
					if not preset.noheadphones then
						hg.AddArmor(ply, "headphones1")
					end

					zb.GiveRole(ply, submode == "sobr" and "SOBR" or "US Special Forces", submode == "sobr" and Color(0,0,190) or Color(0,90,190))

					if preset.primary then
						self:GiveWeaponWithAmmo(ply, preset.primary, 3, preset.atts)
					end

					if preset.secondary then
						self:GiveWeaponWithAmmo(ply, preset.secondary, 2)
					end

					for _, item in ipairs(preset.items) do
						local w = ply:Give(item)
						if preset.nodrop and table.HasValue(preset.nodrop, item) and IsValid(w) then
							w.NoDrop = true
							w.bigNoDrop = true
						end
					end

					if submode == "us" and not ply:HasWeapon("weapon_medkit_sh") then
						ply:Give("weapon_medkit_sh")
					end

					ply:Give("weapon_hands_sh")
					ply:SetSuppressPickupNotices(false)
					ply.noSound = false
					self.swatDeployed = true
					self.preparationActive = false
				end)
			else
				local preset = crimPresets[crimIdx[(crimCount % #crimIdx) + 1]]
				crimCount = crimCount + 1

				local roleName, roleColor = "Chechen Terrorist", Color(190,0,0)
				if submode == "us" then
					roleName, roleColor = "Armed Robber", Color(190,80,0)
				end

				ply:SetSuppressPickupNotices(true)
				ply.noSound = true

				ply:SetPlayerClass("terrorist")

				zb.GiveRole(ply, roleName, roleColor)

				if preset.primary then
					local gun = self:GiveWeaponWithAmmo(ply, preset.primary, 3, preset.atts)
					if preset.nostock and IsValid(gun) then
						gun.attachments = gun.attachments or {}
						gun.attachments.stock = {}
						if gun.UpdateAttachmentModifiers then
							gun:UpdateAttachmentModifiers()
						end
					end
				else
					self:GiveWeaponWithAmmo(ply, randPrimaries[math.random(#randPrimaries)], 3)
					self:GiveWeaponWithAmmo(ply, randSecondaries[math.random(#randSecondaries)], 2)
				end

				if preset.armor then
					hg.AddArmor(ply, preset.armor)
				end

				for _, item in ipairs(CRIM_SHARED_ITEMS) do
					ply:Give(item)
				end

				for _, item in ipairs(preset.items) do
					ply:Give(item)
				end

				local hands = ply:Give("weapon_hands_sh")

				ply:SetSuppressPickupNotices(false)
				ply.noSound = false
			end

			timer.Simple(0.5,function()
				ply.noSound = false
			end)

			ply:SetSuppressPickupNotices(false)
		end
	end)
end

function MODE:RoundThink()
end

function MODE:GetTeamSpawn()
	return zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_CRI_CT")), zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_CRI_T"))
end

function MODE:CanSpawn()
end

function MODE:EndRound()
	self.preparationActive = false
	self.swatDeployed = false

	if zb.SKIP_END_PRESENTATION then
		zb.SKIP_END_PRESENTATION = false
		zb.SHOULD_FADE = true
		zb.END_TIME = nil
	end

	for k,ply in player.Iterator() do
		if timer.Exists("SWATSpawn"..ply:EntIndex()) then
			timer.Remove("SWATSpawn"..ply:EntIndex())
		end
	end

	local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
	-- Criminals defend the map, so they win if time expires or both teams are eliminated.
	if winner ~= 0 and winner ~= 1 then winner = 1 end

	net.Start("cri_roundend")
		net.WriteBool(winner == 1)
	net.Broadcast()

	for k, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		if ply:Team() == winnerTeam then
			ply:GiveExp(math.random(15, 30))
			ply:GiveSkill(math.Rand(0.1, 0.15))
		else
			ply:GiveSkill(-math.Rand(0.05, 0.1))
		end
	end

	table.Empty(assigned)
end

function MODE:PlayerDeath(ply)
end

function MODE:PlayerSpawn(ply)
	if not self.preparationActive or ply:Team() ~= 0 or self.swatDeployed or ply.crirespDeploying then return end

	timer.Simple(0, function()
		if IsValid(ply) and ply:Alive() and CurrentRound() == self and not self.swatDeployed then
			ply:KillSilent()
		end
	end)
end
