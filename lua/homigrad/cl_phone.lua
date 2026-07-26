if SERVER then return end

HG_PHONE_UI = HG_PHONE_UI or {registry = {}, history = {}}
local UI = HG_PHONE_UI

local function PhoneMessage(...)
	chat.AddText(Color(100, 190, 100), "[PHONE] ", Color(235, 235, 235), ...)
end

local function SendPhoneEntity(name, phone)
	if not IsValid(phone) then return end
	net.Start(name)
		net.WriteEntity(phone)
	net.SendToServer()
end

local function PlayPhoneButtonSound()
	LocalPlayer():EmitSound("panoptisscon/phone_query.ogg", 60, math.random(45, 165), 0.75, CHAN_ITEM)
end

local function PlayPhoneNumberSound()
	local suffix = math.random(1, 4)
	surface.PlaySound("panoptisscon/phone_press" .. (suffix == 1 and "" or suffix) .. ".ogg")
end

local function OpenNumberPanel(phone)
	if not IsValid(phone) then return end
	if IsValid(UI.numberPanel) then UI.numberPanel:Remove() end

	local panel = vgui.Create("DFrame")
	UI.numberPanel = panel
	panel:SetSize(250, 300)
	panel:Center()
	panel:SetTitle("Phone Numbers")
	panel:MakePopup()

	local entry = vgui.Create("DTextEntry", panel)
	entry:SetPos(12, 32)
	entry:SetSize(226, 28)
	entry:SetNumeric(true)
	entry:SetPlaceholderText("Enter number")

	for index = 1, 12 do
		local value = index == 10 and "CLEAR" or index == 11 and "0" or index == 12 and "CALL" or tostring(index)
		local button = vgui.Create("DButton", panel)
		button:SetPos(12 + ((index - 1) % 3) * 76, 70 + math.floor((index - 1) / 3) * 38)
		button:SetSize(70, 32)
		button:SetText(value)
		button.DoClick = function()
			if value == "CLEAR" then entry:SetText("") PlayPhoneButtonSound() return end
			if value == "CALL" then
				local number = entry:GetValue()
				if number == "" then return end
				PlayPhoneButtonSound()
				net.Start("HG_Phone_RequestCall")
					net.WriteEntity(phone)
					net.WriteString(number)
				net.SendToServer()
				return
			end
			PlayPhoneNumberSound()
			entry:SetText(string.sub(entry:GetValue() .. value, 1, 16))
		end
	end

	local public = vgui.Create("DCheckBoxLabel", panel)
	public:SetPos(12, 232)
	public:SetText("List my number publicly")
	public:SizeToContents()
	public:SetChecked(HG_PHONE.IsPublic(phone))
	public.OnChange = function(_, value)
		PlayPhoneButtonSound()
		net.Start("HG_Phone_SetPublic")
			net.WriteEntity(phone)
			net.WriteBool(value)
		net.SendToServer()
	end
end
local function AddHistory(senderName, senderNumber, message)
	UI.history[#UI.history + 1] = {
		name = senderName,
		number = senderNumber,
		message = message
	}
	if #UI.history > 60 then table.remove(UI.history, 1) end

	if IsValid(UI.chatLog) then
		UI.chatLog:InsertColorChange(120, 190, 255, 255)
		UI.chatLog:AppendText(string.format("%s (%s): ", senderName, senderNumber))
		UI.chatLog:InsertColorChange(235, 235, 235, 255)
		UI.chatLog:AppendText(message .. "\n")
		UI.chatLog:GotoTextEnd()
	end
end

