AddCSLuaFile()
--

SWEP.JamChanceBase = 0.003 -- 0.3% base chance per shot
SWEP.JamChanceLowCaliber = 0.004 -- +0.4% for pistol / low-caliber rounds
SWEP.JamChanceAutomatic = 0.006 -- +0.6% for automatic fire
SWEP.JamChanceMin = 0.001
SWEP.JamChanceMax = 0.05

SWEP.LowCaliberAmmo = {
	["9x19 mm Parabellum"] = true,
	[".45 ACP"] = true,
	[".50 Action Express"] = true,
	["18x45mm Traumatic"] = true,
	["9mm PAK Blank"] = true,
	[".22 Long Rifle"] = true,
	["5.56x45 mm"] = true,
	["5.45x39 mm"] = true,
	["7.62x39 mm"] = true,
}

function SWEP:GetJammed()
	return self:GetNWBool("Jammed", false)
end

function SWEP:SetJammed(jammed)
	self:SetNWBool("Jammed", tobool(jammed))
end

function SWEP:CalculateJamChance()
	local chance = self.JamChanceBase or 0.003

	local ammo = self.Primary.Ammo
	if ammo and self.LowCaliberAmmo and self.LowCaliberAmmo[ammo] then
		chance = chance + (self.JamChanceLowCaliber or 0.004)
	end

	if self.Primary.Automatic then
		chance = chance + (self.JamChanceAutomatic or 0.006)
	end

	return math.Clamp(chance, self.JamChanceMin or 0.001, self.JamChanceMax or 0.05)
end

function SWEP:TryJam()
	if self:GetJammed() then return end

	local chance = self:CalculateJamChance()
	if math.random() < chance then
		self:SetJammed(true)

		local owner = self:GetOwner()
		if IsValid(owner) and owner:IsPlayer() and owner.Notify then
			owner:Notify("The weapon has jammed!", 5, "jam", 0)
		end
	end
end

function SWEP:ClearJam()
	if not self:GetJammed() then return false end

	self:SetJammed(false)

	local owner = self:GetOwner()
	if IsValid(owner) then
		owner:EmitSound("weapons/zmirli/shared/foley_light" .. math.random(1, 4) .. ".wav", 45, math.random(95, 105))
	end

	return true
end

if SERVER then
	util.AddNetworkString("hg_clear_jam")

	net.Receive("hg_clear_jam", function(len, ply)
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or not ishgweapon(wep) then return end
		if not wep:GetJammed() then return end
		if not wep:CanUse() then return end

		wep:ClearJam()
	end)
end
