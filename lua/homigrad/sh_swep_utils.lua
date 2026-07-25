hg.swep = hg.swep or {}

function hg.swep.SetHold(self, value)
	self:SetWeaponHoldType(value)
	self:SetHoldType(value)
	self.holdtype = value
end

function hg.swep.GetEyeTrace(self)
	return hg.eyeTrace(self:GetOwner())
end

if CLIENT then
	function hg.swep.DrawBoneAttachedModel(self, opts)
		opts = opts or {}
		local modelKey = opts.modelKey or self.WorldModel
		self.model = IsValid(self.model) and self.model or ClientsideModel(modelKey)
		local WorldModel = self.model
		if not IsValid(WorldModel) then return end

		local owner = self:GetOwner()
		WorldModel:SetNoDraw(true)
		WorldModel:SetModelScale(self.ModelScale or 1)

		if opts.material then
			WorldModel:SetMaterial(opts.material)
		end
		if opts.color then
			WorldModel:SetColor(opts.color)
		end
		if opts.setModel then
			WorldModel:SetModel(self:GetModel())
		end

		if IsValid(owner) then
			local offsetVec = self.offsetVec
			local offsetAng = self.offsetAng
			local renderEnt = opts.renderEnt or owner

			local boneName
			if opts.boneName then
				boneName = opts.boneName
			else
				boneName = ((owner.organism and owner.organism.rarmamputated) or (owner.zmanipstart ~= nil and owner.zmanipseq == "interact" and not owner.organism.larmamputated)) and "ValveBiped.Bip01_L_Hand" or "ValveBiped.Bip01_R_Hand"
			end

			local boneid = renderEnt:LookupBone(boneName)
			if not boneid then return end
			local matrix = renderEnt:GetBoneMatrix(boneid)
			if not matrix then return end
			local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())
			WorldModel:SetPos(newPos)
			WorldModel:SetAngles(newAng)
			WorldModel:SetupBones()
		else
			WorldModel:SetPos(self:GetPos())
			WorldModel:SetAngles(self:GetAngles())
		end

		WorldModel:DrawModel()
	end

	function hg.swep.DrawSimpleCrosshair(self)
		if GetViewEntity() ~= LocalPlayer() then return end
		if LocalPlayer():InVehicle() then return end
		local tr = hg.swep.GetEyeTrace(self)
		local toScreen = tr.HitPos:ToScreen()
		surface.SetDrawColor(255, 255, 255, 155)
		surface.DrawRect(toScreen.x - 2.5, toScreen.y - 2.5, 5, 5)
	end
end
