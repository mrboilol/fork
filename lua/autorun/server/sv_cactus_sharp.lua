local CACTUS_MIN_SPEED = 120
local CACTUS_STICK_SPEED = 320
local CACTUS_MAX_SPEED = 900
local CACTUS_MAX_LODGED = 8

local function isCactusModel(model)
	return isstring(model) and string.find(string.lower(model), "cactus", 1, true) ~= nil
end

local function cactusAttacker(cactus)
	local attacker = cactus:GetPhysicsAttacker(5)
	if IsValid(attacker) then return attacker end
	if IsValid(cactus.sharpness_Thrower) then return cactus.sharpness_Thrower end
	return game.GetWorld()
end

local function cactusTarget(hitEnt)
	local owner = hitEnt
	if hitEnt:IsRagdoll() and hg.RagdollOwner then
		local ragdollOwner = hg.RagdollOwner(hitEnt)
		if IsValid(ragdollOwner) then owner = ragdollOwner end
	end
	if not owner.organism then return end
	if owner:IsPlayer() and not owner:Alive() then return end
	return owner
end

local function sendLodged(org)
	net.Start("organism_send")
	net.WriteTable({LodgedEntities = org.LodgedEntities, owner = org.owner})
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.WriteBool(true)
	net.Broadcast()
end

local function lodgeCactus(cactus, org, body, hitPos, dir, cactusPos, cactusAng)
	local _, _, boneName = hg.organism.GetWoundAnchor(body, hitPos, (-dir):Angle())
	local bone = boneName and body:LookupBone(boneName)
	local physBone = bone and bone >= 0 and body:TranslateBoneToPhysBone(bone)
	if not physBone or physBone < 0 then return end
	local anchorBone = body:TranslatePhysBoneToBone(physBone)
	local matrix = anchorBone and anchorBone >= 0 and body:GetBoneMatrix(anchorBone)
	if not matrix then return end

	local lpos, lang = WorldToLocal(cactusPos + dir * 1.5, cactusAng, matrix:GetTranslation(), matrix:GetAngles())
	org.LodgedEntities = org.LodgedEntities or {}
	while #org.LodgedEntities >= CACTUS_MAX_LODGED do
		table.remove(org.LodgedEntities, 1)
	end
	org.LodgedEntities[#org.LodgedEntities + 1] = {
		PhysBoneID = physBone,
		BoneName = body:GetBoneName(anchorBone),
		OffsetPos = lpos,
		OffsetAng = lang,
		model = cactus:GetModel(),
		modelscale = cactus:GetModelScale(),
		DropModel = cactus:GetModel(),
		PrintName = "cactus",
		Superficial = true,
	}
	sendLodged(org)

	cactus.cactusLodged = true
	cactus:Remove()
	return true
end

local function prickWithCactus(cactus, hitEnt, hitPos, velocity, cactusPos, cactusAng)
	local target = cactusTarget(hitEnt)
	if not target then return end
	local org = target.organism

	local speed = velocity:Length()
	local frac = math.Clamp((speed - CACTUS_MIN_SPEED) / (CACTUS_MAX_SPEED - CACTUS_MIN_SPEED), 0, 1)
	local dir = velocity:GetNormalized()

	local dmg = DamageInfo()
	dmg:SetAttacker(cactusAttacker(cactus))
	dmg:SetInflictor(cactus)
	dmg:SetDamage(1 + frac * 2)
	dmg:SetDamageType(DMG_SLASH)
	dmg:SetDamagePosition(hitPos)
	dmg:SetDamageForce(dir * 50)
	target:TakeDamageInfo(dmg)
	if org.lastArmorSharpStopped or not IsValid(hitEnt) then return end

	local woundAng = (-dir):Angle()
	for _ = 1, math.random(2, 3 + math.floor(frac * 3)) do
		local localPos, localAng, boneName = hg.organism.GetWoundAnchor(hitEnt, hitPos + VectorRand() * 3, woundAng)
		if localPos then
			hg.organism.AddWoundManual(target, math.Rand(6, 12) * (0.6 + frac), localPos, localAng, boneName, CurTime())
		end
	end
	hitEnt:EmitSound("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", 65, math.random(110, 130))

	if speed >= CACTUS_STICK_SPEED and IsValid(cactus) and math.Rand(0, 1) < 0.35 + frac * 0.5 then
		lodgeCactus(cactus, org, hitEnt, hitPos, dir, cactusPos, cactusAng)
	end
end

local function onCactusCollide(cactus, data)
	local hitEnt = data.HitEntity
	if not IsValid(hitEnt) or hitEnt:IsWorld() then return end
	if cactus.cactusLodged or (cactus.cactusNextPrick or 0) > CurTime() then return end

	local velocity = data.OurOldVelocity
	if velocity:Length() < CACTUS_MIN_SPEED then return end
	cactus.cactusNextPrick = CurTime() + 0.25

	local hitPos, cactusPos, cactusAng = data.HitPos, cactus:GetPos(), cactus:GetAngles()
	timer.Simple(0, function()
		if not IsValid(cactus) or not IsValid(hitEnt) or cactus.cactusLodged then return end
		prickWithCactus(cactus, hitEnt, hitPos, velocity, cactusPos, cactusAng)
	end)
end

hook.Add("OnEntityCreated", "CactusSharp", function(ent)
	timer.Simple(0, function()
		if not IsValid(ent) or ent:IsPlayer() or ent:IsRagdoll() or ent:IsNPC() then return end
		if not isCactusModel(ent:GetModel()) or not IsValid(ent:GetPhysicsObject()) then return end
		ent:AddCallback("PhysicsCollide", onCactusCollide)
	end)
end)
