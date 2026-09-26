--[[
	Searching downed NPCs.

	Z-City only fills an inventory when an NPC dies - lootNPCs is walked from the
	"npcloot" CreateEntityRagdoll hook (sv_npcstuff.lua:82). A body that is merely
	knocked out or kicked off its feet has no "Inventory" netvar, and without it the
	loot key combo is dropped on the floor (sv_inventory.lua:439).

	Everything else already works on a plain ragdoll: the loot menu only demands a
	FakeRagdoll from players, and never looks at org.alive.

	Loot is rolled once per NPC (ZCNPC.EnsureLootKit) and remembered across down /
	wake cycles. Taking something off the body marks it spent on the NPC, so
	ragdolling the same one again cannot refill an infinite stash.

	External pools (1nazuma Custom NPC Lootpool), in order:
	  1. hook ZCNPC_RollLoot / HG_CustomNPCLoot.Roll (bridged Workshop builds)
	  2. CreateEntityRagdoll "NPC_Loot_Override" (stock Workshop Nazuma — no Roll API;
	     it only ever filled engine death ragdolls, so downed bodies fell through to
	     NativeLoot: smallconsumable + bandage / painkillers)
	  3. NativeLoot mirror of Z-City's sv_npcstuff.lua
]]

local cfg = ZCNPC.Config

--\\ One kit per NPC for its whole life
-- Hook returns a list of weapon/item classes, or nil to fall back to NativeLoot.
-- NativeLoot entries may be a class string or { class, chance } / { class=, chance= }.
local function ResolveLootEntry(entry)
	if isstring(entry) then
		return entry ~= "" and entry or nil
	end

	if not istable(entry) then return end

	local class = entry.class or entry[1]
	if not (isstring(class) and class ~= "") then return end

	local chance = entry.chance or entry[2]
	if isnumber(chance) and math.random() > chance then return end

	return class
end

-- Bridged Nazuma (and forks): explicit roll API.
local function RollBridged(npc, class)
	local rolled = hook.Run("ZCNPC_RollLoot", npc, class)
	if istable(rolled) then return rolled, "hook" end

	if istable(HG_CustomNPCLoot) and isfunction(HG_CustomNPCLoot.Roll) then
		rolled = HG_CustomNPCLoot.Roll(class)
		if istable(rolled) then return rolled, "HG_CustomNPCLoot" end
	end
end

-- Stock Workshop Nazuma: only CreateEntityRagdoll "NPC_Loot_Override", no globals.
local function NazumaRagHook()
	local group = hook.GetTable()["CreateEntityRagdoll"]
	local fn = group and group["NPC_Loot_Override"]

	return isfunction(fn) and fn or nil
end

--\\ The surgical kit, when 1nazuma's Medicine is mounted
-- Every other item in a kit comes out of a pool somebody else owns - Z-City's
-- own list, or Nazuma's, or whatever a bridged pack rolled - and none of them
-- know about the CMS. So it is added afterwards rather than written into any of
-- them: one roll, on top of whatever the kit already is, from whichever of the
-- three sources filled it.
--
-- Rolled once per NPC and remembered, so a kit that gets upgraded off NativeLoot
-- when a pool mounts late does not get a second chance at one.
local CMS_CLASS = "weapon_cms"
local CMS_CHANCE = 0.10

