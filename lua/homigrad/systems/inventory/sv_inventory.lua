local blackList = {
    ["weapon_hands_sh"] = true,
    ["weapon_hg_coolhands"] = true,
    ["weapon_zombclaws"] = true
}

local META = getmetatable("PLAYER")
META.inventory = {
    Weapons = {},
    Ammo = {},
    Armor = {},
    Attachments = {}
}
META.armors = {}

function hg.CreateInv(ply)
    ply.inventory = {}
    local inv = ply.inventory
    inv.Weapons = {}
    for i, wep in ipairs(ply:GetWeapons()) do
        if blackList[wep:GetClass()] then continue end
		local class = hg.CanonicalWeaponClass(wep:GetClass())
        inv.Weapons[class] = wep--wep.GetInfo and wep:GetInfo() or true
    end

    inv.Ammo = ply:GetAmmo()
    inv.Armor = {}
    inv.Attachments = {}
    ply:SetNetVar("Inventory", inv)
end

function hg.RenewInv(ply, isDead, deathRagdoll)
    ply.inventory = ply.inventory or {}
    local inv = ply.inventory
    inv.Weapons = inv.Weapons or {}

    local sling = inv.Weapons["hg_sling"] -- Вот бы все это автоматизировать
    local kastet = inv.Weapons["hg_brassknuckles"]
    local flashlight = inv.Weapons["hg_flashlight"]

    inv.Weapons = {}

    for i, wep in pairs(ply:GetWeapons()) do
        if blackList[wep:GetClass()] then continue end
        if not isDead then
			local class = hg.CanonicalWeaponClass(wep:GetClass())
            inv.Weapons[class] = wep--wep.GetInfo and wep:GetInfo() or true
        else
            ply.nohook = true
            ply:DropWeapon(wep)

            wep:SetNoDraw(true)
            wep:DrawShadow(false)
            wep:AddSolidFlags(FSOLID_NOT_SOLID)

            local rag = IsValid(deathRagdoll) and deathRagdoll or ply:GetNWEntity("RagdollDeath")

            if IsValid(rag) then
				wep:SetPos(rag:GetPos())
                wep:SetParent(rag, 0)
            else
                wep:SetParent(NULL)
                wep:SetPos(ply:GetPos() + vector_up * -10000)
            end

			local class = hg.CanonicalWeaponClass(wep:GetClass())
            inv.Weapons[class] = wep
        end
    end

    inv.Weapons["hg_sling"] = sling
    inv.Weapons["hg_brassknuckles"] = kastet
    inv.Weapons["hg_flashlight"] = flashlight
    inv.Ammo = ply:GetAmmo()
    inv.Armor = inv.Armor or {}
    inv.Attachments = inv.Attachments or {}
    ply:SetNetVar("Inventory", inv)
end

hook.Add("Player Spawn", "homigrad-inventory", function(ply)
    hg.CreateInv(ply)
    ply.armors = {}
    ply.armors_health = {}
    ply:SyncArmor()
end)

hook.Add("WeaponEquip", "homigrad-inventory", function(wep, ply)
    local inv = ply.inventory or {}
    if blackList[wep:GetClass()] then return end

    wep:SetNoDraw(false)

    inv.Weapons = inv.Weapons or {}
	local class = hg.CanonicalWeaponClass(wep:GetClass())
    inv.Weapons[class] = wep
    
    if wep.sling then
        wep.sling = nil
        if not inv["Weapons"]["hg_sling"] then
            inv["Weapons"]["hg_sling"] = true
            ply:ChatPrint("You took the sling the weapon was attached to.")
        else
            local sling = ents.Create("hg_sling")
            sling:SetPos(ply:EyePos())
            sling:SetVelocity(ply:GetAimVector() * 5)
            sling:Spawn()
            ply:ChatPrint("You deattached the sling the weapon was connected to.")
        end
    end

    ply:SetNetVar("Inventory", inv)
end)

hook.Add("PlayerDroppedWeapon", "homigrad-inventory", function(ply, wep)
    local inv = ply.inventory or {}
    if ply:IsNPC() then return end
    if blackList[wep:GetClass()] then return end
    if not inv.Weapons or not inv.Weapons[wep:GetClass()] then return end
    if ply.nohook then ply.nohook = nil return end
    inv.Weapons[wep:GetClass()] = nil
    ply:SetNetVar("Inventory", inv)
end)

