AddCSLuaFile()

if not CLIENT then return end

local math_random = math.random
local math_Clamp = math.Clamp
local string_find = string.find
local string_lower = string.lower

local function isHomigradGun(ent)
	return IsValid(ent) and ent:IsWeapon() and ent.ishgwep == true
end

local function isGunOrBulletSound(soundName)
	if not soundName then return false end

	soundName = string_lower(soundName)

	return string_find(soundName, "weapon", 1, true) ~= nil
		or string_find(soundName, "firearm", 1, true) ~= nil
		or string_find(soundName, "gunshot", 1, true) ~= nil
		or string_find(soundName, "gunfire", 1, true) ~= nil
		or string_find(soundName, "bullet", 1, true) ~= nil
		or string_find(soundName, "fx/", 1, true) ~= nil
		or string_find(soundName, "ricochet", 1, true) ~= nil
		or string_find(soundName, "cracks/", 1, true) ~= nil
		or string_find(soundName, "universal/", 1, true) ~= nil
		or string_find(soundName, "panoptisscon/ric", 1, true) ~= nil
		or string_find(soundName, "panoptisscon/rock", 1, true) ~= nil
end

hook.Add("EntityEmitSound", "HG_GunSoundPitchVariation", function(data)
	local ent = data.Entity
	local fromGun = isHomigradGun(ent)

	if not fromGun and IsValid(ent) and ent:IsPlayer()
		and (data.Channel == CHAN_WEAPON or data.Channel == CHAN_STATIC) then
		fromGun = isHomigradGun(ent:GetActiveWeapon())
	end

	if not fromGun
		and not isGunOrBulletSound(data.OriginalSoundName)
		and not isGunOrBulletSound(data.SoundName) then return end

	local offset = math_random(1, 3)
	if math_random(2) == 1 then offset = -offset end

	data.Pitch = math_Clamp((data.Pitch or 100) + offset, 1, 255)

	return true
end)
