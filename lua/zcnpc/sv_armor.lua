--[[
	NPCs picking armour up off the floor, and rebel spawn kit.

	Z-City's armour entities only answer Player:Use (armor_base/init.lua:47), so a
	helmet lying next to a bare-headed metrocop is scenery. This walks the same
	way the disarmed gun fetch does: spot a loose piece, jog over, put it on.

	Empty slots are filled. A worn piece is swapped only when the floor piece has
	strictly higher protection — hg.AddArmor only auto-drops for players, so the
	swap path drops through hg.DropArmorForce and then writes the new piece.
]]

local cfg = ZCNPC.Config

--\\ Convars, one per group
-- The armour half of sh_npcarmor.lua, created the same way and for the same
-- reason as the weapon boxes next door: replicated so the menu can show what the
-- server is running before anybody touches it.
for _, group in ipairs(ZCNPC.ArmorGroups or {}) do
	if not ConVarExists(group.cvar) then
		CreateConVar(group.cvar, "", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
			"Armour " .. group.name .. " spawn wearing, comma separated. One piece is rolled "
			.. "per placement the list mentions. Empty leaves them as they are, "
			.. ZCNPC.ArmorNone .. " spawns them with nothing")
	end
end
--//

local SEARCH = 900
local REACH = 64
local GIVE_UP = 20
local SEARCH_SQR = SEARCH * SEARCH
local REPATH = 1.25

-- Loose armour registry: FindInSphere(700) × every NPC every 0.5s was the hot
-- cost. Track spawned pieces instead and only walk this set.
ZCNPC.LooseArmor = ZCNPC.LooseArmor or {}

local function ArmorEnabled()
	return ZCNPC.Enabled() and (not cfg.armor_pickup or cfg.armor_pickup:GetBool())
end

local function IsArmor(ent)
	if not IsValid(ent) then return false end
	if ent:IsPlayerHolding() then return false end

	local class = ent:GetClass()
	if string.sub(class, 1, 10) == "ent_armor_" then return true end

	return ent.Base == "armor_base"
end

local function TrackLooseArmor(ent)
	if not IsArmor(ent) then return end

	ZCNPC.LooseArmor[ent] = true
	ent:CallOnRemove("zcnpc_loose_armor", function(e)
		ZCNPC.LooseArmor[e] = nil
	end)
end

hook.Add("OnEntityCreated", "zcnpc_loose_armor", function(ent)
	-- Scripted armour has its class here. Everything else (casings, NPCs,
	-- weapons) must not get a timer.
	local class = ent:GetClass()
	if isstring(class) and class ~= "" and class:sub(1, 10) ~= "ent_armor_" then
		return
	end

	timer.Simple(0, function()
		if IsValid(ent) then TrackLooseArmor(ent) end
	end)
end)

-- Catch armour that already exists (lua refresh / late load).
local function ScanExistingArmor()
	for _, ent in ipairs(ents.GetAll()) do
		TrackLooseArmor(ent)
	end
end

hook.Add("InitPostEntity", "zcnpc_loose_armor", ScanExistingArmor)
hook.Add("HomigradRun", "zcnpc_loose_armor", function()
	timer.Simple(0, ScanExistingArmor)
end)

local function PieceName(ent)
	if isstring(ent.name) and ent.name ~= "" then return ent.name end

	return string.Replace(ent:GetClass(), "ent_armor_", "")
end

local function PlacementOf(piece)
	if not (hg.armor and isfunction(hg.GetArmorPlacement)) then return end

	return hg.GetArmorPlacement(piece)
end

local function ArmorData(piece)
	local placement = PlacementOf(piece)
	if not placement then return end

	local data = hg.armor[placement] and hg.armor[placement][piece]
	if not data then return end

	return data, placement
end

local function ProtectionOf(piece)
	local data = ArmorData(piece)
	if not data then return 0 end

	return tonumber(data.protection) or 0
end

