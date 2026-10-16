-- Material registry. Engine decals use the shipped LightmappedGeneric VMTs (with $modelmaterial
-- for studio models). Directional decals get lazily created rotated variants through
-- $basetexturetransform. Everything else ABL draws itself with UnlitGeneric materials, in three kinds
-- of pass (see tools/texgen for the textures and cl_render.lua for the blend states):
--   * filter:  blood as an absorbing film multiplied over the lit surface (the surface shows through
--              thin blood, lighting and shadows are the real ones): ground stains, runoff trails,
--              settled body streaks,
--   * colour:  blood with its own colour and alpha, lit on the CPU through vertex colours: drops,
--              flowing rivulets, wet overlays on walls,
--   * gloss:   additive reflection of the surroundings where blood is wet, shaped by a gloss mask.

ABL.NoJIT()
ABL.Mat = ABL.Mat or {}
local M = ABL.Mat

local families = {
	drop = 4, splat = 4, elong = 4, sat = 3, streak = 4, smear = 4, pool = 4, soak = 3, wound = 1,
}
M.families = families

-- texture width in pixels (decalscale = 1/width, so DecalEx scale == world units)
M.texSize = { drop = 256, splat = 512, elong = 512, sat = 256, streak = 256, smear = 512, pool = 512, soak = 256, wound = 256 }
-- world units covered by the stain content relative to the texture width (content radius)
M.contentScale = { drop = 0.66, splat = 0.8, elong = 0.9, sat = 0.9, streak = 0.5, smear = 0.95, pool = 0.9, soak = 0.62, wound = 0.6 }

M.decal = {}   -- family -> { IMaterial ... }
M.rotated = {} -- "family:index:step" -> IMaterial

local function Unlit(name, tex, kind, extra)
	local kv = { ["$basetexture"] = tex, ["$vertexcolor"] = 1, ["$vertexalpha"] = 1, ["$nocull"] = 1 }
	if kind == "additive" then kv["$additive"] = 1 else kv["$translucent"] = 1 end
	for k, v in pairs(extra or {}) do kv[k] = v end
	return CreateMaterial(name, "UnlitGeneric", kv)
end

local function Load()
	for fam, n in pairs(families) do
		M.decal[fam] = {}
		for i = 1, n do M.decal[fam][i] = Material("advancedblood/decals/" .. fam .. i) end
	end
	-- airborne blood
	M.droplet = Material("advancedblood/sprites/droplet")        -- a lit liquid drop (colour)
	M.dropStreak = Material("advancedblood/sprites/dropstreak")  -- the same drop smeared by motion
	M.stream = Material("advancedblood/sprites/stream")          -- arterial jet segment (loose)
	M.streamTile = Material("advancedblood/sprites/streamtile")  -- a continuous stream, tiled along it
	M.glint = Material("advancedblood/sprites/glint")            -- additive highlight
	M.mist = {}
	for i = 1, 4 do M.mist[i] = Material("advancedblood/sprites/mist" .. i) end
	-- rivulets: flowing (colour), trails and soaked streaks (filter), their reflection (gloss)
	M.film = Material("advancedblood/sprites/film")
	M.filmFilter = Unlit("abl_filmfilter", "advancedblood/sprites/filmfilter")
	M.filmGloss = Unlit("abl_filmgloss", "advancedblood/sprites/filmgloss", "additive")
	-- the same reflection for static body meshes: its strength is set per draw through $color
	M.bodyGloss = Unlit("abl_bodygloss", "advancedblood/sprites/filmgloss", "additive")
	-- ground impact stains: the filter atlas, and the gloss atlas (same layout) for the reflection,
	-- its unevenness from the sheen pattern as a detail texture. One stain sees less than one band
	-- of the pattern (the atlas has 8 cells across: at eight periods across the atlas a stain was
	-- striped like a sweet)
	M.groundFilter = Unlit("abl_groundfilter", "advancedblood/ground/stainfilter")
	M.groundGloss = Unlit("abl_groundgloss", "advancedblood/ground/stainatlas", "additive", {
		["$detail"] = "advancedblood/sprites/sheen", ["$detailscale"] = 1, ["$detailblendmode"] = 0,
	})
	-- drop outlines (gloss atlas: luminance + coverage) for the liquid beads on bodies
	M.ground = Unlit("abl_ground", "advancedblood/ground/stainatlas")
	M.white = Material("vgui/white")
	-- all wet overlays share one atlas (fresh colour) so they can be batched into a few static meshes;
	-- their reflection uses the gloss version of the same cells
	M.atlas = Unlit("abl_stainatlas", "advancedblood/sprites/stainatlas")
	M.atlasGloss = Unlit("abl_stainatlasgloss", "advancedblood/sprites/stainglossatlas", "additive", {
		["$detail"] = "advancedblood/sprites/sheen", ["$detailscale"] = 0.5, ["$detailblendmode"] = 0,
	})
