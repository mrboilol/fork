if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Morphine"
SWEP.Instructions = "A very strong medicine used primarily to lower the pressure and/or as an anesthetic. Morphine dose must be strictly observed, as it can lead to opiate overdose. Contains the maximum daily dose. RMB to inject into someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/morphine_syrette/morphine.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_morphine")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_morphine.vmt"
	SWEP.BounceWeaponIcon = false
end
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(8, -1.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modeNames = {
	[1] = "analgesic"
}

SWEP.JudgeMedicalTPIK = true
SWEP.BandageTPIK = false
SWEP.supportTPIK = true
SWEP.isTPIKBase = true
SWEP.WorldModelReal = SWEP.WorldModel
SWEP.HideMeshBones = {}
SWEP.UseSpeed = 3
SWEP.CallbackTimeAdjust = 0.5
SWEP.AnimList = {
	["deploy"] = { "deploy", 0.5, false },
	["use"] = { "use", 3, true },
	["idle"] = { "idle", 5, true }
}

SWEP.DeploySnd = ""
SWEP.HolsterSnd = ""

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "Holding")
    self:NetworkVar("Float", 1, "RemainingAmount")
    self:NetworkVar("Float", 2, "Dose")
    self:NetworkVar("Bool", 0, "HealingOther")
end

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	self.modeValues = {
		[1] = 1,
	}
	self:SetDose(self.modeValues[1])
	self:SetRemainingAmount(self.modeValues[1])
	self.ModelScale = 1
end

SWEP.ofsV = Vector(0,8,-3)
SWEP.ofsA = Angle(-90,-90,90)

SWEP.modeValuesdef = {
	[1] = {1, true},
}
SWEP.ShouldDeleteOnFullUse = false

SWEP.showstats = true

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Healing method: 0 = original models + progressive minigames, 1 = Judge animations", 0, 1)

function SWEP:Think()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	if not owner:KeyDown(IN_ATTACK) and not hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 4, 0))
	end
	
	-- Update model scale based on remaining amount (use networked value on client)
	local remaining = SERVER and self.modeValues[1] or self:GetRemainingAmount()
	if self.modeValuesdef and self.modeValuesdef[1] and self.modeValuesdef[1][1] then
		self.ModelScale = math.Clamp(remaining / (self.modeValuesdef[1][1] * 0.8), 0.5, 1)
	else
		self.ModelScale = self.ModelScale or 1
	end

	if hg_healanims:GetBool() then self:ThinkAdd() end
end

function SWEP:Animation()
	local hold = self:GetHolding()
    self:BoneSet("r_upperarm", vector_origin, Angle(0, -hold + (100 * (hold / 100)), 0))
    self:BoneSet("r_forearm", vector_origin, Angle(-hold / 6, -hold * 2, -15))
end

sound.Add( {
	name = "pshiksnd",
	channel = CHAN_AUTO,
	volume = 0.02,
	level = 65,
	pitch = {5555, 5555},
	sound = "snd_jack_sss.ogg",
} )

function SWEP:Deploy()
	if not hg_healanims:GetBool() then return true end
	local base = weapons.GetStored("weapon_tpik_base")
	if base and base.Deploy then return base.Deploy(self) end
	return true
end

function SWEP:Holster()
	self:SetHealingOther(false)
	self.setlh = true
	self.healing = false
	self.callback = nil
	hook.Remove("Think", "AnimCallback" .. self:EntIndex())
	self._injectStartTime = nil
	self._slowed = false
	self._animStarted = false
	return true
end

function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if IsValid(owner) and owner:IsNPC() then
		self:SpawnGarbage()
		self:NPCHeal(owner, 0.3, "snd_jack_hmcd_needleprick.ogg")
	end
end

