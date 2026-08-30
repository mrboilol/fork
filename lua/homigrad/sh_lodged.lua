if SERVER then AddCSLuaFile() end

hg = hg or {}

local function lodgedBody(ent)
	if not IsValid(ent) then return end
	if hg.GetCurrentCharacter then
		local body = hg.GetCurrentCharacter(ent)
		if IsValid(body) then return body end
	end
	return IsValid(ent.FakeRagdoll) and ent.FakeRagdoll or ent
end

local function lodgedBoneName(entry, body)
	if isstring(entry.BoneName) and entry.BoneName ~= "" then return entry.BoneName end
	if not IsValid(body) then return "" end
	local bone = body:TranslatePhysBoneToBone(tonumber(entry.PhysBoneID) or 0)
	return bone and body:GetBoneName(bone) or ""
end

function hg.GetLodgedRegion(entry, body)
	if not istable(entry) then return "chest" end
	if isstring(entry.Region) and entry.Region ~= "" then return entry.Region end

	local bone = string.lower(lodgedBoneName(entry, body))
	local left = string.find(bone, "_l_", 1, true) ~= nil
	local right = string.find(bone, "_r_", 1, true) ~= nil

	if string.find(bone, "neck", 1, true) then return "neck" end
	if string.find(bone, "head", 1, true) then return "head" end
	if string.find(bone, "thigh", 1, true) or string.find(bone, "calf", 1, true)
		or string.find(bone, "foot", 1, true) or string.find(bone, "toe", 1, true) then
		return left and "lleg" or right and "rleg" or "leg"
	end
	if string.find(bone, "arm", 1, true) or string.find(bone, "hand", 1, true)
		or string.find(bone, "finger", 1, true) or string.find(bone, "clavicle", 1, true) then
		return left and "larm" or right and "rarm" or "arm"
	end
	return "chest"
end

function hg.GetLodgedLimbPenalty(ent, limb)
	if not IsValid(ent) then return 1 end
	local org = ent.organism
	if not org and hg.RagdollOwner then
		local owner = hg.RagdollOwner(ent)
		org = IsValid(owner) and owner.organism or nil
	end
	if not org or not istable(org.LodgedEntities) then return 1 end

	local body = lodgedBody(IsValid(org.owner) and org.owner or ent)
	local count = 0
	for _, entry in ipairs(org.LodgedEntities) do
		local region = hg.GetLodgedRegion(entry, body)
		if region == limb or (limb == "lleg" or limb == "rleg") and region == "leg"
			or (limb == "larm" or limb == "rarm") and region == "arm" then
			count = count + 1
		end
	end

	local perObject = string.find(limb, "leg", 1, true) and 0.9 or 0.86
	return math.max(perObject ^ count, string.find(limb, "leg", 1, true) and 0.72 or 0.62)
end

function hg.BestLodgedToTake(ent)
	if not IsValid(ent) or not ent.organism or not istable(ent.organism.LodgedEntities) then return end

	local best
	for i, entry in pairs(ent.organism.LodgedEntities) do
		if isnumber(i) and istable(entry) and (not best or i > best) then
			best = i
		end
	end
	return best
end

hg.BestArrowToTake = hg.BestLodgedToTake

if CLIENT then
	hook.Add("radialOptions", "takeLodged", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() or not ply.organism or not ply.organism.canmove then return end

		local i = hg.BestLodgedToTake(ply)
		local entry = i and ply.organism.LodgedEntities[i]
		if not entry then return end

		local class = entry.takeent
		local weapon = isstring(class) and weapons.GetStored(class) or nil
		local name = entry.CrossbowBolt and "crossbow bolt"
			or weapon and weapon.PrintName
			or "embedded item"
		hg.radialOptions[#hg.radialOptions + 1] = {
			function()
				RunConsoleCommand("hg_take_lodged")
			end,
			"Take " .. name .. " from yourself"
		}
	end)

	return
end

