
include("shared.lua")

function BombInSite(pos, site)
    local pts = zb.ClPoints["BOMB_ZONE_"..(site == 1 and "A" or "B")]

	local vec1
	local vec2
	local vec3
	local vec4

	if #pts >= 2 then
		vec1 = -(-pts[1].pos)
		vec1[3] = vec1[3] - 256
		vec2 = -(-pts[2].pos)
		vec2[3] = vec2[3] + 256
	end
	
	return (#pts < 2 or pos:WithinAABox(vec1,vec2))
end

 

local offsetAng = Angle(-90,0,0)
local offsetVec = Vector(0,0,0)

local addDir = Angle(0,0,0)
local addDirAdd = Angle(0,0,0)

local vecZero,angZero = Vector(0,0,0),Angle(0,0,0)

ENT.nextbeep = 0
local mat = Material("engine/lightsprite")

local offsetVec1,offsetAng1 = Vector(4,5,6.7),Angle(0,-90,0)

local DrawReadout, ScreenRect

if IsValid(modelHuybombb) then
	modelHuybombb:Remove()
	modelHuybombb = nil
end

modelHuybombb = ClientsideModel(ENT.Model)
modelHuybombb:SetNoDraw(true)

function ENT:Draw()
	local view = render.GetViewSetup(true)
	
	if not IsValid(modelHuybombb) then
		modelHuybombb = ClientsideModel(self.Model)
		modelHuybombb:SetNoDraw(true)
	end

	 
	local pos = view.origin + view.angles:Forward() * 25
	local ang = view.angles

	addDir = Lerp(0.9,angZero,addDir)
	addDirAdd = Lerp(0.2,addDirAdd,addDir)

	local dir = util.AimVector(view.angles,view.fov,gui.MouseX(),gui.MouseY(),ScrW(),ScrH())
	dir = dir:Angle()
	local _,dir = WorldToLocal(vecZero,dir,vecZero,view.angles)
	dir[2] = -dir[2]
	dir[1] = -dir[1]
	dir = dir / 3
	dir = dir + addDirAdd
	ang:Add(dir)

	local pos,ang = LocalToWorld(offsetVec,offsetAng,pos,ang)
	
	self:SetRenderOrigin()
	self:SetRenderAngles()

	if self:GetNetVar("timer") then
		if self.nextbeep < CurTime() and self:GetNetVar("timer") > CurTime() then		
			self.nextbeep = CurTime() + math.max((self:GetNetVar("timer") - CurTime()) / self.ExplodeTime,0.05)
		end
	end

	self.looklerp = Lerp(0.1,self.looklerp or 1,self.islooked and 0 or 1)
	self.desiredpos = Lerp(self.looklerp, pos, self:GetPos())
	self.desiredang = LerpAngle(self.looklerp, ang, self:GetAngles())

	modelHuybombb:SetRenderOrigin(self.desiredpos)
	modelHuybombb:SetRenderAngles(self.desiredang)
	modelHuybombb:SetPos(self.desiredpos)
	modelHuybombb:SetAngles(self.desiredang)
	modelHuybombb:SetModelScale(self:GetModelScale())

	self.pos = self.desiredpos
	self.ang = self.desiredang
	modelHuybombb:SetupBones()

	modelHuybombb:DrawModel()

	if IsValid(bombMenu) and bombMenu.bomb == self then
		local pos,ang = LocalToWorld(offsetVec1, offsetAng1, self.pos, self.ang)
		local size = ScrW() / 1920
		
		vgui.Start3D2D(pos, ang, 0.012 * 0.5 / size)
			bombMenu:Paint3D2D()
		vgui.End3D2D()
	elseif self:GetNetVar("timer") and view.origin:DistToSqr(self:GetPos()) < 90000 then
		local pos, ang = LocalToWorld(offsetVec1, offsetAng1, self.pos, self.ang)
		local x, y, w, h, size = ScreenRect()

		cam.Start3D2D(pos, ang, 0.012 * 0.5 / size)
			DrawReadout(self, x, y, w, h, size)
		cam.End3D2D()
	end

	if self:GetNetVar("timer") then
		if self.nextbeep - 0.05 < CurTime() then
			render.SetMaterial(mat)
			local pos = self:GetPos() + self:GetAngles():Up() * 6
			local tr = util.TraceLine({
				start = pos,
				endpos = view.origin,
				filter = {self,LocalPlayer()},
				mask = MASK_VISIBLE
			})
			if not tr.Hit then
				render.DrawSprite(pos,10,10,color_red)
			end
		end
	end
end

function ENT:Think()
	--self:SetRenderOrigin()
	--self:SetRenderAngles()
end

function ENT:Initialize()
end

function ENT:OnRemove()
end

local CreateMenu

local bomb
net.Receive("bomb_look",function()
	if IsValid(bomb) then
		bomb.islooked = false
	end
	bomb = net.ReadEntity()
	bomb = IsValid(bomb) and bomb
	
	if bomb then
		bomb.islooked = true
	end
	
	CreateMenu(bomb)
end)

hook.Add("HUDPaint","Draw3D2DFrameBomb",function()
	
end)

if IsValid(bombMenu) then
	bombMenu.bomb.islooked = nil
	bombMenu:Remove()
	bombMenu = nil
end

local colGray = Color(122,122,122,255)
local colBlue = Color(130,10,10)
local colBlueUp = Color(160,30,30)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(85,85,85,255)

local colorBG = Color(55,55,55,255)
local colorBGBlacky = Color(40,40,40,255)

local blurMat = Material("pp/blurscreen")
local Dynamic = 0

surface.CreateFont("ZCity_Bomb_Display", {font = "Courier New", size = 150, weight = 800})
surface.CreateFont("ZCity_Bomb_Display_Small", {font = "Courier New", size = 64, weight = 800})

ScreenRect = function()
	local size = ScrW() / 1920
	return ScrW() / 2 + 60 * size, 100 * size, ScrW() / 2 - 175 * size, ScrH() / 2 - 125 * size, size
end

local function DrawCentered(text, font, cx, y, r, g, b)
	surface.SetFont(font)
	surface.SetTextColor(r, g, b, 255)
	local tw = surface.GetTextSize(text)
	surface.SetTextPos(cx - tw / 2, y)
	surface.DrawText(text)
end

DrawReadout = function(bomb, x, y, w, h, size, input)
	surface.SetDrawColor(0, 0, 0, 160)
	surface.DrawRect(x, y, w, h)

	local cx = x + w / 2
	local timer = bomb:GetNetVar("timer")
	local known = bomb:GetNetVar("knowncode", "******")

	if timer then
		local left = math.max(timer - CurTime(), 0)
		local blink = math.Round(CurTime() * 2) % 2 == 0
		DrawCentered(string.format("%02d:%02d", math.floor(left / 60), math.floor(left % 60)), "ZCity_Bomb_Display_Small", cx, y + 15 * size, blink and 255 or 120, 30, 30)
	else
		DrawCentered("DISARMED", "ZCity_Bomb_Display_Small", cx, y + 15 * size, 90, 200, 90)
	end

	if input then
		DrawCentered(input .. string.rep("_", 6 - #input), "ZCity_Bomb_Display", cx, y + 90 * size, 255, 255, 255)
		DrawCentered(known, "ZCity_Bomb_Display_Small", cx, y + 270 * size, 200, 200, 60)
	else
		DrawCentered(known, "ZCity_Bomb_Display", cx, y + 90 * size, 200, 200, 60)
	end
end

CreateMenu = function(bomb)
	if IsValid(bombMenu) then
		bombMenu:Remove()
		bombMenu = nil
	end

	if not bomb then
		if IsValid(bombMenu) then
			bombMenu.bomb.islooked = nil
			bombMenu:Remove()
			bombMenu = nil
		end
		return
	end
	local size = ScrW() / 1920

	Dynamic = 0
	bombMenu = vgui.Create("DPanel")
	bombMenu.bomb = bomb
	local sizeX,sizeY = ScrW() ,ScrH()
	local posX,posY = ScrW() / 2 - sizeX / 2,ScrH() / 2 - sizeY / 2
	
	bombMenu:SetPos(posX,posY)
	bombMenu:SetSize(sizeX,sizeY)
	bombMenu:SetBackgroundColor(colGray)
	bombMenu:MakePopup()
	bombMenu:ParentToHUD()
	--bombMenu:SetKeyboardInputEnabled(false)
	
	local x,y = sizeX / 2 + 60 * size, 100 * size
	local w1,h1 = sizeX / 2 - 175 * size, sizeY / 2 - 125 * size

	local txt = ""

	bombMenu.keypress = false
	bombMenu.Paint = function(self,w,h)
		DrawReadout(bomb, x, y, w1, h1, size, txt)
	end

	function bombMenu:OnKeyCodePressed() 
		if IsValid(bombMenu) then
			bombMenu.bomb.islooked = nil
			bombMenu:Remove()
			bombMenu = nil
		end
	end

	bombMenu.Think = function()
		local view = render.GetViewSetup()
		local dir = util.AimVector(view.angles,view.fov,gui.MouseX(),gui.MouseY(),ScrW(),ScrH())
		dir = dir:Angle()
		local _,dir = WorldToLocal(vecZero,dir,vecZero,view.angles)
		dir[2] = -dir[2]
		dir[1] = -dir[1]
		dir = dir / 5
		
		if input.IsMouseDown(MOUSE_LEFT) then
			if not bombMenu.keypress then
				addDir = -(-dir)
			end
			bombMenu.keypress = true
		else
			bombMenu.keypress = false
		end
	end

	local grid = vgui.Create("DGrid",bombMenu)
	
	grid:SetPos(x + 14 * size,y + 530 * size)
	grid:SetCols(5)
	grid:SetColWide(156 * size)
	grid:SetRowHeight(184 * size)
	
	for i = 1, 10 do
		local but = vgui.Create("DButton")
		if i == 10 then i = 0 end
		but:SetText(i)
		but:SetSize(138 * size,150 * size)
		but.DoClick = function()
			surface.PlaySound("weapons/p99/fireselect.ogg")
			--if surface.GetTextSize(txt) >= 56 then return end
			if #txt >= 6 then return end
			txt = txt..i
		end
		function but:TestHover( x, y )
			return false
		end
		grid:AddItem(but)
	end

	local clearbut = vgui.Create("DButton",bombMenu)
	clearbut:SetPos(x + 100 * size,y + 300 * size)
	clearbut:SetSize(ScrW() / 8,ScrH() / 16)
	clearbut:SetText("")

	function clearbut:TestHover( x, y )
		return false
	end

	clearbut.DoClick = function()
		surface.PlaySound("weapons/ins2/p80/m9_empty.ogg")
		txt = ""
	end

	clearbut.Paint = function(self,w,h)
		surface.SetDrawColor( 0, 0, 0, 122)
        surface.DrawRect( 0, 0, w, h, 2.5 )
		surface.SetDrawColor( 122, 122, 122, 255)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
		surface.SetFont( "ZCity_Fixed_Medium" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Clear")
		surface.SetTextPos( w / 2 - lengthX / 2, h / 2 - lengthY / 2)
		surface.DrawText("Clear")
	end

	local enterbut = vgui.Create("DButton",bombMenu)
	enterbut:SetPos(x + 100 * size + ScrW() / 8 + 50 * size,y + 300 * size)
	enterbut:SetSize(ScrW() / 8,ScrH() / 16)
	enterbut:SetText("")

	function enterbut:TestHover( x, y )
		return false
	end

	enterbut.DoClick = function()
		if #txt < 6 then
			chat.AddText("The code must be of 6 numbers.")
			return
		end
		surface.PlaySound("weapons/tfa_ins2_sr25_eft/m14_empty.ogg")
		net.Start("bomb_enter")
		net.WriteString(txt)
		net.SendToServer()
		txt = ""
	end

	enterbut.Paint = function(self,w,h)
		surface.SetDrawColor( 0, 0, 0, 122)
        surface.DrawRect( 0, 0, w, h, 2.5 )
		surface.SetDrawColor( 122, 122, 122, 255)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
		surface.SetFont( "ZCity_Fixed_Medium" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Enter")
		surface.SetTextPos( w / 2 - lengthX / 2, h / 2 - lengthY / 2)
		surface.DrawText("Enter")
	end

	return bombMenu
end