function SWEP:ThinkAdd()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	local curTime = CurTime()
	local anim = self.anim

	if not self.healing and anim == "deploy" and self.animtime and self.animtime <= curTime then
		if SERVER then
			self:PlayAnim("idle")
		end
	end

	if self.healing and not self._animStarted then
		local buttonHeld = owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2)
		if buttonHeld and self.modeValues[1] > 0 then
			self._animStarted = true
			self._injectStartTime = curTime
			self._slowed = false
			if SERVER then
				self:PlayAnim("use", self.UseSpeed, true, nil, false)
			end
		elseif not buttonHeld then
			self.healing = false
			self:SetHealingOther(false)
			self.setlh = true
		end
	end

	if self.healing and not owner:KeyDown(IN_ATTACK) and not owner:KeyDown(IN_ATTACK2) then
		self.healing = false
		self:SetHealingOther(false)
		self.setlh = true
		self._injectStartTime = nil
		self._slowed = false
		self._animStarted = false
		self.callback = nil
		hook.Remove("Think", "AnimCallback" .. self:EntIndex())
		if SERVER then
			if self.modeValues[1] > 0 then
				self:ReverseAnimToIdle("use")
			else
				self:PlayAnim("idle")
			end
		end
	end

	if self.healing and self._injectStartTime then
		local timeSinceStart = curTime - self._injectStartTime

		if timeSinceStart >= 1 then
			if not self._slowed then
				self._slowed = true
				if SERVER then
					self.animspeed = self.animspeed * 2
					self.animtime = curTime + (self.animtime - curTime) * 2
				end
			end

			local ent = self:GetHealingOther() and IsValid(self.healbuddy) and self.healbuddy or owner
			local org = ent.organism
			if org and self.modeValues[1] > 0 then
				local injected = math.min(FrameTime() * 0.5, self.modeValues[1])
				org.analgesiaAdd = math.min(org.analgesiaAdd + injected, 4)
				self.modeValues[1] = math.max(self.modeValues[1] - injected, 0)
				self:SetDose(self.modeValues[1])

				owner.injectedinto = owner.injectedinto or {}
				owner.injectedinto[org.owner] = owner.injectedinto[org.owner] or 0
				owner.injectedinto[org.owner] = owner.injectedinto[org.owner] + injected

				if owner.injectedinto[org.owner] > 1 and injected > 0 then
					local dmgInfo = DamageInfo()
					dmgInfo:SetAttacker(owner)
					hook.Run("HomigradDamage", org.owner, dmgInfo, HITGROUP_RIGHTARM, hg.GetCurrentCharacter(org.owner), injected * (zb and zb.MaximumHarm or 1))
				end

				if SERVER then
					local entOwner = IsValid(ent.FakeRagdoll) and ent.FakeRagdoll or ent
					entOwner:EmitSound("pshiksnd")
				end

				if self.modeValues[1] <= 0 then
					self.healing = false
					self:SetHealingOther(false)
					self.setlh = true
					self._injectStartTime = nil
					self._slowed = false
					self._animStarted = false
					self.callback = nil
					hook.Remove("Think", "AnimCallback" .. self:EntIndex())
					if SERVER then
						owner:DropWeapon(self)
						owner:SelectWeapon("weapon_hg_coolhands")
					end
					return
				end
			end
		end
	end

	self:ThinkReverseAnimToIdle(curTime)
end

function SWEP:SetHandPos(noset)
	if not hg_healanims:GetBool() then return end

	if self:GetHealingOther() then
		self.setlh = false
	else
		self.setlh = true
	end

	return self.BaseClass.SetHandPos(self, noset)
end

function SWEP:PostSetHandPos()
	if not hg_healanims:GetBool() then return end

	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local ent = hg.GetCurrentCharacter(ply)
	if not IsValid(ent) then return end

	local handPosOffset = isvector(self.handPosOffset) and self.handPosOffset or vector_origin
	local handAngOffset = isangle(self.handAngOffset) and self.handAngOffset or angle_zero

	local rhBone = ent:LookupBone("ValveBiped.Bip01_R_Hand")
	if rhBone then
		local mat = ent:GetBoneMatrix(rhBone)
		if mat then
			local pos = mat:GetTranslation() + handPosOffset
			local ang = mat:GetAngles()
			ang.p = ang.p + handAngOffset.p
			ang.y = ang.y + handAngOffset.y
			ang.r = ang.r + handAngOffset.r
			mat:SetTranslation(pos)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(rhBone, mat)
		end
	end

	if not self.lhandik then return end

	local lhBone = ent:LookupBone("ValveBiped.Bip01_L_Hand")
	if lhBone then
		local mat = ent:GetBoneMatrix(lhBone)
		if mat then
			local pos = mat:GetTranslation()
			local offset = handPosOffset
			pos.x = pos.x - offset.x
			pos.y = pos.y - offset.y
			pos.z = pos.z + offset.z
			local ang = mat:GetAngles()
			ang.p = ang.p - handAngOffset.p
			ang.y = ang.y - handAngOffset.y
			ang.r = ang.r + handAngOffset.r
			mat:SetTranslation(pos)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(lhBone, mat)
		end
	end