local chestOrgansUpper = {"lungsL", "lungsR", "heart"}
local chestOrgansLower = {"liver", "stomach", "intestines"}
local brainLobes = {"brainFrontal", "brainParietal", "brainTemporal", "brainOccipital"}

local lodgedExtractionBleed = {
	limb = {min = 95, max = 145},
	vital = {min = 125, max = 175},
}

local function lodgedTransform(owner, entry)
	local body = lodgedBody(owner)
	if not IsValid(body) then return end

	local boneName = lodgedBoneName(entry, body)
	local bone = body:LookupBone(boneName)
	if not bone or bone < 0 then
		bone = body:TranslatePhysBoneToBone(tonumber(entry.PhysBoneID) or 0)
		boneName = bone and body:GetBoneName(bone) or boneName
	end
	if not bone or bone < 0 then return body, boneName, entry.OffsetPos or vector_origin, body:WorldSpaceCenter(), body:GetAngles() end

	local matrix = body:GetBoneMatrix(bone)
	if not matrix then return body, boneName, entry.OffsetPos or vector_origin, body:WorldSpaceCenter(), body:GetAngles() end
	local localPos = isvector(entry.OffsetPos) and entry.OffsetPos or vector_origin
	local localAng = isangle(entry.OffsetAng) and entry.OffsetAng or angle_zero
	local worldPos, worldAng = LocalToWorld(localPos, localAng, matrix:GetTranslation(), matrix:GetAngles())
	return body, boneName, localPos, worldPos, worldAng
end

local function addLodgedWound(owner, org, entry, severity, lasting)
	if not hg.organism or not hg.organism.AddWoundManual then return end
	local body, boneName, localPos, worldPos, worldAng = lodgedTransform(owner, entry)
	if not IsValid(body) then return end
	local wound = hg.organism.AddWoundManual(owner, severity, localPos, isangle(entry.OffsetAng) and entry.OffsetAng or angle_zero, boneName, CurTime() + (lasting or math.Rand(8, 20)))
	if wound and hg.organism.BloodDroplet2 then
		local direction = worldAng:Forward() * math.Rand(35, 80) + body:GetVelocity()
		hg.organism.BloodDroplet2(owner, org, wound, direction, false)
	end
	return body, worldPos, worldAng
end

local function showExtractionBlood(owner, entry)
	local body, _, _, pos, ang = lodgedTransform(owner, entry)
	if not IsValid(body) or not isvector(pos) then return end
	local effect = EffectData()
	effect:SetOrigin(pos)
	effect:SetNormal(ang:Forward())
	effect:SetMagnitude(2)
	effect:SetScale(1.4)
	effect:SetRadius(4)
	util.Effect("BloodImpact", effect, true, true)
	util.Decal("Blood", pos + ang:Forward() * 5, pos - ang:Forward() * 7, body)
end

local function addInternalBleed(org, amount)
	org.internalBleed = math.max((tonumber(org.internalBleed) or 0) + amount, 0)
end