hook.Add("PlayerAmmoChanged", "homigrad-inventory", function(ply,ammoID,oldcount,newcount)
    if not ply.inventory then return end
    ply.inventory.Ammo = ply:GetAmmo()
    ply:SetNetVar("Inventory", ply.inventory)

    if game.GetAmmoName(ammoID) == "Grenade" then

        local wep = ply:Give("weapon_hg_hl2nade_tpik")
        wep.DontEquipInstantly = true
        wep.count = newcount-oldcount
        ply:SetAmmo(0,ammoID)

        timer.Simple(0.1,function()
            wep.DontEquipInstantly = nil
        end)
    end
end)

local vecZero = Vector(0, 0, 0)
hook.Add("PlayerDropWeapon", "homigrad-inventory", function(ply, weapon)
    local wep = IsValid(weapon) and weapon or ply:GetActiveWeapon()
    if not IsValid(wep) or wep.NoDrop then return end
    local eyeAngles = ply:EyeAngles()
    eyeAngles.x = 0
    local ent = hg.GetCurrentCharacter(ply)
    local bon = ent:LookupBone("ValveBiped.Bip01_R_Hand")

    if wep.RemoveFake then wep:RemoveFake() end
    hg.SafeSetCollisionGroup(wep, COLLISION_GROUP_WORLD)
    hg.SafeCollisionRulesChanged(wep)
    ply:DropWeapon(wep, ply:EyePos(), vecZero)
    wep:SetPos(ply:EyePos())
    ply.inventory.Weapons[wep:GetClass()] = nil
    ply:SetNetVar("Inventory", ply.inventory)
    ply:SetActiveWeapon(NULL)
	if ply.organism and ishgweapon(wep) then ply.organism.postureGunfireWeapon = wep end

    if ply:Alive() then
        wep:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        wep.IsSpawned = true
        return
    end

    timer.Simple(0.1,function()
        if not IsValid(wep) then return end
        if not IsValid(ply) then return end
        local ent = IsValid(ply:GetNWEntity("RagdollDeath")) and ply:GetNWEntity("RagdollDeath") or ply.FakeRagdoll
        if not IsValid(ent) then return end
        local bon = ent:LookupBone("ValveBiped.Bip01_R_Hand")
        local handpos,handang = ent:GetPos(),ent:GetAngles()
        if bon then
            local phys = ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(bon))
            if IsValid(phys) then
                handpos = phys:GetPos()
                handang = phys:GetAngles()
            end
        end

        local localpos,localang = LocalToWorld(wep.WorldPos and wep.WorldPos + Vector(3.5,0,0) or vector_origin,wep.WorldAng or angle_zero,handpos,handang)
        localang:RotateAroundAxis(localang:Forward(),180)
        wep:SetPos(localpos)
        wep:SetAngles(localang)
        wep:SetVelocity(vector_origin)
        hg.SafeSetCollisionGroup(wep, COLLISION_GROUP_WEAPON)
        hg.SafeCollisionRulesChanged(wep)

        local physbone = ent:TranslateBoneToPhysBone(bon)
        local physbonetorso = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Spine2"))

        local cons = constraint.Weld(wep, ent, 0, physbone, 600, true, false)
		if ply.organism and ishgweapon(wep) then ply.organism.postureGunfireWeapon = wep end

        if math.random(1,10) <= 2 then
            timer.Simple(4, function()
                timer.Simple(0, function()
                    local cons2 = constraint.NoCollide(wep, ent, 0, 0)
                end)
                if IsValid(cons) then
                    cons:Remove()
                    cons = nil
                end
            end)
        end

        local enta = ply:Alive() and (ply.organism and !ply.organism.otrub) and ply or ent
        local inv = enta:GetNetVar("Inventory",{})
        if not inv["Weapons"] then return end
        if inv["Weapons"]["hg_sling"] and ishgweapon(wep) and not wep:IsPistolHoldType() then
            local rope = constraint.Rope(wep,ent,0,physbonetorso,vector_origin,vector_origin,10,5,0,0,"null",true,color_white)
            wep.sling = true
            ent.rope_attach = wep
            inv["Weapons"]["hg_sling"] = nil
            enta:SetNetVar("Inventory",inv)
        end
    end)
