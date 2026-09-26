--[[
	NPCs spend what is in their pockets.

	A Combine soldier throws npc_grenade_frag. Z-City then swaps that for its
	own HL2 grenade. The kit, meanwhile, may have rolled a molotov, a pipe
	bomb, an RGD - and none of those ever left the pocket. This file is the
	swap: when an NPC of ours throws, the thing that leaves the hand is the
	throwable it is actually carrying.

	Weapons and armour already come out of the lists this addon owns. Medicine
	already spends the kit. What was missing is the grenade.
]]

local cfg = ZCNPC.Config

local NADES = {
	"weapon_hg_molotov_tpik",
	"weapon_hg_pipebomb_tpik",
	"weapon_hg_rgd_tpik",
	"weapon_hg_grenade_tpik",
	"weapon_hg_hl2nade_tpik",
	"weapon_hg_flashbang_tpik",
	"weapon_hg_smokenade_tpik",
	"weapon_hg_f1_tpik",
	"weapon_frag",
}

local FALLBACK_ENT = {
	weapon_hg_molotov_tpik = "ent_hg_grenade_molotov",
	weapon_hg_pipebomb_tpik = "ent_hg_grenade_pipebomb",
	weapon_hg_rgd_tpik = "ent_hg_grenade_rgd",
	weapon_hg_grenade_tpik = "ent_hg_grenade_m67",
	weapon_hg_hl2nade_tpik = "ent_hg_grenade_hl2grenade",
	weapon_hg_flashbang_tpik = "ent_hg_grenade_flashbang",
	weapon_hg_smokenade_tpik = "ent_hg_grenade_smoke",
	weapon_frag = "ent_hg_grenade_hl2grenade",
}

local function InventoryOn()
	return not cfg.inventory_use or cfg.inventory_use:GetBool()
end

local function KitHas(npc, class)
	if npc:HasWeapon(class) then return true end
	if ZCNPC.KitHasItem then return ZCNPC.KitHasItem(npc, class) end

	local kit = npc.zcnpc_lootkit
	if not istable(kit) then return false end

	for i = 1, #kit do
		if kit[i] == class then return true end
	end

	return false
end

local function PickNade(npc)
	for i = 1, #NADES do
		local class = NADES[i]
		if KitHas(npc, class) then return class end
	end
end

local function NadeEnt(class)
	local stored = isfunction(weapons.GetStored) and weapons.GetStored(class)
	if istable(stored) and isstring(stored.ENT) and stored.ENT ~= "" then
		return stored.ENT
	end

	return FALLBACK_ENT[class]
end

local function ThrowNade(npc, class, from)
	local entClass = NadeEnt(class)
	if not entClass then return false end

	local nade = ents.Create(entClass)
	if not IsValid(nade) then return false end

	local hand = npc:LookupBone("ValveBiped.Bip01_R_Hand")
	local pos = (hand and npc:GetBonePosition(hand)) or (npc:WorldSpaceCenter() + npc:GetForward() * 16)
	local enemy = npc:GetEnemy()
	local dest = IsValid(enemy) and enemy:WorldSpaceCenter() or (pos + npc:GetForward() * 400)
	local dir = (dest - pos):GetNormalized()

	nade:SetPos(pos + dir * 8 + vector_up * 4)
	nade:SetAngles(dir:Angle())
	nade:Spawn()
	nade:Activate()
	nade.owner = npc
	nade.IsSpawned = true

	if nade.SetOwner then nade:SetOwner(npc) end
	if nade.timer == nil then nade.timer = CurTime() end

	local phys = nade:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(dir * 900 + vector_up * 200)
	end

	if ZCNPC.MarkLootSpent then ZCNPC.MarkLootSpent(npc, class) end
	if npc:HasWeapon(class) then npc:StripWeapon(class) end

	ZCNPC.Debug("threw kit grenade", npc, class, entClass)

	return true
end

-- The engine frag is created, then Z-City replaces it a tick later. Catch it
-- on spawn, before that swap, and put the kit's own grenade in its place.
-- A weapon whose attachments table never landed throws on pickup. Give it an
-- empty one rather than let every gun in the map dump the same error.
hook.Add("PlayerCanPickupWeapon", "zcnpc_inventory_att", function(_, wep)
	if not IsValid(wep) then return end
	if wep.attachments == nil then wep.attachments = {} end
end)

hook.Add("OnEntityCreated", "zcnpc_inventory_nade", function(ent)
	if not InventoryOn() then return end
	if not ZCNPC.Enabled() then return end

	-- Engine grenades usually have their class here. Anything else is a
	-- casing / prop and must not get a timer.
	local class = ent:GetClass()
	if isstring(class) and class ~= "" and class ~= "npc_grenade_frag" then return end

	timer.Simple(0, function()
		if not IsValid(ent) then return end
		if ent:GetClass() ~= "npc_grenade_frag" then return end

		local owner = ent:GetOwner()
		if not (IsValid(owner) and owner:IsNPC()) then return end
		if ZCNPC.IsZombie and ZCNPC.IsZombie(owner) then return end

		local class = PickNade(owner)
		if not class or class == "weapon_hg_hl2nade_tpik" or class == "weapon_frag" then
			return
		end

		local pos = ent:GetPos()
		ent:Remove()
		ThrowNade(owner, class, pos)
	end)
end)
