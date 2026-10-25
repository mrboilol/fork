AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Portable Bomb"
ENT.Category = "ZCity Other"
ENT.Spawnable = false
ENT.Model = "models/jmod/explosives/bombs/c4/w_c4_planted.mdl"
ENT.UseRange = 150
ENT.CodeLength = 6

function ENT.BeepInterval(left, total)
	return math.Clamp(math.min(left / total, left / 15), 0.07, 1)
end

if SERVER then
	util.AddNetworkString("hg_pbomb_keypad")
	util.AddNetworkString("hg_pbomb_enter")

	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetModelScale(0.5)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(10)
			phys:Wake()
		end

		self.NextBeep = 0
		self.BeepCount = 0
	end

	function ENT:Arm(time, code, planter, power)
		self.Code = code
		self.Planter = planter
		self.Power = power or hg.BombPowerDefault
		self.NextBeep = 0
		self:SetNWFloat("pb_total", time)
		self:SetNWFloat("pb_end", CurTime() + time)
		self:SetNWString("pb_known", string.rep("*", self.CodeLength))
		self:SetNWBool("pb_armed", true)
	end

	function ENT:Disarm()
		self:SetNWBool("pb_armed", false)
		self:SetNWString("pb_known", string.rep("*", self.CodeLength))
	end

	function ENT:TryCode(ply, txt)
		if txt == self.Code then
			local left = self:GetNWFloat("pb_end") - CurTime()
			self:Disarm()
			ply:ChatPrint("The bomb has been disarmed.")
			hg.BombDisarmCrash(ply, left)
			return
		end

		local known = self:GetNWString("pb_known")
		local out = ""

		for i = 1, self.CodeLength do
			local real = string.sub(self.Code, i, i)
			if string.sub(txt, i, i) == real then
				out = out .. real
			elseif string.sub(known, i, i) == real then
				out = out .. real
			else
				out = out .. "*"
			end
		end

		self:SetNWString("pb_known", out)
	end

	function ENT:Use(activator)
		if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end

		if self:GetNWBool("pb_armed") then
			net.Start("hg_pbomb_keypad")
				net.WriteEntity(self)
			net.Send(activator)
			return
		end

		if activator:HasWeapon("weapon_portable_bomb") then
			activator:ChatPrint("You already carry a bomb.")
			return
		end

		local wep = activator:Give("weapon_portable_bomb")
		if not IsValid(wep) then return end

		wep.BombTime = self:GetNWFloat("pb_total", wep.DefaultBombTime)
		wep.BombCode = self.Code or wep.BombCode
		wep.BombPower = self.Power or wep.BombPower
		self:Remove()
	end

	function ENT:Beep(left, total, interval)
		self.BeepCount = self.BeepCount + 1
		self:SetNWInt("pb_beep", self.BeepCount)

		local pitch = math.Remap(1 - math.Clamp(left / total, 0, 1), 0, 1, 100, 150)
		self:EmitSound("snd_jack_chargecapacitor.ogg", 70, pitch)

		for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 32 / interval)) do
			local org = ent.organism
			if org then
				org.adrenalineAdd = (org.adrenalineAdd or 0) + 0.02 / interval
				org.fear = math.min((org.fear or 0) + 0.02 / interval, 1)
			end
		end
	end

	function ENT:Detonate()
		if self.Exploded then return end
		self.Exploded = true
		self:SetNWBool("pb_armed", false)

		util.ScreenShake(self:GetPos(), 95, 500, 4, 1000)
		hg.BombExplode(self, self.Planter, self.Power)
	end

	function ENT:Think()
		self:NextThink(CurTime())
		if not self:GetNWBool("pb_armed") then return true end

		local total = self:GetNWFloat("pb_total", 1)
		local left = self:GetNWFloat("pb_end") - CurTime()

		if left <= 0 then
			self:Detonate()
			return true
		end

		if self.NextBeep <= CurTime() then
			local interval = self.BeepInterval(left, total)
			self.NextBeep = CurTime() + interval
			self:Beep(left, total, interval)
		end

		return true
	end

	net.Receive("hg_pbomb_enter", function(len, ply)
		local ent = net.ReadEntity()
		local txt = net.ReadString()

		if not IsValid(ply) or not ply:Alive() then return end
		if not IsValid(ent) or ent:GetClass() ~= "ent_portable_bomb" or not ent:GetNWBool("pb_armed") then return end
		if ply:GetPos():DistToSqr(ent:GetPos()) > ent.UseRange ^ 2 then return end
		if ply.organism and not ply.organism.canmove then return end
		if #txt ~= ent.CodeLength or not string.match(txt, "^%d+$") then return end
		if (ply.NextPBombTry or 0) > CurTime() then return end

		ply.NextPBombTry = CurTime() + 0.4
		ent:TryCode(ply, txt)
	end)

	return