local function AddCms(npc, kit)
	if not (IsValid(npc) and istable(kit)) then return kit end
	if not (ZCNPC.CmsInstalled and ZCNPC.CmsInstalled()) then return kit end
	if cfg.cms_loot and not cfg.cms_loot:GetBool() then return kit end

	if npc.zcnpc_cmsroll == nil then
		local chance = cfg.cms_chance and cfg.cms_chance:GetFloat() or CMS_CHANCE
		npc.zcnpc_cmsroll = math.random() <= chance
	end

	if not npc.zcnpc_cmsroll then return kit end
	if npc.zcnpc_lootspent and npc.zcnpc_lootspent[CMS_CLASS] then return kit end

	for i = 1, #kit do
		if kit[i] == CMS_CLASS then return kit end
	end

	kit[#kit + 1] = CMS_CLASS

	return kit
end
--//

local function KitFromWeapons(weapons)
	local kit = {}
	if not istable(weapons) then return kit end

	for class in pairs(weapons) do
		if isstring(class) and class ~= "" then
			kit[#kit + 1] = class
		end
	end

	return kit
end

local function ApplyNativeKit(npc, class)
	local kit = {}

	for _, item in ipairs(cfg.NativeLoot[class] or {}) do
		local className = ResolveLootEntry(item)
		if className then kit[#kit + 1] = className end
	end

	AddCms(npc, kit)

	npc.zcnpc_lootkit = kit
	npc.zcnpc_lootsource = "NativeLoot"
	ZCNPC.Debug("loot kit rolled for", npc, class, "NativeLoot", "(" .. #kit .. " items)")

	return kit
end

local function ApplyBridgedKit(npc, class, rolled, source)
	local kit = {}

	for _, item in ipairs(rolled) do
		local className = ResolveLootEntry(item)
		if className then kit[#kit + 1] = className end
	end

	AddCms(npc, kit)

	npc.zcnpc_lootkit = kit
	npc.zcnpc_lootsource = source
	ZCNPC.Debug("loot kit rolled for", npc, class, source or "?", "(" .. #kit .. " items)")

	return kit
end

function ZCNPC.EnsureLootKit(npc, class)
	if not IsValid(npc) then return {} end

	class = class or npc:GetClass()

	-- Self-heal used to freeze NativeLoot before a pool was ready. Bridged rolls
	-- may upgrade a NativeLoot cache; stock Nazuma is handled in BuildDownedLoot.
	if istable(npc.zcnpc_lootkit) then
		if npc.zcnpc_lootsource == "NativeLoot" then
			local upgrade, source = RollBridged(npc, class)
			if istable(upgrade) then
				npc.zcnpc_lootkit = nil
				npc.zcnpc_lootsource = nil
				ZCNPC.Debug("loot kit upgrading off NativeLoot", npc, class)

				return ApplyBridgedKit(npc, class, upgrade, source)
			end
		end

		return npc.zcnpc_lootkit
	end

	npc.zcnpc_lootspent = npc.zcnpc_lootspent or {}

	local rolled, source = RollBridged(npc, class)
	if istable(rolled) then
		return ApplyBridgedKit(npc, class, rolled, source)
	end

	-- Stock Workshop Nazuma has no Roll API. Do not cache NativeLoot for classes
	-- it owns — BuildDownedLoot / FinalizeCorpseLoot fill via its ragdoll hook.
	if NazumaRagHook() and (
		class == "npc_citizen"
		or class == "npc_metropolice"
		or class == "npc_combine_s"
	) then
		-- Nothing of Nazuma's is known yet, but the surgical kit was never part of
		-- its pool: it is ours to add and an NPC standing up should be able to
		-- reach for it (sv_cms.lua) rather than wait to be a corpse.
		npc.zcnpc_lootkit = AddCms(npc, {})
		npc.zcnpc_lootsource = "NazumaPending"
		ZCNPC.Debug("loot kit deferred for Nazuma ragdoll hook", npc, class)

		return npc.zcnpc_lootkit
	end

	return ApplyNativeKit(npc, class)
end

function ZCNPC.MarkLootSpent(npc, class)
	if not (IsValid(npc) and class) then return end

	npc.zcnpc_lootspent = npc.zcnpc_lootspent or {}
	npc.zcnpc_lootspent[class] = true
end

-- Anything from the rolled kit that is no longer in the body's Weapons table was
-- taken. The live sidearm/rifle is not part of the kit: if they pick another gun
-- up later it must be lootable again, so wepclass is left out of spent here.
function ZCNPC.SyncLootSpent(npc, rag, info)
	if not IsValid(npc) then return end

	npc.zcnpc_lootspent = npc.zcnpc_lootspent or {}
	local weapons = IsValid(rag) and rag.inventory and rag.inventory.Weapons
	local offered = info and info.offered or {}

	local kitset = {}
	for _, class in ipairs(npc.zcnpc_lootkit or {}) do
		kitset[class] = true
	end

	for class in pairs(offered) do
		if kitset[class] and not (weapons and weapons[class]) then
			npc.zcnpc_lootspent[class] = true
		end
	end
end
--//

--\\ Stock Nazuma: run its CreateEntityRagdoll filler on our hand-made body
-- Its hook schedules timer.Simple(0), wipes Weapons, and writes the pool. We
-- queue another Simple(0) after calling it so we run once that write is done.
local function FillFromNazumaRagHook(npc, rag, info, heldWep)
	local nazuma = NazumaRagHook()
	if not nazuma then return false end

	nazuma(npc, rag)

	timer.Simple(0, function()
		if not (IsValid(rag) and IsValid(npc) and info) then return end

		local weapons = rag.inventory and rag.inventory.Weapons
		local spent = npc.zcnpc_lootspent or {}

		-- Drop anything already taken earlier this life.
		if istable(weapons) then
			for class in pairs(weapons) do
				if spent[class] then
					weapons[class] = nil
				end
			end
		end

		npc.zcnpc_lootkit = AddCms(npc, KitFromWeapons(rag.inventory and rag.inventory.Weapons))
		npc.zcnpc_lootsource = "Nazuma"
		info.offered = info.offered or {}

		if npc.zcnpc_cmsroll and not spent[CMS_CLASS] then
			ZCNPC.AddLoot(rag, CMS_CLASS)
		end

		for _, class in ipairs(npc.zcnpc_lootkit) do
			info.offered[class] = true
		end

		-- Held gun is not part of Nazuma's pool; put it back after the wipe.
		if isstring(info.wepclass) and info.wepclass ~= "" then
			info.offered[info.wepclass] = true
			ZCNPC.AddLoot(rag, info.wepclass, heldWep)
		end

		info.lootready = true
		if IsValid(rag) then rag:SetNetVar("Inventory", rag.inventory) end

		ZCNPC.Debug("loot ready on downed via Nazuma", info.class, "(" .. #npc.zcnpc_lootkit .. " items)")
	end)

	return true
end

function ZCNPC.BuildDownedLoot(npc, rag, info)
	if not cfg.loot_downed:GetBool() then return end
	if not (IsValid(npc) and IsValid(rag)) then return end

	rag.inventory = rag.inventory or { Weapons = {}, Ammo = {}, Armor = {}, Attachments = {} }
	info.offered = info.offered or {}
	npc.zcnpc_lootspent = npc.zcnpc_lootspent or {}

	local spent = npc.zcnpc_lootspent
	local heldWep

	-- Only Z-City weapons: engine guns are expected to fall next to the corpse and
	-- are handed over by ZCNPC.KillDowned instead. Always mirror whatever is in
	-- their hands right now - a replacement gun after the first was looted is fair game.
	--
	-- The gun rather than the hand, because a man shot while he had a bandage out is
	-- holding a bandage (sv_medical.lua) and it is his rifle that is worth searching him
	-- for.
	local wep = ZCNPC.HeldGun(npc)
	if IsValid(wep) and ZCNPC.IsHomigradWeapon(wep:GetClass()) then
		local wepclass = wep:GetClass()
		info.wepclass = wepclass
		info.offered[wepclass] = true
		heldWep = wep
		ZCNPC.AddLoot(rag, wepclass, wep)
	end

	-- Bridged roll first.
	local rolled, source = RollBridged(npc, info.class)
	if istable(rolled) then
		ApplyBridgedKit(npc, info.class, rolled, source)

		for _, class in ipairs(npc.zcnpc_lootkit) do
			if spent[class] or info.offered[class] then continue end

			info.offered[class] = true
			ZCNPC.AddLoot(rag, class)
		end

		info.lootready = true
		rag:SetNetVar("Inventory", rag.inventory)
		ZCNPC.Debug("loot ready on downed", info.class)

		return
	end

	-- Stock Workshop Nazuma (CreateEntityRagdoll only).
	if FillFromNazumaRagHook(npc, rag, info, heldWep) then
		return
	end

	if not NazumaRagHook() then
		ZCNPC.Debug("Nazuma NPC_Loot_Override hook missing — NativeLoot fallback", info.class)
	end

	-- Vanilla Z-City mirror.
	for _, class in ipairs(ZCNPC.EnsureLootKit(npc, info.class)) do
		if spent[class] or info.offered[class] then continue end

		info.offered[class] = true
		ZCNPC.AddLoot(rag, class)
	end

	info.lootready = true
	rag:SetNetVar("Inventory", rag.inventory)

	ZCNPC.Debug("loot ready on downed", info.class)
end

-- Fill a corpse that never got a downed inventory (loot_downed off, or bleed-out
-- before the kit was applied). Honours spent flags so a previously looted body
-- does not grow a fresh vanilla stash on death.
function ZCNPC.FinalizeCorpseLoot(rag, info)
	if not (IsValid(rag) and info) then return end

	local npc = info.npc
	local spent = IsValid(npc) and npc.zcnpc_lootspent or {}
	info.offered = info.offered or {}

	-- Downed path already ran Nazuma / bridged kit.
	if info.lootready and istable(IsValid(npc) and npc.zcnpc_lootkit) and npc.zcnpc_lootsource ~= "NazumaPending" then
		for _, class in ipairs(npc.zcnpc_lootkit) do
			if spent[class] or info.offered[class] then continue end
			if rag.inventory and rag.inventory.Weapons and rag.inventory.Weapons[class] then
				info.offered[class] = true
				continue
			end

			info.offered[class] = true
			ZCNPC.AddLoot(rag, class)
		end

		return
	end

	local rolled = select(1, RollBridged(IsValid(npc) and npc or rag, info.class))
	if istable(rolled) and IsValid(npc) then
		ApplyBridgedKit(npc, info.class, rolled, "hook")

		for _, class in ipairs(npc.zcnpc_lootkit) do
			if spent[class] or info.offered[class] then continue end
			info.offered[class] = true
			ZCNPC.AddLoot(rag, class)
		end

		return
	end

	if IsValid(npc) and FillFromNazumaRagHook(npc, rag, info, nil) then
		return
	end

	for _, class in ipairs(ZCNPC.EnsureLootKit(IsValid(npc) and npc or rag, info.class)) do
		if spent[class] or info.offered[class] then continue end
		if rag.inventory and rag.inventory.Weapons and rag.inventory.Weapons[class] then
			info.offered[class] = true
			continue
		end

		info.offered[class] = true
		ZCNPC.AddLoot(rag, class)
	end
end

-- The other way round: something that was offered is not in the body any more.
-- Used when a gun leaves the hands for the floor instead - it must not be findable
-- in two places at once.
function ZCNPC.TakeLoot(rag, info, class)
	if not (IsValid(rag) and class) then return end

	-- info.offered stays as it is: it means "this class has already been handed out
	-- one way or another", and a gun lying on the floor is exactly that
	if info and info.wepclass == class then info.wepclass = nil end

	local weapons = rag.inventory and rag.inventory.Weapons
	if weapons and weapons[class] then
		weapons[class] = nil
		rag:SetNetVar("Inventory", rag.inventory)
	end

	local npc = info and info.npc
	if not IsValid(npc) and IsValid(rag) then npc = rag.zcnpc_npc end
	ZCNPC.MarkLootSpent(npc, class)
end

hook.Add("ZCNPC_Downed", "zcnpc_loot", function(npc, rag)
	local info = ZCNPC.Downed[rag]
	if info then ZCNPC.BuildDownedLoot(npc, rag, info) end
end)

-- An NPC that had its gun taken off its unconscious body must not wake up holding it
hook.Add("ZCNPC_WokeUp", "zcnpc_loot", function(npc, org, rag, info)
	if info then ZCNPC.SyncLootSpent(npc, rag, info) end

	if not (info and info.wepclass) then return end

	local left = IsValid(rag) and rag.inventory and rag.inventory.Weapons
	if left and left[info.wepclass] then return end

	ZCNPC.MarkLootSpent(npc, info.wepclass)

	local wep = npc:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == info.wepclass then
		wep:Remove()

		-- Nothing was dropped for it to go back for - the gun is in the pocket of
		-- whoever searched the body - so it is told the same way, and looks for
		-- another one or for somewhere to be instead (sv_disarmed.lua)
		npc.zcnpc_lostwep = nil
		hook.Run("ZCNPC_Disarmed", npc)

		ZCNPC.Debug("woke up disarmed,", info.wepclass, "was looted")
	end
end)

-- Keep spent flags current while the body is still on the floor (loot key → take
-- item never fires a hook we can hear).
timer.Create("zcnpc_loot_sync", 0.5, 0, function()
	if not (ZCNPC.Enabled and ZCNPC.Enabled()) then return end

	for rag, info in pairs(ZCNPC.Downed or {}) do
		if IsValid(rag) and IsValid(info.npc) and info.offered then
			ZCNPC.SyncLootSpent(info.npc, rag, info)
		end
	end
end)

-- Nothing left to take once the body is standing up again
hook.Add("ZB_CanLootInventory", "zcnpc_loot", function(ply, ent)
	if IsValid(ent) and ent.zcnpc_gettingup then return ply, ent, false end
end)
