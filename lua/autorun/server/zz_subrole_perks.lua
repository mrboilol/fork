-- Shared subrole perks. Admin-assigned subroles use this too, so sandbox and
-- round modes do not need separate balance implementations.
hg = hg or {}

hg.SubRolePerks = {
	traitor_assasin = {RecoilMul = 0.70, DeployMul = 0.85, MeleeDamageMul = 1.15, CanDisarm = true},
	traitor_assasin_soe = {RecoilMul = 0.70, DeployMul = 0.85, MeleeDamageMul = 1.15, CanDisarm = true},
	traitor_defoko = {RecoilMul = 0.88, DeployMul = 1.08},
	defoko = {RecoilMul = 0.88, DeployMul = 1.08},
	traitor_chemist = {O2RegenMul = 1.35},
	traitor_infiltrator = {DeployMul = 0.65, PainMul = 0.88, ShockMul = 0.88, CanBreakNeck = true},
	traitor_infiltrator_soe = {DeployMul = 0.65, PainMul = 0.88, ShockMul = 0.88, CanBreakNeck = true},
	traitor_martial_artist = {MeleeDamageMul = 1.35, PainMul = 0.78, ShockMul = 0.78, CanDisarm = true, CanBreakNeck = true},
}

function hg.GetSubRolePerk(ply, key, default)
	local perks = IsValid(ply) and hg.SubRolePerks[ply.SubRole or ""]
	local value = perks and perks[key]
	return value == nil and default or value
end

hook.Add("Org Think", "HG_SubRoleChemistResistance", function(ply, org, timeValue)
	if not IsValid(ply) or ply.SubRole ~= "traitor_chemist" then return end
	org.o2.regen = math.max(org.o2.regen or 0, 1)
	org.CO = math.max((org.CO or 0) - timeValue * 0.45, 0)
	org.fireCOExposure = math.max((org.fireCOExposure or 0) - timeValue * 0.8, 0)
end)

hook.Add("ZC_BodyTemperature", "HG_SubRoleChemistTemperatureResistance", function(ply, org, timeValue, changeRate, maxWarmMul, warmLoseMul)
	if IsValid(ply) and ply.SubRole == "traitor_chemist" then
		return changeRate * 0.45, maxWarmMul, warmLoseMul
	end
end)

local function canDisarm(ply)
	return hg.GetSubRolePerk(ply, "CanDisarm", false) and ply:Alive() and ply.organism and not ply.organism.otrub
end

hook.Add("PlayerPostThink", "HG_SubRoleSandboxNeckBreak", function(ply)
	if engine.ActiveGamemode() ~= "sandbox" or not hg.GetSubRolePerk(ply, "CanBreakNeck", false) then return end
	if not ply:Alive() or not ply.organism or ply.organism.otrub or not ply:KeyDown(IN_WALK) or not ply:KeyPressed(IN_USE) then return end

	local tr = hg.eyeTrace(ply, 85)
	local victim = IsValid(tr.Entity) and (hg.RagdollOwner(tr.Entity) or tr.Entity) or nil
	if not IsValid(victim) or not victim:IsPlayer() or not victim:Alive() or victim == ply then return end

	local behind = math.abs(math.AngleDifference(victim:EyeAngles().y, (ply:GetPos() - victim:GetPos()):Angle().y)) < 100
	if not behind then return end

	victim.organism.spine3 = 1
	victim:Kill()
end)

hook.Add("PlayerPostThink", "HG_SubRoleSandboxDisarm", function(ply)
	if not canDisarm(ply) or not ply:KeyDown(IN_WALK) then return end
	if not ply:KeyPressed(IN_USE) or (ply.NextSubRoleDisarm or 0) > CurTime() then return end

	local tr = hg.eyeTrace(ply, 90)
	local victim = IsValid(tr.Entity) and (hg.RagdollOwner(tr.Entity) or tr.Entity) or nil
	if not IsValid(victim) or not victim:IsPlayer() or victim == ply or not victim:Alive() then return end

	local weapon = victim:GetActiveWeapon()
	if not IsValid(weapon) or weapon.NoDrop then return end

	ply.NextSubRoleDisarm = CurTime() + 1
	victim:DropWeapon(weapon)
	ply:PickupWeapon(weapon, false)
	hg.LightStunPlayer(victim)
end)