end)

hook.Add("PlayerLoadout", "giveHands", function(ply)
    local class = hg.GetHandsWeaponClass and hg.GetHandsWeaponClass(ply) or "weapon_hg_coolhands"
    local hands = ply:GetWeapon(class)
    if not IsValid(hands) then
        hands = ply:Give(class)
    end
    local otherClass = class == "weapon_hg_coolhands" and "weapon_hands_sh" or "weapon_hg_coolhands"
    if ply:HasWeapon(otherClass) then
        ply:StripWeapon(otherClass)
    end
    if IsValid(hands) then
        ply:SelectWeapon(hands:GetClass())
    end
    return true
end)

hook.Add("DoPlayerDeath", "homigrad-inventory", function(ply)
    hook.Run("PlayerDropWeapon", ply)
end)

function hg.TransferItems(ply,ragdoll)
	if IsValid(ragdoll) then
		local inv = ply:GetNetVar("Inventory",{})
		--if inv["Weapons"] then
		--	for wep,tbl in pairs(inv["Weapons"]) do
		--		local weapon = weapons.Get(wep)
		--		if weapon and weapon.holsteredBone and not weapon.shouldntDrawHolstered then
		--			tbl[3] = true
		--		end
		--	end
		--end
		ragdoll.inventory = inv
		ragdoll:SetNetVar("Inventory",ragdoll.inventory)
		-- ragdoll:SetNetVar("zb_Scrappers_RaidMoney",ply:GetNetVar("zb_Scrappers_RaidMoney"))

		hg.CreateInv(ply)
		ply:SetNetVar("Inventory",{})
		ply.inventory = ply:GetNetVar("Inventory",{})

        hook.Run("ItemsTransfered",ply,ragdoll)

		ragdoll:SetNetVar("Armor",ply.armors)
		ragdoll.armors = ragdoll:GetNetVar("Armor",{})
		ragdoll:SetNetVar("HideArmorRender", ply:GetNetVar("HideArmorRender", false))
		
		ply:SetNetVar("Armor",{})
		ply.armors = ply:GetNetVar("Armor",{})
		
		hg.SyncWeapons()
	end
end

hook.Add("PostPlayerDeath", "homigrad-inventory", function(ply)
    local ragdoll = ply:GetNWEntity("RagdollDeath")
    hg.RenewInv(ply, true, ragdoll)
    hg.TransferItems(ply, ragdoll)
    ply:SetNetVar("Inventory", ply.inventory)
    if IsValid(ragdoll) then ragdoll:SetNetVar("Inventory", ragdoll.inventory) end

    --ply:StripWeapons() -- WTF
    ply:SetNetVar("Armor",{})
    ply:SetNetVar("Inventory",{})
    ply:RemoveAllAmmo()
end)

local lootDropMins = Vector(-8, -8, 0)
local lootDropMaxs = Vector(8, 8, 16)

local function GetLootDropPosition(ply, source)
    local forward = ply:EyeAngles():Forward()
    forward.z = 0
    if forward:LengthSqr() > 0 then forward:Normalize() end

    local start = ply:GetPos() + forward * 32 + Vector(0, 0, 32)
    local trace = util.TraceHull({
        start = start,
        endpos = start - Vector(0, 0, 96),
        mins = lootDropMins,
        maxs = lootDropMaxs,
        filter = {ply, source},
        mask = MASK_SOLID
    })

    return trace.HitPos + trace.HitNormal * 3
end

local function PutLootEntityOnGround(ply, source, item)
    if not IsValid(item) then return end

    item:SetParent(NULL)
    item:SetPos(GetLootDropPosition(ply, source))
    item:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    item:SetNoDraw(false)
    item:DrawShadow(true)
    item:RemoveSolidFlags(FSOLID_NOT_SOLID)
    item:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    item.IsSpawned = true
    item.init = true
    item.DontEquipInstantly = nil

    local phys = item:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(vector_origin)
        phys:Wake()
    end
end

