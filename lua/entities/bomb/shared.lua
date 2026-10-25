ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Bomb"
ENT.Category = "ZCity Other"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Model = "models/jmod/explosives/bombs/c4/w_c4_planted.mdl"
ENT.IconOverride = "vgui/wep_jack_hmcd_c4_charge"
ENT.ExplodeTime = 90
ENT.Editable = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Power", {KeyName = "power", Edit = {type = "Int", order = 1, min = 1, max = #hg.BombPower, title = "Blast power"}})

	if SERVER then
		self:SetPower(hg.BombPowerDefault)
	end
end