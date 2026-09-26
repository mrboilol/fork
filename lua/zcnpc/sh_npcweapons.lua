--[[
	What an NPC spawns holding, per kind of NPC.

	The spawn menu already has one of these and it is one gun for everything on
	the map (gmod_npcweapon), which is why a Combine patrol and the refugee it is
	walking past both end up with the same shotgun. This is the same idea kept per
	faction and as a list rather than a single choice: put three rifles in the
	Combine box and each soldier spawns with one of the three.

	The list of guns to choose from is the game's own (NPCUsableWeapons, the list
	the spawn menu's dropdown is built out of), so anything a weapon pack has
	registered for NPCs is in here without us knowing its name. The Half-Life 2
	ones are named below as a fallback, because a dedicated server without the
	sandbox gamemode loaded has an empty list and the stock guns still work.

	Both realms need this file: the server turns the groups into convars and
	decides which group an NPC belongs to, the client builds the picker out of the
	same list.
]]

ZCNPC = ZCNPC or {}

-- Written into a list to mean "spawn with nothing in its hands", so that empty
-- and unarmed stay two different answers.
ZCNPC.WeaponNone = "none"

--\\ The groups, in the order the menu shows them
-- The overwatch line is four boxes rather than one, because "Combine" was never
-- one kind of soldier: a shotgunner, an elite and a Nova Prospekt guard are three
-- different jobs that happen to share an entity class, and putting one list of
-- rifles across all of them is the same flattening the spawn menu's single gun
-- box does to the whole map.
--
-- `parent` is what makes four boxes cost nothing to ignore. A subgroup nobody has
-- filled in reads the box above it, so the Combine list still means every Combine
-- until somebody says otherwise, and filling in the shotgunner box is a change to
-- shotgunners rather than a hole in everything else.
-- `role` is what a group is taken to be carrying when the gun in its hands does
-- not say. Only the randomiser asks (ZCNPC.RandomWeaponFor): a hand-written list
-- is a list somebody chose for that group and does not need to be told what the
-- group is for, but a roll over every gun in the game does. What does not say is
-- commoner than it sounds - a gun out of a pack that filled in no category the
-- addon can read has no job, and no job would mean the whole pool.
ZCNPC.WeaponGroups = {
	{
		id = "combine",
		cvar = "zcnpc_wep_combine",
		name = "Combine soldiers",
		icon = "icon16/user_red.png",
		role = "smg",
		help = "npc_combine_s and the rest of the overwatch line, minus the three below",
	},
	{
		id = "combine_shotgun",
		cvar = "zcnpc_wep_combine_shotgun",
		parent = "combine",
		name = "Shotgunners",
		icon = "icon16/user_red.png",
		role = "shotgun",
		help = "The ones the map or the spawner handed a shotgun to",
	},
	{
		id = "combine_elite",
		cvar = "zcnpc_wep_combine_elite",
		parent = "combine",
		name = "Elites",
		icon = "icon16/shield.png",
		role = "rifle",
		help = "npc_combine_e, and anything wearing the super soldier model",
	},
	{
		id = "combine_prison",
		cvar = "zcnpc_wep_combine_prison",
		parent = "combine",
		name = "Prison guards",
		icon = "icon16/user_suit.png",
		role = "smg",
		help = "Soldiers wearing Nova Prospekt's own prison guard model",
	},
	{
		id = "metrocop",
		cvar = "zcnpc_wep_metrocop",
		name = "Metrocops",
		icon = "icon16/user_orange.png",
		role = "pistol",
		help = "npc_metropolice",
	},
	{
		id = "rebel",
		cvar = "zcnpc_wep_rebel",
		name = "Rebels & medics",
		icon = "icon16/user_green.png",
		role = "rifle",
		help = "npc_citizen wearing group03 / group03m - the ones that fight",
	},
	{
		id = "refugee",
		cvar = "zcnpc_wep_refugee",
		name = "Refugees",
		icon = "icon16/user_gray.png",
		-- A pistol rather than a rifle, and not because a refugee is a worse shot:
		-- what a civilian who has found a weapon has is whatever was small enough
		-- to be lying around.
		role = "pistol",
		help = "npc_citizen wearing group01 / group02 - unarmed by default",
	},
	{
		id = "other",
		cvar = "zcnpc_wep_other",
		name = "Everyone else",
		icon = "icon16/user.png",
		role = "pistol",
		help = "Every other humanoid NPC the addon manages - Barney, Alyx, workshop humans",
	},
}

ZCNPC.WeaponGroupById = {}
ZCNPC.WeaponGroupByCvar = {}

for _, group in ipairs(ZCNPC.WeaponGroups) do
	ZCNPC.WeaponGroupById[group.id] = group
	ZCNPC.WeaponGroupByCvar[group.cvar] = group