local function DropLootAmmo(ply, source, ammoID, count)
    local ammoName = game.GetAmmoName(ammoID)
    if not ammoName or count <= 0 then return false end

    local class = "ent_ammo_" .. string.lower(string.Replace(ammoName, " ", ""))
    if not scripted_ents.GetStored(class) then return false end

    local ammoBox = ents.Create(class)
    if not IsValid(ammoBox) then return false end

    ammoBox.AmmoCount = count
    ammoBox:SetPos(GetLootDropPosition(ply, source))
    ammoBox:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ammoBox:Spawn()

    local phys = ammoBox:GetPhysicsObject()
    if IsValid(phys) then
        local force = game.GetAmmoForce(ammoID) or 1
        phys:SetMass(math.Clamp((force * count) / 1500, 1, 50000))
        phys:Wake()
    end

    return true
end

local function CanStoreLootWeapon(ply, weapon)
    if ply:HasWeapon(weapon:GetClass()) then return false end
    if weapon.weaponInvCategory and not ply.weaponInv then return false end
    if hg.weaponInv and hg.weaponInv.CanInsert and hg.weaponInv.CanInsert(ply, weapon) == false then return false end
    return true
end

local function CanStoreLootEntity(ply, item)
    local class = item:GetClass()
    local weaponsInventory = ply.inventory and ply.inventory.Weapons or {}
    if class == "hg_flashlight" or class == "hg_sling" then return not weaponsInventory[class] end
    if class == "hg_brassknuckles" then
        local value = weaponsInventory[class]
        local count = isnumber(value) and value or (value and 1 or 0)
        return count < 2
    end
    return true
end

local function ArmorFitsWithoutReplacing(ply, placement, armor)
    local equippedArmors = ply.armors or {}
    if equippedArmors[placement] then return false end
    if hg.CanEquipArmorPiece and not hg.CanEquipArmorPiece(ply, armor) then return false end

    local armorData = hg.armor and hg.armor[placement] and hg.armor[placement][armor]
    if not armorData then return false end
    if armorData.whitelistClasses and not armorData.whitelistClasses[ply.PlayerClassName] then return false end

    local dependency = armorData.requireEquipped or armorData.requiresArmor or armorData.requiredArmor
    if dependency and hg.ArmorRequirementSatisfied and not hg.ArmorRequirementSatisfied(ply, dependency) then return false end

    for equippedPlacement, equippedArmor in pairs(equippedArmors) do
        local equippedData = hg.armor[equippedPlacement] and hg.armor[equippedPlacement][equippedArmor]
        if equippedData and equippedData.restricted and table.HasValue(equippedData.restricted, placement) then return false end
        if armorData.restricted and table.HasValue(armorData.restricted, equippedPlacement) then return false end
        if placement == "ears" and equippedData and equippedData.blocksHeadphones then return false end
    end

    return hook.Run("CanEquipArmor", ply, armor) ~= false
end

