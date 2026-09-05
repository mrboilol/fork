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

local accessoryModelBounds = {}

local function GetAccessoryModelBounds(model)
	if !isstring(model) then return end

	local cached = accessoryModelBounds[model]
	if cached then return cached.mins, cached.maxs end

	local mins, maxs
	if isfunction(util.GetModelBounds) then
		mins, maxs = util.GetModelBounds(model)
	end

	if !mins or !maxs then
		local probe = ents.Create("base_anim")
		if IsValid(probe) then
			probe:SetModel(model)
			mins, maxs = probe:GetModelBounds()
			probe:Remove()
		end
	end

	accessoryModelBounds[model] = {mins = mins, maxs = maxs}
	return mins, maxs
end

local function FindAccessoryImpact(ent, accessories, hitPos, direction)
	if !isvector(hitPos) or !isvector(direction) or direction:LengthSqr() <= 0.001 then return end

	local rayDirection = direction:GetNormalized() * 128
	local rayStart = hitPos - rayDirection * 0.5
	local nearest

	for index, accessoryID in pairs(accessories) do
		local accessory = hg.Accessories[accessoryID]
		if !IsDroppableAccessory(accessory) then continue end

		local pos, ang, scale = GetAccessoryTransform(ent, accessory)
		if !pos then continue end

		local mins, maxs = GetAccessoryModelBounds(accessory[ThatPlyIsFemale(ent) and "femmodel"] or accessory.model)
		if !mins or !maxs then continue end

		local impactPos = util.IntersectRayWithOBB(rayStart, rayDirection, pos, ang, mins * scale, maxs * scale)
		if !impactPos then continue end

		local distance = impactPos:DistToSqr(rayStart)
		if !nearest or distance < nearest.distance then
			nearest = {
				id = accessoryID,
				index = index,
				data = accessory,
				position = impactPos,
				distance = distance,
			}
		end
	end

	return nearest
end

local function SpawnAccessoryDrop(accessoryID, accessory, owner, position, force)
	local model = accessory[ThatPlyIsFemale(owner) and "femmodel"] or accessory.model
	if !model then return end

	local dropped = ents.Create("prop_physics")
	if !IsValid(dropped) then return end

	dropped:SetModel(model)
	dropped:SetPos(position)
	dropped:SetAngles(AngleRand())
	dropped:Spawn()
	dropped:SetModelScale((accessory[ThatPlyIsFemale(owner) and "fempos"] or accessory.malepos or {})[3] or 1, 0)
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

	local phys = dropped:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(2)
		phys:Wake()
		if isvector(force) and force:LengthSqr() > 0 then
			phys:AddVelocity(force:GetNormalized() * math.Clamp(force:Length() * 0.08, 90, 340))
		end
	end

	timer.Simple(180, function()
		if IsValid(dropped) then dropped:Remove() end
	end)

	return dropped
end

function APmodule.TryAbsorbAccessoryImpact(ent, dmgInfo, hitPos, direction)
	if !IsValid(ent) or !dmgInfo or !dmgInfo:IsDamageType(accessoryImpactTypes) then return end

	local damage = dmgInfo:GetDamage()
	if damage < 16 then return end

	local wearer = GetAccessoryWearer(ent)
	if !IsValid(wearer) then return end

	local accessories = ent:GetNetVar("Accessories", wearer:GetNetVar("Accessories", {}))
	if !istable(accessories) then return end

	local impact = FindAccessoryImpact(ent, accessories, hitPos, direction)
	if !impact then return end

	local severity = math.Clamp((damage - 16) / 84, 0, 1)
	local absorbed = 0.12 + severity * 0.18
	local dropChance = 0.08 + severity * 0.42
	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then dropChance = dropChance + 0.1 end

	if math.Rand(0, 1) <= dropChance then
		absorbed = absorbed + 0.16
		if isnumber(impact.index) then
			table.remove(accessories, impact.index)
		else
			accessories[impact.index] = nil
		end
		SyncAccessories(wearer, accessories)
		SpawnAccessoryDrop(impact.id, impact.data, wearer, impact.position, direction)
	end

	dmgInfo:ScaleDamage(math.Clamp(1 - absorbed, 0.45, 1))
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
			SpawnAccessoryDrop(replacedID, replacedAccessory, ply, dropped:GetPos(), dropped:GetVelocity())
		end
		accessories[replacement] = accessoryID
	else
		accessories[#accessories + 1] = accessoryID
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

	local dropped = SpawnAccessoryDrop(accessoryID, accessory, ply, ply:EyePos() + ply:EyeAngles():Forward() * 18, ply:EyeAngles():Forward() * 150)
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

local function ForceApplyAppearance(ply, tbl, noModelChange)
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
    if !APmodule.AppearanceValidater(tAppearance) then bRandom = true end

    -- Update cache immediately so next respawn uses this
    client.CachedAppearance = tAppearance

    ApplyAppearance(client,tAppearance, table.IsEmpty(tAppearance) and true or bRandom,true)
end)

net.Receive("OnlyGet_Appearance",function(len,client)
    local tAppearance = net.ReadTable()
    local bRandom = !tAppearance or table.IsEmpty(tAppearance)
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
