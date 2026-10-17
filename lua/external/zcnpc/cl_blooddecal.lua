--[[
	How big Z-City's blood decals are drawn.

	The file next to this one thins out the droplets in the air; this is what
	they leave behind when they land. A decal is cheap to place and expensive to
	look at - it is drawn again over every surface it overlaps, so what it costs
	is the area it covers, and a room a firefight has been through is a floor
	drawn twice. Shrinking them is the one lever on that which does not remove
	them.

	The size is a material property and not an argument, which is why this is a
	material pass rather than a wrapper: Source reads $decalscale off the
	material at the moment a decal is applied, and Z-City sets that itself
	(autorun/shitdecals.lua) to give its eleven droplet textures five sizes.
	So the number it wrote is the size, and ours is a fraction of it - which
	makes 1 exactly Z-City's own rather than an approximation of it.

	Read once and remembered, because after the first write the material no
	longer holds Z-City's number, it holds ours. The reading waits for the frame
	after InitPostEntity for the same reason: Z-City sets its sizes from that
	hook, and a base captured before it would be whatever the .vmt shipped with.

	Both of Z-City's sets, and everybody's blood rather than only the NPCs'. A
	material has no idea who bled on it, and the alternative - a second set of
	materials for NPC blood - is more decal materials to make a scene cheaper,
	which is backwards.
]]

ZCNPC = ZCNPC or {}

-- Z-City's own droplets: drop1_1 through drop11_5, eleven textures in five
-- sizes, and the size is the only thing that separates _1 from _5.
local DROPLET_TEXTURES = 11
local DROPLET_SIZES = 5

-- The set drawn instead when somebody has turned hg_old_blood on. Named the
-- same way, ten each, and scaled the same way for the same reason.
local OLD_SETS = { "decals/z_blood", "decals/arterial_blood" }
local OLD_COUNT = 10

local SCALE_KEY = "$decalscale"

local sizeCvar
local applied -- the multiplier the materials are currently holding
local bases = {} -- material -> the size Z-City gave it

-- Nothing is read or written before this is true, and that is the whole of the
-- timing: Z-City sets its sizes twice, once when its file loads and once from
-- InitPostEntity, and a base read before the later of the two is whatever the
-- .vmt shipped with rather than what Z-City wanted. The convar can arrive well
-- before either - it is replicated, so a client is sent it on the way in, and
-- being sent it fires the callback at the bottom of this file.
local ready = false

local function Size()
	if not sizeCvar then sizeCvar = GetConVar("zcnpc_blood_decal") end
	if not sizeCvar then return 1 end

	return sizeCvar:GetFloat()
end

-- Built once. Material() is a lookup rather than a load after the first call,
-- but there are 75 of these and this runs from a convar change.
local mats
local function Materials()
	if mats then return mats end

	mats = {}

	for texture = 1, DROPLET_TEXTURES do
		for size = 1, DROPLET_SIZES do
			local mat = Material("effects/droplets/drop" .. texture .. "_" .. size)
			if mat and not mat:IsError() then mats[#mats + 1] = mat end
		end
	end

	for _, set in ipairs(OLD_SETS) do
		for i = 1, OLD_COUNT do
			local mat = Material(set .. i)
			if mat and not mat:IsError() then mats[#mats + 1] = mat end
		end
	end

	return mats
end

-- Z-City's size for one material, asked once. A material with no $decalscale of
-- its own is drawn at one, which is the engine's default and so the honest base
-- for it.
local function Base(mat)
	local base = bases[mat]
	if base then return base end

	base = tonumber(mat:GetFloat(SCALE_KEY)) or 1
	if base <= 0 then base = 1 end

	bases[mat] = base

	return base
end

local function Apply(force)
	if not ready then return end

	-- The server's copy is made with this setting's own range on it
	-- (sv_config.lua), so there is no range to repeat here - only the one value
	-- that would make every decal vanish rather than shrink.
	local mul = Size()
	if not (mul > 0) then mul = 1 end

	if not force and applied == mul then return end

	applied = mul

	for _, mat in ipairs(Materials()) do
		mat:SetFloat(SCALE_KEY, Base(mat) * mul)
	end
end

-- The frame after InitPostEntity rather than in it, so this runs after Z-City's
-- own hook has set the sizes this reads as its bases.
local function Start()
	ready = true

	Apply(true)
end

hook.Add("InitPostEntity", "zcnpc_blooddecal", function() timer.Simple(0, Start) end)

-- A Lua refresh re-runs Z-City's file, which puts its own sizes back over ours.
-- The bases are already read by then, so this is a re-apply and not a re-read.
hook.Add("OnReloaded", "zcnpc_blooddecal", function() timer.Simple(0, Start) end)

pcall(cvars.AddChangeCallback, "zcnpc_blood_decal", function()
	Apply(false)
end, "zcnpc_blooddecal")

-- The callback above is the one that should do it, and on a replicated convar
-- pushed from a server it has been known not to. One float comparison a second
-- is cheaper than a setting that only takes effect on the next map.
timer.Create("zcnpc_blooddecal", 1, 0, function() Apply(false) end)