local function BuildPhonePanel(phone)
	if not IsValid(phone) or not HG_PHONE.IsPhone(phone) then return end
	if IsValid(UI.panel) then UI.panel:Remove() end
	UI.currentPhone = phone
	UI.selectedNumber = nil

	local frame = vgui.Create("DFrame")
	UI.panel = frame
	frame:SetSize(780, 650)
	frame:Center()
	frame:SetTitle("Z-City Phone Network")
	frame:SetDeleteOnClose(true)
	frame:MakePopup()

	local ownInfo = vgui.Create("DLabel", frame)
	ownInfo:SetPos(16, 34)
	ownInfo:SetSize(748, 24)
	ownInfo:SetFont("DermaDefaultBold")

	local registryLabel = vgui.Create("DLabel", frame)
	registryLabel:SetPos(16, 64)
	registryLabel:SetSize(360, 20)
	registryLabel:SetText("PHONE REGISTRY — MAP AND PLAYERS")

	local registry = vgui.Create("DListView", frame)
	registry:SetPos(16, 86)
	registry:SetSize(430, 280)
	registry:SetMultiSelect(false)
	registry:AddColumn("Name")
	registry:AddColumn("Number")
	registry:AddColumn("State")
	registry:AddColumn("Type")

	local selectedLabel = vgui.Create("DLabel", frame)
	selectedLabel:SetPos(460, 86)
	selectedLabel:SetSize(304, 42)
	selectedLabel:SetWrap(true)
	selectedLabel:SetText("Select a number from the registry.")

	local callButton = vgui.Create("DButton", frame)
	callButton:SetPos(460, 136)
	callButton:SetSize(90, 38)
	callButton:SetText("CALL")
	callButton.DoClick = function()
		PlayPhoneButtonSound()
		if not UI.selectedNumber or not IsValid(phone) then return end
		net.Start("HG_Phone_RequestCall")
			net.WriteEntity(phone)
			net.WriteString(UI.selectedNumber)
		net.SendToServer()
	end

	local answerButton = vgui.Create("DButton", frame)
	answerButton:SetPos(560, 136)
	answerButton:SetSize(100, 38)
	answerButton:SetText("ANSWER")
	answerButton.DoClick = function() PlayPhoneButtonSound() SendPhoneEntity("HG_Phone_AnswerCall", phone) end

	local numberButton = vgui.Create("DButton", frame)
	numberButton:SetPos(668, 136)
	numberButton:SetSize(96, 38)
	numberButton:SetText("NUMBERS")
	numberButton.DoClick = function() PlayPhoneButtonSound() OpenNumberPanel(phone) end
	local hangupButton = vgui.Create("DButton", frame)
	hangupButton:SetPos(460, 182)
	hangupButton:SetSize(304, 38)
	hangupButton:SetText("HANG UP")
	hangupButton.DoClick = function() PlayPhoneButtonSound() SendPhoneEntity("HG_Phone_HangupCall", phone) end

	local deviceButton = vgui.Create("DButton", frame)
	deviceButton:SetPos(460, 228)
	deviceButton:SetSize(304, 38)
	if phone:GetClass() == "ent_phone" then
		deviceButton:SetText("PICK UP AS HANDHELD")
		deviceButton.DoClick = function() SendPhoneEntity("HG_Phone_Pickup", phone) end
	elseif phone:GetClass() == "weapon_phone" and phone.IsPlaceableDeskPhone and phone:IsPlaceableDeskPhone() then
		deviceButton:SetText("PLACE PHONE DOWN")
		deviceButton.DoClick = function() SendPhoneEntity("HG_Phone_PlaceDown", phone) end
	else
		deviceButton:SetVisible(false)
	end

	local iedButton = vgui.Create("DButton", frame)
	iedButton:SetPos(460, 274)
	iedButton:SetSize(304, 50)
	iedButton:SetText("CALL / DETONATE LINKED IED")
	iedButton:SetTextColor(Color(180, 35, 35))
	iedButton:SetVisible(HG_PHONE.IsIEDPhone(phone))
	iedButton.DoClick = function() SendPhoneEntity("HG_Phone_IEDDetonate", phone) end

	local nameEntry = vgui.Create("DTextEntry", frame)
	nameEntry:SetPos(460, 332)
	nameEntry:SetSize(202, 28)
	nameEntry:SetPlaceholderText("Phone display name")

	local setName = vgui.Create("DButton", frame)
	setName:SetPos(668, 332)
	setName:SetSize(96, 28)
	setName:SetText("SET NAME")
	setName.DoClick = function()
		local name = string.Trim(nameEntry:GetValue())
		if name == "" or not IsValid(phone) then return end
		net.Start("HG_Phone_SetDisplayName")
			net.WriteEntity(phone)
			net.WriteString(name)
		net.SendToServer()
	end

	local ringtone = vgui.Create("DComboBox", frame)
	ringtone:SetPos(460, 372)
	ringtone:SetSize(202, 28)
	for index, data in ipairs(HG_PHONE.RINGTONES) do ringtone:AddChoice(data.name, index) end
	ringtone:SetValue("Choose ringtone")

	local setRingtone = vgui.Create("DButton", frame)
	setRingtone:SetPos(668, 372)
	setRingtone:SetSize(96, 28)
	setRingtone:SetText("SET / TEST")
	setRingtone.DoClick = function()
		local index = ringtone:GetSelectedID()
		if not index or not HG_PHONE.RINGTONES[index] or not IsValid(phone) then return end
		surface.PlaySound(HG_PHONE.RINGTONES[index].path)
		net.Start("HG_Phone_SetRingtone")
			net.WriteEntity(phone)
			net.WriteUInt(index, 8)
		net.SendToServer()
	end

	local chatLabel = vgui.Create("DLabel", frame)
	chatLabel:SetPos(16, 378)
	chatLabel:SetSize(420, 20)
	chatLabel:SetText("CALL TEXT CHAT")

	local chatLog = vgui.Create("RichText", frame)
	UI.chatLog = chatLog
	chatLog:SetPos(16, 400)
	chatLog:SetSize(748, 174)
	for _, entry in ipairs(UI.history) do
		chatLog:InsertColorChange(120, 190, 255, 255)
		chatLog:AppendText(string.format("%s (%s): ", entry.name, entry.number))
		chatLog:InsertColorChange(235, 235, 235, 255)
		chatLog:AppendText(entry.message .. "\n")
	end
	chatLog:GotoTextEnd()

	local messageEntry = vgui.Create("DTextEntry", frame)
	messageEntry:SetPos(16, 584)
	messageEntry:SetSize(626, 32)
	messageEntry:SetPlaceholderText("Text the person on the other end of the active call")

	local sendButton = vgui.Create("DButton", frame)
	sendButton:SetPos(650, 584)
	sendButton:SetSize(114, 32)
	sendButton:SetText("SEND")
	local function SendText()
		local message = string.Trim(messageEntry:GetValue())
		if message == "" or not IsValid(phone) then return end
		net.Start("HG_Phone_Text")
			net.WriteEntity(phone)
			net.WriteString(message)
		net.SendToServer()
		messageEntry:SetText("")
	end
	sendButton.DoClick = SendText
	messageEntry.OnEnter = SendText

	local hint = vgui.Create("DLabel", frame)
	hint:SetPos(16, 620)
	hint:SetSize(748, 18)
	hint:SetContentAlignment(5)
	hint:SetText("Live voice chat is routed automatically while the call says IN CALL.")

	local function RefreshRegistry()
		local selected = UI.selectedNumber
		registry:Clear()
		for _, entry in ipairs(UI.registry) do
			if not IsValid(entry.phone) or not HG_PHONE.IsPhone(entry.phone) then continue end
			local line = registry:AddLine(
				HG_PHONE.GetDisplayName(entry.phone),
				entry.number,
				HG_PHONE.GetStateName(HG_PHONE.GetState(entry.phone)),
				HG_PHONE.IsIEDPhone(entry.phone) and "IED PHONE" or (entry.phone:IsWeapon() and "HANDHELD" or "MAP / DESK")
			)
			line.PhoneNumber = entry.number
			line.PhoneEntity = entry.phone
			if selected == entry.number then registry:SelectItem(line) end
		end
	end

	registry.OnRowSelected = function(_, _, line)
		UI.selectedNumber = line.PhoneNumber
		selectedLabel:SetText(string.format("Selected: %s\nNumber: %s", HG_PHONE.GetDisplayName(line.PhoneEntity), line.PhoneNumber))
	end

	frame.NextRefresh = 0
	frame.Think = function(self)
		if not IsValid(phone) or not HG_PHONE.IsPhone(phone) then return self:Close() end
		if self.NextRefresh <= CurTime() then
			self.NextRefresh = CurTime() + 0.5
			RefreshRegistry()
		end

		local state = HG_PHONE.GetState(phone)
		ownInfo:SetText(string.format("%s  |  %s  |  %s", HG_PHONE.GetDisplayName(phone), HG_PHONE.GetNumber(phone), HG_PHONE.GetStateName(state)))
		callButton:SetEnabled(state == HG_PHONE.STATE_IDLE and UI.selectedNumber ~= nil)
		answerButton:SetEnabled(state == HG_PHONE.STATE_RINGING)
		hangupButton:SetEnabled(state ~= HG_PHONE.STATE_IDLE)
		sendButton:SetEnabled(state == HG_PHONE.STATE_IN_CALL)
		messageEntry:SetEnabled(state == HG_PHONE.STATE_IN_CALL)
		iedButton:SetEnabled(HG_PHONE.IsIEDPhone(phone) and not phone:GetDialing() and not phone:GetDetonating())
	end

	frame.OnClose = function()
		if UI.panel == frame then UI.panel = nil end
		if UI.chatLog == chatLog then UI.chatLog = nil end
	end

	RefreshRegistry()
end

net.Receive("HG_Phone_Registry", function()
	local entries = {}
	for _ = 1, net.ReadUInt(12) do
		entries[#entries + 1] = {number = net.ReadString(), phone = net.ReadEntity()}
	end
	UI.registry = entries
end)

net.Receive("HG_Phone_OpenUI", function()
	BuildPhonePanel(net.ReadEntity())
end)

net.Receive("HG_Phone_Text", function()
	local senderName, senderNumber, message = net.ReadString(), net.ReadString(), net.ReadString()
	AddHistory(senderName, senderNumber, message)
	if not IsValid(UI.panel) then PhoneMessage(senderName .. " (" .. senderNumber .. "): " .. message) end
end)

net.Receive("HG_Phone_Notification", function()
	PhoneMessage(net.ReadString())
end)

concommand.Add("phone_dial", function()
	local phone = LocalPlayer():GetActiveWeapon()
	if not IsValid(phone) or not HG_PHONE.IsPhone(phone) then
		PhoneMessage("Equip a handheld or planted IED phone, or use a nearby map phone.")
		return
	end
	SendPhoneEntity("HG_Phone_RequestOpen", phone)
end, nil, "Open the active phone")
