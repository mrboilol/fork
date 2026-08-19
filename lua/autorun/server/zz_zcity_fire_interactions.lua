hg = hg or {}

local WOOD_PHYSICS_MATERIALS = {
	wood = true,
	wood_crate = true,
	wood_furniture = true,
	wood_solid = true
}

local function HasWoodMaterial(ent)
	if not IsValid(ent) then return false end
	if ent:GetMaterialType() == MAT_WOOD then return true end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return false end

	local material = string.lower(phys:GetMaterial() or "")
	return WOOD_PHYSICS_MATERIALS[material] or string.find(material, "wood", 1, true) ~= nil
end

local function IsWoodProp(ent)
	if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() or ent:IsRagdoll() then return false end
	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return false end
	return HasWoodMaterial(ent)
end

local function ExplodeOilContainer(ent, owner)
	local model = ent:GetModel()
	if not hg.gas_models or not hg.gas_models[model] then return false end
	if not hg.expItems or not hg.PropExplosion then return false end

	local explosion = hg.expItems[model]
	if not explosion then return false end

	local drum = hg.drums and hg.drums[ent:EntIndex()]
	if drum and (drum.Volume or 0) <= 0.5 then return true end
	if ent.HasExploded or ent.babahnut then return true end

	local phys = ent:GetPhysicsObject()
	local mass = IsValid(phys) and phys:GetMass() or 10
	local fuel = drum and drum.Volume or ent.Volume or explosion.Force

	ent.owner = IsValid(owner) and owner or ent
	ent.babahnut = true
	hg.PropExplosion(ent, explosion.ExpType, math.max(fuel or explosion.Force, 1) * 2, mass, explosion)
	return true
end

local ContainerBlazeLife = 60
local ContainerBlazeDuration = 30
local ContainerBlazeCount = 7

local function CreateOilContainerBlaze(ent, owner)
	local center = ent:WorldSpaceCenter()
	local world = game.GetWorld()

	for fire in pairs(ent.fires or {}) do
		if IsValid(fire) then
			fire.feed = math.max(fire.feed or 0, 180)
			fire:ChangeLife(math.max(fire.life or 0, ContainerBlazeLife))
			fire:Prioritize(ContainerBlazeDuration, true)
		end
	end

	for i = 1, ContainerBlazeCount do
		local offset = VectorRand(-140, 140)
		offset.z = 0
		local tr = util.QuickTrace(center + offset + vector_up * 96, -vector_up * 384, ent)
		if not tr.Hit then continue end

		local fire = CreateVFire(world, tr.HitPos, tr.HitNormal, 130, IsValid(owner) and owner or ent)
		if IsValid(fire) then
			fire:ChangeLife(ContainerBlazeLife)
			fire:Prioritize(ContainerBlazeDuration, true)
		end
	end
end

local function CreateWoodFire(ent, hitPos, hitNormal, owner, feed, startingLife, allowFallback)
	if not CreateVFire then
		if allowFallback then ent:Ignite(30) end
		return allowFallback
	end

	local pos = isvector(hitPos) and hitPos or ent:WorldSpaceCenter()
	local normal = isvector(hitNormal) and hitNormal or vector_up
	local fire = CreateVFire(ent, pos, normal, feed, IsValid(owner) and owner or nil)

	if IsValid(fire) then
		fire:SetOwner(IsValid(owner) and owner or ent)
		fire:ChangeLife(startingLife)
		return true
	end

	if allowFallback then
		ent:Ignite(30)
		return true
	end

	return false
end

function hg.TrySmallFlameIgnite(ent, hitPos, hitNormal, owner, flameType, source)
	if not IsValid(ent) then return false end
	if ExplodeOilContainer(ent, owner) then return true end
	if not IsWoodProp(ent) then return false end
	if ent:IsOnFire() then return true end

	if flameType == "match" then
		if IsValid(source) and source.hgWoodIgnitionTried then return true end
		if IsValid(source) then source.hgWoodIgnitionTried = true end

		local roll = math.Rand(0, 1)
		if roll < 0.3 then return true end

		if roll < 0.75 then
			local localPos = ent:WorldToLocal(isvector(hitPos) and hitPos or ent:WorldSpaceCenter())
			local localNormal = ent:WorldToLocal((isvector(hitPos) and hitPos or ent:WorldSpaceCenter()) + (isvector(hitNormal) and hitNormal or vector_up)) - localPos
			timer.Simple(math.Rand(1.25, 3.5), function()
				if not IsValid(ent) or ent:IsOnFire() then return end
				local worldPos = ent:LocalToWorld(localPos)
				local worldNormal = ent:LocalToWorld(localPos + localNormal) - worldPos
				CreateWoodFire(ent, worldPos, worldNormal, owner, 1.5, 1, false)
			end)
			return true
		end

		return CreateWoodFire(ent, hitPos, hitNormal, owner, 7, 2, false)
	end

	return CreateWoodFire(ent, hitPos, hitNormal, owner, 18, 7, true)
end

function hg.SmotherEntityFire(ent, amount, hitPos)
	if not IsValid(ent) or not istable(ent.fires) then return false end

	local nearest
	local nearestDistance = math.huge
	local pos = isvector(hitPos) and hitPos or ent:WorldSpaceCenter()

	for fire in pairs(ent.fires) do
		if not IsValid(fire) then
			ent.fires[fire] = nil
			continue
		end

		local distance = fire:GetPos():DistToSqr(pos)
		if distance < nearestDistance then
			nearest = fire
			nearestDistance = distance
		end
	end

	if not IsValid(nearest) then return false end
	nearest:SoftExtinguish(math.max(tonumber(amount) or 0, 0))
	return true
end

local function AddImpactSmothering(ent)
	if not IsValid(ent) or ent.hgFireImpactCallback then return end
	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return end

	ent.hgFireImpactCallback = ent:AddCallback("PhysicsCollide", function(burningEnt, data)
		if not burningEnt.fires or not data or (data.Speed or 0) < 90 then return end
		if (burningEnt.hgNextFireImpactSmother or 0) > CurTime() then return end

		burningEnt.hgNextFireImpactSmother = CurTime() + 0.2
		local amount = math.Clamp(((data.Speed or 0) - 80) * 0.08, 2, 35)
		hg.SmotherEntityFire(burningEnt, amount, data.HitPos)
	end)
end

hook.Add("vFireEntityStartedBurning", "hg-FireImpactSmothering", AddImpactSmothering)

hook.Add("vFireEntityStartedBurning", "hg-FuelContainerIgnition", function(ent)
	if not IsValid(ent) or not hg.gas_models or not hg.gas_models[ent:GetModel()] then return end
	if ent.hgFuelFireReaction then return end
	ent.hgFuelFireReaction = true

	local owner = ent
	for fire in pairs(ent.fires or {}) do
		if IsValid(fire) and IsValid(fire:GetOwner()) then
			owner = fire:GetOwner()
			break
		end
	end

	if math.Rand(0, 1) < 0.6 then
		ExplodeOilContainer(ent, owner)
	else
		CreateOilContainerBlaze(ent, owner)
	end
end)

hook.Add("EntityTakeDamage", "hg-FireBluntSmothering", function(ent, dmgInfo)
	if not IsValid(ent) or not ent.fires then return end
	if not dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH) then return end

	local amount = math.Clamp(dmgInfo:GetDamage() * 1.25, 3, 35)
	hg.SmotherEntityFire(ent, amount, dmgInfo:GetDamagePosition())
end)

-- Source/propdata owns break gibs so each prop uses its model-defined debris.

