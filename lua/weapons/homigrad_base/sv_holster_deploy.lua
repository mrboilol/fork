local CurTime = CurTime

function SWEP:Holster(wep)
	if hg.HolsterGate(self, wep) then return false end

	if self.deploy then
		self:SetDeploy(0)
		self.deploy = nil
	end

	self.reload = nil

	return true
end

function SWEP:OnHolsterBegin()
	local owner = self:GetOwner()
	self.holster = hg.GetHolsterEnd(self)
	self.deploy = nil
	self:SetDeploy(0)
	self.reload = nil
	self.StaminaReloadTime = nil

	if not owner.noSound then
		owner:EmitSound(self.HolsterSnd[1], 65)
	end
end

local gamemod = engine.ActiveGamemode()
local hg_slings = ConVarExists("hg_slings") and GetConVar("hg_slings") or CreateConVar("hg_slings", 0, FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE, "Toggle sling system", 0, 1)
hook.Add("PlayerSwitchInFake","slingDrop",function(ply,oldWeapon,newWeapon)
	if not hg_slings:GetBool() then return end
	if oldWeapon == newWeapon then return end
	if zb.CROUND and zb.CROUND == "hmcd" or gamemod == "sandbox" then
		local inv = ply:GetNetVar("Inventory")

		if SERVER and not oldWeapon.bigNoDrop and oldWeapon.weaponInvCategory == 1 and not inv["Weapons"]["hg_sling"] then
			timer.Simple(0,function()
				if oldWeapon:GetOwner() == ply then
					hg.drop(ply, oldWeapon, newWeapon)
				end
			end)

			if not IsValid(ply.FakeRagdoll) then return true end
		end
	end
end)

SWEP.Initialzed = false
function SWEP:Deploy()
	local time = CurTime()
	self:ResetTransientAimState()
	if SERVER and self.Initialzed and not self:GetOwner().noSound then
		timer.Simple(math.min(self.CooldownDeploy / self.Ergonomics * 0.35, 0.25), function()
			if IsValid(self) and IsValid(self:GetOwner()) then
				self:GetOwner():EmitSound(self.DeploySnd[1], 65)
			end
		end)
	end
    self.Initialzed = true

	hg.ClearHolster(self)
	self.holster = nil

	self.deploy = time + self:GetDeployDuration()
	self:SetDeploy(self.deploy)

	return true
end

function SWEP:Deploy_End()
	self.deploy = nil
	self:SetDeploy(0)
end
