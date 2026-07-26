-- IED phone client UI.

if SERVER then return end

local activePanel

local function GetIEDStatus(phone)
	if not IsValid(phone) then return "NO SIGNAL", Color(180, 45, 45) end
	if phone:GetDestroyed() then return "DEVICE DESTROYED", Color(180, 45, 45) end
	if phone:GetDetonating() then return "DETONATING", Color(255, 70, 45) end
	if phone:GetDialing() then
		local remaining = math.max(phone:GetDetonateAt() - CurTime(), 0)
		return string.format("CALLING... %.1fs", remaining), Color(245, 185, 55)
	end
	if phone:GetPlanted() then return "ARMED / LINKED", Color(90, 220, 100) end
	return "NOT ARMED", Color(180, 180, 180)
end

local function OpenIEDPhone(phone)
	if not IsValid(phone) then return end
	local phoneLabel = "IED-" .. phone:EntIndex()

	if IsValid(activePanel) then activePanel:Remove() end

	local frame = vgui.Create("DFrame")
	activePanel = frame
	frame:SetSize(360, 430)
	frame:Center()
	frame:SetTitle("Nokia IED Controller")
	frame:SetDeleteOnClose(true)
	frame:MakePopup()

	local screen = vgui.Create("DPanel", frame)
	screen:SetPos(24, 46)
	screen:SetSize(312, 250)
	screen.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(83, 106, 69))
		draw.RoundedBox(2, 8, 8, w - 16, h - 16, Color(154, 176, 124))

		local status, statusColor = GetIEDStatus(phone)
		draw.SimpleText("LINKED DEVICE", "DermaDefaultBold", w / 2, 24, Color(25, 35, 22), TEXT_ALIGN_CENTER)
		draw.SimpleText(phoneLabel, "DermaLarge", w / 2, 70, Color(20, 30, 18), TEXT_ALIGN_CENTER)
		draw.SimpleText(status, "DermaDefaultBold", w / 2, 125, statusColor, TEXT_ALIGN_CENTER)
		draw.SimpleText("Reload opens this phone", "DermaDefault", w / 2, h - 30, Color(35, 48, 30), TEXT_ALIGN_CENTER)
	end

	local detonate = vgui.Create("DButton", frame)
	detonate:SetPos(24, 315)
	detonate:SetSize(312, 55)
	detonate:SetText("CALL LINKED IED")
	detonate:SetFont("DermaDefaultBold")
	detonate.DoClick = function()
		if not IsValid(phone) then
			frame:Close()
			return
		end

		net.Start("HG_IEDPhone_Detonate")
			net.WriteEntity(phone)
		net.SendToServer()
	end

	local hint = vgui.Create("DLabel", frame)
	hint:SetPos(24, 380)
	hint:SetSize(312, 28)
	hint:SetContentAlignment(5)
	hint:SetText("LMB also calls the currently linked charge.")

	frame.Think = function(self)
		if not IsValid(phone) then
			self:Close()
			return
		end

		local busy = phone:GetDialing() or phone:GetDetonating() or phone:GetDestroyed() or not phone:GetPlanted()
		detonate:SetEnabled(not busy)
		if phone:GetDialing() then
			detonate:SetText("CALL IN PROGRESS")
		elseif phone:GetDetonating() then
			detonate:SetText("DETONATING")
		elseif phone:GetDestroyed() then
			detonate:SetText("DEVICE DESTROYED")
		else
			detonate:SetText("CALL LINKED IED")
		end
	end
end

net.Receive("HG_IEDPhone_Open", function()
	OpenIEDPhone(net.ReadEntity())
end)

net.Receive("HG_IEDPhone_Feedback", function()
	chat.AddText(Color(100, 190, 100), "[IED PHONE] ", Color(235, 235, 235), net.ReadString())
end)

concommand.Add("phone_dial", function()
	local phone = LocalPlayer():GetActiveWeapon()
	if not IsValid(phone) or phone:GetClass() ~= "weapon_traitor_ied" then
		chat.AddText(Color(100, 190, 100), "[IED PHONE] ", Color(235, 235, 235), "Equip a planted IED phone first.")
		return
	end

	net.Start("HG_IEDPhone_RequestOpen")
		net.WriteEntity(phone)
	net.SendToServer()
end, nil, "Open the linked IED phone")
