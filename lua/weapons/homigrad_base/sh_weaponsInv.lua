hg = hg or {}
hg.ZCityInventoryAddonEnabled = true
hg.ZCityInventoryAddonFileGuards = hg.ZCityInventoryAddonFileGuards or {}
if hg.ZCityInventoryAddonFileGuards["weaponInv"] then return end
hg.ZCityInventoryAddonFileGuards["weaponInv"] = true
hg.ZCityInventoryAddonLoaded = true

hg.weaponInv = hg.weaponInv or {}
local weaponInv = hg.weaponInv
local ammoType

function weaponInv.CanInsert(ply, wep)
	local category = wep.weaponInvCategory
	if not category then return true end
	local slot = (CLIENT and weaponInv.invWeapon[category]) or (SERVER and ply.weaponInv[category])
	
	if not slot then return true end

	if #slot + 1 > slot.limit then return false end
	return slot
end

if SERVER then
	function weaponInv.CreateLimit(ply, i, count)
		local tbl = {
			limit = count
		}

		ply.weaponInv[i] = tbl
	end

	function weaponInv.CreateLimitAmmo(ply, ammoType, count)
		ammoType = game.GetAmmoID(ammoType)
		ply.ammoInv[ammoType] = count
	end

	local function Remove(self, slot)
		local id
		for i = 1, #slot do
			if slot[i] == wep then
				id = i
				break
			end
		end

		if not id then --lol
			return
		end

		table.remove(slot, id)
		weaponInv.Sync(self:GetOwner())
	end

	function weaponInv.Insert(ply, wep)
		local slot = weaponInv.CanInsert(ply, wep)
		if slot == true then return true end
		if slot == nil then return true end
		if slot == false then return false end
		slot[#slot + 1] = wep
		wep:CallOnRemove("weaponInv", Remove, slot)
		return true
	end
	
	function weaponInv.Remove(ply, wep)
		local id, slot
		if not ply.weaponInv then return end
		for category, _slot in pairs(ply.weaponInv) do
			for i = 1, #_slot do
				if _slot[i] == wep then
					slot = _slot
					id = i
					break
				end
			end

			if id then break end
		end

		if not id then return end
		wep:RemoveCallOnRemove("weaponInv")
		table.remove(slot, id)
		return true
	end

	hook.Add("Player Spawn", "homigrad-weapons-inv2", function(ply)
		ply.weaponInv = ply.weaponInv or {}
		ply.ammoInv = ply.weaponInv or {}
		for k in pairs(ply.weaponInv) do
			ply.weaponInv[k] = nil
		end

		for k in pairs(ply.ammoInv) do
			ply.ammoInv[k] = nil
		end

		if hook.Run("WeaponsInv Loadout", ply) == nil then
			weaponInv.CreateLimit(ply, 1, 1) --main
			weaponInv.CreateLimit(ply, 2, 2) --secondary
			weaponInv.CreateLimit(ply, 3, 1) --melee
			weaponInv.CreateLimit(ply, 4, 1) --traitor 22lr gun
			weaponInv.CreateLimit(ply, 5, 1) --traitor knife
			weaponInv.CreateLimit(ply, 6, 1) --heavy melee
		end

		weaponInv.Sync(ply)
	end)

	hook.Add("WeaponEquip", "homigrad", function(wep, ply)
		if weaponInv.Insert(ply, wep) then
			weaponInv.Sync(ply)
			return
		end
	end)

	hook.Add("PlayerDroppedWeapon", "homigrad-weaponInv", function(ply, wep)
		weaponInv.Remove(ply, wep)
		weaponInv.Sync(ply)
	end)

	hook.Add("PlayerCanPickupWeapon", "homigrad-weapons", function(ply, wep)
		if wep.init and ((ply:GetUseEntity() ~= wep or not ply:KeyPressed(IN_USE)) and not ply.force_pickup) then return false end
		if wep.init and wep.IsSpawned and ((ply.cooldown_grab or 0) > CurTime()) and not ply.force_pickup then return false end
		if wep.PickupFunc and (wep:PickupFunc(ply) == true) then return false end

		if ( ply:HasWeapon( wep:GetClass() ) ) then
			if wep:Clip1() > 0 and ishgweapon(wep) then
				local ammo = wep:Clip1()
				ply:GiveAmmo(ammo, wep:GetPrimaryAmmoType(), true)
				wep:SetClip1(0)
				ply:EmitSound("panoptisscon/mag_unload.mp3", 65)
				ply.cooldown_grab = CurTime() + 0.1
			elseif (wep:GetClass() == "weapon_hg_bow" and not wep.Initialzed) then
				ply:GiveAmmo(1, wep.Ammo, true)
				wep.Initialzed = true
				wep:EmitSound("weapons/bow_deerhunter/arrow_fetch_0"..math.random(4)..".wav")
				ply:EmitSound("weapons/bow_deerhunter/arrow_load_0"..math.random(3)..".wav", 60)
				ply.cooldown_grab = CurTime() + 0.1
			end
			return false
		end
		
		if weaponInv.CanInsert(ply, wep) == false then
			local wep = ply.weaponInv[wep.weaponInvCategory][1]
			
			if IsValid(wep) then
				ply:DropWeapon(wep)
				wep.IsSpawned = true
				wep.init = true
			end

			ply.cooldown_grab = CurTime() + 0.1
			return true
		end
		ply.cooldown_grab = CurTime() + 0.1
	end)

	util.AddNetworkString("weaponInv")
	local packet = {}
	function weaponInv.Sync(ply)
		if ply:IsNPC() then return end
		net.Start("weaponInv")
		packet[1] = ply.weaponInv
		packet[2] = ply.ammoInv
		net.WriteTable(packet)
		net.Send(ply)
	end
else
	weaponInv.invWeapon = weaponInv.invWeapon or {}
	weaponInv.invAmmo = weaponInv.invAmmo or {}
	local invWeapon = weaponInv.invWeapon
	local invAmmo = weaponInv.invAmmo
	net.Receive("weaponInv", function()
		local packet = net.ReadTable()
		for k in pairs(invWeapon) do
			invWeapon[k] = nil
		end

		for k in pairs(invAmmo) do
			invAmmo[k] = nil
		end

		for k, v in pairs(packet[1]) do
			invWeapon[k] = v
		end

		for k, v in pairs(packet[2]) do
			invAmmo[k] = v
		end
	end)

	concommand.Add("hg_listammo", function() PrintTable(game.GetAmmoTypes()) end)
	concommand.Add("hg_weaponInv_table", function() PrintTable(weaponInv) end)
end
if SERVER then
    local function ZCitySetPlayerPosture(ply, pos)
        if not IsValid(ply) then return end
        if hg and hg.SetPlayerPosture then
            hg.SetPlayerPosture(ply, pos, true)
        else
            ply.posture = pos
        end
    end

    local function ZCityShouldUseLowReady(wep)
        if not IsValid(wep) or not wep:IsWeapon() then return false end
        if wep.ZCityNoDeployLowReady then return false end

        local class = wep:GetClass()
        if class == "weapon_hands" or class == "weapon_hands_sh" or class == "gmod_tool" or class == "weapon_physgun" or class == "weapon_physcannon" then return false end

        if isfunction(ishgweapon) then
            return ishgweapon(wep)
        end

        return true
    end

    local function ZCityPutWeaponLowReady(ply, wep)
        if not (hg and hg.ZCityInventoryAddonEnabled) then return end
        if not IsValid(ply) or not ply:IsPlayer() or not IsValid(wep) then return end
        if ply:GetActiveWeapon() ~= wep then return end
        if not ZCityShouldUseLowReady(wep) then return end

        wep.ZCityResetLowReadyOnFirstAim = true
        ply.ZCityBackpackResetLowReadyWep = wep
        ply.ZCityBackpackResetLowReadyUntil = nil
        ZCitySetPlayerPosture(ply, 4)
    end

    hook.Add("PlayerSwitchWeapon", "ZCityLowReadyOnEveryWeaponTake", function(ply, oldWeapon, newWeapon)
        timer.Simple(0, function()
            ZCityPutWeaponLowReady(ply, newWeapon)
        end)
    end)

    hook.Add("WeaponEquip", "ZCityLowReadyOnWeaponEquip", function(wep, ply)
        timer.Simple(0, function()
            ZCityPutWeaponLowReady(ply, wep)
        end)
    end)

    hook.Add("StartCommand", "ZCityResetLowReadyOnAim", function(ply, cmd)
        if not (hg and hg.ZCityInventoryAddonEnabled) then return end
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if not (cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)) then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or not wep.ZCityResetLowReadyOnFirstAim then return end
        if ply.posture ~= 4 then return end

        wep.ZCityResetLowReadyOnFirstAim = nil
        ply.ZCityBackpackResetLowReadyWep = nil
        ply.ZCityBackpackResetLowReadyUntil = nil
        ZCitySetPlayerPosture(ply, 0)
    end)
end