end
--//

--\\ Which group an NPC is in
local COMBINE = {
	npc_combine_s = true,
	npc_combine = true,
	npc_combine_e = true,
}

-- Which kind of soldier, off the only two things that can tell them apart. The
-- class and the model are the unit: an elite is npc_combine_e or anything wearing
-- the super soldier model, a prison guard is Nova Prospekt's own model. The gun
-- only ever decides between the two kinds of plain soldier, because that is the
-- only difference there is between those two - a shotgunner and a rifleman are the
-- same entity class with a different additionalequipment, which is why the gun has
-- to be read before it is taken away (ZCNPC.NpcRole, further down).
--
-- In that order, and the order is the answer to the obvious question: a prison
-- guard holding a shotgun is a prison guard. The model is a unit somebody put on
-- the map on purpose and the gun in its hands is a keyvalue.
local function CombineKind(npc, class)
	if class == "npc_combine_e" then return "combine_elite" end

	local mdl = string.lower(npc:GetModel() or "")

	if string.find(mdl, "super_soldier", 1, true) then return "combine_elite" end
	if string.find(mdl, "prisonguard", 1, true) then return "combine_prison" end
	if string.find(mdl, "prison_guard", 1, true) then return "combine_prison" end

	if ZCNPC.NpcRole(npc) == "shotgun" then return "combine_shotgun" end

	return "combine"
end

-- group03 / group03m = rebel / medic rebel. Refugees are group01 / group02.
--
-- Half-Life 2's own citizentype counts CT_DEFAULT, CT_DOWNTRODDEN, CT_REFUGEE,
-- CT_REBEL, CT_UNIQUE - so a rebel is a 3 and a 2 is a refugee. Reading a 2 as
-- the rebel was the whole of "I set refugees to pistols and they still come out
-- as rebels". The other half is worse: asked before the model has settled, every
-- rebel used to answer refugee, that answer was remembered, and both boxes in
-- the gun select then fed one list.
local CT_REFUGEE = 2
local CT_REBEL = 3

local REBEL_MODEL = { "/group03", "rebel", "resistance" }
local REFUGEE_MODEL = { "/group01", "/group02", "refugee", "downtrodden" }

local function ModelKind(mdl)
	for i = 1, #REBEL_MODEL do
		if string.find(mdl, REBEL_MODEL[i], 1, true) then return "rebel" end
	end

	for i = 1, #REFUGEE_MODEL do
		if string.find(mdl, REFUGEE_MODEL[i], 1, true) then return "refugee" end
	end
end

-- "rebel", "refugee", or nil when the model / type has not said yet. Nil is the
-- point: a guess locked in on spawn is how the two boxes shared one pool.
function ZCNPC.CitizenKind(npc)
	if not (IsValid(npc) and npc:IsNPC() and npc:GetClass() == "npc_citizen") then
		return
	end

	local said = ModelKind(string.lower(npc:GetModel() or ""))
	if said then return said end

	local ctype = npc.GetInternalVariable and npc:GetInternalVariable("m_Type")
	if ctype == nil and npc.GetKeyValues then
		local kv = npc:GetKeyValues()
		ctype = kv and (kv.citizentype or kv.CitizenType)
	end

	ctype = tonumber(ctype)
	if ctype == CT_REBEL then return "rebel" end
	if ctype == CT_REFUGEE then return "refugee" end
end

-- Asked once and remembered, and that is the point of it rather than the speed. The
-- guns and the armour are chosen by two different files at two different moments -
-- the armour on the frame the organism appears, the gun on a guard pass a second
-- later - and a citizen's model is not always settled when the first of them asks.
-- Answering twice is how one NPC ended up carrying the refugee gun list over the
-- rebel armour kit, which is nobody's list at all.
--
-- Only remembered once the citizen can actually be told apart, so an early call
-- from OnEntityCreated cannot lock a rebel into the refugee box.
function ZCNPC.WeaponGroupOf(npc)
	if not (IsValid(npc) and npc:IsNPC()) then return end

	local class = npc:GetClass()

	-- Not remembered, unlike the citizen answer below. The model is the model from
	-- the frame it spawned, but the gun a shotgunner is known by can land a tick
	-- after the armour asks - and this is three string searches, not something
	-- worth caching a wrong answer for.
	if COMBINE[class] then return CombineKind(npc, class) end

	if class == "npc_metropolice" then
		npc.zcnpc_wepgroup = "metrocop"

		return "metrocop"
	end

	if class == "npc_citizen" then
		local kind = ZCNPC.CitizenKind(npc)
		if kind then
			npc.zcnpc_wepgroup = kind

			return kind
		end

		return npc.zcnpc_wepgroup
	end

	if npc.zcnpc_wepgroup then return npc.zcnpc_wepgroup end

	local mdl = npc:GetModel()
	if isstring(mdl) and mdl ~= "" then npc.zcnpc_wepgroup = "other" end

	return npc.zcnpc_wepgroup or "other"
