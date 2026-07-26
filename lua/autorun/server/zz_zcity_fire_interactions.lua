hg = hg or {}

local WOOD_PHYSICS_MATERIALS = {
	wood = true,
	wood_crate = true,
	wood_furniture = true,
	wood_solid = true
}

local WOOD_BREAK_MODEL_CANDIDATES = {
	"models/gibs/wood_gib01a.mdl",
	"models/gibs/wood_gib01b.mdl",
	"models/gibs/wood_gib01c.mdl",
	"models/gibs/wood_gib01d.mdl",
	"models/gibs/wood_gib01e.mdl"
}

local VALID_WOOD_BREAK_MODELS = {}
for _, model in ipairs(WOOD_BREAK_MODEL_CANDIDATES) do
	if util.IsValidModel(model) and util.IsValidProp(model) then
		VALID_WOOD_BREAK_MODELS[#VALID_WOOD_BREAK_MODELS + 1] = model
	end
end

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

hook.Add("EntityTakeDamage", "hg-FireBluntSmothering", function(ent, dmgInfo)
	if not IsValid(ent) or not ent.fires then return end
	if not dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH) then return end

	local amount = math.Clamp(dmgInfo:GetDamage() * 1.25, 3, 35)
	hg.SmotherEntityFire(ent, amount, dmgInfo:GetDamagePosition())
end)

hook.Add("PropBreak", "hg-WoodPropBreakModels", function(attacker, prop)
	if not IsValid(prop) or prop.hgFallbackBreakGib then return end
	-- Some watermelons report wood physics; never add artificial wood gibs.
	if string.find(string.lower(prop:GetModel() or ""), "watermelon", 1, true) then return end
	local class = prop:GetClass()
	if class ~= "prop_physics" and class ~= "prop_physics_multiplayer" then return end
	if not HasWoodMaterial(prop) or #VALID_WOOD_BREAK_MODELS == 0 then return end

	local center = prop:WorldSpaceCenter()
	local velocity = prop:GetVelocity()
	local radius = math.max(prop:GetModelRadius(), 10)
	local count = math.Clamp(math.floor(radius / 24), 2, 5)

	for i = 1, count do
		local gib = ents.Create("prop_physics")
		if not IsValid(gib) then continue end

		gib.hgFallbackBreakGib = true
		gib:SetModel(VALID_WOOD_BREAK_MODELS[math.random(#VALID_WOOD_BREAK_MODELS)])
		gib:SetPos(center + VectorRand(-math.min(radius * 0.25, 12), math.min(radius * 0.25, 12)))
		gib:SetAngles(AngleRand())
		gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		gib:Spawn()

		if IsValid(attacker) and attacker:IsPlayer() then
			gib:SetCreator(attacker)
		end

		local phys = gib:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetVelocity(velocity + VectorRand(-90, 90) + vector_up * math.Rand(20, 85))
			phys:AddAngleVelocity(VectorRand(-180, 180))
		end

		SafeRemoveEntityDelayed(gib, math.Rand(25, 40))
	end
end)
