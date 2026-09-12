local propClasses = {
	prop_physics = true,
	prop_physics_multiplayer = true,
	prop_physics_override = true,
	prop_physics_respawnable = true,
	func_physbox = true,
}

local meleeClasses = {
	weapon_hands_sh = true,
	weapon_hg_coolhands = true,
}

local function IsMeleeInflictor(inflictor)
	if not IsValid(inflictor) or not inflictor:IsWeapon() then return false end

	local class = inflictor:GetClass()
	if meleeClasses[class] or inflictor.ismelee or inflictor.ismelee2 or inflictor.Base == "weapon_melee" then return true end

	local stored = weapons.GetStored(class)
	return stored and (stored.ismelee or stored.ismelee2 or stored.Base == "weapon_melee") or false
end

hook.Add("EntityTakeDamage", "hg_MeleePropPhysicsDamage", function(ent, dmginfo)
	if not propClasses[ent:GetClass()] then return end
	if not IsMeleeInflictor(dmginfo:GetInflictor()) then return end

	dmginfo:SetDamageType(DMG_CRUSH)
	ent:TakePhysicsDamage(dmginfo)
end)
