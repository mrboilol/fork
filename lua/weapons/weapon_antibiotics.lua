if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_painkillers"
SWEP.PrintName = "Antibiotics"
SWEP.Instructions = "Broad spectrum antibiotics. Clears wound infections and sepsis, and protects against new infections for a while. Does not fix acidic blood. RMB to use on someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.HGMedicalMinigameType = "syringe"
SWEP.HGPillMinigame = true
SWEP.modeNames = {
	[1] = "antibiotics"
}

if SERVER then
	function SWEP:Heal(ent, mode)
		if ent:IsNPC() then
			self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
			self:NPCHeal(ent, 0.2, "snd_jack_hmcd_pillsuse.ogg")
		end

		local org = ent.organism
		if not org or not self.modeValues or not self.modeValues[1] then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and not GetConVar("hg_healanims"):GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))
			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		entOwner:EmitSound("snd_jack_hmcd_pillsuse.ogg", 60, math.random(95, 105))
		hg.organism.Infection.GiveAntibiotics(org)

		if self.modeValues[1] > 0 then
			self.modeValues[1] = 0
			owner:SelectWeapon("weapon_hands_sh")
			self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.ogg")
			self:Remove()
		end

		return true
	end
end