local functions = {
    ["Weapons"] = function(ply, ent, wep)
		local originalClass = wep
		local canonicalClass = hg.CanonicalWeaponClass(wep)
		if canonicalClass ~= wep then
			local value = ent.inventory.Weapons[wep]
			if ent.inventory.Weapons[canonicalClass] == nil then ent.inventory.Weapons[canonicalClass] = value end
			ent.inventory.Weapons[wep] = nil
			wep = canonicalClass
		end
        if (ent:IsPlayer() and IsValid(ent:GetActiveWeapon()) and hg.CanonicalWeaponClass(ent:GetActiveWeapon():GetClass()) == wep) then return end
        if (not ent.inventory.Weapons[wep]) then return end

        --local weapon = weapons.Get(wep)
        --if not weapon then return end
        
        local weapon
		local previousWeapon = ply:GetActiveWeapon()
		local storedWeapon = ent.inventory.Weapons[wep]
        local weaponIsEnt = not isbool(storedWeapon) and IsValid(storedWeapon) and storedWeapon:IsWeapon() and storedWeapon:GetClass() == wep
        --print(weaponIsEnt)
        if not weaponIsEnt then
            weapon = ents.Create(wep)
            if not IsValid(weapon) then return end
            weapon.IsSpawned = true
            weapon.init = true
            --weapon.init = true--<^разве это не одно и то же?
            weapon:SetPos(ent:GetPos())
            weapon:SetAngles(ent:GetAngles())
            weapon:Spawn()
            
			local tbl = isentity(storedWeapon) and IsValid(storedWeapon) and storedWeapon.GetInfo and storedWeapon:GetInfo() or storedWeapon
            if weapon.SetInfo and istable(tbl) then weapon:SetInfo(tbl) end
			if isentity(storedWeapon) and IsValid(storedWeapon) and storedWeapon:IsWeapon() then storedWeapon:Remove() end
        else
            weapon = ent.inventory.Weapons[wep]
            weapon:SetParent( NULL )
            weapon:SetAngles( ent:GetAngles() )
            weapon:SetNoDraw( false )
            weapon:DrawShadow( true )
            weapon:RemoveSolidFlags(FSOLID_NOT_SOLID)
            --

            --local tbl = ent.inventory.Weapons[wep]
            --if weapon.SetInfo then weapon:SetInfo(tbl) end
        end

        --print(weapon:GetPos())

        ent.inventory.Weapons[wep] = nil

        if ent:IsPlayer() then
            if weaponIsEnt then
                ent:DropWeapon(weapon)
            else
				ent:StripWeapon(originalClass)
            end
        end

        ply:DropObject()

        PutLootEntityOnGround(ply, ent, weapon)

        if not weapon:IsWeapon() then
            if not CanStoreLootEntity(ply, weapon) then return end
            weapon:Use(ply)
            return
        end

        if not CanStoreLootWeapon(ply, weapon) then return end
        
        weapon.IsSpawned = false
        weapon.init = false
        weapon.DontEquipInstantly = true

        if hook.Run("PlayerCanPickupWeapon",ply,weapon) == false then 
            PutLootEntityOnGround(ply, ent, weapon)
            return
        end
        
        if IsValid(weapon) and weapon:IsWeapon() then
            ply:PickupWeapon(weapon)
        end

        if not IsValid(weapon) or weapon:GetOwner() ~= ply then
            PutLootEntityOnGround(ply, ent, weapon)
            return
        end

        timer.Simple(0, function()
            if not IsValid(ply) or not IsValid(previousWeapon) or previousWeapon:GetOwner() ~= ply then return end
            if ply:GetActiveWeapon() ~= previousWeapon then ply:SelectWeapon(previousWeapon:GetClass()) end
        end)
    end,
    ["Ammo"] = function(ply, ent, ammo, amt)
        local ammoID = tonumber(ammo)
        local amt2 = ammoID and ent.inventory.Ammo[ammoID]
        if not amt2 or amt != amt2 then return end

        local before = ply:GetAmmoCount(ammoID)
        ply:GiveAmmo(amt2, ammoID, true)
        local remaining = math.max(amt2 - math.max(ply:GetAmmoCount(ammoID) - before, 0), 0)
        local dropped = remaining > 0 and DropLootAmmo(ply, ent, ammoID, remaining)

        if ent:IsPlayer() then
            ent:SetAmmo(remaining > 0 and not dropped and remaining or 0, ammoID)
        else
            ent.inventory.Ammo[ammoID] = remaining > 0 and not dropped and remaining or nil
        end
    end,
    ["Armor"] = function(ply, ent, placement, armor)
        local armorData = hg.armor and hg.armor[placement] and hg.armor[placement][armor]
        if not armorData or armorData.nodrop then return end
        if not ent.armors or ent.armors[placement] ~= armor then return end
        if not ArmorFitsWithoutReplacing(ply, placement, armor) then
            hg.DropArmorForce(ent, armor, GetLootDropPosition(ply, ent), Angle(0, ply:EyeAngles().y, 0))
            return
        end
        if !hg.AddArmor(ply, armor) then
            hg.DropArmorForce(ent, armor, GetLootDropPosition(ply, ent), Angle(0, ply:EyeAngles().y, 0))
            return
        end
        ent.armors[placement] = nil

        if placement == "face" and ent:GetNetVar("zableval_masku", false) and armor != "nightvision1" then
            ply:SetNetVar("zableval_masku", true)
            ent:SetNetVar("zableval_masku", false)
        end

        hook.Run("ItemTransfer",ply, ent, placement, armor)
    end,
    ["Attachments"] = function(ply, ent, att)
        att = tonumber(att)
        if not ent.inventory.Attachments[att] then return end
        ply.inventory.Attachments[#ply.inventory.Attachments + 1] = ent.inventory.Attachments[att]
        ent.inventory.Attachments[att] = nil
    end,
    -- ["Money"] = function(ply, ent)
    --     local money = ent:GetNetVar("zb_Scrappers_RaidMoney", 0)
    --     ply:SetNetVar("zb_Scrappers_RaidMoney", ply:GetNetVar("zb_Scrappers_RaidMoney", 0) + money)
    --     ent:SetNetVar("zb_Scrappers_RaidMoney", 0)
    -- end,
}

local function BuildLootTakeKey(ent, tblIndex, thing)
    if not IsValid(ent) then return "" end
    return ent:EntIndex() .. "|" .. tblIndex .. "|" .. thing
end

local function GetLootTakeDuration(tblIndex, thing)
    if tblIndex == "Weapons" then
        local swep = weapons.Get(thing)
        local weight = swep and tonumber(swep.weight)
        if weight ~= nil then
            return math.Clamp(weight, 0, 5)
        end
    end

    return math.Rand(0.5, 1.15)
end

util.AddNetworkString("ZCityBackpackDrawStart")
util.AddNetworkString("ZCityBackpackDrawCancel")
util.AddNetworkString("ply_take_item_begin")
util.AddNetworkString("ply_take_item_begin_ack")
net.Receive("ply_take_item_begin", function(_, ply)
    local tblIndex = net.ReadString()
    local thing = net.ReadString()
    net.ReadTable()
    local ent = net.ReadEntity()

    if not IsValid(ent) or not IsValid(ply) then return end
    if ent:IsPlayer() and not IsValid(ent.FakeRagdoll) then return end
    if ent:GetPos():Distance(ply:GetPos()) > 125 then return end

    local key = BuildLootTakeKey(ent, tblIndex, thing)
    local duration = GetLootTakeDuration(tblIndex, thing)
    ply.lootTakePending = ply.lootTakePending or {}
    ply.lootTakePending[key] = CurTime() + duration

    net.Start("ply_take_item_begin_ack")
    net.WriteString(key)
    net.WriteFloat(duration)
    net.Send(ply)
end)

util.AddNetworkString("ply_take_item")
net.Receive("ply_take_item", function(len, ply)
    local tblIndex = net.ReadString()
    local thing = net.ReadString()
    local tbl = net.ReadTable()
    local ent = net.ReadEntity()
    
    if !IsValid(ent) or !IsValid(ply) then return end
    if ent:IsPlayer() and not IsValid(ent.FakeRagdoll) then return end

    if ent:GetPos():Distance(ply:GetPos()) > 125 then return end
    local key = BuildLootTakeKey(ent, tblIndex, thing)
    local unlockTime = ply.lootTakePending and ply.lootTakePending[key]
    if not unlockTime or unlockTime > CurTime() then return end
    if (ply.cooldown_takeitem or 0) > CurTime() then return end
    ply.cooldown_takeitem = CurTime() + 0.3
    ply.lootTakePending[key] = nil

    local func = functions[tblIndex]
    if func then func(ply, ent, thing, unpack(tbl)) end
    ply:SetNetVar("Inventory", ply.inventory)
    ent:SetNetVar("Inventory", ent.inventory)
    ply:SyncArmor()
    ent:SyncArmor()
end)

util.AddNetworkString("should_open_inv")
local playerMeta = FindMetaTable("Player")
function playerMeta:OpenInventory(ent)
    hook.Run("ZB_InventoryOpened",self,ent)
    if not IsValid(ent) then return end
    if ent:IsPlayer() and not IsValid(ent.FakeRagdoll) then return end
    if ent:IsPlayer() then hg.RenewInv(ent) end
    if self:IsPlayer() then hg.RenewInv(self) end
    self.cooldown_takeitem = CurTime() + 0.3
    net.Start("should_open_inv")
    net.WriteEntity(ent)
    net.Send(self)
end

function playerMeta:GetLookTrace()
    if not IsValid(self) or not self:Alive() then return end
    local tr = {}
    local ent = IsValid(self.FakeRagdoll) and self.FakeRagdoll or self
    local att = ent:GetAttachment(ent:LookupAttachment("eyes"))
    if not att then return false end
    tr.start = att.Pos
    tr.endpos = att.Pos + self:EyeAngles():Forward() * 80
    tr.filter = ent
    return util.TraceLine(tr)
end

local function IsSearchableContainer(ent)
    if not IsValid(ent) or ent:IsWorld() then return false end
    if ent.IsSearchableContainer == true or ent:GetNWBool("hgSearchableContainer", false) then return true end

    local model = string.lower(ent:GetModel() or "")
    if hg.loot_boxes and hg.loot_boxes[model] then return true end
    if hg.SandboxContainerModels and hg.SandboxContainerModels[model] then return true end
    return false
end

local function IsKnownLootEntity(ent)
    if not IsValid(ent) or ent:IsWorld() then return false end
    return ent:GetNetVar("Inventory") ~= nil or IsSearchableContainer(ent)
end

local function ResolveLootEntityFromTrace(ply, trace)
    if not trace then return end

    local traced = trace.Entity
    local owner = hg.RagdollOwner(traced)
    local ent = IsValid(owner) and owner or traced
    if IsKnownLootEntity(ent) or (IsValid(ent) and ent:IsPlayer()) then return ent end

    local hitPos = trace.HitPos
    if not isvector(hitPos) then return ent end

    local best
    local bestDistance
    for _, candidate in ipairs(ents.FindInSphere(hitPos, 48)) do
        if IsKnownLootEntity(candidate) then
            local nearest = candidate.NearestPoint and candidate:NearestPoint(hitPos) or candidate:GetPos()
            local distance = nearest:DistToSqr(hitPos)
            if not bestDistance or distance < bestDistance then
                best = candidate
                bestDistance = distance
            end
        end
    end

    return best or ent
end

local function HandleLootInput(ply)
    if not IsValid(ply) then return end
    if not ply:Alive() then
        ply.keypressed = false
        return
    end
    ply.keypressed = ply.keypressed or false

    local fakeRagdoll = IsValid(ply.FakeRagdoll)
    local use = fakeRagdoll and (ply:KeyDown(IN_WALK) and ply:KeyDown(IN_SPEED) and not ply:KeyDown(IN_ATTACK) and not ply:KeyDown(IN_ATTACK2)) or (not fakeRagdoll and ply:KeyDown(IN_ATTACK2) and ply:KeyDown(IN_USE))
    if not use then
        ply.keypressed = false
        return
    end

    local trace = hg.eyeTrace(ply, 100)
    if not trace then return end

    local ent = ResolveLootEntityFromTrace(ply, trace)
    if not fakeRagdoll then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.GetFists and wep:GetFists() and not IsKnownLootEntity(ent) then
            ply.keypressed = false
            return
        end
    end

    if IsValid(ent) and ent:IsPlayer() and ent ~= ply and ent:Alive() and ent.organism and not ent.organism.otrub then
        if not ply.keypressed then ply:ChatPrint("You cant loot them, they are awake.") end
        ply.keypressed = true
        return
    end

    local hookPly, hookEnt, canloot = hook.Run("ZB_CanLootInventory", ply, ent)
    if canloot ~= nil and canloot == false then
        if not ply.keypressed and IsValid(ent) and hookPly == ply and hookEnt == ent and IsSearchableContainer(ent) and hg.TryZManipInteract then
            hg.TryZManipInteract(ply, ent, "interact")
        end
        ply.keypressed = true
        return
    end

    hook.Run("ZB_InventoryChecked", ply, ent)
    if not IsValid(ent) or not ent:GetNetVar("Inventory") then return end

    if not ply.keypressed then
        ply:OpenInventory(ent)
        if hg.TryZManipInteract then hg.TryZManipInteract(ply, ent, "interact") end
    end

    ply.keypressed = true
end

hook.Add("Think", "loot-fellows", function()
    for _, ply in ipairs(player.GetAll()) do
        HandleLootInput(ply)
    end
end)

--// Prop inventory example
--[[
	local pos = Entity(1):GetEyeTrace().HitPos
	local ent = ents.Create("prop_physics")
	ent:SetModel("models/props_interiors/Furniture_Desk01a.mdl")
	ent:SetPos(pos)
	ent:Spawn()
	ent.inventory = {}
	local wep = "weapon_ar15"
	local weapon = weapons.Get(wep)
	ent.inventory.Weapons = {[wep] = {30,hg.ClearAttachments(wep)}}
	hg.SetAttachment(ent.inventory.Weapons[wep][2],"supressor2",wep)
	ent:SetNetVar("Inventory",ent.inventory)
]]
