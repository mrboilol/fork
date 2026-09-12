include("shared.lua")
ENT.HowToUseInstructions = "<font=ZCity_Tiny>"..string.upper( (input.LookupBinding("+use") or "BIND YOUR +USE KEY PLEASE. WRITE \"bind e +use\" IN CONSOLE FOR THE LOVE OF GOD") ).." to wear</font>"

function ENT:UpdateArmorHudHint()
	local damaged = self:GetNWBool("ArmorBroken", false)
	if self.HudHintMarkup and self.HudHintDamaged == damaged then return end

	self.HudHintDamaged = damaged
	local name = self.ArmorPrintName or self.PrintName
	if damaged then name = name .. " [Damaged]" end
	self.PrintName = name
	self.HudHintMarkup = markup.Parse("<font=ZCity_Tiny>".. name .."</font>\n<font=ZCity_SuperTiny><colour=125,125,125>".. self.HowToUseInstructions .."</colour></font>",450)
end

function ENT:Draw()
	if not self.PhysModel then
		self:DrawModel()
		return
	end

	local model = self.model
	local pos, ang = LocalToWorld(self.PhysPos, self.PhysAng, self:GetPos(), self:GetAngles())
	model:SetRenderOrigin(pos)
	model:SetRenderAngles(ang)
	model:DrawModel()
end

function ENT:Think()
	self:UpdateArmorHudHint()
end

function ENT:Initialize()
	self.ArmorPrintName = self.PrintName
	self:UpdateArmorHudHint()
	self.model = ClientsideModel(self.Model, RENDERGROUP_OPAQUE)
	if !IsValid(self.model) then return end
	self.model:SetNoDraw(true)
end

function ENT:OnRemove()
	if IsValid(self.model) then
		self.model:Remove()
		self.model = nil
	end
end

hook.Add("RagdollPerdiction","TransferMats",function(ragdoll, ply)
	local armors = ragdoll.PredictedArmor
	for k,v in pairs(armors) do
		ragdoll:SetNWString("ArmorMaterials" .. v, ply:GetNWString("ArmorMaterials" .. v))
		ragdoll:SetNWInt("ArmorSkins" .. v, ply:GetNWInt("ArmorSkins" .. v))
	end
end)