local function damageNearbyChestOrgan(org, entry)
	local bone = string.lower(entry.BoneName or "")
	local upperChest = string.find(bone, "spine4", 1, true) ~= nil or string.find(bone, "spine2", 1, true) ~= nil
	local choices = upperChest and chestOrgansUpper or chestOrgansLower
	local organ = choices[math.random(#choices)]
	local amount = math.Rand(0.004, 0.012) / math.max(tonumber(org.organStrengthMul) or 1, 1)
	if organ == "lungsL" or organ == "lungsR" then
		org[organ] = org[organ] or {0, 0}
		org[organ][1] = math.min((org[organ][1] or 0) + amount, 1)
	else
		org[organ] = math.min((tonumber(org[organ]) or 0) + amount, 1)
	end
	addInternalBleed(org, math.Rand(0.025, 0.08))
	org.painadd = math.min((org.painadd or 0) + amount * 35, 150)
end

local function damageBrainLobe(org)
	local lobe = brainLobes[math.random(#brainLobes)]
	local amount = math.Rand(0.002, 0.006) / math.max(tonumber(org.organStrengthMul) or 1, 1)
	org[lobe] = math.min((tonumber(org[lobe]) or 0) + amount, 1)
	org.brain = math.min((tonumber(org.brain) or 0) + amount * 1.5, 1)
	org.disorientation = (org.disorientation or 0) + amount * 1.5
	org.painadd = math.min((org.painadd or 0) + amount * 12, 150)
end

local function cutCarotid(owner, org, pos, direction, extractor)
	if not hg.organism or not hg.organism.input_list or not hg.organism.input_list.arteria then return end
	local dmg = DamageInfo()
	local attacker = IsValid(extractor) and extractor or owner
	dmg:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
	dmg:SetInflictor(IsValid(attacker) and attacker or game.GetWorld())
	dmg:SetDamage(2)
	dmg:SetDamageType(DMG_SLASH)
	dmg:SetDamagePosition(pos)
	dmg:SetDamageForce(direction * 30)
	hg.organism.input_list.arteria(org, 0, 2, dmg, "ValveBiped.Bip01_Neck1", direction, pos)
end

function hg.ApplyLodgedExtraction(owner, extractor, entry)
	if not IsValid(owner) or not owner.organism or not istable(entry) then return end
	local org = owner.organism
	local body = lodgedBody(owner)
	local region = hg.GetLodgedRegion(entry, body)
	local vitalRegion = region == "head" or region == "neck" or region == "chest"
	local bleedRange = lodgedExtractionBleed[vitalRegion and "vital" or "limb"]
	local extractionBleed = math.Rand(bleedRange.min, bleedRange.max)
	local worldPos, worldAng
	body, worldPos, worldAng = addLodgedWound(owner, org, entry, extractionBleed, math.Rand(60, 120))
	showExtractionBlood(owner, entry)
	org.painadd = math.min((org.painadd or 0) + math.Rand(14, 22), 150)

	local direction = isangle(worldAng) and worldAng:Forward() or vector_up
	if region == "neck" and math.Rand(0, 1) < 0.04 then
		cutCarotid(owner, org, worldPos or owner:WorldSpaceCenter(), direction, extractor)
	elseif region == "head" then
		org.brain = math.min((tonumber(org.brain) or 0) + math.Rand(0.002, 0.006), 1)
		if math.Rand(0, 1) < 0.08 then damageBrainLobe(org) end
	elseif region == "chest" and math.Rand(0, 1) < 0.12 then
		addInternalBleed(org, math.Rand(0.04, 0.14))
	end
end

function hg.TakeLodged(ent, ply)
	if not IsValid(ent) or not ent.organism or not istable(ent.organism.LodgedEntities) then return false end
	if not IsValid(ply) or not ply:IsPlayer() or not ply.organism or not ply.organism.canmove then return false end

	local i = hg.BestLodgedToTake(ent)
	if not i then return false end

	local entry = table.remove(ent.organism.LodgedEntities, i)
	if not entry then return false end

	hg.ApplyLodgedExtraction(ent, ply, entry)

	if isstring(entry.takeent) and entry.takeent ~= "" then
		if ply:HasWeapon(entry.takeent) then
			local weapon = ents.Create(entry.takeent)
			if IsValid(weapon) then
				weapon:SetPos(ply:EyePos())
				weapon.IsSpawned = true
				weapon:Spawn()
			end
		else
			ply:Give(entry.takeent)
		end
	else
		local ammoType = entry.CrossbowBolt and "Armature" or "Arrow"
		ply:GiveAmmo(1, ammoType, true)
		if ammoType == "Arrow" then
			ply:EmitSound("weapons/bow_deerhunter/arrow_load_0" .. math.random(3) .. ".wav", 55)
		else
			ply:EmitSound("weapons/crossbow/reload1.wav", 55)
		end
	end

	net.Start("organism_send")
	net.WriteTable({LodgedEntities = ent.organism.LodgedEntities, owner = ent.organism.owner})
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.WriteBool(true)
	net.Broadcast()

	ent:EmitSound("arrow_tear.ogg")
	return true
end

concommand.Add("hg_take_lodged", function(ply)
	if IsValid(ply) and ply.organism and ply.organism.canmove then
		hg.TakeLodged(ply, ply)
	end
end)

hook.Add("Org Think", "LodgedObjectComplications", function(owner, org)
	if not IsValid(owner) or not istable(org.LodgedEntities) or #org.LodgedEntities == 0 then return end
	if owner:IsPlayer() and not owner:Alive() then return end
	local now = CurTime()
	if (org.nextLodgedObjectThink or 0) > now then return end
	org.nextLodgedObjectThink = now + 1

	local body = lodgedBody(owner)
	if not IsValid(body) then return end
	local speed = body:GetVelocity():Length()
	local moving = speed > 55
	local fast = speed > 165 or owner:IsPlayer() and owner:KeyDown(IN_SPEED) and speed > 90
	local armAction = owner:IsPlayer() and (owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2) or owner:KeyDown(IN_RELOAD))

	for _, entry in ipairs(org.LodgedEntities) do
		local region = hg.GetLodgedRegion(entry, body)
		entry.Region = region
		org.painadd = math.min((org.painadd or 0) + 0.015, 150)

		if (region == "lleg" or region == "rleg" or region == "leg") and moving then
			org.painadd = math.min((org.painadd or 0) + (fast and 0.12 or 0.045), 150)
			if fast and math.Rand(0, 1) < 0.008 then addLodgedWound(owner, org, entry, math.Rand(3, 6), math.Rand(6, 14)) end
		elseif (region == "larm" or region == "rarm" or region == "arm") and (armAction or fast) then
			org.painadd = math.min((org.painadd or 0) + (armAction and 0.1 or 0.035), 150)
			if armAction and math.Rand(0, 1) < 0.009 then addLodgedWound(owner, org, entry, math.Rand(3, 6), math.Rand(6, 14)) end
		elseif region == "chest" and fast then
			org.painadd = math.min((org.painadd or 0) + 0.1, 150)
			if math.Rand(0, 1) < 0.006 then addLodgedWound(owner, org, entry, math.Rand(3, 7), math.Rand(8, 18)) end
			if math.Rand(0, 1) < 0.004 then addInternalBleed(org, math.Rand(0.02, 0.07)) end
			if math.Rand(0, 1) < 0.0007 then damageNearbyChestOrgan(org, entry) end
		elseif region == "neck" and fast then
			org.painadd = math.min((org.painadd or 0) + 0.12, 150)
			if math.Rand(0, 1) < 0.004 then addLodgedWound(owner, org, entry, math.Rand(3, 7), math.Rand(8, 18)) end
			if math.Rand(0, 1) < 0.0005 then
				org.trachea = math.min((tonumber(org.trachea) or 0) + math.Rand(0.01, 0.035), 1)
			end
		elseif region == "head" then
			local activityMul = fast and 2 or 1
			local skullRiskMul = 1 + math.Clamp(tonumber(org.skull) or 0, 0, 1) * 1.8
			if math.Rand(0, 1) < 0.0008 * activityMul * skullRiskMul then
				if hg.organism.AddBrainHemorrhage then
					hg.organism.AddBrainHemorrhage(org, math.Rand(0.006, 0.018), math.Rand(0.00004, 0.00012))
				else
					org.brainHemorrhage = math.min((tonumber(org.brainHemorrhage) or 0) + math.Rand(0.006, 0.018), 1)
				end
			end
			if math.Rand(0, 1) < 0.00012 * activityMul then damageBrainLobe(org) end
		end

		if math.Rand(0, 1) < 0.0004 then addLodgedWound(owner, org, entry, math.Rand(2, 4), math.Rand(6, 12)) end
	end
end)