local function CanWear(npc, piece, placement, data)
	if data.whitelistClasses and npc.PlayerClassName and not data.whitelistClasses[npc.PlayerClassName] then
		return false
	end

	-- a slot blocked by something already worn (helmet blocks face, etc.)
	for plc, arm in pairs(npc.armors or {}) do
		if plc == placement then continue end

		local worn = hg.armor[plc] and hg.armor[plc][arm]
		if worn and worn.restricted and table.HasValue(worn.restricted, placement) then
			return false
		end

		if data.restricted and table.HasValue(data.restricted, plc) then
			return false
		end
	end

	return true
end

-- Empty slot, or a strictly better piece for a filled one.
local function Wants(npc, piece)
	local data, placement = ArmorData(piece)
	if not (data and placement) then return false end

	npc.armors = npc.armors or {}
	if not CanWear(npc, piece, placement, data) then return false end

	local worn = npc.armors[placement]
	if not worn then return true end
	if worn == piece then return false end

	return ProtectionOf(piece) > ProtectionOf(worn)
end

local function FindArmor(npc)
	if not next(ZCNPC.LooseArmor) then return end

	local origin = npc:GetPos()
	local best, bestDist, bestGain

	for ent in pairs(ZCNPC.LooseArmor) do
		if not IsArmor(ent) then
			ZCNPC.LooseArmor[ent] = nil
			continue
		end

		local dist = ent:GetPos():DistToSqr(origin)
		if dist > SEARCH_SQR then continue end

		local piece = PieceName(ent)
		if not Wants(npc, piece) then continue end

		local data, placement = ArmorData(piece)
		if not (data and placement) then continue end

		local worn = npc.armors and npc.armors[placement]
		local gain = ProtectionOf(piece) - (worn and ProtectionOf(worn) or 0)

		-- Bare head / face beats a small vest upgrade: go for the helmet first.
		if not worn then
			if placement == "head" or placement == "face" then
				gain = gain + 100
			else
				gain = gain + 10
			end
		end

		-- Prefer a bigger upgrade; distance breaks ties so they do not zig-zag.
		if not best
			or gain > bestGain
			or (gain == bestGain and dist < bestDist)
		then
			best, bestDist, bestGain = ent, dist, gain
		end
	end

	return best
end

local function SyncWorn(npc)
	if npc.SyncArmor then
		npc:SyncArmor()
	else
		npc:SetNetVar("Armor", npc.armors)
	end

	local rag = npc.zcnpc_rag
	if IsValid(rag) then ZCNPC.TransferArmor(npc, rag) end
end

-- Z-City's npcloot CreateEntityRagdoll only does `rag.armors = ent.armors` and
-- never SetNetVar("Armor"). Downed bodies get a NetVar from Floor(); standing
-- one-shot kills (headshot etc.) leave a corpse the client draws naked.
-- Materials / skins are NW strings on the husk — copy those too.
function ZCNPC.TransferArmor(from, to)
	if not (IsValid(from) and IsValid(to)) then return false end

	local armors = from.armors
	if not istable(armors) or next(armors) == nil then
		local net = from.GetNetVar and from:GetNetVar("Armor")
		if istable(net) and next(net) ~= nil then armors = net end
	end

	if not istable(armors) or next(armors) == nil then return false end

	to.armors = armors

	if to.SyncArmor then
		to:SyncArmor()
	elseif to.SetNetVar then
		to:SetNetVar("Armor", armors)
	end

	for _, piece in pairs(armors) do
		if not isstring(piece) then continue end

		local mat = from:GetNWString("ArmorMaterials" .. piece, "")
		if mat ~= "" then to:SetNWString("ArmorMaterials" .. piece, mat) end

		local skin = from:GetNWInt("ArmorSkins" .. piece, -1)
		if skin >= 0 then to:SetNWInt("ArmorSkins" .. piece, skin) end
	end

	-- First-frame NetVar + ArmorVarSet modelArmor wipe race: push again shortly.
	timer.Simple(0.1, function()
		if not (IsValid(to) and istable(to.armors) and next(to.armors) ~= nil) then return end

		if to.SyncArmor then
			to:SyncArmor()
		elseif to.SetNetVar then
			to:SetNetVar("Armor", to.armors)
		end
	end)

	return true
end

