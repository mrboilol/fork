-- 
util.AddNetworkString("Get_Appearance")
util.AddNetworkString("OnlyGet_Appearance")
hg.Appearance = hg.Appearance or {}
local APmodule = hg.Appearance

hg.PointShop = hg.PointShop or {}
local PSmodule = hg.PointShop

-- Appearance backpacks are gameplay inventory equipment too: they cover the
-- body holster positions, so pistols and long guns must be drawn from the bag.
local function SyncInventoryAccessoryEffects(ply, accessories)
	local hasBackpack = false
	if istable(accessories) then
		for _, accessoryID in pairs(accessories) do
			local data = hg.Accessories and hg.Accessories[accessoryID]
			if data and data.inventoryRole == "backpack" then
				hasBackpack = true
				break
			end
		end
	end

	ply:SetNWBool("ZCityBodyHolsterBlocked", hasBackpack)
end

local accessoryImpactTypes = DMG_BULLET + DMG_BUCKSHOT + DMG_CLUB + DMG_SLASH + DMG_CRUSH + DMG_FALL
APmodule.ImpactConfig = {
	minDamage = 1,
	fullDamage = 55,
	dropChance = 0.18,
	severityChance = 0.56,
	bulletChance = 0.2,
	absorption = 0.06,
	severityAbsorption = 0.08,
	dropAbsorption = 0.23,
	dropSeverityAbsorption = 0.13,
}

local accessoryMaterialProfiles = {
	metal = {durability = 95, absorption = 0.34, wear = 0.45},
	wood = {durability = 48, absorption = 0.1, wear = 0.72},
	plastic = {durability = 36, absorption = 0.06, wear = 0.9},
	glass = {durability = 12, absorption = 0.02, wear = 1.5},
	fabric = {durability = 25, absorption = 0.025, wear = 0.8},
}

local function CopyAccessories(accessories)
	return istable(accessories) and table.Copy(accessories) or {}
end

local function GetAccessoryWearer(ent)
	if !IsValid(ent) then return end
	if ent:IsPlayer() then return ent end

	local owner = hg.RagdollOwner and hg.RagdollOwner(ent)
	return IsValid(owner) and owner:IsPlayer() and owner or nil
end

local function SyncAccessories(ply, accessories)
	accessories = CopyAccessories(accessories)
	ply:SetNetVar("Accessories", accessories)

	local character = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply)
	if IsValid(character) and character != ply then
		character:SetNetVar("Accessories", CopyAccessories(accessories))
	end

	if IsValid(ply.OldRagdoll) and ply.OldRagdoll != character then
		ply.OldRagdoll:SetNetVar("Accessories", CopyAccessories(accessories))
	end

	local deathRagdoll = ply:GetNWEntity("RagdollDeath", NULL)
	if IsValid(deathRagdoll) and deathRagdoll != character and deathRagdoll != ply.OldRagdoll then
		deathRagdoll:SetNetVar("Accessories", CopyAccessories(accessories))
	end

	if ply.CurAppearance then
		ply.CurAppearance.AAttachments = CopyAccessories(accessories)
	end

	if ply.CachedAppearance then
		ply.CachedAppearance.AAttachments = CopyAccessories(accessories)
	end

	SyncInventoryAccessoryEffects(ply, accessories)
end

local function GetAccessoryTransform(ent, accessory)
	local pose = accessory[ThatPlyIsFemale(ent) and "fempos" or "malepos"]
	if !pose or !isvector(pose[1]) or !isangle(pose[2]) then return end

	local bone = ent:LookupBone(accessory.bone or "ValveBiped.Bip01_Head1")
	if !bone then return end
	if ent:GetManipulateBoneScale(bone):LengthSqr() < 0.1 then return end
	local limb = hg.amputatedlimbs2 and hg.amputatedlimbs2[accessory.bone]
	if limb and ent.organism and ent.organism[limb .. "amputated"] then return end
	if ent.armors and ent.armors[accessory.placement] then return end

	local matrix = ent:GetBoneMatrix(bone)
	if !matrix then return end

	local pos, ang = LocalToWorld(pose[1], pose[2], matrix:GetTranslation(), matrix:GetAngles())
	if ent:GetModel() == "models/player/group01/male_06.mdl" and (accessory.placement == "head" or accessory.placement == "face") then
		pos = LocalToWorld(Vector(0.4, 0, 0.4), angle_zero, pos, ang)
	end

	return pos, ang, pose[3] or 1