end

-- The overwatch line, and only that: npc_combine_s and its relatives, whatever
-- somebody has dressed them in. Civil Protection is not in it - a metrocop is a
-- conscript with a stunstick, and the things this answer is used to refuse are
-- things a conscript would still do.
--
-- Which are the ones that only make sense for a side that has to look after itself.
-- A soldier who goes down is Overwatch's problem and Overwatch's replacement, and the
-- squad steps over him: that is the reason a Combine does not haul another Combine out
-- of the street and kneel on his chest (sv_rescue.lua), and the same reason none of
-- them go through pockets (sv_looting.lua).
function ZCNPC.IsCombine(npc)
	local id = ZCNPC.WeaponGroupOf(npc)

	return isstring(id) and id:sub(1, 7) == "combine"
end
--//

--\\ The guns to choose from
local HL2 = {
	{ class = "weapon_357", title = "357" },
	{ class = "weapon_alyxgun", title = "Alyx Gun" },
	{ class = "weapon_annabelle", title = "Annabelle" },
	{ class = "weapon_ar2", title = "AR2" },
	{ class = "weapon_citizenpackage", title = "Citizen Package" },
	{ class = "weapon_citizensuitcase", title = "Citizen Suitcase" },
	{ class = "weapon_crossbow", title = "Crossbow" },
	{ class = "weapon_crowbar", title = "Crowbar" },
	{ class = "weapon_pistol", title = "Pistol" },
	{ class = "weapon_rpg", title = "RPG" },
	{ class = "weapon_shotgun", title = "Shotgun" },
	{ class = "weapon_smg1", title = "SMG" },
	{ class = "weapon_stunstick", title = "Stunstick" },
}

local function PrettyClass(class)
	local name = class:gsub("^weapon_", ""):gsub("_", " ")

	return name:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
end