-- Standing engine death: npcloot / TransferOrganismToCorpse left the Lua table
-- but not the replicated Armor NetVar the client draws from.
hook.Add("CreateEntityRagdoll", "zcnpc_armor_corpse", function(ent, rag)
	if not (IsValid(ent) and ent:IsNPC() and IsValid(rag)) then return end
	if not ZCNPC.Enabled() then return end
	if ZCNPC.DropEngineRagdoll and ZCNPC.DropEngineRagdoll(ent, rag) then return end

	rag.zcnpc_npcbody = true
	ZCNPC.TransferArmor(ent, rag)
end)

local function DropWorn(npc, piece)
	if not (IsValid(npc) and isstring(piece) and piece ~= "") then return false end
	if not (istable(npc.armors) and table.HasValue(npc.armors, piece)) then return false end

	local data, placement = ArmorData(piece)
	if not (data and placement) then return false end
	if data.nodrop then return false end

	-- DropArmorForce is the NPC-safe path (no ViewPunch / EyePos / gestures).
	if isfunction(hg.DropArmorForce) then
		local dropped = hg.DropArmorForce(npc, piece)
		if dropped == false then return false end
		if IsValid(dropped) then TrackLooseArmor(dropped) end
	end

	-- Placement keys are strings; clear the slot ourselves so a bad
	-- table.RemoveByValue on the armour table cannot block the upgrade.
	if npc.armors[placement] == piece then
		npc.armors[placement] = nil
		SyncWorn(npc)
	end

	return true
end

function ZCNPC.EquipArmor(npc, armorEnt)
	if not (IsValid(npc) and npc:IsNPC() and IsValid(armorEnt)) then return false end

	local piece = PieceName(armorEnt)
	local data, placement = ArmorData(piece)
	if not (data and placement) then return false end
	if not Wants(npc, piece) then return false end

	local can = hook.Run("CanEquipArmor", npc, piece)
	if can == false then return false end

	npc.armors = npc.armors or {}

	local worn = npc.armors[placement]
	if worn and worn ~= piece then
		if not DropWorn(npc, worn) then return false end
	end

	-- Drop can re-enter LooseArmor tracking; refuse if the slot filled again.
	if npc.armors[placement] then return false end

	npc.armors[placement] = piece

	if armorEnt.ApplyData then
		armorEnt:ApplyData(npc, piece)
	else
		local mat = istable(data.material) and data.material[1] or data.material
		if mat then npc:SetNWString("ArmorMaterials" .. piece, mat) end
		if data.skins then
			npc:SetNWInt("ArmorSkins" .. piece, table.Random(data.skins) or 0)
		end
	end

	SyncWorn(npc)

	armorEnt:EmitSound("snd_jack_hmcd_disguise.wav", 75, math.random(90, 110), 1, CHAN_ITEM)
	armorEnt:Remove()

	ZCNPC.Debug("equipped armour", npc, piece)

	return true
end

--\\ Rebel spawn kit
-- Combine / metrocop already get armour from Z-City's funcspawnNPCs.
-- Only rebels / medic rebels / hostile rebels get a kit — ordinary refugees
-- (group01 / group02) stay unarmoured.
local STOCK_HELMETS = {
	{ piece = "helmet7", weight = 70 }, -- SSh-68
	{ piece = "helmet3", weight = 15 }, -- Riot (rare)
	{ piece = false, weight = 15 },
}

-- vest6 (PACA Soft) is not in here on purpose: Z-City ships it with
-- Spawnable = false because the EFT model it points at is not in the addon, so
-- an NPC wearing it wears nothing. Its share went to the other two soft vests.
local STOCK_VESTS = {
	{ piece = "vest2", weight = 33 }, -- Police Riot Vest
	{ piece = "vest3", weight = 33 }, -- Kevlar IIIA
	{ piece = "vest7", weight = 12 }, -- MF-UNTAR (rare)
	{ piece = false, weight = 22 },
}

-- Soft caps for pieces pulled in from armour-extension addons (Armor Extended…).
-- Stock kit above is always eligible even when a piece sits slightly above these.
local CUSTOM_HELMET_MAX = 5.5
local CUSTOM_VEST_MAX = 5

