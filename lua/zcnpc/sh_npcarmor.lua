--[[
	What an NPC spawns wearing, per kind of NPC.

	The same idea as the gun list next door (sh_npcweapons.lua) and the same five
	groups, because it is the same question asked about the other half of a
	loadout: rebels should be able to turn up in a helmet and a vest of somebody's
	choosing, and refugees should not be able to turn up in one at all.

	The difference is slots. A gun list is rolled once and the NPC holds one thing;
	armour is worn a piece per placement, so a list is read as a pool and one piece
	is rolled for each placement it mentions. Put two helmets and a vest in the
	rebel box and every rebel wears the vest and one of the two helmets.

	`none` is the empty ticket. On its own it means unarmoured - which is the whole
	of the refugee answer. Written next to real pieces it is one more thing a slot
	can roll, so a list of helmet7, vest3, none is a squad where about half have a
	lid and about half have a vest.

	An empty list means untouched, and untouched is not the same as unarmoured:
	rebels keep the built-in kit (sv_armor.lua), Combine and metrocops keep the one
	Z-City hands them, and everybody else keeps wearing nothing the way they always
	did.

	The pieces to choose from are Z-City's own (hg.armor, which is shared), so
	anything an armour pack has registered is in the list without us knowing its
	name. Both realms need this file: the server turns the groups into convars and
	rolls them, the client builds the picker out of the same table.
]]

ZCNPC = ZCNPC or {}

ZCNPC.ArmorNone = "none"

--\\ The groups, in the order the menu shows them
-- Deliberately the same ones, with the same ids and the same fallbacks, as the
-- weapon groups: an NPC is in one kind of box, and ZCNPC.WeaponGroupOf is the one
-- place that decides which.
ZCNPC.ArmorGroups = {
	{
		id = "combine",
		cvar = "zcnpc_arm_combine",
		name = "Combine soldiers",
		icon = "icon16/user_red.png",
		help = "npc_combine_s and the rest of the overwatch line, minus the three below",
	},
	{
		id = "combine_shotgun",
		cvar = "zcnpc_arm_combine_shotgun",
		parent = "combine",
		name = "Shotgunners",
		icon = "icon16/user_red.png",
		help = "The ones the map or the spawner handed a shotgun to",
	},
	{
		id = "combine_elite",
		cvar = "zcnpc_arm_combine_elite",
		parent = "combine",
		name = "Elites",
		icon = "icon16/shield.png",
		help = "npc_combine_e, and anything wearing the super soldier model",
	},
	{
		id = "combine_prison",
		cvar = "zcnpc_arm_combine_prison",
		parent = "combine",
		name = "Prison guards",
		icon = "icon16/user_suit.png",
		help = "Soldiers wearing Nova Prospekt's own prison guard model",
	},
	{
		id = "metrocop",
		cvar = "zcnpc_arm_metrocop",
		name = "Metrocops",
		icon = "icon16/user_orange.png",
		help = "npc_metropolice",
	},
	{
		id = "rebel",
		cvar = "zcnpc_arm_rebel",
		name = "Rebels & medics",
		icon = "icon16/user_green.png",
		help = "npc_citizen wearing group03 / group03m - the ones that fight",
	},
	{
		id = "refugee",
		cvar = "zcnpc_arm_refugee",
		name = "Refugees",
		icon = "icon16/user_gray.png",
		help = "npc_citizen wearing group01 / group02 - unarmoured by default",
	},
	{
		id = "other",
		cvar = "zcnpc_arm_other",
		name = "Everyone else",
		icon = "icon16/user.png",
		help = "Every other humanoid NPC the addon manages - Barney, Alyx, workshop humans",
	},
}

ZCNPC.ArmorGroupById = {}
ZCNPC.ArmorGroupByCvar = {}

for _, group in ipairs(ZCNPC.ArmorGroups) do
	ZCNPC.ArmorGroupById[group.id] = group
	ZCNPC.ArmorGroupByCvar[group.cvar] = group
end
--//

--\\ The pieces to choose from
-- Placement is Z-City's own word for a slot and there are three that matter:
-- torso, head, face. Ears and the rest are in hg.armor too and are listed the
-- same way, since an armour pack is free to add another.
local PLACEMENT_ORDER = {
	torso = 1,
	head = 2,
	face = 3,
	ears = 4,
}

local PLACEMENT_NAME = {
	torso = "Vests",
	head = "Helmets",
	face = "Face",
	ears = "Ears",
}

function ZCNPC.ArmorPlacementName(placement)
	if PLACEMENT_NAME[placement] then return PLACEMENT_NAME[placement] end

	return placement:sub(1, 1):upper() .. placement:sub(2)
