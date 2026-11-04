local chanceCvar = CreateConVar("hg_artery_shrapnel_chance", "15", FCVAR_ARCHIVE, "Percent chance for grenade shrapnel to sever an artery.", 0, 100)

local shrapnelAmmo = "Metal Debris"

local groupArteries = {
	[HITGROUP_HEAD] = {"arteria", {"ValveBiped.Bip01_Neck1"}},
	[HITGROUP_LEFTARM] = {"larmartery", {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm"}},
	[HITGROUP_RIGHTARM] = {"rarmartery", {"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm"}},
	[HITGROUP_LEFTLEG] = {"llegartery", {"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf"}},
	[HITGROUP_RIGHTLEG] = {"rlegartery", {"ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf"}},
}

local function isShrapnel(dmgInfo)
	if not dmgInfo:IsBulletDamage() and not dmgInfo:IsDamageType(DMG_BUCKSHOT) then return false end

	local id = game.GetAmmoID(shrapnelAmmo)
	if id and id > 0 and dmgInfo:GetAmmoType() == id then return true end

	for _, ent in ipairs({dmgInfo:GetInflictor(), dmgInfo:GetAttacker()}) do
		if IsValid(ent) then
			local class = string.lower(ent:GetClass())
			if string.find(class, "grenade", 1, true) or string.find(class, "shrapnel", 1, true) or string.find(class, "frag", 1, true) then
				return true
			end
		end
	end

	return false
end

local function closestBone(ent, bones, pos)
	local best, bestDist
	for _, name in ipairs(bones) do
		local bone = ent:LookupBone(name)
		local bonePos = bone and ent:GetBonePosition(bone)
		if isvector(bonePos) then
			local dist = bonePos:DistToSqr(pos)
			if not bestDist or dist < bestDist then best, bestDist = name, dist end
		end
	end
	return best
end

hook.Add("HomigradDamage", "HG_ShrapnelArteries", function(ent, dmgInfo, hitgroup)
	if not IsValid(ent) or not dmgInfo or not isShrapnel(dmgInfo) then return end

	local ply = ent
	if ent:IsRagdoll() then
		local owner = hg.RagdollOwner(ent)
		if IsValid(owner) then ply = owner end
	end
	if not ply:IsPlayer() or not ply:Alive() or not ply.organism then return end

	local entry = groupArteries[hitgroup]
	if not entry then return end

	local org = ply.organism
	if (tonumber(org[entry[1]]) or 0) > 0 then return end

	local chance = chanceCvar:GetFloat()
	if chance <= 0 or math.Rand(0, 100) > chance then return end

	local character = hg.GetCurrentCharacter(ply)
	if not IsValid(character) then return end

	local pos = dmgInfo:GetDamagePosition()
	local boneName = closestBone(character, entry[2], pos)
	if not boneName then return end

	local dir = dmgInfo:GetDamageForce()
	if dir:LengthSqr() > 0.01 then dir:Normalize() else dir = Vector(0, 0, 1) end

	hg.organism.input_list[entry[1]](org, character:LookupBone(boneName), 5, dmgInfo, boneName, dir, pos)
end)
