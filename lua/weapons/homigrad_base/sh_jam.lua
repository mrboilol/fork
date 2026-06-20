AddCSLuaFile()
--

SWEP.JamChanceBase = 0.003 -- 0.3% base chance per shot
SWEP.JamChanceLowCaliber = 0.004 -- +0.4% for pistol / low-caliber rounds
SWEP.JamChanceAutomatic = 0.006 -- +0.6% for automatic fire
SWEP.JamChanceMin = 0.001
SWEP.JamChanceMax = 0.05

SWEP.JamClearBaseTime = 2.5
SWEP.JamClearMaxTime = 5.0
SWEP.JamClearInspectLoop = 2.0

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

	local hg_jam = GetConVar("hg_jam")
	if hg_jam and hg_jam:GetBool() then
		hg_jam:SetInt(0)
		self:SetJammed(true)

		local owner = self:GetOwner()
		if IsValid(owner) and owner:IsPlayer() and owner.Notify then
			owner:Notify("The weapon has jammed!", 5, "jam", 0)
		end
		return
	end

	local chance = self:CalculateJamChance()
	if math.random() < chance then
		self:SetJammed(true)

		local owner = self:GetOwner()
		if IsValid(owner) and owner:IsPlayer() and owner.Notify then
			owner:Notify("The weapon has jammed!", 5, "jam", 0)
		end
	end
end

function SWEP:IsManualAction()
	return self.Primary and self.Primary.Automatic == false and self.AutomaticDraw == false
end

function SWEP:GetJamClearTime()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner.organism then return self.JamClearBaseTime end

	local org = owner.organism
	local fear = math.Clamp(org.fear or 0, 0, 2)
	local adrenaline = math.Clamp(org.adrenaline or 0, 0, 2)
	local stress = fear + adrenaline

	local base = self.JamClearBaseTime or 2.5
	local maxTime = self.JamClearMaxTime or 5.0
	local factor = math.min(stress / 4, 1)

	return math.min(base + factor * (maxTime - base), maxTime)
end

function SWEP:GetJamClearEnd()
	return self:GetNWFloat("JamClearEnd", 0)
end

function SWEP:GetJamClearStart()
	return self:GetNWFloat("JamClearStart", 0)
end

function SWEP:IsJamClearing()
	return self:GetJamClearEnd() > CurTime()
end

function SWEP:StartJamClear()
	if not self:GetJammed() then return false end
	if self:IsJamClearing() then return false end
	if not self:CanUse() then return false end

	local owner = self:GetOwner()
	if not IsValid(owner) then return false end

	local clearTime = self:GetJamClearTime()
	local endTime = CurTime() + clearTime

	self:SetNWFloat("JamClearEnd", endTime)
	self:SetNWFloat("JamClearStart", CurTime())
	self.jamclear_start = CurTime()
	self.inspect = math.huge

	owner:EmitSound("weapons/zmirli/shared/foley_light" .. math.random(1, 4) .. ".wav", 45, math.random(95, 105))

	return true
end

function SWEP:FinishJamClear()
	self:SetNWFloat("JamClearEnd", 0)
	self:SetNWFloat("JamClearStart", 0)
	self.jamclear_start = nil
	self.inspect = nil

	if not self:GetJammed() then return false end

	self:SetJammed(false)

	local owner = self:GetOwner()
	if not IsValid(owner) then return true end

	owner:EmitSound("weapons/zmirli/shared/foley_light" .. math.random(1, 4) .. ".wav", 45, math.random(95, 105))
	owner:ViewPunch(AngleRand(-2, 2))

	self:RejectShell(self.ShellEject)

	if self:IsManualAction() then
		local cycleAnim = self.AnimList and self.AnimList["cycle"]
		if cycleAnim then
			self:PlayAnim("cycle", 0.6, false, function()
				self:PlayAnim("idle", 1, not self.NoIdleLoop)
			end)
		end

		local cockSound = self.CockSound or self.ReloadSound
		if cockSound then
			owner:EmitSound(cockSound, 60, math.random(95, 105))
		end
	end

	return true
end

function SWEP:CancelJamClear()
	self:SetNWFloat("JamClearEnd", 0)
	self:SetNWFloat("JamClearStart", 0)
	self.jamclear_start = nil
	self.inspect = nil
end

function SWEP:ClearJam()
	if not self:GetJammed() then return false end

	if self:IsJamClearing() then
		self:CancelJamClear()
	end

	self:SetJammed(false)

	local owner = self:GetOwner()
	if IsValid(owner) then
		owner:EmitSound("weapons/zmirli/shared/foley_light" .. math.random(1, 4) .. ".wav", 45, math.random(95, 105))
	end

	return true
end

function SWEP:Step_JamClear(time)
	if CLIENT then return end
	if not self:IsJamClearing() then return end

	local endTime = self:GetJamClearEnd()
	if endTime <= time then
		self:FinishJamClear()
	end
end

if SERVER then
	local hg_jam = ConVarExists("hg_jam") and GetConVar("hg_jam") or CreateConVar("hg_jam", "0", {FCVAR_REPLICATED, FCVAR_CHEAT}, "If set to 1, the next fired round will always jam and then reset to 0.")

	util.AddNetworkString("hg_clear_jam")

	net.Receive("hg_clear_jam", function(len, ply)
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or not ishgweapon(wep) then return end
		if not wep:GetJammed() then return end
		if not wep:CanUse() then return end

		wep:StartJamClear()
	end)
end