end

local function PrettyPiece(piece)
	local names = istable(hg) and hg.armorNames
	if istable(names) and isstring(names[piece]) and names[piece] ~= "" then
		return names[piece]
	end

	return piece:sub(1, 1):upper() .. piece:sub(2)
end

-- Every wearable piece Z-City knows about, { piece, title, placement, protection,
-- icon }, sorted by placement then title. A piece Z-City itself refuses to spawn
-- has no model in the addon and an NPC wearing it wears nothing, so it is not
-- offered - the same line sv_armor.lua draws for the built-in kit.
function ZCNPC.NpcArmor()
	local out = {}

	if not (istable(hg) and istable(hg.armor)) then return out end

	local icons = istable(hg.armorIcons) and hg.armorIcons or {}

	for placement, bucket in pairs(hg.armor) do
		if not istable(bucket) then continue end

		for piece, data in pairs(bucket) do
			if not (isstring(piece) and istable(data)) then continue end
			if data.inbuilt then continue end
			if data.Spawnable == false then continue end
			if not data.model or data.model == "" then continue end

			out[#out + 1] = {
				piece = piece,
				title = PrettyPiece(piece),
				placement = placement,
				protection = tonumber(data.protection) or 0,
				icon = icons[piece],
			}
		end
	end

	table.sort(out, function(a, b)
		if a.placement ~= b.placement then
			local orderA = PLACEMENT_ORDER[a.placement] or 99
			local orderB = PLACEMENT_ORDER[b.placement] or 99

			if orderA ~= orderB then return orderA < orderB end

			return a.placement < b.placement
		end

		return a.title < b.title
	end)

	return out
end

function ZCNPC.ArmorAllowed(piece)
	if not isstring(piece) or piece == "" then return false end
	if piece == ZCNPC.ArmorNone then return true end
	if not piece:match("^[%w_]+$") then return false end

	if not (istable(hg) and istable(hg.armor)) then return false end

	for _, bucket in pairs(hg.armor) do
		if istable(bucket) and istable(bucket[piece]) then return true end
	end

	return false
end
--//

--\\ Convar value <-> list of pieces
-- Weights are the gun list's (ZCNPC.SplitEntry, sh_npcweapons.lua, which loads
-- first), written the same `piece:weight` way and meaning the same thing: how many
-- tickets that vest holds in the roll for its slot.
function ZCNPC.ParseArmorList(value)
	local out, weights = {}, {}
	if not isstring(value) then return out, weights end

	local seen = {}

	for token in string.gmatch(value, "[^,%s]+") do
		local piece, weight = ZCNPC.SplitEntry(token)

		if not seen[piece] and ZCNPC.ArmorAllowed(piece) then
			seen[piece] = true
			out[#out + 1] = piece
			weights[piece] = weight
		end
	end

	return out, weights
end

function ZCNPC.ArmorListString(pieces, weights)
	local clean = {}
	local seen = {}

	for _, piece in ipairs(pieces or {}) do
		if not isstring(piece) then continue end

		if not seen[piece] and ZCNPC.ArmorAllowed(piece) then
			seen[piece] = true
			clean[#clean + 1] = ZCNPC.JoinEntry(piece, weights and weights[piece])
		end
	end

	return table.concat(clean, ",")
end

-- This group's own box, for the menu that is editing it.
function ZCNPC.ArmorListFor(id)
	local group = ZCNPC.ArmorGroupById[id]
	if not group then return {}, {} end

	local cvar = GetConVar(group.cvar)
	if not cvar then return {}, {} end

	return ZCNPC.ParseArmorList(cvar:GetString())
end

-- And what an NPC in it wears, which is the first filled box up the chain, the
-- same way the gun list resolves (ZCNPC.WeaponListForNpc). An untouched Combine
-- subgroup dresses like a Combine soldier, and an untouched Combine box is still
-- Z-City's own vest and nothing of ours.
function ZCNPC.ArmorListForNpc(id)
	for _ = 1, 4 do
		if not id then break end

		local pieces, weights = ZCNPC.ArmorListFor(id)
		if #pieces > 0 then return pieces, weights, id end

		local group = ZCNPC.ArmorGroupById[id]
		id = group and group.parent
	end

	return {}, {}
end

-- And on the client, same as the gun lists next door and for the same reason
-- (ZCNPC.MirrorCvar): a replicated convar needs one of its own name on this side to
-- land on, or the picker reads every group as untouched.
if CLIENT then
	for _, group in ipairs(ZCNPC.ArmorGroups) do
		ZCNPC.MirrorCvar(group.cvar, "")
	end
end
--//