end

local function IsDroppableAccessory(accessory)
	return accessory and accessory.model and accessory.placement and accessory.placement != "none"
end

local function GetAccessoryMaterialProfile(accessory)
	local value = string.lower(table.concat({tostring(accessory.impactMaterial or ""), tostring(accessory.material or ""), tostring(accessory.model or ""), tostring(accessory.name or "")}, " "))
	if string.find(value, "metal", 1, true) or string.find(value, "steel", 1, true) or string.find(value, "iron", 1, true) or string.find(value, "helmet", 1, true) then return accessoryMaterialProfiles.metal end
	if string.find(value, "wood", 1, true) then return accessoryMaterialProfiles.wood end
	if string.find(value, "glass", 1, true) or string.find(value, "goggle", 1, true) then return accessoryMaterialProfiles.glass end
	if string.find(value, "plastic", 1, true) or string.find(value, "rubber", 1, true) then return accessoryMaterialProfiles.plastic end
	return accessoryMaterialProfiles.fabric
end

local function GetAccessoryCondition(wearer, accessoryID, accessory)
	wearer.HGAccessoryDurability = wearer.HGAccessoryDurability or {}
	local profile = GetAccessoryMaterialProfile(accessory)
	local maximum = math.max(tonumber(accessory.impactDurability) or profile.durability, 1)
	local durability = wearer.HGAccessoryDurability[accessoryID]
	if durability == nil then durability = maximum end
	return durability, maximum, profile
end

local function DamageAccessoryCondition(wearer, accessoryID, accessory, damage)
	local durability, maximum, profile = GetAccessoryCondition(wearer, accessoryID, accessory)
	durability = math.max(durability - math.max(damage, 0) * profile.wear, 0)
	wearer.HGAccessoryDurability[accessoryID] = durability
	wearer:SetNWFloat("HGAccessoryCondition_" .. util.CRC(accessoryID), durability / maximum)
	return durability <= 0, durability, maximum, profile
end

