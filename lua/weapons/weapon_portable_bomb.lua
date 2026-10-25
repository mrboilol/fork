if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_traitor_c4"
SWEP.PrintName = "Portable Bomb"
SWEP.Instructions = "LMB - throw bomb. RMB - plant bomb on a nearby surface. R - set timer and code. Press E on a planted bomb to enter the code."
SWEP.Category = "Weapons - Explosive"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Slot = 4
SWEP.SlotPos = 3

SWEP.DefaultBombTime = 60
SWEP.MinBombTime = 5
SWEP.MaxBombTime = 900
SWEP.CodeLength = 6

if SERVER then
	util.AddNetworkString("hg_pbomb_open")
	util.AddNetworkString("hg_pbomb_set")

	local function RandomCode(len)
		local code = ""
		for i = 1, len do code = code .. math.random(0, 9) end
		return code
	end

	function SWEP:InitAdd()
		self.BaseClass.InitAdd(self)
		self.BombTime = self.BombTime or self.DefaultBombTime
		self.BombCode = self.BombCode or RandomCode(self.CodeLength)
		self.BombPower = self.BombPower or hg.BombPowerDefault
	end

	function SWEP:ThinkAdd()
		self.BaseClass.ThinkAdd(self)

		local owner = self:GetOwner()
		if not IsValid(owner) or not owner:KeyDown(IN_RELOAD) or self:GetBusy() then return end
		if (self.NextConfig or 0) > CurTime() then return end

		self.NextConfig = CurTime() + 1
		net.Start("hg_pbomb_open")
			net.WriteFloat(self.BombTime)
			net.WriteString(self.BombCode)
			net.WriteUInt(self.BombPower, 3)
		net.Send(owner)
	end

	function SWEP:CreateC4Charge(pos, ang)
		local bomb = ents.Create("ent_portable_bomb")
		if not IsValid(bomb) then return end

		if self.PlantNormal then
			local _, planted = LocalToWorld(vector_origin, Angle(-90, 0, 180), pos, self.PlantNormal:Angle())
			ang = planted
		end

		bomb:SetPos(pos)
		bomb:SetAngles(ang)
		bomb:Spawn()
		bomb:Activate()
		bomb:Arm(self.BombTime, self.BombCode, self:GetOwner(), self.BombPower)
		return bomb
	end

	function SWEP:ConsumeIfPlaced()
		if self:GetChargePlaced() and not self.Consumed then
			self.Consumed = true
			SafeRemoveEntityDelayed(self, 0)
		end
	end

	function SWEP:FinishC4Throw(keepBusy)
		self.BaseClass.FinishC4Throw(self, keepBusy)
		self:ConsumeIfPlaced()
	end

	function SWEP:FinishC4Plant(keepBusy)
		local tr = self.PendingPlantTrace
		self.PlantNormal = tr and tr.HitNormal
		self.BaseClass.FinishC4Plant(self, keepBusy)
		self.PlantNormal = nil
		self:ConsumeIfPlaced()
	end

	net.Receive("hg_pbomb_set", function(len, ply)
		local time = net.ReadFloat()
		local code = net.ReadString()
		local power = net.ReadUInt(3)

		local wep = IsValid(ply) and ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_portable_bomb" or wep:GetBusy() then return end
		if not string.match(code, "^%d+$") or #code ~= wep.CodeLength then return end

		wep.BombTime = math.Clamp(math.floor(time), wep.MinBombTime, wep.MaxBombTime)
		wep.BombCode = code
		wep.BombPower = math.Clamp(power, 1, #hg.BombPower)
		ply:ChatPrint("Bomb set: " .. wep.BombTime .. "s, code " .. wep.BombCode .. ", power " .. hg.BombPower[wep.BombPower].name)
	end)

	return
end

local function OpenConfig(wepTime, wepCode, wepPower)
	if IsValid(PBombConfig) then PBombConfig:Remove() end

	local weapon = weapons.GetStored("weapon_portable_bomb")

	local frame = vgui.Create("DFrame")
	PBombConfig = frame
	frame:SetTitle("Portable Bomb")
	frame:SetSize(340, 280)
	frame:Center()
	frame:MakePopup()

	local slider = vgui.Create("DNumSlider", frame)
	slider:Dock(TOP)
	slider:DockMargin(8, 8, 8, 0)
	slider:SetText("Timer (seconds)")
	slider:SetMin(weapon.MinBombTime)
	slider:SetMax(weapon.MaxBombTime)
	slider:SetDecimals(0)
	slider:SetValue(wepTime)

	local entry = vgui.Create("DTextEntry", frame)
	entry:Dock(TOP)
	entry:DockMargin(8, 12, 8, 0)
	entry:SetTall(40)
	entry:SetFont("DermaLarge")
	entry:SetPlaceholderText("Code")
	entry:SetValue(wepCode)
	entry.OnChange = function(self)
		local value = string.sub(string.gsub(self:GetValue(), "%D", ""), 1, weapon.CodeLength)
		if value ~= self:GetValue() then
			self:SetValue(value)
			self:SetCaretPos(#value)
		end
	end

	local power = wepPower
	local combo = vgui.Create("DComboBox", frame)
	combo:Dock(TOP)
	combo:DockMargin(8, 8, 8, 0)
	combo:SetTall(28)
	for i, level in ipairs(hg.BombPower) do
		combo:AddChoice("Power: " .. level.name, i, i == wepPower)
	end
	combo.OnSelect = function(_, _, _, data)
		power = data
	end

	local random = vgui.Create("DButton", frame)
	random:Dock(TOP)
	random:DockMargin(8, 8, 8, 0)
	random:SetText("Random code")
	random.DoClick = function()
		local code = ""
		for i = 1, weapon.CodeLength do code = code .. math.random(0, 9) end
		entry:SetValue(code)
	end

	local set = vgui.Create("DButton", frame)
	set:Dock(TOP)
	set:DockMargin(8, 8, 8, 0)
	set:SetTall(32)
	set:SetText("Set")
	set.DoClick = function()
		local code = entry:GetValue()
		if #code ~= weapon.CodeLength then
			chat.AddText("The code must be of " .. weapon.CodeLength .. " numbers.")
			return
		end
		surface.PlaySound("weapons/tfa_ins2_sr25_eft/m14_empty.ogg")
		net.Start("hg_pbomb_set")
			net.WriteFloat(slider:GetValue())
			net.WriteString(code)
			net.WriteUInt(power, 3)
		net.SendToServer()
		frame:Remove()
	end
end

net.Receive("hg_pbomb_open", function()
	OpenConfig(net.ReadFloat(), net.ReadString(), net.ReadUInt(3))
end)
