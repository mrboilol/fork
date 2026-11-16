hg = hg or {}
hg.Medicine = hg.Medicine or {}

local Medicine = hg.Medicine

Medicine.WRAP_KEYS = {head = "skull", torso = "chest"}
Medicine.DEFAULT_COST = 0.25

Medicine.Items = {
	weapon_bruicekit = {
		heals = {"brute", "burn", "muscle"},
		amount = {brute = 25, burn = 20, muscle = 0.35},
		minDamage = {brute = 1, burn = 1, muscle = 0.03},
		mode = "instant",
		target = "aimed",
		cost = 0.25,
	},
	weapon_bandage_sh = {
		heals = {"burn"},
		amount = {burn = 10},
		minDamage = {burn = 1},
		mode = "instant",
		target = "aimed",
		cost = 0,
	},
}

function Medicine.Get(id)
	return Medicine.Items[id]
end

function Medicine.RegisterWeapons()
	for id, entry in pairs(Medicine.Items) do
		if entry.swep and not weapons.GetStored(id) then
			local SWEP = table.Copy(entry.swep)
			SWEP.Base = SWEP.Base or "weapon_bandage_sh"
			SWEP.MedicineId = id
			SWEP.Spawnable = SWEP.Spawnable ~= false
			SWEP.Category = SWEP.Category or "ZCity Medicine"
			SWEP.ShouldDeleteOnFullUse = SWEP.ShouldDeleteOnFullUse ~= false

			if SERVER then
				function SWEP:Heal(ent, mode, bone)
					return Medicine.SwepHeal(self, ent, mode, bone)
				end

				function SWEP:CanHeal(ent)
					return Medicine.SwepCanHeal(self, ent)
				end
			end

			weapons.Register(SWEP, id)
		end
	end
end

Medicine.RegisterWeapons()