-- One entry per class, { class, title, category }, sorted by category then title
-- the same way the spawn menu's own dropdown is.
function ZCNPC.NpcWeapons()
	local byClass = {}

	for _, entry in pairs(list.Get("NPCUsableWeapons") or {}) do
		local class = istable(entry) and entry.class
		if isstring(class) and class ~= "" then
			byClass[class] = {
				class = class,
				title = isstring(entry.title) and entry.title ~= "" and entry.title or PrettyClass(class),
				category = isstring(entry.category) and entry.category or "Other",
			}
		end
	end

	for _, entry in ipairs(HL2) do
		if not byClass[entry.class] then
			byClass[entry.class] = {
				class = entry.class,
				title = entry.title,
				category = "Half-Life 2",
			}
		end
	end

	local out = {}
	for _, entry in pairs(byClass) do
		out[#out + 1] = entry
	end

	table.sort(out, function(a, b)
		if a.category ~= b.category then return a.category < b.category end

		return a.title < b.title
	end)

	return out
end

-- A class is allowed if the game says NPCs can use it, if it is a registered
-- SWEP (a weapon pack that never filled the list in), or if it is one of the
-- stock Half-Life 2 guns. Anything else is somebody's typo or somebody's idea of
-- a joke, and it is checked on the server before it is written to a convar.
function ZCNPC.WeaponAllowed(class)
	if not isstring(class) or class == "" then return false end
	if class == ZCNPC.WeaponNone then return true end
	if not class:match("^[%w_]+$") then return false end

	for _, entry in ipairs(HL2) do
		if entry.class == class then return true end
	end

	for _, entry in pairs(list.Get("NPCUsableWeapons") or {}) do
		if istable(entry) and entry.class == class then return true end
	end

	return istable(weapons.GetStored(class))
end
--//

--\\ How likely each entry is
-- A list of three rifles used to be three equal thirds, which is a squad of six
-- carrying two of each and reads as a uniform of its own. A weight is how many
-- tickets an entry holds in the roll, so a 10 next to two 1s is a squad where one
-- man in six is carrying something else.
--
-- Written into the convar as `class:weight` and only when it is not the default,
-- so a list nobody has touched still reads as the plain comma separated names it
-- always did and an older config still loads.
ZCNPC.WeightMin = 1
ZCNPC.WeightMax = 10
ZCNPC.WeightDefault = 1

function ZCNPC.CleanWeight(value)
	local weight = tonumber(value)
	-- nil for a word, and the self comparison is what catches nan, which no
	-- clamp of any kind survives.
	if not weight or weight ~= weight then return ZCNPC.WeightDefault end

	return math.Clamp(math.Round(weight), ZCNPC.WeightMin, ZCNPC.WeightMax)
end

-- "weapon_ar2:3" -> "weapon_ar2", 3
function ZCNPC.SplitEntry(token)
	local name, weight = string.match(token, "^([^:]+):([^:]+)$")
	if name then return name, ZCNPC.CleanWeight(weight) end

	return token, ZCNPC.WeightDefault
end

function ZCNPC.JoinEntry(name, weight)
	weight = ZCNPC.CleanWeight(weight)
	if weight == ZCNPC.WeightDefault then return name end

	return name .. ":" .. weight
end

-- One entry out of a list, each as likely as its weight says. `blank` is a weight
-- for "none of them" and is what the armour list's own empty ticket is worth; nil
-- means there is no such outcome.
function ZCNPC.PickWeighted(list, weights, blank)
	if not istable(list) or #list == 0 then return end

	weights = weights or {}

	local total = blank and ZCNPC.CleanWeight(blank) or 0
	for i = 1, #list do
		total = total + ZCNPC.CleanWeight(weights[list[i]])
	end

	if total <= 0 then return list[math.random(#list)] end

	local roll = math.random() * total
	local acc = 0

	for i = 1, #list do
		acc = acc + ZCNPC.CleanWeight(weights[list[i]])
		if roll <= acc then return list[i] end
	end

	-- Ran off the end, which is the blank ticket when there is one and float
	-- rounding on the last entry when there is not.
	if blank then return end

	return list[#list]
end
--//

--\\ What kind of gun this is
-- Z-City fills in SWEP.Category for every weapon it ships and names the kind in
-- it ("Weapons - Shotguns"), which is the same string the spawn menu sorts by, so
-- a gun out of a pack nobody here has read still answers this. The Half-Life 2
-- ones have no category worth reading and are named instead.
local ROLE_BY_CLASS = {
	weapon_pistol = "pistol",
	weapon_357 = "pistol",
	weapon_alyxgun = "pistol",
	weapon_smg1 = "smg",
	weapon_ar2 = "rifle",
	weapon_shotgun = "shotgun",
	weapon_crossbow = "sniper",
	weapon_annabelle = "sniper",
	weapon_rpg = "launcher",
	weapon_crowbar = "melee",
	weapon_stunstick = "melee",
}

local ROLE_BY_CATEGORY = {
	["Weapons - Pistols"] = "pistol",
	["Weapons - Machine-Pistols"] = "smg",
	["Weapons - Shotguns"] = "shotgun",
	["Weapons - Carbines"] = "rifle",
	["Weapons - Assault Rifles"] = "rifle",
	["Weapons - Machineguns"] = "rifle",
	["Weapons - Sniper Rifles"] = "sniper",
	["Weapons - Grenade Launchers"] = "launcher",
	["Weapons - Explosive"] = "launcher",
	["Weapons - Melee"] = "melee",
}

-- Last resort for a pack that named its category something of its own.
local ROLE_BY_WORD = {
	{ "shotgun", "shotgun" },
	{ "sniper", "sniper" },
	{ "marksman", "sniper" },
	{ "carbine", "rifle" },
	{ "rifle", "rifle" },
	{ "machinegun", "rifle" },
	{ "smg", "smg" },
	{ "machine-pistol", "smg" },
	{ "submachine", "smg" },
	{ "pistol", "pistol" },
	{ "revolver", "pistol" },
	{ "melee", "melee" },
	{ "knife", "melee" },
	{ "launcher", "launcher" },
}

function ZCNPC.WeaponRole(class)
	if not isstring(class) or class == "" then return end
	if class == ZCNPC.WeaponNone then return end

	if ROLE_BY_CLASS[class] then return ROLE_BY_CLASS[class] end

	local tbl = weapons.GetStored(class)
	local category = istable(tbl) and isstring(tbl.Category) and tbl.Category or nil

	if category then
		if ROLE_BY_CATEGORY[category] then return ROLE_BY_CATEGORY[category] end

		local lower = string.lower(category)
		for _, entry in ipairs(ROLE_BY_WORD) do
			if string.find(lower, entry[1], 1, true) then return entry[2] end
		end
	end

	local lower = string.lower(class)
	for _, entry in ipairs(ROLE_BY_WORD) do
		if string.find(lower, entry[1], 1, true) then return entry[2] end
	end
end

-- Which kinds a given role will accept, best first. Exhausted without a match the
-- caller falls back to the whole list, because a box with nothing an NPC's job
-- covers is somebody asking for that box rather than for the default.
ZCNPC.RoleChain = {
	pistol = { "pistol", "smg" },
	smg = { "smg", "rifle", "pistol" },
	rifle = { "rifle", "smg" },
	shotgun = { "shotgun" },
	sniper = { "sniper", "rifle" },
	launcher = { "launcher" },
	melee = { "melee" },
}

-- What this particular NPC's job is, read off the gun the map or the spawner gave
-- it before we take it away. A Combine shotgunner and a Combine rifleman are the
-- same entity class with different `additionalequipment`, so the gun in its hands
-- is the only thing that tells them apart, and it is remembered because it is
-- gone a moment later.
local ROLE_BY_NPC = {
	npc_metropolice = "pistol",
	npc_combine_s = "smg",
	npc_combine = "smg",
	npc_combine_e = "rifle",
}

function ZCNPC.NpcRole(npc)
	if not IsValid(npc) then return end
	if npc.zcnpc_role then return npc.zcnpc_role end

	local best

	for _, wep in ipairs(npc:GetWeapons()) do
		if IsValid(wep) then
			local role = ZCNPC.WeaponRole(wep:GetClass())

			-- A crowbar in the off hand is not what an NPC is for, so anything
			-- else it is carrying speaks first.
			if role and (not best or best == "melee") then best = role end
		end
	end

	-- Nothing in its hands yet. The gun is still a keyvalue at this point -
	-- additionalequipment, which the engine keeps as m_spawnEquipment and turns into
	-- a real weapon somewhere between Spawn and the tick after it - and reading the
	-- request is as good as reading the result, a good deal earlier.
	if not best and SERVER and npc.GetInternalVariable then
		local equip = npc:GetInternalVariable("m_spawnEquipment")
		if isstring(equip) and equip ~= "" and equip ~= "0" then
			best = ZCNPC.WeaponRole(string.lower(equip))
		end
	end

	best = best or ROLE_BY_NPC[npc:GetClass()]
	if best then npc.zcnpc_role = best end

	return best
end

-- The list narrowed to what `role` will carry, or the list itself when its job is
-- unknown or nothing in the box suits it.
function ZCNPC.WeaponsForRole(list, role)
	if not istable(list) or #list == 0 then return list end
	if not role then return list end

	local chain = ZCNPC.RoleChain[role]
	if not chain then return list end

	for _, want in ipairs(chain) do
		local out = {}

		for _, class in ipairs(list) do
			-- "spawn with nothing" is a valid answer for every job, and dropping
			-- it here would quietly arm the NPCs a list deliberately left empty.
			if class == ZCNPC.WeaponNone or ZCNPC.WeaponRole(class) == want then
				out[#out + 1] = class
			end
		end

		-- Only the blank came through, which is not a match, just the blank.
		if #out > 0 and not (#out == 1 and out[1] == ZCNPC.WeaponNone) then return out end
	end

	return list
end
--//

--\\ Rolling a gun out of everything installed
-- A list somebody wrote is the honest way to do this and it still outranks
-- everything here. This is what happens to the boxes nobody wrote one for, which
-- on a server with three weapon packs mounted is most of them: writing out which
-- of four hundred guns a Combine soldier may carry is not work anybody is going
-- to do, so an empty box says "surprise me" and the pool is everything installed,
-- minus the things that would make a fight worse rather than more varied.
--
-- What is left out, and why each of them:
--
--  * anything with no job this addon can name. The NPC weapon list is not a list
--    of guns - Z-City registers its medicine into it as well (sv_npcstuff.lua
--    registers everything based on weapon_medkit_sh), so bandages, blood bags,
--    duct tape, handcuffs and a walkie talkie are all in there. An NPC issued a
--    tourniquet as its weapon stands in the open holding it.
--  * support and explosive weapons. A belt-fed machinegun and a rocket launcher
--    are things a squad has one of, and a roll that can hand one to everybody is a
--    roll that hands one to everybody: six men with RPGs is not a firefight and
--    six with PKMs is not one either.
--  * melee. A club is not a loadout, it is the absence of one: an NPC handed a
--    knife has nothing to do at range, so it walks at whoever it is angry with and
--    arrives to stand in front of them - the same charge sv_disarmed.lua exists to
--    stop. Rolling one is worse again than finding one on the floor, because it is
--    replacing a gun the spawner meant it to have. A metrocop's stunstick is a
--    different thing and is left alone: the roll only ever replaces a gun.
--  * admin weapons. Something the spawn menu will not give a player without admin
--    is not something to give twenty NPCs behind their back.
--  * anything the pack itself marked unspawnable, which is how a base weapon and a
--    half-finished one both say so.
--  * anything an NPC has no way to fire. See ZCNPC.WeaponUnusable below.
ZCNPC.RandomBlockedRole = {
	launcher = true,
	melee = true,
}

-- Support weapons, off the same evidence WeaponRole reads: the category a pack
-- fills in, then the class name for a pack that named its category something of
-- its own. "Machineguns" is Z-City's own category for the belt-fed ones and the
-- reason it needs saying at all - WeaponRole calls them rifles, correctly, since
-- an NPC handed one should use it like a rifle. Heavy is a separate question to
-- what it is: a PKM is a rifle nobody should be rolling.
local HEAVY_CATEGORY = {
	["Weapons - Machineguns"] = true,
	["Weapons - Grenade Launchers"] = true,
	["Weapons - Explosive"] = true,
}

local HEAVY_WORD = {
	"machinegun", "minigun", "gatling", "lmg", "hmg",
	"rpg", "launcher", "bazooka", "grenade", "mortar", "flamethrower",
	-- Anti-materiel rifles. Registered as sniper rifles, which is what they look
	-- like and not what they are: a round meant for the side of a vehicle.
	"ptrd", "antitank", "anti_tank", "antimateriel", "anti_materiel",
}

function ZCNPC.WeaponHeavy(class)
	if not isstring(class) or class == "" then return false end

	local tbl = weapons.GetStored(class)
	local category = istable(tbl) and isstring(tbl.Category) and tbl.Category or nil

	if category and HEAVY_CATEGORY[category] then return true end

	local haystack = string.lower(class .. " " .. (category or ""))
	for _, word in ipairs(HEAVY_WORD) do
		if string.find(haystack, word, 1, true) then return true end
	end

	return false
end

-- A weapon an NPC cannot fire, which is not the same thing as a weapon it should
-- not be given. Both of the tests below are the weapon saying so about itself.
--
-- The magazine is the general one. Every gun Z-City ships states a positive
-- Primary.ClipSize and everything that is not a gun states -1 - bandages, the
-- hands, throwables - so a stated zero is a third thing: a weapon with a magazine
-- that holds nothing. Nothing loads it and nothing fires it, and an NPC issued one
-- stands in the open holding it for the rest of the fight. Z-City's Bleeding
-- Musket is the one that turns up in practice: it registers as a sniper rifle,
-- passes every other test here, and its trigger is not a trigger at all - the shot
-- is charged by the abnormality system out of the owner's own blood and that code
-- only ever runs for a player (sh_weapon_bleeding_musket.lua:446).
--
-- Which is the second test, and it is that family's own marker rather than its
-- name: a weapon that says it is fired by the abnormality system is saying it is
-- not fired by pulling its trigger.
--
-- Absent is not zero. Half-Life 2's guns are not SWEPs and answer none of this,
-- and a pack that never filled in a Primary table is not making a statement about
-- its magazine - so only a stated zero counts.
function ZCNPC.WeaponUnusable(class)
	local tbl = weapons.GetStored(class)
	if not istable(tbl) then return false end

	if tbl.Abnormalties_ShootableWeapon then return true end

	local primary = istable(tbl.Primary) and tbl.Primary or nil
	if not primary then return false end

	return tonumber(primary.ClipSize) == 0
end

-- Admin only in either of the two ways a weapon says it. AdminOnly is the flag;
-- spawnable to an admin and not to anybody else is the same statement made with
-- two fields, which is what most packs actually do.
local function AdminWeapon(tbl)
	if not istable(tbl) then return false end
	if tbl.AdminOnly then return true end

	return tbl.AdminSpawnable == true and tbl.Spawnable ~= true
end

-- Rebuilt rather than held, because what is installed is not known until it is:
-- a weapon pack registers itself from its own autorun and NPCUsableWeapons is
-- still filling in while the first NPCs on a map are being created. Cleared on
-- InitPostEntity below, which is after all of them.
local pool

function ZCNPC.RandomWeaponPool()
	if pool then return pool end

	pool = {}

	for _, entry in ipairs(ZCNPC.NpcWeapons()) do
		local class = entry.class

		-- No job, no place in the roll. This is the one that keeps the medicine
		-- out, and it does it by knowing what a gun is rather than by naming every
		-- bandage in every pack.
		local role = ZCNPC.WeaponRole(class)
		if not role then continue end
		if ZCNPC.RandomBlockedRole[role] then continue end
		if ZCNPC.WeaponHeavy(class) then continue end
		if ZCNPC.WeaponUnusable(class) then continue end

		local tbl = weapons.GetStored(class)
		if AdminWeapon(tbl) then continue end

		-- Half-Life 2's own guns are not SWEPs and answer none of this, which is
		-- why the test is for a stated no rather than for a yes.
		if istable(tbl) and tbl.Spawnable == false then continue end

		pool[#pool + 1] = class
	end

	table.sort(pool)

	return pool
end

function ZCNPC.ClearRandomWeaponPool()
	pool = nil
end

hook.Add("InitPostEntity", "zcnpc_wep_pool", ZCNPC.ClearRandomWeaponPool)
hook.Add("OnReloaded", "zcnpc_wep_pool", ZCNPC.ClearRandomWeaponPool)

-- One gun for one NPC. `role` is what it was carrying and `fallback` is what its
-- group is for, in that order, because the gun in its hands is about this NPC and
-- the group is about all of them.
--
-- Narrowed to the job whether or not "Match the gun to the job" is on. That
-- setting is about a list somebody wrote - whether a shotgunner rolls the whole
-- box or only the shotguns in it - and there is no list here to respect the
-- shape of. An unfiltered roll over four hundred installed guns is not a loadout
-- anybody asked for; it is a metrocop with a Mosin.
function ZCNPC.RandomWeaponFor(role, fallback)
	local list = ZCNPC.RandomWeaponPool()
	if #list == 0 then return end

	local narrowed = ZCNPC.WeaponsForRole(list, role or fallback)

	-- WeaponsForRole hands the whole list back when a job has nothing in it, which
	-- is the right answer for a box somebody filled in and the wrong one here.
	if not (role or fallback) or #narrowed == 0 then narrowed = list end

	return narrowed[math.random(#narrowed)]
end
--//

--\\ Which end of a gun is the better one
-- Damage a second and a magazine, off the fields a weapon fills in about itself,
-- so a gun out of a pack nobody here has read is still comparable to one that
-- ships with the game.
--
-- Two names for each of the two numbers that matter, because Z-City's own guns
-- and everybody else's disagree about them: the wait between rounds is Wait on a
-- homigrad_base weapon and Delay on a stock one, and a shotgun's pellet count is
-- NumBullet on the first and NumShots on the second.
--
-- Both the body search (sv_looting.lua) and trading a pistol up for a rifle off
-- the floor (sv_disarmed.lua) ask this, and they have to agree or an NPC will
-- fetch a gun it would then refuse to keep.

-- Half-Life 2's own guns are not SWEPs and there is nothing to read off them:
-- weapons.GetStored has no entry for weapon_ar2, so every one of them used to
-- come back as the "answered nothing" score of 1. Which is the same number for
-- all eight of them, and that is worse than being wrong about one - a metrocop
-- with a pistol and an AR2 at its feet compared 1 against 1 and stayed with the
-- pistol, and a rebel holding an AR2 read a Z-City sidearm as the better gun
-- because at least that one had numbers.
--
-- So the numbers are written down here, in the fields the measure already reads,
-- and go through the same arithmetic as everything else. Damage comes off the
-- skill convars the engine actually hits NPCs with rather than the player-facing
-- ones, because that is what these guns do in the hands being scored - and it is
-- also why they all land far below Z-City's rifles, which is not a thing to
-- correct for. An AR2 hits for eight where an AK hits for thirty five, and an NPC
-- that would rather have the AK is right.
--
-- The wait is what the weapon does in an NPC's hands, which is not the player's
-- fire rate: an NPC's shot spacing comes from its own regulator and its weapon's
-- NPC fire rate, so a pistol is half a second between rounds where a player can
-- empty one in two.
local ENGINE_GUNS = {
	weapon_ar2 = { skill = "sk_npc_dmg_ar2", damage = 8, wait = 0.15, clip = 30 },
	weapon_smg1 = { skill = "sk_npc_dmg_smg1", damage = 4, wait = 0.1, clip = 45 },
	weapon_shotgun = { skill = "sk_npc_dmg_buckshot", damage = 5, wait = 1, clip = 6, shots = 7 },
	weapon_357 = { skill = "sk_npc_dmg_357", damage = 30, wait = 1, clip = 6 },
	weapon_annabelle = { skill = "sk_npc_dmg_357", damage = 30, wait = 1.1, clip = 5 },
	weapon_alyxgun = { skill = "sk_npc_dmg_alyxgun", damage = 5, wait = 0.3, clip = 20 },
	weapon_pistol = { skill = "sk_npc_dmg_pistol", damage = 5, wait = 0.5, clip = 18 },
	weapon_crossbow = { skill = "sk_npc_dmg_crossbow", damage = 10, wait = 1.5, clip = 1 },
}

-- Read once and kept. This is asked of every weapon lying within four hundred
-- units of every armed NPC on the map, twice a second (sv_disarmed.lua), and of
-- every class in a body's pockets on top of that - and the answer for a class
-- cannot change while the map is running, since all of it comes off a SWEP's own
-- table or the list above.
local scores = {}

-- Same lifecycle as the spawn pool: skill.cfg is applied on the way into a map,
-- so the convars above are not to be trusted before InitPostEntity, and a lua
-- refresh may have rewritten every SWEP in the game.
function ZCNPC.ClearWeaponScores()
	scores = {}
end

hook.Add("InitPostEntity", "zcnpc_wep_scores", ZCNPC.ClearWeaponScores)
hook.Add("OnReloaded", "zcnpc_wep_scores", ZCNPC.ClearWeaponScores)

-- Nothing stated is read as one round a second, which is roughly what pulling a
-- trigger by hand comes to. Capped so a machine pistol firing twenty a second
-- does not out-score everything else on the map by itself.
local function Rate(wait)
	return wait > 0 and math.min(1 / wait, 12) or 1
end

function ZCNPC.WeaponScore(class)
	local cached = scores[class]
	if cached then return cached end

	local score = 1
	local engine = ENGINE_GUNS[class]

	if engine then
		local cvar = GetConVar(engine.skill)
		local damage = cvar and cvar:GetFloat() or 0

		-- A skill convar of zero is one that has not been set yet rather than a gun
		-- that does no damage.
		if damage <= 0 then damage = engine.damage end

		score = damage * (engine.shots or 1) * Rate(engine.wait) + engine.clip * 0.5
	else
		local tbl = weapons.GetStored(class)
		local primary = istable(tbl) and istable(tbl.Primary) and tbl.Primary or nil
		local damage = primary and tonumber(primary.Damage) or 0

		-- A weapon that answers nothing scores as a last resort rather than as
		-- nothing, since an NPC holding it is still better off than one holding air.
		if damage > 0 then
			local wait = tonumber(primary.Wait) or tonumber(primary.Delay) or 0
			local shots = tonumber(tbl.NumBullet) or tonumber(primary.NumShots) or 1
			local clip = tonumber(primary.ClipSize) or 0

			score = damage * shots * Rate(wait) + math.max(clip, 0) * 0.5
		end
	end

	scores[class] = score

	return score
end
--//

--\\ Convar value <-> list of classes
-- Two returns: the classes in the order they were written, and what each of them
-- is worth in the roll. A caller that only wants the names keeps working, which
-- is most of them.
function ZCNPC.ParseWeaponList(value)
	local out, weights = {}, {}
	if not isstring(value) then return out, weights end

	local seen = {}

	for token in string.gmatch(value, "[^,%s]+") do
		local class, weight = ZCNPC.SplitEntry(string.lower(token))

		if not seen[class] and ZCNPC.WeaponAllowed(class) then
			seen[class] = true
			out[#out + 1] = class
			weights[class] = weight
		end
	end

	return out, weights
end

function ZCNPC.WeaponListString(classes, weights)
	local clean = {}
	local seen = {}

	for _, class in ipairs(classes or {}) do
		if isstring(class) then
			class = string.lower(class)

			if not seen[class] and ZCNPC.WeaponAllowed(class) then
				seen[class] = true
				clean[#clean + 1] = ZCNPC.JoinEntry(class, weights and weights[class])
			end
		end
	end

	return table.concat(clean, ",")
end

-- What this group is set to right now, read off the replicated convar so both
-- realms get the same answer. Exactly this group and nothing inherited: the menu
-- is editing one box and has to be shown the box it is editing.
function ZCNPC.WeaponListFor(id)
	local group = ZCNPC.WeaponGroupById[id]
	if not group then return {}, {} end

	local cvar = GetConVar(group.cvar)
	if not cvar then return {}, {} end

	return ZCNPC.ParseWeaponList(cvar:GetString())
end

-- And what an NPC in that group actually gets, which is the first filled box up
-- its chain (the `parent` field above). Three returns, the third being which box
-- answered, because "loadout combine_shotgun" in the log for a list somebody
-- wrote into the Combine box is a confusing thing to read.
--
-- An empty box at the top of a chain is answered by nothing here: whether that
-- means untouched or a gun out of everything installed is zcnpc_wep_random's
-- question, and it is asked one caller up (sv_npcweapons.lua).
function ZCNPC.WeaponListForNpc(id)
	for _ = 1, 4 do
		if not id then break end

		local classes, weights = ZCNPC.WeaponListFor(id)
		if #classes > 0 then return classes, weights, id end

		local group = ZCNPC.WeaponGroupById[id]
		id = group and group.parent
	end

	return {}, {}
end

-- All of them on the client as well, for the reason ZCNPC.MirrorCvar sets out:
-- the server's copy is replicated onto a convar the client already has, and without one
-- the page above read every list as empty on a dedicated server.
if CLIENT then
	for _, group in ipairs(ZCNPC.WeaponGroups) do
		ZCNPC.MirrorCvar(group.cvar, "")
	end
end
--//