local FACE_BALLISTIC = 0.40 -- mask1
local FACE_WELDING = 0.10 -- mask3
local MISSING_PIECE = 0.13 -- roll once: strip one of the chosen slots
local UNTAR_SET = 0.12 -- helmet13 + vest7, no face mask

-- Armor Extended (and similar) ship ent_armor_helmet13 as the UNTAR lid.
local function UntarHelmetPiece()
	if istable(hg) and istable(hg.armor) and istable(hg.armor.head) and hg.armor.head["helmet13"] then
		return "helmet13"
	end

	if scripted_ents.GetStored and scripted_ents.GetStored("ent_armor_helmet13") then
		return "helmet13"
	end

	local sent = scripted_ents.Get and scripted_ents.Get("ent_armor_helmet13")
	if istable(sent) then return "helmet13" end
end

local function WeightedPick(list)
	local total = 0
	for i = 1, #list do
		total = total + (list[i].weight or 0)
	end

	if total <= 0 then return end

	local roll = math.random() * total
	local acc = 0
	for i = 1, #list do
		acc = acc + (list[i].weight or 0)
		if roll <= acc then
			local piece = list[i].piece
			return piece ~= false and piece or nil
		end
	end
end

-- Same question the gun list asks (sh_npcweapons.lua). One answer, both halves
-- of a loadout, so a rebel cannot wear the rebel kit and then roll the refugee
-- box because two files guessed differently.
function ZCNPC.IsRebelCitizen(npc)
	return ZCNPC.CitizenKind(npc) == "rebel"
end

-- Medic rebel models live under group03m (and a few workshop renames of the same).
-- The spawnflag is Half-Life 2's own SF_CITIZEN_MEDIC and is what the spawn menu's
-- medic checkbox sets, so a medic on a model named anything at all still heals.
local SF_CITIZEN_MEDIC = 131072

function ZCNPC.IsMedicCitizen(npc)
	if not ZCNPC.IsRebelCitizen(npc) then return false end

	if npc:HasSpawnFlags(SF_CITIZEN_MEDIC) then return true end

	local mdl = string.lower(npc:GetModel() or "")

	return string.find(mdl, "group03m", 1, true) ~= nil
		or string.find(mdl, "medic", 1, true) ~= nil
end

local function PieceAllowed(data, piece, placement, maxProt)
	if not data then return false end
	if data.AdminOnly or data.nodrop then return false end
	if data.Spawnable == false then return false end
	if not data.model or data.model == "" then return false end
	if data.whitelistClasses then return false end

	local prot = tonumber(data.protection) or 0
	if prot <= 0 or prot > maxProt then return false end

	return true
end

local function StockSet(list)
	local set = {}
	for i = 1, #list do
		local piece = list[i].piece
		if piece then set[piece] = true end
	end

	return set
end

-- The protection caps above are ours and the stock kit is allowed to sit over
-- them, but "this piece exists and has a model" is not a taste: a piece Z-City
-- itself refuses to spawn is one whose model is not in the addon, and an NPC
-- wearing it is an NPC wearing nothing at all.
local function StockAllowed(piece)
	local data = ArmorData(piece)
	if not data then return false end
	if data.Spawnable == false then return false end
	if not data.model or data.model == "" then return false end

	return true
end

