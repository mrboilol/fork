include("shared.lua")
ENT.HowToUseInstructions = "<font=ZCity_Tiny>"..string.upper( (input.LookupBinding("+use") or "BIND YOUR +USE KEY PLEASE. WRITE \"bind e +use\" IN CONSOLE FOR THE LOVE OF GOD") ).." to wear</font>"

function ENT:UpdateArmorHudHint()
	local damaged = self:GetNWBool("ArmorBroken", false)
	local unusable = self:GetNWBool("ArmorUnusable", false)
	if self.HudHintMarkup and self.HudHintDamaged == damaged and self.HudHintUnusable == unusable then return end

	self.HudHintDamaged = damaged
	self.HudHintUnusable = unusable
	local name = self.ArmorPrintName or self.PrintName
	if unusable then
		name = name .. " [Ruined]"
	elseif damaged then
		name = name .. " [Damaged]"
	end
	self.PrintName = name
	local instructions = unusable and "<font=ZCity_Tiny>TOO DAMAGED TO WEAR</font>" or self.HowToUseInstructions
	self.HudHintMarkup = markup.Parse("<font=ZCity_Tiny>".. name .."</font>\n<font=ZCity_SuperTiny><colour=125,125,125>".. instructions .."</colour></font>",450)
end

function ENT:Draw()
	local unusable = self:GetNWBool("ArmorUnusable", false)
	local model = self.PhysModel and self.model or self
	if unusable and IsValid(model) and not model.HGArmorUnusableMaterial then
		model.HGArmorUnusableMaterial = true
		model:SetMaterial("models/props_c17/fence01a")
		model:SetColor(Color(75, 55, 40))
	end

	if not self.PhysModel then
		self:DrawModel()
		return
	end

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