function APmodule.TraceAccessoryShot(ent, startPos, endPos, seen, hits, padding)
	local accessories = ent:GetNetVar("Accessories", {})
	if !istable(accessories) or table.IsEmpty(accessories) then
		local wearer = GetAccessoryWearer(ent)
		accessories = IsValid(wearer) and wearer:GetNetVar("Accessories", {}) or {}
	end
	if !istable(accessories) then return end
	for index, accessoryID in pairs(accessories) do
		local accessory = hg.Accessories[accessoryID]
		local key = tostring(ent:EntIndex()) .. ":" .. tostring(accessoryID)
		if !IsDroppableAccessory(accessory) or seen[key] then continue end
		local pos, ang, scale = GetAccessoryTransform(ent, accessory)
		if !pos then continue end
		local hit = hg.TraceEquipmentModel(accessory[ThatPlyIsFemale(ent) and "femmodel"] or accessory.model, pos, ang, scale, startPos, endPos, padding)
		if !hit then continue end
		hit.id, hit.index, hit.data, hit.body, hit.key = accessoryID, index, accessory, ent, key
		hits[#hits + 1] = hit
	end
end

function APmodule.GetEntityImpactRadius(ent)
	if !IsValid(ent) or ent:IsWorld() then return 0 end
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	if !isvector(mins) or !isvector(maxs) then return 0 end
	local extents = {
		math.max(math.abs(mins.x), math.abs(maxs.x)),
		math.max(math.abs(mins.y), math.abs(maxs.y)),
		math.max(math.abs(mins.z), math.abs(maxs.z)),
	}
	table.sort(extents)
	local modelScale = tonumber(ent:GetModelScale()) or 1
	return math.Clamp(extents[2] * math.max(modelScale, 0.01), 0, 5)
end

local function FindAccessoryImpact(ent, hitPos, direction, impactRadius)
	if !isvector(hitPos) or !isvector(direction) or direction:LengthSqr() < 0.001 then return end
	local hits = {}
	local dir = direction:GetNormalized()
	local radius = math.max(tonumber(impactRadius) or 0, 0)
	APmodule.TraceAccessoryShot(ent, hitPos - dir * (24 + radius), hitPos + dir * 1, {}, hits, radius)
	table.sort(hits, function(a, b) return a.fraction < b.fraction end)
	return hits[1]
end

local function SpawnAccessoryDrop(accessoryID, accessory, owner, position, force, durability, maximum)
	local model = accessory[ThatPlyIsFemale(owner) and "femmodel"] or accessory.model
	if !model then return end
	local scale = (accessory[ThatPlyIsFemale(owner) and "fempos"] or accessory.malepos or {})[3] or 1

	local dropped = ents.Create("prop_physics")
	if !IsValid(dropped) then return end

	dropped:SetModel(model)
	dropped:SetModelScale(scale, 0)
	dropped:SetPos(position)
	dropped:SetAngles(AngleRand())
	dropped:Spawn()
	dropped:PhysicsInit(SOLID_VPHYSICS)
	dropped:SetMoveType(MOVETYPE_VPHYSICS)
	dropped:SetSolid(SOLID_VPHYSICS)

	local phys = dropped:GetPhysicsObject()
	if !IsValid(phys) then
		local mins, maxs = dropped:OBBMins(), dropped:OBBMaxs()
		if isvector(mins) and isvector(maxs) then
			local center = (mins + maxs) * 0.5
			local half = (maxs - mins) * 0.5
			half.x = math.Clamp(half.x, 1, 24)
			half.y = math.Clamp(half.y, 1, 24)
			half.z = math.Clamp(half.z, 1, 24)
			mins, maxs = center - half, center + half
			dropped:PhysicsInitBox(mins, maxs)
			dropped:SetCollisionBounds(mins, maxs)
			phys = dropped:GetPhysicsObject()
		end
	end

	if !IsValid(phys) then
		dropped:Remove()
		return
	end

	dropped:SetSkin(isfunction(accessory.skin) and accessory.skin(owner) or accessory.skin or 0)
	if accessory.bSetColor and owner.GetPlayerColor then
		local color = owner:GetPlayerColor():ToColor()
		dropped:SetColor(color)
		dropped.HGAccessoryColor = color
	end
	dropped:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	dropped:SetUseType(SIMPLE_USE)
	dropped.HGAccessoryID = accessoryID
	dropped.HGAccessoryOwner = owner
	dropped.HGAccessoryDurability = durability
	dropped.HGAccessoryMaxDurability = maximum
	if isnumber(durability) and isnumber(maximum) and maximum > 0 then
		dropped:SetNWFloat("HGEquipmentCondition", math.Clamp(durability / maximum, 0, 1))
	end

	phys:SetMass(2)
	phys:EnableMotion(true)
	phys:Wake()
	local launch = isvector(force) and force or vector_origin
	if launch:LengthSqr() > 0 then
		launch = launch:GetNormalized() * math.Clamp(launch:Length() * 0.4, 130, 650)
	else
		launch = VectorRand():GetNormalized() * 130
	end
	local inheritedVelocity = IsValid(owner) and owner.GetVelocity and owner:GetVelocity() or vector_origin
	phys:AddVelocity(inheritedVelocity + launch + vector_up * 60 + VectorRand() * 35)
	phys:AddAngleVelocity(VectorRand() * 240)
	dropped:Activate()
	if hg.NotifyPickupHistoryDrop then
		hg.NotifyPickupHistoryDrop(owner, accessory.name or accessoryID)
	end

	timer.Simple(180, function()
		if IsValid(dropped) then dropped:Remove() end
	end)

	return dropped
end

local function QueueAccessoryDrop(accessoryID, accessory, owner, position, force, durability, maximum)
	if !IsValid(owner) or !istable(accessory) or !isvector(position) then return false end
	local model = accessory[ThatPlyIsFemale(owner) and "femmodel"] or accessory.model
	if !model then return false end

	local dropPosition = Vector(position.x, position.y, position.z)
	local dropForce = isvector(force) and Vector(force.x, force.y, force.z) or vector_origin
	timer.Simple(0, function()
		if !IsValid(owner) then return end
		SpawnAccessoryDrop(accessoryID, accessory, owner, dropPosition, dropForce, durability, maximum)
	end)
	return true
end

function APmodule.DropAccessoriesByPlacement(ent, placements, force)
	if !IsValid(ent) or !istable(placements) then return false end

	local wearer = GetAccessoryWearer(ent)
	if !IsValid(wearer) then return false end

	local accessories = ent:GetNetVar("Accessories", {})
	if !istable(accessories) or table.IsEmpty(accessories) then
		accessories = wearer:GetNetVar("Accessories", {})
	end
	if !istable(accessories) then return false end

	accessories = CopyAccessories(accessories)
	local drops = {}
	for index, accessoryID in pairs(accessories) do
		local accessory = hg.Accessories[accessoryID]
		if IsDroppableAccessory(accessory) and placements[accessory.placement] then
			drops[#drops + 1] = {index = index, id = accessoryID, data = accessory}
		end
	end
	if #drops == 0 then return false end

	table.sort(drops, function(a, b)
		if isnumber(a.index) and isnumber(b.index) then return a.index > b.index end
		return isnumber(a.index)
	end)

	local launchForce = isvector(force) and force or ent:GetVelocity() + VectorRand() * 180 + vector_up * 120
	local changed = false
	for _, drop in ipairs(drops) do
		local position = GetAccessoryTransform(ent, drop.data) or ent:WorldSpaceCenter()
		local durability, maximum = GetAccessoryCondition(wearer, drop.id, drop.data)
		local dropped = SpawnAccessoryDrop(drop.id, drop.data, wearer, position, launchForce + VectorRand() * 90, durability, maximum)
		if !IsValid(dropped) then continue end
		if isnumber(drop.index) then
			table.remove(accessories, drop.index)
		else
			accessories[drop.index] = nil
		end
		changed = true
	end

	if changed then SyncAccessories(wearer, accessories) end
	return changed
end

function APmodule.TryAbsorbAccessoryImpact(ent, dmgInfo, hitPos, direction, directImpact, impactRadius)
	if !IsValid(ent) or !dmgInfo or !dmgInfo:IsDamageType(accessoryImpactTypes) then return end
	if hg.EquipmentImpact and hg.EquipmentImpact.ProcessedDamage[dmgInfo] then return end

	local cfg = APmodule.ImpactConfig
	local damage = dmgInfo:GetDamage()
	if damage < cfg.minDamage then return end

	local wearer = GetAccessoryWearer(ent)
	if !IsValid(wearer) then return end

	local accessories = ent:GetNetVar("Accessories", {})
	if !istable(accessories) or table.IsEmpty(accessories) then
		accessories = wearer:GetNetVar("Accessories", {})
	end
	if !istable(accessories) then return end

	if impactRadius == nil and !dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
		local inflictor = dmgInfo:GetInflictor()
		if IsValid(inflictor) and !inflictor:IsPlayer() and !inflictor:IsWeapon() and !inflictor:IsWorld() then
			impactRadius = APmodule.GetEntityImpactRadius(inflictor)
		end
	end
	local impact = directImpact or FindAccessoryImpact(ent, hitPos, direction, impactRadius)
	if !impact then return end
	accessories = CopyAccessories(accessories)
	local index = table.KeyFromValue(accessories, impact.id)
	if !index then return end

	local severity = math.Clamp((damage - cfg.minDamage) / cfg.fullDamage, 0, 1)
	local broken, durability, maximum, materialProfile = DamageAccessoryCondition(wearer, impact.id, impact.data, damage)
	local condition = math.Clamp(durability / maximum, 0, 1)
	local thickness = math.Clamp((impact.thickness or 0.2) / 2, 0.1, 1)
	local materialAbsorption = materialProfile.absorption * thickness * Lerp(condition, 0.25, 1)
	local absorbed = math.max(cfg.absorption + severity * cfg.severityAbsorption, materialAbsorption)
	local dropChance = cfg.dropChance + severity * cfg.severityChance
	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then dropChance = dropChance + cfg.bulletChance end

	if broken or math.Rand(0, 1) <= dropChance then
		if QueueAccessoryDrop(impact.id, impact.data, wearer, impact.position, direction, durability, maximum) then
			absorbed = cfg.dropAbsorption + severity * cfg.dropSeverityAbsorption
			if isnumber(index) then
				table.remove(accessories, index)
			else
				accessories[index] = nil
			end
			SyncAccessories(wearer, accessories)
		end
	end

	dmgInfo:ScaleDamage(math.Clamp(1 - absorbed, 0.6, 1))
	return true
end

function APmodule.EquipFallenAccessory(ply, dropped)
	if !IsValid(ply) or !ply:IsPlayer() or !IsValid(dropped) then return false end

	local accessoryID = dropped.HGAccessoryID
	local accessory = hg.Accessories[accessoryID]
	if !IsDroppableAccessory(accessory) then return false end

	local accessories = CopyAccessories(ply:GetNetVar("Accessories", {}))
	local replacement
	for index, equippedID in pairs(accessories) do
		local equipped = hg.Accessories[equippedID]
		if equipped and equipped.placement == accessory.placement then
			replacement = index
			break
		end
	end

	if replacement then
		local replacedID = accessories[replacement]
		local replacedAccessory = hg.Accessories[replacedID]
		if IsDroppableAccessory(replacedAccessory) then
			local durability, maximum = GetAccessoryCondition(ply, replacedID, replacedAccessory)
			SpawnAccessoryDrop(replacedID, replacedAccessory, ply, dropped:GetPos(), dropped:GetVelocity(), durability, maximum)
		end
		accessories[replacement] = accessoryID
	else
		accessories[#accessories + 1] = accessoryID
	end
	if isnumber(dropped.HGAccessoryDurability) then
		ply.HGAccessoryDurability = ply.HGAccessoryDurability or {}
		ply.HGAccessoryDurability[accessoryID] = dropped.HGAccessoryDurability
		local maximum = math.max(tonumber(dropped.HGAccessoryMaxDurability) or 1, 1)
		ply:SetNWFloat("HGAccessoryCondition_" .. util.CRC(accessoryID), math.Clamp(dropped.HGAccessoryDurability / maximum, 0, 1))
	end

	local hands = ply:GetActiveWeapon()
	if IsValid(hands) and hands.GetCarrying and hands.SetCarrying and hands:GetCarrying() == dropped then
		hands:SetCarrying()
	end
	if ply:GetNetVar("carryent2") == dropped and hg.SetCarryEnt2 then
		hg.SetCarryEnt2(ply)
	end

	SyncAccessories(ply, accessories)
	ply:EmitSound("snd_jack_hmcd_disguise.ogg", 70, math.random(95, 105), 0.7, CHAN_ITEM)
	dropped:Remove()
	return true
end

function APmodule.DropAccessory(ply, accessoryID)
	if !IsValid(ply) or !ply:IsPlayer() or !isstring(accessoryID) then return false end

	local accessories = CopyAccessories(ply:GetNetVar("Accessories", {}))
	local index = table.KeyFromValue(accessories, accessoryID)
	local accessory = hg.Accessories[accessoryID]
	if !index or !IsDroppableAccessory(accessory) then return false end

	local durability, maximum = GetAccessoryCondition(ply, accessoryID, accessory)
	local dropped = SpawnAccessoryDrop(accessoryID, accessory, ply, ply:EyePos() + ply:EyeAngles():Forward() * 18, ply:EyeAngles():Forward() * 150, durability, maximum)
	if !IsValid(dropped) then return false end

	table.remove(accessories, index)
	SyncAccessories(ply, accessories)
	return true
end

hook.Add("PlayerUse", "ZCityAccessoryPickup", function(ply, ent)
	if !IsValid(ent) or !ent.HGAccessoryID then return end
	if APmodule.EquipFallenAccessory(ply, ent) then return false end
end)

-- Stub function for permamodel check (not implemented)
function APmodule.IsPermamodelEnabled(ply)
    return false
end

local function CheckAttachments(ply,tbl)
    if !IsValid(ply) or !ply:IsPlayer() then return end
    --print(ply:PS_HasItem(uid))
    if hg.Appearance.GetAccessToAll(ply) then return tbl end
    for i = 1, #tbl.AAttachments do
        local uid = tbl.AAttachments[i]
        if PSmodule.Items[uid] and (!ply:PS_HasItem(uid) and ply:IsPlayer()) then
            tbl.AAttachments[i] = ""
            ply:ChatPrint(uid .. " - not bought, removed")
        end

        if hg.Accessories[uid] and hg.Accessories[uid].disallowinappearance then
            tbl.AAttachments[i] = ""
            if ply.ChatPrint then ply:ChatPrint(uid .. " - is disallowed in default appearance, removed") end
        end

        if hg.Accessories[uid] and hg.Accessories[uid].allowed and not hg.Accessories[uid].allowed[ply:SteamID()] and not hg.Appearance.GetAccessToAll(ply) then
            tbl.AAttachments[i] = ""
            if ply.ChatPrint then ply:ChatPrint(uid .. " - is restricted, removed") end
        end

        if hg.Accessories[uid] and hg.Accessories[uid].onlySuperAdmin and not ply:IsSuperAdmin() then
            tbl.AAttachments[i] = ""
            if ply.ChatPrint then ply:ChatPrint(uid .. " - is superadmin only, removed") end
        end
    end

    local tMdl = APmodule.PlayerModels[1][tbl.AModel] or APmodule.PlayerModels[2][tbl.AModel] or tbl.AModel
    tbl.ABodygroups = tbl.ABodygroups or {}
    for k,v in pairs(tbl.ABodygroups) do
        if not hg.Appearance.Bodygroups[k] then continue end
        if not hg.Appearance.Bodygroups[k][tMdl.sex and 2 or 1] then continue end
        local bodygroup = hg.Appearance.Bodygroups[k][tMdl.sex and 2 or 1][v]

        if not bodygroup then continue end

        local uid = bodygroup["ID"]
        --print(bodygroup[2],uid,PSmodule.Items[uid],ply:PS_HasItem(uid))
        if bodygroup[2] and uid and PSmodule.Items[uid] and (!ply:PS_HasItem(uid) and ply:IsPlayer()) then
            tbl.ABodygroups[k] = nil
            ply:ChatPrint(v .. " - not bought, removed")
        end
    end

    return tbl
end

function APmodule.SyncAppearanceColor(ply, appearance)
    if !IsValid(ply) then return end

    appearance = appearance or ply.CurAppearance
    local clr = appearance and appearance.AColor
    if !clr then return end

    local color = Vector(clr.r / 255, clr.g / 255, clr.b / 255)
    if ply.SetPlayerColor then
        ply:SetPlayerColor(color)
    end
    ply:SetNWVector("PlayerColor", color)
end

local function ValidateAppearanceTraits(ply, tbl)
    if not istable(tbl) then return end

    if not hg.Traits then
        tbl.ATraits = {}
        return
    end

    local valid, _, normalized, reason = hg.Traits.ValidateSelection(tbl.ATraits, true)
    if valid then
        tbl.ATraits = normalized
        return
    end

    tbl.ATraits = {}
    if IsValid(ply) and ply:IsPlayer() and ply.ChatPrint then
        ply:ChatPrint("[Traits] " .. (reason or "Invalid trait selection") .. ". No traits were applied.")
    end
end

local function ForceApplyAppearance(ply, tbl, noModelChange)
    ValidateAppearanceTraits(ply, tbl)
    local tMdl = APmodule.PlayerModels[1][tbl.AModel] or APmodule.PlayerModels[2][tbl.AModel] or tbl.AModel
    local mdl = istable(tMdl) and tMdl.mdl or tMdl
    if mdl ~= ply:GetModel() and !noModelChange then
        ply:SetModel(mdl)
    end

    APmodule.SyncAppearanceColor(ply, tbl)

    ply:SetSubMaterial()

    local mats = ply:GetMaterials()
    --PrintTable(mats)
    if istable(tMdl) then
        for k, v in pairs(tMdl.submatSlots) do
            --print(k)
            local slot = 1
            for i = 1, #mats do
                --print(mats[i], v,mats[i] == v, i)
                if mats[i] == v then slot = i-1 break end
            end
            ply:SetSubMaterial(slot, hg.Appearance.Clothes[tMdl.sex and 2 or 1][tbl.AClothes[k]] or hg.Appearance.Clothes[tMdl.sex and 2 or 1]["normal"] )
            ply:SetNWString("Colthes" .. k,tbl.AClothes[k] or "normal")
            --print("true")
        end
    end
    for i = 1, #mats do
        if hg.Appearance.FacemapsSlots[mats[i]] and hg.Appearance.FacemapsSlots[mats[i]][tbl.AFacemap] then
            ply:SetSubMaterial(i - 1, hg.Appearance.FacemapsSlots[mats[i]][tbl.AFacemap])
        end
    end

    ply:SetNWString("PlayerName", tbl.AName)
    ply:SetBodyGroups( "00000000000000000000" )
    --print(mdl)
    --if mdl == "models/zcity/m/male_09.mdl" and ply:SteamID() == "STEAM_0:1:163575696" then
    --    timer.Simple(0,function()
    --    ply:SetBodygroup( 1,7 )
    --    end)
    --end

    local bodygroups = ply:GetBodyGroups()
    tbl.ABodygroups = tbl.ABodygroups or {}
    for k, v in ipairs(bodygroups) do
        if !v.name then continue end
        if !tbl.ABodygroups[v.name] then continue end
        if !hg.Appearance.Bodygroups[v.name] then continue end
        --PrintTable(hg.Appearance.Bodygroups[v.name][tMdl.sex and 2 or 1])
        for i = 0, #v.submodels do
            local b = v.submodels[i]
            if !hg.Appearance.Bodygroups[v.name][tMdl.sex and 2 or 1][tbl.ABodygroups[v.name]] then continue end
            if hg.Appearance.Bodygroups[v.name][tMdl.sex and 2 or 1][tbl.ABodygroups[v.name]][1] != b then continue end
            ply:SetBodygroup(k-1,i)
        end
    end

	ply:SetNetVar("Accessories", tbl.AAttachments)
	SyncInventoryAccessoryEffects(ply, tbl.AAttachments)

    ply.CurAppearance = {}
    table.CopyFromTo(tbl, ply.CurAppearance)

    if hg.Traits and ply:IsPlayer() then
        hg.Traits.ApplyToPlayer(ply, tbl.ATraits)
    end
end


local function WearAppearance(ply,tbl)
    local checked = CheckAttachments(ply,tbl)
    ForceApplyAppearance(ply,checked)
end

APmodule.ForceApplyAppearance = ForceApplyAppearance

local function CopyAppearanceAccessories(value)
    if istable(value) then
        return table.Copy(value)
    end

    return value
end

local function AccessoriesStateEqual(a, b)
    if istable(a) or istable(b) then
        if !istable(a) or !istable(b) then return false end
        if table.Count(a) != table.Count(b) then return false end

        for key, value in pairs(a) do
            if b[key] != value then
                return false
            end
        end

        for key, value in pairs(b) do
            if a[key] != value then
                return false
            end
        end

        return true
    end

    return a == b
end

local function CaptureLateReplayState(ply)
    return {
        model = ply:GetModel(),
        className = ply.PlayerClassName or "",
        accessories = CopyAppearanceAccessories(ply:GetNetVar("Accessories", "none"))
    }
end

local function ClearLateReplayState(ply)
    ply.ZCLateAppearanceReplayState = nil
    ply.ZCLateAppearanceReplayExpires = nil
end

local function ShouldLateReplayCachedAppearance(ply)
    if !IsValid(ply) or !ply:IsPlayer() then return false end
    if APmodule.IsPermamodelEnabled(ply) then return false end
    if !ply:Alive() then return false end

    local state = ply.ZCLateAppearanceReplayState
    local expires = ply.ZCLateAppearanceReplayExpires or 0
    if !istable(state) or expires < CurTime() then
        ClearLateReplayState(ply)
        return false
    end

    if ply:GetModel() != state.model then
        ClearLateReplayState(ply)
        return false
    end

    if (ply.PlayerClassName or "") != (state.className or "") then
        ClearLateReplayState(ply)
        return false
    end

    if !AccessoriesStateEqual(ply:GetNetVar("Accessories", "none"), state.accessories) then
        ClearLateReplayState(ply)
        return false
    end

    return true
end

local tWaitResponse = {}

function ApplyAppearance(Client,tAppearance,bRandom,bResponeIsValid,bUseCahsed)
    if not IsValid(Client) then return end
    if bRandom or (Client.IsBot and Client:IsBot()) or (Client.IsRagdoll and Client:IsRagdoll()) then
        ClearLateReplayState(Client)
        tAppearance = APmodule.GetRandomAppearance()
        WearAppearance(Client,tAppearance)
        return
    end
    if bUseCahsed then
        tAppearance = APmodule.GetRandomAppearance()
        tAppearance = Client.CachedAppearance or tAppearance
        --Client:ChatPrint(tAppearance.AModel)
        if !APmodule.AppearanceValidater(tAppearance) then tAppearance = APmodule.GetRandomAppearance() end
        net.Start("OnlyGet_Appearance")
        net.Send(Client)
        WearAppearance(Client,tAppearance)
        Client.ZCLateAppearanceReplayState = CaptureLateReplayState(Client)
        Client.ZCLateAppearanceReplayExpires = CurTime() + 5
        return
    end

    if !bResponeIsValid then
        tWaitResponse[Client] = CurTime() + 3
        net.Start("Get_Appearance")
        net.Send(Client)
    return end
    if !tWaitResponse[Client] then return end
    if tWaitResponse[Client] > CurTime() then
        ApplyAppearance(Client,nil,true)
    return end

    if !tAppearance then ApplyAppearance(Client,nil,true) return end
    if !APmodule.AppearanceValidater(tAppearance) then ApplyAppearance(Client,nil,true) return end

    ClearLateReplayState(Client)
    WearAppearance(Client,tAppearance)
end

net.Receive("Get_Appearance",function(len,client)
    local tAppearance = net.ReadTable()
    local bRandom = net.ReadBool()
    ValidateAppearanceTraits(client, tAppearance)
    if !APmodule.AppearanceValidater(tAppearance) then bRandom = true end

    -- Update cache immediately so next respawn uses this
    client.CachedAppearance = tAppearance

    ApplyAppearance(client,tAppearance, table.IsEmpty(tAppearance) and true or bRandom,true)
end)

net.Receive("OnlyGet_Appearance",function(len,client)
    local tAppearance = net.ReadTable()
    local bRandom = !tAppearance or table.IsEmpty(tAppearance)
    ValidateAppearanceTraits(client, tAppearance)
    --client:ChatPrint(bRandom)
    client.CachedAppearance = bRandom and APmodule.GetRandomAppearance() or tAppearance

    if !ShouldLateReplayCachedAppearance(client) then return end
    if !APmodule.AppearanceValidater(client.CachedAppearance) then
        ClearLateReplayState(client)
        return
    end

    timer.Simple(0, function()
        if !ShouldLateReplayCachedAppearance(client) then return end
        if !APmodule.AppearanceValidater(client.CachedAppearance) then
            ClearLateReplayState(client)
            return
        end

        ClearLateReplayState(client)
        WearAppearance(client, table.Copy(client.CachedAppearance))
    end)
end)

APmodule.ApplyAppearance = ApplyAppearance

-- Ragdoll apply
function ApplyAppearanceRagdoll(ent, ply)
    if !IsValid(ent) or !IsValid(ply) then return end

    local Appearance = ply.CurAppearance or {}
    ent.CurAppearance = istable(ply.CurAppearance) and table.Copy(ply.CurAppearance) or nil
    ent:SetNWString("PlayerName", ply:GetNWString("PlayerName", Appearance.AName))
    ent:SetNetVar("Accessories", CopyAppearanceAccessories(ply:GetNetVar("Accessories", "")))

    local tMdl = APmodule.PlayerModels[1][ent:GetModel()] or APmodule.PlayerModels[2][ent:GetModel()] or ent:GetModel()
    if istable(tMdl) then
        for k,v in pairs(tMdl.submatSlots) do
            ent:SetNWString("Colthes" .. k,ply:GetNWString("Colthes" .. k,"normal"))
        end
    end
end

-- Sandbox applyApperance 
if engine.ActiveGamemode() == "sandbox" then
    hook.Add("PlayerSpawn","SetAppearance",function(ply)
        if OverrideSpawn then return end
        timer.Simple(0,function()
            ApplyAppearance(ply,nil,nil,nil,true)
            --ply.OldAppearance = false
        end)
    end)
end
