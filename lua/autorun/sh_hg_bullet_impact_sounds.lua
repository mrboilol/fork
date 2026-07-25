AddCSLuaFile()

HG_BulletImpactSounds = HG_BulletImpactSounds or {}

local impactSounds = HG_BulletImpactSounds
local math_random = math.random

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

local woodSounds = {
	"bullet/ric_wood1.ogg",
	"bullet/ric_wood2.ogg",
	"bullet/ric_wood3.ogg",
	"bullet/ric_wood4.ogg",
}

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

function impactSounds.PlayMaterialImpact(trace)
	if not SERVER or not trace or trace.HitSky then return false end

	local selection = materialSounds[trace.MatType]
	if not selection then return false end
	if not selection.always and math_random(2) ~= 1 then return false end

	local choices = selection.sounds
	sound.Play(choices[math_random(#choices)], trace.HitPos, 75, math_random(90, 110))

	return true
end

function impactSounds.PlayRicochet(pos)
	if not SERVER or not pos or math_random(2) ~= 1 then return false end

	sound.Play(ricochetSounds[math_random(#ricochetSounds)], pos, 75, math_random(90, 110))

	return true
end

-- Impact_GMOD flag 8 keeps the stock material particles and decal, but omits
-- its stock sound so a selected custom impact can replace it cleanly.
function impactSounds.MakeEffectSilent(effectData)
	effectData:SetFlags(8)
end
