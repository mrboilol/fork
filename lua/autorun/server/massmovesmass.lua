if not SERVER then return end

hg = hg or {}

local targetMassCvar = CreateConVar("hg_ragdoll_mass", "75", FCVAR_ARCHIVE + FCVAR_NOTIFY, "total kg of a humanoid ragdoll at model scale 1; scales with the cube of the player's model scale", 10, 1000)

local READY_RETRY_INTERVAL = 0.1
local MAX_READY_RETRIES = 10
local MIN_MASS = 0.1
local MAX_MASS = 50000
local MIN_SCALE = 0.1
local MAX_SCALE = 10

local idealTotal

local function getIdealTotal()
	if not idealTotal then
		idealTotal = 0
		for _, mass in pairs(hg.IdealMassPlayer or {}) do idealTotal = idealTotal + mass end
	end
	return idealTotal
end

function hg.RagdollTargetMass()
	return targetMassCvar:GetFloat()
end

function hg.RagdollTunedMass()
	return getIdealTotal()
end

function hg.RagdollMassScale(ragdoll, ply)
	local scale
	if IsValid(ply) then
		scale = ply:GetModelScale()
		if IsValid(ragdoll) then ragdoll.hgMassScale = scale end
	elseif IsValid(ragdoll) then
		scale = ragdoll.hgMassScale or ragdoll:GetModelScale()
	end
	return math.Clamp(isnumber(scale) and scale or 1, MIN_SCALE, MAX_SCALE)
end

function hg.RagdollBoneMass(boneName, ragdoll, ply)
	local base = hg.IdealMassPlayer and hg.IdealMassPlayer[boneName]
	local total = getIdealTotal()
	if not base or total <= 0 then return nil end

	local scale = hg.RagdollMassScale(ragdoll, ply)
	return math.Clamp(base / total * hg.RagdollTargetMass() * scale * scale * scale, MIN_MASS, MAX_MASS)
end

function hg.RagdollTotalMass(ragdoll)
	local total = 0
	if not IsValid(ragdoll) then return total end

	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		if IsValid(phys) then total = total + phys:GetMass() end
	end
	return total
end

local function applyRagdollMasses(ragdoll)
	if not IsValid(ragdoll) or ragdoll:GetClass() ~= "prop_ragdoll" then return false end

	local physicsCount = ragdoll:GetPhysicsObjectCount()
	if physicsCount < 1 then return false end

	for physBone = 0, physicsCount - 1 do
		if not IsValid(ragdoll:GetPhysicsObjectNum(physBone)) then return false end
	end

	for physBone = 0, physicsCount - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(physBone)
		local bone = ragdoll:TranslatePhysBoneToBone(physBone)
		local mass = bone and bone >= 0 and hg.RagdollBoneMass(ragdoll:GetBoneName(bone), ragdoll)
		if mass then
			phys:SetMass(mass)
			if ragdoll._OriginalMass and not ragdoll._MassModified then
				ragdoll._OriginalMass[physBone] = mass
			end
		end
	end

	return true
end

local function applyWhenReady(ragdoll, attemptsRemaining)
	if not IsValid(ragdoll) then return end
	if applyRagdollMasses(ragdoll) then return end
	if attemptsRemaining <= 0 then return end

	timer.Simple(READY_RETRY_INTERVAL, function()
		applyWhenReady(ragdoll, attemptsRemaining - 1)
	end)
end

hook.Add("OnEntityCreated", "RagdollMassOverhaul.ApplyMasses", function(ent)
	if ent:GetClass() ~= "prop_ragdoll" then return end
	timer.Simple(READY_RETRY_INTERVAL, function()
		applyWhenReady(ent, MAX_READY_RETRIES)
	end)
end)

hook.Add("InitPostEntity", "RagdollMassOverhaul.ApplyExistingMasses", function()
	for _, ragdoll in ipairs(ents.FindByClass("prop_ragdoll")) do
		applyWhenReady(ragdoll, MAX_READY_RETRIES)
	end
end)
