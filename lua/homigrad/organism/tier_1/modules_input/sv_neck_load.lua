local BARE_MIN_ENERGY = 30
local BARE_MAX_ENERGY = 80
local BARE_MAX_CHANCE = 0.35
local HELMET_MIN_ENERGY = 22
local HELMET_MAX_ENERGY = 65
local HELMET_MAX_CHANCE = 0.85
local TRANSMITTED_NECK_SHARE = 0.35
local DEFLECTED_NECK_SHARE = 0.4
local NECK_INPUT_PER_LOAD = 0.036
local ROLL_COOLDOWN = 0.25
local NECK_BONE = "ValveBiped.Bip01_Neck1"

local function applyNeckLoad(org, attacker, energy, helmetScale, pos, dir)
	if not org.alive or org.godmode or org.superfighter then return end

	local now = CurTime()
	if (org.meleeNeckLoadUntil or 0) > now then return end

	local helmeted = helmetScale < 1
	local minEnergy = helmeted and HELMET_MIN_ENERGY or BARE_MIN_ENERGY
	if energy <= minEnergy then return end

	org.meleeNeckLoadUntil = now + ROLL_COOLDOWN

	local maxEnergy = helmeted and HELMET_MAX_ENERGY or BARE_MAX_ENERGY
	local maxChance = helmeted and HELMET_MAX_CHANCE or BARE_MAX_CHANCE
	local chance = math.Clamp((energy - minEnergy) / (maxEnergy - minEnergy), 0, 1) * maxChance
	if math.Rand(0, 1) >= chance then return end

	local transmitted = energy * helmetScale
	local deflected = energy - transmitted
	local load = transmitted * TRANSMITTED_NECK_SHARE + deflected * DEFLECTED_NECK_SHARE
	local source = IsValid(attacker) and attacker or game.GetWorld()

	local info = DamageInfo()
	info:SetAttacker(source)
	info:SetInflictor(source)
	info:SetDamage(load)
	info:SetDamageType(DMG_CLUB)
	info:SetDamagePosition(pos)
	info:SetDamageForce(dir * load)

	hg.organism.input_list.spine3(org, 0, load * NECK_INPUT_PER_LOAD, info)
end

function hg.organism.aaneckhurts(org, attacker, contact, fallbackEnergy, rawDamageType, pos, dir)
	if contact.boneName == NECK_BONE then return end

	local contactScale = contact.armorModelContact and math.Clamp(contact.equipmentScale or 1, 0.01, 1) or 1
	local helmetScale = math.min(contactScale, org.lastHeadArmorMitigation or 1, org.lastHelmetImpactScale or 1)
	if helmetScale >= 1 and bit.band(rawDamageType, DMG_CLUB) == 0 then return end

	applyNeckLoad(org, attacker, (contact.trauma or fallbackEnergy) / contactScale, helmetScale, pos, dir)
end

function hg.organism.ApplyBlockedHelmetNeckLoad(hit, damage, direction, inflictor)
	if hit.placement ~= "head" and hit.placement ~= ZC_ARMOR_SLOT_HEAD then return end
	if not IsValid(inflictor) then return end

	local wearer = hit.wearer or hit.body
	local org = IsValid(wearer) and wearer.organism or IsValid(hit.body) and hit.body.organism
	if not org then return end

	local swingMul = inflictor.GetSwingDamageMul and inflictor:GetSwingDamageMul() or 1
	applyNeckLoad(org, inflictor:GetOwner(), damage * swingMul, 0, hit.position, direction)
end