end

if CLIENT then
	local colWhite = Color(255, 255, 255, 255)
	local colGray = Color(200, 200, 200, 200)
	local lerpthing = 1
	local colBrown = Color(40,40,40)
	SWEP.showstats = true
	local vector_one = Vector(1,1,1)
	function SWEP:DrawHUD()
		local owner = self:GetOwner()
		if !owner:IsPlayer() then return end
		if GetViewEntity() ~= owner then return end
		if owner:InVehicle() then return end
		local Tr = hg.eyeTrace(owner)
		if !Tr then return end
		local Size = math.max(math.min(1 - Tr.Fraction, 0.5), 0.1)
		local x, y = Tr.HitPos:ToScreen().x, Tr.HitPos:ToScreen().y
		if Tr.Hit then
			lerpthing = Lerp(0.1, lerpthing, 1)
			colWhite.a = 255 * Size
			surface.SetDrawColor(colGray)
			draw.NoTexture()
			surface.SetDrawColor(colWhite)
			draw.NoTexture()
			surface.DrawRect(x - 25 * lerpthing, y - 2.5, 50 * lerpthing, 5)
			surface.DrawRect(x - 2.5, y - 25 * lerpthing, 5, 50 * lerpthing)
			local col = Tr.Entity:GetPlayerColor():ToColor()
			local coloutline = (col.r < 50 and col.g < 50 and col.b < 50) and Color(255,255,255) or Color(0,0,0)
			coloutline.a = 255 * Size * 2
			draw.DrawText(Tr.Entity:IsPlayer() and Tr.Entity:GetPlayerName() or Tr.Entity:IsRagdoll() and Tr.Entity:GetPlayerName() or "", "HomigradFontLarge", x + 1, y + 31, coloutline, TEXT_ALIGN_CENTER)
			draw.DrawText(Tr.Entity:IsPlayer() and Tr.Entity:GetPlayerName() or Tr.Entity:IsRagdoll() and Tr.Entity:GetPlayerName() or "", "HomigradFontLarge", x, y + 30, col, TEXT_ALIGN_CENTER)
		end
		self:DrawWorldModel2(true)
		if self.showstats and self.modeValues and istable(self.modeValues) then
			render.PushFilterMag( TEXFILTER.LINEAR )
			render.PushFilterMin( TEXFILTER.LINEAR )
			local m = Matrix()
			m:Translate( Vector(  ScrW() / 2-ScreenScale(60), ScrH() / 2 + ScreenScaleH(125), 0 ) )
			m:Scale( vector_one * 0.5 )

			cam.PushModelMatrix( m, true )
				local dose = self:GetDose() or 0
				local maxDose = self.modeValuesdef and self.modeValuesdef[1] and self.modeValuesdef[1][1] or 1
				local val = math.Round(dose / maxDose * 100)
				local x,y = 0, ScrH() / 20
				local reveal = 1
				colBrown.a = reveal * 185
				draw.RoundedBox(2,x,y,x + ScreenScale(210) + ScrW() / 10,ScrH() / 25,colBrown)
				surface.SetFont("ZCity_Small")
				surface.SetTextPos(x,y)
				surface.SetTextColor(255,255,255,255 * reveal)
				local txt = string.NiceName(tostring(self.modeNames[1]))
				local w, h = surface.GetTextSize(txt)
				colBrown.a = reveal * 255
				draw.SimpleTextOutlined(txt, "ZCity_Small", x, y, Color(255,50,50, 255 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1.5, colBrown)

				surface.SetDrawColor(0,100,0,255 * reveal)
				surface.DrawRect(x + ScreenScale(210),y,ScrW() / 10 * val / 100,ScrH() / 25)
				surface.SetDrawColor(0,0,0,255 * reveal)
				surface.DrawOutlinedRect(x + ScreenScale(210),y,ScrW() / 10,ScrH() / 25, 4)
			cam.PopModelMatrix()

			render.PopFilterMag()
			render.PopFilterMin()
		end
	end
end

if SERVER then
	function SWEP:PrimaryAttack()
		if not hg_healanims:GetBool() then return self.BaseClass.PrimaryAttack(self) end
		local owner = self:GetOwner()
		if not IsValid(owner) or not self.modeValues or (self.modeValues[1] or 0) <= 0 or self.healing then return end

		self.healbuddy = owner
		self:SetHealingOther(false)
		self.setlh = true
		self.healing = true
	end

	function SWEP:SecondaryAttack()
		if not hg_healanims:GetBool() then return self.BaseClass.SecondaryAttack(self) end
		local owner = self:GetOwner()
		if not IsValid(owner) or not self.modeValues or (self.modeValues[1] or 0) <= 0 or self.healing then return end

		local trace = hg.eyeTrace(owner, 100)
		local ent = trace and trace.Entity
		if IsValid(ent) and ent:IsRagdoll() and hg.RagdollOwner then
			ent = hg.RagdollOwner(ent) or ent
		end
		if not IsValid(ent) or not ent.organism or hg.GetCurrentCharacter(ent) == hg.GetCurrentCharacter(owner) then return end

		local character = hg.GetCurrentCharacter(ent)
		if not IsValid(character) or owner:GetPos():DistToSqr(character:GetPos()) > 10000 then return end
		self.healbuddy = ent
		self:SetHealingOther(true)
		self.setlh = false
		self.healing = true
	end

	function SWEP:Heal(ent, mode)
		if ent:IsNPC() then
			self:SpawnGarbage()
			self:NPCHeal(ent, 0.3, "snd_jack_hmcd_needleprick.ogg")
		end

		local org = ent.organism
		if not org then return end

		if self.modeValues[1] <= 0 then return end

		local owner = self:GetOwner()
		if ent == hg.GetCurrentCharacter(owner) and not hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))

			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner

		local lacedAmount = self.HG_FentanylLacedAmount or 0
		if lacedAmount > 0 then
			org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + lacedAmount, 25)
			self.HG_FentanylLacedAmount = nil
		end
		local injected = math.min(hg_healanims:GetBool() and self.modeValues[1] or FrameTime() * 0.5, self.modeValues[1])
		org.analgesiaAdd = math.min(org.analgesiaAdd + injected, 4)
		self.modeValues[1] = math.max(self.modeValues[1] - injected, 0)

		owner.injectedinto = owner.injectedinto or {}
		owner.injectedinto[org.owner] = owner.injectedinto[org.owner] or 0
		owner.injectedinto[org.owner] = owner.injectedinto[org.owner] + injected

		if owner.injectedinto[org.owner] > 1 and injected > 0 then
			local dmgInfo = DamageInfo()
			dmgInfo:SetAttacker(owner)
			hook.Run("HomigradDamage", org.owner, dmgInfo, HITGROUP_RIGHTARM, hg.GetCurrentCharacter(org.owner), injected * (zb and zb.MaximumHarm or 1))
		end

		if self.poisoned2 then
			org.poison4 = CurTime()

			self.poisoned2 = nil
		end

		-- Sync remaining amount to client
		self:SetRemainingAmount(self.modeValues[1])
		
		if self.modeValues[1] != 0 then
			entOwner:EmitSound("pshiksnd")
		else
			-- No deletion - syringe stays even when empty
			-- owner:SelectWeapon("weapon_hands_sh")
			-- self:Remove()
		end
	end
end