end

local flashMat = Material("engine/lightsprite")

surface.CreateFont("ZCity_PBomb_Time", {font = "Courier New", size = 64, weight = 800})
surface.CreateFont("ZCity_PBomb_Code", {font = "Courier New", size = 40, weight = 800})
surface.CreateFont("ZCity_PBomb_Input", {font = "Courier New", size = 56, weight = 800})
surface.CreateFont("ZCity_PBomb_ScreenBig", {font = "Courier New", size = 150, weight = 800})
surface.CreateFont("ZCity_PBomb_ScreenSmall", {font = "Courier New", size = 64, weight = 800})

local function FormatTime(left)
	left = math.max(left, 0)
	return string.format("%02d:%02d", math.floor(left / 60), math.floor(left % 60))
end

local function DrawCentered(text, font, x, y, r, g, b)
	surface.SetFont(font)
	surface.SetTextColor(r, g, b, 255)
	local tw = surface.GetTextSize(text)
	surface.SetTextPos(x - tw / 2, y)
	surface.DrawText(text)
end

local SCREEN_OFFSET, SCREEN_ANGLE = Vector(4, 5, 6.7), Angle(0, -90, 0)
local SCREEN_X, SCREEN_Y, SCREEN_W, SCREEN_H = 1020, 100, 785, 415