end
Load()

function M.Mist() return M.mist[math.random(1, #M.mist)] end

-- Atlas cells (4x4, 512 px each with a 12 px margin); order matches tools/texgen/texgen.cs.
local ATLAS_ORDER = { "drop1", "drop2", "drop3", "drop4", "splat1", "splat2", "splat3", "splat4",
	"elong1", "elong2", "elong3", "elong4", "soak1", "soak2", "soak3", "smear1" }
M.atlasCells = {}
for i, name in ipairs(ATLAS_ORDER) do
	local cx, cy = (i - 1) % 4, math.floor((i - 1) / 4)
	local m = 12 / 2048
	M.atlasCells[name] = { cx * 0.25 + m, cy * 0.25 + m, (cx + 1) * 0.25 - m, (cy + 1) * 0.25 - m }
end
-- families without their own cell reuse a similar shape (overlays are soft wet sheens)
function M.AtlasCell(fam, idx)
	return M.atlasCells[fam .. idx] or M.atlasCells[fam .. "1"] or M.atlasCells.drop1
end

M.ROT_STEPS = 16

-- Engine decal material for `fam` variant `idx`, rotated by `step` (0..ROT_STEPS-1) in texture space.
function M.Decal(fam, idx, step)
	if not step or step == 0 then return M.decal[fam][idx] end
	local key = fam .. ":" .. idx .. ":" .. step
	local mat = M.rotated[key]
	if mat then return mat end
	local deg = step * 360 / M.ROT_STEPS
	local path = "advancedblood/decals/" .. fam .. idx
	mat = CreateMaterial("abl_rot_" .. fam .. idx .. "_" .. step, "LightmappedGeneric", {
		["$basetexture"] = path,
		["$decal"] = 1,
		["$decalscale"] = 1 / M.texSize[fam],
		["$translucent"] = 1,
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$basetexturetransform"] = string.format("center .5 .5 scale 1 1 rotate %.3f translate 0 0", deg),
		["$modelmaterial"] = path .. "_model",
	})
	M.rotated[key] = mat
	return mat
end

-- Making one of these while the game runs holds the frame it is made in: about 15 ms each (the
-- material system waits for the renderer), once for every rotation of every stain texture that
-- is used for the first time. That was a stutter all through the first fight of a session, and
-- the governor took the lost time for the cost of the blood and cut its detail for a while
-- (measured, phase 28). They are all made here instead, once, while the map loads.
do
	local t0 = SysTime()
	local n = 0
	for fam, cnt in pairs(families) do
		for i = 1, cnt do
			for step = 1, M.ROT_STEPS - 1 do
				M.Decal(fam, i, step)
				n = n + 1
			end
		end
	end
	ABL.Print("decal materials: %d rotations made in %.0f ms", n, (SysTime() - t0) * 1000)
end

function M.Random(fam, rng)
	local n = families[fam] or 1
	if rng then return math.min(n, 1 + math.floor(rng:Next() * n)) end
	return math.random(1, n)
end
