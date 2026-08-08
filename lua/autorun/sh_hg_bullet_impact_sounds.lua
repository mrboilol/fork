AddCSLuaFile()

HG_BulletImpactSounds = HG_BulletImpactSounds or {}

local impactSounds = HG_BulletImpactSounds
local math_random = math.random

local function addNumberedSounds(sounds, folder, count, prefix)
	for index = 1, count do
		sounds[#sounds + 1] = folder .. (prefix or "") .. index .. ".wav"
	end
end

local fleshSounds = {
	"bullet/ric_flesh1.ogg",
	"bullet/ric_flesh2.ogg",
	"bullet/ric_flesh3.ogg",
	"bullet/ric_flesh4.ogg",
	"panoptisscon/blt_flesh1 - Copy.ogg",
	"panoptisscon/blt_flesh2 - Copy.ogg",
	"panoptisscon/blt_flesh3 - Copy.ogg",
	"panoptisscon/bullethit1 - Copy.ogg",
	"panoptisscon/bullethit2 - Copy.ogg",
	"panoptisscon/bullethit3 - Copy.ogg",
	"panoptisscon/bullethit4 - Copy.ogg",
}

local bfxFleshSounds = {}
addNumberedSounds(bfxFleshSounds, "bfx/flesh/", 10)

local stoneSounds = {
	"panoptisscon/rock1 - Copy.ogg",
	"panoptisscon/rock2 - Copy.ogg",
	"panoptisscon/rock3 - Copy.ogg",
	"panoptisscon/rock4 - Copy.ogg",
	"panoptisscon/rock5 - Copy.ogg",
	"bullet/ric_stone1.ogg",
	"bullet/ric_stone2.ogg",
	"bullet/ric_stone3.ogg",
}

local metalSounds = {
	"bullet/ric_metal1.ogg",
	"bullet/ric_metal2.ogg",
	"bullet/ric_metal3.ogg",
	"bullet/ric_metal4.ogg",
	"bullet/ric_metal5.ogg",
}

local bfxMetalSounds = {}
addNumberedSounds(bfxMetalSounds, "bfx/metal/", 29)

local woodSounds = {
	"bullet/ric_wood1.ogg",
	"bullet/ric_wood2.ogg",
	"bullet/ric_wood3.ogg",
	"bullet/ric_wood4.ogg",
}

local bfxWoodSounds = {}
addNumberedSounds(bfxWoodSounds, "bfx/wood/", 15)

local dirtSounds = {}
addNumberedSounds(dirtSounds, "bfx/dirt/", 16)

local genericSounds = {
	"bfx/Misc1.wav",
}
addNumberedSounds(genericSounds, "bfx/generic/", 29)

local glassSounds = {}
addNumberedSounds(glassSounds, "bfx/glass/", 21)

local plasticSounds = {}
addNumberedSounds(plasticSounds, "bfx/plastic/", 10)

local tileSounds = {}
addNumberedSounds(tileSounds, "bfx/tile/", 8)

local supersonicNearMissSounds = {}
local subsonicNearMissSounds = {}
addNumberedSounds(supersonicNearMissSounds, "bul_snap/supersonic_snap_", 18)
addNumberedSounds(subsonicNearMissSounds, "bul_flyby/subsonic_", 27)

local ricochetSounds = {
	"bullet/ricochet1.ogg",
	"bullet/ricochet2.ogg",
	"bullet/ricochet3.ogg",
	"bullet/ricochet4.ogg",
	"panoptisscon/ric1 - Copy.ogg",
	"panoptisscon/ric2 - Copy.ogg",
	"panoptisscon/ric3 - Copy.ogg",
	"panoptisscon/ric4 - Copy.ogg",
	"panoptisscon/ric5 - Copy.ogg",
}

local materialSounds = {
	[MAT_FLESH] = {sounds = fleshSounds, always = true},
	[MAT_ALIENFLESH] = {sounds = fleshSounds, always = true},
	[MAT_ANTLION] = {sounds = fleshSounds, always = true},
	[MAT_BLOODYFLESH] = {sounds = fleshSounds, always = true},

	[MAT_CONCRETE] = {sounds = stoneSounds, always = true},
	[MAT_TILE] = {sounds = stoneSounds, always = true},
	[MAT_SAND] = {sounds = stoneSounds, always = true},
	[MAT_DIRT] = {sounds = stoneSounds, always = true},
	[MAT_GRASS] = {sounds = stoneSounds, always = true},
	[MAT_SNOW] = {sounds = stoneSounds, always = true},
	[74] = {sounds = stoneSounds, always = true},
	[85] = {sounds = stoneSounds, always = true},

	[MAT_METAL] = {sounds = metalSounds},
	[MAT_COMPUTER] = {sounds = metalSounds},
	[MAT_VENT] = {sounds = metalSounds},
	[MAT_GRATE] = {sounds = metalSounds},
	[MAT_GLASS] = {sounds = metalSounds},
	[MAT_PLASTIC] = {sounds = metalSounds},

	[MAT_WOOD] = {sounds = woodSounds},
	[MAT_FOLIAGE] = {sounds = woodSounds},
}

local newMaterialSounds = {
	[MAT_FLESH] = bfxFleshSounds,
	[MAT_ALIENFLESH] = bfxFleshSounds,
	[MAT_ANTLION] = bfxFleshSounds,
	[MAT_BLOODYFLESH] = bfxFleshSounds,

	[MAT_CONCRETE] = genericSounds,
	[MAT_TILE] = tileSounds,
	[MAT_SAND] = dirtSounds,
	[MAT_DIRT] = dirtSounds,
	[MAT_GRASS] = dirtSounds,
	[MAT_SNOW] = dirtSounds,
	[74] = dirtSounds,
	[85] = dirtSounds,

	[MAT_METAL] = bfxMetalSounds,
	[MAT_COMPUTER] = bfxMetalSounds,
	[MAT_VENT] = bfxMetalSounds,
	[MAT_GRATE] = bfxMetalSounds,
	[MAT_GLASS] = glassSounds,
	[MAT_PLASTIC] = plasticSounds,

	[MAT_WOOD] = bfxWoodSounds,
	[MAT_FOLIAGE] = bfxWoodSounds,
}

function impactSounds.PlayMaterialImpact(trace)
	if not SERVER or not trace or trace.HitSky then return false end

	local selection = materialSounds[trace.MatType]
	if not selection then
		if math_random(4) ~= 1 then return false end
		sound.Play(genericSounds[math_random(#genericSounds)], trace.HitPos, 95, math_random(97, 103), 1.2)
		return true
	end
	if not selection.always and math_random(2) ~= 1 then return false end

	local choices = selection.sounds
	local newChoices = newMaterialSounds[trace.MatType]
	if newChoices and math_random(4) == 1 then choices = newChoices end
	sound.Play(choices[math_random(#choices)], trace.HitPos, 95, math_random(97, 103), 1.2)

	return true
end

function impactSounds.PlayRicochet(pos)
	if not SERVER or not pos or math_random(2) ~= 1 then return false end

	local choices = math_random(4) == 1 and genericSounds or ricochetSounds
	sound.Play(choices[math_random(#choices)], pos, 100, math_random(97, 103), 1.2)

	return true
end

function impactSounds.PlayNearMiss(pos, subsonic, soundLevel, volume, soundOverride)
	if not CLIENT or not pos then return false end

	local choices = subsonic and subsonicNearMissSounds or supersonicNearMissSounds
	local soundName = soundOverride or choices[math_random(#choices)]
	sound.Play(soundName, pos, soundLevel or 165, math_random(97, 103), volume or 1.25)

	return true
end

-- Impact_GMOD flag 8 keeps the stock material particles and decal, but omits
-- its stock sound so a selected custom impact can replace it cleanly.
function impactSounds.MakeEffectSilent(effectData)
	effectData:SetFlags(8)
end
