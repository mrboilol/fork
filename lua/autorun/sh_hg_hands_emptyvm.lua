AddCSLuaFile()

local function hasModel(ent)
	if not IsValid(ent) then return false end
	local model = ent:GetModel()

	return model ~= nil and model ~= ""
end

hook.Add("Initialize", "HGHandsEmptyViewModel", function()
	local stored = scripted_ents.GetStored("gmod_hands")
	local ENT = stored and stored.t
	if not ENT then return end

	local attach = ENT.AttachToViewmodel

	function ENT:AttachToViewmodel(vm)
		if hasModel(vm) then
			self:SetNoDraw(false)
			return attach(self, vm)
		end

		self:RemoveEffects(EF_BONEMERGE)
		self:SetParent(NULL)
		self:SetNoDraw(true)

		local owner = self:GetOwner()
		if IsValid(owner) then self:SetPos(owner:GetPos()) end
	end
end)