function ENT:Draw()
	self:DrawModel()

	local eye = EyePos()
	local pos = self:GetPos()
	local distSqr = eye:DistToSqr(pos)
	if distSqr > 250000 then return end

	local armed = self:GetNWBool("pb_armed")

	if armed then
		local beep = self:GetNWInt("pb_beep")
		if beep ~= self.LastBeep then
			self.LastBeep = beep
			self.FlashUntil = CurTime() + 0.08
		end

		if (self.FlashUntil or 0) > CurTime() then
			local lightPos = pos + self:GetAngles():Up() * 6
			local tr = util.TraceLine({
				start = lightPos,
				endpos = eye,
				filter = {self, LocalPlayer()},
				mask = MASK_VISIBLE
			})
			if not tr.Hit then
				render.SetMaterial(flashMat)
				render.DrawSprite(lightPos, 10, 10, color_red)
			end
		end
	end

	if distSqr > 90000 then return end

	local screenPos, screenAng = LocalToWorld(SCREEN_OFFSET, SCREEN_ANGLE, pos, self:GetAngles())
	local cx = SCREEN_X + SCREEN_W / 2
	local known = self:GetNWString("pb_known")
	local input = self.PBInput

	cam.Start3D2D(screenPos, screenAng, 0.006)
		surface.SetDrawColor(0, 0, 0, 160)
		surface.DrawRect(SCREEN_X, SCREEN_Y, SCREEN_W, SCREEN_H)

		if armed then
			local blink = (self.FlashUntil or 0) > CurTime()
			DrawCentered(FormatTime(self:GetNWFloat("pb_end") - CurTime()), "ZCity_PBomb_ScreenSmall", cx, SCREEN_Y + 15, blink and 255 or 120, 30, 30)
		else
			DrawCentered("DISARMED", "ZCity_PBomb_ScreenSmall", cx, SCREEN_Y + 15, 90, 200, 90)
		end

		if input then
			DrawCentered(input .. string.rep("_", self.CodeLength - #input), "ZCity_PBomb_ScreenBig", cx, SCREEN_Y + 90, 255, 255, 255)
			DrawCentered(known, "ZCity_PBomb_ScreenSmall", cx, SCREEN_Y + 270, 200, 200, 60)
		else
			DrawCentered(known, "ZCity_PBomb_ScreenBig", cx, SCREEN_Y + 90, 200, 200, 60)
		end
	cam.End3D2D()
end

local function OpenKeypad(ent)
	if IsValid(PBombKeypad) then PBombKeypad:Remove() end

	local frame = vgui.Create("DFrame")
	PBombKeypad = frame
	frame:SetTitle("Portable Bomb")
	frame:SetSize(320, 480)
	frame:Center()
	frame:SetDraggable(false)
	frame:MakePopup()

	local txt = ""

	local function setText(value)
		txt = value
		if IsValid(ent) then ent.PBInput = value end
	end

	frame.OnRemove = function()
		if IsValid(ent) then ent.PBInput = nil end
	end

	local function press(digit)
		if #txt >= ent.CodeLength then return end
		surface.PlaySound("weapons/p99/fireselect.ogg")
		setText(txt .. digit)
	end

	local function clear()
		surface.PlaySound("weapons/ins2/p80/m9_empty.ogg")
		setText("")
	end

	local function enter()
		if #txt < ent.CodeLength then
			chat.AddText("The code must be of " .. ent.CodeLength .. " numbers.")
			return
		end
		surface.PlaySound("weapons/tfa_ins2_sr25_eft/m14_empty.ogg")
		net.Start("hg_pbomb_enter")
			net.WriteEntity(ent)
			net.WriteString(txt)
		net.SendToServer()
		setText("")
	end

	local display = vgui.Create("DPanel", frame)
	display:Dock(TOP)
	display:SetTall(150)
	display:DockMargin(0, 0, 0, 8)
	display.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, 220)
		surface.DrawRect(0, 0, w, h)

		if not IsValid(ent) then return end

		if ent:GetNWBool("pb_armed") then
			DrawCentered(FormatTime(ent:GetNWFloat("pb_end") - CurTime()), "ZCity_PBomb_Time", w / 2, 6, 255, 40, 40)
		else
			DrawCentered("DISARMED", "ZCity_PBomb_Code", w / 2, 14, 90, 200, 90)
		end

		DrawCentered(txt .. string.rep("_", ent.CodeLength - #txt), "ZCity_PBomb_Input", w / 2, 60, 255, 255, 255)
		DrawCentered(ent:GetNWString("pb_known"), "ZCity_PBomb_Code", w / 2, 108, 200, 200, 60)
	end

	local grid = vgui.Create("DPanel", frame)
	grid:Dock(FILL)
	grid.Paint = function() end

	local labels = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "Clear", "0", "Enter"}
	grid.PerformLayout = function(self, w, h)
		local bw, bh = w / 3, h / 4
		for i, but in ipairs(self:GetChildren()) do
			local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
			but:SetPos(col * bw + 2, row * bh + 2)
			but:SetSize(bw - 4, bh - 4)
		end
	end

	for _, label in ipairs(labels) do
		local but = vgui.Create("DButton", grid)
		but:SetText(label)
		but.DoClick = function()
			if label == "Clear" then clear()
			elseif label == "Enter" then enter()
			else press(label) end
		end
	end

	frame.OnKeyCodePressed = function(self, key)
		if key >= KEY_0 and key <= KEY_9 then
			press(key - KEY_0)
		elseif key >= KEY_PAD_0 and key <= KEY_PAD_9 then
			press(key - KEY_PAD_0)
		elseif key == KEY_BACKSPACE then
			setText(string.sub(txt, 1, -2))
		elseif key == KEY_ENTER or key == KEY_PAD_ENTER then
			enter()
		end
	end

	local baseThink = frame.Think
	frame.Think = function(self)
		if baseThink then baseThink(self) end
		if not IsValid(ent) or LocalPlayer():GetPos():DistToSqr(ent:GetPos()) > 40000 then
			self:Remove()
		end
	end
end

net.Receive("hg_pbomb_keypad", function()
	local ent = net.ReadEntity()
	if IsValid(ent) then OpenKeypad(ent) end
end)