local function BuildPool(placement, stockList, maxProt)
	local pool = {}
	for i = 1, #stockList do
		local entry = stockList[i]
		if not entry.piece or StockAllowed(entry.piece) then
			pool[#pool + 1] = entry
		end
	end

	local stock = StockSet(stockList)
	local bucket = istable(hg) and istable(hg.armor) and hg.armor[placement]
	if not istable(bucket) then return pool end

	for piece, data in pairs(bucket) do
		if stock[piece] then continue end
		if not PieceAllowed(data, piece, placement, maxProt) then continue end

		-- Mild weight so custom soft pieces show up without drowning the stock kit.
		pool[#pool + 1] = { piece = piece, weight = 10 }
	end

	return pool
end

local function PickFace()
	local roll = math.random()
	if roll <= FACE_WELDING then return "mask3" end
	if roll <= FACE_WELDING + FACE_BALLISTIC then return "mask1" end
end

local function GivePiece(npc, piece)
	if not piece then return false end
	if not StockAllowed(piece) then return false end

	local data, placement = ArmorData(piece)
	if not (data and placement) then return false end

	npc.armors = npc.armors or {}
	if npc.armors[placement] then return false end
	if not CanWear(npc, piece, placement, data) then return false end

	-- Prefer Z-City's helper when present (materials / SyncArmor / hooks).
	if isfunction(hg.AddArmor) then
		local ok = hg.AddArmor(npc, piece)
		if ok == false or ok == nil then return false end

		return true
	end

	npc.armors[placement] = piece
	local mat = istable(data.material) and data.material[1] or data.material
	if mat then npc:SetNWString("ArmorMaterials" .. piece, mat) end
	if data.skins then
		npc:SetNWInt("ArmorSkins" .. piece, table.Random(data.skins) or 0)
	end
	SyncWorn(npc)

	return true
end

function ZCNPC.GiveRebelLoadout(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return false end
	if not ZCNPC.IsRebelCitizen(npc) then return false end
	if not npc.organism then return false end
	if npc.zcnpc_rebel_loadout then return false end
	if cfg.armor_spawn and not cfg.armor_spawn:GetBool() then
		npc.zcnpc_rebel_loadout = true

		return false
	end

	npc.zcnpc_rebel_loadout = true
	npc.armors = npc.armors or {}

	local function FinishLoadout(helmet, vest, face, tag)
		local gave = false
		if helmet and GivePiece(npc, helmet) then gave = true end
		if vest and GivePiece(npc, vest) then gave = true end
		if face and GivePiece(npc, face) then gave = true end

		if gave then
			SyncWorn(npc)
			timer.Simple(0.15, function()
				if IsValid(npc) then SyncWorn(npc) end
			end)
			ZCNPC.Debug(tag or "rebel loadout", npc, helmet or "-", vest or "-", face or "-")
		end

		return gave
	end

	-- 12%: full UNTAR set (helmet13 + vest7), never a face mask.
	-- Only when ent_armor_helmet13 / hg.armor.head.helmet13 is present.
	local untarHelm = UntarHelmetPiece()
	if untarHelm
		and not npc.armors.head
		and not npc.armors.torso
		and math.random() <= UNTAR_SET
	then
		return FinishLoadout(untarHelm, "vest7", nil, "rebel UNTAR set")
	end

	local helmets = BuildPool("head", STOCK_HELMETS, CUSTOM_HELMET_MAX)
	local vests = BuildPool("torso", STOCK_VESTS, CUSTOM_VEST_MAX)

	-- Respect anything another addon already put on them.
	local helmet = not npc.armors.head and WeightedPick(helmets) or nil
	local vest = not npc.armors.torso and WeightedPick(vests) or nil
	local face = not npc.armors.face and PickFace() or nil

	-- ~13%: spawn missing one of the rolled pieces (head / face / torso).
	if math.random() <= MISSING_PIECE then
		local slots = {}
		if helmet then slots[#slots + 1] = "helmet" end
		if vest then slots[#slots + 1] = "vest" end
		if face then slots[#slots + 1] = "face" end

		if #slots > 0 then
			local drop = slots[math.random(#slots)]
			if drop == "helmet" then
				helmet = nil
			elseif drop == "vest" then
				vest = nil
			else
				face = nil
			end
		end
	end

	return FinishLoadout(helmet, vest, face, "rebel loadout")
end

--//

--\\ The armour list, when somebody has filled one in
-- sh_npcarmor.lua holds the boxes; this is what a filled one does. The list is
-- read as a pool of slots: one piece is rolled for each placement it mentions,
-- and a placement it says nothing about is left exactly as it was, so a combine
-- list of one vest changes the vest and leaves the helmet alone.
--
-- Being replaced is silent. A rebel who spawns with a vest chosen for him did not
-- take the old one off in front of anybody, and littering the spawn point with
-- the armour he was never wearing is not the point of the setting.
local function ClearSlot(npc, placement)
	local worn = npc.armors and npc.armors[placement]
	if not worn then return end

	npc.armors[placement] = nil
	npc:SetNWString("ArmorMaterials" .. worn, "")
	npc:SetNWInt("ArmorSkins" .. worn, -1)
end

local function ClearAllSlots(npc)
	for placement in pairs(npc.armors or {}) do
		ClearSlot(npc, placement)
	end
end

-- nil when there is no list at all - which is not the same answer as an empty
-- one, and is why this is not a table return.
local function ListSlots(pieces)
	local slots, blank = {}, false

	for _, piece in ipairs(pieces) do
		if piece == ZCNPC.ArmorNone then
			blank = true

			continue
		end

		local data, placement = ArmorData(piece)
		if not (data and placement) then continue end

		slots[placement] = slots[placement] or {}
		table.insert(slots[placement], piece)
	end

	return slots, blank
end

function ZCNPC.GiveListArmor(npc, id)
	if not (IsValid(npc) and npc:IsNPC()) then return false end

	-- Its own box, or the one above it: an elite nobody has dressed separately
	-- wears what the Combine box says (sh_npcarmor.lua).
	local pieces, weights, from = ZCNPC.ArmorListForNpc(id)
	if #pieces == 0 then return false end

	id = from or id

	npc.armors = npc.armors or {}

	local slots, blank = ListSlots(pieces)

	-- `none` on its own: the whole answer is nothing, including whatever Z-City
	-- or another addon already put on them.
	if not next(slots) then
		ClearAllSlots(npc)
		SyncWorn(npc)
		ZCNPC.Debug("armour list", id, npc, "unarmoured")

		return true
	end

	local worn = {}

	for placement, pool in pairs(slots) do
		-- The blank ticket is one more entry in every named slot's roll, so
		-- helmet7, vest3, none is a squad where about half have each - and it holds
		-- as many tickets as its own weight says, the same as every named piece, so
		-- a 1 next to a helmet on 10 is a squad with one bare head in eleven.
		local pick = ZCNPC.PickWeighted(pool, weights, blank and (weights[ZCNPC.ArmorNone] or 1) or nil)

		ClearSlot(npc, placement)

		if pick and GivePiece(npc, pick) then
			worn[#worn + 1] = pick
		end
	end

	SyncWorn(npc)

	-- Same first-frame NetVar race the rebel kit hits.
	timer.Simple(0.15, function()
		if IsValid(npc) then SyncWorn(npc) end
	end)

	ZCNPC.Debug("armour list", id, npc, #worn > 0 and table.concat(worn, " ") or "nothing")

	return true
end
--//

--\\ Deciding which of the two a spawning NPC gets
local function TrySpawnArmor(ent)
	if not IsValid(ent) then return end
	if not ZCNPC.Enabled() then return end
	if not ent:IsNPC() then return end
	if ent.zcnpc_armorloadout then return end
	if cfg.Blacklist and cfg.Blacklist[ent:GetClass()] then return end
	if ZCNPC.IsZombie(ent) then return end
	if ZCNPC.IsZBaseNPC and ZCNPC.IsZBaseNPC(ent) then
		ent.zcnpc_armorloadout = true

		return
	end

	-- Which box an NPC is in is the weapon list's question and it is asked once,
	-- in one place, so a rebel is a rebel to both halves of its loadout.
	local id = ZCNPC.WeaponGroupOf and ZCNPC.WeaponGroupOf(ent)
	if not id then return end

	if cfg.armor_spawn and not cfg.armor_spawn:GetBool() then
		ent.zcnpc_armorloadout = true

		return
	end

	-- The organism is what tells us Z-City has finished with this one, and both
	-- halves below wait for it. Not out of politeness: a Combine soldier is given
	-- its built-in vest as part of being set up, and choosing a slot before that
	-- happens is choosing a slot Z-City is about to fill in behind us.
	if not ent.organism then return end

	-- A list is somebody's explicit answer and outranks the built-in kit.
	if ZCNPC.GiveListArmor(ent, id) then
		ent.zcnpc_armorloadout = true
		ent.zcnpc_rebel_loadout = true -- the kit below must not run over the top

		return
	end

	-- No list: the rebel kit, for rebels, exactly as before.
	if ent:GetClass() ~= "npc_citizen" then return end

	-- Model / citizentype often settle a tick after OnEntityCreated.
	if not ZCNPC.IsRebelCitizen(ent) then return end

	ZCNPC.GiveRebelLoadout(ent)
	ent.zcnpc_armorloadout = true
end

-- Three passes rather than one, because none of the three things this needs
-- arrive on the same frame: the model a citizen's faction is read off, the
-- organism, and whatever armour Z-City is going to put on it. Each pass is a no
-- op once one of them has taken.
hook.Add("OnEntityCreated", "zcnpc_rebel_loadout", function(ent)
	if not (IsValid(ent) and ent:IsNPC()) then return end

	timer.Simple(0, function()
		TrySpawnArmor(ent)
	end)
	-- Second pass: some spawners set the rebel model after the first tick.
	timer.Simple(0.25, function()
		TrySpawnArmor(ent)
	end)
	-- Third: a spawner that calls Spawn a tick after Create, which is the one that
	-- gets the organism in late.
	timer.Simple(0.75, function()
		TrySpawnArmor(ent)
	end)
end)

-- Late load / lua refresh: kit the NPCs that already exist.
local function ScanSpawnArmor()
	if not ZCNPC.Enabled() then return end

	for ent in pairs(ZCNPC.NPCs or {}) do
		if IsValid(ent) then TrySpawnArmor(ent) end
	end
end

hook.Add("InitPostEntity", "zcnpc_rebel_loadout", function()
	timer.Simple(0, ScanSpawnArmor)
end)
hook.Add("HomigradRun", "zcnpc_rebel_loadout", function()
	timer.Simple(0, ScanSpawnArmor)
end)
--//

local function ClearFetch(npc)
	npc.zcnpc_fetcharmor = nil
	npc.zcnpc_fetcharmoruntil = nil
	npc.zcnpc_fetcharmorpos = nil
	npc.zcnpc_fetcharmorat = nil
	npc.zcnpc_fetcharmorcheck = nil
end

local function FetchArmor(npc, ent)
	npc.zcnpc_fetcharmor = ent
	npc.zcnpc_fetcharmoruntil = npc.zcnpc_fetcharmoruntil or (CurTime() + GIVE_UP)

	local origin = npc:GetPos()
	local goal = ent:GetPos()
	local dist = origin:DistToSqr(goal)

	if dist < REACH * REACH then
		ZCNPC.EquipArmor(npc, ent)
		ClearFetch(npc)

		return
	end

	if CurTime() > npc.zcnpc_fetcharmoruntil then
		ClearFetch(npc)
		npc.zcnpc_nofetcharmor = CurTime() + GIVE_UP

		return
	end

	-- Gun fetch owns the feet when it is already mid-run.
	if IsValid(npc.zcnpc_fetch) then return end

	local sched = npc:GetCurrentSchedule()
	local lastGoal = npc.zcnpc_fetcharmorpos
	local lastAt = npc.zcnpc_fetcharmorat
	local movedGoal = not lastGoal or lastGoal:DistToSqr(goal) > 48 * 48
	local due = (npc.zcnpc_fetcharmorcheck or 0) < CurTime()
	local stuck = due and lastAt and origin:DistToSqr(lastAt) < 24 * 24
	local wrongSched = sched ~= SCHED_FORCED_GO_RUN

	-- Combat AI steals the schedule every think; shove them back onto the run
	-- whenever they are idle, fighting, or have stopped making progress.
	if wrongSched or movedGoal or stuck then
		npc:ClearSchedule()
		npc:SetLastPosition(goal)
		npc:SetSchedule(SCHED_FORCED_GO_RUN)
		npc.zcnpc_fetcharmorpos = Vector(goal)
		npc.zcnpc_fetcharmorat = Vector(origin)
		npc.zcnpc_fetcharmorcheck = CurTime() + REPATH
	elseif due then
		npc.zcnpc_fetcharmorat = Vector(origin)
		npc.zcnpc_fetcharmorcheck = CurTime() + REPATH
	end
end

function ZCNPC.UpdateArmorPickup(npc)
	if not ArmorEnabled() then return end
	if not (IsValid(npc) and npc:IsNPC()) then return end
	if IsValid(npc.zcnpc_rag) then return end

	-- A vest is not worth the map's orders (sv_core.lua). Cleared as well as
	-- refused, so one that walks into a sequence mid-fetch stops there rather
	-- than being shoved at the same vest again the moment the sequence lets go.
	if ZCNPC.MapDriven(npc) then
		ClearFetch(npc)

		return
	end

	-- Medic mid-treat / ducking for a wrap: do not yank them off for a vest.
	if IsValid(npc.zcnpc_healally) then return end
	if (npc.zcnpc_bandagecover or 0) > CurTime() then return end

	-- Nor one with a needle in its own leg (sv_cms.lua) or already kneeling over
	-- a body (sv_looting.lua). Both of those own the feet for as long as they last.
	if istable(npc.zcnpc_cms) then return end
	if istable(npc.zcnpc_meduse) then return end
	if IsValid(npc.zcnpc_lootbody) then return end

	-- And a vest on the floor is certainly not worth putting a man down for
	-- (sv_rescue.lua): that one has hold of somebody and both hands full.
	if istable(npc.zcnpc_rescue) then return end

	-- Still fetching a known piece: keep jogging even if the global set is empty
	-- for a frame. Fresh searches need LooseArmor populated.
	local fetching = IsArmor(npc.zcnpc_fetcharmor)
	if not fetching and not next(ZCNPC.LooseArmor) then return end

	if ZCNPC.IsZombie(npc) then return end
	if (ZCNPC.GettingUp[npc] or 0) > CurTime() then return end
	if npc:GetNetVar("handcuffed", false) then return end
	if ZCNPC.HasHeadcrab and ZCNPC.HasHeadcrab(npc) then return end

	local org = ZCNPC.ResolveOrganism(npc)
	if not org or org.alive == false or org.otrub then return end

	local ent = fetching and npc.zcnpc_fetcharmor or nil

	if not ent and (npc.zcnpc_nofetcharmor or 0) < CurTime() then
		ent = FindArmor(npc)
	end

	if ent then FetchArmor(npc, ent) end
end

-- Tick owned by sv_disarmed's organism.list walk (same 0.5s cadence) so the
-- list is not walked twice. UpdateArmorPickup itself early-outs when armour
-- pickup is off or LooseArmor is empty.

--\\ Stopped rounds must not fill the NPC kinetic stack
-- Z-City multiplies NPC dmgstack by 3 (sv_input.lua:937). protec() turns a
-- stopped bullet into DMG_CLUB, which still counts toward that stack — so a
-- vest / helmet / Welding Mask that "worked" could still amputate or ExplodeHead
-- a moment later. Players never get the mul; wipe the stack when armour ate it.
local BULLET = DMG_BULLET + DMG_BUCKSHOT + DMG_SNIPER

local function WearingAny(ent)
	local armors = IsValid(ent) and ent.armors
	if not istable(armors) then return false end

	return next(armors) ~= nil
end

hook.Add("PreHomigradDamage", "zcnpc_armor_stop", function(victim, dmgInfo)
	local org = IsValid(victim) and victim.organism
	if not org then return end

	-- Keep org.owner.armors pointing at the same table protec() reads.
	if istable(victim.armors) and IsValid(org.owner) then
		org.owner.armors = victim.armors
	end

	org.zcnpc_armor_wasbullet = istable(dmgInfo) and dmgInfo.IsDamageType and dmgInfo:IsDamageType(BULLET) or false
end)

hook.Add("HomigradDamage", "zcnpc_armor_stop", function(victim, dmgInfo)
	if not ZCNPC.Enabled() then return end
	if not IsValid(victim) then return end
	-- Players keep Z-City's own stack; only NPCs get the 3x mul that breaks armour.
	if not (victim:IsNPC() or victim.zcnpc_npcbody) then return end
	if not WearingAny(victim) then return end

	local org = victim.organism
	if not org then return end
	if not org.zcnpc_armor_wasbullet then return end
	if dmgInfo:IsDamageType(BULLET) then return end -- still a bullet: nothing stopped it

	-- Converted to club/slash leftover = armour absorbed the round.
	org.zcnpc_armorstop = CurTime() + 0.15
	timer.Simple(0, function()
		if istable(org) then org.dmgstack = {} end
	end)
end)
--//
