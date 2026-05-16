local CLASS = player.RegClass("expie")

function CLASS.Off(self)
	if CLIENT then return end

	ApplyAppearance(self,false,false,false,true)

	if SERVER then
		self.organism.bloodtype = self.oldbloodtype or "o-"
		hg.ClearArmorRestrictions(self)
		self.IsExpie = false
	end

	if eightbit and eightbit.EnableEffect and self.UserID then
		eightbit.EnableEffect(self:UserID(), 0)
	end

	self.JumpPowerMul = nil
	self.SpeedGainClassMul = nil
	self:SetNWInt("SpeedGainClassMul", nil)
	self.MeleeDamageMul = nil
	self.StaminaExhaustMul = nil
end

local sw, sh = CLIENT and ScrW() or nil, CLIENT and ScrH() or nil
CLASS.NoGloves = true

local function GetExpieModel(ply)
	local Appearance = ply.CurAppearance
	if Appearance and hg.Appearance.PlayerModels[2][Appearance.AModel] then
		return "models/assassingecko/geckoexpie/femgeckoexpie.mdl"
	elseif Appearance and hg.Appearance.PlayerModels[1][Appearance.AModel] then
		return "models/assassingecko/geckoexpie/geckoexpie.mdl"
	end
	return math.random(2) == 1 and "models/assassingecko/geckoexpie/femgeckoexpie.mdl" or "models/assassingecko/geckoexpie/geckoexpie.mdl"
end

function CLASS.On(self, data)
	if SERVER then
		if eightbit and eightbit.EnableEffect and self.UserID then
            eightbit.EnableEffect(self:UserID(), eightbit.EFF_PROOT)
		end
		self.IsExpie = true
self:SetSubMaterial(0,"")
        local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
		Appearance.AAttachments = ""
		Appearance.AColthes = ""
        
        self:SetNetVar("Accessories", "")
		self.CurAppearance = Appearance
        self:SetSubMaterial(0,"")
		if self.organism then
			self.oldbloodtype = self.organism.bloodtype
			self.organism.bloodtype = "yellow blood" //lol kill your teammates to survive idk
		end
        	if self.FakeRagdoll then hg.FakeUp(self,true) end
        	self.JumpPowerMul = 1.5
		self.SpeedGainClassMul = 35 //shit doesnt even work (?)
		self.StaminaExhaustMul = 0.75
		local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()

		local name = "Experiment #" .. math.random(1, 999)
//for _, bg in ipairs(self:GetBodyGroups() or {}) do self:SetBodygroup(bg.id, 0) end local bgs = table.Copy(self:GetBodyGroups() or {}) for i = 1, math.random(3, 4) do if #bgs == 0 then break end local idx = math.random(#bgs) local bg = table.remove(bgs, idx) self:SetBodygroup(bg.id, math.random(0, bg.num - 1)) end
//bodygroups buggy with fake sys cuz salat is a NOOOB LOLOOLOLO NOOOB LIGMA
for _, bg in ipairs(self:GetBodyGroups() or {}) do self:SetBodygroup(bg.id, 0) end self:SetSkin(0) //femboy set by default for some reason so needs a reset

		self:SetNWString("PlayerName", name)
		Appearance.AName = name
		self:SetModel(GetExpieModel(self))
	end

	if data.instant then
		if SERVER then
			self:SetNWInt("SpeedGainClassMul", self.SpeedGainClassMul)
			self.armors = {}
			self:SyncArmor()
			self:SetModel(GetExpieModel(self))
			self:SetSkin(0)
			self:SetSubMaterial(0,"")
            self:SetNetVar("Accessories", "")
		end
		self:SetModel(GetExpieModel(self))
		self:SetSubMaterial(0,"")
		self:SetNetVar("Accessories", "")
		if self.SetNetVar then
			self:SetNetVar("Accessories", "")
		end

		for i = 1, self:GetFlexNum() - 1 do
			self:SetFlexWeight(i, 0)
		end

		return
	end
end

function CLASS.HUDPaint(self)
if !self:Alive() then return end
// MAKE C:U STATUS HUD LATER
// bruh just use https://steamcommunity.com/sharedfiles/filedetails/?id=3683079310
end


